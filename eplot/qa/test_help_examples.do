*! test_help_examples.do - help-file and README examples, executed as written
*! The example commands are extracted from eplot.sthlp (every ". command" line
*! of the Examples section, in order, as a user clicking through them would
*! run them; later examples reuse earlier data and estimates) and from the
*! README's stata code blocks (each run on its own after clear all), then
*! executed.  Nothing is retyped here, so help prose cannot drift from what
*! QA runs.  README blocks that install the package or elide their data
*! ("* ..." placeholder lines) are skipped by rule, and the expected counts
*! are pinned: adding or removing an example fails this suite until the
*! counts are reviewed.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_help_examples.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap
discard

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Pinned inventory (review when the help file or README changes).
local want_sthlp 16
local want_readme_run 7
local want_readme_skip 3

mata:
// Example commands of eplot.sthlp: one do-file, each example followed by a
// line recording that it finished.  Returns the number of examples.
real scalar _hx_sthlp(string scalar fn, string scalar out)
{
    real scalar fh, oh, inside, n, p, q
    string scalar line, cmd

    fh = fopen(fn, "r")
    oh = fopen(out, "w")
    fput(oh, "set graphics off")
    inside = 0
    n = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, "{marker examples}")) inside = 1
        if (strpos(line, "{marker remarks}")) break
        if (!inside) continue
        if (strpos(line, "{bf:Example ")) {
            if (n) fput(oh, "global EPLOT_HX_DONE " + strofreal(n))
            n++
            continue
        }
        if (substr(line, 1, 8) != "{phang2}") continue
        p = strpos(line, ":. ")
        q = strpos(line, "}{p_end}")
        if (!p | q <= p) continue
        q = strlen(line) - strlen("}{p_end}")
        cmd = substr(line, p + 3, q - p - 2)
        cmd = subinstr(subinstr(cmd, "{c -(}", "{"), "{c )-}", "}")
        fput(oh, cmd)
    }
    if (n) fput(oh, "global EPLOT_HX_DONE " + strofreal(n))
    fclose(fh)
    fclose(oh)
    return(n)
}

// README stata code blocks: block i is written to stub + "_i.do" unless it
// installs the package or elides its data.  Returns (run, skipped).
real rowvector _hx_readme(string scalar fn, string scalar stub)
{
    real scalar fh, inb, run, skip, i
    real scalar oh
    string scalar line, fence
    string colvector blk

    // A literal fence would be macro-expanded in this do-file.
    fence = char(96) * 3
    fh = fopen(fn, "r")
    inb = 0
    run = 0
    skip = 0
    blk = J(0, 1, "")
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (!inb & strtrim(line) == fence + "stata") {
            inb = 1
            blk = J(0, 1, "")
            continue
        }
        if (inb & strtrim(line) == fence) {
            inb = 0
            if (sum(strpos(blk, "net install") :> 0) |
                sum(regexm(blk, "^[ ]*\* \.\.\.")) ) {
                skip++
                continue
            }
            run++
            oh = fopen(stub + "_" + strofreal(run) + ".do", "w")
            fput(oh, "set graphics off")
            for (i = 1; i <= rows(blk); i++) fput(oh, blk[i])
            fclose(oh)
            continue
        }
        if (inb) blk = blk \ line
    }
    fclose(fh)
    return((run, skip))
}
end

**# eplot.sthlp Examples section
tempfile hx
local hxdo "`hx'_sthlp.do"
mata: st_local("n_sthlp", strofreal(_hx_sthlp("`pkg_dir'/eplot.sthlp", "`hxdo'")))
* Extract the README blocks now: the examples below run clear all, which
* also clears these Mata functions.
mata: st_local("rr", invtokens(strofreal(_hx_readme("`pkg_dir'/README.md", "`hx'_readme"))))

**## 1. inventory: every example heading found
local ++test_count
capture noisily {
    assert `n_sthlp' == `want_sthlp'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "sthlp examples found: `n_sthlp', expected `want_sthlp'"
}

**## 2..: each example runs, in order
global EPLOT_HX_DONE 0
clear all
capture noisily do "`hxdo'"
local hx_rc = _rc
local done = $EPLOT_HX_DONE
capture graph drop _all
forvalues e = 1/`want_sthlp' {
    local ++test_count
    if `e' <= `done' local ++pass_count
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        if `e' == `done' + 1 display as error "sthlp example `e' failed (rc `hx_rc')"
    }
}

**# README stata code blocks
local n_readme_run : word 1 of `rr'
local n_readme_skip : word 2 of `rr'

local ++test_count
capture noisily {
    assert `n_readme_run' == `want_readme_run'
    assert `n_readme_skip' == `want_readme_skip'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
    display as error "README blocks: run `n_readme_run' (expected `want_readme_run'), skipped `n_readme_skip' (expected `want_readme_skip')"
}

forvalues b = 1/`n_readme_run' {
    local ++test_count
    clear all
    capture frame drop effects
    capture noisily {
        do "`hx'_readme_`b'.do"
        * Every runnable block ends in an eplot call (block 4 then drops its
        * frame, which leaves r() alone): its results must be posted.
        assert substr(`"`r(cmd)'"', 1, 7) == "twoway "
        assert r(k) >= 1 & r(k) < .
    }
    if _rc == 0 local ++pass_count
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `test_count'"
        display as error "README runnable block `b' failed (rc `=_rc')"
    }
    capture graph drop _all
}

macro drop EPLOT_HX_DONE
* The examples ran clear all, which dropped the QA helper programs.
quietly do "`qa_dir'/_eplot_qa_common.do"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_help_examples, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
