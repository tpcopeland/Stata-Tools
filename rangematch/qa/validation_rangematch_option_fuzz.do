*! validation_rangematch_option_fuzz.do
*! v1.5.3: randomized differential validation against a brute-force joinby
*! oracle, across the OPTION CROSS-PRODUCT.
*!
*! WHY THIS EXISTS. The suite already had oracles, and they were honest, but
*! they probed one corner each. validation_rangematch_oracle.do randomizes data
*! only at closed(both) with no tolerance(), no nearest(), point mode, and one
*! fixed by() shape; validation_rangematch_nearest.do and
*! validation_rangematch_overlap_oracle.do enumerate hand-built fixtures. Every
*! one of those asks "does this configuration still give the answer I wrote
*! down". None asks "does an arbitrary configuration agree with an independent
*! computation" -- so a defect that needs, say, closed(right) AND a nonzero
*! tolerance AND a by() group whose using rows are all missing-key sits outside
*! the whole suite no matter how many cases are added one at a time.
*!
*! This file crosses the axes instead of listing them. Each replication draws a
*! configuration and a dataset, runs rangematch, and rebuilds the same join from
*! joinby plus explicit keep conditions -- an oracle that shares no code with
*! the package. Comparison is on the PAIR SET, recovered through masterid() and
*! usingid(), not on counts alone: two joins can agree on r(N_pairs) and still
*! pair the wrong rows.
*!
*! Randomized data, fixed seed. The seed makes a failure reproducible; the
*! randomization is what makes the coverage worth having. If a replication ever
*! fails, the reported configuration and rep number reproduce it exactly.
*!
*! Block 1  point mode:   closed() x tolerance() x by() x backend x open-ended
*!                        and inverted master bounds x missing using keys
*! Block 2  nearest mode: nearest() x ties() x closed() x tolerance() x by(),
*!                        on deliberately coarse keys so ties are common
*! Block 3  overlap mode: closed() x tolerance() x by() x inverted, degenerate
*!                        and open-ended intervals on BOTH sides, plus the
*!                        stats diagnostics (the four match counts, the mean,
*!                        and the p50/p90/p99 family against _pctile)
*!
*! nosort in block 1 is not cosmetic: it is what makes the sweep backend
*! ineligible on unsorted master data, so the block exercises the binary-search
*! and sweep backends against the same oracle rather than whichever one the
*! data happened to select.

version 16.1
clear all
set more off

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap

local FAIL 0
local TESTS 0

* Replication counts. Sized to keep the lane brisk while still crossing the
* axes; raise them when investigating a suspected join defect.
local NREP_POINT   60
local NREP_NEAREST 50
local NREP_OVERLAP 50

tempfile mf uf u2 act expf cnts

* ===========================================================================
* Block 1: point mode against a brute-force oracle
* ===========================================================================
set seed 20260813
local ++TESTS
local nbad = 0
local firstbad ""

