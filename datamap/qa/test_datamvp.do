* test_datamvp.do — Comprehensive functional tests for datamvp v1.2.1
* Tests all options, error handling, edge cases, return values, data preservation
* Self-contained: generates own test data

clear all
set more off
version 16.0


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall datamap
net install datamap, from("`pkg_dir'/") replace force

local test_count = 0
local pass_count = 0
local fail_count = 0

* Generate synthetic test data with missingness
quietly {
    clear
    set seed 12345
    set obs 1000
    gen id = _n
    gen age = rnormal(50, 15)
    gen bmi = rnormal(27, 5)
    gen income = rnormal(40000, 15000)
    gen education = floor(runiform()*4) + 1
    gen smoking = runiform() < 0.3
    gen female = runiform() < 0.5
    label define female_lbl 0 "Male" 1 "Female"
    label values female female_lbl
    gen region = floor(runiform()*3) + 1
    label define region_lbl 1 "North" 2 "Central" 3 "South"
    label values region region_lbl
    label var age "Patient age"
    label var bmi "Body mass index"

    * Introduce MCAR missingness
    replace age = . if runiform() < 0.08
    replace bmi = . if runiform() < 0.12
    replace income = . if runiform() < 0.15
    replace education = . if runiform() < 0.10
    replace smoking = . if runiform() < 0.05

    tempfile testdata
    save `testdata', replace
}


* =========================================================================
* BASIC FUNCTIONALITY (Tests 1-2)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking
    assert r(N) == 1000
    assert r(N_vars) > 0
    assert r(N_patterns) > 0
    assert r(N_complete) + r(N_incomplete) == r(N)
}
if _rc == 0 {
    display as result "  PASS `test_count': Basic pattern analysis with explicit varlist"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': Basic pattern analysis (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp
    assert r(N) == 1000
}
if _rc == 0 {
    display as result "  PASS `test_count': All variables (no varlist)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': All variables (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* DISPLAY OPTIONS (Tests 3-8)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, notable
}
if _rc == 0 {
    display as result "  PASS `test_count': notable option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': notable (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, skip
}
if _rc == 0 {
    display as result "  PASS `test_count': skip option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': skip (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, sort
}
if _rc == 0 {
    display as result "  PASS `test_count': sort option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': sort (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi female, nodrop
}
if _rc == 0 {
    display as result "  PASS `test_count': nodrop option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': nodrop (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, wide
}
if _rc == 0 {
    display as result "  PASS `test_count': wide option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': wide (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, nosummary
}
if _rc == 0 {
    display as result "  PASS `test_count': nosummary option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': nosummary (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* PATTERN FILTERING (Tests 9-12)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, minfreq(5)
}
if _rc == 0 {
    display as result "  PASS `test_count': minfreq() option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': minfreq (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, minmissing(2)
}
if _rc == 0 {
    display as result "  PASS `test_count': minmissing() option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': minmissing (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, maxmissing(3)
}
if _rc == 0 {
    display as result "  PASS `test_count': maxmissing() option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': maxmissing (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education, ascending
}
if _rc == 0 {
    display as result "  PASS `test_count': ascending option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': ascending (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* STATISTICS (Tests 13-16)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, percent
}
if _rc == 0 {
    display as result "  PASS `test_count': percent option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': percent (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, percent cumulative
}
if _rc == 0 {
    display as result "  PASS `test_count': cumulative option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': cumulative (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, correlate
    matrix list r(corr_miss)
}
if _rc == 0 {
    display as result "  PASS `test_count': correlate option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': correlate (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education, monotone
    assert "`r(monotone_status)'" != ""
    assert !missing(r(N_monotone))
    assert !missing(r(pct_monotone))
}
if _rc == 0 {
    display as result "  PASS `test_count': monotone option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': monotone (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* OUTPUT (Tests 17-19)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, generate(m)
    confirm variable m_age m_bmi m_income
    confirm variable m_pattern m_nmiss
    * Verify indicator correctness
    assert m_age == missing(age)
    assert m_bmi == missing(bmi)
}
if _rc == 0 {
    display as result "  PASS `test_count': generate() option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': generate (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    capture frame drop mvp_pats
    datamvp age bmi income, save(mvp_pats)
    frame mvp_pats: describe, short
    frame drop mvp_pats
}
if _rc == 0 {
    display as result "  PASS `test_count': save() to frame"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': save frame (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    tempfile savefile
    datamvp age bmi income, save("`savefile'.dta")
    confirm file "`savefile'.dta"
}
if _rc == 0 {
    display as result "  PASS `test_count': save() to file"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': save file (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* GRAPH TYPES (Tests 20-27)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, graph(bar) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': graph(bar)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': graph(bar) (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(bar) sort vertical barcolor(maroon) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': graph(bar) vertical+sort+barcolor"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': graph(bar) vertical (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, graph(patterns) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': graph(patterns)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': graph(patterns) (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(patterns) top(5) title("Top 5") nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': graph(patterns) top() title()"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': graph(patterns) top (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(matrix) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': graph(matrix)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': graph(matrix) (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(matrix, sample(100) sort) misscolor(red) obscolor(green*0.2) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': graph(matrix) suboptions+colors"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': graph(matrix) subopts (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, graph(correlation) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': graph(correlation)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': graph(correlation) (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(correlation) textlabels colorramp(grayscale) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': graph(correlation) textlabels+colorramp"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': graph(correlation) opts (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* GRAPH OPTIONS (Tests 28-30)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(bar) gname(mvp_test) nodraw
    graph describe mvp_test
    graph drop mvp_test
}
if _rc == 0 {
    display as result "  PASS `test_count': gname() option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': gname (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    tempfile gph
    datamvp age bmi income, graph(bar) gsaving("`gph'.gph", replace) nodraw
    confirm file "`gph'.gph"
}
if _rc == 0 {
    display as result "  PASS `test_count': gsaving() option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': gsaving (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(bar) scheme(s1mono) title("Test") subtitle("Sub") nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': scheme() title() subtitle()"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': scheme/title (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* STRATIFICATION (Tests 31-35)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(bar) gby(female) nodraw
    assert "`r(gby)'" == "female"
}
if _rc == 0 {
    display as result "  PASS `test_count': gby() with graph(bar)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': gby bar (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(bar) over(female) nodraw
    assert "`r(over)'" == "female"
}
if _rc == 0 {
    display as result "  PASS `test_count': over() with graph(bar)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': over bar (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(bar) stacked nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': stacked option"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': stacked (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(bar) over(female) groupgap(20) legendopts(rows(1) position(6)) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': over() + groupgap() + legendopts()"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': over+groupgap (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education, graph(patterns) gby(female) top(5) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': gby() with graph(patterns)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': gby patterns (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* DATA SELECTION (Tests 36-38)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income if female == 1
    assert r(N) < 1000
}
if _rc == 0 {
    display as result "  PASS `test_count': if condition"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': if condition (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income in 1/200
    assert r(N) == 200
}
if _rc == 0 {
    display as result "  PASS `test_count': in range"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': in range (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    bysort female: datamvp age bmi income
}
if _rc == 0 {
    display as result "  PASS `test_count': by prefix"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': by prefix (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* EDGE CASES (Tests 39-41)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp female region
    assert r(N_vars) == 0
    assert r(N_complete) == r(N)
}
if _rc == 0 {
    display as result "  PASS `test_count': No missing values"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': no missing (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    gen all_miss = .
    datamvp age all_miss bmi
    assert r(N_vars) >= 2
    drop all_miss
}
if _rc == 0 {
    display as result "  PASS `test_count': All-missing variable"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': all-missing var (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking, ///
        sort skip wide percent cumulative minfreq(3) minmissing(1) maxmissing(4)
}
if _rc == 0 {
    display as result "  PASS `test_count': All display+filter options combined"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': combined options (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* DATA PRESERVATION (Test 42)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    local orig_N = _N
    sort id
    local orig_sort : sortedby
    datamvp age bmi income education smoking, correlate monotone graph(bar) nodraw
    assert _N == `orig_N'
    assert "`orig_sort'" == "`: sortedby'"
    confirm variable id age bmi income education smoking female region
}
if _rc == 0 {
    display as result "  PASS `test_count': Data preservation (N, sort, variables)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': data preservation (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* VARABBREV RESTORE (Test 43)
* =========================================================================

local ++test_count
capture noisily {
    set varabbrev on
    use `testdata', clear
    datamvp age bmi income
    assert "`c(varabbrev)'" == "on"
    * Also test on error path
    capture datamvp, graph(bar) scheme(s1mono)
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS `test_count': Varabbrev restored on success and error"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': varabbrev restore (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* ERROR HANDLING (Tests 44-50)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi, graph(bar) scheme(s1mono) over(female)
    assert _rc == 0
    capture datamvp age bmi, scheme(s1mono)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': scheme() without graph() errors"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': scheme error (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi, horizontal vertical
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': horizontal+vertical conflict errors"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': horiz+vert error (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi, graph(bar) gby(female) over(female)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': gby+over conflict errors"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': gby+over error (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi, minmissing(3) maxmissing(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': minmissing > maxmissing errors"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': minmiss>maxmiss error (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi, graph(invalid)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': Invalid graph type errors"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': invalid graph error (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi, graph(correlation) over(female)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': over() with graph(correlation) errors"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': over+correlation error (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi, graph(matrix) gby(female)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': gby() with graph(matrix) errors"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': gby+matrix error (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* v1.2.0 FIX TESTS (Tests 51-58)
* =========================================================================

* Test 51: generate() stub length validation
local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi, generate(this_stub_is_way_too_long_for_stata)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': generate() long stub rejected"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': generate stub length (rc=`=_rc')"
    local ++fail_count
}

* Test 52: correlate with single missing-value variable warns (no error)
local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age, correlate
    * Should not error — just skip with message
}
if _rc == 0 {
    display as result "  PASS `test_count': correlate with single var (no error)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': correlate single var (rc=`=_rc')"
    local ++fail_count
}

* Test 53: No missing values returns r(varlist_nomiss)
local ++test_count
capture noisily {
    use `testdata', clear
    datamvp female region
    assert "`r(varlist_nomiss)'" != ""
}
if _rc == 0 {
    display as result "  PASS `test_count': r(varlist_nomiss) returned when no missing"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': varlist_nomiss (rc=`=_rc')"
    local ++fail_count
}

