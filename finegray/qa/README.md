# finegray — QA suite

Quality assurance for the **finegray** package (v1.2.0): the Fine and Gray (1999) subdistribution-hazards estimator (`finegray`) and its post-estimation tools (`finegray_predict`, `finegray_cif`, `finegray_phtest`).

This suite is built on four assurance layers, applied in increasing order of authority:

1. **Functional / regression tests** — every command, option, error path, and stored result behaves as documented.
2. **Validation** — model invariants and known answers that are checkable by hand or against Stata's own `stcrreg`, including a closed-form (deterministic delete-one jackknife) oracle for the analytic CIF standard error.
3. **Known-truth parameter recovery** — the lead correctness oracle: simulate competing-risks data from a Fine-Gray model whose true log-subhazard ratio *we* set, then prove `finegray` recovers it at large N while a naive cause-specific Cox model provably misses it.
4. **Cross-validation** — agreement with StataCorp's `stcrreg`, R's `cmprsk::crr` and `riskRegression`, plus an independent direct-equation R implementation for delayed-entry Weight 1.

## Headline results

The latest isolated `full` lane passed 25/25 suites and 563/563 checks on 2026-07-18, with no failures or skips (plus the shell-level `fg02_failclosed` gate). Smoke gate runs are never counted as passes.

| Suite | Type | Tests | Pass | Fail | Skip |
|-------|------|------:|-----:|-----:|-----:|
| `test_finegray.do` | functional / regression | 133 | 133 | 0 | 0 |
| `test_finegray_v110.do` | regression (v1.1.0: CIF/predict/bootstrap surface + graph polish, multi-record post-estimation, LT SEs, stratified IPCW, stale-data/state guards, return gates, bootstrap accounting, factor-level bootstrap skips, `saving()` parsing, prediction-variable cleanup) | 52 | 52 | 0 | 0 |
| `test_finegray_v120.do` | regression (v1.2.0: `finegray_phtest` omnibus test retired — `r(chi2)`/`r(df)`/`r(p)` no longer stored, no Global test row printed, no global row appended to `r(phtest)`; per-covariate surface is the diagnostic `[correlation, events]`) | 4 | 4 | 0 | 0 |
| `test_finegray_ties.do` | **estimator core numerics** (censoring-tie left limit, `(t0,t]` entry boundary, ZZF entry-time at-risk count, intentional stcrreg LT non-parity) | 6 | 6 | 0 | 0 |
| `test_finegray_optimizer.do` | **optimizer safety** (identification, nonconvergence, stale `e(ll)`, degenerate `tolerance()`, scale invariance, nonfinite likelihoods) | 10 | 10 | 0 | 0 |
| `test_finegray_variance.do` | **variance and clustering** (cluster degeneracy, finite-sample adjustment, `e(rank)`/`e(N_clust)`, `stcrreg` SE parity, `norobust` contract) | 6 | 6 | 0 | 0 |
| `test_finegray_bootstrap.do` | **bootstrap and refit integrity** (`if`/`in` stripped from the refit line, replication floor, `seed()` guard, validate-then-mutate) | 6 | 6 | 0 | 0 |
| `test_finegray_postest.do` | **post-estimation contract, CIF/predict output, PH test** (factor terms aligned by level value, equivalent numeric factor tokens and truncated long names in `at()`, tampered `_fg_*` columns, `finegray_cif` rebuild of dropped `_fg_*` columns + curated refusal, `finegray_phtest` data preservation on error, zero-width CIs, `e(basehaz)` uniqueness, CIF terminal time, degenerate PH tests) | 22 | 22 | 0 | 0 |
| `test_finegray_fvgrammar.do` | **factor grammar + missing-value scoring** (FG-05: `ibn.`/`bn.` base-none terms fit with legal `_fg_` names and full postestimation incl. dropped-column rebuild; FG-01: a missing underlying factor/continuous covariate scores as *missing*, never the fitted base category, across `xb`/CIF/interactions; unseen nonmissing level still errors `r(459)`) | 8 | 8 | 0 | 0 |
| `test_finegray_fg03_diagnostic.do` | **phtest diagnostic-only** (FG-03: `r(phtest)` is `[correlation, events]`, no chi2/df/p in the matrix or the console; no-variation guard still fires `r(459)`) | 3 | 3 | 0 | 0 |
| `test_finegray_fg06_vce.do` | **delayed-entry variance contract** (FG-06: `e(lt_vce)` = `fixed_weight_sandwich` / `model_based` / `not_applicable`, never the mislabeled `fg_sandwich`; the documented whole-fit coefficient-bootstrap recipe runs and returns coefficient SEs) | 3 | 3 | 0 | 0 |
| `test_finegray_fg07_options.do` | **option-combination guards** (FG-07: `timevar()`/`level()` with `xb`, `level()` without `ci`, `level()` with `basecshazard`, and `finegray_cif` `bootstrap()`/`level()` without `ci` are all rejected `r(198)`; each paired with a positive control) | 6 | 6 | 0 | 0 |
| `validation_finegray.do` | validation / invariants | 45 | 45 | 0 | 0 |
| `validation_finegray_recovery.do` | known-truth recovery | 4 | 4 | 0 | 0 |
| `validation_finegray_recovery_paths.do` | known-truth recovery across option/coding/estimand paths | 15 | 15 | 0 | 0 |
| `validation_finegray_cif_recovery.do` | analytic CIF known-answer recovery | 5 | 5 | 0 | 0 |
| `validation_finegray_cif_se.do` | closed-form CIF-SE oracle (jackknife) | 7 | 7 | 0 | 0 |
| `validation_finegray_lt_se.do` | left-truncation SE oracles (score identity + coefficient/CIF delete-one jackknives, including published same-group and factorized cross-classified pooled-stabilizer forms) | 6 | 6 | 0 | 0 |
| `crossval_finegray.do` | crossval vs `stcrreg` / `cmprsk` | 55 | 55 | 0 | 0 |
| `crossval_cif.do` | crossval vs `riskRegression` + bootstrap | 2 | 2 | 0 | 0 |
| `crossval_predict_phtest.do` | crossval vs `cmprsk::crr` | 14 | 14 | 0 | 0 |
| `crossval_predict_stcrreg.do` | crossval vs `stcrreg` | 15 | 15 | 0 | 0 |
| `test_finegray_zzf.do` | **delayed-entry (ZZF) surface** (`truncstrata()` parsing/guards, cross-classified support boundaries, `e()` weight + `e(lt_vce)` variance contract, postestimation design rebuild, FG-M06 limiting cases, delayed-entry breaking change, hard positivity failure, refit fidelity, weight warnings) | 27 | 27 | 0 | 0 |
| `test_documentation_examples.do` | **runnable doc examples** — every README/help code block run verbatim (Quick Start, basic fit, `predict cif`, phtest, fit variants, cif/predict CI, `basehaz`/`basecshazard`) | 7 | 7 | 0 | 0 |
| `crossval_finegray_zzf.do` | **ZZF per-dataset parity vs the R oracle** (100 datasets, arms A/B/C/D/X, plus manifest/tolerance guards) | 102 | 102 | 0 | 0 |
| **Total** | | **563** | **563** | **0** | **0** |

