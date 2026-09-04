clear all
version 16.0
set varabbrev off

* test_help_examples.do - documentation reality tests for iivw
*
* Lineage: adapted from the ltmle package's help-example suite.
*
* WHY THIS EXISTS
* ---------------
* A shipped example is part of the API. Audit finding SOL-14 found that it was
* not treated as one: iivw.sthlp and iivw_fit.sthlp both passed truncate(1 99),
* removed in 2.0.0 and now a hard r(198); every example in three help files
* passed censor(fu_end) against a worked dataset that never created fu_end
* (r(111)); and the iivw_exogtest example omitted the end-of-follow-up contract
* the command requires. All of them failed on the first line a user copied.
*
* The sequences below are transcribed from the Examples sections of iivw.sthlp,
* iivw_weight.sthlp and iivw_fit.sthlp. They run against a clean sandboxed PLUS
* directory, so they exercise the same install an ordinary user gets rather
* than the development tree on the author's adopath.
*
* RUNTIME, AND WHY vce(fixed) APPEARS BELOW
* -----------------------------------------
* An IIW/IPTW iivw_fit with no vce() takes the documented default, which is
* vce(bootstrap, reps(999)) [refit] -- 999 refits of the weight models per
* call. H2 runs that IIW default VERBATIM, once, so the documented bootstrap
* path is genuinely exercised end to end. A bare FIPTIW fit is point-only;
* its later examples append vce(fixed) when they explicitly need nominal
* inference. Every later bootstrap-eligible arm also uses vce(fixed) to keep
* the suite inside a QA runtime budget rather than a simulation one; measured,
* the verbatim IIW default is >12 minutes for a single call on this fixture.
*
* That substitution is safe for what this suite is FOR. SOL-14 is about the
* option surface a user copies -- the removed truncate(), the uncreated
* fu_end, the missing exogtest follow-up contract -- and none of those involve
* the variance. The bootstrap default has its own dedicated coverage in
* test_iivw_inference_contract.do and test_iivw_bs_frame_contract.do.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_help_examples.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_help_examples.do must be run from iivw/qa"
    exit 198
}
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

* _help_data -- the worked dataset transcribed verbatim from the Examples
* preamble shared by iivw.sthlp, iivw_weight.sthlp and iivw_fit.sthlp.
*
* fu_end is part of the preamble. If it is ever dropped from the help files
* again, H1 fails here rather than in a user's session.
capture program drop _help_data
program define _help_data
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
    gen byte treatment = cond(treated == 0, 0, cond(edss_bl < 3.5, 1, 2))
    label define arm 0 "Placebo" 1 "Low dose" 2 "High dose", replace
    label values treatment arm
    bysort id (days): egen double fu_end = max(days)
    replace fu_end = fu_end + 30
end

**# H1 - the shared Examples preamble builds every variable the examples use

local ++test_count
capture noisily {
    _help_data
    foreach v in id visit days edss_bl age sex treated edss relapse treatment fu_end {
        confirm variable `v'
    }
    * fu_end is the one SOL-14 found missing: it must be constant within id and
    * at or after the subject's last visit, or every censor(fu_end) call below
    * errors on a contract check rather than running.
    tempvar fmin fmax lastv
    quietly bysort id: egen double `fmin' = min(fu_end)
    quietly bysort id: egen double `fmax' = max(fu_end)
    quietly count if `fmin' != `fmax'
    assert r(N) == 0
    quietly bysort id: egen double `lastv' = max(days)
    quietly count if fu_end < `lastv'
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS H1: Examples preamble is complete and fu_end is a valid censor()"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H1"
    display "FAIL H1: Examples preamble incomplete (error `=_rc')"
}

**# H2 - iivw.sthlp Example 1: IIW only

local ++test_count
capture noisily {
    _help_data
    iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) ///
        lagvars(edss relapse) censor(fu_end) nolog
    iivw_balance
    * VERBATIM: no vce(), so this takes the documented refit-bootstrap default.
    * This is the one arm that pays that cost; see the runtime note above.
    iivw_fit edss treated edss_bl, model(gee) timespec(linear)
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert e(iivw_bs_reps_completed) < .
}
if _rc == 0 {
    local ++pass_count
    display "PASS H2: iivw.sthlp Example 1 (IIW only)"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H2"
    display "FAIL H2: iivw.sthlp Example 1 (error `=_rc')"
}

