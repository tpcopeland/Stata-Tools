*! test_diagtab_accuracy_label.do - prevalence() leaves accuracy at the sample value and labels it
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
set varabbrev off
version 17.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall diagtab
quietly net install diagtab, from("`pkg_dir'") replace
discard

* L1: with prevalence() the accuracy row is labelled as the sample value
local ++test_count
capture noisily {
    clear
    input byte test gold
    1 1
    1 1
    1 1
    1 0
    0 1
    0 0
    0 0
    0 0
    0 0
    0 0
    end
    tempfile csvp
    diagtab test gold, prevalence(0.07) csv("`csvp'.csv")
    local acc_adj = r(accuracy)
    local meth "`r(methods)'"
    import delimited using "`csvp'.csv", clear stringcols(_all) varnames(nonames)
    local found_sample 0
    local found_plain 0
    forvalues i = 1/`=_N' {
        if v1[`i'] == "Accuracy (sample)" local found_sample 1
        if v1[`i'] == "Accuracy" local found_plain 1
    }
    assert `found_sample' == 1
    assert `found_plain' == 0
    * the value itself is the unadjusted sample accuracy (3 + 5) / 10
    assert abs(`acc_adj' - 0.8) < 1e-12
    assert strpos(`"`meth'"', "Accuracy is the sample value") > 0
}
if _rc == 0 {
    display as result "PASS: L1 accuracy labelled sample under prevalence()"
    local ++pass_count
}
else {
    display as error "FAIL: L1 accuracy labelled sample under prevalence()"
    local ++fail_count
}

* guard: L2 is expected green at HEAD (no prevalence: plain Accuracy label)
* L2: without prevalence() the row stays "Accuracy"
local ++test_count
capture noisily {
    clear
    input byte test gold
    1 1
    1 1
    1 1
    1 0
    0 1
    0 0
    0 0
    0 0
    0 0
    0 0
    end
    tempfile csvq
    diagtab test gold, csv("`csvq'.csv")
    import delimited using "`csvq'.csv", clear stringcols(_all) varnames(nonames)
    local found_plain 0
    local found_sample 0
    forvalues i = 1/`=_N' {
        if v1[`i'] == "Accuracy" local found_plain 1
        if v1[`i'] == "Accuracy (sample)" local found_sample 1
    }
    assert `found_plain' == 1
    assert `found_sample' == 0
}
if _rc == 0 {
    display as result "PASS: L2 plain Accuracy label without prevalence()"
    local ++pass_count
}
else {
    display as error "FAIL: L2 plain Accuracy label without prevalence()"
    local ++fail_count
}

display "RESULT: test_diagtab_accuracy_label tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
exit 0
