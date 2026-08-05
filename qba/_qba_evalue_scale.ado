*! _qba_evalue_scale Version 1.1.1  2026/08/05
*! Internal helper: report which VanderWeele-Ding Table 2 scale an E-value used
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
The E-value formula in VanderWeele & Ding (2017) Table 1 takes a risk ratio.
Table 2 lists what must happen first for the other ratio measures. This
helper states which of those paths was taken, so the printed E-value is never
silently a rare-outcome approximation applied to a common-outcome estimate.
*/

capture program drop _qba_evalue_scale
program define _qba_evalue_scale
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , MEASure(string) CONV(string) RRUSED(real) [COMMON(string)]

        local measure = strupper("`measure'")
        local conv = strlower("`conv'")
        if !inlist("`conv'", "none", "sqrtor", "hrcommon") {
            display as error "conv() must be none, sqrtor, or hrcommon"
            exit 198
        }
        if "`conv'" == "sqrtor"   local formula "sqrt(OR)"
        if "`conv'" == "hrcommon" local formula "(1-0.5^sqrt(HR))/(1-0.5^sqrt(1/HR))"

        if "`conv'" == "none" {
            if inlist("`measure'", "RR", "IRR") {
                display as text "  Scale: `measure' used directly" ///
                    " (VanderWeele & Ding Table 2)"
                if "`common'" != "" {
                    display as text ///
                        "  Note: commonoutcome has no effect on a `measure'; no conversion is required"
                }
            }
            else {
                display as text "  Scale: `measure' used directly as a risk ratio;" ///
                    " Table 2 permits this only for a"
                display as text ///
                    "         rare outcome (<15% by end of follow-up). For a common outcome"
                display as text ///
                    "         specify commonoutcome; the E-value below is otherwise too large."
            }
        }
        else {
            display as text "  Scale: common-outcome `measure' converted to a risk ratio"
            display as text "         RR = `formula' = " as result %9.4f `rrused'
        }

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
