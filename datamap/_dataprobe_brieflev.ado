*! _dataprobe_brieflev Version 2.0.0  2026/11/10
*! dataprobe brief: the level text of one categorical or string variable
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// 2.0.0 (U1).  The text, unescaped (the caller escapes it for display), goes
// into the string scalar into(): a value label's quotes and backticks never
// pass through a macro on the way back.
//   categorical   the five most frequent nonmissing levels with their counts,
//                 "1 Male 1,520; 2 Female 1,480; +2 more", ties by value.  A
//                 level held by one observation, or by fewer than mask(m),
//                 is never listed.  Under m > 0 the unlisted rows (the
//                 nonmissing count less the listed ones) are 0 or m or more:
//                 the smallest listed level joins them until that holds,
//                 since the header and the missing count give the total.
//   string        "all distinct, maxlen #" when every nonblank value is held
//                 by one observation; otherwise nothing (brief lists no text
//                 values)
//   withheld()    "levels withheld (safe: <reason>)" in place of either
program define _dataprobe_brieflev, nclass sortpreserve
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local text ""
    tempname fr
    local _fr_open = 0
    capture noisily {
        // uv() and maxlen(): -1 (or a missing value) when not known
        syntax varname, CLASS(string) MASK(integer) INTO(name) [UV(real -1) UC(real 0) ///
            MAXLEN(real -1) WITHHELD(string)]
        if `uv' < 0 local uv = .
        if `maxlen' < 0 local maxlen = .
        local v "`varlist'"
        capture confirm string variable `v'
        local isstr = (_rc == 0)
        if `"`withheld'"' != "" local text "levels withheld (safe: `withheld')"
        else if "`class'" == "string" {
            quietly count if `v' != ""
            local nn = r(N)
            // not all distinct when the exact count says so; else counted
            local all = 0
            if `nn' > 0 & (`uc' == 1 | missing(`uv') | `uv' >= `nn') {
                tempvar t
                quietly bysort `v': generate byte `t' = (_n == 1) if `v' != ""
                quietly count if `t' == 1
                local all = (r(N) == `nn')
            }
            if `all' {
                local ml = cond(missing(`maxlen'), "", ", maxlen " + strtrim(string(`maxlen', "%12.0f")))
                local text "all distinct`ml'"
            }
        }
        else {
            local thr = max(2, `mask')
            frame put `v' if !missing(`v'), into(`fr')
            local _fr_open = 1
            local nl = 0
            local nlev = 0
            frame `fr' {
                if _N > 0 {
                    tempvar f
                    quietly contract `v', freq(`f')
                    local nlev = _N
                    gsort -`f' `v'
                    quietly summarize `f', meanonly
                    local rest = r(sum)
                    forvalues r = 1/`=min(5, _N)' {
                        if `f'[`r'] < `thr' continue, break
                        local ++nl
                        local c`nl' = `f'[`r']
                        local rest = `rest' - `c`nl''
                        if `isstr' mata: st_local("val`nl'", _st_sdata(`r', "`v'"))
                        else local val`nl' = `v'[`r']
                    }
                    // the unlisted rows are 0 or m or more
                    while `mask' > 0 & `nl' > 0 & `rest' >= 1 & `rest' < `mask' {
                        local rest = `rest' + `c`nl''
                        local --nl
                    }
                }
            }
            frame drop `fr'
            local _fr_open = 0
            local lbl : value label `v'
            forvalues k = 1/`nl' {
                if `isstr' mata: st_local("item", char(34) + st_local("val`k'") + char(34))
                else {
                    local item = strtrim(string(`val`k'', "%12.0g"))
                    if "`: type `v''" == "float" local item = strtrim(string(float(`val`k''), "%9.0g"))
                    if "`lbl'" != "" {
                        local lab : label `lbl' `val`k'', strict
                        if `"`lab'"' != "" mata: st_local("item", st_local("item") + " " + st_local("lab"))
                    }
                }
                local cs = strtrim(string(`c`k'', "%20.0fc"))
                mata: st_local("text", st_local("text") + (`k' > 1 ? "; " : "") + st_local("item") + " " + st_local("cs"))
            }
            if `nlev' > `nl' {
                local more = `nlev' - `nl'
                if `nl' == 0 local text "`more' level(s), none listed"
                else mata: st_local("text", st_local("text") + "; +" + st_local("more") + " more")
            }
        }
    }
    local rc = _rc
    if `_fr_open' capture frame drop `fr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    mata: st_strscalar(st_local("into"), st_local("text"))
end
