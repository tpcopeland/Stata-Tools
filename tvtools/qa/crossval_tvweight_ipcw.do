*! crossval_tvweight_ipcw.do -- IPCW (censoring weight) validation for tvweight
*!
*!  PART A  Known-truth recovery (always runs, in-Stata): a population with a
*!          known mean outcome is subjected to covariate-dependent (informative)
*!          censoring. The complete-case mean is biased; the IPCW-weighted mean
*!          recovers the population truth. Proves the censoring weight does its
*!          job, not just that it is internally consistent.
*!  PART B  R parity (ipw available): an independent R implementation of the same
*!          pooled-logistic IPCW (glm of the censoring indicator on the censoring
*!          covariates + time fixed effects, then within-person cumulative product
*!          of 1/P(uncensored)) must reproduce tvweight's cumulative censoring
*!          weight row-for-row. R glm MLE + R cumulation vs Stata logit + Stata
*!          by-product = genuine cross-software check of the weight math.
*!
*!  PART B skips only when Rscript is absent. Once R is available, R execution
*!  or output failure is a failed oracle, never a skip.
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "crossval_tvweight_ipcw.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

display as result "tvtools crossval: tvweight IPCW -- $S_DATE $S_TIME"

**# Part A: single-period known-truth recovery
* PART A: known-truth recovery
*   L ~ Bernoulli(0.5); population E[Y] = 0.2 + 0.4*E[L] = 0.40 (TRUTH).
*   Censoring depends on L: P(cens|L) = 0.2 + 0.4*L  (more loss where Y is high)
*   => complete-case mean(Y) biased low; IPCW-weighted mean recovers 0.40.
*   Single period => cumulative IPCW = 1/P(uncensored|L).
local ++test_count
capture noisily {
    clear
    set seed 20260629
    set obs 200000
    gen id = _n
    gen t = 1
    gen byte L = runiform() < 0.5
    gen double pY = 0.2 + 0.4*L
    gen byte Y = runiform() < pY
    gen double pC = 0.2 + 0.4*L
    gen byte cens = runiform() < pC
    * unconfounded treatment so IPTW ~ 1 and the combined weight ~ IPCW
    gen byte treat = runiform() < 0.5

    quietly summarize Y
    local truth = r(mean)                     // ~0.40 by construction

    * naive complete-case mean among the uncensored
    quietly summarize Y if cens == 0
    local naive = r(mean)

    * tvweight IPCW (unstabilized so the censoring weight = 1/P(uncensored|L))
    tvweight treat, covariates(L) id(id) time(t) ipcw(cens) ///
        censorcovariates(L) generate(iptw) censgenerate(cw) combgenerate(cwc)
    * IPCW-mode return locals (captured before summarize clobbers r())
    assert "`r(ipcw)'" == "cens"
    assert "`r(censorcovariates)'" == "L"
    assert "`r(censgenerate)'" == "cw"
    assert "`r(combgenerate)'" == "cwc"
    quietly summarize Y [aw=cw] if cens == 0
    local ipcw_rec = r(mean)

    di as txt "  truth=" %6.4f `truth' "  naive(complete-case)=" %6.4f `naive' ///
        "  IPCW-weighted=" %6.4f `ipcw_rec'
    * naive must be biased low; IPCW must recover the truth within Monte-Carlo error
    assert `naive' < `truth' - 0.02
    assert abs(`ipcw_rec' - `truth') < 0.01
}
if _rc == 0 {
    display as result "  PASS [A]: IPCW recovers known population mean (naive is biased)"
    local ++pass_count
}
else {
    display as error "  FAIL [A]: IPCW known-truth recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A"
}

**# Part B: R parity
* PART B: R parity (ipw / glm)
*   Multi-period panel; tvweight fits  logit cens L1 L2 i.t  (panel mode adds
*   time FE) and cumulates 1/P(uncensored) within person. R reproduces it with
*   glm(cens ~ L1 + L2 + factor(t), binomial) and cumprod.
local ++test_count
_tvtools_qa_probe_rscript
local has_rscript = r(available)

if `has_rscript' {
    capture noisily {
        clear
        set seed 555
        set obs 1500
        gen id = _n
        gen double L1 = rnormal()
        gen double L2 = rnormal()
        expand 5
        bysort id: gen t = _n
        gen double pc = invlogit(-2.0 + 0.4*L1 - 0.3*L2 + 0.05*t)
        gen byte cens = runiform() < pc
        * absorbing censoring: drop rows after first censoring within person
        bysort id (t): gen byte cc = sum(cens)
        drop if cc > 1
        drop cc
        gen byte treat = runiform() < 0.5

        tvweight treat, covariates(L1 L2) id(id) time(t) ipcw(cens) ///
            censorcovariates(L1 L2) generate(iptw) censgenerate(cw)
        assert r(n_cens_boundary) == 0

        preserve
        keep id t L1 L2 cens cw
        local _input "$TVTOOLS_QA_RUN_DIR/_xv_ipcw.csv"
        local _script "$TVTOOLS_QA_RUN_DIR/_xv_ipcw.R"
        local _output "$TVTOOLS_QA_RUN_DIR/_xv_ipcw_r.csv"
        local _rlog "$TVTOOLS_QA_RUN_DIR/_xv_ipcw_r.log"
        export delimited id t L1 L2 cens cw using "`_input'", replace
        restore
    }
    local _setup_rc = _rc

    if `_setup_rc' == 0 {
        * --- write the R oracle ---
        capture file close _rf
        tempname _rf
        file open _rf using "`_script'", write replace
        file write _rf "args <- commandArgs(trailingOnly=TRUE)" _n
        file write _rf "d <- read.csv(args[1])" _n
        file write _rf "d <- d[order(d\$id, d\$t), ]" _n
        file write _rf "m <- glm(cens ~ L1 + L2 + factor(t), family=binomial, data=d)" _n
        file write _rf "pc <- predict(m, type='response')" _n
        file write _rf "punc <- 1-pc" _n
        file write _rf "stopifnot(all(is.finite(punc)), all(punc > 0 & punc < 1))" _n
        file write _rf "w <- 1/punc" _n
        file write _rf "d\$cw_r <- ave(w, d\$id, FUN=cumprod)" _n
        file write _rf "write.csv(d[, c('id','t','cw_r')], args[2], row.names=FALSE)" _n
        file close _rf

        shell Rscript "`_script'" "`_input'" "`_output'" > "`_rlog'" 2>&1
        capture confirm file "`_output'"
        if _rc == 0 {
            capture noisily {
                preserve
                import delimited using "`_output'", clear varnames(1)
                tempfile rcw
                save `rcw'
                restore
                merge 1:1 id t using `rcw', nogen
                gen double _absdiff = abs(cw - cw_r)
                quietly summarize _absdiff
                local maxdiff = r(max)
                di as txt "  max|tvweight cw - R cw| = " %12.3e `maxdiff'
                assert `maxdiff' < 1e-5
            }
            if _rc == 0 {
                display as result "  PASS [B]: tvweight cumulative IPCW matches R glm oracle"
                local ++pass_count
            }
            else {
                display as error "  FAIL [B]: IPCW parity vs R (rc `=_rc')"
                local ++fail_count
                local failed_tests "`failed_tests' B"
            }
        }
        else {
            display as error "  FAIL [B]: R produced no output (see `_rlog')"
            local ++fail_count
            local failed_tests "`failed_tests' B-R"
        }
    }
    else {
        display as error "  FAIL [B]: Stata setup for parity failed (rc `_setup_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' B-setup"
    }
    capture erase "`_input'"
    capture erase "`_script'"
    capture erase "`_output'"
    capture erase "`_rlog'"
}
else {
    display as text "  SKIP [B]: Rscript not found (install R to enable IPCW parity)"
    local ++skip_count
}

