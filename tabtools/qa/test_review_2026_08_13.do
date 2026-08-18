*! test_review_2026_08_13.do  2026-08-13
*! Regression pins for the 2026-08-13 review of tabtools 1.14.2
*! Author: Timothy P Copeland, Karolinska Institutet
*!
*! R1-R6 pin the percentage-denominator disclosure defect in
*! table1_tc, smallcells(): a published percentage releases its own
*! denominator (the per-variable, per-group non-missing count), which the
*! suppression engine models as unreleased. Dividing a published count by its
*! published percentage recovers that denominator; subtracting the published
*! counts then reconstructs a primary-suppressed count EXACTLY, at rc 0, under
*! a table the engine has certified. R1 is a live reconstruction attack rather
*! than a "was a percentage printed" check: it is the axis the shipped
*! smallcells suites do not probe. validation_smallcells.do's V8 gate drives
*! the ENGINE directly with every cell and margin declared released, so it
*! validates the engine against its own model and never sees a caller that
*! under-declares. test_smallcells.do's "raw-leak attack" greps the CSV and
*! Markdown for the literal raw values, so it cannot see a value that is
*! arithmetically recoverable rather than textually present.
*!
*! R7 pins the corrtab star-legend inconsistency: identical thresholds printed
*! two different legends depending on whether they came from the default or
*! from star().

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _rv0813
log using "test_review_2026_08_13.log", replace text name(_rv0813)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

capture program drop _rv_record
program define _rv_record
    args label rc passed failed
    if `rc' == 0 {
        display as result "  PASS: `label'"
        c_local pass_count = `passed' + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        c_local fail_count = `failed' + 1
        c_local failed_tests "`failed_tests' `label'"
    }
end

/* Reconstruction attack.

   Reads a rendered table1_tc frame and plays the part of a reader who has only
   the printed page. For one group column it collects every published
   "count (percent)" pair, intersects the denominator intervals each pair
   implies, and -- when that pins a single integer denominator -- subtracts the
   published counts from it. If exactly one cell in the column is
   primary-suppressed, the subtraction returns that cell's exact value.

   Sets r(recovered) to the reconstructed count, or missing when the column
   cannot be reduced to a single value. A successful reconstruction is a
   disclosure failure, not a pass.

   LIMIT: the cell parser assumes the default "n (%)" ordering. Under
   percent_n the components are reversed to "% (n)" and it would read the
   percentage as the count. R3 drives percent_n with a single, fully protected
   variable, so no "x (y)" cell survives for it to misread. Anything that adds
   an UNPROTECTED variable to a percent_n case must teach the parser the
   ordering first, or it will derive a denominator from the wrong component. */
