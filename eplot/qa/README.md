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
- Every `test_*` suite calls `_eplot_qa_bootstrap` from `_eplot_qa_common.do` before installing, so `PLUS`/`PERSONAL` are sandboxed under `c(tmpdir)` in a standalone run too, not only under the runner. `validation_eplot_precision.do` and `validation_eplot_fixture_contract.do` do not: they put the package directory on the path with `adopath ++` (the code under test is the working tree, and nothing is installed or uninstalled), so a standalone run leaves the user's `PLUS`/`PERSONAL` in place but writes nothing into them. `validation_eplot.do` calls the bootstrap; `_qa_fx_a6.do` and `_qa_state.do` are fixture helpers included by those two validation suites (the first by both, the second by the fixture-contract suite) and have no bootstrap of their own.
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
| `test_selection_labels.do` | Exact `keep()`/`drop()`/`noconstant` row identity in every mode, `coeflabels()` composition with `order()`/`groups()`/`headers()`, `noci` interval-geometry suppression, mode-scoped presentation options, numeric option domains, weighted-marker weight validity, and package-owned axis scaling |
| `test_regressions.do` | Analytical return preservation when graph saving fails in each input mode |
| `test_eplot_v128.do` | Multi-equation identity, estimate state, interval validation, option conflicts, interaction messaging, and rendered help |
| `test_eplot_v129.do` | Finite-df inference, immutable coefficient identity, prediction intervals, fail-closed parsing, long labels, exact annotations, and shipped-example regressions |
| `test_eplot_v140.do` | Logarithmic effect axis: multiplicative range padding, decade tick lattice and its linear fallback, non-positive value/`null()`/`xline()` refusals, the `xscale()`/`yscale()` passthrough guard, and `logscale` across all four modes and both orientations |
| `test_eplot_v142.do` | Matrix row-stripe identity (names with spaces, repeated names with equation prefixes), absence of unavailable `r()` results on success and error paths, zero- versus tiny-variance coefficients, parameter-specific degrees of freedom (`e(df_mi)`, `mixed, dfmethod()`) against Stata's own coefficient table, shared weighted-box scale under `sigcolors` (read from the graph sersets), `eform` axis titles from `e(cmd2)`, `null(-999)`, estimates-mode console output, and drawn layer colors read from the graph object (multi-model `mcolor()`/`cicolor()` lists and refusals, RGB colors in every mode, preset colors yielding to the palette), refusal of multi-color or unknown color values in every mode, acceptance of every documented single-color form, and a scan of the suite's own log for twoway's unknown-style note |
| `test_eplot_v150.do` | Values-column text styling (`vsize()`, `vcolor()`, `labsize()`, `*#` resolution, margin widening, refusals), `xscale()`/`yscale()` style passthrough read from the drawn axis with geometry suboptions (including `nolog`/`noreverse` and repeated options) still refused, grid suppression under a user `xlabel()` against a grid-drawing scheme written by the suite, `nogrid`, labelled `xline()` lines in every mode and both orientations, `favors()` `ends`/`below`/`arrows` placement and the off-range-null fallback, `vtitle()`, and "Not estimated" text for type 2 rows (`vmissing()`, string `reference` rows left blank, frame forwarding), with drawn text read back from SVG exports; also the effect range widened to every numeric tick of a user `xlabel()` or the decade lattice (log and linear, all modes), the values column anchored past the last tick when `xlabel()` carries suboptions, bare-number `vsize()`/`labsize()` without spurious error output, labelled lines placed above the values header, RGB `vcolor()` in estimates and matrix modes, and `xlabel(, suboptions)` grid handling |
| `test_eplot_v151.do` | `eform` against Stata's own `r(table)` eform row (ologit, nbreg, streg, melogit, mlogit with `e(k_eform)`), omission of `/`-equation ancillary parameters and their p-values, active results posted without `e(cmd)` surviving `eplot m1` and accepted by `eplot .`, `rename()` collisions within a model (r(198)) versus alignment across models, `coeflabels()` that equal another coefficient's name, `vformat()` refusal in data, estimates and matrix modes, no spurious constant note, `logscale` with a nonpositive point estimate or `xlabel()` tick, frame-mode `in` checked against the source frame, the effect range reaching an `xline()` outside the data, and the note for a null line outside the data range (silenced by `nonull` or an `xline()` at the null) |
| `test_eplot_v160.do` | `favors()` placement (anchored at the null since 1.6.1; log and linear, `below` and inside the plot) and drawn in the tick-label size, `size()`/`color()`/`gap()` suboptions and their refusals, the `ends` fallback when the null sits on a tick-span end, `effect(, atnull)` placing the title on the null below the favors row with even spacing in data, estimates, and matrix modes, vertical layout, and `graph combine`, its off-axis-null fallback, `xtitle()` text refusal and default label, the values-mode axis line stopping at the last tick with `xscale()` line styling (including two-letter abbreviations) forwarded, `atnull` through `frame()`, multi-model, and `nonull`; and the design-review items: `eform` with `rescale()` (exp(k*b)) in every mode and the PI path, block-wise `sort` with headers, pooled rows, and `groups()`, the off-axis null line, `favors()` widening to the null, `noci` range, `plotregion()` merge, repeated `xline()` validation and styling, `null(#, line_options)`, `baselevels`/`vreference()` with `r(k)`/`r(table)` unchanged, `diamondcolor()`, data-mode `level()`, `order()` typos, the multi-model `offset()` cap, `export()` round-trip and clash refusals, symmetric narrow log ticks, `hetrow`, `xline()` label placement and styling, and the default title under `values`; positions read back from SVG exports |
| `test_eplot_v161.do` | `favors()` labels anchored at the null: the left label's right edge and the right label's left edge measured `gap()` from the null (label half-widths from a same-size calibration graph) for long and short labels, ticks 0.8-1.6 and 0.1-5, log and linear axes, `gap()` values, `graph combine`, and the estimates and matrix modes; `below` rows spaced from the scheme's axis metrics (s2color, economist's inward ticks) and `size()`; the centred and `atnull` titles kept below the row with even steps; unboxed inside rows; the zero bottom plot-region margin including named margins; `gap()` refusals; the inside-row fallback with a note for rotated or multi-line tick labels and absolute-unit sizes; the room kept under a passed-through `xtitle("")`; positions read back from SVG exports |
| `test_eplot_v162.do` | `mixed` with `dfmethod(kroger)` and `dfmethod(satterthwaite)`: `ll`, `ul`, and p-values against Stata's own `r(table)` to 1e-8; `keep()` and `drop()` naming nothing exit `r(198)` in estimates, data, and matrix modes, `eq:name` selects exactly one matrix row, and a multi-model term present in one model does not error; `values` text at `dp(5)`, `dp(8)`, `dp(0)` compared with `string(round(x, 10^-dp), "%.dpf")` computed in the suite (estimates against `r(table)`, matrix and data against constants), and a rounded negative zero printed `0.00`, read from `export()`; matrix `coeflabels()` applied after `order()`; `groups()` members directly under their header and a coefficient in two groups refused; data-mode `values vcolor("0 128 0")` with `export()`; the `cnsreg` constrained-coefficient note, read back from a log; no missing-values text from `order()`; `logscale` over sixteen decades giving at most twelve decade ticks parsed from `r(cmd)`; `rename()` swaps against `e(b)` and same-name collisions; no leak of the caller's `r()` in frame mode; `drop(_cons)` accepted on `stcox`, `regress, noconstant`, and data mode without a `_cons` row while `drop(nosuch)` still exits 198; `drop()` of a coefficient already removed by `keep()`, a base level without `baselevels`, or a constrained-omitted coefficient; values rounding half away from zero on decimal ties (0.125, 2.675, 1.005, negatives, `dp(0)`) as hand-written strings; the constrained-coefficient note text; and one notation per values cell when numbers overflow the fixed format (e-notation for a 1e22 row, fixed for 1e12) |
| `test_eplot_v170.do` | Data and frame rows with a missing estimate or interval named in a note (labels or observation numbers, five then a count, inside `if`/`in` only, structural `type()` rows never named) read back from a captured log; one missing limit refused with `r(198)` naming the rows in data and frame modes; multi-model `msymbol()` lists in model order, a single symbol for all, the unchanged default, count refusals, and a `style()` preset; the hostile-string corpus drawn verbatim from `labels()`, and variable/value labels holding a backtick and `$name` drawn, exported, and read back through `frame()` exactly, read from SVG exports; the `eform` axis title for 16 estimation commands against the exponentiated-column header of each command's own replayed table, and the generic title for an `exp(b)` column |
| `test_adversarial.do` | qa-lib adversarial axes: session fingerprint on three error paths (unknown option, one-limit refusal, `msymbol()` count) and a success path with a noted row; lifecycle of `eplot .` across an overwritten and restored fit; surface parity of the estimate and both limits across `r(table)`, the `export()` frame, and its values text against `regress`'s own `r(table)`; the hostile-string corpus through `labels()` and the missing-row note; non-decimal doubles carried exactly through data and matrix modes |
| `test_examples.do` | Installed-user execution of shipped help examples across all input modes, with assertions on `r()` |
| `test_help_examples.do` | Every `. command` line of the `eplot.sthlp` Examples section, extracted and run in order (16 examples), and every runnable README `stata` block (7; install blocks and blocks with elided data skipped by rule), with the counts pinned |

