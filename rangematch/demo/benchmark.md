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
  |  sparse_10k      10,000            0.072           0.062        0.861       ok |
  |   dense_10k     207,800            0.120           0.331        2.758       ok |
  | sparse_100k     100,000            0.418           0.415        0.993       ok |
  |  dense_100k   1,098,500            0.731           2.231        3.052       ok |
  |   sparse_1m   1,000,000            3.760           4.255        1.132       ok |
  |--------------------------------------------------------------------------------|
  |    dense_1m   2,999,800            4.663           9.867        2.116       ok |
  +--------------------------------------------------------------------------------+
```
