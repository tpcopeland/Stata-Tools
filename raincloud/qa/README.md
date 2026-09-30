# raincloud QA

<!-- archetypes: A1 A7 -->

The `raincloud` QA suite is flat and concern-oriented, with a curated runner and independently runnable functional, regression, release-surface, and known-answer suites.

## How to run

```bash
cd raincloud/qa
stata-mp -b do run_all.do full       # default release gate
stata-mp -b do run_all.do quick      # same compact gate
stata-mp -b do test_regressions.do   # one suite standalone
```

`run_all.do` writes the authoritative terminal `RESULT:` line and `run_all_status.txt`; it exits nonzero when any suite fails.

## Isolation

The runner and suites write logs in `qa/`, so do not run the same package lane concurrently from one checkout. For concurrent or trusted gate runs, use a scratch copy that preserves the repository layout and remove copied `qa/*.log` plus `qa/run_all_status.txt` before starting; disagreement between `run_all.log` and a suite log is evidence of a collision.

## Conventions

- `test_*` covers functional, regression, state, graph, install, and release contracts; `validation_*` uses hand-computed known answers and invariants; `crossval_*` is reserved for an independent external implementation; `benchmark_*` is reserved for timing and never belongs in a correctness lane.
- Every runnable suite ends with `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exits nonzero on failure; the full gate permits no hidden skips.
- Suites sandbox `PLUS` and `PERSONAL` below `c(tmpdir)` through `_raincloud_qa_common.do`, install from the package directory, and leave the user's real ado directories untouched.
- Paths derive from `c(pwd)`; no suite contains a machine-local path.
- Test data come from Stata's built-in `auto` data or are generated in the test block; there are no tracked QA data fixtures.
- Generated logs, status files, graphs, and temporary datasets are gitignored; tracked generated images are documentation assets under `demo/` only.
- The command is a visualization, not a standalone estimator; `validation_raincloud.do` is the numeric oracle, and no external cross-validation layer is claimed.

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_raincloud.do` | Core syntax, options, state restoration, graph structure, weights, install behavior, and edge cases. |
| `test_raincloud_errors.do` | Exact numeric, no-element, empty-sample, and late graph-saving error contracts with data/session/artifact preservation and legal inverses. |
| `test_raincloud_documentation_examples.do` | Every displayed help example, with plotted-sample and group-count assertions. |
| `test_regressions.do` | Long group labels, analytical returns after saving failure, and exact frequency-weight semantics. |
| `test_package_release.do` | Installed command/help resolution, self-contained SMCL rendering with a positive control, and method terminology. |
| `test_fixture_error_returns.do` | Genuine empty/populated scalar/macro/striped-matrix prior r() on named pre-payload refusals; complete caller snapshot compared after logopen/before logclose |
| `test_fixture_global_state.do` | Missing/opaque S_1–S_4 and outside S_5 across actual cloud success, named early198/late602, both varabbrev settings, full state, exact old graph bytes and next native summary. |
| `test_fixture_text_routes.do` | Actual SVG text across nine corpora/five explicit roles, numeric/string groups, both directions and all three layers, raw metadata and defaults, independent finite summaries/native bandwidth, full state, adjacent quotes and nested multiline/suboptions. |
| `test_fixture_files.do` | Canonical friendly/hostile/extensionless native graph writers; actual live graph read-back and complete owned-tree byte preservation. |
| `test_fixture_domains.do` | Eight legal/outside option axes on friendly/permuted canonical data, independent summary/default-bandwidth arithmetic, explicit bandwidth consumption, and sixteen additional named198/full-state refusals. |

### Validation

| File | Covers |
|---|---|
| `validation_raincloud.do` | Hand-computed group statistics, sample restrictions, missingness, constants, and single-observation invariants. |
| `validation_fixture_matrix.do` | Independent weighted mean/variance/percentile formulas for eleven consumed A1 cases and hostile singleton/code/name/missing-value primitives, with exact state fingerprints. |

