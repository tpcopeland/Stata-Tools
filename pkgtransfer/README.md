# pkgtransfer - Transfer installed Stata packages between machines

**Version 1.0.0** | 2026-07-10

`pkgtransfer` reads the package-tracking information in your PLUS directory and generates the files needed to recreate that package set on another Stata installation. It supports both online migration, where the new machine reinstalls packages from their original sources, and offline migration, where you carry a ZIP bundle of package files.

## Requirements

- Stata 16 or later
- The `github` command is only needed if your generated reinstall script includes `github install ...` lines for packages originally installed from GitHub

## Installation

```stata
capture ado uninstall pkgtransfer
net install pkgtransfer, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `pkgtransfer` | Export your installed-package setup for online or offline recreation |

## How It Works

`pkgtransfer` works from the `stata.trk` file in your current PLUS directory. That file records which packages are installed and where they came from. The command then generates one of three outputs:

1. Default mode writes `pkgtransfer.do`, a do-file with `ssc install`, `net install`, or `github install` commands that recreate your current setup online.
2. `download(online)` or `download(local)` creates `pkgtransfer.do` plus `pkgtransfer_files.zip` for offline transfer.
3. `restore` rewrites tracked source paths back to their original online URLs after packages were installed from a `pkgtransfer` ZIP bundle.

Use `limited()` and `skip()` to control which packages are included. Use `os()` when the destination machine needs platform-specific cleanup commands for a different operating system.

## Choosing a Mode

| Mode | When to use | Output |
|------|-------------|--------|
| Default | The destination machine has internet access | `pkgtransfer.do` |
| `download(online)` | You want an offline bundle built from current upstream package files | `pkgtransfer.do` and `pkgtransfer_files.zip` |
| `download(local)` | You want to bundle the copies already installed in your PLUS directory | `pkgtransfer.do` and `pkgtransfer_files.zip` |
| `restore` | Packages were installed from a `pkgtransfer` ZIP bundle and you want `stata.trk` pointed back to online sources | Updated `stata.trk` plus `stata.trk.backup` |

## Worked Examples

### 1. Online migration to a new machine

Use this when the destination machine has internet access and you want the lightest transfer workflow.

On the old machine:

```stata
pkgtransfer
```

Move `pkgtransfer.do` to the new machine, then run:

```stata
do pkgtransfer.do
```

### 2. Build an offline bundle from online sources

Use `download(online)` when you want `pkgtransfer` to fetch current package files from the internet before bundling them.

```stata
pkgtransfer, download(online)
```

Move both `pkgtransfer.do` and `pkgtransfer_files.zip` to the destination machine. Extract the ZIP archive, then run:

```stata
do pkgtransfer.do
```

### 3. Build an offline bundle from your local PLUS directory

Use `download(local)` when you want to package the copies you already have installed locally.

```stata
pkgtransfer, download(local) limited(estout outreg2) ///
    dofile(team_setup.do) zipfile(team_setup.zip)
```

This still creates `pkgtransfer.do` and `pkgtransfer_files.zip`, but it copies package files from your local installation whenever possible.

### 4. Limit the package set or skip selected packages

These options are useful when you are preparing a smaller team environment or excluding packages you do not want to redistribute.

```stata
pkgtransfer, download(online) skip(gtools ftools) ///
    dofile(clean_install.do) zipfile(clean_install.zip)
```

Package names in `limited()` and `skip()` must match the package names recorded in `stata.trk` exactly.

### 5. Restore online source paths after a local install

If packages were installed from a `pkgtransfer` ZIP bundle, `restore` can point `stata.trk` back to the original online source URLs.

```stata
pkgtransfer, restore
```

## Practical Notes

- Run `pkgtransfer` once in default mode before using `download()`. That gives you a clean online-install script you can keep as a fallback.
- `zipfile()` is valid only with `download()`.
- `dofile()` must end in `.do`, and `zipfile()` must end in `.zip`.
- The generated outputs reflect the packages visible in the current PLUS directory, not every package that might exist elsewhere on the system.
- Platform-specific `.plugin` files are still fetched from the internet when `download(local)` is used, because a local PLUS directory only contains the current platform build.

## Version History

- **1.0.0** (2026-04-08): Current Stata-Tools release with online transfer, offline bundle creation, filtering options, and source restoration

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
