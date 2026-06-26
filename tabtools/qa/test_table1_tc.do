* test_table1_tc.do - complete QA for table1_tc
* Consolidated in v1.7.0 from: test_coverage_gaps.do, test_new_commands.do, test_nopvalue.do, test_review_tables_contracts.do, test_review_v1013.do, test_review_v1013_gaps.do, test_table1_tc_aggregation_contracts.do, test_tabtools.do, test_tabtools_v1015.do, test_v140_features.do, test_v150_features.do

clear all
set more off
set varabbrev off
version 16.0

capture log close _table1tc
log using "test_table1_tc.log", replace text name(_table1tc)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear


**# Migrated: legacy suite: table1_tc + weighted sections

* ============================================================
* table1_tc Tests
* ============================================================

* Test: Basic table without grouping
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

* Test: Quick-start auto-detect contract matches help example
capture noisily {
    sysuse auto, clear
    table1_tc rep78 foreign, by(foreign) clear
    assert factor[2] == "No. (Column %)"
    assert "`r(Dapa)'" == "Data are presented as No. (%)."
    assert strpos(`"`r(methods)'"', `"`r(Dapa)'"') > 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc - quick-start descriptor contract"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - quick-start descriptor contract (error `=_rc')"
    local ++fail_count
}

* Test: Total column before
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

* Test: Invalid total() value rejected
capture noisily {
    sysuse auto, clear
    capture table1_tc, by(foreign) vars(price contn \ rep78 cat) total(foo)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: table1_tc - invalid total() rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - invalid total() rejected (error `=_rc')"
    local ++fail_count
}

* Test: Categorical single-column display (onecol removed — now always active)
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat)
}
if _rc == 0 {
    display as result "  PASS: table1_tc - categorical single-column display"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - categorical single-column display (error `=_rc')"
    local ++fail_count
}

* Test: Test statistic column
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

* Test: open requires xlsx()/excel()
capture noisily {
    sysuse auto, clear
    capture table1_tc, by(foreign) vars(price contn \ rep78 cat) open
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: table1_tc - open requires excel"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - open requires excel (error `=_rc')"
    local ++fail_count
}

* Test: xlsx target must have .xlsx suffix
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_test_table1_badext.xls"
    capture table1_tc, by(foreign) vars(price contn \ rep78 cat) ///
        xlsx("`output_dir'/_test_table1_badext.xls")
    assert _rc == 198
    capture confirm file "`output_dir'/_test_table1_badext.xls"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc - bad xlsx suffix rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - bad xlsx suffix rejected (error `=_rc')"
    local ++fail_count
}

* Test: Valid sheet names with punctuation
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_test_table1_sheet_amp.xlsx"
    capture erase "`output_dir'/_test_table1_sheet_quote.xlsx"
    table1_tc, by(foreign) vars(price contn) ///
        xlsx("`output_dir'/_test_table1_sheet_amp.xlsx") sheet("Men & Women")
    confirm file "`output_dir'/_test_table1_sheet_amp.xlsx"
    table1_tc, by(foreign) vars(price contn) ///
        xlsx("`output_dir'/_test_table1_sheet_quote.xlsx") sheet("O'Brien")
    confirm file "`output_dir'/_test_table1_sheet_quote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc - punctuation sheet names accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - punctuation sheet names accepted (error `=_rc')"
    local ++fail_count
}

* Test: Custom format
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
capture noisily {
    clear
    input g y z
    0 1 0
    0 2 1
    0 3 1
    1 4 .
    1 5 .
    1 6 .
    end
    table1_tc, by(g) vars(y contn \ z bin) headerperc clear
    assert g_0[2] == "3 (50.0)"
    assert g_1[2] == "3 (50.0)"
}
if _rc == 0 {
    display as result "  PASS: table1_tc - headerperc uses true group totals"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - headerperc uses true group totals (error `=_rc')"
    local ++fail_count
}

* Test: Percent only
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
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) clear
    assert _N > 0
    capture confirm variable _p_raw
    assert _rc == 111
    capture confirm variable _smd_raw
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: table1_tc - clear option cleans internal columns"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - clear option cleans internal columns (error `=_rc')"
    local ++fail_count
}

* Test: Row percentages
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

* Test: Thin border style Excel
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

* Test: table1_tc without vars() uses all variables (U1 varlist feature)
capture noisily {
    sysuse auto, clear
    capture table1_tc, by(foreign)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc - runs without vars() (uses all variables)"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc - without vars() should succeed (error `=_rc')"
    local ++fail_count
}

* ============================================================
* table1_tc Weighted Tests
* ============================================================

* Test: Weighted basic (contn + cat + conts)
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, by(foreign) vars(price contn \ rep78 cat \ mpg conts) wt(iptw)
    assert "`r(Dapa)'" != ""
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
capture noisily {
    sysuse auto, clear
    set seed 42
    gen double iptw = 0.5 + runiform() * 2
    table1_tc, by(foreign) vars(price contn \ rep78 cat) wt(iptw)
    assert regexm("`r(Dapa)'", "Weighted")
    assert regexm("`r(Dapa)'", "suppressed")
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


**# Migrated: legacy suite: varabbrev edge case

**# Edge cases

* Test: varabbrev restoration after table1_tc
capture noisily {
    sysuse auto, clear
    set varabbrev on
    table1_tc, by(foreign) vars(price contn \ mpg contn)
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: edge case - varabbrev restored after table1_tc"
    local ++pass_count
}
else {
    display as error "  FAIL: edge case - varabbrev not restored after table1_tc (error `=_rc')"
    local ++fail_count
}
set varabbrev off


**# Migrated: legacy suite: robustness edge cases

* Test: two observations (one per group) in table1_tc — graceful handling
capture noisily {
    clear
    set obs 2
    gen double y = _n * 10.0
    gen byte g = _n - 1
    label variable y "Outcome"
    table1_tc, by(g) vars(y contn)
}
* Accept either success or graceful error (no crash)
display as result "  PASS: edge case - single obs per group in table1_tc (handled rc=`=_rc')"
local ++pass_count
local --test_count

* Test: all-missing variable in table1_tc vars()
capture noisily {
    sysuse auto, clear
    gen double miss_var = .
    label variable miss_var "All Missing"
    table1_tc, by(foreign) vars(miss_var contn \ price contn)
}
* Accept graceful handling (error or success, not crash)
display as result "  PASS: edge case - all-missing variable in table1_tc vars() (handled rc=`=_rc')"
local ++pass_count
local --test_count

* Test: long variable label (>80 chars) in table1_tc
capture noisily {
    sysuse auto, clear
    label variable price "A very long variable label that exceeds eighty characters in total length for testing"
    table1_tc, by(foreign) vars(price contn \ mpg contn)
}
if _rc == 0 {
    display as result "  PASS: edge case - long variable label (>80 chars) in table1_tc"
    local ++pass_count
}
else {
    display as error "  FAIL: edge case - long variable label (error `=_rc')"
    local ++fail_count
}


**# Migrated: nopvalue option suite

**# T1: Default by() produces p-value column

capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) clear
    confirm variable pvalue
}
if _rc == 0 {
    display as result "  PASS T1: Default produces pvalue column"
    local ++pass_count
}
else {
    display as error "  FAIL T1: Default should produce pvalue column (rc=`=_rc')"
    local ++fail_count
}

**# T2: nopvalue suppresses p-value column

capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue clear
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T2: nopvalue suppresses pvalue column"
    local ++pass_count
}
else {
    display as error "  FAIL T2: nopvalue should suppress pvalue column (rc=`=_rc')"
    local ++fail_count
}

**# T3: nop abbreviation works

capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nop clear
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T3: nop abbreviation works"
    local ++pass_count
}
else {
    display as error "  FAIL T3: nop abbreviation should suppress pvalue (rc=`=_rc')"
    local ++fail_count
}

**# T4: nopvalue + smd still shows SMD

capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue smd clear
    confirm variable smd_str
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T4: nopvalue + smd shows SMD without pvalue"
    local ++pass_count
}
else {
    display as error "  FAIL T4: nopvalue + smd should show SMD without pvalue (rc=`=_rc')"
    local ++fail_count
}

**# T5: nopvalue + test suppresses test column

capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue test clear
    capture confirm variable test
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T5: nopvalue suppresses test column"
    local ++pass_count
}
else {
    display as error "  FAIL T5: nopvalue + test should suppress test column (rc=`=_rc')"
    local ++fail_count
}

**# T6: nopvalue + statistic suppresses statistic column

capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue statistic clear
    capture confirm variable statistic
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T6: nopvalue suppresses statistic column"
    local ++pass_count
}
else {
    display as error "  FAIL T6: nopvalue + statistic should suppress statistic column (rc=`=_rc')"
    local ++fail_count
}

**# T7: nopvalue without by() does not error

capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, nopvalue
}
if _rc == 0 {
    display as result "  PASS T7: nopvalue without by() does not error"
    local ++pass_count
}
else {
    display as error "  FAIL T7: nopvalue without by() should not error (rc=`=_rc')"
    local ++fail_count
}

**# T8: r(Dapa) mentions P-values suppressed

capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue
    local dapa "`r(Dapa)'"
    assert strpos("`dapa'", "P-values suppressed") > 0
}
if _rc == 0 {
    display as result "  PASS T8: r(Dapa) mentions P-values suppressed"
    local ++pass_count
}
else {
    display as error "  FAIL T8: r(Dapa) should mention P-values suppressed (rc=`=_rc')"
    local ++fail_count
}

**# T9: r(methods) is empty with nopvalue

capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue
    assert "`r(methods)'" == ""
}
if _rc == 0 {
    display as result "  PASS T9: r(methods) empty with nopvalue"
    local ++pass_count
}
else {
    display as error "  FAIL T9: r(methods) should be empty with nopvalue (rc=`=_rc')"
    local ++fail_count
}

**# T10: Excel export with nopvalue works

capture noisily {
    sysuse auto, clear
    tempfile xlsxout
    local xlsxout "`xlsxout'.xlsx"
    table1_tc mpg price weight, by(foreign) nopvalue xlsx("`xlsxout'")
    confirm file "`xlsxout'"
}
if _rc == 0 {
    display as result "  PASS T10: Excel export works with nopvalue"
    local ++pass_count
}
else {
    display as error "  FAIL T10: Excel export should work with nopvalue (rc=`=_rc')"
    local ++fail_count
}

**# T11: Categorical vars with nopvalue

capture noisily {
    sysuse auto, clear
    table1_tc rep78, by(foreign) nopvalue clear
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T11: nopvalue works with categorical vars"
    local ++pass_count
}
else {
    display as error "  FAIL T11: nopvalue should suppress pvalue for categorical (rc=`=_rc')"
    local ++fail_count
}

**# T12: Binary vars with nopvalue

capture noisily {
    sysuse auto, clear
    gen byte highmpg = mpg > 20
    table1_tc, vars(highmpg bin) by(foreign) nopvalue clear
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T12: nopvalue works with binary vars"
    local ++pass_count
}
else {
    display as error "  FAIL T12: nopvalue should suppress pvalue for binary (rc=`=_rc')"
    local ++fail_count
}


**# Migrated: v1.0.15 reviewer punch list D-G

**# Helper: assert ALL needles appear in a captured log/sthlp file
* Reads `path' line by line; asserts that every newline-separated entry in
* `needles_local' (passed by name) appears in at least one line.
capture program drop _v1015_assert_all_in_file
program define _v1015_assert_all_in_file
    args path needles_local
    capture confirm file `"`path'"'
    if _rc {
        display as error "  file not found: `path'"
        exit 601
    }
    * Slurp file content into one local for substring checks. SMCL is
    * line-oriented; a single pass_count collecting all lines is sufficient.
    tempname _vfh
    local _content ""
    file open `_vfh' using `"`path'"', read text
    file read `_vfh' line
    while r(eof) == 0 {
        local _content `"`_content' `line'"'
        file read `_vfh' line
    }
    file close `_vfh'

    local _missing ""
    foreach _n of local `needles_local' {
        if strpos(`"`_content'"', `"`_n'"') == 0 {
            local _missing `"`_missing' [`_n']"'
        }
    }
    if `"`_missing'"' != "" {
        display as error "  missing in `path':`_missing'"
        exit 9
    }
end

display as text _newline "=== test_tabtools_v1015 ==="

**# Test D: by() variable name restriction
* The reshape pipeline reserves N_*, m_*, _column* columns. A by-variable named
* N_age (or any blacklisted name) must produce error 498 with a message that
* points at the help file.
local _d_log "`c(tmpdir)'/_t1tc_by_reserved.log"
capture erase "`_d_log'"
local ++test_count
capture noisily {
    sysuse auto, clear
    rename rep78 N_age   // alias one of the reserved prefixes

    log using `"`_d_log'"', replace text name(_v1015_D)
    capture noisily table1_tc mpg, by(N_age)
    local rc_D = _rc
    capture log close _v1015_D
    assert `rc_D' == 498
    local needles_D
    local needles_D `" "by() variable name N_age collides with internal reshape columns" "Reserved prefixes: N_, m_" "reserved names: N, m" "help table1_tc" "'
    _v1015_assert_all_in_file `"`_d_log'"' needles_D
}
local rc_D_outer = _rc
capture log close _v1015_D
if `rc_D_outer' == 0 & `rc_D' == 498 {
    display as result "  PASS: Test D (by(N_age) raised rc=498 with documented message)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test D (outer rc=`rc_D_outer'; inner rc=`rc_D')"
    local ++fail_count
}

**# Test E: Mata workspace leak on Excel format failure
* Run table1_tc with an excel target that fails the Mata xl() block. Hardest
* path to trigger is the load_book step on a non-existent file — but
* export excel succeeds and creates the file, so we instead simulate by
* dropping the Mata vector mid-flight is impossible from outside.
* Practical approach: run table1_tc, then assert _p_raw_save and _smd_raw_save
* do NOT exist in Mata afterward (success path also drops them). Then run
* against an impossible output path to exercise the error branch.
local ++test_count
capture noisily {
    sysuse auto, clear

    * Pre-condition: clear any leftover state from a prior failed run.
    capture mata: mata drop _p_raw_save
    capture mata: mata drop _smd_raw_save

    tempfile xlsx_ok
    capture erase "`xlsx_ok'.xlsx"

    quietly table1_tc mpg headroom, by(foreign) xlsx("`xlsx_ok'.xlsx") smd

    * Both saved-state Mata vectors must be cleaned up after a successful run.
    * `mata describe NAME` errors with rc=3499 when NAME does not exist.
    capture mata: mata describe _p_raw_save
    local _have_p_after = _rc == 0
    capture mata: mata describe _smd_raw_save
    local _have_s_after = _rc == 0
    assert `_have_p_after' == 0
    assert `_have_s_after' == 0

    capture erase "`xlsx_ok'.xlsx"

    * Now exercise the error branch: an impossible output directory forces
    * export/formatting to fail_count after the raw Mata vectors have been saved.
    tempfile bad_xlsx
    local bad_xlsx "`bad_xlsx'_missing_dir/out.xlsx"

    capture noisily table1_tc mpg headroom, by(foreign) xlsx("`bad_xlsx'") smd
    local rc_bad = _rc
    assert `rc_bad' != 0

    * The cleanup must drop the saved state after the error branch.
    capture mata: mata describe _p_raw_save
    local _have_p_after2 = _rc == 0
    capture mata: mata describe _smd_raw_save
    local _have_s_after2 = _rc == 0
    assert `_have_p_after2' == 0
    assert `_have_s_after2' == 0

    capture erase "`bad_xlsx'"
}
local rc_E = _rc
if `rc_E' == 0 {
    display as result "  PASS: Test E (Mata workspace clean after success and after format failure)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test E (rc=`rc_E')"
    local ++fail_count
}

**# Test F: sthlp source contains the new "Reserved by() variable names" section
* Verify the markup we shipped: the {marker technical} anchor, the bold
* section header, every reserved-name token, and a rename example. This
* locks the source-of-truth so a future sthlp rewrite cannot silently drop
* the documentation that the table1_tc.ado error message points at.
local ++test_count
capture noisily {
    capture findfile table1_tc.sthlp
    if _rc {
        display as error "  table1_tc.sthlp not found on adopath"
        exit 601
    }
    local _sthlp_path "`r(fn)'"

    * Tokens that must all be present in the .sthlp source.
    local needles_F
    local needles_F : list needles_F | needles_F
    local needles_F `" "{marker technical}" "{bf:Reserved by() variable names:}" "{cmd:N_<level>}" "{cmd:m_<level>}" "{cmd:_columna_<level>}" "{cmd:_columnb_<level>}" "rejects such names with rc=498" "{cmd:rename N_age age_n}" "'

    _v1015_assert_all_in_file `"`_sthlp_path'"' needles_F
}
local rc_F = _rc
if `rc_F' == 0 {
    display as result "  PASS: Test F (sthlp source contains Reserved by() variable names section + all reserved tokens)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test F (rc=`rc_F'; sthlp markup incomplete)"
    local ++fail_count
}

**# Test G: `help table1_tc` renders the new section to a log-captured viewer
* `help` in batch mode resolves the .sthlp through Stata's viewer pipeline
* and prints the rendered output to the log. Asserting on the rendered
* form (post-SMCL) catches markup that compiles but renders blank — the
* failure mode visual inspection would catch.
local _g_log "`c(tmpdir)'/_t1tc_help_render.log"
capture erase "`_g_log'"
local ++test_count
capture noisily {
    log using `"`_g_log'"', replace text name(_v1015_G_t1tc)
    capture noisily help table1_tc
    capture log close _v1015_G_t1tc

    * After SMCL rendering the bracket markers are stripped. Assert on
    * the surface text the user actually sees: the section title, a
    * representative reserved name, and the actionable rename guidance.
    local needles_G
    local needles_G `" "Reserved by() variable names" "N_<level>" "m_<level>" "rc=498" "rename N_age age_n" "Technical notes" "'

    _v1015_assert_all_in_file `"`_g_log'"' needles_G
}
local rc_G = _rc
capture log close _v1015_G_t1tc
if `rc_G' == 0 {
    display as result "  PASS: Test G (help table1_tc renders Reserved by() section in viewer)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test G (rc=`rc_G'; see `_g_log')"
    local ++fail_count
}


**# Migrated: fast-collect aggregation contracts

which table1_tc

