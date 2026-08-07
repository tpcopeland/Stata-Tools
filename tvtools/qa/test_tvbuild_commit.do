*! test_tvbuild_commit.do
*! Phase 4C contract pins for tvbuild: events, provenance, and the transaction.
*!
*! Phase 4B ended at a finalised scratch result. This suite covers what turns
*! that into something the user can see: the optional event stage, the output
*! characteristics and data signature, the optional manifest, and the paired
*! commit that either produces both destinations or leaves the session exactly
*! as it found it.
*!
*! The false greens this suite is written against:
*!
*!   1. "The event stage produced numbers, but not tvevent's numbers." E2-E7
*!      compare against the composed primitive sequence, including the
*!      placement rules that are easiest to get subtly wrong: an event at the
*!      interval start, at the stop, before entry, after exit, and a competing
*!      risk on the earlier date.
*!
*!   2. "The rollback said it rolled back." T4-T7 do not take the command's
*!      word for it. They compare the pre-existing destination's data
*!      signature, its variable list, its storage types, its labels, and its
*!      characteristics before and after a failure -- and T6 forces the failure
*!      to land BETWEEN the two commits, which is the only window in which the
*!      output frame has already been written.
*!
*!   3. "Committed values were right while the session drifted." S1-S6 assert
*!      the caller's data, current frame, frame list, value-label namespace,
*!      active e(), sort order, and c(varabbrev) across success and failure.
*!
*! Axes probed:
*!   E1-E12c  the event stage against the frozen tvevent sequence
*!   P1-P6    manifest content, order, and the provenance characteristics
*!   T1-T8    destination ownership, replace, commit, and rollback
*!   S1-S6    session state after success and after failure

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvbuild_commit.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVC_PASS = 0
global TVC_FAIL = 0
global TVC_FAILED ""
local test_count = 0

display as result "tvtools QA: tvbuild events and commit (Phase 4C) -- $S_DATE $S_TIME"

capture program drop _tvc_check
program define _tvc_check
    args ok label detail
    if `ok' {
        global TVC_PASS = $TVC_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVC_FAIL = $TVC_FAIL + 1
        global TVC_FAILED "$TVC_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

capture program drop _tvc_framelist
program define _tvc_framelist, rclass
    version 16.0
    mata: st_local("_fl", invtokens(sort(st_framedir(), 1)'))
    return local frames "`_fl'"
end

* Every probe of a frame tvbuild was supposed to create is preceded by this.
* Entering `frame X { ... }' for a frame that does not exist ends the do-file,
* so one injected defect that stops the commit takes the whole suite down after
* naming at most one failure. Wrapping the block in `capture' does not help and
* makes it worse: `capture' swallows the frame-not-found error, the body then
* runs IN THE CALLER'S FRAME uncaptured -- computing an answer from the wrong
* dataset at rc=0 if it happens to be legal there -- and the closing brace is
* finally read as a command, r(199). See the same note in test_tvbuild_construct.do.
capture program drop _tvc_ready
program define _tvc_ready, rclass
    version 16.0
    syntax , FR(name) [VARS(string)]
    local _here "`c(frame)'"
    local _ok = 1
    capture confirm frame `fr'
    if _rc local _ok = 0
    if `_ok' & `"`vars'"' != "" {
        capture frame change `fr'
        if _rc {
            local _ok = 0
        }
        else {
            foreach v of local vars {
                capture confirm variable `v'
                if _rc local _ok = 0
            }
        }
    }
    capture frame change `_here'
    return scalar ok = `_ok'
end

