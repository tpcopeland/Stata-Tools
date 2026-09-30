clear all
set more off
version 16.0
set linesize 255

* test_dataqa.do - dataqa set/report/assert/export/compare and the datacheck
* ledger() it reads (datamap 1.8.0 E2, L1, L2).  Expected values come from
* the fixture designs; the register draft is compared with a hand-written
* golden file (golden/dataqa_report.md) with the date column normalized.

* === Bootstrap: targeted local reinstall ===
local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

* === Tally helper ===
global TC 0
global PASS 0
global FAIL 0
capture program drop _dq
program define _dq
    args rc msg
    global TC = $TC + 1
    if `rc' == 0 {
        display as result "  PASS: `msg'"
        global PASS = $PASS + 1
    }
    else {
        display as error "  FAIL (rc=`rc'): `msg'"
        global FAIL = $FAIL + 1
    }
end

capture program drop _dq_count
program define _dq_count, rclass
    args file needle
    tempname fh
    local n = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

capture program drop _dq_fix
program define _dq_fix
    clear
    set obs 20
    gen long id = _n
    gen double x = _n
end

local L "`c(tmpdir)'/dq_ledger_test.dta"
local L2 "`c(tmpdir)'/dq_ledger_test2.dta"
local MD "`c(tmpdir)'/dq_report_test.md"
local EX "`c(tmpdir)'/dq_export_test.dta"
tempfile lg

**# dataqa set

