# tabtools - Publication-ready Excel tables across common Stata workflows

**Version 1.3.0** | 2026-05-23

`tabtools` is a suite of Stata commands for exporting manuscript-ready tables to Excel across descriptive summaries, regression models, treatment effects, survival analysis, diagnostic accuracy workflows, incidence rates, and composite tables. The package is organized around a shared formatting layer, so commands that come from very different analysis pipelines still produce tables that look like they belong in the same workbook.

## Requirements

- Stata 16 or later for `tabtools` and `table1_tc`
- Stata 17 or later for `desctab`, `regtab`, `effecttab`, `comptab`, `hrcomptab`, `survtab`, `crosstab`, `corrtab`, `diagtab`, and `stratetab`
- `desctab`, `regtab`, and `effecttab` require Stata's `collect` framework
- `survtab` requires `stset` data, and `stratetab` expects saved `strate, output()` datasets

## Installation

```stata
capture ado uninstall tabtools
net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tabtools") replace
```

After installation, start with `help tabtools` for the suite overview, `help tabtools_cheatsheet` for common option patterns, and `help tabtools_cookbook` for longer worked workflows.

## Commands

### Direct table builders

| Command | Description | Stata |
|---------|-------------|-------|
| `table1_tc` | Table 1 generator with automatic tests, SMDs, weighting support, and Excel export | 16+ |
| `desctab` | Format active `table` collections with per-statistic formats and composite cells | 17+ |
| `crosstab` | Cross-tabulation with association measures such as OR, RR, and risk difference | 17+ |
| `corrtab` | Correlation matrix with significance stars, p-values, and lower, upper, or full layouts | 17+ |
| `survtab` | Kaplan-Meier survival summary table with medians, RMST, and number at risk | 17+ |
| `diagtab` | Diagnostic-accuracy table with sensitivity, specificity, predictive values, likelihood ratios, and optional AUC | 17+ |

### Post-estimation formatters

| Command | Description | Stata |
|---------|-------------|-------|
| `regtab` | Format the current `collect` from regression models into a polished table with Excel export and automatic console display | 17+ |
| `effecttab` | Format `teffects` or `margins` results from the current `collect` into an effects table | 17+ |

### File and frame workflow builders

| Command | Description | Stata |
|---------|-------------|-------|
| `stratetab` | Format saved `strate, output()` files into incidence-rate tables | 17+ |
| `comptab` | Combine selected rows from one or more `regtab` or `effecttab` frames into one composite sheet | 17+ |
| `hrcomptab` | Build a final Table 2-style sheet by combining a `stratetab` frame with selected `regtab` rows | 17+ |

### Suite utility

| Command | Description | Stata |
|---------|-------------|-------|
| `tabtools` | Browse commands and manage persistent formatting defaults for the current Stata session | 16+ |

## Choosing a Workflow

| Workflow | Start here | Notes |
|----------|------------|-------|
| Descriptive table from the dataset in memory | `table1_tc`, `crosstab`, `corrtab`, `diagtab` | These commands work directly on the active dataset and do not require `collect` |
| Formatted output from a custom `table` call | `collect: table` then `desctab` | Use when Stata's single `nformat()` is too blunt and each statistic needs its own format |
| Regression or effect estimates after modeling | `collect:` then `regtab` or `effecttab` | These commands format the active collection rather than refitting models |
| Survival summaries from `stset` data | `survtab` | Use when you want Kaplan-Meier estimates, medians, RMST, or risk sets |
| Incidence-rate tables from saved `strate` files | `stratetab` | File-based workflow; no dataset needs to remain in memory |
| Final manuscript table assembled from earlier outputs | `comptab` or `hrcomptab` | These second-stage builders consume frames produced earlier in the pipeline |
| Session-wide formatting defaults | `tabtools` | Use `tabtools set`, `tabtools get`, and `tabtools set clear` to control fonts, borders, themes, and digits |

## Repository Checkout Demo

The rebuild demo is a repository-maintenance workflow, not part of the net install payload. It reads shared `_data/` fixtures and sibling packages from a local Stata-Tools checkout, then regenerates console output and 11 Excel workbooks (55 sheets total) covering every tabtools command.

