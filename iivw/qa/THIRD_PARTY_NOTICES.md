# Third-party data notices (iivw QA)

These QA files contain or are derived from third-party data distributed under an open licence. They are QA inputs only: none is in `iivw.pkg`, so `net install` does not deliver them. Third-party data whose terms do not clearly allow redistribution (NHEFS) is not tracked here; see `data/nhefs/SOURCE.md`.

## Phenobarb (R package nlme)

| Item | Value |
|------|-------|
| Files | `phenobarb_prepared.csv`, `phenobarb_cox_data.csv`, `phenobarb_parity_entry_weights.csv` (data rows and per-row weights); `phenobarb_cox_coefs.csv`, `phenobarb_parity_coefs.csv`, `phenobarb_parity_entry_coefs.csv` (model estimates computed from those rows) |
| Original data | `Phenobarb`, R package `nlme` 3.1-171 (Pinheiro J, Bates D, DebRoy S, Sarkar D, R Core Team) |
| Licence | GNU General Public License, version 2 or (at your option) any later version, as `nlme` declares (`GPL (>= 2)`). Full text: `licenses/GPL-2.txt` |
| Original source | Grasela TH, Donn SM (1985). Neonatal population pharmacokinetics of phenobarbital derived from routine clinical data. *Developmental Pharmacology and Therapeutics* 8:374-383; as distributed in Pinheiro JC, Bates DM (2000), *Mixed-Effects Models in S and S-PLUS*, Springer, Appendix A.23 |
| Modifications | By `crossval_irreglong.R`, following the R package `IrregLong` 0.4.1 Phenobarb vignette: rows restricted to concentration measurements before 16 days (384 hours); an event indicator, lagged time and concentration, a visit counter and IrregLong inverse-intensity weights added; columns selected and renamed |
| Regeneration | `Rscript crossval_irreglong.R` (needs `nlme`, `IrregLong`, `survival`) |

These files are distributed under the same licence, GPL-2 or later. Absence of any warranty: see sections 11 and 12 of `licenses/GPL-2.txt`.
