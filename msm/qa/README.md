# msm QA

Flat, concern-named QA for the `msm` estimator core (prepare, weight, diagnose, fit, predict), the seven removed-command stubs, and the companion-package routes that replace them. One curated runner owns lane membership, and every suite is independently runnable from this directory.

archetypes: A3(msm_prepare msm_weight msm_fit msm_predict msm_diagnose) A1(msm_prepare msm_weight msm_fit msm_predict msm_diagnose) A7(msm)

## How to run

```bash
cd msm/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do core       # all Stata-side suites, no R/Python
stata-mp -b do run_all.do quick      # functional lane
stata-mp -b do crossval_msm_predict.do # one suite standalone
stata-mp -b do run_all.do benchmark  # performance guard only
```

Legacy aliases remain accepted: `tests` maps to `quick`, `stata` maps to `core`, and `all` maps to `full`.

## Isolation

`run_all.do` creates process-specific PLUS and PERSONAL directories under `c(tmpdir)`, installs the package from `../`, and requires every child suite to publish reconciled test/pass/fail/skip counts. For an independent release-gate receipt, copy `msm/`, `_data/`, `tabtools/`, `psdash/`, `eplot/`, `qba/` and `swimlane/` into a scratch directory that preserves the repository layout, then run the copied `msm/qa/run_all.do` so its logs remain in scratch.

## Conventions

- `test_*` covers functional and regression behavior; `validation_*` covers hand-derived answers, invariants, and known-truth recovery; `crossval_*` compares against independent R/Python or published-study oracles; `benchmark_*` measures performance and is not part of the correctness gate.
- Every suite ends with `RESULT: <name> tests=N pass=N fail=N skip=N`, publishes the same reconciled values through `_record_qa_result.do`, and exits nonzero on failure.
- `run_all.do` owns the explicit suite lists and fails if a runnable suite is omitted or a listed file is missing.
- Paths derive from `c(pwd)`; package installation is sandboxed; no suite relies on a machine-specific path.
- Tracked fixtures live in `data/`, with provenance and checksums in `fixtures_manifest.md`; synthetic fixtures are generated at runtime.
- Logs, temporary exchange files, workbooks, graphs, and other generated artifacts are gitignored and removed by the runner cleanup helper.

## Dependencies

| Suite/lane | Needs | If missing |
|---|---|---|
| `test_msm_companion_smoke.do`, `test_msm_documentation_examples.do`, `test_demo_contract.do` | Sibling package directories `../../tabtools`, `../../psdash`, `../../eplot`, `../../qba`, `../../swimlane` | Hard failure; run from the Stata-Tools layout or copy the siblings into scratch |
| `crossval` / `full` | `Rscript`; R packages `haven`, `ipw`, `sandwich`, `survey`, `survival`, `splines` | Hard failure; install the missing package and rerun |
| `crossval_msm.do`, `crossval_external_models.do` | Python 3; `numpy`, `pandas`, `scipy`, `statsmodels` | Hard failure; install into the interpreter used by the suite and rerun |
| Public-data cross-validation | Tracked `data/nhefs.dta` and `data/haartdat.dta` | Hard failure; restore from the public source recorded in `fixtures_manifest.md` |

## File index

### Functional and regression tests