From a local checkout, run:

```bash
stata-mp -b do tabtools/demo/demo_tabtools.do
```

Installed users should start with `help tabtools`, `help tabtools_cheatsheet`, and `help tabtools_cookbook`; those help files are shipped by `net install`.

### Suite overview

```stata
. tabtools
```

```
──────────────────────────────────────────────────────────────────────
tabtools - Publication-Ready Table Export Suite
──────────────────────────────────────────────────────────────────────

**Descriptive Statistics**
  table1_tc    - Table 1 with automatic statistical tests
  desctab      - Format descriptive table collects
  crosstab     - Cross-tabulation with association measures
  corrtab      - Correlation matrix with significance

**Model Results**
  regtab       - Regression results from any estimation command
  effecttab    - Treatment-effect style tables from supported results

**Incidence Rates**
  stratetab    - Incidence rates from strate output

**Survival Analysis**
  survtab      - Kaplan-Meier estimates, medians, and RMST

**Diagnostic Accuracy**
  diagtab      - Sensitivity, specificity, PPV, NPV, ROC

**Composite**
  comptab      - Combine regtab/effecttab frames into one table
  hrcomptab    - Attach regtab frames to a stratetab scaffold

**General Purpose**
  tabtools     - Suite controller and persistent defaults

──────────────────────────────────────────────────────────────────────
Total commands: 12
```

### table1_tc — Baseline characteristics

```stata
. table1_tc, by(treated) ///
>     vars(index_age contn %5.1f \ female bin \ ///
>          education cat \ income_quintile cat \ ///
>          born_abroad bin \ civil_status cat \ ///
>          diabetes bin \ hypertension bin \ anxiety bin \ prior_cvd bin)
```

<details>
<summary>Console output (click to expand)</summary>

```
  ┌────────────────────────────────────────────────────────────────────────┐
  │                                SSRI            SNRI            p-value │
  ├────────────────────────────────────────────────────────────────────────┤
  │ No. (Column %) or Mean (SD)    N=8,934         N=6,066                 │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Age at cohort entry (years)    58.3 (13.4)     58.5 (13.3)      0.24   │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Female sex                     5,351 (59.9%)   3,621 (59.7%)    0.80   │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Education level                                                 0.11   │
  │    Primary                     2,333 (26.1%)   1,527 (25.2%)           │
  │    Secondary                   3,530 (39.5%)   2,354 (38.8%)           │
  │    Tertiary                    3,071 (34.4%)   2,185 (36.0%)           │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Disposable income quintile                                      0.73   │
  │    1                           1,778 (19.9%)   1,175 (19.4%)           │
  │    2                           1,783 (20.0%)   1,249 (20.6%)           │
  │    3                           1,769 (19.8%)   1,228 (20.2%)           │
  │    4                           1,786 (20.0%)   1,209 (19.9%)           │
  │    5                           1,818 (20.3%)   1,205 (19.9%)           │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Born outside Sweden            1,362 (15.2%)   897 (14.8%)      0.44   │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Marital status                                                  0.34   │
  │    Single                      2,764 (30.9%)   1,804 (29.7%)           │
  │    Married                     3,074 (34.4%)   2,162 (35.6%)           │
  │    Divorced                    1,763 (19.7%)   1,188 (19.6%)           │
  │    Widowed                     1,333 (14.9%)   912 (15.0%)             │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Diabetes                       4,107 (46.0%)   2,818 (46.5%)    0.56   │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Hypertension                   4,112 (46.0%)   2,935 (48.4%)    0.005  │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Anxiety disorder               6,079 (68.0%)   4,148 (68.4%)    0.66   │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Prior cardiovascular disease   5,002 (56.0%)   3,390 (55.9%)    0.90   │
  └────────────────────────────────────────────────────────────────────────┘
```

</details>

### survtab — Kaplan-Meier survival summary

```stata
. survtab, times(365 730 1095 1460) by(treated) ///
>     rmst(1460) difference median timeunit(days)
```

