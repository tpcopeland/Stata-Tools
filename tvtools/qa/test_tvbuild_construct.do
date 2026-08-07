*! test_tvbuild_construct.do
*! Phase 4B contract pins for tvbuild: construction, alignment, coverage, schema.
*!
*! Phase 4A stopped at the plan. This suite covers everything from the first
*! construction kernel to the finalised scratch result: raw episodes tiled by
*! the shared tvexpose constructor, ready interval sources normalised, one or
*! more of them aligned by the shared tvmerge engine, the coverage policies,
*! the master payload attached once, and the committed schema and metadata.
*! Events, provenance, and the transaction are test_tvbuild_commit.do.
*!
*! The three tvbuild-specific false greens this suite is written against:
*!
*!   1. "tvbuild called only the legacy public wrappers, or never dispatched an
*!      engine at all." Values alone cannot tell those apart from a correct
*!      run. B1-B7 compare against the frozen primitive sequence -- tvexpose,
*!      then tvmerge -- so an answer that is right for a different reason still
*!      has to be right. B12 pins the engine label the plan frame recorded, and
*!      X1-X2 pin that a frame source is read and never written, which the
*!      wrapper path could not satisfy: tvexpose takes a `using' file.
*!
*!   2. "Both input forms share one normaliser bug and therefore agree." B3
*!      compares inline against a one-row specframe, which on its own passes
*!      while both are wrong. B4 compares BOTH of them against a fixed expected
*!      table written out by hand from the interval arithmetic.
*!
*!   3. "The values matched while something else drifted." M1-M9 assert the
*!      variable order, storage types, formats, variable labels, value-label
*!      assignments AND definitions, characteristics, and the dataset label as
*!      separate categories, because datasignature sees none of them. S1-S5
*!      assert the counts and the return surface. X3 asserts the source frames
*!      and the caller are unchanged.
*!
*! Axes probed:
*!   B1-B15   construction and alignment against the frozen primitive sequence
*!   Q1-Q6    rate / interval-total / cumulative algebra through the merge
*!   C1-C6    strict and allow coverage, and the zero-result refusals
*!   M1-M11   committed order, metadata categories, and internal-name absence
*!   S1-S6    stage counts, source counts, and the real-run return surface
*!   X1-X4    input frames read-only, no working-directory artefact, repeat runs

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvbuild_construct.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVB_PASS = 0
global TVB_FAIL = 0
global TVB_FAILED ""
local test_count = 0

display as result "tvtools QA: tvbuild construction (Phase 4B) -- $S_DATE $S_TIME"

capture program drop _tvb_check
program define _tvb_check
    args ok label detail
    if `ok' {
        global TVB_PASS = $TVB_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVB_FAIL = $TVB_FAIL + 1
        global TVB_FAILED "$TVB_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

* Compare the current frame against a saved oracle on the listed variables.
* `cf' is used rather than a value-by-value loop because it compares storage
* content, and it is given an explicit variable list so a schema difference is
* reported by its own check rather than hidden inside this one.
capture program drop _tvb_cf
program define _tvb_cf, rclass
    version 16.0
    syntax varlist using/
    keep `varlist'
    order `varlist'
    sort `varlist'
    capture cf _all using `"`using'"'
    return scalar rc = _rc
end

