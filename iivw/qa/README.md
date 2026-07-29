# iivw QA suite

The `iivw` QA suite is a flat, concern-oriented collection driven by the
curated `run_all.do` runner. It covers all public commands, the weighting and
diagnostic workflow, state preservation, installed-user behavior, numerical
recovery, reporting exports, and independent R parity.

## What the suite actually establishes

A green run demonstrates implementation breadth and known-truth recovery. Interval coverage is measured rather than assumed, and the answer differs by weight type. Naming the gates precisely, because a green count does not distinguish them:

| Gate | Status |
|---|---|
| IIW weights + visit-model coefficient vs `IrregLong` 0.4.1, **exact**, with censoring rows and rebuilt lags | ✅ passes — the strongest evidence the package has |
| Outcome GEE vs R `geepack::geeglm` (Gaussian, logit, Poisson) | ✅ passes |
| Functional / error-path / state coverage across all six commands | ✅ passes |
| **Stabilized ATE IPTW vs an independent implementation** | ✅ **closed (Gate 2A).** Base-R `glm` IPTW oracle, plus a hand-computed saturated fixture exact to `1e-8` and a mean-one identity check |
| **FIPTIW known-truth recovery with mechanism discrimination** (Coulombe Appendix A) | ✅ **closed (Gate 2B).** In the arm where treatment drives both the visit schedule and the outcome, only FIPTIW recovers the truth; naive, IIW-only, and IPTW-only each miss |
| **Treatment present in the FIPTIW visit model** (Coulombe eq. 3.12) | ✅ **detectable.** Removing `treat()` from the visit-intensity model turns `test_iivw_phase2_contract` red |
| **Corrected-variance coverage** (does a 95% CI cover 95% of the time?) | ⚠️ **split result.** IIW 0.939 and IPTW 0.954 met the preregistered rule. For FIPTIW at `n=300`, Wald 0.914, percentile 0.924, basic 0.896, bias-corrected 0.914, and BCa 0.895 all missed the same gate, so the default is point-only. Records: [`RESULT_2026-07-22.md`](coverage_results/RESULT_2026-07-22.md), [`FIPTIW_INTERVALS_2026-07-23.md`](coverage_results/FIPTIW_INTERVALS_2026-07-23.md), [`FIPTIW_NSCALE_2026-07-23.md`](coverage_results/FIPTIW_NSCALE_2026-07-23.md) |
| **Aggregation integrity of the coverage gate itself** | ✅ **closed 2026-07-22.** `test_iivw_coverage_gate.do` proves `combine` refuses a missing interior block, overlapping blocks, and — after a defect found the same day — any pool whose replication count, study size, or seed disagrees with the verdict it would print |

Three pre-registered false-green mutations are recorded in [`METHOD_ORACLE_MAP.md`](METHOD_ORACLE_MAP.md). **All three turn a gate red** — flipping the IIW exponent breaks `validation_iivw_fiptiw_recovery`, dropping `treat()` from the visit model breaks `test_iivw_phase2_contract`, and the third (holding the weights fixed) is discriminated by the coverage run: for IPTW the fixed-weight SE runs 1.31× the empirical SD against the refit bootstrap's 1.02×, exactly the over-coverage direction the tolerance framework preregistered.

Oracle strength, tolerances, and the disposition of every suite are documented in [`METHOD_ORACLE_MAP.md`](METHOD_ORACLE_MAP.md), [`TOLERANCE_FRAMEWORK.md`](TOLERANCE_FRAMEWORK.md), and [`CROSSVAL_MODULE_MAP.md`](CROSSVAL_MODULE_MAP.md).

## How to run

From the package QA directory:

```bash
cd iivw/qa
stata-mp -b do run_all.do quick        # fast contract/release smoke
stata-mp -b do run_all.do core         # all supported Stata gates
stata-mp -b do run_all.do              # core plus fresh R parity
stata-mp -b do run_all.do legacy       # legacy estimator constructions
stata-mp -b do run_all.do sensitivity  # post-hoc simulation envelopes
```

`sim` remains a backward-compatible alias for `sensitivity`. `run_all.do` uses
explicit lane lists and exits nonzero inside Stata when any suite fails.
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
| `quick` | Stata 16+, Python 3 with `openpyxl` | Fast contract/release subset; reporting-export checks inspect workbook cells and styling. |
| `core` | same as `quick` | All supported Stata functional, invariant, recovery, and release gates. |
| `full` | `core`, plus R with `IrregLong`, `geepack`, `survival`, `nlme`, `ipw`, `cobalt` | Regenerates R references before comparing. `ipw` and `cobalt` are required by the external oracle. |
| `legacy` | Stata 16+ | Historical risk-set/recovery constructions, reported but not counted as supported-estimator validation. |
| `sensitivity` (`sim`) | Stata 16+ | Post-hoc simulation envelopes (Scenarios A–E), kept outside validation lanes. |

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
- `sim_*.do` files are long-form sensitivity/regression envelopes selected by
  the `sensitivity` lane (`sim` alias), not by `full`.
