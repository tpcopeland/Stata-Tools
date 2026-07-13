/*******************************************************************************
* validation_audit_tvmerge.do
*
* Audit-closure known-answer checks for tvmerge naming, quantity algebra,
* payload preservation, interval diagnostics, and strict input integrity.
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-07-13
*******************************************************************************/

clear all
set more off
set varabbrev off
version 16.0

capture log close _all
quietly log using "validation_audit_tvmerge.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

capture program drop _audit_log_has
program define _audit_log_has, rclass
    syntax , logfile(string) needle(string)
    local content = fileread("`logfile'")
    return scalar found = strpos(`"`content'"', `"`needle'"') > 0
end

display as result "tvtools QA: audit closure for tvmerge -- $S_DATE $S_TIME"

**# Shared naming fixtures
quietly {
    clear
    input long id double(s1 e1) byte exp1 int payload
        1 1 10 1 10
    end
    tempfile name1
    save `name1'

    clear
    input long id double(s2 e2) byte exp2 int payload
        1 1 10 2 20
    end
    tempfile name2
    save `name2'

    use `name1', clear
    rename exp1 art
    tempfile prefix1
    save `prefix1'

    use `name2', clear
    rename exp2 other
    tempfile prefix2
    save `prefix2'
}

**# 1. Every output-name collision is rejected before caller mutation
local ++test_count
capture noisily {
    clear
    input int sentinel str8 note
        731 "original"
    end
    capture noisily tvmerge "`name1'" "`name2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) generate(dup dup)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    capture noisily tvmerge "`name1'" "`name2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) generate(id out2)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    capture noisily tvmerge "`name1'" "`name2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) generate(start out2)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    capture noisily tvmerge "`name1'" "`name2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) generate(stop out2)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    capture noisily tvmerge "`name1'" "`name2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        generate(payload_ds1 out2) keep(payload)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    capture noisily tvmerge "`prefix1'" "`prefix2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(art other) prefix(st)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    * These paths intentionally do not exist. The option error must win,
    * proving that collision preflight occurs before source-file access.
    capture noisily tvmerge ///
        "/tmp/tvmerge_absent_preflight_a_731" ///
        "/tmp/tvmerge_absent_preflight_b_731", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) generate(dup dup)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    foreach internal_name in __tvm_mobs __tvm_uobs _first {
        capture noisily tvmerge ///
            "/tmp/tvmerge_absent_preflight_a_731" ///
            "/tmp/tvmerge_absent_preflight_b_731", id(id) ///
            start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
            generate(`internal_name' safe_out)
        local cmdrc = _rc
        assert `cmdrc' == 198
        assert _N == 1 & sentinel == 731 & note == "original"
    }

    capture noisily tvmerge ///
        "/tmp/tvmerge_absent_preflight_a_731" ///
        "/tmp/tvmerge_absent_preflight_b_731", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) keep(id)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    local keep28 "kkkkkkkkkkkkkkkkkkkkkkkkkkkk"
    assert strlen("`keep28'") == 28
    capture noisily tvmerge ///
        "/tmp/tvmerge_absent_preflight_a_731" ///
        "/tmp/tvmerge_absent_preflight_b_731", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        keep(`keep28') startname(`keep28'_ds1)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    capture noisily tvmerge ///
        "/tmp/tvmerge_absent_preflight_a_731" ///
        "/tmp/tvmerge_absent_preflight_b_731", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        keep(payload) stopname(payload_ds2)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    * Structural roles are positional and must be distinct in each source.
    capture noisily tvmerge ///
        "/tmp/tvmerge_absent_preflight_a_731" ///
        "/tmp/tvmerge_absent_preflight_b_731", id(id) ///
        start(shared s2) stop(e1 e2) exposure(shared exp2)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    capture noisily tvmerge ///
        "/tmp/tvmerge_absent_preflight_a_731" ///
        "/tmp/tvmerge_absent_preflight_b_731", id(id) ///
        start(shared s2) stop(shared e2) exposure(exp1 exp2)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"

    local keep29 "kkkkkkkkkkkkkkkkkkkkkkkkkkkkk"
    assert strlen("`keep29'") == 29
    capture noisily tvmerge ///
        "/tmp/tvmerge_absent_preflight_a_731" ///
        "/tmp/tvmerge_absent_preflight_b_731", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) keep(`keep29')
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 731 & note == "original"
}
if _rc == 0 {
    display as result "  PASS: naming/keep preflight precedes file access and is transactional"
    local ++pass_count
}
else {
    display as error "  FAIL: output-name preflight/rollback (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' names"
}

**# 1b. Exactly 32-character generated names remain legal
local ++test_count
capture noisily {
    local name32a "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    local name32b "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    assert strlen("`name32a'") == 32 & strlen("`name32b'") == 32
    tvmerge "`name1'" "`name2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        generate(`name32a' `name32b')
    confirm variable `name32a'
    confirm variable `name32b'
    assert _N == 1

    local keep28 "kkkkkkkkkkkkkkkkkkkkkkkkkkkk"
    assert strlen("`keep28'") == 28
    use `name1', clear
    generate int `keep28' = 281
    tempfile keep_boundary1
    save `keep_boundary1'
    use `name2', clear
    generate int `keep28' = 282
    tempfile keep_boundary2
    save `keep_boundary2'
    tvmerge "`keep_boundary1'" "`keep_boundary2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) keep(`keep28')
    confirm variable `keep28'_ds1
    confirm variable `keep28'_ds2
    assert `keep28'_ds1 == 281 & `keep28'_ds2 == 282
}
if _rc == 0 {
    display as result "  PASS: 32-character output-name boundary is accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: 32-character output-name boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' name32"
}

