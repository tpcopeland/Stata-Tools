* test_qba_v120.do -- Plot legibility fixes asserted on exported SVG geometry
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_v120.do

clear all

* === Bootstrap ===
capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}
_qba_qa_bootstrap
local qa_dir `"`r(qa_dir)'"'
local pkg_dir `"`r(pkg_dir)'"'

local test_count = 0
local pass_count = 0
local fail_count = 0

* count occurrences of a literal string in a file (one count per matching line piece)
capture program drop _v120_count
program define _v120_count, rclass
    args file needle
    tempname fh
    file open `fh' using `"`file'"', read text
    local n = 0
    file read `fh' line
    while r(eof) == 0 {
        local rest `"`macval(line)'"'
        while strpos(`"`rest'"', `"`needle'"') {
            local ++n
            local rest = substr(`"`rest'"', strpos(`"`rest'"', `"`needle'"') + 1, .)
        }
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

local dir "`c(tmpdir)'"
local mc "`dir'/qba_v120_mc.dta"

**# V120.1 distribution: median line is the green the legend names; null line is solid and visible
local ++test_count
capture noisily {
    quietly qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
        reps(300) dist_se("trapezoidal .75 .82 .88 .95") ///
        dist_sp("trapezoidal .90 .93 .97 1.0") seed(1) saving("`mc'", replace)
    local svg "`dir'/qba_v120_dist.svg"
    capture erase "`svg'"
    qba_plot, distribution using("`mc'") observed(2.15) saving("`svg'") replace
    * median: a dashed "0 150 60" (#00963C) line, clearly green
    _v120_count "`svg'" "stroke:#00963C;stroke-width:12.96"
    assert r(n) > 0
    * null: ONE solid gray (#606060) medthick path, not a dotted series
    _v120_count "`svg'" "stroke:#606060;stroke-width:12.96"
    assert r(n) == 1
    * legend text names the actual styles
    _v120_count "`svg'" "Gray solid=null"
    assert r(n) == 1
    capture erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: V120.1 distribution median green and null solid"
    local ++pass_count
}
else {
    display as error "  FAIL: V120.1 distribution reference lines (error `=_rc')"
    local ++fail_count
}

**# V120.2 tornado: reference lines are labelled
local ++test_count
capture noisily {
    local svg "`dir'/qba_v120_tornado.svg"
    capture erase "`svg'"
    qba_plot, tornado a(136) b(297) c(1432) d(6738) param1(se) range1(.7 .98) ///
        param2(sp) range2(.9 1) steps(10) saving("`svg'") replace
    _v120_count "`svg'" ">Observed OR (2.15)<"
    assert r(n) == 1
    _v120_count "`svg'" ">Null (1.00)<"
    assert r(n) == 1
    * the null line itself is one solid gray (#606060) path, not a dotted
    * series that blends into the grid
    _v120_count "`svg'" "stroke:#606060;stroke-width:8.64"
    assert r(n) == 1
    capture erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: V120.2 tornado reference lines are labelled"
    local ++pass_count
}
else {
    display as error "  FAIL: V120.2 tornado labels (error `=_rc')"
    local ++fail_count
}

**# V120.3 tipping: tiles carry no outline (no dark stripes)
local ++test_count
capture noisily {
    local svg "`dir'/qba_v120_tipping.svg"
    capture erase "`svg'"
    qba_plot, tipping a(136) b(297) c(1432) d(6738) param1(p1) range1(0 .6) ///
        param2(rrcd) range2(1 5) base_p0(.1) steps(8) saving("`svg'") replace
    _v120_count "`svg'" "stroke-width:0.00"
    assert r(n) >= 40
    capture erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: V120.3 tipping tiles are drawn without outlines"
    local ++pass_count
}
else {
    display as error "  FAIL: V120.3 tipping outlines (error `=_rc')"
    local ++fail_count
}

capture erase "`mc'"
display as result "v1.2.0 Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    display "RESULT: test_qba_v120 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

capture ado uninstall qba
display "RESULT: test_qba_v120 tests=`test_count' pass=`pass_count' fail=`fail_count'"