* Test 54: stacked bar actually works (v1.2.0 reimplementation)
local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education, graph(bar) stacked nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': stacked bar (v1.2.0 reimplementation)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': stacked bar (rc=`=_rc')"
    local ++fail_count
}

* Test 55: over() restricted to graph(bar)
local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi income, graph(patterns) over(female)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': over() rejected with graph(patterns)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': over+patterns error (rc=`=_rc')"
    local ++fail_count
}

* Test 56: gby() restricted to graph(bar) or graph(patterns)
local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi income, graph(correlation) gby(female)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': gby() rejected with graph(correlation)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': gby+correlation error (rc=`=_rc')"
    local ++fail_count
}

* Test 57: stacked rejected with non-bar graph
local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi income, graph(patterns) stacked
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': stacked rejected with graph(patterns)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': stacked+patterns error (rc=`=_rc')"
    local ++fail_count
}

* Test 58: graphoptions() passthrough
local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(bar) graphoptions(ysize(5) xsize(8)) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': graphoptions() passthrough"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': graphoptions (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* STORED RESULTS VERIFICATION (Test 59)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking
    assert !missing(r(N))
    assert !missing(r(N_complete))
    assert !missing(r(N_incomplete))
    assert !missing(r(N_patterns))
    assert !missing(r(N_vars))
    assert !missing(r(max_miss))
    assert !missing(r(mean_miss))
    assert !missing(r(N_mv_total))
    assert r(N_complete) + r(N_incomplete) == r(N)
    assert r(N_vars) > 0
    assert r(mean_miss) >= 0
    assert "`r(varlist)'" != ""
}
if _rc == 0 {
    display as result "  PASS `test_count': All stored results valid"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': stored results (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* v1.2.1 FIX TESTS (Tests 60-72)
* =========================================================================

* Test 60: varabbrev OFF stays OFF after datamvp (was leaked as ON)
local ++test_count
capture noisily {
    set varabbrev off
    use `testdata', clear
    datamvp age bmi income
    assert "`c(varabbrev)'" == "off"
    * Also test error path
    capture datamvp, graph(bar) scheme(s1mono)
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS `test_count': Varabbrev OFF preserved on success+error (v1.2.1)"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "  FAIL `test_count': varabbrev OFF leak (rc=`=_rc')"
    local ++fail_count
}