**# Quantity fixtures: a common 10-day row split into 4 and 6 days
quietly {
    clear
    input long id double(s1 e1 ratev)
        1 1 10 2
    end
    char ratev[tvtools_quantity] "rate"
    tempfile qrate
    save `qrate'

    clear
    input long id double(s2 e2 totalv)
        1 1 10 100
    end
    char totalv[tvtools_quantity] "total"
    tempfile qtotal
    save `qtotal'

    clear
    input long id double(s3 e3 cumv)
        1 1 10 10
    end
    char cumv[tvtools_quantity] "cumulative"
    char cumv[tvtools_history_point] "start"
    tempfile qcum
    save `qcum'

    clear
    input long id double(s4 e4) byte marker
        1 1  4 1
        1 5 10 2
    end
    tempfile qsplit
    save `qsplit'
}

**# 2. Explicit rate/total/cumulative semantics are exact under splitting
local ++test_count
capture noisily {
    tvmerge "`qrate'" "`qtotal'" "`qcum'" "`qsplit'", id(id) ///
        start(s1 s2 s3 s4) stop(e1 e2 e3 e4) ///
        exposure(ratev totalv cumv marker) ///
        rate(ratev) total(totalv) cumulative(cumv) ///
        generate(rate_out total_out cum_out marker_out)
    local returned_rate "`r(rate_vars)'"
    local returned_total "`r(total_vars)'"
    local returned_cumulative "`r(cumulative_vars)'"
    local returned_n_rate = r(n_rate)
    local returned_n_total = r(n_total)
    local returned_n_cumulative = r(n_cumulative)
    local returned_n_categorical = r(n_categorical)
    local returned_n_invalid = r(n_invalid)
    local returned_n_invalid_ds1 = r(n_invalid_ds1)
    local returned_n_input_overlaps = r(n_input_overlaps)
    local returned_n_input_overlaps_ds1 = r(n_input_overlaps_ds1)
    local returned_n_input_overlaps_ds2 = r(n_input_overlaps_ds2)
    local returned_n_input_overlaps_ds3 = r(n_input_overlaps_ds3)
    local returned_n_input_overlaps_ds4 = r(n_input_overlaps_ds4)
    local returned_n_duplicates = r(n_duplicates_dropped)
    assert _N == 2
    sort start
    assert start[1] == 1 & stop[1] == 4
    assert start[2] == 5 & stop[2] == 10
    assert rate_out == 2
    assert total_out[1] == 40 & total_out[2] == 60
    assert cum_out == 10
    quietly summarize total_out, meanonly
    assert r(sum) == 100
    local qratechar : char rate_out[tvtools_quantity]
    local qtotalchar : char total_out[tvtools_quantity]
    local qcumchar : char cum_out[tvtools_quantity]
    local qhistchar : char cum_out[tvtools_history_point]
    assert "`qratechar'" == "rate"
    assert "`qtotalchar'" == "total"
    assert "`qcumchar'" == "cumulative"
    assert "`qhistchar'" == "start"
    assert "`returned_rate'" == "rate_out"
    assert "`returned_total'" == "total_out"
    assert "`returned_cumulative'" == "cum_out"
    assert `returned_n_rate' == 1
    assert `returned_n_total' == 1
    assert `returned_n_cumulative' == 1
    assert `returned_n_categorical' == 1
    assert `returned_n_invalid' == 0 & `returned_n_invalid_ds1' == 0
    assert `returned_n_input_overlaps' == 0 & ///
        `returned_n_input_overlaps_ds1' == 0
    assert `returned_n_input_overlaps_ds2' == 0
    assert `returned_n_input_overlaps_ds3' == 0
    assert `returned_n_input_overlaps_ds4' == 0
    assert `returned_n_duplicates' == 0
}
if _rc == 0 {
    display as result "  PASS: rate invariant, total conserved, cumulative carried"
    local ++pass_count
}
else {
    display as error "  FAIL: explicit quantity algebra (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' quantities"
}

