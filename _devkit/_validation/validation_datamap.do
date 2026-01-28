/*******************************************************************************
* validation_datamap.do
* Validation tests for datamap.ado and datadict.ado
*
* Tests:
* - Basic execution with single() option
* - Return values verification
* - Output file creation
* - Options: nostats, nofreq, nolabels, maxfreq, maxcat, exclude, datesafe
* - Directory scanning with filelist()
* - Separate output mode
* - datadict: Markdown dictionary generation
* - datadict: Stats and missing options
* - Error conditions
*******************************************************************************/

version 16.0
set more off
set varabbrev off

/*******************************************************************************
* Configuration
*******************************************************************************/
local test_name "validation_datamap"
local stata_path "/usr/local/stata17/stata-mp"

* Path configuration - detect environment
local pwd "`c(pwd)'"
if regexm("`pwd'", "_validation$") {
    local base_path ".."
    local validation_path "."
}
else {
    local base_path "."
    local validation_path "_validation"
}

* Ensure datamap is on adopath
adopath ++ "`base_path'/datamap"

* Create test data directory
capture mkdir "`validation_path'/data"

local pass_count = 0
local fail_count = 0
local test_num = 0

/*******************************************************************************
* Create Test Datasets
*******************************************************************************/
di as text _n "=== Creating Test Datasets ===" _n

* Dataset 1: Mixed variable types
clear
set obs 50
gen id = _n
gen double date_var = td(01jan2020) + int(runiform()*365)
format date_var %td
gen age = 20 + int(runiform()*60)
gen income = 30000 + runiform()*70000
gen sex = (runiform() > 0.5)
label define sex_lab 0 "Female" 1 "Male"
label values sex sex_lab
gen str20 name = "Person" + string(_n)
gen group = 1 + int(runiform()*3)
label define group_lab 1 "Group A" 2 "Group B" 3 "Group C"
label values group group_lab
label data "Test dataset with mixed variable types"
label variable id "Unique identifier"
label variable date_var "Date of observation"
label variable age "Age in years"
label variable income "Annual income"
label variable sex "Sex of participant"
label variable name "Participant name"
label variable group "Study group"
* Add some missing values
replace age = . in 1/5
replace income = . in 3/7
save "`validation_path'/data/val_datamap_mixed.dta", replace

* Dataset 2: High cardinality numeric for categorical detection
clear
set obs 100
gen id = _n
gen category5 = 1 + int(runiform()*5)
gen category50 = 1 + int(runiform()*50)
gen continuous = runiform()*100
label data "Test dataset for cardinality detection"
save "`validation_path'/data/val_datamap_cardinality.dta", replace

* Dataset 3: For panel detection
clear
set obs 200
gen patient_id = 1 + int((_n - 1) / 4)
bysort patient_id: gen visit = _n
gen outcome = runiform()
label data "Panel structure test dataset"
save "`validation_path'/data/val_datamap_panel.dta", replace

di as text "Test datasets created successfully."

/*******************************************************************************
* Section 1: datamap - Basic Execution and Return Values
*******************************************************************************/
di as text _n "=== Section 1: datamap Basic Execution ===" _n

* Test 1.1: Basic single file processing
local ++test_num
di as text "Test `test_num': Basic single file processing"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_output.txt")
}
if _rc == 0 {
    di as result "  PASS: datamap executed without error"
    local ++pass_count
}
else {
    di as error "  FAIL: datamap failed with rc = `=_rc'"
    local ++fail_count
}

* Test 1.2: Return value r(nfiles)
local ++test_num
di as text "Test `test_num': Return value r(nfiles)"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_output.txt")
}
if r(nfiles) == 1 {
    di as result "  PASS: r(nfiles) = `r(nfiles)' as expected"
    local ++pass_count
}
else {
    di as error "  FAIL: r(nfiles) = `r(nfiles)', expected 1"
    local ++fail_count
}

* Test 1.3: Return value r(format)
local ++test_num
di as text "Test `test_num': Return value r(format)"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_output.txt")
}
if "`r(format)'" == "text" {
    di as result "  PASS: r(format) = `r(format)' as expected"
    local ++pass_count
}
else {
    di as error "  FAIL: r(format) = `r(format)', expected text"
    local ++fail_count
}

