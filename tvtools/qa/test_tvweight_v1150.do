*! test_tvweight_v1150.do
*! Regression coverage for explicit longitudinal stabilization numerators.
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "test_tvweight_v1150.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global W15_TESTS = 0
global W15_PASS = 0
global W15_FAIL = 0
global W15_FAILED ""

capture program drop _w15_record
program define _w15_record
    args ok code detail
    global W15_TESTS = $W15_TESTS + 1
    if `ok' {
        global W15_PASS = $W15_PASS + 1
        display as result "  PASS: `code'"
    }
    else {
        global W15_FAIL = $W15_FAIL + 1
        global W15_FAILED "$W15_FAILED `code'"
        display as error "  FAIL: `code' (`detail')"
    }
end

set seed 20260810
quietly set obs 200
quietly generate long id = _n
quietly generate double z = rnormal()
quietly expand 4
quietly bysort id: generate byte period = _n - 1
quietly sort id period
quietly generate byte treatment = .
quietly replace treatment = runiform() < invlogit(-.5 + .5*z + .2*period) ///
    if period == 0
quietly replace treatment = runiform() < ///
    invlogit(-1 + 1.6*treatment[_n-1] + .5*z + .2*period) if period > 0
quietly by id (period): generate byte lag_treatment = ///
    cond(period == 0, 0, treatment[_n-1])
quietly generate double confounder = rnormal() + .6*lag_treatment + .3*z
quietly generate byte censored = runiform() < ///
    invlogit(-2.7 + .7*lag_treatment + .4*z + .25*confounder + .15*period)
tempfile panel
quietly save `panel'

display as result "tvtools QA: 1.15.0 longitudinal numerators -- $S_DATE $S_TIME"

**# Treatment numerator matches an independent model oracle
quietly logit treatment z lag_treatment confounder i.period, ///
    nolog vce(cluster id)
quietly predict double den_manual, pr
quietly logit treatment z lag_treatment i.period, nolog
quietly predict double num_manual, pr
quietly generate double sw_manual = cond(treatment, ///
    num_manual / den_manual, (1-num_manual) / (1-den_manual))

capture noisily tvweight treatment, ///
    covariates(c.z i.lag_treatment c.confounder) ///
    numcovariates(c.z i.lag_treatment) id(id) time(period) stabilized ///
    generate(sw_tv) denominator(den_tv) nolog
local treatment_rc = _rc
local treatment_num_model ""
local treatment_num_covars ""
if `treatment_rc' == 0 {
    local treatment_num_model `"`r(numerator_model)'"'
    local treatment_num_covars `"`r(numcovariates)'"'
}
local ok = `treatment_rc' == 0
_w15_record `ok' W15_TREATMENT_RUN "rc=`treatment_rc'"

local max_treatment_diff = .
local max_den_diff = .
if `treatment_rc' == 0 {
    quietly generate double treatment_diff = abs(sw_tv - sw_manual)
    quietly summarize treatment_diff, meanonly
    local max_treatment_diff = r(max)
    quietly generate double den_diff = abs(den_tv - den_manual)
    quietly summarize den_diff, meanonly
    local max_den_diff = r(max)
}
local ok = `treatment_rc' == 0 & `max_treatment_diff' < 1e-10 & ///
    `max_den_diff' < 1e-10
_w15_record `ok' W15_TREATMENT_ORACLE ///
    "weight=`max_treatment_diff' denominator=`max_den_diff'"

local ok = `treatment_rc' == 0 & ///
    `"`treatment_num_model'"' == "z i.lag_treatment i.period" & ///
    `"`treatment_num_covars'"' == "z i.lag_treatment"
_w15_record `ok' W15_TREATMENT_RETURNS ///
    `"model=`treatment_num_model' covariates=`treatment_num_covars'"'

