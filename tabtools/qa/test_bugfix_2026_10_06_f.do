* test_bugfix_2026_10_06_f.do - review of the wave-1 changes (A: regtab, B: desctab
* and the rate/survival/cross tables)
*
* F1 a waiver must name a rule code one of the checkers knows (an unknown
*    code is silently inert, so the line it was meant to excuse would be
*    unguarded); every code on a waiver line is checked
* F2 a stats(groups) request no model can meet leaves the session as it found it
* F3 regtab's numeric equation order (_regtab_eqkeys now sorts in Mata): the
*    levels 2 < 10 and -1 < 1 are ordered numerically and each header's
*    coefficient rows carry that equation's estimates
* F4 r(table) names of crosstab, survtab and stratetab, whose captures around
*    matrix rownames/colnames/cell assignments were removed
*
* Oracles: levelsof and the estimation commands' own e(b); no expected value
* is read back from the code under test. Run from tabtools/qa.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _bff
log using "test_bugfix_2026_10_06_f.log", replace text name(_bff)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* _f_hits FILE NEEDLE: r(n) = number of lines of FILE that contain NEEDLE
capture program drop _f_hits
program define _f_hits, rclass
    version 17.0
    args file needle
    mata: st_numscalar("_f_n", sum(strpos(cat(st_local("file")), st_local("needle")) :> 0))
    return scalar n = scalar(_f_n)
    scalar drop _f_n
end

* _f_badcodes(FILE, MARKER, KNOWN): waiver codes on FILE's waiver lines that
* are not in KNOWN. The code list is the text after MARKER up to the dash that
* opens the reason, split on commas, so every code on the line is checked.
capture mata: mata drop _f_badcodes()
mata:
real scalar _f_badcodes(string scalar file, string scalar marker,
    string scalar known)
{
    string colvector l
    string rowvector t, k
    string scalar c
    real scalar i, j, b

    k = tokens(known)
    l = cat(file)
    l = select(l, strpos(l, marker) :> 0)
    b = 0
    for (i = 1; i <= rows(l); i++) {
        c = substr(l[i], strpos(l[i], marker) + strlen(marker), .)
        c = ustrregexra(c, "\s+(\u2014|\u2013|-)\s.*$", "")
        t = tokens(subinstr(c, ",", " "))
        for (j = 1; j <= cols(t); j++) {
            if (!anyof(k, t[j])) {
                printf("{err}    unknown waiver code %s\n", t[j])
                b++
            }
        }
    }
    return(b)
}
end

**# F1: every waiver in the package names a rule code a checker knows
local ++test_count
capture noisily {
    * A waiver whose code no checker knows is inert, so the line it was
    * meant to excuse is unguarded. The two checkers spell the capture rule
    * differently: the source validator's code is capture_rc and the linter's
    * is capture-rc, so a waiver for both names both. This list is every code
    * the checkers define that the package uses; a misspelt code fails here.
    * The marker is assembled from two pieces so this file does not itself
    * read as a reference to the development repository.
    local known "ambient-fallback capture-rc capture_rc cf-one-directional"
    local known "`known' double-macro-transport hardcoded-tempname identity-fold"
    local known "`known' missing-passes-reldif omitted-coef-display"
    local known "`known' pinned-constant-no-derivation rc-only-test shape-dispatch"
    local known "`known' unchecked-commit unseeded-draw vacuous-tolerance"
    local nd1 "stata"
    local nd2 "-dev-ignore:"
    local bad 0
    foreach sub in "" "qa" {
        local dir = cond("`sub'" == "", "`pkg_dir'", "`pkg_dir'/`sub'")
        foreach ext in ado do {
            local files : dir "`dir'" files "*.`ext'"
            foreach f of local files {
                mata: st_local("_f_bad", strofreal(_f_badcodes("`dir'/`f'", ///
                    st_local("nd1") + st_local("nd2"), st_local("known"))))
                if `_f_bad' > 0 display as error "    `sub'/`f': `_f_bad' unknown waiver code(s)"
                local bad = `bad' + `_f_bad'
            }
        }
    }
    assert `bad' == 0
}
if _rc == 0 {
    display as result "  PASS: F1 every waiver code is one a checker knows"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 unknown waiver code (rc=`=_rc', `bad' code(s))"
    local ++fail_count
}

