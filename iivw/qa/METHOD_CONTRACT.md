# `iivw` — Method Contract

**Status:** Phase 0 gate artifact. **Not a release approval.**
**Written:** 2026-07-14 · **Updated:** 2026-07-23 · **Package version inspected:** 2.2.0
**Governing plan:** the `iivw` finalization plan, held in the development repository.

This file is the single place where every supported calculation is mapped to **the source that grounds
it**, **the equation in that source**, **the code path that implements it**, and **the QA oracle that
proves it**. A calculation that cannot fill all four columns is not reliability-cleared, and this file
says so out loud rather than leaving the gap for a reader to discover.

Every source cited here was **fetched and read**; each row points at a page, section, or equation. The
literature corpus and its provenance index are held in the development repository. Nothing in this file is
written from recall.

---

## 0. Reliability status in one line

**`iivw` 2.2.0 computes externally checked point estimates and defaults to a refit bootstrap that
propagates weight-estimation uncertainty. Its interval coverage has now been measured, and the answer
depends on the weight type:** IIW 0.939 and IPTW 0.954 meet the preregistered rule
(`cleared-at-studied-settings`); **FIPTIW covers 0.914 and does not** — its interval runs about 14% too
narrow, while its point estimator is unaffected (`undercovers-at-studied-settings`). Coverage is
established at one correctly specified cell per family at one sample size, so the status never degrades
to a bare `cleared`. Record: `coverage_results/RESULT_2026-07-22.md`.

---

## 1. The trust boundary

The first reliable release will support and claim **only** the following. Anything outside this list must
error, or be conspicuously quarantined as experimental/legacy — it must never return an ordinary-looking
estimate under a general reliability claim.

| Supported | Not supported (must error or be quarantined) |
|---|---|
| Marginal Gaussian / binomial / Poisson outcome means via the independence-GEE estimating equation | Time-varying treatment |
| IIW for irregular observation under a documented at-risk window (`censor()` or `maxfu()`) | Informative dropout without a separate IPCW model |
| Baseline = study entry by default; `baseline(event)` only under a validated design | Multilevel weighted random-effects variance components (`model(mixed)`) |
| Baseline, **binary, subject-constant** treatment for IPTW / FIPTIW | ATT, ATC, multi-arm, or continuous treatment |
| Subject-level analysis and **subject-level** bootstrap | Higher-level cluster resampling |
| Visit-model covariates observed **before** the visit they predict, incl. correctly reconstructed `lagvars()` | Concurrent (same-visit) outcome-related covariates in `visit_cov()` |
| Stabilization **only** when its numerator is a function of the actual outcome-model design | Causal interpretation of `iivw_diagnose`'s package-original shares |
| Inference that **propagates weight-estimation uncertainty** | Fixed-weight SEs presented as the package's valid IIW/FIPTIW SE |

---

## 2. The two numerator rules — do not conflate them