capture program drop _rv_attack
program define _rv_attack, rclass
    version 16.0
    syntax , FRame(name) COLumn(name) [FIRSTrow(integer 1) PCTDigits(integer 0)]

    tempname lo hi
    scalar `lo' = 0
    scalar `hi' = .
    local published_sum = 0
    local n_suppressed = 0
    local n_pairs = 0

    frame `frame' {
        quietly count
        local nrows = r(N)
        forvalues i = `firstrow'/`nrows' {
            local cell = strtrim(`column'[`i'])
            if "`cell'" == "" continue
            * A suppression marker, not a publishable count.
            if strpos("`cell'", "<") > 0 | strpos("`cell'", "≥") > 0 {
                local ++n_suppressed
                continue
            }
            * "9 (43)" -> n = 9, pct = 43. Anything else is a label row.
            if !regexm("`cell'", "^([0-9][0-9,]*) \(([0-9.]+)\)$") continue
            local _n = subinstr(regexs(1), ",", "", .)
            local _p = regexs(2)
            local published_sum = `published_sum' + `_n'
            local ++n_pairs
            if `_p' == 0 continue
            * A percent shown to `pctdigits' places came from a true value in
            * [p - half, p + half); invert to bound the denominator.
            local half = 0.5 / (10 ^ `pctdigits')
            local plo = (`_p' - `half') / 100
            local phi = (`_p' + `half') / 100
            local dlo = `_n' / `phi'
            local dhi = `_n' / `plo'
            if `dlo' > scalar(`lo') scalar `lo' = `dlo'
            if missing(scalar(`hi')) | `dhi' < scalar(`hi') scalar `hi' = `dhi'
        }
    }

    return scalar n_pairs = `n_pairs'
    return scalar n_suppressed = `n_suppressed'
    return scalar recovered = .
    if `n_pairs' == 0 | `n_suppressed' != 1 exit
    if missing(scalar(`hi')) exit

    * Unique integer denominator in [lo, hi]?
    local dmin = ceil(scalar(`lo') - 1e-9)
    local dmax = floor(scalar(`hi') + 1e-9)
    if `dmin' != `dmax' exit
    return scalar recovered = `dmax' - `published_sum'
end

**# R1: reconstruction attack on the shipped auto example

local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop rv1
    table1_tc, by(foreign) vars(rep78 cat) smallcells(5) frame(rv1)

    * The Foreign column holds exactly one primary suppression (rep78 == 3,
    * true value 3) alongside published 0, 0, 9, 9 and a header N of 22.
    * Before the fix, "9 (43)" pinned the denominator at 21 and the
    * suppressed cell fell out as 21 - 0 - 0 - 9 - 9 = 3.
    quietly frame rv1: ds foreign*
    local _grpvars "`r(varlist)'"
    local _fgn : word 2 of `_grpvars'

    _rv_attack, frame(rv1) column(`_fgn')
    assert r(n_suppressed) == 1
    assert missing(r(recovered))

    * And the same for the reference (Domestic) column.
    local _dom : word 1 of `_grpvars'
    _rv_attack, frame(rv1) column(`_dom')
    assert missing(r(recovered))
}
_rv_record "reconstruction attack cannot recover a suppressed count (auto/rep78)" `=_rc' `pass_count' `fail_count'

**# R2: reconstruction attack across three groups

local ++test_count
capture noisily {
    sysuse auto, clear
    generate byte grp = 1 + mod(_n, 3)
    capture frame drop rv2
    table1_tc, by(grp) vars(rep78 cat) smallcells(5) frame(rv2)

    * Before the fix the grp == 3 column pinned its denominator at 25 three
    * independent ways (10 -> 40%, 8 -> 32%, 5 -> 20%) and returned the
    * suppressed cell as 25 - 0 - 10 - 8 - 5 = 2, its true value.
    frame rv2 {
        quietly ds grp*
        local _grpcols "`r(varlist)'"
    }
    assert `: word count `_grpcols'' == 3
    foreach v of local _grpcols {
        _rv_attack, frame(rv2) column(`v')
        assert missing(r(recovered))
    }
}
_rv_record "reconstruction attack fails across three group columns" `=_rc' `pass_count' `fail_count'

**# R3: the same attack against every affected display mode

local ++test_count
capture noisily {
    foreach mode in "total(after)" "slashN" "missingsummary" "percent_n" {
        sysuse auto, clear
        capture frame drop rv3
        table1_tc, by(foreign) vars(rep78 cat) smallcells(5) `mode' frame(rv3)
        frame rv3 {
            quietly ds
            local _allv "`r(varlist)'"
        }
        foreach v of local _allv {
            if "`v'" == "factor" continue
            frame rv3 {
                capture confirm string variable `v'
                local _isstr = (_rc == 0)
            }
            if !`_isstr' continue
            _rv_attack, frame(rv3) column(`v')
            assert missing(r(recovered))
        }
    }
}
_rv_record "reconstruction attack fails under total/slashN/missingsummary/percent_n" `=_rc' `pass_count' `fail_count'

**# R4: a protected variable publishes no percentage at all

local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop rv4
    table1_tc, by(foreign) vars(rep78 cat) smallcells(5) frame(rv4)
    assert r(N_primary_suppressed) > 0

    frame rv4 {
        quietly ds
        local _vars "`r(varlist)'"
        local _pct_cells = 0
        foreach v of local _vars {
            capture confirm string variable `v'
            if _rc continue
            if "`v'" == "factor" continue
            quietly count if regexm(`v', "\([0-9.]+\)$")
            local _pct_cells = `_pct_cells' + r(N)
        }
        assert `_pct_cells' == 0
    }
}
_rv_record "protected variable publishes counts only, no percentages" `=_rc' `pass_count' `fail_count'

**# R5: withholding is per variable, not table-wide

local ++test_count
capture noisily {
    * evenmpg splits every group well above the threshold, so its block is
    * never protected; rep78 carries the small cells. Both live in one table,
    * so withholding must be scoped to the protected block only.
    sysuse auto, clear
    generate byte evenmpg = mod(mpg, 2)
    capture frame drop rv5
    table1_tc, by(foreign) vars(evenmpg cat \ rep78 cat) smallcells(5) frame(rv5)
    assert r(N_primary_suppressed) > 0

    frame rv5 {
        quietly ds
        local _vars "`r(varlist)'"
        quietly count
        local _n = r(N)

        * The output frame carries only factor, the group columns and pvalue,
        * so a level row is attributed to its block by indentation: an
        * unindented factor starts a new variable block, indented rows belong
        * to the most recent one.
        local _pct_unprotected = 0
        local _pct_protected = 0
        local _owner ""
        forvalues i = 1/`_n' {
            local _fac = factor[`i']
            if `"`_fac'"' == "" continue
            if substr(`"`_fac'"', 1, 1) != " " {
                local _owner `"`_fac'"'
                continue
            }
            if `"`_owner'"' == "" continue
            local _is_rep78 = (strpos(`"`_owner'"', "Repair") > 0)
            foreach v of local _vars {
                capture confirm string variable `v'
                if _rc continue
                if inlist("`v'", "factor", "factor_sep") continue
                local _cell = strtrim(`v'[`i'])
                if !regexm("`_cell'", "\([0-9.]+\)$") continue
                if `_is_rep78' local ++_pct_protected
                else local ++_pct_unprotected
            }
        }
        * The protected block publishes no percentage ...
        assert `_pct_protected' == 0
        * ... and the unprotected block in the same table keeps every one.
        assert `_pct_unprotected' > 0
    }
}
_rv_record "an unprotected variable keeps its percentages under smallcells()" `=_rc' `pass_count' `fail_count'

**# R6: percent-only display is refused, explicitly and implicitly

local ++test_count
capture noisily {
    sysuse auto, clear
    capture table1_tc, by(foreign) vars(rep78 cat) percent smallcells(5)
    assert _rc == 198

    * wt() without wtn/percent_n silently selects the percent-only default, so
    * the guard has to sit after that assignment, not before it.
    sysuse auto, clear
    generate double w = 1 + mod(_n, 3)
    capture table1_tc, by(foreign) vars(rep78 cat) wt(w) smallcells(5)
    assert _rc == 198

    * ... but the same weighted table is accepted once counts are restored.
    sysuse auto, clear
    generate double w = 1 + mod(_n, 3)
    capture frame drop rv6
    capture noisily table1_tc, by(foreign) vars(rep78 cat) wt(w) wtn smallcells(5) frame(rv6)
    assert _rc == 0
}
_rv_record "percent-only display refused with smallcells(), explicit and implicit" `=_rc' `pass_count' `fail_count'

**# R7: corrtab star legend does not depend on how the thresholds arrived

local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop rv7a
    capture frame drop rv7b
    quietly corrtab price mpg weight, frame(rv7a)
    local _default_methods `"`r(methods)'"'
    quietly corrtab price mpg weight, star(0.05 0.01 0.001) frame(rv7b)
    local _explicit_methods `"`r(methods)'"'

    * Same thresholds, same table: one legend.
    assert `"`_default_methods'"' == `"`_explicit_methods'"'
    assert strpos(`"`_default_methods'"', "p<0.05") > 0
    assert strpos(`"`_default_methods'"', "p<0.01") > 0
    assert strpos(`"`_default_methods'"', "p<0.001") > 0
    * The bare-point form is what the defect produced.
    assert strpos(`"`_explicit_methods'"', "p<.05") == 0
    assert strpos(`"`_explicit_methods'"', "p<.01") == 0
    assert strpos(`"`_explicit_methods'"', "p<.001") == 0

    * A threshold set that is not the default renders the same way.
    quietly corrtab price mpg weight, star(0.1 0.05 0.01)
    assert strpos(`"`r(methods)'"', "p<0.1") > 0
    assert strpos(`"`r(methods)'"', "p<.1,") == 0
}
_rv_record "corrtab star legend is identical for default and explicit thresholds" `=_rc' `pass_count' `fail_count'

**# Summary

display as result "Review 2026-08-13 tests: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_review_2026_08_13 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rv0813
if `fail_count' > 0 exit 1
