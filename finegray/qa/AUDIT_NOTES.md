# finegray QA — audit notes

[README.md](README.md) is the runbook: how to run each lane and one sentence on what each file checks. This file holds the material that is not a runbook — why a check exists, what it was measured at, which defect it was written against, and which earlier behaviour it pins. Nothing here was deleted from the README; it was relocated verbatim.

Read a section here when you are deciding whether a check may be weakened, moved or removed. The one-line entry in the README will not tell you what it is holding shut.

## Per-suite detail

Each block below is the full `Covers` prose that the README's file index used to carry for that file, unedited.

### `test_finegray_v110.do`

Multiple-record reduction, CIF/bootstrap additions, state preservation, factor profiles, and v1.1.x regressions. Three blocks pin the `_fg_*` OWNERSHIP rule: a package column is recognised by the per-run ownership characteristic it carries, not by its name, so a user's own variable spelled `_fg_grp_2` (or `_fg_entry` after a multiple-record fit) is preserved and the fit is `r(198)` rather than silently overwritten, while `finegray`'s own refits still replace the columns they created. Two further blocks pin that the adjudication is complete BEFORE any mutation: a refusal over a name only the NEW specification claims, and a 32-character truncation collision, both leave the characteristics, the prior run's `_fg_*` columns and the still-current fit untouched, so `finegray_cif` on that fit still answers — before this they fired inside the creation loop, after the marks were blanked and the prior columns dropped, and left the dataset unrecoverable at `r(301)`.

### `test_finegray_mi.do`

`mi estimate, cmdok:` compatibility: no unregistered `_fg_*` columns left in `mi` data, bit-identical estimates off `mi` data, fail-closed post-estimation, detection in all `mi` styles, and hand-computed Rubin pooling. Also the hostile negative cases: an ordinary dataset carrying a variable named `_mi_m`, `_mi_id` or `_mi_miss` is **not** `mi` data and must fit and post-estimate normally; and what `mi estimate` actually leaves in `e(mi_data)`/`e(postest)` (retained state from the last per-imputation fit — the pooled refusal is driven by the `e(cmd)` gate, not by those). FGMI-18 pins that `mi estimate`/`mi xeq` do **not** strip a typed `[pw=]`: the weight reaches every imputation's fit and the pooled weighted estimates differ from the pooled unweighted ones.

### `test_finegray_tvc.do`

