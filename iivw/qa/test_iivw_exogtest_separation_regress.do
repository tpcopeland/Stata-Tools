*! test_iivw_exogtest_separation_regress.do -- certified regression cells for the exogtest separation check
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Mata-level cells for _iivw_cox_recession (_iivw_mlib.ado), the monotone-
* likelihood check behind iivw_exogtest. Each R cell feeds rows whose answer
* was decided EXACTLY in rational arithmetic (a verified direction a with
* Z a >= 0, some > 0, for "separated"; a verified y > 0 with Z'y = 0 for "not
* separated"; Z the (at-risk minus event) pair rows), and asserts the status
* equals that truth: 1 for separated, 0 for not. "Did not settle" (2) fails a
* cell. The certificate behind each cell is quoted in its comment.
*
* R01-R06 and R11-R13 are the rows that gave a wrong or unsettled answer
* before the exact certificates (heavy 205 and 594 false positives, a
* collinear false positive and three misses, heavy cases 8 and 334, weak2).
* D01 asserts the status does not depend on Stata's sort jumbler. R14 and
* V01 pin exact power-of-two scalings, G01 the search route on its own, U05
* and U06 the exact powers of two and the O(rows) Stiemke residual. R07-R08 are rank-deficient pair rows (exact
* column dependence), R09-R10 problems too large for the exhaustive small-case
* route, so the search and its certificates decide them. U cells pin the
* error-free arithmetic the certificates rest on.
*
* Optional argument: the path of an _iivw_mlib.ado to load instead of the
* installed one (to show a cell red on an older version).
version 16.0
clear all
set more off
set varabbrev off
args mlib_override
local qa_dir "`c(pwd)'"
do _iivw_qa_common.do
iivw_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local mlib_fn `"`mlib_override'"'
if `"`mlib_fn'"' == "" {
    quietly findfile _iivw_mlib.ado
    local mlib_fn "`r(fn)'"
}

**# U00: the library compiles under matastrict
* Suites that run before iivw_exogtest can leave matastrict on, and the
* library is compiled on first use; an undeclared variable then aborts the
* command with r(3000).
local ++test_count
local strict0 = c(matastrict)
capture noisily {
    mata: mata clear
    mata: mata set matastrict on
    run `"`mlib_fn'"'
}
local rc_strict = _rc
mata: mata set matastrict `strict0'
if `rc_strict' == 0 {
    display as result "  PASS: U00 _iivw_mlib.ado compiles under matastrict"
    local ++pass_count
}
else {
    display as error "  FAIL: U00 strict compile (rc `rc_strict')"
    local ++fail_count
    local failed "`failed' U00"
    mata: mata clear
    run `"`mlib_fn'"'
}

* Status and term flags of the check on t0, t, d and the touse marker tu.
capture program drop _sepr_check
program define _sepr_check, rclass
    version 16.0
    syntax varlist(numeric)
    local out ""
    mata: st_local("out", invtokens(strofreal(_iivw_cox_recession("t0", "t", "d", "`varlist'", "tu"))))
    gettoken s flags : out
    return scalar status = `s'
    return local flags = strtrim("`flags'")
end

**# R01: heavy case 205 (LEDGER defect 1), not separated
* Exact: cdd finds no direction; an exact y > 0 with Z'y = 0 exists. The old
* check accepted a = (1, 4e-9, -2e-9): pair (row 7 - row 4) has raw slack
* -6e-9, about -1e-17 once unit-normalised, inside a 1e-12 allowance.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    2 4 1 0 0 1
    2 5 1 1 0 0
    1 3 0 1 2 2
    0 1 1 0 2 1
    0 4 0 1 2 0
    0 1 0 2 0 0
    0 3 1 2 -1e9 2
    2 7 1 1 1 1
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 0
}
if _rc == 0 {
    display as result "  PASS: R01 heavy 205 (1e9 lag, -1e-17 normalised slack): finite (0)"
    local ++pass_count
}
else {
    display as error "  FAIL: R01 heavy 205 (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R01"
}

**# R02: heavy case 594, not separated (a -1e12 value)
* Exact: no direction (cdd); exact Stiemke vector.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    1 3 1 2 2 1
    2 6 0 2 3 2
    0 2 1 1 1 1
    0 2 1 -1e12 2 1
    1 2 1 2 2 2
    1 5 0 2 2 1
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 0
}
if _rc == 0 {
    display as result "  PASS: R02 heavy 594 (-1e12 value): finite (0)"
    local ++pass_count
}
else {
    display as error "  FAIL: R02 heavy 594 (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R02"
}

