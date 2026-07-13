*! _finegray_weight_groups Version 1.1.4  2026/07/13
*! Deterministic reconstruction of the IPCW weight strata
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: internal (creates caller-named group variables)

* Builds the two group variables the Mata engine indexes its weights by:
*
*   censoring strata   strata()       -> G is estimated within these groups
*   truncation strata  truncstrata()  -> H is estimated within these groups
*
* The engine cross-classifies them itself; only the OBSERVED (censoring,
* truncation) combinations become weight strata.
*
* WHY A SHARED HELPER.  finegray.ado, finegray_cif.ado, finegray_predict.ado and
* finegray_phtest.ado each need the SAME groups: estimation builds them, and every
* postestimation command must rebuild them IDENTICALLY or it silently computes
* weights for a different design than the one that was fitted.  Storing a temporary
* group variable in the data is not an option (it would not survive `preserve`,
* `drop`, or a saved dataset), so the group SPECIFICATION is stored in e() and the
* groups are rebuilt on demand -- here, in one place, by one rule.
*
* `egen group()` is deterministic given the same variables and the same sample:
* it orders by the variables' values, so identical inputs always yield identical
* codes.  That determinism is the contract this helper exists to hold.
*
* Caller supplies the names to create (tempvar names from the caller's scope), so
* the generated variables live in the CALLER, not here.

program define _finegray_weight_groups
    version 16.0
    syntax , [STRATA(varlist numeric) TRUNCstrata(varlist numeric) ///
              BYGname(name) TGname(name) TOUSE(varname numeric)]

    if "`touse'" == "" {
        tempvar touse
        quietly gen byte `touse' = 1
    }

    * --- censoring strata -> one numeric group variable
    if "`bygname'" != "" {
        capture confirm variable `bygname'
        if !_rc {
            display as error "_finegray_weight_groups: `bygname' already exists"
            exit 110
        }
        if "`strata'" == "" {
            quietly gen byte `bygname' = 1 if `touse'
        }
        else {
            quietly egen long `bygname' = group(`strata') if `touse'
        }
    }

    * --- truncation strata -> one numeric group variable
    if "`tgname'" != "" {
        capture confirm variable `tgname'
        if !_rc {
            display as error "_finegray_weight_groups: `tgname' already exists"
            exit 110
        }
        if "`truncstrata'" == "" {
            quietly gen byte `tgname' = 1 if `touse'
        }
        else {
            quietly egen long `tgname' = group(`truncstrata') if `touse'
        }
    }
end
