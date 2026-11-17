*! crossval_longitudinal_cobalt_weightit.do Version 1.0.0  2026/11/17
*! Reference parity for psdash combined's longitudinal route against R cobalt and WeightIt
*! Author: Timothy P Copeland, Karolinska Institutet
* Usage: cd psdash/qa && stata-mp -b do crossval_longitudinal_cobalt_weightit.do
*
* Route: psdash combined on a producer-stamped longitudinal dataset (msm, tte)
* summarises the propensity scores and cumulative weights per period and overall.
* Producers are run for real; the identical analysed rows go to R
* (_longitudinal_reference_psdash.R, regenerated on every run).
*
* Parity-claimable quantities and their reference (definition map):
*   overlap_by_period N, N_treated, N_control      row counts by arm (exact)
*   overlap_by_period mean_treated, mean_control   cobalt bal.tab M.1.Un / M.0.Un of the ps
*   weights_by_period N                            row count (exact)
*   weights_by_period mean, sd                     cobalt col_w_mean, col_w_sd (n-1 SD)
*   weights_by_period max                          WeightIt summary(as.weightit) weight.range max
*   weights_by_period ess_pct                      100 * WeightIt::ESS(w) / N (pooled across arms)
*   weights_by_period ess_treated_pct/_control_pct 100 * summary.weightit effective.sample.size / arm N
*                                                  (cobalt bal.tab Observations Adjusted is a second check)
*   overall mean_wt, sd_wt, cv, min_wt, max_wt     cobalt col_w_mean/col_w_sd, WeightIt weight.range
*   overall ess, ess_pct                           WeightIt::ESS (Kish, pooled across arms)
*   overall p1 p5 p50 p95 p99                      stats::quantile(type = 2), the summarize,detail rule
*   overall n_extreme, pct_extreme                 count and percentage of weights above 10
*   N_periods, periods, matrix row names           distinct period values in the analysed rows
* NOT parity-claimable (no maintained package reports them; covered by the
* recovery suites, not here): per-period min/max propensity score by arm,
* overlap_lower/upper bounds, pct_outside, per-period p95/p99.
*
* Scenarios (each runs the real producer):
*   msm   msm_prepare + msm_weight on msm/msm_example.dta (10 periods)
*   tte   tte_prepare + tte_expand + tte_weight, seed 2026072204
*   msmx  msm_example with a strongly confounded treatment (seed 2026111701):
*         heavy-tailed weights (max above 100, weights above 10 present), so the
*         n_extreme and tail-percentile comparisons are not 0 == 0
* Layout: each scenario needs its producer as a sibling package directory of
* psdash (../msm, ../tte). A scenario whose producer is absent records 5 SKIPs;
* where only msm is a sibling, msm and msmx are the coverage and tte skips. If
* no scenario runs at all, the suite fails rather than passing on zero checks.
* Identical-input rule: only rows psdash analysed (risk-set indicator == 1, no
* missing treat/ps/wt/period) are exported, and the count must equal r(N_complete).
* Tolerance: counts exact; continuous reldif < 1e-10 (full-precision double CSV round trip).

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "crossval_longitudinal_cobalt_weightit.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global PSDASH_LW_TESTS = 0
global PSDASH_LW_PASS = 0
global PSDASH_LW_FAIL = 0
global PSDASH_LW_SKIP = 0
global PSDASH_LW_FAILED ""

capture program drop _psdash_lw_record
program define _psdash_lw_record
    args id rc
    global PSDASH_LW_TESTS = $PSDASH_LW_TESTS + 1
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_LW_PASS = $PSDASH_LW_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_LW_FAIL = $PSDASH_LW_FAIL + 1
        global PSDASH_LW_FAILED "$PSDASH_LW_FAILED `id'"
    }
end

capture program drop _psdash_lw_skip
program define _psdash_lw_skip
    args id why
    global PSDASH_LW_TESTS = $PSDASH_LW_TESTS + 1
    global PSDASH_LW_SKIP = $PSDASH_LW_SKIP + 1
    display as text "SKIP: `id' (`why')"
end

* One reference value by key from the frame psdash_lw_ref; exactly one row must match.
capture program drop _psdash_lw_ref
program define _psdash_lw_ref, rclass
    args key
    quietly frame psdash_lw_ref: count if key == "`key'"
    if r(N) != 1 {
        display as error "reference key `key' matched " r(N) " rows"
        exit 9
    }
    quietly frame psdash_lw_ref: summarize v if key == "`key'"
    return scalar v = r(mean)
end

