* test_regtab_v231.do - regtab 2.3.1: user reports from three studies
* Covers, each on its happy path, its refusal paths, and a known answer:
*   S1  sheet() honours the session workbook (tabtools set workbook), starts
*       it over on the first write, and says when sheet() has no workbook
*   Z1  a factor level the fit estimated with a zero variance is not the
*       reference: not "Reference", masked by mincount(), reftop accepted
*   H1  cilabel() and plabel() reach every sink and layout
*   A1  addcol() for transposed tables
*   G1  stats() e(name)="label" items and statlabels()
*   C1  cellnote() accepts addrow()'s quoting forms; whole-spec unwrap
* Every expected value is computed from the fit's own e()/r(table) or from
* the fixture's design, never from the table regtab builds.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rv231
log using "test_regtab_v231.log", replace text name(_rv231)

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

global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/rt231_facts.txt"
run "`qa_dir'/_qa_v230_helpers.do"
quietly tabtools set clear

local dash = uchar(8211)

* Trimmed contents of column `col' on the one row of frame `fr' whose trimmed
* label (variable `lv') is `label', searching from row `from'.
capture program drop _v231_cell
program define _v231_cell, rclass
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

* Whole text of a file, lines joined with "|".
capture program drop _v231_slurp
program define _v231_slurp, rclass
    version 17.0
    args fn
    mata: st_local("all", invtokens(cat(st_local("fn"))', "|"))
    return local text `"`all'"'
end

* Worksheet names of a workbook, read back by import excel.
capture program drop _v231_sheets
program define _v231_sheets, rclass
    version 17.0
    args book
    quietly import excel using "`book'", describe
    local n = r(N_worksheet)
    local s ""
    forvalues i = 1/`n' {
        local s "`s' `r(worksheet_`i')'"
    }
    return local sheets = strtrim("`s'")
end

* The zero-variance fixture: cat2 == 2 holds the first three subjects, who
* all die first, so stcox drives that level's coefficient off to infinity.
* With age added the robust variance of that coefficient is exactly zero.
capture program drop _v231_zvfix
program define _v231_zvfix
    version 17.0
    sysuse cancer, clear
    quietly generate id = _n
    quietly stset studytime, failure(died) id(id)
    quietly generate byte cat2 = cond(_n < 4, 2, 1)
    collect clear
end

**# S1 session workbook
* S1a: sheet() writes to the session workbook and starts it over on the first
* write (a sheet left in the file before tabtools set workbook is gone); the
* second write adds its sheet.
local ++test_count
capture noisily {
    local book "`output_dir'/rt231_session.xlsx"
    capture erase "`book'"
    clear
    set obs 1
    generate x = 1
    quietly export excel using "`book'", sheet("Stale") replace
    _v231_sheets "`book'"
    assert "`r(sheets)'" == "Stale"
    quietly tabtools set workbook "`book'"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    matrix T = r(table)
    regtab, sheet("T2")
    assert `"`r(sheet)'"' == "T2"
    confirm file "`book'"
    _v231_sheets "`book'"
    assert "`r(sheets)'" == "T2"
    import excel using "`book'", sheet("T2") clear allstring
    quietly count if strtrim(B) == "Mileage (mpg)" & ///
        strtrim(C) == strtrim(string(round(T[1, 1], 0.01), "%32.2f"))
    assert r(N) == 1
    sysuse auto, clear
    collect clear
    quietly collect: regress price weight
    regtab, sheet("T3")
    _v231_sheets "`book'"
    assert "`r(sheets)'" == "T2 T3"
    * the workbook as written, read with openpyxl
    _v_facts "`book'" "T3"
    _v_value B4 "Weight (lbs.)"
    quietly tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: S1a sheet() writes the session workbook, started over on the first write"
    local ++pass_count
}
else {
    display as error "  FAIL: S1a session workbook (rc=`=_rc')"
    local ++fail_count
    capture tabtools set clear
}

* S1b: an explicit xlsx() wins over the session workbook; with no workbook at
* all sheet() is ignored and regtab says so, exactly.
local ++test_count
capture noisily {
    local book "`output_dir'/rt231_session2.xlsx"
    local mine "`output_dir'/rt231_explicit.xlsx"
    capture erase "`book'"
    capture erase "`mine'"
    quietly tabtools set workbook "`book'"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    regtab, xlsx("`mine'") sheet("E")
    assert `"`r(xlsx)'"' == "`mine'"
    confirm file "`mine'"
    capture confirm file "`book'"
    assert _rc == 601
    quietly tabtools set clear
    local lg "`output_dir'/rt231_ignored.log"
    capture log close _rv231b
    log using "`lg'", replace text name(_rv231b)
    regtab, sheet("T2")
    log close _rv231b
    assert `"`r(xlsx)'"' == ""
    _v_line "`lg'" "(tabtools: sheet() ignored; no xlsx() and no session workbook)" 1
    * without sheet() nothing is said and nothing is written
    log using "`lg'", replace text name(_rv231b)
    regtab
    log close _rv231b
    _v_grep "`lg'" "sheet\(\) ignored"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: S1b explicit xlsx() wins; sheet() without a workbook is reported"
    local ++pass_count
}
else {
    display as error "  FAIL: S1b explicit xlsx()/ignored sheet() (rc=`=_rc')"
    local ++fail_count
    capture log close _rv231b
    capture tabtools set clear
}

* S1c: the session Markdown file is honoured by sheet() too.
local ++test_count
capture noisily {
    local md "`output_dir'/rt231_session.md"
    capture erase "`md'"
    quietly tabtools set markdown "`md'"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    regtab, sheet("M")
    assert `"`r(markdown)'"' != ""
    confirm file "`md'"
    _v231_slurp "`md'"
    assert strpos(`"`r(text)'"', "| Mileage (mpg) |") > 0
    quietly tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: S1c sheet() writes the session Markdown file"
    local ++pass_count
}
else {
    display as error "  FAIL: S1c session Markdown (rc=`=_rc')"
    local ++fail_count
    capture tabtools set clear
}

**# Z1 zero-variance non-reference level
* Z1a: the level cat2 = 2 is estimated in both models (e(b) colname 2.cat2,
* no b or o marker); model 2 gives it a zero variance. It is not the
* reference in either model: model 1 shows its estimate and interval, model 2
* shows it as not estimable (emptylabel()). The base level 1b.cat2 stays the
* reference in both, and reftop accepts the two-model table.
local ++test_count
capture noisily {
    _v231_zvfix
    quietly collect: stcox i.drug i.cat2, vce(cluster id)
    local cn1 : colnames e(b)
    matrix T1 = r(table)
    quietly collect: stcox i.drug i.cat2 age, vce(cluster id)
    local cn2 : colnames e(b)
    matrix V2 = e(V)
    * the fixture's design: base 1b.cat2, estimated 2.cat2, zero variance in model 2
    assert strpos(" `cn1' ", " 1b.cat2 ") & strpos(" `cn1' ", " 2.cat2 ")
    assert strpos(" `cn2' ", " 2.cat2 ") & !strpos(" `cn2' ", " 2o.cat2 ")
    local j2 : list posof "2.cat2" in cn2
    assert V2[`j2', `j2'] == 0
    assert T1[2, colnumb(T1, "2.cat2")] > 0
    regtab, noint frame(_z1, replace) eplotframe(_z1e, replace)
    _v231_cell _z1 A "1" c1 4
    assert "`r(cell)'" == "Reference"
    _v231_cell _z1 A "1" c4 4
    assert "`r(cell)'" == "Reference"
    _v231_cell _z1 A "2" c4 4
    assert "`r(cell)'" == "Empty"
    _v231_cell _z1 A "2" c5 4
    assert "`r(cell)'" == ""
    _v231_cell _z1 A "2" c1 4
    assert !inlist("`r(cell)'", "Reference", "Empty", "")
    _v231_cell _z1 A "2" c2 4
    assert substr("`r(cell)'", 1, 1) == "("
    * eplotframe(): no reference row for the estimated level in either model
    frame _z1e {
        quietly count if strtrim(label) == "2" & rowtype == "reference"
        assert r(N) == 0
        quietly count if strtrim(label) == "1" & rowtype == "reference"
        assert r(N) == 2
    }
    * reftop: one base level per block in every model, so no refusal
    regtab, noint reftop frame(_z1r, replace)
    _v231_cell _z1r A "1" c4 4
    local r1 = r(row)
    _v231_cell _z1r A "2" c4 4
    assert r(row) == `r1' + 1
    assert "`r(cell)'" == "Empty"
    * a custom emptylabel() reaches the cell
    regtab, noint emptylabel("n/e") frame(_z1x, replace)
    _v231_cell _z1x A "2" c4 4
    assert "`r(cell)'" == "n/e"
}
if _rc == 0 {
    display as result "  PASS: Z1a zero-variance level is not the reference; reftop accepts it"
    local ++pass_count
}
else {
    display as error "  FAIL: Z1a zero-variance level (rc=`=_rc')"
    local ++fail_count
}

* Z1b: mincount() masks the zero-variance level in model 2 (it used to skip
* it as a base level). Expected masks from the fixture: per model, every
* non-base level with fewer than # events, plus model 2's 2.cat2 (variance 0).
local ++test_count
capture noisily {
    _v231_zvfix
    local mc 5
    local want = 0
    foreach c in "drug == 2" "drug == 3" "cat2 == 2" {
        quietly count if _d & `c'
        if r(N) < `mc' local want = `want' + 2
        else if "`c'" == "cat2 == 2" local want = `want' + 1
    }
    quietly collect: stcox i.drug i.cat2, vce(cluster id)
    quietly tabtools fitcount, events(_d) terms
    quietly collect: stcox i.drug i.cat2 age, vce(cluster id)
    quietly tabtools fitcount, events(_d) terms
    regtab, noint mincount(`mc') frame(_z1m, replace)
    assert r(N_masked) == `want'
    _v231_cell _z1m A "2" c4 4
    assert "`r(cell)'" == "`dash'"
    _v231_cell _z1m A "1" c4 4
    assert "`r(cell)'" == "Reference"
    regtab, noint mincount(`mc') reftop
    assert r(N_masked) == `want'
}
if _rc == 0 {
    display as result "  PASS: Z1b mincount() masks the zero-variance level"
    local ++pass_count
}
else {
    display as error "  FAIL: Z1b mincount() zero-variance level (rc=`=_rc')"
    local ++fail_count
}

* Z1c: a genuine base level and a collinear level keep their labels in a
* linear model (the fallback reads collect's own constrained value).
local ++test_count
capture noisily {
    sysuse auto, clear
    generate byte dom = !foreign
    collect clear
    quietly collect: regress price mpg i.foreign i.dom
    regtab, frame(_z1c, replace)
    _v231_cell _z1c A "Domestic" c1 4
    assert "`r(cell)'" == "Reference"
    frame _z1c {
        quietly count if strtrim(c1) == "Empty"
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: Z1c base and collinear levels keep their labels"
    local ++pass_count
}
else {
    display as error "  FAIL: Z1c base/collinear labels (rc=`=_rc')"
    local ++fail_count
}

**# H1 cilabel() and plabel()
* H1a: defaults are unchanged (non-compact "95% CI", compact "OR 95% CI").
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg weight
    regtab, frame(_h1a, replace flat)
    frame _h1a {
        assert "`: variable label c2'" == "95% CI"
        assert "`: char c2[tabtools_header]'" == "Model, 95% CI"
        assert "`: variable label c3'" == "p-value"
        assert "`: char c3[tabtools_header]'" == "Model, p-value"
    }
    regtab, frame(_h1b, replace flat) compact
    frame _h1b {
        assert "`: variable label c1'" == "OR 95% CI"
        assert "`: char c1[tabtools_header]'" == "Model, OR 95% CI"
        assert "`: variable label c2'" == "p-value"
        assert "`: char c2[tabtools_header]'" == "Model, p-value"
    }
    regtab, frame(_h1c, replace flat) transpose
    frame _h1c {
        assert "`: variable label c1'" == "Mileage (mpg), OR (95% CI)"
        assert "`: variable label c2'" == "Mileage (mpg), p-value"
    }
}
if _rc == 0 {
    display as result "  PASS: H1a default interval and p-value headers unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: H1a default headers (rc=`=_rc')"
    local ++fail_count
}

* H1b: the labels reach every sink: frame(), flat frame, Excel, CSV, Markdown,
* and the compact and transposed layouts.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg weight
    quietly collect: logit foreign mpg weight price
    local f "`output_dir'/rt231_hdr"
    foreach x in xlsx csv md {
        capture erase "`f'.`x'"
    }
    local cil "95% conf. int."
    local pl "P (Wald)"
    regtab, cilabel("`cil'") plabel("`pl'") frame(_h1d, replace) ///
        xlsx("`f'.xlsx") sheet("H") csv("`f'.csv") markdown("`f'.md")
    frame _h1d {
        assert strtrim(c2[3]) == "`cil'" & strtrim(c3[3]) == "`pl'"
        assert strtrim(c5[3]) == "`cil'" & strtrim(c6[3]) == "`pl'"
        quietly count if strtrim(c2) == "95% CI" | strtrim(c3) == "p-value"
        assert r(N) == 0
    }
    _v_facts "`f'.xlsx" "H"
    _v_value D3 "`cil'"
    _v_value E3 "`pl'"
    _v_value G3 "`cil'"
    _v_value H3 "`pl'"
    _v231_slurp "`f'.csv"
    local t `"`r(text)'"'
    assert strpos(`"`t'"', "`cil'") > 0 & strpos(`"`t'"', "`pl'") > 0
    assert strpos(`"`t'"', "95% CI") == 0 & strpos(`"`t'"', "p-value") == 0
    _v231_slurp "`f'.md"
    local t `"`r(text)'"'
    assert strpos(`"`t'"', "Model 1: `cil'") > 0 & strpos(`"`t'"', "Model 2: `pl'") > 0
    assert strpos(`"`t'"', "95% CI") == 0
    regtab, cilabel("`cil'") plabel("`pl'") frame(_h1e, replace flat)
    frame _h1e {
        assert "`: variable label c2'" == "`cil'"
        assert "`: char c2[tabtools_header]'" == "Model 1, `cil'"
        assert "`: variable label c6'" == "`pl'"
        assert "`: char c6[tabtools_header]'" == "Model 2, `pl'"
    }
    regtab, cilabel("`cil'") plabel("`pl'") compact frame(_h1f, replace flat)
    frame _h1f {
        assert "`: variable label c1'" == "OR `cil'"
        assert "`: char c1[tabtools_header]'" == "Model 1, OR `cil'"
        assert "`: variable label c2'" == "`pl'"
        assert "`: char c2[tabtools_header]'" == "Model 1, `pl'"
    }
    regtab, cilabel("`cil'") plabel("`pl'") transpose frame(_h1g, replace flat)
    frame _h1g {
        assert "`: variable label c1'" == "Mileage (mpg), OR (`cil')"
        assert "`: variable label c2'" == "Mileage (mpg), `pl'"
    }
}
if _rc == 0 {
    display as result "  PASS: H1b cilabel()/plabel() in frame, flat, xlsx, csv, md, compact, transpose"
    local ++pass_count
}
else {
    display as error "  FAIL: H1b cilabel()/plabel() sinks (rc=`=_rc')"
    local ++fail_count
}

**# A1 addcol() for transposed tables
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    quietly collect: regress price mpg weight
    local f "`output_dir'/rt231_addcol.xlsx"
    capture erase "`f'"
    regtab, transpose addcol("P trend" 0.032 0.041 \ `"Cohort "B""' a) ///
        frame(_a1, replace flat) xlsx("`f'") sheet("AC")
    frame _a1 {
        unab vv : *
        local nv : word count `vv'
        local last : word `nv' of `vv'
        local prev : word `=`nv' - 1' of `vv'
        assert `"`: variable label `prev''"' == "P trend"
        assert `"`: variable label `last''"' == `"Cohort "B""'
        assert `prev'[1] == "0.032" & `prev'[2] == "0.041"
        assert `last'[1] == "a" & `last'[2] == ""
    }
    import excel using "`f'", sheet("AC") clear allstring
    quietly ds
    local found = 0
    foreach v in `r(varlist)' {
        quietly count if strtrim(`v') == "P trend"
        if r(N) == 1 {
            quietly count if strtrim(`v') == "0.041"
            local found = r(N)
        }
    }
    assert `found' == 1
    * refusals: addcol() needs transpose; transpose refuses addrow(); one value
    * per model at most
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    capture regtab, addcol("x" 1)
    assert _rc == 198
    capture regtab, transpose addrow("x" 1)
    assert _rc == 198
    capture regtab, transpose addcol("x" 1 2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A1 addcol() adds transposed columns; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 addcol() (rc=`=_rc')"
    local ++fail_count
}

**# G1 stats() e(name) items and statlabels()
* G1a: a model lacking the scalar is blank; integers keep thousands
* separators, other values three decimals; r(e_<name>_<m>) at full precision.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress mpg weight
    local r2a1 = e(r2_a)
    quietly collect: tobit mpg weight, ll(17)
    local nlc2 = e(N_lc)
    local nunc2 = e(N_unc)
    assert `nlc2' > 0
    regtab, stats(n e(N_lc)="Left-censored" e(N_unc)=`"Not censored"' e(r2_a)) ///
        frame(_g1, replace)
    local ret_lc2 = r(e_N_lc_2)
    local ret_r2a1 = r(e_r2_a_1)
    local ret_lc1 = r(e_N_lc_1)
    _v231_cell _g1 A "Left-censored" c1 4
    assert "`r(cell)'" == ""
    _v231_cell _g1 A "Left-censored" c4 4
    assert "`r(cell)'" == strtrim(string(`nlc2', "%12.0fc"))
    _v231_cell _g1 A "Not censored" c4 4
    assert "`r(cell)'" == strtrim(string(`nunc2', "%12.0fc"))
    _v231_cell _g1 A "r2_a" c1 4
    assert "`r(cell)'" == strtrim(string(`r2a1', "%12.3f"))
    _v231_cell _g1 A "r2_a" c4 4
    assert "`r(cell)'" == ""
    assert `ret_lc2' == `nlc2'
    assert !missing(`ret_r2a1', `r2a1')
    assert reldif(`ret_r2a1', `r2a1') < 1e-12
    assert missing(`ret_lc1')
    * the generic rows follow the built-in ones, in the order given
    _v231_cell _g1 A "Observations" c1 4
    local ro = r(row)
    _v231_cell _g1 A "Left-censored" c1 4
    assert r(row) == `ro' + 1
    _v231_cell _g1 A "r2_a" c1 4
    assert r(row) == `ro' + 3
    * transposed: the label is the column header
    regtab, transpose stats(e(N_lc)="Left-censored") frame(_g1t, replace flat)
    frame _g1t {
        assert "`: variable label c1'" == "Left-censored"
        assert c1[2] == strtrim(string(`nlc2', "%12.0fc"))
    }
    * refusals: in no model, requested twice, unreadable
    capture regtab, stats(e(nosuch))
    assert _rc == 111
    capture regtab, stats(e(N_lc) e(N_lc))
    assert _rc == 198
    capture regtab, stats(e(1bad))
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: G1a stats() e(name) rows, blanks, formats, returns, refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: G1a stats() e(name) (rc=`=_rc')"
    local ++fail_count
}

* G1b: statlabels() relabels built-in rows; refusals.
local ++test_count
capture noisily {
    _v231_zvfix
    quietly collect: stcox i.drug, vce(cluster id)
    quietly tabtools fitcount, events(_d) people(id) exposure(_t)
    regtab, stats(n events people exposure ll) ///
        statlabels(n "Patients" events "Deaths" people "Clusters" exposure "Months at risk" ll "Log pseudolikelihood") ///
        frame(_g1b, replace)
    frame _g1b {
        foreach l in "Patients" "Deaths" "Clusters" "Months at risk" "Log pseudolikelihood" {
            quietly count if strtrim(A) == "`l'"
            assert r(N) == 1
        }
        foreach l in "Subjects" "Events" "People" "Person-time" "Log-likelihood" {
            quietly count if strtrim(A) == "`l'"
            assert r(N) == 0
        }
    }
    capture regtab, stats(n) statlabels(bogus "x")
    assert _rc == 198
    capture regtab, stats(n) statlabels(aic "x")
    assert _rc == 198
    capture regtab, stats(n) statlabels(n)
    assert _rc == 198
    capture regtab, stats(exposure) exposurelabel("PY") statlabels(exposure "x")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: G1b statlabels() relabels built-in rows; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: G1b statlabels() (rc=`=_rc')"
    local ++fail_count
}

**# C1 cellnote() quoting forms
* C1a: plain, compound, a \ touching its neighbours, and a whole spec wrapped
* in one more quote layer (as a program passes cellnote(`"`spec'"')) all set
* the same cells.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    local i = 0
    foreach spec in ///
        `"("Mileage (mpg)" 1 "a" \ "Weight (lbs.)" 2 "b")"' ///
        `"(`"Mileage (mpg)"' 1 `"a"' \ `"Weight (lbs.)"' 2 `"b"')"' ///
        `"("Mileage (mpg)" 1 "a"\"Weight (lbs.)" 2 "b")"' ///
        `"(`""Mileage (mpg)" 1 "a" \ "Weight (lbs.)" 2 "b""')"' {
        local ++i
        regtab, cellnote`macval(spec)' frame(_c1_`i', replace)
        _v231_cell _c1_`i' A "Mileage (mpg)" c1 4
        assert "`r(cell)'" == "a"
        _v231_cell _c1_`i' A "Weight (lbs.)" c4 4
        assert "`r(cell)'" == "b"
        _v231_cell _c1_`i' A "Weight (lbs.)" c1 4
        assert "`r(cell)'" != "b"
    }
    * text with a backslash and embedded quotes is data
    regtab, cellnote("Mileage (mpg)" 1 `"see "a\b""') frame(_c1x, replace)
    _v231_cell _c1x A "Mileage (mpg)" c1 4
    assert `"`r(cell)'"' == `"see "a\b""'
    * refusals keep working
    capture regtab, cellnote("Mileage (mpg)" 1)
    assert _rc == 198
    capture regtab, cellnote("Mileage (mpg)" 1 "a" \)
    assert _rc == 198
    capture regtab, cellnote("Mileage (mpg)" x "a")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: C1a cellnote() plain, compound, touching \, and wrapped forms"
    local ++pass_count
}
else {
    display as error "  FAIL: C1a cellnote() quoting forms (rc=`=_rc')"
    local ++fail_count
}

* C1b: addrow() with a whole spec wrapped in one more quote layer gives the
* row it names (it used to become one row labelled with the whole spec).
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    quietly collect: regress price mpg weight
    local spec `""P trend" 0.03 0.04"'
    regtab, addrow(`"`spec'"') frame(_c1b, replace)
    _v231_cell _c1b A "P trend" c1 4
    assert "`r(cell)'" == "0.03"
    _v231_cell _c1b A "P trend" c4 4
    assert "`r(cell)'" == "0.04"
}
if _rc == 0 {
    display as result "  PASS: C1b addrow() unwraps a whole quoted spec"
    local ++pass_count
}
else {
    display as error "  FAIL: C1b addrow() wrapped spec (rc=`=_rc')"
    local ++fail_count
}

**# D1 help file renders the new options
* The installed regtab.sthlp as the Viewer prints it (smcl2txt), not its source.
local ++test_count
capture noisily {
    findfile regtab.sthlp
    local txt "`output_dir'/rt231_help.txt"
    quietly translate "`r(fn)'" "`txt'", translator(smcl2txt) replace
    * read in Mata: the help text's own quotes never pass through a macro
    mata: _h = invtokens(cat(st_local("txt"))', " ")
    foreach w in "cilabel(string)" "plabel(string)" "addcol(string asis)" ///
        "statlabels(string asis)" "stats(string asis)" "r(e_name_#)" ///
        "(tabtools: sheet() ignored; no xlsx() and no session" {
        mata: st_local("hit", strofreal(strpos(_h, st_local("w")) > 0))
        assert `hit'
    }
    * the compound-quoted example renders as typed: addrow(`"`spec'"')
    mata: st_local("hit", strofreal(strpos(_h, "addrow(" + char(96) + char(34) + ///
        char(96) + "spec" + char(39) + char(34) + char(39) + ")") > 0))
    assert `hit'
    capture mata: mata drop _h
    _v_grep "`txt'" "\{(opt|cmd|it)"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: D1 help file renders cilabel/plabel/addcol/statlabels/e(name)"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 help file render (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text ""
display "RESULT: test_regtab_v231 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture tabtools set clear
log close _rv231
if `fail_count' > 0 exit 1
