# eplot

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Unified effect plotting for forest plots and coefficient plots in Stata.

`eplot` creates effect plots from three sources:

- data in memory
- stored estimation results
- matrices

It is designed to cover the common workflows that otherwise get split across a forest-plot command, a coefficient-plot command, and custom graph code.

## Installation

```stata
capture ado uninstall eplot
net install eplot, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/eplot") replace
help eplot
```

## How It Works

`eplot` chooses its mode from the call you give it:

1. `eplot es lci uci, ...` uses variables in memory
2. `eplot .` or `eplot model1 model2, ...` uses active or stored estimates
3. `eplot, matrix(R) ...` uses a matrix with effect information

That means one README example is not enough. The most useful way to learn `eplot` is to see one worked example for each mode and then adapt the option set from there.

Mode detection gives precedence to data mode when the first three tokens look like numeric variables. In ambiguous cases, use `eplot .` to force estimates mode or `matrix()` to force matrix mode.

## Worked Examples

### 1. Single-model coefficient plot from `sysuse auto`

This is the fastest way to use `eplot` if you already have estimation results in memory.

```stata
sysuse auto, clear
regress price mpg weight foreign

eplot ., drop(_cons) ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight" ///
               foreign = "Foreign Make") ///
    cicap
```

### 2. Compare two stored models

Multi-model estimates mode is useful when you want to compare a base model and an adjusted model side by side.

```stata
sysuse auto, clear

quietly regress price mpg weight foreign
estimates store base

quietly regress price mpg weight length foreign headroom
estimates store extended

eplot base extended, drop(_cons) ///
    modellabels("Base" "Extended") ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight" ///
               length = "Body Length" ///
               headroom = "Headroom" ///
               foreign = "Foreign Make") ///
    cicap
```

![Multi-Model Comparison](demo/multi_model.png)

### 3. Create a forest plot from data in memory

Use data mode when you already have effect sizes and confidence limits in variables, for example after a meta-analysis or when reading results from another system.

```stata
clear
input str20 study es lci uci weight
"Smith 2020"   -0.16  -0.36   0.03  15.2
"Jones 2021"   -0.33  -0.54  -0.12  18.4
"Brown 2022"   -0.09  -0.25   0.06  22.1
"Wilson 2023"  -0.39  -0.65  -0.12  12.8
"Overall"      -0.24  -0.34  -0.13   .
end

gen byte type = cond(study == "Overall", 5, 1)

eplot es lci uci, labels(study) weights(weight) type(type) ///
    values effect("Mean Difference (95% CI)")
```

![Forest Plot](demo/forest_values.png)

### 4. Plot from a matrix

Matrix mode is useful when the effect table is already assembled programmatically.

```stata
matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2 \ 1.2, 0.9, 1.6)
matrix rownames R = "Treatment_A" "Treatment_B" "Treatment_C"

eplot, matrix(R) eform ///
    effect("Odds Ratio") ///
    values
```

### 5. Apply styling, grouping, and annotation

Once the basic plot works, layer on display options such as `groups()`, `gap()`, `style()`, significance coloring, or `favors()`.

```stata
sysuse auto, clear
regress price mpg weight length turn foreign rep78

eplot ., noconstant ///
    groups(mpg weight length turn = "Vehicle Characteristics" ///
           foreign rep78 = "Other Factors") ///
    gap(0.5) ///
    stars values sigcolors
```

## Common Option Families

### Data and labels

- `labels(varname)`: row labels in data mode
- `weights(varname)`: marker scaling in forest-plot style displays
- `type(varname)`: row roles such as ordinary effect rows and pooled rows
- `coeflabels()`, `groups()`, `headers()`: relabel or organize coefficients

### Effect transformation and reference lines

- `eform`: exponentiate coefficients
- `rescale(#)`: multiply effects by a scalar
- `xline()`, `null()`, `nonull`: control reference lines
- `xlabel()`: pass effect-axis ticks through to either layout

### Display and layout

- `values`: print formatted effect text beside each row
- `vformat()`: control numeric formatting of those values
- `cicap`: use capped confidence-interval whiskers
- `sort` or `order()`: control coefficient order
- `style(lancet|jama|nejm|bmj|forest|coef)`: quick presets
- `gap(#)`: add spacing between grouped sections
- `favors("Left label" "Right label")`: directional annotation for treatment-vs-control style displays

### Multi-model estimates mode

- `modellabels()`: legend labels for stored estimates
- `offset()`: vertical spacing between models
- `palette()`: model color palette
- `legendopts()`: additional legend control

## Stored Results

`eplot` stores:

| Result | Description |
| --- | --- |
| `r(N)` | Number of plotted rows |
| `r(k)` | Number of plotted effects excluding headers and diamonds |
| `r(n_models)` | Number of models in estimates mode |
| `r(cmd)` | Graph command executed |
| `r(table)` | Matrix of plotted estimates and confidence limits |
| `r(pvalues)` | P-value matrix in single-model estimates mode |

## Gallery

### Grouped coefficient plot

![Grouped Coefficient Plot](demo/grouped_coefplot.png)

### Matrix mode

![Matrix Mode](demo/matrix_mode.png)

### Lancet style preset

![Lancet Style](demo/lancet_style.png)

### Significance coloring

![Significance Coloring](demo/sigcolors.png)

### Meta-analysis style display

![Meta-Analysis](demo/meta_heterogeneity.png)

## Requirements

- Stata 16 or newer
- No external package dependencies

## Version

**Version**: 1.1.0

- Added `gap()` for grouped spacing in data and single-model estimates modes.
- Added effect-axis `xlabel()` passthrough for both horizontal and vertical layouts.
- Values annotation now widens the right plot margin automatically when formatted text is wide.
- Help and README now document mode-detection ambiguity when stored estimate names collide with variable names.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License