* A destination fingerprint that goes past the values. datasignature sees data
* only; the storage types, formats, labels, and characteristics are exactly
* what a rollback could restore incorrectly without changing a single number.
capture program drop _tvc_fingerprint
program define _tvc_fingerprint, rclass
    version 16.0
    args fr
    local _here "`c(frame)'"
    frame change `fr'
    quietly datasignature
    local _sig "`r(datasignature)'"
    quietly ds
    local _vars "`r(varlist)'"
    local _meta ""
    foreach v of local _vars {
        local _t : type `v'
        local _f : format `v'
        local _l : variable label `v'
        local _vl : value label `v'
        local _meta `"`_meta'|`v':`_t':`_f':`_l':`_vl'"'
    }
    local _dl : data label
    local _pc : char _dta[tvtools_tvbuild]
    local _cc : char _dta[tvtools_tvbuild_coverage]
    frame change `_here'
    return local fingerprint `"`_sig'`_meta'|data:`_dl'|char:`_pc':`_cc'"'
end


* Compare a committed frame against a saved oracle. `capture' does not survive
* into a `frame X { ... }' block -- the block is executed line by line and an
* error inside it ends the do-file -- so the comparison lives in a program the
* caller can capture as one command. A missing frame returns 999 rather than
* stopping the suite, which is what lets an injected defect report as a
* labelled failure per axis instead of an abort at the first casualty.
capture program drop _tvc_compare
program define _tvc_compare, rclass
    version 16.0
    syntax , FRame(name) VARS(string) ORacle(string)
    local _here "`c(frame)'"
    capture confirm frame `frame'
    if _rc {
        return scalar rc = 999
        exit
    }
    capture frame drop tc_cmp
    frame copy `frame' tc_cmp
    frame change tc_cmp
    capture {
        keep `vars'
        order `vars'
        sort pid start stop
        cf _all using `"`oracle'"'
    }
    local _crc = _rc
    frame change `_here'
    capture frame drop tc_cmp
    return scalar rc = `_crc'
end

**# ---------------------------------------------------------------------
**# Fixtures
**# ---------------------------------------------------------------------
clear
input long pid double study_entry double study_exit byte sex
    1 100 500 1
    2 120 480 0
    3  90 500 1
    4 200 460 0
end
save "tc_cohort.dta", replace

clear
input long pid double a_start double a_stop byte drug
    1 150 199 1
    1 250 299 2
    2 130 200 1
    3 100 400 2
    4 210 300 1
end
save "tc_epi.dta", replace

* Event geometry, one person per case:
*   1 internal to an interval; 2 exactly at an interval start;
*   3 exactly at the study exit; 4 after the exit (never observed).
clear
input long pid double evdate double compdate
    1 175 .
    2 130 .
    3 500 .
    4 900 .
end
save "tc_ev.dta", replace

* Competing risk earlier than the primary for person 1; the same day for 2.
clear
input long pid double evdate double compdate
    1 300 175
    2 200 200
    3 .   .
    4 .   .
end
save "tc_evc.dta", replace

* Recurring wide stub.
clear
input long pid double ev1 double ev2
    1 150 300
    2 200 .
    3 .   .
    4 250 .
end
save "tc_evr.dta", replace

* A cohort that carries the event columns itself.
clear
input long pid double study_entry double study_exit double evdate
    1 100 500 175
    2 120 480 130
    3  90 500 500
    4 200 460 900
end
save "tc_cohort_ev.dta", replace

* A ready interval source with an interval total, for the split algebra.
clear
input long pid double start double stop byte st double dose
    1 100 500 1 401
    2 120 480 1 361
    3  90 500 1 411
    4 200 460 1 261
end
char dose[tvtools_quantity] "total"
save "tc_ready.dta", replace

capture program drop _tvc_spec_new
program define _tvc_spec_new
    version 16.0
    args fr
    capture frame drop `fr'
    frame create `fr'
    frame `fr' {
        quietly generate str32 source_name = ""
        quietly generate str12 source_kind = ""
        quietly generate str32 source_frame = ""
        quietly generate strL  source_file = ""
        quietly generate str32 start_var = ""
        quietly generate str32 stop_var = ""
        quietly generate strL  input_vars = ""
        quietly generate strL  output_vars = ""
        quietly generate double reference = .
        quietly generate strL  rate_vars = ""
        quietly generate strL  total_vars = ""
        quietly generate strL  cumulative_vars = ""
        quietly generate strL  reference_label = ""
        quietly generate strL  variable_label = ""
        quietly generate strL  description = ""
    }
end

capture program drop _tvc_spec_add
program define _tvc_spec_add
    version 16.0
    syntax , FR(name) NAME(string) KIND(string) ///
        SV(string) PV(string) IV(string) OV(string) ///
        [SFRAME(string) SFILE(string) REF(string) TV(string)]
    local _here "`c(frame)'"
    frame change `fr'
    local n = _N + 1
    quietly set obs `n'
    quietly replace source_name  = "`name'"   in `n'
    quietly replace source_kind  = "`kind'"   in `n'
    quietly replace source_frame = "`sframe'" in `n'
    quietly replace source_file  = `"`sfile'"' in `n'
    quietly replace start_var    = "`sv'"     in `n'
    quietly replace stop_var     = "`pv'"     in `n'
    quietly replace input_vars   = "`iv'"     in `n'
    quietly replace output_vars  = "`ov'"     in `n'
    if "`ref'" != "" quietly replace reference = `ref' in `n'
    quietly replace total_vars   = "`tv'"     in `n'
    quietly replace description  = "fixture"  in `n'
    frame change `_here'
end

* The composed primitive sequence: tvexpose into a frame, then tvevent from the
* event data with that frame as the interval input.
* The composed sequence runs entirely inside its own scratch frames and saves
* its result, so it can be called repeatedly without leaving the suite sitting
* in a different frame than it started in. A helper that changes the current
* frame and does not change it back turns every later `use ..., clear' into a
* write to the wrong frame -- silently, and with rc=0.
capture program drop _tvc_oracle
program define _tvc_oracle
    version 16.0
    syntax , EVFile(string) SAVing(string) OUTvars(string) ///
        [TYPE(string) COMpete(string) EVDate(string) EXTra(string)]
    if "`type'" == "" local type "single"
    if "`evdate'" == "" local evdate "evdate"
    local _here "`c(frame)'"
    capture frame drop tc_o1
    frame create tc_o1
    frame tc_o1: use "tc_cohort.dta", clear
    frame change tc_o1
    tvexpose using "tc_epi.dta", id(pid) start(a_start) stop(a_stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug) frameout(tc_ox) replace
    frame change `_here'
    frame tc_ox: rename (a_start a_stop) (start stop)
    capture frame drop tc_oev
    frame create tc_oev
    frame tc_oev: use `"`evfile'"', clear
    frame change tc_oev
    local _c ""
    if "`compete'" != "" local _c "compete(`compete')"
    tvevent, frame(tc_ox) id(pid) date(`evdate') type(`type') ///
        start(start) stop(stop) generate(_failure) `_c' `extra'
    keep `outvars'
    order `outvars'
    sort pid start stop
    quietly save `"`saving'"', replace
    frame change `_here'
    capture frame drop tc_o1
    capture frame drop tc_ox
    capture frame drop tc_oev
end

**# ---------------------------------------------------------------------
**# E. The event stage against the frozen tvevent sequence
**# ---------------------------------------------------------------------
local BASE id(pid) entry(study_entry) exit(study_exit)
local SRC sourceusing("tc_epi.dta") start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug)

* E1: no event stage means no event columns and event_stage == 0.
local ++test_count
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e1) replace
local e1_rc = _rc
local e1_stage = r(event_stage)
local e1_v ""
capture frame tc_e1: quietly ds
if _rc == 0 local e1_v "`r(varlist)'"
local ok = (`e1_rc' == 0 & `e1_stage' == 0 & ///
    "`e1_v'" == "pid study_entry study_exit start stop tv_drug")
_tvc_check `ok' "E1 without eventdate() there is no event stage and no columns" ///
    "rc=`e1_rc' stage=`e1_stage' vars=`e1_v'"

* E2: a single event from a file, against the frozen sequence.
local ++test_count
tempfile e2oracle
_tvc_oracle, evfile("tc_ev.dta") saving("`e2oracle'") ///
    outvars(pid start stop tv_drug _failure)
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e2) replace ///
    eventusing("tc_ev.dta") eventdate(evdate)
local e2_rc = _rc
local e2_var "`r(eventvar)'"
* The comparison is capture'd end to end: when the run under test failed there
* is no destination to copy, and an unguarded `frame copy' would end the suite
* before the remaining axes ran.
_tvc_compare, frame(tc_e2) vars(pid start stop tv_drug _failure) ///
    oracle("`e2oracle'")
local e2_cf = r(rc)
local ok = (`e2_rc' == 0 & `e2_cf' == 0 & !missing(`e2_cf') & "`e2_var'" == "_failure")
_tvc_check `ok' "E2 a single event equals the frozen tvexpose+tvevent sequence" ///
    "rc=`e2_rc' cf=`e2_cf' eventvar=`e2_var'"

* E3: the four placement geometries land where tvevent puts them.
local ++test_count
local e3_p1 = .
local e3_p1stop = .
local e3_p2 = .
local e3_p2start = .
local e3_p3 = .
local e3_p4 = .
_tvc_ready, fr(tc_e2)
if r(ok) {
frame tc_e2 {
    quietly count if pid == 1 & _failure == 1
    local e3_p1 = r(N)
    quietly summarize stop if pid == 1 & _failure == 1, meanonly
    local e3_p1stop = r(mean)
    quietly count if pid == 2 & _failure == 1
    local e3_p2 = r(N)
    quietly summarize start if pid == 2 & _failure == 1, meanonly
    local e3_p2start = r(mean)
    quietly count if pid == 3 & _failure == 1
    local e3_p3 = r(N)
    quietly count if pid == 4 & _failure == 1
    local e3_p4 = r(N)
}
}
local ok = (`e3_p1' == 1 & `e3_p1stop' == 175 & `e3_p2' == 1 & ///
    `e3_p2start' == 130 & `e3_p3' == 1 & `e3_p4' == 0)
_tvc_check `ok' ///
    "E3 internal, at-start, at-exit, and after-exit events land correctly" ///
    "p1=`e3_p1'@`e3_p1stop' p2=`e3_p2'@`e3_p2start' p3=`e3_p3' p4=`e3_p4'"

