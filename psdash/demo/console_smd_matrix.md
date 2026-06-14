---
title: "console_smd_matrix"
---

## Balance SMD matrix for table1_tc / puttab

```stata
. noisily psdash balance statin ps,
>     covariates(age female bmi sbp cholesterol) wvar(ipw) smdmatrix(smd_table)
```

```
Covariate Balance Assessment
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

Balance: Adequate (max |SMD| =  0.047)
```

```stata
. noisily matrix list smd_table
```

```
smd_table[5,2]
             SMD_unadj    SMD_adj
        age  .47159065  .01336012
     female  .43031695   .0011499
        bmi  .15640269  .01378595
        sbp  .19425841  .01822554
cholesterol  .03903631  .04703299
```
