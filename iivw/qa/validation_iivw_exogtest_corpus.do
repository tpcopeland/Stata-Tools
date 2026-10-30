*! validation_iivw_exogtest_corpus.do — certified corpora for the exogtest separation check
*! Author: Timothy P Copeland, Karolinska Institutet
*
* The monotone-likelihood check (_iivw_cox_recession in _iivw_mlib.ado)
* decides Jacobsen's condition (Chen, Ibrahim and Shao 2009, Remark 3.5): is
* there a direction a with z'a >= 0 on every (event, at-risk) pair row
* z = x_j - x_i and > 0 on one? Status 1 says yes, 0 says no, 2 says the
* search did not settle.
*
* Oracle: data/exogtest_corpus_exp.csv column sep, decided EXACTLY in rational
* arithmetic on the stored doubles (a verified direction for sep = 1, a
* verified strictly positive Stiemke vector y with Z'y = 0 for sep = 0;
* cert.py of the 2026-10-29 review, re-run on this very file with correctly
* rounded parsing, which is what import delimited, asdouble reads). Nothing
* here is computed by the package.
*
* data/exogtest_corpus_cases.csv holds 1209 cases (10171 rows: corpus, case,
* t0, t, d, x1..x4; the check uses x1..xp) from thirteen certified corpora:
*   b_gap                 x2 = x1 + 1e-3..1e-5 times 0/1/2: gaps stcox keeps
*                         (2026-10-30 round, generated and certified the same way)
*   g_heavy, g_heavyP     one value of +/-1e5..1e12 (P: rows permuted)
*   g_collin, g_collinP   x2 = x1 + 1e-9 or 1e-7 times 0/1/2
*   g_colscale, h_colscale columns scaled by 1e6 and 1e-6
*   g_cont, h_cont        continuous covariates, some times 1e4..1e9
*   g_ints, g_tie         small integers; g_tie with heavy ties
*   h_easy, h_heavy       the implementer's corpora
* Chosen: every case that kills the slack-threshold mutant (w[1] > 1e6) or
* the slack-error-bound mutant (1e-3 * |Z||a|) on this base, every case the
* 1.0.1 base gets wrong, every case it leaves unsettled, every case whose
* status depends on the tie order of the check's internal sort, and a seeded
* sample of up to 40 sep = 1 and 40 sep = 0 cases per corpus (15 for the long
* continuous ones).
*
* Tie order. Mata's order() breaks ties with Stata's sort jumbler, and the
* check sorts its rows by risk-set entry with order(lo, 1), so the same rows
* can get a different status depending on what ran before in the session.
* Every call below therefore fixes the jumbler (set sortrngstate 1), which
* makes each case's result independent of the suite's history and of any
* mutation elsewhere; D01 then asserts the status does not depend on the
* jumbler state at all (states 1-8), which the 1.0.1 base fails.
*
* Assertion contract, per case: status 1 only if sep = 1, status 0 only if
* sep = 0; status 2 is allowed but counted. The per-corpus status-2 bound is
* the 1.0.1 base's own count on this subset plus the corpus's known-wrong
* cases (each of which may legitimately become "did not settle"): a change
* may turn a wrong verdict into 2, but may not trade settled correct verdicts
* for 2. Corpora the base settles completely have bound 0.
*
* KNOWN WRONG on the 1.0.1 base (column known_wrong = 1, asserted against the
* truth in K01-K05, so those cells are red until the numerics are fixed):
*   g_heavy  205 594            false "monotone" (LEDGER defects 1 and 3)
*   g_heavyP 205 594
*   g_collin 27 42 74 115 146 149 163 164 174 204 245 249 287 307 341 389
*            411 427 435 445 465 478 481 491
*   g_collinP 27 42 74 115 146 149 163 174 204 245 249 287 307 341 389 411
*            435 445 465 478 481 491
*   b_gap    14 55 58 143 282 408 541 554 578 (14 55 282 554 also reach the
*            user through iivw_exogtest: validation_iivw_exogtest_command.do)
* TIE-ORDER DEPENDENT on the 1.0.1 base (column tie_flip = 1, D01):
*   g_heavy 443 606 660, g_heavyP 443 606 660, g_collin 340,
*   g_collinP 164 340
* (g_collin 427 is a miss through the gray zone: the error mask zeroes every
* component of the candidate direction, the zero vector "verifies", and the
* search returns 0.)
version 16.0
clear all
set more off
set varabbrev off
local qa_dir "`c(pwd)'"
do _iivw_qa_common.do
iivw_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