**# 2b. Declared algebra must agree with source metadata
local ++test_count
capture noisily {
    clear
    input int sentinel str8 note
        732 "original"
    end
    capture noisily tvmerge "`qrate'" "`qtotal'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(ratev totalv) ///
        total(ratev) generate(rate_out total_out)
    local cmdrc = _rc
    assert `cmdrc' == 498
    assert _N == 1 & sentinel == 732 & note == "original"

    capture noisily tvmerge "`qrate'" "`qtotal'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(ratev totalv) ///
        generate(rate_out total_out)
    local cmdrc = _rc
    assert `cmdrc' == 498
    assert _N == 1 & sentinel == 732 & note == "original"
}
if _rc == 0 {
    display as result "  PASS: conflicting quantity metadata is rejected transactionally"
    local ++pass_count
}
else {
    display as error "  FAIL: quantity metadata conflict (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' quantity_metadata"
}

**# 2c. Cumulative history-point metadata is mandatory, not advisory
quietly {
    clear
    input long id double(s2 e2 cumv)
        1 1 10 10
    end
    char cumv[tvtools_quantity] "cumulative"
    tempfile qcum_nohistory
    save `qcum_nohistory'
}

local ++test_count
capture noisily {
    clear
    input int sentinel str8 note
        733 "original"
    end
    capture noisily tvmerge "`qrate'" "`qcum_nohistory'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(ratev cumv) ///
        rate(1) cumulative(2) generate(rate_out cum_out)
    local cmdrc = _rc
    assert `cmdrc' == 498
    assert _N == 1 & sentinel == 733 & note == "original"
}
if _rc == 0 {
    display as result "  PASS: cumulative history-point metadata is required"
    local ++pass_count
}
else {
    display as error "  FAIL: cumulative history-point contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' cumulative_history"
}

**# 2d. Repeated raw names remain position-specific under a later split
quietly {
    clear
    input long id double(s1 e1 tv_exposure)
        1 1 10 7
    end
    tempfile duplicate_q1
    save `duplicate_q1'

    clear
    input long id double(s2 e2 tv_exposure)
        1 1 10 100
    end
    char tv_exposure[tvtools_quantity] "total"
    tempfile duplicate_q2
    save `duplicate_q2'

    clear
    input long id double(s3 e3 tv_exposure)
        1 1  2 1
        1 3  5 2
        1 6 10 3
    end
    tempfile duplicate_q3
    save `duplicate_q3'
}

