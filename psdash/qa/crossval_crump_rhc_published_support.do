*! crossval_crump_rhc_published_support.do Version 1.0.0  2026/11/17
*! Published-example reproduction of psdash support (binary common support and
*! Crump trimming) against Crump, Hotz, Imbens and Mitnik (2009)
*! Author: Timothy P Copeland, Karolinska Institutet
* Usage: cd psdash/qa && stata-mp -b do crossval_crump_rhc_published_support.do
*
* Source: Crump RK, Hotz VJ, Imbens GW, Mitnik OA (2009). Dealing with limited
*   overlap in estimation of average treatment effects. Biometrika 96(1):
*   187-199, doi:10.1093/biomet/asn055, Section 4 (pp. 195-196) and Table 2.
*   Full text: _literature/psdash/crump_2009_limited_overlap.txt.
* Data: right heart catheterization (SUPPORT), rhc.csv, found by _psdash_qa_extdata.do (see
*   SOURCE.md). "Data obtained from http://hbiostat.org/data courtesy of the
*   Vanderbilt University Department of Biostatistics." Original study:
*   Connors AF et al. (1996) JAMA 276:889-897. The file is not distributed
*   with the repository: the suite uses a copy under $STATA_QA_DATA when set,
*   otherwise downloads it, and exits 77 (skipped, dependency unavailable) if
*   neither is possible. Either way the
*   file must match the recorded length and Stata checksum CRC or the suite
*   fails.
*
* Propensity model: logit of RHC on main effects of 72 covariates, as stated in
* Crump et al. p. 195 but not listed there. The breakdown follows Li, Morgan and
* Zaslavsky (2018) JASA 113(521):390-400, doi:10.1080/01621459.2016.1260466
* (arXiv:1404.1785v3 p. 17): 21 continuous, 25 binary, 26 dummies from 6
* categorical covariates. Here: 21 continuous = age edu surv2md1 das2d3pc aps1
* scoma1 meanbp1 wblc1 hrt1 resp1 temp1 pafi1 alb1 hema1 bili1 crea1 sod1 pot1
* paco21 ph1 wtkilo1; 25 binary = 12 history flags, sex, dnr1, 10 admission
* diagnosis flags, and wt0 (weight recorded as 0 kg, 515 patients); 6
* categoricals = cat1 cat2 ca race income ninsclas (8+6+2+2+3+5 = 26 dummies).
* Excluded: outcomes (dth30, t3d30 = days to death within 30 days, sadmdte/
* dschdte/lstctdte/death), adld3p and urin1 (3028/1439 missing). Li et al. do
* not name the 25th binary; wt0 is inferred because with it every Table 2
* cell matches exactly (rank 72 + constant). Tolerances:
*   - printed alpha 0.1026: one 0.001 grid step (the grid psdash searches;
*     the paper prints 4 digits);
*   - cohort margins, Table 2 cells and totals: exact;
*   - psdash boundary arithmetic is also checked exactly against independent
*     Stata/Mata computations on the same propensity scores.
* Not asserted: Table 3 ATE estimates, bootstrap SEs and the 64% variance
* ratio (estimator not in psdash).

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "crossval_crump_rhc_published_support.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global PSDASH_CRH_TESTS = 0
global PSDASH_CRH_PASS = 0
global PSDASH_CRH_FAIL = 0
global PSDASH_CRH_FAILED ""

capture program drop _psdash_crh_record
program define _psdash_crh_record
    args id rc
    global PSDASH_CRH_TESTS = $PSDASH_CRH_TESTS + 1
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_CRH_PASS = $PSDASH_CRH_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_CRH_FAIL = $PSDASH_CRH_FAIL + 1
        global PSDASH_CRH_FAILED "$PSDASH_CRH_FAILED `id'"
    }
end

* Independent Crump Corollary 1 root, a different route from the package:
* bracket the first crossing of 1/(a(1-a)) <= 2*E[1/(e(1-e)) | a<=e<=1-a] on
* a 1e-4 scan, then bisect to 1e-12. Returns the exact root in r(root).
capture program drop _psdash_crh_root
program define _psdash_crh_root, rclass
    args psvar
    mata: st_numscalar("__crh_root", _psdash_crh_root_m("`psvar'"))
    return scalar root = scalar(__crh_root)
    scalar drop __crh_root
end

