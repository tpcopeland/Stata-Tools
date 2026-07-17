*! test_rangematch_lane_isolation.do
*! RM-I17 regression gate: the QA suite must not mutate the environment of the
*! person running it, and must not test a copy other than the one under review.
*!
*! WHAT WENT WRONG. Every suite used to open with a bare
*! `capture ado uninstall rangematch' against the caller's REAL PLUS tree, and
*! test_install.do closed by uninstalling again. Running the documented gate
*! therefore deleted the user's own installed rangematch -- at rc=0, with a
*! green lane, and nothing in the output to point at. Twelve suites went
*! further: they uninstalled and then never installed anything, resolving the
*! command off an `adopath ++ "<pkg_dir>"' entry instead. Those suites tested
*! the SOURCE DIRECTORY while reading as though they tested an installed
*! package, so an installed-user defect (a runtime file missing from
*! rangematch.pkg, say) could not fail them.
*!
*! HOW THIS SUITE PROVES THE FIX. It never touches the real tree either. It
*! stands up a FAKE user tree under c(tmpdir), installs rangematch into it to
*! play the part of the user's own copy, and then drives _rm_qa_bootstrap /
*! _rm_qa_teardown against it. The fake copy standing in for the user's is the
*! thing asserted to survive.
*!
*! T1 bootstrap redirects PLUS and PERSONAL away from the caller's trees
*! T2 bootstrap resolves rangematch from the sandbox, not the source dir
*! T3 the user's installed copy is untouched by a full bootstrap
*! T4 teardown restores both trees exactly
*! T5 teardown leaves the user's copy installed and resolvable

clear all
version 16.1

local test_count = 0
local pass_count = 0
local fail_count = 0

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

* Remember the caller's genuine trees. Nothing below may leave them changed.
local true_plus "`c(sysdir_plus)'"
local true_personal "`c(sysdir_personal)'"

* Process-unique fake-user trees. An unseeded runiform() is NOT unique (fixed
* default RNG seed), so derive the token from a tempfile, which carries the pid.
tempfile _iso_tok
mata: st_local("tok", subinstr(pathbasename(st_local("_iso_tok")), ".", "_"))
local user_plus "`c(tmpdir)'/rm_iso_userplus_`tok'"
local user_personal "`c(tmpdir)'/rm_iso_userpers_`tok'"
capture mkdir "`user_plus'"
capture mkdir "`user_personal'"

**# Stand up the fake user: rangematch installed in "their" PLUS tree
sysdir set PLUS "`user_plus'"
sysdir set PERSONAL "`user_personal'"
capture ado uninstall rangematch
quietly net install rangematch, from("`pkg_dir'") replace
discard
capture findfile rangematch.ado
if _rc | strpos("`r(fn)'", "`user_plus'") != 1 {
    display as error "SETUP FAILED: could not stage a fake user install under `user_plus'"
    sysdir set PLUS "`true_plus'"
    sysdir set PERSONAL "`true_personal'"
    exit 459
}
local user_copy "`r(fn)'"
display as text "staged fake user copy at `user_copy'"

* The fake user's trees are what the bootstrap must protect. From here on,
* `user_plus'/`user_personal' play the role the caller's real trees play in a
* live run.
local pre_plus "`c(sysdir_plus)'"
local pre_personal "`c(sysdir_personal)'"

**# Drive a FRESH bootstrap/teardown cycle against the fake user tree
* The sandbox is established once per session and reused, so under run_all.do
* the lane has already bootstrapped by the time this suite runs: RM_QA_ISOLATED
* is set and RM_QA_OLD_* hold the CALLER's real trees. A bootstrap call here
* would simply rejoin the lane's sandbox, and the matching teardown would
* restore the caller's trees rather than the fake ones staged above -- which is
* right for the lane and wrong for this test. (Learned the hard way: the suite
* passed standalone and failed 2/5 inside the lane for exactly this reason.)
*
* Stash the lane's isolation state and clear the flag so the bootstrap performs
* a genuine first-time save/redirect, with the fake user trees standing in for
* the caller's. Everything is put back at the end of the suite.
local lane_isolated "$RM_QA_ISOLATED"
local lane_plus "$RM_QA_PLUS"
local lane_personal "$RM_QA_PERSONAL"
local lane_old_plus "$RM_QA_OLD_PLUS"
local lane_old_personal "$RM_QA_OLD_PERSONAL"
global RM_QA_ISOLATED ""

