* test_cycle_20261119_stratetab.do - regression QA for the 2026-11-19 stratetab review cycle
*   F1 r(rates)/r(ratios) row names are cut on whole UTF-8 characters
*   F2 digits(), smallcells(), fontsize(), level() refuse -1 (it was the "not given" sentinel)
*   F3 ratetab refuses smallcells(1|2) before it fits; excludemasked needs 3 or more
*   F4 an empty smallcells() is r(198) in stratetab and ratetab (it read as absent);
*      outtab refuses smallcells(-1) and an empty smallcells() (session default leaked)

clear all
set more off
set varabbrev off
version 17.0

capture log close _cyc_st
log using "test_cycle_20261119_stratetab.log", replace text name(_cyc_st)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local w "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* a strate-style result file: one row per category label
capture program drop _cst_file
program define _cst_file
    version 17.0
    args file l1 l2 d1 d2
    clear
    quietly set obs 2
    gen str80 cat = cond(_n == 1, `"`l1'"', `"`l2'"')
    gen double _D = cond(_n == 1, `d1', `d2')
    gen double _Y = cond(_n == 1, 100, 200)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.8
    gen double _Upper = _Rate * 1.3
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    quietly save `"`file'"', replace
end

* every row name of matrix `1' is valid UTF-8, at most 32 bytes, and unique;
* r(nbad) counts the rows that fail
capture program drop _cst_rows
program define _cst_rows, rclass
    version 17.0
    args mat
    mata: _cst_rs = st_matrixrowstripe("`mat'")[., 2]
    mata: st_numscalar("r(nbad)", sum((ustrinvalidcnt(_cst_rs) :!= 0) :| (strlen(_cst_rs) :> 32)))
    mata: st_numscalar("r(nuniq)", rows(uniqrows(_cst_rs)))
    mata: st_numscalar("r(nrows)", rows(_cst_rs))
    mata: st_global("r(first)", _cst_rs[1])
    mata: mata drop _cst_rs
    return scalar nbad = r(nbad)
    return scalar nuniq = r(nuniq)
    return scalar nrows = r(nrows)
    return local first `"`r(first)'"'
end

* the ratetab fixture
capture program drop _cst_rt
program define _cst_rt
    version 17.0
    clear
    set seed 5
    quietly set obs 200
    gen id = ceil(_n / 4)
    gen byte grp = mod(_n, 3)
    gen ev = rpoisson(0.05)
    gen pt = 10 + runiform()
end

**# F1 row names cut on whole characters

**## two exposures, 2-byte characters: r(rates) names are valid UTF-8, unique
local ++test_count
capture noisily {
    local a = 25 * "Å"
    _cst_file "`w'/_cst_u1.dta" "`a'1" "`a'2" 10 20
    stratetab, using("`w'/_cst_u1" "`w'/_cst_u1") outcomes(1) frame(_cst_f1, replace)
    tempname R
    matrix `R' = r(rates)
    _cst_rows `R'
    assert r(nrows) == 4
    assert r(nbad) == 0
    assert r(nuniq) == 4
    * the e1_ prefix is kept and the stem ends on a whole character
    assert usubstr(`"`r(first)'"', 1, 3) == "e1_"
    assert ustrregexm(`"`r(first)'"', "^e1_Å+$")
    * the printed table keeps the full label (names are r() only)
    frame _cst_f1 {
        quietly count if inlist(strtrim(c1), "`a'1", "`a'2")
        assert r(N) == 4
    }
}
if _rc == 0 {
    display as result "  PASS: F1 r(rates) row names valid UTF-8 and unique (2-byte labels)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 r(rates) row names (rc=`=_rc')"
    local ++fail_count
}

**## three exposures with rateratio, 3-byte characters: r(ratios) names valid
local ++test_count
capture noisily {
    local a = 12 * "€"
    _cst_file "`w'/_cst_u3.dta" "x`a'1" "x`a'2" 10 20
    stratetab, using("`w'/_cst_u3" "`w'/_cst_u3" "`w'/_cst_u3") outcomes(1) rateratio
    tempname R Q
    matrix `R' = r(rates)
    matrix `Q' = r(ratios)
    _cst_rows `R'
    assert r(nrows) == 6 & r(nbad) == 0 & r(nuniq) == 6
    _cst_rows `Q'
    assert r(nrows) == 4 & r(nbad) == 0 & r(nuniq) == 4
    assert ustrregexm(`"`r(first)'"', "^e2_x€+$")
}
if _rc == 0 {
    display as result "  PASS: F1 r(rates)/r(ratios) row names valid UTF-8 and unique (3-byte labels)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 r(ratios) row names (rc=`=_rc')"
    local ++fail_count
}

**# F2 stratetab: -1 is refused, not read as "not given"

**## smallcells(-1) with a session default is refused; no file is written
local ++test_count
capture noisily {
    _cst_file "`w'/_cst_y1.dta" "A" "B" 2 20
    global TABTOOLS_set_smallcells 8
    capture erase "`w'/_cst_f2.csv"
    capture noisily stratetab, using("`w'/_cst_y1") outcomes(1) smallcells(-1) csv("`w'/_cst_f2.csv")
    local rc1 = _rc
    global TABTOOLS_set_smallcells
    assert `rc1' == 198
    capture confirm file "`w'/_cst_f2.csv"
    assert _rc == 601
    * the session default still applies when smallcells() is not given
    global TABTOOLS_set_smallcells 8
    stratetab, using("`w'/_cst_y1") outcomes(1) frame(_cst_f2, replace)
    global TABTOOLS_set_smallcells
    assert r(smallcells) == 8
    frame _cst_f2: quietly count if c2 == "<8"
    assert r(N) == 1
    * and smallcells(0) still means none
    global TABTOOLS_set_smallcells 8
    stratetab, using("`w'/_cst_y1") outcomes(1) smallcells(0) frame(_cst_f2, replace)
    global TABTOOLS_set_smallcells
    assert r(smallcells) == 0
    frame _cst_f2: quietly count if c2 == "2"
    assert r(N) == 1
}
global TABTOOLS_set_smallcells
if _rc == 0 {
    display as result "  PASS: F2 stratetab smallcells(-1) refused; session default and 0 unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 stratetab smallcells(-1) (rc=`=_rc')"
    local ++fail_count
}

**## digits(-1), fontsize(-1), level(-1) and non-integers are refused
local ++test_count
capture noisily {
    _cst_file "`w'/_cst_y1.dta" "A" "B" 2 20
    foreach o in "digits(-1)" "digits(1.5)" "digits(x)" "fontsize(-1)" "level(-1)" "level(.)" "smallcells(3.5)" {
        capture erase "`w'/_cst_f2b.csv"
        capture noisily stratetab, using("`w'/_cst_y1") outcomes(1) `o' csv("`w'/_cst_f2b.csv")
        if _rc != 198 {
            display as error "    `o' gave rc=`=_rc'"
            error 9
        }
        capture confirm file "`w'/_cst_f2b.csv"
        assert _rc == 601
    }
    * valid values still drive the printed cells
    stratetab, using("`w'/_cst_y1") outcomes(1) digits(3) frame(_cst_f2b, replace)
    frame _cst_f2b: quietly count if strpos(c4, "20.000 (") == 1
    assert r(N) == 1
    stratetab, using("`w'/_cst_y1") outcomes(1) digits(0) level(95) fontsize(12) ///
        xlsx("`w'/_cst_f2b.xlsx") sheet("s") frame(_cst_f2b, replace)
    assert r(ci_level) == 95
    frame _cst_f2b: quietly count if strpos(c4, "20 (") == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: F2 stratetab digits/fontsize/level -1 and non-integers refused; valid values print"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 stratetab sentinel refusals (rc=`=_rc')"
    local ++fail_count
}

**# F2 ratetab: the same sentinels

**## ratetab level(-1), smallcells(-1), digits(-1) are refused
local ++test_count
capture noisily {
    _cst_rt
    foreach o in "level(-1)" "smallcells(-1)" "digits(-1)" "digits(11)" "level(x)" {
        capture erase "`w'/_cst_r2.csv"
        capture noisily ratetab grp, events(ev) exposure(pt) `o' csv("`w'/_cst_r2.csv")
        if _rc != 198 {
            display as error "    `o' gave rc=`=_rc'"
            error 9
        }
        capture confirm file "`w'/_cst_r2.csv"
        assert _rc == 601
    }
    ratetab grp, events(ev) exposure(pt) level(90) digits(2) frame(_cst_r2, replace)
    assert r(level) == 90
    frame _cst_r2 {
        quietly count if strpos(c4, "(90% CI)") > 0
        assert r(N) == 1
        quietly count if ustrregexm(c4, "^[0-9]+\.[0-9][0-9] \(")
        assert r(N) >= 1
    }
}
if _rc == 0 {
    display as result "  PASS: F2 ratetab level/smallcells/digits -1 refused; level(90) digits(2) print"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 ratetab sentinel refusals (rc=`=_rc')"
    local ++fail_count
}

**# F3 ratetab threshold floor

**## smallcells(1|2) refused before the fit, with or without excludemasked
local ++test_count
capture noisily {
    _cst_rt
    foreach t in 1 2 {
        foreach x in "" "ci(cluster(id)) excludemasked" {
            capture erase "`w'/_cst_f3.csv"
            capture noisily ratetab grp, events(ev) exposure(pt) smallcells(`t') `x' csv("`w'/_cst_f3.csv")
            assert _rc == 198
            capture confirm file "`w'/_cst_f3.csv"
            assert _rc == 601
        }
    }
    * a session default of 2 is refused by the excludemasked guard
    global TABTOOLS_set_smallcells 2
    capture noisily ratetab grp, events(ev) exposure(pt) ci(cluster(id)) excludemasked
    local rc2 = _rc
    global TABTOOLS_set_smallcells
    assert `rc2' == 198
    * 3 with excludemasked runs and masks
    ratetab grp, events(ev) exposure(pt) smallcells(3) ci(cluster(id)) excludemasked ///
        frame(_cst_f3, replace)
    assert r(smallcells) == 3
    tempname E
    matrix `E' = r(estimates)
    local nmask 0
    forvalues i = 1/`=rowsof(`E')' {
        if `E'[`i', 4] >= 1 & `E'[`i', 4] < 3 local ++nmask
    }
    frame _cst_f3: quietly count if c2 == "<3"
    assert r(N) == `nmask'
}
global TABTOOLS_set_smallcells
if _rc == 0 {
    display as result "  PASS: F3 ratetab refuses smallcells(1|2) up front; excludemasked runs at 3"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 ratetab threshold floor (rc=`=_rc')"
    local ++fail_count
}

**## the refusal comes from ratetab, before any fit output
local ++test_count
capture noisily {
    _cst_rt
    capture log close _cst_m
    quietly log using "`w'/_cst_f3m.log", replace text name(_cst_m)
    capture noisily ratetab grp, events(ev) exposure(pt) smallcells(2) ci(cluster(id)) excludemasked
    local rc1 = _rc
    quietly log close _cst_m
    assert `rc1' == 198
    * explicit smallcells(2): refused before any fit-stage output
    tempname h
    local n_note 0
    local n_floor 0
    local n_exm 0
    file open `h' using "`w'/_cst_f3m.log", read text
    file read `h' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Note: person-time") local ++n_note
        if strpos(`"`macval(line)'"', "smallcells() must be 3 or more (0 = none)") local ++n_floor
        file read `h' line
    }
    file close `h'
    assert `n_note' == 0
    assert `n_floor' == 1
    * session default 2: refused by ratetab's excludemasked guard, naming 3
    quietly log using "`w'/_cst_f3m.log", replace text name(_cst_m)
    global TABTOOLS_set_smallcells 2
    capture noisily ratetab grp, events(ev) exposure(pt) ci(cluster(id)) excludemasked
    local rc2 = _rc
    global TABTOOLS_set_smallcells
    quietly log close _cst_m
    assert `rc2' == 198
    file open `h' using "`w'/_cst_f3m.log", read text
    file read `h' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "excludemasked requires a small-cell threshold of 3 or more") local ++n_exm
        file read `h' line
    }
    file close `h'
    assert `n_exm' == 1
}
local rcb = _rc
capture log close _cst_m
global TABTOOLS_set_smallcells
if `rcb' == 0 {
    display as result "  PASS: F3 ratetab refuses smallcells 2 before the fit; excludemasked guard names 3"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 ratetab refusal order (rc=`rcb')"
    local ++fail_count
}

**## ratetab.sthlp documents the floor of 3
local ++test_count
capture noisily {
    tempname h
    local hit3 0
    local hit2 0
    file open `h' using "`pkg_dir'/ratetab.sthlp", read text
    file read `h' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "threshold # of 3 or more") local hit3 1
        if strpos(`"`macval(line)'"', "threshold # of 2 or more") local hit2 1
        file read `h' line
    }
    file close `h'
    assert `hit3' == 1 & `hit2' == 0
}
if _rc == 0 {
    display as result "  PASS: F3 ratetab.sthlp says excludemasked needs 3 or more"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 ratetab.sthlp floor (rc=`=_rc')"
    local ++fail_count
}

**# F4 an empty smallcells() is refused (stratetab, ratetab, outtab)

**## smallcells() and smallcells( ) are r(198), with or without a session default; no file
local ++test_count
capture noisily {
    _cst_file "`w'/_cst_y1.dta" "A" "B" 2 20
    local _e ""
    foreach sess in "" "8" {
        global TABTOOLS_set_smallcells `sess'
        foreach o in "smallcells()" "smallcells( )" "smallc()" "smallcells(`_e')" {
            capture erase "`w'/_cst_f4.csv"
            capture noisily stratetab, using("`w'/_cst_y1") outcomes(1) `o' csv("`w'/_cst_f4.csv")
            local rc1 = _rc
            if `rc1' != 198 display as error "    stratetab `o' session [`sess']: rc=`rc1'"
            assert `rc1' == 198
            capture confirm file "`w'/_cst_f4.csv"
            assert _rc == 601
        }
        _cst_rt
        foreach o in "smallcells()" "smallcells( )" {
            capture erase "`w'/_cst_f4.csv"
            capture noisily ratetab grp, events(ev) exposure(pt) `o' csv("`w'/_cst_f4.csv")
            local rc1 = _rc
            if `rc1' != 198 display as error "    ratetab `o' session [`sess']: rc=`rc1'"
            assert `rc1' == 198
            capture confirm file "`w'/_cst_f4.csv"
            assert _rc == 601
        }
    }
    global TABTOOLS_set_smallcells
    * text inside another option is not the option; valid forms still work
    stratetab, using("`w'/_cst_y1") outcomes(1) title("smallcells() note") smallcells(3) frame(_cst_f4, replace)
    assert r(smallcells) == 3
    frame _cst_f4: quietly count if c2 == "<3"
    assert r(N) == 1
    _cst_rt
    ratetab grp, events(ev) exposure(pt) smallcells(5) frame(_cst_f4, replace)
    assert r(smallcells) == 5
}
global TABTOOLS_set_smallcells
if _rc == 0 {
    display as result "  PASS: F4 stratetab/ratetab empty smallcells() refused"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 stratetab/ratetab empty smallcells() (rc=`=_rc')"
    local ++fail_count
}

**## outtab: smallcells(-1) and an empty smallcells() are r(198); the session default still applies
local ++test_count
capture noisily {
    clear
    set seed 3
    quietly set obs 300
    gen byte e = runiform() < .5
    gen byte y = runiform() < .3 + .2*e
    global TABTOOLS_set_smallcells 5
    foreach o in "smallcells(-1)" "smallcells()" "smallcells( )" "smallcells(x)" {
        capture erase "`w'/_cst_f4o.csv"
        capture noisily outtab y, exposure(e) `o' csv("`w'/_cst_f4o.csv")
        local rc1 = _rc
        if `rc1' != 198 display as error "    outtab `o': rc=`rc1'"
        assert `rc1' == 198
        capture confirm file "`w'/_cst_f4o.csv"
        assert _rc == 601
    }
    outtab y, exposure(e) frame(_cst_f4o, replace)
    assert r(smallcells) == 5
    outtab y, exposure(e) smallcells(0) frame(_cst_f4o, replace)
    assert r(smallcells) == 0
    outtab y, exposure(e) smallcells(+7) frame(_cst_f4o, replace)
    assert r(smallcells) == 7
    global TABTOOLS_set_smallcells
}
global TABTOOLS_set_smallcells
if _rc == 0 {
    display as result "  PASS: F4 outtab smallcells(-1)/empty refused; session default and 0 unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 outtab smallcells sentinel (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _cst_f4
capture frame drop _cst_f4o

capture frame drop _cst_f1
capture frame drop _cst_f2
capture frame drop _cst_f2b
capture frame drop _cst_r2
capture frame drop _cst_f3

display as result "test_cycle_20261119_stratetab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_stratetab tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _cyc_st
