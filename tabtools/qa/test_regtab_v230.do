* test_regtab_v230.do - regtab 2.3.0 options and tabtools fitcount
* Covers, each on its happy path, its refusal paths, and a known answer:
*   B1  mi estimate, esampvaryok: the Observations row is e(N_mi), the count
*       mi estimate prints (was blank); RTX's mi estimate regress table
*   O1  cformat(%fmt) + sep() through Excel, CSV, Markdown, frame(), flat
*       frame, eplotframe() and r(table)
*   I2  frame(name, flat)
*   U2  reftop
*   U4  cellnote()
*   I1  tabtools fitcount + stats(events people exposure) + mincount()
*   F5  transpose
*   O4  footnote() paragraphs forwarded to every sink
* Every expected value is computed from the fit's own e(b)/r(table)/e() or
* from the fixture's design, never from the table regtab builds.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rv230
log using "test_regtab_v230.log", replace text name(_rv230)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local dash = uchar(8211)

* Trimmed contents of column `col' on the one row of frame `fr' whose trimmed
* label (variable `lv') is `label', searching from row `from'. Errors unless
* exactly one row matches.
capture program drop _v23_cell
program define _v23_cell, rclass
    version 17.0
    args fr lv label col from
    frame `fr' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(`lv') == `"`label'"' & _n >= `from'
        if r(N) != 1 {
            display as error `"frame `fr': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(`lv') == `"`label'"' & _n >= `from', meanonly
        local row = r(min)
        local cell = strtrim(`col'[`row'])
    }
    return local cell `"`cell'"'
    return scalar row = `row'
end

* The cell text for an estimate and interval, built by hand.
capture program drop _v23_ci
program define _v23_ci, rclass
    version 17.0
    args mat r c fmt sep
    local lo = `mat'[`r', `c']
    local hi = `mat'[`r' + 1, `c']
    return local ci = "(" + strtrim(string(`lo', "`fmt'")) + "`sep'" + strtrim(string(`hi', "`fmt'")) + ")"
end

* Whole text of a file, lines joined with "|".
capture program drop _v23_slurp
program define _v23_slurp, rclass
    version 17.0
    args fn
    tempname fh
    local all ""
    file open `fh' using `"`fn'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local all `"`macval(all)'|`macval(line)'"'
        file read `fh' line
    }
    file close `fh'
    return local text `"`macval(all)'"'
end

* Deterministic count fixture: 200 people with 2 intervals each. Group 3 has
* 3 events, group 4 has 1, groups 1 and 2 many; rows with keep == 0 or a
* missing x are outside the fit, so e(sample) is a strict subset.
capture program drop _v23_counts
program define _v23_counts
    version 17.0
    clear
    quietly set obs 400
    generate long id = ceil(_n / 2)
    generate byte grp = cond(id <= 80, 1, cond(id <= 160, 2, cond(id <= 185, 3, 4)))
    label define grp 1 "Group A" 2 "Group B" 3 "Group C" 4 "Group D"
    label values grp grp
    label variable grp "Exposure group"
    generate double pt = 0.5 + mod(_n, 7) / 7
    generate double x = mod(_n, 11) / 10
    replace x = . if mod(_n, 37) == 0
    generate byte keep = mod(_n, 50) != 1
    generate byte y = 0
    replace y = mod(_n, 3) == 0 if grp == 1
    replace y = mod(_n, 2) == 0 if grp == 2
    replace y = 2 in 200
    * group C: exactly three events, on rows inside the fit
    quietly count if grp == 3
    local c3 = 0
    forvalues r = 1/400 {
        if grp[`r'] == 3 & keep[`r'] & !missing(x[`r']) & `c3' < 3 {
            quietly replace y = 1 in `r'
            local ++c3
        }
    }
    * group D: one event, inside the fit
    local c4 = 0
    forvalues r = 1/400 {
        if grp[`r'] == 4 & keep[`r'] & !missing(x[`r']) & `c4' < 1 {
            quietly replace y = 1 in `r'
            local ++c4
        }
    }
    * an event outside the fit, which must never be counted
    replace y = 1 if keep == 0 & grp == 4
end

