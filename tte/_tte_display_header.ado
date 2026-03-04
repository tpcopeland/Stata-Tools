*! _tte_display_header Version 1.0.2  2026/02/28
*! Standard header for all commands
*! Author: Timothy P Copeland
*! Author: Tania F Reza

program define _tte_display_header
    version 16.0
    set varabbrev off
    set more off

    syntax , command(string) [description(string)]

    display as text ""
    display as text "{hline 70}"
    display as result "tte" as text " - Target Trial Emulation"
    display as text "{hline 70}"
    display as text ""
    display as text "Command: " as result "`command'"
    if "`description'" != "" {
        display as text "`description'"
    }
    display as text ""
end
