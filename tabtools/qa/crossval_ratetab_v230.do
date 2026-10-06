* crossval_ratetab_v230.do - ratetab (F2, R3), tabtools 2.3.0
* Reference implementations: Stata's cii means, poisson (exact limits),
* strate (log-rate limits), and a hand-run poisson ... ibn.level,
* exposure() noconstant vce(cluster id) (clustered limits); the zero-count
* limit -ln(alpha/2)/Y from [R] ci. Plus refusals and the comptab hand-off.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rt230
log using "crossval_ratetab_v230.log", replace text name(_rt230)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global RT_OUT "`output_dir'"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0

capture program drop _rt_surv
program define _rt_surv
    version 17.0
    webuse drugtr, clear
    gen byte agegrp = cond(age < 55, 1, cond(age < 60, 2, 3))
    label define _rtag 1 "<55" 2 "55-59" 3 "60+", replace
    label values agegrp _rtag
    label variable agegrp "Age band"
    gen long id = _n
end

* Recurrent events: 60 people, 1-4 intervals each, Poisson counts with a
* person frailty, three groups; group 3 has no events in the zero fixture.
capture program drop _rt_recur
program define _rt_recur
    version 17.0
    clear
    set seed 20261005
    set obs 60
    gen long id = _n
    gen byte grp = 1 + mod(_n, 3)
    gen double frail = rgamma(2, 0.5)
    expand 1 + floor(runiform() * 4)
    gen double pt = 0.2 + runiform() * 2
    gen long ev = rpoisson(pt * frail * (0.4 + 0.3 * grp))
    label define _rtg 1 "Low" 2 "Mid" 3 "High", replace
    label values grp _rtg
end

