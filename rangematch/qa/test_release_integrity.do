clear all
version 16.1

* This suite only inspects package files on disk; it never invokes rangematch,
* so an installed copy cannot shadow it. Uninstall anyway to keep every QA file
* uniform and leave no installed build behind for later suites.
capture ado uninstall rangematch

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

capture mata: mata drop _qa_file_contains()
capture scalar drop __found

display as result "ALL RANGEMATCH RELEASE INTEGRITY TESTS PASSED"
display "RESULT: test_release_integrity tests=`test_count' pass=`test_count' fail=0"