**# F2: stats(groups) with no group count renders, notes it, and leaves varabbrev, data and collections intact
local ++test_count
capture noisily {
    sysuse auto, clear
    gen pair = ceil(_n/2)
    gen byte hi = price > 6000
    set varabbrev on
    collect clear
    quietly collect: regress mpg weight
    quietly collect: clogit hi weight, group(pair)
    local N0 = _N
    quietly describe
    local k0 = r(k)
    tempfile lgf
    quietly log using "`lgf'.log", text replace name(_bffcap)
    capture noisily regtab, stats(n groups) frame(_bff2, replace)
    local crc = _rc
    local gm = r(groups_1)
    local n1 = r(n_1)
    quietly log close _bffcap
    assert `crc' == 0
    assert "`c(varabbrev)'" == "on"
    assert _N == `N0'
    quietly describe
    assert r(k) == `k0'
    * the note is in the log, once, and the table has no Groups row
    _f_hits "`lgf'.log" "Note: stats(groups) left out: no model stores a group count; model 2 (clogit, group variable pair)"
    assert r(n) == 1
    _f_hits "`lgf'.log" "tabtools fitcount, events(hi) people(pair)"
    assert r(n) == 1
    _f_hits "`lgf'.log" "requested statistic(s), left out of the table"
    assert r(n) == 0
    assert "`gm'" == "." & `n1' == 74
    quietly frame _bff2: count if strtrim(A) == "Groups"
    assert r(N) == 0
    * the collection is still usable
    quietly regtab, stats(n)
    assert r(n_1) == 74 & r(n_2) == 26
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: F2 clogit stats(groups): renders with a note, state restored"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 groups note and state (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off
capture frame drop _bff2
capture log close _bffcap

**# F3: equation order is numeric (2 before 10, -1 before 1) and rows follow it
local ++test_count
capture noisily {
    clear
    set seed 20261006
    set obs 900
    gen byte hi = runiform() > 0.5
    gen double x = rnormal()
    gen double u = runiform()
    foreach spec in "1 2 10|1" "-1 0 1|0" {
        gettoken lv base : spec, parse("|")
        local base = subinstr("`base'", "|", "", 1)
        local lv = strtrim("`lv'")
        local n : word count `lv'
        capture drop y
        gen y = .
        forvalues i = 1/`n' {
            local v : word `i' of `lv'
            quietly replace y = `v' if u >= (`i' - 1) / `n' & u < `i' / `n'
        }
        collect clear
        quietly collect: mlogit y i.hi x, baseoutcome(`base')
        * the non-base equations, in numeric order
        local want ""
        foreach v of local lv {
            if `v' != `base' local want "`want' `v'"
        }
        local want = strtrim("`want'")
        local e1 : word 1 of `want'
        local e2 : word 2 of `want'
        * oracle: each equation's RRR from the fit's own coefficient vector
        matrix _B = e(b)
        foreach e of local want {
            local rrr_`=subinstr("`e'", "-", "m", 1)' = string(exp(_B[1, colnumb(_B, "`e':x")]), "%4.2f")
        }
        regtab, frame(_bff3, replace flat)
        * header rows are "<level>: hi"; collect their order
        frame _bff3 {
            local seq ""
            forvalues r = 1/`=_N' {
                local a = strtrim(rowlabel[`r'])
                if substr("`a'", -4, .) == ": hi" local seq "`seq' `=substr("`a'", 1, length("`a'") - 4)'"
            }
        }
        local seq = strtrim("`seq'")
        assert "`seq'" == "`want'"
        * the x row under each header carries that equation's own RRR
        foreach e of local want {
            local key = subinstr("`e'", "-", "m", 1)
            frame _bff3: quietly count if strtrim(rowlabel) == "`e': x" & strtrim(c1) == "`rrr_`key''"
            assert r(N) == 1
        }
        frame drop _bff3
    }
}
if _rc == 0 {
    display as result "  PASS: F3 numeric equation order and per-equation rows"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 equation order (rc=`=_rc', seq=`seq', want=`want')"
    local ++fail_count
}
capture frame drop _bff3

**# F4a: crosstab r(table) names equal the levels (negative, decimal, missing)
local ++test_count
capture noisily {
    clear
    set obs 80
    gen double r = mod(_n, 4) - 1.5
    gen byte c = mod(_n, 3)
    replace r = . if _n < 5
    replace c = .a if _n == 7
    quietly levelsof r, local(rl)
    quietly levelsof c, local(cl)
    quietly crosstab r c
    matrix _T = r(table)
    local rn : rownames _T
    local cn : colnames _T
    assert "`rn'" == "`rl'"
    assert "`cn'" == "`cl'"
    assert rowsof(_T) == 4 & colsof(_T) == 3
    * with missing the missing levels get their own row and column
    quietly levelsof r, local(rlm) missing
    quietly levelsof c, local(clm) missing
    quietly crosstab r c, missing
    matrix _T = r(table)
    local rn : rownames _T
    local cn : colnames _T
    assert "`rn'" == "`rlm'"
    assert "`cn'" == "`clm'"
    * one-level row variable: one row, still named
    gen byte one = 1
    quietly crosstab one c
    matrix _T = r(table)
    assert rowsof(_T) == 1
    local rn : rownames _T
    assert "`rn'" == "1"
    * the cells are the counts
    quietly count if r == -1.5 & c == 0
    local want11 = r(N)
    assert `want11' > 0
    quietly crosstab r c
    matrix _T = r(table)
    assert _T[1, 1] == `want11'
}
if _rc == 0 {
    display as result "  PASS: F4a crosstab r(table) names"
    local ++pass_count
}
else {
    display as error "  FAIL: F4a crosstab names (rc=`=_rc')"
    local ++fail_count
}

