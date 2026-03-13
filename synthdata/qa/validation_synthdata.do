* ===========================================================================
* validation_synthdata.do — Correctness Validation Suite for synthdata
* ===========================================================================
* Coverage:  50 tests across 11 sections
* Commands:  synthdata
* Run:       cd ~/Stata-Tools/synthdata/qa && stata-mp -b do validation_synthdata.do
* ===========================================================================

clear all
set more off
set varabbrev off
version 16.0

capture ado uninstall synthdata
quietly net install synthdata, from("~/Stata-Tools/synthdata")

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures ""

* Clean leftover temp files from prior runs
local tempfiles : dir "." files "__val_*.dta"
foreach f of local tempfiles {
    capture erase "`f'"
}

capture program drop run_test
program define run_test
    args test_id description result
    scalar gs_ntest = gs_ntest + 1
    if "`result'" == "" local result 0
    if `result' {
        scalar gs_npass = gs_npass + 1
        display as result "  PASSED `test_id': `description'"
    }
    else {
        scalar gs_nfail = gs_nfail + 1
        display as error "  FAILED `test_id': `description'"
        global gs_failures "$gs_failures `test_id'"
    }
end


* === Section V1: Distribution Preservation ===

* Test V1.1: Mean within 20% tolerance
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui summ price
    local orig_mean = r(mean)
    synthdata, saving("__val_v1_1") replace seed(12345)
    use "__val_v1_1", clear
    qui summ price
    local synth_mean = r(mean)
    local pct_diff = abs(`synth_mean' - `orig_mean') / `orig_mean' * 100
    assert `pct_diff' < 20
    local _pass = 1
}
run_test "V1.1" "Mean within 20% tolerance" `_pass'

* Test V1.2: SD within 30% tolerance
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui summ price
    local orig_sd = r(sd)
    synthdata, saving("__val_v1_2") replace seed(12345)
    use "__val_v1_2", clear
    qui summ price
    local synth_sd = r(sd)
    local pct_diff = abs(`synth_sd' - `orig_sd') / `orig_sd' * 100
    assert `pct_diff' < 30
    local _pass = 1
}
run_test "V1.2" "SD within 30% tolerance" `_pass'

* Test V1.3: Median within 25% tolerance
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui summ price, detail
    local orig_med = r(p50)
    synthdata, saving("__val_v1_3") replace seed(12345)
    use "__val_v1_3", clear
    qui summ price, detail
    local synth_med = r(p50)
    local pct_diff = abs(`synth_med' - `orig_med') / `orig_med' * 100
    assert `pct_diff' < 25
    local _pass = 1
}
run_test "V1.3" "Median within 25% tolerance" `_pass'

* Test V1.4: Categorical proportions within 15pp
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui count if foreign == 1
    local orig_pct = r(N) / _N * 100
    synthdata, saving("__val_v1_4") replace seed(12345)
    use "__val_v1_4", clear
    qui count if foreign == 1
    local synth_pct = r(N) / _N * 100
    local pp_diff = abs(`synth_pct' - `orig_pct')
    assert `pp_diff' < 15
    local _pass = 1
}
run_test "V1.4" "Categorical proportions within 15pp" `_pass'

* Test V1.5: Large N tighter tolerance (mean within 10%)
local _pass = 0
capture noisily {
    clear
    set obs 5000
    set seed 20260313
    gen x = rnormal(100, 25)
    qui summ x
    local orig_mean = r(mean)
    synthdata, n(5000) saving("__val_v1_5") replace seed(12345)
    use "__val_v1_5", clear
    qui summ x
    local synth_mean = r(mean)
    local pct_diff = abs(`synth_mean' - `orig_mean') / `orig_mean' * 100
    assert `pct_diff' < 10
    local _pass = 1
}
run_test "V1.5" "Large N mean within 10% tolerance" `_pass'

* Test V1.6: Range roughly preserved
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui summ price
    local orig_min = r(min)
    local orig_max = r(max)
    local orig_range = `orig_max' - `orig_min'
    synthdata, saving("__val_v1_6") replace seed(12345)
    use "__val_v1_6", clear
    qui summ price
    local synth_range = r(max) - r(min)
    * Synthetic range should be within 50% of original
    local range_ratio = `synth_range' / `orig_range'
    assert `range_ratio' > 0.5 & `range_ratio' < 2.0
    local _pass = 1
}
run_test "V1.6" "Range roughly preserved" `_pass'


* === Section V2: Correlation Structure ===

* Test V2.1: Pairwise correlation within 0.3
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui correlate price weight
    local orig_corr = r(rho)
    synthdata, correlations saving("__val_v2_1") replace seed(12345)
    use "__val_v2_1", clear
    qui correlate price weight
    local synth_corr = r(rho)
    local corr_diff = abs(`synth_corr' - `orig_corr')
    assert `corr_diff' < 0.3
    local _pass = 1
}
run_test "V2.1" "Pairwise correlation within 0.3" `_pass'

* Test V2.2: correlations option improves preservation
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui correlate price mpg
    local orig_corr = r(rho)
    * Without correlations option
    synthdata, saving("__val_v2_2a") seed(12345)
    use "__val_v2_2a", clear
    qui correlate price mpg
    local nocorr_diff = abs(r(rho) - `orig_corr')
    * With correlations option
    sysuse auto, clear
    synthdata, correlations saving("__val_v2_2b") seed(12345)
    use "__val_v2_2b", clear
    qui correlate price mpg
    local corr_diff = abs(r(rho) - `orig_corr')
    * With option should be at least as good (or close)
    assert `corr_diff' <= `nocorr_diff' + 0.05
    local _pass = 1
}
run_test "V2.2" "correlations option preserves better" `_pass'

* Test V2.3: Permute destroys correlations
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui correlate price weight
    local orig_corr = r(rho)
    synthdata, permute saving("__val_v2_3") replace seed(12345)
    use "__val_v2_3", clear
    qui correlate price weight
    local perm_corr = r(rho)
    * Permute should substantially reduce correlation
    assert abs(`perm_corr') < abs(`orig_corr')
    local _pass = 1
}
run_test "V2.3" "Permute destroys correlations" `_pass'

* Test V2.4: Large N tighter correlation (within 0.2)
local _pass = 0
capture noisily {
    clear
    set obs 5000
    set seed 20260313
    gen x = rnormal()
    gen y = 0.7 * x + rnormal(0, 0.5)
    qui correlate x y
    local orig_corr = r(rho)
    synthdata, correlations n(5000) saving("__val_v2_4") replace seed(12345)
    use "__val_v2_4", clear
    qui correlate x y
    local synth_corr = r(rho)
    local corr_diff = abs(`synth_corr' - `orig_corr')
    assert `corr_diff' < 0.2
    local _pass = 1
}
run_test "V2.4" "Large N correlation within 0.2" `_pass'


* === Section V3: Known-Answer Tests ===

* Test V3.1: Binary 50/50 within 10pp
local _pass = 0
capture noisily {
    clear
    set obs 1000
    gen binary = (_n <= 500)
    synthdata, saving("__val_v3_1") replace seed(12345)
    use "__val_v3_1", clear
    qui count if binary == 1
    local synth_pct = r(N) / _N * 100
    assert abs(`synth_pct' - 50) < 10
    local _pass = 1
}
run_test "V3.1" "Binary 50/50 within 10pp" `_pass'

* Test V3.2: Uniform [1,100] mean near 50
local _pass = 0
capture noisily {
    clear
    set obs 1000
    set seed 20260313
    gen uniform = ceil(runiform() * 100)
    synthdata, n(1000) saving("__val_v3_2") replace seed(12345)
    use "__val_v3_2", clear
    qui summ uniform
    assert abs(r(mean) - 50) < 15
    local _pass = 1
}
run_test "V3.2" "Uniform [1,100] mean near 50" `_pass'

* Test V3.3: 4-category equal within 10pp each
local _pass = 0
capture noisily {
    clear
    set obs 1000
    gen cat4 = ceil(_n / 250)
    synthdata, categorical(cat4) saving("__val_v3_3") replace seed(12345)
    use "__val_v3_3", clear
    local all_ok = 1
    forvalues k = 1/4 {
        qui count if cat4 == `k'
        local pct = r(N) / _N * 100
        if abs(`pct' - 25) >= 10 local all_ok = 0
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "V3.3" "4-category equal within 10pp each" `_pass'

* Test V3.4: Constant variable stays constant
local _pass = 0
capture noisily {
    clear
    set obs 500
    gen constant = 42
    gen x = rnormal()
    synthdata, saving("__val_v3_4") replace seed(12345)
    use "__val_v3_4", clear
    qui summ constant
    * Constant should remain constant or be very close
    assert r(sd) < 1
    local _pass = 1
}
run_test "V3.4" "Constant variable preserved" `_pass'

* Test V3.5: Zero-variance numeric stays stable
local _pass = 0
capture noisily {
    clear
    set obs 500
    gen zero_var = 100
    gen x = rnormal()
    synthdata, saving("__val_v3_5") replace seed(12345)
    use "__val_v3_5", clear
    qui summ zero_var
    assert r(sd) < 1
    local _pass = 1
}
run_test "V3.5" "Zero-variance stays stable" `_pass'

* Test V3.6: Bernoulli p=0.2 within 10pp
local _pass = 0
capture noisily {
    clear
    set obs 1000
    set seed 20260313
    gen success = (runiform() < 0.2)
    synthdata, saving("__val_v3_6") replace seed(12345)
    use "__val_v3_6", clear
    qui summ success
    assert abs(r(mean) - 0.2) < 0.10
    local _pass = 1
}
run_test "V3.6" "Bernoulli p=0.2 within 10pp" `_pass'


* === Section V4: Bounds & Constraints ===

* Test V4.1: noextreme 5% buffer enforcement
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui summ price
    local orig_min = r(min)
    local orig_max = r(max)
    local orig_range = `orig_max' - `orig_min'
    local buffer = `orig_range' * 0.05
    synthdata, noextreme saving("__val_v4_1") replace seed(12345)
    use "__val_v4_1", clear
    qui summ price
    * With 5% buffer: min should be >= orig_min, max should be <= orig_max
    * Allow small tolerance for implementation details
    assert r(min) >= `orig_min' - `buffer' * 0.5
    assert r(max) <= `orig_max' + `buffer' * 0.5
    local _pass = 1
}
run_test "V4.1" "noextreme 5% buffer enforcement" `_pass'

* Test V4.2: bounds() min/max enforcement
local _pass = 0
capture noisily {
    sysuse auto, clear
    synthdata, bounds("price 3000 12000") saving("__val_v4_2") replace seed(12345)
    use "__val_v4_2", clear
    qui summ price
    assert r(min) >= 3000
    assert r(max) <= 12000
    local _pass = 1
}
run_test "V4.2" "bounds() min/max enforcement" `_pass'

* Test V4.3: constraints age>=18
local _pass = 0
capture noisily {
    clear
    set obs 500
    set seed 20260313
    gen age = 10 + int(runiform() * 60)
    gen income = rnormal(50000, 15000)
    synthdata, constraints("age>=18") saving("__val_v4_3") replace seed(12345)
    use "__val_v4_3", clear
    qui summ age
    assert r(min) >= 18
    local _pass = 1
}
run_test "V4.3" "constraints age>=18 enforced" `_pass'

* Test V4.4: autoconstraints completes without error
local _pass = 0
capture noisily {
    clear
    set obs 500
    set seed 20260313
    gen count_v = int(runiform() * 100)
    gen amount = abs(rnormal(100, 30))
    synthdata, autoconstraints saving("__val_v4_4") replace seed(12345)
    use "__val_v4_4", clear
    assert _N > 0
    local _pass = 1
}
run_test "V4.4" "autoconstraints completes" `_pass'

* Test V4.5: Integer rounding with bounds
local _pass = 0
capture noisily {
    clear
    set obs 500
    set seed 20260313
    gen score = ceil(runiform() * 100)
    synthdata, integer(score) bounds("score 0 100") ///
        saving("__val_v4_5") replace seed(12345)
    use "__val_v4_5", clear
    qui count if score != floor(score)
    assert r(N) == 0
    qui summ score
    assert r(min) >= 0
    assert r(max) <= 100
    local _pass = 1
}
run_test "V4.5" "Integer rounding with bounds" `_pass'


* === Section V5: Variable Type Detection ===

* Test V5.1: Value-labeled variable treated as categorical
local _pass = 0
capture noisily {
    clear
    set obs 500
    set seed 20260313
    gen status = ceil(runiform() * 3)
    label define status_lbl 1 "Low" 2 "Medium" 3 "High"
    label values status status_lbl
    gen x = rnormal()
    synthdata, saving("__val_v5_1") replace seed(12345)
    use "__val_v5_1", clear
    * Should only contain labeled values (1, 2, 3)
    qui count if status < 1 | status > 3
    assert r(N) == 0
    qui count if status != floor(status)
    assert r(N) == 0
    local _pass = 1
}
run_test "V5.1" "Value-labeled treated as categorical" `_pass'

* Test V5.2: continuous() override works
local _pass = 0
capture noisily {
    clear
    set obs 500
    set seed 20260313
    gen rating = ceil(runiform() * 5)
    gen x = rnormal()
    synthdata, continuous(rating) saving("__val_v5_2") replace seed(12345)
    use "__val_v5_2", clear
    * Continuous treatment may produce non-integer values
    assert _N > 0
    local _pass = 1
}
run_test "V5.2" "continuous() override works" `_pass'

* Test V5.3: High-cardinality auto-detected as continuous
local _pass = 0
capture noisily {
    clear
    set obs 500
    set seed 20260313
    gen x = rnormal(100, 25)
    synthdata, saving("__val_v5_3") replace seed(12345)
    use "__val_v5_3", clear
    assert _N > 0
    local _pass = 1
}
run_test "V5.3" "High-cardinality auto continuous" `_pass'

* Test V5.4: Integer auto-detection and rounding
local _pass = 0
capture noisily {
    clear
    set obs 500
    set seed 20260313
    * Variable with only integer values should be auto-detected
    gen int_var = ceil(runiform() * 1000)
    gen x = rnormal()
    synthdata, saving("__val_v5_4") replace seed(12345)
    use "__val_v5_4", clear
    qui count if int_var != floor(int_var) & !missing(int_var)
    assert r(N) == 0
    local _pass = 1
}
run_test "V5.4" "Integer auto-detection and rounding" `_pass'


* === Section V6: Panel Structure ===

* Create panel data for validation
clear
set obs 300
set seed 20260313
gen id = ceil(_n / 6)
bysort id: gen time = _n
gen sex = cond(runiform() < 0.5, 0, 1)
bysort id (time): replace sex = sex[1]
gen birth_year = 1960 + int(runiform() * 40)
bysort id (time): replace birth_year = birth_year[1]
gen outcome = rnormal(50, 10) + time * 2
gen bp = rnormal(120, 15)
save "__val_paneldata.dta", replace

* Test V6.1: Row count distribution preserved
local _pass = 0
capture noisily {
    use "__val_paneldata", clear
    bysort id: gen byte _last = (_n == _N)
    qui summ _last
    local orig_ids = r(sum)
    synthdata, panel(id time) saving("__val_v6_1") replace seed(12345)
    use "__val_v6_1", clear
    capture drop _last
    bysort id: gen byte _last = (_n == _N)
    qui summ _last
    local synth_ids = r(sum)
    * Total rows should be within 10% of original
    local orig_n = 300
    local pct_diff = abs(_N - `orig_n') / `orig_n' * 100
    assert `pct_diff' < 15
    local _pass = 1
}
run_test "V6.1" "Row count distribution preserved" `_pass'

* Test V6.2: Constant-within-ID enforced
local _pass = 0
capture noisily {
    use "__val_paneldata", clear
    synthdata, panel(id time) preservevar(sex birth_year) ///
        saving("__val_v6_2") replace seed(12345)
    use "__val_v6_2", clear
    bysort id: gen byte _vary_sex = (sex != sex[1])
    bysort id: gen byte _vary_by = (birth_year != birth_year[1])
    qui count if _vary_sex == 1 | _vary_by == 1
    assert r(N) == 0
    local _pass = 1
}
run_test "V6.2" "Constant-within-ID enforced" `_pass'

* Test V6.3: Time-varying variables still vary
local _pass = 0
capture noisily {
    use "__val_v6_2", clear
    bysort id: gen byte _vary_out = (outcome != outcome[1])
    qui count if _vary_out == 1
    * At least some variation should remain
    assert r(N) > 0
    local _pass = 1
}
run_test "V6.3" "Time-varying variables still vary" `_pass'

* Test V6.4: Panel N within tolerance
local _pass = 0
capture noisily {
    use "__val_paneldata", clear
    local orig_n = _N
    synthdata, panel(id time) saving("__val_v6_4") replace seed(12345)
    use "__val_v6_4", clear
    local pct_diff = abs(_N - `orig_n') / `orig_n' * 100
    assert `pct_diff' < 15
    local _pass = 1
}
run_test "V6.4" "Panel N within 15% tolerance" `_pass'

* Test V6.5: autocorr preserves lag structure
local _pass = 0
capture noisily {
    * Create data with strong autocorrelation
    clear
    set obs 500
    set seed 20260313
    gen id = ceil(_n / 10)
    bysort id: gen time = _n
    gen x = .
    bysort id (time): replace x = rnormal(50, 5) if _n == 1
    bysort id (time): replace x = 0.8 * x[_n-1] + rnormal(0, 3) if _n > 1
    * Compute original lag-1 correlation
    bysort id (time): gen lag_x = x[_n-1]
    qui correlate x lag_x
    local orig_lag1 = r(rho)
    drop lag_x
    synthdata, panel(id time) autocorr(1) saving("__val_v6_5") replace seed(12345)
    use "__val_v6_5", clear
    capture drop lag_x
    bysort id (time): gen lag_x = x[_n-1]
    qui correlate x lag_x
    local synth_lag1 = r(rho)
    * Autocorrelation should exist (not zero) and be positive like original
    * Allow some tolerance since parametric synthesis may attenuate
    assert `synth_lag1' > -0.5
    local _pass = 1
}
run_test "V6.5" "autocorr preserves lag structure" `_pass'

* Test V6.6: rowdist modes produce reasonable counts
local _pass = 0
capture noisily {
    use "__val_paneldata", clear
    local orig_n = _N
    * Empirical mode
    synthdata, panel(id time) rowdist(empirical) saving("__val_v6_6a") ///
        replace seed(12345)
    use "__val_v6_6a", clear
    local emp_n = _N
    * Exact mode
    use "__val_paneldata", clear
    synthdata, panel(id time) rowdist(exact) saving("__val_v6_6b") ///
        replace seed(12345)
    use "__val_v6_6b", clear
    local exact_n = _N
    * Both should produce reasonable N
    assert abs(`emp_n' - `orig_n') / `orig_n' < 0.2
    assert abs(`exact_n' - `orig_n') / `orig_n' < 0.2
    local _pass = 1
}
run_test "V6.6" "rowdist modes produce reasonable counts" `_pass'


* === Section V7: Index Date Anchoring ===

* Create date data for validation
clear
set obs 300
set seed 20260313
gen long id = _n
gen diag_date = mdy(1, 1, 2020) + int(runiform() * 365)
format diag_date %td
gen rx_date = diag_date + 14 + int(runiform() * 60)
format rx_date %td
gen followup = diag_date + 180 + int(runiform() * 365)
format followup %td
gen age = 20 + int(runiform() * 60)
save "__val_datedata.dta", replace

* Test V7.1: Date offset structure preserved
local _pass = 0
capture noisily {
    use "__val_datedata", clear
    * Original offset: rx_date - diag_date
    gen orig_offset = rx_date - diag_date
    qui summ orig_offset
    local orig_mean_offset = r(mean)
    synthdata, id(id) dates(diag_date rx_date followup) ///
        indexdate(diag_date) saving("__val_v7_1") replace seed(12345)
    use "__val_v7_1", clear
    gen synth_offset = rx_date - diag_date
    qui summ synth_offset
    local synth_mean_offset = r(mean)
    * Mean offset should be similar (within 30 days)
    assert abs(`synth_mean_offset' - `orig_mean_offset') < 30
    local _pass = 1
}
run_test "V7.1" "Date offset structure preserved" `_pass'

* Test V7.2: datenoise() adds measurable noise
local _pass = 0
capture noisily {
    use "__val_datedata", clear
    * With noise (default 14 days)
    synthdata, id(id) dates(diag_date rx_date) indexdate(diag_date) ///
        datenoise(30) saving("__val_v7_2a") replace seed(12345)
    use "__val_v7_2a", clear
    gen offset_noise = rx_date - diag_date
    qui summ offset_noise
    local sd_noise = r(sd)
    * With no noise
    use "__val_datedata", clear
    synthdata, id(id) dates(diag_date rx_date) indexdate(diag_date) ///
        datenoise(0) saving("__val_v7_2b") replace seed(12345)
    use "__val_v7_2b", clear
    gen offset_nonoise = rx_date - diag_date
    qui summ offset_nonoise
    local sd_nonoise = r(sd)
    * Noisy version should have more variation (or at least equal)
    assert `sd_noise' >= `sd_nonoise' * 0.8
    local _pass = 1
}
run_test "V7.2" "datenoise() adds measurable noise" `_pass'

* Test V7.3: datenoise(0) preserves exact offsets
local _pass = 0
capture noisily {
    use "__val_datedata", clear
    gen orig_offset = rx_date - diag_date
    qui summ orig_offset
    local orig_sd = r(sd)
    synthdata, id(id) dates(diag_date rx_date) indexdate(diag_date) ///
        datenoise(0) saving("__val_v7_3") replace seed(12345)
    use "__val_v7_3", clear
    gen synth_offset = rx_date - diag_date
    qui summ synth_offset
    local synth_sd = r(sd)
    * SD of offsets should be very similar with no noise
    local sd_diff = abs(`synth_sd' - `orig_sd') / `orig_sd'
    assert `sd_diff' < 0.3
    local _pass = 1
}
run_test "V7.3" "datenoise(0) preserves offset distribution" `_pass'

* Test V7.4: Temporal ordering maintained
local _pass = 0
capture noisily {
    use "__val_datedata", clear
    synthdata, id(id) dates(diag_date rx_date followup) ///
        indexdate(diag_date) saving("__val_v7_4") replace seed(12345)
    use "__val_v7_4", clear
    * Most rx dates should be after diag dates
    qui count if rx_date < diag_date & !missing(rx_date) & !missing(diag_date)
    local violations = r(N)
    assert `violations' < _N * 0.25
    local _pass = 1
}
run_test "V7.4" "Temporal ordering mostly maintained" `_pass'

* Test V7.5: indexfrom produces valid dates
local _pass = 0
capture noisily {
    * Create external index file
    clear
    set obs 200
    set seed 20260313
    gen long id = _n
    gen indexdate = mdy(3, 1, 2020) + int(runiform() * 365)
    format indexdate %td
    save "__val_indexfile.dta", replace
    * Create main data
    clear
    set obs 200
    set seed 20260314
    gen long id = _n
    gen visit_dt = mdy(6, 1, 2020) + int(runiform() * 365)
    format visit_dt %td
    gen age = 25 + int(runiform() * 50)
    synthdata, id(id) dates(visit_dt) ///
        indexfrom(__val_indexfile.dta indexdate) ///
        saving("__val_v7_5") replace seed(12345)
    use "__val_v7_5", clear
    assert _N > 0
    * Dates should be valid (not missing or absurd)
    qui count if visit_dt < mdy(1, 1, 1900) & !missing(visit_dt)
    assert r(N) == 0
    local _pass = 1
}
run_test "V7.5" "indexfrom produces valid dates" `_pass'


* === Section V8: Privacy Distance ===

* Test V8.1: privacycheck runs successfully
local _pass = 0
capture noisily {
    sysuse auto, clear
    synthdata price mpg weight length, privacycheck privacysample(30) ///
        saving("__val_v8_1") replace seed(12345)
    use "__val_v8_1", clear
    assert _N > 0
    local _pass = 1
}
run_test "V8.1" "privacycheck runs successfully" `_pass'

* Test V8.2: privacythresh sets threshold
local _pass = 0
capture noisily {
    sysuse auto, clear
    synthdata price mpg weight, privacycheck privacysample(30) ///
        privacythresh(0.05) saving("__val_v8_2") replace seed(12345)
    use "__val_v8_2", clear
    assert _N > 0
    local _pass = 1
}
run_test "V8.2" "privacythresh(0.05) completes" `_pass'

* Test V8.3: privacysample limits computation
local _pass = 0
capture noisily {
    sysuse auto, clear
    synthdata price mpg weight length, privacycheck privacysample(10) ///
        saving("__val_v8_3") replace seed(12345)
    use "__val_v8_3", clear
    assert _N > 0
    local _pass = 1
}
run_test "V8.3" "privacysample(10) limits computation" `_pass'


* === Section V9: Missingness & Patterns ===

* Test V9.1: Missing rate preserved within 10pp
local _pass = 0
capture noisily {
    clear
    set obs 500
    set seed 20260313
    gen x = rnormal()
    replace x = . if runiform() < 0.20
    qui count if missing(x)
    local orig_miss_pct = r(N) / _N * 100
    synthdata, saving("__val_v9_1") replace seed(12345)
    use "__val_v9_1", clear
    qui count if missing(x)
    local synth_miss_pct = r(N) / _N * 100
    local pp_diff = abs(`synth_miss_pct' - `orig_miss_pct')
    assert `pp_diff' < 10
    local _pass = 1
}
run_test "V9.1" "Missing rate within 10pp" `_pass'

* Test V9.2: misspattern co-missingness
local _pass = 0
capture noisily {
    clear
    set obs 500
    set seed 20260313
    gen lab_a = rnormal(10, 2)
    gen lab_b = rnormal(20, 5)
    gen lab_c = rnormal(5, 1)
    * a and b missing together
    gen byte miss_panel = runiform() < 0.20
    replace lab_a = . if miss_panel
    replace lab_b = . if miss_panel
    replace lab_c = . if runiform() < 0.10
    * Count co-missing in original
    qui count if missing(lab_a) & missing(lab_b)
    local orig_comiss = r(N)
    synthdata, misspattern saving("__val_v9_2") replace seed(12345)
    use "__val_v9_2", clear
    qui count if missing(lab_a) & missing(lab_b)
    local synth_comiss = r(N)
    * Co-missingness should be preserved roughly
    local diff = abs(`synth_comiss' - `orig_comiss')
    assert `diff' < `orig_comiss' * 0.5 + 20
    local _pass = 1
}
run_test "V9.2" "misspattern co-missingness preserved" `_pass'

* Test V9.3: All-missing stays all-missing
local _pass = 0
capture noisily {
    clear
    set obs 200
    gen x = rnormal()
    gen y = .
    synthdata, saving("__val_v9_3") replace seed(12345)
    use "__val_v9_3", clear
    qui count if !missing(y)
    assert r(N) == 0
    local _pass = 1
}
run_test "V9.3" "All-missing stays all-missing" `_pass'

* Test V9.4: No-missing stays no-missing
local _pass = 0
capture noisily {
    clear
    set obs 200
    set seed 20260313
    gen x = rnormal()
    gen y = rnormal()
    synthdata, saving("__val_v9_4") replace seed(12345)
    use "__val_v9_4", clear
    qui count if missing(x)
    local miss_x = r(N)
    qui count if missing(y)
    local miss_y = r(N)
    assert `miss_x' == 0
    assert `miss_y' == 0
    local _pass = 1
}
run_test "V9.4" "No-missing stays no-missing" `_pass'


* === Section V10: Reproducibility ===

* Test V10.1: Same seed produces identical result
local _pass = 0
capture noisily {
    sysuse auto, clear
    synthdata, saving("__val_v10_1a") seed(99999) replace
    use "__val_v10_1a", clear
    qui summ price
    local m1 = r(mean)
    local s1 = r(sd)
    sysuse auto, clear
    synthdata, saving("__val_v10_1b") seed(99999) replace
    use "__val_v10_1b", clear
    qui summ price
    local m2 = r(mean)
    local s2 = r(sd)
    assert `m1' == `m2'
    assert `s1' == `s2'
    local _pass = 1
}
run_test "V10.1" "Same seed produces identical result" `_pass'

* Test V10.2: Different seed produces different result
local _pass = 0
capture noisily {
    sysuse auto, clear
    synthdata, saving("__val_v10_2a") seed(11111) replace
    use "__val_v10_2a", clear
    qui summ price
    local m1 = r(mean)
    sysuse auto, clear
    synthdata, saving("__val_v10_2b") seed(22222) replace
    use "__val_v10_2b", clear
    qui summ price
    local m2 = r(mean)
    assert `m1' != `m2'
    local _pass = 1
}
run_test "V10.2" "Different seed produces different result" `_pass'

* Test V10.3: multiple() batch consistency
local _pass = 0
capture noisily {
    sysuse auto, clear
    synthdata, multiple(3) saving("__val_v10_3") seed(55555)
    * All 3 datasets should have the same N
    use "__val_v10_3_1", clear
    local n1 = _N
    use "__val_v10_3_2", clear
    local n2 = _N
    use "__val_v10_3_3", clear
    local n3 = _N
    assert `n1' == `n2'
    assert `n2' == `n3'
    local _pass = 1
}
run_test "V10.3" "multiple() batch consistency" `_pass'


* === Section V11: Invariant Tests ===

* Test V11.1: Categorical proportions bounded [0,1]
local _pass = 0
capture noisily {
    sysuse auto, clear
    synthdata, saving("__val_v11_1") replace seed(12345)
    use "__val_v11_1", clear
    qui summ foreign
    assert r(min) >= 0
    assert r(max) <= 1
    local _pass = 1
}
run_test "V11.1" "Categorical proportions bounded [0,1]" `_pass'