capture program drop _tvb_framelist
program define _tvb_framelist, rclass
    version 16.0
    mata: st_local("_fl", invtokens(sort(st_framedir(), 1)'))
    return local frames "`_fl'"
end

**# ---------------------------------------------------------------------
**# Fixtures
**# ---------------------------------------------------------------------
clear
input long pid double study_entry double study_exit byte sex float bmi
    1 100 500 1 22.5
    2 120 480 0 31.0
    3  90 500 1 27.2
    4 200 460 0 19.8
end
label variable pid "Person identifier"
label variable sex "Sex at baseline"
label define tb_sex 0 "Female" 1 "Male"
label values sex tb_sex
label data "Analysis cohort"
save "tb_cohort.dta", replace

* Person 4 has no episode; person 9 is not in the cohort. Both are legal.
clear
input long pid double a_start double a_stop byte drug
    1 150 199 1
    1 250 299 2
    2 130 200 1
    3 100 400 2
    3  90  95 1
    9 100 200 1
end
label variable drug "Drug class"
label define tb_drug 1 "Class A" 2 "Class B"
label values drug tb_drug
save "tb_epi.dta", replace

clear
input long pid double b_start double b_stop byte statin
    1 120 260 1
    2 200 300 1
    3 300 500 1
end
label variable statin "Statin use"
save "tb_epi2.dta", replace

clear
input long pid double c_start double c_stop byte anticoag
    1 400 450 1
    4 210 300 1
end
save "tb_epi3.dta", replace

* Ready intervals covering every master day, with one rate, one interval total,
* and one cumulative history.
clear
input long pid double start double stop byte ckd double egfr double dose double cumdose
    1 100 299 1 90 200 0
    1 300 500 2 70 402 200
    2 120 480 1 85 361 0
    3  90 500 1 88 411 0
    4 200 460 2 60 261 0
end
label variable ckd "CKD stage"
char egfr[tvtools_quantity] "rate"
char dose[tvtools_quantity] "total"
char cumdose[tvtools_quantity] "cumulative"
char cumdose[tvtools_history_point] "start"
save "tb_ready.dta", replace

* Ready intervals with a real gap for person 1.
clear
input long pid double start double stop byte ckd
    1 100 200 1
    1 300 500 2
    2 120 480 1
    3  90 500 1
    4 200 460 1
end
save "tb_gap.dta", replace

* Two sources whose value labels share a NAME but not a definition.
clear
input long pid double d_start double d_stop byte lvl
    1 150 250 1
    2 150 250 1
    3 150 250 1
    4 210 250 1
end
label define tb_shared 1 "First meaning"
label values lvl tb_shared
save "tb_lab1.dta", replace

clear
input long pid double e_start double e_stop byte lvl2
    1 300 400 1
    2 300 400 1
    3 300 400 1
    4 300 400 1
end
label define tb_shared 1 "Second meaning"
label values lvl2 tb_shared
save "tb_lab2.dta", replace

**# ---------------------------------------------------------------------
**# Reusable specification builder
**# ---------------------------------------------------------------------
capture program drop _tvb_spec_new
program define _tvb_spec_new
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

capture program drop _tvb_spec_add
program define _tvb_spec_add
    version 16.0
    syntax , FR(name) NAME(string) KIND(string) ///
        SV(string) PV(string) IV(string) OV(string) ///
        [SFRAME(string) SFILE(string) REF(string) ///
         RV(string) TV(string) CV(string) RLAB(string) VLAB(string)]
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
    quietly replace rate_vars       = "`rv'"   in `n'
    quietly replace total_vars      = "`tv'"   in `n'
    quietly replace cumulative_vars = "`cv'"   in `n'
    quietly replace reference_label = `"`rlab'"' in `n'
    quietly replace variable_label  = `"`vlab'"' in `n'
    quietly replace description     = "fixture" in `n'
    frame change `_here'
end

**# ---------------------------------------------------------------------
**# Result-frame probe guard
**# ---------------------------------------------------------------------
* Every probe of a frame tvbuild was supposed to create goes through this
* first. `capture frame X { ... }' is NOT a guard, and the way it fails is
* worse than no guard at all. Measured directly:
*
*   capture frame nosuchframe {
*       display "running in " c(frame)      // prints: running in default
*       quietly count if pid == 1           // COUNTS THE WRONG DATASET, rc=0
*       local a = r(N)
*   }                                       // "} is not a valid command name"
*
* `capture' swallows the frame-not-found error, the body then executes IN THE
* CURRENT FRAME line by line and UNCAPTURED, and the closing brace is finally
* read as a command and ends the do-file with r(199). So a defect that stops
* tvbuild creating its frame does not merely abort the suite -- if the body
* happens to be legal against the caller's data it first computes an answer
* from the wrong dataset at rc=0.
*
* Confirming the frame is also not enough on its own. An injected defect can
* leave the frame created but wrongly shaped, and `frame X { count if start
* ... }' on a frame with no `start' aborts exactly the same way. vars() is
* therefore checked in the frame before the block is entered.
capture program drop _tvb_ready
program define _tvb_ready, rclass
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
            capture frame change `_here'
        }
    }
    capture frame change `_here'
    return scalar ok = `_ok'
end

**# ---------------------------------------------------------------------
**# B. Construction and alignment against the frozen primitive sequence
**# ---------------------------------------------------------------------

* The oracle: exactly the workflow the documentation tells a user to run by
* hand. tvexpose per raw source into a frame, then tvmerge over those frames.
capture program drop _tvb_oracle2
program define _tvb_oracle2
    version 16.0
    use "tb_cohort.dta", clear
    tvexpose using "tb_epi.dta", id(pid) start(a_start) stop(a_stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug) frameout(tb_o1) replace
    use "tb_cohort.dta", clear
    tvexpose using "tb_epi2.dta", id(pid) start(b_start) stop(b_stop) ///
        exposure(statin) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_statin) frameout(tb_o2) replace
    frame tb_o1: rename (a_start a_stop) (s1 e1)
    frame tb_o2: rename (b_start b_stop) (s2 e2)
    clear
    tvmerge, frames(tb_o1 tb_o2) id(pid) start(s1 s2) stop(e1 e2) ///
        exposure(tv_drug tv_statin) idname(pid) startname(start) ///
        stopname(stop) dateformat(%tdCCYY/NN/DD) frameout(tb_om) replace
end

* B1: one raw source, file locator, against frozen tvexpose.
local ++test_count
use "tb_cohort.dta", clear
tvexpose using "tb_epi.dta", id(pid) start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_drug) frameout(tb_ox) replace
frame tb_ox: rename (a_start a_stop) (start stop)
frame tb_ox {
    keep pid start stop tv_drug
    sort pid start stop
    tempfile b1oracle
    quietly save "`b1oracle'", replace
}
use "tb_cohort.dta", clear
capture tvbuild, sourceusing("tb_epi.dta") id(pid) entry(study_entry) ///
    exit(study_exit) start(a_start) stop(a_stop) exposure(drug) ///
    reference(0) generate(tv_drug) frameout(tb_p1) replace
local b1_rc = _rc
local b1_n = r(N_periods)
frame copy tb_p1 tb_cmp, replace
frame tb_cmp: _tvb_cf pid start stop tv_drug using "`b1oracle'"
local b1_cf = r(rc)
local ok = (`b1_rc' == 0 & `b1_cf' == 0 & `b1_n' == 13)
_tvb_check `ok' ///
    "B1 one raw file source equals the frozen tvexpose result" ///
    "rc=`b1_rc' cf=`b1_cf' n=`b1_n'"

* B2: the same source as a FRAME. tvexpose cannot take one, so a build that
* still matches proves the shared constructor was called directly.
local ++test_count
capture frame drop tb_src
frame create tb_src
frame tb_src: use "tb_epi.dta", clear
use "tb_cohort.dta", clear
capture tvbuild, sourceframe(tb_src) id(pid) entry(study_entry) ///
    exit(study_exit) start(a_start) stop(a_stop) exposure(drug) ///
    reference(0) generate(tv_drug) frameout(tb_p2) replace
local b2_rc = _rc
frame copy tb_p2 tb_cmp, replace
frame tb_cmp: _tvb_cf pid start stop tv_drug using "`b1oracle'"
local b2_cf = r(rc)
local ok = (`b2_rc' == 0 & `b2_cf' == 0)
_tvb_check `ok' ///
    "B2 a frame source builds the same result as the equivalent file source" ///
    "rc=`b2_rc' cf=`b2_cf'"

* B3: inline versus a one-row specframe.
local ++test_count
_tvb_spec_new tb_spec1
_tvb_spec_add, fr(tb_spec1) name(drugsrc) kind(episodes) sfile("tb_epi.dta") ///
    sv(a_start) pv(a_stop) iv(drug) ov(tv_drug) ref(0)
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_spec1) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_p3) replace
local b3_rc = _rc
local b3_sig "`r(datasignature)'"
local b1_sig ""
_tvb_ready, fr(tb_p1)
if r(ok) {
    frame tb_p1: quietly datasignature
    local b1_sig "`r(datasignature)'"
}
local ok = (`b3_rc' == 0 & "`b3_sig'" != "" & "`b3_sig'" == "`b1_sig'")
_tvb_check `ok' ///
    "B3 inline and one-row specframe produce the same committed data" ///
    "rc=`b3_rc' inline=`b1_sig' spec=`b3_sig'"

* B4: both forms against a FIXED expected table. B3 alone would pass while a
* shared normaliser bug made both of them wrong in the same way.
local ++test_count
clear
input long pid double start double stop byte tv_drug
    1 100 149 0
    1 150 199 1
    1 200 249 0
    1 250 299 2
    1 300 500 0
    2 120 129 0
    2 130 200 1
    2 201 480 0
    3  90  95 1
    3  96  99 0
    3 100 400 2
    3 401 500 0
    4 200 460 0
end
sort pid start stop
tempfile b4expect
quietly save "`b4expect'", replace
frame copy tb_p1 tb_cmp, replace
frame tb_cmp: _tvb_cf pid start stop tv_drug using "`b4expect'"
local b4_a = r(rc)
frame copy tb_p3 tb_cmp, replace
frame tb_cmp: _tvb_cf pid start stop tv_drug using "`b4expect'"
local b4_b = r(rc)
local ok = (`b4_a' == 0 & `b4_b' == 0)
_tvb_check `ok' ///
    "B4 both public forms match a hand-written expected tiling" ///
    "inline_cf=`b4_a' spec_cf=`b4_b'"

* B5: two raw sources against tvexpose x2 + tvmerge.
local ++test_count
_tvb_oracle2
frame tb_om {
    keep pid start stop tv_drug tv_statin
    sort pid start stop
    tempfile b5oracle
    quietly save "`b5oracle'", replace
}
_tvb_spec_new tb_spec2
_tvb_spec_add, fr(tb_spec2) name(drugsrc) kind(episodes) sfile("tb_epi.dta") ///
    sv(a_start) pv(a_stop) iv(drug) ov(tv_drug) ref(0)
_tvb_spec_add, fr(tb_spec2) name(statinsrc) kind(episodes) sfile("tb_epi2.dta") ///
    sv(b_start) pv(b_stop) iv(statin) ov(tv_statin) ref(0)
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_spec2) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_p5) replace
local b5_rc = _rc
frame copy tb_p5 tb_cmp, replace
frame tb_cmp: _tvb_cf pid start stop tv_drug tv_statin using "`b5oracle'"
local b5_cf = r(rc)
local ok = (`b5_rc' == 0 & `b5_cf' == 0)
_tvb_check `ok' ///
    "B5 two raw sources equal the frozen tvexpose+tvmerge sequence" ///
    "rc=`b5_rc' cf=`b5_cf'"

* B6: three sources.
local ++test_count
_tvb_spec_new tb_spec3
_tvb_spec_add, fr(tb_spec3) name(s1) kind(episodes) sfile("tb_epi.dta") ///
    sv(a_start) pv(a_stop) iv(drug) ov(tv_drug) ref(0)
_tvb_spec_add, fr(tb_spec3) name(s2) kind(episodes) sfile("tb_epi2.dta") ///
    sv(b_start) pv(b_stop) iv(statin) ov(tv_statin) ref(0)
_tvb_spec_add, fr(tb_spec3) name(s3) kind(episodes) sfile("tb_epi3.dta") ///
    sv(c_start) pv(c_stop) iv(anticoag) ov(tv_ac) ref(0)
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_spec3) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_p6) replace
local b6_rc = _rc
local b6_ns = r(n_sources)
local b6_n = .
local b6_ac = .
_tvb_ready, fr(tb_p6)
if r(ok) {
frame tb_p6 {
    quietly count
    local b6_n = r(N)
    quietly count if tv_ac == 1
    local b6_ac = r(N)
}
}
local ok = (`b6_rc' == 0 & `b6_ns' == 3 & `b6_ac' == 2)
_tvb_check `ok' ///
    "B6 three sources align and every source contributes its payload" ///
    "rc=`b6_rc' n_sources=`b6_ns' rows=`b6_n' ac_rows=`b6_ac'"