**# F4b: survtab r(table) names: t<time>, sanitized and unique group names
local ++test_count
capture noisily {
    clear
    set obs 600
    set seed 456
    gen byte g = mod(_n, 4)
    gen double time = rexponential(3 + g)
    gen byte event = runiform() < 0.7
    label define _gl 0 "Ctrl group" 1 "A-b.c:d" ///
        2 "this is a very long group label with more than thirty-two characters" ///
        3 "this is a very long group label with more than thirty-two characters!"
    label values g _gl
    quietly stset time, failure(event)
    quietly survtab, times(1 3.5 5) by(g)
    matrix _T = r(table)
    local rn : rownames _T
    local cn : colnames _T
    assert "`rn'" == "t1 t3.5 t5"
    assert colsof(_T) == 4
    local c1 : word 1 of `cn'
    local c2 : word 2 of `cn'
    local c3 : word 3 of `cn'
    local c4 : word 4 of `cn'
    assert "`c1'" == "Ctrl_group" & "`c2'" == "A_b_c_d"
    assert strlen("`c3'") == 32 & strlen("`c4'") == 32 & "`c3'" != "`c4'"
    * the cells are survival probabilities in (0, 1)
    forvalues i = 1/3 {
        forvalues j = 1/4 {
            assert _T[`i', `j'] > 0 & _T[`i', `j'] < 1
        }
    }
    * survival is non-increasing over the time rows
    forvalues j = 1/4 {
        assert _T[1, `j'] >= _T[2, `j'] & _T[2, `j'] >= _T[3, `j']
    }
}
if _rc == 0 {
    display as result "  PASS: F4b survtab r(table) names"
    local ++pass_count
}
else {
    display as error "  FAIL: F4b survtab names (rc=`=_rc')"
    local ++fail_count
}

**# F4c: stratetab r(rates) names for categories with spaces, punctuation, length
local ++test_count
capture noisily {
    forvalues o = 1/2 {
        clear
        set obs 4
        gen str80 category = ""
        replace category = "Low dose" in 1
        replace category = "a-b.c:d" in 2
        replace category = "this is a really long category label exceeding thirty-two chars" in 3
        replace category = "High (>=5)" in 4
        gen double _D = 10 * _n * `o'
        gen double _Y = 1000 * _n
        gen double _Rate = _D / _Y
        gen double _Lower = _Rate * 0.8
        gen double _Upper = _Rate * 1.2
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        save "_bff4c_o`o'.dta", replace
    }
    quietly stratetab, using(_bff4c_o1 _bff4c_o2) outcomes(2)
    matrix _T = r(rates)
    local rn : rownames _T
    local r1 : word 1 of `rn'
    local r2 : word 2 of `rn'
    local r3 : word 3 of `rn'
    local r4 : word 4 of `rn'
    assert "`r1'" == "Low_dose" & "`r2'" == "a_b_c_d" & "`r4'" == "High____5_"
    assert strlen("`r3'") == 32
    * rate per 1000: events / person-time * 1000 for each outcome
    forvalues i = 1/4 {
        assert !missing(_T[`i', 1]) & reldif(_T[`i', 1], 10 * `i' / (1000 * `i') * 1000) < 1e-9  // stata-dev-ignore: missing-passes-reldif — the result side is guarded; the oracle is a closed form in a loop index and cannot be missing
        assert !missing(_T[`i', 2]) & reldif(_T[`i', 2], 20 * `i' / (1000 * `i') * 1000) < 1e-9  // stata-dev-ignore: missing-passes-reldif — the result side is guarded; the oracle is a closed form in a loop index and cannot be missing
    }
    erase "_bff4c_o1.dta"
    erase "_bff4c_o2.dta"
}
if _rc == 0 {
    display as result "  PASS: F4c stratetab r(rates) names and cells"
    local ++pass_count
}
else {
    display as error "  FAIL: F4c stratetab names (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as result "RESULT: test_bugfix_2026_10_06_f tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _bff
if `fail_count' > 0 exit 1
