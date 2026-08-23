* Seed: 26082440. Differential check against sts generate at tied event times.
clear all
version 16.0
quietly do "`c(pwd)'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap
set seed 26082440
forvalues rep = 1/200 {
    clear
    set obs 80
    gen byte grp = mod(_n,2)
    gen double t = ceil(runiform()*8)
    gen byte fail = runiform()<.45
    replace t = 1 in 1/2
    replace fail = 1 in 1/2
    quietly stset t, failure(fail)
    tempvar s
    quietly sts generate `s' = s, by(grp)
    kmplot, by(grp) landmark(2 4 6 8) name(kmcv`rep', replace)
    matrix L = r(landmarks)
    forvalues j=1/8 {
        local g=L[`j',1]
        local tt=L[`j',2]
        quietly summarize _t if grp==`g'-1 & _t<=`tt' & !missing(`s'), meanonly
        assert r(N)>0
        local ref_t = r(max)
        quietly summarize `s' if grp==`g'-1 & _t==`ref_t', meanonly
        local ref_s = r(mean)
        assert L[`j',3]<.
        assert `ref_s'<.
        assert abs(L[`j',3]-`ref_s')<1e-12
    }
}
display as result "RESULT: PASS kmplot sts differential (200 reps)"
