* test_regtab_v250.do - regtab after 2.4.0: user feedback, round 2
* Covers, each on its happy path, its refusal paths, and a known answer:
*   B1  a factor's base level when the variable is gone from memory or the
*       fit is no longer active: the fit's own notes (tabtools fitcount's
*       record, the active e(b)), never notestlabel() on the base
*   B2  interaction cells: base cells Reference, empty cells not estimable,
*       for stintreg, streg, stcox, logit, and an interaction without its
*       main effects
*   B3  a coefficient a constraint fixes: its value and cnslabel()
*   B4  stintreg: TR / HR headers, exponentiation, r(methods)
*   B5  mincount(): a level a model leaves out (no observation in its
*       sample) is absentlabel(), blank by default; one it holds unestimated
*       is notestlabel()
*   F9  mincount() accepts the column of a fit that failed
*   K   frame(name, flat keys): _order, _term, _rowtype, _state#
*   D   the help file's new options and its Editing a flat frame example
* Every expected value comes from the fit's own e(b)/e(V), the fixture's
* design, or the data, never from the table regtab builds.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rv250
log using "test_regtab_v250.log", replace text name(_rv250)

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
global V230_RES "`output_dir'/rt250_facts.txt"
run "`qa_dir'/_qa_v230_helpers.do"
quietly tabtools set clear

local dash = uchar(8211)

* Trimmed contents of column `col' on the one row of frame `fr' whose trimmed
* row label is `label', searching from row `from'.
capture program drop _v250_cell
program define _v250_cell, rclass
    version 17.0
    args fr label col from
    if "`from'" == "" local from 1
    frame `fr' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(rowlabel) == `"`label'"' & _n >= `from'
        if r(N) != 1 {
            display as error `"frame `fr': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(rowlabel) == `"`label'"' & _n >= `from', meanonly
        local row = r(min)
        local cell = strtrim(`col'[`row'])
    }
    return local cell `"`cell'"'
    return scalar row = `row'
end

* Trimmed contents of column `col' on the one row of keyed frame `fr' whose
* _term is `term'.
capture program drop _v250_kcell
program define _v250_kcell, rclass
    version 17.0
    args fr term col
    frame `fr' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if _term == `"`term'"'
        if r(N) != 1 {
            display as error `"frame `fr': `r(N)' rows with _term "`term'""'
            exit 459
        }
        quietly summarize `rn' if _term == `"`term'"', meanonly
        local row = r(min)
        local cell = strtrim(`col'[`row'])
    }
    return local cell `"`cell'"'
    return scalar row = `row'
end

* sysuse cancer with a three-level factor v and interval-censoring bounds
* for stintreg (t1 missing: right-censored). emptycell: drug 3 never holds
* v == 2; emptybase: drug 1 never holds v == 2.
capture program drop _v250_cancer
program define _v250_cancer
    version 17.0
    args opt
    sysuse cancer, clear
    quietly generate id = _n
    set seed 20261005
    quietly generate byte v = runiformint(0, 2)
    if "`opt'" == "emptycell" quietly replace v = 1 if drug == 3 & v == 2
    if "`opt'" == "emptybase" quietly replace v = 1 if drug == 1 & v == 2
    quietly generate double t0 = studytime
    quietly generate double t1 = cond(died, studytime, .)
    quietly stset studytime, failure(died) id(id)
    collect clear
end

* The levels of factor `fv' that the active e(b) marks as base (b.) and as
* omitted (o.), read from its column names: the fit's own record.
capture program drop _v250_marks
program define _v250_marks, rclass
    version 17.0
    args fv
    local cn : colnames e(b)
    local base ""
    local omit ""
    foreach c of local cn {
        if !ustrregexm("`c'", "^([0-9]+)([a-z]*)\.`fv'$") continue
        local lv = ustrregexs(1)
        local op = ustrregexs(2)
        if strpos("`op'", "b") & !strpos("`op'", "n") local base "`base' `lv'"
        if strpos("`op'", "o") local omit "`omit' `lv'"
    }
    return local base = strtrim("`base'")
    return local omit = strtrim("`omit'")
end

