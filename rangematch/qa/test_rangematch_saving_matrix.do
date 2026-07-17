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


tempfile using_save saved_file saved_frame

clear
input int uid byte group double keyval int value
1 1 1 101
2 1 2 102
3 2 20 203
end
save "`using_save'", replace

**# saving() with by(), keepusing(), missing(drop), and file input
local ++TESTS

clear
input int id byte group double(keyval lo hi)
1 1 2 1 2
2 1 5 . 5
3 2 20 10 30
end

rangematch keyval lo hi using "`using_save'", ///
    by(group) keepusing(uid value) missing(drop) unmatched(both) ///
    generate(_merge) saving("`saved_file'", replace) stats

assert `"`r(saving)'"' == `"`saved_file'"'
assert r(N_missing_bounds) == 1
assert r(N_master) == 2
assert r(N_pairs) == 3
assert r(N_matched_pairs) == 3
assert r(N_unmatched) == 0
assert r(N_matched_using) == 3
confirm file "`saved_file'"

preserve
use "`saved_file'", clear
assert _N == 3
quietly describe, varlist short
local saved_vars `r(varlist)'
assert "`saved_vars'" == "id group keyval lo hi uid value _merge"
sort id uid
assert id[1] == 1 & uid[1] == 1 & _merge[1] == 3
assert id[2] == 1 & uid[2] == 2 & _merge[2] == 3
assert id[3] == 3 & uid[3] == 3 & _merge[3] == 3
restore

**# saving() with using-frame input
local ++TESTS

capture frame drop saving_using_frame
frame create saving_using_frame
frame saving_using_frame {
    input int uid byte group double keyval int value
    10 1 1 501
    11 1 2 502
    12 2 20 603
    end
}

clear
input int id byte group double(keyval lo hi)
1 1 2 1 2
3 2 20 10 30
end

rangematch keyval lo hi using saving_using_frame, ///
    by(group) keepusing(uid value) unmatched(none) ///
    saving("`saved_frame'", replace)

assert "`r(using_source)'" == "frame"
assert `"`r(saving)'"' == `"`saved_frame'"'
confirm file "`saved_frame'"
preserve
use "`saved_frame'", clear
assert _N == 3
assert uid[1] == 10
assert uid[2] == 11
assert uid[3] == 12
restore
capture frame drop saving_using_frame

**# saving() rejects dryrun/count and missing(error) keeps failure cleanup local
local ++TESTS

clear
input int id byte group double(keyval lo hi)
1 1 2 1 2
end

capture noisily rangematch keyval lo hi using "`using_save'", ///
    by(group) saving("`saved_file'", replace) dryrun
assert _rc == 198

capture noisily rangematch keyval lo hi using "`using_save'", ///
    by(group) saving("`saved_file'", replace) count
assert _rc == 198

clear
input int id byte group double(keyval lo hi)
1 1 2 . 2
end

capture noisily rangematch keyval lo hi using "`using_save'", ///
    by(group) keepusing(uid value) missing(error) ///
    saving("`saved_file'", replace)
assert _rc == 459
assert _N == 1

display as result "ALL RANGEMATCH SAVING MATRIX TESTS PASSED"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: rangematch_saving_matrix tests=`TESTS' pass=`TESTS' fail=0"