A shell-level negative gate, `test_finegray_fg02_failclosed.sh`, is run by `run_all.sh` at the end of the `python` and `full` lanes (it manipulates `PATH`, so it cannot live in the `.do` runner): it puts a failing `Rscript` first on `PATH` with a complete stale oracle cache present and asserts the ZZF crossval fails **closed** (`r(9)`, no passing `RESULT:` line) rather than consuming the stale cache — the FG-02 fail-open regression.

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
| `validation_finegray_zzf_factorization.do` | **Factorization sensitivity.** What does the product weight `A = G·H` cost when `L` and `C` share a dependence that does not split across `strata()`/`truncstrata()`, and why is the fully-joint alternative a positivity/variance (Z23) choice rather than the default? | 100 reps × n = 100,000 × 5 fits + a positivity ladder (~2 h) |

**Gate Z2-green:** the full 2026-07-15 run passed 8/8 at 100 replications × 100,000 retained subjects. Every arm/coefficient cell contained all 100 planned fits. Arms A–C recovered the true coefficients within 1.10 Monte Carlo SE; the deliberately wrong old-weight arm D remained decisively biased (|z| = 9.63 and 90.35), so the gate also demonstrated that it can reject the superseded formula.

**Gate Z-inference:** the full 2026-07-15 run passed on the corrected estimator: all 14 `fixed_weight_sandwich` arm/coefficient cells covered at 0.941–0.957 in the pooled arms and 0.943–0.949 in the two entry-stratified arms, with every cell containing all 1,000 planned fits. `model_based` covered without truncation but fell to 0.890–0.905 under light truncation, 0.850–0.858 under heavy truncation, and 0.737–0.806 in the entry-stratified arms. Smoke settings emit a failing sentinel/internal `r(9)`, and `run_all.sh` propagates that failure to the shell.

