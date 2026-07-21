# msm QA

Run the curated QA lanes from this directory with the local Stata installation:

```bash
cd msm/qa
stata-mp -b do run_all.do full
```

`run_all.do` uses explicit suite lists, creates process-specific PLUS and PERSONAL directories, exits nonzero when any child suite fails, and writes durable dispositions to `run_all_status.txt`. The default lane is `full`. `run_all_validations.do` remains only as a compatibility wrapper.

## Lanes

| Lane | Membership | Purpose |
|------|------------|---------|
| `quick` | Every `test_*.do` file listed below | Functional, contract, state, export, and adversarial regression checks |
| `validations` | Every `validation_*.do` file listed below | Known-answer, recovery, sensitivity, and DGP validation |
| `core` | `quick` plus `validations` | Entire Stata-side gate |
| `crossval` | `crossval_msm.do` and `crossval_external_models.do` | R/Python parity and external model checks |
| `full` | `core` plus `crossval` | Release gate and default |

Legacy lane aliases remain accepted: `tests` maps to `quick`, `stata` maps to `core`, and `all` maps to `full`.

## File index

### Functional and regression suites

| File | Primary coverage |
|------|------------------|
| `test_msm.do` | Core functional tests across all commands (prepare, validate, weight, fit, predict, diagnose, report) |
| `test_msm_table.do` | `msm_table` workbook export (all sheets, re-import verification, error paths, persistence) |
| `test_msm_options.do` | Per-command option-path coverage, SECTION A–M (prepare/validate/weight/fit/predict/diagnose/plot/report/protocol/sensitivity, helpers, metadata, audit-fix regressions) |
| `test_msm_expanded.do` | Expanded command options and pipeline combinations |
| `test_msm_status.do` | Flagship controller and pipeline-state reporting |
| `test_msm_weight_ergonomics.do` | Weight defaults, preview, truncation, and returned specifications |
| `test_msm_fit_guidance.do` | Outcome-model guidance and unsupported model paths |
| `test_msm_cox_state.do` | Cox estimation and caller `stset` restoration |
| `test_msm_continuous_exposure.do` | Continuous/time-varying exposure contracts and effect labeling |
| `test_msm_weight_failures.do` | Weight-model failure policies and diagnostics |
| `test_msm_weight_adversarial.do` | Weight ownership, mutation, replacement, and timing edge cases |
| `test_msm_prepare_validate_adversarial.do` | Mapping, binary-outcome, panel, and validation adversaries |
| `test_msm_state_guards.do` | Pipeline precondition guards and invalidation |
| `test_msm_state_identity.do` | Artifact UUID, signature, metadata, order, and lifecycle identity |
| `test_msm_independent_review.do` | Independent-review regressions for transactions, serialization, ownership, and intermittent missingness |
| `test_msm_phase3.do` | Treatment-history, positivity-policy, repair metadata, and longitudinal balance regressions |
| `test_msm_psdash_contract.do` | Propensity-score dashboard interoperability contract |
| `test_export_surface.do` | Export surfaces and package-root artifact hygiene |
| `test_msm_diagtab.do` | Accumulated diagnostics and Excel export |
| `test_msm_output_adversarial.do` | Output failure restoration and hostile workbook paths |
| `test_msm_abbrev_reload.do` | Option abbreviations, program reload, and session settings |

### Validation suites

| File | Primary coverage |
|------|------------------|
| `validation_msm.do` | Broad analytical and contract validation |
| `validation_msm_known_answers.do` | Deterministic known-answer calculations |
| `validation_msm_expanded.do` | Expanded validation scenarios |
| `validation_msm_sensitivity.do` | E-value and confounding-bound known answers |
| `validation_msm_recovery.do` | Marginal log-odds parameter recovery |
| `validation_msm_dgp_recovery.do` | Binary-outcome and survival DGP recovery, including censoring timing |
| `validation_msm_phase3_recovery.do` | Known-truth static-regime recovery when lagged treatment affects outcome |

### Cross-validation suites

| File | Primary coverage |
|------|------------------|
| `crossval_msm.do` | Stata/R/Python treatment and censoring weight parity |
| `crossval_external_models.do` | External robust/clustered model and prediction parity |

## Coverage map

| Command or surface | Principal QA files |
|--------------------|--------------------|
| `msm`, state controller | `test_msm_status.do`, `test_msm_state_guards.do`, `test_msm_state_identity.do` |
| `msm_prepare`, `msm_validate` | `test_msm_prepare_validate_adversarial.do`, `validation_msm.do`, `validation_msm_known_answers.do` |
| `msm_weight` | `test_msm_weight_ergonomics.do`, `test_msm_weight_failures.do`, `test_msm_weight_adversarial.do`, `test_msm_phase3.do`, `crossval_msm.do` |
| `msm_fit` | `test_msm_fit_guidance.do`, `test_msm_cox_state.do`, `test_msm_continuous_exposure.do`, `test_msm_phase3.do`, `validation_msm_recovery.do`, `validation_msm_dgp_recovery.do`, `validation_msm_phase3_recovery.do` |
| `msm_predict` | `test_msm.do`, `test_msm_options.do`, `test_msm_expanded.do`, `test_msm_phase3.do`, `validation_msm_phase3_recovery.do`, `crossval_external_models.do` |
| `msm_diagnose`, `msm_diagtab` | `test_msm_diagtab.do`, `test_msm_options.do`, `test_msm_phase3.do`, `test_msm_psdash_contract.do`, `test_export_surface.do` |
| `msm_plot`, `msm_report`, `msm_table` | `test_msm_table.do`, `test_export_surface.do`, `test_msm_output_adversarial.do`, `test_msm_options.do`, `test_msm_expanded.do` |
| All commands — per-command option paths | `test_msm.do` (functional), `test_msm_options.do` (options SECTION A–M) |
| `msm_protocol`, `msm_sensitivity` | `test_export_surface.do`, `validation_msm_sensitivity.do` |
| Shared artifact/transaction layer | `test_msm_state_identity.do`, `test_msm_independent_review.do`, `test_msm_abbrev_reload.do` |

## Supporting files

- `_install_msm_isolated.do` installs the package into the runner's isolated Stata directories.
- `_msm_qa_common.do` provides registered fixtures and shared assertions.
- `_cleanup_runtime_artifacts.do` removes disposable child logs and cross-validation products before a lane.
- `_crossval_dgp_generate.do` is a dependency invoked by the cross-validation suite `crossval_msm.do`; it is not a standalone lane.
- `crossval_external_models.R`, `crossval_external_models.py`, `crossval_r.R`, `crossval_python.py`, and `tools/check_xlsx.py` provide external reference calculations and workbook inspection.

The full lane retains `run_all.log`, `run_all_runner.log`, `run_all_status.txt`, and child logs as execution evidence. Remove them after reviewing the result; they are runtime artifacts and must not be committed.
