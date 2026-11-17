*! _qba_draw_checked Version 1.2.1  2026/11/17
*! Internal helper: draw a distribution and flag out-of-support values
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _qba_draw_checked
program define _qba_draw_checked, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , DIst(string) GEN(name) N(integer) INVALID(name) ///
            [LOWER(string) UPPER(string) LOWEROPEN UPPEROPEN ///
            U(varname numeric)]

        _qba_require_distributions
        if "`u'" != "" {
            _qba_draw_one, dist(`"`dist'"') gen(`gen') n(`n') u(`u')
        }
        else {
            _qba_draw_one, dist(`"`dist'"') gen(`gen') n(`n')
        }

        capture confirm variable `invalid'
        if _rc {
            quietly gen byte `invalid' = 0
        }

        * A missing draw is out of support for every parameter, including
        * those drawn with no finite bound (dist_rr(), dist_confeffect()).
        quietly replace `invalid' = 1 if missing(`gen')
        if "`lower'" != "" {
            if "`loweropen'" != "" {
                quietly replace `invalid' = 1 if `gen' <= `lower'
            }
            else {
                quietly replace `invalid' = 1 if `gen' < `lower'
            }
        }
        if "`upper'" != "" {
            if "`upperopen'" != "" {
                quietly replace `invalid' = 1 if `gen' >= `upper'
            }
            else {
                quietly replace `invalid' = 1 if `gen' > `upper'
            }
        }

        quietly count if `invalid' == 1
        return scalar n_invalid = r(N)

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
