*! _visual_stress_gen.do - generate tabtools visual export stress artifacts

clear all
set more off
set varabbrev off
version 17.0

capture log close _visualstress
log using "_visual_stress_gen.log", replace text name(_visualstress)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_root "`qa_dir'/output"
local out "`output_root'/visual_stress_20260625"
capture mkdir "`output_root'"
capture mkdir "`out'"

display as text "ado dir before targeted local reinstall"
ado dir
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

local stems table1_tc regtab desctab crosstab crosstab_fisher crosstab_rr ///
    corrtab diagtab effecttab hrcomptab comptab comptab_full1 comptab_full2 ///
    stratetab survtab simtab puttab puttab_A puttab_B stacktab ///
    stress_table1_long_unicode stress_crosstab_many_groups ///
    stress_corrtab_extreme stress_puttab_overwrite
foreach s of local stems {
    capture erase "`out'/`s'.xlsx"
    capture erase "`out'/`s'.csv"
    capture erase "`out'/`s'.md"
}
capture erase "`out'/manifest.tsv"
capture erase "`out'/stacktab_src.xlsx"
capture erase "`out'/stacktab_output.xlsx"
capture erase "`out'/stress_puttab_overwrite.xlsx"

tempname mh
local tab = char(9)
file open `mh' using "`out'/manifest.tsv", write text replace
file write `mh' "command`tab'variant`tab'xlsx`tab'sheet`tab'csv`tab'markdown" _n

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

capture program drop _vs_record
program define _vs_record
    args name rc
    if `rc' == 0 {
        display as result "  PASS: `name'"
        c_local _vs_ok = 1
    }
    else {
        display as error "  FAIL: `name' (rc=`rc')"
        c_local _vs_ok = 0
    }
end

**# table1_tc
local ++test_count
capture noisily {
    sysuse auto, clear
    label variable price "Price, USD"
    label variable mpg "Fuel economy, miles/gallon"
    label variable rep78 "Repair record"
    table1_tc, by(foreign) vars(price contn \ mpg conts \ rep78 cat) ///
        test smd title("Table 1. Baseline characteristics") ///
        xlsx("`out'/table1_tc.xlsx") sheet("Table 1") ///
        csv("`out'/table1_tc.csv") markdown("`out'/table1_tc.md") ///
        headershade zebra
    confirm file "`out'/table1_tc.xlsx"
    confirm file "`out'/table1_tc.csv"
    confirm file "`out'/table1_tc.md"
    file write `mh' "table1_tc`tab'happy`tab'`out'/table1_tc.xlsx`tab'Table 1`tab'`out'/table1_tc.csv`tab'`out'/table1_tc.md" _n
}
_vs_record "table1_tc happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' table1_tc"
}

**# regtab
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight foreign
    regtab, noint models("Base model" \ "Adjusted model") stats(n r2) ///
        title("Regression models") xlsx("`out'/regtab.xlsx") sheet("Models") ///
        csv("`out'/regtab.csv") markdown("`out'/regtab.md") headershade zebra
    confirm file "`out'/regtab.xlsx"
    confirm file "`out'/regtab.csv"
    confirm file "`out'/regtab.md"
    file write `mh' "regtab`tab'happy`tab'`out'/regtab.xlsx`tab'Models`tab'`out'/regtab.csv`tab'`out'/regtab.md" _n
}
_vs_record "regtab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' regtab"
}

**# desctab
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78 foreign, statistic(count price) statistic(mean price) statistic(sd price)
    desctab, title("Descriptive statistics") digits(1) ///
        xlsx("`out'/desctab.xlsx") sheet("Descriptive") ///
        csv("`out'/desctab.csv") markdown("`out'/desctab.md") ///
        headershade zebra
    confirm file "`out'/desctab.xlsx"
    confirm file "`out'/desctab.csv"
    confirm file "`out'/desctab.md"
    file write `mh' "desctab`tab'happy`tab'`out'/desctab.xlsx`tab'Descriptive`tab'`out'/desctab.csv`tab'`out'/desctab.md" _n
}
_vs_record "desctab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' desctab"
}

