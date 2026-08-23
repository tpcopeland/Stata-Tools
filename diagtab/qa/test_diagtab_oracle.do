* Seed: 26082430. 200 randomized 2x2 table oracles.
clear all
version 17.0
local pkg_dir "`c(pwd)'/.."
adopath ++ "`pkg_dir'"
set seed 26082430
forvalues rep = 1/200 {
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
display as result "RESULT: PASS diagtab randomized oracle (200 reps)"
