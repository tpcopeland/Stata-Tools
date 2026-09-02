* crossval_cif.do
* Cross-validation of the finegray cumulative-incidence machinery:
*   (1) CIF point estimates vs riskRegression::predictRisk (tolerance <1e-4)
*   (2) analytic CIF standard errors vs a same-dataset full-refit subject
*       bootstrap.  This is a sensitivity check, not an exact oracle: the
*       bootstrap re-estimates weights that the fixed-weight analytic SE treats
*       as fixed.  No standard tool exposes the matching analytic quantity.
* SKIP-safe when R or riskRegression is unavailable.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "crossval_cif.log", replace name(_cvcif)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local pass = 0
local fail = 0
local skip = 0

program define _finegray_use_hypoxia
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else {
        use "`cache'", clear
    }
end

* Locate Rscript
local Rscript ""
foreach c in "Rscript" "/usr/bin/Rscript" {
    capture confirm file "`c'"
    if !_rc local Rscript "`c'"
}
if "`Rscript'" == "" {
    capture shell which Rscript > "`c(tmpdir)'/_whichR.txt"
    capture file open _wr using "`c(tmpdir)'/_whichR.txt", read
    capture file read _wr line
    capture file close _wr
    if `"`line'"' != "" local Rscript "Rscript"
}

* Run-unique file prefix (QA-H02): the R oracle CSVs used FIXED paths in
* c(tmpdir), so two concurrent runs of this suite clobbered each other's oracle,
* and a stale _cv_out.csv from a previous run was consumed as if it were this
* run's -- a fixed path, gated only on existence, with no pre-delete.  A per-run
* prefix isolates the files; the output is pre-deleted before the R call and
* required to reappear before it is trusted.  tempfile supplies a session-
* unique path, including when deterministic seeds or concurrent runs coincide.
tempfile _cv_anchor
local _cvpx "`_cv_anchor'_"
local _cv_in  "`_cvpx'in.csv"
local _cv_nd  "`_cvpx'nd.csv"
local _cv_tm  "`_cvpx'tm.csv"
local _cv_out "`_cvpx'out.csv"

**# ------------------------------------------------------------------
**# Fit on hypoxia and export for R
**# ------------------------------------------------------------------
_finegray_use_hypoxia
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1)
assert e(converged) == 1

* Export estimation data (R needs time/status + covariates)
preserve
keep if e(sample)
rename dftime time
keep time status ifp tumsize pelnode
export delimited using "`_cv_in'", replace
restore

* Two profiles: means and a fixed profile
quietly summarize ifp if e(sample), meanonly
scalar mi = r(mean)
quietly summarize tumsize if e(sample), meanonly
scalar mt = r(mean)
quietly summarize pelnode if e(sample), meanonly
scalar mp = r(mean)
preserve
clear
set obs 2
gen ifp = cond(_n==1, mi, 20)
gen tumsize = cond(_n==1, mt, 5)
gen pelnode = cond(_n==1, mp, 1)
export delimited using "`_cv_nd'", replace
clear
set obs 3
gen time = cond(_n==1, 2, cond(_n==2, 5, 8))
export delimited using "`_cv_tm'", replace
restore

**# ------------------------------------------------------------------
**# (1) CIF point vs riskRegression
**# ------------------------------------------------------------------
local have_r = 0
if "`Rscript'" != "" {
    * Pre-delete the oracle output so a stale CSV from a previous run cannot be
    * mistaken for this run's (QA-H02).  Then require it to REAPPEAR: existence
    * after a delete-then-run is proof the R call actually wrote it.
    capture erase "`_cv_out'"
    capture confirm file "`_cv_out'"
    assert _rc != 0
    capture shell `Rscript' "`qa_dir'/crossval_cif_r.R" ///
        "`_cv_in'" "`_cv_nd'" ///
        "`_cv_tm'" "`_cv_out'"
    capture confirm file "`_cv_out'"
    if !_rc local have_r = 1
}

