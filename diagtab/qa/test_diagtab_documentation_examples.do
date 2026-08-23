*! Exact executable examples from diagtab.sthlp
*! Date: 2026-08-23

clear all
set varabbrev off
version 17.0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
adopath ++ "`pkg_dir'"
local test_count = 0
local pass_count = 0
local fail_count = 0

foreach f in diag.xlsx diag_auc.xlsx diag_multi.xlsx {
    capture erase "`qa_dir'/`f'"
}

* Example 1, verbatim.
local ++test_count
capture noisily {
    webuse lbw, clear
    logit low age lwt smoke
    predict phat
    gen byte pred_low = (phat > 0.3)
    diagtab pred_low low, xlsx(diag.xlsx) ///
        title("Diagnostic Accuracy: Low Birth Weight Prediction")
    assert r(TP) + r(FP) + r(FN) + r(TN) == _N
    confirm file "`qa_dir'/diag.xlsx"
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Example 2, verbatim.
local ++test_count
capture noisily {
    webuse lbw, clear
    logit low age lwt smoke
    predict phat
    diagtab phat low, cutoff(0.4) auc ///
        xlsx(diag_auc.xlsx) title("LBW Prediction") ///
        theme(nejm)
    assert r(auc) > 0 & r(auc) < 1
    confirm file "`qa_dir'/diag_auc.xlsx"
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Example 3, verbatim.
local ++test_count
capture noisily {
    webuse lbw, clear
    logit low age lwt smoke
    predict phat
    diagtab phat low, cutoffs(0.2 0.3 0.4 0.5) ///
        xlsx(diag_multi.xlsx) ///
        title("Diagnostic Accuracy Across Cutoffs")
    matrix CT = r(cutoff_table)
    assert rowsof(CT) == 4
    confirm file "`qa_dir'/diag_multi.xlsx"
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Example 4, verbatim.
local ++test_count
capture noisily {
    webuse lbw, clear
    logit low age lwt smoke
    predict phat
    gen byte pred_low = (phat > 0.3)
    diagtab pred_low low, prevalence(0.07) exact ///
        title("PPV/NPV Adjusted for 7% Population Prevalence")
    assert r(ppv) > 0 & r(ppv) < 1
    assert r(npv) > 0 & r(npv) < 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_diagtab_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
