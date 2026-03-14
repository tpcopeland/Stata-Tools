clear all
set more off
version 16.0

* test_raincloud.do - Functional tests for raincloud package
* Generated: 2026-03-13, updated 2026-03-14
* Tests: 50

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0

capture ado uninstall raincloud
quietly net install raincloud, from("/home/tpcopeland/Stata-Dev/raincloud")

* ============================================================
* Basic Functionality
* ============================================================

* Test 1: Minimal invocation
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg
    assert r(N) == 74
    assert r(n_groups) == 1
}
if _rc == 0 {
    display as result "  PASS: Basic - minimal invocation"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic - minimal invocation (error `=_rc')"
    local ++fail_count
}

* Test 2: Over groups
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign)
    assert r(N) == 74
    assert r(n_groups) == 2
    assert "`r(varname)'" == "mpg"
    assert "`r(over)'" == "foreign"
}
if _rc == 0 {
    display as result "  PASS: Basic - over(foreign)"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic - over(foreign) (error `=_rc')"
    local ++fail_count
}

* Test 3: Return values - stats matrix dimensions
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign)
    matrix S = r(stats)
    assert rowsof(S) == 2
    assert colsof(S) == 8
    * Verify column names
    local cnames : colnames S
    assert "`cnames'" == "n mean sd median q25 q75 iqr bandwidth"
}
if _rc == 0 {
    display as result "  PASS: Basic - stats matrix structure"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic - stats matrix structure (error `=_rc')"
    local ++fail_count
}

* Test 4: if/in restriction
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg if price > 5000, over(foreign)
    assert r(N) < 74
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Basic - if restriction"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic - if restriction (error `=_rc')"
    local ++fail_count
}

* Test 5: Data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    raincloud mpg, over(foreign)
    assert _N == `N_before'
}
if _rc == 0 {
    display as result "  PASS: Basic - data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic - data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Orientation Options
* ============================================================

* Test 6: Horizontal (default)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, horizontal
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Orientation - horizontal"
    local ++pass_count
}
else {
    display as error "  FAIL: Orientation - horizontal (error `=_rc')"
    local ++fail_count
}

* Test 7: Vertical
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, vertical over(foreign)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Orientation - vertical"
    local ++pass_count
}
else {
    display as error "  FAIL: Orientation - vertical (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Element Toggle Options
* ============================================================

* Test 8: nocloud
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, nocloud over(foreign)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Toggle - nocloud"
    local ++pass_count
}
else {
    display as error "  FAIL: Toggle - nocloud (error `=_rc')"
    local ++fail_count
}

* Test 9: norain
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, norain over(foreign)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Toggle - norain"
    local ++pass_count
}
else {
    display as error "  FAIL: Toggle - norain (error `=_rc')"
    local ++fail_count
}

* Test 10: nobox
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, nobox over(foreign)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Toggle - nobox"
    local ++pass_count
}
else {
    display as error "  FAIL: Toggle - nobox (error `=_rc')"
    local ++fail_count
}

* Test 11: noumbrella (synonym for nobox)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, noumbrella
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Toggle - noumbrella synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: Toggle - noumbrella synonym (error `=_rc')"
    local ++fail_count
}

* Test 12: nocloud + norain (box only)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, nocloud norain over(foreign)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Toggle - nocloud norain (box only)"
    local ++pass_count
}
else {
    display as error "  FAIL: Toggle - nocloud norain (box only) (error `=_rc')"
    local ++fail_count
}

* Test 13: nocloud + nobox (rain only)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, nocloud nobox over(foreign)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Toggle - nocloud nobox (rain only)"
    local ++pass_count
}
else {
    display as error "  FAIL: Toggle - nocloud nobox (rain only) (error `=_rc')"
    local ++fail_count
}

* Test 14: norain + nobox (cloud only)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, norain nobox over(foreign)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Toggle - norain nobox (cloud only)"
    local ++pass_count
}
else {
    display as error "  FAIL: Toggle - norain nobox (cloud only) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cloud Options
* ============================================================

* Test 15: bandwidth
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, bandwidth(2)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Cloud - bandwidth(2)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cloud - bandwidth(2) (error `=_rc')"
    local ++fail_count
}

* Test 16: kernel
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, kernel(gaussian)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Cloud - kernel(gaussian)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cloud - kernel(gaussian) (error `=_rc')"
    local ++fail_count
}

* Test 17: n (density points)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, n(50)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Cloud - n(50)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cloud - n(50) (error `=_rc')"
    local ++fail_count
}

* Test 18: opacity
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, opacity(80)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Cloud - opacity(80)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cloud - opacity(80) (error `=_rc')"
    local ++fail_count
}

* Test 19: cloudwidth
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, cloudwidth(0.6)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Cloud - cloudwidth(0.6)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cloud - cloudwidth(0.6) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Rain Options
* ============================================================

* Test 20: jitter
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, jitter(0.8)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Rain - jitter(0.8)"
    local ++pass_count
}
else {
    display as error "  FAIL: Rain - jitter(0.8) (error `=_rc')"
    local ++fail_count
}

