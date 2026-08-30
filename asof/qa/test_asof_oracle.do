*! test_asof_oracle.do - Seeded brute-force parity for asof
*! Author: Timothy P Copeland, Karolinska Institutet
*! Seed: 26082301; repetitions: 200

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_oracle.log", replace text nomsg
global ASOF_QA_STATUS "fail"

quietly do "`c(pwd)'/_asof_qa_common.do"
quietly _asof_qa_bootstrap
set seed 26082301

local test_count = 0
local pass_count = 0
local fail_count = 0

forvalues rep = 1/200 {
    local ++test_count
    capture noisily {
    tempfile master events expected
    clear
    set obs 23
    gen long rowid = _n
    gen byte id = ceil(runiform() * 5)
    gen double anchor = floor(runiform() * 61) - 10
    gen byte keepme = mod(_n, 4) != 0
    gen str12 _asof_shadow = "master_" + string(_n)
    save "`master'", replace

    clear
    set obs 31
    gen byte id = ceil(runiform() * 5)
    gen double visit = floor(runiform() * 71) - 15
    gen double score = _n + `rep' / 1000
    gen str12 _asof_shadow = "event_" + string(_n)
    gen double shuffle = runiform()
    sort shuffle
    drop shuffle
    gen long event_order = _n
    save "`events'", replace

    * Brute-force reference: Cartesian product, then minimum absolute gap;
    * lower date wins the nearest() tie under ties(before).
    use "`master'", clear
    joinby id using "`events'"
    gen double signed_gap = visit - anchor
    gen double absolute_gap = abs(signed_gap)
    sort rowid absolute_gap visit event_order
    by rowid: keep if _n == 1
    keep rowid score visit signed_gap
    rename score want_score
    rename visit want_visit
    rename signed_gap want_gap
    save "`expected'", replace

    use "`master'", clear
    asof score using "`events'" if keepme, id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) ties(before) generate(got_score) ///
        datename(got_visit) gapname(got_gap) matchname(got_match) nowarn
    merge 1:1 rowid using "`expected'", nogen
    assert got_match == !missing(want_score) if keepme
    assert got_score == want_score if keepme
    assert got_visit == want_visit if keepme
    assert got_gap == want_gap if keepme
    assert missing(got_score) & missing(got_visit) & missing(got_gap) & missing(got_match) if !keepme
    assert substr(_asof_shadow, 1, 7) == "master_"
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

* Missing keys and an exact nearest tie use the documented unchanged/before rules.
local ++test_count
capture noisily {
clear
input byte(id) double(anchor) byte keepme
1 10 1
. 10 1
1 . 1
1 10 0
end
gen str12 _asof_shadow = "master"
tempfile hostile_events
preserve
clear
input byte(id) double(visit score)
1 8 80
1 12 120
end
save "`hostile_events'", replace
restore
asof score using "`hostile_events'" if keepme, id(id) date(visit) anchor(anchor) ///
    direction(both) select(nearest) ties(before) generate(got) datename(gdate) ///
    gapname(ggap) matchname(gmatch) nowarn
assert got == 80 & gdate == 8 & ggap == -2 & gmatch == 1 in 1
assert missing(got) & missing(gdate) & missing(ggap) & missing(gmatch) in 2/4
assert _asof_shadow == "master"
}
if _rc == 0 local ++pass_count
else local ++fail_count

display as result "RESULT: test_asof_oracle tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