local ++test_count
capture noisily {
    tvmerge "`duplicate_q1'" "`duplicate_q2'" "`duplicate_q3'", id(id) ///
        start(s1 s2 s3) stop(e1 e2 e3) ///
        exposure(tv_exposure tv_exposure tv_exposure) total(2)
    local totalvars "`r(total_vars)'"
    local ntotal = r(n_total)
    local ninputoverlap = r(n_input_overlaps)
    assert _N == 3
    sort start
    assert tv_exposure_1 == 7
    assert tv_exposure_2[1] == 20
    assert tv_exposure_2[2] == 30
    assert tv_exposure_2[3] == 50
    assert tv_exposure_3[1] == 1
    assert tv_exposure_3[2] == 2
    assert tv_exposure_3[3] == 3
    quietly summarize tv_exposure_2, meanonly
    assert r(sum) == 100
    assert "`totalvars'" == "tv_exposure_2"
    assert `ntotal' == 1 & `ninputoverlap' == 0
}
if _rc == 0 {
    display as result "  PASS: duplicate raw names do not duplicate total allocation"
    local ++pass_count
}
else {
    display as error "  FAIL: duplicate raw-name quantity mapping (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' duplicate_quantity_names"
}

**# 2e. Totals are rejected when any input contains overlapping rows
quietly {
    clear
    input long id double(s4 e4) byte marker
        1 1  6 1
        1 5 10 2
    end
    tempfile overlapping_splitter
    save `overlapping_splitter'
}

local ++test_count
capture noisily {
    clear
    input int sentinel str8 note
        734 "original"
    end
    capture noisily tvmerge "`qtotal'" "`overlapping_splitter'", id(id) ///
        start(s2 s4) stop(e2 e4) exposure(totalv marker) ///
        total(1) generate(total_out marker_out)
    local cmdrc = _rc
    assert `cmdrc' == 459
    assert _N == 1 & sentinel == 734 & note == "original"
}
if _rc == 0 {
    display as result "  PASS: overlapping inputs cannot silently inflate totals"
    local ++pass_count
}
else {
    display as error "  FAIL: total conservation overlap gate (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' total_overlap"
}

**# 3. continuous() is a warned compatibility alias for total()
local ++test_count
capture noisily {
    tempfile aliaslog
    quietly log using `aliaslog', text replace name(_aliaslog)
    capture noisily tvmerge "`qrate'" "`qtotal'" "`qcum'" "`qsplit'", id(id) ///
        start(s1 s2 s3 s4) stop(e1 e2 e3 e4) ///
        exposure(ratev totalv cumv marker) ///
        rate(ratev) continuous(totalv) cumulative(cumv) ///
        generate(rate_out total_out cum_out marker_out)
    local cmdrc = _rc
    local totalvars ""
    local continuousvars ""
    local ncontinuous = .
    if `cmdrc' == 0 {
        local totalvars "`r(total_vars)'"
        local continuousvars "`r(continuous_vars)'"
        local ncontinuous = r(n_continuous)
    }
    log close _aliaslog
    assert `cmdrc' == 0
    sort start
    assert total_out[1] == 40 & total_out[2] == 60
    assert "`totalvars'" == "total_out"
    assert "`continuousvars'" == "total_out" & `ncontinuous' == 1
    _audit_log_has, logfile(`aliaslog') ///
        needle("continuous() is deprecated; use total()")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: legacy continuous alias is explicit and deterministic"
    local ++pass_count
}
else {
    display as error "  FAIL: continuous compatibility alias (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' continuous_alias"
    capture log close _aliaslog
}

