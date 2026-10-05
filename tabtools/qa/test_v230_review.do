* test_v230_review.do - regression tests for defects found in the independent
* review of the 2.3.0 slice (smallcells primary, session targets, footnote
* paragraphs, puttab spanheader, stacktab frames()).
*
* Every expectation is computed from an independent route (count/tabulate,
* file contents read back, workbook sheets listed by import excel), never
* from the command's own returns alone.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rv230
log using "test_v230_review.log", replace text name(_rv230)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* Lines of a text file into Mata vector _L.
capture program drop _rv_lines
program define _rv_lines
    version 17.0
    args file
    mata: _L = cat(st_local("file"))
end

**# R1: smallcells(#, primary) with slashN prints every denominator as computed
* Contract (desctab.sthlp): primary masks each printed count 1..#-1 as <# and
* "nothing else changes". A denominator >= # must print as computed, never as
* "Suppressed" (that derived withholding belongs to the full mode only).
local ++test_count
capture noisily {
    foreach ms in "" "missingsummary" {
        sysuse auto, clear
        * oracle: non-missing rep78 per group and level counts
        forvalues g = 0/1 {
            quietly count if foreign == `g' & !missing(rep78)
            local den`g' = r(N)
            forvalues l = 1/5 {
                quietly count if foreign == `g' & rep78 == `l'
                local n`g'_`l' = r(N)
            }
            quietly count if foreign == `g' & missing(rep78)
            local m`g' = r(N)
        }
        desctab rep78, by(foreign) slashN `ms' smallcells(5, primary) clear
        assert "`r(smallcells_mode)'" == "primary"
        assert r(N_derived_suppressed) == 0
        assert r(N_secondary_suppressed) == 0
        local nprim = r(N_primary_suppressed)
        local nmask 0
        forvalues g = 0/1 {
            quietly count if strpos(foreign_`g', "Suppressed")
            assert r(N) == 0
            forvalues l = 1/5 {
                quietly levelsof foreign_`g' if strtrim(factor) == "`l'", local(cell) clean
                local n = `n`g'_`l''
                if inrange(`n', 1, 4) {
                    assert `"`cell'"' == "<5"
                    local ++nmask
                }
                else assert strpos(`"`cell'"', "`n'/`den`g''") == 1
            }
            if "`ms'" != "" & inrange(`m`g'', 1, 4) local ++nmask
        }
        * every printed count 1..4 is masked, and only those are counted
        assert `nprim' == `nmask'
    }
}
if _rc == 0 {
    display as result "  PASS: R1 primary + slashN prints denominators as computed"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 primary + slashN denominators (rc=`=_rc')"
    local ++fail_count
}

**# R2: an explicit xlsx()/markdown() naming the session target counts as its write
* A table written with an explicit option to the session workbook/Markdown
* file after -tabtools set- must survive the next session write (the session
* write used to erase the workbook / overwrite the Markdown file because the
* explicit write never cleared the "first write replaces" flag).
local ++test_count
capture noisily {
    local here "`c(pwd)'"
    quietly cd "`output_dir'"
    capture erase "rv230_same.xlsx"
    capture erase "rv230_other.xlsx"
    capture erase "rv230_same.md"
    sysuse auto, clear
    * stale content from before tabtools set: replaced by the first write
    puttab make mpg in 1/2 using "rv230_same.xlsx", sheet("Stale") markdown("rv230_same.md")
    tabtools set workbook "rv230_same.xlsx"
    tabtools set markdown "rv230_same.md"
    * explicit options, named absolutely, to the same files
    desctab mpg, by(foreign) excel("`output_dir'/rv230_same.xlsx") sheet("Explicit")
    puttab make mpg in 1/3 using "rv230_other.xlsx", sheet("X") ///
        markdown("`output_dir'/rv230_same.md") title("Explicit table")
    * a command with no session support, named relatively: also kept
    collect clear
    collect: regress price mpg
    regtab, xlsx("./rv230_same.xlsx") sheet("Reg") coef("Coef.")
    tabtools query
    assert "`r(workbook_fresh)'" == "0"
    assert "`r(markdown_fresh)'" == "0"
    * session writes
    puttab make mpg in 4/6, sheet("Session") title("Session table")
    quietly import excel using "rv230_same.xlsx", describe
    local sheets ""
    forvalues i = 1/`r(N_worksheet)' {
        local sheets "`sheets' `r(worksheet_`i')'"
    }
    local sheets : list sort sheets
    assert "`sheets'" == "Explicit Reg Session"
    _rv_lines "rv230_same.md"
    mata: st_local("n1", strofreal(sum(strpos(_L, "Explicit table") :> 0)))
    mata: st_local("n2", strofreal(sum(strpos(_L, "Session table") :> 0)))
    mata: st_local("n3", strofreal(sum(strpos(_L, "Stale") :> 0)))
    assert `n1' == 1 & `n2' == 1 & `n3' == 0
    tabtools set clear
    quietly cd "`here'"
}
if _rc {
    local _rc_save = _rc
    capture cd "`here'"
    tabtools set clear
}
else local _rc_save 0
if `_rc_save' == 0 {
    display as result "  PASS: R2 explicit write to the session target is kept"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 explicit write to the session target (rc=`_rc_save')"
    local ++fail_count
}

