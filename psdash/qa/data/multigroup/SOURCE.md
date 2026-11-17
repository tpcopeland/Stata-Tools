# Source of the multigroup fixtures

Used by `qa/crossval_multigroup_published_twang.do`. The printed-table CSVs below are tracked here; `aod_twang_ate_weights.csv` (rows of twang's AOD dataset plus weights, GPL-3 third-party data) is not vendored in this repository; see "How the suite obtains the weights fixture" below.

| Item | Value |
|------|-------|
| Package | R `twang` 2.6.2 (Burgette, Griffin, McCaffrey, Ridgeway, Cefalu, et al.), CRAN |
| URL | https://cran.r-project.org/package=twang |
| Retrieved | 2026-11-17 (installed from CRAN; vignette read from the installed `twang/doc/mnps.pdf`) |
| Licence | GPL-3 (twang `DESCRIPTION`: `License: GPL-3 \| file LICENSE`); the AOD data ship with the package under the same licence |
| Vignette | Burgette L, Griffin BA, McCaffrey D. Propensity scores for multiple treatments: A tutorial for the mnps function in the twang package. RAND Corporation, December 22, 2025. No DOI located; cite as the package vignette. It applies McCaffrey DF, Griffin BA, Almirall D, Slaughter ME, Ramchand R, Burgette LF. Stat Med 2013;32(19):3388-3414, doi:10.1002/sim.5753, to a 600-youth subset of the data |
| Data | `twang::AOD`: 600 youth, 200 each in `community` / `metcbt5` / `scy`; covariates `illact crimjust subprob subdep white` |

## Files

| File | What it is | sha256 |
|------|-----------|--------|
| `aod_twang_ate_weights.csv` | Frozen output (not vendored; 58045 bytes, Stata `checksum` CRC 3078753458) of `qa/_multigroup_reference_twang.R` (`set.seed(1)`, `mnps(treat ~ illact + crimjust + subprob + subdep + white, estimand = "ATE", stop.method = c("es.mean", "ks.mean"), n.trees = 3000)`): `treat`, `tnum` (0/1/2 = community/metcbt5/scy), the five covariates, and `get.weights()` for each stopping rule (`w_es`, `w_ks`). Frozen so GBM or RNG drift cannot change psdash inputs. | `76c7184e936409148e44c5f95bdd3ec2714f99eead3a706c2f66488ed55fdef6` |
| `twang_mnps_aod_baltable_printed.csv` | Printed `bal.table(mnps.AOD, digits = 2)`, rows 1-45 (vignette sec. 2.3, pp. 10-12), hand-transcribed and re-parsed from the PDF text layer (45 of 45 rows identical). Row 1-15 unw, 16-30 es.mean, 31-45 ks.mean. | `026e3cb3055298472b10643ef6c5ece661f9c9e0baddf7351ac7688aab5c0712` |
| `twang_mnps_aod_baltable_3digit_printed.csv` | Printed 3-decimal subsets of `bal.table` (`subset.treat`/`subset.var` call, p. 13; `es.cutoff = 0.1` call, p. 14): 14 distinct rows, keyed by the full-table row number. Parsed from the PDF text layer. | `be741aa845600268fad571a9b2e791b60dc204237d99cfa82d0582e2e564e4a9` |
| `twang_mnps_aod_covariate_ks_printed.csv` | Printed `bal.table(mnps.AOD, collapse.to = 'covariate', digits = 4)`, 15 rows (vignette p. 12). Parsed from the PDF text layer. | `58456cc1772fb408646858123457867ad8b97dd039bac1ddda17fea0363b7971` |
| `twang_mnps_aod_summary_printed.csv` | Printed `summary(mnps.AOD)` (vignette p. 14): `max.std.eff.sz`, `min.p`, `max.ks`, `min.ks.pval` per stopping rule, and the ESS table. | `17431fafeb85cb809d5bae3d6b63ece5f2a34187c12eeb627337fd215d9c8ed6` |
| vignette PDF (not vendored) | `twang/doc/mnps.pdf` | `839361b844cad23f473d09dfbbbf4955c6599aec8d2630f8036eeadfbd1df534` |

## How the suite obtains the weights fixture

`_psdash_qa_extdata.do` (`_psdash_qa_extfile`) uses `$STATA_QA_DATA/psdash/multigroup/aod_twang_ate_weights.csv` when the `STATA_QA_DATA` environment variable names a local directory of third-party QA source data (a local directory not distributed with this repository), and otherwise regenerates it with `Rscript qa/_multigroup_reference_twang.R <outdir>` in a temporary directory when R and twang 2.6.2 are available. Either way the file must match the recorded length and CRC (sha256 above), or the suite fails (r(459)). A regenerated file is thereby proved byte-identical to the frozen original, so the suite does not compare it with itself; it still checks the regenerated `summary()` against the printed vignette values. When neither source is available the suite exits 77 (dependency skip).

The journal article's own Table 3 is not reproducible: it uses non-public CSAT/GAIN data (N 444/2459/1351, 23 covariates),
while AOD is a 5-covariate subset whose arm shares of non-Hispanic white (0.160/0.200/0.175) differ from Table 3.
