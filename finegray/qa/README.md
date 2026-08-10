# finegray — QA suite

Quality assurance for the **finegray** package (v1.2.0): the Fine and Gray (1999) subdistribution-hazards estimator (`finegray`) and its post-estimation tools (`finegray_predict`, `finegray_cif`, `finegray_phtest`).

This suite is built on four complementary assurance layers. Suites are grouped
by their primary purpose; no ordering is intended to rank one reference above
the known-truth oracles:

1. **Functional / regression tests** — every command, option, error path, and stored result behaves as documented.
2. **Validation** — model invariants and known answers that are checkable by hand or against Stata's own `stcrreg`, plus reproducible full-refit jackknife sensitivity envelopes for the fixed-weight analytic standard errors.
3. **Known-truth parameter recovery** — the lead correctness oracle: simulate competing-risks data from a Fine-Gray model whose true log-subhazard ratio *we* set, then prove `finegray` recovers it at large N while a naive cause-specific Cox model provably misses it.
4. **Cross-validation** — agreement with StataCorp's `stcrreg`, R's `cmprsk::crr` and `riskRegression`, plus an independent direct-equation R implementation for delayed-entry Weight 1.

## Headline results

**The committed receipt is older than the source.** `run_all_status.txt` and `run_status_full.txt` record a `full` run of 2026-08-10T19:54:06Z over a **33-suite / 654-check** tree. The package was edited after that run — a documentation-and-diagnostics pass, plus `test_finegray_estimates_use.do` and two new checks in `test_finegray_sthlp_render.do` — so **those two files no longer certify the tree in this directory**. They are kept as the last complete `full` receipt, not as the current one; re-run `./run_all.sh full --source-repo <checkout>` to replace them.

Every check in the table below **has** been observed passing against the current source — all **34 suites / 662 checks**, 0 failures, 0 skips — but as **three invocations, not one `full` run**, each from its own isolated scratch copy of the repo layout:

- `core` lane, 28/28 suites (`run_all.do core`);
- `test_finegray.do` 137/137, re-run on its own because the first scratch tree omitted `tabtools/`, which its `regtab` dependency needs — a missing sibling package makes that suite exit before its first check, and the runner correctly counted it as a failure rather than a pass;
- `python` lane, 5/5 suites (`crossval_cif` 2/2, `crossval_predict_phtest` 14/14, `crossval_finegray` 55/55, `crossval_finegray_zzf` 102/102 with the 100-dataset R oracle regenerated, `crossval_nuisance` 6/6).

**That is per-suite evidence, not a `full` receipt.** Only `run_all.sh` publishes one, and only from a single uninterrupted invocation: the three wrapper-level gates — the FG-02 stale-oracle fail-closed gate, the wrapper's own regression test, and the delayed-entry transfer proof — run *outside* `run_all.do` and did **not** run here. Re-run `./run_all.sh full --source-repo <checkout>` before release.

The three multi-hour ZZF Monte Carlo gates are intentionally outside `full`; their latest receipt remains the 2026-08-05 `run_status_gates.txt`. The standalone scaling benchmark was not rerun.

