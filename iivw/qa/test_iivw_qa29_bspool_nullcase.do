* test_iivw_qa29_bspool_nullcase.do
* Degenerate inputs to iivw_bspool (QA round 2026-10-29, nullcase view). Each
* case supplies the null version of one boundary iivw_bspool crosses -- the
* saved replicate files, their _dta characteristics, the e() it pools into --
* and asserts the exact return code, the message class, and that a refused
* pool leaves the anchor in e() exactly as it was.
*
*   N1  no shard files: an empty using list, a blank one, a missing file
*   N2  a shard with zero replicates: rows emptied under the original stamps,
*       and an honestly stamped empty file
*   N3  all-missing replicate draws: under stamps claiming them complete;
*       honestly stamped as failed beside a complete shard (the failure gate);
*       and honestly stamped as failed alone, refused by the zero-draw variance
*       with or without allowfailedreps
*   N4  a single replicate: a one-draw shard, and a pool with one completed draw
*   N5  mismatched coefficient columns: a dropped column, permuted columns, a
*       renamed column under the same stripes
*   N6  degenerate e(): a foreign estimate, no estimate, a non-bootstrap fit
*   N7  degenerate _dta characteristics: no shard marker, no lineage, a
*       nonnumeric count stamp
*   N8  exactly one failed draw in the pool: refused without allowfailedreps,
*       accepted with it, and counted as one
*   N9  an anchor the shards do not describe: fit on different data (refused by
*       the analysis identity), and shard observed estimates that disagree with
*       the anchor's e(b) under a matching identity (the anchor-b guard)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_qa29_bspool_nullcase.do [case#]

clear all
set varabbrev off
set linesize 255
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

tempfile _stub
local work "`_stub'_qa29nc"
capture mkdir "`work'"
local here "`c(pwd)'"
quietly cd "`work'"
global QA29N_LOG "`work'/_qa29n_msg.log"

* Message capture: a second, named text log around one refused call. The
* message class is then read back from what the user would have seen.
capture program drop _qa29n_open
program define _qa29n_open
    version 16.0
    capture log close _qa29m
    quietly log using "$QA29N_LOG", text replace name(_qa29m)