* Stata's own note ("(base)", "(empty)", "(omitted)", "") for every
* drug#v cell of the active e(b), read from its stripe equation by equation:
* returned as r(n_<drug>_<v>).
capture program drop _v250_inotes
program define _v250_inotes, rclass
    version 17.0
    quietly _ms_eq_info, matrix(e(b))
    local keq = r(k_eq)
    forvalues e = 1/`keq' {
        local ke_`e' = r(k`e')
    }
    local cn : colnames e(b)
    local j = 0
    forvalues e = 1/`keq' {
        forvalues i = 1/`ke_`e'' {
            local ++j
            local c : word `j' of `cn'
            quietly _ms_element_info, element(`i') equation(#`e') matrix(e(b))
            local note `"`r(note)'"'
            if ustrregexm("`c'", "^([0-9]+)[a-z]*\.drug#([0-9]+)[a-z]*\.v$") {
                local d = ustrregexs(1)
                local w = ustrregexs(2)
                if `e' == 1 local n_`d'_`w' `"`note'"'
            }
        }
    }
    foreach d in 1 2 3 {
        foreach w in 0 1 2 {
            return local n_`d'_`w' `"`n_`d'_`w''"'
        }
    }
end

* Every _state# of keyed frame `fr' against what the row prints: the model's
* columns share one state, and each state shows its own text. cpm: printed
* columns per model; compact 1 when the estimate and interval share a cell.
capture program drop _v250_states
program define _v250_states
    version 17.0
    args fr cpm compact ref omit notest masked absent cns
    frame `fr' {
        unab cv : c*
        local k : word count `cv'
        forvalues r = 1/`=_N' {
            forvalues j = 1/`k' {
                local j0 = floor((`j' - 1) / `cpm') * `cpm' + 1
                local s = _state`j'[`r']
                local s0 = _state`j0'[`r']
                if "`s'" != "`s0'" {
                    display as error "row `r': _state`j' (`s') differs from _state`j0' (`s0')"
                    exit 9
                }
                if `j' != `j0' continue
                local e = strtrim(c`j0'[`r'])
                local ok = 0
                if "`s'" == "ref" local ok = (`"`e'"' == `"`ref'"')
                else if "`s'" == "omit" local ok = (`"`e'"' == `"`omit'"')
                else if "`s'" == "notest" local ok = (`"`e'"' == `"`notest'"')
                else if "`s'" == "masked" local ok = (`"`e'"' == `"`masked'"')
                else if "`s'" == "absent" local ok = (`"`e'"' == `"`absent'"')
                else if "`s'" == "empty" {
                    local ok = 1
                    forvalues q = `j0'/`=`j0' + `cpm' - 1' {
                        if strtrim(c`q'[`r']) != "" local ok = 0
                    }
                }
                else if inlist("`s'", "stat", "text") local ok = (`"`e'"' != "")
                else if "`s'" == "note" local ok = 1
                else if "`s'" == "est" {
                    local ok = !missing(real(word(`"`e'"', 1)))
                }
                else if "`s'" == "constrained" {
                    if `compact' local ok = ustrregexm(`"`e'"', "^[-0-9.]+ ") & strpos(`"`e'"', `"`cns'"') > 0
                    else local ok = !missing(real(`"`e'"')) & strtrim(c`=`j0' + 1'[`r']) == `"`cns'"'
                }
                if !`ok' {
                    display as error `"row `r' (`=_term[`r']'): _state`j0' is `s' but c`j0' prints "`e'""'
                    exit 9
                }
            }
        }
    }
end

**# B1 base levels without the data or the active fit
* B1a: stintreg's collection records every constrained cell as "empty"; with
* drug and v dropped and another fit active, the base must still be the
* reference: Stata stores the values exponentiated (HR), so the value rule
* reads the base as 1 on the hazard-ratio scale.
local ++test_count
capture noisily {
    _v250_cancer
    quietly stintreg i.drug i.v age, interval(t0 t1) distribution(weibull)
    _v250_marks drug
    assert "`r(base)'" == "1"
    _v250_marks v
    assert "`r(base)'" == "0"
    quietly collect get e(), tags(cmdset[1])
    drop drug v
    quietly regress age studytime
    regtab, notestlabel("NE") frame(_b1, replace flat)
    _v250_cell _b1 "1.drug" c1
    assert "`r(cell)'" == "Reference"
    _v250_cell _b1 "0.v" c1
    assert "`r(cell)'" == "Reference"
    _v250_cell _b1 "2.drug" c1
    assert !missing(real("`r(cell)'"))
}
if _rc == 0 {
    display as result "  PASS: B1a dropped variables: the base stays Reference"
    local ++pass_count
}
else {
    display as error "  FAIL: B1a dropped variables base (rc=`=_rc')"
    local ++fail_count
}

* B1b: two constrained levels of v (the base and a collinear one). With the
* variable dropped and the fit inactive, fitcount's record tells them apart;
* without it (B1d) nothing can, and neither is called the reference. B1c:
* the active fit decides even though v is gone from memory.
local ++test_count
capture noisily {
    _v250_cancer
    quietly generate byte dup = v == 2
    quietly stintreg dup i.v age, interval(t0 t1) distribution(weibull)
    _v250_marks v
    assert "`r(base)'" == "0" & "`r(omit)'" == "2"
    quietly collect get e(), tags(cmdset[1])
    quietly tabtools fitcount, events(_d) terms
    drop v
    quietly regress age studytime
    regtab, notestlabel("NE") omitlabel("Om") frame(_b1, replace flat)
    _v250_cell _b1 "0.v" c1
    assert "`r(cell)'" == "Reference"
    _v250_cell _b1 "2.v" c1
    assert "`r(cell)'" == "Om"
    * B1c: no record, the active fit
    _v250_cancer
    quietly generate byte dup = v == 2
    quietly collect: stintreg dup i.v age, interval(t0 t1) distribution(weibull)
    drop v
    regtab, notestlabel("NE") omitlabel("Om") frame(_b1, replace flat)
    _v250_cell _b1 "0.v" c1
    assert "`r(cell)'" == "Reference"
    _v250_cell _b1 "2.v" c1
    assert "`r(cell)'" == "Om"
    * B1d: no record, inactive, data gone: neither level is the reference
    quietly regress age studytime
    regtab, notestlabel("NE") omitlabel("Om") frame(_b1, replace flat)
    _v250_cell _b1 "0.v" c1
    assert "`r(cell)'" == "NE"
    _v250_cell _b1 "2.v" c1
    assert "`r(cell)'" == "NE"
}
if _rc == 0 {
    display as result "  PASS: B1b-d base vs omitted from the record, the active fit, or neither"
    local ++pass_count
}
else {
    display as error "  FAIL: B1b-d base vs omitted (rc=`=_rc')"
    local ++fail_count
}

**# B2 interaction cells
* Cells are found by the frame's _term key: since 2.6.2 the printed label of
* an interaction level comes from the variables' labels while they are in
* memory and from collect's key once they are dropped (pass 2), so the key is
* the one stable handle.
* B2a: stintreg i.drug##i.v with the cell drug 3 x v 2 empty. Stata's rule
* for a full factorial: a cell with drug at its base (1) or v at its base (0)
* is a base cell; the empty cell is not estimable. Expected from the data,
* never from the table. Not active, no record, data present (B2a); record,
* data gone (B2b).
local ++test_count
capture noisily {
    forvalues pass = 1/2 {
        _v250_cancer emptycell
        quietly stintreg i.drug##i.v age, interval(t0 t1) distribution(weibull)
        quietly collect get e(), tags(cmdset[1])
        if `pass' == 2 quietly tabtools fitcount, events(_d) terms
        foreach d in 1 2 3 {
            foreach w in 0 1 2 {
                quietly count if e(sample) & drug == `d' & v == `w'
                local n_`d'_`w' = r(N)
            }
        }
        assert `n_3_2' == 0 & `n_2_2' > 0 & `n_1_2' > 0
        if `pass' == 2 drop drug v
        quietly regress age studytime
        regtab, notestlabel("NE") frame(_b2, replace flat keys)
        foreach d in 1 2 3 {
            foreach w in 0 1 2 {
                _v250_kcell _b2 "`d'.drug#`w'.v" c1
                local c `"`r(cell)'"'
                if `d' == 1 | `w' == 0 assert "`c'" == "Reference"
                else if `n_`d'_`w'' == 0 assert "`c'" == "NE"
                else assert !missing(real("`c'"))
            }
        }
    }
}
if _rc == 0 {
    display as result "  PASS: B2a/b stintreg interaction: base cells Reference, the empty cell NE"
    local ++pass_count
}
else {
    display as error "  FAIL: B2a/b stintreg interaction cells (rc=`=_rc')"
    local ++fail_count
}

* B2a2: a factor by continuous interaction. The stripe marks the base cell
* 0b.v#co.age, which collect keys 0.v#age; the record and the active fit
* must key it the same way, or the base cell turns not estimable. No
* record, data present; record, data present; record, data gone.
local ++test_count
capture noisily {
    forvalues pass = 1/3 {
        _v250_cancer
        quietly stintreg i.v##c.age, interval(t0 t1) distribution(weibull)
        _ms_element_info, element(5) matrix(e(b))
        assert "`r(note)'" == "(base)"
        quietly collect get e(), tags(cmdset[1])
        if `pass' >= 2 quietly tabtools fitcount, events(_d) terms
        if `pass' == 3 drop v
        quietly regress age studytime
        regtab, notestlabel("NE") frame(_b2c, replace flat keys)
        _v250_kcell _b2c "0.v#age" c1
        assert "`r(cell)'" == "Reference"
        _v250_kcell _b2c "1.v#age" c1
        assert !missing(real("`r(cell)'"))
    }
}
if _rc == 0 {
    display as result "  PASS: B2a2 factor#continuous base cell stays Reference with fitcount's record"
    local ++pass_count
}
else {
    display as error "  FAIL: B2a2 factor#continuous base cell (rc=`=_rc')"
    local ++fail_count
}

