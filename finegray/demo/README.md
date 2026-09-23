# finegray demonstrations and benchmarks

Run the comprehensive demo from the Stata-Tools repository root, from `finegray/`, or from `finegray/demo/` — it resolves the repository root from the invocation's working directory:

```bash
stata-mp -b do finegray/demo/demo_finegray.do
stata-mp -b do demo_finegray.do
```

Graphs use Stata's built-in `sj` scheme with a white outer region and an unboxed legend, the style of the package's Stata Journal figures. The results workbook is built with `table1_tc`, `regtab` and `puttab` from the sibling Stata-Tools package `tabtools`, which needs Stata 17; without `tabtools` or on Stata 16 the workbook is skipped with a note and the rest of the demo still runs.

The demo uses three of Stata's example datasets: `hypoxia` for the main workflow, `hiv_si` (the Amsterdam Cohort data of [ST] `stcrreg` example 4) for grouped cumulative-incidence curves, and `pneumonia` ([ST] `stcrreg` example 5) for the internal time-varying covariate refusal.

It loads the local package and demonstrates the complete public workflow:

- Core estimation, factor variables, `censvalue()`, reporting controls, stratified censoring, cluster-robust inference, and model-based inference
- Default `xb`, CIF, fixed-horizon CIF confidence intervals, cluster-bootstrap intervals, compatible-new-data scoring, and Schoenfeld residuals
- Rank, log-time, and identity-time proportional subdistribution hazards diagnostics
- CIF profiles, fixed horizons, custom time grids, analytic and bootstrap intervals, graph options, and verified `saving()` output
- Grouped CIF curves on `hiv_si`: one `over(ccr5)` call for the fixed-horizon table and the overlaid curves, with the stacked `r(table)` (sixth column `over`) and `saving()` dataset checked against the single-profile calls they are built from
- Multiple-record (`stsplit`) data, string subject identifiers, CIF bootstrap intervals, and coefficient bootstrap inference through a wrapper program that re-runs `stset` on the resampled identifiers
- Delayed entry on a cohort whose entry depends on a model covariate: `truncstrata()` against a pooled entry distribution, matching and cross-classified censoring/entry strata, the posted weight label, and the weight diagnostics
- The internal time-varying covariate refusal on `pneumonia` (`r(198)`), and the subject-constant baseline-exposure fit that is accepted instead
- A stratified baseline subdistribution hazard via `bstrata()`: `e(k_bstrata)`, the widened `e(basehaz)` (`bstratum`, `time`, `cumhazard`), the `bstratum(#)` requirement in `finegray_cif`, and a per-stratum `basecshazard` prediction
- A piecewise-constant time-varying effect via `tvc()` with `tsplit()`: the per-interval equations and event counts, the `test [tvc1]x = [tvc2]x` constancy test, time-dependent `xb` with and without `attime(#)`, a CIF profile accumulated interval by interval, and the mapping onto `stcrreg, tvc() texp()`
- `mi estimate, cmdok eform("SHR"):` on `mi set wide` data, confirming that no package-owned `_fg_*` design column is written to the `mi` dataset, that post-estimation is refused with `r(301)`, and that the same fit on an extracted dataset behaves as usual

Numeric claims in the demo are gated rather than narrated. Agreement with `stcrreg` on `hypoxia` (coefficients, robust standard errors, log pseudo-likelihood) and on `hiv_si`, the `tvc()`/`texp()` parameterization mapping, and the split-record reduction against the single-record fit are each recomputed and asserted, so a regression fails the run instead of printing a wrong number.

The generated documentation artifacts are `finegray_cif.png`, `finegray_bstrata_cif.png` and `finegray_results.xlsx`. The second figure overlays one CIF curve per baseline stratum in a single `finegray_cif, over(pelnode)` call after a `bstrata(pelnode)` fit, with `pelnode` value-labelled (in `hypoxia` it is 1 for negative or equivocal pelvic nodes, so 0 is node-positive) and the curves told apart through `plot#opts()` and `ci#opts()`; each overlaid curve is that stratum's own `bstratum(#)` curve, and the stacked `r(table)` is checked for its column layout. The workbook is written entirely with `tabtools` commands and holds five formatted sheets: `Table 1` (patient characteristics by pelvic node status, `table1_tc`), `SHR models` (four specifications side by side via `collect:` and `regtab`: SHR, 95% CI and p-value, observations and log pseudolikelihood), `CIF time grid` (yearly CIF with 95% limits, `puttab` from the `saving()` dataset), `PH diagnostic` (the `time(log)` residual-time correlations with labelled covariates, `puttab` from a frame), and `CIF by ccr5` (CIF at 2, 5 and 10 years per genotype on `hiv_si`, `puttab`). The demo reopens every sheet and fails if one is missing or empty. The temporary CIF datasets written with `saving()` are checked for row count, bounds, and interval ordering, then removed.

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
