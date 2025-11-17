# Validation Testing and Error Handling Recommendations

This document provides suggested error messages and validation testing procedures for each package in the Stata-Tools repository.

## check

### Suggested Error Messages

1. **No variables specified**
   - Error code: 198
   - Message: "varlist required"
   - Trigger: User runs `check` without specifying variables

2. **Invalid variable names**
   - Error code: 111
   - Message: "variable {varname} not found"
   - Trigger: User specifies non-existent variable

### Validation Testing

```stata
* Test 1: Basic functionality with numeric variables
sysuse auto, clear
check mpg price weight

* Test 2: String variables
check make

* Test 3: Short option
check mpg price, short

* Test 4: All variables
check _all

* Test 5: Missing data handling
replace mpg = . in 1/10
check mpg

* Test 6: Variables with labels
label variable mpg "Miles per Gallon (EPA)"
check mpg

* Test 7: Error: no variables specified
capture check
assert _rc == 198

* Test 8: Error: invalid variable
capture check nonexistent_var
assert _rc == 111
```

---

## cstat_surv

### Suggested Error Messages

1. **No Cox model fitted**
   - Error code: 301
   - Message: "last estimates not found"
   - Trigger: Running cstat_surv without prior stcox

2. **Data not stset**
   - Error code: 119
   - Message: "data not st; use stset"
   - Trigger: Data not declared as survival-time data

3. **Missing somersd command**
   - Error code: 199
   - Message: "somersd command not found; install with: ssc install somersd"
   - Trigger: Required package not installed

### Validation Testing

```stata
* Test 1: Basic C-statistic calculation
webuse drugtr, clear
stset studytime, failure(died)
stcox age drug
cstat_surv
assert r(c) > 0 & r(c) < 1

* Test 2: Multiple covariates
stcox age drug i.state
cstat_surv

* Test 3: Perfect discrimination (if possible)
* Create artificial perfect predictor
gen perfect = died
stcox perfect
cstat_surv
assert abs(r(c) - 1) < 0.01

* Test 4: Error: no model fitted
capture cstat_surv
assert _rc == 301

* Test 5: Error: data not stset
use drugtr, clear
stcox age
capture cstat_surv
assert _rc == 119

* Test 6: Stored results
stset studytime, failure(died)
stcox age
cstat_surv
assert r(c) != .
assert r(se) != .
assert r(p) != .
```

---

## datamap / datadict

### Suggested Error Messages

1. **No input option specified**
   - Error code: 198
   - Message: "must specify single(), directory(), or filelist()"
   - Trigger: No input option provided

2. **File not found**
   - Error code: 601
   - Message: "file {filename} not found"
   - Trigger: Specified file does not exist

3. **Invalid format option**
   - Error code: 198
   - Message: "invalid format(); only text is supported"
   - Trigger: Non-text format specified

4. **Invalid parameter values**
   - Error code: 198
   - Message: "maxfreq() and maxcat() must be positive integers"
   - Trigger: Non-positive values specified

### Validation Testing

```stata
* Test 1: Basic single file documentation
sysuse auto, clear
save temp_auto, replace
datamap, single(temp_auto.dta)
assert r(nfiles) == 1

* Test 2: Privacy controls - exclude sensitive variables
datamap, single(temp_auto.dta) exclude(make) output(test_exclude.txt) replace

* Test 3: Date-safe mode
gen dob = date("2000-01-01", "YMD")
format dob %td
save temp_dates, replace
datamap, single(temp_dates.dta) datesafe output(test_datesafe.txt) replace

* Test 4: Directory mode
mkdir test_dir
save test_dir/file1, replace
save test_dir/file2, replace
datamap, directory(test_dir) separate

* Test 5: Data dictionary
datadict, single(temp_auto.dta) output(test_dict.md) toc

* Test 6: Error: no input option
capture datamap, output(test.txt)
assert _rc == 198

* Test 7: Error: file not found
capture datamap, single(nonexistent.dta)
assert _rc == 601

* Test 8: Parameter validation
capture datamap, single(temp_auto.dta) maxfreq(-5)
assert _rc == 198

* Cleanup
rm temp_auto.dta
rm temp_dates.dta
rm -r test_dir
```

---

## datefix

