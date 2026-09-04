* test_regtab_omitted.do - constrained-coefficient labelling in regtab
* Regression suite for the base/omitted/empty distinction. Stata's collection
* reports a base category and a level dropped for collinearity as the same
* colname level ("4.grp") carrying the same zero (or one after eform) and the
* same empty interval, so before 2.1.0 every constrained level was labelled
* "Reference" and merged as one. Tests 1-9 fail on 2.0.3; test 10 pins the
* unchanged output of a model that drops nothing. Tests 11-15 cover the
* multi-equation and multilevel row keys and the factor parent rows.

clear all
set more off
set varabbrev off
version 17.0

capture log close _regtab_omitted
log using "test_regtab_omitted.log", replace text name(_regtab_omitted)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Return the trimmed contents of column `col' on the body row whose label is
* `label'. Errors rather than returning empty when the row is absent, so a
* renamed or dropped row cannot pass a cell assertion by accident.
capture program drop _rto_cell
program define _rto_cell, rclass
    version 17.0
    args frname label col
    frame `frname' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly summarize `rn' if strtrim(A) == "`label'" & _n >= 4, meanonly
        if r(N) == 0 {
            display as error "row not found in frame `frname': `label'"
            exit 459
        }
        local row = r(min)
        local cell = strtrim(`col'[`row'])
    }
    return local cell `"`cell'"'
end

* Count body rows whose column `col' equals `value'.
capture program drop _rto_count
program define _rto_count, rclass
    version 17.0
    args frname value col
    frame `frname' {
        quietly count if strtrim(`col') == "`value'" & _n >= 4
        local n = r(N)
    }
    return scalar n = `n'
end

capture program drop _rto_data
program define _rto_data
    version 17.0
    clear
    set obs 800
    generate grp = mod(_n, 4) + 1
    label define GL 1 "One" 2 "Two" 3 "Three" 4 "Four", replace
    label values grp GL
    label variable grp "Group"
    generate byte sex = mod(_n, 2)
    label variable sex "Sex"
    generate byte flag = (grp == 4)
    label variable flag "Flag"
    generate double x = rnormal()
    label variable x "X score"
    generate double y = 0.5 * x + 0.3 * (grp == 2) + rnormal()
    generate byte yb = y > 0
end

**# Test 1: a collinear factor level is Omitted, the base stays Reference
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect: regress y flag i.grp x

    capture frame drop _rto1
    quietly regtab, frame(_rto1, replace)

    _rto_cell _rto1 "One" c1
    assert "`r(cell)'" == "Reference"
    _rto_cell _rto1 "Four" c1
    assert "`r(cell)'" == "Omitted"
    _rto_count _rto1 "Reference" c1
    assert r(n) == 1

    * the constrained rows carry no interval and no p-value
    _rto_cell _rto1 "Four" c2
    assert "`r(cell)'" == ""
    _rto_cell _rto1 "Four" c3
    assert "`r(cell)'" == ""
}
if _rc == 0 {
    display as result "  PASS: collinear factor level labelled Omitted, base Reference"
    local ++pass_count
}
else {
    display as error "  FAIL: collinear factor level labelling (rc=`=_rc')"
    local ++fail_count
}

**# Test 2: a non-default base is the reference, not the lowest level
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect: regress y flag ib3.grp x

    capture frame drop _rto2
    quietly regtab, frame(_rto2, replace)

    _rto_cell _rto2 "Three" c1
    assert "`r(cell)'" == "Reference"
    _rto_cell _rto2 "Four" c1
    assert "`r(cell)'" == "Omitted"
    _rto_count _rto2 "Reference" c1
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: ib#. base is the only Reference"
    local ++pass_count
}
else {
    display as error "  FAIL: ib#. base labelling (rc=`=_rc')"
    local ++fail_count
}

**# Test 3: ibn. leaves no reference category at all
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect: regress y flag ibn.grp x, noconstant

    capture frame drop _rto3
    quietly regtab, frame(_rto3, replace) keepintercept

    _rto_count _rto3 "Reference" c1
    assert r(n) == 0
    _rto_cell _rto3 "Four" c1
    assert "`r(cell)'" == "Omitted"
}
if _rc == 0 {
    display as result "  PASS: ibn. reports no reference category"
    local ++pass_count
}
else {
    display as error "  FAIL: ibn. reference handling (rc=`=_rc')"
    local ++fail_count
}

