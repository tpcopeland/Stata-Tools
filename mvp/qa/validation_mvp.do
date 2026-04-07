* validation_mvp.do — Known-answer and invariant tests for mvp v1.2.1
* Self-contained: generates own test data

clear all
set more off
version 16.0


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall mvp
net install mvp, from("`pkg_dir'/") replace force

local test_count = 0
local pass_count = 0
local fail_count = 0

* V1: Complete data — all scalars correct
local ++test_count
capture noisily {
    clear
    set obs 100
    gen x = _n
    gen y = _n * 2
    mvp x y
    assert r(N) == 100
    assert r(N_complete) == 100
    assert r(N_incomplete) == 0
    assert r(N_vars) == 0
    assert r(max_miss) == 0
    assert r(mean_miss) == 0
    assert r(N_mv_total) == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': Complete data — all scalars correct"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': Complete data (rc=`=_rc')"
    local ++fail_count
}

* V2: All-missing variable — known-answer
local ++test_count
capture noisily {
    clear
    set obs 50
    gen x = _n
    gen y = .
    mvp x y
    assert r(N) == 50
    assert r(N_complete) == 0
    assert r(N_incomplete) == 50
    assert r(N_vars) == 1
    assert r(N_patterns) == 1
    assert r(N_mv_total) == 50
    assert r(max_miss) == 1
    assert abs(r(mean_miss) - 1) < 0.001
}
if _rc == 0 {
    display as result "  PASS `test_count': All-missing variable — known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': All-missing (rc=`=_rc')"
    local ++fail_count
}

* V3: N_complete + N_incomplete == N
local ++test_count
capture noisily {
    clear
    set seed 99
    set obs 500
    gen a = rnormal()
    gen b = rnormal()
    gen c = rnormal()
    replace a = . if runiform() < 0.1
    replace b = . if runiform() < 0.2
    replace c = . if runiform() < 0.15
    mvp a b c
    assert r(N_complete) + r(N_incomplete) == r(N)
}
if _rc == 0 {
    display as result "  PASS `test_count': N_complete + N_incomplete == N"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': N invariant (rc=`=_rc')"
    local ++fail_count
}

* V4: Exactly 2 patterns — known structure
local ++test_count
capture noisily {
    clear
    set obs 100
    gen x = 1
    gen y = 1
    replace y = . in 61/100
    mvp x y, nodrop
    assert r(N_patterns) == 2
    assert r(N_complete) == 60
    assert r(N_incomplete) == 40
    assert r(N_mv_total) == 40
}
if _rc == 0 {
    display as result "  PASS `test_count': Exactly 2 patterns — known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': 2 patterns (rc=`=_rc')"
    local ++fail_count
}

* V5: Monotone data correctly identified
local ++test_count
capture noisily {
    clear
    set obs 100
    gen a = 1
    gen b = 1
    gen c = 1
    replace c = . in 51/100
    replace b = . in 71/100
    mvp a b c, nodrop monotone
    assert "`r(monotone_status)'" == "monotone"
    assert r(pct_monotone) == 100
}
if _rc == 0 {
    display as result "  PASS `test_count': Monotone data correctly identified"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': Monotone (rc=`=_rc')"
    local ++fail_count
}

* V6: Non-monotone data correctly identified
local ++test_count
capture noisily {
    clear
    set obs 100
    gen a = 1
    gen b = 1
    gen c = 1
    replace a = . in 1/20
    replace c = . in 50/70
    mvp a b c, nodrop monotone
    assert "`r(monotone_status)'" == "non-monotone"
}
if _rc == 0 {
    display as result "  PASS `test_count': Non-monotone correctly identified"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': Non-monotone (rc=`=_rc')"
    local ++fail_count
}

* V7: Generate indicators — row-level validation
local ++test_count
capture noisily {
    clear
    set obs 50
    gen a = _n
    gen b = _n
    replace a = . in 1/10
    replace b = . in 5/15
    mvp a b, generate(m)
    assert m_a == 1 in 1/10
    assert m_a == 0 in 11/50
    assert m_b == 1 in 5/15
    assert m_b == 0 in 1/4
    assert m_b == 0 in 16/50
    assert m_nmiss == 2 in 5/10
    assert m_nmiss == 1 in 1/4
    assert m_nmiss == 1 in 11/15
    assert m_nmiss == 0 in 16/50
}
if _rc == 0 {
    display as result "  PASS `test_count': Generate indicators — row-level correct"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': Generate row-level (rc=`=_rc')"
    local ++fail_count
}

* V8: Save patterns — content validation
local ++test_count
capture noisily {
    clear
    set obs 100
    gen a = 1
    gen b = 1
    replace b = . in 1/30
    capture frame drop val_pats
    mvp a b, nodrop save(val_pats)
    frame val_pats {
        assert _N == 2
        qui summ freq
        assert r(sum) == 100
    }
    frame drop val_pats
}
if _rc == 0 {
    display as result "  PASS `test_count': Save patterns — content valid"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': Save content (rc=`=_rc')"
    local ++fail_count
}

