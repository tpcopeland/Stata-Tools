*! test_tvspec.do
*! tvspec builds the specification frame tvbuild's specframe() consumes.
*!
*! The decisive test is EQUIVALENCE, not surface. tvspec's whole claim is that a
*! frame it writes and a frame written by hand are indistinguishable to tvbuild,
*! so the test that matters builds the same specification both ways and compares
*! what tvbuild COMMITS from each, byte for byte. A suite that only checked that
*! the cells look right would pass on a column written to the wrong storage type
*! -- the exact failure the schema exists to prevent -- because a str8 cell
*! holding a truncated but still-legal Stata name reads back as a plausible
*! name, and the build then succeeds against a source nobody described.
*!
*! Three false greens this suite is written against:
*!
*!   1. "The two routes agree, so both are right." E1 compares tvspec against a
*!      hand-built frame, which on its own would pass while both were wrong.
*!      E2 pins the hand-built frame against tvbuild's own returns, and S1
*!      pins the declared storage types against a fixed expected list, so the
*!      schema is anchored to something outside the comparison.
*!
*!   2. "It errored, so the contract holds." Every refusal here is r(198) or
*!      r(110), and most are reachable from more than one guard. Each negative
*!      test also asserts what SURVIVED -- the frame still has its old row
*!      count, the caller's frame is untouched, no row was half-written.
*!
*!   3. "Row order is preserved because the rows came out in order." O1 checks
*!      the order tvbuild ACTS on, not the order tvspec stored: the generated
*!      variable order in the committed frame, which is what row order is FOR.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvspec.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVS_PASS = 0
global TVS_FAIL = 0
global TVS_FAILED ""

display as result "tvtools QA: tvspec -- $S_DATE $S_TIME"

capture program drop _tvs_check
program define _tvs_check
    args ok label detail
    if `ok' {
        global TVS_PASS = $TVS_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVS_FAIL = $TVS_FAIL + 1
        global TVS_FAILED "$TVS_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

capture program drop _tvs_hasframe
program define _tvs_hasframe, rclass
    version 16.0
    args fr
    capture confirm frame `fr'
    local _yes = (_rc == 0)
    return scalar yes = `_yes'
end

capture program drop _tvs_rows
program define _tvs_rows, rclass
    version 16.0
    args fr
    local _here "`c(frame)'"
    local _n = -1
    capture confirm frame `fr'
    if _rc == 0 {
        frame change `fr'
        local _n = _N
        frame change `_here'
    }
    return scalar n = `_n'
end

