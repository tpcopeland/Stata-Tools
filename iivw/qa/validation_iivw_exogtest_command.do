*! validation_iivw_exogtest_command.do — the separation check through iivw_exogtest
*! Author: Timothy P Copeland, Karolinska Institutet
*
* What reaches the user. iivw_exogtest hands the monotone-likelihood check
* (_iivw_cox_recession) only the terms stcox kept, divided by their SD; a
* group the check calls monotone (1) or unsettled (2) has z, p, HR, CI and
* the joint test withheld, and a group it calls finite (0) is reported.
*
* Oracles, none computed by the package:
*   - stcox's own omission flags (o. in e(b)) on a hand-built Andersen-Gill
*     risk set, which name the model the command fits;
*   - exact certificates for that retained design: data/exogtest_corpus_exp.csv
*     columns s1, s12, ... (rational arithmetic, cert.py of the 2026-10-29
*     review, re-run on this file), or a certificate written into the cell
*     from exact comparisons of stored doubles;
*   - stcox refits and a Wald statistic formed here for reported numbers.
*
* A corpus case (rows t0, t, d, x) becomes a panel with one subject per row:
* a first visit at t0 holding x, a second visit at t when d == 1, and
* censor() = t. The command's intervals are then exactly the case's rows.
* An 80-subject group from the exogeneity DGP is appended as by() group 2 so
* the command returns r() whatever group 1 does.
*
* Every check call is made under set sortrngstate 1: the check's internal
* order() breaks ties with the sort jumbler, so its verdict on a few inputs
* depends on session history (validation_iivw_exogtest_corpus.do D01).
*
* Cells
*   C01  P31: a near-copy (1e-6 on tail rows) that stcox omits does not enter
*        the check; the reported fit is the one-lag fit
*   C02  P31: the "Diverging:" note names only kept terms
*   C03  collin corpora: the retained design decides (filter is decisive)
*   C04  heavy and b_gap corpora: no wrong verdict reaches the user, apart
*        from the known-wrong cases of K01-K03
*   C05  a joint p in the subnormal range is reported, not r(198)
*   K01  heavy 205 594: false "monotone" reaches the user (KNOWN WRONG)
*   K02  b_gap 14 55 282 554: false "monotone" through stcox-kept near
*        copies at gaps of 1e-4..1e-3 (KNOWN WRONG)
*   K03  collinP 305: false "monotone" on the retained (x1, x2) (KNOWN WRONG)
*   D02  the command's verdict does not depend on the jumbler state
version 16.0
clear all
set more off
set varabbrev off
local qa_dir "`c(pwd)'"
do _iivw_qa_common.do
iivw_qa_bootstrap
do _iivw_exogtest_dgp.do
quietly findfile _iivw_mlib.ado
run "`r(fn)'"
local srs0 = c(sortrngstate)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

* Command-level known-wrong cases on the 1.0.1 base (K01-K03).
local kw_g_heavy 205 594
local kw_b_gap 14 55 282 554
local kw_g_collin ""
local kw_g_collinP 305

* C01 certificates from exact comparisons on the hand-built rows in memory
* (a0 a1 ev l1 l2; at risk at t when a0 < t <= a1).
capture mata: mata drop _c01_strict()
capture mata: mata drop _c01_signs()
mata:
// Some row with l2 > l1 is at risk at some event time.
real scalar _c01_strict()
{
    real colvector a0, a1, ev, l1, l2, t, r
    real scalar k
    a0 = st_data(., "a0")
    a1 = st_data(., "a1")
    ev = st_data(., "ev")
    l1 = st_data(., "l1")
    l2 = st_data(., "l2")
    t = uniqrows(select(a1, ev :== 1))
    for (k = 1; k <= rows(t); k++) {
        r = (a0 :< t[k]) :& (a1 :>= t[k])
        if (any(r :& (l2 :> l1))) return(1)
    }
    return(0)
}
// One-column design l1: some pair difference l1_j - l1_i is > 0 and some
// is < 0 (event i, j at risk at its time), so no a != 0 has a*z >= 0 on all.
real scalar _c01_signs()
{
    real colvector a0, a1, ev, l1, ei, r
    real scalar k, i, pos, neg
    a0 = st_data(., "a0")
    a1 = st_data(., "a1")
    ev = st_data(., "ev")
    l1 = st_data(., "l1")
    ei = selectindex(ev :== 1)
    pos = 0
    neg = 0
    for (k = 1; k <= rows(ei); k++) {
        i = ei[k]
        r = (a0 :< a1[i]) :& (a1 :>= a1[i])
        if (any(r :& (l1 :> l1[i]))) pos = 1
        if (any(r :& (l1 :< l1[i]))) neg = 1
        if (pos & neg) return(1)
    }
    return(0)
}
end

