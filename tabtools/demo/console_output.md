---
title: "console_output"
---

<!-- **# Console: tabtools set/get/list/detail -->

```stata
. tabtools set font Calibri
```

```
tabtools: default font set to Calibri
```

```stata
tabtools set fontsize 11
```

```
tabtools: default font size set to 11
```

```stata
tabtools set borderstyle thin
```

```
tabtools: default border style set to thin
```

```stata
tabtools get
```

```
──────────────────────────────────────────────────
tabtools - Persistent Formatting Defaults
──────────────────────────────────────────────────

  Font:        Calibri
  Font size:   11
  Border:      thin

  Set with: tabtools set font Calibri
            tabtools set fontsize 11
            tabtools set borderstyle thin
            tabtools set theme lancet
            tabtools set digits 3
            tabtools set boldp 0.05
  Clear:    tabtools set clear

```

```stata
tabtools set clear
```

```
tabtools: all persistent defaults cleared
```

```stata
. noisily tabtools
```

```
──────────────────────────────────────────────────────────────────────────
tabtools - Publication-Ready Table Export Suite
──────────────────────────────────────────────────────────────────────────

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

**Styled Export**
  puttab       - Style an in-memory dataset, frame, or matrix as one sheet
  stacktab     - Assemble multi-sheet composite Excel tables from blocks

**General Purpose**
  tabtools     - Suite controller and persistent defaults

──────────────────────────────────────────────────────────────────────────
Total commands: 14

Help:     help tabtools for overview
          help <command> for individual command help
Settings: tabtools set font Calibri (persistent defaults)
          tabtools get (view current defaults)
```

```stata
noisily tabtools, detail
```

```
──────────────────────────────────────────────────────────────────────
tabtools - Publication-Ready Table Export Suite
──────────────────────────────────────────────────────────────────────

**Descriptive Statistics**
  ────────────────────────────────────────────────────────────────────
  table1_tc    Create publication-ready Table 1 with descriptive
               statistics. Automatically selects appropriate
               tests (t-test, Wilcoxon, chi-square, Fisher's
               exact) based on variable type and distribution.
               Supports continuous, categorical, and binary
               variables with customizable formatting.

  desctab      Format an active table collect with per-statistic
               number formats and optional composite cells such
               as events / N (%).

  crosstab     Cross-tabulation with row/column percentages
               and association measures. Supports chi-square,
               Fisher's exact, odds ratios, and risk ratios.

  corrtab      Correlation matrix with significance stars or
               p-values. Supports Pearson and Spearman. Exports
               lower, upper, or full triangle to Excel.

**Model Results**
  ────────────────────────────────────────────────────────────────────
  regtab       Export regression results from any estimation
               command to Excel. Supports logistic, Cox, Poisson,
               linear, and other models. Configurable columns
               for coefficients, confidence intervals, p-values,
               and model statistics.

  effecttab    Export treatment-effect style tables from
               supported estimation results and matrix inputs.
               Formats effect estimates, confidence intervals,
               and p-values for publication output.

**Incidence Rates**
  ────────────────────────────────────────────────────────────────────
  stratetab    Export stratified incidence rates from strate
               command output. Formats person-time, events,
               rates, and confidence intervals. Supports
               rate ratios and stratified analyses.

**Survival Analysis**
  ────────────────────────────────────────────────────────────────────
  survtab      Export Kaplan-Meier estimates, median survival,
               and restricted mean survival time (RMST) to
               Excel. Supports multiple groups and time points.

**Diagnostic Accuracy**
  ────────────────────────────────────────────────────────────────────
  diagtab      Export sensitivity, specificity, PPV, NPV, and
               ROC analysis results. Supports multiple cutpoints
               and diagnostic tests.

**Composite**
  ────────────────────────────────────────────────────────────────────
  comptab      Combine multiple regtab or effecttab frames
               into a single publication-ready table. Supports
               side-by-side and stacked layouts.

  hrcomptab    Build a final Table 2-style sheet by using
               a stratetab frame as the scaffold and injecting
               selected rows from one or more regtab frames.

**Styled Export**
  ────────────────────────────────────────────────────────────────────
  puttab       Style a table already in memory -- the current
               dataset, a named frame, or a Stata matrix
               (e(b), r(table), collapse output) -- as one
               house-styled Excel sheet. Feeds stacktab.

  stacktab     Assemble multi-sheet composite Excel tables from
               source blocks (vstack or hstack), with column
               merges, titles, and notes. Formerly xlsxcompose.

**General Purpose**
  ────────────────────────────────────────────────────────────────────
  tabtools     Suite controller for listing commands and
               managing persistent formatting defaults with
               set and get.

```

```stata
. log off demo
```

