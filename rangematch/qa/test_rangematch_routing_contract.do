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


capture program drop _rm_assert_no_internal_frames
program define _rm_assert_no_internal_frames
    foreach f in __rm_master __rm_using __rm_uwork __rm_out __rm_grp __rm_grp_u {
        capture frame `f': describe
        assert _rc != 0
    }
end

tempfile using_route saved_route

clear
input int uid byte group double keyval str3 tag
1 1 1 "a"
2 1 2 "b"
3 2 20 "c"
4 3 99 "z"
end
save "`using_route'", replace

**# Current-data replacement restores the caller frame
local ++TESTS

clear
input int id byte group double(keyval lo hi)
1 1 2 1 2
2 2 20 19 21
end
local start_frame "`c(frame)'"

rangematch keyval lo hi using "`using_route'", ///
    by(group) keepusing(uid tag) unmatched(none)

assert "`c(frame)'" == "`start_frame'"
assert _N == 3
quietly describe, varlist short
assert "`r(varlist)'" == "id group keyval lo hi uid tag"
sort id uid
assert id[1] == 1 & uid[1] == 1
assert id[2] == 1 & uid[2] == 2
assert id[3] == 2 & uid[3] == 3
_rm_assert_no_internal_frames

**# frame() output leaves current data unchanged
local ++TESTS

capture frame drop routing_contract_out
clear
input int id byte group double(keyval lo hi) byte sentinel
1 1 2 1 2 42
2 2 20 19 21 43
end
local start_frame "`c(frame)'"

rangematch keyval lo hi using "`using_route'", ///
    by(group) keepusing(uid tag) unmatched(none) ///
    frame(routing_contract_out) replace

assert "`c(frame)'" == "`start_frame'"
assert _N == 2
assert sentinel[1] == 42
frame routing_contract_out: assert _N == 3
frame routing_contract_out {
    quietly describe, varlist short
    local routing_vars `r(varlist)'
}
assert "`routing_vars'" == "id group keyval lo hi sentinel uid tag"
_rm_assert_no_internal_frames
capture frame drop routing_contract_out

**# saving() output leaves current data unchanged
local ++TESTS

clear
input int id byte group double(keyval lo hi) byte sentinel
1 1 2 1 2 42
2 2 20 19 21 43
end
local start_frame "`c(frame)'"

rangematch keyval lo hi using "`using_route'", ///
    by(group) keepusing(uid tag) unmatched(none) ///
    saving("`saved_route'", replace)

assert "`c(frame)'" == "`start_frame'"
assert _N == 2
assert sentinel[2] == 43
assert `"`r(saving)'"' == `"`saved_route'"'
confirm file "`saved_route'"
preserve
use "`saved_route'", clear
assert _N == 3
quietly describe, varlist short
assert "`r(varlist)'" == "id group keyval lo hi sentinel uid tag"
restore
_rm_assert_no_internal_frames

**# dryrun/count do not create output frames or mutate data
local ++TESTS

capture frame drop routing_contract_out
clear
input int id byte group double(keyval lo hi) byte sentinel
1 1 2 1 2 42
2 2 20 19 21 43
end

rangematch keyval lo hi using "`using_route'", ///
    by(group) keepusing(uid tag) unmatched(none) ///
    dryrun frame(routing_contract_out)

assert _N == 2
assert sentinel[1] == 42
assert "`r(frame)'" == ""
assert "`r(saving)'" == ""
capture frame routing_contract_out: describe
assert _rc != 0
_rm_assert_no_internal_frames

rangematch keyval lo hi using "`using_route'", ///
    by(group) keepusing(uid tag) unmatched(none) ///
    count frame(routing_contract_out)

assert _N == 2
assert sentinel[2] == 43
assert "`r(frame)'" == ""
assert "`r(saving)'" == ""
capture frame routing_contract_out: describe
assert _rc != 0
_rm_assert_no_internal_frames

**# using-frame routing and error cleanup
local ++TESTS

capture frame drop route_using_frame
frame create route_using_frame
frame route_using_frame {
    input int uid byte group double keyval str3 tag
    10 1 1 "f1"
    11 1 2 "f2"
    12 2 20 "f3"
    end
}

clear
input int id byte group double(keyval lo hi)
1 1 2 1 2
2 2 20 19 21
end

rangematch keyval lo hi using route_using_frame, ///
    by(group) keepusing(uid tag) unmatched(none)

assert "`r(using_source)'" == "frame"
assert _N == 3
assert uid[1] == 10
_rm_assert_no_internal_frames

clear
input int id byte group double(keyval lo hi)
1 1 50 40 60
end
local start_frame "`c(frame)'"

capture noisily rangematch keyval lo hi using route_using_frame, ///
    by(group) keepusing(uid tag) unmatched(none) assert(match)
assert _rc == 9
assert "`c(frame)'" == "`start_frame'"
assert _N == 1
_rm_assert_no_internal_frames
capture frame drop route_using_frame

display as result "ALL RANGEMATCH ROUTING CONTRACT TESTS PASSED"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: test_rangematch_routing_contract tests=`TESTS' pass=`TESTS' fail=0"
