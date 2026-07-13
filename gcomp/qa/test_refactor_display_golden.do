* test_refactor_display_golden.do - S4 lightweight display snapshot guard
* Coverage: representative gcomp mediation output headers/labels and obvious
*           error absence in a generated text log.

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local testdir "`c(tmpdir)'"

tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local snaplog "`testdir'/gcomp_s4_display_`install_tag'.log"

do "`qa_dir'/_qa_bootstrap.do"

capture program drop _s4_log_check
program define _s4_log_check
    version 16.0
    syntax anything(name=path), Needle(string) [Absent]

    tempname fh
    local path = subinstr(`"`path'"', `"""', "", .)
    local found = 0
    file open `fh' using "`path'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`needle'"') > 0 {
            local found = 1
        }
        file read `fh' line
    }
    file close `fh'

    if "`absent'" != "" {
        assert `found' == 0
    }
    else {
        assert `found' == 1
    }
end

**# Synthetic mediation setup
clear
set seed 202605154
set obs 220
gen double c = rnormal()
gen byte x = rbinomial(1, invlogit(-0.40 + 0.35 * c))
gen byte m = rbinomial(1, invlogit(-0.80 + 0.75 * x + 0.25 * c))
gen byte y = rbinomial(1, invlogit(-1.20 + 0.55 * m + 0.35 * x + 0.20 * c))
tempfile s4_data
save `s4_data'

**# S4: key display headers and labels remain stable
local ++test_count
capture noisily {
    capture erase "`snaplog'"
    use `s4_data', clear

    log using "`snaplog'", text replace name(s4snapshot)
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) control(1) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(4) seed(202605154)
    log close s4snapshot

    confirm file "`snaplog'"
    _s4_log_check "`snaplog'", needle("G-computation procedure using Monte Carlo simulation: mediation")
    _s4_log_check "`snaplog'", needle("Outcome variable: y")
    _s4_log_check "`snaplog'", needle("Exposure variable(s): x")
    _s4_log_check "`snaplog'", needle("Mediator variable(s): m")
    _s4_log_check "`snaplog'", needle("A summary of the specified parametric models")
    _s4_log_check "`snaplog'", needle("Estimating direct/indirect effects")
    _s4_log_check "`snaplog'", needle("G-computation formula estimates of the total causal effect")
    _s4_log_check "`snaplog'", needle("and the controlled direct effect")
    _s4_log_check "`snaplog'", needle("Control value(s):")
    _s4_log_check "`snaplog'", needle("TCE")
    _s4_log_check "`snaplog'", needle("NDE")
    _s4_log_check "`snaplog'", needle("NIE")
    _s4_log_check "`snaplog'", needle("PM")
    _s4_log_check "`snaplog'", needle("CDE")
    _s4_log_check "`snaplog'", needle("r(111)") absent
    _s4_log_check "`snaplog'", needle("r(198)") absent
    _s4_log_check "`snaplog'", needle("r(601)") absent
    _s4_log_check "`snaplog'", needle("invalid syntax") absent
    _s4_log_check "`snaplog'", needle("not found") absent
}
if _rc == 0 {
    display as result "  PASS: S4 display snapshot contains required headers and labels"
    local ++pass_count
}
else {
    capture log close s4snapshot
    display as error "  FAIL: S4 display snapshot guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S4"
}

capture erase "`snaplog'"

display ""
display as result "test_refactor_display_golden Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: test_refactor_display_golden tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    display as error "FAIL"
}
else {
    display "RESULT: test_refactor_display_golden tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    display as result "PASS"
}

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
