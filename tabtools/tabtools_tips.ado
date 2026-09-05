*! tabtools_tips Version 2.1.2  2026/09/05
*! Quick links to the tabtools tips reference and worked recipes
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define tabtools_tips, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, OPEN]

        if "`open'" != "" {
            view help tabtools_tips
        }
        else {
            display as result "tabtools tips" as text " - quick reference and worked recipes"
            display as text "Merged guide: " as result "{help tabtools_tips:help tabtools_tips}"
            display as text "Option patterns by command: " ///
                as result "{help tabtools_tips##quick:quick reference}"
            display as text "End-to-end workflows: " ///
                as result "{help tabtools_tips##recipes:recipes}"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
