*! cci_se Version 1.0.0  2026/02/18
*! Swedish Charlson Comorbidity Index using ICD-7 through ICD-10
*! Based on Ludvigsson et al. Clinical Epidemiology 2021;13:21-41
*! Part of the setools package
*!
*! Description:
*!   Computes the Swedish adaptation of the Charlson Comorbidity Index
*!   from diagnosis-level (long format) registry data. Supports ICD-7
*!   through ICD-10 codes as used in Swedish national health registries.
*!   Handles ICD codes with or without dots automatically.
*!   Accepts date variables as Stata dates, YYYYMMDD integers, or strings.

program define cci_se, rclass
    version 16.0
    set varabbrev off

    syntax [if] [in], ID(varname) ICD(varname string) ///
        DATE(varname) ///
        [GENerate(name) COMPonents PREFIX(string) ///
         DATEFormat(string) NOIsily]

    * ---------------------------------------------------------------
    * Defaults
    * ---------------------------------------------------------------
    if "`generate'" == "" local generate "charlson"
    if "`prefix'" == "" local prefix "cci_"

    * Validate dateformat option
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

    * ---------------------------------------------------------------
    * Validate inputs
    * ---------------------------------------------------------------
    marksample touse, novarlist

    * Determine date variable type (string vs numeric)
    local date_is_str = 0
    capture confirm string variable `date'
    if !_rc {
        local date_is_str = 1
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
    local N_input = r(N)

    if "`generate'" == "`id'" {
        display as error "generate() name cannot be same as id() variable"
        exit 198
    }

    * ---------------------------------------------------------------
    * Preserve and prepare data
    * ---------------------------------------------------------------
    preserve

    quietly keep if `touse'

    * Normalize ICD codes: uppercase, strip dots, prepend space for
    * word-boundary matching in regexm()
    quietly gen _code = " " + upper(subinstr(trim(`icd'), ".", "", .))

    * ---------------------------------------------------------------
    * Extract year from date (handles string, Stata date, YYYYMMDD)
    * ---------------------------------------------------------------
    if `date_is_str' {
        * String date variable
        if "`dateformat'" == "ymd" {
            * YYYY-MM-DD format: extract first 4 characters
            quietly gen int _yr = real(substr(trim(`date'), 1, 4))
        }
        else {
            * Default for string: try YYYYMMDD (strip dashes/slashes first)
            tempvar datenum
            quietly gen `datenum' = subinstr(subinstr(trim(`date'), "-", "", .), "/", "", .)
            quietly gen int _yr = floor(real(`datenum') / 10000)
        }
    }
    else if "`dateformat'" == "yyyymmdd" {
        * Numeric YYYYMMDD format
        quietly gen int _yr = floor(`date' / 10000)
    }
    else {
        * Default for numeric: Stata date format
        quietly gen int _yr = year(`date')
    }

    * Validate year extraction
    quietly count if missing(_yr)
    if r(N) > 0 {
        local n_bad = r(N)
        display as text "Warning: `n_bad' observations with unparseable dates (dropped)"
        quietly drop if missing(_yr)
    }

    quietly count
    if r(N) == 0 {
        display as error "No valid observations after date parsing"
        restore
        exit 2000
    }

    * ICD version flags (Swedish transition dates)
    quietly gen byte _v7  = (_yr <= 1968)
    quietly gen byte _v8  = (_yr >= 1969 & _yr <= 1986)
    quietly gen byte _v9  = (_yr >= 1987 & _yr <= 1997)
    quietly gen byte _v10 = (_yr >= 1997)

    * ---------------------------------------------------------------
    * Initialize 19 comorbidity indicators
    * ---------------------------------------------------------------
    forvalues i = 1/19 {
        quietly gen byte _cci_`i' = 0
    }

    * ---------------------------------------------------------------
    * Match ICD codes per comorbidity
    * Source: Ludvigsson et al. Clin Epidemiol 2021;13:21-41
    * ---------------------------------------------------------------

    * --- 1. Myocardial infarction ---
    quietly replace _cci_1 = 1 if _v7  & regexm(_code, " 420,1")
    quietly replace _cci_1 = 1 if _v8  & regexm(_code, " 410| 411| 412,01| 412,91")
    quietly replace _cci_1 = 1 if _v9  & regexm(_code, " 410| 412")
    quietly replace _cci_1 = 1 if _v10 & regexm(_code, " I21| I22| I252")

    * --- 2. Congestive heart failure ---
    quietly replace _cci_2 = 1 if _v7  & regexm(_code, " 422,21| 422,22| 434,1| 434,2")
    quietly replace _cci_2 = 1 if _v8  & regexm(_code, " 425,08| 425,09| 427,0| 427,1| 428")
    quietly replace _cci_2 = 1 if _v9  & regexm(_code, " 402A| 402B| 402X| 404A| 404B| 404X| 425E| 425F| 425H| 425W| 425X| 428")
    quietly replace _cci_2 = 1 if _v10 & regexm(_code, " I110| I130| I132| I255| I420| I426| I427| I428| I429| I43| I50")

    * --- 3. Peripheral vascular disease ---
    quietly replace _cci_3 = 1 if _v7  & regexm(_code, " 450,1| 451| 453")
    quietly replace _cci_3 = 1 if _v8  & regexm(_code, " 440| 441| 443,1| 443,9")
    quietly replace _cci_3 = 1 if _v9  & regexm(_code, " 440| 441| 443B| 443X| 447B| 557")
    quietly replace _cci_3 = 1 if _v10 & regexm(_code, " I70| I71| I731| I738| I739| I771| I790| I792| K55")

    * --- 4. Cerebrovascular disease ---
    quietly replace _cci_4 = 1 if _v7  & regexm(_code, " 330| 331| 332| 333| 334")
    quietly replace _cci_4 = 1 if _v8  & regexm(_code, " 430| 431| 432| 433| 434| 435| 436| 437| 438")
    quietly replace _cci_4 = 1 if _v9  & regexm(_code, " 430| 431| 432| 433| 434| 435| 436| 437| 438")
    quietly replace _cci_4 = 1 if _v10 & regexm(_code, " G45| I60| I61| I62| I63| I64| I67| I69")

    * --- 5. COPD ---
    quietly replace _cci_5 = 1 if _v7  & regexm(_code, " 502| 527,1")
    quietly replace _cci_5 = 1 if _v8  & regexm(_code, " 491| 492")
    quietly replace _cci_5 = 1 if _v9  & regexm(_code, " 491| 492| 496")
    quietly replace _cci_5 = 1 if _v10 & regexm(_code, " J43| J44")

    * --- 6. Other chronic pulmonary disease ---
    quietly replace _cci_6 = 1 if _v7  & regexm(_code, " 241| 501| 523| 524| 525| 526")
    quietly replace _cci_6 = 1 if _v8  & regexm(_code, " 490| 493| 515| 516| 517| 518")
    quietly replace _cci_6 = 1 if _v9  & regexm(_code, " 490| 493| 494| 495| 500| 501| 502| 503| 504| 505| 506| 507| 508| 516| 517")
    quietly replace _cci_6 = 1 if _v10 & regexm(_code, " J41| J42| J45| J46| J47| J60| J61| J62| J63| J64| J65| J66| J67| J68| J69| J70")

    * --- 7. Rheumatic disease ---
    quietly replace _cci_7 = 1 if _v7  & regexm(_code, " 722,00| 722,01| 722,10| 722,20| 722,23| 456,0| 456,1| 456,2| 456,3")
    quietly replace _cci_7 = 1 if _v8  & regexm(_code, " 446| 696| 712,0| 712,1| 712,2| 712,3| 712,5| 716| 734,0| 734,1| 734,9")
    quietly replace _cci_7 = 1 if _v9  & regexm(_code, " 446| 696A| 710A| 710B| 710C| 710D| 710E| 714| 719D| 720| 725")
    quietly replace _cci_7 = 1 if _v10 & regexm(_code, " M05| M06| M123| M070| M071| M072| M073| M08| M13| M30| M313| M314| M315| M316| M32| M33| M34| M350| M351| M353| M45| M46")

    * --- 8. Dementia ---
    quietly replace _cci_8 = 1 if _v7  & regexm(_code, " 304| 305")
    quietly replace _cci_8 = 1 if _v8  & regexm(_code, " 290")
    quietly replace _cci_8 = 1 if _v9  & regexm(_code, " 290| 294B| 331A| 331B| 331C| 331X")
    quietly replace _cci_8 = 1 if _v10 & regexm(_code, " F00| F01| F02| F03| F051| G30| G311| G319")

    * --- 9. Hemiplegia/paraplegia ---
    quietly replace _cci_9 = 1 if _v7  & regexm(_code, " 351| 352| 357,00")
    quietly replace _cci_9 = 1 if _v8  & regexm(_code, " 343| 344")
    quietly replace _cci_9 = 1 if _v9  & regexm(_code, " 342| 343| 344A| 344B| 344C| 344D| 344E| 344F")
    quietly replace _cci_9 = 1 if _v10 & regexm(_code, " G114| G80| G81| G82| G830| G831| G832| G833| G838")

    * --- 10. Diabetes without complications ---
    quietly replace _cci_10 = 1 if _v7  & regexm(_code, " 260,09")
    quietly replace _cci_10 = 1 if _v8  & regexm(_code, " 250,00| 250,07| 250,08")
    quietly replace _cci_10 = 1 if _v9  & regexm(_code, " 250A| 250B| 250C")
    quietly replace _cci_10 = 1 if _v10 & regexm(_code, " E100| E101| E106| E109| E110| E111| E119| E120| E121| E129| E130| E131| E139| E140| E141| E149")

    * --- 11. Diabetes with complications ---
    quietly replace _cci_11 = 1 if _v7  & regexm(_code, " 260,2| 260,21| 260,29| 260,3| 260,4| 260,49| 260,99")
    quietly replace _cci_11 = 1 if _v8  & regexm(_code, " 250,01| 250,02| 250,03| 250,04| 250,05")
    quietly replace _cci_11 = 1 if _v9  & regexm(_code, " 250D| 250E| 250F| 250G")
    local c11_10a " E102| E103| E104| E105| E107| E112| E113| E114| E115| E116| E117"
    local c11_10b " E122| E123| E124| E125| E126| E127| E132| E133| E134| E135| E136| E137"
    local c11_10c " E142| E143| E144| E145| E146| E147"
    quietly replace _cci_11 = 1 if _v10 & regexm(_code, "`c11_10a'|`c11_10b'|`c11_10c'")

    * --- 12. Renal disease ---
    quietly replace _cci_12 = 1 if _v7  & regexm(_code, " 592| 593| 792")
    quietly replace _cci_12 = 1 if _v8  & regexm(_code, " 582| 583| 584| 792| 593,00| 403,99| 404,99| 792,99| Y29,01")
    quietly replace _cci_12 = 1 if _v9  & regexm(_code, " 403A| 403B| 403X| 582| 583| 585| 586| 588A| V42A| V45B| V56")
    local c12_10a " I120| I131| N032| N033| N034| N035| N036| N037| N052| N053| N054| N055| N056| N057"
    local c12_10b " N11| N18| N19| N250| Q611| Q612| Q613| Q614| Z49| Z940| Z992"
    quietly replace _cci_12 = 1 if _v10 & regexm(_code, "`c12_10a'|`c12_10b'")

    * --- 13. Mild liver disease ---
    quietly replace _cci_13 = 1 if _v7  & regexm(_code, " 581")
    quietly replace _cci_13 = 1 if _v8  & regexm(_code, " 070| 571| 573")
    quietly replace _cci_13 = 1 if _v9  & regexm(_code, " 070| 571C| 571E| 571F| 573")
    quietly replace _cci_13 = 1 if _v10 & regexm(_code, " B15| B16| B17| B18| B19| K703| K709| K73| K746| K754")

    * --- 14. Ascites (internal, used for liver hierarchy) ---
    quietly replace _cci_14 = 1 if _v8  & regexm(_code, " 785,3")
    quietly replace _cci_14 = 1 if _v9  & regexm(_code, " 789F")
    quietly replace _cci_14 = 1 if _v10 & regexm(_code, " R18")

    * --- 15. Moderate/severe liver disease ---
    quietly replace _cci_15 = 1 if _v7  & regexm(_code, " 462,1")
    quietly replace _cci_15 = 1 if _v8  & regexm(_code, " 456,0| 571,9| 573,02")
    quietly replace _cci_15 = 1 if _v9  & regexm(_code, " 456A| 456B| 456C| 572C| 572D| 572E")
    quietly replace _cci_15 = 1 if _v10 & regexm(_code, " I850| I859| I982| I983")

    * --- 16. Peptic ulcer disease ---
    quietly replace _cci_16 = 1 if _v7  & regexm(_code, " 540| 541| 542")
    quietly replace _cci_16 = 1 if _v8  & regexm(_code, " 531| 532| 533| 534")
    quietly replace _cci_16 = 1 if _v9  & regexm(_code, " 531| 532| 533| 534")
    quietly replace _cci_16 = 1 if _v10 & regexm(_code, " K25| K26| K27| K28")

    * --- 17. Malignancy (non-metastatic) ---
    * ICD-7
    local c17_7a " 140| 141| 142| 143| 144| 145| 146| 147| 148| 149"
    local c17_7b " 150| 151| 152| 153| 154| 155| 156| 157| 158| 159"
    local c17_7c " 160| 161| 162| 163| 164| 165| 166| 167| 168| 169"
    local c17_7d " 170| 171| 172| 173| 174| 175| 176| 177| 178| 179"
    local c17_7e " 180| 181| 182| 183| 184| 185| 186| 187| 188| 189"
    local c17_7f " 190| 192| 193| 194| 195| 196| 197| 200| 201| 202| 203| 204"
    quietly replace _cci_17 = 1 if _v7 & regexm(_code, "`c17_7a'|`c17_7b'|`c17_7c'|`c17_7d'|`c17_7e'|`c17_7f'")

    * ICD-8
    local c17_8a " 140| 141| 142| 143| 144| 145| 146| 147| 148| 149"
    local c17_8b " 150| 151| 152| 153| 154| 155| 156| 157| 158| 159"
    local c17_8c " 160| 161| 162| 163| 164| 165| 166| 167| 168| 169"
    local c17_8d " 170| 171| 172| 174| 180| 181| 182| 183| 184| 185"
    local c17_8e " 186| 187| 188| 189| 190| 191| 192| 193| 194| 195"
    local c17_8f " 196| 197| 198| 199| 200| 201| 202| 203| 204| 205| 206| 207| 209"
    quietly replace _cci_17 = 1 if _v8 & regexm(_code, "`c17_8a'|`c17_8b'|`c17_8c'|`c17_8d'|`c17_8e'|`c17_8f'")

    * ICD-9
    local c17_9a " 140| 141| 142| 143| 144| 145| 146| 147| 148| 149"
    local c17_9b " 150| 151| 152| 153| 154| 155| 156| 157| 158| 159"
    local c17_9c " 160| 161| 162| 163| 164| 165| 166| 167| 168| 169"
    local c17_9d " 170| 171| 172| 174| 175| 176| 177| 178| 179| 180"
    local c17_9e " 181| 182| 183| 184| 185| 186| 187| 188| 189| 190"
    local c17_9f " 191| 192| 193| 194| 195| 196| 197| 198| 199| 200"
    local c17_9g " 201| 202| 203| 204| 205| 206| 207| 208"
    quietly replace _cci_17 = 1 if _v9 & regexm(_code, "`c17_9a'|`c17_9b'|`c17_9c'|`c17_9d'|`c17_9e'|`c17_9f'|`c17_9g'")

    * ICD-10
    local c17_10a " C00| C01| C02| C03| C04| C05| C06| C07| C08| C09"
    local c17_10b " C10| C11| C12| C13| C14| C15| C16| C17| C18| C19"
    local c17_10c " C20| C21| C22| C23| C24| C25| C26| C27| C28| C29"
    local c17_10d " C30| C31| C32| C33| C34| C35| C36| C37| C38| C39"
    local c17_10e " C40| C41| C43| C45| C46| C47| C48| C49| C50| C51"
    local c17_10f " C52| C53| C54| C55| C56| C57| C58| C59| C60| C61"
    local c17_10g " C62| C63| C64| C65| C66| C67| C68| C69| C70| C71"
    local c17_10h " C72| C73| C74| C75| C76| C81| C82| C83| C84| C85"
    local c17_10i " C86| C88| C89| C90| C91| C92| C93| C94| C95| C96| C97"
    quietly replace _cci_17 = 1 if _v10 & regexm(_code, "`c17_10a'|`c17_10b'|`c17_10c'|`c17_10d'|`c17_10e'|`c17_10f'|`c17_10g'|`c17_10h'|`c17_10i'")

    * --- 18. Metastatic cancer ---
    quietly replace _cci_18 = 1 if _v7  & regexm(_code, " 156,91| 198| 199")
    quietly replace _cci_18 = 1 if _v8  & regexm(_code, " 196| 197| 198| 199")
    quietly replace _cci_18 = 1 if _v9  & regexm(_code, " 196| 197| 198| 199A| 199B")
    quietly replace _cci_18 = 1 if _v10 & regexm(_code, " C77| C78| C79| C80")

    * --- 19. AIDS/HIV ---
    quietly replace _cci_19 = 1 if _v9  & regexm(_code, " 079J| 279K")
    quietly replace _cci_19 = 1 if _v10 & regexm(_code, " B20| B21| B22| B23| B24| F024| O987| R75| Z219| Z717")

    * ---------------------------------------------------------------
    * Collapse to patient level (max of each indicator)
    * ---------------------------------------------------------------
    collapse (max) _cci_*, by(`id')

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

    * ---------------------------------------------------------------
    * Compute weighted Charlson score
    * Weights: most=1, hemiplegia/diabcomp/renal/cancer=2,
    *          liver severe=3, metastatic/AIDS=6
    * ---------------------------------------------------------------
    quietly gen byte `generate' = ///
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
    * Display results
    * ---------------------------------------------------------------
    if "`noisily'" != "" {
        display as text ""
        display as text "{hline 60}"
        display as text "Swedish Charlson Comorbidity Index (Ludvigsson et al. 2021)"
        display as text "{hline 60}"
        display as text "Input observations:     " as result %12.0fc `N_input'
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
end
