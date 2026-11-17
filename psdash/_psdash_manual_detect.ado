*! _psdash_manual_detect Version 1.9.2  2026/11/18
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

        * RB-06: atc has no unique control arm once there are K>2 arms.
        if "`estimand'" == "atc" & `K' > 2 {
            display as error "estimand(atc) is not uniquely defined for a multi-valued treatment (K=`K')"
            display as error "  use estimand(att) with reference() to target a named arm"
            exit 198
        }

        if `_is_bin01' {
            * Binary 0/1 formulas fix level 0 as the reference (control) arm:
            * refuse any other reference() rather than ignore it.
            if !inlist("`reference'", "", "0") {
                if "`reference'" == "1" {
                    display as error "reference(1) is not supported for a treatment coded 0/1"
                    display as error "  binary 0/1 diagnostics use level 0 as the reference (control) arm."
                    display as error "  To make level 1 the reference, recode the treatment, e.g."
                    display as error "  {cmd:gen byte t = 1 - `varlist'}."
                }
                else {
                    display as error "reference(`reference') is not a treatment level"
                    display as error "  treatment levels: 0 1"
                }
                exit 198
            }
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
