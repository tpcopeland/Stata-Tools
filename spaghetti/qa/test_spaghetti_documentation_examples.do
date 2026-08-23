* Literal safe examples from spaghetti.sthlp.

version 16.0
clear all
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall spaghetti
quietly net install spaghetti, from("`pkg_dir'") replace

local tests = 0
local pass = 0
local fail = 0

**# Basic, grouped, sampled, and highlighted help examples
foreach options in ///
    "" ///
    "by(race) mean(bold ci)" ///
    "sample(100) seed(12345) mean(bold)" ///
    "highlight(idcode==1 | idcode==2)" {
    local ++tests
    capture noisily {
        webuse nlswork, clear
        spaghetti ln_wage, id(idcode) time(year) `options'
        assert !missing(r(N))
        assert r(N) == _N
        assert !missing(r(n_ids))
        assert r(n_ids) > 0
    }
    if _rc == 0 local ++pass
    else local ++fail
}

**# Reference-line and styling help examples retain a populated graph contract
local ++tests
capture noisily {
    webuse nlswork, clear
    spaghetti ln_wage, id(idcode) time(year) sample(50) refline(80, label("Policy change") style(dash))
    assert r(n_sampled) == 50
    webuse nlswork, clear
    spaghetti ln_wage, id(idcode) time(year) by(race) individual(color(gs12) opacity(10) lwidth(vthin)) mean(bold ci) colors(navy cranberry)
    assert r(n_groups) == 3
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_spaghetti_documentation_examples tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
