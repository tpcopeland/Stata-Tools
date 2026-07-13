*! validation_audit_tvexpose.do
*! Exact regressions for the 12jul2026 comprehensive-audit tvexpose findings.

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "validation_audit_tvexpose.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVX_AUDIT_TESTS 0
global TVX_AUDIT_PASS 0
global TVX_AUDIT_FAIL 0
global TVX_AUDIT_FAILED ""

capture program drop _tvx_audit_record
program define _tvx_audit_record
    args name rc
    global TVX_AUDIT_TESTS = $TVX_AUDIT_TESTS + 1
    if `rc' == 0 {
        global TVX_AUDIT_PASS = $TVX_AUDIT_PASS + 1
    }
    else {
        global TVX_AUDIT_FAIL = $TVX_AUDIT_FAIL + 1
        global TVX_AUDIT_FAILED "$TVX_AUDIT_FAILED `name'"
    }
end

capture program drop _tvx_one_master
program define _tvx_one_master
    args lastday
    clear
    set obs 1
    generate long id = 1
    generate double entry = 1
    generate double exitdate = `lastday'
    format entry exitdate %td
end

**# C-01: grace never deletes cross-class person-time

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1  1 1
    1 10 10 2
    end
    format start stop %td
    save "`episodes'", replace
    _tvx_one_master 20
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        grace(30) generate(x)
    local uncovered = r(n_uncovered_days)
    generate double days = stop - start + 1
    quietly summarize days, meanonly
    assert r(sum) == 20
    assert x == 1 if start <= 1 & stop >= 1
    assert x == 0 if start <= 2 & stop >= 2
    assert x == 2 if start <= 10 & stop >= 10
    assert `uncovered' == 0
}
local captured_rc = _rc
_tvx_audit_record grace_cross_class `captured_rc'

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1  1 1
    1 10 10 1
    end
    save "`episodes'", replace
    _tvx_one_master 15
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        grace(8) generate(x)
    local exposed_time = r(exposed_time)
    quietly count if start <= 1 & stop >= 1 & x == 1
    assert r(N) == 1
    quietly count if start <= 10 & stop >= 10 & x == 1
    assert r(N) == 1
    quietly count if x == 0 & start <= 10 & stop >= 1
    assert r(N) == 0
    generate double days = stop - start + 1
    quietly summarize days, meanonly
    assert r(sum) == 15
    assert `exposed_time' == 10
}
local captured_rc = _rc
_tvx_audit_record grace_equal_boundary `captured_rc'

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1  1 1
    1 5  5 2
    end
    save "`episodes'", replace
    _tvx_one_master 8
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        grace(1=3 2=0) generate(x)
    quietly count if start <= 2 & stop >= 2 & x == 0
    assert r(N) == 1
    quietly count if start <= 5 & stop >= 5 & x == 2
    assert r(N) == 1
    generate double days = stop - start + 1
    quietly summarize days, meanonly
    assert r(sum) == 8
}
local captured_rc = _rc
_tvx_audit_record grace_class_specific `captured_rc'

**# C-02: recency has explicit units, exact boundaries, and an open tail

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 1
    generate double stop = 1
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 20
    datasignature set
    capture noisily tvexpose using "`episodes'", id(id) start(start) ///
        stop(stop) exposure(exposure) reference(0) entry(entry) ///
        exit(exitdate) recency(2 5) generate(rec)
    local cmdrc = _rc
    assert `cmdrc' == 198
    datasignature confirm
}
local captured_rc = _rc
_tvx_audit_record recency_unit_required `captured_rc'

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 1
    generate double stop = 1
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 100
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        recency(2 5) recencyunit(days) generate(rec)
    assert _N == 4
    assert start[1] == 1 & stop[1] == 1 & rec[1] == 1
    assert start[2] == 2 & stop[2] == 2 & rec[2] == 2
    assert start[3] == 3 & stop[3] == 5 & rec[3] == 3
    assert start[4] == 6 & stop[4] == 100 & rec[4] == 4
    assert "`r(recency_unit)'" == "days"
    assert "`r(recency_cutdays)'" == "2 5"
}
local captured_rc = _rc
_tvx_audit_record recency_days_exact `captured_rc'

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 1
    generate double stop = 1
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 370
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        recency(1) recencyunit(years) generate(rec)
    assert _N == 3
    assert start[1] == 1 & stop[1] == 1 & rec[1] == 1
    assert start[2] == 2 & stop[2] == 365 & rec[2] == 2
    assert start[3] == 366 & stop[3] == 370 & rec[3] == 3
    assert "`r(recency_cutdays)'" == "365"
}
local captured_rc = _rc
_tvx_audit_record recency_years_exact `captured_rc'

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1  1 1
    1 10 10 1
    end
    save "`episodes'", replace
    _tvx_one_master 20
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        recency(2 5) recencyunit(days) generate(rec)
    quietly count if start <= 10 & stop >= 10 & rec == 1
    assert r(N) == 1
    quietly count if start <= 11 & stop >= 11 & rec == 2
    assert r(N) == 1
    quietly count if start <= 15 & stop >= 15 & rec == 4
    assert r(N) == 1
}
local captured_rc = _rc
_tvx_audit_record recency_reexposure `captured_rc'

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1  1 1
    1 10 10 2
    end
    save "`episodes'", replace
    _tvx_one_master 20
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        recency(2 5) recencyunit(days) bytype generate(r)
    foreach d in 1 2 3 6 10 11 12 15 {
        quietly count if start <= `d' & stop >= `d'
        assert r(N) == 1
    }
    assert r1 == 1 if start <= 1 & stop >= 1
    assert r1 == 2 if start <= 2 & stop >= 2
    assert r1 == 3 if start <= 3 & stop >= 3
    assert r1 == 4 if start <= 6 & stop >= 6
    assert r2 == 0 if start <= 6 & stop >= 6
    assert r2 == 1 if start <= 10 & stop >= 10
    assert r2 == 2 if start <= 11 & stop >= 11
    assert r2 == 3 if start <= 12 & stop >= 12
    assert r2 == 4 if start <= 15 & stop >= 15
}
local captured_rc = _rc
_tvx_audit_record recency_bytype `captured_rc'

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 1
    generate double stop = 1
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 20
    capture noisily tvexpose using "`episodes'", id(id) start(start) ///
        stop(stop) exposure(exposure) reference(0) entry(entry) ///
        exit(exitdate) recency(.001 .002) recencyunit(years)
    assert _rc == 198
}
local captured_rc = _rc
_tvx_audit_record recency_invalid_converted_cuts `captured_rc'

**# C-03a: cumulative histories are known at row start

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 1
    generate double stop = 10
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 15
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        continuousunit(days) generate(cum)
    local total_time = r(total_time)
    local exposed_time = r(exposed_time)
    local unexposed_time = r(unexposed_time)
    local pct_exposed = r(pct_exposed)
    quietly count if start == 1
    assert r(N) == 1
    quietly count if start == 11
    assert r(N) == 1
    assert cum == 0 if start == 1
    assert cum == 10 if start == 11
    assert "`: char cum[tvtools_quantity]'" == "cumulative"
    assert "`: char cum[tvtools_history_point]'" == "start"
    assert `total_time' == 15
    assert `exposed_time' == 10
    assert `unexposed_time' == 5
    assert reldif(`pct_exposed', 100 * 10 / 15) < 1e-12
}
local captured_rc = _rc
_tvx_audit_record cumulative_at_start `captured_rc'

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1 3 1
    1 4 5 2
    end
    save "`episodes'", replace
    _tvx_one_master 8
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        continuousunit(days) bytype generate(c)
    quietly count if start == 1
    assert r(N) == 1
    quietly count if start == 4
    assert r(N) == 1
    quietly count if start == 6
    assert r(N) == 1
    assert c1 == 0 if start == 1
    assert c1 == 3 & c2 == 0 if start == 4
    assert c1 == 3 & c2 == 2 if start == 6
    assert "`: char c1[tvtools_quantity]'" == "cumulative"
    assert "`: char c2[tvtools_history_point]'" == "start"
}
local captured_rc = _rc
_tvx_audit_record cumulative_bytype `captured_rc'

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 1
    generate double stop = 10
    generate double amount = 10
    save "`episodes'", replace
    _tvx_one_master 15
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(amount) entry(entry) exit(exitdate) dose generate(cumdose)
    local total_time = r(total_time)
    local exposed_time = r(exposed_time)
    local unexposed_time = r(unexposed_time)
    local pct_exposed = r(pct_exposed)
    quietly count if start == 1
    assert r(N) == 1
    quietly count if start == 11
    assert r(N) == 1
    assert cumdose == 0 if start == 1
    assert cumdose == 10 if start == 11
    assert "`: char cumdose[tvtools_quantity]'" == "cumulative"
    assert `total_time' == 15
    assert `exposed_time' == 10
    assert `unexposed_time' == 5
    assert reldif(`pct_exposed', 100 * 10 / 15) < 1e-12
}
local captured_rc = _rc
_tvx_audit_record dose_at_start `captured_rc'

**# C-09: point persistence is applied exactly once

capture noisily {
    tempfile points
    clear
    input long id double(start) byte exposure
    1 1  1
    1 61 1
    end
    save "`points'", replace
    _tvx_one_master 100
    tvexpose using "`points'", id(id) start(start) exposure(exposure) ///
        reference(0) entry(entry) exit(exitdate) pointtime ///
        carryforward(30) generate(x)
    generate double days = stop - start + 1
    quietly summarize days if x == 1, meanonly
    assert r(sum) == 60
    quietly count if start <= 31 & stop >= 31 & x == 0
    assert r(N) == 1
    quietly count if start <= 60 & stop >= 60 & x == 0
    assert r(N) == 1
}
local captured_rc = _rc
_tvx_audit_record point_far `captured_rc'

capture noisily {
    tempfile points
    clear
    input long id double(start) byte exposure
    1 1  1
    1 31 1
    end
    save "`points'", replace
    _tvx_one_master 70
    tvexpose using "`points'", id(id) start(start) exposure(exposure) ///
        reference(0) entry(entry) exit(exitdate) pointtime ///
        carryforward(30) generate(x)
    generate double days = stop - start + 1
    quietly summarize days if x == 1, meanonly
    assert r(sum) == 60
    quietly count if x == 0 & start <= 60 & stop >= 1
    assert r(N) == 0
    quietly count if start <= 1 & stop >= 1 & x == 1
    assert r(N) == 1
    quietly count if start <= 60 & stop >= 60 & x == 1
    assert r(N) == 1
}
local captured_rc = _rc
_tvx_audit_record point_equal `captured_rc'

capture noisily {
    tempfile points
    clear
    input long id double(start) byte exposure
    1 1  1
    1 20 2
    1 95 1
    end
    save "`points'", replace
    _tvx_one_master 100
    tvexpose using "`points'", id(id) start(start) exposure(exposure) ///
        reference(0) entry(entry) exit(exitdate) pointtime ///
        carryforward(30) generate(x)
    quietly count if start <= 19 & stop >= 19 & x == 1
    assert r(N) == 1
    quietly count if start <= 20 & stop >= 20 & x == 2
    assert r(N) == 1
    quietly count if start <= 95 & stop >= 95 & x == 1
    assert r(N) == 1
    generate double days = stop - start + 1
    quietly summarize days, meanonly
    assert r(sum) == 100
}
local captured_rc = _rc
_tvx_audit_record point_classes_tail `captured_rc'

**# I-11: window() is an inclusive post-start effect window

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 10
    generate double stop = 109
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 120
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        window(1 7) generate(x)
    local window_min = r(window_min)
    local window_max = r(window_max)
    quietly count if start == 11 & stop == 17 & x == 1
    assert r(N) == 1
    generate double days = stop - start + 1
    quietly summarize days if x == 1, meanonly
    assert r(sum) == 7
    assert `window_min' == 1 & `window_max' == 7
}
local captured_rc = _rc
_tvx_audit_record window_effect `captured_rc'

**# I-03: malformed inputs fail transactionally unless dropinvalid is explicit

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 1
    generate double stop = 2
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 10
    replace entry = 1.5
    datasignature set
    capture noisily tvexpose using "`episodes'", id(id) start(start) ///
        stop(stop) exposure(exposure) reference(0) entry(entry) exit(exitdate)
    local cmdrc = _rc
    assert `cmdrc' == 498
    datasignature confirm
}
local captured_rc = _rc
_tvx_audit_record malformed_master_strict `captured_rc'