**# Test 4: interaction cells separate base, collinear, and empty
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect: regress y i.grp##i.sex x if !(grp == 4 & sex == 1)

    capture frame drop _rto4
    quietly regtab, frame(_rto4, replace)

    * 1.sex is dropped for collinearity; 0.sex remains the base
    _rto_cell _rto4 "0" c1
    assert "`r(cell)'" == "Reference"
    _rto_cell _rto4 "1" c1
    assert "`r(cell)'" == "Omitted"
    * an interaction cell containing the base level of either factor
    _rto_cell _rto4 "1.grp#0.sex" c1
    assert "`r(cell)'" == "Reference"
    * cells that identify no observations
    _rto_cell _rto4 "1.grp#1.sex" c1
    assert "`r(cell)'" == "Empty"
    _rto_cell _rto4 "2.grp#0.sex" c1
    assert "`r(cell)'" == "Empty"
    * a cell dropped for collinearity
    _rto_cell _rto4 "2.grp#1.sex" c1
    assert "`r(cell)'" == "Omitted"
}
if _rc == 0 {
    display as result "  PASS: interaction cells separate base, omitted, empty"
    local ++pass_count
}
else {
    display as error "  FAIL: interaction constraint labelling (rc=`=_rc')"
    local ++fail_count
}

**# Test 5: an omitted continuous term keeps its label and is not a zero
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect: regress y i.grp x flag

    capture frame drop _rto5
    quietly regtab, frame(_rto5, replace)

    * the row is labelled by the variable, not by collect's "o.flag" key
    _rto_cell _rto5 "Flag" c1
    assert "`r(cell)'" == "Omitted"
    _rto_count _rto5 "o.flag" A
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: omitted continuous term labelled and marked Omitted"
    local ++pass_count
}
else {
    display as error "  FAIL: omitted continuous term (rc=`=_rc')"
    local ++fail_count
}

**# Test 6: the class is per model, never the union across models
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect, tag(cmdset[1]): regress y i.grp x
    quietly collect, tag(cmdset[2]): regress y flag i.grp x

    capture frame drop _rto6
    quietly regtab, frame(_rto6, replace) models("M1 \ M2")

    * model 1 estimates the level model 2 dropped
    _rto_cell _rto6 "Four" c1
    assert "`r(cell)'" != "Omitted"
    assert "`r(cell)'" != "Reference"
    assert real("`r(cell)'") < .
    _rto_cell _rto6 "Four" c2
    assert "`r(cell)'" != ""
    _rto_cell _rto6 "Four" c4
    assert "`r(cell)'" == "Omitted"
    _rto_cell _rto6 "One" c1
    assert "`r(cell)'" == "Reference"
    _rto_cell _rto6 "One" c4
    assert "`r(cell)'" == "Reference"
}
if _rc == 0 {
    display as result "  PASS: constraint class is per model"
    local ++pass_count
}
else {
    display as error "  FAIL: per-model constraint class (rc=`=_rc')"
    local ++fail_count
}

**# Test 7: eform models label the constrained level, not a bare 1.00
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect: logistic yb flag i.grp x

    capture frame drop _rto7
    quietly regtab, frame(_rto7, replace)

    _rto_cell _rto7 "Four" c1
    assert "`r(cell)'" == "Omitted"
    _rto_cell _rto7 "One" c1
    assert "`r(cell)'" == "Reference"
}
if _rc == 0 {
    display as result "  PASS: eform model labels the collinear level Omitted"
    local ++pass_count
}
else {
    display as error "  FAIL: eform constrained labelling (rc=`=_rc')"
    local ++fail_count
}

