# psdash — Propensity Score Diagnostics Dashboard

**Version 1.0.1** | 2026-05-06

Unified diagnostics dashboard for propensity score analyses in Stata. After `teffects`, after `logit`/`probit` with manually supplied propensity scores from `predict`, or in fully manual mode, `psdash` assesses the four standard PS diagnostic domains through one command family: overlap between treatment groups (`psdash overlap`), covariate balance before and after weighting (`psdash balance`), weight distribution and effective sample size (`psdash weights`), and common-support regions (`psdash support`). `psdash combined` runs all four and produces a consolidated dashboard.

This package exists because PS diagnostics in Stata are scattered across `tebalance`, user-written helpers, and ad-hoc `summarize`/`tabstat` calls, with each step requiring the analyst to re-specify the treatment variable, covariate list, PS variable, and weighting scheme. `psdash` collapses that friction: when called after `teffects`, it reads treatment, covariates, propensity scores, and the implied weighting scheme (ATE/ATT/ATC) directly from `e()`. After `logit`/`probit` it still pulls treatment and covariates from the estimation context. In fully manual mode, treatment and PS are passed explicitly; `covariates()` and `wvar()` are supplied to the subcommands that use those inputs. Auto-generated propensity scores and IPTW weights are created as temporary working variables and are not left behind in the user's dataset.

Balance reporting is deliberately richer than the `tebalance summarize` default. `psdash balance` computes raw and weighted standardized mean differences, variance ratios, Kolmogorov-Smirnov statistics, and a Love plot sorted by absolute SMD, with configurable thresholds and Excel export. When a PS is available, it auto-generates IPTW weights for the requested `estimand()` (default ATE) and displays adjusted columns alongside raw columns, so the user sees immediately how much weighting resolves any imbalance — with `nowvar` to suppress weighting and `wvar()` to supply a pre-computed weight variable. Factor and interaction notation (`i.var`, `c.var`, `##`) is expanded transparently when balance is auto-detected from a fitted `logit`/`probit`/`teffects` model.

The weights subcommand is the complement. `psdash weights` reports mean, SD, range, percentiles, effective sample size, and extreme-weight counts, with on-the-fly `trim(#)`, `truncate(#)`, and `stabilize` modifications exposed through `generate(name)` so the modified weights are kept as a new variable rather than overwriting the original. `psdash support` assesses common-support regions via manual PS thresholds or the Crump et al. (2009) optimal-trimming rule and can write an `in_support` indicator for downstream analyses. All subcommands store results in `r()` and the dashboard output lines use clear status labels plus a "Consider:" action line when follow-up is warranted.

## Installation

```stata
* Released version from GitHub:
capture ado uninstall psdash
net install psdash, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") replace

* Development install from a local checkout:
capture ado uninstall psdash
net install psdash, from("/path/to/psdash") replace
```

## How It Works

`psdash` is designed to work in four modes:

- **After `teffects`**: treatment, covariates, propensity scores, and the implied weighting scheme are auto-detected from `e()`. This is the shortest workflow: fit `teffects`, then run `psdash combined` or one of the individual subcommands.
- **After `logit`/`probit`**: treatment and covariates are read from the estimation context, but you still supply the PS variable created by `predict`.
- **After `mlogit` (multi-group)**: for multi-valued treatments, treatment and covariates are auto-detected from `e()`. Run `predict ps1 ps2 ps3, pr` and pass the GPS variables via `psvars(ps1 ps2 ps3)`.
- **Manual mode**: provide treatment and PS explicitly, then pass `covariates()` to balance/combined and `wvar()` to balance/weights/combined when you want to override auto-detection.

When a PS variable is available, `psdash balance` auto-generates IPTW weights for the requested `estimand()` unless you suppress that with `nowvar` or provide `wvar()` yourself.
Auto-generated propensity scores and weights are temporary working variables and are not left behind in the user's dataset.

## What Should I Run?

Most users can start with `psdash combined`. It runs the four diagnostic panels together and prints an overall status line. If one panel raises a caution, rerun that subcommand by itself to inspect the graph, export a table, or create a modified weight/support variable.

