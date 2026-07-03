* validation_migrations_type2_censoring.do
* Known-answer validation for v1.4.1 migrations correctness fixes:
*   1. Type 2 classification: a person whose first-ever migration event is a
*      post-start immigration is abroad at baseline even when a later
*      post-start emigration exists (previously silently retained).
*   2. keepimmigrants: included immigrants who later emigrate permanently
*      receive their migration_out_dt censoring date.
*   3. Migration-file columns other than id/in_*/out_* are ignored and can
*      never shadow master-data values (e.g. a stray study_start column).
*   4. Custom idvar() name works across all of the above.
*
* Run from setools/qa:
*     stata-mp -b do validation_migrations_type2_censoring.do

clear all
version 16.0
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall setools
quietly net install setools, from("`pkg_dir'") replace

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_val
program define run_val
    args test_name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  [PASS] `test_name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  [FAIL] `test_name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
        global gs_failures `"${gs_failures} `test_name'"'
    }
end

**# Fixture
* study_start = 01jan2018 for everyone.
* Person 1: in 01mar2019, out 01jun2020            -> Type 2 (abroad at baseline,
*           later emigration must not launder them into the cohort);
*           under keepimmigrants: included with in AND out dates.
* Person 2: no migration records                    -> retained, no dates.
* Person 3: out 01jun2019, in 01aug2019             -> first post-start event is an
*           emigration (born in Sweden): retained, returned, no censor date.
* Person 4: in 01mar2019 only                       -> classic Type 2 (regression).
* Person 5: in 01mar2019, out 01jun2020, in 01aug2021 -> Type 2; under
*           keepimmigrants the 01jun2020 emigration is NOT permanent (returned),
*           so migration_out_dt stays missing.

tempfile master mig_wide mig_long

clear
set obs 5
gen long id = _n
gen long study_start = td(01jan2018)
format study_start %td
save `master', replace

clear
input long id double(in_1 out_1 in_2)
1 . . .
3 . . .
4 . . .
5 . . .
end
replace in_1  = td(01mar2019) if id == 1
replace out_1 = td(01jun2020) if id == 1
replace out_1 = td(01jun2019) if id == 3
replace in_1  = td(01aug2019) if id == 3
replace in_1  = td(01mar2019) if id == 4
replace in_1  = td(01mar2019) if id == 5
replace out_1 = td(01jun2020) if id == 5
replace in_2  = td(01aug2021) if id == 5
format in_* out_* %td
save `mig_wide', replace

clear
set obs 8
gen long id = .
gen long event_date = .
gen str3 event_type = ""
replace id = 1 in 1
replace event_date = td(01mar2019) in 1
replace event_type = "Inv" in 1
replace id = 1 in 2
replace event_date = td(01jun2020) in 2
replace event_type = "Utv" in 2
replace id = 3 in 3
replace event_date = td(01jun2019) in 3
replace event_type = "Utv" in 3
replace id = 3 in 4
replace event_date = td(01aug2019) in 4
replace event_type = "Inv" in 4
replace id = 4 in 5
replace event_date = td(01mar2019) in 5
replace event_type = "Inv" in 5
replace id = 5 in 6
replace event_date = td(01mar2019) in 6
replace event_type = "Inv" in 6
replace id = 5 in 7
replace event_date = td(01jun2020) in 7
replace event_type = "Utv" in 7
replace id = 5 in 8
replace event_date = td(01aug2021) in 8
replace event_type = "Inv" in 8
format event_date %td
save `mig_long', replace

capture program drop _check_type2_default
program define _check_type2_default
    args source_name

    local ok = (r(N_excluded_inmigration) == 3 & ///
        r(N_excluded_total) == 3 & ///
        r(N_final) == 2)
    run_val "`source_name': default excludes first-event-immigration persons (Type 2)" `ok'

    sort id
    local ok = (_N == 2 & id[1] == 2 & id[2] == 3)
    run_val "`source_name': final cohort keeps only baseline residents" `ok'

    quietly count if !missing(migration_out_dt)
    local ok = (r(N) == 0)
    run_val "`source_name': returned emigrant (out-first) has no censor date" `ok'
end

capture program drop _check_type2_keepimm
program define _check_type2_keepimm
    args source_name

    local ok = (r(N_excluded_inmigration) == 0 & ///
        r(N_included_inmigration) == 3 & ///
        r(N_final) == 5)
    run_val "`source_name': keepimmigrants retains all Type 2 persons" `ok'

    sort id
    quietly count if !missing(migration_in_dt) & inlist(id, 1, 4, 5)
    local ok = (r(N) == 3)
    quietly summarize migration_in_dt if id == 1, meanonly
    local ok = (`ok' & r(mean) == td(01mar2019))
    quietly count if !missing(migration_in_dt) & inlist(id, 2, 3)
    local ok = (`ok' & r(N) == 0)
    run_val "`source_name': migration_in_dt set exactly for included immigrants" `ok'

    quietly summarize migration_out_dt if id == 1, meanonly
    local ok = (r(N) == 1 & r(mean) == td(01jun2020))
    run_val "`source_name': included immigrant with permanent emigration is censored" `ok'

    quietly count if !missing(migration_out_dt) & id != 1
    local ok = (r(N) == 0)
    run_val "`source_name': non-permanent emigration of included immigrant not censored" `ok'
end

**# Wide format
use `master', clear
migrations, migfile("`mig_wide'")
_check_type2_default "wide"

use `master', clear
migrations, migfile("`mig_wide'") keepimmigrants
_check_type2_keepimm "wide"

**# Long format
use `master', clear
migrations, migfile("`mig_long'")
_check_type2_default "long"

use `master', clear
migrations, migfile("`mig_long'") keepimmigrants
_check_type2_keepimm "long"

**# Shadowing guard: migration file carrying master-named columns is inert
preserve
use `mig_wide', clear
gen long study_start = td(01jan2030)
gen str10 exclude_reason = "bogus"
format study_start %td
tempfile mig_shadow
save `mig_shadow', replace
restore

use `master', clear
migrations, migfile("`mig_shadow'") keepimmigrants
local ok = (r(N_included_inmigration) == 3 & r(N_final) == 5 & ///
    r(N_excluded_emigrated) == 0)
quietly summarize migration_out_dt if id == 1, meanonly
local ok = (`ok' & r(N) == 1 & r(mean) == td(01jun2020))
capture confirm variable exclude_reason
local ok = (`ok' & _rc != 0)
run_val "shadow: migfile study_start/exclude_reason columns never override master" `ok'

**# Custom idvar() name (QA coverage for the idvar option)
use `master', clear
rename id patient_no
tempfile master_pn
save `master_pn', replace

preserve
use `mig_wide', clear
rename id patient_no
tempfile mig_pn
save `mig_pn', replace
restore

use `master_pn', clear
migrations, migfile("`mig_pn'") idvar(patient_no)
local ok = (r(N_excluded_inmigration) == 3 & r(N_final) == 2)
sort patient_no
local ok = (`ok' & _N == 2 & patient_no[1] == 2 & patient_no[2] == 3)
run_val "idvar: custom ID variable name classifies identically" `ok'

**# Summary
display as text "Total tests:  " scalar(gs_ntest)
display as result "Passed:       " scalar(gs_npass)
if scalar(gs_nfail) > 0 {
    display as error "Failed:       " scalar(gs_nfail)
    display as error "Failed tests: ${gs_failures}"
}
else {
    display as text "Failed:       " scalar(gs_nfail)
}

if scalar(gs_nfail) > 0 {
    display as error "SOME TESTS FAILED"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
}