**# H3 - iivw.sthlp Example 2: FIPTIW

local ++test_count
capture noisily {
    _help_data
    iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) ///
        lagvars(edss relapse) treat(treated) treat_cov(age sex edss_bl) ///
        replace censor(fu_end) nolog
    iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic) vce(fixed)
    assert "`e(iivw_cmd)'" == "iivw_fit"
}
if _rc == 0 {
    local ++pass_count
    display "PASS H3: iivw.sthlp Example 2 (FIPTIW)"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H3"
    display "FAIL H3: iivw.sthlp Example 2 (error `=_rc')"
}

**# H4 - iivw.sthlp Example 3: the full diagnostic decomposition sequence

* This is the sequence SOL-14 singled out: it calls censor(fu_end), then
* iivw_exogtest, then iivw_diagnose across three stored models.
local ++test_count
capture noisily {
    _help_data
    iivw_fit edss treated days relapse age sex edss_bl, unweighted ///
        id(id) time(days) timespec(none) nolog
    estimates store M_unweighted

    iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) ///
        lagvars(edss relapse) treat(treated) treat_cov(age sex edss_bl) ///
        replace censor(fu_end) nolog
    iivw_balance, nolog
    iivw_fit edss treated days relapse age sex edss_bl, model(gee) ///
        timespec(none) replace nolog vce(fixed)
    estimates store M_fiptiw

    gen double log_visit = log(visit + 1)
    iivw_fit edss treated days relapse age sex edss_bl log_visit, ///
        model(gee) timespec(none) replace nolog vce(fixed)
    estimates store M_adjusted

    iivw_exogtest edss relapse, id(id) time(days) censor(fu_end) ///
        adjust(age sex edss_bl) by(treated) nolog

    iivw_diagnose days, unweighted(M_unweighted) weighted(M_fiptiw) ///
        adjusted(M_adjusted) estimand(marginal) exogeneity(unknown)

    * `r(decomposable) < .' is not an assertion about this workflow -- it is
    * true at 0 and at 1, so it could not see that all three fits here are
    * iivw_fit model(gee), i.e. Gaussian identity link, and were nonetheless
    * being reported as a nonlinear-link comparison. This sequence ran the
    * defect for as long as it existed and passed every time. Assert the value.
    assert r(decomposable) == 1
    assert "`r(noncollapsible)'" == ""
    assert r(sample_identical) == 1
}
if _rc == 0 {
    local ++pass_count
    display "PASS H4: iivw.sthlp Example 3 (diagnostic decomposition)"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H4"
    display "FAIL H4: iivw.sthlp Example 3 (error `=_rc')"
}

**# H5 - iivw_weight.sthlp Example 1: basic IIW weights

local ++test_count
capture noisily {
    _help_data
    iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) ///
        lagvars(edss relapse) censor(fu_end) nolog
    summarize _iivw_weight, detail
    confirm variable _iivw_weight
    confirm variable _iivw_iw
    * `confirm variable' is existence-only: an all-missing weight column
    * confirms exactly as well as a weighted one, which is the shape the 4.1.0
    * commit contract exists to refuse. Assert the content the example claims.
    quietly count if !missing(_iivw_weight)
    assert !missing(r(N))
    assert r(N) > 0
    quietly summarize _iivw_weight, meanonly
    assert r(min) > 0 & r(min) < .
    quietly count if !missing(_iivw_iw)
    assert !missing(r(N))
    assert r(N) > 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS H5: iivw_weight.sthlp Example 1"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H5"
    display "FAIL H5: iivw_weight.sthlp Example 1 (error `=_rc')"
}