**# R03: collinear case 74, not separated (x2 = x1 + 1e-7 k)
* Exact: no direction; exact Stiemke vector with min y = 0.237.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    0 2 0 0 2e-07 1
    2 5 1 1 1 1
    1 5 1 2 2.0000002 2
    1 6 1 0 0 1
    1 3 1 0 1e-07 2
    0 5 0 1 1 1
    0 2 1 1 1 0
    0 1 1 0 2e-07 2
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 0
}
if _rc == 0 {
    display as result "  PASS: R03 collinear 74 (old false positive): finite (0)"
    local ++pass_count
}
else {
    display as error "  FAIL: R03 collinear 74 (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R03"
}

**# R04: collinear case 27, separated at the last bit of the data
* Exact: a = (1, -1, 0) (up to sign) with Z a >= 0, one row tight and two
* strict; the strict slacks are 2.2e-16, the rounding of 2.0000001 - 1e-07.
* The old check summed the three pair rows to ~1e-16 and called it
* membership. x3 is constant, so no verified direction can move it.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    0 1 1 1 1.0000001 0
    0 5 1 2 2.0000001 0
    0 3 0 0 1e-07 0
    0 2 1 2 2.0000001 0
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 1
    assert word("`r(flags)'", 3) == "0"
}
if _rc == 0 {
    display as result "  PASS: R04 collinear 27 (old miss): separated (1), x3 not flagged"
    local ++pass_count
}
else {
    display as error "  FAIL: R04 collinear 27 (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R04"
}

**# R05: heavy case 8, separated (a 1e12 value)
* Exact: a = (-1e12, -1, -2), three rows tight, four strict.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    0 4 0 2 2 1
    0 4 1 2 0 2
    0 3 1 0 0 1e12
    0 3 1 2 1 2
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 1
}
if _rc == 0 {
    display as result "  PASS: R05 heavy 8 (1e12 value): separated (1)"
    local ++pass_count
}
else {
    display as error "  FAIL: R05 heavy 8 (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R05"
}

**# R06: weak2, N = 10,000, delta = 1: separated
* x2 = x1 except one row censored at the last event time with x2 = x1 + 1.
* Exact: a = (-1, 1): every pair's slack is exactly 0 except those with the
* censored row at risk, which are +1 (it is at risk at every event time).
* Both terms move along a.
local ++test_count
capture noisily {
    clear
    quietly set obs 10001
    gen double t0 = 0
    gen double t = cond(_n == 10001, 10000, _n)
    gen byte d = _n <= 10000
    set seed 5
    gen double x1 = rnormal()
    gen double x2 = x1 + (_n == 10001)
    gen byte tu = 1
    _sepr_check x1 x2
    assert r(status) == 1
    assert "`r(flags)'" == "1 1"
}
if _rc == 0 {
    display as result "  PASS: R06 weak2 (N = 10,000, delta = 1): separated (1), both terms"
    local ++pass_count
}
else {
    display as error "  FAIL: R06 weak2 (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R06"
}

**# R07: rank-deficient pair rows, not separated (ints case 8)
* The pair rows span 2 of 3 dimensions exactly. Exact: no direction;
* exact Stiemke vector.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    0 5 0 1 1 0
    0 3 1 1 2 0
    0 5 1 1 1 0
    0 3 1 0 0 1
    0 1 1 1 1 0
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 0
}
if _rc == 0 {
    display as result "  PASS: R07 rank-deficient, not separated: finite (0)"
    local ++pass_count
}
else {
    display as error "  FAIL: R07 rank-deficient not separated (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R07"
}

**# R08: rank-deficient pair rows, separated (ints case 147)
* Three pair rows of rank 2. Exact: a verified direction exists (cdd).
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    0 4 1 1 1 1
    2 5 1 2 2 1
    1 2 0 1 2 0
    2 7 0 0 1 2
    1 3 0 0 0 2
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 1
}
if _rc == 0 {
    display as result "  PASS: R08 rank-deficient, separated: separated (1)"
    local ++pass_count
}
else {
    display as error "  FAIL: R08 rank-deficient separated (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R08"
}