if `have_r' {
    * finegray_cif point at both profiles, times 2 5 8
    finegray_cif, at(ifp=`=mi' tumsize=`=mt' pelnode=`=mp') attime(2 5 8)
    matrix P1 = r(table)
    finegray_cif, at(ifp=20 tumsize=5 pelnode=1) attime(2 5 8)
    matrix P2 = r(table)

    preserve
    import delimited using "`_cv_out'", clear case(preserve)
    isid profile time
    assert _N == 6
    * profile 1 rows then profile 2 rows, each times 2 5 8
    local maxdiff = 0
    forvalues r = 1/3 {
        quietly sum cif if profile==1 & abs(time - P1[`r',1]) < 1e-6, meanonly
        local d1 = abs(r(mean) - P1[`r',2])
        quietly sum cif if profile==2 & abs(time - P2[`r',1]) < 1e-6, meanonly
        local d2 = abs(r(mean) - P2[`r',2])
        if `d1' > `maxdiff' local maxdiff = `d1'
        if `d2' > `maxdiff' local maxdiff = `d2'
    }
    restore
    display as text "max |CIF_finegray - CIF_riskRegression| = " `maxdiff'
    if `maxdiff' < 1e-4 {
        display as result "  PASS: CIF point matches riskRegression"
        local ++pass
    }
    else {
        display as error "  FAIL: CIF point vs riskRegression (maxdiff `maxdiff')"
        local ++fail
    }
}
else {
    display as text "  SKIP: riskRegression CIF point check (R unavailable)"
    local ++skip
}

**# ------------------------------------------------------------------
**# (2) CIF SE vs same-dataset subject bootstrap
**# ------------------------------------------------------------------
* analytic SE at profile=means, times 2 5 8
_finegray_use_hypoxia
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1) basehaz
assert e(converged) == 1
quietly summarize ifp if e(sample), meanonly
scalar mi = r(mean)
quietly summarize tumsize if e(sample), meanonly
scalar mt = r(mean)
quietly summarize pelnode if e(sample), meanonly
scalar mp = r(mean)
finegray_cif, at(ifp=`=mi' tumsize=`=mt' pelnode=`=mp') attime(2 5 8) ci
matrix A = r(table)
scalar a2 = A[1,3]
scalar a5 = A[2,3]
scalar a8 = A[3,3]

_finegray_use_hypoxia
gen byte status = failtype
tempfile _cv_boot
save "`_cv_boot'", replace

program define _cifpt, rclass
    args tt
    tempname bh b
    matrix `b' = e(b)
    scalar xb = `b'[1,1]*mi + `b'[1,2]*mt + `b'[1,3]*mp
    matrix `bh' = e(basehaz)
    local nb = rowsof(`bh')
    scalar H0 = 0
    forvalues r=1/`nb' {
        if `bh'[`r',1] <= `tt' {
            scalar H0 = `bh'[`r',2]
        }
    }
    return scalar cif = 1 - exp(-H0*exp(xb))
end

set seed 20260621
scalar s2=0
scalar s5=0
scalar s8=0
scalar q2=0
scalar q5=0
scalar q8=0
scalar nb=0
local reps 400
forvalues b=1/`reps' {
    quietly {
        use "`_cv_boot'", clear
        bsample
        gen long _nid = _n
        stset dftime, failure(dfcens==1) id(_nid)
        * basehaz: _cifpt reads e(basehaz) to step the baseline by hand, so each
        * bootstrap refit must post it.  Without the option the matrix is absent,
        * _cifpt errors, every replication is discarded, and nb stays 0 -- which
        * surfaces as a MISSING bootstrap SE, not as a failed fit.
        capture finegray ifp tumsize pelnode, compete(status) cause(1) basehaz
        local fit_rc = _rc
        if `fit_rc' == 0 & e(converged) != 1 local fit_rc = 430
        if `fit_rc' == 0 {
            scalar nb=nb+1
            _cifpt 2
            scalar s2=s2+r(cif)
            scalar q2=q2+r(cif)^2
            _cifpt 5
            scalar s5=s5+r(cif)
            scalar q5=q5+r(cif)^2
            _cifpt 8
            scalar s8=s8+r(cif)
            scalar q8=q8+r(cif)^2
        }
    }
}
scalar bse2=sqrt((q2-s2^2/nb)/(nb-1))
scalar bse5=sqrt((q5-s5^2/nb)/(nb-1))
scalar bse8=sqrt((q8-s8^2/nb)/(nb-1))
display as text "analytic SE: " a2 " " a5 " " a8
display as text "bootstrap SE: " bse2 " " bse5 " " bse8

* The analytic SE treats censoring weights as known; allow it to run up to
* ~15% below bootstrap, and not materially above it.
local okse = (nb == `reps')
display as text "successful bootstrap refits: " nb " of `reps'"
foreach pair in "`=a2'/`=bse2'" "`=a5'/`=bse5'" "`=a8'/`=bse8'" {
    local an : word 1 of `=subinstr("`pair'","/"," ",.)'
    local bo : word 2 of `=subinstr("`pair'","/"," ",.)'
    local ratio = `an'/`bo'
    display as text "  ratio analytic/bootstrap = " %5.3f `ratio'
    if `ratio' < 0.80 | `ratio' > 1.15 local okse = 0
}
if `okse' {
    display as result "  PASS: CIF SE within tolerance of bootstrap"
    local ++pass
}
else {
    display as error "  FAIL: CIF SE vs bootstrap out of tolerance"
    local ++fail
}

**# Summary
display as text _newline "RESULT: crossval_cif tests=`=`pass'+`fail'+`skip'' pass=`pass' fail=`fail' skip=`skip'"
foreach f in "`_cv_in'" "`_cv_nd'" "`_cv_tm'" "`_cv_out'" {
    capture erase "`f'"
}
* A SKIPPED EXTERNAL ORACLE IS AN UNRUN CHECK, NOT A PASS (2026-09-02).
* This suite used to print "RESULT: PASS (n passed, k skipped)" and exit 0 when
* the R oracle was unavailable, so a machine with no R -- or with the package
* missing -- produced a green cross-validation that had cross-validated nothing.
* run_all.do already treats skip > 0 as a lane failure by parsing the machine
* sentinel, but a human reading the suite's own last line was told PASS.  Match
* crossval_pweight.do: skip > 0 exits 1, and the word PASS is not printed on a
* skipped run.  The machine sentinel above is unchanged -- run_all.do parses
* `RESULT: <name> tests=.. pass=.. fail=.. skip=..' and nothing else.
if `fail' > 0 {
    display as error "SOME CROSSVAL CHECKS FAILED"
    log close _cvcif
    exit 1
}
if `skip' > 0 {
    display as error ///
        "NOT RUN: `skip' check(s) SKIPPED -- the R oracle was unavailable"
    display as error "Install the missing R dependency and re-run; a skipped oracle is not evidence."
    log close _cvcif
    exit 1
}
display as result "CROSSVAL OK"
log close _cvcif