| File | Primary coverage |
|---|---|
| `test_fixture_public.do` | A3 friendly/unsorted public pipeline: readers, dispatcher, direct ESS, longitudinal diagnose returns, fit, and the `msm_predict, frame()` payload |
| `test_fixture_fit_routes.do` | A3 logistic/linear/Cox and four history terms; native coefficients, covariance, stripes and reconstructed estimation/history rows |
| `test_fixture_predict_refusals.do` | Full caller e/r/data/RNG/global fingerprints for early/support refusals, a planted after-draw failure and a `frame()` refusal; prediction writes no state |
| `test_fixture_weight_policies.do` | Separated treatment/censor models and constant treatment refusals, explicit clip/fallback audit and IPW arithmetic, preview, caller-estimate preservation |
| `test_fixture_reader_refusals.do` | Guard refusals of the five core commands and the dispatcher, and the 199 refusal of all seven stubs, × empty/full r() × tied/unsorted data |
| `test_fixture_edges.do` | A3 single-period weighted-mean oracle and incomplete-baseline refusal |
| `test_fixture_contract.do` | Canonical A3 F/U population, order, duplicate/gap atomicity and singleton-cluster contracts |
| `test_qa_harness.do` | Fail-closed runner handshake controls |
| `test_msm.do` | Core prepare, weight, fit, predict and diagnose workflow |
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
| `test_msm_truncation_cutoffs.do` | `truncate()` counts and caps at the exact P1/P99 cutoffs (held in scalars, not macros) |
| `test_msm_weight_scale.do` | ESS and weighted SMD unchanged when weights are scaled to 1e-300 or 1e300; `msm_weight` and `msm_diagnose` ESS against a Mata oracle |
| `test_msm_prepare_validate_adversarial.do` | Mapping, binary outcome, panel and stale-mapping adversaries; post-prepare edits refused by `msm_weight` |
| `test_msm_hostile.do` | Long names, extended missingness, ordering, and hostile inputs |
| `test_msm_state_guards.do` | Pipeline preconditions and invalidation; downstream commands write no state |
| `test_msm_state_identity.do` | Fit identity, signatures, order, lifecycle, and rehydration |
| `test_msm_transaction_regressions.do` | Transaction, serialization, ownership, and intermittent missingness |
| `test_msm_risk_process_regressions.do` | Event/censor timing, gaps, risk-set invariance, support violations |
| `test_msm_history_positivity_regressions.do` | Treatment history, positivity policy, repair metadata, and longitudinal balance |
| `test_msm_fit_prediction_regressions.do` | Fit, prediction, inference, support, spline, signed-period and VCE regressions |
| `test_msm_diagnostics_output_regressions.do` | SMD threshold and unavailable-SMD semantics; operational positivity floor |
| `test_msm_release_option_regressions.do` | Manifest and removed/incompatible-option regressions |
| `test_package_release.do` | Distribution manifest, version/date, Viewer rendering, install, and public surface including the stubs |
| `test_demo_contract.do` | Shipped demo workflow and generated artifact contracts |
| `test_msm_psdash_contract.do` | Contract fields psdash reads, contract 1.1 `_msm_risk_var` signing, and contract-1.0 compatibility |
| `test_msm_documentation_examples.do` | Literal help and README workflows, including the companion calls |
| `test_msm_diagnostic_contracts.do` | Positivity, SMD, risk-set, state, and fitted-sample diagnostic contracts |
| `test_msm_abbrev_reload.do` | Option abbreviations, program reload, and session settings |
| `test_msm_predict_frame.do` | `msm_predict, frame()` schema and values, `r(rd)`/`r(sd)`, replace and refusal contracts, signed-period names |
| `test_msm_diagnose_fixture.do` | Retained `msm_diagnose` returns bit-identical to msm 1.4.12 on three scenarios; removed options; no persistence |
| `test_msm_validate_mapping.do` | One test per former `msm_validate` check, in the core command that now owns it |
| `test_msm_removed_stubs.do` | Each stub exits 199 with its replacement and touches nothing, including when called by literal name on an empty dataset; upgrade over 1.4.x with and without uninstall resolves to the stubs |
| `test_msm_companion_smoke.do` | regtab, effecttab, eplot, twoway recipe, psdash (contract 1.1 end to end), qba_confound and swimlane on msm output, with values checked |

### Validation

| File | Primary coverage |
|---|---|
| `validation_fixture_recovery.do` | A3-SEQ single-decision known-truth risk recovery at 100,000 subjects |
| `validation_msm.do` | Broad analytical, HAART, NHEFS, and contract validation |
| `validation_msm_known_answers.do` | Deterministic weight, fit, and prediction calculations |
| `validation_msm_joint_weights.do` | Exact two-period IPTW×IPCW products under unequal risk sets and current events |
| `validation_msm_expanded.do` | Expanded validation scenarios |
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
| `crossval_msm_predict.do` | R `glm` + `sandwich::vcovCL` + hand-written g-formula standardization: fitted risk set, point risks and RD (1e-6), and Monte Carlo percentile limits on `msm_example` (quadratic; `ns(3)` with history terms) and HAART |

### Benchmark and support

| Path | Contents |
|---|---|
| `benchmark_msm_predict.do` | Vectorized-versus-scalar equivalence and timing guard; benchmark lane only |
| `run_all.do`, `run_all_validations.do` | Canonical runner and compatibility validation wrapper |
| `_install_msm_isolated.do`, `_record_qa_result.do` | Sandboxed install and reconciled child-result handshake |
| `_qa_fx_a1.do`, `_qa_fx_a3.do`, `_qa_fx_a7.do`, `_qa_hostile.do`, `_qa_state.do` | Byte-for-byte canonical fixture and caller-state helpers |
| `_msm_qa_common.do`, `_crossval_dgp_generate.do`, `_cleanup_runtime_artifacts.do` | Shared fixtures, DGP generation, and artifact cleanup |
| `_diagnose_fixture_scenarios.do`, `_make_diagnose_fixture.do` | The three `msm_diagnose` fixture scenarios and the one-off generator run against 1.4.12 |
| `crossval_msm_nhefs.R`, `crossval_msm_haart.R`, `crossval_msm_predict.R` | Public-data and prediction reference calculations |
| `crossval_external_models.R`, `crossval_external_models.py`, `crossval_r.R`, `crossval_python.py`, `crossval_msm_ipw_dta.R` | Existing external reference calculations |
| `tools/` | Package-local XLSX, PNG, and SMCL-width validators |
| `data/`, `fixtures_manifest.md` | Tracked public teaching fixtures, the 1.4.12 `msm_diagnose` fixture, and provenance |