* B2c: the same factorial under streg (collect: every cell "empty"), stcox
* and logit (collect classes them itself). The empty cell is never the
* reference; logit's collinear and perfectly predicted cells keep their
* classes, read from the stripe notes Stata prints.
local ++test_count
capture noisily {
    _v250_cancer emptycell
    quietly generate byte y = died
    quietly streg i.drug##i.v age, distribution(weibull)
    quietly collect get e(), tags(cmdset[1])
    quietly stcox i.drug##i.v age
    quietly collect get e(), tags(cmdset[2])
    quietly logit y i.drug##i.v age
    quietly collect get e(), tags(cmdset[3])
    * logit's own notes per cell, from the e(b) stripe
    _v250_inotes
    foreach d in 1 2 3 {
        foreach w in 0 1 2 {
            local lnote_`d'_`w' `"`r(n_`d'_`w')'"'
        }
    }
    foreach d in 1 2 3 {
        foreach w in 0 1 2 {
            quietly count if drug == `d' & v == `w'
            local n_`d'_`w' = r(N)
        }
    }
    regtab, notestlabel("NE") omitlabel("Om") frame(_b2, replace flat keys)
    foreach d in 1 2 3 {
        foreach w in 0 1 2 {
            _v250_kcell _b2 "`d'.drug#`w'.v" c1
            local c `"`r(cell)'"'
            if `d' == 1 | `w' == 0 assert "`c'" == "Reference"
            else if `n_`d'_`w'' == 0 assert "`c'" == "NE"
            else assert !missing(real("`c'"))
            _v250_kcell _b2 "`d'.drug#`w'.v" c4
            local c `"`r(cell)'"'
            if `d' == 1 | `w' == 0 assert "`c'" == "Reference"
            else if `n_`d'_`w'' == 0 assert "`c'" == "NE"
            else assert !missing(real("`c'"))
            _v250_kcell _b2 "`d'.drug#`w'.v" c7
            local c `"`r(cell)'"'
            local ln `"`lnote_`d'_`w''"'
            if `"`ln'"' == "(base)" assert "`c'" == "Reference"
            else if `"`ln'"' == "(empty)" assert "`c'" == "NE"
            else if `"`ln'"' == "(omitted)" assert "`c'" == "Om"
            else assert !missing(real("`c'"))
        }
    }
}
if _rc == 0 {
    display as result "  PASS: B2c streg/stcox/logit interaction cells"
    local ++pass_count
}
else {
    display as error "  FAIL: B2c streg/stcox/logit interaction cells (rc=`=_rc')"
    local ++fail_count
}

