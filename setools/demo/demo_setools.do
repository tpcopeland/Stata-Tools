/*  demo_setools.do - Generate logdoc HTML screenshots for setools

    Produces 6 console sections, each rendered to HTML via logdoc:
      1. setools overview
      2. cci_se (Swedish Charlson Comorbidity Index)
      3. migrations (migration exclusions & censoring)
      4. sustainedss (sustained EDSS progression)
      5. cdp (confirmed disability progression)
      6. pira (progression independent of relapse activity)
*/

version 16.0
set varabbrev off
set linesize 120
set seed 20260319

* --- Paths ---
local pkg_dir "setools/demo"
capture mkdir "`pkg_dir'"

* --- Install from local source ---
capture ado uninstall setools
quietly net install setools, from("`c(pwd)'/setools") replace

capture ado uninstall logdoc
quietly net install logdoc, from("`c(pwd)'/logdoc") replace

* --- 1. setools overview ---
log using "`pkg_dir'/setools_overview.smcl", replace smcl name(s1) nomsg
noisily setools, detail
log close s1

* --- 2. cci_se — Swedish Charlson Comorbidity Index ---
use "`c(pwd)'/_data/diagnoses.dta", clear
log using "`pkg_dir'/cci_se.smcl", replace smcl name(s2) nomsg
noisily cci_se, id(id) icd(icd) date(visit_date) components noisily
noisily summarize charlson
log close s2

* --- 3. migrations — Migration exclusions & censoring ---
use "`c(pwd)'/_data/cohort.dta", clear
copy "`c(pwd)'/_data/migrations_wide.dta" "migrations_wide.dta", replace
log using "`pkg_dir'/migrations.smcl", replace smcl name(s3) nomsg
noisily migrations, migfile("migrations_wide.dta") startvar(study_entry) verbose
log close s3
capture erase "migrations_wide.dta"

* --- 4. sustainedss — Sustained EDSS progression ---
use "`c(pwd)'/_data/relapses.dta", clear
log using "`pkg_dir'/sustainedss.smcl", replace smcl name(s4) nomsg
noisily sustainedss id edss edss_date, threshold(4) keepall
noisily count if !missing(sustained4_dt)
log close s4

* --- 5. cdp — Confirmed disability progression ---
use "`c(pwd)'/_data/relapses.dta", clear
log using "`pkg_dir'/cdp.smcl", replace smcl name(s5) nomsg
noisily cdp id edss edss_date, dxdate(dx_date) keepall
noisily count if !missing(cdp_date)
log close s5

* --- 6. pira — Progression independent of relapse activity ---
use "`c(pwd)'/_data/relapses.dta", clear
copy "`c(pwd)'/_data/relapses_only.dta" "relapses_only.dta", replace
log using "`pkg_dir'/pira.smcl", replace smcl name(s6) nomsg
noisily pira id edss edss_date, dxdate(dx_date) ///
    relapses("relapses_only.dta") keepall
log close s6
capture erase "relapses_only.dta"

* --- Convert SMCL to HTML via logdoc ---
foreach section in setools_overview cci_se migrations ///
    sustainedss cdp pira {
    logdoc using "`pkg_dir'/`section'.smcl", ///
        output("`pkg_dir'/`section'.html") ///
        theme(light) highlight tables nodots replace quiet
}

* --- Cleanup ---
clear
