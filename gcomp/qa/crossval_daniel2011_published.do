* crossval_daniel2011_published.do - Published-example replication for gcomp
* Source: Daniel, De Stavola, and Cousens (2011), Stata Journal 11:479-517,
* pp. 503-507. Public fixture: Stata Journal st0238/tvc1.dta.
* Fixture SHA-256: 14341aa076691bb2ba8b2f36b40543b1edad1a89a6708a46ce6be884fa38c5f5
* Manual run: cd gcomp/qa && stata-mp -b do crossval_daniel2011_published.do

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local data_file "`qa_dir'/data/daniel2011_tvc1.dta"
do "`qa_dir'/_qa_bootstrap.do"

**# D1: The vendored public fixture is the study dataset

local ++test_count
capture noisily {
    use "`data_file'", clear
    isid id t
    tempvar subject
    egen byte `subject' = tag(id)
    quietly count if `subject'
    assert r(N) == 1000
    quietly count if y == 1
    assert r(N) == 519
    quietly summarize t, meanonly
    assert r(min) == 0
    assert r(max) == 10
}
if _rc == 0 {
    display as result "  PASS: D1 public tvc1 fixture identity"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 public tvc1 fixture identity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D1"
}

**# P1: Published six-regime static example

local ++test_count
capture noisily {
    use "`data_file'", clear
    gcomp y a l a_lag l_lag cuma cuma_lag id t, outcome(y) ///
        commands(y: logit, l: regress, a: logit) ///
        equations(y: l_lag cuma_lag, l: l_lag a_lag, a: l a_lag) ///
        idvar(id) tvar(t) varyingcovariates(l) intvars(a) ///
        interventions(a=1 if t<10, ///
            a=0 if t<=1 \ a=1 if t>1 & t<10, ///
            a=0 if t<=3 \ a=1 if t>3 & t<10, ///
            a=0 if t<=5 \ a=1 if t>5 & t<10, ///
            a=0 if t<=7 \ a=1 if t>7 & t<10, ///
            a=0 if t<=9) pooled ///
        laggedvars(l_lag a_lag cuma_lag) ///
        lagrules(l_lag: l 1, a_lag: a 1, cuma_lag: cuma 1) ///
        msm(stcox cuma_lag) derived(cuma) derrules(cuma: cuma_lag+a) ///
        simulations(1000) samples(2) seed(79)
    tempname static_b
    matrix `static_b' = e(b)
    assert colsof(`static_b') == 15
}
if _rc == 0 {
    display as result "  PASS: P1 published static command resolves"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 published static command (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P1_command"
    display "RESULT: crossval_daniel2011_published tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}

* Published point estimates. Tolerances cover the documented Monte Carlo
* approximation and Stata RNG/maintained-fork differences, not sampling error.
foreach check in ///
    "cuma_lag -0.4620501 0.030" ///
    "PO1 -3.710399 0.100" "PO2 -2.849232 0.100" ///
    "PO3 -2.409732 0.100" "PO4 -2.155157 0.100" ///
    "PO5 -1.992489 0.100" "PO6 -2.010118 0.100" ///
    "PO7 -2.693125 0.100" ///
    "out1 0.208 0.035" "out2 0.408 0.035" ///
    "out3 0.565 0.035" "out4 0.677 0.035" ///
    "out5 0.770 0.035" "out6 0.782 0.035" ///
    "out7 0.486 0.035" {

    gettoken metric rest : check
    gettoken expected tolerance : rest
    local col = colnumb(`static_b', "`metric'")
    local actual = `static_b'[1, `col']
    local ++test_count
    capture noisily assert abs(`actual' - `expected') <= `tolerance'
    if _rc == 0 {
        display as result "  PASS: P1 `metric' published=" %10.7f `expected' ///
            " gcomp=" %10.7f `actual'
        local ++pass_count
    }
    else {
        display as error "  FAIL: P1 `metric' published=" %10.7f `expected' ///
            " gcomp=" %10.7f `actual' " tolerance=" %8.5f `tolerance'
        local ++fail_count
        local failed_tests "`failed_tests' P1_`metric'"
    }
}

**# P2: Published five-threshold dynamic example

local ++test_count
capture noisily {
    use "`data_file'", clear
    gcomp y a l a_lag l_lag cuma cuma_lag id t, outcome(y) ///
        commands(y: logit, l: regress, a: logit) ///
        equations(y: l_lag cuma_lag, l: l_lag a_lag, a: l a_lag) ///
        idvar(id) tvar(t) varyingcovariates(l) intvars(a) ///
        interventions(a=0 if t<10 & l>6.9 \ a=1 if t<10 & l<=6.9, ///
            a=0 if t<10 & l>6.55 \ a=1 if t<10 & l<=6.55, ///
            a=0 if t<10 & l>6.2 \ a=1 if t<10 & l<=6.2, ///
            a=0 if t<10 & l>5.3 \ a=1 if t<10 & l<=5.3, ///
            a=0 if t<10 & l>4.6 \ a=1 if t<10 & l<=4.6) ///
        dynamic pooled laggedvars(l_lag a_lag cuma_lag) ///
        lagrules(l_lag: l 1, a_lag: a 1, cuma_lag: cuma 1) ///
        derived(cuma) derrules(cuma: cuma_lag+a) ///
        simulations(1000) samples(2) seed(801)
    tempname dynamic_b
    matrix `dynamic_b' = e(b)
    assert colsof(`dynamic_b') == 12
}
if _rc == 0 {
    display as result "  PASS: P2 published dynamic command resolves"
    local ++pass_count
}
else {
    display as error "  FAIL: P2 published dynamic command (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P2_command"
    display "RESULT: crossval_daniel2011_published tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}

foreach check in ///
    "PO1 -3.751415 0.100" "PO2 -3.568099 0.100" ///
    "PO3 -3.506201 0.100" "PO4 -2.795603 0.100" ///
    "PO5 -2.322542 0.100" "PO6 -2.719811 0.100" ///
    "out1 0.203 0.035" "out2 0.236 0.035" ///
    "out3 0.252 0.035" "out4 0.451 0.035" ///
    "out5 0.635 0.035" "out6 0.479 0.035" {

    gettoken metric rest : check
    gettoken expected tolerance : rest
    local col = colnumb(`dynamic_b', "`metric'")
    local actual = `dynamic_b'[1, `col']
    local ++test_count
    capture noisily assert abs(`actual' - `expected') <= `tolerance'
    if _rc == 0 {
        display as result "  PASS: P2 `metric' published=" %10.7f `expected' ///
            " gcomp=" %10.7f `actual'
        local ++pass_count
    }
    else {
        display as error "  FAIL: P2 `metric' published=" %10.7f `expected' ///
            " gcomp=" %10.7f `actual' " tolerance=" %8.5f `tolerance'
        local ++fail_count
        local failed_tests "`failed_tests' P2_`metric'"
    }
}

display as result "Daniel 2011 published replication: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: crossval_daniel2011_published tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    display as error "Failed checks:`failed_tests'"
    exit 1
}
display "RESULT: crossval_daniel2011_published tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"

