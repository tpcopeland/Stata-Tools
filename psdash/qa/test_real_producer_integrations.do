* test_real_producer_integrations.do
* Execute each available producer and verify psdash accepts its genuine contract.

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "test_real_producer_integrations.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

local repo_dir = substr("`pkg_dir'", 1, strlen("`pkg_dir'") - strlen("/psdash"))
local tests = 0
global PSDASH_RPI_PASS = 0
global PSDASH_RPI_FAIL = 0
local skip = 0
local failed ""

capture program drop _rpi_record
program define _rpi_record
    args id rc
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_RPI_PASS = $PSDASH_RPI_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_RPI_FAIL = $PSDASH_RPI_FAIL + 1
        c_local failed "`failed' `id'"
    }
end

capture program drop _rpi_foreign_estimates
program define _rpi_foreign_estimates, eclass
    tempname foreign_b
    matrix `foreign_b' = 0
    ereturn post `foreign_b'
    ereturn local cmd "foreign_estimator"
    ereturn local contract_version "999"
end

local ++tests
if fileexists("`repo_dir'/iivw/iivw.pkg") {
    capture noisily {
        quietly net install iivw, from("`repo_dir'/iivw") replace
        clear
        set seed 2026072201
        set obs 320
        generate long id = ceil(_n / 4)
        bysort id: generate byte visit = _n
        generate double days = (visit - 1) * 90 + runiform() * 20
        replace days = 0 if visit == 1
        generate double edss_bl = 2 + 3 * runiform()
        bysort id: replace edss_bl = edss_bl[1]
        generate double age = 35 + 15 * runiform()
        bysort id: replace age = age[1]
        generate byte sex = runiform() > 0.5
        bysort id: replace sex = sex[1]
        generate byte treated = runiform() < invlogit(-0.8 + 0.5 * edss_bl)
        bysort id: replace treated = treated[1]
        generate double edss = edss_bl + 0.012 * days - 0.7 * treated + rnormal(0, 0.45)
        generate byte relapse = runiform() < invlogit(-2 + 0.4 * edss)
        quietly iivw_weight, endatlastvisit id(id) time(days) treat(treated) ///
            treat_cov(edss_bl age sex) visit_cov(edss relapse) ///
            wtype(fiptiw) nolog
        quietly psdash overlap, nograph
        assert "`r(source)'" == "iivw"
        assert "`: char _dta[_iivw_contract_version]'" == "3"
    }
    _rpi_record real_iivw_contract `=_rc'
}
else {
    local ++skip
    display as text "SKIP: iivw producer directory unavailable"
}

local ++tests
if fileexists("`repo_dir'/msm/msm.pkg") & fileexists("`repo_dir'/msm/msm_example.dta") {
    capture noisily {
        quietly net install msm, from("`repo_dir'/msm") replace
        use "`repo_dir'/msm/msm_example.dta", clear
        quietly msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) covariates(biomarker comorbidity age sex)
        quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
            treat_n_cov(age sex) nolog
        quietly psdash detect
        assert "`r(source)'" == "msm"
        assert "`: char _dta[_msm_contract_version]'" == "1.0"
    }
    _rpi_record real_msm_contract `=_rc'
}
else {
    local ++skip
    display as text "SKIP: msm producer fixture unavailable"
}

local ++tests
if fileexists("`repo_dir'/tte/tte.pkg") {
    capture noisily {
        quietly net install tte, from("`repo_dir'/tte") replace
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
        generate byte treatment = runiform() < ///
            invlogit(-0.35 + 0.25 * sex + 0.20 * comorbidity + ///
            0.15 * biomarker + 0.10 * period)
        generate byte eligible = period == 0
        generate byte outcome = period == 2 & runiform() < ///
            invlogit(-2.2 + 0.45 * treatment + 0.25 * comorbidity)
        quietly tte_prepare, id(patid) period(period) treatment(treatment) ///
            outcome(outcome) eligible(eligible) ///
            covariates(age sex comorbidity biomarker) ///
            estimand(PP)
        quietly tte_expand, maxfollowup(2) grace(1)
        quietly tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
            switch_n_cov(age sex) save_ps ///
            truncate(1 99) nolog
        quietly psdash detect
        assert "`r(source)'" == "tte"
        assert "`: char _dta[_tte_contract_version]'" == "1.0"
    }
    _rpi_record real_tte_contract `=_rc'
}
else {
    local ++skip
    display as text "SKIP: tte development producer unavailable"
}

local ++tests
if fileexists("`repo_dir'/targetlearn/targetlearn.pkg") {
    capture noisily {
        quietly net install targetlearn, from("`repo_dir'/targetlearn") replace
        clear
        set seed 2026072202
        set obs 300
        generate double x1 = rnormal()
        generate double x2 = rnormal()
        generate double ps_true = invlogit(-0.25 + 0.45*x1 - 0.20*x2)
        generate byte treat = runiform() < ps_true
        generate double y = 1 + 1.25*treat + 0.40*x1 + 0.25*x2 + rnormal(0, 0.7)
        quietly tmle x1 x2, outcome(y) treatment(treat) nolog
        quietly psdash overlap, nograph
        assert "`r(source)'" == "tmle"
        _rpi_foreign_estimates
        quietly psdash overlap, nograph
        assert "`r(source)'" == "tmle"
        assert "`: char _dta[_tmle_contract_version]'" == "1.0"
        tempfile tmle_saved
        save "`tmle_saved'", replace
        ereturn clear
        use "`tmle_saved'", clear
        foreach helper in _tmle_get_context _tmle_check_estimated _tmle_lib {
            capture program drop `helper'
        }
        quietly psdash overlap, nograph
        assert "`r(source)'" == "tmle"
    }
    _rpi_record real_tmle_contract `=_rc'
}
else {
    local ++skip
    display as text "SKIP: tmle development producer unavailable"
}

local ++tests
if fileexists("`repo_dir'/targetlearn/targetlearn.pkg") {
    capture noisily {
        quietly net install targetlearn, from("`repo_dir'/targetlearn") replace
        clear
        set seed 2026072203
        set obs 360
        generate long pid = ceil(_n / 3)
        bysort pid: generate byte period = _n
        generate double bl_x = rnormal() if period == 1
        bysort pid (period): replace bl_x = bl_x[1]
        generate double tv_x = rnormal() + 0.10*period + 0.15*bl_x
        * Balanced assignment keeps this contract test focused on producer
        * persistence/provenance rather than intentionally triggering a weight warning.
        generate byte a_treat = runiform() < 0.5
        generate byte y_out = runiform() < ///
            invlogit(-1.2 + 0.35*bl_x + 0.25*tv_x + 0.70*a_treat)
        generate byte y_terminal = y_out if period == 3
        quietly ltmle, id(pid) period(period) outcome(y_terminal) ///
            treatment(a_treat) covariates(tv_x) baseline(bl_x) nolog
        quietly psdash detect
        assert "`r(source)'" == "ltmle"
        * ltmle_surv is a valid active LTMLE contract too.  Its e(cmd) differs
        * from ltmle, so this exercises psdash's producer gate rather than the
        * ordinary ltmle path above.
        quietly ltmle_surv, id(pid) period(period) event(y_out) ///
            treatment(a_treat) covariates(tv_x) baseline(bl_x) nolog
        assert "`e(cmd)'" == "ltmle_surv"
        quietly psdash detect
        assert "`r(source)'" == "ltmle"
        _rpi_foreign_estimates
        quietly psdash detect
        assert "`r(source)'" == "ltmle"
        assert "`: char _dta[_ltmle_contract_version]'" == "1.0"
        tempfile ltmle_saved
        save "`ltmle_saved'", replace
        ereturn clear
        use "`ltmle_saved'", clear
        foreach helper in _ltmle_get_context _ltmle_check_estimated _ltmle_lib {
            capture program drop `helper'
        }
        quietly psdash detect
        assert "`r(source)'" == "ltmle"
    }
    _rpi_record real_ltmle_contract `=_rc'
}
else {
    local ++skip
    display as text "SKIP: ltmle development producer unavailable"
}

display as text _n "RESULT: test_real_producer_integrations tests=`tests' pass=$PSDASH_RPI_PASS fail=$PSDASH_RPI_FAIL skip=`skip'"
if $PSDASH_RPI_FAIL > 0 {
    display as error "Failed tests:`failed'"
    _psdash_qa_cleanup
    macro drop PSDASH_RPI_PASS PSDASH_RPI_FAIL
    capture log close _all
    exit 9
}

_psdash_qa_cleanup
macro drop PSDASH_RPI_PASS PSDASH_RPI_FAIL
capture log close _all
if `skip' > 0 exit 77
