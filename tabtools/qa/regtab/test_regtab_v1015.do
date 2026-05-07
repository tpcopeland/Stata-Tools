* test_regtab_v1015.do — regression tests for tabtools v1.0.15 fixes
* Tests A, B, C, F, G from the 2026-05-07 reviewer punch list:
*   A. ICC cross-pollution: multi-model [melogit, mepoisson] keeps melogit ICC
*   B. Comma-format coefficient destring: coefficients >= 1000 round-trip
*   C. Refcat detection robustness against non-default precision
*   F. Single-model mepoisson: exact ICC-skip note string emitted
*   G. Multi-model collection: ICC-skip note names the affected model index
*
* Run from the package qa/regtab/ directory.

clear all
set more off
set seed 13579

* Resolve package directory from cwd. Supports two callers:
*   (a) standalone:  cwd = .../tabtools/qa/regtab
*   (b) run_all.do:  cwd = .../tabtools/qa
local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/regtab$") {
    local pkg_root = regexr("`_cwd'", "/qa/regtab$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local pkg_root = regexr("`_cwd'", "/qa$", "")
}
else {
    local pkg_root "`_cwd'"
}
* When run via the orchestrator, tabtools is already net installed; helper
* loads itself via findfile on first use. Standalone runs still need the
* manual adopath + helper preload below.
capture _tabtools_helpers_ready
if _rc {
    capture noisily adopath ++ "`pkg_root'"
    capture noisily do "`pkg_root'/_tabtools_common.ado"
}

local pass = 0
local fail = 0
local total = 0

tempname out_dir
local out_dir "`c(tmpdir)'/_regtab_v1015"
capture mkdir "`out_dir'"

display as text _newline "=== test_regtab_v1015 ==="

