* test_v192_weights_balance_combined.do -- psdash 1.9.2 weights/balance/combined fixes
* Author: Timothy P Copeland, Karolinska Institutet
*
* Changes under test (Gemini review v2, slice weights/balance/combined):
*   I1   estimand() is case-insensitive in weights/balance/combined
*        (estimand(ATT) was r(2000) on binary data and bypassed the
*        multi-group stabilize guard)
*   I6   weights graph: xscale() in graphoptions() gets no injected
*        xlabel(0(...)) / xscale(range(0 cap))
*   I7   balance distribution(): the shared legend cell and the combined
*        figure use the scheme the panels were drawn in
*   I8   r(max_smd_*) / r(max_ks_*) are missing, not 0, when undefined
*   M1   multi-group Love plot with K >= 10 cycles marker shapes
*   M2   psvars() on a binary treatment is ignored with a note
*   M8   xlsx() is written even when saving() fails (rc still nonzero)
*   M9   psdash_combined.sthlp documents the longitudinal returns;
*        psdash_balance.sthlp documents the format()/name() defaults
*   L3   combined title() with an odd number of embedded double quotes
*        (cross-sectional and longitudinal routes)
*
* Oracles are hand computed from the fixture or are the lowercase call,
* never the call under test.
*
* Usage: cd psdash/qa && stata-mp -b do test_v192_weights_balance_combined.do
version 16.0
capture log close _all
log using test_v192_weights_balance_combined.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local skip = 0
global V192A_FAILED ""
local pkgdir = substr("`c(pwd)'", 1, length("`c(pwd)'") - 3)

capture program drop _v192a_rec
program define _v192a_rec
    args name rc
    if `rc' {
        display as error "FAIL: `name' (rc=`rc')"
        global V192A_FAILED "$V192A_FAILED `name'"
    }
    else display as result "PASS: `name'"
end

* Binary fixture: tr01 with PS ps from a fitted logit.
capture program drop _v192a_binary
program define _v192a_binary
    clear
    set seed 192
    set obs 300
    generate double x = rnormal()
    generate double x2 = rnormal()
    generate byte tr01 = runiform() < invlogit(.6 * x)
    quietly logit tr01 x x2
    quietly predict double ps, pr
    generate double w = 1 + runiform()
end

* Three-arm fixture with mlogit PS columns p0 p1 p2.
capture program drop _v192a_three
program define _v192a_three
    clear
    set seed 1923
    set obs 600
    generate double x1 = rnormal()
    generate double u = runiform()
    generate byte arm = cond(u < .33, 0, cond(u < .66, 1, 2))
    drop u
    quietly mlogit arm x1
    quietly predict double p0 p1 p2, pr
end

