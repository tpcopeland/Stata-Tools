# eplot

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Unified effect plotting command for creating forest plots and coefficient plots in Stata.

## Overview

`eplot` provides a single, intuitive interface for visualizing effect sizes with confidence intervals from:

- **Data in memory** - Variables containing effect sizes and confidence limits (e.g., meta-analysis results)
- **Stored estimates** - Coefficients from regression models, with multi-model comparison
- **Matrices** - Stata matrices with (b, se) or (b, lci, uci) columns

## Installation

```stata
net install eplot, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/eplot")
```

## Key Features

- **Multi-model comparison** - Plot coefficients from 2+ models side by side with automatic coloring and legend
- **Values annotation** - Display formatted effect text (e.g., "0.80 (0.72, 0.88)") beside each row
- **Unified syntax** for data, estimates, and matrix modes
- **Group labeling** with bold section headers via `groups()` and `headers()`
- **Subgroup spacing** with `gap()` between grouped sections, without dummy blank rows
- **Eform transformation** for odds ratios, hazard ratios, etc.
- **Weighted markers** that scale with study/observation weights
- **Diamond rendering** for pooled effects (subgroup and overall)
- **Sort/order** coefficients by effect size or explicit ordering
- **Capped CI lines** with the `cicap` option
- **Color palette** for multi-model with full marker/CI customization
- **Matrix mode** for plotting from pre-computed matrices
- **Auto variable labels** with factor value label expansion in estimates mode
- **Style presets** (`forest`, `coef`, `lancet`, `jama`, `nejm`, `bmj`) for quick publication-ready styling
- **Significance stars** (*, **, ***) and **color-coded significance** (sig vs non-sig)
- **Favors annotation** (`favors("Favors Treatment" "Favors Control")`) below x-axis
- **Effect-axis tick control** with `xlabel()` mapped to the effect axis in either layout
- **Auto-detect effect labels** from `e(cmd)` (Odds Ratio after logit, Hazard Ratio after stcox, IRR after poisson)
- **Prediction intervals** (dashed whiskers behind CIs) for meta-analysis
- **Heterogeneity statistics** (I², τ², Q) in automatic graph notes
- **r(table) matrix** of plotted effects for downstream programmatic use
- **`noconstant`** shorthand for `drop(_cons)`
- **Full customization** via standard Stata graph options

## Syntax

### From data in memory

```stata
eplot esvar lcivar ucivar [if] [in], [options]
```

### From stored estimates (single or multi-model)

```stata
eplot [namelist], [options]
```

Use `.` to refer to active estimation results.

### From matrix

```stata
eplot, matrix(matname) [options]
```

Matrix must have 2 columns (b, se) or 3 columns (b, lci, uci).

Mode detection gives precedence to data mode when the first three tokens are
numeric variables. If stored estimate names happen to match numeric variable
names in memory, `eplot` will interpret the call as data mode. In ambiguous
cases, restore the active model and use `eplot .`, or rename the variables or
stored estimates.

## Examples

### Multi-Model Coefficient Comparison

![Multi-Model Comparison](demo/multi_model.png)

```stata
sysuse auto, clear

quietly regress price mpg weight foreign
estimates store base

quietly regress price mpg weight length headroom foreign
estimates store extended

eplot base extended, drop(_cons) ///
    modellabels("Base" "Extended") ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight" ///
               length = "Body Length" ///
               headroom = "Headroom" ///
               foreign = "Foreign Make") ///
    cicap scheme(plotplainblind)
```

### Forest Plot with Values Annotation

![Forest Plot](demo/forest_values.png)

```stata
clear
input str20 study es lci uci weight
"Smith 2020"    0.72  0.55  0.94  15.2
"Jones 2021"    0.85  0.71  1.02  18.4
"Brown 2022"    0.68  0.49  0.94  22.1
"Overall"       0.76  0.65  0.89   .
end

gen byte type = cond(study=="Overall", 5, 1)

eplot es lci uci, labels(study) weights(weight) type(type) ///
    values vformat(%4.2f) nonull ///
    effect("Hazard Ratio (95% CI)") ///
    scheme(plotplainblind)
```

### Grouped Coefficient Plot

![Grouped Coefficient Plot](demo/grouped_coefplot.png)

```stata
sysuse auto, clear
logit foreign mpg weight length headroom trunk turn

eplot ., drop(_cons) eform ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight" ///
               length = "Body Length" ///
               headroom = "Headroom" ///
               trunk = "Trunk Space" ///
               turn = "Turning Circle") ///
    groups(mpg weight = "Efficiency & Mass" ///
           length headroom trunk = "Dimensions" ///
           turn = "Handling") ///
    cicap mcolor(forest_green) ///
    effect("Odds Ratio") scheme(plotplainblind)
```

### Matrix Mode

![Matrix Mode](demo/matrix_mode.png)

```stata
matrix R = (1.82, 1.21, 2.74 \ 0.73, 0.54, 0.99 \ 1.45, 1.08, 1.95 \ 1.12, 0.78, 1.61)
matrix rownames R = "Drug_A" "Drug_B" "Drug_C" "Drug_D"

eplot, matrix(R) eform ///
    effect("Odds Ratio (95% CI)") ///
    coeflabels(Drug_A = "Drug A (experimental)" ///
               Drug_B = "Drug B (standard)" ///
               Drug_C = "Drug C (combination)" ///
               Drug_D = "Drug D (low-dose)") ///
    values cicap scheme(plotplainblind)
```

### Lancet Style Preset

![Lancet Style](demo/lancet_style.png)