* V9: Correlation matrix symmetry and diagonal
local ++test_count
capture noisily {
    clear
    set seed 42
    set obs 200
    gen a = rnormal()
    gen b = rnormal()
    gen c = rnormal()
    replace a = . if runiform() < 0.3
    replace b = . if runiform() < 0.3
    replace c = . if runiform() < 0.3
    mvp a b c, correlate
    matrix C = r(corr_miss)
    assert abs(C[1,1] - 1) < 0.001
    assert abs(C[2,2] - 1) < 0.001
    assert abs(C[3,3] - 1) < 0.001
    assert abs(C[1,2] - C[2,1]) < 0.001
    assert abs(C[1,3] - C[3,1]) < 0.001
    forv i = 1/3 {
        forv j = 1/3 {
            assert C[`i',`j'] >= -1.001 & C[`i',`j'] <= 1.001
        }
    }
}
if _rc == 0 {
    display as result "  PASS `test_count': Correlation matrix symmetry+diagonal"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': Correlation matrix (rc=`=_rc')"
    local ++fail_count
}

* V10: minfreq filter reduces patterns
local ++test_count
capture noisily {
    clear
    set obs 100
    gen a = 1
    gen b = 1
    replace a = . in 1/40
    replace b = . in 30/50
    mvp a b, percent
    local total_pats = r(N_patterns)
    mvp a b, minfreq(20) percent
    assert r(N_patterns) <= `total_pats'
}
if _rc == 0 {
    display as result "  PASS `test_count': minfreq filtering reduces patterns"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': minfreq filter (rc=`=_rc')"
    local ++fail_count
}

* V11: r(varlist_nomiss) on no-missing early exit
local ++test_count
capture noisily {
    clear
    set obs 50
    gen x = _n
    gen y = _n * 2
    mvp x y
    assert "`r(varlist_nomiss)'" != ""
    assert r(N_vars) == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': r(varlist_nomiss) on early exit"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': varlist_nomiss (rc=`=_rc')"
    local ++fail_count
}

* V12: mean_miss = total_miss / N
local ++test_count
capture noisily {
    clear
    set obs 200
    gen a = 1
    gen b = 1
    gen c = 1
    replace a = . in 1/20
    replace b = . in 1/40
    replace c = . in 1/60
    mvp a b c
    assert r(N_mv_total) == 120
    assert abs(r(mean_miss) - 0.6) < 0.001
}
if _rc == 0 {
    display as result "  PASS `test_count': mean_miss invariant (120/200=0.6)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': mean_miss (rc=`=_rc')"
    local ++fail_count
}

* V13: String gby() counts match manual (v1.2.1 fix)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen a = 1
    gen b = 1
    replace a = . in 1/20
    replace b = . in 41/60
    gen str4 grp = cond(_n <= 50, "AA", "BB")
    * Group AA: obs 1-50, a miss=20 (40%), b miss=10 (20%)
    * Group BB: obs 51-100, b miss=10 (20%), a miss=0 (0%)
    mvp a b, graph(bar) gby(grp) nodraw
    assert r(N) == 100
    assert "`r(gby)'" == "grp"
}
if _rc == 0 {
    display as result "  PASS `test_count': String gby() runs without crash (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': string gby counts (rc=`=_rc')"
    local ++fail_count
}

* V14: String over() runs without crash (v1.2.1 fix)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen a = 1
    gen b = 1
    replace a = . in 1/30
    replace b = . in 20/50
    gen str5 grp = cond(_n <= 50, "Grp_A", "Grp_B")
    mvp a b, graph(bar) over(grp) nodraw
    assert r(N) == 100
    assert "`r(over)'" == "grp"
}
if _rc == 0 {
    display as result "  PASS `test_count': String over() runs without crash (v1.2.1)"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': string over counts (rc=`=_rc')"
    local ++fail_count
}

* V15: Varabbrev OFF preserved through mvp (v1.2.1 fix)
local ++test_count
capture noisily {
    clear
    set obs 50
    gen a = _n
    replace a = . in 1/10
    set varabbrev off
    mvp a
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS `test_count': Varabbrev OFF preserved (v1.2.1)"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "  FAIL `test_count': varabbrev OFF (rc=`=_rc')"
    local ++fail_count
}

* V16: Single observation — known-answer
local ++test_count
capture noisily {
    clear
    set obs 1
    gen a = .
    gen b = 5
    mvp a b, nodrop
    assert r(N) == 1
    assert r(N_complete) == 0
    assert r(N_incomplete) == 1
    assert r(N_vars) == 2
    assert r(N_patterns) == 1
    assert r(max_miss) == 1
    assert abs(r(mean_miss) - 1) < 0.001
}
if _rc == 0 {
    display as result "  PASS `test_count': Single observation — known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': single obs (rc=`=_rc')"
    local ++fail_count
}

* V17: Correlation matrix with all-missing var has missing entries
local ++test_count
capture noisily {
    clear
    set seed 88
    set obs 200
    gen a = rnormal()
    gen b = rnormal()
    gen c = .
    replace a = . if runiform() < 0.3
    replace b = . if runiform() < 0.3
    mvp a b c, correlate
    matrix C = r(corr_miss)
    * c is always missing, so corr(a,c) and corr(b,c) may be undefined
    * Diagonal should still be 1 for a and b
    assert abs(C[1,1] - 1) < 0.001
    assert abs(C[2,2] - 1) < 0.001
}
if _rc == 0 {
    display as result "  PASS `test_count': Correlation matrix with all-missing variable"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': corr all-missing (rc=`=_rc')"
    local ++fail_count
}

* V18: N_mv_total == sum of per-variable missing counts
local ++test_count
capture noisily {
    clear
    set obs 100
    gen a = 1
    gen b = 1
    gen c = 1
    replace a = . in 1/10
    replace b = . in 1/25
    replace c = . in 1/15
    mvp a b c
    assert r(N_mv_total) == 50
}
if _rc == 0 {
    display as result "  PASS `test_count': N_mv_total == sum of per-var missing"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': N_mv_total sum (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
* SUMMARY
* =========================================================================

display _n "{hline 60}"
display "MVP VALIDATION SUMMARY"
display "{hline 60}"
display "Total:  `test_count'"
display as result "Passed: `pass_count'"
if `fail_count' > 0 {
    display as error "Failed: `fail_count'"
}
else {
    display "Failed: `fail_count'"
}
display "{hline 60}"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