**# 4. Requested payload differences survive final deduplication
quietly {
    clear
    input long id double(s1 e1) byte exp1 int payload str5 tag byte code
        1 1 10 1 10 "left"  .
        1 1 10 1 20 "right" 1
    end
    label define payload_code 1 "One"
    label values code payload_code
    tempfile payload1
    save `payload1'

    clear
    input long id double(s2 e2) byte exp2
        1 1 10 2
    end
    tempfile payload2
    save `payload2'
}

local ++test_count
capture noisily {
    tvmerge "`payload1'" "`payload2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        keep(payload tag code)
    assert _N == 2
    sort payload_ds1
    assert payload_ds1[1] == 10 & payload_ds1[2] == 20
    assert tag_ds1[1] == "left" & tag_ds1[2] == "right"
    assert missing(code_ds1[1]) & code_ds1[2] == 1
    assert "`: label (code_ds1) 1'" == "One"
    assert exp1 == 1 & exp2 == 2
}
if _rc == 0 {
    display as result "  PASS: final dedup preserves distinct requested payload"
    local ++pass_count
}
else {
    display as error "  FAIL: requested payload preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' payload"
}

**# 4b. Caller-owned frames survive both success and a late failure
local ++test_count
capture noisily {
    capture frame drop __tvm_master
    capture frame drop __tvm_using
    capture frame drop __tvm_out
    frame create __tvm_master
    frame __tvm_master: set obs 1
    frame __tvm_master: generate long sentinel = 1383
    frame create __tvm_using
    frame __tvm_using: set obs 1
    frame __tvm_using: generate long sentinel = 1385
    frame create __tvm_out
    frame __tvm_out: set obs 1
    frame __tvm_out: generate long sentinel = 1405

    tvmerge "`name1'" "`name2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2)
    frame __tvm_master: assert _N == 1 & sentinel == 1383
    frame __tvm_using: assert _N == 1 & sentinel == 1385
    frame __tvm_out: assert _N == 1 & sentinel == 1405

    generate long caller_sentinel = 511
    capture noisily tvmerge "`name1'" "`name2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        saveas("/dev/null/tvmerge_late_failure.dta") replace
    local cmdrc = _rc
    assert `cmdrc' == 603
    assert _N == 1 & caller_sentinel == 511
    confirm variable exp1
    confirm variable exp2
    frame __tvm_master: assert _N == 1 & sentinel == 1383
    frame __tvm_using: assert _N == 1 & sentinel == 1385
    frame __tvm_out: assert _N == 1 & sentinel == 1405

    frame drop __tvm_master
    frame drop __tvm_using
    frame drop __tvm_out
}
if _rc == 0 {
    display as result "  PASS: caller-owned frame names survive success and late failure"
    local ++pass_count
}
else {
    display as error "  FAIL: caller frame ownership (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' caller_frames"
    capture frame drop __tvm_master
    capture frame drop __tvm_using
    capture frame drop __tvm_out
}

**# 5. Nested intervals use a running union and all-active overlap pairs
quietly {
    clear
    input long id double(s1 e1) byte exp1
        1 50  60 1
        1  1 100 1
        1 10  20 1
    end
    tempfile nested1
    save `nested1'

    clear
    input long id double(s2 e2) byte exp2
        1 1 100 2
    end
    tempfile nested2
    save `nested2'
}

local ++test_count
capture noisily {
    tvmerge "`nested1'" "`nested2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        validatecoverage validateoverlap
    local gaps = r(n_gaps)
    local overlaps = r(n_overlaps)
    assert _N == 3
    assert `gaps' == 0
    assert `overlaps' == 2
}
if _rc == 0 {
    display as result "  PASS: nested diagnostics use union coverage and active pairs"
    local ++pass_count
}
else {
    display as error "  FAIL: nested coverage/overlap diagnostics (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' diagnostics"
}

