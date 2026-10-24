#!/bin/bash

# Exercises bin/omarchy-zipline against test/fake-zipline.py: request shape,
# chunked uploads, URL shortening, status, errors, and that the token never
# reaches curl's argv.

set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CLI="$ROOT/bin/omarchy-zipline"
WORK=$(mktemp -d)
PORT=$((20000 + RANDOM % 20000))
LOG="$WORK/requests.jsonl"
SERVER_PID=""

cleanup() {
  [[ -n $SERVER_PID ]] && kill "$SERVER_PID" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

python3 -I "$ROOT/test/fake-zipline.py" "$PORT" "$LOG" &
SERVER_PID=$!
for _ in $(seq 1 50); do
  curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break
  sleep 0.1
done

# Isolated config, state and a curl shim that records argv.
export XDG_CONFIG_HOME="$WORK/config" XDG_STATE_HOME="$WORK/state"
mkdir -p "$WORK/bin" "$XDG_CONFIG_HOME/omarchy-zipline"
REAL_CURL=$(command -v curl)
cat >"$WORK/bin/curl" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >>"$WORK/curl-argv.log"
exec "$REAL_CURL" "\$@"
EOF
chmod +x "$WORK/bin/curl"
export PATH="$WORK/bin:$PATH"

CONFIG="$XDG_CONFIG_HOME/omarchy-zipline/config"
cat >"$CONFIG" <<EOF
ZIPLINE_URL="http://127.0.0.1:$PORT/"
ZIPLINE_TOKEN=test-token-123
ZIPLINE_FORMAT=random
ZIPLINE_ORIGINAL_NAME=true
EOF
chmod 600 "$CONFIG"

run() { "$CLI" --quiet --no-copy "$@"; }

# 1. Small upload: auth header, upload headers, one multipart file part.
printf 'hello zipline\n' >"$WORK/note; v2 (final).txt"
url=$(run file "$WORK/note; v2 (final).txt") || fail "small upload exited non-zero"
[[ $url == 'http://files.test/u/note; v2 (final).txt' ]] || fail "unexpected url: $url"
line=$(grep '"/api/upload"' "$LOG" | tail -n 1)
jq -e '.headers.authorization == "test-token-123"' <<<"$line" >/dev/null || fail "authorization header missing"
jq -e '.headers["x-zipline-format"] == "random"' <<<"$line" >/dev/null || fail "format header missing"
jq -e '.headers["x-zipline-original-name"] == "true"' <<<"$line" >/dev/null || fail "original-name header missing"
jq -e '.headers["user-agent"] | startswith("omarchy-zipline/")' <<<"$line" >/dev/null || fail "user agent missing"
jq -e '.parts | length == 1 and .[0].name == "file" and .[0].type == "text/plain" and .[0].data == 14' <<<"$line" >/dev/null ||
  fail "multipart part shape wrong: $(jq -c .parts <<<"$line")"
echo "ok - small upload"

# 2. --expires sets x-zipline-deletes-at.
run --expires 7d file "$WORK/note; v2 (final).txt" >/dev/null || fail "expires upload failed"
grep '"/api/upload"' "$LOG" | tail -n 1 | jq -e '.headers["x-zipline-deletes-at"] == "7d"' >/dev/null || fail "expires header missing"
echo "ok - expiry header"

# 3. Chunked upload: 1 MiB chunks for a 2.5 MiB file.
head -c 2621440 /dev/urandom >"$WORK/big.bin"
url=$(ZIPLINE_CHUNK_MB=1 run file "$WORK/big.bin") || fail "chunked upload exited non-zero"
[[ $url == "http://files.test/u/big.bin" ]] || fail "unexpected chunked url: $url"
chunks=$(grep -c '"/api/upload/partial"' "$LOG")
((chunks == 3)) || fail "expected 3 chunks, saw $chunks"
grep '"/api/upload/partial"' "$LOG" | jq -r '.headers["content-range"] + " " + .headers["x-zipline-p-lastchunk"]' >"$WORK/ranges"
diff -u - "$WORK/ranges" <<'EOF' || fail "chunk ranges wrong"
bytes 0-1048575/2621440 false
bytes 1048576-2097151/2621440 false
bytes 2097152-2621439/2621440 true
EOF
grep '"/api/upload/partial"' "$LOG" | jq -e -s 'all(.[]; .headers["x-zipline-p-filename"] == "big.bin" and .headers["x-zipline-p-content-length"] == "2621440")' >/dev/null ||
  fail "partial filename/length headers wrong"
cmp -s "$WORK/big.bin" "$LOG.assembled" || fail "reassembled file differs"
echo "ok - chunked upload"

# 4. Shorten.
url=$(run shorten "https://example.com/some/long/path?x=1") || fail "shorten exited non-zero"
[[ $url == "http://short.test/go/abc" ]] || fail "unexpected short url: $url"
grep '"/api/user/urls"' "$LOG" | tail -n 1 | jq -e '.json.destination == "https://example.com/some/long/path?x=1"' >/dev/null || fail "shorten body wrong"
echo "ok - shorten"

# 5. Status.
out=$("$CLI" status) || fail "status failed: $out"
grep -q 'signed in as tester' <<<"$out" || fail "status output wrong: $out"
echo "ok - status"

# 6. History records uploads, newest first.
first=$("$CLI" history 1 | cut -f1)
[[ $first == "http://short.test/go/abc" ]] || fail "history newest entry wrong: $first"
[[ $(stat -c %a "$XDG_STATE_HOME/omarchy-zipline/history.tsv") == 600 ]] || fail "history file is not private"
echo "ok - history"

# 7. A rejected token fails cleanly and names the problem.
sed -i 's/^ZIPLINE_TOKEN=.*/ZIPLINE_TOKEN=wrong/' "$CONFIG"
if err=$(run file "$WORK/note; v2 (final).txt" 2>&1); then fail "bad token should fail"; fi
grep -q 'not logged in' <<<"$err" || fail "bad token error not surfaced: $err"
echo "ok - rejected token"

# 8. Missing config.
if err=$(OMARCHY_ZIPLINE_CONFIG="$WORK/none" run file "$WORK/big.bin" 2>&1); then fail "missing config should fail"; fi
grep -q 'omarchy-zipline setup' <<<"$err" || fail "missing config hint absent: $err"
echo "ok - missing config"

# 9. The token never reached curl's argv.
if grep -q 'test-token-123\|wrong' "$WORK/curl-argv.log"; then fail "token leaked into curl argv"; fi
echo "ok - token not in argv"

echo "cli-test: ok"
