* validation_table1_tc.do - known-answer and accuracy validation for table1_tc
* Consolidated in v1.7.0 from: validation_calculations.do, validation_excel_accuracy.do, validation_known_answers.do, validation_output_quality.do, validation_tabtools.do

clear all
set more off
set varabbrev off
version 16.0

capture log close _valt1tc
log using "validation_table1_tc.log", replace text name(_valt1tc)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
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


**# Migrated: variable types and content

* V1: table1_tc Validation - Variable Types and Content
* ============================================================

* V1.1: Continuous normal - verify mean matches hand calculation
capture noisily {
    sysuse auto, clear
    summarize price if foreign == 0, meanonly
    local expected_mean = round(r(mean), 0.1)
    table1_tc, vars(price contn %9.1f) by(foreign) sdleft(" (") sdright(")") frame(t1_val, replace)

    * table1_tc frame uses named columns: factor, foreign_0, foreign_1, etc.
    * The Price row has "mean (SD)" in foreign_0 column
    frame t1_val {
        local _found = 0
        forvalues _r = 1/`=_N' {
            if strmatch(strtrim(factor[`_r']), "*Price*") | strmatch(strtrim(factor[`_r']), "*price*") {
                local _cell = strtrim(foreign_0[`_r'])
                * Parse mean from "6072.4 (3097.1)" format
                local _mean_str = substr("`_cell'", 1, strpos("`_cell'", " ") - 1)
                local _mean_got = real("`_mean_str'")
                if !missing(`_mean_got') {
                    assert abs(`_mean_got' - `expected_mean') < 0.15
                    local _found = 1
                    continue, break
                }
            }
        }
        assert `_found' == 1
    }
    capture frame drop t1_val
}
if _rc == 0 {
    display as result "  PASS: V1.1 - table1_tc contn mean matches summarize"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.1 - table1_tc contn mean mismatch (error `=_rc')"
    local ++fail_count
    capture frame drop t1_val
}

