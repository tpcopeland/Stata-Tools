* test_iivw_v420_shard.do
* Contract coverage for the 4.2.0 sharded bootstrap: iivw_fit's saving() and
* rngstream() options, and iivw_bspool's pooling, identity and status rules.
*
*   T1  a 999-draw run split into shard files and re-pooled is bit-identical
*   T2  a single shard pooled through iivw_bspool reproduces the run it came from
*   T3  distinct rngstream() values give distinct draws; each replays identically
*   T4  seed() and rngstream() together are reproducible, and order does not matter
*   T5  pooling refuses shards whose weight contract disagrees
*   T6  pooling refuses shards whose coefficient set disagrees
*   T7  pooling refuses two shards drawn from the same RNG state
*   T8  pooling refuses the same file listed twice
*   T9  pooling refuses a file that is not an iivw shard
*   T10 pooled failed-replicate count is the sum, and gates on error 430
*   T11 nine shards of 111, each stamped uncleared-low-reps, pool to 999 and lift
*   T12 an unrecognized shard stamp dominates and survives pooling
*   T13 BCa shards are refused by name
*   T14 saving()/rngstream() without draws, and an out-of-range stream, error
*   T15 a truncated shard file is refused
*   T16 reps() asserts the pooled total
*   T17 9x111 pooled agrees with 1x999 inside Monte Carlo tolerance
*   T18 citype(), level() and saving() on the pooler, and the pooled e() surface
*   T19 the pooled covariance equals the replicate covariance computed by hand
*   T20 the anchor contract: data-free pooling, a wrong anchor, and stale data
*   T21 a stored interval at a non-default level replays without being asked to
*   T22 an omitted level() takes the shards' level, not the session default
*   T23 a bad saving() target fails early, and a late write failure keeps e()
*
* WHY T1 IS THE PRIMARY REGRESSION
* --------------------------------
* Splitting one run's replicate file into K parts and appending them back is the
* only case where sharding is exactly reproducible: the draws are literally the
* same draws. If pooling is arithmetically correct, T1 must be identical to the
* last bit, not merely close. Every tolerance elsewhere in this suite is there
* because the draws themselves differ; T1 has no such excuse and is asserted at
* equality.

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

iivw_qa_selector `1'
local run_only = r(run_only)

* A working directory of our own. Every shard file this suite writes lands here
* and nowhere near the package tree.
tempfile _stub
local work "`_stub'_shardwork"
capture mkdir "`work'"

capture program drop _v420_panel
program define _v420_panel
    version 16.0
    args nsub
    if "`nsub'" == "" local nsub 150
    clear
    * Pin the generator, not just the seed. A fit that ran under rngstream()
    * can leave the session on a different substream, and `set seed' alone then
    * builds a DIFFERENT panel -- which is how five cases in this suite first
    * failed. mt64s stream 1 reproduces the default generator exactly (measured),
    * so this is the same panel the pre-4.2.0 suites built.
    set rng mt64s
    set rngstream 1
    set seed 4713
    set obs `nsub'
    gen long id = _n
    gen double k1 = rnormal()
    gen double z1 = rnormal()
    gen byte a = runiform() < invlogit(.8*k1)
    expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double y = 1 + .5*a + .4*z1 + .3*k1 + .1*t + rnormal()
    gen double keeppr = invlogit(.4 + .9*z1 - .3*a)
    drop if runiform() > keeppr & j > 1
    sort id t
end

capture program drop _v420_weight
program define _v420_weight
    version 16.0
    args nsub
    _v420_panel `nsub'
    quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
        wtype(fiptiw) maxfu(7) scores nolog
end

**# T1: one run's draws, split and re-pooled, are bit-identical

* The oracle is the run itself. A 60-draw fit writes its replicate file; the
* file is cut into three 20-row pieces carrying the same characteristics; the
* three pieces are pooled. Nothing about the draws changed, so nothing about
* the variance, the interval or the replicate counts may change either.
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(60) seed(31)) saving("`work'/t1_all", replace)
    tempname B1 V1 C1 P1
    matrix `B1' = e(b)
    matrix `V1' = e(V)
    matrix `C1' = e(iivw_ci)
    matrix `P1' = e(iivw_ci_percentile)
    local t1_req  = e(iivw_bs_reps_requested)
    local t1_done = e(iivw_bs_reps_completed)
    local t1_fail = e(iivw_bs_reps_failed)
    local t1_stat "`e(iivw_inference_status)'"

    * Cut the file into three, in a frame, so the fit in e() and the analysis
    * data in memory are both untouched.
    tempname cutfr
    frame create `cutfr'
    frame `cutfr' {
        forvalues i = 1/3 {
            use "`work'/t1_all.dta", clear
            gen long _row = _n
            quietly keep if _row > (`i'-1)*20 & _row <= `i'*20
            drop _row
            * The shard stamp says how many draws the shard requested. These
            * pieces are 20 each, and the pooled arithmetic cross-checks the
            * stamps against the row counts, so the stamps have to be honest.
            char _dta[_iivw_shard_reps_requested] "20"
            char _dta[_iivw_shard_reps_completed] "20"
            char _dta[_iivw_shard_reps_failed] "0"
            * Distinct RNG-state markers: these are three disjoint pieces of one
            * stream, not three copies of it, and the duplicate guard has no way
            * to know that from a shared state string.
            local _st : char _dta[seed]
            char _dta[seed] "`_st'-piece`i'"
            quietly save "`work'/t1_p`i'.dta", replace
        }
    }
    frame drop `cutfr'

    quietly iivw_bspool using "`work'/t1_p1.dta `work'/t1_p2.dta `work'/t1_p3.dta", notable

    assert mreldif(e(b), `B1') == 0
    assert mreldif(e(V), `V1') == 0
    assert mreldif(e(iivw_ci), `C1') == 0
    assert mreldif(e(iivw_ci_percentile), `P1') == 0
    assert e(iivw_bs_reps_requested) == `t1_req'
    assert e(iivw_bs_reps_completed) == `t1_done'
    assert e(iivw_bs_reps_failed)    == `t1_fail'
    assert "`e(iivw_inference_status)'" == "`t1_stat'"
    assert e(iivw_bs_shards) == 3
    assert "`e(iivw_bs_pooled)'" == "1"
    display as result "T1 PASS: split and re-pooled draws are bit-identical"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T1"
    display as error "T1 FAIL"
}
}

