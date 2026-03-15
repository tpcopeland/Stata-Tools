*! _aft_display_header Version 1.0.0  2026/03/14
*! Standard header display for aft commands
*! Author: Timothy P Copeland

* Usage: _aft_display_header "aft_select" "Distribution Selection"

program define _aft_display_header
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
