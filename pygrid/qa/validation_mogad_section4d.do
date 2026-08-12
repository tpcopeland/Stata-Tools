*! validation_mogad_section4d.do Version 1.0.0  2026/08/12
*! Reproduce the six MOGAD Combined section 4d tables with pygrid/pyattach
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
capture log close _all
log using "validation_mogad_section4d.log", replace text

do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

**# One-grid, five-attachment equivalence with six manual tables
capture noisily {
    local study_start = td(01jan2001)
    local study_end = td(31dec2024)
    local pdr_start = td(01jul2005)
    local cost_er_visit = 6085
    local cost_op_doctor = 6085
    local cost_inpatient_day = 18086
    local sek_per_eur = 11.4325

    tempfile people manual_grid pdr_grid
    tempfile outpatient_events inpatient_events rx_events
    tempfile ref_er ref_op ref_ip ref_rx ref_related ref_cost
    tempfile ref_op_cost ref_ip_cost ref_rx_cost

    * Deterministic, MOGAD-shaped source cohort. Every group-year has at
    * least five eligible people, while partial calendar years make exact
    * person-time consequential to the rate summaries.
    clear
    set obs 24
    generate long id = _n
    generate byte mogad = id <= 12
    generate double indexdt = td(01jul2011)
    generate double window_start = cond(mod(id, 2) == 0, ///
        td(15mar2010), td(01jan2010))
    generate double window_end = cond(mod(id, 3) == 0, ///
        td(20oct2012), td(31dec2012))
    format indexdt window_start window_end %td
    assert window_start >= `study_start'
    assert window_end <= `study_end'
    assert window_end >= window_start
    save `people'

    * Manual denominator used by the study code.
    generate int first_year = year(window_start)
    generate int last_year = year(window_end)
    generate int n_years = last_year - first_year + 1
    expand n_years
    bysort id: generate int calendar_year = first_year + _n - 1
    generate double person_start = max(window_start, mdy(1, 1, calendar_year))
    generate double person_end = min(window_end, mdy(12, 31, calendar_year))
    generate double person_years = (person_end - person_start + 1) / 365.25
    generate int rel_year = calendar_year - year(indexdt)
    assert person_years > 0 & person_years <= 1.01
    keep id mogad calendar_year rel_year person_start person_end person_years
    sort id rel_year
    save `manual_grid'

    preserve
    keep if calendar_year >= 2005
    replace person_start = max(person_start, `pdr_start') if calendar_year == 2005
    drop if person_end < person_start
    replace person_years = (person_end - person_start + 1) / 365.25
    save `pdr_grid'
    restore

    * Outpatient events: some person-years deliberately have no event.
    clear
    set obs 144
    generate long id = ceil(_n / 6)
    generate byte slot = mod(_n - 1, 6) + 1
    generate double visitdt = cond(slot == 1, td(01apr2010), ///
        cond(slot == 2, td(31dec2010), ///
        cond(slot == 3, td(01jan2011), ///
        cond(slot == 4, td(30sep2011), ///
        cond(slot == 5, td(01jul2012), td(01oct2012))))))
    generate byte is_er = inlist(slot, 1, 3, 6)
    generate byte mogad_related = mod(id + slot, 3) == 0
    drop if mod(id + year(visitdt), 4) == 0
    format visitdt %td
    drop slot
    save `outpatient_events'

    * Inpatient events include varying LOS, ICU, and related indicators.
    clear
    set obs 72
    generate long id = ceil(_n / 3)
    generate byte slot = mod(_n - 1, 3) + 1
    generate double admitdt = cond(slot == 1, td(01jun2010), ///
        cond(slot == 2, td(01jun2011), td(01sep2012)))
    generate double los = mod(id + slot, 5) + 1
    generate byte is_icu = mod(id + slot, 7) == 0
    generate byte mogad_related = mod(id + 2 * slot, 4) == 0
    drop if mod(id + year(admitdt), 5) == 0
    format admitdt %td
    drop slot
    save `inpatient_events'

    * The current study delivery has no drug-cost variable, so the cost is
    * explicitly missing while medication counts remain observable.
    clear
    set obs 72
    generate long id = ceil(_n / 3)
    generate byte slot = mod(_n - 1, 3) + 1
    generate double dispdt = cond(slot == 1, td(01aug2010), ///
        cond(slot == 2, td(01aug2011), td(01aug2012)))
    generate byte mogad_med = mod(id + slot, 3) != 0
    generate double mogad_drug_cost = .
    drop if mod(id + year(dispdt), 6) == 0
    format dispdt %td
    drop slot
    save `rx_events'

    **# Manual MOGAD Combined section 4d reference tables
    use `outpatient_events', clear
    merge m:1 id using `people', keepusing(indexdt) nogen assert(match)
    generate int rel_year = year(visitdt) - year(indexdt)
    collapse (sum) n_er=is_er, by(id rel_year)
    merge 1:1 id rel_year using `manual_grid', nogen keep(match using)
    replace n_er = 0 if missing(n_er)
    generate byte had_er = n_er > 0
    generate double er_rate = n_er / person_years
    sort mogad rel_year id
    collapse (count) n_patients=id (mean) mean_er=n_er (sd) sd_er=n_er ///
        (mean) mean_er_rate=er_rate pct_any_er=had_er ///
        (sum) total_er=n_er total_py=person_years, by(mogad rel_year)
    generate double er_rate_per_py = total_er / total_py
    drop if n_patients < 5
    sort mogad rel_year
    save `ref_er'

    use `outpatient_events', clear
    merge m:1 id using `people', keepusing(indexdt) nogen assert(match)
    generate int rel_year = year(visitdt) - year(indexdt)
    generate byte specialist_visit = is_er == 0
    collapse (sum) n_visits=specialist_visit, by(id rel_year)
    merge 1:1 id rel_year using `manual_grid', nogen keep(match using)
    replace n_visits = 0 if missing(n_visits)
    generate double visit_rate = n_visits / person_years
    sort mogad rel_year id
    collapse (count) n_patients=id (mean) mean_visits=n_visits ///
        mean_visit_rate=visit_rate (sd) sd_visits=n_visits ///
        (p50) median_visits=n_visits ///
        (sum) total_visits=n_visits total_py=person_years, by(mogad rel_year)
    generate double visit_rate_per_py = total_visits / total_py
    drop if n_patients < 5
    sort mogad rel_year
    save `ref_op'

    use `inpatient_events', clear
    merge m:1 id using `people', keepusing(indexdt) nogen assert(match)
    generate int rel_year = year(admitdt) - year(indexdt)
    collapse (count) n_admissions=admitdt ///
        (sum) total_los=los n_related=mogad_related ///
        (max) any_icu=is_icu, by(id rel_year)
    merge 1:1 id rel_year using `manual_grid', nogen keep(match using)
    foreach variable in n_admissions total_los n_related any_icu {
        replace `variable' = 0 if missing(`variable')
    }
    generate double n_nonrelated = n_admissions - n_related
    generate double admission_rate = n_admissions / person_years
    sort mogad rel_year id
    collapse (count) n_patients=id ///
        (mean) mean_admissions=n_admissions mean_admission_rate=admission_rate ///
        mean_los=total_los mean_related=n_related mean_nonrelated=n_nonrelated ///
        pct_icu=any_icu (sd) sd_admissions=n_admissions sd_los=total_los ///
        (sum) total_admissions=n_admissions total_py=person_years, by(mogad rel_year)
    generate double admission_rate_per_py = total_admissions / total_py
    drop if n_patients < 5
    sort mogad rel_year
    save `ref_ip'

    use `rx_events', clear
    merge m:1 id using `people', keepusing(indexdt) nogen assert(match)
    generate int rel_year = year(dispdt) - year(indexdt)
    collapse (sum) n_rx=mogad_med total_drug_cost=mogad_drug_cost, by(id rel_year)
    merge 1:1 id rel_year using `pdr_grid', nogen keep(match using)
    replace n_rx = 0 if missing(n_rx)
    replace total_drug_cost = .
    generate byte had_mogad_rx = n_rx > 0
    generate double rx_rate = n_rx / person_years
    sort mogad rel_year id
    collapse (count) n_patients=id ///
        (mean) mean_rx=n_rx mean_cost=total_drug_cost pct_any=had_mogad_rx ///
        mean_rx_rate=rx_rate (sd) sd_rx=n_rx sd_cost=total_drug_cost ///
        (sum) total_rx=n_rx total_py=person_years, by(mogad rel_year)
    generate double rx_rate_per_py = total_rx / total_py
    drop if n_patients < 5
    generate double mean_cost_eur = mean_cost / `sek_per_eur'
    sort mogad rel_year
    save `ref_rx'

    use `outpatient_events', clear
    merge m:1 id using `people', keepusing(indexdt) nogen assert(match)
    generate int rel_year = year(visitdt) - year(indexdt)
    collapse (sum) n_mogad_visits=mogad_related ///
        (count) n_total_visits=mogad_related, by(id rel_year)
    merge 1:1 id rel_year using `manual_grid', nogen keep(match using)
    replace n_mogad_visits = 0 if missing(n_mogad_visits)
    replace n_total_visits = 0 if missing(n_total_visits)
    generate double n_non_mogad = n_total_visits - n_mogad_visits
    sort mogad rel_year id
    collapse (count) n_patients=id ///
        (mean) mean_mogad=n_mogad_visits mean_non_mogad=n_non_mogad, ///
        by(mogad rel_year)
    drop if n_patients < 5
    sort mogad rel_year
    save `ref_related'

    use `outpatient_events', clear
    merge m:1 id using `people', keepusing(indexdt) nogen assert(match)
    generate int rel_year = year(visitdt) - year(indexdt)
    generate double op_cost_2024 = cond(is_er == 1, ///
        `cost_er_visit', `cost_op_doctor')
    collapse (sum) op_cost_2024, by(id rel_year)
    save `ref_op_cost'

    use `inpatient_events', clear
    merge m:1 id using `people', keepusing(indexdt) nogen assert(match)
    generate int rel_year = year(admitdt) - year(indexdt)
    generate double ip_cost_2024 = los * `cost_inpatient_day' if !missing(los)
    collapse (sum) ip_cost_2024, by(id rel_year)
    save `ref_ip_cost'

    use `rx_events', clear
    merge m:1 id using `people', keepusing(indexdt) nogen assert(match)
    generate int rel_year = year(dispdt) - year(indexdt)
    collapse (sum) rx_cost_2024=mogad_drug_cost, by(id rel_year)
    replace rx_cost_2024 = .
    save `ref_rx_cost'

    use `manual_grid', clear
    merge 1:1 id rel_year using `ref_op_cost', nogen keep(master match)
    merge 1:1 id rel_year using `ref_ip_cost', nogen keep(master match)
    merge 1:1 id rel_year using `ref_rx_cost', nogen keep(master match)
    replace op_cost_2024 = 0 if missing(op_cost_2024)
    replace ip_cost_2024 = 0 if missing(ip_cost_2024)
    generate double npr_direct_2024 = op_cost_2024 + ip_cost_2024
    replace rx_cost_2024 = .
    generate double total_direct_2024 = .
    generate double total_direct_eur = total_direct_2024 / `sek_per_eur'
    sort mogad rel_year id
    collapse (count) n_npr=npr_direct_2024 n_total=total_direct_2024 ///
        (mean) mean_npr=npr_direct_2024 mean_total=total_direct_2024 ///
        mean_op=op_cost_2024 mean_ip=ip_cost_2024 mean_rx=rx_cost_2024 ///
        mean_total_eur=total_direct_eur ///
        (sd) sd_total=total_direct_2024 ///
        (p50) median_total=total_direct_2024, by(mogad rel_year)
    drop if n_npr < 5
    sort mogad rel_year
    save `ref_cost'

    **# Replacement: exactly one pygrid and five pyattach calls
    use `people', clear
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        origin(indexdt) generate(calendar_year) relgen(rel_year) ///
        keep(mogad indexdt)
    assert _N == 72
    clonevar person_start = period_start
    clonevar person_end = period_stop
    sort id rel_year
    cf id mogad calendar_year rel_year person_start person_end person_years ///
        using `manual_grid'
    drop person_start person_end

    pyattach using `outpatient_events', id(id) date(visitdt) ///
        count(n_total_visits) sum(mogad_related n_mogad_visits) orphans(report)
    assert r(N_orphan) == 0
    pyattach using `outpatient_events', id(id) date(visitdt) ///
        count(n_er) if(is_er == 1) orphans(report)
    assert r(N_orphan) == 0
    pyattach using `inpatient_events', id(id) date(admitdt) ///
        count(n_admissions) sum(los total_los) max(is_icu any_icu) orphans(report)
    assert r(N_orphan) == 0
    * The production study creates is_icu as byte. Preserve that storage
    * before the second collapse so cf also pins Stata's exact mean rounding.
    recast byte any_icu
    pyattach using `inpatient_events', id(id) date(admitdt) ///
        count(n_related) if(mogad_related == 1) orphans(report)
    assert r(N_orphan) == 0
    pyattach using `rx_events', id(id) date(dispdt) ///
        count(n_rx) sum(mogad_drug_cost total_drug_cost) ///
        if(mogad_med == 1) orphans(report)
    assert r(N_orphan) == 0
    local tables_passed = 0

    generate byte had_er = n_er > 0
    generate double er_rate = n_er / person_years
    preserve
    sort mogad rel_year id
    collapse (count) n_patients=id (mean) mean_er=n_er (sd) sd_er=n_er ///
        (mean) mean_er_rate=er_rate pct_any_er=had_er ///
        (sum) total_er=n_er total_py=person_years, by(mogad rel_year)
    generate double er_rate_per_py = total_er / total_py
    drop if n_patients < 5
    sort mogad rel_year
    capture noisily cf _all using `ref_er', all
    local compare_rc = _rc
    if `compare_rc' == 0 local ++tables_passed
    else display as error "Obj3a ER table differs (rc=`compare_rc')"
    restore

    generate double n_visits = n_total_visits - n_er
    generate double visit_rate = n_visits / person_years
    preserve
    sort mogad rel_year id
    collapse (count) n_patients=id (mean) mean_visits=n_visits ///
        mean_visit_rate=visit_rate (sd) sd_visits=n_visits ///
        (p50) median_visits=n_visits ///
        (sum) total_visits=n_visits total_py=person_years, by(mogad rel_year)
    generate double visit_rate_per_py = total_visits / total_py
    drop if n_patients < 5
    sort mogad rel_year
    capture noisily cf _all using `ref_op', all
    local compare_rc = _rc
    if `compare_rc' == 0 local ++tables_passed
    else display as error "Obj3b outpatient table differs (rc=`compare_rc')"
    restore

    generate double n_nonrelated = n_admissions - n_related
    generate double admission_rate = n_admissions / person_years
    preserve
    sort mogad rel_year id
    collapse (count) n_patients=id ///
        (mean) mean_admissions=n_admissions mean_admission_rate=admission_rate ///
        mean_los=total_los mean_related=n_related mean_nonrelated=n_nonrelated ///
        pct_icu=any_icu (sd) sd_admissions=n_admissions sd_los=total_los ///
        (sum) total_admissions=n_admissions total_py=person_years, by(mogad rel_year)
    generate double admission_rate_per_py = total_admissions / total_py
    drop if n_patients < 5
    sort mogad rel_year
    capture noisily cf _all using `ref_ip', all
    local compare_rc = _rc
    if `compare_rc' == 0 local ++tables_passed
    else display as error "Obj3c-e inpatient table differs (rc=`compare_rc')"
    restore

    preserve
    keep if calendar_year >= 2005
    replace period_start = max(period_start, `pdr_start') if calendar_year == 2005
    drop if period_stop < period_start
    replace person_years = (period_stop - period_start + 1) / 365.25
    replace total_drug_cost = .
    generate byte had_mogad_rx = n_rx > 0
    generate double rx_rate = n_rx / person_years
    sort mogad rel_year id
    collapse (count) n_patients=id ///
        (mean) mean_rx=n_rx mean_cost=total_drug_cost pct_any=had_mogad_rx ///
        mean_rx_rate=rx_rate (sd) sd_rx=n_rx sd_cost=total_drug_cost ///
        (sum) total_rx=n_rx total_py=person_years, by(mogad rel_year)
    generate double rx_rate_per_py = total_rx / total_py
    drop if n_patients < 5
    generate double mean_cost_eur = mean_cost / `sek_per_eur'
    sort mogad rel_year
    capture noisily cf _all using `ref_rx', all
    local compare_rc = _rc
    if `compare_rc' == 0 local ++tables_passed
    else display as error "Obj3f medication table differs (rc=`compare_rc')"
    restore

    generate double n_non_mogad = n_total_visits - n_mogad_visits
    preserve
    sort mogad rel_year id
    collapse (count) n_patients=id ///
        (mean) mean_mogad=n_mogad_visits mean_non_mogad=n_non_mogad, ///
        by(mogad rel_year)
    drop if n_patients < 5
    sort mogad rel_year
    capture noisily cf _all using `ref_related', all
    local compare_rc = _rc
    if `compare_rc' == 0 local ++tables_passed
    else display as error "Obj3g related-visit table differs (rc=`compare_rc')"
    restore

    generate double op_cost_2024 = n_er * `cost_er_visit' + ///
        (n_total_visits - n_er) * `cost_op_doctor'
    generate double ip_cost_2024 = total_los * `cost_inpatient_day'
    generate double npr_direct_2024 = op_cost_2024 + ip_cost_2024
    generate double rx_cost_2024 = .
    generate double total_direct_2024 = .
    generate double total_direct_eur = total_direct_2024 / `sek_per_eur'
    sort mogad rel_year id
    collapse (count) n_npr=npr_direct_2024 n_total=total_direct_2024 ///
        (mean) mean_npr=npr_direct_2024 mean_total=total_direct_2024 ///
        mean_op=op_cost_2024 mean_ip=ip_cost_2024 mean_rx=rx_cost_2024 ///
        mean_total_eur=total_direct_eur ///
        (sd) sd_total=total_direct_2024 ///
        (p50) median_total=total_direct_2024, by(mogad rel_year)
    drop if n_npr < 5
    sort mogad rel_year
    capture noisily cf _all using `ref_cost', all
    local compare_rc = _rc
    if `compare_rc' == 0 local ++tables_passed
    else display as error "Obj3h direct-cost table differs (rc=`compare_rc')"

    if `tables_passed' == 6 ///
        display as result "MOGAD_SECTION4D_TABLES=6 MATCHED=6"
    assert `tables_passed' == 6
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("MOGAD section 4d six-table equivalence") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Summary
capture noisily _pygrid_result validation_mogad_section4d ///
    `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
