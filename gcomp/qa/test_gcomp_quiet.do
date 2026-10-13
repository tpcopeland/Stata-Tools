*! gcomp / gcomptab console hygiene: no Mata source echo on first use, and no
*! internal table-building notes in the Results window.
version 16.0
clear all
set more off

local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"

local tests = 0
local pass = 0
local fail = 0

capture program drop _gq_leaks
program define _gq_leaks, rclass
    args file
    tempname fh
    local n = 0
    local first ""
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local t = `"`macval(line)'"'
        if regexm(`"`t'"', "real changes? made|missing values generated|Number of observations \(_N\)|^file .* saved|not found\)|mata \(type end to exit\)|^> *void |^: *void ") {
            local ++n
            if `"`first'"' == "" local first `"`t'"'
        }
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
    return local first `"`first'"'
end

local tmp "`c(tmpdir)'"

**# 1. first use of the intervention parser does not echo Mata source
local ++tests
capture noisily {
    capture program drop _gcomp_split_interventions
    capture mata: mata drop _gcomp_split_arm_locals()
    local lg "`tmp'/gq_mata.log"
    quietly log using "`lg'", text replace name(gqm)
    _gcomp_split_interventions, text("A=1, A=0") prefix(_gq_)
    quietly log close gqm
    assert "`_gq_n'" == "2"
    _gq_leaks "`lg'"
    assert r(n) == 0
    capture erase "`lg'"
}
if _rc == 0 local ++pass
else {
    capture log close gqm
    display as error "FAIL: Mata source echoed on first use"
    local ++fail
}

**# 2. gcomptab mediation, dose-response and models print no internal notes
local ++tests
capture noisily {
    clear
    set seed 12345
    set obs 400
    generate double c = rnormal()
    generate byte x = rbinomial(1, invlogit(.2*c))
    generate double m = .6*x + .3*c + rnormal()
    generate double y = .7*m + .4*x + .2*c + rnormal()
    quietly gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: regress, y: regress) equations(m: x c, y: m x c) ///
        base_confs(c) simulations(200) samples(5) seed(42) savemodels
    local lg "`tmp'/gq_tab.log"
    * fresh output files for every mode (existing files change what is printed)
    local xl "`tmp'/gq_med.xlsx"
    local md "`tmp'/gq_med.md"
    local csv "`tmp'/gq_med.csv"
    local xl2 "`tmp'/gq_mod.xlsx"
    local md2 "`tmp'/gq_mod.md"
    local csv2 "`tmp'/gq_mod.csv"
    local md3 "`tmp'/gq_mod3.md"
    local csv3 "`tmp'/gq_mod3.csv"
    foreach f in xl md csv xl2 md2 csv2 md3 csv3 {
        capture erase "``f''"
    }
    quietly log using "`lg'", text replace name(gqt)
    gcomptab, xlsx("`xl'") sheet("Normal CI") title("Mediation effects") markdown("`md'") csv("`csv'")
    gcomptab, models xlsx("`xl2'") sheet("Models") title("Models") markdown("`md2'") csv("`csv2'") stats(n)
    gcomptab, models markdown("`md3'") csv("`csv3'")
    gcomptab, models display compact
    quietly log close gqt
    _gq_leaks "`lg'"
    if r(n) display as error "leaked: `r(first)'"
    assert r(n) == 0
    * the real notes remain
    foreach f in xl md csv xl2 md2 csv2 md3 csv3 {
        confirm file "``f''"
        capture erase "``f''"
    }
    capture erase "`lg'"
}
if _rc == 0 local ++pass
else {
    capture log close gqt
    display as error "FAIL: gcomptab internal notes in Results window"
    local ++fail
}

**# 3. gcomptab, doseresponse prints no internal notes but keeps its export note
local ++tests
capture noisily {
    clear
    set seed 54321
    set obs 600
    generate long id = ceil(_n/3)
    bysort id: generate int time = 2*_n - 1
    generate double L = rnormal() + .1*time
    generate byte A = rbinomial(1, invlogit(-.8 + .2*L))
    generate byte Y = rbinomial(1, invlogit(-1 + .4*A + .2*L))
    quietly gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
        intvars(A) interventions(A=1, A=0) commands(L: regress, A: logit, Y: logit) ///
        equations(L: time, A: L time, Y: A L time) eofu pooled ///
        simulations(100) samples(5) seed(12345)
    local lg "`tmp'/gq_dr.log"
    local xl "`tmp'/gq_dr.xlsx"
    local md "`tmp'/gq_dr.md"
    capture erase "`xl'"
    capture erase "`md'"
    quietly log using "`lg'", text replace name(gqd)
    gcomptab, doseresponse xlsx("`xl'") sheet("Dose response") ///
        strategylabels("Always A=1 \ Never A=0 \ Observed regime") ///
        expyears(5 0 2) reference(1) effect("Risk") markdown("`md'")
    quietly log close gqd
    _gq_leaks "`lg'"
    if r(n) display as error "leaked: `r(first)'"
    assert r(n) == 0
    tempname fh
    local found = 0
    file open `fh' using "`lg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Markdown table written to") local found = 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
    capture erase "`lg'"
    capture erase "`xl'"
    capture erase "`md'"
}
if _rc == 0 local ++pass
else {
    capture log close gqd
    display as error "FAIL: gcomptab doseresponse notes"
    local ++fail
}

if `fail' > 0 {
    display "RESULT: test_gcomp_quiet tests=`tests' pass=`pass' fail=`fail' status=FAIL"
    exit 1
}
display "RESULT: test_gcomp_quiet tests=`tests' pass=`pass' fail=`fail' status=PASS"
