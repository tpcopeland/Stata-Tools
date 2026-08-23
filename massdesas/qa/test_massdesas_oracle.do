* Seed: 26082404. 200 deterministic nonexistent-directory contracts.
clear all
version 16.0
do "`c(pwd)'/_massdesas_qa_common.do"
_massdesas_qa_bootstrap
set seed 26082404
local before "`c(pwd)'"
forvalues rep = 1/200 {
    local bad "missing_oracle_`rep'_`=floor(runiform()*1e9)'"
    capture quietly massdesas, directory("`bad'")
    assert _rc == 601
    assert "`c(pwd)'" == "`before'"
}
display as result "RESULT: PASS massdesas randomized oracle (200 reps)"