* E4: the same event data as a FRAME gives the same answer as the file.
local ++test_count
capture frame drop tc_evfr
frame create tc_evfr
frame tc_evfr: use "tc_ev.dta", clear
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e4) replace ///
    eventframe(tc_evfr) eventdate(evdate)
local e4_rc = _rc
* The colon form aborts on a missing frame exactly as the brace form does; it
* is guarded for the same reason. E2's frame is read here, so a defect that
* stopped E2 creating it would otherwise end the suite at E4.
local e4_a ""
local e4_b ""
_tvc_ready, fr(tc_e2)
if r(ok) {
    frame tc_e2: quietly datasignature
    local e4_a "`r(datasignature)'"
}
_tvc_ready, fr(tc_e4)
if r(ok) {
    frame tc_e4: quietly datasignature
    local e4_b "`r(datasignature)'"
}
local ok = (`e4_rc' == 0 & "`e4_a'" == "`e4_b'" & "`e4_a'" != "")
_tvc_check `ok' "E4 an event frame and an event file with the same data agree" ///
    "rc=`e4_rc' file=`e4_a' frame=`e4_b'"

* E5: event variables in the master, with no separate event input.
local ++test_count
use "tc_cohort_ev.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e5) replace eventdate(evdate)
local e5_rc = _rc
local e5_s ""
_tvc_ready, fr(tc_e5)
if r(ok) {
    frame tc_e5: quietly datasignature
    local e5_s "`r(datasignature)'"
}
local ok = (`e5_rc' == 0 & "`e5_s'" == "`e4_a'")
_tvc_check `ok' "E5 event columns taken from the master agree with a separate input" ///
    "rc=`e5_rc' master=`e5_s' file=`e4_a'"

* E6: competing risks. The earlier date wins for person 1; person 2 has both
* on the same day.
local ++test_count
tempfile e6oracle
_tvc_oracle, evfile("tc_evc.dta") compete(compdate) saving("`e6oracle'") ///
    outvars(pid start stop tv_drug _failure)
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e6) replace ///
    eventusing("tc_evc.dta") eventdate(evdate) compete(compdate)
local e6_rc = _rc
_tvc_compare, frame(tc_e6) vars(pid start stop tv_drug _failure) ///
    oracle("`e6oracle'")
local e6_cf = r(rc)
local e6_p1 = .
capture frame tc_e6: quietly summarize stop if pid == 1 & _failure > 0 & !missing(_failure), meanonly
if _rc == 0 local e6_p1 = r(max)
local ok = (`e6_rc' == 0 & `e6_cf' == 0 & `e6_p1' == 175)
_tvc_check `ok' "E6 competing risks match tvevent and the earlier date wins" ///
    "rc=`e6_rc' cf=`e6_cf' p1_stop=`e6_p1'"

* E7: recurring events with enum and gap time.
local ++test_count
tempfile e7oracle
_tvc_oracle, evfile("tc_evr.dta") type(recurring) evdate(ev) ///
    extra(enum(_enum) gaptime gapstart(_g0) gapstop(_g1)) ///
    saving("`e7oracle'") outvars(pid start stop tv_drug _failure _enum _g0 _g1)
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e7) replace ///
    eventusing("tc_evr.dta") eventdate(ev) eventtype(recurring) ///
    enum(_enum) gaptime gapstart(_g0) gapstop(_g1)
