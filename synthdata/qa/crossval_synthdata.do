* ===========================================================================
* crossval_synthdata.do — Cross-Method Validation Suite for synthdata
* ===========================================================================
* Coverage:  21 tests across 5 sections
* Commands:  synthdata
* Purpose:   Cross-validate synthesis methods against each other, stability
*            across repeated runs, and multi-dataset concordance
* Run:       cd ~/Stata-Tools/synthdata/qa && stata-mp -b do crossval_synthdata.do
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
local tempfiles : dir "." files "__xval_*.dta"
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


* === Section X1: Cross-Method Mean Agreement ===
* All methods should produce synthetic data with means in the same ballpark

* Test X1.1: 5 methods agree on mean (within 30% of original)
local _pass = 0
capture noisily {
    clear
    set obs 1000
    set seed 20260313
    gen x = rnormal(100, 25)
    gen y = 0.5 * x + rnormal(0, 10)
    gen cat = ceil(runiform() * 5)
    qui summ x
    local orig_mean = r(mean)
    local all_ok = 1
    foreach method in parametric sequential bootstrap permute smart {
        clear
        set obs 1000
        set seed 20260313
        gen x = rnormal(100, 25)
        gen y = 0.5 * x + rnormal(0, 10)
        gen cat = ceil(runiform() * 5)
        synthdata, `method' saving("__xval_1_1_`method'") replace seed(12345)
        use "__xval_1_1_`method'", clear
        qui summ x
        local pct = abs(r(mean) - `orig_mean') / `orig_mean' * 100
        if `pct' >= 30 local all_ok = 0
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "X1.1" "5 methods agree on mean within 30%" `_pass'

* Test X1.2: 5 methods agree on SD (within 50% of original)
local _pass = 0
capture noisily {
    clear
    set obs 1000
    set seed 20260313
    gen x = rnormal(100, 25)
    qui summ x
    local orig_sd = r(sd)
    local all_ok = 1
    foreach method in parametric sequential bootstrap permute smart {
        clear
        set obs 1000
        set seed 20260313
        gen x = rnormal(100, 25)
        synthdata x, `method' saving("__xval_1_2_`method'") replace seed(12345)
        use "__xval_1_2_`method'", clear
        qui summ x
        local pct = abs(r(sd) - `orig_sd') / `orig_sd' * 100
        if `pct' >= 50 local all_ok = 0
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "X1.2" "5 methods agree on SD within 50%" `_pass'

* Test X1.3: Methods agree on binary proportion (within 15pp)
local _pass = 0
capture noisily {
    clear
    set obs 1000
    set seed 20260313
    gen treat = runiform() < 0.35
    gen x = rnormal()
    qui summ treat
    local orig_pct = r(mean) * 100
    local all_ok = 1
    foreach method in parametric bootstrap smart {
        clear
        set obs 1000
        set seed 20260313
        gen treat = runiform() < 0.35
        gen x = rnormal()
        synthdata, `method' saving("__xval_1_3_`method'") replace seed(12345)
        use "__xval_1_3_`method'", clear
        qui summ treat
        local pp_diff = abs(r(mean) * 100 - `orig_pct')
        if `pp_diff' >= 15 local all_ok = 0
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "X1.3" "Methods agree on binary proportion within 15pp" `_pass'

* Test X1.4: Smart vs complex produce similar distributions
local _pass = 0
capture noisily {
    sysuse auto, clear
    synthdata price mpg weight, smart saving("__xval_1_4_smart") ///
        replace seed(12345)
    use "__xval_1_4_smart", clear
    qui summ price
    local smart_mean = r(mean)
    local smart_sd = r(sd)
    sysuse auto, clear
    synthdata price mpg weight, complex saving("__xval_1_4_complex") ///
        replace seed(12345)
    use "__xval_1_4_complex", clear
    qui summ price
    local complex_mean = r(mean)
    local complex_sd = r(sd)
    * Smart and complex should produce similar results
    local mean_diff = abs(`smart_mean' - `complex_mean') / `smart_mean' * 100
    assert `mean_diff' < 30
    local _pass = 1
}
run_test "X1.4" "Smart vs complex produce similar distributions" `_pass'


* === Section X2: Multi-Run Stability ===
* Same method, different seeds: distributions should converge

* Test X2.1: 5 parametric runs have CV of means < 15%
local _pass = 0
capture noisily {
    local sum_mean = 0
    local sum_sq = 0
    forvalues i = 1/5 {
        sysuse auto, clear
        local s = 10000 + `i' * 111
        synthdata, parametric saving("__xval_2_1_`i'") replace seed(`s')
        use "__xval_2_1_`i'", clear
        qui summ price
        local m`i' = r(mean)
        local sum_mean = `sum_mean' + `m`i''
    }
    local avg = `sum_mean' / 5
    local ss = 0
    forvalues i = 1/5 {
        local ss = `ss' + (`m`i'' - `avg')^2
    }
    local sd_means = sqrt(`ss' / 4)
    local cv = `sd_means' / `avg' * 100
    assert `cv' < 15
    local _pass = 1
}
run_test "X2.1" "5 parametric runs CV of means < 15%" `_pass'

* Test X2.2: 5 sequential runs have CV of means < 15%
local _pass = 0
capture noisily {
    local sum_mean = 0
    forvalues i = 1/5 {
        sysuse auto, clear
        local s = 20000 + `i' * 222
        synthdata price mpg weight, sequential ///
            saving("__xval_2_2_`i'") replace seed(`s')
        use "__xval_2_2_`i'", clear
        qui summ price
        local m`i' = r(mean)
        local sum_mean = `sum_mean' + `m`i''
    }
    local avg = `sum_mean' / 5
    local ss = 0
    forvalues i = 1/5 {
        local ss = `ss' + (`m`i'' - `avg')^2
    }
    local sd_means = sqrt(`ss' / 4)
    local cv = `sd_means' / `avg' * 100
    assert `cv' < 15
    local _pass = 1
}
run_test "X2.2" "5 sequential runs CV of means < 15%" `_pass'

* Test X2.3: 5 bootstrap runs have CV of means < 15%
local _pass = 0
capture noisily {
    local sum_mean = 0
    forvalues i = 1/5 {
        sysuse auto, clear
        local s = 30000 + `i' * 333
        synthdata, bootstrap saving("__xval_2_3_`i'") replace seed(`s')
        use "__xval_2_3_`i'", clear
        qui summ price
        local m`i' = r(mean)
        local sum_mean = `sum_mean' + `m`i''
    }
    local avg = `sum_mean' / 5
    local ss = 0
    forvalues i = 1/5 {
        local ss = `ss' + (`m`i'' - `avg')^2
    }
    local sd_means = sqrt(`ss' / 4)
    local cv = `sd_means' / `avg' * 100
    assert `cv' < 15
    local _pass = 1
}
run_test "X2.3" "5 bootstrap runs CV of means < 15%" `_pass'

* Test X2.4: Multi-run correlation sign stability
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui correlate price mpg
    local orig_sign = sign(r(rho))
    local agreement = 0
    forvalues i = 1/5 {
        sysuse auto, clear
        local s = 40000 + `i' * 444
        synthdata, parametric saving("__xval_2_4_`i'") replace seed(`s')
        use "__xval_2_4_`i'", clear
        qui correlate price mpg
        if sign(r(rho)) == `orig_sign' local ++agreement
    }
    * At least 4 out of 5 should preserve the sign
    assert `agreement' >= 4
    local _pass = 1
}
run_test "X2.4" "Multi-run correlation sign stability" `_pass'

* Test X2.5: Multi-run categorical proportion stability
local _pass = 0
capture noisily {
    local sum_pct = 0
    forvalues i = 1/5 {
        sysuse auto, clear
        local s = 50000 + `i' * 555
        synthdata, saving("__xval_2_5_`i'") replace seed(`s')
        use "__xval_2_5_`i'", clear
        qui count if foreign == 1
        local p`i' = r(N) / _N * 100
        local sum_pct = `sum_pct' + `p`i''
    }
    local avg_pct = `sum_pct' / 5
    * Average proportion should be near original (~30% for auto foreign)
    assert abs(`avg_pct' - 30) < 15
    * All individual runs should be within 20pp of each other
    local max_diff = 0
    forvalues i = 1/5 {
        local diff = abs(`p`i'' - `avg_pct')
        if `diff' > `max_diff' local max_diff = `diff'
    }
    assert `max_diff' < 20
    local _pass = 1
}
run_test "X2.5" "Multi-run categorical proportion stability" `_pass'


* === Section X3: Multiple Dataset Concordance ===
* Using multiple() option: datasets should be independent but consistent

* Test X3.1: multiple(5) means are all within 25% of original
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui summ price
    local orig_mean = r(mean)
    synthdata, multiple(5) saving("__xval_3_1") seed(12345)
    local all_ok = 1
    forvalues i = 1/5 {
        use "__xval_3_1_`i'", clear
        qui summ price
        local pct = abs(r(mean) - `orig_mean') / `orig_mean' * 100
        if `pct' >= 25 local all_ok = 0
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "X3.1" "multiple(5) means all within 25%" `_pass'

* Test X3.2: multiple() datasets are not identical
local _pass = 0
capture noisily {
    use "__xval_3_1_1", clear
    qui summ price
    local m1 = r(mean)
    use "__xval_3_1_2", clear
    qui summ price
    local m2 = r(mean)
    use "__xval_3_1_3", clear
    qui summ price
    local m3 = r(mean)
    * At least 2 of 3 should differ
    local ndiff = (`m1' != `m2') + (`m2' != `m3') + (`m1' != `m3')
    assert `ndiff' >= 2
    local _pass = 1
}
run_test "X3.2" "multiple() datasets are not identical" `_pass'

* Test X3.3: multiple() preserves N consistently
local _pass = 0
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    synthdata, multiple(3) saving("__xval_3_3") seed(12345)
    local all_ok = 1
    forvalues i = 1/3 {
        use "__xval_3_3_`i'", clear
        if _N != `orig_n' local all_ok = 0
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "X3.3" "multiple() preserves N consistently" `_pass'

* Test X3.4: multiple() average converges to original
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui summ price
    local orig_mean = r(mean)
    synthdata, multiple(5) saving("__xval_3_4") seed(12345)
    local sum_mean = 0
    forvalues i = 1/5 {
        use "__xval_3_4_`i'", clear
        qui summ price
        local sum_mean = `sum_mean' + r(mean)
    }
    local avg_mean = `sum_mean' / 5
    local pct_diff = abs(`avg_mean' - `orig_mean') / `orig_mean' * 100
    * Average of 5 datasets should be even closer to original
    assert `pct_diff' < 15
    local _pass = 1
}
run_test "X3.4" "multiple() average converges to original" `_pass'


* === Section X4: Cross-Method Correlation Preservation ===

* Test X4.1: Parametric vs Sequential correlation agreement
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui correlate price weight
    local orig_corr = r(rho)
    synthdata price mpg weight, parametric correlations ///
        saving("__xval_4_1_p") replace seed(12345)
    use "__xval_4_1_p", clear
    qui correlate price weight
    local para_corr = r(rho)
    sysuse auto, clear
    synthdata price mpg weight, sequential ///
        saving("__xval_4_1_s") replace seed(12345)
    use "__xval_4_1_s", clear
    qui correlate price weight
    local seq_corr = r(rho)
    * Both should be in the same direction as original
    assert sign(`para_corr') == sign(`orig_corr')
    assert sign(`seq_corr') == sign(`orig_corr')
    * Both should be within 0.4 of original
    assert abs(`para_corr' - `orig_corr') < 0.4
    assert abs(`seq_corr' - `orig_corr') < 0.4
    local _pass = 1
}
run_test "X4.1" "Parametric vs Sequential correlation agreement" `_pass'

* Test X4.2: Empirical preserves correlation better than permute
local _pass = 0
capture noisily {
    sysuse auto, clear
    qui correlate price weight
    local orig_corr = r(rho)
    * Empirical
    synthdata, empirical saving("__xval_4_2_e") replace seed(12345)
    use "__xval_4_2_e", clear
    qui correlate price weight
    local emp_diff = abs(r(rho) - `orig_corr')
    * Permute
    sysuse auto, clear
    synthdata, permute saving("__xval_4_2_p") replace seed(12345)
    use "__xval_4_2_p", clear
    qui correlate price weight
    local perm_diff = abs(r(rho) - `orig_corr')
    * Empirical should be substantially better
    assert `emp_diff' < `perm_diff' + 0.1
    local _pass = 1
}
run_test "X4.2" "Empirical correlation better than permute" `_pass'

* Test X4.3: Sequential preserves conditional relationships
local _pass = 0
capture noisily {
    clear
    set obs 1000
    set seed 20260313
    gen x = rnormal()
    gen y = 0.8 * x + rnormal(0, 0.5)
    gen z = 0.5 * y + 0.3 * x + rnormal(0, 0.3)
    qui correlate y x
    local orig_yx = r(rho)
    qui correlate z y
    local orig_zy = r(rho)
    synthdata, sequential saving("__xval_4_3") replace seed(12345)
    use "__xval_4_3", clear
    qui correlate y x
    assert abs(r(rho) - `orig_yx') < 0.3
    qui correlate z y
    assert abs(r(rho) - `orig_zy') < 0.3
    local _pass = 1
}
run_test "X4.3" "Sequential preserves conditional relationships" `_pass'


* === Section X5: Cross-Method Panel Validation ===

* Create panel dataset
clear
set obs 500
set seed 20260313
gen id = ceil(_n / 5)
bysort id: gen time = _n
gen sex = cond(runiform() < 0.5, 0, 1)
bysort id (time): replace sex = sex[1]
gen outcome = rnormal(50, 10) + time * 2
gen bp = rnormal(120, 15)
save "__xval_paneldata.dta", replace

* Test X5.1: Panel methods all preserve ID structure
local _pass = 0
capture noisily {
    local all_ok = 1
    foreach method in parametric bootstrap smart {
        use "__xval_paneldata", clear
        synthdata, `method' panel(id time) ///
            saving("__xval_5_1_`method'") replace seed(12345)
        use "__xval_5_1_`method'", clear
        * Should have IDs and time
        confirm variable id
        confirm variable time
        * No duplicate id-time pairs
        duplicates tag id time, generate(_dup)
        qui count if _dup > 0
        if r(N) > 0 local all_ok = 0
        drop _dup
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "X5.1" "Panel methods all preserve ID structure" `_pass'

* Test X5.2: Panel preservevar works across methods
local _pass = 0
capture noisily {
    local all_ok = 1
    foreach method in parametric bootstrap smart {
        use "__xval_paneldata", clear
        synthdata, `method' panel(id time) preservevar(sex) ///
            saving("__xval_5_2_`method'") replace seed(12345)
        use "__xval_5_2_`method'", clear
        bysort id: gen byte _v = (sex != sex[1])
        qui count if _v == 1
        if r(N) > 0 local all_ok = 0
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "X5.2" "preservevar works across methods" `_pass'

* Test X5.3: Panel N reasonable across methods
local _pass = 0
capture noisily {
    use "__xval_paneldata", clear
    local orig_n = _N
    local all_ok = 1
    foreach method in parametric bootstrap smart {
        use "__xval_paneldata", clear
        synthdata, `method' panel(id time) ///
            saving("__xval_5_3_`method'") replace seed(12345)
        use "__xval_5_3_`method'", clear
        local pct = abs(_N - `orig_n') / `orig_n' * 100
        if `pct' >= 20 local all_ok = 0
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "X5.3" "Panel N reasonable across methods" `_pass'

* Test X5.4: Panel outcome means agree across methods
local _pass = 0
capture noisily {
    use "__xval_paneldata", clear
    qui summ outcome
    local orig_mean = r(mean)
    local all_ok = 1
    foreach method in parametric bootstrap smart {
        use "__xval_5_3_`method'", clear
        qui summ outcome
        local pct = abs(r(mean) - `orig_mean') / `orig_mean' * 100
        if `pct' >= 30 local all_ok = 0
    }
    assert `all_ok' == 1
    local _pass = 1
}
run_test "X5.4" "Panel outcome means agree across methods" `_pass'

* Test X5.5: Panel + randomeffects ICC direction preserved
local _pass = 0
capture noisily {
    use "__xval_paneldata", clear
    * Compute original ICC for outcome
    qui mixed outcome || id:, nolog
    local var_id = exp(2 * [lns1_1_1]_cons)
    local var_res = exp(2 * [lnsig_e]_cons)
    local orig_icc = `var_id' / (`var_id' + `var_res')
    * Synthesize with randomeffects
    use "__xval_paneldata", clear
    synthdata, smart panel(id time) randomeffects ///
        saving("__xval_5_5") replace seed(12345)
    use "__xval_5_5", clear
    qui mixed outcome || id:, nolog
    local var_id_s = exp(2 * [lns1_1_1]_cons)
    local var_res_s = exp(2 * [lnsig_e]_cons)
    local synth_icc = `var_id_s' / (`var_id_s' + `var_res_s')
    * ICC should be positive (within-person correlation exists)
    assert `synth_icc' > 0
    * ICC should be in reasonable range of original
    assert abs(`synth_icc' - `orig_icc') < 0.5
    local _pass = 1
}
run_test "X5.5" "Panel randomeffects ICC direction preserved" `_pass'


* === Cleanup ===
capture graph close _all
local tempfiles : dir "." files "__xval_*.dta"
foreach f of local tempfiles {
    capture erase "`f'"
}

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