**# crosstab
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte exposed = (_n <= 100)
    gen byte event = 0
    replace event = 1 if exposed == 1 & _n <= 80
    replace event = 1 if exposed == 0 & _n > 100 & _n <= 130
    label define yesno 0 "No" 1 "Yes", replace
    label values exposed yesno
    label values event yesno
    crosstab event exposed, exact or title("Fisher exact cross-tab") ///
        xlsx("`out'/crosstab.xlsx") sheet("Fisher") ///
        csv("`out'/crosstab_fisher.csv") markdown("`out'/crosstab_fisher.md") ///
        headershade zebra
    crosstab event exposed, rr rd title("Risk ratio cross-tab") ///
        xlsx("`out'/crosstab.xlsx") sheet("RR") ///
        csv("`out'/crosstab_rr.csv") markdown("`out'/crosstab_rr.md") ///
        headershade zebra
    confirm file "`out'/crosstab.xlsx"
    confirm file "`out'/crosstab_fisher.csv"
    confirm file "`out'/crosstab_fisher.md"
    confirm file "`out'/crosstab_rr.csv"
    confirm file "`out'/crosstab_rr.md"
    file write `mh' "crosstab`tab'fisher`tab'`out'/crosstab.xlsx`tab'Fisher`tab'`out'/crosstab_fisher.csv`tab'`out'/crosstab_fisher.md" _n
    file write `mh' "crosstab`tab'rr`tab'`out'/crosstab.xlsx`tab'RR`tab'`out'/crosstab_rr.csv`tab'`out'/crosstab_rr.md" _n
}
_vs_record "crosstab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' crosstab"
}

**# corrtab
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight length, full title("Correlation matrix") ///
        xlsx("`out'/corrtab.xlsx") sheet("Full") ///
        csv("`out'/corrtab.csv") markdown("`out'/corrtab.md") ///
        headershade zebra
    confirm file "`out'/corrtab.xlsx"
    confirm file "`out'/corrtab.csv"
    confirm file "`out'/corrtab.md"
    file write `mh' "corrtab`tab'happy`tab'`out'/corrtab.xlsx`tab'Full`tab'`out'/corrtab.csv`tab'`out'/corrtab.md" _n
}
_vs_record "corrtab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' corrtab"
}

**# diagtab
local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 71025
    gen byte gold = (_n <= 100)
    gen byte test = runiform() < cond(gold, 0.82, 0.12)
    diagtab test gold, title("Diagnostic accuracy") exact auc ///
        xlsx("`out'/diagtab.xlsx") sheet("Diagnostic") ///
        csv("`out'/diagtab.csv") markdown("`out'/diagtab.md") ///
        headershade zebra
    confirm file "`out'/diagtab.xlsx"
    confirm file "`out'/diagtab.csv"
    confirm file "`out'/diagtab.md"
    file write `mh' "diagtab`tab'happy`tab'`out'/diagtab.xlsx`tab'Diagnostic`tab'`out'/diagtab.csv`tab'`out'/diagtab.md" _n
}
_vs_record "diagtab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' diagtab"
}

**# effecttab
local ++test_count
capture noisily {
    matrix eff = (1.50, 0.80, 2.20, 0.040 \ 2.30, 1.10, 3.50, 0.001 \ -0.50, -1.20, 0.20, 0.150)
    matrix rownames eff = "Age" "Sex" "BMI"
    effecttab, from(eff) effect("OR") title("Marginal effects") ///
        xlsx("`out'/effecttab.xlsx") sheet("AME") ///
        csv("`out'/effecttab.csv") markdown("`out'/effecttab.md") ///
        headershade zebra
    confirm file "`out'/effecttab.xlsx"
    confirm file "`out'/effecttab.csv"
    confirm file "`out'/effecttab.md"
    file write `mh' "effecttab`tab'happy`tab'`out'/effecttab.xlsx`tab'AME`tab'`out'/effecttab.csv`tab'`out'/effecttab.md" _n
}
_vs_record "effecttab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' effecttab"
}

**# stratetab and hrcomptab shared setup
local ++test_count
capture noisily {
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, cond(_n == 2, 20, 30))
    gen _Y = cond(_n == 1, 1000, cond(_n == 2, 1100, 1200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    label define sexp 0 "Low" 1 "Medium" 2 "High", replace
    label values exposure sexp
    tempfile rate1
    save "`rate1'.dta", replace
    clear
    stratetab, using("`rate1'") outcomes(1) title("Incidence rates") ///
        xlsx("`out'/stratetab.xlsx") sheet("Rates") ///
        csv("`out'/stratetab.csv") markdown("`out'/stratetab.md") ///
        headershade zebra
    confirm file "`out'/stratetab.xlsx"
    confirm file "`out'/stratetab.csv"
    confirm file "`out'/stratetab.md"
    file write `mh' "stratetab`tab'happy`tab'`out'/stratetab.xlsx`tab'Rates`tab'`out'/stratetab.csv`tab'`out'/stratetab.md" _n

    stratetab, using("`rate1'") outcomes(1) frame(vs_rates, replace)
    sysuse auto, clear
    collect clear
    collect: logistic foreign mpg weight
    capture frame drop vs_mod
    regtab, frame(vs_mod, replace) noint coef(OR)
    hrcomptab vs_rates, modelframes(vs_mod) rows(1 2) effect("aHR") ///
        title("Table 2. Rates and model estimates") ///
        xlsx("`out'/hrcomptab.xlsx") sheet("Table 2") ///
        csv("`out'/hrcomptab.csv") markdown("`out'/hrcomptab.md") ///
        headershade zebra
    confirm file "`out'/hrcomptab.xlsx"
    confirm file "`out'/hrcomptab.csv"
    confirm file "`out'/hrcomptab.md"
    file write `mh' "hrcomptab`tab'happy`tab'`out'/hrcomptab.xlsx`tab'Table 2`tab'`out'/hrcomptab.csv`tab'`out'/hrcomptab.md" _n
}
_vs_record "stratetab and hrcomptab happy exports" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' stratetab/hrcomptab"
}

