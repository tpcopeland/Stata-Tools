* test_cycle_20261119_m_descriptive_tests.do - regression QA for the
* 2026-11-19 methods review of desctab/table1_tc and crosstab:
*   F1 contln refuses zero/negative values (was: silently dropped, counted as Missing)
*   F2 t test/ANOVA computed for by() codes above c(maxlong)
*   F3 Wilcoxon p documented as the normal approximation
*   F4 weighted SD form documented (summarize [aw]) against Austin-Stuart
*   F5 crosstab refuses an RR whose CI is undefined (was: "CI: ., .")
*   F6 categorical SMD includes the Missing level under missing
*   F7 wtcompare crude columns keep zero/missing-weight records
*   F8 headerperc rounds a share as the body cells do

clear all
set more off
set varabbrev off
version 17.0

capture log close _cyc_mdt
log using "test_cycle_20261119_m_descriptive_tests.log", replace text name(_cyc_mdt)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# F1 contln and nonpositive values
**## A zero or negative contln value is refused with r(411)
local ++test_count
capture noisily {
    clear
    input byte g double v
    0 0
    0 0
    0 2
    0 4
    0 .
    1 3
    1 5
    1 7
    1 9
    1 0
    end
    capture desctab, by(g) vars(v contln %9.3f %9.3f) missingsummary
    assert _rc == 411
    replace v = -1 in 1/2
    replace v = 1 in 10
    capture desctab, by(g) vars(v contln)
    assert _rc == 411
    * the same values as contn are accepted
    desctab, by(g) vars(v contn)
}
if _rc == 0 {
    display as result "  PASS: F1 contln refuses zero/negative values"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 contln refuses zero/negative values (rc=`=_rc')"
    local ++fail_count
}

**## Positive contln: Missing row counts only missing values
local ++test_count
capture noisily {
    clear
    input byte g double v
    0 1
    0 2
    0 4
    0 .
    1 3
    1 5
    1 7
    1 9
    end
    capture frame drop _f1
    desctab, by(g) vars(v contln %9.3f %9.3f) missingsummary frame(_f1, replace)
    frame _f1 {
        quietly count if strtrim(factor) == "Missing"
        assert r(N) == 1
        quietly levelsof g_0 if strtrim(factor) == "Missing", local(m0) clean
        quietly levelsof g_1 if strtrim(factor) == "Missing", local(m1) clean
        assert `"`m0'"' == "1 (25)"
        assert `"`m1'"' == "0"
        quietly levelsof g_0 if strtrim(factor) == "v", local(gm0) clean
        * geometric mean of 1, 2, 4 is 2
        assert strpos(`"`gm0'"', "2.000") == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F1 contln Missing row is the true missing count"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 contln Missing row is the true missing count (rc=`=_rc')"
    local ++fail_count
}

**# F2 Comparison tests with by() codes above c(maxlong)
**## Three groups: ANOVA p equals oneway on a group index
local ++test_count
capture noisily {
    clear
    set obs 12
    gen double g = cond(_n <= 4, 0, cond(_n <= 8, 1, 3000000000))
    gen double x = _n + mod(_n, 3)
    egen gg = group(g)
    quietly oneway x gg
    local p_ref = Ftail(r(df_m), r(df_r), r(F))
    capture frame drop _f2
    desctab, by(g) vars(x contn %12.3f) test statistic frame(_f2, replace)
    tempname T
    matrix `T' = r(table)
    assert reldif(`T'[1, 1], `p_ref') < 1e-10
    frame _f2 {
        quietly levelsof test if strtrim(factor) == "x", local(tst) clean
        quietly levelsof statistic if strtrim(factor) == "x", local(st) clean
        quietly levelsof pvalue if strtrim(factor) == "x", local(pv) clean
        assert `"`tst'"' == "ANOVA"
        assert `"`st'"' == "F(2,9)= 24.10"
        assert `"`pv'"' == "<0.001"
    }
}
if _rc == 0 {
    display as result "  PASS: F2 ANOVA computed for a 3e9 by() code"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 ANOVA computed for a 3e9 by() code (rc=`=_rc')"
    local ++fail_count
}

**## Two groups: t test p and sign equal ttest
local ++test_count
capture noisily {
    clear
    set obs 8
    gen double g = cond(_n <= 4, 0, 3000000000)
    gen double x = cond(_n <= 4, _n + mod(_n, 3), _n + 4 + mod(_n, 3))
    quietly ttest x, by(g)
    local p_ref = r(p)
    local t_ref : display %6.2f r(t)
    capture frame drop _f2b
    desctab, by(g) vars(x contn %12.3f) test statistic frame(_f2b, replace)
    tempname T
    matrix `T' = r(table)
    assert reldif(`T'[1, 1], `p_ref') < 1e-10
    frame _f2b {
        quietly levelsof statistic if strtrim(factor) == "x", local(st) clean
        assert `"`st'"' == "t(6)=`t_ref'"
        quietly levelsof pvalue if strtrim(factor) == "x", local(pv) clean
        assert `"`pv'"' != ""
    }
}
if _rc == 0 {
    display as result "  PASS: F2 t test computed for a 3e9 by() code"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 t test computed for a 3e9 by() code (rc=`=_rc')"
    local ++fail_count
}

**# F3 Wilcoxon p is the normal approximation, and says so
local ++test_count
capture noisily {
    clear
    input byte g double s
    0 1
    0 2
    0 3
    0 5
    1 4
    1 6
    1 7
    1 8
    end
    quietly ranksum s, by(g)
    local p_ref = r(p)
    assert abs(r(p_exact) - 0.0571428571428571) < 1e-12
    capture frame drop _f3
    desctab, by(g) vars(s conts) test statistic pdp(4) frame(_f3, replace)
    tempname T
    matrix `T' = r(table)
    assert reldif(`T'[1, 1], `p_ref') < 1e-12
    assert strpos(`"`r(methods)'"', "Wilcoxon rank-sum test (normal approximation)") > 0
    frame _f3 {
        quietly levelsof pvalue if strtrim(factor) == "s", local(pv) clean
        assert `"`pv'"' == "0.0433"
    }
    * the help says which p it is
    foreach h in desctab table1_tc {
        tempname fh
        local hit 0
        file open `fh' using "`pkg_dir'/`h'.sthlp", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "not the exact p-value that") local hit 1
            file read `fh' line
        }
        file close `fh'
        assert `hit' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F3 Wilcoxon normal-approximation p documented"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 Wilcoxon normal-approximation p documented (rc=`=_rc')"
    local ++fail_count
}

**# F4 Weighted SD is summarize [aw]; the help states the form
local ++test_count
capture noisily {
    clear
    input byte g double x double w
    0 1 0.5
    0 3 2
    0 4 1
    0 8 3
    1 2 1
    1 5 0.25
    1 6 4
    1 9 1.5
    end
    quietly summarize x [aw=w] if g == 0
    local m0 = r(mean)
    local s0 = r(sd)
    quietly summarize x [aw=w] if g == 1
    local m1 = r(mean)
    local s1 = r(sd)
    local smd_ref = abs(`m0' - `m1') / sqrt((`s0'^2 + `s1'^2) / 2)
    desctab, by(g) vars(x contn) wt(w) smd nopvalue
    tempname T
    matrix `T' = r(table)
    assert reldif(`T'[1, colnumb(`T', "smd")], `smd_ref') < 1e-10
    foreach h in desctab table1_tc {
        tempname fh
        local hit 0
        file open `fh' using "`pkg_dir'/`h'.sthlp", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "reliability-weight form") local hit 1
            file read `fh' line
        }
        file close `fh'
        assert `hit' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F4 weighted SD form pinned and documented"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 weighted SD form pinned and documented (rc=`=_rc')"
    local ++fail_count
}

**# F5 crosstab never prints an undefined RR interval
**## No events among the exposed: rr refused, or/rd still reported
local ++test_count
capture noisily {
    clear
    input byte y byte e int n
    0 0 30
    0 1 25
    1 0 6
    1 1 0
    end
    capture crosstab y e [fw=n], or rr rd
    assert _rc == 498
    capture frame drop _f5
    crosstab y e [fw=n], or rd frame(_f5, replace)
    assert reldif(r(rd), -1/6) < 1e-10
    frame _f5 {
        quietly count if strpos(c1, "RR = ") == 1
        assert r(N) == 0
        quietly count if strpos(c1, "RD = ") == 1
        assert r(N) == 1
        quietly count if strpos(c1, ", .)") | strpos(c1, "CI: .,")
        assert r(N) == 0
    }
    * the mirror table (no events among the unexposed) is refused as before
    clear
    input byte y byte e int n
    0 0 30
    0 1 25
    1 0 0
    1 1 7
    end
    capture crosstab y e [fw=n], rr
    assert _rc == 498
    crosstab y e [fw=n], rd
    assert r(rd) < .
}
if _rc == 0 {
    display as result "  PASS: F5 crosstab refuses an RR with an undefined CI"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 crosstab refuses an RR with an undefined CI (rc=`=_rc')"
    local ++fail_count
}

**# F6 Categorical SMD under missing includes the Missing level
local ++test_count
capture noisily {
    clear
    input byte g double c int n
    0 1 13
    0 2 9
    0 3 13
    0 . 5
    1 1 7
    1 2 9
    1 3 24
    end
    expand n
    drop n
    * Yang-Dalton eq. 2 over (1, 2, 3, Missing): python/numpy oracle
    local smd_miss 0.758961304501041
    local smd_nomiss 0.5197736685140975
    capture frame drop _f6
    desctab, by(g) vars(c cat) smd missing nopvalue frame(_f6, replace)
    tempname T
    matrix `T' = r(table)
    assert reldif(`T'[1, colnumb(`T', "smd")], `smd_miss') < 1e-10
    frame _f6 {
        quietly levelsof smd_str if strtrim(factor) == "c", local(sv) clean
        assert `"`sv'"' == "0.759"
    }
    desctab, by(g) vars(c cat) smd nopvalue
    matrix `T' = r(table)
    assert reldif(`T'[1, colnumb(`T', "smd")], `smd_nomiss') < 1e-10
    desctab, by(g) vars(c cat) smd smdtype(maxpair) missing nopvalue
    matrix `T' = r(table)
    assert reldif(`T'[1, colnumb(`T', "smd")], `smd_miss') < 1e-10
    * an extended missing code joins the one Missing level, as in the table
    replace c = .a in 1/2 if missing(c)
    desctab, by(g) vars(c cat) smd missing nopvalue
    matrix `T' = r(table)
    assert reldif(`T'[1, colnumb(`T', "smd")], `smd_miss') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: F6 categorical SMD includes Missing under missing"
    local ++pass_count
}
else {
    display as error "  FAIL: F6 categorical SMD includes Missing under missing (rc=`=_rc')"
    local ++fail_count
}

**# F7 wtcompare crude columns are the unweighted cohort
local ++test_count
capture noisily {
    clear
    set obs 30
    gen byte g = _n > 15
    gen double x = _n
    gen double w = cond(mod(_n, 3) == 0, 0, 1.5)
    replace w = . in 1
    quietly summarize x if g == 0
    local cr0 = strofreal(r(mean), "%9.3f") + "±" + strofreal(r(sd), "%9.3f")
    capture frame drop _f7
    desctab, by(g) vars(x contn %9.3f %9.3f) wt(w) wtcompare frame(_f7, replace)
    frame _f7 {
        quietly levelsof Cr_0 if strtrim(factor) == "x", local(c0) clean
        quietly levelsof Wt_0 if strtrim(factor) == "x", local(w0) clean
        quietly levelsof Cr_0 if _n == 2, local(n0) clean
        quietly levelsof Wt_0 if _n == 2, local(nw0) clean
        assert `"`c0'"' == `"`cr0'"'
        assert `"`c0'"' == "8.000±4.472"
        * weighted: records 2,4,5,7,8,10,11,13,14 (w = 1.5)
        assert `"`w0'"' == "8.222±4.116"
        assert `"`n0'"' == "N=15"
        assert `"`nw0'"' == "N=9"
    }
}
if _rc == 0 {
    display as result "  PASS: F7 wtcompare crude columns keep zero/missing weights"
    local ++pass_count
}
else {
    display as error "  FAIL: F7 wtcompare crude columns keep zero/missing weights (rc=`=_rc')"
    local ++fail_count
}

**# F8 headerperc and body cells round one share the same way
local ++test_count
capture noisily {
    clear
    set obs 80
    gen byte g = _n == 1
    gen byte b = g
    capture frame drop _f8
    desctab, by(g) vars(b bin) total(after) headerperc percformat(%5.1f) frame(_f8, replace)
    frame _f8 {
        quietly levelsof g_1 if _n == 2, local(h1) clean
        quietly ds g_*
        local tcol : word count `r(varlist)'
        local tcol : word `tcol' of `r(varlist)'
        quietly levelsof `tcol' if strtrim(factor) == "b", local(bt) clean
        assert `"`h1'"' == "1 (1.2)"
        assert `"`bt'"' == "1 (1.2)"
        quietly levelsof g_0 if _n == 2, local(h0) clean
        assert `"`h0'"' == "79 (98.8)"
    }
}
if _rc == 0 {
    display as result "  PASS: F8 headerperc rounds like the body"
    local ++pass_count
}
else {
    display as error "  FAIL: F8 headerperc rounds like the body (rc=`=_rc')"
    local ++fail_count
}

set varabbrev off
display as result "test_cycle_20261119_m_descriptive_tests: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_m_descriptive_tests tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _cyc_mdt
if `fail_count' > 0 exit 1