**# H6 - iivw_weight.sthlp: stabcov() and generate() variants

local ++test_count
capture noisily {
    _help_data
    * stabcov(treated) requires treated to be a main effect of the outcome
    * model that consumes the weights (the SOL-05 contract), which the
    * documented follow-up fit satisfies.
    iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) ///
        lagvars(edss relapse) stabcov(treated) replace censor(fu_end) nolog
    iivw_fit edss treated edss_bl, model(gee) timespec(linear) vce(fixed) nolog
    assert e(iivw_stabilization_validated) == 1

    _help_data
    iivw_weight, id(id) time(days) visit_cov(edss_bl) lagvars(edss) ///
        generate(w_) replace censor(fu_end) nolog
    confirm variable w_weight
}
if _rc == 0 {
    local ++pass_count
    display "PASS H6: iivw_weight.sthlp stabcov()/generate() examples"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H6"
    display "FAIL H6: iivw_weight.sthlp stabcov()/generate() (error `=_rc')"
}

**# H7 - iivw_fit.sthlp: the recipes section

local ++test_count
capture noisily {
    _help_data
    iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) ///
        lagvars(edss relapse) censor(fu_end) nolog

    iivw_fit edss treated age sex edss_bl, timespec(linear) nolog vce(fixed)
    iivw_fit edss treated age sex edss_bl, timespec(ns(3)) replace nolog vce(fixed)
    iivw_fit edss treated age sex edss_bl, timespec(ns(3)) ///
        interaction(treated) replace nolog vce(fixed)
    assert "`e(iivw_cmd)'" == "iivw_fit"
}
if _rc == 0 {
    local ++pass_count
    display "PASS H7: iivw_fit.sthlp analysis recipes"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H7"
    display "FAIL H7: iivw_fit.sthlp analysis recipes (error `=_rc')"
}

**# H8 - iivw_fit.sthlp: the categorical-wave example

local ++test_count
capture noisily {
    _help_data
    gen byte visit_wave = visit
    label define wave 1 "Baseline" 2 "Month 6" 3 "Month 12" 4 "Month 18", replace
    label values visit_wave wave
    iivw_weight, id(id) time(visit_wave) visit_cov(edss_bl relapse) ///
        replace endatlastvisit nolog
    iivw_fit edss treatment edss_bl, timespec(categorical) ///
        categorical(treatment) interaction(treatment) replace vce(fixed)
    assert "`e(iivw_cmd)'" == "iivw_fit"
}
if _rc == 0 {
    local ++pass_count
    display "PASS H8: iivw_fit.sthlp categorical-wave example"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H8"
    display "FAIL H8: iivw_fit.sthlp categorical-wave example (error `=_rc')"
}

**# H9 - no shipped example passes an option the package rejects

