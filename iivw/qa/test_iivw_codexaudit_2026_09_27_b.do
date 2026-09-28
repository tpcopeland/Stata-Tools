* test_iivw_codexaudit_2026_09_27_b.do
* Regressions for the 2026-09-27 Codex audit, shard/pool track (F04-F08, F14).
*
*   C1  F04 same b, same N, different outcome data: shards are refused
*   C2  F04 the same, on an IPTW-weighted fit
*   C3  F04 a live weight input edited after the fit is refused at pooling
*   C4  F04 a live outcome edited after the fit is refused at pooling
*   C5  F04 the anchor's own shard missing from the using list is refused
*   C6  F04 negative control: genuine shards and data-free pooling still pool
*   C7  F05 saved pools keep lineage: AB+B and AB+A refused, AB and AB+CD pool
*   C8  F06 x.dta and x.dta.dta: the intended file is written AND stamped
*   C9  F08 native bootstrap fields describe the pooled draws, not the anchor
*   C10 F14 a fractional confidence level replays and pools at that level
*   C11 F07 shard_driver.do refuses stale artifacts after its workers fail
*
* Every case builds genuine shards with iivw_fit. None of them edits an RNG
* state or a lineage label to fake a distinct shard: that fixture tests append
* arithmetic, not identity, which is how F04/F05 got through the 4.2.0 suite.
*
* C11 launches child stata-mp processes through the demo driver's shell launch.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_codexaudit_2026_09_27_b.do [case#]

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

tempfile _stub
local work "`_stub'_cxb"
capture mkdir "`work'"

* Intercept-only, 80 subjects. `scale' stretches the outcome around 1 so two
* datasets share the observed intercept exactly and differ only in spread.
capture program drop _cxb_flat
program define _cxb_flat
    version 16.0
    args scale
    if "`scale'" == "" local scale 1
    clear
    quietly set obs 80
    gen long id = _n
    gen double y = 1 + `scale'*cond(mod(id,2), -1, 1)
end

* The v420 FIPTIW panel, pinned generator.
capture program drop _cxb_panel
program define _cxb_panel
    version 16.0
    clear
    set rng mt64s
    set rngstream 1
    set seed 4713
    quietly set obs 150
    gen long id = _n
    gen double k1 = rnormal()
    gen double z1 = rnormal()
    gen byte a = runiform() < invlogit(.8*k1)
    quietly expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double y = 1 + .5*a + .4*z1 + .3*k1 + .1*t + rnormal()
    gen double keeppr = invlogit(.4 + .9*z1 - .3*a)
    quietly drop if runiform() > keeppr & j > 1
    sort id t
    quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
        wtype(fiptiw) maxfu(7) scores nolog
end

**# C1: same b, same N, different outcome data

* Both observed intercepts are exactly 1 and both files hold 80-subject draws,
* so every check 4.2.0 made agrees. The bootstrap variances differ ~100-fold:
* pooling them reports the variance of neither analysis.
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    _cxb_flat 1
    quietly iivw_fit y, unweighted id(id) timespec(none) ///
        vce(bootstrap, reps(20) fixedweights seed(11)) saving("`work'/c1_a", replace)
    local bA = _b[_cons]
    _cxb_flat 10
    quietly iivw_fit y, unweighted id(id) timespec(none) ///
        vce(bootstrap, reps(20) fixedweights seed(22)) saving("`work'/c1_b", replace)
    local bB = _b[_cons]
    assert !missing(`bA', `bB')
    assert reldif(`bA', `bB') < 1e-12
    capture iivw_bspool using "`work'/c1_a.dta `work'/c1_b.dta", notable
    local rc1 = _rc
    display as text "  different outcome data, same b -> rc = `rc1'"
    assert `rc1' == 459
    display as result "C1 PASS: shards with equal b but different outcome data are refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C1"
    display as error "C1 FAIL"
}
}

**# C2: the same, on an IPTW-weighted fit

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    clear
    quietly set obs 80
    gen long id = _n
    gen double t = 1
    gen byte a = mod(id, 2)
    gen double x = 1
    gen double y = 1 + cond(mod(ceil(id/2), 2), -1, 1)
    quietly iivw_weight, id(id) time(t) wtype(iptw) treat(a) treat_cov(x) nolog
    quietly iivw_fit y, timespec(none) ///
        vce(bootstrap, reps(20) fixedweights seed(11)) saving("`work'/c2_a", replace)
    quietly replace y = 1 + 10*(y - 1)
    quietly iivw_fit y, timespec(none) ///
        vce(bootstrap, reps(20) fixedweights seed(22)) saving("`work'/c2_b", replace)
    capture iivw_bspool using "`work'/c2_a.dta `work'/c2_b.dta", notable
    local rc2 = _rc
    display as text "  weighted, rescaled outcome -> rc = `rc2'"
    assert `rc2' == 459
    display as result "C2 PASS: weighted shards on different outcomes are refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C2"
    display as error "C2 FAIL"
}
}

**# C3-C5 share one pair of genuine FIPTIW shards fit on the same data

capture program drop _cxb_pair
program define _cxb_pair
    version 16.0
    args work
    _cxb_panel
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(12) seed(71)) rngstream(1) saving("`work'/cp_a", double replace)
    estimates store cxb_A
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(12) seed(71)) rngstream(2) saving("`work'/cp_b", double replace)
    estimates store cxb_B
end

**# C3: a live weight input edited after the fit

* _iivw_check_weighted recomputes the signature and returns 459. 4.2.0 pooling
* compared the cached characteristic, which the edit does not touch, and
* returned 0.
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    _cxb_pair "`work'"
    estimates restore cxb_A
    quietly replace z1 = z1 + 1 in 1
    capture _iivw_check_weighted
    local rcg = _rc
    capture iivw_bspool using "`work'/cp_a.dta `work'/cp_b.dta", notable
    local rc3 = _rc
    display as text "  guard = `rcg', pool = `rc3'"
    assert `rcg' == 459
    assert `rc3' == 459
    display as result "C3 PASS: a stale live weight input is refused at pooling"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C3"
    display as error "C3 FAIL"
}
}

