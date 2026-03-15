*! _drest_display_header Version 1.0.0  2026/03/15
*! Standard header display for drest commands
*! Author: Timothy P Copeland

* Usage: _drest_display_header "drest_estimate" "AIPW Estimation"

program define _drest_display_header
    version 16.0
    set varabbrev off
    set more off

    args cmd_name subtitle

    display as text ""
    display as text "{hline 70}"
    display as result "`cmd_name'" as text " - `subtitle'"
    display as text "{hline 70}"
    display as text ""
end
