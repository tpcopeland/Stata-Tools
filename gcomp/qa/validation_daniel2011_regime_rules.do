* validation_daniel2011_regime_rules.do - Known-answer regime rules on tvc1
* Source: Daniel, De Stavola, and Cousens (2011), pp. 503-504.
* Extends the published threshold example to the paper's suggested rule:
* initiate treatment when L <= 6.2, then remain treated.
* Manual run: cd gcomp/qa && stata-mp -b do validation_daniel2011_regime_rules.do

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

tempfile persistent_saved instantaneous_saved

**# K1: Initiate below 6.2 and continue treatment

local ++test_count
capture noisily {
    use "`data_file'", clear
    gcomp y a l a_lag l_lag cuma cuma_lag id t, outcome(y) ///
        commands(y: logit, l: regress, a: logit) ///
        equations(y: l_lag cuma_lag, l: l_lag a_lag, a: l a_lag) ///
        idvar(id) tvar(t) varyingcovariates(l) intvars(a) ///
        interventions(a=0 if t<10 & l>6.2 & a_lag==0 \ ///
            a=1 if t<10 & (l<=6.2 | a_lag==1), a=0 if t<=9) ///
        dynamic pooled laggedvars(l_lag a_lag cuma_lag) ///
        lagrules(l_lag: l 1, a_lag: a 1, cuma_lag: cuma 1) ///
        derived(cuma) derrules(cuma: cuma_lag+a) ///
        simulations(1000) samples(2) seed(802) ///
        saving("`persistent_saved'") replace
    tempname persistent_b
    matrix `persistent_b' = e(b)
    local persistent_risk = `persistent_b'[1, colnumb(`persistent_b', "out1")]
    local persistent_never = `persistent_b'[1, colnumb(`persistent_b', "out2")]
    assert e(N_subjects) == 1000
    assert e(MC_sims) == 1000
}
if _rc == 0 {
    display as result "  PASS: K1 persistent-threshold command resolves"
    local ++pass_count
}
else {
    display as error "  FAIL: K1 persistent-threshold command (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K1"
    display "RESULT: validation_daniel2011_regime_rules tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}

**# K2: Saved persistent arm obeys the rule exactly

local ++test_count
capture noisily {
    use "`persistent_saved'", clear
    confirm variable _int _id t a a_lag l
    isid _int _id t
    bysort _int _id (t): assert a >= a[_n-1] if _int == 1 & _n > 1 & t < 10
    assert a == 1 if _int == 1 & t < 10 & a_lag == 1
    assert a == 1 if _int == 1 & t < 10 & a_lag == 0 & l <= 6.2
    assert a == 0 if _int == 1 & t < 10 & a_lag == 0 & l > 6.2
}
if _rc == 0 {
    display as result "  PASS: K2 saved persistent arm matches the paper's rule"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 saved persistent arm rule (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K2"
}

**# K3: The persistent-history checks are nonvacuous

local ++test_count
capture noisily {
    use "`persistent_saved'", clear
    quietly count if _int == 1 & t > 0 & t < 10 & a == 1 & a_lag == 0
    assert r(N) > 50
    quietly count if _int == 1 & t > 0 & t < 10 & a == 1 & a_lag == 1
    assert r(N) > 500
    quietly count if _int == 1 & t < 10 & a == 0 & a_lag == 0
    * The 6.2 rule initiates most simulated subjects early; require a real
    * untreated tail without fitting the threshold to a large arbitrary count.
    assert r(N) > 5
}
if _rc == 0 {
    display as result "  PASS: K3 initiation, persistence, and untreated histories occur"
    local ++pass_count
}
else {
    display as error "  FAIL: K3 regime-history nonvacuity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K3"
}

**# K4: The never-treat comparator is exact

local ++test_count
capture noisily {
    use "`persistent_saved'", clear
    assert a == 0 if _int == 2 & t < 10
    assert `persistent_risk' >= 0 & `persistent_risk' <= 1
    assert `persistent_never' >= 0 & `persistent_never' <= 1
    assert `persistent_risk' < `persistent_never'
}
if _rc == 0 {
    display as result "  PASS: K4 never-treat arm and beneficial direction are correct"
    local ++pass_count
}
else {
    display as error "  FAIL: K4 never-treat known answer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K4"
}

**# K5: Instantaneous threshold is a genuinely different regime

local ++test_count
capture noisily {
    use "`data_file'", clear
    gcomp y a l a_lag l_lag cuma cuma_lag id t, outcome(y) ///
        commands(y: logit, l: regress, a: logit) ///
        equations(y: l_lag cuma_lag, l: l_lag a_lag, a: l a_lag) ///
        idvar(id) tvar(t) varyingcovariates(l) intvars(a) ///
        interventions(a=0 if t<10 & l>6.2 \ a=1 if t<10 & l<=6.2, ///
            a=0 if t<=9) dynamic pooled ///
        laggedvars(l_lag a_lag cuma_lag) ///
        lagrules(l_lag: l 1, a_lag: a 1, cuma_lag: cuma 1) ///
        derived(cuma) derrules(cuma: cuma_lag+a) ///
        simulations(1000) samples(2) seed(802) ///
        saving("`instantaneous_saved'") replace
    tempname instantaneous_b
    matrix `instantaneous_b' = e(b)
    local instantaneous_risk = `instantaneous_b'[1, colnumb(`instantaneous_b', "out1")]
    local instantaneous_never = `instantaneous_b'[1, colnumb(`instantaneous_b', "out2")]
    assert `instantaneous_risk' >= 0 & `instantaneous_risk' <= 1
    assert `instantaneous_never' >= 0 & `instantaneous_never' <= 1
}
if _rc == 0 {
    display as result "  PASS: K5 instantaneous-threshold command resolves"
    local ++pass_count
}
else {
    display as error "  FAIL: K5 instantaneous-threshold command (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K5"
    display "RESULT: validation_daniel2011_regime_rules tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}

**# K6: Instantaneous saved arm follows current L and permits discontinuation

local ++test_count
capture noisily {
    use "`instantaneous_saved'", clear
    assert a == 1 if _int == 1 & t < 10 & l <= 6.2
    assert a == 0 if _int == 1 & t < 10 & l > 6.2
    bysort _int _id (t): gen byte _stopped = ///
        (_int == 1 & _n > 1 & t < 10 & a == 0 & a[_n-1] == 1)
    quietly count if _stopped
    assert r(N) > 50
}
if _rc == 0 {
    display as result "  PASS: K6 instantaneous arm follows L and can discontinue"
    local ++pass_count
}
else {
    display as error "  FAIL: K6 instantaneous saved-history rule (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K6"
}

**# K7: Regime contrast relationships are stable

local ++test_count
capture noisily {
    * Persistent initiation treats at least as much as an instantaneous rule.
    * Allow 0.03 for independent Monte Carlo streams across the two runs.
    assert `persistent_risk' <= `instantaneous_risk' + 0.03
    assert `instantaneous_risk' < `instantaneous_never'
    assert abs(`persistent_never' - `instantaneous_never') <= 0.04
    * Daniel et al. report 0.252 for the instantaneous 6.2 threshold.
    assert abs(`instantaneous_risk' - 0.252) <= 0.035
}
if _rc == 0 {
    display as result "  PASS: K7 persistent/instantaneous/never risks resolve correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: K7 regime contrast relationships (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K7"
}

display as result "Daniel 2011 regime-rule validation: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: validation_daniel2011_regime_rules tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    display as error "Failed checks:`failed_tests'"
    exit 1
}
display "RESULT: validation_daniel2011_regime_rules tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