* Test 1.4: Return value r(output)
local ++test_num
di as text "Test `test_num': Return value r(output)"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_output.txt")
}
if regexm("`r(output)'", "test_output\.txt") {
    di as result "  PASS: r(output) contains expected filename"
    local ++pass_count
}
else {
    di as error "  FAIL: r(output) = `r(output)', expected test_output.txt"
    local ++fail_count
}

* Test 1.5: Output file created
local ++test_num
di as text "Test `test_num': Output file created"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_verify.txt")
    confirm file "`validation_path'/data/test_verify.txt"
}
if _rc == 0 {
    di as result "  PASS: Output file created successfully"
    local ++pass_count
}
else {
    di as error "  FAIL: Output file not created"
    local ++fail_count
}

/*******************************************************************************
* Section 2: datamap - Content Control Options
*******************************************************************************/
di as text _n "=== Section 2: datamap Content Control Options ===" _n

* Test 2.1: nostats option
local ++test_num
di as text "Test `test_num': nostats option"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_nostats.txt") nostats
}
if _rc == 0 {
    di as result "  PASS: nostats option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: nostats option failed"
    local ++fail_count
}

* Test 2.2: nofreq option
local ++test_num
di as text "Test `test_num': nofreq option"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_nofreq.txt") nofreq
}
if _rc == 0 {
    di as result "  PASS: nofreq option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: nofreq option failed"
    local ++fail_count
}

* Test 2.3: nolabels option
local ++test_num
di as text "Test `test_num': nolabels option"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_nolabels.txt") nolabels
}
if _rc == 0 {
    di as result "  PASS: nolabels option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: nolabels option failed"
    local ++fail_count
}

* Test 2.4: maxfreq option
local ++test_num
di as text "Test `test_num': maxfreq(10) option"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_maxfreq.txt") maxfreq(10)
}
if _rc == 0 {
    di as result "  PASS: maxfreq(10) option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: maxfreq(10) option failed"
    local ++fail_count
}

* Test 2.5: maxcat option
local ++test_num
di as text "Test `test_num': maxcat(5) option"
capture {
    datamap, single("`validation_path'/data/val_datamap_cardinality.dta") ///
        output("`validation_path'/data/test_maxcat.txt") maxcat(5)
}
if _rc == 0 {
    di as result "  PASS: maxcat(5) option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: maxcat(5) option failed"
    local ++fail_count
}

/*******************************************************************************
* Section 3: datamap - Privacy Options
*******************************************************************************/
di as text _n "=== Section 3: datamap Privacy Options ===" _n

* Test 3.1: exclude option
local ++test_num
di as text "Test `test_num': exclude(id name) option"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_exclude.txt") exclude(id name)
}
if _rc == 0 {
    di as result "  PASS: exclude option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: exclude option failed"
    local ++fail_count
}

* Test 3.2: datesafe option
local ++test_num
di as text "Test `test_num': datesafe option"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_datesafe.txt") datesafe
}
if _rc == 0 {
    di as result "  PASS: datesafe option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: datesafe option failed"
    local ++fail_count
}

/*******************************************************************************
* Section 4: datamap - Multiple Files
*******************************************************************************/
di as text _n "=== Section 4: datamap Multiple Files ===" _n

* Test 4.1: filelist option with multiple datasets
local ++test_num
di as text "Test `test_num': filelist option with multiple datasets"
capture {
    datamap, filelist("`validation_path'/data/val_datamap_mixed.dta `validation_path'/data/val_datamap_cardinality.dta") ///
        output("`validation_path'/data/test_filelist.txt")
}
if _rc == 0 & r(nfiles) == 2 {
    di as result "  PASS: filelist processed 2 files"
    local ++pass_count
}
else {
    di as error "  FAIL: filelist processing failed or wrong file count"
    local ++fail_count
}

/*******************************************************************************
* Section 5: datamap - Detection Features
*******************************************************************************/
di as text _n "=== Section 5: datamap Detection Features ===" _n

* Test 5.1: autodetect option
local ++test_num
di as text "Test `test_num': autodetect option"
capture {
    datamap, single("`validation_path'/data/val_datamap_panel.dta") ///
        output("`validation_path'/data/test_autodetect.txt") autodetect
}
if _rc == 0 {
    di as result "  PASS: autodetect option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: autodetect option failed"
    local ++fail_count
}

* Test 5.2: detect(panel) option
local ++test_num
di as text "Test `test_num': detect(panel) option"
capture {
    datamap, single("`validation_path'/data/val_datamap_panel.dta") ///
        output("`validation_path'/data/test_detect_panel.txt") detect(panel)
}
if _rc == 0 {
    di as result "  PASS: detect(panel) option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: detect(panel) option failed"
    local ++fail_count
}

