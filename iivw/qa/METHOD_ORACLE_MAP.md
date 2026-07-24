# `iivw` — Method → Oracle Map

**Phase 0 gate artifact.** Companion to `METHOD_CONTRACT.md`, which owns the *method*; this file owns
the *proof*. Written 2026-07-14; updated 2026-07-23 against package version 2.3.0.

**The rule this file enforces:** every supported formula must have an oracle that is **independent of the
implementation**. A test that recomputes the package's own formula and compares it to itself proves
nothing. Oracle strength, best first:

| Tier | Oracle | Why it is strong |
|---|---|---|
| **1** | **Hand-computable fixture** — an interval or weight you can verify with a calculator | Cannot share a bug with the code. Cheapest and strongest. |
| **1** | **Analytic invariant from the source paper** | Same: independent of the code, derived by the method's authors. |
| **2** | **Known-truth recovery** — simulate from a DGP whose truth you set | Independent of the estimator, but only asymptotically, and it can hide a bias smaller than Monte Carlo noise. |
| **3** | **Published worked example / independent implementation (R)** | Independent *software*, but may share the same wrong **semantics** — see the warning below. |

> **⚠ A reference implementation can encode the defect too (2026-07-21, SOL-01).** IrregLong's
> `iiw(..., first=TRUE)` sets each subject's first visit weight to a hard-coded 1 while every other row
> keeps its fitted `exp(-xb)`. That mixed-scale construction is **not invariant to the parameterization of
> the visit model**: shifting a Cox covariate by a constant multiplies the fitted weights by a common
> factor and leaves the 1s alone, so the baseline-to-follow-up ratio moves. `iivw` shared that convention
> and the parity tests were exact — two implementations agreeing on the same non-invariant convention.
>
> The oracles were realigned when SOL-01 was fixed, and the realignment is **narrow and auditable**:
>
> - `crossval_fiptiw.R` and `crossval_iivw_external_refs.R` no longer apply the `[first] <- 1` override
>   for the arms whose Stata side runs `baseline(event)`. Under that mode every visit including the first
>   *is* a modelled event with its own fitted weight, so the matching oracle is the unmodified
>   `exp(-xb)`. The override was comparing two different estimands, not detecting a discrepancy.
> - **No formula was changed.** The R side still fits its own `coxph` and computes its own linear
>   predictor; only a post-hoc convention override was removed. `crossval_iivw.do` XV1 (Cox coefficient
>   parity) is untouched and still exact, which is the check that the underlying model did not move.
> - `crossval_iivw.do` XV4c — the `baseline(entry)` arm — still **derives** the expected normalizer from
>   the oracle rather than rescaling both sides, so it retains its teeth. Its formula changed from a
>   pooled mean over `n_first + n_match` rows to a mean over the `n_match` modelled events, and it now
>   additionally asserts the entry rows are **exactly 1** — an assertion the old pooled normalization
>   could not make.
>
> The invariance property itself is proved by `test_iivw_invariance.do`, not by any R oracle: metamorphic
> shift/rescale checks cannot be satisfied by a reference implementation that shares the convention.

> **⚠ Tier-3 is not a free pass.** `iivw`'s FIPTIW parity arms and the R references **both** build
> observed-event-only risk sets and the Stata arms request `endatlastvisit`. Two programs agreeing on the
> **same wrong construction** is not evidence. The same trap applies to the variance: fixed-weight
> Stata/R SE parity proves only that both computed the same *incomplete* variance
> (`METHOD_CONTRACT.md` §3.6).

---

## 1. The oracle map

