*! test_fvgen_oracle.do — Seeded factor-product oracle for fvgen
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+
* Seed: 26082403. 200 randomized factor-product checks over varied shapes.
clear all
version 16.0
do "`c(pwd)'/_fvgen_qa_common.do"
_fvgen_qa_bootstrap
set seed 26082403
local pass_count = 0
local fail_count = 0
local failed_reps ""
forvalues rep = 1/200 {
    capture noisily {
        * Shape varies by rep: 2-5 levels, level gaps of 1-3, and ~10%
        * missing in each source variable.
        local nl = 2 + mod(`rep', 4)
        local step = 1 + mod(`rep', 3)
        clear
        set obs 41
        gen byte arm = `step' * mod(_n, `nl')
        gen double age = runiform()*80
        replace arm = . if runiform() < 0.1
        replace age = . if runiform() < 0.1
        gen str12 _fvgen_shadow = "keep_" + string(_n)
        fvgen i.arm##c.age
        local k_main = r(k_main)
        quietly levelsof arm, local(lv)
        gettoken base lv : lv
        * non-base indicators plus the pass-through age main effect
        assert `k_main' == `: word count `lv'' + 1
        capture confirm variable _arm_`base'
        assert _rc == 111
        foreach L of local lv {
            assert _arm_`L' == (arm == `L') if !missing(arm)
            assert missing(_arm_`L') if missing(arm)
            assert _armXage_`L' == age*(arm == `L') if !missing(age, arm)
            assert missing(_armXage_`L') if missing(age, arm)
        }
        assert _fvgen_shadow == "keep_" + string(_n)
        fvgen, drop
        capture confirm variable _arm_`: word 1 of `lv''
        assert _rc != 0
    }
    if _rc {
        local ++fail_count
        local failed_reps "`failed_reps' `rep'"
    }
    else local ++pass_count
}
local test_count = `pass_count' + `fail_count'
display "RESULT: test_fvgen_oracle tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "FAILED reps:`failed_reps'"
    exit 1
}
