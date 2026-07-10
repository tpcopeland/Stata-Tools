# finegray — QA suite

Quality assurance for the **finegray** package (v1.1.2, 2026-07-09): the
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
| `test_finegray_v111.do` | regression (v1.1.1 fixes: multi-record post-estimation, LT SEs, e(sample) after bootstrap, multi-var strata, string-id bootstrap, cluster resampling, factor `at()`) | 13 | 13 | 0 | 0 |
| `test_finegray_v112.do` | regression (v1.1.2 review fixes: stratified IPCW, stale-data/state guards, return gates, bootstrap convergence, safe saving) | 10 | 10 | 0 | 0 |
| `validation_finegray.do` | validation / invariants | 45 | 45 | 0 | 0 |
| `validation_finegray_recovery.do` | known-truth recovery | 4 | 4 | 0 | 0 |
| `validation_finegray_recovery_paths.do` | known-truth recovery across option/coding/estimand paths | 15 | 15 | 0 | 0 |
| `validation_finegray_cif_recovery.do` | analytic CIF known-answer recovery | 5 | 5 | 0 | 0 |
| `validation_finegray_cif_se.do` | closed-form CIF-SE oracle (jackknife) | 3 | 3 | 0 | 0 |
| `validation_finegray_lt_se.do` | left-truncation SE oracles (score identity + jackknife) | 3 | 3 | 0 | 0 |
| `crossval_finegray.do` | crossval vs `stcrreg` / `cmprsk` | 55 | 49 | 0 | 6 |
| `crossval_cif.do` | crossval vs `riskRegression` + bootstrap | 2 | 2 | 0 | 0 |
| `crossval_predict_phtest.do` | crossval vs `cmprsk::crr` | 14 | 14 | 0 | 0 |
| `crossval_predict_stcrreg.do` | crossval vs `stcrreg` | 15 | 15 | 0 | 0 |
| **Total** | | **335** | **329** | **0** | **6** |

*The 6 skips are `fastcmprsk` cross-checks (C45–C50), a redundant secondary
oracle. `cmprsk::crr` is the authoritative Fine-Gray reference and runs in full;
`fastcmprsk` only confirms it a second time. Skipping it loses no coverage.*

Last full run: 2026-07-09 via `stata-mp -b do run_all.do full`, R with
`cmprsk` and `riskRegression` present.

## How to run

Run from this `qa/` directory. The curated runner uses explicit lane membership
(no globbing), sandboxes PLUS/PERSONAL under `c(tmpdir)`, and exits nonzero if
any suite fails. Every suite also remains independently runnable; each derives
the package root from `c(pwd)`, performs a clean local `net install`, and writes
its log next to itself.

