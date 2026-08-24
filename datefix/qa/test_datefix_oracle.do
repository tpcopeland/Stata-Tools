* Randomized oracle for datefix. Seed: 26082302. 200 repetitions.
clear all
set more off
version 16.0

quietly do "`c(pwd)'/_datefix_qa_common.do"
_datefix_qa_bootstrap
set seed 26082302
local pass_count = 0
local fail_count = 0
local failed_reps ""

forvalues rep = 1/200 {
    capture noisily {
        clear
        set obs 29
        gen int yy = 1960 + floor(runiform() * 65)
        gen byte mm = 1 + floor(runiform() * 12)
        gen byte dd = 1 + floor(runiform() * 28)
        gen str10 source = string(yy, "%04.0f") + "/" + string(mm, "%02.0f") + "/" + string(dd, "%02.0f")
        gen double want = date(source, "YMD")
        gen str12 _datefix_shadow = "keep_" + string(_n)
        label variable source `"quoted "label""'
        datefix source, order(YMD)
        assert source == want
        assert _datefix_shadow == "keep_" + string(_n)
        local got_label : variable label source
        assert `"`got_label'"' == `"quoted "label""'
    }
    if _rc {
        local ++fail_count
        local failed_reps "`failed_reps' `rep'"
    }
    else local ++pass_count
}

* A failed mixed-varlist conversion must roll every source variable back.
capture noisily {
    clear
    input str10 good str10 bad
    "2020/01/02" "not-a-date"
    "2020/03/04" "2020/13/40"
    end
    clonevar good_before = good
    clonevar bad_before = bad
    capture noisily datefix good bad, order(YMD)
    assert _rc == 198
    assert good == good_before
    assert bad == bad_before
}
if _rc {
    local ++fail_count
    local failed_reps "`failed_reps' rollback"
}
else local ++pass_count
local test_count = `pass_count' + `fail_count'
display "RESULT: test_datefix_oracle tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "FAILED reps:`failed_reps'"
    exit 1
}