**# T2: a single shard pooled reproduces the run it came from

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(40) seed(77)) saving("`work'/t2", replace)
    tempname B2 V2 C2
    matrix `B2' = e(b)
    matrix `V2' = e(V)
    matrix `C2' = e(iivw_ci)
    local t2_stat "`e(iivw_inference_status)'"

    quietly iivw_bspool using "`work'/t2.dta", notable
    assert mreldif(e(b), `B2') == 0
    assert mreldif(e(V), `V2') == 0
    assert mreldif(e(iivw_ci), `C2') == 0
    assert "`e(iivw_inference_status)'" == "`t2_stat'"
    assert e(iivw_bs_shards) == 1
    display as result "T2 PASS: one shard pooled reproduces its own run"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T2"
    display as error "T2 FAIL"
}
}

**# T3: distinct streams give distinct draws, and each replays identically

* This is the claim the whole design rests on. If two streams gave the same
* draws, pooling would be counting one shard twice; if a stream did not replay,
* a sharded run would not be reproducible at all.
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    foreach s in 1 2 {
        _v420_weight
        quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
            vce(bootstrap, reps(12) seed(505)) rngstream(`s') ///
            saving("`work'/t3_s`s'", replace)
        assert "`e(iivw_rngstream)'" == "`s'"
        assert "`e(iivw_rng)'" == "mt64s"
    }
    * Stream 1 again, in the same session and after stream 2 has run.
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(12) seed(505)) rngstream(1) ///
        saving("`work'/t3_s1b", replace)

    tempname cmpfr
    frame create `cmpfr'
    frame `cmpfr' {
        use "`work'/t3_s1.dta", clear
        quietly ds
        local firstvar : word 1 of `r(varlist)'
        local a1 = `firstvar'[1]
        local a5 = `firstvar'[5]
        use "`work'/t3_s2.dta", clear
        local b1 = `firstvar'[1]
        use "`work'/t3_s1b.dta", clear
        local c1 = `firstvar'[1]
        local c5 = `firstvar'[5]
    }
    frame drop `cmpfr'

    display as text "  stream1 draw1 = " %16.12f `a1'
    display as text "  stream2 draw1 = " %16.12f `b1'
    display as text "  stream1 again = " %16.12f `c1'
    * Distinct streams, distinct draws.
    assert `a1' != `b1'
    * Same stream, same draws, to the last bit.
    assert `a1' == `c1'
    assert `a5' == `c5'
    display as result "T3 PASS: streams are independent and each replays exactly"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T3"
    display as error "T3 FAIL"
}
}

**# T4: seed() and rngstream() ordering

* iivw_fit sets the generator, then the STREAM, then the seed, and that order
* is load-bearing rather than cosmetic. `set seed' resets the position of the
* substream currently selected and only that one, so seeding first and jumping
* to the stream afterwards lands wherever that stream was left.
*
* A probe on a fresh stream cannot see this: both orderings agree there, which
* is exactly how the wrong order looks correct. So the case is built with the
* target stream deliberately pre-advanced, which is the state a second fit in
* one process actually starts from.
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    * Correct order, stream 6 fresh.
    set rng mt64s
    set rngstream 6
    set seed 8080
    local ord_a = runiform()

    * Advance stream 6, wander off, and run the same recipe again.
    local junk = runiform()
    local junk = runiform()
    set rngstream 1
    local junk = runiform()
    set rng mt64s
    set rngstream 6
    set seed 8080
    local ord_b = runiform()

    * Wrong order (seed, then jump) from the same advanced state.
    local junk = runiform()
    local junk = runiform()
    set rngstream 1
    set rng mt64s
    set seed 8080
    set rngstream 6
    local ord_c = runiform()

    * A different stream, correct order.
    set rng mt64s
    set rngstream 7
    set seed 8080
    local ord_d = runiform()

    display as text "  stream-then-seed, fresh    = " %16.12f `ord_a'
    display as text "  stream-then-seed, advanced = " %16.12f `ord_b'
    display as text "  seed-then-stream, advanced = " %16.12f `ord_c'
    display as text "  stream-then-seed, stream 7 = " %16.12f `ord_d'
    * The order iivw_fit uses reproduces from any prior state.
    assert `ord_a' == `ord_b'
    * The order it does not use does not.
    assert `ord_c' != `ord_a'
    * And the stream index still moves the draws.
    assert `ord_d' != `ord_a'

    * And the same statement at the command surface: one seed, two streams,
    * reproducible draws that differ.
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(4242)) rngstream(11) saving("`work'/t4_a", replace)
    tempname V4a
    matrix `V4a' = e(V)
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(4242)) rngstream(11) saving("`work'/t4_b", replace)
    assert mreldif(e(V), `V4a') == 0
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(4242)) rngstream(12) saving("`work'/t4_c", replace)
    assert mreldif(e(V), `V4a') > 0

    * And the fit puts the caller's generator back. Without this, one
    * rngstream() fit silently moves every later seeded command in the session
    * onto that substream.
    set rng default
    set seed 606
    local ref1 = runiform()
    local ref2 = runiform()
    set rng default
    set seed 606
    local mid = runiform()
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(6)) rngstream(21) saving("`work'/t4_d", replace)
    set rng default
    set seed 606
    local after1 = runiform()
    local after2 = runiform()
    display as text "  caller sequence before = " %16.12f `ref1' " " %16.12f `ref2'
    display as text "  caller sequence after  = " %16.12f `after1' " " %16.12f `after2'
    assert `after1' == `ref1'
    assert `after2' == `ref2'
    assert "`c(rng)'" == "default"
    display as result "T4 PASS: seed and stream compose reproducibly and restore the caller"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T4"
    display as error "T4 FAIL"
}
}

