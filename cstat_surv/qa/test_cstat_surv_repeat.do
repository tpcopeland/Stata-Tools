* Repeat cstat_surv calls: the saved Cox fit is restored (was r(301)).
version 16.0
clear all
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall cstat_surv
quietly net install cstat_surv, from("`pkg_dir'") replace
local tests = 0
local pass = 0
local fail = 0

**# 1. consecutive calls after one stcox work (replay at the new level)
local ++tests
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    quietly ds
    local vars_before `r(varlist)'
    cstat_surv
    quietly ds
    assert "`r(varlist)'" == "`vars_before'"
    local c1 = e(c)
    local lo1 = e(ci_lo)
    local N1 = e(N)
    cstat_surv, level(90)
    assert "`e(cmd)'" == "cstat_surv"
    assert abs(e(c) - `c1') < 1e-12
    assert e(N) == `N1'
    assert e(level) == 90
    assert e(ci_lo) > `lo1'
    quietly count if e(sample)
    assert r(N) == e(N)
    cstat_surv
    assert abs(e(ci_lo) - `lo1') < 1e-12
    * a fresh stcox is evaluated afresh
    stcox age
    cstat_surv
    assert abs(e(c) - `c1') > 1e-6
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: repeat cstat_surv call"
    local ++fail
}

**# 2. an older restored cstat_surv result is never paired with another Cox fit
local ++tests
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug if age < 58
    cstat_surv
    local cA = e(c)
    local nA = e(N)
    estimates store csA
    stcox age
    cstat_surv
    assert abs(e(c) - `cA') > 1e-6
    estimates restore csA
    cstat_surv
    assert abs(e(c) - `cA') < 1e-12
    assert e(N) == `nA'
    estimates drop csA
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: restored older cstat_surv result"
    local ++fail
}

**# 3. a different dataset between calls is refused and e() is left as it was
* guard: expected green at pre-fix ref (HEAD already refuses)
local ++tests
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local c1 = e(c)
    sysuse auto, clear
    capture noisily cstat_surv, level(90)
    assert _rc == 301
    assert "`e(cmd)'" == "cstat_surv"
    assert abs(e(c) - `c1') < 1e-12
    assert e(level) == c(level)
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: different dataset between calls"
    local ++fail
}

**# 4. no estimates namespace footprint
local ++tests
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age
    estimates store _cstat_surv_cox
    stcox age drug
    estimates store mine
    quietly estimates dir
    local dir_before `r(names)'
    cstat_surv
    cstat_surv, level(90)
    quietly estimates dir
    assert "`r(names)'" == "`dir_before'"
    estimates restore _cstat_surv_cox
    assert "`e(cmd)'" == "cox"
    assert colsof(e(b)) == 1
    estimates drop _cstat_surv_cox mine
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: estimates namespace footprint"
    local ++fail
}

**# 5. an in-place edit of the time variable plus re-stset is refused, leaving e() untouched
local ++tests
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local c1 = e(c)
    replace studytime = 40 - studytime
    stset studytime, failure(died)
    capture noisily cstat_surv, level(90)
    assert _rc == 301
    assert "`e(cmd)'" == "cstat_surv"
    assert abs(e(c) - `c1') < 1e-12
    assert e(level) == c(level)
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: an in-place edit of the time variable plus re-stset is refused"
    local ++fail
}

**# 6. an in-place edit of the failure variable plus re-stset is refused, leaving e() untouched
local ++tests
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local c1 = e(c)
    replace died = 1 - died
    stset studytime, failure(died)
    capture noisily cstat_surv, level(90)
    assert _rc == 301
    assert "`e(cmd)'" == "cstat_surv"
    assert abs(e(c) - `c1') < 1e-12
    assert e(level) == c(level)
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: an in-place edit of the failure variable plus re-stset is refused"
    local ++fail
}

**# 7. an in-place edit of a covariate is refused, leaving e() untouched
local ++tests
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local c1 = e(c)
    replace age = -age
    capture noisily cstat_surv, level(90)
    assert _rc == 301
    assert "`e(cmd)'" == "cstat_surv"
    assert abs(e(c) - `c1') < 1e-12
    assert e(level) == c(level)
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: an in-place edit of a covariate is refused"
    local ++fail
}

**# 8. re-sorting and preserve/edit/restore still replay
local ++tests
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox i.drug c.age##c.age
    cstat_surv
    local c1 = e(c)
    set seed 99
    generate double u = runiform()
    sort u
    drop u
    cstat_surv, level(90)
    assert abs(e(c) - `c1') < 1e-12
    assert e(level) == 90
    preserve
    replace age = 0
    restore
    cstat_surv, level(80)
    assert abs(e(c) - `c1') < 1e-12
    assert e(level) == 80
    * a harmless storage-type change is not a data change
    compress
    cstat_surv
    assert abs(e(c) - `c1') < 1e-12
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: re-sort / preserve-restore replay"
    local ++fail
}

**# 9. heavily tied times plus repeated re-sorts never give a false mismatch
local ++tests
capture noisily {
    clear
    set seed 2468
    set obs 240
    generate double t = 1 + floor(runiform() * 8)
    generate byte d = runiform() < .7
    generate byte x = runiform() < .5
    generate byte z = floor(runiform() * 3)
    stset t, failure(d)
    stcox x i.z
    cstat_surv
    local c1 = e(c)
    forvalues r = 1/5 {
        generate double u = runiform()
        sort u
        drop u
        cstat_surv, level(`=80 + `r'')
        assert abs(e(c) - `c1') < 1e-12
        assert e(level) == 80 + `r'
    }
    * ... and one changed value among the ties is still caught
    quietly replace x = 1 - x in 1
    capture noisily cstat_surv
    assert _rc == 301
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: tied times and re-sorts"
    local ++fail
}

display "RESULT: test_cstat_surv_repeat tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