end
capture program drop _qa29n_msg
program define _qa29n_msg
    version 16.0
    args text
    capture log close _qa29m
    tempname fh
    local found 0
    file open `fh' using "$QA29N_LOG", read text
    file read `fh' line
    while r(eof) == 0 {
        * Skip the log's echo of commands (". cmd", "> continuation"): the
        * echo of this very call carries the expected text, which made every
        * message check pass on its own (caught by mutation M22).
        local _echo = (substr(`"`macval(line)'"', 1, 2) == ". " | ///
            substr(`"`macval(line)'"', 1, 2) == "> ")
        if !`_echo' & strpos(`"`macval(line)'"', `"`text'"') local found 1
        file read `fh' line
    }
    file close `fh'
    if !`found' display as error `"expected message not printed: `text'"'
    assert `found' == 1
end

* The anchor after a refused pool: still the shard-1 fit, not a pool, with its
* own 30-draw covariance to the last bit.
capture program drop _qa29n_intact
program define _qa29n_intact
    version 16.0
    args Vanchor
    assert "`e(cmd)'" == "iivw_fit"
    assert "`e(iivw_bs_pooled)'" == ""
    assert e(N_reps) == 30
    assert e(iivw_bs_reps_requested) == 30
    assert mreldif(e(V), `Vanchor') == 0
end

* Fixture: two 30-draw shards of one unweighted analysis (streams 1, 2) and the
* derived degenerate files. Built once; each case restores the anchor.
capture program drop _qa29n_fixture
program define _qa29n_fixture
    version 16.0
    clear
    set rng mt64s
    set rngstream 1
    set seed 121
    set obs 50
    gen long id = _n
    expand 3
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double y = 1 + 0.3*x + 0.2*t + rnormal()
    forvalues s = 1/2 {
        quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
            vce(bootstrap, reps(30) seed(43) fixedweights) citype(percentile) ///
            rngstream(`s') saving(n_p`s', double replace) nolog
        estimates store n_a`s'
    }
    preserve

    * zero replicates: rows emptied, stamps left at 30
    quietly use n_p2, clear
    quietly drop in 1/l
    quietly save n_zero_stale, replace
    * zero replicates, honestly stamped
    char _dta[_iivw_shard_reps_requested] "0"
    char _dta[_iivw_shard_reps_completed] "0"
    char _dta[_iivw_shard_reps_failed] "0"
    quietly save n_zero_honest, replace

    * all-missing draws under stamps that still claim 30 completed
    quietly use n_p2, clear
    foreach v of varlist _all {
        quietly replace `v' = .
    }
    quietly save n_allmiss_stale, replace
    * all-missing draws in the anchor's own shard, honestly stamped as failed
    quietly use n_p1, clear
    foreach v of varlist _all {
        quietly replace `v' = .
    }
    char _dta[_iivw_shard_reps_completed] "0"
    char _dta[_iivw_shard_reps_failed] "30"
    quietly save n_allmiss_honest, replace
    * the same for shard 2, to pool beside the anchor's complete shard
    quietly use n_p2, clear
    foreach v of varlist _all {
        quietly replace `v' = .
    }
    char _dta[_iivw_shard_reps_completed] "0"
    char _dta[_iivw_shard_reps_failed] "30"
    quietly save n_allmiss_honest2, replace

    * a one-draw shard, honestly stamped
    quietly use n_p2, clear
    quietly keep in 1
    char _dta[_iivw_shard_reps_requested] "1"
    char _dta[_iivw_shard_reps_completed] "1"
    char _dta[_iivw_shard_reps_failed] "0"
    quietly save n_single, replace
    * the anchor's shard with one completed draw and 29 failed
    quietly use n_p1, clear
    foreach v of varlist _all {
        quietly replace `v' = . if _n > 1
    }
    char _dta[_iivw_shard_reps_completed] "1"
    char _dta[_iivw_shard_reps_failed] "29"
    quietly save n_onedone, replace

    * coefficient columns: dropped, permuted, renamed under the same stripes
    quietly use n_p2, clear
    drop y_b_t
    quietly save n_dropcol, replace
    quietly use n_p2, clear
    order y_b_t y_b_x y_b_cons
    quietly save n_permcol, replace
    quietly use n_p2, clear
    rename y_b_x y_b_xx
    quietly save n_renamecol, replace

    * characteristics: no shard marker, no lineage, nonnumeric count
    quietly use n_p2, clear
    char _dta[_iivw_shard] ""
    quietly save n_nomarker, replace
    quietly use n_p2, clear
    char _dta[_iivw_shard_lineage] ""
    quietly save n_nolineage, replace
    quietly use n_p2, clear
    char _dta[_iivw_shard_reps_failed] "none"
    quietly save n_badcount, replace

    * exactly one failed draw, honestly stamped
    quietly use n_p2, clear
    foreach v of varlist _all {
        quietly replace `v' = . in 1
    }
    char _dta[_iivw_shard_reps_completed] "29"
    char _dta[_iivw_shard_reps_failed] "1"
    quietly save n_onefail, replace

    * the anchor's own shard with its observed estimate of x moved by 1%:
    * identity and lineage stamps intact, so only the anchor-b guard can see it
    quietly use n_p1, clear
    local obx : char y_b_x[observed]
    local obx2 : display %21.17g 1.01*real("`obx'")
    char y_b_x[observed] "`obx2'"
    quietly save n_obsedit, replace

    restore
end

