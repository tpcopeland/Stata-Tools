* =============================================================================
* crossval_iivw_bootstrap_survival.do - iivw_fit refit subject bootstrap vs R
* =============================================================================
* Route covered: iivw_fit weighted GEE with the refit subject bootstrap, the
* default variance (IIW, IPTW and FIPTIW weights).
*
* Oracle: R survival::coxph (visit model, Efron ties) + glm (propensity) +
* geepack::geeglm (independence GEE), refit from the raw rows on every
* bootstrap resample. Script: crossval_iivw_bootstrap_survival.R. R reads none
* of iivw's weights or replicate estimates.
*
* Identical resamples. Stata's and R's generators differ, so replicate-by-
* replicate parity needs the same subject draws. iivw_fit does not expose them
* (saving() holds the replicate coefficients, not the resampled ids), so this
* suite records them with Stata's own bootstrap prefix: it sets the same seed
* and runs `bootstrap, reps(B) cluster(id) idcluster(...)` around a recording
* program on the same data in the same row order. The prefix draws the clusters
* from c(rngstate) and nothing else, so the draws are those iivw_fit's refit
* bootstrap uses. The recorded draws are therefore an ASSUMPTION until
* checked, and the check is the result itself: if iivw_fit had drawn different
* subjects, its saved replicates could not match R's refit replicate by
* replicate. Test N proves this has teeth: each iivw replicate is compared
* with R's NEXT replicate (a different resample) and must be far worse.
*
* What is compared, per arm:
*   D  every replicate recorded and each resample holds exactly m clusters
*   P  iivw_fit's saved replicate coefficients vs R's refit, every replicate
*      and all four coefficients; observed-sample coefficients too
*   S  the bootstrap SE iivw_fit reports (sqrt diag e(V)) vs the SD of R's
*      replicates (same B-1 divisor)
*   N  negative control: replicate r vs R's replicate r+1 is at least 1000x
*      farther than the parity discrepancy
*
* Tolerance, relative, coefficients and SEs: 1e-9 for the Cox-only (IIW) arm,
* whose Stata and R roots agree to ~1e-13 on the exploration run; 1e-6 for the
* arms that fit the propensity logit, because Stata's logit stops at its default
* 1e-6 likelihood tolerance while R solves to ~1e-12 (worst replicate on the
* exploration run 2.7e-7). A bootstrap SE is a smooth function of the replicates
* and inherits the same bound. Seeds: bootstrap 4242, data 733. B = 200 draws
* per arm, 150 subjects.
* Bounded: ~2 minutes. Lane: full.
* =============================================================================

clear all
set more off
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "crossval_iivw_bootstrap_survival.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

local test_count = 12
local pass_count = 0
local fail_count = 0
local failed_tests ""

local B = 200
local BSEED = 4242
local DSEED = 733
local NSUB = 150

