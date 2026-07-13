* validation_simtab.do - exact known-answer + simsum oracle for simtab

clear all
set more off
set varabbrev off

capture log close _simtabval
log using "validation_simtab.log", replace text name(_simtabval)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local pass = 0
local fail = 0

program define _assert_close
    args got want tol label
    if abs(`got' - `want') < `tol' {
        display as result "    ok: `label' (`got' ~ `want')"
        c_local _ac_ok = 1
    }
    else {
        display as error "    BAD: `label' got `got' want `want'"
        c_local _ac_ok = 0
    }
end

* =====================================================================
**# Deterministic 4-replication cell, true = 1
*   estimates: 1.0 1.2 0.8 1.4   se: 0.2 each   covered: 1 1 0 1   rej: 1 0 0 1
*   mean=1.1 bias=0.1 pctbias=10 empse=.2581989 meanse=0.2
*   relerr=100*(0.2/.2581989-1)=-22.54033 mse=.06 rmse=.2449490
*   coverage=.75 power=.5
*   mcse_bias=.1290994 mcse_empse=.1054093 mcse_coverage=.2165064 mcse_power=.25
*   nsim=10 -> nfail=6 pctfail=60
* =====================================================================
clear
input byte estid double(est se truev) byte(covered rej)
1 1.0 0.2 1 1 1
1 1.2 0.2 1 1 0
1 0.8 0.2 1 0 0
1 1.4 0.2 1 1 1
end

simtab estid, estimate(est) se(se) true(truev) coverage(covered) reject(rej) ///
    nsim(10) metrics(mean bias pctbias empse meanse relerr mse rmse coverage power n nonconv) ///
    plotframe(kpf, replace) display

frame kpf {
    local got_mean     = mean[1]
    local got_bias     = bias[1]
    local got_pctbias  = pctbias[1]
    local got_empse    = empse[1]
    local got_meanse   = meanse[1]
    local got_relerr   = relerr[1]
    local got_mse      = mse[1]
    local got_rmse     = rmse[1]
    local got_cover    = coverage[1]
    local got_power    = power[1]
    local got_n        = n[1]
    local got_nfail    = nfail[1]
    local got_pctfail  = pctfail[1]
    local got_mcbias   = mcse_bias[1]
    local got_mcempse  = mcse_empse[1]
    local got_mccover  = mcse_coverage[1]
    local got_mcpower  = mcse_power[1]
}

foreach chk in ///
    "mean 1.1 1e-6" ///
    "bias 0.1 1e-6" ///
    "pctbias 10 1e-5" ///
    "empse .2581988897 1e-7" ///
    "meanse 0.2 1e-9" ///
    "relerr -22.5403330 1e-4" ///
    "mse 0.06 1e-9" ///
    "rmse .2449489743 1e-7" ///
    "cover 0.75 1e-9" ///
    "power 0.5 1e-9" ///
    "n 4 1e-9" ///
    "nfail 6 1e-9" ///
    "pctfail 60 1e-9" ///
    "mcbias .1290994449 1e-7" ///
    "mcempse .1054092553 1e-7" ///
    "mccover .2165063509 1e-7" ///
    "mcpower 0.25 1e-9" {
    gettoken nm rest : chk
    gettoken want tol : rest
    _assert_close `got_`nm'' `want' `tol' "`nm'"
    if `_ac_ok' local ++pass
    else local ++fail
}

* =====================================================================
**# simsum cross-validation oracle (capture-guarded)
*   For a tool in simsum's territory, parity with simsum is the bar.
* =====================================================================
capture which simsum
if _rc {
    if "$TABTOOLS_QA_REQUIRE_ORACLES" == "1" {
        display as error "  FAIL simsum oracle: required simsum is not installed"
        local ++fail
    }
    else display as text "  SKIP simsum oracle: simsum not installed"
}
else {
    clear
    set obs 1000
    set seed 31415
    gen long rep = ceil(_n/2)
    gen byte method = mod(_n,2)
    gen double estimate = 0.5 + rnormal(cond(method==1,0,0.03), 0.12)
    gen double se = 0.12 + runiform()*0.01
    tempfile fx
    save "`fx'"

    simsum estimate, true(0.5) se(se) methodvar(method) id(rep) mcse clear
    foreach m in 0 1 {
        foreach code in bias empse cover {
            quietly summarize estimate`m' if perfmeascode=="`code'", meanonly
            local ss_`code'`m' = r(mean)
        }
        * simsum reports coverage as a percent; simtab stores a proportion
        local ss_cover`m' = `ss_cover`m''/100
        quietly summarize estimate`m'_mcse if perfmeascode=="bias", meanonly
        local ss_mcbias`m' = r(mean)
        quietly summarize estimate`m'_mcse if perfmeascode=="empse", meanonly
        local ss_mcempse`m' = r(mean)
        quietly summarize estimate`m'_mcse if perfmeascode=="cover", meanonly
        local ss_mccover`m' = r(mean)/100
    }

    use "`fx'", clear
    * compute-mode simtab using Wald coverage (matches simsum default)
    simtab method, estimate(estimate) se(se) true(0.5) ///
        metrics(bias empse coverage n) plotframe(opf, replace)

    * map method 0/1 -> estimator_label ("0"/"1"); ids follow first occurrence
    foreach m in 0 1 {
        frame opf: quietly summarize bias if estimator_label=="`m'", meanonly
        local st_bias = r(mean)
        frame opf: quietly summarize empse if estimator_label=="`m'", meanonly
        local st_empse = r(mean)
        frame opf: quietly summarize coverage if estimator_label=="`m'", meanonly
        local st_cover = r(mean)
        frame opf: quietly summarize mcse_bias if estimator_label=="`m'", meanonly
        local st_mcbias = r(mean)
        frame opf: quietly summarize mcse_empse if estimator_label=="`m'", meanonly
        local st_mcempse = r(mean)
        frame opf: quietly summarize mcse_coverage if estimator_label=="`m'", meanonly
        local st_mccover = r(mean)

        _assert_close `st_bias'   `ss_bias`m''   1e-5 "simsum bias m`m'"
        if `_ac_ok' local ++pass
        else local ++fail
        _assert_close `st_empse'  `ss_empse`m''  1e-5 "simsum empse m`m'"
        if `_ac_ok' local ++pass
        else local ++fail
        _assert_close `st_cover'  `ss_cover`m''  1e-5 "simsum coverage m`m'"
        if `_ac_ok' local ++pass
        else local ++fail
        _assert_close `st_mcbias' `ss_mcbias`m'' 1e-5 "simsum mcse_bias m`m'"
        if `_ac_ok' local ++pass
        else local ++fail
        _assert_close `st_mcempse' `ss_mcempse`m'' 1e-5 "simsum mcse_empse m`m'"
        if `_ac_ok' local ++pass
        else local ++fail
        _assert_close `st_mccover' `ss_mccover`m'' 1e-5 "simsum mcse_coverage m`m'"
        if `_ac_ok' local ++pass
        else local ++fail
    }
}

display as text "{hline 60}"
display as result "simtab known-answer + oracle: `pass' passed, `fail' failed"
display as text "{hline 60}"
local _tc = `pass' + `fail'
display "RESULT: validation_simtab tests=`_tc' pass=`pass' fail=`fail'"
assert `fail' == 0
log close _simtabval