* B7: a ready interval source alone is passed through, not re-tiled.
local ++test_count
use "tb_cohort.dta", clear
_tvb_spec_new tb_spec4
_tvb_spec_add, fr(tb_spec4) name(renal) kind(intervals) sfile("tb_ready.dta") ///
    sv(start) pv(stop) iv(ckd) ov(ckd_stage)
capture tvbuild, specframe(tb_spec4) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_p7) replace
local b7_rc = _rc
local b7_n = r(N_periods)
local ok = (`b7_rc' == 0 & `b7_n' == 5)
_tvb_check `ok' ///
    "B7 a ready interval source is carried through unchanged in row count" ///
    "rc=`b7_rc' rows=`b7_n'"

* B8: a mixture of raw and ready sources.
local ++test_count
_tvb_spec_new tb_spec5
_tvb_spec_add, fr(tb_spec5) name(drugsrc) kind(episodes) sfile("tb_epi.dta") ///
    sv(a_start) pv(a_stop) iv(drug) ov(tv_drug) ref(0)
_tvb_spec_add, fr(tb_spec5) name(renal) kind(intervals) sfile("tb_ready.dta") ///
    sv(start) pv(stop) iv(ckd) ov(ckd_stage)
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_spec5) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_p8) replace
local b8_rc = _rc
local b8_miss = .
_tvb_ready, fr(tb_p8)
if r(ok) {
frame tb_p8 {
    quietly count if missing(tv_drug) | missing(ckd_stage)
    local b8_miss = r(N)
}
}
local ok = (`b8_rc' == 0 & `b8_miss' == 0)
_tvb_check `ok' ///
    "B8 a raw and a ready source align into one complete result" ///
    "rc=`b8_rc' missing_payload_rows=`b8_miss'"

* B9: one locator, two specification rows, two distinct mappings.
local ++test_count
_tvb_spec_new tb_spec6
_tvb_spec_add, fr(tb_spec6) name(first) kind(intervals) sfile("tb_ready.dta") ///
    sv(start) pv(stop) iv(ckd) ov(ckd_a)
_tvb_spec_add, fr(tb_spec6) name(second) kind(intervals) sfile("tb_ready.dta") ///
    sv(start) pv(stop) iv(egfr) ov(egfr_b) rv(egfr)
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_spec6) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_p9) replace
local b9_rc = _rc
local b9_pay "`r(payload_vars)'"
local b9_miss = .
capture confirm frame tb_p9
if _rc == 0 {
    frame tb_p9 {
        quietly count if missing(ckd_a) | missing(egfr_b)
        local b9_miss = r(N)
    }
}
local ok = (`b9_rc' == 0 & `b9_miss' == 0 & "`b9_pay'" == "ckd_a egfr_b")
_tvb_check `ok' ///
    "B9 one locator used by two rows yields both distinct mappings" ///
    "rc=`b9_rc' payload=`b9_pay' missing=`b9_miss'"

* B10: a master person with no episode gets one full-window reference row.
local ++test_count
local b10_rows = .
local b10_s = .
local b10_e = .
local b10_ref = .
_tvb_ready, fr(tb_p1)
if r(ok) {
frame tb_p1 {
    quietly count if pid == 4
    local b10_rows = r(N)
    quietly summarize start if pid == 4, meanonly
    local b10_s = r(min)
    quietly summarize stop if pid == 4, meanonly
    local b10_e = r(max)
    quietly count if pid == 4 & tv_drug == 0
    local b10_ref = r(N)
}
}
local ok = (`b10_rows' == 1 & `b10_s' == 200 & `b10_e' == 460 & `b10_ref' == 1)
_tvb_check `ok' ///
    "B10 a master person with no episode gets one full-window reference row" ///
    "rows=`b10_rows' start=`b10_s' stop=`b10_e' ref_rows=`b10_ref'"

* B11: a source person absent from the master is counted and ignored.
local ++test_count
use "tb_cohort.dta", clear
capture tvbuild, sourceusing("tb_epi.dta") id(pid) entry(study_entry) ///
    exit(study_exit) start(a_start) stop(a_stop) exposure(drug) ///
    reference(0) generate(tv_drug) frameout(tb_p11) replace
matrix tb_sc = r(source_counts)
local b11_unm = tb_sc[1, 3]
local b11_leak = .
_tvb_ready, fr(tb_p11)
if r(ok) {
frame tb_p11 {
    quietly count if pid == 9
    local b11_leak = r(N)
}
}
local ok = (`b11_unm' == 1 & `b11_leak' == 0)
_tvb_check `ok' ///
    "B11 a source id absent from the master is counted and excluded" ///
    "unmatched=`b11_unm' leaked_rows=`b11_leak'"

* B12: the plan records the engine that actually ran.
local ++test_count
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_spec5) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_p12) dryrun
matrix tb_sc2 = r(source_counts)
local b12_k1 = tb_sc2[1, 5]
local b12_k2 = tb_sc2[2, 5]
local ok = (`b12_k1' == 1 & `b12_k2' == 2)
_tvb_check `ok' ///
    "B12 the source-kind coding distinguishes the two engines" ///
    "kind1=`b12_k1' kind2=`b12_k2'"

* B13: adjacent episodes carrying the same category collapse, exactly as the
* released layer kernel does. This fixture is here because Section 11.2 of the
* plan says the opposite and the shipped command is the authority.
local ++test_count
clear
input long pid double a_start double a_stop byte drug
    1 150 199 1
    1 200 249 1
    2 130 200 1
    3 100 400 2
    4 210 300 1
end
quietly save "tb_adj.dta", replace
use "tb_cohort.dta", clear
tvexpose using "tb_adj.dta", id(pid) start(a_start) stop(a_stop) ///
    exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_drug) frameout(tb_oadj) replace
