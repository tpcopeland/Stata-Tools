*! _datacheck_smallcells Version 1.9.0  2026/10/03
*! datacheck smallcells(): no released count of 1 to m-1 in a results dataset
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: countexp [countexp ...] [if exp]
//
// A publication gate for a results dataset (one row per released table cell
// or row).  Each countexp is a variable or an expression with no spaces (a
// parenthesised expression may contain spaces, as in (n1 - e1)), such as
// n1-e1.  On the rows in scope (the entry's if, within the call's if/in) no
// countexp may lie in 1 to m-1.  Zero, a value of m or more, and a missing
// value (a suppressed cell) pass.  A negative or non-integer value fails, as
// its own reason.  An expression that does not evaluate is an error, never a
// pass.  m is the threshold datacheck resolved for the call (mincell(), the
// dataqa set default, or the maskrare default); it arrives as mcell().
//
// The message and the record never carry a value, only the number of table
// rows that fail, per countexp and reason, masked under maskrare.  A failed
// gate is an invariant: it never becomes a band.
program define _datacheck_smallcells, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0) MCELL(integer 0)]
        if `mcell' < 1 {
            display as error "smallcells() needs a threshold: give mincell(#), or set one with dataqa set mincell(#)"
            exit 198
        }
        if `mcell' < 2 {
            display as error "smallcells() needs a threshold of 2 or more (resolved mincell/rare is `mcell'): a gate on counts in 1..`=`mcell'-1' tests nothing"
            exit 198
        }
        // ---- split the entry into countexps and an optional if ----
        local s = strtrim(`"`spec'"')
        local L = strlen(`"`s'"')
        local depth = 0
        local tok ""
        local nexp = 0
        local ifexp ""
        local done = 0
        forvalues i = 1/`=`L' + 1' {
            if `done' continue
            local atend = (`i' > `L')
            if !`atend' {
                if substr(`"`s'"', `i', 1) == "(" local ++depth
                if substr(`"`s'"', `i', 1) == ")" local --depth
                if `depth' < 0 {
                    display as error `"smallcells(): unbalanced parentheses in `spec'"'
                    exit 198
                }
            }
            local isblank = (!`atend' & substr(`"`s'"', `i', 1) == " " & `depth' == 0)
            if `atend' | `isblank' {
                if `depth' != 0 {
                    display as error `"smallcells(): unbalanced parentheses in `spec'"'
                    exit 198
                }
                if `"`tok'"' != "" {
                    if lower(`"`tok'"') == "if" {
                        local ifexp = strtrim(substr(`"`s'"', `i' + 1, .))
                        local done = 1
                    }
                    else {
                        local ++nexp
                        local ex`nexp' `"`tok'"'
                    }
                    local tok ""
                }
            }
            else local tok `"`tok'`=substr(`"`s'"', `i', 1)'"'
        }
        if `nexp' == 0 {
            display as error `"smallcells() spec must be "countexp [countexp ...] [if exp]": `spec'"'
            exit 198
        }
        if `done' & `"`ifexp'"' == "" {
            display as error "smallcells(): empty if condition"
            exit 198
        }
        // ---- the variables the expressions read (kept by datacheck) ----
        local full ""
        forvalues j = 1/`nexp' {
            local full `"`full' `ex`j''"'
        }
        local full `"`full' `ifexp'"'
        local rest `"`full'"'
        while regexm(`"`rest'"', "([A-Za-z_][A-Za-z0-9_]*)") {
            local w = regexs(1)
            local rest = substr(`"`rest'"', strpos(`"`rest'"', "`w'") + strlen("`w'"), .)
            capture confirm variable `w', exact
            if !_rc local vars "`vars' `w'"
        }
        local vars : list uniq vars
        // ---- every expression must evaluate; checked on parse and on run ----
        tempvar sc
        quietly generate byte `sc' = 1
        if `"`ifexp'"' != "" {
            capture quietly replace `sc' = ((`ifexp') != 0)
            if _rc {
                local _erc = _rc
                display as error `"smallcells(): cannot evaluate condition if `ifexp'"'
                exit `_erc'
            }
        }
        forvalues j = 1/`nexp' {
            tempvar v`j'
            capture quietly generate double `v`j'' = (`ex`j'')
            if _rc {
                local _erc = _rc
                display as error `"smallcells(): cannot evaluate `ex`j''; a countexp is a variable or an expression with no spaces"'
                exit `_erc'
            }
        }
        if "`parseonly'" == "" {
            tempvar anyf
            quietly generate byte `anyf' = 0
            local pieces ""
            local mins = .
            local om = 0
            local m1 = `mcell' - 1
            forvalues j = 1/`nexp' {
                local v "`v`j''"
                quietly count if `sc' & !missing(`v') & `v' < 0
                local kneg = r(N)
                quietly count if `sc' & !missing(`v') & `v' >= 0 & abs(`v' - round(`v')) > 1e-8
                local kint = r(N)
                quietly count if `sc' & !missing(`v') & `v' >= 0 & abs(`v' - round(`v')) <= 1e-8 ///
                    & round(`v') >= 1 & round(`v') <= `m1'
                local ksm = r(N)
                quietly replace `anyf' = 1 if `sc' & !missing(`v') & (`v' < 0 | ///
                    abs(`v' - round(`v')) > 1e-8 | (round(`v') >= 1 & round(`v') <= `m1'))
                local why ""
                foreach r in ksm kneg kint {
                    if ``r'' == 0 continue
                    _datacheck_mcount ``r'' `mask'
                    local rs "`r(s)'"
                    if r(masked) {
                        local om = 1
                        local anymask = 1
                    }
                    else local mins = min(`mins', ``r'')
                    local lab = cond("`r'" == "ksm", "small", ///
                        cond("`r'" == "kneg", "negative", "non-integer"))
                    local why "`why'`=cond("`why'" == "", "", ", ")'`rs' `lab'"
                }
                if "`why'" != "" local pieces `"`pieces'`=cond(`"`pieces'"' == "", "", "; ")'`ex`j'' (`why')"'
            }
            quietly count if `anyf'
            local nbad = r(N)
            local ok = (`nbad' == 0)
            if !`ok' local nfail = 1
            _datacheck_mcount `nbad' `mask'
            local nbs "`r(s)'"
            local onum = r(num)
            if r(masked) {
                local om = 1
                local anymask = 1
            }
            else if `nbad' >= 1 local mins = min(`mins', `nbad')
            local vtxt `"`ex1'"'
            forvalues j = 2/`nexp' {
                local vtxt `"`vtxt' `ex`j''"'
            }
            if `"`ifexp'"' != "" local vtxt `"`vtxt' if `ifexp'"'
            if length(`"`vtxt'"') > 60 local vtxt = substr(`"`vtxt'"', 1, 57) + "..."
            local exptxt "no released count in 1..`m1' (m=`mcell')"
            if `ok' local msg `"`pfx'smallcells(`vtxt'): `exptxt'"'
            else local msg `"`pfx'smallcells(`vtxt'): `nbs' table rows fail, `pieces'; expected `exptxt'"'
            frame post `rf' ("smallcells") ("`kind'") (`ok') (`"`macval(vtxt)'"') (`"`macval(vtxt)'"') ///
                (`"`macval(grp)'"') ("`nbs' rows fail") (`onum') ("`exptxt'") ///
                (`nscope') (`"`macval(ifexp)'"') (`"`macval(msg)'"') (`mins') (`om')
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return scalar isgate = 1
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
end
