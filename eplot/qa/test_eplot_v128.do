*! test_eplot_v128.do - Regression tests for eplot 1.2.8
*! Covers defects found by the 2026-08-11 deep review.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_eplot_v128.log", replace text nomsg

local qa_dir "`c(pwd)'"
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

capture program drop _qa_sthlp_render
program define _qa_sthlp_render, rclass
    version 16.0
    syntax anything(name=files id="help files")

    local files = subinstr(`"`files'"', char(34), "", .)
    local nbad 0
    local badfiles ""

    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
            display as error "  render: file not found: `f'"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }

        tempfile rlog
        capture log off
        log using "`rlog'", replace text name(_qarender)
        type "`f'", smcl
        log close _qarender
        capture log on

        local hits 0
        local nlines 0
        tempname fh
        file open `fh' using "`rlog'", read text
        file read `fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
                local shown = subinstr(`"`line'"', "{", char(1), .)
                local shown = subinstr(`"`shown'"', "}", char(2), .)
                local shown = subinstr(`"`shown'"', char(1), "{c -(}", .)
                local shown = subinstr(`"`shown'"', char(2), "{c )-}", .)
                display as error "  literal SMCL: `shown'"
                local ++hits
            }
            file read `fh' line
        }
        file close `fh'

        if `nlines' == 0 {
            display as error "  render produced no output for `f' -- FAILING"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }
        if `hits' > 0 {
            local ++nbad
            local badfiles "`badfiles' `f'"
        }
    }

    return scalar nbad = `nbad'
    return local badfiles "`badfiles'"
end

**# Stored-estimate contracts

