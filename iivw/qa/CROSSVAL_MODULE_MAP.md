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

### 🟡 `crossval_fiptiw` — explicitly labelled legacy parity

| | |
|---|---|
| **Module** | hand-rolled R (`survival` + `geepack`) on `fiptiw_simdata.csv` |
| **Proves** | Stata and R agree on the **1.x observed-event construction**. XV8 separately compares normalized IIW, stabilized IPTW, final FIPTIW, and the product identity; XV9 checks a 90% fixed-weight CI transformation and stored `level()` against `geepack`. Treatment is present in the visit model. |
| **Does NOT prove** | The **recommended full-risk-window estimator** or repeated-sampling coverage. Both sides build observed-event-only risk sets and the Stata arm requests `endatlastvisit`. A single deterministic draw can establish software parity, not bias or coverage. |
| **Disposition** | **LEGACY evidence only.** Retain because it detects component and outcome-engine drift, but do not count it as validation of the recommended censoring-risk-set construction. |

### 🟡 `crossval_iivw_external` — mixed

| Arm | Status |
|---|---|
| **Dietox / `geeglm`** (Gaussian, logit, Poisson) | 🟢 **Retain** — genuine independent check of the **outcome GEE** (B&L eq. 11 ≡ independence GEE). |
| **Dietox FIPTIW** | 🔴 **Legacy-only** — same shared `endatlastvisit` construction as above. |
| **Bladder / phenobarb** | 🟢 Retain — visit-model and entry-time parity fixtures. |
| **Lalonde** | 🟡 Propensity/balance fixture. Useful, but see the gap below. |
| **Does NOT prove** | Corrected variance (the external outcome comparisons are fixed-weight) or the recommended full-risk-window FIPTIW construction. |

### 🟢 `crossval_iivw_pbcseq` — natural irregular follow-up

| | |
|---|---|
| **Module** | `survival::pbcseq`, `survival::coxph`, and `geepack::geeglm` |
| **Authority** | Public sequential measurements from the randomized Mayo PBC trial, shipped and documented by `survival`; the R script independently builds the counting-process data. |
| **Proves** | Exact risk-set counts and visit-model coefficients under subject-specific `censor()` plus `baseline(entry)`; row-level stabilized IIW with lagged bilirubin; quadratic-time weighted Gaussian GEE point and fixed-weight robust-SE parity; and `iivw_exogtest` coefficient/clustered-SE parity. |
| **Does NOT prove** | Causal treatment effects in PBC, corrected weight-estimation variance, or performance when incomplete laboratory rows are retained rather than restricted to the variables used by the oracle. |
| **Disposition** | **RETAIN.** It combines natural irregularity, outcome history, subject-specific follow-up, quadratic time, and a reporting command on one public study. |

---

## 2. Phase-2 IPTW gap — closed

`validation_iivw_iptw_oracle.do` now supplies the package-local exact,
hand-computed stabilized-ATE fixture and the mean-one/saturated identities.
`crossval_iivw_external.do` compares the same treatment-model components and
outcome target against fresh `ipw::ipwpoint`/`cobalt` references. The full
runner regenerates those references and refuses a missing completion sentinel,
so stale CSVs cannot close the gate.

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
| `full` | core + freshly regenerated `crossval_iivw`, `crossval_iivw_external`, `crossval_iivw_dta`, and `crossval_iivw_pbcseq` parity |
| `benchmark` | the ≥1,000-rep coverage gate (`TOLERANCE_FRAMEWORK.md` Class C) |
| `legacy` | legacy recovery scenarios; the `crossval_fiptiw` arms are explicitly labelled legacy within the mixed full cross-validation file |
| `sensitivity` (`sim` alias) | post-hoc scenario envelopes, reported separately from validation |
