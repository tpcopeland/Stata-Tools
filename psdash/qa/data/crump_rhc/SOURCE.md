# crump_rhc: right heart catheterization data (SUPPORT study)

Source data for `crossval_crump_rhc_published_support.do` (not vendored in this repository; see "How the suite obtains it" below), which reproduces the
worked example of Crump, Hotz, Imbens and Mitnik (2009), "Dealing with limited
overlap in estimation of average treatment effects", Biometrika 96(1):187-199,
doi:10.1093/biomet/asn055, Section 4 (alpha-hat = 0.1026, Table 2).

| Item | Value |
|------|-------|
| File | `rhc.csv` (unmodified, as downloaded; not vendored) |
| URL | https://hbiostat.org/data/repo/rhc.csv |
| Retrieved | 2026-11-17 (HTTP 200) |
| Size | 2,320,412 bytes; 5735 rows x 63 columns (including the row-name column) |
| sha256 | `9ef4ab578be4b40ad5d97d3a7e08ffdc1f9f76aeeefee51b4996e4221556f8e8` |
| Original study | Connors AF et al. (1996) JAMA 276:889-897 (SUPPORT; Murphy and Cluff 1990) |
| Distributor | Vanderbilt Department of Biostatistics public dataset repository |
| Stata checksum | `checksum` CRC 2782662126, filelen 2320412 (asserted by the suite before use) |
| Licence / terms | https://hbiostat.org/data/ (checked 2026-11-17): "Permission is granted to anyone wishing to use the data sets provided here. Please reference the original paper which, for most data sets, is given in our notes linked below, and note 'Data obtained from http://hbiostat.org/data courtesy of the Vanderbilt University Department of Biostatistics.'" The grant covers use and does not explicitly mention redistribution, so this repository does not track the file. |
| Required attribution | Data obtained from http://hbiostat.org/data courtesy of the Vanderbilt University Department of Biostatistics. Original paper: Connors AF et al. (1996) JAMA 276:889-897. |

Cohort check against the paper: `swang1` = RHC 2184, No RHC 3551 (5735 patients),
exactly the sizes stated in Crump et al. Section 4.

## How the suite obtains it

The file is not distributed with this repository. `_psdash_qa_extdata.do` (`_psdash_qa_extfile`) uses `$STATA_QA_DATA/psdash/crump_rhc/rhc.csv` when the `STATA_QA_DATA` environment variable names a local directory of third-party QA source data, and otherwise downloads the URL above into a temporary file at test time (fetching a public source at run time is not redistribution). Either way the file must match the recorded length and Stata `checksum` CRC, or the suite fails (r(459)); that also proves the source still serves the same data. When neither is available the suite exits 77 (dependency skip).
