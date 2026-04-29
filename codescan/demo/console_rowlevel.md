---
title: "console_rowlevel"
---

```stata
. noisily codescan dx1 dx2 dx3 dx4,
>     define(dm "E1[01]" | htn "I1[0-35]" | chf "I50" | copd "J4[0-7]" |
>            cancer "C[0-7]" ~ "C77|C78|C79|C80" | metastatic "C7[789]|C80")
>     label(dm "Diabetes" \ htn "Hypertension" \ chf "Heart failure" \
>           copd "COPD" \ cancer "Cancer (non-met)" \ metastatic "Metastatic cancer")
>     detail noisily
```

```
  dm: 384 matches across 4 variables
  htn: 227 matches across 4 variables
  chf: 51 matches across 4 variables
  copd: 159 matches across 4 variables
  cancer: 212 matches across 4 variables
  metastatic: 171 matches across 4 variables

codescan: 6 conditions, 4 variables, N =      1,500

  Condition              Matches   Prevalence            [95% CI]
  ----------------------------------------------------------------
  dm                         384        25.6%    [ 23.5,  27.9]
  htn                        227        15.1%    [ 13.4,  17.0]
  chf                         51         3.4%    [  2.6,   4.4]
  copd                       159        10.6%    [  9.1,  12.3]
  cancer                     212        14.1%    [ 12.5,  16.0]
  metastatic                 171        11.4%    [  9.9,  13.1]

  Per-variable match contribution:
  dm: 129 in dx1, 96 in dx2, 100 in dx3, 59 in dx4
  htn: 84 in dx1, 47 in dx2, 45 in dx3, 51 in dx4
  chf: 16 in dx1, 10 in dx2, 13 in dx3, 12 in dx4
  copd: 51 in dx1, 31 in dx2, 39 in dx3, 38 in dx4
  cancer: 66 in dx1, 50 in dx2, 46 in dx3, 50 in dx4
  metastatic: 42 in dx1, 51 in dx2, 39 in dx3, 39 in dx4

```
