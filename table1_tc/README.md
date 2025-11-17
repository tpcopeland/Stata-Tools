# table1_tc

Create publication-ready Table 1 of baseline characteristics.

## Description

table1_tc generates descriptive statistics tables ("Table 1") for manuscripts. It summarizes continuous and categorical variables, optionally stratified by group, with automatic statistical test selection and p-values. The command is an extension of Phil Clayton's table1 and Mark Chatfield's table1_mc, with enhanced Excel export capabilities.

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/table1_tc
net install table1_tc
```

## Syntax

```stata
table1_tc [if] [in] [fweight], vars(varlist_with_types) [options]
```

### Required option

**vars(string)** - Variables with types separated by backslash

Variable types:
- **contn** - Normal continuous (mean, SD)
- **contln** - Log-normal continuous (geometric mean)
- **conts** - Skewed continuous (median, IQR)
- **cat** - Categorical (chi-square test)
- **cate** - Categorical exact (Fisher's exact test)
- **bin** - Binary (chi-square test)
- **bine** - Binary exact (Fisher's exact test)

### Key options

- **by(varname)** - Stratify by group
- **onecol** - Single column for categorical variables
- **format(string)** - Format for continuous variables
- **excel options** - Export to Excel with formatting

## Examples

```stata
* Basic Table 1
sysuse auto, clear
table1_tc, vars(price contn \ mpg conts \ foreign bin)

* Stratified with p-values
table1_tc, vars(price contn \ mpg conts \ foreign bin) by(rep78)

* Export to Excel
table1_tc, vars(age contn \ bmi conts \ female bin \ race cat) ///
    by(treatment) ///
    excel(table1.xlsx, sheet(Baseline) replace)
```

## Dialog interface

Access the graphical interface:
```stata
db table1_tc
```

Optional menu integration:
```stata
do table1_tc_menu_setup.do
```

## Features

- Automatic statistical test selection
- Professional Excel export
- Flexible formatting options
- Support for multiple variable types
- Custom group labels and formatting

## Requirements

Stata 14.2 or higher

## Author

Timothy P Copeland
Fork of table1_mc by Mark Chatfield

## Help

For more information:
```stata
help table1_tc
```

See also: table1_tc_dialog.md for detailed dialog documentation
