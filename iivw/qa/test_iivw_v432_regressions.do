* test_iivw_v432_regressions.do
* Regressions for the defects fixed in 4.3.2. Every case is red on 4.3.1.
* budget: 10
*
*   T1  iivw_weight leaves unstset data unstset: no _dta[_dta] = st and no
*       st_* characteristic naming a dropped temporary (IIW and FIPTIW+scores)
*   T2  iivw_weight leaves a user's own stset exactly as it was: every st_*
*       characteristic unchanged (4.3.1 added st_enter/st_exit naming a dropped
*       temporary) and stdescribe still runs
*   T3  iivw: r(n_commands) equals the length of r(commands), and every listed
*       command resolves to a help file (4.3.1 posted a literal 5 for six)
*   T4  footnote() and title() reach the workbook byte for byte in
*       iivw_balance, iivw_exogtest and iivw_diagnose ($name, `name', an
*       unbalanced backtick)
*   T5  variable and value labels are data: a label holding $name or a
*       backtick reaches the iivw_balance workbook, and the iivw_exogtest
*       workbook, r(term_label_#) and r(group_label_#), unexpanded
*   T6  iivw_bspool saving(): a name holding a comma is written AND stamped;
*       $name, `name' and an unbalanced backtick are written literally, and
*       e(iivw_bs_saving) is that literal name
*   T7  truncvisit()/trunctreat(): the trimmed-row counts, r(trunc_visit_lo/hi)
*       and the clipped values equal those at the exact _pctile cutpoint
*       (4.3.1 carried the cut through a decimal local), and the iivw_balance
*       replay reproduces the trimmed weight exactly
*
* The expected text is always built in Mata from char() codes, so no oracle
* passes through the macro expansion under test.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v432_regressions.do [case#]

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

iivw_qa_selector `1'
local run_only = r(run_only)

tempfile _stub
local work "`_stub'_v432"
capture mkdir "`work'"
global V432_W "`work'"

**# Fixtures

* The pinned FIPTIW panel of test_iivw_state_lifecycle.do, before weighting;
* `w' also builds the weights.
capture program drop _v432_panel
program define _v432_panel
    version 16.0
    args w
    clear
    set rng mt64s
    set rngstream 1
    set seed 4713
    quietly set obs 150
    gen long id = _n
    gen double k1 = rnormal()
    gen double z1 = rnormal()
    gen byte a = runiform() < invlogit(.8*k1)
    quietly expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double y = 1 + .5*a + .4*z1 + .3*k1 + .1*t + rnormal()
    gen double keeppr = invlogit(.4 + .9*z1 - .3*a)
    quietly drop if runiform() > keeppr & j > 1
    sort id t
    if "`w'" != "" {
        quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
            wtype(fiptiw) maxfu(7) scores nolog
    }
end

* The hostile texts, built from char() codes only.
*   V432_PAIR  a $global, a `name' pair and embedded double quotes
*   V432_TICK  an unbalanced backtick
*   V432_LAB   a label a user could plausibly type ("Cost in $USD")
capture program drop _v432_texts
program define _v432_texts
    version 16.0
    global V432_GLB "EXPANDED"
    global USD "EXPANDED"
    mata: st_global("V432_PAIR", "V " + char(36) + "V432_GLB " + char(96) + ///
        "lit" + char(39) + " " + char(34) + "dq" + char(34) + " end")
    mata: st_global("V432_TICK", "U " + char(96) + "tick end")
    mata: st_global("V432_LAB", "Cost in " + char(36) + "USD " + char(96) + "q")
end

* Every _dta characteristic of the st namespace, as "name=value" lines.
capture program drop _v432_stchars
program define _v432_stchars, rclass
    version 16.0
    local all : char _dta[]
    local out ""
    foreach c of local all {
        if substr("`c'", 1, 3) == "st_" | "`c'" == "_dta" {
            local v : char _dta[`c']
            local out `"`out'|`c'=`v'"'
        }
    }
    return local chars `"`out'"'
end