### Suggested Error Messages

1. **No variables specified**
   - Error code: 198
   - Message: "varlist required"
   - Trigger: No variables specified

2. **Variable not string**
   - Error code: 109
   - Message: "variable {varname} is not string type"
   - Trigger: Attempting to convert non-string variable

3. **Multiple variables with newvar()**
   - Error code: 198
   - Message: "newvar() option requires exactly one variable"
   - Trigger: More than one variable specified with newvar()

4. **Invalid date format**
   - Error code: 198
   - Message: "invalid date format in df()"
   - Trigger: Invalid format specification

5. **Invalid order specification**
   - Error code: 198
   - Message: "invalid order(); must be DMY, MDY, or YMD"
   - Trigger: Invalid order string

### Validation Testing

```stata
* Test 1: Basic date conversion
clear
input str12 date_str
"2020-01-15"
"2020-02-20"
"2020-03-25"
end
datefix date_str
assert date_str < .

* Test 2: Different date formats
clear
input str15 date_str
"15/01/2020"
"20/02/2020"
"25/03/2020"
end
datefix date_str, order(DMY)

* Test 3: newvar() option
clear
input str12 date_orig
"2020-01-15"
end
datefix date_orig, newvar(date_new)
assert date_new < .
assert "`date_orig'" == "2020-01-15"

* Test 4: drop option
clear
input str12 date_str
"2020-01-15"
end
datefix date_str, newvar(date_new) drop
capture confirm variable date_str
assert _rc == 111

* Test 5: Two-digit years
clear
input str10 date_str
"15/01/20"
"20/02/21"
end
datefix date_str, order(DMY) topyear(2030)

* Test 6: Error: non-string variable
sysuse auto, clear
capture datefix mpg
assert _rc == 109

* Test 7: Error: multiple variables with newvar()
clear
input str12 date1 str12 date2
"2020-01-01" "2020-02-01"
end
capture datefix date1 date2, newvar(date_new)
assert _rc == 198
```

---

## massdesas

### Suggested Error Messages

1. **Directory not found**
   - Error code: 601
   - Message: "directory {directory_name} not found"
   - Trigger: Specified directory does not exist

2. **No SAS files found**
   - Error code: 198
   - Message: "no .sas7bdat files found in specified directory"
   - Trigger: Directory contains no SAS files

3. **usesas command not found**
   - Error code: 199
   - Message: "usesas command not found; install with: ssc install usesas"
   - Trigger: Required package not installed

4. **Conversion error**
   - Error code: 198
   - Message: "error converting {filename}: {error_message}"
   - Trigger: Specific file conversion fails

### Validation Testing

**Note**: This command requires actual .sas7bdat files and the usesas package to test properly.

```stata
* Setup: Create test directory structure
* (Requires SAS test files - create manually or skip)

* Test 1: Basic conversion (requires test SAS files)
* mkdir test_sas
* copy test_data.sas7bdat test_sas/
* massdesas, directory(test_sas)
* confirm file test_sas/test_data.dta

* Test 2: Lowercase option
* massdesas, directory(test_sas) lower

* Test 3: Erase option (use with caution!)
* mkdir test_sas_backup
* copy test_data.sas7bdat test_sas_backup/
* massdesas, directory(test_sas_backup) erase
* capture confirm file test_sas_backup/test_data.sas7bdat
* assert _rc == 601

* Test 4: Error: directory not found
capture massdesas, directory(nonexistent_dir)
assert _rc == 601

* Test 5: Error: no SAS files
mkdir empty_dir
capture massdesas, directory(empty_dir)
assert _rc == 198
rm -r empty_dir
```

---

## pkgtransfer

### Suggested Error Messages

1. **stata.trk not found**
   - Error code: 601
   - Message: "stata.trk file not found in PLUS directory"
   - Trigger: No installed packages or stata.trk missing

2. **Limited package not found**
   - Error code: 198
   - Message: "package {pkgname} not found in stata.trk"
   - Trigger: Specified package not installed

3. **Download failed**
   - Error code: 198
   - Message: "failed to download package files for {pkgname}"
   - Trigger: Network error or file access issue

### Validation Testing

```stata
* Test 1: Generate online installation script
pkgtransfer
confirm file pkgtransfer.do