**# Shared fixtures
tempfile ctl cases exp
* Control group: well estimated, ids above 100000, censor() = 7.
set seed 41
quietly iivw_exog_dgp, groups(1) n(80) gammas(0.3) gammatwo(0.1) maxfu(7)
rename y y1
quietly gen double y3 = rnormal()
quietly replace id = id + 100000
quietly replace grp = 2
quietly gen double cens = 7
keep id time y1 y2 y3 grp cens
quietly save `ctl'
import delimited using "`qa_dir'/data/exogtest_corpus_exp.csv", clear asdouble stringcols(1)
quietly save `exp'
import delimited using "`qa_dir'/data/exogtest_corpus_cases.csv", clear asdouble stringcols(1)
gen long rowid = _n
quietly save `cases'

* stcox's omission flags for the case in memory (t0 t d x1..xp), as a
* string of kept column numbers ("13" = x1 and x3 kept). Leaves c_local kept.
capture program drop _cmd_kept
program define _cmd_kept
    version 16.0
    args p
    preserve
    gen long _cid = _n
    quietly stset t, enter(time t0) failure(d) id(_cid) exit(time .)
    local xs ""
    forvalues k = 1/`p' {
        local xs "`xs' x`k'"
    }
    local kept ""
    capture quietly stcox `xs', efron noshow iterate(50)
    if _rc == 0 {
        local cn : colnames e(b)
        forvalues k = 1/`p' {
            if !strpos(" `cn' ", " o.x`k' ") local kept "`kept'`k'"
        }
    }
    restore
    c_local kept `kept'
end

* The check's status for group 1 of the panel in memory, read from the
* command: 1 monotone, 2 did not settle, 0 reported, 8 not fitted or not
* converged (no verdict). Leaves c_local cmdst; rc of the command must be 0.
capture program drop _cmd_status
program define _cmd_status
    version 16.0
    args ys
    tempfile lg
    quietly log using `lg', text replace name(_cmdlog)
    set sortrngstate 1
    capture noisily iivw_exogtest `ys', id(id) time(time) censor(cens) by(grp) nolog
    local rc = _rc
    local nm = r(n_models)
    local nmo = r(n_monotone)
    quietly log close _cmdlog
    if `rc' {
        display as error "iivw_exogtest rc `rc'"
        exit `rc'
    }
    local settle = 0
    local ncv = 0
    local ingrp = 0
    tempname fh
    file open `fh' using `lg', read text
    file read `fh' line
    while !r(eof) {
        if strpos(`"`macval(line)'"', "By group: grp = 1") local ingrp = 1
        if strpos(`"`macval(line)'"', "By group: grp = 2") local ingrp = 0
        if `ingrp' & strpos(`"`macval(line)'"', "check did not settle") local settle = 1
        if `ingrp' & strpos(`"`macval(line)'"', "did not converge") local ncv = 1
        file read `fh' line
    }
    file close `fh'
    local st = 0
    if `nm' != 2 | `ncv' local st = 8
    else if `nmo' == 1 local st = 1
    else if `settle' local st = 2
    c_local cmdst `st'
end

* Load corpus case (corpus, case) as rows, then as a panel with the control.
capture program drop _cmd_case
program define _cmd_case
    version 16.0
    args cases corpus case
    use `"`cases'"' if corpus == "`corpus'" & case == `case', clear
    sort rowid
end
capture program drop _cmd_topanel
program define _cmd_topanel
    version 16.0
    args p ctl
    gen long id = _n
    quietly expand 2 if d == 1, gen(_second)
    gen double time = cond(_second, t, t0)
    forvalues k = 1/`p' {
        gen double y`k' = cond(_second, 0, x`k')
    }
    gen double cens = t
    keep id time y* cens
    gen byte grp = 1
    quietly append using `"`ctl'"'
end

