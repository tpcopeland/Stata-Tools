*! _nma_display_header Version 1.0.1  2026/02/28
*! Standard header display for all nma commands

program define _nma_display_header
    version 16.0
    set varabbrev off

    syntax , command(string) [description(string)]

    display as text ""
    display as text "{hline 70}"
    display as result "nma" as text " - Network Meta-Analysis"
    display as text "{hline 70}"
    display as text ""
    display as text "Command: " as result "`command'"
    if "`description'" != "" {
        display as text "`description'"
    }
    display as text ""
end
