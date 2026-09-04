* test_effecttab_omitted.do - constrained-coefficient labelling in effecttab
* margins reports a not-estimable factor level as a constrained cell with no
* value. The saved collection stamps each such cell "base", "omit" or "empty"
* alongside the value; the renderer used to read whichever JSON member came
* first, so those cells printed the literal "omit" as the point estimate and
* "(omit, omit)" as the interval. Factor rows also arrived as the raw term
* "1.grp" rather than the variable and value labels regtab applies.
* Tests 1-7 fail on 2.0.3; test 8 pins the output of a model that constrains
* nothing beyond its base category.

clear all
set more off
set varabbrev off
version 17.0

capture log close _effecttab_omitted
log using "test_effecttab_omitted.log", replace text name(_effecttab_omitted)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Trimmed contents of column `col' on the body row labelled `label'. Errors
* rather than returning empty when the row is absent, so a renamed or dropped
* row cannot pass a cell assertion by accident.
capture program drop _eto_cell
program define _eto_cell, rclass
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
capture program drop _eto_count
program define _eto_count, rclass
    version 17.0
    args frname value col
    frame `frname' {
        quietly count if strtrim(`col') == "`value'" & _n >= 4
        local n = r(N)
    }
    return scalar n = `n'
end

* Count body rows in which column `col' contains `needle' anywhere.
capture program drop _eto_has
program define _eto_has, rclass
    version 17.0
    args frname needle col
    frame `frname' {
        quietly count if strpos(lower(`col'), lower("`needle'")) > 0 & _n >= 4
        local n = r(N)
    }
    return scalar n = `n'
end

capture program drop _eto_data
program define _eto_data
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

**# Test 1: not-estimable margins are Omitted, never the literal "omit"
capture noisily {
    set seed 20260903
    _eto_data
    quietly regress y flag i.grp x
    collect clear
    quietly collect: margins, dydx(*)

    capture frame drop _eto1
    quietly effecttab, frame(_eto1, replace)

    _eto_count _eto1 "omit" c1
    assert r(n) == 0
    _eto_has _eto1 "(omit" c2
    assert r(n) == 0
    _eto_cell _eto1 "One" c1
    assert "`r(cell)'" == "Reference"
    _eto_cell _eto1 "Two" c1
    assert "`r(cell)'" == "Omitted"
    _eto_cell _eto1 "Four" c1
    assert "`r(cell)'" == "Omitted"
    _eto_cell _eto1 "Two" c2
    assert "`r(cell)'" == ""
    _eto_cell _eto1 "Two" c3
    assert "`r(cell)'" == ""
    _eto_cell _eto1 "Flag" c1
    assert real("`r(cell)'") < .
}
if _rc == 0 {
    display as result "  PASS: not-estimable margins labelled Omitted"
    local ++pass_count
}
else {
    display as error "  FAIL: not-estimable margins labelling (rc=`=_rc')"
    local ++fail_count
}

**# Test 2: a cell identifying no observations is Empty, not "(empty, empty)"
capture noisily {
    set seed 20260903
    _eto_data
    quietly replace sex = 1 if grp == 3
    quietly regress y i.grp##i.sex x
    collect clear
    quietly collect: margins grp#sex

    capture frame drop _eto2
    quietly effecttab, frame(_eto2, replace)

    _eto_has _eto2 "empty," c2
    assert r(n) == 0
    _eto_cell _eto2 "3.grp#0.sex" c1
    assert "`r(cell)'" == "Empty"
    _eto_cell _eto2 "3.grp#0.sex" c2
    assert "`r(cell)'" == ""
    _eto_cell _eto2 "3.grp#1.sex" c1
    assert real("`r(cell)'") < .
}
if _rc == 0 {
    display as result "  PASS: unidentified margin labelled Empty"
    local ++pass_count
}
else {
    display as error "  FAIL: unidentified margin labelling (rc=`=_rc')"
    local ++fail_count
}

**# Test 3: the exponentiated path is labelled the same way
capture noisily {
    set seed 20260903
    _eto_data
    quietly logistic yb flag i.grp x
    collect clear
    quietly collect: margins, dydx(*)

    capture frame drop _eto3
    quietly effecttab, frame(_eto3, replace)

    _eto_count _eto3 "omit" c1
    assert r(n) == 0
    _eto_cell _eto3 "One" c1
    assert "`r(cell)'" == "Reference"
    _eto_cell _eto3 "Three" c1
    assert "`r(cell)'" == "Omitted"
}
if _rc == 0 {
    display as result "  PASS: eform margins labelled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: eform margins labelling (rc=`=_rc')"
    local ++fail_count
}