local e7_rc = _rc
local e7_en "`r(enumvar)'"
local e7_g0 "`r(gapstartvar)'"
_tvc_compare, frame(tc_e7) vars(pid start stop tv_drug _failure _enum _g0 _g1) ///
    oracle("`e7oracle'")
local e7_cf = r(rc)
local ok = (`e7_rc' == 0 & `e7_cf' == 0 & "`e7_en'" == "_enum" & "`e7_g0'" == "_g0")
_tvc_check `ok' "E7 recurring events with enum and gap time match tvevent" ///
    "rc=`e7_rc' cf=`e7_cf' enum=`e7_en' gapstart=`e7_g0'"

* E8: timegen()/timeunit() reach the result with the requested unit.
local ++test_count
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e8) replace ///
    eventusing("tc_ev.dta") eventdate(evdate) timegen(_elapsed) timeunit(days)
local e8_rc = _rc
local e8_tv "`r(timevar)'"
local e8_val = .
_tvc_ready, fr(tc_e8)
if r(ok) {
frame tc_e8 {
    quietly summarize _elapsed if pid == 1 & _failure == 1, meanonly
    local e8_val = r(mean)
}
}
local ok = (`e8_rc' == 0 & "`e8_tv'" == "_elapsed" & `e8_val' == 75)
_tvc_check `ok' "E8 timegen() records elapsed time in the requested unit" ///
    "rc=`e8_rc' var=`e8_tv' value=`e8_val'"

* E9: the event date and the competing-risk date are inputs, and do not become
* committed payload.
local ++test_count
local e9_v ""
capture frame tc_e6: quietly ds
if _rc == 0 local e9_v "`r(varlist)'"
local e9_leak = 0
foreach v of local e9_v {
    if inlist("`v'", "evdate", "compdate") local e9_leak = 1
}
local ok = (`e9_leak' == 0 & "`e9_v'" != "")
_tvc_check `ok' "E9 event input columns are not carried into the result" ///
    "vars=`e9_v'"

* E10: an interval total is apportioned across the event split.
local ++test_count
_tvc_spec_new tc_specq
_tvc_spec_add, fr(tc_specq) name(rd) kind(intervals) sfile("tc_ready.dta") ///
    sv(start) pv(stop) iv(st dose) ov(state dose_t) tv(dose)
use "tc_cohort.dta", clear
capture tvbuild, specframe(tc_specq) `BASE' frameout(tc_e10) replace ///
    eventusing("tc_evr.dta") eventdate(ev) eventtype(recurring)
local e10_rc = _rc
local e10_sum = .
local e10_rows = .
_tvc_ready, fr(tc_e10)
if r(ok) {
frame tc_e10 {
    quietly summarize dose_t if pid == 1, meanonly
    local e10_sum = r(sum)
    quietly count if pid == 1
    local e10_rows = r(N)
}
}
* !missing() is explicit rather than implied. A skipped probe block leaves
* these at missing, and `. > 1' is TRUE in Stata -- the row-count conjunct
* would pass on a run that produced no frame at all. It is only the `< 1e-6'
* conjunct failing first that makes the unguarded form safe, and relying on
* conjunct order for that is not a property worth depending on.
local ok = (`e10_rc' == 0 & !missing(`e10_sum', `e10_rows') & ///
    abs(`e10_sum' - 401) < 1e-6 & `e10_rows' > 1)
_tvc_check `ok' "E10 an interval total is apportioned across the event split" ///
    "rc=`e10_rc' sum=`e10_sum' expected 401 rows=`e10_rows'"

* E11: one file serving both a source role and the event role. Section 12.6
* step 4 requires it to be loaded once and used twice, not read twice.
local ++test_count
clear
input long pid double s double e byte lvl double evdate
    1 100 500 1 175
    2 120 480 2 130
    3  90 500 1 500
    4 200 460 2 900
end
quietly save "tc_both.dta", replace
_tvc_spec_new tc_specb
_tvc_spec_add, fr(tc_specb) name(b) kind(intervals) sfile("tc_both.dta") ///
    sv(s) pv(e) iv(lvl) ov(state)
use "tc_cohort.dta", clear
capture tvbuild, specframe(tc_specb) `BASE' frameout(tc_e11) replace ///
    eventusing("tc_both.dta") eventdate(evdate)
local e11_rc = _rc
local e11_v ""
local e11_ev = .
_tvc_ready, fr(tc_e11)
if r(ok) {
frame tc_e11 {
    quietly ds
    local e11_v "`r(varlist)'"
    quietly count if _failure == 1
    local e11_ev = r(N)
}
}
local ok = (`e11_rc' == 0 & ///
    "`e11_v'" == "pid study_entry study_exit start stop state _failure" & ///
    `e11_ev' == 3)
_tvc_check `ok' ///
    "E11 one locator serving both the source and the event role works once" ///
    "rc=`e11_rc' vars=`e11_v' events=`e11_ev'"

* E11b: a source OUTPUT name that would overwrite the event date is refused.
* replace authorises replacing a destination, never an input role.
local ++test_count
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e11b) replace ///
    eventusing("tc_ev.dta") eventdate(evdate) keepvars(sex)
local e11b_ok_rc = _rc
_tvc_spec_new tc_specz
_tvc_spec_add, fr(tc_specz) name(z) kind(episodes) sfile("tc_epi.dta") ///
    sv(a_start) pv(a_stop) iv(drug) ov(evdate) ref(0)
