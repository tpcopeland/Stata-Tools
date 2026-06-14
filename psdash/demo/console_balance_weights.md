---
title: "console_balance_weights"
---

## Binary balance and IPTW diagnostics

```stata
. noisily psdash balance statin ps,
>     covariates(age female bmi sbp cholesterol) wvar(ipw) ks
```

```
Covariate Balance Assessment
Treatment:     statin
Estimand:      ATE
N (treated):          551
N (control):          249
Weights:       ipw
Threshold:      0.100


------------------------------------------------------------------------------------------------
           Covariate |  SMD Raw  VR Raw      KS  SMD Adj  VR Adj      Status
------------------------------------------------------------------------------------------------
                 age | 0.472  0.99 0.209 0.013  1.01    Balanced
              female | 0.430  1.03 0.211 0.001  1.00    Balanced
                 bmi | 0.156  1.02 0.098 0.014  1.07    Balanced
                 sbp | 0.194  1.01 0.103 0.018  1.05    Balanced
         cholesterol | 0.039  1.04 0.039 0.047  0.99    Balanced
------------------------------------------------------------------------------------------------


Maximum |SMD| (raw):       0.472
Maximum |SMD| (adjusted):  0.047
Maximum VR (raw):           1.04
Maximum VR (adjusted):      1.07
Covariates > SMD threshold:    0 of   5
Maximum KS (raw):             0.211
------------------------------------------------------------------------------------------------

Balance: Adequate (max |SMD| =  0.047)
```

```stata
. noisily psdash weights statin ps, wvar(ipw)
```

```
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
Weights > 10:                    3 ( 0.38%)
Weights > 20:                    0
--------------------------------------------------

Warning: 3 extreme weights detected (>10).

Weights: Acceptable (ESS = 71.2% of N)
```