**# Censoring numerator matches an independent cumulative-weight oracle
use `panel', clear
quietly logit censored z lag_treatment confounder i.period, ///
    nolog vce(cluster id)
quietly predict double pc_den, pr
quietly logit censored z lag_treatment i.period, nolog
quietly predict double pc_num, pr
quietly generate double cw_period = (1-pc_num) / (1-pc_den)
quietly _tvweight_cumprod cw_period, id(id) time(period) generate(cw_manual)

capture noisily tvweight treatment, ///
    covariates(c.z i.lag_treatment c.confounder) ///
    numcovariates(c.z i.lag_treatment) id(id) time(period) stabilized cumulative ///
    ipcw(censored) censorcovariates(c.z i.lag_treatment c.confounder) ///
    censnumcovariates(c.z i.lag_treatment) generate(sw2) cumgenerate(sw2_cum) ///
    censgenerate(cw_tv) combgenerate(combined_tv) nolog
local censor_rc = _rc
local censor_num_model ""
local censor_num_covars ""
if `censor_rc' == 0 {
    local censor_num_model `"`r(censor_numerator_model)'"'
    local censor_num_covars `"`r(censnumcovariates)'"'
}
local ok = `censor_rc' == 0
_w15_record `ok' W15_CENSOR_RUN "rc=`censor_rc'"

local max_censor_diff = .
if `censor_rc' == 0 {
    quietly generate double censor_diff = abs(cw_tv - cw_manual)
    quietly summarize censor_diff, meanonly
    local max_censor_diff = r(max)
}
local ok = `censor_rc' == 0 & `max_censor_diff' < 1e-10
_w15_record `ok' W15_CENSOR_ORACLE "weight=`max_censor_diff'"

local ok = `censor_rc' == 0 & ///
    `"`censor_num_model'"' == "z i.lag_treatment i.period" & ///
    `"`censor_num_covars'"' == "z i.lag_treatment"
_w15_record `ok' W15_CENSOR_RETURNS ///
    `"model=`censor_num_model' covariates=`censor_num_covars'"'

**# Defaults remain time-specific and are reported explicitly
use `panel', clear
capture noisily tvweight treatment, ///
    covariates(z lag_treatment confounder) id(id) time(period) ///
    stabilized cumulative ipcw(censored) ///
    censorcovariates(z lag_treatment confounder) ///
    generate(default_sw) cumgenerate(default_sw_cum) ///
    censgenerate(default_cw) combgenerate(default_combined) nolog
local default_rc = _rc
local default_treatment_model ""
local default_censor_model ""
if `default_rc' == 0 {
    local default_treatment_model `"`r(numerator_model)'"'
    local default_censor_model `"`r(censor_numerator_model)'"'
}
local ok = `default_rc' == 0 & ///
    `"`default_treatment_model'"' == "i.period" & ///
    `"`default_censor_model'"' == "i.period"
_w15_record `ok' W15_TIME_DEFAULTS ///
    `"rc=`default_rc' treatment=`default_treatment_model' censor=`default_censor_model'"'

**# Invalid numerator contracts stop before creating outputs
use `panel', clear
capture noisily tvweight treatment, covariates(z lag_treatment) ///
    numcovariates(z) generate(bad1) nolog
local bad1_rc = _rc
capture confirm variable bad1
local ok = `bad1_rc' == 198 & _rc == 111
_w15_record `ok' W15_NUM_REQUIRES_STABILIZED "rc=`bad1_rc'"

capture noisily tvweight treatment, covariates(lag_treatment) ///
    numcovariates(z) stabilized generate(bad2) nolog
local bad2_rc = _rc
capture confirm variable bad2
local ok = `bad2_rc' == 198 & _rc == 111
_w15_record `ok' W15_NUM_SUBSET "rc=`bad2_rc'"

capture noisily tvweight treatment, covariates(z lag_treatment) ///
    censnumcovariates(z) stabilized generate(bad3) nolog
local bad3_rc = _rc
capture confirm variable bad3
local ok = `bad3_rc' == 198 & _rc == 111
_w15_record `ok' W15_CENSNUM_REQUIRES_IPCW "rc=`bad3_rc'"

capture noisily tvweight treatment, covariates(z lag_treatment) ///
    id(id) time(period) ipcw(censored) ///
    censorcovariates(z lag_treatment) censnumcovariates(z) ///
    generate(bad4) nolog