* Cell (r, c) of a workbook sheet, read without macro expansion.
capture program drop _v432_cell
program define _v432_cell
    version 16.0
    args file sheet r c
    preserve
    quietly import excel using "`file'", sheet("`sheet'") allstring clear
    mata: st_global("V432_CELL", ///
        (st_nobs() >= `r' & st_nvar() >= `c') ? st_sdata(`r', `c') : "")
    restore
end

* True when global g equals V432_CELL exactly.
capture program drop _v432_same
program define _v432_same
    version 16.0
    args g what
    mata: st_local("ok", strofreal(st_global("`g'") == st_global("V432_CELL")))
    if !`ok' {
        mata: printf("{err}%s: got [%s] want [%s]\n", st_local("what"), ///
            st_global("V432_CELL"), st_global("`g'"))
        exit 9
    }
end

**# T1: unstset data stays unstset

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    * IIW only
    _v432_panel
    _v432_stchars
    assert `"`r(chars)'"' == ""
    quietly iivw_weight, id(id) time(t) visit_cov(z1) maxfu(7) nolog
    confirm variable _iivw_weight
    _v432_stchars
    display as text `"st characteristics after iivw_weight: [`r(chars)']"'
    assert `"`r(chars)'"' == ""
    * FIPTIW with score columns: a second merge path (propensity file)
    _v432_panel w
    confirm variable _iivw_weight _iivw_ns1
    _v432_stchars
    assert `"`r(chars)'"' == ""
    * A later st command must see no survival settings, not dangling ones.
    capture stdescribe
    assert _rc == 119
    display as result "T1 PASS: iivw_weight leaves unstset data unstset"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T1"
    display as error "T1 FAIL"
}
}

**# T2: a user's own stset survives unchanged

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _v432_panel
    gen double t0 = t - 1
    bysort id (t): gen byte ev = _n == _N
    quietly stset t, id(id) failure(ev) time0(t0)
    _v432_stchars
    local before `"`r(chars)'"'
    quietly stdescribe
    local nsub0 = r(N_sub)
    local risk0 = r(tr)
    tempvar t_0
    quietly gen double `t_0' = _t
    quietly iivw_weight, id(id) time(t) visit_cov(z1) maxfu(7) nolog
    _v432_stchars
    local after `"`r(chars)'"'
    display as text `"before: [`before']"'
    display as text `"after:  [`after']"'
    assert `"`before'"' == `"`after'"'
    quietly stdescribe
    assert r(N_sub) == `nsub0' & r(tr) == `risk0'
    assert _t == `t_0'
    display as result "T2 PASS: a user's stset is untouched by iivw_weight"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T2"
    display as error "T2 FAIL"
}
}

**# T3: iivw r(n_commands)

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    quietly iivw
    local cmds "`r(commands)'"
    local n : word count `cmds'
    assert `n' == 6
    assert r(n_commands) == `n'
    foreach c of local cmds {
        quietly findfile `c'.sthlp
    }
    display as result "T3 PASS: r(n_commands) = `n' = the commands listed"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T3"
    display as error "T3 FAIL"
}
}

**# T4: title() and footnote() reach the workbook literally

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    _v432_texts
    _v432_panel w
    quietly regress y z1
    estimates store v432_u
    quietly regress y z1 k1
    estimates store v432_w
    quietly regress y z1 k1 a
    estimates store v432_a
    foreach g in V432_PAIR V432_TICK {
        mata: st_local("txt", st_global("`g'"))
        foreach cmd in balance exogtest diagnose {
            local x "$V432_W/t4_`cmd'.xlsx"
            capture erase "`x'"
            if "`cmd'" == "balance" {
                quietly iivw_balance k1 z1, xlsx("`x'") replace ///
                    title(`"`macval(txt)'"') footnote(`"`macval(txt)'"')
            }
            if "`cmd'" == "exogtest" {
                quietly iivw_exogtest y, id(id) time(t) maxfu(7) nolog ///
                    xlsx("`x'") replace ///
                    title(`"`macval(txt)'"') footnote(`"`macval(txt)'"')
            }
            if "`cmd'" == "diagnose" {
                quietly iivw_diagnose z1, unweighted(v432_u) ///
                    weighted(v432_w) adjusted(v432_a) force xlsx("`x'") ///
                    replace title(`"`macval(txt)'"') footnote(`"`macval(txt)'"')
            }
            local sh "`r(sheet)'"
            _v432_cell "`x'" "`sh'" 1 1
            _v432_same `g' "`cmd' title `g'"
            * footnote: column B of the last row
            preserve
            quietly import excel using "`x'", sheet("`sh'") allstring clear
            mata: st_global("V432_CELL", st_sdata(st_nobs(), 2))
            restore
            _v432_same `g' "`cmd' footnote `g'"
        }
    }
    display as result "T4 PASS: title() and footnote() are written byte for byte"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T4"
    display as error "T4 FAIL"
}
capture estimates drop v432_*
}

