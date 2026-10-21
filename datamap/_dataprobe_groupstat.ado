*! _dataprobe_groupstat Version 1.10.6  2026/10/21
*! dataprobe groupstat(): a statistic by group against the pooled value
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec (the entry's own "if" is split off and evaluated by dataprobe):
//   statistic varlist, by(groupvars) [min(#) band(lo hi) relative]
//   statistic statistic ...: varlist, by(groupvars) [min(#)]
//
// The colon form (one or more plain-word statistics, then a colon) prints
// one table with a column per statistic.  Each statistic runs the
// single-statistic code path below, so its ledger/record rows are exactly
// those of the corresponding single-statistic entry; only the display is
// merged.  A band() or relative is declared per statistic and is refused on
// an entry with two or more statistics (rc 198), as is a varlist of more
// than one variable with two or more statistics, and a statistic named twice.
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
program define _dataprobe_groupstat, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    local isgate = 0
    local _fr_made = 0
    local _cf_made = 0
    tempname fr
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0) COND(string) SCOPE(string) ///
            CELLFRAME(name) CELLIDX(integer 0) EXCLuded(string) NPRINT(integer 1) ///
            PROFile(string) PCAT(string) BYVARS(string) MHIDE(string) FHIDE(string) ///
            PHIDE(string) CAPped]
        local head `"`spec'"'
        local opts ""
        local cp = strpos(`"`spec'"', ",")
        if `cp' {
            local head = strtrim(substr(`"`spec'"', 1, `cp' - 1))
            local opts = substr(`"`spec'"', `cp' + 1, .)
        }
        local multi = 0
        local colp = strpos(`"`head'"', ":")
        if `colp' {
            local stlist = strtrim(substr(`"`head'"', 1, `colp' - 1))
            local head = strtrim(substr(`"`head'"', `colp' + 1, .))
            local nstat : word count `stlist'
            if `nstat' == 0 | `"`head'"' == "" {
                display as error `"groupstat() entry must be "statistic [statistic ...]: varlist, by(groupvars)": `spec'"'
                exit 198
            }
            local stnorm ""
            foreach s1 of local stlist {
                local s1 = lower("`s1'")
                if "`s1'" == "median" local s1 "p50"
                if !inlist("`s1'", "p1", "p5", "p10", "p25", "p50", "p75", "p90", "p95", "p99") & ///
                    !inlist("`s1'", "mean", "sd", "sum", "n", "distinct", "pmiss", "ess") {
                    display as error "groupstat(): statistic must be mean, sd, median, p1-p99, sum, n, distinct, pmiss, or ess; got `s1'"
                    exit 198
                }
                if `: list s1 in stnorm' {
                    display as error "groupstat(): statistic `s1' is listed twice (median and p50 are the same statistic)"
                    exit 198
                }
                local stnorm "`stnorm' `s1'"
            }
            local stnorm = strtrim("`stnorm'")
            if `nstat' == 1 {
                // one statistic before the colon is today's grammar
                local head "`stnorm' `head'"
            }
            else {
                local multi = 1
                if `nstat' > 6 {
                    display as error "groupstat(): at most 6 statistics per entry (one table column each); got `nstat'"
                    exit 198
                }
                local nhv : word count `head'
                capture unab hvars : `head'
                if _rc {
                    local _src = _rc
                    display as error `"groupstat(): cannot resolve the variables in: `spec'"'
                    exit `_src'
                }
                local nhv : word count `hvars'
                if `nhv' > 1 {
                    display as error "groupstat(): several statistics take one variable per entry (columns are one per statistic); use one groupstat() entry per variable"
                    exit 198
                }
                local 0 `", `opts'"'
                capture syntax , BY(varlist) [MIN(integer -1) BAND(numlist min=2 max=2) RELative]
                if _rc {
                    local _src = _rc
                    display as error `"groupstat() entry must be "statistic [statistic ...]: varlist, by(groupvars) [min(#)]": `spec'"'
                    if `_src' == 111 exit 111
                    exit 198
                }
                if "`band'" != "" | "`relative'" != "" {
                    display as error "groupstat(): band() and relative are declared per statistic; an entry with several statistics is a review item and takes neither. Write one groupstat() entry per banded statistic"
                    exit 198
                }
                foreach s1 of local stnorm {
                    if !inlist("`s1'", "n", "distinct", "pmiss") {
                        capture confirm numeric variable `hvars'
                        if _rc {
                            display as error "groupstat(): `hvars' is not numeric"
                            exit 109
                        }
                    }
                }
                local vars "`hvars' `by'"
                if "`parseonly'" == "" {
                    if `"`cond'"' == "" local cond "1"
                    tempname cf
                    frame create `cf' int si int kk str244 txt
                    local _cf_made = 1
                    local si = 0
                    foreach s1 of local stnorm {
                        local ++si
                        _dataprobe_groupstat, spec(`"`s1' `hvars', `opts'"') rf(`rf') ///
                            kind(`kind') grp(`"`macval(grp)'"') pfx(`"`macval(pfx)'"') ///
                            mask(`mask') nscope(`nscope') cond(`"`cond'"') ///
                            scope(`"`macval(scope)'"') cellframe(`cf') cellidx(`si') ///
                            excluded(`excluded') nprint(`nprint') profile(`profile') ///
                            pcat(`pcat') byvars(`byvars') mhide(`mhide') fhide(`fhide') ///
                            phide(`phide') `capped'
                        local _m1 = r(masked)
                        local _f1 = r(nfail)
                        if `_m1' local anymask = 1
                        local nfail = `nfail' + `_f1'
                    }
                    // one table: a column per statistic, the group labels and
                    // the small-group line taken from the first statistic
                    local nrow = 0
                    frame `cf' {
                        local ncf = _N
                        forvalues i = 1/`ncf' {
                            local _si = si[`i']
                            local _kk = kk[`i']
                            local _tx = txt[`i']
                            local t_`_si'_`_kk' `"`macval(_tx)'"'
                            if `_kk' > `nrow' local nrow = `_kk'
                        }
                    }
                    if `ncf' > 0 {
                        local sdisp ""
                        foreach s1 of local stlist {
                            local sdisp "`sdisp' `=lower("`s1'")'"
                        }
                        local sdisp = strtrim("`sdisp'")
                        display ""
                        display as text "GROUPSTAT " as result "`sdisp'" as text ": " as result "`hvars'" ///
                            as text " by(" as result "`by'" as text ")"
                        local hdr ""
                        foreach s1 of local sdisp {
                            local hdr `"`hdr' as text %10s abbrev("`s1'", 9)"'
                        }
                        display as text "  " %-16s "Group" `hdr'
                        forvalues k = 1/`nrow' {
                            if `"`t_0_`k''"' == "" continue
                            local line ""
                            forvalues j = 1/`nstat' {
                                local line `"`line' as result %10s `"`t_`j'_`k''"'"'
                            }
                            local gshow = substr(`"`t_0_`k''"', 1, 16)
                            display as text "  " as result %-16s `"`gshow'"' `line'
                        }
                        local line ""
                        forvalues j = 1/`nstat' {
                            local line `"`line' as result %10s `"`t_`j'_0'"'"'
                        }
                        display as text "  " as text %-16s "pooled" `line'
                        if `"`t_0_0'"' != "" display as text `"  `macval(t_0_0)'"'
                    }
                }
            }
        }
        if `multi' == 0 {
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
            if `G' == 0 {
                // no row of the entry scope has a nonmissing group: nothing
                // is tested, so a band fails and a review item says so
                display ""
                display as text "GROUPSTAT " as result "`sname'" as text " by(" as result "`byv'" ///
                    as text ")"
                foreach v of local gvars {
                    local rmsg `"`pfx'groupstat(`sname' `v', by(`byv')): no rows in scope"'
                    display as text "  " as result `"`macval(rmsg)'"'
                    frame post `rf' ("groupstat") ("review") (2) ("`sname' `v'") ("`v'") ///
                        (`"`macval(grp)'"') ("no rows in scope") (.) ("by(`byv')") ///
                        (`nscope') (`"`macval(scope)'"') (`"`macval(rmsg)'"') (.) (0)
                    if !`isgate' continue
                    local etxt = cond("`relative'" != "", "ratio to pooled in [`lo', `hi']", "[`lo', `hi']")
                    local fmsg `"`pfx'groupstat(`sname' `v'): no rows in scope, expected `etxt'"'
                    frame post `rf' ("groupstat") ("`kind'") (0) ("`sname' `v'") ("`v'") ///
                        (`"`macval(grp)'"') ("no rows in scope") (.) ("`etxt'") ///
                        (`nscope') (`"`macval(scope)'"') (`"`macval(fmsg)'"') (.) (0)
                    local ++nfail
                }
            }
            else {
                local glab : value label `g'
                quietly generate byte `one' = 1
                local nv : word count `gvars'
                // per-group values: one row per group in frame fr
                local keep "`g' `one'"
                local j = 0
                foreach v of local gvars {
                    local ++j
                    tempvar gv`j' nle`j' nge`j' nn`j' w2`j' t2`j' tg`j' nlo`j' nhi`j'
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
                        if "`st'" == "sd" {
                            // sd: rows at the group's minimum and maximum,
                            // which are all its rows when it has two values
                            // (see _dataprobe_qshow)
                            tempvar mn`j' mx`j' md`j' mdx`j'
                            quietly by `g': egen double `mn`j'' = min(`v')
                            quietly by `g': egen double `mx`j'' = max(`v')
                            quietly by `g': egen long `nle`j'' = total(`v' == `mn`j'' & !missing(`v'))
                            quietly by `g': egen long `nge`j'' = total(`v' == `mx`j'' & !missing(`v'))
                            // a third value: the rows strictly between the
                            // minimum and maximum, kept in nlo when they all
                            // hold one value (nhi = 1), as in _dataprobe_qshow
                            quietly by `g': egen double `md`j'' = min(cond(`v' > `mn`j'' & `v' < `mx`j'', `v', .))
                            quietly by `g': egen double `mdx`j'' = max(cond(`v' > `mn`j'' & `v' < `mx`j'', `v', .))
                            quietly by `g': egen long `nlo`j'' = total(`v' > `mn`j'' & `v' < `mx`j'' & !missing(`v'))
                            quietly by `g': egen byte `nhi`j'' = max(!missing(`md`j'') & `md`j'' == `mdx`j'')
                        }
                        else {
                            quietly by `g': egen long `nle`j'' = total(`v' <= `gv`j'' & !missing(`v'))
                            quietly by `g': egen long `nge`j'' = total(`v' >= `gv`j'' & !missing(`v'))
                        }
                        quietly by `g': egen long `nn`j'' = count(`v')
                        local keep "`keep' `gv`j'' `nle`j'' `nge`j'' `nn`j''"
                        if "`st'" == "sd" local keep "`keep' `nlo`j'' `nhi`j''"
                    }
                    else if "`st'" == "sum" {
                        quietly bysort `g': egen double `gv`j'' = total(`v') if !missing(`g')
                        quietly by `g': egen long `nn`j'' = count(`v')
                        // a sum is a value of its rows (see _dataprobe_statval):
                        // nonzero rows in nle, rows at the group's minimum and
                        // maximum in nlo and nhi
                        tempvar mn`j' mx`j'
                        quietly by `g': egen long `nle`j'' = total(`v' != 0 & !missing(`v'))
                        quietly by `g': egen double `mn`j'' = min(`v')
                        quietly by `g': egen double `mx`j'' = max(`v')
                        quietly by `g': egen long `nlo`j'' = total(`v' == `mn`j'' & !missing(`v'))
                        quietly by `g': egen long `nhi`j'' = total(`v' == `mx`j'' & !missing(`v') & `mx`j'' > `mn`j'')
                        local keep "`keep' `gv`j'' `nle`j'' `nlo`j'' `nhi`j'' `nn`j''"
                    }
                    else if "`st'" == "n" {
                        quietly bysort `g': egen double `gv`j'' = count(`v') if !missing(`g')
                        quietly by `g': egen long `nn`j'' = total(!missing(`v'))
                        local keep "`keep' `gv`j'' `nn`j''"
                    }
                    else if "`st'" == "distinct" {
                        quietly egen byte `tg`j'' = tag(`g' `v') if !missing(`g') & !missing(`v')
                        quietly bysort `g': egen double `gv`j'' = total(`tg`j'') if !missing(`g')
                        quietly by `g': egen long `nn`j'' = total(!missing(`v'))
                        local keep "`keep' `gv`j'' `nn`j''"
                    }
                    else {
                        quietly generate double `w2`j'' = `v'^2
                        quietly bysort `g': egen double `t2`j'' = total(`w2`j'') if !missing(`g')
                        quietly by `g': egen double `gv`j'' = total(`v') if !missing(`g')
                        quietly replace `gv`j'' = cond(`t2`j'' > 0, `gv`j''^2 / `t2`j'', .)
                        quietly by `g': egen long `nn`j'' = count(`v')
                        // nonzero weights, held in nle: the ess of a 0/1
                        // weight is their count (see _dataprobe_statval)
                        quietly by `g': egen long `nle`j'' = total(`v' != 0 & !missing(`v'))
                        local keep "`keep' `gv`j'' `nle`j'' `nn`j''"
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
                            if "`nle`j''" != "" & !_rc local agg "`agg' `nle`j''"
                            if "`nge`j''" != "" capture confirm variable `nge`j''
                            if "`nge`j''" != "" & !_rc local agg "`agg' `nge`j''"
                            capture confirm variable `nlo`j''
                            if !_rc local agg "`agg' `nlo`j'' `nhi`j''"
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
                                local val_`k'_`j' = regexr(string(`nmk' / `MNG'[1, `k'], "%21x"), "^[+]", "")
                                local nm_`k'_`j' = `nmk'
                                local ng_`k'_`j' = `MNG'[1, `k']
                            }
                            else {
                                local val_`k'_`j' = regexr(string(`gv`j''[`k'], "%21x"), "^[+]", "")
                                local nn_`k'_`j' = `nn`j''[`k']
                                capture confirm variable `nle`j''
                                if !_rc local le_`k'_`j' = `nle`j''[`k']
                                capture confirm variable `nge`j''
                                if !_rc local ge_`k'_`j' = `nge`j''[`k']
                                capture confirm variable `nlo`j''
                                if !_rc {
                                    local lo_`k'_`j' = `nlo`j''[`k']
                                    local hi_`k'_`j' = `nhi`j''[`k']
                                }
                            }
                        }
                    }
                }
                capture frame drop `fr'
                local _fr_made = 0

                // pooled values over the rows of the groups: a row whose by()
                // value is missing is in no group, and counting it in the
                // pooled value only made the pool disagree with its groups
                // (and, under maskrare, recoverable as pooled minus groups)
                tempvar inpool
                quietly generate byte `inpool' = `in' & !missing(`g')
                local j = 0
                foreach v of local gvars {
                    local ++j
                    _dataprobe_statval `st' `v', cond(`"`inpool'"') mask(`mask') fmt(%10.4g)
                    local pool_`j' = regexr(string(r(value), "%21x"), "^[+]", "")
                    local pools_`j' `"`r(s)'"'
                    local pshown_`j' = r(shown)
                    if !r(shown) local anymask = 1
                }

                // display
                local reltxt = cond("`relative'" != "", "  (cells relative to pooled)", "")
                // cellframe(): the table is printed by the multi-statistic
                // caller, which collects this statistic's cells
                if "`cellframe'" == "" {
                    display ""
                    display as text "GROUPSTAT " as result "`sname'" as text " by(" as result "`byv'" ///
                        as text ")`reltxt'"
                    local hdr ""
                    foreach v of local gvars {
                        local hdr `"`hdr' as text %13s abbrev("`v'", 12)"'
                    }
                    display as text "  " %-24s "Group" `hdr'
                }
                local nsmall = 0
                // column width: 13 in this table, 10 in a multi-statistic one
                local _cw = cond("`cellframe'" == "", 13, 10)
                local j = 0
                foreach v of local gvars {
                    local ++j
                    local cm_`j' = 0
                    // date display, as _dataprobe_qshow: a daily date at month
                    // precision under the mask, a %tc date by its day's month
                    local _vf : format `v'
                    local _vf = subinstr("`_vf'", "%-", "%", 1)
                    local isdate_`j' = (substr("`_vf'", 1, 2) == "%t" | substr("`_vf'", 1, 2) == "%d")
                    local isday_`j' = (strpos("`_vf'", "%td") | substr("`_vf'", 1, 2) == "%d") > 0
                    local istc_`j' = (strpos("`_vf'", "%tc") | strpos("`_vf'", "%tC")) > 0
                    local dfmt_`j' "`_vf'"
                    if `mask' > 0 & (strpos("`_vf'", "%td") | substr("`_vf'", 1, 2) == "%d") local dfmt_`j' "%tdCCYY-NN"
                    // exclude(): a variable's contents are withheld
                    local exc_`j' : list v in excluded
                }
                // dataprobe's profile pools a by() group whose counts it
                // cannot show (phide: its rows); with the call's by(), that
                // group is pooled here too
                local _phon = (`mask' > 0 & "`phide'" != "" & "`byvars'" != "")
                if `_phon' local _phon : list byv === byvars
                forvalues k = 1/`G' {
                    local ph_`k' = 0
                    if `_phon' {
                        quietly count if `g' == `k' & `phide' == 1
                        local ph_`k' = (r(N) > 0)
                    }
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
                    if `n_`k'' < `gmin' | `ph_`k'' {
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
                        local x = regexr(string(`val_`k'_`j'', "%21x"), "^[+]", "")
                        local shown = 1
                        local _cpl = 0
                        if missing(`x') local s "."
                        else if "`st'" == "pmiss" {
                            // as stat(pmiss): a small missing or nonmissing
                            // count in the group masks the share
                            local _nmc = `nm_`k'_`j''
                            local _nnc = `ng_`k'_`j'' - `nm_`k'_`j''
                            if `mask' > 0 & ((`_nmc' >= 1 & `_nmc' < `mask') | ///
                                (`_nnc' >= 1 & `_nnc' < `mask')) local shown = 0
                            local s = strtrim(string(`x', "%10.4g"))
                        }
                        else if inlist("`st'", "sum", "n", "distinct") {
                            // as stat(): a count whose complement in the
                            // group's rows, or its nonmissing rows, is a
                            // small cell gives that cell back
                            if `mask' > 0 & `x' >= 1 & `x' == floor(`x') {
                                if `x' < `mask' local shown = 0
                                else if (`n_`k'' - `x' >= 1 & `n_`k'' - `x' < `mask') | ///
                                    (`nn_`k'_`j'' - `x' >= 1 & `nn_`k'_`j'' - `x' < `mask') {
                                    local shown = 0
                                    local _cpl = 1
                                }
                            }
                            // a sum is a value of its rows: masked when the
                            // nonmissing, the nonzero, or (two values) either
                            // value's rows number 1 to mask-1
                            if `mask' > 0 & `shown' & "`st'" == "sum" {
                                local _nnc = `nn_`k'_`j''
                                local _nzc = `le_`k'_`j''
                                local _two = (`hi_`k'_`j'' > 0 & `lo_`k'_`j'' + `hi_`k'_`j'' == `_nnc')
                                if (`_nnc' >= 1 & `_nnc' < `mask') | (`_nzc' >= 1 & `_nzc' < `mask') | ///
                                    (`_two' & (`lo_`k'_`j'' < `mask' | `hi_`k'_`j'' < `mask')) {
                                    local shown = 0
                                    local _cpl = 1
                                }
                            }
                            local s = strtrim(string(`x', "%10.4g"))
                        }
                        else if "`st'" == "sd" | "`st'" == "ess" {
                            if `mask' > 0 & `nn_`k'_`j'' < `mask' local shown = 0
                            // sd of a two-valued variable: each value's rows
                            // (le, ge: rows at the min and max) must reach
                            // the mask, as in _dataprobe_qshow
                            else if `mask' > 0 & "`st'" == "sd" {
                                if `le_`k'_`j'' + `ge_`k'_`j'' == `nn_`k'_`j'' & ///
                                    (`le_`k'_`j'' < `mask' | `ge_`k'_`j'' < `mask') local shown = 0
                                // three values (nlo rows of one middle value)
                                else if `hi_`k'_`j'' == 1 & ///
                                    `le_`k'_`j'' + `ge_`k'_`j'' + `lo_`k'_`j'' == `nn_`k'_`j'' & ///
                                    (`le_`k'_`j'' < `mask' | `ge_`k'_`j'' < `mask' | ///
                                    `lo_`k'_`j'' < `mask') local shown = 0
                            }
                            // ess: the nonzero (le) and zero weights are
                            // counts, as in _dataprobe_statval
                            else if `mask' > 0 & "`st'" == "ess" {
                                local _nzc = `le_`k'_`j''
                                local _zc = `nn_`k'_`j'' - `_nzc'
                                if (`_nzc' >= 1 & `_nzc' < `mask') | ///
                                    (`_zc' >= 1 & `_zc' < `mask') local shown = 0
                            }
                            local s = strtrim(string(`x', "%10.4g"))
                        }
                        else {
                            if `mask' > 0 & (`le_`k'_`j'' < `mask' | `ge_`k'_`j'' < `mask') local shown = 0
                            local s = strtrim(string(`x', "%10.4g"))
                            // a date's mean or percentile prints as a date,
                            // at month precision under the mask, as stat()
                            // and the pooled value do (_dataprobe_qshow)
                            if `isdate_`j'' & "`relative'" == "" & !missing(`x') {
                                if `mask' > 0 & `istc_`j'' local s = string(dofc(`x'), "%tdCCYY-NN")
                                else local s = strtrim(string(`x', "`dfmt_`j''"))
                            }
                        }
                        if !`shown' {
                            local s = cond(inlist("`st'", "sum", "n", "distinct"), "<`mask'", ///
                                "[suppr.]")
                            // a complement cell: the count itself is large
                            if `_cpl' local s "[suppr.]"
                            local anymask = 1
                            local cm_`j' = 1
                        }
                        local sh_`k'_`j' = `shown'
                        local s_`k'_`j' "`s'"
                        // every cell fits its column
                        if `shown' & !missing(`x') & !`exc_`j'' {
                            _dataprobe_gsfit `x', s(`"`s_`k'_`j''"') w(`_cw') ///
                                date(`isday_`j'') tc(`istc_`j'')
                            local s_`k'_`j' `"`r(s)'"'
                        }
                        if `exc_`j'' & !missing(`x') local s_`k'_`j' "[excluded]"
                    }
                }
                // Profile totals (dataprobe passes them in profile mode under
                // the mask).  With the call's by(), a group whose missing
                // count (n, pmiss) or count of ones (sum of a 0/1 variable)
                // another block withholds is withheld here too.
                local _sameby = 0
                if `mask' > 0 & `"`profile'`pcat'"' != "" {
                    local _sameby = ("`byvars'" != "" & `: list byv === byvars')
                }
                local j = 0
                foreach v of local gvars {
                    local ++j
                    local _is01_`j' = 0
                    if `mask' == 0 | `"`profile'`pcat'"' == "" continue
                    if "`st'" == "sum" & `: list v in pcat' {
                        quietly count if !missing(`v') & !inlist(`v', 0, 1)
                        local _is01_`j' = (r(N) == 0)
                    }
                    // flagged rows of the withheld groups
                    local _fl ""
                    local _flc ""
                    if `_sameby' & inlist("`st'", "n", "pmiss") {
                        local _pp : list posof "`v'" in mhide
                        if `_pp' > 0 {
                            local _fl : word `=`_pp' + 1' of `mhide'
                            local _flc "1"
                        }
                    }
                    if `_sameby' & `_is01_`j'' {
                        local _pp : list posof "`v'" in fhide
                        if `_pp' > 0 {
                            local _fl : word `=`_pp' + 1' of `fhide'
                            local _flc "`v' == 1"
                        }
                    }
                    if "`_fl'" != "" {
                        forvalues k = 1/`G' {
                            if `sup_`k'' continue
                            if !`sh_`k'_`j'' continue
                            quietly count if `g' == `k' & `_fl' == 1 & (`_flc')
                            if r(N) > 0 {
                                local sh_`k'_`j' = 0
                                local s_`k'_`j' "[suppr.]"
                                local cm_`j' = 1
                                local anymask = 1
                            }
                        }
                    }
                }
                // Pooled remainders of a count column (n, or the sum of a
                // 0/1 variable in profile mode).  A total of the column
                // minus its shown cells is the share of the pooled-away
                // groups, of the masked cells and of the rows outside the
                // cells; 1 to mask-1 of it gives a small cell back, and so
                // does its complement, the rows of the groups not shown
                // exactly minus that share, when it is 1 to mask-1 (one
                // group printed all but <m).  The totals: the cells' own
                // total over the pooled rows, set against the rows of the
                // groups (a review() or complete() item, a PASS line, or a
                // ledger row prints an N; the rows outside the entry's if
                // or with a missing by() value are no protection); the
                // call's N (a PASS line, the profile header, the ledger's
                // n_scope); and in profile mode the printed total (the
                // nonmissing count of a profiled variable, the ones of a
                // 0/1 categorical one), over all rows.  Each test
                // withholds the smallest shown cell (or, for the
                // complement, the cell with the smallest positive
                // complement), the first group on ties, until it holds.
                if `mask' > 0 {
                    local j = 0
                    foreach v of local gvars {
                        local ++j
                        if "`st'" != "n" & !`_is01_`j'' continue
                        if `exc_`j'' continue
                        // the cells' total over the pooled rows
                        local _T1 = 0
                        forvalues k = 1/`G' {
                            local _xk = `val_`k'_`j''
                            if !missing(`_xk') local _T1 = `_T1' + `_xk'
                        }
                        local _tots "`_T1'"
                        if "`st'" == "n" & `nprint' & `nscope' > 0 & `nscope' < . local _tots "`_tots' `nscope'"
                        if "`st'" == "n" & `: list v in profile' {
                            quietly count if !missing(`v')
                            local _tots "`_tots' `r(N)'"
                        }
                        if `_is01_`j'' {
                            quietly count if `v' == 1
                            local _tots "`_tots' `r(N)'"
                        }
                        local _ti = 0
                        foreach _T of local _tots {
                            local ++_ti
                            while 1 {
                                local _rem = `_T'
                                local _nm = 0
                                forvalues k = 1/`G' {
                                    local _xk = `val_`k'_`j''
                                    if !`sup_`k'' & `sh_`k'_`j'' & !missing(`_xk') local _rem = `_rem' - `_xk'
                                    else if `sup_`k'' | !`sh_`k'_`j'' {
                                        // the rows a hidden cell counts within
                                        if "`st'" == "n" local _nm = `_nm' + `n_`k''
                                        else local _nm = `_nm' + `nn_`k'_`j''
                                    }
                                }
                                local _rbad = (`_rem' >= 1 & `_rem' < `mask')
                                // the complement only against the cells' own
                                // total, the one whose rows are the groups'
                                local _cbad = 0
                                if `_ti' == 1 {
                                    local _crem = `_nm' - `_rem'
                                    local _cbad = (`_rem' >= 1 & `_crem' >= 1 & `_crem' < `mask')
                                }
                                if !`_rbad' & !`_cbad' continue, break
                                local _kmin = 0
                                local _xmin = .
                                forvalues k = 1/`G' {
                                    if `sup_`k'' continue
                                    if !`sh_`k'_`j'' continue
                                    local _xk = `val_`k'_`j''
                                    if missing(`_xk') continue
                                    if `_rbad' local _xc = `_xk'
                                    else if "`st'" == "n" local _xc = `n_`k'' - `_xk'
                                    else local _xc = `nn_`k'_`j'' - `_xk'
                                    if `_xc' > 0 & `_xc' < `_xmin' {
                                        local _xmin = `_xc'
                                        local _kmin = `k'
                                    }
                                }
                                if !`_kmin' continue, break
                                local sh_`_kmin'_`j' = 0
                                local s_`_kmin'_`j' "[suppr.]"
                                local cm_`j' = 1
                                local anymask = 1
                            }
                        }
                    }
                }
                // For n, sum, distinct, and pmiss (a share of a count) the
                // pooled value minus the shown groups would give back a
                // pooled-away group or a masked cell, so the pooled value is
                // withheld when either exists.
                local j = 0
                foreach v of local gvars {
                    local ++j
                    if `mask' > 0 & inlist("`st'", "sum", "n", "distinct", "pmiss") & (`nsmall' > 0 | `cm_`j'') {
                        local pools_`j' "[suppr.]"
                        local pshown_`j' = 0
                        local anymask = 1
                    }
                    if `exc_`j'' & !missing(`pool_`j'') local pools_`j' "[excluded]"
                }
                // With relative, a group's cell is its ratio to the pooled
                // value, the number band() tests; the pooled row stays raw.
                // A withheld pooled value withholds the ratios too, since a
                // shown ratio and a shown group value would give it back.
                forvalues k = 1/`G' {
                    if `sup_`k'' continue
                    local line ""
                    local j = 0
                    foreach v of local gvars {
                        local ++j
                        if "`relative'" != "" & `sh_`k'_`j'' & !missing(`val_`k'_`j'') {
                            if !`pshown_`j'' {
                                local s_`k'_`j' "[suppr.]"
                                local sh_`k'_`j' = 0
                                local anymask = 1
                            }
                            else if missing(`pool_`j'') | `pool_`j'' == 0 local s_`k'_`j' "."
                            else local s_`k'_`j' = strtrim(string(`val_`k'_`j'' / `pool_`j'', "%10.4g"))
                        }
                        // a masked cell reads [suppr.] in a ratio column: "<5"
                        // would read as a ratio below 5
                        else if "`relative'" != "" & !`sh_`k'_`j'' local s_`k'_`j' "[suppr.]"
                        if `exc_`j'' & !missing(`val_`k'_`j'') local s_`k'_`j' "[excluded]"
                        local line `"`line' as result %13s "`s_`k'_`j''""'
                    }
                    local gshow = substr(`"`gl_`k''"', 1, 24)
                    if "`cellframe'" == "" display as text "  " as result %-24s `"`gshow'"' `line'
                    else {
                        if `cellidx' == 1 frame post `cellframe' (0) (`k') (`"`macval(gl_`k')'"')
                        frame post `cellframe' (`cellidx') (`k') (`"`s_`k'_1'"')
                    }
                }
                // the pooled cell as printed: a withheld value reads
                // [suppr.], as a withheld cell does ([suppressed] and
                // all but <m overran a multi-statistic table's column), and
                // a shown one fits the column
                local line ""
                local j = 0
                foreach v of local gvars {
                    local ++j
                    local pdisp_`j' `"`pools_`j''"'
                    if !`pshown_`j'' & substr(`"`pools_`j''"', 1, 1) != "<" & "`pools_`j''" != "[excluded]" ///
                        local pdisp_`j' "[suppr.]"
                    else if `pshown_`j'' & !missing(`pool_`j'') & "`pools_`j''" != "[excluded]" {
                        _dataprobe_gsfit `pool_`j'', s(`"`pools_`j''"') w(`_cw') ///
                            date(`isday_`j'') tc(`istc_`j'')
                        local pdisp_`j' `"`r(s)'"'
                    }
                    local line `"`line' as result %13s "`pdisp_`j''""'
                }
                if "`cellframe'" == "" display as text "  " as text %-24s "pooled" `line'
                else frame post `cellframe' (`cellidx') (0) (`"`pdisp_1'"')
                if `nsmall' > 0 {
                    local smtxt "groups with fewer than `gmin' rows: `nsmall'"
                    if `mask' > 0 local smtxt "groups with <`gmin' rows: `nsmall'"
                    // dataprobe's linked-count check ran out of budget and
                    // pooled every group, whatever its size
                    if `_phon' & "`capped'" != "" local smtxt "groups pooled (the linked-count check ran out of budget): `nsmall'"
                    if "`cellframe'" == "" display as text `"  `smtxt'"'
                    else if `cellidx' == 1 frame post `cellframe' (0) (0) (`"`smtxt'"')
                }

                // records
                local j = 0
                foreach v of local gvars {
                    local ++j
                    local shownG = `G' - `nsmall'
                    local rmsg `"`pfx'groupstat(`sname' `v', by(`byv')): `shownG' group(s) shown, pooled `pools_`j''"'
                    // the record is masked when its table withheld anything:
                    // a cell, the pooled value, or a group below the mask
                    local _rmk = (`mask' > 0 & (`cm_`j'' | !`pshown_`j'' | `nsmall' > 0))
                    if `_rmk' local anymask = 1
                    frame post `rf' ("groupstat") ("review") (2) ("`sname' `v'") ("`v'") ///
                        (`"`macval(grp)'"') ("pooled `pools_`j''") (.) ("by(`byv')") ///
                        (`nscope') (`"`macval(scope)'"') (`"`macval(rmsg)'"') (.) (`_rmk')
                    if !`isgate' continue
                    local nf_v = 0
                    local etxt = cond("`relative'" != "", "ratio to pooled in [`lo', `hi']", "[`lo', `hi']")
                    // A percentile of a float variable is a float value;
                    // compare it with the float-rounded bound, as stat() does.
                    local blo "`lo'"
                    local bhi "`hi'"
                    if "`relative'" == "" & `isorder' & "`: type `v''" == "float" {
                        local blo "cond(missing(float(`lo')), `lo', float(`lo'))"
                        local bhi "cond(missing(float(`hi')), `hi', float(`hi'))"
                    }
                    // relative against a pooled value of 0 or missing: the
                    // ratio is undefined for every group, which fails once
                    // with that reason rather than as a "." per group
                    local rundef = ("`relative'" != "" & (missing(`pool_`j'') | `pool_`j'' == 0))
                    if `rundef' {
                        local ++nf_v
                        local ++nfail
                        local umsg `"`pfx'groupstat(`sname' `v'): ratio to pooled undefined, pooled `sname' `pools_`j'', expected `etxt'"'
                        frame post `rf' ("groupstat") ("`kind'") (0) ("`sname' `v'") ("`v'") ///
                            (`"`macval(grp)'"') ("pooled `pools_`j''") (.) ("`etxt'") ///
                            (`nscope') (`"`macval(scope)'"') (`"`macval(umsg)'"') (.) (!`pshown_`j'')
                    }
                    // direction of the failing groups: groups and in-scope rows
                    // above the band, below it, and (value undefined) neither
                    local dsum ""
                    if !`rundef' {
                        local ng_1 = 0
                        local ng_2 = 0
                        local ng_3 = 0
                        local nr_1 = 0
                        local nr_2 = 0
                        local nr_3 = 0
                        local rtot = 0
                        local sm_1 = 0
                        local sm_2 = 0
                        local sm_3 = 0
                        forvalues k = 1/`G' {
                            local rtot = `rtot' + `n_`k''
                            if !`tst_`k'' continue
                            local x = regexr(string(`val_`k'_`j'', "%21x"), "^[+]", "")
                            if "`relative'" != "" local x = regexr(string(`x' / `pool_`j'', "%21x"), "^[+]", "")
                            if !missing(`x') & `x' >= `blo' & `x' <= `bhi' continue
                            local dd = cond(missing(`x'), 3, cond(`x' > `bhi', 1, 2))
                            local ++ng_`dd'
                            local nr_`dd' = `nr_`dd'' + `n_`k''
                            // a withheld or below-mask group inside a direction:
                            // the direction's row total could be that group's size
                            if `mask' > 0 & (`n_`k'' < `mask' | `sup_`k'') local sm_`dd' = 1
                        }
                        // rows of every direction that prints a count; what remains
                        // of rtot (passing rows plus the withheld directions) of
                        // 1 to mask-1 rows would give back a masked count
                        local rshown = 0
                        forvalues dd = 1/3 {
                            if `ng_`dd'' == 0 continue
                            // a withheld direction of mask rows or more gives nothing
                            // away; one under the mask prints <m, with all-but-<m
                            if `sm_`dd'' & `nr_`dd'' >= `mask' continue
                            local rshown = `rshown' + `nr_`dd''
                        }
                        local rpass = `rtot' - `rshown'
                        local dwith = (`mask' > 0 & `rpass' >= 1 & `rpass' < `mask')
                        local dwords "above below undefined"
                        forvalues dd = 1/3 {
                            if `ng_`dd'' == 0 continue
                            local dw : word `dd' of `dwords'
                            local rmk = 0
                            if `dwith' {
                                local rs "[suppressed]"
                                local rmk = 1
                            }
                            else if `sm_`dd'' & `nr_`dd'' >= `mask' {
                                // two or more such groups sum past the mask, and the
                                // sum would pin their sizes; fewer than the mask
                                // rows in all already prints as <m below
                                local rs "[suppressed]"
                                local anymask = 1
                            }
                            else {
                                _dataprobe_mcount `nr_`dd'' `mask' `rtot'
                                local rmk = r(masked)
                                local rs = cond(`rmk', "`r(s)'", strtrim(string(`nr_`dd'', "%20.0fc")))
                            }
                            // a masked row count pins each group to a small cell
                            // when the groups are many, so the group count follows
                            local gs = strtrim(string(`ng_`dd'', "%20.0fc"))
                            if `rmk' & `mask' > 0 & `ng_`dd'' >= 2 & `ng_`dd'' < `mask' local gs "<`mask'"
                            local gnoun = cond(`ng_`dd'' == 1 & "`gs'" != "<`mask'", "group", "groups")
                            if `rmk' local anymask = 1
                            if "`dw'" == "undefined" local piece `"`gs' `gnoun' undefined (rows `rs')"'
                            else local piece `"`gs' `gnoun' `dw' (rows `rs')"'
                            local dsum = cond(`"`dsum'"' == "", `"`piece'"', `"`dsum', `piece'"')
                        }
                    }
                    forvalues k = 1/`G' {
                        if `rundef' continue
                        if !`tst_`k'' continue
                        local x = regexr(string(`val_`k'_`j'', "%21x"), "^[+]", "")
                        if "`relative'" != "" local x = regexr(string(`x' / `pool_`j'', "%21x"), "^[+]", "")
                        if !missing(`x') & `x' >= `blo' & `x' <= `bhi' continue
                        local ++nf_v
                        local ++nfail
                        if `exc_`j'' {
                            // exclude(): the verdict, never the value
                            local xs "[excluded]"
                            local onum = .
                            local om = 0
                        }
                        else if `sh_`k'_`j'' {
                            // full precision, as stat() prints: a value just
                            // outside the band must not round onto its bound
                            local xs = strtrim(string(`x', "%14.0g"))
                            // a date: under the mask as the table prints it
                            // (month precision); without it the full value
                            // and, beside it, the date, since 1865.5 printed
                            // as 08feb1965 could round onto a bound
                            if `isdate_`j'' & "`relative'" == "" & !missing(`x') {
                                if `mask' > 0 local xs `"`s_`k'_`j''"'
                                else {
                                    // %21.0g for a %tc value (ms since 1960)
                                    _dataprobe_datefull `x' `dfmt_`j''
                                    local xs `"`r(s)'"'
                                }
                            }
                            local onum = regexr(string(`x', "%21x"), "^[+]", "")
                            local om = 0
                        }
                        else {
                            local xs "[suppressed]"
                            local onum = .
                            local om = 1
                        }
                        local what = cond("`relative'" != "", "ratio to pooled", "`sname'")
                        // a group withheld from the table is named by its
                        // number, never its values (as by() names a withheld
                        // group)
                        local gname `"`gl_`k''"'
                        if `sup_`k'' & `mask' > 0 local gname "#`k'"
                        local g2 `"by(`byv') = `gname'"'
                        if `sup_`k'' & `mask' > 0 local g2 "by(`byv' group `k')"
                        if `"`grp'"' != "" local g2 `"`grp'; `g2'"'
                        local fmsg `"`pfx'groupstat(`sname' `v'): `what' `xs' in group `gname', expected `etxt' [`dsum']"'
                        frame post `rf' ("groupstat") ("`kind'") (0) ("`sname' `v'") ("`v'") ///
                            (`"`macval(g2)'"') ("`what' `xs'; `dsum'") (`onum') ("`etxt'") ///
                            (`nscope') (`"`macval(scope)'"') (`"`macval(fmsg)'"') (.) (`om')
                    }
                    if `nf_v' == 0 {
                        local ntst = 0
                        forvalues k = 1/`G' {
                            local ntst = `ntst' + `tst_`k''
                        }
                        if `ntst' == 0 {
                            // min() left every group out: the band tested nothing
                            local pmsg `"`pfx'groupstat(`sname' `v'): no group has `bmin' or more rows, expected `etxt'"'
                            frame post `rf' ("groupstat") ("`kind'") (0) ("`sname' `v'") ("`v'") ///
                                (`"`macval(grp)'"') ("0 groups tested") (.) ("`etxt'") ///
                                (`nscope') (`"`macval(scope)'"') (`"`macval(pmsg)'"') (.) (0)
                            local ++nfail
                        }
                        else {
                            local pmsg `"`pfx'groupstat(`sname' `v'): every tested group within `etxt'"'
                            frame post `rf' ("groupstat") ("`kind'") (1) ("`sname' `v'") ("`v'") ///
                                (`"`macval(grp)'"') ("`ntst' groups within band") (.) ("`etxt'") ///
                                (`nscope') (`"`macval(scope)'"') (`"`macval(pmsg)'"') (.) (0)
                        }
                    }
                }
            }
        }
        }
        // end of the single-statistic path (if `multi' == 0)
    }
    local rc = _rc
    if `_fr_made' capture frame drop `fr'
    if `_cf_made' capture frame drop `cf'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return scalar isgate = `isgate'
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
end

// A groupstat cell that would overrun its column (w characters: 13 in a
// one-statistic table, 10 in a multi-statistic one) is shortened: a daily
// date, or the day of a %tc value, to Stata's %td (27sep1961), otherwise
// the value at %10.4g, as the group cells print.  A cell that fits is left
// as it is.
capture program drop _dataprobe_gsfit
local _drop_gsfit_rc = _rc
program define _dataprobe_gsfit, rclass
    version 16.0
    syntax anything(name=x), [S(string) W(integer 13) DATE(integer 0) TC(integer 0)]
    if ustrlen(`"`s'"') > `w' & (`date' | `tc') {
        if `tc' local s = string(dofc(`x'), "%td")
        else local s = string(floor(`x'), "%td")
    }
    if ustrlen(`"`s'"') > `w' local s = strtrim(string(`x', "%10.4g"))
    return local s `"`s'"'
end
