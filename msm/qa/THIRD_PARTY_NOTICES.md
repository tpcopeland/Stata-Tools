# Third-party data notices (msm QA)

These QA files contain third-party data distributed under an open licence. They are QA inputs only: none is in `msm.pkg`, so `net install` does not deliver them. Third-party data whose terms do not clearly allow redistribution (NHEFS) is not tracked here; see `data/nhefs/SOURCE.md`.

## haartdat (R package ipw)

| Item | Value |
|------|-------|
| Files | `data/haartdat.dta` |
| Original data | `haartdat`, R package `ipw` 1.3.0 (Hung Thai Tran, Willem M. van der Wal, Ronald B. Geskus); simulated teaching data documented in van der Wal WM, Geskus RB (2011). ipw: an R package for inverse probability weighting. *Journal of Statistical Software* 43(13):1-23, doi:10.18637/jss.v043.i13 |
| Licence | MIT (`MIT + file LICENSE`, as `ipw` declares). Copyright notice and permission notice: `licenses/MIT-ipw.txt` |
| Modifications | None to rows or values; exported from R to Stata format |

Copyright (c) 2026, ipw authors. The full MIT permission notice in `licenses/MIT-ipw.txt` applies to `data/haartdat.dta`.
