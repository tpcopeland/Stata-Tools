clear all
set varabbrev off
set more off
version 16.0

* test_datamap_float_format.do - v1.4.1 regression: no IEEE float-precision noise
* in datamap/datacheck text output. Guards the round()->write and raw-value-write
* sites fixed in 1.4.1: continuous DISTRIBUTION stats, panel/survival/survey
* detection ranges, the missing-data summary %, sample-observation rows, and the
* datacheck inrange gate message. Pre-1.4.1 these emitted values like
* "49.40000000000001%", "SD: 777.1900000000001", "max 96.80000000000001".

capture log close _all
log using "test_datamap_float_format.log", replace text nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local tmp_dir "`c(tmpdir)'/datamap_floatfmt"
capture mkdir "`tmp_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace

**# Noise detector
* A genuine value never carries a long run of zeros or nines in its fractional
* part; an IEEE round()/double-expansion tail does (e.g. ".40000000000001",
* ".1900000000001", ".59999999999998"). Scan a file and count offending lines.
capture program drop _ff_count_noise
program define _ff_count_noise, rclass
    version 16.0
    syntax using/
    tempname fh
    local n 0
    local sample ""
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if ustrregexm(`"`macval(line)'"', "\.[0-9]+0{7,}[0-9]") | ///
           ustrregexm(`"`macval(line)'"', "\.[0-9]+9{7,}[0-9]") {
            local ++n
            if `"`sample'"' == "" local sample `"`macval(line)'"'
        }
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
    return local sample `"`sample'"'
end

**# Adversarial dataset exercising every fixed path
quietly {
    clear
    set seed 20260619
    set obs 160

    * panel: repeated id-like key -> panel detector prints avg obs per unit
    gen double patient_id = ceil(_n / 2)

    * rounded-to-0.1 measure -> sample rows + DISTRIBUTION stats (was noisy)
    gen double pct_adherence = round(rnormal(78, 18), 0.1)

    * continuous covariates -> DISTRIBUTION mean/sd/percentiles (round 0.01)
    gen double bmi = rnormal(27.5, 5.2)
    gen double sbp = rnormal(135, 20)

    * outlier / out-of-range driver for datacheck inrange gate
    gen double age = round(rnormal(58, 12), 0.1)
    replace age = -3 in 1
    replace age = 96.8 in 2

    * survival: time-to-event + event indicator -> time range + event rate
    gen double follow_up_time = rexponential(3.5)
    gen double event = rbinomial(1, 0.30)

    * survey weights -> weight range/mean
    gen double sampwt = runiform() * 2 + 0.5

    * missingness so the complete-case percentage is a non-round value
    gen double lab = rnormal()
    replace lab = . if _n > 79

    save "`tmp_dir'/_ff_cohort.dta", replace
}

**# T1: datamap full text output carries no float noise (all file-write paths)
local ++test_count
capture noisily {
    quietly datamap, single("`tmp_dir'/_ff_cohort.dta") ///
        output("`tmp_dir'/_ff_map.txt") ///
        autodetect quality missing(detail) samples(3)
    _ff_count_noise using "`tmp_dir'/_ff_map.txt"
    assert r(n) == 0
}
if _rc == 0 {
    di as result "  T`test_count': PASS - datamap text output free of float noise"
    local ++pass_count
}
else {
    di as error "  T`test_count': FAIL - float noise in datamap output: `r(sample)'"
    local ++fail_count
}

**# T2: complete-data summary percentage is clean
local ++test_count
capture noisily {
    tempname fh
    local ok 1
    file open `fh' using "`tmp_dir'/_ff_map.txt", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Observations with complete data:") > 0 {
            if ustrregexm(`"`macval(line)'"', "0{7,}[0-9]%") local ok 0
        }
        file read `fh' line
    }
    file close `fh'
    assert `ok' == 1
}
if _rc == 0 {
    di as result "  T`test_count': PASS - complete-data percentage clean"
    local ++pass_count
}
else {
    di as error "  T`test_count': FAIL - noisy complete-data percentage"
    local ++fail_count
}

**# T3: sample observation rows carry no float noise
local ++test_count
capture noisily {
    tempname fh
    local ok 1
    file open `fh' using "`tmp_dir'/_ff_map.txt", read text
    file read `fh' line
    while r(eof) == 0 {
        if substr(`"`macval(line)'"', 1, 2) == "| " {
            if ustrregexm(`"`macval(line)'"', "\.[0-9]+0{7,}[0-9]") | ///
               ustrregexm(`"`macval(line)'"', "\.[0-9]+9{7,}[0-9]") local ok 0
        }
        file read `fh' line
    }
    file close `fh'
    assert `ok' == 1
}
if _rc == 0 {
    di as result "  T`test_count': PASS - sample rows clean"
    local ++pass_count
}
else {
    di as error "  T`test_count': FAIL - float noise in sample rows"
    local ++fail_count
}

**# T4: datacheck inrange gate message is clean
local ++test_count
capture noisily {
    use "`tmp_dir'/_ff_cohort.dta", clear
    capture log close dc
    log using "`tmp_dir'/_ff_dc.log", replace text name(dc) nomsg
    capture noisily datacheck age bmi, inrange(age 18 110 \ bmi 10 60) warn
    log close dc
    _ff_count_noise using "`tmp_dir'/_ff_dc.log"
    assert r(n) == 0
}
if _rc == 0 {
    di as result "  T`test_count': PASS - datacheck gate message clean"
    local ++pass_count
}
else {
    di as error "  T`test_count': FAIL - float noise in datacheck output: `r(sample)'"
    local ++fail_count
}

**# T5: detector confirms it can flag noise (guards against a no-op scanner)
local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`tmp_dir'/_ff_synth.txt", write text replace
    file write `fh' "  min -3, max 96.80000000000001" _n
    file close `fh'
    _ff_count_noise using "`tmp_dir'/_ff_synth.txt"
    assert r(n) == 1
}
if _rc == 0 {
    di as result "  T`test_count': PASS - noise detector self-test"
    local ++pass_count
}
else {
    di as error "  T`test_count': FAIL - noise detector did not flag synthetic noise"
    local ++fail_count
}

**# Summary
di as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
log close _all
if `fail_count' > 0 {
    di as error "SOME TESTS FAILED"
    di "RESULT: test_datamap_float_format tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
di as result "ALL TESTS PASSED"
di "RESULT: test_datamap_float_format tests=`test_count' pass=`pass_count' fail=`fail_count'"