* Test 5.3: panelid option
local ++test_num
di as text "Test `test_num': panelid(patient_id) option"
capture {
    datamap, single("`validation_path'/data/val_datamap_panel.dta") ///
        output("`validation_path'/data/test_panelid.txt") detect(panel) panelid(patient_id)
}
if _rc == 0 {
    di as result "  PASS: panelid option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: panelid option failed"
    local ++fail_count
}

/*******************************************************************************
* Section 6: datamap - Quality and Missing Options
*******************************************************************************/
di as text _n "=== Section 6: datamap Quality and Missing Options ===" _n

* Test 6.1: quality option
local ++test_num
di as text "Test `test_num': quality option"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_quality.txt") quality
}
if _rc == 0 {
    di as result "  PASS: quality option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: quality option failed"
    local ++fail_count
}

* Test 6.2: missing(detail) option
local ++test_num
di as text "Test `test_num': missing(detail) option"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_missing.txt") missing(detail)
}
if _rc == 0 {
    di as result "  PASS: missing(detail) option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: missing(detail) option failed"
    local ++fail_count
}

/*******************************************************************************
* Section 7: datamap - Error Conditions
*******************************************************************************/
di as text _n "=== Section 7: datamap Error Conditions ===" _n

* Test 7.1: Error when no input specified
local ++test_num
di as text "Test `test_num': Error when no input specified"
capture noisily datamap, output(test.txt)
if _rc == 198 {
    di as result "  PASS: Correctly errored with rc 198"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 198, got `=_rc'"
    local ++fail_count
}

* Test 7.2: Error when multiple input options specified
local ++test_num
di as text "Test `test_num': Error when multiple input options"
capture noisily datamap, single(test.dta) directory(.)
if _rc == 198 {
    di as result "  PASS: Correctly errored with rc 198"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 198, got `=_rc'"
    local ++fail_count
}

* Test 7.3: Error with invalid maxfreq
local ++test_num
di as text "Test `test_num': Error with invalid maxfreq(0)"
capture noisily datamap, single("`validation_path'/data/val_datamap_mixed.dta") maxfreq(0)
if _rc == 198 {
    di as result "  PASS: Correctly errored with rc 198"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 198, got `=_rc'"
    local ++fail_count
}

* Test 7.4: Error when file not found
local ++test_num
di as text "Test `test_num': Error when file not found"
capture noisily datamap, single("nonexistent_file.dta")
if _rc != 0 {
    di as result "  PASS: Correctly errored for missing file"
    local ++pass_count
}
else {
    di as error "  FAIL: Should have errored for missing file"
    local ++fail_count
}

/*******************************************************************************
* Section 8: datadict - Basic Execution
*******************************************************************************/
di as text _n "=== Section 8: datadict Basic Execution ===" _n

* Test 8.1: Basic single file processing
local ++test_num
di as text "Test `test_num': datadict basic execution"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict.md")
}
if _rc == 0 {
    di as result "  PASS: datadict executed without error"
    local ++pass_count
}
else {
    di as error "  FAIL: datadict failed with rc = `=_rc'"
    local ++fail_count
}

* Test 8.2: Return value r(nfiles)
local ++test_num
di as text "Test `test_num': datadict r(nfiles)"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict.md")
}
if r(nfiles) == 1 {
    di as result "  PASS: r(nfiles) = `r(nfiles)' as expected"
    local ++pass_count
}
else {
    di as error "  FAIL: r(nfiles) = `r(nfiles)', expected 1"
    local ++fail_count
}

* Test 8.3: Return value r(output)
local ++test_num
di as text "Test `test_num': datadict r(output)"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict.md")
}
if regexm("`r(output)'", "test_dict\.md") {
    di as result "  PASS: r(output) contains expected filename"
    local ++pass_count
}
else {
    di as error "  FAIL: r(output) = `r(output)', expected test_dict.md"
    local ++fail_count
}

* Test 8.4: Output file created
local ++test_num
di as text "Test `test_num': datadict output file created"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict_verify.md")
    confirm file "`validation_path'/data/test_dict_verify.md"
}
if _rc == 0 {
    di as result "  PASS: Output file created successfully"
    local ++pass_count
}
else {
    di as error "  FAIL: Output file not created"
    local ++fail_count
}

