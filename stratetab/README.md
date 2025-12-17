# stratetab

![Stata 17+](https://img.shields.io/badge/Stata-17%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Combine strate output files and export to Excel with outcomes as column groups and exposure variables as rows.

## Description

`stratetab` combines pre-computed `strate` output files and exports them to Excel with outcomes as column groups and exposure variables as rows. Each outcome spans three columns: Events, Person-Years, and Rate (95% CI).

The command reads multiple .dta files produced by `strate`, organized by exposure type. Files should be listed in order: all outcomes for exposure 1, then all outcomes for exposure 2, etc. For example, with 3 outcomes and 2 exposure types: *out1_exp1 out2_exp1 out3_exp1 out1_exp2 out2_exp2 out3_exp2*.

`stratetab` cannot be combined with `by:`.

## Dependencies

Requires **strate** (built-in Stata survival analysis command). Data must be declared as survival-time data using `stset`.

## Installation

```stata
net install stratetab, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/stratetab")
```

## Syntax

```stata
stratetab, using(namelist) xlsx(string) outcomes(integer) [options]
```

### Required Options

| Option | Description |
|--------|-------------|
| **using(namelist)** | Space-separated list of strate output files (without .dta extension) |
| **xlsx(string)** | Excel output file (must have .xlsx extension) |
| **outcomes(integer)** | Number of distinct outcomes; total files must be divisible by this number |

### Optional Options

| Option | Default | Description |
|--------|---------|-------------|
| **sheet(string)** | Results | Excel sheet name |
| **title(string)** | *(none)* | Title text that appears in row 1 of the output table |
| **outlabels(string)** | Outcome 1, Outcome 2, ... | Outcome labels separated by backslash (`\`); must match `outcomes()` count |
| **explabels(string)** | Exposure 1, Exposure 2, ... | Exposure group labels separated by backslash (`\`); must match number of exposure groups |
| **digits(integer)** | 1 | Decimal places for rates and confidence intervals (0-10) |
| **eventdigits(integer)** | 0 | Decimal places for event counts (0-10) |
| **pydigits(integer)** | 0 | Decimal places for person-years (0-10) |
| **unitlabel(string)** | 1,000 | Unit label for rate column header (e.g., "Per 1,000 PY (95% CI)") |
| **pyscale(real)** | 1 | Divides person-years values by this factor (must be positive) |
| **ratescale(real)** | 1000 | Multiplies rate and CI values by this factor (must be positive) |

## Examples

### Example 1: Three outcomes, one exposure type

Combine strate output for EDSS 4, EDSS 6, and Relapse outcomes by HRT exposure:

```stata
stratetab, using(edss4_tv edss6_tv relapse_tv) ///
  xlsx(results.xlsx) outcomes(3) ///
  outlabels(Sustained EDSS 4 \ Sustained EDSS 6 \ First Relapse) ///
  explabels(Time-Varying HRT)
```

### Example 2: Three outcomes, four exposure types

Full table with multiple exposure definitions:

```stata
stratetab, using(edss4_tv edss6_tv relapse_tv ///
    edss4_dur edss6_dur relapse_dur ///
    edss4_dur1 edss6_dur1 relapse_dur1 ///
    edss4_dur2 edss6_dur2 relapse_dur2) ///
  xlsx(table2.xlsx) outcomes(3) sheet(Table 2) ///
  title(Table 2. Unadjusted rates of MS outcomes by HRT exposure) ///
  outlabels(Sustained EDSS 4 \ Sustained EDSS 6 \ First Relapse) ///
  explabels(Time-Varying HRT \ HRT Duration \ Estrogen Duration \ Combined Duration)
```

### Example 3: Custom scaling

Display rates per 100 person-years with person-years in 1000s:

```stata
stratetab, using(out1_exp1 out2_exp1 out1_exp2 out2_exp2) ///
  xlsx(results.xlsx) outcomes(2) ///
  ratescale(100) unitlabel(100) pyscale(1000)
```

### Example 4: Two decimal places for rates

```stata
stratetab, using(edss4_tv edss6_tv relapse_tv) ///
  xlsx(results.xlsx) outcomes(3) ///
  outlabels(EDSS 4 \ EDSS 6 \ Relapse) ///
  explabels(Time-Varying HRT) digits(2)
```

## Output Format

The Excel table includes:
- **Title row**: Optional title merged across all columns
- **Outcome headers**: Each outcome label merged across its 3 columns
- **Sub-headers**: Events, Person-Years (PY), and Per [unit] PY (95% CI)
- **Exposure groups**: Header rows for each exposure type
- **Category rows**: Indented rows showing category-specific rates
- **Professional formatting**: Borders, alignment, and appropriate column widths

## Remarks

### File Ordering

Files must be listed with all outcomes for exposure 1 first, then all outcomes for exposure 2, etc. The order of outcomes within each exposure group determines the column order in the output.

For example, with 3 outcomes (O1, O2, O3) and 2 exposures (E1, E2), list files as:
**O1_E1 O2_E1 O3_E1 O1_E2 O2_E2 O3_E2**

### Label Validation

- If `outlabels()` is specified, the number of labels must exactly match `outcomes()`.
- If `explabels()` is specified, the number of labels must match the number of exposure groups (total files / outcomes).

## Requirements

Stata 17.0 or higher

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.2, 2025-12-05

## See Also

- [strate](https://www.stata.com/manuals/ststrate.pdf) - Stata manual entry for strate command