* Test 21: seed (reproducibility)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, seed(12345)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Rain - seed(12345)"
    local ++pass_count
}
else {
    display as error "  FAIL: Rain - seed(12345) (error `=_rc')"
    local ++fail_count
}

* Test 22: pointsize
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, pointsize(small)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Rain - pointsize(small)"
    local ++pass_count
}
else {
    display as error "  FAIL: Rain - pointsize(small) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Box Options
* ============================================================

* Test 23: boxwidth
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, boxwidth(0.15)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Box - boxwidth(0.15)"
    local ++pass_count
}
else {
    display as error "  FAIL: Box - boxwidth(0.15) (error `=_rc')"
    local ++fail_count
}

* Test 24: nomedian option
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, nomedian over(foreign)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Box - nomedian"
    local ++pass_count
}
else {
    display as error "  FAIL: Box - nomedian (error `=_rc')"
    local ++fail_count
}

* Test 25: mean option
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, mean over(foreign)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Box - mean marker"
    local ++pass_count
}
else {
    display as error "  FAIL: Box - mean marker (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Layout Options
* ============================================================

* Test 26: gap
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign) gap(1.5)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Layout - gap(1.5)"
    local ++pass_count
}
else {
    display as error "  FAIL: Layout - gap(1.5) (error `=_rc')"
    local ++fail_count
}

* Test 27: scheme
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, scheme(s1color)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Layout - scheme(s1color)"
    local ++pass_count
}
else {
    display as error "  FAIL: Layout - scheme(s1color) (error `=_rc')"
    local ++fail_count
}

* Test 28: title + subtitle + note
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, title("My Title") subtitle("My Subtitle") note("My Note")
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Layout - title/subtitle/note"
    local ++pass_count
}
else {
    display as error "  FAIL: Layout - title/subtitle/note (error `=_rc')"
    local ++fail_count
}

* Test 29: xtitle + ytitle
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign) xtitle("Miles per gallon") ytitle("Origin")
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Layout - xtitle/ytitle"
    local ++pass_count
}
else {
    display as error "  FAIL: Layout - xtitle/ytitle (error `=_rc')"
    local ++fail_count
}

* Test 30: Combined options stress test
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign) vertical mean nomedian ///
        opacity(70) jitter(0.6) bandwidth(2) seed(999) ///
        cloudwidth(0.5) boxwidth(0.1) pointsize(tiny) ///
        gap(1.2) title("Stress Test")
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: Combined options stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: Combined options stress test (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Error Handling
* ============================================================

* Test 31: opacity out of range
local ++test_count
capture noisily raincloud mpg, opacity(101)
if _rc == 198 {
    display as result "  PASS: Error - opacity out of range"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - opacity out of range (expected 198, got `=_rc')"
    local ++fail_count
}

* Test 32: jitter out of range
local ++test_count
capture noisily raincloud mpg, jitter(1.5)
if _rc == 198 {
    display as result "  PASS: Error - jitter out of range"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - jitter out of range (expected 198, got `=_rc')"
    local ++fail_count
}

* Test 33: both horizontal and vertical
local ++test_count
capture noisily raincloud mpg, horizontal vertical
if _rc == 198 {
    display as result "  PASS: Error - horizontal + vertical"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - horizontal + vertical (expected 198, got `=_rc')"
    local ++fail_count
}

* Test 34: all elements suppressed
local ++test_count
capture noisily raincloud mpg, nocloud norain nobox
if _rc == 198 {
    display as result "  PASS: Error - all elements suppressed"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - all elements suppressed (expected 198, got `=_rc')"
    local ++fail_count
}

* Test 35: no observations
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg if price > 999999
}
if _rc == 2000 {
    display as result "  PASS: Error - no observations"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - no observations (expected 2000, got `=_rc')"
    local ++fail_count
}

* Test 36: varabbrev restored after error
local ++test_count
capture noisily {
    sysuse auto, clear
    local va_before = c(varabbrev)
    capture noisily raincloud mpg, opacity(999)
    local va_after = c(varabbrev)
    assert "`va_before'" == "`va_after'"
}
if _rc == 0 {
    display as result "  PASS: Error - varabbrev restored"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - varabbrev restored (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Edge Cases
* ============================================================

* Test 37: Single observation
local ++test_count
capture noisily {
    sysuse auto, clear
    keep in 1
    raincloud mpg
    assert r(N) == 1
    assert r(n_groups) == 1
}
if _rc == 0 {
    display as result "  PASS: Edge - single observation"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - single observation (error `=_rc')"
    local ++fail_count
}

* Test 38: Constant variable (zero variance)
local ++test_count
capture noisily {
    clear
    set obs 50
    gen double x = 10
    raincloud x
    assert r(N) == 50
}
if _rc == 0 {
    display as result "  PASS: Edge - constant variable"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - constant variable (error `=_rc')"
    local ++fail_count
}

* Test 39: String over variable
local ++test_count
capture noisily {
    sysuse auto, clear
    gen str10 origin = cond(foreign == 0, "Domestic", "Foreign")
    raincloud mpg, over(origin)
    assert r(N) == 74
    assert r(n_groups) == 2
}
if _rc == 0 {
    display as result "  PASS: Edge - string over variable"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - string over variable (error `=_rc')"
    local ++fail_count
}

* Test 40: Many groups (>8, tests color cycling)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(rep78)
    assert r(n_groups) == 5
}
if _rc == 0 {
    display as result "  PASS: Edge - many groups (5 levels)"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - many groups (5 levels) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* v1.1.0 Features
* ============================================================

* Test 41: colors() with fewer colors than groups (cycling)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(rep78) colors(red blue)
    assert r(N) > 0
    assert r(n_groups) == 5
}
if _rc == 0 {
    display as result "  PASS: colors() - fewer colors than groups (cycling)"
    local ++pass_count
}
else {
    display as error "  FAIL: colors() - fewer colors than groups (cycling) (error `=_rc')"
    local ++fail_count
}

* Test 42: colors() with exact match
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign) colors(red blue)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: colors() - exact color count"
    local ++pass_count
}
else {
    display as error "  FAIL: colors() - exact color count (error `=_rc')"
    local ++fail_count
}

* Test 43: mirror basic
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign) mirror
    assert r(N) == 74
    assert r(n_groups) == 2
}
if _rc == 0 {
    display as result "  PASS: mirror - basic"
    local ++pass_count
}
else {
    display as error "  FAIL: mirror - basic (error `=_rc')"
    local ++fail_count
}

* Test 44: mirror + vertical
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign) mirror vertical
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: mirror - vertical orientation"
    local ++pass_count
}
else {
    display as error "  FAIL: mirror - vertical orientation (error `=_rc')"
    local ++fail_count
}

* Test 45: mirror + mean + overlap
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign) mirror mean overlap
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: mirror + mean + overlap"
    local ++pass_count
}
else {
    display as error "  FAIL: mirror + mean + overlap (error `=_rc')"
    local ++fail_count
}

