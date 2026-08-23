* test_finegray_sthlp_render.do
* The RENDER axis for the shipped help files.
*
* Four suites in this package grep .sthlp SOURCE (test_documentation_examples.do
* and friends).  Source is not what the user reads.  A directive that is split
* across a source newline -- `{cmd:finegray}' broken after `{cmd:' -- satisfies
* every source check ever written, because the tokens it looks for are all
* present, and then prints to the Viewer as literal markup.  Nothing in this
* package's QA looked at the rendered output; the only render evidence was an
* external tool run by hand.
*
* `translate ..., translator(smcl2txt)' IS Stata's SMCL renderer, so what it
* emits is what the Viewer would show.  An unresolved directive survives into
* the text verbatim, which is exactly the failure signature.
*
* The file list is read from the package directory rather than hard-coded, so a
* help file added later cannot dodge this check by not being on a list.
*
* This suite ends with a FAULT INJECTION: it renders a deliberately broken
* .sthlp and asserts the checker flags it.  Without that, "0 literal-markup
* lines" is indistinguishable from a checker that cannot fire -- the exact shape
* qa/README.md records for the determinism test.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_sthlp_render.log", replace name(_rend)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Count lines that still carry an SMCL directive after rendering.  Returns
* r(nbad), r(nlines), and lists up to 10 offenders.
capture program drop _fg_render_check
program define _fg_render_check, rclass
    version 16.0
    syntax , SRC(string) OUT(string)

    capture erase "`out'"
    quietly translate "`src'" "`out'", translator(smcl2txt) replace

    * char(1) as the delimiter keeps each rendered line whole: the text is full
    * of quotes, commas and backticks, and any of them would otherwise split a
    * line into columns or die in a macro reference.
    quietly import delimited using "`out'", delimiter(`"`=char(1)'"') ///
        varnames(nonames) stringcols(_all) clear

    * An SMCL directive is `{' + a keyword character.  A bare `{' in prose (or a
    * Stata brace in an example) is not matched, which is what keeps this from
    * flagging every code block in the file.
    quietly count if regexm(v1, "\{[a-zA-Z_]")
    local _nbad = r(N)
    local _nlines = _N
    if `_nbad' > 0 {
        display as error "  literal markup survived rendering in `src':"
        quietly gen long _srcline = _n
        quietly keep if regexm(v1, "\{[a-zA-Z_]")
        * `in 1/10' on a shorter dataset is r(198) -- which would abort the
        * caller's capture block and report the DETECTION as a checker failure.
        quietly keep in 1/`=min(10, _N)'
        list _srcline v1, noobs
    }
    clear
    return scalar nbad = `_nbad'
    return scalar nlines = `_nlines'
end

