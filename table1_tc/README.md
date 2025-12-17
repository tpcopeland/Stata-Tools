f# table1_tc

![Stata 14.2+](https://img.shields.io/badge/Stata-14.2%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Create publication-ready Table 1 of baseline characteristics with automatic statistical testing and Excel export.

## Description

`table1_tc` generates descriptive statistics tables ("Table 1") commonly used in manuscripts to summarize baseline characteristics. The command handles both continuous and categorical variables, automatically selects appropriate statistical tests when stratified by group, and exports publication-ready tables directly to Excel with professional formatting.

This command is a fork of Mark Chatfield's `table1_mc`, itself based on Phil Clayton's `table1`, with enhanced Excel export capabilities including automatic column width calculation, customizable borders, and formatted headers.

## Key Features

- Automatic statistical test selection based on variable type and distribution
- Direct export to formatted Excel files with professional styling
- Support for 7 variable types (normal, log-normal, skewed, categorical, binary)
- Customizable p-value precision and formatting options
- Flexible presentation of statistics (means, medians, percentages, etc.)
- Built-in dialog interface for point-and-click usage

## Dependencies

None - uses only built-in Stata commands.

## Installation

```stata
net install table1_tc, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/table1_tc")
```

## Syntax

```stata
table1_tc [if] [in] [fweight], vars(var_spec) [options]
```

### Variable specification

**vars(var_spec)** is required and contains variables with their types:

```
vars(varname vartype [%fmt1 [%fmt2]] \ varname vartype [%fmt1 [%fmt2]] \ ...)
```

- Variables are separated by backslash (`\`)
- Each variable requires a type designation
- Optional format specifications override defaults
- `%fmt1` controls the main statistic format
- `%fmt2` controls the secondary statistic format (SD, IQR, etc.)

### Variable types

| Type | Description | Summary Statistics | Statistical Test |
|------|-------------|-------------------|------------------|
| **contn** | Continuous, normally distributed | Mean (SD) | ANOVA / t-test |
| **contln** | Continuous, log-normally distributed | Geometric mean (GSD) | ANOVA on log-transformed values |
| **conts** | Continuous, skewed distribution | Median (Q1-Q3) | Kruskal-Wallis / Wilcoxon rank-sum |
| **cat** | Categorical variable | n (%) for each level | Pearson's chi-square test |
| **cate** | Categorical variable | n (%) for each level | Fisher's exact test |
| **bin** | Binary variable (0/1) | n (%) | Pearson's chi-square test |
| **bine** | Binary variable (0/1) | n (%) | Fisher's exact test |

**When to use each type:**
- Use `contn` for normally distributed continuous variables (age, height, etc.)
- Use `contln` for log-normally distributed variables (concentrations, titers)
- Use `conts` for skewed continuous variables (income, hospital stay)
- Use `cat` for categorical variables with expected cell counts ≥ 5
- Use `cate` for categorical variables with small expected cell counts
- Use `bin` for binary variables with adequate sample size
- Use `bine` for binary variables with small sample sizes or rare events

## Options

### Columns and rows

| Option | Description | Default |
|--------|-------------|---------|
| **by(varname)** | Group observations by varname for stratification | Not specified |
| **total(before\|after)** | Include a total column before or after group columns | Not included |
| **onecol** | Report categorical variable levels under variable name | Separate columns |
| **missing** | Treat missing values as a category for cat/cate variables | Excluded |
| **test** | Include column describing the statistical test used | Not included |
| **statistic** | Include column with test statistic values | Not included |
| **pairwise123** | Report pairwise comparisons between first 3 groups | Not included |
| **headerperc** | Add percentage of total to sample size row | Not included |

### Formatting: Numeric display

| Option | Description | Default |
|--------|-------------|---------|
| **format(%fmt)** | Default format for continuous variables | Variable's current format |
| **percformat(%fmt)** | Format for percentages | Auto (0 or 1 decimal) |
| **nformat(%fmt)** | Format for n and N | %12.0fc |
| **pdp(#)** | Decimal places for p < 0.10 | 3 |
| **highpdp(#)** | Decimal places for p ≥ 0.10 | 2 |

### Formatting: Text presentation

| Option | Description | Default |
|--------|-------------|---------|
| **varlabplus** | Add ", mean (SD)" etc. after variable labels | Single footnote |
| **iqrmiddle("string")** | Text between Q1 and Q3 | "-" |
| **sdleft("string")** | Text before SD | "(" |
| **sdright("string")** | Text after SD | ")" |
| **gsdleft("string")** | Text before geometric SD | "(×/" |
| **gsdright("string")** | Text after geometric SD | ")" |
| **percsign("string")** | Percentage symbol | "%" |
| **nospacelowpercent** | Report (3%) instead of ( 3%) | Include space |
| **extraspace** | Extra space for alignment in .docx with non-monospaced fonts | Not included |

### Formatting: Categorical/binary variables

| Option | Description | Default |
|--------|-------------|---------|
| **percent** | Report % instead of n (%) | n (%) |
| **percent_n** | Report % (n) instead of n (%) | n (%) |
| **slashN** | Report n/N instead of n (%) | n (%) |
| **catrowperc** | Row percentages for categorical (not binary) variables | Column percentages |

### Excel output

| Option | Description | Default |
|--------|-------------|---------|
| **excel("filename.xlsx")** | Save table to Excel file (requires sheet and title) | Not specified |
| **sheet("sheetname")** | Name of Excel sheet | Required with excel |
| **title("string")** | Title for the Excel table | Required with excel |
| **borderstyle(default\|thin)** | Border style: default=mixed, thin=uniform | default |

### Other output

| Option | Description | Default |
|--------|-------------|---------|
| **clear** | Replace dataset in memory with the table | Original data preserved |

### Pre-configured style

| Option | Description | Equivalent to |
|--------|-------------|---------------|
| **gurmeet** | Specific formatting style | percformat(%5.1f) percent_n percsign("") iqrmiddle(",") sdleft(" [±") sdright("]") gsdleft(" [×/") gsdright("]") onecol extraspace |

## Statistical Tests

The command automatically selects statistical tests based on variable type:

### Continuous variables

**Normal (contn):**
- **Test:** One-way ANOVA (>2 groups) or independent t-test (2 groups)
- **Assumptions:** Normal distribution, equal variances
- **Reported:** Mean (SD)

**Log-normal (contln):**
- **Test:** One-way ANOVA on log-transformed values
- **Assumptions:** Log-normal distribution
- **Reported:** Geometric mean (GSD)
- **Note:** GSD uses the times-divide symbol (×/) following Kirkwood (1979)

**Skewed (conts):**
- **Test:** Kruskal-Wallis test (>2 groups) or Wilcoxon rank-sum test (2 groups)
- **Assumptions:** Non-parametric, handles ties
- **Reported:** Median (Q1-Q3)

### Categorical and binary variables

**Chi-square (cat, bin):**
- **Test:** Pearson's chi-square test
- **Use when:** Expected cell counts ≥ 5
- **Reported:** n (%) for each category

**Exact test (cate, bine):**
- **Test:** Fisher's exact test
- **Use when:** Small expected cell counts or rare events
- **Reported:** n (%) for each category

## Examples

### Example 1: Basic Table 1

```stata
sysuse auto, clear
generate much_headroom = (headroom >= 3)

table1_tc, vars(weight contn \ price contln \ mpg conts \ rep78 cate \ much_headroom bin)
```

Creates a simple descriptive table with various variable types.

### Example 2: Stratified analysis with p-values

```stata
table1_tc, by(foreign) ///
    vars(weight contn \ price contln \ mpg conts \ rep78 cate \ much_headroom bin) ///
    onecol
```

Stratifies by foreign/domestic with automatic statistical testing.

### Example 3: Complete table with total column and test descriptions

```stata
table1_tc, by(foreign) ///
    vars(weight contn \ price contln \ mpg conts \ rep78 cate \ much_headroom bin) ///
    total(before) test statistic onecol
```

Includes total column, test names, and test statistics.

### Example 4: Excel export with professional formatting

```stata
table1_tc, by(foreign) ///
    vars(weight contn \ price contln \ mpg conts \ rep78 cate \ much_headroom bin) ///
    onecol total(before) headerperc ///
    excel("Auto Tables.xlsx") sheet("Table 1") title("Table 1: Characteristics by Foreign Status")
```

Exports formatted table directly to Excel with automatic column widths and professional styling.

### Example 5: Custom formatting for continuous variables

```stata
table1_tc, by(treatment) ///
    vars(age contn %5.1f \ bmi conts %4.1f %4.1f \ weight contn %6.2f %5.2f) ///
    format(%6.2f) percformat(%5.1f)
```

Specifies custom formats for individual variables and defaults.

### Example 6: Percentage-focused presentation

```stata
table1_tc, by(treatment) ///
    vars(female bin \ smoker bin \ diabetes bin \ race cat) ///
    percent_n percsign("") onecol
```

Reports percentages before counts without percentage signs.

### Example 7: Custom p-value precision

```stata
table1_tc, by(treatment) ///
    vars(age contn \ bmi conts \ female bin \ race cat) ///
    pdp(4) highpdp(3)
```

Uses 4 decimal places for p < 0.10 and 3 for p ≥ 0.10.

### Example 8: Row percentages for categorical variables

```stata
table1_tc, by(treatment) ///
    vars(race cat \ education cat \ region cat) ///
    catrowperc onecol
```

Reports row percentages instead of column percentages for categorical variables.

### Example 9: Pairwise comparisons

```stata
table1_tc, by(treatment) ///
    vars(age contn \ bmi conts \ female bin) ///
    pairwise123
```

Reports pairwise comparisons between the first three treatment groups.

### Example 10: Including missing values as a category

```stata
table1_tc, by(treatment) ///
    vars(race cat \ education cat) ///
    missing onecol
```

Treats missing values as an additional category level.

### Example 11: Alternative statistical notation

```stata
table1_tc, by(treatment) ///
    vars(age contn \ bmi conts) ///
    sdleft("±") sdright("") iqrmiddle(", ")
```

Formats as: mean±SD and median (Q1, Q3).

### Example 12: Clinical trial Table 1 with Excel export

```stata
table1_tc, by(treatment_arm) ///
    vars(age contn %5.1f \ bmi conts %4.1f \ ///
         female bin \ race cate \ ///
         baseline_bp contn %5.1f \ ///
         diabetes bin \ smoker bin) ///
    total(before) onecol headerperc ///
    excel("Clinical_Trial_Table1.xlsx") ///
    sheet("Baseline") ///
    title("Table 1: Baseline Characteristics by Treatment Arm") ///
    borderstyle(thin)
```

Complete clinical trial baseline characteristics table with thin border styling.

### Example 13: Using with survey weights

```stata
svyset [pweight=surveyweight]
table1_tc [fweight=surveyweight], by(region) ///
    vars(age contn \ income conts \ education cat)
```

Incorporates frequency weights for weighted analyses.

### Example 14: Minimalist table saved to memory

```stata
table1_tc, by(treatment) ///
    vars(age contn \ bmi conts \ female bin) ///
    onecol clear
```

Replaces data in memory with the table for further manipulation.

## Excel Export Details

When using the `excel()` option, the command:

1. **Automatically calculates optimal column widths** based on content
2. **Applies professional formatting:**
   - Bold headers with bottom border
   - Centered numeric columns
   - Left-aligned text columns
   - Automatic number formatting
3. **Supports two border styles:**
   - `default`: Mixed borders (headers, totals emphasized)
   - `thin`: Uniform thin borders throughout
4. **Includes data presentation descriptions** in the upper-left cell
5. **Requires three arguments:**
   - `excel("filename.xlsx")`: Output file path
   - `sheet("name")`: Sheet name
   - `title("text")`: Table title

The Excel output requires no manual formatting and is ready for inclusion in manuscripts or reports.

## Dialog Interface

### Command-line dialog

```stata
db table1_tc
```

Opens a graphical dialog for point-and-click table creation.

### Menu integration (optional)

```stata
do table1_tc_menu_setup.do
```

Adds table1_tc to Stata's menu system for easy access.

## Tips and Best Practices

### Variable type selection

- **Test normality** before choosing `contn` vs `conts` (use `histogram`, `qnorm`, or `sktest`)
- **Check for log-normality** when dealing with concentrations, titers, or multiplicative processes
- **Use exact tests** (`cate`, `bine`) when expected cell counts are small (< 5)
- **Consider sample size** when choosing between chi-square and exact tests

### Formatting recommendations

- **Use `onecol`** for cleaner tables when space is limited
- **Include `total(before)`** to show overall sample characteristics
- **Add `headerperc`** to show group distribution in the header
- **Specify `test`** for transparency about statistical methods
- **Use consistent formats** across similar variables for professional appearance

### Statistical considerations

- **P-values are unadjusted** for multiple comparisons; consider adjustment if testing many variables
- **Use `pairwise123`** cautiously as comparisons are also unadjusted
- **Consider effect sizes** in addition to p-values (not provided by this command)
- **Report confidence intervals** separately for key comparisons

### Excel export tips

- **Use descriptive sheet names** for multi-sheet workbooks
- **Choose `borderstyle(thin)`** for simpler, cleaner tables
- **Include informative titles** that can stand alone
- **Test output** before final export to ensure formatting meets journal requirements

## Comparison with Stata's dtable

Stata 18+ includes `dtable`, which provides similar functionality with additional features:

**Advantages of table1_tc:**
- Works with Stata 14.2+ (dtable requires 18+)
- Simpler syntax for straightforward tables
- Direct Excel export with automatic formatting
- Established workflow for many users

**Advantages of dtable:**
- More flexible customization through `collect` suite
- Built-in effect size calculations
- More export format options
- Official Stata support

For users with Stata 18+, consider `dtable` for complex tables; `table1_tc` remains excellent for standard Table 1 needs and Excel-focused workflows.

## Requirements

- Stata 14.2 or higher
- No external dependencies

## Stored Results

The command can store the table in memory using the `clear` option, replacing the current dataset with a dataset containing the table structure.

## References

**Statistical methods:**
- Kirkwood TBL. Geometric means and measures of dispersion. *Biometrics* 1979; 35: 908-909.
- Limpert E, Stahel WA. Problems with Using the Normal Distribution – and Ways to Improve Quality and Efficiency of Data Analysis. *PLoS ONE* 2011; 6(7):e21403.

**Software lineage:**
- Original `table1` by Phil Clayton, ANZDATA Registry, Australia
- `table1_mc` by Mark Chatfield, The University of Queensland, Australia
- `table1_tc` (this fork) by Timothy P. Copeland, Karolinska Institutet

## Version History

- **Version 1.0.3** (5 December 2025): Minor updates
- **Version 1.0.1** (3 December 2025): Code quality improvements
  - Added observation count validation after marksample
  - Added file path security validation for Excel export
  - Fixed macro assignment syntax in gurmeet preset
- **Version 1.0.0** (2 December 2025): GitHub publication release

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Support

For detailed help:
```stata
help table1_tc
```

For dialog documentation, see: `table1_tc_dialog.md`

For issues or feature requests, please contact the author or visit the GitHub repository.
