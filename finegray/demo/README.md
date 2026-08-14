# finegray demonstrations and benchmarks

Run the comprehensive demo from the Stata-Tools repository root:

```bash
stata-mp -b do finegray/demo/demo_finegray.do
```

The demo prefers the `tc_schemes` graph scheme (`plotplainblind`), a sibling Stata-Tools package. If `tc_schemes/` is not present in the checkout it falls back to `s2color`; only the graph cosmetics differ and the numeric demo is unaffected.

The demo loads the local package and demonstrates the complete public workflow:

- Core estimation, factor variables, `censvalue()`, reporting controls, stratified censoring, cluster-robust inference, and model-based inference
- Default `xb`, CIF, fixed-horizon CIF confidence intervals, cluster-bootstrap intervals, compatible-new-data scoring, and Schoenfeld residuals
- Rank, log-time, and identity-time proportional subdistribution hazards diagnostics
- CIF profiles, fixed horizons, custom time grids, analytic and bootstrap intervals, graph options, and verified `saving()` output
- Multiple-record (`stsplit`) data, delayed entry, and bootstrap inference with string subject identifiers

The generated documentation artifact is `finegray_cif.png`. The temporary CIF dataset is checked for row count, bounds, interval ordering, and summary content, then removed.

## Performance benchmarks

`finegray` uses a Mata-native forward-backward scan algorithm (Kawaguchi et al. 2021) that avoids the data expansion the other two Fine-Gray paths in Stata require.

### The three comparators

| Path | How it fits Fine-Gray |
|---|---|
| `finegray` | Mata forward-backward scan over the original rows; no expansion |
| `stcrreg` | Stata's built-in; forms the weighted risk sets internally at every iteration |
| `stcrprep` + `stcox` | [`stcrprep`](https://ideas.repec.org/c/boc/bocode/s457821.html) (Lambert, SSC) expands the data once with time-dependent censoring weights, then a weighted `stcox` on the expanded rows returns the Fine-Gray fit |

`stcrprep` is not shipped with Stata. Both benchmark scripts install it on demand:

```stata
capture which stcrprep
if _rc ssc install stcrprep, replace
```

The `stcrprep` pipeline is timed two ways, because the two answer different questions:

- **`stcrprep` + `stcox` (total)** — the expansion, the re-`stset` that carries the weights, and the Cox fit. This is what *one* Fine-Gray fit costs from a standing start, and is the column comparable to a single `finegray` or `stcrreg` call.
- **`stcox` alone** — what a *second* model on the same expanded weights costs. `stcrprep`'s design goal is that the weights are computed once and reused across several models, so charging every model the expansion would understate it.

### Results

Simulated competing-risks data, three covariates, one cause of interest and one competing event. Median of three timed runs after one untimed warm-up, measured on Linux x86-64 under Stata 17 with `c(processors)` = 16. Absolute seconds are machine-dependent; the speedup ratios are the portable quantity.

| N | finegray | stcrreg | stcrprep + stcox | stcox alone | vs `stcrreg` | vs `stcrprep` |
|------:|---------:|---------:|-----------------:|------------:|-------------:|--------------:|
| 109 (hypoxia) | 0.009s | 0.045s | 0.020s | 0.006s | **5.0x** | **2.2x** |
| 500 | 0.031s | 1.279s | 0.130s | 0.034s | **41.3x** | **4.2x** |
| 1,000 | 0.049s | 3.160s | 0.353s | 0.126s | **64.5x** | **7.2x** |
| 2,000 | 0.087s | 11.835s | 1.635s | 0.520s | **136.0x** | **18.8x** |
| 5,000 | 0.214s | 76.496s | 14.848s | 5.896s | **357.5x** | **69.4x** |
| 10,000 | 0.358s | 334.140s | 76.550s | 35.374s | **933.4x** | **213.8x** |

Reading the table:

- **`stcrreg` is the wrong baseline to stop at.** It is the slowest of the three by a wide margin, and the gap grows superlinearly because it rebuilds weighted risk sets on every iteration. The `stcrprep` column is the honest competitor.
- **`stcrprep` + `stcox` is much closer than `stcrreg`, and still loses at scale.** The expansion is the cost, and it grows far faster than N: 78,407 weighted rows at N=2,000, 487,458 at N=5,000, and 1,790,932 at N=10,000. Every subsequent operation pays for them.
- **Even amortized, the expansion does not disappear.** The `stcox alone` column — the best case for `stcrprep`, where the expansion is already paid for and reused — is still slower than a *complete* `finegray` fit from N=1,000 upward: 0.126s vs 0.049s at N=1,000, 5.896s vs 0.214s at N=5,000, and 35.374s vs 0.358s at N=10,000. Fitting on the expanded rows costs more than scanning the original ones, however the weights were obtained.
- **At small N the picture is different and worth stating plainly.** On the 109-subject `hypoxia` data every path finishes in hundredths of a second, and the ranking is dominated by fixed overhead rather than algorithmic cost. The speedups there are real but not the reason to choose a command.

The three commands are fitting the same model, not merely similar ones: both scripts recompute the maximum relative coefficient difference across the three fits and print it beside the timings. It is 4.6e-11 on `hypoxia` and between 1.3e-08 and 3.2e-08 across the simulated sizes.

The validation suite cross-checks coefficients, log pseudo-likelihoods, model-based standard errors, robust standard errors, CIFs, baseline hazards, and post-estimation predictions against `stcrreg`, `cmprsk`, and `riskRegression`; see [`../qa/README.md`](../qa/README.md).

### Reproducing

Run the timing scripts from the repository root:

```bash
stata-mp -b do finegray/demo/benchmark_finegray.do
stata-mp -b do finegray/demo/benchmark_large.do
```

The first uses Stata's `hypoxia` data (N=109). The second generates fixed-seed samples from N=500 through N=10,000. Runtime varies by machine, Stata version, and current load — run them on an otherwise idle machine, since the `stcrreg` column in particular is long enough to pick up any competing work.