**# R09-R10: problems beyond the exhaustive small-case route
* data/iivw_sep_med_cases.csv: 65 and 66 rows, 1296 and 1503 distinct pair
* rows (more than the 400 the exact enumeration takes), x3 with a 1e9 value.
* Case 1: x1 = x2 - t, exact a = (-1, 1, 0). Case 2: x2 = x1 except on a few
* rows; exact Stiemke vector (LP plus exact projection).
local ++test_count
capture noisily {
    import delimited using "`qa_dir'/data/iivw_sep_med_cases.csv", clear asdouble
    quietly keep if case == 1
    assert sep == 1
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 1
}
if _rc == 0 {
    display as result "  PASS: R09 large separated case (1e9 value): separated (1)"
    local ++pass_count
}
else {
    display as error "  FAIL: R09 large separated case (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R09"
}

local ++test_count
capture noisily {
    import delimited using "`qa_dir'/data/iivw_sep_med_cases.csv", clear asdouble
    quietly keep if case == 2
    assert sep == 0
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 0
}
if _rc == 0 {
    display as result "  PASS: R10 large non-separated case (1e9 value): finite (0)"
    local ++pass_count
}
else {
    display as error "  FAIL: R10 large non-separated case (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R10"
}

**# R11: collinear case 42, separated (an old miss)
* Exact: a = (-1.00000005, 1, 0) (rational), four rows tight, two strict.
* The search stops at membership; only the Stiemke certificate, which must
* fail here, keeps that from being returned as 0.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    0 5 0 1 1.0000002 0
    0 4 0 2 2.0000002 2
    0 4 1 0 1e-07 2
    0 4 1 2 2.0000002 1
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 1
}
if _rc == 0 {
    display as result "  PASS: R11 collinear 42 (old miss): separated (1)"
    local ++pass_count
}
else {
    display as error "  FAIL: R11 collinear 42 (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R11"
}

**# R12: heavy case 334, separated (a 1e7 value)
* Exact: a = (-1, 2, 19999996), three rows tight, three strict.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    0 2 1 2 2 2
    0 5 1 2 1e7 1
    0 1 1 1 1 2
    0 5 0 0 1 2
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 1
}
if _rc == 0 {
    display as result "  PASS: R12 heavy 334 (1e7 value): separated (1)"
    local ++pass_count
}
else {
    display as error "  FAIL: R12 heavy 334 (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R12"
}

**# R13: collinear case 427, separated (the dead gray route)
* Exact: a verified direction (cdd). In the gray zone the candidate's error
* allowance exceeded every component, the all-zero vector "verified" with no
* strict slack and the old search returned 0. A zero candidate must never
* certify anything.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2 x3)
    2 4 1 1 1 0
    2 4 1 0 2e-09 2
    1 5 0 0 1e-09 1
    1 5 1 1 1.000000001 1
    0 2 1 2 2 2
    end
    gen byte tu = 1
    _sepr_check x1 x2 x3
    assert r(status) == 1
}
if _rc == 0 {
    display as result "  PASS: R13 collinear 427 (old gray-zone miss): separated (1)"
    local ++pass_count
}
else {
    display as error "  FAIL: R13 collinear 427 (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R13"
}