**# Test 8: omitlabel() and emptylabel() are honoured and must be distinct
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect: regress y i.grp##i.sex x if !(grp == 4 & sex == 1)

    capture frame drop _rto8
    quietly regtab, frame(_rto8, replace) refcat("Ref.") ///
        omitlabel("(omitted)") emptylabel("(empty)")

    _rto_cell _rto8 "One" c1
    assert "`r(cell)'" == "Ref."
    _rto_cell _rto8 "1" c1
    assert "`r(cell)'" == "(omitted)"
    _rto_cell _rto8 "1.grp#1.sex" c1
    assert "`r(cell)'" == "(empty)"

    capture frame drop _rto8b
    capture regtab, frame(_rto8b, replace) omitlabel("Reference")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: omitlabel()/emptylabel() honoured and validated"
    local ++pass_count
}
else {
    display as error "  FAIL: omitlabel()/emptylabel() handling (rc=`=_rc')"
    local ++fail_count
}

**# Test 9: constrained rows contribute nothing to r(table)
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect: regress y i.grp x flag

    capture frame drop _rto9
    quietly regtab, frame(_rto9, replace)
    tempname rt
    matrix `rt' = r(table)
    local rn : rownames `rt'
    * rownames carry the label-column indent as leading underscores
    local base_seen = 0
    local omit_seen = 0
    local level_seen = 0
    foreach rr of local rn {
        local rrs = regexr("`rr'", "^_+", "")
        if "`rrs'" == "One" local base_seen = 1
        if "`rrs'" == "Flag" | "`rrs'" == "o_flag" local omit_seen = 1
        if "`rrs'" == "Two" local level_seen = 1
    }
    * the base category and the term dropped for collinearity are not estimates
    assert `base_seen' == 0
    assert `omit_seen' == 0
    assert `level_seen' == 1
}
if _rc == 0 {
    display as result "  PASS: constrained rows excluded from r(table)"
    local ++pass_count
}
else {
    display as error "  FAIL: r(table) constrained-row handling (rc=`=_rc')"
    local ++fail_count
}

**# Test 10: a model with no constrained level beyond the base is unchanged
capture noisily {
    set seed 20260903
    _rto_data
    collect clear
    quietly collect: regress y i.grp x

    capture frame drop _rto10
    quietly regtab, frame(_rto10, replace)

    _rto_cell _rto10 "One" c1
    assert "`r(cell)'" == "Reference"
    _rto_count _rto10 "Reference" c1
    assert r(n) == 1
    _rto_count _rto10 "Omitted" c1
    assert r(n) == 0
    _rto_count _rto10 "Empty" c1
    assert r(n) == 0
    _rto_cell _rto10 "Four" c1
    assert real("`r(cell)'") < .
}
if _rc == 0 {
    display as result "  PASS: unconstrained model output unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: unconstrained model output (rc=`=_rc')"
    local ++fail_count
}

**# Test 11: multilevel (coleq) layout keeps the base/omitted distinction
* mixed renders through collect's coleq#colname layout, a different row-key
* path from the flat colname layout tests 1-10 exercise.
capture noisily {
    set seed 20260903
    _rto_data
    generate int clus = mod(_n - 1, 20) + 1
    collect clear
    quietly collect: mixed y flag i.grp x || clus:

    capture frame drop _rto11
    quietly regtab, frame(_rto11, replace)

    _rto_cell _rto11 "One" c1
    assert "`r(cell)'" == "Reference"
    _rto_cell _rto11 "Four" c1
    assert "`r(cell)'" == "Omitted"
    _rto_cell _rto11 "Two" c1
    assert real("`r(cell)'") < .
    _rto_count _rto11 "Reference" c1
    assert r(n) == 1
    _rto_count _rto11 "Omitted" c1
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: multilevel coleq layout labels base and omitted"
    local ++pass_count
}
else {
    display as error "  FAIL: multilevel coleq layout (rc=`=_rc')"
    local ++fail_count
}

**# Test 12: nested random effects on the exponentiated scale
* Two RE levels put four coleq values in the collection and an odds-ratio
* scale renders the constrained cell as 1.00 rather than 0.00.
capture noisily {
    set seed 20260903
    _rto_data
    generate int clus = mod(_n - 1, 20) + 1
    generate int subclus = mod(_n - 1, 40) + 1
    collect clear
    quietly collect: melogit yb flag i.grp x || clus: || subclus:, or

    capture frame drop _rto12
    quietly regtab, frame(_rto12, replace)

    _rto_cell _rto12 "One" c1
    assert "`r(cell)'" == "Reference"
    _rto_cell _rto12 "Four" c1
    assert "`r(cell)'" == "Omitted"
    _rto_cell _rto12 "Four" c2
    assert "`r(cell)'" == ""
    _rto_cell _rto12 "One" c2
    assert "`r(cell)'" == ""
    _rto_cell _rto12 "Two" c1
    assert real("`r(cell)'") < .
    _rto_cell _rto12 "Two" c2
    assert strpos("`r(cell)'", "(") == 1
}
if _rc == 0 {
    display as result "  PASS: nested RE eform layout labels base and omitted"
    local ++pass_count
}
else {
    display as error "  FAIL: nested RE eform layout (rc=`=_rc')"
    local ++fail_count
}