`tvc()`/`tsplit()` piecewise-constant beta(t): equivalence with `stcrreg, tvc() texp()` (J=2) and with a hand-split episode Cox fit (any J, on data with no competing events); the pre-feature values a fit without `tvc()` must still return; the (lower, upper] tie convention pinned with an event exactly on a boundary; the `main`/`tvc1`..`tvcJ` coefficient stripe and `test`; the `e()` contract and `e(refitcmd)` replay; determinism; `predict cif` reconciled against a piecewise accumulation rebuilt by hand from `e(basehaz)` and `e(b)` (a consistency check on the assembly, not an independent one — the step search is the package's own); the interval-aware `xb` and `attime()`; factor variables; the cost *shape* across two sample sizes; bootstrap CIF intervals; the cold-cache baseline rebuild; a constant-effect DGP showing no spurious time variation; every refusal (missing partner option, bad cuts, empty interval, unmodelled `tvc()` variable, `bstrata()`, `nuisance`, delayed entry, `schoenfeld`, `finegray_phtest`, the analytic CIF `ci`); factor variables through every rebuild path (CIF profile, cold cache, dropped `_fg_*` columns); prediction on new data after the estimation sample is gone; an all-`tvc()` model including the one-covariate case; the two tool-free likelihood invariants — the null log-likelihood matches the proportional fit, and the nested proportional fit is strictly dominated; and a direct fit on **zero-entry multiple-record data**, asserted bit-identical in `e(b)`, `e(V)` and `e(ll)` to the single-record fit of the same subjects, with a cold-cache baseline rebuild and CIF afterwards.

### `test_finegray_bstrata.do`

`bstrata()` baseline stratification: bit-identity of the one-level fit with the unstratified estimator, the `stcox, strata()` equivalence oracle when there are no competing events, the K x 3 `e(basehaz)` layout, `e(refitcmd)` replay, the remaining refusals (delayed entry, stratum-varying `id()`), the `finegray_cif` `bstratum()` contract, per-stratum `basecshazard` lookup, and the event-free-stratum contract. B09b pins the pre-`e(bstrata_noevent_x)` fallback, reached by re-posting the live estimates through an eclass helper that omits the macro (the state an estimate saved under an older build presents), where the no-event level is matched by VALUE, so `bstratum(3.0)` and `bstratum(+3)` are refused like `bstratum(3)` instead of drawing the degenerate stratum as a flat zero at `rc 0`. Plus the stratified-`psi` arms: bit-identity of `bstrata(constant) nuisance` with the plain `nuisance` term, `psi` moving `e(V)` and never `e(b)` at K=2/3/5, degenerate strata and complete follow-up (where `psi` must be exactly zero), `e(refitcmd)` over the newly legal combinations, and the **duplicate-stratum identity** — duplicating the data into two labelled strata must halve `e(V)` exactly, which is the internal arm that catches a dropped per-stratum `psi` block without needing R.

### `test_finegray_tvc_bstrata.do`

The `tvc()` x `bstrata()` composition: equivalence with `stcox, strata()` on a hand-split episode fit (coefficients and log-likelihood), the K=1 and pure-`bstrata()` degenerate identities bit for bit, the composed CIF checked against a hand computation from the K x 3 `e(basehaz)` and asserted to DIFFER by stratum, `predict xb/cif/basecshazard` tied back to `finegray_cif` per stratum, `e(refitcmd)` replay, the duplicate-stratum halving with `psi`, determinism and permutation invariance, degenerate strata, bootstrap CIF replaying the requested stratum, and the per-stratum baseline checked both structurally (each block starts at its own first increment) and externally against `stcox`'s stratified Breslow curve.

### `test_finegray_weights.do`

`[pweight=]` / `[fweight=]`: bit-identity of `[pw=1]` and `[fw=1]` with the unweighted fit across `e(b)`, `e(V)`, `e(ll)`, `e(basehaz)`, every row-level prediction and the CIF table; the two in-Stata oracles — an fweighted fit equals the fit of the `expand`ed data (censoring KM included), and with no censoring a pweighted fit equals the expanded data clustered on subject, which pins the `sum_i (w_i s_i)^2` meat form; a constant pweight leaves `e(b)`/`e(V)` and gives `ll_w = c(ll − N_fail log c)`; `e(refitcmd)` replay; the three baseline routes, the weighted analytic CIF SE, bootstrap replay, Schoenfeld, `xb`, `margins`; the weight variables in `e(datasignaturevars)` — string variables a weight expression reads through a function included — and the `r(459)` on a changed weight; determinism; the `e(wtype)`/`e(wexp)`/`e(sum_w)` contract and the header line; and the data-level refusals (aweight/iweight, negative, noninteger fweight, weight varying within `id()`), together with the partial-exclusion pin that a subject only partly in the estimation sample is not read as varying. WT-13 ties `e(basehaz)` to the `finegray_cif` curve at the reference profile (`1 − exp(−H0(t))`) under a censored pweight and under fweights: that is the one weighted cell with no external oracle, because `finegray_cif` reads `_finegray_cif_core`, not `_finegray_basehazard`, so the R crossval passes with the weight dropped from the Breslow numerator while this assertion moves from 2.7e-16 to 1.1e-01. WT-14 pins the reconciliation of the rebuilt weight column against `e(sum_w)`: a scalar in the weight expression changed after the fit, or a re-sort under a subscript such as `pw[1]`, is `r(459)` on `finegray_cif`, `predict, cif ci` and `predict, schoenfeld` — both rebuilt a different column at `rc 0` before the reconciliation — while a re-sort under a plain variable weight still answers bit-identically. WT-18 pins the compensated case: a change to an unsignable weight input that leaves `e(sum_w)` invariant while moving every weight is still `r(459)`, and a re-sorted variable weight still reconciles. WT-19 pins the diagnosis when the fit's `id()` variable is no longer in the data: the digest is keyed by subject and cannot be rebuilt, so the refusal names that variable instead of blanking the key and reporting a changed scalar — a right return code with the wrong explanation. Every block ends with `capture restore`, so a failure inside a `preserve`d block cannot leak its state and turn the next block into a spurious `r(621)`.

### `test_finegray_fences.do`

The whole option-lattice fence matrix in one place, asserted on **(return code, option-name tokens)** rather than on message wording: the sandwich-property fences, the `tvc()`/`tsplit()` grammar, the three right-censoring feature pairs (all lifted in the variance unification, so now positive assertions), the three delayed-entry cells (all still refused), the post-estimation fences under `tvc()` and `bstrata()`, the design-weight matrix (the shipped pweight/fweight core, and the refused cells: `norobust` under pweights, `nuisance`, `strata()`, `truncstrata()`, `bstrata()`, `tvc()`, delayed entry, `finegray_phtest`, aweight/iweight, noninteger fweight, `_n`/`_N` in the weight expression, and a weight carried by `stset` that was not retyped on the command), and the `e(vce_meat)`/`e(lt_vce)`/`e(lt_weight)`/`r(se_method)` disclosure macros. Lifting a fence is a one-line edit here; the wording itself is pinned in exactly one place, the canary in `test_finegray_errors.do`.

### `test_finegray_mi_lattice.do`

Every v1.2.0/v1.3.0 mechanism under `mi`, in both reachability modes (`mi estimate, cmdok:` and typed directly on `mi` data): delayed entry and `truncstrata()`, `strata()`, `nuisance`, `bstrata()` and `tvc()`; hand Rubin pooling of a delayed-entry fit; the mi-style detection matrix re-run for a ZZF fit across four styles x three contexts; `mi update` and a `datasignature` taken around the direct fits; multi-record `id()` + factor variables + delayed entry together; `e(refitcmd)` replay on mi-mode fits; and the post-estimation `r(301)` refusals. Its discriminating arms are the regressions for defect D0-1, the `_dta[_finegray_*]` characteristics a mi-mode fit used to write.

### `test_finegray_adversarial_v130.do`

Cross-feature, hostile, and degenerate probes for the v1.3.0 surface, on the axes the per-feature suites do not cover. `mi`: an imputed factor level present in only some imputations (refused by `mi`'s own consistency check, because `finegray` reports the levels actually present rather than padding a phantom column); a degenerate imputation surfaced through `e(M_mi)`/`e(m_est_mi)`/`e(rc_mi)` under `errorok`; the `_fg_*` namespace against a user's own variable and against a previous fit's stale columns; `mi estimate` pooling of `bstrata()` and `tvc()` fits checked against hand Rubin's rules; `flongsep` and `mlong` typed directly; and per-imputation estimation-sample size. `tvc()`: 32-character names sharing a 30-character prefix; boundaries stacked on the first and last cause-event times; a boundary on 99 tied events checked against a hand-split episode Cox fit with the opposite convention as the discriminating contrast; `tvc()` with `strata()` and `cluster()` by invariance; and an interval carrying exactly one cause event. `bstrata()`: a missing stratum value; value labels holding a space, a quote, `=` and `<`; strata numbered 3, 17, 40 and -5; `i.s` with `bstrata(s)`; twenty baseline blocks checked from `e(basehaz)` in Mata; and `bstrata()` + `cluster()` + `noadjust` with the finite-sample factor verified as exactly *g*/(*g*-1). C8 pins the SCALE-independence of the two data-shape rules: within-subject constancy is judged exactly and interval contiguity relatively (1e-12 of the larger boundary), so a 5e-10 covariate move and a 5e-10 gap on times of order 1e-10 are both `r(198)`, while a genuinely contiguous dataset on the same scale still fits — and at day scale a boundary pair built by two different arithmetic routes, or a few hundred units in the last place apart, must FIT, while a 1e-8 gap (3e-12 relative) is still refused.

### `test_finegray_adversarial_v120.do`

Cross-feature and boundary probes for the v1.2.0 surface. The delayed-entry log-likelihood compared with a `(t0, t]` partial likelihood built by hand in Mata from the raw columns, with the `(t0 <= t]` variant computed in the same loop as the contrast; a zero-length episode dropped by `stset` before `finegray` sees it; a cohort in which nobody is at risk before the first cause event, where the CIF must be exactly 0 with no confidence limits and must say so; degenerate `truncstrata()` strata (a one-subject stratum refused, an all-identical-entry stratum fitted, and identical entry distributions reproducing the pooled fit exactly); `nuisance` with two clusters, finite for one covariate and refused for three; a bootstrap whose replications really fail, checked for reconciliation, on-screen disclosure, reproducibility from the seed, and refusal below the 25-replication floor; and the missing-`compete()` refusal scoped to the estimation sample when the offending record is excluded by `if` and when it is excluded by `stset`.

### `test_finegray_variance.do`

Robust, clustered, model-based, adjusted, and rank-aware variance contracts. FG-M16 pins the finite-sample factor as a COEFFICIENT-variance convention: `e(V)` carries exactly *N*/(*N*-1), or *g*/(*g*-1) under `cluster()`, while the analytic cumulative-incidence variance is the asymptotic influence-function sandwich and carries nothing, so `noadjust` moves `e(V)` and leaves every `finegray_cif` standard error bit-identical; `e(vce_adjust)` and `r(vce_adjust)` are the machine counterparts of that prose disclosure.

### `test_finegray_postest.do`

Factor rebuilds, stale-data checks, CIF limits, baseline grids, and post-estimation cleanup. FG-B05c pins that `mata clear` cannot let a later fit re-mint an earlier fit's baseline cache key. PE-BC1 to PE-BC3 pin that `basecshazard` reads no covariate design: H0(t) on new data carrying only the time variable answers (and, on a `bstrata()` fit, the strata variable — the covariates are neither required nor read), while the cold-cache refusal with no `e(basehaz)` and a cleared Mata cache is still `r(459)`.

### `test_finegray_nuisance_lt.do`

`nuisance` under delayed entry (ZZF 2011 Appendix B): convergence of the three-term representation to Fine & Gray's eta+psi as n grows without truncation (per-subject correlation → 1, meat distance ∝ 1/n), the pooled-weight contract (`e(lt_vce)` = `nuisance_adjusted`, `e(b)`/`e(ll)` unchanged, symmetric PD `e(V)` that differs from the fixed-weight one), the stratified-weight and `norobust` fences, `e(refitcmd)` replay, determinism, mean-zero influence rows on LT data, and the `cluster()` composition. NLT-06 pins that the printed `Variance:` line names BOTH pieces of the sandwich actually in `e(V)` when `cluster()` and `nuisance` are combined.

### `test_finegray_cif_over.do`

`finegray_cif, over()`: bit-identity of every overlaid curve with its standalone `at()`/`bstratum()` call (direct covariate, factor in an interaction, baseline strata on their own grids, bootstrap with a shared seed, `tvc()`), the stacked `r(table)`/`r(at)`/`saving()` surface, the refusals (`over()`+`at()` on one variable, non-model or continuous variable, `over()`+`bstratum()`), the unchanged five-column surface without `over()`, and `r()` survival past a failed `saving()`. OV-11 to OV-13 pin EXACT level transport: levels reach `at()` and the baseline-stratum selector in `%21x`, `r(levels_mat)` and the `over` column of `r(table)` carry machine doubles where the printed `r(levels)` rounds, and a noninteger no-event `bstrata()` level is omitted from the overlay by VALUE — before this the display-string subtraction dropped the wrong stratum and drew a flat zero curve for the degenerate one, under bootstrap too.

### `test_finegray_margins.do`

Native `margins` on factor terms and the widened stripe behind it: the posted `e(b)`/`e(V)` (base levels as zeros, `e(designvars)`, `e(marginsok)`), the Stata and Mata non-base accessors, `margins pelnode` == `at()` == `at() predict(xb)` == hand-computed counterfactual means, `dydx()` and the delta-method SE by hand from `e(V)`, design columns dropped, `estimates store`/`restore`, a non-default base and an `fvset` change after the fit, a re-striped `e(b)` (what `margins` posts while it runs: `xb` scores by name, `cif` refuses), results without `e(designvars)` refused, bit-identity of predict cif/xb/schoenfeld, `finegray_cif` `at()`/`over()` and `finegray_phtest` with a manual-indicator fit, bootstrap refits on the wide stripe, `test`/`testparm`/`contrast`/`lincom`/`pwcompare`, `tvc()` posted narrow, `mi estimate` pooling the wide stripe.

### `test_finegray_failclosed.do`

Missing-injection regressions for the QA guard constructs themselves (FG-08A). Stata missings compare greater than any number and `reldif(., .)` is 0, so `assert q > 0` and `assert reldif(a, b) < tol` both pass on missing operands. Each guard construct in `FAILCLOSED_GUARD_MAP.md` gets a fixture where the guarded quantity IS missing: the unguarded form is shown to pass on it, the guard is shown to exit nonzero, and the guard is shown to pass on finite content.

### `test_finegray_sthlp_render.do`

Self-contained SMCL render, literal-markup, rendered-whitespace, `finegray_methods##marker` link-target, and `{synopt}` column-width checks for shipped help — four render axes, each paired with a fault injection so that a zero count is a measurement rather than a checker that cannot fire. The width axis asserts every `{synopt}` description fits `71 - N` for its governing `{synoptset N}`; three Scalars rows in `finegray.sthlp` had overflowed since the pweight work, wrapping in the Viewer while every other suite stayed green.

### `validation_cluster_recovery.do`

Zhou et al. (2012) positive-stable shared-frailty DGP with exact marginal truth `beta = alpha*tau`: validates the generator's Laplace transform, coefficient recovery under cluster-constant and matched-pair covariates, rejection of the conditional frailty coefficient as the estimand, the study's opposite clustered-SE directions across those designs, and a second dependence/competing-frailty setting.

### `validation_finegray_cif_se.do`

Deterministic analytic CIF inference and delete-one sensitivity envelopes, plus one exactness cell on uncensored data where G is identically 1 and the analytic and jackknife SEs estimate the same quantity, so the band is tight rather than an envelope.

### `validation_finegray_lt_se.do`

Delayed-entry score identities and coefficient/CIF delete-one sensitivity envelopes, plus the clustered delayed-entry variance rebuilt outside the package from the score residuals (within-cluster sums, the `norobust` inverse information, and the g/(g-1) factor) and its one-subject-per-cluster reduction to the unclustered sandwich.

### `validation_pweight_recovery.do`

Known-truth recovery under informative sampling: the Wogu et al. (2021) sec. 5 DGP (p = 0.3, β = (0.5, 0.5), n = 4000), every cause-1 case kept and non-cases sampled Bernoulli with a Z1-dependent rate, weights 1/α. The unweighted fit must be biased (the discriminating contrast) and the `[pweight=]` fit unbiased within 4 MC SEs, with 95% sandwich coverage in [0.90, 0.99] and mean SE / MC SD in [0.85, 1.15], 100 replications. The same replications also evaluate `finegray_cif, ci` at (Z1, Z2) = (1, 0), t = 1 after the weighted fit, whose truth is closed form under the DGP, and assert bias, 95% coverage and mean SE / MC SD of the weighted analytic influence-function interval on the same bands — the one weighted quantity no crossval can reach, since nothing external returns a weighted CIF standard error.

### `validation_tvc_recovery.do`

Known-truth recovery under `tvc()`: data generated by inverting the piecewise subdistribution model's own cumulative incidence, so the interval coefficients are exact. Checks Monte Carlo bias against 4 MC standard errors, 95% coverage of the default fixed-weight sandwich interval, and the mean standard error against the Monte Carlo standard deviation — the last is the only check in the suite that asks whether the piecewise sandwich is the right *size*.

### `crossval_finegray.do`

Coefficient, SE, likelihood, CIF, strata, and benchmark parity with `stcrreg` and `cmprsk::crr`. The stratified numbers are cross-validated against `crr(cengroup=)` in C51/C52 (1e-6, 0.1%); C11 carries the discriminating claim instead — that `strata()` moves the estimate at all — with a floor of 1e-5 four orders above the convergence tolerance and a 5% ceiling, both tied to the measured hypoxia shift (2.2e-4 on `ifp`, 2.1e-3 on `tumsize`). Its former 50%-relative bound was satisfied by any two numbers and passed a `strata()` that was a no-op.

### `crossval_finegray_zzf.do`

Dataset-level parity with a regenerated direct-equation ZZF Weight 1 oracle: coefficients on every dataset, the maximised log-likelihood on the pooled-weight arms (the stratified arms' oracle normalises the weights differently, so its objective is on another scale), and the whole baseline curve on six datasets from arms B and X.

### `crossval_pweight.do`

`[pweight=]` parity with `survival::finegray(weights=)` + `coxph(weights=fgwt, ties="breslow", robust=TRUE, cluster=id)` — the expansion with the user's weights multiplying `fgwt` and an unweighted `Gsurv` — on a continuous-covariate fixture and a factor + `cluster()` fixture: coefficients, robust SEs (`noadjust`), cluster-robust SEs, the weighted log pseudo-likelihood and the CIF at the reference profile from `survfit`; measured 2e-9 to 1.5e-8, gated at 1e-6. The unweighted fit is asserted to differ.

### `crossval_tvc.do`

`tvc()`/`tsplit()` coefficient parity with two independent implementations of the same model: `stcrreg, tvc(x) texp(_t > c)` in-session (J=2, the only shape one `texp()` can express) and `cmprsk::crr` with `cov2`/`tf` interval indicators (any J), across a no-ties fixture, a three-interval fixture, and a tie fixture whose grid puts events exactly on the boundary. A third part composes `tvc()` with `strata()` on a fixture whose censoring rate differs by group and pins it against `crr`'s `cengroup`, with the pooled fit as the discriminating contrast. Standard errors are compared on the `nuisance noadjust` arm against crr's own full sandwich -- the whole covariance matrix, not only its diagonal -- and on the grouped-censoring arm as well, each printed beside the same comparison without the psi term. Each run prints its own measured maximum difference.

### `crossval_bstrata.do`

`bstrata()` coefficient parity with `crrSC::crrs`, the authors' own implementation of Zhou et al. (2011), at both `ctype` mappings (`bstrata()+strata()` = `ctype 1`, `bstrata()` alone = `ctype 2`), across two/three/four strata and with heavy ties. Since the variance unification the regime-1 **variance** is a real oracle too: `crrs` under `ctype 1` returns Zhou et al. sec. 4.1's `eta + psi` variance, which `finegray, bstrata(v) strata(v) nuisance` now computes, so the two are the same estimator computed twice by independent code. The eta-only arm is still compared beside it as a drift alarm, and the suite prints both numbers so the size of the `psi` term is visible rather than assumed. `ctype 2` standard errors are not compared: that is the paper's highly-stratified variance, a different derivation.

### `crossval_public_studies.do`

Regenerates public `crrSC::bce` ECOG breast-cancer and `crrSC::center` multicentre transplant examples, then compares `finegray` with the paper authors' `crrs` regular/high-stratification fits and `crrc` marginal clustered fit. It gates every coefficient, both comparable full covariance matrices, event counts, sample omissions, and stratum/cluster counts; the `ctype=2` covariance is deliberately excluded because it is a distinct highly-stratified derivation.

### `benchmark_finegray_crossval.do`

Wall-clock finegray-vs-`stcrreg` timings at N = 500 to 50,000, plus the one coefficient comparison that came with them. Not a correctness gate and not a lane member: stopwatch readings on a shared machine are timings, not cross-validation tests, so they are kept out of the lane and out of `crossval_finegray.do`.

### `run_all.sh`, `test_run_all_wrapper.sh`, `test_finegray_fg02_failclosed.sh`

Reliable shell status, provenance/receipts, wrapper regression, and stale-oracle fail-closed checks. The provenance comparison skips the run's own outputs — `run_all_status.txt` and `run_status_*.txt` are tracked as evidence of a PREVIOUS run, `run_all_inputs.sha256` is written beside them by a `--source-repo` run (copy it back and commit it with the receipt it belongs to), and all three are deleted or rewritten by this one — and distinguishes missing from modified tracked inputs (`n tracked, m missing, k modified, first: ...`); tests 11b-11d cover the exclusion, a modified `qa/` input, and a tracked input absent from the copy, with those receipt names committed into the synthetic repo so the exclusion is exercised rather than assumed.

### `validation_finegray_zzf_prereg_r.R`

Independent preregistration of the recovery gate's signed controls. Deliberately **not** a lane member: it records the expected sign of the arm-D negative-control bias, derived from the R oracle, *before* the gated repetitions run, and its output is quoted verbatim in the `Z2-PREREG` header of `validation_finegray_zzf_recovery.do` (and pointed at from `validation_finegray_zzf_coverage.do`). Re-derive with `cd finegray/qa && Rscript validation_finegray_zzf_prereg_r.R`.

## Oracle caching rationale

Every `crossval_*_r.R` in this suite is a **pure function of its inputs**. Four
simulate under a fixed seed (`crossval_finegray_r.R` 20260902,
`crossval_finegray_zzf_r.R` 20260713, `crossval_nuisance_r.R` 11/7/21,
`crossval_finegray_zzf_beta_r.R` 20260713 + rep); the other seven make no RNG
call at all and simply fit a model to a CSV the `.do` file exported. Either way
the same inputs produce byte-identical output on every run, forever.

Measured on the full lane (2026-09-04): `crossval_finegray_zzf` cost **2153 s —
98.5% of all cross-validation time** — and the other ten together cost ~56 s.
All of it was spent recomputing a constant on every single run.

So each R oracle now caches its output under `<cache>/<name>/<key>/` and
recomputes **only when an input actually changes**. `_fg_oracle_cache.R` holds
the one shared mechanism. `<cache>` is `$FG_ORACLE_CACHE_DIR` if set, else
`tools::R_user_dir("finegray_qa", "cache")` (`~/.cache/R/finegray_qa` on
Linux). The first version of this cache lived at `qa/.oracle_cache/` beside the
scripts and never filled: the devkit runs every QA lane from a throwaway
scratch copy of the package, so the entries were written into the copy and
discarded with it, and the next lane recomputed everything again (observed
2026-09-04: no cache directory existed anywhere after the lane that introduced
it). The key does not depend on where the scripts sit, so one per-user cache
serves the checkout, every scratch copy and every clone on the machine.

**What invalidates a cache entry** — the key covers every input that can move a
number:

- the md5 of the calling script, and of any oracle/definition file it sources;
- the md5 of every **input data file**. The `.do` files hand these scripts
  paths under `c(tmpdir)` that differ on every run, so the key is over file
  **content**, never over a path;
- named scalar parameters (`N`, `REPS`, a `beta` override);
- the **R version, the platform, and the version of every package used**. An
  oracle that silently moved from one `survival`/`cmprsk`/`crrSC` release to
  another is the exact drift a cross-validation exists to catch, so a cache
  keyed without it would *hide* that drift — worse than slow.

Any key mismatch, any missing cached blob, any md5 that disagrees with the
stored index, and the real computation runs. A partial cache never yields a
partial oracle; it yields a recomputation.

**Where the cache is, and why that matters.** It lives *inside* the R scripts,
not around `Rscript`. `crossval_finegray_zzf.do`'s FG-02 contract exists
because "an ignored `data/` cache from a prior good run still present" plus "a
broken or missing `Rscript`" once let a suite consume a stale oracle and report
a green 102/102. A cache that let a `.do` file **skip R** would rebuild that
hole exactly. This one cannot: R still runs, still deletes whatever stale
artifacts it deleted before, still writes every output, and still exits with a
real status the sentinel reads. **No `.do` file changed.**

**Forcing a recompute.** `FG_ORACLE_NOCACHE=1` disables every oracle cache for
a run:

```
FG_ORACLE_NOCACHE=1 stata-mp -b do run_all.do full
```

Deleting the cache directory has the same effect for the next run. The cache is
per user and outside the repository, so nothing about it is tracked: every
checkout, clone and scratch copy on this machine shares the one cache, and a
new machine populates its own on its first run. A cache carried from one
machine's R build to another would be the very drift the cross-validations
hunt, which is why it is never committed.

Entries are addressed by key hash, so a script invoked twice with different
inputs — `crossval_tvc.do`, `crossval_finegray.do` and
`crossval_predict_phtest.do` each call theirs twice — keeps both entries live
instead of the second clobbering the first.