**# survtab
local ++test_count
capture noisily {
    clear
    set obs 80
    set seed 91025
    gen double time = runiform()*10 + 0.5
    gen byte event = runiform() < 0.65
    gen byte grp = mod(_n, 2)
    stset time, failure(event)
    survtab, times(2 5 8) by(grp) title("Survival estimates") ///
        xlsx("`out'/survtab.xlsx") sheet("CI") ///
        csv("`out'/survtab.csv") markdown("`out'/survtab.md") ///
        headershade zebra
    confirm file "`out'/survtab.xlsx"
    confirm file "`out'/survtab.csv"
    confirm file "`out'/survtab.md"
    file write `mh' "survtab`tab'happy`tab'`out'/survtab.xlsx`tab'CI`tab'`out'/survtab.csv`tab'`out'/survtab.md" _n
}
_vs_record "survtab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' survtab"
}

**# simtab
local ++test_count
capture noisily {
    clear
    set obs 120
    set seed 41025
    gen long sim = mod(_n-1, 30) + 1
    gen byte estid = mod(floor((_n-1)/30), 4) + 1
    gen double truev = 0.5
    gen double est = truev + rnormal(0, 0.05)
    gen double se = 0.05 + runiform()*0.005
    gen byte covered = abs(est - truev) <= 1.96*se
    gen double pval = 2*(1 - normal(abs(est/se)))
    gen byte reject = pval < 0.05
    simtab estid, estimate(est) se(se) true(truev) coverage(covered) reject(reject) ///
        title("Simulation performance") xlsx("`out'/simtab.xlsx") sheet("Table 2") ///
        csv("`out'/simtab.csv") markdown("`out'/simtab.md") ///
        level(95) alpha(0.05) minreps(2) warnreps(2) headershade zebra ///
        plotframe(vs_simpf, replace)
    confirm file "`out'/simtab.xlsx"
    confirm file "`out'/simtab.csv"
    confirm file "`out'/simtab.md"
    file write `mh' "simtab`tab'happy`tab'`out'/simtab.xlsx`tab'Table 2`tab'`out'/simtab.csv`tab'`out'/simtab.md" _n
}
_vs_record "simtab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' simtab"
}

**# puttab
local ++test_count
capture noisily {
    sysuse auto, clear
    puttab make mpg price in 1/8 using "`out'/puttab.xlsx", sheet("A") ///
        title("Puttab A") csv("`out'/puttab_A.csv") markdown("`out'/puttab_A.md") ///
        headershade zebra
    puttab make weight length in 1/8 using "`out'/puttab.xlsx", sheet("B") ///
        title("Puttab B") csv("`out'/puttab_B.csv") markdown("`out'/puttab_B.md") ///
        headershade zebra
    confirm file "`out'/puttab.xlsx"
    confirm file "`out'/puttab_A.csv"
    confirm file "`out'/puttab_A.md"
    confirm file "`out'/puttab_B.csv"
    confirm file "`out'/puttab_B.md"
    file write `mh' "puttab`tab'A`tab'`out'/puttab.xlsx`tab'A`tab'`out'/puttab_A.csv`tab'`out'/puttab_A.md" _n
    file write `mh' "puttab`tab'B`tab'`out'/puttab.xlsx`tab'B`tab'`out'/puttab_B.csv`tab'`out'/puttab_B.md" _n
}
_vs_record "puttab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' puttab"
}

