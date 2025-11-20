# regtab

![Stata 17+](https://img.shields.io/badge/Stata-17%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Format and export regression tables to Excel.

## Description

regtab formats collected regression tables and exports point estimates, 95% confidence intervals, and p-values to Excel with professional formatting. The command works with Stata 17+ collect commands to create publication-ready regression tables.

## Dependencies

Requires **collect** commands (Stata 17.0 or higher).

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/regtab
net install regtab
```

## Syntax

```stata
regtab, xlsx(filename) sheet(sheetname) [options]
```

### Required options

- **xlsx(filename)** - Excel output file (must have .xlsx extension)
- **sheet(sheetname)** - Excel sheet name

### Optional formatting

- **title(string)** - Table title (appears in cell A1)
- **coef(string)** - Label for coefficient column (e.g., "OR", "HR", "Coef.")
- **models(string)** - Model labels separated by backslash
- **sep(string)** - CI separator (default: ", ")
- **noint** - Drop intercept row
- **nore** - Drop random effects rows

## Workflow

1. Run regressions with collect commands
2. Format and export with regtab

## Example

```stata
* Run models with collect
sysuse auto, clear
collect clear
collect: logit foreign mpg
collect: logit foreign mpg weight
collect: logit foreign mpg weight price

* Export formatted table
regtab, xlsx(results.xlsx) sheet(Models) ///
    models(Model 1 \ Model 2 \ Model 3) ///
    coef(OR) title(Logistic Regression Results)
```

## Dialog interface

Access the graphical interface:
```stata
db regtab
```

Optional menu integration:
```stata
do regtab_menu_setup.do
```

## Output format

- Professional Excel formatting
- Automatic column widths
- Point estimates, 95% CI, and p-values
- Publication-ready appearance

## Author

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet

## License

MIT License - See repository for details

## Help

For more information:
```stata
help regtab
```

See also: regtab_dialog.md for detailed dialog documentation
