/*  demo_tabtools.do - Generate demo output for tabtools

    Maintainer note:
      This rebuild script is intended for repository use. It reads repo-local
      datasets and sibling packages that are not available to an installed-only
      user.

    Produces:
      Console (1 SMCL file):
        1. console_output.smcl      - consolidated display log for tabtools/table1_tc/survtab/regtab/corrtab/crosstab/diagtab
      Main workbook (demo_tabtools.xlsx) with 46 sheets:
        TABLE 1 FAMILY (9 sheets):
          1.  "Table 1"            - table1_tc baseline characteristics
          2.  "Table 1 Total"      - table1_tc with total column
          3.  "Table 1 Weighted"   - table1_tc with IPTW weights
          4.  "Table 1 WtCompare"  - table1_tc wtcompare: crude vs weighted side-by-side
          5.  "Table 1 Stats"      - table1_tc with SMD + test + statistic + boldp + zebra
          6.  "Table 1 Formats"    - table1_tc: conts, contln, missing, percent_n, headerperc
          7.  "Table 1 Missing"    - table1_tc: missingsummary per variable
          8.  "Table 1 Custom"     - table1_tc: slashN, catrowperc, custom symbols
          9.  "Table 1 NEJM"       - table1_tc with theme(nejm)
        REGRESSION FAMILY (10 sheets):
         10.  "Logistic"           - regtab single logistic model (OR)
         11.  "Multi-Model"        - regtab multi-model comparison (OR)
         12.  "Cox Model"          - regtab Cox proportional hazards
         13.  "Mixed Model"        - regtab mixed effects with relabel + ICC
         14.  "CDISC"              - regtab CDISC-format output (4-decimal, "Estimate" label)
         15.  "Poisson"            - regtab Poisson with IRR + exposure
         16.  "Regtab Advanced"    - regtab dimnonsig + factorlabel + starslevels
         17.  "Regtab Select"      - regtab keep/drop covariate filtering
         18.  "Regtab Drop"        - regtab drop() covariate exclusion
         19.  "Regtab AddRow"      - regtab addrow() custom summary rows
        COMPOSITE FAMILY (5 sheets):
         20.  "S Binary"           - regtab source frame for comptab (binary treatment Cox)
         21.  "S Education"        - regtab source frame for comptab (education factor Cox)
         22.  "Composite"          - comptab cherry-picked exposure rows from two models
         23.  "Composite Compact"  - comptab compact + sections + relabel + footnote + theme
         24.  "Composite Names"    - comptab rownames() pattern-based row selection
        EFFECTS FAMILY (4 sheets):
         25.  "ATE"                - effecttab treatment effects (IPW)
         26.  "ATE Comparison"     - effecttab multi-estimator (IPW vs AIPW)
         27.  "Margins"            - effecttab margins predictions
         28.  "Margins AME"        - effecttab average marginal effects
        RATES (1 sheet):
         29.  "Rates"              - stratetab rate ratios + multiple exposures
        CORRELATION (3 sheets):
         30.  "Correlation"        - corrtab Pearson with stars (lower triangle)
         31.  "Correlation Spear"  - corrtab Spearman with p-values
         32.  "Correlation Full"   - corrtab Pearson full matrix
        CROSS-TABULATION (5 sheets):
         33.  "Cross-Tabulation"   - crosstab 2x2 with Fisher's exact + OR
         34.  "Cross-Tab Measures" - crosstab RR + RD for 2x2 table
         35.  "Cross-Tab Styled"   - crosstab boldp() + zebra
         36.  "Cross-Tab Trend"    - crosstab Cochran-Armitage trend test
         37.  "Cross-Tab Row Pct"  - crosstab with row percentages
        DIAGNOSTIC (3 sheets):
         38.  "Diagnostic"         - diagtab sensitivity/specificity/PPV/NPV
         39.  "Diag Prevalence"    - diagtab prevalence-adjusted PPV/NPV
         40.  "Diag Multi-Cut"     - diagtab cutoffs() multiple thresholds
        SURVIVAL (3 sheets):
         41.  "Survival"           - survtab Kaplan-Meier with median
         42.  "Survival RMST"      - survtab RMST + riskset + difference
         43.  "Cumul Incidence"    - survtab reverse (cumulative incidence)
        THEMES (2 sheets):
         44.  "Theme BMJ"          - table1_tc with theme(bmj)
         45.  "Theme APA"          - table1_tc with theme(apa)
        HR COMPOSITE (1 sheet):
         46.  "HR Composite"       - hrcomptab final Table 2-style composite from stratetab + regtab frames
*/

version 16.0
local _orig_more = c(more)
local _orig_varabbrev = c(varabbrev)
local _orig_linesize = c(linesize)
local _orig_scheme = c(scheme)
local _demo_success ""

