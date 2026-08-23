* Randomized preservation oracle for compress_tc. Seed: 26082304. 200 repetitions.
clear all
set more off
version 16.0
local pkg_dir "`c(pwd)'/.."
capture ado uninstall compress_tc
adopath ++ "`pkg_dir'"
set seed 26082304

forvalues rep = 1/200 {
    tempfile before after
    clear
    set obs 37
    gen long rowid = _n
    gen str32 long_name_12345678901234567890 = cond(mod(_n, 3), "repeated value", string(runiform()))
    gen str24 _compress_tc_shadow = "shadow_" + string(_n)
    gen double x = runiform()
    replace long_name_12345678901234567890 = "" if mod(_n + `rep', 11) == 0
    save "`before'", replace
    compress_tc, quietly
    assert r(bytes_initial) - r(bytes_final) == r(bytes_saved)
    assert r(pct_saved) >= 0 & r(pct_saved) <= 100
    save "`after'", replace
    use "`before'", clear
    cf _all using "`after'"
    unab before_vars : _all
    use "`after'", clear
    unab after_vars : _all
    assert "`before_vars'" == "`after_vars'"
    assert _compress_tc_shadow == "shadow_" + string(_n)
}

* dryrun() is a no-mutation contract, including storage type.
clear
set obs 5
gen str80 original = "long repeated string"
local before_type : type original
compress_tc, quietly dryrun
local after_type : type original
assert "`before_type'" == "`after_type'"
display as result "RESULT: PASS compress_tc randomized oracle (200 reps)"
