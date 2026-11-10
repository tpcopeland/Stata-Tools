/*  demo_datamap.do - Demo output for datamap 2.0.0

    Produces:
      1. Console output (Markdown map, privacy controls)  -> .log -> .md via logdoc
      2. Console output (compact map, missing(pattern))   -> .log -> .md via logdoc
      3. Console output (safe preset, saving(), agent)    -> .log -> .md via logdoc
      4. Console output (dataprobe QC, gates, brief)      -> .log -> .md via logdoc
      5. Console output (dataprobe snapshot, diff, keys)  -> .log -> .md via logdoc
      6. Console output (datamvp missing patterns)        -> .log -> .md via logdoc
      7. Markdown maps written by datamap (incl. auto)    -> .md
      8. Missingness bar graph (datamvp)                  -> .png
*/

version 16.0
set varabbrev off
set linesize 255

**# Paths
local pkg_dir "datamap/demo"
capture mkdir "`pkg_dir'"

foreach f in datamap_clinical.md datamap_compact.md datamap_missing.md ///
    datamap_auto.md datamap_safe.md datamap_agent.md datamap_vars.csv missingness_bar.png ///
    _demo_auto.dta _demo_cohort.dta _demo_missing.dta _demo_labs.dta ///
    console_datamap_map.log console_datamap_map.md ///
    console_datamap_compact.log console_datamap_compact.md ///
    console_datamap_safe.log console_datamap_safe.md ///
    console_dataprobe.log console_dataprobe.md ///
    console_dataprobe_diff.log console_dataprobe_diff.md ///
    console_datamvp.log console_datamvp.md {
    capture erase "`pkg_dir'/`f'"
}

**# Graph scheme: resolve it before the isolated install below
capture ado uninstall tc_schemes
capture confirm file "`c(pwd)'/tc_schemes/stata.toc"
if _rc {
    quietly net install tc_schemes, ///
        from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tc_schemes") replace
}
else {
    quietly net install tc_schemes, from("`c(pwd)'/tc_schemes") replace
}
set scheme white_tableau

**# Install package from local source
* On a machine that already has datamap 1.x, run "ado uninstall datamap" first:
* net install over 1.x leaves a stale datadict.ado behind.
capture ado uninstall datamap
quietly net install datamap, from("`c(pwd)'/datamap") replace
discard

**# Demo helper programs
* The Markdown output holds backticks, which a Stata "if" expression would try
* to expand, so the line matching runs in Mata.
mata:
void _demo_scan(string scalar path, string scalar needle, real scalar maxn)
{
    real scalar fh, found, shown
    string scalar ln

    fh = fopen(path, "r")
    found = 0
    shown = 0
    while ((ln = fget(fh)) != J(0, 0, "")) {
        if (strpos(ln, needle) > 0) {
            found++
            if (maxn > 0 & shown < maxn) {
                shown++
                printf("%s\n", ln)
            }
        }
    }
    fclose(fh)
    st_local("found", strofreal(found))
}

void _demo_head(string scalar path, real scalar maxn)
{
    real scalar fh, n
    string scalar ln

    fh = fopen(path, "r")
    n = 0
    while ((ln = fget(fh)) != J(0, 0, "") & n < maxn) {
        n++
        printf("%s\n", ln)
    }
    if (n == maxn & fget(fh) != J(0, 0, "")) printf("... [output truncated]\n")
    fclose(fh)
}
end

capture program drop _demo_type_head
program define _demo_type_head
    version 16.0
    syntax using/ [, Lines(integer 60)]

    mata: _demo_head(st_local("using"), `lines')
end

capture program drop _demo_type_matches
program define _demo_type_matches
    version 16.0
    syntax using/ , Text(string) [Lines(integer 12)]

    mata: _demo_scan(st_local("using"), st_local("text"), `lines')
    if `found' == 0 display as text "(no matching lines)"
end

capture program drop _demo_assert_contains
program define _demo_assert_contains
    version 16.0
    syntax using/ , Text(string)

    mata: _demo_scan(st_local("using"), st_local("text"), 0)
    if `found' == 0 {
        display as error `"expected text not found in `using': `text'"'
        exit 459
    }
end

