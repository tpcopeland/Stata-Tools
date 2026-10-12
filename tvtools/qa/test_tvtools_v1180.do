*! test_tvtools_v1180.do
*! Release regressions for the 2026-10-12 clarity audit: quantity-aware
*! splitting in tvsplit/tvband, dose x washout refusal, closed-day timegen,
*! lag x window anchoring, lag truncation, tvmerge intersection loss,
*! quoted label text in tvexpose, a quiet dose sweep, and the help dose example
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
quietly log using "test_tvtools_v1180.log", replace text nomsg
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
local tests = 0
local pass = 0
local fail = 0

**# C1: tvsplit apportions an interval total by inclusive days
* tvmerge total(amt) output: one row [21900, 22300] (401 days, 17dec2019 to
* 20jan2021) with amt = 100. Calendar width 1 cuts it into 15 + 366 + 20
* days. Before the fix every piece carried 100 and the column summed to 300.
local ++tests
capture noisily {
    clear
    input long id double(s e) double amt
    1 21900 22300 100
    end
    tempfile a b
    save `a'
    clear
    input long id double(s e) byte y
    1 21900 22300 1
    end
    save `b'
    tvmerge `a' `b', id(id) start(s s) stop(e e) exposure(amt y) total(amt)
    local q : char amt[tvtools_quantity]
    assert "`q'" == "total"
    tvsplit, id(id) start(start) stop(stop) calendar(width(1))
    assert "`r(total_vars)'" == "amt"
    sort start
    assert _N == 3
    assert stop - start + 1 == 15  in 1
    assert stop - start + 1 == 366 in 2
    assert stop - start + 1 == 20  in 3
    assert !missing(amt)
    assert reldif(amt, 100 * (stop - start + 1) / 401) < 1e-12
    quietly summarize amt
    assert reldif(r(sum), 100) < 1e-12
    * the categorical exposure rides along unchanged
    assert y == 1
    local q : char amt[tvtools_quantity]
    assert "`q'" == "total"
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: C1 tvsplit total apportioning"
}

**# C1: tvband apportions totals; rate and cumulative ride unchanged
* Integer storage must not truncate the shares; an untagged covariate rides
* unchanged; min() drops a band and its share with it.
local ++tests
capture noisily {
    clear
    input long id double(start stop) int amt double(rt cm) byte cov
    1 21900 22300 7 2 50 4
    end
    char amt[tvtools_quantity] "total"
    char rt[tvtools_quantity] "rate"
    char cm[tvtools_quantity] "cumulative"
    tvband, id(id) start(start) stop(stop) type(calendar) width(1)
    assert "`r(total_vars)'" == "amt"
    sort start
    assert _N == 3
    assert "`: type amt'" == "double"
    assert !missing(amt)
    assert reldif(amt, 7 * (stop - start + 1) / 401) < 1e-12
    quietly summarize amt
    assert reldif(r(sum), 7) < 1e-12
    assert rt == 2 & cm == 50 & cov == 4
    * min() bound: only the 2020 and 2021 bands survive (366 + 20 days)
    clear
    input long id double(start stop) double amt
    1 21900 22300 401
    end
    char amt[tvtools_quantity] "total"
    tvband, id(id) start(start) stop(stop) type(calendar) width(1) min(2020)
    assert _N == 2
    quietly summarize amt
    assert reldif(r(sum), 386) < 1e-12
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: C1 tvband quantity algebra"
}

