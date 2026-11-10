clear all
set varabbrev off
set more off
version 16.0

* test_datamap_float_format.do - regressions for no IEEE float-precision noise
* in datamap/dataprobe output. Guards the round()->write and raw-value-write
* sites fixed in 1.4.1: continuous DISTRIBUTION stats, panel/survival/survey
* detection ranges, the missing-data summary %, sample-observation rows, and the
* dataprobe inrange gate message. Pre-1.4.1 these emitted values like
* "49.40000000000001%", "SD: 777.1900000000001", "max 96.80000000000001".
*
* 2026-11-10 (datamap 2.0.0): datadict and the text layout are gone.  The
* documents are Markdown, read through Mata (a Source or Data-signature line
* ends in a backtick, which breaks a macro line reader).  T2 asserts the line
* "- Complete rows: n (p%)" EXISTS before it checks the percentage (the 1.x
* "Observations with complete data:" line is gone, and a reader that finds no
* such line would have passed).  T6 is datadict's categorical-level check on
* datamap's own level cells ("<value>: n (p%)", counts before the percent).

capture log close _all
log using "test_datamap_float_format.log", replace text nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local tmp_dir "`c(tmpdir)'/datamap_floatfmt"
capture mkdir "`tmp_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace

**# Noise detector
* A genuine value never carries a long run of zeros or nines in its fractional
* part; an IEEE round()/double-expansion tail does (e.g. ".40000000000001",
* ".1900000000001", ".59999999999998"). Scan a file and count offending lines.
mata:
void _ff_scan(string scalar f, string scalar contains, string scalar starts)
{
    string colvector L
    real scalar i, n, nsel
    string scalar smp
    L = cat(f)
    n = 0
    nsel = 0
    smp = ""
    for (i = 1; i <= rows(L); i++) {
        if (contains != "" & strpos(L[i], contains) == 0) continue
        if (starts != "" & substr(L[i], 1, strlen(starts)) != starts) continue
        nsel++
        if (ustrregexm(L[i], "\.[0-9]+0{7,}[0-9]") | ///
            ustrregexm(L[i], "\.[0-9]+9{7,}[0-9]")) {
            n++
            if (smp == "") smp = subinstr(L[i], char(96), "", .)
        }
    }
    st_numscalar("__ff_n", n)
    st_numscalar("__ff_nsel", nsel)
    st_global("__ff_sample", smp)
}
end

* r(n) lines (optionally only those containing / starting with a string) that
* carry a float-noise tail, r(nsel) lines examined, r(sample) the first hit
capture program drop _ff_count_noise
program define _ff_count_noise, rclass
    version 16.0
    syntax using/ [, CONTAINS(string) STARTS(string)]
    confirm file `"`using'"'
    mata: _ff_scan(st_local("using"), st_local("contains"), st_local("starts"))
    return scalar n = scalar(__ff_n)
    return scalar nsel = scalar(__ff_nsel)
    return local sample `"$__ff_sample"'
    scalar drop __ff_n __ff_nsel
    macro drop __ff_sample
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

    * outlier / out-of-range driver for dataprobe inrange gate
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

**# T1: datamap full Markdown output carries no float noise (all file-write paths)
local ++test_count
capture noisily {
    quietly datamap, single("`tmp_dir'/_ff_cohort.dta") ///
        output("`tmp_dir'/_ff_map.md") ///
        autodetect quality missing(detail) samples(3)
    _ff_count_noise using "`tmp_dir'/_ff_map.md"
    assert !missing(r(nsel))
    assert r(nsel) > 20
    assert r(n) == 0
}
if _rc == 0 {
    di as result "  T`test_count': PASS - datamap Markdown output free of float noise"
    local ++pass_count
}
else {
    di as error "  T`test_count': FAIL - float noise in datamap output: `r(sample)'"
    local ++fail_count
}

**# T2: complete-data summary percentage is clean
local ++test_count
capture noisily {
    * the line must exist: 79 of 160 rows complete = 49.4%
    _ff_count_noise using "`tmp_dir'/_ff_map.md", contains("- Complete rows: 79 (49.4%)")
    assert r(nsel) == 1
    assert r(n) == 0
    _ff_count_noise using "`tmp_dir'/_ff_map.md", contains("- Complete rows:")
    assert r(nsel) == 1
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
    * every table row starts "| "; the sample-rows table is among them, and
    * the file must hold sample rows at all (samples(3) -> a Sample rows section)
    _ff_count_noise using "`tmp_dir'/_ff_map.md", contains("### Sample rows")
    assert r(nsel) == 1
    _ff_count_noise using "`tmp_dir'/_ff_map.md", starts("| ")
    assert !missing(r(nsel))
    assert r(nsel) >= 8
    assert r(n) == 0
}
if _rc == 0 {
    di as result "  T`test_count': PASS - sample rows clean"
    local ++pass_count
}
else {
    di as error "  T`test_count': FAIL - float noise in sample rows"
    local ++fail_count
}

**# T4: dataprobe inrange gate message is clean
local ++test_count
capture noisily {
    use "`tmp_dir'/_ff_cohort.dta", clear
    capture log close dc
    log using "`tmp_dir'/_ff_dc.log", replace text name(dc) nomsg
    capture noisily dataprobe age bmi, inrange(age 18 110 \ bmi 10 60) warn
    log close dc
    _ff_count_noise using "`tmp_dir'/_ff_dc.log"
    assert r(n) == 0
}
if _rc == 0 {
    di as result "  T`test_count': PASS - dataprobe gate message clean"
    local ++pass_count
}
else {
    di as error "  T`test_count': FAIL - float noise in dataprobe output: `r(sample)'"
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

**# T6: categorical levels respect numeric display precision
local ++test_count
capture noisily {
    clear
    set obs 34
    gen float visual_score = mod(_n - 1, 17) / 10
    quietly datamap, output("`tmp_dir'/_ff_dictionary.md") mincell(0)
    _ff_count_noise using "`tmp_dir'/_ff_dictionary.md", contains("visual_score")
    assert r(nsel) == 1
    assert r(n) == 0
    * 17 distinct levels, two rows each: ".1: 2 (5.9%)" and "1.6: 2 (5.9%)"
    _ff_count_noise using "`tmp_dir'/_ff_dictionary.md", contains("<br>.1: 2 (5.9%)<br>")
    assert r(nsel) == 1
    _ff_count_noise using "`tmp_dir'/_ff_dictionary.md", contains("<br>1.6: 2 (5.9%)")
    assert r(nsel) == 1
}
if _rc == 0 {
    di as result "  T`test_count': PASS - categorical levels free of float noise"
    local ++pass_count
}
else {
    di as error "  T`test_count': FAIL - noisy categorical levels"
    local ++fail_count
}

**# Summary
di as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    di as error "SOME TESTS FAILED"
    di "RESULT: test_datamap_float_format tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}
di as result "ALL TESTS PASSED"
di "RESULT: test_datamap_float_format tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
