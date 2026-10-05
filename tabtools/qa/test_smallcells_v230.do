* test_smallcells_v230.do - smallcells(#, primary), nosmallcells, and the
* session smallcells default in desctab / table1_tc / crosstab (U3, W1)
*
* Contract (user decision 2026-09-30: masking governs what is printed):
* primary mode masks every PRINTED count from 1 to #-1 as <# with no
* percentage, adds no complementary cells, withholds no other percentage,
* and leaves tests as computed. The default (full) mode is unchanged.
* Expected cells are computed from tabulate's own counts, a route that does
* not pass through the tabtools engine.

clear all
set more off
set varabbrev off
version 17.0

capture log close _sc230
log using "test_smallcells_v230.log", replace text name(_sc230)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/sc230_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

**# Engine: primary masks printed 1..k-1 cells and margins only
local ++test_count
capture noisily {
    matrix C = (2, 0, 9 \ 3, 7, 1 \ 12, 6, 4)
    * the 1 at [2,3] is not printed (exact 0): never masked
    matrix E = (1, 1, 1 \ 1, 1, 0 \ 1, 1, 1)
    matrix S = J(3, 3, 1)
    matrix RE = (1 \ 1 \ 1)
    matrix CE = (1, 1, 1)
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) rowexact(RE) ///
        rowsensitive(RE) colexact(CE) colsensitive(CE) grandexact(1) ///
        grandsensitive(1) smallcells(5) primary
    assert "`r(mode)'" == "primary"
    matrix M = r(mask)
    matrix want = (1, 0, 0 \ 1, 0, 0 \ 0, 0, 1)
    assert mreldif(M, want) == 0
    * row totals 11, 11, 22 and column totals 17, 13, 14: none small
    matrix z31 = J(3, 1, 0)
    matrix z13 = J(1, 3, 0)
    assert mreldif(r(rowmask), z31) == 0
    assert mreldif(r(colmask), z13) == 0
    assert r(totalmask) == 0
    assert r(N_primary_suppressed) == 3
    assert r(N_secondary_suppressed) == 0

    * small printed margins are masked; an unprinted margin is not
    matrix C2 = (1, 2 \ 0, 9)
    matrix RE2 = (1 \ 0)
    matrix CE2 = (1, 1)
    _tabtools_smallcells, counts(C2) rowexact(RE2) rowsensitive(RE2) ///
        colexact(CE2) colsensitive(CE2) grandexact(1) grandsensitive(1) ///
        smallcells(5) primary
    matrix M = r(mask)
    matrix w3 = (1, 1 \ 0, 0)
    assert mreldif(M, w3) == 0
    matrix w1 = (1 \ 0)
    matrix w2 = (1, 0)
    assert mreldif(r(rowmask), w1) == 0
    assert mreldif(r(colmask), w2) == 0
    assert r(N_secondary_suppressed) == 0

    * the same block in full mode still gets complementary cells
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) rowexact(RE) ///
        rowsensitive(RE) colexact(CE) colsensitive(CE) grandexact(1) ///
        grandsensitive(1) smallcells(5)
    assert "`r(mode)'" == "full"
    assert !missing(r(N_secondary_suppressed))
    assert r(N_secondary_suppressed) > 0
}
if _rc == 0 {
    display as result "  PASS: engine primary mode masks printed small cells and margins only"
    local ++pass_count
}
else {
    display as error "  FAIL: engine primary mode (rc=`=_rc')"
    local ++fail_count
}

