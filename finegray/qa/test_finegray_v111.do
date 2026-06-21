* test_finegray_v111.do
* Regression tests for finegray 1.1.1:
*   finegray_cif graph polish -
*     - default CIF-plot legend is shown as a single row (CI case)
*     - twoway/legend() options pass through `options' and override defaults
*       (legend(off) suppresses; title()/xtitle() replace the hardcoded defaults)
*     - single-curve (no ci) and nograph paths still build without error
* Graph content is asserted by exporting SVG (a plain-text format that works
* headless) to c(tmpdir) and scanning it for legend/title tokens.
clear all
set varabbrev off
version 16.0

capture log close _t111
log using "test_finegray_v111.log", replace name(_t111)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helpers
program define _mk_hypoxia
    webuse hypoxia, clear
    gen byte status = failtype
end

* Count occurrences of a literal token in a text file. Everything after the
* first (quoted) token on the command line is the search string, so spaces and
* "%" are handled (e.g. _svg_count "file" % CI).
program define _svg_count, rclass
    gettoken fn rest : 0
    local token = strtrim(`"`rest'"')
    tempname fh
    local n = 0
    file open `fh' using `fn', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`token'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

**# ---------------------------------------------------------------
**# 1. Default CI plot: legend shown as a single row, both series labelled
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g1 "`c(tmpdir)'/_fg111_default.svg"
    capture erase "`g1'"
    finegray_cif, ci
    assert _rc == 0
    graph export "`g1'", replace
    * Both legend labels present -> legend is ON by default (not off)
    _svg_count "`g1'" >CIF<
    assert r(n) == 1
    _svg_count "`g1'" % CI<
    assert r(n) == 1
    capture erase "`g1'"
}
if _rc == 0 {
    display as result "  PASS: default CI legend shown with both labels"
    local ++pass_count
}
else {
    display as error "  FAIL: default CI legend shown with both labels (rc=`=_rc')"
    local ++fail_count
}

**# 2. legend(off) passthrough suppresses the legend
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g2 "`c(tmpdir)'/_fg111_legoff.svg"
    capture erase "`g2'"
    finegray_cif, ci legend(off)
    assert _rc == 0
    graph export "`g2'", replace
    * No legend labels -> the passthrough legend(off) reached the plot
    _svg_count "`g2'" >CIF<
    assert r(n) == 0
    _svg_count "`g2'" % CI<
    assert r(n) == 0
    capture erase "`g2'"
}
if _rc == 0 {
    display as result "  PASS: legend(off) passthrough suppresses legend"
    local ++pass_count
}
else {
    display as error "  FAIL: legend(off) passthrough suppresses legend (rc=`=_rc')"
    local ++fail_count
}

**# 3. title()/xtitle() passthrough override the hardcoded defaults
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g3 "`c(tmpdir)'/_fg111_titles.svg"
    capture erase "`g3'"
    finegray_cif, ci title("ZZTITLE") xtitle("ZZXAXIS")
    assert _rc == 0
    graph export "`g3'", replace
    _svg_count "`g3'" ZZTITLE
    assert r(n) >= 1
    _svg_count "`g3'" ZZXAXIS
    assert r(n) >= 1
    * the default xtitle is gone (overridden)
    _svg_count "`g3'" Analysis time
    assert r(n) == 0
    capture erase "`g3'"
}
if _rc == 0 {
    display as result "  PASS: title()/xtitle() passthrough override defaults"
    local ++pass_count
}
else {
    display as error "  FAIL: title()/xtitle() passthrough override defaults (rc=`=_rc')"
    local ++fail_count
}

**# 4. legend(rows(2)) passthrough is accepted (override of default rows(1))
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g4 "`c(tmpdir)'/_fg111_rows2.svg"
    capture erase "`g4'"
    finegray_cif, ci legend(rows(2))
    assert _rc == 0
    graph export "`g4'", replace
    * legend still shown (both labels) under the rows() override
    _svg_count "`g4'" >CIF<
    assert r(n) == 1
    capture erase "`g4'"
}
if _rc == 0 {
    display as result "  PASS: legend(rows(2)) passthrough accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: legend(rows(2)) passthrough accepted (rc=`=_rc')"
    local ++fail_count
}

**# 5. Single-curve (no ci) default builds without error
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    local g5 "`c(tmpdir)'/_fg111_single.svg"
    capture erase "`g5'"
    finegray_cif
    assert _rc == 0
    graph export "`g5'", replace
    * a curve was drawn (default xtitle present), single series -> no legend
    _svg_count "`g5'" Analysis time
    assert r(n) >= 1
    capture erase "`g5'"
}
if _rc == 0 {
    display as result "  PASS: single-curve default builds"
    local ++pass_count
}
else {
    display as error "  FAIL: single-curve default builds (rc=`=_rc')"
    local ++fail_count
}

**# 6. Passthrough does not disturb the returned payload (r(table)) or nograph
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    * graph options present alongside nograph: must be a no-op, payload intact
    finegray_cif, ci nograph legend(off) title("ignored")
    assert _rc == 0
    matrix T = r(table)
    assert colsof(T) == 5
    assert r(cause) == 1
}
if _rc == 0 {
    display as result "  PASS: nograph + passthrough leaves payload intact"
    local ++pass_count
}
else {
    display as error "  FAIL: nograph + passthrough leaves payload intact (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline "RESULT: test_finegray_v111 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _t111
    exit 1
}
display as result "ALL TESTS PASSED"
log close _t111