capture program drop _tvs_reset
program define _tvs_reset
    version 16.0
    foreach fr in sp_tool sp_hand sp_bad out_tool out_tool_manifest ///
        out_hand out_hand_manifest sp_order out_order out_order_manifest ///
        labfr {
        capture frame drop `fr'
    }
end


**# ---------------------------------------------------------------------
**# Fixtures, in the private run workspace
**# ---------------------------------------------------------------------
local work "$TVTOOLS_QA_RUN_DIR"

clear
input long pid double study_entry double study_exit byte sex
    1 100 500 1
    2 120 480 0
    3  90 500 1
end
quietly save "`work'/tvs_master.dta", replace

clear
input long pid double a_start double a_stop byte drug
    1 150 199 1
    1 250 299 2
    2 130 200 1
    3 100 400 2
end
quietly save "`work'/tvs_srcA.dta", replace

clear
input long pid double b_start double b_stop byte benzo
    1 160 220 1
    2 140 260 1
    3 110 300 1
end
quietly save "`work'/tvs_srcB.dta", replace

* Build the two-source specification BY HAND, exactly as a user does today and
* exactly as the demo did before tvspec existed. This is the oracle.
capture program drop _tvs_handspec
program define _tvs_handspec
    version 16.0
    args fr fileA fileB
    capture frame drop `fr'
    frame create `fr'
    frame `fr' {
        quietly set obs 2
        quietly generate str32 source_name     = cond(_n == 1, "antidep", "benzo")
        quietly generate str12 source_kind     = "episodes"
        quietly generate str32 source_frame    = ""
        quietly generate strL  source_file     = cond(_n == 1, "`fileA'", "`fileB'")
        quietly generate str32 start_var       = cond(_n == 1, "a_start", "b_start")
        quietly generate str32 stop_var        = cond(_n == 1, "a_stop", "b_stop")
        quietly generate strL  input_vars      = cond(_n == 1, "drug", "benzo")
        quietly generate strL  output_vars     = cond(_n == 1, "tv_drug", "tv_benzo")
        quietly generate double reference      = 0
        quietly generate strL  reference_label = cond(_n == 1, "Unexposed", "No benzo")
        quietly generate strL  variable_label  = cond(_n == 1, ///
            "Antidepressant class", "Benzodiazepine use")
    }
    frame `fr': char _dta[tvbuild_spec_version] "1"
end

* The same specification via tvspec.
capture program drop _tvs_toolspec
program define _tvs_toolspec
    version 16.0
    args fr fileA fileB
    tvspec create `fr', replace
    tvspec add `fr', name(antidep) using("`fileA'") ///
        start(a_start) stop(a_stop) exposure(drug) reference(0) ///
        generate(tv_drug) referencelabel("Unexposed") ///
        label("Antidepressant class")
    tvspec add `fr', name(benzo) using("`fileB'") ///
        start(b_start) stop(b_stop) exposure(benzo) reference(0) ///
        generate(tv_benzo) referencelabel("No benzo") ///
        label("Benzodiazepine use")
end

local BUILD id(pid) entry(study_entry) exit(study_exit)


**# ===== E: equivalence with the hand-built frame =====

* E1: the decisive test. Build the same specification both ways, run tvbuild
* against each, and compare the COMMITTED frames with cf _all. cf, not
* datasignature: the signature folds storage type into its checksum, so it
* would report a difference that no user could observe. Both are checked.
_tvs_reset
capture erase "`work'/tvs_tool.dta"
capture erase "`work'/tvs_hand.dta"
local e1_d = -1
local e1_sig_t "A"
local e1_sig_h "B"
local e1_src_t "A"
local e1_src_h "B"
local e1_exp_t "A"
local e1_exp_h "B"
capture noisily {
    local _here "`c(frame)'"

    _tvs_toolspec sp_tool "`work'/tvs_srcA.dta" "`work'/tvs_srcB.dta"
    quietly use "`work'/tvs_master.dta", clear
    tvbuild, specframe(sp_tool) `BUILD' frameout(out_tool)
    local e1_sig_t "`r(datasignature)'"
    local e1_src_t "`r(source_names)'"
    local e1_exp_t "`r(exposure_vars)'"
    frame change out_tool
    quietly save "`work'/tvs_tool.dta", replace
    frame change `_here'

    _tvs_handspec sp_hand "`work'/tvs_srcA.dta" "`work'/tvs_srcB.dta"
    quietly use "`work'/tvs_master.dta", clear
    tvbuild, specframe(sp_hand) `BUILD' frameout(out_hand)
    local e1_sig_h "`r(datasignature)'"
    local e1_src_h "`r(source_names)'"
    local e1_exp_h "`r(exposure_vars)'"
    frame change out_hand
    quietly save "`work'/tvs_hand.dta", replace
    frame change `_here'

    quietly use "`work'/tvs_tool.dta", clear
    quietly cf _all using "`work'/tvs_hand.dta", verbose
    local e1_d = r(Nsum)
}
local rc = _rc
_tvs_check `=(`rc' == 0 & `e1_d' == 0 & "`e1_sig_t'" == "`e1_sig_h'" & ///
    "`e1_src_t'" == "`e1_src_h'" & "`e1_exp_t'" == "`e1_exp_h'" & ///
    "`e1_sig_t'" != "")' ///
    "E1 tvspec and a hand-built frame commit identical output" ///
    "rc=`rc' cf=`e1_d' sig=`e1_sig_t'/`e1_sig_h' src=|`e1_src_t'|/|`e1_src_h'| exp=|`e1_exp_t'|/|`e1_exp_h'|"

