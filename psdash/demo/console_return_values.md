---
title: "console_return_values"
---

## Stored results for automated checks

```stata
. noisily psdash balance statin ps,
>     covariates(age female bmi sbp cholesterol) wvar(ipw)
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
. noisily return list
```

```
scalars:
  r(n_ps_near_boundar
    y)                 =  0
      r(n_ps_boundary) =  0
          r(threshold) =  .1
         r(max_ks_raw) =  .2105117384237494
    r(n_vr_imbalanced) =  0
       r(n_imbalanced) =  0
         r(max_vr_adj) =  1.072659849876111
        r(max_smd_adj) =  .047032989657052
         r(max_vr_raw) =  1.04099727858756
        r(max_smd_raw) =  .4715906455790541
          r(N_control) =  249
          r(N_treated) =  551
                  r(N) =  800

macros:
               r(wvar) : "ipw"
            r(varlist) : "age female bmi sbp cholesterol"
             r(source) : "manual"
           r(estimand) : "ate"
          r(treatment) : "statin"

matrices:
            r(balance) :  5 x 10
                r(smd) :  5 x 2
```

```stata
. noisily matrix list r(balance)
```

```
r(balance)[5,10]
                 Mean_T      Mean_C     SMD_Raw      VR_Raw      KS_Raw  Mean_T_Adj  Mean_C_Adj     SMD_Adj      VR_Adj
        age   56.201472   50.841637   .47159065    .9863665   .20893009   54.599767   54.447924   .01336012   1.0070175
     female   .58802178   .37751004   .43031695   1.0286036   .21051174   .52249024    .5219277    .0011499    .9976949
        bmi   27.069826   26.298333   .15640269   1.0152641   .09817856   26.858463   26.790461   .01378595   1.0726598
        sbp   135.14109   130.82382   .19425841   1.0121024   .10261008    133.8648   133.45975   .01822554   1.0508027
cholesterol   201.03442   199.49472   .03903631   1.0409973   .03875393   201.36172   199.50661   .04703299   .99087308

                 KS_Adj
        age           .
     female           .
        bmi           .
        sbp           .
cholesterol           .
```
