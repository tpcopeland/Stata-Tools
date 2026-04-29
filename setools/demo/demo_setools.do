/*  demo_setools.do - Generate logdoc HTML screenshots for setools

    Produces 7 console sections, each rendered to HTML via logdoc:
      1. setools overview
      2. cci_se (Swedish Charlson Comorbidity Index)
      3. procmatch (KVÅ procedure code matching)
      4. migrations (migration exclusions & censoring)
      5. sustainedss (sustained EDSS progression)
      6. cdp (confirmed disability progression)
      7. pira (progression independent of relapse activity)
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

* --- 3. procmatch — Procedure code matching ---
use "`c(pwd)'/_data/procedures.dta", clear
log using "`pkg_dir'/procmatch.smcl", replace smcl name(s3) nomsg
noisily procmatch match, codes("FNG02 FNG05") procvars(kva_code) ///
    generate(cardiac_proc) noisily
noisily procmatch match, codes("FNG") procvars(kva_code) ///
    generate(cardiac_prefix) prefix noisily
noisily procmatch first, codes("FNG02 FNG05") procvars(kva_code) ///
    datevar(proc_date) idvar(id) ///
    generate(cardiac_ever) gendatevar(cardiac_dt) noisily
log close s3

* --- 4. migrations — Migration exclusions & censoring ---
use "`c(pwd)'/_data/cohort.dta", clear
copy "`c(pwd)'/_data/migrations_wide.dta" "migrations_wide.dta", replace
log using "`pkg_dir'/migrations.smcl", replace smcl name(s4) nomsg
noisily migrations, migfile("migrations_wide.dta") startvar(study_entry) verbose
log close s4
capture erase "migrations_wide.dta"

* --- 5. sustainedss — Sustained EDSS progression ---
use "`c(pwd)'/_data/relapses.dta", clear
log using "`pkg_dir'/sustainedss.smcl", replace smcl name(s5) nomsg
noisily sustainedss id edss edss_date, threshold(4) keepall
noisily count if !missing(sustained4_dt)
log close s5

* --- 6. cdp — Confirmed disability progression ---
use "`c(pwd)'/_data/relapses.dta", clear
log using "`pkg_dir'/cdp.smcl", replace smcl name(s6) nomsg
noisily cdp id edss edss_date, dxdate(dx_date) keepall
noisily count if !missing(cdp_date)
log close s6

* --- 7. pira — Progression independent of relapse activity ---
use "`c(pwd)'/_data/relapses.dta", clear
copy "`c(pwd)'/_data/relapses_only.dta" "relapses_only.dta", replace
log using "`pkg_dir'/pira.smcl", replace smcl name(s7) nomsg
noisily pira id edss edss_date, dxdate(dx_date) ///
    relapses("relapses_only.dta") keepall
log close s7
capture erase "relapses_only.dta"

* --- Convert SMCL to HTML via logdoc ---
foreach section in setools_overview cci_se procmatch migrations ///
    sustainedss cdp pira {
    logdoc using "`pkg_dir'/`section'.smcl", ///
        output("`pkg_dir'/`section'.html") ///
        theme(light) highlight tables nodots replace quiet
}

* --- Cleanup ---
clear
