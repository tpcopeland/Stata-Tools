*! cci_se Version 1.4.0  2026/06/15
*! Swedish Charlson Comorbidity Index using ICD-7 through ICD-10
*! Based on Ludvigsson et al. Clinical Epidemiology 2021;13:21-41
*! Part of the setools package
*! Author: Timothy P Copeland, Karolinska Institutet
*!
*! Description:
*!   Computes the Swedish adaptation of the Charlson Comorbidity Index
*!   from diagnosis-level (long format) registry data. Supports ICD-7
*!   through ICD-10 codes as used in Swedish national health registries.
*!   Handles ICD codes with or without separators: dots and Swedish comma
*!   decimals are stripped, so "412.01", "412,01", and "41201" all match.
*!   Accepts date variables as Stata dates, YYYYMMDD integers, or strings.
*!
*! v1.2.3: restrict dual ICD-9/ICD-10 matching to the 1997 overlap year
*! v1.2.0: dates option — earliest diagnosis date per comorbidity component
*! v1.1.0: Mata hash-table engine replaces 70+ regex passes with single-pass
*!         prefix lookup. Same output, dramatically faster on large datasets.

program define cci_se, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax [if] [in], ID(varname) ICD(varlist) ///
        DATE(varname) ///
        [GENerate(name) COMPonents DATEs PREFIX(string) ///
         DATEFormat(string) INDEXDate(varname) LOOKback(integer -1) NOIsily]

    * ---------------------------------------------------------------
    * Defaults
    * ---------------------------------------------------------------
    if "`generate'" == "" local generate "charlson"
    if "`prefix'" == "" local prefix "cci_"

    * ---------------------------------------------------------------
    * Validate inputs
    * ---------------------------------------------------------------
    marksample touse, novarlist

    local icd_vars `icd'
    foreach icd_var of local icd_vars {
        capture confirm string variable `icd_var'
        if _rc {
            display as error "icd() must contain one or more string diagnosis variables"
            exit 109
        }
    }

    * Determine date variable type (string vs numeric)
    local date_is_str = 0
    capture confirm string variable `date'
    if !_rc {
        local date_is_str = 1
    }

    * Validate dateformat option against date variable type
    if "`dateformat'" != "" {
        local dateformat = lower("`dateformat'")
        if !inlist("`dateformat'", "stata", "yyyymmdd", "ymd") {
            display as error "dateformat() must be: stata, yyyymmdd, or ymd"
            display as error "  stata    = Stata date (numeric, days since 01jan1960)"
            display as error "  yyyymmdd = YYYYMMDD integer or string (e.g., 20200115)"
            display as error "  ymd      = YYYY-MM-DD string (e.g., 2020-01-15)"
            exit 198
        }
    }
    else if `date_is_str' {
        local dateformat "yyyymmdd"
    }
    else {
        local dateformat "stata"
    }

    if `date_is_str' & "`dateformat'" == "stata" {
        display as error "dateformat(stata) requires a numeric Stata date variable"
        exit 198
    }
    if !`date_is_str' & "`dateformat'" == "ymd" {
        display as error "dateformat(ymd) requires a string date variable"
        exit 198
    }
    if !`date_is_str' & "`dateformat'" == "stata" {
        local _cci_date_fmt : format `date'
        if lower(substr("`_cci_date_fmt'", 1, 3)) != "%td" {
            display as error "date() must be a Stata daily date variable when dateformat(stata) is used"
            exit 109
        }
        quietly count if `touse' & !missing(`date') & `date' != floor(`date')
        if r(N) > 0 {
            display as error "date() must contain whole-number Stata daily dates when dateformat(stata) is used"
            exit 109
        }
    }

    * Mark out missing IDs before patient-level collapse
    capture confirm string variable `id'
    if !_rc {
        quietly replace `touse' = 0 if trim(`id') == "" & `touse'
    }
    else {
        markout `touse' `id'
    }

    * Mark out missing dates
    if `date_is_str' {
        quietly replace `touse' = 0 if trim(`date') == "" & `touse'
    }
    else {
        markout `touse' `date'
    }

    quietly count if `touse'
    if r(N) == 0 error 2000

    * Validate lookback-windowing options
    if "`indexdate'" != "" {
        capture confirm numeric variable `indexdate'
        if _rc {
            display as error "indexdate() must be a numeric Stata daily date variable"
            exit 109
        }
        local _cci_ix_fmt : format `indexdate'
        if lower(substr("`_cci_ix_fmt'", 1, 3)) != "%td" {
            display as error "indexdate() must be a Stata daily date variable with %td format"
            exit 109
        }
        quietly count if `touse' & !missing(`indexdate') & `indexdate' != floor(`indexdate')
        if r(N) > 0 {
            display as error "indexdate() must contain whole-number Stata daily dates"
            exit 109
        }
    }
    if `lookback' != -1 {
        if "`indexdate'" == "" {
            display as error "lookback() requires indexdate()"
            exit 198
        }
        if `lookback' < 1 {
            display as error "lookback() must be a positive integer (days)"
            exit 198
        }
    }

    if "`generate'" == "`id'" {
        display as error "generate() name cannot be same as id() variable"
        exit 198
    }

    if "`components'" != "" {
        local _pfxlen = strlen("`prefix'")
        if substr("`generate'", 1, `_pfxlen') == "`prefix'" {
            display as error "generate() name conflicts with component variable prefix"
            exit 198
        }
    }

    * ---------------------------------------------------------------
    * Preserve and prepare data
    * ---------------------------------------------------------------
    preserve

    quietly keep if `touse'

    * Normalize one or more ICD code fields: uppercase, strip BOTH dot and
    * Swedish comma decimal separators (so "412.01", "412,01", and "41201" all
    * match the comma-free hash keys), space-separate codes for tokenizing.
    tempvar code yr parsed_date
    quietly gen strL `code' = ""
    foreach icd_var of local icd_vars {
        quietly replace `code' = `code' + " " + ///
            upper(subinstr(subinstr(trim(`icd_var'), ".", "", .), ",", "", .)) ///
            if trim(`icd_var') != ""
    }

    * ---------------------------------------------------------------
    * Extract year from date according to validated dateformat()
    * ---------------------------------------------------------------
    if "`dateformat'" == "ymd" {
        * Strict YYYY-MM-DD string parsing
        tempvar _cci_date_trim
        quietly gen str20 `_cci_date_trim' = trim(`date')
        quietly gen double `parsed_date' = daily(`_cci_date_trim', "YMD") ///
            if regexm(`_cci_date_trim', ///
                "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$")
    }
    else if "`dateformat'" == "yyyymmdd" {
        tempvar _cci_date_clean _cci_date_std
        quietly gen str20 `_cci_date_clean' = ""
        if `date_is_str' {
            * Strip separators before parsing string YYYYMMDD dates
            quietly replace `_cci_date_clean' = ///
                subinstr(subinstr(trim(`date'), "-", "", .), "/", "", .) ///
                if trim(`date') != ""
        }
        else {
            quietly count if !missing(`date') & `date' != floor(`date')
            if r(N) > 0 {
                display as error "date() must contain whole-number YYYYMMDD values when dateformat(yyyymmdd) is used"
                restore
                exit 109
            }
            * Numeric YYYYMMDD format
            quietly replace `_cci_date_clean' = trim(strofreal(`date', "%20.0f")) ///
                if !missing(`date')
        }
        quietly gen str10 `_cci_date_std' = ""
        quietly replace `_cci_date_std' = ///
            substr(`_cci_date_clean', 1, 4) + "-" + ///
            substr(`_cci_date_clean', 5, 2) + "-" + ///
            substr(`_cci_date_clean', 7, 2) ///
            if regexm(`_cci_date_clean', ///
                "^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$")
        quietly gen double `parsed_date' = daily(`_cci_date_std', "YMD")
    }
    else {
        * Numeric Stata date format
        quietly gen double `parsed_date' = `date'
    }
    quietly gen int `yr' = year(`parsed_date') if !missing(`parsed_date')

    * Validate year extraction
    quietly count if missing(`parsed_date')
    if r(N) > 0 {
        local n_bad = r(N)
        display as text "Warning: `n_bad' observations with unparseable dates (dropped)"
        quietly drop if missing(`parsed_date')
    }

    * Restrict diagnoses to the lookback window before the index date.
    * indexdate() alone excludes post-index diagnoses (avoids immortal-time /
    * post-index contamination); adding lookback() also sets a lower bound at
    * indexdate - lookback days. Rows with missing indexdate cannot be windowed.
    local N_excluded_window = 0
    if "`indexdate'" != "" {
        quietly count
        local _n_prewin = r(N)
        quietly count if missing(`indexdate')
        local _n_missix = r(N)
        if `_n_missix' > 0 {
            display as text "Note: `_n_missix' observations with missing indexdate() dropped"
            quietly drop if missing(`indexdate')
        }
        quietly drop if `parsed_date' > `indexdate'
        if `lookback' != -1 {
            quietly drop if `parsed_date' < `indexdate' - `lookback'
        }
        quietly count
        local N_excluded_window = `_n_prewin' - r(N)
    }

    quietly count
    if r(N) == 0 {
        display as error "No valid observations after date parsing"
        restore
        exit 2000
    }
    local N_input = r(N)

    * Count diagnosis rows carrying at least one ICD code (for the zero-match
    * smell diagnostic emitted after classification).
    quietly count if trim(`code') != ""
    local _cci_n_withcodes = r(N)

    * dates implies components
    if "`dates'" != "" & "`components'" == "" {
        local components "components"
    }

    * ---------------------------------------------------------------
    * Initialize 19 comorbidity indicators
    * ---------------------------------------------------------------
    forvalues i = 1/19 {
        capture confirm variable _cci_`i'
        if !_rc {
            display as error "Variables named _cci_* already exist in dataset"
            display as error "Drop or rename them before running cci_se"
            restore
            exit 110
        }
    }
    forvalues i = 1/19 {
        quietly gen byte _cci_`i' = 0
    }

    * Initialize date variables when dates option is specified
    local _do_dates = 0
    if "`dates'" != "" {
        local _do_dates = 1
        forvalues i = 1/19 {
            quietly gen double _cci_d_`i' = .
        }
    }

    * ---------------------------------------------------------------
    * Match ICD codes via Mata hash-table engine (single pass)
    * ---------------------------------------------------------------
    mata: _cci_se_classify("`code'", "`yr'", "`parsed_date'", `_do_dates')

    * ---------------------------------------------------------------
    * Collapse to patient level (max of each indicator, min of dates)
    * ---------------------------------------------------------------
    if `_do_dates' {
        collapse (max) _cci_1-_cci_19 (min) _cci_d_1-_cci_d_19, by(`id')
    }
    else {
        collapse (max) _cci_*, by(`id')
    }

    * Replace missing with 0 (patients with no matches in any component)
    forvalues i = 1/19 {
        quietly replace _cci_`i' = 0 if missing(_cci_`i')
    }

    * ---------------------------------------------------------------
    * Apply hierarchy rules
    * ---------------------------------------------------------------

    * Liver: mild + ascites -> moderate/severe; clear mild if severe
    quietly replace _cci_15 = 1 if _cci_13 > 0 & _cci_14 > 0
    quietly replace _cci_13 = 0 if _cci_15 > 0

    * Diabetes: clear uncomplicated if complicated present
    quietly replace _cci_10 = 0 if _cci_11 > 0

    * Cancer: clear non-metastatic if metastatic present
    quietly replace _cci_17 = 0 if _cci_18 > 0

    * Apply same hierarchy to dates
    if `_do_dates' {
        quietly replace _cci_d_15 = min(_cci_d_15, max(_cci_d_13, _cci_d_14)) ///
            if !missing(_cci_d_13) & !missing(_cci_d_14) & !missing(_cci_d_15)
        quietly replace _cci_d_15 = max(_cci_d_13, _cci_d_14) ///
            if !missing(_cci_d_13) & !missing(_cci_d_14) & missing(_cci_d_15)
        quietly replace _cci_d_13 = . if _cci_15 > 0
        quietly replace _cci_d_10 = . if _cci_11 > 0
        quietly replace _cci_d_17 = . if _cci_18 > 0
    }

    * ---------------------------------------------------------------
    * Compute weighted Charlson score
    * Weights: most=1, hemiplegia/diabcomp/renal/cancer=2,
    *          liver severe=3, metastatic/AIDS=6
    * ---------------------------------------------------------------
    quietly gen int `generate' = ///
        _cci_1 + _cci_2 + _cci_3 + _cci_4 + _cci_5 + _cci_6 + ///
        _cci_7 + _cci_8 + 2*_cci_9 + _cci_10 + 2*_cci_11 + ///
        2*_cci_12 + _cci_13 + 3*_cci_15 + _cci_16 + ///
        2*_cci_17 + 6*_cci_18 + 6*_cci_19
    label variable `generate' "Charlson Comorbidity Index (Ludvigsson 2021)"

    * ---------------------------------------------------------------
    * Label and rename component variables
    * ---------------------------------------------------------------
    local name_1  "mi"
    local name_2  "chf"
    local name_3  "pvd"
    local name_4  "cevd"
    local name_5  "copd"
    local name_6  "pulm"
    local name_7  "rheum"
    local name_8  "dem"
    local name_9  "plegia"
    local name_10 "diab"
    local name_11 "diabcomp"
    local name_12 "renal"
    local name_13 "livmild"
    local name_15 "livsev"
    local name_16 "pud"
    local name_17 "cancer"
    local name_18 "mets"
    local name_19 "aids"

    local lbl_1  "Myocardial infarction"
    local lbl_2  "Congestive heart failure"
    local lbl_3  "Peripheral vascular disease"
    local lbl_4  "Cerebrovascular disease"
    local lbl_5  "COPD"
    local lbl_6  "Other chronic pulmonary disease"
    local lbl_7  "Rheumatic disease"
    local lbl_8  "Dementia"
    local lbl_9  "Hemiplegia/paraplegia"
    local lbl_10 "Diabetes without complications"
    local lbl_11 "Diabetes with complications"
    local lbl_12 "Renal disease"
    local lbl_13 "Mild liver disease"
    local lbl_15 "Moderate/severe liver disease"
    local lbl_16 "Peptic ulcer disease"
    local lbl_17 "Cancer (non-metastatic)"
    local lbl_18 "Metastatic cancer"
    local lbl_19 "AIDS/HIV"

    if "`components'" != "" {
        foreach i in 1 2 3 4 5 6 7 8 9 10 11 12 13 15 16 17 18 19 {
            rename _cci_`i' `prefix'`name_`i''
            label variable `prefix'`name_`i'' "`lbl_`i''"
        }
        drop _cci_14
        if `_do_dates' {
            foreach i in 1 2 3 4 5 6 7 8 9 10 11 12 13 15 16 17 18 19 {
                rename _cci_d_`i' `prefix'`name_`i''_date
                format `prefix'`name_`i''_date %td
                label variable `prefix'`name_`i''_date "Earliest `lbl_`i'' diagnosis"
            }
            drop _cci_d_14
        }
    }
    else {
        drop _cci_*
    }

    * ---------------------------------------------------------------
    * Compute summary statistics for return values
    * ---------------------------------------------------------------
    quietly count
    local N_out = r(N)
    quietly count if `generate' > 0
    local N_any = r(N)
    quietly summarize `generate'
    local mean_cci = r(mean)
    local max_cci = r(max)

    * ---------------------------------------------------------------
    * Zero-match smell diagnostic: ICD codes were present in the input but
    * no patient matched any Charlson component. This catches separator/era
    * mismatches (the class of bug fixed in v1.3.0) before they produce a
    * silently all-zero index. Always shown; not gated by noisily.
    * ---------------------------------------------------------------
    if `_cci_n_withcodes' > 0 & `N_any' == 0 {
        display as text "Warning: `_cci_n_withcodes' diagnosis row(s) present but no patient matched any"
        display as text "  Charlson component (CCI = 0 for all `N_out' patients)."
        display as text "  Check the ICD code format (dot/comma separators are stripped automatically)"
        display as text "  and that date() spans the ICD era of your codes (ICD-7/8/9/10 by year)."
    }

    * ---------------------------------------------------------------
    * Display results
    * ---------------------------------------------------------------
    if "`noisily'" != "" {
        display as text ""
        display as text "{hline 60}"
        display as text "Swedish Charlson Comorbidity Index (Ludvigsson et al. 2021)"
        display as text "{hline 60}"
        display as text "Input observations:     " as result %12.0fc `N_input'
        if "`indexdate'" != "" {
            display as text "Excluded by window:     " as result %12.0fc `N_excluded_window'
        }
        display as text "Patients:               " as result %12.0fc `N_out'
        display as text "Patients with CCI > 0:  " as result %12.0fc `N_any'
        display as text "Mean CCI:               " as result %12.2f `mean_cci'
        display as text "Max CCI:                " as result %12.0f `max_cci'
        display as text "{hline 60}"

        if "`components'" != "" {
            display as text ""
            display as text "Component prevalence:"
            display as text "{hline 45}"
            foreach i in 1 2 3 4 5 6 7 8 9 10 11 12 13 15 16 17 18 19 {
                quietly count if `prefix'`name_`i'' > 0
                local n_comp = r(N)
                local pct : display %5.1f 100 * `n_comp' / `N_out'
                display as text "  `lbl_`i''" _column(36) as result %6.0fc `n_comp' as text " (" as result "`pct'" as text "%)"
            }
            display as text "{hline 45}"
        }
    }

    * ---------------------------------------------------------------
    * Keep modified data (discard preserved copy)
    * ---------------------------------------------------------------
    restore, not

    * ---------------------------------------------------------------
    * Return results
    * ---------------------------------------------------------------
    return scalar N_input    = `N_input'
    return scalar N_patients = `N_out'
    return scalar N_any      = `N_any'
    return scalar mean_cci   = `mean_cci'
    return scalar max_cci    = `max_cci'
    return scalar N_excluded_window = `N_excluded_window'
    if `lookback' != -1 {
        return scalar lookback = `lookback'
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* =====================================================================
* Mata engine: single-pass hash-table ICD classification
* =====================================================================
capture mata: mata drop _cci_se_classify()
capture mata: mata drop _cci_aa_multi()
capture mata: mata drop _cci_aa_range()
capture mata: mata drop _cci_lookup_token()

mata:
mata set matastrict on

void _cci_se_classify(string scalar code_var, string scalar yr_var,
                      string scalar date_var, real scalar do_dates)
{
    real scalar    N, i, j, yr, ntok, dt
    string scalar  raw
    string vector  toks
    real matrix    indicators, dates
    real colvector yr_data, date_data

    transmorphic   ht7, ht8, ht9, ht10

    N = st_nobs()
    if (N == 0) return

    // ---------------------------------------------------------------
    // Build hash tables: prefix -> comorbidity index (1-19)
    // Each ICD version gets its own associative array.
    // Keys are the exact prefix strings from Ludvigsson et al. 2021.
    // ---------------------------------------------------------------
    ht7  = asarray_create()
    ht8  = asarray_create()
    ht9  = asarray_create()
    ht10 = asarray_create()

    // --- 1. Myocardial infarction ---
    asarray(ht7, "4201", 1)
    _cci_aa_multi(ht8, "410 411 412,01 412,91", 1)
    _cci_aa_multi(ht9, "410 412", 1)
    _cci_aa_multi(ht10, "I21 I22 I252", 1)

    // --- 2. Congestive heart failure ---
    _cci_aa_multi(ht7, "422,21 422,22 434,1 434,2", 2)
    _cci_aa_multi(ht8, "425,08 425,09 427,0 427,1 428", 2)
    _cci_aa_multi(ht9, "402A 402B 402X 404A 404B 404X 425E 425F 425H 425W 425X 428", 2)
    _cci_aa_multi(ht10, "I110 I130 I132 I255 I420 I426 I427 I428 I429 I43 I50", 2)

    // --- 3. Peripheral vascular disease ---
    _cci_aa_multi(ht7, "450,1 451 453", 3)
    _cci_aa_multi(ht8, "440 441 443,1 443,9", 3)
    _cci_aa_multi(ht9, "440 441 443B 443X 447B 557", 3)
    _cci_aa_multi(ht10, "I70 I71 I731 I738 I739 I771 I790 I792 K55", 3)

    // --- 4. Cerebrovascular disease ---
    _cci_aa_multi(ht7, "330 331 332 333 334", 4)
    _cci_aa_multi(ht8, "430 431 432 433 434 435 436 437 438", 4)
    _cci_aa_multi(ht9, "430 431 432 433 434 435 436 437 438", 4)
    _cci_aa_multi(ht10, "G45 I60 I61 I62 I63 I64 I67 I69", 4)

    // --- 5. COPD ---
    _cci_aa_multi(ht7, "502 527,1", 5)
    _cci_aa_multi(ht8, "491 492", 5)
    _cci_aa_multi(ht9, "491 492 496", 5)
    _cci_aa_multi(ht10, "J43 J44", 5)

    // --- 6. Other chronic pulmonary disease ---
    _cci_aa_multi(ht7, "241 501 523 524 525 526", 6)
    _cci_aa_multi(ht8, "490 493 515 516 517 518", 6)
    _cci_aa_multi(ht9, "490 493 494 495 500 501 502 503 504 505 506 507 508 516 517", 6)
    _cci_aa_multi(ht10, "J41 J42 J45 J46 J47 J60 J61 J62 J63 J64 J65 J66 J67 J68 J69 J70", 6)

    // --- 7. Rheumatic disease ---
    _cci_aa_multi(ht7, "722,00 722,01 722,10 722,20 722,23 456,0 456,1 456,2 456,3", 7)
    _cci_aa_multi(ht8, "446 696 712,0 712,1 712,2 712,3 712,5 716 734,0 734,1 734,9", 7)
    _cci_aa_multi(ht9, "446 696A 710A 710B 710C 710D 710E 714 719D 720 725", 7)
    _cci_aa_multi(ht10, "M05 M06 M123 M070 M071 M072 M073 M08 M13 M30 M313 M314 M315 M316 M32 M33 M34 M350 M351 M353 M45 M46", 7)

    // --- 8. Dementia ---
    _cci_aa_multi(ht7, "304 305", 8)
    asarray(ht8, "290", 8)
    _cci_aa_multi(ht9, "290 294B 331A 331B 331C 331X", 8)
    _cci_aa_multi(ht10, "F00 F01 F02 F03 F051 G30 G311 G319", 8)

    // --- 9. Hemiplegia/paraplegia ---
    _cci_aa_multi(ht7, "351 352 357,00", 9)
    _cci_aa_multi(ht8, "343 344", 9)
    _cci_aa_multi(ht9, "342 343 344A 344B 344C 344D 344E 344F", 9)
    _cci_aa_multi(ht10, "G114 G80 G81 G82 G830 G831 G832 G833 G838", 9)

    // --- 10. Diabetes without complications ---
    asarray(ht7, "26009", 10)
    _cci_aa_multi(ht8, "250,00 250,07 250,08", 10)
    _cci_aa_multi(ht9, "250A 250B 250C", 10)
    _cci_aa_multi(ht10, "E100 E101 E106 E109 E110 E111 E119 E120 E121 E129 E130 E131 E139 E140 E141 E149", 10)

    // --- 11. Diabetes with complications ---
    _cci_aa_multi(ht7, "260,2 260,21 260,29 260,3 260,4 260,49 260,99", 11)
    _cci_aa_multi(ht8, "250,01 250,02 250,03 250,04 250,05", 11)
    _cci_aa_multi(ht9, "250D 250E 250F 250G", 11)
    _cci_aa_multi(ht10, "E102 E103 E104 E105 E107 E112 E113 E114 E115 E116 E117 E122 E123 E124 E125 E126 E127 E132 E133 E134 E135 E136 E137 E142 E143 E144 E145 E146 E147", 11)

    // --- 12. Renal disease ---
    _cci_aa_multi(ht7, "592 593 792", 12)
    _cci_aa_multi(ht8, "582 583 584 792 593,00 403,99 404,99 792,99 Y29,01", 12)
    _cci_aa_multi(ht9, "403A 403B 403X 582 583 585 586 588A V42A V45B V56", 12)
    _cci_aa_multi(ht10, "I120 I131 N032 N033 N034 N035 N036 N037 N052 N053 N054 N055 N056 N057 N11 N18 N19 N250 Q611 Q612 Q613 Q614 Z49 Z940 Z992", 12)

    // --- 13. Mild liver disease ---
    asarray(ht7, "581", 13)
    _cci_aa_multi(ht8, "070 571 573", 13)
    _cci_aa_multi(ht9, "070 571C 571E 571F 573", 13)
    _cci_aa_multi(ht10, "B15 B16 B17 B18 B19 K703 K709 K73 K746 K754", 13)

    // --- 14. Ascites (internal, for liver hierarchy) ---
    asarray(ht8, "7853", 14)
    asarray(ht9, "789F", 14)
    asarray(ht10, "R18", 14)

    // --- 15. Moderate/severe liver disease ---
    asarray(ht7, "4621", 15)
    _cci_aa_multi(ht8, "456,0 571,9 573,02", 15)
    _cci_aa_multi(ht9, "456A 456B 456C 572C 572D 572E", 15)
    _cci_aa_multi(ht10, "I850 I859 I982 I983", 15)

    // --- 16. Peptic ulcer disease ---
    _cci_aa_multi(ht7, "540 541 542", 16)
    _cci_aa_multi(ht8, "531 532 533 534", 16)
    _cci_aa_multi(ht9, "531 532 533 534", 16)
    _cci_aa_multi(ht10, "K25 K26 K27 K28", 16)

    // --- 17. Malignancy (non-metastatic) ---
    // ICD-7: 140-197, 200-204
    _cci_aa_range(ht7, "1", 40, 97, 17)
    _cci_aa_range(ht7, "2", 0, 4, 17)
    // ICD-8: 140-199, 200-209 (excl 173, 208)
    _cci_aa_range(ht8, "1", 40, 99, 17)
    _cci_aa_range(ht8, "2", 0, 9, 17)
    asarray_remove(ht8, "173")
    asarray_remove(ht8, "208")
    // ICD-9: 140-199, 200-208 (excl 173)
    _cci_aa_range(ht9, "1", 40, 99, 17)
    _cci_aa_range(ht9, "2", 0, 8, 17)
    asarray_remove(ht9, "173")
    // ICD-10: C00-C76, C81-C97 (excl C42, C44, C77-C80, C87)
    _cci_aa_range(ht10, "C", 0, 76, 17)
    _cci_aa_range(ht10, "C", 81, 97, 17)
    asarray_remove(ht10, "C42")
    asarray_remove(ht10, "C44")
    asarray_remove(ht10, "C87")  // C87 unallocated in WHO ICD-10; remove from C81-C97 range

    // --- 18. Metastatic cancer ---
    // ICD-7: 156,91 198 199
    asarray(ht7, "15691", 18)
    _cci_aa_multi(ht7, "198 199", 18)
    // ICD-8: 196-199
    _cci_aa_multi(ht8, "196 197 198 199", 18)
    // ICD-9: 196-199A 199B (196, 197, 198 as prefixes; 199A, 199B exact)
    _cci_aa_multi(ht9, "196 197 198 199A 199B", 18)
    // ICD-10: C77-C80
    _cci_aa_multi(ht10, "C77 C78 C79 C80", 18)

    // --- 19. AIDS/HIV ---
    _cci_aa_multi(ht9, "079J 279K", 19)
    _cci_aa_multi(ht10, "B20 B21 B22 B23 B24 F024 O987 R75 Z219 Z717", 19)

    // ---------------------------------------------------------------
    // Single-pass classification
    // st_sdata() for strL code column (row-by-row); st_view() for
    // numeric indicators (zero-copy direct write to Stata variables)
    // ---------------------------------------------------------------
    real scalar code_idx
    code_idx = st_varindex(code_var)

    st_view(indicators = ., ., "_cci_1 _cci_2 _cci_3 _cci_4 _cci_5 _cci_6 _cci_7 _cci_8 _cci_9 _cci_10 _cci_11 _cci_12 _cci_13 _cci_14 _cci_15 _cci_16 _cci_17 _cci_18 _cci_19")

    st_view(yr_data = ., ., yr_var)

    if (do_dates) {
        st_view(dates = ., ., "_cci_d_1 _cci_d_2 _cci_d_3 _cci_d_4 _cci_d_5 _cci_d_6 _cci_d_7 _cci_d_8 _cci_d_9 _cci_d_10 _cci_d_11 _cci_d_12 _cci_d_13 _cci_d_14 _cci_d_15 _cci_d_16 _cci_d_17 _cci_d_18 _cci_d_19")
        st_view(date_data = ., ., date_var)
    }

    for (i = 1; i <= N; i++) {
        yr = yr_data[i]
        if (yr >= .) continue

        raw = st_sdata(i, code_idx)
        if (raw == "") continue
        toks = tokens(strtrim(raw))
        ntok = cols(toks)

        if (do_dates) dt = date_data[i]

        // Determine ICD version(s) from year
        // 1997 overlaps v9 and v10 — must check both
        if (yr <= 1968) {
            for (j = 1; j <= ntok; j++) {
                _cci_lookup_token(ht7, toks[j], indicators, i, do_dates, dates, dt)
            }
        }
        else if (yr <= 1986) {
            for (j = 1; j <= ntok; j++) {
                _cci_lookup_token(ht8, toks[j], indicators, i, do_dates, dates, dt)
            }
        }
        else if (yr >= 1998) {
            for (j = 1; j <= ntok; j++) {
                _cci_lookup_token(ht10, toks[j], indicators, i, do_dates, dates, dt)
            }
        }
        else if (yr <= 1996) {
            for (j = 1; j <= ntok; j++) {
                _cci_lookup_token(ht9, toks[j], indicators, i, do_dates, dates, dt)
            }
        }
        else {
            // 1997 overlap period: check both v9 and v10
            for (j = 1; j <= ntok; j++) {
                _cci_lookup_token(ht9, toks[j], indicators, i, do_dates, dates, dt)
                _cci_lookup_token(ht10, toks[j], indicators, i, do_dates, dates, dt)
            }
        }
    }
}

// Helper: add multiple space-separated prefixes to an asarray.
// Commas (Swedish decimal separator) are stripped so keys are separator-free
// and match the comma/dot-stripped input tokens.
void _cci_aa_multi(transmorphic ht, string scalar prefixes, real scalar idx)
{
    string vector  toks
    real scalar    j

    toks = tokens(prefixes)
    for (j = 1; j <= cols(toks); j++) {
        asarray(ht, subinstr(toks[j], ",", ""), idx)
    }
}

// Helper: add a range of numeric 2-digit suffixes (with zero-pad) to a prefix
void _cci_aa_range(transmorphic ht, string scalar pfx, real scalar lo,
                   real scalar hi, real scalar idx)
{
    real scalar k
    for (k = lo; k <= hi; k++) {
        asarray(ht, pfx + strofreal(k, "%02.0f"), idx)
    }
}

// Core lookup: try progressively shorter prefixes of a token against hash table.
// When do_dates==1, also writes the visit date to the dates matrix.
void _cci_lookup_token(transmorphic ht, string scalar tok,
                       real matrix indicators, real scalar row,
                       real scalar do_dates, real matrix dates,
                       real scalar dt)
{
    real scalar   len, cci_idx, plen
    string scalar pfx

    len = strlen(tok)
    if (len == 0) return

    for (plen = len; plen >= 2; plen--) {
        pfx = substr(tok, 1, plen)
        if (asarray_contains(ht, pfx)) {
            cci_idx = asarray(ht, pfx)
            indicators[row, cci_idx] = 1
            if (do_dates) dates[row, cci_idx] = dt
            return
        }
    }
}

end