* Test 2: Limited package list
pkgtransfer, limited(estout)
confirm file pkgtransfer.do

* Test 3: Download mode (creates ZIP)
pkgtransfer, download
confirm file pkgtransfer_local.do
confirm file pkgtransfer_files.zip

* Test 4: Error: invalid package name
capture pkgtransfer, limited(nonexistent_package_xyz)
* Note: May not error if package found in stata.trk

* Test 5: Verify output file contents
pkgtransfer
type pkgtransfer.do
* Manually verify commands are valid
```

---

## regtab

### Suggested Error Messages

1. **No active collect**
   - Error code: 111
   - Message: "no active collection found; run collect: command first"
   - Trigger: No collect commands run before regtab

2. **Missing required options**
   - Error code: 198
   - Message: "xlsx() and sheet() are required"
   - Trigger: Required options not specified

3. **Invalid Excel filename**
   - Error code: 198
   - Message: "xlsx() must end with .xlsx extension"
   - Trigger: Invalid file extension

4. **Incompatible model labels**
   - Error code: 198
   - Message: "number of model labels in models() does not match number of models"
   - Trigger: Mismatch in label count

### Validation Testing

```stata
* Test 1: Basic single model
sysuse auto, clear
collect clear
collect: regress price mpg weight
regtab, xlsx(test_single.xlsx) sheet(Model1) coef(Coef.)
confirm file test_single.xlsx

* Test 2: Multiple models with labels
collect clear
collect: logit foreign mpg
collect: logit foreign mpg weight
collect: logit foreign mpg weight price
regtab, xlsx(test_multi.xlsx) sheet(Models) ///
    models(Model 1 \ Model 2 \ Model 3) ///
    coef(OR) title(Logistic Regression)
confirm file test_multi.xlsx

* Test 3: Options: noint, nore
collect clear
collect: regress price mpg weight
regtab, xlsx(test_opts.xlsx) sheet(NoInt) noint
confirm file test_opts.xlsx

* Test 4: Error: no active collect
collect clear
capture regtab, xlsx(test.xlsx) sheet(Test)
assert _rc == 111

* Test 5: Error: missing required options
collect: regress price mpg
capture regtab
assert _rc == 198

* Test 6: Error: invalid filename
collect: regress price mpg
capture regtab, xlsx(test.txt) sheet(Test)
assert _rc == 198

* Cleanup
rm test_single.xlsx
rm test_multi.xlsx
rm test_opts.xlsx
```

---

## stratetab

### Suggested Error Messages

1. **Missing required options**
   - Error code: 198
   - Message: "using() and xlsx() are required"
   - Trigger: Required options not specified

2. **Strate file not found**
   - Error code: 601
   - Message: "strate output file {filename}.dta not found"
   - Trigger: Specified file does not exist

3. **Label count mismatch**
   - Error code: 198
   - Message: "number of labels must match number of using() files"
   - Trigger: Mismatch in label count

4. **Invalid digits specification**
   - Error code: 198
   - Message: "digits must be between 0 and 10"
   - Trigger: Out of range digit specification

### Validation Testing

```stata
* Test 1: Basic two-outcome table
webuse drugtr, clear
stset studytime, failure(died)

* Create strate outputs
strate drug, output(strate_outcome1) replace
strate drug, failure(died==1) output(strate_outcome2) replace

stratetab, using(strate_outcome1 strate_outcome2) ///
    xlsx(test_strate.xlsx) ///
    labels(Primary Outcome \ Secondary Outcome)
confirm file test_strate.xlsx

* Test 2: Custom formatting
stratetab, using(strate_outcome1 strate_outcome2) ///
    xlsx(test_format.xlsx) ///
    labels(Outcome 1 \ Outcome 2) ///
    digits(2) pydigits(1) ///
    title(Event Rates)
confirm file test_format.xlsx

* Test 3: Unit label
stratetab, using(strate_outcome1 strate_outcome2) ///
    xlsx(test_unit.xlsx) ///
    unitlabel(1000)
confirm file test_unit.xlsx

* Test 4: Error: missing required options
capture stratetab, xlsx(test.xlsx)
assert _rc == 198

* Test 5: Error: file not found
capture stratetab, using(nonexistent_file) xlsx(test.xlsx)
assert _rc == 601

