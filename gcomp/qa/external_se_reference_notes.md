# External Reference Notes for gcomp Point Estimates and SEs

Date: 2026-05-06

Scope: research notes for adversarial QA of `gcomp` point estimates, bootstrap
standard errors, and bootstrap covariance matrices against comparable R/Python
implementations.

## Current QA Baseline

Existing QA already covers several external point-estimate comparisons:

- `crossval_external_replication.do` compares binary-outcome mediation,
  continuous-outcome mediation, and time-varying EOFU potential outcome means
  against deterministic Python/statsmodels plug-in formulas in
  `qa/data/generate_external_replication.py`.
- `crossval_gcomp.do` compares OBE mediation against analytical DGP values and
  R `mediation` package benchmarks.
- `crossval_timevarying.do` compares EOFU potential outcome levels and risk
  differences against a sequential Python Monte Carlo benchmark.

The added SE gates address the highest-priority gap:

- `crossval_mediation_se.do` regenerates Python/statsmodels mediation fixtures,
  compares TCE/NDE/NIE/PM/CDE point estimates and bootstrap SEs, checks
  `sqrt(diag(e(V))) == e(se)`, and compares selected off-diagonal covariance
  values against Python bootstrap covariance references.
- `crossval_timevarying_se.do` regenerates Python/statsmodels EOFU fixtures,
  compares PO/RD point estimates and SEs, computes RD SE from `e(V)`, and
  compares `cov(PO1,PO2)` against Python subject-bootstrap references.

Remaining gaps are narrower effect families and more complex longitudinal
branches listed below.

Quick local availability check:

- Python: `numpy 2.4.4`, `pandas 3.0.2`, `statsmodels 0.14.6`
- R: `mediation 4.5.1`, `gfoRmula 1.1.1`
- R: `stdReg2` unavailable locally

External documentation consulted:

- R `mediation`: https://search.r-project.org/CRAN/refmans/mediation/html/mediate.html
- R `gfoRmula`: https://www.maths.bris.ac.uk/R/web/packages/gfoRmula/gfoRmula.pdf
- R `stdReg2`: https://stat.ethz.ch/CRAN/web/packages/stdReg2/stdReg2.pdf
- Python `statsmodels` GLM: https://www.statsmodels.org/dev/glm.html

## Best External Oracles

### Python/statsmodels: primary exact oracle

Use `statsmodels` as the main adversarial oracle for clean point estimate and
bootstrap SE replication. It is transparent, already used by the package
fixtures, and maps directly onto the model families used in the cleanest
`gcomp` test cases:

- Stata `logit` -> `statsmodels.GLM(..., family=Binomial())`
- Stata `regress` -> `statsmodels.OLS`
- Plug-in g-formula calculations can be written explicitly, avoiding ambiguity
  about estimands or package defaults.

Recommended use:

- Mediation OBE, binary exposure, one binary mediator:
  - binary outcome: TCE, NDE, NIE, PM, CDE on risk-difference scale
  - continuous outcome: TCE, NDE, NIE, PM, CDE on mean-difference scale
  - use `minsim moreMC` and large `sim()` so Stata behaves like deterministic
    plug-in standardization rather than random Monte Carlo drawing
  - bootstrap externally by resampling rows, refitting all nuisance models, and
    recomputing all effects
- Time-varying EOFU:
  - static interventions `A=1` and `A=0`
  - binary EOFU outcome and continuous EOFU outcome
  - compare `PO1`, `PO2`, observed/natural PO if included, and `PO1 - PO2`
  - bootstrap externally by resampling subjects/clusters, not rows

The Python oracle should be the source of exact SE benchmarks because it can
match `gcomp`'s target estimands and resampling units more closely than
off-the-shelf causal packages.

### R mediation: useful but not exact for SEs

R `mediation::mediate()` is a useful analogue for standard binary-exposure
single-mediator natural effects. It reports ACME/NIE, ADE/NDE, total effect,
and proportion mediated. It is appropriate for broad agreement checks on OBE
mediation when the mediator and outcome models are ordinary `glm` or `lm`
objects.

Limits:

- Its default inference is quasi-Bayesian simulation, not `gcomp`'s bootstrap.
- Even with `boot=TRUE`, implementation details and supported model classes do
  not give a clean one-to-one test of this package's Monte Carlo g-formula
  machinery.
