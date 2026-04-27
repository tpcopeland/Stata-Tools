* Focused regression tests for tabtools issue fixes

clear all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local output_dir "`qa_dir'/output_issue_regressions"
capture mkdir "`output_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Test 1: stratetab supports console-only mode without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, cond(_n == 2, 20, 30))
    gen _Y = cond(_n == 1, 1000, cond(_n == 2, 1100, 1200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp
    save "`rate1'.dta", replace

    sysuse auto, clear
    stratetab, using("`rate1'") outcomes(1) display
    assert r(N_rows) >= 6
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab display without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display without xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* Test 2: stratetab supports frame() without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 15, cond(_n == 2, 25, 35))
    gen _Y = cond(_n == 1, 900, cond(_n == 2, 1000, 1100))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp2 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp2
    save "`rate1'.dta", replace

    sysuse auto, clear
    capture frame drop issue_rates
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates, replace)
    assert r(frame) == "issue_rates"
    frame issue_rates: assert _N >= 6
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture frame drop issue_rates

* Test 3: stratetab supports display + frame() together without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 12, cond(_n == 2, 22, 32))
    gen _Y = cond(_n == 1, 950, cond(_n == 2, 1050, 1150))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp3 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp3
    save "`rate1'.dta", replace

    sysuse auto, clear
    capture frame drop issue_rates2
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates2, replace) display
    assert r(frame) == "issue_rates2"
    frame issue_rates2: assert _N >= 6
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab display + frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display + frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture frame drop issue_rates2

* Test 4: stratetab rejects open without xlsx()
local ++test_count
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 12, cond(_n == 2, 22, 32))
    gen _Y = cond(_n == 1, 950, cond(_n == 2, 1050, 1150))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp4 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp4
    save "`rate1'.dta", replace

    sysuse auto, clear
    capture stratetab, using("`rate1'") outcomes(1) open
    assert _rc == 198
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab open requires xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab open requires xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