capture noisily {
    macro drop DATAMAP_DQ
    dataqa set maskrare mincell(5) ledger("`L'") run(g1) bandwarn
    assert `"$DATAMAP_DQ"' == `"maskrare mincell(5) ledger("`L'") run(g1) bandwarn"'
    assert `"`r(defaults)'"' == `"$DATAMAP_DQ"'
    * a leading comma is accepted; each set replaces the defaults
    dataqa set , maskrare
    assert `"$DATAMAP_DQ"' == "maskrare"
    dataqa set
    assert `"`r(defaults)'"' == "maskrare"
    dataqa set clear
    assert `"$DATAMAP_DQ"' == ""
    capture dataqa set sideways
    assert _rc == 198
    capture dataqa set run(r1)
    assert _rc == 198
    capture dataqa set ledger("`c(tmpdir)'/a;b.dta")
    assert _rc == 198
    capture dataqa
    assert _rc == 198
    capture dataqa frobnicate
    assert _rc == 198
}
_dq `=_rc' "dataqa set: stores, lists, replaces and clears defaults; refuses bad input"
macro drop DATAMAP_DQ

**# precedence: explicit > session > config

capture noisily {
    _dq_fix
    tempfile cfg
    file open fh using "`cfg'", write text replace
    file write fh "mincell = 9" _n
    file close fh
    dataqa set mincell(3)
    datacheck, gatesonly isid(id) config("`cfg'")
    assert r(mincell) == 3
    datacheck, gatesonly isid(id) mincell(7) config("`cfg'")
    assert r(mincell) == 7
    dataqa set clear
    datacheck, gatesonly isid(id) config("`cfg'")
    assert r(mincell) == 9
    * nomaskrare overrides a session maskrare and says so
    dataqa set maskrare
    capture log close _dql
    log using "`lg'", text replace name(_dql)
    datacheck, gatesonly isid(id) nomaskrare
    local mk = r(maskrare)
    datacheck, gatesonly isid(id)
    local mk2 = r(maskrare)
    log close _dql
    assert `mk' == 0 & `mk2' == 1
    _dq_count "`lg'" "note: nomaskrare overrides the session default maskrare"
    assert r(n) == 1
    _dq_count "`lg'" "[masked <5]"
    assert r(n) == 1
    dataqa set clear
    global DATAMAP_DQ "notanoption(1)"
    capture datacheck, gatesonly isid(id)
    assert _rc == 198
    macro drop DATAMAP_DQ
}
_dq `=_rc' "session defaults: explicit beats session beats config(); nomaskrare overrides with a note"
macro drop DATAMAP_DQ

**# ledger(): one row per gate entry, appended across calls and datasets

capture erase "`L'"
capture noisily {
    dataqa set maskrare mincell(5) ledger("`L'") run(g1) bandwarn
    * alpha: isid passes; rule fails on x = 19, 20 (2 rows); the band on
    * mean x (10.5) warns under bandwarn; review counts x = 1, 2
    _dq_fix
    capture datacheck, gatesonly isid(id) rule("big": x <= 18) ///
        bands(stat(mean x 0 5)) review("low": x < 3) name(alpha)
    assert _rc == 9
    assert r(ledger_seq) == 1
    _dq_fix
    datacheck, gatesonly isid(id) name(beta)
    assert r(ledger_seq) == 2
    assert "`r(ledger)'" == "`L'"
    dataqa set clear
    preserve
    use "`L'", clear
    assert _N == 5
    count if dataset == "alpha"
    assert r(N) == 4
    count if dataset == "beta" & family == "isid" & status == "pass" & seq == 2
    assert r(N) == 1
    count if family == "rule" & status == "fail" & kind == "invariant" & observed == "<5 fail"
    assert r(N) == 1
    count if family == "stat" & status == "warn" & kind == "band"
    assert r(N) == 1
    count if family == "review" & status == "review" & kind == "review"
    assert r(N) == 1
    * the ledger records the installed datacheck version, whatever it is
    quietly _datamap_version datacheck
    assert run == "g1" & version == "`r(version)'" & "`r(version)'" != "unknown" & masked == 1 & mincell == 5
    assert missing(observed_num) if obs_masked == 1
    restore
}
_dq `=_rc' "ledger(): pass, fail, warn and review rows for every gate entry, seq per call"

**# dataqa report: console summary and the register draft

capture noisily {
    capture erase "`MD'"
    capture log close _dql
    log using "`lg'", text replace name(_dql)
    dataqa report using "`L'", run(g1) markdown("`MD'")
    local nr = r(n_rows)
    local nds = r(n_datasets)
    log close _dql
    assert `nr' == 4 & `nds' == 2
    * compare with the golden draft, date column normalized
    tempname a b
    file open `a' using "`MD'", read text
    file open `b' using "`qa_dir'/golden/dataqa_report.md", read text
    local nl = 0
    local ndiff = 0
    file read `a' la
    file read `b' lb
    while r(eof) == 0 {
        local la = regexr(`"`macval(la)'"', "\| [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] \|", "| DATE |")
        if `"`macval(la)'"' != `"`macval(lb)'"' {
            local ++ndiff
            display as error `"  got:    `macval(la)'"'
            display as error `"  golden: `macval(lb)'"'
        }
        local ++nl
        file read `a' la
        file read `b' lb
    }
    file close `a'
    file close `b'
    assert `ndiff' == 0 & `nl' == 6
    * an existing draft is not overwritten without replace
    capture dataqa report using "`L'", run(g1) markdown("`MD'")
    assert _rc == 602
}
_dq `=_rc' "dataqa report: register draft matches the golden file, with the dispositions each kind allows"
capture file close `a'
capture file close `b'

**# dataqa assert

capture noisily {
    capture dataqa assert using "`L'", run(g1)
    assert _rc == 9 & r(n_failed) == 1
    capture dataqa assert using "`L'", run(g1) expect(alpha beta gamma)
    assert _rc == 9 & "`r(missing)'" == "gamma"
    capture dataqa assert using "`L'", run(nosuchrun)
    assert _rc == 9
    * a run where every invariant passed, and every dataset is present
    dataqa set maskrare ledger("`L'") run(g2)
    _dq_fix
    datacheck, gatesonly isid(id) name(alpha)
    _dq_fix
    replace x = x + 1
    datacheck, gatesonly isid(id)
    dataqa set clear
    capture dataqa assert using "`L'", run(g2) expect(alpha)
    assert _rc == 0
    * ledger_missing_dataset: a deleted gate call is caught
    capture dataqa assert using "`L'", run(g2) expect(alpha beta)
    assert _rc == 9 & "`r(missing)'" == "beta"
    * an invariant downgraded by bare warn still fails the assert
    dataqa set maskrare ledger("`L'") run(g3)
    _dq_fix
    capture datacheck, gatesonly rule("big": x <= 18) warn name(alpha)
    dataqa set clear
    capture dataqa assert using "`L'", run(g3)
    assert _rc == 9
}
_dq `=_rc' "dataqa assert: halts on a failed invariant, a warned invariant, a missing dataset, or no rows"
macro drop DATAMAP_DQ

**# dataqa export: the release copy refuses small cells

capture noisily {
    capture erase "`EX'"
    * g2 ran under maskrare with no small cell shown: exported
    dataqa export using "`L'", run(g2) saving("`EX'")
    preserve
    use "`EX'", clear
    assert _N == 2 & masked == 1
    restore
    capture dataqa export using "`L'", run(g2) saving("`EX'")
    assert _rc == 602
    * an unmasked call is refused
    capture erase "`L2'"
    _dq_fix
    datacheck, gatesonly isid(id) ledger("`L2'", run(u1))
    capture dataqa export using "`L2'", run(u1) saving("`EX'") replace
    assert _rc == 459
    * a mask below the house threshold that prints 4 is refused
    _dq_fix
    capture datacheck, gatesonly rule("big": x <= 16) maskrare mincell(3) warn ledger("`L2'", run(u2))
    capture dataqa export using "`L2'", run(u2) saving("`EX'") replace
    assert _rc == 459
    * threshold() only raises the floor: a mask of 3 is refused at threshold(3)
    capture dataqa export using "`L2'", run(u2) saving("`EX'") replace threshold(3)
    assert _rc == 459
    * a masked row that kept observed_num (a leak) is refused
    _dq_fix
    capture datacheck, gatesonly rule("big": x <= 18) maskrare warn ledger("`L2'", run(u3))
    capture dataqa export using "`L2'", run(u3) saving("`EX'") replace
    assert _rc == 0
    preserve
    use "`L2'", clear
    replace observed_num = 2 if run == "u3" & obs_masked == 1
    save "`L2'", replace
    restore
    capture dataqa export using "`L2'", run(u3) saving("`EX'") replace
    assert _rc == 459
    * a scope with a literal identifier is blanked in the release copy
    _dq_fix
    capture datacheck if id != 1234, gatesonly isid(id) maskrare ledger("`L2'", run(u4))
    _dq_fix
    capture datacheck if x > 2, gatesonly isid(id) maskrare ledger("`L2'", run(u4))
    dataqa export using "`L2'", run(u4) saving("`EX'") replace
    assert r(n_scope_dropped) == 1
    preserve
    use "`EX'", clear
    assert scope[1] == "" & scope[2] == "x > 2"
    restore
}
_dq `=_rc' "dataqa export: writes a masked run; refuses unmasked, low-mask, small-count and leaked rows"

**# dataqa compare: drift against a baseline run

capture noisily {
    capture erase "`L2'"
    clear
    set obs 100
    gen long id = _n
    gen double x = _n
    datacheck, gatesonly isid(id) stat(mean x 0 100) name(cohort) signature ledger("`L2'", run(b0))
    local sig0 "`r(signature)'"
    assert "`r(ledger)'" == "`L2'"
    quietly datasignature
    assert "`sig0'" == "`r(datasignature)'" & "`sig0'" != ""
    * 4% fewer rows: within ntol(0.05)
    drop in 1/4
    datacheck, gatesonly isid(id) stat(mean x 0 100) name(cohort) signature ledger("`L2'", run(b1))
    capture log close _dql
    log using "`lg'", text replace name(_dql)
    dataqa compare using "`L2'", run(b1) baseline(b0)
    local f1 = r(n_flags)
    log close _dql
    * N within tolerance; the mean moved from 50.5 to 52.5 (3.96%, within
    * stattol(0.05)); only the signature changed
    assert `f1' == 1
    _dq_count "`lg'" "signature  cohort"
    assert r(n) == 1
    _dq_count "`lg'" "  N  "
    assert r(n) == 0
    * 6% fewer rows than the baseline: flagged for each gate row
    clear
    set obs 94
    gen long id = _n
    gen double x = _n + 3
    datacheck, gatesonly isid(id) name(cohort) ledger("`L2'", run(b2))
    capture log close _dql
    log using "`lg'", text replace name(_dql)
    dataqa compare using "`L2'", run(b2) baseline(b0)
    local f2 = r(n_flags)
    log close _dql
    _dq_count "`lg'" "N  cohort isid(id): 100 -> 94 (-6.0%)"
    assert r(n) == 1
    * the stat() gate of the baseline is absent from b2
    _dq_count "`lg'" "absent  cohort stat(mean x)"
    assert r(n) == 1
    assert `f2' == 2
    * no baseline: a note, exit 0
    dataqa compare using "`L2'", run(b2)
    assert r(n_flags) == 0
    capture dataqa compare using "`L2'", run(b2) baseline(b0) ntol(-1)
    assert _rc == 198
}
_dq `=_rc' "dataqa compare: 4% N drift passes, 6% flags; stat drift, signature change and absent gates flagged"

**# ledger robustness

capture noisily {
    clear
    set obs 3
    gen x = 1
    local notl "`c(tmpdir)'/dq_not_a_ledger.dta"
    save "`notl'", replace
    _dq_fix
    capture datacheck, gatesonly isid(id) ledger("`notl'")
    assert _rc == 610
    * the verdict and r() are still set when the ledger write fails
    assert r(n_checks) == 1
    capture dataqa report using "`notl'"
    assert _rc == 610
    capture dataqa report using "`c(tmpdir)'/dq_no_such_ledger.dta"
    assert _rc == 601
    capture erase "`notl'"
    * profile-only calls write no rows
    capture erase "`L2'"
    _dq_fix
    quietly datacheck, ledger("`L2'")
    capture confirm file "`L2'"
    assert _rc == 601
}
_dq `=_rc' "ledger: a non-ledger file is refused (r(610)) without losing the verdict; no gates, no rows"

* Items 1 and 2 of the 2026-09-30 dataqa findings.  Each ledger lives in its
* own tempfile-named directory, so a concurrent run of this suite cannot
* share it.  An earlier block that failed inside preserve would leave the
* data preserved; restore it so these blocks run on their own.
capture restore
tempfile dqbase
local DQD "`dqbase'_d"
capture mkdir "`DQD'"
capture mkdir "`DQD'/sub"

