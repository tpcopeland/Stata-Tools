clear all
set more off
version 16.0

* test_datacheck.do - Functional tests for the datacheck command (datamap 1.2.0)
* Covers the QA plan in the datacheck spec:
*   classification parity with datamap, per-class rendering, id()/uniqueness,
*   every gate (pass + r(9) fail), warn downgrade, single() preservation,
*   patterns skip-when-absent, saving() output, and the touse-leak regression.

* === Bootstrap: targeted local reinstall ===
local qa_dir  "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard

* === Tally helper (globals so the helper can update counts) ===
global TC 0
global PASS 0
global FAIL 0
capture program drop _dc
program define _dc
    args rc msg
    global TC = $TC + 1
    if `rc' == 0 {
        display as result "  PASS: `msg'"
        global PASS = $PASS + 1
    }
    else {
        display as error "  FAIL (rc=`rc'): `msg'"
        global FAIL = $FAIL + 1
    }
end

* === Build a dataset with all variable classes ===
capture program drop _dc_make5
program define _dc_make5
    clear
    set obs 60
    gen long  pid    = _n
    gen double age   = 20 + mod(_n, 45)
    gen byte  grp    = mod(_n, 4)
    label define gl 0 "A" 1 "B" 2 "C" 3 "D", replace
    label values grp gl
    gen double dt    = mdy(1,1,2020) + _n
    format dt %td
    gen str12 nm     = "subj" + string(_n)
    gen byte  secret = mod(_n, 2)
end

* ============================================================
* 1. Classification parity: datacheck vs datamap on same data
* ============================================================
_dc_make5
tempfile mapout
capture {
    quietly datamap, output("`mapout'")
    local dm_cont  = trim("`r(continuous_vars)'")
    local dm_cat   = trim("`r(categorical_vars)'")
    local dm_date  = trim("`r(date_vars)'")
    local dm_str   = trim("`r(string_vars)'")
    quietly datacheck
    assert trim("`r(continuous_vars)'")  == "`dm_cont'"
    assert trim("`r(categorical_vars)'") == "`dm_cat'"
    assert trim("`r(date_vars)'")        == "`dm_date'"
    assert trim("`r(string_vars)'")      == "`dm_str'"
}
_dc `=_rc' "classification parity with datamap (all class lists match)"
capture erase "`mapout'"

* ============================================================
* 2. Per-class sections render for a 5-class dataset
* ============================================================
_dc_make5
capture noisily datacheck, exclude(secret)
local prc = _rc
capture {
    assert `prc' == 0
    assert "`r(continuous_vars)'"  != ""
    assert "`r(categorical_vars)'" != ""
    assert "`r(date_vars)'"        != ""
    assert "`r(string_vars)'"      != ""
    assert trim("`r(excluded_vars)'") == "secret"
}
_dc `=_rc' "all five class sections populate (continuous/categorical/date/string/excluded)"

* ============================================================
* 3. id() uniqueness report: panel vs person-level
* ============================================================
* Panel: 20 ids x 3 records
clear
set obs 60
gen long pid   = ceil(_n/3)
gen byte visit = mod(_n-1, 3) + 1
gen double y   = mod(_n, 7)
capture {
    quietly datacheck, id(pid)
    assert r(n_dup_pid) == 20
    * r(complete_cases)/r(complete_pct) on fully-complete data
    assert r(complete_cases) == 60
    assert r(complete_pct) == 100
}
_dc `=_rc' "id() panel report: 20 keys with >1 record; complete_cases/pct set"

capture {
    quietly datacheck, id(pid visit)
    assert r(n_dup_pid_visit) == 0
}
_dc `=_rc' "id() composite key (pid visit) is unique"

* Person-level: unique pid
clear
set obs 40
gen long pid = _n
gen double x = runiform()
capture {
    quietly datacheck, id(pid)
    assert r(n_dup_pid) == 0
}
_dc `=_rc' "id() person-level report: 0 keys with >1 record"

* ============================================================
* 4. Each gate: passes on conforming data, fails with r(9) otherwise
* ============================================================
_dc_make5

