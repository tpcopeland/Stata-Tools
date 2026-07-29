# Cross-validation tolerance framework

Tolerances in `crossval_tabtools.do` reflect the numerical path being compared,
not a blanket package-wide threshold.

| Tolerance | Intended use |
|---:|---|
| `1e-12` | Same-sample identities and equivalent Stata calculations |
| `1e-10` | Closed-form double-precision arithmetic and probabilities |
| `1e-8` | Transformed quantities with a few floating-point operations |
| `1e-6` | Confidence limits and other transcendental transformations |
| `1e-4` | Large-magnitude interval bounds where absolute error is the clearer contract |
| `0.001` | SMD comparisons based on seeded generated samples |
| `0.01` | ESS and RMST point/SE comparisons |
| `0.05` | RMST interval bounds and cross-implementation GEE QICu differences |

Rendered values use a rounding-aware bound instead of a computational bound.
For example, a displayed three-decimal probability is checked within
`0.00051`, just over half one unit in the last displayed place.

All 95% confidence-interval oracles use the exact
`invnormal(0.975)`/`qnorm(0.975)` quantile. The literal value `1.96` appears
only as an input in CV14, where the conversion of an arbitrary z statistic is
the quantity under test.

Tolerances may be widened only with a documented numerical reason and a
boundary test showing that a materially wrong result still fails.
