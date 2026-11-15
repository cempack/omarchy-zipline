# Changelog

## 3.0.0

- New panel: account and upload stats in the header (files, storage, views),
  an **Expires** and a **Views** option for the next upload, larger action
  tiles, and recent links with their destination, age and limits.
- One-time links: `--max-views <n>` (and `ZIPLINE_MAX_VIEWS` in the config)
  stops serving a file or short link after n views.
- Recent links: copy as Markdown (`m`, images embed), open (`o`), and forget
  (`x`) to drop a link from the local history without touching the server.
- Uploading several files puts every link on the clipboard, one per line.
- `status --json` reports the account and its stats; `history` adds the
  expiry and view limit columns (older history lines still read fine).
- A footer shows the keys that apply to the selection and confirms actions.
- When nothing is configured, the panel offers to run `omarchy-zipline setup`
  in a terminal.

## 2.1.1

- Panel: removed the status sentence and the footer hint; recent links take one line each.
- Shorter labels in the panel and the Omarchy menu: Clipboard, File, Recording, Last link.

## 2.1.0

- Simpler menu and panel. Omarchy menu > Capture > Zipline and the bar panel
  now offer the same four actions: **Upload clipboard**, **Upload file…**,
  **Upload latest recording** and **Copy last link** (plus recent links in the
  panel).
- Removed "Upload latest screenshot" (Print puts the screenshot on the
  clipboard, so Upload clipboard covers it), "Shorten link" (a link on the
  clipboard is shortened automatically) and "Set up" (run
  `omarchy-zipline setup` once in a terminal). The `screenshot`, `shorten` and
  `setup` commands still work from the CLI.
- `--help` lists the four main commands first.

## 2.0.0

- The plugin no longer takes screenshots. Omarchy's Print key captures and
  copies the image; **Shift + Print** now uploads the clipboard, so the flow is
  Print, then Shift + Print.
- `omarchy-zipline screenshot` uploads the newest screenshot Omarchy saved
  instead of opening a capture. The `smart|region|windows|fullscreen` modes and
  `--delay` are gone, and so is the grim/slurp fallback.
- When the clipboard image is the screenshot Omarchy just saved, the saved file
  is uploaded, so the link keeps its `screenshot-<date>` name.
- Removed **Ctrl + Shift + Print** and the region/window/full-screen buttons
  from the panel and the Omarchy menu.
- The bar icon's right-click uploads the clipboard.

## 1.0.0

- First release: uploads screenshots, recordings, files and the clipboard,
  shortens links, chunked uploads, bar widget, Omarchy menu entries.
