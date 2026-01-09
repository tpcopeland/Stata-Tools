# Vision: effectplot - A Unified Effect Visualization Command

## Executive Summary

The goal is to create a single, unified command called `effectplot` that combines the best features of:
- **forestplot.ado** (David Fisher) - Forest plots from data in memory
- **coefplot.ado** (Ben Jann) - Coefficient plots from stored estimates

The new command will be cleaner, more flexible, and more intuitive while supporting both data sources through a unified syntax.

---

## Current State Analysis

### forestplot.ado (v4.08, David Fisher)
**Purpose**: Create forest plots from data in memory (primarily for meta-analysis)

**Strengths**:
- Sophisticated handling of meta-analysis data structures (`_USE` variable)
- Excellent diamond and box rendering for pooled estimates
- Prediction interval support (`rfdist()`)
- Fine-tuned text column placement (`lcols`, `rcols`)
- Dimensional consistency (`savedims`, `usedims`)

**Pain Points**:
- Very meta-analysis focused - `_USE` values (0-7) are opaque
- Limited labeling flexibility for effect groups
- ~4000 lines monolithic code
- Many undocumented internal options
- Syntax inherited from `metan9` - not intuitive

**Key Variables Expected**:
```stata
_ES      // Effect size
_LCI     // Lower confidence limit
_UCI     // Upper confidence limit
_USE     // Row type (0=header, 1=study, 2=missing, 3=subgroup, 4=het, 5=overall, 6=blank, 7=prediction)
_WT      // Weight (for box sizing)
_LABELS  // Row labels
```

### coefplot.ado (v1.8.8, Ben Jann)
**Purpose**: Plot regression coefficients from stored estimates

**Strengths**:
- Excellent labeling system: `coeflabels()`, `headings()`, `groups()`
- Multi-model comparison support
- Clean syntax with plot/subgraph hierarchy
- `at()` option for continuous axes
- Flexible confidence interval handling (`levels()`, `ci()`)
- Mata-based efficient data processing

**Pain Points**:
- Only works with stored estimates - can't use data in memory directly
- Complex option hierarchy (model/plot/subgraph/global)
- ~4000 lines with embedded Mata
- Some options have cryptic syntax

**Key Features for Effect Groups**:
```stata
groups(var1 var2 = "Group A" var3 var4 = "Group B")
headings(var1 = "Section 1" var3 = "Section 2")
coeflabels(var1 = "Custom Label" var2 = "Another Label")
```

---

## Proposed Architecture

### New Command: `effectplot`

```
effectplot/
├── effectplot.ado          # Main command (unified interface)
├── effectplot.sthlp         # Help file
├── effectplot.pkg           # Package metadata
├── stata.toc                # TOC
├── README.md                # Documentation
│
├── _ep_parse.ado            # Syntax parsing and validation
├── _ep_data.ado             # Data preparation (from memory or estimates)
├── _ep_layout.ado           # Layout calculation (spacing, columns)
├── _ep_render.ado           # Graph rendering (boxes, diamonds, CIs)
├── _ep_labels.ado           # Label management and formatting
└── _ep_style.ado            # Style/theme management
```

### Unified Syntax Design

```stata
// From stored estimates (like coefplot)
effectplot [modellist] [, options]

// From data in memory (like forestplot)
effectplot varlist [if] [in], from(data) [options]

// Quick matrix-based plotting
effectplot matrix(matname) [, options]
```

---

## Core Design Principles

### 1. Single Source of Truth for Data
All plotting goes through a standardized internal data structure:

```stata
// Internal variables (created by _ep_data.ado)
_ep_id        // Unique row identifier
_ep_es        // Effect size (point estimate)
_ep_lci       // Lower confidence limit
_ep_uci       // Upper confidence limit
_ep_weight    // Weight for box sizing (optional)
_ep_type      // Row type: "effect" | "group" | "subgroup" | "overall" | "header" | "blank"
_ep_label     // Display label
_ep_group     // Group membership (for grouping effects)
_ep_plot      // Plot number (for multi-plot graphs)
_ep_style     // Style identifier
```

### 2. Intuitive Row Types
Replace opaque `_USE` codes with readable types:

| Old (_USE) | New (_ep_type) | Meaning |
|------------|----------------|---------|
| 0 | "header" | Section headers, titles |
| 1 | "effect" | Individual effect/study |
| 2 | "missing" | Missing/insufficient data |
| 3 | "subgroup" | Subgroup pooled effect |
| 4 | "hetinfo" | Heterogeneity information |
| 5 | "overall" | Overall pooled effect |
| 6 | "blank" | Spacing/blank row |
| 7 | "prediction" | Prediction interval |

