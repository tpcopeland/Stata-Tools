# datamap

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Generate privacy-safe dataset documentation.

## Description

datamap generates comprehensive, privacy-safe documentation for Stata datasets. It automatically classifies variables as categorical, continuous, date, string, or excluded, and generates appropriate documentation for each type. The command is designed for researchers who need to share dataset descriptions without revealing sensitive information.

The package includes two commands:
- **datamap** - Main command for generating dataset documentation
- **datadict** - Data dictionary utility (helper command)

## Dependencies

None - uses only built-in Stata commands.

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datamap
net install datamap
```

## Syntax

```stata
datamap, input_option [options]
```

### Input options (choose one)

- **single(filename)** - Document a single Stata dataset
- **directory(path)** - Document all .dta files in a directory
- **filelist(filename)** - Document datasets listed in a text file

### Key options

- **output(filename)** - Name of output file (default: datamap.txt)
- **exclude(varlist)** - Exclude sensitive variables from documentation
- **datesafe** - Show only date ranges, not individual values
- **nostats** - Suppress summary statistics
- **nofreq** - Suppress frequency tables
- **separate** - Create separate output file for each dataset

## Examples

```stata
* Document a single dataset with privacy protection
datamap, single(patients.dta) exclude(patient_id patient_name) datesafe

* Document all datasets in current directory
datamap, directory(.)

* Create separate documentation files
datamap, directory(.) separate
```

## Features

- Automatic variable classification
- Privacy controls for sensitive data
- Flexible output options
- Support for multiple input modes
- Date-safe mode for protecting date-based identifiers

## Requirements

Stata 16.0 or higher

## License

MIT License - See LICENSE file for details

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## Help

For more information:
```stata
help datamap
help datadict
```
