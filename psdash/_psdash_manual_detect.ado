*! _psdash_manual_detect Version 1.2.0  2026/06/14
*! Shared treatment-only detection for balance and weights
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper - rclass

program define _psdash_manual_detect, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax varname(numeric) [if] [in], [REFerence(string) ESTImand(string)]
        marksample touse

        quietly levelsof `varlist' if `touse', local(_man_levels)
        local K : word count `_man_levels'

        if `K' == 1 {
            display as error "treatment must have at least 2 levels"
            exit 198
        }
        if `K' == 0 error 2000

        local _is_bin01 = 0
        if `K' == 2 {
            local _l1 : word 1 of `_man_levels'
            local _l2 : word 2 of `_man_levels'
            if "`_l1'" == "0" & "`_l2'" == "1" local _is_bin01 = 1
        }

        if "`estimand'" == "" local estimand "ate"
        else {
            local estimand = strlower("`estimand'")
            if !inlist("`estimand'", "ate", "att", "atc") {
                display as error "estimand() must be ate, att, or atc"
                exit 198
            }
        }

        if `_is_bin01' {
            local multigroup "0"
            local mg_reference "0"
        }
        else {
            _psdash_validate_levels, levels(`_man_levels')
            local multigroup "1"
            if "`reference'" != "" {
                local _ref_ok = 0
                foreach _lv of local _man_levels {
                    if "`reference'" == "`_lv'" local _ref_ok = 1
                }
                if !`_ref_ok' {
                    display as error "reference(`reference') is not a treatment level"
                    display as error "  treatment levels: `_man_levels'"
                    exit 198
                }
                local mg_reference "`reference'"
            }
            else {
                local mg_reference : word 1 of `_man_levels'
            }
        }

        return local treatment "`varlist'"
        return local source "manual"
        return local estimand "`estimand'"
        return local multigroup "`multigroup'"
        return scalar K = `K'
        return local levels "`_man_levels'"
        return local reference "`mg_reference'"
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
