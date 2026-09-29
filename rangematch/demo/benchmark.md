---
title: "benchmark"
---

## Benchmark: rangematch versus rangejoin

```stata
. display as text "Shared syntax benchmark: key lo hi using file, by(group)."
```

```
Shared syntax benchmark: key lo hi using file, by(group).
```

```stata
. display as text "rangematch uses unmatched(none) and nosort so both commands emit matched pairs without a final order
> guarantee."
```

```
rangematch uses unmatched(none) and nosort so both commands emit matched pairs without a final order guarantee.
```

```stata
. display as text "Times include pair generation and output materialization."
```

```
Times include pair generation and output materialization.
```

```stata
. quietly {
```

```
Running sparse_10k...
Running dense_10k...
Running sparse_100k...
Running dense_100k...
Running sparse_1m...
Running dense_1m...
```

```stata
. list scenario pairs rangematch_sec rangejoin_sec rj_over_rm status,
>     noobs abbreviate(16)
```

```
  +--------------------------------------------------------------------------------+
  |    scenario       pairs   rangematch_sec   rangejoin_sec   rj_over_rm   status |
  |--------------------------------------------------------------------------------|
  |  sparse_10k      10,000            0.092           0.082        0.891       ok |
  |   dense_10k     207,800            0.159           0.174        1.094       ok |
  | sparse_100k     100,000            0.568           0.463        0.815       ok |
  |  dense_100k   1,098,500            0.882           1.326        1.503       ok |
  |   sparse_1m   1,000,000            4.176           4.316        1.034       ok |
  |--------------------------------------------------------------------------------|
  |    dense_1m   2,999,800            5.038           6.868        1.363       ok |
  +--------------------------------------------------------------------------------+
```