**# T5: variable and value labels are not expanded

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    _v432_texts
    * iivw_balance: covariate label in column B
    _v432_panel w
    mata: st_varlabel("k1", st_global("V432_LAB"))
    local x "$V432_W/t5_bal.xlsx"
    capture erase "`x'"
    quietly iivw_balance k1 z1, xlsx("`x'") replace
    local sh "`r(sheet)'"
    preserve
    quietly import excel using "`x'", sheet("`sh'") allstring clear
    mata: st_local("hit", strofreal(anyof(st_sdata(., 2), st_global("V432_LAB"))))
    restore
    assert `hit' == 1

    * iivw_exogtest: the lagged-term label and the by() group labels
    _v432_panel w
    mata: st_varlabel("y", st_global("V432_LAB"))
    gen byte grp = mod(id, 2)
    label define v432gl 0 "zero"
    mata: st_vlmodify("v432gl", 1, st_global("V432_TICK"))
    label values grp v432gl
    local x "$V432_W/t5_exo.xlsx"
    capture erase "`x'"
    quietly iivw_exogtest y, id(id) time(t) maxfu(7) by(grp) nolog ///
        xlsx("`x'") replace
    mata: st_global("V432_WANT", st_global("V432_LAB") + " (lag 1)")
    mata: st_local("ok1", strofreal(st_global("r(term_label_1)") == st_global("V432_WANT")))
    mata: st_local("ok2", strofreal(st_global("r(group_label_2)") == st_global("V432_TICK")))
    mata: st_local("ok3", strofreal(st_global("r(group_label_1)") == "zero"))
    assert `ok1' & `ok2' & `ok3'
    local sh "`r(sheet)'"
    preserve
    quietly import excel using "`x'", sheet("`sh'") allstring clear
    mata: X = st_sdata(., .)
    mata: st_local("hit1", strofreal(anyof(X, st_global("V432_WANT"))))
    mata: st_local("hit2", strofreal(anyof(X, st_global("V432_TICK"))))
    restore
    assert `hit1' & `hit2'
    display as result "T5 PASS: labels reach the workbook and r() unexpanded"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T5"
    display as error "T5 FAIL"
}
}

**# T6: iivw_bspool saving() file names

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    _v432_texts
    clear
    set seed 8080
    quietly set obs 80
    gen long id = _n
    gen double y = 1 + rnormal()
    forvalues s = 1/2 {
        quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
            vce(bootstrap, reps(6) fixedweights seed(11)) rngstream(`s') ///
            saving("$V432_W/sh_`s'", replace)
        estimates store v432_s`s'
    }
    mata: st_global("V432_COMMA", "left, right")
    foreach g in V432_COMMA V432_PAIR V432_TICK V432_LAB {
        * V432_PAIR holds double quotes; a file name may not, on Windows.
        if "`g'" == "V432_PAIR" & c(os) == "Windows" continue
        mata: st_local("nm", st_global("V432_W") + "/p_" + st_global("`g'"))
        mata: st_local("fd", st_local("nm") + ".dta")
        capture erase `"`macval(fd)'"'
        quietly estimates restore v432_s1
        iivw_bspool using "$V432_W/sh_1.dta $V432_W/sh_2.dta", notable ///
            saving(`"`macval(nm)'"', replace)
        mata: st_local("ok", strofreal(st_global("e(iivw_bs_saving)") == st_local("fd")))
        assert `ok'
        mata: st_local("there", strofreal(fileexists(st_local("fd"))))
        assert `there'
        * stamped against the pooled result
        preserve
        quietly use `"`macval(fd)'"', clear
        local pooled : char _dta[_iivw_shard_pooled]
        restore
        assert "`pooled'" == "1"
        capture erase `"`macval(fd)'"'
    }
    * nothing was written under an expanded name
    local stray : dir "$V432_W" files "p_*EXPANDED*"
    assert `"`stray'"' == ""
    display as result "T6 PASS: saving() writes and stamps the literal file name"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T6"
    display as error "T6 FAIL"
}
capture estimates drop v432_*
}

