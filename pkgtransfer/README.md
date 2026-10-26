<p align="center"><img src="../_resources/logos/pkgtransfer_hex.svg" width="150" alt="pkgtransfer hex logo"></p>

# pkgtransfer — Move your installed packages to another machine

**Version 1.2.2** | 2026-10-26

[![version](https://img.shields.io/badge/version-1.2.2-1a5f91?style=flat-square)](#version-history) [![Stata 16+](https://img.shields.io/badge/Stata-16%2B-1a5f91?style=flat-square)](#requirements) [![MIT license](https://img.shields.io/badge/license-MIT-1a5f91?style=flat-square)](../LICENSE) [![Part of Stata-Tools](https://img.shields.io/badge/part%20of-Stata--Tools-0e3a5a?style=flat-square)](../README.md)

**[Quick Start](#quick-start)** · **[Installation](#installation)** · **[Worked Examples](#worked-examples)** · **[Key Options](#key-options)** · **[Stata-Tools](../README.md)** · **[Report a bug](https://github.com/tpcopeland/Stata-Tools/issues)**

`pkgtransfer` creates a Stata installation script or an offline package bundle from the packages tracked in the current PLUS directory, for users moving a Stata setup to another machine or sharing a controlled package set. It reproduces package *sources*, not installed *versions*; see [Assumptions and Limits](#assumptions-and-limits).

## Quick Start

After [installing](#installation), write an online reinstall script on the source machine and look at it:

```stata
pkgtransfer, dofile("_all_packages.do")
type "_all_packages.do"
```

```
Preparation of installation do file completed!

net install demofixture, replace from("https://example.org/stata/")
net install pkgtransfer, replace from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer/")
```

<sub>From `demo/console_scripts.md`, written by `demo/demo_pkgtransfer.do` against an isolated PLUS directory that tracks only `pkgtransfer` and a `demofixture` record; on your machine the script lists your own packages.</sub>

Move the do-file to a destination machine with internet access and run it there with `do _all_packages.do`. The default run writes only the script; it does not download package files.

## Features

- **A script or a self-contained bundle.** The default writes `ssc install`, `net install` or `github install` lines for each recorded online source; `download(online)` or `download(local)` builds a ZIP archive with an installer do-file for a destination without internet access.
- **Installed files when versions matter.** The script and `download(online)` install whatever each source offers when they run; `download(local)` carries the `.ado`, help and data files installed here.
- **Nothing overwritten silently.** An existing do-file or archive is kept unless you add `replace` (error 602 before anything is written), an existing `pkgtransfer_files` folder (the one an offline installer unpacks) never gets in the way or is archived, and staging files are removed after success or an error.
- **Platform files on request.** `os()` keeps only the target platform's plugin and other `g`/`G` files in a bundle; omitting it keeps every variant.
- **The way back to online sources.** After installing from a bundle, `restore` puts the original source URLs back into `stata.trk`, saving a numbered backup first and never overwriting an earlier one.

## Requirements

- Stata 16 or later
- A `stata.trk` file in the current PLUS directory, with the package and source records to transfer
- Internet access for `download(online)` and for running a generated online-install script
- The `github` command on the destination if the generated script contains `github install` lines

`download(local)` copies package files from the current PLUS directory, but it still reads each package's source descriptor and downloads files installed by platform-specific `g`/`G` records (plugins and any other file type).

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

- With no options, it writes a do-file containing `ssc install`, `net install`, or `github install` commands for eligible recorded sources. A source is eligible when `stata.trk` records it as a URL (`scheme://...`, for example `http://` or `https://`); packages installed from a local absolute path are omitted from the default and `download(online)` modes, and a note names them. Name them in `limited()` to include them. `download(local)` includes every tracked package.
- With `download(online)`, it downloads package descriptors and files from their recorded online sources, then creates an archive and an installer do-file.
- With `download(local)`, it copies the package files already present in the current PLUS directory, while obtaining files installed by `g`/`G` platform records from their sources. It identifies those files from each package's source descriptor, whatever their extension. Omit `os()` to bundle every platform variant, or specify it to retain only the target OS variants; a `g`-installed file with no record for the requested OS stops bundle creation (error 498). If a source descriptor cannot be read, a note names the package and its files are bundled as installed here. Two cases fail instead (error 601, naming the package): a package with a `.plugin` file, and a package installed from a `pkgtransfer` bundle whose `pkgtransfer_files` folder is no longer readable; for the second, run `pkgtransfer, restore` on its own first.
- With `restore`, it uses backup source metadata embedded by a transfer bundle to restore online URLs in `stata.trk`.

Standard output files are written in the current working directory. The offline installer unpacks the archive selected by `zipfile()`—`pkgtransfer_files.zip` by default—and installs the selected packages from the extracted local files with `net install ..., replace`, so an older copy on the destination is upgraded; it leaves the extracted folder in place because its cleanup commands are disabled for safety. The installer refers to the archive by its file name only, so keep the `.do` and `.zip` files together and run the installer from that directory (or set `package_dir` inside it).

Nested ordinary and plugin paths recorded by package descriptors are preserved in offline bundles. Parent-relative plugin sources are rebased into the archive, `g`/`G` and `F` installation semantics are preserved (an `F` file such as runtime `.dta` data is installed into PLUS on the destination, not dropped as an ancillary file), and unsafe absolute or remaining parent-traversal paths are rejected before a tracked file can escape the command-owned staging directory. Generated `.pkg` files and `stata.toc` use Stata's version-3 distribution format.

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
pkgtransfer, download(online) dofile(online_bundle.do) zipfile(online_bundle.zip)
```

Move `online_bundle.do` and `online_bundle.zip` to the destination machine, keep them in the same directory, and run:

```stata
do online_bundle.do
```

The generated script unpacks the archive before installing the selected packages. The file names are given explicitly because a run refuses to overwrite an existing `pkgtransfer.do` or `pkgtransfer_files.zip` (r(602)) unless `replace` is added.

### 3. Create a bundle from local PLUS files

This example bundles the installed copy of `pkgtransfer` itself. Replace the package name with one recorded in your `stata.trk` when preparing a different subset:

```stata
pkgtransfer, download(local) limited(pkgtransfer) dofile(local_setup.do) zipfile(local_setup.zip)
```

Move `local_setup.do` and `local_setup.zip` to the destination machine and run `do local_setup.do` there. Platform-specific plugin files, if any, are fetched while the bundle is being built. Add `os(Windows)`, `os(Unix)`, or `os(MacOSX)` to keep only that platform's plugins; omitting `os()` keeps all variants.

### 4. Limit or skip packages

The first run obtains a package name from the current tracking file. The subsequent runs create a one-package script and a script that excludes that package:

```stata
pkgtransfer, dofile(all_packages.do)
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

When embedded backup URLs are present, the command first copies the current PLUS `stata.trk` to `stata.trk.backup` (or `stata.trk.backup1`, `stata.trk.backup2`, ... when earlier backups exist; an existing backup is never overwritten), then replaces the source lines and removes those backup records. Every other tracker line is kept byte for byte. When no backup URLs are present, nothing is written. Standalone `restore` cannot be combined with `limited()`, `skip()`, `os()`, `dofile()`, `zipfile()`, or `replace`. If the installer upgraded an existing copy, `stata.trk` lists the package twice; `restore` still runs and names the duplicates, which can be removed with `ado dir` and `ado uninstall [#]`.

## Demo

`demo/demo_pkgtransfer.do` runs every mode against isolated temporary PLUS and PERSONAL directories, so it never touches your own packages, and removes every installer, archive and extracted file after checking them. The online-bundle section needs internet access. Run it from a Stata-Tools checkout root (it is not part of the `net install` payload):

```bash
stata-mp -b do pkgtransfer/demo/demo_pkgtransfer.do
```

| Output | What it shows |
|--------|---------------|
| [`demo/console_scripts.md`](demo/console_scripts.md) | Online-install scripts for all packages, `limited()` with a repeated name and `os(MacOSX)`, and `skip()` |
| [`demo/console_local_bundle.md`](demo/console_local_bundle.md) | `download(local)` with `os(Windows)` and custom `dofile()` and `zipfile()` names |
| [`demo/console_online_bundle.md`](demo/console_online_bundle.md) | `download(online)` with download progress, targeting macOS |
| [`demo/console_restore.md`](demo/console_restore.md) | Installing a bundle into a fresh PLUS directory, then `restore` and the rewritten `stata.trk` |

## Command Reference

### Syntax

```stata
pkgtransfer [, download(local|online) limited(pkglist) skip(pkglist) restore os(Windows|Unix|MacOSX) dofile(filename.do) zipfile(filename.zip) replace]
```

### Generated files

| Mode | Generated files and side effects |
|------|----------------------------------|
| Default | `pkgtransfer.do`, or the name supplied by `dofile()`, containing online installation commands |
| `download(online)` or `download(local)` | The installer do-file plus `pkgtransfer_files.zip`, or the name supplied by `zipfile()`; the archive contains package descriptors, package files, and `stata.toc` |
| `restore` | The current PLUS `stata.trk` is rewritten when backup URLs are present, after a copy is saved as `stata.trk.backup` (numbered `stata.trk.backup1`, ... if that name is taken) |

Bundle creation rejects conflicting source identities at the same archive path, including reserved descriptors and `stata.toc`.

An existing do-file or archive is not overwritten unless `replace` is specified (error 602 otherwise, before anything is written). Bundle creation stages its files in a unique temporary directory, so an existing `pkgtransfer_files` folder (the one an offline installer unpacks next to its archive) is never archived, deleted or in the way of a later bundle run. The staging directory is removed after success and after an error. The generated offline installer references the file name of the archive selected by `zipfile()` (without its directory), uses only local macros, restores the caller's working directory, and stops if a package cannot be installed.

## Key Options

| Option | Default | Behavior |
|--------|---------|----------|
| `download(local|online)` | omitted | Selects offline bundle creation from local PLUS files or recorded online sources; when omitted, creates an online-install script only |
| `limited(pkglist)` | all eligible packages | Restricts the operation to the space-separated package names supplied; names must be present in `stata.trk`. Without it, the default and `download(online)` modes omit packages installed from a local path (with a note) |
| `skip(pkglist)` | none | Excludes the exact package names supplied |
| `restore` | off | Restores embedded online source URLs in `stata.trk`; it may be used alone or with `download()`. With `download()`, the bundle is written first and then this machine's `stata.trk` is restored, as if the two commands were run in sequence; on a machine set up from a bundle whose folder has been removed, run `restore` alone first instead. Alone, it rejects `limited()`, `skip()`, `os()`, `dofile()`, `zipfile()`, and `replace` |
| `os(Windows|Unix|MacOSX)` | current `c(os)`; all plugin variants | Sets the installer target OS and limits offline bundles to matching plugin variants when explicitly supplied: `WIN*` for Windows, `LINUX*`/`UNIX*` for Unix, and `MAC*`/`OSX.*` (including the console platforms `OSX.ARM64` and `OSX.X8664`) for MacOSX |
| `dofile(filename)` | `pkgtransfer.do` | Sets the generated do-file name; it must end in `.do` and may not contain shell metacharacters or quote characters |
| `zipfile(filename)` | `pkgtransfer_files.zip` | Sets the generated archive name; it must end in `.zip`, may not contain shell metacharacters or quote characters, and is valid only with `download()` |
| `replace` | off | Allows an existing do-file or archive to be overwritten |

The values for `download()` and `os()` may be given in any case; `r(os)` and `r(download_mode)` use the spellings shown. A package named in `limited()` that is not present in `stata.trk` produces an error, and the same package may not appear in both `limited()` and `skip()`. `zipfile()` is not valid without `download()`.

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
- **Sources, not versions.** The default script and `download(online)` install whatever each recorded source offers when they run, so a package updated upstream since it was installed here arrives at its newer version. Use `download(local)` to carry the installed `.ado`, help, and data files.
- `download(local)` uses the copies currently installed in PLUS, but files installed by `g`/`G` platform records are downloaded from their *current* sources because PLUS contains only this platform's build, so a bundled plugin can come from a newer release than the bundled `.ado` file. Omitted `os()` downloads every platform variant; explicit `os()` downloads only matching variants. A missing tracked file aborts bundle creation rather than producing a partial archive.
- Packages from E. F. Haghish's GitHub pages are mapped to `https://raw.githubusercontent.com/haghish/<pkg>/master` and written as `github install haghish/<pkg>, stable`, which installs the latest release. `download(online)` fails for such a repository whose default branch is not `master`.
- `restore` works only when a bundle has embedded original-source backup records. A bundle made on a machine that was itself set up from a bundle carries the original source forward in `stata.trk`, so `restore` returns the first machine's source after any number of transfers. Until `restore` is run, `download(local)` on such a machine reads descriptors from the bundle folder that `stata.trk` records; if that folder is gone it stops with error 601 and asks for `pkgtransfer, restore` first. It saves a numbered backup of `stata.trk` before changing the active tracking file and never overwrites an earlier backup.
- The generated offline installer uses `net install ..., replace`, so it upgrades a copy already on the destination. Stata then records the package twice in `stata.trk`; other `pkgtransfer` modes refuse such a tracker (error 459) until the older copy is removed with `ado uninstall [#]`.
- The command preserves the dataset in memory while it reads and writes package-tracking and transfer files.

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.2.2** (2026-10-13): The "Copying OS-specific plugins from online..." progress line is now printed only when the bundle has platform-specific files to fetch; a bundle without them (including every plain `download(local)` bundle) no longer claims to go online. Demo output is stable: the restore log shows `<PLUS>` instead of a random temporary path. Bundle creation now stages in a unique temporary directory instead of `./pkgtransfer_files`, so running the offline installer (which unpacks into `pkgtransfer_files`) no longer makes the next bundle run in the same directory fail with r(602); the README examples now run in order in one directory, with Worked Examples 2 to 4 writing to distinct file names (`online_bundle.*`, `local_setup.*`, `all_packages.do`) because a run refuses to overwrite `pkgtransfer.do` or `pkgtransfer_files.zip` without `replace`.
- **1.2.1** (2026-10-12): `download(local)` on a machine set up from a bundle whose `pkgtransfer_files` folder has been removed now stops with error 601, naming the package and `pkgtransfer, restore`, instead of failing with a bare `file not found` (plugin packages) or shipping this machine's build of a `g`/`G` file under another `os()` (other platform files). An unreadable descriptor for a `.plugin` package names the package, the descriptor, and `skip()`. The help no longer suggests `download()` combined with `restore` for such a machine, and the `.pkg` description is accurate.
- **1.2.0** (2026-10-12): **Behaviour change:** an existing do-file or ZIP file is no longer overwritten silently; add the new `replace` option to scripts that rerun `pkgtransfer` with the same output names. Offline bundles keep `F` records, so runtime data a package forces into PLUS (for example `F data.dta`) is installed on the destination instead of being dropped; `download(local)` writes every tracked file as `F`. `download(local)` identifies `g`/`G`-installed files from each source descriptor rather than by the `.plugin` extension, so `os()` also filters platform-specific `.jar`, `.dll`, data, and other files. A second transfer from a bundle-installed machine carries the original source forward, and `restore` picks the original source from bundles made by earlier versions. `download()` and `os()` accept any case. The duplicate-tracker error names `ado dir` and `ado uninstall [#]`. The help file gains Remarks on source-versus-version fidelity.
- **1.1.3** (2026-10-12): `restore` and bundle creation read and write tracker and descriptor files line by line, so lines containing `|`, blank lines, quotes, tabs, and long lines are no longer truncated or dropped. The offline installer names the archive by file name only and installs with `replace`. `os(MacOSX)` keeps the `OSX.ARM64`/`OSX.X8664` console platforms. The default and `download(online)` modes name the local-path packages they omit, and online sources are recognized by URL scheme. `restore` keeps earlier backups (numbered), backs up only when it changes the tracker, runs on trackers that list a package twice, and rejects options it cannot honor. Plugin records match whole file names, and `d` text can no longer reassign package records in local bundles. `download(online)` parses tab-separated descriptor records (for example `traj`), and its restore marker keeps the tracker's source exactly as recorded.

<details><summary>Earlier versions</summary>

- **1.1.2** (2026-09-30): Bundle creation leaves a scalar named `cv` in the caller's session unchanged.
- **1.1.1** (2026-09-29): Reject conflicting bundle payload and metadata paths; resolve output paths before staging and confirm outputs after cleanup; select plugin platforms independently of filenames; bootstrap the selected github package with net install. QA now preserves caller installations across every suite.
- **1.1.0** (2026-08-16): Offline bundles retain every OS plugin variant by default, while explicit `os(Windows)`, `os(Unix)`, or `os(MacOSX)` limits both plugin files and descriptor records to the selected platform; source files are no longer duplicated under their installation target names inside archives.
- **1.0.5** (2026-08-11): Offline bundles now emit canonical version-3 package and content metadata; preserve plugin directive case, normalized source/target paths, and descriptor terminators; support multiple plugins per package and SSC descriptor lookup; use unambiguous restore markers with legacy URL compatibility; and keep the QA runner from uninstalling the user's package.
- **1.0.4** (2026-08-11): Package selectors are normalized as ordered sets; duplicate tracker definitions fail before any transfer mode; local and online bundles preserve nested ordinary and plugin paths while rejecting traversal; failed side effects retain the analytical return surface; and generated offline installers preserve caller globals and the working directory.
- **1.0.3** (2026-08-10): Local bundles now resolve non-SSC plugin descriptors correctly, parse tab-delimited platform records, preserve nested plugin source paths, and update the correct package descriptor.
- **1.0.2** (2026-08-05): Skipping every tracked package now creates the requested empty script or bundle and returns `r(N_packages)=0` with an empty package list instead of failing with a no-observations error.
- **1.0.1** (2026-08-05): Generated offline installers now use the archive selected by `zipfile()` and propagate installation failures; standalone restore no longer enters script generation; caller state is protected; contradictory filters are rejected; and bundle creation refuses user-owned staging directories, removes its own failed staging, and aborts on missing required files.
- **1.0.0** (2026-07-10): Current Stata-Tools release with online transfer scripts, offline bundle creation, package filtering, and source restoration

</details>

## Author

Timothy P Copeland, Karolinska Institutet

Questions and bug reports: [GitHub issues](https://github.com/tpcopeland/Stata-Tools/issues). Please include the first line of `which pkgtransfer` and your Stata version.

To cite: Copeland TP. *pkgtransfer: Move your installed packages to another machine*. Stata-Tools, https://github.com/tpcopeland/Stata-Tools/tree/main/pkgtransfer. Please give the version you used (`which pkgtransfer` prints it).

## License

MIT (see [LICENSE](../LICENSE))
