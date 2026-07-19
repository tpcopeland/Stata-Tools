* test_iivw_contract.do
* RB-07 iivw contract validation for psdash.
*
* The pre-RB-07 version of this suite FABRICATED iivw dataset characteristics
* (a hand-written _iivw_weighted "1" with no signature) and asserted that psdash
* ACCEPTED them and dispatched diagnostics. The audit (C1/C2) showed that exact
* state is rejected by iivw's own guard (_iivw_check_weighted, r(459)) -- psdash
* was trusting a label the producer no longer considers valid. The suite now:
*   (1) runs the REAL iivw producer, confirms psdash accepts the verified contract
*       and dispatches on the genuine variables, and confirms psdash fails closed
*       when that verified data is then tampered with (rows dropped, signature
*       blanked); and
*   (2) confirms that fabricated/unverifiable iivw metadata is rejected whether or
*       not the iivw package is installed (the released-user reality).
*
* Fail-on-old: against shipped psdash 1.4.1, the fabricated-metadata cases below
* were ACCEPTED (source=iivw, rc=0); every reject assertion here fails on old.
*
* Usage: cd psdash/qa && stata-mp -b do test_iivw_contract.do

clear all
version 16.0
set more off

capture log close _all
log using "test_iivw_contract.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

local test_count = 0
global IIVW_PASS = 0
global IIVW_FAIL = 0
global IIVW_FAILED ""

capture program drop _ct
program define _ct
    args id rc
    if `rc' == 0 {
        display as result "  PASS: `id'"
        global IIVW_PASS = $IIVW_PASS + 1
    }
    else {
        display as error "  FAIL: `id' (rc=`rc')"
        global IIVW_FAIL = $IIVW_FAIL + 1
        global IIVW_FAILED "$IIVW_FAILED `id'"
    }
end

* Install the real iivw producer from its Stata-Tools sibling (relocatable). If
* it is not available, the real-producer positive controls are skipped, but the
* fabricated-metadata reject tests still run (fail closed via the not-installed
* path of _psdash_verify_producer).
capture ado uninstall iivw
capture net install iivw, from("`pkg_dir'/../iivw") replace
local iivw_ok = 0
capture which iivw_weight
if _rc == 0 local iivw_ok = 1
display as text "iivw producer available: `iivw_ok'"

capture program drop _iivw_real_contract
program define _iivw_real_contract
    * Build a genuine, signed iivw treatment-IPTW (FIPTIW) contract.
    version 16.0
    clear
    set seed 20260417
    set obs 320
    gen long id = ceil(_n/4)
    bysort id: gen byte visit = _n
    gen double days = (visit - 1) * 90 + runiform() * 20
    replace days = 0 if visit == 1
    gen double edss_bl = 2 + 3 * runiform()
    bysort id: replace edss_bl = edss_bl[1]
    gen double age = 35 + 15 * runiform()
    bysort id: replace age = age[1]
    gen byte sex = runiform() > 0.5
    bysort id: replace sex = sex[1]
    gen byte treated = (runiform() < invlogit(-0.8 + 0.5 * edss_bl))
    bysort id: replace treated = treated[1]
    gen double edss = edss_bl + 0.012 * days - 0.7 * treated + rnormal(0, 0.45)
    gen byte relapse = (runiform() < invlogit(-2 + 0.4 * edss))
    iivw_weight, endatlastvisit id(id) time(days) treat(treated) ///
        treat_cov(edss_bl age sex) visit_cov(edss relapse) wtype(fiptiw) nolog
end

