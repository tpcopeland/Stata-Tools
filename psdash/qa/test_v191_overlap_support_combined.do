* test_v191_overlap_support_combined.do -- psdash 1.9.1 overlap/support/combined fixes
* Author: Timothy P Copeland, Karolinska Institutet
*
* Changes under test (review findings, psdash 1.9.0):
*   T1  float non-integer period crashed the longitudinal engine with r(198)
*   T2  r(max_pct_outside) was 0 when no period has both arms (must be .)
*   T3  psdash combined leaked tempvar names (__00000#) into r(wvar), panel
*       console headers, and the Overlap/Support report() sheets
*   T4  psdash combined left threshold() unvalidated when balance is skipped
*   T5  report() write failure printed every panel twice, blocked saving(),
*       and posted r(report) for a workbook that was never written
*   T6  psdash support generate() could overwrite an assessed covariate
*   T7  psdash support threshold(-1)/qtrim(-1) were read as "omitted"
*   T8  sheet() with a double quote or an invalid Excel name (over 31 bytes,
*       : \ / ? * [ ], leading/trailing apostrophe, History) failed late or
*       broke parsing; psdash balance broke on a title() with quotes
*   T9  compact multi-group overlap printed the reshape table
*   T10 longitudinal psdash combined ignored covariates()/reference() and let
*       estimand() relabel r(estimand) without re-weighting
*
* Fail-on-old: every test fails on psdash 1.9.0 (observed: 10 of 10).
*
* False greens named and defused:
*   FG1 an error test passes because the command errors for another reason ->
*       each refusal has a positive control that succeeds with a valid value,
*       and T6 asserts the covariate is byte-identical afterwards.
*   FG2 T5's single print passes because nothing printed -> the panel header
*       count is asserted == 1, not == 0, and the payload matches a good run.
*   FG3 T3's label passes because the sheet lacks the row -> the "PS variable"
*       row is located by its key and its value compared exactly.
*
* Usage: cd psdash/qa && stata-mp -b do test_v191_overlap_support_combined.do
version 16.0
capture log close _all
log using test_v191_overlap_support_combined.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)
local repo_dir = substr("`pkg_dir'", 1, strlen("`pkg_dir'") - strlen("/psdash"))
local tests = 0
local pass = 0
local fail = 0
local skip = 0
global V191C_FAILED ""

**# Helpers

capture program drop _v191c_rec
program define _v191c_rec
    args id rc
    if `rc' == 0 display as result "  PASS: `id'"
    else {
        display as error "  FAIL: `id' (rc=`rc')"
        global V191C_FAILED "$V191C_FAILED `id'"
    }
end

