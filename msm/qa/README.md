# msm QA

Run the curated QA lanes from this directory with the local Stata installation:

```bash
cd msm/qa
stata-mp -b do run_all.do full
```

`run_all.do` uses explicit suite lists with an inventory check, creates process-specific PLUS and PERSONAL directories, requires every child to publish reconciled test/pass/fail/skip counts, exits nonzero when any child suite fails, and writes runtime dispositions to the gitignored `run_all_status.txt`. The default lane is `full`. `run_all_validations.do` remains only as a compatibility wrapper.

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
| `test_qa_harness.do` | Negative and positive controls for the runner’s fail-closed child-result handshake |
| `test_msm.do` | Core functional tests across all commands (prepare, validate, weight, fit, predict, diagnose, report) |
| `test_msm_table.do` | `msm_table` workbook export (all sheets, re-import verification, error paths, persistence) |
| `test_msm_options.do` | Per-command option-path coverage, SECTION A–M (prepare/validate/weight/fit/predict/diagnose/plot/report/protocol/sensitivity, helpers, metadata, audit-fix regressions) |
| `test_msm_expanded.do` | Expanded command options and pipeline combinations |
| `test_msm_status.do` | Flagship controller and pipeline-state reporting |
| `test_msm_weight_ergonomics.do` | Weight defaults, preview, truncation, and returned specifications |
| `test_msm_period_basis.do` | 1.4.0 time basis: `period_d_spec()`/`period_n_spec()` parity against hand-refits of all four weighting logits, default no-regression gate, spec validation and spline-support refusal, state persistence, and recovery of a non-monotone treatment process |
| `test_msm_fit_guidance.do` | Outcome-model guidance and unsupported model paths |
| `test_msm_cox_state.do` | Cox estimation and caller `stset` restoration |
| `test_msm_continuous_exposure.do` | Continuous/time-varying exposure contracts and effect labeling |
| `test_msm_weight_failures.do` | Weight-model failure policies and diagnostics |
| `test_msm_weight_adversarial.do` | Weight ownership, mutation, replacement, and timing edge cases |
| `test_msm_prepare_validate_adversarial.do` | Mapping, binary-outcome, panel, and validation adversaries |
| `test_msm_state_guards.do` | Pipeline precondition guards and invalidation |
| `test_msm_state_identity.do` | Artifact UUID, signature, metadata, order, and lifecycle identity |
| `test_msm_transaction_regressions.do` | Transaction, serialization, ownership, and intermittent-missingness regressions |
| `test_msm_risk_process_regressions.do` | Person-period structure, role mapping, event/censor timing, gap, and risk-set invariance regressions |
| `test_msm_history_positivity_regressions.do` | Treatment-history, positivity-policy, repair metadata, and longitudinal-balance regressions |
| `test_msm_fit_prediction_regressions.do` | Fit, prediction, inference, support, spline, and VCE regressions |
| `test_msm_diagnostics_output_regressions.do` | Sensitivity, diagnostics, output error propagation, and formatting regressions |
| `test_msm_release_option_regressions.do` | Release manifest and incompatible-option regressions |
| `test_package_release.do` | Exact package manifest, version/date, SMCL rendering, install, example-data, and public-command contracts |
| `test_demo_contract.do` | Shipped demo workflow plus workbook structure and PNG signature/dimension contracts |
| `test_msm_psdash_contract.do` | Propensity-score dashboard interoperability contract |
| `test_export_surface.do` | Export surfaces and package-root artifact hygiene |
| `test_msm_diagtab.do` | Accumulated diagnostics and Excel export |
| `test_msm_output_adversarial.do` | Output failure restoration and hostile workbook paths |
| `test_msm_diagnostic_contracts.do` | Diagnostic regressions: positivity on P(observed treatment), risk-set summaries and plots, exact continuous/binary SMD known answers, state/order hygiene, and fitted-sample metadata |
| `test_msm_abbrev_reload.do` | Option abbreviations, program reload, and session settings |

### Validation suites