**# C4: a live outcome edited after the fit

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    _cxb_pair "`work'"
    estimates restore cxb_A
    * Unedited, the same restore pools. That is what makes the edit the cause.
    quietly iivw_bspool using "`work'/cp_a.dta `work'/cp_b.dta", notable
    estimates restore cxb_A
    quietly replace y = y + 100
    capture iivw_bspool using "`work'/cp_a.dta `work'/cp_b.dta", notable
    local rc4 = _rc
    display as text "  outcome shifted by 100 after the fit -> rc = `rc4'"
    assert `rc4' == 459
    display as result "C4 PASS: a live outcome edit is refused at pooling"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C4"
    display as error "C4 FAIL"
}
}

**# C5: the anchor's own shard file is not in the using list

* A and B fit the same data, so their observed coefficients are identical and
* coefficient equality cannot tell A's anchor from B's.
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    _cxb_pair "`work'"
    estimates restore cxb_A
    capture iivw_bspool using "`work'/cp_b.dta", notable
    local rc5 = _rc
    display as text "  anchor A, file B only -> rc = `rc5'"
    assert `rc5' == 459
    * And with A's file present the same anchor pools.
    estimates restore cxb_A
    quietly iivw_bspool using "`work'/cp_b.dta `work'/cp_a.dta", notable
    assert e(iivw_bs_reps_requested) == 24
    display as result "C5 PASS: anchor membership is checked by identity"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C5"
    display as error "C5 FAIL"
}
}