* Run a command with its console output captured to a text file; the rc
* comes back in $V191C_RC. r() of the command is held across the log close.
capture program drop _v191c_capture
program define _v191c_capture
    gettoken file 0 : 0
    capture log close _v191cap
    quietly log using `"`file'"', text replace name(_v191cap)
    capture noisily `0'
    global V191C_RC = _rc
    tempname h
    _return hold `h'
    quietly log close _v191cap
    _return restore `h'
end

* Count non-overlapping occurrences of a needle in a file.
capture program drop _v191c_count
program define _v191c_count, rclass
    args file needle
    local txt = fileread(`"`file'"')
    local n = (strlen(`"`txt'"') - strlen(subinstr(`"`txt'"', `"`needle'"', "", .))) / strlen(`"`needle'"')
    return scalar n = `n'
end

capture program drop _v191c_binary
program define _v191c_binary
    clear
    set seed 191
    set obs 400
    generate double x1 = rnormal()
    generate double x2 = rnormal()
    generate byte t = runiform() < invlogit(0.4*x1 - 0.3*x2)
    generate double ps = invlogit(-0.1 + 0.4*x1 - 0.3*x2)
    generate double w = cond(t, 1/ps, 1/(1 - ps))
end

**# T1 float period values are indexed exactly
capture noisily {
    clear
    set obs 100
    generate byte t = mod(_n, 2)
    generate float period = cond(_n <= 50, 0.1, 0.2)
    generate double ps = 0.3 + 0.4*(_n - 1)/99
    generate double w = cond(t, 1/ps, 1/(1 - ps))
    generate byte touse = 1
    _psdash_ltmle_diagnostics, treatment(t) period(period) psvar(ps) ///
        wvar(w) samplevar(touse)
    assert r(N_periods) == 2
    assert "`r(periods)'" == ".1 .2"
    matrix ov = r(overlap_by_period)
    matrix wp = r(weights_by_period)
    local names : rownames ov
    assert "`names'" == "p_1 p_2"
    assert ov[1,1] == 50 & ov[2,1] == 50
    assert ov[1,2] == 25 & ov[1,3] == 25
    assert wp[1,1] == 50 & wp[2,1] == 50
    * exact oracle: period means of the PS by arm
    quietly summarize ps if period == float(0.1) & t == 1, meanonly
    assert !missing(ov[1,4]) & !missing(r(mean))
    assert reldif(ov[1,4], r(mean)) < 1e-14
    quietly summarize ps if period == float(0.2) & t == 0, meanonly
    assert !missing(ov[2,5]) & !missing(r(mean))
    assert reldif(ov[2,5], r(mean)) < 1e-14
    * a double period keeps its exact levelsof labels
    generate double dperiod = cond(_n <= 50, -2, .1)
    _psdash_ltmle_diagnostics, treatment(t) period(dperiod) psvar(ps) ///
        wvar(w) samplevar(touse)
    assert "`r(periods)'" == "-2 .1"
    matrix ov = r(overlap_by_period)
    local names : rownames ov
    assert "`names'" == "p_2 p_1"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191c_rec float_period_indexed `rc'

**# T2 no estimable period -> r(max_pct_outside) is missing
capture noisily {
    clear
    set obs 20
    generate byte period = ceil(_n/10)
    generate byte t = period == 1
    generate double ps = .5
    generate double w = 2
    generate byte touse = 1
    _psdash_ltmle_diagnostics, treatment(t) period(period) psvar(ps) ///
        wvar(w) samplevar(touse)
    assert r(n_estimable_periods) == 0
    assert r(n_single_arm_periods) == 2
    assert missing(r(max_pct_outside))
    assert "`r(verdict)'" == "FAIL"
    assert strpos(`"`r(warnings)'"', "single-arm") > 0
    assert strpos(`"`r(warnings)'"', "outside common support") == 0
    * positive control: an estimable period still reports its share exactly
    replace t = mod(_n, 2)
    * period 1: support is [.5, .5], so the one control at .3 is outside (10%)
    replace ps = .5
    replace ps = .3 if _n == 2
    replace w = cond(t, 1/ps, 1/(1 - ps))
    _psdash_ltmle_diagnostics, treatment(t) period(period) psvar(ps) ///
        wvar(w) samplevar(touse)
    assert r(n_estimable_periods) == 2
    assert !missing(r(max_pct_outside)) & !missing(10)
    assert reldif(r(max_pct_outside), 10) < 1e-12
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191c_rec max_pct_outside_missing_when_unestimable `rc'

**# T3 combined never shows internal tempvar names
* Routes: binary teffects (PS <ps_auto>), K=3 teffects and K=2 coded 1/2
* (per-level PS columns <ps_auto>_<level>), each with a generated weight.
* Exactly six labelled lines are expected per run: the dashboard's PS and
* Weights header lines, and one per panel (overlap PS, balance Weights,
* weights Weight variable, support PS).
foreach case in bin k3 k2 {
    capture noisily {
        sysuse auto, clear
        if "`case'" == "bin" local tvar foreign
        else {
            local tvar arm
            if "`case'" == "k3" generate byte arm = mod(_n, 3)
            else generate byte arm = foreign + 1
        }
        quietly teffects ipw (price) (`tvar' mpg weight)
        local book "`_qa_sysroot'/v191c_teffects_`case'.xlsx"
        capture erase "`book'"
        local cap "`_qa_sysroot'/v191c_t3_`case'.txt"
        _v191c_capture "`cap'" psdash combined, report("`book'")
        assert $V191C_RC == 0
        assert "`r(wvar)'" == "auto-generated"
        assert "`r(psvar)'" == "auto-generated"
        _v191c_count "`cap'" "__0"
        assert r(n) == 0
        _v191c_count "`cap'" "auto-generated"
        display "T3 `case' auto-generated lines: " r(n)
        assert r(n) == 6
        foreach sh in Overlap Support Weights Balance Summary {
            import excel using "`book'", sheet("`sh'") clear allstring
            quietly count if strpos(A, "__0") | strpos(B, "__0")
            assert r(N) == 0
        }
        foreach sh in Overlap Support Summary {
            import excel using "`book'", sheet("`sh'") clear allstring
            quietly count if A == "PS variable"
            assert r(N) == 1
            quietly levelsof B if A == "PS variable", local(val) clean
            assert `"`val'"' == "auto-generated"
        }
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v191c_rec combined_no_tempvar_names_`case' `rc'
}