```stata
. noisily table1_tc, by(treated)
>     vars(index_age contn %5.1f \ female bin \
>          education cat \ income_quintile cat \
>          born_abroad bin \ civil_status cat \
>          diabetes bin \ hypertension bin \ anxiety bin \ prior_cvd bin)
```

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

```stata
. log off demo
```

```stata
. noisily table1_tc, by(treated)
>     vars(index_age contn %5.1f \ female bin \
>          education cat \ income_quintile cat \
>          born_abroad bin \ diabetes bin \ hypertension bin)
>     nopvalue smd
```

```
  ┌───────────────────────────────────────────────────────────────────────┐
  │                               SSRI            SNRI            SMD     │
  ├───────────────────────────────────────────────────────────────────────┤
  │ No. (Column %) or Mean (SD)   N=8,934         N=6,066                 │
  ├───────────────────────────────────────────────────────────────────────┤
  │ Age at cohort entry (years)   58.3 (13.4)     58.5 (13.3)     0.019   │
  ├───────────────────────────────────────────────────────────────────────┤
  │ Female sex                    5,351 (59.9%)   3,621 (59.7%)   0.004   │
  ├───────────────────────────────────────────────────────────────────────┤
  │ Education level                                               0.043   │
  │    Primary                    2,333 (26.1%)   1,527 (25.2%)           │
  │    Secondary                  3,530 (39.5%)   2,354 (38.8%)           │
  │    Tertiary                   3,071 (34.4%)   2,185 (36.0%)           │
  ├───────────────────────────────────────────────────────────────────────┤
  │ Disposable income quintile                                    0.026   │
  │    1                          1,778 (19.9%)   1,175 (19.4%)           │
  │    2                          1,783 (20.0%)   1,249 (20.6%)           │
  │    3                          1,769 (19.8%)   1,228 (20.2%)           │
  │    4                          1,786 (20.0%)   1,209 (19.9%)           │
  │    5                          1,818 (20.3%)   1,205 (19.9%)           │
  ├───────────────────────────────────────────────────────────────────────┤
  │ Born outside Sweden           1,362 (15.2%)   897 (14.8%)     0.013   │
  ├───────────────────────────────────────────────────────────────────────┤
  │ Diabetes                      4,107 (46.0%)   2,818 (46.5%)   0.010   │
  ├───────────────────────────────────────────────────────────────────────┤
  │ Hypertension                  4,112 (46.0%)   2,935 (48.4%)   0.047   │
  └───────────────────────────────────────────────────────────────────────┘
```

```stata
. log off demo
```

```stata
. noisily desctab, compose(events_n_pct) display pctdigits(1)
```

```
  ┌──────────────────────────────────────────┐
  │ Education level                    Value │
  │         Primary    1,317 / 3,860 (34.1%) │
  │       Secondary    2,077 / 5,884 (35.3%) │
  │        Tertiary    1,855 / 5,256 (35.3%) │
  │           Total   5,249 / 15,000 (35.0%) │
  └──────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily survtab, times(365 730 1095 1460) by(treated)
>     rmst(1460) difference median timeunit(days)
```

```
  ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │                                                         SSRI (N=8934)                SNRI (N=6066)         Difference       p │
  │                       Median survival, d                       5699.0                       5660.0               39.0   0.094 │
  │                                 (95% CI)             (5617.0, 5760.0)             (5574.0, 5729.0)                            │
  │                     Survival probability                                                                                      │
  │                                 365 days                        99.9%                        99.8%    0.1 (-0.1, 0.2)         │
  ├───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │                                 730 days                        99.5%                        99.5%   -0.1 (-0.3, 0.2)         │
  │                                1095 days                        99.0%                        99.1%   -0.1 (-0.4, 0.2)         │
  │                                1460 days                        97.3%                        97.5%   -0.2 (-0.8, 0.3)         │
  │                RMST (1460-d), d (95% CI)   1448.87 (1447.02, 1450.72)   1449.75 (1447.55, 1451.96)              -0.88         │
  │ Log-rank test: chi2(1) = 2.80, p = 0.094                                                                                      │
  └───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily regtab, coef("OR") noint display
```

```
  ┌───────────────────────────────────────────────────────────────────┐
  │                                    Model                          │
  │                                       OR         95% CI   p-value │
  │  Age at cohort entry (years)        1.00   (1.00, 1.00)      0.27 │
  │                   Female sex        0.99   (0.93, 1.06)      0.84 │
  │              Education level                                      │
  ├───────────────────────────────────────────────────────────────────┤
  │                      Primary   Reference                          │
  │                    Secondary        1.02   (0.94, 1.11)      0.66 │
  │                     Tertiary        1.09   (1.00, 1.18)     0.053 │
  │                     Diabetes        1.01   (0.94, 1.08)      0.78 │
  │                 Hypertension        1.10   (1.03, 1.17)     0.005 │
  ├───────────────────────────────────────────────────────────────────┤
  │             Anxiety disorder        1.00   (0.93, 1.08)      0.96 │
  │ Prior cardiovascular disease        0.98   (0.92, 1.05)      0.63 │
  └───────────────────────────────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily regtab, coef("OR") noint compact display
```

