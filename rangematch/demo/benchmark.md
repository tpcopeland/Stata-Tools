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
. display as text "rangematch runs with unmatched(none) nosort: matched pairs only, in no guaranteed order."
```

```
rangematch runs with unmatched(none) nosort: matched pairs only, in no guaranteed order.
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
. list scenario pairs rangematch_sec rangejoin_sec rj_over_rm status, ///
>     noobs abbreviate(16)
```

```
  +--------------------------------------------------------------------------------+
  |    scenario       pairs   rangematch_sec   rangejoin_sec   rj_over_rm   status |
  |--------------------------------------------------------------------------------|
  |  sparse_10k      10,000            0.151           0.084        0.556       ok |
  |   dense_10k     207,800            0.216           0.345        1.597       ok |
  | sparse_100k     100,000            0.540           0.508        0.941       ok |
  |  dense_100k   1,098,500            1.053           2.365        2.246       ok |
  |   sparse_1m   1,000,000            4.005           4.415        1.102       ok |
  |--------------------------------------------------------------------------------|
  |    dense_1m   2,999,800            5.263          10.012        1.902       ok |
  +--------------------------------------------------------------------------------+
```
