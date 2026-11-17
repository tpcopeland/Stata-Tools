* test_v191_detect_weights.do -- psdash 1.9.1 detection and weights fixes
* Author: Timothy P Copeland, Karolinska Institutet
*
* Changes under test (Gemini review findings, slice detect_weights):
*   #3  multi-valued teffects no longer leaves _psdash_ps_<lev> in the data
*       after detect/balance/weights/overlap/support/combined
*   #4  post-mlogit psvars() calls without a positional treatment generate
*       IPTW weights (weights no longer r(198); balance gets adjusted balance;
*       detect reports r(wvar)); mlogit atc with K>2 is refused
*   #5  e(cmdline) weight expressions ([fw=], [pw=]) are not covariates
*   #6  reference() on a 0/1 treatment: reference(0) accepted, reference(1)
*       and non-levels refused (r198) on every route instead of ignored
*   #19 treatment-only manual detection refuses estimand(atc) for K>2
*   #22 _psdash_pscheck on an all-missing PS is r(2000), not r(198)
*   #10 trim(0)/truncate(0) are range errors, not the omitted sentinel
*   #15 K=2 non-0/1 weights post r(n_ps_boundary)/r(n_ps_near_boundary) and
*       the positivity finding
*   m2  binary generate() without a modification errors before any output
*   m3  generate() replace cannot overwrite any psvars() variable (binary,
*       K>2, and the treatment+wvar() route); mlogit 0/1 obeys #6
*   m5  binary xlsx() carries p99, max/mean ratio, ESS by arm, modified stats
*
* Fail-on-old: every test except the T7 guard fails on psdash 1.9.0 (verified by running this
* suite against the 1.9.0 tree). Oracles are hand computed from the PS
* columns, never from psdash output.
*
* Usage: cd psdash/qa && stata-mp -b do test_v191_detect_weights.do
version 16.0
capture log close _all
log using test_v191_detect_weights.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local skip = 0
global V191_FAILED ""

capture program drop _v191_rec
program define _v191_rec
    args name rc
    if `rc' {
        display as error "FAIL: `name' (rc=`rc')"
        global V191_FAILED "$V191_FAILED `name'"
    }
    else display as result "PASS: `name'"
end

* Three-arm fixture with a fitted teffects or mlogit model.
capture program drop _v191_three
program define _v191_three
    args model
    clear
    set seed 191
    set obs 600
    generate double x1 = rnormal()
    generate double x2 = rnormal()
    generate double u = runiform()
    generate byte arm = cond(u < .33, 0, cond(u < .66, 1, 2))
    generate double y = x1 + arm + rnormal()
    drop u
    if "`model'" == "teffects" quietly teffects ipw (y) (arm x1 x2)
    if "`model'" == "mlogit" {
        quietly mlogit arm x1 x2
        quietly predict double p0 p1 p2, pr
    }
end

* Binary fixture: tr01 with PS ps, K=2 recode tr12 = tr01 + 1.
capture program drop _v191_binary
program define _v191_binary
    clear
    set seed 7
    set obs 400
    generate double x = rnormal()
    generate double ps = invlogit(.5 * x)
    generate byte tr01 = runiform() < ps
    generate byte tr12 = tr01 + 1
    generate double w = 1 + runiform()
    generate byte tr3 = mod(_n, 3)
end

