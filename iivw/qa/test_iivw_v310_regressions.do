* test_iivw_v310_regressions.do
* Regression coverage for the four defects fixed in 3.1.0:
*   T1  the runtime note for a first visit at exactly time 0 must not promise
*       the study-entry weight of 1, because the row does not get it
*   T2  iivw_weight.sthlp must not promise it either
*   T3  trunctreat() cutpoints are invariant to visit count
*   T4  trunctreat() reports the subject unit and the subject count
*   T5  r(refit_n_target_unusable) exists and gates the balance verdict
*   T6  iivw_balance's baseline-hazard lookup keeps its row-count invariant
*
* Every case here fails on the 3.0.0 code; T1/T2/T3/T4 were confirmed to fail
* against a checkout of the released files before this file was committed.

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

**# Fixtures

* A panel whose visit SPACING depends on z, so exp(-xb) is genuinely not 1 and
* a first-visit weight of 1 is distinguishable from a fitted one. A fixture
* with no intensity signal cannot tell the two apart -- the first probe of this
* defect used equally spaced visits, measured HR = 1.000, and could not see it.
capture program drop _iivw_v310_t0_panel
program define _iivw_v310_t0_panel
    version 16.0
    syntax [, Nsubj(integer 120) Tau(real 12) ]
    clear
    set seed 71
    set obs `nsubj'
    gen long id = _n
    gen double z = rnormal()
    gen double gap = 1.2 * exp(-0.6 * z)
    expand 12
    bysort id: gen double t = sum(gap) - gap
    quietly drop if t > `tau'
    bysort id: gen byte nv = _N
    quietly drop if nv < 2
    drop nv gap
    gen double y = z + rnormal()
end