capture noisily {
    tempfile episodes
    clear
    set obs 3
    generate long id = 1
    generate double start = cond(_n == 1, 1, cond(_n == 2, ., 8))
    generate double stop = cond(_n == 1, 2, cond(_n == 2, 5, 7))
    generate byte exposure = cond(_n == 1, 1, cond(_n == 2, 1, .))
    save "`episodes'", replace
    _tvx_one_master 10
    datasignature set
    capture noisily tvexpose using "`episodes'", id(id) start(start) ///
        stop(stop) exposure(exposure) reference(0) entry(entry) exit(exitdate)
    local cmdrc = _rc
    assert `cmdrc' == 498
    datasignature confirm
}
local captured_rc = _rc
_tvx_audit_record malformed_episode_strict `captured_rc'

capture noisily {
    tempfile episodes
    clear
    set obs 3
    generate long id = 1
    generate double start = cond(_n == 1, 1, cond(_n == 2, ., 8))
    generate double stop = cond(_n == 1, 2, cond(_n == 2, 5, 7))
    generate byte exposure = cond(_n == 3, ., 1)
    save "`episodes'", replace
    clear
    set obs 2
    generate long id = _n
    generate double entry = 1
    generate double exitdate = cond(id == 1, 10, .)
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        dropinvalid flow generate(x)
    assert id == 1
    assert r(n_invalid_master) == 1
    assert r(n_invalid_exposure) == 2
    assert r(n_uncovered_days) == 0
    matrix F = r(flow)
    assert rowsof(F) == 2 & colsof(F) == 3
}
local captured_rc = _rc
_tvx_audit_record dropinvalid_counts `captured_rc'

**# I-10: deep layer chains cannot return unresolved conflicts

capture noisily {
    tempfile episodes
    clear
    set obs 14
    generate long id = 1
    generate double start = _n
    generate double stop = 101 - _n
    generate byte exposure = 1 + mod(_n, 2)
    save "`episodes'", replace
    _tvx_one_master 100
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        layer generate(x)
    assert r(n_unresolved_overlaps) == 0
    preserve
    clear
    input long gid double(s e v)
    1 1  100 1
    1 10  20 1
    1 50  60 2
    end
    _tvexpose_mata_conflicts gid s e v
    assert r(n_conflicts) == 1
    restore
    generate long row = _n
    tempfile output
    save "`output'", replace
    rename (row start stop x) (row2 start2 stop2 x2)
    joinby id using "`output'"
    quietly count if row < row2 & x != x2 & max(start, start2) <= min(stop, stop2)
    assert r(N) == 0
}
local captured_rc = _rc
_tvx_audit_record overlap_convergence `captured_rc'

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1 20 1
    1 5 12 2
    end
    save "`episodes'", replace
    _tvx_one_master 20
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        layer generate(x)
    assert _N == 3
    assert start[1] == 1  & stop[1] == 4  & x[1] == 1
    assert start[2] == 5  & stop[2] == 12 & x[2] == 2
    assert start[3] == 13 & stop[3] == 20 & x[3] == 1
    assert r(n_unresolved_overlaps) == 0
}
local captured_rc = _rc
_tvx_audit_record layer_resumption_exact `captured_rc'

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1 10 1
    1 1  5 2
    end
    save "`episodes'", replace
    _tvx_one_master 10
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        layer generate(x)
    assert _N == 2
    assert start[1] == 1 & stop[1] == 5  & x[1] == 2
    assert start[2] == 6 & stop[2] == 10 & x[2] == 1
    assert r(n_unresolved_overlaps) == 0
}
local captured_rc = _rc
_tvx_audit_record layer_equal_start_source_tie `captured_rc'

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1   100 1
    1 10   20 1
    1 50   60 1
    end
    save "`episodes'", replace
    _tvx_one_master 100
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        generate(x)
    local total_time = r(total_time)
    generate double days = stop - start + 1
    quietly summarize days, meanonly
    assert r(sum) == 100
    assert `total_time' == 100
    generate long row = _n
    tempfile output
    save "`output'", replace
    rename (row start stop) (row2 start2 stop2)
    joinby id using "`output'"
    quietly count if row < row2 & max(start, start2) <= min(stop, stop2)
    assert r(N) == 0
}
local captured_rc = _rc
_tvx_audit_record overlap_same_value_tiling `captured_rc'

capture noisily {
    tempfile episodes
    clear
    input long id double(start stop) byte exposure
    1 1 6 1
    1 4 8 2
    end
    save "`episodes'", replace
    _tvx_one_master 10
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        split generate(x)
    local total_time = r(total_time)
    local exposed_time = r(exposed_time)
    local unexposed_time = r(unexposed_time)
    local pct_exposed = r(pct_exposed)
    assert `total_time' == 10
    assert `exposed_time' == 8
    assert `unexposed_time' == 2
    assert reldif(`pct_exposed', 80) < 1e-12
    generate double days = stop - start + 1
    quietly summarize days, meanonly
    assert r(sum) > `total_time'
}
local captured_rc = _rc
_tvx_audit_record split_union_returns `captured_rc'