* Compare a psdash value with the reference value for key; tol = 0 means exact.
capture program drop _psdash_lw_cmp
program define _psdash_lw_cmp
    args key psval tol
    _psdash_lw_ref `key'
    local refv = r(v)
    if missing(`psval') | missing(`refv') {
        display as error "missing value for `key': psdash=`psval' reference=`refv'"
        exit 9
    }
    if `tol' == 0 {
        assert !missing(`psval') & !missing(`refv') & `psval' == `refv'
    }
    else {
        assert !missing(`psval') & !missing(`refv') & reldif(`psval', `refv') < `tol'
        scalar psdash_lw_worst = max(scalar(psdash_lw_worst), reldif(`psval', `refv'))
    }
end

* Build the producer dataset for one scenario; leaves it in memory.
capture program drop _psdash_lw_build
program define _psdash_lw_build
    args tag repo_dir
    if "`tag'" == "msm" | "`tag'" == "msmx" {
        use "`repo_dir'/msm/msm_example.dta", clear
        if "`tag'" == "msmx" {
            set seed 2026111701
            quietly summarize biomarker
            generate double zb = (biomarker - r(mean)) / r(sd)
            quietly replace treatment = runiform() < ///
                invlogit(-0.8 + 2.6 * zb + 1.2 * comorbidity)
            drop zb
        }
        quietly msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) covariates(biomarker comorbidity age sex)
        quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
            treat_n_cov(age sex) nolog
    }
    else {
        quietly {
            clear
            set seed 2026072204
            set obs 900
            generate long patid = ceil(_n / 3)
            bysort patid: generate byte period = _n - 1
            generate double age = 35 + 20 * runiform() if period == 0
            bysort patid (period): replace age = age[1]
            generate byte sex = runiform() > 0.5 if period == 0
            bysort patid (period): replace sex = sex[1]
            generate byte comorbidity = runiform() < 0.30 if period == 0
            bysort patid (period): replace comorbidity = comorbidity[1]
            generate double biomarker = rnormal(0.20 * period + 0.35 * comorbidity, 1)
            generate byte treatment = runiform() < invlogit(-0.35 + 0.25 * sex + ///
                0.20 * comorbidity + 0.15 * biomarker + 0.10 * period)
            generate byte eligible = period == 0
            generate byte outcome = period == 2 & runiform() < ///
                invlogit(-2.2 + 0.45 * treatment + 0.25 * comorbidity)
        }
        quietly tte_prepare, id(patid) period(period) treatment(treatment) ///
            outcome(outcome) eligible(eligible) ///
            covariates(age sex comorbidity biomarker) estimand(PP)
        quietly tte_expand, maxfollowup(2) grace(1)
        quietly tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
            switch_n_cov(age sex) save_ps truncate(1 99) nolog
    }
end

**# Dependency and layout checks

local qa_dir_len = strlen("`qa_dir'")
local pkg_dir "`qa_dir'"
if substr("`qa_dir'", `qa_dir_len' - 2, 3) == "/qa" {
    local pkg_dir = substr("`qa_dir'", 1, `qa_dir_len' - 3)
}
local repo_dir = substr("`pkg_dir'", 1, strlen("`pkg_dir'") - strlen("/psdash"))

tempfile r_dep_ok r_run_ok lw_in lw_ref
capture erase "`r_dep_ok'"
shell Rscript -e "quit(status=ifelse(requireNamespace('cobalt', quietly=TRUE) && requireNamespace('WeightIt', quietly=TRUE), 0, 1))" > /dev/null 2>&1 && touch "`r_dep_ok'"
capture confirm file "`r_dep_ok'"
if _rc {
    display as text "SKIP (dependency): Rscript, R package cobalt, or R package WeightIt unavailable"
    display as text "RESULT: crossval_longitudinal_cobalt_weightit tests=0 pass=0 fail=0 skip=0 skipped=dependency_unavailable"
    _psdash_qa_cleanup
    macro drop PSDASH_LW_TESTS PSDASH_LW_PASS PSDASH_LW_FAIL PSDASH_LW_SKIP PSDASH_LW_FAILED
    capture log close _all
    exit 77
}

local tol 1e-10
scalar psdash_lw_worst = 0

**# Scenarios

foreach tag in msm tte msmx {

    * producer package for this scenario
    local producer = cond("`tag'" == "tte", "tte", "msm")
    local fixture_ok = fileexists("`repo_dir'/`producer'/`producer'.pkg")
    if "`producer'" == "msm" {
        local fixture_ok = `fixture_ok' & fileexists("`repo_dir'/msm/msm_example.dta")
    }
    if !`fixture_ok' {
        foreach part in reference_generated overlap_by_period weights_by_period ///
            overall_weights period_index {
            _psdash_lw_skip `tag'_`part' "`producer' producer fixture unavailable"
        }
        continue
    }

    **## Producer, psdash combined, R reference

    capture frame drop psdash_lw_ref
    capture noisily {
        quietly net install `producer', from("`repo_dir'/`producer'") replace
        _psdash_lw_build `tag' "`repo_dir'"
        quietly psdash combined
        assert r(longitudinal) == 1
        assert "`r(source)'" == "`producer'"
        local n_complete = r(N_complete)
        local n_periods = r(N_periods)
        local periods "`r(periods)'"
        local k_id "`r(id)'"
        local k_ps "`r(psvar)'"
        local k_wt "`r(wvar)'"
        local k_tr "`r(treatment)'"
        local k_pd "`r(period)'"
        local k_rk "`r(riskvar)'"
        local ps_n_extreme = r(n_extreme)
        local ps_pct_extreme = r(pct_extreme)
        local ps_mean = r(mean_wt)
        local ps_sd = r(sd_wt)
        local ps_cv = r(cv)
        local ps_min = r(min_wt)
        local ps_max = r(max_wt)
        local ps_ess = r(ess)
        local ps_ess_pct = r(ess_pct)
        local ps_p1 = r(p1)
        local ps_p5 = r(p5)
        local ps_p50 = r(p50)
        local ps_p95 = r(p95)
        local ps_p99 = r(p99)
        matrix psdash_lw_O = r(overlap_by_period)
        matrix psdash_lw_W = r(weights_by_period)

        * identical-input rule: export the rows psdash analysed
        foreach v in k_ps k_wt {
            local t : type ``v''
            assert "`t'" == "double"
        }
        keep if !missing(`k_tr', `k_ps', `k_wt', `k_pd')
        if "`k_rk'" != "" keep if `k_rk' == 1
        assert _N == `n_complete'
        keep `k_id' `k_pd' `k_tr' `k_ps' `k_wt'
        local old "`k_id' `k_pd' `k_tr' `k_ps' `k_wt'"
        local new "id period treat ps wt"
        forvalues i = 1/5 {
            local o : word `i' of `old'
            local n : word `i' of `new'
            if "`o'" != "`n'" rename `o' `n'
        }
        assert inlist(treat, 0, 1)
        export delimited id period treat ps wt using "`lw_in'", replace

        capture erase "`r_run_ok'"
        capture erase "`lw_ref'"
        shell Rscript "`qa_dir'/_longitudinal_reference_psdash.R" ///
            "`lw_in'" "`lw_ref'" && touch "`r_run_ok'"
        confirm file "`r_run_ok'"
        confirm file "`lw_ref'"

        frame create psdash_lw_ref
        frame psdash_lw_ref {
            import delimited using "`lw_ref'", varnames(1) stringcols(_all) clear
            generate double v = real(value)
            generate key = scope + "_" + metric
            assert !missing(v)
            assert _N > 20
        }
        * the R side saw the same row count and period count as psdash
        _psdash_lw_cmp all_n `n_complete' 0
        _psdash_lw_cmp all_n_periods `n_periods' 0
    }
    _psdash_lw_record `tag'_reference_generated `=_rc'

    **## Per-period overlap counts and unweighted propensity-score means by arm

    capture noisily {
        local cn : colnames psdash_lw_O
        assert word("`cn'", 1) == "N" & word("`cn'", 2) == "N_treated" & ///
            word("`cn'", 3) == "N_control" & word("`cn'", 4) == "mean_treated" & ///
            word("`cn'", 5) == "mean_control"
        local rn : rownames psdash_lw_O
        assert rowsof(psdash_lw_O) == `n_periods'
        local j 0
        foreach r of local rn {
            local ++j
            local pv = substr("`r'", 2, .)
            _psdash_lw_cmp p`pv'_n psdash_lw_O[`j',1] 0
            _psdash_lw_cmp p`pv'_n_t psdash_lw_O[`j',2] 0
            _psdash_lw_cmp p`pv'_n_c psdash_lw_O[`j',3] 0
            assert psdash_lw_O[`j', 1] == psdash_lw_O[`j', 2] + psdash_lw_O[`j', 3]
            _psdash_lw_cmp p`pv'_mean_t psdash_lw_O[`j',4] `tol'
            _psdash_lw_cmp p`pv'_mean_c psdash_lw_O[`j',5] `tol'
        }
    }
    _psdash_lw_record `tag'_overlap_by_period `=_rc'

    **## Per-period weight summaries and effective sample sizes

    capture noisily {
        local cn : colnames psdash_lw_W
        assert "`cn'" == "N mean sd p95 p99 max ess_pct ess_treated_pct ess_control_pct"
        local rn : rownames psdash_lw_W
        assert rowsof(psdash_lw_W) == `n_periods'
        local j 0
        foreach r of local rn {
            local ++j
            local pv = substr("`r'", 2, .)
            _psdash_lw_cmp p`pv'_n psdash_lw_W[`j',1] 0
            _psdash_lw_cmp p`pv'_wt_mean psdash_lw_W[`j',2] `tol'
            _psdash_lw_cmp p`pv'_wt_sd psdash_lw_W[`j',3] `tol'
            _psdash_lw_cmp p`pv'_wt_max psdash_lw_W[`j',6] `tol'
            _psdash_lw_cmp p`pv'_ess_pct psdash_lw_W[`j',7] `tol'
            _psdash_lw_cmp p`pv'_ess_t_pct psdash_lw_W[`j',8] `tol'
            _psdash_lw_cmp p`pv'_ess_c_pct psdash_lw_W[`j',9] `tol'
            * second reference: cobalt's own adjusted-sample arm ESS
            _psdash_lw_cmp p`pv'_cb_ess_t_pct psdash_lw_W[`j',8] `tol'
            _psdash_lw_cmp p`pv'_cb_ess_c_pct psdash_lw_W[`j',9] `tol'
        }
    }
    _psdash_lw_record `tag'_weights_by_period `=_rc'

    **## Overall weight summary

    capture noisily {
        _psdash_lw_cmp all_mean `ps_mean' `tol'
        _psdash_lw_cmp all_sd `ps_sd' `tol'
        _psdash_lw_cmp all_cv `ps_cv' `tol'
        _psdash_lw_cmp all_min `ps_min' `tol'
        _psdash_lw_cmp all_max `ps_max' `tol'
        _psdash_lw_cmp all_ess `ps_ess' `tol'
        _psdash_lw_cmp all_ess_pct `ps_ess_pct' `tol'
        _psdash_lw_cmp all_p1 `ps_p1' `tol'
        _psdash_lw_cmp all_p5 `ps_p5' `tol'
        _psdash_lw_cmp all_p50 `ps_p50' `tol'
        _psdash_lw_cmp all_p95 `ps_p95' `tol'
        _psdash_lw_cmp all_p99 `ps_p99' `tol'
        _psdash_lw_cmp all_n_extreme `ps_n_extreme' 0
        _psdash_lw_cmp all_pct_extreme `ps_pct_extreme' `tol'
        * the strongly confounded scenario must really exercise the extreme-weight tail
        if "`tag'" == "msmx" {
            _psdash_lw_ref all_n_extreme
            assert !missing(r(v)) & r(v) > 0
            _psdash_lw_ref all_max
            assert !missing(r(v)) & r(v) > 10
        }
    }
    _psdash_lw_record `tag'_overall_weights `=_rc'

    **## Period labels map to the reference periods

    capture noisily {
        assert `n_periods' == wordcount("`periods'")
        assert `n_periods' == rowsof(psdash_lw_O)
        assert `n_periods' == rowsof(psdash_lw_W)
        local rnO : rownames psdash_lw_O
        local rnW : rownames psdash_lw_W
        assert "`rnO'" == "`rnW'"
        local j 0
        foreach pv of local periods {
            local ++j
            local rO : word `j' of `rnO'
            assert "`rO'" == "p`pv'"
            * every psdash period exists in the reference with the same row count
            _psdash_lw_ref p`pv'_n
            assert !missing(r(v)) & r(v) == psdash_lw_O[`j', 1]
        }
    }
    _psdash_lw_record `tag'_period_index `=_rc'

    capture frame drop psdash_lw_ref
    capture matrix drop psdash_lw_O
    capture matrix drop psdash_lw_W
}

display as text _newline "Worst continuous reldif against cobalt/WeightIt: " %9.2e scalar(psdash_lw_worst)
local worst_ok = !missing(scalar(psdash_lw_worst)) & scalar(psdash_lw_worst) < `tol'
scalar drop psdash_lw_worst

**# Summary

display as text "RESULT: crossval_longitudinal_cobalt_weightit tests=$PSDASH_LW_TESTS pass=$PSDASH_LW_PASS fail=$PSDASH_LW_FAIL skip=$PSDASH_LW_SKIP"

local final_fail = $PSDASH_LW_FAIL
if $PSDASH_LW_PASS + $PSDASH_LW_FAIL == 0 {
    display as error "no producer scenario ran (no sibling msm or tte package); zero parity checks is a failure"
    local final_fail = 1
    global PSDASH_LW_FAILED "$PSDASH_LW_FAILED no_scenario_ran"
}
local failed "$PSDASH_LW_FAILED"
macro drop PSDASH_LW_TESTS PSDASH_LW_PASS PSDASH_LW_FAIL PSDASH_LW_SKIP PSDASH_LW_FAILED
_psdash_qa_cleanup
capture log close _all

if `final_fail' | !`worst_ok' {
    display as error "Failed tests:`failed'"
    exit 9
}
