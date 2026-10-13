clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_colors.log", write text replace
file close swlog
log using "test_colors.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* helper: does an exported SVG contain a literal string?
capture program drop _sw_svg_has
program define _sw_svg_has, rclass
    args file needle
    tempname fh
    file open `fh' using `"`file'"', read text
    local found = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(upper(`"`macval(line)'"'), upper(`"`needle'"')) local found = 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end

capture program drop _sw_make_state
program define _sw_make_state
    clear
    quietly set obs 4
    generate byte id = ceil(_n / 2)
    generate byte s0 = cond(mod(_n, 2) == 1, 0, 5)
    generate byte s1 = cond(mod(_n, 2) == 1, 5, 9)
    generate byte state = 1
    replace state = 2 if inlist(_n, 2, 3)
    replace s0 = 0 if _n == 3
    replace s1 = 4 if _n == 3
    replace s0 = 4 if _n == 4
    label define st 1 "A" 2 "B"
    label values state st
end

**# 1. quoted RGB triplets reach the exported SVG (was: grey fallback)

local ++test_count
capture noisily {
    _sw_make_state
    local svg "`c(tmpdir)'/sw_colors_test.svg"
    capture erase "`svg'"
    swimlane, id(id) start(s0) stop(s1) state(state) ///
        colors("0 114 178" "213 94 0") name(sw_col1, replace) ///
        export(`"`svg'"', replace)
    local cmdline `"`r(cmdline)'"'
    * outline colours are exact RGB (0,114,178) = #0072B2, (213,94,0) = #D55E00
    _sw_svg_has "`svg'" "stroke:#0072B2"
    assert r(found) == 1
    _sw_svg_has "`svg'" "stroke:#D55E00"
    assert r(found) == 1
    assert strpos(`"`cmdline'"', `"lcolor("0 114 178")"') > 0
    capture erase "`svg'"
    capture graph drop sw_col1
}
if _rc == 0 {
    display as result "  PASS: quoted RGB colors() render in the exported SVG"
    local ++pass_count
}
else {
    display as error "  FAIL: quoted RGB colors() (error `=_rc')"
    local ++fail_count
}

**# 2. named colors, opacity and intensity suffixes, hex

local ++test_count
capture noisily {
    _sw_make_state
    local svg "`c(tmpdir)'/sw_colors_test.svg"
    capture erase "`svg'"
    swimlane, id(id) start(s0) stop(s1) state(state) ///
        colors(navy%30 "213 94 0*.5") baropacity(50) ///
        name(sw_col2, replace) export(`"`svg'"', replace)
    * a % in the token overrides baropacity(); other bars use baropacity(50)
    _sw_svg_has "`svg'" "opacity:0.30"
    assert r(found) == 1
    _sw_svg_has "`svg'" "opacity:0.50"
    assert r(found) == 1
    swimlane, id(id) start(s0) stop(s1) state(state) ///
        colors("0 114 178" forest_green) name(sw_col2, replace) nodraw
    capture graph drop sw_col2
}
if _rc == 0 {
    display as result "  PASS: named, %opacity, *intensity, baropacity()"
    local ++pass_count
}
else {
    display as error "  FAIL: color suffixes / baropacity (error `=_rc')"
    local ++fail_count
}

**# 3. invalid colors and opacity error clearly (also with nograph)

* each of these is silently drawn in a fallback color by Stata itself
local ++test_count
capture noisily {
    _sw_make_state
    foreach bad in notacolor "0 114" "0 114 300" "navy%x" "navy%101" ///
        "p1" "#FF0000" "%30" "*.7" "hsv 400 1 1" "0.5 0.2 0.1 2" "navy%30%40" {
        capture swimlane, id(id) start(s0) stop(s1) state(state) ///
            colors(navy `"`bad'"') nograph
        if _rc != 198 {
            display as error "    expected 198 for [`bad'], got `=_rc'"
            assert 0
        }
    }
    capture swimlane, id(id) start(s0) stop(s1) state(state) ///
        baropacity(150) nograph
    assert _rc == 198
    capture swimlane, id(id) start(s0) stop(s1) state(state) ///
        baropacity(-5) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: invalid colors() and baropacity() return 198"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid color handling (error `=_rc')"
    local ++fail_count
}

**# 4. valid colorstyles that must be accepted and must draw

local ++test_count
capture noisily {
    _sw_make_state
    * a user-defined color file must resolve like any named color
    * a user-defined color file, kept in a private directory placed on the
    * adopath for this test only (never the real PERSONAL/PLUS folders)
    tempfile qtf
    local qdir "`qtf'_adopath"
    capture mkdir "`qdir'"
    capture mkdir "`qdir'/style"
    tempname sfh
    file open `sfh' using "`qdir'/style/color-swqacustom.style", write text replace
    file write `sfh' `"set rgb "10 20 30""' _n
    file close `sfh'
    adopath ++ "`qdir'"
    discard
    local svg "`c(tmpdir)'/sw_colors_test.svg"

    * name that is a user color file; hsv; decimal CMYK; intensity
    foreach spec in `""swqacustom" "stroke:#0A141E""' ///
        `""hsv 240 1 1" "stroke:#0000FF""' ///
        `""0.5 0.2 0.1 0.0" "stroke:#80CCE6""' ///
        `""255 0 0*1.2" "stroke:#D50000""' {
        gettoken col spec : spec
        gettoken want spec : spec
        capture erase "`svg'"
        swimlane, id(id) start(s0) stop(s1) state(state) ///
            colors("`col'" navy) name(sw_col4, replace) export(`"`svg'"', replace)
        _sw_svg_has "`svg'" "`want'"
        if r(found) != 1 {
            display as error "    no `want' for [`col']"
            assert 0
        }
    }
    * bg and fg resolve (no named-file) and draw
    swimlane, id(id) start(s0) stop(s1) state(state) colors(bg fg) ///
        name(sw_col4, replace) nodraw
    capture adopath - "`qdir'"
    capture erase "`qdir'/style/color-swqacustom.style"
    capture rmdir "`qdir'/style"
    capture rmdir "`qdir'"
    discard
    capture graph drop sw_col4
    capture erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: user colors, hsv, decimal CMYK, intensity, bg/fg are accepted and drawn"
    local ++pass_count
}
else {
    capture adopath - "`qdir'"
    capture erase "`qdir'/style/color-swqacustom.style"
    capture rmdir "`qdir'/style"
    capture rmdir "`qdir'"
    display as error "  FAIL: valid colorstyles (error `=_rc')"
    local ++fail_count
}