**# D01: the verdict does not depend on the sort jumbler
* Cases whose old verdict changed with sortrngstate (ties in the risk-set
* sweep order were broken at random): collinP 287 (not separated) alternated
* 1/0, heavy 443, 606, 660 (not separated) moved between 0 and 2, collinP 164
* (separated) between 1 and 0. Under sortrngstate 1-8 each must return its
* certified status every time.
local ++test_count
capture noisily {
    clear
    input byte cs double(t0 t d x1 x2 x3)
    1 0 5 1 0 0 0
    1 0 1 1 1 0 0
    1 0 3 1 0 2.000000002 2
    1 0 4 0 1 1 1
    1 0 1 1 2 2.000000002 2
    1 0 3 1 2 1.000000002 1
    1 0 1 1 2 0 0
    2 0 1 1 2 2 2
    2 1 6 1 2 2.0000002 2
    2 2 4 1 2 1e-07 0
    2 2 5 1 1 2.0000002 2
    2 2 5 1 0 1.0000002 1
    3 0 3 1 1 1 0
    3 0 1 1 1 1 0
    3 0 4 0 1e12 0 0
    3 0 4 0 0 1 0
    3 0 2 0 2 3 0
    3 0 4 1 0 0 0
    4 0 4 1 0 0 0
    4 0 5 1 0 0 0
    4 0 2 1 1 0 0
    4 0 1 1 0 1 0
    4 0 5 1 1 -1e9 0
    4 0 3 1 1 1 0
    4 0 2 1 0 2 0
    4 0 2 1 0 1 0
    5 0 3 0 0 0 2
    5 0 1 1 1e12 2 0
    5 0 1 1 1 1 0
    5 0 3 1 0 0 2
    5 0 4 1 0 0 0
    5 0 2 1 0 0 0
    5 0 2 1 0 0 1
    5 0 1 1 2 2 2
    end
    gen byte tu = 0
    local truth "0 1 0 0 0"
    local xs1 "x1 x2 x3"
    local xs2 "x1 x2 x3"
    local xs3 "x1 x2"
    local xs4 "x1 x2"
    local xs5 "x1 x2 x3"
    local bad ""
    forvalues r = 1/8 {
        set sortrngstate `r'
        forvalues k = 1/5 {
            quietly replace tu = (cs == `k')
            _sepr_check `xs`k''
            if r(status) != real(word("`truth'", `k')) local bad "`bad' case`k'@`r'=`=r(status)'"
        }
    }
    display "D01 mismatches:`bad'"
    assert "`bad'" == ""
}
if _rc == 0 {
    display as result "  PASS: D01 certified status identical under sortrngstate 1-8"
    local ++pass_count
}
else {
    display as error "  FAIL: D01 sort-jumbler dependence (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D01"
}

**# R14: the 2^40-scaled heavy case (exact power-of-two scalings)
* Rows (t0 t d x1 x2): (0 5 1 2 2), (0 5 0 2 1), (0 1 0 0 0), (0 5 1 -1e9 1),
* x1 and x2 multiplied by 2^k. Exact: a = (1, -(1e9 + 2)) verifies at every
* k (scaling both columns by one power of two changes no sign), so the truth
* is separated. Mata's 2^k is not exact for most k; scaling rows by it left
* the exact cross products not orthogonal, the exhaustive route found no
* ray and returned 0 at k = 40, 60, 90. Factors here are built by repeated
* doubling or halving (exact).
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1 x2)
    0 5 1 2 2
    0 5 0 2 1
    0 1 0 0 0
    0 5 1 -1e9 1
    end
    gen byte tu = 1
    tempfile r14
    quietly save `r14'
    local bad ""
    foreach k in 0 30 40 60 90 -60 -90 {
        use `r14', clear
        scalar f = 1
        forvalues i = 1/`=abs(`k')' {
            if `k' > 0 scalar f = f * 2
            else scalar f = f / 2
        }
        quietly replace x1 = x1 * scalar(f)
        quietly replace x2 = x2 * scalar(f)
        _sepr_check x1 x2
        if r(status) != 1 local bad "`bad' k`k'=`=r(status)'"
    }
    display "R14 mismatches:`bad'"
    assert "`bad'" == ""
}
if _rc == 0 {
    display as result "  PASS: R14 2^k-scaled heavy case separated (1) at every k"
    local ++pass_count
}
else {
    display as error "  FAIL: R14 power-of-two scalings (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R14"
}

