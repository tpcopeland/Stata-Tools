* test_desctab_v240.do - table1_tc/desctab multi-group SMD (tabtools 2.4.0)
*
* Issue: _take_action/2026-10-05-tabtools-smd-multigroup.md. With 3+ by()
* groups the SMD compared groups 1 and 2 only and every sink but the
* Results window showed a bare "SMD" header.
*
* Oracles (none reads the tabtools code):
*   - hand formulas in this file (summarize, Mata) for the known-answer
*     repro and the two-group identities;
*   - crossval_desctab_smd_v240.py: numpy computation of the population SB
*     (McCaffrey et al. 2013 eq. 5, sec. 4.2 max over groups), the max
*     pairwise SMD (Lopez and Gutman 2017 eq. 27, shared sqrt(mean var)
*     denominator), unweighted, wt() and fweight, and the smdpair() SMD;
*   - crossval_desctab_smd_v240.R: cobalt 4.6.3 bal.tab() (pairwise = FALSE,
*     s.d.denom = "all", unweighted and weighted; pairwise = TRUE,
*     s.d.denom = "pooled", unweighted);
*   - the R twin's published values for its toy data
*     (R tabtools, tests/testthat/test-table1-smdtype.R);
*   - excel() read back with openpyxl (tools/xlsx_facts.py), csv(),
*     markdown() and frame() read back as text/data;
*   - data/desctab_v240_golden_2grp.txt: every sink of four two-group SMD
*     tables, written by _dt240_golden.do from the 2.3.1 code.

clear all
set more off
set varabbrev off
version 17.0

capture log close _dt240
log using "test_desctab_v240.log", replace text name(_dt240)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Pin display state: T2/T10/T11 search captured console logs for messages
* that would wrap differently at another linesize, and T4 compares console
* text with a golden written at linesize 79. Restored at the end.
local _ls0 = c(linesize)
set linesize 79

capture mkdir "output"
local od "output"
local pass_count = 0
local fail_count = 0

quietly do "_dt240_golden.do"

* _dt240_has FILE TEXT: assert FILE contains TEXT (literal, any line).
capture program drop _dt240_has
program define _dt240_has
    version 17.0
    args file text
    confirm file `"`file'"'
    mata: st_local("_hit", strofreal(any(strpos(cat(st_local("file")), st_local("text")))))
    if !`_hit' {
        display as error `"`file' lacks: `text'"'
        exit 9
    }
end

* _dt240_hasnot FILE TEXT
capture program drop _dt240_hasnot
program define _dt240_hasnot
    version 17.0
    args file text
    confirm file `"`file'"'
    mata: st_local("_hit", strofreal(any(strpos(cat(st_local("file")), st_local("text")))))
    if `_hit' {
        display as error `"`file' should not contain: `text'"'
        exit 9
    }
end

* _dt240_oracle FILE STAT VAR: r(value) from an oracle CSV (stat,var,value)
capture program drop _dt240_oracle
program define _dt240_oracle, rclass
    version 17.0
    args file stat var
    preserve
    quietly import delimited using `"`file'"', clear varnames(1) stringcols(_all)
    quietly keep if stat == "`stat'" & var == "`var'"
    if _N != 1 {
        display as error "oracle `stat' `var' not found once in `file'"
        exit 9
    }
    return scalar value = real(value[1])
    restore
end

* The issue's repro: three arms of 50, age N(50,10), N(50,10), N(70,10).
capture program drop _dt240_repro
program define _dt240_repro
    version 17.0
    clear
    quietly set obs 150
    set seed 20261005
    quietly gen str1 arm = cond(_n <= 50, "A", cond(_n <= 100, "B", "C"))
    quietly gen double age = rnormal(cond(arm == "C", 70, 50), 10)
    label variable age "Age"
end

