*! test_eplot_v171.do - Regression tests for eplot 1.7.1
*! msymbol() is validated as the color options are: outside multi-model
*! estimates mode a list of symbols exits 198 (data, frame, single-model
*! estimates, matrix), an unknown or miscased symbol name exits 198 in every
*! mode including multi-model lists, an empty msymbol() exits 198, and every
*! [G-4] symbolstyle synonym and named style is still accepted and drawn as
*! given.  The help file carries a References section citing the four Stata
*! manual entries whose rules estimates mode follows.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_v171.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

**# m2: msymbol() validation
**## 1. a symbol list outside multi-model estimates mode exits 198, every mode
local ++test_count
capture noisily {
    * Data mode
    clear
    input str5 lab es lo hi
    "A" 1 .5 1.5
    "B" 2 1 3
    end
    capture eplot es lo hi, labels(lab) msymbol(O D) nodraw
    assert _rc == 198
    * Frame mode
    capture frame drop v171_fr
    frame put lab es lo hi, into(v171_fr)
    frame v171_fr {
        rename (es lo hi) (estimate ll ul)
    }
    capture eplot, frame(v171_fr) msymbol(O D) nodraw
    assert _rc == 198
    frame drop v171_fr
    * Single-model estimates mode, named and active
    sysuse auto, clear
    estimates clear
    quietly regress price mpg weight
    estimates store m1
    capture eplot m1, drop(_cons) msymbol(O D) nodraw
    assert _rc == 198
    capture eplot ., drop(_cons) msymbol(O D) nodraw
    assert _rc == 198
    * Matrix mode
    matrix V171 = (1, .5, 1.5 \ 2, 1, 3)
    matrix rownames V171 = x y
    capture eplot, matrix(V171) msymbol(O D) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 2. an unknown, miscased, or modified symbol name exits 198, every mode
local ++test_count
capture noisily {
    clear
    input str5 lab es lo hi
    "A" 1 .5 1.5
    "B" 2 1 3
    end
    foreach s in foo CIRCLE O*2 = . {
        capture eplot es lo hi, labels(lab) msymbol(`s') nodraw
        assert _rc == 198
    }
    capture frame drop v171_fr
    frame put lab es lo hi, into(v171_fr)
    frame v171_fr {
        rename (es lo hi) (estimate ll ul)
    }
    capture eplot, frame(v171_fr) msymbol(bogus) nodraw
    assert _rc == 198
    frame drop v171_fr
    sysuse auto, clear
    estimates clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg weight foreign
    estimates store m2
    quietly regress price mpg
    estimates store m3
    capture eplot ., drop(_cons) msymbol(foo) nodraw
    assert _rc == 198
    * Multi-model: right count, one unknown name
    capture eplot m1 m2 m3, drop(_cons) msymbol(O Dh foo) nodraw
    assert _rc == 198
    * Multi-model: one unknown symbol for every model
    capture eplot m1 m2, drop(_cons) msymbol(nosuch) nodraw
    assert _rc == 198
    * An explicit unknown name is refused under a style() preset too.
    capture eplot m1 m2, drop(_cons) style(lancet) msymbol(D foo) nodraw
    assert _rc == 198
    matrix V171 = (1, .5, 1.5 \ 2, 1, 3)
    matrix rownames V171 = x y
    capture eplot, matrix(V171) msymbol(nope) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 3. an empty msymbol() exits 198 instead of drawing the scheme default
local ++test_count
capture noisily {
    sysuse auto, clear
    estimates clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg
    estimates store m2
    capture eplot ., drop(_cons) msymbol(" ") nodraw
    assert _rc == 198
    capture eplot m1 m2, drop(_cons) msymbol(" ") nodraw
    assert _rc == 198
    clear
    input str5 lab es lo hi
    "A" 1 .5 1.5
    end
    capture eplot es lo hi, labels(lab) msymbol(" ") nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 4. every [G-4] symbolstyle synonym and named styles are drawn as given
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    * The synonym table of [G-4] symbolstyle plus named styles.
    local good O D T S + X A a | V o d s t x v Oh Dh Th Sh oh dh th sh p i
    local good `good' circle circle_hollow smx smplus point none diamond_hollow
    foreach s of local good {
        eplot ., drop(_cons) msymbol(`s') nodraw
        local c `"`r(cmd)'"'
        local want "_rowtype == 1, msymbol(`s') "
        assert strpos(`"`c'"', "`want'") > 0
    }
    clear
    input str5 lab es lo hi
    "A" 1 .5 1.5
    "B" 2 1 3
    end
    eplot es lo hi, labels(lab) msymbol(Dh) nodraw
    assert strpos(`"`r(cmd)'"', "msymbol(Dh)") > 0
    matrix V171 = (1, .5, 1.5 \ 2, 1, 3)
    matrix rownames V171 = x y
    eplot, matrix(V171) msymbol(smcircle_hollow) nodraw
    assert strpos(`"`r(cmd)'"', "msymbol(smcircle_hollow)") > 0
    * Multi-model per-model list still drawn in model order.
    sysuse auto, clear
    estimates clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg
    estimates store m2
    eplot m1 m2, drop(_cons) msymbol(Oh triangle) nodraw
    local c `"`r(cmd)'"'
    assert strpos(`"`c'"', "model_id == 1 & _rowtype == 1, msymbol(Oh)") > 0
    assert strpos(`"`c'"', "model_id == 2 & _rowtype == 1, msymbol(triangle)") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 5. a refused msymbol() leaves varabbrev and r() state as found
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    quietly regress price mpg weight
    capture eplot ., drop(_cons) msymbol(foo) nodraw
    assert _rc == 198
    assert c(varabbrev) == "on"
    capture eplot ., drop(_cons) msymbol(O D) nodraw
    assert _rc == 198
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 local ++pass_count
else {
    set varabbrev off
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# I1: References section in the help file
**## 6. the shipped eplot.sthlp cites the four manual entries
local ++test_count
capture noisily {
    * The shipped help file (the one the .pkg f-line installs).
    local hf `"`pkg_dir'/eplot.sthlp"'
    confirm file `"`hf'"'
    * Needles travel in globals and the file is read in Mata, so neither
    * the help text nor the needle is ever macro-expanded.
    global V171_HF `"`hf'"'
    local needles `""{title:References}" "[P] ereturn" "[ME] mixed" "[MI] mi estimate" "[R] ml""'
    local needles `"`needles' "stata.com/manuals/pereturn.pdf" "stata.com/manuals/memixed.pdf""'
    local needles `"`needles' "stata.com/manuals/mimiestimate.pdf" "stata.com/manuals/rml.pdf""'
    local needles `"`needles' "{cmd:e(df_r)}" "{cmd:e(V_df)}" "{cmd:e(df_mi)}" "{cmd:e(k_eform)}""'
    foreach e of local needles {
        global V171_NEEDLE `"`e'"'
        mata: st_numscalar("r(pos)", strpos(invtokens(cat(st_global("V171_HF"))', char(10)), st_global("V171_NEEDLE")))
        assert r(pos) > 0 & !missing(r(pos))
    }
    * References precede Author.
    mata: st_numscalar("r(ok)", strpos(invtokens(cat(st_global("V171_HF"))', char(10)), "{title:References}") < strpos(invtokens(cat(st_global("V171_HF"))', char(10)), "{title:Author}"))
    assert r(ok) == 1
    macro drop V171_HF V171_NEEDLE
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v171, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
