# finegray — QA suite

Quality assurance for the **finegray** package (v1.1.0, 2026-06-21): the
Fine and Gray (1999) subdistribution-hazards estimator (`finegray`) and its
post-estimation tools (`finegray_predict`, `finegray_cif`, `finegray_phtest`).

This suite is built on four assurance layers, applied in increasing order of
authority:

1. **Functional / regression tests** — every command, option, error path, and
   stored result behaves as documented.
2. **Validation** — model invariants and known answers that are checkable by
   hand or against Stata's own `stcrreg`, including a closed-form (deterministic
   delete-one jackknife) oracle for the analytic CIF standard error.
3. **Known-truth parameter recovery** — the lead correctness oracle: simulate
   competing-risks data from a Fine-Gray model whose true log-subhazard ratio
   *we* set, then prove `finegray` recovers it at large N while a naive
   cause-specific Cox model provably misses it.
4. **Cross-validation** — bit-level agreement with three independent reference
   implementations: StataCorp's `stcrreg`, R's `cmprsk::crr`, and R's
   `riskRegression`.

## Headline results

Every executable test passes. The only skips are an *optional* secondary R
reference (`fastcmprsk`, archived on CRAN) — the authoritative references
(`stcrreg`, `cmprsk`, `riskRegression`) all run and all agree.

| Suite | Type | Tests | Pass | Fail | Skip |
|-------|------|------:|-----:|-----:|-----:|
| `test_finegray.do` | functional / regression | 127 | 127 | 0 | 0 |
| `test_finegray_v110.do` | regression (v1.1.0 surface + graph polish) | 24 | 24 | 0 | 0 |
| `validation_finegray.do` | validation / invariants | 45 | 45 | 0 | 0 |
| `validation_finegray_recovery.do` | known-truth recovery | 4 | 4 | 0 | 0 |
| `validation_finegray_cif_se.do` | closed-form CIF-SE oracle (jackknife) | 7 | 7 | 0 | 0 |
| `crossval_finegray.do` | crossval vs `stcrreg` / `cmprsk` | 55 | 49 | 0 | 6 |
| `crossval_cif.do` | crossval vs `riskRegression` + bootstrap | 2 | 2 | 0 | 0 |
| `crossval_predict_phtest.do` | crossval vs `cmprsk::crr` | 14 | 14 | 0 | 0 |
| `crossval_predict_stcrreg.do` | crossval vs `stcrreg` | 13 | 13 | 0 | 0 |
| **Total** | | **291** | **285** | **0** | **6** |

*The 6 skips are `fastcmprsk` cross-checks (C45–C50), a redundant secondary
oracle. `cmprsk::crr` is the authoritative Fine-Gray reference and runs in full;
`fastcmprsk` only confirms it a second time. Skipping it loses no coverage.*

Last full run: `stata-mp` (MP), R with `cmprsk` and `riskRegression` present.

## How to run

All suites are self-contained and relocatable: each derives the package root
from its own working directory, performs a clean local `net install`, and
writes its log next to itself. Run from this `qa/` directory.

```bash
# one suite (batch mode writes <name>.log alongside the .do)
stata-mp -b do test_finegray.do

# whole suite — run a couple at a time; the R-backed crossvals are slower
for f in test_finegray test_finegray_v110 \
         validation_finegray validation_finegray_recovery validation_finegray_cif_se \
         crossval_predict_stcrreg crossval_cif \
         crossval_predict_phtest crossval_finegray; do
    stata-mp -b do "$f.do"
done
grep -h "^RESULT:" *.log     # one sentinel line per suite
```

Each suite prints a machine-parseable sentinel as its last line, e.g.
`RESULT: validation_finegray tests=45 pass=45 fail=0`, and `exit 1`s on any
failure — so a non-zero exit code or a `fail=` count above zero flags a problem.

### Dependencies

| Suite | Needs |
|-------|-------|
| `test_*`, `validation_finegray*` | Stata only |
| `crossval_predict_stcrreg.do` | Stata only (`stcrreg` ships with Stata) |
| `crossval_finegray.do` | R + `cmprsk` (required); `fastcmprsk` (optional) |
| `crossval_cif.do` | R + `riskRegression` |
| `crossval_predict_phtest.do` | R + `cmprsk` |

R-backed suites are **SKIP-safe**: if R or the reference package is missing they
report a skip rather than a failure, so the suite still runs on a Stata-only
machine. Install the references to get full parity coverage:

```r
install.packages(c("cmprsk", "riskRegression"))
```

## File index

