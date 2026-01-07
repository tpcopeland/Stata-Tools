# tabtools

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

A comprehensive suite of Stata commands for exporting publication-ready tables to Excel.

## Installation

```stata
net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tabtools")
```

## Commands

| Command | Description | Stata Version |
|---------|-------------|---------------|
| `table1_tc` | Descriptive statistics table (Table 1) with automatic statistical tests | 16+ |
| `regtab` | Format regression results from any model | 17+ |
| `effecttab` | Format treatment effects and margins results | 17+ |
| `gformtab` | Format g-formula mediation analysis results | 16+ |
| `stratetab` | Combine and format strate incidence rate outputs | 17+ |
| `tablex` | General table export for any Stata table | 17+ |

## Quick Examples

### Descriptive Statistics (Table 1)

```stata
sysuse auto, clear
table1_tc, by(foreign) ///
    vars(price contn \ mpg contn \ rep78 cat \ weight contn) ///
    excel("table1.xlsx") sheet("Baseline") title("Table 1. Baseline Characteristics")
```

### Regression Results

```stata
sysuse auto, clear
collect: logit foreign price mpg weight
regtab, xlsx(regression.xlsx) sheet("Model1") title("Logistic Regression") coef(OR)
```

### Treatment Effects

```stata
teffects ipw (outcome) (treatment age sex), ate
effecttab, xlsx(effects.xlsx) sheet("ATE") title("Treatment Effect")
```

### General Tables

```stata
sysuse auto, clear
table foreign rep78, statistic(mean price) statistic(sd price)
tablex using summary.xlsx, sheet("Summary") title("Price by Origin and Repair")
```

### Incidence Rates

```stata
stratetab, using(rate_exp1 rate_exp2 rate_exp3) xlsx(rates.xlsx) outcomes(3) ///
    outlabels("Outcome 1 \ Outcome 2 \ Outcome 3") ///
    title("Incidence Rates per 1,000 Person-Years")
```

## Features

All commands in the tabtools suite share consistent formatting:

- **Automatic column widths** calculated from content length
- **Professional borders** with customizable styles (thin/medium)
- **Merged headers** for title rows and grouped columns
- **Consistent fonts** (default: Arial 10pt)
- **Dynamic p-value formatting** (more decimals for smaller p-values)

## Documentation

Each command has comprehensive help documentation:

```stata
help table1_tc
help regtab
help effecttab
help gformtab
help stratetab
help tablex
```

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.0, 2026-01-07
