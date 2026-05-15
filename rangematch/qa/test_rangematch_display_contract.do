capture ado uninstall rangematch
clear all
version 17.0

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

quietly net install rangematch, from("`pkg_dir'") replace

capture program drop _rm_assert_log_has
program define _rm_assert_log_has
    syntax anything(name=logfile id="log file") , NEEDLE(string)
    tempname fh
    local logfile : subinstr local logfile `"""' "", all
    local found = 0
    file open `fh' using `"`logfile'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`needle'"') > 0 {
            local found = 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
end

tempfile using_display normal_log dryrun_log count_log frame_log

clear
set obs 101
gen int uid = _n
gen double keyval = _n
save "`using_display'", replace

**# Normal, stats, verbose, timing, and warning labels

clear
input int id double(keyval lo hi)
1 50 1 101
2 200 190 210
end

capture log close _rm_display_log
quietly log using "`normal_log'", replace text name(_rm_display_log)
rangematch keyval lo hi using "`using_display'", ///
    keepusing(uid) stats verbose
quietly log close _rm_display_log

_rm_assert_log_has "`normal_log'", needle("Result")
_rm_assert_log_has "`normal_log'", needle("Not matched")
_rm_assert_log_has "`normal_log'", needle("Matched")
_rm_assert_log_has "`normal_log'", needle("Total output")
_rm_assert_log_has "`normal_log'", needle("Match density")
_rm_assert_log_has "`normal_log'", needle("Timing")
_rm_assert_log_has "`normal_log'", needle("Master observations")
_rm_assert_log_has "`normal_log'", needle("Using observations")
_rm_assert_log_has "`normal_log'", needle("warning:")

**# dryrun/count labels

clear
input int id double(keyval lo hi)
1 50 1 101
end

capture log close _rm_display_log
quietly log using "`dryrun_log'", replace text name(_rm_display_log)
rangematch keyval lo hi using "`using_display'", ///
    keepusing(uid) dryrun stats verbose
quietly log close _rm_display_log

_rm_assert_log_has "`dryrun_log'", needle("Dry run result")
_rm_assert_log_has "`dryrun_log'", needle("(data unchanged)")
_rm_assert_log_has "`dryrun_log'", needle("Match density")
_rm_assert_log_has "`dryrun_log'", needle("Timing")

capture log close _rm_display_log
quietly log using "`count_log'", replace text name(_rm_display_log)
rangematch keyval lo hi using "`using_display'", ///
    keepusing(uid) count
quietly log close _rm_display_log

_rm_assert_log_has "`count_log'", needle("Dry run result")
_rm_assert_log_has "`count_log'", needle("(data unchanged)")

**# Output destination labels

capture frame drop display_contract_out
clear
input int id double(keyval lo hi)
1 50 1 101
end

capture log close _rm_display_log
quietly log using "`frame_log'", replace text name(_rm_display_log)
rangematch keyval lo hi using "`using_display'", ///
    keepusing(uid) frame(display_contract_out) replace
quietly log close _rm_display_log

_rm_assert_log_has "`frame_log'", needle("Output frame")
_rm_assert_log_has "`frame_log'", needle("display_contract_out")
capture frame drop display_contract_out

display as result "ALL RANGEMATCH DISPLAY CONTRACT TESTS PASSED"