**# T1-T6 (#3): multi-valued teffects leaves the variable list unchanged
foreach c in detect balance weights overlap support combined {
    capture noisily {
        _v191_three teffects
        quietly ds
        local before "`r(varlist)'"
        quietly psdash `c'
        quietly ds
        local after "`r(varlist)'"
        assert "`after'" == "`before'"
        capture confirm variable _psdash_ps_0
        assert _rc == 111
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v191_rec teffects_mg_no_leak_`c' `rc'
}
graph drop _all

**# T7 (#3, guard -- passes on old and new): the renamed auto PS still feeds
* the diagnostics (weights = 1/own PS; tolerance covers the scaled-sum ESS path)
capture noisily {
    _v191_three teffects
    quietly predict double q0 q1 q2, ps
    generate double wo = cond(arm == 0, 1/q0, cond(arm == 1, 1/q1, 1/q2))
    quietly summarize wo
    local oracle = r(mean)
    quietly psdash weights
    assert "`r(wvar)'" == "auto-generated"
    assert !missing(r(mean_wt)) & !missing(`oracle')
    assert reldif(r(mean_wt), `oracle') < 1e-7
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec teffects_mg_weights_oracle `rc'

**# T8 (#4): post-mlogit psvars() without a treatment: weights
capture noisily {
    _v191_three mlogit
    generate double wo = cond(arm == 0, 1/p0, cond(arm == 1, 1/p1, 1/p2))
    quietly summarize wo
    local oracle_mean = r(mean)
    local oracle_max = r(max)
    psdash weights, psvars(p0 p1 p2)
    assert "`r(wvar)'" == "auto-generated"
    assert r(K) == 3 & r(N) == 600
    assert !missing(r(mean_wt), r(max_wt), `oracle_mean', `oracle_max') == 1
    assert reldif(r(mean_wt), `oracle_mean') < 1e-10
    assert !missing(r(max_wt)) & !missing(`oracle_max')
    assert reldif(r(max_wt), `oracle_max') < 1e-10
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec mlogit_omitted_treatment_weights `rc'

**# T9 (#4): post-mlogit ATT with reference(2) matches P(ref)/P(own)
capture noisily {
    _v191_three mlogit
    generate double wo = cond(arm == 2, 1, cond(arm == 0, p2/p0, p2/p1))
    quietly summarize wo
    local oracle = r(mean)
    psdash weights, psvars(p0 p1 p2) estimand(att) reference(2)
    assert "`r(reference)'" == "2"
    assert !missing(r(mean_wt)) & !missing(`oracle')
    assert reldif(r(mean_wt), `oracle') < 1e-10
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec mlogit_omitted_treatment_att_reference `rc'

**# T10 (#4): post-mlogit balance and detect get the generated weight
capture noisily {
    _v191_three mlogit
    quietly psdash balance, psvars(p0 p1 p2)
    assert "`r(wvar)'" == "auto-generated"
    assert !missing(r(max_smd_adj))
    quietly psdash detect, psvars(p0 p1 p2)
    assert "`r(wvar)'" == "auto-generated"
    assert "`r(covariates)'" == "x1 x2"
    assert "`r(treatment)'" == "arm"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec mlogit_omitted_treatment_balance_detect `rc'

**# T11 (#4/RB-06): post-mlogit estimand(atc) with K=3 is refused
capture noisily {
    _v191_three mlogit
    capture psdash detect, psvars(p0 p1 p2) estimand(atc)
    assert _rc == 198
    capture psdash weights, psvars(p0 p1 p2) estimand(atc)
    assert _rc == 198
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec mlogit_atc_k3_refused `rc'

**# T12 (#5): logit [fw=] is not a covariate; balance runs on the RHS
capture noisily {
    sysuse auto, clear
    generate int fwt = 1 + mod(_n, 3)
    quietly logit foreign mpg weight [fw=fwt]
    quietly predict double ps_fw
    quietly psdash detect ps_fw
    assert "`r(covariates)'" == "mpg weight"
    assert r(n_covariates) == 2
    quietly psdash balance ps_fw
    assert "`r(varlist)'" == "mpg weight"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec logit_fweight_not_covariate `rc'

**# T13 (#5): mlogit [pw=] and probit [pw=] if are not covariates
capture noisily {
    sysuse auto, clear
    generate double pwt = 1 + mod(_n, 3)
    generate byte grp = mod(_n, 3)
    quietly mlogit grp mpg weight [pw=pwt]
    quietly predict double q0 q1 q2, pr
    quietly psdash detect, psvars(q0 q1 q2)
    assert "`r(covariates)'" == "mpg weight"
    quietly probit foreign mpg price if rep78 < . [pw=pwt]
    quietly predict double pp
    quietly psdash detect pp
    assert "`r(covariates)'" == "mpg price"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec mlogit_probit_pweight_not_covariate `rc'

**# T14 (#6): reference(1)/reference(99) on 0/1 refused; reference(0) honoured
capture noisily {
    _v191_binary
    quietly psdash weights tr01 ps, estimand(att)
    local m_default = r(mean_wt)
    quietly psdash weights tr01 ps, estimand(att) reference(0)
    assert !missing(r(mean_wt)) & !missing(`m_default')
    assert reldif(r(mean_wt), `m_default') < 1e-12
    foreach r in 1 99 {
        foreach c in weights detect overlap support balance {
            local extra ""
            if "`c'" == "balance" local extra "covariates(x)"
            capture psdash `c' tr01 ps, reference(`r') `extra'
            if _rc != 198 {
                display as error "`c' reference(`r') rc=" _rc
                exit 9
            }
        }
        capture psdash weights tr01, wvar(w) reference(`r')
        assert _rc == 198
        capture psdash balance tr01, wvar(w) covariates(x) reference(`r')
        assert _rc == 198
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec binary01_reference_validated `rc'

**# T15 (#6): reference(1) refused on the teffects and logit 0/1 routes
capture noisily {
    _v191_binary
    generate double yy = tr01 + x + rnormal()
    quietly teffects ipw (yy) (tr01 x)
    capture psdash weights, reference(1)
    assert _rc == 198
    quietly psdash weights, reference(0)
    quietly logit tr01 x
    quietly predict double pl
    capture psdash detect pl, reference(1)
    assert _rc == 198
    quietly psdash detect pl, reference(0)
    assert "`r(source)'" == "estimation"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec binary01_reference_producer_routes `rc'

**# T16 (#19): treatment-only manual detection refuses atc for K=3
capture noisily {
    _v191_binary
    capture psdash weights tr3, wvar(w) estimand(atc)
    assert _rc == 198
    capture psdash balance tr3, wvar(w) covariates(x) estimand(atc)
    assert _rc == 198
    quietly psdash weights tr3, wvar(w) estimand(att)
    assert "`r(estimand)'" == "att"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec manual_atc_k3_refused `rc'

**# T17 (#22): all-missing PS is r(2000)
capture noisily {
    clear
    set obs 20
    generate double pmiss = .
    capture _psdash_pscheck pmiss
    assert _rc == 2000
    replace pmiss = 1.5 in 1
    capture _psdash_pscheck pmiss
    assert _rc == 198
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec pscheck_all_missing_2000 `rc'

**# T18 (#10): trim(0)/truncate(0) are range errors on both paths
capture noisily {
    _v191_binary
    foreach t in tr01 tr3 {
        local psopt "ps"
        local wopt ""
        if "`t'" == "tr3" {
            local psopt ""
            local wopt "wvar(w)"
        }
        capture psdash weights `t' `psopt', trim(0) `wopt'
        assert _rc == 198
        capture psdash weights `t' `psopt', truncate(0) `wopt'
        assert _rc == 198
        * Old code ignored the 0 and ran stabilize, creating the variable.
        capture psdash weights `t' `psopt', truncate(0) stabilize generate(sw) `wopt'
        assert _rc == 198
        capture confirm variable sw
        assert _rc == 111
        capture psdash weights `t' `psopt', trim(0) stabilize generate(sw) `wopt'
        assert _rc == 198
        capture confirm variable sw
        assert _rc == 111
    }
    quietly psdash weights tr01 ps, truncate(5) generate(wt5)
    quietly summarize wt5
    assert r(max) <= 5
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec trim_truncate_zero_rejected `rc'

**# T19 (#15): K=2 non-0/1 weights post positivity counts and the finding
capture noisily {
    _v191_binary
    replace ps = 1 in 1
    replace tr12 = 2 in 1
    replace ps = 0.995 in 2
    replace tr12 = 2 in 2
    quietly count if ps == 0 | ps == 1
    local nb = r(N)
    quietly count if (ps < 0.01 | ps > 0.99) & ps != 0 & ps != 1
    local nn = r(N)
    assert `nb' == 1 & `nn' >= 1
    quietly psdash weights tr12 ps
    assert r(n_ps_boundary) == `nb'
    assert r(n_ps_near_boundary) == `nn'
    assert strpos(`"`r(warnings)'"', "exact-PS-boundary positivity") > 0
    * recoding invariance: the 0/1 coding reports the same counts
    replace tr01 = tr12 - 1
    quietly psdash weights tr01 ps
    assert r(n_ps_boundary) == `nb' & r(n_ps_near_boundary) == `nn'
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec k2_non01_positivity_counts `rc'

**# T20 (m2): binary generate() without a modification errors before output
capture noisily {
    _v191_binary
    tempfile m2log
    log using "`m2log'", text replace name(v191m2)
    capture noisily psdash weights tr01 ps, generate(zz)
    local m2rc = _rc
    log close v191m2
    assert `m2rc' == 198
    tempname fh
    local printed = 0
    file open `fh' using "`m2log'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Weight Distribution Summary") local printed = 1
        file read `fh' line
    }
    file close `fh'
    assert `printed' == 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec binary_generate_without_modification_early `rc'

**# T21 (m3): psvars(ps0 ps1) generate(ps0) replace cannot overwrite ps0
capture noisily {
    _v191_binary
    generate double ps0 = 1 - ps
    generate double ps0copy = ps0
    capture psdash weights tr01, psvars(ps0 ps) truncate(5) generate(ps0) replace
    assert _rc == 198
    quietly count if ps0 != ps0copy
    assert r(N) == 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec binary_psvars_generate_guard `rc'

**# T22 (m5): binary xlsx() carries p99, ratio, ESS by arm and modified stats
capture noisily {
    _v191_binary
    tempfile xb
    local book "`xb'.xlsx"
    quietly psdash weights tr01 ps, truncate(5) generate(wt5) xlsx("`book'")
    local p99 = r(p99)
    local ratio = r(max_ratio)
    local esst = r(ess_treated)
    local essc = r(ess_control)
    local newess = r(new_ess)
    import excel using "`book'", sheet("Weights") cellrange(A3) clear allstring
    foreach k in "p99" "Max/mean weight ratio" "ESS (treated)" "ESS (control)" ///
            "Modified weight" "Modified ESS" {
        quietly count if A == "`k'"
        assert r(N) == 1
    }
    quietly levelsof B if A == "p99", local(v) clean
    assert abs(real("`v'") - `p99') < 5e-5
    quietly levelsof B if A == "Max/mean weight ratio", local(v) clean
    assert abs(real("`v'") - `ratio') < 5e-3
    quietly levelsof B if A == "ESS (treated)", local(v) clean
    assert abs(real("`v'") - `esst') < 0.05
    quietly levelsof B if A == "ESS (control)", local(v) clean
    assert abs(real("`v'") - `essc') < 0.05
    quietly levelsof B if A == "Modified weight", local(v) clean
    assert "`v'" == "wt5"
    quietly levelsof B if A == "Modified ESS", local(v) clean
    assert abs(real("`v'") - `newess') < 0.05
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec binary_xlsx_parity `rc'

**# T23 (m3, K>2 and treatment+wvar route): psvars() names are reserved
capture noisily {
    _v191_three mlogit
    generate double w = 1 + runiform()
    generate double p1copy = p1
    capture psdash weights arm, psvars(p0 p1 p2) wvar(w) truncate(3) generate(p1) replace
    assert _rc == 198
    quietly count if p1 != p1copy
    assert r(N) == 0
    capture psdash weights arm p1, psvars(p0 p1 p2) truncate(3) generate(p2) replace
    assert _rc == 198
    capture psdash weights, psvars(p0 p1 p2) truncate(3) generate(p0) replace
    assert _rc == 198
    quietly psdash weights arm, wvar(w) truncate(3) generate(wt3)
    quietly summarize wt3
    assert r(max) <= 3
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec psvars_generate_guard_all_routes `rc'

**# T24 (#6): an mlogit treatment coded 0/1 refuses reference(1) too
capture noisily {
    _v191_binary
    quietly mlogit tr01 x
    quietly predict double q0 q1, pr
    capture psdash weights, psvars(q0 q1) estimand(att) reference(1)
    assert _rc == 198
    capture psdash detect, psvars(q0 q1) reference(1)
    assert _rc == 198
    quietly psdash weights, psvars(q0 q1) estimand(att) reference(0)
    quietly psdash weights, psvars(q0 q1) estimand(att)
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191_rec mlogit_binary01_reference_refused `rc'

display "RESULT: test_v191_detect_weights tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
if `fail' display as error "Failed:$V191_FAILED"
global V191_FAILED
_psdash_qa_cleanup
log close
if `fail' exit 1
