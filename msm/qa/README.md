# msm QA

Flat, concern-named QA for the `msm` pipeline, with functional, adversarial, known-answer, recovery, public-data, and cross-language checks. One curated runner owns lane membership, and every suite is independently runnable from this directory.

## How to run

```bash
cd msm/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do crossval_msm_haart.do # one suite standalone
stata-mp -b do run_all.do benchmark  # performance guard only
```

Legacy aliases remain accepted: `tests` maps to `quick`, `stata` maps to `core`, and `all` maps to `full`.

## Isolation

`run_all.do` creates process-specific PLUS and PERSONAL directories under `c(tmpdir)`, installs the package from `../`, and requires every child suite to publish reconciled test/pass/fail/skip counts. For an independent release-gate receipt, copy `msm/`, `_data/`, and `tabtools/` into a scratch directory that preserves the repository layout, then run the copied `msm/qa/run_all.do` so its logs remain in scratch.

## Conventions

- `test_*` covers functional and regression behavior; `validation_*` covers hand-derived answers, invariants, and known-truth recovery; `crossval_*` compares against independent R/Python or published-study oracles; `benchmark_*` measures performance and is not part of the correctness gate.
- Every suite ends with `RESULT: <name> tests=N pass=N fail=N skip=N`, publishes the same reconciled values through `_record_qa_result.do`, and exits nonzero on failure.
- `run_all.do` owns the explicit suite lists and fails if a runnable suite is omitted or a listed file is missing.
- Paths derive from `c(pwd)`; package installation is sandboxed; no suite relies on a machine-specific path.
- Tracked teaching fixtures live in `data/`, with provenance and checksums in `fixtures_manifest.md`; synthetic fixtures are generated at runtime.
- Logs, temporary exchange files, workbooks, graphs, and other generated artifacts are gitignored and removed by the runner cleanup helper.

## Dependencies

| Suite/lane | Needs | If missing |
|---|---|---|
| `crossval` / `full` | `Rscript`; R packages `haven`, `ipw`, `sandwich`, `survey`, `survival` | Hard failure; install the missing package and rerun |
| `crossval_msm.do`, `crossval_external_models.do` | Python 3; `numpy`, `pandas`, `scipy`, `statsmodels` | Hard failure; install into the interpreter used by the suite and rerun |
| Public-data cross-validation | Tracked `data/nhefs.dta` and `data/haartdat.dta` | Hard failure; restore from the public source recorded in `fixtures_manifest.md` |

## File index

### Functional and regression tests

| File | Primary coverage |
|---|---|
| `test_qa_harness.do` | Fail-closed runner handshake controls |
| `test_msm.do` | Core prepare, validate, weight, fit, predict, diagnose, and report workflow |
| `test_msm_table.do` | Workbook content, errors, and persistence |
| `test_msm_options.do` | Per-command option paths and combinations |
| `test_msm_expanded.do` | Expanded pipeline combinations |
| `test_msm_status.do` | Flagship controller and state reporting |
| `test_msm_weight_ergonomics.do` | Weight defaults, preview, truncation, and returned specifications |
| `test_msm_period_basis.do` | Weight-model time bases, parity, and nonmonotone treatment processes |
| `test_msm_fit_guidance.do` | Outcome-model guidance and unsupported paths |
| `test_msm_cox_state.do` | Cox estimation and caller `stset` restoration |
| `test_msm_continuous_exposure.do` | Continuous and time-varying exposure contracts |
| `test_msm_weight_failures.do` | Weight-model failure policies and diagnostics |
| `test_msm_weight_adversarial.do` | Weight ownership, replacement, mutation, and timing edges |
| `test_msm_prepare_validate_adversarial.do` | Mapping, binary outcome, panel, and validation adversaries |
| `test_msm_hostile.do` | Long names, missingness, ordering, and hostile inputs |
| `test_msm_state_guards.do` | Pipeline preconditions and invalidation |
| `test_msm_state_identity.do` | Artifact identity, signatures, order, lifecycle, and rehydration |
| `test_msm_transaction_regressions.do` | Transaction, serialization, ownership, and intermittent missingness |
| `test_msm_risk_process_regressions.do` | Event/censor timing, gaps, and risk-set invariance |
| `test_msm_history_positivity_regressions.do` | Treatment history, positivity policy, repair metadata, and longitudinal balance |
| `test_msm_fit_prediction_regressions.do` | Fit, prediction, inference, support, spline, and VCE regressions |
| `test_msm_diagnostics_output_regressions.do` | Sensitivity, diagnostics, error propagation, and formatting |
| `test_msm_release_option_regressions.do` | Manifest and incompatible-option regressions |
| `test_package_release.do` | Distribution manifest, version/date, Viewer rendering, install, and public surface |
| `test_demo_contract.do` | Shipped demo workflow and generated artifact contracts |
| `test_msm_psdash_contract.do` | Propensity-score dashboard interoperability |
| `test_export_surface.do` | Export surfaces and package-root artifact hygiene |
| `test_msm_diagtab.do` | Accumulated diagnostics and Excel export |
| `test_msm_documentation_examples.do` | Literal help workflows and documented exports |
| `test_msm_output_adversarial.do` | Output failure restoration and hostile workbook paths |
| `test_msm_diagnostic_contracts.do` | Positivity, SMD, risk-set, state, and fitted-sample diagnostic contracts |
| `test_msm_abbrev_reload.do` | Option abbreviations, program reload, and session settings |

