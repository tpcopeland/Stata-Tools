*! _datacheck_complete Version 1.9.0  2026/10/04
*! datacheck complete(): complete cases over a varlist
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: varlist [, min(#)]
//
// Prints the masked complete-case count and share within the scope cond()
// (datacheck calls it once per by() group).  Without min() it is a review
// item.  With min() the complete share must be at least min(), a gate whose
// kind the caller sets (invariant, or band inside bands()).
program define _datacheck_complete, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    local isgate = 0
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0) COND(string)]
        * nscope() may be passed as missing (.)
        local head `"`spec'"'
        local opts ""
        local cp = strpos(`"`spec'"', ",")
        if `cp' {
            local head = substr(`"`spec'"', 1, `cp' - 1)
            local opts = substr(`"`spec'"', `cp' + 1, .)
        }
        unab cvars : `head'
        local 0 `", `opts'"'
        syntax [, MIN(real -1)]
        if `min' != -1 & (`min' < 0 | `min' > 1) {
            display as error "complete(): min() must be a share between 0 and 1"
            exit 198
        }
        local isgate = (`min' != -1)
        local vars "`cvars'"
        if "`parseonly'" == "" {
            if `"`cond'"' == "" local cond "1"
            tempvar cc
            quietly generate byte `cc' = (`cond')
            foreach v of local cvars {
                quietly replace `cc' = 0 if missing(`v')
            }
            quietly count if (`cond')
            local n = r(N)
            quietly count if `cc'
            local k = r(N)
            _datacheck_mshare `k' `n' `mask'
            local kc "`r(cnt)'"
            local kp "`r(pcttxt)'"
            local om = r(masked)
            local knum = r(num)
            _datacheck_mcount `n' `mask'
            local ns "`r(s)'"
            if r(masked) local om = 1
            // datacheck passes a missing nscope for a by() group whose size
            // is withheld; the share would give the size back
            if `mask' > 0 & missing(`nscope') {
                local ns "[suppressed]"
                local kp "[masked]"
                local om = 1
            }
            if `om' local anymask = 1
            local mins = .
            if `knum' < . & `k' >= 1 local mins = `k'
            local vtxt "`cvars'"
            if length("`vtxt'") > 60 local vtxt = substr("`vtxt'", 1, 57) + "..."
            // a masked share is left out rather than printed as ".%"
            local obs = "`kc' of `ns'" + cond(`om', "", " (`kp')")
            local share = cond(`n' > 0, `k' / `n', .)
            local onum = cond(`om', ., `share')
            local rmsg `"`pfx'complete(`vtxt'): `obs' complete"'
            display as text "  " as result `"`macval(rmsg)'"'
            frame post `rf' ("complete") ("review") (2) ("`vtxt'") ("`cvars'") ///
                (`"`macval(grp)'"') ("`obs'") (`onum') ("complete cases") ///
                (`nscope') ("") (`"`macval(rmsg)'"') (`mins') (`om')
            if `isgate' {
                local mtxt = strtrim(string(100 * `min', "%9.3g"))
                local ok = (`n' > 0 & `share' >= `min')
                if !`ok' local ++nfail
                local gmsg `"`pfx'complete(`vtxt'): `obs' complete, expected >= `mtxt'%"'
                frame post `rf' ("complete") ("`kind'") (`ok') ("`vtxt'") ("`cvars'") ///
                    (`"`macval(grp)'"') ("`obs'") (`onum') (">= `mtxt'%") ///
                    (`nscope') ("") (`"`macval(gmsg)'"') (`mins') (`om')
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return scalar isgate = `isgate'
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
end
