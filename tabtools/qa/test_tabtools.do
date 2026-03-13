* test_tabtools.do - Functional tests for tabtools package
* Generated: 2026-03-12
* Covers: tabtools, table1_tc, regtab, effecttab, stratetab, tablex
* Tests: ~130

clear all
set more off
set varabbrev off

* ============================================================
* Setup
* ============================================================

local tabtools_dir "`c(pwd)'/.."
local output_dir "`c(pwd)'/output"
local tools_dir "/home/tpcopeland/Stata-Dev/.claude/skills/qa/tools"
capture mkdir "`output_dir'"

* Load tabtools from parent directory
adopath ++ "`tabtools_dir'"
run "`tabtools_dir'/_tabtools_common.ado"

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
* tabtools Meta-Command Tests
* ============================================================

* Test: tabtools default listing
local ++test_count
capture noisily {
    tabtools
    assert r(n_commands) > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - default listing"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - default listing (error `=_rc')"
    local ++fail_count
}

* Test: tabtools with list option
local ++test_count
capture noisily {
    tabtools, list
    assert r(n_commands) > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - list option"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - list option (error `=_rc')"
    local ++fail_count
}

* Test: tabtools with detail option
local ++test_count
capture noisily {
    tabtools, detail
    assert r(n_commands) > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - detail option"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - detail option (error `=_rc')"
    local ++fail_count
}

* Test: tabtools category filter
local ++test_count
capture noisily {
    tabtools, category(descriptive)
    assert r(n_commands) >= 1
}
if _rc == 0 {
    display as result "  PASS: tabtools - category filter"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - category filter (error `=_rc')"
    local ++fail_count
}

* Test: tabtools returns version
local ++test_count
capture noisily {
    tabtools
    assert "`r(version)'" != ""
}
if _rc == 0 {
    display as result "  PASS: tabtools - returns version"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - returns version (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Helper Utility Tests (_tabtools_common)
* ============================================================

* Test: _tabtools_col_letter basic conversions
local ++test_count
capture noisily {
    _tabtools_col_letter 1
    assert "`result'" == "A"
    _tabtools_col_letter 26
    assert "`result'" == "Z"
    _tabtools_col_letter 27
    assert "`result'" == "AA"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_col_letter - A, Z, AA"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_col_letter (error `=_rc')"
    local ++fail_count
}

* Test: _tabtools_build_col_letters
local ++test_count
capture noisily {
    _tabtools_build_col_letters 5
    assert "`result'" == "A B C D E"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_build_col_letters - 5 columns"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_build_col_letters (error `=_rc')"
    local ++fail_count
}

* Test: _tabtools_validate_path accepts valid paths
local ++test_count
capture noisily {
    _tabtools_validate_path "good_file.xlsx" "test"
}
if _rc == 0 {
    display as result "  PASS: _tabtools_validate_path - valid path accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_validate_path - valid path (error `=_rc')"
    local ++fail_count
}

* Test: _tabtools_validate_path rejects dangerous characters
local ++test_count
capture noisily {
    capture _tabtools_validate_path "bad;file.xlsx" "test"
    assert _rc == 198
    capture _tabtools_validate_path "bad|file.xlsx" "test"
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: _tabtools_validate_path - dangerous chars rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_validate_path - dangerous chars (error `=_rc')"
    local ++fail_count
}

* ============================================================
* table1_tc Tests
* ============================================================

* Test: Basic table without grouping
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, vars(price contn \ mpg conts \ rep78 cat)
}
if _rc == 0 {
    display as result "  PASS: table1_tc - basic without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - basic without by() (error `=_rc')"
    local ++fail_count
}

* Test: Table with grouping
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg conts \ rep78 cat)
}
if _rc == 0 {
    display as result "  PASS: table1_tc - with by()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - with by() (error `=_rc')"
    local ++fail_count
}

* Test: Total column before
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) total(before)
}
if _rc == 0 {
    display as result "  PASS: table1_tc - total(before)"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - total(before) (error `=_rc')"
    local ++fail_count
}

* Test: Total column after
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) total(after)
}
if _rc == 0 {
    display as result "  PASS: table1_tc - total(after)"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - total(after) (error `=_rc')"
    local ++fail_count
}

* Test: One column format
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) onecol
}
if _rc == 0 {
    display as result "  PASS: table1_tc - onecol"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - onecol (error `=_rc')"
    local ++fail_count
}

* Test: Test statistic column
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) test statistic
}
if _rc == 0 {
    display as result "  PASS: table1_tc - test statistic"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - test statistic (error `=_rc')"
    local ++fail_count
}

* Test: Excel export
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) ///
        excel("`output_dir'/_test_table1.xlsx") sheet("Table 1") ///
        title("Table 1. Baseline Characteristics")
    confirm file "`output_dir'/_test_table1.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc - excel export"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - excel export (error `=_rc')"
    local ++fail_count
}

* Test: Custom format
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn %5.1f \ mpg contn %5.2f) format(%5.2f)
}
if _rc == 0 {
    display as result "  PASS: table1_tc - custom format"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - custom format (error `=_rc')"
    local ++fail_count
}