frame tb_oadj: rename (a_start a_stop) (start stop)
frame tb_oadj {
    keep pid start stop tv_drug
    sort pid start stop
    tempfile b13oracle
    quietly save "`b13oracle'", replace
    quietly count if pid == 1
    local b13_orows = r(N)
}
use "tb_cohort.dta", clear
capture tvbuild, sourceusing("tb_adj.dta") id(pid) entry(study_entry) ///
    exit(study_exit) start(a_start) stop(a_stop) exposure(drug) ///
    reference(0) generate(tv_drug) frameout(tb_p13) replace
local b13_rc = _rc
frame copy tb_p13 tb_cmp, replace
frame tb_cmp: _tvb_cf pid start stop tv_drug using "`b13oracle'"
local b13_cf = r(rc)
local ok = (`b13_rc' == 0 & `b13_cf' == 0 & `b13_orows' == 3)
_tvb_check `ok' ///
    "B13 abutting equal-category episodes collapse as the released kernel does" ///
    "rc=`b13_rc' cf=`b13_cf' oracle_p1_rows=`b13_orows'"

* B14: a specification cell containing a macro reference is refused rather than
* expanded. `input' does not expand macros in its data lines, so a locator
* typed as a tempfile macro is stored as the six literal characters -- and the
* local that reads it back out DOES expand them, to whatever a same-named local
* happens to hold in the normaliser, which is normally nothing. The symptom
* without this guard is not an error but a locator that quietly reads as empty.
local ++test_count
capture frame drop tb_p14
_tvb_spec_new tb_spec14
frame tb_spec14 {
    quietly set obs 1
    quietly replace source_name = "bad"
    quietly replace source_kind = "episodes"
    quietly replace source_file = char(96) + "episodes" + char(39)
    quietly replace start_var = "a_start"
    quietly replace stop_var = "a_stop"
    quietly replace input_vars = "drug"
    quietly replace output_vars = "tv_drug"
    quietly replace reference = 0
}
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_spec14) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_p14)
local b14_rc = _rc
capture confirm frame tb_p14
local b14_none = (_rc != 0)
local ok = (`b14_rc' == 198 & `b14_none')
_tvb_check `ok' ///
    "B14 a specification cell holding a macro reference is refused, not expanded" ///
    "rc=`b14_rc' destination_absent=`b14_none'"

* B15: the same guard covers a dollar sign and a double quote.
local ++test_count
local b15_rcs ""
foreach _ch in 36 34 {
    capture frame drop tb_p15
    _tvb_spec_new tb_spec15
    frame tb_spec15 {
        quietly set obs 1
        quietly replace source_name = "bad"
        quietly replace source_kind = "episodes"
        quietly replace source_file = "tb_epi" + char(`_ch') + ".dta"
        quietly replace start_var = "a_start"
        quietly replace stop_var = "a_stop"
        quietly replace input_vars = "drug"
        quietly replace output_vars = "tv_drug"
        quietly replace reference = 0
    }
    use "tb_cohort.dta", clear
    capture tvbuild, specframe(tb_spec15) id(pid) entry(study_entry) ///
        exit(study_exit) frameout(tb_p15)
    local b15_rcs "`b15_rcs' `=_rc'"
}
local ok = ("`=strtrim("`b15_rcs'")'" == "198 198")
_tvb_check `ok' "B15 a dollar sign or a double quote in a cell is refused too" ///
    "rcs=`b15_rcs'"

**# ---------------------------------------------------------------------
**# Q. Quantity algebra through the merge
**# ---------------------------------------------------------------------
_tvb_spec_new tb_specq
_tvb_spec_add, fr(tb_specq) name(drugsrc) kind(episodes) sfile("tb_epi.dta") ///
    sv(a_start) pv(a_stop) iv(drug) ov(tv_drug) ref(0)
_tvb_spec_add, fr(tb_specq) name(renal) kind(intervals) sfile("tb_ready.dta") ///
    sv(start) pv(stop) iv(ckd egfr dose cumdose) ///
    ov(ckd_stage egfr_r dose_t cum_h) rv(egfr) tv(dose) cv(cumdose)
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_specq) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_pq) replace
local q_rc = _rc
local q_rate "`r(rate_vars)'"
local q_total "`r(total_vars)'"
local q_cum "`r(cumulative_vars)'"
local q_expo "`r(exposure_vars)'"

* Q1: the run succeeded and the classification partitions the payload.
local ++test_count
local ok = (`q_rc' == 0 & "`q_rate'" == "egfr_r" & "`q_total'" == "dose_t" ///
    & "`q_cum'" == "cum_h" & "`q_expo'" == "tv_drug ckd_stage")
_tvb_check `ok' ///
    "Q1 mapped quantity names are classified by algebra, not by position" ///
    "rate=`q_rate' total=`q_total' cum=`q_cum' expo=`q_expo'"

* Q2: a rate is carried unchanged onto every derived segment.
* Every block in this group is preceded by _tvb_ready and its locals are
* initialised to missing first, so a Q1 failure that also destroyed the run
* reports as a labelled failure per axis instead of ending the suite.
local ++test_count
local q2_a = .
local q2_b = .
_tvb_ready, fr(tb_pq) vars(pid start egfr_r)
if r(ok) {
    frame tb_pq {
        quietly count if pid == 1 & start < 300 & egfr_r != 90
        local q2_a = r(N)
        quietly count if pid == 1 & start >= 300 & egfr_r != 70
        local q2_b = r(N)
    }
}
local ok = (`q2_a' == 0 & `q2_b' == 0 & !missing(`q2_a', `q2_b'))
_tvb_check `ok' ///
    "Q2 a rate is carried unchanged onto every derived segment" ///
    "wrong_before=`q2_a' wrong_after=`q2_b'"

* Q3: an interval total is apportioned so the pieces sum back to the source.
local ++test_count
local q3_sum = .
local q3_sum3 = .
_tvb_ready, fr(tb_pq) vars(pid dose_t)
if r(ok) {
    frame tb_pq {
        quietly summarize dose_t if pid == 2, meanonly
        local q3_sum = r(sum)
        quietly summarize dose_t if pid == 3, meanonly
        local q3_sum3 = r(sum)
    }
}
local ok = (abs(`q3_sum' - 361) < 1e-6 & abs(`q3_sum3' - 411) < 1e-6)
_tvb_check `ok' ///
    "Q3 an interval total is apportioned and the pieces sum to the source" ///
    "p2=`q3_sum' expected 361; p3=`q3_sum3' expected 411"

* Q4: a cumulative history is carried unchanged.
local ++test_count
local q4_a = .
local q4_b = .
_tvb_ready, fr(tb_pq) vars(pid start cum_h)
if r(ok) {
    frame tb_pq {
        quietly count if pid == 1 & start < 300 & cum_h != 0
        local q4_a = r(N)
        quietly count if pid == 1 & start >= 300 & cum_h != 200
        local q4_b = r(N)
    }
}
local ok = (`q4_a' == 0 & `q4_b' == 0 & !missing(`q4_a', `q4_b'))
_tvb_check `ok' ///
    "Q4 a cumulative history is carried unchanged across every split" ///
    "wrong_before=`q4_a' wrong_after=`q4_b'"

* Q5: the quantity characteristics reach the committed frame.
local ++test_count
local q5_r ""
local q5_t ""
local q5_c ""
local q5_h ""
_tvb_ready, fr(tb_pq) vars(egfr_r dose_t cum_h)
if r(ok) {
    frame tb_pq {
        local q5_r : char egfr_r[tvtools_quantity]
        local q5_t : char dose_t[tvtools_quantity]
        local q5_c : char cum_h[tvtools_quantity]
        local q5_h : char cum_h[tvtools_history_point]
    }
}
local ok = ("`q5_r'" == "rate" & "`q5_t'" == "total" & ///
    "`q5_c'" == "cumulative" & "`q5_h'" == "start")
_tvb_check `ok' ///
    "Q5 the quantity characteristics survive to the committed frame" ///
    "rate=`q5_r' total=`q5_t' cum=`q5_c' point=`q5_h'"

* Q6: total apportionment is not silently applied to the rate or the history.
local ++test_count
local q6_max = .
local q6_cmax = .
_tvb_ready, fr(tb_pq) vars(pid egfr_r cum_h)
if r(ok) {
    frame tb_pq {
        quietly summarize egfr_r if pid == 2, meanonly
        local q6_max = r(max)
        quietly summarize cum_h, meanonly
        local q6_cmax = r(max)
    }
}
local ok = (`q6_max' == 85 & `q6_cmax' == 200)
_tvb_check `ok' ///
    "Q6 the rate and the history are not apportioned like a total" ///
    "egfr_max=`q6_max' cum_max=`q6_cmax'"

**# ---------------------------------------------------------------------
**# C. Coverage policies and zero-result refusals
**# ---------------------------------------------------------------------
_tvb_spec_new tb_specg
_tvb_spec_add, fr(tb_specg) name(gappy) kind(intervals) sfile("tb_gap.dta") ///
    sv(start) pv(stop) iv(ckd) ov(ckd_stage)

* C1: strict refuses a gap and creates nothing.
local ++test_count
capture frame drop tb_pc
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_specg) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_pc)
local c1_rc = _rc
capture confirm frame tb_pc
local c1_none = (_rc != 0)
local ok = (`c1_rc' == 459 & `c1_none')
_tvb_check `ok' ///
    "C1 coverage(strict) refuses a gap and creates no destination" ///
    "rc=`c1_rc' destination_absent=`c1_none'"

* C2: allow succeeds and reports the gap in r() and in the characteristic.
local ++test_count
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_specg) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_pc) coverage(allow)
local c2_rc = _rc
local c2_gap = r(n_gap_ids)
local c2_days = r(uncovered_days)
local c2_cov "`r(coverage)'"
local c2_char ""
_tvb_ready, fr(tb_pc)
if r(ok) {
frame tb_pc {
    local c2_char : char _dta[tvtools_tvbuild_coverage]
}
}
local ok = (`c2_rc' == 0 & `c2_gap' == 1 & `c2_days' == 99 & ///
    "`c2_cov'" == "allow" & "`c2_char'" == "allow")
_tvb_check `ok' ///
    "C2 coverage(allow) succeeds and records the gap in r() and in _dta[]" ///
    "rc=`c2_rc' gap_ids=`c2_gap' days=`c2_days' r=`c2_cov' char=`c2_char'"

* C3: allow still refuses a ready source that omits a master person entirely.
local ++test_count
clear
input long pid double start double stop byte ckd
    1 100 500 1
    2 120 480 1
    3  90 500 1
end
quietly save "tb_missing_person.dta", replace
_tvb_spec_new tb_specm
_tvb_spec_add, fr(tb_specm) name(short) kind(intervals) ///
    sfile("tb_missing_person.dta") sv(start) pv(stop) iv(ckd) ov(ckd_stage)
capture frame drop tb_pc3
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_specm) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_pc3) coverage(allow)
local c3_rc = _rc
capture confirm frame tb_pc3
local c3_none = (_rc != 0)
local ok = (`c3_rc' == 459 & `c3_none')
_tvb_check `ok' ///
    "C3 coverage(allow) still refuses a master person with no source row" ///
    "rc=`c3_rc' destination_absent=`c3_none'"

* C4: the strict default holds when coverage() is not given at all.
local ++test_count
capture frame drop tb_pc4
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_specg) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_pc4)
local c4_rc = _rc
local ok = (`c4_rc' == 459)
_tvb_check `ok' "C4 coverage defaults to strict" "rc=`c4_rc'"

* C5: an episodes source never produces a gap, because the reference category
* fills the window. This is the invariant the fast constructor is trusted for.
local ++test_count
use "tb_cohort.dta", clear
capture tvbuild, sourceusing("tb_epi.dta") id(pid) entry(study_entry) ///
    exit(study_exit) start(a_start) stop(a_stop) exposure(drug) ///
    reference(0) generate(tv_drug) frameout(tb_pc5) replace
local c5_rc = _rc
local c5_gap = r(n_gap_ids)
local c5_days = r(uncovered_days)
local ok = (`c5_rc' == 0 & `c5_gap' == 0 & `c5_days' == 0)
_tvb_check `ok' ///
    "C5 a raw episodes source covers every master day by construction" ///
    "rc=`c5_rc' gap_ids=`c5_gap' days=`c5_days'"

* C6: coverage is measured by interval union, not by summing row lengths.
* The fixture below double-covers one span; a row-length sum would report full
* coverage for person 1 while a real gap remains.
local ++test_count
clear
input long pid double start double stop byte ckd
    1 100 300 1
    1 100 300 2
    1 402 500 1
    2 120 480 1
    3  90 500 1
    4 200 460 1
end
quietly save "tb_double.dta", replace
_tvb_spec_new tb_specd
_tvb_spec_add, fr(tb_specd) name(dbl) kind(intervals) sfile("tb_double.dta") ///
    sv(start) pv(stop) iv(ckd) ov(ckd_stage)
capture frame drop tb_pc6
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_specd) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_pc6) coverage(allow)
local c6_rc = _rc
local c6_days = r(uncovered_days)
local ok = (`c6_rc' == 0 & `c6_days' == 101)
_tvb_check `ok' ///
    "C6 coverage uses the interval union, not the sum of row lengths" ///
    "rc=`c6_rc' uncovered=`c6_days' expected 101"

**# ---------------------------------------------------------------------
**# M. Committed order, metadata categories, internal-name absence
**# ---------------------------------------------------------------------
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_specq) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_pm) keepvars(sex bmi) replace
local m_rc = _rc