### Support

| File | Covers |
|---|---|
| `run_all.do` | Curated `quick`/`full` lane runner, suite-level accounting, and status receipt. |
| `_raincloud_qa_common.do` | Temporary ado-directory sandbox and local package installation bootstrap. |
| `README.md` | Contributor runbook, coverage map, and lane documentation. |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---|---|---|---|
| `raincloud` | `test_raincloud.do`, `test_raincloud_errors.do`, `test_raincloud_documentation_examples.do`, `test_regressions.do` | `validation_raincloud.do` | `test_package_release.do` |

## Lane membership

For this compact package, `quick` and `full` intentionally run the same release gate; `full` is the default.

| Lane | Suites |
|---|---|
| `quick` | `validation_fixture_truth.do`, `validation_fixture_matrix.do`, `test_fixture_domains.do`, `test_fixture_global_state.do`, `test_fixture_error_returns.do`, `test_fixture_text_routes.do`, `test_fixture_files.do`, `test_raincloud.do`, `test_raincloud_errors.do`, `test_raincloud_documentation_examples.do`, `test_regressions.do`, `validation_raincloud.do`, `test_package_release.do` |
| `full` | Same curated release gate as `quick` |

Canonical fixture adoption is in progress. `3` cases in `validation_fixture_truth.do` ran with zero failures in an isolated copy; independent review is pending. Three cases check all seven numerical summary columns and the intentionally absent bandwidth for nocloud against exact integer-block formulas. Unsorted and label-gap variants are consumed.

| Added QA file | Role |
|---|---|
| `validation_fixture_truth.do` | Known-answer F/U suite; reached from the package runner |
| `_qa_fx_a7.do` | Byte-for-byte canonical fixture vendor |
| `_qa_fx_a1.do` | Byte-for-byte canonical cross-sectional fixture vendor |
| `_qa_hostile.do` | Byte-for-byte primitive/assertion helper vendor |
| `_qa_state.do` | Byte-for-byte session-fingerprint helper vendor |
| `_qa_metamorphic.do` | Byte-for-byte option-domain helper vendor |

The expanded matrix ran16/16 in an isolated copy. Its oracle precedes the candidate and computes group means, aweight-normalized sample variances and empirical percentiles from fetched native formulas; all seven returned summary columns and the intentionally absent bandwidth are checked. Actual zero/extreme weights, changed group support, missingness and large shifts enter consumed variable/group roles. A friendly graph draw with an exact finite oracle initializes the native graphics environment before the subsequent state fingerprints. Cold native graphics initialization is not claimed to leave all globals untouched.

The domain suite ran2/2, each case sweeping bandwidth, n, opacity, cloudwidth, jitter, seed, boxwidth and gap. Inside cells retain the exact finite summaries and positive bandwidth; automatic bandwidth equals the independent native formula `.9*min(sd,IQR/1.349)*N^(-1/5)` from fetched [R] kdensity pp9–10. Separate explicit bandwidth0/1/2 cells check the consumed return exactly. Each outside axis additionally has a direct named198 refusal and unchanged full-state fingerprint. Style-return invariance does not claim that graph appearance is unchanged.

The new source/QA scopes above await independent root QA inspection; a final integrated lane is pending. Arbitrary KDE geometry/grid equivalence remains outside the finite summaries/native bandwidth and rendered text checks. The A1 `collinear` cell is inapplicable to the single plotted numeric-variable interface: it cannot consume a redundant multi-column design, and modifying an unused column would give a vacuous test. The declaration keeps that census gap visible. Summary arithmetic does not claim regression-coefficient recovery. A green runtime subset does not meet the full census.

Refusals before analytical payload preparation retain genuine empty or populated prior r(). Successful and late output-side calls publish the command’s analytical returns; these paths are checked numerically rather than demanding unchanged prior r(). Earlier cold/global checks omitted rreturn and prove non-r state only.