* Test: Binary variable types (bin, bine)
local ++test_count
capture noisily {
    sysuse auto, clear
    gen highmpg = (mpg > 20)
    table1_tc, by(foreign) vars(highmpg bin \ highmpg bine) test
}
if _rc == 0 {
    display as result "  PASS: table1_tc - bin and bine types"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - bin and bine types (error `=_rc')"
    local ++fail_count
}

* Test: Categorical with exact test
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cate) test
}
if _rc == 0 {
    display as result "  PASS: table1_tc - cate type"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - cate type (error `=_rc')"
    local ++fail_count
}

* Test: Log-normal continuous
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contln) test
}
if _rc == 0 {
    display as result "  PASS: table1_tc - contln type"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - contln type (error `=_rc')"
    local ++fail_count
}

* Test: Missing category option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) missing
}
if _rc == 0 {
    display as result "  PASS: table1_tc - missing option"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - missing option (error `=_rc')"
    local ++fail_count
}

* Test: Header percentage
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) headerperc
}
if _rc == 0 {
    display as result "  PASS: table1_tc - headerperc"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - headerperc (error `=_rc')"
    local ++fail_count
}

* Test: Percent only
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) percent
}
if _rc == 0 {
    display as result "  PASS: table1_tc - percent"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - percent (error `=_rc')"
    local ++fail_count
}

* Test: Percent (n) format
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) percent_n
}
if _rc == 0 {
    display as result "  PASS: table1_tc - percent_n"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - percent_n (error `=_rc')"
    local ++fail_count
}

* Test: n/N format
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) slashN
}
if _rc == 0 {
    display as result "  PASS: table1_tc - slashN"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - slashN (error `=_rc')"
    local ++fail_count
}

* Test: Custom IQR separator
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price conts) iqrmiddle(", ")
}
if _rc == 0 {
    display as result "  PASS: table1_tc - iqrmiddle"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - iqrmiddle (error `=_rc')"
    local ++fail_count
}

* Test: Custom SD format
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn) sdleft(" [") sdright("]")
}
if _rc == 0 {
    display as result "  PASS: table1_tc - sdleft/sdright"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - sdleft/sdright (error `=_rc')"
    local ++fail_count
}

* Test: If condition
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc if foreign == 1, by(rep78) vars(price contn \ mpg conts)
}
if _rc == 0 {
    display as result "  PASS: table1_tc - if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - if condition (error `=_rc')"
    local ++fail_count
}

* Test: Clear option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) clear
    assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc - clear option"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - clear option (error `=_rc')"
    local ++fail_count
}

* Test: Pairwise comparisons (3-group)
local ++test_count
capture noisily {
    sysuse auto, clear
    gen group3 = cond(rep78 <= 2, 1, cond(rep78 <= 3, 2, 3))
    label define grp3 1 "Low" 2 "Mid" 3 "High"
    label values group3 grp3
    table1_tc, by(group3) vars(price contn \ mpg conts) pairwise123 test
}
if _rc == 0 {
    display as result "  PASS: table1_tc - pairwise123"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - pairwise123 (error `=_rc')"
    local ++fail_count
}

* Test: Row percentages
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) catrowperc
}
if _rc == 0 {
    display as result "  PASS: table1_tc - catrowperc"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - catrowperc (error `=_rc')"
    local ++fail_count
}

* Test: Gurmeet style
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg conts \ rep78 cat) gurmeet
}
if _rc == 0 {
    display as result "  PASS: table1_tc - gurmeet"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - gurmeet (error `=_rc')"
    local ++fail_count
}

* Test: Thin border style Excel
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) ///
        excel("`output_dir'/_test_table1_thin.xlsx") sheet("T1") ///
        title("Table 1") borderstyle(thin)
    confirm file "`output_dir'/_test_table1_thin.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc - borderstyle(thin) excel"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - borderstyle(thin) excel (error `=_rc')"
    local ++fail_count
}

* Test: Excel export without by() (Critical #2 regression)
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, vars(price contn \ mpg contn \ weight contn) ///
        excel("`output_dir'/_test_table1_noby.xlsx") sheet("T1") ///
        title("No By Variable Test")
}
if _rc == 0 {
    display as result "  PASS: table1_tc - excel without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - excel without by() (error `=_rc')"
    local ++fail_count
}

* Test: Error when vars() not specified
local ++test_count
capture noisily {
    sysuse auto, clear
    capture table1_tc, by(foreign)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc - error when vars() missing"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - error when vars() missing (error `=_rc')"
    local ++fail_count
}

* ============================================================
* table1_tc Weighted Tests
* ============================================================

* Test: Weighted basic (contn + cat + conts)
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, by(foreign) vars(price contn \ rep78 cat \ mpg conts) wt(iptw)
    assert "`s(Dapa)'" != ""
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - basic"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - basic (error `=_rc')"
    local ++fail_count
}

* Test: Weighted binary variables
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    gen highmpg = (mpg > 20)
    table1_tc, by(foreign) vars(highmpg bin \ highmpg bine) wt(iptw)
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - binary"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - binary (error `=_rc')"
    local ++fail_count
}

