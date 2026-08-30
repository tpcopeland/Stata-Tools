# comorbidity — Charlson and Elixhauser scores from ICD-10 fields

**Version 1.0.1**

`comorbidity` scans wide-format ICD-10 diagnosis fields and creates patient-level Charlson, Elixhauser, or custom weighted scores. It is for analysts who need to turn one or more diagnosis variables per encounter into condition indicators and a reproducible comorbidity score.

## Quick Start

After installation, scan diagnosis fields and collapse to one row per patient:

```stata
clear
input long pid str6 dx1 str6 dx2
1 "I21" "I50"
1 "E119" ""
2 "C780" ""
end

comorbidity dx1 dx2, id(pid) charlson(original)
list pid charlson mi chf dm_uncomp metastatic
```

The default output is collapsed by `id()`. In this example, patient 1 has score 3 and patient 2 has score 6.

## Requirements

- Stata 16 or later
- The [`codescan`](https://github.com/tpcopeland/Stata-Tools/tree/main/codescan) dependency
- One or more wide-format diagnosis variables and an identifier for the patient or analytic unit

## Installation

Install the scanner dependency first:

```stata
net install codescan, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/codescan") replace
```

Then install `comorbidity`:

```stata
capture ado uninstall comorbidity
net install comorbidity, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/comorbidity") replace
```

## Commands

| Command | Description |
|---|---|
| `comorbidity` | Scan wide-format ICD-10 fields, apply optional hierarchy rules, and compute a Charlson, Elixhauser, or custom weighted score |

## How It Works

`comorbidity` passes the diagnosis variables to `codescan` with a built-in or user-supplied code dictionary, then applies the selected weights to the resulting binary condition indicators.

- `charlson(original)` and `charlson(quan2011)` use the Quan et al. (2005) Charlson ICD-10 definitions with the corresponding weight scheme.
- `elixhauser(vanwalraven)` uses the Quan et al. (2005) Elixhauser ICD-10 definitions and van Walraven weights.
- `custom(filename)` reads condition names, ICD-10 patterns, and weights from a `.csv` or `.dta` code file.
- `collapse` produces one row per `id()` and is the default when neither `collapse` nor `merge` is specified; `merge` returns patient-level indicators and the score on the encounter rows.
- Built-in Charlson and Elixhauser indexes use hierarchy rules by default. Use `nohierarchy` when you need the unadjusted indicators; custom indexes do not apply a built-in hierarchy.

## Worked Examples

### 1. Charlson scores and score bands

`band` adds patient-level counts and percentages for negative scores, 0, greater than 0 to less than 3, 3 to less than 5, and 5 or greater to `r(bands)`. These bands are exhaustive for integer and fractional scores. The nonnegative cutpoints reproduce Charlson et al. (1987); for Elixhauser and custom scores they are descriptive categories rather than validated risk strata.

```stata
clear
input long pid str6 dx1 str6 dx2
1 "I21" "I50"
1 "E119" ""
2 "C780" ""
3 "" ""
end

comorbidity dx1 dx2, id(pid) charlson(original) band
list pid charlson mi chf dm_uncomp metastatic, noobs
matrix list r(bands)
```

### 2. Merge a generated score back to encounter rows

Use `generate()` to prefix the component indicators and score variable. `replace` permits the example to overwrite the placeholder score variable.

```stata
clear
input long pid str6 dx1 str6 dx2
1 "I21" "I50"
1 "E119" ""
2 "C780" ""
end
gen double cmb_score = -99

comorbidity dx1 dx2, id(pid) charlson(quan2011) merge generate(cmb_) replace
list pid dx1 dx2 cmb_score cmb_mi cmb_chf cmb_dm_uncomp cmb_metastatic, noobs
```

### 3. Elixhauser van Walraven scoring

The van Walraven score can be negative because its published weight vector includes negative weights.

```stata
clear
input long pid str6 dx1 str6 dx2 str6 dx3
1 "I50" "C780" "F11"
2 "E66" "F32" ""
3 "I10" "I11" "E112"
end

comorbidity dx1 dx2 dx3, id(pid) elixhauser(vanwalraven) generate(elx_) replace band
list pid elx_score elx_chf elx_metastatic elx_drug elx_obesity elx_depression, noobs
matrix list r(bands)
```

### 4. Restrict matching to a date window

Supply encounter and reference dates with `date()` and `refdate()`, then set the lookback and lookforward windows in days.

```stata
clear
input long pid str6 dx1 int dxdate int refdate
1 "I50" 21910 21915
1 "I21" 21885 21915
2 "I50" 21550 21915
end
format dxdate refdate %td

comorbidity dx1, id(pid) charlson(original) date(dxdate) refdate(refdate) lookback(30) lookforward(10) inclusive
list pid charlson mi chf, noobs
```

### 5. Use a custom weighted code file

The custom file must contain `name`, `pattern`, and `weight` columns. Each detected condition must have exactly one matching weight.

```stata
clear
input long pid str6 dx1 str6 dx2
1 "I21" "I50"
2 "E119" ""
end

tempfile custom_codes
preserve
clear
input str12 name str20 pattern double weight
"mi" "I21|I22" 10
"chf" "I50" 2
"dm" "E11" 4
end
save "`custom_codes'.dta", replace
restore

comorbidity dx1 dx2, id(pid) custom("`custom_codes'.dta") replace
list pid custom mi chf dm, noobs
```

## Demo

The repository demo exercises the built-in indexes, merge and collapse output, generated names, date windows, hierarchy control, custom weights, and verbose scanning. From the repository root, run:

```bash
stata-mp -b do comorbidity/demo/demo_comorbidity.do
```

The checked-in console transcript is [`demo/console_output.md`](demo/console_output.md).

## Command Reference

```stata
comorbidity varlist [if] [in], id(varname) charlson(scheme) [options]
comorbidity varlist [if] [in], id(varname) elixhauser(scheme) [options]
comorbidity varlist [if] [in], id(varname) custom(filename) [options]
```

Exactly one of `charlson()`, `elixhauser()`, or `custom()` is required. `collapse` and `merge` are mutually exclusive, and `collapse` is selected automatically when neither is specified.

## Key Options

| Option | Use |
|---|---|
| `id(varname)` | Required patient or analytic-unit identifier |
| `charlson(scheme)` | Choose `original` or `quan2011` Charlson weights |
| `elixhauser(scheme)` | Choose implemented `vanwalraven` weights; AHRQ scheme names are reserved and exit with error code `r(198)` in this build |
| `custom(filename)` | Read a `.csv` or `.dta` code file containing `name`, `pattern`, and `weight` |
| `collapse` | Return one row per `id()`; default output shape |
| `merge` | Merge patient-level indicators and the score back to encounter rows |
| `date(varname)` | Encounter date variable passed to `codescan` |
| `refdate(varname)` | Reference date variable passed to `codescan` |
| `lookback(#)` | Pass a nonnegative lookback window in days; default `-1` passes no lower bound |
| `lookforward(#)` | Pass a nonnegative lookforward window in days; default `-1` passes no upper bound |
| `inclusive` | Include the reference date in the date window |
| `generate(prefix)` | Prefix condition indicators and name the score `prefixscore` |
| `replace` | Overwrite existing nonstructural condition and score variables; identifiers, diagnosis fields, and date inputs remain protected |
| `nohierarchy` | Skip built-in hierarchy rules for a Charlson or Elixhauser run |
| `band` | Return exhaustive patient-level score-band counts and percentages in `r(bands)` |
| `noisily` | Pass verbose progress output through to `codescan` |

## Stored Results

After a successful run, `comorbidity` stores:

| Result | Type | Meaning |
|---|---|---|
| `r(index)` | Local macro | Resolved index: `charlson`, `elixhauser`, or `custom` |
| `r(scheme)` | Local macro | Resolved weighting scheme |
| `r(scorevar)` | Local macro | Generated score variable name |
| `r(conditions)` | Local macro | Condition indicator variables in score order |
| `r(N)` | Scalar | Patient-level count reported by `codescan` |
| `r(hierarchy)` | Scalar | 1 when a built-in hierarchy was applied, otherwise 0 |
| `r(weights)` | Matrix | Per-condition weights in score order |
| `r(summary)` | Matrix | Post-hierarchy patient counts, prevalence, missing binary-mode hit totals, and positive units |
| `r(bands)` | Matrix | Patient-level score-band counts and percentages when `band` is specified |

## Assumptions and Limits

- The input diagnosis fields are wide-format variables containing ICD-10 codes that can be matched by `codescan`.
- The package-defined Charlson hierarchy supersedes uncomplicated diabetes with complicated diabetes, mild liver disease with severe liver disease, and any malignancy with metastatic cancer.
- The package-defined Elixhauser hierarchy supersedes uncomplicated hypertension with complicated hypertension, solid tumor without metastasis with metastatic cancer, and uncomplicated diabetes with complicated diabetes. These hierarchy rules are package conventions rather than rules established by the cited scoring papers.
- The Quan ICD-10 Charlson dictionary combines solid tumors, leukemia, and lymphoma into one `cancer` indicator. `charlson(original)` therefore reproduces Charlson's weights but cannot separately add those three original conditions when more than one is present.
- The `quan2011` weight vector is cross-validated against R `comorbidity` 1.1.0. That parity check is not an independent audit of the primary paper's exact condition-level weight table.
- `elixhauser(ahrq_mortality)` and `elixhauser(ahrq_readmission)` are reserved but not implemented in this release and exit with error code `r(198)`.
- Custom code files are limited to `.csv` and `.dta` extensions and must provide one nonmissing numeric weight per unique condition name. The schema, output names, and aggregate numeric range of the weights are checked before diagnosis scanning begins.
- `replace` cannot overwrite `id()`, diagnosis variables, `date()`, or `refdate()` through either the score name or a custom condition name.

## References

- Charlson ME, Pompei P, Ales KL, MacKenzie CR. A new method of classifying prognostic comorbidity in longitudinal studies: development and validation. *J Chronic Dis.* 1987;40(5):373–383. [doi:10.1016/0021-9681(87)90171-8](https://doi.org/10.1016/0021-9681(87)90171-8)
- Quan H, Sundararajan V, Halfon P, et al. Coding algorithms for defining comorbidities in ICD-9-CM and ICD-10 administrative data. *Med Care.* 2005;43(11):1130–1139. [doi:10.1097/01.mlr.0000182534.19832.83](https://doi.org/10.1097/01.mlr.0000182534.19832.83)
- Quan H, Li B, Couris CM, et al. Updating and validating the Charlson comorbidity index and score for risk adjustment in hospital discharge abstracts using data from 6 countries. *Am J Epidemiol.* 2011;173(6):676–682. [doi:10.1093/aje/kwq433](https://doi.org/10.1093/aje/kwq433)
- van Walraven C, Austin PC, Jennings A, Quan H, Forster AJ. A modification of the Elixhauser comorbidity measures into a point system for hospital death using administrative data. *Med Care.* 2009;47(6):626–633. [doi:10.1097/MLR.0b013e31819432e5](https://doi.org/10.1097/MLR.0b013e31819432e5)

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.0.1**: Prevent custom-weight overflow from changing caller data; strengthen method caveats, released-package wording, and QA oracles
- **1.0.0**: Initial release with Charlson original, Charlson Quan 2011, Elixhauser van Walraven, custom weighted code files, and hierarchy handling

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License
