*! test_stratetab_order.do — Regression test for covariate sort-order bug
*! stratetab must preserve the original row order from strate output files
*! Bug: bysort in duplicate-label check re-sorted rows alphabetically

clear all
set more off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

**# Setup: create strate-style output files with non-alphabetical order
* Categories deliberately NOT in alphabetical order: Zebra, Apple, Mango
* If stratetab re-sorts, output will be: Apple, Mango, Zebra

clear
input str10 category _D _Y _Rate _Lower _Upper
"Zebra"   50 1000  50  37  66
"Apple"   30  800  37  26  53
"Mango"   20  500  40  25  62
end
save "/tmp/strate_order_test_o1_e1.dta", replace

clear
input str10 category _D _Y _Rate _Lower _Upper
"Zebra"   15 1000  15  9  25
"Apple"   10  800  12  6  23
"Mango"    8  500  16  8  31
end
save "/tmp/strate_order_test_o2_e1.dta", replace

clear

**# Test: verify original order is preserved
stratetab, using(/tmp/strate_order_test_o1_e1 /tmp/strate_order_test_o2_e1) ///
    xlsx(/tmp/strate_order_test.xlsx) outcomes(2) ///
    outlabels(Outcome A \ Outcome B) ///
    explabels(Test Exposure)

* Check r(rates) matrix row order
matrix list r(rates)

* Row 1 should be Zebra (rate=50000 after *1000 default), not Apple
local row1_rate = r(rates)[1,1]
local row2_rate = r(rates)[2,1]
local row3_rate = r(rates)[3,1]

* Zebra rate=50 * 1000 = 50000, Apple=37*1000=37000, Mango=40*1000=40000
assert abs(`row1_rate' - 50000) < 1    // Zebra first (original order)
assert abs(`row2_rate' - 37000) < 1    // Apple second
assert abs(`row3_rate' - 40000) < 1    // Mango third

display as result "PASSED: stratetab preserves original strate row order"

**# Cleanup
capture erase "/tmp/strate_order_test_o1_e1.dta"
capture erase "/tmp/strate_order_test_o2_e1.dta"
capture erase "/tmp/strate_order_test.xlsx"