capture noisily {
set more off
set varabbrev off
set linesize 250

**# Setup

* Support running from either the repo root or the package demo directory.
local repo_root "`c(pwd)'"
capture confirm file "`repo_root'/tabtools/tabtools.pkg"
if _rc {
    local repo_root = subinstr("`repo_root'", "/tabtools/demo", "", 1)
    capture confirm file "`repo_root'/tabtools/tabtools.pkg"
    if _rc {
        display as error "Run demo_tabtools.do from the Stata-Tools repo root or from tabtools/demo"
        exit 601
    }
}

local pkg_dir "`repo_root'/tabtools/demo"
capture mkdir "`pkg_dir'"

* Install tc_schemes for consistent graph appearance
local tc_schemes_dir "`repo_root'/tc_schemes"
capture confirm file "`tc_schemes_dir'/stata.toc"
if _rc {
    display as error "tc_schemes package not found at `tc_schemes_dir'"
    exit 601
}
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`tc_schemes_dir'") replace
set scheme plotplainblind

* Install tabtools from local repo
capture ado uninstall tabtools
quietly net install tabtools, from("`repo_root'/tabtools") replace

local main_xlsx "`pkg_dir'/demo_tabtools.xlsx"
local console_log "`pkg_dir'/console_output.smcl"
capture erase "`main_xlsx'"

**# Build analysis dataset
* Merge cohort, treatment, comorbidities, and outcomes
use `repo_root'/_data/cohort.dta, clear
merge 1:1 id using `repo_root'/_data/treatment.dta, nogen keep(match)
merge 1:1 id using `repo_root'/_data/comorbidities.dta, nogen keep(master match)
merge 1:1 id using `repo_root'/_data/outcomes.dta, nogen keep(master match)

* Fill missing comorbidities with 0
foreach v in diabetes hypertension anxiety prior_cvd {
    replace `v' = 0 if missing(`v')
}

* Derive binary outcome
gen byte cv_event = (cv_event_date < .)
label variable cv_event "Cardiovascular event"
label define cv_event_lbl 0 "No" 1 "Yes"
label values cv_event cv_event_lbl

* Add readable labels for female (cohort data uses yn_lbl 0=No/1=Yes)
label define female_lbl 0 "Male" 1 "Female"
label values female female_lbl

* Survival time for Cox models
gen double follow_up = study_exit - study_entry
label variable follow_up "Follow-up (days)"
stset follow_up, failure(cv_event)

* Generate IPTW weights for weighted demo
quietly logit treated index_age female i.education ///
    diabetes hypertension anxiety prior_cvd
predict double ps, pr
gen double iptw = cond(treated, 1/ps, 1/(1-ps))
label variable iptw "IPTW weight"

* Synthetic variables for additional demos
set seed 20260324

* Log-normal biomarker (CRP) -- for contln demo
gen double crp = exp(rnormal(1.5, 0.8))
label variable crp "C-reactive protein (mg/L)"

* Right-skewed count (prior hospitalizations) -- for conts demo
gen byte prior_hosp = rpoisson(1.8)
label variable prior_hosp "Prior hospitalizations"

* Rare binary event -- for bine (Fisher's exact) demo
gen byte rare_event = runiform() < 0.03
label variable rare_event "Rare adverse event"

* Variable with deliberate missingness -- for missing option demo
gen byte smoking = .
replace smoking = 0 if runiform() < 0.55
replace smoking = 1 if missing(smoking) & runiform() < 0.45
replace smoking = 2 if missing(smoking) & runiform() < 0.60
* ~10% remain missing
label variable smoking "Smoking status"
label define smoke_lbl 0 "Never" 1 "Former" 2 "Current"
label values smoking smoke_lbl

* Save working dataset
tempfile analysis
save `analysis'

**# Console: consolidated display log
capture log close demo
capture erase "`console_log'"
foreach legacy_log in console_survtab.smcl console_tabtools.smcl console_regtab.smcl ///
    console_corrtab.smcl console_crosstab.smcl console_diagtab.smcl {
    capture erase "`pkg_dir'/`legacy_log'"
}

log using "`console_log'", replace smcl name(demo) nomsg

**# Console: tabtools set/get/list/detail
tabtools set font Calibri
tabtools set fontsize 11
tabtools set borderstyle thin
tabtools get
tabtools set clear

noisily tabtools
noisily tabtools, detail

log off demo

**# Console: table1_tc display
log on demo

noisily table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ female bin \ ///
         education cat \ income_quintile cat \ ///
         born_abroad bin \ civil_status cat \ ///
         diabetes bin \ hypertension bin \ anxiety bin \ prior_cvd bin)

log off demo

**# Console: survtab RMST + difference
log on demo

noisily survtab, times(365 730 1095 1460) by(treated) ///
    rmst(1460) difference median timeunit(days)

log off demo

**# Console: regtab display
collect clear
quietly collect: logistic treated index_age female i.education ///
    diabetes hypertension anxiety prior_cvd

log on demo

noisily regtab, coef("OR") noint display

log off demo

**# Console: corrtab display
log on demo

noisily corrtab index_age crp prior_hosp, ///
    star(0.05 0.01 0.001) display

log off demo

**# Console: crosstab display
log on demo

noisily crosstab treated female, or label display

log off demo

**# Console: diagtab display
quietly logit cv_event treated index_age female diabetes hypertension
predict double phat_display, pr
label variable phat_display "Predicted CV risk"

log on demo

noisily diagtab phat_display cv_event, cutoff(0.35) ///
    auc wilson display

log close demo
drop phat_display


**# Sheet 1: Table 1 -- Baseline Characteristics
use `analysis', clear
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ female bin \ ///
         education cat \ income_quintile cat \ ///
         born_abroad bin \ civil_status cat \ ///
         diabetes bin \ hypertension bin \ anxiety bin \ prior_cvd bin) ///
    title("Table 1. Baseline Characteristics by Treatment Group") ///
    excel("`main_xlsx'") sheet("Table 1")

**# Sheet 2: Table 1 with Total -- Adds a total column
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ female bin \ ///
         education cat \ income_quintile cat \ ///
         born_abroad bin \ diabetes bin \ hypertension bin) ///
    total(after) ///
    title("Table 1. Baseline Characteristics (with Total)") ///
    excel("`main_xlsx'") sheet("Table 1 Total")