* M1: the committed variable order is exactly Section 12.4's.
local ++test_count
local m1_order ""
_tvb_ready, fr(tb_pm)
if r(ok) {
frame tb_pm {
    quietly ds
    local m1_order "`r(varlist)'"
}
}
local m1_want "pid study_entry study_exit start stop tv_drug ckd_stage egfr_r dose_t cum_h sex bmi"
local ok = ("`m1_order'" == "`m1_want'")
_tvb_check `ok' "M1 the committed variable order matches the contract" ///
    "got=`m1_order'"

* M2: the identifier carries the master's storage type, format, and labels.
local ++test_count
local m2_type ""
local m2_lab ""
_tvb_ready, fr(tb_pm)
if r(ok) {
frame tb_pm {
    local m2_type : type pid
    local m2_lab : variable label pid
}
}
use "tb_cohort.dta", clear
local m2_mtype : type pid
local m2_mlab : variable label pid
local ok = ("`m2_type'" == "`m2_mtype'" & "`m2_lab'" == "`m2_mlab'")
_tvb_check `ok' ///
    "M2 the identifier keeps the master's storage type and variable label" ///
    "result=`m2_type'/`m2_lab' master=`m2_mtype'/`m2_mlab'"

* M3: a keepvar keeps its master value-label assignment AND definition.
local ++test_count
local m3_vl ""
local m3_txt ""
local m3_lab ""
_tvb_ready, fr(tb_pm)
if r(ok) {
frame tb_pm {
    local m3_vl : value label sex
    local m3_txt : label `m3_vl' 1
    local m3_lab : variable label sex
}
}
local ok = ("`m3_vl'" == "tb_sex" & "`m3_txt'" == "Male" & ///
    "`m3_lab'" == "Sex at baseline")
_tvb_check `ok' ///
    "M3 a keepvar keeps its master value-label assignment and definition" ///
    "vallab=`m3_vl' text=`m3_txt' varlab=`m3_lab'"

* M4: the constructed exposure keeps the source's variable label and gets the
* reference label, exactly as tvexpose builds it.
local ++test_count
local m4_lab ""
local m4_vl ""
local m4_ref ""
local m4_one ""
_tvb_ready, fr(tb_pm)
if r(ok) {
frame tb_pm {
    local m4_lab : variable label tv_drug
    local m4_vl : value label tv_drug
    local m4_ref : label `m4_vl' 0
    local m4_one : label `m4_vl' 1
}
}
local ok = ("`m4_lab'" == "Drug class" & "`m4_ref'" == "Unexposed" & ///
    "`m4_one'" == "Class A")