### Validation

| File | Covers |
|------|--------|
| `validation_eplot.do` | Known-answer checks for `r(table)`, `r(N)`, `r(k)`, coefficient extraction, and eform transformation |
| `validation_eplot_precision.do` | Named raw coefficients, intervals, and p-values near zero and one across the data, frame, matrix, and stored-estimate routes |
| `validation_eplot_fixture_contract.do` | Canonical A6 fixture truth and hostile contracts (case and 32-character twins, restored estimates, missing-bound refusals, factor labels) |

### Support

| Path | Contents |
|------|----------|
| `run_all.do` | Curated `quick`, `core`, and `full` lane runner |
| `_eplot_qa_common.do` | Sandboxed-install bootstrap and `RESULT:` sentinel writer shared by the runner and standalone suites |
| `_qa_fx_a6.do` | Vendored qa-lib A6 fixture generator (estimates matrices with a known truth table) |
| `_qa_state.do` | Vendored qa-lib session fingerprint (`qa_state_snapshot` / `qa_state_compare`) |
| `_qa_hostile.do` | Vendored qa-lib hostile fixtures and strings (`qa_hostile_times`, `qa_hostile_strings`, `qa_assert_equal`) |
| `_qa_lifecycle.do` | Vendored qa-lib lifecycle probe (`qa_lifecycle`) |
| `_qa_parity.do` | Vendored qa-lib surface parity probe (`qa_surface_parity`) |
| `receipts/` | Per-suite run receipts written by `run qa` |
| `.gitignore` | Generated-artifact policy for the QA directory |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---------|------------|------------|-----------|-------------------|
| `eplot` | `test_eplot`, `test_options`, `test_edge_cases`, `test_eplot_frame`, and concern suites | `validation_eplot`, `validation_eplot_precision`, `validation_eplot_fixture_contract` | `test_eplot_v142`, `test_eplot_v151`, `test_eplot_v162` | `test_examples`, `test_help_examples`, `test_adversarial`, `test_regressions`, `test_eplot_v128`, `test_eplot_v129`, `test_eplot_v140`, `test_eplot_v142`, `test_eplot_v150`, `test_eplot_v151`, `test_eplot_v160`, `test_eplot_v161`, `test_eplot_v162`, `test_eplot_v170` |