<details>
<summary>Console output (click to expand)</summary>

```
                                          SSRI (N=8934)               SNRI (N=6066)               Difference
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 Median survival, d                       5699.0                      5660.0                      39.0
   (95% CI)                               (5617.0, 5760.0)            (5574.0, 5729.0)
 Survival probability
   365 days                               99.9%                       99.8%                       0.1 (-0.1, 0.2)
   730 days                               99.5%                       99.5%                       -0.1 (-0.3, 0.2)
   1095 days                              99.0%                       99.1%                       -0.1 (-0.4, 0.2)
   1460 days                              97.3%                       97.5%                       -0.2 (-0.8, 0.3)
 RMST (1460-d), d (95% CI)                1448.87 (1447.02, 1450.72)  1449.75 (1447.55, 1451.96)  -0.88
 Log-rank test: chi2(1) = 2.80, p = 0.094
```

</details>

### regtab — Regression table

```stata
. collect clear
. collect: logistic treated index_age female i.education ///
>     diabetes hypertension anxiety prior_cvd
. regtab, coef("OR") noint display
```

```
                              Model
────────────────────────────────────────────────────────────────
                              OR         95% CI        p-value
 Age at cohort entry (years)  1.00       (1.00, 1.00)  0.27
 Female sex                   0.99       (0.93, 1.06)  0.84
 Education level
   Primary                    Reference
   Secondary                  1.02       (0.94, 1.11)  0.66
   Tertiary                   1.09       (1.00, 1.18)  0.053
 Diabetes                     1.01       (0.94, 1.08)  0.78
 Hypertension                 1.10       (1.03, 1.17)  0.005
 Anxiety disorder             1.00       (0.93, 1.08)  0.96
 Prior cardiovascular disease 0.98       (0.92, 1.05)  0.63
```

Compact layout keeps p-values but combines the point estimate and confidence interval:

```stata
. regtab, coef("OR") noint compact display
```

```
                              Model
──────────────────────────────────────────────────────────
                              OR 95% CI          p-value
 Age at cohort entry (years)  1.00 (1.00, 1.00)  0.27
 Female sex                   0.99 (0.93, 1.06)  0.84
 Education level
   Primary                    Reference
   Secondary                  1.02 (0.94, 1.11)  0.66
   Tertiary                   1.09 (1.00, 1.18)  0.053
 Diabetes                     1.01 (0.94, 1.08)  0.78
 Hypertension                 1.10 (1.03, 1.17)  0.005
 Anxiety disorder             1.00 (0.93, 1.08)  0.96
 Prior cardiovascular disease 0.98 (0.92, 1.05)  0.63
```

The `nopvalue` option suppresses p-value columns:

```stata
. regtab, coef("OR") noint nopvalue display
```

```
                              Model
───────────────────────────────────────────────────────
                              OR         95% CI
 Age at cohort entry (years)  1.00       (1.00, 1.00)
 Female sex                   0.99       (0.93, 1.06)
 Education level
   Primary                    Reference
   Secondary                  1.02       (0.94, 1.11)
   Tertiary                   1.09       (1.00, 1.18)
 Diabetes                     1.01       (0.94, 1.08)
 Hypertension                 1.10       (1.03, 1.17)
 Anxiety disorder             1.00       (0.93, 1.08)
 Prior cardiovascular disease 0.98       (0.92, 1.05)
```

### corrtab — Correlation matrix

```stata
. corrtab index_age crp prior_hosp, ///
>     star(0.05 0.01 0.001) display
```

```
                             Age at cohort entry (years)  C-reactive protein (mg/L)  Prior hospitalizations
─────────────────────────────────────────────────────────────────────────────────────────────────────────────
 Age at cohort entry (years) 1.00
 C-reactive protein (mg/L)   -0.01                        1.00
 Prior hospitalizations      -0.00                        0.01                       1.00

* p<.05, ** p<.01, *** p<.001
```

### crosstab — Cross-tabulation

```stata
. crosstab treated female, or label display
```