- Test files emit a `RESULT: <name> tests=N pass=N fail=N skip=N` sentinel on
  **both** the pass and the fail path, and exit nonzero on failure. The shared
  `iivw_qa_summary` in `_iivw_qa_common.do` is preferred. Older suites may
  calculate their own summary, but the arithmetic, nonzero failure exit, and
  machine-readable sentinel remain mandatory.
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

`test_iivw_inference_contract.do` covers what inference is actually returned (Phase 3). Its load-bearing find: an incomplete bootstrap used to be silent — a measured probe asked for 40 replicates, 6 failed, and the command printed an SE built from 34 draws with nothing in the output or `e()` to say so; that is now `r(430)`, with `allowfailedreps` as the explicit acknowledgment. It pins the `vce()` contract that replaces the ambiguous `bootstrap()`/`refitweights` spelling: `vce(bootstrap, reps(#) [seed(#)])` is the refit bootstrap, `vce(bootstrap, reps(#) fixedweights)` holds the weights fixed, and `vce(fixed)` is the analytic sandwich. I12 proves a bare FIPTIW fit is coefficient-only with no hidden draws and no `e(V)`; I12b proves IIW retains the real 999-draw refit default; I17b distinguishes the point-only notice from explicit nominal-inference warnings. I18–I19 pin the helper's restored panel `e(sample)`, including intermediate outcome/covariate missingness. Nominal coverage is separate evidence: see `coverage_results/RESULT_2026-07-22.md` and `coverage_results/FIPTIW_INTERVALS_2026-07-23.md`. The larger-`n` FIPTIW diagnostic remains in `coverage_results/FIPTIW_NSCALE_2026-07-23.md`; its two `R=200` cells are diagnostics, not new release gates.

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
- `test_iivw_ties.do` — the tie-density axis of the Andersen-Gill visit model. Through 2.4.x `stcox` defaulted to Breslow and both `iivw_weight` and `iivw_exogtest` inherited it; Breslow and Efron agree exactly when no two events share a time and diverge as tie *multiplicity* grows, and every IIW weight is `exp(-xb)` from that fit. Asserts the measurement is arithmetic over the modeled events (entry rows and terminal censoring rows are not events), that the note fires at multiplicity 2 and not below, that `efron` silences the note without silencing the measurement, that `iivw_exogtest` emits it once rather than once per `by()` group, and that a refit bootstrap emits it zero times. T3 and T8(a) are the declared positive controls: continuous times give multiplicity exactly 1 and must stay silent, which is what stops the lazy fix "always warn". Scores **8/8 on 2.4.0 and 2/8 on 2.3.1**; T5 and T7 pass on both by design and are labelled guards, not evidence. **Updated for 3.0.0:** Efron is now the default and `breslow` is the opt-out, so the note's firing rule inverted — every arm that must PRINT the note now asks for `breslow` explicitly, including the T3/T8(a) positive controls, which would otherwise be silent on any build and stop being controls on the *threshold*. The measurement axis this suite owns did not change, so its returns assertions are untouched.
- `test_iivw_tie_default.do` — the tie-method **default** axis, split out from the measurement axis above. Asserts that a bare call fits Efron (anchored to an independent hand-built `stcox ... efron` on the package's own risk set, to 1e-8, not merely to the package's other code path), that `breslow` restores the pre-3.0.0 method, that `efron` survives as an explicit no-op so 2.x do-files keep running, that the stored contract records the *resolved* method so a saved 2.x dataset still replays under Breslow, and that an unthreaded `_iivw_bs_refit` resolves the method from that contract rather than from the current default. T7 discriminates on the coefficient and not on `min_p`, which underflows to 0 on this DGP and made a p-value comparison pass vacuously in the wrong direction. Scores **12/12 on 3.0.0 and 2/12 on 2.4.0**; T4 and T5 pass on both and are labelled guards, because `breslow` is not an option on 2.4.0 and any `rc==198` assertion succeeds there for an unrelated reason.
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
- `test_iivw_v310_regressions.do` — the four 3.1.0 fixes. **T1/T2** retract a claim two user-facing surfaces made and the code never honoured: under `baseline(event)` a first visit at exactly time 0 is excluded from the partial likelihood (its `(0,0]` interval spans no risk time) but still carries a fitted `exp(-xb)`, because `predict, xb` reads covariates and not estimation-sample membership. The runtime note and `iivw_weight.sthlp` both promised "the conventional weight of 1"; measured on the suite's own fixture, 0 of 120 such rows had it and they ranged 0.572-1.757. T1 asserts the message *and* the behaviour, so it cannot pass as a string check against code that has drifted. **T3/T4** pin `trunctreat()` to subject-level percentiles. The IPT weight is estimated once per subject and merged `m:1`, so through 3.0.0 a row percentile made the trim a function of visit density: T3 runs the same 40 subjects twice with subject 1 at 200 and at 2 visits, asserts the raw weight is identical (the premise), and then asserts the cutpoints are too — on 3.0.0 they differed 8.8-fold and the many-visit run left the extreme subject untouched. **T5** pins the `r(refit_n_target_unusable)` contract and the `target_incomplete` gate. **T6** pins the row-count invariant in `iivw_balance`'s baseline-hazard lookup at the *source-structure* axis, because the defect has no external symptom in 3.1.0 — see the axis note in the file. Needles containing a tempvar reference go through the `@BT@`/`@AP@` placeholders, since a backtick in a Stata string literal is a macro reference and would silently shorten the needle. Scores **6/6 on 3.1.0 and 0/6 on 3.0.0** (all six rc=9, observed).
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
- `test_iivw_bs_frame_contract.do` — the bootstrap resampling frame (SOL-02).
  Asserts that a refit draw resamples the visit PANEL, not `iivw_fit`'s outcome
  `e(sample)`, and that the user-facing `e(N)`/`e(sample)` are restored
  afterwards. Scores 3/8 pre-fix, 8/8 after.
