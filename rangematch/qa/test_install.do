* test_install.do — Verify net install and basic usage

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

* Uninstall any installed rangematch packages. ado uninstall by name fails
* with rc=111 if multiple copies are present, so capture log output and
* uninstall by index until none remain. This guards against prior sessions
* that installed from different paths.
forvalues _i = 1/20 {
    capture noisily ado uninstall rangematch
    if _rc == 0 continue, break
    if _rc != 111 continue, break
    * Multiple matches: parse ado dir output for an index, uninstall by index.
    tempname tmplog
    quietly log using "`tmplog'.smcl", replace name(_rm_install_log)
    ado dir rangematch
    quietly log close _rm_install_log
    tempname fh
    file open `fh' using "`tmplog'.smcl", read
    local idx ""
    file read `fh' aline
    while r(eof) == 0 {
        if regexm(`"`aline'"', "^\[([0-9]+)\] package rangematch") {
            local idx = regexs(1)
            continue, break
        }
        file read `fh' aline
    }
    file close `fh'
    erase "`tmplog'.smcl"
    if "`idx'" == "" continue, break
    ado uninstall [`idx']
}
display as result "INSTALL TEST PASSED"
