* validation_kmplot_recovery.do
* Published known-answer and known-truth recovery validation for kmplot
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-08-11

clear all
version 16.0
set varabbrev off

**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Published known answer
**## V1: Kaplan and Meier (1958), Table 464

local ++test_count
capture noisily {
    clear
    input double time byte died
        0.8  1
        1.0  0
        2.7  0
        3.1  1
        5.4  1
        7.0  0
        9.2  1
       12.1  0
    end
    stset time, failure(died)

    tempfile curve
    kmplot, saving("`curve'", replace) name(recovery_v1, replace)
    use "`curve'", clear
    keep if anchor == 0

    quietly summarize estimate if abs(time - 0.8) < 1e-10, meanonly
    assert abs(r(mean) - 7 / 8) < 1e-12
    quietly summarize estimate if abs(time - 3.1) < 1e-10, meanonly
    assert abs(r(mean) - 7 / 10) < 1e-12
    quietly summarize estimate if abs(time - 5.4) < 1e-10, meanonly
    assert abs(r(mean) - 21 / 40) < 1e-12
    quietly summarize estimate if abs(time - 9.2) < 1e-10, meanonly
    assert abs(r(mean) - 21 / 80) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: V1 Published product-limit values reproduced"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 Published product-limit values (rc=`=_rc')"
    local ++fail_count
}

**# Known-truth recovery
**## V2: Exponential survival under independent censoring, two seeds

local ++test_count
capture noisily {
    foreach seed in 314159 271828 {
        clear
        set seed `seed'
        set obs 100000
        local lambda = 0.18
        local mu = 0.10
        local horizon = 4
        local truth = exp(-`lambda' * `horizon')
        local mcse = `truth' * sqrt((`lambda' / (`lambda' + `mu')) * ///
            (exp((`lambda' + `mu') * `horizon') - 1) / _N)

        generate double event_time = -ln(runiform()) / `lambda'
        generate double censor_time = -ln(runiform()) / `mu'
        generate double observed_time = min(event_time, censor_time)
        generate byte died = event_time <= censor_time
        generate byte naive_survival = observed_time > `horizon'
        quietly summarize naive_survival, meanonly
        local naive = r(mean)
        assert abs(`naive' - `truth') > 0.10

        stset observed_time, failure(died)
        kmplot, landmark(`horizon') name(recovery_exp_`seed', replace)
        matrix L = r(landmarks)
        display as text "RECOVERY: exponential seed=`seed' truth=`truth' estimate=" ///
            L[1,3] " naive=`naive' mcse=`mcse'"
        assert abs(L[1,3] - `truth') < 5 * `mcse'
    }
}
if _rc == 0 {
    display as result "  PASS: V2 Exponential survival recovered under censoring"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 Exponential recovery (rc=`=_rc')"
    local ++fail_count
}

**## V3: Increasing-hazard Weibull survival, two seeds and large N

local ++test_count
capture noisily {
    foreach seed in 161803 141421 {
        clear
        set seed `seed'
        set obs 150000
        local lambda = 0.15
        local mu = 0.04
        local horizon = 2
        local truth = exp(-`lambda' * `horizon'^2)
        local censor_survival = exp(-`mu' * `horizon')
        local mcse = sqrt(`truth' * (1 - `truth') / ///
            (_N * `censor_survival'))

        generate double event_time = sqrt(-ln(runiform()) / `lambda')
        generate double censor_time = -ln(runiform()) / `mu'
        generate double observed_time = min(event_time, censor_time)
        generate byte died = event_time <= censor_time
        generate byte naive_survival = observed_time > `horizon'
        quietly summarize naive_survival, meanonly
        local naive = r(mean)
        assert abs(`naive' - `truth') > 0.04

        stset observed_time, failure(died)
        kmplot, landmark(`horizon') name(recovery_weibull_`seed', replace)
        matrix L = r(landmarks)
        display as text "RECOVERY: weibull seed=`seed' truth=`truth' estimate=" ///
            L[1,3] " naive=`naive' mcse=`mcse'"
        assert abs(L[1,3] - `truth') < 5 * `mcse'
    }
}
if _rc == 0 {
    display as result "  PASS: V3 Weibull survival recovered under censoring"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 Weibull recovery (rc=`=_rc')"
    local ++fail_count
}

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: validation_kmplot_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: validation_kmplot_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