### 3. Flexible Group Labeling System

**Goal**: Make effect grouping intuitive and powerful

```stata
// Define groups with labels
effectplot, groups(
    "Demographics" = age gender race
    "Clinical" = bp cholesterol diabetes
    "Behavioral" = smoking exercise diet
)

// Nested groups (subgroups within groups)
effectplot, groups(
    "Cardiovascular" = (
        "Risk Factors" = bp cholesterol
        "Outcomes" = mi stroke
    )
    "Metabolic" = diabetes obesity
)

// Automatic grouping by equation or prefix
effectplot, groupby(equation)
effectplot, groupby(prefix)  // e.g., dem_age, clin_bp -> Demographics, Clinical
```

### 4. Style/Theme System

**Predefined Themes**:
```stata
effectplot, style(forest)      // Classic forest plot (boxes + diamonds)
effectplot, style(coef)        // Clean coefficient plot (dots + spikes)
effectplot, style(minimal)     // Minimal, publication-ready
effectplot, style(clinical)    // Clinical trial standard
effectplot, style(gradient)    // Gradient-filled confidence regions
```

**Custom Styling**:
```stata
effectplot, ///
    markers(effect = "O" subgroup = "D" overall = "D") ///
    colors(effect = "navy" subgroup = "maroon" overall = "black") ///
    sizes(effect = "*1" subgroup = "*1.5" overall = "*2") ///
    fills(subgroup = "none" overall = "solid")
```

---

## Feature Specifications

### 1. Data Source Flexibility

#### From Stored Estimates (Current coefplot behavior)
```stata
regress y x1 x2 x3
estimates store model1

logit y x1 x2 x3
estimates store model2

effectplot model1 model2, ///
    keep(x1 x2 x3) ///
    labels(x1 = "Age" x2 = "Gender" x3 = "BMI")
```

#### From Data in Memory (Current forestplot behavior)
```stata
// Requires: es_var lci_var uci_var
effectplot es lci uci, from(data) ///
    labels(study_name) ///
    weights(study_weight) ///
    type(use_indicator)
```

#### From Matrix
```stata
matrix results = (1.5, 1.2, 1.9 \ 2.1, 1.8, 2.5 \ 0.8, 0.5, 1.2)
matrix rownames results = "Treatment A" "Treatment B" "Treatment C"

effectplot matrix(results), ///
    colspec(1=es 2=lci 3=uci)
```

### 2. Enhanced Labeling Options

#### Effect Labels
```stata
effectplot, labels(
    age = "Age (years)"
    gender = "Female vs. Male"
    bmi = "BMI (kg/m{superscript:2})"
)
```

#### Group Headers
```stata
effectplot, headers(
    before(age) = "{bf:Demographics}"
    before(systolic) = "{bf:Clinical Measures}"
)
```

#### Group Brackets
```stata
effectplot, brackets(
    age gender race = "Patient Characteristics"
    bp cholesterol = "Cardiovascular Risk"
)

// Or with visual grouping
effectplot, groupshade(
    1 = "Patient Characteristics"  // Shaded band
    2 = "Cardiovascular Risk"      // Different shade
)
```

#### Annotation Flexibility
```stata
effectplot, ///
    annotate(age = "p < 0.001" bmi = "p = 0.03") ///
    annotatepos(right)  // left, right, above, below
```

### 3. Aesthetic Flexibility

#### Marker Customization
```stata
effectplot, ///
    mstyle(
        effect = (symbol(O) size(medium) color(navy))
        subgroup = (symbol(D) size(large) color(maroon) fill(solid))
        overall = (symbol(D) size(vlarge) color(black) fill(solid))
    )
```

#### Confidence Interval Styles
```stata
effectplot, ///
    cistyle(
        effect = (type(spike) width(medium) color(navy))
        overall = (type(rcap) width(thick) color(black))
    )

// Or gradient CIs (inspired by cismooth)
effectplot, cigradient(levels(50 75 90 95))
```

#### Diamond Customization (for pooled effects)
```stata
effectplot, ///
    diamonds(
        subgroup = (color(maroon%50) outline(maroon))
        overall = (color(navy%50) outline(navy) size(1.5))
    )
```