use "tc_cohort.dta", clear
capture tvbuild, specframe(tc_specz) `BASE' frameout(tc_e11c) replace ///
    eventusing("tc_ev.dta") eventdate(evdate)
local e11b_rc = _rc
capture confirm frame tc_e11c
local e11b_none = (_rc != 0)
local ok = (`e11b_ok_rc' == 0 & `e11b_rc' == 198 & `e11b_none')
_tvc_check `ok' ///
    "E11b an output name that would overwrite the event date is refused" ///
    "control_rc=`e11b_ok_rc' rc=`e11b_rc' destination_absent=`e11b_none'"

* E12: eventlabel() reaches the committed event variable.
*
* Regression for 1.10.1. tvevent declares eventlabel() `string asis' and
* splices the value straight into `label define <name> <eventlabel>, modify',
* so it needs the bare `value "Label"' pair grammar. _tvbuild_event used to
* re-wrap the value in compound quotes -- correct for a plain `string'
* destination, fatal for an asis one -- and every eventlabel() value tvbuild
* was given failed with r(198). The option was unusable from the day it
* shipped, so an rc check alone is the whole regression; the label text is
* asserted too because a value that arrives quoted but non-fatal would apply
* the wrong text at rc=0.
*
* E12a is the rc, E12b the applied text, E12c the multi-word case: a label
* containing a space is what a compound-quote defect mangles first, and it is
* also the form a user is most likely to type.
local ++test_count
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e12) replace ///
    eventusing("tc_ev.dta") eventdate(evdate) eventgenerate(fail) ///
    eventlabel(1 "Dead")
local e12_rc = _rc
local e12_txt ""
if `e12_rc' == 0 {
    frame change tc_e12
    local _vl : value label fail
    if "`_vl'" != "" local e12_txt : label `_vl' 1
    frame change default
}
local ok = (`e12_rc' == 0)
_tvc_check `ok' "E12a eventlabel() does not fail the event stage" ///
    "rc=`e12_rc'"

local ++test_count
local ok = (`"`e12_txt'"' == "Dead")
_tvc_check `ok' "E12b eventlabel() text reaches the committed event variable" ///
    "text=<`e12_txt'>"

local ++test_count
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_e12c) replace ///
    eventusing("tc_ev.dta") eventdate(evdate) eventgenerate(fail) ///
    eventlabel(0 "Still at risk" 1 "Died of any cause")
local e12c_rc = _rc
local e12c_t1 ""
local e12c_t0 ""
if `e12c_rc' == 0 {
    frame change tc_e12c
    local _vl : value label fail
    if "`_vl'" != "" {
        local e12c_t1 : label `_vl' 1
        local e12c_t0 : label `_vl' 0
    }
    frame change default
}
local ok = (`e12c_rc' == 0 & `"`e12c_t1'"' == "Died of any cause" & ///
    `"`e12c_t0'"' == "Still at risk")
_tvc_check `ok' ///
    "E12c multi-word eventlabel() pairs survive the hop into tvevent" ///
    "rc=`e12c_rc' one=<`e12c_t1'> zero=<`e12c_t0'>"

**# ---------------------------------------------------------------------
**# P. Provenance
**# ---------------------------------------------------------------------
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_p1) manifestframe(tc_man) replace ///
    eventusing("tc_ev.dta") eventdate(evdate)
local p_rc = _rc
local p_sig "`r(datasignature)'"
local p_mf "`r(manifestframe)'"
local p_np = r(N_periods)

* P1: one row per executed stage, in execution order.
local ++test_count
local p1_n = .
local p1_s1 = .
local p1_s2 = .
local p1_s3 = .
local p1_s4 = .
_tvc_ready, fr(tc_man)
if r(ok) {
frame tc_man {
    quietly count
    local p1_n = r(N)
    local p1_s1 = stage[1]
    local p1_s2 = stage[2]
    local p1_s3 = stage[3]
    local p1_s4 = stage[4]
}
}
local ok = (`p_rc' == 0 & `p1_n' == 4 & "`p1_s1'" == "master" & ///
    "`p1_s2'" == "source" & "`p1_s3'" == "event" & "`p1_s4'" == "output")
_tvc_check `ok' "P1 the manifest has one row per executed stage, in order" ///
    "rc=`p_rc' n=`p1_n' stages=`p1_s1' `p1_s2' `p1_s3' `p1_s4'"

* P2: no merge row when there is only one source.
local ++test_count
local p2_m = .
_tvc_ready, fr(tc_man)
if r(ok) {
frame tc_man {
    quietly count if stage == "merge"
    local p2_m = r(N)
}
}
local ok = (`p2_m' == 0)
_tvc_check `ok' "P2 a one-source run records no merge stage" "merge_rows=`p2_m'"

