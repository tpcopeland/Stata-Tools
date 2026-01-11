# synthdata

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Generate realistic synthetic datasets that preserve statistical properties while protecting privacy.

## Package Overview

**synthdata** generates synthetic datasets that preserve the statistical properties and variable relationships of the original data without containing real observations. This command is designed for researchers and data scientists who need to:

- Work with sensitive data in unsecured environments
- Share data for collaboration while protecting privacy
- Develop and test code before accessing restricted data
- Create teaching datasets from real data
- Augment small samples for model development

### Key Features

- **Smart adaptive synthesis** (NEW): Automatically detects distribution shapes, variable relationships, and categorical associations for the most realistic output with minimal configuration
- **Multiple synthesis methods**: Smart (recommended), Parametric (Cholesky), sequential regression, bootstrap with perturbation, independent permutation
- **Auto-detection features** (NEW):
  - Non-normal distributions automatically use empirical quantiles
  - Derived variables (sums, ratios) are automatically detected and reconstructed
  - Strongly associated categorical variables are synthesized jointly
- **Flexible variable handling**: Automatic classification of continuous, categorical, string, date, and integer variables
- **Relationship preservation**: Correlations, conditional distributions, constraints, derived variables
- **Privacy controls**: Rare category protection, extreme value trimming, bounded outputs
- **Panel data support**: Preserve panel structure, within-unit correlations, autocorrelation
- **Comprehensive validation**: Comparison reports, utility metrics, density plots, validation statistics
- **Multiple datasets**: Generate multiple synthetic replicates for uncertainty quantification
- **Automatic metadata preservation**: Variable labels, value labels, variable order, and missingness rates are automatically preserved

---

## Installation

```stata
net install synthdata, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/synthdata")
```

---

## Syntax

```stata
synthdata [varlist] [if] [in], [options]
```

### Required Options

None. If no options are specified, `synthdata` will:
- Synthesize all variables in the dataset
- Use parametric method (Cholesky decomposition)
- Create same number of observations as original
- Replace data in memory

### Main Options

#### Output Options

| Option | Description | Default |
|--------|-------------|---------|
| `n(#)` | Number of synthetic observations | Same as original |
| `saving(filename)` | Save synthetic data to file | — |
| `replace` | Replace current data with synthetic version | — |
| `clear` | Clear current data and load synthetic | — |
| `prefix(string)` | Prefix for synthetic variable names | — |
| `multiple(#)` | Generate # synthetic datasets | 1 |

#### Synthesis Methods

| Option | Description |
|--------|-------------|
| `smart` | **Recommended**: Adaptive synthesis with automatic optimizations |
| `parametric` | Parametric synthesis via Cholesky decomposition (default if smart not specified) |
| `sequential` | Sequential regression synthesis |
| `bootstrap` | Bootstrap with perturbation |
| `permute` | Independent permutation (breaks all relationships) |

#### Method Modifiers

| Option | Description |
|--------|-------------|
| `empirical` | Use empirical quantiles instead of normal distribution |
| `autoempirical` | Auto-detect non-normal distributions |
| `noise(#)` | Perturbation SD as fraction of variable SD (default 0.1) |
| `smooth` | Apply kernel density smoothing |

#### Variable Type Options

| Option | Description |
|--------|-------------|
| `categorical(varlist)` | Force treatment as categorical |
| `continuous(varlist)` | Force treatment as continuous |
| `integer(varlist)` | Force treatment as integer (whole numbers only) |
| `skip(varlist)` | Exclude from synthesis (set to missing) |
| `id(varlist)` | ID variables (generate new sequential IDs) |
| `dates(varlist)` | Date variables with special handling |

#### Privacy and Disclosure Control

| Option | Description | Default |
|--------|-------------|---------|
| `mincell(#)` | Rare category protection threshold | 5 |
| `trim(#)` | Trim extreme values at #th percentile | 0 |
| `bounds(spec)` | Enforce min/max bounds | — |
| `noextreme` | Prevent values outside observed range | — |

#### Constraints and Relationships

| Option | Description |
|--------|-------------|
| `correlations` | Preserve correlation matrix structure |
| `conditional` | Preserve conditional distributions |
| `constraints(string)` | User-specified constraints |
| `autoconstraints` | Auto-detect logical constraints |
| `autorelate` | Auto-detect derived variables (sums, ratios) |
| `conditionalcat` | Preserve categorical associations |

#### Panel/Longitudinal Data

| Option | Description |
|--------|-------------|
| `panel(id time)` | Preserve panel structure |
| `preservevar(varlist)` | Variables constant within panel unit |
| `autocorr(#)` | Preserve autocorrelation up to # lags |

#### Validation and Diagnostics

| Option | Description |
|--------|-------------|
| `compare` | Produce comparison report |
| `validate(filename)` | Save validation statistics |
| `utility` | Compute utility metrics |
| `graph` | Produce overlay density plots |

#### Technical Options

