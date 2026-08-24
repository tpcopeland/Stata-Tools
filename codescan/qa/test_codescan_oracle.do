* Seed: 26082420. 200 randomized rowwise prefix-count oracles.
clear all
version 16.0
quietly do "`c(pwd)'/_codescan_qa_common.do"
_codescan_qa_bootstrap
set seed 26082420
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
}
_codescan_qa_publish "test_codescan_oracle" 200 200 0
display as result "RESULT: test_codescan_oracle tests=200 pass=200 fail=0"