* Test: Weighted log-normal
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, by(foreign) vars(price contln) wt(iptw)
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - contln"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - contln (error `=_rc')"
    local ++fail_count
}

* Test: Weighted with total column
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, by(foreign) vars(price contn \ rep78 cat) wt(iptw) total(after)
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - total(after)"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - total(after) (error `=_rc')"
    local ++fail_count
}

* Test: Weighted Excel export
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, by(foreign) vars(price contn \ rep78 cat) wt(iptw) ///
        excel("`output_dir'/_test_table1_wt.xlsx") sheet("Weighted") ///
        title("Weighted Table 1")
    confirm file "`output_dir'/_test_table1_wt.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - excel export"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - excel export (error `=_rc')"
    local ++fail_count
}

* Test: Weighted clear option
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, by(foreign) vars(price contn \ rep78 cat) wt(iptw) clear
    assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - clear"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - clear (error `=_rc')"
    local ++fail_count
}

* Test: Weighted percent_n
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, by(foreign) vars(rep78 cat) wt(iptw) percent_n
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - percent_n"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - percent_n (error `=_rc')"
    local ++fail_count
}

* Test: fweight + wt() mutual exclusivity error
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    capture table1_tc [fw=rep78], by(foreign) vars(price contn) wt(iptw)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - fweight+wt() error"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - fweight+wt() error (error `=_rc')"
    local ++fail_count
}

* Test: Negative weights error
local ++test_count
capture noisily {
    sysuse auto, clear
    gen double neg_wt = -1
    capture table1_tc, by(foreign) vars(price contn) wt(neg_wt)
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - negative weights error"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - negative weights error (error `=_rc')"
    local ++fail_count
}

* Test: Weighted Dapa footnote
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, by(foreign) vars(price contn \ rep78 cat) wt(iptw)
    assert regexm("`s(Dapa)'", "Weighted")
    assert regexm("`s(Dapa)'", "suppressed")
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - Dapa footnote"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - Dapa footnote (error `=_rc')"
    local ++fail_count
}

* Test: Weighted without by() (single group)
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat \ mpg conts) wt(iptw)
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() - without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() - without by() (error `=_rc')"
    local ++fail_count
}

* ============================================================
* regtab Tests
* ============================================================

* Test: Basic single logistic model
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab.xlsx") sheet("T1") coef("OR")
    confirm file "`output_dir'/_test_regtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - basic logistic"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - basic logistic (error `=_rc')"
    local ++fail_count
}