* E2: the two manifests agree row for row on what ran. The output frames being
* equal does not by itself prove the two plans were the same plan; the manifest
* is the record of the stages, and it names the sources and the counts.
_tvs_reset
local e2_d = -1
capture erase "`work'/tvs_mt.dta"
capture erase "`work'/tvs_mh.dta"
capture noisily {
    local _here "`c(frame)'"
    _tvs_toolspec sp_tool "`work'/tvs_srcA.dta" "`work'/tvs_srcB.dta"
    quietly use "`work'/tvs_master.dta", clear
    tvbuild, specframe(sp_tool) `BUILD' frameout(out_tool)
    frame change out_tool_manifest
    quietly keep stage source_name input_vars output_vars n_input n_output n_persons
    quietly save "`work'/tvs_mt.dta", replace
    frame change `_here'

    _tvs_handspec sp_hand "`work'/tvs_srcA.dta" "`work'/tvs_srcB.dta"
    quietly use "`work'/tvs_master.dta", clear
    tvbuild, specframe(sp_hand) `BUILD' frameout(out_hand)
    frame change out_hand_manifest
    quietly keep stage source_name input_vars output_vars n_input n_output n_persons
    quietly save "`work'/tvs_mh.dta", replace
    frame change `_here'

    quietly use "`work'/tvs_mt.dta", clear
    quietly cf _all using "`work'/tvs_mh.dta", verbose
    local e2_d = r(Nsum)
}
local rc = _rc
_tvs_check `=(`rc' == 0 & `e2_d' == 0)' ///
    "E2 the two routes produce the same provenance manifest" ///
    "rc=`rc' cf=`e2_d'"


**# ===== S: the schema =====

* S1: the declared storage types, checked against a fixed expected list rather
* than against the hand-built frame. Anchoring the schema outside the
* comparison is what keeps E1 from passing while both routes are wrong.
_tvs_reset
local s1_bad ""
capture noisily {
    tvspec create sp_tool, replace
    local _here "`c(frame)'"
    frame change sp_tool
    foreach _spec in source_name:str32 source_kind:str12 source_frame:str32 ///
        source_file:strL start_var:str32 stop_var:str32 input_vars:strL ///
        output_vars:strL reference:double rate_vars:strL total_vars:strL ///
        cumulative_vars:strL reference_label:strL variable_label:strL ///
        description:strL {
        local _v = substr("`_spec'", 1, strpos("`_spec'", ":") - 1)
        local _want = substr("`_spec'", strpos("`_spec'", ":") + 1, .)
        capture confirm variable `_v'
        if _rc local s1_bad "`s1_bad' `_v'(absent)"
        else {
            local _got : type `_v'
            if "`_got'" != "`_want'" local s1_bad "`s1_bad' `_v'(`_got'!=`_want')"
        }
    }
    local s1_char : char _dta[tvbuild_spec_version]
    local s1_n = _N
    frame change `_here'
}
local rc = _rc
_tvs_check `=(`rc' == 0 & "`s1_bad'" == "" & "`s1_char'" == "1" & `s1_n' == 0)' ///
    "S1 create declares the exact typed schema and stamps the version" ///
    "rc=`rc' bad=|`s1_bad'| char=`s1_char' rows=`s1_n'"

* S2: create without replace on an existing frame is r(110), and the frame's
* contents survive.
_tvs_reset
local s2_rows = -1
capture noisily {
    _tvs_toolspec sp_tool "`work'/tvs_srcA.dta" "`work'/tvs_srcB.dta"
}
local setup_rc = _rc
capture noisily tvspec create sp_tool
local rc = _rc
_tvs_rows sp_tool
local s2_rows = r(n)
_tvs_check `=(`setup_rc' == 0 & `rc' == 110 & `s2_rows' == 2)' ///
    "S2 create without replace is r(110) and keeps the rows" ///
    "setup_rc=`setup_rc' rc=`rc' rows=`s2_rows'"

* S3: create WITH replace starts empty.
capture noisily tvspec create sp_tool, replace
local rc = _rc
_tvs_rows sp_tool
local s3_rows = r(n)
_tvs_check `=(`rc' == 0 & `s3_rows' == 0)' ///
    "S3 create with replace starts from an empty frame" ///
    "rc=`rc' rows=`s3_rows'"


**# ===== A: add refusals =====

* A1: add against a frame with no schema characteristic is r(198) and does NOT
* create one. Auto-creating here would silently discard rows the caller thought
* the frame already held.
_tvs_reset
capture frame drop sp_bad
frame create sp_bad
frame sp_bad {
    quietly set obs 4
    quietly generate long caller_sentinel = _n
}
capture noisily tvspec add sp_bad, name(x) frame(f) start(a) stop(b) ///
    exposure(c) generate(d) reference(0)
local rc = _rc
_tvs_rows sp_bad
local a1_rows = r(n)
local a1_kept = 0
capture noisily {
    local _here "`c(frame)'"
    frame change sp_bad
    capture confirm variable caller_sentinel
    if _rc == 0 local a1_kept = 1
    frame change `_here'
}
_tvs_check `=(`rc' == 198 & `a1_rows' == 4 & `a1_kept')' ///
    "A1 add to a frame without the schema is r(198) and changes nothing" ///
    "rc=`rc' rows=`a1_rows' kept=`a1_kept'"

* A2: add to a frame that does not exist is r(111).
_tvs_reset
capture noisily tvspec add sp_tool, name(x) frame(f) start(a) stop(b) ///
    exposure(c) generate(d) reference(0)
local rc = _rc
_tvs_hasframe sp_tool
local a2_made = r(yes)
_tvs_check `=(`rc' == 111 & !`a2_made')' ///
    "A2 add to a missing frame is r(111) and creates nothing" ///
    "rc=`rc' created=`a2_made'"

* A3-A8: one refusal apiece. Each also asserts the frame did not grow -- a
* guard that errors AFTER appending would leave a half-written row behind, and
* the rc alone cannot tell the two apart.
_tvs_reset
capture noisily tvspec create sp_tool, replace
local base_rc = _rc

local a_lab3 "A3 both locators is r(198)"
local a_opt3 "name(x) frame(f) using(z.dta) start(a) stop(b) exposure(c) generate(d) reference(0)"
local a_lab4 "A4 no locator is r(198)"
local a_opt4 "name(x) start(a) stop(b) exposure(c) generate(d) reference(0)"
local a_lab5 "A5 an unknown kind() is r(198)"
local a_opt5 "name(x) frame(f) start(a) stop(b) exposure(c) generate(d) reference(0) kind(bogus)"
local a_lab6 "A6 exposure()/generate() count mismatch is r(198)"
local a_opt6 "name(x) frame(f) start(a) stop(b) exposure(c e) generate(d) reference(0)"
local a_lab7 "A7 an episodes source without reference() is r(198)"
local a_opt7 "name(x) frame(f) start(a) stop(b) exposure(c) generate(d)"
local a_lab8 "A8 an intervals source with reference() is r(198)"
local a_opt8 "name(x) frame(f) start(a) stop(b) exposure(c) generate(d) reference(0) kind(intervals)"

forvalues k = 3/8 {
    capture noisily tvspec add sp_tool, `a_opt`k''
    local rc = _rc
    _tvs_rows sp_tool
    local nrows = r(n)
    _tvs_check `=(`base_rc' == 0 & `rc' == 198 & `nrows' == 0)' ///
        "`a_lab`k''" "rc=`rc' rows=`nrows'"
}

* A9: a source_name longer than its str32 column is refused, not truncated.
* Truncation is the silent failure this check exists for: the shortened name is
* still a legal Stata name, so the build would succeed against a source the
* caller never described.
capture noisily tvspec add sp_tool, name(abcdefghijklmnopqrstuvwxyz0123456) ///
    frame(f) start(a) stop(b) exposure(c) generate(d) reference(0)
local rc = _rc
_tvs_rows sp_tool
local a9_rows = r(n)
_tvs_check `=(`rc' == 198 & `a9_rows' == 0 & ///
    strlen("abcdefghijklmnopqrstuvwxyz0123456") == 33)' ///
    "A9 an over-long name() is refused rather than truncated" ///
    "rc=`rc' rows=`a9_rows'"

* A10: a cell containing a double quote is refused rather than written.
*
* The guard covers a backtick, a dollar sign, and a double quote, but only the
* double quote can be delivered to it from a command line, and that is worth
* recording rather than working around:
*
*   backtick  - `description("pre`=char(96)'post")' never reaches the command.
*               Stata's own parser rejects the line with r(132), "too few
*               quotes", while tokenising it.
*   dollar    - arrives, then vanishes. `$post' is expanded as a global by the
*               time any guard runs, so description() holds "pre" and there is
*               nothing left to detect. Escaping it as \$ does not help: the
*               asis-strip step (`local description `description'') re-scans
*               and expands it there instead.
*   quote     - reaches the option intact when passed in compound quotes, so
*               this is the one the guard can actually be tested against.
*
* The guard stays for all three: it is a backstop matching the cell screen in
* _tvbuild_normalize_spec, and it costs nothing. The test asserts the reachable
* case and does not pretend to cover the other two.
capture noisily tvspec add sp_tool, name(x) frame(f) start(a) stop(b) ///
    exposure(c) generate(d) reference(0) description(`"prefix"suffix"')
local rc = _rc
_tvs_rows sp_tool
local a10_rows = r(n)
_tvs_check `=(`rc' == 198 & `a10_rows' == 0)' ///
    "A10 a cell containing a double quote is refused, no row written" ///
    "rc=`rc' rows=`a10_rows'"

* A11: a bad subcommand is r(198).
capture noisily tvspec bogus sp_tool
local rc = _rc
_tvs_check `=(`rc' == 198)' "A11 an unknown subcommand is r(198)" "rc=`rc'"


**# ===== O: row order =====

* O1: row order is semantic, and the order that matters is the order tvbuild
* ACTS on. Three sources are added in a known order and the check is made
* against the generated-variable order in the COMMITTED frame, not against the
* order the rows sit in the specification.
_tvs_reset
local o1_expo "unset"
local o1_order "unset"
capture noisily {
    tvspec create sp_order, replace
    tvspec add sp_order, name(third) using("`work'/tvs_srcB.dta") ///
        start(b_start) stop(b_stop) exposure(benzo) reference(0) ///
        generate(tv_c) referencelabel("no") label("C")
    tvspec add sp_order, name(first) using("`work'/tvs_srcA.dta") ///
        start(a_start) stop(a_stop) exposure(drug) reference(0) ///
        generate(tv_a) referencelabel("no") label("A")
    local _here "`c(frame)'"
    frame change sp_order
    local o1_order = source_name[1] + " " + source_name[2]
    frame change `_here'

    quietly use "`work'/tvs_master.dta", clear
    tvbuild, specframe(sp_order) `BUILD' frameout(out_order)
    local o1_expo "`r(exposure_vars)'"
}
local rc = _rc
_tvs_check `=(`rc' == 0 & "`o1_order'" == "third first" & ///
    "`o1_expo'" == "tv_c tv_a")' ///
    "O1 add appends, and the append order drives tvbuild's output order" ///
    "rc=`rc' rows=|`o1_order'| exposure_vars=|`o1_expo'|"


**# ===== L: list =====

* L1: list on an empty frame renders without error and reports zero.
_tvs_reset
local l1_n = -1
capture noisily {
    tvspec create sp_tool, replace
    tvspec list sp_tool
    local l1_n = r(n_sources)
    local l1_names "`r(source_names)'"
}
local rc = _rc
_tvs_check `=(`rc' == 0 & `l1_n' == 0 & "`l1_names'" == "")' ///
    "L1 list renders an empty specification frame" ///
    "rc=`rc' n=`l1_n' names=|`l1_names'|"

* L2: list on a populated frame reports the names in row order.
_tvs_reset
local l2_n = -1
local l2_names "unset"
capture noisily {
    _tvs_toolspec sp_tool "`work'/tvs_srcA.dta" "`work'/tvs_srcB.dta"
    tvspec list sp_tool
    local l2_n = r(n_sources)
    local l2_names "`r(source_names)'"
}
local rc = _rc
_tvs_check `=(`rc' == 0 & `l2_n' == 2 & "`l2_names'" == "antidep benzo")' ///
    "L2 list reports the sources in row order" ///
    "rc=`rc' n=`l2_n' names=|`l2_names'|"

* L3: list on a frame without the schema is r(198).
_tvs_reset
capture frame drop sp_bad
frame create sp_bad
capture noisily tvspec list sp_bad
local rc = _rc
_tvs_check `=(`rc' == 198)' ///
    "L3 list on a frame without the schema is r(198)" "rc=`rc'"


