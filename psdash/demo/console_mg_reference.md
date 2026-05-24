---
title: "console_mg_reference"
---

## Multi-group balance with reference arm 1

```stata
. noisily psdash balance arm, psvars(ps0 ps1 ps2)
>     covariates(age female bmi sbp cholesterol creatinine)
>     wvar(gipw) reference(1)
```

```
Covariate Balance Assessment (Multi-Group)
Treatment:     arm (3 groups, ref = 1)
Estimand:      ATE
N (Group Placebo):       154
N (Group Low dose):       321
N (Group High dose):       725
Weights:       gipw
Threshold:      0.100


-----------------------------------------------------------------------------------------------------
           Covariate |  SMD 0v1      VR  SMD 2v1      VR  Adj 0v1      VR  Adj 2v1      VR      Status
-----------------------------------------------------------------------------------------------------
                 age |-0.228  0.74 0.232  0.91-0.091  0.69-0.005  0.93    Balanced
              female | 0.013  1.00-0.005  1.00-0.006  1.00 0.004  1.00    Balanced
                 bmi | 0.026  1.24 0.157  1.15 0.055  1.29 0.014  1.16    Balanced
                 sbp |-0.126  0.90-0.049  0.97-0.026  0.85-0.008  0.99    Balanced
         cholesterol | 0.033  1.10-0.068  1.06-0.020  1.05-0.008  1.09    Balanced
          creatinine | 0.231  1.15-0.038  0.97-0.028  1.13-0.007  0.96    Balanced
-----------------------------------------------------------------------------------------------------


Maximum |SMD| (raw):       0.232
Maximum |SMD| (adjusted):  0.091
Covariates > SMD threshold:    0 of   6
-----------------------------------------------------------------------------------------------------

Balance: Adequate (max |SMD| =  0.091)
```
