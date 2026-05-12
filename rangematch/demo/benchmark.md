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
  |  sparse_10k      10,000            0.072           0.154        2.139       ok |
  |   dense_10k     207,800            0.161           0.152        0.944       ok |
  | sparse_100k     100,000            0.382           0.435        1.139       ok |
  |  dense_100k   1,098,500            0.772           1.081        1.400       ok |
  |   sparse_1m   1,000,000            2.953           4.245        1.438       ok |
  |--------------------------------------------------------------------------------|
  |    dense_1m   2,999,800            3.937           5.781        1.468       ok |
  +--------------------------------------------------------------------------------+

```