* expectn
capture qui datacheck, expectn(60)
_dc `=_rc' "expectn pass (N=60)"
capture qui datacheck, expectn(999)
capture assert _rc == 9
_dc `=_rc' "expectn fail halts with r(9)"
* expectn range
capture qui datacheck, expectn(50 70)
_dc `=_rc' "expectn range pass (50..70)"

* isid
capture qui datacheck, isid(pid)
_dc `=_rc' "isid pass (pid unique)"
* make pid non-unique
preserve
replace pid = 1 in 2
capture qui datacheck, isid(pid)
capture assert _rc == 9
_dc `=_rc' "isid fail halts with r(9)"
restore

* nodups
capture qui datacheck, nodups
_dc `=_rc' "nodups pass (no duplicate rows)"
preserve
expand 2 in 1
capture qui datacheck, nodups
capture assert _rc == 9
_dc `=_rc' "nodups fail halts with r(9)"
restore

* require
capture qui datacheck, require(pid age)
_dc `=_rc' "require pass (vars exist)"
capture qui datacheck, require(pid no_such_var)
capture assert _rc == 9
_dc `=_rc' "require fail halts with r(9)"

* notmissing
capture qui datacheck, notmissing(pid)
_dc `=_rc' "notmissing pass (pid complete)"
preserve
replace age = . in 1
capture qui datacheck, notmissing(age)
capture assert _rc == 9
_dc `=_rc' "notmissing fail halts with r(9)"
restore

* inrange
capture qui datacheck, inrange(age 0 200)
_dc `=_rc' "inrange pass (age within 0..200)"
capture qui datacheck, inrange(age 0 30)
capture assert _rc == 9
_dc `=_rc' "inrange fail halts with r(9)"

* ============================================================
* 5. warn downgrades violations to non-halting, still sets returns
* ============================================================
_dc_make5
capture {
    qui datacheck, expectn(999) inrange(age 0 30) warn
    assert _rc == 0
    assert r(n_violations) == 2
    assert strpos("`r(violations)'", "expectn") > 0
    assert strpos("`r(violations)'", "inrange") > 0
}
_dc `=_rc' "warn: violations reported, rc=0, r(n_violations)=2"

* ============================================================
* 6. single() profiles a saved file, leaves memory untouched
* ============================================================
_dc_make5
tempfile saved5
quietly save "`saved5'"
* load a different, smaller dataset
clear
set obs 5
gen byte token = _n
capture {
    quietly datacheck, single("`saved5'")
    * profiled the saved file (60 obs), not the 5-obs memory
    assert r(N) == 60
    * memory is untouched
    assert _N == 5
    confirm variable token
    capture confirm variable pid
    assert _rc != 0
}
_dc `=_rc' "single() profiles saved file (N=60) and preserves memory (N=5)"

* ============================================================
* 7. patterns: datamvp ships with the package, so it must be present and render
* ============================================================
_dc_make5
capture {
    * datamvp is bundled in datamap; the loader must resolve it
    qui which datamvp
    qui datacheck, patterns
}
_dc `=_rc' "patterns renders via bundled datamvp without error"

* ============================================================
* 8. saving(): file and frame; touse-leak regression (no phantom var)
* ============================================================
_dc_make5
local nvars = c(k)
tempfile prof
capture {
    quietly datacheck, saving("`prof'.dta", replace)
}
_dc `=_rc' "saving() to .dta file succeeds"
capture {
    preserve
    quietly use "`prof'.dta", clear
    * regression: exactly one row per profiled variable, no leaked tempvar
    assert _N == `nvars'
    confirm variable dc_class
    quietly count if strpos(varname, "__") == 1
    assert r(N) == 0
    restore
}
_dc `=_rc' "saved profile has one row per var, no phantom tempvar (touse-leak regression)"
capture erase "`prof'.dta"

_dc_make5
capture {
    quietly datacheck, saving(dcframe)
    frame dcframe: assert _N == `nvars'
}
_dc `=_rc' "saving() to a frame succeeds with one row per var"
capture frame drop dcframe

* ============================================================
* 9. exclude() privacy: excluded var absent from analytical class lists
* ============================================================
_dc_make5
* missingness lives ONLY in an excluded var -> completeness must be unaffected
replace secret = . in 1/10
capture {
    quietly datacheck, exclude(nm secret)
    assert strpos(" `r(string_vars)' ", " nm ") == 0
    assert strpos(" `r(categorical_vars)' ", " secret ") == 0
    assert strpos(" `r(excluded_vars)' ", " nm ") > 0
    assert strpos(" `r(excluded_vars)' ", " secret ") > 0
    * excluded var's missingness does not drive the completeness denominator
    assert r(complete_cases) == 60
    assert r(complete_pct) == 100
}
_dc `=_rc' "exclude() removes vars from class lists; excluded missingness ignored in complete_cases"

* ============================================================
* 10b. detail / rare / nomissing options run; complete_cases with missing
* ============================================================
_dc_make5
* introduce a rare categorical level and some missingness
replace grp = 9 in 1
replace age = . in 1/3
capture noisily quietly datacheck, detail rare(2) nomissing outliers(3)
local orc = _rc
capture {
    assert `orc' == 0
    * 3 obs have missing age -> 57 complete of 60
    assert r(complete_cases) == 57
    assert r(complete_pct)   == 95
}
_dc `=_rc' "detail/rare/nomissing/outliers run; complete_cases=57, complete_pct=95"

* ============================================================
* 10. varlist + if/in subsetting
* ============================================================
_dc_make5
capture {
    quietly datacheck age grp if pid <= 30
    assert r(N) == 30
    assert trim("`r(continuous_vars)'")  == "age"
    assert trim("`r(categorical_vars)'") == "grp"
    assert "`r(date_vars)'" == ""
}
_dc `=_rc' "varlist + if subset profiles only requested vars and rows"

* ============================================================
* Summary
* ============================================================
display as result "Results: $PASS/$TC passed, $FAIL failed"
if $FAIL > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datacheck tests=$TC pass=$PASS fail=$FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datacheck tests=$TC pass=$PASS fail=$FAIL"
