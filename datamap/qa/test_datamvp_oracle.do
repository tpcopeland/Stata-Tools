* Seed: 26082421. 200 randomized missing-pattern conservation checks.
clear all
version 16.0
local pkg_dir "`c(pwd)'/.."
adopath ++ "`pkg_dir'"
set seed 26082421
local pass_count = 0
local fail_count = 0
local failed_reps ""

forvalues rep = 1/200 {
    capture noisily {
        clear
        set obs 29
        gen double x = runiform()
        gen double y = runiform()
        replace x = . if runiform()<.3
        replace y = . if runiform()<.4
        gen byte want_complete = !missing(x,y)
        gen str12 _datamap_shadow = "keep_"+string(_n)
        quietly count if want_complete
        local wc = r(N)
        datamvp x y, summary
        assert r(N) == 29
        assert r(N_complete) == `wc'
        assert r(N_incomplete) == 29-`wc'
        assert r(N_complete)+r(N_incomplete)==r(N)
        assert _datamap_shadow == "keep_"+string(_n)
    }
    if _rc {
        local ++fail_count
        local failed_reps "`failed_reps' `rep'"
    }
    else local ++pass_count
}

local test_count = `pass_count' + `fail_count'
display "RESULT: test_datamvp_oracle tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "FAILED reps:`failed_reps'"
    exit 1
}
display as result "ALL TESTS PASSED"
