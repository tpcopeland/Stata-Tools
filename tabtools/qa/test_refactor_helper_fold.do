* test_refactor_helper_fold.do - tabtools 1.2.1 refactor: S1 helper fold, S2 move
* Covers:
*   H1  topology: the 40 folded helper files, _tabtools_xlsx_read.ado and the
*       9 helper files moved into _tabtools_common.ado (S3) are gone from the
*       package dir and from every f line of the .pkg; the reader lives in
*       qa/tools/; the .pkg stays far below the 100-line cap
*   H2  every folded program is a private subprogram of its host (host.sub)
*       once the host autoloads in a fresh session
*   H3  a private subprogram is not reachable as a global command (r(199))
*   H4  P5a stale shadow: an old helper file earlier on the adopath never
*       reaches the host, whose private copy wins
*   H5  P6 upgrade over 1.2.0: net install, replace leaves the dropped 1.2.0
*       files in PLUS/_ (documented), the new code still runs, and removing
*       both package entries removes the leftovers
*   H6  cold-session examples, one per host, each with a known answer
*   H7  per-program limits after run of each host: stored bytes < 135,600 and
*       source lines < 3,500
* Expected values come from the package source, the data, or arithmetic,
* never from the table under test.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rhf
log using "test_refactor_helper_fold.log", replace text name(_rhf)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local fixture_dir "`qa_dir'/data/p6_tabtools_120"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

* The 40 helper files folded in 1.2.1 (S1), their host, and the programs each
* defined. _tabtools_fitcount.ado also held _tabtools_fitcount_rec.
local regtab_subs _tabtools_match_rows _regtab_activeb _regtab_addcol ///
    _regtab_addrow _regtab_cellnote _regtab_classes _regtab_cmdopts ///
    _regtab_cmdsets _regtab_collabels _regtab_eqkeys _regtab_estats ///
    _regtab_fitrec _regtab_flatten _regtab_frameopts _regtab_fvbase ///
    _regtab_fvparent _regtab_keys _regtab_methods _regtab_mincount ///
    _regtab_modelnoun _regtab_mstats _regtab_optstr _regtab_prefopts ///
    _regtab_relabel _regtab_remeta _regtab_rlabels _regtab_role ///
    _regtab_scale _regtab_statrows _regtab_statspec _regtab_unwrap
local desctab_subs _desctab_collect _desctab_misscell
local tabcell_subs _tabcell_render _tabtools_fmt_p
local tabtools_subs _tabtools_fitcount _tabtools_fitcount_rec _tabtools_set
local stacktab_subs _stacktab_frames
local effecttab_subs _tabtools_collect_atmatrix
local xcs_subs _tabtools_xlsx_deferred_styles
* Host keys: a key names its host .ado; xcs is _tabtools_xlsx_compact_styles,
* whose name is too long to build 31-character local names from.
local keys regtab desctab tabcell tabtools stacktab effecttab xcs
foreach k of local keys {
    local host_`k' "`k'"
}
local host_xcs "_tabtools_xlsx_compact_styles"
local folded_files ""
local folded_progs ""
foreach k of local keys {
    foreach s of local `k'_subs {
        local folded_progs "`folded_progs' `s'"
        if "`s'" != "_tabtools_fitcount_rec" local folded_files "`folded_files' `s'.ado"
    }
}
* The 9 Mata-free multi-caller helper files moved into _tabtools_common.ado
* (S3); their programs keep their global names.
local bundled_files _regtab_bnotes.ado _tabtools_colwidth.ado ///
    _tabtools_export_hint.ado _tabtools_fmt_pct.ado ///
    _tabtools_smallcells_opt.ado _tabtools_smallcells_render.ado ///
    _tabtools_st_timescale.ado _tabtools_texopts.ado ///
    _tabtools_visible_vars.ado
local gone_files "`folded_files' _tabtools_xlsx_read.ado `bundled_files'"

* Fresh state for H2: no tabtools program in memory. The suite's own helpers
* are defined after this point and are not autoloaded, so discard keeps them.
program drop _all
discard

