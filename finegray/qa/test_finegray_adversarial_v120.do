*! test_finegray_adversarial_v120 Version 1.0.0  2026/08/26
*! Adversarial coverage for the v1.2.0 surface: delayed entry, truncstrata(),
*! nuisance, bootstrap CIs, and the missing-compete() refusal
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* The 1.2.0 features are each covered by a suite that asks whether the feature
* works. What none of them asks is what the feature does at the edge of its own
* support, where "works" and "reports a number" stop being the same thing:
*
*  1. THE RISK-SET CONVENTION, HAND-CHECKED. test_finegray_ties.do pins entry-
*     boundary INVARIANCE -- moving t0 from 5 to 5 + 1e-7 must not move the
*     estimate. That is a comparison of the package with itself. D1 below
*     instead builds the (t0, t] partial likelihood by hand, in Mata, from the
*     raw columns, and compares the number. On a fixture with no competing
*     events and no censoring the subdistribution likelihood IS that partial
*     likelihood, so the hand sum is an oracle with no code in common with the
*     engine -- and the (t0 <= t] variant of the same sum, computed in the same
*     loop, shows what a flipped convention would have cost.
*
*  2. AN EMPTY RISK SET. With every subject entering at 5, no time before 5 has
*     anyone at risk. A CIF evaluated there must be exactly 0 and must say so;
*     a positive number from an empty risk set would be reported with a standard
*     error and believed.
*
*  3. DEGENERATE WEIGHT STRATA. A truncation stratum with one subject cannot
*     support an entry distribution, and the package refuses it. A stratum
*     whose entries are all identical can, and must not be confused with the
*     first. When every stratum has the SAME entry distribution the stratified
*     weight must reproduce the pooled one exactly -- an invariance the fit
*     cannot satisfy by accident.
*
*  4. HONESTY UNDER PARTIAL FAILURE. A bootstrap whose replications fail must
*     reconcile: requested = success + failed, the count must be printed, and
*     below the usable floor the interval must be refused rather than built from
*     what survived.
*
*  5. A REFUSAL THAT IS SCOPED. The 1.2.0 missing-compete() fix refuses rather
*     than silently dropping events. A refusal that fired on rows the fit would
*     never have touched would be a different bug of the same size: D7 and D8
*     exclude the offending record by `if' and by stset respectively, and both
*     fits must succeed.

clear all
set more off
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_adversarial_v120.log", replace text name(_fgadv120)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgadvlt_result
program define _fgadvlt_result, rclass
    version 16.0
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        return scalar pass = 0
        return scalar fail = 1
    }
end

capture program drop _fgadvlt_saw
program define _fgadvlt_saw, rclass
    version 16.0
    syntax using/, PHrase(string)
    tempname fh
    local n = 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`phrase'"') > 0 local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar saw = `n'
end

* Run one command with its console output captured; report the return code and
* how often a phrase appeared. Compound-quoted because every call carries
* commas of its own.
capture program drop _fgadvlt_cap
program define _fgadvlt_cap, rclass
    version 16.0
    gettoken cmd 0 : 0
    gettoken phrase 0 : 0
    tempfile cap
    capture log close _fgadvltcap
    log using `"`cap'"', replace text name(_fgadvltcap)
    capture noisily `cmd'
    local rc = _rc
    capture log close _fgadvltcap
    _fgadvlt_saw using `"`cap'"', phrase(`"`phrase'"')
    return scalar saw = r(saw)
    return scalar rc = `rc'
end

* Delayed-entry competing-risks fixture. The weight machinery refuses a joint
* weight stratum with fewer than 20 subjects, so every fixture here is at least
* that size per group.
capture program drop _fgadvlt_data
program define _fgadvlt_data
    version 16.0
    syntax [, N(integer 400) SEED(integer 3141)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x = rnormal()
    gen byte g = 1 + mod(_n, 2)
    gen long cl = 1 + mod(_n, 50)
    gen double t0 = cond(mod(_n, 3) == 0, 2, 0)
    gen double u = runiform()
    gen double t = t0 + 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = status > 0
    drop u
    quietly stset t, failure(anyev) id(id) time0(t0)
end

* -----------------------------------------------------------------------------
**# D1 entry exactly at another subject's event time, against a hand-built
**#    (t0, t] partial likelihood
* -----------------------------------------------------------------------------
* Eight subjects enter at exactly 5 and five subjects fail at exactly 5. Under
* (t0, t] risk sets the entrants are NOT at risk for those failures, and the
* whole delayed-entry branch rests on that.
*
* The fixture has no competing events and no censoring, so every ZZF weight is 1
* and the subdistribution log-likelihood is the ordinary delayed-entry Cox
* partial log-likelihood. The Mata loop below builds that sum from t0, t, x and
* status directly -- no package program, no stcox -- and evaluates it at the
* coefficient finegray reported. It also builds the (t0 <= t] version in the
* same loop; that one must be materially different, or the fixture would not be
* able to tell the two conventions apart at all.
local ++test_count
capture noisily {
    clear
    set seed 606
    quietly set obs 30
    gen long id = _n
    gen byte x = mod(_n, 2)
    gen double t0 = 0
    gen double t = 2 + mod(_n, 9)
    gen byte status = 1
    quietly replace t0 = 5 in 1/8
    quietly replace t = 6 + mod(_n, 5) in 1/8
    quietly replace t = 5 in 20/24
    quietly replace t0 = 0 in 20/24
    gen byte anyev = status > 0

    quietly count if t == 5 & status == 1
    assert !missing(r(N))
    assert r(N) >= 5
    quietly count if t0 == 5
    assert !missing(r(N))
    assert r(N) == 8
    quietly count if status != 1
    assert !missing(r(N))
    assert r(N) == 0

    quietly stset t, failure(anyev) id(id) time0(t0)
    quietly finegray x, compete(status) cause(1) norobust nolog
    assert e(N) == 30
    assert e(N_delayed) == 8
    assert "`e(lt_weight)'" == "zzf1_geskus"
    local _bfg = _b[x]
    local _llfg = e(ll)
    assert !missing(`_bfg', `_llfg')

    mata: b = strtoreal(st_local("_bfg"));                                    ///
        D = st_data(., ("t0", "t", "x", "status"));                           ///
        n = rows(D); ll = 0; llw = 0;                                         ///
        for (i = 1; i <= n; i++) {                                            ///
            if (D[i, 4] == 1) {                                               ///
                ti = D[i, 2]; s = 0; sw = 0;                                  ///
                for (j = 1; j <= n; j++) {                                    ///
                    if (D[j, 1] <  ti && ti <= D[j, 2])                       ///
                        s  = s  + exp(b * D[j, 3]);                           ///
                    if (D[j, 1] <= ti && ti <= D[j, 2])                       ///
                        sw = sw + exp(b * D[j, 3]);                           ///
                };                                                            ///
                ll  = ll  + b * D[i, 3] - log(s);                             ///
                llw = llw + b * D[i, 3] - log(sw);                            ///
            }                                                                 ///
        };                                                                    ///
        st_local("d1hand", strofreal(ll, "%21.15e"));                       ///
        st_local("d1handw", strofreal(llw, "%21.15e"))

    assert !missing(`d1hand', `d1handw')
    assert reldif(`_llfg', `d1hand') < 1e-12
    * the fixture can tell the conventions apart, and finegray is not the other
    assert reldif(`d1hand', `d1handw') > 1e-3
    assert reldif(`_llfg', `d1handw') > 1e-3
}
local _rc = _rc
_fgadvlt_result `_rc' "D1 the delayed-entry likelihood is the hand-built (t0,t] partial likelihood"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# D2 a zero-length episode: entry exactly at the subject's own failure time
* -----------------------------------------------------------------------------
* (t0, t] with t0 == t is an empty interval: the subject is at risk for nothing,
* including its own failure. stset is the layer that refuses it, counting the
* record under "entry on or after exit" and setting _st to 0. What matters here
* is that finegray never sees the record and never silently counts its failure:
* e(N) and e(sample) must both exclude it, and the failure counts must be those
* of the reduced sample.
local ++test_count
capture noisily {
    clear
    set seed 11
    quietly set obs 40
    gen long id = _n
    gen byte x = mod(_n, 2)
    gen double t0 = 0
    gen double t = 2 + mod(_n, 9)
    gen byte status = cond(mod(_n, 4) == 0, 2, 1)
    quietly replace t0 = t in 5
    gen byte anyev = status > 0

    _fgadvlt_cap `"stset t, failure(anyev) id(id) time0(t0)"' ///
        "entry on or after exit (t0>t)"
    assert r(rc) == 0
    assert r(saw) == 1
    assert _st[5] == 0
    quietly count if _st != 1
    assert !missing(r(N))
    assert r(N) == 1

    quietly finegray x, compete(status) cause(1) norobust nolog
    assert e(N) == 39
    quietly count if e(sample)
    assert !missing(r(N))
    assert r(N) == 39
    quietly count if e(sample) & _n == 5
    assert !missing(r(N))
    assert r(N) == 0
    * the excluded record's own failure is not in the counts
    quietly count if _st == 1 & status == 1
    assert !missing(r(N))
    assert e(N_fail) == r(N)
}
local _rc = _rc
_fgadvlt_result `_rc' "D2 a zero-length episode is dropped by stset and never reaches finegray"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# D3 everyone delayed: nobody at risk before t = 5
* -----------------------------------------------------------------------------
* The CIF before the first cause-event time is the case where an empty risk set
* could be reported as a small positive number with a standard error. It must
* be exactly 0, the row must carry no confidence limits, and the reader must be
* told which requested times were out of support -- a silently repeated 0 with
* limits attached would be a claim about a region the data say nothing about.
local ++test_count
capture noisily {
    clear
    set seed 777
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen double t0 = 5
    gen double u = runiform()
    gen double t = 6 + floor(6 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = status > 0
    drop u
    quietly stset t, failure(anyev) id(id) time0(t0)
    quietly count if _t0 > 0
    assert !missing(r(N))
    assert r(N) == 300

    quietly finegray x, compete(status) cause(1) nolog
    assert e(N) == 300
    assert e(N_delayed) == 300
    assert "`e(lt_weight)'" == "zzf1_geskus"
    quietly summarize t if status == 1
    assert !missing(r(min))
    local _first = r(min)
    assert `_first' >= 6

    * Run it twice: _fgadvlt_cap is rclass, so its own r() replaces the
    * command's and r(table) cannot be read back through it.
    quietly finegray_cif, attime(3 7 11) ci nograph
    matrix _d3 = r(table)
    _fgadvlt_cap `"finegray_cif, attime(3 7 11) ci nograph"' ///
        "requested time(s) precede the first cause-event time (`_first')"
    assert r(rc) == 0
    assert r(saw) == 1
    assert rowsof(_d3) == 3
    * exactly zero, not merely small, and with no interval attached
    assert !missing(_d3[1, 1], _d3[1, 2])
    assert _d3[1, 1] == 3
    assert _d3[1, 2] == 0
    assert missing(_d3[1, 4])
    assert missing(_d3[1, 5])
    * and the in-support rows are ordinary
    forvalues r = 2/3 {
        forvalues c = 2/5 {
            assert !missing(_d3[`r', `c'])
        }
        assert _d3[`r', 2] > 0 & _d3[`r', 2] < 1
    }
    assert _d3[3, 2] > _d3[2, 2]
}
local _rc = _rc
_fgadvlt_result `_rc' "D3 a CIF before any subject is at risk is exactly 0 and says so"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# D4 degenerate truncation strata
* -----------------------------------------------------------------------------
* Three cases that a single "does truncstrata() run" test cannot separate:
*   (a) a stratum with one subject -- an entry distribution cannot be estimated
*       from it, and the fit must refuse rather than divide by a weight built on
*       a single observation;
*   (b) a stratum whose entries are all identical -- perfectly estimable, must
*       run, and its weight diagnostics must be finite and honest;
*   (c) every stratum with the SAME entry distribution -- then the stratified H
*       equals the pooled H and the fit must reproduce the unstratified one
*       EXACTLY. Built as two identical halves, so the equality is arithmetic
*       rather than statistical.
local ++test_count
capture noisily {
    * (a) a one-subject truncation stratum
    _fgadvlt_data
    quietly replace g = 3 in 1
    _fgadvlt_cap ///
        `"finegray x, compete(status) cause(1) truncstrata(g) nolog"' ///
        "a weight stratum has only 1 subjects (minimum 20)"
    assert r(rc) == 459
    assert r(saw) == 1

    * (b) a stratum whose entries are all identical
    _fgadvlt_data
    quietly replace t0 = 0 if g == 1
    quietly replace t = t0 + 1 + mod(_n, 8)
    quietly stset t, failure(anyev) id(id) time0(t0)
    quietly summarize t0 if g == 1
    assert !missing(r(sd))
    assert r(sd) == 0
    quietly summarize t0 if g == 2
    assert !missing(r(sd))
    assert r(sd) > 0
    quietly finegray x, compete(status) cause(1) truncstrata(g) nolog
    assert "`e(truncstrata)'" == "g"
    assert "`e(lt_weight)'" == "zzf1_factorized"
    assert e(N_weight_strata) == 2
    assert !missing(e(N_G_trunc), e(N))
    assert e(N_G_trunc) >= 0 & e(N_G_trunc) <= e(N)
    assert !missing(e(min_weight_prob), e(max_lt_weight))
    assert e(min_weight_prob) > 0 & e(min_weight_prob) <= 1
    assert e(max_lt_weight) < .
    assert e(N_prob_warn) == 0
    assert e(N_weight_warn) == 0
    assert !missing(_b[x], e(V)[1, 1])
    assert e(V)[1, 1] > 0

    * (c) identical entry distributions across strata reproduce the pooled fit
    clear
    set seed 2024
    quietly set obs 300
    gen long base = _n
    gen double x = rnormal()
    gen double t0 = cond(mod(_n, 3) == 0, 2, 0)
    gen double u = runiform()
    gen double t = t0 + 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    drop u
    quietly expand 2
    quietly bysort base: gen byte g = _n
    gen long id = _n
    gen byte anyev = status > 0
    quietly stset t, failure(anyev) id(id) time0(t0)
    quietly finegray x, compete(status) cause(1) nolog
    assert "`e(lt_weight)'" == "zzf1_geskus"
    local _bpool = _b[x]
    local _vpool = e(V)[1, 1]
    quietly finegray x, compete(status) cause(1) truncstrata(g) nolog
    assert "`e(lt_weight)'" == "zzf1_factorized"
    assert e(N_weight_strata) == 2
    assert !missing(`_bpool', _b[x], `_vpool', e(V)[1, 1])
    assert reldif(`_bpool', _b[x]) < 1e-10
    assert reldif(`_vpool', e(V)[1, 1]) < 1e-10
}
local _rc = _rc
_fgadvlt_result `_rc' "D4 truncstrata(): a one-subject stratum refuses; identical strata reproduce the pool"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# D5 nuisance at the edge of what a sandwich can support
* -----------------------------------------------------------------------------
* The nuisance-adjusted meat is still a sum over clusters, so with two clusters
* it has rank at most one. One covariate is estimable there and must produce a
* finite standard error; three are not, and the fit must refuse with a message
* about the cluster count rather than print three standard errors from a rank-1
* matrix. The second half is a censoring stratum with no censoring event at
* all: G is identically 1 there, which is a legitimate weight, not a
* degenerate one, and the fit must run with no weight warnings.
local ++test_count
capture noisily {
    clear
    set seed 1717
    quietly set obs 300
    gen long id = _n
    gen long cl = 1 + mod(_n, 2)
    gen double x = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = status > 0
    drop u
    quietly stset t, failure(anyev) id(id)

    quietly finegray x, compete(status) cause(1) nuisance cluster(cl) nolog
    assert e(N_clust) == 2
    assert "`e(vce)'" == "cluster"
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    assert e(rank) == 1
    assert !missing(_b[x], e(V)[1, 1])
    assert e(V)[1, 1] > 0
    assert !missing(sqrt(e(V)[1, 1]))

    _fgadvlt_cap ///
        `"finegray x x2 x3, compete(status) cause(1) nuisance cluster(cl) nolog"' ///
        "identifies 2 clusters for 3 coefficients"
    assert r(rc) == 459
    assert r(saw) == 1

    * a censoring stratum carrying no censoring event
    clear
    set seed 1818
    quietly set obs 400
    gen long id = _n
    gen byte g = 1 + mod(_n, 2)
    gen double x = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    quietly replace status = cond(runiform() < .6, 1, 2) if g == 2
    gen byte anyev = status > 0
    drop u
    quietly count if g == 2 & status == 0
    assert !missing(r(N))
    assert r(N) == 0
    quietly count if g == 1 & status == 0
    assert !missing(r(N))
    assert r(N) > 0
    quietly stset t, failure(anyev) id(id)

    quietly finegray x, compete(status) cause(1) strata(g) nuisance nolog
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    assert !missing(_b[x], e(V)[1, 1])
    assert e(V)[1, 1] > 0
    assert !missing(e(min_weight_prob), e(max_lt_weight))
    assert e(min_weight_prob) > 0
    assert e(N_prob_warn) == 0
    assert e(N_weight_warn) == 0
}
local _rc = _rc
_fgadvlt_result `_rc' "D5 nuisance with two clusters is finite or refused, never rank-deficient at rc 0"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# D6 a bootstrap whose replications really do fail
* -----------------------------------------------------------------------------
* A baseline stratum holding three subjects, one of them the stratum's only
* cause event, disappears from a fair share of resamples. The failures must
* reconcile with the request in r(), be stated on screen with the same numbers,
* and -- below the 25-replication floor -- the interval must be refused rather
* than built from whatever survived. Reporting 50 successes while 23 replicates
* never ran is the failure mode this test exists for.
local ++test_count
capture noisily {
    clear
    set seed 1919
    quietly set obs 200
    gen long id = _n
    gen double x = rnormal()
    gen byte g = 1 + mod(_n, 2)
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    quietly replace g = 3 in 1/3
    quietly replace status = 1 in 1
    quietly replace status = 0 in 2/3
    gen byte anyev = status > 0
    drop u
    quietly stset t, failure(anyev) id(id)
    quietly count if g == 3
    assert !missing(r(N))
    assert r(N) == 3
    quietly count if g == 3 & status == 1
    assert !missing(r(N))
    assert r(N) == 1

    quietly finegray x, compete(status) cause(1) bstrata(g) nolog
    assert e(k_bstrata) == 3

    quietly finegray_cif, bstratum(3) attime(4) ci bootstrap(50) ///
        seed(20260826) nograph
    assert !missing(r(bootstrap_requested), r(bootstrap_success), r(bootstrap_failed))
    local _req = r(bootstrap_requested)
    local _ok  = r(bootstrap_success)
    local _bad = r(bootstrap_failed)
    assert `_req' == 50
    assert `_ok' + `_bad' == `_req'
    * the fixture must actually exercise failure, or the test proves nothing
    assert `_bad' > 0
    assert `_ok' >= 25
    matrix _d6 = r(table)
    assert !missing(_d6[1, 2], _d6[1, 3], _d6[1, 4], _d6[1, 5])
    assert _d6[1, 4] < _d6[1, 2] & _d6[1, 2] < _d6[1, 5]

    * reproducible from the seed: same counts and the same interval
    quietly finegray_cif, bstratum(3) attime(4) ci bootstrap(50) ///
        seed(20260826) nograph
    assert r(bootstrap_success) == `_ok'
    assert r(bootstrap_failed) == `_bad'
    matrix _d6b = r(table)
    assert mreldif(_d6, _d6b) == 0

    * the same numbers are on screen, not only in r(). _fgadvlt_cap is rclass,
    * so this call is made for the message alone -- its r() is the helper's.
    _fgadvlt_cap ///
        `"finegray_cif, bstratum(3) attime(4) ci bootstrap(50) seed(20260826) nograph"' ///
        "`_bad' of 50 bootstrap replications failed and were skipped"
    assert r(rc) == 0
    assert r(saw) == 1

    * below the usable floor the interval is refused, not reported
    _fgadvlt_cap ///
        `"finegray_cif, bstratum(3) attime(4) ci bootstrap(25) seed(20260826) nograph"' ///
        "bootstrap failed: only"
    assert !missing(r(rc))
    assert r(rc) != 0
    assert r(saw) == 1
}
local _rc = _rc
_fgadvlt_result `_rc' "D6 a partly failed bootstrap reconciles, discloses, and refuses below the floor"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# D7 the missing-compete() refusal is scoped to the estimation sample: if
* -----------------------------------------------------------------------------
* The 1.2.0 fix refuses r(198) rather than silently dropping a record whose
* event type is unknown. A refusal that fired on a record the user had already
* excluded would make the fix unusable on exactly the data it was written for --
* stsplit output, where the fix is to exclude the blanked episodes with `if'.
local ++test_count
capture noisily {
    clear
    set seed 4242
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = status > 0
    gen byte keep1 = 1
    drop u
    quietly replace status = . in 1/3
    quietly replace keep1 = 0 in 1/3
    quietly stset t, failure(anyev) id(id)

    _fgadvlt_cap `"finegray x, compete(status) cause(1) nolog"' ///
        "compete() is missing on 3 record(s) of the estimation sample"
    assert r(rc) == 198
    assert r(saw) == 1

    quietly finegray x if keep1, compete(status) cause(1) nolog
    assert e(N) == 297
    quietly count if e(sample) & missing(status)
    assert !missing(r(N))
    assert r(N) == 0
    assert !missing(_b[x], e(V)[1, 1])
}
local _rc = _rc
_fgadvlt_result `_rc' "D7 an if-excluded record with a missing compete() does not block the fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# D8 the same scoping when stset is what excluded the record
* -----------------------------------------------------------------------------
* The refusal is placed after the _st filter, so a record stset itself threw out
* -- here a zero-length episode with t0 == t -- must not raise it either. This
* is the case an `if'-based test cannot reach: the user wrote no `if' at all.
local ++test_count
capture noisily {
    clear
    set seed 4242
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen double t0 = 0
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = status > 0
    drop u
    quietly replace t0 = t in 1/3
    quietly replace status = . in 1/3
    quietly stset t, failure(anyev) id(id) time0(t0)
    quietly count if _st != 1
    assert !missing(r(N))
    assert r(N) == 3
    quietly count if _st != 1 & missing(status)
    assert !missing(r(N))
    assert r(N) == 3

    quietly finegray x, compete(status) cause(1) nolog
    assert e(N) == 297
    quietly count if e(sample) & missing(status)
    assert !missing(r(N))
    assert r(N) == 0
    assert !missing(_b[x], e(V)[1, 1])

    * and putting one of those records back INTO the sample restores the refusal
    quietly replace t0 = 0 in 1
    quietly stset t, failure(anyev) id(id) time0(t0)
    quietly count if _st != 1
    assert !missing(r(N))
    assert r(N) == 2
    _fgadvlt_cap `"finegray x, compete(status) cause(1) nolog"' ///
        "compete() is missing on 1 record(s) of the estimation sample"
    assert r(rc) == 198
    assert r(saw) == 1
}
local _rc = _rc
_fgadvlt_result `_rc' "D8 a record stset excluded does not raise the compete() refusal, and one back in does"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# Summary
* -----------------------------------------------------------------------------
display "RESULT: test_finegray_adversarial_v120 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _fgadv120
if `fail_count' > 0 exit 1
exit 0
