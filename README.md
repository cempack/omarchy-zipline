# Zipline for Omarchy

Upload screenshots, screen recordings, files and the clipboard to your own
[Zipline](https://zipline.diced.sh) server from [Omarchy](https://omarchy.org),
then paste the link anywhere. One key, and the link is on your clipboard.

- **Shift + Print** uploads a screenshot (drag a region or click a window)
- A bar icon with a panel for every action and your recent links
- Entries under **Omarchy menu > Capture > Zipline**
- Large recordings upload in chunks, so proxies like Cloudflare (100 MB limit) don't get in the way
- A link on the clipboard is shortened instead of uploaded

Works with Zipline v4 and Omarchy 4 (the Quickshell-based shell).

## Install

```sh
omarchy plugin add https://github.com/cempack/omarchy-zipline.git --enable
~/.config/omarchy/plugins/io.github.cempack.zipline/install.sh
omarchy-zipline setup
```

1. `omarchy plugin add` clones the plugin and puts its icon in the bar.
2. `install.sh` adds the keybindings, the menu entries and the
   `omarchy-zipline` command. It is safe to run again.
3. `omarchy-zipline setup` asks for your server URL and API token. In Zipline,
   open the user menu at the top right and choose **Copy token**.

Everything it needs ships with Omarchy: `curl`, `jq`, `wl-clipboard`, `file`
and `python3`.

## Use it

| Keys | Does |
|---|---|
| `Shift + Print` | Screenshot a region or window, upload it |
| `Ctrl + Shift + Print` | Screenshot the whole screen, upload it |
| `Alt + Shift + Print` | Upload the newest screen recording (record with `Alt + Print` first) |
| `Super + Ctrl + U` | Upload the clipboard: an image, copied files, or text. A copied link gets shortened |
| `Super + Ctrl + Shift + U` | Open the Zipline panel |

When an upload finishes, the link is on your clipboard and a notification shows
it. Click the notification to open the link.

**Bar icon**: left-click opens the panel (all actions plus recent links; click a
link to copy it again). Right-click uploads a screenshot straight away. Arrow
keys or `hjkl` and Enter work in the panel.

**From a terminal**:

```sh
omarchy-zipline screenshot [smart|region|windows|fullscreen]
omarchy-zipline recording
omarchy-zipline file ~/Documents/report.pdf      # no path opens the file chooser
omarchy-zipline clipboard
omarchy-zipline shorten https://example.com/a/very/long/link
omarchy-zipline --expires 1d file notes.txt      # delete after a day
omarchy-zipline last                             # copy the last link again
omarchy-zipline history 10
omarchy-zipline status                           # check the URL and token
```

Screenshots are also kept where Omarchy saves them (`~/Pictures` by default).

## Configure

`~/.config/omarchy-zipline/config`, mode 600. `omarchy-zipline setup` writes
it; you can also edit it by hand:

```sh
ZIPLINE_URL=https://zipline.example.com
ZIPLINE_TOKEN=paste-your-token-here

# Optional
ZIPLINE_TOKEN_FILE=~/.secrets/zipline-token  # read the token from a file instead
ZIPLINE_FORMAT=random       # random, uuid, date, name, gfycat, random-words
ZIPLINE_EXPIRES=7d          # 1h, 7d, never, or date=2027-01-01
ZIPLINE_ORIGINAL_NAME=true  # downloads keep the original file name
ZIPLINE_FOLDER=<folder id>  # upload into a folder
ZIPLINE_DOMAIN=files.example.com  # return links on another domain configured in Zipline
ZIPLINE_CHUNK_MB=50         # files bigger than this upload in chunks
```

The panel shows the last 5 uploads by default. Change it in the bar widget
settings (`historyCount`).

To use different keys, edit `~/.config/hypr/zipline.lua`, then rerun
`install.sh --no-bindings` from now on so your edits are kept. Other flags:
`--no-menu` and `--no-bar`.

### Zipline behind Cloudflare Access or another login proxy

The plugin talks to the API with your token, so these paths must reach Zipline
without a browser login: `/api/upload`, `/api/upload/partial`, `/api/user/urls`
and `/api/user`. The file and short-link URLs you share also need to be public.

## Security

- The token lives only in the config file (mode 600). It is never written to
  `shell.json`, never passed on a command line (curl reads it from a file
  descriptor), and never printed.
- The QML panel never touches the token. It runs the bundled
  `bin/omarchy-zipline` script with fixed arguments, without a shell.
- Upload history is kept in `~/.local/state/omarchy-zipline/history.tsv` (mode 600).

## Uninstall

```sh
~/.config/omarchy/plugins/io.github.cempack.zipline/uninstall.sh   # add --purge to delete config and history
omarchy plugin remove io.github.cempack.zipline
```

## Develop

```sh
bash test/cli-test.sh          # CLI against a fake Zipline server
node test/model-test.js
node test/qml-contract-test.js
shellcheck bin/omarchy-zipline install.sh uninstall.sh test/cli-test.sh
omarchy plugin validate "$PWD"
```

Running `install.sh` from a checkout outside the plugins folder copies it into
`~/.config/omarchy/plugins/io.github.cempack.zipline/`.

## License

MIT
