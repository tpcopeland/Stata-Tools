*! _tabtools_fmt_p Version 2.6.1  2026/10/09
*! regtab's p-value display rule, vectorised, for tabcell and its callers
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
The rule is copied line for line from regtab.ado (the block after
"Format p-values using pdp/highpdp"), which is the package authority for
p-value text:

    p < 10^-pdp or p == 0      "<0.001"            (pdp = 3)
    10^-pdp <= p < 0.10        %(pdp+2).(pdp)f     ("0.050")
    p >= 0.10                  %(highpdp+2).(highpdp)f
    1 - 10^-highpdp < p < 1    ">0.99"             (highpdp = 2)
    a leading "." gains a "0"

Do not edit one copy without the other; qa/test_tabcell_v230.do pins the
two against each other over a grid of p-values.

Usage: _tabtools_fmt_p pvar [if] [in], generate(newstrvar) [pdp(#) highpdp(#)]
Rows outside the sample, and missing p, are left "".
*/

capture program drop _tabtools_fmt_p
program define _tabtools_fmt_p, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname(numeric) [if] [in], GENerate(name) ///
            [PDP(integer 3) HIGHPDP(integer 2)]
        if `pdp' < 1 | `pdp' > 10 {
            display as error "pdp() must be between 1 and 10"
            exit 198
        }
        if `highpdp' < 1 | `highpdp' > 10 {
            display as error "highpdp() must be between 1 and 10"
            exit 198
        }
        marksample touse, novarlist
        confirm new variable `generate'
        local z `varlist'
        local _pmin = 10^(-`pdp')
        local _pmax = 1 - 10^(-`highpdp')
        local _pfmt_lo = "%`=`pdp'+2'.`pdp'f"
        local _pfmt_hi = "%`=`highpdp'+2'.`highpdp'f"
        quietly {
            gen str20 `generate' = ""
            replace `generate' = "<" + string(`_pmin', "`_pfmt_lo'") if `z' < `_pmin' & !missing(`z') & `touse'
            replace `generate' = string(`z', "`_pfmt_lo'") if `z' >= `_pmin' & `z' < 0.10 & !missing(`z') & `touse'
            replace `generate' = string(`z', "`_pfmt_hi'") if `z' >= 0.10 & !missing(`z') & `touse'
            replace `generate' = ">" + string(`_pmax', "`_pfmt_hi'") if `z' > `_pmax' & `z' < 1 & !missing(`z') & `touse'
            replace `generate' = "<" + string(`_pmin', "`_pfmt_lo'") if `z' == 0 & !missing(`z') & `touse'
            replace `generate' = "0" + `generate' if substr(`generate', 1, 1) == "." & `touse'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