* Test 61: string gby() with graph(bar) does not crash
local ++test_count
capture noisily {
    use `testdata', clear
    gen str6 sex = cond(female == 1, "Female", "Male")
    datamvp age bmi income, graph(bar) gby(sex) nodraw
    assert "`r(gby)'" == "sex"
}
if _rc == 0 {
    display as result "  PASS `test_count': String gby() with graph(bar) (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': string gby bar (rc=`=_rc')"
    local ++fail_count
}

* Test 62: string over() with graph(bar) does not crash
local ++test_count
capture noisily {
    use `testdata', clear
    gen str6 sex = cond(female == 1, "Female", "Male")
    datamvp age bmi income, graph(bar) over(sex) nodraw
    assert "`r(over)'" == "sex"
}
if _rc == 0 {
    display as result "  PASS `test_count': String over() with graph(bar) (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': string over bar (rc=`=_rc')"
    local ++fail_count
}

* Test 63: string gby() with graph(patterns)
local ++test_count
capture noisily {
    use `testdata', clear
    gen str6 sex = cond(female == 1, "Female", "Male")
    datamvp age bmi income, graph(patterns) gby(sex) top(5) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': String gby() with graph(patterns) (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': string gby patterns (rc=`=_rc')"
    local ++fail_count
}

* Test 64: gen:erate abbreviation works (was documented as g: which doesn't)
local ++test_count
capture noisily {
    use `testdata', clear
    capture drop gen_*
    datamvp age bmi, gen(gen)
    confirm variable gen_age gen_bmi gen_pattern gen_nmiss
    drop gen_*
}
if _rc == 0 {
    display as result "  PASS `test_count': gen() abbreviation works (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': gen abbreviation (rc=`=_rc')"
    local ++fail_count
}

* Test 65: graph(correlation) with all-missing variable (missing corr handled)
local ++test_count
capture noisily {
    use `testdata', clear
    gen all_miss = .
    datamvp age bmi all_miss, graph(correlation) nodraw
    drop all_miss
}
if _rc == 0 {
    display as result "  PASS `test_count': Correlation graph with all-missing var (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': corr all-missing (rc=`=_rc')"
    local ++fail_count
}

* Test 66: zero observations after if/in restriction
local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi if id > 9999
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS `test_count': Zero observations errors correctly"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': zero obs (rc=`=_rc')"
    local ++fail_count
}

* Test 67: single observation
local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income in 1
    assert r(N) == 1
    assert r(N_patterns) == 1
}
if _rc == 0 {
    display as result "  PASS `test_count': Single observation"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': single obs (rc=`=_rc')"
    local ++fail_count
}