| Suite | Type | Tests | Pass | Fail | Skip |
|-------|------|------:|-----:|-----:|-----:|
| `test_finegray.do` | functional / regression | 137 | 137 | 0 | 0 |
| `test_finegray_v110.do` | regression (v1.1.0: CIF/predict/bootstrap surface + graph polish, multi-record post-estimation, adjacent gap/overlap rejection, LT SEs, stratified IPCW, stale-data/state guards, return gates, bootstrap accounting, factor-level bootstrap skips, `saving()` parsing, prediction-variable cleanup) | 54 | 54 | 0 | 0 |
| `test_finegray_v120.do` | regression (v1.2.0: `finegray_phtest` omnibus test retired — `r(chi2)`/`r(df)`/`r(p)` no longer stored, no Global test row printed, no global row appended to `r(phtest)`; per-covariate surface is the diagnostic `[correlation, events]`) | 4 | 4 | 0 | 0 |
| `test_finegray_v120b.do` | regression (v1.2.0 presentation pass: `e(b)`/`e(V)` named with the fitted factor terms rather than the internal `_fg_*` design columns and `test`/`testparm` accepting them; `e(covariates)` and the dropped-column rebuild unchanged; replay of `finegray` with no `varlist`, honouring `level()`/`noshr` and leaving `e()` untouched, `r(301)` without a finegray fit; `e(depvar)` = `_t`; `e(compete_values)`, `e(N_delayed)`, `e(N_G_trunc)`; the `finegray_cif` `at:` profile line for `at()` and for default means; out-of-support `attime()` notes with a silent in-support control; labelled/annotated `saving()` dataset; the display-only graph tail absent from `r(table)` and `saving()`; `finegray_predict, cif` labelling its evaluation basis; help-text consistency and rendered sentence spacing) | 16 | 16 | 0 | 0 |
| `test_finegray_release120.do` | final 1.2.0 release regressions: rejects `cluster()` with `norobust`; gives repeated clustered-bootstrap draws fresh cluster identities in both CIF paths; records raw PH residual scaling; checks grouped cluster-score aggregation against a nested reference; and verifies cluster-label invariance in both analytic CIF cores | 7 | 7 | 0 | 0 |
| `test_finegray_reporting.do` | regression (v1.2.0: `finegray_cif` `r(profile_vars)` reports the fitted TERMS rather than the internal `_fg_*` design columns, for `i.` and interaction fits, paired 1:1 with `r(at)`; bootstrap SE present and non-negative at every grid point in both bootstrap paths) | 7 | 7 | 0 | 0 |
| `test_finegray_determinism.do` | **repeat-call determinism** — the axis no other suite probes: identical calls must return bit-identical results. Covers the fit (`e(b)`/`e(V)`), `finegray_phtest` (all three `time()` transforms, and the separate ZZF/LT Mata branch), `finegray_predict` (`schoenfeld`/`cif`/`xb`), `finegray_cif`, post-estimation call-order independence, and an independent-route check that phtest's `rho` equals the raw-Schoenfeld/time correlation | 10 | 10 | 0 | 0 |
| `test_finegray_contracts.do` | contract regression: direct output-equivalence of the Mata weight-stratum mapping `_finegray_joint_setup` against the nested scan it replaced (60 randomized designs, incl. missing/negative/non-contiguous level codes, singleton strata and the 1x1 shape), plus a deliberately-wrong mapping the comparison must reject; the documented factor post-estimation contract in both directions (absent fitted level scores at rc 0 and identically to the full-data fit, unseen level refused `r(459)` with no partial output, no `fvrevar` call post-estimation); singleton- and 40-level censoring strata; fail-closed post-estimation information inversion | 13 | 13 | 0 | 0 |
| `test_finegray_ties.do` | **estimator core numerics** (censoring-tie left limit, `(t0,t]` entry boundary, ZZF entry-time at-risk count, intentional stcrreg LT non-parity) | 6 | 6 | 0 | 0 |
| `test_finegray_optimizer.do` | **optimizer safety** (identification, nonconvergence, stale `e(ll)`, degenerate `tolerance()`, scale invariance, nonfinite likelihoods) | 10 | 10 | 0 | 0 |
| `test_finegray_variance.do` | **variance and clustering** (cluster degeneracy, finite-sample adjustment, `e(rank)`/`e(N_clust)`, `stcrreg` SE parity, `norobust` contract) | 6 | 6 | 0 | 0 |
| `test_finegray_bootstrap.do` | **bootstrap and refit integrity** (`if`/`in` stripped from the refit line, replication floor, `seed()` guard, validate-then-mutate, cache-only/binary-search CIF helpers) | 9 | 9 | 0 | 0 |
| `test_finegray_postest.do` | **post-estimation contract, CIF/predict output, PH test** (factor terms aligned by level value, equivalent numeric factor tokens and truncated long names in `at()`, tampered `_fg_*` columns, `finegray_cif` rebuild of dropped `_fg_*` columns + curated refusal, `finegray_phtest` data preservation on error, zero-width CIs, `e(basehaz)` uniqueness, CIF terminal time, degenerate PH tests) | 27 | 27 | 0 | 0 |
| `test_finegray_fvgrammar.do` | **factor grammar + missing-value scoring** (FG-05: `ibn.`/`bn.` base-none terms fit with legal `_fg_` names and full postestimation incl. dropped-column rebuild; FG-01: a missing underlying factor/continuous covariate scores as *missing*, never the fitted base category, across `xb`/CIF/interactions; unseen nonmissing level still errors `r(459)`) | 8 | 8 | 0 | 0 |
| `test_finegray_fg03_diagnostic.do` | **phtest diagnostic-only** (FG-03: `r(phtest)` is `[correlation, events]`, no chi2/df/p in the matrix or the console; no-variation guard still fires `r(459)`) | 3 | 3 | 0 | 0 |
| `test_finegray_fg06_vce.do` | **delayed-entry variance contract** (FG-06: `e(lt_vce)` = `fixed_weight_sandwich` / `model_based` / `not_applicable`, never the mislabeled `fg_sandwich`; the documented whole-fit coefficient-bootstrap recipe runs and returns coefficient SEs) | 3 | 3 | 0 | 0 |
| `test_finegray_fg07_options.do` | **option-combination guards** (FG-07: `timevar()`/`level()` with `xb`, `level()` without `ci`, `level()` with `basecshazard`, and `finegray_cif` `bootstrap()`/`level()` without `ci` are all rejected `r(198)`; each paired with a positive control) | 8 | 8 | 0 | 0 |
| `validation_finegray.do` | validation / invariants | 45 | 45 | 0 | 0 |
| `validation_finegray_recovery.do` | known-truth recovery | 4 | 4 | 0 | 0 |
| `validation_finegray_recovery_paths.do` | known-truth recovery across option/coding/estimand paths | 15 | 15 | 0 | 0 |
| `validation_finegray_cif_recovery.do` | analytic CIF known-answer recovery | 5 | 5 | 0 | 0 |
| `validation_finegray_cif_se.do` | fixed-weight analytic CIF-SE path regressions plus an all-converged full-refit jackknife sensitivity envelope | 8 | 8 | 0 | 0 |
| `validation_finegray_lt_se.do` | left-truncation SE checks (exact score identity + coefficient/CIF delete-one sensitivity envelopes, including published same-group and factorized cross-classified pooled-stabilizer forms) | 6 | 6 | 0 | 0 |
| `crossval_finegray.do` | crossval vs `stcrreg` / `cmprsk` | 55 | 55 | 0 | 0 |
| `crossval_cif.do` | crossval vs `riskRegression` + bootstrap | 2 | 2 | 0 | 0 |
| `crossval_predict_phtest.do` | crossval vs `cmprsk::crr` | 14 | 14 | 0 | 0 |
| `crossval_predict_stcrreg.do` | crossval vs `stcrreg` | 15 | 15 | 0 | 0 |
| `test_finegray_zzf.do` | **delayed-entry (ZZF) surface** (`truncstrata()` parsing/guards, cross-classified support boundaries, `e()` weight + `e(lt_vce)` variance contract, postestimation design rebuild, cached/self-contained weight-path equivalence, FG-M06 limiting cases, delayed-entry breaking change, hard positivity failure, refit fidelity, weight warnings) | 28 | 28 | 0 | 0 |
| `test_finegray_estimates_use.do` | The **`estimates save` / `estimates use` round trip**, which no suite exercised although `finegray.sthlp` documents `basehaz` specifically for it. `estimates use` restores `e()` but **not** `e(sample)`, so `_finegray_check_data` computed its signature over zero rows and reported "data have changed" about data the user had not touched. Asserts the empty-sample diagnosis on the **message text** (the return code was 459 before and after, so rc cannot tell the two diagnoses apart), that the message names `estimates esample:`, that `predict xb/cif` and the replay survive the reload with the pre-save numbers, that `estimates esample:` reproduces the pre-save `r(table)` and `r(phtest)`, and that a **wrong** esample is still refused by the data signature | 6 | 6 | 0 | 0 |
| `test_finegray_sthlp_render.do` | The **render** axis, on two independent defects: (a) directives that survive into the rendered output, and (b) whitespace artifacts — a hyphenated compound or a sentence boundary broken across a source newline, which resolves its markup perfectly and still prints `inverse-probability-of- censoring` or `one.  The`. Every shipped `.sthlp` goes through Stata's own SMCL renderer (`translate ..., translator(smcl2txt)`); the file list comes from the package directory, not a hard-coded list. Each checker has its own fault injection, and the whitespace one also asserts it does **not** fire on a legitimate suspended hyphen (`a subject- or cluster-bootstrap`) — a checker that cries wolf on correct English gets switched off | 4 | 4 | 0 | 0 |
| `test_documentation_examples.do` | **runnable doc examples** — every README/help code block run verbatim (Quick Start, basic fit, `predict cif`, phtest, fit variants, cif/predict CI, `basehaz`/`basecshazard`) | 7 | 7 | 0 | 0 |
| `crossval_finegray_zzf.do` | **ZZF per-dataset parity vs the R oracle** (100 datasets, arms A/B/C/D/X, plus manifest/tolerance guards) | 102 | 102 | 0 | 0 |
| `test_finegray_nuisance.do` | **`nuisance` (FG 1999 eq. 7-8 psi) contract** — R-free: materiality, default-unchanged, both refusal gates with positive controls, `e(vce_meat)`, cluster path, `sum(psi)==0` invariant, finite-sample composition, beta invariance, post-estimation non-propagation, the Mata-level LT guard, and the no-competing-events reduction to Cox | 12 | 12 | 0 | 0 |
| `crossval_nuisance.do` | **`nuisance` parity vs the FG eq. (7)-(8) oracle** (5 fixtures: hand-checkable, tie-free, 5-way tied events, 3 censoring strata, PBC n=416/p=5). Checks **variances and covariances** — psi's effect is concentrated off-diagonal (up to 19.9% on PBC vs ~1% on the diagonals), and a covariance-only psi defect passes every diagonal assertion | 6 | 6 | 0 | 0 |
| **Total** | | **662** | **662** | **0** | **0** |

**As of 2026-08-10 the `full` lane is 34 suites / 662 checks** — the table above, which is the authoritative inventory.

`test_finegray_v120b.do` was added as the 33rd suite with 14 checks on 2026-08-07 for the 1.2.0 presentation pass. Twelve of those checks were observed to FAIL against the pre-fix tree; the other two are no-regression guards that pass on both. On 2026-08-10 two documentation regressions were added to it, both observed to FAIL against the pre-fix tree.

A shell-level negative gate, `test_finegray_fg02_failclosed.sh`, is run by `run_all.sh` after the Stata `python` and `full` lanes (it manipulates `PATH`, so it cannot live in the `.do` runner): it puts a failing `Rscript` first on `PATH` with a complete stale oracle cache present and asserts the ZZF crossval fails **closed** (`r(9)`, no passing `RESULT:` line) rather than consuming the stale cache — the FG-02 fail-open regression. Missing cache, missing script, nonzero exit, zero or duplicate PASS sentinels all prevent a green receipt.

### The delayed-entry (ZZF) suites

`finegray` estimates the subdistribution hazard under left truncation with the stabilized Zhang–Zhang–Fine Weight-1 estimator, using Geskus's product form `A(t) = G(t−)·H(t−)` in the one-stratum case and the equation-7 pooled-stabilizer form with stratum-specific denominators otherwise. Matching censoring and entry groups reproduce the paper's stratified construction; differing groups use the package's factorized cross-classification. Three suites guard the contract, and they answer different questions:

- **`crossval_finegray_zzf.do` — is it the right estimator?** By default it fits the *same 100 datasets* (20 replications in each of arms A/B/C/D/X) with Stata's `finegray` and with an independent R implementation and requires the coefficients to agree (worst observed relative difference 4.4e-6, which is the two optimizers' tolerance floor). This is a *per-dataset* comparison, not a comparison of Monte-Carlo means — and that distinction is the whole point. Bias is a property of the *estimator*, so a recovery study can never separate "this code is wrong" from "this estimator is biased here." Same-group arm C and genuinely cross-classified arm X specifically guard the pooled-stabilizer formula. The suite regenerates and manifest-checks its oracle on every run, including from a clean `qa/data/` directory. Its full contract is pinned to 20 replications of 3,000 subjects in each arm; the manifest rejects the smaller environment overrides that the R generator permits for direct smoke work.
- **`test_finegray_zzf.do` — is the surface sound?** Option parsing, the hard support boundaries, the stored `e()` contract, and — the one that matters — that changing a `truncstrata()` variable after estimation makes `finegray_cif` and `finegray_phtest` *fail* (`r(459)`) rather than silently rebuild a different weight design and report it as the fitted model.
- **`validation_finegray_lt_se.do` — is downstream inference coherent?** It verifies the per-subject score decomposition and compares robust coefficient and analytic CIF SEs with delete-one jackknives on both one-stratum and stratified pooled-stabilizer fits.