**# T4 combined validates threshold() even when balance is skipped
capture noisily {
    _v191c_binary
    capture noisily psdash combined t ps, nobalance threshold(-5)
    assert _rc == 198
    capture noisily psdash combined t ps, nobalance threshold(.)
    assert _rc == 198
    capture noisily psdash combined t ps, threshold(0)
    assert _rc == 198
    * positive control: a valid threshold with balance skipped runs
    quietly psdash combined t ps, nobalance threshold(0.2)
    assert r(n_panels) == 3
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191c_rec combined_threshold_validated_without_balance `rc'

**# T5 report() write failure: one print per panel, saving() works, no r(report)
capture noisily {
    _v191c_binary
    quietly psdash combined t ps, covariates(x1 x2) wvar(w)
    local verdict "`r(verdict)'"
    local nfind = r(n_warnings)
    local ess = r(ess)
    graph drop _all
    tempfile badroot
    local png "`_qa_sysroot'/v191c_t5.png"
    capture erase "`png'"
    local cap "`_qa_sysroot'/v191c_t5.txt"
    _v191c_capture "`cap'" psdash combined t ps, covariates(x1 x2) wvar(w) ///
        report("`badroot'/report.xlsx") saving("`png'")
    assert $V191C_RC == 603
    assert "`r(report)'" == ""
    assert "`r(verdict)'" == "`verdict'"
    assert r(n_warnings) == `nfind'
    assert r(n_panels) == 4
    assert !missing(r(ess)) & !missing(`ess')
    assert reldif(r(ess), `ess') < 1e-14
    confirm file "`png'"
    foreach needle in "Propensity Score Distribution" ///
            "Covariates > SMD threshold" "Weight Distribution Summary" ///
            "Propensity Score Range" {
        _v191c_count "`cap'" `"`needle'"'
        assert r(n) == 1
    }
    _v191c_count "`cap'" "could not be written"
    assert r(n) == 1
    * positive control: a writable workbook is posted
    local book "`_qa_sysroot'/v191c_t5.xlsx"
    capture erase "`book'"
    quietly psdash combined t ps, covariates(x1 x2) wvar(w) report("`book'")
    assert `"`r(report)'"' == `"`book'"'
    confirm file "`book'"
    * guard (passes on old and new): after the workbook fails, a later
    * panel's genuine analytical error still exits with its own code. The
    * overlap panel hits the export failure; balance then refuses the
    * negative weight (r(198)) instead of the command returning r(603).
    replace w = -1 in 1
    capture noisily psdash combined t ps, covariates(x1 x2) wvar(w) ///
        nosupport report("`badroot'/report.xlsx")
    assert _rc == 198
    assert "`r(verdict)'" == ""
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191c_rec combined_report_failure_contained `rc'

**# T6 support generate() never overwrites an assessed covariate
capture noisily {
    sysuse auto, clear
    generate double ps = invlogit(-1 + 0.02*mpg)
    generate double x1 = mpg
    quietly datasignature
    local sig "`r(datasignature)'"
    capture noisily psdash support foreign ps, threshold(0.1) ///
        covariates(x1) compare generate(x1) replace nograph
    assert _rc == 198
    quietly datasignature
    assert "`r(datasignature)'" == "`sig'"
    * factor-variable term reserves its base variable
    capture noisily psdash support foreign ps, threshold(0.1) ///
        covariates(i.rep78 x1) compare generate(rep78) replace nograph
    assert _rc == 198
    capture noisily psdash support foreign ps, threshold(0.1) ///
        covariates(c.x1#c.weight) compare generate(weight) replace nograph
    assert _rc == 198
    quietly datasignature
    assert "`r(datasignature)'" == "`sig'"
    * positive control: a fresh name works and compare reads the real x1
    psdash support foreign ps, threshold(0.1) covariates(x1) compare ///
        generate(insup) nograph
    confirm variable insup
    assert !missing(r(max_smd_pre))
    assert r(max_smd_pre) > 0.05
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191c_rec support_generate_spares_covariates `rc'

**# T7 support threshold()/qtrim() explicit invalid values error
capture noisily {
    sysuse auto, clear
    generate double ps = invlogit(-1 + 0.02*mpg)
    foreach bad in "threshold(-1)" "qtrim(-1)" "threshold(abc)" ///
            "qtrim(.)" "threshold(.)" "threshold(0.5)" "qtrim(50)" {
        capture noisily psdash support foreign ps, `bad' nograph
        assert _rc == 198
    }
    * positive controls: omitted, and valid explicit values
    quietly psdash support foreign ps, nograph
    assert missing(r(qtrim))
    assert missing(r(n_trimmed))
    quietly psdash support foreign ps, threshold(0.1) nograph
    assert r(trim_lower) == 0.1
    quietly psdash support foreign ps, qtrim(5) nograph
    assert r(qtrim) == 5
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191c_rec support_sentinels_not_user_values `rc'

**# T8 sheet() validated upfront; balance title() with quotes
capture noisily {
    _v191c_binary
    local book "`_qa_sysroot'/v191c_t8.xlsx"
    local cap "`_qa_sysroot'/v191c_t8.txt"
    local s32 "abcdefghijabcdefghijabcdefghij12"
    local s31 "abcdefghijabcdefghijabcdefghij1"
    foreach cmd in "overlap t ps, nograph" "support t ps, nograph" ///
            "balance t ps, covariates(x1 x2) nograph" "weights t ps, wvar(w)" {
        * 11 CJK characters are 33 bytes: over the byte limit putexcel applies
        foreach bad in `"`"Ov "1""'"' "A/B" "A[1]" "a:b" "a*b" "a?b" "`s32'" ///
                "日日日日日日日日日日日" "'lead" "trail'" "History" "hiSTory" {
            capture erase "`book'"
            _v191c_capture "`cap'" psdash `cmd' xlsx("`book'") sheet(`bad')
            assert $V191C_RC == 198
            capture confirm file "`book'"
            assert _rc == 601
            * refused before any panel output
            _v191c_count "`cap'" "Treatment:"
            assert r(n) == 0
        }
        * positive controls: 31 bytes, 10 CJK characters (30 bytes), and an
        * inner apostrophe are valid sheet names
        foreach good in "`s31'" "日日日日日日日日日日" "mid'dle" {
            capture erase "`book'"
            quietly psdash `cmd' xlsx("`book'") sheet(`good')
            import excel using "`book'", sheet("`good'") clear allstring
            assert _N > 2
            _v191c_binary
        }
    }
    * balance title() containing double quotes
    capture erase "`book'"
    local wanted `"Bal "x" table"'
    psdash balance t ps, covariates(x1 x2) nograph xlsx("`book'") ///
        title(`"`wanted'"')
    import excel using "`book'", sheet("Balance") clear allstring
    assert `"`=A[1]'"' == `"`wanted'"'
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191c_rec sheet_validated_upfront `rc'

**# T9 compact multi-group overlap does not print the reshape table
capture noisily {
    sysuse auto, clear
    generate byte arm = mod(_n, 3)
    quietly mlogit arm mpg weight
    quietly predict double p0 p1 p2
    graph drop _all
    local cap "`_qa_sysroot'/v191c_t9.txt"
    _v191c_capture "`cap'" psdash overlap arm, psvars(p0 p1 p2) compact
    assert $V191C_RC == 0
    _v191c_count "`cap'" "Wide   ->   Long"
    assert r(n) == 0
    _v191c_count "`cap'" "Generalized Positivity"
    assert r(n) == 1
    graph describe psdash_overlap
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191c_rec compact_overlap_quiet_reshape `rc'

**# T10 longitudinal combined refuses options it cannot honor
local plus_now = subinstr("`c(sysdir_plus)'", "\", "/", .)
local plus_box = subinstr("`_qa_plus'", "\", "/", .)
local plus_sandboxed = ("`plus_box'" != "" & strpos("`plus_now'", "`plus_box'") == 1)
capture noisily {
    assert `plus_sandboxed'
    assert fileexists("`repo_dir'/msm/msm.pkg")
    capture ado uninstall msm
    quietly net install msm, from("`repo_dir'/msm") replace
    use "`repo_dir'/msm/msm_example.dta", clear
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
        censor_n_cov(age sex) truncate(1 99) nolog
    quietly psdash combined
    assert "`r(estimand)'" == "ate"
    local maxwt = r(max_wt)
    foreach bad in "covariates(age)" "reference(1)" "estimand(att)" {
        capture noisily psdash combined, `bad'
        assert _rc == 198
    }
    capture noisily psdash combined, psvars(age sex)
    assert _rc != 0
    * the producer's own estimand (any case) and reference level 0 of the
    * 0/1 treatment are accepted, change nothing, and r(estimand) keeps the
    * producer's spelling
    foreach ok in "estimand(ate)" "estimand(ATE)" "reference(0)" {
        quietly psdash combined, `ok'
        assert "`r(estimand)'" == "ate"
        assert !missing(r(max_wt)) & !missing(`maxwt')
        assert reldif(r(max_wt), `maxwt') < 1e-14
    }
    capture ado uninstall msm

    * ltmle producer: same rules
    assert fileexists("`repo_dir'/targetlearn/targetlearn.pkg")
    quietly net install targetlearn, from("`repo_dir'/targetlearn") replace
    clear
    set seed 2026072203
    set obs 360
    generate long pid = ceil(_n / 3)
    bysort pid: generate byte period = _n
    generate double bl_x = rnormal() if period == 1
    bysort pid (period): replace bl_x = bl_x[1]
    generate double tv_x = rnormal() + 0.10*period + 0.15*bl_x
    generate byte a_treat = runiform() < 0.5
    generate byte y_out = runiform() < ///
        invlogit(-1.2 + 0.35*bl_x + 0.25*tv_x + 0.70*a_treat)
    generate byte y_terminal = y_out if period == 3
    quietly ltmle, id(pid) period(period) outcome(y_terminal) ///
        treatment(a_treat) covariates(tv_x) baseline(bl_x) nolog
    quietly psdash combined
    assert "`r(source)'" == "ltmle"
    assert "`r(estimand)'" == "ate"
    local maxwt = r(max_wt)
    foreach bad in "covariates(tv_x)" "estimand(att)" "reference(1)" {
        capture noisily psdash combined, `bad'
        assert _rc == 198
    }
    foreach ok in "estimand(ATE)" "reference(0)" {
        quietly psdash combined, `ok'
        assert "`r(estimand)'" == "ate"
        assert !missing(r(max_wt)) & !missing(`maxwt')
        assert reldif(r(max_wt), `maxwt') < 1e-14
    }
    capture ado uninstall targetlearn
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v191c_rec longitudinal_refuses_unhonored_options `rc'

graph drop _all
display "RESULT: test_v191_overlap_support_combined tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
if `fail' display as error "Failed:$V191C_FAILED"
global V191C_FAILED
global V191C_RC
_psdash_qa_cleanup
log close
if `fail' exit 1
