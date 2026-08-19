# Cross-validation module map

`crossval_tabtools.do` regenerates its R reference data on every run, verifies
the regenerated files byte-for-byte against all four tracked fixtures, and
then exercises both formula-level and public-command contracts.

| Cross-validation block | Package surface | Independent oracle |
|---|---|---|
| CV1 | `corrtab` correlation p-values | Base R `pt()` |
| CV5–CV7 | `table1_tc` continuous/categorical SMD and Kish ESS | Seeded R data plus base R matrix/statistical operations |
| CV8–CV10, CV15–CV17 | `regtab` AIC/BIC, ICC, variance transformation, and median odds ratio | Base R arithmetic and `qnorm()` |
| CV11, CV20 | `stratetab` incidence-rate ratio and confidence interval | Base R arithmetic and `qnorm()` |
| CV12–CV13 | `survtab` survival difference and RMST uncertainty | Base R arithmetic over a fixed survival curve |
| CV14 | `table1_tc` z-to-p conversion | Base R `pnorm()` |
| CV19 | `crosstab` weighted trend and Cochran–Armitage statistics | Explicitly expanded data after filtering nonpositive/missing fweights |
| CV21 | `regtab` AIC/BIC across model families | Stata `estat ic` |
| CV22 | `regtab` ICC across link functions | Stata `estat icc` |
| CV23 | `regtab` fixed-scale GEE QICu | Python `statsmodels`; same-data model differences remove implementation-specific additive constants |

The R companion is `crossval_tabtools_companion.R`. The Python QICu oracle is
`tools/crossval_qicu.py`. Neither calls tabtools code. Public-command bridges in
CV1–CV20 prevent a correct standalone formula from masking an incorrect
package mapping.

Tracked R fixtures live in `data/`. `tools/verify_crossval_generation.py`
requires all four regenerated files to match; a missing R runtime, missing
Python dependency, missing fixture, or comparison mismatch is a failure rather
than a skip.