* P3: the signature is on the output row only, and equals r(datasignature).
local ++test_count
local p3_out = .
local p3_n = .
_tvc_ready, fr(tc_man)
if r(ok) {
frame tc_man {
    local p3_out = data_signature[4]
    quietly count if data_signature != ""
    local p3_n = r(N)
}
}
local ok = ("`p3_out'" == "`p_sig'" & `p3_n' == 1 & "`p_sig'" != "")
_tvc_check `ok' "P3 the data signature appears on the output row only" ///
    "row4=`p3_out' r=`p_sig' rows_with_sig=`p3_n'"

* P4: the manifest's source row carries the declared mapping and the engine.
local ++test_count
local p4_iv = .
local p4_ov = .
local p4_en = .
local p4_ni = .
_tvc_ready, fr(tc_man)
if r(ok) {
frame tc_man {
    local p4_iv = input_vars[2]
    local p4_ov = output_vars[2]
    local p4_en = engine[2]
    local p4_ni = n_input[2]
}
}
local ok = ("`p4_iv'" == "drug" & "`p4_ov'" == "tv_drug" & ///
    "`p4_en'" == "tvexpose_categorical" & `p4_ni' == 5)
_tvc_check `ok' "P4 the manifest source row carries the mapping and the engine" ///
    "in=`p4_iv' out=`p4_ov' engine=`p4_en' n=`p4_ni'"

* P5: every provenance characteristic is written, with the event name.
local ++test_count
local p5_p ""
local p5_s ""
local p5_c ""
local p5_st ""
local p5_sp ""
local p5_e ""
local p5_k ""
_tvc_ready, fr(tc_p1)
if r(ok) {
frame tc_p1 {
    local p5_p : char _dta[tvtools_tvbuild]
    local p5_s : char _dta[tvtools_tvbuild_schema]
    local p5_c : char _dta[tvtools_tvbuild_coverage]
    local p5_st : char _dta[tvtools_tvbuild_start]
    local p5_sp : char _dta[tvtools_tvbuild_stop]
    local p5_e : char _dta[tvtools_tvbuild_event]
    local p5_k : char _dta[tvtools_tvbuild_committed]
}
}
local ok = ("`p5_p'" == "tvbuild" & "`p5_s'" == "1" & "`p5_c'" == "strict" & ///
    "`p5_st'" == "start" & "`p5_sp'" == "stop" & "`p5_e'" == "_failure" & ///
    "`p5_k'" == "1")
_tvc_check `ok' "P5 the provenance characteristics are complete" ///
    "pipe=`p5_p' schema=`p5_s' cov=`p5_c' start=`p5_st' stop=`p5_sp' event=`p5_e' done=`p5_k'"

* P6: r(datasignature) is the signature of what is actually in the frame, not
* of the scratch result that preceded it.
local ++test_count
local p6_now ""
_tvc_ready, fr(tc_p1)
if r(ok) {
    frame tc_p1: quietly datasignature
    local p6_now "`r(datasignature)'"
}
local ok = ("`p6_now'" == "`p_sig'")
_tvc_check `ok' "P6 r(datasignature) recomputes on the committed frame" ///
    "returned=`p_sig' recomputed=`p6_now'"

**# ---------------------------------------------------------------------
**# T. Destination ownership, commit, and rollback
**# ---------------------------------------------------------------------

* T1: an existing destination without replace is refused and untouched.
local ++test_count
capture frame drop tc_t1
frame create tc_t1
_tvc_ready, fr(tc_t1)
if r(ok) {
frame tc_t1 {
    clear
    quietly set obs 3
    quietly generate byte marker = _n
    label variable marker "user data"
}
}
_tvc_fingerprint tc_t1
local t1_before "`r(fingerprint)'"
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_t1)
local t1_rc = _rc
_tvc_fingerprint tc_t1
local t1_after "`r(fingerprint)'"
local ok = (`t1_rc' == 110 & `"`t1_before'"' == `"`t1_after'"')
_tvc_check `ok' "T1 an existing destination without replace is refused intact" ///
    "rc=`t1_rc' unchanged=" + string(`"`t1_before'"' == `"`t1_after'"')

* T2: with replace, the destination is replaced.
local ++test_count
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_t1) replace
local t2_rc = _rc
local t2_gone = .
local t2_new = .
_tvc_ready, fr(tc_t1)
if r(ok) {
frame tc_t1 {
    capture confirm variable marker
    local t2_gone = (_rc != 0)
    capture confirm variable tv_drug
    local t2_new = (_rc == 0)
}
}
local ok = (`t2_rc' == 0 & `t2_gone' & `t2_new')
_tvc_check `ok' "T2 replace overwrites the destination" ///
    "rc=`t2_rc' old_gone=`t2_gone' new_present=`t2_new'"

* T3: an existing manifest destination without replace is refused, and the
* output frame is not created either -- the refusal happens before any work.
local ++test_count
capture frame drop tc_t3out
capture frame drop tc_t3man
frame create tc_t3man
_tvc_ready, fr(tc_t3man)
if r(ok) {
frame tc_t3man {
    clear
    quietly set obs 2
    quietly generate byte keepme = _n
}
}
_tvc_fingerprint tc_t3man
local t3_before "`r(fingerprint)'"
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_t3out) manifestframe(tc_t3man)
local t3_rc = _rc
capture confirm frame tc_t3out
local t3_noout = (_rc != 0)
_tvc_fingerprint tc_t3man
local t3_after "`r(fingerprint)'"
local ok = (`t3_rc' == 110 & `t3_noout' & `"`t3_before'"' == `"`t3_after'"')
_tvc_check `ok' ///
    "T3 an existing manifest without replace refuses before any destination is made" ///
    "rc=`t3_rc' output_absent=`t3_noout'"

* T4: a destination that aliases an input is refused even with replace.
local ++test_count
capture frame drop tc_srcfr
frame create tc_srcfr
frame tc_srcfr: use "tc_epi.dta", clear
use "tc_cohort.dta", clear
capture tvbuild, sourceframe(tc_srcfr) `BASE' start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) frameout(tc_srcfr) replace
local t4_rc = _rc
local t4_intact = .
_tvc_ready, fr(tc_srcfr)
if r(ok) {
frame tc_srcfr {
    capture confirm variable a_start
    local t4_intact = (_rc == 0)
}
}
local ok = (`t4_rc' == 198 & `t4_intact')
_tvc_check `ok' "T4 replace never makes an input/output alias legal" ///
    "rc=`t4_rc' source_intact=`t4_intact'"

