# FIPTIW interval calibration — 2026-07-23

## Decision

No tested interval passed the prespecified base-cell gate. Bare FIPTIW fits therefore return point estimates only: they launch no hidden bootstrap, display no standard errors, p-values, or confidence limits, and post no `e(V)`. Explicit nominal Wald, percentile, basic, and BCa inference remains available with a warning that it is empirically uncleared.

The rule was fixed before any candidate result was inspected: at `R=1000`, a candidate must have point coverage at least 0.92 and its 95% Wilson interval must contain 0.95. This corresponds to 937 through 963 covered datasets inclusive. If percentile and basic had both passed, percentile would have won because the two intervals have identical length, percentile is transformation invariant, and it is the operational choice in the closest current full-refit R implementations. BCa was added only after all no-extra-refit candidates failed and was judged by the same rule.

The positivity-stress experiment was conditional on finding a winner in the base cell. There was no winner, so no stress run was launched and no stress result is implied.

## Configuration and provenance

| Item | Base cell |
|---|---:|
| Family / truth | `fiptiw` / 1 |
| Subjects | 300 |
| Outer datasets | 1,000 |
| Full-refit draws per dataset | 999 |
| Master seed | 20260715 |
| Propensity slope multiplier | 1.0 |
| Blocks | 40 × 25 |
| Initial-candidate manifest | `64d8bcaf750cfe2b88c43abc7ece2edb5fc0a967c41008759f2041f0e70d63de` |
| Corrected-BCa manifest | `104a19ada49a4324c2a03a90798e6f16300a3e2d6211e559235484e379c6baad` |
| Git base | `23ef1d92dcb645aba7d5a3df2babd570811ddfa0` |

The working tree was dirty relative to the git base. The manifests, not the commit alone, identify the tested implementations. Both raw unions contained 1,000 uniquely keyed rows, tiled simulations 1–1,000 exactly, agreed on the requested draws/seed/stress stamps, and contained no failed or missing interval rows.

## Results

| Interval | Covered | Coverage | 95% Wilson | Mean length | Truth below / above | Gate |
|---|---:|---:|---:|---:|---:|---:|
| Wald | 914 | 0.914 | [0.8950, 0.9298] | 4.1628 | 45 / 41 | **FAIL** |
| Percentile | 924 | 0.924 | [0.9059, 0.9389] | 4.1545 | 44 / 32 | **FAIL** |
| Basic | 896 | 0.896 | [0.8755, 0.9134] | 4.1545 | 53 / 51 | **FAIL** |
| Bias-corrected | 914 | 0.914 | [0.8950, 0.9298] | 4.1480 | 45 / 41 | **FAIL** |
| BCa | 895 | 0.895 | [0.8745, 0.9125] | 4.2273 | 56 / 49 | **FAIL** |

Point estimator: mean 1.01707; bias +0.01707 (Monte Carlo SE 0.03918); empirical SD 1.23911; mean bootstrap SE 1.06195; SE/SD 0.85703; standardized-statistic SD 1.15564. The point-estimator bias is under half a Monte Carlo standard error; the failure is interval calibration.

The weights-known comparisons did not repair the problem: the analytic cluster sandwich covered 0.911 with mean SE 1.05927, and the fixed-weight bootstrap Wald interval covered 0.917. The mean fixed/refit SE ratio was 0.9994 (Monte Carlo SE 0.0016).

Bias correction `z0`: mean -0.004930, median -0.003764, 95th percentile 0.111890, mean absolute value 0.053517. Corrected BCa acceleration: mean 0.001379, median 0.001469, 95th percentile 0.076728, mean absolute value 0.029272. Percentile and basic lengths agreed to `3.55e-15`, as their algebra requires.

## BCa and studentization

An initial BCa run was rejected before it contributed to the decision. Stata's internal jackknife supplied the omitted subject as an `if` marker, but the nuisance-weight command accepts no `if` qualifier; the first wrapper therefore rebuilt weights on the full panel and applied deletion only to the outcome fit. Its acceleration was the fixed-weight jackknife (`-0.0272532`), not the independent full-refit value (`+0.00277042`).

After physically restricting a preserved copy to the jackknife marker and requesting double precision, Stata's acceleration (`0.0027704216095975`) matched the independent delete-one-subject calculation (`0.0027704216095963`) to machine precision. Only the fresh corrected run is reported above.

A second helper issue affected state, not the statistic: restoring the resampling frame invalidated the `e(sample)` binding posted inside the preserved copy. Reposting it after restore changed the direct helper's marked sample from zero to the full 668-row frame. An exact before/after comparison found no change in `e(b)`, `e(V)`, selected endpoints, or acceleration. The 1,000-dataset coverage manifest therefore remains the valid numerical evidence, while the post-run metadata-only repair is regression-pinned separately.

Studentized intervals were not run. They require an inner variance estimate for every one of the 999 bootstrap draws, making this already nested full-refit experiment substantially more expensive. BCa supplied the justified higher-order candidate without that extra nesting and failed clearly.

## Independent recomputation

`qa/tools/analyze_fiptiw_intervals.py` read the raw block files independently of the Stata combiner. It rejected wrong filenames/ranges, incomplete tiling, duplicate simulation keys, missing values, and mismatched draws/simulations/seed/sample/stress stamps before recomputing bias, Monte Carlo error, empirical SD, bootstrap SE, every coverage proportion and Wilson interval, interval length, directional misses, and the `z0`/acceleration distributions. Its values are the values in the table above.

The corrected-BCa raw union was also compared field by field with the initial-candidate union. All 31 common fields had identical simulation keys; every point-estimate, bootstrap, endpoint, coverage, and decision field was exact. Only `se_fix` differed, in 258 rows, with maximum absolute difference `1.3322676295501878e-15` and maximum scaled relative difference `1.099357623796657e-15`.

## Scope

This experiment assesses one correctly specified identity-link FIPTIW DGP at `n=300` with 999 subject-level full-refit draws. The separate prespecified sample-size diagnostic found Wald coverage 0.950 at `n=600` and 0.960 at `n=1200` (`R=200` each), which supports a finite-sample problem in this DGP but does not establish a universal sample-size cutoff. The point-only default avoids turning one simulation cell into a general 95% claim; it is not a claim that FIPTIW point estimates are invalid.