**# T5: shards whose weight contract disagrees are refused

* Two fits of the same model on DIFFERENT weights produce files with the same
* column names and compatible shapes. Nothing but the weight signature
* distinguishes them, and averaging their draws is the corruption this guard
* exists to stop.
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(61)) rngstream(1) saving("`work'/t5_a", replace)

    * Refit the weights with a different maxfu, which changes the weight
    * signature while leaving every column name identical.
    _v420_panel
    quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
        wtype(fiptiw) maxfu(6) scores nolog
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(61)) rngstream(2) saving("`work'/t5_b", replace)

    capture iivw_bspool using "`work'/t5_a.dta `work'/t5_b.dta", notable
    local rc5 = _rc
    display as text "  mismatched weight contract -> rc = `rc5'"
    assert `rc5' == 459
    display as result "T5 PASS: a disagreeing weight contract is refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T5"
    display as error "T5 FAIL"
}
}

**# T6: shards whose coefficient set disagrees are refused

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(62)) rngstream(1) saving("`work'/t6_a", replace)
    _v420_weight
    quietly iivw_fit y a, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(62)) rngstream(2) saving("`work'/t6_b", replace)

    capture iivw_bspool using "`work'/t6_a.dta `work'/t6_b.dta", notable
    local rc6 = _rc
    display as text "  mismatched coefficient set -> rc = `rc6'"
    assert `rc6' == 459
    display as result "T6 PASS: a disagreeing coefficient set is refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T6"
    display as error "T6 FAIL"
}
}

**# T7: two shards drawn from the same RNG state are refused

local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(71)) saving("`work'/t7_a", replace)
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(71)) saving("`work'/t7_b", replace)

    capture iivw_bspool using "`work'/t7_a.dta `work'/t7_b.dta", notable
    local rc7 = _rc
    display as text "  identical RNG state -> rc = `rc7'"
    assert `rc7' == 459
    display as result "T7 PASS: duplicate draws are refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T7"
    display as error "T7 FAIL"
}
}

**# T8: the same file listed twice is refused

local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(81)) saving("`work'/t8", replace)
    capture iivw_bspool using "`work'/t8.dta `work'/t8.dta", notable
    local rc8 = _rc
    display as text "  same file twice -> rc = `rc8'"
    assert `rc8' == 198
    display as result "T8 PASS: a repeated file is refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T8"
    display as error "T8 FAIL"
}
}

**# T9: a file that is not an iivw shard is refused

* A bare -bootstrap, saving()- file has the right shape and none of the
* identity. Accepting it would mean pooling draws from an unknown estimator.
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(91)) saving("`work'/t9_real", replace)

    tempname jf
    frame create `jf'
    frame `jf' {
        use "`work'/t9_real.dta", clear
        char _dta[_iivw_shard] ""
        quietly save "`work'/t9_bare.dta", replace
    }
    frame drop `jf'

    capture iivw_bspool using "`work'/t9_bare.dta", notable
    local rc9 = _rc
    display as text "  unstamped replicate file -> rc = `rc9'"
    assert `rc9' == 459
    display as result "T9 PASS: an unstamped replicate file is refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T9"
    display as error "T9 FAIL"
}
}

**# T10: pooled failures sum, and gate on error 430

* The gate in iivw_fit fires on one run's failures. Applied per shard and not
* to the total, nine shards with a few failures each would each pass a check
* that the same failures in one run would have stopped.
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(20) seed(101)) rngstream(1) saving("`work'/t10_a", replace)
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(20) seed(101)) rngstream(2) saving("`work'/t10_b", replace)

    * Inject failures the way a failed draw actually appears in the file: a
    * replicate row whose coefficients came back missing. Two in one shard,
    * three in the other, so the pooled total is a sum and not a copy.
    tempname ff
    frame create `ff'
    frame `ff' {
        foreach spec in "a 2" "b 3" {
            local tag : word 1 of `spec'
            local nbad : word 2 of `spec'
            use "`work'/t10_`tag'.dta", clear
            quietly ds
            foreach v of varlist `r(varlist)' {
                quietly replace `v' = . in 1/`nbad'
            }
            char _dta[_iivw_shard_reps_failed] "`nbad'"
            char _dta[_iivw_shard_reps_completed] "`=20-`nbad''"
            char _dta[_iivw_shard_status] "uncleared-failed-reps"
            quietly save "`work'/t10_`tag'.dta", replace
        }
    }
    frame drop `ff'

    capture iivw_bspool using "`work'/t10_a.dta `work'/t10_b.dta", notable
    local rc10 = _rc
    display as text "  5 failures across 2 shards, no allowfailedreps -> rc = `rc10'"
    assert `rc10' == 430

    quietly iivw_bspool using "`work'/t10_a.dta `work'/t10_b.dta", ///
        notable allowfailedreps
    display as text "  pooled failed = " e(iivw_bs_reps_failed)
    display as text "  pooled done   = " e(iivw_bs_reps_completed)
    assert e(iivw_bs_reps_failed) == 5
    assert e(iivw_bs_reps_completed) == 35
    assert e(iivw_bs_reps_requested) == 40
    assert "`e(iivw_inference_status)'" == "uncleared-failed-reps"
    assert "`e(iivw_allowfailedreps)'" == "1"
    display as result "T10 PASS: failures sum and gate on the pooled total"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T10"
    display as error "T10 FAIL"
}
}

