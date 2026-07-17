clear all
version 16.1

* This suite only inspects package files on disk; it never invokes rangematch,
* so an installed copy cannot shadow it. It still bootstraps, for one reason:
* the bare `capture ado uninstall rangematch' that used to stand here ran
* against the caller's REAL tree "to keep every QA file uniform", which meant
* the quick lane ended by uninstalling the user's own rangematch (RM-I17).
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}

mata:
// Return every version DECLARATION in a .do file, space-separated.
//
// Deliberately NOT a substring search. A file that must name the forbidden
// text in order to reject it -- this one -- matches its own source, and so
// does any suite whose comments discuss a version. Anchor on the line instead:
// strip leading whitespace and require the line to BEGIN with the keyword.
// Comments start with * and are therefore invisible to it, which is the point.
//
// (Mata comments are // and /* */ -- a * comment here is not a comment, it is
// a syntax error that kills the whole mata block with r(3000) at a line that
// looks unrelated.)
string scalar _qa_version_decls(string scalar path)
{
    real scalar fh
    string scalar line, trimmed, found

    fh = fopen(path, "r")
    found = ""
    while ((line = fget(fh)) != J(0, 0, "")) {
        trimmed = strtrim(line)
        if (substr(trimmed, 1, 8) == "version ") {
            found = found + " " + strtrim(substr(trimmed, 9, .))
        }
    }
    fclose(fh)
    return(strtrim(found))
}

// Return the space-separated list of files a .pkg declares via `f ' lines.
// Used to compare the manifest as a SET: a presence-only check passes when the
// manifest has grown a file nobody meant to ship.
string scalar _qa_pkg_files(string scalar path)
{
    real scalar fh
    string scalar line, trimmed, files

    fh = fopen(path, "r")
    files = ""
    while ((line = fget(fh)) != J(0, 0, "")) {
        trimmed = strtrim(line)
        if (substr(trimmed, 1, 2) == "f ") {
            files = files + " " + strtrim(substr(trimmed, 3, .))
        }
    }
    fclose(fh)
    return(strtrim(files))
}

// Count lines whose trimmed form EXACTLY equals the needle.
// `_qa_file_contains' answers "does this text appear anywhere", which is why a
// stale syntax block could hide behind an accurate option table (RM-I18/I22).
real scalar _qa_exact_line_count(string scalar path, string scalar needle)
{
    real scalar fh, n
    string scalar line

    fh = fopen(path, "r")
    n = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strtrim(line) == needle) n = n + 1
    }
    fclose(fh)
    return(n)
}

real scalar _qa_file_contains(string scalar path, string scalar needle)
{
    real scalar fh, found
    string scalar line

    fh = fopen(path, "r")
    found = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, needle) > 0) found = 1
    }
    fclose(fh)
    return(found)
}
end

local test_count = 0

**# Required package files
local ++test_count
foreach f in rangematch.ado _rangematch_mata.ado rangematch.sthlp ///
    rangematch.pkg stata.toc README.md bench_rangematch.do {
    confirm file "`pkg_dir'/`f'"
}
display as result "PASS: required package files exist"

**# Version and author synchronization
local ++test_count