* T5: a failure after preflight leaves a pre-existing destination identical in
* data AND in every metadata category.
local ++test_count
capture frame drop tc_t5
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_t5) manifestframe(tc_t5man) replace
_tvc_fingerprint tc_t5
local t5_before "`r(fingerprint)'"
* A source whose ready intervals leave a gap: refused under strict, after the
* destination already exists.
clear
input long pid double start double stop byte st
    1 100 200 1
    2 120 480 1
    3  90 500 1
    4 200 460 1
end
quietly save "tc_gap.dta", replace
_tvc_spec_new tc_specg
_tvc_spec_add, fr(tc_specg) name(g) kind(intervals) sfile("tc_gap.dta") ///
    sv(start) pv(stop) iv(st) ov(state)
use "tc_cohort.dta", clear
capture tvbuild, specframe(tc_specg) `BASE' frameout(tc_t5) replace
local t5_rc = _rc
_tvc_fingerprint tc_t5
local t5_after "`r(fingerprint)'"
local ok = (`t5_rc' != 0 & `"`t5_before'"' == `"`t5_after'"')
_tvc_check `ok' ///
    "T5 a failure leaves a pre-existing destination identical in data and metadata" ///
    "rc=`t5_rc' unchanged=" + string(`"`t5_before'"' == `"`t5_after'"')

* T6: a failure BETWEEN the two commits. This is the only window in which the
* output frame has already been written, so it is the only one that exercises
* the restore rather than the drop. The manifest builder is shadowed by a stub
* that produces an empty frame, which the commit verification refuses.
* The pre-existing destination is deliberately built with a DIFFERENT schema
* from the one the failing run would produce. Two runs that agree cannot tell a
* restored backup from a backup that was never restored -- the frame looks the
* same either way, and the test passes while the rollback does nothing.
local ++test_count
capture frame drop tc_t6
capture frame drop tc_t6man
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_t6) manifestframe(tc_t6man) ///
    replace dropdates
local t6_setup = _rc
_tvc_fingerprint tc_t6
local t6_before "`r(fingerprint)'"
_tvc_fingerprint tc_t6man
local t6_mbefore "`r(fingerprint)'"

capture program drop _tvbuild_manifest
program define _tvbuild_manifest, rclass
    version 16.0
    syntax , MANframe(name) [*]
    capture frame drop `manframe'
    frame create `manframe'
    return scalar n_stages = 0
end

use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_t6) manifestframe(tc_t6man) replace
local t6_rc = _rc
capture program drop _tvbuild_manifest
discard

_tvc_fingerprint tc_t6
local t6_after "`r(fingerprint)'"
_tvc_fingerprint tc_t6man
local t6_mafter "`r(fingerprint)'"
local ok = (`t6_setup' == 0 & `t6_rc' != 0 & ///
    `"`t6_before'"' == `"`t6_after'"' & `"`t6_mbefore'"' == `"`t6_mafter'"')
_tvc_check `ok' ///
    "T6 a failure between the two commits restores both destinations" ///
    "setup=`t6_setup' rc=`t6_rc' out_same=" + ///
    string(`"`t6_before'"' == `"`t6_after'"') + " man_same=" + ///
    string(`"`t6_mbefore'"' == `"`t6_mafter'"')

* T7: the same forced failure when neither destination existed on entry must
* leave neither behind, rather than restoring a backup that was never taken.
local ++test_count
capture frame drop tc_t7
capture frame drop tc_t7man
capture program drop _tvbuild_manifest
program define _tvbuild_manifest, rclass
    version 16.0
    syntax , MANframe(name) [*]
    capture frame drop `manframe'
    frame create `manframe'
    return scalar n_stages = 0
end
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_t7) manifestframe(tc_t7man)
local t7_rc = _rc
capture program drop _tvbuild_manifest
discard
capture confirm frame tc_t7
local t7_noout = (_rc != 0)
capture confirm frame tc_t7man
local t7_noman = (_rc != 0)
local ok = (`t7_rc' != 0 & `t7_noout' & `t7_noman')
_tvc_check `ok' ///
    "T7 a failed commit into new destinations leaves neither frame behind" ///
    "rc=`t7_rc' out_absent=`t7_noout' man_absent=`t7_noman'"

* T8: frameout() and manifestframe() may not be the same frame.
local ++test_count
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_same) manifestframe(tc_same) replace
local t8_rc = _rc
capture confirm frame tc_same
local t8_none = (_rc != 0)
local ok = (`t8_rc' == 198 & `t8_none')
_tvc_check `ok' "T8 the two destinations must be different frames" ///
    "rc=`t8_rc' absent=`t8_none'"

**# ---------------------------------------------------------------------
**# S. Session state
**# ---------------------------------------------------------------------

* S1: after a successful run the caller's data, sort order, current frame, and
* frame list are unchanged apart from the two destinations.
local ++test_count
capture frame drop tc_s1
capture frame drop tc_s1man
use "tc_cohort.dta", clear
sort study_entry
quietly datasignature
local s1_sig "`r(datasignature)'"
local s1_sorted "`: sortedby'"
local s1_frame "`c(frame)'"
_tvc_framelist
local s1_fl "`r(frames)'"
local s1_va "`c(varabbrev)'"
capture tvbuild, `SRC' `BASE' frameout(tc_s1) manifestframe(tc_s1man) replace
local s1_rc = _rc
quietly datasignature
local s1_sig2 "`r(datasignature)'"
_tvc_framelist
local s1_fl2 "`r(frames)'"
local s1_expect "`s1_fl' tc_s1 tc_s1man"
local s1_expect : list sort s1_expect
local ok = (`s1_rc' == 0 & "`s1_sig'" == "`s1_sig2'" & ///
    "`s1_sorted'" == "`: sortedby'" & "`c(frame)'" == "`s1_frame'" & ///
    "`s1_fl2'" == "`s1_expect'" & "`c(varabbrev)'" == "`s1_va'")
