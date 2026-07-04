* validation_rangematch_known_answers.do — a large battery of small, fully
* hand-computed known-answer scenarios for rangematch. Each block builds a tiny
* master/using pair whose matched (mid,uid) set and count are derived by hand
* from the documented semantics (NOT from rangematch, joinby, or any other
* command), then asserts rangematch reproduces exactly that answer.
*
* This complements the brute-force joinby oracles (validation_rangematch_oracle,
* _manual, _nearest): those prove parity against an independent implementation on
* larger/randomized data; this file pins the exact integer answer on the four
* closure rules, degenerate/inverted intervals, wildcard vs literal open bounds,
* missing() policy, scalar key-offset bounds, by() group isolation, the match
* statistics, maxpairs guard, point-mode signed distance, tolerance boundaries,
* full-outer using accounting, and interval-overlap mode incl. open-ended bounds.
clear all
version 17.0
set varabbrev off

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
quietly net install rangematch, from("`pkg_dir'") replace

local test_count = 0

* Shared point-in-interval using dataset for the closure-rule blocks. Master
* window is [10,20]; keys sit below, on the low endpoint, interior, on the high
* endpoint, and above, so each closure rule selects a different, known subset.
tempfile clo_using
clear
input int uid double ukey
1  9
2 10
3 15
4 20
5 21
end
save "`clo_using'", replace

**# 1. closed(both) includes both endpoints -> {10,15,20} = uid 2,3,4
local ++test_count
clear
input int mid double(lo hi)
1 10 20
end
rangematch ukey lo hi using "`clo_using'", keepusing(uid) ///
    unmatched(none) closed(both)
assert r(N_matched_pairs) == 3
sort uid
assert _N == 3
assert uid[1] == 2 & uid[2] == 3 & uid[3] == 4
display as result "PASS: closed(both) endpoint inclusion known answer"

**# 2. closed(left) [10,20) drops the high endpoint -> {10,15} = uid 2,3
local ++test_count
clear
input int mid double(lo hi)
1 10 20
end
rangematch ukey lo hi using "`clo_using'", keepusing(uid) ///
    unmatched(none) closed(left)
assert r(N_matched_pairs) == 2
sort uid
assert _N == 2
assert uid[1] == 2 & uid[2] == 3
display as result "PASS: closed(left) drops high endpoint known answer"

**# 3. closed(right) (10,20] drops the low endpoint -> {15,20} = uid 3,4
local ++test_count
clear
input int mid double(lo hi)
1 10 20
end
rangematch ukey lo hi using "`clo_using'", keepusing(uid) ///
    unmatched(none) closed(right)
assert r(N_matched_pairs) == 2
sort uid
assert _N == 2
assert uid[1] == 3 & uid[2] == 4
display as result "PASS: closed(right) drops low endpoint known answer"

**# 4. closed(none) (10,20) drops both endpoints -> {15} = uid 3
local ++test_count
clear
input int mid double(lo hi)
1 10 20
end
rangematch ukey lo hi using "`clo_using'", keepusing(uid) ///
    unmatched(none) closed(none)
assert r(N_matched_pairs) == 1
assert _N == 1
assert uid[1] == 3
display as result "PASS: closed(none) drops both endpoints known answer"

**# 5. Inverted interval (lo>hi) matches nothing on any row
local ++test_count
clear
input int mid double(lo hi)
1 20 10
end
rangematch ukey lo hi using "`clo_using'", keepusing(uid) ///
    unmatched(none) closed(both)
assert r(N_matched_pairs) == 0
* unmatched(master) keeps the single inverted master row as unmatched
clear
input int mid double(lo hi)
1 20 10
end
rangematch ukey lo hi using "`clo_using'", keepusing(uid) unmatched(master) stats
assert r(N_matched_pairs) == 0
assert r(N_unmatched_master) == 1
assert r(N_pairs) == 1
display as result "PASS: inverted interval matches nothing known answer"

**# 6. Degenerate point interval lo==hi: closed(both) keeps the exact key only,
* closed(none) keeps nothing.
local ++test_count
tempfile pt_using
clear
input int uid double ukey
1 14
2 15
3 16
end
save "`pt_using'", replace
clear
input int mid double(lo hi)
1 15 15
end
rangematch ukey lo hi using "`pt_using'", keepusing(uid) ///
    unmatched(none) closed(both)
assert r(N_matched_pairs) == 1
assert uid[1] == 2
clear
input int mid double(lo hi)
1 15 15
end
rangematch ukey lo hi using "`pt_using'", keepusing(uid) ///
    unmatched(none) closed(none)
assert r(N_matched_pairs) == 0
display as result "PASS: degenerate point interval known answer"

* Shared using for the open-bound blocks: keys 5,10,15,20.
tempfile open_using
clear
input int uid double ukey
1  5
2 10
3 15
4 20
end
save "`open_using'", replace

**# 7. Missing low BOUND VARIABLE -> wildcard -> (-inf,15] -> {5,10,15} = 3
local ++test_count
clear
input int mid double(lo hi)
1 . 15
end
rangematch ukey lo hi using "`open_using'", keepusing(uid) ///
    unmatched(none) closed(both) missing(wildcard)
assert r(N_matched_pairs) == 3
assert r(N_missing_bounds) == 1
sort uid
assert uid[1] == 1 & uid[2] == 2 & uid[3] == 3
display as result "PASS: missing low bound wildcard -> open lower known answer"

**# 8. Missing high BOUND VARIABLE -> wildcard -> [10,+inf) -> {10,15,20} = 3
local ++test_count
clear
input int mid double(lo hi)
1 10 .
end
rangematch ukey lo hi using "`open_using'", keepusing(uid) ///
    unmatched(none) closed(both) missing(wildcard)
assert r(N_matched_pairs) == 3
assert r(N_missing_bounds) == 1
sort uid
assert uid[1] == 2 & uid[2] == 3 & uid[3] == 4
display as result "PASS: missing high bound wildcard -> open upper known answer"

**# 9. missing(drop) removes the missing-bound master row; the other row still
* matches on its own window.
local ++test_count
clear
input int mid double(lo hi)
1 . 15
2 0 100
end
rangematch ukey lo hi using "`open_using'", keepusing(uid) ///
    unmatched(none) closed(both) missing(drop)
assert r(N_missing_bounds) == 1
assert r(N_master) == 1
* mid==2 window [0,100] matches all four using keys
assert r(N_matched_pairs) == 4
count if mid == 1
assert r(N) == 0
display as result "PASS: missing(drop) removes missing-bound master known answer"

**# 10. missing(error) exits rc 459 when a bound variable is missing
local ++test_count
clear
input int mid double(lo hi)
1 . 15
2 0 100
end
capture rangematch ukey lo hi using "`open_using'", keepusing(uid) ///
    unmatched(none) missing(error)
assert _rc == 459
display as result "PASS: missing(error) exits 459 known answer"

**# 11. Literal `.' open-lower token with a VARIABLE high bound: window
* (-inf, hi]. The literal `.' is the user's explicit open token, so it is NOT
* counted as a missing bound (contrast block 7 which uses a missing variable).
local ++test_count
clear
input int mid double hi
1 15
end
rangematch ukey . hi using "`open_using'", keepusing(uid) ///
    unmatched(none) closed(both)
assert r(N_matched_pairs) == 3
assert r(N_missing_bounds) == 0
sort uid
assert uid[1] == 1 & uid[2] == 2 & uid[3] == 3
display as result "PASS: literal open-lower token known answer"

**# 12. Scalar key-offset bounds: finite literal bounds are offsets from the key.
* rangematch event_date -10 5 -> window [key-10, key+5]. Master key=100 ->
* [90,105] -> using event_dates {90,100,105} = 3 (89 and 106 excluded).
local ++test_count
tempfile off_using
clear
input int uid double event_date
1  89
2  90
3 100
4 105
5 106
end
save "`off_using'", replace
clear
input int mid double event_date
1 100
end
rangematch event_date -10 5 using "`off_using'", keepusing(uid) ///
    unmatched(none) closed(both)
assert r(N_matched_pairs) == 3
sort uid
assert uid[1] == 2 & uid[2] == 3 & uid[3] == 4
display as result "PASS: scalar key-offset bounds known answer"

**# 13. by() group isolation: identical in-range keys in a different group must
* NOT match. Without by() all three would match mid 1.
local ++test_count
tempfile by_using
clear
input int uid byte grp double ukey
1 1 5
2 2 5
3 1 5
end
save "`by_using'", replace
clear
input int mid byte grp double(lo hi)
1 1 0 10
2 2 0 10
end
rangematch ukey lo hi using "`by_using'", by(grp) keepusing(uid) ///
    unmatched(none) closed(both)
assert r(N_matched_pairs) == 3
* mid 1 (grp 1) -> uid 1,3 ; mid 2 (grp 2) -> uid 2
count if mid == 1 & inlist(uid, 1, 3)
assert r(N) == 2
count if mid == 2 & uid == 2
assert r(N) == 1
count if mid == 1 & uid == 2
assert r(N) == 0
display as result "PASS: by() group isolation known answer"

**# 14. Match statistics over ALL master rows (incl. zero/low-match rows).
* Windows chosen so per-row match counts are exactly {5,3,1}:
*   mid1 [0,100] -> keys {1,10,20,30,40} = 5
*   mid2 [0,25]  -> keys {1,10,20}       = 3
*   mid3 [0,1]   -> key  {1}             = 1
* max=5, mean=(5+3+1)/3=3, median(1,3,5)=3, N_pairs=9.
local ++test_count
tempfile st_using
clear
input int uid double ukey
1  1
2 10
3 20
4 30
5 40
end
save "`st_using'", replace
clear
input int mid double(lo hi)
1 0 100
2 0 25
3 0 1
end
rangematch ukey lo hi using "`st_using'", keepusing(uid) ///
    unmatched(none) closed(both) stats
assert r(N_matched_pairs) == 9
assert r(max_matches) == 5
assert abs(r(mean_matches) - 3) < 1e-9
assert abs(r(median_matches) - 3) < 1e-9
display as result "PASS: match statistics known answer"

**# 15. maxpairs() guard: a join that would exceed the cap errors rc 198; a cap
* at exactly the produced count succeeds.
local ++test_count
clear
input int mid double(lo hi)
1 0 100
end
capture rangematch ukey lo hi using "`st_using'", keepusing(uid) ///
    unmatched(none) maxpairs(3)
assert _rc == 198
clear
input int mid double(lo hi)
1 0 100
end
rangematch ukey lo hi using "`st_using'", keepusing(uid) ///
    unmatched(none) maxpairs(5)
assert r(N_matched_pairs) == 5
display as result "PASS: maxpairs() guard known answer"

**# 16. Signed distance in point mode (no nearest): delta = using_key - key.
* Master key=10, window [0,100] matches keys {7,10,13} -> deltas {-3,0,3}.
local ++test_count
tempfile dst_using
clear
input int uid double ukey
1  7
2 10
3 13
end
save "`dst_using'", replace
clear
input int mid double(ukey lo hi)
1 10 0 100
end
rangematch ukey lo hi using "`dst_using'", keepusing(uid) ///
    unmatched(none) closed(both) distance(delta)
sort uid
assert _N == 3
assert uid[1] == 1 & delta[1] == -3
assert uid[2] == 2 & delta[2] == 0
assert uid[3] == 3 & delta[3] == 3
display as result "PASS: point-mode signed distance known answer"

**# 17. tolerance() widens both bounds symmetrically. Keys 4.5 and 10.5 sit just
* outside [5,10]. tol(0)->0 ; tol(0.4)->[4.6,10.4]->0 ; tol(1)->[4,11]->2.
local ++test_count
tempfile tol_using
clear
input int uid double ukey
1  4.5
2 10.5
end
save "`tol_using'", replace
clear
input int mid double(lo hi)
1 5 10
end
rangematch ukey lo hi using "`tol_using'", keepusing(uid) ///
    unmatched(none) closed(both) tolerance(0)
assert r(N_matched_pairs) == 0
clear
input int mid double(lo hi)
1 5 10
end
rangematch ukey lo hi using "`tol_using'", keepusing(uid) ///
    unmatched(none) closed(both) tolerance(0.4)
assert r(N_matched_pairs) == 0
clear
input int mid double(lo hi)
1 5 10
end
rangematch ukey lo hi using "`tol_using'", keepusing(uid) ///
    unmatched(none) closed(both) tolerance(1)
assert r(N_matched_pairs) == 2
assert r(tolerance) == 1
display as result "PASS: tolerance() boundary known answers"

**# 18. unmatched(using) full-right accounting: an out-of-range key and a missing
* key both surface as unmatched-using rows.
local ++test_count
tempfile un_using
clear
input int uid double ukey
1  5
2 99
3  .
end
save "`un_using'", replace
clear
input int mid double(lo hi)
1 0 10
end
rangematch ukey lo hi using "`un_using'", keepusing(uid) unmatched(using) stats
assert r(N_matched_pairs) == 1
assert r(N_unmatched_using) == 2
assert r(N_using_missing) == 1
assert r(N_pairs) == 3
assert r(N_unmatched) == 2
display as result "PASS: unmatched(using) accounting known answer"

**# 19. Interval-overlap mode. Master interval [10,20] vs using intervals.
*   [5,10]  touches at 10        [12,15] interior       [20,30] touches at 20
*   [0,5]   disjoint below       [25,30] disjoint above
* closed(both): touching counts -> {[5,10],[12,15],[20,30]} = 3
* closed(none): strict -> only {[12,15]} = 1
local ++test_count
tempfile ov_using
clear
input int uid double(ulo uhi)
1  5 10
2 12 15
3 20 30
4  0  5
5 25 30
end
save "`ov_using'", replace
clear
input int mid double(mlo mhi)
1 10 20
end
rangematch mlo mhi using "`ov_using'", overlap(ulo uhi) keepusing(uid) ///
    unmatched(none) closed(both)
assert r(N_matched_pairs) == 3
sort uid
assert uid[1] == 1 & uid[2] == 2 & uid[3] == 3
clear
input int mid double(mlo mhi)
1 10 20
end
rangematch mlo mhi using "`ov_using'", overlap(ulo uhi) keepusing(uid) ///
    unmatched(none) closed(none)
assert r(N_matched_pairs) == 1
assert uid[1] == 2
display as result "PASS: overlap closed(both|none) known answer"

**# 20. Overlap open-ended using bounds: missing ulo -> -inf, missing uhi -> +inf.
* Master [10,20]. (-inf,15] overlaps; [15,+inf) overlaps; (-inf,5] and [30,+inf)
* do not -> matches uid 2,4 = 2.
local ++test_count
tempfile ovo_using
clear
input int uid double(ulo uhi)
1  .  5
2  . 15
3 30  .
4 15  .
end
save "`ovo_using'", replace
clear
input int mid double(mlo mhi)
1 10 20
end
rangematch mlo mhi using "`ovo_using'", overlap(ulo uhi) keepusing(uid) ///
    unmatched(none) closed(both)
assert r(N_matched_pairs) == 2
sort uid
assert uid[1] == 2 & uid[2] == 4
display as result "PASS: overlap open-ended bounds known answer"

**# 21. Overlap with no overlapping intervals -> zero matches; the master row is
* retained as unmatched under the default unmatched(master).
local ++test_count
tempfile ovn_using
clear
input int uid double(ulo uhi)
1  0  5
2 25 30
end
save "`ovn_using'", replace
clear
input int mid double(mlo mhi)
1 10 20
end
rangematch mlo mhi using "`ovn_using'", overlap(ulo uhi) keepusing(uid) ///
    unmatched(master) stats
assert r(N_matched_pairs) == 0
assert r(N_unmatched_master) == 1
assert r(N_pairs) == 1
display as result "PASS: overlap no-overlap known answer"

display as result "ALL RANGEMATCH KNOWN-ANSWER VALIDATION TESTS PASSED"
display "RESULT: validation_rangematch_known_answers tests=`test_count' pass=`test_count' fail=0"
