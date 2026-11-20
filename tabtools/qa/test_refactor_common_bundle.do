* test_refactor_common_bundle.do - tabtools 1.2.1 refactor: S3 helper bundle
* The 9 Mata-free multi-caller helpers (_regtab_bnotes, _tabtools_colwidth,
* _tabtools_export_hint, _tabtools_fmt_pct, _tabtools_smallcells_opt,
* _tabtools_smallcells_render, _tabtools_st_timescale, _tabtools_texopts,
* _tabtools_visible_vars) moved into _tabtools_common.ado, which now carries a
* release sentinel _tt_bundle_build() that every loader block asserts.
* Covers:
*   B1  common runs twice in one session at rc 0; c(matastrict) is kept
*   B2  the 9 programs are defined by common and are in its required list:
*       dropping any one makes _tabtools_helpers_ready fail
*   B3  sentinel parity: every loader site asserts the same literal, twice
*       per site, and it equals common's own return value (B3a); that value
*       is the release in tabtools.ado's header (B3b, a forcing function on
*       the next version bump)
*   B4  a session holding a 1.2.0 _tabtools_common.ado (fixture
*       qa/data/stale_common_120, byte-identical to 1.2.0, no .pkg line):
*       each example reloads common and prints what a clean session prints
*   B5  recovery matrix: mata clear, discard, clear all, and a dropped
*       _tabtools_colwidth; each example recovers with unchanged output
*   B6  cold first call with only the installed package: outtab, ratetab,
*       tabcell, tabtools fitcount, with known answers
*   B7  common unfindable: outtab, ratetab, tabcell and tabtools fitcount
*       exit 111 "reinstall tabtools" and restore varabbrev (declared new
*       behaviour for the first three in 1.2.1)
* Expected values come from the package source, the data, or a run of the
* same example in a clean session, never from the table under test.
*
* Run from tabtools/qa. The file re-runs its own helper block after a state
* reset (program drop _all, mata clear, clear all): run this file "defs".

args _rcb_mode
if "`_rcb_mode'" == "" {
    clear all
    set more off
    set varabbrev off
}
version 17.0

**# Helpers (re-defined by: run this file defs)
* Run a command with its console output captured to file `1'; the command's
* return code comes back in local `2' of the caller, and its r() is held
* across the log close so the caller can read it.
capture program drop _rcb_cap
program define _rcb_cap, nclass
    version 17.0
    gettoken logf 0 : 0
    gettoken rcname 0 : 0
    quietly log using "`logf'", text replace name(_rcbcap) nomsg
    capture noisily `0'
    local rc = _rc
    tempname rh
    _return hold `rh'
    quietly log close _rcbcap
    _return restore `rh'
    c_local `rcname' `rc'
end

* Identical, nonempty text files.
capture program drop _rcb_same
program define _rcb_same, nclass
    version 17.0
    args a b
    mata: st_local("na", strofreal(rows(cat(st_local("a")))))
    mata: st_local("same", strofreal(cat(st_local("a")) == cat(st_local("b"))))
    assert `na' > 0
    if !`same' {
        display as error "outputs differ: `a' vs `b'"
        type "`a'"
        type "`b'"
    }
    assert `same'
end

* The examples. Each sets up its own data.
capture program drop _rcb_ex_outtab
program define _rcb_ex_outtab
    version 17.0
    sysuse auto, clear
    generate byte hi_mpg = mpg > 21
    generate byte heavy = weight > 3000
    outtab hi_mpg foreign, exposure(heavy)
end
capture program drop _rcb_ex_ratetab
program define _rcb_ex_ratetab
    version 17.0
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    generate byte agegrp = 1 + (age >= 55) + (age >= 60)
    ratetab agegrp, outlabels("Death")
end
capture program drop _rcb_ex_tabcell
program define _rcb_ex_tabcell
    version 17.0
    tabcell p, p(0.0312)
    tabcell np, n(5) d(20)
end
capture program drop _rcb_ex_fitcount
program define _rcb_ex_fitcount
    version 17.0
    sysuse auto, clear
    collect clear
    quietly collect: poisson foreign mpg
    tabtools fitcount, events(foreign) people(headroom)
    regtab, stats(events people)
end
capture program drop _rcb_ex_crosstab
program define _rcb_ex_crosstab
    version 17.0
    sysuse auto, clear
    crosstab rep78 foreign, smallcells(5)
end
capture program drop _rcb_ex_regtab
program define _rcb_ex_regtab
    version 17.0
    args x
    capture erase "`x'"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.foreign
    regtab, excel("`x'") sheet("W")
end
capture program drop _rcb_ex_desctab
program define _rcb_ex_desctab
    version 17.0
    sysuse auto, clear
    desctab price mpg rep78, by(foreign)
end

capture mata: mata drop _rcb_sites() _rcb_sentinel()
mata:
// Loader sites in source file fn: locals n_ff (lines that findfile common)
// and n_lit, lits (every _tt_bundle_build() == "<lit>" literal, in order).
void _rcb_sites(string scalar fn)
{
    string colvector L
    string scalar s, re, lits
    real scalar i, n, p

    re = `"_tt_bundle_build\(\) == "([^"]*)""'
    L = cat(fn)
    st_local("n_ff", strofreal(sum(strpos(L, "findfile _tabtools_common.ado") :> 0)))
    n = 0
    lits = ""
    for (i = 1; i <= rows(L); i++) {
        s = L[i]
        while (ustrregexm(s, re)) {
            n++
            lits = lits + " " + ustrregexs(1)
            p = ustrpos(s, ustrregexs(0))
            s = usubstr(s, p + ustrlen(ustrregexs(0)), .)
        }
    }
    st_local("n_lit", strofreal(n))
    st_local("lits", strtrim(lits))
}

// The value _tt_bundle_build() returns, from common's source: local bb_src
// ("" when the function or its return line is missing).
void _rcb_sentinel(string scalar fn)
{
    string colvector L
    real scalar i, j

    L = cat(fn)
    st_local("bb_src", "")
    for (i = 1; i <= rows(L); i++) {
        if (!ustrregexm(L[i], "^string scalar _tt_bundle_build\(\)[ \t]*$")) continue
        for (j = i + 1; j <= min((i + 4, rows(L))); j++) {
            if (ustrregexm(L[j], `"^[ \t]*return\("([^"]*)"\)[ \t]*$"')) {
                st_local("bb_src", ustrregexs(1))
                return
            }
        }
    }
}
end

if "`_rcb_mode'" == "defs" exit

capture log close _rcb
log using "test_refactor_common_bundle.log", replace text name(_rcb)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local self "`qa_dir'/test_refactor_common_bundle.do"
local stale_fn "`qa_dir'/data/stale_common_120/_tabtools_common.ado"

* run_all.do runs every suite in one session, and earlier suites leave
* `adopath ++ pkg_dir' behind. With the source tree ahead of PLUS, findfile
* resolves there and B1/B6/B7 (which pin resolution to the install, or to
* nowhere) fail for a reason unrelated to the bundle. Take the entry out for
* this suite and put it back at the end.
local had_pkg_path 0
foreach p in "`pkg_dir'" "`pkg_dir'/" {
    forvalues i = 1/5 {
        capture adopath - "`p'"
        if _rc continue, break
        local had_pkg_path 1
    }
}
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local moved _regtab_bnotes _tabtools_colwidth _tabtools_export_hint ///
    _tabtools_fmt_pct _tabtools_smallcells_opt _tabtools_smallcells_render ///
    _tabtools_st_timescale _tabtools_texopts _tabtools_visible_vars

* the release, from tabtools.ado's header
mata: st_local("hdr", cat(st_local("pkg_dir") + "/tabtools.ado")[1])
local rel ""
if regexm(`"`hdr'"', "^\*! tabtools Version ([0-9.]+) ") local rel = regexs(1)
display as text "tabtools.ado header release: `rel'"
* the sentinel, from common's source
mata: _rcb_sentinel(st_local("pkg_dir") + "/_tabtools_common.ado")
local bb "`bb_src'"
display as text "_tabtools_common.ado sentinel: `bb'"

local wb_rt "`output_dir'/rcb_regtab.xlsx"
local exs outtab ratetab tabcell fitcount crosstab regtab desctab
foreach e of local exs {
    local ex_`e' "_rcb_ex_`e'"
    tempfile base_`e'
}
local ex_regtab `"_rcb_ex_regtab "`wb_rt'""'

* Baselines: each example once, in the clean installed session.
local base_rc = 0
foreach e of local exs {
    discard
    _rcb_cap "`base_`e''" rc `ex_`e''
    display as text "baseline `e': rc `rc'"
    if `rc' local base_rc = `rc'
}

**# B1 common runs twice in one session
* B1a: run twice at rc 0 under matastrict on and under matastrict off; each
* run leaves c(matastrict) as it found it.
local ++test_count
capture noisily {
    assert `base_rc' == 0
    quietly findfile _tabtools_common.ado
    local cfn "`r(fn)'"
    assert strpos("`cfn'", "`c(sysdir_plus)'") == 1
    local ms_orig = c(matastrict)
    foreach ms in on off {
        set matastrict `ms'
        run "`cfn'"
        assert c(matastrict) == "`ms'"
        run "`cfn'"
        assert c(matastrict) == "`ms'"
    }
    set matastrict `ms_orig'
    _tabtools_helpers_ready
    mata: assert(_tt_bundle_build() == st_local("bb"))
}
if _rc == 0 {
    display as result "  PASS: B1a common runs twice at rc 0 under either matastrict; setting kept"
    local ++pass_count
}
else {
    display as error "  FAIL: B1a run common twice (rc=`=_rc')"
    local ++fail_count
}

**# B2 the 9 moved programs and the required list
* B2a: after run of common each moved program is in memory, defined once in
* common's source, and has no .ado file of its own; dropping any one of them
* makes _tabtools_helpers_ready (default list) fail with 111.
local ++test_count
capture noisily {
    local n_moved : list sizeof moved
    assert `n_moved' == 9
    quietly findfile _tabtools_common.ado
    local cfn "`r(fn)'"
    run "`cfn'"
    _tabtools_helpers_ready
    mata: _rcb_L = cat(st_local("pkg_dir") + "/_tabtools_common.ado")
    foreach p of local moved {
        capture program list `p'
        assert _rc == 0
        mata: st_local("n_def", strofreal(sum(ustrregexm(_rcb_L, ///
            "^[ \t]*program[ \t]+(define[ \t]+)?" + st_local("p") + "[ \t]*(,.*)?$"))))
        mata: st_local("n_drop", strofreal(sum(ustrregexm(_rcb_L, ///
            "^[ \t]*capture program drop " + st_local("p") + "[ \t]*$"))))
        assert `n_def' == 1
        assert `n_drop' >= 1
        capture confirm file "`pkg_dir'/`p'.ado"
        assert _rc == 601
        capture findfile `p'.ado
        assert _rc == 601
    }
    capture mata: mata drop _rcb_L
    foreach p of local moved {
        capture program drop `p'
        capture _tabtools_helpers_ready
        local hr = _rc
        if `hr' != 111 display as error "helpers_ready with `p' dropped: rc `hr'"
        assert `hr' == 111
        run "`cfn'"
        _tabtools_helpers_ready
    }
}
if _rc == 0 {
    display as result "  PASS: B2a the 9 moved programs live in common and in its required list"
    local ++pass_count
}
else {
    display as error "  FAIL: B2a moved programs / required list (rc=`=_rc')"
    local ++fail_count
}

**# B3 Sentinel parity
* B3a: every .ado that loads common (findfile _tabtools_common.ado) other
* than tabtools.ado carries the canonical block's two literals per site, and
* every literal in every file equals common's return value. outtab, ratetab
* and tabcell are loader sites since 1.2.1.
local ++test_count
capture noisily {
    assert ustrregexm("`bb'", "^[0-9]+\.[0-9]+\.[0-9]+$")
    local ados : dir "`pkg_dir'" files "*.ado"
    local sites ""
    local n_all = 0
    foreach f of local ados {
        mata: _rcb_sites(st_local("pkg_dir") + "/" + st_local("f"))
        if `n_ff' == 0 & `n_lit' == 0 continue
        display as text "  `f': findfile `n_ff', literals `n_lit' (`lits')"
        local n_all = `n_all' + `n_lit'
        foreach l of local lits {
            assert "`l'" == "`bb'"
        }
        if "`f'" == "tabtools.ado" {
            assert `n_lit' >= 2
            continue
        }
        if "`f'" == "_tabtools_common.ado" {
            assert `n_ff' == 0 & `n_lit' == 0
            continue
        }
        assert `n_ff' >= 1
        assert `n_lit' == 2 * `n_ff'
        local sites "`sites' `f'"
    }
    foreach f in outtab.ado ratetab.ado tabcell.ado regtab.ado desctab.ado ///
        crosstab.ado comptab.ado effecttab.ado stratetab.ado {
        local isin : list f in sites
        assert `isin'
    }
    assert `n_all' >= 2 * 16
}
if _rc == 0 {
    display as result "  PASS: B3a every loader site asserts the sentinel `bb' twice; common returns it"
    local ++pass_count
}
else {
    display as error "  FAIL: B3a sentinel literal parity (rc=`=_rc')"
    local ++fail_count
}

* B3b: the sentinel is this release: it equals the version in tabtools.ado's
* header, so a version bump that misses the sentinel (or the reverse) fails.
local ++test_count
capture noisily {
    display as text "  header release `rel'; sentinel `bb'"
    assert ustrregexm("`rel'", "^[0-9]+\.[0-9]+\.[0-9]+$")
    assert "`bb'" == "`rel'"
}
if _rc == 0 {
    display as result "  PASS: B3b sentinel `bb' equals the tabtools.ado release `rel'"
    local ++pass_count
}
else {
    display as error "  FAIL: B3b sentinel `bb' is not the tabtools.ado release `rel' (rc=`=_rc')"
    local ++fail_count
}

**# B4 A session holding a 1.2.0 common
* B4a: the fixture is the 1.2.0 file: its header says 1.2.0, it has no
* sentinel and none of the 9 moved programs, and no .pkg line ships it. In a
* session that ran it (and nothing newer), its own helpers_ready and
* _tt_sep_parse() checks pass, so only the sentinel tells the loader to
* reload. Each example then prints what the clean session printed and leaves
* the sentinel loaded.
local ++test_count
capture noisily {
    mata: _rcb_L = cat(st_local("stale_fn"))
    mata: st_local("sh", _rcb_L[1])
    assert ustrregexm(`"`sh'"', "^\*! _tabtools_common Version 1\.2\.0 ")
    mata: st_local("n_bbs", strofreal(sum(strpos(_rcb_L, "_tt_bundle_build") :> 0)))
    assert `n_bbs' == 0
    foreach p of local moved {
        mata: st_local("n_def", strofreal(sum(ustrregexm(_rcb_L, ///
            "^[ \t]*program[ \t]+(define[ \t]+)?" + st_local("p") + "[ \t]*(,.*)?$"))))
        assert `n_def' == 0
    }
    capture mata: mata drop _rcb_L
    mata: _rcb_L = cat(st_local("pkg_dir") + "/tabtools.pkg")
    mata: st_local("n_pk", strofreal(sum(strpos(_rcb_L, "stale_common_120") :> 0)))
    capture mata: mata drop _rcb_L
    assert `n_pk' == 0
    foreach e of local exs {
        program drop _all
        mata: mata clear
        discard
        run "`self'" defs
        run "`stale_fn'"
        mata: st_local("has_bb", strofreal(findexternal("_tt_bundle_build()") != NULL))
        assert `has_bb' == 0
        mata: st_local("has_sep", strofreal(findexternal("_tt_sep_parse()") != NULL))
        assert `has_sep' == 1
        capture _tabtools_helpers_ready
        assert _rc == 0
        capture program list _tabtools_colwidth
        assert _rc == 111
        tempfile st_`e'
        _rcb_cap "`st_`e''" rc `ex_`e''
        if `rc' display as error "B4 `e': rc `rc' after the 1.2.0 common"
        assert `rc' == 0
        _rcb_same "`base_`e''" "`st_`e''"
        mata: assert(findexternal("_tt_bundle_build()") != NULL)
        mata: assert(_tt_bundle_build() == st_local("bb"))
        capture program list _tabtools_colwidth
        assert _rc == 0
        display as text "  B4 `e': reloaded over the 1.2.0 common; output unchanged"
    }
}
if _rc == 0 {
    display as result "  PASS: B4a every example reloads over a 1.2.0 common with unchanged output"
    local ++pass_count
}
else {
    display as error "  FAIL: B4a stale 1.2.0 common (rc=`=_rc')"
    local ++fail_count
}

**# B5 Recovery matrix
* B5a: from a loaded session, each reset (mata clear, discard, clear all, a
* dropped _tabtools_colwidth) is followed by each example at rc 0 with the
* clean session's output, and the sentinel is loaded afterwards.
local ++test_count
capture noisily {
    local resets mataclear discard clearall dropcw
    foreach r of local resets {
        foreach e of local exs {
            quietly findfile _tabtools_common.ado
            run "`r(fn)'"
            _tabtools_helpers_ready
            if "`r'" == "mataclear" {
                mata: mata clear
                run "`self'" defs
                mata: st_local("has_bb", strofreal(findexternal("_tt_bundle_build()") != NULL))
                assert `has_bb' == 0
            }
            if "`r'" == "discard" {
                discard
                run "`self'" defs
            }
            if "`r'" == "clearall" {
                clear all
                run "`self'" defs
                mata: st_local("has_bb", strofreal(findexternal("_tt_bundle_build()") != NULL))
                assert `has_bb' == 0
            }
            if "`r'" == "dropcw" {
                capture program drop _tabtools_colwidth
                capture _tabtools_helpers_ready
                assert _rc == 111
            }
            tempfile rc_`r'_`e'
            _rcb_cap "`rc_`r'_`e''" rc `ex_`e''
            if `rc' display as error "B5 `r' `e': rc `rc'"
            assert `rc' == 0
            _rcb_same "`base_`e''" "`rc_`r'_`e''"
            mata: assert(_tt_bundle_build() == st_local("bb"))
        }
        display as text "  B5 `r': all examples recovered"
    }
}
if _rc == 0 {
    display as result "  PASS: B5a mata clear, discard, clear all, dropped colwidth: every example recovers"
    local ++pass_count
}
else {
    display as error "  FAIL: B5a recovery matrix (rc=`=_rc')"
    local ++fail_count
}

**# B6 Cold first call with only the installed package
* B6a: in a state with no program and no Mata in memory, each of outtab,
* ratetab, tabcell and tabtools fitcount is the first caller, resolves from
* the installed package (PLUS), loads common itself, and prints what the
* clean session printed. Known answers: 5 of 20 is "5 (25.0)", p = 0.0312
* prints "0.031", and the events are the outcome count in the data.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly count if foreign == 1
    local nev = r(N)
    foreach e in outtab ratetab tabcell fitcount {
        program drop _all
        mata: mata clear
        discard
        run "`self'" defs
        capture program list _tabtools_helpers_ready
        assert _rc == 111
        mata: st_local("has_bb", strofreal(findexternal("_tt_bundle_build()") != NULL))
        assert `has_bb' == 0
        local cmd = cond("`e'" == "fitcount", "tabtools", "`e'")
        quietly findfile `cmd'.ado
        assert strpos("`r(fn)'", "`c(sysdir_plus)'") == 1
        quietly findfile _tabtools_common.ado
        assert strpos("`r(fn)'", "`c(sysdir_plus)'") == 1
        tempfile cold_`e'
        _rcb_cap "`cold_`e''" rc `ex_`e''
        if `rc' display as error "B6 `e': rc `rc' in a cold session"
        assert `rc' == 0
        _rcb_same "`base_`e''" "`cold_`e''"
        if "`e'" == "fitcount" assert r(events_1) == `nev'
        if "`e'" == "tabcell" assert "`r(cell)'" == "5 (25.0)"
        mata: assert(_tt_bundle_build() == st_local("bb"))
    }
    assert `nev' == 22
    program drop _all
    mata: mata clear
    discard
    run "`self'" defs
    tabcell p, p(0.0312)
    assert "`r(cell)'" == "0.031"
}
if _rc == 0 {
    display as result "  PASS: B6a outtab, ratetab, tabcell, tabtools fitcount run cold from the install"
    local ++pass_count
}
else {
    display as error "  FAIL: B6a cold first call (rc=`=_rc')"
    local ++fail_count
}

