* test_package_adversarial.do - adversarial breakage, stress, and export-failure return contracts across commands
* Consolidated in v1.7.0 from: test_adversarial_breakage.do, test_export_failure_returns.do, test_stress.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _pkgadv
capture erase "test_package_adversarial.log"
log using "test_package_adversarial.log", text name(_pkgadv)

local test_count = 0
local pass_count = 0
local fail_count = 0

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


**# Migrated: adversarial breakage sweep



**# Install Surface and Helper Auto-Load
capture noisily {
    foreach cmd in tabtools table1_tc regtab effecttab stratetab hrcomptab ///
        comptab survtab crosstab diagtab corrtab {
        which `cmd'
    }

    clear
    input byte row byte col
    0 0
    0 1
    1 0
    1 1
    end
 crosstab row col
    assert r(N) == 4
}
if _rc == 0 {
    display as result "  PASS: install surface and helper auto-load"
    local ++pass_count
}
else {
    display as error "  FAIL: install surface and helper auto-load (rc=`=_rc')"
    local ++fail_count
}

**# tabtools Controller
capture noisily {
    tabtools set clear

    tabtools
    assert r(n_commands) == 16
    assert "`r(commands)'" == ///
        "table1_tc desctab crosstab corrtab regtab effecttab stratetab survtab diagtab comptab hrcomptab puttab stacktab simtab tabtools tabtools_tips"

    set varabbrev on
    capture tabtools nonsense
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture tabtools, category(garbage)
    assert _rc == 198
    assert c(varabbrev) == "on"

    tabtools set theme lancet
    tabtools set font Calibri
    assert "$TABTOOLS_THEME" == "custom"
    assert "$TABTOOLS_FONT" == "Calibri"

    capture tabtools set theme custom, fontsize(5)
    assert _rc == 198

    tabtools set clear
    assert "$TABTOOLS_THEME" == ""
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: tabtools rejects bad controller/default inputs cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools adversarial controller/default inputs (rc=`=_rc')"
    local ++fail_count
}

**# table1_tc
capture noisily {
    clear
    set obs 6
    gen double x = _n
    gen byte group = mod(_n, 2)
    gen double wt = 1
    replace wt = -5 in 6
    gen byte keepme = (_n < 6)
    gen int fw = 1
    tempfile table1_before
    save "`table1_before'", replace

    set varabbrev on
    capture table1_tc
    assert _rc == 0
    assert strpos(" `r(varlist)' ", " x ") > 0
    assert c(varabbrev) == "on"

    preserve
    clear
    capture table1_tc
    local no_data_rc = _rc
    restore
    assert `no_data_rc' == 100
    assert c(varabbrev) == "on"

    capture table1_tc x, by(group) vars(x nonsense)
    assert _rc == 498
    assert c(varabbrev) == "on"

    capture table1_tc x, by(group) vars(x contn) wt(wt)
    assert _rc == 498
    assert c(varabbrev) == "on"

    table1_tc x if keepme, by(group) vars(x contn) wt(wt)
    cf _all using "`table1_before'"

    capture table1_tc x [fweight=fw], by(group) vars(x contn) wt(wt)
    assert _rc == 198

    gen byte N = group
    capture table1_tc x, by(N) vars(x contn)
    assert _rc == 498

    gen byte bin12 = cond(_n <= 3, 1, 2)
    capture table1_tc, vars(bin12 bin)
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: table1_tc adversarial inputs and preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc adversarial inputs and preservation (rc=`=_rc')"
    local ++fail_count
}

**# crosstab
capture noisily {
    clear
    input str1 row_s byte col
    "a" 0
    "b" 1
    "a" 0
    "b" 1
    end

    set varabbrev on
    capture crosstab row_s col
    assert _rc == 109
    assert c(varabbrev) == "on"

    clear
    input byte row byte col int freq
    0 0 10
    0 1 20
    1 0 30
    1 1 40
    end
    expand freq

    capture crosstab row col, rowpct colpct
    assert _rc == 198
    assert c(varabbrev) == "on"

    gen byte row3 = cond(_n <= 30, 0, cond(_n <= 70, 1, 2))
    capture crosstab row3 col, or
    assert _rc == 198

    capture crosstab row col if 0
    assert _rc == 2000

    capture crosstab row col, open
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: crosstab adversarial inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab adversarial inputs (rc=`=_rc')"
    local ++fail_count
}

**# corrtab
capture noisily {
    clear
    input double x y z
    1 1 1
    2 2 .
    3 3 .
    4 4 4
    5 . 5
    . 6 6
    end

    set varabbrev on
    capture corrtab x y z, lower upper
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture corrtab x y z, pvalues star(0.05)
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture corrtab x y z, star(0 0.05)
    assert _rc == 198

    capture corrtab x y z if 0
    assert _rc == 2000

    capture frame drop corr_adv
    corrtab x y z, full frame(corr_adv, replace)
    matrix N = r(N)
    assert N[1,1] == 5
    assert N[1,2] == 4
    assert N[1,3] == 3
    assert N[2,3] == 3
    assert N[3,3] == 4
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: corrtab conflicts and pairwise-missing N matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab conflicts and pairwise-missing N matrix (rc=`=_rc')"
    local ++fail_count
}
capture frame drop corr_adv

**# diagtab
capture noisily {
    clear
    input double score byte test byte gold
    0.10 0 0
    0.20 0 0
    0.80 1 1
    0.90 1 1
    0.40 1 0
    0.60 0 1
    end

    set varabbrev on
    capture diagtab score gold
    assert _rc == 198
    assert c(varabbrev) == "on"

    replace gold = 2 in 1
    capture diagtab test gold
    assert _rc == 198
    assert c(varabbrev) == "on"
    replace gold = 0 in 1

    capture diagtab test gold, prevalence(0)
    assert _rc == 198

    capture diagtab test gold, prevalence(1)
    assert _rc == 198

    capture diagtab score gold, cutoff(0.5) cutoffs(0.2 0.5)
    assert _rc == 198

    capture diagtab score gold, cutoffs(0.2 0.5) auc
    assert _rc == 198

    capture diagtab score gold, cutoffs(0.2 0.5) optimal
    assert _rc == 198

    capture diagtab test gold if 0
    assert _rc == 2000
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: diagtab adversarial inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab adversarial inputs (rc=`=_rc')"
    local ++fail_count
}

**# regtab
capture noisily {
    collect clear
    set varabbrev on
    capture regtab
    * Missing active collection uses Stata's standard r(119) contract.
    assert _rc == 119
    assert c(varabbrev) == "on"

    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local e_cmd "`e(cmd)'"
    local e_N = e(N)

    capture regtab, digits(7)
    assert _rc == 198
    assert c(varabbrev) == "on"
    assert "`e(cmd)'" == "`e_cmd'"
    assert e(N) == `e_N'

    capture regtab, keep(mpg) drop(weight)
    assert _rc == 198
    assert "`e(cmd)'" == "`e_cmd'"
    assert e(N) == `e_N'

    capture regtab, open
    assert _rc == 198

    capture regtab, xlsx("bad.txt")
    assert _rc == 198

    capture regtab, starslevels(0.05 0.01)
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: regtab rejects invalid state/options without clearing e()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab invalid state/options or e() preservation (rc=`=_rc')"
    local ++fail_count
}
collect clear

**# effecttab
capture noisily {
    collect clear
    set varabbrev on
    capture effecttab
    * Missing active collection uses Stata's standard r(119) contract.
    assert _rc == 119
    assert c(varabbrev) == "on"

    matrix bad_eff = J(1, 3, .)
    capture effecttab, from(bad_eff)
    assert _rc == 198
    assert c(varabbrev) == "on"

    matrix adv_eff = (1, 0.5, 1.5, 0.04 \ -0.5, -1, 0, 0.051)
    matrix rownames adv_eff = exposure dose
    capture frame drop adv_eff1
 effecttab, from(adv_eff) frame(adv_eff1, replace)
    assert "`r(frame)'" == "adv_eff1"
    assert r(N_rows) == 5

    capture effecttab, from(adv_eff) type(garbage)
    assert _rc == 198

    capture effecttab, from(adv_eff) open
    assert _rc == 198

    capture effecttab, from(adv_eff) boldp(1)
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: effecttab adversarial from()/option inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab adversarial from()/option inputs (rc=`=_rc')"
    local ++fail_count
}

**# stratetab
capture noisily {
    clear
    input byte id double x
    1 10
    2 20
    3 30
    end
    tempfile strat_user_before
    save "`strat_user_before'", replace

    set varabbrev on
    capture stratetab, using(one two three) outcomes(2)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`strat_user_before'"

    capture stratetab, using("bad;name") outcomes(1)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`strat_user_before'"

    capture stratetab, using(one) outcomes(0)
    assert _rc == 198
    cf _all using "`strat_user_before'"

    capture stratetab, using(one) outcomes(1) xlsx("bad.txt")
    assert _rc == 198
    cf _all using "`strat_user_before'"

    local badbase "`c(tmpdir)'/tabtools_adv_bad_`c(pid)'"
    preserve
        clear
        input byte bogus
        1
        end
        save "`badbase'.dta", replace
    restore

    capture stratetab, using("`badbase'") outcomes(1)
    assert _rc == 111
    assert c(varabbrev) == "on"
    cf _all using "`strat_user_before'"
    capture erase "`badbase'.dta"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: stratetab rejects malformed file contracts and restores data"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab malformed file contracts or data restore (rc=`=_rc')"
    local ++fail_count
}

**# survtab
capture noisily {
    clear
    set obs 6
    gen double t = _n
    gen byte fail = (_n <= 3)
    gen byte group = 1

    set varabbrev on
    capture survtab, times(1)
    assert _rc == 119
    assert c(varabbrev) == "on"

    stset t, failure(fail)

    capture survtab, times(1) difference
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture survtab, times(1) by(group)
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture survtab, times(1) timeunit(fortnights)
    assert _rc == 198

    capture survtab, times(1) rmst(0)
    assert _rc == 198

    capture survtab, times(1) digits(7)
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: survtab adversarial stset/group/options"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab adversarial stset/group/options (rc=`=_rc')"
    local ++fail_count
}

**# comptab
capture noisily {
    matrix comp_eff = (1, 0.5, 1.5, 0.04 \ 2, 1, 3, 0.20)
    matrix rownames comp_eff = exposure dose
    capture frame drop adv_eff1
    capture frame drop adv_eff2
    capture frame drop adv_comp
    effecttab, from(comp_eff) frame(adv_eff1, replace)
    effecttab, from(comp_eff) frame(adv_eff2, replace)

    set varabbrev on
    capture comptab adv_eff1 adv_eff2
    assert _rc == 198
    assert c(varabbrev) == "on"

    capture comptab adv_eff1 adv_eff2, rows(1 \ 1) rownames(exposure \ dose)
    assert _rc == 198
    assert c(varabbrev) == "on"

 capture comptab adv_eff1 adv_eff2, rows(1 99 \ 1)
    assert _rc == 198

 capture comptab adv_eff1 adv_eff2, rownames("__definitely_absent__ \ exposure")
    assert _rc == 198

    comptab adv_eff1 adv_eff2, rows(1 2 \ 1 2) frame(adv_comp, replace)
    assert r(N_frames) == 2
    assert r(N_models) == 1

    capture frame drop adv_bad_comp
    frame create adv_bad_comp
    frame adv_bad_comp {
        set obs 3
        gen str244 A = ""
        gen str244 c1 = ""
        replace A = "label" in 3
    }
 capture comptab adv_bad_comp, rows(1)
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: comptab adversarial frame/row contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab adversarial frame/row contracts (rc=`=_rc')"
    local ++fail_count
}
capture frame drop adv_comp
capture frame drop adv_bad_comp

**# hrcomptab
capture noisily {
    clear
    input byte id double x
    1 10
    2 20
    end
    tempfile hr_user_before
    save "`hr_user_before'", replace

    set varabbrev on
    capture hrcomptab missing_rates, modelframes(missing_model) rows(1)
    assert _rc == 111
    assert c(varabbrev) == "on"
    cf _all using "`hr_user_before'"

    capture frame drop adv_rate_bad
    frame create adv_rate_bad
    frame adv_rate_bad {
        set obs 3
        gen str244 c1 = ""
        gen str244 c2 = ""
        gen str244 c3 = ""
    }
    capture hrcomptab adv_rate_bad, modelframes(missing_model) rows(1)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`hr_user_before'"

    capture hrcomptab adv_rate_bad, modelframes(missing_model)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`hr_user_before'"

    capture hrcomptab adv_rate_bad, modelframes(missing_model) rows(1) rownames(foo)
    assert _rc == 198
    assert c(varabbrev) == "on"
    cf _all using "`hr_user_before'"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: hrcomptab adversarial scaffold/model contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab adversarial scaffold/model contracts (rc=`=_rc')"
    local ++fail_count
}
capture frame drop adv_rate_bad
capture frame drop adv_eff1
capture frame drop adv_eff2
**# Migrated: 3-perspective stress suite



* ============================================================
**# Nick Cox perspective: Minimalism and edge cases
* ============================================================

* S1: table1_tc with single observation per group
capture noisily {
    clear
    set obs 4
    gen group = mod(_n, 2)
    gen x = rnormal()
    gen y = runiform() > 0.5
    label variable x "Continuous var"
    label variable y "Binary var"
    table1_tc, by(group) vars(x contn \ y bin) ///
        xlsx("`output_dir'/_stress_t1_small.xlsx") sheet("small")
    confirm file "`output_dir'/_stress_t1_small.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S1 table1_tc single obs per group"
    local ++pass_count
}
else {
    display as error "  FAIL: S1 table1_tc single obs per group (error `=_rc')"
    local ++fail_count
}

* S2: table1_tc with all missing values in a variable
capture noisily {
    sysuse auto, clear
    gen x = .
    label variable x "All missing"
    table1_tc, by(foreign) vars(x contn \ price contn) ///
        xlsx("`output_dir'/_stress_t1_allmiss.xlsx") sheet("allmiss")
    confirm file "`output_dir'/_stress_t1_allmiss.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S2 table1_tc all missing variable"
    local ++pass_count
}
else {
    display as error "  FAIL: S2 table1_tc all missing variable (error `=_rc')"
    local ++fail_count
}

* S3: table1_tc without by() — overall descriptives only
capture noisily {
    sysuse auto, clear
    table1_tc, vars(price contn \ mpg contn \ rep78 cat) ///
        xlsx("`output_dir'/_stress_t1_noby.xlsx") sheet("noby")
    confirm file "`output_dir'/_stress_t1_noby.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S3 table1_tc without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 table1_tc without by() (error `=_rc')"
    local ++fail_count
}

* S4: corrtab with only 2 variables (minimum)
capture noisily {
    sysuse auto, clear
    corrtab price mpg, xlsx("`output_dir'/_stress_corr_min.xlsx") sheet("min")
    assert rowsof(r(C)) == 2
}
if _rc == 0 {
    display as result "  PASS: S4 corrtab minimum 2 variables"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 corrtab minimum 2 variables (error `=_rc')"
    local ++fail_count
}

* S5: corrtab with many variables (10+)
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight length displacement headroom trunk turn gear_ratio, ///
        xlsx("`output_dir'/_stress_corr_many.xlsx") sheet("many") lower
    assert rowsof(r(C)) == 9
}
if _rc == 0 {
    display as result "  PASS: S5 corrtab 9 variables"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 corrtab 9 variables (error `=_rc')"
    local ++fail_count
}

* S6: crosstab with single category in one variable
capture noisily {
    sysuse auto, clear
    gen byte always1 = 1
    label variable always1 "Constant"
    crosstab always1 foreign, ///
        xlsx("`output_dir'/_stress_cross_const.xlsx") sheet("const")
    confirm file "`output_dir'/_stress_cross_const.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S6 crosstab with constant variable"
    local ++pass_count
}
else {
    display as error "  FAIL: S6 crosstab with constant variable (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# StataCorp perspective: Conventions, robustness, data safety
* ============================================================

* S7: regtab preserves estimation results (e() not cleared)
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local n_before = e(N)
    local r2_before = e(r2)
    regtab, xlsx("`output_dir'/_stress_reg_epreserve.xlsx") sheet("e")
    * e() should still be available after regtab
    assert e(N) == `n_before'
    assert abs(e(r2) - `r2_before') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: S7 regtab preserves e() results"
    local ++pass_count
}
else {
    display as error "  FAIL: S7 regtab preserves e() results (error `=_rc')"
    local ++fail_count
}

* S8: regtab with factor variables
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price i.rep78 mpg weight
    regtab, xlsx("`output_dir'/_stress_reg_factor.xlsx") sheet("factor")
    confirm file "`output_dir'/_stress_reg_factor.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S8 regtab with factor variables"
    local ++pass_count
}
else {
    display as error "  FAIL: S8 regtab with factor variables (error `=_rc')"
    local ++fail_count
}

* S9: regtab with interaction terms
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price c.mpg##i.foreign weight
    regtab, xlsx("`output_dir'/_stress_reg_interact.xlsx") sheet("interact")
    confirm file "`output_dir'/_stress_reg_interact.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S9 regtab with interaction terms"
    local ++pass_count
}
else {
    display as error "  FAIL: S9 regtab with interaction terms (error `=_rc')"
    local ++fail_count
}

* S10: Multiple sheet names with spaces and special chars
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn) ///
        xlsx("`output_dir'/_stress_sheetname.xlsx") sheet("My Table (1)")
    confirm file "`output_dir'/_stress_sheetname.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S10 sheet name with spaces and parens"
    local ++pass_count
}
else {
    display as error "  FAIL: S10 sheet name with spaces and parens (error `=_rc')"
    local ++fail_count
}

* S11: Very long title and footnote strings
capture noisily {
    sysuse auto, clear
    local long_title "Table 1. Baseline Characteristics of Study Population: A Comprehensive Comparison Across Treatment Groups With Extended Title Text"
    local long_foot "Notes: Data from the 1978 Automobile Dataset. P-values calculated using independent samples t-test for continuous variables and chi-squared test for categorical variables. Statistical significance defined as p < 0.05."
    table1_tc, by(foreign) vars(price contn \ mpg contn) ///
        title("`long_title'") footnote("`long_foot'") ///
        xlsx("`output_dir'/_stress_long_text.xlsx") sheet("long")
    confirm file "`output_dir'/_stress_long_text.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S11 very long title and footnote"
    local ++pass_count
}
else {
    display as error "  FAIL: S11 very long title and footnote (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# Biostats/Epi perspective: Clinical data patterns
* ============================================================

* S12: table1_tc with 3+ groups (multi-arm trial)
capture noisily {
    sysuse auto, clear
    table1_tc, by(rep78) vars(price contn \ mpg contn \ weight contn) ///
        xlsx("`output_dir'/_stress_t1_multigroup.xlsx") sheet("multi")
    confirm file "`output_dir'/_stress_t1_multigroup.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S12 table1_tc with 5 groups (multi-arm)"
    local ++pass_count
}
else {
    display as error "  FAIL: S12 table1_tc with 5 groups (error `=_rc')"
    local ++fail_count
}

* S13: survtab with no events (everyone censored)
capture noisily {
    clear
    set obs 100
    gen time = runiform() * 365
    gen byte event = 0
    stset time, failure(event)
    survtab, times(100 200 300) ///
        xlsx("`output_dir'/_stress_surv_noevents.xlsx") sheet("noevents")
    confirm file "`output_dir'/_stress_surv_noevents.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S13 survtab with no events (all censored)"
    local ++pass_count
}
else {
    display as error "  FAIL: S13 survtab with no events (error `=_rc')"
    local ++fail_count
}

* S14: survtab with all events (everyone fails)
capture noisily {
    clear
    set obs 100
    gen time = runiform() * 365
    gen byte event = 1
    stset time, failure(event)
    survtab, times(100 200 300) ///
        xlsx("`output_dir'/_stress_surv_allevents.xlsx") sheet("allevents")
    confirm file "`output_dir'/_stress_surv_allevents.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S14 survtab with all events"
    local ++pass_count
}
else {
    display as error "  FAIL: S14 survtab with all events (error `=_rc')"
    local ++fail_count
}

* S15: diagtab with perfect prediction (Se=Sp=100%)
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = gold
    diagtab test gold, xlsx("`output_dir'/_stress_diag_perfect.xlsx") sheet("perfect")
    assert abs(r(sensitivity) - 1.0) < 0.001
    assert abs(r(specificity) - 1.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: S15 diagtab perfect prediction"
    local ++pass_count
}
else {
    display as error "  FAIL: S15 diagtab perfect prediction (error `=_rc')"
    local ++fail_count
}

* S16: diagtab with zero sensitivity (all predicted negative)
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 30)
    gen byte test = 0
    diagtab test gold, xlsx("`output_dir'/_stress_diag_nosens.xlsx") sheet("nosens")
    assert abs(r(sensitivity)) < 0.001
    assert abs(r(specificity) - 1.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: S16 diagtab zero sensitivity"
    local ++pass_count
}
else {
    display as error "  FAIL: S16 diagtab zero sensitivity (error `=_rc')"
    local ++fail_count
}

* S17: crosstab with very sparse table exports with exact test
capture noisily {
    clear
    set obs 50
    gen byte exposure = cond(_n <= 45, 0, 1)
    gen byte outcome = cond(_n <= 48, 0, 1)
    label variable exposure "Rare exposure"
    label variable outcome "Rare outcome"
    crosstab exposure outcome, exact ///
        xlsx("`output_dir'/_stress_cross_sparse.xlsx") sheet("sparse")
    confirm file "`output_dir'/_stress_cross_sparse.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S17 crosstab sparse table with exact test"
    local ++pass_count
}
else {
    display as error "  FAIL: S17 crosstab sparse table (error `=_rc')"
    local ++fail_count
}

* S18: crosstab rejects undefined requested OR
capture noisily {
    clear
    set obs 50
    gen byte exposure = cond(_n <= 45, 0, 1)
    gen byte outcome = cond(_n <= 48, 0, 1)
    capture crosstab exposure outcome, exact or
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: S18 crosstab undefined OR rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: S18 crosstab undefined OR rejected (error `=_rc')"
    local ++fail_count
}

* S19: table1_tc display output without xlsx (console only)
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn \ rep78 cat)
}
if _rc == 0 {
    display as result "  PASS: S19 table1_tc console-only display"
    local ++pass_count
}
else {
    display as error "  FAIL: S19 table1_tc console-only display (error `=_rc')"
    local ++fail_count
}

* S20: corrtab display output without xlsx (console only)
capture noisily {
    sysuse auto, clear
 corrtab price mpg weight
}
if _rc == 0 {
    display as result "  PASS: S20 corrtab console-only display"
    local ++pass_count
}
else {
    display as error "  FAIL: S20 corrtab console-only display (error `=_rc')"
    local ++fail_count
}

* S22: regtab console output
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
 regtab, xlsx("`output_dir'/_stress_reg_display.xlsx") sheet("disp")
    confirm file "`output_dir'/_stress_reg_display.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S22 regtab with display option"
    local ++pass_count
}
else {
    display as error "  FAIL: S22 regtab with display (error `=_rc')"
    local ++fail_count
}

* S23: survtab with RMST (2 groups only for rmst_diff; common support is 23)
capture noisily {
    sysuse cancer, clear
    gen byte drug2 = (drug >= 2)
    stset studytime, failure(died)
    survtab, times(10 20) by(drug2) rmst(20) median difference ///
        xlsx("`output_dir'/_stress_surv_rmst.xlsx") sheet("rmst")
    assert !missing(r(rmst_diff))
}
if _rc == 0 {
    display as result "  PASS: S23 survtab with RMST"
    local ++pass_count
}
else {
    display as error "  FAIL: S23 survtab with RMST (error `=_rc')"
    local ++fail_count
}

* S24: survtab with difference option
capture noisily {
    sysuse cancer, clear
    gen byte drug2 = (drug >= 2)
    stset studytime, failure(died)
    survtab, times(10 20 30) by(drug2) difference median ///
        xlsx("`output_dir'/_stress_surv_diff.xlsx") sheet("diff")
    confirm file "`output_dir'/_stress_surv_diff.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S24 survtab with difference"
    local ++pass_count
}
else {
    display as error "  FAIL: S24 survtab with difference (error `=_rc')"
    local ++fail_count
}

* S24b: survtab rejects difference with more than 2 groups
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture survtab, times(10 20 30) by(drug) difference
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: S24b survtab rejects 3-group difference"
    local ++pass_count
}
else {
    display as error "  FAIL: S24b survtab 3-group difference validation (error `=_rc')"
    local ++fail_count
}

* S24c: survtab rejects invalid rmst()/pdp()/highpdp()
capture noisily {
    sysuse cancer, clear
    gen byte drug2 = (drug >= 2)
    stset studytime, failure(died)

    capture survtab, times(10 20 30) by(drug2) rmst(-5)
    assert _rc == 198

    capture survtab, times(10 20 30) by(drug2) pdp(-2)
    assert _rc == 198

    capture survtab, times(10 20 30) by(drug2) highpdp(-2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: S24c survtab rejects invalid rmst()/pdp()/highpdp()"
    local ++pass_count
}
else {
    display as error "  FAIL: S24c survtab option validation (error `=_rc')"
    local ++fail_count
}

* S25: crosstab with weighted data
capture noisily {
    sysuse auto, clear
    gen wt = price / 1000
    crosstab rep78 foreign [fw=round(wt)], colpct ///
        xlsx("`output_dir'/_stress_cross_wt.xlsx") sheet("weighted")
    confirm file "`output_dir'/_stress_cross_wt.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S25 crosstab with frequency weights"
    local ++pass_count
}
else {
    display as error "  FAIL: S25 crosstab with frequency weights (error `=_rc')"
    local ++fail_count
}

* S26: All theme options across commands
capture noisily {
    sysuse auto, clear
    foreach theme in lancet nejm bmj apa {
        table1_tc, by(foreign) vars(price contn) ///
            xlsx("`output_dir'/_stress_theme_`theme'.xlsx") ///
            sheet("`theme'") theme(`theme')
        confirm file "`output_dir'/_stress_theme_`theme'.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: S26 all 4 themes (lancet, nejm, bmj, apa)"
    local ++pass_count
}
else {
    display as error "  FAIL: S26 theme options (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# Cleanup
* ============================================================

local stress_files : dir "`output_dir'" files "_stress_*.xlsx"
foreach f of local stress_files {
    capture erase "`output_dir'/`f'"
}

* ============================================================

**# Migrated: export failure r() survival

local bad_root "`output_dir'/__missing_export_dir__"


capture program drop _make_exportfail_strate
program define _make_exportfail_strate
    syntax , BASENAME(string)
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, cond(_n == 2, 20, 30))
    gen _Y = cond(_n == 1, 1000, cond(_n == 2, 1100, 1200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define exportfail_exp 0 "Low" 1 "Medium" 2 "High", replace
    label values exposure exportfail_exp
    save "`basename'.dta", replace
end


**# Direct builders
**## table1_tc returns varlist and table after xlsx() failure
capture noisily {
    sysuse auto, clear
    return clear
    capture noisily table1_tc price mpg weight, by(foreign) ///
        xlsx("`bad_root'/table1_tc.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert strpos("`r(varlist)'", "price") > 0
    tempname t1
    matrix `t1' = r(table)
    assert rowsof(`t1') > 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## crosstab returns table and N after xlsx() failure
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq
    return clear
    capture noisily crosstab outcome exposure, ///
        xlsx("`bad_root'/crosstab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N) == 100
    tempname ct
    matrix `ct' = r(table)
    assert rowsof(`ct') > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## corrtab returns correlation matrices after xlsx() failure
capture noisily {
    sysuse auto, clear
    return clear
    capture noisily corrtab price mpg weight, ///
        xlsx("`bad_root'/corrtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    tempname C N
    matrix `C' = r(C)
    matrix `N' = r(N)
    assert colsof(`C') == 3
    assert `N'[1,1] > 0
}
if _rc == 0 {
    display as result "  PASS: corrtab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## diagtab returns scalar diagnostics after xlsx() failure
capture noisily {
    sysuse auto, clear
    gen byte expensive = price > 6000 if !missing(price)
    gen byte heavy = weight > 3000 if !missing(weight)
    return clear
    capture noisily diagtab heavy expensive, ///
        xlsx("`bad_root'/diagtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(sensitivity) >= 0 & r(sensitivity) <= 1
    assert r(specificity) >= 0 & r(specificity) <= 1
}
if _rc == 0 {
    display as result "  PASS: diagtab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## survtab returns survival table after xlsx() failure
capture noisily {
    webuse drugtr, clear
    stset studytime, failure(died)
    return clear
    capture noisily survtab, times(10 20) by(drug) ///
        xlsx("`bad_root'/survtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N_rows) > 0
    tempname st
    matrix `st' = r(table)
    assert rowsof(`st') > 0
}
if _rc == 0 {
    display as result "  PASS: survtab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## stratetab returns rate matrices after xlsx() failure
capture noisily {
    tempfile rate1
    _make_exportfail_strate, basename("`rate1'")
    clear
    return clear
    capture noisily stratetab, using("`rate1'") outcomes(1) ///
        xlsx("`bad_root'/stratetab.xlsx")
    local rc = _rc
    capture confirm file "`bad_root'/stratetab.xlsx"
    assert _rc != 0
    assert r(N_rows) >= 6
    tempname rt
    matrix `rt' = r(rates)
    assert rowsof(`rt') > 0
    assert `"`r(xlsx)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: stratetab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**# Collect-based builders
**## regtab returns table and model counts after xlsx() failure
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    return clear
    capture noisily regtab, xlsx("`bad_root'/regtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N_models) == 1
    tempname rg
    matrix `rg' = r(table)
    assert rowsof(`rg') > 0
}
if _rc == 0 {
    display as result "  PASS: regtab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## effecttab returns table and detected type after xlsx() failure
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    collect clear
    collect: margins, dydx(mpg weight)
    return clear
    capture noisily effecttab, type(margins) ///
        xlsx("`bad_root'/effecttab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert "`r(type)'" == "margins"
    tempname ef
    matrix `ef' = r(table)
    assert rowsof(`ef') > 0
}
if _rc == 0 {
    display as result "  PASS: effecttab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## comptab returns composite dimensions after xlsx() failure
capture noisily {
    capture frame drop ef_comp1
    capture frame drop ef_comp2

    sysuse auto, clear
    collect clear
    collect: regress price mpg
    regtab, frame(ef_comp1, replace)

    collect clear
    collect: regress price weight
    regtab, frame(ef_comp2, replace)

    return clear
    capture noisily comptab ef_comp1 ef_comp2, rows(1 \ 1) ///
        xlsx("`bad_root'/comptab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N_frames) == 2
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: comptab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab export-failure returns (rc=`=_rc')"
    local ++fail_count
}
capture frame drop ef_comp1
capture frame drop ef_comp2

**## hrcomptab returns scaffold metadata after xlsx() failure
capture noisily {
    capture frame drop ef_rates
    capture frame drop ef_model

    tempfile rate1
    _make_exportfail_strate, basename("`rate1'")
    clear
    stratetab, using("`rate1'") outcomes(1) outcomeids(_t) ///
        frame(ef_rates, replace)

    sysuse auto, clear
    stset price, failure(foreign)
    collect clear
    collect: stcox mpg weight
    regtab, frame(ef_model, replace) coef(HR)

    return clear
    capture noisily hrcomptab ef_rates, modelframes(ef_model) rows(1 2) ///
        xlsx("`bad_root'/hrcomptab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert r(N_outcomes) == 1
    assert r(N_modelframes) == 1
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: hrcomptab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab export-failure returns (rc=`=_rc')"
    local ++fail_count
}
capture frame drop ef_rates
capture frame drop ef_model

**## puttab returns source dimensions after xlsx() failure
capture noisily {
    sysuse auto, clear
    return clear
    capture noisily puttab make mpg in 1/2 using "`bad_root'/puttab.xlsx"
    local rc = _rc
    assert `rc' != 0
    assert r(n_rows) == 3
    assert r(n_cols) == 2
    assert r(n_datarows) == 2
    assert "`r(source)'" == "data"
    assert `"`r(file)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: puttab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: puttab export-failure returns (rc=`=_rc')"
    local ++fail_count
}

**## simtab returns analytical metadata after xlsx() failure
capture noisily {
    clear
    set obs 8
    gen long sim = mod(_n - 1, 4) + 1
    gen byte estimator = floor((_n - 1) / 4) + 1
    gen double estimate = cond(estimator == 1, .1, .2) + ///
        (_n - 4 * floor((_n - 1) / 4) - 2.5) / 100
    gen double se = .05
    return clear
    capture noisily simtab estimator, estimate(estimate) se(se) true(0) ///
        sim(sim) xlsx("`bad_root'/simtab.xlsx")
    local rc = _rc
    assert `rc' != 0
    assert "`r(mode)'" == "compute"
    assert "`r(source)'" == "compute"
    assert r(n_estimands) == 1
    assert r(n_estimators) == 2
    assert r(n_by) == 1
    assert r(N_cells) == 2
    assert r(n_reps_min) == 4
    assert r(n_reps_max) == 4
    assert `"`r(xlsx)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: simtab preserves r() after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: simtab export-failure returns (rc=`=_rc')"
    local ++fail_count
}


**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_package_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _pkgadv
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_package_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _pkgadv
