# mdgrill

A native macOS app for annotating rendered markdown files.

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

Opens the file in a rendered view. The source file is never modified.

## Requirements

- macOS 13+
- Swift 5.9+
- Xcode Command Line Tools
