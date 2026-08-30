*! _comorbidity_hierarchy Version 1.0.1  2026/08/30
*! Canonical comorbidity supersession hierarchies
*! Author: Timothy P Copeland, Karolinska Institutet

capture program drop _comorbidity_hierarchy
local _drop_rc = _rc
if `_drop_rc' & `_drop_rc' != 111 {
    exit `_drop_rc'
}
program define _comorbidity_hierarchy, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , INDEX(string) [PREFIX(string)]
        local index = lower(strtrim("`index'"))

        if "`index'" == "charlson" {
            local pairs "dm_comp:dm_uncomp liver_severe:liver_mild metastatic:cancer"
        }
        else if "`index'" == "elixhauser" {
            local pairs "htn_comp:htn_uncomp metastatic:solid_tumor dm_comp:dm_uncomp"
        }
        else {
            display as error "unknown index `index'"
            exit 198
        }

        quietly {
            foreach p of local pairs {
                gettoken sup inf : p, parse(":")
                local inf = subinstr("`inf'", ":", "", 1)
                local sup "`prefix'`sup'"
                local inf "`prefix'`inf'"
                capture confirm variable `sup'
                if _rc {
                    continue
                }
                capture confirm variable `inf'
                if _rc {
                    continue
                }
                replace `inf' = 0 if `sup' == 1
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
