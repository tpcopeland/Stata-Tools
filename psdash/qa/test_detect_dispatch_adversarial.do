* test_detect_dispatch_adversarial.do - adversarial dispatch/detection QA for psdash
* Usage: cd psdash/qa && stata-mp -b do test_detect_dispatch_adversarial.do

clear all
version 16.0

capture log close _all
log using "test_detect_dispatch_adversarial.log", replace nomsg

local test_count = 0
global DD_PASS_COUNT = 0
global DD_FAIL_COUNT = 0
global DD_FAILED_TESTS ""

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'"
if strpos("`pkg_dir'", "/qa") > 0 {
    local pkg_dir = subinstr("`pkg_dir'", "/qa", "", 1)
}

local _qa_plus_orig "`c(sysdir_plus)'"
local _qa_personal_orig "`c(sysdir_personal)'"
tempfile _qa_marker
local _qa_sysroot "`_qa_marker'_sysdir"
local _qa_plus "`_qa_sysroot'/plus"
local _qa_personal "`_qa_sysroot'/personal"
capture mkdir "`_qa_sysroot'"
capture mkdir "`_qa_plus'"
capture mkdir "`_qa_personal'"
sysdir set PLUS "`_qa_plus'"
sysdir set PERSONAL "`_qa_personal'"

capture ado uninstall psdash
capture noisily net install psdash, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    exit `install_rc'
}

capture program drop _dd_result
program define _dd_result
    args test_id rc
    if `rc' == 0 {
        display as result "  PASS: `test_id'"
        global DD_PASS_COUNT = $DD_PASS_COUNT + 1
    }
    else {
        display as error "  FAIL: `test_id' (rc=`rc')"
        global DD_FAIL_COUNT = $DD_FAIL_COUNT + 1
        global DD_FAILED_TESTS "$DD_FAILED_TESTS `test_id'"
    }
end

capture program drop _dd_binary_data
program define _dd_binary_data
    syntax [, N(integer 400) SEED(integer 9471)]
    clear
    set seed `seed'
    set obs `n'
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rnormal()
    gen double ps_true = invlogit(-0.35 + 0.7*x1 - 0.4*x2 + 0.2*x3)
    gen byte treat = runiform() < ps_true
    gen double y = 2 + 1.5*treat + 0.5*x1 - 0.25*x2 + rnormal()
end

capture program drop _dd_multigroup_data
program define _dd_multigroup_data
    syntax [, N(integer 450) SEED(integer 1934)]
    clear
    set seed `seed'
    set obs `n'
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double xb1 = 0.4*x1 - 0.2*x2
    gen double xb2 = -0.3*x1 + 0.5*x2
    gen double den = 1 + exp(xb1) + exp(xb2)
    gen double gps0 = 1 / den
    gen double gps1 = exp(xb1) / den
    gen double gps2 = exp(xb2) / den
    gen double u = runiform()
    gen byte arm = cond(u < gps0, 0, cond(u < gps0 + gps1, 1, 2))
    gen double y = 1 + arm + 0.4*x1 - 0.3*x2 + rnormal()
end

capture program drop _dd_fake_teffects
program define _dd_fake_teffects, eclass
    quietly regress y
    ereturn local cmd "teffects"
    ereturn local subcmd "ipw"
    ereturn local cmdline "teffects ipw malformed"
end

**# Installed-user autoload and router surface

local ++test_count
display as text _n "--- T1: installed-user dispatcher autoloads subcommand and helper ---"
capture noisily {
    clear
    _dd_binary_data, n(300) seed(1001)
    quietly logit treat x1 x2 x3
    predict double ps, pr
    findfile psdash.ado
    assert strpos("`r(fn)'", "`_qa_plus'") > 0
    findfile _psdash_detect.ado
    assert strpos("`r(fn)'", "`_qa_plus'") > 0
    psdash balance ps, nowvar
    assert "`r(treatment)'" == "treat"
    assert "`r(varlist)'" == "x1 x2 x3"
    assert rowsof(r(balance)) == 3
}
_dd_result "T1" `=_rc'

local ++test_count
display as text _n "--- T2: dispatcher routes all public subcommands ---"
capture noisily {
    _dd_binary_data, n(300) seed(1002)
    quietly logit treat x1 x2 x3
    predict double ps, pr
    psdash overlap treat ps, nograph
    assert r(N) == 300
    psdash balance treat ps, covariates(x1 x2 x3) nowvar
    assert rowsof(r(balance)) == 3
    psdash weights treat ps
    assert r(ess) > 0
    psdash support treat ps, nograph
    assert r(N) == 300
    psdash combined treat ps, covariates(x1 x2 x3) ///
        nooverlap nobalance noweights nosupport
    assert "`r(treatment)'" == "treat"
}
_dd_result "T2" `=_rc'

local ++test_count
display as text _n "--- T3: dispatcher rejects abbreviated/unknown subcommands ---"
capture noisily {
    _dd_binary_data, n(100) seed(1003)
    capture psdash over treat ps
    local rc_over = _rc
    assert `rc_over' == 198
    capture psdash diagnose treat ps
    local rc_diag = _rc
    assert `rc_diag' == 198
}
_dd_result "T3" `=_rc'