**# Helpers
* program dir, captured to a file (with the suite log paused) and parsed into
* Mata: _rhf_pdN holds each program's name, _rhf_pdB its stored bytes.
capture mata: mata drop _rhf_pd_load() _rhf_pd_bytes() _rhf_spans()
mata:
void _rhf_pd_load(string scalar fn)
{
    external string colvector _rhf_pdN
    external real colvector _rhf_pdB
    string colvector L
    string scalar re

    re = "^ *(ado)? +[0-9]+ +[A-Za-z_][A-Za-z0-9_.]*$"
    L = cat(fn)
    if (rows(L)) L = select(L, ustrregexm(L, re))
    if (rows(L) == 0) {
        _rhf_pdN = J(0, 1, "")
        _rhf_pdB = J(0, 1, .)
        return
    }
    _rhf_pdN = ustrregexra(L, "^ *(ado)? +[0-9]+ +", "")
    _rhf_pdB = strtoreal(ustrregexra(ustrregexra(L, "^ *(ado)? +", ""), ///
        " +[A-Za-z_][A-Za-z0-9_.]*$", ""))
}

// Stored bytes of program `name' in the last snapshot; -1 when absent.
real scalar _rhf_pd_bytes(string scalar name)
{
    external string colvector _rhf_pdN
    external real colvector _rhf_pdB
    real colvector i

    i = selectindex(_rhf_pdN :== name)
    if (rows(i) == 0) return(-1)
    return(max(_rhf_pdB[i]))
}

// Every program a source file defines: locals nprogs, prog_k and plines_k
// (lines from the program line through the first end line after it).
void _rhf_spans(string scalar fn)
{
    string colvector L, T
    string scalar nm, re
    real scalar i, j, k

    re = "^[ \t]*program[ \t]+(define[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*(,.*)?$"
    L = cat(fn)
    T = strtrim(L)
    k = 0
    for (i = 1; i <= rows(L); i++) {
        if (!ustrregexm(L[i], re)) continue
        nm = ustrregexra(L[i], "^[ \t]*program[ \t]+(define[ \t]+)?", "")
        nm = strtrim(ustrregexra(nm, "[ \t]*,.*$", ""))
        if (anyof(("drop", "dir", "list"), nm)) continue
        for (j = i + 1; j <= rows(L); j++) {
            if (T[j] == "end") break
        }
        if (j > rows(L)) _error(3498, "no end line after program " + nm)
        k++
        st_local("prog_" + strofreal(k), nm)
        st_local("plines_" + strofreal(k), strofreal(j - i + 1))
    }
    st_local("nprogs", strofreal(k))
}
end

* program dir snapshot; the listing goes to a temp file only.
capture program drop _rhf_progdir
program define _rhf_progdir, nclass
    version 17.0
    tempfile pd
    capture quietly log off _rhf
    quietly log using "`pd'", text replace name(_rhfpd) nomsg
    noisily program dir
    quietly log close _rhfpd
    capture quietly log on _rhf
    mata: _rhf_pd_load(st_local("pd"))
end

* Run a command with its console output captured to file `1'; the command's
* return code comes back in local `2' of the caller.
capture program drop _rhf_cap
program define _rhf_cap, nclass
    version 17.0
    gettoken logf 0 : 0
    gettoken rcname 0 : 0
    quietly log using "`logf'", text replace name(_rhfcap) nomsg
    capture noisily `0'
    local rc = _rc
    quietly log close _rhfcap
    c_local `rcname' `rc'
end

* Identical, nonempty text files.
capture program drop _rhf_same
program define _rhf_same, nclass
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

* One example per host. Each sets up its own data.
capture program drop _rhf_ex_regtab
program define _rhf_ex_regtab
    version 17.0
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg i.foreign
    regtab, addrow("Extra row" 1) frame(_rhf_rt, replace flat)
end
capture program drop _rhf_ex_desctab
program define _rhf_ex_desctab
    version 17.0
    sysuse auto, clear
    desctab price mpg rep78, by(foreign)
end
capture program drop _rhf_ex_tabcell
program define _rhf_ex_tabcell
    version 17.0
    tabcell np, n(5) d(20)
    tabcell p, p(0.0312)
end
capture program drop _rhf_ex_tabtools
program define _rhf_ex_tabtools
    version 17.0
    sysuse auto, clear
    collect clear
    quietly collect: poisson foreign mpg
    tabtools fitcount, events(foreign) people(headroom)
    regtab, stats(events people)
