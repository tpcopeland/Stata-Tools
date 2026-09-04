/*******************************************************************************
* test_selection_labels.do
*
* Purpose: Route-aware semantic regressions for coefficient selection, label
*          composition, interval suppression, palette cycling, mode-scoped
*          presentation options, and numeric option domains.
*
*          Every case here asserts an exact identity, value, layer, or error
*          code. The defects these cover all returned rc=0 with a plausible
*          graph and self-consistent returns, so shape-only assertions
*          (r(N)>0, "r(cmd) is nonempty", "the graph exists") cannot see them.
*
* Prerequisites:
*   - eplot.ado must be installed/accessible
*
* Run modes:
*   Standalone: do test_selection_labels.do
*   Via runner: do run_all.do [core|full]
*
* Author: Timothy Copeland
* Date: 2026-09-02
*******************************************************************************/

clear all
set more off
set varabbrev off
version 16.0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

* Sandbox PLUS/PERSONAL and install the package under test.  Every suite
* does this before touching adopath or installing, so a standalone run
* cannot write into the real ado tree either.
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap "`pkg_dir'"

adopath ++ "`pkg_dir'"
discard

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Fixture builder: three effect rows whose labels are the selection keys.
capture program drop _sel_fixture
program define _sel_fixture
    clear
    quietly set obs 3
    quietly gen str20 lab = ""
    quietly replace lab = "A"     in 1
    quietly replace lab = "B"     in 2
    quietly replace lab = "_cons" in 3
    quietly gen double es = _n
    quietly gen double lo = es - 1
    quietly gen double hi = es + 1
end

* Fixture builder: mixed regular / subgroup / overall rows.
capture program drop _pooled_fixture
program define _pooled_fixture
    clear
    quietly set obs 4
    quietly gen str20 lab = ""
    quietly replace lab = "S1"      in 1
    quietly replace lab = "S2"      in 2
    quietly replace lab = "Sub"     in 3
    quietly replace lab = "Overall" in 4
    quietly gen double es = _n / 10
    quietly gen double lo = es - .05
    quietly gen double hi = es + .05
    quietly gen byte ty = 1
    quietly replace ty = 3 in 3
    quietly replace ty = 5 in 4
end

display _n "{bf:SELECTION AND LABEL COMPOSITION}"