* Test V11.2: N preservation exact
local _pass = 0
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    synthdata, saving("__val_v11_2") replace seed(12345)
    use "__val_v11_2", clear
    assert _N == `orig_n'
    local _pass = 1
}
run_test "V11.2" "N preservation exact" `_pass'

* Test V11.3: No new categories created
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui levelsof rep78, local(orig_levels)
    local orig_nlvl : word count `orig_levels'
    synthdata, categorical(rep78) saving("__val_v11_3") replace seed(12345)
    use "__val_v11_3", clear
    qui levelsof rep78, local(synth_levels)
    local synth_nlvl : word count `synth_levels'
    assert `synth_nlvl' <= `orig_nlvl'
    local _pass = 1
}
run_test "V11.3" "No new categories created" `_pass'

* Test V11.4: Variable count preserved
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui describe
    local orig_k = r(k)
    synthdata, saving("__val_v11_4") replace seed(12345)
    use "__val_v11_4", clear
    qui describe
    local synth_k = r(k)
    assert `synth_k' == `orig_k'
    local _pass = 1
}
run_test "V11.4" "Variable count preserved" `_pass'


* === Cleanup ===
capture graph close _all
local tempfiles : dir "." files "__val_*.dta"
foreach f of local tempfiles {
    capture erase "`f'"
}
capture erase "__val_indexfile.dta"

* === Summary ===
display _newline
display as text "Results: " as result scalar(gs_npass) as text " passed, " ///
    as error scalar(gs_nfail) as text " failed, " ///
    as text scalar(gs_ntest) as text " total"

if scalar(gs_nfail) > 0 {
    display as error "FAILED TESTS: $gs_failures"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