**# R3: generated notes stay separate paragraphs of a paragraph footnote
* The smallcells notice (desctab/crosstab) and corrtab's star legend were
* glued onto the user's last paragraph in every sink. With " \ " in the
* footnote, each is its own paragraph (row / CSV line / Markdown paragraph).
local ++test_count
capture noisily {
    local csv "`output_dir'/rv230_r3.csv"
    local md "`output_dir'/rv230_r3.md"
    sysuse auto, clear
    crosstab rep78 foreign, smallcells(3) footnote("A1. \ A2.") csv("`csv'") markdown("`md'")
    _rv_lines "`csv'"
    mata: st_local("a2", strofreal(sum(_L :== "A2.,,,")))
    mata: st_local("sc", strofreal(sum(substr(_L, 1, 16) :== "Counts below 3 a")))
    assert `a2' == 1 & `sc' == 1
    _rv_lines "`md'"
    mata: st_local("a2", strofreal(sum(_L :== "*A2.*")))
    assert `a2' == 1
    sysuse auto, clear
    desctab rep78, by(foreign) smallcells(3) footnote("D1. \ D2.") csv("`csv'")
    _rv_lines "`csv'"
    mata: st_local("d2", strofreal(sum(_L :== "D2.,,,")))
    mata: st_local("sc", strofreal(sum(substr(_L, 1, 16) :== "Counts below 3 a")))
    assert `d2' == 1 & `sc' == 1
    corrtab mpg price weight, footnote("C1. \ C2.") csv("`csv'") markdown("`md'")
    _rv_lines "`csv'"
    mata: st_local("c2", strofreal(sum(_L :== "C2.,,,")))
    mata: st_local("lg", strofreal(sum(substr(_L, 1, 9) :== char(34) + "* p<0.05")))
    assert `c2' == 1 & `lg' == 1
    _rv_lines "`md'"
    mata: st_local("c2", strofreal(sum(_L :== "*C2.*")))
    assert `c2' == 1
    * one-paragraph footnotes keep the 2.2.0 join
    corrtab mpg price weight, footnote("Plain.") csv("`csv'")
    _rv_lines "`csv'"
    mata: st_local("pl", strofreal(sum(substr(_L, 1, 16) :== char(34) + "Plain. * p<0.05")))
    assert `pl' == 1
}
if _rc == 0 {
    display as result "  PASS: R3 generated notes are their own paragraphs"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 generated notes as paragraphs (rc=`=_rc')"
    local ++fail_count
}

