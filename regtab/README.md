# regtab

![Stata 17+](https://img.shields.io/badge/Stata-17%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Format and export regression, treatment effects, and mediation analysis tables to Excel with professional formatting.

## Description

This package provides three commands for creating publication-ready Excel tables from Stata results:

### regtab - Regression Tables

`regtab` formats standard regression output (logit, regress, stcox, poisson, etc.) into polished Excel tables with point estimates, 95% CIs, and p-values.

### effecttab - Treatment Effects Tables

`effecttab` formats causal inference results including:
- **IPTW/MSM**: `teffects ipw` for inverse probability weighting
- **G-computation**: `teffects ra` and `margins` for regression adjustment
- **Doubly robust**: `teffects aipw`, `teffects ipwra`
- **Matching**: `teffects psmatch`, `teffects nnmatch`
- **Marginal effects**: `margins` with `dydx()`, `at()`, `over()`

### gformtab - Mediation Analysis Tables

`gformtab` formats output from the `gformula` command (parametric g-formula) including:
- **Total Causal Effect (TCE)**
- **Natural Direct Effect (NDE)**
- **Natural Indirect Effect (NIE)**
- **Proportion Mediated (PM)**
- **Controlled Direct Effect (CDE)**

`regtab` and `effecttab` work with Stata 17+ `collect` commands. `gformtab` works with the user-written `gformula` command. All create publication-ready tables with professional Excel formatting.

## Dependencies

**Required:**
- Stata 17.0 or higher for `regtab` and `effecttab` (requires `collect` commands)
- Stata 16.0 or higher for `gformtab`
- `putexcel` command (built-in to Stata 14+)

**Optional (for gformtab):**
- `gformula` command from SSC: `ssc install gformula`

## Installation

```stata
net install regtab, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/regtab")
```

## Syntax

```stata
regtab, xlsx(string) sheet(string) [sep(string) models(string) coef(string)
    title(string) noint nore]
```

**Required:** An active `collect` with items `_r_b`, `_r_ci`, and `_r_p` and dimensions including `colname` and `cmdset`.

## Options

### Required Options

| Option | Description |
|--------|-------------|
| `xlsx(string)` | Output Excel filename (must end with `.xlsx`). If the file exists, only the named sheet is replaced. |
| `sheet(string)` | Target sheet name to create/replace in the Excel file. |

### Optional Formatting Options

| Option | Default | Description |
|--------|---------|-------------|
| `sep(string)` | `", "` | Delimiter between CI endpoints used by `collect cidelimiter()`. Example alternative: `sep("; ")`. |
| `models(string)` | (none) | Labels to merge above each model's three columns. Separate labels with a backslash, e.g., `"Model 1 \ Model 2"`. If omitted, model labels are not included. |
| `coef(string)` | (blank or collect default) | Header label for the point estimate column (the `_r_b` result). Set this to `"OR"`, `"RR"`, `"Coef."`, `"HR"`, etc., as desired. If omitted, the collect default/blank label is used. |
| `title(string)` | (none) | Text written into cell `A1` and merged across the table width. If omitted, the title row is left blank. |
| `noint` | not dropped | Drop the intercept row. Matches `_cons`, `constant`, or `Intercept` (case-insensitive). |
| `nore` | not dropped | Drop rows whose variable name contains `var(...)`  (common for random-effects variance components). |

## Workflow

1. **Run regressions** using `collect:` prefix or add results to an active `collect`
2. **Format and export** with `regtab` to create a polished Excel table

## Examples

### Example 1: Single Model with Custom Labels

```stata
collect clear
collect: logit case i.exposure age i.sex
regtab, xlsx(results.xlsx) sheet("Table 1") ///
    coef("OR") ///
    title("Table 1. Logistic regression") ///
    sep("; ")
```

This creates a single model table with:
- Odds ratios labeled as "OR"
- CI delimiter as semicolon ("; " instead of ", ")
- A title in cell A1

### Example 2: Multiple Models with Headers and No Intercept

```stata
collect clear
collect: logit case i.exposure age i.sex
collect: logit case i.exposure age i.sex i.region
regtab, xlsx(results.xlsx) sheet("Table 2") ///
    models("Unadj \ Adj") ///
    coef("OR") ///
    title("Table 2. Odds ratios") ///
    noint
```

This creates a two-model table with:
- Model headers "Unadj" and "Adj" merged above each set of three columns
- Intercept row removed
- Coefficients labeled as "OR"

### Example 3: Mixed Model with Random Effects Suppressed

```stata
collect clear
collect: melogit outcome i.treat age || facility:
regtab, xlsx(results.xlsx) sheet("Table 3") ///
    models("GEE") ///
    coef("RR") ///
    title("Table 3. Rate ratios") ///
    nore
```

This creates a mixed/multilevel model table with:
- Random-effects variance components hidden
- Model labeled as "GEE"
- Coefficients labeled as "RR"

### Example 4: Multiple Models from Auto Dataset

```stata
* Load data and clear any previous collect
sysuse auto, clear
collect clear

* Run three logistic regression models
collect: logit foreign mpg
collect: logit foreign mpg weight
collect: logit foreign mpg weight price

* Export formatted table
regtab, xlsx(results.xlsx) sheet(Models) ///
    models(Model 1 \ Model 2 \ Model 3) ///
    coef(OR) ///
    title(Logistic Regression Results)
```

This demonstrates a typical workflow with progressively adjusted models.

## Output Format

The Excel output includes:

- **Cell A1**: Optional title (if `title()` specified), merged across table width
- **Row 2**: Optional model headers (if `models()` specified), merged across each model's three columns
- **Row 3**: Column headers: Variable name, then for each model: `coef`, "95% CI", "p-value"
- **Rows 4+**: Data rows with variable names and results

### Formatting Applied

- **Fonts**: Arial 10 point
- **Borders**: Around the table and model blocks
- **Alignment**: Centered for headers, appropriate alignment for data
- **Column widths**: Automatically adjusted to fit content
- **Number formats**:
  - Point estimates (`_r_b`): %4.2fc (e.g., 1.23)
  - Confidence intervals (`_r_ci`): Formatted as (lower, upper) or (lower; upper) depending on `sep()`
  - P-values (`_r_p`): %5.4f (e.g., 0.0234)

### Special Handling

- **Reference categories**: If a point estimate is 0 or 1 and the adjacent CI cell is empty, `regtab` substitutes "Reference" in the estimate column
- **Intercept removal**: The `noint` option removes rows matching `_cons`, `constant`, or `Intercept` (case-insensitive)
- **Random effects removal**: The `nore` option removes rows containing `var(...)` patterns common in mixed model output

## Remarks

### Prerequisites and Expectations

- **Run models first**: Run your models inside `collect:` or otherwise ensure the relevant results are in the active `collect`. `regtab` does not run models.
- **Required items**: `regtab` expects dimensions including `colname` and `cmdset`, and result items `_r_b`, `_r_ci`, `_r_p`
- **Styling**: The command applies cell styles: `_r_b` as %4.2fc, `_r_ci` as `sformat("(%s")` with `cidelimiter()`, and `_r_p` as %5.4f
- **CI delimiter**: The CI delimiter is controlled by `sep()`; default is `", "`. Example alternative: `sep("; ")`
- **Coefficient labels**: If `coef()` is not provided, the header label above `_r_b` may be blank depending on your `collect` labels; set it explicitly for clarity (e.g., `coef("OR")`)
- **Model headers**: Model header labels are included only when `models()` is supplied; the labels are split on the backslash character

### Notes on Output Shaping

- **Baseline/reference rows**: If a point estimate is 0 or 1 and the adjacent CI cell is empty, `regtab` substitutes "Reference" in the estimate column
- **Row removal**: Intercept and random-effects rows can be removed using `noint` and `nore`, respectively
- **Formatting details**: Fonts are set to Arial 10. Borders are drawn around the table and model blocks. Column widths and row heights are adjusted heuristically to fit labels and contents
- **Temporary files**: The command writes the Excel output using `putexcel`; a temporary workbook `temp.xlsx` is created and deleted during processing

### Working with Existing Excel Files

- If the Excel file specified in `xlsx()` already exists, only the specified sheet will be replaced
- Other sheets in the workbook will remain unchanged
- This allows you to build multi-table Excel workbooks by running `regtab` multiple times with different sheet names

## Dialog Interface

Access the graphical user interface:

```stata
db regtab
```

Optional menu integration:

```stata
do regtab_menu_setup.do
```

See `regtab_dialog.md` for detailed dialog documentation.

## Stored Results

`regtab` stores nothing in `r()`. It clears the active `collect` at the end and deletes the temporary workbook.

## Requirements

- Stata 17.0 or higher
- No external dependencies - uses built-in `collect` and `putexcel` commands

## Common Use Cases

1. **Publication tables**: Create formatted tables ready for journal submission
2. **Multiple specifications**: Compare different model specifications side-by-side
3. **Presentations**: Export professional-looking tables for presentations
4. **Reports**: Generate automated regression output for regular reports
5. **Adjusted models**: Show unadjusted and adjusted models in a single table

## Tips and Best Practices

1. **Always use coef()**: Explicitly set the coefficient label for clarity (OR, HR, RR, Coef., etc.)
2. **Model labels**: Use descriptive model labels that help readers understand what each model includes
3. **Test first**: Run `regtab` on a test file first to verify formatting before overwriting important files
4. **Consistent formatting**: Use the same `sep()` option across related tables for consistency
5. **Check reference categories**: Verify that reference category labeling is correct
6. **Remove clutter**: Use `noint` and `nore` to remove rows that aren't relevant for your table

---

## effecttab - Treatment Effects Tables

### Syntax

```stata
effecttab, xlsx(string) sheet(string) [type(string) effect(string) sep(string)
    models(string) title(string) clean]
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `xlsx(string)` | required | Output Excel filename (must end with `.xlsx`) |
| `sheet(string)` | required | Target sheet name |
| `type(string)` | `auto` | Result type: `teffects`, `margins`, or `auto` |
| `effect(string)` | varies | Label for effect column (ATE, RD, RR, AME, etc.) |
| `models(string)` | none | Model labels separated by backslash |
| `title(string)` | none | Table title for cell A1 |
| `clean` | off | Clean teffects labels (e.g., "r1vs0.treat" to "Treat (1 vs 0)") |

### effecttab Examples

#### Example 1: IPTW Treatment Effect

```stata
* Load data
sysuse cancer, clear

* Estimate ATE using IPTW
collect clear
collect: teffects ipw (died) (drug age), ate

* Export formatted table
effecttab, xlsx(results.xlsx) sheet("ATE") ///
    effect("ATE") ///
    title("Average Treatment Effect (IPTW)") ///
    clean
```

#### Example 2: Compare IPTW and Doubly Robust

```stata
collect clear
collect: teffects ipw (died) (drug age), ate
collect: teffects aipw (died age) (drug age), ate

effecttab, xlsx(results.xlsx) sheet("Comparison") ///
    models("IPTW \ AIPW") ///
    effect("ATE") ///
    clean
```

#### Example 3: Marginal Effects (G-computation style)

```stata
sysuse auto, clear
logit foreign mpg weight

collect clear
collect: margins, dydx(mpg weight)

effecttab, xlsx(results.xlsx) sheet("AME") ///
    effect("AME") ///
    title("Average Marginal Effects")
```

#### Example 4: Predicted Probabilities

```stata
logit foreign i.rep78 mpg weight

collect clear
collect: margins rep78

effecttab, xlsx(results.xlsx) sheet("Predictions") ///
    type(margins) ///
    effect("Pr(Foreign)") ///
    title("Predicted Probability by Repair Record")
```

---

## gformtab - Mediation Analysis Tables

### Syntax

```stata
gformtab, xlsx(string) sheet(string) [ci(string) effect(string) title(string)
    labels(string) decimal(#)]
```

### Description

`gformtab` formats output from the user-written `gformula` command (parametric g-formula for causal mediation analysis). It exports:

- Total Causal Effect (TCE)
- Natural Direct Effect (NDE)
- Natural Indirect Effect (NIE)
- Proportion Mediated (PM)
- Controlled Direct Effect (CDE)

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `xlsx(string)` | required | Output Excel filename (must end with `.xlsx`) |
| `sheet(string)` | required | Target sheet name |
| `ci(string)` | `normal` | CI type: `normal`, `percentile`, `bc`, or `bca` |
| `effect(string)` | `Effect` | Label for effect column |
| `title(string)` | none | Table title for cell A1 |
| `labels(string)` | default labels | Custom effect labels separated by backslash |
| `decimal(#)` | 3 | Decimal places for estimates (1-6) |

### gformtab Examples

#### Example 1: Basic Mediation Analysis

```stata
* Run gformula first (example syntax)
gformula outcome mediator treatment confounder, ///
    outcome(outcome) treatment(treatment) mediator(mediator) ///
    control(0) base_confs(confounder) sim(1000) bootstrap(500)

* Format results to Excel
gformtab, xlsx(mediation.xlsx) sheet("Table 1") ///
    title("Table 1. Causal Mediation Analysis")
```

#### Example 2: Using Percentile Bootstrap CIs

```stata
gformtab, xlsx(mediation.xlsx) sheet("Percentile CI") ///
    ci(percentile) title("Mediation Results (Percentile CI)")
```

#### Example 3: Custom Effect Labels

```stata
gformtab, xlsx(mediation.xlsx) sheet("Custom") ///
    labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated \ CDE") ///
    effect("RD") title("Risk Difference Decomposition")
```

### Prerequisites

Run `gformula` with the bootstrap option before using `gformtab`. The `gformula` command is available from the SSC archive:

```stata
ssc install gformula
```

---

## Version History

- **Version 1.2.0** (19 December 2025): Added gformtab for mediation analysis
  - New `gformtab` command for gformula output
  - Formats TCE, NDE, NIE, PM, and CDE with CIs and SEs
  - Support for normal, percentile, BC, and BCa confidence intervals
  - Custom labels and decimal precision options
- **Version 1.1.0** (19 December 2025): Added effecttab for causal inference
  - New `effecttab` command for teffects and margins output
  - Supports IPTW, g-computation, doubly robust, and matching estimators
  - Auto-detection of result type (teffects vs margins)
  - Clean option for human-readable effect labels
- **Version 1.0.3** (5 December 2025): Minor updates
- **Version 1.0.1** (3 December 2025): Code quality improvements
  - Added version declarations and varabbrev settings to helper programs
  - Enhanced error handling for Excel import/export operations
  - Added file path sanitization for security
  - Improved error messages for better user feedback
- **Version 1.0.0** (2 December 2025): GitHub publication release

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## See Also

- `help regtab` - Regression tables command
- `help effecttab` - Treatment effects tables command
- `help gformtab` - Mediation analysis tables command
- `help collect` - Stata's collect system for tables
- `help teffects` - Treatment effects estimation
- `help margins` - Marginal effects and predictions
- `help putexcel` - Export results to Excel
- `regtab_dialog.md` - Detailed dialog documentation
- SSC package `gformula` - Parametric g-formula for mediation analysis

## Getting Help

For more detailed information, you can access the Stata help files:
```stata
help regtab
help effecttab
help gformtab
```