**# ===== P: optional columns and the intervals kind =====

* P1: omitting every optional column leaves those cells empty and tvbuild still
* builds. The optional columns must be present-but-empty, not absent: the
* normalizer refuses an unknown column and requires the nine mandatory ones.
_tvs_reset
local p1_empty = 0
capture noisily {
    tvspec create sp_tool, replace
    tvspec add sp_tool, name(antidep) using("`work'/tvs_srcA.dta") ///
        start(a_start) stop(a_stop) exposure(drug) reference(0) generate(tv_drug)
    local _here "`c(frame)'"
    frame change sp_tool
    local p1_empty = (rate_vars[1] == "" & total_vars[1] == "" & ///
        cumulative_vars[1] == "" & reference_label[1] == "" & ///
        variable_label[1] == "" & description[1] == "")
    frame change `_here'
    quietly use "`work'/tvs_master.dta", clear
    tvbuild, specframe(sp_tool) `BUILD' frameout(out_tool)
}
local rc = _rc
_tvs_check `=(`rc' == 0 & `p1_empty')' ///
    "P1 omitted optional columns are empty and tvbuild still builds" ///
    "rc=`rc' empty=`p1_empty'"

* P2: an intervals source with a rate quantity round-trips through tvbuild.
* This is the case the plan's one-name-per-option syntax could not express, so
* it is the one most likely to have been left untested.
_tvs_reset
capture frame drop labfr
frame create labfr
frame labfr {
    clear
    quietly input long pid double s double e double egfr
        1 100 500 60
        2 120 480 70
        3  90 500 45
    end
    * The declaration and the data must agree: tvbuild refuses a rate() cell
    * whose source variable does not carry the matching characteristic, with
    * r(498). That rule belongs to tvbuild, not tvspec -- which is the design,
    * and the reason this fixture has to carry the characteristic.
    char egfr[tvtools_quantity] "rate"
}
local p2_expo "unset"
capture noisily {
    tvspec create sp_tool, replace
    tvspec add sp_tool, name(labs) frame(labfr) start(s) stop(e) ///
        exposure(egfr) generate(tv_egfr) kind(intervals) rate(egfr)
    quietly use "`work'/tvs_master.dta", clear
    tvbuild, specframe(sp_tool) `BUILD' frameout(out_tool)
    local p2_expo "`r(rate_vars)'"
}
local rc = _rc
_tvs_check `=(`rc' == 0 & "`p2_expo'" == "tv_egfr")' ///
    "P2 an intervals source with a rate quantity builds" ///
    "rc=`rc' rate_vars=|`p2_expo'|"


**# ===== Cleanup and summary =====
_tvs_reset
foreach f in tvs_master tvs_srcA tvs_srcB tvs_tool tvs_hand tvs_mt tvs_mh {
    capture erase "`work'/`f'.dta"
}

local pass_count = $TVS_PASS
local fail_count = $TVS_FAIL
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvspec Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvspec tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: $TVS_FAILED"
    exit 1
}
display as result "ALL TESTS PASSED"
