*! _gcomp_check_categorical Version 2.0.2  2026/09/30
*! Refuse categorical intervention values absent from the original analytic data
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _gcomp_check_categorical
program define _gcomp_check_categorical
    version 16.0
    tempname caller_r
    _return hold `caller_r'
    local original_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname(numeric) [if] [in], LEVELS(string) [CONTEXT(string) LABEL(name)]
        marksample touse, novarlist
        tempvar supported
        quietly generate byte `supported' = 0 if `touse' & !missing(`varlist')
        foreach level of local levels {
            quietly replace `supported' = 1 if `touse' & `varlist' == `level'
        }
        quietly count if `touse' & !missing(`varlist') & `supported' != 1
        local unsupported = r(N)
        if `unsupported' {
            if "`label'" == "" local label "`varlist'"
            noisily display as error "`context': `label' has `unsupported' value(s) outside observed categorical support"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `original_varabbrev'
    _return restore `caller_r'
    if `rc' exit `rc'
end
