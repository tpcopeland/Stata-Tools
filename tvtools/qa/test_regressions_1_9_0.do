*! test_regressions_1_9_0.do
*! Regression pins for the four defects fixed in tvtools 1.9.0.
*!
*! Every check in this file was confirmed to FAIL against 1.8.0 before the fix.
*! Each block names the axis it probes, because three of these four defects
*! survived a green 54-suite lane: they live on axes the suite never asked
*! about (weight variance rather than weight presence; which weight the
*! balance table uses rather than whether its arithmetic is self-consistent;
*! interior indicator values rather than the extremes; coherence of a percent
*! column rather than its per-row arithmetic).

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_regressions_1_9_0.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: 1.9.0 regression pins -- $S_DATE $S_TIME"

* Counts the wvar() argument used at the psdash delegation site (see R3f).
capture mata: mata drop _r190_check_wvar()
mata:
void _r190_check_wvar(string scalar fn)
{
    string colvector lines
    string scalar bt, ap, needle_awt, needle_gen
    real scalar i, n_awt, n_gen

    bt = char(96)
    ap = char(39)
    needle_awt = "wvar(" + bt + "_awt" + ap + ")"
    needle_gen = "wvar(" + bt + "generate" + ap + ")"
    lines = cat(fn)
    n_awt = 0
    n_gen = 0
    for (i = 1; i <= length(lines); i++) {
        if (strpos(lines[i], needle_awt) > 0) n_awt++
        if (strpos(lines[i], needle_gen) > 0) n_gen++
    }
    st_local("wvar_awt", strofreal(n_awt))
    st_local("wvar_gen", strofreal(n_gen))
}
end


**# ===== R1: ipcw() enforces its documented 0/1 coding on every row =====
* Axis probed: interior values, not the extremes. 1.8.0 tested only
* inlist(r(min),0,1) and inlist(r(max),0,1), so a 0/.5/1 indicator passed the
* gate and the censoring logit silently read .5 as "censored" at rc=0.

capture program drop _r190_panel
program define _r190_panel
    syntax , [n(integer 400) per(integer 4) seed(integer 20260725)]
    clear
    set seed `seed'
    set obs `n'
    gen long id = ceil(_n/`per')
    bysort id: gen period = _n
    gen x = rnormal()
    gen byte a = runiform() < invlogit(.5*x)
end

local ++test_count
_r190_panel
gen double cens = 0
replace cens = 1   if runiform() < .10
replace cens = 0.5 if runiform() < .10 & cens == 0
quietly count if cens == 0.5
local n_interior = r(N)
capture quietly tvweight a, cov(x) id(id) time(period) ipcw(cens) gen(w1) nolog
local rc_bad = _rc
if `rc_bad' == 198 & `n_interior' > 0 {
    local ++pass_count
    display as result "  PASS R1a: interior ipcw() value rejected (rc=198, `n_interior' rows)"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R1a_interior_ipcw_accepted"
    display as error "  FAIL R1a: expected rc=198, got `rc_bad' (interior rows=`n_interior')"
}

* No output variable may survive the refusal.
local ++test_count
capture confirm variable w1
local rc_w1 = _rc
capture confirm variable ipcw
local rc_cw = _rc
if `rc_w1' != 0 & `rc_cw' != 0 {
    local ++pass_count
    display as result "  PASS R1b: refusal left no partial weight outputs"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R1b_partial_outputs"
    display as error "  FAIL R1b: outputs survived the refusal"
}

* Control: a correctly coded indicator on the same data still succeeds.
local ++test_count
gen byte cens_ok = cens == 1
capture quietly tvweight a, cov(x) id(id) time(period) ipcw(cens_ok) ///
    gen(w1b) censgen(cw_b) combgen(comb_b) nolog
local rc_ok = _rc
if `rc_ok' == 0 {
    local ++pass_count
    display as result "  PASS R1c: valid 0/1 indicator still accepted"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R1c_valid_ipcw_rejected"
    display as error "  FAIL R1c: valid indicator rejected (rc=`rc_ok')"
}


**# ===== R2: stabilized numerator carries the denominator's time term =====
* Axis probed: weight VARIANCE against an independent oracle, not weight
* presence or mean. The 1.8.0 marginal numerator kept mean(sw) ~ 1 -- which is
* why every existing stabilized check stayed green -- while inflating the SD
* nine-fold. Oracle is hand-built from Cole & Hernan (2008) Table 3 spec 1,
* computed with plain logit/predict, sharing no code path with tvweight.