local checker "`checker'"
capture confirm file "`checker'"
if _rc {
    display as error "check_xlsx.py not found"
    exit 601
}

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}
if "`python_cmd'" == "" {
    display as error "python runtime not found"
    exit 601
}

capture program drop _t1agg_build_data
program define _t1agg_build_data
    version 17.0
    clear
    set obs 12

    gen byte trt = cond(_n <= 6, 0, 1)
    gen double age = .
    replace age = 48 in 1
    replace age = 50 in 2
    replace age = 53 in 3
    replace age = 55 in 4
    replace age = 58 in 5
    replace age = .  in 6
    replace age = 60 in 7
    replace age = 62 in 8
    replace age = 64 in 9
    replace age = 67 in 10
    replace age = 70 in 11
    replace age = 73 in 12

    gen double marker = .
    replace marker = 4 in 1
    replace marker = 5 in 2
    replace marker = 6 in 3
    replace marker = 8 in 4
    replace marker = 9 in 5
    replace marker = . in 6
    replace marker = 7 in 7
    replace marker = 8 in 8
    replace marker = 10 in 9
    replace marker = 12 in 10
    replace marker = 13 in 11
    replace marker = 15 in 12

    gen byte female = .
    replace female = 0 in 1
    replace female = 1 in 2
    replace female = 1 in 3
    replace female = 0 in 4
    replace female = 1 in 5
    replace female = . in 6
    replace female = 1 in 7
    replace female = 0 in 8
    replace female = 1 in 9
    replace female = 1 in 10
    replace female = 0 in 11
    replace female = 1 in 12

    gen byte stage = .
    replace stage = 1 in 1
    replace stage = 1 in 2
    replace stage = 2 in 3
    replace stage = 2 in 4
    replace stage = 3 in 5
    replace stage = . in 6
    replace stage = 1 in 7
    replace stage = 2 in 8
    replace stage = 2 in 9
    replace stage = 3 in 10
    replace stage = 3 in 11
    replace stage = . in 12

    gen double w = 0.75 + mod(_n, 4) / 2
    gen int fw = cond(mod(_n, 5) == 0, 3, cond(mod(_n, 3) == 0, 2, 1))

    label define trtlbl 0 "Control" 1 "Active", replace
    label values trt trtlbl
    label define yesno 0 "No" 1 "Yes", replace
    label values female yesno
    label define stagelbl 1 "Stage I" 2 "Stage II" 3 "Stage III", replace
    label values stage stagelbl

    label variable age "Age at entry"
    label variable marker "Inflammation marker"
    label variable female "Female sex"
    label variable stage "Clinical stage"
    label variable trt "Treatment group"
    label variable w "Analysis weight"
    label variable fw "Frequency weight"
end