**# Build synthetic clinical cohort
quietly {
    clear
    set seed 20260226
    set obs 1200

    gen double patient_id = 100000 + _n
    gen double subject_id = 5000 + _n
    gen str32 patient_name = "Patient " + string(_n, "%03.0f")

    gen double age = max(18, round(rnormal(58, 12), 0.1))
    gen double sex = rbinomial(1, 0.52)
    label define sex_lbl 0 "Female" 1 "Male"
    label values sex sex_lbl

    gen double smoking = floor(runiform() * 3)
    label define smoke_lbl 0 "Never" 1 "Former" 2 "Current"
    label values smoking smoke_lbl

    gen double bmi = round(rnormal(27.5, 5.2), 0.1)
    gen double sbp = round(rnormal(135, 20))
    gen double creatinine = round(rnormal(1.05, 0.35), 0.01)
    gen double pct_adherence = round(rnormal(78, 18), 0.1)

    gen double enroll_date = mdy(1, 1, 2021) + floor(runiform() * 900)
    format enroll_date %td
    gen double birth_date = enroll_date - round(age * 365.25)
    format birth_date %td

    gen double follow_up_time = round(rexponential(3.5), 0.01)
    gen double event = rbinomial(1, 0.30)
    label define event_lbl 0 "Censored" 1 "Event"
    label values event event_lbl

    gen double treatment = rbinomial(1, 0.50)
    label define treat_lbl 0 "Control" 1 "Active"
    label values treatment treat_lbl

    gen double site = ceil(runiform() * 6)
    replace site = 9 in 1/3
    label define site_lbl 1 "Stockholm" 2 "Gothenburg" 3 "Malmo" ///
        4 "Uppsala" 5 "Linkoping" 6 "Lund" 9 "Satellite clinic"
    label values site site_lbl

    gen double rare_marker = (_n <= 3)
    label define rare_lbl 0 "Absent" 1 "Present"
    label values rare_marker rare_lbl

    replace age = -3 in 1
    replace pct_adherence = 115.2 in 5

    replace bmi = . if runiform() < 0.08
    replace sbp = . if runiform() < 0.05
    replace creatinine = . if runiform() < 0.12
    replace smoking = . if runiform() < 0.15
    replace pct_adherence = . if runiform() < 0.20

    label variable patient_id "Patient identifier"
    label variable subject_id "Study subject identifier"
    label variable patient_name "Patient full name"
    label variable age "Age at enrollment (years)"
    label variable sex "Biological sex"
    label variable smoking "Smoking status"
    label variable bmi "Body mass index (kg/m2)"
    label variable sbp "Systolic blood pressure (mmHg)"
    label variable creatinine "Serum creatinine (mg/dL)"
    label variable pct_adherence "Medication adherence (%)"
    label variable enroll_date "Date of enrollment"
    label variable birth_date "Date of birth"
    label variable follow_up_time "Follow-up time (years)"
    label variable event "Primary endpoint"
    label variable treatment "Randomization arm"
    label variable site "Study site"
    label variable rare_marker "Rare clinical marker"

    label data "Synthetic Clinical Trial Cohort (N=1200)"
    save "`pkg_dir'/_demo_cohort.dta", replace
}

**# Build missingness dataset
quietly {
    clear
    set seed 20260227
    set obs 80

    gen double id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rnormal()
    gen double x4 = rnormal()
    gen double outcome = rbinomial(1, 0.40)

    replace x1 = . if _n > 60
    replace x2 = . if mod(_n, 4) == 0
    replace x3 = . if x1 == . | runiform() < 0.10
    replace x4 = . if _n > 70

    label variable id "Subject ID"
    label variable x1 "Biomarker A"
    label variable x2 "Biomarker B"
    label variable x3 "Biomarker C"
    label variable x4 "Biomarker D"
    label variable outcome "Binary outcome"
    label define yn 0 "No" 1 "Yes"
    label values outcome yn

    label data "Biomarker Study with Missing Data Patterns"
    save "`pkg_dir'/_demo_missing.dta", replace
}


**# Quick Start artifact: the auto data through single()
sysuse auto, clear
quietly save "`pkg_dir'/_demo_auto.dta", replace
quietly datamap, single("`pkg_dir'/_demo_auto.dta") output("`pkg_dir'/datamap_auto.md")
_demo_assert_contains using "`pkg_dir'/datamap_auto.md", text("| `make` |")
capture erase "`pkg_dir'/_demo_auto.dta"

