* test_rangematch_overlap.do — interval-overlap mode (overlap()) regression suite
* Covers v1.1.0 overlap(ulow uhigh): brute-force joinby oracle parity, closed
* both/none, tolerance, missing-bound open-ended matching, unmatched() modes,
* output routing, dryrun parity, stats, maxpairs, carry options, return
* contract, error guards, and a documentation-example smoke.

clear all
set varabbrev off
version 16.1

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

* ----------------------------------------------------------------------
* Helper: run a capture'd block, record pass/fail
* (each test below sets `desc' then runs a capture noisily block)
* ----------------------------------------------------------------------

**# Test 1: brute-force joinby oracle parity (randomized, by-grouped)

local ++test_count
local desc "oracle parity (randomized by-grouped intervals)"
capture noisily {
    * Master: cohort follow-up windows, several per id
    clear
    set seed 8675309
    set obs 400
    gen long id = ceil(_n / 4)
    gen double mlo = floor(runiform() * 1000)
    gen double mhi = mlo + ceil(runiform() * 60)
    tempfile master_o
    save "`master_o'"

    * Using: event/episode intervals, several per id, some non-overlapping
    clear
    set seed 1234567
    set obs 1200
    gen long id = ceil(_n / 4)
    gen double ulo = floor(runiform() * 1000)
    gen double uhi = ulo + ceil(runiform() * 40)
    gen double payload = runiform()
    tempfile using_o
    save "`using_o'"

    * rangematch overlap mode
    use "`master_o'", clear
    rangematch mlo mhi using "`using_o'", overlap(ulo uhi) by(id) ///
        unmatched(none) frame(rm_o) replace nosort
    frame rm_o {
        keep id mlo mhi ulo uhi
        gsort id mlo mhi ulo uhi
        tempfile rm_pairs_o
        save "`rm_pairs_o'"
        local n_rm = _N
    }

    * Brute-force oracle: full cartesian within id, keep overlaps
    use "`master_o'", clear
    joinby id using "`using_o'"
    keep if (mlo <= uhi) & (ulo <= mhi)
    keep id mlo mhi ulo uhi
    gsort id mlo mhi ulo uhi
    local n_oracle = _N

    assert `n_rm' == `n_oracle'
    cf _all using "`rm_pairs_o'"
}
if _rc == 0 {
    display as result "  PASS: `desc' (`n_oracle' pairs)"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 2: closed(none) strict vs closed(both) — endpoint-touch difference

local ++test_count
local desc "closed(none) drops endpoint-touch matches kept by closed(both)"
capture noisily {
    clear
    input long id double mlo double mhi
    1 10 20
    end
    tempfile m2
    save "`m2'"

    clear
    input long id double ulo double uhi
    1 20 30
    1  0 10
    1 12 14
    end
    tempfile u2
    save "`u2'"

    * closed(both): all three overlap [10,20] (two touch at endpoints 20 and 10)
    use "`m2'", clear
    rangematch mlo mhi using "`u2'", overlap(ulo uhi) by(id) ///
        unmatched(none) frame(b2) replace
    frame b2: count
    local n_both = r(N)

    * closed(none): the two endpoint-touch intervals drop, only [12,14] remains
    use "`m2'", clear
    rangematch mlo mhi using "`u2'", overlap(ulo uhi) by(id) ///
        closed(none) unmatched(none) frame(n2) replace
    frame n2: count
    local n_none = r(N)

    assert `n_both' == 3
    assert `n_none' == 1
}
if _rc == 0 {
    display as result "  PASS: `desc' (both=`n_both' none=`n_none')"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 3: tolerance() boundary expansion

local ++test_count
local desc "tolerance() brings a near-miss interval into overlap"
capture noisily {
    clear
    input long id double mlo double mhi
    1 10 20
    end
    tempfile m3
    save "`m3'"

    clear
    input long id double ulo double uhi
    1 22 30
    end
    tempfile u3
    save "`u3'"

    * No overlap: gap of 2 between mhi=20 and ulo=22
    use "`m3'", clear
    rangematch mlo mhi using "`u3'", overlap(ulo uhi) by(id) ///
        unmatched(none) frame(t3a) replace
    frame t3a: count
    assert r(N) == 0

    * tolerance(2) closes the gap
    use "`m3'", clear
    rangematch mlo mhi using "`u3'", overlap(ulo uhi) by(id) ///
        tolerance(2) unmatched(none) frame(t3b) replace
    frame t3b: count
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 4: missing master/using bounds -> open-ended matching

local ++test_count
local desc "missing bounds are open-ended on that side"
capture noisily {
    * Master with open-ended-above interval [50, .]
    clear
    input long id double mlo double mhi
    1 50 .
    end
    tempfile m4
    save "`m4'"

    clear
    input long id double ulo double uhi
    1 10 20
    1 60 70
    1 100 200
    end
    tempfile u4
    save "`u4'"

    * [50, +inf] overlaps [60,70] and [100,200] but not [10,20]
    use "`m4'", clear
    rangematch mlo mhi using "`u4'", overlap(ulo uhi) by(id) ///
        unmatched(none) frame(m4f) replace
    frame m4f: count
    assert r(N) == 2

    * Using with open-ended-below interval [., 30] matches master [50,.]?
    * [-inf,30] vs [50,+inf]: 50 <= 30 is false -> no overlap
    clear
    input long id double ulo double uhi
    1 . 30
    1 . 80
    end
    tempfile u4b
    save "`u4b'"
    use "`m4'", clear
    rangematch mlo mhi using "`u4b'", overlap(ulo uhi) by(id) ///
        unmatched(none) frame(m4g) replace
    frame m4g: count
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 5: all four unmatched() modes

local ++test_count
local desc "unmatched(master|none|using|both) row accounting"
capture noisily {
    clear
    input long id double mlo double mhi
    1 10 20
    1 200 210
    end
    tempfile m5
    save "`m5'"

    clear
    input long id double ulo double uhi
    1 15 18
    1 900 950
    end
    tempfile u5
    save "`u5'"

    * 1 matched pair (m[10,20] x u[15,18]); 1 unmatched master; 1 unmatched using
    use "`m5'", clear
    rangematch mlo mhi using "`u5'", overlap(ulo uhi) by(id) ///
        unmatched(master) frame(um) replace
    frame um: count
    assert r(N) == 2

    use "`m5'", clear
    rangematch mlo mhi using "`u5'", overlap(ulo uhi) by(id) ///
        unmatched(none) frame(un) replace
    frame un: count
    assert r(N) == 1

    use "`m5'", clear
    rangematch mlo mhi using "`u5'", overlap(ulo uhi) by(id) ///
        unmatched(using) frame(uu) replace
    frame uu: count
    assert r(N) == 2

    use "`m5'", clear
    rangematch mlo mhi using "`u5'", overlap(ulo uhi) by(id) ///
        unmatched(both) frame(ub) replace
    frame ub: count
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 6: output routing — frame() vs saving() vs in-memory equal

local ++test_count
local desc "frame(), saving(), and in-memory produce identical output"
capture noisily {
    clear
    set seed 4242
    set obs 60
    gen long id = ceil(_n / 3)
    gen double mlo = floor(runiform() * 200)
    gen double mhi = mlo + ceil(runiform() * 30)
    tempfile m6
    save "`m6'"

    clear
    set seed 9999
    set obs 120
    gen long id = ceil(_n / 3)
    gen double ulo = floor(runiform() * 200)
    gen double uhi = ulo + ceil(runiform() * 20)
    tempfile u6
    save "`u6'"

    use "`m6'", clear
    rangematch mlo mhi using "`u6'", overlap(ulo uhi) by(id) frame(f6) replace
    frame f6 {
        keep id mlo mhi ulo uhi
        gsort id mlo mhi ulo uhi
        tempfile fr6
        save "`fr6'"
    }

    use "`m6'", clear
    tempfile saved6
    rangematch mlo mhi using "`u6'", overlap(ulo uhi) by(id) ///
        saving("`saved6'", replace)
    use "`saved6'", clear
    keep id mlo mhi ulo uhi
    gsort id mlo mhi ulo uhi
    cf _all using "`fr6'"

    use "`m6'", clear
    rangematch mlo mhi using "`u6'", overlap(ulo uhi) by(id)
    keep id mlo mhi ulo uhi
    gsort id mlo mhi ulo uhi
    cf _all using "`fr6'"
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 7: dryrun/count N_pairs parity with materialized frame

local ++test_count
local desc "dryrun and count report N_pairs equal to materialized rows"
capture noisily {
    use "`m6'", clear
    rangematch mlo mhi using "`u6'", overlap(ulo uhi) by(id) ///
        unmatched(both) frame(fp7) replace
    frame fp7: count
    local n_mat = r(N)

    use "`m6'", clear
    rangematch mlo mhi using "`u6'", overlap(ulo uhi) by(id) ///
        unmatched(both) dryrun
    assert r(N_pairs) == `n_mat'

    use "`m6'", clear
    rangematch mlo mhi using "`u6'", overlap(ulo uhi) by(id) ///
        unmatched(both) count
    assert r(N_pairs) == `n_mat'
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 8: stats match-density returns

local ++test_count
local desc "stats posts match-density scalars"
capture noisily {
    use "`m6'", clear
    rangematch mlo mhi using "`u6'", overlap(ulo uhi) by(id) ///
        frame(s8) replace stats
    assert r(max_matches) >= 1
    assert r(mean_matches) >= 0
    assert r(N_matched_master) >= 1
    assert r(N_master_groups) >= 1
    assert !missing(r(p90_matches))
    assert !missing(r(p99_matches))
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 9: maxpairs() trip returns rc 198

local ++test_count
local desc "maxpairs() guard trips with rc 198"
capture noisily {
    * Dense mutually-overlapping intervals to blow past a small cap
    clear
    set obs 50
    gen long id = 1
    gen double mlo = 0
    gen double mhi = 1000
    tempfile m9
    save "`m9'"
    clear
    set obs 50
    gen long id = 1
    gen double ulo = 0
    gen double uhi = 1000
    tempfile u9
    save "`u9'"

    use "`m9'", clear
    capture rangematch mlo mhi using "`u9'", overlap(ulo uhi) by(id) maxpairs(100)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 10: keepusing / masterid / usingid / generate carry

local ++test_count
local desc "keepusing/masterid/usingid/generate carry correctly"
capture noisily {
    clear
    input long id double mlo double mhi
    1 10 20
    1 200 210
    end
    tempfile m10
    save "`m10'"
    clear
    input long id double ulo double uhi str4 drug
    1 15 18 "ssri"
    1 900 950 "snri"
    end
    tempfile u10
    save "`u10'"

    use "`m10'", clear
    rangematch mlo mhi using "`u10'", overlap(ulo uhi) by(id) ///
        keepusing(ulo uhi drug) masterid(mrow) usingid(urow) ///
        generate(_mtype) unmatched(both) frame(c10) replace
    frame c10 {
        * matched row has drug, masterid, usingid all nonmissing and _mtype==3
        count if _mtype == 3
        assert r(N) == 1
        count if _mtype == 1
        assert r(N) == 1
        count if _mtype == 2
        assert r(N) == 1
        * matched row carries the using string payload
        count if _mtype == 3 & drug == "ssri"
        assert r(N) == 1
        count if _mtype == 3 & !missing(mrow) & !missing(urow)
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 11: return contract — r(backend)=="overlap", r(overlap) macro

local ++test_count
local desc "r(backend)==overlap and r(overlap) names using bounds"
capture noisily {
    use "`m10'", clear
    rangematch mlo mhi using "`u10'", overlap(ulo uhi) by(id) frame(r11) replace
    assert "`r(backend)'" == "overlap"
    assert "`r(overlap)'" == "ulo uhi"
    assert "`r(cmd)'" == "rangematch"
    assert "`r(low)'" == "mlo"
    assert "`r(high)'" == "mhi"
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 12: error guards (point-only options + bad bounds)

local ++test_count
local desc "overlap-mode error guards reject incompatible options"
capture noisily {
    use "`m10'", clear
    capture rangematch mlo mhi using "`u10'", overlap(ulo uhi) nearest(both)
    assert _rc == 198
    capture rangematch mlo mhi using "`u10'", overlap(ulo uhi) ties(first)
    assert _rc == 198
    capture rangematch mlo mhi using "`u10'", overlap(ulo uhi) distance(d)
    assert _rc == 198
    capture rangematch mlo mhi using "`u10'", overlap(ulo uhi) closed(left)
    assert _rc == 198
    capture rangematch mlo mhi using "`u10'", overlap(ulo uhi) closed(right)
    assert _rc == 198
    * scalar-offset master bound not allowed in overlap mode
    capture rangematch mlo 5 using "`u10'", overlap(ulo uhi)
    assert _rc == 198
    * three positionals with overlap()
    capture rangematch mlo mhi mhi using "`u10'", overlap(ulo uhi)
    assert _rc == 103
    * overlap() must name exactly two variables
    capture rangematch mlo mhi using "`u10'", overlap(ulo)
    assert _rc == 198
    capture rangematch mlo mhi using "`u10'", overlap(ulo uhi extra)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Test 13: documentation-example smoke (cohort x episodes overlap)

local ++test_count
local desc "documentation example (cohort follow-up x treatment episodes)"
capture noisily {
    clear
    input long id double entry double exit
    1 100 200
    2 100 200
    end
    tempfile cohort
    save "`cohort'"

    clear
    input long id double rx_start double rx_stop str4 drug
    1 150 180 "ssri"
    1 300 400 "snri"
    2  50  90 "ssri"
    end
    tempfile episodes
    save "`episodes'"

    use "`cohort'", clear
    rangematch entry exit using "`episodes'", overlap(rx_start rx_stop) ///
        by(id) keepusing(rx_start rx_stop drug) frame(exposed) replace stats
    * id 1: [100,200] overlaps [150,180] only; id 2: [100,200] vs [50,90] no
    frame exposed {
        count if !missing(rx_start)
        assert r(N) == 1
        count if !missing(rx_start) & drug == "ssri" & id == 1
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: `desc'"
    local ++pass_count
}
else {
    display as error "  FAIL: `desc' (rc=`=_rc')"
    local ++fail_count
}

**# Summary

display as result _newline "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME OVERLAP TESTS FAILED"
    display "RESULT: test_rangematch_overlap tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL OVERLAP TESTS PASSED"
display "RESULT: test_rangematch_overlap tests=`test_count' pass=`pass_count' fail=`fail_count'"