**The delayed-entry breaking change (Z8, Z21, Z22).** Under left truncation the weights are `A = G·H` and `A` is evaluated per observed joint group, so 150 `strata()` levels are 150 *weight* strata **even with no `truncstrata()`** — and the >100 boundary therefore refuses a delayed-entry model that the released version fitted. Without left truncation the same 150 strata still fit, because the no-LT path is required to stay bit-identical and an error is not bit-identical. That asymmetry is deliberate, so it is pinned from both sides: Z8 asserts the no-LT fit still succeeds, Z21 asserts the LT fit is `r(459)`, and Z22 asserts the refusal *names the option the user actually typed* — the first version of that message blamed a cross-classification with `truncstrata()` even when `truncstrata()` was never specified. A guard that fires correctly but explains itself falsely is still a defect, so the message text is part of the contract.

**The hard positivity failure (Z23).** Published stratified Weight 1 consults joint-stratum denominators both for genuinely at-risk subjects at cause-event times and for retained competing-event subjects at their exits. If any consulted denominator is **zero**, that contribution is undefined — and Mata returns *missing* for `x/0`, not infinity, so before the guard existed this surfaced far downstream as "the null log pseudo-likelihood is not finite" and `r(430)` **convergence not achieved**: a message that blames the optimizer for a property of the data and names no stratum. It is now a hard `r(459)` that reports how many denominator cells and which weight strata.

This was **found, not designed**: a benchmark lane (n = 8,000, 50 truncation strata) died on it, and 39 competing subjects turned out to have `A(X_i−)` *bit-exactly* zero — in a stratum holding 168 subjects, **eight times the ≥20-subject support boundary**. That is the whole point of Z23: the size boundary bounds how many subjects a stratum *holds*, not whether `A` stays away from zero where the scan actually divides by it, so Z6 cannot stand in for it. Splitting the sample into more weight strata makes the violation *more* likely, because each stratum's entry distribution `Ĥ_g` is then estimated from fewer subjects.

**Refit fidelity (Z24).** `e(refitcmd)` is what `finegray_cif`'s bootstrap re-issues on every resample. A fit option dropped from it does **not** error there: the refit converges, its covariates still match the stored profile, so the replication is *accepted* — and the bootstrap silently describes a **different estimator** than the point estimate it is wrapped around. `truncstrata()` was in fact missing, so a bootstrapped ZZF fit was resampling the **pooled-weight** estimator; against the pre-fix code Z24 shows a coefficient difference of **0.113**. Z24 deliberately does *not* look for the option by name — it asserts the invariant that running `e(refitcmd)` reproduces `e(b)`, so any fit option dropped in future fails on its own.

**The weight warnings actually fire (Z25).** Z14 only proves they stay *silent* on clean data, which a warning that can never fire also passes. Z25 fires them. It also guards a threshold collision worth remembering: the first positivity guard errored whenever `A(X_i−) ≤ 1e-10` — the *same* threshold as the low-`A` warning — so the fit aborted before the warning could ever be reached, making the denominator half of the documented `e()` warning contract unreachable dead code. The two are now distinct:

| condition | weight | behaviour |
|---|---|---|
| `A == 0` | **undefined** (Mata: `x/0` is missing) | hard `r(459)` |
| `0 < A < 1e-10` | defined but enormous | **warn**, and still fit |

### The `gates` lane — hours, not minutes

The three ZZF Monte Carlo gates live in their own lane (`run_all.do gates`) rather than in `full`. They are gates, not regression tests: a lane nobody can afford to run is a lane nobody runs, and putting a 4-hour Monte Carlo in `full` would take the ordinary suites down with it.

| Suite | Question | Cost |
|---|---|---|
| `validation_finegray_zzf_recovery.do` | **Gate Z2-green.** Does the ZZF estimator recover a known truth under delayed entry, where the released command was 63–190 MC SE off? | 100 reps × n = 100,000 × 4 arms (~4 h) |
| `validation_finegray_zzf_coverage.do` | **Gate Z-inference.** Which LT variance actually covers? | 1000 reps × 7 arms × 2 fits (~1 h) |
| `validation_finegray_zzf_factorization.do` | **Mechanism-conditioning sensitivity.** What happens when a driver of both entry and censoring is omitted from one or both mechanism groupings, and what support cost accompanies matching-group conditioning? | 100 reps × n = 100,000 × 5 fits + a positivity ladder (~2 h) |

**Running the three concurrently — and what it costs you.** The gates share no state, so they can be run at the same time in three scratch copies, one Stata process each with `set processors 1`. Measured 2026-08-05: **110 minutes wall** against 1 h 51 m for the same three run sequentially on an idle box, and roughly 7 h if the box is busy. Both were at full gate settings (`smoke=0`).

The catch is that concurrency forfeits the receipt. `run_status_gates.txt` is written only by `run_all.sh gates`, which drives `run_all.do gates` and runs the three in order; three separate invocations produce three per-suite `RESULT:` lines and no lane verdict. That is assembled evidence, not a receipt — the same distinction drawn under *Headline results* above. Use the concurrent form to get an answer fast; use `./run_all.sh gates --source-repo ~/Stata-Tools` when the artifact is the point. On an idle box the sequential run is not the 7 h the estimate suggests, so reach for it more readily than that number implies.

**Gate Z2-green:** the full 2026-07-15 run passed 8/8 at 100 replications × 100,000 retained subjects. Every arm/coefficient cell contained all 100 planned fits. Arms A–C recovered the true coefficients within 1.10 Monte Carlo SE; the deliberately wrong old-weight arm D remained decisively biased (|z| = 9.63 and 90.35), so the gate also demonstrated that it can reject the superseded formula.

**Gate Z-inference:** the full 2026-07-15 run passed on the corrected estimator: all 14 `fixed_weight_sandwich` arm/coefficient cells covered at 0.941–0.957 in the pooled arms and 0.943–0.949 in the two entry-stratified arms, with every cell containing all 1,000 planned fits. `model_based` covered without truncation but fell to 0.890–0.905 under light truncation, 0.850–0.858 under heavy truncation, and 0.737–0.806 in the entry-stratified arms. Smoke settings emit a failing sentinel/internal `r(9)`, and `run_all.sh` propagates that failure to the shell.

The gate verdict is the stated inferential target: empirical 95% Wald coverage in every arm, with every planned fit converged. It prints both mean-SE/plain-SD and mean-SE/IQR-SD ratios as diagnostics, but neither ratio can turn a cell green. The former IQR-based acceptance rule was post-hoc and targeted a robust central-spread measure rather than the standard-deviation scale a sandwich variance estimates. Both stratified arms use a latest-entry wave at 1.0; the recorded full run realized 43.9% and 52.8% truncation and fitted 1,000/1,000 replications, so an unbounded survivor-only fixture cannot pass.

**Mechanism-conditioning sensitivity.** Geskus Remark 1 says the published same-group `G·H` product-limit result holds irrespective of the `L`–`C` relationship; independence is needed only for separate marginal interpretations of the two factors. This gate therefore does not test whether the Geskus product “factorizes.” Its DGP makes a shared factor `W` (correlated with the covariate of interest) drive both entry and censoring while drawing `L` and `C` independently conditional on `W`. It asks whether omitting `W` from one or both mechanism groupings biases the fitted mean model and what support cost accompanies conditioning both mechanisms on increasingly fine `W`.