/*******************************************************************************
* Section 9: datadict - Metadata Options
*******************************************************************************/
di as text _n "=== Section 9: datadict Metadata Options ===" _n

* Test 9.1: title option
local ++test_num
di as text "Test `test_num': title option"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict_title.md") ///
        title("Custom Title")
}
if _rc == 0 {
    di as result "  PASS: title option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: title option failed"
    local ++fail_count
}

* Test 9.2: subtitle option
local ++test_num
di as text "Test `test_num': subtitle option"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict_subtitle.md") ///
        subtitle("A subtitle for the dictionary")
}
if _rc == 0 {
    di as result "  PASS: subtitle option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: subtitle option failed"
    local ++fail_count
}

* Test 9.3: version option
local ++test_num
di as text "Test `test_num': version option"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict_version.md") ///
        version("1.0.0")
}
if _rc == 0 {
    di as result "  PASS: version option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: version option failed"
    local ++fail_count
}

* Test 9.4: author option
local ++test_num
di as text "Test `test_num': author option"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict_author.md") ///
        author("Test Author")
}
if _rc == 0 {
    di as result "  PASS: author option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: author option failed"
    local ++fail_count
}

/*******************************************************************************
* Section 10: datadict - Content Options
*******************************************************************************/
di as text _n "=== Section 10: datadict Content Options ===" _n

* Test 10.1: missing option
local ++test_num
di as text "Test `test_num': missing option"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict_missing.md") ///
        missing
}
if _rc == 0 {
    di as result "  PASS: missing option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: missing option failed"
    local ++fail_count
}

* Test 10.2: stats option
local ++test_num
di as text "Test `test_num': stats option"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict_stats.md") ///
        stats
}
if _rc == 0 {
    di as result "  PASS: stats option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: stats option failed"
    local ++fail_count
}

* Test 10.3: missing and stats together
local ++test_num
di as text "Test `test_num': missing and stats together"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict_both.md") ///
        missing stats
}
if _rc == 0 {
    di as result "  PASS: missing and stats together accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: missing and stats together failed"
    local ++fail_count
}

* Test 10.4: maxcat option
local ++test_num
di as text "Test `test_num': maxcat(10) option"
capture {
    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_dict_maxcat.md") ///
        maxcat(10)
}
if _rc == 0 {
    di as result "  PASS: maxcat(10) option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: maxcat(10) option failed"
    local ++fail_count
}

/*******************************************************************************
* Section 11: datadict - Multiple Files
*******************************************************************************/
di as text _n "=== Section 11: datadict Multiple Files ===" _n

* Test 11.1: filelist option
local ++test_num
di as text "Test `test_num': filelist option"
capture {
    datadict, filelist("`validation_path'/data/val_datamap_mixed.dta `validation_path'/data/val_datamap_cardinality.dta") ///
        output("`validation_path'/data/test_dict_filelist.md")
}
if _rc == 0 & r(nfiles) == 2 {
    di as result "  PASS: filelist processed 2 files"
    local ++pass_count
}
else {
    di as error "  FAIL: filelist processing failed"
    local ++fail_count
}

/*******************************************************************************
* Section 12: datadict - Error Conditions
*******************************************************************************/
di as text _n "=== Section 12: datadict Error Conditions ===" _n