end
capture program drop _rhf_ex_stacktab
program define _rhf_ex_stacktab
    version 17.0
    args wb
    capture erase "`wb'"
    capture frame drop _rhf_fa
    capture frame drop _rhf_fb
    frame create _rhf_fa
    frame _rhf_fa {
        quietly set obs 2
        quietly generate str8 lab = word("Mean Median", _n)
        quietly generate str8 v1 = word("1.5 2.0", _n)
    }
    frame copy _rhf_fa _rhf_fb
    stacktab using "`wb'", frames(_rhf_fa "A" \ _rhf_fb "B") sheet("S")
end
capture program drop _rhf_ex_effecttab
program define _rhf_ex_effecttab
    version 17.0
    sysuse auto, clear
    quietly logit foreign c.mpg
    collect clear
    quietly collect: margins, at(mpg=(20 30))
    matrix _rhf_mb = r(b)
    effecttab, frame(_rhf_ef, replace)
end
capture program drop _rhf_ex_puttab
program define _rhf_ex_puttab
    version 17.0
    args x
    capture erase "`x'"
    sysuse auto, clear
    puttab make price mpg in 1/4 using "`x'", sheet("S") zebra
end

local wb_st "`output_dir'/rhf_stacktab.xlsx"
local wb_pt "`output_dir'/rhf_puttab.xlsx"
local ex_regtab "_rhf_ex_regtab"
local ex_desctab "_rhf_ex_desctab"
local ex_tabcell "_rhf_ex_tabcell"
local ex_tabtools "_rhf_ex_tabtools"
local ex_stacktab `"_rhf_ex_stacktab "`wb_st'""'
local ex_effecttab "_rhf_ex_effecttab"
local ex_xcs `"_rhf_ex_puttab "`wb_pt'""'

**# H1 Topology
* H1a: none of the 50 files is in the package dir or on any f/F line; the
* reader is in qa/tools/; the f-line count stays far below Stata's r(640) cap.
local ++test_count
capture noisily {
    local n_bundled : list sizeof bundled_files
    assert `n_bundled' == 9
    local n_gone : list sizeof gone_files
    * history: 41 after S1 + S2; 50 since S3
    assert `n_gone' == 50
    local n_progs : list sizeof folded_progs
    assert `n_progs' == 41
    mata: _rhf_pkg = cat(st_local("pkg_dir") + "/tabtools.pkg")
    mata: _rhf_pkgf = select(_rhf_pkg, ustrregexm(_rhf_pkg, "^[fF] "))
    mata: _rhf_pkgf = strtrim(substr(_rhf_pkgf, 3, .))
    mata: st_local("n_f", strofreal(rows(_rhf_pkgf)))
    display as text "tabtools.pkg f lines: `n_f'"
    * history: ceiling <= 60 after S1 + S2 (55 lines); <= 50 since S3 (46)
    assert `n_f' > 0 & `n_f' <= 50
    foreach f of local gone_files {
        capture confirm file "`pkg_dir'/`f'"
        assert _rc == 601
        mata: st_local("on_pkg", strofreal(anyof(_rhf_pkgf, st_local("f"))))
        assert `on_pkg' == 0
    }
    capture mata: mata drop _rhf_pkg _rhf_pkgf
    confirm file "`qa_dir'/tools/_tabtools_xlsx_read.ado"
    * every host is still shipped
    foreach k of local keys {
        capture confirm file "`pkg_dir'/`host_`k''.ado"
        assert _rc == 0
    }
}
if _rc == 0 {
    display as result "  PASS: H1a 50 helper files gone from dir and .pkg; reader in qa/tools; f lines <= 50"
    local ++pass_count
}
else {
    display as error "  FAIL: H1a topology (rc=`=_rc')"
    local ++fail_count
}

**# H2 Private presence after autoload
* H2a: in a fresh state (program drop _all and discard above; no host in
* memory, checked), each host's example autoloads the host, and every
* program folded into it is listed by program dir as host.sub. The snapshot
* is taken right after each host's call, because set adosize lets Stata
* evict autoloaded programs that were used earlier.
local ++test_count
capture noisily {
    discard
    _rhf_progdir
    foreach k of local keys {
        mata: st_local("hb", strofreal(_rhf_pd_bytes(st_local("host_`k'"))))
        assert `hb' == -1
    }
    foreach k of local keys {
        local h "`host_`k''"
        quietly `ex_`k''
        _rhf_progdir
        mata: st_local("hb", strofreal(_rhf_pd_bytes(st_local("h"))))
        assert `hb' > 0
        foreach s of local `k'_subs {
            mata: st_local("sb", strofreal(_rhf_pd_bytes(st_local("h") + "." + st_local("s"))))
            mata: st_local("gb", strofreal(_rhf_pd_bytes(st_local("s"))))
            display as text "  `h'.`s': `sb' bytes (global copy: `gb')"
            assert `sb' > 0
            assert `gb' == -1
        }
    }
}
if _rc == 0 {
    display as result "  PASS: H2a all 41 folded programs load as private host.sub programs"
    local ++pass_count
}
else {
    display as error "  FAIL: H2a private presence (rc=`=_rc')"
    local ++fail_count
}

