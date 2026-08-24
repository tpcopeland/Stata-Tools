* Seed: 26082430. 200 randomized 2x2 table oracles.
clear all
version 17.0
local pkg_dir "`c(pwd)'/.."
adopath ++ "`pkg_dir'"
set seed 26082430
local pass_count = 0
local fail_count = 0
local failed_reps ""
forvalues rep = 1/200 {
    capture noisily {
        clear
        set obs 61
        gen byte gold = runiform()<.45
        gen double score = runiform()
        gen byte pred = score >= .5
        quietly count if pred & gold
        local tp=r(N)
        quietly count if pred & !gold
        local fp=r(N)
        quietly count if !pred & gold
        local fn=r(N)
        quietly count if !pred & !gold
        local tn=r(N)
        diagtab score gold, cutoff(.5)
        assert r(TP)==`tp' & r(FP)==`fp' & r(FN)==`fn' & r(TN)==`tn'
        assert abs(r(sensitivity)-`tp'/(`tp'+`fn'))<1e-12 if `tp'+`fn'>0
    }
    if _rc {
        local ++fail_count
        local failed_reps "`failed_reps' `rep'"
    }
    else local ++pass_count
}
local test_count = `pass_count' + `fail_count'
display "RESULT: test_diagtab_oracle tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "FAILED reps:`failed_reps'"
    exit 1
}
