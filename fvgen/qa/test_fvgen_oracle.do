* Seed: 26082403. 200 randomized factor-product checks.
clear all
version 16.0
do "`c(pwd)'/_fvgen_qa_common.do"
_fvgen_qa_bootstrap
set seed 26082403
forvalues rep = 1/200 {
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
display as result "RESULT: PASS fvgen randomized oracle (200 reps)"
