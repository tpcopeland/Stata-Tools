# simtab QA

<!-- archetypes: A1 A7 -->

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
| `test_fixture_error_payload.do` | Both strict contexts, late named603 export refusal with exact four numeric companion cells, analytical r publication, preserved active native estimates/xb/stdp and all other caller state |
| `test_fixture_error_returns.do` | Genuine empty/populated scalar/macro/striped-matrix prior r() on named pre-payload refusals; complete caller snapshot compared after logopen/before logclose |
| `test_fixture_cold_workbook.do` | Cold strict off/on compilation through actual Excel export and named198 sheet refusal, independent finite mean/SD payloads, full non-r caller fingerprint and subsequent native Mata work |
| `test_fixture_compile_state.do` | All five actual helper compilation blocks with planted syntax errors under strict off/on, compared with native compiler rc and caller strict/data preservation |
| `test_fixture_precision.do` | All five estimate storage types under friendly/permuted inputs, independent Bernoulli means/SDs, requested digits0/6 and exact caller fingerprint |
| `test_simtab.do` | Compute and ingest modes, metrics, MCSEs, every public option, artifacts, frames, caller Mata state, external-oracle adapters, and formatting regressions |
| `test_simtab_errors.do` | Sheet and formatting guards, summary proportion domains, simsum-row uniqueness, output-option conflicts, and symmetric caller-data preservation |
| `test_simtab_documentation_examples.do` | Executable compute and summary help workflows plus a self-contained SMCL render oracle with a positive control |
| `test_simtab_oracle.do` | Seeded independent numeric compute-mode oracle for means, RMS model SE, dispersion, coverage, power, failure counts, and plotframe precision |

### Validation

| File | Covers |
| --- | --- |
| `validation_fixture_truth.do` | Canonical exact labelled-group moments |
| `validation_fixture_matrix.do` | Two independent Gaussian recovery seeds and finite A1/A7/primitive summaries with named refusal fingerprints |
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
| `quick` | `validation_fixture_truth.do`, `validation_fixture_matrix.do`, `test_fixture_precision.do`, `test_fixture_compile_state.do`, `test_fixture_cold_workbook.do`, `test_fixture_error_returns.do`, `test_fixture_error_payload.do`, `test_simtab.do`, `test_simtab_errors.do`, `test_simtab_documentation_examples.do` |
| `full` | `validation_fixture_truth.do`, `validation_fixture_matrix.do`, `test_fixture_precision.do`, `test_fixture_compile_state.do`, `test_fixture_cold_workbook.do`, `test_fixture_error_returns.do`, `test_fixture_error_payload.do`, `test_simtab.do`, `test_simtab_errors.do`, `test_simtab_documentation_examples.do`, `validation_simtab.do`, `test_simtab_oracle.do` |

Canonical fixture adoption is in progress. `3` cases in `validation_fixture_truth.do` ran with zero failures in an isolated copy; independent review is pending. Three cases check group means, bias, empirical SD, root-mean-square model SE, MSE and RMSE against exact ten-row integer-block formulas in the numeric companion frame. order(sort) explicitly aligns ordinal output keys after permutation.

| Added QA file | Role |
|---|---|
| `validation_fixture_truth.do` | Known-answer F/U suite; reached from the package runner |
| `_qa_fx_a1.do` | Byte-for-byte canonical regression DGP vendor |
| `_qa_state.do` | Byte-for-byte full session fingerprint vendor |
| `_qa_fx_a7.do` | Byte-for-byte canonical fixture vendor |
| `_qa_hostile.do` | Byte-for-byte primitive/assertion helper vendor |

The matrix computes direct centered finite moments before the candidate, and two seeds recover mean2 using the independent Gaussian DGP MCSE1/sqrt(cellN). A1 outcome/design/group roles are consumed explicitly. Zero/extreme analytic weights have no compute-mode weight argument; collinear regressors have no role in a scalar simulation estimate. Those cells remain visible for applicability review. Fixture coverage still owed: default first-occurrence ordering, ingest, file writers and remaining A1/A7 minima. Cold state/export precision controls remain under review. Archetype declarations retain these obligations; a green runtime subset does not meet the full census.

Refusals before analytical payload preparation retain genuine empty or populated prior r(). Successful and late output-side calls publish the command’s analytical returns; these paths are checked numerically rather than demanding unchanged prior r(). Earlier cold/global checks omitted rreturn and prove non-r state only.