* The check under test is the INSTALLED Mata (the net install above).
quietly findfile _iivw_mlib.ado
local mlib_fn "`r(fn)'"
run "`mlib_fn'"

* One row per corpus: name, cases in the file, status-2 bound.
local corpora b_gap g_heavy g_heavyP g_collin g_collinP g_colscale g_cont g_ints ///
    g_tie h_colscale h_cont h_easy h_heavy
local ncase_b_gap 146
local ncase_g_heavy 103
local ncase_g_heavyP 101
local ncase_g_collin 168
local ncase_g_collinP 166
local ncase_g_colscale 80
local ncase_g_cont 30
local ncase_g_ints 80
local ncase_g_tie 80
local ncase_h_colscale 80
local ncase_h_cont 15
local ncase_h_easy 80
local ncase_h_heavy 80
local s2max_b_gap 10
local s2max_g_heavy 20
local s2max_g_heavyP 17
local s2max_g_collin 48
local s2max_g_collinP 47
foreach c in g_colscale g_cont g_ints g_tie h_colscale h_cont h_easy h_heavy {
    local s2max_`c' 0
}

tempfile cases exp res
local srs0 = c(sortrngstate)

**# T01: the corpus files are the certified subset, read bit-exactly
local ++test_count
capture noisily {
    import delimited using "`qa_dir'/data/exogtest_corpus_exp.csv", clear asdouble ///
        stringcols(1)
    assert _N == 1209
    assert inlist(sep, 0, 1) & inrange(p, 1, 4) & inlist(known_wrong, 0, 1)
    foreach c of local corpora {
        quietly count if corpus == "`c'"
        assert r(N) == `ncase_`c''
    }
    * The mutant-killing cases are present (trimming the subset would disarm it).
    quietly count if kill_n2
    assert r(N) == 22
    quietly count if kill_n12
    assert r(N) == 123
    quietly count if known_wrong
    assert r(N) == 59
    quietly count if tie_flip
    assert r(N) == 9
    sort corpus case
    quietly by corpus case: assert _N == 1
    gen long key = _n
    quietly save `exp'
    import delimited using "`qa_dir'/data/exogtest_corpus_cases.csv", clear asdouble ///
        stringcols(1)
    assert _N == 10171
    * File order is kept within a case: the sweep's floating-point sums, and
    * so a near-boundary verdict, depend on row order (g_heavyP and
    * g_collinP are row permutations of g_heavy and g_collin).
    gen long rowid = _n
    * x2 = x1 + 1e-9 survives only in double: a float import would erase it.
    foreach v in t0 t d x1 x2 x3 x4 {
        assert "`: type `v''" == "double" | "`: type `v''" == "byte" | ///
            "`: type `v''" == "int" | "`: type `v''" == "long"
    }
    quietly count if corpus == "g_collin" & case == 427 & x2 == 2e-9
    assert r(N) == 1
    sort corpus case, stable
    quietly merge m:1 corpus case using `exp', keepusing(key p) assert(match) nogenerate
    sort key rowid
    quietly save `cases'
}
if _rc == 0 {
    display as result "  PASS: T01 corpus files: 1209 certified cases, double precision"
    local ++pass_count
}
else {
    display as error "  FAIL: T01 corpus files (rc `=_rc')"
    local ++fail_count
    local failed "`failed' T01"
}

**# T02: every case runs and returns a status in {0, 1, 2}
local ++test_count
capture noisily {
    use `cases', clear
    gen byte tu = 0
    quietly summarize key, meanonly
    local nk = r(max)
    assert `nk' == 1209
    tempname ST
    matrix `ST' = J(`nk', 3, .)
    timer clear 91
    timer on 91
    forvalues k = 1/`nk' {
        quietly replace tu = (key == `k')
        quietly summarize p if tu, meanonly
        local pk = r(max)
        local xs "x1"
        forvalues j = 2/`pk' {
            local xs "`xs' x`j'"
        }
        local st = .
        set sortrngstate 1
        capture mata: st_local("st", strofreal(_iivw_cox_recession("t0", "t", "d", "`xs'", "tu")[1]))
        matrix `ST'[`k', 1] = _rc
        matrix `ST'[`k', 2] = `st'
        * The same rows under jumbler states 2-8 (for D01).
        local same = 1
        forvalues q = 2/8 {
            local sq = .
            set sortrngstate `q'
            capture mata: st_local("sq", strofreal(_iivw_cox_recession("t0", "t", "d", "`xs'", "tu")[1]))
            if _rc | "`sq'" != "`st'" local same = 0
        }
        matrix `ST'[`k', 3] = `same'
    }
    set sortrngstate `srs0'
    timer off 91
    quietly timer list 91
    display as text "  checked `nk' cases in " %6.2f r(t91) " s"
    use `exp', clear
    quietly gen double crash = .
    quietly gen double status = .
    quietly gen double same = .
    forvalues k = 1/`nk' {
        quietly replace crash = `ST'[`k', 1] in `k'
        quietly replace status = `ST'[`k', 2] in `k'
        quietly replace same = `ST'[`k', 3] in `k'
    }
    assert key == _n
    quietly save `res'
    assert crash == 0
    assert inlist(status, 0, 1, 2)
}
if _rc == 0 {
    display as result "  PASS: T02 every case ran and returned 0, 1 or 2"
    local ++pass_count
}
else {
    display as error "  FAIL: T02 check crashed or returned an invalid status (rc `=_rc')"
    local ++fail_count
    local failed "`failed' T02"
}

