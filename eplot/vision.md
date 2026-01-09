# eplot - Unified Effect Visualization Command

## Overview

`eplot` is a unified command for creating effect plots (forest plots, coefficient plots) from either:
1. **Data in memory** - variables containing effect sizes and confidence intervals
2. **Stored estimates** - coefficients from regression models

The command emphasizes clean syntax, flexible labeling, and aesthetic customization.

---

## Syntax

### From Data in Memory
```stata
eplot esvar lcivar ucivar [if] [in], [options]
```

### From Stored Estimates
```stata
eplot [namelist] [, options]
```
Where `namelist` is a list of stored estimate names (use `.` for active estimates).

### From Matrix
```stata
eplot matrix(matname) [, options]
```

---

## Core Options

### Data Specification
| Option | Description |
|--------|-------------|
| `labels(varname)` | Variable containing row labels |
| `weights(varname)` | Variable for marker/box sizing |
| `type(varname)` | Row type indicator (effect/subgroup/overall/header/blank) |
| `se(varname)` | Standard errors (alternative to CI vars) |

### Coefficient Selection (estimates mode)
| Option | Description |
|--------|-------------|
| `keep(coeflist)` | Keep specified coefficients |
| `drop(coeflist)` | Drop specified coefficients |
| `order(coeflist)` | Reorder coefficients |
| `rename(old=new ...)` | Rename coefficients |
| `eqlabels(spec)` | Equation labels |

### Labeling
| Option | Description |
|--------|-------------|
| `coeflabels(spec)` | Custom coefficient/effect labels |
| `groups(spec)` | Define groups with labels |
| `headers(spec)` | Insert section headers |
| `headings(spec)` | Alias for headers |

### Transform
| Option | Description |
|--------|-------------|
| `eform` | Exponentiate (for OR, HR, RR) |
| `percent` | Display as percentages |
| `rescale(#)` | Multiply estimates by # |

### Reference Lines
| Option | Description |
|--------|-------------|
| `xline(numlist)` | Vertical reference lines |
| `null(#)` | Null hypothesis line (default: 0, or 1 if eform) |
| `nonull` | Suppress null line |

### Confidence Intervals
| Option | Description |
|--------|-------------|
| `level(#)` | Confidence level (default: 95) |
| `levels(numlist)` | Multiple CI levels |
| `noci` | Suppress confidence intervals |

### Markers and Styling
| Option | Description |
|--------|-------------|
| `mstyle(spec)` | Marker styling by type |
| `cistyle(spec)` | CI spike styling |
| `colors(colorlist)` | Color scheme |
| `horizontal` | Horizontal layout (default) |
| `vertical` | Vertical layout |

### Layout
| Option | Description |
|--------|-------------|
| `lcols(varlist)` | Left-side text columns |
| `rcols(varlist)` | Right-side text columns |
| `spacing(#)` | Row spacing multiplier |
| `textsize(#)` | Text size multiplier |
| `astext(#)` | Percent of width for text (10-90) |

### Display
| Option | Description |
|--------|-------------|
| `nostats` | Suppress effect size column |
| `nowt` | Suppress weight column |
| `nonames` | Suppress row labels |
| `dp(#)` | Decimal places |
| `effect(string)` | Column header for effect sizes |
| `favours(left # right)` | Axis labels |

### Graph Options
| Option | Description |
|--------|-------------|
| `title(string)` | Graph title |
| `subtitle(string)` | Graph subtitle |
| `note(string)` | Graph note |
| `name(string)` | Graph name |
| `saving(filename)` | Save graph |
| `scheme(schemename)` | Graph scheme |
| `*` | Other twoway options |

---

## Groups Syntax

The `groups()` option allows flexible grouping of effects with labels:

```stata
// Basic: coefficients = "Label"
groups(age gender race = "Demographics"  bp chol = "Clinical")

// With styling
groups(age gender race = "Demographics", gap(1) style(bold))

// Nested groups (future)
groups(
    "Patient Factors" = (
        age gender = "Demographics"
        smoking exercise = "Lifestyle"
    )
)
```

---

## Type Variable Values

When using `type(varname)`, the variable should contain:

| Value | Meaning | Display |
|-------|---------|---------|
| 1 | Effect/Study | Marker + CI |
| 2 | Missing/Excluded | Text only "(Insufficient data)" |
| 3 | Subgroup total | Diamond |
| 4 | Heterogeneity info | Text only |
| 5 | Overall total | Diamond |
| 0 | Header/Label | Text only (bold) |
| 6 | Blank row | Spacing |

