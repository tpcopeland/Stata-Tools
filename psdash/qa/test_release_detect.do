* test_release_detect.do -- release regression checks for detection/state handling
* Usage: cd psdash/qa && stata-mp -b do test_release_detect.do

clear all
version 16.0

capture log close _all
log using "test_release_detect.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"

global PSDASH_RD_TEST = 0
global PSDASH_RD_PASS = 0
global PSDASH_RD_FAIL = 0

capture program drop _rd_record
program define _rd_record
    args rc label
    global PSDASH_RD_TEST = $PSDASH_RD_TEST + 1
    if `rc' == 0 {
        display as result "  PASS: `label'"
        global PSDASH_RD_PASS = $PSDASH_RD_PASS + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        global PSDASH_RD_FAIL = $PSDASH_RD_FAIL + 1
    }
end

capture program drop _rd_binary_data
program define _rd_binary_data
    clear
    set obs 8
    generate byte trt = _n > 4
    generate double ps = .2 + .6 * (_n - 1) / 7
    generate double wt = 1 + _n / 10
    generate double x = _n
end

**# Repeated helper calls clear every fixed-name c_local output
capture noisily {
    _rd_binary_data
    _psdash_detect trt ps, wvar(wt) covariates(x)
    assert "`_psd_wvar'" == "wt"
    assert "`_psd_covariates'" == "x"

    local _psd_method "stale_method"
    local _psd_contract_version "stale_contract"
    local _psd_longitudinal "1"
    local _psd_n_estimation "999"
    local _psd_n_excluded "999"
    _psdash_detect trt ps
    assert "`_psd_wvar'" == ""
    assert "`_psd_covariates'" == ""
    assert "`_psd_method'" == ""
    assert "`_psd_contract_version'" == ""
    assert "`_psd_longitudinal'" == ""
    assert "`_psd_n_estimation'" == ""
    assert "`_psd_n_excluded'" == ""
}
_rd_record `=_rc' "repeated detector calls do not inherit optional metadata"

**# Public detector rejects an empty requested sample
capture noisily {
    _rd_binary_data
    capture noisily psdash_detect trt ps if 0
    assert _rc == 2000
}
_rd_record `=_rc' "public detector rejects empty if/in sample"

**# Dispatcher preserves the public detector's empty-sample error
capture noisily {
    _rd_binary_data
    capture noisily psdash detect trt ps if 0
    assert _rc == 2000
}
_rd_record `=_rc' "dispatcher forwards empty-sample error"

**# Combined dryrun preserves the public detector's empty-sample error
capture noisily {
    _rd_binary_data
    capture noisily psdash combined trt ps if 0, dryrun
    assert _rc == 2000
}
_rd_record `=_rc' "combined dryrun forwards empty-sample error"

**# An all-missing score cannot produce a successful detection report
capture noisily {
    _rd_binary_data
    replace ps = .
    capture noisily psdash_detect trt ps
    assert _rc == 2000
}
_rd_record `=_rc' "all-missing binary score is rejected"

**# Multi-group validation requires a complete probability vector
capture noisily {
    clear
    set obs 9
    generate byte arm = mod(_n - 1, 3)
    generate double p0 = .
    generate double p1 = .
    generate double p2 = .
    capture noisily psdash_detect arm, psvars(p0 p1 p2)
    assert _rc == 2000
}
_rd_record `=_rc' "all-incomplete multi-group score vector is rejected"

**# Every detected treatment level must remain represented after score markout
capture noisily {
    clear
    set obs 9
    generate byte arm = mod(_n - 1, 3)
    generate double p0 = .50
    generate double p1 = .30
    generate double p2 = .20
    replace p0 = . if arm == 2
    replace p1 = . if arm == 2
    replace p2 = . if arm == 2
    capture noisily psdash_detect arm, psvars(p0 p1 p2)
    assert _rc == 2001
}
_rd_record `=_rc' "score-complete sample retains every treatment level"

**# Partial missingness is allowed when usable rows retain all levels
capture noisily {
    clear
    set obs 12
    generate byte arm = mod(_n - 1, 3)
    generate double p0 = .50
    generate double p1 = .30
    generate double p2 = .20
    replace p0 = . in 1/3
    replace p1 = . in 1/3
    replace p2 = . in 1/3
    quietly psdash_detect arm, psvars(p0 p1 p2)
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
}
_rd_record `=_rc' "partial missingness retains a usable row in every level"

display as text "RESULT: test_release_detect tests=$PSDASH_RD_TEST pass=$PSDASH_RD_PASS fail=$PSDASH_RD_FAIL skip=0"
local final_rc = cond($PSDASH_RD_FAIL > 0, 9, 0)
_psdash_qa_cleanup
macro drop PSDASH_RD_TEST PSDASH_RD_PASS PSDASH_RD_FAIL
capture log close _all
exit `final_rc'
