*! _asof_report Version 0.1.0  2026/08/12
*! Display asof match coverage
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _asof_report
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , MASTER(real) KEYS(real) MATCHED(real) UNMATCHED(real) ///
            NOKEY(real) USING(real) ELIGIBLE(real) TIES(real) ///
            DIRection(string) SELect(string) TIERULE(string) ///
            [NOWARN NOIsily]

        if "`noisily'" != "" {
            display as text "asof match coverage"
            display as text "  rule:       " as result "`direction' / `select' / ties(`tierule')"
            display as text "  master:     " as result %12.0fc `master'
            display as text "  keys:       " as result %12.0fc `keys'
            display as text "  matched:    " as result %12.0fc `matched'
            display as text "  unmatched:  " as result %12.0fc `unmatched'
            display as text "  missing key:" as result %12.0fc `nokey'
            display as text "  using rows: " as result %12.0fc `using'
            display as text "  eligible:   " as result %12.0fc `eligible'
            display as text "  ties:       " as result %12.0fc `ties'
        }
        else if `unmatched' > 0 & "`nowarn'" == "" {
            display as text "(`unmatched' master observations had no eligible using record)"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
