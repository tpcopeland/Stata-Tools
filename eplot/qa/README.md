# eplot QA

The `eplot` QA suite is flat and concern-oriented, covering data, estimates, matrix, and frame inputs through one curated runner. Every suite is independently runnable from this directory.

## How to run

```bash
cd eplot/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do run_all.do core       # functional + regression lane
stata-mp -b do test_eplot_v128.do    # one suite standalone
```

`run_all.do` installs the parent package into sandboxed `PLUS`/`PERSONAL` directories and exits nonzero if any suite fails. All suites run in one Stata process: the runner issues `clear all` between them, which drops data, programs, estimates, matrices, globals, and frames, but process-level settings and the sandboxed `sysdir` entries are deliberately shared. It is a clean session *state*, not a new process.

Each suite must also write a reconcilable `RESULT:` sentinel, which the runner reads back before crediting a pass. A suite that returns zero without a sentinel, or whose sentinel does not satisfy `tests = pass + fail + skip` with `fail = 0`, is reported as failed. Exit status alone is not evidence that a suite's cases ran.

## Isolation

The runner writes suite logs in the active `qa/` directory. Concurrent runs of the same lane can corrupt those logs; use a scratch copy that preserves the repository layout and remove copied `qa/*.log` files before running. A disagreement between `run_all.log` and a suite’s own log is the tell for a collision.

## Conventions

- `test_*` files provide functional and regression checks; `validation_*` files provide known-answer or invariant checks. There is no `crossval_*` layer because `eplot` transforms and renders supplied or Stata-estimated values rather than implementing an external estimator.
- Every suite ends by calling `_eplot_qa_result <name>, tests() pass() fail() skip()`, which prints the canonical `RESULT: <name> tests=N pass=N fail=N skip=N` line, refuses counts that do not reconcile, and records the line for `run_all.do`. Suites exit nonzero on failure; the `full` lane accepts no skips.
- Every suite calls `_eplot_qa_bootstrap` from `_eplot_qa_common.do` before touching `adopath` or installing, so `PLUS`/`PERSONAL` are sandboxed under `c(tmpdir)` in a standalone run too, not only under the runner. No suite writes into the user’s real ado tree.
- Paths derive from `c(pwd)`; no suite contains machine-local paths.
- Test data are generated at runtime from built-in datasets or inline fixtures; no `.dta` fixture is tracked.
- Generated `.log`, `.smcl`, `.dta`, `.xlsx`, `.png`, `.gph`, and `RESULT:` sentinel files are gitignored by `qa/.gitignore`; only reader-facing assets under `demo/` may be tracked.

## File index

### Functional and regression tests

| File | Covers |
|------|--------|
| `test_eplot.do` | Core data and estimates behavior, options, preservation, returns, and targeted-run reporting |
| `test_options.do` | Multi-model, values, sort/order, matrix, palette, headers, and transform options |
| `test_edge_cases.do` | Empty and single samples, missing values, option quoting, abbreviation disambiguation, and varabbrev restoration |
| `test_eplot_errors.do` | Public error codes, caller-state preservation, and graph-file collision behavior across input modes |
| `test_eplot_frame.do` | Graph-ready `frame()` input and companion-variable routing |
| `test_graph_options.do` | Titles, scheme, graph regions, legend, and other graph-option passthrough |
| `test_layout.do` | Group gaps, effect-axis labels, values-column margins, and mode-detection precedence |
| `test_colors_routing.do` | Significance colors, mistyped-estimate routing, and in-session rerun safety |
| `test_axis_coeflabels.do` | Category-axis suppression, coefficient labels, and group/model ordering |
| `test_stars_matrix.do` | Stars, p-values, special row types, matrix styles, weighted markers, and sort alignment |
| `test_selection_labels.do` | Exact `keep()`/`drop()`/`noconstant` row identity in every mode, `coeflabels()` composition with `order()`/`groups()`/`headers()`, `noci` interval-geometry suppression, mode-scoped presentation options, numeric option domains, and weighted-marker weight validity |
| `test_regressions.do` | Analytical return preservation when graph saving fails in each input mode |
| `test_eplot_v128.do` | Multi-equation identity, estimate state, interval validation, option conflicts, interaction messaging, and rendered help |
| `test_eplot_v129.do` | Finite-df inference, immutable coefficient identity, prediction intervals, fail-closed parsing, long labels, exact annotations, and shipped-example regressions |
| `test_examples.do` | Installed-user execution of shipped help examples across all input modes |

### Validation

| File | Covers |
|------|--------|
| `validation_eplot.do` | Known-answer checks for `r(table)`, `r(N)`, `r(k)`, coefficient extraction, and eform transformation |

### Support

| Path | Contents |
|------|----------|
| `run_all.do` | Curated `quick`, `core`, and `full` lane runner |
| `_eplot_qa_common.do` | Sandboxed-install bootstrap shared by the runner and standalone suites |
| `.gitignore` | Generated-artifact policy for the QA directory |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---------|------------|------------|-------------------|
| `eplot` | `test_eplot`, `test_options`, `test_edge_cases`, `test_eplot_frame`, and concern suites | `validation_eplot` | `test_examples`, `test_regressions`, `test_eplot_v128`, `test_eplot_v129` |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate. The explicit suite lists in `run_all.do` are authoritative.

| Lane | Membership |
|------|------------|
| `quick` | Core command, option, and edge-case suites |
| `core` | `quick` plus frame, graph, layout, routing, labels, stars/matrix, selection/labeling, graph-failure, and current-version regression suites |
| `full` | `core` plus known-answer validation and installed documentation examples |

## Known gaps

- The suite validates graph commands, analytical returns, save failures, and representative exports, but it does not perform pixel-level comparison of rendered graphs. Layer-level assertions read the generated `twoway` command in `r(cmd)`; they prove which plot layers and colors were requested, not how the result looks.
- `test_examples.do` recreates the shipped help examples by hand rather than extracting and executing the code blocks from `eplot.sthlp` and `README.md`, so example prose can drift from the executed form.
- Some suites reuse data or estimation state across adjacent cases for narrative continuity, which weakens isolated diagnosis when one of those cases fails.