**# B1 mi estimate, esampvaryok
* The RTX pattern: mi estimate regress, noconstant vce(cluster id), one fit
* with esampvaryok on a sample that varies across imputations.
capture program drop _v23_midata
program define _v23_midata
    version 17.0
    clear
    set seed 12345
    quietly set obs 300
    generate long start_id = _n
    generate long id = ceil(_n / 2)
    generate byte cmp = 1 + mod(_n, 4)
    generate double y0 = 50000 + 12000 * (cmp == 2) - 8000 * (cmp == 3) + 3000 * (cmp == 4) + rnormal(0, 40000)
    quietly expand 6
    bysort start_id: generate m = _n - 1
    generate double dtotal = cond(m == 0, ., y0 + rnormal(0, 5000))
    generate double ovl = cond(m == 0, ., runiform() < .8)
    forvalues c = 2/4 {
        generate byte k`c' = cmp == `c'
    }
    keep start_id id cmp m dtotal ovl k2 k3 k4
    quietly mi import flong, m(m) id(start_id) imputed(dtotal ovl) clear
end

local ++test_count
capture noisily {
    _v23_midata
    collect clear
    quietly collect: mi estimate: regress dtotal k2 k3 k4, noconstant vce(cluster id)
    local n1 = e(N)
    matrix T1 = r(table)
    quietly collect: mi estimate, esampvaryok: regress dtotal k2 k3 k4 if ovl == 1, noconstant vce(cluster id)
    local n2 = e(N_mi)
    assert missing(e(N))
    matrix T2 = r(table)
    regtab, frame(_b1, replace) stats(n) cformat(%12.0fc) sep(" to ") nopvalue
    local r_n2 = r(n_2)
    * Observations: e(N) for the fixed sample, e(N_mi) (the count mi
    * estimate prints) for the varying one
    _v23_cell _b1 A "Observations" c1 4
    assert "`r(cell)'" == strtrim(string(`n1', "%12.0fc"))
    _v23_cell _b1 A "Observations" c3 4
    assert "`r(cell)'" == strtrim(string(`n2', "%12.0fc"))
    assert `r_n2' == `n2'
    * RTX's hand-built cells: estimate (lower to upper) in whole SEK
    forvalues j = 1/3 {
        local k = `j' + 1
        _v23_cell _b1 A "k`k'" c1 4
        assert "`r(cell)'" == strtrim(string(T1[1, `j'], "%12.0fc"))
        _v23_cell _b1 A "k`k'" c2 4
        _v23_ci T1 5 `j' %12.0fc " to "
        local want `"`r(ci)'"'
        _v23_cell _b1 A "k`k'" c2 4
        assert `"`r(cell)'"' == `"`want'"'
        _v23_cell _b1 A "k`k'" c3 4
        assert "`r(cell)'" == strtrim(string(T2[1, `j'], "%12.0fc"))
        _v23_ci T2 5 `j' %12.0fc " to "
        local want `"`r(ci)'"'
        _v23_cell _b1 A "k`k'" c4 4
        assert `"`r(cell)'"' == `"`want'"'
    }
}
if _rc == 0 {
    display as result "  PASS: B1 mi estimate esampvaryok N and RTX cells"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 mi estimate esampvaryok N and RTX cells (rc=`=_rc')"
    local ++fail_count
}

* Regression test for the blank Observations cell alone (2.2.0 printed
* nothing for the esampvaryok model), with no 2.3.0 option involved.
local ++test_count
capture noisily {
    _v23_midata
    collect clear
    quietly collect: mi estimate: regress dtotal k2 k3 k4, noconstant vce(cluster id)
    quietly collect: mi estimate, esampvaryok: regress dtotal k2 k3 k4 if ovl == 1, noconstant vce(cluster id)
    local n2 = e(N_mi)
    regtab, frame(_b1r, replace) stats(n)
    _v23_cell _b1r A "Observations" c4 4
    assert "`r(cell)'" == strtrim(string(`n2', "%12.0fc"))
}
if _rc == 0 {
    display as result "  PASS: B1r esampvaryok model's Observations cell is e(N_mi)"
    local ++pass_count
}
else {
    display as error "  FAIL: B1r esampvaryok Observations cell (rc=`=_rc')"
    local ++fail_count
}

**# O1 cformat() and sep() through every sink
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight i.foreign
    matrix T = r(table)
    local f "`output_dir'/_v23_cf"
    capture erase "`f'.xlsx"
    capture erase "`f'.csv"
    capture erase "`f'.md"
    regtab, xlsx("`f'.xlsx") sheet("CF") csv("`f'.csv") markdown("`f'.md") ///
        frame(_o1, replace) eplotframe(_o1e, replace) cformat(%12.0fc) sep(" to ")
    tempname R
    matrix `R' = r(table)
    * hand-built cells from the fit's own r(table)
    local wmpg_b = strtrim(string(T[1, 1], "%12.0fc"))
    _v23_ci T 5 1 %12.0fc " to "
    local wmpg_ci `"`r(ci)'"'
    _v23_ci T 5 5 %12.0fc " to "
    local wcons_ci `"`r(ci)'"'
    local wcons_b = strtrim(string(T[1, 5], "%12.0fc"))
    assert strpos("`wcons_ci'", ",") > 0
    * frame
    _v23_cell _o1 A "Mileage (mpg)" c1 4
    assert "`r(cell)'" == "`wmpg_b'"
    _v23_cell _o1 A "Mileage (mpg)" c2 4
    assert `"`r(cell)'"' == `"`wmpg_ci'"'
    _v23_cell _o1 A "Intercept" c1 4
    assert "`r(cell)'" == "`wcons_b'"
    _v23_cell _o1 A "Intercept" c2 4
    assert `"`r(cell)'"' == `"`wcons_ci'"'
    * r(table) and eplotframe() stay numeric at full precision
    assert reldif(`R'[1, 1], T[1, 1]) < 1e-12
    frame _o1e {
        quietly summarize ll if strtrim(label) == "Intercept", meanonly
        assert reldif(r(mean), T[5, 5]) < 1e-10
        quietly summarize ul if strtrim(label) == "Intercept", meanonly
        assert reldif(r(mean), T[6, 5]) < 1e-10
    }
    * Excel
    import excel using "`f'.xlsx", sheet("CF") clear allstring
    quietly count if strtrim(B) == "Intercept" & strtrim(C) == "`wcons_b'" & strtrim(D) == `"`wcons_ci'"'
    assert r(N) == 1
    * CSV and Markdown
    _v23_slurp "`f'.csv"
    local csv `"`r(text)'"'
    assert strpos(`"`csv'"', `""`wcons_ci'""') > 0
    _v23_slurp "`f'.md"
    assert strpos(`"`r(text)'"', `"| `wcons_ci' |"') > 0
}
if _rc == 0 {
    display as result "  PASS: O1a cformat(%12.0fc) sep(to) in frame, r(table), eplot, xlsx, csv, md"
    local ++pass_count
}
else {
    display as error "  FAIL: O1a cformat/sep sinks (rc=`=_rc')"
    local ++fail_count
}

* eform model: cformat applies to the exponentiated estimate and bounds
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg weight, or
    matrix T = r(table)
    regtab, frame(_o1b, replace) cformat(%9.4f)
    _v23_cell _o1b A "Mileage (mpg)" c1 4
    assert "`r(cell)'" == strtrim(string(T[1, 1], "%9.4f"))
    _v23_ci T 5 1 %9.4f ", "
    local want `"`r(ci)'"'
    _v23_cell _o1b A "Mileage (mpg)" c2 4
    assert `"`r(cell)'"' == `"`want'"'
    * cformat() with compact merges the formatted cells
    regtab, frame(_o1c, replace) cformat(%9.4f) compact
    _v23_cell _o1c A "Mileage (mpg)" c1 4
    assert `"`r(cell)'"' == strtrim(string(T[1, 1], "%9.4f")) + " " + `"`want'"'
}
if _rc == 0 {
    display as result "  PASS: O1b cformat() on an odds-ratio fit and with compact"
    local ++pass_count
}
else {
    display as error "  FAIL: O1b cformat() eform/compact (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    foreach bad in "%td" "%tc" "%9s" "%21x" "%-12s" "abc" "%9.2" {
        capture regtab, cformat(`bad')
        assert _rc == 198
    }
    capture regtab, cformat(%9.2f) digits(3)
    assert _rc == 198
    capture regtab, cformat(%9.2fc)
    assert _rc == 0
    capture regtab, cformat(%9.3g)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: O1c cformat() refuses date, string, hex formats and digits()"
    local ++pass_count
}
else {
    display as error "  FAIL: O1c cformat() refusals (rc=`=_rc')"
    local ++fail_count
}

**# I2 frame(name, flat)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.rep78
    quietly collect: regress price mpg i.rep78 weight
    regtab, frame(_i2, replace flat) models("Crude \ Adjusted") stats(n)
    regtab, frame(_i2r, replace) models("Crude \ Adjusted") stats(n)
    frame _i2 {
        confirm string variable rowlabel
        assert "`: variable label c1'" == "Crude, Coef."
        assert "`: variable label c2'" == "Crude, 95% CI"
        assert "`: variable label c3'" == "Crude, p-value"
        assert "`: variable label c4'" == "Adjusted, Coef."
        assert "`: char c4[tabtools_header]'" == "Adjusted, Coef."
        assert "`: char _dta[tabtools_layout]'" == "flat"
        capture confirm variable title
        assert _rc
        capture confirm variable ref1
        assert _rc
        capture confirm variable A
        assert _rc
        unab vv : *
        assert "`vv'" == "rowlabel c1 c2 c3 c4 c5 c6"
        * body only: no title or header rows
        assert strtrim(rowlabel[1]) == "Mileage (mpg)"
        local nflat = _N
    }
    * same body as the non-flat frame, cell for cell
    frame _i2r {
        assert _N - 3 == `nflat'
        local nr = _N
    }
    forvalues r = 4/`nr' {
        frame _i2r: local a = strtrim(A[`r'])
        frame _i2r: local b = strtrim(c5[`r'])
        frame _i2: assert strtrim(rowlabel[`r' - 3]) == "`a'"
        frame _i2: assert strtrim(c5[`r' - 3]) == "`b'"
    }
    _v23_cell _i2 rowlabel "Observations" c1 1
    assert "`r(cell)'" == "74" | "`r(cell)'" == "69"
    * puttab varlabels reproduces it with no drop: the header row is the labels
    local f "`output_dir'/_v23_flat.xlsx"
    capture erase "`f'"
    frame _i2: puttab rowlabel c1-c6 using "`f'", sheet("Flat") varlabels
    import excel using "`f'", sheet("Flat") clear allstring
    local hit_hdr = 0
    local hit_row = 0
    foreach v of varlist * {
        quietly count if strtrim(`v') == "Adjusted, 95% CI"
        if r(N) == 1 local hit_hdr = 1
    }
    assert `hit_hdr'
    frame _i2: local m_ci = strtrim(c5[1])
    quietly ds
    local vlist `r(varlist)'
    foreach v of local vlist {
        quietly count if strtrim(`v') == "`m_ci'"
        if r(N) >= 1 local hit_row = 1
    }
    assert `hit_row'
}
if _rc == 0 {
    display as result "  PASS: I2a frame(name, flat) contract and puttab varlabels round trip"
    local ++pass_count
}
else {
    display as error "  FAIL: I2a frame(name, flat) (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg weight
    regtab, frame(_i2c, flat replace) compact nopvalue
    frame _i2c {
        unab vv : *
        assert "`vv'" == "rowlabel c1"
        assert "`: variable label c1'" == "Model, OR 95% CI"
    }
    capture regtab, frame(_i2d, flatt)
    assert _rc == 198
    capture regtab, frame(_i2d, flat junk)
    assert _rc == 198
    * frame(name) without flat is unchanged: title, A, c1, ref1, ...
    regtab, frame(_i2e, replace)
    frame _i2e {
        confirm variable title A c1 ref1 c2 c3
        assert "`: char _dta[tabtools_layout]'" == ""
    }
}
if _rc == 0 {
    display as result "  PASS: I2b flat with compact/nopvalue, refusals, plain frame unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: I2b flat variants (rc=`=_rc')"
    local ++fail_count
}

**# U2 reftop
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg ib3.rep78
    regtab, frame(_u2a, replace)
    regtab, frame(_u2b, replace) reftop
    * without reftop the levels run 1..5; with it level 3 (the base) comes
    * first and the rest keep their order
    frame _u2a {
        quietly count if strtrim(A) == "Repair record 1978"
        assert r(N) == 1
    }
    _v23_cell _u2a A "Repair record 1978" A 4
    local h = r(row)
    frame _u2a: assert strtrim(A[`h' + 1]) == "1" & strtrim(A[`h' + 3]) == "3"
    _v23_cell _u2b A "Repair record 1978" A 4
    local h = r(row)
    frame _u2b {
        assert strtrim(A[`h' + 1]) == "3"
        assert strtrim(c1[`h' + 1]) == "Reference"
        assert strtrim(A[`h' + 2]) == "1"
        assert strtrim(A[`h' + 3]) == "2"
        assert strtrim(A[`h' + 4]) == "4"
        assert strtrim(A[`h' + 5]) == "5"
    }
    * the cells move with their rows
    _v23_cell _u2a A "4" c1 4
    local c4a "`r(cell)'"
    _v23_cell _u2b A "4" c1 4
    assert "`r(cell)'" == "`c4a'"
    * models holding different base levels of one factor: refused
    quietly collect: regress price mpg i.rep78
    capture regtab, reftop
    assert _rc == 198
    regtab, frame(_u2c, replace)
}
if _rc == 0 {
    display as result "  PASS: U2 reftop moves the base level first; conflicting bases refused"
    local ++pass_count
}
else {
    display as error "  FAIL: U2 reftop (rc=`=_rc')"
    local ++fail_count
}

**# U4 cellnote()
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight length
    regtab, frame(_u4, replace) eplotframe(_u4e, replace) ///
        cellnote("Weight (lbs.)" 2 "Not fitted: collinear" \ "Mileage (mpg)" 1 "12 / 3")
    tempname R
    matrix `R' = r(table)
    _v23_cell _u4 A "Weight (lbs.)" c4 4
    assert "`r(cell)'" == "Not fitted: collinear"
    _v23_cell _u4 A "Weight (lbs.)" c5 4
    assert "`r(cell)'" == ""
    _v23_cell _u4 A "Weight (lbs.)" c6 4
    assert "`r(cell)'" == ""
    _v23_cell _u4 A "Mileage (mpg)" c1 4
    assert "`r(cell)'" == "12 / 3"
    * the other model's cell on that row is untouched
    _v23_cell _u4 A "Weight (lbs.)" c1 4
    assert "`r(cell)'" != "" & "`r(cell)'" != "Not fitted: collinear"
    * r(table) and the plot frame no longer carry the replaced estimates
    assert missing(`R'[rownumb(`R', "Weight_(lbs_)"), 2])
    assert !missing(`R'[rownumb(`R', "Weight_(lbs_)"), 1])
    frame _u4e {
        quietly count if strtrim(label) == "Weight (lbs.)" & model == 2
        assert r(N) == 0
        quietly count if strtrim(label) == "Weight (lbs.)" & model == 1
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: U4a cellnote() replaces one model's cell by row label"
    local ++pass_count
}
else {
    display as error "  FAIL: U4a cellnote() (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    generate byte hi = price > 6000
    generate byte heavy = weight > 3000
    label define yn 0 "No" 1 "Yes"
    label values hi yn
    label values heavy yn
    collect clear
    quietly collect: regress mpg i.hi i.heavy
    * "Yes" labels two rows: refused, never the first match
    capture regtab, cellnote("Yes" 1 "x")
    assert _rc == 198
    capture regtab, cellnote("No such row" 1 "x")
    assert _rc == 198
    capture regtab, cellnote("Intercept" 2 "x")
    assert _rc == 198
    capture regtab, cellnote("Intercept" 0 "x")
    assert _rc == 198
    capture regtab, cellnote("Intercept" one "x")
    assert _rc == 198
    capture regtab, cellnote("Intercept" 1 "x" / "Intercept" 1 "y")
    assert _rc == 198
    capture regtab, cellnote("Intercept" 1 "x" \)
    assert _rc == 198
    * labels match exactly: case and spelling
    capture regtab, cellnote("intercept" 1 "x")
    assert _rc == 198
    regtab, frame(_u4b, replace) cellnote("Intercept" 1 "n/a")
    _v23_cell _u4b A "Intercept" c1 4
    assert "`r(cell)'" == "n/a"
}
if _rc == 0 {
    display as result "  PASS: U4b cellnote() exact-or-error refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: U4b cellnote() refusals (rc=`=_rc')"
    local ++fail_count
}

**# I1 tabtools fitcount
* Expected counts come from the fixture's design: the fit uses keep == 1 rows
* with a nonmissing x; nothing is read from e(sample).
local ++test_count
capture noisily {
    _v23_counts
    generate byte insamp = keep == 1 & !missing(x)
    quietly summarize y if insamp, meanonly
    local w_ev = r(sum)
    quietly summarize pt if insamp, meanonly
    local w_pt = r(sum)
    preserve
    quietly keep if insamp
    quietly duplicates drop id, force
    local w_pp = _N
    restore
    forvalues g = 1/4 {
        quietly summarize y if insamp & grp == `g', meanonly
        local w_g`g' = r(sum)
    }
    assert `w_g3' == 3 & `w_g4' == 1
    collect clear
    quietly collect: poisson y i.grp x if keep, exposure(pt) irr vce(cluster id)
    tabtools fitcount, events(y) people(id) exposure(pt) terms
    assert r(events) == `w_ev'
    assert r(people) == `w_pp'
    assert reldif(r(exposure), `w_pt') < 1e-12
    assert r(cmdset) == 1
    assert r(n_terms) == 4
    assert strpos(";" + "`r(terms)'" + ";", ";3.grp=3|1;") > 0
    assert strpos(";" + "`r(terms)'" + ";", ";4.grp=1|1;") > 0
    assert strpos(";" + "`r(terms)'" + ";", ";1.grp=`w_g1'|0;") > 0
    * the second model: no people or exposure
    quietly collect: poisson y i.grp if keep, exposure(pt) irr
    tabtools fitcount, events(y) terms
    local g_ev2 = r(events)
    quietly summarize y if keep, meanonly
    local w_ev2 = r(sum)
    assert `g_ev2' == `w_ev2'
    regtab, frame(_i1, replace) stats(n events people exposure) exposurelabel("Person-years")
    assert r(events_1) == `w_ev'
    assert r(people_1) == `w_pp'
    assert reldif(r(exposure_1), `w_pt') < 1e-12
    assert r(events_2) == `w_ev2'
    _v23_cell _i1 A "Events" c1 4
    assert "`r(cell)'" == strtrim(string(`w_ev', "%12.0fc"))
    _v23_cell _i1 A "Events" c4 4
    assert "`r(cell)'" == strtrim(string(`w_ev2', "%12.0fc"))
    _v23_cell _i1 A "People" c1 4
    assert "`r(cell)'" == strtrim(string(`w_pp', "%12.0fc"))
    _v23_cell _i1 A "People" c4 4
    assert "`r(cell)'" == ""
    _v23_cell _i1 A "Person-years" c1 4
    assert "`r(cell)'" == strtrim(string(`w_pt', "%12.0fc"))
    capture regtab, stats(events) exposurelabel("Person-years")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: I1a fitcount counts on e(sample) and regtab stats(events people exposure)"
    local ++pass_count
}
else {
    display as error "  FAIL: I1a fitcount and stats rows (rc=`=_rc')"
    local ++fail_count
}

* fit-time contract: the counts belong to exactly the latest collected fit
local ++test_count
capture noisily {
    _v23_counts
    collect clear
    * no collected model
    quietly poisson y i.grp, exposure(pt)
    capture tabtools fitcount, events(y)
    assert _rc == 119
    quietly collect: poisson y i.grp, exposure(pt)
    * a later uncollected fit is not the collected model
    quietly poisson y i.grp x, exposure(pt)
    capture tabtools fitcount, events(y)
    assert _rc == 459
    * the data changed after the fit: e(sample) no longer has e(N) rows
    quietly collect: poisson y i.grp, exposure(pt)
    preserve
    quietly drop in 1/10
    capture tabtools fitcount, events(y)
    assert _rc == 459
    restore
    * bad event and exposure variables
    generate double yneg = -y
    capture tabtools fitcount, events(yneg)
    assert _rc == 459
    generate double yhalf = y / 2
    capture tabtools fitcount, events(yhalf)
    assert _rc == 459
    generate double ptm = pt
    replace ptm = . in 3
    capture tabtools fitcount, events(y) exposure(ptm)
    assert _rc == 459
    * no estimation results
    ereturn clear
    capture tabtools fitcount, events(y)
    assert _rc == 301
    * mi estimate results carry no single sample
    _v23_midata
    collect clear
    quietly collect: mi estimate: regress dtotal k2 k3 k4, noconstant
    capture tabtools fitcount, events(k2)
    assert _rc == 198
    * the sort order of the data is left alone
    _v23_counts
    generate long order = _n
    gsort -pt id
    generate long order2 = _n
    collect clear
    quietly collect: poisson y i.grp, exposure(pt)
    tabtools fitcount, events(y) people(id)
    assert order2 == _n
}
if _rc == 0 {
    display as result "  PASS: I1b fitcount refuses a fit that is not the latest collected model"
    local ++pass_count
}
else {
    display as error "  FAIL: I1b fitcount fit-time contract (rc=`=_rc')"
    local ++fail_count
}

* survival: events from fitcount equal stcox's e(N_fail); without fitcount the
* existing e(N_fail) path still fills the row
local ++test_count
capture noisily {
    _v23_counts
    generate double t = 1 + mod(_n * 7, 13)
    quietly stset t, failure(y)
    quietly count if _d == 1 & grp != .
    collect clear
    quietly collect: stcox i.grp
    local nfail = e(N_fail)
    quietly collect: stcox i.grp x
    local nfail2 = e(N_fail)
    tabtools fitcount, events(_d) people(id)
    regtab, frame(_i1s, replace) stats(events people)
    assert r(events_1) == `nfail'
    assert r(events_2) == `nfail2'
    _v23_cell _i1s A "People" c1 4
    assert "`r(cell)'" == ""
    _v23_cell _i1s A "People" c4 4
    assert "`r(cell)'" != ""
}
if _rc == 0 {
    display as result "  PASS: I1c events from fitcount and from e(N_fail) side by side"
    local ++pass_count
}
else {
    display as error "  FAIL: I1c survival events (rc=`=_rc')"
    local ++fail_count
}

**# I1 mincount()
local ++test_count
capture noisily {
    _v23_counts
    collect clear
    quietly collect: poisson y i.grp x if keep, exposure(pt) irr
    matrix T = r(table)
    tabtools fitcount, events(y) terms
    regtab, frame(_mc, replace) eplotframe(_mce, replace) mincount(5)
    assert r(N_masked) == 2
    tempname R
    matrix `R' = r(table)
    * group C (3 events) and D (1 event) are masked; B shows; A is the base
    _v23_cell _mc A "Group C" c1 4
    assert `"`r(cell)'"' == "`dash'"
    _v23_cell _mc A "Group C" c2 4
    assert "`r(cell)'" == ""
    _v23_cell _mc A "Group C" c3 4
    assert "`r(cell)'" == ""
    _v23_cell _mc A "Group D" c1 4
    assert `"`r(cell)'"' == "`dash'"
    _v23_cell _mc A "Group A" c1 4
    assert "`r(cell)'" == "Reference"
    _v23_cell _mc A "Group B" c1 4
    assert "`r(cell)'" == strtrim(string(round(T[1, 2], 0.01), "%32.2f"))
    frame _mce {
        quietly count if inlist(strtrim(label), "Group C", "Group D")
        assert r(N) == 0
    }
    * mincount(1) shows both again; mincount(4) masks only group D
    regtab, frame(_mc1, replace) mincount(1)
    assert r(N_masked) == 0
    _v23_cell _mc1 A "Group C" c1 4
    assert "`r(cell)'" == strtrim(string(round(T[1, 3], 0.01), "%32.2f"))
    regtab, frame(_mc4, replace) mincount(4) emptylabel("n.r.")
    assert r(N_masked) == 2
    _v23_cell _mc4 A "Group C" c1 4
    assert "`r(cell)'" == "n.r."
    regtab, frame(_mc3, replace) mincount(3)
    assert r(N_masked) == 1
    _v23_cell _mc3 A "Group C" c1 4
    assert "`r(cell)'" != "`dash'"
}
if _rc == 0 {
    display as result "  PASS: I1d mincount() masks levels below the event threshold"
    local ++pass_count
}
else {
    display as error "  FAIL: I1d mincount() (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _v23_counts
    * a level the fit cannot estimate (collinear with z) is masked under
    * mincount() even with many events
    generate byte z = grp == 2
    collect clear
    quietly collect: poisson y z i.grp if keep, exposure(pt)
    tabtools fitcount, events(y) terms
    regtab, frame(_mco, replace)
    _v23_cell _mco A "Group B" c1 4
    local plain "`r(cell)'"
    assert inlist("`plain'", "Omitted", "Empty")
    regtab, frame(_mco2, replace) mincount(2)
    _v23_cell _mco2 A "Group B" c1 4
    assert `"`r(cell)'"' == "`dash'"
    * refusals: no fitcount, fitcount without terms, one model without counts
    collect clear
    quietly collect: poisson y i.grp, exposure(pt)
    capture regtab, mincount(5)
    assert _rc == 198
    tabtools fitcount, events(y)
    capture regtab, mincount(5)
    assert _rc == 198
    tabtools fitcount, events(y) terms
    quietly collect: poisson y i.grp x, exposure(pt)
    capture regtab, mincount(5)
    assert _rc == 198
    capture regtab, mincount(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: I1e mincount() masks inestimable levels; refuses missing counts"
    local ++pass_count
}
else {
    display as error "  FAIL: I1e mincount() refusals (rc=`=_rc')"
    local ++fail_count
}

* a 0/1 indicator entered as a plain variable is masked like a level
local ++test_count
capture noisily {
    _v23_counts
    generate byte flag = 0
    * two events and some non-events carry the flag, inside the fit
    local nf = 0
    forvalues r = 1/400 {
        if grp[`r'] == 2 & y[`r'] == 1 & keep[`r'] & !missing(x[`r']) & `nf' < 2 {
            quietly replace flag = 1 in `r'
            local ++nf
        }
    }
    quietly replace flag = 1 if grp == 1 & y == 0 & mod(_n, 5) == 0
    quietly summarize y if flag == 1 & keep & !missing(x), meanonly
    assert r(sum) == 2
    label variable flag "Comorbidity"
    collect clear
    quietly collect: poisson y i.grp flag x if keep, exposure(pt)
    tabtools fitcount, events(y) terms
    assert strpos(";" + "`r(terms)'" + ";", ";flag=2|1;") > 0
    * x is not 0/1, so it is not a counted term
    assert strpos("`r(terms)'", "x=") == 0
    regtab, frame(_mcf, replace) mincount(3)
    _v23_cell _mcf A "Comorbidity" c1 4
    assert `"`r(cell)'"' == "`dash'"
    _v23_cell _mcf A "x" c1 4
    assert `"`r(cell)'"' != "`dash'" & "`r(cell)'" != ""
    regtab, frame(_mcf2, replace) mincount(2)
    _v23_cell _mcf2 A "Comorbidity" c1 4
    assert `"`r(cell)'"' != "`dash'"
}
if _rc == 0 {
    display as result "  PASS: I1f mincount() masks a thin 0/1 indicator; continuous terms untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: I1f mincount() indicator (rc=`=_rc')"
    local ++fail_count
}

**# F5 transpose
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.foreign
    matrix T1 = r(table)
    quietly collect: regress price mpg i.foreign weight
    matrix T2 = r(table)
    local f "`output_dir'/_v23_tp.xlsx"
    capture erase "`f'"
    regtab, transpose keep(mpg 1.foreign) stats(n) models("Crude \ Adjusted") ///
        frame(_f5, replace flat) xlsx("`f'") sheet("TP")
    assert r(N_models) == 2
    frame _f5 {
        unab vv : *
        assert "`vv'" == "rowlabel c1 c2 c3 c4 c5"
        assert _N == 2
        assert rowlabel[1] == "Crude" & rowlabel[2] == "Adjusted"
        assert "`: variable label c1'" == "Observations"
        assert "`: variable label c2'" == "Mileage (mpg), Coef. (95% CI)"
        assert "`: variable label c3'" == "Mileage (mpg), p-value"
        assert "`: variable label c4'" == "Car origin: Foreign, Coef. (95% CI)"
        assert c1[1] == "74"
    }
    _v23_ci T2 5 1 %32.2f ", "
    local w = strtrim(string(round(T2[1, 1], 0.01), "%32.2f")) + " " + `"`r(ci)'"'
    frame _f5: assert c2[2] == `"`w'"'
    _v23_ci T1 5 3 %32.2f ", "
    local w = strtrim(string(round(T1[1, 3], 0.01), "%32.2f")) + " " + `"`r(ci)'"'
    frame _f5: assert c4[1] == `"`w'"'
    import excel using "`f'", sheet("TP") clear allstring
    quietly count if strtrim(B) == "Adjusted"
    assert r(N) == 1
    * nopvalue drops the p columns; refusals
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.foreign
    regtab, transpose nopvalue frame(_f5b, replace flat)
    frame _f5b {
        foreach v of varlist c* {
            assert strpos("`: variable label `v''", "p-value") == 0
        }
    }
    capture regtab, transpose addrow("x" 1)
    assert _rc == 198
    capture regtab, transpose dimnonsig
    assert _rc == 198
    capture regtab, transpose boldp(0.05)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: F5 transpose: models as rows, terms and stats as columns"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 transpose (rc=`=_rc')"
    local ++fail_count
}

**# O4 footnote() paragraphs
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    local f "`output_dir'/_v23_fn"
    capture erase "`f'.xlsx"
    capture erase "`f'.csv"
    capture erase "`f'.md"
    regtab, xlsx("`f'.xlsx") sheet("FN") csv("`f'.csv") markdown("`f'.md") ///
        footnote("First paragraph. \ Second paragraph, longer. \ Third")
    import excel using "`f'.xlsx", sheet("FN") clear allstring
    quietly count if strtrim(B) == "Intercept"
    assert r(N) == 1
    local n0 = _N
    assert strtrim(B[`n0' - 2]) == "First paragraph."
    assert strtrim(B[`n0' - 1]) == "Second paragraph, longer."
    assert strtrim(B[`n0']) == "Third"
    * CSV and Markdown receive the text unchanged (the writers split it)
    _v23_slurp "`f'.csv"
    local t `"`r(text)'"'
    assert strpos(`"`t'"', "First paragraph.") & strpos(`"`t'"', "Second paragraph") & strpos(`"`t'"', "Third")
    _v23_slurp "`f'.md"
    local t `"`r(text)'"'
    assert strpos(`"`t'"', "First paragraph.") & strpos(`"`t'"', "Second paragraph") & strpos(`"`t'"', "Third")
}
if _rc == 0 {
    display as result "  PASS: O4 footnote paragraphs: one Excel row each, text forwarded to CSV/Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: O4 footnote paragraphs (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text ""
display "RESULT: test_regtab_v230 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture frame drop _b1
log close _rv230
if `fail_count' > 0 exit 1
