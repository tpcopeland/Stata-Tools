/*
    cleaning.do — Prepare NHEFS data for Stata-Tools examples

    Source: NHEFS (National Health and Nutrition Examination Survey
            Epidemiologic Follow-up Study) from Hernán & Robins,
            "Causal Inference: What If" (2020)

    Input:  nhefs.dta (raw, 1,629 obs × 64 vars)
    Output: nhefs_tc.dta (cleaned, labeled, formatted)

    Usage:  stata-mp -b do cleaning.do
*/

version 16.0
set varabbrev off
set more off
clear all

// ─────────────────────────────────────────────────────────────────────
// 1. Load raw data
// ─────────────────────────────────────────────────────────────────────

use "nhefs.dta", clear


// ─────────────────────────────────────────────────────────────────────
// 2. Recode 2 → missing for variables that use 2 as a missing code
// ─────────────────────────────────────────────────────────────────────

foreach var in hbp diabetes hbpmed boweltrouble birthcontrol pica alcoholpy {
    replace `var' = . if `var' == 2
}

// marital == 8 is also coded as unknown
replace marital = . if marital == 8


// ─────────────────────────────────────────────────────────────────────
// 3. Rename variables for clarity
// ─────────────────────────────────────────────────────────────────────

rename seqn              id
rename qsmk              quit_smoking
rename yrdth             death_year
rename modth             death_month
rename dadth             death_day
rename ht                height
rename wt71              weight_71
rename wt82              weight_82
rename wt82_71           weight_change
rename smokeintensity    cigs_per_day
rename smkintensity82_71 cigs_change
rename smokeyrs          smoke_years
rename school            school_yrs
rename bronch            bronchitis
rename hf                heart_failure
rename hbp               high_bp
rename tb                tuberculosis
rename pepticulcer       peptic_ulcer
rename chroniccough      chronic_cough
rename nervousbreak      nervous_breakdown
rename alcoholpy         alcohol_past_yr
rename alcoholfreq       alcohol_freq
rename alcoholtype       alcohol_type
rename alcoholhowmuch    alcohol_amount
rename hbpmed            med_hbp
rename boweltrouble      med_bowel
rename headache          med_headache
rename otherpain         med_pain
rename weakheart         med_weakheart
rename allergies         med_allergies
rename nerves            med_nerves
rename lackpep           med_lackpep
rename wtloss            med_wtloss
rename infection         med_infection
rename birthcontrol      birth_control
rename hightax82         high_tax_82
rename price71_82        price_change
rename tax71_82          tax_change
rename cholesterol       cholesterol_71


// ─────────────────────────────────────────────────────────────────────
// 4. Define value labels
// ─────────────────────────────────────────────────────────────────────

// Binary: yes/no
label define yesno 0 "No" 1 "Yes"

// Sex
label define sex_lbl 0 "Male" 1 "Female"

// Race
label define race_lbl 0 "White" 1 "Black or other"

// Education
label define educ_lbl  ///
    1 "8th grade or less"  ///
    2 "HS dropout"         ///
    3 "HS graduate"        ///
    4 "College dropout"    ///
    5 "College or more"

// Income (1971 USD)
label define income_lbl  ///
    11 "<$1,000"         ///
    12 "$1,000-1,999"    ///
    13 "$2,000-2,999"    ///
    14 "$3,000-3,999"    ///
    15 "$4,000-4,999"    ///
    16 "$5,000-5,999"    ///
    17 "$6,000-6,999"    ///
    18 "$7,000-9,999"    ///
    19 "$10,000-14,999"  ///
    20 "$15,000-19,999"  ///
    21 "$20,000-24,999"  ///
    22 "$25,000+"

// Marital status
label define marital_lbl  ///
    2 "Married"       ///
    3 "Widowed"       ///
    4 "Never married" ///
    5 "Divorced"      ///
    6 "Separated"

// Daily activity
label define active_lbl  ///
    0 "Very active"       ///
    1 "Moderately active" ///
    2 "Inactive"

// Recreational exercise
label define exercise_lbl  ///
    0 "Much exercise"         ///
    1 "Moderate exercise"     ///
    2 "Little or no exercise"

