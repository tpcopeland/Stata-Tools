# Third-party data notices (finegray QA)

These QA files contain third-party data distributed under an open licence. They are QA inputs only: none is in `finegray.pkg`, so `net install` does not deliver them.

## bce and center (R package crrSC)

| Item | Value |
|------|-------|
| Files | `oracles/public_studies/6f6e50b781cf065f/001_public_studies.csv` (rows of `bce`, 200, and `center`, 400); `oracles/public_studies/6f6e50b781cf065f/002_public_studies_oracle.csv` (`crrSC::crrs` estimates computed from those rows) |
| Original data | `bce` (breast cancer data randomly generated after the E1178 clinical trial; the help page spells it "El178") and `center` ("random sub sample of 400 patients", multicenter bone marrow transplantation data), R package `crrSC` 1.1.2 (Bingqing Zhou, Aurelien Latouche) |
| Licence | GNU General Public License, version 2 (`GPL-2`, as `crrSC` declares). Full text: `licenses/GPL-2.txt` |
| Modifications | By `crossval_public_studies_r.R`: selected columns mapped to `time`, `status`, `stratum`, `x1`-`x3` (`bce`: `time`, `type`, `trt`, log of `nnodes`, `tsize`, `age`; `center`: `ftime`, `fstatus`, `id`, `fm`, `cells`, and `x3` missing), and the two datasets stacked with a `dataset` column |
| Regeneration | The oracle cache records the generator and toolchain in `PROVENANCE.txt` beside the files |

These files are distributed under the same licence, GPL-2. Absence of any warranty: see sections 11 and 12 of `licenses/GPL-2.txt`.