* Test: With title
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab_title.xlsx") sheet("T1") ///
        coef("OR") title("Table 1. Logistic Regression Results")
    confirm file "`output_dir'/_test_regtab_title.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - title option"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - title option (error `=_rc')"
    local ++fail_count
}

* Test: Multiple models
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    collect: regress price mpg weight
    collect: regress price mpg weight foreign
    regtab, xlsx("`output_dir'/_test_regtab_multi.xlsx") sheet("T1") ///
        coef("Coef.") models("Model 1 \ Model 2 \ Model 3")
    confirm file "`output_dir'/_test_regtab_multi.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - multiple models"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - multiple models (error `=_rc')"
    local ++fail_count
}

* Test: Drop intercept
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg
    regtab, xlsx("`output_dir'/_test_regtab_noint.xlsx") sheet("T1") coef("OR") noint
    confirm file "`output_dir'/_test_regtab_noint.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - noint"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - noint (error `=_rc')"
    local ++fail_count
}

* Test: Custom CI separator
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg
    regtab, xlsx("`output_dir'/_test_regtab_sep.xlsx") sheet("T1") coef("OR") sep("; ")
    confirm file "`output_dir'/_test_regtab_sep.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - custom separator"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - custom separator (error `=_rc')"
    local ++fail_count
}

* Test: Linear regression
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab_linear.xlsx") sheet("T1") ///
        coef("Coef.") title("Linear Regression")
    confirm file "`output_dir'/_test_regtab_linear.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - linear regression"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - linear regression (error `=_rc')"
    local ++fail_count
}

* Test: Cox regression
local ++test_count
capture noisily {
    clear
    set seed 54321
    set obs 200
    gen treat = runiform() > 0.5
    gen age = 40 + int(runiform()*30)
    gen time = rexponential(1/(0.1 + 0.05*treat))
    gen event = runiform() < 0.7
    stset time, failure(event)
    collect clear
    collect: stcox treat age
    regtab, xlsx("`output_dir'/_test_regtab_cox.xlsx") sheet("T1") ///
        coef("HR") title("Hazard Ratios")
    confirm file "`output_dir'/_test_regtab_cox.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - Cox regression"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - Cox regression (error `=_rc')"
    local ++fail_count
}

* Test: Poisson regression
local ++test_count
capture noisily {
    sysuse auto, clear
    gen n_events = ceil(runiform() * 5)
    collect clear
    collect: poisson n_events price mpg, irr
    regtab, xlsx("`output_dir'/_test_regtab_poisson.xlsx") sheet("T1") coef("IRR")
    confirm file "`output_dir'/_test_regtab_poisson.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - Poisson regression"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - Poisson regression (error `=_rc')"
    local ++fail_count
}

* Test: Stats option (N, AIC, BIC)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab_stats.xlsx") sheet("Stats") ///
        coef("OR") title("With Stats") stats(n aic bic) noint
    confirm file "`output_dir'/_test_regtab_stats.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - stats(n aic bic)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - stats(n aic bic) (error `=_rc')"
    local ++fail_count
}

* Test: Mixed model with relabel
local ++test_count
capture noisily {
    clear
    set seed 12345
    set obs 200
    gen cluster = ceil(_n/20)
    label variable cluster "Study Site"
    gen x = rnormal()
    label variable x "Treatment Score"
    gen u0 = rnormal() * 0.5 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen u1 = rnormal() * 0.3 if cluster != cluster[_n-1]
    replace u1 = u1[_n-1] if u1 == .
    gen y = 1 + 0.5*x + u0 + u1*x + rnormal()*0.3
    collect clear
    collect: mixed y x || cluster: x
    regtab, xlsx("`output_dir'/_test_regtab_mixed.xlsx") sheet("Mixed") ///
        coef("Coef.") title("Mixed Model") stats(n groups aic bic icc) relabel
    confirm file "`output_dir'/_test_regtab_mixed.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab - mixed model relabel"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - mixed model relabel (error `=_rc')"
    local ++fail_count
}

* Test: nore option (hide random effects)
local ++test_count
capture noisily {
    clear
    set seed 12345
    set obs 200
    gen facility = ceil(_n/20)
    gen exposure = runiform() > 0.5
    gen outcome = 1 + 0.5*exposure + rnormal()*0.5
    collect clear
    collect: mixed outcome exposure || facility:
    regtab, xlsx("`output_dir'/_test_regtab_nore.xlsx") sheet("NoRE") ///
        coef("Coef.") title("Hide RE") nore
    * Verify no RE rows in output
    import excel "`output_dir'/_test_regtab_nore.xlsx", sheet("NoRE") clear allstring
    count if strpos(B, "var(") > 0 | strpos(B, "Variance") > 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: regtab - nore option"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - nore option (error `=_rc')"
    local ++fail_count
}

* Test: Data preservation after regtab
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_N = _N
    local orig_k = c(k)
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_test_regtab_preserve.xlsx") sheet("T1") coef("Coef.")
    assert _N == `orig_N'
    assert c(k) == `orig_k'
    confirm variable price mpg weight foreign
}
if _rc == 0 {
    display as result "  PASS: regtab - data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab - data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* effecttab Tests
* ============================================================

* Create synthetic causal inference dataset
quietly {
    clear
    set seed 54321
    set obs 2000
    gen age = 30 + runiform() * 40
    gen female = runiform() < 0.55
    gen education = 1 + floor(runiform() * 4)
    gen propensity = invlogit(-1.5 + 0.02*age + 0.3*female + 0.1*education)
    gen treatment = runiform() < propensity
    gen prob_outcome = invlogit(-2 + 0.5*treatment + 0.01*age - 0.2*female + 0.05*education)
    gen outcome_bin = runiform() < prob_outcome
    gen outcome_cont = 50 + 5*treatment + 0.2*age - 2*female + runiform()*10
    gen treat3 = 0 if runiform() < 0.33
    replace treat3 = 1 if missing(treat3) & runiform() < 0.5
    replace treat3 = 2 if missing(treat3)
    label define treat3_lbl 0 "Control" 1 "Low dose" 2 "High dose"
    label values treat3 treat3_lbl
    gen prob3 = invlogit(-2 + 0.3*(treat3==1) + 0.6*(treat3==2) + 0.01*age)
    gen outcome3 = runiform() < prob3
    label variable age "Age (years)"
    label variable female "Female sex"
    label variable treatment "Treatment (binary)"
    label variable outcome_bin "Binary outcome"
    label variable outcome_cont "Continuous outcome"
    label define treat_lbl 0 "Control" 1 "Treated"
    label values treatment treat_lbl
    save "`output_dir'/_effecttab_testdata.dta", replace
}

* Test: Basic teffects ipw - ATE
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female education), ate
    effecttab, xlsx("`output_dir'/_test_effecttab.xlsx") sheet("ATE") effect("ATE")
    confirm file "`output_dir'/_test_effecttab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - basic teffects ipw ATE"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - basic teffects ipw ATE (error `=_rc')"
    local ++fail_count
}

* Test: teffects with title and clean
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_clean.xlsx") sheet("T1") ///
        effect("ATE") title("ATE with IPTW") clean
    confirm file "`output_dir'/_test_effecttab_clean.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - title and clean"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - title and clean (error `=_rc')"
    local ++fail_count
}

* Test: teffects ipw - ATET
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female education), atet
    effecttab, xlsx("`output_dir'/_test_effecttab_atet.xlsx") sheet("ATET") effect("ATET")
    confirm file "`output_dir'/_test_effecttab_atet.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - ATET"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - ATET (error `=_rc')"
    local ++fail_count
}

* Test: teffects ipw - PO means
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), pomeans
    effecttab, xlsx("`output_dir'/_test_effecttab_po.xlsx") sheet("PO") ///
        effect("Pr(Y)") title("Potential Outcome Means") clean
    confirm file "`output_dir'/_test_effecttab_po.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - PO means"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - PO means (error `=_rc')"
    local ++fail_count
}

* Test: teffects ra
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ra (outcome_bin age female education) (treatment), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_ra.xlsx") sheet("RA") effect("ATE")
    confirm file "`output_dir'/_test_effecttab_ra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - teffects ra"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - teffects ra (error `=_rc')"
    local ++fail_count
}

* Test: teffects aipw (doubly robust)
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects aipw (outcome_bin age female) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_aipw.xlsx") sheet("AIPW") ///
        effect("ATE") title("Doubly Robust") clean
    confirm file "`output_dir'/_test_effecttab_aipw.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - teffects aipw"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - teffects aipw (error `=_rc')"
    local ++fail_count
}

* Test: Multiple models comparison
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate
    collect: teffects aipw (outcome_bin age female) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_multi.xlsx") sheet("Compare") ///
        models("IPTW \ AIPW") effect("ATE") clean
    confirm file "`output_dir'/_test_effecttab_multi.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - multiple models"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - multiple models (error `=_rc')"
    local ++fail_count
}

