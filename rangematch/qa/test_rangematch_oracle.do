* Randomized point-in-interval oracle for rangematch. Seed: 26082303. 200 repetitions.
clear all
set more off
version 16.1
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
set seed 26082303

forvalues rep = 1/200 {
    tempfile master using expected actual
    clear
    set obs 19
    gen long mid = _n
    gen byte group = ceil(runiform() * 4)
    gen double lo = floor(runiform() * 51) - 10
    gen double hi = lo + floor(runiform() * 10)
    replace lo = . if mod(mid + `rep', 17) == 0
    save "`master'", replace

    clear
    set obs 27
    gen long uid = _n
    gen byte group = ceil(runiform() * 4)
    gen double ukey = floor(runiform() * 61) - 15
    replace ukey = . if mod(uid + `rep', 19) == 0
    gen str12 _rangematch_shadow = "using_" + string(_n)
    gen double shuffle = runiform()
    sort shuffle
    drop shuffle
    save "`using'", replace

    use "`master'", clear
    joinby group using "`using'", unmatched(none)
    keep if lo < . & hi < . & ukey < . & ukey >= lo & ukey <= hi
    keep mid uid
    sort mid uid
    save "`expected'", replace

    use "`master'", clear
    rangematch ukey lo hi using "`using'", by(group) keepusing(uid) ///
        unmatched(none) missing(drop)
    keep mid uid
    sort mid uid
    save "`actual'", replace
    use "`expected'", clear
    cf _all using "`actual'"
    unab expected_vars : _all
    use "`actual'", clear
    unab actual_vars : _all
    assert "`expected_vars'" == "`actual_vars'"
}
display as result "RESULT: PASS rangematch randomized oracle (200 reps)"
