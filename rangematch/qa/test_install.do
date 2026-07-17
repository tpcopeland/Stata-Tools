* test_install.do — Verify net install and basic usage
*
* This suite's subject IS installation, so unlike its siblings it exercises a
* bare `net install' (no replace) against an empty tree. The bootstrap gives it
* a sandboxed PLUS/PERSONAL to do that in; the uninstall below therefore
* removes the SANDBOX copy, never the caller's own (RM-I17).

version 16.1
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local qa_dir  "`r(qa_dir)'"

* The bootstrap already installed; clear the sandbox so the bare form below is
* tested against an empty tree rather than failing r(602) on a stale copy.
capture ado uninstall rangematch
net install rangematch, from("`pkg_dir'")
which rangematch
which _rangematch_mata
help rangematch

* Quick smoke test after install
clear
input int id double(lo hi)
1 1 5
2 10 20
end
tempfile master
save `master'

clear
input int uid double keyval
1 3
2 15
3 25
end
tempfile using
save `using'

use `master', clear
rangematch keyval lo hi using `using'

assert _N == 2
assert r(N_pairs) == 2
assert r(N_unmatched) == 0
mata: st_local("rm_mata_version", _rm_mata_version())

* Parse the source-of-truth version from rangematch.ado's banner so this
* assertion does not go stale on every package bump.
tempname fh
file open `fh' using "`pkg_dir'/rangematch.ado", read
file read `fh' line
file close `fh'
local pos = strpos(`"`line'"', "Version ")
assert `pos' > 0
local rest = substr(`"`line'"', `pos' + 8, .)
gettoken expected_version : rest
assert "`rm_mata_version'" == "`expected_version'"
list

* Prove `net install' really delivered every file rangematch.pkg lists, rather
* than trusting rc=0. `net install' silently SKIPS files whose extension it
* does not recognize and still returns rc=0, so an incomplete install is not a
* failure it reports -- it has to be asserted (measured behaviour, not theory).
foreach f in rangematch.ado _rangematch_mata.ado rangematch.sthlp {
    capture findfile `f'
    if _rc {
        display as error "net install did not deliver `f'"
        exit 601
    }
}

* This suite deliberately leaves the sandbox copy installed: run_all.do's
* teardown restores the caller's real PLUS/PERSONAL, and the sandbox tree is a
* throwaway under c(tmpdir).
*
* Do NOT reintroduce the uninstall sweep that used to live here. It ran against
* the caller's REAL tree, so simply running the documented gate uninstalled the
* user's own rangematch. Its fallback also parsed `ado dir' for an index and
* called `ado uninstall [<n>]', which does not work at all: measured on
* stata-mp 17 the index form returns r(111) "package not found" even for a
* single freshly installed package whose index `ado dir' printed one line
* earlier. The loop was therefore destructive when it worked and inert when it
* did not.
* Terminal sentinel (RM-I20). Five logical tests: the bare `net install'
* succeeds; the public command resolves; the Mata helper resolves; the smoke
* join returns the known pair count; the backend version matches the .ado
* banner. Assert-driven, so its absence is the failure signal.
display "RESULT: test_install tests=5 pass=5 fail=0"
display as result "INSTALL TEST PASSED"
