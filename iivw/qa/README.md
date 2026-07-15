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

### Reading the result

`stata-mp -b do` returns shell exit status 0 unconditionally on this platform,
even after `exit 1` or a failed `assert`. **Never gate on `$?`.** Read one of:

- `qa/run_all_status.txt` — first line is `PASS` or `FAIL`
- the final log line — `RUNALL: status=PASS|FAIL suites=N pass=N fail=N`

### Lane dependencies

Each lane needs strictly more than the one before it. A lane whose dependencies
are missing fails loudly; it does not silently skip.

| Lane | Needs | Notes |
|------|-------|-------|
| `quick` | Stata 16+, Python 3 with `openpyxl` | The reporting-export suites open the generated workbooks and inspect cells and styling, so `openpyxl` is a **quick-lane** requirement, not a full-lane one. |
| `sim` | Stata 16+ | Long-form simulation gates (Scenarios A–E). |
| `full` | everything above, plus R with `IrregLong`, `geepack`, `survival`, `nlme`, `ipw`, `cobalt` | `full` regenerates the reference CSVs from the R scripts before comparing. `ipw` and `cobalt` are needed by `crossval_iivw_external_refs.R`; they were once missing from the runner's dependency message, and the external lane false-greened against stale CSVs as a result. |

The `full` lane refuses to continue if either R script fails, rather than
comparing against whatever CSVs happen to be on disk. It detects the failure
with a sentinel file, because Stata's `shell` does not propagate a child's exit
status (`_rc` is 0 even when the command is missing).

## Conventions

- `test_*.do` files cover functional, adversarial, integration, release, and
  version-specific regression behavior.
- `validation_*.do` files use known answers, invariants, and simulated
  parameter-recovery oracles.
- `crossval_*.do` files compare against independently computed R results.
- `sim_*.do` files are long-form simulation gates selected by the `sim` and
  `full` lanes.
- Test files emit a `RESULT: <name> tests=N pass=N fail=N skip=N` sentinel on
  **both** the pass and the fail path, and exit nonzero on failure. The shared
  `iivw_qa_summary` in `_iivw_qa_common.do` is the single place that writes it;
  suites do not hand-roll their own success banner.
- Selectable suites take an optional case selector (`stata-mp -b do suite.do 7`).
  An invalid selector is an **error**, not a silent no-op: `iivw_qa_selector`
  rejects a non-integer or negative value, and `iivw_qa_summary` refuses to call
  a run green when it executed zero cases. Before 2.0.0, `do suite.do 999` ran
  nothing, reported `fail=0`, printed an all-passed banner and exited 0.
- Suites do not write logs, workbooks, or datasets into the package tree. Every
  runtime artifact is staged under `c(tmpdir)` via `tempfile`, and the release
  gate (`test_iivw_release_adversarial.do`) **fails** on any `.log`, `.smcl`,
  `.dta`, or `.xlsx` found in the package or `qa` directory. Cross-validation
  logs carry the local Stata license header, so they are sensitive debris rather
  than mere clutter.
- Every suite sandboxes `PLUS`/`PERSONAL` under `c(tmpdir)` before installing
  (`iivw_qa_sandbox`), so running one standalone cannot rewrite the user's real
  ado tree — which is how an audit run once left `iivw` pointing at `/tmp` and
  removed `tabtools` outright.
- Package paths are stripped by known-suffix **length**, never with
  first-occurrence `subinstr()`. A run from `/tmp/qa-audit-42/iivw/qa` used to
  derive a nonexistent `/tmp-audit-42/iivw`.

## File index

### Phase-1 contract suites (concern-named)

These five are the Gate-1 evidence for the weighting-state contract. They are named for the concern they probe, not for the release that introduced them, and each one is a regression test for a defect confirmed in the 2026-07-14 audit. **30 of their 53 assertions fail against the pre-release build** (the 2026-07-13 development state, before this work), which is what makes them evidence rather than decoration.

- `test_iivw_replay.do` — the bootstrap replay must rebuild the *same estimator* the observed pass built. The oracle is the **identity draw**: resample every subject exactly once, and the recomputed weights must equal the observed weights to `1e-12` (Class E). Against the pre-release build the identity draw was off by **2.2e-01** — a 22% weight error — because `_iivw_bs_refit` passed the precomputed `*_lag1` columns through `visit_cov()` instead of replaying `lagvars()` from the raw sources. Also covers a duplicated-subject draw against an independent reconstruction, and the refusal of a pre-2.0.0 contract that cannot be replayed at all.
- `test_iivw_state_contract.do` — the caller's data, characteristics, active estimates, sort order, and `varabbrev` survive both success and every injected failure. The old bootstrap snapshotted a *hand-maintained list* of characteristics and the list was missing three fields, so a successful `refitweights` run blanked `_iivw_lagvars` and `_iivw_wsig` — and `_iivw_check_weighted` still returned 0 afterwards, because the guard's own evidence had been erased by the same bug.
- `test_iivw_stale_state.do` — the weights must stop describing the data *loudly*. Seventeen mutations: every bound input and owned output edited one at a time, plus dropped/appended/duplicated rows, a permuted weight column, a tampered specification, and a deleted column. Two of them (editing `treat()`, editing a `treat_cov()` value) returned **rc 0** in the pre-release build. Two specificity tests keep the guard honest: a harmless re-sort and an unrelated new variable must still pass.
- `test_iivw_ownership.do` — `replace` may destroy only what iivw made. In the pre-release build a user's own `_iivw_weight = 99` column was backed up and discarded at rc 0, because ownership was inferred from the *name*. It is now a mark carried by the variable.
- `test_iivw_sample_contract.do` — a row with no weight is a row dropped from the fit. Missing weights now error by default; `allowmissingweights` is the acknowledgment; and the loss is reported **by treatment arm**, because differential loss changes the estimand rather than merely the precision.

### Phase-2 contract suite (concern-named)

`test_iivw_phase2_contract.do` is the Gate-2 evidence for the *estimator* contract. Phase 1 made the weighting state replayable but changed no estimator; this suite covers the four defects that did. **11 of its 15 tests fail against the pre-Phase-2 build** (git HEAD, 2026-07-14), and the suite's own header names the four that do not, and says why each is a regression guard rather than a defect detector — a test that passes on the broken code proves nothing about the fix, and pretending otherwise is how a suite inflates its own authority.

The load-bearing oracle is **saturated stabilization**. Set `stabcov()` equal to the full visit model. Bůžková & Lumley (2007, p.8) state the consequence directly — *"When observation–times model covariates Z are a subset of the outcome model covariates X, then the inverse weight ρᵢ(t; γ, h₀) equals one for all individuals at all times"* — and the package reproduces it exactly: the weight is identically 1, to the last bit. A weight vector of all ones reweights nothing, so every target-standardized mean difference must be **0 by algebra**, with no appeal to asymptotics and no Monte Carlo error to hide behind. The pre-Phase-2 build reported **max |TSMD| = 0.3321411** there: a 0.33 "imbalance" for a weight that does not reweight. It was never a balance defect — `iivw_balance` was comparing a *stabilized* observed weight against an *unstabilized* target measure, so the two sides described different populations, and a correctly stabilized IIW was made to look broken.

What else it pins: `treat()` is in the FIPTIW visit-intensity denominator by construction and survives the bootstrap replay; a stabilization numerator outside the outcome design is **refused** before the outcome is fitted; the ambiguous `truncate()` is gone and each component trims separately, keeps its raw column, reports its own cutpoints, and is the weight `iivw_balance` actually describes.

`test_iivw_inference_contract.do` covers what the reported standard error actually is (Phase 3). Its load-bearing find: an incomplete bootstrap used to be silent — a measured probe asked for 40 replicates, 6 failed, and the command printed an SE built from 34 draws with nothing in the output or `e()` to say so; that is now `r(430)`, with `allowfailedreps` as the explicit acknowledgment. It also pins the `vce()` contract that replaces the ambiguous `bootstrap()`/`refitweights` spelling: `vce(bootstrap, reps(#) [seed(#)])` is the refit bootstrap (the recommended method), `vce(bootstrap, reps(#) fixedweights)` holds the weights fixed, and `vce(fixed)` is the analytic sandwich — each mapping to exactly one `e(iivw_vce)`, with malformed and doubled specifications refused. **5 of its 11 tests fail against the pre-Phase-3 build**; the header names the three guards. What it does *not* show: that the default variance is correct. It is not — IIVW-B02 remains open, the default still treats the weights as known, and no coverage simulation has yet run against a preregistered gate.

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
- `test_iivw_release_adversarial.do` — release surface: version/date sync, `.pkg` completeness, dev-path leaks, artifact hygiene, isolated install smoke, and the worked examples from every help file. Also gates **SMCL render integrity**: no help-file line may leave a `{...}` directive open across a newline. `iivw_weight.sthlp` shipped exactly that defect in v2.0.0 (`{it:Mean-1` / `normalization}` split across lines 565-566), which renders the markup literally in the Viewer; every existing content check passed it because all the words were still present, in order. The date sync derives the expected distribution date from `iivw.pkg`, **not** from the `iivw.ado` header date — a doc-only render fix legitimately advances the former while every `.ado` is untouched.
- `test_iivw_literature_invariants.do` — asserts the identities the source papers state, not the ones the code happens to satisfy: `Z ⊆ X` ⇒ stabilized IIW ≡ 1 (B&L p.8), and the stabilized-IPTW mean-one property.
- `test_iivw_reporting_exports.do`
- `test_iivw_v200_qagate.do` — the QA harness's own gates: a bad case selector must error rather than silently run nothing, and a suite that executed zero cases must not be reported green.
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
- `test_iivw_v200_phase3.do` — output, export, and contract hardening: missing
  numeric thresholds, export-only options without `xlsx()`, the return gate on a
  failed export (all three reporting commands), case-insensitive Excel sheet
  lookup, the stale-weight signature, the `treat_cov()` baseline contract, the
  weighted-`mixed` acknowledgment, and a documentation-reality check that runs
  the README Quick Start straight out of the shipped file (H9-H16, H18, C10).
- `test_iivw_v200_phase3b.do` — label serialization, documentation contracts,
  and QA-infrastructure gates: variable and value labels containing `"` or `|`
  round-trip through the indexed `r(*_label_#)` returns and into Excel; the
  border documentation matches the borders the code draws; the selector and
  summary contracts refuse a zero-execution run (proved end to end against a
  real suite); no suite emits prose instead of the `RESULT:` sentinel, derives a
  path with first-occurrence `subinstr()`, or writes an artifact into the tree;
  and the demo stages its assets and publishes atomically (H14, D3, Q5, Q6, Q8,
  Q9, Q12).
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
