---
title: "Auto Dataset Analysis"
date: "March 2026"
---

```stata
. * Summary statistics
```

```stata
. summarize price mpg weight length, separator(0)
```

```
    Variable │        Obs        Mean    Std. dev.       Min        Max
─────────────┼─────────────────────────────────────────────────────────
       price │         74    6165.257    2949.496       3291      15906
         mpg │         74     21.2973    5.785503         12         41
      weight │         74    3019.459    777.1936       1760       4840
      length │         74    187.9324    22.26634        142        233

```

```stata
. * Regression with table output
```

```stata
. regress price mpg weight length i.foreign
```

```
      Source │       SS           df       MS      Number of obs   =        74
─────────────┼──────────────────────────────────   F(4, 69)        =     21.01
       Model │   348708940         4    87177235   Prob > F        =    0.0000
    Residual │   286356456        69  4150093.57   R-squared       =    0.5491
─────────────┼──────────────────────────────────   Adj R-squared   =    0.5230
       Total │   635065396        73  8699525.97   Root MSE        =    2037.2

```

```
─────────────┬──────────────────────────────────────────────────────────────────────
        price │ Coefficient   Std. err.       t    P>|t|      [95% con f. interval]
─────────────┼──────────────────────────────────────────────────────────────────────
         mpg │   -13.40719    72.10761     -0.19    0.853     -157.2579     130.4436
      weight │    5.716181    1.016095      5.63    0.000      3.689127     7.743235
      length │   -92.48018     33.5912     -2.75    0.008     -159.4928    -25.46758
             │──────────────────────────────────────────────────────────────────────
     foreign │
    Foreign  │    3550.194    655.4564      5.42    0.000      2242.594     4857.793
       _cons │     5515.58    5241.941      1.05    0.296     -4941.807     15972.97
─────────────┴──────────────────────────────────────────────────────────────────────
```

```stata
. * Margins after regression
```

```stata
. margins foreign, atmeans
```

```

 Adjusted predictions                                       Number of obs  = 74
 Model VCE: OLS


Linear prediction, predict()

At: mpg = 21.2973 
weight = 3019.459 
length = 187.9324 
0.foreign = .7027027 
1.foreign = .2972973 

```

```
─────────────┬──────────────────────────────────────────────────────────────────────
             │            Delta-method
             │     Margin    std. err.       t    P>|t|      [95% con f. interval]
─────────────┼──────────────────────────────────────────────────────────────────────
     foreign │
   Domestic  │    5109.794    306.6837     16.66    0.000      4497.977     5721.611
    Foreign  │    8659.987    517.9058     16.72    0.000      7626.794     9693.181
─────────────┴──────────────────────────────────────────────────────────────────────
```

```stata
. * Tabulation
```

```stata
. tabulate foreign rep78
```

```
           │                   Repair record 1978
Car origin │         1          2          3          4          5 │     Total
───────────┼───────────────────────────────────────────────────────┼───────────
  Domestic │         2          8         27          9          2 │        48 
   Foreign │         0          0          3          9          9 │        21 
───────────┼───────────────────────────────────────────────────────┼───────────
     Total │         2          8         30         18         11 │        69 

```

```stata
. * Residual histogram
```

```stata
. quietly regress price mpg weight
```

```stata
predict double resid, residuals
```

```stata
histogram resid, normal scheme(plotplainblind)
>     title("Residual Distribution")
>     xtitle("Residuals") ytitle("Density")
```

```
(bin=8, start=-3332.4617, width=1354.9264)

```

```stata
graph export "logdoc/demo/residuals.png", replace width(800)
```

![residuals.png](residuals.png)

```
file **logdoc/demo/residuals.png** written in PNG format

```

```stata
capture graph close _all
```

```stata
drop resid
```