**# R4: a one-column span prints no stray error text
* Mata regexs() on the unmatched "/last" group printed "invalid number,
* outside of allowed range" once per one-column span (rc stayed 0).
local ++test_count
capture noisily {
    local book "`output_dir'/rv230_r4.xlsx"
    local lg "`output_dir'/rv230_r4.log"
    capture erase "`book'"
    sysuse auto, clear
    keep in 1/4
    log using "`lg'", text replace name(_rv4)
    puttab make price rep78 using "`book'", sheet("S") spanheader("A" 2 \ "B" 3)
    local n_spans = r(n_spans)
    log close _rv4
    assert `n_spans' == 2
    _rv_lines "`lg'"
    mata: st_local("bad", strofreal(sum(strpos(_L, "invalid number") :> 0)))
    assert `bad' == 0
}
if _rc == 0 {
    display as result "  PASS: R4 one-column spans parse silently"
    local ++pass_count
}
else {
    local _rc_save = _rc
    capture log close _rv4
    display as error "  FAIL: R4 one-column span noise (rc=`_rc_save')"
    local ++fail_count
}

**# R5: stacktab frames() keeps one panel per frame when labels repeat
* The panel variable was the label text, so two adjacent frames with the same
* label fused into one panel: one heading, the second frame's rows under it.
local ++test_count
capture noisily {
    local md "`output_dir'/rv230_r5.md"
    local book "`output_dir'/rv230_r5.xlsx"
    capture erase "`book'"
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) frame(rv5a, replace)
    table1_tc, by(foreign) vars(mpg contn) frame(rv5b, replace)
    stacktab using "`book'", frames(rv5a "Same" \ rv5b "Same") sheet("F") markdown("`md'")
    assert r(n_panels) == 2
    _rv_lines "`md'"
    mata: st_local("nh", strofreal(sum(substr(_L, 1, 10) :== "| **Same**")))
    assert `nh' == 2
    * an unlabeled frame still gets no heading
    stacktab using "`book'", frames(rv5a "A" \ rv5b) sheet("G") markdown("`md'")
    assert r(n_panels) == 1
    _rv_lines "`md'"
    mata: st_local("nh", strofreal(sum(substr(_L, 1, 4) :== "| **")))
    assert `nh' == 1
    frame drop rv5a
    frame drop rv5b
}
if _rc == 0 {
    display as result "  PASS: R5 one panel per frame"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 stacktab frames() panels (rc=`=_rc')"
    local ++fail_count
}

* Sheet names of a workbook, sorted, into local `sheets' of the caller.
capture program drop _rv_sheets
program define _rv_sheets
    version 17.0
    args book
    quietly import excel using "`book'", describe
    local sh ""
    forvalues i = 1/`r(N_worksheet)' {
        local sh "`sh' `r(worksheet_`i')'"
    }
    local sh : list sort sh
    c_local sheets "`sh'"
end

**# R6: re-setting a target never erases a file this session already wrote
* A -> B -> A: going back to A must keep A's earlier sheets (and Markdown).
* Setting the current target again is a no-op that says writes are added.
local ++test_count
capture noisily {
    local A "`output_dir'/rv230_A.xlsx"
    local B "`output_dir'/rv230_B.xlsx"
    local Am "`output_dir'/rv230_A.md"
    local Bm "`output_dir'/rv230_B.md"
    local lg "`output_dir'/rv230_r6.log"
    foreach f in A B Am Bm {
        capture erase "``f''"
    }
    tabtools set clear
    sysuse auto, clear
    tabtools set workbook "`A'"
    tabtools set markdown "`Am'"
    puttab make mpg in 1/2, sheet("A1") title("TA1")
    tabtools set workbook "`B'"
    tabtools set markdown "`Bm'"
    puttab make mpg in 1/2, sheet("B1") title("TB1")
    tabtools set workbook "`A'"
    tabtools set markdown "`Am'"
    tabtools query
    assert "`r(workbook_fresh)'" == "0" & "`r(markdown_fresh)'" == "0"
    puttab make mpg in 3/4, sheet("A2") title("TA2")
    _rv_sheets "`A'"
    assert "`sheets'" == "A1 A2"
    _rv_sheets "`B'"
    assert "`sheets'" == "B1"
    _rv_lines "`Am'"
    mata: st_local("n", strofreal(sum(_L :== "### TA1") + sum(_L :== "### TA2")))
    assert `n' == 2
    * same target again: no re-arm, and the echo says so
    capture log close _rv6
    local ls0 = c(linesize)
    set linesize 255
    log using "`lg'", text replace name(_rv6)
    tabtools set workbook "`A'"
    log close _rv6
    set linesize `ls0'
    _rv_lines "`lg'"
    mata: st_local("n", strofreal(sum(strpos(_L, "already the session workbook") :> 0)))
    assert `n' == 1
    * tabtools set clear does not forget what was written
    tabtools set clear
    tabtools set workbook "`A'"
    puttab make mpg in 5/6, sheet("A3")
    _rv_sheets "`A'"
    assert "`sheets'" == "A1 A2 A3"
    * a target never written this session is still started over
    tabtools set workbook "`B'"
    tabtools set clear
    puttab make mpg in 1/2 using "`output_dir'/rv230_C.xlsx", sheet("Old")
    tabtools set workbook "`output_dir'/rv230_D.xlsx"
    tabtools query
    assert "`r(workbook_fresh)'" == "1"
}
local _rc_save = _rc
capture log close _rv6
tabtools set clear
if `_rc_save' == 0 {
    display as result "  PASS: R6 A->B->A keeps A; same target is a no-op"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 re-arm data loss (rc=`_rc_save')"
    local ++fail_count
}

