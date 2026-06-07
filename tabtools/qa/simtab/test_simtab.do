* test_simtab.do - Functional QA for simtab compute mode

clear all
set more off
set varabbrev off

capture log close _simtab
log using "test_simtab.log", replace text name(_simtab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* ---- helper: build a deterministic long sim dataset in memory ----
program drop _all
program define _simtab_make_data
    syntax , [Reps(integer 80) Estimands(integer 1)]
    clear
    local cells = `reps' * 2 * 3 * `estimands'
    set obs `cells'
    set seed 20260607
    gen long sim = mod(_n-1, `reps') + 1
    gen byte sc = mod(floor((_n-1)/(`reps'*3)), 2) + 1
    gen byte estid = mod(floor((_n-1)/`reps'), 3) + 1
    gen byte emd = floor((_n-1)/(`reps'*3*2)) + 1
    label define sclbl 1 "A" 2 "B", replace
    label values sc sclbl
    label define estlbl 1 "Unweighted" 2 "IIW" 3 "IIW+log", replace
    label values estid estlbl
    label define emdlbl 1 "Marginal" 2 "Contrast", replace
    label values emd emdlbl
    gen double truev = cond(emd==1, 0.10, 0.50)
    gen double est = truev + rnormal(cond(estid==1, 0.05, 0), 0.04)
    gen double se = 0.04 + runiform()*0.004
    gen double lo = est - 1.96*se
    gen double hi = est + 1.96*se
    gen byte covered = (lo <= truev & truev <= hi)
    gen double pval = 2*(1 - normal(abs((est-0)/se)))
    gen byte rej = (pval < 0.05)
end

program define _simchk
    args label rc
    c_local _last_rc = `rc'
end

* =====================================================================
**# T1: single estimand, no by(), display + returns
* =====================================================================
local ++test_count
capture noisily {
    _simtab_make_data, reps(80) estimands(1)
    keep if emd == 1
    simtab estid, estimate(est) se(se) true(truev) display
    assert r(mode) == "compute"
    assert r(n_estimands) == 1
    assert r(n_estimators) == 3
    assert r(n_by) == 1
    assert r(N_cells) == 3
}
if _rc == 0 {
    display as result "  PASS T1: single estimand no by"
    local ++pass_count
}
else {
    display as error "  FAIL T1 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T2: single estimand with by(), numeric+labeled estimator, frame
* =====================================================================
local ++test_count
capture noisily {
    _simtab_make_data, reps(80) estimands(1)
    keep if emd == 1
    simtab estid, estimate(est) se(se) true(truev) by(sc) sim(sim) ///
        coverage(covered) frame(ft2, replace)
    assert r(n_by) == 2
    assert "`r(frame)'" == "ft2"
    frame ft2: assert _N == 7
    frame ft2: assert c1[2] == "A"
    frame ft2: assert c2[2] == "Unweighted"
    frame ft2: assert c1[3] == ""
}
if _rc == 0 {
    display as result "  PASS T2: by() + frame"
    local ++pass_count
}
else {
    display as error "  FAIL T2 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T3: multiple estimands -> merged Excel + flattened markdown
* =====================================================================
local ++test_count
local x3 "`output_dir'/test_simtab_multi.xlsx"
local m3 "`output_dir'/test_simtab_multi.md"
capture erase "`x3'"
capture erase "`m3'"
capture noisily {
    _simtab_make_data, reps(80) estimands(2)
    simtab estid, estimate(est) se(se) true(truev) by(sc) estimand(emd) sim(sim) ///
        coverage(covered) metrics(mean bias coverage n) ///
        xlsx("`x3'") sheet("Tab") markdown("`m3'") title("Multi") frame(ft3, replace)
    assert r(n_estimands) == 2
    assert r(N_cells) == 12
    assert "`r(xlsx)'" == "`x3'"
    assert "`r(markdown)'" == "`m3'"
    * Excel: title row, group header row, metric header row
    import excel using "`x3'", sheet("Tab") cellrange(A1:J3) clear allstring
    assert A[1] == "Multi"
    assert C[2] == "Marginal"
    * group header for 2nd estimand at column lead(2)+D(4)+1 = 7 (G)
    assert G[2] == "Contrast"
    assert A[3] == "sc"
    assert C[3] == "Mean"
}
if _rc == 0 {
    display as result "  PASS T3: multi-estimand merged Excel + markdown"
    local ++pass_count
}
else {
    display as error "  FAIL T3 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T4: coverage sources -- lci/uci and Wald agree with indicator
* =====================================================================
local ++test_count
capture noisily {
    _simtab_make_data, reps(80) estimands(1)
    keep if emd == 1
    * indicator-based coverage
    simtab estid, estimate(est) se(se) true(truev) coverage(covered) ///
        plotframe(pf_ind, replace) display
    * lci/uci coverage (same 1.96 limits)
    simtab estid, estimate(est) se(se) true(truev) lci(lo) uci(hi) ///
        plotframe(pf_ci, replace) display
    * compare coverage per estimator
    frame pf_ind: gen long _k = estimator_value
    frame pf_ci:  gen long _k = estimator_value
    frame pf_ind: sort _k
    frame pf_ci:  sort _k
    forvalues i = 1/3 {
        frame pf_ind: local a = coverage[`i']
        frame pf_ci:  local b = coverage[`i']
        assert abs(`a' - `b') < 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS T4: coverage source agreement"
    local ++pass_count
}
else {
    display as error "  FAIL T4 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T5: power from pvalue() and from reject() agree
* =====================================================================
local ++test_count
capture noisily {
    _simtab_make_data, reps(80) estimands(1)
    keep if emd == 1
    simtab estid, estimate(est) se(se) true(truev) coverage(covered) ///
        metrics(power n) pvalue(pval) plotframe(pf_p, replace) display
    simtab estid, estimate(est) se(se) true(truev) coverage(covered) ///
        metrics(power n) reject(rej) plotframe(pf_r, replace) display
    frame pf_p: sort estimator_value
    frame pf_r: sort estimator_value
    forvalues i = 1/3 {
        frame pf_p: local a = power[`i']
        frame pf_r: local b = power[`i']
        assert abs(`a' - `b') < 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS T5: power source agreement"
    local ++pass_count
}
else {
    display as error "  FAIL T5 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T6: nsim() -> nonconv / nfail / pctfail correctness
* =====================================================================
local ++test_count
capture noisily {
    _simtab_make_data, reps(80) estimands(1)
    keep if emd == 1
    simtab estid, estimate(est) se(se) true(truev) by(sc) coverage(covered) ///
        nsim(100) metrics(mean coverage n nonconv) ///
        plotframe(pf6, replace) display
    * each by x estimator cell has 80 reps -> nfail = 20
    assert r(n_fail_max) == 20
    frame pf6: assert nfail == 100 - n
    frame pf6: assert reldif(pctfail, 100*nfail/100) < 1e-9
    * nsim < per-cell reps must error
    capture simtab estid, estimate(est) se(se) true(truev) by(sc) ///
        coverage(covered) nsim(10) metrics(n nonconv) display
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T6: non-convergence reporting"
    local ++pass_count
}
else {
    display as error "  FAIL T6 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T7: order(data) preserves first-occurrence estimator order
* =====================================================================
local ++test_count
capture noisily {
    _simtab_make_data, reps(80) estimands(1)
    keep if emd == 1
    simtab estid, estimate(est) se(se) true(truev) by(sc) coverage(covered) ///
        order(data) frame(fto, replace)
    * data first-occurrence (c2 = estimator column when by() present):
    * Unweighted, IIW, IIW+log
    frame fto: assert c2[2] == "Unweighted"
    frame fto: assert c2[3] == "IIW"
    frame fto: assert c2[4] == "IIW+log"
}
if _rc == 0 {
    display as result "  PASS T7: order(data)"
    local ++pass_count
}
else {
    display as error "  FAIL T7 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T8: CSV export + true() as scalar literal
* =====================================================================
local ++test_count
local c8 "`output_dir'/test_simtab.csv"
capture erase "`c8'"
capture noisily {
    _simtab_make_data, reps(80) estimands(1)
    keep if emd == 1 & estid == 2
    * all truev == 0.10 here, so literal true(0.10) is valid
    simtab estid, estimate(est) se(se) true(0.10) coverage(covered) csv("`c8'")
    assert "`r(csv)'" == "`c8'"
    confirm file "`c8'"
    * footnote stays in the frame's full table even though the console preview
    * drops it (so a long footnote cannot inflate the console column width)
    simtab estid, estimate(est) se(se) true(0.10) coverage(covered) ///
        footnote("My footnote line.") frame(ft8, replace) display
    frame ft8: assert c1[_N] == "My footnote line."
}
if _rc == 0 {
    display as result "  PASS T8: csv + true literal"
    local ++pass_count
}
else {
    display as error "  FAIL T8 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T9: coverage off-nominal flag asterisk in rendered table
* =====================================================================
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte estid = 1
    gen long sim = _n
    gen double truev = 0
    * deliberately under-cover: estimates far from truth relative to se
    set seed 99
    gen double est = rnormal(0.5, 0.05)
    gen double se = 0.05
    gen byte covered = (est - 1.96*se <= 0 & 0 <= est + 1.96*se)
    simtab estid, estimate(est) se(se) true(truev) coverage(covered) ///
        metrics(coverage n) frame(ft9, replace) display
    * coverage is ~0% -> off-nominal -> asterisk on the coverage cell (c2, row 2)
    frame ft9: assert strpos(c2[2], "*") > 0
}
if _rc == 0 {
    display as result "  PASS T9: coverage off-nominal asterisk"
    local ++pass_count
}
else {
    display as error "  FAIL T9 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T10: ERROR paths
* =====================================================================
local ++test_count
local err_ok = 1
_simtab_make_data, reps(80) estimands(1)
keep if emd == 1
* no output target
capture simtab estid, estimate(est) se(se) true(truev)
if _rc == 0 local err_ok = 0
* bad metric
capture simtab estid, estimate(est) se(se) true(truev) metrics(bogus) display
if _rc == 0 local err_ok = 0
* power without source
capture simtab estid, estimate(est) se(se) true(truev) metrics(power) display
if _rc == 0 local err_ok = 0
* nonconv without nsim
capture simtab estid, estimate(est) se(se) true(truev) metrics(nonconv) display
if _rc == 0 local err_ok = 0
* negative se
preserve
replace se = -1 in 1
capture simtab estid, estimate(est) se(se) true(truev) display
if _rc == 0 local err_ok = 0
restore
* duplicate sim cells
preserve
replace sim = 1 in 1/3
capture simtab estid, estimate(est) se(se) true(truev) sim(sim) display
if _rc == 0 local err_ok = 0
restore
* truth varies within cell
preserve
replace truev = 0.9 in 1
capture simtab estid, estimate(est) se(se) true(truev) display
if _rc == 0 local err_ok = 0
restore
* bad xlsx extension
capture simtab estid, estimate(est) se(se) true(truev) xlsx("bad.txt")
if _rc == 0 local err_ok = 0
if `err_ok' {
    display as result "  PASS T10: error paths fire"
    local ++pass_count
}
else {
    display as error "  FAIL T10: an error path did not fire"
    local ++fail_count
}

* =====================================================================
display as text "{hline 60}"
display as result "simtab functional: `pass_count'/`test_count' passed (`fail_count' failed)"
display as text "{hline 60}"
assert `fail_count' == 0
log close _simtab
