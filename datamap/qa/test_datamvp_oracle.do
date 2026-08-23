* Seed: 26082421. 200 randomized missing-pattern conservation checks.
clear all
version 16.0
local pkg_dir "`c(pwd)'/.."
adopath ++ "`pkg_dir'"
set seed 26082421
forvalues rep = 1/200 {
    clear
    set obs 29
    gen double x = runiform()
    gen double y = runiform()
    replace x = . if runiform()<.3
    replace y = . if runiform()<.4
    gen byte want_complete = !missing(x,y)
    gen str12 _datamap_shadow = "keep_"+string(_n)
    quietly count if want_complete
    local wc = r(N)
    datamvp x y, summary
    assert r(N) == 29
    assert r(N_complete) == `wc'
    assert r(N_incomplete) == 29-`wc'
    assert r(N_complete)+r(N_incomplete)==r(N)
    assert _datamap_shadow == "keep_"+string(_n)
}
display as result "RESULT: PASS datamap datamvp randomized oracle (200 reps)"
