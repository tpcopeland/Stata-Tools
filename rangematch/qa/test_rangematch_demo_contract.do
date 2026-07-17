*! test_rangematch_demo_contract.do
*! Regression suite for the Phase-4 demo-hygiene finding (RM-I15).
*!
*! The demo redirects sysdir PLUS to install the package under test, but it
*! restored PLUS only on its normal tail: any earlier failure left the caller's
*! PLUS pointing into a temporary directory and the demo's logs open. It also
*! left PERSONAL alone, and PERSONAL precedes PLUS on the adopath -- so a stale
*! PERSONAL copy could shadow the local install and the demo would benchmark
*! the wrong code while reporting it as the local one.
*!
*! This suite runs the real demo script with a stale PERSONAL copy seeded ahead
*! of it and a forced mid-demo error, then checks what the session looks like
*! afterwards. It runs the demo in-process (`do'), because sysdir state is
*! per-process and a batch child could not show restoration.

clear all
set varabbrev off
version 16.1

* No `log using' here by design -- see test_rangematch_doc_contract.do. This
* suite has an extra wrinkle: the demo's cleanup runs `log close _all', which
* closes whatever log is open around this file (the runner's, or batch mode's).
* The outer log is therefore recorded below and reopened after the demo.

* Relocatable bootstrap.
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

capture confirm file "`pkg_dir'/demo/demo_rangematch.do"
if _rc {
    display as error "demo/demo_rangematch.do not found under `pkg_dir'"
    exit 601
}

**# Build an isolated repository-shaped scratch copy
* The demo derives its paths from the current directory, so the scratch tree
* must keep the <repo>/rangematch/demo layout.
* Process-unique: an unseeded runiformint() repeats byte-for-byte each run
* (fixed default RNG seed) and would reuse the previous run's scratch tree.
tempfile _tok_probe
mata: st_local("tag", subinstr(pathbasename(st_local("_tok_probe")), ".", "_"))
local scratch "`c(tmpdir)'/rm_demo_qa_`tag'"
local stale "`c(tmpdir)'/rm_demo_stale_`tag'"
capture mkdir "`scratch'"
capture mkdir "`scratch'/rangematch"
capture mkdir "`scratch'/rangematch/demo"
capture mkdir "`stale'"

copy "`pkg_dir'/rangematch.ado"          "`scratch'/rangematch/rangematch.ado", replace
copy "`pkg_dir'/_rangematch_mata.ado"    "`scratch'/rangematch/_rangematch_mata.ado", replace
copy "`pkg_dir'/rangematch.sthlp"        "`scratch'/rangematch/rangematch.sthlp", replace
copy "`pkg_dir'/rangematch.pkg"          "`scratch'/rangematch/rangematch.pkg", replace
copy "`pkg_dir'/stata.toc"               "`scratch'/rangematch/stata.toc", replace
copy "`pkg_dir'/bench_rangematch.do"     "`scratch'/rangematch/bench_rangematch.do", replace

**# Copy the demo, forcing an error immediately after its resolution check
* Injecting the failure early keeps the suite fast (the demo's own benchmarks
* run to 1M rows) and puts the error exactly where the old script would have
* skipped its cleanup.
tempname in out
local injected = 0
file open `in'  using "`pkg_dir'/demo/demo_rangematch.do", read text
file open `out' using "`scratch'/rangematch/demo/demo_rangematch.do", write replace text
file read `in' line
while r(eof) == 0 {
    file write `out' `"`macval(line)'"' _n
    if strpos(`"`macval(line)'"', "not the demo install under") {
        * next two lines are `exit 459' and the closing brace; emit them, then fail
        file read `in' line
        file write `out' `"`macval(line)'"' _n
        file read `in' line
        file write `out' `"`macval(line)'"' _n
        file write `out' "error 9" _n
        local injected = 1
    }
    file read `in' line
}
file close `in'
file close `out'

if !`injected' {
    display as error "failure injection anchor not found in demo_rangematch.do"
    display as error "the demo would run to completion and this suite would prove nothing"
    exit 459
}

**# Seed a stale PERSONAL copy that must not win
* A decoy that errors if it is ever the resolved copy.
tempname decoy
file open `decoy' using "`stale'/rangematch.ado", write replace text
file write `decoy' "*! decoy rangematch -- stale PERSONAL copy planted by QA" _n
file write `decoy' "program define rangematch" _n
file write `decoy' "    display as error " _char(34) "STALE PERSONAL COPY RAN" _char(34) _n
file write `decoy' "    exit 459" _n
file write `decoy' "end" _n
file close `decoy'

**# Record pre-demo state on disk
* The demo runs `clear all', which drops every local in this file. Anything the
* assertions need afterwards has to survive outside the macro space.
local statefile "`c(tmpdir)'/rm_demo_state_`tag'.txt"
sysdir set PERSONAL "`stale'"
local expect_plus "`c(sysdir_plus)'"
local expect_personal "`c(sysdir_personal)'"

tempname sf
file open `sf' using "`statefile'", write replace text
file write `sf' `"`expect_plus'"' _n
file write `sf' `"`expect_personal'"' _n
file write `sf' `"`scratch'"' _n
file write `sf' `"`stale'"' _n
file write `sf' `"`pkg_dir'"' _n
file close `sf'

**# Run the demo, expecting the injected failure
* Hand the demo an unpolluted adopath.
*
* This used to be load-bearing: ten sibling suites ran `adopath ++ "<pkg_dir>"'
* and never removed it, so under run_all.do the source directory sat ahead of
* the demo's sandbox, rangematch.ado resolved there, and the demo correctly
* refused to claim it had run its own install (rc=459) -- a true verdict about
* a polluted session, but not the contract under test here. That pollution was
* the visible symptom of RM-I17 and is now fixed at the source: no suite
* appends to the adopath, and run_all.do strips this entry between suites.
*
* Kept as a defensive strip, because this suite must be runnable standalone in
* a session whose adopath nobody controls. `had_pkg_on_path' is expected to be
* 0 under the lane.
local had_pkg_on_path = 0
forvalues i = 1/20 {
    capture adopath - "`pkg_dir'"
    if _rc continue, break
    local had_pkg_on_path = 1
}
* Survives the demo's `clear all' via the statefile, like everything else the
* post-demo assertions need.
file open `sf' using "`statefile'", write append text
file write `sf' `"`had_pkg_on_path'"' _n
file close `sf'

* Record the enclosing log so it can be reopened after the demo closes _all.
capture log query
local outer_log `"`r(filename)'"'
local outer_type `"`r(type)'"'
if `"`outer_type'"' == "" local outer_type "text"

