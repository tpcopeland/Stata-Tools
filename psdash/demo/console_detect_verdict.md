---
title: "console_detect_verdict"
---

## Auto-detection report and machine-readable verdict

### psdash detect — inspect detection without running panels

```stata
. noisily psdash detect statin ps, covariates(age female bmi sbp cholesterol)
```

```
psdash detection report (dry run — no diagnostics computed)
Source:        manual
Treatment:     statin
Type:          binary
PS variable:   ps
Covariates:    5 detected/supplied
  age female bmi sbp cholesterol
Estimand:      ATE
Longitudinal:  no

Run psdash combined (without dryrun) to compute diagnostics.
```

### Returned verdict with configurable thresholds

```stata
. noisily psdash combined statin ps,
>     covariates(age female bmi sbp cholesterol) wvar(ipw)
>     overlapmax(5) essmin(60) nooverlap nosupport
```

```
Propensity Score Diagnostics Dashboard
Treatment:     statin
PS variable:   ps
Covariates:    5
Weights:       ipw
Estimand:      ATE
Source:        manual

=== BALANCE DIAGNOSTICS ===

Covariate Balance
Treatment:     statin
Estimand:      ATE
N (treated):          551
N (control):          249
Weights:       ipw
Threshold:      0.100


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
Note: variance ratio is not a meaningful balance diagnostic for binary covariate(s): female
      (VR for a two-level covariate is determined by the SMD; excluded from the VR count).

Balance: Adequate (max |SMD| =  0.047)

=== WEIGHT DIAGNOSTICS ===

IPTW Weight Diagnostics
Weight variable:   ipw
Treatment:         statin
Observations:             800

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
Max / mean weight ratio:      6.31
Weights > 10:                    3 ( 0.38%)
Weights > 20:                    0
--------------------------------------------------

Warning: 3 extreme weights detected (>10).

Weights: WARNING (ESS = 71.2% of N; 1 finding(s))
  Consider: psdash weights, trim(99) generate(w_trim) or psdash weights, truncate(#) generate(w_trunc)

Overall: FAIL (1 finding(s) across 2 panel(s): weights)
  Findings: [weights] 3 extreme weights > 10
  Consider: rerun failing panels individually for targeted diagnostics
```

```stata
. noisily display "verdict = " r(verdict) "  (n_warnings = " r(n_warnings) ")"
```

```
verdict = FAIL  (n_warnings = 1)
```

```stata
. noisily display "warnings = " r(warnings)
```

```
warnings = [weights] 3 extreme weights > 10
```
