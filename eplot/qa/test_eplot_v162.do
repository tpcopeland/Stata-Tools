*! test_eplot_v162.do - Regression tests for eplot 1.6.2
*! Covers mixed, dfmethod(kroger | satterthwaite) intervals and p-values against
*! Stata's own r(table); keep() and drop() refusing a term that matches nothing
*! (estimates, data and matrix modes) while a multi-model plot may name a term
*! one model lacks, and eq:name selection of a matrix row; values text at dp(5),
*! dp(8), dp(0) and a rounded negative zero, read from export() and compared
*! with string(round(x, 10^-dp), "%.dpf") computed here from Stata's own
*! r(table) or from constants; matrix-mode coeflabels() applied after order();
*! groups() gathering members under their header and refusing a coefficient in
*! two groups; a data-mode values vcolor() RGB triplet with export(); the note
*! for a coefficient constrained by cnsreg; no missing-values text from order();
*! thinned decade ticks on a logscale axis wider than twelve decades; rename()
*! swaps and collisions against e(b); and no leak of the caller's r() results
*! in frame mode.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_v162.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Counts the lines of a text file that contain a string.
capture program drop _v162_grep
program define _v162_grep, rclass
    version 16.0
    syntax , File(string) Text(string asis)
    gettoken text : text
    tempname fh
    local n 0
    file open `fh' using "`file'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`text'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

**## 1. mixed, dfmethod(kroger): ll, ul and p equal Stata's r(table)
local ++test_count
capture noisily {
    capture frame drop v162_f8
    sysuse auto, clear
    gen id = mod(_n, 10)
    quietly mixed price mpg weight || id:, reml dfmethod(kroger)
    matrix S = r(table)
    eplot ., drop(_cons) nodraw
    matrix E = r(table)
    matrix P = r(pvalues)
    assert rowsof(E) == 2 & rowsof(P) == 2
    forvalues j = 1/2 {
        assert !missing(S[5, `j'], E[`j', 2], S[6, `j'], E[`j', 3], S[4, `j'], P[`j', 1], S[1, `j'], E[`j', 1])
        assert !missing(E[`j', 1], S[1, `j'])
        assert reldif(E[`j', 1], S[1, `j']) < 1e-8
        assert !missing(E[`j', 2], S[5, `j'])
        assert reldif(E[`j', 2], S[5, `j']) < 1e-8
        assert !missing(E[`j', 3], S[6, `j'])
        assert reldif(E[`j', 3], S[6, `j']) < 1e-8
        assert !missing(P[`j', 1], S[4, `j'])
        assert reldif(P[`j', 1], S[4, `j']) < 1e-8
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 2. mixed, dfmethod(satterthwaite): ll, ul and p equal Stata's r(table)
local ++test_count
capture noisily {
    sysuse auto, clear
    gen id = mod(_n, 10)
    quietly mixed price mpg weight || id:, reml dfmethod(satterthwaite)
    matrix S = r(table)
    eplot ., drop(_cons) nodraw
    matrix E = r(table)
    matrix P = r(pvalues)
    assert rowsof(E) == 2 & rowsof(P) == 2
    forvalues j = 1/2 {
        assert !missing(S[5, `j'], E[`j', 2], S[6, `j'], E[`j', 3], S[4, `j'], P[`j', 1])
        assert !missing(E[`j', 2], S[5, `j'])
        assert reldif(E[`j', 2], S[5, `j']) < 1e-8
        assert !missing(E[`j', 3], S[6, `j'])
        assert reldif(E[`j', 3], S[6, `j']) < 1e-8
        assert !missing(P[`j', 1], S[4, `j'])
        assert reldif(P[`j', 1], S[4, `j']) < 1e-8
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 3. keep() and drop() naming nothing exit 198 in estimates mode
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight length
    capture noisily eplot ., keep(mpg wieght) nodraw
    assert _rc == 198
    capture noisily eplot ., drop(wieght) nodraw
    assert _rc == 198
    * Controls: correct names are accepted and select the right rows.
    eplot ., keep(mpg weight) nodraw
    assert r(k) == 2
    matrix T = r(table)
    assert !missing(T[1, 1], _b[mpg], T[2, 1], _b[weight])
    assert reldif(T[1, 1], _b[mpg]) < 1e-12 & reldif(T[2, 1], _b[weight]) < 1e-12
    eplot ., drop(length _cons) nodraw
    assert r(k) == 2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 4. keep() and drop() naming nothing exit 198 in data mode
local ++test_count
capture noisily {
    clear
    input str8 lab double(es lo hi)
    "alpha" 1 .5 1.5
    "beta"  2 1.5 2.5
    "gamma" 3 2 4
    end
    capture noisily eplot es lo hi, labels(lab) keep(alpha betta) nodraw
    assert _rc == 198
    capture noisily eplot es lo hi, labels(lab) drop(betta) nodraw
    assert _rc == 198
    eplot es lo hi, labels(lab) keep(alpha gamma) nodraw
    assert r(k) == 2
    matrix T = r(table)
    assert T[1, 1] == 1 & T[2, 1] == 3
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 5. keep() and drop() naming nothing exit 198 in matrix mode
local ++test_count
capture noisily {
    matrix M = (1, .5, 1.5 \ 2, 1.5, 2.5 \ 3, 2, 4)
    matrix rownames M = alpha beta gamma
    capture noisily eplot, matrix(M) keep(alpha betta) nodraw
    assert _rc == 198
    capture noisily eplot, matrix(M) drop(betta) nodraw
    assert _rc == 198
    eplot, matrix(M) drop(beta) nodraw
    assert r(k) == 2
    matrix T = r(table)
    assert T[1, 1] == 1 & T[2, 1] == 3
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 6. Matrix keep(eq:name) selects exactly that row
local ++test_count
capture noisily {
    matrix M = (1, .5, 1.5 \ 2, 1.5, 2.5 \ 3, 2, 4)
    matrix rownames M = x y z
    matrix roweq M = a b b
    eplot, matrix(M) keep(a:x) nodraw
    assert r(k) == 1
    matrix T = r(table)
    assert rowsof(T) == 1 & T[1, 1] == 1 & T[1, 2] == .5 & T[1, 3] == 1.5
    eplot, matrix(M) keep(b:y) nodraw
    assert r(k) == 1
    matrix T = r(table)
    assert T[1, 1] == 2 & T[1, 2] == 1.5 & T[1, 3] == 2.5
    eplot, matrix(M) drop(a:x) nodraw
    assert r(k) == 2
    matrix T = r(table)
    assert T[1, 1] == 2 & T[2, 1] == 3
    capture noisily eplot, matrix(M) keep(a:y) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 7. A multi-model term present in only one model does not error
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store v162_m1
    quietly regress price mpg weight length
    estimates store v162_m2
    eplot v162_m1 v162_m2, keep(mpg length) nodraw
    assert r(k) == 2
    eplot v162_m1 v162_m2, drop(length _cons) nodraw
    assert r(k) == 2
    * A term in neither model still refuses.
    capture noisily eplot v162_m1 v162_m2, keep(mpg lenght) nodraw
    assert _rc == 198
    estimates drop v162_m1 v162_m2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 8. values text at dp(5) and dp(8), estimates mode, hand-written strings
local ++test_count
capture noisily {
    capture frame drop v162_f8
    sysuse auto, clear
    quietly regress price mpg weight
    * Literals: regress's r(table) b, ll, ul (17 digits) rounded half away from
    * zero to 5 and to 8 decimals by exact decimal arithmetic outside Stata.
    matrix T0 = r(table)
    assert !missing(T0[1, 1], T0[5, 1])
    assert reldif(T0[1, 1], -49.512220666356171) < 1e-13 & reldif(T0[5, 1], -221.30248296542905) < 1e-13
    assert !missing(T0[6, 1], T0[1, 2])
    assert reldif(T0[6, 1], 122.27804163271671) < 1e-13 & reldif(T0[1, 2], 1.7465591583457509) < 1e-13
    assert !missing(T0[5, 2], T0[6, 2])
    assert reldif(T0[5, 2], .46773602346915921) < 1e-13 & reldif(T0[6, 2], 3.0253822932223429) < 1e-13
    eplot ., keep(mpg weight) values dp(5) export(v162_f8, replace) nodraw
    frame v162_f8 {
        assert values[1] == "-49.51222 (-221.30248, 122.27804)"
        assert values[2] == "1.74656 (0.46774, 3.02538)"
    }
    frame drop v162_f8
    eplot ., keep(mpg weight) values dp(8) export(v162_f8, replace) nodraw
    frame v162_f8 {
        assert values[1] == "-49.51222067 (-221.30248297, 122.27804163)"
        assert values[2] == "1.74655916 (0.46773602, 3.02538229)"
    }
    frame drop v162_f8
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 9. values text at dp(5) and dp(8), matrix mode, against constants
local ++test_count
capture noisily {
    capture frame drop v162_f9
    matrix M = (1.234567891, 0.123456786, 12.3456789123)
    matrix rownames M = a
    eplot, matrix(M) values dp(5) export(v162_f9, replace) nodraw
    frame v162_f9 {
        assert values[1] == "1.23457 (0.12346, 12.34568)"
    }
    frame drop v162_f9
    eplot, matrix(M) values dp(8) export(v162_f9, replace) nodraw
    frame v162_f9 {
        assert values[1] == "1.23456789 (0.12345679, 12.34567891)"
    }
    frame drop v162_f9
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 10. values text at dp(5) and dp(8), data mode, hand-written strings
local ++test_count
capture noisily {
    capture frame drop v162_f10
    clear
    input str8 lab double(es lo hi)
    "one" 1.234567891 0.123456786 12.3456789123
    "two" -2.5 -3.25 -0.000004
    end
    eplot es lo hi, labels(lab) values dp(5) export(v162_f10, replace) nodraw
    frame v162_f10 {
        assert _N == 2
        assert values[1] == "1.23457 (0.12346, 12.34568)"
        assert values[2] == "-2.50000 (-3.25000, 0.00000)"
    }
    frame drop v162_f10
    eplot es lo hi, labels(lab) values dp(8) export(v162_f10, replace) nodraw
    frame v162_f10 {
        assert values[1] == "1.23456789 (0.12345679, 12.34567891)"
        assert values[2] == "-2.50000000 (-3.25000000, -0.00000400)"
    }
    frame drop v162_f10
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 11. Matrix coeflabels() applies after order()
local ++test_count
capture noisily {
    capture frame drop v162_f12
    matrix M = (1, .5, 1.5 \ 2, 1.5, 2.5 \ 3, 2, 4)
    matrix rownames M = A B C
    eplot, matrix(M) coeflabels(A = "Alpha" B = "Beta") order(C A) nodraw
    assert r(k) == 3
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "C Alpha Beta"
    assert T[1, 1] == 3 & T[2, 1] == 1 & T[3, 1] == 2
    * A label equal to another row's name: order() still reads the original.
    eplot, matrix(M) coeflabels(A = "B" B = "Z") order(B) nodraw
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "Z B C"
    assert T[1, 1] == 2 & T[2, 1] == 1 & T[3, 1] == 3
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 12. groups() puts each member directly under its header
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight length
    local bm = _b[mpg]
    local bw = _b[weight]
    local bl = _b[length]
    eplot ., keep(mpg weight length) groups(weight mpg = "G1" length = "G2") ///
        export(v162_f12, replace) nodraw
    frame v162_f12 {
        assert _N == 5
        quietly levelsof pos if label == "G1", local(p1)
        quietly levelsof pos if label == "G2", local(p2)
        assert `p1' == 1 & `p2' == 4
        * Rows 2 and 3 are G1's members (mpg and weight in either order).
        assert type[1] == 0 & type[4] == 0 & type[2] == 1 & type[3] == 1 & type[5] == 1
        assert !missing(estimate[2], `bm', estimate[3], `bw')
        assert (reldif(estimate[2], `bm') < 1e-8 & reldif(estimate[3], `bw') < 1e-8) | ///
            (reldif(estimate[2], `bw') < 1e-8 & reldif(estimate[3], `bm') < 1e-8)
        assert !missing(estimate[5], `bl')
        assert reldif(estimate[5], `bl') < 1e-8
    }
    frame drop v162_f12
    * Members separated by an ungrouped coefficient are still gathered.
    eplot ., keep(mpg weight length) groups(mpg length = "G1") ///
        export(v162_f12, replace) nodraw
    frame v162_f12 {
        quietly levelsof pos if label == "G1", local(p1)
        assert `p1' == 1
        assert !missing(estimate[2], `bm', estimate[3], `bl')
        assert (reldif(estimate[2], `bm') < 1e-8 & reldif(estimate[3], `bl') < 1e-8) | ///
            (reldif(estimate[2], `bl') < 1e-8 & reldif(estimate[3], `bm') < 1e-8)
        assert !missing(estimate[_N], `bw')
        assert reldif(estimate[_N], `bw') < 1e-8
    }
    frame drop v162_f12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 13. A coefficient listed in two groups exits 198
local ++test_count
capture noisily {
    capture frame drop v162_f14
    sysuse auto, clear
    quietly regress price mpg weight length
    capture noisily eplot ., keep(mpg weight length) ///
        groups(mpg weight = "G1" weight length = "G2") nodraw
    assert _rc == 198
    * Control: disjoint groups are accepted.
    eplot ., keep(mpg weight length) groups(mpg weight = "G1" length = "G2") nodraw
    assert r(k) == 3
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 14. Data mode: values vcolor() RGB triplet with export()
local ++test_count
capture noisily {
    clear
    input str8 lab double(es lo hi)
    "one"   1 .5 1.5
    "two"   2 1.5 2.5
    "three" 3 2 4
    end
    capture noisily eplot es lo hi, labels(lab) values vcolor("0 128 0") ///
        export(v162_f14) nodraw
    assert _rc == 0
    frame v162_f14 {
        assert _N == 3
        assert estimate[1] == 1 & estimate[2] == 2 & estimate[3] == 3
        assert values[2] == "2.00 (1.50, 2.50)"
    }
    frame drop v162_f14
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 15. cnsreg: the constrained coefficient is omitted with a note
local ++test_count
capture noisily {
    capture log close v162_l15
    sysuse auto, clear
    constraint define 1 mpg = 2
    quietly cnsreg price mpg weight length, constraints(1)
    * The constrained coefficient has exactly zero variance in Stata's own V.
    matrix V = e(V)
    assert V[1, 1] == 0
    tempfile lf
    log using "`lf'", text replace name(v162_l15)
    display "V162-LOG-CONTROL"
    eplot ., drop(_cons) nodraw
    local k15 = r(k)
    matrix T15 = r(table)
    log close v162_l15
    _v162_grep, file("`lf'") text("V162-LOG-CONTROL")
    assert !missing(r(n))
    assert r(n) >= 1
    _v162_grep, file("`lf'") text("(note: zero-variance (constrained) coefficient(s) omitted: mpg)")
    assert r(n) == 1
    _v162_grep, file("`lf'") text("omitted")
    assert !missing(r(n))
    assert r(n) >= 1
    assert `k15' == 2
    matrix T = T15
    assert rowsof(T) == 2
    local rn : rownames T
    assert strpos(lower("`rn'"), "mileage") == 0 & strpos(lower("`rn'"), "mpg") == 0
    * The unconstrained rows match Stata's own coefficients.
    assert !missing(T[1, 1], _b[weight], T[2, 1], _b[length])
    assert reldif(T[1, 1], _b[weight]) < 1e-8 & reldif(T[2, 1], _b[length]) < 1e-8
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 16. order() prints no missing-values message
local ++test_count
capture noisily {
    capture log close v162_l16
    sysuse auto, clear
    quietly regress price mpg weight length
    matrix M = (1, .5, 1.5 \ 2, 1.5, 2.5 \ 3, 2, 4)
    matrix rownames M = A B C
    clear
    input str8 lab double(es lo hi)
    "one"   1 .5 1.5
    "two"   2 1.5 2.5
    "three" 3 2 4
    end
    tempfile lf
    log using "`lf'", text replace name(v162_l16)
    display "V162-LOG-CONTROL"
    sysuse auto, clear
    quietly regress price mpg weight length
    eplot ., drop(_cons) order(length mpg) nodraw
    eplot, matrix(M) order(C A) nodraw
    clear
    input str8 lab double(es lo hi)
    "one"   1 .5 1.5
    "two"   2 1.5 2.5
    "three" 3 2 4
    end
    eplot es lo hi, labels(lab) order(three one) nodraw
    log close v162_l16
    _v162_grep, file("`lf'") text("V162-LOG-CONTROL")
    assert !missing(r(n))
    assert r(n) >= 1
    * The log does hold the commands' own output, so a hit would be seen.
    _v162_grep, file("`lf'") text("order(")
    assert !missing(r(n))
    assert r(n) >= 3
    _v162_grep, file("`lf'") text("missing value")
    assert r(n) == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 17. logscale over sixteen decades: thinned decade ticks, at most twelve
local ++test_count
capture noisily {
    capture frame drop v162_f18
    matrix L = (1e-8, 1e-9, 1e-7 \ 1, .5, 2 \ 1e8, 1e7, 1e9)
    matrix rownames L = a b c
    eplot, matrix(L) logscale nodraw
    local cmd `"`r(cmd)'"'
    assert regexm(`"`cmd'"', "xlabel\(([^)]*)\)")
    local body = regexs(1)
    gettoken body : body, parse(",")
    local n 0
    local k 0
    local prev .
    local i 0
    while `"`body'"' != "" {
        gettoken tok body : body
        local ++i
        if mod(`i', 2) == 1 {
            local v = real("`tok'")
            assert !missing(`v') & `v' > 0
            local ++n
            if `n' == 1 local first = `v'
            local last = `v'
            if `n' > 1 {
                local lr = log10(`v' / `prev')
                assert `lr' > 0.5 & abs(`lr' - round(`lr')) < 1e-6
            }
            local prev = `v'
        }
    }
    assert `n' >= 3 & `n' <= 12
    assert `first' <= 1.0001e-8 & `last' >= 0.9999e8
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 18. Rounded zero prints without a sign; dp(0) rounds half up
local ++test_count
capture noisily {
    matrix M = (-0.001, -0.004, 0.004 \ -0.001, -0.3, 0.2 \ -0.0049, -0.0051, -0.0001)
    matrix rownames M = a b c
    eplot, matrix(M) values dp(2) export(v162_f18, replace) nodraw
    frame v162_f18 {
        assert values[1] == "0.00 (0.00, 0.00)"
        assert values[2] == "0.00 (-0.30, 0.20)"
        assert values[3] == "0.00 (-0.01, 0.00)"
    }
    frame drop v162_f18
    matrix H = (12.5, 11.5, 13.5)
    matrix rownames H = a
    eplot, matrix(H) values dp(0) export(v162_f18, replace) nodraw
    frame v162_f18 {
        assert values[1] == "13 (12, 14)"
    }
    frame drop v162_f18
    * Data mode.
    clear
    input str4 lab double(es lo hi)
    "a" -0.001 -0.004 0.004
    "b" 12.5 11.5 13.5
    end
    eplot es lo hi, labels(lab) values dp(2) export(v162_f18, replace) nodraw
    frame v162_f18 {
        assert values[1] == "0.00 (0.00, 0.00)"
        assert values[2] == "12.50 (11.50, 13.50)"
    }
    frame drop v162_f18
    eplot es lo hi, labels(lab) values dp(0) export(v162_f18, replace) nodraw
    frame v162_f18 {
        assert values[2] == "13 (12, 14)"
    }
    frame drop v162_f18
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 19. rename() swaps two coefficients, checked against e(b)
local ++test_count
capture noisily {
    capture frame drop v162_fr
    sysuse auto, clear
    quietly regress price mpg weight
    local bm = _b[mpg]
    local bw = _b[weight]
    eplot ., drop(_cons) rename(mpg = weight weight = mpg) nodraw
    matrix T = r(table)
    local rn : rownames T
    * Row 1 is the original mpg coefficient, now called weight, and keeps
    * mpg's estimate; the variable label follows the new name.
    assert !missing(T[1, 1], `bm', T[2, 1], `bw')
    assert reldif(T[1, 1], `bm') < 1e-12 & reldif(T[2, 1], `bw') < 1e-12
    local rn = lower("`rn'")
    assert strpos("`rn'", "weight") > 0 & strpos("`rn'", "mileage") > 0
    assert strpos("`rn'", "weight") < strpos("`rn'", "mileage")
    * A chain renames each coefficient once.
    eplot ., drop(_cons) rename(mpg = weight weight = length) nodraw
    matrix T = r(table)
    assert !missing(T[1, 1], `bm', T[2, 1], `bw')
    assert reldif(T[1, 1], `bm') < 1e-12 & reldif(T[2, 1], `bw') < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 20. rename() of two originals to one name exits 198
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    capture noisily eplot ., drop(_cons) rename(mpg = x weight = x) nodraw
    assert _rc == 198
    capture noisily eplot ., drop(_cons) rename(mpg = weight weight = weight) nodraw
    assert _rc == 198
    capture noisily eplot ., drop(_cons) rename(mpg = a mpg = b) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 21. Frame mode does not leak the caller's r() results
* Guard: 1.6.1 already returned nothing stale on these routes (its wrapper
* gated on a complete result set), so this passes on both versions.
local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop v162_fr
    frame create v162_fr
    frame v162_fr {
        input str6 label double(estimate ll ul)
        "a" 1 .5 1.5
        "b" 2 1.5 2.5
        end
    }
    quietly summarize price, detail
    assert !missing(r(mean), r(sd), r(p50), r(Var))
    eplot, frame(v162_fr) nodraw
    assert r(k) == 2
    assert missing(r(mean)) & missing(r(sd)) & missing(r(p50)) & missing(r(Var))
    assert "`r(mean)'" == "" & "`r(sd)'" == ""
    * A prior eplot leaves r(pvalues) behind; the frame plot has no p-values,
    * so none may be returned, and r(table) is the frame's two rows.
    quietly regress price mpg weight length
    eplot ., drop(_cons) nodraw
    matrix P = r(pvalues)
    assert rowsof(P) == 3
    eplot, frame(v162_fr) nodraw
    assert r(k) == 2 & r(N) == 2
    matrix T = r(table)
    assert rowsof(T) == 2 & T[1, 1] == 1 & T[2, 1] == 2
    local rmats : r(matrices)
    assert "`rmats'" == "table"
    * A frame-mode call that fails inside the data helper must not hand back
    * the previous plot's N, k, cmd and table as its own.
    eplot ., drop(_cons) nodraw
    local prev_cmd `"`r(cmd)'"'
    assert `"`prev_cmd'"' != ""
    capture noisily eplot, frame(v162_fr) vformat(abc) nodraw
    assert _rc != 0
    local rmats : r(matrices)
    assert "`rmats'" == "" & missing(r(N)) & missing(r(k))
    assert `"`r(cmd)'"' != `"`prev_cmd'"'
    frame drop v162_fr
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 22. Values rounding is half away from zero on decimal values (dp(2), dp(0))
local ++test_count
capture noisily {
    capture frame drop v162_f22
    matrix R = (0.125, 0.125, 0.125 \ -0.125, -0.125, -0.125 \ 0.135, 0.135, 0.135 \ 2.675, 2.675, 2.675 \ 1.005, 1.005, 1.005 \ -0.001, -0.004, 0.004 \ -0.135, -2.675, -1.005)
    matrix rownames R = a b c d e f g
    eplot, matrix(R) values dp(2) export(v162_f22, replace) nodraw nonull
    frame v162_f22 {
        assert _N == 7
        assert values[1] == "0.13 (0.13, 0.13)"
        assert values[2] == "-0.13 (-0.13, -0.13)"
        assert values[3] == "0.14 (0.14, 0.14)"
        assert values[4] == "2.68 (2.68, 2.68)"
        assert values[5] == "1.01 (1.01, 1.01)"
        assert values[6] == "0.00 (0.00, 0.00)"
        assert values[7] == "-0.14 (-2.68, -1.01)"
    }
    frame drop v162_f22
    matrix Z = (12.5, 11.5, 13.5 \ -12.5, -13.5, -11.5 \ 0.4, -0.4, 0.5)
    matrix rownames Z = a b c
    eplot, matrix(Z) values dp(0) export(v162_f22, replace) nodraw nonull
    frame v162_f22 {
        assert values[1] == "13 (12, 14)"
        assert values[2] == "-13 (-14, -12)"
        assert values[3] == "0 (0, 1)"
    }
    frame drop v162_f22
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 23. drop(_cons) on a model with no constant is not an error; an unknown name still is
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly stcox i.drug age
    local e2 = exp(_b[2.drug])
    local e3 = exp(_b[3.drug])
    local ea = exp(_b[age])
    capture noisily eplot ., drop(_cons) eform nodraw
    assert _rc == 0
    assert r(k) == 3
    matrix T = r(table)
    assert !missing(T[1, 1], T[2, 1], T[3, 1], `e2', `e3', `ea')
    assert reldif(T[1, 1], `e2') < 1e-8 & reldif(T[2, 1], `e3') < 1e-8 & reldif(T[3, 1], `ea') < 1e-8
    capture noisily eplot ., drop(nosuch) eform nodraw
    assert _rc == 198
    sysuse auto, clear
    quietly regress price mpg weight, noconstant
    capture noisily eplot ., drop(_cons) nodraw
    assert _rc == 0
    assert r(k) == 2
    matrix T = r(table)
    assert !missing(T[1, 1], T[2, 1], _b[mpg], _b[weight])
    assert reldif(T[1, 1], _b[mpg]) < 1e-8 & reldif(T[2, 1], _b[weight]) < 1e-8
    capture noisily eplot ., drop(nosuch) nodraw
    assert _rc == 198
    clear
    input str8 lab double(es lo hi)
    "alpha" 1 .5 1.5
    "beta"  2 1.5 2.5
    "gamma" 3 2 4
    end
    capture noisily eplot es lo hi, labels(lab) drop(_cons) nodraw
    assert _rc == 0
    assert r(k) == 3
    matrix T = r(table)
    assert T[1, 1] == 1 & T[2, 1] == 2 & T[3, 1] == 3
    capture noisily eplot es lo hi, labels(lab) drop(nosuch) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 24. drop() of a coefficient already removed or omitted is not an error
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    capture noisily eplot ., keep(mpg weight) drop(weight) nodraw
    assert _rc == 0
    assert r(k) == 1
    matrix T = r(table)
    assert !missing(T[1, 1], _b[mpg])
    assert reldif(T[1, 1], _b[mpg]) < 1e-8
    * A base level is in e(b) but not plotted without baselevels.
    quietly regress price mpg i.rep78
    local bm = _b[mpg]
    local b5 = _b[5.rep78]
    capture noisily eplot ., drop(1b.rep78 _cons) nodraw
    assert _rc == 0
    assert r(k) == 5
    matrix T = r(table)
    assert !missing(T[1, 1], T[5, 1], `bm', `b5')
    assert reldif(T[1, 1], `bm') < 1e-8 & reldif(T[5, 1], `b5') < 1e-8
    * A coefficient omitted for zero variance (cnsreg) can still be dropped.
    constraint define 1 mpg = 2
    quietly cnsreg price mpg weight length, constraints(1)
    local bw = _b[weight]
    local bl = _b[length]
    capture noisily eplot ., drop(mpg _cons) nodraw
    assert _rc == 0
    assert r(k) == 2
    matrix T = r(table)
    assert !missing(T[1, 1], T[2, 1], `bw', `bl')
    assert reldif(T[1, 1], `bw') < 1e-8 & reldif(T[2, 1], `bl') < 1e-8
    * A name that exists nowhere still refuses, with or without keep().
    capture noisily eplot ., keep(weight length) drop(nosuch) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 25. One notation per values cell when the numbers are large
local ++test_count
capture noisily {
    capture frame drop v162_f25
    matrix B = (1e22, 1e22, 1e22 \ 1e12, 1e12, 1e12 \ 1e22, 5, 1e12 \ 1e11, 5, 1e12)
    matrix rownames B = a b c d
    eplot, matrix(B) values dp(2) export(v162_f25, replace) nodraw nonull
    * Stata's own formats are the oracle for each notation.
    local e22 = strtrim(string(1e22, "%20.2e"))
    local e5  = strtrim(string(5, "%20.2e"))
    local e12 = strtrim(string(1e12, "%20.2e"))
    local f12 = strtrim(string(1e12, "%20.2f"))
    local f11 = strtrim(string(1e11, "%20.2f"))
    assert "`e22'" == "1.00e+22" & "`f12'" == "1000000000000.00"
    frame v162_f25 {
        assert _N == 4
        assert values[1] == "`e22' (`e22', `e22')"
        assert values[2] == "`f12' (`f12', `f12')"
        assert values[3] == "`e22' (`e5', `e12')"
        assert values[4] == "`f11' (5.00, `f12')"
    }
    frame drop v162_f25
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v162, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