* Test 68: all data missing
local ++test_count
capture noisily {
    clear
    set obs 50
    gen a = .
    gen b = .
    gen c = .
    datamvp a b c
    assert r(N) == 50
    assert r(N_complete) == 0
    assert r(N_incomplete) == 50
    assert r(N_vars) == 3
    assert r(N_patterns) == 1
    assert r(max_miss) == 3
    assert abs(r(mean_miss) - 3) < 0.001
}
if _rc == 0 {
    display as result "  PASS `test_count': All data missing"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': all missing (rc=`=_rc')"
    local ++fail_count
}

* Test 69: graph(bar) with string over() + groupgap + legendopts
local ++test_count
capture noisily {
    use `testdata', clear
    gen str6 sex = cond(female == 1, "Female", "Male")
    datamvp age bmi income, graph(bar) over(sex) groupgap(20) legendopts(rows(1)) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': String over()+groupgap+legendopts (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': string over+opts (rc=`=_rc')"
    local ++fail_count
}

* Test 70: string gby() with value labels absent (uses varname=value)
local ++test_count
capture noisily {
    use `testdata', clear
    gen str3 grp = cond(_n <= 500, "A", "B")
    datamvp age bmi income, graph(bar) gby(grp) nodraw
    assert "`r(gby)'" == "grp"
}
if _rc == 0 {
    display as result "  PASS `test_count': String gby() no value labels (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': string gby no labels (rc=`=_rc')"
    local ++fail_count
}

* Test 71: colorramp(redblue) with graph(correlation)
local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income, graph(correlation) colorramp(redblue) nodraw
}
if _rc == 0 {
    display as result "  PASS `test_count': colorramp(redblue) (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': redblue colorramp (rc=`=_rc')"
    local ++fail_count
}

* Test 72: monotone + correlate + graph(bar) + generate combined
local ++test_count
capture noisily {
    use `testdata', clear
    capture drop combo_*
    datamvp age bmi income, monotone correlate graph(bar) generate(combo) nodraw
    assert "`r(monotone_status)'" != ""
    matrix list r(corr_miss)
    confirm variable combo_age combo_bmi combo_income combo_pattern combo_nmiss
    drop combo_*
}
if _rc == 0 {
    display as result "  PASS `test_count': Combined monotone+correlate+graph+generate (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': combined v1.2.1 (rc=`=_rc')"
    local ++fail_count
}

* Test 73: file paths reject shell metacharacters before any write command runs
local ++test_count
capture noisily {
    use `testdata', clear
    capture datamvp age bmi income, save("bad;path.dta")
    assert _rc == 198
    capture datamvp age bmi income, graph(bar) gsaving("bad;path.gph", replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS `test_count': save()/gsaving() reject shell metacharacters"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': shell-metacharacter path guard (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* SUMMARY
* =========================================================================

display _n "{hline 60}"
display "MVP TEST SUMMARY"
display "{hline 60}"
display "Total:  `test_count'"
display as result "Passed: `pass_count'"
if `fail_count' > 0 {
    display as error "Failed: `fail_count'"
}
else {
    display "Failed: `fail_count'"
}
display "{hline 60}"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datamvp tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    display "RESULT: test_datamvp tests=`test_count' pass=`pass_count' fail=`fail_count'"
}
