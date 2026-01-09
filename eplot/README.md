# eplot

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Unified effect plotting command for creating forest plots and coefficient plots in Stata.

## Overview

`eplot` provides a single, intuitive interface for visualizing effect sizes with confidence intervals from:

- **Data in memory** - Variables containing effect sizes and confidence limits (e.g., meta-analysis results)
- **Stored estimates** - Coefficients from regression models

## Installation

```stata
net install eplot, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/eplot")
```

## Syntax

### From data in memory

```stata
eplot esvar lcivar ucivar [if] [in], [options]
```

### From stored estimates

```stata
eplot [namelist], [options]
```

Use `.` to refer to active estimation results.

## Key Features

- **Unified syntax** for both data and estimates modes
- **Group labeling** with `groups()` option
- **Section headers** with `headers()` option
- **Eform transformation** for odds ratios, hazard ratios, etc.
- **Weighted markers** that scale with study/observation weights
- **Diamond rendering** for pooled effects (subgroup and overall)
- **Horizontal or vertical** layout options
- **Full customization** via standard Stata graph options

## Examples

### Basic Forest Plot

```stata
// Create sample data
clear
input str20 study es lci uci weight
"Smith 2020"    -0.16  -0.36  0.03  15.2
"Jones 2021"    -0.33  -0.54 -0.12  18.4
"Brown 2022"    -0.09  -0.25  0.06  22.1
"Wilson 2023"   -0.39  -0.65 -0.12  12.8
"Overall"       -0.24  -0.34 -0.13   .
end

gen byte type = cond(study=="Overall", 5, 1)

eplot es lci uci, labels(study) weights(weight) type(type)
```

### Odds Ratio Forest Plot

```stata
eplot es lci uci, labels(study) weights(weight) type(type) ///
    eform effect("Odds Ratio") ///
    title("Meta-analysis of Treatment Effect")
```

### Coefficient Plot from Regression

```stata
sysuse auto, clear
regress price mpg weight length foreign

eplot ., drop(_cons) ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight (lbs)" ///
               length = "Length (inches)" ///
               foreign = "Foreign Make") ///
    xline(0) ///
    title("Determinants of Car Price")
```

### Grouped Effects

```stata
regress price mpg weight length turn foreign rep78

eplot ., drop(_cons) ///
    groups(mpg weight length turn = "Vehicle Specs" ///
           foreign rep78 = "Other Factors") ///
    title("Grouped Coefficient Plot")
```

## Options

### Data Specification

| Option | Description |
|--------|-------------|
| `labels(varname)` | Variable containing row labels |
| `weights(varname)` | Variable for marker sizing |
| `type(varname)` | Row type (1=effect, 3=subgroup, 5=overall, 0=header) |

### Coefficient Selection

| Option | Description |
|--------|-------------|
| `keep(coeflist)` | Keep specified coefficients |
| `drop(coeflist)` | Drop specified coefficients (e.g., `drop(_cons)`) |
| `rename(spec)` | Rename coefficients |

### Labeling

| Option | Description |
|--------|-------------|
| `coeflabels(spec)` | Custom labels for coefficients/effects |
| `groups(spec)` | Define groups with labels |
| `headers(spec)` | Insert section headers |

### Transform

| Option | Description |
|--------|-------------|
| `eform` | Exponentiate (OR, HR, RR) |
| `rescale(#)` | Multiply estimates by # |

### Layout

| Option | Description |
|--------|-------------|
| `horizontal` | Horizontal layout (default) |
| `vertical` | Vertical layout |
| `xline(numlist)` | Reference lines |
| `null(#)` | Null line position |
| `nonull` | Suppress null line |

### Display

| Option | Description |
|--------|-------------|
| `effect(string)` | Column header for effects |
| `dp(#)` | Decimal places |
| `level(#)` | Confidence level |
| `noci` | Suppress confidence intervals |

## Type Variable Values

When using `type(varname)`:

| Value | Meaning | Display |
|-------|---------|---------|
| 1 | Effect/Study | Marker + CI |
| 2 | Missing | Text "(Insufficient data)" |
| 3 | Subgroup total | Diamond |
| 5 | Overall total | Diamond |
| 0 | Header | Bold text |
| 6 | Blank | Spacing |

## Stored Results

`eplot` stores the following in `r()`:

| Result | Description |
|--------|-------------|
| `r(N)` | Number of effects plotted |
| `r(cmd)` | Graph command executed |

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.0, 2026-01-09

## Acknowledgments

Inspired by:
- `forestplot` by David Fisher (UCL)
- `coefplot` by Ben Jann (University of Bern)