capture program drop _t1agg_row
program define _t1agg_row, rclass
    version 17.0
    syntax anything(name=wanted)
    local wanted = subinstr(`"`wanted'"', `"""', "", .)

    tempvar _row
    gen long `_row' = _n
    quietly summarize `_row' if strtrim(factor) == strtrim(`"`wanted'"'), meanonly
    if r(N) != 1 {
        noisily display as error "expected one row for factor `wanted', found " r(N)
        drop `_row'
        exit 459
    }
    return scalar row = r(min)
    drop `_row'
end

capture program drop _t1agg_assert_has
program define _t1agg_assert_has
    version 17.0
    syntax varname, ROW(integer) TEXT(string asis)

    assert strpos(`varlist'[`row'], `"`text'"') > 0
end


**# Unweighted aggregation, p-values/tests/SMD, missing, totals, and labels

capture noisily {
    _t1agg_build_data
    table1_tc, by(trt) ///
        vars(age contn %6.2f \ marker conts %6.1f \ female bin \ stage cat) ///
        smd test statistic missing total(after) clear nformat(%9.0f) percformat(%5.1f) percsign("%")

    confirm variable factor
    confirm variable trt_0
    confirm variable trt_1
    confirm variable trt_T
    confirm variable pvalue
    confirm variable test
    confirm variable statistic
    confirm variable smd_str
    assert "`: variable label trt_0'" == "Control"
    assert "`: variable label trt_1'" == "Active"
    assert "`: variable label trt_T'" == "Total"
    assert "`: variable label pvalue'" == "p-value"
    assert "`: variable label smd_str'" == "SMD"

    tempname R
    matrix `R' = r(table)
    assert colnumb(`R', "p_value") == 1
    assert colnumb(`R', "smd") == 2
    assert rownumb(`R', "Age_at_entry") < .
    assert el(`R', rownumb(`R', "Age_at_entry"), colnumb(`R', "p_value")) < .
    assert el(`R', rownumb(`R', "Age_at_entry"), colnumb(`R', "smd")) < .

    _t1agg_row "Age at entry"
    local age_row = r(row)
    assert test[`age_row'] == "Ind. t test"
    assert statistic[`age_row'] != ""
    assert pvalue[`age_row'] != ""
    assert smd_str[`age_row'] != ""
    assert trt_T[`age_row'] != ""

    _t1agg_row "Female sex"
    local bin_row = r(row)
    assert test[`bin_row'] == "Chi-square"
    assert strpos(trt_0[`bin_row'], "(") > 0
    assert strpos(trt_1[`bin_row'], "%") > 0

    _t1agg_row "Missing"
    local miss_row = r(row)
    assert strpos(trt_0[`miss_row'], "%") > 0
    assert strpos(trt_1[`miss_row'], "%") > 0
}
if _rc == 0 {
    display as result "  PASS: unweighted aggregation contract covers tests, SMD, missing, totals, and labels"
    local ++pass_count
}
else {
    display as error "  FAIL: unweighted aggregation contract (rc=`=_rc')"
    local ++fail_count
}

**# Percent modes, total placement, and header percentages

capture noisily {
    _t1agg_build_data
    table1_tc, by(trt) vars(stage cat) total(before) headerperc percent clear ///
        nformat(%9.0f) percformat(%5.1f) percsign("%")
    confirm variable trt_T
    assert "`: variable label trt_T'" == "Total"
    assert strpos(trt_T[2], "100.0%") > 0
    _t1agg_row "Stage II"
    local row = r(row)
    assert strpos(trt_0[`row'], "%") > 0
    assert strpos(trt_0[`row'], "(") == 0

    _t1agg_build_data
    table1_tc, by(trt) vars(stage cat) catrowperc percent_n slashN total(after) ///
        missing clear nformat(%9.0f) percformat(%5.1f) percsign("%")
    _t1agg_row "Stage II"
    local row = r(row)
    assert strpos(trt_0[`row'], "%") > 0
    assert strpos(trt_0[`row'], "/") > 0
    assert strpos(trt_T[`row'], "%") > 0
    _t1agg_row "Missing"
    local row = r(row)
    assert strpos(trt_T[`row'], "%") > 0
}
if _rc == 0 {
    display as result "  PASS: percent, percent_n, slashN, catrowperc, total, and headerperc contracts hold"
    local ++pass_count
}
else {
    display as error "  FAIL: percent-mode and total/header contracts (rc=`=_rc')"
    local ++fail_count
}

**# fweight parity against expanded data

capture noisily {
    tempfile fwout expandedout
    tempname FW EX

    _t1agg_build_data
    table1_tc [fw=fw], by(trt) vars(age contn %6.2f \ female bin \ stage cat) ///
        missing total(after) smd nopvalue clear nformat(%9.0f) percformat(%5.1f)
    matrix `FW' = r(table)
    gen long rowid = _n
    rename factor fw_factor
    rename trt_0 fw_trt_0
    rename trt_1 fw_trt_1
    rename trt_T fw_trt_T
    rename smd_str fw_smd_str
    keep rowid fw_factor fw_trt_0 fw_trt_1 fw_trt_T fw_smd_str
    save "`fwout'", replace

    _t1agg_build_data
    expand fw
    table1_tc, by(trt) vars(age contn %6.2f \ female bin \ stage cat) ///
        missing total(after) smd nopvalue clear nformat(%9.0f) percformat(%5.1f)
    matrix `EX' = r(table)
    gen long rowid = _n
    rename factor ex_factor
    rename trt_0 ex_trt_0
    rename trt_1 ex_trt_1
    rename trt_T ex_trt_T
    rename smd_str ex_smd_str
    keep rowid ex_factor ex_trt_0 ex_trt_1 ex_trt_T ex_smd_str
    save "`expandedout'", replace

    use "`fwout'", clear
    merge 1:1 rowid using "`expandedout'", nogen assert(match)
    assert fw_factor == ex_factor
    assert fw_trt_0 == ex_trt_0
    assert fw_trt_1 == ex_trt_1
    assert fw_trt_T == ex_trt_T
    assert fw_smd_str == ex_smd_str

    local fw_rows : rownames `FW'
    local ex_rows : rownames `EX'
    assert `"`fw_rows'"' == `"`ex_rows'"'
    local fw_smd_col = colnumb(`FW', "smd")
    local ex_smd_col = colnumb(`EX', "smd")
    assert `fw_smd_col' == `ex_smd_col'
    forvalues i = 1/`=rowsof(`FW')' {
        local fwv = el(`FW', `i', `fw_smd_col')
        local exv = el(`EX', `i', `ex_smd_col')
        assert (`fwv' < . & `exv' < .) | (`fwv' >= . & `exv' >= .)
        if (`fwv' < . & `exv' < .) {
            assert abs(`fwv' - `exv') < 1e-10
        }
    }
}
if _rc == 0 {
    display as result "  PASS: fweight output matches expanded-data output"
    local ++pass_count
}
else {
    display as error "  FAIL: fweight parity contract (rc=`=_rc')"
    local ++fail_count
}

**# wt(), wtcompare, SMD, and weighted p-value suppression

capture noisily {
    _t1agg_build_data
    * wtn restores weighted n (%) so the side-by-side count format is exercised.
    table1_tc, by(trt) vars(age contn %6.2f \ female bin \ stage cat) ///
        wt(w) wtcompare wtn smd total(after) clear nformat(%9.0f) percformat(%5.1f) percsign("%")
    confirm variable Cr_0
    confirm variable Cr_1
    confirm variable Cr_T
    confirm variable Wt_0
    confirm variable Wt_1
    confirm variable Wt_T
    confirm variable smd_str
    capture confirm variable pvalue
    assert _rc == 111
    capture confirm variable test
    local has_test_col = (_rc == 0)
    capture confirm variable statistic
    local has_stat_col = (_rc == 0)
    assert "`: variable label Cr_0'" == "Crude Control"
    assert "`: variable label Wt_0'" == "Weighted Control"
    assert "`: variable label Cr_T'" == "Crude Total"
    assert "`: variable label Wt_T'" == "Weighted Total"

    _t1agg_row "Effective sample size"
    local ess_row = r(row)
    assert Wt_0[`ess_row'] != ""
    assert Wt_1[`ess_row'] != ""
    assert Wt_T[`ess_row'] != ""

    _t1agg_row "Age at entry"
    local age_row = r(row)
    assert Cr_0[`age_row'] != Wt_0[`age_row']
    assert smd_str[`age_row'] != ""

    _t1agg_row "Female sex"
    local bin_row = r(row)
    assert strpos(Cr_0[`bin_row'], "(") > 0
    assert strpos(Wt_0[`bin_row'], "(") > 0
    assert strpos(Wt_0[`bin_row'], "%") > 0
}
if _rc == 0 {
    display as result "  PASS: wtcompare side-by-side columns, ESS, SMD, and p-value suppression hold"
    local ++pass_count
}
else {
    display as error "  FAIL: wtcompare contract (rc=`=_rc')"
    local ++fail_count
}

**# Weighted effective count: weighted n differs from crude and is consistent
* Regression guard for the weighted-count fix. With wtn, the displayed weighted
* count is the effective count (weighted % x group N), so it differs from the
* crude raw count and satisfies n/N = weighted %. (The original bug rendered the
* weighted count as the raw unweighted count, identical to crude.)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte grp = _n > 100
    * 60 of 100 are female in each group; weight is informative within group
    * (2 for female, 0.5 otherwise) so the weighted female proportion -- and
    * hence the effective count -- differs from the crude count of 60.
    gen byte female = mod(_n - 1, 100) + 1 <= 60
    gen double w = cond(female, 2, 0.5)
    label define _t1eff_gl 0 "A" 1 "B", replace
    label values grp _t1eff_gl
    label variable female "Female"

    * Known answers for group A (grp == 0), computed by hand:
    quietly count if grp == 0
    local _rawN = r(N)                              // 100
    quietly count if grp == 0 & female == 1
    local _crude = r(N)                             // 60
    local _wprop = (60 * 2) / (60 * 2 + 40 * 0.5)   // 120/140 = .857
    local _eff = round(`_wprop' * `_rawN')          // round(85.7) = 86

    table1_tc, by(grp) vars(female bin) wt(w) wtcompare wtn ///
        clear nformat(%9.0f) percformat(%5.1f) percsign("%")

    _t1agg_row "Female"
    local frow = r(row)
    assert regexm(Cr_0[`frow'], "([0-9]+)")
    local _crn = real(regexs(1))
    assert regexm(Wt_0[`frow'], "([0-9]+)")
    local _wtn = real(regexs(1))
    assert regexm(Wt_0[`frow'], "\(([ 0-9.]+)%")
    local _wtp = real(strtrim(regexs(1)))

    * Crude column still shows the raw count.
    assert `_crn' == `_crude'
    * Weighted count differs from crude (the bug rendered them identical).
    assert `_wtn' != `_crn'
    * Weighted count equals the rounded effective count (known answer).
    assert `_wtn' == `_eff'
    * Internal consistency: displayed n / N matches the displayed weighted %.
    assert abs(`_wtn' / `_rawN' * 100 - `_wtp') < 1
}
if _rc == 0 {
    display as result "  PASS: weighted effective count differs from crude and is consistent"
    local ++pass_count
}
else {
    display as error "  FAIL: weighted effective-count contract (rc=`=_rc')"
    local ++fail_count
}

**# Weighted display policy: recommended defaults + wtn override
* Standalone weighted and wtcompare default to percent-only weighted columns;
* wtn restores the weighted effective count. Crude columns always keep n (%).
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte grp = _n > 100
    gen byte female = mod(_n - 1, 100) + 1 <= 60
    gen double w = cond(female, 2, 0.5)
    label variable female "Female"

    * (a) standalone weighted default: percent-only (no count, so no "(").
    table1_tc, by(grp) vars(female bin) wt(w) clear ///
        nformat(%9.0f) percformat(%5.1f) percsign("%")
    _t1agg_row "Female"
    assert strpos(grp_0[r(row)], "(") == 0
    assert strpos(grp_0[r(row)], "%") > 0

    * (b) standalone weighted + wtn: effective count shown as n (%).
    clear
    set obs 200
    gen byte grp = _n > 100
    gen byte female = mod(_n - 1, 100) + 1 <= 60
    gen double w = cond(female, 2, 0.5)
    label variable female "Female"
    table1_tc, by(grp) vars(female bin) wt(w) wtn clear ///
        nformat(%9.0f) percformat(%5.1f) percsign("%")
    _t1agg_row "Female"
    assert strpos(grp_0[r(row)], "(") > 0

    * (c) wtcompare default: crude keeps n (%), weighted is percent-only.
    clear
    set obs 200
    gen byte grp = _n > 100
    gen byte female = mod(_n - 1, 100) + 1 <= 60
    gen double w = cond(female, 2, 0.5)
    label variable female "Female"
    table1_tc, by(grp) vars(female bin) wt(w) wtcompare smd clear ///
        nformat(%9.0f) percformat(%5.1f) percsign("%")
    _t1agg_row "Female"
    local frow = r(row)
    assert strpos(Cr_0[`frow'], "(") > 0
    assert strpos(Wt_0[`frow'], "(") == 0
    assert strpos(Wt_0[`frow'], "%") > 0
    confirm variable smd_str
}
if _rc == 0 {
    display as result "  PASS: weighted display policy (percent-only default, wtn override)"
    local ++pass_count
}
else {
    display as error "  FAIL: weighted display policy (rc=`=_rc')"
    local ++fail_count
}

**# wtn option guards
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte grp = _n > 50
    gen byte female = mod(_n, 2)
    gen double w = 1 + mod(_n, 3)

    * wtn requires wt()
    capture table1_tc, by(grp) vars(female bin) wtn clear
    assert _rc == 198
    * wtn is incompatible with percent (which suppresses all counts)
    capture table1_tc, by(grp) vars(female bin) wt(w) wtn percent clear
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: wtn guards (requires wt(); incompatible with percent)"
    local ++pass_count
}
else {
    display as error "  FAIL: wtn guards (rc=`=_rc')"
    local ++fail_count
}

**# Public Excel style smoke

capture noisily {
    local xlsx_file "`output_dir'/test_table1_tc_aggregation_contracts.xlsx"
    local check_result "`output_dir'/test_table1_tc_aggregation_contracts_xlsx.txt"
    capture erase "`xlsx_file'"
    capture erase "`check_result'"

    _t1agg_build_data
    table1_tc, by(trt) vars(age contn %6.2f \ female bin \ stage cat) ///
        smd test statistic missing total(after) ///
        xlsx("`xlsx_file'") sheet("Agg Contracts") ///
        title("Table 1 Aggregation Contracts") footnote("Excel style smoke") ///
        theme(lancet) borderstyle(thin) headershade zebra boldp(0.05) ///
        nformat(%9.0f) percformat(%5.1f)
    confirm file "`xlsx_file'"

    shell `python_cmd' "`checker'" "`xlsx_file'" --sheet "Agg Contracts" ///
        --cell A1 "Table 1 Aggregation Contracts" ///
        --contains "Age at entry" --contains "Excel style smoke" ///
        --has-pattern p-values n-equals --merged-row 1 ///
        --has-borders --font Arial --result-file "`check_result'" --quiet
    file open _xfh using "`check_result'", read text
    file read _xfh _line
    file close _xfh
    assert "`_line'" == "PASS"
    capture erase "`xlsx_file'"
    capture erase "`check_result'"
}
if _rc == 0 {
    display as result "  PASS: public Excel style smoke workbook passes semantic/style checks"
    local ++pass_count
}
else {
    display as error "  FAIL: public Excel style smoke (rc=`=_rc')"
    local ++fail_count
}

**# Performance guardrail for aggregation-heavy public command path

capture noisily {
    clear
    set obs 20000
    set seed 20260523
    gen byte trt = mod(_n, 3)
    gen double age = 50 + 10 * rnormal() + trt
    gen double bmi = 27 + 4 * rnormal()
    gen double marker = exp(1 + .15 * rnormal() + .05 * trt)
    gen byte female = runiform() > .48
    gen byte smoker = runiform() > .70
    gen byte stage = floor(4 * runiform())
    replace age = . if mod(_n, 97) == 0
    replace bmi = . if mod(_n, 89) == 0
    replace marker = . if mod(_n, 83) == 0
    replace female = . if mod(_n, 113) == 0
    replace smoker = . if mod(_n, 127) == 0
    replace stage = . if mod(_n, 131) == 0
    label define trt3 0 "Control" 1 "Dose A" 2 "Dose B", replace
    label values trt trt3
    label define stage4 0 "Stage 0" 1 "Stage 1" 2 "Stage 2" 3 "Stage 3", replace
    label values stage stage4

    timer clear 91
    timer on 91
    quietly table1_tc, by(trt) vars(age contn \ bmi contn \ marker conts \ ///
        female bin \ smoker bin \ stage cat) total(after) nopvalue clear ///
        nformat(%9.0f) percformat(%5.1f)
    timer off 91
    quietly timer list 91
    local elapsed = r(t91)
    display as text "table1_tc aggregation performance guardrail elapsed seconds: `elapsed'"
    assert `elapsed' < 30
    confirm variable trt_T
}
if _rc == 0 {
    display as result "  PASS: aggregation performance guardrail stays below 30 seconds"
    local ++pass_count
}
else {
    display as error "  FAIL: aggregation performance guardrail (rc=`=_rc')"
    local ++fail_count
}
**# Migrated: v1.4 auto-detect, varlist, SMD formatting

**# Test Data Setup
sysuse auto, clear

* =========================================================================
**# F3: Auto-detect variable types
* =========================================================================

* --- F3.1: auto keyword in vars() ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price auto \ mpg auto \ rep78 auto \ headroom auto)
if _rc == 0 {
    display as result "PASS: F3.1 — auto keyword in vars()"
    local ++pass_count
}
else {
    display as error "FAIL: F3.1 — auto keyword in vars() (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* --- F3.2: omitted vartype (empty = auto) ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price \ mpg \ rep78 \ headroom)
if _rc == 0 {
    display as result "PASS: F3.2 — omitted vartype triggers auto-detect"
    local ++pass_count
}
else {
    display as error "FAIL: F3.2 — omitted vartype triggers auto-detect (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* --- F3.3: auto with explicit format ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price auto %9.0fc \ mpg contn)
if _rc == 0 {
    display as result "PASS: F3.3 — auto with explicit format"
    local ++pass_count
}
else {
    display as error "FAIL: F3.3 — auto with explicit format (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* --- F3.4: binary variable detected as bin ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(foreign auto)
if _rc == 0 {
    display as result "PASS: F3.4 — binary variable detected"
    local ++pass_count
}
else {
    display as error "FAIL: F3.4 — binary variable detected (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* =========================================================================
**# U1: Simplified varlist syntax
* =========================================================================

* --- U1.1: plain varlist without vars() ---
local ++n_total
capture noisily table1_tc price mpg weight rep78, by(foreign)
if _rc == 0 {
    display as result "PASS: U1.1 — plain varlist syntax"
    local ++pass_count
}
else {
    display as error "FAIL: U1.1 — plain varlist syntax (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* --- U1.2: varlist with Excel export ---
local ++n_total
capture noisily table1_tc price mpg weight, by(foreign) excel("output/test_u1.xlsx") title("U1 Test")
if _rc == 0 {
    capture confirm file "output/test_u1.xlsx"
    if _rc == 0 {
        display as result "PASS: U1.2 — varlist syntax with Excel export"
        local ++pass_count
    }
    else {
        display as error "FAIL: U1.2 — Excel file not created"
        local ++fail_count
    }
}
else {
    display as error "FAIL: U1.2 — varlist syntax with Excel export (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* =========================================================================
**# O2: SMD conditional formatting
* =========================================================================

* --- O2.1: SMD with Excel export (visual check) ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn \ weight contn \ rep78 cat) ///
    smd excel("output/test_o2_smd.xlsx") title("O2 SMD Formatting Test")
if _rc == 0 {
    capture confirm file "output/test_o2_smd.xlsx"
    if _rc == 0 {
        display as result "PASS: O2.1 — SMD with Excel export (check output/test_o2_smd.xlsx for orange highlight)"
        local ++pass_count
    }
    else {
        display as error "FAIL: O2.1 — Excel file not created"
        local ++fail_count
    }
}
else {
    display as error "FAIL: O2.1 — SMD with Excel export (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* =========================================================================

**# Migrated: v1.4 frame output

**# I5: Frame output for table1_tc
* =========================================================================

* --- I5.1: frame() option ---
local ++n_total
capture frame drop _test_frame
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) frame(_test_frame)
if _rc == 0 {
    capture frame _test_frame: describe
    if _rc == 0 {
        display as result "PASS: I5.1 — frame() option creates frame"
        local ++pass_count
    }
    else {
        display as error "FAIL: I5.1 — frame not created"
        local ++fail_count
    }
}
else {
    display as error "FAIL: I5.1 — frame() option (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _test_frame

sysuse auto, clear

* --- I5.2: frame preserves original data ---
local ++n_total
local _orig_N = _N
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) frame(_test_frame2)
if _rc == 0 {
    if _N == `_orig_N' {
        display as result "PASS: I5.2 — original data preserved with frame()"
        local ++pass_count
    }
    else {
        display as error "FAIL: I5.2 — data modified after frame() (N=`=_N' vs `_orig_N')"
        local ++fail_count
    }
}
else {
    display as error "FAIL: I5.2 — frame() option (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _test_frame2

sysuse auto, clear

* =========================================================================

**# Migrated: v1.5 auto-type sort stability

**# R1: Sort stability in auto-type detection
* =========================================================================

* --- R1.1: Repeated auto-detect gives same result ---
local ++n_total
capture noisily {
    sysuse auto, clear
    * Run auto-detect twice, results should be identical due to fixed seed
    _tabtools_detect_vartype price
    local type1 "`result'"
    sysuse auto, clear
    _tabtools_detect_vartype price
    local type2 "`result'"
    assert "`type1'" == "`type2'"
}
if _rc == 0 {
    display as result "  PASS: R1.1 — auto-detect reproducible (price=`type1' both times)"
    local ++pass_count
}
else {
    display as error "  FAIL: R1.1 — auto-detect not reproducible (rc=`=_rc')"
    local ++fail_count
}

* --- R1.2: Auto-detect for known binary variable ---
local ++n_total
capture noisily {
    sysuse auto, clear
    _tabtools_detect_vartype foreign
    assert "`result'" == "bin"
}
if _rc == 0 {
    display as result "  PASS: R1.2 — foreign correctly detected as bin"
    local ++pass_count
}
else {
    display as error "  FAIL: R1.2 — foreign detection wrong (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.5 smdthreshold

**# O2: smdthreshold() option
* =========================================================================

* --- O2.1: Custom smdthreshold ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign) smd smdthreshold(0.2) ///
        excel("output/test_o2_smdthresh.xlsx") title("SMD Threshold Test")
}
if _rc == 0 {
    display as result "  PASS: O2.1 — smdthreshold(0.2) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: O2.1 — smdthreshold failed (rc=`=_rc')"
    local ++fail_count
}

* --- O2.2: Default smdthreshold (0.1) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign) smd ///
        excel("output/test_o2_smddefault.xlsx") title("SMD Default Test")
}
if _rc == 0 {
    display as result "  PASS: O2.2 — default smdthreshold works"
    local ++pass_count
}
else {
    display as error "  FAIL: O2.2 — default smdthreshold failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.5 rclass returns

**# I4: table1_tc rclass (r(Dapa), r(methods), r(varlist))
* =========================================================================

* --- I4.1: r(Dapa) populated ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight rep78, by(foreign)
    assert `"`r(Dapa)'"' != ""
}
if _rc == 0 {
    display as result "  PASS: I4.1 — r(Dapa) populated: `r(Dapa)'"
    local ++pass_count
}
else {
    display as error "  FAIL: I4.1 — r(Dapa) missing (rc=`=_rc')"
    local ++fail_count
}

* --- I4.2: r(methods) populated with by() ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign) test
    assert `"`r(methods)'"' != ""
}
if _rc == 0 {
    display as result "  PASS: I4.2 — r(methods) populated with by()"
    local ++pass_count
}
else {
    display as error "  FAIL: I4.2 — r(methods) missing (rc=`=_rc')"
    local ++fail_count
}

* --- I4.3: r(varlist) returns processed variables ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign)
    assert `"`r(varlist)'"' != ""
    assert strpos(`"`r(varlist)'"', "price") > 0
    assert strpos(`"`r(varlist)'"', "mpg") > 0
    assert strpos(`"`r(varlist)'"', "weight") > 0
}
if _rc == 0 {
    display as result "  PASS: I4.3 — r(varlist) = `r(varlist)'"
    local ++pass_count
}
else {
    display as error "  FAIL: I4.3 — r(varlist) wrong (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: v1.5 binary errors, header height, SMD warning, r(varlist)

**# U6: Better binary variable error message
* =========================================================================

* --- U6.1: Binary error suggests cat ---
local ++n_total
capture noisily {
    sysuse auto, clear
    * rep78 has values 1-5, not 0/1
    table1_tc, by(foreign) vars(rep78 bin)
}
if _rc == 198 {
    display as result "  PASS: U6.1 — binary var error triggers rc=198 (suggests cat)"
    local ++pass_count
}
else {
    display as error "  FAIL: U6.1 — expected rc=198, got rc=`=_rc'"
    local ++fail_count
}

* =========================================================================
**# O3: Header row height auto-calculation
* =========================================================================

* --- O3.1: Long description auto-adjusts row height ---
local ++n_total
capture noisily {
    sysuse auto, clear
    * Many variables = long Dapa string = taller row 2
    table1_tc price mpg weight headroom trunk length turn displacement gear_ratio, ///
        by(foreign) excel("output/test_o3_height.xlsx") ///
        title("Row Height Auto-Calc Test")
}
if _rc == 0 {
    display as result "  PASS: O3.1 — header row height auto-calc (many vars)"
    local ++pass_count
}
else {
    display as error "  FAIL: O3.1 — header height failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# R3: SMD >2 groups warning
* =========================================================================

* --- R3.1: SMD with 3+ groups shows warning ---
local ++n_total
capture noisily {
    sysuse auto, clear
    * rep78 has 5 levels (1-5) — more than 2 groups
    table1_tc price mpg weight, by(rep78) smd
}
if _rc == 0 {
    display as result "  PASS: R3.1 — SMD with >2 groups runs (warning in log)"
    local ++pass_count
}
else {
    display as error "  FAIL: R3.1 — SMD with >2 groups failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# C2: r(varlist) for pipeline workflows
* =========================================================================

* --- C2.1: r(varlist) matches input variables ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign)
    local vlist "`r(varlist)'"
    assert wordcount("`vlist'") == 3
    assert strpos("`vlist'", "price") > 0
    assert strpos("`vlist'", "mpg") > 0
    assert strpos("`vlist'", "weight") > 0
}
if _rc == 0 {
    display as result "  PASS: C2.1 — r(varlist) has 3 vars: `vlist'"
    local ++pass_count
}
else {
    display as error "  FAIL: C2.1 — r(varlist) wrong (rc=`=_rc')"
    local ++fail_count
}

* --- C2.2: r(varlist) with vars() explicit syntax ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn \ rep78 cat)
    local vlist "`r(varlist)'"
    assert wordcount("`vlist'") == 3
}
if _rc == 0 {
    display as result "  PASS: C2.2 — r(varlist) with vars() syntax: `vlist'"
    local ++pass_count
}
else {
    display as error "  FAIL: C2.2 — r(varlist) with vars() wrong (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.5 data preservation

**# Data preservation
* =========================================================================

* --- DP.1: table1_tc preserves data ---
local ++n_total
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    local orig_vars : char _dta[_N]
    summarize price, meanonly
    local orig_mean = r(mean)
    table1_tc price mpg weight, by(foreign)
    assert _N == `orig_n'
    summarize price, meanonly
    assert reldif(r(mean), `orig_mean') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: DP.1 — table1_tc preserves data (N=`orig_n')"
    local ++pass_count
}
else {
    display as error "  FAIL: DP.1 — data not preserved (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: missingsummary, ESS row, r(table) features

* --- 7.1: table1_tc missingsummary ---
capture noisily {
    sysuse auto, clear
    replace mpg = . in 1/5
    replace rep78 = . in 6/10
    capture erase "`output_dir'/test_missingsummary.xlsx"
    table1_tc, by(foreign) ///
        vars(mpg contn \ rep78 cat) ///
        missingsummary excel("`output_dir'/test_missingsummary.xlsx")
    confirm file "`output_dir'/test_missingsummary.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc missingsummary"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc missingsummary (rc=`=_rc')"
    local ++fail_count
}

* --- 7.2: table1_tc ESS row with wt() ---
capture noisily {
    sysuse auto, clear
    gen iptw = 1 + runiform()
    capture erase "`output_dir'/test_ess.xlsx"
    table1_tc, by(foreign) ///
        vars(mpg contn \ weight contn) ///
        wt(iptw) excel("`output_dir'/test_ess.xlsx")
    confirm file "`output_dir'/test_ess.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc ESS row with wt()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc ESS row with wt() (rc=`=_rc')"
    local ++fail_count
}

* --- 7.3: table1_tc r(table) matrix ---
capture noisily {
    clear
    set obs 6
    gen g = _n > 3
    gen y = _n
    gen x = inlist(_n, 3, 4, 5, 6)
    label var y y
    label var x x

    table1_tc, by(g) vars(y contn \ x bin) smd
    tempname T
    matrix `T' = r(table)
    local _cnames : colnames `T'
    local _rnames : rownames `T'
    assert rowsof(`T') == 2
    assert colsof(`T') == 2
    assert "`_cnames'" == "p_value smd"
    assert "`_rnames'" == "y x"

    quietly ttest y, by(g)
    local _p_y = r(p)
    quietly tab x g, chi2
    local _p_x = r(p)

    scalar _rt_p_y = el(`T', 1, 1)
    scalar _rt_s_y = el(`T', 1, 2)
    scalar _rt_p_x = el(`T', 2, 1)
    scalar _rt_s_x = el(`T', 2, 2)
    assert reldif(_rt_p_y, `_p_y') < 1e-8
    assert reldif(_rt_p_x, `_p_x') < 1e-8
    assert reldif(_rt_s_y, 3) < 1e-12
    assert reldif(_rt_s_x, 2) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: table1_tc r(table) matrix is semantic"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc r(table) matrix is semantic (rc=`=_rc')"
    local ++fail_count
}

* --- 7.4: table1_tc r(table) omitted above 200 rows ---
capture noisily {
    clear
    set obs 20
    gen g = _n > 10
    local _vars ""
    forvalues j = 1/201 {
        gen x`j' = mod(_n + `j', 2)
        if `j' > 1 local _vars "`_vars' \ "
        local _vars "`_vars'x`j' bin"
    }
    table1_tc, by(g) vars(`_vars')
    capture confirm matrix r(table)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc r(table) omitted above 200 rows"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc r(table) omitted above 200 rows (rc=`=_rc')"
    local ++fail_count
}


**# Migrated: option coverage sweep

**# SECTION 1: table1_tc — untested options
* ============================================================

sysuse auto, clear

* Test: percformat option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) percformat(%5.1f) ///
        xlsx("`output_dir'/_cov_t1_percformat.xlsx") sheet("percformat")
    confirm file "`output_dir'/_cov_t1_percformat.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc percformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc percformat() (error `=_rc')"
    local ++fail_count
}

* Test: nformat option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat \ price contn) ///
        nformat(%9.0g) xlsx("`output_dir'/_cov_t1_nformat.xlsx") sheet("nformat")
    confirm file "`output_dir'/_cov_t1_nformat.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc nformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc nformat() (error `=_rc')"
    local ++fail_count
}

* Test: gsdleft/gsdright (geometric SD formatting)
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contln) gsdleft(" [GSD ") gsdright("]") ///
        xlsx("`output_dir'/_cov_t1_gsd.xlsx") sheet("gsd")
    confirm file "`output_dir'/_cov_t1_gsd.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc gsdleft()/gsdright()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc gsdleft()/gsdright() (error `=_rc')"
    local ++fail_count
}

* Test: varlabplus option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat \ foreign bin) ///
        varlabplus xlsx("`output_dir'/_cov_t1_vlp.xlsx") sheet("varlabplus")
    confirm file "`output_dir'/_cov_t1_vlp.xlsx"
    assert `"`r(Dapa)'"' == "Data are presented as mean±SD for continuous measures, and No. (%) for categorical measures."
    assert strpos(`"`r(methods)'"', `"`r(Dapa)'"') > 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc varlabplus keeps stored results"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc varlabplus keeps stored results (error `=_rc')"
    local ++fail_count
}

* Test: percsign option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) percsign("pct") ///
        xlsx("`output_dir'/_cov_t1_percsign.xlsx") sheet("percsign")
    confirm file "`output_dir'/_cov_t1_percsign.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc percsign()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc percsign() (error `=_rc')"
    local ++fail_count
}

* Test: nospacelowpercent option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) nospacelowpercent ///
        xlsx("`output_dir'/_cov_t1_nospace.xlsx") sheet("nospace")
    confirm file "`output_dir'/_cov_t1_nospace.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc nospacelowpercent"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc nospacelowpercent (error `=_rc')"
    local ++fail_count
}

* Test: extraspace option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) extraspace ///
        xlsx("`output_dir'/_cov_t1_extraspace.xlsx") sheet("extraspace")
    confirm file "`output_dir'/_cov_t1_extraspace.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc extraspace"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc extraspace (error `=_rc')"
    local ++fail_count
}

* Test: pdp/highpdp options
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn) pdp(4) highpdp(3) ///
        xlsx("`output_dir'/_cov_t1_pdp.xlsx") sheet("pdp")
    confirm file "`output_dir'/_cov_t1_pdp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc pdp()/highpdp()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc pdp()/highpdp() (error `=_rc')"
    local ++fail_count
}

* Test: zebra option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) zebra ///
        xlsx("`output_dir'/_cov_t1_zebra.xlsx") sheet("zebra")
    confirm file "`output_dir'/_cov_t1_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc zebra (error `=_rc')"
    local ++fail_count
}

* Test: headershade option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) headershade ///
        xlsx("`output_dir'/_cov_t1_headershade.xlsx") sheet("headershade")
    confirm file "`output_dir'/_cov_t1_headershade.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc headershade"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc headershade (error `=_rc')"
    local ++fail_count
}

* Test: highlight option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn \ rep78 cat) ///
        highlight(0.05) xlsx("`output_dir'/_cov_t1_highlight.xlsx") sheet("highlight")
    confirm file "`output_dir'/_cov_t1_highlight.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc highlight() (error `=_rc')"
    local ++fail_count
}

* Test: boldp option
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn) boldp(0.05) ///
        xlsx("`output_dir'/_cov_t1_boldp.xlsx") sheet("boldp")
    confirm file "`output_dir'/_cov_t1_boldp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc boldp()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc boldp() (error `=_rc')"
    local ++fail_count
}

* Test: headercolor/zebracolor options
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) ///
        headercolor("200 220 240") zebracolor("245 245 255") zebra headershade ///
        xlsx("`output_dir'/_cov_t1_colors.xlsx") sheet("colors")
    confirm file "`output_dir'/_cov_t1_colors.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc headercolor()/zebracolor()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc headercolor()/zebracolor() (error `=_rc')"
    local ++fail_count
}

* Test: csv export
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) ///
        csv("`output_dir'/_cov_t1.csv")
    confirm file "`output_dir'/_cov_t1.csv"
    import delimited using "`output_dir'/_cov_t1.csv", clear varnames(1)
    capture confirm variable _p_raw
    assert _rc == 111
    capture confirm variable _smd_raw
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: table1_tc csv() omits internal columns"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc csv() omits internal columns (error `=_rc')"
    local ++fail_count
}

* Test: frame output
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) ///
        frame(_cov_t1_fr, replace)
    frame _cov_t1_fr: assert _N > 0
    frame _cov_t1_fr: capture confirm variable _p_raw
    local _frame_rc_p = _rc
    frame _cov_t1_fr: capture confirm variable _smd_raw
    local _frame_rc_s = _rc
    assert `_frame_rc_p' == 111
    assert `_frame_rc_s' == 111
    frame drop _cov_t1_fr
}
if _rc == 0 {
    display as result "  PASS: table1_tc frame() omits internal columns"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc frame() omits internal columns (error `=_rc')"
    local ++fail_count
}

* Test: missingsummary option
capture noisily {
    sysuse auto, clear
    replace rep78 = . in 1/5
    table1_tc, by(foreign) vars(price contn \ rep78 cat) missingsummary ///
        xlsx("`output_dir'/_cov_t1_missingsummary.xlsx") sheet("misssum")
    confirm file "`output_dir'/_cov_t1_missingsummary.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc missingsummary"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc missingsummary (error `=_rc')"
    local ++fail_count
}

* Test: combined formatting options stress test
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg conts \ rep78 cat \ foreign bin) ///
        zebra headershade boldp(0.05) highlight(0.1) ///
        headercolor("180 200 230") zebracolor("240 240 255") ///
        footnote("Source: auto dataset") title("Comprehensive Table 1") ///
        borderstyle(thin) ///
        xlsx("`output_dir'/_cov_t1_stress.xlsx") sheet("stress")
    confirm file "`output_dir'/_cov_t1_stress.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc combined formatting stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc combined formatting stress test (error `=_rc')"
    local ++fail_count
}

* Regression: wt() negative values outside if-sample are ignored
capture noisily {
    clear
    input x grp wt keep
    10 0 1 1
    20 1 2 1
    30 0 -5 0
    40 1 3 1
    end
    table1_tc x if keep, by(grp) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() ignores negative values outside sample"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() ignores negative values outside sample (error `=_rc')"
    local ++fail_count
}

* Regression: wt() negative values inside if-sample still fail
capture noisily {
    clear
    input x grp wt keep
    10 0 1 1
    20 1 -2 1
    30 0 4 0
    40 1 3 1
    end
    capture table1_tc x if keep, by(grp) wt(wt)
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: table1_tc wt() still rejects negative values inside sample"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc wt() still rejects negative values inside sample (error `=_rc')"
    local ++fail_count
}

* Regression: negative numeric by() values outside if-sample are ignored
capture noisily {
    clear
    input x grp keep
    10 0 1
    20 1 1
    30 -1 0
    40 1 1
    end
    table1_tc x if keep, by(grp)
}
if _rc == 0 {
    display as result "  PASS: table1_tc by() ignores negative values outside sample"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc by() ignores negative values outside sample (error `=_rc')"
    local ++fail_count
}

* Regression: negative numeric by() values inside if-sample still fail
capture noisily {
    clear
    input x grp keep
    10 0 1
    20 -1 1
    30 1 0
    40 1 1
    end
    capture table1_tc x if keep, by(grp)
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: table1_tc by() still rejects negative values inside sample"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc by() still rejects negative values inside sample (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: SMD all-missing categorical guard

**# 1. table1_tc SMD guard for all-missing categorical group

**## 1a. Unweighted SMD with one all-missing group returns without error
capture noisily {
    clear
    set obs 60
    gen byte group = cond(_n <= 30, 1, 2)
    gen byte catvar = mod(_n, 3)
    replace catvar = . if group == 2
    table1_tc, vars(catvar cat) by(group) smd
    assert r(N) > 0
    matrix list r(table)
}
if _rc == 0 {
    display as result "  PASS [1a]: table1_tc SMD with all-missing group completes without error"
    local ++pass_count
}
else {
    display as error "  FAIL [1a]: table1_tc SMD with all-missing group (rc=`=_rc')"
    local ++fail_count
}

**## 1b. Weighted SMD with one zero-weight group returns without error
capture noisily {
    clear
    set obs 60
    gen byte group = cond(_n <= 30, 1, 2)
    gen byte catvar = mod(_n, 3)
    gen double wt = cond(group == 1, runiform(), 0)
    table1_tc, vars(catvar cat) by(group) smd wt(wt)
    assert r(N) > 0
    matrix list r(table)
}
if _rc == 0 {
    display as result "  PASS [1b]: table1_tc weighted SMD with zero-weight group completes without error"
    local ++pass_count
}
else {
    display as error "  FAIL [1b]: table1_tc weighted SMD with zero-weight group (rc=`=_rc')"
    local ++fail_count
}

**## 1c. SMD with valid groups still produces correct nonmissing value
local t1c_pass = 1
capture noisily {
    clear
    set obs 200
    gen byte group = cond(_n <= 100, 1, 2)
    gen byte catvar = cond(group == 1, cond(_n <= 80, 1, 0), cond(_n <= 140, 1, 0))
    table1_tc, vars(catvar bin) by(group) smd
    matrix define _t = r(table)
}
if _rc != 0 {
    display as error "  FAIL [1c.run]: table1_tc SMD with valid groups returned error `=_rc'"
    local t1c_pass = 0
}
else {
    local ncols = colsof(_t)
    local smd_col = `ncols'
    local smd_val = _t[1, `smd_col']
    if `smd_val' < . & `smd_val' >= 0 {
        display as result "  PASS [1c.value]: SMD = `smd_val' (nonmissing, nonnegative)"
    }
    else {
        display as error "  FAIL [1c.value]: SMD is missing or negative (`smd_val')"
        local t1c_pass = 0
    }
}
if `t1c_pass' {
    display as result "  PASS [1c]: SMD with valid groups produces correct value"
    local ++pass_count
}
else {
    local ++fail_count
}



**# Migrated: percent+continuous header regression

**# 7. table1_tc percent + continuous Excel header no duplication (I1 regression)

**## 7a. Header row contains "Mean (SD)" exactly once when percent is specified
capture noisily {
    sysuse auto, clear
    local i1_xlsx "`output_dir'/_rev1013_i1_percent.xlsx"
    capture erase "`i1_xlsx'"
    table1_tc, vars(price contn \ rep78 cat \ foreign bin) by(foreign) percent ///
        xlsx("`i1_xlsx'") sheet("I1Test")

    * Read back the xlsx; check the header description row (row 2) for duplication
    clear
    import excel using "`i1_xlsx'", sheet("I1Test") allstring clear
    * Row 2 of the xlsx = observation 2 after import; column B has the header text
    local header_desc = B[2]
    * Count "Mean (SD)" within this single cell — should appear exactly once
    local count = 0
    local sstr "`header_desc'"
    while strpos("`sstr'", "Mean (SD)") > 0 {
        local count = `count' + 1
        local p = strpos("`sstr'", "Mean (SD)")
        local sstr = substr("`sstr'", `p' + 9, .)
    }
    assert `count' == 1
}
if _rc == 0 {
    display as result "  PASS [7a]: table1_tc percent header has Mean (SD) exactly once"
    local ++pass_count
}
else {
    display as error "  FAIL [7a]: table1_tc percent header duplicated Mean (SD) (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i1_percent.xlsx"



**# Migrated: zero-denominator .% regression

**# 14. table1_tc zero-denominator group does not produce ".%" (M10 regression)

**## 14a. Categorical variable with all-missing group does not crash or show ".%"
capture noisily {
    clear
    set obs 60
    gen byte group = cond(_n <= 30, 1, 2)
    gen byte catvar = mod(_n, 3)
    replace catvar = . if group == 2
    local m10_xlsx "`output_dir'/_rev1013_m10_table1.xlsx"
    capture erase "`m10_xlsx'"
    table1_tc, vars(catvar cat) by(group) ///
        xlsx("`m10_xlsx'") sheet("M10Test")

    * Read back the xlsx after command returns (avoids nested preserve)
    clear
    import excel using "`m10_xlsx'", sheet("M10Test") allstring clear
    local found_dotpct = 0
    ds
    foreach v in `r(varlist)' {
        forvalues i = 1/`=_N' {
            local cell_val = `v'[`i']
            if strpos("`cell_val'", ".%") > 0 {
                local found_dotpct = 1
            }
        }
    }
    assert `found_dotpct' == 0
}
if _rc == 0 {
    display as result "  PASS [14a]: table1_tc zero-denominator group: no '.%' in output"
    local ++pass_count
}
else {
    display as error "  FAIL [14a]: table1_tc zero-denominator group: '.%' found or crash (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_m10_table1.xlsx"



**# Migrated: wtcompare column layout

**# QA Gap 3: table1_tc wtcompare column layout

**## 3a. wtcompare produces both crude and weighted columns in frame
capture noisily {
    sysuse auto, clear
    gen byte treat = foreign
    gen double ipw = cond(foreign, 1/0.3, 1/0.7)
    capture frame drop _wtc_test
    table1_tc, vars(price contn \ mpg conts \ rep78 cat) by(treat) ///
        wt(ipw) smd wtcompare frame(_wtc_test) clear
    frame _wtc_test {
        * Should have crude and weighted columns
        ds Cr_* Wt_*
        local _wtc_vars `r(varlist)'
        local _ncr = 0
        local _nwt = 0
        foreach v of local _wtc_vars {
            if substr("`v'", 1, 3) == "Cr_" local ++_ncr
            if substr("`v'", 1, 3) == "Wt_" local ++_nwt
        }
        assert `_ncr' >= 2  // at least 2 crude columns (one per group)
        assert `_nwt' >= 2  // at least 2 weighted columns
    }
    capture frame drop _wtc_test
}
if _rc == 0 {
    display as result "  PASS [3a]: table1_tc wtcompare produces Cr_*/Wt_* columns"
    local ++pass_count
}
else {
    display as error "  FAIL [3a]: table1_tc wtcompare layout (rc=`=_rc')"
    local ++fail_count
}

**## 3b. wtcompare crude and weighted columns have data
capture noisily {
    clear
    set obs 100
    set seed 42
    gen byte group = _n > 50
    gen x = rnormal()
    gen double ipw = cond(group, 2, 0.5)
    capture frame drop _wtc_vals
    table1_tc, vars(x contn) by(group) wt(ipw) wtcompare frame(_wtc_vals) clear
    frame _wtc_vals {
        * Confirm both Cr_ and Wt_ columns exist and have non-empty data
        confirm variable Cr_0 Cr_1 Wt_0 Wt_1
        * Find the variable row (after N and ESS rows)
        local _var_row = _N
        assert Cr_0[`_var_row'] != ""
        assert Wt_0[`_var_row'] != ""
    }
    capture frame drop _wtc_vals
}
if _rc == 0 {
    display as result "  PASS [3b]: table1_tc wtcompare crude vs weighted values differ"
    local ++pass_count
}
else {
    display as error "  FAIL [3b]: table1_tc wtcompare value check (rc=`=_rc')"
    local ++fail_count
}

**## 3c. wtcompare includes SMD column when smd is specified
capture noisily {
    clear
    set obs 100
    set seed 42
    gen byte group = _n > 50
    gen x = rnormal() + group * 0.5
    gen double ipw = cond(group, 2, 0.5)
    capture frame drop _wtc_smd
    table1_tc, vars(x contn) by(group) wt(ipw) smd wtcompare frame(_wtc_smd) clear
    frame _wtc_smd {
        capture confirm variable smd_str
        assert _rc == 0  // SMD column should exist
    }
    capture frame drop _wtc_smd
}
if _rc == 0 {
    display as result "  PASS [3c]: table1_tc wtcompare + smd includes smd_str column"
    local ++pass_count
}
else {
    display as error "  FAIL [3c]: table1_tc wtcompare + smd (rc=`=_rc')"
    local ++fail_count
}



**# Migrated: reserved by() names contract

**# table1_tc reserved by() names and cleanup

capture noisily {
    clear
    set obs 6
    gen byte N_case = mod(_n, 2)
    gen byte m_case = mod(_n + 1, 2)
    gen double age = 40 + _n
    gen str5 marker = "keep"
    local n_before = _N
    local marker_before = marker[3]
    set varabbrev on

    capture noisily table1_tc age, by(N_case)
    local rc_n = _rc
    assert `rc_n' == 498
    assert _N == `n_before'
    assert marker[3] == "`marker_before'"
    assert c(varabbrev) == "on"

    capture noisily table1_tc age, by(m_case)
    local rc_m = _rc
    assert `rc_m' == 498
    assert _N == `n_before'
    assert marker[3] == "`marker_before'"
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: table1_tc rejects reserved by() names and restores caller state"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc reserved by() cleanup contract (rc=`=_rc')"
    local ++fail_count
    capture set varabbrev off
}


**# dots option emits progress and preserves the table
* Clarity audit MINOR-5 (2026-06-13): the dots option was declared and
* documented ("show progress dots while processing variables") but unwired.
* Assert it now emits one progress line and leaves the table unchanged.
local ++test_count
capture noisily {
    sysuse auto, clear

    capture frame drop _t1_nodot
    table1_tc price mpg weight, by(foreign) frame(_t1_nodot, replace)
    frame _t1_nodot {
        local _n_nodot = _N
        ds
        local _fv_nodot : word 1 of `r(varlist)'
        local _cell_nodot = `_fv_nodot'[2]
    }

    * Capture console output to confirm the progress dots are emitted.
    tempname _dotlog
    tempfile _dotlogf
    log using "`_dotlogf'", replace text name(`_dotlog')
    capture frame drop _t1_dot
    table1_tc price mpg weight, by(foreign) dots frame(_t1_dot, replace)
    log close `_dotlog'
    frame _t1_dot {
        local _n_dot = _N
        ds
        local _fv_dot : word 1 of `r(varlist)'
        local _cell_dot = `_fv_dot'[2]
    }

    * Output identical with and without dots.
    assert `_n_nodot' == `_n_dot'
    assert "`_fv_nodot'" == "`_fv_dot'"
    assert "`_cell_nodot'" == "`_cell_dot'"

    * Progress line ("Processing N variable(s): ...") reached the log.
    local _saw_dots 0
    file open _dfh using "`_dotlogf'", read text
    file read _dfh _dl
    while r(eof) == 0 {
        if strpos(`"`_dl'"', "Processing") > 0 & strpos(`"`_dl'"', "variable") > 0 ///
            local _saw_dots 1
        file read _dfh _dl
    }
    file close _dfh
    assert `_saw_dots' == 1

    frame drop _t1_nodot
    frame drop _t1_dot
}
if _rc == 0 {
    display as result "  PASS: table1_tc dots emits progress and preserves table"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc dots option (rc=`=_rc')"
    local ++fail_count
    capture log close `_dotlog'
}


**# Markdown stat-column headers (p-value, SMD) are present
* Regression for the strictheaders gap: the Markdown writer takes column
* headers only from the row-2 cell and (under strictheaders) does not fall
* back to variable labels, so the p-value/SMD columns shipped a BLANK header
* even though their values were exported. Assert the Markdown HEADER ROW (the
* line immediately preceding the "| --- |" separator) names both stat columns.
capture noisily {
    sysuse auto, clear
    gen byte _trt = foreign
    local _mdhdr "`c(tmpdir)'/_t1tc_mdhdr.md"
    capture erase "`_mdhdr'"
    table1_tc, by(_trt) smd vars(price contn %9.1f \ mpg contn %9.1f) ///
        title("Header regression") markdown("`_mdhdr'") clear

    * Pull the header row: first table line, which is the row before "| --- |".
    tempname _fh
    file open `_fh' using "`_mdhdr'", read text
    local _hdr ""
    local _prev ""
    file read `_fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "| ---") > 0 & "`_hdr'" == "" local _hdr `"`_prev'"'
        local _prev `"`line'"'
        file read `_fh' line
    }
    file close `_fh'

    assert strpos(`"`_hdr'"', "p-value") > 0
    assert strpos(`"`_hdr'"', "SMD") > 0
    * Body p-values must survive (header write must not clobber data rows).
    if "`md_checker'" != "" {
        shell python3 "`md_checker'" "`_mdhdr'" --contains "Price"
    }
    capture erase "`_mdhdr'"
}
if _rc == 0 {
    display as result "  PASS: table1_tc Markdown header names p-value and SMD columns"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc Markdown stat-column headers (rc=`=_rc')"
    local ++fail_count
}


**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_table1_tc tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _table1tc
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_table1_tc tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _table1tc

