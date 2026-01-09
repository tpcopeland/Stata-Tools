# forestpy

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![Python](https://img.shields.io/badge/Python-3.6%2B-blue) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Stata wrapper for the Python [forestplot](https://github.com/lsys/forestplot) package - create publication-ready forest plots with minimal configuration.

## Installation

```stata
net install forestpy, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/forestpy")
```

## Requirements

- **Stata 16.0+** with Python integration enabled
- **Python 3.6+** with the following packages (automatically installed on first use):
  - pandas
  - numpy
  - matplotlib
  - forestplot

## Description

`forestpy` creates publication-ready forest plots using the Python forestplot package. Forest plots are commonly used to visualize:

- Meta-analysis results
- Regression coefficients across models
- Correlation coefficients
- Odds ratios, hazard ratios, and risk ratios
- Any estimate with confidence intervals

The command automatically handles data transfer between Stata and Python, manages Python dependencies, and provides extensive customization options.

## Syntax

```stata
forestpy [if] [in], estimate(varname) varlabel(varname) [options]
```

### Required Options

| Option | Description |
|--------|-------------|
| `estimate(varname)` | Variable containing point estimates |
| `varlabel(varname)` | String variable containing row labels |

### Optional Options

| Option | Description |
|--------|-------------|
| `ll(varname)` | Lower confidence limit variable |
| `hl(varname)` | Upper confidence limit variable |
| `groupvar(varname)` | Variable for grouping rows |
| `grouporder(string)` | Order of groups (space-separated) |
| `sort` | Sort rows by estimate value |
| `logscale` | Use logarithmic x-axis (for OR, HR, RR) |
| `xlabel(string)` | X-axis label |
| `decimal(#)` | Decimal precision (default: 2) |
| `figsize(# #)` | Figure width and height (default: 4 8) |
| `color_alt_rows` | Shade alternate rows |
| `table` | Display as table format |
| `annote(varlist)` | Variables for left-side annotations |
| `pval(varname)` | P-value variable |
| `saving(filename)` | Save plot to file |
| `replace` | Replace existing file |

## Examples

### Basic Forest Plot

```stata
* Create example data
clear
input str20 label estimate ll hl
"Age" 0.15 0.08 0.22
"Sex (Male)" -0.05 -0.12 0.02
"BMI" 0.28 0.21 0.35
"Smoking" 0.42 0.33 0.51
"Diabetes" 0.35 0.25 0.45
end

* Create forest plot
forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    xlabel("Correlation coefficient")
```

### Forest Plot with Groups

```stata
clear
input str20 label estimate ll hl str15 group
"Age" 0.15 0.08 0.22 "Demographics"
"Sex (Male)" -0.05 -0.12 0.02 "Demographics"
"BMI" 0.28 0.21 0.35 "Clinical"
"Smoking" 0.42 0.33 0.51 "Clinical"
end

forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    groupvar(group) xlabel("Effect size")
```

### Odds Ratio Plot (Log Scale)

```stata
clear
input str20 label or or_ll or_hl
"Treatment A" 1.45 1.12 1.88
"Treatment B" 0.82 0.65 1.03
"Treatment C" 2.15 1.68 2.75
end

forestpy, estimate(or) varlabel(label) ll(or_ll) hl(or_hl) ///
    logscale xlabel("Odds Ratio") saving(odds_ratio.png, replace)
```

### Forest Plot with Annotations

```stata
clear
input str20 label estimate ll hl n pvalue
"Variable 1" 0.25 0.15 0.35 500 0.001
"Variable 2" 0.18 0.08 0.28 450 0.012
"Variable 3" -0.12 -0.22 -0.02 520 0.025
end

forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///
    annote(n) annotehead(N) pval(pvalue)
```

## Output Formats

Supported output formats via `saving()`:
- PNG (default)
- PDF
- SVG
- EPS
- TIFF

## Stored Results

| Result | Description |
|--------|-------------|
| `r(N)` | Number of observations plotted |
| `r(estimate)` | Estimate variable name |
| `r(varlabel)` | Label variable name |
| `r(filename)` | Output filename (if saved) |

## Troubleshooting

### Python not found

If you see "Python integration not available", ensure:
1. Your Stata version is 16.0 or later
2. Python is installed and configured in Stata
3. Run `python query` to check Python configuration

### Package installation fails

If automatic package installation fails:
```stata
python: import subprocess; subprocess.check_call(['pip', 'install', 'forestplot'])
```

Or install manually from command line:
```bash
pip install pandas numpy matplotlib forestplot
```

## Credits

This Stata wrapper uses the Python [forestplot](https://github.com/lsys/forestplot) package by Lucas Shen.

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.0, 2026-01-09
