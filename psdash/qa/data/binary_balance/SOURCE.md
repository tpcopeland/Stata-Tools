# Source data for the binary-balance published reproduction and parity suites

Raw files, byte-for-byte as downloaded. They are not vendored in this repository; see "How the suites obtain them" below.

| File | URL | Retrieved | Bytes | sha256 |
|---|---|---|---|---|
| `nsw_dw.dta` | https://users.nber.org/~rdehejia/data/nsw_dw.dta | 2026-11-17 | 28598 | `d1bd2680a1c6f799f1c6d2455bf29633fdf19be01cb19490621c20a560b4e072` |
| `cps_controls.dta` | https://users.nber.org/~rdehejia/data/cps_controls.dta | 2026-11-17 | 705546 | `80f0123eaf723870bd060ba9f8569617a7cb519a462dc20badbfb3443cd8374b` |

## What they are

The Dehejia-Wahba (1999, 2002) subsample of the National Supported Work (NSW) demonstration, as distributed from Rajeev Dehejia's academic page at the National Bureau of Economic Research.

- `nsw_dw.dta`: 445 observations, 185 trainees (`treat == 1`) and 260 experimental controls (`treat == 0`).
- `cps_controls.dta`: 15,992 observations, all `treat == 0`, the non-experimental CPS comparison group used by Imbens (2015, Table 16).

Variables: `treat`, `age`, `education`, `black`, `hispanic`, `married`, `nodegree`, `re74`, `re75`, `re78`.

## Licence and attribution

The distribution page, https://users.nber.org/~rdehejia/nswdata2.html (read 2026-11-17), states: "These data are distributed for attributable non-commercial use (CC by NC)", linking Creative Commons Attribution-NonCommercial 2.0 (https://creativecommons.org/licenses/by-nc/2.0/). The page asks users to cite these three papers:

1. Dehejia RH, Wahba S. Causal effects in non-experimental studies: reevaluating the evaluation of training programs. Journal of the American Statistical Association 1999;94(448):1053-1062.
2. Dehejia RH, Wahba S. Propensity score matching methods for non-experimental causal studies. Review of Economics and Statistics 2002;84:151-161.
3. LaLonde RJ. Evaluating the econometric evaluations of training programs with experimental data. American Economic Review 1986;76:604-620.

Data source page: https://users.nber.org/~rdehejia/nswdata2.html

These two `.dta` files are third-party data under CC BY-NC 2.0. They are **not** covered by the repository's MIT licence, and they may not be used commercially. They are not redistributed here and are not part of the installable package or the `.pkg`. The attribution above applies to any copy used for QA.

## How the suites obtain them

`_psdash_qa_extdata.do` (`_psdash_qa_extfile`) uses `$STATA_QA_DATA/psdash/binary_balance/<file>` when the `STATA_QA_DATA` environment variable names a local directory of third-party QA source data, and otherwise downloads the URL in the table above into a temporary file at test time (fetching a public source at run time is not redistribution). Either way the file must match the byte length and Stata `checksum` CRC recorded in the suites (`nsw_dw.dta` 28598 bytes, CRC 2283301062; `cps_controls.dta` 705546 bytes, CRC 2178836444), or the suite fails (r(459)); that also proves the source still serves the same data. When neither is available the suites exit 77 (dependency skip).

## Used by

- `crossval_binary_balance_published_imbens2015.do`: reproduces the printed normalized differences, means and standard deviations of Imbens (2015) Tables 10 and 16 (IZA DP 8049 pp. 57 and 60; the same tables appear in NBER w19959).
- `crossval_binary_balance_cobalt.do`: real-data parity against R cobalt with propensity-score weights fitted on these samples.

## Provenance check

`sha256sum nsw_dw.dta cps_controls.dta` on a local copy must print the values above. If the files are ever re-downloaded and the hashes differ, the published-reproduction targets must be re-verified before the suites are trusted.