local rscript "`qa_dir'/crossval_iivw_bootstrap_survival.R"
capture confirm file "`rscript'"
if _rc {
    display as error "missing R generator: `rscript'"
    exit 601
}
tempfile _tstub
local ref_dir "`_tstub'_bsx"
capture mkdir "`ref_dir'"
local rpre "`ref_dir'/.preflight_ok"
local rcheck "if (all(sapply(c('survival','geepack'), requireNamespace, quietly=TRUE))) quit(status=0) else quit(status=1)"
shell Rscript -e "`rcheck'" > /dev/null 2>&1 && touch "`rpre'"
capture confirm file "`rpre'"
if _rc {
    display as error "R preflight failed: needs Rscript with survival and geepack"
    display as error `"  install.packages(c("survival","geepack"))"'
    exit 198
}

* Same fixture family as crossval_iivw_stacked_geex.do: irregular continuous
* visit times, a time-varying visit covariate (zl), confounded treatment.
capture program drop mkfix
program define mkfix
    syntax , NSub(integer) Seed(integer)
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double z1 = rnormal()
    gen double k1 = rnormal()
    gen byte a = runiform() < invlogit(0.8*k1)
    expand 25
    bysort id: gen int j = _n
    gen double zt = rnormal()
    bysort id (j): gen double zl = cond(_n == 1, 0, zt[_n-1])
    gen double gap = -ln(runiform())/exp(-0.3 + 0.4*z1 + 0.4*zl + 0.3*a)
    replace gap = 0.05 + 0.4*runiform() if j == 1
    bysort id (j): gen double t = sum(gap)
    keep if t < 7
    gen double y = 1 + 0.5*a + 0.4*z1 + 1.0*zl + 0.6*k1 + 0.1*t + rnormal()
    keep id t y a z1 zl k1
    sort id t
    bysort id (t): gen int seq = _n
end

* Recording wrapper. bootstrap runs it once on the observed data (no idcluster
* variable yet) and then once per replicate on the resampled panel, where the
* idcluster variable names each drawn cluster and id still holds the subject.
capture program drop _bsrec
program define _bsrec, eclass
    version 16.0
    syntax varlist [if], NEWid(name)
    marksample touse
    global BSREC_K = $BSREC_K + 1
    capture confirm variable `newid'
    if _rc == 0 & $BSREC_K > 0 {
        preserve
        quietly keep if `touse'
        quietly keep id `newid'
        quietly duplicates drop
        quietly rename `newid' nid
        quietly gen int rep = $BSREC_K
        capture append using "$BSREC_FILE"
        quietly save "$BSREC_FILE", replace
        restore
    }
    quietly regress `varlist' if `touse'
end

local arms iiw iptw fiptiw
foreach arm of local arms {
    mkfix, nsub(`NSUB') seed(`DSEED')
    local wt "iivw"
    local vis "visit_cov(z1 zl)"
    local trt ""
    local mf  "maxfu(7)"
    if "`arm'" == "iptw" {
        local wt "iptw"
        local vis ""
        local mf  ""
    }
    if "`arm'" == "fiptiw" local wt "fiptiw"
    if inlist("`arm'", "iptw", "fiptiw") local trt "treat(a) treat_cov(k1)"
    quietly iivw_weight, id(id) time(t) `vis' `trt' wtype(`wt') `mf' nolog
    quietly export delimited id seq t y a z1 zl k1 ///
        using "`ref_dir'/panel_`arm'.csv", replace

    * ---- record the draws the prefix makes under this seed
    global BSREC_K = -1
    global BSREC_FILE "`ref_dir'/draws_`arm'.dta"
    capture erase "$BSREC_FILE"
    set seed `BSEED'
    quietly bootstrap, reps(`B') cluster(id) idcluster(__bsid) nodots: ///
        _bsrec y a z1 t, newid(__bsid)
    preserve
    quietly use "`ref_dir'/draws_`arm'.dta", clear
    quietly export delimited rep nid id using "`ref_dir'/draws_`arm'.csv", replace
    quietly count
    local ndraw_`arm' = r(N)
    quietly bysort rep: gen byte _one = (_n == 1)
    quietly count if _one
    local nrep_`arm' = r(N)
    quietly egen _cnt = count(nid), by(rep)
    quietly summarize _cnt, meanonly
    local cmin_`arm' = r(min)
    local cmax_`arm' = r(max)
    restore

    * ---- the command under test, default variance, same seed
    quietly iivw_fit y a z1, timespec(linear) ///
        vce(bootstrap, reps(`B') seed(`BSEED')) saving("`ref_dir'/save_`arm'.dta", double replace) nolog
    matrix bobs_`arm' = e(b)
    matrix Vbs_`arm'  = e(V)
    local nreps_`arm' = e(N_reps)
    display as text "arm `arm': recorded `nrep_`arm'' resamples, clusters/resample " ///
        "`cmin_`arm''-`cmax_`arm'', iivw_fit N_reps = `nreps_`arm''" ///
        "  se(a) = " %8.5f sqrt(Vbs_`arm'[1,1])
}

local rok "`ref_dir'/.generated_ok"
shell Rscript "`rscript'" --indir="`ref_dir'" --outdir="`ref_dir'" --maxfu=7 ///
    && touch "`rok'"
capture confirm file "`rok'"
if _rc {
    display as error "R reference generation did not run to completion"
    exit 198
}
quietly import delimited using "`ref_dir'/bootstrap_ref.csv", clear ///
    varnames(1) stringcols(1) asdouble
tempfile ref
quietly save `ref'

foreach arm of local arms {
    * ---- D
    local ok = (`nrep_`arm'' == `B') & (`cmin_`arm'' == `cmax_`arm'') & ///
        (`ndraw_`arm'' == `B' * `cmin_`arm'') & (`nreps_`arm'' == `B')
    if `ok' {
        local ++pass_count
        display "PASS D-`arm': `B' resamples recorded, `cmin_`arm'' clusters each"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' D-`arm'"
        display "FAIL D-`arm': draws incomplete (reps `nrep_`arm'', N_reps `nreps_`arm'')"
    }

    * this arm's R rows, replicates and observed sample kept apart
    quietly use `ref', clear
    quietly keep if arm == "`arm'"
    tempfile refa refo
    quietly save `refo'
    quietly keep if rep > 0
    quietly save `refa'

    * ---- P: replicate-by-replicate and observed coefficients
    * saved columns follow e(b): a z1 t _cons (saving() was asked for doubles)
    quietly use "`ref_dir'/save_`arm'.dta", clear
    quietly describe, short
    local nsave = r(N)
    quietly rename (*) (sb1 sb2 sb3 sb4)
    quietly gen int rep = _n
    tempfile sv
    quietly save `sv'
    quietly use `refa', clear
    quietly merge 1:1 rep using `sv', keep(match) nogenerate
    quietly count
    local nmatch = r(N)
    local tol = cond("`arm'" == "iiw", 1e-9, 1e-6)
    local prd = 0
    forvalues k = 1/4 {
        quietly gen double rd`k' = abs(sb`k' - b`k') / max(abs(b`k'), 1e-8)
        quietly summarize rd`k', meanonly
        if r(max) > `prd' local prd = r(max)
    }
    * observed sample
    quietly use `refo', clear
    quietly keep if rep == 0
    local ord = 0
    forvalues k = 1/4 {
        local rv = b`k'[1]
        local sv_ = bobs_`arm'[1, `k']
        local d = abs(`sv_' - `rv') / max(abs(`rv'), 1e-8)
        if `d' > `ord' local ord = `d'
    }
    display as text "P `arm': replicates matched `nmatch'/`B'  max reldif " %10.3e `prd' ///
        "  observed max reldif " %10.3e `ord'
    if `nmatch' == `B' & !missing(`prd', `ord') & `prd' < `tol' & `ord' < `tol' {
        local ++pass_count
        display "PASS P-`arm': every replicate's refit coefficients match R on the same resample"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' P-`arm'"
        display "FAIL P-`arm': replicate parity with the R refit"
    }

    * ---- S: bootstrap SE
    quietly use `refa', clear
    local srd = 0
    forvalues k = 1/4 {
        quietly summarize b`k'
        local rsd = r(sd)
        local isd = sqrt(Vbs_`arm'[`k', `k'])
        local d = abs(`isd' - `rsd') / `rsd'
        if `d' > `srd' local srd = `d'
    }
    display as text "S `arm': max reldif of bootstrap SE vs SD of R replicates " %10.3e `srd'
    if !missing(`srd') & `srd' < `tol' {
        local ++pass_count
        display "PASS S-`arm': the reported bootstrap SE equals the SD of R's refit replicates"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' S-`arm'"
        display "FAIL S-`arm': bootstrap SE differs from the R replicate SD"
    }

    * ---- N: negative control, replicate r against R's replicate r+1
    quietly use `sv', clear
    quietly replace rep = rep - 1
    quietly keep if rep >= 1
    quietly merge 1:1 rep using `refa', keep(match) nogenerate
    quietly gen double shift = abs(sb1 - b1) / max(abs(b1), 1e-8)
    quietly summarize shift, detail
    local shmed = r(p50)
    if !missing(`shmed') & !missing(`prd') & `prd' > 0 & `shmed' > 1000 * `prd' {
        local ++pass_count
        display "PASS N-`arm': a different resample is >1000x farther (median " %9.3e `shmed' ")"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' N-`arm'"
        display "FAIL N-`arm': parity cannot tell this resample from the next"
    }
}

**# SUMMARY

iivw_qa_summary, name(crossval_iivw_bootstrap_survival) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed_tests'")