**# R7: the session target is stored absolute and normalised
local ++test_count
capture noisily {
    local here "`c(pwd)'"
    quietly cd "`output_dir'"
    local od "`c(pwd)'"
    capture mkdir "rv230_sub"
    capture erase "rv230_r7.xlsx"
    tabtools set workbook "./rv230_sub/..//rv230_r7.xlsx"
    assert `"$TABTOOLS_set_workbook"' == "`od'/rv230_r7.xlsx"
    tabtools set markdown "rv230_sub/./../rv230_r7.md"
    assert `"$TABTOOLS_set_markdown"' == "`od'/rv230_r7.md"
    quietly cd "`here'"
    sysuse auto, clear
    puttab make mpg in 1/2, sheet("S")
    confirm file "`od'/rv230_r7.xlsx"
    capture confirm file "`here'/rv230_r7.xlsx"
    assert _rc == 601
    tabtools set clear
}
local _rc_save = _rc
capture cd "`here'"
tabtools set clear
if `_rc_save' == 0 {
    display as result "  PASS: R7 absolute normalised session paths"
    local ++pass_count
}
else {
    display as error "  FAIL: R7 session path normalisation (rc=`_rc_save')"
    local ++fail_count
}

**# R8: puttab noheadershade overrides the session headershade for one call
local ++test_count
capture noisily {
    local book "`output_dir'/rv230_r8.xlsx"
    local out "`output_dir'/rv230_r8.txt"
    capture erase "`book'"
    sysuse auto, clear
    tabtools set headershade on
    puttab make mpg in 1/3 using "`book'", sheet("On")
    puttab make mpg in 1/3 using "`book'", sheet("Off") noheadershade
    capture puttab make mpg in 1/3 using "`book'", sheet("X") headershade noheadershade
    assert _rc == 198
    capture erase "`out'"
    shell python3 -c "import openpyxl,sys; wb=openpyxl.load_workbook(sys.argv[1]); f=lambda s: 'fill' if wb[s]['C2'].fill.fill_type else 'none'; open(sys.argv[2],'w').write(' '.join(f(s) for s in ['On','Off']))" "`book'" "`out'"
    _rv_lines "`out'"
    mata: st_local("got", _L[1])
    assert "`got'" == "fill none"
}
local _rc_save = _rc
tabtools set clear
if `_rc_save' == 0 {
    display as result "  PASS: R8 noheadershade"
    local ++pass_count
}
else {
    display as error "  FAIL: R8 noheadershade (rc=`_rc_save')"
    local ++fail_count
}

display "RESULT: test_v230_review tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rv230
if `fail_count' > 0 exit 1
