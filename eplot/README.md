# eplot - Unified effect plotting from data, estimates, and matrices

**Version 1.1.0** | 2026-04-19

`eplot` creates forest-plot and coefficient-plot style graphics from three sources: variables in memory, active or stored estimation results, and preassembled matrices. The point of the package is to keep those workflows under one command instead of switching between separate plotting tools and custom graph code.

## Requirements

- Stata 16 or later
- No external package dependencies

## Installation

```stata
capture ado uninstall eplot
net install eplot, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/eplot") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `eplot` | Draw effect plots from data in memory, estimation results, or matrices |

## How It Works

`eplot` chooses its mode from the call you give it:

1. `eplot es lci uci, ...` uses variables in memory.
2. `eplot .` or `eplot model1 model2, ...` uses active or stored estimates.
3. `eplot, matrix(R) ...` uses a matrix with effect information.

Mode detection gives precedence to data mode when the first three tokens look like numeric variables. In ambiguous cases, use `eplot .` to force estimates mode or `matrix()` to force matrix mode explicitly.

## Feature Highlights

- One plotting command across data, estimation, and matrix workflows
- Forest-plot and coefficient-plot layouts under a shared option vocabulary
- Multi-model comparisons with `modellabels()`, `offset()`, and `palette()`
- Display controls such as `values`, `cicap`, `groups()`, `headers()`, and `gap()`
- Quick styling through `style(lancet|jama|nejm|bmj|forest|coef)` and custom axis/reference-line options

## Worked Examples

### 1. Create a single-model coefficient plot

This is the fastest way to use `eplot` when you already have estimation results in memory.

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

### 4. Plot from a matrix

Matrix mode is useful when the effect table is already assembled programmatically.

```stata
matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2 \ 1.2, 0.9, 1.6)
matrix rownames R = "Treatment_A" "Treatment_B" "Treatment_C"

eplot, matrix(R) eform ///
    effect("Odds Ratio") ///
    values
```

### 5. Add grouping and annotation

Once the basic plot works, layer on display options such as `groups()`, `gap()`, significance coloring, or `favors()`.

```stata
sysuse auto, clear
regress price mpg weight length turn foreign rep78

eplot ., noconstant ///
    groups(mpg weight length turn = "Vehicle Characteristics" ///
           foreign rep78 = "Other Factors") ///
    gap(0.5) ///
    stars values sigcolors
```

## Gallery

### Multi-model comparison

![Multi-model comparison](demo/multi_model.png)

### Forest plot from data mode

![Forest plot from data mode](demo/forest_values.png)

### Matrix mode

![Matrix mode](demo/matrix_mode.png)

## Version History

- **1.1.0** (2026-04-19): Added `gap()` for grouped spacing, added effect-axis `xlabel()` passthrough, widened value-annotation margins automatically, and documented mode-detection ambiguity more clearly

## Author

Timothy P Copeland, Karolinska Institutet