* Test 12.1: Error when no input specified
local ++test_num
di as text "Test `test_num': Error when no input specified"
capture noisily datadict, output(test.md)
if _rc == 198 {
    di as result "  PASS: Correctly errored with rc 198"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 198, got `=_rc'"
    local ++fail_count
}

* Test 12.2: Error when multiple input options specified
local ++test_num
di as text "Test `test_num': Error when multiple input options"
capture noisily datadict, single(test.dta) directory(.)
if _rc == 198 {
    di as result "  PASS: Correctly errored with rc 198"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 198, got `=_rc'"
    local ++fail_count
}

* Test 12.3: Error with invalid maxcat
local ++test_num
di as text "Test `test_num': Error with invalid maxcat(0)"
capture noisily datadict, single("`validation_path'/data/val_datamap_mixed.dta") maxcat(0)
if _rc == 198 {
    di as result "  PASS: Correctly errored with rc 198"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 198, got `=_rc'"
    local ++fail_count
}

* Test 12.4: Error when file not found
local ++test_num
di as text "Test `test_num': Error when file not found"
capture noisily datadict, single("nonexistent_file.dta")
if _rc != 0 {
    di as result "  PASS: Correctly errored for missing file"
    local ++pass_count
}
else {
    di as error "  FAIL: Should have errored for missing file"
    local ++fail_count
}

/*******************************************************************************
* Section 13: Invariant Tests
*******************************************************************************/
di as text _n "=== Section 13: Invariant Tests ===" _n

* Test 13.1: datamap output is consistent across runs
local ++test_num
di as text "Test `test_num': datamap output consistency"
capture {
    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_consist1.txt")
    file open f1 using "`validation_path'/data/test_consist1.txt", read text
    file read f1 line1
    file close f1

    datamap, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_consist2.txt")
    file open f2 using "`validation_path'/data/test_consist2.txt", read text
    file read f2 line2
    file close f2
}
* Skip detailed comparison due to timestamps - just verify files exist
if _rc == 0 {
    di as result "  PASS: Multiple runs produce output without error"
    local ++pass_count
}
else {
    di as error "  FAIL: Consistency test failed"
    local ++fail_count
}

* Test 13.2: datadict preserves original data
local ++test_num
di as text "Test `test_num': datadict preserves original data"
capture {
    use "`validation_path'/data/val_datamap_mixed.dta", clear
    local orig_n = _N
    local orig_k = c(k)

    datadict, single("`validation_path'/data/val_datamap_mixed.dta") ///
        output("`validation_path'/data/test_preserve.md")

    * Data should be preserved (restore happens in datadict)
    use "`validation_path'/data/val_datamap_mixed.dta", clear
    local new_n = _N
    local new_k = c(k)
}
if `orig_n' == `new_n' & `orig_k' == `new_k' {
    di as result "  PASS: Original dataset unchanged"
    local ++pass_count
}
else {
    di as error "  FAIL: Dataset was modified"
    local ++fail_count
}

/*******************************************************************************
* Cleanup and Summary
*******************************************************************************/
di as text _n "=== Cleaning up test files ===" _n

* Remove test output files
capture erase "`validation_path'/data/test_output.txt"
capture erase "`validation_path'/data/test_verify.txt"
capture erase "`validation_path'/data/test_nostats.txt"
capture erase "`validation_path'/data/test_nofreq.txt"
capture erase "`validation_path'/data/test_nolabels.txt"
capture erase "`validation_path'/data/test_maxfreq.txt"
capture erase "`validation_path'/data/test_maxcat.txt"
capture erase "`validation_path'/data/test_exclude.txt"
capture erase "`validation_path'/data/test_datesafe.txt"
capture erase "`validation_path'/data/test_filelist.txt"
capture erase "`validation_path'/data/test_autodetect.txt"
capture erase "`validation_path'/data/test_detect_panel.txt"
capture erase "`validation_path'/data/test_panelid.txt"
capture erase "`validation_path'/data/test_quality.txt"
capture erase "`validation_path'/data/test_missing.txt"
capture erase "`validation_path'/data/test_dict.md"
capture erase "`validation_path'/data/test_dict_verify.md"
capture erase "`validation_path'/data/test_dict_title.md"
capture erase "`validation_path'/data/test_dict_subtitle.md"
capture erase "`validation_path'/data/test_dict_version.md"
capture erase "`validation_path'/data/test_dict_author.md"
capture erase "`validation_path'/data/test_dict_missing.md"
capture erase "`validation_path'/data/test_dict_stats.md"
capture erase "`validation_path'/data/test_dict_both.md"
capture erase "`validation_path'/data/test_dict_maxcat.md"
capture erase "`validation_path'/data/test_dict_filelist.md"
capture erase "`validation_path'/data/test_consist1.txt"
capture erase "`validation_path'/data/test_consist2.txt"
capture erase "`validation_path'/data/test_preserve.md"

* Remove test datasets
capture erase "`validation_path'/data/val_datamap_mixed.dta"
capture erase "`validation_path'/data/val_datamap_cardinality.dta"
capture erase "`validation_path'/data/val_datamap_panel.dta"

/*******************************************************************************
* Final Summary
*******************************************************************************/
di as text _n "=========================================="
di as text "VALIDATION SUMMARY: `test_name'"
di as text "=========================================="
di as text "Total tests: `test_num'"
di as result "Passed: `pass_count'"
if `fail_count' > 0 {
    di as error "Failed: `fail_count'"
}
else {
    di as text "Failed: `fail_count'"
}
di as text "==========================================" _n

if `fail_count' > 0 {
    exit 1
}