#### Reference Lines
```stata
effectplot, ///
    refline(1)                    // Single reference at 1
    reflines(0.5 1 2)             // Multiple references
    reflineopt(pattern(dash) color(gray))
```

### 4. Layout Control

#### Column Placement
```stata
effectplot, ///
    leftcols(study_name author year) ///
    rightcols(effect_text weight pvalue) ///
    colwidths(study_name = 30% effect_text = 20%)
```

#### Text Formatting
```stata
effectplot, ///
    textsize(labels = 2.5 data = 2) ///
    textformat(weight = "%5.1f" pvalue = "%5.3f")
```

#### Spacing
```stata
effectplot, ///
    spacing(between_effects = 1 between_groups = 2 after_header = 1.5) ///
    groupgap(1.5)
```

### 5. Multi-Panel Plots

```stata
// Side-by-side comparison
effectplot model1 || model2, ///
    bylayout(horizontal) ///
    bylabels("Primary Analysis" "Sensitivity Analysis")

// Faceted by subgroup
effectplot, ///
    by(study_type) ///
    byrows(2) bycols(2)
```

---

## Helper Module Specifications

### _ep_parse.ado
**Purpose**: Parse and validate all syntax variants

**Key Functions**:
- Detect data source type (estimates, memory, matrix)
- Validate option combinations
- Expand shorthand syntax
- Return structured option sets

### _ep_data.ado
**Purpose**: Prepare standardized internal dataset

**Key Functions**:
- Extract coefficients from stored estimates
- Read effect data from memory
- Parse matrix specifications
- Apply keep/drop/rename rules
- Generate internal variables (`_ep_*`)
- Handle missing data

### _ep_layout.ado
**Purpose**: Calculate plot layout and spacing

**Key Functions**:
- Determine row positions
- Calculate column widths
- Handle text wrapping
- Manage group spacing
- Calculate aspect ratios
- Handle multi-panel layouts

### _ep_render.ado
**Purpose**: Generate graph commands

**Key Functions**:
- Render markers (dots, boxes, diamonds)
- Render confidence intervals (spikes, ranges, caps)
- Render reference lines
- Render group brackets/shading
- Handle arrow indicators for off-scale CIs
- Generate legend

### _ep_labels.ado
**Purpose**: Manage all labeling

**Key Functions**:
- Process coeflabels specification
- Process group/heading specifications
- Handle text truncation/wrapping
- Format numeric displays
- Apply SMCL formatting

### _ep_style.ado
**Purpose**: Theme and style management

**Key Functions**:
- Load predefined themes
- Merge user customizations
- Resolve style inheritance
- Validate color specifications

---

## Implementation Phases

### Phase 1: Foundation (Core Infrastructure)
1. Create package structure with helper files
2. Implement `_ep_parse.ado` - unified syntax parsing
3. Implement `_ep_data.ado` - data standardization
4. Basic `effectplot.ado` that routes to appropriate helper
5. Support for `from(data)` mode (simplest case)

### Phase 2: Estimates Mode
1. Extend `_ep_data.ado` for stored estimates
2. Implement coefficient extraction
3. Add equation/keep/drop support
4. Matrix mode support

### Phase 3: Layout Engine
1. Implement `_ep_layout.ado`
2. Row positioning algorithm
3. Column width calculations
4. Group spacing logic

### Phase 4: Rendering Engine
1. Implement `_ep_render.ado`
2. Basic markers and CIs
3. Diamond rendering
4. Reference lines

### Phase 5: Labeling System
1. Implement `_ep_labels.ado`
2. `groups()` specification
3. `headers()` and `brackets()`
4. Text formatting and wrapping

### Phase 6: Styling System
1. Implement `_ep_style.ado`
2. Define built-in themes
3. Custom style merging
4. Advanced aesthetics (gradients, etc.)

### Phase 7: Polish
1. Comprehensive help file
2. Examples and tutorials
3. Edge case handling
4. Performance optimization

---

## Option Reference (Proposed)

### Data Source Options
| Option | Description |
|--------|-------------|
| `from(data)` | Use data in memory |
| `from(estimates)` | Use stored estimates (default) |
| `matrix(name)` | Use Stata matrix |
| `using(filename)` | Load from file |

### Variable/Coefficient Selection
| Option | Description |
|--------|-------------|
| `keep(spec)` | Keep specified effects |
| `drop(spec)` | Drop specified effects |
| `order(spec)` | Reorder effects |
| `rename(spec)` | Rename effects |