* SOL-14's proximate cause: truncate() was removed in 2.0.0 and now errors, but
* six shipped examples still passed truncate(1 99). This scans the help source
* directly, so a reintroduction fails here even if no example above covers it.
local ++test_count
capture noisily {
    local removed_opts "truncate("
    local n_bad = 0
    foreach f in iivw.sthlp iivw_weight.sthlp iivw_fit.sthlp ///
                 iivw_balance.sthlp iivw_exogtest.sthlp iivw_diagnose.sthlp {
        tempname fh
        file open `fh' using "`pkg_dir'/`f'", read text
        file read `fh' line
        while r(eof) == 0 {
            * Only EXAMPLE lines matter: prose may legitimately name a removed
            * option in order to say it was removed.
            if strpos(`"`macval(line)'"', "{phang2}{cmd:. ") > 0 {
                foreach o of local removed_opts {
                    if strpos(`"`macval(line)'"', "`o'") > 0 {
                        display as error "  `f': example passes removed option `o'"
                        local ++n_bad
                    }
                }
            }
            file read `fh' line
        }
        file close `fh'
    }
    assert `n_bad' == 0
}
if _rc == 0 {
    local ++pass_count
    display "PASS H9: no shipped example passes a removed option"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H9"
    display "FAIL H9: a shipped example passes a removed option"
}

**# H10 - iivw_balance.sthlp Examples section runs verbatim

* WHY H10 AND H11 EXIST
* ---------------------
* SOL-14 was recorded as fixed, and it regressed. The fix transcribed only
* iivw.sthlp, iivw_weight.sthlp and iivw_fit.sthlp; iivw_balance.sthlp and
* iivw_exogtest.sthlp were left uncovered, and both carried forward the exact
* two defects SOL-14 named. iivw_balance.sthlp passed censor(fu_end) against a
* setup that never created fu_end (r(111)), and iivw_exogtest.sthlp supplied
* none of censor()/maxfu()/endatlastvisit (r(198)). H9's source scan did not
* catch either: it looks only for the removed truncate() spelling, so a help
* file can fail on its first copied line and still pass this suite.
*
* The lane was 61/61 green with both broken. Transcribing the remaining three
* help files is what closes the gap H9 alone cannot.
local ++test_count
capture noisily {
    clear
    set seed 240526
    set obs 240
    gen long id = ceil(_n/4)
    bysort id: gen byte visit = _n
    gen double months = 3 * (visit - 1) + runiform() * .05
    replace months = 0 if visit == 1
    gen double age = 35 + mod(id, 20)
    gen byte female = mod(id, 2)
    gen double severity = .04 * age + .25 * female + .12 * visit + rnormal()
    gen byte relapse = runiform() < invlogit(-2 + .4 * severity)
    gen double fu_end = 12

    * The administrative end must cover every observed visit, or the risk
    * window the example demonstrates is not the one the help describes.
    quietly summarize months, meanonly
    assert r(max) < 12

    iivw_weight, id(id) time(months) visit_cov(age female) ///
        lagvars(severity relapse) censor(fu_end) nolog
    iivw_balance
}
if _rc == 0 {
    local ++pass_count
    display "PASS H10: iivw_balance.sthlp example runs verbatim"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H10"
    display "FAIL H10: iivw_balance.sthlp example (error `=_rc')"
}

**# H11 - iivw_exogtest.sthlp Examples section runs verbatim

local ++test_count
capture noisily {
    clear
    set seed 240526
    set obs 240
    gen id = ceil(_n/4)
    bysort id: gen visit = _n
    gen treatment = mod(id,2)
    gen age = 35 + mod(id,20)
    gen female = mod(id,3)==0
    bysort id: gen double sdmt = 45 - .15*age + 1.5*treatment + rnormal() if visit==1
    bysort id: replace sdmt = sdmt[_n-1] + .3*treatment + rnormal() if visit>1
    gen recent_relapse = runiform() < invlogit(-2 + .04*(50-sdmt))
    bysort id (visit): gen double gap = 3 + .02*(50-sdmt[_n-1]) + runiform() if visit>1
    bysort id (visit): replace gap = 0 if visit==1
    bysort id (visit): gen double months = sum(gap)
    gen double fu_end = 15

    quietly summarize months, meanonly
    assert r(max) < 15

    iivw_exogtest sdmt recent_relapse, id(id) time(months) censor(fu_end) ///
        adjust(age female) efron nolog
    iivw_exogtest sdmt recent_relapse, id(id) time(months) censor(fu_end) ///
        adjust(age female) by(treatment) replace efron nolog
    iivw_exogtest sdmt, id(id) time(months) censor(fu_end) ///
        generate(x_) replace nolog
}
if _rc == 0 {
    local ++pass_count
    display "PASS H11: iivw_exogtest.sthlp example runs verbatim"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H11"
    display "FAIL H11: iivw_exogtest.sthlp example (error `=_rc')"
}

**# H12 - iivw_diagnose.sthlp Examples section runs verbatim

