*! validation_pyattach_reference.do Version 1.0.0  2026/08/12
*! Compare arithmetic attachment with a direct interval join on 500 persons
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
capture log close _all
log using "validation_pyattach_reference.log", replace text

do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

**# Arithmetic bucket path against a direct interval join
capture noisily {
    tempfile events grid actual aggregates reference

    clear
    set obs 500
    generate long id = _n
    generate double window_start = td(01jan2010)
    generate double window_end = td(31dec2012)
    format window_start window_end %td
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    assert _N == 1500
    save `grid'

    clear
    set obs 2500
    generate long id = ceil(_n / 5)
    generate byte slot = mod(_n - 1, 5) + 1
    generate double event_date = cond(slot == 1, td(05jan2010), ///
        cond(slot == 2, td(31dec2010), ///
        cond(slot == 3, td(01jan2011), ///
        cond(slot == 4, td(01jul2012), td(01jan2013)))))
    generate double value = id + slot / 10
    generate byte severity = mod(id + slot, 5)
    format event_date %td
    save `events'

    use `grid', clear
    pyattach using `events', id(id) date(event_date) count(n) ///
        sum(value total) max(severity peak) orphans(report)
    assert r(N_eligible) == 2500
    assert r(N_attached) == 2000
    assert r(N_orphan) == 500
    assert r(N_orphan_nokey) == 0
    rename n n_actual
    rename total total_actual
    rename peak peak_actual
    sort id period
    save `actual'

    * The reference deliberately ignores the arithmetic period bucket.
    use `events', clear
    generate long event_row = _n
    joinby id using `grid', unmatched(master) _merge(reference_merge)
    generate byte attached = reference_merge == 3 & ///
        event_date >= period_start & event_date <= period_stop
    bysort event_row: egen long match_count = total(attached)
    assert match_count <= 1
    keep if attached
    generate double one = 1
    collapse (sum) n_reference=one total_reference=value ///
        (max) peak_reference=severity, by(id period)
    save `aggregates'

    use `grid', clear
    merge 1:1 id period using `aggregates', nogen keep(master match)
    replace n_reference = 0 if missing(n_reference)
    replace total_reference = 0 if missing(total_reference)
    replace peak_reference = 0 if missing(peak_reference)
    sort id period
    save `reference'

    use `actual', clear
    merge 1:1 id period using `reference', nogen assert(match)
    assert n_actual == n_reference
    assert !missing(total_actual, total_reference)
    assert reldif(total_actual, total_reference) < 1e-12
    assert peak_actual == peak_reference
    assert n_actual == cond(period == 2010, 2, 1)
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("500-person arithmetic/direct-join equivalence") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Repeated same-period episodes against the same direct interval join
capture noisily {
    tempfile events grid actual aggregates reference

    clear
    set obs 1000
    generate long id = ceil(_n / 2)
    generate byte episode = mod(_n - 1, 2) + 1
    generate double window_start = cond(episode == 1, td(01jan2010), td(01jul2010))
    generate double window_end = window_start + 9
    format window_start window_end %td
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) keep(episode)
    assert _N == 1000
    save `grid'

    clear
    set obs 2000
    generate long id = ceil(_n / 4)
    generate byte slot = mod(_n - 1, 4) + 1
    generate double event_date = cond(slot == 1, td(05jan2010), ///
        cond(slot == 2, td(01apr2010), ///
        cond(slot == 3, td(05jul2010), td(01dec2010))))
    generate double value = id + slot / 10
    generate byte severity = mod(id + slot, 5)
    format event_date %td
    save `events'

    use `grid', clear
    pyattach using `events', id(id) date(event_date) count(n) ///
        sum(value total) max(severity peak) orphans(report)
    assert r(N_eligible) == 2000
    assert r(N_attached) == 1000
    assert r(N_orphan) == 1000
    assert r(N_orphan_nokey) == 0
    quietly summarize n, meanonly
    assert r(sum) == 1000
    rename n n_actual
    rename total total_actual
    rename peak peak_actual
    sort id episode
    save `actual'

    * Deliberately slow reference: form every event-by-episode pair within id,
    * then retain only pairs satisfying the exact inclusive interval bounds.
    use `events', clear
    generate long event_row = _n
    joinby id using `grid', unmatched(master) _merge(reference_merge)
    generate byte attached = reference_merge == 3 & ///
        event_date >= period_start & event_date <= period_stop
    bysort event_row: egen long match_count = total(attached)
    assert match_count <= 1
    keep if attached
    generate double one = 1
    collapse (sum) n_reference=one total_reference=value ///
        (max) peak_reference=severity, by(id episode)
    save `aggregates'

    use `grid', clear
    merge 1:1 id episode using `aggregates', nogen keep(master match)
    replace n_reference = 0 if missing(n_reference)
    replace total_reference = 0 if missing(total_reference)
    replace peak_reference = 0 if missing(peak_reference)
    sort id episode
    save `reference'

    use `actual', clear
    merge 1:1 id episode using `reference', nogen assert(match)
    assert n_actual == n_reference
    assert !missing(total_actual, total_reference)
    assert reldif(total_actual, total_reference) < 1e-12
    assert peak_actual == peak_reference
    assert n_actual == 1
    assert total_actual == id + cond(episode == 1, .1, .3)
    assert peak_actual == mod(id + cond(episode == 1, 1, 3), 5)
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("500-person direct interval-join equivalence") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Summary
capture noisily _pygrid_result validation_pyattach_reference ///
    `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
