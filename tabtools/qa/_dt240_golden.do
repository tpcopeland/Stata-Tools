* _dt240_golden.do - two-group SMD sink dump for test_desctab_v240.do
*
* Defines _dt240_data (the 30-record, three-arm toy data of the R twin's
* tests/testthat/test-table1-smdtype.R, plus weights) and _dt240_dump2,
* which runs four two-group SMD tables through every sink (console listing,
* r(table), r(Dapa), excel() read back by tools/xlsx_facts.py, csv(),
* markdown(), frame()) and concatenates everything into one text file.
* qa/data/desctab_v240_golden_2grp.txt was written by this program from
* the 2.3.1 desctab/_desctab_collect code (before the multi-group SMD
* work); the suite regenerates the dump and requires byte equality.
* One intended edit since: case 3 (wtcompare) lost the 11 stray lines the
* crude/weighted merge printed ("(6 real changes made)", "(1 observation
* in frame ... unmatched)", eight "(# missing values generated)", "(8
* variables copied from linked frame)"), which 2.4.0 runs quietly. Every
* other byte is the 2.3.1 output; r() additions are not in the dump.
* Paths are relative to qa/ so the dump does not depend on the checkout.

capture program drop _dt240_data
program define _dt240_data
    version 17.0
    clear
    quietly set obs 30
    quietly gen str1 arm = cond(_n <= 8, "A", cond(_n <= 18, "B", "C"))
    quietly gen double age = .
    local ages 41 45 47 50 52 55 58 60 44 46 49 51 53 56 57 59 62 65 ///
        55 58 60 63 66 68 70 72 75 77 80 83
    local sexes 0 0 1 0 0 1 0 0 1 0 1 0 1 1 0 1 0 1 ///
        1 1 0 1 1 1 0 1 1 1 1 0
    forvalues i = 1/30 {
        quietly replace age = `: word `i' of `ages'' in `i'
    }
    quietly gen byte sex = .
    forvalues i = 1/30 {
        quietly replace sex = `: word `i' of `sexes'' in `i'
    }
    quietly gen str1 grp = substr("xyz", mod(_n - 1, 3) + 1, 1)
    quietly encode grp, gen(grpn)
    quietly gen double w = cond(mod(_n, 2), 1, 3)
    label variable age "Age"
    label variable sex "Female"
    label variable grpn "Group"
end

* The dump is console text, so it depends on display state: the golden was
* written at linesize 79 (the batch default) with a period decimal point.
* _dt240_dump2 pins both and restores the caller's values on every path, so
* the result does not depend on what ran earlier in the session (run_all's
* single-session full lane).
capture program drop _dt240_dump2
program define _dt240_dump2
    version 17.0
    args dump
    local _ls0 = c(linesize)
    local _dp0 = c(dp)
    set linesize 79
    set dp period
    capture noisily _dt240_dump2_body `"`dump'"'
    local rc = _rc
    capture log close _dt240g
    set linesize `_ls0'
    set dp `_dp0'
    if `rc' exit `rc'
end

capture program drop _dt240_dump2_body
program define _dt240_dump2_body
    version 17.0
    args dump
    local od "output"
    capture mkdir "`od'"
    capture erase "`dump'"
    local c1 "smd test"
    local c2 "smd wt(w)"
    local c3 "smd wt(w) wtcompare"
    local c4 "smd smdthreshold(0.05) nopvalue"
    forvalues k = 1/4 {
        local c "`c`k''"
        _dt240_data
        quietly keep if arm != "C"
        foreach f in con.txt xlsx.txt {
            capture erase "`od'/dt240_g`k'_`f'"
        }
        capture erase "`od'/dt240_g`k'.xlsx"
        capture frame drop dt240_gf
        quietly log using "`od'/dt240_g`k'_con.txt", text replace name(_dt240g) nomsg
        display "== case `k': `c'"
        table1_tc, by(arm) vars(age contn \ sex bin \ grpn cat) `c' ///
            excel("`od'/dt240_g`k'.xlsx") sheet("T") ///
            csv("`od'/dt240_g`k'.csv") markdown("`od'/dt240_g`k'.md") ///
            frame(dt240_gf)
        display `"Dapa: `r(Dapa)'"'
        matrix list r(table), format(%21x)
        frame dt240_gf: list, noobs
        quietly log close _dt240g
        frame drop dt240_gf
        shell python3 tools/xlsx_facts.py "`od'/dt240_g`k'.xlsx" T "`od'/dt240_g`k'_xlsx.txt"
        * frlink names a tempframe (__000007) that depends on session state
        shell sed -i -E "s/__[0-9A-F]{6}/__TMPNAM/g" "`od'/dt240_g`k'_con.txt"
        shell cat "`od'/dt240_g`k'_con.txt" "`od'/dt240_g`k'.csv" "`od'/dt240_g`k'.md" "`od'/dt240_g`k'_xlsx.txt" >> "`dump'"
    }
    confirm file "`dump'"
end

if "$DT240_MAKE_GOLDEN" == "1" {
    local qa_dir "`c(pwd)'"
    local pkg_dir = regexr("`qa_dir'", "/qa$", "")
    capture ado uninstall tabtools
    quietly net install tabtools, from("`pkg_dir'") replace
    discard
    _dt240_dump2 "data/desctab_v240_golden_2grp.txt"
}