* H2b: a public command that is not itself a host reaches a folded program
* through its host: puttab loads
* _tabtools_xlsx_compact_styles._tabtools_xlsx_deferred_styles.
local ++test_count
capture noisily {
    discard
    quietly _rhf_ex_puttab "`wb_pt'"
    _rhf_progdir
    mata: st_local("b1", strofreal(_rhf_pd_bytes("_tabtools_xlsx_compact_styles._tabtools_xlsx_deferred_styles")))
    mata: st_local("b2", strofreal(_rhf_pd_bytes("_tabtools_xlsx_deferred_styles")))
    assert `b1' > 0
    assert `b2' == -1
}
if _rc == 0 {
    display as result "  PASS: H2b puttab loads the deferred-styles engine privately"
    local ++pass_count
}
else {
    display as error "  FAIL: H2b puttab deferred styles (rc=`=_rc')"
    local ++fail_count
}

**# H3 Private subprograms are not global commands
* H3a: no folded program, and not the moved reader, resolves from the do-file.
local ++test_count
capture noisily {
    quietly _rhf_ex_regtab
    capture _regtab_addrow
    assert _rc == 199
    foreach p of local folded_progs {
        capture `p'
        local rc = _rc
        if `rc' != 199 display as error "`p': rc `rc'"
        assert `rc' == 199
    }
    capture _tabtools_xlsx_read
    assert _rc == 199
}
if _rc == 0 {
    display as result "  PASS: H3a folded programs and the moved reader give r(199) from the do-file"
    local ++pass_count
}
else {
    display as error "  FAIL: H3a private subprograms reachable globally (rc=`=_rc')"
    local ++fail_count
}