local ++test_count
capture noisily {
    * Transcribed from iivw_diagnose.sthlp Examples 1-4. This help file drives
    * iivw_diagnose from three STORED estimates rather than from the
    * iivw_weight pipeline, so the setup is deliberately unlike H10/H11.
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
    * The example is documented as producing a decomposition; check that it
    * did. Running to rc 0 is satisfied equally by a table of missing values.
    * The gaps are ROWS of r(decomp), not scalars -- reading them as
    * r(sampling_gap) yields missing, and the check would fail permanently.
    assert "`r(depvar)'" == "price"
    matrix h12_D = r(decomp)
    local h12_s = rownumb(h12_D, "sampling_gap")
    local h12_a = rownumb(h12_D, "artifact_gap")
    local h12_t = rownumb(h12_D, "total_gap")
    assert !missing(`h12_s', `h12_a', `h12_t')
    assert !missing(h12_D[`h12_s',1], h12_D[`h12_a',1], h12_D[`h12_t',1])
    assert !missing(h12_D[`h12_s',1] + h12_D[`h12_a',1])
    assert reldif(h12_D[`h12_t',1], h12_D[`h12_s',1] + h12_D[`h12_a',1]) < 1e-10
    matrix drop h12_D
    iivw_diagnose mpg, unweighted(M_unweighted) weighted(M_weighted) ///
        adjusted(M_adjusted) exogeneity(endogenous)
    matrix h12_E = r(decomp)
    assert !missing(h12_E[rownumb(h12_E, "sampling_gap"),1], ///
                    h12_E[rownumb(h12_E, "artifact_gap"),1])
    matrix drop h12_E
    iivw_diagnose mpg, unweighted(M_unweighted) weighted(M_weighted) ///
        adjusted(M_adjusted) true(0) exogeneity(unknown)

    * Example 4 exports. Send it to a scratch path rather than the qa/ tree:
    * a generated .xlsx is an artifact and must not be left behind.
    tempfile xlsxpath
    iivw_diagnose mpg, unweighted(M_unweighted) weighted(M_weighted) ///
        adjusted(M_adjusted) exogeneity(unknown) ///
        xlsx("`xlsxpath'.xlsx") sheet(Diagnostics) replace
    capture erase "`xlsxpath'.xlsx"
    estimates drop M_unweighted M_weighted M_adjusted
}
if _rc == 0 {
    local ++pass_count
    display "PASS H12: iivw_diagnose.sthlp example runs verbatim"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H12"
    display "FAIL H12: iivw_diagnose.sthlp example (error `=_rc')"
}

**# H13 - every help file with an Examples section is transcribed above

* H10-H12 close today's gap; this stops the NEXT one. A new .sthlp, or a new
* Examples section in an existing one, must be added to this suite rather than
* inheriting a silent pass. The check is on the shipped file set, so adding a
* help file without a transcription fails here.
local ++test_count
capture noisily {
    local covered "iivw.sthlp iivw_weight.sthlp iivw_fit.sthlp"
    local covered "`covered' iivw_balance.sthlp iivw_exogtest.sthlp"
    local covered "`covered' iivw_diagnose.sthlp"
    local helpfiles : dir "`pkg_dir'" files "*.sthlp"
    local uncovered ""
    foreach f of local helpfiles {
        * Only files that actually invite copy/paste need a transcription.
        tempname fh
        local has_examples = 0
        file open `fh' using "`pkg_dir'/`f'", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "{title:Examples}") > 0 {
                local has_examples = 1
            }
            file read `fh' line
        }
        file close `fh'
        if `has_examples' == 1 {
            local hit : list posof "`f'" in covered
            if `hit' == 0 local uncovered "`uncovered' `f'"
        }
    }
    if "`uncovered'" != "" {
        display as error "help files with Examples but no transcription:`uncovered'"
    }
    assert "`uncovered'" == ""
}
if _rc == 0 {
    local ++pass_count
    display "PASS H13: every Examples section is transcribed in this suite"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' H13"
    display "FAIL H13: an Examples section is untranscribed (error `=_rc')"
}

**# SUMMARY

iivw_qa_summary, name(test_help_examples) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed_tests'")