_tvb_check `ok' ///
    "M4 the exposure keeps its source labels and gains the reference label" ///
    "varlab=`m4_lab' ref=`m4_ref' one=`m4_one'"

* M5: no internal column survives into the committed schema.
local ++test_count
local m5_all ""
_tvb_ready, fr(tb_pm)
if r(ok) {
frame tb_pm {
    quietly ds
    local m5_all "`r(varlist)'"
}
}
local m5_bad = 0
foreach v of local m5_all {
    if substr("`v'", 1, 5) == "_tvp_" local m5_bad = 1
    if substr("`v'", 1, 6) == "__tvm_" local m5_bad = 1
    if inlist("`v'", "exp_start", "exp_stop", "exp_value") local m5_bad = 1
}
local ok = (`m5_bad' == 0)
_tvb_check `ok' "M5 no internal staging column survives the commit" ///
    "vars=`m5_all'"

* M6: the output bounds are doubles carrying dateformat().
local ++test_count
local m6_t ""
local m6_f ""
local m6_t2 ""
_tvb_ready, fr(tb_pm)
if r(ok) {
frame tb_pm {
    local m6_t : type start
    local m6_f : format start
    local m6_t2 : type stop
}
}
local ok = ("`m6_t'" == "double" & "`m6_t2'" == "double" & ///
    "`m6_f'" == "%tdCCYY/NN/DD")
_tvb_check `ok' "M6 output bounds are doubles with dateformat()" ///
    "type=`m6_t'/`m6_t2' format=`m6_f'"

* M7: a non-default dateformat() reaches the committed bounds.
local ++test_count
use "tb_cohort.dta", clear
capture tvbuild, sourceusing("tb_epi.dta") id(pid) entry(study_entry) ///
    exit(study_exit) start(a_start) stop(a_stop) exposure(drug) ///
    reference(0) generate(tv_drug) frameout(tb_pm7) dateformat(%tdDD/NN/CCYY) ///
    replace
local m7_rc = _rc
local m7_f ""
_tvb_ready, fr(tb_pm7)
if r(ok) {
frame tb_pm7 {
    local m7_f : format stop
}
}
local ok = (`m7_rc' == 0 & "`m7_f'" == "%tdDD/NN/CCYY")
_tvb_check `ok' "M7 dateformat() reaches the committed bounds" ///
    "rc=`m7_rc' format=`m7_f'"

* M8: the master's dataset label is preserved.
local ++test_count
local m8_d ""
_tvb_ready, fr(tb_pm)
if r(ok) {
frame tb_pm {
    local m8_d : data label
}
}
local ok = (`"`m8_d'"' == "Analysis cohort")
_tvb_check `ok' "M8 the master dataset label is preserved" "label=`m8_d'"

* M9: two sources whose value labels share a NAME with different definitions
* both keep their own meaning. The second must be renamed rather than
* overwrite the first.
local ++test_count
_tvb_spec_new tb_specl
_tvb_spec_add, fr(tb_specl) name(l1) kind(episodes) sfile("tb_lab1.dta") ///
    sv(d_start) pv(d_stop) iv(lvl) ov(lvl_a) ref(0) rlab("Ref A")
_tvb_spec_add, fr(tb_specl) name(l2) kind(episodes) sfile("tb_lab2.dta") ///
    sv(e_start) pv(e_stop) iv(lvl2) ov(lvl_b) ref(0) rlab("Ref B")
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_specl) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_pm9) replace
local m9_rc = _rc
local m9_va ""
local m9_vb ""
local m9_ta ""
local m9_tb ""
local m9_ra ""
local m9_rb ""
_tvb_ready, fr(tb_pm9)
if r(ok) {
frame tb_pm9 {
    local m9_va : value label lvl_a
    local m9_vb : value label lvl_b
    local m9_ta : label `m9_va' 1
    local m9_tb : label `m9_vb' 1
    local m9_ra : label `m9_va' 0
    local m9_rb : label `m9_vb' 0
}
}
local ok = (`m9_rc' == 0 & "`m9_ta'" == "First meaning" & ///
    "`m9_tb'" == "Second meaning" & "`m9_ra'" == "Ref A" & "`m9_rb'" == "Ref B")
