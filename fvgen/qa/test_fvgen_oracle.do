* Seed: 26082403. 200 randomized factor-product checks.
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
        clear
        set obs 41
        gen byte arm = mod(_n, 2)
        gen double age = runiform()*80
        gen str12 _fvgen_shadow = "keep_" + string(_n)
        fvgen i.arm##c.age
        assert _arm_1 == (arm == 1) if !missing(arm)
        assert _armXage_1 == age*(arm == 1) if !missing(age, arm)
        assert _fvgen_shadow == "keep_" + string(_n)
        fvgen, drop
        capture confirm variable _arm_1
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
