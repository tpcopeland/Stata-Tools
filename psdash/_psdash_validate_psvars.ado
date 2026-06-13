*! _psdash_validate_psvars Version 1.2.0  2026/06/14
*! Validate multi-group propensity-score variable lists
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

program define _psdash_validate_psvars, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax varlist(numeric), levels(string asis) k(integer) [SAMPLEvar(varname)]

        local psvars "`varlist'"
        _psdash_validate_levels, levels(`levels')
        local _n_psvars : word count `psvars'
        if `_n_psvars' != `k' {
            display as error "psvars() requires `k' variables (one per treatment level)"
            display as error "  treatment levels: `levels'"
            display as error "  psvars provided: `_n_psvars'"
            exit 198
        }

        local _ps_idx = 1
        foreach _lv of local levels {
            local _ps_v : word `_ps_idx' of `psvars'
            return local ps_`_lv' "`_ps_v'"
            local _ps_idx = `_ps_idx' + 1
        }

        tempvar _psv_sum _psv_complete
        local _sv_cond "1"
        if "`samplevar'" != "" local _sv_cond "`samplevar'"
        quietly {
            gen double `_psv_sum' = 0 if `_sv_cond'
            gen byte `_psv_complete' = 1 if `_sv_cond'
        }

        local _bad_psvar ""
        local _bad_range = 0
        foreach _ps_v of local psvars {
            quietly count if `_sv_cond' & !missing(`_ps_v') ///
                & (`_ps_v' < 0 | `_ps_v' > 1)
            if r(N) > 0 & `_bad_range' == 0 {
                local _bad_psvar "`_ps_v'"
                local _bad_range = r(N)
            }
            quietly replace `_psv_complete' = 0 ///
                if `_sv_cond' & missing(`_ps_v')
            quietly replace `_psv_sum' = `_psv_sum' + `_ps_v' ///
                if `_sv_cond' & !missing(`_ps_v')
        }

        if `_bad_range' > 0 {
            display as error "propensity scores must be in [0,1]"
            display as error "  invalid values found in `_bad_psvar'"
            exit 198
        }
        quietly count if `_sv_cond' & `_psv_complete' ///
            & abs(`_psv_sum' - 1) > 1e-6
        if r(N) > 0 {
            display as error "psvars() probabilities must sum to 1 within each observation"
            display as error "  offending complete rows: " r(N)
            exit 198
        }

        gettoken _first_psv _rest_psv : psvars
        return local first_psvar "`_first_psv'"
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