The Cross-val column names the suites whose oracle is Stata's own coefficient table (`r(table)` after the estimation command), the maintained reference implementation for every interval `eplot` constructs.

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate. The explicit suite lists in `run_all.do` are authoritative.

| Lane | Membership |
|------|------------|
| `quick` | Core command, option, and edge-case suites |
| `core` | `quick` plus frame, graph, layout, routing, labels, stars/matrix, selection/labeling, graph-failure, version regression suites, and the qa-lib adversarial suite |
| `full` | `core` plus known-answer validation, the fixture contract, and the installed and extracted documentation examples |

## Evidence layers

`eplot` estimates no parameter of its own: it builds Wald intervals and p-values from posted `e(b)`/`e(V)` (or a supplied standard error) and plots supplied limits as given. Its known truth is Stata's own coefficient table, so recovery is checked against fixture truth tables and parity against `r(table)` from the estimation command.

| Route | Recovery | Reference parity | Published reproduction | Inference calibration |
|---|---|---|---|---|
| `eplot` estimates mode, Wald interval and p-value from `e(b)`/`e(V)` (t with `e(df_r)`, `e(df_mi)`, or `e(df)`; normal otherwise) | `validation_eplot_precision.do`; `validation_eplot.do` | `test_eplot_v142.do`; `test_eplot_v151.do`; `test_eplot_v162.do` | `none: no grounding paper (the intervals reproduce Stata's own ereturn display, which is the reference)` | `none: deterministic transform` |
| `eplot` matrix mode, normal interval from a 2-column (b, se) matrix | `validation_eplot_precision.do`; `validation_eplot_fixture_contract.do` | `none: deterministic transform` | `none: no grounding paper (a normal-approximation interval from a supplied standard error)` | `none: deterministic transform` |
| `eplot` data, frame, and 3-column matrix modes, supplied limits plotted as given | `validation_eplot_fixture_contract.do` | `none: deterministic transform` | `none: no grounding paper (no interval is computed)` | `none: deterministic transform` |

## Known gaps

- The suite validates graph commands, analytical returns, save failures, and representative exports, but it does not perform pixel-level comparison of rendered graphs. Layer-level assertions read the generated `twoway` command in `r(cmd)`; they prove which plot layers and colors were requested, not how the result looks.
- `test_help_examples.do` runs the help and README examples as written but asserts only that they run; the value checks on those examples live in `test_examples.do`, which retypes them.
- The Stata 16 minimum is not exercised: only Stata 17 is installed where this suite is run.
- Some suites reuse data or estimation state across adjacent cases for narrative continuity, which weakens isolated diagnosis when one of those cases fails.

archetypes: A6(eplot)

## Canonical fixture adoption

Exact coefficient and interval identity across data/matrix/estimates/frame modes; case and 32-character twins, restored estimates, missing bounds refusals and factor labels. These are implemented suites; independent adoption signoff is pending. Remaining unexercised public routes and generic minima remain visible in the fixture census.

| File | Coverage | Lanes |
| --- | --- | --- |
| `validation_eplot_precision.do` | Named raw coefficients, intervals and p-values near zero/one across data, frame, matrix and stored-estimate routes | full |
| `validation_eplot_fixture_contract.do` | Canonical fixture truth and hostile contracts | full |
