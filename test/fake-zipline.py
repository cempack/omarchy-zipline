#!/usr/bin/env python3
"""Minimal stand-in for the Zipline v4 endpoints the CLI uses.

Logs every request as one JSON line to the file given as argv[2] and answers
like Zipline: /api/upload, /api/upload/partial, /api/user/urls, /api/user.
"""

import email.parser
import email.policy
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = "test-token-123"
LOG = sys.argv[2]
partials = {}


def parse_multipart(content_type, body):
    message = email.parser.BytesParser(policy=email.policy.HTTP).parsebytes(
        b"Content-Type: " + content_type.encode() + b"\r\n\r\n" + body
    )
    parts = []
    for part in message.iter_parts():
        parts.append(
            {
                "name": part.get_param("name", header="content-disposition"),
                "filename": part.get_filename(),
                "type": part.get_content_type(),
                "data": part.get_payload(decode=True),
            }
        )
    return parts


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, payload):
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def record(self, extra):
        headers = {k.lower(): v for k, v in self.headers.items()}
        with open(LOG, "a") as f:
            f.write(json.dumps({"method": self.command, "path": self.path, "headers": headers, **extra}) + "\n")

    def authorized(self):
        return self.headers.get("authorization") == TOKEN

    def do_GET(self):
        self.record({})
        if self.path == "/api/user":
            if not self.authorized():
                return self.reply(401, {"error": "not logged in"})
            return self.reply(200, {"user": {"username": "tester"}})
        self.reply(404, {"error": "not found"})

    def do_POST(self):
        length = int(self.headers.get("content-length", 0))
        body = self.rfile.read(length)
        if not self.authorized():
            self.record({})
            return self.reply(401, {"error": "not logged in"})

        if self.path == "/api/user/urls":
            payload = json.loads(body)
            self.record({"json": payload})
            return self.reply(200, {"code": "abc", "url": "http://short.test/go/abc"})

        parts = parse_multipart(self.headers["content-type"], body)
        summary = [{k: (len(v) if k == "data" else v) for k, v in p.items()} for p in parts]
        self.record({"parts": summary})

        if self.path == "/api/upload":
            files = [{"id": str(i), "name": p["filename"], "url": "http://files.test/u/" + p["filename"]} for i, p in enumerate(parts)]
            return self.reply(200, {"files": files})

        if self.path == "/api/upload/partial":
            start, end, total = (
                self.headers["content-range"].replace("bytes ", "").replace("-", "/").split("/")
            )
            start, end, total = int(start), int(end), int(total)
            token = self.headers.get("x-zipline-p-token")
            if start == 0:
                if token:
                    return self.reply(400, {"error": "first chunk must not send a token"})
                key = "upload"
                partials[key] = bytearray()
            else:
                if token != "tok-%d" % start:
                    return self.reply(400, {"error": "bad partial token"})
                key = "upload"
            data = parts[0]["data"]
            if len(data) != end - start + 1:
                return self.reply(400, {"error": "chunk length mismatch"})
            partials[key] += data
            last = self.headers.get("x-zipline-p-lastchunk") == "true"
            response = {"files": [], "partialSuccess": True, "partialToken": "tok-%d" % (end + 1)}
            if last:
                with open(LOG + ".assembled", "wb") as f:
                    f.write(partials[key])
                response["files"].append({"id": "p", "name": "big.bin", "url": "http://files.test/u/big.bin", "pending": True})
            return self.reply(200, response)

        self.reply(404, {"error": "not found"})


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler)
    server.serve_forever()
