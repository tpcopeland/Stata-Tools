* test_rangematch_abbrev.do — lock minimum-abbreviation contract for options
* Guards the keepusing() abbreviation documented in rangematch.sthlp as
* {opt keepu:sing(varlist)} (syntax: KEEPUsing -> min "keepu"). A static
* abbreviation checker has mis-flagged this as requiring the full name; this
* test pins the real, executable contract.
clear all
set more off

cap ado uninstall rangematch
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
adopath ++ "`pkg_dir'"

* Using frame: key (id) plus a carry variable
frame create using_f
frame using_f {
    set obs 3
    gen id = _n
    gen carryme = _n * 100
}

* Master data
clear
set obs 2
gen lo = 0
gen hi = 5
gen id = _n

* keepu — the documented minimum abbreviation — must resolve
rangematch id lo hi using using_f, keepu(carryme) frame(out1) replace
frame out1: confirm variable carryme
di as result "PASS T1: keepu() minimum abbreviation resolves"

* keepus — an intermediate-length form — must also resolve
rangematch id lo hi using using_f, keepus(carryme) frame(out2) replace
frame out2: confirm variable carryme
di as result "PASS T2: keepus() resolves"

* keepusing — the full form — must resolve
rangematch id lo hi using using_f, keepusing(carryme) frame(out3) replace
frame out3: confirm variable carryme
di as result "PASS T3: keepusing() full form resolves"

* keep — shorter than the documented minimum — must fail (rc=198)
cap noisily rangematch id lo hi using using_f, keep(carryme) frame(out4) replace
assert _rc == 198
di as result "PASS T4: keep() (below documented minimum) errors rc=" _rc

di as result "ALL TESTS PASSED"