* Run every case of a corpus: kept set, retained truth, command status, and
* the check's status on the FULL raw design (what a filter-less command would
* judge). Leaves the results in memory.
capture program drop _cmd_corpus
program define _cmd_corpus
    version 16.0
    args cases exp ctl corpus
    use `"`exp'"' if corpus == "`corpus'", clear
    local nc = _N
    forvalues i = 1/`nc' {
        local c`i' = case[`i']
        local p`i' = p[`i']
    }
    tempname M
    matrix `M' = J(`nc', 6, .)
    forvalues i = 1/`nc' {
        local p = `p`i''
        _cmd_case `"`cases'"' `corpus' `c`i''
        _cmd_kept `p'
        local xs ""
        local ys ""
        forvalues k = 1/`p' {
            local xs "`xs' x`k'"
            local ys "`ys' y`k'"
        }
        gen byte _tu = 1
        set sortrngstate 1
        mata: st_local("fs", strofreal(_iivw_cox_recession("t0", "t", "d", "`xs'", "_tu")[1]))
        drop _tu
        _cmd_topanel `p' `"`ctl'"'
        _cmd_status "`ys'"
        matrix `M'[`i', 1] = `c`i''
        matrix `M'[`i', 2] = `p'
        matrix `M'[`i', 3] = real("`kept'")
        matrix `M'[`i', 4] = `cmdst'
        matrix `M'[`i', 5] = `fs'
    }
    use `"`exp'"' if corpus == "`corpus'", clear
    quietly gen double kept = .
    quietly gen double cmdst = .
    quietly gen double fullst = .
    forvalues i = 1/`nc' {
        assert case[`i'] == `M'[`i', 1]
        quietly replace kept = `M'[`i', 3] in `i'
        quietly replace cmdst = `M'[`i', 4] in `i'
        quietly replace fullst = `M'[`i', 5] in `i'
    }
    * Retained-design truth from the subset certificates.
    quietly gen double truth = .
    foreach s in 1 2 3 12 13 23 123 {
        quietly replace truth = s`s' if kept == `s'
    }
    quietly gen byte full = (kept == 1 & p == 1) | (kept == 12 & p == 2) | ///
        (kept == 123 & p == 3)
end

