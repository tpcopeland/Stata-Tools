*! test_finegray_audit_2026_10_05_runtime Version 1.0.0  2026/10/06
*! Regression coverage for audit findings R01-R04 (runtime)
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.  Every cell below was a rc-0 or wrong-refusal defect
* that the existing suites never reached:
*
*   R02  a range anywhere in attime()/timepoints() sent EVERY token through
*        numlist's ~13-digit serialisation, so a literal horizon typed exactly
*        on an event time moved below the event: CIF and SE of 0 at rc 0.
*   R03  _datasignature is invariant to an independent permutation of one
*        signed column, so swapping x (or status, cluster, id) between rows
*        kept the data signature while changing every fitting tuple.  The CIF,
*        its SE and the Schoenfeld correlation were recomputed from the new
*        association against the old b/V at rc 0.  The weight digest was keyed
*        by id alone, so a compensated weight swap plus id swap also passed.
*   R01  `finegray 2.grp x' enumerated only the typed term, so predict, margins
*        and the diagnostics refused grp levels 1 and 3, which the fit saw.
*   R04  weighted finegray_cif called _finegray_wsig before its own loader: r(3499)
*        after `mata: mata clear' and in a fresh process after `estimates use'.
*
* Every R03 control that must ACCEPT (full-row sort, rows outside the fitting
* sample, legacy-free predict) is paired with the permutations that must refuse.
* The legacy-estimate cell blanks e(rowsig) on a live new fit through an
* e-class helper; it proves the refusal path, not a historical .ster.

clear all
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_audit_2026_10_05_runtime.log", replace text name(_fgar)

local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace
local plus_dir "`c(sysdir_plus)'"
local personal_dir "`c(sysdir_personal)'"

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _ar_blank_rowsig
program define _ar_blank_rowsig, eclass
    ereturn local rowsig ""
end

capture program drop _ar_saw
program define _ar_saw, rclass
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

capture program drop _ar_mk
program define _ar_mk
    version 16.0
    syntax [, N(integer 240) SEED(integer 9813)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen byte g = mod(id, 2)
    gen byte grp = mod(id, 3) + 1
    gen long cl = ceil(id / 8)
    gen double x = rnormal() + 0.3 * g
    gen double t = -ln(runiform()) / (0.08 * exp(0.4 * x))
    gen double tc = -ln(runiform()) * 12
    gen byte status = cond(runiform() < 0.7, 1, 2)
    replace status = 0 if tc < t
    replace t = min(t, tc)
    replace t = max(t, 0.01)
    quietly stset t, failure(status == 1 2) id(id)
end

* Swap `v' between row pairs (1,2), (3,4), ... of the first 2*k rows
capture program drop _ar_pairswap
program define _ar_pairswap
    args v k s
    if "`s'" == "" local s 1
    * rows b..b+s-1 exchange with b+s..b+2s-1.  replace is sequential, so the
    * exchange reads an untouched copy (a local would round to 15 digits).
    tempvar o
    quietly generate double `o' = `v'
    forvalues b = 1(`=2*`s'')`k' {
        forvalues i = `b'/`=`b'+`s'-1' {
            local j = `i' + `s'
            quietly replace `v' = `o'[`j'] in `i'
            quietly replace `v' = `o'[`i'] in `j'
        }
    }
end

* ---------------------------------------------------------------------------
**# R02 horizon literals survive a range elsewhere in the list
* ---------------------------------------------------------------------------
capture program drop _ar_mk8
program define _ar_mk8
    clear
    quietly set obs 8
    gen long id = _n
    gen double x = cond(mod(_n, 2), -1, 1)
    gen double t = cond(_n <= 2, .123456789012345, 6 + floor((_n - 1) / 2))
    gen byte status = cond(_n <= 2, 1, cond(_n <= 4, 2, 0))
    quietly stset t, failure(status == 1 2) id(id)
    quietly finegray x, compete(status) cause(1) nolog basehaz
end