**# T7: trimming counts and clips at the exact percentile

* The oracle recomputes each cutpoint with _pctile into a scalar and counts
* strictly-beyond rows against it. On 4.3.1 the cut went through a decimal
* local, so a weight equal to the percentile could land beyond its own
* rounded value: r(n_trunc_visit) overcounted in about half of these draws.
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    local nbad 0
    forvalues sd = 1/8 {
        _v432_panel
        set seed `sd'
        quietly replace z1 = z1 + rnormal()/10
        quietly iivw_weight, id(id) time(t) visit_cov(z1 k1) treat(a) ///
            treat_cov(k1) wtype(fiptiw) maxfu(7) nolog ///
            truncvisit(5 95) trunctreat(2 98) truncfinal(1 99)
        tempname rv rt rf
        scalar `rv' = r(n_trunc_visit)
        scalar `rt' = r(n_trunc_treat)
        scalar `rf' = r(n_truncated)
        scalar v432_vlo = r(trunc_visit_lo)
        scalar v432_vhi = r(trunc_visit_hi)
        * visit component: row percentiles of the raw IIW
        quietly _pctile _iivw_iw_raw if !missing(_iivw_iw_raw), percentiles(5 95)
        scalar v432_lo = r(r1)
        scalar v432_hi = r(r2)
        quietly count if !missing(_iivw_iw_raw) & ///
            (_iivw_iw_raw < v432_lo | _iivw_iw_raw > v432_hi)
        local want_v = r(N)
        assert v432_vlo == v432_lo & v432_vhi == v432_hi
        * the clipped rows hold the exact cutpoint
        quietly count if _iivw_iw_raw < v432_lo & _iivw_iw != v432_lo
        assert r(N) == 0
        quietly count if _iivw_iw_raw > v432_hi & _iivw_iw != v432_hi
        assert r(N) == 0
        * treatment component: subject percentiles of the raw IPTW
        tempvar tg
        quietly egen byte `tg' = tag(id) if !missing(_iivw_tw_raw)
        quietly _pctile _iivw_tw_raw if `tg' == 1, percentiles(2 98)
        scalar v432_lo = r(r1)
        scalar v432_hi = r(r2)
        quietly count if !missing(_iivw_tw_raw) & ///
            (_iivw_tw_raw < v432_lo | _iivw_tw_raw > v432_hi)
        local want_t = r(N)
        display as text "draw `sd': visit " scalar(`rv') " vs `want_v'; treat " ///
            scalar(`rt') " vs `want_t'"
        if scalar(`rv') != `want_v' | scalar(`rt') != `want_t' local ++nbad
    }
    assert `nbad' == 0
    * the balance replay reproduces the trimmed visit weight exactly
    quietly iivw_balance z1
    assert r(replay_max_reldif) == 0
    display as result "T7 PASS: trimming counts and clips at the exact percentile"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T7"
    display as error "T7 FAIL"
}
capture scalar drop v432_*
}

**# Summary

macro drop V432_*
capture macro drop USD
capture erase "`work'"

iivw_qa_summary, name(test_iivw_v432_regressions) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