```bash
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # functional/regression lane
stata-mp -b do run_all.do core       # quick + validation + Stata-only crossval
stata-mp -b do run_all.do python     # R-backed cross-validation lane
stata-mp -b do run_all.do full       # all curated suites

# one suite (batch mode writes <name>.log alongside the .do)
stata-mp -b do test_finegray.do
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
| `run_all.do` | Curated lane runner (`quick`, `core`, `python`, `full`) |
| `_finegray_qa_common.do` | Shared sandbox bootstrap for the lane runner |
| `test_finegray.do` | Master functional/regression suite for all four commands |
| `test_finegray_v110.do` | Regression tests for the v1.1.0 feature surface (CIF curves, bootstrap CI, multi-record stsplit, `level()`) and the `finegray_cif` graph polish (single-row legend default, `legend()`/`title()`/`xtitle()` passthrough, single-curve/`nograph` paths) |
| `test_finegray_v111.do` | Regression tests for the v1.1.1 fixes: post-estimation parity between single-record and `stsplit` (reduced) fits, bootstrap refits on true entry times, `e(sample)` survival across `finegray_cif, bootstrap()`, `_fg_entry` lifecycle, multi-variable `strata()` through the CIF SE paths, string-`id()` bootstrap (no `r(109)` crash, no char/type leak, matches numeric path), cluster-level bootstrap resampling (SE inflated vs subject resampling), and `finegray_cif, at()` factor-variable natural names |
| `test_finegray_v112.do` | Regression tests for v1.1.2: estimation-data signatures, stale-state invalidation, graph/save return gates, strict `saving()`/`at()` validation, all/partial bootstrap nonconvergence, restored estimates and `e(sample)`, and helper `r()` isolation |
| `test_finegray_v114.do` | Regression tests for v1.1.4: factor-level bootstrap skips/counts, unspaced `saving(filename,replace)` parsing, and all-or-nothing prediction-variable cleanup |
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
| `.gitignore` | Excludes generated artifacts (`.log`, `.csv`, `.dta`, `.xlsx`, …) |

## Lane membership

| Lane | Suites |
|------|--------|
| `quick` | `test_finegray.do`, `test_finegray_v110.do`, `test_finegray_v111.do`, `test_finegray_v112.do`, `test_finegray_v114.do` |
| `core` | `quick` + `validation_finegray.do`, `validation_finegray_recovery.do`, `validation_finegray_recovery_paths.do`, `validation_finegray_cif_recovery.do`, `validation_finegray_cif_se.do`, `validation_finegray_lt_se.do`, `crossval_predict_stcrreg.do` |
| `python` | `crossval_cif.do`, `crossval_predict_phtest.do`, `crossval_finegray.do` |
| `full` | `core` + `python` |

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
| Data preservation, `if`/`in`, multi-record / left truncation | T8, T26, V23, V27–V28, test_v110, test_v111 |
| Coefficients / LL / χ² / SEs vs `stcrreg` | V1–V6, V9–V10, V24b, C1–C10 |
| Subdistribution-hazard / model invariants (SHR>0, scaling, reproducibility, convergence, explicit rank-deficiency rejection, separation, zero-event strata) | V7–V14, V37–V41 |

### `finegray_predict`

| Surface | Where tested |
|---------|--------------|
| `xb`, `cif`, `schoenfeld` | V15–V18, A1–A7, P1–P5 |
| CIF confidence intervals, `level()`, `bootstrap`, name-collision guard, `if`/`in` estimation-sample fix | test_v110, test_v111 (multi-record fits, multi-var strata, LT jackknife) |
| `xb` / `cif` / `schoenfeld` bit-exact vs `stcrreg` | A1–A7 |
| Row-level `xb` / `cif` / `schoenfeld` vs `cmprsk::crr` | P1–P11 |

### `finegray_cif`

| Surface | Where tested |
|---------|--------------|
| Fixed-horizon table, `at()`, `attime()`, `timepoints()`, `saving()`, `e(cmd)` guard, complete `r()` payload | test_v110, test_v111, test_v112 (safe parsing and graph/save failure gates) |
| Bootstrap CI, `level()` width control | test_v110, test_v111, test_v112 (nonconverged refits skipped; counts and state restoration) |
| Graph legend, `legend()`/`title()`/`xtitle()` passthrough, `nograph` | test_v110 |
| CIF point estimates vs `riskRegression::predictRisk`; SEs vs bootstrap | crossval_cif |
| Analytic CIF SE vs closed-form jackknife; `finegray_cif`/`finegray_predict` SE agreement | validation_cif_se |

### `finegray_phtest`

| Surface | Where tested |
|---------|--------------|
| Global χ², per-variable χ²/df/p, `r(N_fail)`, time functions | V30–V36 |
| χ² vs `cmprsk` at a common β (rank/log/identity, tie-free sim — exact); hypoxia functional validity; internal consistency and determinism | P3, P12, P14–P15 |

## The four assurance layers in detail

### 1. Functional / regression (174 tests)

`test_finegray.do` (127) walks the full command surface in eleven sections:
installation and helper auto-load, basic fits, every option individually and in
combination, one test per documented error message, complete stored-result
inventory, data preservation, and edge cases. `test_finegray_v110.do` (24) is a
version-pinned regression suite that locks in the v1.1.0 CIF/predict/bootstrap
surface and the `finegray_cif` graph polish (single-row legend default,
`legend()`/`title()`/`xtitle()` passthrough, single-curve/`nograph` paths), so
those features cannot silently regress. `test_finegray_v111.do` (13) and
`test_finegray_v112.do` (10) lock the subsequent correctness, state-safety,
return-gate, and bootstrap-convergence fixes.

### 2. Validation (75 tests across six suites)

`validation_finegray.do` proves correctness against three kinds of ground truth:

- **Live `stcrreg` parity** — coefficients match Stata's own Fine-Gray
  estimator to **< 1e-4** and the log-likelihood to **< 0.001** (V1–V6), both
  against frozen reference values and re-fit in the same session (V4).
- **Mathematical invariants** — SHR > 0; constant and exactly collinear terms are
  rejected as unidentified; χ² equals
  the Wald form *b′V⁻¹b*; p = `chi2tail(df, χ²)`; covariate scaling moves
  coefficients proportionally; adding an irrelevant covariate leaves the others
  unchanged; identical re-runs are bit-identical (V7–V14).
- **Prediction invariants** — CIF ∈ [0,1], monotone non-decreasing, and equal to
  `1 − exp(−H₀(t)·exp(xβ))`; `xb` equals manual *Zβ*; baseline cumulative hazard
  is positive, increasing, and time-sorted (V15–V20).
- **Robustness** — symmetric positive-definite robust and `norobust` covariance,
  strata, the multi-record `if`/`in` `bysort` fix, `censvalue()` invariance,
  predict `if`/`in` invariance, factor variables, phtest invariants, and stress
  cases (non-convergence, collinearity, near-separation, zero-event strata,
  interactions) (V21–V45).

`validation_finegray_cif_se.do` (3) adds a **closed-form (deterministic) oracle
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

### 3. Known-truth parameter recovery (24 tests across three suites) — the lead oracle

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

`validation_finegray_recovery_paths.do` (15) drives the **same** closed-form DGP
through fifteen distinct invocation and coding paths, so recovery is proven not
just for the core fit but for every branch a user can reach: a null effect
(β = 0, SHR = 1) and a strong one (β = 1.0, cause-specific Cox provably misses); a
binary covariate, three continuous covariates, an `i.grp` factor, and an
`i.grp##c.z1` interaction; non-default `cause(2)` and `censvalue(9)` codings;
`cluster()` and `norobust` variance estimators (point estimate recovers,
`e(vce)` correct); heavy independent censoring (~75% censored, IPCW stress);
high (p = 0.6) and low (p = 0.2) baseline incidence; `level(90)` invariance; and
the multiple-record reduction — an `stsplit` panel fit recovers the truth and
matches its single-record counterpart to `reldif < 1e-4`.

