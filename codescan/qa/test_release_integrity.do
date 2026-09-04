* test_release_integrity.do - Release surface and package metadata checks for codescan

clear all
version 16.0
set varabbrev off

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local repo_dir "`pkg_dir'/.."

* Install the local copy so a stale installed build cannot shadow it, and so the
* release surface is checked against a package that genuinely net-installs.
* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane -- the level-80/99 CI scenarios restored inside a
* captured block, so any assertion failure above them used to leak.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"


capture program drop _assert_marker_pass
program define _assert_marker_pass
    version 16.0
    args marker

    tempname fh
    file open `fh' using `"`marker'"', read text
    file read `fh' status
    file close `fh'
    assert strtrim("`status'") == "PASS"
end

* Return the first regex capture group found in a file, or "" if the pattern
* never matches. Parsing the fact out of the file that owns it keeps this suite
* from carrying stale literals that must be hand-edited on every release.
capture program drop _cs_extract_first
program define _cs_extract_first, rclass
    version 16.0
    args path pattern

    tempname fh
    local value ""
    file open `fh' using "`path'", read text
    file read `fh' line
    while r(eof) == 0 {
        if ustrregexm(`"`macval(line)'"', "`pattern'") {
            local value = ustrregexs(1)
            continue, break
        }
        file read `fh' line
    }
    file close `fh'
    return local value "`value'"
end

* Render shipped help through Stata's own SMCL interpreter and fail closed if
* literal directives remain in the rendered log. Source-text brace checks cannot
* detect a directive split across a source newline, but this is exactly what a
* user sees in the Viewer.
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
                * Park braces on control characters before displaying the line;
                * the SMCL brace escapes contain braces of their own.
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

**# Tests