**# T1: known-answer 3-arm repro: the pair SMD is A vs B and says so
capture noisily {
    _dt240_repro
    * hand A vs B SMD (Yang-Dalton eq. 1)
    quietly summarize age if arm == "A"
    local mA = r(mean)
    local vA = r(Var)
    quietly summarize age if arm == "B"
    local mB = r(mean)
    local vB = r(Var)
    quietly summarize age if arm == "C"
    local mC = r(mean)
    local vC = r(Var)
    quietly summarize age
    local mP = r(mean)
    local sP = r(sd)
    local smdAB = abs(`mA' - `mB') / sqrt((`vA' + `vB') / 2)
    local psb = max(abs(`mA' - `mP'), abs(`mB' - `mP'), abs(`mC' - `mP')) / `sP'
    local mx = (max(`mA', `mB', `mC') - min(`mA', `mB', `mC')) / sqrt((`vA' + `vB' + `vC') / 3)
    display as text "  hand: A vs B `smdAB'  PSB `psb'  max pairwise `mx'"

    table1_tc, by(arm) vars(age contn) smd
    assert reldif(el(r(table), 1, 2), `smdAB') < 1e-12
    assert `smdAB' < 0.25
    assert "`r(smdtype)'" == "pair"
    assert `"`r(smdnote)'"' == "SMD compares A vs B only (the first two of 3 groups)."

    table1_tc, by(arm) vars(age contn) smd smdtype(population)
    assert reldif(el(r(table), 1, 2), `psb') < 1e-12
    assert `psb' > 0.5
    assert "`r(smdtype)'" == "population"

    table1_tc, by(arm) vars(age contn) smd smdtype(maxpair)
    assert reldif(el(r(table), 1, 2), `mx') < 1e-12
    assert `mx' > 1.5
}
if _rc == 0 {
    display as result "  PASS: T1 3-arm repro: pair = hand A vs B, PSB and max pairwise flag arm C"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 3-arm repro (rc=`=_rc')"
    local ++fail_count
}

**# T2: every sink names the comparison (pair, population, maxpair)
capture noisily {
    local hdr_pair "SMD (A vs B)"
    local hdr_population "Pop. SB"
    local hdr_maxpair "Max SMD"
    local note_pair "SMD compares A vs B only (the first two of 3 groups)."
    local note_population "Pop. SB: largest absolute difference between a group mean and the overall mean, in overall-sample SDs, across the 3 groups (McCaffrey et al. 2013)."
    local note_maxpair "Max SMD: largest absolute pairwise difference across the 3 groups, in the root-mean of the group variances."
    foreach t in pair population maxpair {
        _dt240_repro
        local f "`od'/dt240_s_`t'"
        foreach x in xlsx csv md con.txt facts.txt {
            capture erase "`f'.`x'"
        }
        capture frame drop dt240_sf
        quietly log using "`f'.con.txt", text replace name(_dt240c) nomsg
        table1_tc, by(arm) vars(age contn) smd smdtype(`t') ///
            footnote("User note.") ///
            excel("`f'.xlsx") sheet("S") csv("`f'.csv") markdown("`f'.md") ///
            frame(dt240_sf)
        assert `"`r(smdnote)'"' == `"`note_`t''"'
        quietly log close _dt240c
        * excel(): read back with openpyxl
        shell python3 tools/xlsx_facts.py "`f'.xlsx" S "`f'.facts.txt"
        _dt240_has "`f'.facts.txt" "value G2 `hdr_`t''"
        _dt240_has "`f'.facts.txt" "User note. `note_`t''"
        * csv() and markdown()
        _dt240_has "`f'.csv" ",`hdr_`t''"
        _dt240_has "`f'.csv" "`note_`t''"
        _dt240_has "`f'.md" "| `hdr_`t'' |"
        _dt240_has "`f'.md" "`note_`t''"
        * console: header in the listing, note above it
        _dt240_has "`f'.con.txt" "`hdr_`t''"
        _dt240_has "`f'.con.txt" "Note: "
        * frame(): header row, variable label and characteristic
        frame dt240_sf {
            assert strtrim(smd_str[1]) == "`hdr_`t''"
            assert "`: variable label smd_str'" == "`hdr_`t''"
            local _ch : char _dta[tabtools_smdnote]
            assert `"`_ch'"' == `"`note_`t''"'
        }
        frame drop dt240_sf
        * clear: the table left in memory carries the header too
        _dt240_repro
        quietly table1_tc, by(arm) vars(age contn) smd smdtype(`t') clear
        assert strtrim(smd_str[1]) == "`hdr_`t''"
    }
}
if _rc == 0 {
    display as result "  PASS: T2 header + footnote in excel/csv/markdown/console/frame/clear and r(smdnote)"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 sink labelling (rc=`=_rc')"
    local ++fail_count
}

**# T3: crossval: Python hand computation and cobalt 4.6.3 (toy data)
capture noisily {
    _dt240_data
    quietly gen str1 grps = grp
    preserve
    keep arm age sex grp w
    quietly export delimited using "`od'/dt240_toy.csv", replace
    restore
    capture erase "`od'/dt240_toy_py.csv"
    capture erase "`od'/dt240_toy_r.csv"
    shell python3 crossval_desctab_smd_v240.py "`od'/dt240_toy.csv" "`od'/dt240_toy_py.csv"
    shell Rscript crossval_desctab_smd_v240.R "`od'/dt240_toy.csv" "`od'/dt240_toy_r.csv"
    confirm file "`od'/dt240_toy_py.csv"
    confirm file "`od'/dt240_toy_r.csv"
    local vars "age contn \ sex bin \ grpn cat"
    local names "age sex grp"
    local ncmp 0
    foreach k in un wt fw {
        local wopt ""
        local wexp ""
        if "`k'" == "wt" local wopt "wt(w)"
        if "`k'" == "fw" local wexp "[fw=w]"
        foreach t in population maxpair {
            local st = cond("`t'" == "population", "pop", "max") + "_`k'"
            table1_tc `wexp', by(arm) vars(`vars') smd smdtype(`t') nopvalue `wopt'
            tempname R
            matrix `R' = r(table)
            local c = colnumb(`R', "smd")
            forvalues j = 1/3 {
                local nm : word `j' of `names'
                local got = `R'[`j', `c']
                _dt240_oracle "`od'/dt240_toy_py.csv" `st' `nm'
                local py = r(value)
                assert !missing(`got') & !missing(`py')
                if reldif(`got', `py') >= 1e-12 {
                    display as error "  `st' `nm': stata `got' python `py'"
                    exit 9
                }
                local ++ncmp
                * cobalt where it computes the same quantity
                if inlist("`st'", "pop_un", "pop_wt") | ("`st'" == "max_un" & "`nm'" != "grp") {
                    _dt240_oracle "`od'/dt240_toy_r.csv" `st' `nm'
                    local rv = r(value)
                    assert !missing(`rv')
                    if reldif(`got', `rv') >= 1e-12 {
                        display as error "  `st' `nm': stata `got' cobalt `rv'"
                        exit 9
                    }
                    local ++ncmp
                }
            }
        }
    }
    display as text "  `ncmp' oracle comparisons"
    assert `ncmp' == 26
    * the R twin's published values (same toy data)
    table1_tc, by(arm) vars(age contn \ sex bin) smd smdtype(population) nopvalue
    assert reldif(el(r(table), 1, 1), 0.879755808022535) < 1e-12
    assert reldif(el(r(table), 2, 1), 0.639039154296497) < 1e-12
    table1_tc, by(arm) vars(age contn \ sex bin) smd smdtype(maxpair) nopvalue
    assert reldif(el(r(table), 1, 1), 2.387998740048635) < 1e-12
    assert reldif(el(r(table), 2, 1), 1.104315260748465) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T3 PSB and max pairwise = numpy (un/wt/fw) and cobalt; R twin values"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 crossval (rc=`=_rc')"
    local ++fail_count
}

**# T4: two-group output byte-identical to 2.3.1 in every sink
capture noisily {
    capture erase "`od'/dt240_2grp_now.txt"
    * the dump pins its own display state: run it from a different linesize
    * and check the caller's value comes back
    set linesize 132
    _dt240_dump2 "`od'/dt240_2grp_now.txt"
    assert c(linesize) == 132
    set linesize 79
    mata: st_local("_same", strofreal(cat("`od'/dt240_2grp_now.txt") == cat("data/desctab_v240_golden_2grp.txt")))
    if !`_same' {
        shell diff "`od'/dt240_2grp_now.txt" "data/desctab_v240_golden_2grp.txt" | head -40
        exit 9
    }
}
if _rc == 0 {
    display as result "  PASS: T4 two-group console/r(table)/xlsx/csv/md/frame identical to 2.3.1"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 two-group golden (rc=`=_rc')"
    local ++fail_count
}

**# T5: two groups: maxpair is |pair| (un/wt/fw, all types); no note for pair
capture noisily {
    foreach k in un wt fw {
        _dt240_data
        quietly keep if arm != "C"
        local wopt ""
        local wexp ""
        if "`k'" == "wt" local wopt "wt(w)"
        if "`k'" == "fw" local wexp "[fw=w]"
        table1_tc `wexp', by(arm) vars(age contn \ age contln \ sex bin \ grpn cat) smd nopvalue `wopt'
        assert `"`r(smdnote)'"' == ""
        tempname A B
        matrix `A' = r(table)
        table1_tc `wexp', by(arm) vars(age contn \ age contln \ sex bin \ grpn cat) smd smdtype(maxpair) nopvalue `wopt'
        matrix `B' = r(table)
        forvalues j = 1/4 {
            assert !missing(`A'[`j', 1]) & !missing(`B'[`j', 1])
            assert reldif(`A'[`j', 1], `B'[`j', 1]) < 1e-12
        }
        assert `"`r(smdnote)'"' == "Max SMD: largest absolute pairwise difference across the 2 groups, in the root-mean of the group variances."
    }
}
if _rc == 0 {
    display as result "  PASS: T5 two-group maxpair = |pair SMD| unweighted, wt(), fweight"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 two-group identity (rc=`=_rc')"
    local ++fail_count
}

**# T6: smdpair() picks the pair (string, numeric, labelled numeric by)
capture noisily {
    _dt240_data
    _dt240_oracle "`od'/dt240_toy_py.csv" pair_CA age
    local want = r(value)
    table1_tc, by(arm) vars(age contn) smd smdpair(C A) nopvalue
    assert reldif(el(r(table), 1, 1), `want') < 1e-12
    assert `"`r(smdnote)'"' == "SMD compares C vs A only (2 of 3 groups, chosen with smdpair())."
    * numeric by: codes; labelled numeric by: label text or code
    quietly encode arm, gen(armn)
    table1_tc, by(armn) vars(age contn) smd smdpair(3 1) nopvalue
    assert reldif(el(r(table), 1, 1), `want') < 1e-12
    table1_tc, by(armn) vars(age contn) smd smdpair("C" A) nopvalue frame(dt240_pf, replace)
    assert reldif(el(r(table), 1, 1), `want') < 1e-12
    frame dt240_pf: assert strtrim(smd_str[1]) == "SMD (C vs A)"
    frame drop dt240_pf
    * two groups with smdpair: header names the pair, no note
    preserve
    quietly keep if arm != "B"
    table1_tc, by(arm) vars(age contn) smd smdpair(C A) nopvalue clear
    assert strtrim(smd_str[1]) == "SMD (C vs A)"
    restore
    * refusals
    foreach bad in `"smdpair(C)"' `"smdpair(A B C)"' `"smdpair(A A)"' `"smdpair(A D)"' ///
        `"smdpair(A B) smdtype(population)"' `"smdtype(population) smd(x)"' `"smdtype(bogus)"' {
        capture table1_tc, by(arm) vars(age contn) smd `bad'
        assert inlist(_rc, 198)
    }
    capture table1_tc, by(arm) vars(age contn) smdtype(population)
    assert _rc == 198
    capture table1_tc, by(arm) vars(age contn) smdpair(A B)
    assert _rc == 198
    capture table1_tc, by(armn) vars(age contn) smd smdpair(1 7)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T6 smdpair() values, labels, header, refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 smdpair (rc=`=_rc')"
    local ++fail_count
}

**# T7: wtcompare + population; smdthreshold() bolds Pop. SB cells
capture noisily {
    _dt240_data
    _dt240_oracle "`od'/dt240_toy_py.csv" pop_wt age
    local want = r(value)
    local f "`od'/dt240_wtc"
    capture erase "`f'.xlsx"
    table1_tc, by(arm) vars(age contn \ sex bin) smd smdtype(population) ///
        wt(w) wtcompare smdthreshold(0.7) excel("`f'.xlsx") sheet("W") frame(dt240_wf, replace)
    assert reldif(el(r(table), 1, 1), `want') < 1e-12
    assert strpos(`"`r(Dapa)'"', "SMD reflects weighted comparison.")
    frame dt240_wf {
        * the SMD column is last after the crude/weighted pairs
        quietly ds
        local last : word `: word count `r(varlist)'' of `r(varlist)'
        assert "`last'" == "smd_str"
        assert strtrim(smd_str[1]) == "Pop. SB"
    }
    frame drop dt240_wf
    shell python3 tools/xlsx_facts.py "`f'.xlsx" W "`f'.facts.txt"
    * age PSB 0.937 > 0.7 is bold; sex 0.639 is not (factor B, crude C-E, weighted F-H, SMD I; body from row 5)
    _dt240_has "`f'.facts.txt" "value I2 Pop. SB"
    _dt240_has "`f'.facts.txt" "value I5 0.937"
    _dt240_has "`f'.facts.txt" "bold I5"
    _dt240_hasnot "`f'.facts.txt" "bold I6"
}
if _rc == 0 {
    display as result "  PASS: T7 wtcompare population SB, header, threshold bolding"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 wtcompare/threshold (rc=`=_rc')"
    local ++fail_count
}

**# T8: a group with no values leaves the statistic blank (never fewer groups)
capture noisily {
    foreach t in population maxpair {
        _dt240_data
        quietly replace age = . if arm == "C"
        quietly replace sex = . if arm == "B"
        table1_tc, by(arm) vars(age contn \ sex bin \ grpn cat) smd smdtype(`t') nopvalue
        assert missing(el(r(table), 1, 1))
        assert missing(el(r(table), 2, 1))
        assert !missing(el(r(table), 3, 1))
        * a group with one record: maxpair variance undefined -> blank;
        * population is defined (the pooled SD exists)
        _dt240_data
        quietly drop if arm == "A" & _n > 1
        table1_tc, by(arm) vars(age contn) smd smdtype(`t') nopvalue
        if "`t'" == "maxpair" assert missing(el(r(table), 1, 1))
        else assert !missing(el(r(table), 1, 1))
    }
}
if _rc == 0 {
    display as result "  PASS: T8 empty or singleton group gives a blank, not a K-1 group statistic"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 empty group (rc=`=_rc')"
    local ++fail_count
}

**# T9: smallcells, contln and session hygiene
capture noisily {
    _dt240_data
    local before_vao = c(varabbrev)
    set varabbrev on
    quietly frames dir
    local before `"`r(frames)'"'
    table1_tc, by(arm) vars(age contln \ grpn cat) smd smdtype(maxpair) smallcells(3) nopvalue
    assert "`r(smdtype)'" == "maxpair"
    * contln: max pairwise on the log scale, by hand
    quietly gen double lnage = log(age)
    local vs 0
    foreach g in A B C {
        quietly summarize lnage if arm == "`g'"
        local m`g' = r(mean)
        local vs = `vs' + r(Var)
    }
    table1_tc, by(arm) vars(age contln) smd smdtype(maxpair) nopvalue
    local hand = (max(`mA', `mB', `mC') - min(`mA', `mB', `mC')) / sqrt(`vs' / 3)
    assert reldif(el(r(table), 1, 1), `hand') < 1e-12
    capture table1_tc, by(arm) vars(age contn) smd smdtype(bogus)
    assert _rc == 198
    assert c(varabbrev) == "on"
    quietly frames dir
    assert `"`r(frames)'"' == `"`before'"'
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: T9 smallcells/contln run; varabbrev and frames restored"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 hygiene (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

**# T10: smdpair() with numeric-looking value labels: ambiguity is refused
capture noisily {
    _dt240_data
    quietly gen byte armn = cond(arm == "A", 1, cond(arm == "B", 2, 3))
    label define dt240_amb 1 "3" 2 "1" 3 "2"
    label values armn dt240_amb
    * expected pairs, from the string arm (A=value 1, B=2, C=3)
    table1_tc, by(arm) vars(age contn) smd smdpair(C B) nopvalue
    local wantCB = el(r(table), 1, 1)
    table1_tc, by(arm) vars(age contn) smd smdpair(A C) nopvalue
    local wantAC = el(r(table), 1, 1)
    * 3 is value 3 (label "2") and the label of value 1: ambiguous, quoted or not
    foreach spec in `"3 2"' `""3" "2""' `"1 2"' {
        local f "`od'/dt240_amb.txt"
        quietly log using "`f'", text replace name(_dt240a) nomsg
        capture noisily table1_tc, by(armn) vars(age contn) smd smdpair(`spec')
        local rc = _rc
        quietly log close _dt240a
        assert `rc' == 198
        _dt240_has "`f'" "is ambiguous"
        _dt240_has "`f'" ", values)"
        _dt240_hasnot "`f'" "invalid name"
    }
    * values: 3 and 2 are by() values -> groups C and B
    table1_tc, by(armn) vars(age contn) smd smdpair(3 2, values) nopvalue frame(dt240_af, replace)
    assert reldif(el(r(table), 1, 1), `wantCB') < 1e-12
    frame dt240_af: assert strtrim(smd_str[1]) == "SMD (2 vs 1)"
    * labels: "3" and "2" are label texts -> values 1 and 3 (groups A and C)
    table1_tc, by(armn) vars(age contn) smd smdpair("3" "2", labels) nopvalue frame(dt240_af, replace)
    assert reldif(el(r(table), 1, 1), `wantAC') < 1e-12
    frame dt240_af: assert strtrim(smd_str[1]) == "SMD (3 vs 2)"
    frame drop dt240_af
    * a label equal to its own value is not ambiguous
    label define dt240_same 1 "1" 2 "2" 3 "3"
    label values armn dt240_same
    table1_tc, by(armn) vars(age contn) smd smdpair(3 2) nopvalue
    assert reldif(el(r(table), 1, 1), `wantCB') < 1e-12
    * bad suboption; values with a label-only token
    capture table1_tc, by(armn) vars(age contn) smd smdpair(3 2, both)
    assert _rc == 198
    label values armn dt240_amb
    capture table1_tc, by(arm) vars(age contn) smd smdpair(C B, values)
    assert _rc == 0
    capture table1_tc, by(armn) vars(age contn) smd smdpair(x 2, values)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T10 smdpair() value/label ambiguity refused; values/labels resolve it"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 smdpair ambiguity (rc=`=_rc')"
    local ++fail_count
}

**# T11: wtcompare prints no internal merge chatter (2 and 3 groups)
capture noisily {
    foreach k in 3 2 {
        _dt240_data
        if `k' == 2 quietly keep if arm != "C"
        local f "`od'/dt240_wtcq`k'.txt"
        quietly log using "`f'", text replace name(_dt240q) nomsg
        table1_tc, by(arm) vars(age contn \ sex bin \ grpn cat) smd wt(w) wtcompare
        quietly log close _dt240q
        foreach junk in "real change" "unmatched" "missing value" "copied from linked frame" {
            _dt240_hasnot "`f'" "`junk'"
        }
        _dt240_has "`f'" "Weighted A"
    }
}
if _rc == 0 {
    display as result "  PASS: T11 wtcompare console free of merge chatter"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 wtcompare chatter (rc=`=_rc')"
    local ++fail_count
}

**# T12: r(table) under wt(): the smd column only; nothing without smd
capture noisily {
    _dt240_data
    foreach opt in "" "wtcompare" {
        table1_tc, by(arm) vars(age contn \ sex bin \ grpn cat) smd wt(w) `opt' nopvalue
        tempname T
        matrix `T' = r(table)
        assert rowsof(`T') == 3 & colsof(`T') == 1
        assert "`: colnames `T''" == "smd"
        assert "`r(smdtype)'" == "pair"
        assert !missing(`T'[1, 1])
        * no smd: no p-values (suppressed under wt()) and no SMD, so nothing to post
        table1_tc, by(arm) vars(age contn \ sex bin) wt(w) `opt'
        capture confirm matrix r(table)
        assert _rc == 111
    }
    * the same contract unweighted with nopvalue
    table1_tc, by(arm) vars(age contn) nopvalue
    capture confirm matrix r(table)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T12 r(table) under wt() holds smd; absent without p-values or smd"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 r(table) under weights (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_desctab_v240 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _dt240
set linesize `_ls0'
if `fail_count' > 0 exit 1
