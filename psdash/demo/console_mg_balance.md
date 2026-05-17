---
title: "console_mg_balance"
---

```stata
. noisily psdash balance arm, psvars(ps0 ps1 ps2)
>     covariates(age female bmi sbp cholesterol creatinine) wvar(gipw)
```

```
Covariate Balance Assessment (Multi-Group)
Treatment:     arm (3 groups, ref = 0)
Estimand:      ATE
N (Group Placebo):       154
N (Group Low dose):       321
N (Group High dose):       725
Weights:       gipw
Threshold:      0.100


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
