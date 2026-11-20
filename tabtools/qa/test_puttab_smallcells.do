* test_puttab_smallcells.do - puttab smallcells(), counts(), withhold(),
* fraction(), rowtotal() and totalrow() (tabtools 1.2.0)
*
* Contract: only the counts() columns are tested; a count from 1 to #-1
* prints as <#, a complementary count as >=#, zero as 0, missing blank.
* Complementary masking uses the declared margins only (rowtotal(),
* totalrow() within panel(), a fraction()'s denominator). Every sink is
* masked identically, the data in memory are unchanged, and r() gains
* r(smallcells), r(n_primary) and r(n_complementary) only.
*
* Oracles never pass through the tabtools engine: expected strings are
* written out by hand or recomputed in Stata from the data, and disclosure
* is checked by enumerating every integer table consistent with the
* PUBLISHED cells (read back from the written CSV) and the declared sums
* (_psc_nfeas below): each masked count, and each count that is truly from
* 1 to #-1, must keep at least two feasible values. The reader is taken to
* know the masking rule: a count that is not printed (a fraction's den-num)
* but is truly 1..#-1 is bounded to 1..#-1, since a ">=#" numerator beside a
* printed denominator can only mean that.

clear all
set more off
set varabbrev off
version 17.0

capture log close _psc
log using "test_puttab_smallcells.log", replace text name(_psc)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/psc_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

global PSC_tests 0
global PSC_pass 0
global PSC_fail 0

capture program drop _psc_tally
program define _psc_tally
    args rc name
    global PSC_tests = $PSC_tests + 1
    if `rc' == 0 {
        display as result "  PASS: `name'"
        global PSC_pass = $PSC_pass + 1
    }
    else {
        display as error "  FAIL: `name' (rc=`rc')"
        global PSC_fail = $PSC_fail + 1
    }
end

* Load a CSV written by puttab: one string variable v# per column.
capture program drop _psc_load
program define _psc_load
    args file
    import delimited using "`file'", varnames(nonames) stringcols(_all) ///
        delimiters(",") encoding("utf-8") clear
end

* Assert that column `col' of the loaded CSV reads, from row `from' on,
* exactly the listed cells ("" for an empty one).
capture program drop _psc_col
program define _psc_col
    gettoken col 0 : 0
    gettoken from 0 : 0
    local r = `from'
    while `"`0'"' != "" {
        gettoken cell 0 : 0
        if strtrim(v`col'[`r']) != `"`cell'"' {
            display as error `"row `r' column `col': found "`=v`col'[`r']'", expected "`cell'""'
            exit 9
        }
        local ++r
    }
end

mata:
// (lo, hi) of one published count: "" unpublished (., .), <k, >=k, n
real rowvector _psc_parse(string scalar s0, real scalar k)
{
    string scalar s
    s = strtrim(s0)
    if (s == "") return((., .))
    if (s == "<" + strofreal(k)) return((1, k - 1))
    if (s == "≥" + strofreal(k)) return((k, .))
    s = subinstr(s, ",", "")
    if (regexm(s, "^[0-9]+$")) return((strtoreal(s), strtoreal(s)))
    _error(3300, "unparsed published cell: " + s0)
}

// numerator and denominator text of a published fraction "a/b"
string rowvector _psc_split(string scalar s)
{
    real scalar p
    s = strtrim(s)
    if (s == "") return(("", ""))
    p = strpos(s, "/")
    if (!p) _error(3300, "not a fraction: " + s)
    return((substr(s, 1, p - 1), substr(s, p + 1, .)))
}

// depth-first enumeration of the unknown entries of grid G (row-major);
// with rowc the last column totals each row, with colc the last row
// totals each column. An entry fixed by its row or column is solved, not
// looped. seen[u, v + 1] = 1 when unknown u takes value v in a solution.
void _psc_dfs(real scalar u, real matrix G, real matrix LO, real matrix HI,
    real colvector ui, real colvector uj, real colvector lastin,
    real scalar rowc, real scalar colc, real matrix seen)
{
    real scalar R, C, i, j, x, x0, x1, r, c, tot, v

    R = rows(G)
    C = cols(G)
    if (u > rows(ui)) {
        if (rowc) {
            for (r = 1; r <= R; r++) if (sum(G[r, (1..C - 1)]) != G[r, C]) return
        }
        if (colc) {
            for (c = 1; c <= C; c++) if (sum(G[(1..R - 1), c]) != G[R, c]) return
        }
        for (v = 1; v <= rows(ui); v++) seen[v, G[ui[v], uj[v]] + 1] = 1
        return
    }
    i = ui[u]
    j = uj[u]
    x0 = LO[i, j]
    x1 = HI[i, j]
    if (colc & i == R) {
        tot = sum(G[(1..R - 1), j])
        x0 = max((x0, tot))
        x1 = min((x1, tot))
    }
    else if (rowc & j == C) {
        tot = sum(G[i, (1..C - 1)])
        x0 = max((x0, tot))
        x1 = min((x1, tot))
    }
    else if (colc & i == R - 1 & LO[R, j] == HI[R, j]) {
        tot = G[R, j] - (i > 1 ? sum(G[(1..i - 1), j]) : 0)
        x0 = max((x0, tot))
        x1 = min((x1, tot))
    }
    else if (rowc & lastin[u] & LO[i, C] == HI[i, C]) {
        tot = G[i, C] - (sum(G[i, (1..C - 1)]) - G[i, j])
        x0 = max((x0, tot))
        x1 = min((x1, tot))
    }
    if (colc & i < R & LO[R, j] == HI[R, j]) {
        tot = G[R, j] - (i > 1 ? sum(G[(1..i - 1), j]) : 0)
        x1 = min((x1, tot))
    }
    for (x = x0; x <= x1; x++) {
        G[i, j] = x
        _psc_dfs(u + 1, G, LO, HI, ui, uj, lastin, rowc, colc, seen)
    }
    G[i, j] = LO[i, j]
}

// number of feasible integer values of every grid entry given its bounds
// (lo = hi: printed) and the declared sums
real matrix _psc_nfeas(real matrix LO0, real matrix HI0, real scalar rowc,
    real scalar colc)
{
    real matrix LO, HI, G, seen, NF
    real colvector ui, uj, lastin
    real scalar R, C, i, j, u, cap, big

    LO = LO0
    HI = HI0
    R = rows(LO)
    C = cols(LO)
    big = 0
    for (i = 1; i <= R; i++) for (j = 1; j <= C; j++) {
        if (LO[i, j] == HI[i, j] & LO[i, j] < . & LO[i, j] > big) big = LO[i, j]
    }
    ui = J(0, 1, .)
    uj = J(0, 1, .)
    for (i = 1; i <= R; i++) for (j = 1; j <= C; j++) {
        if (LO[i, j] == HI[i, j]) continue
        if (HI[i, j] >= .) {
            cap = .
            if (rowc & j < C & LO[i, C] == HI[i, C]) cap = min((cap, LO[i, C]))
            if (colc & i < R & LO[R, j] == HI[R, j]) cap = min((cap, LO[R, j]))
            if (rowc & colc & LO[R, C] == HI[R, C]) cap = min((cap, LO[R, C]))
            if (cap >= .) cap = 3 * big + 30
            HI[i, j] = cap
        }
        ui = ui \ i
        uj = uj \ j
    }
    lastin = J(rows(ui), 1, 0)
    for (u = 1; u <= rows(ui); u++) {
        if (uj[u] == C & rowc) continue
        lastin[u] = 1
        if (u < rows(ui)) {
            if (ui[u + 1] == ui[u] & !(rowc & uj[u + 1] == C)) lastin[u] = 0
        }
    }
    G = LO
    seen = J(rows(ui), max((max(HI :* (HI :< .)), 1)) + 2, 0)
    _psc_dfs(1, G, LO, HI, ui, uj, lastin, rowc, colc, seen)
    NF = J(R, C, 1)
    for (u = 1; u <= rows(ui); u++) NF[ui[u], uj[u]] = sum(seen[u, .])
    return(NF)
}