| File | Role |
|------|------|
| `test_finegray.do` | Master functional/regression suite for all four commands |
| `test_finegray_v110.do` | Regression tests for the v1.1.0 feature surface (CIF curves, bootstrap CI, multi-record stsplit, `level()`) and the `finegray_cif` graph polish (single-row legend default, `legend()`/`title()`/`xtitle()` passthrough, single-curve/`nograph` paths) |
| `validation_finegray.do` | 45 known-answer and invariant checks (incl. live `stcrreg` parity) |
| `validation_finegray_recovery.do` | Known-truth log-SHR recovery from a Fine-Gray DGP |
| `validation_finegray_cif_se.do` | Closed-form (deterministic delete-one jackknife) oracle for the analytic CIF standard error |
| `crossval_finegray.do` | Systematic estimator parity vs `stcrreg` and `cmprsk::crr` (coefficients, SEs, LL, CIF, strata, benchmarks) |
| `crossval_finegray_r.R` | R companion: `cmprsk::crr` / `fastcmprsk::fastCrr` reference fits |
| `crossval_cif.do` | CIF point estimates vs `riskRegression`; CIF SEs vs subject bootstrap |
| `crossval_cif_r.R` | R companion: `riskRegression::FGR` + `predictRisk` |
| `crossval_predict_phtest.do` | Row-level `finegray_predict` and `finegray_phtest` parity vs R |
| `crossval_predict_phtest_r.R` | R companion for the predict/phtest cross-check |
| `crossval_predict_stcrreg.do` | Every prediction path vs native `stcrreg` (no external dependency) |
| `.gitignore` | Excludes generated artifacts (`.log`, `.csv`, `.dta`, `.xlsx`, …) |

## Coverage map

Keyed to the command surface. Every public command, option, and stored result
is exercised somewhere below.

### `finegray` (estimation)

| Surface | Where tested |
|---------|--------------|
| Core fit, 1/2/3-covariate models, cause(1)/cause(2) | T5–T8, V1–V6, C1–C5 |
| Options `noshr`, `level()`, `robust`, `cluster()`, `strata()`, `censvalue()`, `iterate()`, `tolerance()`, `nolog` | T9–T17, T26, V22, V24, V26, V29, C11–C12, C51–C55 |
| Factor variables (`i.`, `ib#.`, `##` interactions) | T18–T19, V25, V42–V45, C27 |
| Combined options | T20 |
| Error handling (no `stset`, missing `compete()`/`cause()`, bad cause, no competing events, no `id()`, removed options) | T21–T30 |
| Stored results `e(b)`, `e(V)`, `e(basehaz)`, all scalars/macros, event-count identity | T31–T37, V19–V20 |
| Data preservation, `if`/`in`, multi-record / left truncation | T8, T26, V23, V27–V28, test_v110 |
| Coefficients / LL / χ² / SEs vs `stcrreg` | V1–V6, V9–V10, V24b, C1–C10 |
| Subdistribution-hazard / model invariants (SHR>0, null β≈0, scaling, reproducibility, convergence, separation, zero-event strata) | V7–V14, V37–V41 |

### `finegray_predict`

| Surface | Where tested |
|---------|--------------|
| `xb`, `cif`, `schoenfeld` | V15–V18, A1–A7, P1–P5 |
| CIF confidence intervals, `level()`, `bootstrap`, name-collision guard, `if`/`in` estimation-sample fix | test_v110 |
| `xb` / `cif` / `schoenfeld` bit-exact vs `stcrreg` | A1–A7 |
| Row-level `xb` / `cif` / `schoenfeld` vs `cmprsk::crr` | P1–P11 |

### `finegray_cif`

| Surface | Where tested |
|---------|--------------|
| Fixed-horizon table, `at()`, `attime()`, `timepoints()`, `saving()`, `e(cmd)` guard, `r(profile_vars)` | test_v110 |
| Bootstrap CI, `level()` width control | test_v110 |
| Graph legend, `legend()`/`title()`/`xtitle()` passthrough, `nograph` | test_v110 |
| CIF point estimates vs `riskRegression::predictRisk`; SEs vs bootstrap | crossval_cif |
| Analytic CIF SE vs closed-form jackknife; `finegray_cif`/`finegray_predict` SE agreement | validation_cif_se |

### `finegray_phtest`

| Surface | Where tested |
|---------|--------------|
| Global χ², per-variable χ²/df/p, `r(N_fail)`, time functions | V30–V36 |
| χ² vs `cmprsk` at a common β (rank/log/identity, tie-free sim — exact); hypoxia functional validity; internal consistency and determinism | P3, P12, P14–P15 |

## The four assurance layers in detail

### 1. Functional / regression (151 tests)