This is the correction Phase 0 forced, and it changes the plan. `iivw` has **two** weight numerators, and
they obey **two different rules from two different sources**. The finalization plan (blocker #4) treats
them as one problem. They are not.

| Numerator | The rule | Source | `iivw` status |
|---|---|---|---|
| **IPTW** `g[A]` | must be **a function of `A` only, never of `L`** | *What If*, **Technical Point 12.2, p.155**: "`g[A]` is any function of `A` that is not a function of `L`" | ✅ **Correct by construction.** `iivw` uses the marginal `Pr[A=1]` (`iivw_weight.ado:1076-1080`), computed subject-level on the logit's own `e(sample)`. A function of `A` alone. **Needs no outcome-design check.** |
| **IIW** `h(X)` | must be **a deterministic function of the outcome-model covariates `X(t)`** | **B&L p.7** (immediately after eq. 6) and **p.10** (the unbiasedness proof conditions on `X`); restated by **Tompkins p.5** and **p.20**; the IPTW-side statement is **Cole & Hernán, Appendix 1**: numerator covariates "must be included" in the weighted model | ✅ **Enforced (2.0.0, Phase 2).** `iivw_fit` maps every `stabcov()` variable onto the expanded outcome design — independent variables, `categorical()` and `interaction()` sources, and the panel time variable behind the fitted time terms — and **errors before estimating** if the numerator is not a function of it, naming the offending variables. `e(iivw_stabilization_validated)` / `e(iivw_stab_terms)`. The check is deliberately conservative: a numerator that is some *other* deterministic function of a design covariate is defensible in theory, but the package cannot prove that from the data, and a guard that accepts what it cannot verify is not a guard. Was defect **IIVW-B04**. |

**Consequence:** the Phase-2 "enforce valid stabilization" work applies to `stabcov()` / the IIW numerator
**only**. The IPTW numerator is already right, and a "fix" there would be a regression. This also closes
the old clarity finding C7 ("prevalence computed on the wrong sample") — it is computed on the right
sample, and `iivw_weight.ado:1069-1078` carries a correct comment explaining why.

---

## 3. The calculation map

Legend — **Cleared**: source + code + independent oracle all agree, and the oracle has run.
**Grounded, unproven**: formula matches the source, but no independent oracle proves the implementation.
**Defect**: code and source disagree. **Unsourced**: no source grounds it.

### 3.1 IIW — inverse-intensity weight (Bůžková & Lumley)

| Item | Value |
|---|---|
| **Source** | Bůžková P, Lumley T. *Canadian Journal of Statistics* 2007;35(4):485–500. Local copy = the UW Biostat WP #262 preprint; **page numbers below are the preprint's.** |
| **Estimand** | Marginal GLM `g(µ_i(t)) = β₀ᵀX_i(t)`, eq. (1) p.5 — the expectation does **not** condition on the observation times (p.7). |
| **Visit model** | Marginal **proportional rate** model `E[dN*_i(t)\|Z_i(t)] = exp{γ₀ᵀZ_i(t)}dΛ₀(t)`, eq. (2) p.6. `Z` and `X` may be arbitrary and different — that is the paper's whole point vs. D. Lin & Ying (2001). |
| **Weight (unstabilized)** | `w_i(t) = exp{−γᵀZ_i(t)}` — the inverse of `ρ` in eq. (6), p.7. Baseline `Λ₀` **cancels** (rate *ratio*), which is why `predict, xb` after `stcox` suffices and no baseline is ever estimated. |
| **Weight (stabilized)** | `w_i(t) = exp{δ̂ᵀX_i(t) − γ̂ᵀZ_i(t)}`, with `δ` from a **second** proportional-rate model on the **outcome-model covariates** (p.8). |
| **Code** | `iivw_weight.ado:856-876`. Unstabilized `gen double iw = exp(-xb_full)` (:876); stabilized `gen double iw = exp(xb_stab - xb_full)` (:873) after a second `stcox stabcov` (:867). |
| **Status** | ✅ **Cleared** for the formula. Matches IrregLong's `iiw.weights` exactly (`reference-software.notes.md`, source read 2026-07-13), and `crossval_iivw_irreglong` requires **exact** agreement on the visit-model coefficient and observed-visit weights. ✅ The **stabilized** branch is now *enforced* at `iivw_fit` (§2), and the `Z ⊆ X ⇒ w ≡ 1` identity of B&L p.8 is asserted directly (`test_iivw_literature_invariants` T1–T2, `test_iivw_phase2_contract` T5). |

### 3.2 The risk set — the load-bearing line, and 2.0.0's biggest repair

| Item | Value |
|---|---|
| **Source** | **B&L p.7 and eq. (8) p.8: `ξ_i(t) = I(C_i > t)`**, where `C_i` is drop-out or end of follow-up τ, whichever is first. It is **not** an indicator of having a future visit. In B&L's own HUD-VASH analysis they set `C_i = τ = 48 months` for all 460 subjects (p.13) precisely so nobody leaves the risk set early. Corroborated: Tompkins p.5 (`I(C_i ≥ t)`); Coulombe's DGP censors at `C_i ~ U(τ/2, τ)` (§3.3), strictly before the horizon and *not* at the last visit. |
| **Why it matters** | If follow-up ends at each subject's **last visit**, risk-set membership becomes a function of the very process being modelled. Measured attenuation of `γ̂` was **≈26%**. |
| **Code** | `iivw_weight.ado:777-800`. Appends an `_event = 0` censoring row over `(last visit, C]` — copying the last visit row so every covariate carries forward — exactly what IrregLong's `addcensoredrows()` builds before it ever calls `coxph`. Gated by `censor()` / `maxfu()`; `endatlastvisit` restores the old (wrong) behaviour. |
| **Status** | ✅ **Cleared.** This is defect **IIVW-B01**, fixed in 2.0.0 and verified against IrregLong with `maxfu(384)`. **Preserve this behaviour through every later phase.** |
| **Contract** | `censor()`/`maxfu()` is **required** for a reliability-cleared IIW/FIPTIW result. `endatlastvisit` is a **legacy sensitivity mode**: it must not appear in a primary worked example or in the primary recovery gate. |

### 3.3 IPTW — stabilized, binary, point treatment

| Item | Value |
|---|---|
| **Source** | **Hernán & Robins, *Causal Inference: What If*, §12.3, p.153** (free pre-publication draft, 2019-11-10, now in the corpus). *Not* Coulombe and *not* Tompkins — **both write the treatment weight unstabilized** (Coulombe eq. 3.13). Robins/Hernán/Brumback (2000) remains unread and is **no longer load-bearing**. |
| **Estimand** | **ATE.** §12.3 p.154: the causal difference `E[Y^{a=1}] − E[Y^{a=0}]`, fitted as a weighted `E[Y\|A] = θ₀ + θ₁A`. **Technical Point 12.2 (p.155) proves** the IP-weighted mean equals the counterfactual mean `E[Y^a]`. |
| **Weight** | `SW^A = f(A)/f(A\|L)`; per arm (p.153, verbatim): "`Pr[A=1]/f(A\|L)` for the treated and `Pr[A=0]/f(A\|L)` for the untreated". |
| **Code** | `iivw_weight.ado:1155-1158` — `tw = p_treat/ps` if `treat==1`; `tw = (1-p_treat)/(1-ps)` if `treat==0`. `ps` from `logit treat treat_cov` on one row per subject (`:1066`); `p_treat` = subject-level marginal prevalence on that logit's own `e(sample)` (`:1080`). |
| **Status** | ✅ **Grounded and correct** — exact match to the source, including the numerator rule (§2). Estimand grounded and **proved** in-source. ⚠️ **Not yet independently oracled**: no crossval verifies stabilized ATE IPTW against an independent implementation on one-row-per-subject data (Phase 2 owes this). |
| **Boundary** | The **ATT** needs a *different* numerator (`p = Pr[A=1\|L]`, *What If* Technical Point 4.1, flagged in the p.153 margin). `iivw` does not implement it. **Do not broaden to ATT/ATC/multi-arm/time-varying** — this source does not cover them. |

### 3.4 FIPTIW — the product weight

| Item | Value |
|---|---|
| **Source** | **Coulombe J, Moodie EEM, Platt RW. *Biometrics* 2021;77(1):162–174** — the **origin of FIPTIW** (the authors call it FIPTM). Cited **nowhere** in the package before the 2026-07-13 backfill; Tompkins, whom the package credited, attributes it to Coulombe at their p.2 and p.6 (defect **IIVW-B03**). Local copy = the accepted manuscript as Ch.3 of Coulombe's McGill thesis; **cite the chapter's eq. numbers and PDF pages, never the journal pages.** |
| **Weight** | Product of the inverse monitoring intensity and the IPTW: `e_i(t;ω)/φ_i(t;γ_V)`, eq. (3.14) PDF p.85–86. Tompkins eq. (5) p.6 restates it as the plain product IPTW × IIW. |
| **Code** | `iivw_weight.ado:1172` — `gen double weight = iw * tw`. ✅ matches. |
| **⚠ Treatment MUST be in the visit-intensity model** | **Coulombe eq. (3.12), PDF p.85: `φ_i(t;γ_V) = exp(γ₁ᵀZ_i(t) + γ₂ I_i(t))`** — the treatment `I_i(t)` is *inside* the monitoring-intensity model. |
| **Status** | ❌ **DEFECT (plan blocker #5).** `iivw_weight` builds the denominator from `visit_cov()` + generated lags and **never adds `treat()`**. Several shipped examples and recovery scenarios omit treatment from `visit_cov()`, so **they cannot detect this.** Phase 2 must add it by construction. |
| **Also undocumented** | Coulombe's spline intercept default is **2 knots at the tertiles of `t`** (p.85) — `iivw_fit`'s `timespec(ns(#))` does not mention this default. |

### 3.5 Outcome estimating equation

| Item | Value |
|---|---|
| **Source** | **B&L eq. (11), p.9.** Under a canonical link it collapses to `Σ_i ∫ W(t) X_i(t)[Y_i(t) − µ_i(t;β)](1/ρ_i)dN_i(t)` — an **independence-working-correlation GEE weighted by `1/ρ`**. |
| **Code** | `iivw_fit` → `glm ... [pw=w], vce(cluster id)`, which is algebraically the independence GEE with robust SEs (the code says so at `iivw_fit.ado:942-944`). ✅ matches. |
| **Note** | B&L's optional time-weighting `W(t)` (p.9) is absent from `iivw`; `W(t) ≡ 1` is a **permitted special case, not a defect**. |
| **Status** | ✅ **Grounded** for the point estimate. The **variance** is a different story — see §3.6. |

### 3.6 Variance — the release blocker

| Item | Value |
|---|---|
| **What the code does** | **Since 2.0.0 the WEIGHTED default is the 999-draw refit subject bootstrap** (Phase 3B); `vce(fixed)` is the explicit weights-known cluster-robust sandwich (`vce(cluster id)`). A fixed-weight bootstrap (`vce(bootstrap, … fixedweights)`) also holds the weights fixed. Unweighted fits keep the cluster sandwich (no nuisance weights to propagate). |
| **What B&L do** | **p.10–11.** The asymptotic variance `D⁻¹VD⁻¹` residualises the outcome score against the **visit-model score** before squaring: `V̂ = (1/n)Σ_i[Û_i − ĤÂ⁻¹∫(Z_i(t) − Z̄(t;γ̂))dM̂_i(t)]^⊗2`. In the authors' own words (p.11): **"We account for estimation of γ₀ by including the second term on right-hand side."** A plain fixed-weight sandwich is the **first term only** — it drops the `ĤÂ⁻¹(...)` correction entirely. |
| **What Coulombe does** | **PDF p.86, verbatim:** the asymptotic variance is computed "with the components of variance due to the weights **incorporated into the sandwich estimator using theory on two-step estimators (Newey and McFadden [1994])**." |
| **Status** | ⚠️ **IIVW-B02 coverage gate RUN 2026-07-22; split result.** IIW 0.939 and IPTW 0.954 met the preregistered rule; **FIPTIW 0.914 did not** (0.92 floor). The IPTW arm also supplies B02's own separator: the fixed-weight SE runs 1.31x the empirical SD against the refit bootstrap's 1.02x, the over-coverage direction the framework predicted from the B&L projection. The open item is no longer "no coverage evidence" but the FIPTIW interval specifically, where three independent variance estimators agree with each other and all fall ~14% short of the empirical SD. |
| **Documentation** | ✅ The shipped help states that the fixed-weight sandwich omits the nuisance-estimation correction and that the direction is not universal; under the registered correctly specified weight model it is conservative (over-wide). `iivw_fit.sthlp` now carries an *Inference status and coverage evidence* section giving the measured numbers per weight type, and a weighted FIPTIW fit prints its coverage shortfall at the point of use. |
| **Consequence** | Fixed-weight R/Stata SE parity proves only that **both programs computed the same incomplete variance.** It is not evidence of valid inference. |
| **Contract** | The **subject bootstrap that refits all nuisance models** is the default inferential path under `vce()`. Fixed-weight survives only behind `vce(fixed)` or `fixedweights`; the refit path remains `candidate` until the release coverage gate passes. |

### 3.7 Balance target (`iivw_balance`)

| Item | Value |
|---|---|
| **The identity being checked** | `E[Σ_visits w_ij g(Z_ij)] = E[∫ ξ_i(t) g(Z_i(t)) dΛ₀(t)]` — the IIW-weighted visit mean equals the mean over **at-risk person-time, in `dΛ₀` units**. `iivw_balance.ado:383-393` states this correctly and it is the right null for the **unstabilized** weight `w = exp(−γᵀZ)`. |
| **Code — observed side** | ✅ Correct. `iivw_balance.ado:575-588` forms `exp(xb_stab − xb_full)` when `stabcov()` is present, `exp(-xb_full)` otherwise. |
| **Code — target side** | ❌ **DEFECT (plan blocker #7).** The at-risk target is weighted by **`dΛ₀` alone** (`:604-615`, `predict, basechazard`), with **no `h(X)` factor**. |
| **Why that is wrong** | With a stabilized weight `w = h(X)exp(−γᵀZ)`, the identity becomes `E[Σ w g] = E[∫ ξ h(X) g dΛ₀]`. The target must be weighted by **`h(X)dΛ₀`**. The present formula is correct **only** when the numerator is constant (or happens to cancel for the tested moment). |
| **Status** | ❌ Defect. The observed weight is stabilized; the target it is compared against is not. Phase 4 fixes the target to `h(X)dΛ₀` for both target means **and** target variances. |
| **Credit where due** | The command already **refuses to issue a verdict** when the nuisance model did not converge (`:739-749`), with an excellent comment: *"'good' here would be the most dangerous output the command can produce."* That instinct is right and must be extended to the stabilized case until the target is fixed. |

### 3.8 Truncation (`truncate()`)

| Item | Value |
|---|---|
| **Sources** | **Tompkins §4.4, p.12–13:** the 95th-percentile trimming recommendation, and the finding that trimming helps **only for IPTW-side extremes** — it did **not** repair visit-model misspecification. **Cole & Hernán, §Weight truncation:** truncation is a **bias–variance tradeoff**, explored by *progressively* truncating; "one can see the **growing bias** as the weights are progressively truncated." |
| **Code** | `iivw_weight.ado:1205-1219` — `_pctile` on the **final product**, then clips it. |
| **Status** | ❌ **DEFECT (plan blocker #8).** A generic final-product clip is applied **after** both components are formed, so it (a) cannot report *which* component moved, (b) has no unambiguous statistical target, and (c) leaves `iivw_balance` describing the **untruncated** IIW rather than the analysis weight. |
| **Contract** | **The default supported analysis is untruncated IIW.** Truncation becomes component-specific (treatment / visit / final), is reported over a progression, always carries the bias warning, and is **never** described as a remedy for misspecification. |

### 3.9 `iivw_exogtest`

| Item | Value |
|---|---|
| **Source** | **B&L assumption (4), eq. (4) p.6:** `E[dN*_i(t)\|Z_i(t),X_i(t),Y_i(t),C_i ≥ t] = E[dN*_i(t)\|Z_i(t)]` — visit timing depends on `Y`, `X`, `C` only through `Z`. |
| **Status** | ✅ The command's target **is** eq. (4). Keep it explicitly as a **falsification diagnostic**. |
| **Hard rule** | Failure to reject is **not** proof of exogeneity. No output string may imply it is. |

### 3.10 Unsourced surfaces — quarantine

| Surface | Problem |
|---|---|
| **`iivw_diagnose`** | Its sampling/artifact **shares are original to this package**. No source. "Share", "point decomposition", and "bounds" are causal language with nothing behind them. A user-supplied `exogeneity(exogenous)` label flips a "diagnostic range" into a "point decomposition" — **a label is not evidence that exogeneity holds.** Quarantine (Phase 4). |
| **Weighted `model(mixed)`** | Not a valid weighted random-effects estimator. `experimentalmixed` is an honest warning, but a public path that prints ordinary variance components is easy to overread. **Cannot be in the cleared surface.** |
| **ESS thresholds (`iivw_balance`)** | `ESS = (Σw)²/Σw²` is attributed to **Kish (1965)** — a book we do **not hold** (corroborated across secondary sources; never read). The **thresholds** built on it are package conventions with **no source**, and the help now says so. |
| **The 0.10 balance threshold** | A **convention**, not proof of correct visit-model specification. |

---

## 3.11 Option classification — all 109 public options

Gate 0 requires that **every** public option be inside the supported contract, explicitly legacy, or
explicitly experimental. Classifying only the headline options is not enough: the gaps are where the
damage hides. `S` = supported · `L` = legacy · `X` = experimental/quarantined · `D` = defective (open) ·
`C` = cosmetic (no statistical content).

**`iivw_weight` (19)**

| Option | | Note |
|---|---|---|
| `id` `time` `visit_cov` `treat` `treat_cov` `wtype` `entry` `baseline` `lagvars` | **S** | Core contract. `baseline(event)` is **S-restricted**: valid only under a design where the first visit is genuinely part of the monitored process. |
| `censor` `maxfu` | **S** | **Required** for a cleared IIW/FIPTIW result (§3.2). |
| `endatlastvisit` | **L** | Reproduces defect IIVW-B01. Never in a primary example or the primary recovery gate. |
| `stabcov` | **A** | Validated against the expanded outcome design at `iivw_fit`; the fit errors before estimating if the numerator is not a function of it (§2, IIVW-B04 fixed). |
| `trunctreat` | **B** | Treatment-component trim. A labelled sensitivity analysis: it shifts the target toward the overlap population (Tompkins §4.4). |
| `truncvisit` | **B** | Visit-component trim. Explicitly **not** a remedy for a misspecified visit model (Tompkins §4.4); balance is expected to worsen. |
| `truncfinal` | **B** | Final-product trim. Cannot attribute an extreme weight to a component; the old `truncate()` behaviour, named honestly. |
| `experimentalnotreatvisit` | **D** | Omits `treat()` from the FIPTIW visit model. Outside the supported contract; recorded as such (§2, IIVW-B05). |
| **`efron`** | **S** | **Tie method — statistically load-bearing, and previously unclassified.** Must be part of the replay contract: a bootstrap draw that changes the tie handling is bootstrapping a different estimator. |
| **`allownonconverged`** | **X** | **Previously unclassified.** Lets a nuisance model that does **not solve its estimating equation** through. `exp(−γ̂ᵀZ)` is then not the IIW weight and no downstream null holds. `iivw_balance` already refuses a verdict in this state (`:739-749`) — **correct, and that refusal must extend to every consumer.** Cannot be part of a cleared result. |
| `generate` `replace` `log` | **C** | Naming/verbosity. (`replace` has an *ownership* defect — plan blocker #10 — but no statistical content.) |

**`iivw_fit` (22)**

| Option | | Note |
|---|---|---|
| `model(gee)` `family` `link` `id` `time` `level` | **S** | Core (§3.5). |
| `cluster` | **S-restricted** | Subject level only. A higher-level cluster design needs its own resampling/nuisance theory and must error until validated. |
| `bootstrap` `refitweights` | **D** | The only corrective inferential path, and it is defective (`lagvars()` replay, state corruption). §3.6. |
| `categorical` `basecat` `interaction` `timebasecat` | **S** | Outcome-design construction. **Load-bearing for §2:** the stabilization check must map `stabcov()` against the design *after* these expand. |
| **`timespec`** | **S** | **Previously unclassified.** This is Coulombe's spline intercept `α(t)`. His default is **2 knots at the tertiles of `t`** (PDF p.85) — `iivw` does not document that default. |
| `unweighted` | **S** | The naive comparator. Essential to the recovery grid — it is the estimator that must *miss* when the DGP bites. |
| `allownonconverged` | **X** | As above. |
| `experimentalmixed` `mixedopts` | **X** | Not a valid weighted random-effects estimator (§3.10). **`mixedopts` shares the same variance-ownership contract as `geeopts` below** — it is validated by the same token-aware guard. |
| **`geeopts` `mixedopts`** | **X** | **Pass-through option surface, GUARDED since 2.0.0 (IIVW-B08).** Both are appended raw to the inner `glm`/`mixed` after the package's own VCE, so a variance/resampling token in them is inside the blast radius. A shared **token-aware validator** (`_iivw_check_passthru.ado`) now rejects `vce()`, every abbreviation of `robust` (`r`…`robust`), and `cluster()` (`cl(`…`cluster(`) — across case, tabs, spaces, quotes, and nested parens — before any GEE/mixed call site, including the bootstrap helpers `_iivw_bs_estimate`/`_iivw_bs_refit`. A **post-fit variance lock** (`e(iivw_vce_locked)`) then re-reads `e(vce)`/`e(clustvar)` and confirms the posted covariance matches the package-selected method, erroring otherwise. Note the earlier "silent override" framing was imprecise: local probes show `geeopts(vce(robust))` in fact *errors* `r(198)` at `glm` (duplicate `vce()`); the real hazard was an uncontrolled inference-option surface, especially in bootstrap helpers whose inner `glm` carried no package VCE. Both halves — pre-call reject and post-fit lock — now close it. |
| `log` `replace` `collect` | **C** | |

**`iivw_balance` (21)** — `component` **S** · `agrefit` **S** · `balcut` `cvcut` `essratiocut` **X** (thresholds are package conventions with **no source**; the 0.10 cut is a convention, not proof) · `level` `log` `efron` **S** · the 13 `xlsx`/styling options **C**.
The **stabilized target is now A** (§3.7, IIVW-B06 fixed): the at-risk reference is weighted by `h(X)dΛ₀`, so both sides of the comparison describe the same population.

**`iivw_exogtest` (26)** — `id` `time` `adjust` `by` `bystart` `entry` `censor` `maxfu` `generate` `efron` `level` **S** (falsification diagnostic, §3.9) · `endatlastvisit` **L** · `log` `replace` + the 13 styling options **C**.
**Hard rule:** failure to reject is not proof of exogeneity, whatever the option combination.

**`iivw_diagnose` (21)** — **the whole command is X** (§3.10; package-original shares, no source).
Two options need naming because they are the sharp edges:
| Option | | Note |
|---|---|---|
| **`exogeneity`** | **X** | A user-supplied *label* flips a "diagnostic range" into a "point decomposition". **A label is not evidence that exogeneity holds.** |
| **`force`** | **X** | **Previously unclassified.** Bypasses the comparability gate (`iivw_diagnose.ado:185,203`) — it lets **incomparable** estimates through. Under a quarantined, unsourced command this is the most overreadable switch in the package. |

`unweighted` `weighted` `adjusted` `estimand` `true` **X** · `level` `log` + styling **C**.

> **Net:** of the 109 options, ~60 are cosmetic export/styling and carry no statistical content. Of the
> remainder, this pass found **five statistically load-bearing options that no prior artifact
> classified**: `efron`, `allownonconverged` (×2), `timespec`, `geeopts`, and `force`. **`geeopts` is the
> serious one** — it can silently change the variance estimator, which is the exact quantity the release
> blocker is about.

---

## 4. Phase-0 decisions (no "typical", no "usually")

1. **Supported estimand:** stabilized **binary baseline-treatment ATE only**. Grounded in *What If* §12.3 + Technical Point 12.2. ATT/ATC/multi-arm/time-varying are **out** and must error — no source in the corpus covers them.
2. **Supported visit model:** Andersen–Gill with **baseline entry** and **observed follow-up end** (`censor()`/`maxfu()` required). `endatlastvisit` = legacy sensitivity only. `baseline(event)` = design-specific, requires an explicit validated design in which the first observed visit is genuinely part of the monitored visit process.
3. **Supported outcome estimator:** independence GEE (B&L eq. 11).
4. **Supported inference:** **subject bootstrap with nuisance-model refitting.** This is the default for the first reliable release. Fixed-weight is opt-in only.
5. **Treatment is automatically included in the FIPTIW visit denominator** (Coulombe eq. 3.12). An opt-out, if retained, is experimental and cannot carry a cleared FIPTIW label.
6. **Stabilization must be validated against the fitted outcome design** — the **IIW numerator only** (§2). The IPTW numerator is already correct and must not be "fixed".
7. **Truncation is component-specific**, off by default, and reported as a sensitivity analysis with its bias acknowledged.
8. **`iivw_diagnose` and weighted `model(mixed)` are experimental/descriptive**, not reliability-cleared.

---

## 5. Free, exact oracles this contract hands to QA

Four checks that need **no external software**, are **hand-verifiable**, are **sourced**, and are **not in
`iivw`'s QA today**. Cheapest correctness evidence available:

1. **`Z ⊆ X` ⇒ stabilized IIW ≡ unweighted.** B&L p.8: when the visit covariates are a subset of the
   stabilization covariates, the stabilized weight "equals one for all individuals at all times" under
   assumption (4). Tompkins p.5 states the same. ⇒ `visit_cov()` ⊆ `stabcov()` must return weights that
   are **all 1.0** to numerical tolerance.
2. **Saturated-model equivalence.** *What If* §12.3 p.154: stabilized and unstabilized IPTW give the
   **same point estimate** when the weighted outcome model is saturated. ⇒ binary `treat()`, outcome model
   `Y ~ treat` alone: `θ̂₁` identical to tolerance under `wtype(iptw)` with and without stabilization.
3. **Mean-one.** *What If* §12.3 p.153 ("expected to be 1") and **Cole & Hernán, §Correct model
   specification: "a necessary condition for correct model specification is that the stabilized weights
   have a mean of one"**. ⇒ assert `mean(_iivw_tw) ≈ 1`. Necessary, **not sufficient** — no verdict may
   read the converse. **Use the self-calibrating `4·SD_subj(w)/√n_subjects` band from
   `qa/TOLERANCE_FRAMEWORK.md`, never a fixed absolute number**: a fixed `0.02` band false-reds on 35% of
   *correct* runs at n=60 (measured 2026-07-14). `_iivw_tw` is subject-constant, so `n` is **subjects**.
4. **Coulombe's DGP is a published known-truth fixture.** §3.3, PDF p.87–88: complete, reproducible,
   **true treatment effect = 1**, and its censoring `C_i ~ U(τ/2, τ)` makes the risk-set question
   unavoidable by construction. Steal it wholesale for the Phase-2 recovery grid.

---

## 6. Defect register (as grounded by this contract)

| ID | Defect | Source that proves it | Plan blocker |
|---|---|---|---|
| **IIVW-B01** | Risk set truncated at last visit | B&L p.7 `ξ_i(t)=I(C_i>t)`; IrregLong `addcensoredrows()` | ✅ **FIXED in 2.0.0** |
| **IIVW-B02** | Default variance treats estimated weights as known | B&L p.10–11; Coulombe PDF p.86 | #1 — **default now flipped (2.0.0), coverage gate still pending.** Phase 3B changed the WEIGHTED-GEE default: a bare weighted `iivw_fit` now selects the 999-draw subject bootstrap that refits every nuisance model, and `vce(fixed)` (the old default) is an explicit weights-known opt-in. `vce(bootstrap)` defaults to 999; fewer draws stamp `uncleared-low-reps`. RNG provenance (`e(iivw_rng)`, `e(iivw_rngstate_start)`), the CI type (`e(iivw_ci_type)=wald-normal`) and `e(iivw_inference_status)` are recorded; the refit default is stamped **`candidate`, NEVER `cleared`** — that word waits on the coverage+mutation gates. **The ≥1000×999 coverage simulation (`validation_iivw_inference.do`) has still not been run against the preregistered gate**, so the inference *claim* is not cleared even though the honest default now propagates weight-estimation uncertainty. Tests: `test_iivw_inference_contract` I12–I16 |
| **IIVW-B03** | FIPTIW attributed to Tompkins, not Coulombe | Tompkins p.2, p.6 | ✅ fixed at backfill |
| **IIVW-B04** | `stabcov()` not checked against the outcome design | B&L p.7, p.10; Cole & Hernán App. 1 | #4 — **FIXED 2.0.0** (Phase 2). `iivw_fit` maps `stabcov()` onto the expanded outcome design and errors before estimating if the numerator is not a function of it. `e(iivw_stabilization_validated)`, `e(iivw_stab_terms)`. Test: `test_iivw_phase2_contract` T8–T9; `validation_iivw_recovery_extended` S2a/S2b |
| **IIVW-B05** | Treatment absent from the FIPTIW visit model | Coulombe eq. 3.12 | #5 — **FIXED 2.0.0** (Phase 2). `treat()` enters the visit-intensity denominator by construction, deduplicated, shown in the fitted spec, recorded on the contract and replayed. `experimentalnotreatvisit` is the labelled opt-out. Test: `test_iivw_phase2_contract` T1–T4; `test_iivw_literature_invariants` T2 |
| **IIVW-B06** | Stabilized balance target omits `h(X)` | derived from B&L eq. 6 + the balance identity | #7 — **FIXED 2.0.0** (Phase 2). The target is `h(X)dΛ₀` under `stabcov()` and reduces exactly to `dΛ₀` without it. Pinned by the **saturated-stabilization identity** (B&L p.8): `stabcov()` = the full visit model ⇒ weight ≡ 1 ⇒ every TSMD = 0. Old code: **0.3321411**. Test: `test_iivw_phase2_contract` T5–T7 |
| **IIVW-B07** | `truncate()` clips the final product only | Tompkins §4.4; Cole & Hernán §Weight truncation | #8 — **FIXED 2.0.0** (Phase 2). `trunctreat()` / `truncvisit()` / `truncfinal()`, each with its own count and realized cutpoints, the untrimmed component preserved, and `iivw_balance` describing the analysis weight. `truncate()` is now `r(198)`. Supported default is untruncated. Test: `test_iivw_phase2_contract` T10–T15 |
| **IIVW-B08** | **Uncontrolled variance-option surface in `geeopts()`/`mixedopts()`** — pass-through tokens appended raw to the inner `glm`/`mixed` | Found at the Gate-0 review, 2026-07-14. Not in the finalization plan | **FIXED (2.0.0, Phase 3B).** Two-layer guard: (1) `_iivw_check_passthru.ado` rejects `vce()`/`robust`(abbrevs)/`cluster()`(abbrevs) in either pass-through option before every GEE/mixed call site incl. the bootstrap helpers; (2) a post-fit lock re-reads `e(vce)`/`e(clustvar)` and errors unless the posted covariance matches the package-selected method, recording `e(iivw_vce_locked)`. The original "silent override" wording was imprecise — the token actually errors at `glm` — but the surface is now owned deterministically. Test: `test_iivw_inference_contract` I16 |

### State-contract defects — closed by Phase 1 (2026-07-14)

These five are the plan's blockers #2, #3, #9, #10 and #11. Each is now a regression test that **fails against the pre-release build and passes on the shipped code**; the "proved by" column names the test and the measured old-code failure.

> **"Pre-release build" means the 2026-07-13 development state** (git HEAD before this work). 2.0.0 was never released, so these defects never reached a user — they are folded into the 2.0.0 breaking release rather than shipped and then patched.

| ID | Defect | Proved by (old-code behaviour measured 2026-07-14) | Status |
|---|---|---|---|
| **IIVW-B09** | `refitweights` did not replay `lagvars()`: the precomputed `*_lag1` columns were passed through `visit_cov()`, so lags were never rebuilt inside a resampled subject and the terminal censoring row carried the value from **two visits back** | `test_iivw_replay.do` T1. The **identity draw** — resample every subject exactly once — disagreed with the observed weights by **max reldif 2.24e-01**. It is now **0.00e+00** | ✅ **FIXED in 2.0.0** |
| **IIVW-B10** | The bootstrap snapshotted a hand-maintained **list** of `_dta[]` characteristics; three fields were missing from it, so a *successful* `refitweights` run blanked `_iivw_lagvars` and `_iivw_wsig` — and `_iivw_check_weighted` still returned 0, because the guard's own evidence had been erased by the same bug | `test_iivw_state_contract.do` T1–T2. Both halves now discover the namespace from the data, so all **22** contract fields survive | ✅ **FIXED in 2.0.0** |
| **IIVW-B11** | The stale-weight signature bound only the final weight, the id/time key, and the *generated* visit-covariate list. Editing `treat()`, editing a `treat_cov()` value, corrupting `_iivw_iw` while leaving the product alone, appending a row, or tampering with the stored spec **all returned rc 0** | `test_iivw_stale_state.do`, 17 mutations. The signature now binds every consumed input, every owned output, and the specification. Two specificity tests confirm a harmless re-sort still passes | ✅ **FIXED in 2.0.0** |
| **IIVW-B12** | Output ownership was **inferred from a name**: an existing `_iivw_*` variable that was not a current input was assumed to be a prior package output. A user's own `_iivw_weight = 99` column was backed up and **discarded at rc 0** — measured: it came back as `1` | `test_iivw_ownership.do` T1. Ownership is now a mark carried by the variable (`char v[_iivw_owner]`), and an unowned column is refused with r(110), unmutated | ✅ **FIXED in 2.0.0** |
| **IIVW-B13** | Missing final weights were a `Note:` in a long log. `iivw_fit` then marked those rows out silently: the analysis became complete-case without consent, and **differential loss by arm silently changed the estimand** | `test_iivw_sample_contract.do`. Missing weights now error (r(416)); `allowmissingweights` is the acknowledgment; loss is reported and returned **by treatment arm** | ✅ **FIXED in 2.0.0** |

### Estimator and inference defects — closed 2026-07-21 (audit SOL-01/02/03)

Raised by the independent audit of the 2.0.1 snapshot. Each is a regression test that **fails against the pre-fix code and passes on the current tree**; the "proved by" column names the test and the measured old-code failure. All three were `rc=0`-but-wrong: the command returned numbers while computing something other than the estimator it reported.

| ID | Defect | Proved by (old-code behaviour measured 2026-07-21) | Status |
|---|---|---|---|
| **SOL-01** | The IIW component was normalized to mean 1 over a **pooled** vector mixing hard-coded baseline weights of 1 with fitted `exp(-xb)` weights, and `baseline(event)` additionally overwrote the first fitted event's weight with 1. Since a Cox model has no intercept, `z -> z+c` multiplies every fitted weight by a common factor while the 1s stay put — so the baseline-to-follow-up ratio moved and the **point estimate depended on the arbitrary origin of a visit covariate** | `test_iivw_invariance.do`, **3/10 on the pre-fix build**. On the V1 fixture the coefficient on `a` moved by **0.0041** under `z -> z+8`, mean baseline weights scaled by **1.121** and follow-up weights by **0.969**. V9 is the discrimination control (the fixture *is* sensitive to the visit model); V2 passes on both builds because a rescale leaves `xb` untouched | ✅ **FIXED** — normalization is taken over the **modelled events only**, entry rows are inserted at exactly 1 *afterwards*, and no fitted weight is overwritten |
| **SOL-02** | The refit bootstrap resampled the **outcome sample**, then refitted the visit-intensity model on that truncated panel. Stata's `bootstrap` does not resample the prefix's `if` — it resamples the `e(sample)` the observed evaluation posts, and the helper posted `glm`'s. Visits with a missing outcome, a missing outcome covariate, or excluded by an outcome `if` were deleted before the weight model ran, so **every replicate bootstrapped a different estimator than the one reported** | `test_iivw_inference_contract.do` I18–I20. **I18/I19 fail numerically on the old code**: with 668 panel rows and 581 outcome rows the identity draw gave **0.63015547** against an observed **0.63280949**. Draw traces read `[567/567]`, `[546/546]`, `[576/576]` where the observed pass read `[668/581]`; after the fix they read `[660/567]`, `[628/546]`, `[659/576]`. **I20 is not old-code evidence** — it fails there at r(198) because `outcometouse()` does not exist on that build, so its discrimination leg (restricting the panel instead of the outcome equation must move the answer) is only exercised on the current tree | ✅ **FIXED** — the helper posts the **panel frame** as `e(sample)` (`marksample …, novarlist`), a separate `outcometouse()` marker restricts the outcome equation, and `_iivw_repost_outcome_n` restores the user-facing `e(N)`/`e(sample)` afterwards |
| **SOL-03** | Neither bootstrap wrapper checked `e(converged)`. `glm` and `mixed` both return a numeric coefficient vector after printing "convergence not achieved", so `bootstrap` booked non-solutions as completed replicates and folded them into the reported variance | `test_iivw_inference_contract.do` I21–I22. An outcome model capped at `iterate(1)` returned **rc=0 with 3 completed / 0 failed** replicates; it is now **r(430)**. The uncapped control still completes 3/3, so the test discriminates convergence from a fixture that cannot fit | ✅ **FIXED** — both wrappers gate `e(converged)` (a *missing* value fails closed too), and `allownonconverged` does not admit a nonconverged **outcome** fit inside a draw |

### `baseline()` is a substantive modelling choice, and the coverage gate had it wrong (2026-07-21)

Recorded here because it is a **method** fact, not a test detail, and because the package's own gate authors got it wrong — which is evidence about how the option reads, not just about one fixture.

`baseline()` decides what a subject's **first observed visit** is:

- `baseline(entry)` (the **default**) — the first visit is a *scheduled study-entry / recruitment* visit. It is not an event of the monitoring process, it is not modelled, and it receives a hard-coded weight of **1**.
- `baseline(event)` — the first visit is an *event of the monitoring process*, modelled like any other, and it keeps its fitted `exp(-xb)` weight.

**These are not interchangeable, and the default is only right when a recruitment visit actually exists.** Choosing `entry` for a visit process that has no entry visit assigns a hard-coded 1 to a genuine, informative monitoring event, and that is not a small approximation:

| `nsub` | slope bias under wrong mode | bias/SD | predicted 95% coverage |
|---|---|---|---|
| 250 | −0.0179 | 0.64 | 0.902 |
| 500 | −0.0171 | 0.84 | 0.866 |
| 1000 | −0.0161 | 1.14 | 0.793 |
| 2000 | −0.0166 | 1.66 | 0.617 |

The bias is **flat in n** while the sampling SD falls like `1/√n`, so it is an **asymptotic offset**: coverage degrades as the study grows. Under `baseline(event)` on the same DGP the slope bias is +0.002…+0.003 and predicted coverage is ~0.948 at both `nsub` — and the marginal **level** recovers to +0.0005 (against +0.128 under the wrong mode).

Attribution, measured rather than argued (400 sims, `nsub=1000`): true weights `exp(-γZ)` on every row → bias −0.0006 (0.7 MCSE, unbiased); the same true weights with **only** the first visit forced to 1 → −0.0169 (22.0 MCSE), reproducing the package's −0.0173; keeping `<2`-visit singletons changes nothing (−0.0007). The convention is the entire effect.

**Where this bit.** `benchmark_iivw_coverage.do` and the `iiw` family of `validation_iivw_inference.do` both called `iivw_weight` with **no** `baseline()`, taking the entry default, on `_cov_dgp`/`_inf_dgp_iiw` — a pure exponential-gap Poisson process with no entry visit. Both now pass `baseline(event)`. Corrected **before** the gate was ever run, so no preregistered constant was tuned to a seen result.

**Where it did not.** The `fiptiw` family passes `baseline(entry)` **deliberately and correctly**: `_inf_dgp_fiptiw` appends a real `t=0` carrier row (`entry=1`, `y=.`). The `iptw` family is one row per subject. Only the `iiw` fixture was wrong. The blanket fix would have broken a correct arm.

**Consequence for the SOL-01 story.** The old rationale in `benchmark_iivw_coverage.do` blamed the marginal-level offset on the SOL-01 baseline convention. That is falsified: on this DGP the pre-fix and post-fix weight vectors are **bit-identical** (`max reldif 0.000e+00` over 4471 rows), so SOL-01 cannot be moving anything here, yet the offset was still +0.128. SOL-01 and this are different defects that happened to involve the same word.

---

**What this did NOT touch.** SOL-04 through SOL-17 from the same audit are all still open — in particular the **999-replicate coverage study (SOL-04) has not been run**, so the default inference remains uncleared, and the stabilization guard (SOL-05), `iivw_diagnose` decomposition language (SOL-07), `iivw_exogtest` failure states (SOL-08) and the documentation/attribution items are unchanged. Fixing SOL-01–03 makes the default estimator invariant, the draws faithful, and the components fail-closed; it does not establish that the reported interval has nominal coverage.

**What Phase 1 did NOT touch.** IIVW-B02, B04, B05, B06, B07 and B08 are all still open. Phase 1 made the weighting *state* transactional and exactly replayable. It did not make any *estimator* or any *variance* correct. A bootstrap that now replays the weights faithfully is still bootstrapping the estimator described in §3, defects and all — it is simply no longer bootstrapping a *different* one by accident.

---

## 7. What Phase 0 changed about the plan

- **Blocker #4 is narrower than written.** It applies to the IIW numerator only. The IPTW numerator is
  correct by construction (§2). A Phase-2 implementer following the plan literally would have "fixed" a
  correct calculation.
- **Blocker #2's premise is now closed.** The plan said "the local literature index currently marks the
  Robins source as unavailable/unverified. Until a primary source is in the corpus, do not broaden the
  implementation." A primary source **is now in the corpus** (*What If* §12.3), it grounds the weight and
  the ATE, and it also **draws the boundary** (ATT needs a different numerator). The prohibition on
  broadening stands — now for a *sourced* reason rather than an absent one.
- **Three new free oracles** (§5) exist that the plan did not know about, two of them exact.
- **Five load-bearing options were unclassified** by every prior artifact (§3.11): `efron`,
  `allownonconverged`, `timespec`, `geeopts`, `force`. **`geeopts()` is a new defect (IIVW-B08)** — it is
  appended raw to the `glm` call after `vce(cluster ...)`, so it can silently override the very variance
  estimator the release blocker is about. The plan's 18-item blocker list does not mention it.
- **Gate 0's criterion (3) cannot be discharged by Phase 0 at all.** "No unsupported surface can produce
  an ordinary reliability-cleared result" is an *enforcement* property, and Phase 0 changes no code. Two
  probes on 2026-07-14 confirmed both open holes still return `rc=0` with ordinary output: `stabcov(Q)`
  with `Q` outside the outcome design was silently accepted (`b[treat]=0.4915, se=0.0602`), and FIPTIW
  fitted `stcox L1` with `treat` absent, storing `_iivw_visit_covars = L1`. Criterion (3) is satisfied
  **only** in the weak sense that the package now documents that **nothing** is reliability-cleared. The
  substantive requirement — that these **error** — is Phase 2 work and must be re-checked at Gate 2.
