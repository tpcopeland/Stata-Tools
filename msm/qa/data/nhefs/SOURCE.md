# nhefs: NHEFS teaching extract (Hernán and Robins, Causal Inference: What If)

Source data for `msm/qa/validation_msm.do` (Part A, Hernán-Robins chapter 12 IPTW, and the person-period example) and `msm/qa/crossval_msm_nhefs.do` (R `ipw::ipwpoint`/`survey` parity).

| Item | Value |
|------|-------|
| File | `nhefs.dta` (unmodified, as downloaded) |
| URL | https://miguelhernan.org/s/nhefs.dta (linked from https://miguelhernan.org/whatifbook) |
| Retrieved | 2026-11-17 (HTTP 200; byte-identical to the copy previously tracked in Stata-Tools) |
| Size | 844,532 bytes; 1,629 subjects, one row per subject |
| sha256 | `2a095f38d38ef769767a021dfc54b4b7b3fe056b71894404c5fe6ff1572b3bf2` |
| md5 | `3dfc7dc06acb9d2b565bebb63874174a` |
| Stata checksum | `checksum` CRC 3078715963, filelen 844532 (asserted by the suite before use) |
| Original study | National Health and Nutrition Examination Survey I Epidemiologic Follow-up Study (NHEFS), NCHS |
| Distributor | Miguel Hernán, book website for Hernán MA, Robins JM (2020). *Causal Inference: What If*. Boca Raton: Chapman & Hall/CRC |
| Licence / terms | No licence is stated on the book page (checked 2026-11-17); the data are offered as a free download for use with the book, and earlier project notes recorded them as "public, non-commercial teaching use". Redistribution is not explicitly granted, so the file is not tracked in Stata-Tools. |
| Required attribution | Hernán MA, Robins JM (2020). Causal Inference: What If. Data from https://miguelhernan.org/whatifbook. |

Without `STATA_QA_DATA`, the suite downloads this file from the URL at run time and verifies the same length and CRC; it fails (error 601) when neither route is available.