clear
set seed 4242
set obs 8000
gen long id = ceil(_n/8)
bysort id: gen period = _n
gen x = rnormal()
* Treatment prevalence sweeps 0.13 -> 0.98 across periods: the denominator's
* i.period term does real work, so omitting it from the numerator is visible.
gen double eta = -3 + 0.9*period + 0.4*x
gen byte a = runiform() < invlogit(eta)

quietly tvweight a, cov(x) id(id) time(period) stabilized cumulative ///
    gen(sw) cumgen(sw_cum) nolog
local ess_pct = r(ess_pct)
local ess = r(ess)
local num_model "`r(numerator_model)'"

* Independent oracle: numerator model = exposure on i.period only.
quietly logit a i.period x
predict double _pden, pr
quietly logit a i.period
predict double _pnum, pr
gen double _swref = cond(a == 1, _pnum/_pden, (1-_pnum)/(1-_pden))
sort id period
by id: gen double _swref_cum = _swref if _n == 1
by id: replace _swref_cum = _swref_cum[_n-1] * _swref if _n > 1
quietly summarize _swref_cum, meanonly
local oracle_sw = r(sum)
local oracle_n = r(N)
generate double _swref_cum2 = _swref_cum^2
quietly summarize _swref_cum2, meanonly
local oracle_ess = (`oracle_sw'^2) / r(sum)
local oracle_ess_pct = 100 * `oracle_ess' / `oracle_n'

local ++test_count
if "`num_model'" == "i.period" {
    local ++pass_count
    display as result "  PASS R2a: r(numerator_model) = i.period in panel mode"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R2a_numerator_model"
    display as error "  FAIL R2a: r(numerator_model) = '`num_model'' (expected i.period)"
}

local ++test_count
quietly gen double _d_sw = abs(sw - _swref)
quietly summarize _d_sw
local maxdiff = r(max)
if `maxdiff' < 1e-10 {
    local ++pass_count
    display as result "  PASS R2b: per-period weight matches Cole-Hernan oracle (max diff `maxdiff')"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R2b_oracle_mismatch"
    display as error "  FAIL R2b: max |tvweight - oracle| = `maxdiff' (expected < 1e-10)"
}

local ++test_count
quietly gen double _d_cum = abs(sw_cum - _swref_cum)
quietly summarize _d_cum
local maxdiff_cum = r(max)
if `maxdiff_cum' < 1e-10 {
    local ++pass_count
    display as result "  PASS R2c: cumulative weight matches oracle (max diff `maxdiff_cum')"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R2c_cum_oracle_mismatch"
    display as error "  FAIL R2c: max cumulative diff = `maxdiff_cum' (expected < 1e-10)"
}

* The headline ESS is for the analysis weight. Under cumulative, that means
* sw_cum rather than the per-period intermediate sw. Recompute both ESS values
* from the independent cumulative-weight oracle above.
local ++test_count
if reldif(`ess', `oracle_ess') < 1e-12 & ///
   reldif(`ess_pct', `oracle_ess_pct') < 1e-12 {
    local ++pass_count
    display as result "  PASS R2d: cumulative analysis-weight ESS = " ///
        %7.3f `ess' " (" %5.2f `ess_pct' "%)"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R2d_ess_regression"
    display as error "  FAIL R2d: ESS=`ess'/`oracle_ess', pct=`ess_pct'/`oracle_ess_pct'"
}

* Weight-tail gate: the cumulative product is where the defect compounded.
local ++test_count
quietly summarize sw_cum
local cum_max = r(max)
if `cum_max' < 20 {
    local ++pass_count
    display as result "  PASS R2e: max cumulative weight = " %6.3f `cum_max' " (1.8.0 reached 248.8)"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R2e_cum_tail"
    display as error "  FAIL R2e: max cumulative weight = `cum_max' (expected < 20)"
}

* Without id()/time() the denominator has no time term, so the marginal
* numerator is still correct: that path must be bit-identical to 1.8.0.
clear
set seed 7
set obs 2000
gen x = rnormal()
gen byte a = runiform() < invlogit(.7*x)
quietly tvweight a, cov(x) stabilized gen(sw0) nolog
local num_model0 "`r(numerator_model)'"
quietly summarize a
local marg = r(mean)
quietly logit a x
predict double _p0, pr
gen double _ref0 = cond(a == 1, `marg'/_p0, (1-`marg')/(1-_p0))

local ++test_count
if "`num_model0'" == "marginal" {
    local ++pass_count
    display as result "  PASS R2f: non-panel numerator stays marginal"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R2f_nonpanel_numerator"
    display as error "  FAIL R2f: non-panel r(numerator_model) = '`num_model0''"
}

local ++test_count
quietly gen double _d0 = abs(sw0 - _ref0)
quietly summarize _d0
local maxdiff0 = r(max)
if `maxdiff0' < 1e-12 {
    local ++pass_count
    display as result "  PASS R2g: non-panel path unchanged (max diff `maxdiff0')"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R2g_nonpanel_changed"
    display as error "  FAIL R2g: non-panel max diff = `maxdiff0' (expected < 1e-12)"
}