**# Test A: ICC cross-pollution (multi-model melogit + mepoisson)
* Build a 3-cluster melogit + 3-cluster mepoisson dataset, collect both, then
* request stats(icc). Before the fix, e(cmd2) == "mepoisson" caused the global
* skip to fire and ALL models' ICC went missing. After the fix, melogit ICC
* should still come through.
local ++total
capture noisily {
    clear
    set obs 600
    gen cluster = ceil(_n / 30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort cluster: gen u = `uraw'[1] * 0.6
    gen lp = 0.4 + 0.5 * x + u
    gen y_bin = runiform() < invlogit(lp)
    gen y_cnt = rpoisson(exp(0.3 + 0.4 * x + u))

    collect clear
    collect: melogit y_bin x || cluster:
    collect: mepoisson y_cnt x || cluster:

    capture frame drop _rt_v1015_A
    regtab, frame(_rt_v1015_A, replace) stats(icc) noreeffects

    local melogit_icc = .
    local mepoisson_icc = .
    frame _rt_v1015_A {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "ICC" {
                local melogit_icc  = real(strtrim(c1[`i']))
                local mepoisson_icc = real(strtrim(c4[`i']))
            }
        }
    }
    frame drop _rt_v1015_A

    * After the fix, melogit ICC must be a finite positive value.
    assert `melogit_icc' < . & `melogit_icc' > 0
    * mepoisson ICC must remain missing (no closed-form level-1 variance).
    assert `mepoisson_icc' >= .
}
local rc_A = _rc
if `rc_A' == 0 {
    display as result "  PASS: Test A (multi-model ICC: melogit recovered = `melogit_icc'; mepoisson skipped)"
    local ++pass
}
else {
    display as error "  FAIL: Test A (rc=`rc_A'; melogit_icc=`melogit_icc'; mepoisson_icc=`mepoisson_icc')"
    local ++fail
}

**# Test B: Coefficient >= 1000 destring round-trip
* Build a dataset where the regression coefficient is >= 1000 (collect's default
* %4.2fc format renders as "1,234.56"). Before the fix, destring force returned
* missing and r(table) had no entry for that row. After the fix, the comma is
* stripped before destring and r(table) carries the actual coefficient.
local ++total
capture noisily {
    clear
    set obs 200
    gen x = runiform()
    * Outcome scale picks a coefficient close to 2500 so the formatter must
    * insert a thousands separator.
    gen y = 100 + 2500 * x + rnormal(0, 50)

    collect clear
    collect: regress y x

    local ref_b = _b[x]

    capture frame drop _rt_v1015_B
    regtab, frame(_rt_v1015_B, replace) digits(3)

    tempname rt
    matrix `rt' = r(table)

    * r(table) row 1 col 1 should equal _b[x] within 0.01 absolute.
    local got_b = `rt'[1, 1]
    assert abs(`got_b' - `ref_b') < 0.01
    * The displayed cell must use 3 decimal places (digits(3)) — find the data
    * row containing the variable name "x" (rows 1-3 are headers/labels).
    local cell ""
    frame _rt_v1015_B {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "x" {
                local cell = strtrim(c1[`i'])
                continue, break
            }
        }
        local dot_pos = strpos("`cell'", ".")
        local dec_count = strlen("`cell'") - `dot_pos'
        assert `dec_count' == 3
        assert strpos("`cell'", ",") == 0
    }
    frame drop _rt_v1015_B
}
local rc_B = _rc
if `rc_B' == 0 {
    display as result "  PASS: Test B (large coef destring: ref=`=string(`ref_b', "%9.3f")', got=`=string(`got_b', "%9.3f")')"
    local ++pass
}
else {
    display as error "  FAIL: Test B (rc=`rc_B'; ref_b=`ref_b'; got_b=`got_b'; cell=`cell')"
    local ++fail
}

**# Test C: Refcat detection with non-default precision
* Use a logit with a 4-level factor variable. Reference category coefficient
* is exactly 0 (linear) → 1 (exponentiated) with empty CI. Before the fix the
* "Reference" label only matched literal "0" / "1" strings; if collect rendered
* "1.000" because of a higher-precision format, the label fell off and a numeric
* "1.000" leaked into the cell. After the fix, refcat detection works off the
* numeric value so digits(4) still labels the row.
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg i.rep78

    capture frame drop _rt_v1015_C
    regtab, frame(_rt_v1015_C, replace) digits(4)

    local ref_count = 0
    frame _rt_v1015_C {
        forvalues i = 3/`=_N' {
            local _v = strtrim(c1[`i'])
            if "`_v'" == "Reference" local ++ref_count
        }
    }
    frame drop _rt_v1015_C

    * 4-level rep78 → 1 reference row (the omitted base).
    assert `ref_count' >= 1
}
local rc_C = _rc
if `rc_C' == 0 {
    display as result "  PASS: Test C (refcat detection at digits(4): `ref_count' Reference row(s))"
    local ++pass
}
else {
    display as error "  FAIL: Test C (rc=`rc_C'; ref_count=`ref_count')"
    local ++fail
}

**# Helper: assert string appears in a captured log file
* Slurps the log file, joining Stata's hard-wrapped continuation lines
* (`\n> ` markers from batch mode line-wrap at column ~80), then asserts
* `needle' appears in the resulting concatenated content. This locks the
* exact Note text emitted by regtab without being defeated by the column
* wrap that Stata applies when writing display strings to a text log.
capture program drop _v1015_assert_in_log
program define _v1015_assert_in_log
    args path needle
    capture confirm file `"`path'"'
    if _rc {
        display as error "  log file not found: `path'"
        exit 601
    }
    tempname _vfh
    local _content ""
    file open `_vfh' using `"`path'"', read text
    file read `_vfh' line
    while r(eof) == 0 {
        * Strip Stata's batch wrap-continuation prefix exactly "> " (gt,
        * single space). The wrap point preserves the original character at
        * column 1 of the continuation, so the leading space from the source
        * text typically remains as the first char after the marker. Removing
        * only "> " (not "> +") rejoins exactly as the user-visible string.
        if regexm(`"`line'"', "^> ") {
            local line = regexr(`"`line'"', "^> ", "")
            local _content `"`_content'`line'"'
        }
        else {
            local _content `"`_content' `line'"'
        }
        file read `_vfh' line
    }
    file close `_vfh'
    if strpos(`"`_content'"', `"`needle'"') == 0 {
        display as error "  needle not found in `path':"
        display as error "    `needle'"
        exit 9
    }
end

**# Test F: single-model mepoisson — exact ICC-skip Note string
* Lock the user-facing message that fires when every model in the collection
* has an undefined level-1 variance. The exact wording is part of the
* contract: any future refactor that drops the parenthetical must update
* this assertion too.
local _f_log "`out_dir'/_test_F.log"
capture erase "`_f_log'"
local ++total
capture noisily {
    clear
    set obs 600
    gen group = ceil(_n / 30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.5
    gen mu = exp(0.5 + 0.3 * x + u)
    gen y = rpoisson(mu)

    collect clear
    collect: mepoisson y x || group:

    log using `"`_f_log'"', replace text name(_v1015_F)
    capture frame drop _rt_v1015_F
    regtab, frame(_rt_v1015_F, replace) stats(icc)
    capture log close _v1015_F
    capture frame drop _rt_v1015_F

    _v1015_assert_in_log `"`_f_log'"' ///
        "Note: ICC not computed (no closed-form level-1 variance for the requested model family)"
}
local rc_F = _rc
capture log close _v1015_F
if `rc_F' == 0 {
    display as result "  PASS: Test F (single-model mepoisson — exact Note string emitted)"
    local ++pass
}
else {
    display as error "  FAIL: Test F (rc=`rc_F'; see `_f_log')"
    local ++fail
}

**# Test G: multi-model — ICC-skip Note names the affected position(s)
* Two-model collection [melogit, mepoisson]. Note must list the count-data
* position only; melogit ICC must still be recovered. Lock both the message
* template and the listed index.
local _g_log "`out_dir'/_test_G.log"
capture erase "`_g_log'"
local ++total
capture noisily {
    clear
    set obs 600
    gen cluster = ceil(_n / 30)
    gen x = rnormal()
    tempvar uraw2
    gen `uraw2' = rnormal()
    bysort cluster: gen u = `uraw2'[1] * 0.6
    gen lp = 0.4 + 0.5 * x + u
    gen y_bin = runiform() < invlogit(lp)
    gen y_cnt = rpoisson(exp(0.3 + 0.4 * x + u))

    collect clear
    collect: melogit y_bin x || cluster:
    collect: mepoisson y_cnt x || cluster:

    log using `"`_g_log'"', replace text name(_v1015_G)
    capture frame drop _rt_v1015_G
    regtab, frame(_rt_v1015_G, replace) stats(icc) noreeffects
    capture log close _v1015_G
    capture frame drop _rt_v1015_G

    * mepoisson is the second model — index 2 must appear in the note.
    _v1015_assert_in_log `"`_g_log'"' ///
        "Note: ICC not computed for model(s) 2 (no closed-form level-1 variance)"
}
local rc_G = _rc
capture log close _v1015_G
if `rc_G' == 0 {
    display as result "  PASS: Test G (multi-model — Note lists position 2 only)"
    local ++pass
}
else {
    display as error "  FAIL: Test G (rc=`rc_G'; see `_g_log')"
    local ++fail
}

**# Summary
display as text _newline "=== Summary ==="
display as text "Total : `total'"
display as result "Pass  : `pass'"
if `fail' > 0 display as error "Fail  : `fail'"
else display as text "Fail  : 0"

if `fail' > 0 exit `fail'