**# 5. baropacity() with palette(scheme) is honoured; with lanetype(line) it is a noted no-op

local ++test_count
capture noisily {
    _sw_make_state
    local svg "`c(tmpdir)'/sw_colors_test.svg"
    capture erase "`svg'"
    swimlane, id(id) start(s0) stop(s1) state(state) palette(scheme) ///
        baropacity(40) name(sw_col5, replace) export(`"`svg'"', replace)
    _sw_svg_has "`svg'" "opacity:0.40"
    assert r(found) == 1
    * outlines stay at full opacity: no stroke-opacity anywhere in the bars
    _sw_svg_has "`svg'" "stroke-opacity:0.40"
    assert r(found) == 0
    swimlane, id(id) start(s0) stop(s1) state(state) lanetype(line) ///
        baropacity(40) name(sw_col5, replace) nodraw
    capture graph drop sw_col5
    capture erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: baropacity() honoured under palette(scheme); noted under lanetype(line)"
    local ++pass_count
}
else {
    display as error "  FAIL: baropacity() corner cases (error `=_rc')"
    local ++fail_count
}

**# 6. surrounding spaces in a colors() entry are trimmed, not passed on

local ++test_count
capture noisily {
    _sw_make_state
    local svg "`c(tmpdir)'/sw_colors_test.svg"
    capture erase "`svg'"
    swimlane, id(id) start(s0) stop(s1) state(state) ///
        colors("0 114 178 " " 213 94 0") name(sw_col6, replace) ///
        export(`"`svg'"', replace)
    _sw_svg_has "`svg'" "stroke:#0072B2"
    assert r(found) == 1
    _sw_svg_has "`svg'" "stroke:#D55E00"
    assert r(found) == 1
    capture graph drop sw_col6
    capture erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: padded colors() entries are trimmed"
    local ++pass_count
}
else {
    display as error "  FAIL: padded colors() entries (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_colors tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_colors tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
