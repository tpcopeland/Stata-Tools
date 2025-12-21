# outlier

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Outlier detection toolkit with multiple methods: IQR, standard deviation, Mahalanobis distance, and regression influence.

## Description

`outlier` is a comprehensive outlier detection toolkit that supports multiple detection methods and provides options to flag, winsorize, or exclude outliers with detailed reporting.

Key features:
- Multiple detection methods (IQR, SD, Mahalanobis, influence)
- Flag, winsorize, or exclude outliers
- Group-specific outlier detection
- Excel report export
- Detailed summary statistics

## Installation

```stata
net install outlier, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/outlier")
```

## Syntax

```stata
outlier varlist [if] [in] [, options]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| **method(string)** | iqr | Detection method: iqr, sd, mahal, influence |
| **multiplier(#)** | 1.5/3 | IQR/SD multiplier |
| **maha_p(#)** | 0.001 | Mahalanobis p-value threshold |
| **action(string)** | flag | Action: flag, winsorize, exclude |
| **generate(name)** | - | Prefix for generated variables |
| **replace** | off | Allow replacing existing variables |
| **by(varname)** | - | Detect outliers within groups |
| **report** | off | Display detailed report |
| **xlsx(filename)** | - | Export report to Excel |

## Detection Methods

### IQR Method (default)
Outliers are values below Q1 - k×IQR or above Q3 + k×IQR.
- Default k = 1.5 (mild outliers)
- Use k = 3 for extreme outliers
- Robust to existing outliers

### SD Method
Outliers are values more than k standard deviations from the mean.
- Default k = 3
- Assumes approximate normality
- Sensitive to outliers

### Mahalanobis Distance
Multivariate method detecting unusual combinations of values.
- Requires 2+ variables
- Uses chi-square p-value threshold
- Detects outliers normal in each variable but unusual together

### Influence Diagnostics
Identifies observations influencing regression results.
- Uses Cook's D, leverage, studentized residuals
- First variable is outcome, rest are predictors
- Flags high-influence observations

## Examples

### Basic IQR detection

```stata
sysuse auto, clear
outlier price mpg weight
```

### SD-based with custom threshold

```stata
outlier price, method(sd) multiplier(2.5)
```

### Winsorize outliers

```stata
outlier price, action(winsorize) generate(w_)
```

### Multivariate Mahalanobis

```stata
outlier price mpg weight, method(mahal) generate(maha_)
```

### Detection within groups

```stata
outlier price, by(foreign) report
```

### Export to Excel

```stata
outlier price mpg weight, xlsx(outliers.xlsx)
```

## Actions

| Action | Description |
|--------|-------------|
| **flag** | Create indicator variables (1=outlier, 0=not) |
| **winsorize** | Replace outliers with boundary values |
| **exclude** | Set outliers to missing |

## Stored Results

`outlier` stores the following in `r()`:

**Scalars:**

| Result | Description |
|--------|-------------|
| `r(N)` | Number of observations |
| `r(n_outliers)` | Total outliers detected |
| `r(multiplier)` | Multiplier used (iqr/sd) |
| `r(lower)` | Lower bound (single variable) |
| `r(upper)` | Upper bound (single variable) |

**Matrices:**

| Result | Description |
|--------|-------------|
| `r(results)` | Matrix of results by variable |

## Requirements

- Stata 16.0 or higher

## Version

- **Version 1.0.0** (21 December 2025): Initial release

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## See Also

- `help winsor2` - Winsorizing command
- `help summarize` - Summary statistics