* Test 5: crosstab validates boldp() bounds
local ++test_count
capture noisily {
    clear
    input exposure outcome
    0 0
    0 1
    1 0
    1 1
    end
    capture crosstab exposure outcome, boldp(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: crosstab rejects invalid boldp()"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rejects invalid boldp() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

* Test 6: survtab validates highlight() bounds
local ++test_count
capture noisily {
    clear
    set obs 20
    gen byte group = (_n > 10)
    gen double time = _n
    gen byte event = (_n <= 10)
    stset time, failure(event)
    capture survtab, times(1 2 3) by(group) highlight(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: survtab rejects invalid highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab rejects invalid highlight() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

* Test 7: table1_tc headerperc works with total(before)
local ++test_count
capture noisily {
    clear
    input g y z
    0 1 0
    0 2 1
    0 3 1
    1 4 .
    1 5 .
    1 6 .
    end
    table1_tc, by(g) vars(y contn \ z bin) headerperc total(before) clear
    assert g_T[2] == "6 (100.0%)"
    assert g_0[2] == "3 (50.0%)"
    assert g_1[2] == "3 (50.0%)"
}
if _rc == 0 {
    display as result "  PASS: table1_tc headerperc total(before)"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc headerperc total(before) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

* Test 8: table1_tc headerperc works with total(after)
local ++test_count
capture noisily {
    clear
    input g y z
    0 1 0
    0 2 1
    0 3 1
    1 4 .
    1 5 .
    1 6 .
    end
    table1_tc, by(g) vars(y contn \ z bin) headerperc total(after) clear
    assert g_T[2] == "6 (100.0%)"
    assert g_0[2] == "3 (50.0%)"
    assert g_1[2] == "3 (50.0%)"
}
if _rc == 0 {
    display as result "  PASS: table1_tc headerperc total(after)"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc headerperc total(after) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

* Test 9: table1_tc wt() smd works when categorical variable is first
local ++test_count
capture noisily {
    clear
    input g cat bin x w
    0 1 0 1 1
    0 1 0 2 1
    0 2 1 3 4
    1 1 0 4 3
    1 2 1 5 1
    1 2 1 6 1
    end
    table1_tc, by(g) vars(cat cat \ x contn \ bin bin) wt(w) smd

    tempname T
    matrix `T' = r(table)
    local _cnames : colnames `T'
    local _cat_row = rownumb(`T', "cat")
    local _x_row = rownumb(`T', "x")
    local _bin_row = rownumb(`T', "bin")
    assert colsof(`T') == 1
    assert "`_cnames'" == "smd"
    assert `_cat_row' < .
    assert `_x_row' < .
    assert `_bin_row' < .
    assert el(`T', `_cat_row', 1) < .
    assert el(`T', `_x_row', 1) < .
    assert el(`T', `_bin_row', 1) < .
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() smd categorical-first"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() smd categorical-first (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

* Test 10: table1_tc wt() smd uses weighted, non-stale values by variable type
local ++test_count
capture noisily {
    clear
    input g cat bin x w
    0 1 0 1 1
    0 1 0 2 1
    0 2 1 3 4
    1 1 0 4 3
    1 2 1 5 1
    1 2 1 6 1
    end

    quietly summarize x [aw=w] if g == 0
    local _m0 = r(mean)
    local _sd0 = r(sd)
    quietly summarize x [aw=w] if g == 1
    local _m1 = r(mean)
    local _sd1 = r(sd)
    local _cont_exp = abs((`_m0' - `_m1') / sqrt((`_sd0'^2 + `_sd1'^2) / 2))

    local _cat_ssq 0
    quietly levelsof cat, local(_cat_levels)
    foreach _clv of local _cat_levels {
        quietly summarize w if g == 0
        local _w0 = r(sum)
        quietly summarize w if cat == `_clv' & g == 0
        local _p0 = r(sum) / `_w0'
        quietly summarize w if g == 1
        local _w1 = r(sum)
        quietly summarize w if cat == `_clv' & g == 1
        local _p1 = r(sum) / `_w1'
        local _pavg = (`_p0' + `_p1') / 2
        local _den = sqrt(`_pavg' * (1 - `_pavg'))
        if `_den' > 0 local _cat_ssq = `_cat_ssq' + ((`_p0' - `_p1') / `_den')^2
    }
    local _cat_exp = sqrt(`_cat_ssq')

    quietly summarize bin [aw=w] if g == 0
    local _bp0 = r(mean)
    quietly summarize bin [aw=w] if g == 1
    local _bp1 = r(mean)
    local _bin_exp = abs((`_bp0' - `_bp1') / sqrt((`_bp0' * (1 - `_bp0') + `_bp1' * (1 - `_bp1')) / 2))

    table1_tc, by(g) vars(x contn \ cat cat \ bin bin) wt(w) smd
    tempname T
    matrix `T' = r(table)
    local _x_row = rownumb(`T', "x")
    local _cat_row = rownumb(`T', "cat")
    local _bin_row = rownumb(`T', "bin")
    assert colsof(`T') == 1
    assert `_x_row' < .
    assert `_cat_row' < .
    assert `_bin_row' < .
    assert abs(el(`T', `_x_row', 1) - `_cont_exp') < 0.001
    assert abs(el(`T', `_cat_row', 1) - `_cat_exp') < 0.001
    assert abs(el(`T', `_bin_row', 1) - `_bin_exp') < 0.001
    assert abs(el(`T', `_cat_row', 1) - el(`T', `_x_row', 1)) > 0.001
    assert abs(el(`T', `_bin_row', 1) - el(`T', `_x_row', 1)) > 0.001
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() smd weighted non-stale values"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() smd weighted non-stale values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

* Test 11: regtab documents active collect mutation
local ++test_count
capture noisily {
    findfile regtab.sthlp
    tempname fh
    local _found_mutation 0
    local _found_rebuild 0
    file open `fh' using "`r(fn)'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "intentionally updates collect labels") > 0 local _found_mutation 1
        if strpos(`"`line'"', "save or rebuild that collection") > 0 local _found_rebuild 1
        file read `fh' line
    }
    file close `fh'
    assert `_found_mutation' == 1
    assert `_found_rebuild' == 1
}
if _rc == 0 {
    display as result "  PASS: regtab active collect side effect documented"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab active collect side effect documented (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

* Test 12: effecttab documents active collect mutation and from() isolation
local ++test_count
capture noisily {
    findfile effecttab.sthlp
    tempname fh
    local _found_mutation 0
    local _found_from 0
    file open `fh' using "`r(fn)'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "intentionally updates active collection labels") > 0 local _found_mutation 1
        if strpos(`"`line'"', "matrix path does not inspect") > 0 local _found_from 1
        file read `fh' line
    }
    file close `fh'
    assert `_found_mutation' == 1
    assert `_found_from' == 1
}
if _rc == 0 {
    display as result "  PASS: effecttab active collect side effect documented"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab active collect side effect documented (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

display ""
display as result "=== tabtools issue regression tests: `pass_count' passed, `fail_count' failed out of `test_count' ==="
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