```
 Treatment group                          Male           Female         Total
────────────────────────────────────────────────────────────────────────────────
 SSRI                                     3,583 (59.4%)  5,351 (59.6%)  8,934
 SNRI                                     2,445 (40.6%)  3,621 (40.4%)  6,066
 Total                                    6,028          8,972          15,000
 Pearson's chi-squared test: chi2 = 0.06, p = 0.805
 OR = 1.0 (95% CI: 0.9, 1.1)
```

### diagtab — Diagnostic accuracy

```stata
. diagtab phat cv_event, cutoff(0.35) auc wilson display
```

```
                Gold +    Gold -
──────────────────────────────────────────
 Test +         2,622     4,497
 Test -         2,627     5,254

 Measure        Estimate  (95% CI)
 Sensitivity    50.0%     (48.6, 51.3)
 Specificity    53.9%     (52.9, 54.9)
 PPV            36.8%     (35.7, 38.0)
 NPV            66.7%     (65.6, 67.7)
 Accuracy       52.5%     (51.7, 53.3)
 LR+            1.1       (1.0, 1.1)
 LR-            0.93      (0.90, 0.96)
 DOR            1.2       (1.1, 1.2)
 AUC            0.520     (0.510, 0.530)
 Youden's index 0.038
```

### Persistent defaults

```stata
. tabtools set font Calibri
tabtools: default font set to Calibri

. tabtools set fontsize 11
tabtools: default font size set to 11

. tabtools set borderstyle thin
tabtools: default border style set to thin

. tabtools get
──────────────────────────────────────────────────
tabtools - Persistent Formatting Defaults
──────────────────────────────────────────────────

  Font:        Calibri
  Font size:   11
  Border:      thin

. tabtools set clear
tabtools: all persistent defaults cleared
```

### Excel workbooks

The demo generates 11 workbooks (55 sheets) covering every command and option combination:

| Workbook | Sheets | Contents |
|----------|--------|----------|
| `demo_table1.xlsx` | 11 | table1_tc variants: basic, total, weighted, wtcompare, SMD, formats, missing, custom symbols, NEJM/BMJ/APA themes |
| `demo_desctab.xlsx` | 6 | desctab: default unshaded exports, explicit shaded styling, events / N (%), mean (SD), median (IQR), separate statistic columns, and custom compose templates |
| `demo_regtab.xlsx` | 13 | regtab: logistic, compact, nopvalue, multi-model, Cox, mixed, CDISC, Poisson, GEE QIC, advanced formatting, keep/drop, addrow |
| `demo_effecttab.xlsx` | 4 | effecttab: ATE (IPW), IPW vs AIPW comparison, margins, average marginal effects |
| `demo_comptab.xlsx` | 5 | comptab: source frames, composite, compact with sections, name-based row selection |
| `demo_survtab.xlsx` | 3 | survtab: KM + median, RMST + difference, cumulative incidence |
| `demo_stratetab.xlsx` | 1 | stratetab: incidence rates with rate ratios by sex |
| `demo_corrtab.xlsx` | 3 | corrtab: Pearson with stars, Spearman with p-values, full matrix |
| `demo_crosstab.xlsx` | 5 | crosstab: OR, RR/RD, styled, trend, row percentages |
| `demo_diagtab.xlsx` | 3 | diagtab: accuracy + AUC, prevalence-adjusted, multiple cutoffs |
| `demo_hrcomptab.xlsx` | 1 | hrcomptab: Table 2-style composite (rates + hazard ratios) |

## Resources

- `help tabtools` for the suite overview and persistent defaults
- `help tabtools_cheatsheet` for compact option patterns across commands
- `help tabtools_cookbook` for longer end-to-end recipes
- `help table1_tc`, `help desctab`, `help regtab`, `help effecttab`, `help comptab`, `help hrcomptab`, `help survtab`, `help stratetab`, `help crosstab`, `help corrtab`, and `help diagtab` for command-specific syntax

## Version History