mata:
real scalar _psdash_crh_g(real colvector p, real scalar a)
{
    real colvector q
    q = select(p, (p :>= a) :& (p :<= 1 :- a))
    if (rows(q) == 0) return(.)
    return(1 / (a * (1 - a)) - 2 * mean(1 :/ (q :* (1 :- q))))
}
real scalar _psdash_crh_root_m(string scalar v)
{
    real colvector p
    real scalar a, lo, hi, mid, g
    p = st_data(., v)
    p = select(p, (p :> 0) :& (p :< 1))
    lo = .
    for (a = 0.0001; a <= 0.5; a = a + 0.0001) {
        g = _psdash_crh_g(p, a)
        if (g != . & g <= 0) {
            hi = a
            lo = a - 0.0001
            break
        }
    }
    if (lo == .) return(.)
    for (a = 1; a <= 60; a++) {
        mid = (lo + hi) / 2
        g = _psdash_crh_g(p, mid)
        if (g != . & g <= 0) hi = mid
        else lo = mid
    }
    return(hi)
}
end

**# Data and model setup

tempfile rhc_ps
run "`qa_dir'/_psdash_qa_extdata.do"
capture noisily _psdash_qa_extfile crump_rhc rhc.csv, len(2320412) crc(2782662126) ///
    url("https://hbiostat.org/data/repo/rhc.csv")
local ext_rc = _rc
if `ext_rc' {
    display as error "FAIL: rhc.csv integrity check (rc=`ext_rc')"
    display as text "RESULT: crossval_crump_rhc_published_support tests=1 pass=0 fail=1 skip=0"
    _psdash_qa_cleanup
    macro drop PSDASH_CRH_TESTS PSDASH_CRH_PASS PSDASH_CRH_FAIL PSDASH_CRH_FAILED
    capture log close _all
    exit 9
}
local rhc_csv `"`r(path)'"'
local rhc_source "`r(source)'"
if `"`rhc_csv'"' == "" {
    display as text "SKIP: rhc.csv unavailable (no STATA_QA_DATA copy and the public download failed)"
    display as text "RESULT: crossval_crump_rhc_published_support tests=0 pass=0 fail=0 skip=1 skipped=dependency_unavailable"
    _psdash_qa_cleanup
    macro drop PSDASH_CRH_TESTS PSDASH_CRH_PASS PSDASH_CRH_FAIL PSDASH_CRH_FAILED
    capture log close _all
    exit 77
}
display as text "rhc.csv source: `rhc_source' (length and CRC verified)"

capture noisily {
    * integrity: SOURCE.md records sha256 9ef4ab57...1556f8e8; Stata checks
    * the byte length and its checksum CRC of the same file
    checksum "`rhc_csv'"
    assert r(filelen) == 2320412
    assert r(checksum) == 2782662126
    import delimited using "`rhc_csv'", clear varnames(1) stringcols(_all)
    assert _N == 5735
    gen byte w = swang1 == "RHC"
    foreach v in cat1 cat2 ca sex race income ninsclas dnr1 resp card neuro ///
        gastr renal meta hema seps trauma ortho {
        quietly encode `v', gen(f_`v')
    }
    local cont21 age edu surv2md1 das2d3pc aps1 scoma1 meanbp1 wblc1 ///
        hrt1 resp1 temp1 pafi1 alb1 hema1 bili1 crea1 sod1 pot1 paco21 ph1 ///
        wtkilo1
    local hx cardiohx chfhx dementhx psychhx chrpulhx renalhx liverhx ///
        gibledhx malighx immunhx transhx amihx
    local xvars ""
    foreach v of local hx {
        quietly destring `v', gen(n_`v')
        assert inlist(n_`v', 0, 1)
        local xvars `xvars' n_`v'
    }
    foreach v of local cont21 {
        quietly destring `v', gen(n_`v')
        assert !missing(n_`v')
        local xvars `xvars' n_`v'
    }
    gen byte wt0 = n_wtkilo1 == 0
    quietly count if wt0
    assert r(N) == 515
    local xvars `xvars' wt0
    local cats ""
    foreach v in cat1 cat2 ca sex race income ninsclas dnr1 resp card neuro ///
        gastr renal meta hema seps trauma ortho {
        local cats `cats' i.f_`v'
    }
    quietly logit w `xvars' `cats'
    assert e(converged) == 1
    scalar crh_rank = e(rank)
    scalar crh_eN = e(N)
    quietly predict double psA, pr
    keep w psA
    save "`rhc_ps'", replace
}
local setup_rc = _rc
_psdash_crh_record setup_rhc_72_covariate_logit `setup_rc'
if `setup_rc' {
    display as text "RESULT: crossval_crump_rhc_published_support tests=$PSDASH_CRH_TESTS pass=$PSDASH_CRH_PASS fail=$PSDASH_CRH_FAIL skip=0"
    _psdash_qa_cleanup
    macro drop PSDASH_CRH_TESTS PSDASH_CRH_PASS PSDASH_CRH_FAIL PSDASH_CRH_FAILED
    capture log close _all
    exit 9
}

