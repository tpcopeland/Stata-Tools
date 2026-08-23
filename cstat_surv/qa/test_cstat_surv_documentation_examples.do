*! test_cstat_surv_documentation_examples.do - executable cstat_surv.sthlp example
version 16.0
clear all
set more off
set varabbrev off
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall cstat_surv
quietly net install cstat_surv, from("`pkg_dir'") replace
local tests = 0
local pass = 0
local fail = 0

* cstat_surv.sthlp: Setup, Cox fit, then calculate the C-statistic.
local ++tests
capture noisily {
    webuse drugtr
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert !missing(e(c))
    assert e(N_comparable) == e(N_concordant) + e(N_discordant) + e(N_tied)
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_cstat_surv_documentation_examples tests=`tests' pass=`pass' fail=`fail'"
if `fail' exit 9