**# V01: power-of-two column scalings of the certified heavy and cont corpora
* Multiplying a column by an exact power of two changes no slack sign, so the
* certified truth is unchanged by construction. Six scalings (exponents per
* column x1-x4), including the four that produced wrong finite verdicts:
* (30,30,30,30), (40,40,40,40), (60,-60,20,-20), (-90,30,0,90). Zero wrong
* verdicts and zero status 2 on every one.
local ++test_count
capture noisily {
    import delimited using "`qa_dir'/data/exogtest_corpus_exp.csv", clear
    quietly keep if inlist(corpus, "g_heavy", "g_cont")
    sort corpus case
    gen long cid = _n
    local ncs = _N
    forvalues c = 1/`ncs' {
        local vp`c' = p[`c']
        local vs`c' = sep[`c']
    }
    tempfile vexp
    quietly save `vexp'
    import delimited using "`qa_dir'/data/exogtest_corpus_cases.csv", clear asdouble
    * Keep the file's row order within a case: the search's path (not its
    * soundness) depends on it.
    gen long ord = _n
    quietly merge m:1 corpus case using `vexp', keep(match) keepusing(cid) nogenerate
    sort cid ord
    tempfile vcas
    quietly save `vcas'
    local bad ""
    local nrun = 0
    foreach sc in "30 30 30 30" "40 40 40 40" "60 -60 20 -20" "-90 30 0 90" "-40 70 -10 25" "90 90 -90 -90" {
        use `vcas', clear
        * An integer-valued column imports as byte or int, and replace would
        * promote it to float; scale in double only.
        recast double x1 x2 x3 x4
        forvalues k = 1/4 {
            local e : word `k' of `sc'
            scalar f = 1
            forvalues i = 1/`=abs(`e')' {
                if `e' > 0 scalar f = f * 2
                else scalar f = f / 2
            }
            quietly replace x`k' = x`k' * scalar(f)
        }
        gen byte tu = 0
        forvalues c = 1/`ncs' {
            quietly replace tu = (cid == `c')
            local xs = cond(`vp`c''==1, "x1", cond(`vp`c''==2, "x1 x2", cond(`vp`c''==3, "x1 x2 x3", "x1 x2 x3 x4")))
            _sepr_check `xs'
            local ++nrun
            if r(status) != `vs`c'' local bad "`bad' (`sc')#`c'=`=r(status)'"
        }
    }
    display "V01 runs: `nrun'; mismatches:`bad'"
    assert `nrun' == 6 * `ncs' & `ncs' == 133
    assert "`bad'" == ""
}
if _rc == 0 {
    display as result "  PASS: V01 scaled heavy/cont corpora: every verdict equals the certificate"
    local ++pass_count
}
else {
    display as error "  FAIL: V01 scaled corpora (rc `=_rc')"
    local ++fail_count
    local failed "`failed' V01"
}

**# G01: the search and its certificates alone (route 1) settle what they settled
* _iivw_cox_recession(..., 1) skips the O(rows) Stiemke shortcut and the
* exhaustive small-problem route, so the floating-point search (its slack
* threshold, slack error bound and gray zone) decides how often the check
* settles on its own, as it does on large data. On the certified corpus
* (every case, all its columns): no wrong verdict, and at most 45 unsettled
* (measured 45 at this version; weakening the slack error bound to 1e-3
* gives 49). Four cases this route settles are pinned exactly. The bound is a
* regression bound on efficiency, not on soundness: lower it when the search
* improves.
local ++test_count
capture noisily {
    import delimited using "`qa_dir'/data/exogtest_corpus_exp.csv", clear
    sort corpus case
    gen long cid = _n
    local ncs = _N
    forvalues c = 1/`ncs' {
        local gp`c' = p[`c']
        local gs`c' = sep[`c']
        local gn`c' = corpus[`c'] + "_" + string(case[`c'])
    }
    tempfile gexp
    quietly save `gexp'
    import delimited using "`qa_dir'/data/exogtest_corpus_cases.csv", clear asdouble
    * Keep the file's row order within a case: the search's path (not its
    * soundness) depends on it.
    gen long ord = _n
    quietly merge m:1 corpus case using `gexp', keep(match) keepusing(cid) nogenerate
    sort cid ord
    gen byte tu = 0
    local nwrong = 0
    local nunset = 0
    forvalues c = 1/`ncs' {
        quietly replace tu = (cid == `c')
        local xs = cond(`gp`c''==1, "x1", cond(`gp`c''==2, "x1 x2", cond(`gp`c''==3, "x1 x2 x3", "x1 x2 x3 x4")))
        mata: st_local("st", strofreal(_iivw_cox_recession("t0", "t", "d", "`xs'", "tu", 1)[1]))
        if "`st'" == "2" local ++nunset
        else if "`st'" != "`gs`c''" local ++nwrong
    }
    * Pinned: settled by this route, certified finite.
    local pin ""
    foreach pc in "b_gap_293 x1 x2" "g_heavyP_443 x1 x2" "g_heavyP_660 x1 x2 x3" "g_collinP_481 x1 x2 x3" {
        gettoken nm vars : pc
        local k = 0
        forvalues c = 1/`ncs' {
            if "`gn`c''" == "`nm'" local k = `c'
        }
        assert `k' > 0
        quietly replace tu = (cid == `k')
        mata: st_local("st", strofreal(_iivw_cox_recession("t0", "t", "d", "`vars'", "tu", 1)[1]))
        if "`st'" != "0" local pin "`pin' `nm'=`st'"
    }
    display "G01 cases `ncs', wrong `nwrong', unsettled `nunset'; pinned mismatches:`pin'"
    assert `ncs' == 1209
    assert `nwrong' == 0
    assert `nunset' <= 45
    assert "`pin'" == ""
}
if _rc == 0 {
    display as result "  PASS: G01 search route alone: no wrong verdict, settle rate held"
    local ++pass_count
}
else {
    display as error "  FAIL: G01 search route settle rate (rc `=_rc')"
    local ++fail_count
    local failed "`failed' G01"
}