**# C01: P31 -- a near-copy stcox omits does not enter the check
* y2 = y + 1e-6 on each odd subject's last visit (s = 1). The lag of s is 1
* only on terminal censored intervals, so the design (y_lag, y2_lag) is
* separated EXACTLY by a = (-1, 1): every event row has y2_lag == y_lag, every
* row has y2_lag >= y_lag, and some at-risk row has y2_lag > y_lag (exact
* comparisons of stored doubles, checked below). stcox omits y2_lag as
* collinear, so the fitted model is y_lag alone, whose design has pair
* differences of both signs (no direction: finite maximum). Handing the
* omitted term to the check makes it judge the separated design and withhold
* a finite fit.
local ++test_count
capture noisily {
    tempname R
    set seed 31
    quietly iivw_exog_dgp, groups(1) n(120) gammas(0.4) maxfu(5)
    quietly bysort id (time): gen byte s = (_n == _N) & mod(id, 2)
    quietly gen double y2 = y + 1e-6 * s
    quietly gen double cens = 5
    keep id time y y2 cens
    tempfile p31
    quietly save `p31'
    * Hand-built Andersen-Gill rows.
    sort id time
    quietly by id: gen double a0 = time[_n - 1]
    gen double a1 = time
    gen byte ev = 1
    quietly by id: gen double l1 = y[_n - 1]
    quietly by id: gen double l2 = y2[_n - 1]
    quietly by id: gen byte last = _n == _N
    quietly expand 2 if last & time < 5, gen(tail)
    quietly replace a0 = time if tail
    quietly replace a1 = 5 if tail
    quietly replace ev = 0 if tail
    quietly replace l1 = y if tail
    quietly replace l2 = y2 if tail
    quietly keep if !missing(a0, l1, l2) & a1 > a0
    * Exact certificate of separation for the full design.
    assert l2 == l1 if ev == 1
    assert l2 >= l1
    quietly count if l2 > l1
    assert !missing(r(N)) & r(N) > 0
    * ... and the strict rows are at risk at some event time.
    mata: st_numscalar("_c01_strict", _c01_strict())
    assert scalar(_c01_strict) == 1
    * Retained design: pair differences of both signs (exact comparisons).
    mata: st_numscalar("_c01_signs", _c01_signs())
    assert scalar(_c01_signs) == 1
    * stcox omits l2; the one-lag refit is the oracle.
    quietly stset a1, enter(time a0) failure(ev) id(id) exit(time .)
    quietly stcox l1 l2, efron noshow
    local cn : colnames e(b)
    assert strpos(" `cn' ", " o.l2 ") > 0
    quietly stcox l1, efron vce(cluster id) noshow
    assert e(converged) == 1
    local b0 = _b[l1]
    local se0 = _se[l1]
    * The command.
    use `p31', clear
    gen byte grp = 1
    quietly append using `ctl'
    quietly replace y = y1 if grp == 2
    iivw_exogtest y y2, id(id) time(time) censor(cens) by(grp) nolog
    matrix `R' = r(results)
    assert r(n_monotone) == 0 & r(n_unknown) == 0 & r(n_models) == 2
    assert `R'[1, 1] == 1 & `R'[2, 1] == 1
    assert !missing(`R'[1, 3], `R'[1, 4], `R'[1, 5], `R'[1, 6])
    assert !missing(`b0', `se0', `b0' / `se0') & `se0' > 0
    assert reldif(`R'[1, 3], `b0') < 1e-9 & reldif(`R'[1, 4], `se0') < 1e-9
    assert reldif(`R'[1, 5], `b0' / `se0') < 1e-9
    assert missing(`R'[2, 5], `R'[2, 6])
}
if _rc == 0 {
    display as result "  PASS: C01 omitted near-copy kept out of the check; one-lag fit reported"
    local ++pass_count
}
else {
    display as error "  FAIL: C01 omitted near-copy (rc `=_rc')"
    local ++fail_count
    local failed "`failed' C01"
}

**# C02: P31 -- the "Diverging:" note names only terms stcox kept
* s_lag is 1 only on terminal censored intervals (separated, monotone); s2 =
* 2 * s is an exact copy that stcox omits. The note must name s's lag alone.
local ++test_count
capture noisily {
    set seed 31
    quietly iivw_exog_dgp, groups(1) n(120) gammas(0.4) maxfu(5)
    quietly bysort id (time): gen double s = (_n == _N) & mod(id, 2)
    quietly gen double s2 = 2 * s
    quietly gen double cens = 5
    keep id time s s2 cens
    gen byte grp = 1
    quietly append using `ctl'
    quietly replace s = y1 if grp == 2
    quietly replace s2 = y2 if grp == 2
    tempfile clog
    quietly log using `clog', text replace name(c02log)
    iivw_exogtest s s2, id(id) time(time) censor(cens) by(grp) nolog
    local nmo = r(n_monotone)
    quietly log close c02log
    assert `nmo' == 1
    local hit = 0
    local bad = 0
    tempname fh
    file open `fh' using `clog', read text
    file read `fh' line
    while !r(eof) {
        if strpos(`"`macval(line)'"', "Diverging: _iivw_exog_s_lag1.") local ++hit
        if strpos(`"`macval(line)'"', "Diverging:") & strpos(`"`macval(line)'"', "s2_lag1") local ++bad
        file read `fh' line
    }
    file close `fh'
    assert `hit' == 1 & `bad' == 0
}
if _rc == 0 {
    display as result "  PASS: C02 the diverging-terms note names only the kept lag"
    local ++pass_count
}
else {
    display as error "  FAIL: C02 diverging-terms note (rc `=_rc')"
    local ++fail_count
    local failed "`failed' C02"
}

**# C03: collin corpora -- the retained design decides
* x2 = x1 + 1e-9 or 1e-7 times 0/1/2: stcox omits x2 in every case, and the
* certificate of the retained design is the truth. Decisive: the cases where
* the check, handed the FULL design, returns a verdict that is wrong for the
* fitted model; without the filter those would reach the user.
foreach c in g_collin g_collinP {
    local ++test_count
    capture noisily {
        _cmd_corpus `cases' `exp' `ctl' `c'
        tempfile r_`c'
        quietly save `r_`c''
        gen byte kw = 0
        foreach k of local kw_`c' {
            quietly replace kw = 1 if case == `k'
        }
        quietly count if cmdst == 8
        local nv = r(N)
        quietly count if !inlist(cmdst, 0, 1, 2, 8)
        assert r(N) == 0
        quietly count if !kw & cmdst == 1 & truth == 0
        local w1 = r(N)
        quietly count if !kw & cmdst == 0 & truth == 1
        local w0 = r(N)
        quietly count if full == 0 & ((fullst == 1 & truth == 0) | (fullst == 0 & truth == 1))
        local dec = r(N)
        quietly count if full == 0
        local nom = r(N)
        display as text "  `c': n=`=_N' x2 omitted=`nom' no-verdict=`nv' wrong1=`w1' wrong0=`w0' decisive=`dec'"
        if `w1' + `w0' {
            quietly levelsof case if !kw & ((cmdst == 1 & truth == 0) | (cmdst == 0 & truth == 1)), local(bad)
            display as error "  `c' wrong verdicts at cases: `bad'"
        }
        assert missing(truth) == 0 if cmdst != 8
        assert truth >= 0 if cmdst != 8
        assert `w1' == 0 & `w0' == 0
        assert `dec' >= 20
    }
    if _rc == 0 {
        display as result "  PASS: C03 `c': the fitted model's certificate decides every verdict"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C03 `c' (rc `=_rc')"
        local ++fail_count
        local failed "`failed' C03_`c'"
    }
}

