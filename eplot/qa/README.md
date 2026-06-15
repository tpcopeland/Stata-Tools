# eplot QA

QA suite for `eplot` — unified effect plotting from data, estimates, matrices, and frames.

## How to run

```stata
cd eplot/qa
stata-mp -b do run_all.do            // full release gate (default)
stata-mp -b do run_all.do quick      // fast functional smoke
stata-mp -b do run_all.do core       // quick + per-feature regressions
```

The runner sandboxes `PLUS`/`PERSONAL` under `c(tmpdir)` (via `_eplot_qa_bootstrap`
in `_eplot_qa_common.do`), installs the package from the parent directory, runs the
lane's suites with a fresh `clear all` between each, and `exit 1` if any suite fails.
Each suite gates itself with `exit 1`, so the runner keys on per-file return codes.

## Conventions

- Every suite is a self-contained `.do` at `qa/` root, runnable standalone.
- Suites are named by concern, not by the release that introduced them; each file's
  header documents which version/bug its checks guard.
- Paths are derived from `c(pwd)` — no machine-local paths.
- `.log`/`.smcl` build artifacts are gitignored, never tracked.

## File index

| File | Concern |
|------|---------|
| `run_all.do` | Curated lane runner (quick/core/full) |
| `_eplot_qa_common.do` | Sandboxed-install bootstrap |
| `test_eplot.do` | Core functional coverage across data + estimates modes and all options |
| `test_options.do` | Broad option/feature surface — multi-model, values, sort/order, matrix, palette, headers, eform+rescale |
| `test_edge_cases.do` | Zero/single/all-missing obs, `noci`, `nodiamonds`, `order()` quoting, abbreviation disambiguation, varabbrev restore |
| `test_eplot_frame.do` | `frame()` input mode (tabtools-companion frames) |
| `test_graph_options.do` | Graph-option passthrough (titles, scheme, region, legend) |
| `test_layout.do` | `gap()` spacing, effect-axis `xlabel()` passthrough, dynamic values-column margin, mode-detection precedence |
| `test_colors_routing.do` | `insigncolor()`, mistyped-estimate routing, in-session rerun safety |
| `test_axis_coeflabels.do` | Default category-axis suppression, `coeflabels()` honored under variable labels, group/model ordering |
| `test_stars_matrix.do` | Stars + `eform` p-values, `type()` special-row filtering, matrix-mode style/stars, weighted-box note, sort alignment |
| `validation_eplot.do` | Known-answer checks — `r(table)`/`r(N)`/`r(k)` against `e(b)`, eform transform |

## Coverage map

| Surface | Covered by |
|---------|-----------|
| Data mode (`eplot es lci uci`) | `test_eplot`, `test_layout`, `test_edge_cases` |
| Estimates mode (`eplot namelist`) | `test_eplot`, `test_options`, `test_colors_routing`, `test_axis_coeflabels` |
| Matrix mode (`matrix()`) | `test_options`, `test_stars_matrix` |
| Frame mode (`frame()`) | `test_eplot_frame` |
| Multi-model comparison | `test_options`, `test_axis_coeflabels` |
| `keep()`/`drop()`/`rename()`/`coeflabels()` | `test_options`, `test_axis_coeflabels`, `validation_eplot` |
| Stars / p-values | `test_stars_matrix`, `validation_eplot` |
| Returns `r(N)`/`r(k)`/`r(n_models)`/`r(table)`/`r(pvalues)` | `validation_eplot`, `test_eplot` |
| Graph passthrough | `test_graph_options`, `test_layout` |
| Error / edge / varabbrev paths | `test_edge_cases`, `test_colors_routing` |

## Lane membership

| Suite | quick | core | full |
|-------|:-----:|:----:|:----:|
| `test_eplot` | ✓ | ✓ | ✓ |
| `test_options` | ✓ | ✓ | ✓ |
| `test_edge_cases` | ✓ | ✓ | ✓ |
| `test_eplot_frame` | | ✓ | ✓ |
| `test_graph_options` | | ✓ | ✓ |
| `test_layout` | | ✓ | ✓ |
| `test_colors_routing` | | ✓ | ✓ |
| `test_axis_coeflabels` | | ✓ | ✓ |
| `test_stars_matrix` | | ✓ | ✓ |
| `validation_eplot` | | | ✓ |