* Parse the source-of-truth version from rangematch.ado's banner line.
* Form: "*! rangematch Version X.Y.Z  YYYY/MM/DD"
tempname fh
file open `fh' using "`pkg_dir'/rangematch.ado", read
file read `fh' line
file close `fh'
local pos = strpos("`line'", "Version ")
if `pos' == 0 {
    display as error "could not parse Version from rangematch.ado banner: `line'"
    exit 9
}
local rest = substr("`line'", `pos' + 8, .)
gettoken pkg_version : rest
display as text "Parsed package version: `pkg_version'"

* Each file stamps the same version with a slightly different prefix.
local path "`pkg_dir'/rangematch.ado"
local needle "Version `pkg_version'"
mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
assert scalar(__found) == 1

local path "`pkg_dir'/_rangematch_mata.ado"
local needle "Version `pkg_version'"
mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
assert scalar(__found) == 1

local path "`pkg_dir'/rangematch.sthlp"
local needle "version `pkg_version'"
mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
assert scalar(__found) == 1

local path "`pkg_dir'/README.md"
local needle "Version `pkg_version'"
mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
assert scalar(__found) == 1

local needle "Timothy P Copeland, Karolinska Institutet"
foreach f in rangematch.ado _rangematch_mata.ado rangematch.pkg ///
    stata.toc rangematch.sthlp {
    local path "`pkg_dir'/`f'"
    mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
    assert scalar(__found) == 1
}
display as result "PASS: versions and author strings synchronized at `pkg_version'"

**# .pkg manifest and canonical stata.toc
local ++test_count
local path "`pkg_dir'/rangematch.pkg"
foreach needle in "f rangematch.ado" "f _rangematch_mata.ado" ///
    "f rangematch.sthlp" "f bench_rangematch.do" {
    mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
    assert scalar(__found) == 1
}

local path "`pkg_dir'/stata.toc"
foreach needle in "v 3" "d Stata-Tools: rangematch" ///
    "d Timothy P Copeland, Karolinska Institutet" ///
    "d https://github.com/tpcopeland/Stata-Tools" "p rangematch" {
    mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
    assert scalar(__found) == 1
}
display as result "PASS: package manifest and stata.toc"

**# Exact version/date surface, derived from one source of truth (RM-I22)
* The checks above ask "does this text appear somewhere in the file". That is
* too weak to gate a release: it cannot see a Distribution-Date that never got
* bumped, a help-file date that drifted from the .ado banner, or a top-level
* badge still advertising the previous version -- all of which live in a
* DIFFERENT file from the one being edited and so drift silently.
*
* Everything below is derived from the rangematch.ado banner and compared
* EXACTLY. Nothing here is hardcoded, so a future bump does not have to
* remember this file.
local ++test_count

* Banner form: "*! rangematch Version X.Y.Z  YYYY/MM/DD"
local dpos = strpos("`line'", "Version ")
local drest = substr("`line'", `dpos' + 8, .)
gettoken v_tok d_tok : drest
local raw_date = strtrim("`d_tok'")
local d = date("`raw_date'", "YMD")
if missing(`d') {
    display as error "could not parse the banner date from rangematch.ado: [`raw_date']"
    exit 9
}
* The three date dialects the release surface uses, all from that one date.
local help_date = lower(string(`d', "%tdDDmonCCYY"))
local pkg_date  = subinstr("`raw_date'", "/", "", .)
local badge_date = subinstr(string(`d', "%tdCCYY-NN-DD"), "-", "--", .)
display as text "release surface: version=`pkg_version' pkg=`pkg_date' help=`help_date' badge=`badge_date'"

* .pkg Distribution-Date
local path "`pkg_dir'/rangematch.pkg"
local needle "d Distribution-Date: `pkg_date'"
mata: st_numscalar("__n", _qa_exact_line_count(st_local("path"), st_local("needle")))
if scalar(__n) != 1 {
    display as error "rangematch.pkg has no exact line [`needle'] (found `=scalar(__n)')"
    exit 9
}

* Flagship .sthlp version line: version AND date together.
*
* The needle is SMCL, so it CANNOT be echoed through `display' -- the braces are
* markup and the Viewer/console swallows them, which is how the first draft of
* this check reported the useless message "has no exact line [] (found 0)".
* Describe the expectation in plain text instead.
local path "`pkg_dir'/rangematch.sthlp"
local needle "{* *! version `pkg_version'  `help_date'}{...}"
mata: st_numscalar("__n", _qa_exact_line_count(st_local("path"), st_local("needle")))
if scalar(__n) != 1 {
    display as error "rangematch.sthlp lacks its exact version line (found `=scalar(__n)' matches)"
    display as error "expected the flagship help version comment to read: version `pkg_version'  `help_date'"
    display as error "both the version and the date must match the rangematch.ado banner"
    exit 9
}

* Package README header line.
local path "`pkg_dir'/README.md"
local needle "Version `pkg_version', `help_date'"
mata: st_numscalar("__n", _qa_exact_line_count(st_local("path"), st_local("needle")))
if scalar(__n) != 1 {
    display as error "README.md has no exact line [`needle'] (found `=scalar(__n)')"
    exit 9
}
display as result "PASS: version and date exact across .ado, .pkg, .sthlp, README"

**# .pkg manifest compared as a SET, not by presence (RM-I22)
* A presence check cannot fail on a manifest that gained a file. Compare both
* directions: nothing missing, nothing extra.
local ++test_count
local expected_manifest "rangematch.ado _rangematch_mata.ado rangematch.sthlp bench_rangematch.do"
local path "`pkg_dir'/rangematch.pkg"
mata: st_local("actual_manifest", _qa_pkg_files(st_local("path")))
foreach f of local expected_manifest {
    if !`: list f in actual_manifest' {
        display as error "rangematch.pkg is missing `f'"
        exit 9
    }
}
foreach f of local actual_manifest {
    if !`: list f in expected_manifest' {
        display as error "rangematch.pkg ships an unexpected file: `f'"
        display as error "every shipped file must be a deliberate release decision"
        exit 9
    }
}
* Every manifest entry must actually exist on disk. `net install' silently
* SKIPS files it cannot place and still returns rc=0, so a manifest naming a
* file that is not there installs "successfully" and delivers nothing.
foreach f of local actual_manifest {
    confirm file "`pkg_dir'/`f'"
}
display as result "PASS: .pkg manifest matches the expected set exactly (`: word count `actual_manifest'' files)"

**# Top-level Stata-Tools README badges (RM-I22)
* These live one directory up, in a different file from everything else the
* release touches, which is exactly why they drift. Checked when the package is
* being tested inside the repo; a package tested outside it has no repo README
* to check, and that is reported rather than passed over in silence.
local ++test_count
local repo_readme "`pkg_dir'/../README.md"
capture confirm file "`repo_readme'"
if _rc {
    display as text "NOTE: no repo-level README.md above `pkg_dir'; top-level badge check not applicable here"
}
else {
    local vbadge "version-`pkg_version'-blue"
    local dbadge "updated-`badge_date'-brightgreen"
    foreach b in "`vbadge'" "`dbadge'" {
        mata: st_numscalar("__found", _qa_file_contains(st_local("repo_readme"), st_local("b")))
        if scalar(__found) != 1 {
            display as error "top-level README.md does not carry the badge [`b']"
            display as error "the package tables in the repo README are part of the release surface"
            exit 9
        }
    }
    display as result "PASS: top-level README badges match (`vbadge', `dbadge')"
}

**# README option and stored-result surface
local ++test_count
local path "`pkg_dir'/README.md"
foreach needle in "ties(all|first|last|random)" "seed(#)" ///
    "N_using_missing" "N_using_inverted" "r(overlap)" "r(seed)" ///
    "Pair-generation backend selected" {
    mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
    assert scalar(__found) == 1
}
display as result "PASS: README option and stored-result surface"

**# No forbidden release paths in shipped text
local ++test_count
local needle_home "/hom"
local needle_home "`needle_home'e/"
local needle_stata "~/"
local needle_stata "`needle_stata'Stata-"
local needle_claude ".claude"
local needle_claude "`needle_claude'/skills"
local needle_codex ".codex"
local needle_codex "`needle_codex'/skills"
local needle_dev "Stata"
local needle_dev "`needle_dev'-Dev"
local needle_examples "_examples"
local needle_examples "`needle_examples'/"
* demo/workflow.md and demo/benchmark.md are regenerated logdoc artifacts, not
* committed (removed in commit e6168bb, "remove stale demo outputs"). Scan only
* the committed shipped/doc files, and scan any demo .md only if present so a
* freshly regenerated demo output is still checked without being mandatory.
foreach f in rangematch.ado _rangematch_mata.ado rangematch.sthlp ///
    rangematch.pkg stata.toc README.md bench_rangematch.do ///
    demo/demo_rangematch.do {
    confirm file "`pkg_dir'/`f'"
    local path "`pkg_dir'/`f'"
    foreach needle in "`needle_home'" "`needle_stata'" "`needle_claude'" ///
        "`needle_codex'" "`needle_dev'" "`needle_examples'" {
        mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
        assert scalar(__found) == 0
    }
}
foreach f in demo/workflow.md demo/benchmark.md {
    capture confirm file "`pkg_dir'/`f'"
    if !_rc {
        local path "`pkg_dir'/`f'"
        foreach needle in "`needle_home'" "`needle_stata'" "`needle_claude'" ///
            "`needle_codex'" "`needle_dev'" "`needle_examples'" {
            mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
            assert scalar(__found) == 0
        }
    }
}
display as result "PASS: no forbidden release paths"

**# Auxiliary .do files honor the package's Stata version floor
* The package advertises Stata 16.1+; the shipped benchmark and the demo must
* not pin a language level above it, or a 16.1 user gets r(9) before the file
* runs. Assert each declares `version 16.1' and none pins `version 17/18/19'.
* Guards the fix that lowered both from `version 17.0'.
local ++test_count
foreach f in bench_rangematch.do demo/demo_rangematch.do {
    local path "`pkg_dir'/`f'"
    confirm file "`path'"
    local needle "version 16.1"
    mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
    assert scalar(__found) == 1
    foreach bad in "version 17" "version 18" "version 19" {
        local needle "`bad'"
        mata: st_numscalar("__found", _qa_file_contains(st_local("path"), st_local("needle")))
        assert scalar(__found) == 0
    }
}
display as result "PASS: auxiliary .do files honor the 16.1 version floor"

**# The QA lane itself honors the 16.1 floor (RM-I16)
* The package advertises Stata 16.1, but the gate that is supposed to establish
* that contract used to run at `version 17.0' in 22 of its suites, with 6 more
* declaring nothing at all and floating to whatever the host binary defaults to.
* A suite interpreted at 17 can use 17-only syntax and pass, so the lane could
* not have detected the package breaking its own floor. Pin every suite, and
* keep it pinned: this check is what stops the next new suite from drifting.
*
* This bounds the SYNTAX INTERPRETER only. It is not equivalent to running on a
* real 16.1 binary, because `version 16.1' does not remove post-16.1 functions
* from a 17 executable -- see the limitation noted in
* test_rangematch_v16compat.do. A real 16.1 lane remains outstanding.
local ++test_count
local qa_files : dir "`qa_dir'" files "*.do"
local n_qa = 0
local bad_ver ""
foreach f of local qa_files {
    local ++n_qa
    local path "`qa_dir'/`f'"
    mata: st_local("decls", _qa_version_decls(st_local("path")))
    if `"`decls'"' == "" {
        local bad_ver "`bad_ver' `f'(none)"
        continue
    }
    * Every declaration in the file must be the floor -- not just the first.
    foreach d of local decls {
        if "`d'" != "16.1" local bad_ver "`bad_ver' `f'(`d')"
    }
}
* Guard against the screen passing because it found no files to check.
assert `n_qa' >= 40
if `"`bad_ver'"' != "" {
    display as error "QA suites not pinned to the 16.1 floor:`bad_ver'"
    exit 9
}
display as result "PASS: all `n_qa' QA suites pinned to the 16.1 floor"

capture mata: mata drop _qa_file_contains()
capture scalar drop __found

display as result "ALL RANGEMATCH RELEASE INTEGRITY TESTS PASSED"
display "RESULT: test_release_integrity tests=`test_count' pass=`test_count' fail=0"