* 40 subjects, one of them an UNTREATED case with propensity ~ 1 (so its IPT
* weight is large) whose visit count is a parameter. The propensity model is
* fitted on one row per subject, so the raw weight is identical whatever
* nvis() is -- which is exactly what makes the cutpoint comparison valid.
capture program drop _iivw_v310_trim_panel
program define _iivw_v310_trim_panel
    version 16.0
    syntax [, Nvis(integer 200) ]
    clear
    set seed 909
    set obs 40
    gen long id = _n
    gen double x = rnormal()
    gen byte a = runiform() < invlogit(1.5 * x)
    quietly replace x = 4 if id == 1
    quietly replace a = 0 if id == 1
    gen int nv = 2
    quietly replace nv = `nvis' if id == 1
    expand nv
    drop nv
    bysort id: gen double t = _n
    gen double y = a + x + rnormal()
end

* Collapse a file to one space-separated string so a phrase match is decoupled
* from source wrapping. `document reflow' rewraps prose render-neutrally, so a
* line-by-line search silently turns a required phrase into a failure and, far
* worse, lets a forbidden one back in undetected.
*
* @BT@ and @AP@ stand for a backtick and an apostrophe. A needle that has to
* match Stata source containing a tempvar reference cannot be written as a
* string literal here -- Stata would expand it as a local-macro reference and
* silently shorten the needle, which passes every assertion built on it. The
* substitution happens in Mata, where the two characters are just data.
*
* Every Mata statement below is one physical line on purpose: `///' is a
* COMMENT to Mata (it reads `//'), so a continued Mata statement in a do-file
* is mangled rather than joined.
capture program drop _iivw_v310_count_phrase
program define _iivw_v310_count_phrase, rclass
    version 16.0
    syntax , File(string) PHrase(string)
    mata: _v310t = stritrim(subinstr(invtokens(cat(st_local("file"))', " "), char(9), " "))
    mata: _v310p = st_local("phrase")
    mata: _v310p = subinstr(_v310p, "@BT@", char(96), .)
    mata: _v310p = subinstr(_v310p, "@AP@", char(39), .)
    mata: st_local("v310n", strofreal((strlen(_v310t) - strlen(subinstr(_v310t, _v310p, "", .))) / strlen(_v310p)))
    mata: mata drop _v310t _v310p
    return scalar n = `v310n'
end

**# T1: the runtime note must not promise the study-entry weight of 1

* The note fires under baseline(event) when a first visit sits at time 0. The
* row is excluded from the partial likelihood by stset (its (0,0] interval
* spans no risk time) but `predict, xb' still yields a linear predictor from
* its covariates, so it carries a FITTED weight. Through 3.0.0 the note said
* "they keep the conventional weight of 1" while the code fitted one; measured
* on this fixture, 0 of 120 such rows had weight 1 and they ranged 0.572-1.757.
local ++test_count
capture noisily {
    _iivw_v310_t0_panel

    tempfile notelog
    log using "`notelog'", replace text name(v310note)
    iivw_weight, id(id) time(t) visit_cov(z) wtype(iivw) ///
        baseline(event) maxfu(12) nolog
    log close v310note

    * (a) the note fired at all -- otherwise (b) and (c) are vacuous
    _iivw_v310_count_phrase, file("`notelog'") ///
        phrase("subjects have their first visit at time 0")
    assert r(n) == 1

    * (b) the retracted promise is gone
    _iivw_v310_count_phrase, file("`notelog'") ///
        phrase("they keep the conventional weight of 1")
    assert r(n) == 0
    _iivw_v310_count_phrase, file("`notelog'") ///
        phrase("keep the conventional weight of 1")
    assert r(n) == 0

    * (c) the note now describes what actually happens
    _iivw_v310_count_phrase, file("`notelog'") ///
        phrase("still carry a fitted weight exp(-xb) from their own covariates")
    assert r(n) == 1

    * (d) and the BEHAVIOUR the note now describes is the behaviour on disk.
    * This is the half that makes the message test more than a string check:
    * assert the fitted weights vary and that none is the study-entry 1.
    bysort id (t): gen byte v310_first = (_n == 1)
    quietly count if v310_first
    assert r(N) == 120
    quietly count if v310_first & t == 0
    assert r(N) == 120
    quietly count if v310_first & abs(_iivw_iw - 1) < 1e-12
    assert r(N) == 0
    quietly summarize _iivw_iw if v310_first
    assert !missing(r(sd))
    assert r(sd) > 1e-6
    drop v310_first
}
if _rc == 0 {
    display as result "  PASS: T1 - time-0 note does not promise weight 1"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - time-0 runtime note (error `=_rc')"
    local ++fail_count
    local failed "`failed' T1"
}

**# T2: iivw_weight.sthlp must not promise it either

* Same retraction on the documentation axis. The help file is what a user
* consults when auditing a weight vector, and through 3.0.0 it said the row
* "keeps the conventional baseline weight of exactly 1".
local ++test_count
capture noisily {
    local v310_sthlp "`pkg_dir'/iivw_weight.sthlp"

    _iivw_v310_count_phrase, file("`v310_sthlp'") ///
        phrase("keeps the conventional baseline weight of exactly 1")
    assert r(n) == 0
    _iivw_v310_count_phrase, file("`v310_sthlp'") ///
        phrase("conventional baseline weight")
    assert r(n) == 0

    * The replacement must state the fitted-weight rule and must still reserve
    * the 1 for rows that were never modeled as monitoring events.
    _iivw_v310_count_phrase, file("`v310_sthlp'") ///
        phrase("still receives a fitted weight")
    assert r(n) == 1
    _iivw_v310_count_phrase, file("`v310_sthlp'") ///
        phrase("never modeled as monitoring")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: T2 - sthlp does not promise weight 1 at time 0"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - sthlp time-0 contract (error `=_rc')"
    local ++fail_count
    local failed "`failed' T2"
}

**# T3: trunctreat() cutpoints are invariant to visit count

* The IPT weight is estimated once per subject and merged m:1, so it is
* subject-constant. Through 3.0.0 the cutpoints were ROW percentiles, so the
* trim was a function of visit density rather than of the weights: with subject
* 1 holding 200 of 278 rows the row-level p95 landed inside its own block and
* the clip left it untouched (realized upper cut 16.2837 == its own weight),
* while at 2 visits the identical weight was cut to 1.8548.
*
* This is the load-bearing case. It compares TWO RUNS whose weights are equal
* by construction, so any difference in the cutpoint is attributable to visit
* count alone -- there is no tolerance question and no oracle to get wrong.
local ++test_count
capture noisily {
    foreach nvis in 200 2 {
        _iivw_v310_trim_panel, nvis(`nvis')
        quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) ///
            wtype(iptw) trunctreat(1 95) nolog
        * Read r() BEFORE any other r-class command runs, or -summarize- below
        * silently replaces the whole return set.
        local v310_hi_`nvis'  = r(trunc_treat_hi)
        local v310_lo_`nvis'  = r(trunc_treat_lo)
        local v310_nid_`nvis' = r(n_trunc_treat_id)

        assert !missing(`v310_hi_`nvis'')
        assert !missing(`v310_lo_`nvis'')

        * subject 1's raw weight, and whether the trim actually moved it
        quietly summarize _iivw_tw_raw if id == 1, meanonly
        local v310_raw_`nvis' = r(mean)
        quietly summarize _iivw_tw if id == 1, meanonly
        local v310_trim_`nvis' = r(mean)
    }

    * The raw weight is identical across the two runs -- the premise of the test
    assert !missing(`v310_raw_200', `v310_raw_2')
    assert reldif(`v310_raw_200', `v310_raw_2') < 1e-10

    * The cutpoints must now be identical too. On 3.0.0 they differed ~8.8-fold.
    assert !missing(`v310_hi_200', `v310_hi_2')
    assert reldif(`v310_hi_200', `v310_hi_2') < 1e-10
    assert !missing(`v310_lo_200', `v310_lo_2')
    assert reldif(`v310_lo_200', `v310_lo_2') < 1e-10

    * And the extreme subject must actually be bounded in BOTH runs. This is the
    * assertion that pins the direction of the old failure: the many-visit run
    * is the one where the trim used to do nothing.
    assert `v310_trim_200' < `v310_raw_200'
    assert `v310_trim_2'   < `v310_raw_2'
    assert !missing(`v310_trim_200', `v310_trim_2')
    assert reldif(`v310_trim_200', `v310_trim_2') < 1e-10

    * Same subjects bounded either way; only the ROW count may differ.
    assert `v310_nid_200' == `v310_nid_2'
}
if _rc == 0 {
    display as result "  PASS: T3 - trunctreat cutpoints invariant to visit count"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - trunctreat visit-count invariance (error `=_rc')"
    local ++fail_count
    local failed "`failed' T3"
}

**# T4: trunctreat() reports the subject unit and the subject count

* r(n_trunc_treat) keeps its old meaning (panel rows). The new returns say what
* unit the cutpoints were taken at and how many subjects were bounded -- which
* is the quantity the sensitivity analysis is about and which a row count
* cannot recover on an unbalanced panel.
local ++test_count
capture noisily {
    _iivw_v310_trim_panel, nvis(200)
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) ///
        wtype(iptw) trunctreat(1 95) nolog
    local v310_nrow = r(n_trunc_treat)
    local v310_nid  = r(n_trunc_treat_id)
    local v310_unit = "`r(trunc_treat_unit)'"

    * Presence first: a nonexistent r() reads back as "." and `. == 0' is FALSE
    * but `. > 2' is TRUE, so a value test alone can pass on a missing return.
    assert !missing(`v310_nid')
    assert "`v310_unit'" == "subject"

    * Subject 1 is bounded, so at least one subject is trimmed, and every one
    * of its 200 rows carries the clipped weight -- hence rows >= subjects and
    * strictly greater here.
    assert `v310_nid' >= 1
    assert `v310_nrow' > `v310_nid'

    * The subject count must agree with a count taken directly off the data.
    tempvar v310_tag
    quietly egen byte `v310_tag' = tag(id) if !missing(_iivw_tw)
    quietly count if `v310_tag' == 1 & abs(_iivw_tw - _iivw_tw_raw) > 1e-12
    assert r(N) == `v310_nid'

    * truncvisit() is deliberately NOT converted: the IIW weight varies within
    * a subject, so the row is the right unit there and no unit macro is set.
    _iivw_v310_t0_panel
    quietly iivw_weight, id(id) time(t) visit_cov(z) wtype(iivw) ///
        maxfu(12) truncvisit(1 95) nolog
    assert "`r(trunc_treat_unit)'" == ""
    assert !missing(r(n_trunc_visit))
}
if _rc == 0 {
    display as result "  PASS: T4 - trunctreat reports the subject unit and count"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - trunctreat unit reporting (error `=_rc')"
    local ++fail_count
    local failed "`failed' T4"
}

**# T5: r(refit_n_target_unusable) exists and gates the verdict

* iivw_balance counted at-risk intervals with no usable baseline-hazard
* increment and then discarded the count. Such an interval leaves the TARGET
* side of the target SMD (every target sum is guarded on a nonmissing
* person-time increment) while the matching visit row stays on the WEIGHTED
* side, which requires only a weight and a covariate -- so the two halves would
* be measured over different interval sets and the gap read as imbalance.
*
* The count measured 0 on every fixture probed, so this pins the CONTRACT (the
* return exists, is 0 on clean data, and the verdict is issued) rather than a
* firing gate. That limit is stated in the residual risks, not hidden.
local ++test_count
capture noisily {
    _iivw_v310_t0_panel
    * A second visit covariate missing for one subject in seven, so some rows
    * fall outside the Cox sample -- the shape that used to duplicate rows.
    gen double z2 = rnormal()
    quietly replace z2 = . if mod(id, 7) == 0
    quietly iivw_weight, id(id) time(t) visit_cov(z z2) wtype(iivw) ///
        maxfu(12) nolog allowmissingweights
    quietly iivw_balance, component(final)

    local v310_unusable = r(refit_n_target_unusable)
    local v310_status   = "`r(target_status)'"
    local v310_flag     = "`r(balance_flag)'"
    local v310_tsmd     = r(balance_max_tsmd)

    * Presence, then value. On 3.0.0 this return did not exist at all.
    assert !missing(`v310_unusable')
    assert `v310_unusable' == 0

    * With nothing unusable the verdict must still be issued -- a gate that
    * withholds on clean data would be worse than the discarded count.
    assert "`v310_status'" != "target_incomplete"
    assert "`v310_flag'" != "not_assessed" | "`v310_status'" == "tie_method_efron"
    assert !missing(`v310_tsmd')

    * The status/flag pair must stay inside the documented value sets, which
    * iivw_balance.sthlp now enumerates in full.
    assert inlist("`v310_status'", "identified", "not_identified", ///
        "tie_method_efron", "target_incomplete", "unavailable")
    assert inlist("`v310_flag'", "within_rule", "exceeds_rule", ///
        "not_identified", "not_assessed", "unknown")
}
if _rc == 0 {
    display as result "  PASS: T5 - refit_n_target_unusable returned and gating"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - target-unusable gate (error `=_rc')"
    local ++fail_count
    local failed "`failed' T5"
}

**# T6: the baseline-hazard lookup keeps its row-count invariant

* iivw_balance expands every row to create a scratch copy carrying the fitted
* step function, then drops the copies. Through 3.0.0 the "is a copy" flag and
* the "can serve as a knot" flag were the SAME variable: a copy with no fitted
* hazard had the flag reset to 0, which also exempted it from the drop, so it
* survived. Measured on the T5 fixture: 944 rows where 825 were stored.
*
* AXIS NOTE. This defect has no external symptom in 3.1.0, because every
* consumer downstream of the lookup filters on the Cox-sample marker and the
* duplicated rows fail it -- verified by running the fixture on both versions
* and getting bit-identical returns (max target SMD 0.0330504244, max shift
* 0.1668150340, ESS 696.160754). So there is no behavioural assertion available
* and this pins the SOURCE STRUCTURE instead: the drop must key on a flag that
* is never reset. That is a weaker axis, and it is the honest one -- the point
* is to stop the two flags being merged again, which is what reintroduces it.
local ++test_count
capture noisily {
    local v310_bal "`pkg_dir'/iivw_balance.ado"

    * @BT@/@AP@ are the helper's stand-ins for a backtick and an apostrophe;
    * see the note on the helper for why they cannot be written literally.

    * The drop must key on the copy flag, never on the knot flag: keying on the
    * knot flag is precisely the 3.0.0 defect, because the knot flag gets reset.
    _iivw_v310_count_phrase, file("`v310_bal'") ///
        phrase("drop if @BT@__iivw_isdup@AP@")
    assert r(n) == 1
    _iivw_v310_count_phrase, file("`v310_bal'") ///
        phrase("drop if @BT@__iivw_isknot@AP@")
    assert r(n) == 0

    * The copy is created as the copy flag, and the knot flag is a SEPARATE
    * fresh byte -- not the expand's own flag later reset in place.
    _iivw_v310_count_phrase, file("`v310_bal'") ///
        phrase("expand 2, gen(@BT@__iivw_isdup@AP@)")
    assert r(n) == 1
    _iivw_v310_count_phrase, file("`v310_bal'") ///
        phrase("expand 2, gen(@BT@__iivw_isknot@AP@)")
    assert r(n) == 0
    _iivw_v310_count_phrase, file("`v310_bal'") ///
        phrase("gen byte @BT@__iivw_isknot@AP@")
    assert r(n) == 1

    * Both tempvar names must actually be declared, so a rename cannot make the
    * four assertions above vacuously true by removing the strings entirely.
    _iivw_v310_count_phrase, file("`v310_bal'") phrase("__iivw_isdup")
    assert r(n) == 6
    _iivw_v310_count_phrase, file("`v310_bal'") phrase("__iivw_isknot")
    assert r(n) == 5

    * Belt and braces on the live path: the fixture that used to duplicate 119
    * rows must still produce a usable verdict and a verified replay.
    _iivw_v310_t0_panel
    gen double z2 = rnormal()
    quietly replace z2 = . if mod(id, 7) == 0
    quietly iivw_weight, id(id) time(t) visit_cov(z z2) wtype(iivw) ///
        maxfu(12) nolog allowmissingweights
    quietly iivw_balance, component(final)
    local v310_reldif = r(replay_max_reldif)
    local v310_rn     = r(replay_n)
    assert !missing(`v310_reldif')
    assert `v310_reldif' < 1e-8
    assert `v310_rn' > 0
}
if _rc == 0 {
    display as result "  PASS: T6 - balance row-count invariant pinned"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - balance row-count invariant (error `=_rc')"
    local ++fail_count
    local failed "`failed' T6"
}

**# T7: a pre-3.1.0 trunctreat contract cannot be replayed by refitweights

* A refit bootstrap rebuilds the trim per draw from the stored PERCENTILES, so
* the unit in force at replay time must be the unit the observed weights were
* built with. A contract from 3.0.0 or earlier carries a row-level `_iivw_tw'
* column; every draw here would be rebuilt at subject level, so the draws and
* the point estimate would describe different estimators and the reported SE
* would belong to neither -- at rc 0, and invisible to every existing check
* (iivw_balance's replay verification covers the IIW component only).
*
* Reproducing a pre-3.1.0 analysis is deliberately unsupported, so the contract
* records the resolved unit and the replay REFUSES rather than silently mixing.
local ++test_count
capture noisily {
    _iivw_v310_trim_panel, nvis(4)
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) ///
        wtype(fiptiw) visit_cov(x) maxfu(6) trunctreat(1 95) nolog ///
        allowmissingweights

    * The fresh contract records the unit, and a refit replay is accepted.
    local v310_char : char _dta[_iivw_tt_unit]
    assert "`v310_char'" == "subject"

    * Now age the contract to a pre-3.1.0 one: drop the unit and RE-SIGN, so the
    * stale-contract signature guard cannot be what fires. Without the re-sign
    * this test would pass for the wrong reason -- `_iivw_tt_unit' is part of the
    * weight signature precisely so a hand-edited contract is detectable.
    char _dta[_iivw_tt_unit] ""
    iivw_qa_sign_contract

    capture iivw_fit y a, vce(bootstrap, reps(4)) refitweights nolog
    assert _rc == 198

    * And the refusal must be specific to the refit path: a fixed-weight fit
    * consumes the stored column as-is, recomputes no trim, and must still run.
    capture iivw_fit y a, vce(fixed) nolog
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: T7 - stale trunctreat unit refuses a refit replay"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - stale trunctreat unit replay guard (error `=_rc')"
    local ++fail_count
    local failed "`failed' T7"
}

**# T8: the trimming-unit rule holds in BOTH directions

* T3 pins only half the rule -- that trunctreat() is visit-count invariant. On
* its own that makes the WRONG generalization free: a later "make every trim
* subject-level" change would pass the whole suite. The rule is
*
*   the percentile is taken over the distribution of the estimated weight, at
*   the unit where that weight is estimated and VARIES
*
* which is what the trimming literature does on both sides (Lee, Lessler &
* Stuart 2011 and Crump et al. 2009 trim a per-subject weight over subjects;
* Cole & Hernan 2008 trim a time-varying MSM weight over person-time records).
* The IIW weight is exp(-gamma'Z(t)) and varies row to row within a subject, so
* the row is its correct unit. Assert that it still IS row-level, by showing its
* realized cutpoint responds to the row distribution.
local ++test_count
capture noisily {
    * Two panels with the same subjects but different visit densities. The IIW
    * weight varies within subject, so a row percentile SHOULD move here --
    * that is the property being protected, not a defect.
    foreach keep in 1 2 {
        _iivw_v310_t0_panel
        if `keep' == 2 {
            * Halve the rows for half the subjects, changing the row-level
            * distribution while leaving the visit MODEL untouched. The sequence
            * number is materialised first: `drop' is not byable, so a
            * `bysort ... : drop if ... _n ...' does not mean what it reads as.
            bysort id (t): gen long v310_seq = _n
            quietly drop if mod(id, 2) == 0 & mod(v310_seq, 2) == 0 & v310_seq > 1
            drop v310_seq
            bysort id: gen byte v310_nv = _N
            quietly drop if v310_nv < 2
            drop v310_nv
        }
        quietly iivw_weight, id(id) time(t) visit_cov(z) wtype(iivw) ///
            maxfu(12) truncvisit(1 95) nolog
        local v310_tv_hi_`keep' = r(trunc_visit_hi)
        local v310_tv_unit_`keep' = "`r(trunc_visit_unit)'"
        assert !missing(`v310_tv_hi_`keep'')
    }

    * truncvisit() must NOT advertise a subject unit -- it has none.
    assert "`v310_tv_unit_1'" == ""
    assert "`v310_tv_unit_2'" == ""

    * The visit-trim cutpoint is a row statistic, so thinning the panel moves it.
    * If a future change converted truncvisit() to subject-level percentiles this
    * assertion is what would catch it.
    assert !missing(`v310_tv_hi_1', `v310_tv_hi_2')
    assert reldif(`v310_tv_hi_1', `v310_tv_hi_2') > 1e-6

    * The complement, restated on the treat side so the pair reads as one rule:
    * trunctreat() carries the subject unit and truncvisit() does not.
    _iivw_v310_trim_panel, nvis(4)
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(x) wtype(iptw) ///
        trunctreat(1 95) nolog
    assert "`r(trunc_treat_unit)'" == "subject"
}
if _rc == 0 {
    display as result "  PASS: T8 - trimming-unit rule pinned in both directions"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - trimming-unit rule both directions (error `=_rc')"
    local ++fail_count
    local failed "`failed' T8"
}

**# Summary

capture log close _all
iivw_qa_summary, name(test_iivw_v310_regressions) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