**# latest row per gate: a fixed rerun under the same run label (item 1)

local L3 "`DQD'/rerun.dta"
capture erase "`L3'"
capture noisily {
    dataqa set maskrare mincell(5) ledger("`L3'") run(r1)
    * the gate fails, the data are fixed, the same call is rerun
    _dq_fix
    replace x = . in 1/3
    capture datacheck, gatesonly name(auto) notmissing(x)
    assert _rc == 9
    _dq_fix
    datacheck, gatesonly name(auto) notmissing(x)
    capture dataqa assert, expect(auto)
    assert _rc == 0
    assert r(n_failed) == 0 & r(N) == 1 & r(n_superseded) == 1
    dataqa report
    assert r(N) == 1 & r(n_failed) == 0 & r(n_superseded) == 1
    * one call writes two rows under one key (heaping's review row and its
    * gate row); both are kept, and the failed gate still halts.  10 of 20
    * dates fall on 1 January against max(0.1); the other 10 run from 17 to
    * 26 June, so no share is masked.
    clear
    set obs 20
    gen dt = td(06jun2020) + _n
    replace dt = td(01jan2021) in 1/10
    format dt %td
    capture datacheck, gatesonly name(dates) heaping(dt, max(0.1))
    assert _rc == 9
    capture dataqa assert
    assert _rc == 9 & r(n_failed) == 1
    dataqa report
    assert r(N) == 3 & r(n_failed) == 1
    * a call without a dataset name is never superseded: a pass on other
    * unnamed data leaves the earlier failure standing
    dataqa set maskrare mincell(5) ledger("`L3'") run(r2)
    _dq_fix
    replace x = . in 1/3
    capture datacheck, gatesonly notmissing(x)
    _dq_fix
    datacheck, gatesonly notmissing(x)
    capture dataqa assert
    assert _rc == 9 & r(n_failed) == 1 & r(n_superseded) == 0
    * export keeps one row per gate: only the fixed rerun leaves
    dataqa set maskrare mincell(5) ledger("`L3'") run(r1)
    dataqa export, saving("`DQD'/rerun_release.dta") replace
    assert r(N) == 3 & r(n_superseded) == 1
    preserve
    use "`DQD'/rerun_release.dta", clear
    assert _N == 3
    count if dataset == "auto"
    assert r(N) == 1 & status[1] == "pass"
    restore
    dataqa set clear
}
_dq `=_rc' "latest row per gate: a fixed rerun passes assert and counts once; two rows of one call and unnamed calls are kept"
macro drop DATAMAP_DQ

**# dataqa set replace: a rerun starts its run afresh (item 1)

local L4 "`DQD'/replace.dta"
capture erase "`L4'"
capture noisily {
    * run r0 is a baseline in the same ledger
    dataqa set maskrare ledger("`L4'") run(r0)
    _dq_fix
    datacheck, gatesonly isid(id) name(alpha)
    * session 1 of run r1: alpha fails, beta passes
    dataqa set maskrare ledger("`L4'") run(r1)
    _dq_fix
    capture datacheck, gatesonly rule("big": x <= 18) name(alpha)
    assert _rc == 9
    _dq_fix
    datacheck, gatesonly isid(id) name(beta)
    * session 2 without replace: a note, and the rows are kept
    capture log close _dql
    log using "`lg'", text replace name(_dql)
    dataqa set maskrare ledger("`L4'") run(r1)
    log close _dql
    _dq_count "`lg'" "note: ledger already holds 2 row(s) of run r1; they are read with this session's rows; add replace to start the run afresh"
    assert r(n) == 1
    preserve
    use "`L4'", clear
    assert _N == 3
    keep if run == "r0"
    quietly datasignature
    local sig0 "`r(datasignature)'"
    restore
    * session 2 with replace: alpha is fixed and the call on beta was
    * deleted by mistake
    capture log close _dql
    log using "`lg'", text replace name(_dql)
    dataqa set maskrare ledger("`L4'") run(r1) replace
    local nrem = r(n_removed)
    log close _dql
    assert `nrem' == 2
    _dq_count "`lg'" "dataqa set: 2 row(s) of run r1 removed from `L4'"
    assert r(n) == 1
    * replace is an action, not a stored default
    assert `"$DATAMAP_DQ"' == `"maskrare ledger("`L4'") run(r1)"'
    _dq_fix
    datacheck, gatesonly rule("big": x <= 20) name(alpha)
    preserve
    use "`L4'", clear
    count if run == "r1"
    assert r(N) == 1
    assert family == "rule" & status == "pass" & seq == 1 if run == "r1"
    * every r0 row is kept
    keep if run == "r0"
    assert _N == 1
    quietly datasignature
    assert "`r(datasignature)'" == "`sig0'"
    restore
    capture dataqa assert, expect(alpha beta)
    assert _rc == 9 & "`r(missing)'" == "beta" & r(n_failed) == 0
    * replace needs both ledger() and run(); the defaults stay as they were
    capture dataqa set maskrare ledger("`L4'") replace
    assert _rc == 198
    capture dataqa set maskrare replace
    assert _rc == 198
    assert `"$DATAMAP_DQ"' == `"maskrare ledger("`L4'") run(r1)"'
    * a file that is not a ledger is left untouched
    clear
    set obs 3
    gen run = "r1"
    save "`DQD'/notled.dta", replace
    quietly datasignature
    local sign "`r(datasignature)'"
    capture dataqa set ledger("`DQD'/notled.dta") run(r1) replace
    assert _rc == 610
    use "`DQD'/notled.dta", clear
    quietly datasignature
    assert "`r(datasignature)'" == "`sign'" & _N == 3
    dataqa set clear
}
_dq `=_rc' "dataqa set replace: removes only run() rows, keeps other runs, needs ledger() and run(); a note without it"
macro drop DATAMAP_DQ

**# the gate key includes the expectation (review D1, D2)

local L6 "`DQD'/expect.dta"
capture erase "`L6'"
capture noisily {
    * D1: a failed inrange(x 0 10) is not cleared by rerunning the gate
    * with wider bounds; that would widen an invariant in code
    _dq_fix
    capture datacheck, gatesonly inrange(x 0 10) name(cohort) ledger("`L6'", run(r1))
    assert _rc == 9
    datacheck, gatesonly inrange(x 0 100) name(cohort) ledger("`L6'", run(r1))
    capture dataqa assert using "`L6'", run(r1)
    assert _rc == 9 & r(n_failed) == 1 & r(n_superseded) == 0
    dataqa report using "`L6'", run(r1)
    assert r(n_failed) == 1 & r(N) == 2
    * the same bounds rerun on fixed data still supersede the failure
    replace x = min(x, 10)
    datacheck, gatesonly inrange(x 0 10) name(cohort) ledger("`L6'", run(r1))
    capture dataqa assert using "`L6'", run(r1)
    assert _rc == 0 & r(n_failed) == 0 & r(n_superseded) == 1
    * D2: two entries on one variable are compared one by one.  The
    * baseline has [0, 10] and [0, 100]; a run with only [0, 100] reports
    * [0, 10] absent
    _dq_fix
    capture datacheck, gatesonly inrange(x 0 10 \ x 0 100) name(cohort) ledger("`L6'", run(b0))
    datacheck, gatesonly inrange(x 0 100) name(cohort) ledger("`L6'", run(b1))
    capture log close _dql
    log using "`lg'", text replace name(_dql)
    dataqa compare using "`L6'", run(b1) baseline(b0)
    local f1 = r(n_flags)
    log close _dql
    assert `f1' == 1
    _dq_count "`lg'" "absent  cohort inrange(x), expected"
    assert r(n) == 1
    * 6 of 20 rows fewer: each entry's N change is flagged, not one for both
    drop in 1/6
    replace x = min(x, 10)
    datacheck, gatesonly inrange(x 0 10 \ x 0 100) name(cohort) ledger("`L6'", run(b2))
    dataqa compare using "`L6'", run(b2) baseline(b0)
    assert r(n_flags) == 2
}
_dq `=_rc' "gate key includes the expectation: wider bounds cannot clear a failure; compare links each entry"
capture erase "`L6'"

