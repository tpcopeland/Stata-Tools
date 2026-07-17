*! _msm_restore_order Version 1.2.3  2026/07/17
*! Restore observation order from a temporary sequence variable
*! Author: Timothy P Copeland
*! Program class: utility

/*
Syntax:
  _msm_restore_order ordervar

The helper is intentionally a no-op when ordervar no longer exists, as can
happen after a caller restores a preserved dataset. Otherwise, failure to sort
or remove the marker is propagated to the caller instead of being silently
discarded during footer cleanup.
*/

program define _msm_restore_order
    version 16.0
    args ordervar

    if strtrim("`ordervar'") == "" {
        display as error "order variable is required"
        exit 198
    }

    capture confirm variable `ordervar'
    if _rc exit 0

    sort `ordervar'
    drop `ordervar'
end
