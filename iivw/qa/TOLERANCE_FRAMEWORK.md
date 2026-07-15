# `iivw` — Tolerance Framework

**Phase 0 gate artifact.** Written 2026-07-14, **before** the Phase 1–3 implementation runs.

**The rule:** a tolerance is fixed **before** the run that it judges. Widening a tolerance *after* seeing
a failure is how a suite is fitted to its own bug. `iivw`'s own simulation files already admit to this —
their comments say the acceptance tolerances "were set from observed QA-mode runs." That is the practice
this file exists to end.

> **No tolerance in this package may be widened after a failure without (a) a method-level explanation of
> why the original bound was wrong *as a matter of statistics, not of convenience*, and (b) independent
> review.** Record both in the suite, at the assertion.

---

## 1. Tolerance classes

Pick the class from **what the comparison is**, never from what makes the test pass.

### Class E — Exact / replay

Two computations that are **algebraically the same computation** must agree to floating-point noise.

| Comparison | Bound |
|---|---|
| Observed weights vs. bootstrap-replay weights on the **same** data (`test_iivw_replay`) | `reldif < 1e-12` |
| Same weight recomputed after a harmless re-sort | `reldif < 1e-12` |
| `_iivw_weight` vs. `_iivw_iw × _iivw_tw` (FIPTIW identity) | `reldif < 1e-12` |
| Row counts, interval starts/stops, event indicators, sample membership | **exact equality**, no tolerance |

> **Why so tight.** A "small" discrepancy in a quantity that ought to be *identical* is not noise — it is
> a **different code path**. The treesignal LLR incident (two implementations 4 ulps apart, silently
> dropping discrete-null atoms) is the failure mode: `1e-8` would have passed it. If two paths compute
> the same thing, demand `1e-12`; if they cannot meet it, find out why before relaxing it.

### Class A — Analytic invariant