* B6b: tabcell's loader keeps the caller's r(). tabcell est reads lincom's and
* nlcom's r() after its loader runs, so a loader that replaces r() (the
* readiness check, findfile, run) makes lincom report "no lincom results in
* r()" (rc 301; seen in the 1.2.1 bundle before the hold/restore). Each of
* three loader states must read the same source: warm (common loaded, check
* passes), cold (nothing in memory, common found and run), and stale (only the
* sentinel dropped, so the check fails and common is re-run). Known answer:
* r(se) equals lincom's own r(se).
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    quietly lincom mpg + weight
    local lc_se = r(se)
    foreach st in warm cold stale {
        if "`st'" == "cold" {
            program drop _all
            mata: mata clear
            discard
            run "`self'" defs
            capture program list _tabtools_helpers_ready
            assert _rc == 111
        }
        if "`st'" == "stale" {
            capture mata: mata drop _tt_bundle_build()
            mata: st_local("has_bb", strofreal(findexternal("_tt_bundle_build()") != NULL))
            assert `has_bb' == 0
        }
        quietly regress price mpg weight
        quietly lincom mpg + weight
        capture noisily tabcell est, lincom
        if _rc display as error "B6b lincom `st': rc `=_rc'"
        assert _rc == 0
        assert reldif(r(se), `lc_se') < 1e-12
        local lc_cell_`st' `"`r(cell)'"'
        quietly nlcom _b[mpg] / _b[weight]
        capture noisily tabcell est, nlcom
        if _rc display as error "B6b nlcom `st': rc `=_rc'"
        assert _rc == 0
        local nl_cell_`st' `"`r(cell)'"'
        mata: assert(_tt_bundle_build() == st_local("bb"))
    }
    assert `"`lc_cell_warm'"' != ""
    assert `"`lc_cell_cold'"' == `"`lc_cell_warm'"'
    assert `"`lc_cell_stale'"' == `"`lc_cell_warm'"'
    assert `"`nl_cell_warm'"' != ""
    assert `"`nl_cell_cold'"' == `"`nl_cell_warm'"'
    assert `"`nl_cell_stale'"' == `"`nl_cell_warm'"'
}
if _rc == 0 {
    display as result "  PASS: B6b tabcell est lincom/nlcom read the caller's r() across warm, cold and stale loader states"
    local ++pass_count
}
else {
    display as error "  FAIL: B6b tabcell loader keeps the caller's r() (rc=`=_rc')"
    local ++fail_count
}

* B6c: comptab and hrcomptab as the first caller. comptab's main program
* calls _tabtools_smallcells_opt (moved into common in 1.2.1) before its
* rate/vertical subprograms load common, so main carries its own loader;
* without it a cold comptab is r(199) "_tabtools_smallcells_opt is
* unrecognized". The source frames are built first (regtab/ratetab load
* common), then programs and Mata are cleared -- frames survive -- so comptab
* and hrcomptab meet a session with no common in memory. Each prints what the
* same call printed warm.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly regtab, frame(rcb_p1, replace) noint
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    generate byte agegrp = 1 + (age >= 55) + (age >= 60)
    quietly ratetab agegrp, outlabels("Death") frame(rcb_rates, replace)
    collect clear
    quietly collect: stcox i.agegrp drug
    quietly regtab, frame(rcb_models, replace) noint
    local c_cmd comptab rcb_p1, rows(1 2) frame(rcb_cflat, replace flat)
    local h_cmd hrcomptab rcb_rates, modelframes(rcb_models) rows(all) outcomemap(_t) modelonly effect("HR") frame(rcb_hflat, replace flat)
    tempfile c_warm c_cold h_warm h_cold
    _rcb_cap "`c_warm'" rc `c_cmd'
    assert `rc' == 0
    _rcb_cap "`h_warm'" rc `h_cmd'
    assert `rc' == 0
    foreach k in c h {
        program drop _all
        mata: mata clear
        discard
        run "`self'" defs
        capture program list _tabtools_helpers_ready
        assert _rc == 111
        capture program list _tabtools_smallcells_opt
        assert _rc == 111
        _rcb_cap "``k'_cold'" rc ``k'_cmd'
        if `rc' display as error "B6c `k': rc `rc' in a cold session"
        assert `rc' == 0
        _rcb_same "``k'_warm'" "``k'_cold'"
        mata: assert(_tt_bundle_build() == st_local("bb"))
    }
    foreach f in rcb_p1 rcb_rates rcb_models rcb_cflat rcb_hflat {
        capture frame drop `f'
    }
}
if _rc == 0 {
    display as result "  PASS: B6c comptab and hrcomptab run cold as the first caller"
    local ++pass_count
}
else {
    display as error "  FAIL: B6c comptab/hrcomptab cold first call (rc=`=_rc')"
    local ++fail_count
}

