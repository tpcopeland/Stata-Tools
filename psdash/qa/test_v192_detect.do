* test_v192_detect.do -- psdash 1.9.2 detection/dispatch fixes
* Author: Timothy P Copeland, Karolinska Institutet
*
* Changes under test (Gemini v2 review, slice detect/dispatch):
*   I1  r(estimand) is lowercased on every detect route (estimand(ATT) -> att)
*   I3  _psdash_pscheck does not count missing PS as near-boundary
*   I4  active tmle/ltmle estimates never fall back to stale _dta[] chars
*   I5  teffects: a reduced-arm if/in sample is refused (r198); control(1)
*       maps teffects atet onto psdash atc (level 1 = treated in psdash)
*   I11 e(cmdline) parsing: "(treat, logit)", ", asis", ", base(1)" and
*       "if(...)" never reach the treatment name or the covariate list
*   I12 K=2 non-0/1 positional PS is markout-gated; producer estimand
*       conflicts (iivw/msm) are refused; positional args that would be
*       silently ignored are refused
*   M5  reference() takes one level (reference(0 junk) is r198)
*   M6  "psdash , opt" is r198, not the overview
*   M7  logit/probit treatment must be 0/1; mlogit 0/1 reports the binary
*       design exactly as the manual route does
*   M9  psdash detect posts r(n_estimation)/r(n_excluded); help files place
*       r(vr_na_vars) under Macros and mark longitudinal-only detect returns
*
* Oracles are hand computed or fixed literals, never psdash output.
*
* Usage: cd psdash/qa && stata-mp -b do test_v192_detect.do
version 16.0
capture log close _all
log using test_v192_detect.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local repo_dir = substr("`pkg_dir'", 1, strlen("`pkg_dir'") - strlen("/psdash"))
local tests = 0
local pass = 0
local fail = 0
local skip = 0
global V192B_FAILED ""

capture program drop _v192b_rec
program define _v192b_rec
    args name rc
    if `rc' {
        display as error "FAIL: `name' (rc=`rc')"
        global V192B_FAILED "$V192B_FAILED `name'"
    }
    else display as result "PASS: `name'"
end

capture program drop _v192b_auto
program define _v192b_auto
    sysuse auto, clear
    quietly logit foreign mpg weight
    quietly predict double ps, pr
end