local keep_pwd "`c(pwd)'"
cd "`scratch'"
capture noisily do "`scratch'/rangematch/demo/demo_rangematch.do"
local demo_rc = _rc
cd "`keep_pwd'"

* Sample the demo's log state BEFORE touching any log. The reopen below has to
* close _all first, which would itself close whatever the demo left open and
* manufacture a pass for T5.
capture log query workflow
local workflow_open = (_rc == 0)
capture log query benchmark
local benchmark_open = (_rc == 0)

* The demo's cleanup closed every open log, including the one wrapping this
* file. Reopen it (append) so the assertions below are still recorded and the
* suites that run after this one keep logging.
capture log close _all
if `"`outer_log'"' != "" {
    capture log using `"`outer_log'"', append `outer_type' nomsg
}

* Re-read what `clear all' destroyed.
tempname sf2
file open `sf2' using "`statefile'", read text
file read `sf2' expect_plus
file read `sf2' expect_personal
file read `sf2' scratch
file read `sf2' stale
file read `sf2' pkg_dir
file read `sf2' had_pkg_on_path
file close `sf2'
erase "`statefile'"

* Put the lane's adopath entry back for the suites that follow.
if `had_pkg_on_path' adopath ++ "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0

**# T1: the injected failure propagates as a nonzero rc
* rc=9 also proves the resolution check passed: had the stale PERSONAL copy
* shadowed the local install, the demo would have exited 459 before reaching
* the injected error.
local ++test_count
if `demo_rc' == 9 {
    local ++pass_count
    display as result "PASS: demo propagated the injected failure (rc=9) and resolved its own install"
}
else if `demo_rc' == 459 {
    local ++fail_count
    display as error "FAIL: demo resolved the stale PERSONAL copy instead of its own install (rc=459)"
}
else if `demo_rc' == 0 {
    local ++fail_count
    display as error "FAIL: demo swallowed a mid-demo error and exited 0"
}
else {
    local ++fail_count
    display as error "FAIL: demo exited rc=`demo_rc'; expected the injected rc=9"
}

**# T2: sysdir PLUS is restored after the failure
local ++test_count
if `"`c(sysdir_plus)'"' == `"`expect_plus'"' {
    local ++pass_count
    display as result "PASS: sysdir PLUS restored after a failed demo"
}
else {
    local ++fail_count
    display as error "FAIL: PLUS left at `c(sysdir_plus)'; expected `expect_plus'"
}

**# T3: sysdir PERSONAL is restored after the failure
local ++test_count
if `"`c(sysdir_personal)'"' == `"`expect_personal'"' {
    local ++pass_count
    display as result "PASS: sysdir PERSONAL restored after a failed demo"
}
else {
    local ++fail_count
    display as error "FAIL: PERSONAL left at `c(sysdir_personal)'; expected `expect_personal'"
}

**# T4: neither sysdir is left pointing into a temporary sandbox
* Independent of the exact expected values above: a restored sysdir must not
* still be inside the demo's throwaway tree.
local ++test_count
if strpos(`"`c(sysdir_plus)'"', "rm_demo_plus_") | strpos(`"`c(sysdir_personal)'"', "rm_demo_personal_") {
    local ++fail_count
    display as error "FAIL: a sysdir is still redirected into the demo sandbox"
}
else {
    local ++pass_count
    display as result "PASS: no sysdir left inside the demo sandbox"
}

**# T5: the demo's logs are closed
* `log query <name>' exits 111 when no such log is open.
local ++test_count
if `workflow_open' | `benchmark_open' {
    local ++fail_count
    display as error "FAIL: demo left a log open (workflow=`workflow_open' benchmark=`benchmark_open')"
    capture log close workflow
    capture log close benchmark
}
else {
    local ++pass_count
    display as result "PASS: demo closed its logs on the failure path"
}

**# Cleanup
sysdir set PERSONAL "`expect_personal'"
capture erase "`stale'/rangematch.ado"
capture rmdir "`stale'"

**# Summary
display as text "tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "RESULT: rangematch_demo_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
