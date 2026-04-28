# mdgrill

A native macOS app for annotating rendered markdown files. Select text, attach comments, export quote+comment pairs to the clipboard. Source files are never modified — annotations live in a sidecar.

## Build

```sh
make build
```

Produces `.build/mdgrill.app`.

## Install

```sh
make install
```

Copies the app to `/Applications/mdgrill.app`.

Then copy the CLI shim to somewhere on your PATH:

```sh
cp mdgrill /usr/local/bin/mdgrill
```

## Usage

```sh
mdgrill path/to/file.md
```

Opens the file rendered in a single window. Close the window to quit.

### Annotating

| Action | Shortcut |
|--------|----------|
| Add comment | Cmd+Shift+C |
| Save comment | Cmd+Return |
| Cancel | Esc |
| Export all to clipboard | Cmd+E |
| Delete annotation | Click highlight → Delete |

Select text, press Cmd+Shift+C, type your comment, press Cmd+Return. A yellow highlight marks the annotation. Click any highlight to view or delete it.

### Export format

Cmd+E copies all annotations to the clipboard as:

```
> quoted text

your comment

---
```

### Storage

Annotations are stored in `~/.mdgrill/annotations/<hash>.json` (one file per source document, keyed by SHA-256 of the absolute path). Source `.md` files are never modified.

## Configuration

Edit `~/.mdgrill/config.json` to override shortcuts:

```json
{
  "shortcuts": {
    "add_comment": "cmd+shift+c",
    "export": "cmd+e"
  }
}
```

Supported modifiers: `cmd`, `shift`, `alt`/`option`, `ctrl`. Changes take effect on relaunch.

## Development

Rebuild and relaunch in one step:

```sh
make run FILE=/path/to/file.md
```

This kills any running instance, rebuilds, and opens the app with the given file.

## Requirements

- macOS 13+
- Swift 5.9+
- Xcode Command Line Tools
