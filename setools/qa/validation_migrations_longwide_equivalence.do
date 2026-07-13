* validation_migrations_longwide_equivalence.do
* Synthetic long-vs-wide equivalence harness for migrations
*
* Purpose:
*   Build a wide migration file from long event data using the same historical
*   construction pattern supplied by the user, then verify that migrations
*   returns identical results when pointed at the long file or the derived
*   wide file.
*
* Scenarios:
*   E1: default options
*   E2: keepimmigrants
*   E3: minresidence(365)
*   E4: keepimmigrants + minresidence(365)

clear all
set more off
version 16.0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0

capture program drop run_test
program define run_test
    args name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  [PASS] `name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  [FAIL] `name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
    }
end

capture program drop build_wide_from_long
program define build_wide_from_long
    syntax , LONG(string) WIDE(string) IDVAR(name)

    use "`long'", clear
    gen long _event_order = _n
    gen double in_ = event_date if event_type == "Inv"
    gen double out_ = event_date if event_type == "Utv"
    gen byte inbin = event_type == "Inv"
    egen double first = min(event_date), by(`idvar')
    egen byte first_typeX = min(inbin) if event_date == first, by(`idvar')
    egen byte first_type = min(first_typeX), by(`idvar')

    tempfile temp migration_in migration_out base_ids
    save `temp', replace

    keep `idvar'
    duplicates drop `idvar', force
    save `base_ids', replace

    use `temp', clear
    keep if in_ != .
    count
    local has_in = (r(N) > 0)
    if `has_in' {
        bysort `idvar' (event_date _event_order): gen long count = _n
        replace count = count + 1 if first_type == 0
        keep `idvar' in_ count
        reshape wide in_, i(`idvar') j(count)
        save `migration_in', replace
    }

    use `temp', clear
    keep if out_ != .
    count
    local has_out = (r(N) > 0)
    if `has_out' {
        bysort `idvar' (event_date _event_order): gen long count = _n
        keep `idvar' out_ count
        reshape wide out_, i(`idvar') j(count)
        save `migration_out', replace
    }

    use `base_ids', clear
    if `has_in' merge 1:1 `idvar' using `migration_in', keep(1 3) nogen
    if `has_out' merge 1:1 `idvar' using `migration_out', keep(1 3) nogen
    if !`has_in' gen double in_1 = .
    if !`has_out' gen double out_1 = .
    format in_* out_* %td
    save "`wide'", replace
end

capture program drop assert_mig_equiv
program define assert_mig_equiv, rclass
    syntax , MASTER(string) LONG(string) WIDE(string) [KEEPImmigrants MINRes(integer 0)]

    local opts ""
    if "`keepimmigrants'" != "" local opts "`opts' keepimmigrants"
    if `minres' > 0 local opts "`opts' minresidence(`minres')"

    tempfile long_res wide_res long_excl wide_excl long_cens wide_cens

    use "`master'", clear
    migrations, migfile("`long'") `opts' saveexclude("`long_excl'") savecensor("`long_cens'") replace
    foreach s in N_excluded_emigrated N_excluded_inmigration N_excluded_abroad ///
        N_excluded_minresidence N_excluded_total N_censored ///
        N_included_inmigration N_final {
        local long_`s' = r(`s')
    }
    capture confirm variable migration_in_dt
    if _rc gen long migration_in_dt = .
    keep id study_start migration_out_dt migration_in_dt
    sort id
    save `long_res', replace

    use "`master'", clear
    migrations, migfile("`wide'") `opts' saveexclude("`wide_excl'") savecensor("`wide_cens'") replace
    foreach s in N_excluded_emigrated N_excluded_inmigration N_excluded_abroad ///
        N_excluded_minresidence N_excluded_total N_censored ///
        N_included_inmigration N_final {
        local wide_`s' = r(`s')
    }
    capture confirm variable migration_in_dt
    if _rc gen long migration_in_dt = .
    keep id study_start migration_out_dt migration_in_dt
    sort id
    save `wide_res', replace

    local ok = 1
    foreach s in N_excluded_emigrated N_excluded_inmigration N_excluded_abroad ///
        N_excluded_minresidence N_excluded_total N_censored ///
        N_included_inmigration N_final {
        if `long_`s'' != `wide_`s'' local ok = 0
    }

    use `long_res', clear
    rename study_start study_start_long
    rename migration_out_dt migration_out_dt_long
    rename migration_in_dt migration_in_dt_long
    merge 1:1 id using `wide_res', nogen
    gen byte eq_start = (study_start_long == study_start)
    gen byte eq_out = (migration_out_dt_long == migration_out_dt) | ///
        (missing(migration_out_dt_long) & missing(migration_out_dt))
    gen byte eq_in = (migration_in_dt_long == migration_in_dt) | ///
        (missing(migration_in_dt_long) & missing(migration_in_dt))
    quietly count if eq_start != 1 | eq_out != 1 | eq_in != 1
    if r(N) > 0 local ok = 0

    use `long_excl', clear
    capture confirm variable exclude_reason
    if _rc gen str80 exclude_reason = ""
    keep id exclude_reason
    sort id
    rename exclude_reason exclude_reason_long
    tempfile long_excl_norm
    save `long_excl_norm', replace

    use `wide_excl', clear
    capture confirm variable exclude_reason
    if _rc gen str80 exclude_reason = ""
    keep id exclude_reason
    sort id
    merge 1:1 id using `long_excl_norm', nogen
    gen byte eq_reason = (exclude_reason == exclude_reason_long)
    quietly count if eq_reason != 1
    if r(N) > 0 local ok = 0

    use `long_cens', clear
    capture confirm variable migration_in_dt
    if _rc gen long migration_in_dt = .
    keep id migration_out_dt migration_in_dt
    sort id
    rename migration_out_dt migration_out_dt_long
    rename migration_in_dt migration_in_dt_long
    tempfile long_cens_norm
    save `long_cens_norm', replace

    use `wide_cens', clear
    capture confirm variable migration_in_dt
    if _rc gen long migration_in_dt = .
    keep id migration_out_dt migration_in_dt
    sort id
    merge 1:1 id using `long_cens_norm', nogen
    gen byte eq_cens_out = (migration_out_dt == migration_out_dt_long) | ///
        (missing(migration_out_dt) & missing(migration_out_dt_long))
    gen byte eq_cens_in = (migration_in_dt == migration_in_dt_long) | ///
        (missing(migration_in_dt) & missing(migration_in_dt_long))
    quietly count if eq_cens_out != 1 | eq_cens_in != 1
    if r(N) > 0 local ok = 0

    return scalar ok = `ok'
end

* === Synthetic cohort ===
clear
set obs 14
gen long id = _n
gen long study_start = td(01jan2018)
format study_start %td
tempfile master
save `master', replace

* === Synthetic long migration data ===
clear
set obs 29
gen long id = .
gen double event_date = .
gen str3 event_type = ""

* 2: Type 1
replace id = 2 in 1
replace event_date = td(01dec2016) in 1
replace event_type = "Utv" in 1

* 3: Type 2
replace id = 3 in 2
replace event_date = td(20feb2018) in 2
replace event_type = "Inv" in 2

* 4: Type 3
replace id = 4 in 3/4
replace event_date = td(01dec2016) in 3
replace event_type = "Utv" in 3
replace event_date = td(01feb2018) in 4
replace event_type = "Inv" in 4

* 5: Permanent post-start emigration
replace id = 5 in 5
replace event_date = td(01jun2020) in 5
replace event_type = "Utv" in 5

* 6: Temporary post-start emigration
replace id = 6 in 6/8
replace event_date = td(01mar2015) in 6
replace event_type = "Inv" in 6
replace event_date = td(01jun2020) in 7
replace event_type = "Utv" in 7
replace event_date = td(01jan2021) in 8
replace event_type = "Inv" in 8

* 7: Temporary then permanent
replace id = 7 in 9/12
replace event_date = td(01jan2014) in 9
replace event_type = "Inv" in 9
replace event_date = td(01jun2019) in 10
replace event_type = "Utv" in 10
replace event_date = td(01dec2019) in 11
replace event_type = "Inv" in 11
replace event_date = td(01jun2021) in 12
replace event_type = "Utv" in 12

* 8: minresidence fail
replace id = 8 in 13
replace event_date = td(23sep2017) in 13
replace event_type = "Inv" in 13

* 9: minresidence boundary pass
replace id = 9 in 14
replace event_date = td(01jan2017) in 14
replace event_type = "Inv" in 14

* 10: Returned before baseline
replace id = 10 in 15/17
replace event_date = td(01jan2016) in 15
replace event_type = "Inv" in 15
replace event_date = td(01jan2017) in 16
replace event_type = "Utv" in 16
replace event_date = td(01jun2017) in 17
replace event_type = "Inv" in 17

* 11: Multiple pre-start trips ending abroad (Type 1)
replace id = 11 in 18/21
replace event_date = td(01jan2014) in 18
replace event_type = "Inv" in 18
replace event_date = td(01jan2015) in 19
replace event_type = "Utv" in 19
replace event_date = td(01jan2016) in 20
replace event_type = "Inv" in 20
replace event_date = td(15dec2017) in 21
replace event_type = "Utv" in 21

* 12: Duplicate post-start immigration rows
replace id = 12 in 22/23
replace event_date = td(01mar2018) in 22/23
replace event_type = "Inv" in 22/23

* 13: Same-day out then in after study start
replace id = 13 in 24/26
replace event_date = td(01jan2010) in 24
replace event_type = "Inv" in 24
replace event_date = td(01jun2020) in 25
replace event_type = "Utv" in 25
replace event_date = td(01jun2020) in 26
replace event_type = "Inv" in 26

* 14: Same-day in then out after study start
replace id = 14 in 27/29
replace event_date = td(01jan2010) in 27
replace event_type = "Inv" in 27
replace event_date = td(01jun2020) in 28
replace event_type = "Inv" in 28
replace event_date = td(01jun2020) in 29
replace event_type = "Utv" in 29

format event_date %td
tempfile mig_long mig_wide
save `mig_long', replace

build_wide_from_long, long("`mig_long'") wide("`mig_wide'") idvar(id)

* === Equivalence checks ===
assert_mig_equiv, master("`master'") long("`mig_long'") wide("`mig_wide'")
run_test "E1: default long vs wide equivalence" `=r(ok)'

assert_mig_equiv, master("`master'") long("`mig_long'") wide("`mig_wide'") keepimmigrants
run_test "E2: keepimmigrants long vs wide equivalence" `=r(ok)'

assert_mig_equiv, master("`master'") long("`mig_long'") wide("`mig_wide'") minres(365)
run_test "E3: minresidence(365) long vs wide equivalence" `=r(ok)'

assert_mig_equiv, master("`master'") long("`mig_long'") wide("`mig_wide'") keepimmigrants minres(365)
run_test "E4: keepimmigrants + minresidence(365) long vs wide equivalence" `=r(ok)'

* === Summary ===
display _newline "=== LONG/WIDE EQUIVALENCE SUMMARY ==="
display "Passed: " scalar(gs_npass)
display "Failed: " scalar(gs_nfail)
display "Total:  " scalar(gs_ntest)
display "RESULT: validation_migrations_longwide_equivalence tests=" ///
    scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)

if scalar(gs_nfail) > 0 {
    display as error _newline "FAILED: " scalar(gs_nfail) " test(s) failed"
    exit 9
}
else {
    display as result _newline "ALL TESTS PASSED"
}

do "`qa_dir'/_setools_qa_common.do" teardown
