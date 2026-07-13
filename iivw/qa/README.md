# iivw QA suite

The `iivw` QA suite is a flat, concern-oriented collection driven by the
curated `run_all.do` runner. It covers all public commands, the weighting and
diagnostic workflow, state preservation, installed-user behavior, numerical
recovery, reporting exports, and independent R parity.

## How to run

From the package QA directory:

```bash
cd iivw/qa
stata-mp -b do run_all.do quick   # Stata functional, validation, and release gate
stata-mp -b do run_all.do         # full gate, including simulations and R parity
stata-mp -b do run_all.do sim     # simulation scenarios A-E only
```

`run_all.do` uses explicit lane lists and exits nonzero when any suite fails.
Every `test_*.do`, `validation_*.do`, and `crossval_*.do` file is independently
runnable from this directory. Individual suites perform a targeted local
reinstall so an older SSC/GitHub copy cannot shadow the package under review.

## Conventions

- `test_*.do` files cover functional, adversarial, integration, release, and
  version-specific regression behavior.
- `validation_*.do` files use known answers, invariants, and simulated
  parameter-recovery oracles.
- `crossval_*.do` files compare against independently computed R results.
- `sim_*.do` files are long-form simulation gates selected by the `sim` and
  `full` lanes.
- Test files emit a `RESULT: ... tests=N pass=N fail=N` sentinel and exit
  nonzero on failure.
- Disposable logs and workbooks are runtime artifacts, not fixtures. Paths are
  derived from `c(pwd)` or `c(tmpdir)`.

## File index

### Functional and regression tests

- `test_iivw.do`
- `test_iivw_balance.do`
- `test_iivw_diagnose.do`
- `test_iivw_diagnostic_workflow.do`
- `test_iivw_exogtest.do`
- `test_iivw_exogtest_adversarial.do`
- `test_iivw_expanded.do`
- `test_iivw_final_adversarial.do`
- `test_iivw_fit_adversarial.do`
- `test_iivw_fit_unweighted.do`
- `test_iivw_performance.do`
- `test_iivw_psdash_contract.do`
- `test_iivw_release_adversarial.do`
- `test_iivw_reporting_exports.do`
- `test_iivw_v105_regressions.do`
- `test_iivw_v106_regressions.do`
- `test_iivw_v123_regressions.do`
- `test_iivw_v130_regressions.do`
- `test_iivw_v131_regressions.do`
- `test_iivw_v180_regressions.do`
- `test_iivw_v190_regressions.do`
- `test_iivw_v191_regressions.do`
- `test_iivw_v192_regressions.do`
- `test_iivw_v193_regressions.do`
- `test_iivw_v194_regressions.do`
- `test_iivw_v196_regressions.do`
- `test_iivw_v200_phase0.do` — generated-variable transaction, categorical dummy
  names, nonconvergence-is-an-error, QA gate integrity (C3, C4, C9, Q1, Q4).
- `test_iivw_v200_phase1.do` — weight contracts: the terminal at-risk interval,
  the risk-set specification, and the entry/baseline semantics (C1, C5-C7, H17).
- `test_iivw_v200_phase2.do` — diagnostics redesign: the target-SMD balance
  verdict, the IIW component, ESS, exogeneity conditioning and Holm adjustment,
  and the iivw_diagnose comparability gate (C2, C8, H1-H7).
- `test_iivw_v200_coverage.do` — surface added in Phases 0-2 that no other suite
  exercised: the convergence guard, the nonconverged-weight taint (and that
  `iivw_fit` does not launder it), the refit counts, the risk-set returns, and
  `censor()`/`maxfu()` on `iivw_exogtest`.
- `test_iivw_weight_adversarial.do`
- `test_iivw_weight_validation_guards.do`

### Validation

- `validation_iivw.do`
- `validation_iivw_diagnostics_known_answers.do`
- `validation_iivw_expanded.do`
- `validation_iivw_known_answers.do`
- `validation_iivw_recovery.do`
- `validation_iivw_recovery_extended.do`
- `validation_iivw_recovery_extended2.do`

### Cross-validation and simulations

- `crossval_iivw.do` — IIW and FIPTIW parity against generated R references.
- `crossval_iivw_external.do` — external dataset parity against R survival,
  GEE, mixed-model, and propensity-score workflows.
- `sim_scenarios_abc.do`, `sim_scenario_d.do`, `sim_scenario_e.do` — simulation
  scenarios for visit-process, treatment, and measurement-artifact behavior.
  Each emits the standard `RESULT: <name> tests=N pass=N fail=N` sentinel and
  exits 1 on failure. Tolerances are set from observed runs, not guessed, and
  recorded in each file's header table.
  - A/B/C and D are **bounded recovery gates**: the unweighted GEE must miss the
    truth, FIPTIW must remove >60% of that bias and land inside a confirmed
    residual envelope, and FIPTIW's coverage must beat the naive estimator's.
    IIW alone is *not* gated on recovery — it targets the visit process, not the
    treatment confounding induced by latent `u_i`, so it stays biased by design.
  - E is a **documented failure mode**, not a recovery scenario. The artifact is
    outcome-dependent and `test_number` is collinear with follow-up time, so no
    estimator recovers and adjusting for test count drives the marginal slope to
    the wrong sign. Its gates assert the stress bites, the artifact-share
    diagnostic flags it, and nothing escapes a documented bias envelope.

### Support

- `run_all.do` — curated `quick`, `full`, and `sim` lane runner.
- `crossval_irreglong.R`, `crossval_fiptiw.R`, and
  `crossval_iivw_external_refs.R` — independent R reference generators.
- `tools/check_iivw_xlsx.py` and `tools/check_iivw_style.py` — workbook content
  and style validators.
- The tracked CSV files are cross-validation inputs or generated reference
  values with companion R scripts in this directory.

## Coverage map

| Command | Functional coverage | Validation / parity | Cross-command coverage |
|---|---|---|---|
| `iivw` | `test_iivw.do`, release adversarial | version and distribution checks | installed-user smoke |
| `iivw_weight` | core, expanded, validation guards, adversarial, version regressions | recovery suites and both cross-validation suites | fit, balance, psdash, diagnostic workflow |
| `iivw_balance` | command, reporting exports, adversarial/version regressions | known-answer balance checks | weighting and diagnostic workflow |
| `iivw_fit` | core, unweighted, adversarial, performance, version regressions | recovery suites and external R parity | fixed/refit-weight bootstrap and psdash workflow |
| `iivw_exogtest` | command, adversarial, reporting exports | diagnostic known answers | diagnostic workflow |
| `iivw_diagnose` | command, reporting exports, version regressions | diagnostic known answers | unweighted/weighted/adjusted workflow |

## Lane membership

| Lane | Suites |
|---|---|
| `quick` | All functional and validation files listed above, excluding R cross-validation and simulation scripts |
| `full` | `quick` plus the three simulation scripts and both `crossval_*.do` suites; R reference generators run first |
| `sim` | `sim_scenarios_abc.do`, `sim_scenario_d.do`, `sim_scenario_e.do` |
