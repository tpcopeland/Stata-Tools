# finegray Performance Benchmarks

`finegray` uses a Mata-native forward-backward scan algorithm (Kawaguchi et al. 2020) as its default estimator. This avoids the data expansion step required by `stcrprep` + `stcox` and Stata's built-in `stcrreg`, delivering identical point estimates in a fraction of the time.

## Benchmark Results

Simulated competing risks data with 3 covariates, ~50% cause 1, ~30% cause 2, ~20% censored. Timings from Stata/MP on a single run.

| N | finegray (default) | wrapper mode | stcrreg | Speedup vs stcrreg |
|------:|-------------------:|-------------:|--------:|-------------------:|
| 500 | 0.12s | 0.30s | 1.50s | **13x** |
| 1,000 | 0.05s | 0.67s | 2.94s | **59x** |
| 2,000 | 0.12s | 2.73s | 11.21s | **93x** |
| 5,000 | 0.37s | 17.97s | 65.37s | **177x** |

At N=5,000, `finegray` finishes in under half a second while `stcrreg` takes over a minute. The gap widens with sample size because `stcrreg` and the wrapper both expand the dataset (487,458 pseudo-observations at N=5,000), while the Mata engine operates on the original data.

## Why the Mata engine is faster

`stcrreg` and the `stcrprep` + `stcox` workflow must expand the dataset so that each subject who experiences a competing event gets replicated across all later risk sets with time-dependent weights. This expansion is O(n * number of unique event times), creating datasets 10-100x larger than the original. The Mata engine computes the same weighted partial likelihood directly using a forward-backward scan over the sorted event times, avoiding expansion entirely.

## Numerical accuracy

The Mata engine matches `stcrreg` to machine precision. From the validation suite (61 tests):

- Coefficients agree to 6+ decimal places
- Log pseudo-likelihoods match exactly
- Standard errors are within numerical tolerance

See `../qa/validation_finegray.do` for the full cross-validation against `stcrreg`.

## When to use wrapper mode

The default Mata engine handles the vast majority of use cases. Use `wrapper` mode only when you need:

- **`tvc(varlist)`** — time-varying coefficients (testing proportional subdistribution hazards)
- **`strata(varlist)`** — stratified baseline hazards

These features require the underlying `stcox` engine and are automatically activated when specified:

```stata
* Default: Mata engine (fast)
finegray x1 x2 x3, events(status) cause(1)

* Wrapper mode: explicit
finegray x1 x2 x3, events(status) cause(1) wrapper

* Wrapper mode: automatic (tvc triggers it)
finegray x1 x2 x3, events(status) cause(1) tvc(x1)
```

## Running the benchmarks

```stata
do benchmark_finegray.do   // hypoxia dataset (small, real data)
do benchmark_large.do      // simulated data, N = 500 to 5,000
```

Both scripts install `finegray` from the local package directory and log results to `.log` files.
