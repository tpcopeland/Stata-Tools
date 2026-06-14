*! _psdash_pscheck Version 1.3.0  2026/06/14
*! Validate propensity score ranges and positivity warnings
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper

program define _psdash_pscheck, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varlist(numeric min=1) [if] [in], ///
            [SAMPLEvar(varname) WARNvar(varname numeric) ///
             NEARMessage(string asis) ADVice(string asis) NOWARN]

        return clear
        if `"`advice'"' != "" & `"`nearmessage'"' == "" {
            local nearmessage `"`advice'"'
        }

        if "`samplevar'" == "" {
            tempvar _sample
            marksample _sample
            local samplevar "`_sample'"
        }
        else if `"`if'`in'"' != "" {
            tempvar _ifin_sample _sample
            marksample _ifin_sample
            quietly gen byte `_sample' = (`samplevar') & (`_ifin_sample')
            local samplevar "`_sample'"
        }

        foreach psv of local varlist {
            quietly summarize `psv' if `samplevar'
            if r(min) < 0 | r(max) > 1 {
                display as error "propensity scores must be in [0,1]"
                exit 198
            }
        }

        local n_ps_boundary = 0
        local n_ps_near = 0
        if "`nowarn'" == "" {
            if "`warnvar'" == "" {
                local warnvar : word 1 of `varlist'
            }
            quietly count if (`warnvar' == 0 | `warnvar' == 1) & `samplevar'
            local n_ps_boundary = r(N)
            if `n_ps_boundary' > 0 {
                display as error "warning: `n_ps_boundary' observations have PS exactly 0 or 1"
                display as error "  IPTW weights are undefined at these values"
            }
            quietly count if (`warnvar' < 0.01 | `warnvar' > 0.99) & `samplevar' ///
                & `warnvar' != 0 & `warnvar' != 1
            local n_ps_near = r(N)
            if `n_ps_near' > 0 {
                if `"`nearmessage'"' == "" {
                    local nearmessage "consider {cmd:psdash support, crump} or {cmd:psdash support, threshold(0.05)}"
                }
                display as text "note: `n_ps_near' additional observations have PS < 0.01 or > 0.99"
                display as text "  `nearmessage'"
            }
        }

        return scalar n_ps_boundary = `n_ps_boundary'
        return scalar n_ps_near = `n_ps_near'
        return scalar n_ps_near_boundary = `n_ps_near'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