local ++test_count
capture noisily {
    confirm file "`pkg_dir'/codescan.ado"
    confirm file "`pkg_dir'/codescan.sthlp"
    confirm file "`pkg_dir'/codescan_describe.ado"
    confirm file "`pkg_dir'/codescan_describe.sthlp"
    confirm file "`pkg_dir'/codescan.pkg"
    confirm file "`pkg_dir'/stata.toc"
    confirm file "`pkg_dir'/README.md"
}
if _rc == 0 {
    display as result "  PASS: release files present"
    local ++pass_count
}
else {
    display as error "  FAIL: release files present (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempname fh
    local pkg_files ""
    file open `fh' using "`pkg_dir'/codescan.pkg", read text
    file read `fh' line
    while r(eof) == 0 {
        local trimmed = strtrim(`"`line'"')
        if substr(`"`trimmed'"', 1, 2) == "f " {
            local f = strtrim(substr(`"`trimmed'"', 3, .))
            local pkg_files "`pkg_files' `f'"
            confirm file "`pkg_dir'/`f'"
        }
        file read `fh' line
    }
    file close `fh'

    foreach f in ///
        codescan.ado ///
        _codescan_engine.ado ///
        _codescan_codefile.ado ///
        _codescan_definitions.ado ///
        _codescan_outputs.ado ///
        _codescan_parse_filespec.ado ///
        _codescan_validate_path.ado ///
        codescan.sthlp ///
        codescan_describe.ado ///
        codescan_describe.sthlp {

        assert strpos(" `pkg_files' ", " `f' ") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: .pkg lists every runtime/help file"
    local ++pass_count
}
else {
    display as error "  FAIL: .pkg runtime/help file list (error `=_rc')"
    local ++fail_count
}

* Version/date synchronization. Facts are parsed from the surfaces that own
* them and compared only against compatible facts. The previous version of this
* test hardcoded the whole version/date tuple as shell grep literals, which made
* it (a) stale on every release and (b) wrong: it required each .ado's code-edit
* date to equal the package distribution date, which are different facts about
* different events.
local ++test_count
capture noisily {
    * The flagship help file owns the package version.
    _cs_extract_first "`pkg_dir'/codescan.sthlp" "^\{\* \*! version ([0-9]+\.[0-9]+\.[0-9]+)"
    local ver "`r(value)'"
    assert "`ver'" != ""

    * Every .ado header must carry that same version. Their dates are NOT
    * compared to the distribution date.
    foreach f in codescan.ado _codescan_engine.ado codescan_describe.ado ///
        _codescan_codefile.ado _codescan_definitions.ado _codescan_outputs.ado ///
        _codescan_parse_filespec.ado _codescan_validate_path.ado {
        _cs_extract_first "`pkg_dir'/`f'" "^\*! [_a-zA-Z]+ Version ([0-9]+\.[0-9]+\.[0-9]+)"
        if "`r(value)'" != "`ver'" {
            display as error "    `f' version [`r(value)'] != flagship [`ver']"
            exit 9
        }
    }

    * Version numbers live in the flagship help only; a sub-command help file
    * must not carry one.
    _cs_extract_first "`pkg_dir'/codescan_describe.sthlp" "(\*! version)"
    assert "`r(value)'" == ""

    * README header version must match the flagship version.
    _cs_extract_first "`pkg_dir'/README.md" "^\*\*Version ([0-9]+\.[0-9]+\.[0-9]+)\*\*"
    if "`r(value)'" != "`ver'" {
        display as error "    README version [`r(value)'] != flagship [`ver']"
        exit 9
    }

    * Release-date facts: the README header date and the .pkg Distribution-Date
    * describe the same event, so they must agree with each other.
    _cs_extract_first "`pkg_dir'/README.md" "^\*\*Version [0-9.]+\*\* \| ([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])"
    local rdate "`r(value)'"
    _cs_extract_first "`pkg_dir'/codescan.pkg" "^d Distribution-Date: ([0-9]+)"
    local pdate "`r(value)'"
    assert "`rdate'" != ""
    assert "`pdate'" != ""
    if subinstr("`rdate'", "-", "", .) != "`pdate'" {
        display as error "    README date [`rdate'] != .pkg Distribution-Date [`pdate']"
        exit 9
    }
}
if _rc == 0 {
    display as result "  PASS: version strings synchronized"
    local ++pass_count
}
else {
    display as error "  FAIL: version strings synchronized (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile marker
    shell bash -lc 'cd "$1" && if grep -Fq "v 3" stata.toc && grep -Fq "d Stata-Tools: codescan" stata.toc && grep -Fq "d Timothy P Copeland, Karolinska Institutet" stata.toc && grep -Fq "d https://github.com/tpcopeland/Stata-Tools" stata.toc && grep -Fq "p codescan" stata.toc && grep -Fq "d Author: Timothy P Copeland, Karolinska Institutet" codescan.pkg && grep -Fq "Timothy P Copeland, Karolinska Institutet" README.md && grep -Fq "Timothy P Copeland, Karolinska Institutet" codescan.sthlp && grep -Fq "Timothy P Copeland, Karolinska Institutet" codescan_describe.sthlp; then echo PASS > "$2"; else echo FAIL > "$2"; fi' bash "`pkg_dir'" "`marker'"
    _assert_marker_pass "`marker'"
}
if _rc == 0 {
    display as result "  PASS: canonical metadata present"
    local ++pass_count
}
else {
    display as error "  FAIL: canonical metadata present (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile marker
    local p1 = "/home/" + "tpcopeland"
    local p2 = "~/" + "Stata-"
    local p3 = "Stata-" + "Dev"
    local p4 = "." + "claude"
    local p5 = "." + "codex"
    shell bash -lc 'cd "$1" && files=$(git ls-files codescan | grep -Ev "^codescan/demo/.*\\.(xlsx|png)$" || true); if [ -z "$files" ]; then files=$(awk "/^f /{print \"codescan/\" \$2}" codescan/codescan.pkg; printf "%s\n" codescan/codescan.pkg codescan/stata.toc codescan/README.md); files=$(printf "%s\n" "$files" | grep -Ev "^codescan/demo/.*\\.(xlsx|png)$" | sort -u); fi; if [ -n "$files" ] && printf "%s\n" "$files" | xargs rg -n -F -e "$3" -e "$4" -e "$5" -e "$6" -e "$7" > "$2.hits"; then echo FAIL > "$2"; else echo PASS > "$2"; fi' bash "`repo_dir'" "`marker'" "`p1'" "`p2'" "`p3'" "`p4'" "`p5'"
    _assert_marker_pass "`marker'"
}
if _rc == 0 {
    display as result "  PASS: tracked text has no dev-only paths"
    local ++pass_count
}
else {
    display as error "  FAIL: tracked text has dev-only paths (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile marker
    shell bash -lc 'cd "$1" && files=$(git ls-files codescan || true); if [ -z "$files" ]; then files=$(awk "/^f /{print \"codescan/\" \$2}" codescan/codescan.pkg; printf "%s\n" codescan/codescan.pkg codescan/stata.toc codescan/README.md); fi; if printf "%s\n" "$files" | grep -Ev "^codescan/demo/" | grep -E "\\.(log|smcl|dta|xlsx)$" > "$2.hits"; then echo FAIL > "$2"; else echo PASS > "$2"; fi' bash "`repo_dir'" "`marker'"
    _assert_marker_pass "`marker'"
}
if _rc == 0 {
    display as result "  PASS: no tracked generated debris outside demo allowances"
    local ++pass_count
}
else {
    display as error "  FAIL: tracked generated debris outside demo allowances (error `=_rc')"
    local ++fail_count
}

* Viewer description-column width oracle for {synopt} rows.
*
* The render check above proves no literal SMCL leaks, but a description that
* overruns the p2col description column renders perfectly as text and still
* wraps in the Viewer -- miscounting the width, mangling the trailing {p_end},
* and corrupting the rows after it. That is why a green package lane coexisted
* with two shipped help files failing the structural documentation gate. The
* column runs to source column 77 and the description starts 6 columns past the
* {synoptset N tabbed} width, so a row has 71 - N characters. This is measured
* on the RENDERED text: {cmd:x} prints one character, not eight.
capture program drop _qa_smcl_render
program define _qa_smcl_render, rclass
    version 16.0
    gettoken s 0 : 0

    * Innermost-first: take the first closing brace and the last opening brace
    * before it, so a nested {cmd:{it:x}} collapses correctly instead of being
    * cut at the inner close.
    local guard = 0
    while strpos(`"`s'"', "}") > 0 & `guard' < 500 {
        local ++guard
        local q = strpos(`"`s'"', "}")
        local head `"`=substr(`"`s'"', 1, `q' - 1)'"'
        local p = strrpos(`"`head'"', "{")
        if `p' == 0 {
            local s `"`=substr(`"`s'"', 1, `q' - 1) + substr(`"`s'"', `q' + 1, .)'"'
            continue
        }
        local inner `"`=substr(`"`s'"', `p' + 1, `q' - `p' - 1)'"'
        local mapped ""
        if ustrregexm(`"`inner'"', "^opth? ") {
            * {opt def:ine(x)} prints "define(x)": the abbreviation colon is
            * markup, both halves are printed.
            local mapped `"`=subinstr(substr(`"`inner'"', strpos(`"`inner'"', " ") + 1, .), ":", "", .)'"'
        }
        else if ustrregexm(`"`inner'"', "^c ") {
            * {c -(} and friends are single printed characters.
            local mapped "x"
        }
        else if ustrregexm(`"`inner'"', "^(helpb|help|manhelp[a-z]*) ") {
            * A link prints the label after the last colon, or the whole target.
            local _lbl `"`=substr(`"`inner'"', strpos(`"`inner'"', " ") + 1, .)'"'
            if strpos(`"`_lbl'"', ":") > 0 {
                local _lbl `"`=substr(`"`_lbl'"', strrpos(`"`_lbl'"', ":") + 1, .)'"'
            }
            local mapped `"`=subinstr(`"`_lbl'"', char(34), "", .)'"'
        }
        else if strpos(`"`inner'"', ":") > 0 {
            * {cmd:x}, {it:x}, {bf:x}, ... print the text after the tag.
            local mapped `"`=substr(`"`inner'"', strpos(`"`inner'"', ":") + 1, .)'"'
        }
        local s `"`=substr(`"`s'"', 1, `p' - 1)'`mapped'`=substr(`"`s'"', `q' + 1, .)'"'
    }
    return local text `"`s'"'
end

capture program drop _qa_synopt_width
program define _qa_synopt_width, rclass
    version 16.0
    syntax anything(name=files id="help files")

    local files = subinstr(`"`files'"', char(34), "", .)
    local nover 0
    local overfiles ""

    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
            display as error "  width: file not found: `f'"
            local ++nover
            local overfiles "`overfiles' `f'"
            continue
        }

        * Default {synoptset} width is 20 when a table declares none.
        local setw = 20
        local lineno = 0
        local fbad = 0
        tempname wfh
        file open `wfh' using "`f'", read text
        file read `wfh' line
        while r(eof) == 0 {
            local ++lineno
            if ustrregexm(`"`macval(line)'"', "\{synoptset[ ]+([0-9]+)") {
                local setw = real(ustrregexs(1))
            }
            local trimmed = strtrim(`"`macval(line)'"')
            if ustrregexm(`"`trimmed'"', "^\{synopt[ ]*:") {
                * Skip the balanced first column, then measure what is left.
                local depth = 0
                local cut = 0
                local L = strlen(`"`trimmed'"')
                forvalues ci = 1/`L' {
                    local ch = substr(`"`trimmed'"', `ci', 1)
                    if "`ch'" == "{" local ++depth
                    if "`ch'" == "}" {
                        local --depth
                        if `depth' == 0 {
                            local cut = `ci'
                            continue, break
                        }
                    }
                }
                local desc `"`=substr(`"`trimmed'"', `cut' + 1, .)'"'
                local desc `"`=subinstr(`"`desc'"', "{p_end}", "", .)'"'
                _qa_smcl_render `"`desc'"'
                local w = strlen(strtrim(`"`r(text)'"'))
                local cap = 77 - (`setw' + 6)
                if `w' > `cap' {
                    display as error "  synopt width: `f' line `lineno' (`w'>`cap')"
                    local ++fbad
                }
            }
            file read `wfh' line
        }
        file close `wfh'
        if `fbad' > 0 {
            local nover = `nover' + `fbad'
            local overfiles "`overfiles' `f'"
        }
    }

    return scalar nover = `nover'
    return local overfiles "`overfiles'"