**# Post-estimation detection

local ++test_count
display as text _n "--- T4: logit auto-detects treatment/covariates with single PS arg ---"
capture noisily {
    _dd_binary_data, n(400) seed(2001)
    quietly logit treat x1 x2 x3
    predict double ps, pr
    psdash overlap ps, nograph
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "ps"
    psdash balance ps, nowvar
    assert "`r(varlist)'" == "x1 x2 x3"
}
_dd_result "T4" `=_rc'

local ++test_count
display as text _n "--- T5: probit auto-detects treatment/covariates with single PS arg ---"
capture noisily {
    _dd_binary_data, n(400) seed(2002)
    quietly probit treat x1 x2 x3
    predict double ps_pb, pr
    psdash balance ps_pb, nowvar
    assert "`r(treatment)'" == "treat"
    assert "`r(varlist)'" == "x1 x2 x3"
}
_dd_result "T5" `=_rc'

local ++test_count
display as text _n "--- T6: teffects auto-detects treatment, PS, weights, and source ---"
capture noisily {
    _dd_binary_data, n(500) seed(2003)
    quietly teffects ipw (y) (treat x1 x2 x3)
    psdash combined, nooverlap nobalance noweights nosupport
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "auto-generated"
    assert "`r(source)'" == "teffects"
    assert "`r(estimand)'" == "ate"
}
_dd_result "T6" `=_rc'

local ++test_count
display as text _n "--- T7: mlogit auto-detects treatment/covariates with psvars() ---"
capture noisily {
    _dd_multigroup_data, n(450) seed(2004)
    quietly mlogit arm x1 x2
    predict double p0 p1 p2, pr
    psdash overlap, psvars(p0 p1 p2) nograph
    assert "`r(treatment)'" == "arm"
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
}
_dd_result "T7" `=_rc'

**# Omitted treatment/psvar behavior

local ++test_count
display as text _n "--- T8: after logit, omitting PS variable errors informatively ---"
capture noisily {
    _dd_binary_data, n(300) seed(3001)
    quietly logit treat x1 x2 x3
    capture psdash overlap, nograph
    local rc_no_ps = _rc
    assert `rc_no_ps' == 198
}
_dd_result "T8" `=_rc'

local ++test_count
display as text _n "--- T9: after logit, giving depvar alone is not accepted as PS ---"
capture noisily {
    _dd_binary_data, n(300) seed(3002)
    quietly logit treat x1 x2 x3
    capture psdash overlap treat, nograph
    local rc_dep_only = _rc
    assert `rc_dep_only' == 198
}
_dd_result "T9" `=_rc'

local ++test_count
display as text _n "--- T10: manual treatment-only call without e() errors ---"
capture noisily {
    _dd_binary_data, n(200) seed(3003)
    capture ereturn clear
    capture psdash overlap treat, nograph
    local rc_manual = _rc
    assert `rc_manual' == 198
}
_dd_result "T10" `=_rc'

local ++test_count
display as text _n "--- T11: mlogit K>2 rejects a single positional PS var ---"
capture noisily {
    _dd_multigroup_data, n(450) seed(3004)
    quietly mlogit arm x1 x2
    predict double p0 p1 p2, pr
    capture psdash overlap p0, nograph
    local rc_one_ps = _rc
    assert `rc_one_ps' == 198
}
_dd_result "T11" `=_rc'

**# Malformed estimation state

local ++test_count
display as text _n "--- T12: malformed teffects e(cmdline) is rejected without crash ---"
capture noisily {
    clear
    set obs 20
    gen double y = rnormal()
    _dd_fake_teffects
    capture psdash overlap, nograph
    local rc_bad_te = _rc
    assert `rc_bad_te' == 198
}
_dd_result "T12" `=_rc'

**# State restoration

local ++test_count
display as text _n "--- T13: varabbrev restored after successful dispatch ---"
capture noisily {
    set varabbrev on
    _dd_binary_data, n(200) seed(4001)
    gen double ps = 0.2 + 0.6*runiform()
    psdash overlap treat ps, nograph
    assert "`c(varabbrev)'" == "on"
}
_dd_result "T13" `=_rc'

local ++test_count
display as text _n "--- T14: varabbrev restored after detection failure ---"
set varabbrev off
capture noisily {
    _dd_binary_data, n(200) seed(4002)
    capture psdash overlap treat, nograph
    local rc_fail = _rc
    assert `rc_fail' == 198
    assert "`c(varabbrev)'" == "off"
}
_dd_result "T14" `=_rc'
set varabbrev on

local ++test_count
display as text _n "--- T15: post-logit auto-detection preserves active e() ---"
capture noisily {
    _dd_binary_data, n(350) seed(4003)
    quietly logit treat x1 x2 x3
    predict double ps, pr
    local cmd_before "`e(cmd)'"
    local dep_before "`e(depvar)'"
    local N_before = e(N)
    tempname b_before b_after
    matrix `b_before' = e(b)

    psdash overlap ps, nograph
    psdash balance ps, nowvar
    psdash weights ps

    assert "`e(cmd)'" == "`cmd_before'"
    assert "`e(depvar)'" == "`dep_before'"
    assert e(N) == `N_before'
    matrix `b_after' = e(b)
    assert colsof(`b_after') == colsof(`b_before')
    forvalues j = 1/`=colsof(`b_before')' {
        assert reldif(`b_before'[1,`j'], `b_after'[1,`j']) < 1e-12
    }
}
_dd_result "T15" `=_rc'

local ++test_count
display as text _n "--- T16: post-teffects auto-detection preserves active e() ---"
capture noisily {
    _dd_binary_data, n(450) seed(4004)
    quietly teffects ipw (y) (treat x1 x2 x3), atet
    local cmd_before "`e(cmd)'"
    local subcmd_before "`e(subcmd)'"
    local stat_before "`e(stat)'"
    local N_before = e(N)
    tempname b_before b_after
    matrix `b_before' = e(b)

    psdash overlap, nograph
    psdash weights, detail

    assert "`e(cmd)'" == "`cmd_before'"
    assert "`e(subcmd)'" == "`subcmd_before'"
    assert "`e(stat)'" == "`stat_before'"
    assert e(N) == `N_before'
    matrix `b_after' = e(b)
    assert colsof(`b_after') == colsof(`b_before')
}
_dd_result "T16" `=_rc'

**# README/sthlp example reality

local ++test_count
display as text _n "--- T17: README/sthlp manual sysuse example runs as installed user ---"
capture noisily {
    sysuse auto, clear
    logit foreign mpg weight length
    predict double ps, pr
    psdash overlap foreign ps
    psdash balance foreign ps, covariates(mpg weight length) loveplot
    psdash weights foreign ps
    psdash support foreign ps, crump generate(in_support)
    confirm variable in_support
    graph close _all
}
_dd_result "T17" `=_rc'

local ++test_count
display as text _n "--- T18: README/sthlp mlogit syntax is installed-user runnable ---"
capture noisily {
    sysuse auto, clear
    gen byte arm = cond(weight < 2500, 0, cond(weight < 3500, 1, 2))
    capture quietly mlogit arm mpg length turn, iterate(30)
    local doc_mlogit_rc = _rc
    display as text "  documented sysuse auto mlogit rc=`doc_mlogit_rc'"
    if `doc_mlogit_rc' {
        display as error "  DOC RISK: documented sysuse auto mlogit example did not converge"
    }

    _dd_multigroup_data, n(450) seed(5001)
    quietly mlogit arm x1 x2
    predict double ps0 ps1 ps2, pr
    psdash overlap arm, psvars(ps0 ps1 ps2) nograph
    psdash balance arm, psvars(ps0 ps1 ps2) covariates(x1 x2)
    gen double w = cond(arm == 0, 1/ps0, cond(arm == 1, 1/ps1, 1/ps2))
    psdash weights arm, psvars(ps0 ps1 ps2) wvar(w) detail
    psdash support arm, psvars(ps0 ps1 ps2) threshold(0.1) nograph
    assert r(K) == 3
}
_dd_result "T18" `=_rc'

local ++test_count
display as text _n "--- T19: docs state actual logit/probit and mlogit detection contracts ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "After `logit`/`probit`") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "treatment and covariates are read from the estimation context") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), ///
        "After {cmd:logit}/{cmd:probit}, {it:treatment} is auto-detected but {it:psvar} must be supplied explicitly.") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "After `mlogit` (multi-group)") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), ///
        "After {cmd:mlogit} with a multi-valued treatment") > 0
}
_dd_result "T19" `=_rc'

**# Summary and cleanup

capture graph close _all
capture ado uninstall psdash
sysdir set PLUS "`_qa_plus_orig'"
sysdir set PERSONAL "`_qa_personal_orig'"
capture shell rm -rf "`_qa_sysroot'"

display as text _n "{hline 70}"
display as text "DETECT/DISPATCH ADVERSARIAL TEST SUMMARY"
display as text "{hline 70}"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result $DD_PASS_COUNT
display as text "Failed:    " as result $DD_FAIL_COUNT
if $DD_FAIL_COUNT > 0 {
    display as error "FAILED TESTS:$DD_FAILED_TESTS"
    display "RESULT: test_detect_dispatch_adversarial tests=`test_count' pass=$DD_PASS_COUNT fail=$DD_FAIL_COUNT"
    log close _all
    exit 9
}

display as result "ALL TESTS PASSED"
display "RESULT: test_detect_dispatch_adversarial tests=`test_count' pass=$DD_PASS_COUNT fail=$DD_FAIL_COUNT"
log close _all