**# C6: negative control -- genuine shards and data-free pooling still pool

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    _cxb_pair "`work'"
    estimates restore cxb_B
    quietly iivw_bspool using "`work'/cp_a.dta `work'/cp_b.dta", notable
    assert e(iivw_bs_reps_requested) == 24
    tempname V6
    matrix `V6' = e(V)
    * Data-free: anchor from disk, nothing in memory.
    estimates restore cxb_B
    estimates save "`work'/c6_anchor", replace
    clear
    estimates use "`work'/c6_anchor"
    quietly iivw_bspool using "`work'/cp_a.dta `work'/cp_b.dta", notable
    assert !matmissing(`V6')
    assert mreldif(e(V), `V6') < 1e-15
    * A harmless re-sort of the live data does not trip the live check.
    _cxb_pair "`work'"
    gsort -id -t
    quietly iivw_bspool using "`work'/cp_a.dta `work'/cp_b.dta", notable
    assert e(iivw_bs_reps_requested) == 24
    display as result "C6 PASS: genuine, data-free and re-sorted pooling still work"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C6"
    display as error "C6 FAIL"
}
}

**# C7: saved pools keep their component lineage

* Four genuine shards on four streams. AB and CD are saved pools. AB+B holds 40
* distinct draws, not 60; AB+A likewise. AB+CD is disjoint and must pool to 80.
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    _cxb_flat 1
    forvalues s = 1/4 {
        local L : word `s' of A B C D
        quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
            vce(bootstrap, reps(10) fixedweights seed(11)) rngstream(`s') ///
            saving("`work'/c7_`L'", replace)
        estimates store cxb7_`L'
    }
    estimates restore cxb7_B
    quietly iivw_bspool using "`work'/c7_A.dta `work'/c7_B.dta", notable ///
        saving("`work'/c7_AB", replace)
    assert e(iivw_bs_reps_requested) == 20
    estimates store cxb7_AB
    estimates restore cxb7_D
    quietly iivw_bspool using "`work'/c7_C.dta `work'/c7_D.dta", notable ///
        saving("`work'/c7_CD", replace)
    estimates store cxb7_CD

    estimates restore cxb7_AB
    quietly iivw_bspool using "`work'/c7_AB.dta", notable
    assert e(iivw_bs_reps_requested) == 20
    local rcAB = 0

    estimates restore cxb7_AB
    capture iivw_bspool using "`work'/c7_AB.dta `work'/c7_B.dta", notable
    local rcABB = _rc
    estimates restore cxb7_AB
    capture iivw_bspool using "`work'/c7_AB.dta `work'/c7_A.dta", notable
    local rcABA = _rc
    * The overlap is refused whichever file carries the anchor.
    estimates restore cxb7_B
    capture iivw_bspool using "`work'/c7_B.dta `work'/c7_AB.dta", notable
    local rcBAB = _rc

    estimates restore cxb7_CD
    quietly iivw_bspool using "`work'/c7_AB.dta `work'/c7_CD.dta", notable
    local repsABCD = e(iivw_bs_reps_requested)
    local linABCD : word count `e(iivw_bs_lineage)'
    display as text "  AB+B -> `rcABB'   AB+A -> `rcABA'   B+AB -> `rcBAB'"
    display as text "  AB+CD -> reps `repsABCD', lineage size `linABCD'"
    assert `rcABB' == 459
    assert `rcABA' == 459
    assert `rcBAB' == 459
    assert `repsABCD' == 40
    assert `linABCD' == 4
    display as result "C7 PASS: pooled files keep lineage; overlaps are refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C7"
    display as error "C7 FAIL"
}
}

**# C8: exact saving() path resolution

* bootstrap writes saving(x.dta) to x.dta. With x.dta.dta also present, 4.2.0
* stamped x.dta.dta instead and left the file it had just written unstamped.
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    _cxb_flat 1
    quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
        vce(bootstrap, reps(12) fixedweights seed(81)) rngstream(1) ///
        saving("`work'/c8.dta.dta", replace)
    quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
        vce(bootstrap, reps(14) fixedweights seed(81)) rngstream(2) ///
        saving("`work'/c8.dta", replace)
    tempname fr8
    frame create `fr8'
    frame `fr8' {
        use "`work'/c8.dta", clear
        local mk14 : char _dta[_iivw_shard]
        local rq14 : char _dta[_iivw_shard_reps_requested]
        local n14 = _N
        use "`work'/c8.dta.dta", clear
        local rq12 : char _dta[_iivw_shard_reps_requested]
        local n12 = _N
    }
    frame drop `fr8'
    display as text "  c8.dta: stamp=[`mk14'] requested=`rq14' rows=`n14'"
    display as text "  c8.dta.dta: requested=`rq12' rows=`n12'"
    assert "`mk14'" == "1" & "`rq14'" == "14" & `n14' == 14
    assert "`rq12'" == "12" & `n12' == 12
    * Pooling resolves the typed name exactly too.
    quietly iivw_bspool using "`work'/c8.dta", notable
    assert e(iivw_bs_reps_requested) == 14
    * A suffixless name still gets .dta, as bootstrap wrote it.
    quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
        vce(bootstrap, reps(6) fixedweights seed(81)) rngstream(3) ///
        saving("`work'/c8 plain", replace)
    quietly iivw_bspool using `""`work'/c8 plain""', notable
    assert e(iivw_bs_reps_requested) == 6
    display as result "C8 PASS: the file written is the file stamped and pooled"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C8"
    display as error "C8 FAIL"
}
}