**# R15: separated through an integer combination whose slacks cancel to the last bits
* data/iivw_sep_intdir_cases.csv: three cases from a near-cancellation corpus
* (one column is a small-integer combination of the others up to rounding:
* p = 4, 44 distinct pair rows; p = 3, 130; p = 3, 108), each certified
* separated by an exact direction (cdd). Too many rows for the exhaustive
* route; a floating candidate cannot hit the exact direction, so only the
* integer rounding of the candidate settles them.
local ++test_count
capture noisily {
    import delimited using "`qa_dir'/data/iivw_sep_intdir_cases.csv", clear asdouble
    gen byte tu = 0
    local bad ""
    forvalues c = 1/3 {
        quietly replace tu = (case == `c')
        quietly summarize p if case == `c', meanonly
        local pc = r(mean)
        quietly summarize sep if case == `c', meanonly
        assert r(mean) == 1
        local xs = cond(`pc'==2, "x1 x2", cond(`pc'==3, "x1 x2 x3", "x1 x2 x3 x4"))
        _sepr_check `xs'
        if r(status) != 1 local bad "`bad' case`c'=`=r(status)'"
    }
    display "R15 mismatches:`bad'"
    assert "`bad'" == ""
}
if _rc == 0 {
    display as result "  PASS: R15 integer-combination separations: separated (1)"
    local ++pass_count
}
else {
    display as error "  FAIL: R15 integer-combination separations (rc `=_rc')"
    local ++fail_count
    local failed "`failed' R15"
}

**# U01: error-free transformations are exact in Mata
* (1 + 2^-30)^2 = 1 + 2^-29 + 2^-60: TwoProduct must return the 2^-60.
* 0.1 + 0.2 rounds up by exactly 2^-55 (as doubles).
local ++test_count
capture noisily {
    mata: qp = .
    mata: qe = .
    mata: _iivw_cr_tprod(1 + 2^-30, 1 + 2^-30, qp, qe)
    mata: st_numscalar("q_p", qp - 1)
    mata: st_numscalar("q_e", qe)
    assert scalar(q_p) == 2^-29 & scalar(q_e) == 2^-60
    mata: qs = .
    mata: _iivw_cr_tsum(0.1, 0.2, qs, qe)
    mata: st_numscalar("q_e", qe)
    assert scalar(q_e) == -2^-55
}
if _rc == 0 {
    display as result "  PASS: U01 TwoProduct and TwoSum exact"
    local ++pass_count
}
else {
    display as error "  FAIL: U01 error-free transformations (rc `=_rc')"
    local ++fail_count
    local failed "`failed' U01"
}

