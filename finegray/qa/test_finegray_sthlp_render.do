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
* Every checker here is paired with a FAULT INJECTION: the suite feeds it a
* deliberately broken .sthlp and asserts it flags it.  Without that, "0
* literal-markup lines" is indistinguishable from a checker that cannot fire --
* the exact shape qa/README.md records for the determinism test.
*
* Tests 5 and 6 cover a third axis, added with the finegray_methods split: a
* {help finegray_methods##marker} deep link whose target marker does not exist.
* That resolves as markup, renders as ordinary text, and silently opens the
* Viewer at the top of the file instead of the section.

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

* -----------------------------------------------------------------------------
**# 5. Every {help finegray_methods##marker} target exists as a {marker}
* -----------------------------------------------------------------------------
* One-way check, and deliberately so: it asserts that every deep link INTO
* finegray_methods.sthlp lands somewhere.  A marker in that file that nothing
* links to is not a defect (a reader can still jump to it from the file's own
* {viewerjumpto} list), so the reverse direction is not asserted.
*
* A dangling ##marker is invisible to every other axis in this package: the
* source greps see the words, RENDER-1 sees resolved markup, and the Viewer
* silently opens the file at the top instead of the section.  finegray.sthlp
* shipped exactly that defect before the methods split -- four help files
* linked to `finegray##nuisance', which no {marker nuisance} ever defined.
*
* Extraction splits on a char(2) sentinel rather than looping regexm/regexs,
* because a single source line can carry more than one reference and regexs()
* only ever exposes the first.  bindquote(nobind) is required: these files are
* full of lines that OPEN a quotation and close it on the next line, and the
* default binding would swallow the following lines -- a {marker} among them --
* into one field.

capture program drop _fg_help_targets
program define _fg_help_targets, rclass
    version 16.0
    syntax , SRC(string) TARGET(string)

    quietly import delimited using "`src'", delimiter(`"`=char(1)'"') ///
        varnames(nonames) stringcols(_all) bindquote(nobind) clear
    quietly gen strL _w = subinstr(v1, "`target'##", char(2), .)
    quietly keep if strpos(_w, char(2)) > 0
    if _N == 0 {
        clear
        return local names ""
        exit
    }
    quietly split _w, parse(`"`=char(2)'"') gen(_pc)
    local names ""
    unab pcs : _pc*
    foreach v of local pcs {
        * _pc1 is the text BEFORE the first reference, never a target name.
        if "`v'" == "_pc1" continue
        quietly replace `v' = regexr(`v', "[^a-zA-Z_].*$", "")
        levelsof `v' if `v' != "", local(these) clean
        foreach t of local these {
            local names : list names | t
        }
    }
    clear
    return local names "`names'"
end

capture program drop _fg_file_markers
program define _fg_file_markers, rclass
    version 16.0
    syntax , SRC(string)

    quietly import delimited using "`src'", delimiter(`"`=char(1)'"') ///
        varnames(nonames) stringcols(_all) bindquote(nobind) clear
    quietly keep if regexm(v1, "^\{marker [a-zA-Z_]+\}")
    local names ""
    if _N > 0 {
        quietly gen strL _m = regexr(regexr(v1, "^\{marker ", ""), "\}.*$", "")
        levelsof _m, local(these) clean
        foreach t of local these {
            local names : list names | t
        }
    }
    clear
    return local names "`names'"
end

local ++test_count
capture noisily {
    local mfile "`pkg_dir'/finegray_methods.sthlp"
    confirm file "`mfile'"

    _fg_file_markers, src("`mfile'")
    local have "`r(names)'"
    local nhave : word count `have'
    display as text "  finegray_methods.sthlp defines `nhave' marker(s)"
    * A parsing failure would leave this empty and the loop would assert nothing.
    assert `nhave' >= 10

    local helps : dir "`pkg_dir'" files "*.sthlp"
    local nhelp : word count `helps'
    assert `nhelp' >= 5

    local missing ""
    local nref = 0
    foreach h of local helps {
        _fg_help_targets, src("`pkg_dir'/`h'") target("finegray_methods")
        local want "`r(names)'"
        local nwant : word count `want'
        local nref = `nref' + `nwant'
        display as text "  `h': `nwant' distinct finegray_methods##marker target(s)"
        local gap : list want - have
        if "`gap'" != "" {
            display as error "  `h' links to undefined marker(s): `gap'"
            local missing : list missing | gap
        }
    }
    * The split is only useful if the other files actually deep-link into it.
    assert `nref' >= 15
    assert "`missing'" == ""
}
if _rc == 0 {
    display as result "  PASS: RENDER-5 every finegray_methods##marker target is defined"
    local ++pass_count
}
else {
    display as error "  FAIL: RENDER-5 dangling finegray_methods##marker target (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 6. FAULT INJECTION: the marker checker must flag a dangling target
* -----------------------------------------------------------------------------
* Same reason as tests 2 and 4: "0 dangling targets" is indistinguishable from
* an extractor that returns nothing.  Both halves are injected -- a reference
* that resolves and one that does not -- so a checker that simply reported
* everything as missing would fail here too.
local ++test_count
capture noisily {
    tempname mfh
    tempfile injmanchor
    local mbroken "`injmanchor'_markerinjected.sthlp"
    file open `mfh' using "`mbroken'", write text replace
    file write `mfh' "{smcl}" _n
    file write `mfh' "{* injected fault: do not ship}{...}" _n
    file write `mfh' "{title:Injected}" _n _n
    file write `mfh' "{pstd}" _n
    * Two references on ONE line: the loop-free extractor must return both.
    file write `mfh' "See {help finegray_methods##variance:Variance} and also" _n
    file write `mfh' "{help finegray_methods##fg_no_such_marker:nowhere}." _n
    file write `mfh' "{p_end}" _n
    file close `mfh'

    _fg_help_targets, src("`mbroken'") target("finegray_methods")
    local injwant "`r(names)'"
    display as text "  injected file references: `injwant'"

    _fg_file_markers, src("`pkg_dir'/finegray_methods.sthlp")
    local have "`r(names)'"

    * The real target must resolve; the invented one must not.
    local injgap : list injwant - have
    assert "`injgap'" == "fg_no_such_marker"
    local resolved : list injwant & have
    assert "`resolved'" == "variance"
    capture erase "`mbroken'"
}
if _rc == 0 {
    display as result "  PASS: RENDER-6 marker checker fires on a dangling target only"
    local ++pass_count
}
else {
    display as error "  FAIL: RENDER-6 marker checker miscounts injected targets (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 7. No {synopt} description overflows its {synoptset} column
* -----------------------------------------------------------------------------
* The THIRD render axis, and the one tests 1 and 3 are blind to.  A {synopt}
* description resolves its markup perfectly and carries no whitespace artifact,
* and still prints wrong when it is too long: the Viewer wraps it onto a second
* line under the label column, which reads as a new table row.  Stata's own
* help files hold the description to (71 - N) characters, N being the governing
* {synoptset N tabbed}.
*
* Found on 2026-08-29 in finegray.sthlp: three Scalars rows -- e(N) at 53,
* e(N_fail) at 71 and e(N_compete) at 63 against a 51-character column -- had
* grown an "(weighted total under {cmd:fweight}s)" clause with the pweight
* work.  Tests 1 and 3 were green over all three, as was every source-text
* suite in the package.
*
* Asserted as an invariant over every shipped file rather than as three pinned
* strings, for the reason recorded at test 3: the pinned form is what let the
* identical defect recur in a second file.  A source-side rule is the right
* shape here because the wrap is a deterministic function of the source
* lengths, and the package's QA may not depend on _devkit tooling.
capture program drop _fg_synopt_width
program define _fg_synopt_width, rclass
    version 16.0
    syntax , SRC(string)

    tempname fh
    local nbad = 0
    local nrow = 0
    * Stata's default when a table opens without its own {synoptset}.
    local width = 20
    local lineno = 0

    file open `fh' using "`src'", read text
    file read `fh' line
    while r(eof) == 0 {
        local ++lineno
        if regexm(`"`macval(line)'"', "\{synoptset +([0-9]+)") ///
            local width = real(regexs(1))

        if regexm(`"`macval(line)'"', "^\{synopt:") {
            local ++nrow
            * Resolve markup the way the Viewer does: {tag:text} shows text,
            * a bare {tag} shows nothing.  Loop: regexr replaces one match.
            * The colon form must go FIRST: the bare pattern would otherwise
            * swallow {help a:b} and lose the text it renders.
            *
            * The label is peeled AFTER resolving, not before.  Its form varies
            * -- {synopt:{cmd:e(N)}}, {synopt:{opt tvc(varlist)}}, a bare
            * {synopt:name} -- and a prefix regex per form is how the stray `}'
            * that closes {synopt: survives into the description and inflates
            * every row by one, which reads as an overflow on a row sitting
            * exactly at the cap.  Instead: drop the opening {synopt:, resolve
            * everything, and split at the one unmatched `}' that is left.
            local _d `"`macval(line)'"'
            local _d = regexr(`"`macval(_d)'"', "^\{synopt:", "")
            local _guard = 0
            while regexm(`"`macval(_d)'"', "\{[a-zA-Z_][^:{}]*:([^{}]*)\}") & `_guard' < 40 {
                local ++_guard
                local _d = regexr(`"`macval(_d)'"', "\{[a-zA-Z_][^:{}]*:([^{}]*)\}", "`=regexs(1)'")
            }
            local _guard = 0
            while regexm(`"`macval(_d)'"', "\{[^{}]*\}") & `_guard' < 40 {
                local ++_guard
                local _d = regexr(`"`macval(_d)'"', "\{[^{}]*\}", "")
            }
            * Everything after the first surviving `}' is the description.
            local _brk = strpos(`"`macval(_d)'"', "}")
            if `_brk' > 0 ///
                local _d = substr(`"`macval(_d)'"', `_brk' + 1, .)
            local _len = length(`"`macval(_d)'"')
            local _cap = 71 - `width'
            if `_len' > `_cap' {
                local ++nbad
                if `nbad' <= 10 {
                    display as error "    line `lineno': `_len' > `_cap' chars: " ///
                        `"`macval(_d)'"'
                }
            }
        }
        file read `fh' line
    }
    file close `fh'

    return scalar nbad = `nbad'
    return scalar nrow = `nrow'
