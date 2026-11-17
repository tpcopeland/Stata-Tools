*! crossval_binary_balance_published_imbens2015.do Version 1.0.0  2026/11/17
*! Published reproduction: psdash balance against Imbens (2015) Tables 10 and 16
*! Author: Timothy P Copeland, Karolinska Institutet
* Usage: cd psdash/qa && stata-mp -b do crossval_binary_balance_published_imbens2015.do
*
* Source: Imbens GW. Matching methods in practice: three examples. Journal of
* Human Resources 2015;50(2):373-419, doi:10.3368/jhr.50.2.373. Page numbers
* below are those of the free working-paper version IZA DP 8049 (March 2014);
* the same tables are in NBER w19959. The JHR publisher PDF was not consulted.
*   Table 10 (p. 57): experimental Lalonde data, 260 controls vs 185 trainees.
*   Table 16 (p. 60): non-experimental Lalonde data, 15,992 CPS controls vs the
*                     same 185 trainees.
* Both print mean, s.d. and the normalized difference (nor-dif) per covariate.
* Imbens eq. 5.12: nor-dif = (mean_t - mean_c) / sqrt((s2_t + s2_c) / 2) with
* n-1 variances, which is psdash's raw SMD (treated minus control, pooled SD).
* The printed s.d. columns give the variance ratio s2_t / s2_c.
* Data: nsw_dw.dta and cps_controls.dta, not distributed with the repository
* (provenance, sha256 and the CC BY-NC 2.0 licence with its required
* attribution in data/binary_balance/SOURCE.md; not MIT-licensed). Found by
* _psdash_qa_extdata.do: $STATA_QA_DATA copy, else a public download; exits 77
* (skipped, dependency unavailable) when neither is possible.
*
* Mapping (psdash r(balance) columns): 1 Mean_T, 2 Mean_C, 3 SMD_Raw, 4 VR_Raw.
* psdash needs a weight argument, so wvar(one) with a constant 1 is used and
* only the raw columns are compared to the paper.
*
* Tolerances, all derived from the paper's two-decimal rounding:
*   means and SMD of continuous rows: half a unit in the last printed digit,
*     0.005.
*   SMD of binary rows: 0.005 + 0.0028*|SMD|. psdash (like Austin 2009 and
*     cobalt) uses p(1-p) for a binary variance, Imbens the n-1 sample
*     variance. For N_t = 185 the relative gap in the pooled SD is bounded by
*     sqrt(n_t/(n_t-1)) - 1 = 0.27%. Needed for Table 16 Nodegree: psdash
*     0.90505, printed 0.90; Imbens' own n-1 formula gives 0.9038 from the
*     same data (asserted independently below).
*   VR: psdash VR must lie in [((st-.005)/(sc+.005))^2, ((st+.005)/(sc-.005))^2]
*     implied by the printed s.d.s.
* Table 10 prints the trainee Education s.d. as 1.97, but Table 16 prints 2.01
* for the same 185 trainees and the data give 2.0107; 1.97 is a misprint in
* the paper, so 2.01 is used for that cell.
* KS is not published; it is not asserted here.

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "crossval_binary_balance_published_imbens2015.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

run "`qa_dir'/_psdash_qa_extdata.do"
capture noisily {
    _psdash_qa_extfile binary_balance nsw_dw.dta, len(28598) crc(2283301062) ///
        url("https://users.nber.org/~rdehejia/data/nsw_dw.dta")
    global PSDASH_BBP_NSW `"`r(path)'"'
    global PSDASH_BBP_NSWSRC "`r(source)'"
    _psdash_qa_extfile binary_balance cps_controls.dta, len(705546) crc(2178836444) ///
        url("https://users.nber.org/~rdehejia/data/cps_controls.dta")
    global PSDASH_BBP_CPS `"`r(path)'"'
    global PSDASH_BBP_CPSSRC "`r(source)'"
}
if _rc {
    display as error "FAIL: NSW/CPS integrity check (rc=`=_rc')"
    display as text "RESULT: crossval_binary_balance_published_imbens2015 tests=1 pass=0 fail=1 skip=0"
    _psdash_qa_cleanup
    macro drop PSDASH_BBP_NSW PSDASH_BBP_CPS PSDASH_BBP_NSWSRC PSDASH_BBP_CPSSRC
    capture log close _all
    exit 9
}
if `"$PSDASH_BBP_NSW"' == "" | `"$PSDASH_BBP_CPS"' == "" {
    display as text "SKIP: NSW/CPS data unavailable (no STATA_QA_DATA copy and the public download failed)"
    display as text "RESULT: crossval_binary_balance_published_imbens2015 tests=0 pass=0 fail=0 skip=1 skipped=dependency_unavailable"
    _psdash_qa_cleanup
    macro drop PSDASH_BBP_NSW PSDASH_BBP_CPS PSDASH_BBP_NSWSRC PSDASH_BBP_CPSSRC
    capture log close _all
    exit 77
}
display as text "nsw_dw.dta source: $PSDASH_BBP_NSWSRC; cps_controls.dta source: $PSDASH_BBP_CPSSRC (length and CRC verified)"