// Alcohol frequency
label define alcfreq_lbl  ///
    0 "Almost every day"   ///
    1 "2-3 times/week"     ///
    2 "1-4 times/month"    ///
    3 "<12 times/year"     ///
    4 "None past year"     ///
    5 "Unknown"

// Alcohol type
label define alctype_lbl  ///
    1 "Beer"         ///
    2 "Wine"         ///
    3 "Liquor"       ///
    4 "Non-drinker"


// ─────────────────────────────────────────────────────────────────────
// 5. Attach value labels
// ─────────────────────────────────────────────────────────────────────

label values sex           sex_lbl
label values race          race_lbl
label values education     educ_lbl
label values income        income_lbl
label values marital       marital_lbl
label values active        active_lbl
label values exercise      exercise_lbl
label values alcohol_freq  alcfreq_lbl
label values alcohol_type  alctype_lbl

// Binary yes/no labels
foreach var in quit_smoking death high_bp diabetes asthma bronchitis  ///
    tuberculosis heart_failure peptic_ulcer colitis hepatitis         ///
    chronic_cough hayfever polio tumor nervous_breakdown              ///
    alcohol_past_yr pica high_tax_82 birth_control                   ///
    med_hbp med_bowel med_headache med_pain med_weakheart            ///
    med_allergies med_nerves med_lackpep med_wtloss med_infection {
    label values `var' yesno
}


// ─────────────────────────────────────────────────────────────────────
// 6. Variable labels
// ─────────────────────────────────────────────────────────────────────

label variable id                "Participant ID"
label variable quit_smoking      "Quit smoking 1971-1982"
label variable death             "Died by 1992"
label variable death_year        "Year of death"
label variable death_month       "Month of death"
label variable death_day         "Day of death"

label variable sex               "Sex"
label variable age               "Age in 1971"
label variable race              "Race"
label variable income            "Total family income in 1971"
label variable marital           "Marital status in 1971"
label variable school_yrs        "Highest grade completed in 1971"
label variable education         "Education level in 1971"
label variable birthplace        "State of birth (FIPS code)"

label variable height            "Height (cm) in 1971"
label variable weight_71         "Weight (kg) in 1971"
label variable weight_82         "Weight (kg) in 1982"
label variable weight_change     "Weight change (kg), 1982-1971"

label variable cigs_per_day      "Cigarettes per day in 1971"
label variable cigs_change       "Change in cigarettes/day, 1982-1971"
label variable smoke_years       "Years of smoking"

label variable sbp               "Systolic blood pressure (mmHg) in 1982"
label variable dbp               "Diastolic blood pressure (mmHg) in 1982"
label variable cholesterol_71    "Serum cholesterol (mg/dL) in 1971"

label variable asthma            "Dx asthma in 1971"
label variable bronchitis        "Dx chronic bronchitis/emphysema in 1971"
label variable tuberculosis      "Dx tuberculosis in 1971"
label variable heart_failure     "Dx heart failure in 1971"
label variable high_bp           "Dx high blood pressure in 1971"
label variable peptic_ulcer      "Dx peptic ulcer in 1971"
label variable colitis           "Dx colitis in 1971"
label variable hepatitis         "Dx hepatitis in 1971"
label variable chronic_cough     "Dx chronic cough in 1971"
label variable hayfever          "Dx hay fever in 1971"
label variable diabetes          "Dx diabetes in 1971"
label variable polio             "Dx polio in 1971"
label variable tumor             "Dx malignant tumor in 1971"
label variable nervous_breakdown "Dx nervous breakdown in 1971"

label variable alcohol_past_yr   "Drank in past year in 1971"
label variable alcohol_freq      "Alcohol frequency in 1971"
label variable alcohol_type      "Preferred alcohol type in 1971"
label variable alcohol_amount    "Drinks per occasion in 1971"

label variable active            "Daily activity level in 1971"
label variable exercise          "Recreational exercise in 1971"

label variable pica              "Eats non-food substances in 1971"
label variable pregnancies       "Total pregnancies in 1971"
label variable birth_control     "Birth control pills past 6 months in 1971"

label variable med_hbp           "Takes HBP medication in 1971"
label variable med_bowel         "Takes bowel medication in 1971"
label variable med_headache      "Takes headache medication in 1971"
label variable med_pain          "Takes pain medication in 1971"
label variable med_weakheart     "Takes weak heart medication in 1971"
label variable med_allergies     "Takes allergy medication in 1971"
label variable med_nerves        "Takes nerve medication in 1971"
label variable med_lackpep       "Takes lack-of-pep medication in 1971"
label variable med_wtloss        "Takes weight loss medication in 1971"
label variable med_infection     "Takes infection medication in 1971"

label variable high_tax_82       "High-tax tobacco state in 1982"
label variable price71           "Avg tobacco price in 1971 (2008 USD)"
label variable price82           "Avg tobacco price in 1982 (2008 USD)"
label variable price_change      "Tobacco price change, 1982-1971 (2008 USD)"
label variable tax71             "Tobacco tax in 1971 (2008 USD)"
label variable tax82             "Tobacco tax in 1982 (2008 USD)"
label variable tax_change        "Tobacco tax change, 1982-1971 (2008 USD)"


// ─────────────────────────────────────────────────────────────────────
// 7. Optimize storage types
// ─────────────────────────────────────────────────────────────────────

// Integer variables → int or byte
recast long id
recast byte quit_smoking death sex race education marital active exercise
recast byte asthma bronchitis tuberculosis heart_failure high_bp
recast byte peptic_ulcer colitis hepatitis chronic_cough hayfever
recast byte diabetes polio tumor nervous_breakdown
recast byte alcohol_past_yr alcohol_freq alcohol_type pica
recast byte high_tax_82 birth_control
recast byte med_hbp med_bowel med_headache med_pain med_weakheart
recast byte med_allergies med_nerves med_lackpep med_wtloss med_infection
recast int  age school_yrs cigs_per_day cigs_change smoke_years
recast int  death_year death_month death_day
recast int  income birthplace pregnancies alcohol_amount


// ─────────────────────────────────────────────────────────────────────
// 8. Display formats
// ─────────────────────────────────────────────────────────────────────

format id              %8.0g
format age             %3.0g
format school_yrs      %3.0g
format cigs_per_day    %3.0g
format cigs_change     %4.0g
format smoke_years     %3.0g
format height          %6.1f
format weight_71       %6.1f
format weight_82       %6.1f
format weight_change   %6.1f
format sbp             %4.0g
format dbp             %4.0g
format cholesterol_71  %4.0g
format price71         %6.2f
format price82         %6.2f
format price_change    %6.2f
format tax71           %6.2f
format tax82           %6.2f
format tax_change      %6.2f
format pregnancies     %3.0g
format alcohol_amount  %3.0g


// ─────────────────────────────────────────────────────────────────────
// 9. Order variables logically
// ─────────────────────────────────────────────────────────────────────

order id quit_smoking death death_year death_month death_day          ///
      sex age race income marital school_yrs education birthplace    ///
      height weight_71 weight_82 weight_change                      ///
      cigs_per_day cigs_change smoke_years                          ///
      sbp dbp cholesterol_71                                        ///
      asthma bronchitis tuberculosis heart_failure high_bp           ///
      peptic_ulcer colitis hepatitis chronic_cough hayfever         ///
      diabetes polio tumor nervous_breakdown                        ///
      alcohol_past_yr alcohol_freq alcohol_type alcohol_amount      ///
      active exercise                                               ///
      pica pregnancies birth_control                                ///
      med_hbp med_bowel med_headache med_pain med_weakheart         ///
      med_allergies med_nerves med_lackpep med_wtloss med_infection ///
      high_tax_82 price71 price82 price_change tax71 tax82 tax_change


// ─────────────────────────────────────────────────────────────────────
// 10. Dataset metadata and save
// ─────────────────────────────────────────────────────────────────────

label data "NHEFS — Cleaned for Stata-Tools examples"
note: Source: Hernán MA, Robins JM (2020). Causal Inference: What If.
note: Baseline (1971): N=1,629 smokers from NHANES I (ages 25-74).
note: Treatment: Quit smoking by 1982. Outcome: Weight change or death by 1992.
note: Cleaned: `c(current_date)'

compress
datasignature set

save "nhefs_tc.dta", replace

describe