**# Test 4: predictive margins with no estimable level are all Omitted
* margins i.grp after a model that dropped a level has no reference category
* at all, so no row may be labelled Reference.
capture noisily {
    set seed 20260903
    _eto_data
    quietly regress y flag i.grp x
    collect clear
    quietly collect: margins i.grp

    capture frame drop _eto4
    quietly effecttab, frame(_eto4, replace)

    _eto_count _eto4 "Omitted" c1
    assert r(n) == 4
    _eto_count _eto4 "Reference" c1
    assert r(n) == 0
    _eto_has _eto4 "(omit" c2
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: no estimable level yields no Reference row"
    local ++pass_count
}
else {
    display as error "  FAIL: all-omitted predictive margins (rc=`=_rc')"
    local ++fail_count
}

**# Test 5: factor rows carry the variable label and one parent row
capture noisily {
    set seed 20260903
    _eto_data
    quietly regress y i.grp x
    collect clear
    quietly collect: margins, dydx(*)

    capture frame drop _eto5
    quietly effecttab, frame(_eto5, replace)

    _eto_count _eto5 "Group" A
    assert r(n) == 1
    _eto_count _eto5 "One" A
    assert r(n) == 1
    _eto_count _eto5 "Four" A
    assert r(n) == 1
    frame _eto5 {
        quietly count if strpos(strtrim(A), ".grp") > 0 & _n >= 4
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: factor rows use variable and value labels"
    local ++pass_count
}
else {
    display as error "  FAIL: factor row labels (rc=`=_rc')"
    local ++fail_count
}

**# Test 6: omitlabel() and emptylabel() are honoured and must differ
capture noisily {
    set seed 20260903
    _eto_data
    quietly regress y flag i.grp x
    collect clear
    quietly collect: margins, dydx(*)

    capture frame drop _eto6
    quietly effecttab, omitlabel("Dropped") frame(_eto6, replace)
    _eto_cell _eto6 "Two" c1
    assert "`r(cell)'" == "Dropped"
    _eto_count _eto6 "Omitted" c1
    assert r(n) == 0

    capture frame drop _eto6b
    capture effecttab, omitlabel("Reference") frame(_eto6b, replace)
    assert _rc == 198
    capture effecttab, omitlabel("Same") emptylabel("Same") frame(_eto6b, replace)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: omitlabel()/emptylabel() honoured and validated"
    local ++pass_count
}
else {
    display as error "  FAIL: omitlabel()/emptylabel() (rc=`=_rc')"
    local ++fail_count
}

**# Test 7: constrained rows contribute nothing to r(table)
capture noisily {
    set seed 20260903
    _eto_data
    quietly regress y flag i.grp x
    collect clear
    quietly collect: margins, dydx(*)

    capture frame drop _eto7
    quietly effecttab, frame(_eto7, replace)

    matrix _eto_rt = r(table)
    local _rn : rownames _eto_rt
    foreach _r of local _rn {
        local _rc_name = regexr("`_r'", "^_+", "")
        assert !inlist("`_rc_name'", "One", "Two", "Three", "Four")
    }
    assert rowsof(_eto_rt) == 2
}
if _rc == 0 {
    display as result "  PASS: constrained rows excluded from r(table)"
    local ++pass_count
}
else {
    display as error "  FAIL: r(table) constrained-row handling (rc=`=_rc')"
    local ++fail_count
}

**# Test 8: a model that constrains only its base category is unchanged
capture noisily {
    set seed 20260903
    _eto_data
    quietly regress y i.grp x
    collect clear
    quietly collect: margins, dydx(*)

    capture frame drop _eto8
    quietly effecttab, frame(_eto8, replace)

    _eto_cell _eto8 "One" c1
    assert "`r(cell)'" == "Reference"
    _eto_count _eto8 "Reference" c1
    assert r(n) == 1
    _eto_count _eto8 "Omitted" c1
    assert r(n) == 0
    _eto_count _eto8 "Empty" c1
    assert r(n) == 0
    _eto_cell _eto8 "Two" c1
    assert real("`r(cell)'") < .
    _eto_cell _eto8 "Four" c1
    assert real("`r(cell)'") < .
    _eto_cell _eto8 "X score" c1
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

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_effecttab_omitted tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _effecttab_omitted
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_effecttab_omitted tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _effecttab_omitted