- **Part 1 — omitted conditioning, quantified.** Five paired specifications fit the same correct mean model on the same data each replication. `JOINT` (`strata(W) truncstrata(W)`) conditions both mechanism estimators on `W` and recovers the truth; `MARGINAL` and the two `SPLIT` arms omit `W` from at least one mechanism that depends on it and are biased. A `NULL` control with `W` inert recovers, attributing the contrast to omitted mechanism conditioning rather than to the existence of `W`, delayed entry, or the estimator. At the recorded full-gate settings, the three omitted-conditioning arms exceed the preregistered bias threshold while `JOINT` and `NULL` remain within the recovery tolerance.
- **Part 2 — the support cost.** Matching-group conditioning consults a stratum-specific denominator `A_W(X_i−)` in every cell, so refinement can reach the Z23 zero-denominator failure while a pooled but misspecified fit remains numerically feasible. This is a positivity warning, not a license to accept bias: the gate establishes no general bias bound, and feasibility cannot make a coarser mechanism model valid.

Like its two sibling gates, this is run on demand (smoke settings emit `smoke=1` and a failing sentinel, which `run_all.sh`/the runner treat as non-gating).

### Why the tie and optimizer suites exist

A green suite is only evidence if it *can* go red. Through v1.1.4 this one could not: the flagship cross-validation fixture (`webuse hypoxia`) has **zero** cause-event times shared with a censored observation, so a left-limit `G(t-)` implementation and a post-jump `G(t)` implementation agree on it *exactly*. The suite was 347/347 green while the estimator disagreed with both `cmprsk` and `stcrreg` on any tied dataset.

`test_finegray_ties.do` and `test_finegray_optimizer.do` were written against that blind spot. Both are verified to **fail against v1.1.4** and pass after the fix — that differential is the point of them, and `test_finegray_ties.do` test 1 asserts the hypoxia tie structure directly, so the reason the old suite could be green is now an executable fact rather than a footnote.

## How to run

Run from this `qa/` directory. The curated runner uses explicit lane membership (no globbing), sandboxes PLUS/PERSONAL under `c(tmpdir)`, and records a failed Stata result if any suite fails. Every suite also remains independently runnable; each derives the package root from `c(pwd)`, performs a clean local `net install`, and writes its log next to itself.

```bash
./run_all.sh full                     # full lane; shell/CI-safe exit status
./run_all.sh quick                    # functional/regression lane
./run_all.sh core                     # quick + validation + Stata-only crossval
./run_all.sh python                   # R-backed cross-validation lane
./run_all.sh gates                    # ZZF Monte Carlo gates -- HOURS, run on demand

stata-mp -b do run_all.do full       # direct Stata invocation; inspect RESULT in run_all.log

# one suite (batch mode writes <name>.log alongside the .do)
stata-mp -b do test_finegray.do
```

### Running from a scratch copy — pass `--source-repo`

The isolation practice is to run from a scratch **copy** of the package, so a concurrent lane cannot write into the same `qa/` directory. A copy is not a git checkout, which costs the wrapper two things it needs: the provenance stamp (`run_all_status.txt` recorded `pkg_tree: not-a-git-repo (unknown)` and `head_commit: unknown` on 2026-07-22, losing the one field that block exists to record) and the gated tree the delayed-entry transfer gate extracts. `--source-repo` supplies both, and the receipt additionally records whether the copy still matches the named repo:

```bash
SC=/tmp/fgqa && rm -rf $SC && mkdir -p $SC
cp -r ~/Stata-Tools/finegray $SC/finegray
cp -r ~/Stata-Tools/tabtools $SC/tabtools        # test_finegray.do needs ../tabtools
rm -f $SC/finegray/qa/*.log $SC/finegray/qa/run_all_status.txt
printf 'set processors 1\n' > $SC/finegray/qa/profile.do
cd $SC/finegray/qa && ./run_all.sh full --source-repo ~/Stata-Tools
```

Without it the transfer gate reports `NOT-RUN` in the receipt rather than passing silently.

Each suite prints a machine-parseable sentinel as its last line, e.g. `RESULT: validation_finegray tests=45 pass=45 fail=0`, and calls `exit 1` on any failure. On this installation the Stata batch binary can still return OS status 0 after an internal `r(1)`, so shell automation must not trust the Stata process code alone. `run_all.sh` requires exactly one numeric runner sentinel, verifies `tests = pass + fail`, `fail = 0`, and `skip = 0`, and propagates a reliable shell status. On `python` and `full`, it additionally requires exactly one evaluated `RESULT: test_finegray_fg02_failclosed tests=1 pass=1 fail=0` before writing a PASS receipt. Two further shell gates run the same way: `test_run_all_wrapper.sh` (every lane but `gates`) and, on `full`/`gates`, the delayed-entry **transfer gate** described below. All three write their verdict into the receipt, and any of them can take the lane red.

### Dependencies

| Suite | Needs |
|-------|-------|
| `test_*`, `validation_finegray*` | Stata only |
| `crossval_predict_stcrreg.do` | Stata only (`stcrreg` ships with Stata) |
| `crossval_finegray.do` | R + `cmprsk` (required); `fastcmprsk` (optional) |
| `crossval_cif.do` | R + `riskRegression`, `prodlim`, and `survival` |
| `crossval_predict_phtest.do` | R + `cmprsk` |
| `crossval_finegray_zzf.do` | R + `survival`; the suite regenerates and manifest-checks its oracle itself and fails if any required arm/replication is absent |
| `crossval_nuisance.do` | R + `survival`, `cmprsk`; regenerates `qa/data/` via `crossval_nuisance_r.R`, which self-validates against `cmprsk::crr` (whole matrix, not just diagonals) and aborts rather than emit a drifted oracle. It also prints the measured psi effect on both the variance and SE scales — the ranges quoted in the package `README.md` come from that print, not from memory |

Some R-backed files can report a standalone skip, but the curated runner treats every skip as an unrun check and therefore fails the lane. Install the references to get full parity coverage:

```r
install.packages(c("survival", "cmprsk", "riskRegression", "prodlim"))
# Optional acceleration reference used by crossval_finegray.do:
install.packages("fastcmprsk")
```

## File index

