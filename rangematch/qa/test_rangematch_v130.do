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


**# distance(), generated labels, and parsed-option returns
local ++TESTS

tempfile using_dist
clear
input int uid double event_date str4 tag
1  8 "pre"
2 10 "zero"
3 13 "post"
end
save "`using_dist'", replace

clear
input int id double(event_date lo hi)
1 10 8 13
2 20 19 21
end

rangematch event_date lo hi using "`using_dist'", ///
    keepusing(uid tag) generate(status) distance(delta) ///
    unmatched(master) stats verbose

assert r(N_pairs) == 4
assert r(N_unmatched_master) == 1
assert r(N_empty_groups) == 0
assert r(N_master_groups) == 1
assert "`r(using_source)'" == "file"
assert "`r(key)'" == "event_date"
assert "`r(low)'" == "lo"
assert "`r(high)'" == "hi"
assert "`r(keepusing)'" == "uid tag"
assert "`r(unmatched)'" == "master"
assert "`r(closed)'" == "both"
assert "`r(ties)'" == "all"
assert "`r(generate)'" == "status"
assert "`r(distance)'" == "delta"
assert "`r(verbose)'" == "verbose"

sort id uid
assert delta[1] == -2
assert delta[2] == 0
assert delta[3] == 3
assert missing(delta[4])

decode status, gen(status_text)
assert status_text[1] == "matched"
assert status_text[4] == "master only"

**# assert() failures use side-specific counters
local ++TESTS

tempfile using_assert
clear
input int uid double event_date
1 8
2 30
end
save "`using_assert'", replace

clear
input int id double(event_date lo hi)
1 10 8 13
end

rangematch event_date lo hi using "`using_assert'", ///
    keepusing(uid) unmatched(none) assert(match) stats
assert r(N_pairs) == 1
assert r(N_unmatched_using) == 1

clear
input int id double(event_date lo hi)
1 10 8 13
end
capture noisily rangematch event_date lo hi using "`using_assert'", ///
    keepusing(uid) unmatched(none) assert(using)
assert _rc == 9
assert _N == 1

clear
input int id double(event_date lo hi)
1 99 90 100
end
capture noisily rangematch event_date lo hi using "`using_assert'", ///
    keepusing(uid) unmatched(master) assert(match)
assert _rc == 9
assert _N == 1

**# using frame input preserves source and current frames
local ++TESTS

capture frame drop events_frame
capture frame drop frame_matches
frame create events_frame
frame events_frame {
    clear
    input int uid byte group double event_date str3 code
    1 1 10 "a"
    2 1 12 "b"
    3 2 50 "c"
    end
}

clear
input int id byte group double(event_date lo hi) byte sentinel
1 1 11 9 12 42
2 2 40 39 41 43
end

rangematch event_date lo hi using events_frame, ///
    by(group) keepusing(uid code) frame(frame_matches) replace ///
    generate(status) distance(delta)

assert _N == 2
assert sentinel[1] == 42
assert sentinel[2] == 43
assert "`r(using_source)'" == "frame"
assert "`r(by)'" == "group"
assert "`r(distance)'" == "delta"

frame events_frame: assert _N == 3
frame events_frame: capture confirm variable __rm_gid
assert _rc != 0

frame frame_matches {
    assert _N == 3
    sort id uid
    assert id[1] == 1 & uid[1] == 1 & delta[1] == -1
    assert id[2] == 1 & uid[2] == 2 & delta[2] == 1
    assert id[3] == 2 & missing(uid[3]) & missing(delta[3])
    decode status, gen(status_text)
    assert status_text[1] == "matched"
    assert status_text[3] == "master only"
}

capture frame drop events_frame
capture frame drop frame_matches

**# Empty by-group diagnostics
local ++TESTS

tempfile using_groups
clear
input int uid byte group double event_date
1 1 10
end
save "`using_groups'", replace

clear
input int id byte group double(event_date lo hi)
1 1 10 9 11
2 2 10 9 11
3 3 10 9 11
end

rangematch event_date lo hi using "`using_groups'", by(group) ///
    keepusing(uid) count stats
assert r(N_master_groups) == 3
assert r(N_empty_groups) == 2
assert r(N_pairs) == 3

**# Large-join progress path
local ++TESTS

tempfile using_progress
clear
input int uid double event_date
1 50
end
save "`using_progress'", replace

clear
set obs 100001
gen long id = _n
gen double event_date = 50
gen double lo = 49
gen double hi = 51

rangematch event_date lo hi using "`using_progress'", ///
    keepusing(uid) unmatched(none) count verbose
assert r(N_master) == 100001
assert r(N_pairs) == 100001

display as result "ALL RANGEMATCH V1.3.0 TESTS PASSED"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: test_rangematch_v130 tests=`TESTS' pass=`TESTS' fail=0"
