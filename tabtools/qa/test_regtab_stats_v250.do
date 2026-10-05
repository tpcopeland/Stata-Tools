* test_regtab_stats_v250.do - regtab stats(e(), maskwith()): rows declared
* to give a masked count back are masked with it (complementary masking
* within one table)
*
* Fixture: models whose stats() rows hold test-owned collection results
* (collect get name = (#), tags(cmdset[#])), so every value per model is
* known in advance and the expected cell is written out by hand: "<5" where
* the row's own mincell() masks it, an en dash where a member of its
* maskwith() group is masked in that model, the formatted number otherwise.
* Eleven models check that a model's cells are matched to its column through
* the renderer's numeric cmdset order (_regtab_cmdsets), not the text order
* of collect levelsof (1 10 11 2 ...).

clear all
set more off
set varabbrev off
version 17.0

capture log close _rs250
log using "test_regtab_stats_v250.log", replace text name(_rs250)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/rs250_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"
do "`qa_dir'/_qa_state.do"

local dash = uchar(8211)

* The cell of row `label' in column `col' of frame `fr', in r(cell).
capture program drop _rs250_cell
program define _rs250_cell, rclass
    version 17.0
    args fr label col
    frame `fr' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(rowlabel) == `"`label'"'
        if r(N) != 1 {
            display as error `"frame `fr': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(rowlabel) == `"`label'"', meanonly
        local cell = strtrim(`col'[r(min)])
    }
    return local cell `"`cell'"'
end

* Assert the cell of row `label', model column `m' (c1, c4, c7, ... in a
* three-column layout) is `want'.
capture program drop _rs250_is
program define _rs250_is
    version 17.0
    args fr label m want
    local col = "c" + string((`m' - 1) * 3 + 1)
    _rs250_cell `fr' `"`label'"' `col'
    if `"`r(cell)'"' != `"`want'"' {
        display as error `"`fr' "`label'" model `m': "`r(cell)'", expected "`want'""'
        exit 9
    }
end

* Three Cox models with test-owned counts per model:
*   ev    3 10 12    events, mincell(5) masks model 1
*   ppl  50 60 14    people
*   noev 47 50  2    people without an event, mincell(5) masks model 3
*   zr    0  0  0    a zero count in the group
capture program drop _rs250_fix
program define _rs250_fix
    version 17.0
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    collect clear
    quietly collect: stcox i.drug
    quietly collect: stcox i.drug age
    quietly collect: stcox age
    local ev 3 10 12
    local ppl 50 60 14
    local noev 47 50 2
    forvalues k = 1/3 {
        foreach r in ev ppl noev {
            local v : word `k' of ``r''
            quietly collect get `r' = (`v'), tags(cmdset[`k'])
        }
        quietly collect get zr = (0), tags(cmdset[`k'])
    }
end

**# M1: a declared group is masked together, in every sink
local ++test_count
capture noisily {
    _rs250_fix
    local csv "`output_dir'/rs250_m1.csv"
    local md "`output_dir'/rs250_m1.md"
    local book "`output_dir'/rs250_m1.xlsx"
    capture erase "`book'"
    regtab, stats(e(ev, mincell(5))="Events" e(ppl)="People" ///
        e(noev, mincell(5) maskwith(ev))="Without an event") ///
        frame(_rs1, replace flat) csv("`csv'") markdown("`md'") xlsx("`book'") sheet("M1")
    assert r(N_stats_masked) == 2
    assert r(N_stats_linked) == 2
    * r() keeps every number
    assert r(e_ev_1) == 3 & r(e_noev_1) == 47 & r(e_ev_3) == 12 & r(e_noev_3) == 2
    * model 1: events masked, so people without an event (people - events)
    * is withheld; people stay
    _rs250_is _rs1 "Events" 1 "<5"
    _rs250_is _rs1 "People" 1 "50"
    _rs250_is _rs1 "Without an event" 1 "`dash'"
    * model 2: nothing masked
    _rs250_is _rs1 "Events" 2 "10"
    _rs250_is _rs1 "Without an event" 2 "50"
    * model 3: the dependent row is the small one; events are withheld
    _rs250_is _rs1 "Events" 3 "`dash'"
    _rs250_is _rs1 "People" 3 "14"
    _rs250_is _rs1 "Without an event" 3 "<5"
    * the other sinks carry the same text
    _v_line "`csv'" "Events,<5,,,10,,,`dash',," 1
    _v_line "`csv'" "Without an event,`dash',,,50,,,<5,," 1
    _v_line "`md'" "| Without an event | `dash' |  |  | 50 |  |  | \<5 |  |  |" 1
    _v_line "`md'" "| Events | \<5 |  |  | 10 |  |  | `dash' |  |  |" 1
    _v_facts "`book'" "M1"
    _v_grep "$V230_RES" "^value [A-Z]+[0-9]+ `dash'$"
    assert r(n) == 2
    _v_grep "$V230_RES" "^value [A-Z]+[0-9]+ 47$"
    assert r(n) == 0
    _v_grep "$V230_RES" "^value [A-Z]+[0-9]+ 12$"
    assert r(n) == 0
    * undeclared, nothing is assumed: the same table without maskwith()
    regtab, stats(e(ev, mincell(5))="Events" e(ppl)="People" ///
        e(noev, mincell(5))="Without an event") frame(_rs1b, replace flat)
    assert r(N_stats_masked) == 2
    capture confirm scalar r(N_stats_linked)
    assert _rc != 0
    _rs250_is _rs1b "Without an event" 1 "47"
    _rs250_is _rs1b "Events" 3 "12"
}
if _rc == 0 {
    display as result "  PASS: M1 maskwith() masks the declared group in every sink"
    local ++pass_count
}
else {
    display as error "  FAIL: M1 maskwith() group masking (rc=`=_rc')"
    local ++fail_count
}

**# M2: groups join through shared names; zero is withheld; pairs
local ++test_count
capture noisily {
    _rs250_fix
    * ppl -> noev and zr -> noev: one group {ppl, noev, zr}; ev stays out
    regtab, stats(e(ev, mincell(5))="Events" e(ppl, maskwith(noev))="People" ///
        e(noev, mincell(5))="Without an event" e(zr, maskwith(noev))="Zero") ///
        frame(_rs2, replace flat)
    local nlink = r(N_stats_linked)
    * model 3: noev masked -> ppl and the zero count are withheld
    _rs250_is _rs2 "Without an event" 3 "<5"
    _rs250_is _rs2 "People" 3 "`dash'"
    _rs250_is _rs2 "Zero" 3 "`dash'"
    _rs250_is _rs2 "Events" 3 "12"
    * model 1: ev is masked, but ev is in no group
    _rs250_is _rs2 "Events" 1 "<5"
    _rs250_is _rs2 "People" 1 "50"
    _rs250_is _rs2 "Zero" 1 "0"
    assert `nlink' == 2
    * a pair: its parts are masked alone unless the pair declares a link
    regtab, stats(e(ppl|ev, mincell(5))="People (events)") frame(_rs2b, replace flat)
    _rs250_is _rs2b "People (events)" 1 "50 (<5)"
    regtab, stats(e(ppl|ev, mincell(5) maskwith(ev))="People (events)") frame(_rs2b, replace flat)
    assert r(N_stats_masked) == 1 & r(N_stats_linked) == 1
    _rs250_is _rs2b "People (events)" 1 "`dash' (<5)"
    _rs250_is _rs2b "People (events)" 2 "60 (10)"
    * a pair part linked from another row
    regtab, stats(e(ppl|ev, mincell(5))="People (events)" ///
        e(noev, maskwith(ev))="Without an event") frame(_rs2c, replace flat)
    _rs250_is _rs2c "People (events)" 1 "50 (<5)"
    _rs250_is _rs2c "Without an event" 1 "`dash'"
    _rs250_is _rs2c "Without an event" 3 "2"
}
if _rc == 0 {
    display as result "  PASS: M2 joined groups, zero withheld, pairs linked only on request"
    local ++pass_count
}
else {
    display as error "  FAIL: M2 group closure and pairs (rc=`=_rc')"
    local ++fail_count
}

**# M3: eleven models: each column's masking is its own model's
* ev_k = k with mincell(5) masks the models with cmdset 1-4; x_k = 100 + k
* is linked to ev. Columns follow the numeric cmdset order; collect
* levelsof lists the levels as text (1 10 11 2 ...).
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    forvalues k = 1/11 {
        quietly collect: regress price mpg if _n <= 30 + `k'
        quietly collect get evk = (`k'), tags(cmdset[`k'])
        quietly collect get xk = (100 + `k'), tags(cmdset[`k'])
    }
    quietly collect levelsof cmdset
    local textorder `"`s(levels)'"'
    _regtab_cmdsets
    local colorder `"`_cs_levels'"'
    assert `"`colorder'"' == "1 2 3 4 5 6 7 8 9 10 11"
    assert `"`textorder'"' != `"`colorder'"'
    regtab, stats(e(N) e(evk, mincell(5))="Events" e(xk, maskwith(evk))="Linked") ///
        frame(_rs3, replace flat)
    assert r(N_stats_masked) == 4 & r(N_stats_linked) == 4
    forvalues k = 1/11 {
        local rx`k' = r(e_xk_`k')
    }
    forvalues m = 1/11 {
        local k : word `m' of `colorder'
        * the column is model k's: its e(N) is 30 + k
        _rs250_is _rs3 "N" `m' "`=30 + `k''"
        if `k' < 5 {
            _rs250_is _rs3 "Events" `m' "<5"
            _rs250_is _rs3 "Linked" `m' "`dash'"
        }
        else {
            _rs250_is _rs3 "Events" `m' "`k'"
            _rs250_is _rs3 "Linked" `m' "`=100 + `k''"
        }
        assert `rx`k'' == 100 + `k'
    }
}
if _rc == 0 {
    display as result "  PASS: M3 eleven models: masking follows each model's column"
    local ++pass_count
}
else {
    display as error "  FAIL: M3 eleven models (rc=`=_rc')"
    local ++fail_count
}

**# M4: refusals
local ++test_count
capture noisily {
    _rs250_fix
    * control: a valid link runs
    regtab, stats(e(ev, mincell(5)) e(noev, maskwith(ev)))
    assert r(N_stats_linked) == 1
    capture noisily regtab, stats(e(ev, mincell(5)) e(noev, maskwith(nosuch)))
    assert _rc == 198
    capture noisily regtab, stats(e(ev, mincell(5)) e(noev, maskwith(1bad)))
    assert _rc == 198
    * a name that is not a stats() item, even if the collection holds it
    capture noisily regtab, stats(e(noev, maskwith(ppl)))
    assert _rc == 198
    capture noisily regtab, stats(e(noev, maskwith()))
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: M4 maskwith() refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: M4 refusals (rc=`=_rc')"
    local ++fail_count
}

**# M5: one statistic, one threshold across the items that name it
* stats(e(ev, mincell(5)) e(tot|ev)) used to print "<5" in one row and
* "13 (3)" in the other. Every occurrence of a name now takes the strictest
* mincell() any item gives it. Expected cells are written out by hand.
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    collect clear
    quietly collect: stcox i.drug
    quietly collect get ev = (3), tags(cmdset[1])
    quietly collect get tot = (13), tags(cmdset[1])
    quietly collect get ev4 = (4), tags(cmdset[1])
    quietly collect get ev_count_for_the_first_cohort_a = (2), tags(cmdset[1])
    quietly collect get ev_count_for_the_first_cohort_b = (2), tags(cmdset[1])
    quietly collect: stcox i.drug age
    quietly collect get ev = (30), tags(cmdset[2])
    quietly collect get tot = (40), tags(cmdset[2])
    quietly collect get ev4 = (4), tags(cmdset[2])
    regtab, stats(e(ev, mincell(5))="E" e(tot|ev)="T (E)" e(ev|tot)="E (T)") frame(_rs5, replace flat)
    local nm = r(N_stats_masked)
    _rs250_is _rs5 "E" 1 "<5"
    _rs250_is _rs5 "T (E)" 1 "13 (<5)"
    _rs250_is _rs5 "E (T)" 1 "<5 (13)"
    _rs250_is _rs5 "T (E)" 2 "40 (30)"
    assert `nm' == 3
    * the strictest of two thresholds wins, in either order
    regtab, stats(e(ev4, mincell(3))="A" e(ev4|tot, mincell(5))="B") frame(_rs5, replace flat)
    _rs250_is _rs5 "A" 1 "<5"
    _rs250_is _rs5 "B" 1 "<5 (13)"
    regtab, stats(e(ev4|tot, mincell(5))="B" e(ev4, mincell(3))="A") frame(_rs5, replace flat)
    _rs250_is _rs5 "A" 2 "<5"
    * names that share a long prefix keep their own thresholds
    regtab, stats(e(ev_count_for_the_first_cohort_a, mincell(3))="LA" ///
        e(ev_count_for_the_first_cohort_b)="LB") frame(_rs5, replace flat)
    _rs250_is _rs5 "LA" 1 "<3"
    _rs250_is _rs5 "LB" 1 "2"
    * no mincell() anywhere: nothing masked
    regtab, stats(e(ev) e(tot|ev)) frame(_rs5, replace flat)
    _rs250_is _rs5 "tot (ev)" 1 "13 (3)"
}
if _rc == 0 {
    display as result "  PASS: M5 a statistic takes its strictest mincell() in every item"
    local ++pass_count
}
else {
    display as error "  FAIL: M5 one threshold per statistic (rc=`=_rc')"
    local ++fail_count
}

**# M6: a maskwith() group without any mincell() says it masks nothing
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    collect clear
    quietly collect: stcox i.drug
    quietly collect get ev = (3), tags(cmdset[1])
    quietly collect get tot = (13), tags(cmdset[1])
    tempfile nlog
    local ls0 = c(linesize)
    set linesize 255
    quietly log using "`nlog'", text replace name(_rs6)
    regtab, stats(e(ev) e(tot, maskwith(ev)))
    quietly log close _rs6
    mata: _l = cat(st_local("nlog")); st_local("n6", strofreal(sum(strpos(_l, ///
        "(regtab: stats(): no mincell() is given for the maskwith() group ev tot, so nothing in it is masked)") :> 0)))
    assert `n6' == 1
    * a mincell() on any member, also through another item, silences it
    quietly log using "`nlog'", text replace name(_rs6)
    regtab, stats(e(ev, mincell(5)) e(tot, maskwith(ev)))
    regtab, stats(e(tot|ev, mincell(5)) e(tot, maskwith(ev)))
    quietly log close _rs6
    mata: _l = cat(st_local("nlog")); st_local("n6", strofreal(sum(strpos(_l, "masks nothing") :> 0) + ///
        sum(strpos(_l, "so nothing in it is masked") :> 0)))
    assert `n6' == 0
    mata: mata drop _l
    set linesize `ls0'
}
if _rc == 0 {
    display as result "  PASS: M6 maskwith() group without mincell(): one note"
    local ++pass_count
}
else {
    display as error "  FAIL: M6 maskwith() note (rc=`=_rc')"
    local ++fail_count
}
capture log close _rs6
capture set linesize `ls0'

**# K1: frame(, flat keys): each stats() row's _term is stat:<id>, unique
* The ids, written out here: the built-in word as documented (n, F, ...), a
* generic item as typed without its options or label (e(N), e(a|b)), and
* text(#) for the #th text() item. stats(r2 e(r2)) and stats(F e(F)) show
* why a bare name would not do: the built-in and the e() row would share it.
* A requested built-in no model reports (groups) has no row and no id, and
* addrow(..., after()) moves rows without breaking the pairing.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg
    quietly collect get vk = (5), tags(cmdset[1])
    quietly collect get vk = (6), tags(cmdset[2])
    regtab, stats(n r2 F groups e(r2, %6.4f)="R2 again" e(F)="F again" ///
        text("Adj" "Yes" "No") e(N|vk)="N (vk)" text("Data" "auto" "auto")) ///
        addrow("Extra" "a" "b", after(mpg)) frame(_rsk, replace flat keys)
    frame _rsk {
        quietly count if _rowtype == "stat"
        assert r(N) == 8
        local want stat:n stat:r2 stat:F stat:e(r2) stat:e(F) stat:text(1) stat:e(N|vk) stat:text(2)
        local labs `""Observations" "R²" "F statistic" "R2 again" "F again" "Adj" "N (vk)" "Data""'
        local i = 0
        forvalues r = 1/`=_N' {
            if _rowtype[`r'] != "stat" continue
            local ++i
            local w : word `i' of `want'
            local l : word `i' of `labs'
            assert _term[`r'] == "`w'"
            assert strtrim(rowlabel[`r']) == "`l'"
        }
        assert `i' == 8
        * unique over the whole frame, and in order after the addrow() row
        quietly duplicates report _term
        assert r(unique_value) == r(N)
        quietly count if _term == "addrow:1"
        assert r(N) == 1
        * a cell found through its id holds that row's value
        generate long _rn = _n
        quietly summarize _rn if _term == "stat:e(N|vk)", meanonly
        assert strtrim(c1[r(min)]) == "74 (5)" & strtrim(c4[r(min)]) == "74 (6)"
        quietly summarize _rn if _term == "stat:e(F)", meanonly
        assert strtrim(c4[r(min)]) != "" & _state4[r(min)] == "stat"
        drop _rn
    }
    * the masked cells keep their ids; the states say stat
    _rs250_fix
    regtab, stats(e(ev, mincell(5)) e(noev, maskwith(ev))) frame(_rsk2, replace flat keys)
    frame _rsk2 {
        generate long _rn = _n
        quietly summarize _rn if _term == "stat:e(noev)", meanonly
        assert strtrim(c1[r(min)]) == "`dash'" & _state1[r(min)] == "stat"
        quietly summarize _rn if _term == "stat:e(ev)", meanonly
        assert strtrim(c1[r(min)]) == "<5"
    }
}
if _rc == 0 {
    display as result "  PASS: K1 stats() rows keyed stat:<id>, unique and aligned"
    local ++pass_count
}
else {
    display as error "  FAIL: K1 stats() row keys (rc=`=_rc')"
    local ++fail_count
}

**# H1: caller state untouched by a masked table and by a refusal
local ++test_count
capture noisily {
    set varabbrev on
    _rs250_fix
    qa_state_snapshot, tag(rs250)
    regtab, stats(e(ev, mincell(5)) e(noev, maskwith(ev)))
    qa_state_compare, tag(rs250)
    qa_state_snapshot, tag(rs250)
    capture regtab, stats(e(noev, maskwith(nosuch)))
    local call_rc = _rc
    qa_state_compare, tag(rs250)
    assert `call_rc' == 198
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: H1 session fingerprint unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: H1 session fingerprint (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off
foreach f in _rs1 _rs1b _rs2 _rs2b _rs2c _rs3 _rsk _rsk2 _rs5 {
    capture frame drop `f'
}
collect clear
macro drop V230_TOOL V230_RES

display "RESULT: test_regtab_stats_v250 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rs250
if `fail_count' > 0 exit 1
