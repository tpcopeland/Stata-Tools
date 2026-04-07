/*  demo_setools.do - Generate screenshots for setools package

    Produces 1 output type:
      1. Console output (all 7 commands demonstrated) -> .smcl

    Commands covered:
      - setools (package overview)
      - cci_se (Charlson Comorbidity Index)
      - procmatch (procedure code matching)
      - migrations (migration exclusions/censoring)
      - sustainedss (sustained EDSS progression)
      - cdp (Confirmed Disability Progression)
      - pira (Progression Independent of Relapse Activity)
*/

version 16.0
set more off
set varabbrev off
set seed 20260319

* --- Paths ---
local pkg_dir "setools/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload all commands ---
foreach cmd in setools cci_se procmatch ///
    migrations sustainedss cdp pira {
    capture program drop `cmd'
}
* Drop setools detail helper
capture program drop _setools_detail

quietly run setools/setools.ado
quietly run setools/cci_se.ado
quietly run setools/procmatch.ado
quietly run setools/migrations.ado
quietly run setools/sustainedss.ado
quietly run setools/cdp.ado
quietly run setools/pira.ado

* =====================================================================
* CONSOLE OUTPUT
* =====================================================================
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* =============================================================
* 1. setools — Package Overview
* =============================================================
noisily setools, detail

* =============================================================
* 2. cci_se — Swedish Charlson Comorbidity Index
* =============================================================
* Generate synthetic diagnosis data (ICD-10 codes)
clear
set obs 500
gen long id = ceil(_n / 5)
gen str5 icd = ""
* Assign realistic ICD-10 codes
replace icd = "I219" if mod(_n, 17) == 0
replace icd = "E119" if mod(_n, 13) == 0
replace icd = "J449" if mod(_n, 19) == 0
replace icd = "C509" if mod(_n, 23) == 0
replace icd = "N189" if mod(_n, 29) == 0
replace icd = "F009" if mod(_n, 31) == 0
replace icd = "G459" if mod(_n, 37) == 0
replace icd = "I500" if mod(_n, 41) == 0
replace icd = "K259" if mod(_n, 43) == 0
replace icd = "M069" if mod(_n, 47) == 0
* Fill remaining with benign codes
replace icd = "Z000" if icd == ""
gen double visit_date = mdy(1,1,2010) + floor(runiform() * 4380)
format visit_date %tdCCYY/NN/DD

noisily display _newline as text "{bf:Charlson Comorbidity Index from ICD-10 codes}"
noisily cci_se, id(id) icd(icd) date(visit_date) components noisily
noisily display _newline as text "Patient-level CCI distribution:"
noisily tabulate charlson

* =============================================================
* 3. procmatch — Procedure Code Matching
* =============================================================
noisily display _newline as text "{bf:Procedure Code Matching (KVÅ)}"

* Generate synthetic procedure data
clear
set obs 200
gen long id = ceil(_n / 4)
gen str6 kva_code = ""
replace kva_code = "FNG02" if mod(_n, 7) == 0
replace kva_code = "FNG05" if mod(_n, 11) == 0
replace kva_code = "DA024" if mod(_n, 13) == 0
replace kva_code = "JAB30" if mod(_n, 17) == 0
replace kva_code = "ZXA00" if kva_code == ""
gen double proc_date = mdy(1,1,2015) + floor(runiform() * 2555)
format proc_date %tdCCYY/NN/DD

* Exact match
noisily procmatch match, codes("FNG02 FNG05") procvars(kva_code) ///
    generate(cardiac_proc) noisily

* Prefix match
noisily procmatch match, codes("FNG") procvars(kva_code) ///
    generate(cardiac_prefix) prefix noisily

* First occurrence date
noisily procmatch first, codes("FNG02 FNG05") procvars(kva_code) ///
    datevar(proc_date) idvar(id) ///
    generate(cardiac_ever) gendatevar(cardiac_dt) noisily

* =============================================================
* 4. migrations — Migration Exclusions & Censoring
* =============================================================
noisily display _newline as text "{bf:Migration Processing}"

* Create synthetic master cohort
clear
set obs 100
gen long id = _n
gen double study_start = mdy(1,1,2015) + floor(runiform() * 730)
format study_start %tdCCYY/NN/DD
tempfile cohort_data
save `cohort_data'

* Create synthetic migration data (wide format)
clear
set obs 100
gen long id = _n
gen double in_1 = mdy(1,1,2000) + floor(runiform() * 3650) if runiform() < 0.3
gen double out_1 = in_1 + 365 + floor(runiform() * 1825) if !missing(in_1)
gen double in_2 = out_1 + 180 + floor(runiform() * 730) if runiform() < 0.4 & !missing(out_1)
gen double out_2 = .
format in_* out_* %tdCCYY/NN/DD
tempfile mig_file
save `mig_file'

* Process migrations
use `cohort_data', clear
noisily migrations, migfile("`mig_file'") idvar(id) startvar(study_start) verbose

* =============================================================
* 5. sustainedss — Sustained EDSS Progression
* =============================================================
noisily display _newline as text "{bf:Sustained EDSS Progression}"

* Generate synthetic MS EDSS data
clear
set obs 500
gen long id = ceil(_n / 10)
bysort id: gen visit_num = _n
gen double edss_date = mdy(1,1,2010) + (visit_num - 1) * 180 + floor(runiform() * 60)
format edss_date %tdCCYY/NN/DD

* Simulate progressive disability trajectory
bysort id: gen double edss = 1.0 + (_n - 1) * 0.3 + rnormal() * 0.5
replace edss = max(0, min(10, round(edss * 2, 1) / 2))

noisily sustainedss id edss edss_date, threshold(4) keepall

* =============================================================
* 6. cdp — Confirmed Disability Progression
* =============================================================
noisily display _newline as text "{bf:Confirmed Disability Progression (CDP)}"

* Rebuild EDSS data with diagnosis dates
clear
set obs 500
gen long id = ceil(_n / 10)
bysort id: gen visit_num = _n
gen double edss_date = mdy(1,1,2012) + (visit_num - 1) * 180 + floor(runiform() * 60)
format edss_date %tdCCYY/NN/DD
gen double edss = 1.5 + (_n / 50) * 0.2 + rnormal() * 0.8
replace edss = max(0, min(10, round(edss * 2, 1) / 2))
gen double dx_date = mdy(6,15,2011)
format dx_date %tdCCYY/NN/DD

noisily cdp id edss edss_date, dxdate(dx_date) keepall

* =============================================================
* 7. pira — Progression Independent of Relapse Activity
* =============================================================
noisily display _newline as text "{bf:PIRA — Progression Independent of Relapse Activity}"

* Rebuild EDSS data
clear
set obs 500
gen long id = ceil(_n / 10)
bysort id: gen visit_num = _n
gen double edss_date = mdy(1,1,2012) + (visit_num - 1) * 180 + floor(runiform() * 60)
format edss_date %tdCCYY/NN/DD
gen double edss = 1.5 + (_n / 50) * 0.2 + rnormal() * 0.8
replace edss = max(0, min(10, round(edss * 2, 1) / 2))
gen double dx_date = mdy(6,15,2011)
format dx_date %tdCCYY/NN/DD
tempfile edss_data
save `edss_data'

* Create relapse dataset
clear
set obs 80
gen long id = ceil(runiform() * 50)
gen double relapse_date = mdy(1,1,2013) + floor(runiform() * 2555)
format relapse_date %tdCCYY/NN/DD
tempfile relapse_data
save `relapse_data'

* Run PIRA
use `edss_data', clear
noisily pira id edss edss_date, dxdate(dx_date) ///
    relapses("`relapse_data'") keepall

log close demo

* --- Cleanup ---
clear