String values also accepted: "effect", "subgroup", "overall", "header", "blank", "missing", "hetinfo"

---

## Implementation Architecture

### File Structure
```
eplot/
├── eplot.ado              # Main command (~800-1000 lines)
├── eplot.sthlp            # Help file
├── eplot.pkg              # Package metadata
├── stata.toc              # Table of contents
├── README.md              # Documentation
│
├── _eplot_propgram.ado    # (Future: modular helpers)
```

### Internal Program Flow

```
eplot
  │
  ├─► Parse syntax (determine mode: data/estimates/matrix)
  │
  ├─► Prepare data
  │   ├─► [data mode] Read variables, validate
  │   ├─► [estimates mode] Extract coefficients
  │   └─► [matrix mode] Parse matrix
  │
  ├─► Process options
  │   ├─► Apply keep/drop/rename
  │   ├─► Process groups/headers
  │   └─► Calculate positions
  │
  ├─► Build graph
  │   ├─► Generate marker commands
  │   ├─► Generate CI commands
  │   ├─► Generate text columns
  │   └─► Combine with twoway
  │
  └─► Return results
```

### Key Internal Variables (tempvars)
```stata
`_es'        // Effect size
`_lci'       // Lower CI
`_uci'       // Upper CI
`_wt'        // Weight
`_type'      // Row type (numeric)
`_label'     // Display label
`_pos'       // Y-axis position
`_plot'      // Plot group number
```

---

## Version 1.0.0 Scope

### Included
- Data from memory mode (full support)
- Basic estimates mode (single model)
- `groups()` with simple syntax
- `headers()` for section breaks
- `coeflabels()` for custom labels
- `eform` transformation
- `xline()` reference lines
- `lcols()`/`rcols()` text columns
- Horizontal and vertical layouts
- Diamond rendering for pooled effects
- Box/marker sizing by weight
- Publication-quality defaults

### Deferred to v1.1+
- Multi-model comparison
- Matrix mode
- Nested groups
- Gradient CI smoothing
- Theme/style presets
- `by()` faceting

---

## Testing Strategy

### Unit Tests (_testing/test_eplot.do)
1. Basic data mode - simple 3-variable input
2. With labels and weights
3. With type variable (mixed rows)
4. Groups option parsing
5. Headers option
6. Eform transformation
7. Vertical layout
8. Custom columns (lcols/rcols)
9. Error handling (bad inputs)

### Validation Tests (_validation/validation_eplot.do)
1. Known-answer: manual calculation of positions
2. Comparison with coefplot output
3. Comparison with forestplot output
4. Edge cases: single row, all missing, etc.

---

## Example Gallery

### Basic Forest Plot
```stata
// Simulate meta-analysis data
clear
input str20 study es lci uci weight
"Smith 2020"    0.85  0.70  1.03  15.2
"Jones 2021"    0.72  0.58  0.89  18.4
"Brown 2022"    0.91  0.78  1.06  22.1
"Wilson 2023"   0.68  0.52  0.89  12.8
"Overall"       0.79  0.71  0.88  .
end

gen byte type = cond(study=="Overall", 5, 1)

eplot es lci uci, ///
    labels(study) weights(weight) type(type) ///
    eform effect("Risk Ratio") ///
    xline(1) ///
    title("Meta-analysis of Treatment Effect")
```

### Coefficient Plot from Regression
```stata
sysuse auto, clear
regress price mpg weight length foreign

eplot ., ///
    drop(_cons) ///
    coeflabels(mpg="Miles per Gallon" weight="Weight (lbs)" ///
               length="Length (in)" foreign="Foreign Make") ///
    xline(0) ///
    title("Price Determinants")
```

### Grouped Effects
```stata
eplot es lci uci, ///
    labels(varname) ///
    groups(var1 var2 var3 = "Risk Factors" ///
           var4 var5 = "Protective Factors") ///
    eform effect("Odds Ratio")
```

---

## Return Values

```stata
r(N)          // Number of effects plotted
r(es)         // Matrix of effect sizes
r(ci)         // Matrix of confidence intervals
r(labels)     // List of labels
r(cmd)        // Full graph command (for debugging)
```

---

## Changelog

### v1.0.0 (2026-01-09)
- Initial release
- Data from memory mode
- Basic estimates mode
- Groups and headers
- Core styling options

---

*Last updated: 2026-01-09*