* Test: margins predictions
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    logit outcome_bin i.treatment age female
    collect clear
    collect: margins treatment
    effecttab, xlsx("`output_dir'/_test_effecttab_margins.xlsx") sheet("Pred") ///
        type(margins) effect("Pr(Y)") title("Predicted Probabilities")
    confirm file "`output_dir'/_test_effecttab_margins.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - margins predictions"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - margins predictions (error `=_rc')"
    local ++fail_count
}

* Test: margins dydx (AME)
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    logit outcome_bin i.treatment age female education
    collect clear
    collect: margins, dydx(treatment age female)
    effecttab, xlsx("`output_dir'/_test_effecttab_dydx.xlsx") sheet("AME") ///
        effect("AME") title("Average Marginal Effects")
    confirm file "`output_dir'/_test_effecttab_dydx.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - margins dydx"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - margins dydx (error `=_rc')"
    local ++fail_count
}

* Test: margins contrasts
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    logit outcome_bin i.treatment age female
    collect clear
    collect: margins r.treatment
    effecttab, xlsx("`output_dir'/_test_effecttab_rd.xlsx") sheet("RD") effect("RD")
    confirm file "`output_dir'/_test_effecttab_rd.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - margins contrasts"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - margins contrasts (error `=_rc')"
    local ++fail_count
}

* Test: margins with at()
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    logit outcome_bin i.treatment age female
    collect clear
    collect: margins treatment, at(age=(30 40 50 60))
    effecttab, xlsx("`output_dir'/_test_effecttab_at.xlsx") sheet("ByAge") ///
        type(margins) effect("Pr(Y)")
    confirm file "`output_dir'/_test_effecttab_at.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - margins at()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - margins at() (error `=_rc')"
    local ++fail_count
}

* Test: Multi-level treatment
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome3) (treat3 age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_ml.xlsx") sheet("Multi") ///
        effect("ATE") title("Multi-level Treatment") clean
    confirm file "`output_dir'/_test_effecttab_ml.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - multi-level treatment"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - multi-level treatment (error `=_rc')"
    local ++fail_count
}

* Test: Continuous outcome
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ra (outcome_cont age female) (treatment), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_cont.xlsx") sheet("Cont") effect("ATE")
    confirm file "`output_dir'/_test_effecttab_cont.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - continuous outcome"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - continuous outcome (error `=_rc')"
    local ++fail_count
}

* Test: Custom CI separator
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_sep.xlsx") sheet("Sep") ///
        effect("ATE") sep(" to ")
    confirm file "`output_dir'/_test_effecttab_sep.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - custom separator"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - custom separator (error `=_rc')"
    local ++fail_count
}

* Test: Auto-detection of type
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_auto.xlsx") sheet("Auto") effect("Effect")
    assert "`r(type)'" == "teffects"
}
if _rc == 0 {
    display as result "  PASS: effecttab - auto type detection"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - auto type detection (error `=_rc')"
    local ++fail_count
}

* Test: clean with value-labeled treatment (auto-detect)
local ++test_count
capture noisily {
    sysuse cancer, clear
    collect clear
    collect: teffects ipw (died) (drug age), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_vlabel.xlsx") ///
        sheet("AutoLabels") effect("ATE") title("Auto Labels") clean
    confirm file "`output_dir'/_test_effecttab_vlabel.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - clean with value labels"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - clean with value labels (error `=_rc')"
    local ++fail_count
}

* Test: tlabels() option
local ++test_count
capture noisily {
    sysuse cancer, clear
    collect clear
    collect: teffects ipw (died) (drug age), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_tlab.xlsx") ///
        sheet("Explicit") effect("ATE") ///
        tlabels(1 "Control" 2 "Treatment A" 3 "Treatment B")
    confirm file "`output_dir'/_test_effecttab_tlab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - tlabels() option"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - tlabels() option (error `=_rc')"
    local ++fail_count
}

* Test: Error handling - no collect table
local ++test_count
capture noisily {
    collect clear
    capture effecttab, xlsx("`output_dir'/_test_error.xlsx") sheet("Error")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: effecttab - error on no collect"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - error on no collect (error `=_rc')"
    local ++fail_count
}

* Test: Error handling - invalid file extension
local ++test_count
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age), ate
    capture effecttab, xlsx("`output_dir'/_test_error.xls") sheet("Error")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: effecttab - error on .xls extension"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - error on .xls extension (error `=_rc')"
    local ++fail_count
}