**# U02: exact signs of sums the floating sum gets wrong
* Rows (exact sums): 1 + 1e-30 - 1 (> 0, float 0), 1 - 1 (0), -2^-60 + 1 - 1
* (< 0), 1e16 + 1 - 1e16 (> 0, float 0 or 2), 3 - 1 - 2 (0).
local ++test_count
capture noisily {
    mata: qs = _iivw_cr_xsign((1, 1e-30, -1 \ 1, -1, 0 \ -2^-60, 1, -1 \ 1e16, 1, -1e16 \ 3, -1, -2))
    mata: st_local("qsg", invtokens(strofreal(qs')))
    assert "`qsg'" == "1 0 -1 1 0"
}
if _rc == 0 {
    display as result "  PASS: U02 exact sign of sums with cancellation"
    local ++pass_count
}
else {
    display as error "  FAIL: U02 exact sign (rc `=_rc')"
    local ++fail_count
    local failed "`failed' U02"
}

**# U03: exact cross product of two rows, and an exact slack below a double
* Rows (1, 2, 3) and (4, 5, 6) are scaled by 2^-1 and 2^-2, so the cross
* product is (-3, 6, -3) / 8 componentwise (each component its own value).
* The row (1 + 2^-60, 1) against a = (1, -1) has slack 2^-60: the TwoSum
* remainder of the row must enter the sign.
local ++test_count
capture noisily {
    mata: qv = rowsum(_iivw_cr_gcp((1, 2, 3 \ 4, 5, 6), J(2, 3, 0)))'
    mata: st_local("qcp", invtokens(strofreal(qv)))
    assert "`qcp'" == "-.375 .75 -.375"
    mata: qs = _iivw_cr_xslack((1, 1 \ 1, 1 \ 1, 1), (2^-60, 0 \ -2^-60, 0 \ 0, 0), (1 \ -1))
    mata: st_local("qsg", invtokens(strofreal(qs')))
    assert "`qsg'" == "1 -1 0"
}
if _rc == 0 {
    display as result "  PASS: U03 exact cross product and sub-ulp slack signs"
    local ++pass_count
}
else {
    display as error "  FAIL: U03 exact cross product / slack (rc `=_rc')"
    local ++fail_count
    local failed "`failed' U03"
}

**# U04: exact linear-predictor enclosures
* Row (1, 2^-60) with a = (1, 1): eta = 1 + 2^-60 is not one double, so the
* row is not marked exact and its enclosure must contain 1 + 2^-60 (strictly
* above 1). Row (1, 0): eta = 1 exactly, enclosure the point 1.
local ++test_count
capture noisily {
    mata: qT = .
    mata: qlo = .
    mata: qhi = .
    mata: qex = .
    mata: qbad = .
    mata: _iivw_cr_xeta((1, 2^-60 \ 1, 0), (1 \ 1), qT, qlo, qhi, qex, qbad)
    mata: st_local("qex", invtokens(strofreal(qex')))
    mata: st_numscalar("q_hi1", qhi[1] - 1)
    mata: st_numscalar("q_lo1", qlo[1] - 1)
    mata: st_local("qpt", strofreal(qlo[2] == 1 & qhi[2] == 1))
    assert "`qex'" == "0 1"
    assert scalar(q_hi1) >= 2^-60 & scalar(q_lo1) <= 0
    assert "`qpt'" == "1"
}
if _rc == 0 {
    display as result "  PASS: U04 linear-predictor enclosures contain the exact value"
    local ++pass_count
}
else {
    display as error "  FAIL: U04 enclosures (rc `=_rc')"
    local ++fail_count
    local failed "`failed' U04"
}

**# U05: exact powers of two for every exponent
* _iivw_cr_pow2(k) against a reference built by repeated doubling from 1 (k
* up to 1023) and halving from 1 (k down to -1074, through the subnormals);
* both are exact. Also the hex of 2^-1074, 2^-69 and 2^1023, and the
* constants 2^-53 and 2^-80 the code writes with Mata's ^.
local ++test_count
capture noisily {
    mata: qr = J(2098, 1, .)
    mata: qv = 1
    mata: for (qk = 0; qk <= 1023; qk++) { qr[qk + 1075] = qv; qv = qv * 2; }
    mata: qv = 1
    mata: for (qk = 0; qk >= -1074; qk--) { qr[qk + 1075] = qv; qv = qv / 2; }
    mata: st_local("qbad", strofreal(sum(_iivw_cr_pow2((-1074::1023)) :!= qr)))
    assert "`qbad'" == "0"
    mata: st_local("qh", strofreal(_iivw_cr_pow2(-1074), "%21x") + " " + strofreal(_iivw_cr_pow2(-69), "%21x") + " " + strofreal(_iivw_cr_pow2(1023), "%21x"))
    assert "`qh'" == "+0.0000000000001X-3ff +1.0000000000000X-045 +1.0000000000000X+3ff"
    mata: st_local("qc", strofreal((2^-53 == qr[-53 + 1075]) & (2^-80 == qr[-80 + 1075])))
    assert "`qc'" == "1"
}
if _rc == 0 {
    display as result "  PASS: U05 exact 2^k for k = -1074..1023"
    local ++pass_count
}
else {
    display as error "  FAIL: U05 exact powers of two (rc `=_rc')"
    local ++fail_count
    local failed "`failed' U05"
}

**# U06: the O(rows) Stiemke residual against a sum over every pair
* For integer rows and the grid predictor eta = k 2^-12 (k integers, |eta| <
* 1/2), sum over every (event i, at-risk j) pair of (1 + eta_j - eta_i)
* (x_j - x_i) must equal sum_r C_r x_r with C_r from _iivw_cr_dyadcoef. The
* reference builds risk sets directly (t0 < t_event <= t) and sums the pairs;
* every number is an integer times 2^-12 below 2^40, so both sides are exact.
* Delayed entry, tied event times and censored rows are included.
local ++test_count
capture noisily {
    clear
    quietly set obs 40
    set seed 606
    gen double t0 = floor(runiform() * 3)
    gen double t = t0 + 1 + floor(runiform() * 6)
    gen double d = runiform() < 0.7
    gen double x1 = floor(runiform() * 9) - 4
    gen double x2 = floor(runiform() * 21) - 10
    gen double k = floor(runiform() * 3000) - 1500
    mata: qT0 = st_data(., "t0"); qT = st_data(., "t"); qD = st_data(., "d")
    mata: qX = st_data(., ("x1", "x2")); qk = st_data(., "k")
    mata: qev = uniqrows(select(qT, qD :!= 0))
    mata: qlo = _iivw_cr_count_le(qev, qT0) :+ 1; qhi = _iivw_cr_count_le(qev, qT)
    mata: qPD = _iivw_cr_events(qD, qhi, rows(qev))
    mata: qC = _iivw_cr_dyadcoef(qlo, qhi, qPD, qk, 4096)
    mata: qlhs = colsum(qX :* qC) / 4096
    mata: qrhs = J(1, 2, 0)
    mata: for (qi = 1; qi <= rows(qT); qi++) { if (qD[qi] != 0) { for (qj = 1; qj <= rows(qT); qj++) { if (qT0[qj] < qT[qi] & qT[qi] <= qT[qj]) qrhs = qrhs + (1 + (qk[qj] - qk[qi]) / 4096) * (qX[qj, .] - qX[qi, .]); } } }
    mata: st_local("qeq", strofreal(qlhs == qrhs & !hasmissing(qC)))
    mata: st_local("qnz", strofreal(any(qrhs :!= 0)))
    assert "`qeq'" == "1"
    assert "`qnz'" == "1"
}
if _rc == 0 {
    display as result "  PASS: U06 O(rows) Stiemke residual equals the pair sum exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: U06 dyadic coefficients (rc `=_rc')"
    local ++fail_count
    local failed "`failed' U06"
}

**# U07: the O(rows) identity refuses an event row outside its own risk set
* The identity of U06 pairs each event with its risk set and assumes the
* event row is in it (t0 < t, which stset guarantees). An event row with
* t0 = t breaks that; the coefficients must then come back missing (no
* certificate) rather than a residual for a different pair set.
local ++test_count
capture noisily {
    clear
    input double(t0 t d x1)
    0 2 1 1
    0 3 1 2
    3 3 1 0
    0 4 0 5
    end
    mata: qT0 = st_data(., "t0"); qT = st_data(., "t"); qD = st_data(., "d")
    mata: qev = uniqrows(select(qT, qD :!= 0))
    mata: qlo = _iivw_cr_count_le(qev, qT0) :+ 1; qhi = _iivw_cr_count_le(qev, qT)
    mata: qPD = _iivw_cr_events(qD, qhi, rows(qev))
    mata: st_local("qm", strofreal(hasmissing(_iivw_cr_dyadcoef(qlo, qhi, qPD, J(4, 1, 0), 4096))))
    assert "`qm'" == "1"
}
if _rc == 0 {
    display as result "  PASS: U07 event row outside its risk set: no O(rows) certificate"
    local ++pass_count
}
else {
    display as error "  FAIL: U07 event-row guard (rc `=_rc')"
    local ++fail_count
    local failed "`failed' U07"
}

**# Summary
iivw_qa_summary, name(test_iivw_exogtest_separation_regress) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
