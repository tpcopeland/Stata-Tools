*! version 1.0.1  2025/12/06
*! Author: Timothy P Copeland
*! Generate synthetic datasets for testing tvtools, mvp, and other commands
program define generate_test_data
    version 16.0
    set varabbrev off
    syntax , SAVEdir(string) [SEED(integer 12345) NOBS(integer 1000) MISS REPLACE]

    * Validate savedir exists
    mata: st_local("direxists", strofreal(direxists(st_local("savedir"))))
    if `direxists' == 0 {
        display as error "Directory `savedir' does not exist"
        exit 601
    }

    * Set seed for reproducibility
    set seed `seed'

    * =========================================================================
    * PART 1: Generate cohort.dta
    * =========================================================================
    display as text _n "Creating cohort.dta with `nobs' observations..."

    clear
    set obs `nobs'

    * ID variable
    gen long id = _n
    label variable id "Person identifier"

    * Demographics - age at study entry (18-80)
    gen byte age = 18 + floor(runiform() * 62)
    label variable age "Age at study entry"

    * Gender (female=1, male=0) - 70% female for MS cohort
    gen byte female = runiform() < 0.70
    label variable female "Female sex"
    label define female_lbl 0 "Male" 1 "Female"
    label values female female_lbl

    * MS type (1=RRMS, 2=SPMS, 3=PPMS, 4=CIS)
    gen temp = runiform()
    gen byte mstype = cond(temp < 0.65, 1, cond(temp < 0.85, 2, cond(temp < 0.95, 3, 4)))
    drop temp
    label variable mstype "MS phenotype"
    label define mstype_lbl 1 "RRMS" 2 "SPMS" 3 "PPMS" 4 "CIS"
    label values mstype mstype_lbl

    * Baseline EDSS (0-6.5, skewed toward lower values)
    gen float edss_baseline = floor(2 * abs(rnormal()) * 2) / 2
    replace edss_baseline = 6.5 if edss_baseline > 6.5
    label variable edss_baseline "Baseline EDSS score"

    * Region (1-6)
    gen byte region = ceil(runiform() * 6)
    label variable region "Geographic region"
    label define region_lbl 1 "North" 2 "Central" 3 "South" 4 "East" 5 "West" 6 "Metropolitan"
    label values region region_lbl

    * Study entry date (2010-2020)
    gen int study_entry = mdy(1,1,2010) + floor(runiform() * 3652)
    format study_entry %tdCCYY/NN/DD
    label variable study_entry "Study entry date"

    * Study exit date (1-10 years after entry, with some censoring)
    gen int study_exit = study_entry + 365 + floor(runiform() * 3287)
    * Cap at end of 2023
    replace study_exit = min(study_exit, mdy(12, 31, 2023))
    format study_exit %tdCCYY/NN/DD
    label variable study_exit "Study exit date"

    * EDSS 4 sustained progression date (outcome) - ~25% have event
    * Event occurs strictly after study_entry (add 1 to avoid day-0 events)
    gen int edss4_dt = .
    gen temp = runiform()
    replace edss4_dt = study_entry + 1 + floor(runiform() * (study_exit - study_entry - 1)) if temp < 0.25 & edss_baseline < 4
    format edss4_dt %tdCCYY/NN/DD
    label variable edss4_dt "Date of sustained EDSS >= 4"
    drop temp

    * Death date (competing event) - ~5% die
    * Event occurs strictly after study_entry
    gen int death_dt = .
    gen temp = runiform()
    replace death_dt = study_entry + 1 + floor(runiform() * (study_exit - study_entry - 1)) if temp < 0.05
    format death_dt %tdCCYY/NN/DD
    label variable death_dt "Date of death"
    drop temp

    * If death occurred on or before EDSS4, the EDSS4 event couldn't have happened
    * (death is a competing event that precludes reaching EDSS 4)
    replace edss4_dt = . if !missing(death_dt) & !missing(edss4_dt) & edss4_dt >= death_dt

    * Emigration date (censoring) - ~8%
    * Event occurs strictly after study_entry
    gen int emigration_dt = .
    gen temp = runiform()
    replace emigration_dt = study_entry + 1 + floor(runiform() * (study_exit - study_entry - 1)) if temp < 0.08 & missing(death_dt)
    format emigration_dt %tdCCYY/NN/DD
    label variable emigration_dt "Date of emigration"
    drop temp

    * Education level (1-4)
    gen temp = runiform()
    gen byte education = cond(temp < 0.15, 1, cond(temp < 0.45, 2, cond(temp < 0.80, 3, 4)))
    drop temp
    label variable education "Education level"
    label define edu_lbl 1 "Primary" 2 "Secondary" 3 "Tertiary" 4 "Postgraduate"
    label values education edu_lbl

    * Income quartile (1-4)
    gen byte income_q = ceil(runiform() * 4)
    label variable income_q "Income quartile"
    label define inc_lbl 1 "Q1 (lowest)" 2 "Q2" 3 "Q3" 4 "Q4 (highest)"
    label values income_q inc_lbl

    * Comorbidity index (0-5)
    gen byte comorbidity = floor(abs(rnormal()) * 2)
    replace comorbidity = min(comorbidity, 5)
    label variable comorbidity "Charlson comorbidity index"

    * Smoking status (0=never, 1=former, 2=current)
    gen temp = runiform()
    gen byte smoking = cond(temp < 0.50, 0, cond(temp < 0.80, 1, 2))
    drop temp
    label variable smoking "Smoking status"
    label define smoke_lbl 0 "Never" 1 "Former" 2 "Current"
    label values smoking smoke_lbl

    * BMI (18-40, normally distributed)
    gen float bmi = 25 + rnormal() * 5
    replace bmi = max(18, min(bmi, 45))
    label variable bmi "Body mass index"

    * Order and compress
    order id age female mstype edss_baseline region study_entry study_exit edss4_dt death_dt emigration_dt education income_q comorbidity smoking bmi
    compress

    * Add dataset notes
    note: Synthetic cohort dataset for testing tvtools and related commands
    note: Generated by generate_test_data on $S_DATE
    note: N = `nobs' observations

    if "`replace'" != "" {
        save "`savedir'/cohort.dta", replace
    }
    else {
        capture confirm file "`savedir'/cohort.dta"
        if _rc {
            save "`savedir'/cohort.dta"
        }
        else {
            display as error "File cohort.dta exists. Use replace option to overwrite."
            exit 602
        }
    }
    display as text "  Saved: `savedir'/cohort.dta"

    * =========================================================================
    * PART 2: Generate hrt.dta (HRT exposure periods)
    * =========================================================================
    display as text _n "Creating hrt.dta..."

    * Keep ID and dates from cohort for reference
    tempfile cohort_ref
    keep id study_entry study_exit female
    save `cohort_ref'

    clear

    * Approximately 40% of females will have HRT exposure
    * Multiple periods per person (1-4)
    use `cohort_ref', clear
    keep if female == 1
    local nfemale = _N

    * Expand to create multiple periods per person
    gen byte n_periods = 1 + floor(runiform() * 4)  // 1-4 periods
    expand n_periods
    bysort id: gen byte period = _n

    * HRT type (1=estrogen, 2=progesterone, 3=combined)
    gen temp = runiform()
    gen byte hrt_type = cond(temp < 0.45, 1, cond(temp < 0.65, 2, 3))
    drop temp
    label variable hrt_type "HRT type"
    label define hrt_lbl 0 "No HRT" 1 "Estrogen only" 2 "Progesterone only" 3 "Combined"
    label values hrt_type hrt_lbl

    * Generate start dates spread across follow-up
    gen int rx_start = study_entry + floor(runiform() * (study_exit - study_entry - 90))
    format rx_start %tdCCYY/NN/DD
    label variable rx_start "HRT prescription start date"

    * Generate stop dates (30-365 days after start)
    gen int rx_stop = rx_start + 30 + floor(runiform() * 335)
    replace rx_stop = min(rx_stop, study_exit)
    format rx_stop %tdCCYY/NN/DD
    label variable rx_stop "HRT prescription stop date"

    * Dose (0.5, 1.0, 1.5, 2.0 mg)
    gen temp = runiform()
    gen float dose = cond(temp < 0.30, 0.5, cond(temp < 0.70, 1.0, cond(temp < 0.90, 1.5, 2.0)))
    drop temp
    label variable dose "HRT dose (mg)"

    * Keep only about 40% of female subjects (i.e., ~40% ever used HRT)
    gen temp = runiform()
    bysort id (period): gen first = _n == 1
    gen keep_id = temp < 0.40 if first == 1
    bysort id: replace keep_id = keep_id[1]
    keep if keep_id == 1
    drop temp first keep_id

    * Sort and ensure non-overlapping periods (simple approach)
    sort id rx_start
    bysort id (rx_start): replace rx_start = rx_stop[_n-1] + 30 if _n > 1 & rx_start < rx_stop[_n-1]
    replace rx_stop = rx_start + 30 + floor(runiform() * 180) if rx_stop <= rx_start
    replace rx_stop = min(rx_stop, study_exit)

    * Drop invalid periods (where start >= exit)
    drop if rx_start >= study_exit
    drop if rx_stop <= rx_start

    * Renumber periods
    drop period n_periods
    bysort id (rx_start): gen byte period = _n

    * Final cleanup
    keep id rx_start rx_stop hrt_type dose period
    order id period rx_start rx_stop hrt_type dose
    label variable id "Person identifier"
    label variable period "HRT period number"
    compress

    note: Synthetic HRT exposure dataset for testing tvtools
    note: Generated by generate_test_data on $S_DATE

    if "`replace'" != "" {
        save "`savedir'/hrt.dta", replace
    }
    else {
        capture confirm file "`savedir'/hrt.dta"
        if _rc {
            save "`savedir'/hrt.dta"
        }
        else {
            display as error "File hrt.dta exists. Use replace option to overwrite."
            exit 602
        }
    }
    display as text "  Saved: `savedir'/hrt.dta"

    * =========================================================================
    * PART 3: Generate dmt.dta (Disease-modifying therapy periods)
    * =========================================================================
    display as text _n "Creating dmt.dta..."

    clear
    use `cohort_ref', clear
    drop female

    * Approximately 70% will have DMT exposure
    * Multiple periods per person (1-5)
    gen byte n_periods = 1 + floor(runiform() * 5)  // 1-5 periods
    expand n_periods
    bysort id: gen byte period = _n

    * DMT type (1-6 = different DMT types)
    * 1=Interferon beta, 2=Glatiramer, 3=Dimethyl fumarate, 4=Teriflunomide, 5=Fingolimod, 6=Natalizumab
    gen temp = runiform()
    gen byte dmt = cond(temp < 0.25, 1, cond(temp < 0.40, 2, cond(temp < 0.55, 3, ///
                    cond(temp < 0.70, 4, cond(temp < 0.85, 5, 6)))))
    drop temp
    label variable dmt "DMT type"
    label define dmt_lbl 0 "No DMT" 1 "Interferon beta" 2 "Glatiramer acetate" ///
        3 "Dimethyl fumarate" 4 "Teriflunomide" 5 "Fingolimod" 6 "Natalizumab"
    label values dmt dmt_lbl

    * Generate start dates
    gen int dmt_start = study_entry + floor(runiform() * (study_exit - study_entry - 90))
    format dmt_start %tdCCYY/NN/DD
    label variable dmt_start "DMT start date"

    * Generate stop dates (60-730 days after start)
    gen int dmt_stop = dmt_start + 60 + floor(runiform() * 670)
    replace dmt_stop = min(dmt_stop, study_exit)
    format dmt_stop %tdCCYY/NN/DD
    label variable dmt_stop "DMT stop date"

    * Efficacy category (for testing)
    gen byte efficacy = cond(dmt <= 2, 1, cond(dmt <= 4, 2, 3))
    label variable efficacy "DMT efficacy category"
    label define eff_lbl 1 "Moderate" 2 "High" 3 "Very high"
    label values efficacy eff_lbl

    * Keep only ~70% of subjects
    gen temp = runiform()
    bysort id (period): gen first = _n == 1
    gen keep_id = temp < 0.70 if first == 1
    bysort id: replace keep_id = keep_id[1]
    keep if keep_id == 1
    drop temp first keep_id

    * Sort and fix overlapping periods
    sort id dmt_start
    bysort id (dmt_start): replace dmt_start = dmt_stop[_n-1] + 7 if _n > 1 & dmt_start < dmt_stop[_n-1]
    replace dmt_stop = dmt_start + 60 + floor(runiform() * 365) if dmt_stop <= dmt_start
    replace dmt_stop = min(dmt_stop, study_exit)

    * Drop invalid periods
    drop if dmt_start >= study_exit
    drop if dmt_stop <= dmt_start

    * Renumber periods
    drop period n_periods
    bysort id (dmt_start): gen byte period = _n

    * Final cleanup
    keep id dmt_start dmt_stop dmt efficacy period
    order id period dmt_start dmt_stop dmt efficacy
    label variable id "Person identifier"
    label variable period "DMT period number"
    compress

    note: Synthetic DMT exposure dataset for testing tvtools
    note: Generated by generate_test_data on $S_DATE

    if "`replace'" != "" {
        save "`savedir'/dmt.dta", replace
    }
    else {
        capture confirm file "`savedir'/dmt.dta"
        if _rc {
            save "`savedir'/dmt.dta"
        }
        else {
            display as error "File dmt.dta exists. Use replace option to overwrite."
            exit 602
        }
    }
    display as text "  Saved: `savedir'/dmt.dta"

    * =========================================================================
    * PART 4: Generate hospitalizations.dta (for tvevent recurring example)
    * =========================================================================
    display as text _n "Creating hospitalizations.dta..."

    clear
    use `cohort_ref', clear
    drop female

    * ~30% will have hospitalizations, multiple possible
    gen byte n_hosp = floor(abs(rnormal()) * 2)  // 0-3+ hospitalizations
    replace n_hosp = min(n_hosp, 5)
    expand n_hosp + 1 if n_hosp > 0

    bysort id: gen byte hosp_n = _n
    drop if hosp_n > n_hosp

    * Only keep those with at least 1 hospitalization (~30%)
    keep if n_hosp > 0

    * Hospitalization date
    gen int hosp_date = study_entry + floor(runiform() * (study_exit - study_entry))
    format hosp_date %tdCCYY/NN/DD
    label variable hosp_date "Hospitalization date"

    * Sort and ensure sequential
    sort id hosp_date
    bysort id (hosp_date): replace hosp_n = _n

    * Hospitalization type (1-4)
    gen temp = runiform()
    gen byte hosp_type = cond(temp < 0.40, 1, cond(temp < 0.65, 2, cond(temp < 0.85, 3, 4)))
    drop temp
    label variable hosp_type "Hospitalization type"
    label define hosp_lbl 1 "MS relapse" 2 "Infection" 3 "Injury" 4 "Other"
    label values hosp_type hosp_lbl

    * ICD code (synthetic)
    gen str7 icd_code = "G35" if hosp_type == 1
    replace icd_code = "J" + string(10 + floor(runiform()*10)) if hosp_type == 2
    replace icd_code = "S" + string(floor(runiform()*100), "%02.0f") if hosp_type == 3
    replace icd_code = "R" + string(floor(runiform()*100), "%02.0f") if hosp_type == 4
    label variable icd_code "ICD-10 code"

    * Final cleanup
    keep id hosp_date hosp_type icd_code hosp_n
    order id hosp_n hosp_date hosp_type icd_code
    label variable id "Person identifier"
    label variable hosp_n "Hospitalization number"
    compress

    note: Synthetic hospitalizations dataset for testing tvevent recurring
    note: Generated by generate_test_data on $S_DATE

    if "`replace'" != "" {
        save "`savedir'/hospitalizations.dta", replace
    }
    else {
        capture confirm file "`savedir'/hospitalizations.dta"
        if _rc {
            save "`savedir'/hospitalizations.dta"
        }
        else {
            display as error "File hospitalizations.dta exists. Use replace option to overwrite."
            exit 602
        }
    }
    display as text "  Saved: `savedir'/hospitalizations.dta"

    * =========================================================================
    * PART 4b: Generate hospitalizations_wide.dta (for tvevent recurring)
    * =========================================================================
    display as text _n "Creating hospitalizations_wide.dta..."

    clear
    use `cohort_ref', clear
    drop female

    * Approximately 40% of patients have hospitalizations (wide format)
    gen byte has_hosp = runiform() < 0.40

    * Generate up to 5 hospitalization dates per person (wide format)
    gen int hosp_date1 = study_entry + floor(runiform() * (study_exit - study_entry) * 0.2) if has_hosp
    gen int hosp_date2 = hosp_date1 + 60 + floor(runiform() * 180) if has_hosp & runiform() < 0.60
    gen int hosp_date3 = hosp_date2 + 60 + floor(runiform() * 180) if !missing(hosp_date2) & runiform() < 0.50
    gen int hosp_date4 = hosp_date3 + 60 + floor(runiform() * 180) if !missing(hosp_date3) & runiform() < 0.30
    gen int hosp_date5 = hosp_date4 + 60 + floor(runiform() * 180) if !missing(hosp_date4) & runiform() < 0.20

    * Ensure dates are within study period
    foreach v in hosp_date1 hosp_date2 hosp_date3 hosp_date4 hosp_date5 {
        replace `v' = . if `v' > study_exit - 7
        replace `v' = . if `v' <= study_entry
    }

    format hosp_date1 hosp_date2 hosp_date3 hosp_date4 hosp_date5 %tdCCYY/NN/DD
    label variable hosp_date1 "First hospitalization date"
    label variable hosp_date2 "Second hospitalization date"
    label variable hosp_date3 "Third hospitalization date"
    label variable hosp_date4 "Fourth hospitalization date"
    label variable hosp_date5 "Fifth hospitalization date"

    drop has_hosp

    compress

    note: Synthetic hospitalizations dataset (wide format) for testing tvevent
    note: Generated by generate_test_data on $S_DATE

    if "`replace'" != "" {
        save "`savedir'/hospitalizations_wide.dta", replace
    }
    else {
        capture confirm file "`savedir'/hospitalizations_wide.dta"
        if _rc {
            save "`savedir'/hospitalizations_wide.dta"
        }
        else {
            display as error "File hospitalizations_wide.dta exists. Use replace option to overwrite."
            exit 602
        }
    }
    display as text "  Saved: `savedir'/hospitalizations_wide.dta"

    * =========================================================================
    * PART 5: Generate migrations_wide.dta (for migrations command)
    * =========================================================================
    display as text _n "Creating migrations_wide.dta..."

    clear
    use `cohort_ref', clear
    drop female

    * About 15% will have migration events
    gen has_migration = runiform() < 0.15

    * Immigration dates (up to 3)
    gen int in_1 = .
    gen int in_2 = .
    gen int in_3 = .

    * Emigration dates (up to 3)
    gen int out_1 = .
    gen int out_2 = .
    gen int out_3 = .

    * Generate migration patterns for those with migrations
    * Pattern 1: Emigrated before study start (~40% of migrants)
    * Pattern 2: Emigrated after study start (~40% of migrants)
    * Pattern 3: Complex pattern (~20% of migrants)
    gen pattern = 1 + floor(runiform() * 3) if has_migration == 1

    * Pattern 1: One emigration before study, one immigration after
    replace out_1 = study_entry - floor(runiform() * 365) - 30 if pattern == 1
    replace in_1 = study_entry + floor(runiform() * 365) + 30 if pattern == 1

    * Pattern 2: One emigration after study start
    replace out_1 = study_entry + floor(runiform() * (study_exit - study_entry - 30)) + 30 if pattern == 2

    * Pattern 3: Complex - emigrate, immigrate, emigrate again
    replace out_1 = study_entry + floor(runiform() * 365) if pattern == 3
    replace in_1 = out_1 + 30 + floor(runiform() * 180) if pattern == 3
    replace out_2 = in_1 + 30 + floor(runiform() * 365) if pattern == 3 & in_1 < study_exit - 60

    * Format dates
    format in_1 in_2 in_3 out_1 out_2 out_3 %tdCCYY/NN/DD

    * Labels
    label variable in_1 "Immigration date 1"
    label variable in_2 "Immigration date 2"
    label variable in_3 "Immigration date 3"
    label variable out_1 "Emigration date 1"
    label variable out_2 "Emigration date 2"
    label variable out_3 "Emigration date 3"

    * Cleanup
    keep id in_1 in_2 in_3 out_1 out_2 out_3
    label variable id "Person identifier"
    compress

    note: Synthetic migrations dataset (wide format) for testing migrations command
    note: Generated by generate_test_data on $S_DATE

    if "`replace'" != "" {
        save "`savedir'/migrations_wide.dta", replace
    }
    else {
        capture confirm file "`savedir'/migrations_wide.dta"
        if _rc {
            save "`savedir'/migrations_wide.dta"
        }
        else {
            display as error "File migrations_wide.dta exists. Use replace option to overwrite."
            exit 602
        }
    }
    display as text "  Saved: `savedir'/migrations_wide.dta"

    * =========================================================================
    * PART 6: Generate edss_long.dta (for sustainedss command)
    * =========================================================================
    display as text _n "Creating edss_long.dta..."

    clear
    use `cohort_ref', clear
    drop female

    * Generate 3-10 EDSS measurements per person
    gen byte n_visits = 3 + floor(runiform() * 8)
    expand n_visits
    bysort id: gen byte visit = _n

    * Visit dates spread across follow-up
    gen int edss_dt = study_entry + floor((visit - 1) * (study_exit - study_entry) / n_visits) + floor(runiform() * 30) - 15
    replace edss_dt = max(edss_dt, study_entry)
    replace edss_dt = min(edss_dt, study_exit)
    format edss_dt %tdCCYY/NN/DD
    label variable edss_dt "EDSS measurement date"

    * EDSS scores - generally stable or slowly progressing
    * Start with baseline from cohort (merge back)
    preserve
    use "`savedir'/cohort.dta", clear
    keep id edss_baseline
    tempfile baseline
    save `baseline'
    restore

    merge m:1 id using `baseline', nogen keep(match)

    * Verify merge was successful (all IDs should match)
    quietly count
    if r(N) == 0 {
        display as error "EDSS merge failed - no matching observations"
        exit 459
    }

    * Generate EDSS with some progression over time
    gen float edss = edss_baseline + floor(visit * 0.3 * runiform()) / 2
    * Add some noise
    replace edss = edss + (rnormal() * 0.5)
    * Round to valid EDSS values (0, 0.5, 1, 1.5, ... 10)
    replace edss = round(edss * 2) / 2
    replace edss = max(0, min(edss, 10))
    label variable edss "EDSS score"

    * Cleanup
    keep id edss_dt edss visit
    order id visit edss_dt edss
    sort id edss_dt
    bysort id (edss_dt): replace visit = _n
    label variable id "Person identifier"
    label variable visit "Visit number"
    compress

    note: Synthetic EDSS longitudinal dataset for testing sustainedss command
    note: Generated by generate_test_data on $S_DATE

    if "`replace'" != "" {
        save "`savedir'/edss_long.dta", replace
    }
    else {
        capture confirm file "`savedir'/edss_long.dta"
        if _rc {
            save "`savedir'/edss_long.dta"
        }
        else {
            display as error "File edss_long.dta exists. Use replace option to overwrite."
            exit 602
        }
    }
    display as text "  Saved: `savedir'/edss_long.dta"

    * =========================================================================
    * PART 7: Generate datasets with missingness patterns (_miss versions)
    * =========================================================================
    if "`miss'" != "" {
        display as text _n "Creating datasets with missingness patterns..."

        * ------------------------------------------------------------------
        * cohort_miss.dta
        * ------------------------------------------------------------------
        use "`savedir'/cohort.dta", clear

        * Pattern 1: MCAR - random missingness in age (~5%)
        replace age = . if runiform() < 0.05

        * Pattern 2: MAR - missingness in education related to age
        * Older patients more likely to have missing education
        replace education = . if (age > 60 | missing(age)) & runiform() < 0.25

        * Pattern 3: MAR - missingness in BMI related to both age and sex
        replace bmi = . if female == 0 & runiform() < 0.15
        replace bmi = . if age > 65 & runiform() < 0.20

        * Pattern 4: Block missingness - income_q and education tend to be missing together
        gen temp = runiform()
        replace income_q = . if temp < 0.10
        replace education = . if temp < 0.08 & !missing(education)  // overlap
        drop temp

        * Pattern 5: Monotone-like - comorbidity missing implies smoking missing
        replace comorbidity = . if runiform() < 0.08
        replace smoking = . if missing(comorbidity) & runiform() < 0.60

        * Pattern 6: Some outcome-related missingness (edss4_dt already has natural missingness)
        * Add a bit more missingness in death_dt
        replace death_dt = . if !missing(death_dt) & runiform() < 0.10

        * Pattern 7: EDSS baseline occasionally missing (~3%)
        replace edss_baseline = . if runiform() < 0.03

        compress
        note: Cohort dataset with various missingness patterns for testing mvp
        note: MCAR: age; MAR: education, bmi; Block: income_q+education; Monotone-like: comorbidity->smoking

        if "`replace'" != "" {
            save "`savedir'/cohort_miss.dta", replace
        }
        else {
            capture confirm file "`savedir'/cohort_miss.dta"
            if _rc {
                save "`savedir'/cohort_miss.dta"
            }
            else {
                display as error "File cohort_miss.dta exists. Use replace option to overwrite."
                exit 602
            }
        }
        display as text "  Saved: `savedir'/cohort_miss.dta"

        * ------------------------------------------------------------------
        * hrt_miss.dta
        * ------------------------------------------------------------------
        use "`savedir'/hrt.dta", clear

        * Some dose values missing (~10%)
        replace dose = . if runiform() < 0.10

        * Some hrt_type missing when dose is missing (correlated)
        replace hrt_type = . if missing(dose) & runiform() < 0.30

        compress
        note: HRT dataset with missingness patterns

        if "`replace'" != "" {
            save "`savedir'/hrt_miss.dta", replace
        }
        else {
            capture confirm file "`savedir'/hrt_miss.dta"
            if _rc {
                save "`savedir'/hrt_miss.dta"
            }
            else {
                display as error "File hrt_miss.dta exists. Use replace option to overwrite."
                exit 602
            }
        }
        display as text "  Saved: `savedir'/hrt_miss.dta"

        * ------------------------------------------------------------------
        * dmt_miss.dta
        * ------------------------------------------------------------------
        use "`savedir'/dmt.dta", clear

        * Efficacy missing when DMT is certain types (~15%)
        replace efficacy = . if inlist(dmt, 3, 4) & runiform() < 0.15

        compress
        note: DMT dataset with missingness patterns

        if "`replace'" != "" {
            save "`savedir'/dmt_miss.dta", replace
        }
        else {
            capture confirm file "`savedir'/dmt_miss.dta"
            if _rc {
                save "`savedir'/dmt_miss.dta"
            }
            else {
                display as error "File dmt_miss.dta exists. Use replace option to overwrite."
                exit 602
            }
        }
        display as text "  Saved: `savedir'/dmt_miss.dta"

        display as text _n "Missingness datasets created successfully."
    }

    * =========================================================================
    * Summary
    * =========================================================================
    display as text _n "{hline 60}"
    display as text "Synthetic test data generation complete!"
    display as text "{hline 60}"
    display as text "Files created in: `savedir'"
    display as text "  - cohort.dta                (baseline cohort, `nobs' persons)"
    display as text "  - hrt.dta                   (HRT exposure periods)"
    display as text "  - dmt.dta                   (DMT exposure periods)"
    display as text "  - hospitalizations.dta      (hospitalization events)"
    display as text "  - hospitalizations_wide.dta (wide format for tvevent)"
    display as text "  - migrations_wide.dta       (migration records)"
    display as text "  - edss_long.dta             (longitudinal EDSS)"
    if "`miss'" != "" {
        display as text "  - cohort_miss.dta           (with missingness patterns)"
        display as text "  - hrt_miss.dta              (with missingness)"
        display as text "  - dmt_miss.dta              (with missingness)"
    }
    display as text "{hline 60}"

    * Clear and restore
    clear
end
