* test_regtab_v240.do - regtab 2.4.0 development: user feedback, wave 1
* Covers, each on its happy path, its refusal paths, and a known answer:
*   S0  regtab.ado split into _regtab_* helpers: size, install, transport
*   B1  base levels detected from the model's own specification, not from
*       collect's "empty" class; notestlabel() for levels not estimable
*   M1  mincount(): a level missing from a model's e(b) inside a factor the
*       model includes is not estimable, never a blank cell
*   F1  frame(, flat): short column labels, model kept in characteristics
*   R1  addrow(..., after(term)) places rows inside the table body
* Every expected value comes from the fit's own e(b)/e(V), the fixture's
* design, or the data, never from the table regtab builds.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rv240
log using "test_regtab_v240.log", replace text name(_rv240)

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
global V230_RES "`output_dir'/rt240_facts.txt"
run "`qa_dir'/_qa_v230_helpers.do"
quietly tabtools set clear

local dash = uchar(8211)

* Trimmed contents of column `col' on the one row of frame `fr' whose trimmed
* label (variable `lv') is `label', searching from row `from'.
capture program drop _v240_cell
program define _v240_cell, rclass
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

* The levels of factor `fv' that the active e(b) marks as base (b.) and as
* omitted (o.), read from its column names: the fit's own record.
capture program drop _v240_marks
program define _v240_marks, rclass
    version 17.0
    args fv
    local cn : colnames e(b)
    local base ""
    local omit ""
    local all ""
    foreach c of local cn {
        if !ustrregexm("`c'", "^([0-9]+)([a-z]*)\.`fv'$") continue
        local lv = ustrregexs(1)
        local op = ustrregexs(2)
        local all "`all' `lv'"
        if strpos("`op'", "b") & !strpos("`op'", "n") local base "`base' `lv'"
        if strpos("`op'", "o") local omit "`omit' `lv'"
    }
    return local base = strtrim("`base'")
    return local omit = strtrim("`omit'")
    return local all = strtrim("`all'")
end

* The zero-variance fixture of test_regtab_v231: cat2 == 2 holds the first
* three subjects, who all die first; with age added the robust variance of
* that level's coefficient is exactly zero.
capture program drop _v240_zvfix
program define _v240_zvfix
    version 17.0
    sysuse cancer, clear
    quietly generate id = _n
    quietly stset studytime, failure(died) id(id)
    quietly generate byte cat2 = cond(_n < 4, 2, 1)
    collect clear
end

* The feedback fixture: stcox in everyone and in the placebo group, where
* drug has a single level (e(b): 0o.drug, and no 1.drug column at all).
capture program drop _v240_drugtr
program define _v240_drugtr
    version 17.0
    args third
    webuse drugtr, clear
    quietly generate id = _n
    collect clear
    quietly stcox i.drug age
    quietly collect get e(), tags(cmdset[1])
    quietly tabtools fitcount, events(_d) terms
    quietly stcox i.drug age if drug == 0
    quietly collect get e(), tags(cmdset[2])
    quietly tabtools fitcount, events(_d) terms
    if "`third'" != "" {
        quietly stcox age
        quietly collect get e(), tags(cmdset[3])
        quietly tabtools fitcount, events(_d) terms
    }
end