**# C04: heavy and b_gap corpora -- no wrong verdict outside the known list
foreach c in g_heavy b_gap {
    local ++test_count
    capture noisily {
        _cmd_corpus `cases' `exp' `ctl' `c'
        tempfile r_`c'
        quietly save `r_`c''
        gen byte kw = 0
        foreach k of local kw_`c' {
            quietly replace kw = 1 if case == `k'
        }
        quietly count if !kw & cmdst == 1 & truth == 0
        local w1 = r(N)
        quietly count if !kw & cmdst == 0 & truth == 1
        local w0 = r(N)
        quietly count if cmdst == 2
        local s2 = r(N)
        quietly count if full
        local nf = r(N)
        display as text "  `c': n=`=_N' all terms kept=`nf' wrong1=`w1' wrong0=`w0' status2=`s2'"
        if `w1' + `w0' {
            quietly levelsof case if !kw & ((cmdst == 1 & truth == 0) | (cmdst == 0 & truth == 1)), local(bad)
            display as error "  `c' wrong verdicts at cases: `bad'"
        }
        assert truth >= 0 & !missing(truth) if cmdst != 8
        assert `w1' == 0 & `w0' == 0
        assert `nf' > 0
    }
    if _rc == 0 {
        display as result "  PASS: C04 `c': no wrong verdict reaches the user outside the known list"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C04 `c' (rc `=_rc')"
        local ++fail_count
        local failed "`failed' C04_`c'"
    }
}

**# K01-K03: known-wrong verdicts that reach the user (1.0.1 base)
* The exact certificate of the design stcox fitted says finite, but the
* group is declared monotone and its z, p, HR and CI are withheld. The
* accepted direction violates one pair by 1e-17 to 4e-15 of that pair's size
* (decimal rounding of x + 1e-4 and the like), inside the check's slack
* error allowance (_iivw_mlib.ado). g_collinP 305 is reached only through
* the filter: stcox drops x3, and the kept (x1, x2) has its own such pair.
local k = 0
foreach c in g_heavy b_gap g_collinP {
    local ++k
    local ++test_count
    capture noisily {
        use `r_`c'', clear
        gen byte kw = 0
        foreach q of local kw_`c' {
            quietly replace kw = 1 if case == `q'
        }
        quietly keep if kw
        assert _N == `: word count `kw_`c'''
        assert truth == 0
        quietly count if cmdst == 1
        if r(N) {
            quietly levelsof case if cmdst == 1, local(bad)
            display as error "  `c' false monotone reaches the user at cases: `bad'"
        }
        assert inlist(cmdst, 0, 2)
    }
    if _rc == 0 {
        display as result "  PASS: K0`k' `c' known-wrong cases now agree with the certificate"
        local ++pass_count
    }
    else {
        display as error "  FAIL: K0`k' `c' known-wrong cases (rc `=_rc')"
        local ++fail_count
        local failed "`failed' K0`k'"
    }
}

