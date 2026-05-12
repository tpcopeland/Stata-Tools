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

**# keepusing() pre-validation

tempfile using_keep
clear
input int uid double keyval
1 10
end
save "`using_keep'", replace

clear
input int id double(lo hi)
1 5 15
end

capture noisily rangematch keyval lo hi using "`using_keep'", ///
    keepusing(uid missing_var)
assert _rc == 111
assert _N == 1
capture frame __rm_using: describe
assert _rc != 0

**# Date and datetime format preservation

tempfile using_dates
clear
input int uid double event_date
1 21915
end
format event_date %td
save "`using_dates'", replace

clear
input int id double(event_date date_low date_high)
1 21915 21914 21916
end
format event_date date_low date_high %td

rangematch event_date date_low date_high using "`using_dates'"

local fmt : format event_date
assert "`fmt'" == "%td"
local fmt : format date_low
assert "`fmt'" == "%td"
local fmt : format date_high
assert "`fmt'" == "%td"
local fmt : format event_date_U
assert "`fmt'" == "%td"

tempfile using_times
clear
set obs 1
gen int uid = 1
gen double event_time = clock("2020-01-01 12:00:00", "YMDhms")
format event_time %tc
save "`using_times'", replace

clear
set obs 1
gen int id = 1
gen double event_time = clock("2020-01-01 12:00:00", "YMDhms")
gen double time_low = event_time - 1000
gen double time_high = event_time + 1000
format event_time time_low time_high %tc

rangematch event_time time_low time_high using "`using_times'"

local fmt : format event_time
assert "`fmt'" == "%tc"
local fmt : format time_low
assert "`fmt'" == "%tc"
local fmt : format time_high
assert "`fmt'" == "%tc"
local fmt : format event_time_U
assert "`fmt'" == "%tc"

**# Match-density stored results require stats

tempfile using_stats
clear
set obs 10
gen int uid = _n
gen double keyval = _n
save "`using_stats'", replace

clear
input int id double(lo hi)
1 100 100
2   1   1
3   1   2
4   1  10
end

rangematch keyval lo hi using "`using_stats'", keepusing(uid)

assert r(N_master) == 4
assert r(N_using) == 10
assert r(N_pairs) == 14
assert r(N_unmatched) == 1
assert r(N_matched_pairs) == 13
foreach scalar_name in N_matched_master N_matched_using N_unmatched_master ///
    N_unmatched_using max_matches mean_matches median_matches p50_matches ///
    p90_matches p99_matches N_empty_groups N_master_groups {
    capture confirm scalar r(`scalar_name')
    assert _rc == 111
}

clear
input int id double(lo hi)
1 100 100
2   1   1
3   1   2
4   1  10
end

rangematch keyval lo hi using "`using_stats'", keepusing(uid) stats

assert r(N_master) == 4
assert r(N_using) == 10
assert r(N_pairs) == 14
assert r(N_unmatched) == 1
assert r(N_matched_pairs) == 13
assert r(N_matched_using) == 10
assert r(N_unmatched_using) == 0
assert r(N_matched_using) + r(N_unmatched_using) == r(N_using)
assert reldif(r(mean_matches), 3.25) < 1e-12
assert reldif(r(median_matches), 1.5) < 1e-12
assert reldif(r(p50_matches), 1.5) < 1e-12
assert r(p90_matches) == 10
assert r(p99_matches) == 10

clear
input int id double(lo hi)
1 100 100
2   1   1
3   1   2
4   1  10
end

rangematch keyval lo hi using "`using_stats'", keepusing(uid) count

assert r(N_pairs) == 14
assert r(N_unmatched) == 1
assert r(N_matched_pairs) == 13
foreach scalar_name in N_matched_master N_matched_using N_unmatched_master ///
    N_unmatched_using max_matches mean_matches median_matches p50_matches ///
    p90_matches p99_matches N_empty_groups N_master_groups {
    capture confirm scalar r(`scalar_name')
    assert _rc == 111
}

**# tolerance() boundary comparisons

tempfile using_tol
clear
set obs 1
gen int uid = 1
gen double keyval = 0.1 + 0.2
save "`using_tol'", replace

clear
input int id double(lo hi)
1 .3 .3
end

rangematch keyval lo hi using "`using_tol'", keepusing(uid) unmatched(none)
assert r(N_pairs) == 0
assert _N == 0

clear
input int id double(lo hi)
1 .3 .3
end

rangematch keyval lo hi using "`using_tol'", ///
    keepusing(uid) unmatched(none) tolerance(1e-12)
assert r(N_pairs) == 1
assert r(tolerance) == 1e-12
assert uid[1] == 1

clear
input int id double(lo hi)
1 .3 .3
end

capture noisily rangematch keyval lo hi using "`using_tol'", ///
    keepusing(uid) tolerance(-1)
assert _rc == 198

clear
input int id double(lo hi)
1 .3 .3
end

capture noisily rangematch keyval lo hi using "`using_tol'", ///
    keepusing(uid) tolerance(.)
assert _rc == 198

**# sort and nosort output order

tempfile using_order
clear
input int uid double keyval
1 30
2 10
3 20
end
save "`using_order'", replace

clear
input int id double(lo hi)
1 0 100
end

rangematch keyval lo hi using "`using_order'", keepusing(uid) unmatched(none)
assert uid[1] == 1
assert uid[2] == 2
assert uid[3] == 3

clear
input int id double(lo hi)
1 0 100
end

rangematch keyval lo hi using "`using_order'", ///
    keepusing(uid) unmatched(none) nosort
assert "`r(nosort)'" == "nosort"
assert uid[1] == 2
assert uid[2] == 3
assert uid[3] == 1

clear
input int id double(lo hi)
1 0 100
end

capture noisily rangematch keyval lo hi using "`using_order'", ///
    keepusing(uid) sort nosort
assert _rc == 198

display as result "ALL RANGEMATCH V1.4.0 TESTS PASSED"
