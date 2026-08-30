# simtab QA

The `simtab` QA suite is flat and concern-oriented, with functional, error-path, documentation, known-answer, and independent-oracle checks driven by a curated runner. Each suite is independently runnable from this directory.

## How to run

```bash
cd simtab/qa
stata-mp -b do run_all.do          # full lane (default release gate)
stata-mp -b do run_all.do quick    # functional lane
stata-mp -b do test_simtab.do      # one suite standalone
```

The devkit can run the same gate in an isolated scratch copy with `python3 -m _devkit.stata_dev_cli run qa simtab --repo tools --isolated`.

## Isolation

The runner writes suite logs in `qa/`; concurrent runs of the same lane can collide. Use the devkit's isolated mode, or a scratch copy preserving the repository layout, for a trusted lane result.

## Conventions

- `test_*` files cover functional and regression behavior; `validation_*` files use known-answer and invariant oracles; `crossval_*` is reserved for parity against an independent external implementation; `benchmark_*` is reserved for timing guardrails outside correctness lanes.
- Every suite ends with `RESULT: <name> tests=N pass=N fail=N` and exits nonzero on failure.
- `run_all.do` sandboxes `PLUS` and `PERSONAL` under `c(tmpdir)` and restores them after the lane.
- Paths derive from `c(pwd)`; no suite depends on a machine-local repository path.
- Test data are generated at runtime from fixed or deterministic constructions.
- Generated logs, workbooks, tables, and datasets are gitignored; only `demo/` documentation assets may be tracked.

## Dependencies

| Suite or lane | Needs | If missing |
| --- | --- | --- |
| `quick` and `full` | Python 3 and `openpyxl` through `tools/check_xlsx.py` | workbook content and style assertions fail |
| `full` | `simsum`, `siman`, `sencode`, and `labelsof` | the runner attempts a sandboxed install and fails if any oracle is unavailable |

## File index

### Functional and regression tests

| File | Covers |
| --- | --- |
| `test_simtab.do` | Compute and ingest modes, metrics, MCSEs, every public option, artifacts, frames, caller Mata state, external-oracle adapters, and formatting regressions |
| `test_simtab_errors.do` | Sheet and formatting guards, summary proportion domains, simsum-row uniqueness, output-option conflicts, and symmetric caller-data preservation |
| `test_simtab_documentation_examples.do` | Executable compute and summary help workflows plus a self-contained SMCL render oracle with a positive control |
| `test_simtab_oracle.do` | Seeded independent numeric compute-mode oracle for means, RMS model SE, dispersion, coverage, power, failure counts, and plotframe precision |

### Validation

| File | Covers |
| --- | --- |
| `validation_simtab.do` | Hand-computed performance metrics, RMS model SE, inclusive rejection boundary, MCSEs, and live `simsum` parity |

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
| `simtab` | `test_simtab.do`, `test_simtab_errors.do`, `test_simtab_oracle.do` | `validation_simtab.do` | installed-user help workflows, render gate, demo, and install smoke |

## Lane membership

`quick` is a subset of `full`; `full` is the default release gate.

| Lane | Suites |
| --- | --- |
| `quick` | `test_simtab.do`, `test_simtab_errors.do`, `test_simtab_documentation_examples.do` |
| `full` | `test_simtab.do`, `test_simtab_errors.do`, `test_simtab_documentation_examples.do`, `validation_simtab.do`, `test_simtab_oracle.do` |