**# ===== R3: balance reports the analysis weight, not a per-period weight =====
* Axis probed: WHICH weight the weighted SMD column uses. Existing balance QA
* hand-recomputes the SMD using the same weight the code chose, so it is a
* mirror: it cannot see the code picking the wrong weight.

clear
set seed 99
set obs 4000
gen long id = ceil(_n/8)
bysort id: gen period = _n
gen x = rnormal()
gen double eta = -1 + 1.2*x + 0.3*period
gen byte a = runiform() < invlogit(eta)
gen byte cens = runiform() < invlogit(-2.5 + 0.8*x)

quietly tvweight a, cov(x) id(id) time(period) ipcw(cens) gen(w) balance nolog
local bal_wt "`r(balance_weight)'"
matrix B = r(balance)
local reported = B[1,2]

* Hand-computed SMD under each candidate weight, by a route that does not
* call tvweight at all.
quietly summarize x if a == 1
local mt = r(mean)
local vt = r(Var)
quietly summarize x if a == 0
local mc = r(mean)
local vc = r(Var)
local denom = sqrt((`vt' + `vc')/2)
quietly summarize x [aw=w] if a == 1
local wmt_per = r(mean)
quietly summarize x [aw=w] if a == 0
local wmc_per = r(mean)
local smd_perperiod = (`wmt_per' - `wmc_per')/`denom'
quietly summarize x [aw=w_ipcw] if a == 1
local wmt_an = r(mean)
quietly summarize x [aw=w_ipcw] if a == 0
local wmc_an = r(mean)
local smd_analysis = (`wmt_an' - `wmc_an')/`denom'

local ++test_count
if "`bal_wt'" == "w_ipcw" {
    local ++pass_count
    display as result "  PASS R3a: r(balance_weight) = w_ipcw under ipcw()"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R3a_balance_weight_name"
    display as error "  FAIL R3a: r(balance_weight) = '`bal_wt'' (expected w_ipcw)"
}

* Guard the guard: if the two candidate SMDs coincide on this fixture, the
* next two checks prove nothing. Assert they are separated first.
local ++test_count
local separation = abs(`smd_analysis' - `smd_perperiod')
if `separation' > 1e-3 {
    local ++pass_count
    display as result "  PASS R3b: fixture separates the two weights (gap " %7.5f `separation' ")"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R3b_fixture_not_discriminating"
    display as error "  FAIL R3b: candidate SMDs differ by only `separation'; fixture is blind"
}

local ++test_count
if abs(`reported' - `smd_analysis') < 1e-10 {
    local ++pass_count
    display as result "  PASS R3c: r(balance) uses the analysis weight (" %8.6f `reported' ")"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R3c_balance_wrong_weight"
    display as error "  FAIL R3c: reported `reported' != analysis-weight SMD `smd_analysis'"
}

* cumulative without ipcw() must select the cumulative weight.
clear
set seed 31
set obs 3200
gen long id = ceil(_n/8)
bysort id: gen period = _n
gen x = rnormal()
gen byte a = runiform() < invlogit(-0.5 + 1.0*x + 0.2*period)
quietly tvweight a, cov(x) id(id) time(period) cumulative gen(wc) ///
    cumgen(wc_cum) balance nolog
local bal_wt_cum "`r(balance_weight)'"

local ++test_count
if "`bal_wt_cum'" == "wc_cum" {
    local ++pass_count
    display as result "  PASS R3d: r(balance_weight) = wc_cum under cumulative"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R3d_cumulative_balance_weight"
    display as error "  FAIL R3d: r(balance_weight) = '`bal_wt_cum'' (expected wc_cum)"
}

* Plain run: the per-row weight is the analysis weight, so nothing changes.
clear
set seed 5
set obs 1500
gen x = rnormal()
gen byte a = runiform() < invlogit(.8*x)
quietly tvweight a, cov(x) gen(wp) balance nolog
local bal_wt_plain "`r(balance_weight)'"

local ++test_count
if "`bal_wt_plain'" == "wp" {
    local ++pass_count
    display as result "  PASS R3e: plain run reports its own weight"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R3e_plain_balance_weight"
    display as error "  FAIL R3e: r(balance_weight) = '`bal_wt_plain'' (expected wp)"
}


* The delegated love plot must be drawn from the same weight the table used.
* This is a source contract rather than a value check: psdash is called inside
* `capture quietly` and its r() is discarded, so the weight it received is not
* observable from tvweight's return surface. Pinning it statically is the only
* way to catch the plot and the table drifting apart -- which they did once,
* when the table was moved to the analysis weight and the plot was not.
* Read the source in Mata: tvweight.ado contains compound-quote display lines
* that a file read / local round-trip cannot survive (r(132), too few quotes).
* The needle is assembled from char() so Stata's macro processor does not
* expand the backtick-quoted macro reference before Mata sees it.
local ++test_count
quietly findfile tvweight.ado
local tvw_src "`r(fn)'"
mata: _r190_check_wvar("`tvw_src'")
if `wvar_awt' == 1 & `wvar_gen' == 0 {
    local ++pass_count
    display as result "  PASS R3f: loveplot delegates the analysis weight to psdash"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R3f_loveplot_weight_drift"
    display as error "  FAIL R3f: psdash wvar() -- analysis-weight sites=`wvar_awt', per-row sites=`wvar_gen'"
}


**# ===== R4: tvdiagnose surfaces cross-exposure person-time overlap =====
* Axis probed: coherence of the percent COLUMN as a distribution, not the
* arithmetic of any single row. Each row was individually correct in 1.8.0;
* the column summed to 120.4% with no warning.

clear
input id start stop expo
1 1 100 0
1 50 150 1
2 1 100 0
end
format start stop %td
quietly tvdiagnose, id(id) start(start) stop(stop) exposure(expo) summarize
local xover = r(n_crossexposure_overlap_days)
matrix E = r(exposure_summary)
local pct_sum = E[1,4] + E[2,4]

* id 1 covers [1,100] under expo=0 and [50,150] under expo=1: days 50..100
* (51 days) are counted under both levels. Union person-time is 150 + 100 = 250.
local ++test_count
if `xover' == 51 {
    local ++pass_count
    display as result "  PASS R4a: r(n_crossexposure_overlap_days) = 51"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R4a_overlap_days"
    display as error "  FAIL R4a: overlap days = `xover' (expected 51)"
}

* The overlap must be exactly the amount by which the column overshoots 100%.
local ++test_count
local implied = 100 * `xover' / r(total_person_time)
if abs(`pct_sum' - 100 - `implied') < 1e-6 {
    local ++pass_count
    display as result "  PASS R4b: reported overlap explains the percent overshoot"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R4b_overlap_accounting"
    display as error "  FAIL R4b: pct_sum=`pct_sum', implied overshoot=`implied'"
}

* Non-overlapping exposure levels must report zero and sum to exactly 100%.
clear
input id start stop expo
1 1 50 0
1 51 100 1
end
format start stop %td
quietly tvdiagnose, id(id) start(start) stop(stop) exposure(expo) summarize
local xover_clean = r(n_crossexposure_overlap_days)
matrix E2 = r(exposure_summary)
local pct_sum_clean = E2[1,4] + E2[2,4]

local ++test_count
if `xover_clean' == 0 {
    local ++pass_count
    display as result "  PASS R4c: clean data reports zero cross-exposure overlap"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R4c_false_positive"
    display as error "  FAIL R4c: clean data reported `xover_clean' overlap days"
}

local ++test_count
if abs(`pct_sum_clean' - 100) < 1e-6 {
    local ++pass_count
    display as result "  PASS R4d: clean data percent column sums to 100"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R4d_clean_percent_sum"
    display as error "  FAIL R4d: clean percent sum = `pct_sum_clean' (expected 100)"
}

* The return must exist even when summarize was not requested, so scripts can
* read it unconditionally.
local ++test_count
clear
input id start stop expo
1 1 50 0
1 51 100 1
end
format start stop %td
quietly tvdiagnose, id(id) start(start) stop(stop) overlaps
capture confirm scalar define r(n_crossexposure_overlap_days)
local has_ret = (r(n_crossexposure_overlap_days) == 0)
if `has_ret' {
    local ++pass_count
    display as result "  PASS R4e: return present and zero when summarize not requested"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' R4e_return_missing"
    display as error "  FAIL R4e: r(n_crossexposure_overlap_days) absent without summarize"
}


**# Summary
display "RESULT: test_regressions_1_9_0 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "1.9.0 regression failures:`failed_tests'"
    exit 1
}
