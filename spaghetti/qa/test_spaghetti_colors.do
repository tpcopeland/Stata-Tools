* colors() / individual(color()) parsing: quoted RGB, named, errors.
version 16.0
clear all
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall spaghetti
quietly net install spaghetti, from("`pkg_dir'") replace
local tests = 0
local pass = 0
local fail = 0

capture program drop _sp_svg_has
program define _sp_svg_has, rclass
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

capture program drop _sp_make
program define _sp_make
    clear
    quietly set obs 60
    generate byte id = ceil(_n / 3)
    generate byte time = mod(_n - 1, 3)
    generate double y = id + time
    generate byte grp = (id > 10)
    generate double base = id
end

**# 1. colorby with a quoted-RGB sequential palette
local ++tests
capture noisily {
    _sp_make
    local svg "`c(tmpdir)'/sp_colors_test.svg"
    capture erase "`svg'"
    spaghetti y, id(id) time(time) colorby(base) ///
        colors("158 202 225" "107 174 214" "66 146 198" "33 113 181" "8 69 148") ///
        export(`"`svg'"', replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', `"lcolor("158 202 225%25")"') > 0
    assert strpos(`"`cmd'"', `"lcolor("8 69 148%25")"') > 0
    * 158 202 225 = #9ECAE1 and 8 69 148 = #084594
    _sp_svg_has "`svg'" "stroke:#9ECAE1"
    assert r(found) == 1
    _sp_svg_has "`svg'" "stroke:#084594"
    assert r(found) == 1
    capture erase "`svg'"
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: colorby quoted RGB colors()"
    local ++fail
}

**# 2. by() with quoted RGB: lines and mean overlays take the exact colors
local ++tests
capture noisily {
    _sp_make
    local svg "`c(tmpdir)'/sp_colors_test.svg"
    capture erase "`svg'"
    spaghetti y, id(id) time(time) by(grp) mean(bold) ///
        colors("0 114 178" "213 94 0") export(`"`svg'"', replace)
    _sp_svg_has "`svg'" "stroke:#0072B2"
    assert r(found) == 1
    _sp_svg_has "`svg'" "stroke:#D55E00"
    assert r(found) == 1
    capture erase "`svg'"
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: by() quoted RGB colors()"
    local ++fail
}

**# 3. individual(color("R G B"))
local ++tests
capture noisily {
    _sp_make
    local svg "`c(tmpdir)'/sp_colors_test.svg"
    capture erase "`svg'"
    spaghetti y, id(id) time(time) individual(color("0 114 178") opacity(60)) ///
        export(`"`svg'"', replace)
    _sp_svg_has "`svg'" "stroke:#0072B2"
    assert r(found) == 1
    capture erase "`svg'"
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: individual(color()) RGB"
    local ++fail
}

**# 4. invalid colors error instead of silently falling back
local ++tests
capture noisily {
    _sp_make
    foreach bad in notacolor "0 114" "0 114 300" "navy%50" "p1" "#FF0000" ///
        "%30" "*.7" "hsv 400 1 1" "0.5 0.2 0.1 2" "navy*x" {
        capture spaghetti y, id(id) time(time) by(grp) colors(navy `"`bad'"')
        if _rc != 198 {
            display as error "    expected 198 for [`bad'], got `=_rc'"
            assert 0
        }
    }
    capture spaghetti y, id(id) time(time) individual(color(notacolor))
    assert _rc == 198
    capture spaghetti y, id(id) time(time) individual(color(navy%50))
    assert _rc == 198
    * a quoted triplet counts as one color, so one entry cannot cover 2 groups
    capture spaghetti y, id(id) time(time) by(grp) colors("0 114 178")
    assert _rc == 198
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: invalid colors() handling"
    local ++fail
}

**# 5. valid colorstyles Stata resolves are accepted and drawn
local ++tests
capture noisily {
    _sp_make
    * a user-defined color file, kept in a private directory placed on the
    * adopath for this test only (never the real PERSONAL/PLUS folders)
    tempfile qtf
    local qdir "`qtf'_adopath"
    capture mkdir "`qdir'"
    capture mkdir "`qdir'/style"
    tempname sfh
    file open `sfh' using "`qdir'/style/color-spqacustom.style", write text replace
    file write `sfh' `"set rgb "10 20 30""' _n
    file close `sfh'
    adopath ++ "`qdir'"
    discard
    local svg "`c(tmpdir)'/sp_colors_test.svg"
    foreach spec in `""spqacustom" "stroke:#0A141E""' ///
        `""hsv 240 1 1" "stroke:#0000FF""' ///
        `""0.5 0.2 0.1 0.0" "stroke:#80CCE6""' ///
        `""255 0 0*1.2" "stroke:#D50000""' {
        gettoken col spec : spec
        gettoken want spec : spec
        capture erase "`svg'"
        spaghetti y, id(id) time(time) by(grp) mean(bold) ///
            colors("`col'" navy) export(`"`svg'"', replace)
        _sp_svg_has "`svg'" "`want'"
        if r(found) != 1 {
            display as error "    no `want' for [`col']"
            assert 0
        }
    }
    * padded entries are trimmed
    spaghetti y, id(id) time(time) by(grp) colors("0 114 178 " " 213 94 0")
    assert strpos(`"`r(cmd)'"', `"lcolor("0 114 178%25")"') > 0
    * background/foreground resolve
    spaghetti y, id(id) time(time) by(grp) colors(bg fg)
    capture adopath - "`qdir'"
    capture erase "`qdir'/style/color-spqacustom.style"
    capture rmdir "`qdir'/style"
    capture rmdir "`qdir'"
    discard
    capture erase "`svg'"
}
if _rc == 0 local ++pass
else {
    capture adopath - "`qdir'"
    capture erase "`qdir'/style/color-spqacustom.style"
    capture rmdir "`qdir'/style"
    capture rmdir "`qdir'"
    display as error "FAIL: valid colorstyles"
    local ++fail
}

**# 6. individual() keeps options on either side of a quoted color
local ++tests
capture noisily {
    _sp_make
    local svg "`c(tmpdir)'/sp_colors_test.svg"
    foreach opts in `"color("0 114 178") opacity(60) lwidth(thick)"' ///
        `"opacity(60) lwidth(thick) color("0 114 178")"' ///
        `"lwidth(thick) color("0 114 178") opacity(60)"' ///
        `"COLOR("0 114 178") Opacity(60) LWidth(thick)"' {
        capture erase "`svg'"
        spaghetti y, id(id) time(time) individual(`opts') ///
            export(`"`svg'"', replace)
        local cmd `"`r(cmd)'"'
        if strpos(`"`cmd'"', `"lcolor("0 114 178%60")"') == 0 | ///
            strpos(`"`cmd'"', "lwidth(thick)") == 0 {
            display as error "    options lost for [`opts']"
            assert 0
        }
        _sp_svg_has "`svg'" "stroke-opacity:0.60"
        assert r(found) == 1
    }
    * intensity inside individual(color()) no longer raises r(199)
    spaghetti y, id(id) time(time) individual(color("navy*0.5") lwidth(medium))
    assert strpos(`"`r(cmd)'"', `"lcolor("navy*0.5%25")"') > 0
    assert strpos(`"`r(cmd)'"', "lwidth(medium)") > 0
    capture erase "`svg'"
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: individual() option parsing"
    local ++fail
}

display "RESULT: test_spaghetti_colors tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