**# I-12: frame output is staged and caller state survives

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 1
    generate double stop = 2
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 5
    generate str4 caller = "kept"
    datasignature set
    capture frame drop tvx_target
    frame create tvx_target
    frame tvx_target: set obs 1
    frame tvx_target: generate str3 old = "old"
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        frameout(tvx_target) replace generate(x)
    datasignature confirm
    frame tvx_target: assert _N > 0
    frame tvx_target: confirm variable x
    capture frame tvx_target: confirm variable old, exact
    local old_rc = _rc
    assert `old_rc' == 111
    frame drop tvx_target
}
local captured_rc = _rc
capture frame drop tvx_target
_tvx_audit_record frameout_staged `captured_rc'

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = 1
    generate double stop = 2
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 5
    generate str4 caller = "kept"
    datasignature set
    capture frame drop tvx_new_target
    tvexpose using "`episodes'", id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exitdate) ///
        frameout(tvx_new_target) generate(x)
    datasignature confirm
    frame tvx_new_target: assert _N > 0
    frame tvx_new_target: confirm variable x
    frame drop tvx_new_target
}
local captured_rc = _rc
capture frame drop tvx_new_target
_tvx_audit_record frameout_new_target `captured_rc'

capture noisily {
    tempfile episodes
    clear
    set obs 1
    generate long id = 1
    generate double start = .
    generate double stop = 2
    generate byte exposure = 1
    save "`episodes'", replace
    _tvx_one_master 5
    generate str4 caller = "kept"
    datasignature set
    capture frame drop tvx_error_target
    frame create tvx_error_target
    frame tvx_error_target: set obs 1
    frame tvx_error_target: generate str3 old = "old"
    capture noisily tvexpose using "`episodes'", id(id) start(start) ///
        stop(stop) exposure(exposure) reference(0) entry(entry) ///
        exit(exitdate) frameout(tvx_error_target) replace generate(x)
    local cmdrc = _rc
    assert `cmdrc' == 498
    datasignature confirm
    frame tvx_error_target: assert old == "old"
    frame tvx_error_target: confirm variable old
    capture frame tvx_error_target: confirm variable x, exact
    local x_rc = _rc
    assert `x_rc' == 111
}
local captured_rc = _rc
capture frame drop tvx_error_target
_tvx_audit_record frameout_error_preserves_target `captured_rc'

capture noisily {
    capture frame drop tvx_rollback_target
    frame create tvx_rollback_target
    frame tvx_rollback_target: set obs 1
    frame tvx_rollback_target: generate str3 old = "old"
    capture noisily _tvexpose_frame_commit, ///
        target(tvx_rollback_target) replace failrename
    local cmdrc = _rc
    assert `cmdrc' == 498
    frame tvx_rollback_target: assert old == "old"
    frame tvx_rollback_target: confirm variable old
    capture frame tvx_rollback_target: confirm variable id, exact
    local id_rc = _rc
    assert `id_rc' == 111
}
local captured_rc = _rc
capture frame drop tvx_rollback_target
_tvx_audit_record frameout_rollback `captured_rc'

local test_count = $TVX_AUDIT_TESTS
local pass_count = $TVX_AUDIT_PASS
local fail_count = $TVX_AUDIT_FAIL
local failed_tests "$TVX_AUDIT_FAILED"
macro drop TVX_AUDIT_TESTS TVX_AUDIT_PASS TVX_AUDIT_FAIL TVX_AUDIT_FAILED

display "RESULT: validation_audit_tvexpose tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "tvexpose audit failures:`failed_tests'"
    exit 1
}
