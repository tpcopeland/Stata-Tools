# raincloud QA

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
| `test_regressions.do` | Long group labels, analytical returns after saving failure, and exact frequency-weight semantics. |
| `test_package_release.do` | Installed command/help resolution, self-contained SMCL rendering with a positive control, and method terminology. |

### Validation

| File | Covers |
|---|---|
| `validation_raincloud.do` | Hand-computed group statistics, sample restrictions, missingness, constants, and single-observation invariants. |

### Support

| File | Covers |
|---|---|
| `run_all.do` | Curated `quick`/`full` lane runner, suite-level accounting, and status receipt. |
| `_raincloud_qa_common.do` | Temporary ado-directory sandbox and local package installation bootstrap. |
| `README.md` | Contributor runbook, coverage map, and lane documentation. |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---|---|---|---|
| `raincloud` | `test_raincloud.do`, `test_regressions.do` | `validation_raincloud.do` | `test_package_release.do` |

## Lane membership

For this compact package, `quick` and `full` intentionally run the same release gate; `full` is the default.

| Lane | Suites |
|---|---|
| `quick` | `test_raincloud.do`, `test_regressions.do`, `validation_raincloud.do`, `test_package_release.do` |
| `full` | Same curated release gate as `quick` |
