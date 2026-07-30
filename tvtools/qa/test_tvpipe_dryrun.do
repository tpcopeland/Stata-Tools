*! test_tvpipe_dryrun.do
*! Phase 4A contract pins for tvpipe: parsing, normalization, preflight, dryrun.
*!
*! tvpipe is a coordinator over the tvexpose/tvmerge/tvevent engines. Phase 4A
*! is everything that happens before the first kernel: the public syntax, the
*! specification normalizer, the complete read-only preflight, the plan
*! display, and the dryrun return surface. Construction, merge, events, and
*! commit are Phase 4B/4C and are not exercised here.
*!
*! The three tvpipe-specific false greens this suite is written against:
*!
*!   1. "tvpipe never actually validated anything." A dry run that returns
*!      rc=0 on a plan it never inspected looks exactly like a dry run that
*!      inspected it. Every refusal group below (R*) is a case where a real
*!      preflight must fail; a suite of only happy paths cannot tell the two
*!      apart. R14-R19 in particular reach data-level checks that need the
*!      source actually loaded and joined to the master.
*!
*!   2. "Both input forms share one normalizer bug and therefore agree." P3
*!      compares the inline and one-row specframe forms against each other,
*!      which on its own would pass while both were wrong. P4 compares each of
*!      them against a FIXED expected plan written out by hand.
*!
*!   3. "The plan was right while the session drifted." A dry run promises to
*!      change nothing. S1-S8 assert the caller's data signature, variable
*!      list, sort order, the frame list, the value-label namespace, active
*!      e(), c(varabbrev), and the current frame across both success and
*!      failure paths -- because the failure paths are where a half-built
*!      scratch frame survives.
*!
*! Axes probed:
*!   P1-P8    both public input forms, their equivalence, and a fixed oracle
*!   R1-R13   parsing, specification-schema, and name refusals
*!   R14-R22  master, locator, and source data refusals
*!   E1-E7    the event stage's option and data preflight
*!   D1-D5    destination ownership and replace
*!   C1-C4    counts: rows, persons, unmatched ids, rows outside the window
*!   S1-S9    session state after success, after failure, and on repeat

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvpipe_dryrun.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVP_PASS = 0
global TVP_FAIL = 0
global TVP_FAILED ""
local test_count = 0

display as result "tvtools QA: tvpipe dry run (Phase 4A) -- $S_DATE $S_TIME"

