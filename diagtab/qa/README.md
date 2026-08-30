# diagtab QA

The `diagtab` QA suite is flat and concern-oriented, with functional, error-contract, documentation-example, oracle, and known-answer suites driven by a curated runner. Each suite is independently runnable from this directory.

## How to run

```bash
cd diagtab/qa
stata-mp -b do run_all.do          # full lane (default release gate)
stata-mp -b do run_all.do quick    # functional lane
stata-mp -b do test_diagtab.do     # one suite standalone
```

The devkit can run the same gate in an isolated scratch copy with `python3 -m _devkit.stata_dev_cli run qa diagtab --repo tools --isolated`.

## Isolation

The runner writes suite logs in `qa/`; concurrent runs of the same lane can collide. Use the devkit's isolated mode, or a scratch copy preserving the repository layout, for a trusted lane result.

## Conventions

- `test_*` files cover functional and regression behavior; `validation_*` files use known-answer and invariant oracles.
- Every suite ends with `RESULT: <name> tests=N pass=N fail=N` and exits nonzero on failure.
- `run_all.do` sandboxes `PLUS` and `PERSONAL` under `c(tmpdir)` and restores them after the lane.
- Paths derive from `c(pwd)`; no suite depends on a machine-local repository path.
- Test data are generated at runtime from fixed or deterministic constructions.
- Generated logs, workbooks, tables, and datasets are gitignored; only `demo/` documentation assets may be tracked.

## Dependencies

| Suite or lane | Needs | If missing |
| --- | --- | --- |
| `test_diagtab.do`, `validation_diagtab.do` | Python 3 and `openpyxl` through `tools/check_xlsx.py` | Excel content and style assertions fail |

## File index

### Functional and regression tests

| File | Covers |
| --- | --- |
| `test_diagtab.do` | Diagnostic measures, cutoffs, AUC, exports, frames, option conflicts, boundary cells, and formatting regressions |
| `test_diagtab_errors.do` | Public error codes, state preservation, destination preflight, and no-partial-output contracts |
| `test_diagtab_documentation_examples.do` | Executability of every public help example |
| `test_diagtab_oracle.do` | Deterministic random-table comparisons against independently computed two-by-two metrics |

### Validation

| File | Covers |
| --- | --- |
| `validation_diagtab.do` | Hand-computed 2 × 2 measures, interval oracles, cutoff monotonicity, AUC parity with `roctab`, and workbook cell values |

### Support

| Path | Contents |
| --- | --- |
| `run_all.do` | Curated sandboxed `quick` and `full` lane runner |
| `tools/check_xlsx.py` | Package-local workbook structure and cell-value checker |
| `tools/check_markdown.py` | Package-local Markdown artifact checker |
| `tools/summarize_xlsx.py` | Workbook summary helper used by validation diagnostics |
| `.gitignore` | Generated-artifact policy |

## Coverage map

| Command | Functional | Validation | Also exercised in |
| --- | --- | --- | --- |
| `diagtab` | `test_diagtab.do` | `validation_diagtab.do` | installed-user demo and install smoke |

## Lane membership

`quick` is a subset of `full`; `full` is the default release gate.

| Lane | Suites |
| --- | --- |
| `quick` | `test_diagtab.do`, `test_diagtab_errors.do`, `test_diagtab_documentation_examples.do` |
| `full` | All quick suites plus `validation_diagtab.do` and `test_diagtab_oracle.do` |