**# table1_tc primary: known answer against tabulate, every sink
local ++test_count
capture noisily {
    local book "`output_dir'/sc230_t1.xlsx"
    local csv "`output_dir'/sc230_t1.csv"
    local md "`output_dir'/sc230_t1.md"
    capture erase "`book'"
    sysuse auto, clear
    * oracle: counts and column percentages from tabulate
    quietly tabulate rep78 foreign, matcell(F)
    matrix colN = J(1, 5, 1) * F
    table1_tc, by(foreign) vars(rep78 cat) total(before) ///
        smallcells(5, primary) excel("`book'") sheet("P") csv("`csv'") ///
        markdown("`md'") frame(sc230_p, replace)
    assert "`r(smallcells_mode)'" == "primary"
    assert r(smallcells) == 5
    assert r(N_secondary_suppressed) == 0
    assert r(N_derived_suppressed) == 0
    * Domestic 1 (2), Domestic 5 (2), Foreign 3 (3), Total 1 (2)
    assert r(N_primary_suppressed) == 4
    frame sc230_p {
        * rows: 1 header, 2 N, 3 variable, 4..8 levels 1..5
        forvalues lv = 1/5 {
            local r = `lv' + 3
            forvalues g = 0/1 {
                local n = F[`lv', `g' + 1]
                local pct = strtrim(string(100 * `n' / colN[1, `g' + 1], "%3.0f"))
                local cell = strtrim(foreign_`g'[`r'])
                if inrange(`n', 1, 4) assert "`cell'" == "<5"
                else assert "`cell'" == "`n' (`pct')"
            }
        }
        * the test is shown as computed, not Suppressed
        assert strtrim(pvalue[3]) == "<0.001"
        * nothing complementary anywhere
        foreach v of varlist foreign_* {
            quietly count if strpos(`v', "≥")
            assert r(N) == 0
            * the Dose_IgG hand regex finds nothing left to mask
            quietly count if ustrregexm(`v', "^[1-4] \(")
            assert r(N) == 0
        }
    }
    * Excel, CSV, Markdown carry the same masked cells and the mode note
    import excel using "`book'", sheet("P") allstring clear
    quietly count if ustrregexm(D, "^[1-4] \(") | ustrregexm(E, "^[1-4] \(") | ///
        ustrregexm(C, "^[1-4] \(")
    assert r(N) == 0
    local nmask 0
    foreach v in C D E {
        quietly count if `v' == "<5"
        local nmask = `nmask' + r(N)
    }
    assert `nmask' == 4
    _v_grep "`csv'" "This protects printed counts only"
    assert r(n) == 1
    _v_grep "`csv'" "(^|,)[1-4] \("
    assert r(n) == 0
    _v_grep "`md'" "\| 8 \(17\) \|"
    assert r(n) == 1
    _v_grep "`md'" "primary suppression only"
    assert r(n) == 1
    _v_grep "`md'" "≥"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc smallcells(5, primary) known answer in every sink"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc primary known answer (rc=`=_rc')"
    local ++fail_count
}

**# primary masks printed missing counts and small group Ns; derived counts are not protected
local ++test_count
capture noisily {
    sysuse auto, clear
    * Missing rep78: Domestic 4, Foreign 1, both printed under -missing-
    desctab, by(foreign) vars(rep78 cat) missing smallcells(5, primary) clear
    quietly count if strtrim(factor) == "Missing"
    assert r(N) == 1
    quietly levelsof foreign_0 if strtrim(factor) == "Missing", local(m0) clean
    quietly levelsof foreign_1 if strtrim(factor) == "Missing", local(m1) clean
    assert "`m0'" == "<5"
    assert "`m1'" == "<5"

    * missingsummary on a continuous variable: 3 missing in Domestic
    sysuse auto, clear
    replace mpg = . in 1/3
    desctab, by(foreign) vars(mpg contn) missingsummary smallcells(5, primary) clear
    quietly count if strpos(foreign_0, "<5") > 0
    assert r(N) == 1

    * a group of 3 prints its N as <5
    sysuse auto, clear
    gen byte g = cond(_n <= 3, 1, 2)
    desctab, by(g) vars(foreign bin) smallcells(5, primary) clear
    assert strtrim(g_1[2]) == "<5"
    assert strtrim(g_2[2]) == "N=71"

    * a hidden (derived) small count is not protected in primary mode:
    * binary: Foreign has 22 of 22 non-missing, Domestic 0 negatives
    * become derivable but print nothing small, so nothing is masked
    sysuse auto, clear
    desctab, by(foreign) vars(mpg contn) smallcells(5, primary) clear
    quietly count if strpos(foreign_0, "<5") | strpos(foreign_1, "<5")
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: primary masks printed missing counts and small Ns"
    local ++pass_count
}
else {
    display as error "  FAIL: primary missing counts / Ns (rc=`=_rc')"
    local ++fail_count
}

**# full mode is unchanged by the 2.3.0 parser
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) total(before) smallcells(5) clear
    assert "`r(smallcells_mode)'" == "full"
    assert !missing(r(N_secondary_suppressed))
    assert r(N_secondary_suppressed) > 0
    assert strtrim(pvalue[3]) == "Suppressed"
    quietly count if strpos(foreign_0, "≥5") | strpos(foreign_1, "≥5")
    assert !missing(r(N))
    assert r(N) >= 1
    * percentages withheld for the protected variable
    quietly count if strpos(foreign_0, "(") | strpos(foreign_1, "(")
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: default smallcells(#) keeps full complementary protection"
    local ++pass_count
}
else {
    display as error "  FAIL: full mode regression (rc=`=_rc')"
    local ++fail_count
}

**# crosstab primary: cells and margins, tests kept
local ++test_count
capture noisily {
    local csv "`output_dir'/sc230_ct.csv"
    sysuse auto, clear
    quietly tabulate rep78 foreign, matcell(F)
    crosstab rep78 foreign, colpct smallcells(5, primary) frame(sc230_ct, replace) ///
        csv("`csv'")
    assert "`r(smallcells_mode)'" == "primary"
    assert r(N_secondary_suppressed) == 0
    assert r(N_primary_suppressed) == 4
    assert !missing(r(p))
    assert r(p) < 0.001
    frame sc230_ct {
        * rows: 1 title, 2 header, 3..7 levels, 8 total; c2 c3 counts, c4 total
        forvalues lv = 1/5 {
            local r = `lv' + 2
            forvalues g = 1/2 {
                local n = F[`lv', `g']
                local cell = strtrim(c`=`g' + 1'[`r'])
                if inrange(`n', 1, 4) assert "`cell'" == "<5"
                else assert strpos("`cell'", "`n' (") == 1
            }
        }
        * row 1 total is 2: a printed margin, masked
        assert strtrim(c4[3]) == "<5"
        assert strtrim(c4[5]) == "30"
        quietly count if strpos(c2, "≥") | strpos(c3, "≥") | strpos(c4, "≥")
        assert r(N) == 0
    }
    _v_grep "`csv'" "Suppressed"
    assert r(n) == 0
    _v_grep "`csv'" "This protects printed counts only"
    assert r(n) == 1
    * full mode on the same table still suppresses the test
    crosstab rep78 foreign, colpct smallcells(5)
    assert "`r(smallcells_mode)'" == "full"
    assert r(p) == .d
}
if _rc == 0 {
    display as result "  PASS: crosstab smallcells(5, primary) known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab primary (rc=`=_rc')"
    local ++fail_count
}

**# refusals
local ++test_count
capture noisily {
    sysuse auto, clear
    foreach bad in "5, prim" "5," "5 primary" "x, primary" "2, primary" "5, primary full" {
        capture table1_tc, by(foreign) vars(rep78 cat) smallcells(`bad')
        assert _rc == 198
        capture crosstab rep78 foreign, smallcells(`bad')
        assert _rc == 198
    }
    capture table1_tc, by(foreign) vars(rep78 cat) smallcells(5) nosmallcells
    assert _rc == 198
    capture crosstab rep78 foreign, smallcells(5, primary) nosmallcells
    assert _rc == 198
    * percent-only display stays refused in primary mode
    capture desctab, by(foreign) vars(rep78 cat) percent smallcells(5, primary)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: smallcells() suboption and combination refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: smallcells() refusals (rc=`=_rc')"
    local ++fail_count
}

**# session default (W1): applied, echoed, overridden, switched off
local ++test_count
capture noisily {
    local lg "`output_dir'/sc230_echo.log"
    sysuse auto, clear
    tabtools set smallcells 5 primary
    capture log close _sc230e
    log using "`lg'", replace text name(_sc230e)
    table1_tc, by(foreign) vars(rep78 cat) clear
    local k = r(smallcells)
    local mode "`r(smallcells_mode)'"
    log close _sc230e
    assert `k' == 5
    assert "`mode'" == "primary"
    assert strtrim(foreign_0[4]) == "<5"
    _v_grep "`lg'" "^\(tabtools: using session smallcells\(5, primary\)\)$"
    assert r(n) == 1

    * explicit option wins, including its mode
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) smallcells(5) clear
    assert "`r(smallcells_mode)'" == "full"

    * nosmallcells: no masking at all for this call
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) nosmallcells clear
    assert missing(r(smallcells))
    assert strtrim(foreign_0[4]) == "2 (4)"

    * crosstab honours the session default too
    sysuse auto, clear
    crosstab rep78 foreign
    assert "`r(smallcells_mode)'" == "primary"
    crosstab rep78 foreign, nosmallcells
    assert missing(r(smallcells))

    * a session default without a mode is full
    tabtools set smallcells 5
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) clear
    assert "`r(smallcells_mode)'" == "full"
    tabtools set smallcells clear
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) clear
    assert missing(r(smallcells))
}
local _rc_save = _rc
capture log close _sc230e
tabtools set clear
if `_rc_save' == 0 {
    display as result "  PASS: session smallcells default, echo, override, nosmallcells"
    local ++pass_count
}
else {
    display as error "  FAIL: session smallcells (rc=`_rc_save')"
    local ++fail_count
}

capture frame drop sc230_p
capture frame drop sc230_ct
capture erase "$V230_RES"
macro drop V230_TOOL V230_RES
display "RESULT: test_smallcells_v230 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _sc230
if `fail_count' > 0 exit 1
