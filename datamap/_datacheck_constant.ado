*! _datacheck_constant Version 1.8.1  2026/09/30
*! datacheck constant(): time-fixed values within a key
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: keyvars: varlist [, ignoremissing]
//
// Each variable takes one value within each key.  A missing value next to
// a nonmissing one within a key is a second value unless ignoremissing is
// given.  String variables are allowed.  One record per variable; the
// observed count is the number of keys with more than one value.
program define _datacheck_constant, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0)]
        local cp = strpos(`"`spec'"', ":")
        if `cp' == 0 {
            display as error `"constant() spec must be "keyvars: varlist [, ignoremissing]": `spec'"'
            exit 198
        }
        local keys = strtrim(substr(`"`spec'"', 1, `cp' - 1))
        local rest = strtrim(substr(`"`spec'"', `cp' + 1, .))
        local opts ""
        local cc = strpos(`"`rest'"', ",")
        if `cc' {
            local opts = strtrim(substr(`"`rest'"', `cc' + 1, .))
            local rest = strtrim(substr(`"`rest'"', 1, `cc' - 1))
        }
        unab keys : `keys'
        unab cvars : `rest'
        local 0 `", `opts'"'
        syntax [, IGNOREmissing]
        local vars "`keys' `cvars'"
        if "`parseonly'" == "" {
            local klab = subinstr("`keys'", " ", "+", .)
            tempvar tg nv kt
            foreach v of local cvars {
                capture drop `tg'
                capture drop `nv'
                capture drop `kt'
                if "`ignoremissing'" != "" {
                    quietly egen byte `tg' = tag(`keys' `v') if !missing(`v'), missing
                }
                else quietly egen byte `tg' = tag(`keys' `v'), missing
                quietly bysort `keys': egen long `nv' = total(`tg')
                quietly egen byte `kt' = tag(`keys') if `nv' > 1, missing
                quietly count if `kt' == 1
                local nk = r(N)
                _datacheck_mcount `nk' `mask'
                local nks "`r(s)'"
                local nknum = r(num)
                local om = r(masked)
                if `om' local anymask = 1
                local mins = cond(`om' | `nk' < 1, ., `nk')
                local ok = (`nk' == 0)
                local mtxt = cond("`ignoremissing'" != "", "one nonmissing value per key", "one value per key")
                local msg `"`pfx'constant(`klab': `v'): `nks' keys with more than one value"'
                if !`ok' local ++nfail
                frame post `rf' ("constant") ("`kind'") (`ok') ("`klab': `v'") ("`v'") ///
                    (`"`macval(grp)'"') ("`nks' keys vary") (`nknum') ("`mtxt'") ///
                    (`nscope') ("") (`"`macval(msg)'"') (`mins') (`om')
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
end