global PSDASH_BBP_TESTS = 0
global PSDASH_BBP_PASS = 0
global PSDASH_BBP_FAIL = 0
global PSDASH_BBP_FAILED ""

capture program drop _bbp_record
program define _bbp_record
    args id rc
    global PSDASH_BBP_TESTS = $PSDASH_BBP_TESTS + 1
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_BBP_PASS = $PSDASH_BBP_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_BBP_FAIL = $PSDASH_BBP_FAIL + 1
        global PSDASH_BBP_FAILED "$PSDASH_BBP_FAILED `id'"
    }
end

* Load the sample and build the covariates exactly as Imbens defines them:
* U'74 = (re74 == 0), U'75 = (re75 == 0), E'74 and E'75 in thousands.
capture program drop _bbp_load
program define _bbp_load
    args sample
    if "`sample'" == "cps" {
        tempfile trainees
        quietly use `"$PSDASH_BBP_NSW"', clear
        quietly keep if treat == 1
        quietly save `trainees'
        quietly use `"$PSDASH_BBP_CPS"', clear
        quietly append using `trainees'
    }
    else {
        quietly use `"$PSDASH_BBP_NSW"', clear
    }
    quietly generate byte u74 = (re74 == 0)
    quietly generate byte u75 = (re75 == 0)
    quietly generate double e74 = re74 / 1000
    quietly generate double e75 = re75 / 1000
    quietly generate double one = 1
end

* One covariate row: psdash raw columns (matrix _bbpB, row `row') against the
* printed mean (control mc, treated mt), s.d. (sc, st) and nor-dif (nd).
* kind: b = binary, c = continuous.
capture program drop _bbp_row
program define _bbp_row
    args row kind mc sc mt st nd
    assert rowsof(_bbpB) == 10
    local smd = _bbpB[`row', 3]
    local mT  = _bbpB[`row', 1]
    local mC  = _bbpB[`row', 2]
    local vr  = _bbpB[`row', 4]
    assert !missing(`smd') & !missing(`mT') & !missing(`mC') & !missing(`vr')
    local tol = 0.005
    if "`kind'" == "b" local tol = 0.005 + 0.0028 * abs(`smd')
    * printed nor-dif
    assert abs(`smd' - (`nd')) <= `tol'
    * printed means
    assert abs(`mT' - (`mt')) <= 0.005
    assert abs(`mC' - (`mc')) <= 0.005
    * printed s.d.s imply an interval for s2_t / s2_c
    local lo = ((`st' - 0.005) / (`sc' + 0.005))^2
    local hi = ((`st' + 0.005) / (`sc' - 0.005))^2
    assert `vr' >= `lo' & `vr' <= `hi'
end

* Imbens eq. 5.12 straight from summarize (n-1 variances), independent of
* psdash: must round to the printed mean, s.d. and nor-dif.
capture program drop _bbp_imbens_row
program define _bbp_imbens_row
    args var mc sc mt st nd
    quietly summarize `var' if treat == 1
    local m1 = r(mean)
    local v1 = r(Var)
    quietly summarize `var' if treat == 0
    local m0 = r(mean)
    local v0 = r(Var)
    local ndi = (`m1' - `m0') / sqrt((`v1' + `v0') / 2)
    assert !missing(`ndi') & !missing(`v1') & !missing(`v0')
    assert abs(`ndi' - (`nd')) <= 0.005 + 1e-9
    assert abs(`m1' - (`mt')) <= 0.005 + 1e-9
    assert abs(`m0' - (`mc')) <= 0.005 + 1e-9
    assert abs(sqrt(`v1') - (`st')) <= 0.005 + 1e-9
    assert abs(sqrt(`v0') - (`sc')) <= 0.005 + 1e-9
end

local covs "black hispanic age married nodegree education e74 u74 e75 u75"
local kinds "b b c b b c c b c b"

**# Sample sizes
**## Group sizes match the paper's table headers

capture noisily {
    * Table 10 header: Nc = 260, Nt = 185
    _bbp_load nsw
    quietly count if treat == 1
    assert r(N) == 185
    quietly count if treat == 0
    assert r(N) == 260
    * Table 16 header: Nc = 15,992, Nt = 185
    _bbp_load cps
    quietly count if treat == 1
    assert r(N) == 185
    quietly count if treat == 0
    assert r(N) == 15992
    * psdash sees the same groups
    psdash balance treat, covariates(`covs') wvar(one)
    assert r(N_treated) == 185 & r(N_control) == 15992
}
_bbp_record sample_sizes_match_paper `=_rc'

**# Table 16: non-experimental Lalonde data (CPS controls vs trainees), p. 60
**## psdash raw balance reproduces the printed columns

* args: row kind mc sc mt st nd   (Table 16, p. 60)
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 1 b  .07  .26  .84  .36   2.43
}
_bbp_record t16_black `=_rc'
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 2 b  .07  .26  .06  .24  -0.05
}
_bbp_record t16_hisp `=_rc'
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 3 c 33.23 11.05 25.82 7.16 -0.80
}
_bbp_record t16_age `=_rc'
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 4 b  .71  .45  .19  .39  -1.23
}
_bbp_record t16_married `=_rc'
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    * printed 0.90; psdash 0.90505 (p(1-p) variance), n-1 formula 0.9038
    _bbp_row 5 b  .30  .46  .71  .46   0.90
}
_bbp_record t16_nodegree `=_rc'
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 6 c 12.03  2.87 10.35 2.01 -0.68
}
_bbp_record t16_education `=_rc'
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 7 c 14.02  9.57  2.10 4.89 -1.57
}
_bbp_record t16_e74 `=_rc'
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 8 b  .12  .32  .71  .46   1.49
}
_bbp_record t16_u74 `=_rc'
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 9 c 13.65  9.27  1.53 3.22 -1.75
}
_bbp_record t16_e75 `=_rc'
capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 10 b  .11  .31  .60  .49   1.19
}
_bbp_record t16_u75 `=_rc'

**# Table 10: experimental Lalonde data (260 controls vs trainees), p. 57
**## psdash raw balance reproduces the printed columns

* args: row kind mc sc mt st nd   (Table 10, p. 57)
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 1 b  .83  .38  .84  .36   0.04
}
_bbp_record t10_black `=_rc'
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 2 b  .11  .31  .06  .24  -0.17
}
_bbp_record t10_hisp `=_rc'
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 3 c 25.05  7.06 25.82 7.16  0.11
}
_bbp_record t10_age `=_rc'
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 4 b  .15  .36  .19  .39   0.09
}
_bbp_record t10_married `=_rc'
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 5 b  .83  .37  .71  .46  -0.30
}
_bbp_record t10_nodegree `=_rc'
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    * Table 10 prints the trainee s.d. as 1.97, a misprint (Table 16: 2.01,
    * data: 2.0107); 2.01 is used. The printed nor-dif 0.14 is unaffected.
    _bbp_row 6 c 10.09  1.61 10.35 2.01  0.14
}
_bbp_record t10_education `=_rc'
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 7 c  2.11  5.69  2.10 4.89 -0.00
}
_bbp_record t10_e74 `=_rc'
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 8 b  .75  .43  .71  .46  -0.09
}
_bbp_record t10_u74 `=_rc'
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 9 c  1.27  3.10  1.53 3.22  0.08
}
_bbp_record t10_e75 `=_rc'
capture noisily {
    _bbp_load nsw
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    _bbp_row 10 b  .68  .47  .60  .49 -0.18
}
_bbp_record t10_u75 `=_rc'

**# The vendored data are the paper's data
**## Imbens eq. 5.12 computed with summarize (no psdash) rounds to every printed cell

capture noisily {
    _bbp_load cps
    * args: var mc sc mt st nd   (Table 16, p. 60)
    _bbp_imbens_row black     .07  .26  .84  .36   2.43
    _bbp_imbens_row hispanic  .07  .26  .06  .24  -0.05
    _bbp_imbens_row age     33.23 11.05 25.82 7.16 -0.80
    _bbp_imbens_row married   .71  .45  .19  .39  -1.23
    _bbp_imbens_row nodegree  .30  .46  .71  .46   0.90
    _bbp_imbens_row education 12.03 2.87 10.35 2.01 -0.68
    _bbp_imbens_row e74     14.02  9.57  2.10 4.89 -1.57
    _bbp_imbens_row u74       .12  .32  .71  .46   1.49
    _bbp_imbens_row e75     13.65  9.27  1.53 3.22 -1.75
    _bbp_imbens_row u75       .11  .31  .60  .49   1.19
}
_bbp_record t16_data_match_printed_independent `=_rc'

capture noisily {
    _bbp_load nsw
    * args: var mc sc mt st nd   (Table 10, p. 57; trainee Education s.d. 2.01)
    _bbp_imbens_row black     .83  .38  .84  .36   0.04
    _bbp_imbens_row hispanic  .11  .31  .06  .24  -0.17
    _bbp_imbens_row age     25.05  7.06 25.82 7.16  0.11
    _bbp_imbens_row married   .15  .36  .19  .39   0.09
    _bbp_imbens_row nodegree  .83  .37  .71  .46  -0.30
    _bbp_imbens_row education 10.09 1.61 10.35 2.01 0.14
    _bbp_imbens_row e74      2.11  5.69  2.10 4.89 -0.00
    _bbp_imbens_row u74       .75  .43  .71  .46  -0.09
    _bbp_imbens_row e75      1.27  3.10  1.53 3.22  0.08
    _bbp_imbens_row u75       .68  .47  .60  .49  -0.18
}
_bbp_record t10_data_match_printed_independent `=_rc'

**# Weight plumbing
**## A constant weight leaves the adjusted columns equal to the raw columns

capture noisily {
    _bbp_load cps
    quietly psdash balance treat, covariates(`covs') wvar(one)
    matrix _bbpB = r(balance)
    forvalues i = 1/10 {
        assert !missing(_bbpB[`i',3]) & !missing(_bbpB[`i',8])
        assert abs(_bbpB[`i',3] - _bbpB[`i',8]) < 1e-9
        assert !missing(_bbpB[`i',5]) & !missing(_bbpB[`i',10])
        assert abs(_bbpB[`i',5] - _bbpB[`i',10]) < 1e-9
        assert !missing(_bbpB[`i',1]) & !missing(_bbpB[`i',6])
        assert abs(_bbpB[`i',1] - _bbpB[`i',6]) < 1e-9
        assert !missing(_bbpB[`i',2]) & !missing(_bbpB[`i',7])
        assert abs(_bbpB[`i',2] - _bbpB[`i',7]) < 1e-9
    }
}
_bbp_record unit_weight_adjusted_equals_raw `=_rc'

capture matrix drop _bbpB
display as text _n "RESULT: crossval_binary_balance_published_imbens2015 tests=$PSDASH_BBP_TESTS pass=$PSDASH_BBP_PASS fail=$PSDASH_BBP_FAIL skip=0"

local final_fail = $PSDASH_BBP_FAIL
local failed "$PSDASH_BBP_FAILED"
macro drop PSDASH_BBP_TESTS PSDASH_BBP_PASS PSDASH_BBP_FAIL PSDASH_BBP_FAILED PSDASH_BBP_NSW PSDASH_BBP_CPS PSDASH_BBP_NSWSRC PSDASH_BBP_CPSSRC
_psdash_qa_cleanup
capture log close _all

if `final_fail' {
    display as error "Failed tests:`failed'"
    exit 9
}