`test_finegray.do` (127) walks the full command surface in eleven sections:
installation and helper auto-load, basic fits, every option individually and in
combination, one test per documented error message, complete stored-result
inventory, data preservation, and edge cases. `test_finegray_v110.do` (24) is a
version-pinned regression suite that locks in the v1.1.0 CIF/predict/bootstrap
surface and the `finegray_cif` graph polish (single-row legend default,
`legend()`/`title()`/`xtitle()` passthrough, single-curve/`nograph` paths), so
those features cannot silently regress.

### 2. Validation (45 + 7 tests)

`validation_finegray.do` proves correctness against three kinds of ground truth:

- **Live `stcrreg` parity** — coefficients match Stata's own Fine-Gray
  estimator to **< 1e-4** and the log-likelihood to **< 0.001** (V1–V6), both
  against frozen reference values and re-fit in the same session (V4).
- **Mathematical invariants** — SHR > 0; a null covariate gives β ≈ 0; χ² equals
  the Wald form *b′V⁻¹b*; p = `chi2tail(df, χ²)`; covariate scaling moves
  coefficients proportionally; adding an irrelevant or constant covariate leaves
  the others unchanged; identical re-runs are bit-identical (V7–V14).
- **Prediction invariants** — CIF ∈ [0,1], monotone non-decreasing, and equal to
  `1 − exp(−H₀(t)·exp(xβ))`; `xb` equals manual *Zβ*; baseline cumulative hazard
  is positive, increasing, and time-sorted (V15–V20).
- **Robustness** — symmetric positive-definite robust and `norobust` covariance,
  strata, the multi-record `if`/`in` `bysort` fix, `censvalue()` invariance,
  predict `if`/`in` invariance, factor variables, phtest invariants, and stress
  cases (non-convergence, collinearity, near-separation, zero-event strata,
  interactions) (V21–V45).

`validation_finegray_cif_se.do` (7) adds a **closed-form (deterministic) oracle
for the analytic CIF standard error**. finegray reports an influence-function
(sandwich) SE for the cumulative incidence, with the censoring weights treated
as known; no R package exposes a Fine-Gray CIF SE, so the only external check
available to `crossval_cif.do` is a Monte-Carlo subject bootstrap. This suite
supplies the deterministic counterpart: the delete-one **jackknife** variance,
`(n−1)/n · Σ(F₍₋ᵢ₎ − F̄)²`, computed by refitting on leave-one-subject-out
samples — an entirely independent mechanism that never touches the SE Mata code.
Because removing one subject perturbs the censoring KM only infinitesimally, the
jackknife matches the analytic SE far more tightly than the bootstrap does: on a
seeded DGP the analytic SE sits at a stable ratio of **0.97–0.99** to the
jackknife across two covariate profiles and three horizons (the ~1–2% gap is
exactly the known-censoring assumption), and `finegray_cif` and
`finegray_predict` are confirmed to report a bit-identical SE.

### 3. Known-truth parameter recovery (4 tests) — the lead oracle

`validation_finegray_recovery.do` is the strongest correctness statement the
suite makes, because the truth is set by us, not borrowed from another
estimator. It simulates competing risks directly from the Fine-Gray
subdistribution model

> F₁(t; z) = 1 − (1 − p·(1 − e^(−t)))^exp(z′b)

with the event-time CDF inverted in closed form, so the true log-SHR **b** is
known exactly. At N = 50 000–60 000:

| Scenario | Truth | Recovered |
|----------|-------|-----------|
| A: positive single coefficient | b = +0.5 | ✓ within 0.03, and naive Cox provably misses |
| B: negative single coefficient | b = −0.7 | ✓ within 0.03 |
| C: two-covariate model | (0.5, −0.4) | ✓ both within 0.03 |
| D: `strata()` under group-dependent censoring | b = +0.6 | ✓ within 0.03 |

Each scenario also confirms that a **cause-specific Cox model misses the truth**
on the same data (it targets a different estimand), proving the scenario
actually exercises what the Fine-Gray estimator is built to do rather than
passing trivially. The 0.03 tolerance is ~2× the worst Monte-Carlo error
observed across a 6-seed mini-MC and ~4× the analytic SE — deterministic at the
fixed seeds, not a loose band.

### 4. Cross-validation (78 tests against 3 independent references)