## Coverage map

| Command | Functional | Validation | Cross-validation |
|---|---|---|---|
| `msm` | `test_msm_status.do`, `test_msm_state_guards.do`, `test_fixture_public.do`, `test_fixture_reader_refusals.do` | `validation_msm.do` | `crossval_msm.do` |
| `msm_prepare` | `test_msm_prepare_validate_adversarial.do`, `test_msm_validate_mapping.do`, `test_fixture_contract.do`, `test_fixture_edges.do`, `test_fixture_reader_refusals.do` | `validation_msm_joint_weights.do` | `crossval_msm_nhefs.do`, `crossval_msm_haart.do` |
| `msm_weight` | `test_msm_weight_adversarial.do`, `test_msm_weight_scale.do`, `test_msm_truncation_cutoffs.do`, `test_msm_period_basis.do`, `test_msm_psdash_contract.do`, `test_fixture_weight_policies.do`, `test_fixture_reader_refusals.do` | `validation_msm_known_answers.do`, `validation_msm_joint_weights.do`, recovery suites | All cross-validation suites |
| `msm_diagnose` | `test_msm_diagnose_fixture.do`, `test_msm_diagnostic_contracts.do`, `test_msm_validate_mapping.do`, `test_fixture_public.do`, `test_fixture_reader_refusals.do` | `validation_msm.do`, `validation_msm_expanded.do` | — |
| `msm_fit` | `test_msm_fit_prediction_regressions.do`, `test_msm_cox_state.do`, `test_fixture_public.do`, `test_fixture_fit_routes.do`, `test_fixture_reader_refusals.do` | Fit, recovery, and prediction validation suites | `crossval_msm.do`, `crossval_external_models.do`, `crossval_msm_haart.do`, `crossval_msm_predict.do` |
| `msm_predict` | `test_msm_predict_frame.do`, `test_msm_fit_prediction_regressions.do`, `test_fixture_contract.do`, `test_fixture_edges.do`, `test_fixture_predict_refusals.do`, `test_fixture_reader_refusals.do` | `validation_msm_history_recovery.do`, `validation_msm_predict_vectorized.do` | `crossval_msm_predict.do` |
| Removed-command stubs (7) | `test_msm_removed_stubs.do`, `test_fixture_reader_refusals.do`, `test_package_release.do` | — | — |
| Companion routes | `test_msm_companion_smoke.do`, `test_msm_documentation_examples.do` | — | — |

## Former `msm_validate` checks

| Check | Now owned by | Test |
|---|---|---|
| 1 One row per id-period | `msm_prepare` refusal (198) | `test_msm_validate_mapping.do` V1 |
| 2 No period gaps | `msm_prepare` `r(n_gap_ids)` note; `msm_weight` refusal (459) | V2 |
| 3 Outcome terminal | Rows after the event leave `_msm_decision_risk` | V3 |
| 4 Treatment variation | `msm_weight` refusal (498) | V4 |
| 5 Missing data | `msm_prepare` `r(missing_vars)`; id/period refused (198); missing model inputs refused by `msm_weight` (459); missing outcome kept out of the fit | V5 |
| 6 Observations per period | `msm_prepare` `r(min_period_n)` note; per-period N in `msm_diagnose` `r(support)` and `psdash combined` | V6 |
| 7 Covariate completeness | `msm_prepare` `r(constant_covariates)`; all-missing covariate refused by `msm_weight` (459) | V7 |
| 8 Treatment history patterns | Descriptive only; `swimlane` | — |
| 9 Censoring terminal | Rows after censoring leave `_msm_decision_risk` | V3, `test_msm_prepare_validate_adversarial.do` PV5 |
| 10 Treatment support by period | `msm_diagnose` `r(n_support_violations)` and positivity floor; missing treatment refused by `msm_weight` | V8 |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate. `run_all.do` is the sole executable membership list.

| Lane | Membership |
|---|---|
| `quick` | All curated `test_*.do` functional, state, stub, companion, documentation, and adversarial suites |
| `validations` | All curated `validation_*.do` known-answer and recovery suites |
| `core` | `quick` plus `validations` |
| `crossval` | All curated `crossval_*.do` external-oracle suites |
| `full` | `core` plus `crossval` |
| `benchmark` | `benchmark_msm_predict.do` only; outside correctness lanes |

## Known gaps

- Multi-period risk recovery, separated outcome/treatment/censoring routes, absorption, remaining partial-missingness and factor/name routes, extreme weights, and additional Cox/linear inference routes remain open cells of the fixture catalog.

## Fixtures and runtime artifacts

`fixtures_manifest.md` records source, licence, checksum, transformations, and regeneration for tracked data. `run_all_status.txt`, suite logs, exchange files, and generated outputs are runtime evidence only and must not be committed.