- It is not a clean oracle for CDE, OCE vector contrasts, BOCE-AM,
  post-treatment confounder handling, time-varying interventions, MSM summaries,
  survival, stochastic interventions, or ordinal/multinomial simulation paths.

Recommended use: keep R `mediation` as a sanity benchmark for OBE TCE/NDE/NIE/PM
point estimates and CI scale, not as the primary SE oracle.

### R gfoRmula: best off-the-shelf analogue for longitudinal g-formula

R `gfoRmula` is the closest package analogue for longitudinal parametric
g-formula under time-varying treatments/confounders. Its documented scope
includes counterfactual means/risks under hypothetical interventions, discrete
or continuous time-varying treatments, EOFU binary/continuous outcomes, failure
time outcomes, censoring, competing events, and flexible intervention
specification.

Recommended use:

- Use it for package-level triangulation of simple time-varying EOFU scenarios:
  two static interventions, one treatment, one time-varying confounder, no
  censoring, no competing event, no MSM.
- Compare point estimates and bootstrap SEs only if the data layout, visit
  process, intervention coding, model families, and resampling units can be
  aligned exactly.

Limits:

- `gfoRmula` is a richer longitudinal package with its own input contract. A
  mismatch can test interface differences instead of `gcomp` correctness.
- It is not the cleanest first-line oracle for mediation outputs.
- For survival, competing risks, stochastic/dynamic interventions, and complex
  censoring, it is better as a qualitative analogue unless an exact paired
  fixture is built.

### R stdReg/stdReg2: standardization analogue, not full gcomp analogue

`stdReg2` documents regression standardization for GLM, GEE, Cox, and frailty
models. It is conceptually useful for single-time standardized means/risks, but
`stdReg2` is not installed locally and is not a natural direct match for this
package's mediation decomposition or sequential time-varying simulation.

Recommended use: optional future triangulation for simple baseline-treatment
standardized risks or means. Do not make it a required QA dependency for this
package unless it is vendored or installed in the QA environment.

## Clean Cross-Validation Targets

### 1. Mediation OBE point estimates

Cleanest estimands:

- TCE = `E[Y(1, M(1))] - E[Y(0, M(0))]`
- NDE = `E[Y(1, M(0))] - E[Y(0, M(0))]`
- NIE = TCE - NDE
- PM = NIE / TCE
- CDE at `control(m0)` = `E[Y(1, m0)] - E[Y(0, m0)]`

Recommended fixtures:

- Binary mediator + binary outcome, `commands(m: logit, y: logit)`.
- Binary mediator + continuous outcome, `commands(m: logit, y: regress)`.
- Include `control(0)` so CDE is covered.
- Run Stata with `minsim moreMC sim(5000+) samples(499 or 999)` for stable
  point estimates and SEs. Use a fixed seed.

Recommended tolerances:

- Point estimates:
  - TCE/NDE/NIE/CDE: absolute tolerance `0.002` to `0.005` for binary outcome;
    `0.005` to `0.015` for continuous outcome depending on residual variance.
  - PM: absolute tolerance `0.02` to `0.05`, because it is a ratio and becomes
    unstable when TCE is small. Design fixtures with `abs(TCE) >= 0.08`.
- Bootstrap SEs:
  - TCE/NDE/NIE/CDE: relative tolerance `10%` plus absolute floor `0.003`.
  - PM: relative tolerance `20%` plus absolute floor `0.03`.
  - Compare both individual `e(se_*)` scalars and the diagonal of `e(V)`.
- CIs:
  - Normal CI endpoints can be checked against `b +/- invnormal(.975) * se`
    exactly within floating tolerance.
  - Percentile/BC/BCa external equality is lower priority unless Python mirrors
    Stata's bootstrap percentile implementation exactly.

### 2. Time-varying EOFU potential outcome means

Cleanest estimands:

- Mean/risk under static `A=1` at all visits: `PO1`
- Mean/risk under static `A=0` at all visits: `PO2`
- Optional observed/natural course mean if exposed by the Stata result matrix
- Risk/mean difference: `PO1 - PO2`

Recommended fixtures:

- Three visits, one binary treatment `A`, one continuous time-varying
  confounder `L`, one baseline covariate `L0`, EOFU outcome only.