### Labeling Options
| Option | Description |
|--------|-------------|
| `labels(spec)` | Custom effect labels |
| `headers(spec)` | Insert section headers |
| `groups(spec)` | Define and label groups |
| `brackets(spec)` | Add group brackets |
| `annotate(spec)` | Add annotations |

### Aesthetic Options
| Option | Description |
|--------|-------------|
| `style(name)` | Apply predefined theme |
| `mstyle(spec)` | Marker styling |
| `cistyle(spec)` | CI styling |
| `diamonds(spec)` | Diamond styling |
| `colors(spec)` | Color scheme |

### Layout Options
| Option | Description |
|--------|-------------|
| `leftcols(varlist)` | Left-side columns |
| `rightcols(varlist)` | Right-side columns |
| `spacing(spec)` | Row/group spacing |
| `textsize(spec)` | Text sizing |
| `astext(#)` | Text area percentage |

### Display Options
| Option | Description |
|--------|-------------|
| `eform` | Exponentiate (OR, HR, etc.) |
| `null(#)` | Null reference value |
| `reflines(numlist)` | Additional reference lines |
| `dp(#)` | Decimal places |
| `level(#)` | Confidence level |

---

## Example Usage Gallery

### Basic Forest Plot (from data)
```stata
use meta_analysis_results, clear
effectplot es lci uci, from(data) ///
    labels(study) ///
    style(forest) ///
    eform effect("Odds Ratio")
```

### Coefficient Plot (from estimates)
```stata
regress outcome age gender bmi bp_sys bp_dia
effectplot, ///
    keep(age gender bmi bp_*) ///
    groups(
        "Demographics" = age gender
        "Clinical" = bmi bp_sys bp_dia
    ) ///
    style(coef) ///
    refline(0)
```

### Multi-Model Comparison
```stata
effectplot model1 model2 model3, ///
    keep(treatment) ///
    labels(
        model1 = "Unadjusted"
        model2 = "Adjusted"
        model3 = "Full Model"
    ) ///
    eform effect("Hazard Ratio") ///
    colors(navy maroon forest_green)
```

### Publication-Ready Forest Plot
```stata
effectplot es lci uci, from(data) ///
    type(row_type) ///
    labels(study_name) ///
    leftcols(author year) ///
    rightcols(events_trt events_ctrl weight_text) ///
    style(minimal) ///
    eform effect("Risk Ratio") ///
    diamonds(overall = (color(navy%60))) ///
    xlabel(0.1 0.5 1 2 10, format(%3.1f)) ///
    favours("Favours Treatment" # "Favours Control")
```

---

## Backward Compatibility Notes

### For forestplot users:
- `from(data)` mode maintains variable naming conventions
- `_USE` values still accepted (mapped to `_ep_type`)
- `useopts` support for metan integration

### For coefplot users:
- Model specification syntax preserved
- `keep()`, `drop()`, `rename()` unchanged
- `coeflabels()` → `labels()`
- `headings()` → `headers()`

---

## Success Criteria

1. **Unified Syntax**: One command handles both use cases elegantly
2. **Flexible Labeling**: Groups, headers, brackets all intuitive
3. **Aesthetic Control**: Easy to customize every visual element
4. **Clean Code**: Modular helpers, no 4000-line monoliths
5. **Well Documented**: Comprehensive help with many examples
6. **Performant**: Efficient even with large datasets
7. **Backward Compatible**: Existing workflows still work

---

## Open Questions

1. **Naming**: Is `effectplot` the right name? Alternatives:
   - `eplot`
   - `fpcoef`
   - `vizeffect`
   - `ploteffects`

2. **Group syntax**: Which is more intuitive?
   ```stata
   // Option A: Named groups
   groups("Demographics" = age gender race)

   // Option B: Positional with separator
   groups(age gender race = "Demographics")

   // Option C: Separate option per group
   group1(age gender race, label("Demographics"))
   ```

3. **Mata usage**: Should we use Mata for performance-critical sections (like coefplot does) or keep pure ado for simplicity?

4. **Theme files**: Should themes be external files (`.theme` or `.style`) for easy sharing/customization?

---

## References

- Fisher, D. (2024). forestplot v4.08. UCL.
- Jann, B. (2025). coefplot v1.8.8. University of Bern.
- StataCorp. (2023). Stata Graphics Reference Manual.

---

*Document Version: 1.0*
*Created: 2026-01-09*
*Author: Claude/Timothy Copeland*