* Count occurrences of a substring.
capture program drop _v192a_count
program define _v192a_count, rclass
    args hay needle
    local n = (strlen(`"`hay'"') - strlen(subinstr(`"`hay'"', `"`needle'"', "", .))) / strlen(`"`needle'"')
    return scalar n = `n'
end

**# T1 (I1): binary weights -- uppercase estimand matches lowercase
foreach e in ATT ATE ATC Att {
    capture noisily {
        _v192a_binary
        local le = strlower("`e'")
        quietly psdash weights tr01 ps, estimand(`le')
        local ess0 = r(ess)
        local mx0 = r(max_wt)
        quietly psdash weights tr01 ps, estimand(`e')
        assert "`r(estimand)'" == "`le'"
        assert !missing(r(ess), `ess0')
        assert reldif(r(ess), `ess0') < 1e-12
        assert !missing(r(max_wt)) & !missing(`mx0')
        assert reldif(r(max_wt), `mx0') < 1e-12
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192a_rec I1_weights_binary_`e' `rc'
}

**# T2 (I1): binary balance -- uppercase estimand matches lowercase
foreach e in ATT ATE ATC {
    capture noisily {
        _v192a_binary
        local le = strlower("`e'")
        quietly psdash balance tr01 ps, covariates(x x2) estimand(`le') nograph
        local s0 = r(max_smd_adj)
        quietly psdash balance tr01 ps, covariates(x x2) estimand(`e') nograph
        assert "`r(estimand)'" == "`le'"
        assert !missing(r(max_smd_adj), `s0')
        assert reldif(r(max_smd_adj), `s0') < 1e-12
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192a_rec I1_balance_binary_`e' `rc'
}

**# T3 (I1): binary combined -- uppercase estimand matches lowercase
foreach e in ATT ATE ATC {
    capture noisily {
        _v192a_binary
        local le = strlower("`e'")
        quietly psdash combined tr01 ps, covariates(x x2) estimand(`le')
        local v0 "`r(verdict)'"
        local n0 = r(n_warnings)
        quietly psdash combined tr01 ps, covariates(x x2) estimand(`e')
        assert "`r(estimand)'" == "`le'"
        assert "`r(verdict)'" == "`v0'"
        assert r(n_warnings) == `n0'
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192a_rec I1_combined_binary_`e' `rc'
    capture graph drop _all
}

**# T4 (I1): binary stabilize guard fires for uppercase ATT (198, not 2000)
capture noisily {
    _v192a_binary
    capture psdash weights tr01 ps, estimand(ATT) stabilize generate(sw)
    assert _rc == 198
    capture confirm variable sw
    assert _rc == 111
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec I1_binary_stabilize_guard_upper `rc'

**# T5 (I1): multi-group stabilize guard fires for uppercase ATT
capture noisily {
    _v192a_three
    capture psdash weights, psvars(p0 p1 p2) estimand(att) reference(0) stabilize generate(sw)
    assert _rc == 198
    capture psdash weights, psvars(p0 p1 p2) estimand(ATT) reference(0) stabilize generate(sw)
    assert _rc == 198
    capture confirm variable sw
    assert _rc == 111
    * ATE stabilize is defined and still runs
    quietly psdash weights, psvars(p0 p1 p2) estimand(ATE) stabilize generate(sw)
    confirm variable sw
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec I1_multigroup_stabilize_guard_upper `rc'

**# T6 (I6): user xscale(log) gets no injected labels or range
capture noisily {
    _v192a_binary
    quietly replace w = 1000 in 1
    quietly psdash weights tr01, wvar(w) graph name(v192_log) graphoptions(xscale(log))
    graph describe v192_log
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "xlabel(0(") == 0
    assert strpos(`"`cmd'"', "range(0 ") == 0
    _v192a_count `"`cmd'"' "xscale("
    assert r(n) == 1
    assert strpos(`"`cmd'"', "xscale(log)") > 0
    assert strpos(`"`cmd'"', "omitted") == 0
    * a wider user range is not overridden either
    quietly psdash weights tr01, wvar(w) graph name(v192_rng) graphoptions(xscale(range(0 200)))
    graph describe v192_rng
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "xlabel(0(") == 0
    _v192a_count `"`cmd'"' "xscale("
    assert r(n) == 1
    assert strpos(`"`cmd'"', "xscale(range(0 200))") > 0
    * default (no xscale): the outlier is still clipped with a note
    quietly psdash weights tr01, wvar(w) graph name(v192_def)
    graph describe v192_def
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "xlabel(0(") > 0
    assert strpos(`"`cmd'"', "omitted") > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec I6_user_xscale_no_injected_axis `rc'
capture graph drop _all

**# T7 (I7): distribution figure carries the panel scheme
foreach how in graphopt option {
    capture noisily {
        _v192a_binary
        if "`how'" == "graphopt" local sopt "graphoptions(scheme(s1mono))"
        else local sopt "scheme(s1mono)"
        quietly psdash balance tr01 ps, covariates(x x2) distribution(x x2) `sopt' name(v192_d)
        graph describe v192_d_dist
        local cmd `"`r(command)'"'
        assert strpos(`"`cmd'"', "combine ") == 1
        assert strpos(`"`cmd'"', "scheme(s1mono)") > 0
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192a_rec I7_distribution_scheme_`how' `rc'
    capture graph drop _all
}

**# T8 (I8): undefined SMD/KS maxima are missing (binary)
capture noisily {
    _v192a_binary
    generate double xam = .
    quietly psdash balance tr01 ps, covariates(xam) ks nograph
    assert missing(r(max_smd_raw))
    assert missing(r(max_smd_adj))
    assert missing(r(max_ks_raw))
    assert missing(r(max_ks_adj))
    assert missing(r(max_vr_raw))
    assert r(n_imbalanced) == 1
    quietly psdash balance tr01 ps, covariates(xam) nowvar ks nograph
    assert missing(r(max_smd_raw))
    assert missing(r(max_ks_raw))
    * a defined covariate alongside: the maximum is that covariate's |SMD|
    quietly psdash balance tr01 ps, covariates(xam x) ks nograph
    matrix B = r(balance)
    local oracle = abs(B[rownumb(B, "x"), colnumb(B, "SMD_Raw")])
    assert !missing(`oracle')
    assert !missing(r(max_smd_raw)) & !missing(`oracle')
    assert reldif(r(max_smd_raw), `oracle') < 1e-12
    * a constant covariate has a defined SMD of 0
    generate double xc = 1
    quietly psdash balance tr01 ps, covariates(xc) ks nograph
    assert r(max_smd_raw) == 0
    assert r(max_ks_raw) == 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec I8_undefined_max_missing_binary `rc'

**# T9 (I8): undefined SMD/KS maxima are missing (multi-group)
capture noisily {
    _v192a_three
    generate double xam = .
    quietly psdash balance, psvars(p0 p1 p2) covariates(xam) ks nograph
    assert r(K) == 3
    assert missing(r(max_smd_raw))
    assert missing(r(max_smd_adj))
    assert missing(r(max_ks_raw))
    assert missing(r(max_ks_adj))
    quietly psdash balance, psvars(p0 p1 p2) covariates(xam x1) ks nograph
    assert !missing(r(max_smd_raw)) & r(max_smd_raw) > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec I8_undefined_max_missing_multigroup `rc'

**# T10 (M1): K = 10 Love plot has a marker for every contrast
capture noisily {
    clear
    set seed 10
    set obs 1000
    generate byte arm = mod(_n, 10)
    generate double x = rnormal() + arm / 10
    forvalues k = 0/9 {
        generate double p`k' = .1
    }
    quietly psdash balance arm, psvars(p0 p1 p2 p3 p4 p5 p6 p7 p8 p9) covariates(x) loveplot name(v192_lp)
    graph describe v192_lp
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "msymbol()") == 0
    assert strpos(`"`cmd'"', "msize()") == 0
    _v192a_count `"`cmd'"' "msymbol(circle)"
    assert r(n) == 2
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec M1_loveplot_k10_symbols `rc'
capture graph drop _all

**# T11 (M2): psvars() on a binary treatment prints a note
capture noisily {
    _v192a_binary
    tempfile cap
    foreach c in balance weights {
        if "`c'" == "balance" local o "covariates(x) nograph"
        else local o ""
        quietly log using "`cap'.txt", text replace name(_v192cap)
        psdash `c' tr01, wvar(w) psvars(x x2) `o'
        quietly log close _v192cap
        local txt = fileread("`cap'.txt")
        assert strpos(`"`txt'"', "psvars() applies to multi-group treatments only") > 0
        quietly log using "`cap'.txt", text replace name(_v192cap)
        psdash `c' tr01, wvar(w) `o'
        quietly log close _v192cap
        local txt = fileread("`cap'.txt")
        assert strpos(`"`txt'"', "psvars() applies") == 0
    }
    * after mlogit on a 0/1 treatment detect takes the PS from psvars(),
    * so no "ignored" note (final cross-slice review)
    clear
    set seed 4711
    set obs 300
    gen double z = rnormal()
    gen byte a01 = runiform() < invlogit(0.5 * z)
    quietly mlogit a01 z, baseoutcome(0)
    quietly predict double m0 m1, pr
    foreach c in balance weights {
        if "`c'" == "balance" local o "covariates(z) nograph"
        else local o ""
        quietly log using "`cap'.txt", text replace name(_v192cap)
        psdash `c', psvars(m0 m1) `o'
        quietly log close _v192cap
        local txt = fileread("`cap'.txt")
        assert strpos(`"`txt'"', "psvars() applies") == 0
    }
}
local rc = _rc
capture log close _v192cap
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec M2_binary_psvars_note `rc'

**# T12 (M8): xlsx() is written although saving() fails
capture noisily {
    _v192a_binary
    tempfile xw xb
    capture psdash weights tr01 ps, graph saving("/nonexistent_dir_v192/zz.png") xlsx("`xw'.xlsx")
    assert _rc != 0
    confirm file "`xw'.xlsx"
    capture psdash balance tr01 ps, covariates(x) loveplot saving("/nonexistent_dir_v192/zz.png") xlsx("`xb'.xlsx")
    assert _rc != 0
    confirm file "`xb'.xlsx"
    quietly import excel using "`xb'.xlsx", clear allstring
    assert _N > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec M8_xlsx_after_saving_failure `rc'
capture graph drop _all

**# T13 (L3): combined title() with an odd number of embedded quotes
capture noisily {
    _v192a_binary
    quietly psdash combined tr01 ps, covariates(x) title(`"unbalanced " quote"') nooverlap nobalance nosupport
    assert "`r(verdict)'" != ""
    quietly psdash combined tr01 ps, covariates(x) title(`"He said "hi""') nooverlap nobalance nosupport
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec L3_combined_title_quotes `rc'
capture graph drop _all

**# T14 (M9): help files document the corrected surfaces
capture noisily {
    local h = fileread("`pkgdir'/psdash_combined.sthlp")
    foreach r in N_input N_complete N_periods n_missing_weight n_missing_ps ///
        n_missing_period n_outside_risk ess ess_pct cv mean_wt p99 n_extreme ///
        pct_extreme periods riskvar weight_role overlap_by_period weights_by_period {
        assert strpos(`"`h'"', "{cmd:r(`r')}") > 0
    }
    local h = fileread("`pkgdir'/psdash_balance.sthlp")
    assert strpos(`"`h'"', "sets the displayed numeric format; default is {cmd:%6.3f}") > 0
    assert strpos(`"`h'"', "names the graph in memory; default is {cmd:psdash_balance}") > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec M9_help_surfaces `rc'

**# T15 (M8): multi-group xlsx() is written although saving() fails
capture noisily {
    _v192a_three
    tempfile xw xb xwok
    quietly psdash weights arm, psvars(p0 p1 p2) xlsx("`xwok'.xlsx")
    capture psdash weights arm, psvars(p0 p1 p2) graph saving("/nonexistent_dir_v192/zz.png") xlsx("`xw'.xlsx")
    assert _rc != 0
    confirm file "`xw'.xlsx"
    capture psdash balance arm, psvars(p0 p1 p2) covariates(x1) loveplot saving("/nonexistent_dir_v192/zz.png") xlsx("`xb'.xlsx")
    assert _rc != 0
    confirm file "`xb'.xlsx"
    * the data are untouched by the failed runs
    confirm variable x1 p0 p1 p2 arm
    assert _N == 600
    * the workbook after the failure matches a normal run
    quietly import excel using "`xw'.xlsx", clear allstring
    quietly ds
    local _va "`r(varlist)'"
    tempfile a
    quietly save "`a'"
    quietly import excel using "`xwok'.xlsx", clear allstring
    assert _N > 0
    quietly ds
    assert "`r(varlist)'" == "`_va'"
    cf _all using "`a'"
    quietly import excel using "`xb'.xlsx", clear allstring
    assert _N > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec M8_multigroup_xlsx_after_saving_failure `rc'
capture graph drop _all

**# T16 (M2): psdash combined with binary psvars(): a positional PS outside
* psvars() is refused by detect (contradictory input); a PS inside psvars()
* is used, so no "ignored" note is printed by the dashboard or its panels.
capture noisily {
    _v192a_binary
    tempfile cap
    quietly log using "`cap'.txt", text replace name(_v192cap)
    capture noisily psdash combined tr01 ps, covariates(x) psvars(x x2) nooverlap nosupport
    local erc = _rc
    quietly log close _v192cap
    assert `erc' == 198
    local txt = fileread("`cap'.txt")
    assert strpos(`"`txt'"', "is not one of psvars(") > 0
    quietly log using "`cap'.txt", text replace name(_v192cap)
    psdash combined tr01 ps, covariates(x) psvars(ps x2) nooverlap nosupport
    quietly log close _v192cap
    local txt = fileread("`cap'.txt")
    _v192a_count `"`txt'"' "psvars() applies to multi-group treatments only"
    assert r(n) == 0
}
local rc = _rc
capture log close _v192cap
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec M2_combined_psvars_note_once `rc'
capture graph drop _all

**# T17 (I1): longitudinal combined route with a real msm producer
* The estimand mismatch error echoes the case the user typed, and the
* producer's estimand typed in upper case is accepted.
local repo_dir = substr("`pkgdir'", 1, length("`pkgdir'") - 7)
local plus_now = subinstr("`c(sysdir_plus)'", "\", "/", .)
local plus_box = subinstr("`_qa_plus'", "\", "/", .)
local plus_sandboxed = ("`plus_box'" != "" & strpos("`plus_now'", "`plus_box'") == 1)
capture noisily {
    assert `plus_sandboxed'
    confirm file "`repo_dir'/msm/msm.pkg"
    capture ado uninstall msm
    quietly net install msm, from("`repo_dir'/msm") replace
    use "`repo_dir'/msm/msm_example.dta", clear
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
        censor_n_cov(age sex) truncate(1 99) nolog
    quietly psdash combined
    local prod "`r(estimand)'"
    assert "`prod'" != ""
    local other = cond("`prod'" == "att", "ATE", "ATT")
    tempfile cap
    quietly log using "`cap'.txt", text replace name(_v192cap)
    capture noisily psdash combined, estimand(`other')
    local erc = _rc
    quietly log close _v192cap
    assert `erc' == 198
    local txt = fileread("`cap'.txt")
    * detect refuses first and reports the normalised (lower-case) estimand
    assert strpos(lower(`"`txt'"'), "estimand(" + lower("`other'") + ") does not match") > 0
    * the producer's estimand in upper case is accepted
    quietly psdash combined, estimand(`=strupper("`prod'")')
    assert "`r(estimand)'" == "`prod'"
}
local rc = _rc
capture log close _v192cap
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec I1_longitudinal_estimand_msm `rc'

**# T18 (L3): longitudinal combined title() with embedded quotes
* Needs the compound-quote test in _psdash_ltmle_diagnostics.ado as well as
* the one in psdash_combined.ado.
capture noisily {
    assert `plus_sandboxed'
    quietly psdash combined, title(`"unbalanced " quote"')
    assert "`r(verdict)'" != ""
    quietly psdash combined, title(`"He said "hi""')
    assert "`r(verdict)'" != ""
}
local rc = _rc
capture ado uninstall msm
local ++tests
if `rc' local ++fail
else local ++pass
_v192a_rec L3_longitudinal_title_quotes `rc'
capture graph drop _all

display "RESULT: test_v192_weights_balance_combined tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
if `fail' display as error "Failed:$V192A_FAILED"
global V192A_FAILED
_psdash_qa_cleanup
log close
if `fail' exit 1