local bad4_rc = _rc
capture confirm variable bad4
local ok = `bad4_rc' == 198 & _rc == 111
_w15_record `ok' W15_CENSNUM_REQUIRES_STABILIZED "rc=`bad4_rc'"

**# The two numerator branches the original 1.15.0 suite never entered
* Every check above uses a binary exposure in panel mode, so the mlogit
* numerator (tvweight.ado, the mlogit arm of the stabilized block) and the
* no-id()/no-time() arm that omits i.time from the numerator both shipped
* without coverage. Each is compared against a reduced model fitted here.

use `panel', clear
quietly generate byte treat3 = treatment
quietly replace treat3 = 2 if runiform() < .3
quietly mlogit treat3 z lag_treatment confounder i.period, ///
    baseoutcome(0) nolog vce(cluster id)
quietly generate double m_den = .
forvalues k = 0/2 {
    quietly predict double m_den`k', pr outcome(`k')
    quietly replace m_den = m_den`k' if treat3 == `k'
}
quietly mlogit treat3 z lag_treatment i.period, baseoutcome(0) nolog
quietly generate double m_num = .
forvalues k = 0/2 {
    quietly predict double m_num`k', pr outcome(`k')
    quietly replace m_num = m_num`k' if treat3 == `k'
}
quietly generate double sw_mlogit_manual = m_num / m_den

capture noisily tvweight treat3, ///
    covariates(c.z i.lag_treatment c.confounder) ///
    numcovariates(c.z i.lag_treatment) id(id) time(period) stabilized ///
    generate(sw_ml) nolog
local mlogit_rc = _rc
local mlogit_model ""
local max_mlogit_diff = .
if `mlogit_rc' == 0 {
    local mlogit_model `"`r(numerator_model)'"'
    quietly generate double mlogit_diff = abs(sw_ml - sw_mlogit_manual)
    quietly summarize mlogit_diff, meanonly
    local max_mlogit_diff = r(max)
}
local ok = `mlogit_rc' == 0 & `max_mlogit_diff' < 1e-10 & ///
    `"`mlogit_model'"' == "z i.lag_treatment i.period"
_w15_record `ok' W15_MLOGIT_NUMERATOR ///
    `"rc=`mlogit_rc' diff=`max_mlogit_diff' model=`mlogit_model'"'

* Without id()/time() the denominator carries no time term, so the numerator
* must not acquire one either: r(numerator_model) is exactly numcovariates().
use `panel', clear
quietly logit treatment z lag_treatment confounder, nolog
quietly predict double np_den, pr
quietly logit treatment z, nolog
quietly predict double np_num, pr
quietly generate double sw_nopanel_manual = cond(treatment, ///
    np_num / np_den, (1-np_num) / (1-np_den))

capture noisily tvweight treatment, ///
    covariates(c.z i.lag_treatment c.confounder) numcovariates(c.z) ///
    stabilized generate(sw_np) nolog
local nopanel_rc = _rc
local nopanel_model ""
local max_nopanel_diff = .
if `nopanel_rc' == 0 {
    local nopanel_model `"`r(numerator_model)'"'
    quietly generate double nopanel_diff = abs(sw_np - sw_nopanel_manual)
    quietly summarize nopanel_diff, meanonly
    local max_nopanel_diff = r(max)
}
local ok = `nopanel_rc' == 0 & `max_nopanel_diff' < 1e-10 & ///
    `"`nopanel_model'"' == "z"
_w15_record `ok' W15_NONPANEL_NUMERATOR ///
    `"rc=`nopanel_rc' diff=`max_nopanel_diff' model=`nopanel_model'"'

display as result "tvtools 1.15.0 numerator regressions: $W15_PASS/$W15_TESTS passed"
display "RESULT: test_tvweight_v1150 tests=$W15_TESTS pass=$W15_PASS fail=$W15_FAIL"
if $W15_FAIL > 0 {
    display as error "Failed tests:$W15_FAILED"
    capture log close _all
    exit 1
}
capture log close _all