```
  ┌────────────────────────────────────────────────────────────┐
  │                                           Model            │
  │                                        OR 95% CI   p-value │
  │  Age at cohort entry (years)   1.00 (1.00, 1.00)      0.27 │
  │                   Female sex   0.99 (0.93, 1.06)      0.84 │
  │              Education level                               │
  ├────────────────────────────────────────────────────────────┤
  │                      Primary           Reference           │
  │                    Secondary   1.02 (0.94, 1.11)      0.66 │
  │                     Tertiary   1.09 (1.00, 1.18)     0.053 │
  │                     Diabetes   1.01 (0.94, 1.08)      0.78 │
  │                 Hypertension   1.10 (1.03, 1.17)     0.005 │
  ├────────────────────────────────────────────────────────────┤
  │             Anxiety disorder   1.00 (0.93, 1.08)      0.96 │
  │ Prior cardiovascular disease   0.98 (0.92, 1.05)      0.63 │
  └────────────────────────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily regtab, coef("OR") noint nopvalue display
```

```
  ┌─────────────────────────────────────────────────────────┐
  │                                    Model                │
  │                                       OR         95% CI │
  │  Age at cohort entry (years)        1.00   (1.00, 1.00) │
  │                   Female sex        0.99   (0.93, 1.06) │
  │              Education level                            │
  ├─────────────────────────────────────────────────────────┤
  │                      Primary   Reference                │
  │                    Secondary        1.02   (0.94, 1.11) │
  │                     Tertiary        1.09   (1.00, 1.18) │
  │                     Diabetes        1.01   (0.94, 1.08) │
  │                 Hypertension        1.10   (1.03, 1.17) │
  ├─────────────────────────────────────────────────────────┤
  │             Anxiety disorder        1.00   (0.93, 1.08) │
  │ Prior cardiovascular disease        0.98   (0.92, 1.05) │
  └─────────────────────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily regtab, display stats(n ll aic bic r2)
```

```
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                                              Model                          │
  │                                                RRR         95% CI   p-value │
  │ Secondary: Age at cohort entry (years)        1.00   (1.00, 1.00)      0.75 │
  │                  Secondary: Female sex        1.08   (1.00, 1.18)     0.063 │
  │                    Secondary: Diabetes        1.01   (0.93, 1.09)      0.86 │
  ├─────────────────────────────────────────────────────────────────────────────┤
  │                Secondary: Hypertension        0.99   (0.91, 1.08)      0.85 │
  │  Tertiary: Age at cohort entry (years)        1.00   (1.00, 1.00)      0.76 │
  │                   Tertiary: Female sex        1.02   (0.93, 1.11)      0.71 │
  │                     Tertiary: Diabetes        1.03   (0.95, 1.12)      0.50 │
  │                 Tertiary: Hypertension        1.00   (0.92, 1.09)      0.98 │
  ├─────────────────────────────────────────────────────────────────────────────┤
  │                           Observations      15,000                          │
  │                                    AIC    32530.06                          │
  │                                    BIC    32606.21                          │
  │                         Log-likelihood   -16255.03                          │
  │                              Pseudo R²       0.000                          │
  └─────────────────────────────────────────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily regtab, display stats(n aic bic ll) models("ZIP" \ "ZINB")
```

```
  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │                                                 ZIP                                  ZINB                            │
  │                                               Coef.           95% CI   p-value      Coef.           95% CI   p-value │
  │                   Event count: Treatment      -0.15   (-0.26, -0.05)     0.003      -0.14   (-0.26, -0.03)     0.016 │
  │                 Event count: Age z-score       0.39     (0.34, 0.44)    <0.001       0.39     (0.33, 0.45)    <0.001 │
  │                      Event count: Female       0.30     (0.19, 0.41)    <0.001       0.32     (0.19, 0.45)    <0.001 │
  ├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │               Inflation equation: Female       0.50     (0.15, 0.84)     0.005       0.72     (0.26, 1.19)     0.002 │
  │ Inflation equation: Structural-zero risk       0.85     (0.66, 1.04)    <0.001       1.07     (0.79, 1.35)    <0.001 │
  │                             Observations      1,500                                 1,500                            │
  │                                      AIC    4338.98                               4307.53                            │
  │                                      BIC    4376.17                               4350.04                            │
  ├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │                           Log-likelihood   -2162.49                              -2145.76                            │
  └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily regtab, display stats(n ll aic bic r2)
```

