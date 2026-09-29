*! _kmplot_times Version 1.3.1  2026/09/30
*! Expand numeric time lists without rounding explicit double values
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _kmplot_times, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , VALues(string)
        * Stata validates grammar and cardinality; its decimal serialization
        * is used only to count sequence members, never as the requested time.
        numlist "`values'"
        tokenize "`values'", parse(" /()[]:")
        local times ""
        tempname start step value
        while "`1'" != "" {
            scalar `start' = `1'
            scalar `step' = 1
            local n = 1
            if inlist("`2'", "(", "[") {
                scalar `step' = `3'
                numlist "`1'(`3')`5'"
                local n : word count `r(numlist)'
                macro shift 5
            }
            else if "`2'" == "/" {
                numlist "`1'/`3'"
                local n : word count `r(numlist)'
                if `3' < scalar(`start') scalar `step' = -1
                macro shift 3
            }
            else if inlist("`3'", ":", "to") {
                scalar `step' = `2' - scalar(`start')
                numlist "`1' `2' to `4'"
                local n : word count `r(numlist)'
                macro shift 4
            }
            else {
                macro shift
            }
            forvalues j = 0/`=`n' - 1' {
                scalar `value' = scalar(`start') + `j' * scalar(`step')
                local text : display %24.17g scalar(`value')
                local times "`times' `text'"
            }
        }
        mata: st_local("times", invtokens(strofreal(sort(strtoreal(tokens(st_local("times")))', 1)', "%24.17g")))
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local times "`times'"
end
