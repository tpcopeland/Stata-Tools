# finegray Performance Benchmarks

`finegray` uses a Mata-native forward-backward scan algorithm (Kawaguchi et al. 2021) as its default estimator. This avoids the data expansion step required by Stata's built-in `stcrreg`, delivering identical point estimates in a fraction of the time.

## Benchmark Results

Simulated competing risks data with 3 covariates. Formal benchmarks (median of 3 replications, 1 core) from the Stata Journal manuscript:

| N | finegray | stcrreg | Speedup |
|------:|----------:|--------:|--------:|
| 500 | 0.04s | 1.5s | **40x** |
| 1,000 | 0.06s | 3.9s | **63x** |
| 2,000 | 0.14s | 15.9s | **114x** |
| 5,000 | 0.27s | 96.8s | **357x** |
| 10,000 | 0.58s | 378.7s | **651x** |

At N=5,000, `finegray` finishes in under a third of a second while `stcrreg` takes over 90 seconds. The gap widens with sample size because `stcrreg` expands the dataset, while the Mata engine operates on the original data.

## Why the Mata engine is faster

`stcrreg` and the `stcrprep` + `stcox` workflow must expand the dataset so that each subject who experiences a competing event gets replicated across all later risk sets with time-dependent weights. This expansion is O(n * number of unique event times), creating datasets 10-100x larger than the original. The Mata engine computes the same weighted partial likelihood directly using a forward-backward scan over the sorted event times, avoiding expansion entirely.

## Numerical accuracy

The Mata engine matches `stcrreg` to machine precision. From the validation suite:

- Coefficients agree to 6+ decimal places
- Log pseudo-likelihoods match exactly
- Model-based SEs (`norobust`) match exactly
- Default robust SEs may differ by 10-15% due to different sandwich estimator implementations

See `../qa/validation_finegray.do` for the full cross-validation against `stcrreg`.

## Running the benchmarks

```stata
do benchmark_finegray.do   // hypoxia dataset (small, real data)
do benchmark_large.do      // simulated data, N = 500 to 5,000
```

Both scripts install `finegray` from the local package directory and log results to `.log` files.