_qa29n_fixture
estimates restore n_a1
tempname VA
matrix `VA' = e(V)

**# N1: no shard files
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    estimates restore n_a1

    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "", notable
    local rc = _rc
    assert `rc' == 198
    _qa29n_msg "invalid file specification"
    _qa29n_intact `VA'

    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using " ", notable
    local rc = _rc
    assert `rc' == 198
    _qa29n_msg "iivw_bspool: no replicate files given"
    _qa29n_intact `VA'

    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_absent.dta", notable
    local rc = _rc
    assert `rc' == 601
    _qa29n_msg "iivw_bspool: no replicate file at n_absent.dta"
    _qa29n_intact `VA'
    display as result "N1 PASS: empty, blank and missing file lists refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' N1"
    display as error "N1 FAIL"
}
}

**# N2: a shard with zero replicates
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    estimates restore n_a1

    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_zero_stale.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "artifact row count/stamps disagree in n_zero_stale.dta"
    _qa29n_intact `VA'

    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_zero_honest.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: n_zero_honest.dta requested 0 draw(s); a shard must request at least 2"
    _qa29n_intact `VA'
    display as result "N2 PASS: zero-replicate shards refused, stale or honestly stamped"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' N2"
    display as error "N2 FAIL"
}
}

**# N3: all-missing replicate draws
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    estimates restore n_a1

    * all-missing draws the stamps call complete
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_allmiss_stale.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "artifact completed/failed stamps disagree in n_allmiss_stale.dta"
    _qa29n_intact `VA'

    * honestly failed beside a complete shard: the pooled failure gate
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_allmiss_honest2.dta", notable
    local rc = _rc
    assert `rc' == 430
    _qa29n_msg "30 of 60 pooled bootstrap replicates failed"
    _qa29n_intact `VA'

    * honestly failed and alone: zero completed draws give no variance, and
    * bstat refuses before the failure gate is reached, with or without
    * allowfailedreps; bstat posts nothing, so the anchor stays in e()
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_allmiss_honest.dta", notable
    local rc = _rc
    assert `rc' == 2000
    _qa29n_msg "insufficient observations to compute bootstrap standard errors"
    _qa29n_intact `VA'

    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_allmiss_honest.dta", notable allowfailedreps
    local rc = _rc
    assert `rc' == 2000
    _qa29n_msg "insufficient observations to compute bootstrap standard errors"
    _qa29n_intact `VA'

    * the same honest file beside a complete shard is a legitimate pool of 30
    * completed draws when the failures are acknowledged
    estimates restore n_a2
    quietly iivw_bspool using "n_allmiss_honest.dta n_p2.dta", notable allowfailedreps
    assert e(N_reps) == 30
    assert e(N_misreps) == 30
    assert e(iivw_bs_reps_requested) == 60
    assert "`e(iivw_allowfailedreps)'" == "1"
    * unweighted outranks failed draws in the status, as it does in iivw_fit
    assert "`e(iivw_inference_status)'" == "not-applicable-unweighted"
    display as result "N3 PASS: all-missing draws refused at the stamp, gate and variance"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' N3"
    display as error "N3 FAIL"
}
}

**# N4: a single replicate
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    estimates restore n_a1

    * a shard that requested one draw
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_single.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: n_single.dta requested 1 draw(s); a shard must request at least 2"
    _qa29n_intact `VA'

    * one completed draw in the whole pool
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_onedone.dta", notable allowfailedreps
    local rc = _rc
    assert `rc' == 2000
    _qa29n_msg "insufficient observations to compute bootstrap standard errors"
    _qa29n_intact `VA'
    display as result "N4 PASS: single-replicate shards and one-draw pools refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' N4"
    display as error "N4 FAIL"
}
}

**# N5: mismatched coefficient columns across shards
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    estimates restore n_a1

    * a dropped column
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_dropcol.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: shards disagree on coefficient names"
    _qa29n_intact `VA'

    * the same columns in another order
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_permcol.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: shards disagree on coefficient names"
    _qa29n_intact `VA'

    * a renamed column under unchanged stripes
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_renamecol.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: shards disagree on saved variable names"
    _qa29n_intact `VA'
    display as result "N5 PASS: dropped, permuted and renamed coefficient columns refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' N5"
    display as error "N5 FAIL"
}
}

