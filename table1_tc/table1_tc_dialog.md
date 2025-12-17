# table1_tc dialog - Graphical user interface for table1_tc

## Syntax

**Command line:**
```stata
db table1_tc
```

**Optional menu access:**
The dialog can be added to Stata menus. To set up menu integration, run:
```stata
do table1_tc_menu_setup.do
```

After menu setup: **User > Tables > Table 1 (table1_tc)**

## Description

The **table1_tc** dialog provides a graphical interface for creating publication-ready "Table 1" of baseline characteristics. The dialog guides you through specifying variables, formatting options, grouping, and export settings.

## Dialog structure

The table1_tc dialog consists of three tabs:

1. [Main](#main-tab) - Variables, sample selection, and basic options
2. [By Group](#by-group-tab) - Grouping and p-value options
3. [Output](#output-tab) - Excel export and formatting

---

## Main tab

The Main tab contains the core specifications for creating your Table 1.

### Sample selection

**If condition** - Optional condition to restrict the sample (e.g., `age >= 18`).

**In range** - Optional observation range (e.g., `1/100`).

### Weights

**Frequency weights** - Specify a frequency weight variable if needed.

### Variables to display (REQUIRED)

This is the core specification. List variables with their types, separated by backslash (`\`).

**Format:** `varname type [format1] [format2] \ ...`

**Variable types:**
- `contn` - Continuous normal distribution (reports mean and SD)
- `contln` - Continuous log-normal (reports geometric mean and ratio)
- `conts` - Continuous skewed (reports median and IQR)
- `cat` - Categorical (uses chi-square test)
- `cate` - Categorical with exact test (uses Fisher's exact)
- `bin` - Binary (uses chi-square test)
- `bine` - Binary with exact test (uses Fisher's exact)

**Example:**
```
age contn \ weight contn \ gender bin \ race cat %10.0f
```

### Quick reference - Statistical tests

The dialog displays which statistical tests are used for each variable type when using the by() option:
- Normal continuous: two-sample t-test
- Log-normal continuous: two-sample t-test on log scale
- Skewed continuous: rank-sum test
- Categorical: chi-square or Fisher's exact
- Binary: chi-square or Fisher's exact

---

## By Group tab

The By Group tab controls grouping and statistical testing.

### Grouping variable

**Group by variable** - Categorical variable to stratify the table by (creates columns).

**Show total column** - Include an "Overall" or "Total" column alongside group-specific columns.

### P-value options

**Test column** - Display p-values from statistical tests comparing groups.

**P-value label** - Custom label for the p-value column (default is "P-value").

---

## Output tab

The Output tab controls Excel export and formatting options.

### Excel export

**Export to Excel** - Enable Excel export functionality.

**Excel filename** - Path to .xlsx file (use Browse button).

**Sheet name** - Name of the Excel sheet.

**Replace** - Overwrite existing file if it exists.

**Open after export** - Automatically open the Excel file after creation.

### Formatting options

**One column for categorical** - Display categorical variables in a single column instead of separate columns for each category.

**Default format** - Number format for continuous variables (default: `%9.1f`).

**Percentage format** - Format for percentages in categorical/binary variables (default: `%9.1f`).

**N format** - Format for counts (default: `%12.0fc` with comma separator).

**IQR separator** - Character between Q1 and Q3 (default: `-`).

**SD left symbol** - Symbol before SD value (default: ` (`).

**SD right symbol** - Symbol after SD value (default: `)`).

---

## Examples

### Example 1: Basic Table 1 without groups

```stata
db table1_tc
```

**Main tab:**
- Variables: `age contn \ bmi contn \ female bin \ race cat`
- Click OK

Creates a simple descriptive table with all observations.

### Example 2: Table 1 by treatment group with p-values

```stata
db table1_tc
```

**Main tab:**
- Variables: `age contn \ bmi conts \ sbp contn \ female bin \ comorbidity cat`

**By Group tab:**
- Group by: `treatment`
- Check: "Show total column"
- Check: "Test column"

Creates a table stratified by treatment with statistical tests.

### Example 3: Export to Excel with custom formatting

```stata
db table1_tc
```

**Main tab:**
- Variables: `age contn \ weight contn \ race cat \ outcome bin`

**By Group tab:**
- Group by: `study_arm`
- Check: "Test column"

**Output tab:**
- Check: "Export to Excel"
- Excel filename: `table1_results.xlsx`
- Sheet name: `BaselineCharacteristics`
- Check: "Replace"
- One column for categorical: checked
- Default format: `%9.2f`

Creates a formatted Excel table with custom number formatting.

### Example 4: Using if/in conditions

```stata
db table1_tc
```

**Main tab:**
- Check "If:" and enter: `complete_case == 1`
- Variables: `age contn \ bp contn \ medication bin`

**By Group tab:**
- Group by: `treatment_group`

Creates Table 1 restricted to complete cases only.

---

## Remarks

### Variable type selection

Choose the appropriate variable type based on distribution:
- Use `contn` for normally distributed continuous variables
- Use `conts` for skewed continuous variables (displays median/IQR)
- Use `contln` for variables better analyzed on log scale
- Use `cat` for multi-category variables
- Use `bin` for binary (0/1) variables
- Add `e` suffix (`cate`, `bine`) to use exact tests instead of asymptotic tests

### Excel export features

When exporting to Excel:
- The title appears in cell A1
- The table starts at cell A2 (or B2 if there's a title)
- Columns are automatically sized for readability
- Numeric values are properly formatted as numbers (not text)
- Use the "Open after export" option for immediate viewing

### Format specifications

You can specify one or two formats after the variable type:
- One format: applies to all statistics for that variable
- Two formats: first for main statistic, second for secondary statistic
- Example: `age contn %9.1f %9.2f` (mean with 1 decimal, SD with 2 decimals)

---

## Saved results

After running the command via the dialog, results are stored in `s()` (sclass):

**Macros:**
- `s(cmd)` - `table1_tc`
- Various statistics depending on options used

---

## Also see

**Manual:** [R] table, [R] tabulate, [R] summarize

**Related commands:** `help table1_tc`, `help table`, `help tabstat`