**# T1 (I1): r(estimand) is lowercase on manual, logit, and router routes
capture noisily {
    _v192b_auto
    quietly psdash_detect foreign ps, estimand(ATT)
    assert "`r(estimand)'" == "att"
    quietly psdash detect foreign ps, estimand(Ate)
    assert "`r(estimand)'" == "ate"
    quietly psdash detect ps, estimand(aTc)
    assert "`r(estimand)'" == "atc"
    assert "`r(source)'" == "estimation"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec estimand_lowercase `rc'

**# T2 (I3): missing PS (. and .a) inside samplevar is not near-boundary
capture noisily {
    clear
    set obs 10
    generate double ps = 0.5
    replace ps = 0.995 in 9/10
    replace ps = . in 1/2
    replace ps = .a in 3
    generate byte keep_all = 1
    _psdash_pscheck ps, samplevar(keep_all) nowarn
    assert r(n_ps_near) == 2
    assert r(n_ps_near_boundary) == 2
    assert r(n_ps_boundary) == 0
    replace ps = 0.5 in 9/10
    _psdash_pscheck ps, samplevar(keep_all) nowarn
    assert r(n_ps_near) == 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec pscheck_missing_not_near `rc'

**# T3-T4 (I4, I12c): active tmle/ltmle ignore stale chars; stray 1-arg refused
local tl_ok = fileexists("`repo_dir'/targetlearn/targetlearn.pkg")
if `tl_ok' {
    capture ado uninstall targetlearn
    quietly net install targetlearn, from("`repo_dir'/targetlearn") replace
    capture noisily {
        clear
        set seed 2026072202
        set obs 300
        generate double x1 = rnormal()
        generate double x2 = rnormal()
        generate double ps_true = invlogit(-0.25 + 0.45*x1 - 0.20*x2)
        generate byte treat = runiform() < ps_true
        generate double y = 1 + 1.25*treat + 0.40*x1 + 0.25*x2 + rnormal(0, 0.7)
        quietly tmle x1 x2, outcome(y) treatment(treat) nolog
        assert "`e(weight_var)'" == ""
        generate double bogus_stale_w = 1
        char _dta[_tmle_weight_var] "bogus_stale_w"
        quietly psdash detect
        assert "`r(source)'" == "tmle"
        assert "`r(wvar)'" == "auto-generated"
        char _dta[_tmle_weight_var]
        * I12c: a lone positional that is not the fitted treatment
        capture noisily psdash detect x1
        assert _rc == 198
        quietly psdash detect treat
        assert "`r(treatment)'" == "treat"
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192b_rec tmle_active_ignores_stale_chars `rc'

    capture noisily {
        clear
        set seed 2026072203
        set obs 360
        generate long pid = ceil(_n / 3)
        bysort pid: generate byte period = _n
        generate double bl_x = rnormal() if period == 1
        bysort pid (period): replace bl_x = bl_x[1]
        generate double tv_x = rnormal() + 0.10*period + 0.15*bl_x
        generate byte a_treat = runiform() < 0.5
        generate byte y_out = runiform() < ///
            invlogit(-1.2 + 0.35*bl_x + 0.25*tv_x + 0.70*a_treat)
        generate byte y_terminal = y_out if period == 3
        quietly ltmle, id(pid) period(period) outcome(y_terminal) ///
            treatment(a_treat) baseline(bl_x) nolog
        assert "`e(covariates)'" == ""
        char _dta[_ltmle_tmodel] "tv_x"
        quietly psdash detect
        assert "`r(source)'" == "ltmle"
        assert "`r(covariates)'" == "bl_x"
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192b_rec ltmle_active_ignores_stale_chars `rc'
    capture ado uninstall targetlearn
}
else {
    local skip = `skip' + 2
    display as text "SKIP: targetlearn sibling not available"
}

**# T5 (I5a): teffects reduced-arm sample is refused; caller data survives
capture noisily {
    sysuse auto, clear
    generate byte arm = cond(rep78 <= 2, 0, cond(rep78 == 3, 1, 2)) if !missing(rep78)
    quietly teffects ipw (price) (arm headroom trunk)
    assert e(k_levels) == 3
    quietly ds
    local before "`r(varlist)'"
    quietly datasignature
    local sig "`r(datasignature)'"
    foreach c in detect overlap support weights balance {
        local opt ""
        if inlist("`c'", "overlap", "support") local opt ", nograph"
        capture noisily psdash `c' if arm != 2 `opt'
        assert _rc == 198
        quietly ds
        assert "`r(varlist)'" == "`before'"
    }
    quietly datasignature
    assert "`r(datasignature)'" == "`sig'"
    * full-arm sample still works
    quietly psdash detect
    assert r(K) == 3
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec teffects_reduced_arm_refused `rc'

**# T6 (I5b): teffects control(1) atet -> psdash atc with matching weights
capture noisily {
    sysuse auto, clear
    quietly teffects ipw (price) (foreign headroom trunk), control(1) atet
    quietly predict double p1 if e(sample), ps tlevel(1)
    quietly psdash detect
    assert "`r(estimand)'" == "atc"
    * ATC oracle: treated (level 1) (1-p)/p, control (level 0) 1
    generate double w_or = cond(foreign == 1, (1 - p1) / p1, 1) if e(sample)
    quietly summarize w_or
    local oracle = r(mean)
    quietly psdash weights
    assert "`r(estimand)'" == "atc"
    assert !missing(r(mean_wt)) & !missing(`oracle')
    assert reldif(r(mean_wt), `oracle') < 1e-10
    * ATE under control(1) is symmetric and unchanged
    quietly teffects ipw (price) (foreign headroom trunk), control(1)
    quietly psdash detect
    assert "`r(estimand)'" == "ate"
    * default control(0) atet stays att
    quietly teffects ipw (price) (foreign headroom trunk), atet
    quietly psdash detect
    assert "`r(estimand)'" == "att"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec teffects_control1_maps_estimand `rc'

**# T7 (I11): cmdline parsing keeps options/qualifiers out of names
capture noisily {
    sysuse auto, clear
    quietly teffects ipw (price) (foreign, logit)
    quietly psdash detect
    assert "`r(treatment)'" == "foreign"
    assert "`r(covariates)'" == ""
    quietly teffects ipw (price) (foreign headroom trunk, logit)
    quietly psdash detect
    assert "`r(covariates)'" == "headroom trunk"
    quietly logit foreign, asis
    quietly predict double ps0, pr
    quietly psdash detect ps0
    assert "`r(covariates)'" == ""
    quietly logit foreign mpg weight if(mpg>12)
    quietly predict double ps1, pr
    quietly psdash detect ps1
    assert "`r(covariates)'" == "mpg weight"
    quietly logit foreign mpg weight [pw=trunk], vce(robust)
    quietly predict double ps2, pr
    quietly psdash detect ps2
    assert "`r(covariates)'" == "mpg weight"
    generate byte arm = cond(rep78 <= 2, 0, cond(rep78 == 3, 1, 2)) if !missing(rep78)
    quietly mlogit arm, base(1)
    quietly predict double m0 m1 m2, pr
    quietly psdash detect, psvars(m0 m1 m2)
    assert "`r(covariates)'" == ""
    quietly mlogit arm mpg in 1/60, base(1)
    quietly predict double n0 n1 n2, pr
    quietly psdash detect, psvars(n0 n1 n2)
    assert "`r(covariates)'" == "mpg"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec cmdline_parsing_options_qualifiers `rc'

**# T8 (I12a): K=2 non-0/1 positional PS that is all missing is r(2000)
capture noisily {
    clear
    set obs 40
    generate byte a12 = 1 + (_n > 20)
    generate double psmiss = .
    generate double w = 1
    capture noisily psdash detect a12 psmiss, wvar(w)
    assert _rc == 2000
    replace psmiss = 0.4
    quietly psdash detect a12 psmiss, wvar(w)
    assert r(multigroup) == 1
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec k2_non01_ps_markout `rc'

**# T9 (I12c): positional PS outside psvars(); teffects stray positional
capture noisily {
    _v192b_auto
    generate double q = 1 - ps
    capture noisily psdash detect foreign ps, psvars(weight length)
    assert _rc == 198
    * the combined-dashboard forwarding form (positional is a psvars column)
    quietly psdash detect foreign ps, psvars(q ps)
    assert "`r(psvar)'" == "ps"
    quietly teffects ipw (price) (foreign mpg weight)
    capture noisily psdash detect mpg
    assert _rc == 198
    quietly psdash detect foreign
    assert "`r(source)'" == "teffects"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec stray_positional_refused `rc'

**# T10 (I12b): iivw estimand() conflicting with the producer's is refused
capture ado uninstall iivw
capture net install iivw, from("`repo_dir'/iivw") replace
capture which iivw_weight
if _rc == 0 {
    capture noisily {
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
        quietly iivw_weight, endatlastvisit id(id) time(days) treat(treated) ///
            treat_cov(edss_bl age sex) visit_cov(edss relapse) wtype(fiptiw) nolog
        quietly psdash detect
        assert "`r(estimand)'" == "ate"
        foreach c in detect weights balance {
            capture noisily psdash `c', estimand(att)
            assert _rc == 198
        }
        quietly psdash detect, estimand(ATE)
        assert "`r(estimand)'" == "ate"
        * PS-only panel: estimand() does not consume the iivw weight
        quietly psdash support, estimand(att) nograph
        assert "`r(estimand)'" == "att"
        * combined: the balance panel consumes the iivw weight even under
        * noweights, so the conflict is refused there too (cross-slice review)
        * positive control first, so the two 198s below cannot be a syntax error
        quietly psdash combined, estimand(att) nobalance noweights
        assert "`r(estimand)'" == "att"
        capture noisily psdash combined, estimand(att) noweights
        assert _rc == 198
        capture noisily psdash combined, estimand(att)
        assert _rc == 198
        capture graph drop _all
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192b_rec iivw_estimand_conflict_refused `rc'
    capture ado uninstall iivw
}
else {
    local ++skip
    display as text "SKIP: iivw sibling not available"
}

**# T11 (I12b): msm detect refuses a conflicting estimand()
local plus_now = subinstr("`c(sysdir_plus)'", "\", "/", .)
local plus_box = subinstr("`_qa_plus'", "\", "/", .)
if fileexists("`repo_dir'/msm/msm.pkg") & "`plus_box'" != "" & strpos("`plus_now'", "`plus_box'") == 1 {
    capture noisily {
        capture ado uninstall msm
        quietly net install msm, from("`repo_dir'/msm") replace
        use "`repo_dir'/msm/msm_example.dta", clear
        quietly msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) censor(censored) covariates(biomarker comorbidity) ///
            baseline_covariates(age sex)
        quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
            treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
            censor_n_cov(age sex) truncate(1 99) nolog
        capture noisily psdash detect, estimand(att)
        assert _rc == 198
        quietly psdash detect, estimand(ATE)
        assert "`r(estimand)'" == "ate"
        capture ado uninstall msm
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192b_rec msm_estimand_conflict_refused `rc'
}
else {
    local ++skip
    display as text "SKIP: msm sibling or PLUS sandbox not available"
}

**# T12 (M5): reference() takes exactly one level
capture noisily {
    _v192b_auto
    capture noisily psdash detect foreign ps, reference(0 bogus_extra)
    assert _rc == 198
    capture noisily psdash detect ps, reference(0 bogus_extra)
    assert _rc == 198
    quietly psdash detect foreign ps, reference(0)
    assert "`r(treatment)'" == "foreign"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec reference_single_level `rc'

**# T13 (M6): "psdash , option" is an error; bare forms show the overview
capture noisily {
    capture noisily psdash , nonexistent
    assert _rc == 198
    psdash
    assert _rc == 0
    psdash ,
    assert _rc == 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec router_rejects_options `rc'

**# T14 (M7a): logit treatment not coded 0/1 is refused at detection
capture noisily {
    sysuse auto, clear
    generate byte t02 = 2 * foreign
    quietly logit t02 mpg weight
    quietly predict double ps2, pr
    capture noisily psdash detect ps2
    assert _rc == 198
    quietly probit t02 mpg weight
    capture noisily psdash detect ps2
    assert _rc == 198
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec logit_non01_refused `rc'

**# T15 (M7b): mlogit 0/1 reports the binary design like the manual route
capture noisily {
    sysuse auto, clear
    quietly mlogit foreign mpg weight
    quietly predict double m0 m1, pr
    quietly psdash detect, psvars(m0 m1)
    assert r(multigroup) == 0
    assert "`r(psvar)'" == "m1"
    assert "`r(source)'" == "estimation"
    assert "`r(covariates)'" == "mpg weight"
    * same weights as the manual route; oracle 1/m1 treated, 1/m0 control
    generate double w_or = cond(foreign == 1, 1/m1, 1/m0)
    quietly summarize w_or
    local oracle = r(mean)
    quietly psdash weights, psvars(m0 m1)
    assert !missing(r(mean_wt)) & !missing(`oracle')
    assert reldif(r(mean_wt), `oracle') < 1e-7
    quietly mlogit foreign mpg weight
    quietly psdash weights foreign, psvars(m0 m1)
    assert !missing(r(mean_wt)) & !missing(`oracle')
    assert reldif(r(mean_wt), `oracle') < 1e-7
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec mlogit_binary01_is_binary `rc'

**# T16 (M9): detect posts the estimation-sample ledger
capture noisily {
    sysuse auto, clear
    quietly teffects ipw (price) (foreign headroom trunk) if rep78 != .
    quietly psdash detect
    assert r(n_estimation) == 69
    assert r(n_excluded) == 5
    quietly psdash_detect
    assert r(n_estimation) == 69
    assert r(n_excluded) == 5
    quietly psdash overlap, nograph
    assert r(n_estimation) == 69
    * manual route posts no ledger
    quietly logit foreign mpg
    quietly predict double ps, pr
    quietly psdash detect foreign ps
    assert missing(r(n_estimation))
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec detect_posts_sample_ledger `rc'

**# T17 (M9 docs): vr_na_vars under Macros; longitudinal-only detect returns
capture noisily {
    local h = fileread("`pkg_dir'/psdash.sthlp")
    local r0 = strpos(`"`h'"', "{marker results}")
    assert `r0' > 0
    local res = substr(`"`h'"', `r0', .)
    local b0 = strpos(`"`res'"', "{dlgtab:balance}")
    assert `b0' > 0
    local bal = substr(`"`res'"', `b0', .)
    local b1 = strpos(substr(`"`bal'"', 2, .), "{dlgtab:")
    local bal = substr(`"`bal'"', 1, `b1')
    local mac = strpos(`"`bal'"', "Macros}")
    local vr = strpos(`"`bal'"', "r(vr_na_vars)")
    assert `mac' > 0 & `vr' > `mac'
    assert strpos(`"`h'"', "every subcommand (including {cmd:detect})") > 0
    local d = fileread("`pkg_dir'/psdash_detect.sthlp")
    assert strpos(`"`d'"', "{synopt:{cmd:r(method)}}") > 0
    assert strpos(`"`d'"', "{cmd:r(regime)}, {cmd:r(method)}, {cmd:r(contract_version)}, and {cmd:r(riskvar)} are") > 0
    assert strpos(`"`d'"', "posted only for longitudinal contracts") > 0
    assert strpos(`"`d'"', "{synopt:{cmd:r(n_estimation)}}") > 0
    assert strpos(`"`d'"', "{synopt:{cmd:r(n_excluded)}}") > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec docs_return_blocks `rc'

**# T18 (lead 5): _psdash_strip_fv opens grouped factor operators
capture noisily {
    sysuse auto, clear
    _psdash_strip_fv "i.(rep78 foreign) mpg"
    assert "`_psd_stripped_covars'" == "rep78 foreign mpg"
    _psdash_strip_fv "ib(first).rep78 c.mpg##i.foreign"
    assert "`_psd_stripped_covars'" == "rep78 mpg foreign"
    _psdash_strip_fv "ib(#2).(rep78 foreign) weight"
    assert "`_psd_stripped_covars'" == "rep78 foreign weight"
    _psdash_strip_fv "ib2.rep78 i.(rep78 foreign)##c.(mpg weight)"
    assert "`_psd_stripped_covars'" == "rep78 foreign mpg weight"
    _psdash_strip_fv "mpg nosuchvar i.(foreign nosuch2)"
    assert "`_psd_stripped_covars'" == "mpg foreign"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192b_rec strip_fv_grouped_operators `rc'

graph drop _all
display "RESULT: test_v192_detect tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
if `fail' display as error "Failed:$V192B_FAILED"
global V192B_FAILED
_psdash_qa_cleanup
log close
if `fail' exit 1
* A skipped producer test leaves I4/I12 unexercised: not green (run_all: 77 = skipped)
if `skip' > 0 exit 77