| Question | Command | What to look for |
|----------|---------|------------------|
| Do treated and control observations have comparable propensity scores? | `psdash overlap` | Large percentages outside common support, very high AUC, PS values near 0 or 1 |
| Are the covariates balanced after adjustment? | `psdash balance` | Maximum absolute SMD above `threshold()`; variance ratios outside 0.5 to 2.0; large KS statistics |
| Are a few observations dominating the weighted analysis? | `psdash weights` | Low ESS, high coefficient of variation, weights above 10 or 20 |
| Which observations are inside the usable support region? | `psdash support` | Number outside empirical common support and number trimmed by `crump` or `threshold()` |
| Do I need the full dashboard in one step? | `psdash combined` | Overall PASS/CAUTION plus the panel named in the warning |

## Reading the Output

`psdash` uses the same diagnostics that are common in propensity-score reporting, but it labels the output so a non-specialist can follow the next action:

- **Overlap/support warnings** mean the treatment groups do not share enough comparable observations in part of the propensity-score range. Consider trimming, narrowing the study population, changing the estimand, or revisiting the PS model.
- **Balance warnings** mean one or more observed covariates still differ after adjustment. Consider model revisions, additional covariates or interactions, a different weighting scheme, or reporting the residual imbalance explicitly.
- **Weight warnings** mean the estimated effect may be sensitive to a small number of observations. Consider stabilized weights, percentile trimming, truncation, or an estimand with better support.
- **A PASS or Adequate label is not a causal proof.** It means these observed-diagnostic thresholds were not crossed. Outcome-model assumptions, unmeasured confounding, missing data, and study design still need separate judgment.

## Worked Examples

Most examples below use Stata's built-in `sysuse` or `webuse` datasets, so they can be copied directly after installation. The `sysuse auto` examples use `foreign` as a convenient binary treatment indicator. The `webuse cattaneo2` examples show a more realistic treatment-effects workflow. The multi-group example generates a small simulated dataset so the multinomial treatment model has stable support. These examples are intended to illustrate syntax and diagnostics, not to endorse a final causal specification.

### 1. Manual propensity-score workflow with `sysuse auto`

Estimate the propensity score with `logit`, save fitted probabilities in `ps`, then run each diagnostic explicitly. Because this is a manual workflow, `balance` is told which covariates to assess.

```stata
sysuse auto, clear
logit foreign mpg weight length
predict double ps, pr
psdash overlap foreign ps
psdash balance foreign ps, covariates(mpg weight length) loveplot
psdash weights foreign ps
psdash support foreign ps, crump generate(in_support)
```

After `logit` or `probit`, the treatment and covariates are still available in `e()`, so the same workflow can be written more compactly:

```stata
psdash overlap ps
psdash balance ps, loveplot
psdash weights ps
```

### 2. Fully automatic workflow after `teffects` with `webuse cattaneo2`

Here `teffects ipw` estimates the propensity score internally. After that, `psdash` reads the treatment (`mbsmoke`), the estimated PS, the covariates, and the implied weighting scheme from `e()`, so the subcommands can be called without retyping variable names.

```stata
webuse cattaneo2, clear
teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby)
psdash combined
psdash balance
```

### 3. Using pre-computed weights with `sysuse auto`

If weights were created outside `psdash`, pass them through `wvar()` so that the weight and balance diagnostics use the same variable.

```stata
sysuse auto, clear
logit foreign mpg weight length
predict double ps, pr
gen double ipw = cond(foreign == 1, 1/ps, 1/(1-ps))
psdash weights foreign ps, wvar(ipw) detail graph
psdash balance foreign ps, covariates(mpg weight length) wvar(ipw)
```

### 4. ATT workflow after `teffects, atet`

When `teffects` is fit with `, atet`, `psdash` maps Stata's ATET result to `estimand(att)` internally. That lets the balance and weight diagnostics use ATT weights automatically.

```stata
webuse cattaneo2, clear
teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), atet
psdash balance
psdash weights, detail
```

### 5. Focused option examples on `sysuse auto`

These examples show common follow-up diagnostics once `ps` already exists: add KS statistics to the balance table, create trimmed or stabilized weights, and mark observations inside common support.

```stata
sysuse auto, clear
logit foreign mpg weight length
predict double ps, pr
psdash balance foreign ps, covariates(mpg weight length) ks
psdash weights foreign ps, trim(99) generate(ipw_trimmed)
psdash weights foreign ps, stabilize generate(ipw_stab)
psdash support foreign ps, crump generate(in_support)
```

### 6. Multi-group treatment with `mlogit`

When the treatment has more than two levels, estimate generalized propensity scores and pass the K predicted probabilities through `psvars()`.

