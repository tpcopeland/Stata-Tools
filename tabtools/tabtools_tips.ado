*! tabtools_tips Version 1.6.4  2026/06/10
*! Quick links to tabtools tips, cheatsheet, and cookbook content
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define tabtools_tips, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, OPEN]

        if "`open'" != "" {
            view help tabtools_tips
        }
        else {
            display as text ""
            display as result "tabtools tips" as text " - quick reference and worked recipes"
            display as text "{hline 62}"
            display as text "Open the merged guide:"
            display as text "  " as result "{help tabtools_tips:help tabtools_tips}"
            display as text ""
            display as text "Jump to:"
            display as text "  " as result "{help tabtools_tips##quick:quick reference}" ///
                as text "  - common option patterns by command"
            display as text "  " as result "{help tabtools_tips##recipes:recipes}" ///
                as text "          - end-to-end workflows"
            display as text ""
            display as text "Legacy help topics still work:"
            display as text "  " as result "{help tabtools_cheatsheet:help tabtools_cheatsheet}"
            display as text "  " as result "{help tabtools_cookbook:help tabtools_cookbook}"
            display as text ""
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
