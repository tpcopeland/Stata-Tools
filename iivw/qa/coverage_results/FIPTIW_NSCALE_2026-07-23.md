# FIPTIW sample-size diagnostic — 2026-07-23

This is the preregistered P1 diagnostic from `qa/COVERAGE_MATRIX_PLAN.md`: does
the FIPTIW coverage shortfall observed at `n=300` shrink with sample size? It is
**not a new release gate**. The two added cells use 200 outer replications, not
the gate's 1,000, and they must not be relabelled as coverage validation for all
FIPTIW settings.

## Configuration and provenance

| Item | Value |
|---|---|
| Family / DGP | `fiptiw`, strong-dependence arm `(gamma1,gamma2)=(0.6,0.3)`, truth 1 |
| Added sample sizes | `n=600`, `n=1200` |
| Outer / inner replications | `R=200` per added cell; 999 bootstrap draws per outer dataset |
| Master seed | `20260715` |
| Sharding | 8 disjoint blocks of 25 outer replications per cell |
| Base manifest digest | `79ff4b2839867d678c15da66093827ca3301858773a11ecdf4f1de1259d0fa06` |
| Numerical estimator | Same point-estimation and bootstrap code as the 2026-07-22 gate; the work-copy differences were release version/status/warning text plus the coverage driver's `blk_nsub` provenance stamp |
| Completion record | 16/16 blocks reported `OK`; no failed outer draw |

The `n=600` blocks predate the `blk_nsub` stamp. They are therefore diagnostic
evidence only: all 200 rows carry `nsub=600`, tile simulations 1–200 exactly,
and have no duplicate `(arm,sim)` key, but the current gate combiner correctly
refuses to certify them. The `n=1200` blocks carry `blk_nsub=1200` as well as
`blk_reps=999`, `blk_sims=1000`, `blk_seed=20260715`, and `arm=3`; those blocks
also tile 1–200 exactly with no duplicate key. The 1,000-row `n=300` result is
the original gate cell recorded in `RESULT_2026-07-22.md`.

## Results

| n | R | bias (MCSE) | empirical SD | mean refit SE | SE / empirical SD | refit coverage | 95% Wilson | standardized SD |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 300 | 1,000 | +0.0171 (0.0392) | 1.2391 | 1.0620 | 0.857 | 0.914 | [0.895, 0.930] | 1.156 |
| 600 | 200 | -0.0072 (0.0519) | 0.7345 | 0.7391 | 1.006 | 0.950 | [0.910, 0.973] | 1.021 |
| 1,200 | 200 | +0.0335 (0.0419) | 0.5920 | 0.5636 | 0.952 | 0.960 | [0.923, 0.980] | 1.003 |

The point estimate remains compatible with zero bias at every sample size. The
standardized statistic is over-dispersed at `n=300` and approximately unit-scale
at both larger sample sizes. The fixed analytic and fixed-weight-bootstrap
methods also move toward calibration as `n` grows, but neither is a principled
replacement for the nuisance-refitting bootstrap.

| n | fixed coverage | fixed-weight bootstrap coverage | naive coverage |
|---:|---:|---:|---:|
| 300 | 0.911 | 0.917 | 0.489 |
| 600 | 0.945 | 0.960 | 0.175 |
| 1,200 | 0.970 | 0.970 | 0.025 |

## Interpretation

The observed pattern supports a **finite-sample calibration problem in this
package-representable DGP**, not a variance deficit that persists as sample size
increases. This is consistent with the source paper's own finite-sample evidence:
Coulombe et al. Table A.3 reports bootstrap coverage of 93.2%–96.3% at `n=250`
across its original DGP cells, including 95.5% in the closest strong-dependence
cell. It is not a contradiction because this QA adaptation makes `Z`
subject-constant, creating a stronger subject-level residual component.

These diagnostics do **not** establish `n=600` as a universal safe cutoff. They
cover one correctly specified identity-link DGP, and each added cell has only
200 outer replications. Weak positivity, model misspecification, nonlinear links,
and few-cluster settings remain separate questions. The shipped contract should
therefore continue to report the measured `n=300` undercoverage and should not
claim generally validated FIPTIW nominal intervals. An ad hoc SE multiplier or a
post-hoc ESS cutoff is not licensed by these results.

## Independent recomputation

The numbers above were recomputed directly from the raw block `.dta` files in
Python, separately from Stata's `_inf_engine` aggregation. The recomputation
verified block count, row count, exact 1–200 tiling, duplicate keys, configuration
stamps, bias, MCSE, empirical SD, mean SE, coverage, Wilson limits, and the
standardized-statistic SD. This is an independent code path, not independent
review: the final release still requires reviewer signoff from someone other
than the implementation/audit agent.