**# C9: native bootstrap fields after pooling

local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    _cxb_flat 1
    quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
        vce(bootstrap, reps(20) fixedweights seed(11)) rngstream(1) saving("`work'/c9_a", replace)
    quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
        vce(bootstrap, reps(20) fixedweights seed(11)) rngstream(2) saving("`work'/c9_b", replace)
    quietly iivw_bspool using "`work'/c9_a.dta `work'/c9_b.dta", notable ///
        saving("`work'/c9_ab", replace)
    display as text "  N_reps=" e(N_reps) " iivw completed=" e(iivw_bs_reps_completed)
    assert e(N_reps) == 40
    assert e(N_misreps) == 0
    assert e(N_reps) == e(iivw_bs_reps_completed)
    assert !matmissing(e(iivw_ci_percentile))
    assert mreldif(e(ci_percentile), e(iivw_ci_percentile)) < 1e-12
    tempname se9
    matrix `se9' = e(se)
    assert !missing(el(`se9',1,1), sqrt(el(e(V),1,1)))
    assert reldif(el(`se9',1,1), sqrt(el(e(V),1,1))) < 1e-12
    assert rowsof(e(reps)) == 1 & el(e(reps),1,1) == 40
    assert `"`e(iivw_bs_saving)'"' == `"`work'/c9_ab.dta"'
    assert `"`e(rngstate)'"' == ""
    * estat bootstrap reads the native fields; it must show the pooled interval.
    quietly estat bootstrap, percentile
    tempname Pe
    matrix `Pe' = e(ci_percentile)
    assert mreldif(`Pe', e(iivw_ci_percentile)) < 1e-12
    * Without saving(), there is no single replicate file for the result.
    quietly iivw_bspool using "`work'/c9_a.dta `work'/c9_b.dta", notable
    assert `"`e(iivw_bs_saving)'"' == ""
    display as result "C9 PASS: native bootstrap fields describe the pooled draws"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C9"
    display as error "C9 FAIL"
}
}

**# C10: fractional confidence levels in replay and pooling