**# C05: a joint p in the subnormal range is reported, not r(198)
* Two strong lags on 380 subjects: chi2(2) of about 1450, joint p near 1e-317,
* below c(smallestdouble). Stata prints such a value in %21x as
* +0.xxxxxxxxxxxxxX-3ff, which it cannot read back; the 1.0.1 command
* aborted with r(198) at its first use. Oracle: stcox on the hand-built
* Andersen-Gill rows and the Wald statistic b' V^-1 b formed here.
local ++test_count
capture noisily {
    tempname R bb VV W
    set seed 4
    quietly iivw_exog_dgp, groups(1) n(380) gammas(.8) gammatwo(.4) maxfu(5) k(120)
    tempfile sub
    quietly save `sub'
    sort id time
    quietly by id: gen double a0 = time[_n - 1]
    gen double a1 = time
    gen byte ev = 1
    quietly by id: gen double l1 = y[_n - 1]
    quietly by id: gen double l2 = y2[_n - 1]
    quietly by id: gen byte last = _n == _N
    quietly expand 2 if last & time < 5, gen(tail)
    quietly replace a0 = time if tail
    quietly replace a1 = 5 if tail
    quietly replace ev = 0 if tail
    quietly replace l1 = y if tail
    quietly replace l2 = y2 if tail
    quietly keep if !missing(a0, l1, l2) & a1 > a0
    quietly stset a1, enter(time a0) failure(ev) id(id) exit(time .)
    quietly stcox l1 l2, efron vce(cluster id) noshow
    assert e(converged) == 1
    matrix `bb' = e(b)
    matrix `VV' = e(V)
    matrix `W' = `bb' * invsym(`VV') * `bb''
    scalar _c05_w = `W'[1, 1]
    scalar _c05_p = chi2tail(2, scalar(_c05_w))
    assert scalar(_c05_p) > 0 & scalar(_c05_p) < c(smallestdouble)
    use `sub', clear
    capture noisily iivw_exogtest y y2, id(id) time(time) maxfu(5) nolog
    assert _rc == 0
    local jp = r(joint_min_p)
    local hp = r(holm_min_p)
    assert r(n_models) == 1 & r(n_unknown) == 0 & r(history_association_flag) == 1
    assert `jp' > 0 & `jp' < c(smallestdouble)
    assert `hp' == `jp'
    * The subnormal p carries about 30 significant bits; the statistics agree
    * to 1e-12, so the p-values agree to well inside 1e-6.
    assert !missing(`jp', scalar(_c05_p))
    assert reldif(`jp', scalar(_c05_p)) < 1e-6
    matrix `R' = r(results)
    assert !missing(`R'[1, 5], `R'[2, 5], `R'[1, 6], `R'[2, 6])
    assert !missing(`R'[1, 3], `R'[2, 3], `bb'[1, 1], `bb'[1, 2])
    assert reldif(`R'[1, 3], `bb'[1, 1]) < 1e-9 & reldif(`R'[2, 3], `bb'[1, 2]) < 1e-9
    scalar drop _c05_w _c05_p
}
if _rc == 0 {
    display as result "  PASS: C05 subnormal joint p reported exactly, no r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: C05 subnormal joint p (rc `=_rc')"
    local ++fail_count
    local failed "`failed' C05"
}

**# D02: the command's verdict does not depend on the jumbler state
* g_heavy 443 606 660: identical data, run after set sortrngstate 1..8. The
* 1.0.1 base reports some of these groups under one state and withholds them
* as unsettled under another (KNOWN WRONG: tie order in the check's sort).
local ++test_count
capture noisily {
    local nflip = 0
    foreach q in 443 606 660 {
        use `exp' if corpus == "g_heavy" & case == `q', clear
        local p = p[1]
        local ys ""
        forvalues j = 1/`p' {
            local ys "`ys' y`j'"
        }
        local s0 = ""
        forvalues st = 1/8 {
            _cmd_case `cases' g_heavy `q'
            _cmd_topanel `p' `ctl'
            set sortrngstate `st'
            capture quietly iivw_exogtest `ys', id(id) time(time) censor(cens) by(grp) nolog
            assert _rc == 0
            local sig = string(r(n_unknown)) + "/" + string(r(n_monotone))
            if "`s0'" == "" local s0 "`sig'"
            if "`sig'" != "`s0'" {
                local ++nflip
                display as error "  g_heavy `q': state `st' gives unknown/monotone `sig', state 1 `s0'"
            }
        }
    }
    assert `nflip' == 0
}
if _rc == 0 {
    display as result "  PASS: D02 the command's verdict is the same under jumbler states 1-8"
    local ++pass_count
}
else {
    display as error "  FAIL: D02 command verdict depends on tie order (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D02"
}

set sortrngstate `srs0'
iivw_qa_summary, name(validation_iivw_exogtest_command) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
