*! validation_fixture_truth.do -- canonical known-answer functional/hostile adoption
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set varabbrev off
set more off
set graphics off
capture log close _all
log using "validation_fixture_truth.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a2.do"
quietly do "_qa_hostile.do"
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    local op ""
    * Friendly known-answer control
    qa_fx_a2_lifetable, clear tier(micro)
    quietly count if d
    scalar events=r(N)
    quietly count if !d
    scalar censored=r(N)
    generate double duration=t-t0
    quietly summarize duration, detail
    scalar dmin=r(min)
    scalar dmax=r(max)
    scalar dmedian=r(p50)
    quietly stset t, failure(d) enter(time t0) id(id)
    quietly swimlane, id(id) censor nograph frame(fxlanes,replace)
    qa_assert_equal r(N_subjects) 24, property("all distinct subjects")
    qa_assert_equal r(N_segments) 24, property("one span per subject")
    qa_assert_equal r(N_events) events, property("actual event markers")
    qa_assert_equal r(N_ongoing) censored, property("actual censor ongoing subjects")
    qa_assert_equal r(min_duration) dmin, property("actual minimum exposure span")
    qa_assert_equal r(max_duration) dmax, property("actual maximum exposure span")
    qa_assert_equal r(median_duration) dmedian, property("actual median exposure span")
    frame fxlanes: quietly count if rowtype=="bar"
    assert r(N)==24
    forvalues i=1/24 {
        quietly summarize t0 if id==`i', meanonly
        scalar entry=r(mean)
        quietly summarize t if id==`i', meanonly
        scalar exit=r(mean)
        frame fxlanes: quietly count if id==`i' & rowtype=="bar"
        assert r(N)==1
        frame fxlanes: assert start==scalar(entry) & stop==scalar(exit) & duration==scalar(exit)-scalar(entry) if id==`i' & rowtype=="bar"
    }
    frame drop fxlanes
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    local op "unsorted"
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    assert !missing(r(perturb_n_unsorted)) & r(perturb_n_unsorted)>0
    quietly count if d
    scalar events=r(N)
    quietly count if !d
    scalar censored=r(N)
    generate double duration=t-t0
    quietly summarize duration, detail
    scalar dmin=r(min)
    scalar dmax=r(max)
    scalar dmedian=r(p50)
    quietly stset t, failure(d) enter(time t0) id(id)
    quietly swimlane, id(id) censor nograph frame(fxlanes,replace)
    qa_assert_equal r(N_subjects) 24, property("all distinct subjects")
    qa_assert_equal r(N_segments) 24, property("one span per subject")
    qa_assert_equal r(N_events) events, property("actual event markers")
    qa_assert_equal r(N_ongoing) censored, property("actual censor ongoing subjects")
    qa_assert_equal r(min_duration) dmin, property("actual minimum exposure span")
    qa_assert_equal r(max_duration) dmax, property("actual maximum exposure span")
    qa_assert_equal r(median_duration) dmedian, property("actual median exposure span")
    frame fxlanes: quietly count if rowtype=="bar"
    assert r(N)==24
    forvalues i=1/24 {
        quietly summarize t0 if id==`i', meanonly
        scalar entry=r(mean)
        quietly summarize t if id==`i', meanonly
        scalar exit=r(mean)
        frame fxlanes: quietly count if id==`i' & rowtype=="bar"
        assert r(N)==1
        frame fxlanes: assert start==scalar(entry) & stop==scalar(exit) & duration==scalar(exit)-scalar(entry) if id==`i' & rowtype=="bar"
    }
    frame drop fxlanes
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    local op "late_entry"
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(late_entry)
    assert !missing(r(perturb_n_late_entry)) & r(perturb_n_late_entry)>0
    quietly count if d
    scalar events=r(N)
    quietly count if !d
    scalar censored=r(N)
    generate double duration=t-t0
    quietly summarize duration, detail
    scalar dmin=r(min)
    scalar dmax=r(max)
    scalar dmedian=r(p50)
    quietly stset t, failure(d) enter(time t0) id(id)
    quietly swimlane, id(id) censor nograph frame(fxlanes,replace)
    qa_assert_equal r(N_subjects) 24, property("all distinct subjects")
    qa_assert_equal r(N_segments) 24, property("one span per subject")
    qa_assert_equal r(N_events) events, property("actual event markers")
    qa_assert_equal r(N_ongoing) censored, property("actual censor ongoing subjects")
    qa_assert_equal r(min_duration) dmin, property("actual minimum exposure span")
    qa_assert_equal r(max_duration) dmax, property("actual maximum exposure span")
    qa_assert_equal r(median_duration) dmedian, property("actual median exposure span")
    frame fxlanes: quietly count if rowtype=="bar"
    assert r(N)==24
    forvalues i=1/24 {
        quietly summarize t0 if id==`i', meanonly
        scalar entry=r(mean)
        quietly summarize t if id==`i', meanonly
        scalar exit=r(mean)
        frame fxlanes: quietly count if id==`i' & rowtype=="bar"
        assert r(N)==1
        frame fxlanes: assert start==scalar(entry) & stop==scalar(exit) & duration==scalar(exit)-scalar(entry) if id==`i' & rowtype=="bar"
    }
    frame drop fxlanes
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    local op "ties"
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(ties)
    assert !missing(r(perturb_n_ties)) & r(perturb_n_ties)>0
    quietly count if d
    scalar events=r(N)
    quietly count if !d
    scalar censored=r(N)
    generate double duration=t-t0
    quietly summarize duration, detail
    scalar dmin=r(min)
    scalar dmax=r(max)
    scalar dmedian=r(p50)
    quietly stset t, failure(d) enter(time t0) id(id)
    quietly swimlane, id(id) censor nograph frame(fxlanes,replace)
    qa_assert_equal r(N_subjects) 24, property("all distinct subjects")
    qa_assert_equal r(N_segments) 24, property("one span per subject")
    qa_assert_equal r(N_events) events, property("actual event markers")
    qa_assert_equal r(N_ongoing) censored, property("actual censor ongoing subjects")
    qa_assert_equal r(min_duration) dmin, property("actual minimum exposure span")
    qa_assert_equal r(max_duration) dmax, property("actual maximum exposure span")
    qa_assert_equal r(median_duration) dmedian, property("actual median exposure span")
    frame fxlanes: quietly count if rowtype=="bar"
    assert r(N)==24
    forvalues i=1/24 {
        quietly summarize t0 if id==`i', meanonly
        scalar entry=r(mean)
        quietly summarize t if id==`i', meanonly
        scalar exit=r(mean)
        frame fxlanes: quietly count if id==`i' & rowtype=="bar"
        assert r(N)==1
        frame fxlanes: assert start==scalar(entry) & stop==scalar(exit) & duration==scalar(exit)-scalar(entry) if id==`i' & rowtype=="bar"
    }
    frame drop fxlanes
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_truth tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