| File | Role |
|------|------|
| `run_all.do` | Curated Stata lane runner (`quick`, `core`, `python`, `full`, `gates`) |
| `run_all.sh` | Shell/CI wrapper that converts the numeric runner sentinel into a reliable OS exit status, runs the three shell gates (FG-02 fail-closed, the wrapper's own regression test, and the delayed-entry transfer gate), accepts `--source-repo PATH` so a scratch-copy run still stamps provenance, and writes receipts only after every applicable gate has a final verdict |
| `test_run_all_wrapper.sh` | Bounded shell regression for the wrapper itself, run against a fake `stata` binary: PASS/FAIL receipt ordering, missing or malformed FG-02 sentinels, stale-receipt removal after an early Stata failure, the transfer gate going red on drifted / truncated / never-published proof runs, `--source-repo` provenance, and the wrapper-test gate's own fail-closed behaviour. Invoked automatically by `run_all.sh` on every lane but `gates` (`FINEGRAY_WRAPPER_TEST_ACTIVE` guards the re-entry) |
| `test_finegray_fg02_failclosed.sh` | Standalone shell gate proving that a broken R oracle generator cannot consume a complete stale ZZF cache and report a pass |
| `run_all_status.txt`, `run_status_full.txt`, `run_status_gates.txt` | Tracked machine-readable lane receipts; the first mirrors the latest run and the lane-pinned files preserve full/gates evidence separately |
| `_finegray_qa_common.do` | Shared process-unique PLUS/PERSONAL sandbox bootstrap for the lane runner, plus the seeded fixture builders (`_finegray_qa_tied_data`, `_finegray_qa_entry_data`, `_finegray_qa_unident_data`) that the tie and optimizer suites are built on |
| `benchmark_finegray_zzf.do` | Standalone preregistered scaling measurement for the delayed-entry scan; fits CPU-time and incremental-memory log–log slopes and is intentionally outside `run_all.do` |
| `_benchmark_finegray_zzf_cell.do` | Fresh-process worker used by `benchmark_finegray_zzf.do` for one measured fit |
| `gates_transfer_proof.do` | The reproducible half of `run_status_gates.txt`: fits the same seeded delayed-entry model on two trees and diffs the `R|` rows, so the claim "the estimator core is provably unchanged since the last gate run" has a generator rather than being asserted. Takes a tree and a tag (`stata-mp -b do gates_transfer_proof.do "<tree>" <TAG>`), so it is outside `run_all.do` — it is run once per tree, not once per lane. `run_all.sh` drives both runs on `full`/`gates`; it sandboxes PLUS/PERSONAL like every other suite (it used to install the **gated** tree straight into the live adopath and leave it there). Both proof runs now leave their raw output in `qa/gates_transfer/` (`gt4_GATED.log`, `gt4_CURRENT.log`, `PROVENANCE.txt`), cleared and rewritten per run — previously they were written into a `mktemp` directory the EXIT trap deleted, so the `transfer_gate:` verdict outlived the four rows it compared |
| `gates_transfer_pin.txt` | The commit the three ZZF Monte Carlo gates were last actually run against. `run_all.sh` extracts this tree and diffs four delayed-entry arms against the tree under test. Move the pin only after re-running `./run_all.sh gates` (~7h) — moving it to silence a red transfer gate destroys the only evidence the gates still describe the shipped estimator |
| `test_finegray.do` | Master functional/regression suite for all four commands |
| `test_finegray_v110.do` | Regression tests for everything the collapsed version history attributes to v1.1.0. Merged mechanically from the four version-pinned suites that predated the collapse (v110 + v111 + v112 + v114); section banners inside the file preserve their origin. Covers: the v1.1.0 feature surface (CIF curves, bootstrap CI, multi-record `stsplit`, `level()`) and `finegray_cif` graph polish (single-row legend default, `legend()`/`title()`/`xtitle()` passthrough, single-curve/`nograph` paths); post-estimation parity between single-record and `stsplit` (reduced) fits, bootstrap refits on true entry times, `e(sample)` survival across `finegray_cif, bootstrap()`, `_fg_entry` lifecycle, multi-variable `strata()` through the CIF SE paths, string-`id()` bootstrap (no `r(109)` crash, no char/type leak, matches numeric path), cluster-level bootstrap resampling (SE inflated vs subject resampling), `finegray_cif, at()` factor-variable natural names; estimation-data signatures, stale-state invalidation, graph/save return gates, strict `saving()`/`at()` validation, all/partial bootstrap nonconvergence, restored estimates and `e(sample)`, helper `r()` isolation; factor-level bootstrap skips/counts, unspaced `saving(filename,replace)` parsing, and all-or-nothing prediction-variable cleanup |
| `test_finegray_v120.do` | Version-pinned regression for the v1.2.0 `finegray_phtest` diagnostic-only return and display contract |
| `test_finegray_release120.do` | Final 1.2.0 regressions for contradictory VCE options, repeated clustered-bootstrap identities, raw PH residuals, grouped cluster-score aggregation, and both clustered analytic-CIF cores |
| `test_finegray_determinism.do` | Exact repeat-call determinism on a deliberately tied fixture, plus independent raw-residual/phtest route agreement |
| `test_finegray_reporting.do` | Factor-aware `r(profile_vars)` and complete analytic/bootstrap CIF reporting |
| `test_finegray_contracts.do` | Direct weight-stratum mapping oracle, factor post-estimation contracts, high/singleton censoring-strata checks, and fail-closed post-estimation information inversion |
| `test_finegray_estimates_use.do` | The `estimates save` / `estimates use` round trip: which post-estimation commands survive a reload, the empty-`e(sample)` diagnosis and its `estimates esample:` remedy, and that a wrong esample is still refused by the data signature |
| `test_finegray_ties.do` | Estimator core numerics: censoring ties use the left limit `G(t-)` (matching `cmprsk`'s `xout = ftime*(1-100*eps)` and `stcrreg`), and the risk-set entry boundary is `(t0, t]` so a subject entering at exactly `t` is not at risk at `t`. Asserts tied-data parity with `stcrreg`, exact entry-boundary invariance, and — as an executable fact — that `webuse hypoxia` has zero censor/event time collisions and is therefore blind to the tie convention |
| `test_finegray_optimizer.do` | Optimizer safety: rank-deficient information is a hard error rather than a fabricated coefficient; nonconvergence, `tolerance(.)`/`(0)`/`(-1)` and `iterate(.)` are hard errors; `e(ll)` is recomputed at the accepted β; the convergence test is scale invariant (Newton decrement, not coefficient-scale step size); nonfinite trial likelihoods are never accepted as improvements |
| `test_finegray_variance.do` | Variance and clustering: degenerate cluster counts are rejected (the clustered meat has rank at most `g-1`, so `g <= p` errors instead of reporting g-inverse artefacts — 1 cluster previously returned `rc 0` with `SE = 1.4e-11`); the finite-sample adjustment `N/(N-1)`, or `g/(g-1)` under `cluster()`, is applied by default and removed by exactly `noadjust`, matching `stcrreg`; `e(rank)` and `e(N_clust)` are posted and `e(df_m)` is the numerical rank of `e(V)`; default SEs agree with `stcrreg`'s default to `< 1e-3` relative and `noadjust` reproduces its `noadjust`; `norobust` reports a genuinely distinct (model-based) variance at identical coefficients |
| `test_finegray_bootstrap.do` | Bootstrap and refit integrity: an `in`-qualified fit can be bootstrapped (the refit replays `e(refitcmd)`, which carries no sample qualifier — replaying `e(cmdline)` gave `rc 498, 0/B`), while a variable-based `if` fit still resamples the estimation sample only; the replication floor of 25 is enforced on both the request and the successes (a band was previously built from two replications); `seed()` without `bootstrap()` errors instead of being silently ignored, and seeded runs reproduce; multi-record reduction validates before it mutates, so a failed re-fit cannot strand the prior fit's `_fg_entry`; `e(refitcmd)` replayed on the estimation sample reproduces the fit exactly |
| `test_finegray_postest.do` | Post-estimation data contract and output correctness (Phases 5-7). Factor terms are rebuilt from the fit-time expansion `e(fvsemantic)` and aligned to the current data **by level value**, not positionally: fitting on `i.grp` over {1,2,3} and shifting the data to {2,3,4} used to apply the level-2 coefficient to level 3 at rc 0, and an unfitted level on new data was silently collapsed onto the base category. `finegray_cif, at()` uses that same semantic map, so equivalent numeric spellings and a generated `_fg_*` name truncated before a long level suffix cannot silently select the reference profile. A `_fg_*` design column that is *altered in place* is now detected (dropping one is still supported, since consumers rebuild it: `finegray_cif` reconstructs dropped `_fg_*` columns from `e(fvsemantic)` to a bit-identical CIF/CI — analytic and bootstrap paths — and refuses with a curated `r(459)` when the underlying raw variable is also gone, instead of a bare `r(111)`; `finegray_phtest` leaves the caller's data intact if it aborts mid-`preserve`). Confidence limits that cannot be computed stay missing instead of collapsing onto the point estimate — through v1.1.4 a nonfinite SE produced a zero-width interval presented as a real one, and `r(table)` carried `lci = uci = cif` even when `ci` was never requested. `e(basehaz)` carries one row per unique cause-event *time* (it was one row per *event*, so 50 tied events gave 50 rows and 1 unique time). The CIF grid always closes on the terminal basehaz row — the thinning stride used to step over it depending on the *parity* of the row count, silently dropping the CIF's plateau. And a proportional-hazards diagnostic with no time variation errors instead of reporting a blank correlation row at rc 0 |
| `test_finegray_fvgrammar.do` | Base-none factor grammar, interaction rebuilds, missing-value scoring, and unseen-level refusal |
| `test_finegray_fg03_diagnostic.do` | Diagnostic-only `finegray_phtest` matrix/display contract and no-variation refusal |
| `test_finegray_fg06_vce.do` | Delayed-entry variance labeling and runnable whole-fit coefficient bootstrap |
| `test_finegray_fg07_options.do` | Positive and negative checks for invalid post-estimation option combinations |
| `test_finegray_zzf.do` | Delayed-entry surface and regression contract: `truncstrata()` parsing, cross-classified support/positivity boundaries, weight diagnostics, `e(lt_weight)`/`e(lt_vce)`, post-estimation design rebuilding, limiting cases, refit fidelity, and live warning paths |
| `test_finegray_nuisance.do` | R-free Fine–Gray estimated-weight influence-term contract, refusal gates, score invariants, clustering, and Cox reduction |
| `test_documentation_examples.do` | Runs the documented README/help workflows and advertised baseline options verbatim after a local install |
| `validation_finegray.do` | 45 known-answer and invariant checks (incl. live `stcrreg` parity) |
| `validation_finegray_recovery.do` | Known-truth log-SHR recovery from a Fine-Gray DGP |
| `validation_finegray_recovery_paths.do` | Known-truth log-SHR recovery across 15 option/coding/estimand code paths (null/strong effects, binary/factor/interaction covariates, non-default `cause()`/`censvalue()`, cluster/norobust VCE, heavy censoring, high/low incidence, `level()`, multi-record reduction) |
| `validation_finegray_cif_recovery.do` | Analytic CIF known-answer recovery: `finegray_cif` vs the closed-form DGP oracle F₁(t;z)=1−(1−p·(1−e^−ᵗ))^exp(z′b) at reference and non-zero profiles, plateau, monotonicity/bounds |
| `validation_finegray_cif_se.do` | Deterministic analytic-path regression plus an all-converged full-refit jackknife sensitivity envelope; not an exact fixed-weight variance oracle |
| `validation_finegray_lt_se.do` | Left-truncation SE checks: exact score-residual sum identity plus delete-one sensitivity envelopes for coefficient and CIF SEs on delayed-entry DGPs |
| `crossval_finegray.do` | Systematic estimator parity vs `stcrreg` and `cmprsk::crr` (coefficients, SEs, LL, CIF, strata, benchmarks) |
| `crossval_finegray_r.R` | R companion: `cmprsk::crr` / `fastcmprsk::fastCrr` reference fits |
| `crossval_cif.do` | CIF point estimates vs `riskRegression`; CIF SEs vs subject bootstrap |
| `crossval_cif_r.R` | R companion: `riskRegression::FGR` + `predictRisk` |
| `crossval_predict_phtest.do` | Row-level `finegray_predict` and `finegray_phtest` parity vs R |
| `crossval_predict_phtest_r.R` | R companion for the predict/phtest cross-check |
| `crossval_predict_stcrreg.do` | Every prediction path vs native `stcrreg` (no external dependency) |
| `crossval_finegray_zzf.do` | Dataset-by-dataset Stata parity with the regenerated direct-equation ZZF oracle; manifest requires arms A/B/C/D/X and every replication |
| `crossval_finegray_zzf_beta_r.R` | Generates the ZZF parity datasets, oracle coefficients, and manifest; cross-checks the direct objective with `survival::coxph` |
| `crossval_finegray_zzf_r.R` | Independent direct-equation Weight-1 implementation, external-software controls, tied-time decision fixtures, and the quarantined `mstate::crprep` sentinel |
| `crossval_nuisance.do` | Whole-matrix variance/covariance parity for the opt-in estimated-weight influence term |
| `crossval_nuisance_r.R` | Independent Fine–Gray equation (7)–(8) nuisance reference with `cmprsk::crr` self-validation |
| `validation_finegray_zzf_recovery.do` | Full known-truth delayed-entry recovery gate (smoke settings are explicitly non-gating) |
| `validation_finegray_zzf_coverage.do` | Full delayed-entry variance-coverage gate (smoke settings are explicitly non-gating) |
| `validation_finegray_zzf_factorization.do` | Mechanism-conditioning sensitivity: omitted shared drivers contrasted with matching-group conditioning and its positivity cost (smoke settings are explicitly non-gating) |
| `validation_finegray_zzf_prereg_r.R` | Reproducible independent-R preregistration of the recovery gate's signed negative-control expectations |
| `.gitignore` | Excludes generated artifacts (`.log`, `.csv`, `.dta`, `.xlsx`, …) |

## Lane membership

| Lane | Suites |
|------|--------|
| `quick` | `test_finegray.do`, `test_finegray_v110.do`, `test_finegray_v120.do`, `test_finegray_v120b.do`, `test_finegray_release120.do`, `test_finegray_ties.do`, `test_finegray_optimizer.do`, `test_finegray_variance.do`, `test_finegray_bootstrap.do`, `test_finegray_postest.do`, `test_finegray_zzf.do`, `test_finegray_fvgrammar.do`, `test_finegray_fg03_diagnostic.do`, `test_finegray_fg06_vce.do`, `test_finegray_fg07_options.do`, `test_finegray_nuisance.do`, `test_finegray_determinism.do`, `test_finegray_reporting.do`, `test_finegray_contracts.do`, `test_finegray_estimates_use.do`, `test_finegray_sthlp_render.do`, `test_documentation_examples.do` |
| `core` | `quick` + `validation_finegray.do`, `validation_finegray_recovery.do`, `validation_finegray_recovery_paths.do`, `validation_finegray_cif_recovery.do`, `validation_finegray_cif_se.do`, `validation_finegray_lt_se.do`, `crossval_predict_stcrreg.do` |
| `python` | `crossval_cif.do`, `crossval_predict_phtest.do`, `crossval_finegray.do`, `crossval_finegray_zzf.do`, `crossval_nuisance.do` |
| `full` | `core` + `python` |
| `gates` | `validation_finegray_zzf_recovery.do`, `validation_finegray_zzf_coverage.do`, `validation_finegray_zzf_factorization.do` |
| Shell gates (run by `run_all.sh`, not `run_all.do`) | `test_run_all_wrapper.sh` (all lanes but `gates`); `test_finegray_fg02_failclosed.sh` (`python`, `full`); the delayed-entry transfer gate driving `gates_transfer_proof.do` against `gates_transfer_pin.txt` (`full`, `gates`). Each is also runnable by hand |
| Standalone measurement | `benchmark_finegray_zzf.do` (uses `_benchmark_finegray_zzf_cell.do`; intentionally not a `run_all.do` lane) |

## Coverage map

Keyed to the command surface. Every public command, option, and stored result is exercised somewhere below.

> **On the determinism axis — a correctly-conceived test that could not fire.** The
> `finegray_phtest` reproducibility defect is worth reading carefully, because the axis was *not*
> unprobed. Two suites already tested it, both green on the broken code:
>
> - `crossval_predict_phtest.do` **P15**, "phtest deterministic (same model → identical results on
>   re-run)" — the *exact* command, the *exact* property, calling it twice and comparing the full
>   `r(phtest)` matrix. It had even been strengthened to assert the whole matrix rather
>   than two scalars.
> - `validation_finegray.do` **V13**, the same idea for the fit.
>
> Neither could ever have fired, for two compounding reasons:
> 1. **Fixture.** Both use `hypoxia`, which this package's own scaffold documents as having zero
>    cause-event times shared with a censored observation — effectively tie-free. **Ties are the
>    entire mechanism**: with distinct event times `sort _t` is already a total order and the
>    defect cannot appear at all.
> 2. **Tolerance.** Both assert to `1e-10`. The drift is `8e-16` — six orders of magnitude *below*
>    the tolerance. P15 would have passed on tied data too.
>
> So the lesson is not "add coverage for determinism"; the coverage existed and was well named. It
> is that **a determinism check is only a determinism check at exact equality, on a fixture that can
> express the failure.** Any tolerance silently converts "identical" into "close", which is a much
> weaker and quite different claim. (P15 also lives in the `python` lane, so it only runs where R is
> installed — a third reason it was a weak guard.)
>
> `test_finegray_determinism.do` therefore asserts **bit equality for repeat calls** on a deliberately
> tied fixture whose tie density is itself asserted first (DET-0), so the suite cannot go vacuously
> green, and it lives in `quick` so it always runs. DET-9 is a separate route-agreement check:
> `finegray_phtest` must agree with a manually computed raw-Schoenfeld/time correlation within
> `1e-6`. Verified to go red on the pre-fix build: DET-2/3/4/8 fail, while
> DET-1/5/6/7/9 stay green on both builds.

### `finegray` (estimation)

| Surface | Where tested |
|---------|--------------|
| Core fit, 1/2/3-covariate models, cause(1)/cause(2) | T5–T8, V1–V6, C1–C5 |
| Options `noshr`, `level()`, `robust`/`norobust`, `cluster()`, `strata()`, `censvalue()`, `noadjust`, `basehaz`, `iterate()`, `tolerance()`, `nolog` | T9–T17, T26, V22, V24, V26, V29, C11–C12, C51–C55; `test_finegray_variance.do`; `test_finegray_postest.do` |
| Delayed-entry options and stored contract: `truncstrata()`, cross-classified grouping, `e(lt_weight)`, `e(lt_vce)`, and weight diagnostics | `test_finegray_zzf.do`, `validation_finegray_lt_se.do`, `crossval_finegray_zzf.do` |
| Factor variables (`i.`, `ib#.`, `##` interactions) | T18–T19, V25, V42–V45, C27 |
| Combined options | T20 |
| Error handling (no `stset`, missing `compete()`/`cause()`, bad cause, no competing events, no `id()`, removed options) | T21–T30 |
| Stored results `e(b)`, `e(V)`, `e(basehaz)`, all scalars/macros, event-count identity | T31–T37, V19–V20 |
| Data preservation, `if`/`in`, multi-record / left truncation | T8, T26, V23, V27–V28, test_v110 |
| Coefficients / LL / χ² / SEs vs `stcrreg` | V1–V6, V9–V10, V24b, C1–C10 |
| Subdistribution-hazard / model invariants (SHR>0, scaling, reproducibility, convergence, explicit rank-deficiency rejection, separation, zero-event strata) | V7–V14, V37–V41 |
| **Repeat-call determinism (bit equality)** — the fit and every post-estimation command; separate raw-residual route agreement | `test_finegray_determinism.do` DET-1..9 |
| **Weight-stratum mapping, directly** — `_finegray_joint_setup` output vs the scan it replaced (no other suite references this function) | `test_finegray_contracts.do` JS-1..5 |
| **Documented factor post-estimation contract** — absent fitted level vs unseen level | `test_finegray_contracts.do` FV-1..5 |

### `finegray_predict`

| Surface | Where tested |
|---------|--------------|
| `xb`, `cif`, `schoenfeld`, `basecshazard`, and `timevar()` | V15–V18, A1–A7, P1–P5; `test_documentation_examples.do` |
| CIF confidence intervals, `level()`, `bootstrap()`, `seed()`, name-collision guard, `if`/`in` estimation-sample fix | `test_finegray_v110.do`, `test_finegray_bootstrap.do` (multi-record fits, multi-var strata, LT jackknife) |
| `xb` / `cif` / `schoenfeld` agreement with `stcrreg` within registered numerical tolerances | A1–A7 |
| Row-level `xb` / `cif` / `schoenfeld` vs `cmprsk::crr` | P1–P11 |

### `finegray_cif`

| Surface | Where tested |
|---------|--------------|
| Fixed-horizon table, semantic factor-level `at()` mapping, `attime()`, `timepoints()`, `saving()`, `e(cmd)` guard, complete `r()` payload | `test_finegray_v110.do`, `test_finegray_postest.do` (safe parsing and graph/save failure gates) |
| Bootstrap CI, `level()` width control | test_v110 (nonconverged refits skipped; counts and state restoration) |
| Graph legend, `legend()`/`title()`/`xtitle()` passthrough, `nograph` | test_v110 |
| CIF point estimates vs `riskRegression::predictRisk`; SEs vs bootstrap | crossval_cif |
| Analytic CIF SE vs full-refit jackknife sensitivity envelope; all delete-one fits converged; `finegray_cif`/`finegray_predict` SE agreement | validation_cif_se |

### `finegray_phtest`

| Surface | Where tested |
|---------|--------------|
| Per-variable residual-time **correlation** (`r(phtest)` columns `correlation`/`events`), `r(N_fail)`, `time()` functions, and `detail` output. `finegray_phtest` is descriptive: no null calibration for this simple statistic is implemented or established here, so it reports no chi2/df/p | V30–V36; `test_finegray_fg03_diagnostic.do`; `test_documentation_examples.do` |
| Residual-time correlation vs R at a common β (rank/log/identity, tie-free sim — **coding-consistency only**, not a test-calibration claim: `cmprsk` ships no PH test, so R recomputes the same correlation); hypoxia functional validity; internal consistency and determinism | P3, P12, P14–P15 |

## The four assurance layers in detail

### 1. Functional / regression (361 checks across 20 suites)

`test_finegray.do` (137) walks the full command surface in eleven sections: installation and helper auto-load, basic fits, every option individually and in combination, one test per documented error message, complete stored-result inventory, data preservation, and edge cases. `test_finegray_v110.do` (53) is a version-pinned regression suite that locks in the v1.1.0 CIF/predict/bootstrap surface and the `finegray_cif` graph polish (single-row legend default, `legend()`/`title()`/`xtitle()` passthrough, single-curve/`nograph` paths), together with the correctness, state-safety, return-gate, bootstrap-convergence, and adjacent-interval validation fixes accumulated since that release. The remaining 17 focused suites cover ties, optimizer and variance safety, bootstrap/refit integrity, post-estimation and factor grammar, delayed entry, nuisance inference, determinism, reporting, internal contracts, option guards, and runnable documentation.

### 2. Validation and deterministic checks (59 checks across three suites)

`validation_finegray.do` proves correctness across four sets of checks:

- **Live `stcrreg` parity** — coefficients match Stata's own Fine-Gray estimator to **< 1e-4** and the log-likelihood to **< 0.001** (V1–V6), both against frozen reference values and re-fit in the same session (V4).
- **Mathematical invariants** — SHR > 0; constant and exactly collinear terms are rejected as unidentified; χ² equals the Wald form *b′V⁻¹b*; p = `chi2tail(df, χ²)`; covariate scaling moves coefficients proportionally; adding an irrelevant covariate leaves the others unchanged; identical re-runs are bit-identical (V7–V14).
- **Prediction invariants** — CIF ∈ [0,1], monotone non-decreasing, and equal to `1 − exp(−H₀(t)·exp(xβ))`; `xb` equals manual *Zβ*; baseline cumulative hazard is positive, increasing, and time-sorted (V15–V20).
- **Robustness** — symmetric positive-definite robust and `norobust` covariance, strata, the multi-record `if`/`in` `bysort` fix, `censvalue()` invariance, predict `if`/`in` invariance, factor variables, phtest invariants, and stress cases (non-convergence, collinearity, near-separation, zero-event strata, interactions) (V21–V45).

`validation_finegray_cif_se.do` (8) checks the analytic CIF-SE path by two independent routes. `finegray_cif` and `finegray_predict` must report the same analytic SE, and a seeded delete-one **full-refit jackknife**, `(n−1)/n · Σ(F₍₋ᵢ₎ − F̄)²`, must stay within a fixed regression envelope across two profiles and three horizons; all 150 delete-one fits must converge. The jackknife is deliberately labelled a sensitivity check, not an oracle for the shipped fixed-weight variance: each refit re-estimates G, while the analytic SE treats G as fixed. No R package exposes the matching fixed-weight analytic CIF SE.

`validation_finegray_lt_se.do` (6) extends the deterministic checks to delayed entry: per-subject scores must sum to the fitted estimating equation, and coefficient plus CIF standard errors are compared with delete-one jackknives on both one-stratum and published same-group stratified pooled-stabilizer fits. A separate score identity exercises the factorized extension with different censoring and entry groupings.

### 3. Known-truth parameter recovery (24 tests across three suites) — the lead oracle

`validation_finegray_recovery.do` is the strongest correctness statement the suite makes, because the truth is set by us, not borrowed from another estimator. It simulates competing risks directly from the Fine-Gray subdistribution model

> F₁(t; z) = 1 − (1 − p·(1 − e^(−t)))^exp(z′b)

with the event-time CDF inverted in closed form, so the true log-SHR **b** is known exactly. At N = 50 000–60 000:

| Scenario | Truth | Recovered |
|----------|-------|-----------|
| A: positive single coefficient | b = +0.5 | ✓ within 0.03, and naive Cox provably misses |
| B: negative single coefficient | b = −0.7 | ✓ within 0.03 |
| C: two-covariate model | (0.5, −0.4) | ✓ both within 0.03 |
| D: `strata()` under group-dependent censoring | b = +0.6 | ✓ within 0.03 |

Each scenario also confirms that a **cause-specific Cox model misses the truth** on the same data (it targets a different estimand), proving the scenario actually exercises what the Fine-Gray estimator is built to do rather than passing trivially. The 0.03 tolerance is ~2× the worst Monte-Carlo error observed across a 6-seed mini-MC and ~4× the analytic SE — deterministic at the fixed seeds, not a loose band.

`validation_finegray_recovery_paths.do` (15) drives the **same** closed-form DGP through fifteen distinct invocation and coding paths, so recovery is proven not just for the core fit but for every branch a user can reach: a null effect (β = 0, SHR = 1) and a strong one (β = 1.0, cause-specific Cox provably misses); a binary covariate, three continuous covariates, an `i.grp` factor, and an `i.grp##c.z1` interaction; non-default `cause(2)` and `censvalue(9)` codings; `cluster()` and `norobust` variance estimators (point estimate recovers, `e(vce)` correct); heavy independent censoring (~75% censored, IPCW stress); high (p = 0.6) and low (p = 0.2) baseline incidence; `level(90)` invariance; and the multiple-record reduction — an `stsplit` panel fit recovers the truth and matches its single-record counterpart to `reldif < 1e-4`.

`validation_finegray_cif_recovery.do` (5) extends the known-truth idea to the **predicted cumulative incidence** (`finegray_cif`). At the reference profile z = 0 the DGP collapses to the exact, estimator-free oracle F₁(t; 0) = p·(1 − e^(−t)); the suite asserts `finegray_cif` reproduces it across horizons (and the general F₁(t; z) = 1 − (1 − p·(1 − e^(−t)))^exp(z′b) at z = 1), checks the plateau and the [0,1]/monotonicity invariants, and repeats at p = 0.6. Observed max absolute error 0.0015–0.0030 at N = 120 000. This suite also exercises the CIF influence-function variance code at realistic N, where the O(_n_ log _n_) prefix-sum rewrite (v1.1.1, numerically identical to the prior O(_n_²) implementation) keeps it practical (~7 s vs ~91 s per call at N = 120 000).

### 4. Cross-validation (194 checks across six suites)

| Suite | Reference | What it proves |
|-------|-----------|----------------|
| `crossval_predict_stcrreg.do` | StataCorp `stcrreg` | `finegray_predict` `xb`, `exp(xb)` (relative subhazard), covariate and baseline CIF, `e(basehaz)`, Schoenfeld residuals (incl. tied-time group sums), and SHR/SE/95% CI all agree within registered tolerances: point quantities and residual aggregates to `1e-5` or tighter, robust SEs and CIs within **2%** relative. Also includes a GitHub issue&nbsp;#1 regression guard (C1/C2): the fixed-horizon (`timevar()`) CIF matches the correct baseline-CIF mapping `1-(1-basecif)^exp(xb)` to ~6e-8 and is asserted **not** to equal the wrong `basecif^exp(xb)`. No external dependency; never skips. |
| `crossval_finegray.do` | `stcrreg` + `cmprsk::crr` | Coefficients vs `stcrreg` to **< 1e-4** across covariate combinations and both causes; log-likelihood, robust SEs (ratio 0.95–1.05), strata via `cengroup`, high-censoring stress, simulated-DGP direction recovery, and N = 500–50 000 performance benchmarks. Strata parity vs `cmprsk` `cengroup` (C51–C55): coefficients < 1e-6, SEs < 0.1%, relative LL difference < 1e-6, CIF < 1e-5. |
| `crossval_cif.do` | R `riskRegression` | `finegray_cif` point estimates match `riskRegression::predictRisk` (**< 1e-4**); analytic CIF standard errors stay within a registered same-dataset subject-bootstrap sensitivity envelope, with all 400 refits required to converge. The bootstrap re-estimates weights, so this is not exact parity for the fixed-weight analytic SE. |
| `crossval_predict_phtest.do` | `cmprsk::crr` | Row-level `xb` (**< 0.001**) and CIF (**< 0.01**) vs R. Schoenfeld residuals and the `finegray_phtest` residual-time **correlation** are cross-checked at a **common β** (finegray's coefficients passed to R, isolating the residual algorithm from optimizer-to-optimizer β differences): on tie-free simulated data the residuals and the correlation agree with R across rank/log/identity transforms to **< 1e-4**. This is a coding-consistency check, not a test-calibration claim — `cmprsk` ships no PH test, so R recomputes the same correlation; `finegray_phtest` reports no chi2/p-value (FG-03). Hypoxia (heavy ties + a near-zero censoring weight) is checked for functional validity only — its residuals are compared with `stcrreg` within the registered `1e-5` aggregate tolerance in `crossval_predict_stcrreg.do`. Includes an internal `predict schoenfeld` → manual correlation → `phtest` consistency check and a determinism check. |
| `crossval_finegray_zzf.do` | Independent R implementation of Zhang–Zhang–Fine Weight 1 | Per-dataset coefficient parity on 100 regenerated datasets: pooled arms A/B/D, published same-group stratification C, and genuinely cross-classified censoring/entry groups X. A manifest requires every arm and replication; an independent `coxph` optimizer cross-checks the direct R objective before Stata sees its result. |
| `crossval_nuisance.do` | Fine–Gray equation (7)–(8) R oracle + `cmprsk::crr` | Whole-matrix variance/covariance parity for five fixtures, including ties, censoring strata, and PBC; a covariance-only deliberate defect proves diagonal-only checks are insufficient. |

#### Tolerance rationale

Tolerances are tiered by how close the reference algorithm is to `finegray`:

- **Same algorithm (`stcrreg`, identical model):** point quantities and residual aggregates use absolute tolerances of `1e-5` or tighter; coefficients < 1e-4, LL < 0.001, SE/CI < 2%.
- **Different implementation, same estimand (`cmprsk`, `riskRegression`):** coefficients < 0.01, xb < 0.001, CIF < 0.01, Schoenfeld < 0.05.
- **PH diagnostic correlation (at a common β, tie-free data):** < 1e-4 absolute. On tie-heavy or ill-conditioned data the per-event residual is convention- and truncation-dependent, so the row-level residual is checked against the relevant implementation contract rather than treated as a calibrated test.
- **Full-refit SE sensitivity (CIF subject bootstrap / delete-one jackknife):** ~15% bootstrap and tighter seeded jackknife envelopes catch gross scaling or routing errors, but are not exact fixed-weight variance oracles because both refit procedures re-estimate weights.

## Conventions

- **Self-contained & relocatable** — no hardcoded paths; package root is derived from `c(pwd)`, and generated R cross-check CSVs live in the ignored `qa/data/` directory. Nothing under `qa/` is required at runtime by the package.
- **Clean install per suite** — each `.do` `ado uninstall`s then `net install`s `finegray` from the local source, so tests run against the working tree, never a shadowed installed copy.
- **Test isolation** — every test block re-establishes its own data (`webuse hypoxia` or a seeded simulation); no test depends on prior state.
- **Semantic assertions** — checks compare against expected *values* (or tight analytic bounds), not mere existence.
- **Machine-parseable** — each suite ends with a `RESULT: <name> tests=N pass=N fail=N [skip=N]` sentinel. The curated runner requires exactly one evaluated numeric sentinel, rejects failures/skips/smoke settings even when a do-file returns `rc=0`, deletes each prior suite log before execution, and fails the lane on any malformed result. `run_all.sh` applies the same contract at the shell boundary, removes stale receipts before starting, requires the exact FG-02 PASS sentinel where applicable, and writes the final receipt only after that shell gate.
- **No tracked artifacts** — generated logs/CSVs/datasets are gitignored.

## What a clean run demonstrates

- The tested known-truth DGPs recover their specified log-SHRs within the registered tolerances.
- Without delayed entry, coefficients, likelihood, predictions, and untied-time Schoenfeld residuals agree with the documented `stcrreg` contract; tied residuals are compared by event-time sums.
- Independent R references (`cmprsk`, `riskRegression`, and the direct Weight-1 oracle) agree on the explicitly scoped coefficient, CIF, diagnostic-correlation, and delayed-entry checks.
- The postestimation surface is exercised for analytic and bootstrap paths, error contracts, stored results, and documentation examples.
