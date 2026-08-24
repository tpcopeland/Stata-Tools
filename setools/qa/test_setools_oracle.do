* Seed: 26082401. 200 deterministic catalog repetitions.
clear all
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"
set seed 26082401
forvalues rep = 1/200 {
    local pick = mod(`rep', 4)
    if `pick' == 0 local cat all
    if `pick' == 1 local cat codes
    if `pick' == 2 local cat migration
    if `pick' == 3 local cat ms
    setools, category(`cat')
    if "`cat'" == "all" local want "cci_se migrations sustainedss cdp pira"
    if "`cat'" == "codes" local want "cci_se"
    if "`cat'" == "migration" local want "migrations"
    if "`cat'" == "ms" local want "sustainedss cdp pira"
    assert "`r(commands)'" == "`want'"
    local n : word count `want'
    assert r(n_commands) == `n'
}
capture noisily setools, category(bogus)
assert _rc == 198
do "`qa_dir'/_setools_qa_common.do" teardown
display as result "RESULT: test_setools_oracle tests=201 pass=201 fail=0"