```stata
clear
set obs 300
set seed 20260506
gen double age = rnormal(60, 10)
gen byte female = runiform() > .5
gen double bmi = rnormal(27, 4)
gen double eta1 = -0.2 + 0.03*(age-60) + 0.25*female - 0.04*(bmi-27)
gen double eta2 = 0.1 - 0.02*(age-60) + 0.02*(bmi-27)
gen double den = 1 + exp(eta1) + exp(eta2)
gen double p0 = 1/den
gen double p1 = exp(eta1)/den
gen double u = runiform()
gen byte arm = cond(u < p0, 0, cond(u < p0 + p1, 1, 2))

mlogit arm age female bmi
predict double ps0 ps1 ps2, pr
psdash overlap arm, psvars(ps0 ps1 ps2)
psdash balance arm, psvars(ps0 ps1 ps2) covariates(age female bmi)
psdash weights arm, psvars(ps0 ps1 ps2) detail
psdash support arm, psvars(ps0 ps1 ps2) threshold(0.1)
psdash balance arm, psvars(ps0 ps1 ps2) covariates(age female bmi) reference(1)
```

## Subcommands

| Subcommand | Purpose |
|------------|---------|
| `overlap` | PS density/histogram by treatment group |
| `balance` | SMD balance table + Love plot |
| `weights` | Weight distribution, ESS, extreme weights, trim/stabilize |
| `support` | Common support assessment, Crump optimal trimming |
| `combined` | All diagnostics in a combined dashboard |

## Key Options

### Common and multi-group options
- `estimand(ate|att|atc)` - target estimand for generated weights. Default is `ate`; after `teffects`, the value is read from `e(stat)` unless supplied explicitly.
- `psvars(varlist)` - generalized propensity scores for multi-group treatments. Provide one probability variable per treatment level, ordered by ascending treatment value.
- `reference(#)` - reference treatment level for pairwise multi-group balance and weight summaries. Default is the smallest observed treatment level.
- `saving(filename)` - save the graph produced by the relevant subcommand. For `combined`, this saves the combined dashboard graph.
- `scheme(schemename)`, `title(string)`, `name(string)`, `graphoptions(string)` - graph styling options where supported by the subcommand.

### overlap
- `histogram` - use overlapping histograms instead of kernel density plots
- `bins(#)` - histogram bins; default is 30
- `bwidth(#)` - kernel density bandwidth; Stata's default is used when omitted
- `nograph` - show the overlap table without drawing a graph

### balance
- `covariates(varlist)` — covariates to assess (auto-detected if omitted)
- `wvar(varname)` — weight variable (auto-generated from PS if omitted)

> **Default behavior:** When a PS is supplied, `balance` auto-generates IPTW weights for the requested `estimand()` (default: ATE) and displays *adjusted* SMD/VR columns alongside the raw columns. Pass `nowvar` to see raw balance only, or `wvar()` to supply a pre-computed weight variable.
- `matched` - report matched/unweighted balance; mutually exclusive with `wvar()`
- `nowvar` - suppress automatic weight generation and show raw balance only
- `loveplot` — generate Love plot
- `threshold(#)` — SMD threshold (default: 0.1)
- `ks` - display Kolmogorov-Smirnov statistics; KS values are stored either way
- `xlsx(filename)` — export to Excel
- `sheet(string)` - Excel sheet name; default is `"Balance"`
- `format(string)` - numeric display format for SMD values; default is `%6.3f`

### weights
- `wvar(varname)` — weight variable (auto-generated from PS if omitted)
- `trim(#)` — trim at percentile (50–99.9)
- `truncate(#)` — cap at fixed value
- `stabilize` — create stabilized weights
- `generate(name)` — variable for modified weights
- `replace` - allow `generate()` to replace an existing variable
- `detail` — show percentile distribution
- `graph` — weight distribution histogram
- `xlabel(numlist)` - custom x-axis labels for the histogram

### support
- `crump` — Crump et al. (2009) optimal trimming
- `threshold(#)` — manual PS trimming threshold (0–0.5)
- `generate(name)` — create an in-support indicator. With `crump` or `threshold()`, this marks the trimmed region; otherwise it marks the empirical common-support interval.
- `replace` - allow `generate()` to replace an existing variable
- `nograph` - show the support table without drawing a graph

### combined
- `nooverlap`, `nobalance`, `noweights`, `nosupport` — suppress panels

## Stored Results

Each subcommand stores results in `r()`. Technical users can use these values in QA checks, automated reports, or decision rules.