end

* The release gate must exercise the render axis, not only source-text markup.
local ++test_count
capture noisily {
    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    local help_paths ""
    foreach s of local sthlps {
        local help_paths "`help_paths' `pkg_dir'/`s'"
    }
    _qa_sthlp_render `help_paths'
    assert r(nbad) == 0
}
if _rc == 0 {
    display as result "  PASS: shipped .sthlp files render without literal SMCL"
    local ++pass_count
}
else {
    display as error "  FAIL: shipped .sthlp render (error `=_rc')"
    local ++fail_count
}

* Positive control: prove the oracle detects a broken directive rather than
* returning zero because it never rendered the file.
local ++test_count
capture noisily {
    tempname bfh
    tempfile broken
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
    display as result "  PASS: SMCL render oracle positive control detects literal markup"
    local ++pass_count
}
else {
    display as error "  FAIL: SMCL render oracle positive control (error `=_rc')"
    local ++fail_count
}


* Viewer column width is a shipped-documentation contract, not a style rule:
* an over-wide {synopt} description wraps and corrupts the table around it.
local ++test_count
capture noisily {
    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    local width_paths ""
    foreach s of local sthlps {
        local width_paths "`width_paths' `pkg_dir'/`s'"
    }
    _qa_synopt_width `width_paths'
    assert r(nover) == 0
}
if _rc == 0 {
    display as result "  PASS: shipped .sthlp synopt descriptions fit the Viewer column"
    local ++pass_count
}
else {
    display as error "  FAIL: shipped .sthlp synopt width (error `=_rc')"
    local ++fail_count
}