**# Cohort and model match the paper's stated sample

* Crump et al. p. 195: 5735 patients, 2184 treated, 3551 controls, 72
* covariates (logit rank 72 + constant = 73).
capture noisily {
    assert !missing(scalar(crh_rank), scalar(crh_eN))
    assert scalar(crh_eN) == 5735
    assert scalar(crh_rank) == 73
    use "`rhc_ps'", clear
    assert !missing(psA)
    assert psA > 0 & psA < 1
    quietly count if w == 1
    assert r(N) == 2184
    quietly count if w == 0
    assert r(N) == 3551
    psdash overlap w psA, nograph
    assert r(N) == 5735
    assert r(N_treated) == 2184
    assert r(N_control) == 3551
}
_psdash_crh_record cohort_margins_5735_2184_3551 `=_rc'

**# Crump optimal alpha

* Paper p. 195: alpha-hat = 0.1026. psdash searches an ascending 0.001 grid for
* the first alpha satisfying Corollary 1's inequality, so the comparable value
* is the paper's printed alpha rounded up to the grid (0.103); the tolerance is
* one grid step. The independent Mata root (exact, same PS vector) must round
* up to the psdash grid value exactly.
capture noisily {
    use "`rhc_ps'", clear
    psdash support w psA, crump nograph
    assert !missing(r(crump_alpha))
    scalar a_ps = r(crump_alpha)
    * published: alpha-hat 0.1026, Crump et al. (2009) p. 195
    assert abs(scalar(a_ps) - 0.1026) <= 0.001 + 1e-9
    assert !missing(scalar(a_ps))
    assert reldif(scalar(a_ps), 0.103) < 1e-9
    assert !missing(r(trim_lower)) & !missing(scalar(a_ps))
    assert reldif(r(trim_lower), scalar(a_ps)) < 1e-12
    assert !missing(r(trim_upper)) & !missing(1 - scalar(a_ps))
    assert reldif(r(trim_upper), 1 - scalar(a_ps)) < 1e-12

    _psdash_crh_root psA
    scalar a_root = r(root)
    assert !missing(scalar(a_root))
    * exact root lies within one grid step below the grid value psdash returns
    assert scalar(a_root) <= scalar(a_ps) + 1e-9
    assert scalar(a_root) > scalar(a_ps) - 0.001 - 1e-9
    * psdash value is the ceiling of the exact root to the 0.001 grid
    assert !missing(scalar(a_ps)) & !missing(ceil(scalar(a_root) * 1000 - 1e-9) / 1000)
    assert reldif(scalar(a_ps), ceil(scalar(a_root) * 1000 - 1e-9) / 1000) < 1e-9
    * the exact root also sits close to the paper's printed figure
    assert abs(scalar(a_root) - 0.1026) <= 0.001
    display as text "observed: psdash alpha=" %6.4f scalar(a_ps) " exact root=" %8.5f scalar(a_root) " paper=0.1026"
}
_psdash_crh_record crump_alpha_vs_paper_0_1026 `=_rc'

**# Crump trimmed share

* Paper p. 196: "by dropping 18% of the sample", a sentence that covers both
* the [0.1, 0.9] sample (17.56%, asserted exactly below) and the optimal
* sample. psdash's optimal-alpha share must round to 18, and its count must equal an independent count on the
* same propensity scores at the bounds psdash reports.
capture noisily {
    use "`rhc_ps'", clear
    psdash support w psA, crump nograph
    assert !missing(r(pct_trimmed), r(n_trimmed), r(N_remaining), r(trim_lower), r(trim_upper))
    assert r(pct_trimmed) >= 17.5 & r(pct_trimmed) < 18.5
    scalar n_tr = r(n_trimmed)
    scalar n_rem = r(N_remaining)
    scalar lo_b = r(trim_lower)
    scalar hi_b = r(trim_upper)
    scalar pct_b = r(pct_trimmed)
    quietly count if psA < scalar(lo_b) | psA > scalar(hi_b)
    assert scalar(n_tr) == r(N)
    assert scalar(n_rem) == 5735 - r(N)
    assert !missing(scalar(pct_b)) & !missing(100 * scalar(n_tr) / 5735)
    assert reldif(scalar(pct_b), 100 * scalar(n_tr) / 5735) < 1e-9
}
_psdash_crh_record crump_trimmed_share_18pct `=_rc'

**# Table 2 totals at the 0.1 / 0.9 cut

* Paper Table 2 (p. 196): outside [0.1, 0.9] is 910 + 97 = 1007 of 5735
* (17.56%); retained 4728. The paper's middle cell is inclusive [0.1, 0.9] and
* psdash trims e < 0.1 or e > 0.9, the same region. Exact.
capture noisily {
    use "`rhc_ps'", clear
    psdash support w psA, threshold(0.1) nograph
    assert !missing(r(n_trimmed), r(N_remaining), r(pct_trimmed))
    scalar n_tr = r(n_trimmed)
    scalar n_rem = r(N_remaining)
    scalar pct_b = r(pct_trimmed)
    * exact: psdash vs an independent count on the same scores
    quietly count if psA < 0.1 | psA > 0.9
    assert scalar(n_tr) == r(N)
    assert scalar(n_rem) == 5735 - r(N)
    * Table 2 (p. 196), exact
    assert scalar(n_tr) == 1007
    assert scalar(n_rem) == 4728
    assert !missing(scalar(pct_b)) & !missing(100 * 1007 / 5735)
    assert reldif(scalar(pct_b), 100 * 1007 / 5735) < 1e-9
}
_psdash_crh_record table2_totals_outside_0_1_0_9 `=_rc'

**# Table 2 cells by treatment arm

* Paper Table 2 (p. 196), controls/treated/all:
*   e < 0.1      : 870 /  40 /  910
*   0.1 <= e <= 0.9: 2671 / 2057 / 4728
*   e > 0.9      :  10 /  87 /   97
* Arm-level outside counts come from psdash's generated support indicator; the
* low/high split uses psdash's reported bounds. Every cell exact.
capture noisily {
    use "`rhc_ps'", clear
    psdash support w psA, threshold(0.1) nograph generate(insup)
    assert !missing(r(trim_lower), r(trim_upper))
    scalar lo_b = r(trim_lower)
    scalar hi_b = r(trim_upper)
    assert !missing(scalar(lo_b))
    assert reldif(scalar(lo_b), 0.1) < 1e-12
    assert !missing(scalar(hi_b))
    assert reldif(scalar(hi_b), 0.9) < 1e-12
    assert !missing(insup)

    foreach a in 0 1 {
        quietly count if w == `a' & insup == 0 & psA < scalar(lo_b)
        scalar lo_`a' = r(N)
        quietly count if w == `a' & insup == 1
        scalar mid_`a' = r(N)
        quietly count if w == `a' & insup == 0 & psA > scalar(hi_b)
        scalar hi_`a' = r(N)
        * exact: psdash's indicator equals the independent cut
        quietly count if w == `a' & psA >= 0.1 & psA <= 0.9
        assert scalar(mid_`a') == r(N)
    }
    assert scalar(lo_0) + scalar(mid_0) + scalar(hi_0) == 3551
    assert scalar(lo_1) + scalar(mid_1) + scalar(hi_1) == 2184

    assert scalar(lo_0)  == 870
    assert scalar(lo_1)  == 40
    assert scalar(mid_0) == 2671
    assert scalar(mid_1) == 2057
    assert scalar(hi_0)  == 10
    assert scalar(hi_1)  == 87
    assert scalar(lo_0) + scalar(lo_1) == 910
    assert scalar(mid_0) + scalar(mid_1) == 4728
    assert scalar(hi_0) + scalar(hi_1) == 97
    display as text "observed cells ctrl/trt: <0.1 " scalar(lo_0) "/" scalar(lo_1) "  mid " scalar(mid_0) "/" scalar(mid_1) "  >0.9 " scalar(hi_0) "/" scalar(hi_1)
}
_psdash_crh_record table2_cells_by_arm `=_rc'

**# Crump support indicator agrees with the independent cut

capture noisily {
    use "`rhc_ps'", clear
    psdash support w psA, crump nograph generate(insup)
    assert !missing(r(crump_alpha), insup)
    scalar a_ps = r(crump_alpha)
    quietly count if insup == 1 & psA >= scalar(a_ps) & psA <= 1 - scalar(a_ps)
    scalar n_in = r(N)
    quietly count if insup == 0 & (psA < scalar(a_ps) | psA > 1 - scalar(a_ps))
    scalar n_out = r(N)
    assert scalar(n_in) + scalar(n_out) == 5735
}
_psdash_crh_record crump_indicator_matches_cut `=_rc'

**# Summary

display as text "RESULT: crossval_crump_rhc_published_support tests=$PSDASH_CRH_TESTS pass=$PSDASH_CRH_PASS fail=$PSDASH_CRH_FAIL skip=0"

local final_fail = $PSDASH_CRH_FAIL
local failed "$PSDASH_CRH_FAILED"
macro drop PSDASH_CRH_TESTS PSDASH_CRH_PASS PSDASH_CRH_FAIL PSDASH_CRH_FAILED
_psdash_qa_cleanup
capture log close _all

if `final_fail' {
    display as error "Failed tests:`failed'"
    exit 9
}