- `test_iivw_invariance.do` — the point estimate must not move when a
  visit-model covariate is shifted or rescaled (SOL-01). A Cox model has no
  intercept, so `z -> z + c` leaves the fit unchanged but rescales every
  weight; the old pooled normalization could not undo that because it is a
  change in a ratio. Scores 3/10 against the pre-fix code.
- `test_iivw_coverage_gate.do` — the aggregation contract of the SOL-04 coverage
  gate, which is where a wrong coverage number gets manufactured at `rc=0`.
  Nine arms, ~1.5 s, **4/8 pre-fix → 9/9 post-fix**. Every arm fabricates a
  block pool rather than simulating one: the contract is about which rows are
  present and what they claim about themselves, not about their values, so
  fabricated rows exercise it exactly and cost seconds instead of days. G1–G2
  prove `combine` refuses a missing *interior* block and overlapping blocks;
  G4–G7 prove it refuses a pool whose replication count, study size, or seed
  disagrees with the verdict it would print — the defect found 2026-07-22, where
  one pool certified as both `reps=999` and `reps=10` with identical coverage.
  G9 closes a door the `nsub` diagnostic passthrough opened: a sample-size study block agrees with a gate pool on reps, sims *and* seed and tiles correctly, so the requested `nsub` is stamped too and a gate cell is defined as `nsub=0`. G10 applies the same refusal contract to the FIPTIW propensity-slope multiplier: positivity-stress rows cannot be relabelled as the base cell. G3 is the positive control (without it, every refusal arm would pass on a
  `combine` that refused everything), and G8 bounds the run so a regression that
  makes `combine` re-run the study fails instead of hanging. G1/G2/G3/G8 pass on
  both builds by design — they are regression cover for defects fixed on
  2026-07-21, and their teeth were shown with surgical mutants rather than
  assumed.
- `test_iivw_interval_contract.do` — 15 selected-interval and fail-closed tests for full-refit percentile, reverse-percentile (basic), and BCa limits. It includes `level()` forwarding, no-rerun selection, initial and replayed endpoints, postestimation preservation, safe ado reload with the replay helper resident, fixed- versus refit-jackknife sample contracts, a manual delete-one-subject acceleration oracle, and the coefficient-only FIPTIW default with no `e(V)`.
- `test_iivw_failclosed.do` — Gate 4/5 probes for audit findings SOL-05, SOL-07,
  SOL-08, SOL-11, SOL-12, SOL-13 and SOL-17. **Pre-fix score 1/11, post-fix
  16/16** (same file, both runs), and the single pre-fix pass was S5b, the
  positive control that must be green both ways. Each probe asserts a state the
  shipped build got wrong at `rc=0`: an interaction-only `stabcov()` certified
  as validated; two disjoint equal-N samples decomposed; a noncollapsible logit
  gap reported as an artifact share; a nonconverged Cox counted as "no
  evidence"; a balance verdict issued with no identified person-time target;
  `iivw_balance` mixing a subset refit with full-sample stored weights. S17 is
  the odd one out — it locks behavior the audit proposed **deleting**; see the
  in-file note.