// Disclosure audit of one published grid P (strings; "" = not printed)
// against its truth T: printed cells must be true, every masked cell and
// every truly small count (1..k-1) must keep two feasible values. Posts
// scalars psc_viol (violations) and psc_masked (masked cells).
void _psc_audit(string matrix P, real matrix T, real scalar k,
    real scalar rowc, real scalar colc)
{
    real matrix LO, HI, NF, b
    real scalar i, j, viol, masked
    string scalar s

    LO = J(rows(P), cols(P), .)
    HI = LO
    viol = 0
    masked = 0
    for (i = 1; i <= rows(P); i++) for (j = 1; j <= cols(P); j++) {
        b = _psc_parse(P[i, j], k)
        s = strtrim(P[i, j])
        if (b[1] >= .) b = ((T[i, j] >= 1 & T[i, j] < k) ? (1, k - 1) : (0, .))
        LO[i, j] = b[1]
        HI[i, j] = b[2]
        if (s == "<" + strofreal(k) | s == "≥" + strofreal(k)) masked++
        if (T[i, j] < LO[i, j] | T[i, j] > HI[i, j]) {
            printf("{err}cell [%f,%f] published %s but is %f\n", i, j, s, T[i, j])
            viol++
        }
    }
    NF = _psc_nfeas(LO, HI, rowc, colc)
    for (i = 1; i <= rows(P); i++) for (j = 1; j <= cols(P); j++) {
        s = strtrim(P[i, j])
        if ((s == "<" + strofreal(k) | s == "≥" + strofreal(k) |
            (T[i, j] >= 1 & T[i, j] < k)) & NF[i, j] < 2) {
            printf("{err}cell [%f,%f] (true %f, published %s) has %f feasible value(s)\n",
                i, j, T[i, j], s, NF[i, j])
            viol++
        }
    }
    st_numscalar("psc_viol", viol)
    st_numscalar("psc_masked", masked)
}

// published strings of rows rr, columns cc of the loaded CSV (v# variables)
string matrix _psc_grab(real rowvector rr, real rowvector cc)
{
    string matrix P
    real scalar i, j
    P = J(cols(rr), cols(cc), "")
    for (i = 1; i <= cols(rr); i++) for (j = 1; j <= cols(cc); j++) {
        P[i, j] = strtrim(st_sdata(rr[i], "v" + strofreal(cc[j])))
    }
    return(P)
}
end

