* test_finegray_v120b.do
* Regression tests for the finegray 1.2.0 presentation pass.
*
* Every block below is written to FAIL on the pre-fix build.  "The pre-fix
* build" means the state before the 1.2.0 presentation pass, audited 2026-08-07.
*
*   V120B-1   e(b)/e(V) carry the fitted TERMS, not the _fg_* design columns.
*            Pre-fix, a fit on `i.grp i.pelnode' named its coefficients
*            _fg_grp_1 _fg_grp_2 _fg_pelnode_1, so the printed table abbreviated
*            an interaction to `_fg_pelnod~p' -- undecodable from the output --
*            and every estout-style export carried the same names.
*   V120B-2   `test' and `testparm' address factor terms directly.  Pre-fix,
*            `test 1.pelnode' died r(111) and the user had to discover
*            `test _fg_pelnode_1'.
*   V120B-3   e(covariates) still holds the internal design columns, so the
*            post-estimation rebuild contract is unchanged by V120B-1.
*   V120B-4   Replay: bare `finegray' redisplays.  Pre-fix it was r(100)
*            "varlist required"; refitting was the only way back to the table.
*   V120B-5   Replay honours level() and noshr, and does NOT change e(b).
*   V120B-6   Replay without a finegray fit in e() is r(301), not r(100).
*   V120B-7   e(depvar) is _t (as stcrreg), not the event-type variable.
*   V120B-8   e(compete_values) lists the values pooled as competing.
*   V120B-9   e(N_delayed) counts late-entering subjects; e(N_G_trunc) counts
*            the G(t) floor hits the Mata engine used to printf ABOVE the
*            command's own title.
*   V120B-10  finegray_cif prints the covariate profile above the table, in the
*            same vocabulary r(profile_vars) reports, for at() and for the
*            default estimation-sample means alike.
*   V120B-11  finegray_cif notes attime() values outside the estimated support.
*   V120B-12  The saving() dataset is labelled and carries the profile as a note.
*   V120B-13  The display-only graph tail does not reach r(table) or saving().
*   V120B-14  finegray_predict, cif labels the evaluation basis (_t vs timevar).
*   V120B-15  The factor-name help contract agrees with the fitted coefficient
*            stripe: user-facing terms in e(b)/e(V), internal columns only in
*            e(covariates).
*   V120B-16  The rendered CIF help has no doubled spaces at the two sentence
*            boundaries split across source lines.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v120b.log", replace name(_t120b)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_120b
program define _mk_120b
    version 16.0
    clear
    set seed 20260807
    quietly set obs 900
    gen long id = _n
    gen double x1 = rnormal()
    gen byte grp = 1 + int(runiform() * 3)
    gen byte pelnode = rbinomial(1, 0.4)
    gen double lat  = ceil(runiform() * 10)
    gen double lat2 = ceil(runiform() * 10)
    gen double cen  = ceil(runiform() * 13)
    gen byte ev = cond(lat <= lat2, 1, 2)
    gen double t = min(lat, lat2)
    quietly replace ev = 0 if cen < t
    quietly replace t = min(t, cen)
    quietly stset t, failure(ev == 1 2) id(id)
    drop lat lat2 cen
end

* Delayed-entry variant: a third of subjects enter after time 0.
capture program drop _mk_120b_lt
program define _mk_120b_lt
    version 16.0
    _mk_120b
    gen double ent = cond(mod(_n, 3) == 0, t / 4, 0)
    quietly stset t, failure(ev == 1 2) id(id) enter(time ent)
end

**# 1. e(b)/e(V) carry the fitted terms, not the design columns [FAILS PRE-FIX]
local ++test_count
capture noisily {
    _mk_120b
    finegray i.grp i.pelnode x1, compete(ev) cause(1) nolog
    local cn : colnames e(b)
    * Stata normalises a stripe with no base level to `Nbn.', so compare on the
    * VARIABLE part rather than on the exact level marker.
    assert strpos("`cn'", "_fg_") == 0
    assert strpos("`cn'", "grp") > 0
    assert strpos("`cn'", "pelnode") > 0
    local rn : rownames e(V)
    assert strpos("`rn'", "_fg_") == 0
    * An interaction term must be nameable too.
    finegray i.pelnode##c.x1, compete(ev) cause(1) nolog
    local cn2 : colnames e(b)
    assert strpos("`cn2'", "_fg_") == 0
    assert strpos("`cn2'", "#") > 0
}
if _rc == 0 {
    display as result "  PASS: V120B-1 e(b)/e(V) named with the fitted terms"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-1 coefficient names (rc=`=_rc')"
    local ++fail_count
}

**# 2. test/testparm address the factor terms directly [FAILS PRE-FIX]
local ++test_count
capture noisily {
    _mk_120b
    finegray i.grp i.pelnode x1, compete(ev) cause(1) nolog
    quietly test 1.pelnode
    assert r(df) == 1
    quietly testparm i.grp
    assert r(df) == 2
}
if _rc == 0 {
    display as result "  PASS: V120B-2 test/testparm accept the typed fv terms"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-2 test on fv terms (rc=`=_rc')"
    local ++fail_count
}

**# 3. e(covariates) is UNCHANGED -- the rebuild contract still uses _fg_*
* V120B-1 must move the display vocabulary only.  finegray_cif/predict/phtest all
* read e(covariates) by name; renaming it as well would break every consumer.
local ++test_count
capture noisily {
    _mk_120b
    finegray i.grp i.pelnode x1, compete(ev) cause(1) nolog
    assert "`e(covariates)'" == "_fg_grp_2 _fg_grp_3 _fg_pelnode_1 x1"
    * ...and post-estimation still runs on it after the design columns are gone.
    drop _fg_*
    quietly finegray_cif, attime(3)
    matrix _c3 = r(table)
    assert _c3[1,2] > 0 & _c3[1,2] < 1
}
if _rc == 0 {
    display as result "  PASS: V120B-3 e(covariates) unchanged; rebuild path intact"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-3 e(covariates)/rebuild (rc=`=_rc')"
    local ++fail_count
}

**# 4. Bare `finegray' replays instead of erroring [FAILS PRE-FIX: r(100)]
local ++test_count
capture noisily {
    _mk_120b
    finegray x1 pelnode, compete(ev) cause(1) nolog
    matrix _b_fit = e(b)
    capture noisily finegray
    assert _rc == 0
    * Replay must not disturb the estimation results it is redisplaying.
    matrix _b_rep = e(b)
    assert mreldif(_b_fit, _b_rep) == 0
    assert "`e(cmd)'" == "finegray"
}
if _rc == 0 {
    display as result "  PASS: V120B-4 bare finegray replays"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-4 replay (rc=`=_rc')"
    local ++fail_count
}

**# 5. Replay honours level() and noshr without refitting [FAILS PRE-FIX]
local ++test_count
capture noisily {
    _mk_120b
    finegray x1 pelnode, compete(ev) cause(1) nolog
    matrix _b5 = e(b)
    local ll5 = e(ll)
    capture noisily finegray, level(90) noshr
    assert _rc == 0
    assert mreldif(_b5, e(b)) == 0
    assert e(ll) == `ll5'
    capture noisily finegray, level(80)
    assert _rc == 0
    * An out-of-range level is refused rather than silently clamped.
    capture finegray, level(150)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V120B-5 replay options honoured, e() untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-5 replay options (rc=`=_rc')"
    local ++fail_count
}

**# 6. Replay with no finegray fit in e() is r(301) [FAILS PRE-FIX: r(100)]
local ++test_count
capture noisily {
    _mk_120b
    quietly stcox x1
    capture finegray
    assert _rc == 301
    ereturn clear
    capture finegray
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: V120B-6 replay without finegray results is r(301)"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-6 replay guard (rc=`=_rc')"
    local ++fail_count
}

**# 7. e(depvar) is _t, as after stcrreg [FAILS PRE-FIX: "ev"]
local ++test_count
capture noisily {
    _mk_120b
    finegray x1 pelnode, compete(ev) cause(1) nolog
    assert "`e(depvar)'" == "_t"
    assert "`e(compete)'" == "ev"
}
if _rc == 0 {
    display as result "  PASS: V120B-7 e(depvar) == _t"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-7 e(depvar) (rc=`=_rc')"
    local ++fail_count
}

**# 8. e(compete_values) lists what was pooled as competing [FAILS PRE-FIX: unset]
* A miscoded event code is invisible when the header names only the variable.
local ++test_count
capture noisily {
    _mk_120b
    * Introduce a third, distinct competing code: it must be reported.
    quietly replace ev = 9 if ev == 2 & mod(_n, 5) == 0
    quietly stset t, failure(ev == 1 2 9) id(id)
    finegray x1 pelnode, compete(ev) cause(1) nolog
    local cv "`e(compete_values)'"
    assert strpos(" `cv' ", " 2 ") > 0
    assert strpos(" `cv' ", " 9 ") > 0
    assert strpos(" `cv' ", " 1 ") == 0
    assert strpos(" `cv' ", " 0 ") == 0
}
if _rc == 0 {
    display as result "  PASS: V120B-8 e(compete_values) names the pooled codes"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-8 e(compete_values) (rc=`=_rc')"
    local ++fail_count
}

**# 9. e(N_delayed) and e(N_G_trunc) exist and are honest [FAILS PRE-FIX: unset]
local ++test_count
capture noisily {
    _mk_120b
    finegray x1 pelnode, compete(ev) cause(1) nolog
    assert e(N_delayed) == 0
    assert e(N_G_trunc) < .
    assert !missing(e(N_G_trunc))
    assert e(N_G_trunc) >= 0

    _mk_120b_lt
    quietly count if ent > 0
    local n_ent = r(N)
    assert `n_ent' > 0
    finegray x1 pelnode, compete(ev) cause(1) nolog
    assert e(N_delayed) == `n_ent'
    assert "`e(lt_weight)'" != "right_censoring"
}
if _rc == 0 {
    display as result "  PASS: V120B-9 e(N_delayed)/e(N_G_trunc) posted"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-9 delayed-entry/G-floor counts (rc=`=_rc')"
    local ++fail_count
}

**# 10. finegray_cif prints the profile above the table [FAILS PRE-FIX]
* Read back from a NAMED log: the `at:' line is display, not a return, so the
* rendered output is the only place the contract can be checked.
local ++test_count
capture noisily {
    _mk_120b
    finegray x1 pelnode, compete(ev) cause(1) nolog
    tempfile atbase
    local atlog `"`atbase'.log"'
    quietly log using `"`atlog'"', replace text name(_v120bat)
    finegray_cif, at(x1=1 pelnode=1) attime(3)
    finegray_cif, attime(3)
    quietly log close _v120bat

    tempname fh
    local seen_at = 0
    local seen_mean = 0
    file open `fh' using `"`atlog'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "at: x1=1 pelnode=1") > 0 local seen_at = 1
        if strpos(`"`line'"', "at (estimation-sample means):") > 0 ///
            local seen_mean = 1
        file read `fh' line
    }
    file close `fh'
    assert `seen_at' == 1
    assert `seen_mean' == 1
}
if _rc == 0 {
    display as result "  PASS: V120B-10 finegray_cif prints the at: profile line"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-10 at: line (rc=`=_rc')"
    local ++fail_count
}

**# 11. Out-of-support attime() values are flagged [FAILS PRE-FIX: silent]
local ++test_count
capture noisily {
    _mk_120b
    finegray x1 pelnode, compete(ev) cause(1) nolog
    quietly summarize _t if e(sample) & ev == 1, meanonly
    local tlast = r(max)
    local tbig = `tlast' * 100

    tempfile rngbase
    local rnglog `"`rngbase'.log"'
    quietly log using `"`rnglog'"', replace text name(_v120brng)
    finegray_cif, attime(0 `tbig')
    quietly log close _v120brng

    tempname fh2
    local seen_after = 0
    local seen_before = 0
    file open `fh2' using `"`rnglog'"', read text
    file read `fh2' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "exceed the last cause-event time") > 0 ///
            local seen_after = 1
        if strpos(`"`line'"', "precede the first cause-event time") > 0 ///
            local seen_before = 1
        file read `fh2' line
    }
    file close `fh2'
    assert `seen_after' == 1
    assert `seen_before' == 1

    * A grid entirely inside the support must stay silent.
    tempfile okbase
    local oklog `"`okbase'.log"'
    quietly log using `"`oklog'"', replace text name(_v120bok)
    finegray_cif, attime(`=`tlast'/2')
    quietly log close _v120bok
    tempname fh3
    local seen_any = 0
    file open `fh3' using `"`oklog'"', read text
    file read `fh3' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "cause-event time") > 0 local seen_any = 1
        file read `fh3' line
    }
    file close `fh3'
    assert `seen_any' == 0
}
if _rc == 0 {
    display as result "  PASS: V120B-11 out-of-support attime() values noted"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-11 support notes (rc=`=_rc')"
    local ++fail_count
}

**# 12. saving() writes a labelled, self-describing dataset [FAILS PRE-FIX]
local ++test_count
capture noisily {
    _mk_120b
    finegray x1 pelnode, compete(ev) cause(1) nolog
    tempfile cifout
    quietly finegray_cif, ci nograph saving(`"`cifout'"', replace)

    * No assert between preserve and restore: a failing assertion there aborts
    * the block with the preserve still live, and the NEXT test then dies
    * r(621) "already preserved" -- a real failure reported at the wrong test.
    preserve
    quietly use `"`cifout'"', clear
    local nlab = 0
    foreach v in time cif se lci uci {
        local lb : variable label `v'
        if `"`lb'"' != "" local ++nlab
    }
    local dl : data label
    local nt1 `"`_dta[note1]'"'
    restore

    assert `nlab' == 5
    assert strpos(`"`dl'"', "finegray_cif") > 0
    * The profile rides in a dataset note, which has no 80-character cap.
    assert `"`nt1'"' != ""
    assert strpos(`"`nt1'"', "x1=") > 0
}
if _rc == 0 {
    display as result "  PASS: V120B-12 saving() dataset is labelled and noted"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-12 saving() labels (rc=`=_rc')"
    local ++fail_count
}

**# 13. The graph's flat tail is DISPLAY-ONLY
* The curve is drawn out to the last observed analysis time, but r(table) and
* the exported estimates must still stop at the last cause-event time -- the
* same contract the (0,0) origin row has always had.
local ++test_count
capture noisily {
    _mk_120b
    finegray x1 pelnode, compete(ev) cause(1) nolog
    quietly summarize _t if e(sample) & ev == 1, meanonly
    local tlastev = r(max)
    quietly summarize _t if e(sample), meanonly
    local tlastfu = r(max)
    assert `tlastfu' >= `tlastev'

    tempfile cifout2
    quietly finegray_cif, ci saving(`"`cifout2'"', replace) nodraw
    matrix _t13 = r(table)
    local nr = rowsof(_t13)
    assert !missing(_t13[`nr', 1], `tlastev')
    assert reldif(_t13[`nr', 1], `tlastev') < 1e-8

    preserve
    quietly use `"`cifout2'"', clear
    quietly summarize time, meanonly
    local sav_tmax = r(max)
    local sav_tmin = r(min)
    restore

    assert !missing(`sav_tmax', `tlastev')
    assert reldif(`sav_tmax', `tlastev') < 1e-8
    assert `sav_tmin' > 0
}
if _rc == 0 {
    display as result "  PASS: V120B-13 graph tail absent from r(table)/saving()"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-13 graph tail leaked into estimates (rc=`=_rc')"
    local ++fail_count
}

**# 14. finegray_predict, cif records its evaluation basis in the label
local ++test_count
capture noisily {
    _mk_120b
    finegray x1 pelnode, compete(ev) cause(1) nolog
    quietly finegray_predict double cifA, cif
    local lA : variable label cifA
    assert strpos(`"`lA'"', "_t") > 0
    assert strpos(`"`lA'"', "cause 1") > 0

    gen double h5 = 5
    quietly finegray_predict double cifB, cif timevar(h5)
    local lB : variable label cifB
    assert strpos(`"`lB'"', "h5") > 0
    * The two must be distinguishable in `describe' -- the whole point.
    assert `"`lA'"' != `"`lB'"'
}
if _rc == 0 {
    display as result "  PASS: V120B-14 cif label names the evaluation basis"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-14 cif prediction label (rc=`=_rc')"
    local ++fail_count
}

**# 15. The factor-name help contract matches the fitted coefficient stripe
local ++test_count
capture noisily {
    tempname fh4
    local stale_names = 0
    local user_names = 0
    file open `fh4' using "`pkg_dir'/finegray.sthlp", read text
    file read `fh4' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "label a factor term by its design column") > 0 ///
            local stale_names = 1
        if strpos(`"`line'"', "the factor-variable terms you typed") > 0 ///
            local user_names = 1
        file read `fh4' line
    }
    file close `fh4'
    assert `stale_names' == 0
    assert `user_names' == 1
}
if _rc == 0 {
    display as result "  PASS: V120B-15 factor-name help matches e(b)/e(V)"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-15 factor-name help contract (rc=`=_rc')"
    local ++fail_count
}

**# 16. The Viewer-visible CIF help has no doubled punctuation spaces
local ++test_count
capture noisily {
    tempfile cifhelp
    quietly translate "`pkg_dir'/finegray_cif.sthlp" `"`cifhelp'"', ///
        translator(smcl2txt) replace

    tempname fh5
    local doubled_one = 0
    local doubled_tail = 0
    file open `fh5' using `"`cifhelp'"', read text
    file read `fh5' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "one.  The") > 0 local doubled_one = 1
        if strpos(`"`line'"', "display-only:  it") > 0 local doubled_tail = 1
        file read `fh5' line
    }
    file close `fh5'
    assert `doubled_one' + `doubled_tail' == 0
}
if _rc == 0 {
    display as result "  PASS: V120B-16 rendered CIF help sentence spacing"
    local ++pass_count
}
else {
    display as error "  FAIL: V120B-16 rendered CIF help spacing (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_v120b tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _t120b
    exit 1
}
display as result "ALL TESTS PASSED"
log close _t120b