`validation_finegray_cif_recovery.do` (5) extends the known-truth idea to the
**predicted cumulative incidence** (`finegray_cif`). At the reference profile
z = 0 the DGP collapses to the exact, estimator-free oracle
F₁(t; 0) = p·(1 − e^(−t)); the suite asserts `finegray_cif` reproduces it across
horizons (and the general F₁(t; z) = 1 − (1 − p·(1 − e^(−t)))^exp(z′b) at z = 1),
checks the plateau and the [0,1]/monotonicity invariants, and repeats at
p = 0.6. Observed max absolute error 0.0015–0.0030 at N = 120 000. This suite
also exercises the CIF influence-function variance code at realistic N, where the
O(_n_ log _n_) prefix-sum rewrite (v1.1.1, numerically identical to the prior
O(_n_²) implementation) keeps it practical (~7 s vs ~91 s per call at N = 120 000).

### 4. Cross-validation (86 tests against 3 independent references)

| Suite | Reference | What it proves |
|-------|-----------|----------------|
| `crossval_predict_stcrreg.do` | StataCorp `stcrreg` | `finegray_predict` `xb`, `exp(xb)` (relative subhazard), covariate and baseline CIF, `e(basehaz)`, Schoenfeld residuals (incl. tied-time group sums), and SHR/SE/95% CI all match the native estimator — bit-exact on point estimates, **< 2%** relative on robust SEs and CIs. Also includes a GitHub issue&nbsp;#1 regression guard (C1/C2): the fixed-horizon (`timevar()`) CIF matches the correct baseline-CIF mapping `1-(1-basecif)^exp(xb)` to ~6e-8 and is asserted **not** to equal the wrong `basecif^exp(xb)`. No external dependency; never skips. |
| `crossval_finegray.do` | `stcrreg` + `cmprsk::crr` | Coefficients vs `stcrreg` to **< 1e-4** across covariate combinations and both causes; log-likelihood, robust SEs (ratio 0.95–1.05), strata via `cengroup`, high-censoring stress, simulated-DGP direction recovery, and N = 500–50 000 performance benchmarks. Strata parity vs `cmprsk` `cengroup` (C51–C55): coefficients < 1e-6, SEs < 0.1%, relative LL difference < 1e-6, CIF < 1e-5. |
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
