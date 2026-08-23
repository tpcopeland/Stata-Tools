*! crossval_cstat_surv_sksurv.do
*! Cross-validation against scikit-survival's ordinary Harrell C
*! Seed 26082441

clear all
set varabbrev off
version 16.0

capture log close _all
log using "crossval_cstat_surv_sksurv.log", replace nomsg

* Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local py_script "`qa_dir'/tools/crossval_cstat_surv_sksurv.py"

capture program drop cstat_surv
quietly run "`pkg_dir'/cstat_surv.ado"

local test_count = 0
local pass_count = 0
local fail_count = 0

* Ordinary Harrell C external parity
local ++test_count
capture noisily {
    clear
    * Seed before the permutation that assigns the fixed tied-risk groups.
    set seed 26082441
    set obs 36
    gen long id = _n
    gen byte x = mod(_n, 5) - 2
    gen double order_u = runiform()
    sort order_u
    gen double time = _n
    gen byte event = mod(_n, 3) != 0
    drop order_u

    * Every survival time is unique, matching the external Harrell convention.
    isid time
    stset time, failure(event)
    stcox x
    predict double risk, hr
    cstat_surv

    local stata_c = e(c)
    local stata_comp = e(N_comparable)
    local stata_conc = e(N_concordant)
    local stata_disc = e(N_discordant)
    local stata_tied = e(N_tied)
    local stata_se = e(se)
    local stata_ci_lo = e(ci_lo)
    local stata_ci_hi = e(ci_hi)

    assert `stata_c' < .
    assert `stata_comp' < .
    assert `stata_conc' < .
    assert `stata_disc' < .
    assert `stata_tied' < .
    assert `stata_se' < .
    assert `stata_ci_lo' < .
    assert `stata_ci_hi' < .
    assert `stata_ci_lo' <= `stata_c'
    assert `stata_c' <= `stata_ci_hi'
    assert `stata_tied' > 0
    assert `stata_comp' == `stata_conc' + `stata_disc' + `stata_tied'

    tempfile exchange py_result
    local exchange "`exchange'.dta"
    local py_result "`py_result'.dta"
    keep id time event risk
    save "`exchange'", replace
    shell python3 "`py_script'" "`exchange'" "`py_result'"

    preserve
    use "`py_result'", clear
    assert _N == 1
    assert py_c < .
    assert py_comparable < .
    assert py_concordant < .
    assert py_discordant < .
    assert py_tied < .
    local py_c = py_c[1]
    local py_comp = py_comparable[1]
    local py_conc = py_concordant[1]
    local py_disc = py_discordant[1]
    local py_tied = py_tied[1]
    restore

    assert `py_comp' == `py_conc' + `py_disc' + `py_tied'
    assert abs(`stata_c' - `py_c') < 1e-12
    assert `stata_comp' == `py_comp'
    assert `stata_conc' == `py_conc'
    assert `stata_disc' == `py_disc'
    assert `stata_tied' == `py_tied'
}
if _rc == 0 {
    local ++pass_count
}
else {
    local ++fail_count
}

* Same-time failures are unusable; an event/censor pair at the same time is usable.
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        1 1 4
        1 1 3
        1 0 2.5
        2 0 2
        3 1 1
        4 0 0
        5 1 -1
    end
    stset time, failure(event)
    stcox x
    predict double risk, hr
    cstat_surv

    local stata_c = e(c)
    local stata_comp = e(N_comparable)
    local stata_conc = e(N_concordant)
    local stata_disc = e(N_discordant)
    local stata_tied = e(N_tied)
    foreach value in stata_c stata_comp stata_conc stata_disc stata_tied {
        assert ``value'' < .
    }
    assert `stata_comp' == `stata_conc' + `stata_disc' + `stata_tied'

    tempfile exchange py_result
    local exchange "`exchange'.dta"
    local py_result "`py_result'.dta"
    keep time event risk
    save "`exchange'", replace
    shell python3 "`py_script'" "`exchange'" "`py_result'"
    use "`py_result'", clear
    assert _N == 1
    foreach value in py_c py_comparable py_concordant py_discordant py_tied {
        assert !missing(`value'[1])
    }
    assert py_comparable[1] == py_concordant[1] + py_discordant[1] + py_tied[1]

    * Two same-time deaths are excluded; each is comparable to the same-time censor.
    assert py_comparable[1] == 12
    assert abs(`stata_c' - py_c[1]) < 1e-12
    assert `stata_comp' == py_comparable[1]
    assert `stata_conc' == py_concordant[1]
    assert `stata_disc' == py_discordant[1]
    assert `stata_tied' == py_tied[1]
}
if _rc == 0 {
    local ++pass_count
}
else {
    local ++fail_count
}

if `fail_count' > 0 {
    display as error "RESULT: crossval_cstat_surv_sksurv tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}

display as result "RESULT: crossval_cstat_surv_sksurv tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