The scale check uses an **IQR-implied** SD and prints the plain-SD ratio beside it. This choice was re-audited on final code rather than defended from the old survivor-only result. Bounded-entry probes at 43.9% and 52.8% truncation retained every one of 1,000 fits and covered at 0.939–0.943, while mean-SE/plain-SD remained 0.85–0.90 and mean-SE/IQR-SD was 0.95–0.97. The discrepancy therefore persisted away from fit attrition: it reflects a heavy sampling tail, not a few excluded positivity failures. Coverage is the direct interval criterion; IQR scale checks the central distribution. The gate applies it uniformly to both candidates and all arms, requires `nr == REPS` in every cell, and continues to print the raw ratio. Both stratified arms now use a latest-entry wave at 1.0, realized 43.9% and 52.8% truncation in the full run, and fitted 1,000/1,000 replications; an unbounded fixture can no longer pass on survivors.

**Factorization sensitivity — the honest weakness, converted.** The product weight `A(t−) = G(t−)·H(t−)` (Geskus 2011 eq. 11) buys separability at the price of an assumption ZZF (2011 §3.2, after eq. 6) states directly: within a weight cell the joint truncation–censoring probability must factor, `P(L ≤ t ≤ C | cell) = P(L ≤ t | cell)·P(C ≥ t | cell)`, i.e. the entry mechanism `L` and the censoring mechanism `C` must be conditionally independent. ZZF §5 (the BMT example) is the paper's own negative control for the *covariate-dependent-truncation* half of that assumption; `validation_finegray_zzf_factorization.do` is the negative control for the *product* half — a shared factor `W` (correlated with the covariate of interest) that drives **both** `L` and `C`, so the dependence cannot be absorbed by conditioning on either grouping alone. This is the sensitivity analysis a referee who sees a factorized `G·H` weight will ask for, and it answers both questions the referee is really asking: is the product form fragile, and is it a defensible choice?