| # | Supported calculation | Oracle | Tier | Exists today? |
|---|---|---|---|---|
| 1 | IIW unstabilized `exp(−γᵀZ)` | IrregLong `iiw.weights`, **exact** agreement on visit-model coefficient + observed-visit weights | 3 | ✅ `crossval_iivw_irreglong` |
| 2 | **`Z ⊆ X` ⇒ stabilized IIW ≡ 1** | **B&L p.8** analytic invariant: the stabilized weight "equals one for all individuals at all times". Tompkins p.5 concurs | **1** | ✅ `test_iivw_literature_invariants` T1–T2, `test_iivw_phase2_contract` T5. Under FIPTIW the numerator must now match the *full* visit design (`visit_cov()` **+ `treat()`**), which makes the identity a two-sided check on the design as well |
| 3 | Risk set `ξ_i(t)=I(C_i>t)` | IrregLong `addcensoredrows()`, exact row-count + interval match | 3 | ✅ `crossval_iivw_irreglong` (`maxfu(384)`) |
| 3b | Terminal censoring interval | **Hand-computable**: subject with visits at t=1,3 and `maxfu(10)` ⇒ intervals (0,1],(1,3],(3,10] with `_event`=1,1,0 | **1** | ⚠️ partial — assert it directly |
| 4 | Stabilized IPTW `Pr[A=a]/Pr[A=a\|L]` | **Independent implementation** on one-row-per-subject data (base-R `glm`, hand-computed from a saturated `logit`) | 1/3 | ✅ **CLOSED (Gate 2A, 2026-07-15)** — `validation_iivw_iptw_oracle.do` T1 (tier-1 saturated-cell fixture) + T2 (base-R `glm` parity: treatment coefs, propensity, per-arm weights, weighted coef, sample membership) |
| 5 | **Saturated-model equivalence** | ***What If* §12.3 p.154** analytic invariant: stabilized ≡ unstabilized point estimate when the outcome model is `Y ~ A` alone | **1** | ✅ **CLOSED (Gate 2A)** — `validation_iivw_iptw_oracle.do` T3, `reldif < 1e-8` |
| 6 | **Mean-one** | ***What If* §12.3 p.153** + **Cole & Hernán §Correct model specification**: "a necessary condition for correct model specification is that the stabilized weights have a mean of one" | **1** | ✅ **CLOSED (Gate 2A)** — `validation_iivw_iptw_oracle.do` T4, self-calibrating `MEANONE_K·SD/√n` band with a power check that the unstabilized numerator falls outside it |
| 7 | FIPTIW product `e_i/φ_i` | Coulombe **eq. 3.14**; parity on a **full at-risk window** | 3 | ⚠️ **legacy only** — current arms use `endatlastvisit` (see §3) |
| 8 | Treatment in the FIPTIW visit model | Coulombe **eq. 3.12** — assert `treat` appears in the fitted visit-model spec | **1** | ✅ **CLOSED (2.0.0, Phase 2)** — `test_iivw_phase2_contract` T1–T4 asserts the fitted design, the dedup, the contract field, the labelled opt-out, and that the refit bootstrap replays it. `test_iivw_literature_invariants` T2 adds the converse: a numerator that does *not* match the full FIPTIW design must **not** collapse to 1, so the identity cannot pass vacuously if `treat()` is ever dropped again |
| 9 | Outcome GEE (B&L eq. 11) | Stata `glm [pw], vce(cluster id)` ≡ independence GEE; cross-check vs R `geeglm` | 3 | ✅ `crossval_iivw_external` (geeglm arms) |
| 10 | Known-truth recovery | **Coulombe §3.3 DGP, PDF p.87–88 — true effect = 1**, `C_i ~ U(τ/2,τ)` | 2 | ✅ **CLOSED for the point estimate (Gate 2B, 2026-07-15)** — `validation_iivw_fiptiw_recovery.do` on the package-representable Coulombe-based Appendix-A DGP, FULL `C_i` risk window (`censor()`+`baseline(entry)`, never `endatlastvisit`). FIPTIW bias shrinks with n (n=250→500) across 50 seeds; preregistered comparator ordering isolates each mechanism (IIW-only's confounding-blindness in the null-monitoring arm, IPTW-only's monitoring-blindness in the strong arm). The legacy-design recovery arms remain in the sensitivity lane |
| 11 | **Corrected variance / honest absence of one** | Coverage simulation ≥1,000 reps; **and** a fixed-weight arm that demonstrably **fails** a scenario the corrected method passes | 2 | ⚠️ **WEIGHT-TYPE-SPECIFIC RESULT.** IIW 0.939 [0.922,0.952] and IPTW 0.954 [0.939,0.965] meet the preregistered rule at 1000×999. IPTW also supplies the separator: fixed-weight SE/empirical SD 1.31 versus refit 1.02. For FIPTIW at `n=300`, Wald 0.914, percentile 0.924, basic 0.896, bias-corrected 0.914, and corrected BCa 0.895 all failed the same rule. Bare FIPTIW is therefore point-only and posts no `e(V)`; explicit intervals remain nominal and uncleared. Records: `coverage_results/RESULT_2026-07-22.md` and `coverage_results/FIPTIW_INTERVALS_2026-07-23.md` |
| 12 | Balance target (unstabilized) | Hand-computed `∫ξ(t)g(Z(t))dΛ₀(t)` on a 2-subject fixture | **1** | ⚠️ assert directly |
| 13 | Balance target (**stabilized**) | **The saturated-stabilization identity.** Set `stabcov()` = the full visit model. B&L p.8: the stabilized weight is then **identically 1** — it reweights nothing — so every target SMD must be **0 by algebra**, with no Monte Carlo error and no external implementation. Tier-1: hand-checkable and deterministic | **1** | ✅ **CLOSED** — `test_iivw_phase2_contract` T5–T7. Old code reported max \|TSMD\| = **0.3321411** for a weight vector of all ones. T5 establishes the weight really is 1 (so T6 is not vacuous); T7 pins the unstabilized path bit-for-bit unchanged |
| 14 | Holm adjustment (`iivw_exogtest`) | Hand-computed p-value vectors incl. ties, skipped groups, 1-vs-many groups | **1** | ⚠️ verify coverage |

