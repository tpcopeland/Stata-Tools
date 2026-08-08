# Bootstrap-t R=1,000 gate — n=300

**This is the §10 tier-3 confirmation run** for the bootstrap-t studentized by the
stacked sandwich SE. It applies the preregistered rule: coverage ≥ 0.92 AND 95%
Wilson containing 0.95, at R=1,000, on the registered seed.

| | |
|---|---|
| Run date | 2026-08-08 |
| Probe | `qa/probe_bootstrap_t_screen.do` |
| n | 300 |
| Outer reps | 1,000 (8 shards × 125) |
| Inner draws | 199 per outer rep |
| Seed | 20260715 (registered master, arm 3) |
| Failures | 0 |

## Result

**FAILS.** Coverage **0.916**, Wilson **[0.897, 0.932]** — does not contain 0.95.

| candidate | coverage | note |
|---|---:|---|
| bootstrap-t (stacked studentizer) | 0.916 | best performer; still fails |
| percentile bootstrap | 0.921 | |
| fixed Wald | 0.911 | |
| stacked Wald | 0.892 | |
| **oracle (true SE)** | **0.943** | structural ceiling |

Bootstrap-t median quantiles: q(0.025) = −2.294, q(0.975) = +2.273 (nominal ±1.96).

Sampling distribution: bias/empSD 0.014, SD/IQR-scale 1.049.

## Why no candidate can pass

The oracle covers only **0.943** — even with the true standard error, a Wald
interval does not reach 0.95 at n=300. The deficit is the sampling distribution:
SD/IQR ~1.05, kurtosis ~3.8. The estimator is near-unbiased (bias/empSD 0.014)
and the spread is near-normal, but "near" is not "exact," and at n=300 the
departures are enough that 1.96 is the wrong critical value. The bootstrap-t
finds the right critical value (±2.28) and still falls short, because the
pivot's distribution is not just wider but asymmetric and leptokurtic in a way
that a single scale correction cannot fully absorb.

No variance estimator — however accurate — can close this gap with a symmetric
z-based interval. The gate is structurally unpassable at n=300.

## What passes at n≥600

At n=600 the sampling distribution is near-normal (SD/IQR 1.02, kurtosis 2.9)
and all three candidates pass the screen:

| candidate | n=600 coverage | Wilson contains 0.95? |
|---|---:|---|
| stacked Wald | 0.940 | yes [0.898, 0.965] |
| bootstrap-t | 0.950 | yes [0.910, 0.973] |
| percentile | 0.960 | yes |

At n=1200 the stacked Wald covers 0.960 (Wilson [0.923, 0.980]). No overcoverage
at any sample size.

## Reproducing

```bash
# from isolated scratch copies
for i in $(seq 1 8); do
  FROM=$(( (i-1)*125 + 1 )); TO=$(( i*125 ))
  cd <scratch_$i>/iivw/qa
  stata-mp -b do probe_bootstrap_t_screen.do 300 1000 20260715 $FROM $TO &
done
wait
# combine in a directory containing all 8 .dta files
stata-mp -b do probe_bootstrap_t_screen.do 300 1000 20260715 COMBINE
```
