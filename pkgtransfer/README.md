# pkgtransfer — Transfer installed Stata packages between machines

**Version 1.0.5** | 2026-08-11

`pkgtransfer` creates a reproducible Stata installation script or an offline package bundle from the packages tracked in the current PLUS directory. It is for users moving a Stata setup to another machine or sharing a controlled package set.

## Quick Start

Create an online reinstall script on the source machine:

```stata
pkgtransfer
return list
```

Move `pkgtransfer.do` to a destination machine with internet access and run:

```stata
do pkgtransfer.do
```

The default run writes only the script; it does not download package files. It uses the package sources recorded in the source machine's `stata.trk`.

## Requirements

- Stata 16 or later
- A `stata.trk` file in the current PLUS directory, with the package and source records to transfer
- Internet access for `download(online)` and for running a generated online-install script
- The `github` command on the destination if the generated script contains `github install` lines

`download(local)` copies package files from the current PLUS directory, but it still contacts source URLs for platform-specific `.plugin` files.

## Installation

Install the released package from Stata-Tools:

```stata
capture ado uninstall pkgtransfer
net install pkgtransfer, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `pkgtransfer` | Generate an online-install script, an offline package bundle, or restored package source paths |

## How It Works

`pkgtransfer` reads the `stata.trk` file in the current PLUS directory (`c(sysdir_plus)`). It uses the package names, source URLs, and file records there to select packages and construct the requested transfer outputs.

- With no options, it writes a do-file containing `ssc install`, `net install`, or `github install` commands for eligible recorded sources.
- With `download(online)`, it downloads package descriptors and files from their recorded online sources, then creates an archive and an installer do-file.
- With `download(local)`, it copies the package files already present in the current PLUS directory, while obtaining platform-specific plugins from their sources.
- With `restore`, it uses backup source metadata embedded by a transfer bundle to restore online URLs in `stata.trk`.

Standard output files are written in the current working directory. The offline installer unpacks the archive selected by `zipfile()`—`pkgtransfer_files.zip` by default—and installs the selected packages from the extracted local files; it leaves the extracted folder in place because its cleanup commands are disabled for safety.

Nested ordinary and plugin paths recorded by package descriptors are preserved in offline bundles. Parent-relative plugin sources are rebased into the archive, plugin `g`/`G` installation semantics are preserved, and unsafe absolute or remaining parent-traversal paths are rejected before a tracked file can escape the command-owned staging directory. Generated `.pkg` files and `stata.toc` use Stata's version-3 distribution format.

## Worked Examples

### 1. Generate and run an online installation script

Run this on the source machine:

```stata
pkgtransfer, dofile(source_install.do)
return list
```

Move `source_install.do` to the destination machine and run it there:

```stata
do source_install.do
```

The generated script uses SSC installation for recognized SSC sources, GitHub installation for recognized Haghish GitHub sources, and `net install` with `from()` for other online sources.

### 2. Create an offline bundle from online sources

Use this when the source machine can reach the recorded package URLs but the destination machine should install from a bundle:

```stata
pkgtransfer, download(online)
```

Move `pkgtransfer.do` and `pkgtransfer_files.zip` to the destination machine, keep them in the same directory, and run:

```stata
do pkgtransfer.do
```

The generated script unpacks the archive before installing the selected packages.

### 3. Create a bundle from local PLUS files

This example bundles the installed copy of `pkgtransfer` itself. Replace the package name with one recorded in your `stata.trk` when preparing a different subset:

```stata
pkgtransfer, download(local) limited(pkgtransfer) dofile(local_setup.do)
```

Move `local_setup.do` and `pkgtransfer_files.zip` to the destination machine and run `do local_setup.do` there. Platform-specific plugin files, if any, are fetched while the bundle is being built.

### 4. Limit or skip packages

The first run obtains a package name from the current tracking file. The subsequent runs create a one-package script and a script that excludes that package:

```stata
pkgtransfer
local packages "`r(package_list)'"
local first : word 1 of `packages'

pkgtransfer, limited(`first') dofile(one_package.do)
pkgtransfer, skip(`first') dofile(without_one.do)
```

Package names must match the names recorded in `stata.trk` exactly. `limited()` rejects a name that is not installed; `skip()` ignores names that do not match a tracked package. Repeated names in either option are normalized once while retaining their first-supplied order.

### 5. Restore online source paths

Run this on a machine where packages were installed from a `pkgtransfer` offline bundle:

```stata
pkgtransfer, restore
```

The command backs up the current PLUS `stata.trk` as `stata.trk.backup`, replaces source lines when embedded backup URLs are available, and removes those backup records from the active tracking file.

## Demo

The checkout demo (`pkgtransfer/demo/demo_pkgtransfer.do`) exercises online-script generation, package filtering, local and online offline bundles, custom filenames, target operating systems, bundle installation, and source restoration. It uses isolated temporary PLUS and PERSONAL directories and removes every generated installer, archive, and extracted file after verifying its contents. The online-bundle section requires internet access.

Run it from the Stata-Tools repository root:

```bash
stata-mp -b do pkgtransfer/demo/demo_pkgtransfer.do
```

### Online installation scripts and package filters

The controlled tracker contains the locally installed `pkgtransfer` package and a small `demofixture` record so the effects of `limited()` and `skip()` are visible.

<details>
<summary>Script generation and filtering output (click to expand)</summary>

#### All eligible packages

```stata
.     noisily pkgtransfer, dofile("_all_packages.do")
```

```
Preparation of installation do file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  2

macros:
             r(dofile) : "_all_packages.do"
                 r(os) : "Unix"
      r(download_mode) : "script_only"
       r(package_list) : "demofixture pkgtransfer"
```

```stata
.     noisily type "_all_packages.do"
```

```
net install demofixture, replace from("https://example.org/stata/")
net install pkgtransfer, replace from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer/")
```

#### limited() normalizes repeated package names

```stata
.     noisily pkgtransfer, limited(pkgtransfer pkgtransfer)
>         os(MacOSX) dofile("_limited_packages.do")
```

```
Preparation of installation do file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  1

macros:
             r(dofile) : "_limited_packages.do"
                 r(os) : "MacOSX"
      r(download_mode) : "script_only"
       r(package_list) : "pkgtransfer"
```

#### skip() excludes an exact package name

```stata
.     noisily pkgtransfer, skip(demofixture)
>         dofile("_skip_packages.do")
```

```
Preparation of installation do file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  1

macros:
             r(dofile) : "_skip_packages.do"
                 r(os) : "Unix"
      r(download_mode) : "script_only"
       r(package_list) : "pkgtransfer"
```

</details>

### Local offline bundle

This stage copies the selected package from the isolated PLUS directory, targets Windows cleanup syntax, and uses custom installer and archive names.

<details>
<summary>Local bundle output (click to expand)</summary>

```stata
.     noisily pkgtransfer, download(local) limited(pkgtransfer)
>         os(Windows) dofile("_offline_install.do")
>         zipfile("_offline_bundle.zip")
```

```
Starting file copy (2 files) from local directory...
Copying OS-specific plugins from online...
Preparation of installation do file and package ZIP file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  1

macros:
            r(zipfile) : "_offline_bundle.zip"
             r(dofile) : "_offline_install.do"
                 r(os) : "Windows"
      r(download_mode) : "local"
       r(package_list) : "pkgtransfer"
```

</details>

### Online offline bundle

This stage downloads a fresh package descriptor and its required files from the recorded URL, targets macOS, verifies the version-3 archive metadata, and checks that the archive contains the `.ado`, `.sthlp`, `.pkg`, and `stata.toc` files.

<details>
<summary>Online bundle output (click to expand)</summary>

```stata
.     noisily pkgtransfer, download(online) limited(pkgtransfer)
>         os(MacOSX) dofile("_online_bundle_install.do")
>         zipfile("_online_bundle.zip")
```

```
Starting download of 1 packages...
Progress: 1/1 packages (100%)
Preparation of installation do file and package ZIP file completed!
```

```stata
.     noisily return list
```

```
scalars:
         r(N_packages) =  1

macros:
            r(zipfile) : "_online_bundle.zip"
             r(dofile) : "_online_bundle_install.do"
                 r(os) : "MacOSX"
      r(download_mode) : "online"
       r(package_list) : "pkgtransfer"
```

</details>

### Install a bundle and restore its online source

The demo installs the local bundle into a fresh destination PLUS directory, confirms that its tracker contains the embedded backup source, runs `restore`, and verifies both the restored source and the tracker backup.

<details>
<summary>Restore output (click to expand)</summary>

```stata
.     noisily pkgtransfer, restore
```

```
Restoring installation pathways to online sources...
Installation pathways restored!
```

```stata
.     noisily return list
```

```
macros:
                 r(os) : "Unix"
      r(download_mode) : "restore"
```

```stata
.     noisily type "`destination_plus'/stata.trk"
```

```
* 00000001
*! version 1.0.0
* Do not erase or edit this file
* It is used by Stata to track the ado and help
* files you have installed.
S https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer
N pkgtransfer.pkg
D 11 Aug 2026
U 1
d pkgtransfer feature demo
f p/pkgtransfer.ado
f p/pkgtransfer.sthlp
e
```

</details>

## Command Reference

### Syntax

```stata
pkgtransfer [, download(local|online) limited(pkglist) skip(pkglist) restore os(Windows|Unix|MacOSX) dofile(filename.do) zipfile(filename.zip)]
```

### Generated files

| Mode | Generated files and side effects |
|------|----------------------------------|
| Default | `pkgtransfer.do`, or the name supplied by `dofile()`, containing online installation commands |
| `download(online)` or `download(local)` | The installer do-file plus `pkgtransfer_files.zip`, or the name supplied by `zipfile()`; the archive contains package descriptors, package files, and `stata.toc` |
| `restore` | The current PLUS `stata.trk` is rewritten when backup URLs are present, and `stata.trk.backup` is created first |

Existing do-file and archive targets with the same names are replaced. Bundle creation refuses to reuse an existing `pkgtransfer_files` directory, preventing unrelated files in that directory from being archived or deleted; move or remove it before rerunning a download mode. Invocation-owned staging files are removed after an error. The generated offline installer references the exact archive name selected by `zipfile()`, uses only local macros, restores the caller's working directory, and stops if a package cannot be installed.

## Key Options

| Option | Default | Behavior |
|--------|---------|----------|
| `download(local|online)` | omitted | Selects offline bundle creation from local PLUS files or recorded online sources; when omitted, creates an online-install script only |
| `limited(pkglist)` | all eligible packages | Restricts the operation to the space-separated package names supplied; names must be present in `stata.trk` |
| `skip(pkglist)` | none | Excludes the exact package names supplied |
| `restore` | off | Restores embedded online source URLs in `stata.trk`; it may be used alone or with `download()` |
| `os(Windows|Unix|MacOSX)` | current `c(os)` | Sets the target OS used for the commented manual-cleanup command in an offline installer |
| `dofile(filename)` | `pkgtransfer.do` | Sets the generated do-file name; it must end in `.do` and may not contain shell metacharacters or quote characters |
| `zipfile(filename)` | `pkgtransfer_files.zip` | Sets the generated archive name; it must end in `.zip`, may not contain shell metacharacters or quote characters, and is valid only with `download()` |

The values for `download()` and `os()` are case-sensitive as shown. A package named in `limited()` that is not present in `stata.trk` produces an error, and the same package may not appear in both `limited()` and `skip()`. `zipfile()` is not valid without `download()`.

## Stored Results

After a standard non-restore run, `pkgtransfer` returns:

| Result | Type | Meaning |
|--------|------|---------|
| `r(N_packages)` | scalar | Number of selected packages represented in the generated installer or bundle |
| `r(package_list)` | local macro | Space-separated names of the selected packages |
| `r(download_mode)` | local macro | `script_only`, `online`, or `local` |
| `r(os)` | local macro | Target operating system |
| `r(dofile)` | local macro | Name or path used for the generated do-file |
| `r(zipfile)` | local macro | Name or path used for the archive when `download()` is specified |

For standalone `restore`, the returned `download_mode` is `restore` and `r(os)` is returned; the package-count, package-list, do-file, and archive results are not set. When `restore` is combined with `download()`, the returned mode reflects the download mode.

If `skip()` excludes every tracked package, `r(N_packages)` is 0, `r(package_list)` is empty, and the requested empty script or bundle is still created.

After package selection has succeeded, capturing a later output-write or archive failure leaves this full return surface available while preserving the original nonzero return code.

## Assumptions and Limits

- Only packages and sources recorded in the current PLUS directory's `stata.trk` are considered. Other adopath locations and untracked files are not reconstructed.
- The default mode does not fetch package files. Its generated commands require internet access on the destination, and GitHub-origin entries require the `github` command there.
- `download(online)` depends on the recorded source URLs and network availability. A missing or inaccessible required descriptor or package file aborts bundle creation.
- `download(local)` uses the copies currently installed in PLUS, but platform-specific `.plugin` files are downloaded from their sources because PLUS contains only the current platform build. A missing tracked file aborts bundle creation rather than producing a partial archive.
- `restore` works only when a bundle has embedded original-source backup records. It creates `stata.trk.backup` before changing the active tracking file.
- The generated offline installer does not add `replace` or `force` to its local `net install` commands. If the destination already has the package, edit the generated installer as needed.
- The command preserves the dataset in memory while it reads and writes package-tracking and transfer files.

## Version History

- **1.0.5** (2026-08-11): Offline bundles now emit canonical version-3 package and content metadata; preserve plugin directive case, normalized source/target paths, and descriptor terminators; support multiple plugins per package and SSC descriptor lookup; use unambiguous restore markers with legacy URL compatibility; and keep the QA runner from uninstalling the user's package.
- **1.0.4** (2026-08-11): Package selectors are normalized as ordered sets; duplicate tracker definitions fail before any transfer mode; local and online bundles preserve nested ordinary and plugin paths while rejecting traversal; failed side effects retain the analytical return surface; and generated offline installers preserve caller globals and the working directory.
- **1.0.3** (2026-08-10): Local bundles now resolve non-SSC plugin descriptors correctly, parse tab-delimited platform records, preserve nested plugin source paths, and update the correct package descriptor.
- **1.0.2** (2026-08-05): Skipping every tracked package now creates the requested empty script or bundle and returns `r(N_packages)=0` with an empty package list instead of failing with a no-observations error.
- **1.0.1** (2026-08-05): Generated offline installers now use the archive selected by `zipfile()` and propagate installation failures; standalone restore no longer enters script generation; caller state is protected; contradictory filters are rejected; and bundle creation refuses user-owned staging directories, removes its own failed staging, and aborts on missing required files.
- **1.0.0** (2026-07-10): Current Stata-Tools release with online transfer scripts, offline bundle creation, package filtering, and source restoration

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
