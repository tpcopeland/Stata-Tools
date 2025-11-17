# massdesas

Batch convert SAS datasets to Stata format.

## Description

massdesas converts all .sas7bdat files to .dta files within a given directory and all subdirectories. The command provides options for erasing original SAS files after conversion and converting variable names to lowercase.

## Dependencies

Requires the **usesas** command and Java:
- Install usesas: `ssc install usesas`
- Java must be installed and configured for SAS file reading

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/massdesas
net install massdesas
```

## Syntax

```stata
massdesas [, directory(directory_name) erase lower]
```

### Options

- **directory(directory_name)** - Directory containing .sas7bdat files (including subdirectories)
- **erase** - Delete .sas7bdat files after generating .dta files
- **lower** - Convert all variable names to lowercase

## Example

```stata
* Convert all SAS files in a directory
massdesas, directory("C:/data/sas_files")

* Convert with lowercase variables and erase originals
massdesas, directory("C:/data/sas_files") lower erase
```

## Note

Use the erase option with caution, as it permanently deletes the original SAS files.

## Requirements

Stata 14.0 or higher

## Author

Timothy P Copeland, University of California, San Francisco

## Help

For more information:
```stata
help massdesas
```
