*! _psdash_mgps_map Version 1.0.2  2026/05/17
*! Build multi-group propensity score mapping
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper

program define _psdash_mgps_map, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , MULTIgroup(string) K(integer) LEVELS(string asis) ///
            TREATment(varname numeric) SAMPLEvar(varname) ///
            [PSVar(varname numeric) DETPSVars(varlist numeric) ///
             FALLBACKps(name) MARKout ALLOWEmpty]

        return clear
        local mg_psvars_all ""

        if "`multigroup'" != "0" {
            local n_group_ps = 0
            local idx = 1
            foreach lev of local levels {
                local this_ps : word `idx' of `detpsvars'
                if "`this_ps'" != "" {
                    return local group_ps_`lev' "`this_ps'"
                    local mg_psvars_all "`mg_psvars_all' `this_ps'"
                    local n_group_ps = `n_group_ps' + 1
                }
                local idx = `idx' + 1
            }

            if `n_group_ps' == 0 & `k' == 2 & "`psvar'" != "" {
                if "`fallbackps'" == "" {
                    if "`allowempty'" != "" {
                        local mg_psvars_all "`psvar'"
                    }
                    else {
                        display as error "internal error: fallback propensity score variable required"
                        exit 498
                    }
                }
                else {
                    local first_level : word 1 of `levels'
                    local second_level : word 2 of `levels'
                    quietly gen double `fallbackps' = 1 - `psvar' if `samplevar'
                    return local group_ps_`first_level' "`fallbackps'"
                    return local group_ps_`second_level' "`psvar'"
                    local mg_psvars_all "`fallbackps' `psvar'"
                    local n_group_ps = `k'
                }
            }
            else if `n_group_ps' != `k' {
                if "`allowempty'" != "" & `n_group_ps' == 0 {
                    if "`psvar'" != "" {
                        local mg_psvars_all "`psvar'"
                    }
                    else {
                        local mg_psvars_all ""
                    }
                }
                else {
                    display as error "internal error: multigroup propensity score mapping incomplete"
                    exit 498
                }
            }

            local mg_psvars_all : list uniq mg_psvars_all
            if "`markout'" != "" {
                if "`mg_psvars_all'" != "" {
                    markout `samplevar' `treatment' `mg_psvars_all'
                }
                else {
                    markout `samplevar' `treatment'
                }
            }
        }
        else if "`markout'" != "" {
            if "`psvar'" != "" {
                markout `samplevar' `treatment' `psvar'
            }
            else {
                markout `samplevar' `treatment'
            }
        }

        return local mg_psvars_all "`mg_psvars_all'"
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
