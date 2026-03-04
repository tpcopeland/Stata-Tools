# pkgtransfer

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Transfer installed Stata packages between installations.

## Description

`pkgtransfer` facilitates transferring installed packages from one Stata installation to another. It can generate a do-file with the necessary `net install`, `ssc install`, or `github install` commands for online installation on a new machine. Alternatively, it can download all the package files and create a local installation script and a ZIP archive for offline installation.

The command works by reading the `stata.trk` file in your current PLUS directory to identify installed packages and their sources. It can handle packages installed from various sources, including SSC, personal websites, and GitHub (using the [github](https://github.com/haghish/github) command).

**Important Note:** It is strongly suggested that when using the `download` option, you first run `pkgtransfer` without options to save all the original package installation commands for online installation (i.e., `pkgtransfer`) and move the resulting `pkgtransfer.do` to a separate folder before running with the `download` option.

## Dependencies

**Required:**
- None - uses only built-in Stata commands

**Optional:**
- **github** command - Only needed if you have packages installed from GitHub
  - Install with: `net install github, from("https://haghish.github.io/github/")`

## Installation

```stata
net install pkgtransfer, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer")
```

## Syntax

```stata
pkgtransfer [, download limited(pkglist)]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `download` | online mode | Specifies that you want to create a ZIP file containing all the package files and a do-file (`pkgtransfer_local.do`) for installing the packages locally. This is useful for machines without internet access or for creating backups of your installed packages. When `download` is not specified, `pkgtransfer` generates a do-file (`pkgtransfer.do`) with online installation commands. |
| `limited(pkglist)` | all packages | Restricts the operation to a specific set of packages. `pkglist` should be a space-separated list of package names, exactly as they appear in the `stata.trk` file. For example, `limited(estout outreg2)`. When not specified, `pkgtransfer` processes all packages listed in the `stata.trk` file. |

## Output Files

### Without `download` Option:
- **pkgtransfer.do** - Do-file containing `net install`, `ssc install`, or `github install` commands for online installation

### With `download` Option:
- **pkgtransfer_local.do** - Do-file with local installation commands
- **pkgtransfer_files.zip** - ZIP archive containing all package files

## Workflow Examples

### Workflow 1: Online Installation (Internet Available on New Machine)

On your old machine:
```stata
pkgtransfer
```

Transfer `pkgtransfer.do` to your new machine, then run:
```stata
do pkgtransfer.do
```

### Workflow 2: Offline Installation (No Internet on New Machine)

On your old machine:
```stata
pkgtransfer, download
```

Transfer both `pkgtransfer_local.do` and `pkgtransfer_files.zip` to your new machine. Extract the ZIP file, then run:
```stata
do pkgtransfer_local.do
```

### Workflow 3: Best Practice (Save Both Online and Offline Versions)

On your old machine:
```stata
* First, generate online installation script
pkgtransfer

* Move the file to a safe location
copy pkgtransfer.do ~/backup/pkgtransfer_online.do, replace

* Then generate offline installation package
pkgtransfer, download
```

This gives you both options: fast online installation and an offline backup.

## Examples

### Example 1: Generate Online Installation Script

```stata
pkgtransfer
```

Generates a do-file (`pkgtransfer.do`) for online installation of all packages listed in your `stata.trk` file.

### Example 2: Create Offline Installation Package

```stata
pkgtransfer, download
```

Downloads all packages and creates a local installation script (`pkgtransfer_local.do`) and a ZIP archive (`pkgtransfer_files.zip`).

### Example 3: Transfer Only Specific Packages (Online)

```stata
pkgtransfer, limited(estout outreg2)
```

Generates a do-file for online installation of only the "estout" and "outreg2" packages.

### Example 4: Transfer Only Specific Packages (Offline)

```stata
pkgtransfer, download limited(estout outreg2)
```

Downloads only the "estout" and "outreg2" packages and creates a local installation script and ZIP archive.

### Example 5: Transfer Common Regression and Table Packages

```stata
pkgtransfer, limited(estout outreg2 coefplot reghdfe)
```

Creates an installation script for commonly used regression and output packages.

## How It Works

1. **Reads stata.trk**: The command reads the `stata.trk` file in your PLUS directory, which tracks all installed packages
2. **Identifies Sources**: It identifies where each package was installed from (SSC, net install, GitHub, etc.)
3. **Generates Commands**: Creates appropriate installation commands (`ssc install`, `net install`, or `github install`)
4. **Downloads (if requested)**: If the `download` option is used, it downloads all package files
5. **Creates Output**: Generates do-file(s) and optionally a ZIP archive

## Use Cases

- **Migrating to a New Computer**: Transfer all your packages to a new Stata installation
- **Setting Up Multiple Machines**: Standardize packages across multiple workstations
- **Offline Installation**: Install packages on machines without internet access
- **Backup**: Create a backup of your current package configuration
- **Team Collaboration**: Share a standard package setup with collaborators
- **Reproducibility**: Document and replicate package environments for research projects

## Remarks

### Important Notes

- The command processes packages based on the `stata.trk` file, which is automatically maintained by Stata
- Packages installed via different methods (SSC, net install, GitHub) are all supported
- The `limited()` option is case-sensitive and must match package names exactly as they appear in `stata.trk`
- When using `download`, ensure you have sufficient disk space for all package files

### Best Practices

1. **Test First**: Run `pkgtransfer` without options first to verify which packages will be included
2. **Keep Both Versions**: Save both online and offline installation scripts for flexibility
3. **Document**: Add comments to the generated do-files documenting when they were created
4. **Regular Backups**: Periodically run `pkgtransfer, download` to maintain backups of your package setup
5. **Version Control**: Store the generated do-files in version control for reproducibility

## Requirements

- Stata 14.0 or higher
- No external dependencies for basic functionality
- `github` command required only if you have GitHub-installed packages

## Version History

- **Version 1.0.2** (5 December 2025): Minor updates
- **Version 1.0.1** (3 December 2025): Security and validation improvements
  - Added file path sanitization for dofile() and zipfile() options
  - Fixed file extension validation to check file endings
  - Removed debugging code from production
- **Version 1.0.0** (2 December 2025): GitHub publication release

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## See Also

- `help ssc` - SSC package installation
- `help net` - Network installation commands
- `help adoupdate` - Update installed packages
- [GitHub command](https://github.com/haghish/github) - Install packages from GitHub

## Getting Help

For more detailed information, you can access the Stata help file:
```stata
help pkgtransfer
```