Exact identities from the source papers (`METHOD_ORACLE_MAP.md` §1, oracles #2, #5, #6). These hold in
the **sample**, not just asymptotically — so they get sample-level tolerances, not Monte Carlo ones.

| Invariant | Bound |
|---|---|
| `Z ⊆ X` ⇒ stabilized IIW ≡ 1 (B&L p.8) | `max\|w − 1\| < 1e-8` |
| Saturated-model equivalence: stabilized ≡ unstabilized `θ̂₁` (*What If* §12.3 p.154) | `reldif(θ̂₁) < 1e-8` |
| Mean-one: `mean(_iivw_tw)` (*What If* p.153; Cole & Hernán) | **`\|mean − 1\| < MEANONE_K · SD_subj(w)/√n_subjects`**, `MEANONE_K = 4`. **Self-calibrating — NOT a fixed constant.** See the calibration below. |

> #### ⚠ Mean-one is the one band that must NOT be a fixed number — measured, 2026-07-14
>
> An earlier draft of this file registered `TOL_MEANONE = 0.02` as a fixed absolute band. **That is a
> false-red generator, and it was caught at the Gate-0 review by simulating it against correct code.**
> The mean of the *estimated* stabilized weights is itself an estimate: its sampling error shrinks like
> `1/√n`, so any fixed band is simultaneously too tight at small `n` and too loose at large `n`.
>
> Measured on **correct** `iivw` code (40–60 reps per cell, `wtype(iptw)`, 4 visits/subject):
>
> | n subjects | mean \|dev\| | 95th pct | **false-red rate, fixed 0.02 band** | **false-red rate, `4·SE` band** |
> |---|---|---|---|---|
> | 60 | 0.0188 | 0.0739 | **35%** | **0.0%** |
> | 100 | 0.0131 | 0.0481 | **15%** | **0.0%** |
> | 200 | 0.0107 | 0.0327 | **12%** | **0.0%** |
> | 400 | 0.0059 | 0.0149 | 1.7% | **0.0%** |
> | 800 | 0.0048 | 0.0116 | 0.0% | **0.0%** |
>
> The fixed band fails **more than a third of the time on correct code** at n=60. The self-calibrating
> band holds its size at **0% across every n**, and it retains power: a genuinely broken numerator (e.g.
> dropping `Pr[A=a]` and shipping the *unstabilized* weight) drives the mean to ≈2 while the band stays
> ≈0.1, so it is detected immediately.
>
> `_iivw_tw` is **subject-constant**, so the effective sample size is the number of **subjects**, not
> rows. Compute `SD` and `n` on one row per subject — using row counts inflates `n` by the visits-per-
> subject factor and silently shrinks the band by `√(visits)`.
>
> **The general lesson, and it applies to every band in this file:** a tolerance for a *quantity that is
> itself estimated* must scale with that quantity's standard error. Pick the band by simulating it
> against known-correct code and measuring its false-red rate — never by choosing a round number.

### Class P — Cross-implementation parity

Stata vs. R (IrregLong, `geeglm`). Different optimizers, different convergence criteria, different
tie-handling — so **not** Class E.

| Comparison | Bound |
|---|---|
| Visit-model coefficient `γ̂` vs. IrregLong `coxph` | `reldif < 1e-6` |
| Row-level observed-visit weights vs. IrregLong `iiw.weights` | `reldif < 1e-6` |
| Outcome coefficients vs. R `geeglm` | `reldif < 1e-5` |
| Interval counts / risk-set membership | **exact equality** |

> **Banned:** the current FIPTIW arm's `correlation > 0.75` and `absolute bias < 0.25`. Those are not
> parity tolerances — they are smoke tests wearing a parity label, and they would pass a materially wrong
> weight. Any comparison that cannot meet Class P is **not a parity test** and may not be counted as one.

### Class M — Monte Carlo recovery

Bias must be judged **against its own Monte Carlo standard error**, never against a fixed number someone
liked.

```
MCSE(bias) = SD(estimates) / sqrt(R)
PASS  iff  |mean(θ̂) − θ_true|  <  k · MCSE(bias)        with k = 3
```

- **`k = 3`, fixed.** A 3-MCSE band is ≈99.7% under the CLT; a true-zero bias fails it once in ~370 runs.
- **Every recovery assertion reports its MCSE.** An assertion that prints only "bias = 0.004" is
  uninterpretable — 0.004 against an MCSE of 0.001 is a **defect**; against an MCSE of 0.01 it is noise.
- **Bias must shrink with `n`.** A persistent asymptotic offset shows up as a bias that stays put (or
  grows in MCSE units) as `n` rises, while Monte Carlo noise shrinks like `1/√n`. **Run ≥2 sample sizes
  and ≥3 seeds.** This is the check that distinguishes "finite-sample wobble" from "wrong estimator", and
  it is the one `iivw`'s current recovery suites do not make.
- **`R` is chosen so the MCSE can resolve the effect**, not so the test passes. If `k·MCSE` is wider than
  the bias a defect would produce, the test **cannot detect that defect** and must not be counted as
  covering it.

### Class C — Coverage (the Phase-3 release gate)

**Pre-registered, and not adjustable after results are seen.**

| Criterion | Value |
|---|---|
| Replications per core scenario | **≥ 1,000** |
| Empirical coverage of the nominal 95% CI | the **95% Wilson interval** for the coverage proportion **must contain 0.95** |
| Hard floor | **no point coverage below 0.92** |
| Reported alongside | bias + MCSE(bias), empirical SD, mean model-based SE, coverage + its Wilson interval |

- **The refit (default) method's empirical SE must track the Monte Carlo SD**, and its coverage Wilson
  interval must contain 0.95 with no point below 0.92.
- **Pilot runs may tune `R` and runtime. They may not tune the acceptance boundary.**

> #### ⚠ The separation direction is OVER-coverage, not under-coverage — corrected 2026-07-15
>
> The plan's blocker #1 assumes the fixed-weight default *under*-states uncertainty. **Under a correctly
> specified weight model it does the opposite**, and the 200×300 pilot confirmed it (refit coverage 0.925,
> fixed 0.930; fixed SE ran **+3.0%** above refit; at strong dependence the gap widens). The reason is a
> theorem, not a tuning accident: the Bůžková–Lumley variance (p.10–11, `METHOD_CONTRACT.md` §3.6)
> residualises the outcome score against the visit-model score before squaring, `V = Var(Û − proj)`, and
> the fixed-weight sandwich is the first term `Var(Û)` only. For a Cox-partial-likelihood (MLE) visit
> model that projection is orthogonal, so `Var(Û − proj) ≤ Var(Û)` (Henmi & Eguchi 2004; the IPW analogue
> is Lunceford & Davidian 2004). **Treating estimated weights as known therefore makes the interval too
> WIDE (conservative), and the fixed default over-covers.** There is no correct-specification scenario in
> which it under-covers.
>
> **So the "gate must be able to fail" separator is a TWO-SIDED calibration test, preregistered here
> before the release run:** in the **strong-dependence** scenario (`GAMMA` and `DELTA` both large, so the
> projection correction is a large share of the total variance) the **refit** coverage Wilson interval
> must contain 0.95, while the **fixed** coverage Wilson interval must **exclude 0.95 from above**
> (empirical over-coverage). That is the demonstrable difference between the two methods, and it is honest
> about the direction. If, at the strong-dependence setting the release run uses, the fixed over-coverage
> is too mild for its Wilson interval to clear 0.95, the honest conclusion is that **coverage cannot
> separate the two methods under correct specification** — the demonstrable difference is then the
> systematic fixed-vs-refit **SE ratio > 1**, which the run also reports. Under-coverage of the fixed
> method is expected only under weight-model **misspecification**, which is a separate, still-to-build arm
> and is not part of this correct-specification gate.

---

## 2. What a tolerance may never do

- **Absorb a known defect.** If a bound is loose enough to pass a construction the contract calls wrong,
  it is not a tolerance — it is a cover-up. (Current example: the FIPTIW `correlation > 0.75` arm passes
  with treatment **missing from the visit model**.)
- **Be set from the observed run.** See the header.
- **Hide behind `assert` without a printed value.** Every numeric assertion prints the compared values and
  the bound, so a reader can see the margin. A test that passes by 0.0001 and a test that passes by 10×
  are different facts about the code, and a bare `assert` erases the difference.
- **Apply Class M/C thinking to a Class E comparison.** Two paths computing the same algebra do not get a
  "statistical" tolerance.

---

## 3. Fixed constants (registered here, referenced from suites)

| Name | Value | Applies to |
|---|---|---|
| `TOL_EXACT` | `1e-12` | Class E |
| `TOL_INVARIANT` | `1e-8` | Class A (identities) |
| `MEANONE_K` | `4` | Class A mean-one — used as `k·SD_subj(w)/√n_subjects`, **never as a fixed band** (calibrated 2026-07-14; 0% false-red at n = 60…800) |
| `TOL_PARITY_COEF` | `1e-6` | Class P (nuisance coefficients, weights) |
| `TOL_PARITY_OUTCOME` | `1e-5` | Class P (outcome coefficients) |
| `MCSE_K` | `3` | Class M |
| `COVERAGE_R` | `1000` | Class C |
| `COVERAGE_FLOOR` | `0.92` | Class C |

Suites reference these names. Changing a value here is a **reviewed** change with a method-level reason,
and it changes every suite at once — which is the point.