**## Multi-equation coefficients retain equation identity
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly sureg (price mpg weight) (length mpg weight)
    eplot ., noconstant name(eplot_v128_t1, replace)
    matrix T = r(table)
    assert rowsof(T) == 4
    assert r(k) == 4
    local roweq : roweq T
    local unique_eq : list uniq roweq
    local neq : word count `unique_eq'
    assert `neq' == 2
}
if _rc == 0 {
    display as result "  PASS: Multi-equation identities remain distinct"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-equation identities collapsed (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}
capture graph drop eplot_v128_t1

**## r(k) counts coefficients, not model-by-coefficient rows
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store eplot_v128_m1
    quietly regress length mpg weight
    estimates store eplot_v128_m2
    eplot eplot_v128_m1 eplot_v128_m2, noconstant ///
        name(eplot_v128_t2, replace)
    matrix T = r(table)
    assert r(n_models) == 2
    assert rowsof(T) == 2
    assert r(N) == 2
    assert r(k) == 2
    estimates drop eplot_v128_m1 eplot_v128_m2
}
if _rc == 0 {
    display as result "  PASS: Multi-model r(k) counts unique coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-model r(k) contract is wrong (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture graph drop eplot_v128_t2
capture estimates drop eplot_v128_m1 eplot_v128_m2

**## Named estimates preserve an initially empty e() state
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store eplot_v128_empty
    ereturn clear
    assert "`e(cmd)'" == ""
    eplot eplot_v128_empty, noconstant name(eplot_v128_t3, replace)
    assert "`e(cmd)'" == ""
    estimates drop eplot_v128_empty
}
if _rc == 0 {
    display as result "  PASS: Empty active estimation state is preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Named estimate leaked into active e() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture graph drop eplot_v128_t3
capture estimates drop eplot_v128_empty

**## Eform label follows the requested named estimate
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg weight
    estimates store eplot_v128_logit
    quietly regress price mpg weight
    matrix B_before = e(b)
    quietly count if e(sample)
    local sample_before = r(N)
    eplot eplot_v128_logit, eform noconstant ///
        name(eplot_v128_t4, replace)
    local graphcmd `"`r(cmd)'"'
    assert strpos(`"`graphcmd'"', "Odds Ratio (95% CI)") > 0
    assert "`e(cmd)'" == "regress"
    matrix B_after = e(b)
    assert mreldif(B_before, B_after) < 1e-12
    quietly count if e(sample)
    assert r(N) == `sample_before'
    estimates drop eplot_v128_logit
}
if _rc == 0 {
    display as result "  PASS: Named-model eform label and caller state are correct"
    local ++pass_count
}
else {
    display as error "  FAIL: Named-model eform label used stale e() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}
capture graph drop eplot_v128_t4
capture estimates drop eplot_v128_logit

**## Invalid covariance matrices fail explicitly and preserve empty e()
capture program drop _eplot_v128_bad_est
program define _eplot_v128_bad_est, eclass
    version 16.0
    tempname b V
    matrix `b' = (1)
    matrix colnames `b' = x
    matrix `V' = (-1)
    matrix colnames `V' = x
    matrix rownames `V' = x
    ereturn post `b' `V'
    ereturn local cmd "eplot_v128_bad_est"
end

local ++test_count
capture noisily {
    clear
    _eplot_v128_bad_est
    estimates store eplot_v128_badv
    ereturn clear
    capture noisily eplot eplot_v128_badv, name(eplot_v128_t5, replace)
    assert _rc == 498
    assert "`e(cmd)'" == ""
    estimates drop eplot_v128_badv
}
if _rc == 0 {
    display as result "  PASS: Invalid e(V) is rejected without leaking state"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid e(V) was not handled explicitly (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}
capture graph drop eplot_v128_t5
capture estimates drop eplot_v128_badv

**# Transformation and input validation

**## Negative rescale keeps ordered confidence limits in every numeric mode
local ++test_count
capture noisily {
    clear
    input double(es ll ul)
    1 .5 1.5
    end
    eplot es ll ul, rescale(-2) name(eplot_v128_t6a, replace)
    matrix TD = r(table)
    assert !missing(TD[1, 1], -2)
    assert reldif(TD[1, 1], -2) < 1e-12
    assert !missing(TD[1, 2], -3)
    assert reldif(TD[1, 2], -3) < 1e-12
    assert !missing(TD[1, 3], -1)
    assert reldif(TD[1, 3], -1) < 1e-12

    matrix R = (1, .5, 1.5)
    matrix rownames R = x
    eplot, matrix(R) rescale(-2) name(eplot_v128_t6b, replace)
    matrix TM = r(table)
    assert !missing(TM[1, 1], -2)
    assert reldif(TM[1, 1], -2) < 1e-12
    assert !missing(TM[1, 2], -3)
    assert reldif(TM[1, 2], -3) < 1e-12
    assert !missing(TM[1, 3], -1)
    assert reldif(TM[1, 3], -1) < 1e-12

    sysuse auto, clear
    quietly regress price mpg
    matrix B = e(b)
    eplot ., noconstant rescale(-2) name(eplot_v128_t6c, replace)
    matrix TE = r(table)
    assert !missing(TE[1, 1], -2 * B[1, 1])
    assert reldif(TE[1, 1], -2 * B[1, 1]) < 1e-12
    assert TE[1, 2] <= TE[1, 1]
    assert TE[1, 1] <= TE[1, 3]
}
if _rc == 0 {
    display as result "  PASS: Negative rescale preserves lower/upper ordering"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative rescale reversed CI bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}
capture graph drop eplot_v128_t6a eplot_v128_t6b eplot_v128_t6c

**## Reversed limits and negative standard errors are rejected
local ++test_count
capture noisily {
    clear
    input double(es ll ul)
    1 2 0
    end
    capture noisily eplot es ll ul, name(eplot_v128_t7a, replace)
    assert _rc == 198

    matrix R3 = (1, 2, 0)
    matrix rownames R3 = x
    capture noisily eplot, matrix(R3) name(eplot_v128_t7b, replace)
    assert _rc == 198

    matrix R2 = (1, -.5)
    matrix rownames R2 = x
    capture noisily eplot, matrix(R2) name(eplot_v128_t7c, replace)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Invalid interval inputs are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid interval input returned success (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}
capture graph drop eplot_v128_t7a eplot_v128_t7b eplot_v128_t7c

**## Row types accept documented effects and reject unknown codes
local ++test_count
capture noisily {
    clear
    input str8 kind double(es ll ul)
    "effect" 1 .5 1.5
    end
    eplot es ll ul, type(kind) name(eplot_v128_t8a, replace)
    assert r(k) == 1

    replace kind = "typo"
    capture noisily eplot es ll ul, type(kind) name(eplot_v128_t8b, replace)
    assert _rc == 198

    drop kind
    gen byte kind = 7
    capture noisily eplot es ll ul, type(kind) name(eplot_v128_t8c, replace)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Row-type vocabulary is validated"
    local ++pass_count
}
else {
    display as error "  FAIL: Unknown row type was accepted (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}
capture graph drop eplot_v128_t8a eplot_v128_t8b eplot_v128_t8c

**## P-values must lie in the unit interval
local ++test_count
capture noisily {
    clear
    input double(es ll ul p)
    1 .5 1.5 -.1
    end
    capture noisily eplot es ll ul, pvalue(p) name(eplot_v128_t9a, replace)
    assert _rc == 198
    replace p = 1.1
    capture noisily eplot es ll ul, pvalue(p) name(eplot_v128_t9b, replace)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Out-of-range p-values are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Out-of-range p-value was accepted (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}
capture graph drop eplot_v128_t9a eplot_v128_t9b

**# Option interaction contracts

**## Horizontal and vertical are mutually exclusive in every mode
local ++test_count
capture noisily {
    clear
    input double(es ll ul)
    1 .5 1.5
    end
    capture noisily eplot es ll ul, horizontal vertical
    assert _rc == 198

    matrix R = (1, .5, 1.5)
    matrix rownames R = x
    capture noisily eplot, matrix(R) horizontal vertical
    assert _rc == 198

    sysuse auto, clear
    quietly regress price mpg
    capture noisily eplot ., noconstant horizontal vertical
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Conflicting orientations are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Conflicting orientations were accepted (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}
capture graph drop _all

**## Sort and order() are mutually exclusive in every mode
local ++test_count
capture noisily {
    clear
    input str1 label double(es ll ul)
    "A" 1 .5 1.5
    end
    capture noisily eplot es ll ul, labels(label) sort order("A")
    assert _rc == 198

    matrix R = (1, .5, 1.5)
    matrix rownames R = x
    capture noisily eplot, matrix(R) sort order(x)
    assert _rc == 198

    sysuse auto, clear
    quietly regress price mpg
    capture noisily eplot ., noconstant sort order(mpg)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Conflicting ordering options are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Conflicting ordering options were accepted (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}
capture graph drop _all

**## favors() requires exactly two nonempty labels
local ++test_count
capture noisily {
    clear
    input double(es ll ul)
    1 .5 1.5
    end
    capture noisily eplot es ll ul, favors("Left only")
    assert _rc == 198
    capture noisily eplot es ll ul, favors("Left" "Right" "Extra")
    assert _rc == 198
    eplot es ll ul, favors("Left" "Right") name(eplot_v128_t12, replace)
    assert r(k) == 1
}
if _rc == 0 {
    display as result "  PASS: favors() enforces its two-label contract"
    local ++pass_count
}
else {
    display as error "  FAIL: Malformed favors() was accepted (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}
capture graph drop eplot_v128_t12

**# Messages and release surface

**## Interaction coefficients are plotted without a false exclusion note
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price c.mpg##c.weight
    tempfile interaction_log
    capture log off
    log using "`interaction_log'", replace text name(_interaction)
    capture noisily eplot ., noconstant name(eplot_v128_t13, replace)
    local plot_rc = _rc
    if `plot_rc' == 0 {
        matrix T = r(table)
        local fullnames : rowfullnames T
    }
    log close _interaction
    capture log on
    assert `plot_rc' == 0
    assert rowsof(T) == 3
    assert strpos(`"`fullnames'"', "#") > 0

    local excluded_hits 0
    tempname ifh
    file open `ifh' using "`interaction_log'", read text
    file read `ifh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "excluded from plot") > 0 {
            local ++excluded_hits
        }
        file read `ifh' line
    }
    file close `ifh'
    assert `excluded_hits' == 0
}
local interaction_rc = _rc
if `interaction_rc' == 0 {
    display as result "  PASS: Interaction output matches plotted content"
    local ++pass_count
}
else {
    capture log close _interaction
    capture log on
    display as error "  FAIL: Interaction output falsely claims exclusion (error `interaction_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}
capture graph drop eplot_v128_t13

**## Help abbreviations, row types, and rendered SMCL match the command
local ++test_count
capture noisily {
    local pkg_dir = regexr("`qa_dir'", "/qa$", "")
    local saw_rename 0
    local saw_headings 0
    local saw_effect_type 0
    tempname hfh
    file open `hfh' using "`pkg_dir'/eplot.sthlp", read text
    file read `hfh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "{opt ren:ame(spec)}") > 0 local saw_rename 1
        if strpos(`"`macval(line)'"', "{opt head:ings(spec)}") > 0 local saw_headings 1
        if strpos(`"`macval(line)'"', `"{cmd:"effect"}"') > 0 local saw_effect_type 1
        file read `hfh' line
    }
    file close `hfh'
    assert `saw_rename' == 1
    assert `saw_headings' == 1
    assert `saw_effect_type' == 1

    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    local paths ""
    foreach s of local sthlps {
        local paths "`paths' `pkg_dir'/`s'"
    }
    _qa_sthlp_render `paths'
    assert r(nbad) == 0

    tempfile brokenbase
    local broken "`brokenbase'.sthlp"
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    _qa_sthlp_render `broken'
    assert r(nbad) == 1
}
if _rc == 0 {
    display as result "  PASS: Shipped help matches syntax and renders cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: Help contract or render oracle failed (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**## Fractional and out-of-sample row types are rejected
local ++test_count
capture noisily {
    clear
    input double(kind es ll ul)
    1.5 1 .5 1.5
    end
    capture noisily eplot es ll ul, type(kind)
    assert _rc == 198

    clear
    input str8 kind double(es ll ul)
    "typo" . . .
    end
    capture noisily eplot es ll ul, type(kind)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: All supplied row-type values are validated"
    local ++pass_count
}
else {
    display as error "  FAIL: A supplied row type escaped validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}

**## favors() is rejected in vertical layout in every mode
local ++test_count
capture noisily {
    clear
    input double(es ll ul)
    1 .5 1.5
    end
    capture noisily eplot es ll ul, vertical favors("Left" "Right")
    assert _rc == 198

    matrix R = (1, .5, 1.5)
    matrix rownames R = x
    capture noisily eplot, matrix(R) vertical favors("Left" "Right")
    assert _rc == 198

    sysuse auto, clear
    quietly regress price mpg
    capture noisily eplot ., noconstant vertical favors("Left" "Right")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: favors() rejects incompatible vertical layout"
    local ++pass_count
}
else {
    display as error "  FAIL: Vertical favors() was silently ignored (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}
capture graph drop _all

**# Summary

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_eplot_v128 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    exit 1
}