capture program drop _tvp_check
program define _tvp_check
    args ok label detail
    if `ok' {
        global TVP_PASS = $TVP_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVP_FAIL = $TVP_FAIL + 1
        global TVP_FAILED "$TVP_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

* Sorted frame list. `frames dir' only displays; st_framedir() is the only way
* to compare the list before and after a call.
capture program drop _tvp_framelist
program define _tvp_framelist, rclass
    version 16.0
    mata: st_local("_fl", invtokens(sort(st_framedir(), 1)'))
    return local frames "`_fl'"
end

**# ---------------------------------------------------------------------
**# Fixtures. Built at top level: an `input' block inside `program define'
**# would end the program at its own `end'.
**# ---------------------------------------------------------------------
clear
input long pid double study_entry double study_exit byte sex
    1 100 500 1
    2 120 480 0
    3  90 500 1
    4 200 460 0
end
label variable pid "Person identifier"
save "tp_cohort.dta", replace

* Clean, non-overlapping episodes inside every window. Person 4 has none, and
* person 9 is not in the cohort at all: both are legal and both are counted.
clear
input long pid double a_start double a_stop byte drug
    1 150 199 1
    1 250 299 2
    2 130 200 1
    3 100 400 2
    3  90  95 1
    9 100 200 1
end
save "tp_epi.dta", replace

* Same episodes plus one row wholly after person 1's exit: reported, ignored.
clear
input long pid double a_start double a_stop byte drug
    1 150 199 1
    1 600 700 2
    2 130 200 1
    3 100 400 2
    4 250 300 1
end
save "tp_epi_outside.dta", replace

* Two clipped episodes that share a closed endpoint.
clear
input long pid double a_start double a_stop byte drug
    1 150 250 1
    1 250 300 2
    2 130 200 1
    3 100 400 2
    4 250 300 1
end
save "tp_epi_overlap.dta", replace

* One retained episode coded to the reference category.
clear
input long pid double a_start double a_stop byte drug
    1 150 199 0
    2 130 200 1
    3 100 400 2
    4 250 300 1
end
save "tp_epi_ref.dta", replace

* A fractional daily date.
clear
input long pid double a_start double a_stop byte drug
    1 150.5 199 1
    2 130 200 1
    3 100 400 2
    4 250 300 1
end
save "tp_epi_frac.dta", replace

* A second raw source, for multi-source plans.
clear
input long pid double b_start double b_stop byte care
    1 100 300 1
    2 150 250 1
    3 200 260 2
    4 210 220 1
end
save "tp_epi2.dta", replace

* A ready interval source covering every person's whole window, with a rate
* payload that carries the characteristic its declaration will claim.
clear
input long pid double start double stop double egfr
    1 100 300 60
    1 301 500 55
    2 120 480 70
    3  90 500 45
    4 200 460 80
end
char egfr[tvtools_quantity] "rate"
save "tp_iv.dta", replace

* The same source with a hole in person 2's window.
clear
input long pid double start double stop double egfr
    1 100 500 60
    2 120 300 70
    3  90 500 45
    4 200 460 80
end
char egfr[tvtools_quantity] "rate"
save "tp_iv_gap.dta", replace

* Ready intervals whose payload does NOT carry the declared characteristic.
clear
input long pid double start double stop double egfr
    1 100 500 60
    2 120 480 70
    3  90 500 45
    4 200 460 80
end
save "tp_iv_nochar.dta", replace

* Event data keyed on the same identifier.
clear
input long pid double evt_dt double comp_dt
    1 260 .
    2 . 300
    3 450 .
    4 . .
end
save "tp_evt.dta", replace

* String-identified cohort and source.
clear
input str8 pid double study_entry double study_exit
    "a" 100 500
    "b" 120 480
end
save "tp_cohort_s.dta", replace
clear
input str8 pid double a_start double a_stop byte drug
    "a" 150 199 1
    "b" 130 200 1
end
save "tp_epi_s.dta", replace

* Not a Stata dataset.
capture erase "tp_notadta.dta"
tempname fh
file open `fh' using "tp_notadta.dta", write text replace
file write `fh' "this is not a Stata dataset" _n
file close `fh'

* Frame-resident copies of two sources.
capture frame drop epi_fr
frame create epi_fr
frame epi_fr: use "tp_epi.dta", clear
capture frame drop iv_fr
frame create iv_fr
frame iv_fr: use "tp_iv.dta", clear
capture frame drop evt_fr
frame create evt_fr
frame evt_fr: use "tp_evt.dta", clear

* One-row specification frame, matching the inline call exactly.
capture frame drop spec1
frame create spec1
frame change spec1
input str32 source_name str12 source_kind str32 source_frame strL source_file ///
    str32 start_var str32 stop_var strL input_vars strL output_vars double reference
    "tv_drug" "episodes" "" "tp_epi.dta" "a_start" "a_stop" "drug" "tv_drug" 0
end
frame change default

* Two-source specification: one raw, one ready.
capture frame drop spec2
frame create spec2
frame change spec2
input str32 source_name str12 source_kind str32 source_frame strL source_file ///
    str32 start_var str32 stop_var strL input_vars strL output_vars double reference ///
    strL rate_vars
    "drug"  "episodes"  "" "tp_epi.dta" "a_start" "a_stop" "drug" "tv_drug" 0 ""
    "renal" "intervals" "" "tp_iv.dta"  "start"   "stop"   "egfr" "egfr_out" . "egfr"
end
frame change default

* Three rows, two of which share one file locator with distinct mappings.
capture frame drop spec3
frame create spec3
frame change spec3
input str32 source_name str12 source_kind str32 source_frame strL source_file ///
    str32 start_var str32 stop_var strL input_vars strL output_vars double reference
    "drug"  "episodes" "" "tp_epi.dta"  "a_start" "a_stop" "drug" "tv_drug" 0
    "care"  "episodes" "" "tp_epi2.dta" "b_start" "b_stop" "care" "tv_care" 0
    "drug2" "episodes" "" "tp_epi.dta"  "a_start" "a_stop" "drug" "tv_drug2" 0
end
frame change default

* Baseline call macros, so a test changes one thing at a time.
local BASE `"id(pid) entry(study_entry) exit(study_exit) frameout(analysis) dryrun"'
local INLINE `"sourceusing("tp_epi.dta") start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug)"'

**# ---------------------------------------------------------------------
**# P: both input forms
**# ---------------------------------------------------------------------
local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, `INLINE' `BASE'
local rc = _rc
local ok = (`rc' == 0)
_tvp_check `ok' "P1 the inline file form dry-runs clean" "rc=`rc'"

local in_np      = r(N_persons)
local in_ns      = r(n_sources)
local in_sv      = "`r(startvar)'"
local in_payload = "`r(payload_vars)'"
local in_expo    = "`r(exposure_vars)'"
local in_names   = "`r(source_names)'"
local in_cov     = "`r(coverage)'"
local in_dry     = r(dryrun)
matrix in_counts = r(source_counts)

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, sourceframe(epi_fr) start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) `BASE'
local rc = _rc
local ok = (`rc' == 0)
_tvp_check `ok' "P2 the inline frame form dry-runs clean" "rc=`rc'"

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, specframe(spec1) `BASE'
local rc = _rc
local sp_np      = r(N_persons)
local sp_ns      = r(n_sources)
local sp_sv      = "`r(startvar)'"
local sp_payload = "`r(payload_vars)'"
local sp_expo    = "`r(exposure_vars)'"
local sp_names   = "`r(source_names)'"
local sp_cov     = "`r(coverage)'"
matrix sp_counts = r(source_counts)
local same = (`rc' == 0 & `in_np' == `sp_np' & `in_ns' == `sp_ns' & ///
    "`in_sv'" == "`sp_sv'" & "`in_payload'" == "`sp_payload'" & ///
    "`in_expo'" == "`sp_expo'" & "`in_names'" == "`sp_names'" & ///
    "`in_cov'" == "`sp_cov'" & mreldif(in_counts, sp_counts) == 0)
_tvp_check `same' ///
    "P3 the inline and one-row specframe forms produce the same plan" ///
    "rc=`rc'; inline(`in_np',`in_ns',`in_payload') spec(`sp_np',`sp_ns',`sp_payload')"

* P4 is the reason P3 is not enough: a normalizer bug shared by both forms
* makes P3 pass while both plans are wrong. These are hand-written values.
local ++test_count
matrix expect = (6, 4, 1, 0, 1, 2)
local ok = (`in_np' == 4 & `in_ns' == 1 & "`in_payload'" == "tv_drug" & ///
    "`in_expo'" == "tv_drug" & "`in_names'" == "tv_drug" & ///
    "`in_cov'" == "strict" & `in_dry' == 1 & ///
    mreldif(in_counts, expect) == 0)
_tvp_check `ok' ///
    "P4 the inline plan matches a hand-written expected plan" ///
    "N_persons=`in_np' n_sources=`in_ns' payload=`in_payload' counts=`=in_counts[1,1]',`=in_counts[1,2]',`=in_counts[1,3]',`=in_counts[1,4]',`=in_counts[1,5]',`=in_counts[1,6]'"

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, specframe(spec2) `BASE'
local rc = _rc
local ok = (`rc' == 0 & r(n_sources) == 2 & ///
    "`r(payload_vars)'" == "tv_drug egfr_out" & ///
    "`r(rate_vars)'" == "egfr_out" & "`r(exposure_vars)'" == "tv_drug")
_tvp_check `ok' ///
    "P5 a two-source plan classifies its payload by declared algebra" ///
    "rc=`rc' n=`=r(n_sources)' payload=`r(payload_vars)' rate=`r(rate_vars)' expo=`r(exposure_vars)'"

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, specframe(spec3) `BASE'
local rc = _rc
local nf_ok = (`rc' == 0 & r(n_sources) == 3)
_tvp_check `nf_ok' "P6 a three-source plan with a repeated locator dry-runs clean" ///
    "rc=`rc' n=`=r(n_sources)'"

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, `INLINE' id(pid) entry(study_entry) exit(study_exit) ///
    frameout(analysis) keepvars(sex) startname(t0) stopname(t1) ///
    dateformat(%td) dropdates dryrun
local rc = _rc
local ok = (`rc' == 0 & "`r(startvar)'" == "t0" & "`r(stopvar)'" == "t1" & ///
    r(dates_kept) == 0)
_tvp_check `ok' ///
    "P7 startname/stopname/dropdates/keepvars are honoured in the plan" ///
    "rc=`rc' start=`r(startvar)' stop=`r(stopvar)' dates_kept=`=r(dates_kept)'"

local ++test_count
use "tp_cohort_s.dta", clear
capture noisily tvpipe, sourceusing("tp_epi_s.dta") start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) ///
    id(pid) entry(study_entry) exit(study_exit) frameout(analysis) dryrun
local rc = _rc
local ok = (`rc' == 0 & r(N_persons) == 2)
_tvp_check `ok' "P8 a fixed-width string identifier is accepted" ///
    "rc=`rc' persons=`=r(N_persons)'"

**# ---------------------------------------------------------------------
**# R: refusals. Each one is a plan a real preflight must reject.
**# ---------------------------------------------------------------------
capture program drop _tvp_refuse
program define _tvp_refuse, rclass
    version 16.0
    args expected label opts
    quietly use "tp_cohort.dta", clear
    capture tvpipe, `opts'
    return scalar rc = _rc
    return scalar ok = (_rc == `expected')
end

capture program drop _tvp_refusal
program define _tvp_refusal
    version 16.0
    args n expected label opts
    _tvp_refuse `expected' "`label'" `"`opts'"'
    local rc = r(rc)
    local ok = r(ok)
    _tvp_check `ok' "R`n' `label'" "rc=`rc', expected `expected'"
end

local ++test_count
_tvp_refusal 1 198 "specframe() combined with an inline option is refused" ///
    `"specframe(spec1) start(a_start) `BASE'"'
local ++test_count
_tvp_refusal 2 198 "neither input form is refused" `"`BASE'"'
local ++test_count
_tvp_refusal 3 198 "both sourceframe() and sourceusing() is refused" ///
    `"sourceframe(epi_fr) sourceusing("tp_epi.dta") start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug) `BASE'"'
local ++test_count
_tvp_refusal 4 198 "the inline form without reference() is refused" ///
    `"sourceusing("tp_epi.dta") start(a_start) stop(a_stop) exposure(drug) generate(tv_drug) `BASE'"'
local ++test_count
_tvp_refusal 5 111 "a missing specframe() is refused" ///
    `"specframe(no_such_frame) `BASE'"'
local ++test_count
_tvp_refusal 6 198 "coverage() outside strict|allow is refused" ///
    `"`INLINE' `BASE' coverage(loose)"'
local ++test_count
_tvp_refusal 7 198 "an invalid dateformat() is refused" ///
    `"`INLINE' `BASE' dateformat(%tcnonsense)"'
local ++test_count
* startname() colliding with id(): a legal Stata name, refused by tvpipe's
* output-name planner rather than by `syntax'. A syntactically illegal name
* would be rejected by Stata's own parser and would test nothing of tvpipe's.
_tvp_refusal 8 198 "a startname() colliding with id() is refused" ///
    `"`INLINE' `BASE' startname(pid)"'

* Specification-schema refusals.
capture frame drop spec_bad
frame create spec_bad
frame change spec_bad
input str32 source_name str12 source_kind str32 source_frame strL source_file ///
    str32 start_var str32 stop_var strL input_vars strL output_vars
    "drug" "episodes" "" "tp_epi.dta" "a_start" "a_stop" "drug" "tv_drug"
end
frame change default
local ++test_count
_tvp_refusal 9 111 "a specframe missing a required column is refused" ///
    `"specframe(spec_bad) `BASE'"'

capture frame drop spec_unk
frame copy spec1 spec_unk
frame spec_unk: quietly generate strL total_var = ""
local ++test_count
_tvp_refusal 10 198 "an unknown specframe column is refused" ///
    `"specframe(spec_unk) `BASE'"'

capture frame drop spec_type
frame copy spec1 spec_type
frame spec_type: quietly drop reference
frame spec_type: quietly generate str4 reference = "0"
local ++test_count
_tvp_refusal 11 109 "a specframe column of the wrong storage class is refused" ///
    `"specframe(spec_type) `BASE'"'

capture frame drop spec_ver
frame copy spec1 spec_ver
frame spec_ver: char _dta[tvpipe_spec_version] "2"
local ++test_count
_tvp_refusal 12 198 "an unsupported specification version is refused" ///
    `"specframe(spec_ver) `BASE'"'

capture frame drop spec_v1
frame copy spec1 spec_v1
frame spec_v1: char _dta[tvpipe_spec_version] "1"
local ++test_count
use "tp_cohort.dta", clear
capture tvpipe, specframe(spec_v1) `BASE'
local rc = _rc
local ok = (`rc' == 0)
_tvp_check `ok' "R13 an explicit version-1 characteristic is accepted" "rc=`rc'"

capture frame drop spec_wild
frame copy spec1 spec_wild
frame spec_wild: quietly replace input_vars = "dr*"
local ++test_count
_tvp_refusal 14 198 "a wildcard in a specification list cell is refused" ///
    `"specframe(spec_wild) `BASE'"'

capture frame drop spec_len
frame copy spec1 spec_len
frame spec_len: quietly replace output_vars = "a b"
local ++test_count
_tvp_refusal 15 198 "unequal input_vars/output_vars counts are refused" ///
    `"specframe(spec_len) `BASE'"'

capture frame drop spec_dupn
frame copy spec3 spec_dupn
frame spec_dupn: quietly replace source_name = "drug" in 3
local ++test_count
_tvp_refusal 16 198 "a repeated source_name is refused" ///
    `"specframe(spec_dupn) `BASE'"'

capture frame drop spec_dupo
frame copy spec3 spec_dupo
frame spec_dupo: quietly replace output_vars = "tv_drug" in 3
local ++test_count
_tvp_refusal 17 198 "a repeated output name across sources is refused" ///
    `"specframe(spec_dupo) `BASE'"'

capture frame drop spec_q
frame copy spec2 spec_q
frame spec_q: quietly replace rate_vars = "not_declared" in 2
local ++test_count
_tvp_refusal 18 198 "a quantity variable absent from input_vars is refused" ///
    `"specframe(spec_q) `BASE'"'

capture frame drop spec_qq
frame copy spec2 spec_qq
frame spec_qq: quietly generate strL total_vars = ""
frame spec_qq: quietly replace total_vars = "egfr" in 2
local ++test_count
_tvp_refusal 19 198 "the same variable declared rate and total is refused" ///
    `"specframe(spec_qq) `BASE'"'

capture frame drop spec_epi2
frame copy spec2 spec_epi2
frame spec_epi2: quietly replace input_vars = "drug a_start" in 1
local ++test_count
_tvp_refusal 20 198 "an episodes row with two input variables is refused" ///
    `"specframe(spec_epi2) `BASE'"'

capture frame drop spec_ivref
frame copy spec2 spec_ivref
frame spec_ivref: quietly replace reference = 0 in 2
local ++test_count
_tvp_refusal 21 198 "an intervals row carrying a reference is refused" ///
    `"specframe(spec_ivref) `BASE'"'

**# ---------------------------------------------------------------------
**# Master, locator, and source data refusals
**# ---------------------------------------------------------------------
capture program drop _tvp_refuse_data
program define _tvp_refuse_data, rclass
    version 16.0
    args cohort expected opts
    quietly use "`cohort'", clear
    capture tvpipe, `opts'
    return scalar rc = _rc
    return scalar ok = (_rc == `expected')
end

local ++test_count
quietly use "tp_cohort.dta", clear
quietly expand 2 in 1
capture tvpipe, `INLINE' `BASE'
local rc = _rc
local ok = (`rc' == 459)
_tvp_check `ok' "R22 a duplicate master id is refused with r(459)" "rc=`rc'"

local ++test_count
quietly use "tp_cohort.dta", clear
quietly replace study_entry = . in 2
capture tvpipe, `INLINE' `BASE'
local rc = _rc
local ok = (`rc' == 498)
_tvp_check `ok' "R23 a missing master entry date is refused with r(498)" "rc=`rc'"

local ++test_count
quietly use "tp_cohort.dta", clear
quietly generate strL pid_l = string(pid)
capture tvpipe, sourceusing("tp_epi.dta") start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) ///
    id(pid_l) entry(study_entry) exit(study_exit) frameout(analysis) dryrun
local rc = _rc
local ok = (`rc' == 109)
_tvp_check `ok' "R24 a strL identifier is refused with r(109)" "rc=`rc'"

local ++test_count
_tvp_refuse_data "tp_cohort.dta" 106 ///
    `"sourceusing("tp_epi_s.dta") start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' "R25 a string source id against a numeric master is r(106)" "rc=`rc'"

local ++test_count
_tvp_refuse_data "tp_cohort.dta" 601 ///
    `"sourceusing("tp_no_such_file.dta") start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' "R26 a missing source file is r(601)" "rc=`rc'"

local ++test_count
_tvp_refuse_data "tp_cohort.dta" 610 ///
    `"sourceusing("tp_notadta.dta") start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' "R27 a file that is not a Stata dataset is r(610)" "rc=`rc'"

local ++test_count
_tvp_refuse_data "tp_cohort.dta" 111 ///
    `"sourceframe(no_such_frame) start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' "R28 a missing source frame is r(111)" "rc=`rc'"

local ++test_count
_tvp_refuse_data "tp_cohort.dta" 111 ///
    `"sourceusing("tp_epi.dta") start(a_start) stop(a_stop) exposure(no_such_var) reference(0) generate(tv_drug) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' "R29 a declared source variable that does not exist is r(111)" "rc=`rc'"

local ++test_count
_tvp_refuse_data "tp_cohort.dta" 459 ///
    `"sourceusing("tp_epi_overlap.dta") start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' ///
    "R30 clipped episodes sharing a closed endpoint are r(459)" "rc=`rc'"

local ++test_count
_tvp_refuse_data "tp_cohort.dta" 459 ///
    `"sourceusing("tp_epi_ref.dta") start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' "R31 a retained episode coded to reference() is r(459)" "rc=`rc'"

local ++test_count
_tvp_refuse_data "tp_cohort.dta" 498 ///
    `"sourceusing("tp_epi_frac.dta") start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' "R32 a fractional daily date is r(498)" "rc=`rc'"

capture frame drop spec_gap
frame copy spec2 spec_gap
frame spec_gap: quietly replace source_file = "tp_iv_gap.dta" in 2
local ++test_count
_tvp_refuse_data "tp_cohort.dta" 459 `"specframe(spec_gap) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' ///
    "R33 an uncovered ready interval source under coverage(strict) is r(459)" "rc=`rc'"

local ++test_count
quietly use "tp_cohort.dta", clear
capture tvpipe, specframe(spec_gap) `BASE' coverage(allow)
local rc = _rc
local gaps = r(n_gap_ids)
local ok = (`rc' == 0 & "`r(coverage)'" == "allow")
_tvp_check `ok' ///
    "R34 the same gap under coverage(allow) is accepted and recorded" ///
    "rc=`rc' coverage=`r(coverage)'"

capture frame drop spec_nochar
frame copy spec2 spec_nochar
frame spec_nochar: quietly replace source_file = "tp_iv_nochar.dta" in 2
local ++test_count
_tvp_refuse_data "tp_cohort.dta" 498 `"specframe(spec_nochar) `BASE'"'
local ok = r(ok)
local rc = r(rc)
_tvp_check `ok' ///
    "R35 a quantity declaration the data do not carry is r(498)" "rc=`rc'"

**# ---------------------------------------------------------------------
**# E: event stage
**# ---------------------------------------------------------------------
local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, `INLINE' `BASE'
local ok = (r(event_stage) == 0)
_tvp_check `ok' "E1 a plan with no eventdate() has no event stage" ///
    "event_stage=`=r(event_stage)'"

local ++test_count
use "tp_evt.dta", clear
quietly merge 1:1 pid using "tp_cohort.dta", nogenerate
capture noisily tvpipe, `INLINE' id(pid) entry(study_entry) exit(study_exit) ///
    frameout(analysis) eventdate(evt_dt) compete(comp_dt) dryrun
local rc = _rc
local ok = (`rc' == 0 & r(event_stage) == 1 & "`r(eventvar)'" == "_failure")
_tvp_check `ok' "E2 event variables read from the master dry-run clean" ///
    "rc=`rc' stage=`=r(event_stage)' eventvar=`r(eventvar)'"

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, `INLINE' `BASE' eventframe(evt_fr) eventdate(evt_dt) ///
    eventgenerate(died) timegen(t_elapsed) timeunit(years)
local rc = _rc
local ok = (`rc' == 0 & "`r(eventvar)'" == "died" & "`r(timevar)'" == "t_elapsed")
_tvp_check `ok' "E3 a separate event frame dry-runs clean" ///
    "rc=`rc' eventvar=`r(eventvar)' timevar=`r(timevar)'"

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, `INLINE' `BASE' eventusing("tp_evt.dta") eventdate(evt_dt)
local rc = _rc
local ok = (`rc' == 0)
_tvp_check `ok' "E4 a separate event file dry-runs clean" "rc=`rc'"

local ++test_count
_tvp_refusal 36 198 "an event option without eventdate() is refused" ///
    `"`INLINE' `BASE' eventgenerate(died)"'

local ++test_count
_tvp_refusal 37 198 "eventframe() with eventusing() is refused" ///
    `"`INLINE' `BASE' eventdate(evt_dt) eventframe(evt_fr) eventusing("tp_evt.dta")"'

local ++test_count
_tvp_refusal 38 198 "compete() with eventtype(recurring) is refused" ///
    `"`INLINE' `BASE' eventframe(evt_fr) eventdate(evt_dt) eventtype(recurring) compete(comp_dt)"'

local ++test_count
_tvp_refusal 39 198 "enum() with eventtype(single) is refused" ///
    `"`INLINE' `BASE' eventframe(evt_fr) eventdate(evt_dt) enum(k)"'

**# ---------------------------------------------------------------------
**# D: destination ownership
**# ---------------------------------------------------------------------
local ++test_count
_tvp_refusal 40 198 "frameout() naming the caller frame is refused" ///
    `"`INLINE' id(pid) entry(study_entry) exit(study_exit) frameout(default) dryrun"'

local ++test_count
_tvp_refusal 41 198 "frameout() naming the specification frame is refused" ///
    `"specframe(spec1) id(pid) entry(study_entry) exit(study_exit) frameout(spec1) dryrun"'

local ++test_count
_tvp_refusal 42 198 "frameout() naming an input source frame is refused" ///
    `"sourceframe(epi_fr) start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug) id(pid) entry(study_entry) exit(study_exit) frameout(epi_fr) dryrun"'

local ++test_count
_tvp_refusal 43 198 "manifestframe() equal to frameout() is refused" ///
    `"`INLINE' `BASE' manifestframe(analysis)"'

capture frame drop analysis
frame create analysis
local ++test_count
_tvp_refusal 44 110 "an existing frameout() without replace is r(110)" ///
    `"`INLINE' `BASE'"'

local ++test_count
use "tp_cohort.dta", clear
capture tvpipe, `INLINE' `BASE' replace
local rc = _rc
local ok = (`rc' == 0)
_tvp_check `ok' "D5 replace authorizes an existing frameout()" "rc=`rc'"
capture frame drop analysis

local ++test_count
_tvp_refusal 45 198 "a keepvar colliding with a source output is refused" ///
    `"sourceusing("tp_epi.dta") start(a_start) stop(a_stop) exposure(drug) reference(0) generate(sex) keepvars(sex) `BASE'"'

local ++test_count
use "tp_evt.dta", clear
quietly merge 1:1 pid using "tp_cohort.dta", nogenerate
capture tvpipe, sourceusing("tp_epi.dta") start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(evt_dt) ///
    id(pid) entry(study_entry) exit(study_exit) frameout(analysis) ///
    eventdate(evt_dt) dryrun
local rc = _rc
local ok = (`rc' == 198)
_tvp_check `ok' ///
    "D7 an output name that would overwrite the event date is refused" "rc=`rc'"

**# ---------------------------------------------------------------------
**# C: the counts the plan reports
**# ---------------------------------------------------------------------
local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, `INLINE' `BASE'
matrix c1 = r(source_counts)
local ok = (c1[1,1] == 6 & c1[1,2] == 4 & c1[1,3] == 1)
_tvp_check `ok' ///
    "C1 rows, source persons, and unmatched ids are counted" ///
    "rows=`=c1[1,1]' persons=`=c1[1,2]' unmatched=`=c1[1,3]'"

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, sourceusing("tp_epi_outside.dta") start(a_start) ///
    stop(a_stop) exposure(drug) reference(0) generate(tv_drug) `BASE'
matrix c2 = r(source_counts)
local rc = _rc
local ok = (`rc' == 0 & c2[1,4] == 1)
_tvp_check `ok' ///
    "C2 an episode wholly outside its person's window is counted, not fatal" ///
    "rc=`rc' outside=`=c2[1,4]'"

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, specframe(spec2) `BASE'
matrix c3 = r(source_counts)
local ok = (c3[1,5] == 1 & c3[2,5] == 2 & c3[1,6] == 2 & c3[2,6] == 2)
_tvp_check `ok' ///
    "C3 the kind and input codings distinguish the two source classes" ///
    "kind=`=c3[1,5]',`=c3[2,5]' input=`=c3[1,6]',`=c3[2,6]'"

local ++test_count
use "tp_cohort.dta", clear
capture noisily tvpipe, sourceframe(epi_fr) start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) `BASE'
matrix c4 = r(source_counts)
local ok = (c4[1,6] == 1)
_tvp_check `ok' "C4 a frame source is coded input==1" "input=`=c4[1,6]'"

**# ---------------------------------------------------------------------
**# S: session state. A dry run promises to change nothing.
**# ---------------------------------------------------------------------
use "tp_cohort.dta", clear
sort study_entry
quietly datasignature
local before_sig "`r(datasignature)'"
quietly ds
local before_vars "`r(varlist)'"
local before_sortedby : sortedby
local before_frame "`c(frame)'"
local before_abbrev "`c(varabbrev)'"
_tvp_framelist
local before_frames "`r(frames)'"
quietly label dir
local before_labels "`r(names)'"
quietly regress study_exit study_entry
local before_e "`e(cmd)' `=e(N)'"

capture noisily tvpipe, `INLINE' `BASE'
local rc = _rc

local ++test_count
quietly datasignature
local after_sig "`r(datasignature)'"
quietly ds
local after_vars "`r(varlist)'"
local after_sortedby : sortedby
local ok = ("`after_sig'" == "`before_sig'" & "`after_vars'" == "`before_vars'" & ///
    "`after_sortedby'" == "`before_sortedby'")
_tvp_check `ok' ///
    "S1 a successful dry run leaves the caller's data byte-identical" ///
    "sig=`after_sig'/`before_sig' vars=`after_vars' sortedby=`after_sortedby'/`before_sortedby'"

local ++test_count
_tvp_framelist
local after_frames "`r(frames)'"
local ok = ("`after_frames'" == "`before_frames'")
_tvp_check `ok' "S2 a successful dry run leaves no scratch frame behind" ///
    "after=`after_frames'; before=`before_frames'"

local ++test_count
quietly label dir
local after_labels "`r(names)'"
local ok = ("`after_labels'" == "`before_labels'")
_tvp_check `ok' "S3 a dry run defines no value label" ///
    "after=`after_labels'; before=`before_labels'"

local ++test_count
local ok = ("`c(frame)'" == "`before_frame'" & "`c(varabbrev)'" == "`before_abbrev'")
_tvp_check `ok' "S4 the caller frame and c(varabbrev) are restored" ///
    "frame=`c(frame)'/`before_frame' varabbrev=`c(varabbrev)'/`before_abbrev'"

local ++test_count
local after_e "`e(cmd)' `=e(N)'"
local ok = ("`after_e'" == "`before_e'")
_tvp_check `ok' "S5 active e() survives a dry run" ///
    "after=`after_e'; before=`before_e'"

* The failure paths are where a half-built scratch frame survives, so they get
* their own frame-list assertion rather than sharing S2's.
local ++test_count
use "tp_cohort.dta", clear
_tvp_framelist
local before_frames "`r(frames)'"
capture tvpipe, sourceusing("tp_epi_overlap.dta") start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) `BASE'
local rc = _rc
_tvp_framelist
local after_frames "`r(frames)'"
local ok = (`rc' == 459 & "`after_frames'" == "`before_frames'")
_tvp_check `ok' ///
    "S6 a preflight failure leaves no scratch frame behind" ///
    "rc=`rc'; after=`after_frames'; before=`before_frames'"

local ++test_count
use "tp_cohort.dta", clear
_tvp_framelist
local before_frames "`r(frames)'"
capture tvpipe, sourceusing("tp_notadta.dta") start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) `BASE'
local rc = _rc
_tvp_framelist
local after_frames "`r(frames)'"
local ok = (`rc' == 610 & "`after_frames'" == "`before_frames'" & ///
    "`c(frame)'" == "default")
_tvp_check `ok' ///
    "S7 a failure while a source frame is current still restores the caller" ///
    "rc=`rc'; frame=`c(frame)'; after=`after_frames'"

local ++test_count
frame epi_fr: quietly datasignature
local src_before "`r(datasignature)'"
use "tp_cohort.dta", clear
capture tvpipe, sourceframe(epi_fr) start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) `BASE'
frame epi_fr: quietly datasignature
local src_after "`r(datasignature)'"
local ok = ("`src_after'" == "`src_before'")
_tvp_check `ok' "S8 an input source frame is not modified" ///
    "after=`src_after'; before=`src_before'"

local ++test_count
use "tp_cohort.dta", clear
capture tvpipe, `INLINE' `BASE'
local rc1 = _rc
capture tvpipe, `INLINE' `BASE'
local rc2 = _rc
local ok = (`rc1' == 0 & `rc2' == 0)
_tvp_check `ok' "S9 a repeated invocation succeeds" "rc1=`rc1' rc2=`rc2'"

* A clean dry run is a statement about the data as they stand, never an
* authorization. Mutate the source and the next call must catch it.
local ++test_count
quietly use "tp_epi.dta", clear
quietly save "tp_epi_mut.dta", replace
use "tp_cohort.dta", clear
capture tvpipe, sourceusing("tp_epi_mut.dta") start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) `BASE'
local clean_rc = _rc
quietly use "tp_epi_mut.dta", clear
quietly replace a_stop = 400 in 1
quietly save "tp_epi_mut.dta", replace
use "tp_cohort.dta", clear
capture tvpipe, sourceusing("tp_epi_mut.dta") start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) generate(tv_drug) `BASE'
local mut_rc = _rc
local ok = (`clean_rc' == 0 & `mut_rc' == 459)
_tvp_check `ok' ///
    "S10 a source mutated after a clean plan is caught by the next call" ///
    "clean_rc=`clean_rc' mutated_rc=`mut_rc'"

* The dry run and the real run differ in exactly one observable way: the real
* one has a destination afterwards. Asserting that here, from the same fixture
* and the same options, is what proves `dryrun' is a mode of this command
* rather than a separate code path that happens to agree with it.
local ++test_count
capture frame drop analysis
use "tp_cohort.dta", clear
_tvp_framelist
local before_frames "`r(frames)'"
capture tvpipe, `INLINE' id(pid) entry(study_entry) exit(study_exit) ///
    frameout(analysis) dryrun
local dry_rc = _rc
capture confirm frame analysis
local dry_no_dest = (_rc != 0)
_tvp_framelist
local after_dry "`r(frames)'"
capture tvpipe, `INLINE' id(pid) entry(study_entry) exit(study_exit) ///
    frameout(analysis)
local real_rc = _rc
capture confirm frame analysis
local real_dest = (_rc == 0)
local ok = (`dry_rc' == 0 & `dry_no_dest' & "`after_dry'" == "`before_frames'" ///
    & `real_rc' == 0 & `real_dest')
_tvp_check `ok' ///
    "S11 dryrun leaves no destination where the identical real run creates one" ///
    "dry_rc=`dry_rc' dry_absent=`dry_no_dest' real_rc=`real_rc' real_dest=`real_dest'"
capture frame drop analysis

* Section 6.6 of the plan: after installation and `discard', every ado helper
* must resolve and one public helper-dependent path must run, with no
* development adopath in play. The whole suite runs against the sandboxed
* install, so this is the discard half.
local ++test_count
discard
local resolved = 1
foreach h in tvpipe _tvpipe_normalize_spec _tvpipe_preflight ///
    _tvpipe_load_source _tvpipe_carry_meta _tvpipe_build_source ///
    _tvpipe_combine _tvpipe_event _tvpipe_finalize _tvpipe_manifest ///
    _tvpipe_commit {
    capture which `h'
    if _rc local resolved = 0
}
use "tp_cohort.dta", clear
capture frame drop analysis
capture tvpipe, `INLINE' `BASE'
local after_discard_rc = _rc
local ok = (`resolved' & `after_discard_rc' == 0)
_tvp_check `ok' ///
    "S12 every helper resolves and a plan runs after discard" ///
    "resolved=`resolved' rc=`after_discard_rc'"

**# Cleanup
foreach f in tp_cohort tp_epi tp_epi_outside tp_epi_overlap tp_epi_ref ///
    tp_epi_frac tp_epi2 tp_iv tp_iv_gap tp_iv_nochar tp_evt tp_cohort_s ///
    tp_epi_s tp_notadta tp_epi_mut {
    capture erase "`f'.dta"
}

**# Summary
local pass_count = $TVP_PASS
local fail_count = $TVP_FAIL
display "RESULT: test_tvpipe_dryrun tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "tvpipe dry-run failures:$TVP_FAILED"
    exit 1
}