**# C1: multi-axis tvsplit keeps the source total; unknown metadata refused
local ++tests
capture noisily {
    clear
    input long id double(start stop dob ref) double amt
    1 21000 22900 3000 21000 1000
    2 21500 21600 9000 21500 50
    end
    char amt[tvtools_quantity] "total"
    tvsplit, id(id) start(start) stop(stop) age(dob, width(5)) ///
        calendar(, width(1)) elapsed(ref, width(1) unit(year))
    assert "`r(total_vars)'" == "amt"
    tempvar s0 tot
    bysort id: egen double `tot' = total(amt)
    assert !missing(`tot', amt)
    assert reldif(`tot', 1000) < 1e-10 if id == 1
    assert reldif(`tot', 50) < 1e-10 if id == 2
    * pieces are proportional to their days within each source row
    assert reldif(amt, 1000 * (stop - start + 1) / 1901) < 1e-10 if id == 1
    * unknown [tvtools_quantity] metadata: refused, data untouched
    clear
    input long id double(start stop) double amt
    1 21900 22300 100
    end
    char amt[tvtools_quantity] "bogus"
    datasignature set
    capture noisily tvsplit, id(id) start(start) stop(stop) calendar(width(1))
    assert _rc == 498
    datasignature confirm
    assert _N == 1 & amt == 100
    capture noisily tvband, id(id) start(start) stop(stop) type(calendar)
    assert _rc == 498
    datasignature confirm
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: C1 multi-axis conservation / unknown metadata"
}

**# I2: dose with washout() is refused; dose without washout unchanged
* Before the fix 30 units over days 100-129 read as 23.33 cumulative on day
* 170 under washout(60), although nothing was taken after day 129.
local ++tests
capture noisily {
    clear
    input long id double(rs re dose)
    1 100 129 30
    1 170 170 1
    end
    tempfile ep
    save `ep'
    clear
    input long id double(entry exit)
    1 0 175
    end
    datasignature set
    capture noisily tvexpose using `ep', id(id) start(rs) stop(re) ///
        exposure(dose) dose entry(entry) exit(exit) generate(cd) washout(60)
    assert _rc == 198
    datasignature confirm
    tvexpose using `ep', id(id) start(rs) stop(re) exposure(dose) dose ///
        entry(entry) exit(exit) generate(cd) washout(0)
    sort rs
    assert _N == 3
    assert rs[2] == 130 & cd[2] == 30
    assert rs[3] == 171 & cd[3] == 31
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: I2 dose x washout"
}

**# I3: timegen is closed-day elapsed time; an entry-day event survives stset
local ++tests
capture noisily {
    clear
    input long id double(start stop)
    1 100 100
    1 101 200
    2 100 150
    2 151 300
    end
    tempfile ivl
    save `ivl'
    clear
    input long id double edate
    1 100
    2 .
    end
    tvevent using `ivl', id(id) date(edate) generate(fail) ///
        timegen(t) timeunit(days)
    sort id start
    tempvar fs
    bysort id (start): generate double `fs' = start[1]
    assert t == stop - `fs' + 1
    assert t == 1 & fail == 1 if id == 1
    * entry-day event row stays in the analysis under the documented mapping
    generate double t0 = t - (stop - start + 1)
    stset t, id(id) failure(fail == 1) time0(t0)
    quietly count if _st == 1 & _d == 1
    assert r(N) == 1
    quietly count if _st == 0
    assert r(N) == 0
    * a full year from entry is 366 days through the end of the row, month scale
    clear
    input long id double(start stop)
    1 21915 22280
    end
    save `ivl', replace
    clear
    input long id double edate
    1 .
    end
    tvevent using `ivl', id(id) date(edate) generate(fail) ///
        timegen(tm) timeunit(months)
    assert !missing(tm)
    assert reldif(tm, 366 / 30.4375) < 1e-12
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: I3 timegen convention"
}

**# I5 / M9: window() anchors on the lagged start; lag truncates, not shifts
local ++tests
capture noisily {
    clear
    input long id double(rs re) byte drug
    1 100 160 1
    1 300 305 1
    end
    tempfile ep
    save `ep'
    clear
    input long id double(entry exit)
    1 0 400
    end
    tempfile coh
    save `coh'
    * lag(10) window(1 7): exposed 111-117 (start 100 + lag 10 + 1..7)
    tvexpose using `ep', id(id) start(rs) stop(re) exposure(drug) ///
        reference(0) entry(entry) exit(exit) generate(tv) lag(10) window(1 7)
    * the 6-day second episode is removed by the lag before any window
    quietly count if tv == 1
    assert r(N) == 1
    quietly count if tv == 1 & rs == 111 & re == 117
    assert r(N) == 1
    * lag truncates: [100,160] -> [110,160]; the 6-day [300,305] vanishes
    use `coh', clear
    tvexpose using `ep', id(id) start(rs) stop(re) exposure(drug) ///
        reference(0) entry(entry) exit(exit) generate(tv) lag(10)
    assert r(n_lag_removed) == 1
    quietly count if tv == 1
    assert r(N) == 1
    quietly count if tv == 1 & rs == 110 & re == 160
    assert r(N) == 1
    * window clipped by the washout-extended stop: a 3-day episode with
    * washout(30) and window(1 7) is exposed on start+1 .. start+7
    clear
    input long id double(rs re) byte drug
    1 100 102 1
    end
    save `ep', replace
    use `coh', clear
    tvexpose using `ep', id(id) start(rs) stop(re) exposure(drug) ///
        reference(0) entry(entry) exit(exit) generate(tv) washout(30) window(1 7)
    quietly count if tv == 1 & rs == 101 & re == 107
    assert r(N) == 1
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: I5/M9 lag and window anchoring"
}

**# I6: tvmerge reports person-time lost to the coverage intersection
local ++tests
capture noisily {
    clear
    input long id double(s e) byte x
    1 0 299 0
    1 300 999 1
    2 0 999 0
    end
    tempfile a b c
    save `a'
    clear
    input long id double(s e) byte y
    1 0 199 0
    1 200 499 2
    2 0 999 2
    end
    save `b'
    tvmerge `a' `b', id(id) start(s s) stop(e e) exposure(x y)
    assert r(n_persontime_lost) == 500
    assert r(n_ids_persontime_lost) == 1
    assert r(n_gaps) == 0
    * equal follow-up: nothing lost
    tvmerge `a' `a', id(id) start(s s) stop(e e) exposure(x x) ///
        generate(x1 x2)
    assert r(n_persontime_lost) == 0
    assert r(n_ids_persontime_lost) == 0
    * a source with a coverage gap: days 400-599 missing in source 2
    clear
    input long id double(s e) byte y
    1 0 399 1
    1 600 999 1
    2 0 999 1
    end
    save `c'
    tvmerge `a' `c', id(id) start(s s) stop(e e) exposure(x y)
    assert r(n_persontime_lost) == 200
    assert r(n_ids_persontime_lost) == 1
    * force: a person absent from one source loses all of their days
    clear
    input long id double(s e) byte y
    1 0 999 1
    end
    save `c', replace
    tvmerge `a' `c', id(id) start(s s) stop(e e) exposure(x y) force
    assert r(n_persontime_lost) == 1000
    assert r(n_ids_persontime_lost) == 1
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: I6 tvmerge intersection loss"
}

**# M3: label text with embedded double quotes round-trips (both engines)
* Before the fix referencelabel(`"He said "no" today"') exited r(198), and an
* exposure variable label containing quotes broke the default label path.
local ++tests
capture noisily {
    clear
    input long id double(entry exit)
    1 0 999
    end
    tempfile coh ep
    save `coh'
    clear
    input long id double(rs re) byte drug
    1 100 200 1
    end
    label variable drug `"Drug "A" class"'
    save `ep'
    foreach fp in "" "nofastpath" {
        use `coh', clear
        tvexpose using `ep', id(id) start(rs) stop(re) exposure(drug) ///
            reference(0) entry(entry) exit(exit) generate(tv) `fp' ///
            referencelabel(`"He said "no" today"')
        local l : label (tv) 0
        assert `"`l'"' == `"He said "no" today"'
        local v : variable label tv
        assert `"`v'"' == `"Drug "A" class"'
        use `coh', clear
        tvexpose using `ep', id(id) start(rs) stop(re) exposure(drug) ///
            reference(0) entry(entry) exit(exit) generate(tv) `fp' ///
            evertreated label(`"My "x" label"')
        local v : variable label tv
        assert `"`v'"' == `"My "x" label"'
    }
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: M3 quoted label text"
}

**# M4: the dose overlap sweep writes nothing from duplicates drop
local ++tests
capture noisily {
    clear
    input long id double(rs re dose)
    1 100 129 30
    1 110 140 31
    2 100 129 30
    2 120 150 10
    end
    tempfile ep logf
    save `ep'
    clear
    input long id double(entry exit)
    1 0 200
    2 0 200
    end
    quietly log using `"`logf'"', text name(m4log) replace
    tvexpose using `ep', id(id) start(rs) stop(re) exposure(dose) dose ///
        entry(entry) exit(exit) generate(cd)
    quietly log close m4log
    tempname fh
    local hits = 0
    file open `fh' using `"`logf'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Duplicates in terms of") local ++hits
        file read `fh' line
    }
    file close `fh'
    assert `hits' == 0
    * the overlap path really ran: the 11-day overlap sums both daily rates
    quietly summarize cd if id == 1
    assert reldif(r(max), 61) < 1e-10
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: M4 quiet dose sweep"
}

**# I4: the help dose example crosses both dose cutpoints
* Mirrors the tvexpose.sthlp Cumulative dose example. Before the fix it passed
* a daily rate as the episode total and every row was "No dose" or "<300".
local ++tests
capture noisily {
    clear
    input long id str9(entry_s exit_s) byte female
    1 "01jan2020" "31dec2020" 1
    2 "01jan2020" "31dec2020" 0
    end
    generate double study_entry = date(entry_s, "DMY")
    generate double study_exit = date(exit_s, "DMY")
    format study_entry study_exit %td
    drop entry_s exit_s
    tempfile cohort episodes dose_episodes
    save `cohort'
    clear
    input long id str9(start_s stop_s) byte drug_class double daily_dose
    1 "05jan2020" "20feb2020" 1 10
    1 "01mar2020" "15apr2020" 2 20
    2 "10jun2020" "31jul2020" 1 10
    end
    generate double rx_start = date(start_s, "DMY")
    generate double rx_stop = date(stop_s, "DMY")
    format rx_start rx_stop %td
    drop start_s stop_s
    save `episodes'
    use `episodes', clear
    generate double rx_total = daily_dose * (rx_stop - rx_start + 1)
    assert rx_total == 470 in 1
    assert rx_total == 920 in 2
    assert rx_total == 520 in 3
    save `dose_episodes'
    use `cohort', clear
    tvexpose using `dose_episodes', id(id) start(rx_start) stop(rx_stop) ///
        exposure(rx_total) entry(study_entry) exit(study_exit) dose ///
        dosecuts(300 900) generate(cum_dose)
    * categories 0 = no dose, 1 = <300, 2 = 300-<900, 3 = 900+
    quietly levelsof cum_dose if id == 1, local(c1)
    quietly levelsof cum_dose if id == 2, local(c2)
    assert "`c1'" == "0 2 3"
    assert "`c2'" == "0 2"
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: I4 help dose example"
}

**# M3 (bytype): exposure value-label text reaches every bytype label verbatim
* Value-label text with a double quote, a backtick, and a dollar sign used to be
* dereferenced inside plain quotes in each bytype labelling path.
local ++tests
capture noisily {
    global TVQA_V1180_G "EXPANDED"
    clear
    input long id double(entry exit)
    1 0 400
    end
    tempfile coh ep
    save `coh'
    clear
    input long id double(rs re) byte drug
    1 100 150 1
    1 200 260 2
    end
    mata: st_local("hl", "Drug " + char(34) + "A" + char(34) + " " + char(96) + "x" + char(39) + " " + char(36) + "TVQA_V1180_G")
    label define drug_lbl 1 `"`macval(hl)'"' 2 "Other"
    label values drug drug_lbl
    save `ep'
    local nbad = 0
    foreach mode in "evertreated" "currentformer" "duration(30) continuousunit(days)" ///
        "continuousunit(days)" "recency(30) recencyunit(days)" {
        foreach lab in "" "withlabel" {
            use `coh', clear
            local labopt ""
            if "`lab'" != "" local labopt `"label("Rx")"'
            tvexpose using `ep', id(id) start(rs) stop(re) exposure(drug) ///
                reference(0) entry(entry) exit(exit) bytype `mode' `labopt'
            local hits = 0
            foreach v of varlist _all {
                mata: st_local("hit", strofreal(strpos(st_varlabel("`v'"), st_local("hl")) > 0))
                local hits = `hits' + `hit'
            }
            if `hits' != 1 {
                local ++nbad
                display as error "bytype `mode' `lab': `hits' variable label(s) carry the value-label text"
            }
        }
    }
    assert `nbad' == 0
    macro drop TVQA_V1180_G
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: M3 bytype value-label text"
}

**# M3 (master labels): keepvars() and entry/exit variable labels survive
local ++tests
capture noisily {
    global TVQA_V1180_G "EXPANDED"
    mata: st_local("hl", "Lab " + char(34) + "q" + char(34) + " " + char(96) + "x" + char(39) + " " + char(36) + "TVQA_V1180_G")
    clear
    input long id double(rs re) byte drug
    1 100 150 1
    end
    tempfile ep coh
    save `ep'
    clear
    input long id double(entry exit) byte female
    1 0 400 1
    end
    label variable female `"`macval(hl)'"'
    label variable entry `"`macval(hl)' entry"'
    label variable exit `"`macval(hl)' exit"'
    save `coh'
    foreach fp in "" "nofastpath" {
        use `coh', clear
        tvexpose using `ep', id(id) start(rs) stop(re) exposure(drug) ///
            reference(0) entry(entry) exit(exit) generate(tv) ///
            keepvars(female) keepdates `fp'
        mata: st_local("ok1", strofreal(st_varlabel("female") == st_local("hl")))
        mata: st_local("ok2", strofreal(st_varlabel("study_entry") == st_local("hl") + " entry"))
        mata: st_local("ok3", strofreal(st_varlabel("study_exit") == st_local("hl") + " exit"))
        assert `ok1' & `ok2' & `ok3'
    }
    macro drop TVQA_V1180_G
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: M3 master variable labels"
}

**# M3 (tvevent/tvbuild): event label text is not re-expanded
* eventlabel() was spliced unquoted into label define, and tvbuild forwarded it
* through an inline `if', so `x' vanished and $global expanded.
local ++tests
capture noisily {
    global TVQA_V1180_G "EXPANDED"
    mata: st_local("hl", "Ev " + char(96) + "x" + char(39) + " " + char(36) + "TVQA_V1180_G")
    clear
    input long id double(start stop)
    1 100 200
    end
    tempfile ivl
    save `ivl'
    clear
    input long id double edate
    1 150
    end
    label variable edate `"`macval(hl)' date"'
    tempfile ev
    save `ev'
    * default label comes from the date variable's label
    tvevent using `ivl', id(id) date(edate) generate(fail)
    local lbl : value label fail
    mata: st_local("ok", strofreal(st_vlmap("`lbl'", 1) == st_local("hl") + " date"))
    assert `ok'
    * eventlabel() override
    use `ev', clear
    local elab `"1 `"`macval(hl)'"'"'
    tvevent using `ivl', id(id) date(edate) generate(fail) eventlabel(`macval(elab)')
    local lbl : value label fail
    mata: st_local("ok", strofreal(st_vlmap("`lbl'", 1) == st_local("hl")))
    assert `ok'
    * the same override through tvbuild's event stage
    clear
    input long id double(entry exit) byte drug
    1 100 200 0
    end
    tempfile coh
    save `coh'
    clear
    input long id double(rs re) byte drug
    1 120 130 1
    end
    tempfile ep
    save `ep'
    use `coh', clear
    capture frame drop v1180_b
    capture frame drop v1180_b_manifest
    capture frame drop v1180_ev
    frame create v1180_ev
    frame v1180_ev: use `ev'
    tvbuild, sourceusing(`"`ep'"') id(id) entry(entry) exit(exit) ///
        start(rs) stop(re) exposure(drug) reference(0) generate(tvd) ///
        eventframe(v1180_ev) eventdate(edate) eventgenerate(fail) ///
        eventlabel(`macval(elab)') frameout(v1180_b) replace
    frame v1180_b {
        local lbl : value label fail
        mata: st_local("ok", strofreal(st_vlmap("`lbl'", 1) == st_local("hl")))
    }
    assert `ok'
    capture frame drop v1180_b
    capture frame drop v1180_b_manifest
    capture frame drop v1180_ev
    macro drop TVQA_V1180_G
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: M3 event label text"
}

**# tvweight: fractional time() fits and reports terms by the caller's name
local ++tests
capture noisily {
    clear
    set obs 200
    set seed 20261012
    generate long id = ceil(_n / 4)
    bysort id: generate double t = (_n - 1) + 0.5
    generate double x = rnormal()
    generate byte a = runiform() < invlogit(0.3 * x)
    tvweight a, covariates(x) id(id) time(t) stabilized numcovariates(x) ///
        generate(w) cumulative nolog
    assert "`r(numerator_model)'" == "x i.t"
    assert !missing(w, w_cum)
    * same model as integer time codes (one indicator per distinct value)
    generate long tint = t - 0.5
    tvweight a, covariates(x) id(id) time(tint) stabilized numcovariates(x) ///
        generate(w2) cumulative nolog
    assert reldif(w, w2) < 1e-10
    * string time() is refused by name
    generate str4 ts = string(tint)
    capture noisily tvweight a, covariates(x) id(id) time(ts) generate(w3)
    assert _rc == 109
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: tvweight fractional time()"
}

display "RESULT: test_tvtools_v1180 tests=`tests' pass=`pass' fail=`fail' skip=0"
capture log close _all
if `fail' exit 1