* Test: Data preservation after effecttab
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_N = _N
    collect clear
    collect: regress price mpg weight
    effecttab, xlsx("`output_dir'/_test_effecttab_pres.xlsx") sheet("T1") type(margins)
    assert _N == `orig_N'
    confirm variable price mpg weight foreign
}
if _rc == 0 {
    display as result "  PASS: effecttab - data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* stratetab Tests
* ============================================================

* Create synthetic strate output files
quietly {
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 25, cond(_n==2, 18, 32))
    gen _Y = cond(_n==1, 5000, cond(_n==2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_lbl 0 "Never" 1 "Former" 2 "Current"
    label values exposure exp_lbl
    save "`output_dir'/_strate_o1e1.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 12, cond(_n==2, 8, 20))
    gen _Y = cond(_n==1, 5000, cond(_n==2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_lbl 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_lbl
    save "`output_dir'/_strate_o2e1.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 15, cond(_n==2, 22, 28))
    gen _Y = cond(_n==1, 5000, cond(_n==2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_lbl 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_lbl
    save "`output_dir'/_strate_o3e1.dta", replace

    clear
    set obs 4
    gen duration_cat = _n
    gen _D = cond(_n==1, 8, cond(_n==2, 14, cond(_n==3, 22, 30)))
    gen _Y = cond(_n==1, 800, cond(_n==2, 1200, cond(_n==3, 2000, 3000)))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years"
    label values duration_cat dur_lbl
    save "`output_dir'/_strate_o1e2.dta", replace

    clear
    set obs 4
    gen duration_cat = _n
    gen _D = cond(_n==1, 4, cond(_n==2, 9, cond(_n==3, 15, 20)))
    gen _Y = cond(_n==1, 800, cond(_n==2, 1200, cond(_n==3, 2000, 3000)))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years", replace
    label values duration_cat dur_lbl
    save "`output_dir'/_strate_o2e2.dta", replace

    clear
    set obs 4
    gen duration_cat = _n
    gen _D = cond(_n==1, 12, cond(_n==2, 18, cond(_n==3, 25, 35)))
    gen _Y = cond(_n==1, 800, cond(_n==2, 1200, cond(_n==3, 2000, 3000)))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years", replace
    label values duration_cat dur_lbl
    save "`output_dir'/_strate_o3e2.dta", replace
}

* Test: Basic stratetab (single exposure)
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab.xlsx") outcomes(3)
    confirm file "`output_dir'/_test_stratetab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - basic single exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - basic single exposure (error `=_rc')"
    local ++fail_count
}

* Test: Custom outcome labels
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_lab.xlsx") outcomes(3) ///
        outlabels("EDSS 4 \ EDSS 6 \ Relapse")
    confirm file "`output_dir'/_test_stratetab_lab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - outlabels"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - outlabels (error `=_rc')"
    local ++fail_count
}

* Test: Custom exposure labels
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_exp.xlsx") outcomes(3) ///
        explabels("Time-Varying HRT")
    confirm file "`output_dir'/_test_stratetab_exp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - explabels"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - explabels (error `=_rc')"
    local ++fail_count
}

* Test: Multiple exposure types
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1" "`output_dir'/_strate_o1e2" "`output_dir'/_strate_o2e2" "`output_dir'/_strate_o3e2") ///
        xlsx("`output_dir'/_test_stratetab_multi.xlsx") outcomes(3) ///
        outlabels("EDSS 4 \ EDSS 6 \ Relapse") explabels("Time-Varying \ Duration")
    confirm file "`output_dir'/_test_stratetab_multi.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - multiple exposure types"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - multiple exposure types (error `=_rc')"
    local ++fail_count
}

* Test: Custom sheet name
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_sh.xlsx") outcomes(3) sheet("Table 2")
    confirm file "`output_dir'/_test_stratetab_sh.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - custom sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - custom sheet (error `=_rc')"
    local ++fail_count
}

