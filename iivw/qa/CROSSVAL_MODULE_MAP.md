# `iivw` — Cross-Validation Module Map

**Phase 0 gate artifact.** Written 2026-07-14. Companion to `METHOD_ORACLE_MAP.md`.

Maps each external reference to **the module that computes it**, **what it actually proves**, and — the
column that matters — **what it does not prove**. An external arm whose "what it does not prove" column is
empty has not been thought about hard enough.

**Environment (recorded by `crossval_*_versions.csv`, regenerated per run):**
R 4.6.1 · `survival` 3.8.6 · `IrregLong` 0.4.1 · `geepack` 1.3.13 · `ipw` 1.3.0 · `cobalt` 4.6.3 · `nlme` 3.1.169

---

## 1. The modules

### 🟢 `crossval_iivw_irreglong` — the good one

| | |
|---|---|
| **Module** | `IrregLong::iiw.weights`, `IrregLong::addcensoredrows`, `survival::coxph` |
| **Authority** | **Pullenayegum is the method author.** This is her own implementation. |
| **Proves** | The IIW weight `exp(−xb)`, the `exp(xb_null − xb_full)` stabilization, the first-visit-weight-1 convention, and — decisively — the **censoring rows** (`addcensoredrows()` appends an `event=0` row at each subject's end of follow-up *before* `coxph`). Exact agreement required on the visit-model coefficient and observed-visit weights, with `maxfu(384)` and lags rebuilt after the censoring rows. |
| **Does NOT prove** | Anything about **variance** (IrregLong's SEs are not the corrected ones either). Anything about **IPTW/FIPTIW**. Anything about the **outcome model**. |
| **Disposition** | **RETAIN and extend.** This is the shape every other arm should copy. |

### 🔴 `crossval_fiptiw` — legacy parity, mislabelled

| | |
|---|---|
| **Module** | hand-rolled R (`survival` + `geepack`) on `fiptiw_simdata.csv` |
| **Proves** | That Stata and R agree **on the 1.x construction**. |
| **Does NOT prove** | The **recommended** estimator. Both sides build **observed-event-only risk sets**, and the Stata arm requests **`endatlastvisit`** — i.e. both reproduce defect **IIVW-B01**, which 2.0.0 exists to fix. **Two programs agreeing on the same wrong construction is not evidence.** Worse, the tolerances are smoke-test grade: **one comparison requires only `correlation > 0.75`**, one treatment-effect check allows **`|bias| < 0.25`** — bounds loose enough to pass with **treatment missing from the visit model** (defect IIVW-B05), which is exactly what the Stata arm does. |
| **Disposition** | **LEGACY-ONLY lane.** Do not count as FIPTIW validation. **Phase 2 owes a new full-at-risk-window FIPTIW parity arm** with Class-P tolerances (`TOLERANCE_FRAMEWORK.md`) and **treatment in the visit model per Coulombe eq. 3.12**. |

### 🟡 `crossval_iivw_external` — mixed

| Arm | Status |
|---|---|
| **Dietox / `geeglm`** (Gaussian, logit, Poisson) | 🟢 **Retain** — genuine independent check of the **outcome GEE** (B&L eq. 11 ≡ independence GEE). |
| **Dietox FIPTIW** | 🔴 **Legacy-only** — same shared `endatlastvisit` construction as above. |
| **Bladder / phenobarb** | 🟢 Retain — visit-model and entry-time parity fixtures. |
| **Lalonde** | 🟡 Propensity/balance fixture. Useful, but see the gap below. |
| **Does NOT prove** | The **variance** (all fixed-weight — see `METHOD_CONTRACT.md` §3.6), and the **stabilized ATE IPTW** (no arm does this). |

---

## 2. The gap Phase 2 must close

**`iivw`'s stabilized binary ATE IPTW — the weight at `iivw_weight.ado:1155-1158` — has NO external
oracle.** It is now *grounded* (*What If* §12.3, Technical Point 12.2) but never *checked* against an
independent implementation.

**The tool is already installed: `ipw` 1.3.0** (`ipw::ipwpoint`), plus `cobalt` 4.6.3 for balance.
There is no "library not available" excuse here.

**New arm — `crossval_iivw_iptw`:**

1. Export **one** analysis-ready, **one-row-per-subject** dataset for both languages.
2. R: `ipwpoint(exposure = treat, family = "binomial", link = "logit", numerator = ~1, denominator = ~treat_cov, data = d)` — `numerator = ~1` is precisely the marginal `Pr[A=1]` numerator (`METHOD_CONTRACT.md` §2), so this compares like with like.
3. Compare, **separately** (never as one aggregate number):
   - the propensity scores `Pr[A=1|L]`, row by row;
   - the **numerator** `Pr[A=1]` (a scalar — this is the piece no current test touches);
   - the final stabilized weights, row by row;
   - the weighted ATE `θ̂₁` from the saturated `Y ~ A` model.
4. Tolerances: **Class P** (`TOL_PARITY_COEF = 1e-6` on weights and PS; `TOL_PARITY_OUTCOME = 1e-5` on `θ̂₁`).
5. **The companion script must compute the reference, never hardcode it.**

> Cross-check with a **tier-1** oracle in the same suite so the R arm is not the only witness: the
> **saturated-model equivalence** invariant (*What If* §12.3 p.154 — stabilized ≡ unstabilized `θ̂₁` when
> the outcome model is `Y ~ A` alone) needs no R at all.

---

## 3. Rules for every crossval arm

- **Fresh references, in an empty temp dir, with completion sentinels and a recorded version manifest.** (The 2.0.0 external lane already does this — **keep it.** A stale `.csv` that silently survives a failed R run is a false green.)
- **Compare components separately, never as one number.** Row membership · interval starts/stops/events · nuisance coefficients · raw component weights (`_iivw_iw`, `_iivw_ps`, `_iivw_tw`) · normalization constants · final weights · outcome coefficients. A single aggregate comparison lets a compensating pair of errors pass.
- **The R script computes; it does not hardcode.** A reference literal in a `.R` file is a snapshot of the bug you had the day you wrote it.
- **Export the input once, read it from both languages.** Two independent data constructions is two chances to differ for a reason that has nothing to do with the estimator.
- **State what the arm does not prove.** In the file, at the top.
- **Never let an R arm be the sole witness for a formula that has a tier-1 invariant available.** Independent *software* can still share wrong *semantics* — which is the entire lesson of the FIPTIW arm above.

---

## 4. Lane membership

| Lane | Crossval content |
|---|---|
| `quick` | **none** — R lanes explicitly skipped. *(This is why the 43/43 quick PASS proves so little.)* |
| `core` | none |
| `external` | `crossval_iivw_irreglong`, `crossval_iivw_external`, **`crossval_iivw_iptw` (new)**, `crossval_iivw_fiptiw` (new, full-risk-set) |
| `full` | core + external + moderate simulations |
| `benchmark` | the ≥1,000-rep coverage gate (`TOLERANCE_FRAMEWORK.md` Class C) |
| *legacy* | `crossval_fiptiw` (1.x parity), the `endatlastvisit` arms — **run, reported, never counted as estimator validation** |
