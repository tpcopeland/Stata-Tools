quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1

local TESTS 0
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

capture program drop _rm_assert_log_lacks
program define _rm_assert_log_lacks
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
    assert `found' == 0
end

capture program drop _rm_assert_value_edge
program define _rm_assert_value_edge
    * Every row starting with LABEL (as printed, indent included) must end at
    * column EDGE, and at least one such row must exist.
    syntax anything(name=logfile id="log file") , LABEL(string) EDGE(integer)
    tempname fh
    local logfile : subinstr local logfile `"""' "", all
    local seen = 0
    local bad = 0
    local lablen = strlen(`"`label'"')
    file open `fh' using `"`logfile'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if substr(`"`line'"', 1, `lablen') == `"`label'"' {
            local ++seen
            if strlen(strrtrim(`"`line'"')) != `edge' local bad = 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `seen' > 0
    assert `bad' == 0
end

tempfile using_display normal_log dryrun_log count_log frame_log save_log save_out1 save_out2 style_log inv_using by_log by_using

clear
set obs 101
gen int uid = _n
gen double keyval = _n
save "`using_display'", replace

**# Normal, stats, verbose, timing, and warning labels
local ++TESTS

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
local ++TESTS

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
_rm_assert_value_edge "`dryrun_log'", label("    Materialize") edge(55)
_rm_assert_value_edge "`dryrun_log'", label("    Load") edge(55)

capture log close _rm_display_log
quietly log using "`count_log'", replace text name(_rm_display_log)
rangematch keyval lo hi using "`using_display'", ///
    keepusing(uid) count
quietly log close _rm_display_log

_rm_assert_log_has "`count_log'", needle("Dry run result")
_rm_assert_log_has "`count_log'", needle("(data unchanged)")

**# Output destination labels
local ++TESTS

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
_rm_assert_value_edge "`frame_log'", label("    Output frame") edge(55)
_rm_assert_value_edge "`frame_log'", label("    Total output") edge(55)
capture frame drop display_contract_out

**# saving() reports the file once, without Stata's save chatter
* The output file is named on the "Output file" row. The underlying save must
* not also print "(file ... not found)" for a replace target that does not
* exist yet, nor "file ... saved", on either the replace or the new-file path.
local ++TESTS

clear
input int id double(keyval lo hi)
1 50 1 101
end

capture log close _rm_display_log
quietly log using "`save_log'", replace text name(_rm_display_log)
rangematch keyval lo hi using "`using_display'", ///
    keepusing(uid) saving("`save_out1'", replace)
rangematch keyval lo hi using "`using_display'", ///
    keepusing(uid) saving("`save_out2'")
quietly log close _rm_display_log

_rm_assert_log_has "`save_log'", needle("Output file")
_rm_assert_log_lacks "`save_log'", needle(" saved")
_rm_assert_log_lacks "`save_log'", needle("not found)")
confirm file "`save_out1'"
confirm file "`save_out2'"
_rm_assert_value_edge "`save_log'", label("    Output file") edge(55)

* A path too wide to end at column 55 starts two spaces after its label.
local long_out "`c(tmpdir)'/rm_display_contract_long_output_name_`=floor(runiform()*1e6)'.dta"
local long_out : subinstr local long_out "//" "/", all
capture erase "`long_out'"
capture log close _rm_display_log
quietly log using "`save_log'", replace text name(_rm_display_log)
rangematch keyval lo hi using "`using_display'", ///
    keepusing(uid) saving("`long_out'")
quietly log close _rm_display_log
_rm_assert_log_has "`save_log'", needle("    Output file  `long_out'")
capture erase "`long_out'"

**# Status-line style: indented verbose rows, separated counts, no " -- "
* Status and warning lines share one style: verbose rows use the table layout
* (four-space indent, thousands separators), warning counts carry thousands
* separators, and clauses are joined with "; " rather than " -- ".
local ++TESTS

clear
set obs 1500
gen long uid = _n
gen double ulo = 10
gen double uhi = 5
save "`inv_using'", replace

clear
set obs 1500
gen long id = _n
gen double mlo = 1
gen double mhi = 20

capture log close _rm_display_log
quietly log using "`style_log'", replace text name(_rm_display_log)
rangematch mlo mhi using "`inv_using'", overlap(ulo uhi) ///
    keepusing(uid) dryrun verbose
quietly log close _rm_display_log

_rm_assert_log_has "`style_log'", needle("    Master observations")
_rm_assert_log_has "`style_log'", needle("1,500")
_rm_assert_log_has "`style_log'", needle("warning: 1,500 using interval(s)")
_rm_assert_log_has "`style_log'", needle("match nothing; validate")
_rm_assert_log_lacks "`style_log'", needle(" -- ")
_rm_assert_log_lacks "`style_log'", needle("Master observations: ")
_rm_assert_value_edge "`style_log'", label("    Master observations") edge(55)
_rm_assert_value_edge "`style_log'", label("    Using observations") edge(55)
_rm_assert_value_edge "`style_log'", label("    By-groups") edge(55)

* With by(), the text value is wider than a count yet must end on the same
* column 55 as the counts.
clear
input long patient_id double key long uid
1 5 1
2 7 2
end
save "`by_using'", replace

clear
input long patient_id double(lo hi)
1 1 10
2 1 10
end

capture log close _rm_display_log
quietly log using "`by_log'", replace text name(_rm_display_log)
rangematch key lo hi using "`by_using'", by(patient_id) ///
    keepusing(uid) dryrun verbose
quietly log close _rm_display_log

_rm_assert_log_has "`by_log'", needle("yes (patient_id)")
_rm_assert_value_edge "`by_log'", label("    Master observations") edge(55)
_rm_assert_value_edge "`by_log'", label("    Using observations") edge(55)
_rm_assert_value_edge "`by_log'", label("    By-groups") edge(55)

display as result "ALL RANGEMATCH DISPLAY CONTRACT TESTS PASSED"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: test_rangematch_display_contract tests=`TESTS' pass=`TESTS' fail=0"