* B2d: an interaction without its main effects (i.drug#i.v), drug 1 never
* holding v 2: the cell 1.drug#2.v carries drug's base level and is empty,
* not a base. With the record its class is the fit's own; without the record
* and the fit, no constrained cell may read Reference.
local ++test_count
capture noisily {
    _v250_cancer emptybase
    quietly stintreg i.drug#i.v age, interval(t0 t1) distribution(weibull)
    _v250_inotes
    foreach d in 1 2 3 {
        foreach w in 0 1 2 {
            local note_`d'_`w' `"`r(n_`d'_`w')'"'
        }
    }
    quietly count if e(sample) & drug == 1 & v == 2
    assert r(N) == 0
    assert `"`note_1_2'"' == "(empty)" & `"`note_1_0'"' == "(base)"
    quietly collect get e(), tags(cmdset[1])
    quietly tabtools fitcount, events(_d) terms
    quietly regress age studytime
    regtab, notestlabel("NE") frame(_b2, replace flat keys)
    foreach d in 1 2 3 {
        foreach w in 0 1 2 {
            _v250_kcell _b2 "`d'.drug#`w'.v" c1
            local c `"`r(cell)'"'
            if `"`note_`d'_`w''"' == "(base)" assert "`c'" == "Reference"
            else if `"`note_`d'_`w''"' == "(empty)" assert "`c'" == "NE"
            else assert !missing(real("`c'"))
        }
    }
    * without the record: nothing in the block reads Reference
    _v250_cancer emptybase
    quietly stintreg i.drug#i.v age, interval(t0 t1) distribution(weibull)
    quietly collect get e(), tags(cmdset[1])
    quietly regress age studytime
    regtab, notestlabel("NE") frame(_b2, replace flat keys)
    frame _b2: quietly count if strpos(_term, "drug#") & strtrim(c1) == "Reference"
    assert r(N) == 0
    _v250_kcell _b2 "1.drug#2.v" c1
    assert "`r(cell)'" == "NE"
}
if _rc == 0 {
    display as result "  PASS: B2d interaction without main effects: empty cell never Reference"
    local ++pass_count
}
else {
    display as error "  FAIL: B2d interaction without main effects (rc=`=_rc')"
    local ++fail_count
}

**# B3 coefficients a constraint fixes
* stintreg (HR), cnsreg (Coef.), glm binomial (OR), each with 2.drug = 0.5
* and age = 0.05 fixed and fitcount's record; the table shows the fixed
* value on its scale and cnslabel() where the interval would be.
local ++test_count
capture noisily {
    _v250_cancer
    quietly generate byte y = died
    constraint define 91 age = 0.05
    constraint define 92 2.drug = 0.5
    quietly stintreg i.drug age, interval(t0 t1) distribution(weibull) constraints(91 92)
    assert el(e(V), colnumb(e(b), "2.drug"), colnumb(e(b), "2.drug")) == 0
    quietly collect get e(), tags(cmdset[1])
    quietly tabtools fitcount, events(_d)
    quietly cnsreg studytime i.drug age, constraints(91 92)
    quietly collect get e(), tags(cmdset[2])
    quietly tabtools fitcount, events(_d)
    quietly glm y i.drug age, family(binomial) constraints(91 92)
    quietly collect get e(), tags(cmdset[3])
    quietly tabtools fitcount, events(_d)
    quietly regress age studytime
    regtab, notestlabel("NE") frame(_b3, replace flat) eplotframe(_b3e, replace)
    tempname T
    matrix `T' = r(table)
    local ld : label (drug) 2
    _v250_cell _b3 "`ld'" c1
    assert "`r(cell)'" == strtrim(string(exp(0.5), "%9.2f"))
    _v250_cell _b3 "`ld'" c2
    assert "`r(cell)'" == "(constrained)"
    _v250_cell _b3 "`ld'" c3
    assert "`r(cell)'" == ""
    _v250_cell _b3 "`ld'" c4
    assert "`r(cell)'" == "0.50"
    _v250_cell _b3 "`ld'" c5
    assert "`r(cell)'" == "(constrained)"
    _v250_cell _b3 "`ld'" c7
    assert "`r(cell)'" == strtrim(string(exp(0.5), "%9.2f"))
    local la : variable label age
    _v250_cell _b3 `"`la'"' c1
    assert "`r(cell)'" == strtrim(string(exp(0.05), "%9.2f"))
    _v250_cell _b3 `"`la'"' c4
    assert "`r(cell)'" == "0.05"
    _v250_cell _b3 `"`la'"' c5
    assert "`r(cell)'" == "(constrained)"
    * r(table) holds the fixed value; the eplot frame posts it as constrained
    * row names keep the level's indent as underscores
    local rn : rownames `T'
    local i : list posof "__`ld'" in rn
    assert `i' > 0
    assert !missing(`T'[`i', 1], exp(0.5))
    assert reldif(`T'[`i', 1], exp(0.5)) < 1e-8
    assert !missing(`T'[`i', 2])
    assert reldif(`T'[`i', 2], 0.5) < 1e-8
    frame _b3e: quietly count if rowtype == "constrained" & model == 1 & reldif(estimate, exp(0.5)) < 1e-8 & missing(ll)
    assert r(N) == 1
    regtab, compact cnslabel("(fixed)") frame(_b3, replace flat)
    _v250_cell _b3 "`ld'" c1
    assert "`r(cell)'" == strtrim(string(exp(0.5), "%9.2f")) + " (fixed)"
    * the cnsreg fit, active and without fitcount's record, is read the same
    collect clear
    quietly collect: cnsreg studytime i.drug age, constraints(91 92)
    regtab, frame(_b3, replace flat)
    _v250_cell _b3 "`ld'" c2
    assert "`r(cell)'" == "(constrained)"
}
local rc = _rc
capture constraint drop 91 92
if `rc' == 0 {
    display as result "  PASS: B3 constrained coefficients: value with cnslabel()"
    local ++pass_count
}
else {
    display as error "  FAIL: B3 constrained coefficients (rc=`rc')"
    local ++fail_count
}

**# B4 stintreg display scale
* The estimate header names the numbers under it: time ratios in the
* log-time metric (tratio or not), hazard ratios in the log-hazard metric
* (nohr or not), each value the exponent of the fit's own coefficient.
local ++test_count
capture noisily {
    _v250_cancer
    local specs `""ggamma) tratio" "ggamma)" "weibull)" "weibull) nohr" "weibull) time" "gompertz)" "lognormal)""'
    local hdrs "TR TR HR HR TR HR TR"
    local m = 0
    foreach s of local specs {
        local ++m
        quietly stintreg i.drug age, interval(t0 t1) distribution(`s'
        local b_`m' = _b[2.drug]
        quietly collect get e(), tags(cmdset[`m'])
    }
    regtab, frame(_b4, replace flat)
    assert r(coef_label) == "mixed"
    local ld : label (drug) 2
    forvalues m = 1/7 {
        local hd : word `m' of `hdrs'
        local cc = 3 * `m' - 2
        frame _b4: local vl : variable label c`cc'
        assert "`vl'" == "`hd'"
        _v250_cell _b4 "`ld'" c`cc'
        assert "`r(cell)'" == strtrim(string(exp(`b_`m''), "%9.2f"))
    }
    * one model at a time: the header and r(methods)
    collect clear
    quietly collect: stintreg i.drug age, interval(t0 t1) distribution(ggamma)
    regtab
    assert r(coef_label) == "TR"
    assert strpos(r(methods), "Time ratios with 95% confidence intervals from multivariable interval-censored accelerated failure-time survival regression.") == 1
    collect clear
    quietly collect: stintreg i.drug age, interval(t0 t1) distribution(weibull)
    regtab
    assert r(coef_label) == "HR"
    assert strpos(r(methods), "Hazard ratios with 95% confidence intervals from multivariable interval-censored parametric proportional hazards survival regression.") == 1
}
if _rc == 0 {
    display as result "  PASS: B4 stintreg TR/HR headers, values, r(methods)"
    local ++pass_count
}
else {
    display as error "  FAIL: B4 stintreg scale (rc=`=_rc')"
    local ++fail_count
}

**# B5 levels a model leaves out
* B5a: the round-1 repro. Model 2 is fitted on drug == 1 only: 1.drug is in
* its e(b) (omitted: every observation holds it) and is not estimable; drugs
* 2 and 3 have no observation in its sample and are left out by design:
* absentlabel(), blank by default, "–" as 2.4.0 printed with
* absentlabel("–").
local ++test_count
capture noisily {
    _v250_cancer
    quietly stcox i.drug age
    quietly collect get e(), tags(cmdset[1])
    quietly tabtools fitcount, events(_d) terms
    quietly stcox i.drug age if drug == 1
    local cn : colnames e(b)
    assert !strpos(" `cn' ", "2.drug") & !strpos(" `cn' ", "3.drug")
    quietly count if e(sample) & drug != 1
    assert r(N) == 0
    quietly collect get e(), tags(cmdset[2])
    quietly tabtools fitcount, events(_d) terms
    local l1 : label (drug) 1
    local l2 : label (drug) 2
    local l3 : label (drug) 3
    regtab, coef("HR") compact mincount(1) notestlabel("NE") frame(_b5, replace flat)
    assert r(N_absent) == 2
    assert r(N_masked) == 1
    _v250_cell _b5 "`l1'" c3
    assert "`r(cell)'" == "NE"
    _v250_cell _b5 "`l2'" c3
    assert "`r(cell)'" == ""
    _v250_cell _b5 "`l3'" c3
    assert "`r(cell)'" == ""
    _v250_cell _b5 "`l1'" c1
    assert "`r(cell)'" == "Reference"
    regtab, coef("HR") compact mincount(1) notestlabel("NE") absentlabel("`dash'") frame(_b5, replace flat)
    assert r(N_absent) == 2
    _v250_cell _b5 "`l2'" c3
    assert "`r(cell)'" == "`dash'"
    _v250_cell _b5 "`l3'" c3
    assert "`r(cell)'" == "`dash'"
    * the 2.4.0 output: default labels and absentlabel("–")
    regtab, coef("HR") compact mincount(1) absentlabel("`dash'") frame(_b5, replace flat)
    _v250_cell _b5 "`l1'" c3
    assert "`r(cell)'" == "`dash'"
    _v250_cell _b5 "`l2'" c3
    assert "`r(cell)'" == "`dash'"
    * refusals
    capture regtab, absentlabel("x")
    assert _rc == 198
    capture regtab, mincount(1) absentlabel("Reference")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: B5a absent levels blank by default, absentlabel(), refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: B5a absent levels (rc=`=_rc')"
    local ++fail_count
}

* B5b: a level a model's sample holds but its e(b) leaves out (the explicit
* level 3.drug: drugs 1 and 2 are in the sample) is not estimable, never
* blank; counts from a fitcount that recorded no sample levels (an emulated
* 2.4.0 record: tt_terms and tt_events only) cannot tell, so the missing
* levels read notestlabel().
local ++test_count
capture noisily {
    _v250_cancer
    quietly stcox i.drug age
    quietly collect get e(), tags(cmdset[1])
    quietly tabtools fitcount, events(_d) terms
    quietly stcox 3.drug age
    local cn : colnames e(b)
    assert "`cn'" == "3.drug age"
    quietly count if e(sample) & drug == 1
    assert !missing(r(N)) & r(N) > 0
    quietly collect get e(), tags(cmdset[2])
    quietly tabtools fitcount, events(_d) terms
    local l1 : label (drug) 1
    local l2 : label (drug) 2
    regtab, mincount(1) notestlabel("NE") absentlabel("AB") frame(_b5, replace flat)
    local l3 : label (drug) 3
    _v250_cell _b5 "`l1'" c4
    assert "`r(cell)'" == "NE"
    _v250_cell _b5 "`l2'" c4
    assert "`r(cell)'" == "NE"
    _v250_cell _b5 "`l3'" c4
    assert !missing(real("`r(cell)'"))
    * the emulated older record
    _v250_cancer
    quietly stcox i.drug age
    quietly collect get e(), tags(cmdset[1])
    quietly tabtools fitcount, events(_d) terms
    quietly stcox i.drug age if drug == 1
    quietly collect get e(), tags(cmdset[2])
    quietly collect copy default _v250old
    quietly collect set _v250old
    quietly tabtools fitcount, events(_d) terms
    local tt `"`r(terms)'"'
    local ev = r(events)
    quietly collect set default
    quietly collect drop _v250old
    quietly collect get tt_terms = ("`tt'"), tags(cmdset[2])
    quietly collect get tt_events = (`ev'), tags(cmdset[2])
    regtab, mincount(1) notestlabel("NE") absentlabel("AB") frame(_b5, replace flat)
    _v250_cell _b5 "`l2'" c4
    assert "`r(cell)'" == "NE"
}
if _rc == 0 {
    display as result "  PASS: B5b held-but-unestimated and unrecorded levels are notestlabel()"
    local ++pass_count
}
else {
    display as error "  FAIL: B5b held or unrecorded levels (rc=`=_rc')"
    local ++fail_count
}

**# F9 mincount() and a fit that failed
* Eleven columns; model 10 is a fit that failed, collected as an empty cmdset
* (collect get e() after e() was cleared) and, in a second pass, as a
* placeholder result. mincount() accepts it, masks nothing there, and the
* other models keep their own scale; a column with estimates but without
* counts is still refused.
local ++test_count
capture noisily {
    foreach mode in empty placeholder {
        _v250_cancer
        forvalues m = 1/11 {
            if `m' == 10 {
                capture stcox i.drug age if age > 1000
                assert _rc == 2000
                if "`mode'" == "empty" {
                    ereturn clear
                    quietly collect get e(), tags(cmdset[10])
                }
                else quietly collect get failed = "Did not converge", tags(cmdset[10])
                capture tabtools fitcount, events(_d) terms
                assert _rc
                continue
            }
            quietly stcox i.drug age if age >= 46 + `m'
            quietly collect get e(), tags(cmdset[`m'])
            quietly tabtools fitcount, events(_d) terms
        }
        regtab, mincount(3) notestlabel("NE") frame(_f9, replace flat)
        assert r(N_models) == 11
        assert r(coef_label) == "HR"
        assert strpos(r(methods), "Hazard ratios") == 1
        frame _f9 {
            assert strtrim(c28) == "" & strtrim(c29) == "" & strtrim(c30) == ""
            local vl : variable label c28
            assert "`vl'" == "HR"
            quietly count if strtrim(c31) != ""
            assert !missing(r(N)) & r(N) > 0
        }
    }
    * estimates without counts: refused, the model named
    _v250_cancer
    quietly stcox i.drug age
    quietly collect get e(), tags(cmdset[1])
    quietly stcox i.drug
    quietly collect get e(), tags(cmdset[2])
    quietly tabtools fitcount, events(_d) terms
    capture regtab, mincount(3)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: F9 mincount() accepts a failed fit's column among 11"
    local ++pass_count
}
else {
    display as error "  FAIL: F9 failed fit column (rc=`=_rc')"
    local ++fail_count
}

**# K frame(name, flat keys)
* K1: keys only add variables. The keyed frame minus its key variables is the
* plain flat frame: same data, labels, and characteristics.
local ++test_count
capture noisily {
    _v250_cancer
    quietly stcox i.drug i.v age
    quietly collect get e(), tags(cmdset[1])
    quietly stcox i.drug age
    quietly collect get e(), tags(cmdset[2])
    regtab, compact stats(n) addrow("Note" a b) frame(_k1a, replace flat)
    regtab, compact stats(n) addrow("Note" a b) frame(_k1b, replace flat keys)
    frame _k1b {
        local keys : char _dta[tabtools_keys]
        assert "`keys'" == "_order _term _rowtype _state1 _state2 _state3 _state4"
        foreach k of local keys {
            local kc : char `k'[tabtools_key]
            assert "`kc'" == "1"
        }
        drop `keys'
        char _dta[tabtools_keys]
    }
    frame _k1a {
        local nk : char _dta[tabtools_keys]
        assert "`nk'" == ""
        tempfile fa
        quietly save `"`fa'"'
        unab va : _all
        foreach v of local va {
            local lab_`v' : variable label `v'
        }
        local ca : char _dta[]
    }
    frame _k1b {
        unab vb : _all
        assert "`va'" == "`vb'"
        * stata-dev-ignore: cf-one-directional — the varlists of both frames are asserted equal (va == vb) three lines above, so no variable can be dropped unseen
        cf _all using `"`fa'"'
        foreach v of local vb {
            local lb : variable label `v'
            assert `"`lb'"' == `"`lab_`v''"'
            local cv : char `v'[]
            foreach c of local cv {
                local x : char `v'[`c']
                frame _k1a: local y : char `v'[`c']
                * the block id names its regtab call: two calls never share it
                if "`c'" == "tabtools_block_id" {
                    assert `"`x'"' != "" & `"`y'"' != "" & `"`x'"' != `"`y'"'
                    continue
                }
                assert `"`x'"' == `"`y'"'
            }
        }
        local cb : char _dta[]
        local ca2 : list ca - cb
        local cb2 : list cb - ca
        assert "`ca2'" == "tabtools_companion_id" | "`ca2'" == ""
    }
    * refusals: keys without flat; keys with transpose
    capture regtab, frame(_k1c, replace keys)
    assert _rc == 198
    capture regtab, transpose frame(_k1c, replace flat keys)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: K1 keys only add variables; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: K1 keys add-only (rc=`=_rc')"
    local ++fail_count
}

* K2: eleven models (the cmdset order 1 10 11 2 ... is a text order, the
* columns are numeric), mincount() masking, absentlabel(), reftop. Every
* model's expected state of every level is computed from its own fit and
* data: absent when no observation of its sample holds the level, ref for
* the base e(b) marks, masked when the level's events are fewer than k,
* else est. Every _state# also matches the text the row prints.
local ++test_count
capture noisily {
    clear
    set seed 4242
    quietly set obs 900
    quietly generate id = _n
    quietly generate byte edss = runiformint(0, 3)
    quietly replace edss = 9 if runiform() < 0.15
    quietly generate byte ms = runiformint(1, 3)
    quietly replace ms = 9 if runiform() < 0.012
    quietly generate double age = rnormal(45, 10)
    quietly generate double t = rexponential(5)
    quietly generate byte d = runiform() < 0.5
    quietly stset t, failure(d) id(id)
    local k = 6
    collect clear
    forvalues m = 1/11 {
        local cond "id > (`m' - 1) * 40"
        if `m' == 11 local cond "edss != 9"
        quietly stcox i.edss ib3.ms age if `cond'
        tempname V
        matrix `V' = e(V)
        local cn : colnames e(b)
        foreach fv in edss ms {
            quietly levelsof `fv', local(levs)
            foreach l of local levs {
                quietly count if e(sample) & `fv' == `l'
                local nobs = r(N)
                quietly count if e(sample) & `fv' == `l' & _d
                local nev = r(N)
                local st "est"
                local j : list posof "`l'b.`fv'" in cn
                if `nobs' == 0 local st "absent"
                else if `j' > 0 local st "ref"
                else if `nev' < `k' local st "masked"
                else {
                    local j : list posof "`l'.`fv'" in cn
                    if `j' == 0 local st "notest"
                    else if !(`V'[`j', `j'] > 0 & `V'[`j', `j'] < .) local st "notest"
                }
                local x_`m'_`l'_`fv' "`st'"
            }
        }
        quietly collect get e(), tags(cmdset[`m'])
        quietly tabtools fitcount, events(_d) terms
    }
    * at least one masked and one absent cell, or the test proves little
    local nmask = 0
    forvalues m = 1/11 {
        if "`x_`m'_9_ms'" == "masked" local ++nmask
    }
    assert `nmask' > 0 & "`x_11_9_edss'" == "absent"
    regtab, compact mincount(`k') reftop refcat("R") omitlabel("O") notestlabel("NE") ///
        emptylabel("<`k'") absentlabel("AB") stats(n) frame(_k2, replace flat keys)
    _v250_states _k2 2 1 "R" "O" "NE" "<`k'" "AB" "(constrained)"
    forvalues m = 1/11 {
        local cc = 2 * `m' - 1
        foreach fv in edss ms {
            quietly levelsof `fv', local(levs)
            foreach l of local levs {
                _v250_kcell _k2 "`l'.`fv'" _state`cc'
                if "`r(cell)'" != "`x_`m'_`l'_`fv''" {
                    display as error "model `m' `l'.`fv': state `r(cell)', expected `x_`m'_`l'_`fv''"
                    exit 9
                }
            }
        }
    }
    frame _k2 {
        assert _order == _n
        quietly count if _rowtype == "factor" & inlist(_term, "edss", "ms")
        assert r(N) == 2
        quietly count if _rowtype == "var" & _term == "age"
        assert r(N) == 1
        quietly count if _rowtype == "stat" & substr(_term, 1, 5) == "stat:"
        assert r(N) == 1
        * reftop: the base of ms (3) heads its block
        quietly summarize _order if _term == "ms", meanonly
        local h = r(min)
        assert _term[`h' + 1] == "3.ms"
    }
}
if _rc == 0 {
    display as result "  PASS: K2 eleven models: every _state# from the fit, and as printed"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 eleven-model keys (rc=`=_rc')"
    local ++fail_count
}

* K3: a multi-equation table: the equation leads the term (4:mpg), the
* factor heading and levels keep it, and addrow() rows are numbered in the
* order given wherever they are placed.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: mlogit rep78 mpg i.foreign if rep78 >= 3, baseoutcome(3)
    regtab, refcat("R") frame(_k3, replace flat keys) stats(n) ///
        addrow("first" 1 \ "second" 2)
    frame _k3 {
        foreach e in 4 5 {
            quietly count if _term == "`e':foreign" & _rowtype == "factor"
            assert r(N) == 1
            quietly count if _term == "`e':0.foreign" & _rowtype == "level" & _state1 == "ref" & strtrim(c1) == "R"
            assert r(N) == 1
            quietly count if _term == "`e':1.foreign" & _rowtype == "level" & _state1 == "est"
            assert r(N) == 1
            quietly count if _term == "`e':mpg" & _rowtype == "var" & _state1 == "est" & _state3 == "est"
            assert r(N) == 1
        }
        quietly count if substr(_term, 1, 2) == "3:"
        assert r(N) == 0
        assert _term[_N - 1] == "addrow:1" & _term[_N] == "addrow:2"
        assert rowlabel[_N - 1] == "first" & _rowtype[_N] == "addrow" & _state1[_N] == "text"
        assert _rowtype[_N - 2] == "stat"
    }
    _v250_states _k3 3 0 "R" "Omitted" "Empty" "Empty" "" "(constrained)"
}
if _rc == 0 {
    display as result "  PASS: K3 multi-equation terms and addrow numbering"
    local ++pass_count
}
else {
    display as error "  FAIL: K3 multi-equation keys (rc=`=_rc')"
    local ++fail_count
}

* K4: addrow(..., after()) rows are keyed by their position in addrow(), and
* the constrained and note states print as their cells do.
local ++test_count
capture noisily {
    _v250_cancer
    constraint define 93 age = 0.05
    quietly stcox i.drug
    quietly collect get e(), tags(cmdset[1])
    quietly cnsreg studytime i.drug age, constraints(93)
    quietly collect get e(), tags(cmdset[2])
    local ld : label (drug) 3
    regtab, frame(_k4, replace flat keys) addrow("P trend" 0.1 0.2, after(drug) \ "Last" x y) ///
        cellnote("`ld'" 1 "see text")
    frame _k4 {
        quietly count if _term == "addrow:1" & _rowtype == "addrow"
        assert r(N) == 1
        quietly summarize _order if _term == "addrow:1", meanonly
        assert _term[r(min) - 1] == "3.drug"
        assert _term[_N] == "addrow:2"
        quietly count if _term == "age" & _state4 == "constrained" & _state6 == "constrained" & strtrim(c5) == "(constrained)"
        assert r(N) == 1
        quietly count if _term == "3.drug" & _state1 == "note" & strtrim(c1) == "see text"
        assert r(N) == 1
    }
    _v250_states _k4 3 0 "Reference" "Omitted" "Empty" "Empty" "" "(constrained)"
}
local rc = _rc
capture constraint drop 93
if `rc' == 0 {
    display as result "  PASS: K4 addrow() and cellnote() keys, constrained state"
    local ++pass_count
}
else {
    display as error "  FAIL: K4 addrow()/cellnote() keys (rc=`rc')"
    local ++fail_count
}

**# L long fit-time records
* L1: a 20 x 20 factorial with half its cells empty: fitcount's records run
* past the 2,045 bytes collect get name = ("...") accepts. Every count is
* stored, every record whole (its length as computed from the fit), and
* mincount() reads the last level of the long record.
local ++test_count
capture noisily {
    clear
    set seed 11
    quietly set obs 4000
    quietly generate byte a = runiformint(1, 20)
    quietly generate byte b = runiformint(1, 20)
    quietly drop if mod(a + b, 2)
    quietly generate double x = rnormal()
    quietly generate double y = rpoisson(2)
    quietly generate byte d = y > 2
    collect clear
    quietly collect: poisson y x i.a#i.b
    _regtab_bnotes
    local ncns = strlen(`"`_bn_notes'"')
    assert `ncns' > 2045
    quietly count if e(sample) & d
    local nev = r(N)
    tabtools fitcount, events(d)
    assert r(events) == `nev'
    tabtools fitcount, events(d) terms
    local nterms = strlen(r(terms))
    assert `nterms' > 2045
    _regtab_fitrec tt_cns tt_terms tt_levels tt_events
    mata: assert(strlen(st_local("_fr_tt_cns_1")) == `ncns')
    mata: assert(strlen(st_local("_fr_tt_terms_1")) == `nterms')
    mata: assert(strlen(st_local("_fr_tt_levels_1")) > 0)
    assert real("`_fr_tt_events_1'") == `nev'
    * the last cell of the factorial: its events, from the data
    quietly count if e(sample) & d & a == 20 & b == 20
    local e2020 = r(N)
    local k = `e2020' + 1
    regtab, mincount(`k') emptylabel("THIN") frame(_l1, replace flat keys)
    _v250_kcell _l1 "20.a#20.b" c1
    assert "`r(cell)'" == "THIN"
}
if _rc == 0 {
    display as result "  PASS: L1 records past 2,045 bytes are stored whole; counts never lost"
    local ++pass_count
}
else {
    display as error "  FAIL: L1 long fit-time records (rc=`=_rc')"
    local ++fail_count
}

**# C constrained factor levels without a record or the active fit
* C1: constraint 3.rep78 = 0 in a logit: Stata prints 1 (empty), 2 (empty),
* 3 (omitted) (its own stripe notes, read at fit time). With the fit no
* longer active and no record, level 3 is never the reference: Omitted while
* the data resolve the base (level 1), not estimable with a note once rep78
* is gone. An ib4. command line resolves without the data.
local ++test_count
capture noisily {
    sysuse auto, clear
    constraint define 94 3.rep78 = 0
    collect clear
    quietly logit foreign mpg i.rep78, constraints(94)
    local cn : colnames e(b)
    local j = 0
    foreach c of local cn {
        local ++j
        quietly _ms_element_info, element(`j') matrix(e(b))
        if ustrregexm("`c'", "^([0-9]+)[a-z]*\.rep78$") {
            local lv = ustrregexs(1)
            local note_`lv' `"`r(note)'"'
        }
    }
    assert `"`note_1'"' == "(empty)" & `"`note_3'"' == "(omitted)"
    quietly collect get e(), tags(cmdset[1])
    ereturn clear
    regtab, notestlabel("NE") omitlabel("Om") frame(_c1, replace flat)
    foreach l in 1 2 3 5 {
        _v250_cell _c1 "`l'" c1
        local c `"`r(cell)'"'
        if `"`note_`l''"' == "(empty)" assert "`c'" == "NE"
        if `"`note_`l''"' == "(omitted)" assert "`c'" == "Om"
    }
    frame _c1: quietly count if strtrim(c1) == "Reference"
    assert r(N) == 0
    * the variable gone: the base cannot be told, never a Reference
    preserve
    drop rep78
    regtab, notestlabel("NE") omitlabel("Om") frame(_c1, replace flat)
    frame _c1: quietly count if strtrim(c1) == "Reference"
    assert r(N) == 0
    _v250_cell _c1 "3.rep78" c1
    assert "`r(cell)'" == "NE"
    restore
    * ib4. resolves without the data; the fixed level 5 is omitted
    constraint define 95 5.rep78 = 0
    collect clear
    quietly logit foreign mpg ib4.rep78 if rep78 >= 3, constraints(95)
    quietly collect get e(), tags(cmdset[1])
    ereturn clear
    drop rep78
    regtab, notestlabel("NE") omitlabel("Om") frame(_c1, replace flat)
    _v250_cell _c1 "4.rep78" c1
    assert "`r(cell)'" == "Reference"
    _v250_cell _c1 "5.rep78" c1
    assert "`r(cell)'" == "Om"
}
local rc = _rc
capture constraint drop 94 95
if `rc' == 0 {
    display as result "  PASS: C1 a level a constraint fixes is never a wrong Reference"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 constrained level without record (rc=`rc')"
    local ++fail_count
}

* F9b: a collect get e() straight after a fit that failed collects the
* previous model again (e() is not cleared); regtab says so.
local ++test_count
capture noisily {
    _v250_cancer
    quietly stcox i.drug age
    quietly collect get e(), tags(cmdset[1])
    capture stcox i.drug age if age > 1000
    assert _rc == 2000 & "`e(cmd)'" == "cox"
    quietly collect get e(), tags(cmdset[2])
    quietly stcox i.drug
    quietly collect get e(), tags(cmdset[3])
    tempfile f9log
    quietly log using `"`f9log'"', text replace name(_f9b)
    regtab
    quietly log close _f9b
    mata: _L = cat(st_local("f9log")); assert(sum(strpos(_L, "model 2 repeats model 1") :> 0) == 1); assert(!any(strpos(_L, "model 3 repeats")))
    capture mata: mata drop _L
}
if _rc == 0 {
    display as result "  PASS: F9b a model repeating an earlier one is noted"
    local ++pass_count
}
else {
    display as error "  FAIL: F9b duplicate model note (rc=`=_rc')"
    local ++fail_count
}

**# U user text is data
* U1: a model name, an addcol() label and value, and sep() holding $name,
* a backquote and an apostrophe print byte for byte (compared in Mata) in the
* display frame, the flat frame's characteristics, and the CSV; the global and
* local they name are never substituted. 2.4.0 re-expanded models() under
* compact, addcol() everywhere, and sep() in the renderer.
local ++test_count
* stata-dev-ignore: rc-only-test — the content oracles are the frame/mata-prefixed mata: assert(...) comparisons in this block (leaked-global and cell-text checks); the rule does not parse an assert behind a mata: prefix
capture noisily {
    global V250_SECRET "LEAKED"
    local x "XLOCAL"
    mata: st_local("T", "A $" + "V250_SECRET b" + char(96) + "x" + char(39) + "c")
    mata: _rt_T = st_local("T")
    local csv "`output_dir'/rt250_u1.csv"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.foreign
    quietly collect: regress price mpg weight i.foreign
    foreach c in "" compact {
        capture erase "`csv'"
        regtab, models(`"`macval(T)'"' \ "B") `c' frame(_u1, replace) csv("`csv'")
        * the name heads model 1's block (row 2 of the display frame)
        frame _u1: mata: assert(st_sdata(2, "c1") == _rt_T)
        frame _u1: mata: assert(st_global("_dta[tabtools_model_label_1]") == _rt_T)
        mata: _C = cat(st_local("csv")); assert(any(strpos(_C, _rt_T))); assert(!any(strpos(_C, "LEAKED"))); assert(!any(strpos(_C, "XLOCAL")))
        regtab, models(`"`macval(T)'"' \ "B") `c' frame(_u1f, replace flat)
        frame _u1f: mata: assert(st_global("c1[tabtools_block]") == _rt_T)
    }
    * sep(): both bounds joined by the text as typed
    capture erase "`csv'"
    regtab, sep(`"`macval(T)'"') frame(_u1, replace) csv("`csv'")
    frame _u1: mata: _S = st_sdata(., "c2"); assert(any(strpos(_S, _rt_T))); assert(!any(strpos(_S, "LEAKED")))
    mata: _C = cat(st_local("csv")); assert(any(strpos(_C, _rt_T))); assert(!any(strpos(_C, "LEAKED")))
    * a double quote is a separator like any other (help tabtools##sep)
    regtab, sep(`"a"b"') frame(_u1, replace)
    frame _u1: mata: _S = st_sdata(., "c2"); assert(any(strpos(_S, "a" + char(34) + "b")))
    * addcol(): the label (header) and a value
    regtab, transpose keep(mpg) addcol(`"`macval(T)'"' 1 2) frame(_u1, replace)
    frame _u1: mata: assert(any(st_sdata(., "c3") :== _rt_T))
    regtab, transpose keep(mpg) addcol("Lab" `"`macval(T)'"' 2) frame(_u1, replace)
    frame _u1: mata: assert(any(st_sdata(., "c3") :== _rt_T))
    capture mata: mata drop _rt_T _C _S
    capture macro drop V250_SECRET
}
if _rc == 0 {
    display as result "  PASS: U1 models(), sep(), addcol() text printed byte for byte"
    local ++pass_count
}
else {
    display as error "  FAIL: U1 user text (rc=`=_rc')"
    local ++fail_count
}
capture macro drop V250_SECRET

**# D help file
* D1: the new options and the keys are documented.
local ++test_count
capture noisily {
    mata: _h = invtokens(cat(st_local("pkg_dir") + "/regtab.sthlp")', " ")
    foreach w in "absentl:abel(string)" "cnsl:abel(string)" "replace flat keys" "_state" "tt_cns" "tt_levels" "stintreg" "Editing a flat frame" {
        mata: st_local("hit", strofreal(strpos(_h, st_local("w")) > 0))
        assert `hit'
    }
    capture mata: mata drop _h
}
if _rc == 0 {
    display as result "  PASS: D1 help file documents absentlabel(), cnslabel(), flat keys"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 help file (rc=`=_rc')"
    local ++fail_count
}

* D2: the help file's "Editing a flat frame" example, run as written (the
* workbook goes to the output directory): the cell found by name, the row
* placed by _order, and the rule above the stats() row in the workbook.
local ++test_count
capture noisily {
    mata: _L = cat(st_local("pkg_dir") + "/regtab.sthlp")
    mata: _a = selectindex(strpos(_L, "{bf:Editing a flat frame.}"))
    mata: _L = _L[(_a[1] + 1)::rows(_L)]
    mata: _e = selectindex(substr(_L, 1, 6) :== "{pstd}")
    mata: _L = _L[1::(_e[1] - 1)]
    mata: _L = select(_L, substr(_L, 1, 15) :== "{phang2}{cmd:. ")
    mata: _L = subinstr(subinstr(substr(_L, 16, .), "{p_end}", ""), "}", "")
    mata: st_local("nl", strofreal(rows(_L)))
    assert `nl' >= 15
    local book "`output_dir'/rt250_editflat.xlsx"
    capture erase "`book'"
    forvalues i = 1/`nl' {
        mata: st_local("cmd", subinstr(_L[`i'], "regression.xlsx", st_local("book")))
        display as text `". `macval(cmd)'"'
        `cmd'
    }
    capture mata: mata drop _L _a _e
    frame t {
        quietly count if _term == "1.lengthy" & strtrim(c1) == "see note"
        assert r(N) == 1
        quietly count if _term == "1.heavy" & !missing(real(word(c1, 1)))
        assert r(N) == 1
        quietly count if strtrim(rowlabel) == "Yes"
        assert r(N) == 2
        local vr = .
        forvalues r = 1/`=_N' {
            if strtrim(rowlabel[`r']) == "Vehicle size" local vr = `r'
        }
        assert _term[`vr' + 1] == "heavy"
        quietly count if substr(_term, 1, 5) == "stat:"
        assert r(N) == 1
        assert substr(_term[_N], 1, 5) == "stat:"
        local statlab = strtrim(rowlabel[_N])
    }
    _v_facts "`book'" "Edited"
    * the cell holding the stats() row's label, then a top border on it and
    * none on the row above it (the rule hlines() draws)
    mata: _f = cat("$V230_RES"); _i = selectindex(ustrregexm(_f, "^value [A-Z]+[0-9]+ ") :& (ustrregexra(_f, "^value [A-Z]+[0-9]+ ", "") :== st_local("statlab")))
    mata: st_local("srow", strofreal(rows(_i)))
    assert `srow' == 1
    mata: st_local("scell", ustrregexra(_f[_i[1]], "^value ([A-Z]+[0-9]+) .*$", "$1"))
    mata: st_local("scol", ustrregexra(st_local("scell"), "[0-9]+$", "")); st_local("srw", ustrregexra(st_local("scell"), "^[A-Z]+", ""))
    local above "`scol'`=`srw' - 1'"
    mata: st_local("ntop", strofreal(sum(substr(_f, 1, strlen("top `scell' ")) :== "top `scell' ")))
    assert `ntop' == 1
    mata: st_local("nprev", strofreal(sum(substr(_f, 1, strlen("top `above' ")) :== "top `above' ")))
    assert `nprev' == 0
    capture mata: mata drop _f _i
}
if _rc == 0 {
    display as result "  PASS: D2 the Editing a flat frame example runs and does what it says"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 Editing a flat frame example (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display "RESULT: test_regtab_v250 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture constraint drop 91 92 93 94 95
capture frame drop t
foreach f in _b1 _b2 _b2c _b3 _b3e _b4 _b5 _f9 _k1a _k1b _k2 _k3 _k4 _u1 _u1f _l1 _c1 {
    capture frame drop `f'
}
capture tabtools set clear
log close _rv250
if `fail_count' > 0 exit 1
