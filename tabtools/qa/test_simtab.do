* test_simtab.do - complete QA for simtab (functional, ingest, styling)
* Consolidated in v1.7.0 from: test_simtab.do, test_simtab_ingest.do, test_simtab_styling.do

clear all
set more off
set varabbrev off
version 16.0

capture log close _simtab
log using "test_simtab.log", replace text name(_simtab)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear


**# Migrated from test_simtab.do


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
    assert D[2] == "Marginal"
    * by() and estimator columns precede the metric blocks; second estimand starts at H.
    assert H[2] == "Contrast"
    assert B[3] == "sc"
    assert C[3] == "estid"
    assert D[3] == "Mean"
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
**# T11: nosign / sedigits options + r(n_reps_min/max) returns
* =====================================================================
* Clarity audit MINOR-2 (2026-06-13): nosign, sedigits and the
* r(n_reps_min)/r(n_reps_max) returns were undocumented-by-test.
* nosign was also a no-op until wired to _sgn — assert it actually
* removes the leading "+" on positive bias cells.
capture noisily {
    _simtab_make_data, reps(80) estimands(1)
    keep if emd == 1

    * Default: positive bias cells carry a leading "+" before the number.
    * Match "+<digit>" so the "IIW+log" estimator label can't false-positive.
    simtab estid, estimate(est) se(se) true(truev) metrics(bias) ///
        frame(ft11a, replace)
    local _saw_plus 0
    frame ft11a {
        foreach _v of varlist c* {
            quietly count if regexm(`_v', "\+[0-9.]")
            if r(N) > 0 local _saw_plus 1
        }
    }
    assert `_saw_plus' == 1

    * nosign: no "+<digit>" sign prefix anywhere in the rendered table.
    simtab estid, estimate(est) se(se) true(truev) metrics(bias) ///
        nosign frame(ft11b, replace)
    local _saw_plus 0
    frame ft11b {
        foreach _v of varlist c* {
            quietly count if regexm(`_v', "\+[0-9.]")
            if r(N) > 0 local _saw_plus 1
        }
    }
    assert `_saw_plus' == 0

    * sedigits controls SE-class metric decimals independently of digits().
    * by(sc) keeps sim() x cell unique (the fixture carries a latent scenario).
    simtab estid, estimate(est) se(se) true(truev) by(sc) sim(sim) ///
        metrics(empse) digits(2) sedigits(4) frame(ft11c, replace)
    local _saw_4dp 0
    frame ft11c {
        foreach _v of varlist c* {
            quietly count if regexm(`_v', "\.[0-9][0-9][0-9][0-9]")
            if r(N) > 0 local _saw_4dp 1
        }
    }
    assert `_saw_4dp' == 1

    * Compute mode returns replication-count bounds; this fixture is balanced
    * (every cell has 80 reps) so min == max == 80.
    simtab estid, estimate(est) se(se) true(truev) by(sc) sim(sim) display
    assert r(n_reps_min) == 80
    assert r(n_reps_max) == 80
}
if _rc == 0 {
    display as result "  PASS T11: nosign/sedigits/n_reps_min/max"
    local ++pass_count
}
else {
    display as error "  FAIL T11 (rc=`=_rc')"
    local ++fail_count
}

**# Migrated from test_simtab_ingest.do


program drop _all
program define _simtab_fixture
    syntax , [Reps(integer 400)]
    clear
    set obs `=`reps'*2'
    set seed 70
    gen long rep = ceil(_n/2)
    gen byte method = mod(_n,2)
    label define meth 0 "A" 1 "B", replace
    label values method meth
    gen double estimate = 0.5 + rnormal(cond(method==1,0,0.04), 0.1)
    gen double se = 0.1 + runiform()*0.01
    gen byte covered = (estimate-1.96*se <= 0.5 & 0.5 <= estimate+1.96*se)
end

* =====================================================================
**# T1: from(summary) -- always runs (dependency-free contract)
* =====================================================================
capture noisily {
    _simtab_fixture, reps(400)
    collapse (mean) m=estimate (sd) sd=estimate (mean) cov=covered ///
        (count) nr=estimate, by(method)
    gen double b = m - 0.5
    simtab, from(summary) estimatorvar(method) ///
        measures(mean=m bias=b empse=sd coverage=cov n=nr) ///
        frame(fs1, replace) display
    assert r(mode) == "ingest"
    assert r(source) == "summary"
    assert r(n_estimators) == 2
    * rendered coverage = proportion*100 displayed as %
    frame fs1: assert strpos(c5[2], "%") > 0
}
if _rc == 0 {
    display as result "  PASS T1: from(summary)"
    local ++pass_count
}
else {
    display as error "  FAIL T1 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T2: mode conflict -- compute options with from()
* =====================================================================
capture noisily {
    _simtab_fixture, reps(400)
    capture simtab method, from(summary) estimate(estimate) se(se) true(0.5) display
    assert _rc != 0
    capture simtab, from(bogus) display
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T2: ingest error paths"
    local ++pass_count
}
else {
    display as error "  FAIL T2 (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T2b: from(summary) byvar() + estimandvar() column overrides
* =====================================================================
* Clarity audit MINOR-2 (2026-06-13): byvar() and estimandvar() ingest
* overrides were untested. Build a per-cell summary crossing estimator x
* scenario x estimand and assert simtab renders all three dimensions.
capture noisily {
    clear
    input str3 method str2 scenario str2 target double m double b double cov double nr
    "A" "S1" "T1" 0.50 0.00 0.94 400
    "B" "S1" "T1" 0.54 0.04 0.91 400
    "A" "S2" "T1" 0.48 -0.02 0.95 400
    "B" "S2" "T1" 0.55 0.05 0.90 400
    "A" "S1" "T2" 0.10 0.00 0.96 400
    "B" "S1" "T2" 0.13 0.03 0.92 400
    "A" "S2" "T2" 0.09 -0.01 0.95 400
    "B" "S2" "T2" 0.14 0.04 0.91 400
    end

    simtab, from(summary) estimatorvar(method) byvar(scenario) ///
        estimandvar(target) measures(mean=m bias=b coverage=cov n=nr) ///
        frame(fbe, replace) display
    assert r(mode) == "ingest"
    assert r(source) == "summary"
    assert r(n_estimators) == 2
    assert r(n_by) == 2
    assert r(n_estimands) == 2

    * by-group (scenario) and estimator labels render as standalone cells;
    * estimand (target) labels render as a header prefix ("T1: Mean", ...).
    foreach _lbl in S1 S2 A B {
        local _saw 0
        frame fbe {
            foreach _v of varlist c* {
                quietly count if strtrim(`_v') == "`_lbl'"
                if r(N) > 0 local _saw 1
            }
        }
        assert `_saw' == 1
    }
    foreach _lbl in T1 T2 {
        local _saw 0
        frame fbe {
            foreach _v of varlist c* {
                quietly count if strpos(`_v', "`_lbl':") > 0
                if r(N) > 0 local _saw 1
            }
        }
        assert `_saw' == 1
    }
}
if _rc == 0 {
    display as result "  PASS T2b: from(summary) byvar/estimandvar overrides"
    local ++pass_count
}
else {
    display as error "  FAIL T2b (rc=`=_rc')"
    local ++fail_count
}

* =====================================================================
**# T3: from(simsum) -- capture-guarded against live simsum
* =====================================================================
capture which simsum
if _rc {
    display as text "  SKIP T3: simsum not installed"
}
else {
    capture noisily {
        _simtab_fixture, reps(400)
        tempfile fx
        save "`fx'"
        simsum estimate, true(0.5) se(se) methodvar(method) id(rep) mcse clear
        * simsum's empirical SE and bias for method A (estimate0)
        quietly summarize estimate0 if perfmeascode=="bias", meanonly
        local ss_bias = r(mean)
        quietly summarize estimate0 if perfmeascode=="empse", meanonly
        local ss_empse = r(mean)
        quietly summarize estimate0 if perfmeascode=="cover", meanonly
        local ss_cover = r(mean)/100
        simtab, from(simsum) plotframe(pfs, replace) display
        assert r(source) == "simsum"
        * method A row in plotframe
        frame pfs: quietly summarize bias if estimator_label=="A", meanonly
        assert reldif(r(mean), `ss_bias') < 1e-5
        frame pfs: quietly summarize empse if estimator_label=="A", meanonly
        assert reldif(r(mean), `ss_empse') < 1e-5
        frame pfs: quietly summarize coverage if estimator_label=="A", meanonly
        assert reldif(r(mean), `ss_cover') < 1e-5
    }
    if _rc == 0 {
        display as result "  PASS T3: from(simsum) reproduces simsum values"
        local ++pass_count
    }
    else {
        display as error "  FAIL T3 (rc=`=_rc')"
        local ++fail_count
    }
}

* =====================================================================
**# T4: from(siman) -- capture-guarded; reproduces siman analyse values
*   Requires siman (UCL) plus its sencode/labelsof dependencies. Under the
*   run_all harness (temp PLUS adopath) these are hidden, so this SKIPs;
*   a direct run against the real adopath exercises the live adapter.
* =====================================================================
local _siman_ok = 1
foreach _dep in siman sencode labelsof {
    capture which `_dep'
    if _rc local _siman_ok = 0
}
if !`_siman_ok' {
    display as text "  SKIP T4: siman (or sencode/labelsof) not installed"
}
else {
    capture noisily {
        clear
        set seed 70
        set obs 1200
        gen long rep = ceil(_n/2)
        gen byte methnum = mod(_n,2)
        gen str8 estimator = cond(methnum==1, "B", "A")
        gen byte scen = 1 + (rep>300)
        label define _sc 1 "S1" 2 "S2", replace
        label values scen _sc
        gen double estimate = 0.5 + rnormal(cond(estimator=="A",0.04,0), 0.1)
        gen double se = 0.1 + runiform()*0.01
        drop methnum

        siman setup, rep(rep) estimate(estimate) se(se) method(estimator) ///
            dgm(scen) true(0.5)
        siman analyse

        * reference performance values straight from siman's rows
        foreach mm in A B {
            forvalues s = 1/2 {
                foreach code in bias empse cover {
                    quietly summarize estimate if _perfmeascode=="`code'" ///
                        & estimator=="`mm'" & scen==`s', meanonly
                    local ref_`code'_`mm'`s' = r(mean)
                }
            }
        }

        * simtab renders the siman output already in memory
        simtab, from(siman) plotframe(spf, replace) display
        assert r(source) == "siman"
        assert r(n_by) == 2
        assert r(n_estimators) == 2

        foreach mm in A B {
            forvalues s = 1/2 {
                frame spf: quietly summarize bias ///
                    if estimator_label=="`mm'" & by_label=="S`s'", meanonly
                assert reldif(r(mean), `ref_bias_`mm'`s'') < 1e-5
                frame spf: quietly summarize empse ///
                    if estimator_label=="`mm'" & by_label=="S`s'", meanonly
                assert reldif(r(mean), `ref_empse_`mm'`s'') < 1e-5
                frame spf: quietly summarize coverage ///
                    if estimator_label=="`mm'" & by_label=="S`s'", meanonly
                assert reldif(r(mean)*100, `ref_cover_`mm'`s'') < 1e-4
            }
        }
    }
    if _rc == 0 {
        display as result "  PASS T4: from(siman) reproduces siman values"
        local ++pass_count
    }
    else {
        display as error "  FAIL T4 (rc=`=_rc')"
        local ++fail_count
    }
}

**# Migrated from test_simtab_styling.do

* require the xlsx checker - styling assertions depend on it
capture confirm file "`checker'"
if _rc {
    display as error "check_xlsx.py not found in `tools_dir'; cannot validate styling"
    exit 601
}
local checker "`checker'"


* ---- deterministic long sim dataset with labelled grouping vars ----
program drop _all
program define _simtab_style_data
    syntax , [Reps(integer 60) Estimands(integer 2)]
    clear
    local cells = `reps' * 2 * 3 * `estimands'
    set obs `cells'
    set seed 20260608
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
    label variable sc "Scenario"
    label variable estid "Estimator"
    gen double truev = cond(emd==1, 0.10, 0.50)
    gen double est = truev + rnormal(0, 0.04)
    gen double se = 0.04 + runiform()*0.004
end

* helper: run check_xlsx.py and assert PASS via the result file
capture program drop _xl_pass
program define _xl_pass
    args result_file
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end

* =====================================================================
**# T1: multi-estimand (by + 2 estimands) - B2 offset, box, separators
* =====================================================================
* Layout (title + by + 2 estimands + 5 metrics):
*   col A = spacer, B = scenario, C = estimator, D-H = marginal, I-M = contrast
*   row 1 = title, 2 = group header, 3 = metric header, 4-9 = data, 10 = footnote
local x1 "`output_dir'/_style_multi.xlsx"
local r1 "`output_dir'/_style_r1.txt"
capture noisily {
    _simtab_style_data, reps(60) estimands(2)
    capture erase "`x1'"
    simtab estid, estimate(est) se(se) true(truev) by(sc) estimand(emd) sim(sim) ///
        metrics(mean bias empse coverage n) digits(3) ///
        title("Styling Regression") ///
        footnote("Regression fixture for the B2-offset styling fix.") ///
        borderstyle(academic) ///
        xlsx("`x1'") sheet("Tab")

    shell python3 "`checker'" "`x1'" --sheet "Tab" ///
        --cell A1 "Styling Regression" ///
        --cell B3 "Scenario" --cell C3 "Estimator" ///
        --cell D2 "Marginal" --cell I2 "Contrast" ///
        --cell-border B2 left medium ///
        --cell-border M2 right medium ///
        --cell-border D2 top medium ///
        --cell-border B9 bottom medium ///
        --cell-border M9 bottom medium ///
        --cell-border D2 bottom medium ///
        --cell-border D3 bottom medium ///
        --cell-border B4 right medium ///
        --cell-border C4 right medium ///
        --cell-border H4 right medium ///
        --cell-border B7 top thin ///
        --cell-no-fill B3 C3 D2 D3 I2 ///
        --result-file "`r1'" --quiet
    _xl_pass "`r1'"
}
if _rc == 0 {
    display as result "  PASS: T1 multi-estimand B2 offset + box + separators + no fill"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 (rc=`=_rc')"
    local ++fail_count
}
capture erase "`r1'"

* =====================================================================
**# T2: single estimand (no by) - B2 offset, three-line box, no group row
* =====================================================================
* Layout (title + no by + 1 estimand + 5 metrics):
*   col A = spacer, B = estimator, C-G = metrics
*   row 1 = title, 2 = metric header, 3-5 = data, 6 = footnote
local x2 "`output_dir'/_style_single.xlsx"
local r2 "`output_dir'/_style_r2.txt"
capture noisily {
    _simtab_style_data, reps(60) estimands(1)
    keep if sc == 1
    capture erase "`x2'"
    simtab estid, estimate(est) se(se) true(truev) sim(sim) ///
        metrics(mean bias empse coverage n) digits(3) ///
        title("Single Estimand") ///
        borderstyle(academic) ///
        xlsx("`x2'") sheet("Tab")

    shell python3 "`checker'" "`x2'" --sheet "Tab" ///
        --cell A1 "Single Estimand" ///
        --cell B2 "Estimator" ///
        --cell-border B2 left medium ///
        --cell-border G2 right medium ///
        --cell-border B2 top medium ///
        --cell-border B5 bottom medium ///
        --cell-border B2 right medium ///
        --cell-no-fill B2 C2 ///
        --result-file "`r2'" --quiet
    _xl_pass "`r2'"
}
if _rc == 0 {
    display as result "  PASS: T2 single-estimand B2 offset + three-line box"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 (rc=`=_rc')"
    local ++fail_count
}
capture erase "`r2'"

* =====================================================================
**# T3: headershade is opt-in - explicit headershade still fills header
* =====================================================================
* Confirms the default-no-fill change did not break the headershade option.
local x3 "`output_dir'/_style_shade.xlsx"
local r3 "`output_dir'/_style_r3.txt"
capture noisily {
    _simtab_style_data, reps(60) estimands(2)
    capture erase "`x3'"
    simtab estid, estimate(est) se(se) true(truev) by(sc) estimand(emd) sim(sim) ///
        metrics(mean bias empse coverage n) digits(3) ///
        title("Shaded Header") ///
        borderstyle(academic) headershade ///
        xlsx("`x3'") sheet("Tab")

    * with headershade, the metric-header row (row 3) carries a solid fill,
    * and the B2 offset / left border are still present
    shell python3 "`checker'" "`x3'" --sheet "Tab" ///
        --cell A1 "Shaded Header" ///
        --cell-border B2 left medium ///
        --has-fill 3 ///
        --result-file "`r3'" --quiet
    _xl_pass "`r3'"
}
if _rc == 0 {
    display as result "  PASS: T3 headershade opt-in still applies header fill"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 (rc=`=_rc')"
    local ++fail_count
}
capture erase "`r3'"

* =====================================================================

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_simtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _simtab
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_simtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _simtab