| Subcommand | Key scalars/macros | Matrix |
|------------|--------------------|--------|
| `overlap` | `r(N)`, `r(overlap_lower)`, `r(overlap_upper)`, `r(n_outside)`, `r(pct_outside)`, `r(auc)`, `r(treatment)`, `r(psvar)` | none |
| `balance` | `r(max_smd_raw)`, `r(max_smd_adj)`, `r(max_vr_raw)`, `r(max_vr_adj)`, `r(max_ks_raw)`, `r(n_imbalanced)`, `r(threshold)`, `r(wvar)` | `r(balance)` |
| `weights` | `r(mean_wt)`, `r(sd_wt)`, `r(cv)`, `r(ess)`, `r(ess_pct)`, `r(n_extreme)`, `r(p1)`, `r(p99)`, `r(generate)` | none |
| `support` | `r(lower_bound)`, `r(upper_bound)`, `r(n_outside)`, `r(pct_outside)`, `r(trim_lower)`, `r(trim_upper)`, `r(n_trimmed)`, `r(crump_alpha)` | none |
| `combined` | Inherits subcommand results via `return add`; also stores `r(treatment)`, `r(psvar)`, `r(estimand)`, `r(source)`, and for multi-group runs `r(K)`, `r(levels)`, `r(reference)` | inherited when balance runs |

For binary treatments, `r(balance)` has one row per covariate and columns for raw and adjusted means, SMDs, variance ratios, and KS statistics. For multi-group treatments, `r(balance)` has one five-column block per non-reference group, plus adjusted blocks when weights are applied; column names include the compared treatment levels.

Example:

```stata
psdash balance foreign ps, covariates(mpg weight length)
return list
matrix list r(balance)
* Example decision rule for your own analysis:
* assert r(max_smd_adj) < 0.1
```

## Relationship to Existing Packages

`psdash balance` incorporates the computation from [`balancetab`](../balancetab/) and `psdash weights` from [`iptw_diag`](../iptw_diag/). Both use identical methods. The `overlap` and `support` subcommands are new.

## Demo

### Binary treatment (2 groups)

Synthetic data: 800 observations, confounded treatment assignment (statin use), propensity scores via logit, IPTW weights.

<details>
<summary>Overlap diagnostics (click to expand)</summary>

```stata
. noisily psdash overlap statin ps, nograph
```

```
----------------------------------------------------------------------
Propensity Score Overlap
----------------------------------------------------------------------
Treatment:         statin
PS variable:       ps
----------------------------------------------------------------------

----------------------------------------------------------------------
Propensity Score Distribution
----------------------------------------------------------------------
                            Treated        Control
----------------------------------------------------------------------
                   N            551            249
                Mean         0.7191         0.6217
                  SD         0.1325         0.1486
                 Min         0.3136         0.1853
                 Max         0.9505         0.9206
----------------------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.3136
Upper bound:               0.9206
Outside support:               17 ( 2.12%)
  Treated outside:             12
  Control outside:              5
C-statistic (AUC):         0.6881
-------------------------------------------------------

Overlap: Good ( 2.1% outside support)
```

</details>

![PS overlap density](demo/overlap_density.png)

<details>
<summary>Balance and weight diagnostics (click to expand)</summary>

```stata
. noisily psdash balance statin ps,
>     covariates(age female bmi sbp cholesterol) wvar(ipw)
```

```
---------------------------------------------------------------------------
Covariate Balance Assessment
---------------------------------------------------------------------------
Treatment:     statin
Estimand:      ATE
N (treated):          551
N (control):          249
Weights:       ipw
Threshold:      0.100
---------------------------------------------------------------------------


---------------------------------------------------------------------------------------
           Covariate |  SMD Raw  VR Raw  SMD Adj  VR Adj      Status
---------------------------------------------------------------------------------------
                 age | 0.472  0.99 0.013  1.01    Balanced
              female | 0.430  1.03 0.001  1.00    Balanced
                 bmi | 0.156  1.02 0.014  1.07    Balanced
                 sbp | 0.194  1.01 0.018  1.05    Balanced
         cholesterol | 0.039  1.04 0.047  0.99    Balanced
---------------------------------------------------------------------------------------


Maximum |SMD| (raw):       0.472
Maximum |SMD| (adjusted):  0.047
Maximum VR (raw):           1.04
Maximum VR (adjusted):      1.07
Covariates > SMD threshold:    0 of   5
---------------------------------------------------------------------------------------

Balance: Adequate (max |SMD| =  0.047)
```

```stata
. noisily psdash weights statin ps, wvar(ipw)
```