- `test_help_examples.do` — documentation reality tests (SOL-14). Every worked
  sequence in `iivw.sthlp`, `iivw_weight.sthlp` and `iivw_fit.sthlp` is
  transcribed and run from a clean sandboxed PLUS directory, plus a source scan
  proving no shipped example passes an option the package now rejects. H2 runs
  the documented refit-bootstrap default verbatim; the later arms append
  `vce(fixed)` for runtime, which the file explains.
- `test_iivw_weight_adversarial.do` — adversarial probes for `iivw_weight`
  option parsing, weight construction and the name-transaction contract.
- `test_iivw_weight_validation_guards.do` — the `iivw_weight` input guards:
  end-of-follow-up contract, censor()/maxfu() validity, and trimming bounds.

### Validation

- `validation_iivw.do`
- `validation_iivw_diagnostics_known_answers.do`
- `validation_iivw_expanded.do`
- `validation_iivw_fiptiw_recovery.do`
- `validation_iivw_inference.do` — release-only nested coverage simulation. It is intentionally excluded from `run_all.do` because release mode requires at least 1,000 outer simulations with 999 inner bootstrap draws; run it explicitly. `_skip.txt` records the exclusion so it cannot masquerade as ordinary lane coverage. The driver now retains Wald, percentile, basic, bias-corrected, and BCa endpoints plus FIPTIW propensity-slope stress stamps. The interval comparison is `coverage_results/FIPTIW_INTERVALS_2026-07-23.md`; the `n=600`/`n=1200` diagnostic is `coverage_results/FIPTIW_NSCALE_2026-07-23.md`.
- `validation_iivw_iptw_oracle.do`
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
  exits 1 on failure. Their tolerances are post-hoc regression envelopes fitted
  to observed QA-mode runs, so these suites detect implementation drift but do
  not independently validate an estimator.
  - A/B/C and D are **bounded sensitivity scenarios**: the unweighted GEE must miss the
    truth, FIPTIW must remove >60% of that bias and land inside a confirmed
    residual envelope, and FIPTIW's coverage must beat the naive estimator's.
    IIW alone is *not* gated on recovery — it targets the visit process, not the
    treatment confounding induced by latent `u_i`, so it stays biased by design.
  - E is a **documented failure mode**, not a recovery scenario. The artifact is
    outcome-dependent and `test_number` is collinear with follow-up time, so no
    estimator recovers and adjusting for test count drives the marginal slope to
    the wrong sign. Its gates assert the stress bites, the artifact-share
    diagnostic flags it, and nothing escapes a documented bias envelope.
- `benchmark_iivw_coverage.do` — reduced coverage-harness benchmark/pilot; not a release gate and not part of a standard lane.

### Support

- `run_all.do` — curated `quick`, `core`, `full`, `legacy`, and `sensitivity`
  lane runner (`sim` aliases `sensitivity`).
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
| `iivw_weight` | core, expanded, validation guards, adversarial, version regressions, tie density | recovery suites and both cross-validation suites | fit, balance, psdash, diagnostic workflow |
| `iivw_balance` | command, reporting exports, adversarial/version regressions | known-answer balance checks | weighting and diagnostic workflow |
| `iivw_fit` | core, unweighted, adversarial, performance, version regressions | recovery suites and external R parity | fixed/refit-weight bootstrap and psdash workflow |
| `iivw_exogtest` | command, adversarial, reporting exports, tie density | diagnostic known answers | diagnostic workflow |
| `iivw_diagnose` | command, reporting exports, version regressions | diagnostic known answers | unweighted/weighted/adjusted workflow |

## Lane membership

| Lane | Suites |
|---|---|
| `quick` | Fast contract, recovery, documentation, and release subset |
| `core` | All supported Stata functional, invariant, recovery, and release suites |
| `full` | `core` plus both `crossval_*.do` suites; R reference generators run first |
| `legacy` | `validation_iivw_recovery_extended.do`, `validation_iivw_recovery_extended2.do` |
| `sensitivity` (`sim`) | `sim_scenarios_abc.do`, `sim_scenario_d.do`, `sim_scenario_e.do` |

`validation_iivw_inference.do` is outside all standard lanes by design and is listed in `_skip.txt`; its release mode is invoked explicitly when the multi-day inference gate is authorized.