- **Part 1 — the bias, quantified.** Five paired specifications fit the same correct mean model on the same data each replication. `JOINT` (`strata(W) truncstrata(W)` — the fully-joint, matching-groups eq. 7 form) conditions `W` in **both** factors and **recovers** the truth; `MARGINAL` (no strata) and the two `SPLIT` arms (`strata(W)` only, `truncstrata(W)` only) violate the factorization and are **biased**. The `SPLIT` arms are the literal content of "a dependence that does not split across the two groupings": conditioning `W` in one grouping alone does not fix it, and — a finding worth stating — the two `SPLIT` arms err in **opposite directions**, so half-conditioning is *worse* than the symmetric `MARGINAL` omission. A `NULL` control (`MARGINAL` on data where `W` is inert) recovers, proving the bias is the dependence and not the estimator. At the full gate settings (100 reps × n = 100,000, corr(x1,W) ≈ 0.5) the observed b1 biases are `SPLIT_H` −0.102 (z = −41.6), `SPLIT_G` +0.057 (z = +31.0), `MARGINAL` −0.048 (z = −23.9), against `JOINT` −0.004 (z = −1.7, inside the ±3 MC-SE recovery band); the `NULL` control recovers at z = −1.9. The three misspecified arms clear the |z| > 5 bias threshold by wide margins while `JOINT`/`NULL` stay within tolerance — the gate passes 10/10.
- **Part 2 — the trade, priced.** The fully-joint fix is not free, and that is why it is not the default. It consults a stratum-specific denominator `A_W(X_i−)` in every joint cell — exactly the quantity **Z23** shows goes to zero under refinement. So the choice is bias-variance/**positivity**: `JOINT` is unbiased here but more variable than `MARGINAL` (observed mean analytic SE ratio ≈ 1.11 at K = 2), and as `W` is refined its denominator hits the Z23 hard failure `r(459)` while the pooling `MARGINAL` product stays feasible. The positivity ladder observes this directly — at K = 80 the fully-joint fit dies with the genuine Z23 message ("*consulted joint-stratum denominator cell(s) are zero*") on a dataset where `MARGINAL` fits without complaint. The shipped factorized default is that trade, made deliberately: a small *observed* bias in this constructed sensitivity scenario when `L` and `C` share an unsplit dependence (not a general theoretical bound — the quantity measured here is the bias in the tested DGP), in exchange for a weight that stays defined as strata refine.

Like its two sibling gates, this is run on demand (smoke settings emit `smoke=1` and a failing sentinel, which `run_all.sh`/the runner treat as non-gating).

This gate runs under the `gates` lane (on demand, hours not minutes), separately from the `full` lane whose counts appear in the Headline results above; its last recorded green run was 2026-07-15.

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

Each suite prints a machine-parseable sentinel as its last line, e.g. `RESULT: validation_finegray tests=45 pass=45 fail=0`, and calls `exit 1` on any failure. On this installation the Stata batch binary can still return OS status 0 after an internal `r(1)`, so shell automation must not trust the Stata process code alone. `run_all.sh` requires exactly one numeric runner sentinel, verifies `tests = pass + fail`, `fail = 0`, and `skip = 0`, and propagates a reliable shell status.

### Dependencies

| Suite | Needs |
|-------|-------|
| `test_*`, `validation_finegray*` | Stata only |
| `crossval_predict_stcrreg.do` | Stata only (`stcrreg` ships with Stata) |
| `crossval_finegray.do` | R + `cmprsk` (required); `fastcmprsk` (optional) |
| `crossval_cif.do` | R + `riskRegression`, `prodlim`, and `survival` |
| `crossval_predict_phtest.do` | R + `cmprsk` |
| `crossval_finegray_zzf.do` | R + `survival`; the suite regenerates and manifest-checks its oracle itself and fails if any required arm/replication is absent |

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
| `run_all.sh` | Shell/CI wrapper that converts the numeric runner sentinel into a reliable OS exit status |
| `_finegray_qa_common.do` | Shared process-unique PLUS/PERSONAL sandbox bootstrap for the lane runner, plus the seeded fixture builders (`_finegray_qa_tied_data`, `_finegray_qa_entry_data`, `_finegray_qa_unident_data`) that the tie and optimizer suites are built on |
| `benchmark_finegray_zzf.do` | Standalone preregistered scaling measurement for the delayed-entry scan; fits CPU-time and incremental-memory log–log slopes and is intentionally outside `run_all.do` |
| `_benchmark_finegray_zzf_cell.do` | Fresh-process worker used by `benchmark_finegray_zzf.do` for one measured fit |
| `test_finegray.do` | Master functional/regression suite for all four commands |
| `test_finegray_v110.do` | Regression tests for everything the collapsed version history attributes to v1.1.0. Merged mechanically from the four version-pinned suites that predated the collapse (v110 + v111 + v112 + v114); section banners inside the file preserve their origin. Covers: the v1.1.0 feature surface (CIF curves, bootstrap CI, multi-record `stsplit`, `level()`) and `finegray_cif` graph polish (single-row legend default, `legend()`/`title()`/`xtitle()` passthrough, single-curve/`nograph` paths); post-estimation parity between single-record and `stsplit` (reduced) fits, bootstrap refits on true entry times, `e(sample)` survival across `finegray_cif, bootstrap()`, `_fg_entry` lifecycle, multi-variable `strata()` through the CIF SE paths, string-`id()` bootstrap (no `r(109)` crash, no char/type leak, matches numeric path), cluster-level bootstrap resampling (SE inflated vs subject resampling), `finegray_cif, at()` factor-variable natural names; estimation-data signatures, stale-state invalidation, graph/save return gates, strict `saving()`/`at()` validation, all/partial bootstrap nonconvergence, restored estimates and `e(sample)`, helper `r()` isolation; factor-level bootstrap skips/counts, unspaced `saving(filename,replace)` parsing, and all-or-nothing prediction-variable cleanup |
| `test_finegray_ties.do` | Estimator core numerics: censoring ties use the left limit `G(t-)` (matching `cmprsk`'s `xout = ftime*(1-100*eps)` and `stcrreg`), and the risk-set entry boundary is `(t0, t]` so a subject entering at exactly `t` is not at risk at `t`. Asserts tied-data parity with `stcrreg`, exact entry-boundary invariance, and — as an executable fact — that `webuse hypoxia` has zero censor/event time collisions and is therefore blind to the tie convention |
| `test_finegray_optimizer.do` | Optimizer safety: rank-deficient information is a hard error rather than a fabricated coefficient; nonconvergence, `tolerance(.)`/`(0)`/`(-1)` and `iterate(.)` are hard errors; `e(ll)` is recomputed at the accepted β; the convergence test is scale invariant (Newton decrement, not coefficient-scale step size); nonfinite trial likelihoods are never accepted as improvements |
| `test_finegray_variance.do` | Variance and clustering: degenerate cluster counts are rejected (the clustered meat has rank at most `g-1`, so `g <= p` errors instead of reporting g-inverse artefacts — 1 cluster previously returned `rc 0` with `SE = 1.4e-11`); the finite-sample adjustment `N/(N-1)`, or `g/(g-1)` under `cluster()`, is applied by default and removed by exactly `noadjust`, matching `stcrreg`; `e(rank)` and `e(N_clust)` are posted and `e(df_m)` is the numerical rank of `e(V)`; default SEs agree with `stcrreg`'s default to `< 1e-3` relative and `noadjust` reproduces its `noadjust`; `norobust` reports a genuinely distinct (model-based) variance at identical coefficients |
| `test_finegray_bootstrap.do` | Bootstrap and refit integrity: an `in`-qualified fit can be bootstrapped (the refit replays `e(refitcmd)`, which carries no sample qualifier — replaying `e(cmdline)` gave `rc 498, 0/B`), while a variable-based `if` fit still resamples the estimation sample only; the replication floor of 25 is enforced on both the request and the successes (a band was previously built from two replications); `seed()` without `bootstrap()` errors instead of being silently ignored, and seeded runs reproduce; multi-record reduction validates before it mutates, so a failed re-fit cannot strand the prior fit's `_fg_entry`; `e(refitcmd)` replayed on the estimation sample reproduces the fit exactly |
| `test_finegray_postest.do` | Post-estimation data contract and output correctness (Phases 5-7). Factor terms are rebuilt from the fit-time expansion `e(fvsemantic)` and aligned to the current data **by level value**, not positionally: fitting on `i.grp` over {1,2,3} and shifting the data to {2,3,4} used to apply the level-2 coefficient to level 3 at rc 0, and an unfitted level on new data was silently collapsed onto the base category. `finegray_cif, at()` uses that same semantic map, so equivalent numeric spellings and a generated `_fg_*` name truncated before a long level suffix cannot silently select the reference profile. A `_fg_*` design column that is *altered in place* is now detected (dropping one is still supported, since consumers rebuild it: `finegray_cif` reconstructs dropped `_fg_*` columns from `e(fvsemantic)` to a bit-identical CIF/CI — analytic and bootstrap paths — and refuses with a curated `r(459)` when the underlying raw variable is also gone, instead of a bare `r(111)`; `finegray_phtest` leaves the caller's data intact if it aborts mid-`preserve`). Confidence limits that cannot be computed stay missing instead of collapsing onto the point estimate — through v1.1.4 a nonfinite SE produced a zero-width interval presented as a real one, and `r(table)` carried `lci = uci = cif` even when `ci` was never requested. `e(basehaz)` carries one row per unique cause-event *time* (it was one row per *event*, so 50 tied events gave 50 rows and 1 unique time). The CIF grid always closes on the terminal basehaz row — the thinning stride used to step over it depending on the *parity* of the row count, silently dropping the CIF's plateau. And a proportional-hazards diagnostic with no time variation errors instead of reporting a blank correlation row at rc 0 |
| `test_finegray_zzf.do` | Delayed-entry surface and regression contract: `truncstrata()` parsing, cross-classified support/positivity boundaries, weight diagnostics, `e(lt_weight)`/`e(lt_vce)`, post-estimation design rebuilding, limiting cases, refit fidelity, and live warning paths |
| `test_documentation_examples.do` | Runs the documented README/help workflows and advertised baseline options verbatim after a local install |
| `validation_finegray.do` | 45 known-answer and invariant checks (incl. live `stcrreg` parity) |
| `validation_finegray_recovery.do` | Known-truth log-SHR recovery from a Fine-Gray DGP |
| `validation_finegray_recovery_paths.do` | Known-truth log-SHR recovery across 15 option/coding/estimand code paths (null/strong effects, binary/factor/interaction covariates, non-default `cause()`/`censvalue()`, cluster/norobust VCE, heavy censoring, high/low incidence, `level()`, multi-record reduction) |
| `validation_finegray_cif_recovery.do` | Analytic CIF known-answer recovery: `finegray_cif` vs the closed-form DGP oracle F₁(t;z)=1−(1−p·(1−e^−ᵗ))^exp(z′b) at reference and non-zero profiles, plateau, monotonicity/bounds |
| `validation_finegray_cif_se.do` | Closed-form (deterministic delete-one jackknife) oracle for the analytic CIF standard error |
| `validation_finegray_lt_se.do` | Left-truncation SE oracles: exact score-residual sum identity plus delete-one jackknife for robust coefficient SEs and the influence-function CIF SE on a delayed-entry DGP |
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
| `validation_finegray_zzf_recovery.do` | Full known-truth delayed-entry recovery gate (smoke settings are explicitly non-gating) |
| `validation_finegray_zzf_coverage.do` | Full delayed-entry variance-coverage gate (smoke settings are explicitly non-gating) |
| `validation_finegray_zzf_factorization.do` | Factorization sensitivity gate: bias of the product weight `A=G·H` under an unsplit `L`–`C` dependence, contrasted with the fully-joint estimator as a positivity/variance (Z23) choice (smoke settings are explicitly non-gating) |
| `validation_finegray_zzf_prereg_r.R` | Reproducible independent-R preregistration of the recovery gate's signed negative-control expectations |
| `.gitignore` | Excludes generated artifacts (`.log`, `.csv`, `.dta`, `.xlsx`, …) |

## Lane membership

| Lane | Suites |
|------|--------|
| `quick` | `test_finegray.do`, `test_finegray_v110.do`, `test_finegray_v120.do`, `test_finegray_ties.do`, `test_finegray_optimizer.do`, `test_finegray_variance.do`, `test_finegray_bootstrap.do`, `test_finegray_postest.do`, `test_finegray_zzf.do`, `test_documentation_examples.do` |
| `core` | `quick` + `validation_finegray.do`, `validation_finegray_recovery.do`, `validation_finegray_recovery_paths.do`, `validation_finegray_cif_recovery.do`, `validation_finegray_cif_se.do`, `validation_finegray_lt_se.do`, `crossval_predict_stcrreg.do` |
| `python` | `crossval_cif.do`, `crossval_predict_phtest.do`, `crossval_finegray.do`, `crossval_finegray_zzf.do` |
| `full` | `core` + `python` |
| `gates` | `validation_finegray_zzf_recovery.do`, `validation_finegray_zzf_coverage.do`, `validation_finegray_zzf_factorization.do` |
| Standalone measurement | `benchmark_finegray_zzf.do` (uses `_benchmark_finegray_zzf_cell.do`; intentionally not a `run_all.do` lane) |

## Coverage map

Keyed to the command surface. Every public command, option, and stored result is exercised somewhere below.

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

### `finegray_predict`

| Surface | Where tested |
|---------|--------------|
| `xb`, `cif`, `schoenfeld`, `basecshazard`, and `timevar()` | V15–V18, A1–A7, P1–P5; `test_documentation_examples.do` |
| CIF confidence intervals, `level()`, `bootstrap()`, `seed()`, name-collision guard, `if`/`in` estimation-sample fix | `test_finegray_v110.do`, `test_finegray_bootstrap.do` (multi-record fits, multi-var strata, LT jackknife) |
| `xb` / `cif` / `schoenfeld` bit-exact vs `stcrreg` | A1–A7 |
| Row-level `xb` / `cif` / `schoenfeld` vs `cmprsk::crr` | P1–P11 |

### `finegray_cif`

| Surface | Where tested |
|---------|--------------|
| Fixed-horizon table, semantic factor-level `at()` mapping, `attime()`, `timepoints()`, `saving()`, `e(cmd)` guard, complete `r()` payload | `test_finegray_v110.do`, `test_finegray_postest.do` (safe parsing and graph/save failure gates) |
| Bootstrap CI, `level()` width control | test_v110 (nonconverged refits skipped; counts and state restoration) |
| Graph legend, `legend()`/`title()`/`xtitle()` passthrough, `nograph` | test_v110 |
| CIF point estimates vs `riskRegression::predictRisk`; SEs vs bootstrap | crossval_cif |
| Analytic CIF SE vs closed-form jackknife; `finegray_cif`/`finegray_predict` SE agreement | validation_cif_se |

### `finegray_phtest`

| Surface | Where tested |
|---------|--------------|
| Per-variable residual-time **correlation** (`r(phtest)` columns `correlation`/`events`), `r(N_fail)`, `time()` functions, and `detail` output. `finegray_phtest` is a diagnostic: it reports no chi2/df/p (no published null calibration exists under the subdistribution model) | V30–V36; `test_finegray_fg03_diagnostic.do`; `test_documentation_examples.do` |
| Residual-time correlation vs R at a common β (rank/log/identity, tie-free sim — **coding-consistency only**, not a test-calibration claim: `cmprsk` ships no PH test, so R recomputes the same correlation); hypoxia functional validity; internal consistency and determinism | P3, P12, P14–P15 |

## The four assurance layers in detail

### 1. Functional / regression (293 checks across 14 suites)

`test_finegray.do` (133) walks the full command surface in eleven sections: installation and helper auto-load, basic fits, every option individually and in combination, one test per documented error message, complete stored-result inventory, data preservation, and edge cases. `test_finegray_v110.do` (52) is a version-pinned regression suite that locks in the v1.1.0 CIF/predict/bootstrap surface and the `finegray_cif` graph polish (single-row legend default, `legend()`/`title()`/`xtitle()` passthrough, single-curve/`nograph` paths), together with the correctness, state-safety, return-gate, and bootstrap-convergence fixes of that release, so none of it can silently regress. It was merged mechanically from the four version-pinned suites that predated the version-history collapse; the merged file reproduces their combined 52/52 exactly. The tie, optimizer, variance, bootstrap, postestimation, delayed-entry-surface, and documentation-example suites contribute the remaining executable regression guards.

### 2. Validation and deterministic oracles (58 checks across three suites)

`validation_finegray.do` proves correctness across four sets of checks:

- **Live `stcrreg` parity** — coefficients match Stata's own Fine-Gray estimator to **< 1e-4** and the log-likelihood to **< 0.001** (V1–V6), both against frozen reference values and re-fit in the same session (V4).
- **Mathematical invariants** — SHR > 0; constant and exactly collinear terms are rejected as unidentified; χ² equals the Wald form *b′V⁻¹b*; p = `chi2tail(df, χ²)`; covariate scaling moves coefficients proportionally; adding an irrelevant covariate leaves the others unchanged; identical re-runs are bit-identical (V7–V14).
- **Prediction invariants** — CIF ∈ [0,1], monotone non-decreasing, and equal to `1 − exp(−H₀(t)·exp(xβ))`; `xb` equals manual *Zβ*; baseline cumulative hazard is positive, increasing, and time-sorted (V15–V20).
- **Robustness** — symmetric positive-definite robust and `norobust` covariance, strata, the multi-record `if`/`in` `bysort` fix, `censvalue()` invariance, predict `if`/`in` invariance, factor variables, phtest invariants, and stress cases (non-convergence, collinearity, near-separation, zero-event strata, interactions) (V21–V45).

`validation_finegray_cif_se.do` (7) adds a **closed-form (deterministic) oracle for the analytic CIF standard error**. finegray reports an influence-function (sandwich) SE for the cumulative incidence, with the censoring weights treated as known; no R package exposes a Fine-Gray CIF SE, so the only external check available to `crossval_cif.do` is a Monte-Carlo subject bootstrap. This suite supplies the deterministic counterpart: the delete-one **jackknife** variance, `(n−1)/n · Σ(F₍₋ᵢ₎ − F̄)²`, computed by refitting on leave-one-subject-out samples — an entirely independent mechanism that never touches the SE Mata code. Because removing one subject perturbs the censoring KM only infinitesimally, the jackknife matches the analytic SE far more tightly than the bootstrap does: on a seeded DGP the analytic SE sits at a stable ratio of **0.97–0.99** to the jackknife across two covariate profiles and three horizons (the ~1–2% gap is exactly the known-censoring assumption), and `finegray_cif` and `finegray_predict` are confirmed to report a bit-identical SE.

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

### 4. Cross-validation (188 checks against software and direct-equation references)

| Suite | Reference | What it proves |
|-------|-----------|----------------|
| `crossval_predict_stcrreg.do` | StataCorp `stcrreg` | `finegray_predict` `xb`, `exp(xb)` (relative subhazard), covariate and baseline CIF, `e(basehaz)`, Schoenfeld residuals (incl. tied-time group sums), and SHR/SE/95% CI all match the native estimator — bit-exact on point estimates, **< 2%** relative on robust SEs and CIs. Also includes a GitHub issue&nbsp;#1 regression guard (C1/C2): the fixed-horizon (`timevar()`) CIF matches the correct baseline-CIF mapping `1-(1-basecif)^exp(xb)` to ~6e-8 and is asserted **not** to equal the wrong `basecif^exp(xb)`. No external dependency; never skips. |
| `crossval_finegray.do` | `stcrreg` + `cmprsk::crr` | Coefficients vs `stcrreg` to **< 1e-4** across covariate combinations and both causes; log-likelihood, robust SEs (ratio 0.95–1.05), strata via `cengroup`, high-censoring stress, simulated-DGP direction recovery, and N = 500–50 000 performance benchmarks. Strata parity vs `cmprsk` `cengroup` (C51–C55): coefficients < 1e-6, SEs < 0.1%, relative LL difference < 1e-6, CIF < 1e-5. |
| `crossval_cif.do` | R `riskRegression` | `finegray_cif` point estimates match `riskRegression::predictRisk` (**< 1e-4**); CIF standard errors match a same-dataset subject bootstrap. (Since no R package exposes a Fine-Gray CIF SE, the *deterministic* SE oracle is the jackknife in `validation_finegray_cif_se.do`.) |
| `crossval_predict_phtest.do` | `cmprsk::crr` | Row-level `xb` (**< 0.001**) and CIF (**< 0.01**) vs R. Schoenfeld residuals and the `finegray_phtest` residual-time **correlation** are cross-checked at a **common β** (finegray's coefficients passed to R, isolating the residual algorithm from optimizer-to-optimizer β differences): on tie-free simulated data the residuals are **bit-exact (< 1e-4)** and the correlation agrees with R across rank/log/identity transforms to **< 1e-4**. This is a coding-consistency check, not a test-calibration claim — `cmprsk` ships no PH test, so R recomputes the same correlation; `finegray_phtest` reports no chi2/p-value (FG-03). Hypoxia (heavy ties + a near-zero censoring weight) is checked for functional validity only — its residuals are validated bit-for-bit against `stcrreg` in `crossval_predict_stcrreg.do`. Includes an internal `predict schoenfeld` → manual correlation → `phtest` consistency check and a determinism check. |
| `crossval_finegray_zzf.do` | Independent R implementation of Zhang–Zhang–Fine Weight 1 | Per-dataset coefficient parity on 100 regenerated datasets: pooled arms A/B/D, published same-group stratification C, and genuinely cross-classified censoring/entry groups X. A manifest requires every arm and replication; an independent `coxph` optimizer cross-checks the direct R objective before Stata sees its result. |

#### Tolerance rationale

Tolerances are tiered by how close the reference algorithm is to `finegray`:

- **Same algorithm (`stcrreg`, identical model):** point estimates bit-exact; coefficients < 1e-4, LL < 0.001, SE/CI < 2%.
- **Different implementation, same estimand (`cmprsk`, `riskRegression`):** coefficients < 0.01, xb < 0.001, CIF < 0.01, Schoenfeld < 0.05.
- **PH-test χ² (at a common β, tie-free data):** < 0.5% relative (observed ~1e-6) — once the optimizer-β difference is removed, the correlation-based statistic agrees with `cmprsk` to numerical precision. On tie-heavy / ill-conditioned data (hypoxia) the per-event residual is convention- and truncation-dependent, so χ² is not cross-validated there (functional check only; residuals validated against `stcrreg` instead).
- **Monte-Carlo / finite-sample SEs (CIF subject bootstrap):** ~15% relative band (`crossval_cif.do`), reflecting bootstrap noise at feasible reps; the *deterministic* jackknife oracle (`validation_finegray_cif_se.do`) pins the same SE to ~1–2%.

## Conventions

- **Self-contained & relocatable** — no hardcoded paths; package root is derived from `c(pwd)`, and generated R cross-check CSVs live in the ignored `qa/data/` directory. Nothing under `qa/` is required at runtime by the package.
- **Clean install per suite** — each `.do` `ado uninstall`s then `net install`s `finegray` from the local source, so tests run against the working tree, never a shadowed installed copy.
- **Test isolation** — every test block re-establishes its own data (`webuse hypoxia` or a seeded simulation); no test depends on prior state.
- **Semantic assertions** — checks compare against expected *values* (or tight analytic bounds), not mere existence.
- **Machine-parseable** — each suite ends with a `RESULT: <name> tests=N pass=N fail=N [skip=N]` sentinel. The curated runner requires exactly one evaluated numeric sentinel, rejects failures/skips/smoke settings even when a do-file returns `rc=0`, deletes each prior suite log before execution, and fails the lane on any malformed result. `run_all.sh` applies the same contract at the shell boundary because Stata's batch process status is not authoritative.
- **No tracked artifacts** — generated logs/CSVs/datasets are gitignored.

## What a clean run demonstrates

- `finegray` returns the **correct estimand**: it recovers a log-SHR set by us at large N, where a naive competing-risks-as-censoring Cox model fails.
- It is **numerically identical to StataCorp's `stcrreg`** on coefficients, log- likelihood, predictions, and Schoenfeld residuals — while remaining practical on data sizes where `stcrreg` is slow or infeasible.
- It **agrees with independent R references** (`cmprsk`, `riskRegression`, and the direct Weight-1 oracle) on coefficients, CIF, the proportional-subhazards diagnostic, and delayed-entry estimating-equation results.
- Its post-estimation surface (`finegray_predict`, `finegray_cif`, `finegray_phtest`) is correct, CI-aware, bootstrap-capable, and fully documented-behaviour-locked by version-pinned regression tests.
