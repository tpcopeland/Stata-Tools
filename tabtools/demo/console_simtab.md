---
title: "console_simtab"
---

## simtab: Monte Carlo simulation performance tables

<!-- * simtab summarizes one row per replication x estimator x estimand x scenario -->

<!-- * into table-grade performance measures, then styles and exports the table. -->

### Compute mode: scenarios, estimators, non-convergence, coverage flag

<!-- * The intended replication count is nsim(400). Estimators whose fits failed -->

<!-- * to converge show nfail > 0 via the nonconv column. Coverage that deviates -->

<!-- * from the nominal 95% by more than 2 Monte Carlo SEs is flagged with "*". -->

```stata
. use "`reps'", clear
```

```stata
. keep if emd == 1
```

```
(3,524 observations deleted)
```

```stata
. noisily simtab estid, estimate(est) se(se) true(truev)
>     by(scen) sim(sim) coverage(covered) nsim(400)
>     metrics(mean bias empse meanse coverage n nonconv)
>     digits(3) xlsx("`xlsx_simtab'") sheet("Scenarios")
>     title("Simulation results by scenario (400 replications)")
>     footnote("Coverage is empirical 95% CI coverage; * flags off-nominal coverage.")
>     display
```

```
note: coverage 85.8% is off-nominal (estimator Unweighted, scenario A)
note: coverage 74.7% is off-nominal (estimator Unweighted, scenario B)
note: coverage 73.9% is off-nominal (estimator Unweighted, scenario C)
note: coverage 91.5% is off-nominal (estimator IIW + log(test), scenario C)

Simulation results by scenario (400 replications)
  +----------------------------------------------------------------------------------------------+
  | Scenario         Estimator    Mean     Bias   Emp. SE   Mean SE   Coverage     N   Non-conv. |
  |        A        Unweighted   0.142   +0.042     0.040     0.042       86%*   372          28 |
  |                        IIW   0.093   -0.007     0.039     0.042        95%   400           0 |
  |            IIW + log(test)   0.109   +0.009     0.039     0.042        96%   400           0 |
  |        B        Unweighted   0.151   +0.051     0.042     0.042       75%*   379          21 |
  |----------------------------------------------------------------------------------------------|
  |                        IIW   0.102   +0.002     0.042     0.042        96%   400           0 |
  |            IIW + log(test)   0.120   +0.020     0.039     0.042        94%   400           0 |
  |        C        Unweighted   0.157   +0.057     0.041     0.042       74%*   379          21 |
  |                        IIW   0.110   +0.010     0.040     0.042        96%   400           0 |
  |            IIW + log(test)   0.128   +0.028     0.040     0.042       92%*   400           0 |
  +----------------------------------------------------------------------------------------------+

Coverage is empirical 95% CI coverage; * flags off-nominal coverage.
simtab: wrote 9 data rows x 9 cols to sheet Scenarios in /home/tpcopeland/Stata-Tools/tabtools/demo/demo_simtab.xlsx
```

### Figure-ready companion frame (plotframe)

<!-- * plotframe() stores one row per by x estimator x estimand cell with the raw -->

<!-- * measures and their Monte Carlo SEs - the structured source for figures, -->

<!-- * replacing the fragile "parse a text log" boundary. -->

```stata
. use "`reps'", clear
```

```stata
. keep if emd == 1
```

```
(3,524 observations deleted)
```

```stata
. quietly simtab estid, estimate(est) se(se) true(truev)
>     by(scen) sim(sim) coverage(covered) nsim(400)
>     metrics(mean bias empse coverage n) plotframe(simfig, replace)
```

```stata
. frame simfig: format mean bias empse %6.3f
```

```stata
. frame simfig: format coverage mcse_coverage %5.3f
```

```stata
. noisily frame simfig: list by_label estimator_label mean bias empse
>     coverage mcse_coverage nfail n, noobs sepby(by_label)
```

```
  +-----------------------------------------------------------------------------------------+
  | by_label   estimator_label    mean     bias   empse   coverage   mcse_c~e   nfail     n |
  |-----------------------------------------------------------------------------------------|
  |        A        Unweighted   0.142    0.042   0.040      0.858      0.018      28   372 |
  |        A               IIW   0.093   -0.007   0.039      0.952      0.011       0   400 |
  |        A   IIW + log(test)   0.109    0.009   0.039      0.962      0.009       0   400 |
  |-----------------------------------------------------------------------------------------|
  |        B        Unweighted   0.151    0.051   0.042      0.747      0.022      21   379 |
  |        B               IIW   0.102    0.002   0.042      0.957      0.010       0   400 |
  |        B   IIW + log(test)   0.120    0.020   0.039      0.942      0.012       0   400 |
  |-----------------------------------------------------------------------------------------|
  |        C        Unweighted   0.157    0.057   0.041      0.739      0.023      21   379 |
  |        C               IIW   0.110    0.010   0.040      0.960      0.010       0   400 |
  |        C   IIW + log(test)   0.128    0.028   0.040      0.915      0.014       0   400 |
  +-----------------------------------------------------------------------------------------+