- **1.3.0** (2026-05-23): Replace final Excel writers with a shared Mata `xl()` backend, add Mata workbook read/write helpers for collect parsing and backend contracts, and remove `export excel`/`import excel` from command implementations.
- **1.2.0** (2026-05-20): Add `regtab, nopvalue` to suppress p-value columns from console, frame, CSV, and Excel outputs while preserving internal p-values for significance stars and row highlighting.
- **1.1.0** (2026-05-13): Add `desctab`, a formatter for active `table` collections with per-statistic number formats, `events / N (%)` and other composite cells, Excel/CSV/frame/display outputs, and shared tabtools styling defaults.
- **1.0.15** (2026-05-07): Fix `regtab` ICC cross-pollution where a multi-model collection ending in `mepoisson`/`menbreg` silently suppressed ICC for all earlier mixed-effects models (now skipped per-model). Strip thousands separators from coefficient and CI cells so `digits()`, `stars`, `boldp`, `dimnonsig`, and `r(table)` work for coefficients ≥ 1000. Make reference-category detection match the underlying numeric value (0 or 1 with empty CI) instead of the rendered string, so non-default precision still labels rows "Reference". Emit a noisily warning when the per-model stats fallback fires for a multi-model collection. Document `table1_tc` reserved `by()` variable name prefixes (`N_`, `m_`, `_c…`). Plug a Mata workspace leak in `table1_tc` Excel error path. Use a tempname instead of the literal `beatles` value-label fallback. Replace ad-hoc `…2` suffix scratch columns in `headerperc` with tempvars to avoid name collisions. Move integer check before `recast long, force` to prevent silent truncation. Sthlp `boldp` colon-position fix.
- **1.0.14** (2026-05-05): Add QIC (Quasi-likelihood Information Criterion) support to `regtab` for GEE models. When `stats(aic)` is requested after `xtgee`, QIC is automatically computed and displayed since AIC is undefined for quasi-likelihood estimators. QIC can also be requested explicitly via `stats(qic)`.
- **1.0.13** (2026-04-27): Documentation improvements across all .sthlp files and README. Enhanced corrtab, survtab, and diagtab help files with richer descriptions, additional examples, and "Also see" sections. Standardized author blocks with mailto links. Added `{vieweralsosee}` links to the cheatsheet.
- **1.0.12** (2026-04-27): Fix `crosstab, or rr rd` for 2x2 variables coded with nonzero category values by internally recoding observed levels to 0/1 before calling Stata's `cc`/`cs`; reject undefined requested association measures instead of silently omitting them; and validate `table1_tc` `wt()` and numeric `by()` values within the analysis sample so excluded rows do not trigger false hard failures.
- **1.0.11** (2026-04-26): Fix `table1_tc, wt() smd` weighted SMD calculations for continuous, categorical, and binary variables; fix `headerperc` with `total(before|after)`; and document active `collect` side effects for `regtab` and `effecttab`.
- **1.0.10** (2026-04-26): Fix weighted `crosstab, trend`, enforce unique truncated `stratetab` matrix row names, hard-fail missing final `effecttab` workbooks, reject binary `diagtab, optimal`, add `corrtab` shape conflict checks, clarify cookbook runnable versus illustrative recipes, and strengthen QA/install isolation.
- **1.0.9** (2026-04-23): Fix `regtab` exporting a spurious blank trailing column. The `_re_group_label` internal variable was not being dropped before export because it was bundled in a `capture drop` with `_ci_seen`, which only exists under `dimnonsig`.
- **1.0.8** (2026-04-22): Clarity audit release with hardened export-return behavior, synchronized package metadata, and expanded QA around release gates and export failures.
- **1.0.7** (2026-04-18): Stata-Tools suite release covering direct descriptive tables, `collect`-based model formatters, file-based rate workflows, and frame-based composite builders.
- **1.0.6** (2026-04-17): Incremental refinement release during the Stata-Tools packaging cycle.
- **1.0.5** (2026-04-17): Incremental refinement release during the Stata-Tools packaging cycle.
- **1.0.4** (2026-04-16): Early public packaging milestone for the tabtools suite.

## Author

Timothy P Copeland, Karolinska Institutet