quietly do "`qa_dir'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local sandbox_plus "`r(plus_dir)'"

**# T1 — bootstrap redirects both trees away from the caller's
local ++test_count
local ok = 1
if "`c(sysdir_plus)'" == "`pre_plus'" {
    display as error "T1 FAIL: PLUS still points at the caller's tree"
    local ok = 0
}
if "`c(sysdir_personal)'" == "`pre_personal'" {
    display as error "T1 FAIL: PERSONAL still points at the caller's tree"
    local ok = 0
}
* PERSONAL matters specifically: it PRECEDES PLUS on the adopath, so leaving it
* alone lets a stale personal copy shadow the package under test.
if `ok' {
    local ++pass_count
    display as result "PASS T1: bootstrap redirected PLUS and PERSONAL"
}
else local ++fail_count

**# T2 — the command resolves from the sandbox, not the source directory
local ++test_count
capture findfile rangematch.ado
if _rc == 0 & strpos("`r(fn)'", "`sandbox_plus'") == 1 {
    local ++pass_count
    display as result "PASS T2: rangematch resolves from the sandbox"
}
else {
    local ++fail_count
    display as error "T2 FAIL: rangematch resolved to `r(fn)' (rc=`_rc'), want a path under `sandbox_plus'"
}

**# T3 — the user's own installed copy is untouched
local ++test_count
capture confirm file "`user_copy'"
if _rc == 0 {
    local ++pass_count
    display as result "PASS T3: the user's installed copy survived the bootstrap"
}
else {
    local ++fail_count
    display as error "T3 FAIL: the bootstrap deleted the user's copy at `user_copy'"
    display as error "this is the RM-I17 defect: QA is not entitled to uninstall the caller's package"
}

**# T4 — teardown restores both trees exactly
_rm_qa_teardown
local ++test_count
local ok = 1
if "`c(sysdir_plus)'" != "`pre_plus'" {
    display as error "T4 FAIL: PLUS is `c(sysdir_plus)', want `pre_plus'"
    local ok = 0
}
if "`c(sysdir_personal)'" != "`pre_personal'" {
    display as error "T4 FAIL: PERSONAL is `c(sysdir_personal)', want `pre_personal'"
    local ok = 0
}
if `ok' {
    local ++pass_count
    display as result "PASS T4: teardown restored both trees"
}
else local ++fail_count

**# T5 — after teardown the user's copy is still installed and resolvable
local ++test_count
discard
capture findfile rangematch.ado
if _rc == 0 & strpos("`r(fn)'", "`user_plus'") == 1 {
    local ++pass_count
    display as result "PASS T5: the user's copy resolves again after teardown"
}
else {
    local ++fail_count
    display as error "T5 FAIL: after teardown rangematch resolved to `r(fn)' (rc=`_rc')"
}

**# Hand the session back exactly as it was found
* Put the lane's isolation state back, then re-point the sysdirs where the
* caller had them: at the lane's sandbox if run_all.do is driving, at the
* genuine trees if this suite was run standalone. Every step capture'd -- a
* failure here must not strand the next suite in this suite's scratch trees.
global RM_QA_ISOLATED "`lane_isolated'"
global RM_QA_PLUS "`lane_plus'"
global RM_QA_PERSONAL "`lane_personal'"
global RM_QA_OLD_PLUS "`lane_old_plus'"
global RM_QA_OLD_PERSONAL "`lane_old_personal'"

if "`lane_isolated'" != "" {
    capture sysdir set PLUS "`lane_plus'"
    capture sysdir set PERSONAL "`lane_personal'"
}
else {
    capture sysdir set PLUS "`true_plus'"
    capture sysdir set PERSONAL "`true_personal'"
}
capture discard

display "RESULT: lane_isolation tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "test_rangematch_lane_isolation: FAILED (`fail_count')"
    exit 9
}
display as result "test_rangematch_lane_isolation: PASSED"