```

### Ingest mode: render a pre-computed summary (from(summary))

<!-- * When the per-cell numbers already exist - computed by simsum, siman, or any -->

<!-- * collapse - simtab renders them without recomputation. from(summary) maps the -->

<!-- * columns explicitly and never depends on an external package. -->

```stata
. use "`reps'", clear
```

```stata
. keep if emd == 1
```

```
(3,524 observations deleted)
```

```stata
. collapse (mean) avg=est (sd) sdest=est (mean) cov=covered
```

```
>     (count) nrep=est, by(scen estid)
```

```stata
. gen double b = avg - 0.10
```

```stata
. noisily list scen estid avg b sdest cov nrep, noobs sepby(scen)
```

```
  +-----------------------------------------------------------------------------+
  | scen             estid         avg           b       sdest       cov   nrep |
  |-----------------------------------------------------------------------------|
  |    A        Unweighted   .14171439   .04171439   .03966624   .857527    372 |
  |    A               IIW    .0934485   -.0065515   .03918887     .9525    400 |
  |    A   IIW + log(test)   .10913499   .00913499   .03893928     .9625    400 |
  |-----------------------------------------------------------------------------|
  |    B        Unweighted   .15110523   .05110523   .04224197   .746702    379 |
  |    B               IIW   .10158071   .00158071   .04195086     .9575    400 |
  |    B   IIW + log(test)   .12009573   .02009573   .03948182     .9425    400 |
  |-----------------------------------------------------------------------------|
  |    C        Unweighted   .15721494   .05721494   .04056943   .738786    379 |
  |    C               IIW   .10993618   .00993618   .04010997       .96    400 |
  |    C   IIW + log(test)   .12765362   .02765362   .04022542      .915    400 |
  +-----------------------------------------------------------------------------+
```

```stata
. noisily simtab, from(summary) byvar(scen) estimatorvar(estid)
>     measures(mean=avg bias=b empse=sdest coverage=cov n=nrep)
>     title("Ingested per-cell summary (no recomputation)") display
```

```
Ingested per-cell summary (no recomputation)
  +------------------------------------------------------------------+
  | scen             estid   Mean    Bias   Emp. SE   Coverage     N |
  |    A        Unweighted   0.14   +0.04      0.04        86%   372 |
  |                    IIW   0.09   -0.01      0.04        95%   400 |
  |        IIW + log(test)   0.11   +0.01      0.04        96%   400 |
  |    B        Unweighted   0.15   +0.05      0.04        75%   379 |
  |------------------------------------------------------------------|
  |                    IIW   0.10   +0.00      0.04        96%   400 |
  |        IIW + log(test)   0.12   +0.02      0.04        94%   400 |
  |    C        Unweighted   0.16   +0.06      0.04        74%   379 |
  |                    IIW   0.11   +0.01      0.04        96%   400 |
  |        IIW + log(test)   0.13   +0.03      0.04        92%   400 |
  +------------------------------------------------------------------+

```
