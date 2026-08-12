# asof QA

The `asof` QA suite is flat and concern-oriented, with functional, known-answer, external-parity, and scaling files driven by one curated runner. Every suite is independently runnable from this directory.

## How to run

```bash
cd asof/qa
stata-mp -b do run_all.do            # full lane (default correctness gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do test_asof_ties.do     # one suite, standalone
```

The benchmark is deliberately separate: `stata-mp -b do run_all.do benchmark`.

## Isolation

`run_all.do` and every suite write logs in `qa/`, so concurrent runs of the same lane can corrupt evidence. Run the lane through `python3 -m _devkit.stata_dev_cli run qa asof --isolated` or from a scratch copy that preserves the repository layout and starts without copied logs.

## Conventions

- `test_*` covers functional and regression behavior; `validation_*` uses hand-computable or brute-force independent oracles; `crossval_*` compares against an independently implemented Python oracle; `benchmark_*` enforces timing shape and is not in a correctness lane.
- Every runnable suite ends with `RESULT: <name> tests=N pass=N fail=N skip=N` and exits nonzero on a failure. The full lane permits no skips.
- Suites sandbox PLUS and PERSONAL under `c(tmpdir)` through `_asof_qa_common.do`, install from the package directory, and never touch the user's real ado tree.
- Paths derive from `c(pwd)` or temporary paths; no suite contains a machine-local repository path.
- Test data are generated at runtime from deterministic inline or seeded builders; no input fixture is tracked.
- Generated logs, datasets, CSV files, and Python caches are gitignored; no QA artifact is part of the package runtime surface.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| `crossval_asof_pandas.do` / `crossval` / `full` | Python 3, pandas, NumPy | Hard failure; install with `pip install --break-system-packages pandas numpy`. |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_asof_syntax.do` | Required syntax, using-data varlist expansion, rule validation, output naming, replacement, sample qualifiers, stored results, and varabbrev restoration. |
| `test_asof_selection.do` | Every direction-by-selection crossing, person-period anchors, and duplicate master keys. |
| `test_asof_windows.do` | Protocol and observability intersections, open bounds, `require()`, inclusive boundaries, and invalid bounds. |
| `test_asof_ties.do` | Equidistant and duplicate-date ties, input-order behavior, and strict tie errors. |
| `test_asof_edge_cases.do` | Unmatched and absent persons, empty using data, extended missings, internal-name exhaustion, strings, sample restriction, and empty keys. |
| `test_asof_types.do` | Numeric and string identifiers, storage formats, `%td`/`%tc` units, incompatible types, and frame sources. |
| `test_asof_install.do` | Installed command/helper discovery, Mata reload, documented workflow, and package metadata presence. |
| `test_asof_examples.do` | Inline synthetic fixtures, exact execution of all three documented workflows, and public-example path hygiene. |

### Validation

| File | Covers |
|---|---|
| `validation_asof_known_truth.do` | Hand-computed rows and gaps, strict anchors, exact parity with a brute-force `joinby` oracle, and eligible-row union counts. |
| `validation_asof_mogad.do` | All eleven MOGAD extraction sites from the build spec, represented by twelve exact single-call assertions because the cleaning site produces both index and last values. |

### Cross-validation

| File | Covers |
|---|---|
| `crossval_asof_pandas.do` + `crossval_asof_pandas.py` | Exact backward and forward parity with `pandas.merge_asof` on shared large fixtures. |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Curated quick, core, crossval, full, and benchmark lanes. |
| `_asof_qa_common.do` | Relocatable sandbox installation bootstrap. |
| `benchmark_asof_scaling.do` | On-demand 10K/100K/1M event shape gate; excluded from correctness lanes. |
| `.gitignore` | Generated-artifact policy. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `asof` | `test_asof_*` | `validation_asof_known_truth.do`, `validation_asof_mogad.do` | `crossval_asof_pandas.do` | `benchmark_asof_scaling.do` |

## Lane membership

`quick` is a subset of `core`, which is a subset of `full`; `full` is the default correctness gate. `crossval` and `benchmark` can also be run independently.

| Lane | Suites |
|---|---|
| `quick` | All `test_asof_*` functional and install suites. |
| `core` | `quick` plus both `validation_asof_*` suites. |
| `crossval` | `crossval_asof_pandas.do`. |
| `full` | `core` plus `crossval`. |
| `benchmark` | `benchmark_asof_scaling.do` only, on demand. |

## False-green checks

Run these manual mutation checks only in disposable scratch copies. Each mutation must make its named suite report at least one failure:

- Force nearest `ties(before)` to select the later date: `test_asof_ties.do`.
- Ignore `range()` bounds: `test_asof_windows.do`.
- Zero-fill unmatched numeric outputs: `test_asof_edge_cases.do`.
- Reverse the recorded using-file order: `test_asof_ties.do`.
- Leak `varabbrev off`: `test_asof_syntax.do`.

Never apply these mutations to the working package.
