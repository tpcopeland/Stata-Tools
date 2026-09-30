# iivw QA

archetypes: A3(iivw_weight iivw_fit iivw_balance iivw_exogtest iivw_diagnose iivw_bspool)

Canonical fixture adoption is in progress. Predictable visit intensity and analytic full-data mean recovery at two seeds; weight, unweighted/fixed-sandwich fit and replay, balance, exogeneity, overview and decomposition numeric/state contracts. Long-name fit invariance uses the shared primitive. Shard pooling and additional weight/inference routes remain uncovered by these new canonical suites. Frozen generators and state/primitive helpers are byte-vendored from the devkit. New fixture suites join the core/full lane (full only where the runner has no core lane); additional route/minimum/domain cells reported by the fixture census remain explicit, and this declaration does not certify them.

New suite index: `test_fixture_names.do`, `validation_fixture_recovery.do`.

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
| `full` | `core`; R with `haven`, `IrregLong`, `geepack`, `survival`, `nlme`, `ipw`, and `cobalt` | hard failure before stale CSVs can be used |
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
| `test_iivw_hostile.do` | Hostile-input and rollback checks across the public workflow. |
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
| `test_theme_removed.do` | Removed theme() parser rejection for reporting commands. |
| `test_iivw_sample_contract.do` | Weighted outcome sample and arm-specific loss. |
| `test_iivw_nullcase.do` | Degenerate-artifact (fail-open) contracts. Commit contract (Rule 15): a FIPTIW run whose visit- and treatment-model complete-case sets are disjoint is refused instead of committing an all-missing weight variable and its signed contract, `allowmissingweights` still accepts partial loss, and the `_iivw_assert_cardinality` helper contract. Resolve contract (Rule 14): `iivw_diagnose` refuses stored estimates carrying no `e(depvar)`/`e(cmd)` — the comparability gate compares those fields across the three roles, so three estimates carrying neither passed it on `"" == ""` — and `iivw` refuses an `iivw.ado` whose `*!` header has no readable version instead of reporting `r(version)` as `unknown`. Each refusal is paired with a positive control that must still succeed. |
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
| `test_iivw_v401_regressions.do` | Baseline-event missing-weight refusal and demo return/state regressions. |
| `test_iivw_v413_regressions.do` | Stacked Wald limits are formed from the posted covariance at two confidence levels and agree with the Wald replay; finite edits to a saved score column, derivative cell, or inverse-information metadata are refused, with an untouched-contract control. |
| `test_iivw_v432_regressions.do` | 4.3.2 regressions (7 cases, `core`, all red on 4.3.1). `iivw_weight` leaves unstset data unstset (IIW and FIPTIW with `scores`) and a user's own `stset` characteristics, `stdescribe` totals and `_t` unchanged; `iivw` `r(n_commands)` equals the six listed commands, each with a help file; `title()`/`footnote()` holding `$name`, `` `name' ``, double quotes or an unbalanced backtick reach workbook A1 and the footnote cell byte for byte in `iivw_balance`, `iivw_exogtest` and `iivw_diagnose`; variable and value labels holding them reach the `iivw_balance` and `iivw_exogtest` workbooks and `r(term_label_#)`/`r(group_label_#)` unexpanded; `iivw_bspool, saving()` writes, stamps and returns the literal name for a comma, `$name`/`` `name' `` and an unbalanced backtick, and writes nothing under an expanded name; `truncvisit()`/`trunctreat()` counts, `r(trunc_visit_lo/hi)` and clipped values equal those at the exact `_pctile` cutpoint over eight draws, and the `iivw_balance` replay reproduces the trimmed weight exactly. Every expected string is built from `char()` codes in Mata. |
| `test_iivw_v420_shard.do` | Sharded bootstrap contract (23 cases). One run's draws split and re-pooled are bit-identical, and `e(V)` equals the covariance of the pooled draws computed independently. Substreams are independent and each replays exactly; `seed()` and `rngstream()` reproduce from any prior session state, with the target substream deliberately pre-advanced, and the caller's generator is restored. Pooling refuses a disagreeing weight contract, coefficient set, duplicate RNG state, repeated file, unstamped file, truncated file, BCa shards, an unpoolable `citype()`, a non-`iivw_fit` anchor, data reweighted since the fit, and a failed `reps()` assertion. Failures sum and gate on the pooled total; nine shards of 111 pool to 999 and lift the low-reps stamp while an unrecognized stamp dominates. `citype()`, `level()` and `saving()` are covered, a saved pooled file re-pools, data-free pooling works, and 9x111 agrees with 1x999 inside a 3-MCSE band. A bad `saving()` target fails before any pooling work and a failed write never strands the pooled `e()`. T21 and T22 are red on 4.1.3: a stored non-default-level interval refused its own bare replay, and an omitted `level()` took the session default rather than the shards'. |
| `test_iivw_codexaudit_2026_09_27_a.do` | 2026-09-27 audit estimator/diagnostic regressions (11 cases). Entry-only subjects' visit-model scores match an independent full-risk-set Efron fit; `vce(stacked)` equals an independent two-step sandwich over outcome plus nuisance-only subjects, with and without missing outcomes; a restored fit refuses `predict` (r(459)) after a later fit rebuilt its categorical-time columns, while its own design predicts correctly after sort/restore; missing `offset()`/`exposure()` rows leave `e(sample)`/`e(N)` on the fixed, point-only and refit routes; cluster nesting is judged on the resampled rows only (shuffled, with a genuine-crossing negative control); `iivw_diagnose` consumes a stored percentile interval and refuses another level, withholds shares under `force` and `exogeneity(endogenous)` in `r(decomp)` and workbook cells, and refuses omitted and base-level coefficients. |
| `test_iivw_codexaudit_2026_09_27_b.do` | 2026-09-27 audit shard/pool regressions (11 cases), all on genuine shards. Pooling refuses equal-b/equal-N shards from different outcome data (unweighted and IPTW), a live weight input or outcome edited after the fit, and an anchor whose own shard is absent; saved pools keep component lineage so AB+B and AB+A are refused while AB+CD pools; `saving(x.dta)` stamps and pools x.dta beside an x.dta.dta; native `e(N_reps)`/`e(ci_percentile)`/`estat bootstrap` describe the pooled draws; fractional levels replay and pool; `demo/shard_driver.do` fails rather than pool a previous run's artifacts (spawns child `stata-mp`). |
| `test_iivw_route_grid.do` | Route × condition contract grid for `iivw_fit` and `iivw_bspool` (117 cells, `core`). Nine inference routes (`vce(fixed)`, `vce(stacked)`, fixed-weight and refit bootstrap, `citype(none)`, `citype(percentile)`, `iivw_bspool` pool, `model(mixed)`, `unweighted`) × thirteen conditions (none, `if`/`in`, whole-subject and partial missing outcome, missing covariate, missing `offset()`, entry-only subjects, `cluster()` above the subject with last rows excluded and rows shuffled, string id, `level(95.5)`, restore after a later fit, weight input edited after weighting, documented `e()` surface). Every cell ends EQUAL or REFUSED with a declared rc. An EQUAL cell asserts `e(sample)` row by row against a marker built from the fixture design (never from `e(sample)` or `touse`), `e(N)`, cluster counts, `e(b)`, the route's V oracle (independent `glm`/`mixed`; an independent-Cox two-step sandwich over the design union for `stacked`; the same seeded `bootstrap` around `glm` for fixed weights; the covariance and quantiles of the saved draws for refit, percentile and pooled), `e(iivw_ci)`, and every result `iivw_fit.sthlp` documents without a route qualifier. Cells that a known open package bug breaks are held in an in-file open ledger and must fail at the recorded step (empty on 4.3.1; see Known gaps). The suite fails if one of them passes or fails anywhere else. It prints a receipt of route rows × condition columns. Replayed at pre-fix `166dfd10` (4.2.0), the F01, F02, F09 and F13 cells fail at the V, cluster-count, sample and fit steps respectively. |
| `test_iivw_route_grid_fixes.do` | 4.3.1 regressions for the route-grid findings (10 cases, `core`, all red on 4.3.0). Refit, percentile and `model(mixed)` refit bootstraps report `e(sample)`/`e(N)`/`e(iivw_outcome_nclust)` equal to a design-built marker under missing outcomes and covariates; a `timespec(categorical)` level seen only on missing-outcome rows builds no omitted column under `vce()`; `e(iivw_outcome_nclust)` is posted and correct on all seven routes at subject and clinic level; `vce(stacked)` with a string id reproduces the numeric-id result; `vce(stacked), cluster(clinic)` equals an independent-Cox two-step sandwich summing subject scores per cluster (and not the one-subject-per-cluster twin), and a subject spanning clusters is refused as a nesting failure; point-only fits post `e(iivw_predict)` and refuse `predict` over rebuilt design columns (r(459)); `geeopts()` under `model(mixed)` and `mixedopts()` under `model(gee)` are refused (r(198)) with the caller's state unchanged. |
| `test_iivw_state_lifecycle.do` | Session fingerprint (`_qa_state.do`) of all seven public commands on a success and an early-error path (foreign `regress` e() with a predict round trip, user matrix/scalar/global, `varabbrev on`); lifecycle (`qa_lifecycle`) for `iivw_fit` (categorical-time fit A, later-support fit B, restore A: F03), `iivw_weight` (reweighted fit B) and `iivw_diagnose`; `qa_lifecycle_pool` on genuine bootstrap shards (A+B, AB, AB+B, AB+A, AB+CD, failed rerun, `x.dta` beside `x.dta.dta`: F05, F06); `qa_counterfeit_twin` shards with equal b and N (F04). `core`. At pre-fix `166dfd10` it fails F03, F04, F05 and F06. Its `iivw_weight` block was open on 4.3.1 (the `stset` leak) and is closed in 4.3.2. |
| `test_iivw_surfaces.do` | Surface parity (`qa_surface_parity`) across `r()`/`e()`, workbook and console for all seven commands, against independent oracles where one exists (`summarize`, `glm [pw]`, the appended draw files, the stored percentile interval); withheld endogenous shares (F11); pooled draw count and percentile limit (F08); diagnosis interval (F10); `qa_hostile_times` as visit times with an order-invariance oracle through `iivw_weight`, `iivw_balance`, `iivw_exogtest` and `iivw_fit`; the `qa_hostile_strings` corpus through `title()` and `saving()`. `core`. At `166dfd10` it fails F08, F10 and F11. The four blocks that held open findings on 4.3.1 are closed in 4.3.2. |
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
| `validation_iivw_links_known_answers.do` | Exact Poisson-log quadratic-time and binomial-logit outcome-model solutions. |
| `validation_iivw_recovery.do` | Legacy end-at-last-visit recovery construction. |
| `validation_iivw_recovery_extended.do` | Legacy recovery construction. |
| `validation_iivw_recovery_extended2.do` | Additional legacy recovery construction. |

### Cross-validation

| File | Covers |
|---|---|
| `crossval_iivw.do` | Freshly regenerated weight and outcome parity with `IrregLong`, `survival`, `geepack`, and a local simplified Tompkins-informed transcription. |
| `crossval_iivw_external.do` | External datasets and independent IPTW/GEE references. |
| `crossval_iivw_dta.do` | Fresh `.dta` exchange parity for baseline-event Efron weights and independence-GEE point estimates and sandwich SEs. |
| `crossval_iivw_pbcseq.do` | Mayo PBC sequential-study parity for subject-specific censoring, lagged-outcome IIW, quadratic-time GEE, and exogeneity diagnostics. |

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
| `iivw_weight` | command, adversarial, interval, tie, regression suites | recovery and IPTW/FIPTIW oracles | all cross-validation suites | fit, balance, psdash, diagnostics |
| `iivw_balance` | command, exports, adversarial regressions | known-answer balance checks | — | weighting and diagnostic workflow |
| `iivw_fit` | command, unweighted, inference, stacked, replay, regressions; route grid 117 cells (117 EQUAL or REFUSED, 0 open); `test_iivw_route_grid_fixes` | recovery and canonical-link known answers | all cross-validation suites | bootstrap and psdash workflow |
| `iivw_exogtest` | command, adversarial, exports, ties | diagnostic known answers | `crossval_iivw_pbcseq` | diagnostic workflow |
| `iivw_diagnose` | command, exports, workflow | diagnostic known answers | — | unweighted/weighted/adjusted comparison |
| `iivw_bspool` | `test_iivw_v420_shard`, `test_iivw_codexaudit_2026_09_27_b`, route grid `bspool` row (13 cells) | pooled covariance equals the hand-computed replicate covariance (T19); split-and-repool is bit-identical (T1) | — | `demo/shard_driver.do` (C11), help examples |

Adversarial axes, in cells (`check qa iivw --view axes`: 36/36 owed cells probed): route grid 2/2; fingerprint 7 commands × 2 paths; lifecycle 4/4 (`iivw_fit`, `iivw_weight`, `iivw_diagnose`, and `iivw_bspool` through 7/7 pool scenarios); parity 7/7; hostile strings 5/5; hostile fixtures 4/4. `demo/shard_driver.do` stale artifacts (F07) are pinned only by `test_iivw_codexaudit_2026_09_27_b.do` C11, which launches child Stata processes; the pool block's failed-rerun scenario is declared accept, since a genuine earlier shard file cannot be told from a fresh one at pool level.

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate. The explicit suite names live only in `run_all.do`.

| Lane | Suites |
|---|---|
| `quick` | Fast public-command, state, recovery, documentation, and release contracts. |
| `core` | `quick` plus supported Stata validation, adversarial, stacked, tie, and regression suites. |
| `full` | `core` plus regenerated R references and all cross-validation suites. |
| `legacy` | Historical `validation_iivw_recovery*` constructions, outside the supported-estimator gate. |
| `sensitivity` (`sim`) | Post-hoc scenario envelopes, outside validation lanes. |

## Known gaps

- `validation_iivw_inference.do` is intentionally excluded from standard lanes because its preregistered release mode is a multi-day nested-bootstrap study; run it through `run_coverage_gate.sh` when that gate is authorized.
- Route-grid open ledger (`test_iivw_route_grid.do`): empty on 4.3.1, 117/117 cells EQUAL or REFUSED. The 17 cells it held on 4.3.0 (I1, N1-N4) are fixed and pinned by `test_iivw_route_grid_fixes.do`.
- The route grid has no quick-lane diagonal subset yet. The full grid runs in `core` and `full`.
- The four findings the 4.3.1 lifecycle and surfaces suites held open (the `iivw_weight` `stset` leak, `title()` re-expansion, `iivw_bspool, saving()` re-expansion, and `r(n_commands)` = 5) are fixed in 4.3.2; both open ledgers are empty and `test_iivw_v432_regressions.do` pins them. `iivw_fit, saving()` only inherits Stata's own `bootstrap, saving()` grammar, which expands `$`/backtick names itself (checked against native `bootstrap`), so it is not counted.
- `iivw_fit` keeps a session counter in the global `IIVW_FIT_SERIAL`, and official `glm` leaves `$GLIST`; the fingerprint blocks exempt both by name (and Stata's `S_#`/`S_E_*` saved-result globals) and hold every other global to no change.
- `probe_*` and `benchmark_*` scripts are diagnostics, not pass/fail evidence unless their results are promoted through a preregistered gate.

## Audit notes

See [AUDIT_NOTES.md](AUDIT_NOTES.md) for the historical false-green defects, method-evidence boundaries, and links to retained coverage receipts.

`test_fixture_state.do` checks exact caller column order, data, active estimates and session state after stored-estimate diagnosis on friendly and unsorted VISIT fixtures, with present/absent active estimates and success/refusal.