forvalues rep = 1/`NREP_POINT' {
    local nm = 3 + floor(runiform()*20)
    local nu = 3 + floor(runiform()*25)
    local ngrp = 1 + floor(runiform()*4)
    local ci = 1 + floor(runiform()*4)
    local closed : word `ci' of both left right none
    local tol = 0
    if runiform() < 0.35 local tol = floor(runiform()*4)
    local useby = (runiform() < 0.70)
    local nosort ""
    if runiform() < 0.50 local nosort "nosort"
    local pmiss = runiform()*0.30
    local pinv  = runiform()*0.25
    local popen = runiform()*0.25

    clear
    quietly set obs `nm'
    gen long mrow = _n
    gen byte grp = 1 + floor(runiform()*`ngrp')
    gen double lo = floor(runiform()*40) - 5
    gen double hi = lo + floor(runiform()*10)
    quietly replace hi = lo - 1 - floor(runiform()*3) if runiform() < `pinv'
    quietly replace lo = . if runiform() < `popen'
    quietly replace hi = . if runiform() < `popen'
    quietly save "`mf'", replace

    clear
    quietly set obs `nu'
    gen long urow = _n
    gen byte grp = 1 + floor(runiform()*`ngrp')
    gen double ukey = floor(runiform()*50) - 8
    quietly replace ukey = . if runiform() < `pmiss'
    quietly save "`uf'", replace

    local byopt ""
    if `useby' local byopt "by(grp)"
    local cfg "closed(`closed') tol(`tol') by=`useby' `nosort' ngrp=`ngrp' nm=`nm' nu=`nu'"

    use "`mf'", clear
    capture rangematch ukey lo hi using "`uf'", `byopt' ///
        keepusing(urow ukey) unmatched(none) closed(`closed') ///
        tolerance(`tol') masterid(m_id) usingid(u_id) `nosort' ///
        saving("`act'", replace)
    if _rc {
        local ++nbad
        if `"`firstbad'"' == "" local firstbad "rep `rep' rc=`=_rc' [`cfg']"
        continue
    }
    local got_pairs = r(N_pairs)

    use "`mf'", clear
    if `useby' {
        quietly joinby grp using "`uf'", unmatched(none)
    }
    else {
        rename grp mgrp
        gen byte _j = 1
        preserve
        use "`uf'", clear
        rename grp ugrp
        gen byte _j = 1
        quietly save "`u2'", replace
        restore
        quietly joinby _j using "`u2'", unmatched(none)
    }
    quietly keep if !missing(ukey)
    gen double _lo = cond(missing(lo), mindouble(), lo)
    gen double _hi = cond(missing(hi), maxdouble(), hi)
    * An inverted master interval is empty and matches nothing, and tolerance()
    * does not rescue it -- the shift fuzzes comparisons between two genuine
    * intervals, it does not promote an empty one.
    quietly keep if _lo <= _hi
    gen double _los = max(_lo - `tol', mindouble())
    gen double _his = min(_hi + `tol', maxdouble())
    if "`closed'" == "both"  quietly keep if ukey >= _los & ukey <= _his
    if "`closed'" == "left"  quietly keep if ukey >= _los & ukey <  _his
    if "`closed'" == "right" quietly keep if ukey >  _los & ukey <= _his
    if "`closed'" == "none"  quietly keep if ukey >  _los & ukey <  _his
    keep mrow urow
    sort mrow urow
    quietly count
    local exp_n = r(N)
    quietly save "`expf'", replace

    use "`act'", clear
    keep m_id u_id
    rename m_id mrow
    rename u_id urow
    sort mrow urow
    quietly count
    local act_n = r(N)

    local bad = 0
    if `act_n' != `exp_n' | `got_pairs' != `exp_n' local bad = 1
    if !`bad' & `act_n' > 0 {
        capture cf _all using "`expf'"
        if _rc local bad = 1
    }
    if `bad' {
        local ++nbad
        if `"`firstbad'"' == "" {
            local firstbad "rep `rep' act=`act_n' exp=`exp_n' pairs=`got_pairs' [`cfg']"
        }
    }
}
if `nbad' > 0 {
    di as error "B1 point-mode fuzz: `nbad'/`NREP_POINT' replications disagreed with the oracle"
    di as error "   first: `firstbad'"
    local ++FAIL
}
else {
    di as result "PASS: B1 point mode matches the oracle over `NREP_POINT' randomized configurations"
}

* ===========================================================================
* Block 2: nearest()/ties() against a brute-force oracle
* ===========================================================================
set seed 771003
local ++TESTS
local nbad = 0
local firstbad ""