**# comptab
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg
    collect: regress price foreign mpg weight
    capture frame drop vs_reg_cf
    regtab, frame(vs_reg_cf, replace) noint models("Model A" \ "Model B")
    comptab vs_reg_cf, rows(1 2) title("Composite table 1") ///
        xlsx("`out'/comptab.xlsx") sheet("Full 1") ///
        csv("`out'/comptab_full1.csv") markdown("`out'/comptab_full1.md") ///
        headershade zebra
    comptab vs_reg_cf, rows(2 3) ///
        title("Composite table 2") xlsx("`out'/comptab.xlsx") sheet("Full 2") ///
        csv("`out'/comptab_full2.csv") markdown("`out'/comptab_full2.md") ///
        headershade zebra
    confirm file "`out'/comptab.xlsx"
    confirm file "`out'/comptab_full1.csv"
    confirm file "`out'/comptab_full1.md"
    confirm file "`out'/comptab_full2.csv"
    confirm file "`out'/comptab_full2.md"
    file write `mh' "comptab`tab'full1`tab'`out'/comptab.xlsx`tab'Full 1`tab'`out'/comptab_full1.csv`tab'`out'/comptab_full1.md" _n
    file write `mh' "comptab`tab'full2`tab'`out'/comptab.xlsx`tab'Full 2`tab'`out'/comptab_full2.csv`tab'`out'/comptab_full2.md" _n
}
_vs_record "comptab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' comptab"
}

**# stacktab
local ++test_count
capture noisily {
    local src "`out'/stacktab_src.xlsx"
    local wb "`out'/stacktab_output.xlsx"
    clear
    input str20 label str10 est str16 ci
    "Category"   "HR"    "95% CI"
    "Binary HRT" "1.23"  "(1.05, 1.44)"
    "Active"     "1.45"  "(1.20, 1.75)"
    end
    export excel "`src'", sheet("SrcA") sheetreplace
    export excel "`wb'", sheet("SrcA") sheetreplace
    clear
    input str20 label str10 est str16 ci
    "Dose"      "aHR"   "95% CI"
    "Low dose"  "1.10"  "(0.90, 1.35)"
    "High dose" "1.67"  "(1.30, 2.15)"
    end
    export excel "`src'", sheet("SrcB") sheetreplace
    export excel "`wb'", sheet("SrcB") sheetreplace
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/3) cols(A-C) \ sheet(SrcB) rows(1/3) cols(A-C)) ///
        sheet("Composite") sheetreplace title("Stacked table") ///
        csv("`out'/stacktab.csv") markdown("`out'/stacktab.md")
    confirm file "`wb'"
    confirm file "`out'/stacktab.csv"
    confirm file "`out'/stacktab.md"
    file write `mh' "stacktab`tab'happy`tab'`wb'`tab'Composite`tab'`out'/stacktab.csv`tab'`out'/stacktab.md" _n
}
_vs_record "stacktab happy export" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' stacktab"
}

**# stress: long labels, Unicode, pipes, and many columns
local ++test_count
capture noisily {
    clear
    set obs 150
    set seed 260625
    gen byte grp = mod(_n, 5)
    gen double marker = rnormal(100, 15)
    gen double biomu = runiform()*1000
    gen byte category = mod(_n, 4)
    label define glbl 0 "Arm A | control" 1 "Arm B - Förändring" 2 "Arm C ≥ target" 3 "Arm D μ-dose" 4 "Arm E very long label", replace
    label values grp glbl
    label define catlbl 0 "None | baseline" 1 "Mild förändring" 2 "Moderate ≥ threshold" 3 "Severe μ-shift", replace
    label values category catlbl
    label variable marker "A very long continuous marker label with spaces, punctuation, and CI pressure"
    label variable biomu "Unicode biomarker μmol/L with value ≥ assay floor"
    label variable category "Categorical label containing a pipe | and accented text"
    table1_tc, by(grp) vars(marker contn \ biomu conts \ category cat) ///
        test smd title("Stress: long labels, Unicode, pipes, and 5 groups") ///
        xlsx("`out'/stress_table1_long_unicode.xlsx") sheet("Stress") ///
        csv("`out'/stress_table1_long_unicode.csv") ///
        markdown("`out'/stress_table1_long_unicode.md") ///
        headershade zebra
    confirm file "`out'/stress_table1_long_unicode.xlsx"
    confirm file "`out'/stress_table1_long_unicode.csv"
    confirm file "`out'/stress_table1_long_unicode.md"
    file write `mh' "table1_tc`tab'stress_long_unicode_pipe`tab'`out'/stress_table1_long_unicode.xlsx`tab'Stress`tab'`out'/stress_table1_long_unicode.csv`tab'`out'/stress_table1_long_unicode.md" _n
}
_vs_record "stress long labels/unicode/pipe table1_tc" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' stress_table1"
}