| File | Primary coverage |
|------|------------------|
| `validation_msm.do` | Broad analytical and contract validation |
| `validation_msm_known_answers.do` | Deterministic known-answer calculations |
| `validation_msm_expanded.do` | Expanded validation scenarios |
| `validation_msm_sensitivity.do` | E-value and confounding-bound known answers |
| `validation_msm_recovery.do` | Marginal log-odds parameter recovery |
| `validation_msm_dgp_recovery.do` | Binary-outcome and survival DGP recovery, including censoring timing and replicated MCSE-calibrated recovery |
| `validation_msm_history_recovery.do` | Known-truth static-regime recovery when lagged treatment affects outcome |

### Cross-validation suites

| File | Primary coverage |
|------|------------------|
| `crossval_msm.do` | Actual `msm` output against R/Python row-level treatment-weight parity, `ipw::ipwtm` execution, and `teffects ipw` |
| `crossval_external_models.do` | External robust/clustered model and prediction parity |

## Coverage map

| Command or surface | Principal QA files |
|--------------------|--------------------|
| `msm`, state controller | `test_msm_status.do`, `test_msm_state_guards.do`, `test_msm_state_identity.do` |
| `msm_prepare`, `msm_validate` | `test_msm_prepare_validate_adversarial.do`, `validation_msm.do`, `validation_msm_known_answers.do` |
| `msm_weight` | `test_msm_weight_ergonomics.do`, `test_msm_weight_failures.do`, `test_msm_weight_adversarial.do`, `test_msm_history_positivity_regressions.do`, `crossval_msm.do` |
| `msm_fit` | `test_msm_fit_guidance.do`, `test_msm_cox_state.do`, `test_msm_continuous_exposure.do`, `test_msm_history_positivity_regressions.do`, `validation_msm_recovery.do`, `validation_msm_dgp_recovery.do`, `validation_msm_history_recovery.do` |
| `msm_predict` | `test_msm.do`, `test_msm_options.do`, `test_msm_expanded.do`, `test_msm_history_positivity_regressions.do`, `validation_msm_history_recovery.do`, `crossval_external_models.do` |
| `msm_diagnose`, `msm_diagtab` | `test_msm_diagtab.do`, `test_msm_options.do`, `test_msm_history_positivity_regressions.do`, `test_msm_psdash_contract.do`, `test_export_surface.do` |
| `msm_plot`, `msm_report`, `msm_table` | `test_msm_table.do`, `test_export_surface.do`, `test_msm_output_adversarial.do`, `test_msm_options.do`, `test_msm_expanded.do` |
| All commands — per-command option paths | `test_msm.do` (functional), `test_msm_options.do` (options SECTION A–M) |
| `msm_protocol`, `msm_sensitivity` | `test_export_surface.do`, `validation_msm_sensitivity.do` |
| Shared artifact/transaction layer | `test_msm_state_identity.do`, `test_msm_transaction_regressions.do`, `test_msm_abbrev_reload.do` |

## Lane membership

| Lane | Suites |
|------|--------|
| `quick` | 30 curated functional, regression, harness, package, demo, export, and adversarial suites listed under Functional and regression suites |
| `validations` | 7 `validation_*.do` suites listed under Validation suites |
| `core` | All 37 Stata-side suites (`quick` + `validations`) |
| `crossval` | `crossval_msm.do`, `crossval_external_models.do` |
| `full` | All 39 suites (`core` + `crossval`); default release gate |

## Supporting files

- `_install_msm_isolated.do` installs the package into the runner's isolated Stata directories.
- `_record_qa_result.do` validates each suite’s arithmetic and publishes its completion handshake to the runner.
- `_msm_qa_common.do` provides registered fixtures and shared assertions.
- `_cleanup_runtime_artifacts.do` removes disposable child logs and cross-validation products before a lane.
- `_crossval_dgp_generate.do` is a dependency invoked by the cross-validation suite `crossval_msm.do`; it is not a standalone lane.
- `crossval_external_models.R`, `crossval_external_models.py`, `crossval_r.R`, `crossval_python.py`, `tools/check_xlsx.py`, and `tools/check_png.py` provide external reference calculations and artifact inspection.

Batch Stata may create `run_all.log`; the runner also writes `run_all_runner.log`, `run_all_status.txt`, and any logs opened by child suites. These are runtime evidence only, are gitignored, and must not be committed.
