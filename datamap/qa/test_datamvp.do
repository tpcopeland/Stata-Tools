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

* Independent oracle for r(N_patterns): datamvp.ado (see grpseq/isf/ng around
* "Identify unique patterns") flags exactly one row per distinct missingness
* pattern, then zeroes that flag for any pattern whose group frequency is
* below minfreq(), or whose per-row missing-count falls outside
* [minmissing(), maxmissing()]; N_patterns is the count of rows still
* flagged. This rebuilds that same computation independently so
* minfreq()/minmissing()/maxmissing() can be checked against their
* documented effect on the return, not just "ran without error".
capture program drop _qa_dmvp_pattern_count
program define _qa_dmvp_pattern_count, rclass
    version 16.0
    syntax varlist, [MINFreq(integer 1) MINMissing(integer -1) MAXMissing(integer -1)]
    tempvar pat nmiss freq first
    quietly {
        gen strL `pat' = ""
        gen int `nmiss' = 0
        foreach v of local varlist {
            replace `pat' = `pat' + cond(missing(`v'), ".", "+")
            replace `nmiss' = `nmiss' + cond(missing(`v'), 1, 0)
        }
        bysort `pat': gen long `freq' = _N
        bysort `pat': gen byte `first' = (_n == 1)
        replace `first' = 0 if `freq' < `minfreq'
        if `minmissing' >= 0 replace `first' = 0 if `nmiss' < `minmissing'
        if `maxmissing' >= 0 replace `first' = 0 if `nmiss' > `maxmissing'
        count if `first'
    }
    return scalar n_patterns = r(N)
end


* =========================================================================
* BASIC FUNCTIONALITY (Tests 1-2)
* =========================================================================

local ++test_count
capture noisily {
    use `testdata', clear
    datamvp age bmi income education smoking
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 5
    assert !missing(r(N_patterns))
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
    * No varlist: datamvp defaults to analysing every variable in the dataset,
    * so this is NOT the nvar==0 early-return branch -- measured r(N_vars) is
    * 5, the full varlist of `testdata', not 0.
    assert r(N) == 1000
    assert r(N_vars) == 5
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * notable only suppresses the console table -- no r() effect to assert
    * beyond the varlist actually parsing and the identity holding.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * skip only inserts a display blank every 5 vars in the console table --
    * no r() effect to assert beyond the varlist parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 5
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * sort only reorders the console pattern table by missingness -- the
    * underlying pattern set is unchanged, so no r() effect beyond parsing.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 5
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * nodrop's observable effect: `female' carries no missingness at all, so
    * without nodrop it would be filtered out of the tracked varlist
    * (datamvp.ado's default-drop rule keeps only vars with >0 missing) and
    * N_vars would be 2. nodrop forces all 3 requested vars to be kept.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * wide only compacts the console display -- no r() effect beyond
    * parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 5
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * nosummary only suppresses the console summary block -- the summary
    * scalars are still returned, so check the varlist parsed and the
    * identity holds.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    local _dmvp_np = r(N_patterns)
    * Read EVERY r() result of the command under test before the oracle helper
    * below runs: `_qa_dmvp_pattern_count' issues its own commands and so
    * replaces r() wholesale -- asserting on r(N)/r(N_vars) after the call
    * reads the HELPER's results, not datamvp's.
    local _dmvp_n  = r(N)
    local _dmvp_nv = r(N_vars)
    local _dmvp_nc = r(N_complete)
    local _dmvp_ni = r(N_incomplete)
    assert !missing(`_dmvp_np')
    assert !missing(`_dmvp_n', `_dmvp_nv', `_dmvp_nc', `_dmvp_ni')
    assert `_dmvp_n' == 1000
    assert `_dmvp_nv' == 5
    assert `_dmvp_nc' + `_dmvp_ni' == `_dmvp_n'
    * minfreq()'s observable effect on the RETURN (not just the console
    * table): r(N_patterns) only counts patterns whose group frequency
    * meets the threshold. Rebuild that count independently.
    _qa_dmvp_pattern_count age bmi income education smoking, minfreq(5)
    assert `_dmvp_np' == r(n_patterns)
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
    local _dmvp_np = r(N_patterns)
    * Read EVERY r() result of the command under test before the oracle helper
    * below runs: `_qa_dmvp_pattern_count' issues its own commands and so
    * replaces r() wholesale -- asserting on r(N)/r(N_vars) after the call
    * reads the HELPER's results, not datamvp's.
    local _dmvp_n  = r(N)
    local _dmvp_nv = r(N_vars)
    local _dmvp_nc = r(N_complete)
    local _dmvp_ni = r(N_incomplete)
    assert !missing(`_dmvp_np')
    assert !missing(`_dmvp_n', `_dmvp_nv', `_dmvp_nc', `_dmvp_ni')
    assert `_dmvp_n' == 1000
    assert `_dmvp_nv' == 5
    assert `_dmvp_nc' + `_dmvp_ni' == `_dmvp_n'
    * minmissing()'s observable effect on the RETURN: r(N_patterns) only
    * counts patterns whose per-row missing count meets the threshold.
    _qa_dmvp_pattern_count age bmi income education smoking, minmissing(2)
    assert `_dmvp_np' == r(n_patterns)
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
    local _dmvp_np = r(N_patterns)
    * Read EVERY r() result of the command under test before the oracle helper
    * below runs: `_qa_dmvp_pattern_count' issues its own commands and so
    * replaces r() wholesale -- asserting on r(N)/r(N_vars) after the call
    * reads the HELPER's results, not datamvp's.
    local _dmvp_n  = r(N)
    local _dmvp_nv = r(N_vars)
    local _dmvp_nc = r(N_complete)
    local _dmvp_ni = r(N_incomplete)
    assert !missing(`_dmvp_np')
    assert !missing(`_dmvp_n', `_dmvp_nv', `_dmvp_nc', `_dmvp_ni')
    assert `_dmvp_n' == 1000
    assert `_dmvp_nv' == 5
    assert `_dmvp_nc' + `_dmvp_ni' == `_dmvp_n'
    * maxmissing()'s observable effect on the RETURN: r(N_patterns) only
    * counts patterns whose per-row missing count meets the threshold.
    _qa_dmvp_pattern_count age bmi income education smoking, maxmissing(3)
    assert `_dmvp_np' == r(n_patterns)
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
    * ascending only reverses the console pattern sort order -- the pattern
    * set and counts are unchanged, so no r() effect beyond parsing.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 4
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * percent only adds a console percentage column -- no r() effect beyond
    * parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * percent/cumulative only add console columns -- no r() effect beyond
    * parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    matrix _corr_miss = r(corr_miss)
    assert rowsof(_corr_miss) == 5
    assert colsof(_corr_miss) == 5
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
    frame mvp_pats {
        assert _N > 0
    }
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
    preserve
    use "`savefile'.dta", clear
    assert _N > 0
    restore
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
    * graph(bar)/nodraw only select and suppress rendering -- no r() effect
    * beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 5
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * sort/vertical/barcolor()/nodraw only affect the (suppressed)
    * rendering -- no r() effect beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * graph(patterns)/nodraw only select and suppress rendering -- no r()
    * effect beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 5
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * top()/title()/nodraw only affect the (suppressed) rendering -- no
    * r() effect beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * graph(matrix)/nodraw only select and suppress rendering -- no r()
    * effect beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * sample()/sort/misscolor()/obscolor()/nodraw only affect the
    * (suppressed) rendering -- no r() effect beyond parsing and the
    * identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * graph(correlation)/nodraw only select and suppress rendering -- the
    * matrix itself is checked separately (Test: correlate option); here
    * just confirm the varlist parsed and the identity holds.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 5
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * textlabels/colorramp()/nodraw only affect the (suppressed) rendering
    * -- no r() effect beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    * `graph describe' errors if gname() did not actually create the named
    * graph in memory -- the real oracle for this option.
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
    * `confirm file' alone passes on a truncated/empty .gph -- check it has
    * real bytes (binary format, so no fileread() text-content check here).
    tempname _gph_fh
    file open `_gph_fh' using "`gph'.gph", read binary
    file seek `_gph_fh' eof
    file seek `_gph_fh' query
    local _gph_bytes = r(loc)
    file close `_gph_fh'
    assert !missing(`_gph_bytes')
    assert `_gph_bytes' > 0
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
    * scheme()/title()/subtitle() only affect graph rendering (suppressed
    * here via nodraw) -- no r() effect beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * stacked only affects the (suppressed) bar-chart rendering -- no r()
    * effect beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * over()'s observable effect: r(over)/r(over_levels). groupgap()/
    * legendopts() only affect the (suppressed) rendering.
    assert "`r(over)'" == "female"
    * r(over_levels) is a `levelsof' LIST (a return local), not a count --
    * `missing()' on it is a type mismatch, r(109). Assert the number of
    * levels it names, which is the quantity the option actually governs.
    assert wordcount(`"`r(over_levels)'"') == 2
    assert !missing(r(N))
    assert r(N) == 1000
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
    * gby()'s observable effect: r(gby)/r(gby_levels). top() only truncates
    * the (suppressed) pattern chart's rendering.
    assert "`r(gby)'" == "female"
    * r(gby_levels) is a `levelsof' LIST (a return local), not a count --
    * `missing()' on it is a type mismatch, r(109). Assert the number of
    * levels it names, which is the quantity the option actually governs.
    assert wordcount(`"`r(gby_levels)'"') == 2
    assert !missing(r(N))
    assert r(N) == 1000
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
    * r() reflects only the last by-group processed, not the full 1000 obs.
    assert !missing(r(N))
    assert r(N) > 0
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
    assert !missing(r(N_vars))
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
    local _dmvp_np = r(N_patterns)
    * Read EVERY r() result of the command under test before the oracle helper
    * below runs: `_qa_dmvp_pattern_count' issues its own commands and so
    * replaces r() wholesale -- asserting on r(N)/r(N_vars) after the call
    * reads the HELPER's results, not datamvp's.
    local _dmvp_n  = r(N)
    local _dmvp_nv = r(N_vars)
    local _dmvp_nc = r(N_complete)
    local _dmvp_ni = r(N_incomplete)
    assert !missing(`_dmvp_np')
    assert !missing(`_dmvp_n', `_dmvp_nv', `_dmvp_nc', `_dmvp_ni')
    assert `_dmvp_n' == 1000
    assert `_dmvp_nv' == 5
    assert `_dmvp_nc' + `_dmvp_ni' == `_dmvp_n'
    * sort/skip/wide/percent/cumulative are console-only; minfreq()/
    * minmissing()/maxmissing() DO have an observable effect on
    * r(N_patterns) -- rebuild that count independently.
    _qa_dmvp_pattern_count age bmi income education smoking, ///
        minfreq(3) minmissing(1) maxmissing(4)
    assert `_dmvp_np' == r(n_patterns)
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
    * correlate with nvar<=1 hits datamvp.ado's documented skip branch
    * ("correlate requires at least 2 variables...; skipped"), which never
    * sets `_return_has_corr' -- confirm r(corr_miss) is genuinely absent,
    * not just that the command didn't error.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 1
    capture matrix list r(corr_miss)
    assert _rc != 0
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
    * stacked/nodraw only affect the (suppressed) rendering -- no r()
    * effect beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 4
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * graphoptions()/nodraw only affect the (suppressed) rendering -- no
    * r() effect beyond parsing and the identity.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    assert !missing(r(N_vars))
    assert r(N_vars) > 0
    assert !missing(r(mean_miss))
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
    * String gby()'s observable effect: r(gby)/r(gby_levels), same as the
    * numeric gby() test above. top()/nodraw only affect rendering.
    assert "`r(gby)'" == "sex"
    * r(gby_levels) is a `levelsof' LIST (a return local), not a count --
    * `missing()' on it is a type mismatch, r(109). Assert the number of
    * levels it names, which is the quantity the option actually governs.
    assert wordcount(`"`r(gby_levels)'"') == 2
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * `confirm variable' alone passes on all-missing generated columns;
    * require the missingness-count column to actually hold valid counts.
    quietly count if missing(gen_nmiss)
    assert r(N) == 0
    quietly summarize gen_nmiss
    assert !missing(r(max))
    assert r(max) <= 2
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
    * graph(correlation) internally runs correlate over the 3 vars (all
    * have missingness, nvar>1) -- confirm the matrix actually posted at
    * the right dimension despite the degenerate all-missing column.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    matrix _t65_corr = r(corr_miss)
    assert rowsof(_t65_corr) == 3
    assert colsof(_t65_corr) == 3
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
    * String over()'s observable effect: r(over)/r(over_levels). groupgap()/
    * legendopts()/nodraw only affect rendering.
    assert "`r(over)'" == "sex"
    * r(over_levels) is a `levelsof' LIST (a return local), not a count --
    * `missing()' on it is a type mismatch, r(109). Assert the number of
    * levels it names, which is the quantity the option actually governs.
    assert wordcount(`"`r(over_levels)'"') == 2
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
    * colorramp()/nodraw only affect the (suppressed) rendering; the
    * correlation matrix itself is checked in the dedicated graph(correlation)
    * and correlate tests above.
    assert !missing(r(N))
    assert r(N) == 1000
    assert !missing(r(N_vars))
    assert r(N_vars) == 3
    assert r(N_complete) + r(N_incomplete) == r(N)
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
