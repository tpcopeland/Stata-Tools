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
  |  sparse_10k      10,000            0.098           0.067        0.684       ok |
  |   dense_10k     207,800            0.163           0.147        0.902       ok |
  | sparse_100k     100,000            0.431           0.457        1.060       ok |
  |  dense_100k   1,098,500            0.887           1.154        1.301       ok |
  |   sparse_1m   1,000,000            3.425           3.930        1.147       ok |
  |--------------------------------------------------------------------------------|
  |    dense_1m   2,999,800            4.474           7.344        1.641       ok |
  +--------------------------------------------------------------------------------+
```