* Test 6: Error: label count mismatch
capture stratetab, using(strate_outcome1 strate_outcome2) ///
    xlsx(test.xlsx) labels(Only One Label)
assert _rc == 198

* Cleanup
rm strate_outcome1.dta
rm strate_outcome2.dta
rm test_strate.xlsx
rm test_format.xlsx
rm test_unit.xlsx
```

---

## table1_tc

### Suggested Error Messages

1. **No variables specified**
   - Error code: 198
   - Message: "vars() option required"
   - Trigger: vars() not specified

2. **Invalid variable type**
   - Error code: 198
   - Message: "invalid variable type {type}; must be contn, contln, conts, cat, cate, bin, or bine"
   - Trigger: Invalid type specification

3. **Variable not found**
   - Error code: 111
   - Message: "variable {varname} not found"
   - Trigger: Specified variable does not exist

4. **Invalid by() variable**
   - Error code: 108
   - Message: "by() variable must be numeric or string"
   - Trigger: Invalid by() variable type

5. **Excel option incomplete**
   - Error code: 198
   - Message: "excel() requires both sheet() and title() options"
   - Trigger: Missing required Excel options

### Validation Testing

```stata
* Test 1: Basic table without grouping
sysuse auto, clear
table1_tc, vars(price contn \ mpg conts \ foreign bin)

* Test 2: Stratified by group
table1_tc, vars(price contn \ mpg conts \ weight contn) ///
    by(foreign)

* Test 3: All variable types
gen log_price = log(price)
table1_tc, vars(price contn \ log_price contln \ mpg conts \ ///
    rep78 cat \ foreign bin)

* Test 4: Excel export
table1_tc, vars(price contn \ mpg conts \ foreign bin) ///
    by(foreign) ///
    excel(test_table1.xlsx) ///
    sheet(Baseline) ///
    title(Table 1: Vehicle Characteristics)
confirm file test_table1.xlsx

* Test 5: Format options
table1_tc, vars(price contn %12.0fc \ mpg conts %4.1f) ///
    onecol

* Test 6: Error: no vars specified
capture table1_tc
assert _rc == 198

* Test 7: Error: invalid variable type
capture table1_tc, vars(price invalid_type)
assert _rc == 198

* Test 8: Error: variable not found
capture table1_tc, vars(nonexistent contn)
assert _rc == 111

* Cleanup
rm test_table1.xlsx
```

---

## today

### Suggested Error Messages

1. **Invalid date format**
   - Error code: 198
   - Message: "invalid date format; must be ymd, dmony, dmy, or mdy"
   - Trigger: Invalid df() specification

2. **from() without to()**
   - Error code: 198
   - Message: "from() and to() must be specified together"
   - Trigger: Only one timezone option specified

3. **Invalid UTC format**
   - Error code: 198
   - Message: "invalid timezone format; use UTC+X or UTC-X"
   - Trigger: Invalid timezone specification

### Validation Testing

```stata
* Test 1: Default format
today
assert "$today" != ""
assert "$today_time" != ""

* Test 2: Different date formats
today, df(ymd)
local ymd_date = "$today"
today, df(dmony)
local dmony_date = "$today"
today, df(dmy)
local dmy_date = "$today"
today, df(mdy)
local mdy_date = "$today"
assert "`ymd_date'" != "`dmony_date'"

* Test 3: Time separator
today, tsep(.)
assert strpos("$today_time", ".") > 0

* Test 4: Hours-minutes only
today, hm
local time_hm = "$today_time"
* Count colons/separators - should be 1 not 2
assert length(subinstr("$today_time", ":", "", .)) == length("$today_time") - 1

* Test 5: Timezone conversion
today, from(UTC+0) to(UTC+5)

* Test 6: Error: invalid date format
capture today, df(invalid_format)
assert _rc == 198

* Test 7: Error: from() without to()
capture today, from(UTC+0)
assert _rc == 198