**# Part C: multi-period known-truth recovery
* PART C: multi-period known-truth recovery (always runs, in-Stata)
*   PART A recovers a mean under SINGLE-period censoring (cumulative IPCW
*   collapses to 1/P(uncensored|L)). This part proves the CUMULATIVE product
*   over K=4 periods of absorbing, covariate-dependent censoring.
*     L1..L4 ~ N(0,1) iid;  Y = b0 + g*(L1+L2+L3+L4) + e,  b0=0.40 (TRUTH=E[Y]).
*     Censoring at period t is absorbing: C_t ~ Bernoulli(invlogit(c0+c1*L_t)),
*     so high-L (high-Y) people are lost => the complete-case mean is biased low.
*   The cumulative IPCW = prod_t 1/P(uncensored_t|L_t) reweights the survivors
*   back to the full population and recovers b0. The HT identity E[surv*w]=1 means
*   the survivors' mean weight ~ 1/P(survive); this telescopes only if the
*   per-period weights are cumulated correctly, so it exercises the product path,
*   not just one interval. TOL=0.02 from a multi-seed mini-MC (recovery clustered
*   in 0.393-0.403 across seeds at N=2e5; naive ~0.23, a >0.15 miss).
local ++test_count
capture noisily {
    clear
    set seed 26062904
    set obs 200000
    gen long id = _n
    local b0 = 0.40
    local g  = 0.30
    local c0 = -1.6
    local c1 = 0.8
    forvalues t = 1/4 {
        gen double L`t' = rnormal()
        gen double pc`t' = invlogit(`c0' + `c1'*L`t')
        gen byte d`t' = runiform() < pc`t'
    }
    gen double Y = `b0' + `g'*(L1+L2+L3+L4) + rnormal()
    local truth = `b0'                         // E[Y]=b0 since E[L_t]=0

    * absorbing first-censoring period (0 if never censored)
    gen byte firstcens = 0
    forvalues t = 4(-1)1 {
        replace firstcens = `t' if d`t'==1
    }
    * person-period panel: rows 1..firstcens (survivors keep all 4)
    expand 4
    bysort id: gen byte t = _n
    drop if firstcens>0 & t>firstcens
    gen double L = .
    forvalues k = 1/4 {
        replace L = L`k' if t==`k'
    }
    gen byte cens = (firstcens==t & firstcens>0)
    * unconfounded treatment so IPTW ~ 1 and the combined weight ~ cumulative IPCW
    gen byte treat = runiform() < 0.5

    * complete-case mean among survivors uncensored through period 4
    quietly summarize Y if cens==0 & t==4
    local naive = r(mean)

    tvweight treat, covariates(L) id(id) time(t) ipcw(cens) ///
        censorcovariates(L) generate(iptw) censgenerate(cw) combgenerate(cwc) nolog
    * cumulative IPCW weight on the survivor (t==4, uncensored) rows
    quietly summarize Y [aw=cw] if cens==0 & t==4
    local ipcw_rec = r(mean)

    di as txt "  [C] truth=" %6.4f `truth' "  naive(complete-case)=" %6.4f `naive' ///
        "  cum-IPCW=" %6.4f `ipcw_rec'
    * naive biased low; cumulative IPCW recovers the truth
    assert `naive' < `truth' - 0.05
    assert abs(`ipcw_rec' - `truth') < 0.02
}
if _rc == 0 {
    display as result "  PASS [C]: cumulative (multi-period) IPCW recovers known mean"
    local ++pass_count
}
else {
    display as error "  FAIL [C]: multi-period IPCW recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C"
}

**# Summary
local test_count = `pass_count' + `fail_count' + `skip_count'
display as result _newline "tvweight IPCW crossval Results -- $S_DATE $S_TIME"
display as text "Checks: `test_count'"
display as text "Passed: `pass_count'"
display as text "Failed: `fail_count'"
display as text "Skipped: `skip_count'"
display "RESULT: crossval_tvweight_ipcw tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
if `fail_count' > 0 {
    display as error "CROSSVAL FAILED: `failed_tests'"
    exit 1
}
display as result "ALL IPCW CROSSVAL CHECKS PASSED (or skipped)"
