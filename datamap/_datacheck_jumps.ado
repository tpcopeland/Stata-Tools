*! _datacheck_jumps Version 1.9.2  2026/10/05
*! datacheck jumps(): implausible jumps between consecutive repeated measures
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: id time value [, ratio(#)]   (default ratio 10)
//
// Within id, sorted by time, a pair of consecutive positive values is a jump
// when either value exceeds ratio() times the other (at float precision for
// a float value).  Rows with a missing
// time or value are not measures and are left out of the sequence.  Rows of
// one id at the same time are ordered by value, so the count does not depend
// on the order of the data; the message then says how many persons have
// such ties.  A review family: it prints the masked count of jumps and of
// persons and never halts.
program define _datacheck_jumps, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local anymask = 0
    local vars ""
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0)]
        local head `"`spec'"'
        local opts ""
        local cp = strpos(`"`spec'"', ",")
        if `cp' {
            local head = substr(`"`spec'"', 1, `cp' - 1)
            local opts = substr(`"`spec'"', `cp' + 1, .)
        }
        unab head : `head'
        local nw : word count `head'
        if `nw' < 3 {
            display as error `"jumps() spec must be "id time value [, ratio(#)]": `spec'"'
            exit 198
        }
        local val : word `nw' of `head'
        local tm : word `=`nw' - 1' of `head'
        local ids ""
        forvalues j = 1/`=`nw' - 2' {
            local ids "`ids' `: word `j' of `head''"
        }
        foreach tv in val tm {
            capture confirm numeric variable ``tv''
            if _rc {
                display as error "jumps(): ``tv'' is not numeric"
                exit 109
            }
        }
        local 0 `", `opts'"'
        syntax [, RATio(real 10)]
        if `ratio' <= 1 | missing(`ratio') {
            display as error "jumps(): ratio() must exceed 1"
            exit 198
        }
        local vars "`ids' `tm' `val'"
        if "`parseonly'" == "" {
            tempvar ok prev jmp tg tt tp
            quietly generate byte `ok' = !missing(`tm', `val')
            quietly bysort `ok' `ids' (`tm' `val'): generate double `prev' = `val'[_n-1] ///
                if `ok' & _n > 1
            // a float value is compared with ratio() times the other at float
            // precision, so values typed exactly ratio()-fold apart are no jump
            local fc = cond("`: type `val''" == "float", "float", "")
            quietly generate byte `jmp' = `ok' & `val' > 0 & `prev' > 0 & !missing(`prev') & ///
                (`val' > `fc'(`ratio' * `prev') | `prev' > `fc'(`ratio' * `val'))
            // persons with two or more measures at the same time
            quietly bysort `ok' `ids' `tm': generate byte `tt' = `ok' & _N > 1
            quietly egen byte `tp' = tag(`ids') if `tt'
            quietly count if `tp' == 1
            local nt = r(N)
            quietly count if `jmp'
            local nj = r(N)
            quietly egen byte `tg' = tag(`ids') if `jmp'
            quietly count if `tg' == 1
            local np = r(N)
            _datacheck_mcount `nj' `mask'
            local njs "`r(s)'"
            local njnum = r(num)
            local m1 = r(masked)
            _datacheck_mcount `np' `mask'
            local nps "`r(s)'"
            local m2 = r(masked)
            local om = (`m1' | `m2')
            if `om' local anymask = 1
            local mins = .
            if !`m1' & `nj' >= 1 local mins = `nj'
            if !`m2' & `np' >= 1 local mins = min(`mins', `np')
            local rtxt = strtrim(string(`ratio', "%12.0g"))
            local msg `"`pfx'jumps(`val'): `njs' consecutive pairs in `nps' persons differ by more than `rtxt'-fold"'
            if `nt' > 0 {
                _datacheck_mcount `nt' `mask'
                if r(masked) {
                    local anymask = 1
                    local om = 1
                }
                else local mins = min(`mins', `nt')
                local msg `"`msg' (same-time measures in `r(s)' persons ordered by value)"'
            }
            display as text "  " as result `"`macval(msg)'"'
            frame post `rf' ("jumps") ("review") (2) ("`val'") ("`val'") ///
                (`"`macval(grp)'"') ("`njs' jumps in `nps' persons") (`njnum') ///
                ("ratio <= `rtxt'") (`nscope') ("") (`"`macval(msg)'"') (`mins') (`om')
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return scalar masked = `anymask'
end