* Test 8: Error: invalid UTC format
capture today, from(UTC+0) to(invalid)
assert _rc == 198
```

---

## tvtools (tvexpose and tvmerge)

### Suggested Error Messages for tvexpose

1. **Missing required options**
   - Error code: 198
   - Message: "id(), start(), exposure(), reference(), entry(), and exit() are required"
   - Trigger: Missing required options

2. **Variable not found**
   - Error code: 111
   - Message: "variable {varname} not found in using dataset"
   - Trigger: Specified variable does not exist

3. **Invalid exposure definition combination**
   - Error code: 198
   - Message: "cannot combine evertreated, currentformer, duration(), and continuousunit()"
   - Trigger: Incompatible options specified

4. **Duration without continuousunit()**
   - Error code: 198
   - Message: "duration() requires continuousunit() to be specified"
   - Trigger: Missing required option

### Validation Testing for tvexpose

```stata
* Test 1: Basic time-varying exposure
* (Requires test data - create manually)
use cohort, clear
tvexpose using medication, ///
    id(patient_id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_med.dta) replace
confirm file tv_med.dta

* Test 2: Ever-treated exposure
tvexpose using medication, ///
    id(patient_id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(ever_treated) ///
    saveas(tv_ever.dta) replace

* Test 3: Current/former exposure
tvexpose using medication, ///
    id(patient_id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(med_status) ///
    saveas(tv_cf.dta) replace

* Test 4: Duration categories
tvexpose using medication, ///
    id(patient_id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(1 5) continuousunit(years) ///
    saveas(tv_duration.dta) replace

* Test 5: Error: missing required options
capture tvexpose using medication, id(patient_id)
assert _rc == 198
```

### Suggested Error Messages for tvmerge

1. **Missing required options**
   - Error code: 198
   - Message: "id(), start(), stop(), and exposure() are required"
   - Trigger: Missing required options

2. **Dataset count mismatch**
   - Error code: 198
   - Message: "number of datasets must equal number of start/stop/exposure variables"
   - Trigger: Count mismatch

3. **Dataset not found**
   - Error code: 601
   - Message: "dataset {filename}.dta not found"
   - Trigger: File does not exist

4. **Duplicate exposure names**
   - Error code: 198
   - Message: "exposure variable names must be unique across datasets"
   - Trigger: Duplicate exposure variable names

### Validation Testing for tvmerge

```stata
* Test 1: Basic two-dataset merge
use tv_med1, clear
tvmerge tv_med1 tv_med2, ///
    id(patient_id) ///
    start(period_start period_start) ///
    stop(period_end period_end) ///
    exposure(exposure exposure) ///
    generate(med1 med2) ///
    saveas(tv_merged.dta) replace
confirm file tv_merged.dta

* Test 2: Merge with diagnostics
tvmerge tv_med1 tv_med2, ///
    id(patient_id) ///
    start(period_start period_start) ///
    stop(period_end period_end) ///
    exposure(exposure exposure) ///
    check validatecoverage validateoverlap

* Test 3: Keep additional variables
tvmerge tv_med1 tv_med2, ///
    id(patient_id) ///
    start(period_start period_start) ///
    stop(period_end period_end) ///
    exposure(exposure exposure) ///
    keep(age sex)

* Test 4: Error: missing required options
capture tvmerge tv_med1 tv_med2
assert _rc == 198

* Test 5: Error: dataset not found
capture tvmerge nonexistent tv_med2, ///
    id(patient_id) ///
    start(start start) ///
    stop(stop stop) ///
    exposure(exp exp)
assert _rc == 601
```

---

## General Testing Best Practices

1. **Always test with clean data**: Start each test with `clear all` or load fresh data
2. **Test edge cases**: Empty datasets, single observations, missing values
3. **Test error conditions**: Verify error codes match expectations
4. **Clean up after tests**: Remove temporary files and datasets
5. **Document assumptions**: Note any required test data or packages
6. **Version compatibility**: Test on minimum required Stata version
7. **Cross-platform testing**: Test on Windows, Mac, and Linux if possible

## Continuous Integration Suggestions

For automated testing, consider creating a master test file:

```stata
* master_test.do
version 16
set more off

* Test each package
do test_check.do
do test_cstat_surv.do
do test_datamap.do
do test_datefix.do
do test_massdesas.do
do test_pkgtransfer.do
do test_regtab.do
do test_stratetab.do
do test_table1_tc.do
do test_today.do
do test_tvtools.do

display "All tests completed successfully"
```