**Score (updated 2026-07-23): of 14 supported calculations, the point-estimator surface is covered** —
#1, #2, #3, #4, #5, #6, #8, #9, #10, #13 have adequate oracles; #7/#12/#14 remain tier-1 asserts to
grow. **Oracle #11 has been executed and resolved honestly rather than uniformly:** IIW/IPTW retain
their qualified refit-bootstrap clearance, while five FIPTIW intervals failed. The FIPTIW point
estimator is unaffected; the default now returns coefficients only and refuses to manufacture a
generally valid 95% claim. The `-at-studied-settings` qualifier remains mandatory for IIW/IPTW.

---

## 2. The three mandatory false-green mutations

**Pre-registered before implementation** (plan Phase 0 `$qa` item 4). Each must make **at least one
independent gate fail**. A mutation that everything survives means the suite is not testing the thing.

| # | Mutation | Must break |
|---|---|---|
| **M1** | **Omit the terminal censoring interval** (or flip the IIW exponent sign: `exp(+xb)`) | `crossval_iivw_irreglong` exact weight parity; the hand-computed interval fixture (#3b); the recovery gate |
| **M2** | **Hold weights fixed inside the bootstrap** (or fail to reconstruct lag sources within a draw) | `test_iivw_replay` exact observed-vs-replay weights; the Phase-3 coverage gate (fixed-weight must undercover) |
| **M3** | **Omit treatment from the FIPTIW visit model** (or allow an outcome-invalid stabilizer) | The Coulombe eq.-3.12 spec assertion (#8); the stabilization-validity error path (#2/#5) |

M3 is closed by the Phase-2 design and validation checks. M2 is also closed: the identity-draw oracle
pins nuisance replay, the 1000×999 experiment distinguishes fixed from refit inference in IPTW, and
the FIPTIW follow-up shows that neither route supplies a calibrated interval in its base cell.

### M2 status after Phase 1 — half closed, and only half

**The lag half of M2 is now closed, with a tier-1 oracle.** `test_iivw_replay.do` introduces the
**identity draw**: hand the bootstrap replay a resample in which every subject is drawn exactly once,
so the draw *is* the observed panel, and require the recomputed weights to equal the observed weights
to `1e-12` (Class E). This is hand-checkable, deterministic, needs no external software, and has no
Monte Carlo error for a defect to hide behind.

It discriminates, measurably: against the pre-release build the identity draw is off by
**max reldif 2.24e-01**. It is now **0.00e+00**.

**What the identity draw does NOT prove.** It runs the same `iivw_weight` on both sides, so it can only
catch a defect in *what the replay hands to the weighting* — which is exactly where the defect
was (`visit_cov()` receiving precomputed `*_lag1` columns instead of `lagvars()` receiving the raw
sources). A defect *inside* `iivw_weight` itself would cancel on both sides and pass. That is what the
IrregLong parity arm (#1) is for, and the two are not substitutes.

**The coverage half of M2 is closed.** The release experiment ran with 1,000 outer datasets and 999
draws per family. IPTW provides the prespecified fixed-versus-refit discriminator. The FIPTIW
follow-up compared Wald, percentile, basic, bias-corrected, and corrected full-refit BCa and found no
winner, which is why its default is point-only. M3 remains closed by
`test_iivw_phase2_contract` and `test_iivw_literature_invariants`.

---

## 3. Suite disposition

Every existing suite, marked **retain** / **rewrite** / **legacy-only** / **remove false oracle**.

### 🔴 Remove false oracle

| Suite | Why |
|---|---|
| `validation_iivw_recovery_extended.do` **scenario S2** | **Encodes an assumption violation as success.** Its own comment (lines 136–140) says it stabilizes by a baseline `S` that is "**NOT in the outcome**" model — the exact violation of B&L's `h(X)` rule (`METHOD_CONTRACT.md` §2) — then asserts recovery (`abs(s2_est-0.5) < 0.03`) as validation. It passes only because `S` was drawn independent of `Z` and of the outcome; correlate `S` with either and it biases. **Do not loosen the tolerance — the tolerance is not the problem, the claim is.** **Rewrite as a negative-path test:** once Phase 2 enforces the numerator rule, `stabcov(S)` with `S` outside the outcome design must **error**, and S2 asserts that error. |

### 🟡 Legacy-only — move to a named legacy/sensitivity lane, do not count as estimator validation

| Suite / arm | Why |
|---|---|
| `crossval_fiptiw.R` + its Stata arm | Builds **observed-event-only** risk sets and the Stata arm requests `endatlastvisit`. This is **legacy parity**, not the recommended full-risk-set FIPTIW estimator. Its tolerances are smoke-test grade: **one comparison requires only correlation > 0.75**, one treatment-effect check allows **absolute bias < 0.25**. |
| `crossval_iivw_external.do` — Dietox FIPTIW arm | Same shared legacy construction. |
| Most of `validation_iivw_recovery_extended.do` / `_extended2.do` | Explicitly request `endatlastvisit baseline(event)` — **1.x semantics**, not the 2.0.0 contract. |
| `sim_scenario_d.do`, `sim_scenario_e.do`, `sim_scenarios_abc.do` | Their interval calls now request `vce(fixed)` explicitly, but QA mode is **50 reps** and comments say tolerances were **set from observed QA-mode runs** (fitting the gate to the result). They retain legacy `endatlastvisit baseline(event)` designs. **Useful DGP scaffolds — but their coverage columns cannot clear the variance method.** |

### 🟡 Rewrite (documented non-recovery counted as green)

Suites that "pass" while accepting a persistent level offset, partial correction from weighted mixed,
truncation attenuation, or a broad failure envelope. These are **honest sensitivity findings**, but
counting them as green estimator-validation modules **inflates the apparent correctness evidence**. Move
to a named limitation/sensitivity lane. The **core recovery lane must contain only estimands that recover
under the stated assumptions.**

- `validation_iivw_recovery_extended.do` (S1 "bounded level recovery" — an accepted offset)
- `validation_iivw_recovery_extended2.do`
- the weighted-`mixed` arms wherever they appear

### 🟢 Retain

- `crossval_iivw_irreglong` (+ `crossval_irreglong.R`) — **the model of what a good oracle looks like.** `maxfu(384)`, rebuilt lags after censoring rows, exact agreement required. Keep and extend.
- `test_iivw_v200_*` — they assert the 2.0.0 repairs (risk set, baseline default, nonconvergence, name collisions). **These encode fixed bugs; they must keep failing on old code.**
- `test_iivw_literature_invariants.do` — the right idea; **extend it with oracles #2, #5, #6** above.
- `test_iivw_weight_validation_guards.do`, `test_iivw_*_adversarial.do`, `test_iivw_psdash_contract.do`, `test_iivw_reporting_exports.do` — functional/negative-path coverage, keep.
- `validation_iivw_known_answers.do`, `validation_iivw_diagnostics_known_answers.do` — tier-1 shaped; keep and grow.

### ⚪ Housekeeping

- `qa/README.md` **omits** `test_iivw_literature_invariants.do` and `test_iivw_v200_qagate.do`. Reconcile.
- Six standalone suites have no detected targeted uninstall; each must be checked against the shared bootstrap rather than waived by filename.

---

## 4. Naming

New work goes in **concern-named** files, not `test_iivw_v###_*.do`. Version-numbered files record *when*
a bug was fixed; concern-named files record *what must stay true*. Target layout is in the finalization
plan, Phase 5. The `v###` files are **retained** — they are the old-code regressions — but no **new**
assertion may be added to one.