**# T11: nine shards of 111 pool to 999 and lift the low-reps stamp

* Each shard honestly carries uncleared-low-reps, because 111 draws have not
* earned the 999-draw coverage receipt. The pooled result has 999 draws and
* must not carry it. This is the one status the pooler is allowed to lift, and
* it is the reason the pooler exists.
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
capture noisily {
    local poollist ""
    forvalues s = 1/9 {
        _v420_weight
        quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
            vce(bootstrap, reps(111) seed(2026)) rngstream(`s') ///
            saving("`work'/t11_s`s'", replace)
        assert "`e(iivw_inference_status)'" == "uncleared-low-reps"
        assert e(iivw_bs_reps_requested) == 111
        local poollist "`poollist' `work'/t11_s`s'.dta"
    }
    quietly iivw_bspool using "`poollist'", notable reps(999)

    display as text "  pooled reps   = " e(iivw_bs_reps_requested)
    display as text "  pooled status = `e(iivw_inference_status)'"
    assert e(iivw_bs_reps_requested) == 999
    assert e(iivw_bs_reps_completed) == 999
    assert e(iivw_bs_reps_failed) == 0
    assert e(iivw_bs_shards) == 9
    assert "`e(iivw_inference_status)'" != "uncleared-low-reps"
    * fiptiw weights, refit draws, percentile interval: the ladder in iivw_fit
    * lands on the fiptiw stamp once the reps stamp no longer applies.
    assert "`e(iivw_inference_status)'" == "uncleared-fiptiw-percentile"
    assert "`e(iivw_bs_streams)'" == "1 2 3 4 5 6 7 8 9"
    display as result "T11 PASS: 9x111 pools to 999 and the low-reps stamp lifts"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T11"
    display as error "T11 FAIL"
}
}

**# T12: a weaker shard stamp survives pooling

* Pooling earns the replicate count and nothing else. The identity checks
* already force every shard to agree on weight type, refitweights and
* unweighted, so the pooler recomputes each estimator-level stamp itself; what
* the inheritance rule actually has to guarantee is the residual case, where a
* shard carries a status this version does not recognize. Such a stamp must
* dominate every known one, because a status the pooler cannot reason about is
* not one it may quietly discard.
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(20) seed(121)) rngstream(1) saving("`work'/t12_a", replace)
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(20) seed(121)) rngstream(2) saving("`work'/t12_b", replace)

    * Control: untouched stamps pool to the recomputed status. At 40 draws that
    * is uncleared-low-reps, which is what the pooler works out for itself.
    quietly iivw_bspool using "`work'/t12_a.dta `work'/t12_b.dta", notable
    local base_status "`e(iivw_inference_status)'"
    display as text "  untouched shards  -> `base_status'"
    assert "`base_status'" == "uncleared-low-reps"

    * Now one shard carries a stamp from a future version.
    tempname sf
    frame create `sf'
    frame `sf' {
        use "`work'/t12_b.dta", clear
        char _dta[_iivw_shard_status] "uncleared-something-this-build-never-heard-of"
        quietly save "`work'/t12_b.dta", replace
    }
    frame drop `sf'

    quietly iivw_bspool using "`work'/t12_a.dta `work'/t12_b.dta", notable
    display as text "  unrecognized stamp -> `e(iivw_inference_status)'"
    assert "`e(iivw_inference_status)'" == "uncleared-something-this-build-never-heard-of"
    display as result "T12 PASS: an unrecognized shard stamp dominates and survives"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T12"
    display as error "T12 FAIL"
}
}

**# T13: BCa shards are refused, by name