| Option | Description | Default |
|--------|-------------|---------|
| `seed(#)` | Random seed for reproducibility | — |
| `iterate(#)` | Max iterations for constraints | 100 |
| `tolerance(#)` | Convergence tolerance | 1e-6 |

For complete option details, see: `help synthdata`

---

## Synthesis Methods

### Smart Method (Recommended)

The **smart** method is the recommended approach for generating the most realistic synthetic data with minimal configuration. It automatically:

1. **Detects non-normal distributions** using skewness and kurtosis, and uses empirical quantile synthesis for them
2. **Detects derived variables** (sums, ratios, perfect linear combinations) and reconstructs them from base variables
3. **Detects categorical associations** using Cramér's V and synthesizes associated categoricals jointly
4. **Auto-detects logical constraints** (non-negative values, etc.)

**Advantages:**
- Most realistic output with minimal configuration
- Preserves distribution shapes automatically
- Maintains variable relationships
- Handles mixed data types intelligently

```stata
synthdata, smart saving(synth_realistic)
```

### Parametric Method (Default if smart not specified)

The parametric method fits normal distributions to continuous variables and preserves the correlation matrix via Cholesky decomposition. Categorical variables are drawn from observed frequencies.

**Advantages:**
- Fast and efficient
- Preserves correlations exactly
- Mathematically well-understood

**Limitations:**
- Assumes normality for continuous variables
- May generate values outside observed range

```stata
synthdata, parametric n(10000) saving(synth_parametric)
```

### Sequential Method

Models each variable conditional on previous variables using regression, then draws from the predictive distribution. Handles mixed variable types naturally.

**Advantages:**
- Captures complex dependencies
- Handles mixed variable types
- No normality assumption

**Limitations:**
- Slower for many variables
- Variable order matters

```stata
synthdata, sequential n(10000) saving(synth_sequential)
```

### Bootstrap Method

Resamples rows with replacement and adds random noise to continuous variables.

**Advantages:**
- Simple and intuitive
- Preserves empirical distributions
- Fast

**Limitations:**
- May not preserve all relationships
- Less privacy protection

```stata
synthdata, bootstrap noise(0.15) n(10000) saving(synth_bootstrap)
```

### Permute Method

Permutes each variable independently, breaking all relationships. Useful as a null/baseline comparison.

**Advantages:**
- Maximum privacy protection
- Simple method

**Limitations:**
- Destroys all relationships
- Not useful for analysis (baseline only)

```stata
synthdata, permute n(10000) saving(synth_permute)
```

---

## Automatic Features

**synthdata** automatically preserves key properties from the original data:

### Variable Labels
All variable labels from the original data are applied to the synthetic variables. This ensures the synthetic dataset is self-documenting.

### Value Labels
Value label attachments for categorical variables are preserved, maintaining meaningful category descriptions.

### Variable Order
Variables in the synthetic data are ordered to match the original data, facilitating direct comparison and analysis.

### Missingness Rates
The proportion of missing values for each variable is preserved. If a variable has 10% missing values in the original data, approximately 10% of values will be randomly set to missing in the synthetic data. This is important for:
- Variables that are conditionally missing (e.g., dates of events that never occurred)
- Preserving realistic data patterns for imputation testing
- Maintaining the utility of the synthetic data for analyses that handle missing data

### Integer Detection
Continuous variables that contain only whole numbers (integers) are automatically detected. Synthesized values for these variables are rounded to integers. This is useful for:
- Age in years (not fractional)
- Count variables (number of visits, events, etc.)
- Year variables
- Any continuous measure recorded as whole numbers

You can also explicitly specify integer variables using the `integer(varlist)` option.

---

## Examples

### Example 1: Basic Synthesis

Generate synthetic version of current dataset with same size:

```stata
use patient_data, clear
synthdata, saving(synthetic_patients) compare
```

### Example 2: Larger Synthetic Dataset

Generate 50,000 synthetic observations from smaller original:

```stata
use patient_data, clear
synthdata, n(50000) replace seed(12345)
```

### Example 3: Privacy-Preserving Synthesis

Generate synthetic data with privacy controls:

```stata
use sensitive_data, clear

synthdata, ///
    id(patient_id) ///
    mincell(10) ///
    trim(5) ///
    noextreme ///
    autoconstraints ///
    saving(safe_synthetic) ///
    validate(validation_stats) ///
    compare
```

### Example 4: Sequential Method with Custom Variable Types

Specify variable types and use sequential synthesis:

```stata
use medical_records, clear

synthdata, ///
    sequential ///
    categorical(sex diagnosis treatment) ///
    continuous(age bmi lab_value) ///
    dates(admission_date discharge_date) ///
    id(patient_id) ///
    n(20000) ///
    saving(synth_medical)
```

### Example 5: Multiple Synthetic Datasets

Generate 5 synthetic datasets for uncertainty quantification:

```stata
use cohort_data, clear

synthdata, ///
    multiple(5) ///
    n(10000) ///
    seed(54321) ///
    saving(synth_m) ///
    compare
```

This creates: `synth_m_1.dta`, `synth_m_2.dta`, ..., `synth_m_5.dta`

### Example 6: Synthesis with Constraints

Apply logical constraints to synthetic data:

```stata
use hr_data, clear

synthdata, ///
    constraints("age>=18" "age<=70" "hire_date<=term_date" "salary>=0") ///
    n(15000) ///
    saving(synth_hr) ///
    compare
```

### Example 7: Panel Data Synthesis

Preserve panel structure in longitudinal data:

```stata
use panel_data, clear

synthdata, ///
    panel(patient_id visit_num) ///
    preservevar(sex birth_date) ///
    autocorr(2) ///
    n(25000) ///
    saving(synth_panel)
```

### Example 8: Bootstrap with Validation

Generate synthetic data using bootstrap with comprehensive validation:

```stata
use clinical_trial, clear

synthdata, ///
    bootstrap ///
    noise(0.1) ///
    categorical(treatment_arm response) ///
    continuous(age weight bp) ///
    n(5000) ///
    saving(synth_trial) ///
    validate(trial_validation) ///
    compare ///
    graph
```

### Example 9: Selective Variable Synthesis

Synthesize only sensitive variables, skip identifiers:

```stata
use patient_records, clear

synthdata income assets debt diagnosis, ///
    id(patient_id record_id) ///
    skip(name address phone_number) ///
    saving(synth_selective)
```

### Example 10: Reproducible Synthesis for Collaboration

Create reproducible synthetic dataset for sharing:

```stata
use proprietary_data, clear

synthdata, ///
    parametric ///
    seed(999) ///
    n(10000) ///
    mincell(5) ///
    noextreme ///
    saving(share_synthetic) ///
    validate(share_validation) ///
    compare ///
    replace
```

---

## Validation and Quality Assessment

### Comparison Report

The `compare` option produces a detailed comparison table:

```stata
synthdata, saving(synth) compare
```

Output shows:
- Original vs synthetic means
- Original vs synthetic standard deviations
- Percentage difference (normalized by SD)

### Validation Statistics

The `validate(filename)` option saves detailed statistics:

```stata
synthdata, saving(synth) validate(validation_stats)
use validation_stats, clear
list
```

Contains:
- Mean, SD, min, max, percentiles for original and synthetic
- Utility metrics: mean_diff_pct, sd_ratio, range_coverage

### Utility Metrics

The `utility` option computes synthetic data utility measures:

```stata
synthdata, saving(synth) utility
```

### Density Plots

The `graph` option creates overlay density plots for continuous variables:

```stata
synthdata, saving(synth) graph
```

Shows original (blue solid) vs synthetic (red dashed) distributions.

---

## Best Practices

### 1. Choose the Right Method

- **Parametric**: Fast, good for normal data, preserves correlations
- **Sequential**: Best for mixed types and complex relationships
- **Bootstrap**: Simple, preserves empirical distributions
- **Permute**: Baseline/null comparison only

### 2. Protect Privacy

Always use privacy controls when sharing synthetic data:

```stata
synthdata, ///
    mincell(10) ///        // Protect rare categories
    trim(5) ///            // Remove extreme 5%
    noextreme ///          // Bound to observed range
    autoconstraints        // Enforce logical constraints
```

### 3. Validate Quality

Always validate synthetic data quality:

```stata
synthdata, ///
    saving(synth) ///
    validate(validation) ///
    compare ///
    graph
```

### 4. Use Seeds for Reproducibility

Always set a seed when sharing synthetic data:

```stata
synthdata, seed(12345) saving(synth)
```

### 5. Handle IDs Properly

Generate new sequential IDs for synthetic data:

```stata
synthdata, id(patient_id study_id) saving(synth)
```

### 6. Test Multiple Methods

Compare different synthesis methods:

```stata
synthdata, parametric saving(synth_param) validate(val_param)
synthdata, sequential saving(synth_seq) validate(val_seq)
synthdata, bootstrap saving(synth_boot) validate(val_boot)
```

---

## Limitations

Users should be aware of the following limitations:

- **High-dimensional interactions**: Difficult to preserve perfectly
- **Rare combinations**: May not appear in synthetic data
- **Nonlinear relationships**: May be attenuated
- **Privacy**: Synthetic data is NOT disclosure-proof; utility/privacy tradeoff exists
- **Performance**: Sequential method can be slow for many variables
- **Panel structure**: Preservation is simplified in this version

---

## Requirements

- Stata 16.0 or higher
- No additional dependencies (uses only built-in Stata commands and Mata)

## Documentation

- Command help: `help synthdata`
- Package overview: This README
- Full option reference: `help synthdata` (see Options section)

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.4.0, 2026-01-11

## See Also

- Stata help: `help simulate`, `help bootstrap`, `help permute`
- Related packages: `synth` (synthetic control methods)