forvalues rep = 1/`NREP_NEAREST' {
    local nm = 3 + floor(runiform()*12)
    local nu = 3 + floor(runiform()*20)
    local ngrp = 1 + floor(runiform()*3)
    local ci = 1 + floor(runiform()*4)
    local closed : word `ci' of both left right none
    local ni = 1 + floor(runiform()*3)
    local nmode : word `ni' of before after both
    local ti = 1 + floor(runiform()*3)
    local tmode : word `ti' of all first last
    local tol = 0
    if runiform() < 0.30 local tol = floor(runiform()*3)
    local useby = (runiform() < 0.60)
    local popen = runiform()*0.20
    local pmiss = runiform()*0.25

    clear
    quietly set obs `nm'
    gen long mrow = _n
    gen byte grp = 1 + floor(runiform()*`ngrp')
    * Coarse keys on purpose: ties are the point of ties().
    gen double mkey = floor(runiform()*12)
    gen double lo = mkey - floor(runiform()*8)
    gen double hi = mkey + floor(runiform()*8)
    quietly replace lo = . if runiform() < `popen'
    quietly replace hi = . if runiform() < `popen'
    quietly save "`mf'", replace

    clear
    quietly set obs `nu'
    gen long urow = _n
    gen byte grp = 1 + floor(runiform()*`ngrp')
    gen double mkey = floor(runiform()*12)
    quietly replace mkey = . if runiform() < `pmiss'
    quietly save "`uf'", replace

    local byopt ""
    if `useby' local byopt "by(grp)"
    local cfg "closed(`closed') nearest(`nmode') ties(`tmode') tol(`tol') by=`useby' ngrp=`ngrp'"

    use "`mf'", clear
    capture rangematch mkey lo hi using "`uf'", `byopt' ///
        keepusing(urow) unmatched(none) closed(`closed') tolerance(`tol') ///
        nearest(`nmode') ties(`tmode') masterid(m_id) usingid(u_id) ///
        saving("`act'", replace)
    if _rc {
        local ++nbad
        if `"`firstbad'"' == "" local firstbad "rep `rep' rc=`=_rc' [`cfg']"
        continue
    }
    local got_pairs = r(N_pairs)

    use "`mf'", clear
    rename mkey m_key
    if `useby' {
        quietly joinby grp using "`uf'", unmatched(none)
    }
    else {
        rename grp mgrp
        gen byte _j = 1
        preserve
        use "`uf'", clear
        rename grp ugrp
        gen byte _j = 1
        quietly save "`u2'", replace
        restore
        quietly joinby _j using "`u2'", unmatched(none)
    }
    quietly keep if !missing(mkey) & !missing(m_key)
    gen double _lo = cond(missing(lo), mindouble(), lo)
    gen double _hi = cond(missing(hi), maxdouble(), hi)
    quietly keep if _lo <= _hi
    gen double _los = max(_lo - `tol', mindouble())
    gen double _his = min(_hi + `tol', maxdouble())
    if "`closed'" == "both"  quietly keep if mkey >= _los & mkey <= _his
    if "`closed'" == "left"  quietly keep if mkey >= _los & mkey <  _his
    if "`closed'" == "right" quietly keep if mkey >  _los & mkey <= _his
    if "`closed'" == "none"  quietly keep if mkey >  _los & mkey <  _his

    * nearest() selects within the in-range candidate set only: a row outside
    * [lo,hi] is never a nearest match.
    gen double d = mkey - m_key
    if _N > 0 {
        quietly {
            if "`nmode'" == "before" {
                keep if d <= 0
                bysort mrow: egen double _best = max(d)
                keep if d == _best
            }
            else if "`nmode'" == "after" {
                keep if d >= 0
                bysort mrow: egen double _best = min(d)
                keep if d == _best
            }
            else {
                gen double ad = abs(d)
                bysort mrow: egen double _best = min(ad)
                keep if ad == _best
            }
        }
    }
    if _N > 0 {
        quietly {
            if "`tmode'" == "first" {
                bysort mrow: egen long _pick = min(urow)
                keep if urow == _pick
            }
            else if "`tmode'" == "last" {
                bysort mrow: egen long _pick = max(urow)
                keep if urow == _pick
            }
        }
    }
    keep mrow urow
    sort mrow urow
    quietly count
    local exp_n = r(N)
    quietly save "`expf'", replace

    use "`act'", clear
    keep m_id u_id
    rename m_id mrow
    rename u_id urow
    sort mrow urow
    quietly count
    local act_n = r(N)

    local bad = 0
    if `act_n' != `exp_n' | `got_pairs' != `exp_n' local bad = 1
    if !`bad' & `act_n' > 0 {
        capture cf _all using "`expf'"
        if _rc local bad = 1
    }
    if `bad' {
        local ++nbad
        if `"`firstbad'"' == "" {
            local firstbad "rep `rep' act=`act_n' exp=`exp_n' pairs=`got_pairs' [`cfg']"
        }
    }
}
if `nbad' > 0 {
    di as error "B2 nearest fuzz: `nbad'/`NREP_NEAREST' replications disagreed with the oracle"
    di as error "   first: `firstbad'"
    local ++FAIL
}
else {
    di as result "PASS: B2 nearest()/ties() match the oracle over `NREP_NEAREST' randomized configurations"
}

