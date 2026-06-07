* test_simtab_ingest.do - QA for simtab ingest mode (from())

clear all
set more off
set varabbrev off

capture log close _simtabing
log using "test_simtab_ingest.log", replace text name(_simtabing)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

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
local ++test_count
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
local ++test_count
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
**# T3: from(simsum) -- capture-guarded against live simsum
* =====================================================================
local ++test_count
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
local ++test_count
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

* =====================================================================
display as text "{hline 60}"
display as result "simtab ingest: `pass_count'/`test_count' passed (`fail_count' failed)"
display as text "{hline 60}"
assert `fail_count' == 0
log close _simtabing