- Binary EOFU outcome: `commands(A: logit, Y: logit, L: regress)`.
- Continuous EOFU outcome: `commands(A: logit, Y: regress, L: regress)`.
- Use lag rules already present in QA: `Alag: A 1`, `Llag: L 1`.
- External bootstrap must resample unique `id` values with replacement and
  carry all rows for selected subjects. Row bootstrap is wrong for this
  estimand.

Recommended tolerances:

- Point estimates with deterministic plug-in/minsim setup:
  - PO means and `PO1 - PO2`: absolute tolerance `0.002` to `0.01`.
- Point estimates with random simulation:
  - PO means: absolute tolerance `0.02` to `0.04`.
  - RD/MD: absolute tolerance `0.03` to `0.06`.
- Bootstrap SEs:
  - PO SEs: relative tolerance `10%` plus absolute floor `0.005`.
  - RD/MD SE from external bootstrap distribution: relative tolerance `12%`
    plus absolute floor `0.006`.
  - If Stata only posts PO SEs and not the RD SE, compute RD externally for
    reporting but do not assert it against `e(se)` unless `gcomp` exposes a
    matching contrast.

## Outputs That Are Harder to Validate Cleanly

- OCE mediation: point estimates are vector-valued per nonbaseline exposure
  level. A Python oracle can be written, but R `mediation` is not a clean match.
  Recommend future custom Python plug-in tests for `tce_j`, `nde_j`, `nie_j`,
  `pm_j`, optional `cde_j`; use looser PM tolerances.
- `linexp`: estimand is tied to a one-unit linear exposure increase and package
  implementation details. Use custom Python only after confirming the exact
  Stata intervention construction; do not use R `mediation` as a definitive
  oracle.
- `specific` / `baseline()` + `alternative()`: clean with custom Python when
  exposure values are explicit; not clean with generic R mediation defaults.
- MSM summaries: Stata accepts an arbitrary `msm()` command and posts fitted MSM
  parameters. Cross-validate only after fixing one MSM formula and matching the
  simulated intervention-level dataset externally. Treat as a second-stage
  regression check, not a direct PO check.
- Stochastic interventions and dynamic regimes: package syntax supports dynamic
  flags and flexible intervention strings, but no simple off-the-shelf exact
  oracle was identified for this Stata implementation. Use bespoke Python DGPs.
- Survival / non-EOFU longitudinal outcomes: R `gfoRmula` is relevant, but exact
  comparison requires careful alignment of censoring, competing death, visit
  process, and survival scale. Start with EOFU before survival.
- `mlogit` and `ologit`: statsmodels has related categorical/ordinal tools, but
  category coding, thresholds, and random draw behavior are easy to mismatch.
  First validate point estimates with deterministic expected-value formulas;
  treat SE validation as follow-up.
- Imputation options: external validation must mirror the chained imputation
  cycles and random draws. Do not mix with first-line SE checks.

## Recommended Next QA Additions

1. Create a Python-generated CSV of bootstrap reference distributions for the
   existing `external_mediation_binary.csv`, `external_mediation_continuous.csv`,
   and `external_timevarying.csv` fixtures. Store one row per analysis/effect:
   point estimate, bootstrap SD, and optional percentile CI.
2. Add a Stata `crossval_external_se.do` that runs the same scenarios with
   `samples(499)` or `samples(999)` and asserts:
   - `e(b)` columns match Python point estimates within the point tolerances
   - `e(se)` and `sqrt(vecdiag(e(V)))` match Python bootstrap SDs within SE
     tolerances
   - convenience scalars such as `e(se_tce)` match `e(se)` columns
3. Keep R `mediation` comparison as a separate sanity test, not the hard SE
   gate.
4. Add one small OCE custom Python point-estimate fixture after OBE SEs pass.
   Do not block release on OCE SEs until vector naming and effect definitions
   are fully pinned down.
5. Defer MSM, survival, stochastic interventions, ordinal models, and imputation
   to targeted follow-up fixtures. They need bespoke oracles and should not be
   conflated with the clean OBE/EOFU SE gate.

## Bottom Line

The cleanest adversarial QA path is not to depend primarily on high-level R
causal packages. Use custom Python/statsmodels as the exact oracle for both
point estimates and bootstrap SEs in simple, fully specified OBE mediation and
EOFU time-varying scenarios. Use R `mediation` and `gfoRmula` for triangulation
and plausibility checks where their estimands align, but treat them as secondary
references unless their resampling and intervention contracts are explicitly
matched.
