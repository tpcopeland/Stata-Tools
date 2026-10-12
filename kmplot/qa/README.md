# kmplot QA
<!-- archetypes: A2(kmplot) -->


The `kmplot` QA suite covers functional behavior, regressions, graph artifacts, published known answers, and survival-estimate recovery. One curated lane runner drives the flat suite, and every test file is independently runnable from this directory.

## How to run

```bash
cd kmplot/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do run_all.do calibration  # coverage simulation only (~40 min)
stata-mp -b do test_kmplot_v125.do   # one suite standalone
```

Gate on the final `RESULT:` line; the runner exits nonzero when any suite fails.

## Isolation

The runner and suites write logs into `qa/`. Concurrent runs of the same lane require separate scratch copies preserving the repository layout; a disagreement between `run_all.log` and a suite log indicates a collision.

## Conventions

- `test_*` files cover functional and regression behavior; `validation_*` files provide published, hand-computed, invariant, or simulated-truth oracles. `crossval_kmplot_survfit.do` is the external reference (R `survival::survfit`, and `survdiff` for the log-rank p-value on right-censored data, since `survdiff` refuses delayed entry); `crossval_kmplot_sts.do` is a self-consistency check against `sts generate`, the engine `kmplot` itself calls.
- `crossval_kmplot_survfit.do` needs `Rscript` on the PATH with the `survival` package; the help-example smoke in `test_kmplot_v140.do` runs `webuse diet` and needs network access. Neither is skipped when unavailable: the suite fails.
- Every runnable suite ends with `RESULT: <name> tests=N pass=N fail=N` and exits nonzero on failure; `full` permits no skips.
- Suites sandbox `PLUS` and `PERSONAL` under `c(tmpdir)` through `_kmplot_qa_common.do`, then install the local package without touching the user’s ado tree.
- Paths derive from `c(pwd)`; no suite contains a machine-local path.
- Layout assertions in `test_kmplot_v130.do` measure the exported SVG. Text extents are computed from Helvetica advance widths; letters render up to 6% wider than that metric, so letter-based extents are inflated by 10% before being asserted on, and a pass means the clearance is real. Two things the suite cannot cover, and that a layout change should be checked against by hand: raster inspection of the rendered graph, and the `stcolor` scheme, which needs Stata 18 or later.
- Test data use built-in datasets, inline published observations, or seeded runtime generation; no tracked data fixture is required.
- Generated logs, graphs, and datasets are gitignored; only package `demo/` assets may be tracked generated files.

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_kmplot.do` | Core workflows, options, errors, state restoration, exports, saved datasets, and returned results. |
| `test_kmplot_errors.do` | Exact error contracts for unstset data, dependent options, one-group p-values, and unsafe late export paths, with preservation and legal inverses. |
| `test_kmplot_v124.do` | Multiple-record and weighted risk sets, option-dependency errors, and Stata-native help rendering. |
| `test_kmplot_v125.do` | Graph-name isolation and cleanup, custom-color recycling, combined-plot median annotations, and dotted export paths. |
| `test_kmplot_v126.do` | Combined-plot x-axis ordering, risk-table separator, and readable default label sizing. |
| `test_kmplot_v127.do` | Risk-table tick labels and count columns aligned with main-plot x-axis positions. |
| `test_kmplot_v129.do` | Rendered-SVG alignment under two graph layouts, custom axis specifications, and margin reserves for labels and large endpoint counts. |
| `test_kmplot_v1210.do` | Stale in-memory risk-table helper replacement and repeated-call helper reload behavior. |
| `test_kmplot_v131.do` | F1–F8: band coordinates, precise times, support limits, large censor counters, quoted labels, comma titles/paths, pweights; hostile times, the nine-string corpus through all six label options, and state fingerprints. |
| `test_kmplot_v140.do` | 2026-10-12 clarity audit: Okabe-Ito default palette checked under simulated protan/deutan/tritan vision (Machado et al. 2009) and RGB colours at every sink; fractional weighted risk-table cells; `c(level)` default and Stata's level range; every help example run from the installed help file; lifecycle (`qa_lifecycle`, saved-file freshness) and surface parity (`qa_surface_parity`: r(), console, saved data); missing bounds at S = 1 and S = 0; `medianformat()` and tied-data medians against `stci`; the version-literal guard; iweight inference. |
| `test_kmplot_v141.do` | 2026-10-12 final clarity audit: drawn CI band and CI lines carry the last bounds to the time a curve reaches 0 (1 with `failure`), matched to the `sts graph, ci` serset, per group, while returned and saved bounds stay missing there; `riskheight()` requires `risktable`, and `r(riskheight)` is stored only with a drawn table. |
| `test_kmplot_v130.do` | Rendered-SVG geometry of the combined risk-table layout across four schemes and three canvas sizes: the main plot's time origin sits on its own y axis, both panels share that origin, row labels clear the time-zero count and the vertical table title, the final count fits inside the graph boundary, and each panel carries the other's label set invisibly. Also pins comma-formatted counts and the helper's margin contract. |

### Validation

| File | Covers |
|---|---|
| `validation_kmplot_recovery.do` | Kaplan–Meier’s published worked example and multi-seed survival recovery under two censoring DGPs. |
| `validation_kmplot.do` | Saved estimates, confidence intervals, medians, risk tables, p-values, and landmark results against independent calculations and Stata survival commands. |
| `validation_fixture_truth.do` | Canonical A2 fixture: 40 hand-enumerated cases for survival/failure landmarks, Greenwood log-log limits, risk/event/censor tables, medians, and log-rank probabilities, with life-table hostile variants and positive time scaling. |
| `validation_kmplot_calibration.do` | Coverage of the 95% pointwise interval under all three `citransform()` choices at S = .75 and .50, R = 1000 exponential replicates; `smoke` argument runs 25. |

### Cross-validation

| File | Covers |
|---|---|
| `crossval_kmplot_survfit.do` | External reference: R `survival::survfit` (log-log, log and plain CI bounds to 1e-8, counting-process risk sets) on 2 scenarios x 40 replicates x 2 groups with delayed entry, continuous and tied times; estimates, bounds, numbers at risk, and medians (R's plateau-midpoint convention mapped to Stata's plateau start); log-rank p-values against `survdiff` on the same draws with entry times ignored. Script: `crossval_kmplot_survfit.R`. |
| `crossval_kmplot_sts.do` | Self-consistency: 200 seeded tied-time landmark comparisons against `sts generate`, with independent follow-up support checks. |

### Support

| File | Covers |
|---|---|
| `run_all.do` | Curated `quick`, `core`, `full`, and `calibration` lane runner. |
| `test_fixture_domains.do` | Legal and illegal `level()`, `ciopacity()`, `censorthin()`, and `riskheight()` values on canonical life tables, with caller-state fingerprints. |
| `_qa_hostile.do`, `_qa_state.do`, `_qa_metamorphic.do`, `_qa_fx_a2.do`, `_qa_lifecycle.do`, `_qa_parity.do` | Vendored qa-lib helpers (never edited; `check qa kmplot --view vendored`). |
| `_kmplot_qa_common.do` | Sandboxed local installation and shared artifact assertions. |

## Coverage map

| Command | Functional | Validation | Cross-val |
|---|---|---|---|
| `kmplot` | `test_kmplot.do`, `test_kmplot_errors.do`, `test_kmplot_v124.do`, `test_kmplot_v125.do`, `test_kmplot_v126.do`, `test_kmplot_v127.do`, `test_kmplot_v129.do`, `test_kmplot_v1210.do`, `test_kmplot_v130.do`, `test_kmplot_v131.do`, `test_kmplot_v140.do`, `test_kmplot_v141.do`, `test_fixture_domains.do` | `validation_kmplot_recovery.do`, `validation_kmplot.do`, `validation_fixture_truth.do`, `validation_kmplot_calibration.do` | `crossval_kmplot_survfit.do`, `crossval_kmplot_sts.do`; local install and helper auto-load through `_kmplot_qa_common.do` |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate. `calibration` stands alone: run it when the interval code changes and before a release.

| Lane | Suites |
|---|---|
| `quick` | `test_kmplot.do`, `test_kmplot_errors.do` |
| `core` | `quick` plus `validation_fixture_truth.do`, `test_fixture_domains.do`, ten version-regression suites (v124-v141), recovery, and comprehensive validation |
| `full` | `core` plus `crossval_kmplot_sts.do` and `crossval_kmplot_survfit.do` |
| `calibration` | `validation_kmplot_calibration.do` only (about 40 minutes). Kept out of `full` because the bounds it calibrates are pinned exactly: closed form for all three transforms in `validation_kmplot.do` (V2, V2b) and R `survfit` log-log, log and plain bounds to 1e-8 in `crossval_kmplot_survfit.do`. |

## Evidence layers

One row per estimator route. Cells name files only; `check qa kmplot --view evidence` derives each state from lane membership and the `run qa` receipts. Risk-table counts and medians are deterministic functions of the risk sets and the KM curve, so they owe no calibration.

| Route | Recovery | Reference parity | Published reproduction | Inference calibration |
|---|---|---|---|---|
| KM survival / cumulative failure estimate (`landmark()`, `saving()`) | `validation_kmplot_recovery.do` | `crossval_kmplot_survfit.do`; `crossval_kmplot_sts.do` | `validation_kmplot_recovery.do` | none: no inference reported |
| Pointwise confidence interval (`ci`, `citransform()`, `level()`) | `validation_fixture_truth.do` | `crossval_kmplot_survfit.do` | none: paper publishes no worked example | `validation_kmplot_calibration.do` |
| Number at risk, events, censoring (`risktable`, `risksaving()`) | `validation_fixture_truth.do` | `crossval_kmplot_survfit.do` | none: paper publishes no worked example | none: deterministic transform |
| Median (`median`) | `validation_fixture_truth.do` | `crossval_kmplot_survfit.do` | none: paper publishes no worked example | none: no inference reported |
| Log-rank p-value (`pvalue`) | `validation_fixture_truth.do` | `crossval_kmplot_survfit.do` | none: paper publishes no worked example | none: deterministic transform of the `sts test` chi-squared, whose type I error is Stata's (parity with R survdiff is in the Reference parity column) |

The canonical A2 suite `validation_fixture_truth.do` runs in core/full. Its 40 cases check survival/failure landmarks, Greenwood log-log limits, risk/event/censor tables, medians and log-rank probabilities against independent risk-table calculations, with all A2 life-table hostile variants and positive time scaling. Vendored `_qa_fx_a2.do` and `_qa_hostile.do` match the canonical sources. The new scope covers unweighted two-group curves; weighted and other plotting routes remain covered by existing suites and need fixture adoption.

`test_fixture_domains.do` runs in core/full. Friendly and unsorted canonical life tables check legal and illegal `level()`, `ciopacity()`, `censorthin()`, and `riskheight()` values. Inside controls retain the independently enumerated KM estimates and Greenwood limits at the requested level; each outside axis additionally has a direct named r(198) refusal with a complete caller-state fingerprint. Vendored `_qa_metamorphic.do` 1.1.1 and `_qa_state.do` 1.0.2 preserve the live estimation context in option cells.