**# Test 13: the class is read per model column, not as a union
* Model 1 estimates 4.grp; model 2 drops it. A shared row must not take one
* model's constraint class from the other.
capture noisily {
    set seed 20260903
    _rto_data
    generate int clus = mod(_n - 1, 20) + 1
    collect clear
    quietly collect, tag(cmdset[1]): mixed y i.grp x || clus:
    quietly collect, tag(cmdset[2]): mixed y flag i.grp x || clus:

    capture frame drop _rto13
    quietly regtab, frame(_rto13, replace)

    _rto_cell _rto13 "Four" c1
    assert real("`r(cell)'") < .
    _rto_cell _rto13 "Four" c4
    assert "`r(cell)'" == "Omitted"
    _rto_cell _rto13 "One" c1
    assert "`r(cell)'" == "Reference"
    _rto_cell _rto13 "One" c4
    assert "`r(cell)'" == "Reference"
}
if _rc == 0 {
    display as result "  PASS: constraint class read per model column"
    local ++pass_count
}
else {
    display as error "  FAIL: per-model constraint class (rc=`=_rc')"
    local ++fail_count
}

**# Test 14: a wholly constrained equation is dropped, not half-printed
* In mlogit the base-outcome equation has no estimated coefficient at all.
* Its o.-marked rows were already dropped, but its factor levels - which
* collect reports without the marker - were left standing and labelled as if
* they were reference categories of the estimated equations.
capture noisily {
    set seed 20260903
    _rto_data
    generate byte ycat = mod(_n - 1, 3) + 1
    collect clear
    quietly collect: mlogit ycat flag i.grp x, base(1)

    capture frame drop _rto14
    quietly regtab, frame(_rto14, replace)

    frame _rto14 {
        quietly count if strpos(strtrim(A), "1: ") == 1 & _n >= 4
        assert r(N) == 0
        quietly count if strpos(strtrim(A), "2: ") == 1 & _n >= 4
        assert r(N) > 0
        quietly count if strpos(strtrim(A), "3: ") == 1 & _n >= 4
        assert r(N) > 0
    }
    _rto_cell _rto14 "2: 4.grp" c1
    assert "`r(cell)'" == "Omitted"
    _rto_cell _rto14 "3: 4.grp" c1
    assert "`r(cell)'" == "Omitted"
    _rto_cell _rto14 "2: 1.grp" c1
    assert "`r(cell)'" == "Reference"
}
if _rc == 0 {
    display as result "  PASS: wholly constrained equation dropped"
    local ++pass_count
}
else {
    display as error "  FAIL: wholly constrained equation (rc=`=_rc')"
    local ++fail_count
}

**# Test 15: an interaction gets one parent row, not one per level
* The parent of "1.grp#0.sex" is the term grp#sex. Taking only the first
* component made it "grp#0.sex", so every row printed its own header.
capture noisily {
    set seed 20260903
    _rto_data
    quietly replace sex = 1 if grp == 3
    collect clear
    quietly collect: regress y i.grp##i.sex x

    capture frame drop _rto15
    quietly regtab, frame(_rto15, replace)

    _rto_count _rto15 "grp#sex" A
    assert r(n) == 1
    frame _rto15 {
        quietly count if strpos(strtrim(A), "grp#0.sex") == 1 & _n >= 4
        assert r(N) == 0
        quietly count if strpos(strtrim(A), "grp#1.sex") == 1 & _n >= 4
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: interaction gets a single parent row"
    local ++pass_count
}
else {
    display as error "  FAIL: interaction parent row (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_regtab_omitted tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _regtab_omitted
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_regtab_omitted tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _regtab_omitted