_tvb_check `ok' ///
    "M9 two sources sharing a value-label name keep their own definitions" ///
    "rc=`m9_rc' a=`m9_ta'/`m9_ra' b=`m9_tb'/`m9_rb'"

* M10: dropdates removes entry/exit and nothing else.
local ++test_count
use "tb_cohort.dta", clear
capture tvbuild, sourceusing("tb_epi.dta") id(pid) entry(study_entry) ///
    exit(study_exit) start(a_start) stop(a_stop) exposure(drug) ///
    reference(0) generate(tv_drug) frameout(tb_pm10) dropdates replace
local m10_rc = _rc
local m10_kept = r(dates_kept)
local m10_v ""
_tvb_ready, fr(tb_pm10)
if r(ok) {
frame tb_pm10 {
    quietly ds
    local m10_v "`r(varlist)'"
}
}
local ok = (`m10_rc' == 0 & `m10_kept' == 0 & "`m10_v'" == "pid start stop tv_drug")
_tvb_check `ok' "M10 dropdates removes entry/exit and nothing else" ///
    "rc=`m10_rc' dates_kept=`m10_kept' vars=`m10_v'"

* M11: a stray column in the finalised result is refused before any commit.
* The schema check is the only thing standing between a leaked internal column
* and a committed frame, and nothing about the VALUES would reveal it -- so it
* is injected here rather than assumed. _tvbuild_carry_meta is shadowed by a
* stub that adds one column; a program in memory takes precedence over the
* installed ado, and `discard' puts the real one back.
local ++test_count
capture frame drop tb_pm11
capture program drop _tvbuild_carry_meta
program define _tvbuild_carry_meta, rclass
    version 16.0
    syntax , SRCframe(name) DSTframe(name) VARS(string) [SRCVars(string)]
    local _here "`c(frame)'"
    frame change `dstframe'
    capture generate byte _tvp_stray = 1
    frame change `_here'
    return scalar n_vars = 0
end
use "tb_cohort.dta", clear
capture tvbuild, sourceusing("tb_epi.dta") id(pid) entry(study_entry) ///
    exit(study_exit) start(a_start) stop(a_stop) exposure(drug) ///
    reference(0) generate(tv_drug) frameout(tb_pm11)
local m11_rc = _rc
capture program drop _tvbuild_carry_meta
discard
capture confirm frame tb_pm11
local m11_none = (_rc != 0)
local ok = (`m11_rc' == 498 & `m11_none')
_tvb_check `ok' ///
    "M11 a column outside the planned schema is refused before any commit" ///
    "rc=`m11_rc' destination_absent=`m11_none'"

**# ---------------------------------------------------------------------
**# S. Stage counts, source counts, and the real-run return surface
**# ---------------------------------------------------------------------
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_spec2) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_ps) replace
local s_rc = _rc
matrix tb_stage = r(stage_counts)
matrix tb_src = r(source_counts)
local s_names : rownames tb_stage
local s_cols : colnames tb_stage
local s_np = r(N_periods)
local s_sig "`r(datasignature)'"
local s_dry = r(dryrun)

* S1: the stage matrix has one row per executed stage, in execution order.
local ++test_count
local ok = (`s_rc' == 0 & "`s_names'" == "source1 source2 merge output" & ///
    "`s_cols'" == "N_in N_out N_persons_in N_persons_out uncovered_days")
_tvb_check `ok' "S1 r(stage_counts) names the executed stages in order" ///
    "rows=`s_names' cols=`s_cols'"

