*! _dataprobe_reconcile Version 2.1.0  2026/11/16
*! dataprobe reconcile(): row, id and total conservation against a saved file
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (internal helper)

// Spec: filename [, n ids(varname) sum(varlist) by(varlist)
//                   expect(eq|le|ge) tol(#)]
//
// Compares dataprobe's working sample (memory) with a saved .dta (a
// checkpoint): n the row count, ids() the distinct nonmissing values of an
// id, sum() the total of each variable (missing values add nothing), by()
// the same per group, groups present on one side only counting zero on the
// other.  n is compared when given and when neither ids() nor sum() is.
// expect() is the relation memory must have to the file: eq (default), le
// (memory at most the file, after exclusions) or ge.  Counts compare
// exactly; a sum compares within tol() times the file's absolute total
// (default 1e-9, for the order of floating-point addition).  The file is
// read with a varlist (only ids, sum and by variables) into a frame; with n
// alone only its header is read.  The working sample is never sorted.
//
// One record per measure; with by() one more per measure, failed when any
// group fails.  Under mask() (m > 0): a count, the file's count and their
// difference are one triple, and when any of them is 1..m-1 every nonzero
// member is withheld and the difference prints as its direction only.  The
// totals of sum() are never printed under the mask, only their relative
// difference, which is withheld when the row or id difference, or either
// side's row count, is 1..m-1 (the difference would then be a value of
// those few rows).  by() groups print by their display label; a group with
// 1..m-1 rows on either side is not named (counted in one line), and when
// any group's difference in a measure is withheld, every group line prints
// that measure as a direction only, since the group differences add up to
// the overall one.  A group of a by() variable in exclude(), and under
// safe() every group, is named by its number (group 3), as smallcells()
// names a stratum.  r(rdn) and r(rdi), the overall row and id differences
// (memory minus file), are unmasked.
program define _dataprobe_reconcile, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local rdn = .
    local rdi = .
    local vars ""
    local file ""
    local _ff_made = 0
    local _mf_made = 0
    tempname ff mf
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) MASK(integer 0) NSCOPE(real 0) ///
            SAFE(integer 0) EXCLuded(string)]
        local usage `"reconcile() entry must be "filename [, n ids(varname) sum(varlist) by(varlist) expect(eq|le|ge) tol(#)]""'
        local _sw = strtrim(`"`spec'"')
        local opts ""
        if substr(`"`_sw'"', 1, 1) == char(34) | substr(`"`_sw'"', 1, 2) == char(96) + char(34) {
            // a quoted filename may hold a comma or a space
            gettoken file rest : _sw
            local rest = strtrim(`"`rest'"')
            if substr(`"`rest'"', 1, 1) == "," local opts = substr(`"`rest'"', 2, .)
            else if `"`rest'"' != "" {
                display as error `"`usage': `spec'"'
                exit 198
            }
        }
        else {
            local cp = strpos(`"`_sw'"', ",")
            local file `"`_sw'"'
            if `cp' {
                local file = strtrim(substr(`"`_sw'"', 1, `cp' - 1))
                local opts = substr(`"`_sw'"', `cp' + 1, .)
            }
        }
        if `"`file'"' == "" {
            display as error `"`usage': `spec'"'
            exit 198
        }
        local 0 `", `opts'"'
        capture syntax [, N IDs(string) SUM(string) BY(string) EXPect(string) TOL(real 1e-9)]
        if _rc {
            display as error `"`usage': `spec'"'
            exit 198
        }
        local expect = lower(strtrim("`expect'"))
        if "`expect'" == "" local expect "eq"
        if !inlist("`expect'", "eq", "le", "ge") | `tol' < 0 {
            display as error "reconcile(): expect() must be eq, le, or ge and tol() 0 or more"
            exit 198
        }
        if "`ids'" != "" {
            unab ids : `ids'
            if `: word count `ids'' != 1 {
                display as error "reconcile(): ids() takes one variable"
                exit 198
            }
        }
        if "`sum'" != "" {
            unab sum : `sum'
            capture confirm numeric variable `sum'
            if _rc {
                display as error "reconcile(): sum() needs numeric variables: `sum'"
                exit 109
            }
        }
        if "`by'" != "" unab by : `by'
        local _ov : list by & sum
        if "`_ov'" == "" & "`ids'" != "" local _ov : list by & ids
        if "`_ov'" != "" {
            display as error "reconcile(): `_ov' cannot be in by() and in ids() or sum()"
            exit 198
        }
        local don = ("`n'" != "" | ("`ids'" == "" & "`sum'" == ""))
        local vars : list ids | sum
        local vars : list vars | by
        local vars = strtrim("`vars'")
        _datamap_validate_path `"`file'"', option(reconcile())
        capture confirm file `"`file'"'
        if _rc {
            // a name ending in .dta is the file itself (never foo.dta.dta);
            // _rc stays the first confirm's
            if lower(substr(`"`file'"', -4, 4)) != ".dta" capture confirm file `"`file'.dta"'
            if _rc {
                display as error `"reconcile(): file `file' not found"'
                exit 601
            }
            local file `"`file'.dta"'
        }
        capture quietly describe using `"`file'"', varlist
        if _rc {
            local _drc = _rc
            display as error `"reconcile(): cannot read `file' as a Stata dataset"'
            exit `_drc'
        }
        local fN = r(N)
        local fvars `"`r(varlist)'"'
        local _miss : list vars - fvars
        if "`_miss'" != "" {
            display as error `"reconcile(): `_miss' not found in `file'"'
            exit 111
        }
        if "`parseonly'" == "" {
            mata: st_local("fbase", pathrmsuffix(pathbasename(st_local("file"))))
            local m = `mask'
            local nsum : word count `sum'
            // ---- each side: overall values, and with by() one row per group ----
            tempvar f2 gn gi
            forvalues j = 1/`nsum' {
                tempvar gs`j'
            }
            local mN = c(N)
            local mI = 0
            local fI = 0
            if "`vars'" != "" {
                frame put `vars', into(`mf')
                local _mf_made = 1
                frame create `ff'
                local _ff_made = 1
                frame `ff' {
                    capture use `vars' using `"`file'"', clear
                    if _rc {
                        local _urc = _rc
                        display as error `"reconcile(): cannot read `vars' from `file'"'
                        exit `_urc'
                    }
                }
                foreach v of local sum {
                    frame `ff': capture confirm numeric variable `v'
                    if _rc {
                        display as error `"reconcile(): `v' is a string in `file'; sum() needs numbers"'
                        exit 109
                    }
                }
                foreach v of local by {
                    local tm : type `v'
                    frame `ff': local tf : type `v'
                    if (substr("`tm'", 1, 3) == "str") != (substr("`tf'", 1, 3) == "str") | ///
                        "`tm'" == "strL" | "`tf'" == "strL" {
                        display as error `"reconcile(): by() variable `v' is `tm' in memory and `tf' in `file'; groups need the same kind, and no strL"'
                        exit 106
                    }
                }
                foreach s in m f {
                    frame ``s'f' {
                        local `s'I = 0
                        if "`ids'" != "" {
                            // overall, then within by() groups: an id in two
                            // groups is one id overall
                            sort `ids'
                            // generate, then by-replace: on zero rows
                            // -by: generate- makes no variable at all
                            quietly generate byte `f2' = 0
                            quietly by `ids': replace `f2' = (_n == 1 & !missing(`ids'))
                            quietly count if `f2'
                            local `s'I = r(N)
                            if "`by'" != "" {
                                sort `by' `ids'
                                quietly by `by' `ids': replace `f2' = (_n == 1 & !missing(`ids'))
                            }
                        }
                        forvalues j = 1/`nsum' {
                            local v : word `j' of `sum'
                            quietly summarize `v', meanonly
                            local `s'S`j' = cond(r(N) == 0, 0, r(sum))
                        }
                        if "`by'" != "" {
                            sort `by'
                            quietly generate double `s'`gn' = .
                            quietly by `by': replace `s'`gn' = _N
                            quietly generate double `s'`gi' = 0
                            if "`ids'" != "" quietly by `by': replace `s'`gi' = sum(`f2')
                            forvalues j = 1/`nsum' {
                                local v : word `j' of `sum'
                                quietly generate double `s'`gs`j'' = .
                                quietly by `by': replace `s'`gs`j'' = sum(`v')
                            }
                            quietly by `by': keep if _n == _N
                            local kl "`by' `s'`gn' `s'`gi'"
                            forvalues j = 1/`nsum' {
                                local kl "`kl' `s'`gs`j''"
                            }
                            keep `kl'
                        }
                    }
                }
            }
            // ---- overall triples ----
            // r(): the row difference when rows are compared, the id
            // difference when ids() is; the masking rule reads both always
            local _dn = `mN' - `fN'
            local rdn = cond(`don', `_dn', .)
            local rdi = cond("`ids'" != "", `mI' - `fI', .)
            local _rel = cond("`expect'" == "eq", "equal to", cond("`expect'" == "le", "at most", "at least"))
            display ""
            display as text "RECONCILE: " as result "memory" as text " vs " as result "`fbase'" ///
                as text " (memory `_rel' `fbase')"
            local wsum = 0
            if `m' > 0 {
                foreach x in `mN' `fN' `_dn' `rdi' {
                    if `x' < . & abs(`x') >= 1 & abs(`x') < `m' local wsum = 1
                }
            }
            local meas ""
            if `don' local meas "rows"
            if "`ids'" != "" local meas "`meas' ids"
            forvalues j = 1/`nsum' {
                local meas "`meas' s`j'"
            }
            foreach q of local meas {
                if "`q'" == "rows" {
                    local a = `mN'
                    local b = `fN'
                    local qn "rows"
                    local qv ""
                }
                else if "`q'" == "ids" {
                    local a = `mI'
                    local b = `fI'
                    local qn "ids(`ids')"
                    local qv "`ids'"
                }
                else {
                    local j = substr("`q'", 2, .)
                    local a = `mS`j''
                    local b = `fS`j''
                    local qv : word `j' of `sum'
                    local qn "sum(`qv')"
                }
                local d = `a' - `b'
                local issum = (substr("`q'", 1, 1) == "s")
                _dataprobe_rcok `a' `b' `expect' `=cond(`issum', `tol', 0)'
                local ok = r(ok)
                local dir = cond(`d' < 0, "lower in memory", cond(`d' > 0, "higher in memory", "equal"))
                local qm = 0
                local mins = .
                if !`issum' {
                    local dir = cond(`d' < 0, "fewer in memory", cond(`d' > 0, "more in memory", "equal"))
                    local i = 0
                    foreach x in `a' `b' `=abs(`d')' {
                        local ++i
                        _dataprobe_mcount `x' `m'
                        local t`i' "`r(s)'"
                        if r(masked) local qm = 1
                        else local t`i' = strtrim(string(`x', "%20.0fc"))
                    }
                    if `qm' {
                        forvalues i = 1/3 {
                            if !inlist("`t`i''", "0", "<`m'") local t`i' "[suppressed]"
                        }
                    }
                    else local mins = min(cond(`a' >= 1, `a', .), cond(`b' >= 1, `b', .), cond(`d' != 0, abs(`d'), .))
                    local dt = cond(`d' == 0, "equal", cond(`qm', "`dir'", "`t3' `dir'"))
                    local obs "memory `t1', `fbase' `t2'; `dt'"
                }
                else {
                    local rr = cond(`b' != 0, `d' / abs(`b'), cond(`d' == 0, 0, .))
                    local rt = cond(`rr' < ., strtrim(string(100 * `rr', "%9.3g")) + "%", "n/a")
                    if `m' > 0 {
                        if `wsum' & `d' != 0 {
                            local rt "[suppressed]"
                            local qm = 1
                        }
                        local obs = "relative difference `rt'" + cond(`d' != 0, " (`dir')", "")
                    }
                    else {
                        local obs = "memory " + strtrim(string(`a', "%21.10g")) + ", `fbase' " + ///
                            strtrim(string(`b', "%21.10g")) + "; difference " + ///
                            strtrim(string(`d', "%21.10g")) + " (`rt')"
                    }
                }
                if `qm' local anymask = 1
                local ptxt = cond(`ok', "", "  [fails]")
                display as text "  `qn': " as result "`obs'" as error "`ptxt'"
                if !`ok' local ++nfail
                local exp = "memory `_rel' `fbase'" + cond(`issum', ", tol " + strtrim(string(`tol', "%9.3g")), "")
                local msg `"reconcile(`fbase'): `qn' — `obs', expected `exp'"'
                // under the mask a total is never stored: its difference
                // over the printed relative rate would give the file's total
                local onum = cond(`issum' & `m' > 0, ., `d')
                frame post `rf' ("reconcile") ("`kind'") (`ok') ("`fbase' `qn'") ("`qv'") ///
                    ("") ("`obs'") (`onum') ("`exp'") (`nscope') ("") (`"`macval(msg)'"') (`mins') (`qm')
            }
            // ---- by(): one row per group, both sides ----
            if "`by'" != "" {
                tempfile fg
                frame `ff': quietly save `"`fg'"'
                frame `mf' {
                    quietly merge 1:1 `by' using `"`fg'"', nogenerate
                    foreach s in m f {
                        // stata-dev-ignore: unchecked-commit — a private tempframe of group totals, never user data
                        quietly replace `s'`gn' = 0 if missing(`s'`gn')
                        quietly replace `s'`gi' = 0 if missing(`s'`gi')
                        forvalues j = 1/`nsum' {
                            quietly replace `s'`gs`j'' = 0 if missing(`s'`gs`j'')
                        }
                    }
                    local G = _N
                    tempvar small anyf
                    quietly generate byte `small' = 0
                    if `m' > 0 quietly replace `small' = (inrange(m`gn', 1, `m' - 1) | inrange(f`gn', 1, `m' - 1))
                    quietly generate byte `anyf' = 0
                    // per measure: fails, and whether any group's difference
                    // is withheld (then every group line is direction only)
                    foreach q of local meas {
                        if "`q'" == "rows" local pr "`gn'"
                        else if "`q'" == "ids" local pr "`gi'"
                        else local pr "`gs`=substr("`q'", 2, .)''"
                        tempvar x_`q'
                        local issum = (substr("`q'", 1, 1) == "s")
                        local tt = cond(`issum', `tol', 0)
                        if "`expect'" == "eq" quietly generate byte `x_`q'' = abs(m`pr' - f`pr') > `tt' * abs(f`pr')
                        else if "`expect'" == "le" quietly generate byte `x_`q'' = (m`pr' - f`pr') > `tt' * abs(f`pr')
                        else quietly generate byte `x_`q'' = (m`pr' - f`pr') < -`tt' * abs(f`pr')
                        quietly replace `anyf' = 1 if `x_`q''
                        local w_`q' = 0
                        if `m' > 0 {
                            if `issum' quietly count if (m`pr' != f`pr') & (`small' | ///
                                inrange(abs(m`gn' - f`gn'), 1, `m' - 1) | inrange(abs(m`gi' - f`gi'), 1, `m' - 1))
                            else quietly count if (m`pr' != f`pr') & (`small' | inrange(abs(m`pr' - f`pr'), 1, `m' - 1))
                            local w_`q' = (r(N) > 0)
                        }
                        quietly count if `x_`q''
                        local gf_`q' = r(N)
                    }
                    quietly count if `anyf'
                    local nfg = r(N)
                    quietly count if `anyf' & `small'
                    local nfs = r(N)
                    // under the mask a count of failing groups is masked as
                    // byrule() masks one (<m, all but <m).  The group lines
                    // number nfg - nfs, so when nfs is masked nfg and each
                    // measure's count are withheld too (2026-11-17)
                    local nfgs "`nfg'"
                    local nfss "`nfs'"
                    local _gsup = 0
                    if `m' > 0 {
                        _dataprobe_mcount `nfs' `m'
                        local nfss "`r(s)'"
                        local _gsup = r(masked)
                        _dataprobe_mcount `nfg' `m' `G'
                        local nfgs "`r(s)'"
                        if `_gsup' & !r(masked) & `nfg' > 0 local nfgs "[suppressed]"
                        if `_gsup' | r(masked) local anymask = 1
                    }
                    display as text "  by(`by'): " as result "`G'" as text " groups, " ///
                        as result "`nfgs'" as text " failing"
                    // a by() variable in exclude(), or safe: groups by number
                    local _bx : list by & excluded
                    local _bynum = (`safe' | "`_bx'" != "")
                    local shown = 0
                    forvalues g = 1/`G' {
                        if !`anyf'[`g'] | `small'[`g'] continue
                        local ++shown
                        if `shown' > 20 continue
                        if `_bynum' local gl "group `g'"
                        else {
                            _dataprobe_gtext `by', row(`g')
                            local gl `"`r(disp)'"'
                        }
                        local gt ""
                        foreach q of local meas {
                            if "`q'" == "rows" local pr "`gn'"
                            else if "`q'" == "ids" local pr "`gi'"
                            else local pr "`gs`=substr("`q'", 2, .)''"
                            local issum = (substr("`q'", 1, 1) == "s")
                            local dd = m`pr'[`g'] - f`pr'[`g']
                            local qn = cond("`q'" == "rows", "rows", cond("`q'" == "ids", "ids", ///
                                "sum " + word("`sum'", real(substr("`q'", 2, .)))))
                            if `issum' local dw = cond(`dd' < 0, "lower", cond(`dd' > 0, "higher", "equal"))
                            else local dw = cond(`dd' < 0, "fewer", cond(`dd' > 0, "more", "equal"))
                            local dv ""
                            if `dd' != 0 & !`w_`q'' {
                                if `issum' {
                                    local fb = f`pr'[`g']
                                    local dv = cond(`fb' != 0, strtrim(string(100 * `dd' / abs(`fb'), "%9.3g")) + "% ", "")
                                }
                                else local dv = strtrim(string(abs(`dd'), "%20.0fc")) + " "
                            }
                            local gt "`gt'`=cond("`gt'" == "", "", "; ")'`qn' `dv'`dw'"
                        }
                        display as text `"    `macval(gl)': "' as result "`gt'"
                    }
                    if `shown' > 20 display as text "    ... and " as result "`=`shown' - 20'" as text " more"
                    if `nfs' > 0 display as text "    groups with fewer than `m' rows on a side (not shown): " ///
                        as result "`nfss'" as text " failing"
                    foreach q of local meas {
                        if "`q'" == "rows" local qn "rows"
                        else if "`q'" == "ids" local qn "ids(`ids')"
                        else local qn "sum(`=word("`sum'", real(substr("`q'", 2, .)))')"
                        local qv = cond("`q'" == "rows", "", cond("`q'" == "ids", "`ids'", word("`sum'", real(substr("`q'", 2, .)))))
                        local ok = (`gf_`q'' == 0)
                        if !`ok' local ++nfail
                        local gfs "`gf_`q''"
                        local gfn = `gf_`q''
                        local gfm = 0
                        if `m' > 0 {
                            _dataprobe_mcount `gf_`q'' `m' `G'
                            local gfs "`r(s)'"
                            local gfn = r(num)
                            local gfm = r(masked)
                            if `_gsup' & !`gfm' & `gf_`q'' > 0 {
                                local gfs "[suppressed]"
                                local gfn = .
                                local gfm = 1
                            }
                            if `gfm' local anymask = 1
                        }
                        local obs "`gfs' of `G' groups fail"
                        local exp "memory `_rel' `fbase' in every group"
                        local msg `"reconcile(`fbase'): `qn' by(`by') — `obs', expected `exp'"'
                        frame post `rf' ("reconcile") ("`kind'") (`ok') ("`fbase' `qn' by(`by')") ///
                            ("`qv'") ("") ("`obs'") (`gfn') ("`exp'") (`nscope') ("") ///
                            (`"`macval(msg)'"') (.) (`gfm')
                    }
                }
            }
        }
    }
    local rc = _rc
    if `_mf_made' capture frame drop `mf'
    if `_ff_made' capture frame drop `ff'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return local file `"`file'"'
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
    return scalar rdn = `rdn'
    return scalar rdi = `rdi'
end

// does a (memory) stand in relation e to b (file), within t * |b|?
capture program drop _dataprobe_rcok
program define _dataprobe_rcok, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args a b e t
        if "`e'" == "eq" local ok = (abs(`a' - `b') <= `t' * abs(`b'))
        else if "`e'" == "le" local ok = ((`a' - `b') <= `t' * abs(`b'))
        else local ok = ((`a' - `b') >= -`t' * abs(`b'))
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar ok = `ok'
end