```
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                                              Model                          │
  │                                              Coef.         95% CI   p-value │
  │             Annual cost: Dose intensity       1.75   (1.49, 2.02)    <0.001 │
  │ Selection equation: Participation score       0.51   (0.43, 0.60)    <0.001 │
  │                            Observations      1,200                          │
  ├─────────────────────────────────────────────────────────────────────────────┤
  │                                     AIC    3425.86                          │
  │                                     BIC    3451.31                          │
  │                          Log-likelihood   -1707.93                          │
  │                               Pseudo R²      0.100                          │
  └─────────────────────────────────────────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily corrtab index_age crp prior_hosp,
>     star(0.05 0.01 0.001) display
```

```
  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │                               Age at cohort entry (years)   C-reactive protein (mg/L)   Prior hospitalizations │
  │ Age at cohort entry (years)                          1.00                                                      │
  │   C-reactive protein (mg/L)                         -0.01                        1.00                          │
  │      Prior hospitalizations                         -0.00                        0.01                     1.00 │
  └────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

* p<.05, ** p<.01, *** p<.001

```

```stata
. log off demo
```

```stata
. noisily crosstab treated female, or label display
```

```
  ┌─────────────────────────────────────────────────────────────────────────────────────────────┐
  │                                    Treatment group            Male          Female    Total │
  │                                               SSRI   3,583 (59.4%)   5,351 (59.6%)    8,934 │
  │                                               SNRI   2,445 (40.6%)   3,621 (40.4%)    6,066 │
  │                                              Total           6,028           8,972   15,000 │
  │ Pearson's chi-squared test: chi2 = 0.06, p = 0.805                                          │
  ├─────────────────────────────────────────────────────────────────────────────────────────────┤
  │                        OR = 1.0 (95% CI: 0.9, 1.1)                                          │
  └─────────────────────────────────────────────────────────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily diagtab phat_display cv_event, cutoff(0.35)
>     auc wilson display
```

```
  ┌────────────────────────────────────────────┐
  │                    Gold +           Gold - │
  │         Test +      2,622            4,497 │
  │         Test -      2,627            5,254 │
  │                                            │
  │        Measure   Estimate         (95% CI) │
  ├────────────────────────────────────────────┤
  │    Sensitivity      50.0%     (48.6, 51.3) │
  │    Specificity      53.9%     (52.9, 54.9) │
  │            PPV      36.8%     (35.7, 38.0) │
  │            NPV      66.7%     (65.6, 67.7) │
  │       Accuracy      52.5%     (51.7, 53.3) │
  ├────────────────────────────────────────────┤
  │            LR+        1.1       (1.0, 1.1) │
  │            LR-       0.93     (0.90, 0.96) │
  │            DOR        1.2       (1.1, 1.2) │
  │            AUC      0.520   (0.510, 0.530) │
  │ Youden's index      0.038                  │
  └────────────────────────────────────────────┘

```

```stata
. log off demo
```

```stata
. noisily puttab term ahr ci using "`_pipe_xlsx'", sheet("Block Primary") varlabels
```

```
puttab: wrote 3 data rows x 3 cols (data source) to sheet Block Primary in /home/tpcopeland/Stata-Tools/tabtools/demo/_pipeline_parts.xlsx
```

```stata
. log off demo
```

```stata
. noisily puttab term ahr ci using "`_pipe_xlsx'", sheet("Block Dose") varlabels
```

```
puttab: wrote 2 data rows x 3 cols (data source) to sheet Block Dose in /home/tpcopeland/Stata-Tools/tabtools/demo/_pipeline_parts.xlsx
```

```stata
. noisily stacktab using "`_pipe_xlsx'", sheet("Composite")
>     blocks(sheet(Block Primary) rows(1/4) cols(A-C) label(Any HRT use) \
>            sheet(Block Dose) rows(1/3) cols(A-C) label(By estrogen dose))
>     columnmerge(B+C as "aHR (95% CI)")
>     spacing(1) display
>     title("Hormone therapy and recurrent events")
>     note("aHR = adjusted hazard ratio; CI = confidence interval.")
```

```

  ┌──────────────────────────────────────┐─────────────
  │           _xcol1              _xcol2 │
  ├──────────────────────────────────────┤─────────────
  │      Any HRT use        aHR (95% CI) │
  │          Any HRT   0.82 (0.69, 0.98) │
  │    Former smoker   1.14 (0.97, 1.34) │
  │   Current smoker   1.46 (1.21, 1.77) │
  │                                      │
  ├──────────────────────────────────────┤─────────────
  │ By estrogen dose          aHR 95% CI │
  │         Low dose   0.91 (0.74, 1.12) │
  │        High dose   0.73 (0.58, 0.92) │
  └──────────────────────────────────────┘─────────────
stacktab: 2 blocks -> 8 rows written -> sheet Composite
```

```stata
. log off demo
```