* Count rendered PROSE lines carrying a whitespace artifact -- the SECOND render
* axis, and the one test 1 is blind to.  A source line break inside a hyphenated
* compound, or immediately after sentence-ending punctuation, resolves its markup
* perfectly and still prints wrong: SMCL joins two source lines with one space, so
* `inverse-probability-of-' + `censoring' renders as "inverse-probability-of-
* censoring" and `...one.' + `The...' renders as "one.  The".  Every source-text
* check in this package passes both, and so does the literal-markup check above.
*
* Found by hand on 2026-08-10 in finegray.sthlp, twice, in the SAME release that
* had just repaired two instances of the identical defect in finegray_cif.sthlp
* -- because the guard written for that repair pinned two literal strings in one
* file instead of asserting an invariant over every shipped file.  This is that
* invariant.  Returns r(nbad), r(nlines) and lists up to 10 offenders.
*
* KNOWN BLIND SPOT, stated so nobody reads a green RENDER-3 as "no artifacts".
* This scans the render LINE BY LINE, so an artifact that lands on a wrap
* boundary -- the renderer breaking the line between the two spaces -- is
* invisible here.  One such case existed in finegray.sthlp when this check was
* written (`...across sessions;' + `refitting...', line 487) and RENDER-3 passed
* over it; the SOURCE-side counterpart caught it, so the two are complementary
* and neither replaces the other:
*
*   python3 -m _devkit.stata_dev_cli check package finegray --view findings
*
* That checker (`punct_line_break') tests source lines ending in . : ; ? ! and
* is wrap-independent but cannot see the hyphen class, which is why this one
* exists.  Run both.
capture program drop _fg_render_ws
program define _fg_render_ws, rclass
    version 16.0
    syntax , SRC(string) OUT(string)

    capture erase "`out'"
    quietly translate "`src'" "`out'", translator(smcl2txt) replace

    quietly import delimited using "`out'", delimiter(`"`=char(1)'"') ///
        varnames(nonames) stringcols(_all) clear

    * A suspended hyphen ("a subject- or cluster-bootstrap") is correct English
    * and renders character-for-character like the defect.  Neutralise the three
    * conjunctions it can precede rather than widening the pattern, which would
    * lose the defect along with the false positive.
    quietly gen strL _probe = v1
    foreach _w in or and to {
        quietly replace _probe = subinstr(_probe, "- `_w' ", "-`_w'-", .)
    }

    * EXACTLY two spaces, never an aligned column.  SMCL joins two source lines
    * with one space, so the artifact is always 1 + 1 = 2; the {synopt} and
    * stored-result tables pad with many more, and a third space fails the
    * trailing [A-Za-z].  Their labels also do not end in sentence punctuation,
    * so the second pattern cannot reach them either.
    local _pat1 "[a-zA-Z]- [a-z]"
    local _pat2 "[a-zA-Z][.,;:]  [A-Za-z]"

    quietly count if regexm(_probe, "`_pat1'") | regexm(_probe, "`_pat2'")
    local _nbad = r(N)
    local _nlines = _N
    if `_nbad' > 0 {
        display as error "  rendered whitespace artifact in `src':"
        quietly gen long _srcline = _n
        quietly keep if regexm(_probe, "`_pat1'") | regexm(_probe, "`_pat2'")
        * `in 1/10' on a shorter dataset is r(198), which would abort the
        * caller's capture block and report the DETECTION as a checker failure.
        quietly keep in 1/`=min(10, _N)'
        list _srcline v1, noobs
    }
    clear
    return scalar nbad = `_nbad'
    return scalar nlines = `_nlines'
end

* -----------------------------------------------------------------------------
**# 1. Every shipped .sthlp renders with no literal markup
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    local helps : dir "`pkg_dir'" files "*.sthlp"
    local nhelp : word count `helps'
    display as text "  shipped help files found: `nhelp'"
    * A globbing failure would leave this at 0 and the loop would assert nothing.
    assert `nhelp' >= 4

    * Render output goes to Stata's temp directory, never into qa/: a rendered
    * .txt left behind by an aborted run is clutter, and an injected .sthlp left
    * behind (test 2) would be picked up by the `dir' glob above on the NEXT
    * run and fail a clean tree.
    tempfile rout
    local total_bad = 0
    foreach h of local helps {
        _fg_render_check, src("`pkg_dir'/`h'") out("`rout'")
        display as text "  `h': " r(nlines) " rendered lines, " ///
            r(nbad) " with literal markup"
        * A help file that renders to almost nothing did not render at all.
        assert !missing(r(nlines))
        assert r(nlines) > 100
        local total_bad = `total_bad' + r(nbad)
    }
    assert `total_bad' == 0
}
if _rc == 0 {
    display as result "  PASS: RENDER-1 all shipped .sthlp render clean"
    local ++pass_count
}
else {
    display as error "  FAIL: RENDER-1 literal markup in rendered help (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 2. FAULT INJECTION: the checker must flag a split directive
* -----------------------------------------------------------------------------
* This is the half that makes test 1 mean something.  The injected defect is the
* real one: a directive broken across a source newline, which every source-level
* grep in this package passes.
local ++test_count
capture noisily {
    tempname fh
    tempfile injanchor
    local broken "`injanchor'_injected.sthlp"
    file open `fh' using "`broken'", write text replace
    file write `fh' "{smcl}" _n
    file write `fh' "{* injected fault: do not ship}{...}" _n
    file write `fh' "{title:Injected}" _n _n
    file write `fh' "{pstd}" _n
    file write `fh' "A directive split across a source newline: {cmd:" _n
    file write `fh' "finegray} is what the Viewer shows literally." _n
    file write `fh' "{p_end}" _n
    file close `fh'

    tempfile injout
    _fg_render_check, src("`broken'") out("`injout'")
    display as text "  injected file: " r(nbad) " literal-markup line(s) (must be > 0)"
    assert !missing(r(nbad))
    assert r(nbad) > 0
    capture erase "`broken'"
}
if _rc == 0 {
    display as result "  PASS: RENDER-2 checker fires on an injected split directive"
    local ++pass_count
}
else {
    display as error "  FAIL: RENDER-2 checker cannot detect a broken directive (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 3. No shipped .sthlp renders a whitespace artifact
* -----------------------------------------------------------------------------
* The invariant, over every shipped file, replacing the two literal strings in
* one file that test_finegray_v120b.do V120B-16 used to pin.
local ++test_count
capture noisily {
    local helps : dir "`pkg_dir'" files "*.sthlp"
    local nhelp : word count `helps'
    assert `nhelp' >= 4

    tempfile wsout
    local ws_bad = 0
    foreach h of local helps {
        _fg_render_ws, src("`pkg_dir'/`h'") out("`wsout'")
        display as text "  `h': " r(nlines) " rendered lines, " ///
            r(nbad) " with a whitespace artifact"
        assert !missing(r(nlines))
        assert r(nlines) > 100
        local ws_bad = `ws_bad' + r(nbad)
    }
    assert `ws_bad' == 0
}
if _rc == 0 {
    display as result "  PASS: RENDER-3 no rendered whitespace artifacts"
    local ++pass_count
}
else {
    display as error "  FAIL: RENDER-3 rendered whitespace artifact (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 4. FAULT INJECTION: the whitespace checker must flag both artifact kinds
* -----------------------------------------------------------------------------
* Same reason as test 2: "0 artifacts" is indistinguishable from a checker that
* cannot fire.  Both defect shapes are injected, and the suspended-hyphen line is
* injected too -- it must NOT be counted, or the checker would be unusable on
* correct English and would be switched off the first time it cried wolf.
local ++test_count
capture noisily {
    tempname wfh
    tempfile wsanchor
    local wsbroken "`wsanchor'_wsinjected.sthlp"
    file open `wfh' using "`wsbroken'", write text replace
    file write `wfh' "{smcl}" _n
    file write `wfh' "{* injected fault: do not ship}{...}" _n
    file write `wfh' "{title:Injected}" _n _n
    * Defect 1: a hyphenated compound split across a source newline.
    file write `wfh' "{pstd}" _n
    file write `wfh' "It treats the estimated inverse-probability-of-" _n
    file write `wfh' "censoring weights as fixed and says so here." _n
    file write `wfh' "{p_end}" _n _n
    * Defect 2: a line break immediately after sentence-ending punctuation.
    file write `wfh' "{pstd}" _n
    file write `wfh' "A default run is as self-describing as an explicit one." _n
    file write `wfh' "The graph note is a default that yours replaces." _n
    file write `wfh' "{p_end}" _n _n
    * Correct English that renders identically to defect 1 and must NOT count.
    file write `wfh' "{pstd}" _n
    file write `wfh' "Compute a subject- or cluster-bootstrap confidence band" _n
    file write `wfh' "for the curve, and a subject- and cluster-level total." _n
    file write `wfh' "{p_end}" _n
    file close `wfh'

    tempfile wsinjout
    _fg_render_ws, src("`wsbroken'") out("`wsinjout'")
    display as text "  injected file: " r(nbad) " whitespace artifact(s) (must be exactly 2)"
    * Exactly 2: one per real defect, and none from the suspended hyphens.
    assert r(nbad) == 2
    capture erase "`wsbroken'"
}
if _rc == 0 {
    display as result "  PASS: RENDER-4 checker fires on both artifact kinds, not on suspended hyphens"
    local ++pass_count
}
else {
    display as error "  FAIL: RENDER-4 whitespace checker miscounts injected faults (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_sthlp_render tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _rend
    exit 1
}
display as result "ALL TESTS PASSED"
log close _rend
