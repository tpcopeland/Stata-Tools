# pkgtransfer

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Transfer installed Stata packages between installations.

## Description

pkgtransfer facilitates transferring installed packages from one Stata installation to another. It can generate a do-file with the necessary net install, ssc install, or github install commands for online installation. Alternatively, it can download all package files and create a local installation script with a ZIP archive for offline installation.

## Dependencies

None - uses only built-in Stata commands. Optional support for the **github** command if packages were installed from GitHub (install with `net install github, from("https://haghish.github.io/github/")`).

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer
net install pkgtransfer
```

## Syntax

```stata
pkgtransfer [, download limited(pkglist)]
```

### Options

- **download** - Create ZIP file of all packages and do-file for local installation
- **limited(pkglist)** - Restrict operation to specified packages (space-separated list)

## Workflow

### Online installation (internet available on new machine)

```stata
* On old machine
pkgtransfer

* Transfer pkgtransfer.do to new machine and run
do pkgtransfer.do
```

### Offline installation (no internet on new machine)

```stata
* On old machine
pkgtransfer, download

* Transfer the ZIP file and pkgtransfer_local.do to new machine
* Extract ZIP and run
do pkgtransfer_local.do
```

## Examples

```stata
* Generate online installation script
pkgtransfer

* Create offline installation package
pkgtransfer, download

* Transfer only specific packages
pkgtransfer, limited(estout outreg2)
```

## Note

It is recommended to first run pkgtransfer without the download option to save original installation commands, then run with download if needed.

## Requirements

Stata 14.0 or higher

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## Help

For more information:
```stata
help pkgtransfer
```