**# H4 P5a: a stale helper file ahead on the adopath does not shadow
* H4a: the same examples give rc 0 and byte-identical console output with a
* directory of stale _regtab_addrow/_desctab_collect/_tabcell_render files
* (each prints STALE and exits 9) placed ahead of the package; a bare call
* proves the stale directory really was reachable.
local ++test_count
tempfile stale_tok
local stale_dir "`stale_tok'_rhf_stale"
foreach h in regtab desctab tabcell {
    tempfile base_`h' stale_`h' p6_`h'
}
capture noisily {
    capture mkdir "`stale_dir'"
    foreach s in _regtab_addrow _desctab_collect _tabcell_render {
        tempname fh
        file open `fh' using "`stale_dir'/`s'.ado", write text replace
        file write `fh' "*! `s' stale stub (test_refactor_helper_fold H4)" _n
        file write `fh' "program define `s'" _n
        file write `fh' `"    display as error "STALE""' _n
        file write `fh' "    exit 9" _n
        file write `fh' "end" _n
        file close `fh'
    }
    foreach h in regtab desctab tabcell {
        discard
        _rhf_cap "`base_`h''" rc `ex_`h''
        assert `rc' == 0
    }
    adopath ++ "`stale_dir'"
    foreach h in regtab desctab tabcell {
        discard
        _rhf_cap "`stale_`h''" rc `ex_`h''
        assert `rc' == 0
        _rhf_same "`base_`h''" "`stale_`h''"
        mata: st_local("hit", strofreal(any(strpos(cat(st_local("stale_`h'")), "STALE"))))
        assert `hit' == 0
    }
    foreach s in _regtab_addrow _desctab_collect _tabcell_render {
        capture noisily `s'
        assert _rc == 9
        capture program drop `s'
    }
}
local h4_rc = _rc
capture adopath - "`stale_dir'"
foreach s in _regtab_addrow _desctab_collect _tabcell_render {
    capture program drop `s'
    capture erase "`stale_dir'/`s'.ado"
}
capture rmdir "`stale_dir'"
discard
if `h4_rc' == 0 {
    display as result "  PASS: H4a stale helper files ahead on the adopath never reach the hosts"
    local ++pass_count
}
else {
    display as error "  FAIL: H4a stale-shadow probe (rc=`h4_rc')"
    local ++fail_count
}

**# H5 P6: net install over 1.2.0
* H5a: a minimal 1.2.0 install (qa/data/p6_tabtools_120: three helper files
* that 1.2.1 folds, byte-identical to 1.2.0) into a scratch PLUS, then the
* new tree with replace. The 1.2.0 files stay in PLUS/_ beside a second
* package entry (P6), and the examples still give rc 0 and the new output.
* Removing both entries, highest index first, removes the leftovers.
local ++test_count
local orig_plus "`c(sysdir_plus)'"
tempfile p6_tok
local p6_plus "`p6_tok'_rhf_p6plus"
capture noisily {
    confirm file "`fixture_dir'/tabtools.pkg"
    capture mkdir "`p6_plus'"
    sysdir set PLUS "`p6_plus'/"
    discard
    net install tabtools, from("`fixture_dir'")
    foreach s in _regtab_addrow _desctab_collect _tabcell_render {
        confirm file "`p6_plus'/_/`s'.ado"
    }
    net install tabtools, from("`pkg_dir'") replace
    mata: _rhf_trk = cat(st_local("p6_plus") + "/stata.trk")
    mata: st_local("n_entries", strofreal(sum(_rhf_trk :== "N tabtools.pkg")))
    display as text "stata.trk tabtools entries after the upgrade: `n_entries'"
    assert `n_entries' == 2
    * P6, documented: the dropped 1.2.0 helper files are still installed,
    * byte-identical to the fixture
    foreach s in _regtab_addrow _desctab_collect _tabcell_render {
        confirm file "`p6_plus'/_/`s'.ado"
        mata: st_local("same", strofreal(cat(st_local("p6_plus") + "/_/`s'.ado") == ///
            cat(st_local("fixture_dir") + "/`s'.ado")))
        assert `same'
    }
    confirm file "`p6_plus'/r/regtab.ado"
    foreach h in regtab desctab tabcell {
        discard
        _rhf_cap "`p6_`h''" rc `ex_`h''
        assert `rc' == 0
        _rhf_same "`base_`h''" "`p6_`h''"
    }
    * the private copy wins over the leftover file of the same name
    quietly _rhf_ex_regtab
    _rhf_progdir
    mata: st_local("pb", strofreal(_rhf_pd_bytes("regtab._regtab_addrow")))
    mata: st_local("gb", strofreal(_rhf_pd_bytes("_regtab_addrow")))
    assert `pb' > 0 & `gb' == -1
    discard
    * two entries: the name criterion matches both (r(111), P6); remove by index
    capture noisily ado uninstall tabtools
    local un_rc = _rc
    display as text "ado uninstall tabtools with two entries: rc `un_rc'"
    assert inlist(`un_rc', 0, 111)
    if `un_rc' == 111 {
        ado uninstall [2]
        ado uninstall [1]
    }
    foreach s in _regtab_addrow _desctab_collect _tabcell_render {
        capture confirm file "`p6_plus'/_/`s'.ado"
        assert _rc == 601
    }
    capture confirm file "`p6_plus'/r/regtab.ado"
    assert _rc == 601
    mata: _rhf_trk = cat(st_local("p6_plus") + "/stata.trk")
    mata: st_local("n_left", strofreal(sum(_rhf_trk :== "N tabtools.pkg")))
    assert `n_left' == 0
}
local h5_rc = _rc
capture mata: mata drop _rhf_trk
sysdir set PLUS "`orig_plus'"
discard
capture shell rm -rf "`p6_plus'"
if `h5_rc' == 0 {
    display as result "  PASS: H5a upgrade over 1.2.0 keeps working; leftovers removed by index"
    local ++pass_count
}
else {
    display as error "  FAIL: H5a upgrade-over-1.2.0 probe (rc=`h5_rc')"
    local ++fail_count
}

**# H6 Cold-session examples, one per host
* H6a regtab addrow(): the added row is in the frame with its value.
local ++test_count
capture noisily {
    discard
    _rhf_ex_regtab
    frame _rhf_rt {
        quietly count if strtrim(rowlabel) == "Extra row" & strtrim(c1) == "1"
        assert r(N) == 1
        quietly count if strtrim(rowlabel) == "Foreign"
        assert r(N) == 1
    }
    frame drop _rhf_rt
}
if _rc == 0 {
    display as result "  PASS: H6a regtab addrow() row in a cold session"
    local ++pass_count
}
else {
    display as error "  FAIL: H6a regtab cold session (rc=`=_rc')"
    local ++fail_count
}

* H6b desctab: runs cold and reports the variables it tabulated.
local ++test_count
capture noisily {
    discard
    _rhf_ex_desctab
    assert "`r(varlist)'" == "price mpg rep78"
    confirm matrix r(table)
}
if _rc == 0 {
    display as result "  PASS: H6b desctab in a cold session"
    local ++pass_count
}
else {
    display as error "  FAIL: H6b desctab cold session (rc=`=_rc')"
    local ++fail_count
}

* H6c tabcell, scalar (frame-block) path and generate() path: 5 of 20 is
* 25.0%, p = 0.0312 prints at three decimals.
local ++test_count
capture noisily {
    discard
    tabcell np, n(5) d(20)
    assert "`r(cell)'" == "5 (25.0)"
    discard
    tabcell p, p(0.0312)
    assert "`r(cell)'" == "0.031"
    discard
    clear
    quietly set obs 2
    generate n = 5 * _n
    generate d = 20
    tabcell np, n(n) d(d) generate(cell)
    assert cell[1] == "5 (25.0)"
    assert cell[2] == "10 (50.0)"
}
if _rc == 0 {
    display as result "  PASS: H6c tabcell frame-block and generate() paths in a cold session"
    local ++pass_count
}
else {
    display as error "  FAIL: H6c tabcell cold session (rc=`=_rc')"
    local ++fail_count
}

* H6d tabtools fitcount, then regtab stats(events people): the events are the
* outcome count in the estimation sample, from the data.
local ++test_count
capture noisily {
    discard
    sysuse auto, clear
    quietly count if foreign == 1
    local nev = r(N)
    _rhf_ex_tabtools
    assert r(events_1) == `nev'
    assert `nev' == 22
}
if _rc == 0 {
    display as result "  PASS: H6d tabtools fitcount -> regtab stats(events) in a cold session"
    local ++pass_count
}
else {
    display as error "  FAIL: H6d fitcount cold session (rc=`=_rc')"
    local ++fail_count
}

* H6e stacktab frames(): both panels are written, each with its Mean row.
local ++test_count
capture noisily {
    discard
    _rhf_ex_stacktab "`wb_st'"
    assert "`r(sheet)'" == "S"
    import excel using "`wb_st'", sheet("S") clear allstring
    local n_mean = 0
    foreach v of varlist _all {
        quietly count if strtrim(`v') == "Mean"
        local n_mean = `n_mean' + r(N)
    }
    assert `n_mean' == 2
    capture frame drop _rhf_fa
    capture frame drop _rhf_fb
}
if _rc == 0 {
    display as result "  PASS: H6e stacktab frames() in a cold session"
    local ++pass_count
}
else {
    display as error "  FAIL: H6e stacktab cold session (rc=`=_rc')"
    local ++fail_count
}

* H6f effecttab after margins, at(): the at() rows are named by their
* scenario and carry margins' own estimate.
local ++test_count
capture noisily {
    discard
    _rhf_ex_effecttab
    local lab : variable label mpg
    local e20 = strofreal(round(_rhf_mb[1, 1], 0.01), "%4.2f")
    local e30 = strofreal(round(_rhf_mb[1, 2], 0.01), "%4.2f")
    frame _rhf_ef {
        quietly count if strtrim(A) == "`lab' = 20" & strtrim(c1) == "`e20'"
        assert r(N) == 1
        quietly count if strtrim(A) == "`lab' = 30" & strtrim(c1) == "`e30'"
        assert r(N) == 1
    }
    frame drop _rhf_ef
    matrix drop _rhf_mb
}
if _rc == 0 {
    display as result "  PASS: H6f effecttab margins at() rows in a cold session"
    local ++pass_count
}
else {
    display as error "  FAIL: H6f effecttab cold session (rc=`=_rc')"
    local ++fail_count
}

* H6g puttab (host of the deferred-styles engine): the workbook holds the data.
local ++test_count
capture noisily {
    discard
    sysuse auto, clear
    local make1 = make[1]
    _rhf_ex_puttab "`wb_pt'"
    import excel using "`wb_pt'", sheet("S") clear allstring
    local hit = 0
    foreach v of varlist _all {
        quietly count if strtrim(`v') == "`make1'"
        local hit = `hit' + r(N)
    }
    assert `hit' == 1
}
if _rc == 0 {
    display as result "  PASS: H6g puttab workbook in a cold session"
    local ++pass_count
}
else {
    display as error "  FAIL: H6g puttab cold session (rc=`=_rc')"
    local ++fail_count
}

**# H7 Per-program limits
* H7a: after run of each host, every program it defines is in memory with a
* stored size under 135,600 bytes and a source span under 3,500 lines, and
* the run leaves c(matastrict) as it was. The programs are dropped again
* afterwards so later code autoloads as an installed user would.
local ++test_count
capture noisily {
    foreach k of local keys {
        local h "`host_`k''"
        discard
        quietly findfile `h'.ado
        local fn "`r(fn)'"
        mata: _rhf_spans(st_local("fn"))
        assert `nprogs' >= 2
        forvalues j = 1/`nprogs' {
            capture program drop `prog_`j''
        }
        local ms0 = c(matastrict)
        run "`fn'"
        assert c(matastrict) == "`ms0'"
        _rhf_progdir
        local maxb = 0
        local maxl = 0
        forvalues j = 1/`nprogs' {
            mata: st_local("b", strofreal(_rhf_pd_bytes(st_local("prog_`j'"))))
            assert `b' > 0 & `b' < 135600
            assert `plines_`j'' < 3500
            if `b' > `maxb' {
                local maxb = `b'
                local maxp "`prog_`j''"
            }
            local maxl = max(`maxl', `plines_`j'')
        }
        display as text "  `h'.ado: `nprogs' programs; largest `maxp' `maxb' B; longest span `maxl' lines"
        if "`h'" == "regtab" {
            mata: st_local("rb", strofreal(_rhf_pd_bytes("regtab")))
            display as text "  regtab stored bytes: `rb'"
        }
        * every program folded into this host is among the ones it defines
        * (the span loops index with j: an inner forvalues k once cleared the
        * host key, so this list difference compared nothing)
        local defined ""
        forvalues j = 1/`nprogs' {
            local defined "`defined' `prog_`j''"
        }
        local n_subs : list sizeof `k'_subs
        assert `n_subs' >= 1
        local missing : list `k'_subs - defined
        assert "`missing'" == ""
        forvalues j = 1/`nprogs' {
            capture program drop `prog_`j''
        }
    }
    discard
}
if _rc == 0 {
    display as result "  PASS: H7a every host program < 135,600 B and < 3,500 lines; matastrict kept"
    local ++pass_count
}
else {
    display as error "  FAIL: H7a per-program limits (rc=`=_rc')"
    local ++fail_count
}

capture mata: mata drop _rhf_pd_load() _rhf_pd_bytes() _rhf_spans()
capture mata: mata drop _rhf_pdN _rhf_pdB
capture erase "`wb_st'"
capture erase "`wb_pt'"

**# Summary
display as result "RESULT: test_refactor_helper_fold tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rhf
if `fail_count' > 0 exit 1
