*! validation_dgp_known_answers.do
*! Known-answer DGP validation for tvtools: each scenario builds data from a
*! generating process whose exact output (row counts, person-time, split
*! boundaries, propensity weights) is derived analytically from the DGP -- never
*! from the package -- and asserts recovery. Deterministic transforms
*! (tvage/tvband/tvsplit/tvpanel/tvexpose/tvmerge/tvevent/tvdiagnose) have exact
*! integer oracles; tvweight uses saturated-model IPTW identities (mean
*! unstabilized weight = 2, mean stabilized weight = 1, covariate balance) that
*! hold to machine precision.
*!
*! Independent invariants asserted throughout: person-time conservation
*! (sum stop-start+1 == exit-entry+1), abutting/no-overlap, coverage.
*!
*! Run standalone:  cd tvtools/qa && stata-mp -b do validation_dgp_known_answers.do

clear all
set varabbrev off
version 16.0

capture log close
log using "validation_dgp_known_answers.log", replace nomsg

* Bootstrap: sandboxed install from the package root (qa/..).
local qa_dir "`c(pwd)'"
do "`qa_dir'/_tvtools_qa_common.do"
quietly _tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Local base date for readability (2015 is a non-leap year).
local BASE = td(01jan2015)

**# =========================================================================
**# S1: tvage continuous -- exact age-band count + person-time conservation
**# =========================================================================
* DGP: 1 person, dob 15jun1970, followed 01mar2010 -> 31dec2013 (well away from
* the birthday so the 365.25 approximation cannot flip a band). Continuous age
* (groupwidth 1) emits one row per integer age traversed. Analytic band count:
*   age_entry = floor((entry-dob)/365.25), age_exit = floor((exit-dob)/365.25)
*   n_rows    = age_exit - age_entry + 1
* Person-time is conserved exactly and intervals abut (no gaps/overlaps).
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double dob   = td(15jun1970)
    gen double entry = td(01mar2010)
    gen double exit  = td(31dec2013)
    format %td dob entry exit
    local age_e = floor((td(01mar2010) - td(15jun1970)) / 365.25)
    local age_x = floor((td(31dec2013) - td(15jun1970)) / 365.25)
    local exp_rows = `age_x' - `age_e' + 1
    local exp_pt = td(31dec2013) - td(01mar2010) + 1

    tvage, id(id) dob(dob) entry(entry) exit(exit) generate(age) ///
        startgen(a_start) stopgen(a_stop)

    quietly count
    if r(N) != `exp_rows' {
        di as error "  FAIL [S1.rows]: actual=`r(N)' expected=`exp_rows'"
        local t_pass = 0
    }
    else di as result "  PASS [S1.rows]: `exp_rows' continuous age bands"

    quietly gen double pt = a_stop - a_start + 1
    quietly summarize pt
    if r(sum) != `exp_pt' {
        di as error "  FAIL [S1.pt]: actual=`r(sum)' expected=`exp_pt'"
        local t_pass = 0
    }
    else di as result "  PASS [S1.pt]: person-time=`exp_pt' conserved"

    * Abutting intervals: next start == prior stop + 1, no gaps/overlaps.
    sort id a_start
    quietly gen byte bad = (a_start != a_stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
    quietly count if bad == 1
    if r(N) != 0 {
        di as error "  FAIL [S1.abut]: `r(N)' non-abutting joins"
        local t_pass = 0
    }
    else di as result "  PASS [S1.abut]: intervals abut exactly"
}
if _rc & `t_pass' {
    di as error "  FAIL [S1.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S1"
}

**# =========================================================================
**# S2: tvage groupwidth(5) -- age groups collapse to distinct 5-year bands
**# =========================================================================
* DGP: dob 15jun1970, entry 01mar2003 (age ~32), exit 31dec2013 (age ~43).
* With groupwidth 5, continuous ages collapse into 5-year floor bands
* {30,35,40}. Distinct bands = floor(age_x/5) - floor(age_e/5) + 1. Person-time
* is still conserved (collapse takes min start / max stop per band).
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double dob   = td(15jun1970)
    gen double entry = td(01mar2003)
    gen double exit  = td(31dec2013)
    format %td dob entry exit
    local age_e = floor((td(01mar2003) - td(15jun1970)) / 365.25)
    local age_x = floor((td(31dec2013) - td(15jun1970)) / 365.25)
    local exp_bands = floor(`age_x'/5) - floor(`age_e'/5) + 1
    local exp_pt = td(31dec2013) - td(01mar2003) + 1

    tvage, id(id) dob(dob) entry(entry) exit(exit) groupwidth(5) ///
        generate(agegrp) startgen(g_start) stopgen(g_stop)

    quietly count
    if r(N) != `exp_bands' {
        di as error "  FAIL [S2.bands]: actual=`r(N)' expected=`exp_bands'"
        local t_pass = 0
    }
    else di as result "  PASS [S2.bands]: `exp_bands' five-year age groups"

    quietly gen double pt = g_stop - g_start + 1
    quietly summarize pt
    if r(sum) != `exp_pt' {
        di as error "  FAIL [S2.pt]: actual=`r(sum)' expected=`exp_pt'"
        local t_pass = 0
    }
    else di as result "  PASS [S2.pt]: person-time=`exp_pt' conserved"

    * Every band value is a multiple of 5.
    quietly count if mod(agegrp,5) != 0
    if r(N) != 0 {
        di as error "  FAIL [S2.mult5]: `r(N)' bands not multiples of 5"
        local t_pass = 0
    }
    else di as result "  PASS [S2.mult5]: all bands multiples of 5"
}
if _rc & `t_pass' {
    di as error "  FAIL [S2.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S2"
}

**# =========================================================================
**# S3: tvband elapsed(day) width(30) -- exact band count over 365 days
**# =========================================================================
* DGP: 1 person, interval [BASE, BASE+364] (365 days), elapsed axis from BASE,
* width 30 days. Bands b0..b1 with b0=floor(0/30)=0, b1=floor(364/30)=12 -> 13
* rows. Band k covers [BASE+30k, BASE+30(k+1)-1] clamped to the interval, so
* band 12 is the 5-day remainder. Person-time conserved = 365.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start = `BASE'
    gen double stop  = `BASE' + 364
    gen double origin = `BASE'
    format %td start stop origin
    local exp_rows = floor(364/30) - floor(0/30) + 1

    tvband, id(id) start(start) stop(stop) type(elapsed) origin(origin) ///
        width(30) unit(day) generate(fuband)

    quietly count
    if r(N) != `exp_rows' {
        di as error "  FAIL [S3.rows]: actual=`r(N)' expected=`exp_rows'"
        local t_pass = 0
    }
    else di as result "  PASS [S3.rows]: `exp_rows' elapsed-day bands"

    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S3.pt]: actual=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S3.pt]: person-time=365 conserved"

    * First band is a full 30-day width; last is the 5-day remainder.
    sort id start
    if pt[1] != 30 {
        di as error "  FAIL [S3.first]: first band width=`=pt[1]' expected=30"
        local t_pass = 0
    }
    else di as result "  PASS [S3.first]: first band = 30 days"
    if pt[_N] != 5 {
        di as error "  FAIL [S3.last]: last band width=`=pt[_N]' expected=5"
        local t_pass = 0
    }
    else di as result "  PASS [S3.last]: last band = 5 days"
}
if _rc & `t_pass' {
    di as error "  FAIL [S3.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S3"
}

**# =========================================================================
**# S4: tvband calendar width(1) -- split across a year boundary
**# =========================================================================
* DGP: 1 person, interval [01dec2015, 31jan2016] (62 days). Calendar axis width
* 1 year, anchor = 2015 (earliest start year). Bands: 2015 (b0) and 2016 (b1) ->
* 2 rows. Band 2015 = [01dec2015, 31dec2015] = 31 days, band 2016 =
* [01jan2016, 31jan2016] = 31 days. Person-time conserved = 62.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start = td(01dec2015)
    gen double stop  = td(31jan2016)
    format %td start stop

    tvband, id(id) start(start) stop(stop) type(calendar) width(1) ///
        generate(calband)

    quietly count
    if r(N) != 2 {
        di as error "  FAIL [S4.rows]: actual=`r(N)' expected=2"
        local t_pass = 0
    }
    else di as result "  PASS [S4.rows]: 2 calendar-year bands"

    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 62 {
        di as error "  FAIL [S4.pt]: actual=`r(sum)' expected=62"
        local t_pass = 0
    }
    else di as result "  PASS [S4.pt]: person-time=62 conserved"

    sort id start
    quietly count if calband == 2015 | calband == 2016
    if r(N) != 2 {
        di as error "  FAIL [S4.vals]: band values not {2015,2016}"
        local t_pass = 0
    }
    else di as result "  PASS [S4.vals]: bands = {2015, 2016}"
}
if _rc & `t_pass' {
    di as error "  FAIL [S4.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S4"
}

**# =========================================================================
**# S5: tvsplit age+calendar Lexis -- invariants (PT, coverage, no overlap)
**# =========================================================================
* DGP: 1 person, dob 15jun1975, interval [01mar2015, 01aug2016]. Simultaneous
* split on age (birthday ~15jun) and calendar (01jan) axes. Because the 365.25
* age approximation makes the exact cut count fragile, the oracle is the set of
* Lexis invariants that hold for ANY valid multi-axis split: person-time is
* conserved, sub-intervals abut with no gaps/overlaps, and n_axes = 2.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double dob   = td(15jun1975)
    gen double start = td(01mar2015)
    gen double stop  = td(01aug2016)
    format %td dob start stop
    local exp_pt = td(01aug2016) - td(01mar2015) + 1

    tvsplit, id(id) start(start) stop(stop) age(dob, width(1)) calendar(, width(1))

    if r(n_axes) != 2 {
        di as error "  FAIL [S5.axes]: n_axes=`r(n_axes)' expected=2"
        local t_pass = 0
    }
    else di as result "  PASS [S5.axes]: n_axes=2"

    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != `exp_pt' {
        di as error "  FAIL [S5.pt]: actual=`r(sum)' expected=`exp_pt'"
        local t_pass = 0
    }
    else di as result "  PASS [S5.pt]: person-time=`exp_pt' conserved"

    sort id start
    quietly gen byte gap = (start != stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
    quietly count if gap == 1
    if r(N) != 0 {
        di as error "  FAIL [S5.cover]: `r(N)' non-abutting joins (gap/overlap)"
        local t_pass = 0
    }
    else di as result "  PASS [S5.cover]: full coverage, no gaps/overlaps"

    * More rows than a single-axis split (both axes actually cut).
    if _N < 3 {
        di as error "  FAIL [S5.cuts]: only `=_N' rows, expected multi-axis cuts"
        local t_pass = 0
    }
    else di as result "  PASS [S5.cuts]: `=_N' Lexis cells"
}
if _rc & `t_pass' {
    di as error "  FAIL [S5.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S5"
}

**# =========================================================================
**# S6: tvsplit elapsed(year) -- exact band count + PT conservation
**# =========================================================================
* DGP: 1 person, interval [BASE, BASE + round(3.5*365.25)] elapsed from BASE,
* width 1 year. Elapsed-year bands use round(origin + b*365.25) boundaries:
* b0=0, b1=floor(1278/365.25)=3 -> 4 bands (years 0,1,2,3). PT conserved.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start  = `BASE'
    gen double stop   = `BASE' + round(3.5*365.25)
    gen double origin = `BASE'
    format %td start stop origin
    local span = round(3.5*365.25)
    local exp_rows = floor(`span'/365.25) - floor(0/365.25) + 1
    local exp_pt = `span' + 1

    tvsplit, id(id) start(start) stop(stop) elapsed(origin, width(1) unit(year))

    quietly count
    if r(N) != `exp_rows' {
        di as error "  FAIL [S6.rows]: actual=`r(N)' expected=`exp_rows'"
        local t_pass = 0
    }
    else di as result "  PASS [S6.rows]: `exp_rows' elapsed-year bands"

    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != `exp_pt' {
        di as error "  FAIL [S6.pt]: actual=`r(sum)' expected=`exp_pt'"
        local t_pass = 0
    }
    else di as result "  PASS [S6.pt]: person-time=`exp_pt' conserved"
}
if _rc & `t_pass' {
    di as error "  FAIL [S6.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S6"
}

**# =========================================================================
**# S7: tvpanel fixed grid -- exact period count, 0-based index, clamped tail
**# =========================================================================
* DGP: 1 person, entry BASE, exit BASE+364 (365-day follow-up), width 90.
* nper = ceil((exit-entry+1)/width) = ceil(365/90) = 5. Periods 0..4. Period k
* covers [entry+90k, min(entry+90(k+1)-1, exit)]; the tail (period 4) is clamped
* to exit. Person-time conserved = 365.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double entry = `BASE'
    gen double exit  = `BASE' + 364
    format %td entry exit
    tempfile s7_epi
    * Minimal episode file: one reference-class episode spanning follow-up.
    preserve
    clear
    set obs 1
    gen long id = 1
    gen double estart = `BASE'
    gen double estop  = `BASE' + 364
    gen byte eclass = 0
    format %td estart estop
    save `s7_epi'
    restore

    local exp_rows = ceil(365/90)
    tvpanel using `s7_epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        start(estart) stop(estop) width(90) generate(cls) period(per)

    quietly count
    if r(N) != `exp_rows' {
        di as error "  FAIL [S7.rows]: actual=`r(N)' expected=`exp_rows'"
        local t_pass = 0
    }
    else di as result "  PASS [S7.rows]: `exp_rows' fixed-width periods"

    sort id per
    if per[1] != 0 | per[_N] != `exp_rows'-1 {
        di as error "  FAIL [S7.idx]: period range [`=per[1]',`=per[_N]'] expected [0,`=`exp_rows'-1']"
        local t_pass = 0
    }
    else di as result "  PASS [S7.idx]: 0-based period index 0..`=`exp_rows'-1'"

    if stop[_N] != `BASE' + 364 {
        di as error "  FAIL [S7.clamp]: tail stop=`=stop[_N]' expected=`=`BASE'+364'"
        local t_pass = 0
    }
    else di as result "  PASS [S7.clamp]: tail clamped to exit"

    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S7.pt]: actual=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S7.pt]: person-time=365 conserved"
}
if _rc & `t_pass' {
    di as error "  FAIL [S7.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S7"
}

**# =========================================================================
**# S8: tvpanel exact-multiple boundary -- exit day gets its own period
**# =========================================================================
* Regression guard for the inclusive [entry,exit] fix. DGP: entry BASE,
* exit BASE+270 so (exit-entry) = 270 = 3*width exactly (width 90). The exit
* day is NOT an exact multiple of the covered span, so nper must be
* ceil((270+1)/90) = 4, and period 3 = [BASE+270, BASE+270] (the exit day).
* A regression to ceil((exit-entry)/width)=3 would leave the exit day uncovered.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double entry = `BASE'
    gen double exit  = `BASE' + 270
    format %td entry exit
    tempfile s8_epi
    preserve
    clear
    set obs 1
    gen long id = 1
    gen double estart = `BASE'
    gen double estop  = `BASE' + 270
    gen byte eclass = 0
    save `s8_epi'
    restore

    tvpanel using `s8_epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        start(estart) stop(estop) width(90) generate(cls) period(per)

    quietly count
    if r(N) != 4 {
        di as error "  FAIL [S8.rows]: actual=`r(N)' expected=4 (exit day uncovered?)"
        local t_pass = 0
    }
    else di as result "  PASS [S8.rows]: 4 periods, exit day covered"

    quietly summarize stop
    if r(max) != `BASE' + 270 {
        di as error "  FAIL [S8.exit]: max stop=`r(max)' expected=`=`BASE'+270'"
        local t_pass = 0
    }
    else di as result "  PASS [S8.exit]: max stop reaches exit"

    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 271 {
        di as error "  FAIL [S8.pt]: actual=`r(sum)' expected=271"
        local t_pass = 0
    }
    else di as result "  PASS [S8.pt]: person-time=271 conserved"
}
if _rc & `t_pass' {
    di as error "  FAIL [S8.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S8"
}

**# =========================================================================
**# S9: tvpanel cumulative(days) -- exact accrued exposure at each period start
**# =========================================================================
* DGP: entry BASE, exit BASE+364, width 91. One class-1 episode [BASE+10,
* BASE+40] = 31 exposed days. cumulative(days) reports class-1 days accrued
* STRICTLY BEFORE each period start:
*   period 0 (start BASE):     0 days   (episode starts after BASE)
*   period 1 (start BASE+91):  31 days  (whole episode is before BASE+91)
*   periods 2,3,4:             31 days  (episode fully accrued)
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double entry = `BASE'
    gen double exit  = `BASE' + 364
    format %td entry exit
    tempfile s9_epi
    preserve
    clear
    set obs 1
    gen long id = 1
    gen double estart = `BASE' + 10
    gen double estop  = `BASE' + 40
    gen byte eclass = 1
    save `s9_epi'
    restore

    tvpanel using `s9_epi', id(id) entry(entry) exit(exit) exposure(eclass) ///
        start(estart) stop(estop) width(91) generate(cls) period(per) ///
        cumulative(days)

    sort id per
    capture confirm variable cum_1
    if _rc {
        di as error "  FAIL [S9.var]: cum_1 not created"
        local t_pass = 0
    }
    else {
        if cum_1[1] != 0 {
            di as error "  FAIL [S9.p0]: cum_1[period0]=`=cum_1[1]' expected=0"
            local t_pass = 0
        }
        else di as result "  PASS [S9.p0]: period 0 cumulative = 0"

        quietly count if per >= 1 & cum_1 != 31
        if r(N) != 0 {
            di as error "  FAIL [S9.acc]: `r(N)' periods with cum_1 != 31 after accrual"
            local t_pass = 0
        }
        else di as result "  PASS [S9.acc]: periods 1+ cumulative = 31 days"
    }
}
if _rc & `t_pass' {
    di as error "  FAIL [S9.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S9"
}

**# =========================================================================
**# S10: tvdiagnose coverage -- exact mean coverage % and gap count
**# =========================================================================
* DGP: 2 persons, study window [BASE, BASE+99] (100 days each).
*   id 1: two covered periods [BASE,BASE+49] + [BASE+60,BASE+99] = 50+40 = 90
*          days covered -> 90% coverage, has a gap.
*   id 2: single period [BASE,BASE+99] = 100 days -> 100% coverage, no gap.
* mean_coverage = (90 + 100)/2 = 95. n_with_gaps = 1.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(start stop entry exit)
        1 0 49 0 99
        1 60 99 0 99
        2 0 99 0 99
    end
    replace start = start + `BASE'
    replace stop  = stop  + `BASE'
    replace entry = entry + `BASE'
    replace exit  = exit  + `BASE'
    format %td start stop entry exit

    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit) coverage

    if abs(r(mean_coverage) - 95) > 1e-6 {
        di as error "  FAIL [S10.mean]: mean_coverage=`r(mean_coverage)' expected=95"
        local t_pass = 0
    }
    else di as result "  PASS [S10.mean]: mean coverage = 95%"

    if r(n_with_gaps) != 1 {
        di as error "  FAIL [S10.ngap]: n_with_gaps=`r(n_with_gaps)' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S10.ngap]: 1 person with gaps"
}
if _rc & `t_pass' {
    di as error "  FAIL [S10.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S10"
}

**# =========================================================================
**# S11: tvdiagnose gaps -- exact gap count, mean/max gap days, large-gap flag
**# =========================================================================
* DGP: 1 person with two gaps.
*   periods: [0,9], [20,29], [80,89]  (offsets from BASE)
*   gap 1: days 10..19 -> 10 days
*   gap 2: days 30..79 -> 50 days
* n_gaps=2, mean_gap=30, max_gap=50, threshold(30) -> n_large_gaps=1 (only 50>30).
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(start stop)
        1 0 9
        1 20 29
        1 80 89
    end
    replace start = start + `BASE'
    replace stop  = stop  + `BASE'
    format %td start stop

    tvdiagnose, id(id) start(start) stop(stop) gaps threshold(30)

    if r(n_gaps) != 2 {
        di as error "  FAIL [S11.n]: n_gaps=`r(n_gaps)' expected=2"
        local t_pass = 0
    }
    else di as result "  PASS [S11.n]: 2 gaps"
    if abs(r(mean_gap) - 30) > 1e-6 {
        di as error "  FAIL [S11.mean]: mean_gap=`r(mean_gap)' expected=30"
        local t_pass = 0
    }
    else di as result "  PASS [S11.mean]: mean gap = 30 days"
    if r(max_gap) != 50 {
        di as error "  FAIL [S11.max]: max_gap=`r(max_gap)' expected=50"
        local t_pass = 0
    }
    else di as result "  PASS [S11.max]: max gap = 50 days"
    if r(n_large_gaps) != 1 {
        di as error "  FAIL [S11.large]: n_large_gaps=`r(n_large_gaps)' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S11.large]: 1 gap exceeds 30-day threshold"
}
if _rc & `t_pass' {
    di as error "  FAIL [S11.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S11"
}

**# =========================================================================
**# S12: tvdiagnose overlaps -- exact overlapping-period count and IDs affected
**# =========================================================================
* DGP: 2 persons.
*   id 1: [0,49] and [40,89] overlap (start 40 <= prior stop 49) -> 1 overlap row.
*   id 2: [0,49] and [50,99] abut (start 50 > prior stop 49) -> no overlap.
* n_overlaps=1, n_ids_affected=1.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(start stop)
        1 0 49
        1 40 89
        2 0 49
        2 50 99
    end
    replace start = start + `BASE'
    replace stop  = stop  + `BASE'
    format %td start stop

    tvdiagnose, id(id) start(start) stop(stop) overlaps

    if r(n_overlaps) != 1 {
        di as error "  FAIL [S12.n]: n_overlaps=`r(n_overlaps)' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S12.n]: 1 overlapping period"
    if r(n_ids_affected) != 1 {
        di as error "  FAIL [S12.ids]: n_ids_affected=`r(n_ids_affected)' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S12.ids]: 1 ID affected"
}
if _rc & `t_pass' {
    di as error "  FAIL [S12.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S12"
}

**# =========================================================================
**# S13: tvdiagnose summarize -- exact total person-time
**# =========================================================================
* DGP: 2 persons, exposure levels {0,1}.
*   rows (offsets, inclusive): id1 [0,29] exp0, id1 [30,99] exp1,
*                              id2 [0,49] exp1, id2 [50,99] exp0
*   total person-time = 30 + 70 + 50 + 50 = 200 days.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(start stop) byte exp
        1 0 29 0
        1 30 99 1
        2 0 49 1
        2 50 99 0
    end
    replace start = start + `BASE'
    replace stop  = stop  + `BASE'
    format %td start stop

    tvdiagnose, id(id) start(start) stop(stop) exposure(exp) summarize

    if r(total_person_time) != 200 {
        di as error "  FAIL [S13.pt]: total_person_time=`r(total_person_time)' expected=200"
        local t_pass = 0
    }
    else di as result "  PASS [S13.pt]: total person-time = 200 days"
}
if _rc & `t_pass' {
    di as error "  FAIL [S13.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S13"
}

**# =========================================================================
**# S14: tvexpose single mid-follow-up episode -- 3 intervals, exact exposed PT
**# =========================================================================
* DGP: 1 person, study [01jan2015, 31dec2015] (365 days). One exposure episode
* [01apr2015, 30jun2015] = 91 days (Apr30+May31+Jun30 = 91). tvexpose emits:
*   [01jan,31mar] ref=0, [01apr,30jun] exp=1, [01jul,31dec] ref=0  -> 3 rows.
* Exposed person-time = 91 days; total conserved = 365.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double study_entry = td(01jan2015)
    gen double study_exit  = td(31dec2015)
    format %td study_entry study_exit
    tempfile s14_cohort
    save `s14_cohort'

    clear
    set obs 1
    gen long id = 1
    gen double start = td(01apr2015)
    gen double stop  = td(30jun2015)
    gen byte drug = 1
    format %td start stop
    tempfile s14_exp
    save `s14_exp'

    use `s14_cohort', clear
    tvexpose using `s14_exp', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) generate(tv_drug)

    sort id start
    quietly count
    if r(N) != 3 {
        di as error "  FAIL [S14.rows]: actual=`r(N)' expected=3"
        local t_pass = 0
    }
    else di as result "  PASS [S14.rows]: 3 intervals (pre/exposed/post)"

    quietly gen double pt = stop - start + 1
    quietly summarize pt if tv_drug == 1
    if r(sum) != 91 {
        di as error "  FAIL [S14.exp]: exposed PT=`r(sum)' expected=91"
        local t_pass = 0
    }
    else di as result "  PASS [S14.exp]: exposed person-time = 91 days"

    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S14.pt]: total PT=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S14.pt]: total person-time = 365 conserved"
}
if _rc & `t_pass' {
    di as error "  FAIL [S14.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S14"
}

**# =========================================================================
**# S15: tvexpose episode ending at exit -- boundary collapses to 2 intervals
**# =========================================================================
* DGP: 1 person, study [01jan2015, 31dec2015]. Episode [01jul2015, 31dec2015]
* ends exactly at study exit, so the post-exposure interval is empty and
* dropped -> 2 rows: [01jan,30jun] ref=0, [01jul,31dec] exp=1.
* Exposed PT = 01jul..31dec = 184 days; total = 365.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double study_entry = td(01jan2015)
    gen double study_exit  = td(31dec2015)
    format %td study_entry study_exit
    tempfile s15_cohort
    save `s15_cohort'

    clear
    set obs 1
    gen long id = 1
    gen double start = td(01jul2015)
    gen double stop  = td(31dec2015)
    gen byte drug = 1
    format %td start stop
    tempfile s15_exp
    save `s15_exp'

    use `s15_cohort', clear
    tvexpose using `s15_exp', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) generate(tv_drug)

    sort id start
    quietly count
    if r(N) != 2 {
        di as error "  FAIL [S15.rows]: actual=`r(N)' expected=2 (empty tail not dropped?)"
        local t_pass = 0
    }
    else di as result "  PASS [S15.rows]: 2 intervals (boundary tail dropped)"

    quietly gen double pt = stop - start + 1
    quietly summarize pt if tv_drug == 1
    if r(sum) != 184 {
        di as error "  FAIL [S15.exp]: exposed PT=`r(sum)' expected=184"
        local t_pass = 0
    }
    else di as result "  PASS [S15.exp]: exposed person-time = 184 days"

    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S15.pt]: total PT=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S15.pt]: total person-time = 365 conserved"
}
if _rc & `t_pass' {
    di as error "  FAIL [S15.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S15"
}

**# =========================================================================
**# S16: tvmerge two non-overlapping episodes -- exact intersection lattice
**# =========================================================================
* DGP: 1 person, both exposure files span [01jan2015, 31dec2015].
*   Drug A intervals: [01jan,31mar] A=0, [01apr,30jun] A=1, [01jul,31dec] A=0
*   Drug B intervals: [01jan,31aug] B=0, [01sep,31oct] B=1, [01nov,31dec] B=0
* A and B change on different dates -> intersection cut points at
* {01apr,01jul,01sep,01nov} -> 5 merged intervals. Person-time conserved = 365.
* Exposed-A PT = 91 (Apr-Jun); exposed-B PT = 61 (Sep-Oct); never both (disjoint).
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(start stop) byte tv_a
        1 0 0 0
    end
    replace start = td(01jan2015)
    replace stop  = td(31mar2015)
    set obs 3
    replace id = 1 in 2/3
    replace start = td(01apr2015) in 2
    replace stop  = td(30jun2015) in 2
    replace tv_a = 1 in 2
    replace start = td(01jul2015) in 3
    replace stop  = td(31dec2015) in 3
    replace tv_a = 0 in 3
    format %td start stop
    tempfile s16_a
    save `s16_a'

    clear
    set obs 3
    gen long id = 1
    gen double start = .
    gen double stop = .
    gen byte tv_b = 0
    replace start = td(01jan2015) in 1
    replace stop  = td(31aug2015) in 1
    replace start = td(01sep2015) in 2
    replace stop  = td(31oct2015) in 2
    replace tv_b = 1 in 2
    replace start = td(01nov2015) in 3
    replace stop  = td(31dec2015) in 3
    format %td start stop
    tempfile s16_b
    save `s16_b'

    tvmerge "`s16_a'" "`s16_b'", id(id) start(start start) stop(stop stop) ///
        exposure(tv_a tv_b) generate(drug_a drug_b)

    sort id start
    quietly count
    if r(N) != 5 {
        di as error "  FAIL [S16.rows]: actual=`r(N)' expected=5"
        local t_pass = 0
    }
    else di as result "  PASS [S16.rows]: 5 intersection intervals"

    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S16.pt]: total PT=`r(sum)' expected=365"
        local t_pass = 0
    }
    else di as result "  PASS [S16.pt]: person-time = 365 conserved"

    quietly summarize pt if drug_a == 1
    if r(sum) != 91 {
        di as error "  FAIL [S16.a]: A-exposed PT=`r(sum)' expected=91"
        local t_pass = 0
    }
    else di as result "  PASS [S16.a]: Drug-A exposed PT = 91"

    quietly summarize pt if drug_b == 1
    if r(sum) != 61 {
        di as error "  FAIL [S16.b]: B-exposed PT=`r(sum)' expected=61"
        local t_pass = 0
    }
    else di as result "  PASS [S16.b]: Drug-B exposed PT = 61"

    quietly count if drug_a == 1 & drug_b == 1
    if r(N) != 0 {
        di as error "  FAIL [S16.disjoint]: `r(N)' rows with both exposures (should be 0)"
        local t_pass = 0
    }
    else di as result "  PASS [S16.disjoint]: no simultaneous A&B exposure"
}
if _rc & `t_pass' {
    di as error "  FAIL [S16.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S16"
}

**# =========================================================================
**# S17: tvevent recurring events -- non-censoring split, PT conserved
**# =========================================================================
* DGP: 1 person, single interval [01jan2015, 31dec2015] (365 days). Two recurring
* event dates 01apr2015 and 01sep2015, both strictly interior. type(recurring)
* takes WIDE event columns (event_dt1, event_dt2, ...) -- one row per person --
* and does NOT censor: each interior event splits its interval but keeps all
* person-time. Expected 3 rows, total PT still 365, and exactly 2 event flags.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double start = td(01jan2015)
    gen double stop  = td(31dec2015)
    format %td start stop
    tempfile s17_iv
    save `s17_iv'

    clear
    set obs 1
    gen long id = 1
    gen double event_dt1 = td(01apr2015)
    gen double event_dt2 = td(01sep2015)
    format %td event_dt1 event_dt2

    tvevent using `s17_iv', id(id) start(start) stop(stop) date(event_dt) ///
        generate(outcome) type(recurring)

    sort id start
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 365 {
        di as error "  FAIL [S17.pt]: total PT=`r(sum)' expected=365 (recurring must not censor)"
        local t_pass = 0
    }
    else di as result "  PASS [S17.pt]: recurring PT = 365 conserved"

    quietly count
    if r(N) != 3 {
        di as error "  FAIL [S17.rows]: actual=`r(N)' expected=3"
        local t_pass = 0
    }
    else di as result "  PASS [S17.rows]: 3 intervals (2 interior splits)"

    quietly summarize outcome
    if r(sum) != 2 {
        di as error "  FAIL [S17.flags]: sum(outcome)=`r(sum)' expected=2"
        local t_pass = 0
    }
    else di as result "  PASS [S17.flags]: 2 event flags"
}
if _rc & `t_pass' {
    di as error "  FAIL [S17.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S17"
}

**# =========================================================================
**# S18: tvweight saturated IPTW identity -- mean unstabilized weight = 2
**# =========================================================================
* DGP: single binary confounder x, N=4000.
*   cell x=0: 3000 obs, 900 treated -> P(A=1|x=0) = 0.30
*   cell x=1: 1000 obs, 800 treated -> P(A=1|x=1) = 0.80
* logit(A on x) is SATURATED, so predicted PS equals the empirical cell
* proportion exactly (MLE of a saturated logit = cell mean). Then the
* Horvitz-Thompson identity gives, per cell, sum of 1/PS over treated = n and
* over untreated = n, so the mean unstabilized IPTW = 2 to machine precision --
* an oracle independent of the fitting code.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 4000
    gen byte x = _n > 3000
    gen byte a = 0
    replace a = 1 if x == 0 & _n <= 900
    replace a = 1 if x == 1 & _n <= 3800

    tvweight a, covariates(x) generate(w) nolog

    if abs(r(w_mean) - 2) > 1e-5 {
        di as error "  FAIL [S18.mean]: mean IPTW=`r(w_mean)' expected=2"
        local t_pass = 0
    }
    else di as result "  PASS [S18.mean]: mean unstabilized IPTW = 2"

    * Horvitz-Thompson: sum of treated weights = N (pseudo-population size).
    quietly summarize w if a == 1, meanonly
    local sum_treated = r(sum)
    if abs(`sum_treated' - 4000) > 1e-3 {
        di as error "  FAIL [S18.ht]: sum treated w=`sum_treated' expected=4000"
        local t_pass = 0
    }
    else di as result "  PASS [S18.ht]: sum of treated weights = N = 4000"
}
if _rc & `t_pass' {
    di as error "  FAIL [S18.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S18"
}

**# =========================================================================
**# S19: tvweight saturated stabilized identity -- mean stabilized weight = 1
**# =========================================================================
* Same DGP as S18. Stabilized weight = P(A=a) / P(A=a|x). Per cell, treated sum
* = n*P(A=1), untreated sum = n*P(A=0), so each cell contributes n and the
* stabilized weights sum to N -> mean = 1 to machine precision. Also ESS/N is
* materially higher than for the unstabilized weights.
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 4000
    gen byte x = _n > 3000
    gen byte a = 0
    replace a = 1 if x == 0 & _n <= 900
    replace a = 1 if x == 1 & _n <= 3800

    tvweight a, covariates(x) generate(sw) stabilized nolog
    local sw_ess = r(ess)

    if abs(r(w_mean) - 1) > 1e-5 {
        di as error "  FAIL [S19.mean]: mean stabilized=`r(w_mean)' expected=1"
        local t_pass = 0
    }
    else di as result "  PASS [S19.mean]: mean stabilized weight = 1"

    * ESS must lie in (0, N].
    if `sw_ess' <= 0 | `sw_ess' > 4000 + 1e-6 {
        di as error "  FAIL [S19.ess]: ESS=`sw_ess' outside (0,4000]"
        local t_pass = 0
    }
    else di as result "  PASS [S19.ess]: ESS=`sw_ess' within (0,N]"
}
if _rc & `t_pass' {
    di as error "  FAIL [S19.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S19"
}

**# =========================================================================
**# S20: tvweight IPTW covariate balance -- pseudo-population equalizes x
**# =========================================================================
* Same DGP as S18. In the IPTW pseudo-population the weighted mean of the
* confounder is equal across arms and equals the marginal P(x=1) = 1000/4000 =
* 0.25. This is the defining property of a correct propensity weight and is
* derived analytically from the DGP (not from any estimator).
local ++test_count
local t_pass = 1
capture noisily {
    clear
    set obs 4000
    gen byte x = _n > 3000
    gen byte a = 0
    replace a = 1 if x == 0 & _n <= 900
    replace a = 1 if x == 1 & _n <= 3800
    local marg_x = 1000/4000

    tvweight a, covariates(x) generate(w) nolog

    quietly summarize x [aweight=w] if a == 1, meanonly
    local wx1 = r(mean)
    quietly summarize x [aweight=w] if a == 0, meanonly
    local wx0 = r(mean)

    if abs(`wx1' - `marg_x') > 1e-6 {
        di as error "  FAIL [S20.treated]: weighted E[x|A=1]=`wx1' expected=`marg_x'"
        local t_pass = 0
    }
    else di as result "  PASS [S20.treated]: weighted E[x|A=1] = 0.25"
    if abs(`wx0' - `marg_x') > 1e-6 {
        di as error "  FAIL [S20.untreated]: weighted E[x|A=0]=`wx0' expected=`marg_x'"
        local t_pass = 0
    }
    else di as result "  PASS [S20.untreated]: weighted E[x|A=0] = 0.25"
    if abs(`wx1' - `wx0') > 1e-6 {
        di as error "  FAIL [S20.balance]: arms differ (`wx1' vs `wx0')"
        local t_pass = 0
    }
    else di as result "  PASS [S20.balance]: arms balanced on x"
}
if _rc & `t_pass' {
    di as error "  FAIL [S20.run]: rc=`=_rc'"
    local t_pass = 0
}
if `t_pass' local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' S20"
}

**# =========================================================================
**# Summary
**# =========================================================================
display _newline as result "validation_dgp_known_answers: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED SCENARIOS:`failed_tests'"
    display "RESULT: validation_dgp_known_answers tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL KNOWN-ANSWER DGP SCENARIOS PASSED"
display "RESULT: validation_dgp_known_answers tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