local ++test_count
capture noisily {
    _ar_mk8
    quietly finegray_cif, at(x=0) attime(.123456789012345) nograph
    tempname L
    matrix `L' = r(table)
    local lone_cif = `L'[1, 2]
    assert `L'[1, 1] == .123456789012345
    assert `lone_cif' > 0.2
    assert abs(`lone_cif' - (1 - exp(-.25))) < 1e-6
    * the same horizon next to an unrelated range
    quietly finegray_cif, at(x=0) attime(.123456789012345 2 3 to 5) nograph
    matrix `L' = r(table)
    assert rowsof(`L') == 5
    assert `L'[1, 1] == .123456789012345
    assert reldif(`L'[1, 2], `lone_cif') < 1e-12
    assert `L'[1, 3] > 0
    quietly finegray_cif, at(x=0) timepoints(.123456789012345 2(1)5) nograph
    matrix `L' = r(table)
    assert `L'[1, 1] == .123456789012345
    assert reldif(`L'[1, 2], `lone_cif') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: AR-R02a literal horizon exact beside a range; CIF and SE unmoved"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R02a literal horizon beside a range (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ar_mk8
    tempfile grid
    quietly finegray_cif, at(x=0) timepoints(.123456789012345 2 3 to 5) ///
        saving("`grid'", replace) name(_ar_g, replace)
    preserve
    quietly use "`grid'", clear
    quietly summarize time if abs(time - .123456789012345) < 1e-9, meanonly
    assert r(N) == 1
    quietly count if time == .123456789012345 & abs(cif - (1 - exp(-.25))) < 1e-6
    assert r(N) == 1
    restore
    * the plotted series carries the same exact point
    quietly graph display _ar_g
    quietly serset set 0
    quietly serset use, clear
    quietly count if time == .123456789012345 & abs(cif - (1 - exp(-.25))) < 1e-6
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: AR-R02b saved dataset and graph series carry the exact horizon"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R02b saved/graph horizon (rc=`=_rc')"
    local ++fail_count
}
capture graph drop _ar_g

local ++test_count
capture noisily {
    _ar_mk8
    foreach spec in "5 .123456789012345 2 3 : 5" "2 3 to 5 .123456789012345" ///
        "5 0/2 .123456789012345 .123456789012345" {
        quietly finegray_cif, at(x=0) attime(`spec') nograph
        tempname M
        matrix `M' = r(table)
        quietly mata: st_local("hit", strofreal(sum(st_matrix("r(table)")[., 1] :== .123456789012345)))
        assert `hit' == 1
    }
    quietly finegray_cif, at(x=0) attime(5 .123456789012345 2 3 : 5) nograph
    assert rowsof(r(table)) == 5
    * a range ENDPOINT that numlist would round cannot be honoured: refuse
    capture finegray_cif, at(x=0) attime(.123456789012345 1 to 3) nograph
    assert _rc == 198
    capture finegray_cif, at(x=0) attime(.123456789012345(1)3) nograph
    assert _rc == 198
    quietly finegray_cif, at(x=0) attime(1 2 to 5) nograph
    assert rowsof(r(table)) == 5
    quietly finegray_cif, at(x=0) attime(0(.5)2) nograph
    assert rowsof(r(table)) == 5
}
if _rc == 0 {
    display as result "  PASS: AR-R02c grammar variants keep literals; lossy range endpoints refuse 198"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R02c grammar variants (rc=`=_rc')"
    local ++fail_count
}

* ---------------------------------------------------------------------------
**# R03 joint tuple identity
* ---------------------------------------------------------------------------
* reference fit, unweighted, clustered
local ++test_count
capture noisily {
    _ar_mk
    quietly finegray x, compete(status) cause(1) cluster(cl) nolog
    quietly finegray_cif, at(x=0) attime(5) ci nograph
    tempname R
    matrix `R' = r(table)
    assert `R'[1, 2] > 0 & `R'[1, 3] > 0
    * legal: a full-row sort changes nothing
    set seed 1
    gen double _u = runiform()
    sort _u
    drop _u
    quietly finegray_cif, at(x=0) attime(5) ci nograph
    assert reldif(r(table)[1, 2], `R'[1, 2]) < 1e-10
    assert reldif(r(table)[1, 3], `R'[1, 3]) < 1e-10
    quietly finegray_phtest
    * legal: appended rows outside the fitting sample
    quietly set obs `=_N + 5'
    quietly replace x = 30 in -5/L
    quietly finegray_cif, at(x=0) attime(5) ci nograph
    assert reldif(r(table)[1, 2], `R'[1, 2]) < 1e-10
    quietly keep in 1/240
}
if _rc == 0 {
    display as result "  PASS: AR-R03a full-row sort and appended rows are accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R03a legal reorder/append (rc=`=_rc')"
    local ++fail_count
}

foreach v in x status cl id {
    local ++test_count
    capture noisily {
        _ar_mk
        quietly finegray x, compete(status) cause(1) cluster(cl) nolog
        quietly finegray_cif, at(x=0) attime(5) ci nograph
        quietly finegray_predict _arc0, cif ci
        quietly finegray_phtest
        * the signed column's multiset is untouched: the marginal signature agrees
        quietly _datasignature `e(datasignaturevars)' if e(sample), nodefault nonames
        local sig0 `"`r(datasignature)'"'
        if "`v'" == "id" {
            * ids of a stset-id dataset: exchange two subjects' ids
            _ar_pairswap id 60
        }
        else if "`v'" == "cl" _ar_pairswap cl 60 8
        else _ar_pairswap `v' 60
        quietly _datasignature `e(datasignaturevars)' if e(sample), nodefault nonames
        assert `"`r(datasignature)'"' == `"`sig0'"'
        capture finegray_cif, at(x=0) attime(5) ci nograph
        assert _rc == 459
        capture finegray_predict _arc1, cif ci
        assert _rc == 459
        capture finegray_phtest
        assert _rc == 459
    }
    if _rc == 0 {
        display as result "  PASS: AR-R03b permuting `v' alone is refused (459) by CIF, predict CI, phtest"
        local ++pass_count
    }
    else {
        display as error "  FAIL: AR-R03b permuting `v' (rc=`=_rc')"
        local ++fail_count
    }
}

* adjacent double: one-ulp edit of a signed value
local ++test_count
capture noisily {
    _ar_mk
    quietly finegray x, compete(status) cause(1) nolog
    quietly replace x = x * (1 + 2^-52) in 7
    capture finegray_cif, at(x=0) attime(5) ci nograph
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: AR-R03c a one-ulp edit of an in-sample value is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R03c adjacent double (rc=`=_rc')"
    local ++fail_count
}

* weighted: compensated scalar weights + id swap keep the id|weight pairs
local ++test_count
capture noisily {
    _ar_mk
    scalar _ar_a = 1
    scalar _ar_b = 3
    quietly finegray x [pw = cond(g, scalar(_ar_a), scalar(_ar_b))], compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0) attime(5) ci nograph
    scalar _ar_a = 3
    scalar _ar_b = 1
    quietly replace id = cond(g, id + 1, id - 1)
    capture finegray_cif, at(x=0) attime(5) ci nograph
    assert _rc == 459
    capture finegray_predict _arw, cif ci
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: AR-R03d compensated weight + id swap is refused (459)"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R03d weight/id counterfeit (rc=`=_rc')"
    local ++fail_count
}

* weighted full-row sort is still accepted; weight digest keyed by the tuple
local ++test_count
capture noisily {
    _ar_mk
    quietly finegray x [pw = 1 + mod(id, 3)], compete(status) cause(1) nolog
    assert "`e(wsigkeyvars)'" != ""
    quietly finegray_cif, at(x=0) attime(5) ci nograph
    local ref = r(table)[1, 2]
    set seed 2
    gen double _u = runiform()
    sort _u
    drop _u
    quietly finegray_cif, at(x=0) attime(5) ci nograph
    assert reldif(r(table)[1, 2], `ref') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: AR-R03e weighted full-row sort accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R03e weighted sort (rc=`=_rc')"
    local ++fail_count
}

* rows outside the fitting sample may change freely (marker is 0, not missing)
local ++test_count
capture noisily {
    _ar_mk
    quietly finegray x if id <= 200, compete(status) cause(1) nolog
    quietly finegray_cif, at(x=0) attime(5) ci nograph
    local ref = r(table)[1, 2]
    quietly replace x = x + 100 in 230/240
    _ar_pairswap x 8
    * rows 1-8 are in sample: that edit must be refused ...
    capture finegray_cif, at(x=0) attime(5) ci nograph
    assert _rc == 459
    _ar_pairswap x 8
    * ... and undone it, only outside rows differ
    quietly finegray_cif, at(x=0) attime(5) ci nograph
    assert reldif(r(table)[1, 2], `ref') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: AR-R03f outside-sample edits ignored; in-sample swap refused"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R03f outside-sample rows (rc=`=_rc')"
    local ++fail_count
}

* legacy estimate (no e(rowsig)): refit instruction, but data-free routes work
local ++test_count
capture noisily {
    _ar_mk
    quietly finegray x, compete(status) cause(1) nolog basehaz
    _ar_blank_rowsig
    assert "`e(rowsig)'" == ""
    capture finegray_cif, at(x=0) attime(5) ci nograph
    assert _rc == 301
    capture finegray_predict _arl, cif ci
    assert _rc == 301
    capture finegray_phtest
    assert _rc == 301
    quietly finegray_predict _arx, xb
    quietly count if missing(_arx)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: AR-R03g estimates without e(rowsig) refuse inference (301), xb still works"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R03g legacy estimates (rc=`=_rc')"
    local ++fail_count
}

* ---------------------------------------------------------------------------
**# R01 full fit-time factor support, independent of the typed terms
* ---------------------------------------------------------------------------
local ++test_count
capture noisily {
    _ar_mk
    quietly replace grp = cond(grp == 3, 20, grp)
    quietly finegray 2.grp x, compete(status) cause(1) nolog basehaz
    set type double
    quietly finegray_predict _arxb, xb
    quietly count if missing(_arxb)
    assert r(N) == 0
    quietly gen double _arch = (grp == 2) * _b[2.grp] + x * _b[x]
    assert abs(_arxb - _arch) < 1e-12 in 1/L
    quietly finegray_predict _arcf, cif
    quietly finegray_predict _arsc, schoenfeld
    quietly count if status == 1 & !missing(_arsc)
    quietly count if status == 1 & e(sample)
    local nev = r(N)
    quietly count if !missing(_arsc)
    assert r(N) == `nev'
    quietly margins, predict(xb)
    tempname mm
    matrix `mm' = r(b)
    quietly summarize _arxb, meanonly
    assert abs(`mm'[1, 1] - r(mean)) < 1e-10
    * a level the fit never saw is still refused
    quietly replace grp = 99 in 1
    capture finegray_predict _arbad, xb
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: AR-R01a selective factor term scores every fitted level; unseen level refused"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R01a selective factor support (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ar_mk
    quietly finegray ib2.grp#c.x i.g, compete(status) cause(1) nolog basehaz
    quietly finegray_predict _arxb, xb
    quietly count if missing(_arxb)
    assert r(N) == 0
    quietly finegray_cif, at(grp=1 g=0 x=0) attime(5) nograph
    quietly finegray_cif, at(grp=3 g=1 x=0) attime(5) nograph
    * a SELECTIVE interaction: only the grp==2 slope is a coefficient, yet
    * grp 1 and 3 were observed at fit time and must score (the 1.3.7 guard
    * enumerated coefficient terms only and refused them, r(459))
    _ar_mk
    quietly finegray 2.grp#c.x g, compete(status) cause(1) nolog basehaz
    set type double
    quietly finegray_predict _arxs, xb
    quietly count if missing(_arxs)
    assert r(N) == 0
    quietly gen double _arcs = (grp == 2) * x * _b[2.grp#c.x] + g * _b[g]
    assert abs(_arxs - _arcs) < 1e-12 in 1/L
    quietly finegray_cif, at(grp=1 g=0 x=0) attime(5) nograph
    quietly finegray_cif, at(grp=3 g=1 x=0) attime(5) nograph
}
if _rc == 0 {
    display as result "  PASS: AR-R01b base-specified interaction terms keep full support"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R01b interaction support (rc=`=_rc')"
    local ++fail_count
}

* ---------------------------------------------------------------------------
**# Fit-time support and row-identity metadata VALUES
* ---------------------------------------------------------------------------
local ++test_count
capture noisily {
    _ar_mk
    quietly replace grp = cond(grp == 3, 20, grp)
    * selective factor term: support still lists every level the fit saw
    quietly finegray 2.grp x, compete(status) cause(1) nolog
    assert "`e(fvsupport_vars)'" == "grp"
    assert "`e(fvsupport1)'" == "1 2 20"
    assert "`e(fvsupport2)'" == ""
    * two factor variables, interaction-only first term
    quietly finegray 2.grp#c.x i.g, compete(status) cause(1) nolog
    assert "`e(fvsupport_vars)'" == "grp g"
    assert "`e(fvsupport1)'" == "1 2 20"
    assert "`e(fvsupport2)'" == "0 1"
    * an if-restricted fit records only the levels in its sample
    quietly finegray 2.grp x if grp != 20, compete(status) cause(1) nolog
    assert "`e(fvsupport_vars)'" == "grp"
    assert "`e(fvsupport1)'" == "1 2"
    * no factor term: nothing is posted
    quietly finegray x, compete(status) cause(1) nolog
    assert "`e(fvsupport_vars)'" == ""
}
if _rc == 0 {
    display as result "  PASS: AR-R01c e(fvsupport_vars) and e(fvsupport#) hold the observed levels"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R01c fvsupport values (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ar_mk
    quietly finegray x, compete(status) cause(1) nolog
    assert e(rowsig_n) == 240
    assert e(rowsig_n) == e(N)
    * the id is in the digest's variable list but NOT in the storage-sensitive signature
    assert strpos(" `e(rowsigvars)' ", " id ") > 0
    assert strpos(" `e(datasignaturevars)' ", " id ") == 0
    * if-restricted: digest counts the estimation sample only
    quietly finegray x if cl <= 10, compete(status) cause(1) nolog
    assert e(rowsig_n) == 80
    quietly count if e(sample)
    assert r(N) == 80
}
if _rc == 0 {
    display as result "  PASS: AR-R03j e(rowsig_n) counts the estimation rows; id covered by e(rowsigvars) only"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R03j rowsig_n/rowsigvars values (rc=`=_rc')"
    local ++fail_count
}

* ---------------------------------------------------------------------------
**# Storage-type changes of the id and entry variables are not data changes
* ---------------------------------------------------------------------------
* e(datasignature) is storage-type sensitive; the id and entry variables are
* covered by the value-hashing e(rowsig) instead, so compress / recast of them
* must be accepted with identical numbers while a permuted id is still refused.
foreach wt in unweighted pweight {
    local ++test_count
    capture noisily {
        _ar_mk
        quietly replace x = round(x, 0.01)
        * the weight is a COLUMN: a weight expression that reads id would put id
        * in the storage-sensitive signature, which is a different case
        quietly generate double _arw = 1 + mod(id, 3)
        if "`wt'" == "pweight" quietly finegray x [pw = _arw], compete(status) cause(1) nolog
        else quietly finegray x, compete(status) cause(1) nolog
        quietly finegray_cif, at(x=0) attime(5) ci nograph
        matrix _ar_R0 = r(table)
        quietly finegray_predict double _ar_c0, cif ci
        foreach op in "compress id" "recast double id" "recast float id" {
            preserve
            `op'
            capture noisily finegray_cif, at(x=0) attime(5) ci nograph
            assert _rc == 0
            assert mreldif(_ar_R0, r(table)) < 1e-12
            capture drop _ar_c1*
            capture noisily finegray_predict double _ar_c1, cif ci
            assert _rc == 0
            quietly gen double _ar_dd = abs(_ar_c1 - _ar_c0) + abs(_ar_c1_lci - _ar_c0_lci)
            quietly summarize _ar_dd, meanonly
            assert r(max) < 1e-12
            restore
        }
        * a compressed id that is then PERMUTED is still refused
        quietly compress id
        _ar_pairswap id 60
        capture finegray_cif, at(x=0) attime(5) ci nograph
        assert _rc == 459
    }
    if _rc == 0 {
        display as result "  PASS: AR-R03k `wt': compress/recast of id accepted with identical CIF and CI; permuted id refused"
        local ++pass_count
    }
    else {
        display as error "  FAIL: AR-R03k `wt' id storage type (rc=`=_rc')"
        local ++fail_count
    }
    capture restore
}

local ++test_count
capture noisily {
    * delayed entry through a multiple-record fit: _fg_entry is the entry variable
    clear
    set seed 30922
    quietly set obs 300
    gen long id = _n
    gen double x = round(rnormal(), 0.01)
    gen double t = 2 + ceil(10 * runiform())
    gen byte status = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    expand 2
    bysort id: gen byte episode = _n
    bysort id: gen double stop = cond(_n == 1, t - 1, t)
    gen byte event = cond(episode == 1, 0, status)
    quietly stset stop, id(id) failure(event == 1 2)
    quietly finegray x, compete(event) cause(1) nolog
    assert "`e(entryvar)'" == "_fg_entry"
    assert strpos(" `e(rowsigvars)' ", " _fg_entry ") > 0
    assert strpos(" `e(datasignaturevars)' ", " _fg_entry ") == 0
    quietly finegray_cif, at(x=0) attime(5) ci nograph
    matrix _ar_R0 = r(table)
    foreach op in "compress _fg_entry" "recast float _fg_entry" "compress id" "recast double id" {
        preserve
        `op'
        capture noisily finegray_cif, at(x=0) attime(5) ci nograph
        assert _rc == 0
        assert mreldif(_ar_R0, r(table)) < 1e-12
        restore
    }
    * a changed entry time (row 2 is the subject's estimation row) is still refused
    quietly replace _fg_entry = _fg_entry + 1 in 2
    capture finegray_cif, at(x=0) attime(5) ci nograph
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: AR-R03l compress/recast of the entry variable and id accepted; changed entry refused"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R03l entry storage type (rc=`=_rc')"
    local ++fail_count
}
capture restore

* ---------------------------------------------------------------------------
**# Legacy estimates (no e(rowsig)) get the refit refusal FIRST
* ---------------------------------------------------------------------------
* estimates use restores no e(sample); the empty-sample message (r(459), "run
* estimates esample:") used to be shown first, and only after following it did
* the real r(301) "refit" appear.  The probe is a new fit with e(rowsig) blanked
* (an actual 1.3.7 .ster is exercised by test_finegray_wsig_legacy).
local ++test_count
capture noisily {
    _ar_mk
    quietly finegray x, compete(status) cause(1) nolog basehaz
    _ar_blank_rowsig
    tempfile lg
    quietly estimates save `lg', replace
    quietly save "`lg'_d", replace
    quietly use "`lg'_d", clear
    quietly estimates use `lg'
    assert "`e(rowsig)'" == ""
    quietly count if e(sample)
    assert r(N) == 0
    foreach cmd in "finegray_cif, at(x=0) attime(5) nograph" ///
        "finegray_cif, at(x=0) attime(5) ci nograph" ///
        "finegray_predict double _arl, cif ci" ///
        "finegray_predict double _arl, schoenfeld" ///
        "finegray_phtest" {
        tempfile cap
        quietly log using `"`cap'"', replace text name(_arlg)
        capture noisily `cmd'
        local crc = _rc
        quietly log close _arlg
        assert `crc' == 301
        _ar_saw using `"`cap'"', phrase("predates joint-row")
        assert r(saw) == 1
        _ar_saw using `"`cap'"', phrase("estimation sample is empty")
        assert r(saw) == 0
    }
    * the routes documented as still working for legacy estimates do work
    capture noisily finegray_predict double _arxb, xb
    assert _rc == 0
    capture noisily finegray_predict double _arcf, cif
    assert _rc == 0
    capture noisily finegray_predict double _arbh, basecshazard
    assert _rc == 0
    * with the sample re-declared the answer is the same refusal
    quietly estimates esample: `e(datasignaturevars)'
    capture finegray_cif, at(x=0) attime(5) ci nograph
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: AR-R03m legacy estimates: r(301) refit message first, with and without esample; xb/cif/basecshazard kept"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R03m legacy first error (rc=`=_rc')"
    local ++fail_count
}

* ---------------------------------------------------------------------------
**# R04 weighted finegray_cif on a cold Mata namespace and a new process
* ---------------------------------------------------------------------------
local ++test_count
capture noisily {
    _ar_mk
    quietly finegray x [pw = 1 + mod(id, 3)], compete(status) cause(1) nolog basehaz
    quietly finegray_cif, at(x=0) attime(3 5) ci nograph
    tempname W
    matrix `W' = r(table)
    mata: mata clear
    mata: mata set matastrict off
    quietly finegray_cif, at(x=0) attime(3 5) ci nograph
    forvalues r = 1/2 {
        forvalues c = 2/3 {
            assert reldif(r(table)[`r', `c'], `W'[`r', `c']) < 1e-10
        }
    }
    assert c(matastrict) == "off"
    mata: mata clear
    mata: mata set matastrict on
    quietly finegray_cif, at(x=0) attime(3 5) ci nograph
    assert c(matastrict) == "on"
    mata: mata set matastrict off
}
if _rc == 0 {
    display as result "  PASS: AR-R04a weighted finegray_cif after mata clear; matastrict kept"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R04a weighted CIF cold Mata (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ar_mk
    quietly finegray x [pw = 1 + mod(id, 3)], compete(status) cause(1) nolog basehaz
    quietly finegray_cif, at(x=0) attime(3 5) ci nograph
    local ref1 = r(table)[1, 2]
    local ref2 = r(table)[2, 3]
    tempfile ds est
    local wd "`c(tmpdir)'"
    tempname fh
    local cdir "`ds'_child"
    quietly mkdir "`cdir'"
    quietly save "`ds'", replace
    quietly estimates save "`est'", replace
    file open `fh' using "`cdir'/profile.do", write text replace
    file write `fh' "set processors 1" _newline
    file write `fh' `"sysdir set PLUS "`plus_dir'""' _newline
    file write `fh' `"sysdir set PERSONAL "`personal_dir'""' _newline
    file close `fh'
    file open `fh' using "`cdir'/child.do", write text replace
    file write `fh' `"use "`ds'", clear"' _newline
    file write `fh' `"estimates use "`est'""' _newline
    file write `fh' "estimates esample: \`e(datasignaturevars)' if !missing(_t)" _newline
    file write `fh' "capture finegray_cif, at(x=0) attime(3 5) ci nograph" _newline
    file write `fh' "local crc = _rc" _newline
    file write `fh' "clear" _newline
    file write `fh' "set obs 1" _newline
    file write `fh' "gen rc = \`crc'" _newline
    file write `fh' "capture gen double c1 = r(table)[1, 2]" _newline
    file write `fh' "capture gen double s2 = r(table)[2, 3]" _newline
    file write `fh' `"save "`cdir'/out.dta", replace"' _newline
    file close `fh'
    quietly shell cd "`cdir'" && stata-mp -b do child.do
    quietly use "`cdir'/out.dta", clear
    assert rc[1] == 0
    assert reldif(c1[1], `ref1') < 1e-10
    assert reldif(s2[1], `ref2') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: AR-R04b weighted finegray_cif first in a fresh process after estimates use"
    local ++pass_count
}
else {
    display as error "  FAIL: AR-R04b fresh process (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_audit_2026_10_05_runtime tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgar
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgar
