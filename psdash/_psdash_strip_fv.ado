*! _psdash_strip_fv Version 1.4.0  2026/07/01
*! Strip factor-variable notation from a covariate token list
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass
*! Internal helper

program define _psdash_strip_fv
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        args raw_covars

        local clean ""
        foreach token of local raw_covars {
            local expanded : subinstr local token "##" " ", all
            local expanded : subinstr local expanded "#" " ", all

            foreach sub of local expanded {
                local dotpos = strpos("`sub'", ".")
                if `dotpos' > 0 {
                    local sub = substr("`sub'", `dotpos' + 1, .)
                }
                capture confirm variable `sub'
                if _rc == 0 {
                    local dup : list sub in clean
                    if !`dup' {
                        local clean "`clean' `sub'"
                    }
                }
            }
        }
        c_local _psd_stripped_covars "`=strtrim("`clean'")'"
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