### Validation

| File | Primary coverage |
|---|---|
| `validation_msm.do` | Broad analytical, HAART, NHEFS, and contract validation |
| `validation_msm_known_answers.do` | Deterministic weight, fit, prediction, and sensitivity calculations |
| `validation_msm_joint_weights.do` | Exact two-period IPTW×IPCW products under unequal risk sets and current events |
| `validation_msm_expanded.do` | Expanded validation scenarios |
| `validation_msm_sensitivity.do` | E-value and confounding-bound known answers |
| `validation_msm_recovery.do` | Marginal log-odds recovery |
| `validation_msm_dgp_recovery.do` | Binary, survival, censoring, truncation, and replicated recovery |
| `validation_msm_history_recovery.do` | Static-regime recovery with lagged treatment effects |
| `validation_msm_predict_vectorized.do` | Seeded prediction-matrix, scalar-oracle, and degenerate-covariance parity |

### Cross-validation

| File | Independent oracle |
|---|---|
| `crossval_msm.do` | R/Python row-level weights, `ipw::ipwtm`, and Stata `teffects ipw` |
| `crossval_external_models.do` | R/Python robust and clustered outcome models on public package datasets |
| `crossval_msm_ipw_dta.do` | R `ipw::ipwpoint` and HC1 linear-model parity through `.dta` exchange |
| `crossval_msm_nhefs.do` | Public NHEFS `ipwpoint`, `survey::svyglm`, and published weight-gain example |
| `crossval_msm_haart.do` | Public HAART joint IPTW/IPCW, `survival::coxph`, and JSS worked-example anchors |

### Benchmark and support

| Path | Contents |
|---|---|
| `benchmark_msm_predict.do` | Vectorized-versus-scalar equivalence and timing guard; benchmark lane only |
| `run_all.do`, `run_all_validations.do` | Canonical runner and compatibility validation wrapper |
| `_install_msm_isolated.do`, `_record_qa_result.do` | Sandboxed install and reconciled child-result handshake |
| `_msm_qa_common.do`, `_crossval_dgp_generate.do`, `_cleanup_runtime_artifacts.do` | Shared fixtures, DGP generation, and artifact cleanup |
| `crossval_msm_nhefs.R`, `crossval_msm_haart.R` | Public-data reference calculations added for NHEFS and HAART |
| `crossval_external_models.R`, `crossval_external_models.py`, `crossval_r.R`, `crossval_python.py`, `crossval_msm_ipw_dta.R` | Existing external reference calculations |
| `tools/` | Package-local XLSX, PNG, and SMCL-width validators |
| `data/`, `fixtures_manifest.md` | Tracked public teaching fixtures and provenance |

## Coverage map

| Command | Functional | Validation | Cross-validation |
|---|---|---|---|
| `msm` | `test_msm_status.do`, `test_msm_state_guards.do` | `validation_msm.do` | `crossval_msm.do` |
| `msm_prepare` | `test_msm_prepare_validate_adversarial.do` | `validation_msm_joint_weights.do` | `crossval_msm_nhefs.do`, `crossval_msm_haart.do` |
| `msm_validate` | `test_msm_prepare_validate_adversarial.do` | `validation_msm.do` | — |
| `msm_weight` | `test_msm_weight_adversarial.do`, `test_msm_period_basis.do` | `validation_msm_known_answers.do`, `validation_msm_joint_weights.do`, recovery suites | All cross-validation suites |
| `msm_fit` | `test_msm_fit_prediction_regressions.do`, `test_msm_cox_state.do` | Fit, recovery, and prediction validation suites | `crossval_msm.do`, `crossval_external_models.do`, `crossval_msm_haart.do` |
| `msm_predict` | `test_msm_fit_prediction_regressions.do` | `validation_msm_history_recovery.do`, `validation_msm_predict_vectorized.do` | `crossval_external_models.do` |
| `msm_diagnose` | `test_msm_diagnostic_contracts.do` | `validation_msm.do` | — |
| `msm_diagtab` | `test_msm_diagtab.do` | — | — |
| `msm_plot` | `test_msm_documentation_examples.do`, `test_msm_output_adversarial.do` | `validation_msm.do` | — |
| `msm_table` | `test_msm_table.do`, `test_export_surface.do` | — | — |
| `msm_report` | `test_export_surface.do`, `test_msm_documentation_examples.do` | `validation_msm.do` | — |
| `msm_protocol` | `test_demo_contract.do`, `test_msm_options.do` | `validation_msm.do` | — |
| `msm_sensitivity` | `test_msm_diagnostics_output_regressions.do` | `validation_msm_sensitivity.do`, `validation_msm_known_answers.do` | — |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate. `run_all.do` is the sole executable membership list.

| Lane | Membership |
|---|---|
| `quick` | All curated `test_*.do` functional, state, export, documentation, and adversarial suites |
| `validations` | All curated `validation_*.do` known-answer and recovery suites |
| `core` | `quick` plus `validations` |
| `crossval` | All curated `crossval_*.do` external-oracle suites |
| `full` | `core` plus `crossval` |
| `benchmark` | `benchmark_msm_predict.do` only; outside correctness lanes |

## Fixtures and runtime artifacts

`fixtures_manifest.md` records source, licence, checksum, transformations, and regeneration for tracked data. `run_all_status.txt`, suite logs, exchange files, and generated outputs are runtime evidence only and must not be committed.
