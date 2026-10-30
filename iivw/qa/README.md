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

Suites sandbox `PLUS` and `PERSONAL` under `c(tmpdir)` and install from the local package tree. Scratch copies must include the sibling `_data/` directory and `tabtools/` package used by installed export smokes.

## Conventions

archetypes: A3(iivw_weight iivw_fit iivw_balance iivw_exogtest iivw_diagnose iivw_bspool)

- `test_*` covers functional, adversarial, integration, release, and regression behavior; `validation_*` uses known-answer, invariant, or simulated-truth oracles; `crossval_*` compares with independent R implementations; `benchmark_*` and `probe_*` are diagnostics outside correctness lanes.
- Every curated suite ends with one `RESULT: <name> tests=N pass=N fail=N [skip=N]` sentinel and exits nonzero on failure. `full` accepts no skips.
- Suites sandbox `PLUS` and `PERSONAL` via `_iivw_qa_common.do`, then install the package from `../`; the user's ado tree is not touched.
- Paths derive from `c(pwd)` or the script location; no suite uses a machine-local checkout path.
- Functional data are generated from fixed seeds; tracked CSV fixtures are independent R reference outputs with their generators beside them.
- Generated logs, datasets, workbooks, graphs, and sentinel files are gitignored. Tracked coverage results are preregistered evidence, not disposable runtime artifacts.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| `quick` | Stata 16+; Python 3 with `openpyxl`; Rscript (base R) for the independent IPTW oracle | hard failure |
| `core` | `quick`; NumPy in Stata's configured Python interpreter; R packages `haven` and `clubSandwich` for the CR ladder; Stata's Python (`hashlib`) for the NHEFS fixture SHA-256 check | hard failure |
| `full` | `core`; R packages `IrregLong`, `geepack`, `survival`, `nlme`, `ipw`, `cobalt`, `geex`, and `dplyr` | hard failure before stale CSVs can be used |
| `crossval_iivw_published_tompkins-2025-smmr.do` (`full`) | network access to GitHub to fetch the authors' code at the pinned commit | hard failure: the suite exits 198, never passes offline |
| `validation_iivw_exogtest_calibration.do` | Rscript (base R `p.adjust`) for the Holm parity, gate and `smoke` forms | hard failure |
| installed export smoke | sibling `tabtools/` checkout | hard failure |
| `legacy`, `sensitivity` | Stata 16+; `sensitivity` also needs Rscript for the exogtest calibration gate | hard failure |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_fixture_names.do` | Long-name fit invariance using the shared canonical primitive. |
| `test_fixture_state.do` | Stored-estimate diagnosis preserves original variable order, data, estimates and session state on success/refusal. |
| `test_fixture_balance_state.do` | Native, opaque, absent and empty global controls with next native ttest and outcome predictions. |
| `test_fixture_weight_state.do` | Native global boundaries, named separating-FIPTIW refusal and late owned-column rollback fault. |
| `test_fixture_exog_state.do` | Exogeneity native globals on analytical success and named late worksheet refusal; exact original data and non-r caller state, then next native predictions. Analytical r() and the generated column intentionally survive late export refusal. |
| `test_fixture_font_tokens.do` | Entire unbound macro-token font payloads are preserved as workbook style bytes. |
| `test_fixture_font_forms.do` | Actual workbook fonts for bare, quoted, nested, Unicode and opaque byte forms across reporting commands. |
| `test_help_examples.do` | Shipped help examples and documentation contracts. |
| `test_iivw.do` | Public workflow, options, errors, returns, and session state. |
| `test_iivw_balance.do` | Balance diagnostics, returns, and state preservation. |
| `test_iivw_qa29_returns.do` | Stored-result contract closure: `iivw_bspool` native `e(b_bs)`, `e(bias)`, `e(se)`, `e(z0)`, `e(ci_normal)`, `e(ci_bc)`, `e(reps)` against [R] bootstrap formulas recomputed in Mata from the pooled draws (including tied draws), BCa locals cleared after a pool and re-pool; `iivw_fit` `e(depvar)`, `e(iivw_design_vars)`, `e(iivw_expr#)`, `e(iivw_design_token)` across routes, design changes, replay and refusals; a refused post-engine fit restores the caller's `e()` on the analytic, fixed-weight and refit bootstrap routes; `e(estat_cmd)`/`e(iivw_estat)` and estat dispatch; an omitted term agrees exactly between the unsharded fit and split-and-repool (R9); regression: a retained term whose Wald variance is exactly zero gets missing endpoints and a note on `iivw_fit` and the `iivw_bspool` pool, where both posted [b, b] silently (R10). |
| `test_iivw_qa29_bspool_nullcase.do` | `iivw_bspool` degenerate inputs: empty, blank and missing file lists; zero- and one-draw shards; all-missing draws; exactly one failed draw; dropped, permuted and renamed coefficient columns; foreign, absent, non-bootstrap and different-data anchors; anchor/shard estimate disagreement; missing marker, lineage and nonnumeric stamps. Each asserts the exact rc, message and an unchanged anchor `e()`. |
| `test_iivw_bs_frame_contract.do` | Bootstrap panel frame and restored outcome sample. |
| `test_iivw_coverage_gate.do` | Coverage-pool aggregation and claim consistency. |
| `test_iivw_cr_ladder.do` | Correlation-structure ladder arithmetic. |
| `test_iivw_diagnose.do` | Diagnostic decomposition command. |
| `test_iivw_diagnostic_workflow.do` | Cross-command diagnostic workflow. |
| `test_iivw_exogtest.do` | Exogeneity command behavior and returns. |
| `test_iivw_exogtest_adversarial.do` | Exogeneity failure paths and grouped edge cases. |
| `test_iivw_exogtest_separation_regress.do` | Mata-level regression cells for the exogtest separation check (`_iivw_cox_recession`; 26 cells): heavy 205/594 and collinear 74 false positives, collinear 27/42/427 misses, heavy 8 and 334, weak2 at N = 10,000, rank-deficient pair rows, two problems beyond the exhaustive route (`data/iivw_sep_med_cases.csv`), sortrngstate independence, exact power-of-two scalings (a 2^k-scaled case and six scalings of the certified heavy/cont corpora), the search route alone on the certified corpus (`route = 1`: settle bound and four pinned cases), integer-combination separations (`data/iivw_sep_intdir_cases.csv`), the error-free arithmetic, exact 2^k, the O(rows) Stiemke residual against a pair sum, and a `matastrict` compile. Each verdict is asserted against an exact rational certificate. |
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
| `test_iivw_v437_ordinal.do` | 4.3.7 regressions (3 cases, red on 4.3.6 except the non-integer guard). The trimming message names percentiles with correct ordinals: 1st/2nd/3rd, 11th to 13th, 21st, one-sided wording, and a non-integer 2.5th. |
| `test_iivw_quiet_output.do` | Console output contract (8 cases, `quick`; T1-T6 red on the pre-release build). Typical `iivw_weight` (IIW, FIPTIW with `stabcov()`), `iivw_balance` (with and without `agrefit`), `iivw_exogtest`, `iivw_fit` (fixed and shard bootstrap) and `iivw_bspool` calls are logged and the log must hold none of the internal-machinery strings: `real change(s) made`, `observations created/deleted`, `missing values generated`, `stset` settings, tempfile `saved as .dta`, the `merge` result table, `(bootstrap: ...)`, `(results ... are active now)` and the internal st header; under `nolog` also no nuisance-model table or iteration log. Positive controls: without `nolog` the visit, stabilization and treatment fits are displayed; the Breslow tie warning and a failed visit model's error still reach the console, and under `nolog` a covariate the visit or treatment model omitted (collinear) is named in a note, with a no-omission negative control. |
| `test_iivw_v100_regressions.do` | 1.0.0 review regressions (9 cases, `core`; T1, T2 and T5-T9 red on the pre-release build, T3-T4 guards). `iivw_fit, saving()` with a base-name suffix longer than 10 characters (`x.000002_quiet_sh1`) is written as typed and stamped (it exited r(601) after a completed bootstrap: Mata `pathsuffix()` returns empty for such suffixes, so the stamp looked for `name.dta`); `iivw_bspool` reads and writes such names by the same rule; undotted base names, including inside a dotted directory, still take `.dta`; a `saving()` name ending in a period (Stata writes `x.` as `x`) is written, stamped and pooled; the removed `bootstrap(#)` and `refitweights` options exit `r(198)` and the `vce(bootstrap, reps(#) fixedweights)` spelling still runs; the removed `model()`, `mixedopts()` and `experimentalmixed` options exit `r(198)` and a GEE fit records `e(iivw_model)`=`gee`; `iivw_exogtest` term p-values equal 2·normal(−|b/se|) from `r(results)` exactly, `r(joint_min_p)` matches chi2tail(1, (b/se)²) within 1e-14 relative (it was off by 4.6e-14 when carried through macros), and `r(holm_min_p)` equals min(1, m·`r(joint_min_p)`) exactly; the removed `experimentalnotreatvisit` option exits `r(198)`, a pre-release contract marked `_iivw_treat_in_visit`=0 is refused (459) by `iivw_fit` and `iivw_balance`, and reweighting clears the marker; `iivw_bspool` against such a contract names that cause instead of reporting that the data changed. |
| `test_iivw_readme_sequence.do` | Extracts the README Quick Start and every Worked Example block and runs them in one session under sysdir sandboxes (red on 4.3.7 drafts without the Example 5 reweighting line: r(198) from the stabilized-weights refusal). |
| `test_iivw_v420_shard.do` | Sharded bootstrap contract (23 cases). One run's draws split and re-pooled are bit-identical, and `e(V)` equals the covariance of the pooled draws computed independently. Substreams are independent and each replays exactly; `seed()` and `rngstream()` reproduce from any prior session state, with the target substream deliberately pre-advanced, and the caller's generator is restored. Pooling refuses a disagreeing weight contract, coefficient set, duplicate RNG state, repeated file, unstamped file, truncated file, BCa shards, an unpoolable `citype()`, a non-`iivw_fit` anchor, data reweighted since the fit, and a failed `reps()` assertion. Failures sum and gate on the pooled total; nine shards of 111 pool to 999 and lift the low-reps stamp while an unrecognized stamp dominates. `citype()`, `level()` and `saving()` are covered, a saved pooled file re-pools, data-free pooling works, and 9x111 agrees with 1x999 inside a 3-MCSE band. A bad `saving()` target fails before any pooling work and a failed write never strands the pooled `e()`. T21 and T22 are red on 4.1.3: a stored non-default-level interval refused its own bare replay, and an omitted `level()` took the session default rather than the shards'. |
| `test_iivw_codexaudit_2026_09_27_a.do` | 2026-09-27 audit estimator/diagnostic regressions (11 cases). Entry-only subjects' visit-model scores match an independent full-risk-set Efron fit; `vce(stacked)` equals an independent two-step sandwich over outcome plus nuisance-only subjects, with and without missing outcomes; a restored fit refuses `predict` (r(459)) after a later fit rebuilt its categorical-time columns, while its own design predicts correctly after sort/restore; missing `offset()`/`exposure()` rows leave `e(sample)`/`e(N)` on the fixed, point-only and refit routes; cluster nesting is judged on the resampled rows only (shuffled, with a genuine-crossing negative control); `iivw_diagnose` consumes a stored percentile interval and refuses another level, withholds shares under `force` and `exogeneity(endogenous)` in `r(decomp)` and workbook cells, and refuses omitted and base-level coefficients. |
| `test_iivw_codexaudit_2026_09_27_b.do` | 2026-09-27 audit shard/pool regressions (11 cases), all on genuine shards. Pooling refuses equal-b/equal-N shards from different outcome data (unweighted and IPTW), a live weight input or outcome edited after the fit, and an anchor whose own shard is absent; saved pools keep component lineage so AB+B and AB+A are refused while AB+CD pools; `saving(x.dta)` stamps and pools x.dta beside an x.dta.dta; native `e(N_reps)`/`e(ci_percentile)`/`estat bootstrap` describe the pooled draws; fractional levels replay and pool; `demo/shard_driver.do` fails rather than pool a previous run's artifacts (spawns child `stata-mp`). |
| `test_iivw_audit_2026_10_05_weight.do` | 2026-10-05 audit weight track (W1-W13): the stale-score sweep deletes only columns carrying this prefix's ownership stamp; the exact/float-precision endpoint policy keeps representable terminal intervals at large time origins and tiny units, and `maxfu()` keeps its exact token; treatment-model scores are zero outside the logit sample so the stacked subject union is complete; untrimmed raw component snapshots are bound by the weight signature; a float-resolved endpoint is refused when another subject's visit lies in the dropped gap; the earlier-version contract message; the signature is identical across `set processors` values. |
| `test_iivw_audit_2026_10_05_fit.do` | 2026-10-05 audit fit/inference track (FIT-F01..F12): engine `e(sample)` sync on point-only and binomial routes; stacked intercept-only and `noconstant` fits and the stacked-V Wald test; grouped-binomial response check; protection of offset/exposure/trials inputs; option sentinels; the generated-design expression guard in `predict`; point-only offset. |
| `test_iivw_audit_2026_10_05_bootstrap.do` | 2026-10-05 audit bootstrap/pooling track (BP-01..BP-05): auxiliary analysis inputs in the pooling identity; BCa refusal wording; refusal when a selected BCa endpoint is undefined while omitted terms stay available; per-file shard count reconciliation; stale BCa surfaces cleared after pooling; a `citype(wald)` fit with an undefined model variance completes with a note; `margins` at counterfactual raw-time values is refused after generated time columns. |
| `test_iivw_audit_2026_10_05_diag.do` | 2026-10-05 audit diagnostics/exogeneity track (DX01..DX06): selected-history `iivw_exogtest` against a native `stset`/`stcox` oracle; any-tie Efron verdict gate; modeled-only balance verdict and `r(target)`; `xtreg` fe/be identity; contrast-mode eligibility; ties counted on each fitted sample; exact endpoints and `maxfu()` tokens in `iivw_balance`/`iivw_exogtest`; the extra-covariate verdict `r(extra_flag)` fires on z² and omitted-covariate misspecification, counts a duplicate extra/model variable once, and is reported when the modeled maximum is degenerate. |
| `test_iivw_audit_2026_10_05_shared.do` | 2026-10-05 audit shared-state track (SS01..SS04): reversible worksheet-name escape across the three reporters; raw string cells in the standard export layout; the byte wording of the `sheet()` length error; strict header-version parsing. |
| `test_iivw_audit_2026_10_05_qadocs.do` | 2026-10-05 audit QA/docs track: coverage-runner failure, manifest and stale-row guards (QDR01-03, native refusal plus stub controls); assertion-blindness guards (QDR05); help, runbook and verifier contract checks (QDR04, QDR06-11, SS03). |
| `test_iivw_route_grid.do` | Route × condition contract grid for `iivw_fit` and `iivw_bspool` (104 cells, `core`). Eight inference routes (`vce(fixed)`, `vce(stacked)`, fixed-weight and refit bootstrap, `citype(none)`, `citype(percentile)`, `iivw_bspool` pool, `unweighted`) × thirteen conditions (none, `if`/`in`, whole-subject and partial missing outcome, missing covariate, missing `offset()`, entry-only subjects, `cluster()` above the subject with last rows excluded and rows shuffled, string id, `level(95.5)`, restore after a later fit, weight input edited after weighting, documented `e()` surface). Every cell ends EQUAL or REFUSED with a declared rc. An EQUAL cell asserts `e(sample)` row by row against a marker built from the fixture design (never from `e(sample)` or `touse`), `e(N)`, cluster counts, `e(b)`, the route's V oracle (independent `glm`; an independent-Cox two-step sandwich over the design union for `stacked`; the same seeded `bootstrap` around `glm` for fixed weights; the covariance and quantiles of the saved draws for refit, percentile and pooled), `e(iivw_ci)`, and every result `iivw_fit.sthlp` documents without a route qualifier. Cells that a known open package bug breaks are held in an in-file open ledger and must fail at the recorded step (empty on 4.3.1; see Known gaps). The suite fails if one of them passes or fails anywhere else. It prints a receipt of route rows × condition columns. Replayed at pre-fix `166dfd10` (4.2.0), the F01, F02, F09 and F13 cells fail at the V, cluster-count, sample and fit steps respectively. |
| `test_iivw_route_grid_fixes.do` | 4.3.1 regressions for the route-grid findings (9 cases, `core`; R1-R9 were red on 4.3.0, R10 pins the 1.0.0 option removal). Refit and percentile refit bootstraps report `e(sample)`/`e(N)`/`e(iivw_outcome_nclust)` equal to a design-built marker under missing outcomes and covariates; a `timespec(categorical)` level seen only on missing-outcome rows builds no omitted column under `vce()`; `e(iivw_outcome_nclust)` is posted and correct on all six routes at subject and clinic level; `vce(stacked)` with a string id reproduces the numeric-id result; `vce(stacked), cluster(clinic)` equals an independent-Cox two-step sandwich summing subject scores per cluster (and not the one-subject-per-cluster twin), and a subject spanning clusters is refused as a nesting failure; point-only fits post `e(iivw_predict)` and refuse `predict` over rebuilt design columns (r(459)); the removed mixed-model options are refused (r(198)) with the caller's state unchanged. |
| `test_iivw_state_lifecycle.do` | Session fingerprint (`_qa_state.do`) of all seven public commands on a success and an early-error path (foreign `regress` e() with a predict round trip, user matrix/scalar/global, `varabbrev on`); lifecycle (`qa_lifecycle`) for `iivw_fit` (categorical-time fit A, later-support fit B, restore A: F03), `iivw_weight` (reweighted fit B) and `iivw_diagnose`; `qa_lifecycle_pool` on genuine bootstrap shards (A+B, AB, AB+B, AB+A, AB+CD, failed rerun, `x.dta` beside `x.dta.dta`: F05, F06); `qa_counterfeit_twin` shards with equal b and N (F04). `core`. At pre-fix `166dfd10` it fails F03, F04, F05 and F06. Its `iivw_weight` block was open on 4.3.1 (the `stset` leak) and is closed in 4.3.2. |
| `test_iivw_surfaces.do` | Surface parity (`qa_surface_parity`) across `r()`/`e()`, workbook and console for all seven commands, against independent oracles where one exists (`summarize`, `glm [pw]`, the appended draw files, the stored percentile interval); withheld endogenous shares (F11); pooled draw count and percentile limit (F08); diagnosis interval (F10); `qa_hostile_times` as visit times with an order-invariance oracle through `iivw_weight`, `iivw_balance`, `iivw_exogtest` and `iivw_fit`; the `qa_hostile_strings` corpus through `title()` and `saving()`. `core`. At `166dfd10` it fails F08, F10 and F11. The four blocks that held open findings on 4.3.1 are closed in 4.3.2. |
| `test_iivw_weight_adversarial.do` | Weight construction hostile cases. |
| `test_iivw_weight_validation_guards.do` | Weight-option validation and error codes. |

### Validation

| File | Covers |
|---|---|
| `validation_fixture_phase2_iivw.do` | Conditional raw-design coefficients/projections and actual metamorphic row/category/name/list relations; large and near0/1 double outputs, correctly rounded supported6-place Excel values and named decimals8 refusals. |
| `validation_fixture_recovery.do` | Canonical visit-intensity and analytic full-data mean recovery at seeded populations. |
| `validation_fixture_pool.do` | Saved finite draw covariance, Wald, percentile and basic interval pooling arithmetic. |
| `validation_fixture_analytical.do` |26 independent raw-design Gaussian projections and uniquely mapped coefficients for polynomial/category/interaction/time-category/collinear designs, friendly and unsorted. Five noninteger waves are an explicit pre-weighting adapter; collinear coefficients are nonidentified and only projection is asserted. |
| `validation_fixture_domains.do` | Finite-data weighted coefficients, confidence endpoints, threshold effects and observed-time cell means. |
| `validation_fixture_weightdomains.do` | Exact treatment propensity and visit/treatment/combined weight rows with risk-entry controls. |
| `validation_fixture_inference.do` | Fixed-weight saved-draw variance and interval arithmetic over confidence levels and RNG stream bounds; no coverage claim. |
| `validation_fixture_qa29_weight.do` | A3 operator cells for `iivw_weight`: exact counting-process and logit oracles, refusals with an unchanged state fingerprint, raw multidigit codes through the visit model. |
| `validation_fixture_qa29_fit.do` | A3 operator cells for `iivw_fit`: Mata WLS/IRLS coefficient oracles and cluster-sandwich `e(V)` oracles, declared omissions, refusals, code-relabel and singleton-cluster invariance. |
| `validation_fixture_qa29_bspool.do` | A3 operator cells for `iivw_bspool`: two-shard pools (including unweighted duplicate keys and reserved-name collisions) against restacked-draw V and Wald CI, with a clustered positive control. |
| `validation_fixture_qa29_balance.do` | A3 operator cells for `iivw_balance` against Mata moments, independent target SMDs, leverage classes and the saturated-stabilisation identity, plus `decimals()`, `fontsize()` and `font()` workbook boundaries. |
| `validation_fixture_qa29_diagnose.do` | A3 operator cells for `iivw_diagnose`: stored `e(b)`/`e(V)` arithmetic, Mata WLS slopes, design-based sample identity, export boundaries, removed `theme()`. |
| `validation_fixture_qa29_exogtest.do` | A3 operator cells for `iivw_exogtest` against a hand-built Andersen-Gill risk set (b, se, z, p, HR and CI); regressions for missing `adjust()` history, degenerate robust variance, monotone-likelihood separation (one term, near-extreme control, joint-only), scale invariance from 1 to 1e12, post-`maxfu()` missing `adjust()`, and the `adjust()` timing rule. Separation-check cells: delayed entry at an event time, flat (non-strict) directions from a lag copy or the wave number, a constant `adjust()` term, separation through `adjust()`, nearly collinear lags, stcox-omitted terms kept out of the check, a rank-deficient robust variance that withholds the omnibus, a certified -1e9 lag decided finite, an input outside the check's exact range counted in `r(n_unknown)` only, and the floating-point membership bound on certified 1e12 and one-strict-pair-in-millions inputs. |
| `validation_iivw_exogtest_corpus.do` | Separation check (`_iivw_cox_recession`) on 1,209 exactly certified cases from 13 corpora (`data/exogtest_corpus_*.csv`): no wrong verdict, status-2 bounds per corpus, the 1.0.1 wrong-verdict cases asserted against the truth, verdict invariant to the sort jumbler state. |
| `validation_iivw_exogtest_command.do` | The same check through `iivw_exogtest`: stcox-omitted terms kept out, retained-design certificates on collinear, heavy and gap corpora, the check run on the fitted variables rather than SD-divided copies (g_collinP 305), a subnormal joint p reported exactly, verdict invariant to the jumbler state. |
| `validation_fixture_excel.do` | Actual workbook decimal endpoints and fonts, exported numerical cells and named styling refusals. |
| `validation_iivw.do` | Core known-answer identities. |
| `validation_iivw_diagnostics_known_answers.do` | Hand-computable diagnostic outputs. |
| `validation_iivw_expanded.do` | Extended invariants. |
| `validation_iivw_exogtest_calibration.do` | `iivw_exogtest` size and power at nominal level ± 3 MCSE, plus Holm p-value parity with R `p.adjust`; `smoke` argument for the code-path form. |
| `validation_iivw_exogtest_recovery.do` | `iivw_exogtest` lagged-outcome visit-intensity coefficients recovered from a seeded DGP with known truth. |
| `validation_iivw_fiptiw_recovery.do` | FIPTIW known-truth recovery and mechanism discrimination. |
| `validation_iivw_inference.do` | Long-running preregistered interval-coverage study. |
| `validation_iivw_iptw_oracle.do` | Stabilized IPTW known-answer oracle. |
| `validation_iivw_known_answers.do` | Additional hand-computable results. |
| `validation_iivw_links_calibration.do` | Poisson-log and binomial-logit interval coverage at nominal ± 3 MCSE with a negative control; `smoke` argument. |
| `validation_iivw_links_known_answers.do` | Exact Poisson-log quadratic-time and binomial-logit outcome-model solutions. |
| `validation_iivw_links_recovery.do` | Poisson-log and binomial-logit weighted-GEE coefficients recovered from a seeded DGP; tolerance from MCSE. |
| `validation_iivw_recovery.do` | Legacy end-at-last-visit recovery construction. |
| `validation_iivw_recovery_extended.do` | Legacy recovery construction. |
| `validation_iivw_recovery_extended2.do` | Additional legacy recovery construction. |
| `validation_iivw_stacked_calibration.do` | `vce(stacked)` interval coverage at nominal ± 3 MCSE with a fixed-variance negative control; `smoke` argument. |
| `validation_iivw_unweighted_calibration.do` | Unweighted GEE cluster-robust interval coverage at nominal ± 3 MCSE with a negative control; `smoke` argument. |
| `validation_iivw_unweighted_recovery.do` | Unweighted GEE coefficients recovered from a seeded DGP; tolerance from MCSE. |

### Cross-validation

| File | Covers |
|---|---|
| `crossval_iivw.do` | Freshly regenerated weight and outcome parity with `IrregLong`, `survival`, `geepack`, and a local simplified Tompkins-informed transcription. |
| `crossval_iivw_external.do` | External datasets and independent IPTW/GEE references. |
| `crossval_iivw_dta.do` | Fresh `.dta` exchange parity for baseline-event Efron weights and independence-GEE point estimates and sandwich SEs. |
| `crossval_iivw_pbcseq.do` | Mayo PBC sequential-study parity for subject-specific censoring, lagged-outcome IIW, quadratic-time GEE, and exogeneity diagnostics. |
| `crossval_iivw_bootstrap_survival.do` | Refit subject-bootstrap SEs against R `survival` + `geepack` refits on the identical resamples. |
| `crossval_iivw_stacked_geex.do` | `vce(stacked)` two-step sandwich parity with R `geex`. |
| `crossval_iivw_unweighted_geepack.do` | Unweighted GEE coefficients and cluster-robust SEs against R `geepack`. |
| `crossval_iivw_published_hernan-robins-whatif.do` | Published reproduction of Hernán and Robins, *What If* ch. 12 (NHEFS): stabilized IPTW range and mean, IP-weighted difference and robust CI, crude difference. |
| `crossval_iivw_published_coulombe-2021-biometrics.do` | Published reproduction of Coulombe et al. 2021 Table 3.1, OLS and IPT columns in all settings; FIPTM/VW are not reproducible through visit-row input. |
| `crossval_iivw_published_tompkins-2025-smmr.do` | Reference parity with the authors' public FIPTIW simulation code (GitHub commit f46e493, SHA-256 pinned, fetched at run time); not a published reproduction, since that code does not reproduce the printed Table 1. |

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
| `_iivw_fixture_excel.do`, `tools/check_iivw_format.py` | Shared reporting-form assertions and workbook style/numerical inspection. |
| `_qa_fx_a3.do`, `_qa_state.do`, `_qa_hostile.do`, `_qa_lifecycle.do`, `_qa_metamorphic.do`, `_qa_parity.do`, `_qa_route_grid.do` | Byte-vendored canonical fixture, state and primitive helpers. |
| `_iivw_qa29_oracles.do` | Fixture-to-iivw adapter and independent oracles shared by the `validation_fixture_qa29_*` suites. |
| `_iivw_fixture_qa29.do` | Independent oracles shared by the QA29 balance, diagnose and exogtest fixture suites; not run directly. |
| `_iivw_cr_ladder.do` | Shared correlation-structure ladder implementation. |
| `_iivw_unw_dgp.do`, `_iivw_links_dgp.do`, `_iivw_exogtest_dgp.do` | Seeded DGPs sourced by the matching recovery and calibration suites; not run directly. |
| `run_all.do` | Curated Stata lane manifest and runner. |
| `run_all.sh`, `test_run_all_wrapper.sh` | Reliable shell exit and sentinel gate, plus its regression test. |
| `run_coverage_gate.sh`, `COVERAGE_GATE_RUNBOOK.md`, `tools/covgate_env.sh`, `tools/stub_stata_mp.sh` | Block-sharded long-run coverage workflow, plus the environment shim and stub `stata-mp` its runner regressions use. |
| `crossval_*.R`, `crossval_irreglong.R`, `validation_iivw_exogtest_calibration_holm.R` | Independent R reference generators (the new crossvals and the Holm check call theirs at run time). |
| `*_versions.csv` | R and package versions recorded beside each R-backed suite. |
| `*.csv` | Tracked cross-validation inputs and generated reference values. |
| `data/nhefs_whatif.csv` | NHEFS extract for the Hernán-Robins reproduction; its SHA-256 is asserted in the suite. |
| `data/iivw_sep_med_cases.csv` | Two separation-check cases (1,296 and 1,503 distinct pair rows, a 1e9 value) with their exactly certified `sep`. |
| `data/iivw_sep_intdir_cases.csv` | Three separated cases whose exact direction is a small-integer column combination (44, 130 and 108 distinct pair rows), with the certified `sep`. |
| `data/exogtest_corpus_cases.csv`, `data/exogtest_corpus_exp.csv` | Rows and exactly certified separation truth (full design and every column subset) for 1,209 corpus cases. |
| `_skip.txt` | Explicit standard-lane exclusion for the long-running inference gate. |
| `METHOD_CONTRACT.md`, `METHOD_ORACLE_MAP.md`, `CROSSVAL_MODULE_MAP.md` | Method, oracle, and external-module mappings. |
| `COVERAGE_MATRIX_PLAN.md`, `TOLERANCE_FRAMEWORK.md`, `coverage_results/` | Preregistered coverage design and retained evidence. |
| `AUDIT_NOTES.md` | Durable interpretation and historical defect evidence moved out of this runbook. |
| `.gitignore` | Generated-artifact policy. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `iivw` | `test_iivw`, release adversarial | version/distribution invariants | — | installed-user smoke |
| `iivw_weight` | command, adversarial, interval, tie, regression suites | recovery and IPTW/FIPTIW oracles | `crossval_iivw`, `crossval_iivw_external`, `crossval_iivw_dta`, `crossval_iivw_pbcseq`; `crossval_iivw_published_*` (Tompkins code parity, Hernán-Robins and Coulombe published reproductions) | fit, balance, psdash, diagnostics |
| `iivw_balance` | command, exports, adversarial regressions | known-answer balance checks | — | weighting and diagnostic workflow |
| `iivw_fit` | command, unweighted, inference, stacked, replay, regressions; route grid 104 cells (104 EQUAL or REFUSED, 0 open); `test_iivw_route_grid_fixes` | recovery (incl. `validation_iivw_unweighted_recovery`, `validation_iivw_links_recovery`), calibration gates (`validation_iivw_stacked_calibration`, `validation_iivw_unweighted_calibration`, `validation_iivw_links_calibration`), canonical-link known answers, conditional raw-design projections and Phase2 numerical relations | all cross-validation suites (`crossval_iivw*`) | bootstrap and psdash workflow |
| `iivw_exogtest` | command, adversarial, exports, ties | diagnostic known answers, `validation_iivw_exogtest_recovery`, `validation_iivw_exogtest_calibration` | `crossval_iivw_pbcseq` | diagnostic workflow |
| `iivw_diagnose` | command, exports, workflow | diagnostic known answers and actual supported-decimal numerical exports | — | unweighted/weighted/adjusted comparison |
| `iivw_bspool` | `test_iivw_v420_shard`, `test_iivw_codexaudit_2026_09_27_b`, route grid `bspool` row (13 cells) | pooled covariance equals the hand-computed replicate covariance (T19); split-and-repool is bit-identical (T1) | `test_iivw_v420_shard` (unsharded-bootstrap parity, T1/T2/T17) | `demo/shard_driver.do` (C11), help examples |

Adversarial axes, in cells (`check qa iivw --view axes`: 36/36 owed cells probed): route grid 2/2; fingerprint 7 commands × 2 paths; lifecycle 4/4 (`iivw_fit`, `iivw_weight`, `iivw_diagnose`, and `iivw_bspool` through 7/7 pool scenarios); parity 7/7; hostile strings 5/5; hostile fixtures 4/4. `demo/shard_driver.do` stale artifacts (F07) are pinned only by `test_iivw_codexaudit_2026_09_27_b.do` C11, which launches child Stata processes; the pool block's failed-rerun scenario is declared accept, since a genuine earlier shard file cannot be told from a fresh one at pool level.

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default release gate. The explicit suite names live only in `run_all.do`.

| Lane | Suites |
|---|---|
| `quick` | Fast public-command, state, recovery, documentation, and release contracts. |
| `core` | `quick` plus supported Stata validation, recovery, adversarial, stacked, tie, and regression suites, and the Hernán-Robins published reproduction. |
| `full` | `core` plus regenerated R references, all other cross-validation and published-reproduction suites, and every calibration gate in its `smoke` form (`<suite>:smoke` in `run_all.do`). |
| `legacy` | Historical `validation_iivw_recovery*` constructions, outside the supported-estimator gate. |
| `sensitivity` (`sim`) | The four `validation_iivw_*_calibration.do` gates at full replicate count, then the post-hoc scenario envelopes. |

## Evidence layers

One row per estimator route. Cells name files only; `check qa iivw --view evidence` derives each cell's state from lane membership, `_skip.txt` and the `run qa` receipts. A blank cell is owed evidence that does not exist yet. `iivw_balance` and `iivw_diagnose` report descriptive balance statistics and re-report stored estimates, so they have no row. The FIPTIW parity arms share the legacy observed-event risk set (`METHOD_ORACLE_MAP.md` §3), and fixed-weight SE parity certifies only the weights-known variance. Calibration files run at gate size in `sensitivity` and in their `smoke` form in `full`; only a gate-size receipt satisfies a cell.

| Route | Recovery | Reference parity | Published reproduction | Inference calibration |
|---|---|---|---|---|
| `iivw_weight` IIW inverse visit-intensity weight (Andersen-Gill Cox) | `validation_fixture_recovery.do` | `crossval_iivw.do`; `crossval_iivw_dta.do`; `crossval_iivw_pbcseq.do`; `crossval_iivw_published_tompkins-2025-smmr.do` | none: data unavailable (buzkova-lumley-2007 HUD-VASH data not distributed, PDF p.22; tompkins-2025-smmr Table 1 is not reproduced by the authors' own public code, see crossval_iivw_published_tompkins-2025-smmr.do header) | none: no inference reported (iivw_weight returns a weight per visit row and weight summaries; no weight carries a standard error or interval, and the visit-model stcox table printed without nolog is Stata's own nuisance output) |
| `iivw_weight` stabilized IPTW treatment weight | `validation_iivw_fiptiw_recovery.do` | `crossval_iivw_external.do`; `crossval_iivw.do` | `crossval_iivw_published_hernan-robins-whatif.do`; `crossval_iivw_published_coulombe-2021-biometrics.do` | none: no inference reported (iivw_weight returns a weight per visit row and weight summaries; no weight carries a standard error or interval, and the treatment-model logit table printed without nolog is Stata's own nuisance output) |
| `iivw_weight` FIPTIW product weight | `validation_iivw_fiptiw_recovery.do` | `crossval_iivw.do`; `crossval_iivw_external.do` | none: data unavailable (coulombe-2021-biometrics Tables 3.1/A.3 use Z(t) at every risk time, which visit-row input does not carry; at the (0,0) setting iivw's FIPTIW empirical variance is 0.89 against the published 0.766) | none: no inference reported (iivw_weight returns a weight per visit row and weight summaries; no weight carries a standard error or interval, and the visit-model stcox and treatment-model logit tables printed without nolog are Stata's own nuisance output) |
| `iivw_fit` IIW/IPTW weighted GEE, refit subject bootstrap (default; FIPTIW on request) | `validation_fixture_recovery.do`; `validation_iivw_fiptiw_recovery.do` | `crossval_iivw_bootstrap_survival.do` | none: data unavailable (coulombe-2021-biometrics Table A.3, PDF p.191, reports FIPTM bootstrap RE/coverage, but its estimator uses Z(t) at every risk time, which visit-row input does not carry; at (0,0) iivw's FIPTIW empirical variance is 0.89 against the published 0.766) | `validation_iivw_inference.do` |
| `iivw_fit` weighted GEE, `vce(fixed)` cluster-robust sandwich and fixed-weight bootstrap | `validation_fixture_recovery.do`; `validation_iivw_fiptiw_recovery.do` | `crossval_iivw.do`; `crossval_iivw_external.do`; `crossval_iivw_dta.do`; `crossval_iivw_pbcseq.do` | `crossval_iivw_published_hernan-robins-whatif.do` | `validation_iivw_inference.do` |
| `iivw_fit` weighted GEE, `vce(stacked)` two-step influence-function sandwich | `validation_fixture_recovery.do`; `validation_iivw_fiptiw_recovery.do` | `crossval_iivw_stacked_geex.do` | none: data unavailable (coulombe-2021-biometrics Table A.3, PDF p.191, reports the asymptotic two-step sandwich RE/coverage, but on a Z(t)-grid estimator that visit-row input does not carry; newey-mcfadden-1994 publishes no worked example) | `validation_iivw_stacked_calibration.do` |
| `iivw_fit` FIPTIW weighted GEE, bare-fit point estimate | `validation_iivw_fiptiw_recovery.do` | `crossval_iivw.do`; `crossval_iivw_external.do` | none: data unavailable (coulombe-2021-biometrics Tables 3.1/A.3 use Z(t) at every risk time, which visit-row input does not carry; at the (0,0) setting iivw's FIPTIW empirical variance is 0.89 against the published 0.766) | none: no inference reported (a bare FIPTIW fit posts coefficients only, with no e(V) or interval, because no FIPTIW interval has passed the coverage gate; iivw_fit.sthlp, Inference status) |
| `iivw_fit` unweighted GEE, cluster-robust sandwich | `validation_iivw_unweighted_recovery.do` | `crossval_iivw_unweighted_geepack.do` | `crossval_iivw_published_hernan-robins-whatif.do`; `crossval_iivw_published_coulombe-2021-biometrics.do` | `validation_iivw_unweighted_calibration.do` |
| `iivw_fit` weighted GEE, Poisson-log and binomial-logit links | `validation_iivw_links_recovery.do` | `crossval_iivw_external.do` | none: data unavailable (buzkova-lumley-2007 Table 6 DGP, PDF pp.18-19, redraws X(t) and Z(t) on a 0.01 grid that visit-row input cannot carry, with a probit-scale truth; the HUD-VASH data are not distributed, PDF p.22) | `validation_iivw_links_calibration.do` |
| `iivw_exogtest` lagged-outcome visit-intensity coefficients, Holm-adjusted p-values | `validation_iivw_exogtest_recovery.do` | `crossval_iivw_pbcseq.do` | none: data unavailable (buzkova-lumley-2007 Table 2, PDF p.15, reports the lagged-outcome visit coefficient from the HUD-VASH application; the data are not distributed, PDF p.22) | `validation_iivw_exogtest_calibration.do` |
| `iivw_bspool` pooled sharded bootstrap covariance and intervals | `validation_fixture_pool.do`; `test_iivw_v420_shard.do#T19` | `test_iivw_v420_shard.do#T1`; `test_iivw_v420_shard.do#T2`; `test_iivw_v420_shard.do#T17` | none: no grounding paper (iivw_bspool appends shard replicate files and passes them to Stata's bstat, [R] bstat; the bootstrap it pools is grounded on the iivw_fit rows) | none: deterministic transform (the pooled interval is the one the unsharded bootstrap gives from the same draws, bit-identical per test_iivw_v420_shard T1, so its coverage is that of the iivw_fit bootstrap calibrated on the iivw_fit rows) |

## Known gaps

- `validation_iivw_inference.do` is intentionally excluded from standard lanes because its preregistered release mode is a multi-day nested-bootstrap study; run it through `run_coverage_gate.sh` when that gate is authorized.
- Route-grid open ledger (`test_iivw_route_grid.do`): empty on 4.3.1, 104/104 cells EQUAL or REFUSED (117 before the mixed route was removed in 1.0.0). The 17 cells it held on 4.3.0 (I1, N1-N4) are fixed and pinned by `test_iivw_route_grid_fixes.do`.
- The route grid has no quick-lane diagonal subset yet. The full grid runs in `core` and `full`.
- The four findings the 4.3.1 lifecycle and surfaces suites held open (the `iivw_weight` `stset` leak, `title()` re-expansion, `iivw_bspool, saving()` re-expansion, and `r(n_commands)` = 5) are fixed in 4.3.2; both open ledgers are empty and `test_iivw_v432_regressions.do` pins them. `iivw_fit, saving()` only inherits Stata's own `bootstrap, saving()` grammar, which expands `$`/backtick names itself (checked against native `bootstrap`), so it is not counted.
- `iivw_fit` keeps a session counter in the global `IIVW_FIT_SERIAL`, and official `glm` leaves `$GLIST`; the fingerprint blocks exempt both by name (and Stata's `S_#`/`S_E_*` saved-result globals) and hold every other global to no change.
- The inference-calibration gates (`validation_iivw_*_calibration.do`) run at gate size only in `sensitivity`; `full` runs their `smoke` form, which is never gate evidence. Refresh a gate receipt with `run qa iivw --file <suite> --isolated` after any source change.
- Fixture-census cells with no applicable input (`check qa iivw --view fixtures`): `extreme_weight` for `iivw_weight`, `iivw_fit` and `iivw_bspool`, because no command accepts a user case or analysis weight and the operator's `w` column is never read; and `singleton_clusters` for `iivw_weight`, which takes no cluster input. The census can still mark some of these met, because it credits every setup call inside a fixture segment; those credits assert nothing about the operator.
- Defensive branches with no reachable input, which no mutation can turn red: the `iivw_bspool` cleanup restore after a failed `bstat`. It is covered by code reading only.
- The separation check returns status 0 or 1 only on an exactly verified certificate, so its search tolerances change only how often it settles; G01 of `test_iivw_exogtest_separation_regress.do` bounds the search route's settle rate and kills the 1e-3 slack-bound mutant. Mutants that survive, each for a stated reason: the Stiemke residual error bound (never binding), the slack threshold and the gray-zone route (outcome-equivalent once every verdict is certified), disabling one of the three integer-rounding sites (they back each other up), the O(rows) shortcut off (performance only), the cross-product orthogonality fail-safe off (reachable only with inexact scaling), and a BLAS row product in the reweighting (ulp-level, inside the 1e-12 slack).
- `probe_*` and `benchmark_*` scripts are diagnostics, not pass/fail evidence unless their results are promoted through a preregistered gate.

## Audit notes

See [AUDIT_NOTES.md](AUDIT_NOTES.md) for the historical false-green defects, method-evidence boundaries, and links to retained coverage receipts.


For bounded integration, `do run_all.do core 1 30` accepts validated inclusive suite positions. Default lanes retain their complete curated manifests. Reconcile disjoint chunk coverage before reporting manifest coverage; separate receipts do not establish one uninterrupted core session.
