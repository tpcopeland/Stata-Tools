# finegray demonstrations and benchmarks

Run the comprehensive demo from the Stata-Tools repository root:

```bash
stata-mp -b do finegray/demo/demo_finegray.do
```

The demo installs the local package and demonstrates the complete public workflow:

- Core estimation, factor variables, `censvalue()`, reporting controls, stratified censoring, cluster-robust inference, and model-based inference
- Default `xb`, CIF, fixed-horizon CIF confidence intervals, cluster-bootstrap intervals, compatible-new-data scoring, and Schoenfeld residuals
- Rank, log-time, and identity-time proportional subdistribution hazards diagnostics
- CIF profiles, fixed horizons, custom time grids, analytic and bootstrap intervals, graph options, and verified `saving()` output
- Multiple-record (`stsplit`) data, delayed entry, and bootstrap inference with string subject identifiers

The generated documentation artifact is `finegray_cif.png`. The temporary CIF dataset is checked for row count, bounds, interval ordering, and summary content, then removed.

## Performance benchmarks

`finegray` uses a Mata-native forward-backward scan algorithm (Kawaguchi et al. 2021) that avoids the data expansion required by Stata's built-in `stcrreg`.

Formal benchmarks from the Stata Journal manuscript used simulated competing-risks data with three covariates (median of three replications, one core):

| N | finegray | stcrreg | Speedup |
|------:|----------:|--------:|--------:|
| 500 | 0.04s | 1.5s | **40x** |
| 1,000 | 0.06s | 3.9s | **63x** |
| 2,000 | 0.14s | 15.9s | **114x** |
| 5,000 | 0.27s | 96.8s | **357x** |
| 10,000 | 0.58s | 378.7s | **651x** |

The validation suite cross-checks coefficients, log pseudo-likelihoods, model-based standard errors, robust standard errors, CIFs, baseline hazards, and post-estimation predictions against `stcrreg`, `cmprsk`, and `riskRegression`; see [`../qa/README.md`](../qa/README.md).

Run the reproducible timing scripts from the repository root:

```bash
stata-mp -b do finegray/demo/benchmark_finegray.do
stata-mp -b do finegray/demo/benchmark_large.do
```

The first uses Stata's `hypoxia` data. The second generates fixed-seed samples from N=500 through N=5,000. Runtime varies by machine, Stata version, and current load; the manuscript table above is retained as the fixed reference rather than overwritten by a single local run.