**# Build a small lab file for the keyset() preflight
quietly {
    clear
    set seed 20260228
    set obs 900
    gen double patient_id = 100000 + ceil(runiform() * 1200)
    duplicates drop patient_id, force
    gen double lab_value = round(rnormal(5, 1), 0.1)
    label variable patient_id "Patient identifier"
    label variable lab_value "Laboratory value"
    save "`pkg_dir'/_demo_labs.dta", replace
}

**# Markdown map with privacy controls and document options
capture log close _all
log using "`pkg_dir'/console_datamap_map.log", replace text name(map) nomsg

* # Markdown map with document options

use "`pkg_dir'/_demo_cohort.dta", clear
quietly datasignature
local map_signature "`r(datasignature)'"
tempfile map_integrity
quietly datamap, output("`map_integrity'.md") exclude(patient_id subject_id patient_name) ///
    datesafe mincell(5) autodetect quality samples(3) missing(detail)
quietly datasignature
assert "`map_signature'" == "`r(datasignature)'"
noisily display as result "In-memory integrity check: datamap left the datasignature unchanged"

noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_clinical.md") ///
    title("SYNTH-01 Clinical Trial Map") ///
    subtitle("Synthetic cohort for demonstration purposes") ///
    version("1.1") docdate("10 Nov 2026") author("Timothy P Copeland, Karolinska Institutet") ///
    exclude(patient_id subject_id patient_name) ///
    datesafe mincell(5) autodetect quality samples(3) missing(detail)

noisily display as text "Map excerpt:"
noisily _demo_type_head using "`pkg_dir'/datamap_clinical.md", lines(90)
noisily display as text "Suppressed frequency cells:"
noisily _demo_type_matches using "`pkg_dir'/datamap_clinical.md", ///
    text("suppressed (") lines(8)

log close map

**# Compact map and missing-data patterns
capture log close _all
log using "`pkg_dir'/console_datamap_compact.log", replace text name(compact) nomsg

* # Compact map

noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_compact.md") ///
    compact exclude(patient_id subject_id patient_name) datesafe mincell(5)
noisily _demo_type_head using "`pkg_dir'/datamap_compact.md", lines(60)

* # Missing-data patterns

noisily datamap, single("`pkg_dir'/_demo_missing.dta") ///
    output("`pkg_dir'/datamap_missing.md") ///
    exclude(id) missing(pattern) quality mincell(5)
noisily _demo_type_head using "`pkg_dir'/datamap_missing.md", lines(80)

log close compact

**# Safe preset, saving() and the agent default
capture log close _all
log using "`pkg_dir'/console_datamap_safe.log", replace text name(safe) nomsg

* # datamap, safe

* safe = mincell(5) or more, datesafe, exclude(auto), no sample rows and no listed
* values of text. It limits printed output and written files; stored results are
* not masked.

noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_safe.md") safe
noisily display as text "Excluded as likely identifiers: `r(excluded_vars)'"
noisily display as text "safe stored as r(safe) = `r(safe)'"
noisily _demo_type_head using "`pkg_dir'/datamap_safe.md", lines(36)

* # safe refuses sample rows

capture noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_safe.md") safe samples(3)
noisily display as text "return code: " _rc

* # saving(): one row per variable as a table

noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_safe.md") safe ///
    saving("`pkg_dir'/datamap_vars", replace csv)
noisily display as text "CSV written: `r(metadata_csv)'"
preserve
quietly import delimited using "`pkg_dir'/datamap_vars.csv", clear varnames(1) stringcols(_all)
noisily display as text "Columns in the metadata table: " c(k)
noisily list variable class storage_type missing missing_pct in 1/6, noobs abbreviate(14)
restore
capture erase "`pkg_dir'/datamap_vars.dta"

* # dataqa set agent

* dataqa set agent makes safe the session default for datamap and dataprobe.

use "`pkg_dir'/_demo_cohort.dta", clear
noisily dataqa set agent
noisily datamap, output("`pkg_dir'/datamap_agent.md")
noisily display as text "Session default applied: r(safe) = `r(safe)'"
noisily dataqa set clear

log close safe

