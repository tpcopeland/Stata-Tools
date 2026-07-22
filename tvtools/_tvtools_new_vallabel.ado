*! _tvtools_new_vallabel Version 1.8.0  2026/07/22
*! Find a collision-safe persistent value-label name
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package

program define _tvtools_new_vallabel, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , BASE(name) [EXCLUDE(string asis)]

        local candidate = substr("`base'", 1, 32)
        local suffix_n = 0
        local found = 0

        while !`found' {
            local excluded : list candidate in exclude
            if !`excluded' {
                capture label list `candidate'
                local label_exists = (_rc == 0)

                if !`label_exists' local found = 1
            }

            if !`found' {
                local ++suffix_n
                local suffix "_`suffix_n'"
                local stem_len = 32 - strlen("`suffix'")
                local candidate = substr("`base'", 1, `stem_len') + "`suffix'"
            }
        }

        return local name "`candidate'"
    }
    local rc = _rc
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end
