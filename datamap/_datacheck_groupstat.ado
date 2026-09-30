*! _datacheck_groupstat Version 1.8.0  2026/09/30
*! datacheck groupstat(): a statistic by group against the pooled value
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec (the entry's own "if" is split off and evaluated by datacheck):
//   statistic varlist, by(groupvars) [min(#) band(lo hi) relative]
//
// statistic: mean sd median p1 p5 p10 p25 p50 p75 p90 p95 p99 sum n distinct
// pmiss ess, with the definitions of stat().  Prints one row per group and
// one column per variable, then the pooled value.  Groups with fewer than
// min() rows (default: the mask threshold, or 1 without masking) are
// suppressed and counted in one pooled line.  Cells follow the stat()
// masking rules.  pmiss comes from _datamap_missby, the helper datamvp
// bytable() uses.
//
// Without band() the entry is a review item.  With band(lo hi) every
// group's value must lie in [lo, hi], including groups pooled away under the
// mask (reported as [suppressed]); an explicit min() excludes the groups
// below it from the band.  With relative the band applies to the ratio of
// the cell to the pooled value.  The gate's kind is set by the caller.
program define _datacheck_groupstat, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    local isgate = 0
    local _fr_made = 0
    tempname fr
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0) COND(string) SCOPE(string)]
        local head `"`spec'"'
        local opts ""
        local cp = strpos(`"`spec'"', ",")
        if `cp' {
            local head = strtrim(substr(`"`spec'"', 1, `cp' - 1))
            local opts = substr(`"`spec'"', `cp' + 1, .)
        }
        gettoken st head : head
        local st = lower("`st'")
        if "`st'" == "median" local st "p50"
        local isorder = inlist("`st'", "p1", "p5", "p10", "p25", "p50") | ///
            inlist("`st'", "p75", "p90", "p95", "p99")
        if !`isorder' & !inlist("`st'", "mean", "sd", "sum", "n", "distinct", "pmiss", "ess") {
            display as error "groupstat(): statistic must be mean, sd, median, p1-p99, sum, n, distinct, pmiss, or ess; got `st'"
            exit 198
        }
        unab gvars : `head'
        if !inlist("`st'", "n", "distinct", "pmiss") {
            foreach v of local gvars {
                capture confirm numeric variable `v'
                if _rc {
                    display as error "groupstat(): `v' is not numeric"
                    exit 109
                }
            }
        }
        local 0 `", `opts'"'
        capture syntax , BY(varlist) [MIN(integer -1) BAND(numlist min=2 max=2) RELative]
        if _rc {
            local _src = _rc
            display as error `"groupstat() entry must be "statistic varlist, by(groupvars) [min(#) band(lo hi) relative]": `spec'"'
            if `_src' == 111 exit 111
            exit 198
        }
        local byv "`by'"
        if "`relative'" != "" & "`band'" == "" {
            display as error "groupstat(): relative requires band()"
            exit 198
        }
        local lo : word 1 of `band'
        local hi : word 2 of `band'
        if "`band'" != "" {
            if `lo' > `hi' {
                display as error "groupstat(): band() lower bound exceeds upper bound"
                exit 198
            }
        }
        local isgate = ("`band'" != "")
        local vars "`gvars' `byv'"
        if "`parseonly'" == "" {
            if `"`cond'"' == "" local cond "1"
            local gmin = `min'
            if `gmin' < 0 local gmin = max(`mask', 1)
            // The band tests every group unless min() excludes the small
            // ones by choice: the mask decides what prints, never the verdict.
            local bmin = cond(`min' < 0, 1, `min')
            local sname = cond("`st'" == "p50", "median", "`st'")
            tempvar in g one
            quietly generate byte `in' = (`cond')
            quietly egen long `g' = group(`byv') if `in', label
            quietly summarize `g', meanonly
            local G = cond(r(N) > 0, r(max), 0)
            local glab : value label `g'
            quietly generate byte `one' = 1
            local nv : word count `gvars'
            // per-group values: one row per group in frame fr
            local keep "`g' `one'"
            local j = 0
            foreach v of local gvars {
                local ++j
                tempvar gv`j' nle`j' nge`j' nn`j' w2`j' t2`j' tg`j'
                if "`st'" == "pmiss" {
                    quietly generate byte `gv`j'' = missing(`v') if `in' & !missing(`g')
                    quietly generate byte `nn`j'' = `gv`j''
                    local keep "`keep' `gv`j'' `nn`j''"
                    continue
                }
                if inlist("`st'", "mean", "sd") | `isorder' {
                    if "`st'" == "mean" quietly bysort `g': egen double `gv`j'' = mean(`v') if !missing(`g')
                    else if "`st'" == "sd" quietly bysort `g': egen double `gv`j'' = sd(`v') if !missing(`g')
                    else {
                        local pp = substr("`st'", 2, .)
                        quietly bysort `g': egen double `gv`j'' = pctile(`v') if !missing(`g'), p(`pp')
                    }
                    quietly by `g': egen long `nle`j'' = total(`v' <= `gv`j'' & !missing(`v'))
                    quietly by `g': egen long `nge`j'' = total(`v' >= `gv`j'' & !missing(`v'))
                    quietly by `g': egen long `nn`j'' = count(`v')
                    local keep "`keep' `gv`j'' `nle`j'' `nge`j'' `nn`j''"
                }
                else if "`st'" == "sum" {
                    quietly bysort `g': egen double `gv`j'' = total(`v') if !missing(`g')
                    quietly by `g': egen long `nn`j'' = count(`v')
                    local keep "`keep' `gv`j'' `nn`j''"
                }
                else if "`st'" == "n" {
                    quietly bysort `g': egen double `gv`j'' = count(`v') if !missing(`g')
                    quietly generate byte `nn`j'' = 1
                    local keep "`keep' `gv`j'' `nn`j''"
                }
                else if "`st'" == "distinct" {
                    quietly egen byte `tg`j'' = tag(`g' `v') if !missing(`g') & !missing(`v')
                    quietly bysort `g': egen double `gv`j'' = total(`tg`j'') if !missing(`g')
                    quietly generate byte `nn`j'' = 1
                    local keep "`keep' `gv`j'' `nn`j''"
                }
                else {
                    quietly generate double `w2`j'' = `v'^2
                    quietly bysort `g': egen double `t2`j'' = total(`w2`j'') if !missing(`g')
                    quietly by `g': egen double `gv`j'' = total(`v') if !missing(`g')
                    quietly replace `gv`j'' = cond(`t2`j'' > 0, `gv`j''^2 / `t2`j'', .)
                    quietly by `g': egen long `nn`j'' = count(`v')
                    local keep "`keep' `gv`j'' `nn`j''"
                }
            }
            if "`st'" == "pmiss" {
                quietly _datamap_missby `gvars', by(`byv') touse(`in')
                tempname MN MNG
                matrix `MN' = r(nmiss)
                matrix `MNG' = r(ngroup)
            }
            frame put `keep' if !missing(`g'), into(`fr')
            local _fr_made = 1
            frame `fr' {
                if "`st'" == "pmiss" {
                    quietly collapse (sum) `one', by(`g')
                }
                else {
                    local agg ""
                    local j = 0
                    foreach v of local gvars {
                        local ++j
                        local agg "`agg' `gv`j''"
                        if "`nle`j''" != "" capture confirm variable `nle`j''
                        if "`nle`j''" != "" & !_rc local agg "`agg' `nle`j'' `nge`j''"
                        local agg "`agg' `nn`j''"
                    }
                    quietly collapse (sum) `one' (max) `agg', by(`g')
                }
                forvalues k = 1/`G' {
                    local n_`k' = `one'[`k']
                    local j = 0
                    foreach v of local gvars {
                        local ++j
                        if "`st'" == "pmiss" {
                            local nmk = `MN'[`j', `k']
                            local val_`k'_`j' = `nmk' / `MNG'[1, `k']
                            local nm_`k'_`j' = `nmk'
                        }
                        else {
                            local val_`k'_`j' = `gv`j''[`k']
                            local nn_`k'_`j' = `nn`j''[`k']
                            capture confirm variable `nle`j''
                            if !_rc {
                                local le_`k'_`j' = `nle`j''[`k']
                                local ge_`k'_`j' = `nge`j''[`k']
                            }
                        }
                    }
                }
            }
            capture frame drop `fr'
            local _fr_made = 0

            // pooled values over the whole entry scope
            local j = 0
            foreach v of local gvars {
                local ++j
                _datacheck_statval `st' `v', cond(`"`in'"') mask(`mask') fmt(%10.4g)
                local pool_`j' = r(value)
                local pools_`j' `"`r(s)'"'
                if !r(shown) local anymask = 1
            }

            // display
            local reltxt = cond("`relative'" != "", "  (cells relative to pooled)", "")
            display ""
            display as text "GROUPSTAT " as result "`sname'" as text " by(" as result "`byv'" ///
                as text ")`reltxt'"
            local hdr ""
            foreach v of local gvars {
                local hdr `"`hdr' as text %12s abbrev("`v'", 12)"'
            }
            display as text "  " %-24s "Group" `hdr'
            local nsmall = 0
            local j = 0
            foreach v of local gvars {
                local ++j
                local cm_`j' = 0
            }
            forvalues k = 1/`G' {
                local gl "`k'"
                if "`glab'" != "" {
                    local _t : label `glab' `k'
                    if `"`_t'"' != "" local gl `"`_t'"'
                }
                local gl_`k' `"`gl'"'
                local sup_`k' = 0
                local tst_`k' = (`n_`k'' >= `bmin')
                if `n_`k'' < `gmin' {
                    local ++nsmall
                    local sup_`k' = 1
                    local j = 0
                    foreach v of local gvars {
                        local ++j
                        local sh_`k'_`j' = 0
                    }
                    continue
                }
                local line ""
                local j = 0
                foreach v of local gvars {
                    local ++j
                    local x = `val_`k'_`j''
                    local shown = 1
                    if missing(`x') local s "."
                    else if "`st'" == "pmiss" {
                        if `mask' > 0 & `nm_`k'_`j'' >= 1 & `nm_`k'_`j'' < `mask' local shown = 0
                        local s = strtrim(string(`x', "%10.4g"))
                    }
                    else if inlist("`st'", "sum", "n", "distinct") {
                        if `mask' > 0 & `x' >= 1 & `x' < `mask' & `x' == floor(`x') local shown = 0
                        local s = strtrim(string(`x', "%10.4g"))
                    }
                    else if "`st'" == "sd" | "`st'" == "ess" {
                        if `mask' > 0 & `nn_`k'_`j'' < `mask' local shown = 0
                        local s = strtrim(string(`x', "%10.4g"))
                    }
                    else {
                        if `mask' > 0 & (`le_`k'_`j'' < `mask' | `ge_`k'_`j'' < `mask') local shown = 0
                        local s = strtrim(string(`x', "%10.4g"))
                    }
                    if !`shown' {
                        local s = cond(inlist("`st'", "sum", "n", "distinct"), "<`mask'", ///
                            cond("`st'" == "pmiss", ".", "[suppr.]"))
                        local anymask = 1
                        local cm_`j' = 1
                    }
                    local sh_`k'_`j' = `shown'
                    local s_`k'_`j' "`s'"
                    local line `"`line' as result %12s "`s'""'
                }
                local gshow = substr(`"`gl'"', 1, 24)
                display as text "  " as result %-24s `"`gshow'"' `line'
            }
            // For n, sum, and distinct the pooled value minus the shown groups
            // would give back a pooled-away group or a masked cell, so the
            // pooled value is withheld when either exists.
            local line ""
            local j = 0
            foreach v of local gvars {
                local ++j
                if `mask' > 0 & inlist("`st'", "sum", "n", "distinct") & (`nsmall' > 0 | `cm_`j'') {
                    local pools_`j' "[suppr.]"
                    local anymask = 1
                }
                local line `"`line' as result %12s "`pools_`j''""'
            }
            display as text "  " as text %-24s "pooled" `line'
            if `nsmall' > 0 {
                if `mask' > 0 display as text "  groups with <`gmin' rows: " as result `nsmall'
                else display as text "  groups with fewer than `gmin' rows: " as result `nsmall'
            }

            // records
            local j = 0
            foreach v of local gvars {
                local ++j
                local shownG = `G' - `nsmall'
                local rmsg `"`pfx'groupstat(`sname' `v', by(`byv')): `shownG' group(s) shown, pooled `pools_`j''"'
                frame post `rf' ("groupstat") ("review") (2) ("`sname' `v'") ("`v'") ///
                    (`"`macval(grp)'"') ("pooled `pools_`j''") (.) ("by(`byv')") ///
                    (`nscope') (`"`macval(scope)'"') (`"`macval(rmsg)'"') (.) (0)
                if !`isgate' continue
                local nf_v = 0
                local etxt = cond("`relative'" != "", "ratio to pooled in [`lo', `hi']", "[`lo', `hi']")
                forvalues k = 1/`G' {
                    if !`tst_`k'' continue
                    local x = `val_`k'_`j''
                    if "`relative'" != "" local x = `x' / `pool_`j''
                    if !missing(`x') & `x' >= `lo' & `x' <= `hi' continue
                    local ++nf_v
                    local ++nfail
                    if `sh_`k'_`j'' {
                        local xs = strtrim(string(`x', "%10.4g"))
                        local onum = `x'
                        local om = 0
                    }
                    else {
                        local xs "[suppressed]"
                        local onum = .
                        local om = 1
                    }
                    local what = cond("`relative'" != "", "ratio to pooled", "`sname'")
                    local g2 `"by(`byv') = `gl_`k''"'
                    if `"`grp'"' != "" local g2 `"`grp'; `g2'"'
                    local fmsg `"`pfx'groupstat(`sname' `v'): `what' `xs' in group `gl_`k'', expected `etxt'"'
                    frame post `rf' ("groupstat") ("`kind'") (0) ("`sname' `v'") ("`v'") ///
                        (`"`macval(g2)'"') ("`what' `xs'") (`onum') ("`etxt'") ///
                        (`nscope') (`"`macval(scope)'"') (`"`macval(fmsg)'"') (.) (`om')
                }
                if `nf_v' == 0 {
                    local ntst = 0
                    forvalues k = 1/`G' {
                        local ntst = `ntst' + `tst_`k''
                    }
                    local pmsg `"`pfx'groupstat(`sname' `v'): every tested group within `etxt'"'
                    frame post `rf' ("groupstat") ("`kind'") (1) ("`sname' `v'") ("`v'") ///
                        (`"`macval(grp)'"') ("`ntst' groups within band") (.) ("`etxt'") ///
                        (`nscope') (`"`macval(scope)'"') (`"`macval(pmsg)'"') (.) (0)
                }
            }
        }
    }
    local rc = _rc
    if `_fr_made' capture frame drop `fr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return scalar isgate = `isgate'
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
end