**# Sheet 3: Table 1 Weighted -- IPTW-weighted descriptives
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ female bin \ ///
         education cat \ income_quintile cat \ ///
         born_abroad bin \ diabetes bin \ hypertension bin) ///
    wt(iptw) ///
    title("Table 1. Weighted Baseline Characteristics (IPTW)") ///
    excel("`main_xlsx'") sheet("Table 1 Weighted")

**# Sheet 4: Table 1 WtCompare -- Crude vs weighted side-by-side
* Demonstrates: wtcompare shows unweighted and IPTW-weighted columns together
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ female bin \ ///
         education cat \ income_quintile cat \ ///
         diabetes bin \ hypertension bin \ anxiety bin \ prior_cvd bin) ///
    wt(iptw) wtcompare smd ///
    title("Table 1. Crude vs IPTW-Weighted Baseline Characteristics") ///
    footnote("Crude and IPTW-weighted statistics shown side-by-side with SMD.") ///
    excel("`main_xlsx'") sheet("Table 1 WtCompare")

**# Sheet 5: Table 1 Stats -- SMD + test + statistic + boldp + zebra
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ crp contln %5.1f \ ///
         prior_hosp conts \ female bin \ ///
         education cat \ income_quintile cat \ ///
         born_abroad bin \ diabetes bin \ hypertension bin \ ///
         anxiety bin \ prior_cvd bin) ///
    smd test statistic boldp(0.05) zebra ///
    footnote("SMD = standardized mean difference. Bold p-values indicate p < 0.05.") ///
    title("Table 1. Baseline Characteristics with Balance Diagnostics") ///
    excel("`main_xlsx'") sheet("Table 1 Stats")

**# Sheet 6: Table 1 Formats -- Alternative formatting options
* Demonstrates: conts, contln, bine, cate, missing, percent_n, headerperc,
*               highlight(), varlabplus, nospacelowpercent
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ crp contln %5.1f \ ///
         prior_hosp conts \ female bin \ ///
         rare_event bine \ smoking cate \ ///
         education cat \ civil_status cat) ///
    missing percent_n headerperc varlabplus nospacelowpercent ///
    highlight(0.05) ///
    title("Table 1. Alternative Formatting Options Demo") ///
    footnote("Yellow rows indicate p < 0.05. Missing values shown as separate category.") ///
    excel("`main_xlsx'") sheet("Table 1 Formats")

**# Sheet 7: Table 1 Missing -- Missing data summary per variable
* Demonstrates: missingsummary adds a missing-count row below each variable
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ crp contln %5.1f \ ///
         prior_hosp conts \ female bin \ ///
         smoking cate \ education cat \ ///
         rare_event bine) ///
    missingsummary ///
    title("Table 1. Baseline with Missing Data Summary") ///
    footnote("Missing row shows n (%) of missing values per variable.") ///
    excel("`main_xlsx'") sheet("Table 1 Missing")

**# Sheet 8: Table 1 Custom -- Custom symbols and display options
* Demonstrates: slashN, catrowperc, iqrmiddle(), sdleft(), sdright(), pdp(), highpdp()
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ crp contln %5.1f \ ///
         prior_hosp conts \ female bin \ ///
         education cat \ smoking cate) ///
    slashN catrowperc ///
    iqrmiddle(" to ") sdleft(" [") sdright("]") ///
    pdp(4) highpdp(3) ///
    missing ///
    title("Table 1. Custom Symbol Formatting Demo") ///
    footnote("SD shown as mean [SD]. IQR uses 'to' separator. Row % for categoricals.") ///
    excel("`main_xlsx'") sheet("Table 1 Custom")

**# Sheet 9: Table 1 NEJM -- Journal theme styling
* Demonstrates: theme(nejm) for New England Journal of Medicine formatting
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ female bin \ ///
         education cat \ diabetes bin \ hypertension bin \ ///
         anxiety bin \ prior_cvd bin) ///
    smd test ///
    theme(nejm) ///
    title("Table 1. Baseline Characteristics (NEJM Style)") ///
    excel("`main_xlsx'") sheet("Table 1 NEJM")

**# Sheet 10: Logistic -- Single propensity score model
collect clear
collect: logistic treated index_age female i.education ///
    diabetes hypertension anxiety prior_cvd

regtab, xlsx("`main_xlsx'") sheet("Logistic") frame(_demo_logistic) ///
    title("Table 2. Propensity Score Model (Logistic Regression)") ///
    coef("OR") noint models("Logistic")

**# Sheet 11: Multi-Model -- Nested logistic models
collect clear
collect: logistic treated index_age female
collect: logistic treated index_age female i.education ///
    diabetes hypertension