**# B7 Common unfindable
* B7a: with PLUS pointed at an empty directory and a copy of the package dir
* without _tabtools_common.ado ahead on the adopath, outtab, ratetab, tabcell
* and tabtools fitcount exit 111 with "_tabtools_common.ado not found;
* reinstall tabtools", and the caller's varabbrev setting survives the exit.
local ++test_count
local orig_plus "`c(sysdir_plus)'"
tempfile b7_tok
local nocommon "`b7_tok'_rcb_nocommon"
local emptyplus "`b7_tok'_rcb_emptyplus"
capture noisily {
    capture mkdir "`nocommon'"
    capture mkdir "`emptyplus'"
    local ados : dir "`pkg_dir'" files "*.ado"
    local n_copied = 0
    foreach f of local ados {
        if "`f'" == "_tabtools_common.ado" continue
        copy "`pkg_dir'/`f'" "`nocommon'/`f'", replace
        local ++n_copied
    }
    assert `n_copied' >= 20
    sysdir set PLUS "`emptyplus'/"
    adopath ++ "`nocommon'"
    program drop _all
    mata: mata clear
    discard
    run "`self'" defs
    capture findfile _tabtools_common.ado
    assert _rc == 601
    quietly findfile outtab.ado
    assert strpos("`r(fn)'", "`nocommon'") == 1
    foreach e in outtab ratetab tabcell fitcount {
        program drop _all
        mata: mata clear
        discard
        run "`self'" defs
        tempfile mc_`e'
        set varabbrev on
        _rcb_cap "`mc_`e''" rc `ex_`e''
        local va "`c(varabbrev)'"
        set varabbrev off
        display as text "  B7 `e': rc `rc', varabbrev after: `va'"
        assert `rc' == 111
        assert "`va'" == "on"
        mata: st_local("n_msg", strofreal(sum(strpos(cat(st_local("mc_`e'")), ///
            "_tabtools_common.ado not found; reinstall tabtools") :> 0)))
        assert `n_msg' == 1
    }
}
local b7_rc = _rc
set varabbrev off
capture adopath - "`nocommon'"
sysdir set PLUS "`orig_plus'"
local ados : dir "`nocommon'" files "*.ado"
foreach f of local ados {
    capture erase "`nocommon'/`f'"
}
capture rmdir "`nocommon'"
capture rmdir "`emptyplus'"
program drop _all
mata: mata clear
discard
run "`self'" defs
if `b7_rc' == 0 {
    display as result "  PASS: B7a common unfindable: four callers exit 111 reinstall, varabbrev kept"
    local ++pass_count
}
else {
    display as error "  FAIL: B7a missing common (rc=`b7_rc')"
    local ++fail_count
}

capture erase "`wb_rt'"
capture mata: mata drop _rcb_sites() _rcb_sentinel()
capture mata: mata drop _rcb_L
if `had_pkg_path' adopath ++ "`pkg_dir'"

**# Summary
display as result "RESULT: test_refactor_common_bundle tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rcb
if `fail_count' > 0 exit 1
