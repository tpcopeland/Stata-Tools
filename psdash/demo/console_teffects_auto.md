---
title: "console_teffects_auto"
---

## Automatic detection after teffects

```stata
. noisily teffects ipw (ldl_change) (statin age female bmi sbp cholesterol)
```

```
Iteration 0:   EE criterion =  7.348e-24
Iteration 1:   EE criterion =  3.610e-31

Treatment-effects estimation                    Number of obs     =        800
Estimator      : inverse-probability weights
Outcome model  : weighted mean
Treatment model: logit
------------------------------------------------------------------------------
             |               Robust
  ldl_change | Coefficient  std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
ATE          |
      statin |
(Yes vs No)  |   -20.2643   .9216667   -21.99   0.000    -22.07073   -18.45786
-------------+----------------------------------------------------------------
POmean       |
      statin |
         No  |   17.67373   .8291345    21.32   0.000     16.04866    19.29881
------------------------------------------------------------------------------
```

```stata
. noisily psdash combined
```

```
Propensity Score Diagnostics Dashboard
Treatment:     statin
PS variable:   auto-generated
Covariates:    5
Weights:       auto-generated
Estimand:      ATE
Source:        teffects

=== OVERLAP DIAGNOSTICS ===

PS Overlap
Treatment:         statin
PS variable:       __000001

----------------------------------------------------------------------
Propensity Score Distribution
----------------------------------------------------------------------
                            Treated        Control
----------------------------------------------------------------------
                   N            551            249
                Mean         0.7194         0.6209
                  SD         0.1331         0.1491
                 Min         0.2828         0.1771
                 Max         0.9488         0.9289
----------------------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.2828
Upper bound:               0.9289
Outside support:               10 ( 1.25%)
  Treated outside:              8
  Control outside:              2
C-statistic (AUC):         0.6901
-------------------------------------------------------

Overlap: Good ( 1.2% outside support)

=== BALANCE DIAGNOSTICS ===

Covariate Balance
Treatment:     statin
Estimand:      ATE
N (treated):          551
N (control):          249
Weights:       __000002
Threshold:      0.100


---------------------------------------------------------------------------------------
           Covariate |  SMD Raw  VR Raw  SMD Adj  VR Adj      Status
---------------------------------------------------------------------------------------
                 age | 0.472  0.99 0.007  1.00    Balanced
              female | 0.430  1.03 0.003  1.00    Balanced
                 bmi | 0.156  1.02 0.007  1.07    Balanced
                 sbp | 0.194  1.01 0.012  1.06    Balanced
         cholesterol | 0.039  1.04-0.032  0.99    Balanced
---------------------------------------------------------------------------------------


Maximum |SMD| (raw):       0.472
Maximum |SMD| (adjusted):  0.032
Maximum VR (raw):           1.04
Maximum VR (adjusted):      1.07
Covariates > SMD threshold:    0 of   5
---------------------------------------------------------------------------------------

Balance: Adequate (max |SMD| =  0.032)

=== WEIGHT DIAGNOSTICS ===

IPTW Weight Diagnostics
Weight variable:   __000002
Treatment:         statin
Observations:             800

----------------------------------------------------------------------
Weight Distribution Summary
----------------------------------------------------------------------
                                 Overall        Treated        Control
----------------------------------------------------------------------
                        N            800            551            249
                     Mean          1.998          1.450          3.212
                       SD          1.298          0.341          1.740
                      Min          1.054          1.054          1.215
                      Max         14.074          3.536         14.074
----------------------------------------------------------------------

----------------------------------------------------------------------
Effective Sample Size (ESS)
----------------------------------------------------------------------
                                 Overall        Treated        Control
----------------------------------------------------------------------
                      ESS          562.7          522.3          192.6
               ESS % of N          70.3%          94.8%          77.4%
----------------------------------------------------------------------

--------------------------------------------------
Extreme Weight Detection
--------------------------------------------------
Coefficient of Variation:    0.650
Weights > 10:                    3 ( 0.38%)
Weights > 20:                    0
--------------------------------------------------

Warning: 3 extreme weights detected (>10).

Weights: Acceptable (ESS = 70.3% of N)

=== COMMON SUPPORT ASSESSMENT ===

Common Support
Treatment:         statin
PS variable:       __000001
Observations:             800

------------------------------------------------------------
Propensity Score Range
------------------------------------------------------------
                            Treated        Control
------------------------------------------------------------
                   N            551            249
              Min PS         0.2828         0.1771
              Max PS         0.9488         0.9289
------------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.2828
Upper bound:               0.9289
Outside support:               10 ( 1.25%)
  Treated outside:              8
  Control outside:              2
-------------------------------------------------------

Support: Good ( 1.2% outside support)
Overall: PASS
```
