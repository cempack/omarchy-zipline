# Changelog

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