* Per-corpus verdicts on the cases the base decides correctly or leaves
* unsettled: no wrong verdict, and status 2 within the bound.
capture program drop _cor_verdicts
program define _cor_verdicts
    version 16.0
    args corpus s2max
    quietly count if corpus == "`corpus'" & !known_wrong
    local n = r(N)
    quietly count if corpus == "`corpus'" & !known_wrong & status == 1 & sep == 0
    local w1 = r(N)
    quietly count if corpus == "`corpus'" & !known_wrong & status == 0 & sep == 1
    local w0 = r(N)
    quietly count if corpus == "`corpus'" & status == 2
    local s2 = r(N)
    display as text "  `corpus': n=`n' wrong1=`w1' wrong0=`w0' status2=`s2' (bound `s2max')"
    if `w1' + `w0' > 0 {
        quietly levelsof case if corpus == "`corpus'" & !known_wrong & ///
            ((status == 1 & sep == 0) | (status == 0 & sep == 1)), local(bad)
        display as error "  `corpus' wrong verdicts at cases: `bad'"
    }
    assert `n' > 0
    assert `w1' == 0 & `w0' == 0
    assert `s2' <= `s2max'
end

local t = 2
foreach c of local corpora {
    local ++t
    local tid = "T" + string(`t', "%02.0f")
    local ++test_count
    capture noisily {
        use `res', clear
        _cor_verdicts `c' `s2max_`c''
    }
    if _rc == 0 {
        display as result "  PASS: `tid' `c': no wrong verdict, status 2 within bound"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `tid' `c' verdicts (rc `=_rc')"
        local ++fail_count
        local failed "`failed' `tid'"
    }
}

**# K01-K05: the base's known-wrong cases, against the truth
* Red on the 1.0.1 base by construction: these are the defects being fixed.
local k = 0
foreach c in g_heavy g_heavyP g_collin g_collinP b_gap {
    local ++k
    local tid "K0`k'"
    local ++test_count
    capture noisily {
        use `res', clear
        quietly keep if corpus == "`c'" & known_wrong
        assert _N > 0
        quietly count if (status == 1 & sep == 0) | (status == 0 & sep == 1)
        local nw = r(N)
        if `nw' {
            quietly levelsof case if (status == 1 & sep == 0) | (status == 0 & sep == 1), local(bad)
            display as error "  `c' known-wrong cases still wrong: `bad'"
        }
        assert `nw' == 0
    }
    if _rc == 0 {
        display as result "  PASS: `tid' `c' known-wrong cases now agree with the certificate"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `tid' `c' known-wrong cases (rc `=_rc')"
        local ++fail_count
        local failed "`failed' `tid'"
    }
}

**# D01: the status does not depend on the jumbler state (tie order)
* Identical rows must get one answer. Red on the 1.0.1 base at the cases
* marked tie_flip (heavy 443 606 660 flip between 0 and 2; collinP 164
* between 1 and 0).
local ++test_count
capture noisily {
    use `res', clear
    quietly count if same != 1
    local nf = r(N)
    if `nf' {
        quietly levelsof corpus if same != 1, local(fc)
        foreach c of local fc {
            quietly levelsof case if same != 1 & corpus == "`c'", local(bad)
            display as error "  `c' status depends on tie order at cases: `bad'"
        }
    }
    assert `nf' == 0
}
if _rc == 0 {
    display as result "  PASS: D01 every status is the same under jumbler states 1-8"
    local ++pass_count
}
else {
    display as error "  FAIL: D01 tie-order dependent status (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D01"
}

set sortrngstate `srs0'
iivw_qa_summary, name(validation_iivw_exogtest_corpus) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
