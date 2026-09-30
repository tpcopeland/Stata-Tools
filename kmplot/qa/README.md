# kmplot QA
<!-- archetypes: A2(kmplot) -->


The `kmplot` QA suite covers functional behavior, regressions, graph artifacts, published known answers, and survival-estimate recovery. One curated lane runner drives the flat suite, and every test file is independently runnable from this directory.

## How to run

```bash
cd kmplot/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do test_kmplot_v125.do   # one suite standalone
```

Gate on the final `RESULT:` line; the runner exits nonzero when any suite fails.

## Isolation

The runner and suites write logs into `qa/`. Concurrent runs of the same lane require separate scratch copies preserving the repository layout; a disagreement between `run_all.log` and a suite log indicates a collision.

## Conventions

- `test_*` files cover functional and regression behavior; `validation_*` files provide published, hand-computed, invariant, or simulated-truth oracles. `crossval_kmplot_sts.do` compares with native Stata survival commands.
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
| `test_kmplot_v130.do` | Rendered-SVG geometry of the combined risk-table layout across four schemes and three canvas sizes: the main plot's time origin sits on its own y axis, both panels share that origin, row labels clear the time-zero count and the vertical table title, the final count fits inside the graph boundary, and each panel carries the other's label set invisibly. Also pins comma-formatted counts and the helper's margin contract. |

### Validation

| File | Covers |
|---|---|
| `validation_kmplot_recovery.do` | Kaplan–Meier’s published worked example and multi-seed survival recovery under two censoring DGPs. |
| `validation_kmplot.do` | Saved estimates, confidence intervals, medians, risk tables, p-values, and landmark results against independent calculations and Stata survival commands. |

### Cross-validation

| File | Covers |
|---|---|
| `crossval_kmplot_sts.do` | 200 seeded tied-time landmark comparisons against `sts generate`, with independent follow-up support checks. |

### Support

| File | Covers |
|---|---|
| `run_all.do` | Curated `quick`, `core`, and `full` lane runner. |
| `_qa_hostile.do`, `_qa_state.do` | Vendored hostile fixtures and caller-state fingerprints, loaded by v131. |
| `_kmplot_qa_common.do` | Sandboxed local installation and shared artifact assertions. |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---|---|---|---|
| `kmplot` | `test_kmplot.do`, `test_kmplot_errors.do`, `test_kmplot_v124.do`, `test_kmplot_v125.do`, `test_kmplot_v126.do`, `test_kmplot_v127.do`, `test_kmplot_v129.do`, `test_kmplot_v1210.do`, `test_kmplot_v130.do`, `test_kmplot_v131.do` | `validation_kmplot_recovery.do`, `validation_kmplot.do` | `crossval_kmplot_sts.do`; local install and helper auto-load through `_kmplot_qa_common.do` |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate.

| Lane | Suites |
|---|---|
| `quick` | `test_kmplot.do`, `test_kmplot_errors.do` |
| `core` | `quick` plus eight version-regression suites, recovery, and comprehensive validation |
| `full` | `core` plus `crossval_kmplot_sts.do` |

The canonical A2 suite `validation_fixture_truth.do` runs in core/full. Its 40 cases check survival/failure landmarks, Greenwood log-log limits, risk/event/censor tables, medians and log-rank probabilities against independent risk-table calculations, with all A2 life-table hostile variants and positive time scaling. Vendored `_qa_fx_a2.do` and `_qa_hostile.do` match the canonical sources. The new scope covers unweighted two-group curves; weighted and other plotting routes remain covered by existing suites and need fixture adoption.