**# 1. Data mode keep() retains exactly the named rows
local ++test_count
capture noisily {
    _sel_fixture
    eplot es lo hi, labels(lab) keep(B) name(_sel_t1, replace)
    assert r(N) == 1
    assert r(k) == 1
    matrix T = r(table)
    assert rowsof(T) == 1
    local rn : rownames T
    assert "`rn'" == "B"
    assert abs(T[1, 1] - 2) < 1e-12
    assert abs(T[1, 2] - 1) < 1e-12
    assert abs(T[1, 3] - 3) < 1e-12

    * Positive control: without keep(), all three rows are present, so the
    * assertions above are not satisfied by an empty or degenerate table.
    _sel_fixture
    eplot es lo hi, labels(lab) name(_sel_t1b, replace)
    assert r(k) == 3
    matrix T0 = r(table)
    assert rowsof(T0) == 3
    local rn0 : rownames T0
    assert "`rn0'" == "A B _cons"
}
if _rc == 0 {
    display as result "  PASS: 1 data keep() exact rows"
    local ++pass_count
}
else {
    display as error "  FAIL: 1 data keep() exact rows (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}
capture graph drop _sel_t1
capture graph drop _sel_t1b

**# 2. Data mode drop() and noconstant remove exactly the named rows
local ++test_count
capture noisily {
    _sel_fixture
    eplot es lo hi, labels(lab) drop(B) name(_sel_t2a, replace)
    assert r(k) == 2
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "A _cons"

    _sel_fixture
    eplot es lo hi, labels(lab) noconstant name(_sel_t2b, replace)
    assert r(k) == 2
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "A B"

    * noconstant is shorthand for drop(_cons) and must compose with drop().
    _sel_fixture
    eplot es lo hi, labels(lab) noconstant drop(A) name(_sel_t2c, replace)
    assert r(k) == 1
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "B"
}
if _rc == 0 {
    display as result "  PASS: 2 data drop()/noconstant exact rows"
    local ++pass_count
}
else {
    display as error "  FAIL: 2 data drop()/noconstant exact rows (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture graph drop _sel_t2a
capture graph drop _sel_t2b
capture graph drop _sel_t2c

**# 3. Data mode selection wildcards and exhaustion errors
local ++test_count
capture noisily {
    _sel_fixture
    eplot es lo hi, labels(lab) keep(_c*) name(_sel_t3a, replace)
    assert r(k) == 1
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "_cons"

    _sel_fixture
    eplot es lo hi, labels(lab) drop(?) name(_sel_t3b, replace)
    assert r(k) == 1
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "_cons"

    * An unmatched keep() must fail loudly rather than draw an empty graph.
    _sel_fixture
    capture noisily eplot es lo hi, labels(lab) keep(ZZZ) name(_sel_t3c, replace)
    assert _rc == 2000

    _sel_fixture
    capture noisily eplot es lo hi, labels(lab) drop(A B _cons) name(_sel_t3d, replace)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: 3 data selection wildcards and exhaustion"
    local ++pass_count
}
else {
    display as error "  FAIL: 3 data selection wildcards and exhaustion (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture graph drop _sel_t3a
capture graph drop _sel_t3b

**# 4. Data mode selection reaches structural rows and pooled row types
local ++test_count
capture noisily {
    _pooled_fixture
    eplot es lo hi, labels(lab) type(ty) drop(Sub) name(_sel_t4a, replace)
    * r(k) counts type-1 rows; the dropped subgroup row leaves r(table).
    assert r(k) == 2
    matrix T = r(table)
    assert rowsof(T) == 3
    local rn : rownames T
    assert "`rn'" == "S1 S2 Overall"

    _pooled_fixture
    eplot es lo hi, labels(lab) type(ty) keep(S1 S2) name(_sel_t4b, replace)
    assert r(k) == 2
    matrix T = r(table)
    assert rowsof(T) == 2
    local rn : rownames T
    assert "`rn'" == "S1 S2"

    * Selection that removes every plottable effect row is an error even when
    * a structural row survives.
    clear
    quietly set obs 2
    quietly gen str20 lab = cond(_n == 1, "Header", "A")
    quietly gen double es = cond(_n == 1, ., 1)
    quietly gen double lo = es - 1
    quietly gen double hi = es + 1
    quietly gen byte ty = cond(_n == 1, 0, 1)
    capture noisily eplot es lo hi, labels(lab) type(ty) keep(Header) ///
        name(_sel_t4c, replace)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: 4 selection over structural and pooled rows"
    local ++pass_count
}
else {
    display as error "  FAIL: 4 selection over structural and pooled rows (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}
capture graph drop _sel_t4a
capture graph drop _sel_t4b

**# 5. Frame mode inherits data-mode selection and preserves caller state
local ++test_count
capture noisily {
    capture frame drop _sel_frame
    _sel_fixture
    rename lab label
    rename es estimate
    rename lo ll
    rename hi ul
    frame put label estimate ll ul, into(_sel_frame)

    clear
    quietly set obs 5
    quietly gen int marker = _n
    local before_frame "`c(frame)'"
    local before_N = _N

    eplot, frame(_sel_frame) keep(B) name(_sel_t5a, replace)
    assert r(k) == 1
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "B"
    assert "`c(frame)'" == "`before_frame'"
    assert _N == `before_N'
    assert marker[1] == 1

    eplot, frame(_sel_frame) noconstant name(_sel_t5b, replace)
    assert r(k) == 2
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "A B"

    eplot, frame(_sel_frame) drop(A) name(_sel_t5c, replace)
    assert r(k) == 2
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "B _cons"

    * Frame mode also honours [if] [in], which the syntax accepts.
    eplot in 1/2, frame(_sel_frame) name(_sel_t5d, replace)
    assert r(k) == 2
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "A B"
}
if _rc == 0 {
    display as result "  PASS: 5 frame selection and caller state"
    local ++pass_count
}
else {
    display as error "  FAIL: 5 frame selection and caller state (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}
capture frame drop _sel_frame
capture graph drop _sel_t5a
capture graph drop _sel_t5b
capture graph drop _sel_t5c
capture graph drop _sel_t5d

**# 6. coeflabels() composes with groups(), headers(), and order() in data mode
local ++test_count
capture noisily {
    * The documented spaced call: groups() keys on the SOURCE name even though
    * coeflabels() renames it for display.  Before 1.3.0 this returned r(198)
    * because coeflabels() had already erased the key groups() matches on.
    _sel_fixture
    eplot es lo hi, labels(lab) coeflabels(A = "Alpha") groups(A = "Domain") ///
        name(_sel_t6a, replace)
    local c `"`r(cmd)'"'
    assert r(N) == 4
    assert r(k) == 3
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "Alpha B _cons"
    * The group header is inserted above its first member, and the member row
    * carries the display label.
    local pDomain = strpos(`"`c'"', "Domain")
    local pAlpha  = strpos(`"`c'"', "Alpha")
    assert `pDomain' > 0
    assert `pAlpha' > 0
    assert `pDomain' < `pAlpha'

    * headers() keys on the source name too.
    _sel_fixture
    eplot es lo hi, labels(lab) coeflabels(B = "Beta") headers(B = "Section") ///
        name(_sel_t6b, replace)
    local c `"`r(cmd)'"'
    assert r(N) == 4
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "A Beta _cons"
    local pSection = strpos(`"`c'"', "Section")
    local pBeta    = strpos(`"`c'"', "Beta")
    assert `pSection' > 0
    assert `pBeta' > 0
    assert `pSection' < `pBeta'

    * order() keys on the source name; the display label still follows the row.
    _sel_fixture
    eplot es lo hi, labels(lab) coeflabels(A = "Alpha") order(_cons B A) ///
        name(_sel_t6c, replace)
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "_cons B Alpha"

    * Selection, grouping and relabeling compose in one call.
    _sel_fixture
    eplot es lo hi, labels(lab) keep(A B) coeflabels(A = "Alpha") ///
        groups(A B = "Domain") name(_sel_t6d, replace)
    assert r(k) == 2
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "Alpha B"

    * Negative control: a group key that matches only the DISPLAY label must
    * still fail, proving the match runs against source names.
    _sel_fixture
    capture noisily eplot es lo hi, labels(lab) coeflabels(A = "Alpha") ///
        groups(Alpha = "Domain") name(_sel_t6e, replace)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: 6 data coeflabels composes with groups/headers/order"
    local ++pass_count
}
else {
    display as error "  FAIL: 6 data coeflabels composition (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}
capture graph drop _sel_t6a
capture graph drop _sel_t6b
capture graph drop _sel_t6c
capture graph drop _sel_t6d

**# 7. The same composition rule holds in frame, estimates, and matrix modes
local ++test_count
capture noisily {
    capture frame drop _sel_frame2
    _sel_fixture
    rename lab label
    rename es estimate
    rename lo ll
    rename hi ul
    frame put label estimate ll ul, into(_sel_frame2)
    clear
    quietly set obs 2
    quietly gen int marker = _n
    eplot, frame(_sel_frame2) coeflabels(A = "Alpha") groups(A = "Domain") ///
        name(_sel_t7a, replace)
    local c `"`r(cmd)'"'
    assert r(N) == 4
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "Alpha B _cons"
    local pDomain = strpos(`"`c'"', "Domain")
    local pAlpha  = strpos(`"`c'"', "Alpha")
    assert `pDomain' > 0 & `pAlpha' > 0 & `pDomain' < `pAlpha'

    sysuse auto, clear
    quietly regress price mpg weight foreign
    eplot ., drop(_cons) coeflabels(mpg = "MPG") groups(mpg = "Domain") ///
        name(_sel_t7b, replace)
    local c `"`r(cmd)'"'
    local pDomain = strpos(`"`c'"', "Domain")
    local pMPG    = strpos(`"`c'"', "MPG")
    assert `pDomain' > 0 & `pMPG' > 0 & `pDomain' < `pMPG'

    matrix RSEL = (1, .5, 1.5 \ 2, 1.5, 2.5)
    matrix rownames RSEL = A B
    eplot, matrix(RSEL) keep(B) coeflabels(B = "Beta") name(_sel_t7c, replace)
    assert r(k) == 1
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "Beta"
}
if _rc == 0 {
    display as result "  PASS: 7 composition rule across frame/estimates/matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: 7 composition across modes (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}
capture frame drop _sel_frame2
capture graph drop _sel_t7a
capture graph drop _sel_t7b
capture graph drop _sel_t7c

display _n "{bf:INTERVAL SUPPRESSION}"

**# 8. noci removes every interval-derived layer, diamonds included
local ++test_count
capture noisily {
    * Control first: the default DOES draw pooled diamonds and study whiskers.
    _pooled_fixture
    eplot es lo hi, labels(lab) type(ty) name(_sel_t8a, replace)
    local c0 `"`r(cmd)'"'
    assert strpos(`"`c0'"', "pcspike") > 0
    assert strpos(`"`c0'"', "rspike") > 0
    assert strpos(`"`c0'"', "Diamonds represent") > 0

    * noci alone: no rspike, no rcap, and no CI-derived pcspike diamonds.
    _pooled_fixture
    eplot es lo hi, labels(lab) type(ty) noci name(_sel_t8b, replace)
    assert r(N) == 4
    local c1 `"`r(cmd)'"'
    assert strpos(`"`c1'"', "rspike") == 0
    assert strpos(`"`c1'"', "rcap") == 0
    assert strpos(`"`c1'"', "pcspike") == 0
    assert strpos(`"`c1'"', "Diamonds represent") == 0
    * Point estimates survive.
    assert strpos(`"`c1'"', "scatter") > 0

    * noci with cicap must not reintroduce capped intervals.
    _pooled_fixture
    eplot es lo hi, labels(lab) type(ty) noci cicap name(_sel_t8c, replace)
    local c2 `"`r(cmd)'"'
    assert strpos(`"`c2'"', "rcap") == 0
    assert strpos(`"`c2'"', "pcspike") == 0

    * Same contract through the frame route.
    capture frame drop _sel_frame3
    _pooled_fixture
    rename lab label
    rename es estimate
    rename lo ll
    rename hi ul
    rename ty rowtype
    frame put label estimate ll ul rowtype, into(_sel_frame3)
    clear
    quietly set obs 2
    quietly gen int marker = _n
    eplot, frame(_sel_frame3) noci name(_sel_t8d, replace)
    local c3 `"`r(cmd)'"'
    assert strpos(`"`c3'"', "rspike") == 0
    assert strpos(`"`c3'"', "rcap") == 0
    assert strpos(`"`c3'"', "pcspike") == 0
}
if _rc == 0 {
    display as result "  PASS: 8 noci suppresses all interval geometry"
    local ++pass_count
}
else {
    display as error "  FAIL: 8 noci interval geometry (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}
capture frame drop _sel_frame3
capture graph drop _sel_t8a
capture graph drop _sel_t8b
capture graph drop _sel_t8c
capture graph drop _sel_t8d

display _n "{bf:MODE-SCOPED PRESENTATION OPTIONS}"

**# 9. Multi-model estimates report the single-model-only options they ignore
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store _sel_m1
    quietly regress price mpg weight
    estimates store _sel_m2

    * Single-model: values really is applied.
    eplot _sel_m1, drop(_cons) values name(_sel_t9a, replace)
    assert strpos(`"`r(cmd)'"', "mlabel(_val_text)") > 0

    * Multi-model: the layer is absent and the palette colors win.  Capture
    * the console so the note itself is asserted; without it this case would
    * pass on the pre-1.3.0 build, which discarded the options in silence.
    * A batch log wraps at c(linesize) with a "> " continuation, which would
    * split the note mid-word; widen the line so each note is one record.
    local _orig_ls = c(linesize)
    set linesize 200
    tempfile _mmlog
    capture log close _sel_mm
    log using "`_mmlog'", replace text name(_sel_mm)
    eplot _sel_m1 _sel_m2, drop(_cons) values stars sigcolors ///
        sigcolor(red) insigncolor(green) name(_sel_t9b, replace)
    * Capture r(cmd) before `log close', which clears r().
    local c `"`r(cmd)'"'
    log close _sel_mm
    assert strpos(`"`c'"', "mlabel(_val_text)") == 0
    assert strpos(`"`c'"', "red") == 0
    assert strpos(`"`c'"', "green") == 0
    assert strpos(`"`c'"', "mcolor(navy)") > 0
    assert strpos(`"`c'"', "mcolor(cranberry)") > 0

    * Read the captured console back and require the note to name every
    * option that was dropped.
    tempname _fh
    local _noted 0
    local _saw_values 0
    local _saw_stars 0
    local _saw_sigcolors 0
    file open `_fh' using "`_mmlog'", read text
    file read `_fh' _ln
    while r(eof) == 0 {
        if substr(`"`_ln'"', 1, 6) == "(note:" & ///
           strpos(`"`_ln'"', "ignored in multi-model mode") > 0 {
            local _noted 1
            if strpos(`"`_ln'"', "values") > 0     local _saw_values 1
            if strpos(`"`_ln'"', "stars") > 0      local _saw_stars 1
            if strpos(`"`_ln'"', "sigcolors") > 0  local _saw_sigcolors 1
        }
        file read `_fh' _ln
    }
    file close `_fh'
    assert `_noted' == 1
    assert `_saw_values' == 1
    assert `_saw_stars' == 1
    assert `_saw_sigcolors' == 1

    * Negative control: the single-model call must NOT emit that note.
    tempfile _smlog
    capture log close _sel_sm
    log using "`_smlog'", replace text name(_sel_sm)
    eplot _sel_m1, drop(_cons) values stars name(_sel_t9c, replace)
    log close _sel_sm
    local _noted 0
    file open `_fh' using "`_smlog'", read text
    file read `_fh' _ln
    while r(eof) == 0 {
        if substr(`"`_ln'"', 1, 6) == "(note:" & ///
           strpos(`"`_ln'"', "ignored in multi-model mode") > 0 local _noted 1
        file read `_fh' _ln
    }
    file close `_fh'
    assert `_noted' == 0

    * A style preset that supplies values must not produce the note, because
    * the user never asked for values.
    tempfile _stlog
    capture log close _sel_st
    log using "`_stlog'", replace text name(_sel_st)
    eplot _sel_m1 _sel_m2, drop(_cons) style(forest) name(_sel_t9d, replace)
    log close _sel_st
    local _noted 0
    file open `_fh' using "`_stlog'", read text
    file read `_fh' _ln
    while r(eof) == 0 {
        if substr(`"`_ln'"', 1, 6) == "(note:" & ///
           strpos(`"`_ln'"', "ignored in multi-model mode") > 0 local _noted 1
        file read `_fh' _ln
    }
    file close `_fh'
    assert `_noted' == 0
    set linesize `_orig_ls'

    estimates drop _sel_m1 _sel_m2
}
if _rc == 0 {
    display as result "  PASS: 9 multi-model presentation-option scope"
    local ++pass_count
}
else {
    display as error "  FAIL: 9 multi-model presentation-option scope (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}
capture estimates drop _all
capture graph drop _sel_t9a
capture graph drop _sel_t9b
capture graph drop _sel_t9c
capture graph drop _sel_t9d
capture log close _sel_mm
capture log close _sel_sm
capture log close _sel_st

display _n "{bf:NUMERIC OPTION DOMAINS AND WEIGHT VALIDITY}"

**# 10. Invalid numeric option values fail before graph construction
local ++test_count
capture noisily {
    _sel_fixture
    capture noisily eplot es lo hi, labels(lab) dp(-1) values name(_sel_t10, replace)
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) rescale(.) name(_sel_t10, replace)
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) null(.) name(_sel_t10, replace)
    assert _rc == 198
    quietly gen double w = _n
    capture noisily eplot es lo hi, labels(lab) weights(w) boxscale(-100) ///
        name(_sel_t10, replace)
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) weights(w) boxscale(0) ///
        name(_sel_t10, replace)
    assert _rc == 198

    * Valid boundary values still work.
    eplot es lo hi, labels(lab) dp(0) values name(_sel_t10, replace)
    assert r(k) == 3
    eplot es lo hi, labels(lab) weights(w) boxscale(50) name(_sel_t10, replace)
    assert r(k) == 3
    eplot es lo hi, labels(lab) rescale(-2) name(_sel_t10, replace)
    matrix T = r(table)
    assert T[1, 2] <= T[1, 3]

    * The same domains hold in estimates and matrix modes.
    sysuse auto, clear
    quietly regress price mpg
    foreach bad in "dp(-1)" "rescale(.)" "null(.)" {
        capture noisily eplot ., drop(_cons) `bad' name(_sel_t10, replace)
        assert _rc == 198
    }
    matrix RD = (1, .5, 1.5 \ 2, 1.5, 2.5)
    matrix rownames RD = A B
    foreach bad in "dp(-1)" "rescale(.)" "null(.)" {
        capture noisily eplot, matrix(RD) `bad' name(_sel_t10, replace)
        assert _rc == 198
    }
}
if _rc == 0 {
    display as result "  PASS: 10 numeric option domains"
    local ++pass_count
}
else {
    display as error "  FAIL: 10 numeric option domains (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}
capture graph drop _sel_t10

**# 11. Weighted markers require a usable weight on every plotted effect row
local ++test_count
capture noisily {
    _pooled_fixture
    quietly gen double w = 10 * _n
    * Pooled rows carry no weight in the documented forest-plot idiom.
    quietly replace w = . if inlist(ty, 3, 5)
    eplot es lo hi, labels(lab) type(ty) weights(w) name(_sel_t11a, replace)
    assert r(k) == 2

    * A missing weight on a plotted type-1 row would silently drop that row's
    * marker while leaving the row in r(table); that must be an error.
    quietly replace w = . in 1
    capture noisily eplot es lo hi, labels(lab) type(ty) weights(w) ///
        name(_sel_t11b, replace)
    assert _rc == 198

    quietly replace w = -5 in 1
    capture noisily eplot es lo hi, labels(lab) type(ty) weights(w) ///
        name(_sel_t11c, replace)
    assert _rc == 198

    quietly replace w = 0 in 1
    capture noisily eplot es lo hi, labels(lab) type(ty) weights(w) ///
        name(_sel_t11d, replace)
    assert _rc == 198

    * nobox opts out of weight-proportional squares, so the weight column is
    * no longer load-bearing.
    eplot es lo hi, labels(lab) type(ty) weights(w) nobox name(_sel_t11e, replace)
    assert r(k) == 2

    * A row excluded by keep()/drop() cannot trigger the weight error.
    quietly replace w = . in 1
    eplot es lo hi, labels(lab) type(ty) weights(w) drop(S1) ///
        name(_sel_t11f, replace)
    assert r(k) == 1
}
if _rc == 0 {
    display as result "  PASS: 11 weighted-marker weight validity"
    local ++pass_count
}
else {
    display as error "  FAIL: 11 weighted-marker weight validity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}
capture graph drop _all

**# 12. Selection leaves caller data and varabbrev untouched
local ++test_count
capture noisily {
    set varabbrev on
    _sel_fixture
    local before_N = _N
    eplot es lo hi, labels(lab) keep(A) name(_sel_t12, replace)
    assert _N == `before_N'
    assert lab[1] == "A"
    assert lab[3] == "_cons"
    assert "`c(varabbrev)'" == "on"

    * The same holds when selection fails.
    capture noisily eplot es lo hi, labels(lab) keep(ZZZ) name(_sel_t12, replace)
    assert _rc == 2000
    assert _N == `before_N'
    assert lab[3] == "_cons"
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: 12 caller state preserved across selection"
    local ++pass_count
}
else {
    display as error "  FAIL: 12 caller state across selection (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}
set varabbrev off
capture graph drop _all

capture program drop _sel_fixture
capture program drop _pooled_fixture

display _n "{bf:test_selection_labels summary}"
_eplot_qa_result test_selection_labels, tests(`test_count') pass(`pass_count') ///
    fail(`fail_count') skip(0)
if `fail_count' > 0 {
    display as error "Failed cases:`failed_tests'"
    exit 1
}