**# dataprobe: console QC profile, expectation gates and brief
capture log close _all
log using "`pkg_dir'/console_dataprobe.log", replace text name(dataprobe) nomsg

* # Console QC profile

* The cohort carries a deliberate age = -3 outlier, a 115% adherence value, a
* rare "Satellite clinic" site, and missing biomarkers.

use "`pkg_dir'/_demo_cohort.dta", clear
noisily dataprobe patient_id age sex smoking bmi pct_adherence site, ///
    id(patient_id) outliers(3) rare(5)

* # Expectation gate (warn mode)

* With warn, violations are reported and execution continues; drop warn to halt
* the do-file with r(9) instead.

noisily dataprobe age pct_adherence, expectn(1200) isid(patient_id) ///
    notmissing(age sex) inrange(age 18 110 \ pct_adherence 0 100) warn

* # brief: one line per variable

noisily dataprobe, brief

log close dataprobe

**# dataprobe: snapshot, diff and keyset preflight
capture log close _all
log using "`pkg_dir'/console_dataprobe_diff.log", replace text name(diff) nomsg

* # Snapshot before a data step

use "`pkg_dir'/_demo_cohort.dta", clear
capture frame drop baseline
noisily dataprobe, snapshot(baseline) gatesonly
noisily display as text "Snapshot frame: `r(snapshot)'; key: `r(snapshot_key)'"

* # A data step that goes wrong

quietly {
    drop bmi
    replace creatinine = . if mod(_n, 5) == 0
    generate double bmi_group = floor(sbp / 20)
    expand 2 in 1/10
}

* # Diff against the snapshot

noisily dataprobe, diff(baseline) gatesonly

* # keyset() preflight before a merge

use "`pkg_dir'/_demo_cohort.dta", clear
noisily dataprobe, gatesonly keyset(patient_id using "`pkg_dir'/_demo_labs.dta") warn

capture frame drop baseline
log close diff

**# datamvp: missing-value pattern analysis
capture log close _all
log using "`pkg_dir'/console_datamvp.log", replace text name(datamvp) nomsg

* # Missing-value pattern table

use "`pkg_dir'/_demo_missing.dta", clear
noisily datamvp x1 x2 x3 x4, percent sort

* # Monotone-missingness test

noisily datamvp x1 x2 x3 x4, monotone

log close datamvp

**# datamvp missingness bar graph
use "`pkg_dir'/_demo_missing.dta", clear
datamvp x1 x2 x3 x4, graph(bar) varlabels ///
    title("Missingness by variable") nodraw gname(dmvp_bar)
graph display dmvp_bar
graph export "`pkg_dir'/missingness_bar.png", as(png) width(1400) replace
capture graph close _all

**# Verify generated artifact content
_demo_assert_contains using "`pkg_dir'/datamap_clinical.md", text("suppressed")
_demo_assert_contains using "`pkg_dir'/datamap_clinical.md", text("SYNTH-01 Clinical Trial Map")
_demo_assert_contains using "`pkg_dir'/datamap_safe.md", text("withheld")
_demo_assert_contains using "`pkg_dir'/datamap_compact.md", text("patient")
_demo_assert_contains using "`pkg_dir'/console_datamap_map.log", ///
    text("In-memory integrity check: datamap left the datasignature unchanged")
_demo_assert_contains using "`pkg_dir'/console_dataprobe_diff.log", text("DIFF")
_demo_assert_contains using "`pkg_dir'/console_datamvp.log", text("Missing value patterns")

**# Convert console logs to markdown via logdoc
capture ado uninstall logdoc
capture confirm file "`c(pwd)'/logdoc/stata.toc"
if _rc {
    quietly net install logdoc, ///
        from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/logdoc") replace
}
else {
    quietly net install logdoc, from("`c(pwd)'/logdoc") replace
}

foreach section in datamap_map datamap_compact datamap_safe dataprobe ///
    dataprobe_diff datamvp {
    logdoc using "`pkg_dir'/console_`section'.log", ///
        output("`pkg_dir'/console_`section'.md") ///
        format(md) replace quiet
    capture erase "`pkg_dir'/console_`section'.log"
}

**# Cleanup: keep the synthetic fixtures as shipped demo assets; the README
**# transcripts reference demo/_demo_cohort.dta and demo/_demo_missing.dta.
clear
