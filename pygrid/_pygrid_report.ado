*! _pygrid_report Version 1.0.2  2026/10/13
*! Display compact pygrid and pyattach reports
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _pygrid_report
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , MODE(string) N1(real) N2(real) N3(real) N4(real) TOTAL(real) ///
            [ AXIS(string) CONVENTION(string) ]

        if "`mode'" == "build" {
            display as text "pygrid: " as result strtrim(string(`n1', "%15.0fc")) ///
                as text " persons, " as result strtrim(string(`n2', "%15.0fc")) as text " period rows"
            display as text "  empty windows: " as result strtrim(string(`n3', "%15.0fc")) ///
                as text "   partial periods: " as result strtrim(string(`n4', "%15.0fc"))
            display as text "  person-time: " as result strtrim(string(`total', "%14.6g")) ///
                as text "   axis: " as result "`axis'" ///
                as text "   convention: " as result "`convention'"
        }
        else {
            display as text "pyattach: " as result strtrim(string(`n1', "%15.0fc")) ///
                as text " eligible events, " as result strtrim(string(`n2', "%15.0fc")) as text " attached"
            display as text "  orphans: " as result strtrim(string(`n3', "%15.0fc")) ///
                as text "   zero-event grid rows: " as result strtrim(string(`n4', "%15.0fc"))
            display as text "  overall event rate: " as result strtrim(string(`total', "%14.6g"))
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
