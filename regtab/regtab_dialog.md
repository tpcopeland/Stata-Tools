# regtab dialog - Graphical user interface for regtab

## Syntax

**Command line:**
```stata
db regtab
```

**Optional menu access:**
The dialog can be added to Stata menus. To set up menu integration, run:
```stata
do regtab_menu_setup.do
```

After menu setup: **User > Tables > Regression tables (regtab)**

## Description

The **regtab** dialog provides a graphical interface for formatting and exporting regression tables collected with Stata's `collect` commands. The dialog exports point estimates, 95% confidence intervals, and p-values to Excel with professional formatting.

## Prerequisites

Before using regtab:

1. Run your regression models using Stata 17+ `collect` commands
2. The collected results must be in memory
3. The regtab dialog will format and export these results

## Dialog structure

The regtab dialog consists of two tabs:

1. [Main](#main-tab) - Output file specification and formatting options
2. [Help/Examples](#helpexamples-tab) - Documentation and examples

---

## Main tab

### Required options

**Excel filename (.xlsx)** - Specify the output Excel file. Click "Browse..." to select a location. The file must have a `.xlsx` extension. If the file exists, it will be overwritten (no warning).

**Sheet name** - Name of the Excel sheet where the table will be placed (e.g., "Table1", "Results", "Model_Comparison").

### Optional formatting

**Table title** - Title that appears in cell A1 of the Excel sheet. If specified, the table starts at B2; otherwise it starts at A1.

**Coefficient label** - Label for the point estimate column (e.g., "OR" for odds ratios, "HR" for hazard ratios, "Coef." for coefficients, "IRR" for incidence rate ratios). If not specified, the column is labeled based on the model type.

**Model labels** - Custom labels for each model column, separated by backslash (`\`). The number of labels should match the number of models in your collected results.

**Example:**
```
Model 1 \ Model 2 \ Model 3
```

Or:
```
Unadjusted \ Age-adjusted \ Fully adjusted
```

**CI separator** - Character(s) separating the lower and upper bounds of the 95% confidence interval. Default is `, ` (comma-space). Common alternatives include ` to ` or ` - `.

**Drop intercept row** - Exclude the intercept from the exported table. Useful when intercepts are not of interest.

**Drop random effects rows** - Exclude random effects variance components from the exported table. Useful for mixed models when focusing on fixed effects.

---

## Help/Examples tab

The Help/Examples tab provides quick reference documentation and usage examples.

### Workflow

1. Run regression models using Stata's `collect` commands
2. Configure regtab options in the Main tab
3. Click OK to export the formatted table to Excel

### Examples shown in dialog

**Example 1: Basic usage**
```stata
regtab, xlsx(results.xlsx) sheet(Table1)
```

**Example 2: With model labels and title**
```stata
regtab, xlsx(results.xlsx) sheet(Table1) ///
    models(Model 1 \ Model 2) coef(OR) ///
    title(Table 1. Regression Results)
```

**Example 3: Customize separator and drop intercept**
```stata
regtab, xlsx(results.xlsx) sheet(Table1) sep(" to ") noint
```

---

## Complete workflow example

### Step 1: Run regressions with collect

```stata
* Load example data
sysuse auto, clear

* Create collection and run models
collect clear
collect: logit foreign mpg
collect: logit foreign mpg weight
collect: logit foreign mpg weight price

* Label models
collect label levels cmdset 1 "Model 1" 2 "Model 2" 3 "Model 3"
```

### Step 2: Open regtab dialog

```stata
db regtab
```

### Step 3: Configure and export

**Main tab:**
- Excel filename: `auto_regression.xlsx`
- Sheet name: `Logistic_Models`
- Table title: `Table 2. Logistic Regression Results`
- Coefficient label: `OR`
- Model labels: `Unadjusted \ + Weight \ + Weight + Price`

Click OK to create the formatted Excel file.

---

## Output format

The regtab command creates a professionally formatted Excel table:

**Layout:**
- Cell A1: Table title (if specified)
- Cell B2: Top-left corner of table (if title present) or A1 (if no title)
- Columns: Variable names, followed by one column per model
- Each model column shows: Point estimate, 95% CI, p-value

**Formatting:**
- Column widths automatically adjusted
- Cells merged appropriately for headers
- Numeric values formatted as numbers (not text)
- Professional appearance suitable for publication

---

## Remarks

### Using collect commands

The `collect` suite of commands (Stata 17+) provides a modern approach to regression tables:

```stata
collect clear
collect: regress outcome predictor1 predictor2
collect: regress outcome predictor1 predictor2 predictor3
```

After running these commands, use `regtab` to export the results.

### Model labeling

Model labels help readers understand the progression of models:
- "Unadjusted" vs "Adjusted"
- Sequential adjustment: "Model 1" / "+ Age" / "+ Age + Gender"
- Sensitivity analyses: "Main" / "Sensitivity 1" / "Sensitivity 2"

### Coefficient labels

Choose coefficient labels appropriate for your model:
- `OR` - Odds ratios (logistic regression)
- `HR` - Hazard ratios (Cox models)
- `IRR` - Incidence rate ratios (Poisson/negative binomial)
- `Coef.` or `β` - Linear regression coefficients
- `RR` - Risk ratios

### Excel formatting tips

The Excel file can be further customized after creation:
- Add footnotes below the table
- Apply additional formatting (bold, italics, colors)
- Add cell borders or shading
- Copy-paste into Word documents

The automatic column width and number formatting provide a professional starting point.

---

## Saved results

The regtab command works with the results stored by `collect` commands. After running, the Excel file contains the formatted table ready for inclusion in manuscripts.

---

## Also see

**Manual:** [R] collect, [R] table, [P] putexcel

**Related commands:** `help regtab`, `help collect`, `help table`, `help putexcel`

**Related dialog:** table1_tc (for baseline characteristics tables)