* Positive control: one row one character over the cap, one row exactly at it.
* Without this the width oracle could return zero because it never measured
* anything.
local ++test_count
capture noisily {
    tempname wfh2
    tempfile widefile
    file open `wfh2' using "`widefile'", write replace text
    file write `wfh2' "{smcl}" _n
    file write `wfh2' "{synoptset 20 tabbed}{...}" _n
    file write `wfh2' "{synopt:{opt a}}" _dup(51) "x" "{p_end}" _n
    file write `wfh2' "{synopt:{opt b}}" _dup(52) "x" "{p_end}" _n
    file write `wfh2' "{synopt:{opt c}}{cmd:" _dup(51) "y" "}{p_end}" _n
    file close `wfh2'
    _qa_synopt_width `widefile'
    * cap = 77 - (20 + 6) = 51: the 51-character rows fit, the 52 does not, and
    * the {cmd:} row proves markup is not counted as printed characters.
    assert r(nover) == 1
}
if _rc == 0 {
    display as result "  PASS: synopt width oracle positive control detects an over-wide row"
    local ++pass_count
}
else {
    display as error "  FAIL: synopt width oracle positive control (error `=_rc')"
    local ++fail_count
}


**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


**# Summary

display ""
_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_release_integrity" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_release_integrity tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
