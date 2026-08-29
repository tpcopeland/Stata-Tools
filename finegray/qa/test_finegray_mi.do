*! test_finegray_mi Version 1.0.0  2026/08/24
*! Multiple-imputation compatibility for finegray (v1.3.0)
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* `mi estimate, cmdok:' has no registration hook -- mi_estimate.sthlp documents
* cmdok as the community-command path and the supported list is internal -- so
* "compatible" means: it works, it is tested, and it is documented.  Rubin's
* rules apply to any (b, V) from an M-estimator, and the Fine-Gray pseudo-
* likelihood with a sandwich qualifies; there is no new statistics here.  What
* there IS, and what this suite exists for, is the package's habit of writing
* PERMANENT columns into the caller's data:
*
*   _fg_entry        earliest subject entry time on a multiple-record fit
*   _fg_<term>       one design column per factor-variable term
*
* Both are post-estimation SUPPORT (the fit itself runs on tempvars inside
* `preserve').  In mi data they are unregistered variables.  Verified against
* the v1.2.0 tree: `finegray i.grp x, compete(etype) cause(1)' typed on `mi set
* wide' data ran to convergence at rc 0 and left _fg_grp_2 and _fg_grp_3 behind,
* with `mi describe' reporting "there are 2 unregistered variables".
*
* v1.3.0 detects mi data and routes that support through tempvars, which means
* it does not survive the command -- so post-estimation must refuse rather than
* answer from columns that are gone.  Refusing by NAME (e(postest)) rather than
* by failing to find the columns is not fussiness: a tempvar name is reused by
* the next command that asks for one, so a stale e(designvars) could resolve to
* somebody else's column at rc 0.
*
* Verified 2026-08-25 against the pre-fix tree (git HEAD of Stata-Tools, v1.2.0)
* in an isolated scratch copy: 6 pass / 7 fail there on tests 1-13.
* Tests 1, 2, 4, 5, 11, 12 and 13 are the discriminating half.  Tests 3, 6, 7,
* 8, 9 and 10 pass on both and are the no-regression half -- 3 in particular,
* because it is what would catch a routing change that moved the estimate: the
* mi-mode fit must be BIT-IDENTICAL to the same fit off mi data.  6 is the
* statistics: mi estimate's pooled output must equal Rubin's rules applied by
* hand to the per-imputation e(b)/e(V), so a wrong scale or a wrong variance
* would show there rather than in an eyeball of the table.
*
* Tests 14-17 were added 2026-08-25 for the detection defect found after those
* thirteen were written: detection used to fire on the mere EXISTENCE of a
* variable named _mi_m / _mi_id / _mi_miss, which are legal names in ordinary
* data.  14-16 are the hostile-name regressions (they fail on the shipped
* 1.3.0 working tree as it stood before that fix), 17 pins what `mi estimate'
* actually leaves in e() so the demo and these comments tell one story.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_mi.log", replace name(_fgmi)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgmi_result
program define _fgmi_result, rclass
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

* Read a captured log back and report whether a phrase appears in it.  Several
* assertions here are about the MESSAGE: r(301) is what a plain "you must run
* finegray" refusal already returns, so rc alone cannot tell the mi refusal from
* the generic one.
capture program drop _fgmi_saw
program define _fgmi_saw, rclass
    version 16.0
    syntax using/, PHrase(string)
    tempname fh
    local saw = 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`phrase'"') > 0 local saw = 1
        file read `fh' line
    }
    file close `fh'
    return scalar saw = `saw'
end

* Single-record competing-risks fixture with one MAR-incomplete covariate (z)
* and one factor covariate (grp).  `anyev' is the stset failure indicator, so
* compete() is an ordinary classification column.
capture program drop _fgmi_data
program define _fgmi_data
    version 16.0
    syntax [, SEED(integer 20260824) N(integer 500)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x = rnormal()
    gen double z = rnormal()
    gen byte grp = 1 + floor(3 * runiform())
    gen double t = 1 + floor(10 * runiform())
    gen byte etype = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    gen byte anyev = etype != 0
    * MAR in x: the imputation model below is correctly specified for it
    quietly replace z = . if invlogit(-1.2 + 0.6 * x) > runiform()
end

* Two-record-per-subject version of the same fixture, for the _fg_entry path.
* Records are contiguous ((0,1] then (1,tend]) and covariates are constant
* within id, which is what the multiple-record reduction requires.  Not mi.
capture program drop _fgmi_data_mr
program define _fgmi_data_mr
    version 16.0
    syntax [, SEED(integer 20260824) N(integer 400)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x = rnormal()
    gen double z = rnormal()
    gen byte grp = 1 + floor(3 * runiform())
    gen double tend = 2 + floor(9 * runiform())
    gen byte etype = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly replace z = . if invlogit(-1.2 + 0.6 * x) > runiform()
    * split each subject into (0, 1] and (1, tend]
    quietly expand 2
    bysort id: gen byte _rec = _n
    gen double t0 = cond(_rec == 1, 0, 1)
    gen double t  = cond(_rec == 1, 1, tend)
    quietly replace etype = 0 if _rec == 1
    gen byte anyev = etype != 0
    drop _rec tend
end

* The mi version of the multiple-record fixture, built the only way that is
* actually coherent: impute at SUBJECT level, then `mi expand' the completed
* rows.  Imputing after the split instead gives a subject two different draws of
* z on its two records, which is a time-varying covariate -- finegray refuses
* it, and rightly (test 9b pins that refusal).
capture program drop _fgmi_set_mr
program define _fgmi_set_mr
    version 16.0
    syntax , STYle(string) [M(integer 5)]
    * subject-level exit time for the split; _fgmi_data ships a single-record
    * `t' in 1..10, and the second interval (1, tend] must be non-empty
    rename t tend
    quietly replace tend = 2 if tend < 2
    drop anyev
    quietly mi set `style'
    quietly mi register imputed z
    quietly mi register regular x grp etype tend id
    set seed 4242
    quietly mi impute regress z = x, add(`m')
    quietly mi expand 2
    * `_mi_m' exists only in mlong/flong; in wide every row is one subject and
    * the record index is just _n within id.
    capture confirm variable _mi_m
    if !_rc bysort _mi_m id: gen byte _rec = _n
    else    bysort id: gen byte _rec = _n
    gen double t0 = cond(_rec == 1, 0, 1)
    gen double t  = cond(_rec == 1, 1, tend)
    gen byte ev   = cond(_rec == 1, 0, etype)
    gen byte anyev = ev != 0
    quietly mi register regular _rec t0 t ev anyev
    quietly mi update
    quietly mi stset t, failure(anyev) id(id) enter(time t0)
end

* mi-set a fixture in the requested style.  stset comes AFTER mi set, via
* mi stset, so that _st/_d/_t/_t0 are registered and mi update stays clean.
capture program drop _fgmi_set
program define _fgmi_set
    version 16.0
    syntax , STYle(string) [M(integer 5) MR]
    quietly mi set `style'
    quietly mi register imputed z
    if "`mr'" == "" quietly mi register regular x grp etype t anyev id
    else            quietly mi register regular x grp etype t t0 anyev id
    set seed 4242
    quietly mi impute regress z = x, add(`m')
    if "`mr'" == "" quietly mi stset t, failure(anyev) id(id)
    else            quietly mi stset t, failure(anyev) id(id) enter(time t0)
end

* Run a command with its output captured to a log, and report both its return
* code and whether a phrase appeared.  The command arrives as ONE compound-quoted
* token because every call here contains commas of its own (`mi estimate, cmdok
* noisily: finegray ..., compete(...)'), which a `syntax' line would split on.
capture program drop _fgmi_note
program define _fgmi_note, rclass
    version 16.0
    gettoken cmd 0 : 0
    gettoken phrase 0 : 0
    tempfile cap
    capture log close _fgmicap
    log using "`cap'", replace text name(_fgmicap)
    capture noisily `cmd'
    local rc = _rc
    log close _fgmicap
    _fgmi_saw using "`cap'", phrase(`"`phrase'"')
    return scalar saw = r(saw)
    return scalar rc = `rc'
end

* -----------------------------------------------------------------------------
**# 1. A factor-variable fit on mi data leaves NO unregistered columns
* -----------------------------------------------------------------------------
* The v1.2.0 defect, on the style where it is reachable: `wide' keeps one row per
* subject, so the fit runs and the _fg_<term> columns land in the user's mi data.
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set, style(wide)

    quietly finegray i.grp x, compete(etype) cause(1) nolog
    assert e(converged) == 1

    * no package-owned columns left behind
    local _resid ""
    capture quietly ds _fg_*
    if !_rc local _resid "`r(varlist)'"
    assert "`_resid'" == ""

    * and mi's own audit agrees
    tempfile capmid
    capture log close _cmid
    log using "`capmid'", replace text name(_cmid)
    mi describe
    log close _cmid
    _fgmi_saw using "`capmid'", phrase("there are no unregistered variables")
    assert r(saw) == 1

    * mi update must have nothing to repair
    capture noisily mi update
    assert _rc == 0

    * the fit declares itself
    assert `"`e(mi_data)'"' == "1"
    assert `"`e(postest)'"' == "unavailable_mi"

    * and NO estimation-state characteristic is written at all.
    *
    * This line used to assert "0" -- the INVALIDATED mark.  That was pinning a
    * defect as a contract: on mi data the fit mutates nothing permanent, so
    * there is nothing for the mark to invalidate, and writing it put seven
    * _dta[_finegray_*] characteristics into the caller's mi dataset against
    * finegray.ado's own stated contract.  Corrected 2026-08-26 with defect
    * D0-1; the full story and the regressions are in
    * qa/test_finegray_mi_lattice.do (FGML-01/02/03).  ABSENT means UNKNOWN and
    * is adjudicated against e(), which is the right state for a dataset the
    * fit never touched.
    assert `"`: char _dta[_finegray_estimated]'"' == ""
    local _cs : char _dta[]
    local _nfgc = 0
    foreach _c of local _cs {
        if substr("`_c'", 1, 10) == "_finegray_" local ++_nfgc
    }
    assert `_nfgc' == 0
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-1 fv fit on mi data leaves no unregistered columns"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 2. A multiple-record fit on mi data leaves no _fg_entry
* -----------------------------------------------------------------------------
* The other permanent column.  Its name is claimed by a pre-flight check in
* v1.2.0 ("variable _fg_entry already exists"); on mi data no name is claimed at
* all, so a USER variable called _fg_entry must not be refused either.
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set_mr, style(wide)

    * a user variable occupying the name finegray would otherwise take
    quietly gen double _fg_entry = 0

    quietly finegray x, compete(ev) cause(1) nolog
    assert e(converged) == 1
    assert `"`e(mi_data)'"' == "1"

    * the user's variable is untouched and is still theirs
    capture confirm variable _fg_entry
    assert _rc == 0
    quietly summarize _fg_entry
    assert r(min) == 0 & r(max) == 0

    * e(entryvar) names the tempvar the fit used, not the user's column
    assert `"`e(entryvar)'"' != "_fg_entry"
    assert `"`e(entryvar)'"' != ""
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-2 multiple-record fit on mi data writes no _fg_entry"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 3. mi routing does not move the estimate (bit-identical e(b), e(V))
* -----------------------------------------------------------------------------
* The tempvar routing changes WHERE the design columns live, nothing else.  The
* same data fitted with and without the mi characteristics must give the same
* numbers to the last bit -- including the factor path, where the mi branch
* generates its column from a different source variable than the named branch.
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set, style(wide)
    quietly finegray i.grp x, compete(etype) cause(1) nolog
    tempname b_mi V_mi
    matrix `b_mi' = e(b)
    matrix `V_mi' = e(V)
    local ll_mi = e(ll)

    * same rows, same values, no mi
    _fgmi_data
    quietly stset t, failure(anyev) id(id)
    quietly finegray i.grp x, compete(etype) cause(1) nolog
    tempname b_pl V_pl
    matrix `b_pl' = e(b)
    matrix `V_pl' = e(V)
    local ll_pl = e(ll)

    assert colsof(`b_mi') == colsof(`b_pl')
    forvalues j = 1/`=colsof(`b_pl')' {
        assert `b_mi'[1, `j'] == `b_pl'[1, `j']
        forvalues k = 1/`=colsof(`b_pl')' {
            assert `V_mi'[`j', `k'] == `V_pl'[`j', `k']
        }
    }
    assert `ll_mi' == `ll_pl'

    * and the coefficient stripe is still the terms the user typed
    local cn : colnames `b_mi'
    assert strpos("`cn'", "grp") > 0
    assert strpos("`cn'", "_fg_") == 0
    assert strpos("`cn'", "__0") == 0
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-3 mi routing leaves e(b)/e(V)/e(ll) bit-identical"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 4. Post-estimation fails CLOSED on an mi fit, by name
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set, style(wide)
    quietly finegray i.grp x, compete(etype) cause(1) nolog

    foreach _c in predict cif phtest {
        tempfile cap`_c'
        capture log close _cp
        log using "`cap`_c''", replace text name(_cp)
        if "`_c'" == "predict"  capture noisily finegray_predict _p1, xb
        if "`_c'" == "cif"      capture noisily finegray_cif, at(x=0 grp=1)
        if "`_c'" == "phtest"   capture noisily finegray_phtest
        local rc_`_c' = _rc
        log close _cp

        assert `rc_`_c'' == 301
        _fgmi_saw using "`cap`_c''", ///
            phrase("post-estimation is not available after a fit on mi data")
        assert r(saw) == 1
        _fgmi_saw using "`cap`_c''", phrase("mi extract")
        assert r(saw) == 1
    }

    * no variable was created by the refused predict
    capture confirm variable _p1
    assert _rc != 0
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-4 predict/cif/phtest refuse an mi fit at r(301) by name"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 5. mi estimate, cmdok: runs, in every style, and restores the data
* -----------------------------------------------------------------------------
* Also the detection test.  mi hands the command one completed dataset whose
* _dta[_mi_style] is "bad" under mlong/wide and ABSENT under flong; the flong
* case is carried by _dta[_mi_substyle] == "bad" instead, which is the only
* _mi_* characteristic mi leaves on that dataset (enumerated 2026-08-25; the
* table is in finegray.ado's detection comment).  A style that slipped through
* detection would write _fg_<term> columns into mi's working copy -- which mi
* discards, so the residue check cannot see it.  Nor can e(postest) be trusted
* to distinguish the styles here: mi posts its pooled results OVER the last
* per-imputation fit's e(), so e(postest) survives for whichever style ran
* last (test 17 pins that) and says nothing about the others.  So the detection
* is asserted directly through a probe fit run in each style.
local ++test_count
capture noisily {
    foreach _sty in mlong wide flong {
        _fgmi_data
        _fgmi_set, style(`_sty')

        * (a) pooled fit runs
        quietly mi estimate, cmdok eform("SHR"): ///
            finegray i.grp x z, compete(etype) cause(1) nolog
        assert e(cmd) == "mi estimate"
        assert e(cmd_mi) == "finegray"
        assert e(M_mi) == 5

        * (b) the caller's data is intact afterwards
        local _resid ""
        capture quietly ds _fg_*
        if !_rc local _resid "`r(varlist)'"
        assert "`_resid'" == ""
        capture noisily mi update
        assert _rc == 0

        * (c) detection fired INSIDE mi estimate, in this style.  Reading it
        * back from e() afterwards would not do: mi posts its pooled results
        * over the last per-imputation fit's e(), so e(mi_data)/e(postest) do
        * survive (test 17) but only for the fit that happened to run last --
        * they cannot attribute detection to THIS style.  Residue cannot do it
        * either, because mi discards its working copy whether the columns were
        * written or not.  What it CAN be read from is the fit's own output:
        * `mi estimate, noisily' echoes each per-imputation fit, and the mi note
        * is printed only when detection fired.  This is the assertion that
        * covers flong, where _dta[_mi_style] is ABSENT inside mi estimate and
        * _dta[_mi_substyle] is the only characteristic left to detect on.
        _fgmi_note ///
            `"mi estimate, cmdok noisily: finegray i.grp x, compete(etype) cause(1) nolog"' ///
            "fitted on multiple-imputation data"
        assert r(rc) == 0
        assert r(saw) == 1
    }
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-5 mi estimate runs and detection fires in mlong/wide/flong"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 6. mi estimate's pooling IS Rubin's rules on finegray's e(b)/e(V)
* -----------------------------------------------------------------------------
* The statistics.  Refit each imputation by hand with `mi xeq', pool with the
* formulas (Rubin 1987; mi_estimate.sthlp, Methods and formulas)
*     Qbar = (1/M) sum Q_m
*     Ubar = (1/M) sum U_m           (within)
*     B    = (1/(M-1)) sum (Q_m - Qbar)^2   (between)
*     T    = Ubar + (1 + 1/M) B
* and assert agreement with what mi estimate posted.  Equality is to 1e-12
* relative, not exact: mi's own accumulation order need not match this loop's.
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set, style(mlong) m(5)
    local M = 5

    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    tempname Qmi Tmi
    matrix `Qmi' = e(b_mi)
    matrix `Tmi' = e(V_mi)
    local p = colsof(`Qmi')
    * read before the mi xeq loop below overwrites e()
    assert e(M_mi) == `M'

    tempname Qbar Ubar Bmat Qm Um Tman
    matrix `Qbar' = J(1, `p', 0)
    matrix `Ubar' = J(`p', `p', 0)
    forvalues m = 1/`M' {
        quietly mi xeq `m': finegray x z, compete(etype) cause(1) nolog
        matrix `Qm' = e(b)
        matrix `Um' = e(V)
        matrix `Qbar' = `Qbar' + `Qm' / `M'
        matrix `Ubar' = `Ubar' + `Um' / `M'
        matrix Q`m' = `Qm'
    }
    matrix `Bmat' = J(`p', `p', 0)
    forvalues m = 1/`M' {
        tempname dev
        matrix `dev' = Q`m' - `Qbar'
        matrix `Bmat' = `Bmat' + (`dev'' * `dev') / (`M' - 1)
    }
    matrix `Tman' = `Ubar' + (1 + 1 / `M') * `Bmat'

    * reldif(., .) is 0 in Stata, so a missing cell would SATISFY every
    * comparison below rather than failing it.
    forvalues j = 1/`p' {
        assert !missing(`Qbar'[1, `j'], `Qmi'[1, `j'])
        assert reldif(`Qbar'[1, `j'], `Qmi'[1, `j']) < 1e-12
        forvalues k = 1/`p' {
            assert !missing(`Tman'[`j', `k'], `Tmi'[`j', `k'])
            assert reldif(`Tman'[`j', `k'], `Tmi'[`j', `k']) < 1e-10
        }
    }

}
local _rc = _rc
_fgmi_result `_rc' "FGMI-6 mi estimate pooling reproduces hand Rubin's rules"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 7. eform("SHR") pools on the log-SHR scale
* -----------------------------------------------------------------------------
* e(b) is log-SHR, so mi estimate pools the log and exponentiates at display
* time -- which is the correct order.  Assert it directly: the reported SHR must
* be exp(pooled log-SHR), NOT the mean of the per-imputation SHRs (those differ
* by Jensen, and the difference is small enough to pass an eyeball).
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set, style(mlong) m(5)
    local M = 5

    quietly mi estimate, cmdok eform("SHR"): ///
        finegray x z, compete(etype) cause(1) nolog
    tempname Qmi
    matrix `Qmi' = e(b_mi)

    * mean of per-imputation SHRs, for contrast
    tempname shrbar
    matrix `shrbar' = J(1, colsof(`Qmi'), 0)
    forvalues m = 1/`M' {
        quietly mi xeq `m': finegray x z, compete(etype) cause(1) nolog
        tempname bm
        matrix `bm' = e(b)
        forvalues j = 1/`=colsof(`Qmi')' {
            matrix `shrbar'[1, `j'] = `shrbar'[1, `j'] + exp(`bm'[1, `j']) / `M'
        }
    }
    * e(b_mi) is on the LOG scale even under eform()
    forvalues j = 1/`=colsof(`Qmi')' {
        assert abs(`Qmi'[1, `j']) < 3
        assert !missing(exp(`Qmi'[1, `j']), `shrbar'[1, `j'])
        assert reldif(exp(`Qmi'[1, `j']), `shrbar'[1, `j']) < 1e-3
        assert exp(`Qmi'[1, `j']) != `shrbar'[1, `j']
    }
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-7 eform(SHR) pools log-SHR, exponentiates after"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 8. Pooled estimates recover the full-data fit
* -----------------------------------------------------------------------------
* Monte-Carlo sanity, not a coverage gate: with a correctly specified imputation
* model the pooled point estimates must sit near the fit on the data BEFORE
* missingness was imposed, and nearer to it than the complete-case fit's
* standard error would call a coincidence.  Tolerance is 1 within-imputation SE,
* which is loose on purpose -- this test is here to catch a pooling that is
* wrong by a lot (wrong scale, wrong weights), not to measure efficiency.
local ++test_count
capture noisily {
    * full data, no missingness
    clear
    set seed 20260824
    quietly set obs 500
    gen long id = _n
    gen double x = rnormal()
    gen double z = rnormal()
    gen byte grp = 1 + floor(3 * runiform())
    gen double t = 1 + floor(10 * runiform())
    gen byte etype = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    gen byte anyev = etype != 0
    tempfile fulldata
    quietly save "`fulldata'"

    quietly stset t, failure(anyev) id(id)
    quietly finegray x z, compete(etype) cause(1) nolog
    tempname bfull Vfull
    matrix `bfull' = e(b)
    matrix `Vfull' = e(V)

    * impose the same MAR mechanism and impute
    quietly use "`fulldata'", clear
    quietly replace z = . if invlogit(-1.2 + 0.6 * x) > runiform()
    _fgmi_set, style(mlong) m(20)
    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    tempname bpool
    matrix `bpool' = e(b_mi)

    forvalues j = 1/`=colsof(`bfull')' {
        local se = sqrt(`Vfull'[`j', `j'])
        assert abs(`bpool'[1, `j'] - `bfull'[1, `j']) < `se'
    }
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-8 pooled estimates recover the pre-missingness fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 9. A multiple-record id() fit pools under mi estimate
* -----------------------------------------------------------------------------
* The reduction path (and with it _fg_entry) under mi.  mi stset with enter()
* must arrive properly stset in each imputation, and the per-subject reduction
* must run on mi's working copy without touching the caller's data.
local ++test_count
capture noisily {
    * (a) the supported construction: impute at subject level, then mi expand
    _fgmi_data
    _fgmi_set_mr, style(mlong) m(5)

    _fgmi_note ///
        `"mi estimate, cmdok noisily: finegray x z, compete(ev) cause(1) nolog"' ///
        "records reduced to"
    assert r(rc) == 0
    assert r(saw) == 1
    assert e(cmd_mi) == "finegray"
    assert colsof(e(b_mi)) == 2

    local _resid ""
    capture quietly ds _fg_*
    if !_rc local _resid "`r(varlist)'"
    assert "`_resid'" == ""
    capture noisily mi update
    assert _rc == 0

    * (b) the construction that is NOT supported, pinned: imputing a covariate
    * AFTER the episode split draws a different value on each of a subject's
    * records, which is a time-varying covariate.  finegray refuses it off mi
    * data and must refuse it here too, with the same message -- silently
    * fitting the last record's draw would be an estimate of nothing.
    _fgmi_data_mr
    quietly mi set mlong
    quietly mi register imputed z
    quietly mi register regular x grp etype t t0 anyev id
    set seed 4242
    quietly mi impute regress z = x, add(3)
    quietly mi stset t, failure(anyev) id(id) enter(time t0)

    _fgmi_note ///
        `"mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog"' ///
        "covariate z varies within subject"
    assert r(rc) == 198
    assert r(saw) == 1
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-9 multiple-record id() fit pools under mi estimate"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 10. Off mi data nothing changed: support columns still persist
* -----------------------------------------------------------------------------
* The no-regression half.  The mi branch must not have taken the ordinary path
* with it: a plain fit still writes its _fg_<term> columns, still claims the
* _fg_entry name, still sets the estimation characteristic, and post-estimation
* still runs.
local ++test_count
capture noisily {
    _fgmi_data
    quietly drop if missing(z)
    quietly stset t, failure(anyev) id(id)
    quietly finegray i.grp x z, compete(etype) cause(1) nolog

    assert `"`e(mi_data)'"' == ""
    assert `"`e(postest)'"' == ""
    assert `"`: char _dta[_finegray_estimated]'"' == "1"

    capture quietly ds _fg_*
    assert _rc == 0
    local _resid "`r(varlist)'"
    assert "`_resid'" == "_fg_grp_2 _fg_grp_3"

    quietly finegray_predict _xb1, xb
    assert _rc == 0
    quietly finegray_cif, at(x=0 z=0 grp=1)
    assert _rc == 0
    quietly finegray_phtest
    assert _rc == 0

    * and the _fg_entry name is still claimed on a multiple-record fit
    _fgmi_data_mr
    quietly drop if missing(z)
    quietly stset t, failure(anyev) id(id) enter(time t0)
    quietly gen double _fg_entry = 0
    capture noisily finegray x, compete(etype) cause(1) nolog
    assert _rc == 198
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-10 off mi data the permanent-column contract is unchanged"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 11. mi extract is a working route back to post-estimation
* -----------------------------------------------------------------------------
* The refusal message names `mi extract'; a message that told the user to do
* something that does not work would be worse than no message.  Follow it.
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set, style(wide)
    quietly finegray i.grp x, compete(etype) cause(1) nolog
    assert `"`e(postest)'"' == "unavailable_mi"

    quietly mi extract 1, clear
    quietly stset t, failure(anyev) id(id)
    quietly finegray i.grp x, compete(etype) cause(1) nolog
    assert `"`e(postest)'"' == ""
    assert `"`e(mi_data)'"' == ""

    quietly finegray_predict _xb2, xb
    assert _rc == 0
    quietly finegray_cif, at(x=0 grp=1)
    assert _rc == 0
    quietly finegray_phtest
    assert _rc == 0
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-11 mi extract restores post-estimation, as the message says"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 12. The fit-time note is printed, and is printed again on replay
* -----------------------------------------------------------------------------
* Under `mi estimate' the per-imputation fits run quietly, so this note surfaces
* exactly where it is actionable: a finegray typed on mi data.  It is built from
* e() inside _finegray_display, so the replay prints the same line.
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set, style(wide)

    tempfile capfit
    capture log close _cf
    log using "`capfit'", replace text name(_cf)
    finegray i.grp x, compete(etype) cause(1) nolog
    log close _cf
    _fgmi_saw using "`capfit'", phrase("fitted on multiple-imputation data")
    assert r(saw) == 1
    _fgmi_saw using "`capfit'", phrase("e(postest)=unavailable_mi")
    assert r(saw) == 1

    tempfile caprep
    capture log close _cr
    log using "`caprep'", replace text name(_cr)
    finegray
    log close _cr
    _fgmi_saw using "`caprep'", phrase("fitted on multiple-imputation data")
    assert r(saw) == 1
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-12 mi note printed at fit time and on replay"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 13. After mi estimate, the refusals name mi estimate, not "run finegray"
* -----------------------------------------------------------------------------
* `mi estimate' posts its own pooled e(), so e(cmd) is "mi estimate" and every
* finegray post-estimation command falls into its generic "last estimates not
* found -- you must run finegray" branch.  A user who has just run finegray,
* through mi, is then told to run it.  Same r(301), different diagnosis: assert
* the message, because rc cannot tell the two apart.
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set, style(mlong)
    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    assert e(cmd) == "mi estimate"
    assert e(cmd_mi) == "finegray"

    _fgmi_note `"finegray_predict _p3, xb"' ///
        "post-estimation is not available after mi estimate"
    assert r(rc) == 301
    assert r(saw) == 1

    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    _fgmi_note `"finegray_cif, at(x=0 z=0)"' ///
        "post-estimation is not available after mi estimate"
    assert r(rc) == 301
    assert r(saw) == 1

    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    _fgmi_note `"finegray_phtest"' ///
        "post-estimation is not available after mi estimate"
    assert r(rc) == 301
    assert r(saw) == 1

    * and a bare `finegray' points at mi estimate's own replay
    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    _fgmi_note `"finegray"' ///
        "last estimates are pooled mi estimate results"
    assert r(rc) == 301
    assert r(saw) == 1
}
local _rc = _rc
_fgmi_result `_rc' "FGMI-13 post-mi-estimate refusals name mi estimate"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 14-16. HOSTILE: an ordinary variable named _mi_m / _mi_id / _mi_miss is NOT
**#         multiple-imputation data
* -----------------------------------------------------------------------------
* Through the first cut of 1.3.0, detection asked "does a variable named _mi_m,
* _mi_id or _mi_miss exist".  Those are legal names in an ordinary dataset, so
* the answer was yes on data that had never been near mi.  Reproduced
* 2026-08-25 against that tree:
*
*   webuse hypoxia, clear
*   generate byte status = failtype
*   stset dftime, failure(dfcens == 1) id(stnum)
*   generate long _mi_id = _n
*   quietly finegray ifp tumsize, compete(status) cause(1) nolog
*     -> e(mi_data)=1, e(postest)=unavailable_mi
*   finegray_predict double _xb, xb   -> r(301)
*
* An ordinary fit was routed through the mi bookkeeping path and all three
* post-estimation commands refused it.  Detection now asks whether the DATASET
* carries any _mi_* CHARACTERISTIC, which is true in all twelve mi style x
* context cells and false here (see the comment block in finegray.ado).  These
* three tests fail on the variable-name detector and pass on the char detector.
foreach _hostile in _mi_m _mi_id _mi_miss {
    local ++test_count
    capture noisily {
        _fgmi_data
        quietly drop if missing(z)
        quietly stset t, failure(anyev) id(id)
        * the hostile name, carrying ordinary user data
        quietly generate long `_hostile' = _n

        quietly finegray x z, compete(etype) cause(1) nolog

        * not mi: neither bookkeeping result may be posted
        assert `"`e(mi_data)'"' == ""
        assert `"`e(postest)'"' == ""
        assert e(cmd) == "finegray"
        assert e(converged) == 1

        * and all three post-estimation commands must WORK, not refuse
        capture drop _xbh
        finegray_predict double _xbh, xb
        quietly count if missing(_xbh) & e(sample)
        assert r(N) == 0

        quietly finegray_cif, at(x=0 z=0) attime(3 6) nograph
        matrix _cifh = r(table)
        * column 2 is the CIF; column 1 is the time, which would be non-missing
        * even on a table the command failed to fill.
        assert !missing(_cifh[1, 2], _cifh[2, 2])
        assert _cifh[1, 2] > 0 & _cifh[2, 2] < 1
        assert _cifh[2, 2] >= _cifh[1, 2]

        quietly finegray_phtest
        assert r(N_fail) < . & r(N_fail) > 0
        assert `"`r(time)'"' != ""

        * the hostile column is the user's data and must survive untouched
        quietly count if `_hostile' != _n
        assert r(N) == 0
    }
    local _rc = _rc
    _fgmi_result `_rc' ///
        "FGMI-hostile ordinary variable named `_hostile' is not mi data"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)
}

* -----------------------------------------------------------------------------
**# 17. What mi estimate leaves in e(mi_data)/e(postest) is RETAINED STATE
* -----------------------------------------------------------------------------
* Measured on this build (Stata 17.0 MP, 2026-08-25): `mi estimate, cmdok:'
* posts its own pooled results OVER the last per-imputation fit's e(), so the
* macros finegray posted survive -- e(mi_data) is "1" and e(postest) is
* "unavailable_mi" after the pooled command returns.  The demo prints them and
* this test pins them, so a Stata version that stops carrying them forward is
* visible here rather than as a mystery in the demo.
*
* What must NOT be inferred from that is that the pooled refusal DEPENDS on
* them.  It does not: finegray_cif / finegray_predict / finegray_phtest reach
* the `e(cmd) != "finegray"' gate first (e(cmd) is "mi estimate"), and test 13
* asserts the message that gate prints.  The e(postest) gate is for a fit typed
* directly on mi data, where e(cmd) IS "finegray".  Both are asserted here so
* the two mechanisms are not confused for one.
local ++test_count
capture noisily {
    _fgmi_data
    _fgmi_set, style(mlong)

    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    assert e(cmd) == "mi estimate"
    assert e(cmd_mi) == "finegray"
    * retained from the per-imputation fit
    assert `"`e(mi_data)'"' == "1"
    assert `"`e(postest)'"' == "unavailable_mi"

    * the refusal is driven by e(cmd), not by the retained e(postest):
    * test 13 already pins the mi-estimate message, which only the e(cmd)
    * branch prints.  Assert here that the OTHER message -- the one the
    * e(postest) branch prints -- is NOT what comes out.
    _fgmi_note `"finegray_cif, at(x=0 z=0)"' ///
        "post-estimation is not available after a fit on mi data"
    assert r(rc) == 301
    assert r(saw) == 0

    * and a fit typed DIRECTLY on mi data is the case the e(postest) gate is
    * for: e(cmd) is finegray there, so that branch is the one reached.
    _fgmi_data
    _fgmi_set, style(mlong)
    quietly mi xeq 1: finegray x z, compete(etype) cause(1) nolog
    assert e(cmd) == "finegray"
    assert `"`e(postest)'"' == "unavailable_mi"
}
local _rc = _rc
_fgmi_result `_rc' ///
    "FGMI-17 pooled e(mi_data)/e(postest) are retained state; refusal is by e(cmd)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# 18. mi estimate does NOT strip a typed weight
* -----------------------------------------------------------------------------
* An external audit (2026-08-29) reported that `mi estimate, cmdok:' silently
* discards [pw=]/[fw=] -- pooled coefficients identical to the unweighted
* pooled fit -- and asked for a doc sentence or a refusal.  It does not, on
* Stata 17 MP: the weight reaches every imputation's fit.  Both halves are
* pinned here rather than argued, because the failure the report describes is
* exactly the rc-0-but-wrong shape this package fences everywhere else, and a
* future Stata that DID strip the weight must turn this red instead of
* quietly pooling unweighted numbers.
*   per imputation: e(wtype) survives into the fit (mi xeq)
*   pooled:         the weighted pooled fit is NOT the unweighted pooled fit
local ++test_count
capture noisily {
    _fgmi_data
    quietly generate double pw = 0.5 + 2 * runiform()
    _fgmi_set, style(wide) m(3)
    quietly mi register regular pw

    * per imputation
    quietly mi xeq 1: finegray x z [pw = pw], compete(etype) cause(1) nolog
    assert "`e(wtype)'" == "pweight"
    assert "`e(wexp)'" == "= pw"
    tempname bw1
    matrix `bw1' = e(b)
    quietly mi xeq 1: finegray x z, compete(etype) cause(1) nolog
    assert "`e(wtype)'" == ""
    assert mreldif(`bw1', e(b)) > 1e-6

    * pooled
    quietly mi estimate, cmdok: finegray x z [pw = pw], compete(etype) cause(1) nolog
    tempname bmw
    matrix `bmw' = e(b_mi)
    quietly mi estimate, cmdok: finegray x z, compete(etype) cause(1) nolog
    assert mreldif(`bmw', e(b_mi)) > 1e-6
}
local _rc = _rc
_fgmi_result `_rc' ///
    "FGMI-18 mi estimate/mi xeq carry a typed weight into every imputation's fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_mi tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgmi
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgmi
