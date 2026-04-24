* Test Mata optimizations for codescan v1.1.0
* Tests: match count accumulation, co-occurrence overlap detection,
*        multi-window single-pass, describe hash tabulation

capture ado uninstall codescan
net install codescan, from("/home/tpcopeland/Stata-Tools/codescan") replace

clear
set seed 42
set obs 1000

gen str5 pid = "P" + string(ceil(runiform() * 200), "%04.0f")
gen double date = mdy(1,1,2020) + floor(runiform() * 365)
format date %td
gen double refdate = mdy(6,1,2020)
format refdate %td

gen str5 dx1 = ""
gen str5 dx2 = ""
gen str5 dx3 = ""

forvalues i = 1/`=_N' {
    if runiform() < 0.3 quietly replace dx1 = "E11" + string(floor(runiform()*10)) in `i'
    if runiform() < 0.2 quietly replace dx2 = "I10" in `i'
    if runiform() < 0.1 quietly replace dx3 = "J44" + string(floor(runiform()*10)) in `i'
    if runiform() < 0.15 quietly replace dx1 = "E66" in `i'
}

display _n "=== TEST 1: Basic row-level scan (match counts from Mata) ==="
codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid)
return list
assert r(N) == 1000
assert r(n_conditions) == 4

display _n "=== TEST 2: Collapse mode ==="
preserve
codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid) collapse replace
return list
assert r(collapsed) == 1
restore

display _n "=== TEST 3: Merge mode ==="
preserve
codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid) merge replace
return list
assert r(merged) == 1
restore

display _n "=== TEST 4: Countmode ==="
codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid) countmode replace
return list

display _n "=== TEST 5: Co-occurrence overlap detection (single Mata pass) ==="
* Create overlapping conditions that trigger the overlap warning
codescan dx1-dx3, define(diabetes "E1[01]" | dm2 "E11") id(pid) noisily replace
return list

display _n "=== TEST 6: Multi-window sensitivity (single supplementary scan) ==="
preserve
codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44") ///
    id(pid) date(date) refdate(refdate) lookback(30 90 180 365) collapse replace
return list
assert r(n_conditions) == 3
matrix list r(sensitivity)
restore

display _n "=== TEST 7: Multi-window with collapse ==="
preserve
codescan dx1-dx3, define(dm2 "E11" | htn "I10") ///
    id(pid) date(date) refdate(refdate) lookback(30 90 180) collapse replace
return list
matrix list r(sensitivity)
restore

display _n "=== TEST 8: codescan_describe (Mata hash tabulation) ==="
codescan_describe dx1-dx3
return list
assert r(n_unique) > 0
assert r(n_entries) > 0
matrix list r(top_codes)
matrix list r(chapters)

display _n "=== TEST 9: codescan_describe with nodots ==="
codescan_describe dx1-dx3, nodots
return list

display _n "=== TEST 10: Detail mode (per-variable tracking) ==="
codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44") id(pid) detail replace
return list
matrix list r(varcounts)

display _n "=== TEST 11: Prefix mode ==="
codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44") id(pid) mode(prefix) replace
return list

display _n "=== TEST 12: Nocase ==="
codescan dx1-dx3, define(dm2 "e11" | htn "i10") id(pid) nocase replace
return list

display _n "=== TEST 13: Co-occurrence option ==="
preserve
codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") ///
    id(pid) collapse cooccurrence replace
return list
matrix list r(cooccurrence)
restore

display _n "=== TEST 14: Matched code capture ==="
codescan dx1-dx3, define(dm2 "E11" | htn "I10") id(pid) matched_code(mc) replace
assert mc != "" if dm2 == 1 | htn == 1
return list

display _n "=== ALL TESTS PASSED ==="
