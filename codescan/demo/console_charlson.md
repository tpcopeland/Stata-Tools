---
title: "console_charlson"
---

```stata
. noisily codescan dx1 dx2 dx3 dx4,
>     codefile(charlson_icd10_example.csv)
>     id(pid) date(visit_dt) refdate(index_dt)
>     lookback(365) inclusive
>     collapse alldates countrows
>     score(charlson)
>     hierarchy(dm_comp > dm_uncomp \ liver_severe > liver_mild \ metastatic > cancer)
>     cooccurrence detail noisily
```

```
(file /tmp/St1311976.000001 not found)
  mi: 28 matches across 4 variables
  chf: 44 matches across 4 variables
  pvd: 39 matches across 4 variables
  cvd: 0 matches across 4 variables
(note: condition cvd matched 0 observations)
  dementia: 28 matches across 4 variables
  copd: 40 matches across 4 variables
  rheumatic: 45 matches across 4 variables
  peptic: 14 matches across 4 variables
  liver_mild: 44 matches across 4 variables
  dm_uncomp: 62 matches across 4 variables
  dm_comp: 61 matches across 4 variables
  hemiplegia: 41 matches across 4 variables
  renal: 65 matches across 4 variables
  cancer: 98 matches across 4 variables
  liver_severe: 28 matches across 4 variables
  metastatic: 45 matches across 4 variables
  hiv: 28 matches across 4 variables
  (hierarchy: 3 rule(s) applied)

codescan: 17 conditions, 4 variables, N =        344
Window: 365 days before index_dt (inclusive)

  Condition              Matches   Prevalence            [95% CI]
  ----------------------------------------------------------------
  mi                          28         8.1%    [  5.7,  11.5]
  chf                         43        12.5%    [  9.4,  16.4]
  pvd                         37        10.8%    [  7.9,  14.5]
  cvd                          0         0.0%    [  0.0,   1.1]
  dementia                    28         8.1%    [  5.7,  11.5]
  copd                        39        11.3%    [  8.4,  15.1]
  rheumatic                   45        13.1%    [  9.9,  17.1]
  peptic                      14         4.1%    [  2.4,   6.7]
  liver_mild                  38        11.0%    [  8.2,  14.8]
  dm_uncomp                   53        15.4%    [ 12.0,  19.6]
  dm_comp                     61        17.7%    [ 14.1,  22.1]
  hemiplegia                  41        11.9%    [  8.9,  15.8]
  renal                       62        18.0%    [ 14.3,  22.4]
  cancer                      85        24.7%    [ 20.4,  29.5]
  liver_severe                28         8.1%    [  5.7,  11.5]
  metastatic                  44        12.8%    [  9.7,  16.7]
  hiv                         28         8.1%    [  5.7,  11.5]

  Collapsed to        344 unique pid values

  charlson score: mean =  3.89, median =   3.0, range = [  0,  17]

  Per-variable match contribution:
  mi: 5 in dx1, 8 in dx2, 7 in dx3, 8 in dx4
  chf: 12 in dx1, 13 in dx2, 7 in dx3, 12 in dx4
  pvd: 16 in dx1, 7 in dx2, 11 in dx3, 5 in dx4
  cvd: no matches
  dementia: 7 in dx1, 7 in dx2, 8 in dx3, 6 in dx4
  copd: 13 in dx1, 4 in dx2, 11 in dx3, 12 in dx4
  rheumatic: 13 in dx1, 10 in dx2, 11 in dx3, 11 in dx4
  peptic: 1 in dx1, 3 in dx2, 6 in dx3, 4 in dx4
  liver_mild: 13 in dx1, 9 in dx2, 11 in dx3, 11 in dx4
  dm_uncomp: 17 in dx1, 15 in dx2, 17 in dx3, 13 in dx4
  dm_comp: 21 in dx1, 15 in dx2, 16 in dx3, 9 in dx4
  hemiplegia: 10 in dx1, 10 in dx2, 12 in dx3, 9 in dx4
  renal: 27 in dx1, 14 in dx2, 10 in dx3, 14 in dx4
  cancer: 29 in dx1, 27 in dx2, 24 in dx3, 18 in dx4
  liver_severe: 9 in dx1, 11 in dx2, 3 in dx3, 5 in dx4
  metastatic: 13 in dx1, 9 in dx2, 14 in dx3, 9 in dx4
  hiv: 11 in dx1, 11 in dx2, 2 in dx3, 4 in dx4

  Co-occurrence:
                              mi      chf      pvd      cvd dementia     copdrheumatic   pepticliver_milddm_uncomp  dm_comphemiplegia    renal   cancerliver_severemetastatic      hiv
  mi                          28        4        2        0        2        6        6        1        2        3        4        1        5        3        2        3        0
  chf                          4       43        3        0        2        7        4        2        8        6        6        3        8       11        1        3        4
  pvd                          2        3       37        0        3        3        6        5        4        6        6        3        8        9        4        3        0
  cvd                          0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0
  dementia                     2        2        3        0       28        5        6        1        7        3        3        6        4        7        2        1        2
  copd                         6        7        3        0        5       39        7        0        4        3        8        7        6       10        3        5        2
  rheumatic                    6        4        6        0        6        7       45        0        7        6        7        6        8       13        4        8        2
  peptic                       1        2        5        0        1        0        0       14        2        3        1        2        7        5        2        2        2
  liver_mild                   2        8        4        0        7        4        7        2       38        2        4        3        4       11        0        5        5
  dm_uncomp                    3        6        6        0        3        3        6        3        2       53        0        4        7       10        3        6        6
  dm_comp                      4        6        6        0        3        8        7        1        4        0       61        7       15       12        7        6        6
  hemiplegia                   1        3        3        0        6        7        6        2        3        4        7       41        5        8        4        8        4
  renal                        5        8        8        0        4        6        8        7        4        7       15        5       62       15        6        6        5
  cancer                       3       11        9        0        7       10       13        5       11       10       12        8       15       85       10        0        9
  liver_severe                 2        1        4        0        2        3        4        2        0        3        7        4        6       10       28        5        3
  metastatic                   3        3        3        0        1        5        8        2        5        6        6        8        6        0        5       44        2
  hiv                          0        4        0        0        2        2        2        2        5        6        6        4        5        9        3        2       28

```

```stata
. noisily summarize _score, detail
```

```
                       charlson score
-------------------------------------------------------------
      Percentiles      Smallest
 1%            0              0
 5%            0              0
10%            1              0       Obs                 344
25%            2              0       Sum of wgt.         344

50%            3                      Mean           3.892442
                        Largest       Std. dev.      3.062526
75%            6             13
90%            8             14       Variance       9.379068
95%            9             14       Skewness       1.024558
99%           13             17       Kurtosis       3.972026

```
