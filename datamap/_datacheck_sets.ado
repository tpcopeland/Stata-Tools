*! _datacheck_sets Version 1.9.0  2026/10/04
*! datacheck sets(): matched-set structure
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: set_id exposure [, k(#) index(varname)]
//
// Named checks, each its own record:
//   values     exposure is 0 or 1 on every row
//   exposed    each set has exactly one exposed row (exposure == 1)
//   unexposed  each set has exactly k unexposed rows (at least one without k())
//   index      (index()) each set has one index date
// Observed counts are numbers of sets (rows for values), masked under maskrare
// (a row count also when its complement in nscope() is a small cell).
program define _datacheck_sets, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
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
        if `: word count `head'' != 2 {
            display as error `"sets() spec must be "set_id exposure [, k(#) index(varname)]": `spec'"'
            exit 198
        }
        local sid : word 1 of `head'
        local ex : word 2 of `head'
        capture confirm numeric variable `ex'
        if _rc {
            display as error "sets(): `ex' is not numeric"
            exit 109
        }
        local 0 `", `opts'"'
        syntax [, K(integer -1) INDEX(varname)]
        if `k' == 0 | `k' < -1 {
            display as error "sets(): k() must be a positive integer"
            exit 198
        }
        local vars "`sid' `ex' `index'"
        if "`parseonly'" == "" {
            tempvar n1 n0 tg bad it ni
            quietly bysort `sid': egen long `n1' = total(`ex' == 1)
            quietly by `sid': egen long `n0' = total(`ex' == 0)
            quietly egen byte `tg' = tag(`sid'), missing
            local checks "values exposed unexposed"
            if "`index'" != "" {
                local checks "`checks' index"
                quietly egen byte `it' = tag(`sid' `index'), missing
                quietly bysort `sid': egen long `ni' = total(`it')
            }
            local ktxt = cond(`k' > 0, "exactly `k'", "at least 1")
            foreach ck of local checks {
                capture drop `bad'
                if "`ck'" == "values" {
                    quietly generate byte `bad' = !inlist(`ex', 0, 1)
                    local unit "rows"
                    local what "have exposure other than 0/1"
                    local exp "exposure 0 or 1"
                }
                else if "`ck'" == "exposed" {
                    quietly generate byte `bad' = `tg' & `n1' != 1
                    local unit "sets"
                    local what "do not have exactly one exposed row"
                    local exp "1 exposed per set"
                }
                else if "`ck'" == "unexposed" {
                    if `k' > 0 quietly generate byte `bad' = `tg' & `n0' != `k'
                    else quietly generate byte `bad' = `tg' & `n0' < 1
                    local unit "sets"
                    local what "do not have `ktxt' unexposed rows"
                    local exp "`ktxt' unexposed per set"
                }
                else {
                    quietly generate byte `bad' = `tg' & `ni' > 1
                    local unit "sets"
                    local what "have more than one `index'"
                    local exp "one `index' per set"
                }
                quietly count if `bad'
                local nb = r(N)
                // rows are counted out of the N a run prints, so a small
                // complement is masked too; sets are counted out of no
                // printed total
                if "`ck'" == "values" _datacheck_mcount `nb' `mask' `nscope'
                else _datacheck_mcount `nb' `mask'
                local nbs "`r(s)'"
                local nbnum = r(num)
                local om = r(masked)
                if `om' local anymask = 1
                local mins = cond(`om' | `nb' < 1, ., `nb')
                local ok = (`nb' == 0)
                if !`ok' local ++nfail
                local msg `"`pfx'sets(`ck'): `nbs' `unit' `what'"'
                frame post `rf' ("sets") ("`kind'") (`ok') ("`ck'") ("`sid' `ex'") ///
                    (`"`macval(grp)'"') ("`nbs' `unit'") (`nbnum') ("`exp'") ///
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