collect: logistic treated index_age female i.education ///
    diabetes hypertension anxiety prior_cvd

regtab, xlsx("`main_xlsx'") sheet("Multi-Model") ///
    title("Table 3. Propensity Score Models -- Nested Comparison") ///
    coef("OR") models("Demographics \ + Comorbidities \ Full Model") ///
    stats(n aic bic) noint

**# Sheet 12: Cox Model -- Survival analysis
collect clear
collect: stcox treated index_age female i.education ///
    diabetes hypertension anxiety

regtab, xlsx("`main_xlsx'") sheet("Cox Model") frame(_demo_cox) ///
    title("Table 4. Cox Proportional Hazards Model") ///
    coef("HR") stats(n ll) noint models("Cox PH")

**# Sheet 13: Mixed Model -- Random effects with relabel + ICC
preserve
clear
set seed 20260323
set obs 600
gen int region = ceil(_n/100)
label variable region "Healthcare Region"
gen double age = rnormal(55, 12)
label variable age "Age (years)"
gen byte female = runiform() > 0.5
label variable female "Female sex"
gen double bmi = rnormal(26, 5)
label variable bmi "BMI"

* Random intercept per region
gen double u0 = .
forvalues r = 1/6 {
    replace u0 = rnormal() * 0.8 if region == `r'
}

gen double y = 2.5 + 0.01*age - 0.3*female + 0.08*bmi + u0 + rnormal()*0.6
label variable y "Systolic BP Change"

collect clear
collect: mixed y age female bmi || region:

regtab, xlsx("`main_xlsx'") sheet("Mixed Model") ///
    title("Table 5. Mixed Effects Model -- BP Change by Region") ///
    coef("Coef.") stats(n groups aic icc) relabel models("Mixed")
restore

**# Sheet 14: CDISC -- Regulatory-format regression output
* Demonstrates: regtab cdisc option (4-decimal precision, "Estimate" label)
use `analysis', clear
collect clear
collect: logistic treated index_age female i.education diabetes hypertension

regtab, xlsx("`main_xlsx'") sheet("CDISC") ///
    title("Table X. CDISC-Format Regression Output") ///
    coef("OR") cdisc noint models("CDISC")

**# Sheet 15: Poisson -- Incidence rate ratios from Poisson regression
collect clear
collect: poisson cv_event treated index_age female diabetes hypertension, ///
    irr exposure(follow_up)

regtab, xlsx("`main_xlsx'") sheet("Poisson") ///
    title("Table X. Poisson Regression -- Incidence Rate Ratios") ///
    coef("IRR") noint stats(n aic) models("Poisson")

**# Sheet 16: Regtab Advanced -- Conditional formatting and label features
* Demonstrates: dimnonsig, factorlabel, starslevels(), theme(bmj)
collect clear
collect: logistic cv_event treated index_age female i.education ///
    diabetes hypertension anxiety prior_cvd

regtab, xlsx("`main_xlsx'") sheet("Regtab Advanced") ///
    title("Table X. Logistic Regression with Advanced Formatting") ///
    coef("OR") noint dimnonsig factorlabel ///
    starslevels(0.05 0.01 0.001) ///
    theme(bmj) models("Advanced")

**# Sheet 17: Regtab Select -- Covariate filtering with keep/drop
* Demonstrates: keep() to show only selected covariates, stars
collect clear
collect: logistic cv_event treated index_age female i.education ///
    diabetes hypertension anxiety prior_cvd

regtab, xlsx("`main_xlsx'") sheet("Regtab Select") ///
    title("Table X. Selected Covariates (keep/drop demo)") ///
    coef("OR") noint stars ///
    keep(treated index_age female diabetes) ///
    footnote("Selected covariates from full model. * p<0.05 ** p<0.01 *** p<0.001.") ///
    models("Selected")

**# Sheet 18: Regtab Drop -- Exclude specific covariates with drop()
* Demonstrates: drop() to hide covariates while keeping them in the model
collect clear
collect: logistic cv_event treated index_age female i.education ///
    diabetes hypertension anxiety prior_cvd

regtab, xlsx("`main_xlsx'") sheet("Regtab Drop") ///
    title("Table X. Logistic Model (Confounders Suppressed)") ///
    coef("OR") noint ///
    drop(index_age female 2.education 3.education) ///
    footnote("Model adjusted for age, sex, and education (coefficients suppressed).") ///
    models("Adjusted")

**# Sheet 19: Regtab AddRow -- Append custom summary rows
* Demonstrates: addrow() for P-trend, P-interaction, or other custom rows
collect clear
collect: logistic cv_event treated index_age female diabetes hypertension

regtab, xlsx("`main_xlsx'") sheet("Regtab AddRow") ///
    title("Table X. Logistic Regression with Custom Summary Rows") ///
    coef("OR") noint stars ///
    addrow("P for trend" 0.032 \ "P for interaction" 0.15) ///
    footnote("Custom rows appended below model estimates.") ///
    models("Model 1")

* Build purpose-built Cox model frames for composite demo
* Both use HR -- same coefficient type so headers align correctly

* Frame 1: Binary treatment effect (6 data rows)
* Row 1=Treatment, 2=Age, 3=Female, 4=Diabetes, 5=Hypertension, 6=Anxiety
use `analysis', clear
collect clear
collect: stcox treated index_age female diabetes hypertension anxiety, nolog
regtab, xlsx("`main_xlsx'") sheet("S Binary") frame(_demo_binary) coef("HR") noint ///
    title("Cox Model -- Binary Treatment") models("Cox PH")

* Frame 2: Education categories (9 data rows)
* Row 1=Education(hdr), 2=Primary(ref), 3=Secondary, 4=Tertiary,
* 5=Age, 6=Female, 7=Treatment, 8=Diabetes, 9=Hypertension
collect clear
collect: stcox i.education index_age female treated diabetes hypertension, nolog
regtab, xlsx("`main_xlsx'") sheet("S Education") frame(_demo_educ) coef("HR") noint ///
    title("Cox Model -- Education Categories") models("Cox PH")

capture frame drop _demo_logistic
capture frame drop _demo_cox

**# Sheet 22: Composite -- Cherry-pick exposure rows from two Cox models
* Demonstrates: comptab pulling specific rows into one summary table
* Treatment HR from binary model + education HRs from factor model
comptab _demo_binary _demo_educ, ///
    rows(1 \ 1/4) ///
    xlsx("`main_xlsx'") sheet("Composite") ///
    title("Table S1. Exposure Effects on Cardiovascular Events") ///
    separator(2)

**# Sheet 23: Composite Compact -- Full composite with sections + footnote
* Demonstrates: compact, section(), relabel(), footnote(), theme()
* Treatment + confounders from model 1, education from model 2
comptab _demo_binary _demo_educ, ///
    rows(1 4 5 6 \ 1/4) compact ///
    section("Treatment Effect" \ "Education Level") ///
    xlsx("`main_xlsx'") sheet("Composite Compact") ///
    title("Table 3. Risk Factors for Cardiovascular Events") ///
    footnote("aHR = adjusted hazard ratio; CI = confidence interval. Models adjusted for age, sex, and comorbidities.") ///
    theme(lancet)

**# Sheet 24: Composite Names -- Pattern-based row selection with rownames()
* Demonstrates: comptab rownames() as alternative to rows() for label-based selection
comptab _demo_binary _demo_educ, ///
    rownames(Treatment Diabetes Hypertension \ Secondary Tertiary) ///
    xlsx("`main_xlsx'") sheet("Composite Names") ///
    title("Table S2. Selected Risk Factors (Name-Based Selection)") ///
    compact zebra ///
    footnote("Rows selected by label pattern using rownames() option.")

capture frame drop _demo_binary
capture frame drop _demo_educ

**# Sheet 25: ATE -- Treatment effects (IPW)
use `analysis', clear
collect clear
collect: teffects ipw (cv_event) (treated index_age female i.education ///
    diabetes hypertension anxiety), ate

effecttab, xlsx("`main_xlsx'") sheet("ATE") ///
    effect("ATE") ///
    title("Table 6. Average Treatment Effect on CV Events (IPW)") ///
    tlabels(0 "SSRI" 1 "SNRI")

**# Sheet 26: ATE Comparison -- Multiple estimators side by side
* Demonstrates: effecttab with multiple collected teffects models + models()
collect clear
collect: teffects ipw (cv_event) (treated index_age female i.education ///
    diabetes hypertension anxiety), ate
collect: teffects aipw (cv_event index_age female i.education ///
    diabetes hypertension anxiety) (treated index_age female i.education ///
    diabetes hypertension anxiety), ate

effecttab, xlsx("`main_xlsx'") sheet("ATE Comparison") ///
    effect("ATE") models("IPW \ AIPW") ///
    title("Table 7. Treatment Effect Estimates -- IPW vs AIPW") ///
    tlabels(0 "SSRI" 1 "SNRI") zebra ///
    footnote("IPW = inverse probability weighting. AIPW = augmented IPW (doubly robust).")

**# Sheet 27: Margins -- Predicted probabilities
quietly logit cv_event treated##c.index_age female i.education ///
    diabetes hypertension
collect clear
collect: margins treated, post

effecttab, xlsx("`main_xlsx'") sheet("Margins") ///
    type(margins) effect("Pr(CV Event)") ///
    title("Table 8. Predicted Probability of CV Event by Treatment")

**# Sheet 28: Margins AME -- Average marginal effects
* Demonstrates: effecttab with margins dydx() for average marginal effects
quietly logit cv_event treated index_age female i.education ///
    diabetes hypertension anxiety prior_cvd
collect clear
collect: margins, dydx(treated index_age female diabetes hypertension) post

effecttab, xlsx("`main_xlsx'") sheet("Margins AME") ///
    type(margins) effect("AME") ///
    title("Table 9. Average Marginal Effects on CV Event Risk") ///
    footnote("AME = average marginal effect. Change in Pr(CV event) per unit change in covariate.")


**# Sheet 29: Rates -- Incidence rates with rate ratios + multiple exposure strata
* Demonstrates: stratetab rateratio, ratiodigits(), explabels(), multiple strata
* Create synthetic strate output: 2 outcomes x 2 strata = 4 files

* Stratum 1: Male patients (SSRI vs SNRI)
preserve
clear
input str20 drug_class _D _Y double(_Rate _Lower _Upper)
"SSRI"   178 28100 0.00633 0.00545 0.00734
"SNRI"   161 22300 0.00722 0.00616 0.00844
end
save "`pkg_dir'/_strate_cv_m.dta", replace

clear
input str20 drug_class _D _Y double(_Rate _Lower _Upper)
"SSRI"    52 28100 0.00185 0.00139 0.00243
"SNRI"    58 22300 0.00260 0.00199 0.00337
end
save "`pkg_dir'/_strate_sh_m.dta", replace

* Stratum 2: Female patients (SSRI vs SNRI -- same row categories)
clear
input str20 drug_class _D _Y double(_Rate _Lower _Upper)
"SSRI"   134 24380 0.00550 0.00462 0.00652
"SNRI"   128 19520 0.00656 0.00549 0.00781
end
save "`pkg_dir'/_strate_cv_f.dta", replace

clear
input str20 drug_class _D _Y double(_Rate _Lower _Upper)
"SSRI"    35 24380 0.00144 0.00100 0.00200
"SNRI"    36 19520 0.00184 0.00129 0.00256
end
save "`pkg_dir'/_strate_sh_f.dta", replace
restore

stratetab, using("`pkg_dir'/_strate_cv_m" "`pkg_dir'/_strate_sh_m" "`pkg_dir'/_strate_cv_f" "`pkg_dir'/_strate_sh_f") ///
    xlsx("`main_xlsx'") outcomes(2) sheet("Rates") ///
    outlabels("CV Events \ Self-Harm") ///
    explabels("Male \ Female") ///
    rateratio ratiodigits(2) zebra ///
    title("Table 12. Incidence Rates per 1,000 Person-Years by Sex") ///
    footnote("IRR = incidence rate ratio, Female vs Male. CI by log-normal method.")

capture erase "`pkg_dir'/_strate_cv_m.dta"
capture erase "`pkg_dir'/_strate_sh_m.dta"
capture erase "`pkg_dir'/_strate_cv_f.dta"
capture erase "`pkg_dir'/_strate_sh_f.dta"


**# Sheet 30: Correlation -- Pearson with stars (lower triangle)
use `analysis', clear
corrtab index_age crp prior_hosp, ///
    xlsx("`main_xlsx'") sheet("Correlation") ///
    title("Table 13. Pearson Correlation Matrix") ///
    star(0.05 0.01 0.001)

**# Sheet 31: Correlation Spearman -- Spearman with p-values
corrtab index_age crp prior_hosp, ///
    xlsx("`main_xlsx'") sheet("Correlation Spear") ///
    title("Table 14. Spearman Rank Correlation Matrix") ///
    spearman pvalues

**# Sheet 32: Correlation Full -- Pearson full matrix (all cells)
* Demonstrates: corrtab full option showing complete matrix instead of triangle
corrtab index_age crp prior_hosp, ///
    xlsx("`main_xlsx'") sheet("Correlation Full") ///
    title("Table 15. Pearson Correlation Matrix (Full)") ///
    full star(0.05 0.01 0.001)


**# Sheet 33: Cross-Tabulation -- 2x2 with Fisher's exact + OR
crosstab treated female, ///
    xlsx("`main_xlsx'") sheet("Cross-Tabulation") ///
    title("Table 16. Treatment by Sex") ///
    exact or label

**# Sheet 34: Cross-Tab Measures -- Risk ratio and risk difference
* Demonstrates: crosstab rr, rd for 2x2 table
crosstab treated cv_event, ///
    xlsx("`main_xlsx'") sheet("Cross-Tab Measures") ///
    title("Table X. Treatment-Outcome Association Measures") ///
    rr rd label ///
    footnote("RR = risk ratio; RD = risk difference with 95% CI.")

**# Sheet 35: Cross-Tab Styled -- boldp() + zebra
* Demonstrates: crosstab boldp(), zebra, and trend on a valid ordinal table
preserve
clear
input byte outcome byte exposure int freq
0 0 25
1 0 5
0 1 15
1 1 15
0 2 5
1 2 25
end
expand freq
label define demo_outcome 0 "No event" 1 "Event", replace
label values outcome demo_outcome
label define demo_exposure 0 "Low" 1 "Medium" 2 "High", replace
label values exposure demo_exposure

crosstab outcome exposure, ///
    xlsx("`main_xlsx'") sheet("Cross-Tab Styled") ///
    title("Table X. Outcome by Ordinal Exposure") ///
    trend label boldp(0.05) zebra ///
    footnote("Significant chi-squared and trend rows are bolded when p < 0.05.")
restore

**# Sheet 36: Cross-Tab Trend -- Cochran-Armitage trend test
* Demonstrates: crosstab trend for ordinal exposure variable
crosstab education cv_event, ///
    xlsx("`main_xlsx'") sheet("Cross-Tab Trend") ///
    title("Table X. CV Events by Education Level (Trend Test)") ///
    trend label zebra

**# Sheet 37: Cross-Tab Row Pct -- Row percentages instead of column
* Demonstrates: crosstab rowpct for row-based percentage display
crosstab treated cv_event, ///
    xlsx("`main_xlsx'") sheet("Cross-Tab Row Pct") ///
    title("Table X. Treatment-Outcome (Row Percentages)") ///
    rowpct or label ///
    footnote("Percentages are row percentages within each treatment group.")


**# Sheet 38: Diagnostic -- Sensitivity/specificity from propensity model
quietly logit cv_event treated index_age female diabetes hypertension
predict double phat, pr
label variable phat "Predicted CV risk"

diagtab phat cv_event, cutoff(0.35) ///
    xlsx("`main_xlsx'") sheet("Diagnostic") ///
    title("Table 17. Diagnostic Accuracy of Risk Prediction Model") ///
    auc optimal wilson

**# Sheet 39: Diagnostic Prevalence -- Prevalence-adjusted PPV/NPV
* Demonstrates: diagtab prevalence() for population-level PPV/NPV adjustment
diagtab phat cv_event, cutoff(0.35) ///
    xlsx("`main_xlsx'") sheet("Diag Prevalence") ///
    title("Table X. Diagnostic Accuracy (Prevalence-Adjusted)") ///
    prevalence(0.15) auc wilson ///
    footnote("PPV and NPV adjusted to population prevalence of 15%.")

**# Sheet 40: Diagnostic Multi-Cut -- Multiple cutoff thresholds
* Demonstrates: diagtab cutoffs() for comparing sensitivity/specificity across thresholds
diagtab phat cv_event, cutoffs(0.30 0.32 0.34 0.36 0.38 0.40) ///
    xlsx("`main_xlsx'") sheet("Diag Multi-Cut") ///
    title("Table X. Diagnostic Accuracy Across Multiple Cutoffs") ///
    wilson ///
    footnote("Sensitivity and specificity shown at each probability threshold.")

drop phat

**# Sheet 41: Survival -- Kaplan-Meier table with median
stset follow_up, failure(cv_event)
survtab, times(365 730 1095 1460) by(treated) ///
    xlsx("`main_xlsx'") sheet("Survival") ///
    title("Table 18. Kaplan-Meier Survival Estimates") ///
    median timeunit(days) ///
    footnote("Survival probabilities estimated by Kaplan-Meier method.")

**# Sheet 42: Survival RMST -- RMST + risk set + between-group difference
* Demonstrates: survtab rmst(), riskset, difference
survtab, times(365 730 1095 1460) by(treated) ///
    rmst(1460) riskset difference ///
    xlsx("`main_xlsx'") sheet("Survival RMST") ///
    title("Table X. Survival with RMST and Group Differences") ///
    median timeunit(days) ///
    footnote("RMST = restricted mean survival time truncated at 1460 days.")

**# Sheet 43: Cumulative Incidence -- Reverse survival function
* Demonstrates: survtab reverse (1 - S(t)) + theme(apa)
survtab, times(365 730 1095 1460) by(treated) ///
    reverse ///
    xlsx("`main_xlsx'") sheet("Cumul Incidence") ///
    title("Table X. Cumulative Incidence of CV Events") ///
    timeunit(days) theme(apa)


**# Sheet 44: Theme BMJ -- BMJ journal formatting
* Demonstrates: theme(bmj) applied to table1_tc
use `analysis', clear
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ female bin \ ///
         education cat \ diabetes bin \ hypertension bin \ ///
         anxiety bin \ prior_cvd bin) ///
    smd ///
    theme(bmj) ///
    title("Table 1. Baseline Characteristics (BMJ Style)") ///
    excel("`main_xlsx'") sheet("Theme BMJ")

**# Sheet 45: Theme APA -- APA formatting
* Demonstrates: theme(apa) applied to table1_tc
table1_tc, by(treated) ///
    vars(index_age contn %5.1f \ female bin \ ///
         education cat \ diabetes bin \ hypertension bin \ ///
         anxiety bin \ prior_cvd bin) ///
    smd ///
    theme(apa) ///
    title("Table 1. Baseline Characteristics (APA Style)") ///
    excel("`main_xlsx'") sheet("Theme APA")

**# Sheet 46: HR Composite -- hrcomptab final Table 2-style survival composite
tempfile rate11 rate12 rate13 rate21 rate22 rate23

* Binary HRT scaffold rows
clear
input byte exposure double(_D _Y _Rate _Lower _Upper)
0 42 5200 0.00808 0.00610 0.01069
1 31 4980 0.00622 0.00436 0.00887
end
label define _hrc_bin 0 "No HRT" 1 "Any HRT", replace
label values exposure _hrc_bin
save "`rate11'.dta", replace

clear
input byte exposure double(_D _Y _Rate _Lower _Upper)
0 19 5310 0.00358 0.00228 0.00563
1 12 5040 0.00238 0.00135 0.00419
end
label define _hrc_bin2 0 "No HRT" 1 "Any HRT", replace
label values exposure _hrc_bin2
save "`rate12'.dta", replace

clear
input byte exposure double(_D _Y _Rate _Lower _Upper)
0 88 5150 0.01709 0.01384 0.02110
1 67 4895 0.01369 0.01062 0.01763
end
label define _hrc_bin3 0 "No HRT" 1 "Any HRT", replace
label values exposure _hrc_bin3
save "`rate13'.dta", replace

* Dose category scaffold rows
clear
input byte exposure double(_D _Y _Rate _Lower _Upper)
0 42 5200 0.00808 0.00610 0.01069
1 16 1760 0.00909 0.00557 0.01484
2 9 1510 0.00596 0.00310 0.01145
3 6 1710 0.00351 0.00158 0.00781
end
label define _hrc_dose 0 "No HRT" 1 "Low dose" 2 "Medium dose" 3 "High dose", replace
label values exposure _hrc_dose
save "`rate21'.dta", replace

clear
input byte exposure double(_D _Y _Rate _Lower _Upper)
0 19 5310 0.00358 0.00228 0.00563
1 7 1805 0.00388 0.00185 0.00814
2 3 1535 0.00195 0.00063 0.00603
3 2 1700 0.00118 0.00029 0.00471
end
label define _hrc_dose2 0 "No HRT" 1 "Low dose" 2 "Medium dose" 3 "High dose", replace
label values exposure _hrc_dose2
save "`rate22'.dta", replace

clear
input byte exposure double(_D _Y _Rate _Lower _Upper)
0 88 5150 0.01709 0.01384 0.02110
1 31 1740 0.01782 0.01253 0.02533
2 21 1495 0.01405 0.00917 0.02154
3 15 1660 0.00904 0.00545 0.01499
end
label define _hrc_dose3 0 "No HRT" 1 "Low dose" 2 "Medium dose" 3 "High dose", replace
label values exposure _hrc_dose3
save "`rate23'.dta", replace

stratetab, using(`rate11' `rate12' `rate13' `rate21' `rate22' `rate23') ///
    outcomes(3) frame(_demo_hr_rates, replace) ///
    outlabels("Sustained EDSS 4" \ "Sustained EDSS 6" \ "Recurring Relapse") ///
    explabels("Any HRT" \ "Estrogen Dose")

* Binary HRT model frame: one non-reference row
clear
set seed 20260417
set obs 360
gen int id = _n
gen byte hrt = runiform() < 0.38
gen double age = rnormal(57, 8)
gen byte female = runiform() < 0.78
gen byte education = ceil(runiform() * 3)
gen double time = ceil(runiform() * 1825)
gen byte edss4 = runiform() < invlogit(-2.7 - 0.35 * hrt + 0.02 * (age - 55))
gen byte edss6 = runiform() < invlogit(-3.4 - 0.40 * hrt + 0.02 * (age - 55))
gen byte relapse = runiform() < invlogit(-1.6 - 0.28 * hrt + 0.01 * (age - 55))

collect clear
stset time, failure(edss4) id(id)
collect: stcox hrt c.age i.female i.education, nolog
stset time, failure(edss6) id(id)
collect: stcox hrt c.age i.female i.education, nolog
stset time, failure(relapse) id(id)
collect: stcox hrt c.age i.female i.education, nolog
regtab, frame(_demo_hr_bin, replace) noint coef("HR")

* Dose category model frame: three non-reference rows after header + reference
clear
set obs 420
gen int id = _n
gen byte dosecat = floor(runiform() * 4)
gen double age = rnormal(57, 8)
gen byte female = runiform() < 0.78
gen byte education = ceil(runiform() * 3)
gen double time = ceil(runiform() * 1825)
gen byte edss4 = runiform() < invlogit(-2.7 - 0.12 * (dosecat == 1) - 0.30 * (dosecat == 2) - 0.48 * (dosecat == 3) + 0.02 * (age - 55))
gen byte edss6 = runiform() < invlogit(-3.5 - 0.10 * (dosecat == 1) - 0.26 * (dosecat == 2) - 0.44 * (dosecat == 3) + 0.02 * (age - 55))
gen byte relapse = runiform() < invlogit(-1.6 - 0.08 * (dosecat == 1) - 0.20 * (dosecat == 2) - 0.34 * (dosecat == 3) + 0.01 * (age - 55))

collect clear
stset time, failure(edss4) id(id)
collect: stcox i.dosecat c.age i.female i.education, nolog
stset time, failure(edss6) id(id)
collect: stcox i.dosecat c.age i.female i.education, nolog
stset time, failure(relapse) id(id)
collect: stcox i.dosecat c.age i.female i.education, nolog
regtab, frame(_demo_hr_dose, replace) noint coef("HR")

hrcomptab _demo_hr_rates, modelframes(_demo_hr_bin _demo_hr_dose) ///
    rows(1 \ 3/5) ///
    xlsx("`main_xlsx'") sheet("HR Composite") ///
    effect("aHR") zebra headershade ///
    title("Table X. Hormone Therapy Events, Person-Years, and Adjusted Hazard Ratios") ///
    footnote("Demo of hrcomptab. The stratetab frame supplies events, person-years, and rates; selected regtab rows supply adjusted hazard ratios and p-values.")

capture frame drop _demo_hr_rates
capture frame drop _demo_hr_bin
capture frame drop _demo_hr_dose

**# Cleanup
clear
display as result "Demo complete. Outputs:"
display as result "  `pkg_dir'/console_output.smcl"
display as result "  `pkg_dir'/demo_tabtools.xlsx (46 sheets)"
local _demo_success "1"
}
local _rc = _rc
if "`_demo_success'" == "1" local _rc = 0
capture log close demo
set scheme `_orig_scheme'
set linesize `_orig_linesize'
set varabbrev `_orig_varabbrev'
set more `_orig_more'
if `_rc' exit `_rc'