```
----------------------------------------------------------------------
IPTW Weight Diagnostics
----------------------------------------------------------------------
Weight variable:   ipw
Treatment:         statin
Observations:             800
----------------------------------------------------------------------

----------------------------------------------------------------------
Weight Distribution Summary
----------------------------------------------------------------------
                                 Overall        Treated        Control
----------------------------------------------------------------------
                        N            800            551            249
                     Mean          1.996          1.450          3.206
                       SD          1.271          0.334          1.682
                      Min          1.052          1.052          1.227
                      Max         12.602          3.188         12.602
----------------------------------------------------------------------

----------------------------------------------------------------------
Effective Sample Size (ESS)
----------------------------------------------------------------------
                                 Overall        Treated        Control
----------------------------------------------------------------------
                      ESS          569.4          523.2          195.4
               ESS % of N          71.2%          95.0%          78.5%
----------------------------------------------------------------------

--------------------------------------------------
Extreme Weight Detection
--------------------------------------------------
Coefficient of Variation:    0.637
Weights > 10:                    3 ( 0.38%)
Weights > 20:                    0
--------------------------------------------------

Warning: 3 extreme weights detected (>10).

Weights: Acceptable (ESS = 71.2% of N)
```

</details>

![Love plot](demo/love_plot.png)

<details>
<summary>Common support assessment (click to expand)</summary>

```stata
. noisily psdash support statin ps, crump nograph
```

```
----------------------------------------------------------------------
Common Support Assessment
----------------------------------------------------------------------
Treatment:         statin
PS variable:       ps
Observations:             800
----------------------------------------------------------------------

------------------------------------------------------------
Propensity Score Range
------------------------------------------------------------
                            Treated        Control
------------------------------------------------------------
                   N            551            249
              Min PS         0.3136         0.1853
              Max PS         0.9505         0.9206
------------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.3136
Upper bound:               0.9206
Outside support:               17 ( 2.12%)
  Treated outside:             12
  Control outside:              5
-------------------------------------------------------

-------------------------------------------------------
Crump et al. (2009) Optimal Trimming
-------------------------------------------------------
Optimal alpha:             0.1000
Trim region:           [0.100, 0.900]
Observations trimmed:          26 ( 3.25%)
Remaining sample:             774
-------------------------------------------------------

Support: Trimmed ( 3.2% excluded)
```

</details>

![Combined dashboard](demo/dashboard.png)

### Multi-group treatment (3 arms)

Synthetic data: 1,200 observations, 3-arm treatment (placebo / low dose / high dose) assigned via multinomial logit with confounding by age, BMI, and SBP. Generalized propensity scores via `mlogit`, generalized IPTW weights.

<details>
<summary>Multi-group overlap (click to expand)</summary>

```stata
. noisily psdash overlap arm, psvars(ps0 ps1 ps2) nograph
```

```
----------------------------------------------------------------------
Propensity Score Overlap
----------------------------------------------------------------------
Treatment:         arm (3 groups)
PS variable:       ps0
Reference group:   0
----------------------------------------------------------------------

-----------------------------------------------------------
Propensity Score Distribution
-----------------------------------------------------------
                          Placebo     Low dose    High dose
-----------------------------------------------------------
                   N          154          321          725
                Mean       0.1515       0.2738       0.6163
                  SD       0.0608       0.0409       0.0831
                 Min       0.0422       0.1758       0.3046
                 Max       0.3586       0.4003       0.8513
-----------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.3046
Upper bound:               0.3586
Outside support:             1129 (94.08%)
  Placebo outside:        152
  Low dose outside:        253
  High dose outside:        724
-------------------------------------------------------
Warning: >10% of observations outside common support region.

Overlap: WARNING (94.1% outside support)
  Consider: psdash support, threshold(0.05)
```

</details>

![Multi-group overlap density](demo/mg_overlap_density.png)

<details>
<summary>Multi-group balance (click to expand)</summary>

```stata
. noisily psdash balance arm, psvars(ps0 ps1 ps2)
>     covariates(age female bmi sbp cholesterol creatinine) wvar(gipw)
```