_tvc_check `ok' ///
    "S1 success leaves the caller's data, sort order, and frame list intact" ///
    "rc=`s1_rc' sig=`s1_sig'/`s1_sig2' sortedby=`s1_sorted'/`: sortedby' frames=`s1_fl2'"

* S2: the same after a failure.
local ++test_count
use "tc_cohort.dta", clear
sort study_exit
quietly datasignature
local s2_sig "`r(datasignature)'"
local s2_sorted "`: sortedby'"
_tvc_framelist
local s2_fl "`r(frames)'"
capture tvbuild, specframe(tc_specg) `BASE' frameout(tc_s2fail)
local s2_rc = _rc
quietly datasignature
local s2_sig2 "`r(datasignature)'"
_tvc_framelist
local s2_fl2 "`r(frames)'"
local ok = (`s2_rc' != 0 & "`s2_sig'" == "`s2_sig2'" & ///
    "`s2_sorted'" == "`: sortedby'" & "`s2_fl'" == "`s2_fl2'" & ///
    "`c(varabbrev)'" == "`s1_va'")
_tvc_check `ok' ///
    "S2 a failure leaves no scratch frame and no change to the caller" ///
    "rc=`s2_rc' sig=`s2_sig'/`s2_sig2' frames_equal=" + string("`s2_fl'" == "`s2_fl2'")

* S3: the caller's value-label namespace is untouched.
local ++test_count
use "tc_cohort.dta", clear
label define tc_keep 1 "original"
label values sex tc_keep
quietly label dir
local s3_before "`r(names)'"
local s3_before : list sort s3_before
capture tvbuild, `SRC' `BASE' frameout(tc_s3) replace
local s3_rc = _rc
quietly label dir
local s3_after "`r(names)'"
local s3_after : list sort s3_after
local s3_txt : label tc_keep 1
local ok = (`s3_rc' == 0 & "`s3_before'" == "`s3_after'" & "`s3_txt'" == "original")
_tvc_check `ok' "S3 the caller's value-label namespace is untouched" ///
    "rc=`s3_rc' before=`s3_before' after=`s3_after' text=`s3_txt'"

* S4: an active e() survives.
local ++test_count
use "tc_cohort.dta", clear
quietly regress study_exit study_entry
local s4_cmd "`e(cmd)'"
local s4_n = e(N)
capture tvbuild, `SRC' `BASE' frameout(tc_s4) replace
local s4_rc = _rc
local ok = (`s4_rc' == 0 & "`e(cmd)'" == "`s4_cmd'" & e(N) == `s4_n')
_tvc_check `ok' "S4 an active e() survives a tvbuild run" ///
    "rc=`s4_rc' cmd=`e(cmd)' N=`=e(N)'"

* S5: the source and event input frames are unchanged.
local ++test_count
capture frame drop tc_s5src
capture frame drop tc_s5ev
frame create tc_s5src
frame tc_s5src: use "tc_epi.dta", clear
frame create tc_s5ev
frame tc_s5ev: use "tc_ev.dta", clear
_tvc_fingerprint tc_s5src
local s5_sb "`r(fingerprint)'"
_tvc_fingerprint tc_s5ev
local s5_eb "`r(fingerprint)'"
use "tc_cohort.dta", clear
capture tvbuild, sourceframe(tc_s5src) `BASE' start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) frameout(tc_s5) replace ///
    eventframe(tc_s5ev) eventdate(evdate)
local s5_rc = _rc
_tvc_fingerprint tc_s5src
local s5_sa "`r(fingerprint)'"
_tvc_fingerprint tc_s5ev
local s5_ea "`r(fingerprint)'"
local ok = (`s5_rc' == 0 & `"`s5_sb'"' == `"`s5_sa'"' & `"`s5_eb'"' == `"`s5_ea'"')
_tvc_check `ok' "S5 the source and event input frames are read-only" ///
    "rc=`s5_rc' src_same=" + string(`"`s5_sb'"' == `"`s5_sa'"') + ///
    " ev_same=" + string(`"`s5_eb'"' == `"`s5_ea'"')

* S6: no helper r() leaks into tvbuild's return surface.
local ++test_count
use "tc_cohort.dta", clear
capture tvbuild, `SRC' `BASE' frameout(tc_s6) replace ///
    eventusing("tc_ev.dta") eventdate(evdate)
local s6_rc = _rc
local s6_names "`: r(scalars)' `: r(macros)' `: r(matrices)'"
local s6_allowed dryrun spec_version n_sources N_persons event_stage ///
    dates_kept N_periods n_gap_ids uncovered_days ///
    idvar entryvar exitvar startvar stopvar source_names payload_vars ///
    exposure_vars rate_vars total_vars cumulative_vars frameout coverage ///
    datasignature eventvar timevar enumvar gapstartvar gapstopvar ///
    specframe manifestframe source_counts stage_counts
local s6_extra : list s6_names - s6_allowed
local ok = (`s6_rc' == 0 & "`s6_extra'" == "")
_tvc_check `ok' "S6 no helper result leaks into tvbuild's return surface" ///
    "unexpected=`s6_extra'"

**# Cleanup
foreach f in tc_cohort tc_epi tc_ev tc_evc tc_evr tc_cohort_ev tc_ready ///
    tc_gap tc_both {
    capture erase "`f'.dta"
}

**# Summary
local pass_count = $TVC_PASS
local fail_count = $TVC_FAIL
display "RESULT: test_tvbuild_commit tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "tvbuild commit failures:$TVC_FAILED"
    exit 1
}