| Suite | Reference | What it proves |
|-------|-----------|----------------|
| `crossval_predict_stcrreg.do` | StataCorp `stcrreg` | `finegray_predict` `xb`, `exp(xb)` (relative subhazard), covariate and baseline CIF, `e(basehaz)`, Schoenfeld residuals (incl. tied-time group sums), and SHR/SE/95% CI all match the native estimator — bit-exact on point estimates, **< 2%** relative on robust SEs and CIs. No external dependency; never skips. |
| `crossval_finegray.do` | `stcrreg` + `cmprsk::crr` | Coefficients vs `stcrreg` to **< 1e-4** across covariate combinations and both causes; log-likelihood, robust SEs (ratio 0.95–1.05), strata via `cengroup`, high-censoring stress, simulated-DGP direction recovery, and N = 500–50 000 performance benchmarks. Strata parity vs `cmprsk` `cengroup` (C51–C55): coefficients < 0.01, SEs < 15%, LL < 0.1%, CIF < 0.02. |
| `crossval_cif.do` | R `riskRegression` | `finegray_cif` point estimates match `riskRegression::predictRisk` (**< 1e-4**); CIF standard errors match a same-dataset subject bootstrap. (Since no R package exposes a Fine-Gray CIF SE, the *deterministic* SE oracle is the jackknife in `validation_finegray_cif_se.do`.) |
| `crossval_predict_phtest.do` | `cmprsk::crr` | Row-level `xb` (**< 0.001**) and CIF (**< 0.01**) vs R. Schoenfeld residuals and `finegray_phtest` χ² are cross-checked at a **common β** (finegray's coefficients passed to R, isolating the residual algorithm from optimizer-to-optimizer β differences): on tie-free simulated data the residuals are **bit-exact (< 1e-4)** and the χ² agrees with `cmprsk` across rank/log/identity transforms to **< 0.5%** (observed ~1e-6). Hypoxia (heavy ties + a near-zero censoring weight) is checked for functional validity only — its residuals are validated bit-for-bit against `stcrreg` in `crossval_predict_stcrreg.do`. Includes an internal `predict schoenfeld` → manual correlation → `phtest` consistency check and a determinism check. |

#### Tolerance rationale

Tolerances are tiered by how close the reference algorithm is to `finegray`:

- **Same algorithm (`stcrreg`, identical model):** point estimates bit-exact;
  coefficients < 1e-4, LL < 0.001, SE/CI < 2%.
- **Different implementation, same estimand (`cmprsk`, `riskRegression`):**
  coefficients < 0.01, xb < 0.001, CIF < 0.01, Schoenfeld < 0.05.
- **PH-test χ² (at a common β, tie-free data):** < 0.5% relative (observed
  ~1e-6) — once the optimizer-β difference is removed, the correlation-based
  statistic agrees with `cmprsk` to numerical precision. On tie-heavy /
  ill-conditioned data (hypoxia) the per-event residual is convention- and
  truncation-dependent, so χ² is not cross-validated there (functional check
  only; residuals validated against `stcrreg` instead).
- **Monte-Carlo / finite-sample SEs (CIF subject bootstrap):** ~15% relative
  band (`crossval_cif.do`), reflecting bootstrap noise at feasible reps; the
  *deterministic* jackknife oracle (`validation_finegray_cif_se.do`) pins the
  same SE to ~1–2%.

## Conventions

- **Self-contained & relocatable** — no hardcoded paths; package root is derived
  from `c(pwd)`, R cross-check CSVs are written to `c(tmpdir)`. Nothing under
  `qa/` is required at runtime by the package.
- **Clean install per suite** — each `.do` `ado uninstall`s then `net install`s
  `finegray` from the local source, so tests run against the working tree, never
  a shadowed installed copy.
- **Test isolation** — every test block re-establishes its own data (`webuse
  hypoxia` or a seeded simulation); no test depends on prior state.
- **Semantic assertions** — checks compare against expected *values* (or tight
  analytic bounds), not mere existence.
- **Machine-parseable** — each suite ends with a `RESULT: <name> tests=N pass=N
  fail=N [skip=N]` sentinel and `exit 1`s on failure.
- **No tracked artifacts** — generated logs/CSVs/datasets are gitignored.

## What a clean run demonstrates

- `finegray` returns the **correct estimand**: it recovers a log-SHR set by us
  at large N, where a naive competing-risks-as-censoring Cox model fails.
- It is **numerically identical to StataCorp's `stcrreg`** on coefficients, log-
  likelihood, predictions, and Schoenfeld residuals — while remaining practical
  on data sizes where `stcrreg` is slow or infeasible.
- It **agrees with two independent R references** (`cmprsk`, `riskRegression`)
  on coefficients, CIF, and the proportional-subhazards diagnostic.
- Its post-estimation surface (`finegray_predict`, `finegray_cif`,
  `finegray_phtest`) is correct, CI-aware, bootstrap-capable, and fully
  documented-behaviour-locked by version-pinned regression tests.