**# 6. Malformed required rows fail by default and drop only by explicit opt-in
quietly {
    clear
    set obs 6
    generate long id = 1
    generate double s1 = 1
    generate double e1 = 10
    generate double exp1 = 1
    replace id = . in 2
    replace exp1 = 9 in 2
    replace s1 = . in 3
    replace exp1 = 9 in 3
    replace s1 = 8 in 4
    replace e1 = 4 in 4
    replace exp1 = 9 in 4
    replace s1 = 1.5 in 5
    replace e1 = 4 in 5
    replace exp1 = 9 in 5
    replace exp1 = . in 6
    tempfile invalid1
    save `invalid1'

    clear
    input long id double(s2 e2) byte exp2
        1 1 10 2
    end
    tempfile invalid2
    save `invalid2'
}

local ++test_count
capture noisily {
    clear
    input int sentinel str8 note
        915 "original"
    end
    capture noisily tvmerge "`invalid1'" "`invalid2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2)
    local cmdrc = _rc
    assert `cmdrc' == 498
    assert _N == 1 & sentinel == 915 & note == "original"

    tvmerge "`invalid1'" "`invalid2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2) dropinvalid
    local invalid_ds1 = r(n_invalid_ds1)
    local invalid_ds2 = r(n_invalid_ds2)
    local overlap_ds1 = r(n_input_overlaps_ds1)
    local overlap_ds2 = r(n_input_overlaps_ds2)
    matrix invalid_flow = r(flow)
    assert _N == 1
    assert exp1 == 1 & exp2 == 2
    assert r(n_invalid) == 5
    assert r(n_invalid_id) == 1
    assert r(n_invalid_dates) == 2
    assert r(n_invalid_order) == 1
    assert r(n_invalid_exposure) == 1
    assert `invalid_ds1' == 5 & `invalid_ds2' == 0
    assert `overlap_ds1' == 0 & `overlap_ds2' == 0
    assert rowsof(invalid_flow) == 2 & colsof(invalid_flow) == 3
    assert invalid_flow[2,1] == 7 & invalid_flow[2,2] == 1
}
if _rc == 0 {
    display as result "  PASS: malformed rows are strict with exact dropinvalid accounting"
    local ++pass_count
}
else {
    display as error "  FAIL: malformed-input policy/accounting (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' invalid"
}

**# 7. Non-numeric bounds fail explicitly and transactionally
quietly {
    clear
    input long id str2 s1 double e1 byte exp1
        1 "1" 10 1
    end
    tempfile string1
    save `string1'
}

local ++test_count
capture noisily {
    clear
    input int sentinel str8 note
        916 "original"
    end
    capture noisily tvmerge "`string1'" "`invalid2'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(exp1 exp2)
    local cmdrc = _rc
    assert `cmdrc' == 109
    assert _N == 1 & sentinel == 916 & note == "original"
}
if _rc == 0 {
    display as result "  PASS: non-numeric bounds fail before mutation"
    local ++pass_count
}
else {
    display as error "  FAIL: numeric-bound validation/rollback (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' numeric_bounds"
}

**# 7b. Failure restores an observations-only caller dataset
local ++test_count
capture noisily {
    clear
    set obs 3
    assert _N == 3 & c(k) == 0
    capture noisily tvmerge "`qrate'" "`qtotal'", id(id) ///
        start(s1 s2) stop(e1 e2) exposure(ratev totalv) ///
        total(ratev) generate(rate_out total_out)
    local cmdrc = _rc
    assert `cmdrc' == 498
    assert _N == 3 & c(k) == 0
}
if _rc == 0 {
    display as result "  PASS: observations-only caller data are restored on failure"
    local ++pass_count
}
else {
    display as error "  FAIL: zero-variable caller rollback (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' empty_schema_rollback"
}

display "RESULT: validation_audit_tvmerge tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "FAILED_TESTS:`failed_tests'"
    exit 1
}
