*! test_eplot_quiet.do - eplot prints nothing but its notes and errors
*! Representative calls in every mode are logged one at a time.  Apart from
*! the echoed command, every nonblank log line must be a deliberate
*! "(note: ...)" line: internal-command chatter ("(N real changes made)",
*! "(N missing values generated)", "variable x created", sort, preserve,
*! frame or merge messages, leaked tables) fails the suite.  Notes and
*! errors must stay visible.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_quiet.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Lines of a text log other than blanks, command echoes, and continuations.
mata:
string colvector _qt_output(string scalar fn)
{
    string colvector L, out
    real scalar i
    string scalar s

    L = cat(fn)
    out = J(0, 1, "")
    for (i = 1; i <= rows(L); i++) {
        s = strtrim(L[i])
        if (s == "") continue
        if (substr(s, 1, 2) == ". " | s == ".") continue
        if (substr(s, 1, 1) == ">") continue
        out = out \ s
    }
    return(out)
}
end

* Runs one eplot call under its own log; r(n_out) counts output lines,
* r(n_chatter) those that are not notes; QT_FIRST holds the first chatter.
capture program drop _qt_run
program define _qt_run, rclass
    version 16.0
    gettoken call 0 : 0
    tempfile lg
    quietly log using "`lg'", text replace name(_qt)
    capture noisily `call'
    local rc = _rc
    quietly log close _qt
    mata: _qt_o = _qt_output(st_local("lg"))
    mata: _qt_c = rows(_qt_o) ? select(_qt_o, substr(_qt_o, 1, 7) :!= "(note: ") : J(0, 1, "")
    mata: st_numscalar("r(n_out)", rows(_qt_o))
    mata: st_numscalar("r(n_chatter)", rows(_qt_c))
    mata: st_global("QT_FIRST", rows(_qt_c) ? _qt_c[1] : "")
    mata: st_global("QT_ALL", rows(_qt_o) ? invtokens(_qt_o', char(10)) : "")
    local n_out = r(n_out)
    local n_chatter = r(n_chatter)
    if `n_chatter' > 0 display as error `"chatter: $QT_FIRST"'
    return scalar n_out = `n_out'
    return scalar n_chatter = `n_chatter'
    return scalar rc = `rc'
end

**# 1. estimates mode: single model, groups, baselevels, values, rescale
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight i.foreign i.rep78
    _qt_run `"eplot ., values stars nodraw"'
    assert r(rc) == 0 & r(n_chatter) == 0
    _qt_run `"eplot ., baselevels drop(_cons) groups(mpg weight = "Size" 1.foreign 2.rep78 3.rep78 4.rep78 5.rep78 = "Other") gap(1) nodraw"'
    assert r(rc) == 0 & r(n_chatter) == 0
    _qt_run `"eplot ., rescale(10) favors("Lower" "Higher") headers(mpg = "Vehicle") cicap sigcolors sort nodraw"'
    assert r(rc) == 0 & r(n_chatter) == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 2. multi-model with export(); eform with its deliberate note
local ++test_count
capture noisily {
    sysuse auto, clear
    estimates clear
    quietly regress price mpg weight
    estimates store qa
    quietly regress price mpg
    estimates store qb
    capture frame drop qt_fx
    _qt_run `"eplot qa qb, modellabels("Full" "Small") drop(_cons) export(qt_fx) nodraw"'
    assert r(rc) == 0 & r(n_out) == 0
    frame drop qt_fx
    quietly logit foreign mpg weight
    _qt_run `"eplot ., eform logscale values xline(2) order(weight mpg) nodraw"'
    assert r(rc) == 0 & r(n_chatter) == 0
    * The constant-suppressed note is user-facing and must stay visible.
    assert r(n_out) == 1
    assert strpos(`"$QT_ALL"', "(note: constant suppressed with eform)") == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 3. data mode: pooled rows, weights, sort, prediction intervals, hetrow
local ++test_count
capture noisily {
    clear
    quietly input str20 study es lci uci weight byte type
    "Smith" -0.42 -0.78 -0.06 12.3 1
    "Jones" -0.31 -0.58 -0.04 16.8 1
    "Sub"    -0.30 -0.50 -0.10 . 3
    "Brown" -0.18 -0.41 0.05 21.5 1
    "Overall" -0.28 -0.41 -0.15 . 5
    end
    quietly gen double pl = lci - 0.1
    quietly gen double pu = uci + 0.1
    local nv = c(k)
    local nn = c(N)
    _qt_run `"eplot es lci uci, labels(study) weights(weight) type(type) values i2("42%") tau2("0.02") qstat("8.6") sort nodraw"'
    assert r(rc) == 0 & r(n_out) == 0
    capture frame drop qt_dx
    _qt_run `"eplot es lci uci, labels(study) type(type) eform values hetrow i2("40%") pi(pl pu) export(qt_dx) nodraw"'
    assert r(rc) == 0 & r(n_out) == 0
    frame drop qt_dx
    _qt_run `"eplot es lci uci if type == 1, labels(study) vertical cicap nodraw"'
    assert r(rc) == 0 & r(n_out) == 0
    * Nothing was added to or removed from the caller's data.
    assert c(k) == `nv' & c(N) == `nn'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 4. matrix and frame modes
local ++test_count
capture noisily {
    matrix QT = (0.4, 0.1 \ -0.2, 0.15 \ 0.1, 0.05)
    matrix rownames QT = "Treatment A" "Treatment B" "Treatment C"
    _qt_run `"eplot, matrix(QT) stars values eform nodraw"'
    assert r(rc) == 0 & r(n_out) == 0
    clear
    quietly input str20 label double(estimate ll ul pvalue) str10 rowtype
    "Age"      1.12 1.04 1.20 0.004 "effect"
    "Sex"      0.86 0.70 1.06 0.150 "effect"
    "Overall"  1.03 0.97 1.10 0.320 "overall"
    end
    capture frame drop qt_eff
    frame put label estimate ll ul pvalue rowtype, into(qt_eff)
    _qt_run `"eplot, frame(qt_eff) values stars logscale nodraw"'
    assert r(rc) == 0 & r(n_out) == 0
    frame drop qt_eff
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 5. errors stay visible: the message is printed, and only the message
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    _qt_run `"eplot ., keep(nosuch) nodraw"'
    assert r(rc) == 198
    assert !missing(r(n_out)) & r(n_out) >= 1
    assert strpos(`"$QT_ALL"', "keep() did not match: nosuch") > 0
    * The batch log adds the r(198) line; nothing else is printed.
    assert r(n_chatter) <= 2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 6. the detector is not blind: internal-command chatter is caught
local ++test_count
capture noisily {
    sysuse auto, clear
    _qt_run `"generate double qt_x = cond(foreign, ., 1)"'
    assert r(rc) == 0 & r(n_chatter) == 1
    assert strpos(`"$QT_FIRST"', "missing values generated") > 0
    _qt_run `"replace qt_x = 2 if foreign"'
    assert r(n_chatter) == 1
    assert strpos(`"$QT_FIRST"', "real changes made") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

macro drop QT_FIRST QT_ALL
capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_quiet, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
