# gcomp

G-computation formula via Monte Carlo simulation for causal inference.

**Version**: 1.2.1
**Forked from**: SSC `gformula` v1.16 beta (Rhian Daniel, 2021)

## Overview

Implements Robins' parametric g-computation formula (Robins 1986) for:

- **Time-varying confounding**: Estimates causal effects of time-varying exposures on outcomes in the presence of time-varying confounders affected by prior exposure
- **Causal mediation**: Estimates total causal effects (TCE), natural direct effects (NDE), natural indirect effects (NIE), proportion mediated (PM), and controlled direct effects (CDE)

## Commands

| Command | Description |
|---------|-------------|
| `gcomp` | G-computation formula for causal inference and mediation |
| `gcomptab` | Export gcomp mediation results to publication-ready Excel |

## Installation

```stata
net install gcomp, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/gcomp/") replace
```

## Changes from SSC v1.16

### Bug fixes
1. **Hardcoded `by id:`** - Survival/death path now correctly uses `idvar()` variable
2. **Broken baseline auto-detect with `oce`** - Fixed backtick macro bug that silently produced wrong results
3. **Global macro pollution** - Eliminated `$maxid`, `$check_delete`, `$check_print`, `$check_save`, `$almost_varlist` globals

### Modernization
- Merged `gformula_.ado` into single file (no more separate bootstrap program)
- Replaced deprecated `uniform()` with `runiform()` and `invnormal(uniform())` with `rnormal()`
- Added `double` precision to all numeric `gen` statements
- Inlined `detangle`/`formatline`/`chkin` dependencies (no more `ice` package dependency)
- Added `version 16.0`, `set varabbrev off`, `set more off`
- Namespaced internal variables to prevent collisions

## References

- Robins JM (1986). A new approach to causal inference in mortality studies with a sustained exposure period. *Mathematical Modelling* 7:1393-1512.
- Daniel RM, De Stavola BL, Cousens SN (2011). gformula: Estimating causal effects in the presence of time-varying confounding or mediation using the g-computation formula. *The Stata Journal* 11(4):479-517.

## Credits

Original author: Rhian Daniel (LSHTM)
Fork maintainer: Timothy P Copeland (Karolinska Institutet)