local ++test_count
if `run_only' == 0 | `run_only' == 13 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(bca) ///
        vce(bootstrap, reps(12) seed(131)) rngstream(1) saving("`work'/t13_a", replace)
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(bca) ///
        vce(bootstrap, reps(12) seed(131)) rngstream(2) saving("`work'/t13_b", replace)

    capture iivw_bspool using "`work'/t13_a.dta `work'/t13_b.dta", notable
    local rc13 = _rc
    display as text "  BCa shards -> rc = `rc13'"
    assert `rc13' == 198
    display as result "T13 PASS: BCa shards are refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T13"
    display as error "T13 FAIL"
}
}

**# T14: options without draws, and an out-of-range stream

* Silently ignoring an option the user typed is how a sharded run ends up
* pooling a file that was never written.
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
capture noisily {
    _v420_weight
    capture iivw_fit y a z1, timespec(linear) vce(fixed) saving("`work'/never", replace)
    local rcA = _rc
    capture iivw_fit y a z1, timespec(linear) vce(fixed) rngstream(3)
    local rcB = _rc
    capture iivw_fit y a z1, timespec(linear) vce(bootstrap, reps(6)) rngstream(0)
    local rcC = _rc
    capture iivw_fit y a z1, timespec(linear) vce(bootstrap, reps(6)) rngstream(40000)
    local rcD = _rc
    display as text "  saving without draws -> `rcA'"
    display as text "  rngstream without draws -> `rcB'"
    display as text "  rngstream(0) -> `rcC'"
    display as text "  rngstream(40000) -> `rcD'"
    assert `rcA' == 198
    assert `rcB' == 198
    assert `rcC' == 198
    assert `rcD' == 198
    * And the range check fires before the fit, not after it: no file is left.
    capture confirm file "`work'/never.dta"
    assert _rc != 0
    display as result "T14 PASS: shard options without draws, and bad streams, error"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T14"
    display as error "T14 FAIL"
}
}

**# T15: a truncated shard file is refused

* A process killed mid-run while every() was flushing leaves a file with fewer
* rows than the shard requested. Pooling it produces an interval from a draw
* count nobody chose, at rc 0.
local ++test_count
if `run_only' == 0 | `run_only' == 15 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(20) seed(151)) rngstream(1) saving("`work'/t15_a", replace)
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(20) seed(151)) rngstream(2) saving("`work'/t15_b", replace)

    tempname tf
    frame create `tf'
    frame `tf' {
        use "`work'/t15_b.dta", clear
        quietly drop in 15/20
        quietly save "`work'/t15_b.dta", replace
    }
    frame drop `tf'

    capture iivw_bspool using "`work'/t15_a.dta `work'/t15_b.dta", notable
    local rc15 = _rc
    display as text "  truncated shard -> rc = `rc15'"
    assert `rc15' == 459
    display as result "T15 PASS: a truncated shard file is refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T15"
    display as error "T15 FAIL"
}
}

**# T16: reps() asserts the pooled total

* The likeliest operational failure in a nine-process driver is one process
* dying and the driver pooling eight files. reps() is the user's statement of
* what the design called for.
local ++test_count
if `run_only' == 0 | `run_only' == 16 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(161)) rngstream(1) saving("`work'/t16_a", replace)
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(161)) rngstream(2) saving("`work'/t16_b", replace)

    capture iivw_bspool using "`work'/t16_a.dta `work'/t16_b.dta", notable reps(30)
    local rc16 = _rc
    display as text "  reps(30) against 20 pooled draws -> rc = `rc16'"
    assert `rc16' == 459
    quietly iivw_bspool using "`work'/t16_a.dta `work'/t16_b.dta", notable reps(20)
    assert e(iivw_bs_reps_requested) == 20
    display as result "T16 PASS: reps() asserts the pooled total"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T16"
    display as error "T16 FAIL"
}
}

**# T17: 9x111 pooled agrees with 1x999 inside Monte Carlo tolerance

* The shards and the single run draw DIFFERENT replicates, so the endpoints
* cannot match and a tolerance is unavoidable. The right one is the Monte Carlo
* spread of a bootstrap SE itself: for R draws, SD(s)/s is about 1/sqrt(2(R-1)),
* and two independent estimates differ with sqrt(2) times that. Three of those,
* per the k=3 rule in TOLERANCE_FRAMEWORK.md Class M.
*
* This test is what converts "pooled from 9 independent shards" into "equal to
* the 999-draw run". Until it passes, the former is the only honest phrasing.
local ++test_count
if `run_only' == 0 | `run_only' == 17 {
capture noisily {
    local R = 999
    local mcse = sqrt(2) / sqrt(2*(`R'-1))
    local tol = 3 * `mcse'
    display as text "  MCSE(relative SE difference) = " %6.4f `mcse'
    display as text "  tolerance (k=3)              = " %6.4f `tol'

    * The single 999-draw reference, on a stream no shard used.
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(999) seed(3030)) rngstream(100) ///
        saving("`work'/t17_ref", replace)
    tempname Vref
    matrix `Vref' = e(V)
    local kterm = colsof(e(b))

    * Nine shards of 111 from a different master seed, so the two sets of draws
    * are independent rather than nested.
    local poollist ""
    forvalues s = 1/9 {
        _v420_weight
        quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
            vce(bootstrap, reps(111) seed(9090)) rngstream(`s') ///
            saving("`work'/t17_s`s'", replace)
        local poollist "`poollist' `work'/t17_s`s'.dta"
    }
    quietly iivw_bspool using "`poollist'", notable reps(999)
    tempname Vpool
    matrix `Vpool' = e(V)

    local worst = 0
    local worstterm ""
    local names : colnames e(b)
    forvalues j = 1/`kterm' {
        local se_ref  = sqrt(el(`Vref', `j', `j'))
        local se_pool = sqrt(el(`Vpool', `j', `j'))
        local rel = abs(`se_pool' - `se_ref') / `se_ref'
        local nm : word `j' of `names'
        display as text "  " %-10s "`nm'" ///
            "  SE(1x999) = " %9.6f `se_ref' ///
            "  SE(9x111) = " %9.6f `se_pool' ///
            "  rel = " %7.4f `rel'
        if `rel' > `worst' {
            local worst = `rel'
            local worstterm "`nm'"
        }
    }
    display as text "  worst relative difference: " %7.4f `worst' " on `worstterm'"
    assert !missing(`worst')
    assert `worst' < `tol'
    display as result "T17 PASS: 9x111 matches 1x999 within Monte Carlo tolerance"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T17"
    display as error "T17 FAIL"
}
}