**# X1: ci(exact) equals cii means, poisson for every cell (and level 90)
capture noisily {
    _rt_surv
    foreach lv in 95 90 {
        ratetab agegrp drug, level(`lv')
        assert "`r(ci_method)'" == "exact"
        matrix E = r(estimates)
        forvalues i = 1/`=rowsof(E)' {
            local D = E[`i', 4]
            local Y = E[`i', 5]
            quietly cii means `Y' `D', poisson level(`lv')
            assert !missing(E[`i', 7], r(lb) * 1000)
            assert reldif(E[`i', 7], r(lb) * 1000) < 1e-7
            assert !missing(E[`i', 8], r(ub) * 1000)
            assert reldif(E[`i', 8], r(ub) * 1000) < 1e-7
            assert !missing(E[`i', 6], `D' / `Y' * 1000)
            assert reldif(E[`i', 6], `D' / `Y' * 1000) < 1e-12
        }
    }
}
if _rc == 0 {
    display as result "  PASS: X1 ci(exact) equals cii means, poisson at levels 95 and 90"
    local ++pass_count
}
else {
    display as error "  FAIL: X1 exact limits (rc=`=_rc')"
    local ++fail_count
}

**# X2: ci(poisson) equals strate's saved limits; table cells equal strate+stratetab
capture noisily {
    _rt_surv
    quietly strate agegrp, output("$RT_OUT/_rt_strate", replace) nolist
    ratetab agegrp, ci(poisson) frame(_rtx2, replace)
    matrix E = r(estimates)
    preserve
    use "$RT_OUT/_rt_strate", clear
    forvalues i = 1/3 {
        assert !missing(E[`i', 7], _Lower[`i'] * 1000)
        assert reldif(E[`i', 7], _Lower[`i'] * 1000) < 1e-10
        assert !missing(E[`i', 8], _Upper[`i'] * 1000)
        assert reldif(E[`i', 8], _Upper[`i'] * 1000) < 1e-10
    }
    restore
    stratetab, using("$RT_OUT/_rt_strate") outcomes(1) frame(_rtx2s, replace)
    forvalues r = 5/7 {
        frame _rtx2: local a = c4[`r']
        frame _rtx2s: assert c4[`r'] == "`a'"
    }
}
if _rc == 0 {
    display as result "  PASS: X2 ci(poisson) equals strate; cells equal strate -> stratetab"
    local ++pass_count
}
else {
    display as error "  FAIL: X2 strate limits (rc=`=_rc')"
    local ++fail_count
}

**# X3: ci(cluster()) equals the hand-run clustered Poisson; cluster count
capture noisily {
    _rt_recur
    ratetab grp, events(ev) exposure(pt) ci(cluster(id)) level(95)
    matrix E = r(estimates)
    matrix G = r(clusters)
    assert "`r(cluster)'" == "id" & "`r(ci_method)'" == "cluster"
    quietly poisson ev ibn.grp, exposure(pt) noconstant vce(cluster id)
    assert G[1,1] == e(N_clust)
    forvalues l = 1/3 {
        assert !missing(E[`l', 6], exp(_b[`l'.grp]) * 1000)
        assert reldif(E[`l', 6], exp(_b[`l'.grp]) * 1000) < 1e-8
        assert !missing(E[`l', 7], exp(_b[`l'.grp] - invnormal(.975) * _se[`l'.grp]) * 1000)
        assert reldif(E[`l', 7], exp(_b[`l'.grp] - invnormal(.975) * _se[`l'.grp]) * 1000) < 1e-10
        assert !missing(E[`l', 8], exp(_b[`l'.grp] + invnormal(.975) * _se[`l'.grp]) * 1000)
        assert reldif(E[`l', 8], exp(_b[`l'.grp] + invnormal(.975) * _se[`l'.grp]) * 1000) < 1e-10
    }
    * clustering widens the interval against the exact Poisson one here
    ratetab grp, events(ev) exposure(pt)
    matrix X = r(estimates)
    assert (E[1,8] - E[1,7]) > (X[1,8] - X[1,7])
}
if _rc == 0 {
    display as result "  PASS: X3 ci(cluster()) equals poisson ibn., exposure() vce(cluster); r(clusters) = e(N_clust)"
    local ++pass_count
}
else {
    display as error "  FAIL: X3 clustered limits (rc=`=_rc')"
    local ++fail_count
}

**# X4: R3 zero-event cells: exact upper limit for every method
capture noisily {
    foreach m in exact poisson "cluster(id)" {
        _rt_recur
        replace ev = 0 if grp == 3
        quietly summarize pt if grp == 3
        local Y3 = r(sum)
        ratetab grp, events(ev) exposure(pt) ci(`m') frame(_rtx4, replace)
        matrix E = r(estimates)
        assert r(N_zero) == 1
        assert E[3, 4] == 0 & E[3, 7] == 0
        assert !missing(E[3, 8], -ln(0.025) / `Y3' * 1000)
        assert reldif(E[3, 8], -ln(0.025) / `Y3' * 1000) < 1e-12
        quietly cii means `Y3' 0, poisson
        assert !missing(E[3, 8], r(ub) * 1000)
        assert reldif(E[3, 8], r(ub) * 1000) < 1e-6
        frame _rtx4: assert regexm(c4[7], "^0\.0 \(0\.0, [0-9.]+\)$")
    }
    * the zero level is left out of the clustered fit
    _rt_recur
    replace ev = 0 if grp == 3
    ratetab grp, events(ev) exposure(pt) ci(cluster(id))
    matrix G = r(clusters)
    quietly poisson ev ibn.grp if grp != 3, exposure(pt) noconstant vce(cluster id)
    assert G[1,1] == e(N_clust)
}
if _rc == 0 {
    display as result "  PASS: X4 zero-event cells show (0, -ln(alpha/2)/Y) for exact, poisson and cluster"
    local ++pass_count
}
else {
    display as error "  FAIL: X4 zero events (rc=`=_rc')"
    local ++fail_count
}

**# X5: events()/exposure() equal the stset route; two outcomes; pyscale()
capture noisily {
    _rt_surv
    ratetab agegrp
    matrix A = r(estimates)
    gen double pt = _t - _t0
    ratetab agegrp, events(died) exposure(pt)
    matrix B = r(estimates)
    assert mreldif(A, B) < 1e-14
    gen byte old = age >= 60
    ratetab drug, events(died old) exposure(pt) frame(_rtx5, replace)
    assert r(N_outcomes) == 2
    matrix C = r(estimates)
    assert rowsof(C) == 4
    frame _rtx5: assert c2[3] == "Events" & c5[3] == "Events"
    * person-time in days, rates per person-year
    gen double ptd = pt * 365.25
    ratetab drug, events(died) exposure(ptd) pyscale(365.25)
    matrix D = r(estimates)
    ratetab drug, events(died) exposure(pt)
    matrix F = r(estimates)
    assert mreldif(D, F) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: X5 events()/exposure() equal stset data; two outcomes; pyscale()"
    local ++pass_count
}
else {
    display as error "  FAIL: X5 sources (rc=`=_rc')"
    local ++fail_count
}

**# X6: smallcells, session default, formats; r(estimates) unmasked
capture noisily {
    _rt_surv
    ratetab agegrp, smallcells(10) frame(_rtx6, replace)
    matrix E = r(estimates)
    assert E[3, 4] == 9
    frame _rtx6: assert c2[7] == "<10" & c3[7] == "–" & c4[7] == "–"
    assert strpos(r(methods), "<10") > 0
    global TABTOOLS_set_smallcells 10
    ratetab agegrp, frame(_rtx6b, replace)
    frame _rtx6b: assert c2[7] == "<10"
    ratetab agegrp, nosmallcells frame(_rtx6c, replace)
    frame _rtx6c: assert c2[7] == "9"
    global TABTOOLS_set_smallcells
    ratetab agegrp, cformat(%7.3f) sep(" to ") per(100) frame(_rtx6d, replace)
    matrix E = r(estimates)
    local want = strtrim(string(E[1,6], "%7.3f")) + " (" + strtrim(string(E[1,7], "%7.3f")) + " to " + strtrim(string(E[1,8], "%7.3f")) + ")"
    frame _rtx6d: assert c4[5] == "`want'" & c4[3] == "Per 100 PY (95% CI)"
}
if _rc == 0 {
    display as result "  PASS: X6 smallcells (explicit and session), cformat/sep/per in the cells; numbers unmasked"
    local ++pass_count
}
else {
    display as error "  FAIL: X6 masking and formats (rc=`=_rc')"
    local ++fail_count
}
global TABTOOLS_set_smallcells

**# X7: refusals
capture noisily {
    _rt_surv
    gen double pt = _t - _t0
    capture ratetab agegrp, events(died)
    assert _rc == 198
    capture ratetab agegrp, ci(bogus)
    assert _rc == 198
    capture ratetab agegrp, ci(cluster(nosuch))
    assert _rc == 111
    capture ratetab agegrp, cformat(%5.1f) digits(1)
    assert _rc == 198
    capture ratetab agegrp, level(5)
    assert _rc == 198
    capture ratetab agegrp, per(0)
    assert _rc == 198
    capture ratetab agegrp if age > 200
    assert _rc == 2000
    replace id = . in 3
    capture ratetab agegrp, ci(cluster(id))
    assert _rc == 459
    replace id = _n in 3
    gen double badpt = pt
    replace badpt = -1 in 1
    capture ratetab agegrp, events(died) exposure(badpt)
    assert _rc == 459
    gen double half = died / 2
    capture ratetab agegrp, events(half) exposure(pt)
    assert _rc == 459
    replace badpt = pt
    replace badpt = 0 if died == 1 in 1/10
    capture ratetab agegrp, events(died) exposure(badpt)
    assert _rc == 459
    stset, clear
    capture ratetab agegrp
    assert _rc == 119
}
if _rc == 0 {
    display as result "  PASS: X7 refusals: missing exposure, bad ci(), bad formats, empty sample, bad counts and person-time"
    local ++pass_count
}
else {
    display as error "  FAIL: X7 refusals (rc=`=_rc')"
    local ++fail_count
}

**# X8: a level seen in one cluster has no clustered interval (r(N_noci))
capture noisily {
    _rt_recur
    replace grp = 3 if id == 1
    replace grp = 1 if id != 1 & grp == 3
    quietly count if grp == 3 & ev > 0
    assert !missing(r(N)) & r(N) > 0
    ratetab grp, events(ev) exposure(pt) ci(cluster(id)) frame(_rtx8, replace)
    assert r(N_noci) == 1
    frame _rtx8: assert c1[7] == "   High" & strpos(c4[7], "(–)") > 0
}
if _rc == 0 {
    display as result "  PASS: X8 a single-cluster level prints no interval and is counted in r(N_noci)"
    local ++pass_count
}
else {
    display as error "  FAIL: X8 single-cluster level (rc=`=_rc')"
    local ++fail_count
}

**# X9: the frame is a stratetab frame comptab, rateframe() accepts
capture noisily {
    _rt_surv
    gen double pt = _t - _t0
    ratetab agegrp, outlabels("Death") ci(cluster(id)) frame(_rtx9, replace)
    frame _rtx9 {
        local src : char _dta[tabtools_source]
        local prod : char _dta[tabtools_producer]
        local meth : char _dta[tabtools_ci_method]
        assert "`src'" == "stratetab" & "`prod'" == "ratetab" & "`meth'" == "cluster"
    }
    collect clear
    quietly collect: poisson died i.agegrp, exposure(pt) irr vce(cluster id)
    quietly regtab, frame(_rtm9, replace) noint models("P")
    comptab _rtm9, rateframe(_rtx9) rows(3/4) outcomemap("P") effect("IRR") frame(_rtc9, replace)
    frame _rtm9: local want = strtrim(c1[6]) + " " + strtrim(c2[6])
    frame _rtc9: assert c5[6] == "`want'"
}
if _rc == 0 {
    display as result "  PASS: X9 ratetab frame carries stratetab provenance and composes with comptab"
    local ++pass_count
}
else {
    display as error "  FAIL: X9 comptab hand-off (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: crossval_ratetab_v230 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _rt230
if `fail_count' > 0 exit 1