**# stress: many crosstab columns
local ++test_count
capture noisily {
    clear
    set obs 300
    gen byte group10 = mod(_n, 10)
    gen byte event = mod(_n, 3) == 0
    label define g10 0 "Group 0 very long" 1 "Group 1" 2 "Group 2" 3 "Group 3" 4 "Group 4" 5 "Group 5" 6 "Group 6" 7 "Group 7" 8 "Group 8" 9 "Group 9", replace
    label values group10 g10
    label define eventlbl 0 "No event" 1 "Event", replace
    label values event eventlbl
    crosstab event group10, colpct title("Stress: crosstab with ten columns") ///
        xlsx("`out'/stress_crosstab_many_groups.xlsx") sheet("Many groups") ///
        csv("`out'/stress_crosstab_many_groups.csv") ///
        markdown("`out'/stress_crosstab_many_groups.md") headershade zebra
    confirm file "`out'/stress_crosstab_many_groups.xlsx"
    confirm file "`out'/stress_crosstab_many_groups.csv"
    confirm file "`out'/stress_crosstab_many_groups.md"
    file write `mh' "crosstab`tab'stress_many_groups`tab'`out'/stress_crosstab_many_groups.xlsx`tab'Many groups`tab'`out'/stress_crosstab_many_groups.csv`tab'`out'/stress_crosstab_many_groups.md" _n
}
_vs_record "stress crosstab many groups" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' stress_crosstab"
}

**# stress: perfect/extreme correlations
local ++test_count
capture noisily {
    clear
    set obs 80
    gen double x = _n
    gen double y = x
    gen double z = -x
    gen double tiny = 1e-12 * _n
    label variable tiny "Tiny value scale 1e-12"
    corrtab x y z tiny, full digits(3) title("Stress: perfect and tiny correlations") ///
        xlsx("`out'/stress_corrtab_extreme.xlsx") sheet("Extreme") ///
        csv("`out'/stress_corrtab_extreme.csv") ///
        markdown("`out'/stress_corrtab_extreme.md") headershade zebra
    confirm file "`out'/stress_corrtab_extreme.xlsx"
    confirm file "`out'/stress_corrtab_extreme.csv"
    confirm file "`out'/stress_corrtab_extreme.md"
    file write `mh' "corrtab`tab'stress_extreme`tab'`out'/stress_corrtab_extreme.xlsx`tab'Extreme`tab'`out'/stress_corrtab_extreme.csv`tab'`out'/stress_corrtab_extreme.md" _n
}
_vs_record "stress corrtab extreme values" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' stress_corrtab"
}

**# stress: existing sheet overwrite leaves no stale rows
local ++test_count
capture noisily {
    clear
    set obs 20
    gen str20 label = "stale_" + string(_n)
    gen value = _n
    puttab label value using "`out'/stress_puttab_overwrite.xlsx", sheet("Replace") ///
        title("Stale long table")
    clear
    set obs 3
    gen str20 label = "fresh_" + string(_n)
    gen value = 100 + _n
    puttab label value using "`out'/stress_puttab_overwrite.xlsx", sheet("Replace") ///
        title("Fresh short table") csv("`out'/stress_puttab_overwrite.csv") ///
        markdown("`out'/stress_puttab_overwrite.md")
    confirm file "`out'/stress_puttab_overwrite.xlsx"
    confirm file "`out'/stress_puttab_overwrite.csv"
    confirm file "`out'/stress_puttab_overwrite.md"
    import excel using "`out'/stress_puttab_overwrite.xlsx", sheet("Replace") clear allstring
    count if strpos(A, "stale_") | strpos(B, "stale_")
    assert r(N) == 0
    file write `mh' "puttab`tab'stress_overwrite`tab'`out'/stress_puttab_overwrite.xlsx`tab'Replace`tab'`out'/stress_puttab_overwrite.csv`tab'`out'/stress_puttab_overwrite.md" _n
}
_vs_record "stress puttab overwrite stale-row guard" `=_rc'
if `_vs_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' stress_puttab"
}

file close `mh'

display ""
display as result "Visual stress artifact generation: `pass_count'/`test_count' passed, `fail_count' failed"
display as result "Manifest: `out'/manifest.tsv"
if `fail_count' > 0 {
    display as error "FAILED blocks:`failed'"
    display "RESULT: visual_stress_gen tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _visualstress
    exit 1
}

display as result "ALL VISUAL STRESS ARTIFACTS GENERATED"
display "RESULT: visual_stress_gen tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _visualstress