local ++test_count
if `run_only' == 0 | `run_only' == 10 {
capture noisily {
    _cxb_flat 1
    quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) level(95.5) ///
        vce(bootstrap, reps(20) fixedweights seed(11)) rngstream(1) saving("`work'/c10", replace)
    assert e(level) == 95.5
    capture noisily iivw_fit, level(95.5)
    local rcr = _rc
    capture noisily iivw_fit
    local rcr0 = _rc
    capture iivw_fit, level(90)
    local rcr90 = _rc
    capture iivw_bspool using "`work'/c10.dta", level(95.5) notable
    local rcp = _rc
    local lvp = e(level)
    quietly iivw_bspool using "`work'/c10.dta", notable
    local lv0 = e(level)
    quietly iivw_bspool using "`work'/c10.dta", notable level(90.5)
    local lv905 = e(level)
    capture iivw_bspool using "`work'/c10.dta", notable level(99.995)
    local rcbad = _rc
    capture iivw_bspool using "`work'/c10.dta", notable level(9.5)
    local rcbad2 = _rc
    display as text "  replay 95.5 -> `rcr'  bare -> `rcr0'  changed 90 -> `rcr90'"
    display as text "  pool 95.5 -> `rcp' (level `lvp')  omitted -> `lv0'  90.5 -> `lv905'"
    display as text "  pool 99.995 -> `rcbad'  9.5 -> `rcbad2'"
    assert `rcr' == 0
    assert `rcr0' == 0
    assert `rcr90' == 198
    assert `rcp' == 0 & `lvp' == 95.5
    assert `lv0' == 95.5
    assert `lv905' == 90.5
    assert `rcbad' == 198
    assert `rcbad2' == 198
    display as result "C10 PASS: fractional levels replay and pool; changed levels still refuse"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C10"
    display as error "C10 FAIL"
}
}

**# C11: shard_driver.do refuses stale artifacts after its workers fail

* Run the documented driver twice in the same directory. The first run is
* genuine. The second run's workers die before fitting (weightcall error 498);
* 4.2.0's driver then pooled the first run's files and returned 0.
*
* The only edits to the driver copy are the CONFIGURATION values, plus one
* profile line that puts this checkout first on each child's adopath.
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
capture noisily {
    local dwork "`work'/c11"
    capture mkdir "`dwork'"
    clear
    quietly set obs 80
    gen long id = _n
    gen double y = mod(id, 2)*2
    gen double t = 1
    gen byte a = mod(id, 2)
    gen byte x = mod(floor(id/2), 2)
    quietly iivw_weight, id(id) time(t) wtype(iptw) treat(a) treat_cov(x) nolog
    quietly save "`dwork'/shard_panel.dta", replace

    local src "`pkg_dir'/demo/shard_driver.do"
    tempfile s1 s2 s3 s4 s5
    filefilter "`src'" "`s1'", from("local reps_total 999") to("local reps_total 10") replace
    filefilter "`s1'" "`s2'", from("local nshard 9") to("local nshard 2") replace
    filefilter "`s2'" "`s3'", from(`"local indepvar \Qa z1\Q"') to(`"local indepvar \Q\Q"') replace
    filefilter "`s3'" "`s4'", from("timespec(linear) citype(percentile)") ///
        to("timespec(none) citype(percentile)") replace
    filefilter "`s4'" "`s5'", ///
        from(`"file write \LQpf\RQ \Qset processors 1\Q _n"') ///
        to(`"file write \LQpf\RQ \Qset processors 1\Q _n\n    file write \LQpf\RQ \Qadopath ++ \Q _char(34) \Q`pkg_dir'\Q _char(34) _n"') replace
    assert r(occurrences) == 1
    copy "`s5'" "`dwork'/driver_ok.do", replace
    filefilter "`s5'" "`dwork'/driver_bad.do", ///
        from(`"local weightcall \Q\Q"') to(`"local weightcall \Qerror 498\Q"') replace
    assert r(occurrences) == 1

    local here "`c(pwd)'"
    quietly cd "`dwork'"
    capture noisily do driver_ok.do
    local rc_ok = _rc
    local reps_ok = e(iivw_bs_reps_completed)
    capture noisily do driver_bad.do
    local rc_bad = _rc
    quietly cd "`here'"
    * The driver starts with clear all, which drops the QA helper programs.
    quietly do "`qa_dir'/_iivw_qa_common.do"
    display as text "  first run rc = `rc_ok' (reps `reps_ok'); failed-worker rerun rc = `rc_bad'"
    assert `rc_ok' == 0
    assert `reps_ok' == 10
    assert `rc_bad' != 0
    display as result "C11 PASS: the driver pools only artifacts of the current run"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' C11"
    display as error "C11 FAIL"
}
}

capture estimates drop cxb_*
capture erase "`work'"

iivw_qa_summary, name(test_iivw_codexaudit_2026_09_27_b) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
