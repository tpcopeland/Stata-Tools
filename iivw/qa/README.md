# iivw QA

The `iivw` QA suite is flat and concern-oriented, with curated lanes in `run_all.do` and independently runnable suites in this directory. It covers the public commands, pipeline state, installed-user behavior, numerical recovery, documentation, exports, and external parity.

## How to run

```bash
cd iivw/qa
./run_all.sh full                       # default release gate, including R parity
./run_all.sh quick                      # fast contract and release subset
stata-mp -b do test_iivw.do             # one standalone suite
```

Prefer `run_all.sh`: it gives the shell a reliable exit status and verifies one well-formed `RESULT:` sentinel for every curated suite. A bare `stata-mp -b do` process returns zero on this platform even after a Stata failure; for direct runs, read the terminal `RESULT:` line or `run_all_status.txt`.

Legacy lanes are `legacy` and `sensitivity`; `sim` aliases `sensitivity`.

## Isolation

The runner writes shared logs and status files in `qa/`, so do not run the same lane concurrently from one checkout. For parallel or repeated audit runs, use a scratch copy that preserves the repository layout and remove copied `qa/*.log`, `run_all_status.txt`, and `run_all_expected.txt` before starting.

Suites sandbox `PLUS` and `PERSONAL` under `c(tmpdir)` and install from the local package tree. Scratch copies must include the sibling `tabtools/` package used by installed export smokes.

## Conventions