**# T18: citype(), level() and saving(), and the pooled e() surface

* The pooler's own options and its added returns. The interval identity is the
* oracle rather than a stored number: basic limits are the percentile limits
* reflected about the estimate, and Wald limits are b +/- z*SE from the pooled
* covariance, both of which hold whatever the draws happened to be.
local ++test_count
if `run_only' == 0 | `run_only' == 18 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(20) seed(181)) rngstream(1) saving("`work'/t18_a", replace)
    * saving() is string asis, so e() keeps the spec exactly as typed --
    * embedded quotes and all. Compare with compound quotes; plain ones make
    * assert read the path as a variable name.
    local _want `""`work'/t18_a", replace"'
    assert `"`e(iivw_bs_saving)'"' == `"`_want'"' 
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(20) seed(181)) rngstream(2) saving("`work'/t18_b", replace)

    local files "`work'/t18_a.dta `work'/t18_b.dta"

    * --- citype(basic) at a non-default level, written out for re-pooling
    quietly iivw_bspool using "`files'", notable citype(basic) level(90) ///
        saving("`work'/t18_pooled", replace)

    assert "`e(iivw_ci_type)'" == "basic"
    assert e(level) == 90
    assert e(iivw_interval_available) == 1
    assert "`e(iivw_pooled_by)'" == "iivw_bspool"
    assert "`e(iivw_bs_pooled)'" == "1"
    assert "`e(iivw_bs_seeds)'" == "181 181"
    assert "`e(iivw_bs_shard_files)'" == "`files'"
    local _breldif = real("`e(iivw_bs_anchor_breldif)'")
    assert !missing(`_breldif')
    assert `_breldif' < 1e-10

    * basic == percentile reflected about the point estimate
    tempname B P BAS SEL
    matrix `B'   = e(b)
    matrix `P'   = e(iivw_ci_percentile)
    matrix `BAS' = e(iivw_ci_basic)
    matrix `SEL' = e(iivw_ci)
    local k = colsof(`B')
    local maxdev = 0
    forvalues j = 1/`k' {
        local want_lo = 2*el(`B',1,`j') - el(`P',2,`j')
        local want_hi = 2*el(`B',1,`j') - el(`P',1,`j')
        assert !missing(`want_lo', `want_hi')
        local d1 = reldif(el(`BAS',1,`j'), `want_lo')
        local d2 = reldif(el(`BAS',2,`j'), `want_hi')
        if `d1' > `maxdev' local maxdev = `d1'
        if `d2' > `maxdev' local maxdev = `d2'
        * and citype(basic) is what e(iivw_ci) actually reports
        assert el(`SEL',1,`j') == el(`BAS',1,`j')
        assert el(`SEL',2,`j') == el(`BAS',2,`j')
    }
    display as text "  basic-vs-reflected-percentile max reldif = " %8.2e `maxdev'
    assert !missing(`maxdev')
    assert `maxdev' < 1e-12

    * --- the saved pooled file re-pools to the same answer
    tempname V1
    matrix `V1' = e(V)
    capture confirm file "`work'/t18_pooled.dta"
    assert _rc == 0
    * The saved file must be re-poolable as it stands. iivw_bspool restamps it
    * with the POOLED totals; without that it would carry shard 1's stamp,
    * claiming 20 draws while holding 40, and the truncation guard would refuse
    * it -- so "saving() for re-pooling later" would not have worked at all.
    tempname rf
    frame create `rf'
    frame `rf' {
        use "`work'/t18_pooled.dta", clear
        assert _N == 40
        local restamped : char _dta[_iivw_shard_reps_requested]
        local pooledmark : char _dta[_iivw_shard]
    }
    frame drop `rf'
    assert "`restamped'" == "40"
    assert "`pooledmark'" == "1"
    quietly iivw_bspool using "`work'/t18_pooled.dta", notable citype(basic) level(90)
    assert mreldif(e(V), `V1') == 0
    assert e(iivw_bs_reps_requested) == 40

    * --- citype(wald) is b +/- z*SE from the pooled covariance
    quietly iivw_bspool using "`files'", notable citype(wald)
    assert "`e(iivw_ci_type)'" == "wald-normal"
    assert e(level) == 95
    tempname BW VW CW
    matrix `BW' = e(b)
    matrix `VW' = e(V)
    matrix `CW' = e(iivw_ci)
    local z = invnormal((100+95)/200)
    local maxdev = 0
    forvalues j = 1/`k' {
        local se = sqrt(el(`VW',`j',`j'))
        assert !missing(`se')
        local d1 = reldif(el(`CW',1,`j'), el(`BW',1,`j') - `z'*`se')
        local d2 = reldif(el(`CW',2,`j'), el(`BW',1,`j') + `z'*`se')
        if `d1' > `maxdev' local maxdev = `d1'
        if `d2' > `maxdev' local maxdev = `d2'
    }
    display as text "  wald-vs-b+/-zSE max reldif = " %8.2e `maxdev'
    assert !missing(`maxdev')
    assert `maxdev' < 1e-12

    * --- an unpoolable citype is refused by name
    capture iivw_bspool using "`files'", notable citype(bca)
    assert _rc == 198
    capture iivw_bspool using "`files'", notable citype(nonsense)
    assert _rc == 198
    display as result "T18 PASS: citype(), level(), saving() and the pooled e() surface"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T18"
    display as error "T18 FAIL"
}
}

**# T19: the pooled covariance is the replicate covariance

* An independent oracle for the pooling arithmetic. Everything above checks the
* pooled result against another run of the same machinery, which cannot catch a
* systematic error in that machinery. This computes the bootstrap covariance
* straight from the pooled draws -- the sum of squared deviations about the
* replicate mean, over R-1 -- and asserts e(V) equals it.
local ++test_count
if `run_only' == 0 | `run_only' == 19 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(30) seed(191)) rngstream(1) saving("`work'/t19_a", replace)
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(30) seed(191)) rngstream(2) saving("`work'/t19_b", replace)

    quietly iivw_bspool using "`work'/t19_a.dta `work'/t19_b.dta", notable ///
        saving("`work'/t19_pooled", replace)
    tempname Vgot
    matrix `Vgot' = e(V)
    local k = colsof(e(b))
    local R = e(iivw_bs_reps_completed)
    assert `R' == 60

    * Recompute by hand, in a frame, from the draws themselves.
    tempname hf Vhand
    frame create `hf'
    frame `hf' {
        use "`work'/t19_pooled.dta", clear
        assert _N == 60
        quietly ds
        local vars "`r(varlist)'"
        assert `: word count `vars'' == `k'
        quietly correlate `vars', covariance
        matrix `Vhand' = r(C)
    }
    frame drop `hf'

    local maxdev = 0
    forvalues a = 1/`k' {
        forvalues b = 1/`k' {
            local d = reldif(el(`Vgot',`a',`b'), el(`Vhand',`a',`b'))
            if `d' > `maxdev' local maxdev = `d'
        }
    }
    display as text "  e(V) vs hand-computed replicate covariance: max reldif = " %8.2e `maxdev'
    assert !missing(`maxdev')
    assert `maxdev' < 1e-10
    display as result "T19 PASS: e(V) is the covariance of the pooled draws"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T19"
    display as error "T19 FAIL"
}
}

**# T20: the anchor contract

* iivw_bspool pools into the iivw_fit results in e(). Three properties of that
* anchor are documented and none was exercised above.
*
* Data-free pooling is the driver's real workflow: the shards ran in other
* processes, so the pooling step has estimates but no dataset. It has to work
* with nothing in memory, and it is the case most likely to break silently,
* because e(sample) has nothing to point at.
local ++test_count
if `run_only' == 0 | `run_only' == 20 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(12) seed(201)) rngstream(1) saving("`work'/t20_a", replace)
    estimates save "`work'/t20_anchor", replace
    tempname Bref Vref
    matrix `Bref' = e(b)
    matrix `Vref' = e(V)

    * --- data-free
    clear
    assert c(N) == 0
    estimates use "`work'/t20_anchor"
    quietly iivw_bspool using "`work'/t20_a.dta", notable
    assert mreldif(e(b), `Bref') == 0
    assert mreldif(e(V), `Vref') == 0
    assert e(iivw_bs_reps_requested) == 12
    display as text "  pooled with no data in memory: OK"

    * --- an anchor that is not an iivw_fit
    _v420_weight
    quietly regress y a z1
    capture iivw_bspool using "`work'/t20_a.dta", notable
    local rcw = _rc
    display as text "  non-iivw_fit anchor -> rc = `rcw'"
    assert `rcw' == 301

    * --- data reweighted since the anchor was fit
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(12) seed(202)) rngstream(1) saving("`work'/t20_b", replace)
    quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
        wtype(fiptiw) maxfu(6) scores nolog replace
    capture iivw_bspool using "`work'/t20_b.dta", notable
    local rcs = _rc
    display as text "  data reweighted since the fit -> rc = `rcs'"
    assert `rcs' == 459
    display as result "T20 PASS: data-free pooling works; wrong anchor and stale data are refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T20"
    display as error "T20 FAIL"
}
}

**# T21: a non-default level replays without an error nobody asked for

* A pre-existing defect, found while wiring iivw_bspool's display through the
* same replay program, and RED on shipped 4.1.3.
*
* _iivw_fit_replay parsed its level() as syntax type cilevel. syntax fills a
* cilevel option with c(level) whenever it is omitted, so the option was never
* empty, and the guard meant to refuse "you cannot relabel frozen endpoints at
* a new level" instead compared c(level) with e(level) on every replay. A
* percentile, basic or BCa fit made at any level other than the session default
* therefore refused its own bare replay, citing an option the user had not
* typed. Measured on 4.1.3: level(90) fit, c(level) 95, bare replay -> r(198).
local ++test_count
if `run_only' == 0 | `run_only' == 21 {
capture noisily {
    assert c(level) == 95
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(10) seed(211)) level(90)
    assert e(level) == 90
    assert "`e(iivw_ci_type)'" == "percentile"

    * The user types nothing. This must replay, not error.
    capture noisily iivw_fit
    local rc_bare = _rc
    display as text "  bare replay of a level(90) percentile fit -> rc = `rc_bare'"
    assert `rc_bare' == 0

    * Naming the level the fit already used is also fine.
    capture iivw_fit, level(90)
    assert _rc == 0

    * Asking for a DIFFERENT level is still refused: those endpoints came from
    * the replicate distribution and cannot be relabelled.
    capture iivw_fit, level(80)
    local rc_other = _rc
    display as text "  replay at a different level -> rc = `rc_other'"
    assert `rc_other' == 198

    * A nonsense level is rejected by the replay's own check.
    capture iivw_fit, level(200)
    assert _rc == 198

    * And a Wald fit, which goes down the ereturn display branch, replays too.
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(wald) ///
        vce(bootstrap, reps(10) seed(212)) level(90)
    capture noisily iivw_fit
    assert _rc == 0
    display as result "T21 PASS: a non-default level replays; a changed level is still refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T21"
    display as error "T21 FAIL"
}
}

**# T22: an omitted level() takes the shards' level, not c(level)

* The same syntax-type trap as T21, on the pooler's own option. A cilevel
* option is filled with c(level) whenever it is omitted, so "the user did not
* ask for a level" and "the user asked for the session default" are the same
* string -- and iivw_bspool's documented default is the SHARDS' level. With
* cilevel, pooling shards fit at level(90) in a session at 95 silently reported
* a 95% interval computed from those draws.
*
* The session default is deliberately left at 95 here so the two values differ.
local ++test_count
if `run_only' == 0 | `run_only' == 22 {
capture noisily {
    assert c(level) == 95
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(12) seed(221)) rngstream(1) level(90) ///
        saving("`work'/t22_a", replace)
    assert e(level) == 90
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(12) seed(221)) rngstream(2) level(90) ///
        saving("`work'/t22_b", replace)

    local files "`work'/t22_a.dta `work'/t22_b.dta"

    * No level() typed: the pooled interval must stay at the shards' 90.
    quietly iivw_bspool using "`files'", notable
    display as text "  omitted level() -> e(level) = " e(level) "  (c(level) = " c(level) ")"
    assert e(level) == 90

    * The percentile endpoints must be 90% endpoints, not 95% ones. A 95%
    * interval is strictly wider, so compare the two directly rather than
    * trusting the label.
    tempname C90
    matrix `C90' = e(iivw_ci)
    quietly iivw_bspool using "`files'", notable level(95)
    assert e(level) == 95
    tempname C95
    matrix `C95' = e(iivw_ci)
    local k = colsof(e(b))
    local nwider = 0
    forvalues j = 1/`k' {
        local w90 = el(`C90',2,`j') - el(`C90',1,`j')
        local w95 = el(`C95',2,`j') - el(`C95',1,`j')
        assert !missing(`w90', `w95')
        if `w95' > `w90' local ++nwider
    }
    display as text "  terms where the 95% interval is wider than the 90%: `nwider' of `k'"
    assert `nwider' == `k'

    * An out-of-range level is the pooler's own error, not a silent clamp.
    capture iivw_bspool using "`files'", notable level(200)
    assert _rc == 198
    capture iivw_bspool using "`files'", notable level(abc)
    assert _rc == 198
    display as result "T22 PASS: an omitted level() takes the shards' level"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T22"
    display as error "T22 FAIL"
}
}

**# T23: saving() failures cost nothing they do not have to

* Two separate contracts.
*
* A target that already exists with no replace is the commonest saving()
* mistake, and it has to be caught BEFORE the shards are read and pooled --
* otherwise a nine-shard run does minutes of work and then throws it away over
* a missing word. The test for "early" is that no pooled result was posted.
*
* A write that fails after the pooling succeeded must not roll the pooled
* result back. The user waited for that variance; an unwritable output path is
* not a reason to take it away.
local ++test_count
if `run_only' == 0 | `run_only' == 23 {
capture noisily {
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(12) seed(231)) rngstream(1) saving("`work'/t23_a", replace)
    _v420_weight
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(12) seed(231)) rngstream(2) saving("`work'/t23_b", replace)
    local files "`work'/t23_a.dta `work'/t23_b.dta"

    * A successful pool, so there is a known-good e() to compare against and an
    * existing file to collide with.
    quietly iivw_bspool using "`files'", notable saving("`work'/t23_out", replace)
    tempname Vgood
    matrix `Vgood' = e(V)
    local reps_good = e(iivw_bs_reps_requested)
    capture confirm file "`work'/t23_out.dta"
    assert _rc == 0

    * --- the target exists and replace was not given
    capture iivw_bspool using "`files'", notable saving("`work'/t23_out")
    local rc_exists = _rc
    display as text "  existing target, no replace -> rc = `rc_exists'"
    assert `rc_exists' == 602

    * It failed EARLY: the previous pooled result is still the one in e(),
    * untouched, because no new one was ever posted.
    assert mreldif(e(V), `Vgood') == 0
    assert e(iivw_bs_reps_requested) == `reps_good'

    * --- a write that cannot succeed, discovered after pooling
    * An unwritable directory is not something a test can rely on creating, so
    * use a path whose parent does not exist: resolvable as "new", unwritable
    * when the copy is attempted.
    capture iivw_bspool using "`files'", notable ///
        saving("`work'/t23_no_such_dir/out", replace)
    local rc_write = _rc
    display as text "  unwritable target -> rc = `rc_write'"
    assert `rc_write' == 603

    * The pooled result survives the failed write. This is the contract: a side
    * effect failing must not strand the analytical payload.
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_bs_pooled)'" == "1"
    assert e(iivw_bs_reps_requested) == `reps_good'
    assert mreldif(e(V), `Vgood') == 0
    display as result "T23 PASS: saving() fails early where it can, and never strands e()"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T23"
    display as error "T23 FAIL"
}
}

capture erase "`work'"

iivw_qa_summary, name(test_iivw_v420_shard) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
