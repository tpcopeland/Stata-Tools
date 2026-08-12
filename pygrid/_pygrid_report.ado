*! _pygrid_report Version 1.0.0  2026/08/12
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
            display as text "pygrid: " as result %12.0fc `n1' ///
                as text " persons, " as result %12.0fc `n2' as text " period rows"
            display as text "  empty windows: " as result %12.0fc `n3' ///
                as text "   partial periods: " as result %12.0fc `n4'
            display as text "  person-time: " as result %14.6g `total' ///
                as text "   axis: " as result "`axis'" ///
                as text "   convention: " as result "`convention'"
        }
        else {
            display as text "pyattach: " as result %12.0fc `n1' ///
                as text " eligible events, " as result %12.0fc `n2' as text " attached"
            display as text "  orphans: " as result %12.0fc `n3' ///
                as text "   zero-event grid rows: " as result %12.0fc `n4'
            display as text "  overall event rate: " as result %14.6g `total'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