**# T1: fabricated/unsigned iivw metadata is rejected (C1)
* A hand-written contract with no signature must NOT be trusted. With iivw
* installed the guard rejects it (r459); without iivw the not-installed path
* rejects it (r459). Either way, rc != 0 -- old psdash returned source=iivw, r0.
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treated = _n > 50
    gen double _iivw_ps = invlogit(0.3 * rnormal())
    gen double _iivw_tw = 1
    gen double _iivw_weight = 1
    char _dta[_iivw_weighted] "1"
    char _dta[_iivw_weighttype] "iptw"
    char _dta[_iivw_treat] "treated"
    char _dta[_iivw_ps_var] "_iivw_ps"
    char _dta[_iivw_tw_var] "_iivw_tw"
    char _dta[_iivw_weight_var] "_iivw_weight"
    char _dta[_iivw_treat_covars] "_iivw_ps"
    capture noisily psdash overlap, nograph
    assert _rc != 0
}
_ct T1_fabricated_iivw_rejected `=_rc'

if `iivw_ok' {
    **# T2: psdash accepts a REAL, verified iivw contract and dispatches on it
    local ++test_count
    capture noisily {
        _iivw_real_contract
        capture graph drop _all
        psdash combined
        assert "`r(source)'" == "iivw"
        assert "`r(treatment)'" == "treated"
        assert "`r(psvar)'" == "_iivw_ps"
        assert "`r(wvar)'" == "_iivw_tw"
        assert "`r(iivwcomponent)'" == "treatment"
    }
    _ct T2_real_iivw_accepted `=_rc'

    **# T3: balance dispatches on the real iivw treatment covariates
    local ++test_count
    capture noisily {
        _iivw_real_contract
        capture graph drop _all
        psdash balance, loveplot
        assert "`r(source)'" == "iivw"
        assert "`r(varlist)'" == "edss_bl age sex"
        assert "`r(wvar)'" == "_iivw_tw"
    }
    _ct T3_real_iivw_covariates `=_rc'

    **# T4: weights can select the final iivw analysis weight
    local ++test_count
    capture noisily {
        _iivw_real_contract
        capture graph drop _all
        psdash weights, iivwcomponent(final)
        assert "`r(source)'" == "iivw"
        assert "`r(wvar)'" == "_iivw_weight"
        assert "`r(iivwcomponent)'" == "final"
    }
    _ct T4_real_iivw_final_weight `=_rc'

    **# T5: tampering with the verified data fails closed (C2)
    * Drop rows after the contract is signed -> the stored signature no longer
    * matches -> iivw's guard rejects -> psdash refuses to diagnose stale weights.
    local ++test_count
    capture noisily {
        _iivw_real_contract
        drop in 1/4
        capture noisily psdash overlap, nograph
        assert _rc == 459
    }
    _ct T5_tampered_iivw_rejected `=_rc'

    **# T6: blanking the signature (edited contract) fails closed
    local ++test_count
    capture noisily {
        _iivw_real_contract
        char _dta[_iivw_wsig] ""
        capture noisily psdash overlap, nograph
        assert _rc == 459
    }
    _ct T6_unsigned_iivw_rejected `=_rc'

    **# T7: explicit treatment/PS arguments override iivw detection (no guard)
    local ++test_count
    capture noisily {
        _iivw_real_contract
        gen double explicit_ps = invlogit(0.1 + 0.5 * age)
        gen byte explicit_treat = runiform() < explicit_ps
        replace explicit_treat = 0 in 1/5
        replace explicit_treat = 1 in 316/320
        psdash overlap explicit_treat explicit_ps, nograph
        assert "`r(source)'" == "manual"
        assert "`r(treatment)'" == "explicit_treat"
    }
    _ct T7_explicit_override `=_rc'
}
else {
    display as text "  (T2-T7 skipped: iivw producer not installable in this environment)"
}

display as text _n "=== iivw contract summary: $IIVW_PASS passed, $IIVW_FAIL failed ==="

capture ado uninstall iivw
_psdash_qa_cleanup
capture log close _all

display "RESULT: test_iivw_contract tests=`test_count' pass=$IIVW_PASS fail=$IIVW_FAIL"
if $IIVW_FAIL > 0 {
    display as error "Failed tests:$IIVW_FAILED"
    exit 9
}
display as result "ALL PSDASH IIVW CONTRACT TESTS PASSED"