- `test_*` covers functional, adversarial, integration, release, and regression behavior; `validation_*` uses known-answer, invariant, or simulated-truth oracles; `crossval_*` compares with independent R implementations; `benchmark_*` and `probe_*` are diagnostics outside correctness lanes.
- Every curated suite ends with one `RESULT: <name> tests=N pass=N fail=N [skip=N]` sentinel and exits nonzero on failure. `full` accepts no skips.
- Suites sandbox `PLUS` and `PERSONAL` via `_iivw_qa_common.do`, then install the package from `../`; the user's ado tree is not touched.
- Paths derive from `c(pwd)` or the script location; no suite uses a machine-local checkout path.
- Functional data are generated from fixed seeds; tracked CSV fixtures are independent R reference outputs with their generators beside them.
- Generated logs, datasets, workbooks, graphs, and sentinel files are gitignored. Tracked coverage results are preregistered evidence, not disposable runtime artifacts.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| `quick`, `core` | Stata 16+; Python 3 with `openpyxl` for workbook inspection | hard failure |
| `full` | `core`; R with `IrregLong`, `geepack`, `survival`, `nlme`, `ipw`, and `cobalt` | hard failure before stale CSVs can be used |
| installed export smoke | sibling `tabtools/` checkout | hard failure |
| `legacy`, `sensitivity` | Stata 16+ | hard failure |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_help_examples.do` | Shipped help examples and documentation contracts. |
| `test_iivw.do` | Public workflow, options, errors, returns, and session state. |
| `test_iivw_balance.do` | Balance diagnostics, returns, and state preservation. |
| `test_iivw_bs_frame_contract.do` | Bootstrap panel frame and restored outcome sample. |
| `test_iivw_coverage_gate.do` | Coverage-pool aggregation and claim consistency. |
| `test_iivw_cr_ladder.do` | Correlation-structure ladder arithmetic. |
| `test_iivw_diagnose.do` | Diagnostic decomposition command. |
| `test_iivw_diagnostic_workflow.do` | Cross-command diagnostic workflow. |
| `test_iivw_exogtest.do` | Exogeneity command behavior and returns. |
| `test_iivw_exogtest_adversarial.do` | Exogeneity failure paths and grouped edge cases. |
| `test_iivw_expanded.do` | Extended integration, state, and helper paths. |
| `test_iivw_failclosed.do` | Missing, stale, and unverifiable contract refusal. |
| `test_iivw_final_adversarial.do` | Cross-surface hostile-input sweep. |
| `test_iivw_fit_adversarial.do` | Outcome-model validation and rollback. |
| `test_iivw_fit_unweighted.do` | Unweighted outcome-model route. |
| `test_iivw_inference_contract.do` | Variance, interval, and failed-replicate contracts. |
| `test_iivw_interval_contract.do` | Visit intervals, censoring rows, and risk sets. |
| `test_iivw_invariance.do` | Point-estimate invariance under visit-covariate transforms. |
| `test_iivw_literature_invariants.do` | Exact identities stated by the source literature. |
| `test_iivw_ownership.do` | Generated-variable ownership and safe replacement. |
| `test_iivw_performance.do` | Runtime guardrails for supported paths. |
| `test_iivw_phase2_contract.do` | Estimator and stabilization contracts. |
| `test_iivw_psdash_contract.do` | Integration with propensity diagnostics. |
| `test_iivw_release_adversarial.do` | Version, package, installed-user, session-state, and documentation release surface. |
| `test_iivw_replay.do` | Estimation replay and interval display. |
| `test_iivw_reporting_exports.do` | Console and Excel report fidelity. |
| `test_iivw_sample_contract.do` | Weighted outcome sample and arm-specific loss. |
| `test_iivw_stacked.do` | Independent reconstruction of the stacked sandwich. |
| `test_iivw_stale_state.do` | Mutated-input signatures and harmless changes. |
| `test_iivw_state_contract.do` | Pipeline characteristic transactions. |
| `test_iivw_tie_default.do` | Efron default and Breslow compatibility route. |
| `test_iivw_ties.do` | Tie-density measurement and notices. |
| `test_iivw_v105_regressions.do` | Historical regression batch. |
| `test_iivw_v106_regressions.do` | Historical regression batch. |
| `test_iivw_v123_regressions.do` | Historical regression batch. |
| `test_iivw_v130_regressions.do` | Historical regression batch. |
| `test_iivw_v131_regressions.do` | Historical regression batch. |
| `test_iivw_v180_regressions.do` | Historical regression batch. |
| `test_iivw_v190_regressions.do` | Historical regression batch. |
| `test_iivw_v191_regressions.do` | Historical regression batch. |
| `test_iivw_v192_regressions.do` | Historical regression batch. |
| `test_iivw_v193_regressions.do` | Historical regression batch. |
| `test_iivw_v194_regressions.do` | Historical regression batch. |
| `test_iivw_v196_regressions.do` | Historical regression batch. |
| `test_iivw_v200_coverage.do` | Version 2 coverage of newly introduced returns and guards. |
| `test_iivw_v200_phase0.do` | Generated-name and convergence transactions. |
| `test_iivw_v200_phase1.do` | Weighting intervals and risk-set semantics. |
| `test_iivw_v200_phase2.do` | Diagnostics and balance redesign. |
| `test_iivw_v200_phase3.do` | Export, labels, and stale-state hardening. |
| `test_iivw_v200_phase3b.do` | Documentation and QA-infrastructure contracts. |
| `test_iivw_v200_qagate.do` | Selector and zero-execution refusal. |
| `test_iivw_v310_regressions.do` | Baseline-event and trimming-unit regressions. |
| `test_iivw_v341_regressions.do` | FIPTIW point-only default and explicit stacked route. |
| `test_iivw_v343_regressions.do` | End-of-follow-up boundary tolerance, and agreement of the `iivw_weight`, `iivw_exogtest` and `iivw_balance` risk sets. |
| `test_iivw_weight_adversarial.do` | Weight construction hostile cases. |
| `test_iivw_weight_validation_guards.do` | Weight-option validation and error codes. |

### Validation

| File | Covers |
|---|---|
| `validation_iivw.do` | Core known-answer identities. |
| `validation_iivw_diagnostics_known_answers.do` | Hand-computable diagnostic outputs. |
| `validation_iivw_expanded.do` | Extended invariants. |
| `validation_iivw_fiptiw_recovery.do` | FIPTIW known-truth recovery and mechanism discrimination. |
| `validation_iivw_inference.do` | Long-running preregistered interval-coverage study. |
| `validation_iivw_iptw_oracle.do` | Stabilized IPTW known-answer oracle. |
| `validation_iivw_known_answers.do` | Additional hand-computable results. |
| `validation_iivw_recovery.do` | Supported-estimator parameter recovery. |
| `validation_iivw_recovery_extended.do` | Legacy recovery construction. |
| `validation_iivw_recovery_extended2.do` | Additional legacy recovery construction. |

### Cross-validation

| File | Covers |
|---|---|
| `crossval_iivw.do` | Weight and outcome parity with `IrregLong`, `survival`, and `geepack`. |
| `crossval_iivw_external.do` | External datasets and independent IPTW/GEE references. |

### Diagnostics and sensitivity scripts

| File | Covers |
|---|---|
| `benchmark_iivw_coverage.do` | On-demand coverage timing; not a correctness gate. |
| `probe_bootstrap_t_screen.do` | Bootstrap-t diagnostic screen. |
| `probe_cr_ladder.do` | On-demand correlation-structure study driver. |
| `probe_jackknife_screen.do` | Jackknife diagnostic screen. |
| `probe_stacked_calibration.do` | Stacked-sandwich calibration probe. |
| `probe_stacked_screen.do` | Stacked-interval diagnostic screen. |
| `probe_stacked_strain.do` | Stacked-sandwich stress probe. |
| `probe_z_toggle.do` | Visit-covariate toggle probe. |
| `sim_scenarios_abc.do` | Post-hoc sensitivity scenarios A–C. |
| `sim_scenario_d.do` | Post-hoc sensitivity scenario D. |
| `sim_scenario_e.do` | Post-hoc sensitivity scenario E. |

### Support

| Path | Contents |
|---|---|
| `_iivw_qa_common.do` | Sandboxed bootstrap, selector, summary, and data builders. |
| `_iivw_cr_ladder.do` | Shared correlation-structure ladder implementation. |
| `run_all.do` | Curated Stata lane manifest and runner. |
| `run_all.sh`, `test_run_all_wrapper.sh` | Reliable shell exit and sentinel gate, plus its regression test. |
| `run_coverage_gate.sh`, `COVERAGE_GATE_RUNBOOK.md` | Block-sharded long-run coverage workflow. |
| `crossval_*.R`, `crossval_irreglong.R` | Independent R reference generators. |
| `*.csv` | Tracked cross-validation inputs and generated reference values. |
| `_skip.txt` | Explicit standard-lane exclusion for the long-running inference gate. |
| `METHOD_CONTRACT.md`, `METHOD_ORACLE_MAP.md`, `CROSSVAL_MODULE_MAP.md` | Method, oracle, and external-module mappings. |
| `COVERAGE_MATRIX_PLAN.md`, `TOLERANCE_FRAMEWORK.md`, `coverage_results/` | Preregistered coverage design and retained evidence. |
| `AUDIT_NOTES.md` | Durable interpretation and historical defect evidence moved out of this runbook. |
| `.gitignore` | Generated-artifact policy. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `iivw` | `test_iivw`, release adversarial | version/distribution invariants | — | installed-user smoke |
| `iivw_weight` | command, adversarial, interval, tie, regression suites | recovery and IPTW/FIPTIW oracles | both cross-validation suites | fit, balance, psdash, diagnostics |
| `iivw_balance` | command, exports, adversarial regressions | known-answer balance checks | — | weighting and diagnostic workflow |
| `iivw_fit` | command, unweighted, inference, stacked, replay, regressions | recovery suites | both cross-validation suites | bootstrap and psdash workflow |
| `iivw_exogtest` | command, adversarial, exports, ties | diagnostic known answers | — | diagnostic workflow |
| `iivw_diagnose` | command, exports, workflow | diagnostic known answers | — | unweighted/weighted/adjusted comparison |

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate. The explicit suite names live only in `run_all.do`.

| Lane | Suites |
|---|---|
| `quick` | Fast public-command, state, recovery, documentation, and release contracts. |
| `core` | `quick` plus supported Stata validation, adversarial, stacked, tie, and regression suites. |
| `full` | `core` plus regenerated R references and both cross-validation suites. |
| `legacy` | Historical recovery constructions, outside the supported-estimator gate. |
| `sensitivity` (`sim`) | Post-hoc scenario envelopes, outside validation lanes. |

## Known gaps

- `validation_iivw_inference.do` is intentionally excluded from standard lanes because its preregistered release mode is a multi-day nested-bootstrap study; run it through `run_coverage_gate.sh` when that gate is authorized.
- `probe_*` and `benchmark_*` scripts are diagnostics, not pass/fail evidence unless their results are promoted through a preregistered gate.

## Audit notes

See [AUDIT_NOTES.md](AUDIT_NOTES.md) for the historical false-green defects, method-evidence boundaries, and links to retained coverage receipts.