**# N6: degenerate e()
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {

    * a foreign estimate in e()
    * nullcase: iivw_bspool
    quietly regress y x
    tempname bR
    matrix `bR' = e(b)
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_p2.dta", notable
    local rc = _rc
    assert `rc' == 301
    _qa29n_msg "iivw_bspool requires iivw_fit estimation results"
    assert "`e(cmd)'" == "regress"
    assert mreldif(e(b), `bR') == 0

    * no estimate at all
    * nullcase: iivw_bspool
    ereturn clear
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_p2.dta", notable
    local rc = _rc
    assert `rc' == 301
    _qa29n_msg "iivw_bspool requires iivw_fit estimation results"
    assert "`e(cmd)'" == ""

    * an iivw_fit with no draws
    * nullcase: iivw_bspool
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
    tempname VF
    matrix `VF' = e(V)
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_p2.dta", notable
    local rc = _rc
    assert `rc' == 198
    _qa29n_msg "iivw_bspool: the results in e() are not a bootstrap fit"
    assert "`e(cmd)'" == "iivw_fit"
    assert "`e(iivw_vce)'" == "fixed"
    assert mreldif(e(V), `VF') == 0
    display as result "N6 PASS: foreign, absent and non-bootstrap anchors refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' N6"
    display as error "N6 FAIL"
}
}

**# N7: degenerate _dta characteristics
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    estimates restore n_a1

    * the shard marker is missing
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_nomarker.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: n_nomarker.dta is not an iivw shard file"
    _qa29n_intact `VA'

    * the lineage stamp is missing
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_nolineage.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: n_nolineage.dta carries no analysis identity or lineage"
    _qa29n_intact `VA'

    * a count stamp that is not a number
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_badcount.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: nonnumeric fail count in n_badcount.dta"
    _qa29n_intact `VA'
    display as result "N7 PASS: missing marker, missing lineage and nonnumeric stamps refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' N7"
    display as error "N7 FAIL"
}
}

**# N8: exactly one failed draw
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    estimates restore n_a1

    * one failed draw of 60, without allowfailedreps
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_onefail.dta", notable
    local rc = _rc
    assert `rc' == 430
    _qa29n_msg "1 of 60 pooled bootstrap replicates failed"
    _qa29n_intact `VA'

    * acknowledged, the pool stands on 59 draws and says so
    quietly iivw_bspool using "n_p1.dta n_onefail.dta", notable allowfailedreps
    assert e(N_misreps) == 1
    assert e(N_reps) == 59
    assert e(iivw_bs_reps_failed) == 1
    assert e(iivw_bs_reps_completed) == 59
    assert e(iivw_bs_reps_requested) == 60
    assert el(e(reps), 1, 1) == 59
    assert "`e(iivw_allowfailedreps)'" == "1"
    display as result "N8 PASS: a single failed draw is gated, and counted once when accepted"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' N8"
    display as error "N8 FAIL"
}
}

**# N9: an anchor the shards do not describe
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    * an anchor fit on different data, same seed and stream as shard 1
    preserve
    quietly replace y = y + 0.5*x
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
        vce(bootstrap, reps(30) seed(43) fixedweights) citype(percentile) ///
        rngstream(1) saving(n_other, double replace) nolog
    tempname VO
    matrix `VO' = e(V)
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_p1.dta n_p2.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: shards disagree on outcome-analysis identity"
    assert "`e(iivw_bs_pooled)'" == ""
    assert mreldif(e(V), `VO') == 0
    restore

    * identity intact, observed estimates that are not the anchor's e(b)
    estimates restore n_a1
    * nullcase: iivw_bspool
    _qa29n_open
    capture noisily iivw_bspool using "n_obsedit.dta", notable
    local rc = _rc
    assert `rc' == 459
    _qa29n_msg "iivw_bspool: the shards' observed estimates are not the anchor's"
    _qa29n_intact `VA'
    display as result "N9 PASS: a different-data anchor and anchor-b disagreement refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' N9"
    display as error "N9 FAIL"
}
}

capture log close _qa29m
quietly cd "`here'"
iivw_qa_summary, name(test_iivw_qa29_bspool_nullcase) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