```
---------------------------------------------------------------------------
Covariate Balance Assessment (Multi-Group)
---------------------------------------------------------------------------
Treatment:     arm (3 groups, ref = 0)
Estimand:      ATE
N (Group Placebo):       154
N (Group Low dose):       321
N (Group High dose):       725
Weights:       gipw
Threshold:      0.100
---------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------------
           Covariate |  SMD 1v0      VR  SMD 2v0      VR  Adj 1v0      VR  Adj 2v0      VR      Status
-----------------------------------------------------------------------------------------------------
                 age | 0.228  1.35 0.483  1.24 0.091  1.45 0.087  1.34    Balanced
              female |-0.013  1.00-0.018  0.99 0.006  1.00 0.009  1.00    Balanced
                 bmi |-0.026  0.80 0.124  0.93-0.055  0.78-0.039  0.90    Balanced
                 sbp | 0.126  1.11 0.077  1.08 0.026  1.17 0.018  1.16    Balanced
         cholesterol |-0.033  0.91-0.099  0.97 0.020  0.95 0.012  1.03    Balanced
          creatinine |-0.231  0.87-0.269  0.85 0.028  0.89 0.021  0.85    Balanced
-----------------------------------------------------------------------------------------------------


Maximum |SMD| (raw):       0.483
Maximum |SMD| (adjusted):  0.091
Covariates > SMD threshold:    0 of   6
-----------------------------------------------------------------------------------------------------

Balance: Adequate (max |SMD| =  0.091)
```

</details>

![Multi-group Love plot](demo/mg_love_plot.png)

<details>
<summary>Multi-group weight diagnostics (click to expand)</summary>

```stata
. noisily psdash weights arm, psvars(ps0 ps1 ps2) wvar(gipw)
```

```
----------------------------------------------------------------------
IPTW Weight Diagnostics (Multi-Group)
----------------------------------------------------------------------
Weight variable:   gipw
Treatment:         arm (3 groups, ref = 0)
Observations:           1,200
----------------------------------------------------------------------

-------------------------------------------------------------------------------------
Weight Distribution Summary
-------------------------------------------------------------------------------------
                                 Overall        Placebo       Low dose      High dose
-------------------------------------------------------------------------------------
                        N          1,200            154            321            725
                     Mean          2.989          7.708          3.737          1.655
                       SD          2.351          3.212          0.577          0.251
                      Min          1.175          2.789          2.498          1.175
                      Max         23.690         23.690          5.688          3.283
-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
Effective Sample Size (ESS)
-------------------------------------------------------------------------------------
                                 Overall        Placebo       Low dose      High dose
-------------------------------------------------------------------------------------
                      ESS          741.5          131.3          313.6          708.8
               ESS % of N          61.8%          85.3%          97.7%          97.8%
-------------------------------------------------------------------------------------

--------------------------------------------------
Extreme Weight Detection
--------------------------------------------------
Coefficient of Variation:    0.787
Weights > 10:                   30 ( 2.50%)
Weights > 20:                    1
--------------------------------------------------

Warning: 30 extreme weights detected (>10).
Warning: Maximum weight exceeds 20. Consider truncation.

Weights: Acceptable (ESS = 61.8% of N)
```

</details>

<details>
<summary>Multi-group common support (click to expand)</summary>

```stata
. noisily psdash support arm, psvars(ps0 ps1 ps2) threshold(0.1) nograph
```

```
----------------------------------------------------------------------
Common Support Assessment
----------------------------------------------------------------------
Treatment:         arm (3 groups)
PS variable:       ps0
Reference group:   0
Observations:           1,200
----------------------------------------------------------------------

-----------------------------------------------------------
Propensity Score Range
-----------------------------------------------------------
                          Placebo     Low dose    High dose
-----------------------------------------------------------
                   N          154          321          725
              Min PS       0.0422       0.1758       0.3046
              Max PS       0.3586       0.4003       0.8513
-----------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.3046
Upper bound:               0.3586
Outside support:             1129 (94.08%)
  Placebo outside:        152
  Low dose outside:        253
  High dose outside:        724
-------------------------------------------------------

-------------------------------------------------------
Manual Threshold Trimming
-------------------------------------------------------
Threshold:                 0.1000
Trim region:           [0.100, 0.900]
Observations trimmed:          30 ( 2.50%)
Remaining sample:            1170
-------------------------------------------------------
Warning: >10% of observations outside common support.

Support: Trimmed ( 2.5% excluded)
```

</details>

PNG demo images in demo/ are tracked in this repository.

## Version History

- **v1.0.1** (06 May 2026): Hardened PS detection and validation, fixed `teffects` binary PS orientation, K=2 non-0/1 auto-weights, support threshold validation, and binary variance-ratio summaries.
- **v1.0.0** (29 Apr 2026): Initial release with five subcommands
