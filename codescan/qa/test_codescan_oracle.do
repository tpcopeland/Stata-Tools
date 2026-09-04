* Seed: 26082420. 200 randomized rowwise prefix-count oracles.
clear all
version 16.0
quietly do "`c(pwd)'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"
set seed 26082420
local _oracle_reps = 0
forvalues rep = 1/200 {
    clear
    set obs 31
    gen str8 dx1 = cond(runiform()<.5,"E11"+string(_n),"Z00")
    gen str8 dx2 = cond(runiform()<.5,"E11"+string(_n),"")
    gen str8 dx3 = cond(runiform()<.5,"E11"+string(_n),"A10")
    gen byte want = (substr(dx1,1,3)=="E11") + (substr(dx2,1,3)=="E11") + (substr(dx3,1,3)=="E11")
    gen str12 _codescan_shadow = "keep_"+string(_n)
    codescan dx1-dx3, define(hit "E11") countmode
    assert hit == want
    assert _codescan_shadow == "keep_"+string(_n)
    local ++_oracle_reps
}
_codescan_qa_restore "`_qa_owner'"
* The handshake is derived from the counter incremented inside the loop, not
* from the literal loop bound. Published literals agree with each other whatever
* the loop did: lowering the bound to 5 used to leave this suite green while
* still reporting 200 passing oracles. The assert pins the intended sample size,
* so shrinking it is a failure rather than a quiet reduction in coverage.
assert `_oracle_reps' == 200
_codescan_qa_publish "test_codescan_oracle" `_oracle_reps' `_oracle_reps' 0
display as result "RESULT: test_codescan_oracle tests=`_oracle_reps' pass=`_oracle_reps' fail=0"