**# 1. Threshold boundary: #-1 masked; #, 0 and missing printed; others untouched
capture noisily {
    local csv "`output_dir'/psc_t1.csv"
    clear
    input str4 lab c1 c2 x
    "r0" 0 0 1
    "r1" 1 2 2
    "r4" 4 3 3
    "r5" 5 . 4
    "r6" 6 7 0.5
    end
    puttab lab c1 c2 x, csv("`csv'") counts(c1 c2) smallcells(5)
    assert r(smallcells) == 5
    assert r(n_primary) == 4
    assert r(n_complementary) == 0
    _psc_load "`csv'"
    _psc_col 2 2 "0" "<5" "<5" "5" "6"
    _psc_col 3 2 "0" "<5" "<5" "" "7"
    * x is not a count: 1, 2, 3 and 4 stay printed
    _psc_col 4 2 "1.00" "2.00" "3.00" "4.00" "0.50"
    * the threshold moves the boundary
    clear
    input str4 lab c1
    "a" 0
    "b" 1
    "c" 2
    "d" 3
    end
    format c1 %9.0fc
    puttab lab c1, csv("`csv'") counts(c1) smallcells(3)
    assert r(n_primary) == 2
    _psc_load "`csv'"
    _psc_col 2 2 "0" "<3" "<3" "3"
    * a comma-formatted count keeps its format when printed
    clear
    input str4 lab c1
    "a" 1234
    "b" 2
    end
    format c1 %9.0fc
    puttab lab c1, csv("`csv'") counts(c1) smallcells(5)
    _psc_load "`csv'"
    _psc_col 2 2 "1,234" "<5"
}
_psc_tally `=_rc' "threshold boundary (k-1 masked, k and 0 printed, others untouched)"

**# 2. withhold(): exactly the listed cells, primary or complementary key
capture noisily {
    local csv "`output_dir'/psc_t2.csv"
    clear
    input str4 lab e1 n1 e0 n0 p1 p0 rr str2 note
    "a" 3 40 10 50 7.5 20 1.2 "x"
    "b" 0 40 7 9 0 77.8 0.8 "y"
    "c" 20 40 30 50 50 60 0.9 "z"
    "d" 38 40 25 50 95 50 1.1 "w"
    end
    puttab lab e1 n1 e0 n0 p1 p0 rr note, csv("`csv'") digits(1) ///
        counts(e1 n1 e0 n0) fraction(e1/n1 e0/n0) smallcells(5) ///
        withhold(e1: p1 rr \ e0: p0 rr note)
    assert r(n_cols) == 7
    _psc_load "`csv'"
    _psc_col 1 1 "lab" "a" "b" "c" "d"
    _psc_col 2 1 "e1" "<5/40" "0/40" "20/40" "≥5/40"
    _psc_col 3 1 "e0" "10/50" "≥5/9" "30/50" "25/50"
    _psc_col 4 1 "p1" "" "0.0" "50.0" ""
    _psc_col 5 1 "p0" "20.0" "" "60.0" "50.0"
    _psc_col 6 1 "rr" "" "" "0.9" ""
    _psc_col 7 1 "note" "x" "" "z" "w"
    * a plain count key (no fraction); the key column itself may be listed
    clear
    input str4 lab n py rate
    "a" 2 100 2
    "b" 9 120 7.5
    "c" 0 50 0
    end
    puttab lab n py rate, csv("`csv'") counts(n) smallcells(5) withhold(n: rate n)
    _psc_load "`csv'"
    _psc_col 2 2 "" "9" "0"
    _psc_col 3 2 "100" "120" "50"
    _psc_col 4 2 "" "7.50" "0.00"
    * a key masked only as complementary (>=5 within a rowtotal() row, and
    * down a totalrow() column) blanks its listed cells as well: row x
    * masks a as <5 and b as >=5, row z masks b as <5 and c as >=5
    clear
    input str6 lab a b c tot pb pc
    "x" 2 10 12 24 41.7 50
    "y" 6 7 20 33 21.2 60.6
    "z" 0 1 30 31 3.2 96.8
    end
    puttab lab a b c tot pb pc, csv("`csv'") digits(1) counts(a b c tot) ///
        rowtotal(tot) smallcells(5) withhold(b: pb \ c: pc)
    _psc_load "`csv'"
    _psc_col 3 2 "≥5" "7" "<5"
    _psc_col 4 2 "12" "20" "≥5"
    _psc_col 6 2 "" "21.2" ""
    _psc_col 7 2 "50.0" "60.6" ""
    clear
    input str6 lab n pn
    "x" 2 3.4
    "y" 7 11.9
    "z" 50 84.7
    "Total" 59 100
    end
    puttab lab n pn, csv("`csv'") digits(1) counts(n) totalrow(lab == "Total") ///
        smallcells(5) withhold(n: pn)
    _psc_load "`csv'"
    _psc_col 2 2 "<5" "≥5" "50" "59"
    _psc_col 3 2 "" "" "84.7" "100.0"
}
_psc_tally `=_rc' "withhold() blanks exactly the listed cells"

**# 3. fraction(): e, N-e and N masked by the count rule; oracle per row
capture noisily {
    local csv "`output_dir'/psc_t3.csv"
    clear
    input str4 lab e n
    "a" 3 40
    "b" 38 40
    "c" 0 40
    "d" 40 40
    "e" 3 6
    "f" 2 3
    "g" 0 3
    "h" 0 0
    "i" . .
    "j" 5 9
    "k" 6 10
    "l" 5 10
    end
    label variable e "Exposed, n/N"
    puttab lab e n, csv("`csv'") varlabels counts(e n) fraction(e/n) smallcells(5)
    * the denominator is printed inside the fraction only
    assert r(n_cols) == 2
    * primary: a e, b N-e, e e and N-e, f e N and N-e... counted by hand:
    * a:1 b:1 e:2 f:3 (e=2, N-e=1, N=3) g:2 (N-e, N) j:1 k:1
    assert r(n_primary) == 11
    * complementary: b, j, k (a small N-e beside a printed N)
    assert r(n_complementary) == 3
    _psc_load "`csv'"
    _psc_col 2 1 "Exposed, n/N" "<5/40" "≥5/40" "0/40" "40/40" "<5/6" ///
        "<5/<5" "0/<5" "0/0" "" "≥5/9" "≥5/10" "5/10"
    * oracle: [e, N-e | N] with the row sum declared by the fraction
    local truth "3, 40 \ 38, 40 \ 0, 40 \ 40, 40 \ 3, 6 \ 2, 3 \ 0, 3 \ 0, 0 \ ., . \ 5, 9 \ 6, 10 \ 5, 10"
    matrix TT = (`truth')
    forvalues r = 1/12 {
        if missing(TT[`r', 1]) continue
        mata: _f = _psc_split(st_sdata(`r' + 1, "v2"))
        mata: _psc_audit((_f[1], "", _f[2]), ///
            (st_matrix("TT")[`r', 1], st_matrix("TT")[`r', 2] - st_matrix("TT")[`r', 1], ///
            st_matrix("TT")[`r', 2]), 5, 1, 0)
        assert scalar(psc_viol) == 0
    }
}
_psc_tally `=_rc' "fraction() masks e, N-e and N; no row recoverable"

**# 4. rowtotal(): complementary within a row, checked by enumeration
capture noisily {
    local csv "`output_dir'/psc_t4.csv"
    clear
    input str4 lab a b c tot
    "x" 2 10 12 24
    "y" 3 4 20 27
    "z" 0 1 30 31
    "w" 6 7 8 21
    end
    puttab lab a b c tot, csv("`csv'") counts(a b c tot) rowtotal(tot) smallcells(5)
    assert r(n_primary) == 4
    assert r(n_complementary) == 2
    _psc_load "`csv'"
    * x: the 2 needs a second masked cell (the smallest, 10); y: 3 + 4 = 7
    * already has two solutions; z: the 1 beside a 0 needs the 30
    _psc_col 2 2 "<5" "<5" "0" "6"
    _psc_col 3 2 "≥5" "<5" "<5" "7"
    _psc_col 4 2 "12" "20" "≥5" "8"
    _psc_col 5 2 "24" "27" "31" "21"
    matrix T = (2, 10, 12, 24 \ 3, 4, 20, 27 \ 0, 1, 30, 31 \ 6, 7, 8, 21)
    forvalues r = 1/4 {
        mata: _psc_audit(_psc_grab(`r' + 1, (2, 3, 4, 5)), st_matrix("T")[`r', .], 5, 1, 0)
        assert scalar(psc_viol) == 0
    }
    * the colon form names the addends; other counts are tested on their own
    clear
    input str4 lab e n1 n0 ntot
    "x" 3 2 10 12
    "y" 9 8 20 28
    end
    puttab lab e n1 n0 ntot, csv("`csv'") counts(e n1 n0 ntot) ///
        rowtotal(ntot: n1 n0) smallcells(5)
    _psc_load "`csv'"
    _psc_col 2 2 "<5" "9"
    _psc_col 3 2 "<5" "8"
    _psc_col 4 2 "≥5" "20"
    _psc_col 5 2 "12" "28"
}
_psc_tally `=_rc' "rowtotal() complementary cells; no cell recoverable"

**# 5. totalrow() within panel(): complementary down a column
capture noisily {
    local csv "`output_dir'/psc_t5.csv"
    clear
    input str6 blk str6 lab n1 n0
    "A" "x" 2 10
    "A" "y" 8 20
    "A" "z" 9 30
    "A" "Total" 19 60
    "B" "x" 1 12
    "B" "y" 5 13
    "B" "z" 7 14
    "B" "Total" 13 39
    end
    puttab lab n1 n0, panel(blk) noindent csv("`csv'") counts(n1 n0) ///
        totalrow(lab == "Total") smallcells(5)
    assert r(n_primary) == 2
    assert r(n_complementary) == 2
    _psc_load "`csv'"
    * rows: 1 header, 2 heading A, 3-6 panel A, 7 heading B, 8-11 panel B
    _psc_col 1 2 "A" "x" "y" "z" "Total" "B" "x" "y" "z" "Total"
    * A: one small count, the smallest other (8) protects it. B: 1 beside a
    * masked 5 would be pinned (1 + 5 = 6 and the 5 is at least 5), so the
    * 7 protects it instead and the 5 stays printed
    _psc_col 2 3 "<5" "≥5" "9" "19"
    _psc_col 2 8 "<5" "5" "≥5" "13"
    _psc_col 3 3 "10" "20" "30" "60"
    _psc_col 3 8 "12" "13" "14" "39"
    matrix TA = (2 \ 8 \ 9 \ 19)
    matrix TB = (1 \ 5 \ 7 \ 13)
    mata: _psc_audit(_psc_grab((3, 4, 5, 6), 2), st_matrix("TA"), 5, 0, 1)
    assert scalar(psc_viol) == 0
    mata: _psc_audit(_psc_grab((8, 9, 10, 11), 2), st_matrix("TB"), 5, 0, 1)
    assert scalar(psc_viol) == 0
    * a small total row count is itself masked
    clear
    input str6 lab n1
    "x" 1
    "y" 0
    "Total" 1
    end
    puttab lab n1, csv("`csv'") counts(n1) totalrow(lab == "Total") smallcells(5)
    _psc_load "`csv'"
    _psc_col 2 2 "<5" "0" "<5"
    mata: _psc_audit(_psc_grab((2, 3, 4), 2), (1 \ 0 \ 1), 5, 0, 1)
    assert scalar(psc_viol) == 0
}
_psc_tally `=_rc' "totalrow() within panel(): complementary down a column"

**# 6. rowtotal() and totalrow() together: the two-way case
capture noisily {
    local csv "`output_dir'/psc_t6.csv"
    clear
    input str6 lab n1 n0 tot
    "x" 2 10 12
    "y" 8 20 28
    "z" 9 30 39
    "Total" 19 60 79
    end
    puttab lab n1 n0 tot, csv("`csv'") counts(n1 n0 tot) rowtotal(tot) ///
        totalrow(lab == "Total") smallcells(5)
    assert r(n_primary) == 1
    assert r(n_complementary) == 3
    _psc_load "`csv'"
    _psc_col 2 2 "<5" "≥5" "9" "19"
    _psc_col 3 2 "≥5" "≥5" "30" "60"
    _psc_col 4 2 "12" "28" "39" "79"
    matrix T = (2, 10, 12 \ 8, 20, 28 \ 9, 30, 39 \ 19, 60, 79)
    mata: _psc_audit(_psc_grab((2, 3, 4, 5), (2, 3, 4)), st_matrix("T"), 5, 1, 1)
    assert scalar(psc_viol) == 0
    * fractions down a panel with a total row: [e, N-e | N] two ways
    clear
    input str6 lab e n
    "x" 2 30
    "y" 10 40
    "z" 12 25
    "Total" 24 95
    end
    puttab lab e n, csv("`csv'") counts(e n) fraction(e/n) ///
        totalrow(lab == "Total") smallcells(5)
    _psc_load "`csv'"
    mata: _P = J(4, 3, "")
    forvalues r = 1/4 {
        mata: _f = _psc_split(st_sdata(`r' + 1, "v2")); _P[`r', 1] = _f[1]; _P[`r', 3] = _f[2]
    }
    mata: _psc_audit(_P, (2, 28, 30 \ 10, 30, 40 \ 12, 13, 25 \ 24, 71, 95), 5, 1, 1)
    assert scalar(psc_viol) == 0
    assert scalar(psc_masked) >= 2
}
_psc_tally `=_rc' "rowtotal() with totalrow(): two-way protection, enumeration-checked"

**# 7. Random two-way tables: no published cell is recoverable
capture noisily {
    local csv "`output_dir'/psc_t7.csv"
    set seed 20261118
    local nmasked 0
    forvalues rep = 1/40 {
        local R = runiformint(2, 3)
        local C = runiformint(2, 3)
        local k = cond(runiform() < 0.5, 3, 5)
        clear
        quietly set obs `=`R' + 1'
        quietly gen str6 lab = "r" + string(_n)
        quietly replace lab = "Total" in L
        local cl ""
        forvalues c = 1/`C' {
            quietly gen long c`c' = cond(runiform() < 0.45, runiformint(0, `k' - 1), runiformint(`k', 14))
            quietly summarize c`c' in 1/`R', meanonly
            quietly replace c`c' = r(sum) in L
            local cl `cl' c`c'
        }
        quietly egen long tot = rowtotal(`cl')
        capture puttab lab `cl' tot, csv("`csv'") counts(`cl' tot) rowtotal(tot) ///
            totalrow(lab == "Total") smallcells(`k')
        * a block the engine cannot certify is refused, never printed
        if _rc == 498 continue
        if _rc exit `=_rc'
        mkmat `cl' tot, matrix(T)
        _psc_load "`csv'"
        local cc ""
        forvalues c = 2/`=`C' + 2' {
            local cc `cc' `c'
        }
        local cc = subinstr("`cc'", " ", ", ", .)
        local rr ""
        forvalues r = 2/`=`R' + 2' {
            local rr `rr' `r'
        }
        local rr = subinstr("`rr'", " ", ", ", .)
        mata: _psc_audit(_psc_grab((`rr'), (`cc')), st_matrix("T"), `k', 1, 1)
        if scalar(psc_viol) != 0 {
            display as error "random table `rep' leaks"
            exit 9
        }
        local nmasked = `nmasked' + scalar(psc_masked)
    }
    * the grid is not vacuous
    assert `nmasked' > 40
}
_psc_tally `=_rc' "random two-way tables: every masked and small cell keeps two values"

**# 8. primary and nosmallcells
capture noisily {
    local csv "`output_dir'/psc_t8.csv"
    clear
    input str6 lab n1 n0 tot
    "x" 2 10 12
    "y" 8 20 28
    "Total" 10 30 40
    end
    puttab lab n1 n0 tot, csv("`csv'") counts(n1 n0 tot) rowtotal(tot) ///
        totalrow(lab == "Total") smallcells(5, primary)
    assert r(n_primary) == 1
    assert r(n_complementary) == 0
    _psc_load "`csv'"
    _psc_col 2 2 "<5" "8" "10"
    _psc_col 3 2 "10" "20" "30"
    * primary protects printed counts only: the margins give the 2 back
    mata: _psc_audit(_psc_grab((2, 3, 4), (2, 3, 4)), (2, 10, 12 \ 8, 20, 28 \ 10, 30, 40), 5, 1, 1)
    assert scalar(psc_viol) > 0
    * primary in a fraction: a small N-e still hides e (as >=5), counted primary
    clear
    input str4 lab e n
    "a" 38 40
    "b" 3 40
    end
    puttab lab e n, csv("`csv'") counts(e n) fraction(e/n) smallcells(5, primary)
    assert r(n_primary) == 2
    assert r(n_complementary) == 0
    _psc_load "`csv'"
    _psc_col 2 2 "≥5/40" "<5/40"
    * nosmallcells: nothing masked, fractions still printed, r(smallcells) 0
    clear
    input str4 lab e n rr
    "a" 3 40 1.5
    "b" 38 40 2
    end
    puttab lab e n rr, csv("`csv'") counts(e n) fraction(e/n) nosmallcells ///
        withhold(e: rr)
    assert r(smallcells) == 0
    assert r(n_primary) == 0
    assert r(n_complementary) == 0
    capture puttab lab e n, csv("`csv'") counts(e n) smallcells(5) nosmallcells
    assert _rc == 198
    _psc_load "`csv'"
    _psc_col 2 2 "3/40" "38/40"
    _psc_col 3 2 "1.50" "2.00"
}
_psc_tally `=_rc' "primary masks only small counts; nosmallcells masks nothing"

**# 9. Session default: applied with counts(), echoed, and never silent without
capture noisily {
    local csv "`output_dir'/psc_t9.csv"
    local lg "`output_dir'/psc_t9.log"
    clear
    input str6 lab n1 n0 tot
    "x" 2 10 12
    "y" 8 20 28
    end
    tabtools set smallcells 5
    capture log close _psc9
    log using "`lg'", replace text name(_psc9)
    puttab lab n1 n0 tot, csv("`csv'") counts(n1 n0 tot) rowtotal(tot)
    local r1 = r(smallcells)
    local c1 = r(n_complementary)
    * no declared margin: the note says undeclared totals are not protected
    * (tot is not in counts(), so it is not checked)
    puttab lab n1 n0 tot, csv("`output_dir'/psc_t9b.csv") counts(n1 n0)
    puttab lab n1 n0 tot, csv("`output_dir'/psc_t9c.csv")
    local r3 : r(scalars)
    log close _psc9
    assert `r1' == 5
    assert `c1' == 1
    assert !`: list posof "smallcells" in r3'
    _v_line "`lg'" "(tabtools: using session smallcells(5))" 2
    _v_grep "`lg'" "^\(puttab: smallcells\(5\): no rowtotal\(\) or totalrow\(\) declared; a printed total"
    assert r(n) == 1
    _v_grep "`lg'" "^\(puttab: session smallcells\(5\) not applied"
    assert r(n) == 1
    _psc_load "`csv'"
    _psc_col 2 2 "<5" "8"
    _psc_col 3 2 "≥5" "20"
    _psc_load "`output_dir'/psc_t9c.csv"
    _psc_col 2 2 "2" "8"
    * the session primary mode, and an explicit option or nosmallcells wins
    clear
    input str6 lab n1 n0 tot
    "x" 2 10 12
    "y" 8 20 28
    end
    tabtools set smallcells 5 primary
    puttab lab n1 n0 tot, csv("`csv'") counts(n1 n0 tot) rowtotal(tot)
    assert r(n_complementary) == 0
    _psc_load "`csv'"
    _psc_col 3 2 "10" "20"
    clear
    input str6 lab n1 n0 tot
    "x" 2 10 12
    end
    puttab lab n1 n0 tot, csv("`csv'") counts(n1 n0 tot) rowtotal(tot) smallcells(3)
    assert r(smallcells) == 3
    _psc_load "`csv'"
    _psc_col 2 2 "<3"
    clear
    input str6 lab n1 n0 tot
    "x" 2 10 12
    end
    puttab lab n1 n0 tot, csv("`csv'") counts(n1 n0 tot) nosmallcells
    assert r(smallcells) == 0
    _psc_load "`csv'"
    _psc_col 2 2 "2"
}
local _rc_save = _rc
capture log close _psc9
tabtools set clear
_psc_tally `_rc_save' "session smallcells default: applied, echoed, overridden"

**# 10. Every sink masked identically (Excel, CSV, Markdown, LaTeX)
capture noisily {
    local book "`output_dir'/psc_t10.xlsx"
    local csv "`output_dir'/psc_t10.csv"
    local md "`output_dir'/psc_t10.md"
    local tex "`output_dir'/psc_t10.tex"
    foreach f in book csv md tex {
        capture erase "``f''"
    }
    clear
    input str6 lab n1 n0 tot e
    "x" 2 10 12 1
    "y" 8 20 28 30
    "z" 9 30 39 3
    end
    puttab lab n1 n0 tot e using "`book'", sheet("SC") csv("`csv'") ///
        markdown("`md'") latex("`tex'") counts(n1 n0 tot e) ///
        rowtotal(tot: n1 n0) smallcells(5)
    _psc_load "`csv'"
    _psc_col 2 2 "<5" "8" "9"
    _psc_col 3 2 "≥5" "20" "30"
    _psc_col 4 2 "12" "28" "39"
    _psc_col 5 2 "<5" "30" "<5"
    * the same cells in every other sink
    _v_facts "`book'" "SC"
    local xl "C D E F"
    forvalues r = 2/4 {
        forvalues c = 2/5 {
            local cell = strtrim(v`c'[`r'])
            local xc : word `=`c' - 1' of `xl'
            _v_value `xc'`=`r' + 1' "`cell'"
        }
    }
    forvalues r = 2/4 {
        local mdl "| `=v1[`r']'"
        local texl "`=v1[`r']'"
        forvalues c = 2/5 {
            local cell = strtrim(v`c'[`r'])
            local mdl "`mdl' | `=subinstr("`cell'", "<", "\<", .)'"
            local tc = subinstr("`cell'", "<", "\textless{}", .)
            local tc = subinstr("`tc'", "≥", "\ensuremath{\geq}", .)
            local texl "`texl' & `tc'"
        }
        _v_line "`md'" "`mdl' |" 1
        _v_line "`tex'" "`texl' \\" 1
    }
    * no raw small count survives anywhere
    foreach f in md tex {
        _v_grep "``f''" "(^|[|&] )[1-4]( [|&\\]|$)"
        assert r(n) == 0
    }
}
_psc_tally `=_rc' "Excel, CSV, Markdown and LaTeX carry the same masked cells"

**# 11. Data in memory and r() unchanged apart from the three new scalars
capture noisily {
    local csv "`output_dir'/psc_t11.csv"
    clear
    input str6 lab n1 n0 tot rr
    "x" 2 10 12 1.5
    "y" 8 20 28 0.7
    "Total" 10 30 40 .
    end
    label variable n1 "Exposed"
    sort lab
    datasignature
    local sig0 "`r(datasignature)'"
    local srt0 : sortedby
    puttab lab n1 n0 tot rr, csv("`csv'") varlabels
    local s0 : r(scalars)
    local m0 : r(macros)
    foreach x in n_rows n_cols n_datarows n_panels n_spans {
        local v0_`x' = r(`x')
    }
    puttab lab n1 n0 tot rr, csv("`csv'") varlabels counts(n1 n0 tot) ///
        rowtotal(tot) totalrow(lab == "Total") withhold(n1: rr) smallcells(5)
    local s1 : r(scalars)
    local m1 : r(macros)
    local added : list s1 - s0
    local lost : list s0 - s1
    assert "`lost'" == ""
    assert `: list sizeof added' == 3
    foreach x in smallcells n_primary n_complementary {
        assert `: list x in added'
    }
    assert `: list m0 === m1'
    foreach x in n_rows n_cols n_datarows n_panels n_spans {
        assert r(`x') == `v0_`x''
    }
    datasignature
    assert "`r(datasignature)'" == "`sig0'"
    assert "`: sortedby'" == "`srt0'"
    assert c(k) == 5
    assert n1[2] == 2
    assert "`: variable label n1'" == "Exposed"
    * an error path leaves the data unchanged as well
    capture puttab lab n1 n0 tot rr, csv("`csv'") counts(n1 n0 tot) ///
        rowtotal(tot) totalrow(lab == "x") smallcells(5)
    assert _rc == 459
    datasignature
    assert "`r(datasignature)'" == "`sig0'"
    assert c(k) == 5
}
_psc_tally `=_rc' "data and r() unchanged apart from the new scalars"

**# 12. Errors: what cannot be mapped exactly is refused
capture noisily {
    local csv "`output_dir'/psc_t12.csv"
    clear
    input str6 lab e n a b tot x neg str2 s ist rid
    "x" 3 40 2 10 12 1.5 1 "q" 0 1
    "y" 9 30 8 20 28 2 -1 "r" 0 2
    "Total" 12 70 10 30 40 . 0 "t" 1 3
    end
    datasignature
    local sig0 "`r(datasignature)'"
    local base `"puttab lab e n a b tot x neg s, csv("`csv'")"'
    local i 0
    foreach spec in ///
        "198|counts(e n) fraction(e/n) smallcells(5) nosmallcells" ///
        "198|smallcells(5)" ///
        "198|withhold(e: x)" ///
        "198|fraction(e/n)" ///
        "198|rowtotal(tot)" ///
        "198|totalrow(ist)" ///
        "198|counts(e) smallcells(2)" ///
        "198|counts(e) smallcells(5, all)" ///
        "111|counts(nosuch) smallcells(5)" ///
        "198|counts(e e) smallcells(5)" ///
        "109|counts(s) smallcells(5)" ///
        "459|counts(x) smallcells(5)" ///
        "459|counts(neg) smallcells(5)" ///
        "198|counts(e) fraction(e/n) smallcells(5)" ///
        "198|counts(e n) fraction(e:n) smallcells(5)" ///
        "198|counts(e n) fraction(e/e) smallcells(5)" ///
        "459|counts(e n) fraction(n/e) smallcells(5)" ///
        "198|counts(e n) fraction(e/n) withhold(e: n) smallcells(5)" ///
        "198|counts(e n) withhold(x: e) smallcells(5)" ///
        "198|counts(e n) withhold(e x) smallcells(5)" ///
        "111|counts(e n) withhold(e: nosuch) smallcells(5)" ///
        "198|counts(a b tot) rowtotal(tot: tot a) smallcells(5)" ///
        "198|counts(a b tot) rowtotal(x) smallcells(5)" ///
        "198|counts(e n a b tot) fraction(e/n) rowtotal(tot) smallcells(5)" ///
        "198|counts(e n tot) fraction(e/n) rowtotal(tot: n) smallcells(5)" ///
        "459|counts(a b tot e) rowtotal(tot) smallcells(5)" ///
        "459|counts(a b tot) rowtotal(tot) totalrow(rid == 1) smallcells(5)" ///
        "459|counts(a b tot) totalrow(rid == 9) smallcells(5)" ///
        "459|counts(a b tot) totalrow(rid != 1) smallcells(5)" ///
        "109|counts(a b) totalrow(lab == 1) smallcells(5)" ///
        "198|counts(e n)" ///
        "198|counts(a b tot) rowtotal(tot \ tot: a b) smallcells(5)" ///
        "198|counts(a b tot e) rowtotal(tot: a b \ e: a) smallcells(5)" ///
        "198|counts(a b tot e) rowtotal(tot: a b \ e: tot) smallcells(5)" ///
        "459|counts(a b tot) smallcells(5)" {
        gettoken want opt : spec, parse("|")
        local opt = substr(`"`opt'"', 2, .)
        capture `base' `opt'
        if _rc != `want' {
            display as error `"`opt': rc=`=_rc', expected `want'"'
            exit 9
        }
        datasignature
        assert "`r(datasignature)'" == "`sig0'"
        local ++i
    }
    assert `i' == 35
    * a column not exported, partly missing counts, a second total row
    capture puttab lab e x, csv("`csv'") counts(e n) smallcells(5)
    assert _rc == 198
    capture puttab lab e x, csv("`csv'") counts(e) withhold(e: n) smallcells(5)
    assert _rc == 198
    preserve
    quietly replace n = . in 2
    capture puttab lab e n, csv("`csv'") counts(e n) fraction(e/n) smallcells(5)
    assert _rc == 416
    restore
    preserve
    quietly replace lab = "Total" in 1
    capture puttab lab a b, csv("`csv'") counts(a b) totalrow(lab == "Total") smallcells(5)
    assert _rc == 459
    restore
    * counts() names variables: never with a matrix source
    matrix M = (1, 2 \ 3, 4)
    capture puttab, matrix(M) csv("`csv'") counts(c1)
    assert _rc == 198
    datasignature
    assert "`r(datasignature)'" == "`sig0'"
}
_psc_tally `=_rc' "errors refuse every unmappable specification"

**# 13. Metamorphic: the hand-masked proportions of a do-file block
* The hand rule re-implemented on synthetic data: a group is low when n,
* e or n - e is 1..k-1; the small group's e/n becomes "<k/n" or ">=k/n"
* (blank when n itself is small); the difference and ratio go whenever
* either group is low. Where n >= k, puttab equals it except on rows where
* the hand row is recoverable by a reader who knows the rule (both e and
* n-e small beside a printed n; or ">=k/n" with too little room for e);
* there the engine masks more, and the test shows the hand row leaks and
* puttab's does not. Where n is 1..k-1 or 0 the two print differently by
* design; pinned below.
capture noisily {
    local csv "`output_dir'/psc_t13.csv"
    local k 5
    clear
    set seed 4411
    quietly set obs 60
    gen str6 lab = "o" + string(_n)
    foreach g in 1 0 {
        gen long n`g' = runiformint(0, 14)
        gen long e`g' = runiformint(0, n`g')
    }
    * force the patterns: e small, n-e small, both small, e = 0, e = n
    quietly replace n1 = 40 in 1
    quietly replace e1 = 3 in 1
    quietly replace n1 = 40 in 2
    quietly replace e1 = 38 in 2
    quietly replace n0 = 7 in 3
    quietly replace e0 = 4 in 3
    quietly replace n0 = 20 in 4
    quietly replace e0 = 0 in 4
    quietly replace n1 = 20 in 5
    quietly replace e1 = 20 in 5
    gen double diff = e1 / n1 - e0 / n0
    gen double rr = (e1 / n1) / (e0 / n0)
    * puttab input data, saved for the call
    tempfile src
    quietly save `src'
    * hand masking
    foreach g in 1 0 {
        gen str20 c_m`g' = string(e`g') + "/" + string(n`g') if n`g' > 0
        gen byte low`g' = inrange(n`g', 1, `k' - 1) | inrange(e`g', 1, `k' - 1) | ///
            inrange(n`g' - e`g', 1, `k' - 1)
    }
    gen byte sup = low1 | low0
    foreach g in 1 0 {
        replace c_m`g' = "" if low`g'
        replace c_m`g' = cond(inrange(e`g', 1, `k' - 1), "<`k'", "≥`k'") + "/" + ///
            strtrim(string(n`g', "%12.0fc")) if low`g' & !inrange(n`g', 1, `k' - 1)
    }
    replace c_m1 = strtrim(c_m1)
    replace c_m0 = strtrim(c_m0)
    gen str20 c_diff = strtrim(string(diff, "%32.2f")) if !missing(diff)
    gen str20 c_rr = strtrim(string(rr, "%32.2f")) if !missing(rr)
    * a value that rounds to zero prints without its minus sign
    foreach v in c_diff c_rr {
        replace `v' = substr(`v', 2, .) if ustrregexm(`v', "^-0[.]0+$")
    }
    foreach v in c_diff c_rr {
        replace `v' = "" if sup
    }
    keep lab n1 n0 e1 e0 c_*
    tempfile hand
    quietly save `hand'
    use `src', clear
    puttab lab e1 n1 e0 n0 diff rr, csv("`csv'") counts(e1 n1 e0 n0) ///
        fraction(e1/n1 e0/n0) withhold(e1: diff rr \ e0: diff rr) smallcells(`k')
    _psc_load "`csv'"
    quietly drop in 1
    rename (v1 v2 v3 v4 v5) (lab p_m1 p_m0 p_diff p_rr)
    quietly merge 1:1 lab using `hand', assert(match) nogenerate
    foreach c in m1 m0 diff rr {
        quietly replace p_`c' = strtrim(p_`c')
    }
    * every row with n >= k: equal, or the hand row leaks and puttab's not
    local nsame 0
    local ndiff 0
    forvalues i = 1/`=_N' {
        foreach g in 1 0 {
            if n`g'[`i'] < `k' continue
            if p_m`g'[`i'] == c_m`g'[`i'] {
                local ++nsame
                continue
            }
            local ++ndiff
            local tr = "(" + string(e`g'[`i']) + ", " + string(n`g'[`i'] - e`g'[`i']) + ", " + string(n`g'[`i']) + ")"
            mata: _f = _psc_split(st_sdata(`i', "c_m`g'"))
            mata: _psc_audit((_f[1], "", _f[2]), `tr', `k', 1, 0)
            if scalar(psc_viol) == 0 {
                display as error "row `i' group `g': hand row is safe but puttab differs"
                exit 9
            }
            mata: _f = _psc_split(st_sdata(`i', "p_m`g'"))
            mata: _psc_audit((_f[1], "", _f[2]), `tr', `k', 1, 0)
            assert scalar(psc_viol) == 0
        }
    }
    assert `nsame' >= 40
    assert `ndiff' >= 1
    display as text "  (`nsame' fractions equal the hand rule; `ndiff' hand fractions leak and are masked further)"
    * pinned differences: a small n prints "<k/<k" or "0/<k" (the hand rule
    * blanks it), n = 0 prints "0/0" (blank by hand); the withheld cells agree
    foreach g in 1 0 {
        assert inlist(p_m`g', "<`k'/<`k'", "0/<`k'") if inrange(n`g', 1, `k' - 1)
        assert c_m`g' == "" if inrange(n`g', 1, `k' - 1)
        assert p_m`g' == "0/0" if n`g' == 0
        assert c_m`g' == "" if n`g' == 0
    }
    assert p_diff == c_diff & p_rr == c_rr if n1 > 0 & n0 > 0
}
_psc_tally `=_rc' "metamorphic: hand-masked proportions equal puttab where the hand rule is sound"

**# 14. Metamorphic: the hand complementary rule for panels that add up
* The hand rule: in a group of categories adding up to a released total,
* when any count is small, the smallest other count of k or more is shown
* as ">=k". puttab (totalrow() within panel()) equals it when the group has
* one small count p whose protector c satisfies p >= 2 or c > k. Pinned:
* p = 1 with c = k (the hand table gives p back; the engine masks more),
* and two small counts (the hand rule masks a third, the engine need not).
capture noisily {
    local csv "`output_dir'/psc_t14.csv"
    local k 5
    clear
    input byte t str6 lab n1 n0 m1 m0 rr
    1 "a" 3 12 1.1 2.2 0.5
    1 "b" 9 6 3.3 4.4 0.6
    1 "c" 14 20 5.5 6.6 0.7
    1 "Total" 26 38 . . .
    2 "a" 2 30 1.2 2.3 0.8
    2 "b" 6 3 3.4 4.5 0.9
    2 "c" 8 7 5.6 6.7 1.0
    2 "Total" 16 40 . . .
    3 "a" 1 4 1.3 2.4 1.1
    3 "b" 5 2 3.5 4.6 1.2
    3 "c" 7 30 5.7 6.8 1.3
    3 "Total" 13 36 . . .
    end
    gen long row = _n
    tempfile src
    quietly save `src'
    * hand masking (category rows are the family; the total is released)
    foreach g in 1 0 {
        gen str10 c_n`g' = strtrim(string(n`g', "%12.0fc"))
        gen str10 c_m`g' = strtrim(string(m`g', "%32.2f")) if !missing(m`g')
        gen byte low`g' = inrange(n`g', 1, `k' - 1) & lab != "Total"
    }
    gen str10 c_rr = strtrim(string(rr, "%32.2f")) if !missing(rr)
    gen byte sup = low1 | low0
    gen str7 fam = cond(lab != "Total", "fam", "")
    foreach g in 1 0 {
        replace c_n`g' = "<`k'" if low`g'
        replace c_m`g' = "" if low`g'
    }
    replace c_rr = "" if sup
    foreach g in 1 0 {
        egen int nm`g' = total(inrange(n`g', 1, `k' - 1) & fam != ""), by(fam t)
        egen long mn`g' = min(cond(n`g' >= `k' & fam != "", n`g', .)), by(fam t)
        egen double rc`g' = min(cond(n`g' == mn`g', row, .)), by(fam t)
        gen byte comp`g' = fam != "" & nm`g' > 0 & row == rc`g' & !missing(mn`g')
        replace c_n`g' = "≥`k'" if comp`g'
    }
    keep row t lab n1 n0 c_* comp?
    tempfile hand
    quietly save `hand'
    use `src', clear
    puttab lab n1 n0 m1 m0 rr, panel(t) noindent csv("`csv'") counts(n1 n0) ///
        totalrow(lab == "Total") withhold(n1: m1 rr \ n0: m0 rr) smallcells(`k')
    _psc_load "`csv'"
    * drop the header and the three panel heading rows
    quietly drop if _n == 1 | inlist(v1, "1", "2", "3")
    gen long row = _n
    rename (v2 v3 v4 v5 v6) (p_n1 p_n0 p_m1 p_m0 p_rr)
    quietly merge 1:1 row using `hand', assert(match) nogenerate
    * panel 1, n1 (one small 3, protector 9) and n0 (none small); panel 2,
    * n1 (2, protector 6) and n0 (3, protector 7): the hand rule is sound
    foreach g in 1 0 {
        assert p_n`g' == c_n`g' if inlist(t, 1, 2)
    }
    * panel 3, n1: p = 1 beside c = 5 -- the hand table leaks the 1; the
    * engine protects it with the 7 and prints the 5
    assert p_n1[9] == "<`k'" & p_n1[10] == "5" & p_n1[11] == "≥`k'" & p_n1[12] == "13"
    assert c_n1[9] == "<`k'" & c_n1[10] == "≥`k'" & c_n1[11] == "7"
    mata: _psc_audit(st_sdata((9, 10, 11, 12)', "c_n1"), (1 \ 5 \ 7 \ 13), `k', 0, 1)
    assert scalar(psc_viol) > 0
    mata: _psc_audit(st_sdata((9, 10, 11, 12)', "p_n1"), (1 \ 5 \ 7 \ 13), `k', 0, 1)
    assert scalar(psc_viol) == 0
    * panel 3, n0: two small counts (4 and 2, sum 6 known) keep two values
    * each with no third cell masked; the hand rule masks the 30 as well
    assert p_n0[9] == "<`k'" & p_n0[10] == "<`k'" & p_n0[11] == "30"
    assert c_n0[11] == "≥`k'"
    mata: _psc_audit(st_sdata((9, 10, 11, 12)', "p_n0"), (4 \ 2 \ 30 \ 36), `k', 0, 1)
    assert scalar(psc_viol) == 0
    * the withheld cells: puttab also blanks a complementary row's rate and
    * ratio (withhold() keys on any masked count); elsewhere they agree
    foreach c in m1 m0 rr {
        quietly replace p_`c' = strtrim(p_`c')
    }
    assert p_m1 == c_m1 if !comp1 & t != 3
    assert p_m0 == c_m0 if !comp0 & t != 3
    assert p_m1 == "" & c_m1 != "" if comp1 & t != 3
    assert p_rr == c_rr if !comp1 & !comp0 & t != 3
}
_psc_tally `=_rc' "metamorphic: hand complementary rule equals puttab where sound; stricter cases pinned"

**# 15. The spec's target call (Table 2) end to end on synthetic data
capture noisily {
    local book "`output_dir'/psc_t15.xlsx"
    capture erase "`book'"
    global mincell 5
    global xlsx "`book'"
    clear
    input str40 outcome e1 n1 e0 n0 rr0 lb0 ub0 rr1 lb1 ub1
    "Preterm birth" 12 160 230 3200 1.4 0.8 2.5 1.3 0.7 2.4
    "Stillbirth" 2 160 11 3200 3.6 0.8 16 3.1 0.7 14
    "Caesarean section" 157 160 2900 3200 1.1 1.0 1.2 1.1 1.0 1.2
    "Low birth weight" 0 160 140 3200 . . . . . .
    end
    label variable outcome "Outcome"
    label variable e1 "Exposed, n/N"
    label variable e0 "Unexposed, n/N"
    label variable rr0 "Crude RR"
    label variable lb0 "Lower"
    label variable ub0 "Upper"
    label variable rr1 "Adjusted RR"
    label variable lb1 "Lower"
    label variable ub1 "Upper"
    tempfile estimates
    quietly save `estimates'
    use `estimates', clear
    puttab outcome e1 n1 e0 n0 rr0 lb0 ub0 rr1 lb1 ub1 using "$xlsx", sheet("Table 2") varlabels digits(2) ///
        smallcells($mincell) counts(e1 n1 e0 n0) fraction(e1/n1 e0/n0) ///
        withhold(e1: rr0 lb0 ub0 rr1 lb1 ub1 \ e0: rr0 lb0 ub0 rr1 lb1 ub1) ///
        title("Table 2. Pregnancy outcomes by maternal narcolepsy") ///
        footnote("RR, risk ratio; CI, confidence interval. Adjusted for maternal age, calendar year and parity.")
    assert r(n_cols) == 9
    assert r(n_primary) == 2
    assert r(n_complementary) == 1
    assert r(smallcells) == 5
    _v_facts "`book'" "Table 2"
    _v_value A1 "Table 2. Pregnancy outcomes by maternal narcolepsy"
    _v_value C2 "Exposed, n/N"
    _v_value D2 "Unexposed, n/N"
    _v_value E2 "Crude RR"
    _v_value C3 "12/160"
    _v_value D3 "230/3200"
    _v_value E3 "1.40"
    * stillbirth: 2 exposed is masked and its ratios withheld
    _v_value C4 "<5/160"
    _v_value D4 "11/3200"
    foreach c in E F G H I J {
        _v_empty `c'4
    }
    * caesarean: 160 - 157 = 3 without the outcome, so 157 shows as >=5
    _v_value C5 "≥5/160"
    _v_empty E5
    _v_value C6 "0/160"
    _v_value B7 "RR, risk ratio; CI, confidence interval. Adjusted for maternal age, calendar year and parity."
    * the estimates on disk are unchanged
    datasignature
    local s1 "`r(datasignature)'"
    use `estimates', clear
    datasignature
    assert "`r(datasignature)'" == "`s1'"
}
local _rc_save = _rc
macro drop mincell xlsx
_psc_tally `_rc_save' "target call (Table 2) runs end to end and masks as specified"

**# 16. frame() source, if/in, and a totalrow() expression on an unexported column
capture noisily {
    local csv "`output_dir'/psc_t16.csv"
    clear
    input str6 lab byte istot n1 n0 keep
    "x" 0 2 10 1
    "y" 0 8 20 1
    "z" 0 9 30 1
    "T" 1 19 60 1
    "drop" 0 1 1 0
    end
    frame copy default psc_src, replace
    clear
    frame psc_src: puttab lab n1 n0 if keep, csv("`csv'") counts(n1 n0) ///
        totalrow(istot) smallcells(5)
    assert r(n_datarows) == 4
    _psc_load "`csv'"
    assert c(k) == 3
    _psc_col 2 2 "<5" "≥5" "9" "19"
    _psc_col 3 2 "10" "20" "30" "60"
    puttab lab n1 n0 in 1/4, frame(psc_src) csv("`csv'") counts(n1 n0) ///
        totalrow(istot == 1) smallcells(5)
    _psc_load "`csv'"
    _psc_col 2 2 "<5" "≥5" "9" "19"
    frame drop psc_src
}
local _rc_save = _rc
capture frame drop psc_src
_psc_tally `_rc_save' "frame() source, if/in, totalrow() on an unexported column"

**# 17. Several rowtotal() sums, undeclared sums, no threshold, block limit
capture noisily {
    local csv "`output_dir'/psc_t17.csv"
    * two total columns, each declared: n1 = 43 - 40 is protected by n0
    clear
    input str3 lab e1 e0 etot n1 n0 ntot
    "r1" 30 41 71 3 40 43
    "r2" 30 40 70 30 41 71
    end
    tempfile two
    quietly save `two'
    puttab lab e1 e0 etot n1 n0 ntot, csv("`csv'") smallcells(5) ///
        counts(e1 e0 etot n1 n0 ntot) rowtotal(etot: e1 e0 \ ntot: n1 n0)
    assert r(n_primary) == 1
    assert r(n_complementary) == 1
    _psc_load "`csv'"
    _psc_col 5 2 "<5" "30"
    _psc_col 6 2 "≥5" "41"
    _psc_col 7 2 "43" "71"
    matrix T = (30, 41, 71, 3, 40, 43 \ 30, 40, 70, 30, 41, 71)
    forvalues r = 1/2 {
        mata: _psc_audit(_psc_grab(`r' + 1, (2, 3, 4)), st_matrix("T")[`r', 1..3], 5, 1, 0)
        assert scalar(psc_viol) == 0
        mata: _psc_audit(_psc_grab(`r' + 1, (5, 6, 7)), st_matrix("T")[`r', 4..6], 5, 1, 0)
        assert scalar(psc_viol) == 0
    }
    * the second sum left undeclared: refused, not printed
    use `two', clear
    capture erase "`csv'"
    capture noisily puttab lab e1 e0 etot n1 n0 ntot, csv("`csv'") smallcells(5) ///
        counts(e1 e0 etot n1 n0 ntot) rowtotal(etot: e1 e0)
    assert _rc == 459
    confirm new file "`csv'"
    * no sum declared at all; a total of fraction numerators cannot be
    * declared, so it is refused too
    capture puttab lab n1 n0 ntot, csv("`csv'") smallcells(5) counts(n1 n0 ntot)
    assert _rc == 459
    clear
    input str3 lab e1 n1 e0 n0 etot
    "r1" 3 40 10 50 13
    end
    capture puttab lab e1 n1 e0 n0 etot, csv("`csv'") smallcells(5) ///
        counts(e1 n1 e0 n0 etot) fraction(e1/n1 e0/n0)
    assert _rc == 459
    * an undeclared sum is fine when no addend is masked, and under primary
    * (which protects printed counts only, by request)
    clear
    input str3 lab a b tot
    "r1" 6 40 46
    "r2" 0 9 9
    end
    puttab lab a b tot, csv("`csv'") smallcells(5) counts(a b tot)
    assert r(n_primary) == 0
    replace a = 3 in 1
    replace tot = 43 in 1
    puttab lab a b tot, csv("`csv'") smallcells(5, primary) counts(a b tot)
    assert r(n_primary) == 1
    _psc_load "`csv'"
    _psc_col 2 2 "<5" "0"
    _psc_col 4 2 "43" "9"
    * counts() needs a threshold: none given and no session default is an
    * error; nosmallcells prints the counts raw on request
    clear
    input str3 lab a b
    "r1" 3 40
    end
    tabtools set clear
    capture puttab lab a b, csv("`csv'") counts(a b)
    assert _rc == 198
    puttab lab a b, csv("`csv'") counts(a b) nosmallcells
    assert r(smallcells) == 0
    _psc_load "`csv'"
    _psc_col 2 2 "3"
    * block limit with a total row: 60 cells per rowtotal() sum, 60 rows
    * otherwise; refused before the engine runs, allowed at the limit and
    * under primary. One small count keeps the allowed calls quick.
    foreach nr in 20 21 {
        clear
        quietly set obs `nr'
        gen str8 lab = "r" + string(_n)
        gen a = 10
        gen b = 20
        gen c = 30
        quietly replace a = 2 in 1
        gen tot = a + b + c
        quietly set obs `=`nr' + 1'
        quietly replace lab = "Total" in L
        foreach v in a b c tot {
            quietly summarize `v'
            quietly replace `v' = r(sum) in L
        }
        capture noisily puttab lab a b c tot, csv("`csv'") smallcells(5) ///
            counts(a b c tot) rowtotal(tot: a b c) totalrow(lab == "Total")
        assert _rc == cond(`nr' == 20, 0, 459)
        if `nr' == 21 {
            puttab lab a b c tot, csv("`csv'") smallcells(5, primary) ///
                counts(a b c tot) rowtotal(tot: a b c) totalrow(lab == "Total")
            assert r(n_primary) == 1
        }
    }
    foreach nr in 60 61 {
        clear
        quietly set obs `nr'
        gen str8 lab = "r" + string(_n)
        gen n = 10
        quietly replace n = 2 in 1
        quietly set obs `=`nr' + 1'
        quietly replace lab = "Total" in L
        quietly summarize n
        quietly replace n = r(sum) in L
        capture noisily puttab lab n, csv("`csv'") smallcells(5) counts(n) ///
            totalrow(lab == "Total")
        assert _rc == cond(`nr' == 60, 0, 459)
    }
    * split into panels, each with its own total row, 61 rows pass
    clear
    quietly set obs 63
    gen byte blk = 1 + (_n > 31)
    gen str8 lab = cond(inlist(_n, 31, 63), "Total", "r" + string(_n))
    gen n = 10
    quietly replace n = 2 in 1
    quietly summarize n in 1/30
    quietly replace n = r(sum) in 31
    quietly summarize n in 32/62
    quietly replace n = r(sum) in 63
    puttab lab n, panel(blk) csv("`csv'") smallcells(5) counts(n) ///
        totalrow(lab == "Total")
    assert r(n_primary) == 1
}
local _rc_save = _rc
tabtools set clear
_psc_tally `_rc_save' "several rowtotal() sums, undeclared sums refused, threshold required, block limit"

capture erase "$V230_RES"
macro drop V230_TOOL V230_RES
local test_count = $PSC_tests
local pass_count = $PSC_pass
local fail_count = $PSC_fail
macro drop PSC_tests PSC_pass PSC_fail
display "RESULT: test_puttab_smallcells tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _psc
if `fail_count' > 0 exit 1