```stata
sysuse auto, clear
logit foreign mpg weight length

eplot ., noconstant eform ///
    style(lancet) ///
    scheme(plotplainblind)
```

### Significance Coloring with Stars

![Significance Coloring](demo/sigcolors.png)

```stata
sysuse auto, clear
regress price mpg weight length turn headroom foreign

eplot ., noconstant ///
    sigcolors sigcolor(navy) ///
    cicap values stars ///
    scheme(plotplainblind)
```

### Meta-Analysis with Prediction Intervals and Heterogeneity

![Meta-Analysis](demo/meta_heterogeneity.png)

```stata
clear
input str20 study double(es lci uci pi_lci pi_uci weight) byte type
"Smith 2018"   -0.42  -0.78  -0.06  -1.15   0.31  12.3  1
"Jones 2019"   -0.31  -0.58  -0.04  -1.04   0.42  16.8  1
"Brown 2020"   -0.18  -0.41   0.05  -0.91   0.55  21.5  1
"Lee 2021"     -0.55  -0.93  -0.17  -1.28   0.18  10.2  1
"Garcia 2022"  -0.27  -0.49  -0.05  -1.00   0.46  19.1  1
"Patel 2023"   -0.09  -0.35   0.17  -0.82   0.64  20.1  1
"Overall"      -0.28  -0.41  -0.15   .       .      .    5
end

eplot es lci uci, labels(study) weights(weight) type(type) ///
    values vformat(%4.2f) ///
    pi(pi_lci pi_uci) ///
    i2("42.1%") tau2("0.021") qstat("8.63, df=5, p=0.125") ///
    effect("Mean Difference (95% CI)") ///
    favors("Favors Treatment" "Favors Control") ///
    scheme(plotplainblind)
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
| `keep(coeflist)` | Keep specified coefficients (wildcards supported) |
| `drop(coeflist)` | Drop specified coefficients (e.g., `drop(_cons)`) |
| `rename(spec)` | Rename coefficients (estimates mode only) |

### Labeling

| Option | Description |
|--------|-------------|
| `coeflabels(spec)` | Custom labels for coefficients/effects |
| `groups(spec)` | Define groups with bold headers |
| `headers(spec)` | Insert section headers |
| `gap(#)` | Extra spacing between `groups()` blocks in data and single-model estimates modes |

### Transform

| Option | Description |
|--------|-------------|
| `eform` | Exponentiate (OR, HR, RR) |
| `rescale(#)` | Multiply estimates by # |

### Display

| Option | Description |
|--------|-------------|
| `values` | Annotate rows with formatted effect text |
| `vformat(fmt)` | Format for values (default: %5.2f) |
| `sort` | Sort coefficients by effect size |
| `order(coeflist)` | Explicit coefficient ordering |
| `cicap` | Capped CI lines |
| `effect(string)` | X-axis title for effects |
| `level(#)` | Confidence level (default: 95) |
| `noci` | Suppress confidence intervals |
| `noconstant` | Drop the constant (_cons) |
| `stars` | Add significance stars (*, **, ***) |
| `sigcolors` | Color markers by significance (CI vs null) |
| `sigcolor(color)` | Significant effect color (default: cranberry) |
| `insigncolor(color)` | Non-significant effect color (default: gs10) |
| `style(name)` | Preset: forest, coef, lancet, jama, nejm, or bmj |
| `favors(left right)` | Directional annotation below x-axis (horizontal mode) |
| `xlabel(spec)` | Effect-axis tick specification in horizontal or vertical layout |
| `pi(lci_var uci_var)` | Prediction interval whiskers (data mode) |
| `i2(string)` | Display I-squared in note (data mode) |
| `tau2(string)` | Display tau-squared in note (data mode) |
| `qstat(string)` | Display Q statistic in note (data mode) |

### Multi-Model

| Option | Description |
|--------|-------------|
| `modellabels(strlist)` | Custom legend labels for each model |
| `offset(#)` | Vertical spacing between models (default: 0.15) |
| `palette(colorlist)` | Color palette for models |
| `legendopts(string)` | Additional legend options |

### Markers & CI

| Option | Description |
|--------|-------------|
| `mcolor(color)` | Marker color |
| `msymbol(symbol)` | Marker symbol (default: O) |
| `msize(size)` | Marker size |
| `cicolor(color)` | CI line color |
| `ciwidth(lwstyle)` | CI line width |
| `boxscale(#)` | Box size scaling (percentage) |
| `nobox` | Suppress weighted boxes |
| `nodiamonds` | Use markers instead of diamonds for pooled effects |

### Reference Lines

| Option | Description |
|--------|-------------|
| `xline(numlist)` | Add reference lines |
| `null(#)` | Null line position (default: 0, or 1 if eform) |
| `nonull` | Suppress null line |

## Stored Results

`eplot` stores the following in `r()`:

| Result | Description |
|--------|-------------|
| `r(N)` | Number of effects plotted |
| `r(k)` | Number of coefficients (excluding headers/diamonds) |
| `r(n_models)` | Number of models (estimates mode only) |
| `r(cmd)` | Graph command executed |
| `r(table)` | k x 3 matrix of plotted effects (b, ll, ul); k x (3*m) for multi-model |
| `r(pvalues)` | P-value matrix (estimates mode, single-model only) |

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.1.0, 2026-04-19

- Added `gap()` for grouped spacing in data and single-model estimates modes.
- Added effect-axis `xlabel()` passthrough for both horizontal and vertical layouts.
- Values annotation now widens the right plot margin automatically when formatted text is wide.
- Help now documents the mode-detection ambiguity when stored estimate names collide with variable names.
