clear all
version 16.1
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
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

local test_count = 0

**# README quick start
local ++test_count
capture frame drop matches
clear
input str1 site int id double event_date
"A" 1 21915
"B" 2 21946
end
format event_date %td
tempfile master events
save `master'

clear
input str1 site int eid double event_date
"A" 101 21890
"A" 102 21920
"B" 103 21950
"B" 104 21990
end
format event_date %td
save `events'

use `master', clear
rangematch event_date -30 30 using `events', frame(matches) replace stats
assert _N == 2
assert "`r(frame)'" == "matches"
assert r(N_pairs) == 4
frame matches {
    assert _N == 4
    sort id eid
    assert id[1] == 1 & eid[1] == 101
    assert id[2] == 1 & eid[2] == 102
    assert id[3] == 2 & eid[3] == 102
    assert id[4] == 2 & eid[4] == 103
}
display as result "PASS: README quick start"

**# Help-file continuation examples using the same temporary files
local ++test_count
use `master', clear
generate double lo = event_date - 14
generate double hi = event_date + 14
rangematch event_date lo hi using `events', closed(left) unmatched(none)
assert r(N_pairs) == 2
sort id eid
assert id[1] == 1 & eid[1] == 102
assert id[2] == 2 & eid[2] == 103

use `master', clear
rangematch event_date . 30 using `events', count
assert _N == 2
assert r(N_pairs) == 5
display as result "PASS: help-file scalar/count examples"

**# README worked exposure-window example
local ++test_count
capture frame drop exposure_events
clear
input int patient_id str10 start_string byte exposure_days
101 "2020-01-15" 30
101 "2020-03-01" 14
102 "2020-02-10" 21
end
generate double exposure_start = daily(start_string, "YMD")
generate double exposure_end = exposure_start + exposure_days
format exposure_start exposure_end %td
drop start_string exposure_days
tempfile exposures adverse_events
save `exposures'

clear
input int patient_id str10 event_string str18 event_type
101 "2020-01-20" "rash"
101 "2020-02-20" "headache"
101 "2020-03-10" "nausea"
102 "2020-02-15" "dizziness"
102 "2020-03-20" "fatigue"
end
generate double event_date = daily(event_string, "YMD")
format event_date %td
drop event_string
save `adverse_events'

use `exposures', clear
rangematch event_date exposure_start exposure_end using `adverse_events', ///
    by(patient_id) keepusing(event_date event_type) ///
    generate(_merge) frame(exposure_events) replace stats
assert _N == 3
assert r(N_pairs) == 3
assert r(N_unmatched) == 0
frame exposure_events {
    assert _N == 3
    sort patient_id event_date
    assert patient_id[1] == 101 & event_type[1] == "rash"
    assert patient_id[2] == 101 & event_type[2] == "nausea"
    assert patient_id[3] == 102 & event_type[3] == "dizziness"
    assert _merge[1] == 3 & _merge[2] == 3 & _merge[3] == 3
}
capture frame drop exposure_events
capture frame drop matches
display as result "PASS: README worked exposure-window example"

**# README/help interval-overlap worked example
local ++test_count
capture frame drop exposed
clear
input int id str10 entry_s str10 exit_s
1 "2020-01-01" "2020-06-30"
2 "2020-02-01" "2020-08-31"
end
generate double entry = daily(entry_s, "YMD")
generate double exit  = daily(exit_s, "YMD")
format entry exit %td
drop entry_s exit_s
tempfile cohort episodes
save `cohort'

clear
input int id str10 start_s str10 stop_s str10 drug
1 "2019-12-15" "2020-01-20" "drugA"
1 "2020-03-01" "2020-03-31" "drugB"
2 "2020-09-15" "2020-10-15" "drugA"
end
generate double rx_start = daily(start_s, "YMD")
generate double rx_stop  = daily(stop_s, "YMD")
format rx_start rx_stop %td
drop start_s stop_s
save `episodes'

use `cohort', clear
rangematch entry exit using `episodes', overlap(rx_start rx_stop) ///
    by(id) keepusing(rx_start rx_stop drug) frame(exposed) replace stats
assert "`r(backend)'" == "overlap"
assert r(N_matched_pairs) == 2
assert r(N_unmatched) == 1
assert r(N_pairs) == 3
frame exposed {
    assert _N == 3
    sort id rx_start
    assert id[1] == 1 & drug[1] == "drugA"
    assert id[2] == 1 & drug[2] == "drugB"
    assert id[3] == 2 & missing(rx_start[3]) & drug[3] == ""
}
capture frame drop exposed
display as result "PASS: README/help interval-overlap worked example"

display as result "ALL RANGEMATCH DOCUMENTATION EXAMPLE TESTS PASSED"
display "RESULT: test_documentation_examples tests=`test_count' pass=`test_count' fail=0"