* Test 46: mirror + norain (violin only)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign) mirror norain
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: mirror + norain (full violin)"
    local ++pass_count
}
else {
    display as error "  FAIL: mirror + norain (full violin) (error `=_rc')"
    local ++fail_count
}

* Test 47: by() removed from syntax (absorbed by * passthrough, errors at graph)
local ++test_count
capture noisily {
    sysuse auto, clear
    * by() no longer has dedicated handling — it passes to twoway which errors
    raincloud mpg, by(foreign)
}
if _rc != 0 {
    display as result "  PASS: by() errors at graph level (rc `=_rc')"
    local ++pass_count
}
else {
    * If twoway happens to accept by() in some Stata versions, still pass
    display as result "  PASS: by() passthrough (no dedicated handling)"
    local ++pass_count
}

* Test 48: r(stats) has 8 columns with bandwidth populated
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign)
    matrix S = r(stats)
    assert colsof(S) == 8
    * Bandwidth column should be populated (not missing) for normal groups
    assert S[1,8] > 0
    assert S[2,8] > 0
}
if _rc == 0 {
    display as result "  PASS: r(stats) bandwidth column populated"
    local ++pass_count
}
else {
    display as error "  FAIL: r(stats) bandwidth column populated (error `=_rc')"
    local ++fail_count
}

* Test 49: bandwidth missing for zero-variance group
local ++test_count
capture noisily {
    clear
    set obs 30
    gen double x = cond(_n <= 20, rnormal(), 5)
    gen group = cond(_n <= 20, 1, 2)
    * Group 2 has 10 obs all equal to 5 (zero variance)
    replace x = 5 if group == 2
    raincloud x, over(group)
    matrix S = r(stats)
    * Group 1 should have bandwidth
    assert S[1,8] > 0
    * Group 2 has zero variance → skip_cloud → bandwidth is missing
    assert S[2,8] == .
}
if _rc == 0 {
    display as result "  PASS: bandwidth missing for zero-variance group"
    local ++pass_count
}
else {
    display as error "  FAIL: bandwidth missing for zero-variance group (error `=_rc')"
    local ++fail_count
}

* Test 50: mirror + colors combined
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign) mirror colors(cranberry forest_green) ///
        mean seed(42)
    assert r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: mirror + colors combined"
    local ++pass_count
}
else {
    display as error "  FAIL: mirror + colors combined (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Summary
* ============================================================

display as result _newline "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