* Test: Title option
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_title.xlsx") outcomes(3) ///
        title("Table 2. Unadjusted incidence rates")
    confirm file "`output_dir'/_test_stratetab_title.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - title"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - title (error `=_rc')"
    local ++fail_count
}

* Test: Custom digits
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_dig.xlsx") outcomes(3) digits(2)
    confirm file "`output_dir'/_test_stratetab_dig.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - custom digits"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - custom digits (error `=_rc')"
    local ++fail_count
}

* Test: Event digits and PY digits
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_evtpy.xlsx") outcomes(3) ///
        eventdigits(1) pydigits(1)
    confirm file "`output_dir'/_test_stratetab_evtpy.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - eventdigits/pydigits"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - eventdigits/pydigits (error `=_rc')"
    local ++fail_count
}

* Test: Rate scale and unit label
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_scale.xlsx") outcomes(3) ///
        ratescale(100) unitlabel("100")
    confirm file "`output_dir'/_test_stratetab_scale.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - ratescale/unitlabel"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - ratescale/unitlabel (error `=_rc')"
    local ++fail_count
}

* Test: PY scale
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_pys.xlsx") outcomes(3) pyscale(1000)
    confirm file "`output_dir'/_test_stratetab_pys.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - pyscale"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - pyscale (error `=_rc')"
    local ++fail_count
}

* Test: Full options combination
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1" "`output_dir'/_strate_o1e2" "`output_dir'/_strate_o2e2" "`output_dir'/_strate_o3e2") ///
        xlsx("`output_dir'/_test_stratetab_full.xlsx") outcomes(3) ///
        sheet("Table 2") title("Table 2. Rates by Exposure") ///
        outlabels("EDSS 4 \ EDSS 6 \ Relapse") explabels("TV \ Duration") ///
        digits(2) eventdigits(0) pydigits(0)
    confirm file "`output_dir'/_test_stratetab_full.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - full options"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - full options (error `=_rc')"
    local ++fail_count
}

* ============================================================
* tablex Tests
* ============================================================

* Test: Basic frequency table
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign rep78
    tablex using "`output_dir'/_test_tablex.xlsx", ///
        sheet("Freq") title("Frequency Table") replace
    confirm file "`output_dir'/_test_tablex.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex - basic frequency table"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - basic frequency table (error `=_rc')"
    local ++fail_count
}

* Test: Summary statistics table
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg weight) statistic(sd price mpg weight)
    tablex using "`output_dir'/_test_tablex_sum.xlsx", ///
        sheet("Summary") title("Summary Stats") replace
    confirm file "`output_dir'/_test_tablex_sum.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex - summary statistics"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - summary statistics (error `=_rc')"
    local ++fail_count
}

* Test: Cross-tabulation
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign rep78, statistic(frequency) statistic(percent)
    tablex using "`output_dir'/_test_tablex_cross.xlsx", ///
        sheet("CrossTab") title("Cross Tab") replace
    confirm file "`output_dir'/_test_tablex_cross.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex - cross-tabulation"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - cross-tabulation (error `=_rc')"
    local ++fail_count
}

* Test: Custom font and border
local ++test_count
capture noisily {
    sysuse auto, clear
    table rep78, statistic(mean price) statistic(count price)
    tablex using "`output_dir'/_test_tablex_custom.xlsx", ///
        sheet("Custom") title("Custom Formatting") ///
        font(Calibri) fontsize(11) borderstyle(medium) replace
    confirm file "`output_dir'/_test_tablex_custom.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex - custom font/border"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - custom font/border (error `=_rc')"
    local ++fail_count
}

* Test: Without title
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price)
    tablex using "`output_dir'/_test_tablex_notitle.xlsx", ///
        sheet("NoTitle") replace
    confirm file "`output_dir'/_test_tablex_notitle.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex - without title"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - without title (error `=_rc')"
    local ++fail_count
}

* Test: Table with three-way classification
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(median price) statistic(min price) statistic(max price)
    tablex using "`output_dir'/_test_tablex_threeway.xlsx", ///
        sheet("MultiStat") title("Price Statistics") replace
    confirm file "`output_dir'/_test_tablex_threeway.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex - three-way table"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - three-way table (error `=_rc')"
    local ++fail_count
}

* Test: Multiple sheets in same file
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price)
    tablex using "`output_dir'/_test_tablex_sheets.xlsx", ///
        sheet("Sheet1") title("First Table") replace
    sysuse auto, clear
    table rep78, statistic(mean mpg)
    tablex using "`output_dir'/_test_tablex_sheets.xlsx", ///
        sheet("Sheet2") title("Second Table")
    confirm file "`output_dir'/_test_tablex_sheets.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex - multiple sheets"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - multiple sheets (error `=_rc')"
    local ++fail_count
}

* Test: nformat option
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg weight)
    tablex using "`output_dir'/_test_tablex_nfmt.xlsx", sheet("Test") ///
        title("Table") replace nformat("#,##0.0")
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: tablex - nformat option"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - nformat option (error `=_rc')"
    local ++fail_count
}

* Test: Return values
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg)
    tablex using "`output_dir'/_test_tablex_ret.xlsx", sheet("T") ///
        title("Table") replace
    assert r(N_rows) > 0
    assert r(N_cols) > 0
}
if _rc == 0 {
    display as result "  PASS: tablex - return values"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - return values (error `=_rc')"
    local ++fail_count
}

* Test: Error handling - no collect table
local ++test_count
capture noisily {
    collect clear
    capture tablex using "`output_dir'/_test_error.xlsx", sheet("Error") replace
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: tablex - error on no collect"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - error on no collect (error `=_rc')"
    local ++fail_count
}

* Test: Data preservation after tablex
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_N = _N
    local orig_k = c(k)
    table foreign rep78
    tablex using "`output_dir'/_test_tablex_pres.xlsx", sheet("T") ///
        title("Test") replace
    assert _N == `orig_N'
    assert c(k) == `orig_k'
    confirm variable price mpg weight foreign
}
if _rc == 0 {
    display as result "  PASS: tablex - data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex - data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup
* ============================================================

* Remove temporary files
local xlsx_files : dir "`output_dir'" files "_test_*.xlsx"
foreach f of local xlsx_files {
    capture erase "`output_dir'/`f'"
}
local strate_files : dir "`output_dir'" files "_strate_*.dta"
foreach f of local strate_files {
    capture erase "`output_dir'/`f'"
}
capture erase "`output_dir'/_effecttab_testdata.dta"

* ============================================================
* Summary
* ============================================================

display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