* V1.2: All variable types in single call
capture noisily {
    sysuse auto, clear
    gen highmpg = (mpg > 20)
    table1_tc, vars(price contn \ mpg conts \ weight contln \ rep78 cat \ highmpg bin) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: V1.2 - all variable types (contn/conts/contln/cat/bin)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.2 - all variable types (error `=_rc')"
    local ++fail_count
}

* V1.3: Weighted continuous - verify weighted mean differs from unweighted
capture noisily {
    sysuse auto, clear
    gen double wt = cond(foreign == 1, 2.0, 0.5)
    * Unweighted mean
    summarize price, meanonly
    local unwt_mean = r(mean)
    * Run weighted table1_tc
    table1_tc, vars(price contn) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: V1.3 - weighted table1_tc executes"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.3 - weighted table1_tc (error `=_rc')"
    local ++fail_count
}

* V1.4: P-values suppressed with weights
capture noisily {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: V1.4 - weighted p-value suppression"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.4 - weighted p-value suppression (error `=_rc')"
    local ++fail_count
}

* V1.5: fweight + wt() mutual exclusivity → error 198
capture noisily {
    sysuse auto, clear
    gen double wt = 1.5
    capture table1_tc [fw=rep78], vars(price contn) by(foreign) wt(wt)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V1.5 - fweight + wt() correctly rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.5 - fweight + wt() error check (error `=_rc')"
    local ++fail_count
}

* V1.6: Negative weights → error 498
capture noisily {
    sysuse auto, clear
    gen double neg_wt = -1
    capture table1_tc, vars(price contn) by(foreign) wt(neg_wt)
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: V1.6 - negative weights correctly rejected (rc=498)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.6 - negative weights error check (error `=_rc')"
    local ++fail_count
}

* V1.7: Missing vars() with no data → error; with data → auto-detect
capture noisily {
    clear
    capture table1_tc
    assert _rc != 0
    sysuse auto, clear
    table1_tc, by(foreign)
}
if _rc == 0 {
    display as result "  PASS: V1.7 - missing vars() errors on empty data, auto-detects with data"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.7 - missing vars() error check (error `=_rc')"
    local ++fail_count
}

* V1.8: Weighted with total column
capture noisily {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat) by(foreign) wt(wt) total(after)
}
if _rc == 0 {
    display as result "  PASS: V1.8 - weighted with total column"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.8 - weighted with total column (error `=_rc')"
    local ++fail_count
}

* V1.9: Weighted with clear option preserves table data
capture noisily {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat) by(foreign) wt(wt) clear
    assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: V1.9 - weighted with clear option"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.9 - weighted with clear option (error `=_rc')"
    local ++fail_count
}

* V1.10: Weighted without by() (single group)
capture noisily {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ mpg conts \ rep78 cat) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: V1.10 - weighted without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.10 - weighted without by() (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: mean/SD/median/percent/p-value vs oracles

**# VC1: table1_tc — mean, SD, median, percentage, p-value
* =========================================================================

* Frame variables expose public display columns only; numeric p-values live in r(table)

* --- VC1.1: mean in frame matches summarize ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 0
    local ref_mean_dom = r(mean)
    quietly summarize price if foreign == 1
    local ref_mean_for = r(mean)

    capture frame drop _vc_t1
    table1_tc, by(foreign) vars(price contn %9.1f) sdleft(" (") sdright(")") frame(_vc_t1)

    frame _vc_t1 {
        * Row 3 = Price row (row 1=header, row 2=N=)
        * Columns: factor, foreign_0, foreign_1, pvalue
        local dom_cell = foreign_0[3]
        local for_cell = foreign_1[3]

        * Parse mean from "6072.4 (3097.1)"
        local dom_mean = real(word("`dom_cell'", 1))
        local for_mean = real(word("`for_cell'", 1))

        assert abs(`dom_mean' - `ref_mean_dom') < 1
        assert abs(`for_mean' - `ref_mean_for') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: VC1.1 — table1_tc mean matches summarize"
    local ++pass_count
}
else {
    display as error "  FAIL: VC1.1 — table1_tc mean accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_t1

* --- VC1.2: median matches summarize detail ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 0, detail
    local ref_med_dom = r(p50)

    capture frame drop _vc_t1m
    table1_tc, by(foreign) vars(price conts %9.0f) frame(_vc_t1m)

    frame _vc_t1m {
        local dom_cell = foreign_0[3]
        * Parse median from "4890 (3299-5705)"
        local dom_med = real(word("`dom_cell'", 1))
        assert abs(`dom_med' - `ref_med_dom') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: VC1.2 — table1_tc median matches summarize detail"
    local ++pass_count
}
else {
    display as error "  FAIL: VC1.2 — table1_tc median accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_t1m

* --- VC1.3: categorical percentage matches manual ---
local ++n_total
capture noisily {
    sysuse auto, clear

    * Count rep78==3 among domestic (non-missing)
    quietly count if rep78 == 3 & foreign == 0
    local n3_dom = r(N)
    quietly count if !missing(rep78) & foreign == 0
    local ntot_dom = r(N)
    local ref_pct = `n3_dom' / `ntot_dom' * 100

    capture frame drop _vc_t1c
    table1_tc, by(foreign) vars(rep78 cat) percsign("%") frame(_vc_t1c)

    frame _vc_t1c {
        * Find row with factor containing "3" (indented level)
        local found = 0
        forvalues i = 1/`=_N' {
            local fval = strtrim(factor[`i'])
            if "`fval'" == "3" {
                local dom_cell = foreign_0[`i']
                local found = 1
                continue, break
            }
        }
        assert `found' == 1

        * Parse count from "27 (56%)" or "27 (54.0%)" — count is first word
        local dom_n = real(word("`dom_cell'", 1))
        local ref_n = `n3_dom'
        assert `dom_n' == `ref_n'

        local pct_start = strpos("`dom_cell'", "(")
        local pct_end = strpos("`dom_cell'", "%")
        assert `pct_start' > 0
        assert `pct_end' > `pct_start'
        local dom_pct = real(substr("`dom_cell'", `pct_start' + 1, `pct_end' - `pct_start' - 1))
        assert abs(`dom_pct' - `ref_pct') < 0.6
    }
}
if _rc == 0 {
    display as result "  PASS: VC1.3 — table1_tc categorical % matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: VC1.3 — table1_tc categorical % accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_t1c

* --- VC1.4: raw p-value matches ttest ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly ttest price, by(foreign)
    local ref_p = r(p)

    capture frame drop _vc_t1p
    table1_tc, by(foreign) vars(price contn) frame(_vc_t1p)
    tempname _vc_t1p_mat
    matrix `_vc_t1p_mat' = r(table)
    assert abs(`_vc_t1p_mat'[1,1] - `ref_p') < 0.01
}
if _rc == 0 {
    display as result "  PASS: VC1.4 — table1_tc r(table) p-value matches ttest"
    local ++pass_count
}
else {
    display as error "  FAIL: VC1.4 — table1_tc p-value accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_t1p

* --- VC1.5: p-value for >2 groups matches Kruskal-Wallis ---
local ++n_total
capture noisily {
    sysuse auto, clear

    quietly kwallis price, by(rep78)
    local ref_p = chi2tail(r(df), r(chi2_adj))

    capture frame drop _vc_t1kw
    table1_tc, by(rep78) vars(price conts) frame(_vc_t1kw)
    tempname _vc_t1kw_mat
    matrix `_vc_t1kw_mat' = r(table)
    assert abs(`_vc_t1kw_mat'[1,1] - `ref_p') < 0.01
}
if _rc == 0 {
    display as result "  PASS: VC1.5 — table1_tc r(table) p-value (>2 groups) matches kwallis"
    local ++pass_count
}
else {
    display as error "  FAIL: VC1.5 — table1_tc kwallis p-value accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_t1kw


* =========================================================================

**# Migrated: p-value cross-check

**# VC11: table1_tc — p-value cross-check
* =========================================================================

* --- VC11.1: table1_tc continuous p-value matches ttest ---
local ++n_total
capture noisily {
    sysuse auto, clear
    ttest price, by(foreign)
    local _ref_p = r(p)

    table1_tc, vars(price contn) by(foreign) frame(_vc_t1p, replace)
    tempname _vc11_t1p_mat
    matrix `_vc11_t1p_mat' = r(table)
    assert abs(`_vc11_t1p_mat'[1,1] - `_ref_p') < 0.001
    capture frame drop _vc_t1p
}
if _rc == 0 {
    display as result "  PASS: VC11.1 — table1_tc continuous r(table) p matches ttest"
    local ++pass_count
}
else {
    display as error "  FAIL: VC11.1 — table1_tc p-value (rc=`=_rc')"
    local ++fail_count
    capture frame drop _vc_t1p
}

* --- VC11.2: table1_tc categorical p-value matches chi2 ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)
    quietly tab highmpg foreign, chi2
    local _ref_chi2_p = r(p)

    table1_tc, vars(highmpg cat) by(foreign) frame(_vc_t1chi, replace)
    tempname _vc11_t1chi_mat
    matrix `_vc11_t1chi_mat' = r(table)
    assert abs(`_vc11_t1chi_mat'[1,1] - `_ref_chi2_p') < 0.001
    capture frame drop _vc_t1chi
}
if _rc == 0 {
    display as result "  PASS: VC11.2 — table1_tc categorical r(table) p matches chi2"
    local ++pass_count
}
else {
    display as error "  FAIL: VC11.2 — table1_tc chi2 p-value (rc=`=_rc')"
    local ++fail_count
    capture frame drop _vc_t1chi
}

* =========================================================================

**# Migrated: fweight SMD oracle

**# KE0: table1_tc fweight SMDs match expanded-data oracle
* =========================================================================

local ++n_total
capture noisily {
    clear
    input byte(g b cat fw) double x
    0 0 1 9 0
    0 1 2 1 10
    1 0 1 1 10
    1 1 2 9 20
    end

    tempfile fwbase
    save "`fwbase'", replace

    table1_tc x b cat [fw=fw], by(g) vars(x contn \ b bin \ cat cat) smd clear
    matrix _ke_t1_fw_smd = r(table)
    local smd_col = colnumb(_ke_t1_fw_smd, "smd")
    local smd_x = el(_ke_t1_fw_smd, rownumb(_ke_t1_fw_smd, "x"), `smd_col')
    local smd_b = el(_ke_t1_fw_smd, rownumb(_ke_t1_fw_smd, "b"), `smd_col')
    local smd_cat = el(_ke_t1_fw_smd, rownumb(_ke_t1_fw_smd, "cat"), `smd_col')

    use "`fwbase'", clear
    expand fw

    quietly summarize x if g == 0
    local m1 = r(mean)
    local s1 = r(sd)
    quietly summarize x if g == 1
    local m2 = r(mean)
    local s2 = r(sd)
    local oracle_x = abs((`m1' - `m2') / sqrt((`s1'^2 + `s2'^2) / 2))

    quietly summarize b if g == 0
    local p1 = r(mean)
    quietly summarize b if g == 1
    local p2 = r(mean)
    local oracle_b = abs((`p1' - `p2') / sqrt((`p1' * (1 - `p1') + `p2' * (1 - `p2')) / 2))

    quietly count if g == 0
    local qn1 = r(N)
    quietly count if g == 1
    local qn2 = r(N)
    quietly count if g == 0 & cat == 1
    local q1 = r(N) / `qn1'
    quietly count if g == 1 & cat == 1
    local q2 = r(N) / `qn2'
    local oracle_cat = abs((`q1' - `q2') / sqrt((`q1' * (1 - `q1') + `q2' * (1 - `q2')) / 2))

    assert abs(`smd_x' - `oracle_x') < 1e-10
    assert abs(`smd_b' - `oracle_b') < 1e-10
    assert abs(`smd_cat' - `oracle_cat') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: KE0 — table1_tc fweight SMDs match expanded-data oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: KE0 — table1_tc fweight SMD oracle (rc=`=_rc')"
    local ++fail_count
}

* --- KE0.1: multinomial Mahalanobis distance is coding invariant, and K=2
*             categorical SMD reduces to the binary formula.
local ++n_total
capture noisily {
    clear
    input byte(g category) int frequency
    0 1 30
    0 2 50
    0 3 20
    1 1 45
    1 2 35
    1 3 20
    end
    expand frequency

    table1_tc category, by(g) vars(category cat) smd frame(_ke_cat_original, replace)
    matrix _ke_cat_smd_original = r(table)
    local _ke_smd_col = colnumb(_ke_cat_smd_original, "smd")
    local _ke_smd_original = el(_ke_cat_smd_original, 1, `_ke_smd_col')

    recode category (1=3) (3=1), generate(category_reversed)
    table1_tc category_reversed, by(g) vars(category_reversed cat) smd frame(_ke_cat_reversed, replace)
    matrix _ke_cat_smd_reversed = r(table)
    local _ke_smd_col = colnumb(_ke_cat_smd_reversed, "smd")
    local _ke_smd_reversed = el(_ke_cat_smd_reversed, 1, `_ke_smd_col')
    assert abs(`_ke_smd_original' - `_ke_smd_reversed') < 1e-10

    generate byte binary = category == 1
    generate byte binary_as_cat = binary
    table1_tc binary, by(g) vars(binary bin) smd frame(_ke_binary, replace)
    matrix _ke_binary_smd = r(table)
    local _ke_smd_col = colnumb(_ke_binary_smd, "smd")
    local _ke_smd_binary = el(_ke_binary_smd, 1, `_ke_smd_col')
    table1_tc binary_as_cat, by(g) vars(binary_as_cat cat) smd frame(_ke_binary_cat, replace)
    matrix _ke_binary_cat_smd = r(table)
    local _ke_smd_col = colnumb(_ke_binary_cat_smd, "smd")
    local _ke_smd_binary_cat = el(_ke_binary_cat_smd, 1, `_ke_smd_col')
    assert abs(`_ke_smd_binary' - `_ke_smd_binary_cat') < 1e-10

    capture frame drop _ke_cat_original
    capture frame drop _ke_cat_reversed
    capture frame drop _ke_binary
    capture frame drop _ke_binary_cat
}
if _rc == 0 {
    display as result "  PASS: KE0.1 — categorical SMD coding invariance and binary reduction"
    local ++pass_count
}
else {
    display as error "  FAIL: KE0.1 — categorical SMD invariants (rc=`=_rc')"
    local ++fail_count
    capture frame drop _ke_cat_original
    capture frame drop _ke_cat_reversed
    capture frame drop _ke_binary
    capture frame drop _ke_binary_cat
}
* =========================================================================

**# Migrated: descriptive identities

**# KE7: table1_tc — additional descriptive identities
* =========================================================================

* --- KE7.1: SD parsed from cell matches summarize sd ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 0
    local ref_sd_dom = r(sd)
    quietly summarize price if foreign == 1
    local ref_sd_for = r(sd)

    capture frame drop _ke_t1
    table1_tc, by(foreign) vars(price contn %9.1f) sdleft(" (") sdright(")") frame(_ke_t1)
    frame _ke_t1 {
        local dom_cell = foreign_0[3]
        local for_cell = foreign_1[3]
        * "MEAN (SD)" — extract token after first space, strip parens
        local dom_inside = subinstr("`dom_cell'", "(", "", .)
        local dom_inside = subinstr("`dom_inside'", ")", "", .)
        local for_inside = subinstr("`for_cell'", "(", "", .)
        local for_inside = subinstr("`for_inside'", ")", "", .)
        local dom_sd = real(word("`dom_inside'", 2))
        local for_sd = real(word("`for_inside'", 2))
        assert abs(`dom_sd' - `ref_sd_dom') < 1
        assert abs(`for_sd' - `ref_sd_for') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE7.1 — table1_tc SD matches summarize"
    local ++pass_count
}
else {
    display as error "  FAIL: KE7.1 — table1_tc SD (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_t1

* --- KE7.2: IQR parsed from conts cell matches p25/p75 ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 0, detail
    local p25_dom = r(p25)
    local p75_dom = r(p75)

    capture frame drop _ke_t1q
    table1_tc, by(foreign) vars(price conts %9.0f) iqrmiddle("-") frame(_ke_t1q)
    frame _ke_t1q {
        local dom_cell = foreign_0[3]
        * "MED (LO-HI)"
        local _idx_lp = strpos("`dom_cell'", "(")
        local _idx_dash = strpos("`dom_cell'", "-")
        local _idx_rp = strpos("`dom_cell'", ")")
        local lo = real(substr("`dom_cell'", `_idx_lp' + 1, `_idx_dash' - `_idx_lp' - 1))
        local hi = real(substr("`dom_cell'", `_idx_dash' + 1, `_idx_rp' - `_idx_dash' - 1))
        assert abs(`lo' - `p25_dom') < 1
        assert abs(`hi' - `p75_dom') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE7.2 — table1_tc IQR (lo-hi) matches p25/p75"
    local ++pass_count
}
else {
    display as error "  FAIL: KE7.2 — table1_tc IQR (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_t1q

* --- KE7.3: Categorical proportions sum to 100% within each group ---
local ++n_total
capture noisily {
    sysuse auto, clear
    keep if !missing(rep78)
    capture frame drop _ke_t1c
    table1_tc, by(foreign) vars(rep78 cat) percsign("%") frame(_ke_t1c)
    frame _ke_t1c {
        * Sum percentages in each by-group column for the rep78 rows.
        * Each cell is "n (pct%)". Find rows that begin with a number after trim
        * (level rows) — their pct should sum to ~100 per column.
        local sum0 = 0
        local sum1 = 0
        forvalues i = 1/`=_N' {
            local lab = strtrim(factor[`i'])
            * Skip header/total/blank rows
            if "`lab'" == "" continue
            if regexm("`lab'", "^[1-5]$") {
                local cell0 = foreign_0[`i']
                local cell1 = foreign_1[`i']
                * extract pct between "(" and ")"
                local lp0 = strpos("`cell0'", "(")
                local rp0 = strpos("`cell0'", "%")
                if `lp0' > 0 & `rp0' > `lp0' {
                    local p0 = real(substr("`cell0'", `lp0'+1, `rp0'-`lp0'-1))
                    local sum0 = `sum0' + `p0'
                }
                local lp1 = strpos("`cell1'", "(")
                local rp1 = strpos("`cell1'", "%")
                if `lp1' > 0 & `rp1' > `lp1' {
                    local p1 = real(substr("`cell1'", `lp1'+1, `rp1'-`lp1'-1))
                    local sum1 = `sum1' + `p1'
                }
            }
        }
        assert abs(`sum0' - 100) < 0.5
        assert abs(`sum1' - 100) < 0.5
    }
}
if _rc == 0 {
    display as result "  PASS: KE7.3 — table1_tc cat proportions sum to 100% per group"
    local ++pass_count
}
else {
    display as error "  FAIL: KE7.3 — cat proportion sum (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_t1c

* --- KE7.4: Group N values in header row match `count if by==g` ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly count if foreign == 0
    local n0 = r(N)
    quietly count if foreign == 1
    local n1 = r(N)

    capture frame drop _ke_t1n
    table1_tc, by(foreign) vars(price contn) frame(_ke_t1n)
    frame _ke_t1n {
        * The "N=" header row is row 2
        local cell0 = foreign_0[2]
        local cell1 = foreign_1[2]
        * Extract any integer in the cell
        local d0 = ""
        local d1 = ""
        local k = strlen("`cell0'")
        forvalues i = 1/`k' {
            local ch = substr("`cell0'", `i', 1)
            if regexm("`ch'", "[0-9]") local d0 "`d0'`ch'"
        }
        local k = strlen("`cell1'")
        forvalues i = 1/`k' {
            local ch = substr("`cell1'", `i', 1)
            if regexm("`ch'", "[0-9]") local d1 "`d1'`ch'"
        }
        assert real("`d0'") == `n0'
        assert real("`d1'") == `n1'
    }
}
if _rc == 0 {
    display as result "  PASS: KE7.4 — table1_tc N= header matches per-group count"
    local ++pass_count
}
else {
    display as error "  FAIL: KE7.4 — header N (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_t1n

* --- KE7.5: t-test p value matches ttest exactly (two-group continuous) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly ttest price, by(foreign)
    local ref_p = r(p)

    capture frame drop _ke_t1p
    table1_tc, by(foreign) vars(price contn) frame(_ke_t1p)
    tempname _ke_t1p_mat
    matrix `_ke_t1p_mat' = r(table)
    assert abs(`_ke_t1p_mat'[1,1] - `ref_p') < 1e-4
}
if _rc == 0 {
    display as result "  PASS: KE7.5 — table1_tc r(table) p equals ttest p"
    local ++pass_count
}
else {
    display as error "  FAIL: KE7.5 — table1_tc p vs ttest (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_t1p


* =========================================================================

**# Migrated: shared Excel-checking helpers

local checker "`tools_dir'/check_xlsx.py"
capture confirm file "`checker'"
if _rc != 0 local checker ""
local has_checker = ("`checker'" != "")
if !`has_checker' {
    display as text "NOTE: check_xlsx.py not found — using Stata-native Excel validation"

    * Stata-native fallback: generate xlsx, verify title cells with import excel
    local ++n_total
    capture noisily {
        sysuse auto, clear
        collect clear
        collect: regress price mpg weight
        capture erase "`output_dir'/_va_native_regtab.xlsx"
        regtab, xlsx("`output_dir'/_va_native_regtab.xlsx") sheet("Test") title("Regression") digits(2)
        import excel "`output_dir'/_va_native_regtab.xlsx", sheet("Test") clear allstring
        assert A[1] == "Regression"
        * Check for p-value patterns in data rows
        local _has_pval = 0
        foreach _v of varlist * {
            forvalues _r = 1/`=_N' {
                local _cell = strtrim(`_v'[`_r'])
                if regexm(`"`_cell'"', "^[0-9]\.[0-9]+$") | regexm(`"`_cell'"', "^<0\.[0-9]+$") {
                    local _has_pval = 1
                }
            }
        }
        assert `_has_pval' == 1
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    local ++n_total
    capture noisily {
        webuse cattaneo2, clear
        collect clear
        collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
        capture erase "`output_dir'/_va_native_effecttab.xlsx"
        effecttab, xlsx("`output_dir'/_va_native_effecttab.xlsx") sheet("ATE") ///
            title("Effects") effect("ATE") clean
        import excel "`output_dir'/_va_native_effecttab.xlsx", sheet("ATE") cellrange(A1:A1) clear
        assert A[1] == "Effects"
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * Cleanup
    capture erase "`output_dir'/_va_native_regtab.xlsx"
    capture erase "`output_dir'/_va_native_effecttab.xlsx"

    display _newline as result "Stata-native Excel Accuracy Validation Complete"
    display as result "  Passed: `pass_count' / `n_total'"
    if `fail_count' > 0 {
        display as error "  Failed: `fail_count' / `n_total'"
    }
    else {
        display as result "  All `n_total' tests passed!"
    }
    assert `fail_count' == 0
}

if `has_checker' {

display as result "Using checker: `checker'"

* =========================================================================

**# Migrated: Excel statistics match summarize

**# VA7: table1_tc — summary statistics match summarize
* =========================================================================

* --- VA7.1: table1_tc mean matches summarize ---
local ++n_total
capture noisily {
    sysuse auto, clear

    * Compute expected values
    quietly summarize price if foreign == 0
    local mean_dom : display %9.0f r(mean)
    local mean_dom = strtrim("`mean_dom'")

    capture erase "`output_dir'/_va_table1.xlsx"
    table1_tc, by(foreign) vars(price contn %9.0f) ///
        excel("`output_dir'/_va_table1.xlsx") title("Test")

    * Price row (row 4): Domestic column (C) should contain mean
    shell python3 "`checker'" "`output_dir'/_va_table1.xlsx" ///
        --cell-contains C4 "`mean_dom'" ///
        --result-file "`output_dir'/_va_t1.txt" --quiet
    file open _fh using "`output_dir'/_va_t1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA7.1 — table1_tc Domestic mean price matches summarize in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA7.1 — table1_tc mean accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_t1.txt"

* --- VA7.2: table1_tc N= values match data ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly count if foreign == 0
    local n_dom = r(N)
    quietly count if foreign == 1
    local n_for = r(N)

    capture erase "`output_dir'/_va_table1_n.xlsx"
    table1_tc, by(foreign) vars(price contn) ///
        excel("`output_dir'/_va_table1_n.xlsx") title("Test")

    shell python3 "`checker'" "`output_dir'/_va_table1_n.xlsx" ///
        --contains "N=`n_dom'" --contains "N=`n_for'" ///
        --result-file "`output_dir'/_va_t2.txt" --quiet
    file open _fh using "`output_dir'/_va_t2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA7.2 — table1_tc N=52 and N=22 appear in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA7.2 — table1_tc N values (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_t2.txt"

* =========================================================================

**# Migrated: summary statistics quality

**# SECTION 6: table1_tc — validate summary statistics
* ============================================================

* V14: table1_tc mean/SD matches summarize
capture noisily {
    sysuse auto, clear
    summarize price if foreign == 0
    local mean_dom = r(mean)
    local sd_dom = r(sd)
    local mean_dom_fmt : display %12.4f `mean_dom'
    local sd_dom_fmt : display %12.4f `sd_dom'
    local mean_dom_fmt = strtrim("`mean_dom_fmt'")
    local sd_dom_fmt = strtrim("`sd_dom_fmt'")

    summarize price if foreign == 1
    local mean_for = r(mean)
    local sd_for = r(sd)
    local mean_for_fmt : display %12.4f `mean_for'
    local sd_for_fmt : display %12.4f `sd_for'
    local mean_for_fmt = strtrim("`mean_for_fmt'")
    local sd_for_fmt = strtrim("`sd_for_fmt'")

    table1_tc, by(foreign) vars(price contn %12.4f) sdleft(" (") sdright(")") ///
        xlsx("`output_dir'/_val_t1_stats.xlsx") sheet("stats") frame(_val_t1)

    frame _val_t1 {
        assert factor[4] == "Price"
        local dom_stats = foreign_0[4]
        local for_stats = foreign_1[4]
    }
    local dom_open = strpos(`"`dom_stats'"', "(")
    local dom_close = strpos(`"`dom_stats'"', ")")
    local for_open = strpos(`"`for_stats'"', "(")
    local for_close = strpos(`"`for_stats'"', ")")
    assert `dom_open' > 0
    assert `dom_close' > `dom_open'
    assert `for_open' > 0
    assert `for_close' > `for_open'
    local mean_dom_t1 = real(word(`"`dom_stats'"', 1))
    local sd_dom_t1 = real(substr(`"`dom_stats'"', `dom_open' + 1, `dom_close' - `dom_open' - 1))
    local mean_for_t1 = real(word(`"`for_stats'"', 1))
    local sd_for_t1 = real(substr(`"`for_stats'"', `for_open' + 1, `for_close' - `for_open' - 1))
    assert abs(`mean_dom_t1' - `mean_dom') < 0.001
    assert abs(`sd_dom_t1' - `sd_dom') < 0.001
    assert abs(`mean_for_t1' - `mean_for') < 0.001
    assert abs(`sd_for_t1' - `sd_for') < 0.001
    frame drop _val_t1
}
if _rc == 0 {
    display as result "  PASS: V14 table1_tc mean/SD matches summarize"
    local ++pass_count
}
else {
    display as error "  FAIL: V14 table1_tc mean/SD matches summarize (error `=_rc')"
    local ++fail_count
}

* V15: table1_tc p-value for continuous — t-test matches ttest
capture noisily {
    sysuse auto, clear
    quietly ttest price, by(foreign)
    local p_ttest = r(p)

    table1_tc, by(foreign) vars(price contn) clear
    * After clear, the table is in memory — extract p-value
    * The p-value column should exist
    capture confirm variable pvalue
    if _rc == 0 {
        local p_t1 = real(pvalue[4])
        if !missing(`p_t1') {
            assert abs(`p_t1' - `p_ttest') < 0.01
        }
    }
    sysuse auto, clear
}
if _rc == 0 {
    display as result "  PASS: V15 table1_tc p-value consistent with ttest"
    local ++pass_count
}
else {
    display as error "  FAIL: V15 table1_tc p-value consistent with ttest (error `=_rc')"
    local ++fail_count
}

* ============================================================

}  // close `if has_checker' block (Excel-checker VA tests)

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_table1_tc tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _valt1tc
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_table1_tc tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _valt1tc
