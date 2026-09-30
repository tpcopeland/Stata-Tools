*! _datacheck_heaping Version 1.8.0  2026/09/30
*! datacheck heaping(): placeholder-date heaping on 1 January, the 1st, the 15th
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: datevarlist [, fold(#) max(# [# #])]
//
// For each daily date, prints the share of dates on 1 January, on the 1st of
// any month and on the 15th, next to the share expected by chance
// (1/365.25, 12/365.25, 12/365.25).  A share above fold() times its chance
// share (default 5) is marked; that is a review item and never halts.  With
// max(), the 1 January share (and, with two or three numbers, the 1st and
// the 15th shares) must not exceed the given shares: a gate whose kind the
// caller sets (invariant, or band inside bands()).
program define _datacheck_heaping, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    local isgate = 0
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
        unab dvars : `head'
        foreach dv of local dvars {
            capture confirm numeric variable `dv'
            local isnum = (_rc == 0)
            local vf : format `dv'
            local vf = subinstr("`vf'", "%-", "%", 1)
            if !`isnum' | !(substr("`vf'", 1, 3) == "%td" | substr("`vf'", 1, 2) == "%d") {
                display as error "heaping(): `dv' must be a daily (%td) date"
                exit 198
            }
        }
        local 0 `", `opts'"'
        syntax [, FOLD(real 5) MAX(numlist max=3 >=0 <=1)]
        if `fold' <= 0 | missing(`fold') {
            display as error "heaping(): fold() must be positive"
            exit 198
        }
        local isgate = ("`max'" != "")
        local vars "`dvars'"
        if "`parseonly'" == "" {
            local e1 = 1 / 365.25
            local e2 = 12 / 365.25
            local e3 = 12 / 365.25
            local ftxt = strtrim(string(`fold', "%9.0g"))
            local m1 : word 1 of `max'
            local m2 : word 2 of `max'
            local m3 : word 3 of `max'
            display ""
            display as text "HEAPING " as text "(share of dates; chance: Jan 1 " ///
                as result %4.2f 100 * `e1' as text "%, 1st " as result %4.2f 100 * `e2' ///
                as text "%, 15th " as result %4.2f 100 * `e3' as text "%)"
            display as text "  " %-22s "Variable" %9s "N" %11s "Jan 1" %11s "1st" %11s "15th"
            foreach dv of local dvars {
                quietly count if !missing(`dv')
                local n = r(N)
                quietly count if !missing(`dv') & day(`dv') == 1 & month(`dv') == 1
                local c1 = r(N)
                quietly count if !missing(`dv') & day(`dv') == 1
                local c2 = r(N)
                quietly count if !missing(`dv') & day(`dv') == 15
                local c3 = r(N)
                _datacheck_mcount `n' `mask' `nscope'
                local ns "`r(s)'"
                local om = r(masked)
                local obs ""
                local marks ""
                forvalues j = 1/3 {
                    local sh`j' = cond(`n' > 0, `c`j'' / `n', .)
                    _datacheck_mshare `c`j'' `n' `mask'
                    local p`j' "`r(pct)'"
                    local sm`j' = r(masked)
                    if !`sm`j'' & `n' > 0 local p`j' = strtrim(string(100 * `sh`j'', "%9.2f"))
                    if `sm`j'' local om = 1
                    local f`j' = cond(`n' > 0 & `sh`j'' > `fold' * `e`j'' & !`sm`j'', "*", " ")
                    if "`f`j''" == "*" local marks "`marks' `j'"
                }
                if `om' local anymask = 1
                local vshow = substr("`dv'", 1, 21)
                display as text "  " as result %-22s "`vshow'" %9s "`ns'" ///
                    %10s "`p1'%" as text "`f1'" as result %10s "`p2'%" as text "`f2'" ///
                    as result %10s "`p3'%" as text "`f3'"
                local obs "Jan 1 `p1'%, 1st `p2'%, 15th `p3'%"
                local onum = cond(`sm1', ., `sh1')
                local rmsg `"`pfx'heaping(`dv'): `obs'"'
                if "`marks'" != "" local rmsg `"`rmsg' (above `ftxt'x chance)"'
                frame post `rf' ("heaping") ("review") (2) ("`dv'") ("`dv'") ///
                    (`"`macval(grp)'"') ("`obs'") (`onum') ("<= `ftxt'x chance") ///
                    (`nscope') ("") (`"`macval(rmsg)'"') (.) (`om')
                if `isgate' {
                    local ok = 1
                    local bad ""
                    local exp ""
                    local lab1 "Jan 1"
                    local lab2 "1st"
                    local lab3 "15th"
                    forvalues j = 1/3 {
                        if "`m`j''" == "" continue
                        local exp = strtrim("`exp' `lab`j'' <= " + strtrim(string(100 * `m`j'', "%9.3g")) + "%")
                        if `n' == 0 | `sh`j'' > `m`j'' {
                            local ok = 0
                            local bad = strtrim("`bad' `lab`j'' `p`j''%")
                        }
                    }
                    if `n' == 0 local bad "no nonmissing dates"
                    if !`ok' local ++nfail
                    if `ok' local gmsg `"`pfx'heaping(`dv'): `obs' within `exp'"'
                    else local gmsg `"`pfx'heaping(`dv'): `bad' exceeds `exp'"'
                    frame post `rf' ("heaping") ("`kind'") (`ok') ("`dv'") ("`dv'") ///
                        (`"`macval(grp)'"') ("`obs'") (`onum') ("`exp'") ///
                        (`nscope') ("") (`"`macval(gmsg)'"') (.) (`om')
                }
            }
            display as text "  (* above `ftxt' times the chance share; a review item)"
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