**# per-level fail rows are superseded by a passing rerun (review B1)

local L7 "`DQD'/levels.dta"
capture erase "`L7'"
capture noisily {
    * events(): level 2 has 5 events against min(10); its fail row carries
    * "lv = 2" in grp, the passing rerun's row has no level
    clear
    set obs 40
    gen byte lv = ceil(_n / 20)
    gen byte ev = _n <= 25
    capture datacheck, gatesonly name(ev) events(ev: lv, min(10)) ledger("`L7'", run(r1))
    assert _rc == 9
    replace ev = 1
    datacheck, gatesonly name(ev) events(ev: lv, min(10)) ledger("`L7'", run(r1))
    capture dataqa assert using "`L7'", run(r1)
    assert _rc == 0 & r(n_failed) == 0 & r(n_superseded) == 1
    * groupstat() band: group 2's mean fails with "by(g) = 2" in grp
    clear
    set obs 40
    gen byte g = ceil(_n / 20)
    gen double x = cond(g == 2, 10, 1)
    capture datacheck, gatesonly name(gs) groupstat(mean x, by(g) band(0 2)) warn ledger("`L7'", run(r2))
    dataqa report using "`L7'", run(r2)
    assert r(n_warned) == 1
    replace x = 1
    datacheck, gatesonly name(gs) groupstat(mean x, by(g) band(0 2)) warn ledger("`L7'", run(r2))
    dataqa report using "`L7'", run(r2)
    assert r(n_warned) == 0 & r(n_superseded) == 2
    * a datacheck by() call keeps one row per by() group from its latest
    * call: notmissing fails in both foreign groups, then passes
    sysuse auto, clear
    capture datacheck, gatesonly name(auto) by(foreign) notmissing(rep78) ledger("`L7'", run(r3))
    assert _rc == 9
    replace rep78 = 3 if missing(rep78)
    datacheck, gatesonly name(auto) by(foreign) notmissing(rep78) ledger("`L7'", run(r3))
    capture dataqa assert using "`L7'", run(r3)
    assert _rc == 0 & r(N) == 2 & r(n_superseded) == 2
    * the same gate under another by() grouping is another gate
    sysuse auto, clear
    capture datacheck, gatesonly name(auto) by(foreign) notmissing(rep78) ledger("`L7'", run(r4))
    datacheck, gatesonly name(auto) notmissing(mpg) ledger("`L7'", run(r4))
    replace rep78 = 3 if missing(rep78)
    datacheck, gatesonly name(auto) notmissing(rep78) ledger("`L7'", run(r4))
    capture dataqa assert using "`L7'", run(r4)
    assert _rc == 9 & r(n_failed) == 2 & r(n_superseded) == 0
}
_dq `=_rc' "per-level fail rows (events, groupstat band, by() groups) are superseded by a passing rerun; another grouping is not"
capture erase "`L7'"