**# S0 regtab.ado split
* S0a: regtab.ado is far below Stata's ado-file size limit, every _regtab_*
* helper file is shipped by the .pkg and resolves for an installed user, and
* every program is defined in the file named after it.
local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`pkg_dir'/regtab.ado", read binary
    file seek `fh' eof
    file seek `fh' query
    local bytes = r(loc)
    file close `fh'
    display as text "regtab.ado: `bytes' bytes"
    assert `bytes' < 200000
    local helpers : dir "`pkg_dir'" files "_regtab_*.ado"
    local nh : word count `helpers'
    assert `nh' >= 23
    mata: st_local("pkgtxt", invtokens(cat(st_local("pkg_dir") + "/tabtools.pkg")', "|"))
    foreach h of local helpers {
        assert strpos(`"|`pkgtxt'|"', "|f `h'|") > 0
        local prog = subinstr("`h'", ".ado", "", 1)
        * installed by net install (PLUS/_/), whatever adopath run_all sets
        confirm file `"`c(sysdir_plus)'_/`h'"'
        mata: st_local("hit", strofreal(any(ustrregexm(cat(st_local("pkg_dir") + "/`h'"), ///
            "^program define `prog', nclass$"))))
        assert `hit'
    }
}
if _rc == 0 {
    display as result "  PASS: S0a regtab.ado < 200 KB; every _regtab_* helper shipped and installed"
    local ++pass_count
}
else {
    display as error "  FAIL: S0a regtab.ado split (rc=`=_rc')"
    local ++fail_count
}

* S0b: the block helpers hand regtab's locals over through Mata; nothing of
* that transport is left behind, after a success or after a refusal raised
* inside a block (addrow() runs in _regtab_addrow), and the caller's
* varabbrev setting survives the refusal.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.foreign
    regtab, stats(n aic) relabel
    foreach v in N V O I {
        capture mata: _regtab_ns`v'
        assert _rc == 3499
    }
    set varabbrev on
    capture regtab, addrow("x" 1, after(nosuch))
    local rc = _rc
    local va = c(varabbrev)
    set varabbrev off
    assert `rc' == 198
    assert "`va'" == "on"
    foreach v in N V O I {
        capture mata: _regtab_ns`v'
        assert _rc == 3499
    }
}
if _rc == 0 {
    display as result "  PASS: S0b block transport leaves no Mata state and restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: S0b block transport (rc=`=_rc')"
    local ++fail_count
}

**# B1 base levels and notestlabel()
* B1a: logit drops the observations of a perfectly predicted base level, so
* e(b) marks it b. while the estimation sample holds none of it (collect's
* class "empty" is true here) and drops level 5 to identify the rest. A base
* level with no observations is not estimable: notestlabel(), never the
* reference; level 5 stays omitted. The b. marker alone does not make a
* reference in a model whose classes collect recorded.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly generate byte hi = price > 6000
    collect clear
    quietly collect: logit hi i.rep78 i.foreign
    _v240_marks rep78
    assert "`r(base)'" == "1" & "`r(omit)'" == "5"
    quietly count if rep78 == 1 & e(sample)
    assert r(N) == 0
    quietly count if rep78 == 1
    assert r(N) > 0
    * the collection's own class of the base level is "empty"
    tempfile cj
    quietly collect save "`cj'.stjson", replace
    mata: st_local("hit", strofreal(ustrregexm(invtokens(cat(st_local("cj") + ".stjson")'), ///
        `"colname\[1\.rep78\][^"]*result\[_r_b\][^"]*":\s*\{\s*"d":\s*[^,]*,\s*"omit-type":\s*"empty""')))
    assert `hit'
    regtab, noint notestlabel("NE") frame(_b1, replace)
    _v240_cell _b1 A "1" c1 4
    assert "`r(cell)'" == "NE"
    _v240_cell _b1 A "5" c1 4
    assert "`r(cell)'" == "Omitted"
    _v240_cell _b1 A "Domestic" c1 4
    assert "`r(cell)'" == "Reference"
    frame _b1: quietly count if strtrim(c1) == "Reference"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: B1a an empty base level is notestlabel(), not the reference"
    local ++pass_count
}
else {
    display as error "  FAIL: B1a logit base level (rc=`=_rc')"
    local ++fail_count
}

* B1b: nbreg stamps every constrained cell "empty". The b. levels are the
* reference; dup duplicates foreign, so e(b) omits 1o.dup: Omitted, as
* regress shows a collinear level, never a second reference of the dup
* block. Both routes: the fit active (its e(b) markers), and after another
* fit (the model's own specification through fvexpand).
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly generate byte dup = foreign
    collect clear
    quietly collect: nbreg mpg i.rep78 i.foreign i.dup
    _v240_marks dup
    assert "`r(base)'" == "0" & "`r(omit)'" == "1"
    _v240_marks rep78
    local brep = "`r(base)'"
    regtab, notestlabel("n.e.") frame(_b2, replace)
    tempfile b2a
    frame _b2: quietly save "`b2a'"
    quietly regress price weight
    regtab, notestlabel("n.e.") frame(_b2, replace)
    * the two routes print the same table
    frame _b2: cf _all using "`b2a'"
    _v240_cell _b2 A "Repair record 1978" A 4
    local rrow = r(row)
    frame _b2: assert strtrim(A[`rrow' + `brep']) == "`brep'"
    frame _b2: assert strtrim(c1[`rrow' + `brep']) == "Reference"
    _v240_cell _b2 A "Domestic" c1 4
    assert "`r(cell)'" == "Reference"
    _v240_cell _b2 A "dup" c1 4
    local hrow = r(row)
    _v240_cell _b2 A "0" c1 `hrow'
    assert "`r(cell)'" == "Reference"
    _v240_cell _b2 A "1" c1 `=`hrow' + 1'
    assert "`r(cell)'" == "Omitted"
    _v240_cell _b2 A "1" c2 `=`hrow' + 1'
    assert "`r(cell)'" == ""
    regtab, omitlabel("Dropped") frame(_b2, replace)
    _v240_cell _b2 A "1" c1 `=`hrow' + 1'
    assert "`r(cell)'" == "Dropped"
}
if _rc == 0 {
    display as result "  PASS: B1b nbreg: b. levels are the reference, an o. level is Omitted (both routes)"
    local ++pass_count
}
else {
    display as error "  FAIL: B1b nbreg base/not estimable (rc=`=_rc')"
    local ++fail_count
}

* B1c: ib4. and ib(last). bases resolve as the fit did (logit, where collect
* stamps classes unreliably): the b. level is the reference, others are not.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly generate byte hi = price > 6000
    foreach spec in "ib4.rep78" "ib(last).foreign" {
        collect clear
        quietly collect: logit hi `spec' mpg
        local fv = substr("`spec'", strpos("`spec'", ".") + 1, .)
        _v240_marks `fv'
        local b = "`r(base)'"
        local all = "`r(all)'"
        assert wordcount("`b'") == 1
        regtab, noint frame(_b3, replace)
        frame _b3: quietly count if strtrim(c1) == "Reference"
        assert r(N) == 1
        local lab "`b'"
        if "`fv'" == "foreign" local lab : label (foreign) `b'
        _v240_cell _b3 A "`lab'" c1 4
        assert "`r(cell)'" == "Reference"
    }
}
if _rc == 0 {
    display as result "  PASS: B1c ib#. and ib(last). bases follow e(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: B1c ib#. bases (rc=`=_rc')"
    local ++fail_count
}

* B1d: a level the fit estimated with a zero variance (the v231 fixture) is
* notestlabel(); the reference keeps refcat(); refusals of labels that would
* be indistinguishable.
local ++test_count
capture noisily {
    _v240_zvfix
    quietly collect: stcox i.drug i.cat2 age, vce(cluster id)
    local cn : colnames e(b)
    local j : list posof "2.cat2" in cn
    assert el(e(V), `j', `j') == 0
    regtab, noint notestlabel("NE") frame(_b4, replace)
    _v240_cell _b4 A "cat2" A 4
    local hrow = r(row)
    _v240_cell _b4 A "1" c1 `hrow'
    assert "`r(cell)'" == "Reference"
    _v240_cell _b4 A "2" c1 `hrow'
    assert "`r(cell)'" == "NE"
    capture regtab, notestlabel("Reference")
    assert _rc == 198
    capture regtab, notestlabel("Gone") omitlabel("Gone")
    assert _rc == 198
    * equal to emptylabel() is allowed: that is the default
    regtab, notestlabel("E2") emptylabel("E2") frame(_b4, replace)
    _v240_cell _b4 A "2" c1 `hrow'
    assert "`r(cell)'" == "E2"
}
if _rc == 0 {
    display as result "  PASS: B1d zero-variance level is notestlabel(); label refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: B1d zero-variance notestlabel (rc=`=_rc')"
    local ++fail_count
}

* B1e: under mincount() the two masks read differently: a level with fewer
* events than # is emptylabel(), the zero-variance level notestlabel() even
* though its events are fewer than # as well; the bases stay the reference.
local ++test_count
capture noisily {
    _v240_zvfix
    quietly collect: stcox i.drug i.cat2 age, vce(cluster id)
    quietly tabtools fitcount, events(_d) terms
    quietly count if _d & e(sample) & drug == 2
    local e2 = r(N)
    quietly count if _d & e(sample) & drug == 3
    local e3 = r(N)
    quietly count if _d & e(sample) & cat2 == 2
    local ez = r(N)
    * k: one more than the thinner level's events, so that level (both, on a
    * tie) is masked as too thin
    local k = min(`e2', `e3') + 1
    assert `ez' < `k'
    regtab, noint mincount(`k') emptylabel("<`k'") notestlabel("NE") frame(_b5, replace)
    assert r(N_masked) == (`e2' < `k') + (`e3' < `k') + 1
    local dl : variable label drug
    _v240_cell _b5 A "`dl'" A 4
    local drow = r(row)
    local l1 : label (drug) 1
    frame _b5: assert strtrim(A[`drow' + 1]) == "`l1'" & strtrim(c1[`drow' + 1]) == "Reference"
    foreach l in 2 3 {
        local ll : label (drug) `l'
        frame _b5: assert strtrim(A[`drow' + `l']) == "`ll'"
        frame _b5: local cell = strtrim(c1[`drow' + `l'])
        if `e`l'' < `k' assert "`cell'" == "<`k'"
        else assert !inlist("`cell'", "<`k'", "NE", "")
    }
    _v240_cell _b5 A "cat2" A 4
    local hrow = r(row)
    _v240_cell _b5 A "2" c1 `hrow'
    assert "`r(cell)'" == "NE"
    _v240_cell _b5 A "1" c1 `hrow'
    assert "`r(cell)'" == "Reference"
}
if _rc == 0 {
    display as result "  PASS: B1e mincount(): thin level emptylabel(), not estimable notestlabel()"
    local ++pass_count
}
else {
    display as error "  FAIL: B1e mincount() two labels (rc=`=_rc')"
    local ++fail_count
}

**# M1 mincount() and levels absent from a model
* M1a: the feedback repro. Model 2 (placebo only) has 0o.drug and no 1.drug
* column at all: both are not estimable there, shown as notestlabel(); the
* first counted by r(N_masked), the second by r(N_absent).
* Model 3 has no drug term: its drug rows stay
* blank. Model 1 is unchanged.
local ++test_count
capture noisily {
    _v240_drugtr third
    quietly stcox i.drug age if drug == 0
    local cn2 : colnames e(b)
    assert strpos(" `cn2' ", " 0o.drug ") & !strpos(" `cn2' ", "1.drug")
    _v240_drugtr third
    regtab, coef("HR") compact mincount(1) notestlabel("NE") ///
        models("All" \ "Placebo" \ "Age") frame(_m1, replace)
    * r(N_masked) as in 2.3.1 (0o.drug, a level model 2 holds); the level
    * absent from model 2 is r(N_absent)
    assert r(N_masked) == 1
    assert r(N_absent) == 1
    _v240_cell _m1 A "0" c1 4
    assert "`r(cell)'" == "Reference"
    _v240_cell _m1 A "0" c3 4
    assert "`r(cell)'" == "NE"
    _v240_cell _m1 A "1" c3 4
    assert "`r(cell)'" == "NE"
    _v240_cell _m1 A "1" c4 4
    assert "`r(cell)'" == ""
    _v240_cell _m1 A "0" c5 4
    assert "`r(cell)'" == ""
    _v240_cell _m1 A "1" c5 4
    assert "`r(cell)'" == ""
    * default: the dash, never a blank
    regtab, coef("HR") compact mincount(1) models("All" \ "Placebo" \ "Age") frame(_m1, replace)
    _v240_cell _m1 A "1" c3 4
    assert "`r(cell)'" == "`dash'"
    * without mincount() a level absent from a model is still left blank
    regtab, coef("HR") compact frame(_m1, replace)
    _v240_cell _m1 A "1" c3 4
    assert "`r(cell)'" == ""
}
if _rc == 0 {
    display as result "  PASS: M1a mincount(): a level absent from e(b) is notestlabel(), not blank"
    local ++pass_count
}
else {
    display as error "  FAIL: M1a mincount() absent level (rc=`=_rc')"
    local ++fail_count
}

**# F1 flat frame labels
* F1a: frame(, flat) labels each column with its statistic header alone
* (plabel("P") is "P"); the model name is kept in char c#[tabtools_block]
* and the full header in char c#[tabtools_header]; names stay c1..c#.
local ++test_count
capture noisily {
    _v240_drugtr
    regtab, frame(_f1, replace flat) coef("HR") compact mincount(1) plabel("P") ///
        models("All" \ "Placebo")
    frame _f1 {
        quietly ds
        assert "`r(varlist)'" == "rowlabel c1 c2 c3 c4"
        local w : variable label c1
        assert "`w'" == "HR 95% CI"
        local w : variable label c2
        assert "`w'" == "P"
        local w : variable label c4
        assert "`w'" == "P"
        assert `"`: char c2[tabtools_header]'"' == "All, P"
        assert `"`: char c4[tabtools_header]'"' == "Placebo, P"
        assert `"`: char c2[tabtools_block]'"' == "All"
        assert `"`: char c3[tabtools_block]'"' == "Placebo"
        assert `"`: char _dta[tabtools_model_label_2]'"' == "Placebo"
    }
    * transpose: a column's block is its term, so the label keeps it
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    regtab, transpose frame(_f2, replace flat) plabel("P")
    frame _f2 {
        local w : variable label c2
        assert "`w'" == "Mileage (mpg), P"
    }
}
if _rc == 0 {
    display as result "  PASS: F1a flat frame short labels; model in characteristics"
    local ++pass_count
}
else {
    display as error "  FAIL: F1a flat frame labels (rc=`=_rc')"
    local ++fail_count
}

**# R1 addrow(..., after())
* R1a: rows placed after a factor's block, after one level, after a
* continuous term, two after one anchor in order, one appended below the
* stats() rows; inserted rows take the anchor's indentation; the
* eplotframe() source rows still point at their display rows.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price i.rep78 mpg i.foreign
    quietly collect: regress price i.rep78 mpg
    local book "`output_dir'/rt240_addrow.xlsx"
    capture erase "`book'"
    regtab, frame(_r1, replace flat) stats(n) eplotframe(_r1e, replace) ///
        xlsx("`book'") sheet("A") ///
        addrow("P trend" 0.03 0.04, after(rep78) \ "Note" x, after(mpg) \ ///
        "Second" y, after(rep78) \ "Bottom" 1 2 \ "Lvl" z, after(3.rep78))
    frame _r1 {
        generate long rn = _n
        foreach l in 3 5 {
            quietly summarize rn if strtrim(rowlabel) == "`l'", meanonly
            local r`l' = r(min)
        }
        foreach l in "P trend" "Second" "Lvl" "Note" "Bottom" "Observations" {
            quietly summarize rn if strtrim(rowlabel) == "`l'", meanonly
            assert r(N) == 1
            local r_`=strtoname("`l'")' = r(min)
        }
        quietly summarize rn if strtrim(rowlabel) == "Mileage (mpg)", meanonly
        local rmpg = r(min)
        assert `r_Lvl' == `r3' + 1
        assert `r_P_trend' == `r5' + 1
        assert `r_Second' == `r5' + 2
        assert `r_Note' == `rmpg' + 1
        assert `r_Bottom' == _N & `r_Observations' == _N - 1
        * values in the estimate columns, positionally
        assert strtrim(c1[`r_P_trend']) == "0.03" & strtrim(c4[`r_P_trend']) == "0.04"
        assert strtrim(c1[`r_Lvl']) == "z" & strtrim(c4[`r_Lvl']) == ""
        * the anchor's indentation
        local ind = ustrregexra(rowlabel[`r5'], "^( *).*$", "$1")
        assert strlen("`ind'") > 0
        assert rowlabel[`r_P_trend'] == "`ind'P trend"
        assert rowlabel[`r_Note'] == "Note"
        * a frame for the eplot check below
        tempfile disp
        quietly save "`disp'"
    }
    frame _r1e {
        quietly count
        assert r(N) > 0
        forvalues i = 1/`=_N' {
            local s = source_row[`i']
            local l = strtrim(label[`i'])
            frame _r1: assert strtrim(rowlabel[`s']) == "`l'"
        }
    }
    * the workbook: the inserted row's value spans the model's cells, with
    * no rule above it (the appended row keeps its rule)
    _v_facts "`book'" "A"
    _v_value B`=`r_Lvl' + 3' "`ind'Lvl"
    _v_has merge "" "C`=`r_Lvl' + 3':E`=`r_Lvl' + 3'"
    _v_none top "B`=`r_Lvl' + 3'"
    _v_value B`=`r_Bottom' + 3' "Bottom"
}
if _rc == 0 {
    display as result "  PASS: R1a addrow(after()) places rows in the body; eplot rows aligned"
    local ++pass_count
}
else {
    display as error "  FAIL: R1a addrow(after()) (rc=`=_rc')"
    local ++fail_count
}

* R1b: refusals: no matching row, an empty after(), several rows of one
* raw name, and a factor whose levels form several blocks (mlogit: one per
* equation). A row without after() is appended exactly as before.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price i.rep78 mpg
    capture regtab, addrow("x" 1, after(nosuch))
    assert _rc == 198
    capture regtab, addrow("x" 1, after())
    assert _rc == 198
    regtab, addrow("Plain, with comma" 1) frame(_r2, replace)
    frame _r2: assert strtrim(A[_N]) == "Plain, with comma"
    collect clear
    quietly collect: mlogit rep78 i.foreign mpg
    capture regtab, addrow("x" 1, after(foreign))
    assert _rc == 198
    capture regtab, addrow("x" 1, after(1.foreign))
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R1b addrow(after()) refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: R1b addrow(after()) refusals (rc=`=_rc')"
    local ++fail_count
}

**# D1 help file
local ++test_count
capture noisily {
    mata: _h = invtokens(cat(st_local("pkg_dir") + "/regtab.sthlp")', " ")
    foreach w in "notestl:abel(string)" "after(" "tabtools_block" {
        mata: st_local("hit", strofreal(strpos(_h, st_local("w")) > 0))
        assert `hit'
    }
    capture mata: mata drop _h
}
if _rc == 0 {
    display as result "  PASS: D1 help file documents notestlabel(), after(), tabtools_block"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 help file (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display "RESULT: test_regtab_v240 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture tabtools set clear
log close _rv240
if `fail_count' > 0 exit 1