* S2: the merge stage's N_in is the sum of the normalised source rows.
local ++test_count
local s2_a = tb_stage[1, 2]
local s2_b = tb_stage[2, 2]
local s2_m = tb_stage[3, 1]
local ok = (`s2_m' == `s2_a' + `s2_b')
_tvb_check `ok' "S2 the merge stage reads exactly what the sources emitted" ///
    "source_out=`s2_a'+`s2_b' merge_in=`s2_m'"

* S3: the output stage row count equals r(N_periods) and the committed frame.
local ++test_count
local s3_out = tb_stage[4, 2]
local s3_actual = .
_tvb_ready, fr(tb_ps)
if r(ok) {
frame tb_ps {
    quietly count
    local s3_actual = r(N)
}
}
local ok = (`s3_out' == `s3_actual' & `s_np' == `s3_actual')
_tvb_check `ok' "S3 the output stage, r(N_periods), and the frame agree" ///
    "stage=`s3_out' r=`s_np' frame=`s3_actual'"

* S4: uncovered_days is populated for construction rows and missing after them.
local ++test_count
local s4_src = tb_stage[1, 5]
local s4_mrg = tb_stage[3, 5]
local s4_out = tb_stage[4, 5]
local ok = (`s4_src' == 0 & `s4_mrg' == 0 & missing(`s4_out'))
_tvb_check `ok' ///
    "S4 uncovered_days is a construction-stage number and missing at output" ///
    "src=`s4_src' merge=`s4_mrg' output=`s4_out'"

* S5: r(dryrun) is 0 on a real run and the signature is nonempty.
local ++test_count
local ok = (`s_dry' == 0 & "`s_sig'" != "" & "`s_sig'" != ".")
_tvb_check `ok' "S5 a real run reports dryrun=0 and a data signature" ///
    "dryrun=`s_dry' sig=`s_sig'"

* S6: the source matrix reports rows and persons before restriction.
local ++test_count
local s6_r1 = tb_src[1, 1]
local s6_p1 = tb_src[1, 2]
local s6_r2 = tb_src[2, 1]
local ok = (`s6_r1' == 6 & `s6_p1' == 4 & `s6_r2' == 3)
_tvb_check `ok' "S6 r(source_counts) describes the sources before restriction" ///
    "rows1=`s6_r1' persons1=`s6_p1' rows2=`s6_r2'"

**# ---------------------------------------------------------------------
**# X. Read-only inputs, no artefacts, repeatability
**# ---------------------------------------------------------------------

* X1: a frame source is byte-identical after the call.
local ++test_count
capture frame drop tb_srcx
frame create tb_srcx
frame tb_srcx: use "tb_epi.dta", clear
frame tb_srcx: quietly datasignature
local x1_before "`r(datasignature)'"
frame tb_srcx {
    quietly ds
    local x1_vbefore "`r(varlist)'"
}
use "tb_cohort.dta", clear
capture tvbuild, sourceframe(tb_srcx) id(pid) entry(study_entry) ///
    exit(study_exit) start(a_start) stop(a_stop) exposure(drug) ///
    reference(0) generate(tv_drug) frameout(tb_px1) replace
local x1_rc = _rc
frame tb_srcx: quietly datasignature
local x1_after "`r(datasignature)'"
frame tb_srcx {
    quietly ds
    local x1_vafter "`r(varlist)'"
}
local ok = (`x1_rc' == 0 & "`x1_before'" == "`x1_after'" & ///
    "`x1_vbefore'" == "`x1_vafter'")
_tvb_check `ok' "X1 a frame source is unchanged after a real run" ///
    "rc=`x1_rc' before=`x1_before' after=`x1_after'"

* X2: tvbuild writes no file into the working directory. The engines it calls
* use Stata tempfiles under c(tmpdir); this pins that tvbuild adds no artefact
* of its own where the user is working.
local ++test_count
local x2_before : dir "." files "*.dta"
local x2_nb : word count `x2_before'
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_spec2) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_px2) replace
local x2_rc = _rc
local x2_after : dir "." files "*.dta"
local x2_na : word count `x2_after'
local ok = (`x2_rc' == 0 & `x2_nb' == `x2_na')
_tvb_check `ok' "X2 no working-directory file is created by a real run" ///
    "rc=`x2_rc' before=`x2_nb' after=`x2_na'"

* X3: the caller's data and frame are unchanged.
local ++test_count
use "tb_cohort.dta", clear
quietly datasignature
local x3_before "`r(datasignature)'"
local x3_frame_before "`c(frame)'"
_tvb_framelist
local x3_fl_before "`r(frames)'"
capture tvbuild, specframe(tb_spec2) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_px3) replace
local x3_rc = _rc
quietly datasignature
local x3_after "`r(datasignature)'"
_tvb_framelist
local x3_fl_after "`r(frames)'"
* Both destinations, and only those two. Since 1.12.0 the manifest is built by
* default, so a run with no manifestframe() commits frameout() AND its derived
* manifest; naming both here keeps the check exact rather than loosening it,
* and it still fails on any leaked scratch frame.
local x3_expect "`x3_fl_before' tb_px3 tb_px3_manifest"
local x3_expect : list sort x3_expect
local ok = (`x3_rc' == 0 & "`x3_before'" == "`x3_after'" & ///
    "`c(frame)'" == "`x3_frame_before'" & "`x3_fl_after'" == "`x3_expect'")
_tvb_check `ok' ///
    "X3 the caller's data, current frame, and frame list gain only the two destinations" ///
    "rc=`x3_rc' sig=`x3_before'/`x3_after' frames=`x3_fl_after'"

* X4: two identical runs produce identical results.
local ++test_count
use "tb_cohort.dta", clear
capture tvbuild, specframe(tb_specq) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_px4) keepvars(sex bmi) replace
local x4_rc1 = _rc
local x4_s1 "`r(datasignature)'"
capture tvbuild, specframe(tb_specq) id(pid) entry(study_entry) ///
    exit(study_exit) frameout(tb_px4) keepvars(sex bmi) replace
local x4_rc2 = _rc
local x4_s2 "`r(datasignature)'"
local ok = (`x4_rc1' == 0 & `x4_rc2' == 0 & "`x4_s1'" == "`x4_s2'" & "`x4_s1'" != "")
_tvb_check `ok' "X4 a repeated identical run is bit-identical" ///
    "rc=`x4_rc1'/`x4_rc2' sig=`x4_s1'/`x4_s2'"

**# Cleanup
foreach f in tb_cohort tb_epi tb_epi2 tb_epi3 tb_ready tb_gap tb_lab1 tb_lab2 ///
    tb_adj tb_missing_person tb_double {
    capture erase "`f'.dta"
}

**# Summary
local pass_count = $TVB_PASS
local fail_count = $TVB_FAIL
display "RESULT: test_tvbuild_construct tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "tvbuild build failures:$TVB_FAILED"
    exit 1
}