* ===========================================================================
* Block 3: overlap mode plus the stats diagnostics
* ===========================================================================
set seed 559111
local ++TESTS
local nbad = 0
local firstbad ""

forvalues rep = 1/`NREP_OVERLAP' {
    local nm = 3 + floor(runiform()*18)
    local nu = 3 + floor(runiform()*22)
    local ngrp = 1 + floor(runiform()*4)
    local closed "both"
    if runiform() < 0.5 local closed "none"
    local tol = 0
    if runiform() < 0.35 local tol = floor(runiform()*4)
    local useby = (runiform() < 0.65)
    local popen = runiform()*0.20
    local pinv  = runiform()*0.20
    local pdeg  = runiform()*0.20

    clear
    quietly set obs `nm'
    gen long mrow = _n
    gen byte grp = 1 + floor(runiform()*`ngrp')
    gen double lo = floor(runiform()*30) - 5
    gen double hi = lo + floor(runiform()*8)
    quietly replace hi = lo if runiform() < `pdeg'
    quietly replace hi = lo - 1 - floor(runiform()*2) if runiform() < `pinv'
    quietly replace lo = . if runiform() < `popen'
    quietly replace hi = . if runiform() < `popen'
    quietly save "`mf'", replace

    clear
    quietly set obs `nu'
    gen long urow = _n
    gen byte grp = 1 + floor(runiform()*`ngrp')
    gen double ulo = floor(runiform()*30) - 5
    gen double uhi = ulo + floor(runiform()*8)
    quietly replace uhi = ulo if runiform() < `pdeg'
    quietly replace uhi = ulo - 1 - floor(runiform()*2) if runiform() < `pinv'
    quietly replace ulo = . if runiform() < `popen'
    quietly replace uhi = . if runiform() < `popen'
    quietly save "`uf'", replace

    local byopt ""
    if `useby' local byopt "by(grp)"
    local cfg "closed(`closed') tol(`tol') by=`useby' ngrp=`ngrp' nm=`nm' nu=`nu'"

    use "`mf'", clear
    capture rangematch lo hi using "`uf'", overlap(ulo uhi) `byopt' ///
        keepusing(urow) unmatched(none) closed(`closed') tolerance(`tol') ///
        masterid(m_id) usingid(u_id) stats saving("`act'", replace)
    if _rc {
        local ++nbad
        if `"`firstbad'"' == "" local firstbad "rep `rep' rc=`=_rc' [`cfg']"
        continue
    }
    local got_pairs = r(N_pairs)
    local got_mm    = r(N_matched_master)
    local got_um    = r(N_unmatched_master)
    local got_mu    = r(N_matched_using)
    local got_uu    = r(N_unmatched_using)
    local got_max   = r(max_matches)
    local got_mean  = r(mean_matches)
    local got_p50   = r(p50_matches)
    local got_p90   = r(p90_matches)
    local got_p99   = r(p99_matches)

    use "`mf'", clear
    if `useby' {
        quietly joinby grp using "`uf'", unmatched(none)
    }
    else {
        rename grp mgrp
        gen byte _j = 1
        preserve
        use "`uf'", clear
        rename grp ugrp
        gen byte _j = 1
        quietly save "`u2'", replace
        restore
        quietly joinby _j using "`u2'", unmatched(none)
    }
    gen double _mlo = cond(missing(lo),  mindouble(), lo)
    gen double _mhi = cond(missing(hi),  maxdouble(), hi)
    gen double _ulo = cond(missing(ulo), mindouble(), ulo)
    gen double _uhi = cond(missing(uhi), maxdouble(), uhi)
    * Closure-aware nonemptiness on BOTH sides, judged on the raw bounds.
    if "`closed'" == "both" quietly keep if _mlo <= _mhi & _ulo <= _uhi
    else                    quietly keep if _mlo <  _mhi & _ulo <  _uhi
    gen double _mlos = max(_mlo - `tol', mindouble())
    gen double _mhis = min(_mhi + `tol', maxdouble())
    if "`closed'" == "both" quietly keep if _ulo <= _mhis & _uhi >= _mlos
    else                    quietly keep if _ulo <  _mhis & _uhi >  _mlos
    keep mrow urow
    sort mrow urow
    quietly count
    local exp_n = r(N)
    quietly save "`expf'", replace

    preserve
    if _N > 0 {
        quietly bysort mrow: keep if _n == 1
    }
    quietly count
    local exp_mm = r(N)
    restore
    preserve
    if _N > 0 {
        quietly bysort urow: keep if _n == 1
    }
    quietly count
    local exp_mu = r(N)
    restore

    * Per-master match counts over ALL master rows, zeros included -- that is
    * the population the reported percentile family is defined on.
    use "`expf'", clear
    if _N > 0 {
        quietly bysort mrow: gen long _c = _N
        quietly bysort mrow: keep if _n == 1
    }
    else {
        gen long _c = .
    }
    keep mrow _c
    quietly save "`cnts'", replace
    use "`mf'", clear
    keep mrow
    quietly merge 1:1 mrow using "`cnts'", nogenerate
    quietly replace _c = 0 if missing(_c)
    quietly summarize _c, meanonly
    local exp_max = r(max)
    local exp_mean = r(mean)
    quietly _pctile _c, p(50 90 99)
    local exp_p50 = r(r1)
    local exp_p90 = r(r2)
    local exp_p99 = r(r3)

    use "`act'", clear
    keep m_id u_id
    rename m_id mrow
    rename u_id urow
    sort mrow urow
    quietly count
    local act_n = r(N)

    local bad = 0
    local why ""
    if `act_n' != `exp_n' | `got_pairs' != `exp_n' {
        local bad 1
        local why "`why' pairs(`act_n'/`got_pairs' vs `exp_n')"
    }
    if !`bad' & `act_n' > 0 {
        capture cf _all using "`expf'"
        if _rc {
            local bad 1
            local why "`why' pairset"
        }
    }
    if `got_mm' != `exp_mm' {
        local bad 1
        local why "`why' matched_master(`got_mm' vs `exp_mm')"
    }
    if `got_um' != (`nm' - `exp_mm') {
        local bad 1
        local why "`why' unmatched_master(`got_um')"
    }
    if `got_mu' != `exp_mu' {
        local bad 1
        local why "`why' matched_using(`got_mu' vs `exp_mu')"
    }
    if `got_uu' != (`nu' - `exp_mu') {
        local bad 1
        local why "`why' unmatched_using(`got_uu')"
    }
    if reldif(`got_max', `exp_max') > 1e-10 {
        local bad 1
        local why "`why' max(`got_max' vs `exp_max')"
    }
    if reldif(`got_mean', `exp_mean') > 1e-8 {
        local bad 1
        local why "`why' mean(`got_mean' vs `exp_mean')"
    }
    if reldif(`got_p50', `exp_p50') > 1e-8 {
        local bad 1
        local why "`why' p50(`got_p50' vs `exp_p50')"
    }
    if reldif(`got_p90', `exp_p90') > 1e-8 {
        local bad 1
        local why "`why' p90(`got_p90' vs `exp_p90')"
    }
    if reldif(`got_p99', `exp_p99') > 1e-8 {
        local bad 1
        local why "`why' p99(`got_p99' vs `exp_p99')"
    }
    if `bad' {
        local ++nbad
        if `"`firstbad'"' == "" local firstbad "rep `rep' [`why'] [`cfg']"
    }
}
if `nbad' > 0 {
    di as error "B3 overlap/stats fuzz: `nbad'/`NREP_OVERLAP' replications disagreed with the oracle"
    di as error "   first: `firstbad'"
    local ++FAIL
}
else {
    di as result "PASS: B3 overlap() and stats match the oracle over `NREP_OVERLAP' randomized configurations"
}

display "RESULT: validation_rangematch_option_fuzz tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 {
    di as error "validation_rangematch_option_fuzz: FAILED (`FAIL')"
    exit 9
}
di as result "validation_rangematch_option_fuzz: PASSED"