end

local ++test_count
capture noisily {
    local helps : dir "`pkg_dir'" files "*.sthlp"
    local nhelp : word count `helps'
    assert `nhelp' >= 4
    local total_bad = 0
    local total_row = 0
    foreach h of local helps {
        _fg_synopt_width, src("`pkg_dir'/`h'")
        display as text "  `h': " r(nrow) " {synopt} rows, " ///
            r(nbad) " overflowing"
        local total_bad = `total_bad' + r(nbad)
        local total_row = `total_row' + r(nrow)
    }
    * A checker that found no rows at all cannot have found an overflow.
    assert `total_row' > 50
    assert `total_bad' == 0
}
if _rc == 0 {
    display as result "  PASS: RENDER-7 no {synopt} description overflows its column"
    local ++pass_count
}
else {
    display as error "  FAIL: RENDER-7 {synopt} column overflow (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 8. FAULT INJECTION: the width checker must flag an over-wide description
* -----------------------------------------------------------------------------
* Same contract as tests 2, 4 and 6: "0 overflowing" must be a measurement, not
* a checker that cannot fire.  The injected file carries one row one character
* over the cap and one row exactly at it, so the boundary is pinned in both
* directions, plus a row whose length is only reached after markup resolves --
* the case a naive length(line) would miscount.
local ++test_count
capture noisily {
    tempname wfh
    tempfile injwidth
    local wbroken "`injwidth'_widthinjected.sthlp"
    file open `wfh' using "`wbroken'", write text replace
    file write `wfh' "{smcl}" _n
    file write `wfh' "{* injected fault: do not ship}{...}" _n
    file write `wfh' "{synoptset 20 tabbed}{...}" _n
    * cap is 71 - 20 = 51.
    file write `wfh' "{synopt:{cmd:e(ok)}}123456789012345678901234567890123456789012345678901{p_end}" _n
    file write `wfh' "{synopt:{cmd:e(bad)}}1234567890123456789012345678901234567890123456789012{p_end}" _n
    * 46 plain characters plus markup that resolves to 6 more = 52, over by one.
    file write `wfh' "{synopt:{cmd:e(mk)}}1234567890123456789012345678901234567890123456 {cmd:fweight}{p_end}" _n
    file close `wfh'

    _fg_synopt_width, src("`wbroken'")
    display as text "  injected: " r(nrow) " rows, " r(nbad) " flagged"
    assert r(nrow) == 3
    * the 51-character row must NOT be flagged; the other two must be
    assert r(nbad) == 2
    capture erase "`wbroken'"
}
if _rc == 0 {
    display as result "  PASS: RENDER-8 width checker fires on the over-wide rows only"
    local ++pass_count
}
else {
    display as error "  FAIL: RENDER-8 width checker miscounts injected rows (rc=`=_rc')"
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
