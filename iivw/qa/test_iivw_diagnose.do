clear all
version 16.0
set varabbrev off

* test_iivw_diagnose.do - focused QA for iivw_diagnose
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_diagnose.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_diagnose.do must be run from iivw/qa"
    exit 198
}
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"
ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _iivw_diag_post
program define _iivw_diag_post, eclass
    version 16.0
    args estname b se
    tempname bmat vmat
    matrix `bmat' = (`b')
    matrix colnames `bmat' = x
    matrix `vmat' = (`se'^2)
    matrix rownames `vmat' = x
    matrix colnames `vmat' = x
    ereturn post `bmat' `vmat', obs(100)
    ereturn local cmd "regress"
    * e(depvar) is required from 4.1.1: iivw_diagnose decides "same estimand"
    * by comparing e(depvar)/e(cmd) across the three roles, and a mock that
    * posts neither made that gate compare "" with "" and pass vacuously.
    ereturn local depvar "y"
    estimates store `estname'
end

capture program drop _iivw_diag_known
program define _iivw_diag_known
    version 16.0
    estimates clear
    _iivw_diag_post M_unw 0.42 0.08
    _iivw_diag_post M_wgt 0.31 0.09
    _iivw_diag_post M_adj 0.10 0.10
end

**# T1: known stored estimates produce correct gaps and shares

local ++test_count
capture noisily {
    _iivw_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        exogeneity(exogenous)
    matrix E = r(estimates)
    matrix D = r(decomp)
    assert !missing(E[1,1], 0.42)
    assert reldif(E[1,1], 0.42) < 1e-12
    assert !missing(E[2,1], 0.31)
    assert reldif(E[2,1], 0.31) < 1e-12
    assert !missing(E[3,1], 0.10)
    assert reldif(E[3,1], 0.10) < 1e-12
    assert !missing(D[1,1], 0.11)
    assert reldif(D[1,1], 0.11) < 1e-12
    assert !missing(D[2,1], 0.21)
    assert reldif(D[2,1], 0.21) < 1e-12
    assert !missing(D[3,1], 0.32)
    assert reldif(D[3,1], 0.32) < 1e-12
    assert !missing(D[4,1], 0.34375)
    assert reldif(D[4,1], 0.34375) < 1e-12
    assert !missing(D[5,1], 0.65625)
    assert reldif(D[5,1], 0.65625) < 1e-12
    assert "`r(conclusion)'" == "shares_descriptive"
    assert rowsof(E) == 3
    assert colsof(E) == 4
}
if _rc == 0 {
    display as result "  PASS: T1 - known gaps and shares"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - known gaps and shares (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: true() computes known biases

local ++test_count
capture noisily {
    _iivw_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        true(0.10) exogeneity(unknown)
    matrix B = r(bias)
    assert !missing(B[1,1], 0.10)
    assert reldif(B[1,1], 0.10) < 1e-12
    assert !missing(B[2,1], 0.32)
    assert reldif(B[2,1], 0.32) < 1e-12
    assert !missing(B[3,1], 0.21)
    assert reldif(B[3,1], 0.21) < 1e-12
    assert abs(B[4,1]) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T2 - true() bias returns"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - true() bias returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: missing coefficient errors clearly

local ++test_count
capture noisily {
    _iivw_diag_known
    capture noisily iivw_diagnose z, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T3 - missing coefficient rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - missing coefficient rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: missing stored estimate name errors clearly

local ++test_count
capture noisily {
    _iivw_diag_known
    capture noisily iivw_diagnose x, unweighted(NO_SUCH_EST) weighted(M_wgt) ///
        adjusted(M_adj)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T4 - missing stored estimate rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - missing stored estimate rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: tiny total gap suppresses share calculation

local ++test_count
capture noisily {
    estimates clear
    _iivw_diag_post M_unw 0.100000001 0.01
    _iivw_diag_post M_wgt 0.1000000005 0.01
    _iivw_diag_post M_adj 0.100000000 0.01
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj)
    matrix D = r(decomp)
    assert missing(D[4,1])
    assert missing(D[5,1])
    assert "`r(conclusion)'" == "unstable"
}
if _rc == 0 {
    display as result "  PASS: T5 - tiny total gap suppresses shares"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - tiny total gap suppresses shares (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: sign-inconsistent shares return without crashing

local ++test_count
capture noisily {
    estimates clear
    _iivw_diag_post M_unw 0.10 0.01
    _iivw_diag_post M_wgt 0.20 0.01
    _iivw_diag_post M_adj 0.00 0.01
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj)
    matrix D = r(decomp)
    assert D[4,1] < 0
    assert D[5,1] > 1
    assert "`r(conclusion)'" == "sign_inconsistent"
}
if _rc == 0 {
    display as result "  PASS: T6 - sign-inconsistent shares handled"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - sign-inconsistent shares handled (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: exogeneity(endogenous) returns bounds and conclusion

local ++test_count
capture noisily {
    _iivw_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        exogeneity(endogenous)
    matrix D = r(decomp)
    assert !missing(D[6,1], 0.10)
    assert reldif(D[6,1], 0.10) < 1e-12
    assert !missing(D[7,1], 0.31)
    assert reldif(D[7,1], 0.31) < 1e-12
    assert "`r(conclusion)'" == "bounds"
}
if _rc == 0 {
    display as result "  PASS: T7 - endogenous bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - endogenous bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: active estimates are preserved after command

local ++test_count
capture noisily {
    _iivw_diag_known
    clear
    set obs 40
    gen double z = _n
    gen double y = 1 + 2 * z
    regress y z
    local active_b = _b[z]
    local active_cmd "`e(cmd)'"
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj)
    assert "`e(cmd)'" == "`active_cmd'"
    assert !missing(_b[z], `active_b')
    assert reldif(_b[z], `active_b') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T8 - active estimates preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - active estimates preserved (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9: works with estimates stored after raw glm

local ++test_count
capture noisily {
    estimates clear
    clear
    set obs 120
    gen long id = ceil(_n / 4)
    bysort id: gen double t = _n
    gen double w = cond(mod(id, 2), 1.4, 0.8)
    gen double visits = t
    gen double y = 2 + 0.50 * t + 0.15 * mod(id, 3) + 0.30 * visits
    glm y t, family(gaussian) link(identity) vce(cluster id)
    estimates store G_unw
    glm y t [pw=w], family(gaussian) link(identity) vce(cluster id)
    estimates store G_wgt
    glm y t visits [pw=w], family(gaussian) link(identity) vce(cluster id)
    estimates store G_adj
    iivw_diagnose t, unweighted(G_unw) weighted(G_wgt) adjusted(G_adj)
    matrix E = r(estimates)
    assert E[1,1] != .
    assert E[2,1] != .
    assert E[3,1] != .
    assert "`r(coefficient)'" == "t"
}
if _rc == 0 {
    display as result "  PASS: T9 - raw glm stored estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - raw glm stored estimates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# T10: estimand(contrast) suppresses share returns

local ++test_count
capture noisily {
    _iivw_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        estimand(contrast)
    matrix D = r(decomp)
    assert missing(D[4,1])
    assert missing(D[5,1])
    assert "`r(conclusion)'" == "movement_only"
}
if _rc == 0 {
    display as result "  PASS: T10 - contrast suppresses shares"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - contrast suppresses shares (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

**# T11: invalid option values are rejected

local ++test_count
capture noisily {
    _iivw_diag_known
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) estimand(bad)
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) exogeneity(bad)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T11 - invalid options rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - invalid options rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}

**# T12: help-file example pattern runs with shipped Stata data

local ++test_count
capture noisily {
    estimates clear
    sysuse auto, clear
    gen double visit_w = cond(foreign, 1.30, 0.85)
    regress price mpg
    estimates store M_unweighted
    regress price mpg [pw=visit_w]
    estimates store M_weighted
    regress price mpg weight [pw=visit_w]
    estimates store M_adjusted
    iivw_diagnose mpg, unweighted(M_unweighted) weighted(M_weighted) ///
        adjusted(M_adjusted) exogeneity(exogenous)
    assert "`r(coefficient)'" == "mpg"
    assert "`r(estimand)'" == "marginal"
    iivw_diagnose mpg, unweighted(M_unweighted) we(M_weighted) ///
        ad(M_adjusted) tr(0) ex(unknown)
    matrix B = r(bias)
    assert B[1,1] == 0
}
if _rc == 0 {
    display as result "  PASS: T12 - help-file example pattern and abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - help-file example pattern and abbreviations (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T12"
}

**# T13: accepts estimates stored after iivw_fit, unweighted

local ++test_count
capture noisily {
    estimates clear
    clear
    set obs 120
    gen long id = ceil(_n / 4)
    bysort id: gen double t = _n
    gen double x = sin(id / 5)
    gen double z = cos(id / 7)
    gen double y = 1 + 0.20 * t + 0.40 * x + 0.10 * z

    iivw_fit y x z, unweighted id(id) time(t) timespec(linear) nolog
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_weighttype)'" == "unweighted"
    local fit_b = _b[x]
    estimates store F_unweighted

    glm y x z t, family(gaussian) link(identity) vce(cluster id)
    estimates store F_weighted
    glm y x z t, family(gaussian) link(identity) vce(cluster id)
    estimates store F_adjusted

    iivw_diagnose x, unweighted(F_unweighted) weighted(F_weighted) ///
        adjusted(F_adjusted)
    matrix E = r(estimates)
    assert !missing(E[1,1], `fit_b')
    assert reldif(E[1,1], `fit_b') < 1e-10
    assert "`r(unweighted)'" == "F_unweighted"
}
if _rc == 0 {
    display as result "  PASS: T13 - iivw_fit unweighted stored estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 - iivw_fit unweighted stored estimates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T13"
}

**# T14: removed excel()/digits() synonyms are rejected (v1.6.0 breaking change)

local ++test_count
capture noisily {
    _iivw_diag_known
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) excel("nope.xlsx")
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) digits(2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T14 - removed excel()/digits() synonyms rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T14 - removed synonyms rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T14"
}

* ============================================================================
* T15-T18: the COLLAPSIBILITY / SCALE axis.
*
* T9 above already fits `glm ..., family(gaussian) link(identity)' and passes
* the estimates in -- but it asserts only that r(estimates) holds numbers and
* that r(coefficient) is right. It never asks the question these four ask, and
* neither did any other caller of iivw_diagnose in this tree: every one of them
* builds its roles from plain -regress-, which is the single estimator whose
* scale is decided by the e(cmd) list rather than by e(family)/e(link). All
* four documented examples in iivw_diagnose.sthlp use -regress- too.
*
* That left the package's OWN workflow untested. README "Diagnostic workflow"
* and demo/demo_iivw.do both feed iivw_fit estimates straight into
* iivw_diagnose, and iivw_fit's model(gee) path is -glm-, which does not set
* e(family) at all and puts the internal link PROGRAM name ("glim_l01") in
* e(link). Measured on the pre-fix build: T15 returned decomposable == 0 with
* the note "identity-link collapsibility not established" for a Gaussian
* identity-link fit, and T17 decomposed a Gaussian fit against a GAMMA fit at
* rc 0, reporting a 100% artifact share.
* ============================================================================

capture program drop _iivw_diag_panel
program define _iivw_diag_panel
    version 16.0
    args seed
    clear
    set seed `seed'
    quietly set obs 90
    gen long id = _n
    gen double z = rnormal()
    gen byte A = runiform() < invlogit(0.5 * z)
    gen double cens = 12
    quietly expand 5
    bysort id: gen int k = _n
    gen double time = (k - 1) * 2 + runiform() * 1.5
    bysort id (time): replace time = 0.1 if _n == 1
    gen double y = 1 + 0.5 * A + 0.3 * z + rnormal()
    gen byte yb = runiform() < invlogit(-0.2 + 0.5 * A)
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(cens) nolog replace
end

**# T15: an identity-link iivw_fit trio IS decomposable

* The one case the decomposition is valid for, built the way the README and the
* demo build it. Fails on the pre-fix build (decomposable == 0).
local ++test_count
capture noisily {
    _iivw_diag_panel 15150
    quietly iivw_fit y A, timespec(none) unweighted nolog replace
    estimates store D_unw
    quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
    estimates store D_wgt
    quietly iivw_fit y A z, timespec(none) vce(fixed) nolog replace
    estimates store D_adj

    * the fits really are Gaussian/identity, and really are iivw_fit
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(varfunct)'" == "Gaussian"
    assert "`e(linkt)'" == "Identity"
    * and the keys the pre-fix code read really are uninformative -- without
    * this the test could pass for the wrong reason on some future Stata that
    * starts populating e(family)
    assert "`e(family)'" == ""
    assert "`e(link)'" != "identity"

    iivw_diagnose A, unweighted(D_unw) weighted(D_wgt) adjusted(D_adj) ///
        estimand(marginal) exogeneity(exogenous)
    assert `r(decomposable)' == 1
    assert "`r(noncollapsible)'" == ""
    assert `r(sample_identical)' == 1
}
if _rc == 0 {
    display as result "  PASS: T15 - identity-link iivw_fit trio is decomposable"
    local ++pass_count
}
else {
    display as error "  FAIL: T15 - identity-link iivw_fit trio is decomposable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T15"
}

**# T16: a NONLINEAR iivw_fit trio is still refused

* The positive control for T15. Without it, T15 passes just as well against a
* build that called every fit collapsible -- which is the obvious wrong fix.
* This case passes on the pre-fix build too, and is a regression guard.
local ++test_count
capture noisily {
    _iivw_diag_panel 16160
    quietly iivw_fit yb A, timespec(none) family(binomial) link(logit) ///
        unweighted nolog replace
    estimates store B_unw
    quietly iivw_fit yb A, timespec(none) family(binomial) link(logit) ///
        vce(fixed) nolog replace
    estimates store B_wgt
    quietly iivw_fit yb A z, timespec(none) family(binomial) link(logit) ///
        vce(fixed) nolog replace
    estimates store B_adj
    assert "`e(varfunct)'" == "Bernoulli"

    iivw_diagnose A, unweighted(B_unw) weighted(B_wgt) adjusted(B_adj) ///
        estimand(marginal) exogeneity(exogenous)
    assert `r(decomposable)' == 0
    assert strpos("`r(noncollapsible)'", "collapsibility not established") > 0
}
if _rc == 0 {
    display as result "  PASS: T16 - nonlinear iivw_fit trio stays non-decomposable"
    local ++pass_count
}
else {
    display as error "  FAIL: T16 - nonlinear iivw_fit trio stays non-decomposable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T16"
}

**# T17: a FAMILY change at an unchanged link is refused

* glm gives gaussian/identity and gamma/identity the SAME e(link) ("glim_l01")
* and an empty e(family) for both, so the comparability gate compared two empty
* strings and saw nothing. Fails on the pre-fix build (rc 0, and a full
* decomposition table printed for a Gaussian-against-Gamma comparison).
local ++test_count
capture noisily {
    _iivw_diag_panel 17170
    quietly glm y A, family(gaussian) link(identity) vce(cluster id)
    estimates store F_unw
    quietly glm y A, family(gaussian) link(identity) vce(cluster id)
    estimates store F_wgt
    quietly glm y A z, family(gamma) link(identity) vce(cluster id)
    estimates store F_adj

    capture noisily iivw_diagnose A, unweighted(F_unw) weighted(F_wgt) ///
        adjusted(F_adj) estimand(marginal) exogeneity(exogenous)
    assert _rc == 198

    * a LINK change was already caught before the fix; assert it still is, so
    * the family repair cannot have been made by loosening the link check
    _iivw_diag_panel 17171
    quietly glm y A, family(gaussian) link(identity) vce(cluster id)
    estimates store L_unw
    quietly glm y A, family(gaussian) link(identity) vce(cluster id)
    estimates store L_wgt
    quietly glm y A z, family(gaussian) link(log) vce(cluster id)
    estimates store L_adj
    capture noisily iivw_diagnose A, unweighted(L_unw) weighted(L_wgt) ///
        adjusted(L_adj) estimand(marginal) exogeneity(exogenous)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T17 - family change at an unchanged link is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T17 - family change at an unchanged link is refused (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T17"
}

**# T18: the incomparability report is ONE line per finding, not per word

* Every phrase in that report contains spaces, and the display loop used to be
* `foreach ... of local', which splits on whitespace -- so a single finding was
* printed as one line per word. It stayed invisible because the only branch QA
* ever triggered was the family/link one, whose message was a single word
* before T17 above started exercising it.
*
* The needle is assembled at run time so this file's own source text cannot be
* what the search matches: a batch log echoes the commands it runs, and a
* literal here would be found in the echo whether or not the command printed it.
local ++test_count
capture noisily {
    _iivw_diag_panel 18180
    quietly regress y A
    estimates store W_unw
    quietly regress y A
    estimates store W_wgt
    * a DIFFERENT outcome -- one finding, and its phrase holds 6 words
    quietly regress yb A z
    estimates store W_adj

    * One name, used for both the write and the read. A tempfile path already
    * ends in ".tmp", so -log using- does NOT append ".log" to it and reading
    * back "`difflog'.log" is r(601). Naming the file explicitly avoids relying
    * on that rule at all. The log is NAMED so it cannot disturb the batch log
    * this suite is itself running under.
    tempfile difflog
    local t18log "`difflog'_t18.log"
    log using "`t18log'", replace text name(_iivw_t18)
    capture noisily iivw_diagnose A, unweighted(W_unw) weighted(W_wgt) ///
        adjusted(W_adj) estimand(marginal)
    local _t18_rc = _rc
    log close _iivw_t18
    assert `_t18_rc' == 198

    local needle = "mis" + "match:"
    * The read is wrapped so -restore- runs on every path. A do-file -preserve-
    * leaves a PENDING restore if the block between it and -restore- throws, and
    * the next -preserve- in the file then fails with r(621) -- a failure that
    * would be attributed to whatever test came after this one.
    local n_lines = .
    local n_whole = .
    preserve
    capture {
        quietly infix str200 line 1-200 using "`t18log'", clear
        quietly count if strpos(line, "`needle'") > 0
        local n_lines = r(N)
        * the outcome phrase is "outcome(adjusted: yb vs unweighted: y)". Pre-fix
        * this printed one line per word; there is exactly ONE finding, so
        * exactly one line must carry the marker, and it must carry the phrase
        * whole rather than split across lines.
        quietly count if strpos(line, "outcome(adjusted:") > 0 & ///
            strpos(line, "unweighted: y)") > 0
        local n_whole = r(N)
    }
    local _t18_read_rc = _rc
    restore
    assert `_t18_read_rc' == 0
    assert `n_lines' == 1
    assert `n_whole' == 1

    * The SAMPLE branch is the other one whose phrase contains spaces, and it is
    * the only one that interpolates a number computed by the preceding -count-
    * with an intervening statement between the two. Cover it separately: the
    * outcome branch above cannot show that `r(N)' still holds the row count by
    * the time the message is built.
    * auto, not the panel fixture above: this half needs a dataset where
    * dropping a fixed number of rows gives a known row-count difference.
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store W2_unw
    quietly regress price mpg weight
    estimates store W2_wgt
    quietly regress price mpg weight if _n > 5     // 74 -> 69 rows
    estimates store W2_adj

    local t18log2 "`difflog'_t18b.log"
    log using "`t18log2'", replace text name(_iivw_t18b)
    capture noisily iivw_diagnose mpg, unweighted(W2_unw) weighted(W2_wgt) ///
        adjusted(W2_adj) estimand(marginal)
    local _t18b_rc = _rc
    log close _iivw_t18b
    assert `_t18b_rc' == 198

    local n_lines2 = .
    local n_whole2 = .
    preserve
    capture {
        quietly infix str220 line 1-220 using "`t18log2'", clear
        quietly count if strpos(line, "`needle'") > 0
        local n_lines2 = r(N)
        * whole phrase, with the row-difference count intact: 74 - 69 = 5
        quietly count if strpos(line, "sample(adjusted: 69 obs") > 0 & ///
            strpos(line, "74 obs, 5 row(s) differ)") > 0
        local n_whole2 = r(N)
    }
    local _t18b_read_rc = _rc
    restore
    assert `_t18b_read_rc' == 0
    assert `n_lines2' == 1
    assert `n_whole2' == 1
}
if _rc == 0 {
    display as result "  PASS: T18 - incomparability report is one line per finding"
    local ++pass_count
}
else {
    display as error "  FAIL: T18 - incomparability report is one line per finding (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T18"
}

**# T19: Greenland-Robins-Pearl Table 2 -- noncollapsibility with ZERO confounding

* A PUBLISHED known answer, not a simulation. Greenland, Robins & Pearl (1999),
* Statistical Science 14(1):29-46, section 5.1 "The Divergence", Table 2, p.39
* gives a population in which Z is not a confounder and the odds ratio still
* moves when you condition on it:
*
*     stratum   P(resp|X=x1)  P(resp|X=x0)   size
*     Z=1           0.8           0.6        1000
*     Z=0           0.4           0.2        1000
*     crude         0.6           0.4        2000
*
* The paper's own arithmetic: crude OR = (0.6/0.4)/(0.4/0.6) = 2.25; within
* levels of Z the OR is (0.8/0.2)/(0.6/0.4) = 8/3 = 2.67, "higher than the
* unconditional (crude) odds ratio of 2.25 obtained when Z is ignored", and
* "there is no confounding of the odds ratio". Z is balanced 1000/1000 across
* X by construction, so the TRUE artifact here is exactly zero and the whole
* 2.25 -> 2.67 movement is noncollapsibility.
*
* This is the case iivw_diagnose's scale gate exists for, with a target taken
* from the source rather than from this suite. test_iivw_failclosed S7c makes
* the same point with a random logit DGP and nothing published to check against.
local ++test_count
capture noisily {
    clear
    * one row per (X, Z, response) cell, expanded to the paper's counts
    quietly set obs 8
    gen byte x  = inlist(_n, 1, 2, 3, 4)
    gen byte Z  = inlist(_n, 1, 2, 5, 6)
    gen byte y  = inlist(_n, 1, 3, 5, 7)
    gen int  n  = .
    quietly replace n = 800 in 1      // x=1 Z=1 y=1
    quietly replace n = 200 in 2      // x=1 Z=1 y=0
    quietly replace n = 400 in 3      // x=1 Z=0 y=1
    quietly replace n = 600 in 4      // x=1 Z=0 y=0
    quietly replace n = 600 in 5      // x=0 Z=1 y=1
    quietly replace n = 400 in 6      // x=0 Z=1 y=0
    quietly replace n = 200 in 7      // x=0 Z=0 y=1
    quietly replace n = 800 in 8      // x=0 Z=0 y=0
    quietly expand n
    drop n

    * Z is balanced across X -- this is what makes confounding exactly zero
    quietly count if x == 1 & Z == 1
    assert r(N) == 1000
    quietly count if x == 0 & Z == 1
    assert r(N) == 1000

    * The two published odds ratios, reproduced against the paper.
    *
    * 1e-6, not 1e-8, and the reason is measured rather than assumed: the crude
    * fit lands at reldif 1.2e-12 of 2.25, but the two-covariate fit lands at
    * 2.6666665588 -- reldif 2.9e-8 of 8/3. That is -logit-'s own gradient
    * convergence criterion, not a settable tolerance: re-running with
    * tolerance(1e-12) nrtolerance(1e-12) reproduces 2.9e-8 exactly. 1e-6 still
    * pins the published value to seven significant figures.
    quietly logit y x
    assert !missing(exp(_b[x]), 2.25)
    assert reldif(exp(_b[x]), 2.25) < 1e-6
    estimates store GRP_unw
    quietly logit y x
    estimates store GRP_wgt
    quietly logit y x Z
    assert !missing(exp(_b[x]), 8/3)
    assert reldif(exp(_b[x]), 8/3) < 1e-6
    estimates store GRP_adj

    * ...and the gate refuses to call their difference a decomposition
    quietly iivw_diagnose x, unweighted(GRP_unw) weighted(GRP_wgt) ///
        adjusted(GRP_adj) estimand(marginal) exogeneity(exogenous)
    assert `r(decomposable)' == 0
    assert "`r(noncollapsible)'" != ""

    * the movement it would otherwise have booked as "artifact" is exactly the
    * paper's noncollapsibility, and the true artifact is zero
    matrix GRPd = r(decomp)
    local grp_artifact = log(8/3) - log(2.25)
    assert !missing(abs(GRPd[2,1]), abs(`grp_artifact'))
    assert reldif(abs(GRPd[2,1]), abs(`grp_artifact')) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: T19 - GRP Table 2 noncollapsibility without confounding"
    local ++pass_count
}
else {
    display as error "  FAIL: T19 - GRP Table 2 noncollapsibility without confounding (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T19"
}

capture adopath - "`pkg_dir'"
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_diagnose tests=`test_count' pass=`pass_count' fail=`fail_count'"
    display as error "Failed tests:`failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_diagnose tests=`test_count' pass=`pass_count' fail=`fail_count'"
