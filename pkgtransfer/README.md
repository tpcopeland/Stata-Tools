# pkgtransfer - Transfer installed Stata packages between installations

**Version 1.0.0** | 2026-04-08

`pkgtransfer` reads the package-tracking information in your PLUS directory and generates the files needed to recreate that package set on another Stata installation. It supports both online migration, where the new machine reinstalls packages from their original sources, and offline migration, where you carry a local bundle of package files.

## Requirements

- Stata 16 or later
- The `github` command is only needed if some installed packages were originally installed from GitHub

## Installation

```stata
capture ado uninstall pkgtransfer
net install pkgtransfer, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer") replace
```

If you need GitHub-backed reinstall commands on the destination machine, install `github` as well:

```stata
net install github, from("https://haghish.github.io/github/") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `pkgtransfer` | Export an installed-package setup for online or offline recreation |

## How It Works

`pkgtransfer` works off the `stata.trk` file in your current PLUS directory. That file records which packages are installed and where they came from. The command uses that information to generate one of three outputs:

1. **Default mode**: writes `pkgtransfer.do`, a do-file with `ssc install`, `net install`, or `github install` commands that recreate your current package setup online.
2. **`download(online)` or `download(local)`**: creates a local-install do-file plus a ZIP archive of package files for offline transfer.
3. **`restore`**: rewrites stored source paths in `stata.trk` back to their original online locations after packages were installed from a `pkgtransfer` ZIP bundle.

`limited()` and `skip()` let you restrict the package set. `os()` lets you target cleanup commands to `Windows`, `Unix`, or `MacOSX` if the destination machine differs from the current one.

## Output Files

| Mode | Files created |
|------|---------------|
| Default | `pkgtransfer.do` |
| `download(online)` | `pkgtransfer.do` and `pkgtransfer_files.zip` |
| `download(local)` | `pkgtransfer.do` and `pkgtransfer_files.zip` |

When `download(local)` is used, platform-specific `.plugin` files are still fetched from the internet because the local PLUS directory only contains the current platform's plugin build.

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

The generated do-file recreates your installed packages from their original sources.

### 2. Offline migration when the destination machine has no internet

Use `download(online)` if you want `pkgtransfer` to fetch current package files from the internet before bundling them.

On the old machine:

```stata
pkgtransfer, download(online)
```

Move both `pkgtransfer.do` and `pkgtransfer_files.zip` to the new machine. Extract the ZIP archive, then run:

```stata
do pkgtransfer.do
```

This is the safest offline workflow when you want the bundle to reflect the sources recorded in `stata.trk`.

### 3. Build an offline bundle from your local PLUS directory

Use `download(local)` when you want to package the copies you already have installed locally.

```stata
pkgtransfer, download(local)
```

This still creates `pkgtransfer.do` and `pkgtransfer_files.zip`, but it copies package files from your local installation whenever possible.

### 4. Limit the package set or skip specific packages

These options are useful when you are preparing a smaller team environment or excluding packages you do not want to redistribute.

```stata
pkgtransfer, limited(estout outreg2) dofile(team_setup.do)
pkgtransfer, download(online) skip(gtools ftools) ///
    dofile(clean_install.do) zipfile(clean_install.zip)
```

Package names in `limited()` and `skip()` must match the package names recorded in `stata.trk` exactly.

### 5. Restore online source paths after a local install

If packages were installed from a `pkgtransfer` ZIP bundle, `restore` can point `stata.trk` back to the original online source URLs.

```stata
pkgtransfer, restore
```

This works only for packages installed from `pkgtransfer`-generated ZIP archives, because those archives store the backup source metadata needed for restoration.

## Practical Notes

- Run `pkgtransfer` once in default mode before using `download()`. That gives you a clean online-install script you can keep as a fallback.
- `zipfile()` is valid only with `download()`.
- `dofile()` must end in `.do`, and `zipfile()` must end in `.zip`.
- The generated outputs reflect the packages visible in the current PLUS directory, not every package that might exist elsewhere on the system.

## Returned Results

After a run, `pkgtransfer` stores:

- `r(N_packages)` - number of packages processed
- `r(package_list)` - package names included in the output
- `r(download_mode)` - `script_only`, `online`, `local`, or `restore`
- `r(os)` - target operating system
- `r(dofile)` - generated do-file path
- `r(zipfile)` - generated ZIP file path when applicable

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