**# dataqa export: saving() may not name the ledger it reads (item 2)

local L5 "`DQD'/self.dta"
capture erase "`L5'"
capture noisily {
    _dq_fix
    datacheck, gatesonly isid(id) maskrare name(alpha) ledger("`L5'", run(s1))
    _dq_fix
    datacheck, gatesonly isid(id) maskrare name(beta) ledger("`L5'", run(s2))
    preserve
    use "`L5'", clear
    local n0 = _N
    quietly datasignature
    local sig0 "`r(datasignature)'"
    restore
    assert `n0' == 2
    quietly cd "`DQD'"
    local nbad = 0
    foreach u in "self.dta" "`L5'" {
        foreach s in "self.dta" "`L5'" "./self.dta" "./self" "sub/../self.dta" "`DQD'/./sub/../self.dta" {
            capture dataqa export using "`u'", run(s1) saving("`s'") replace
            if _rc != 602 {
                display as error "  export using `u' saving(`s'): rc = " _rc
                local ++nbad
            }
        }
    }
    if inlist(c(os), "Windows", "MacOSX") {
        * these file systems ignore case; Windows also reads \ as /
        capture dataqa export using "self.dta", run(s1) saving("SELF.dta") replace
        if _rc != 602 local ++nbad
        if c(os) == "Windows" {
            capture dataqa export using "self.dta", run(s1) saving(".\sub\..\self.dta") replace
            if _rc != 602 local ++nbad
        }
    }
    else {
        * a case-sensitive file system: SELF.dta is another file
        capture erase "SELF.dta"
        dataqa export using "self.dta", run(s1) saving("SELF.dta") replace
        erase "SELF.dta"
    }
    assert `nbad' == 0
    preserve
    use "`L5'", clear
    quietly datasignature
    assert _N == `n0' & "`r(datasignature)'" == "`sig0'"
    restore
    * a distinct release copy is written; the working ledger is unchanged
    dataqa export using "self.dta", run(s1) saving("self_release.dta") replace
    assert r(N) == 1
    preserve
    use "self_release.dta", clear
    assert _N == 1 & run == "s1"
    use "`L5'", clear
    quietly datasignature
    assert _N == `n0' & "`r(datasignature)'" == "`sig0'"
    restore
}
local rc = _rc
quietly cd "`qa_dir'"
_dq `rc' "dataqa export: saving() naming the source ledger (relative, absolute, ./, dir/.., case) is r(602); the ledger is unchanged"
capture erase "`DQD'/self_release.dta"
foreach f in rerun rerun_release replace notled self {
    capture erase "`DQD'/`f'.dta"
}
capture rmdir "`DQD'/sub"
capture rmdir "`DQD'"

foreach f in "`L'" "`L2'" "`MD'" "`EX'" {
    capture erase `f'
}
macro drop DATAMAP_DQ

* ============================================================
* Summary
* ============================================================
display as result "Results: $PASS/$TC passed, $FAIL failed"
if $FAIL > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_dataqa tests=$TC pass=$PASS fail=$FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_dataqa tests=$TC pass=$PASS fail=$FAIL"
exit 0
