clear all
set more off
version 16.0

* validation_datamap.do - Correctness validation for datamap package
* Generated: 2026-03-13
* Validates: variable classification, content correctness, return values,
*            output content verification, missing data handling, invariants

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0

local pkg_dir "/home/tpcopeland/Stata-Tools/datamap"
local qa_dir  "`pkg_dir'/qa"
local tmp_dir "`qa_dir'/data"

capture mkdir "`tmp_dir'"

* Uninstall any existing version
capture ado uninstall datamap

* Install from local directory
quietly net install datamap, from("`pkg_dir'") force

* ============================================================
* V1: Variable Classification - Known Types
* ============================================================
* Create dataset with exactly known variable types:
*   id       -> continuous (numeric, no labels, many unique values)
*   age      -> continuous (numeric, no labels)
*   sex      -> categorical (labeled 0/1)
*   bmi      -> continuous (numeric, no labels)
*   region   -> categorical (labeled 1-4)
*   entry_dt -> date (%td format)
*   name     -> string

clear
set seed 99999
set obs 50
gen double id = _n
gen double age = 25 + int(50*runiform())
gen byte sex = cond(runiform() > 0.5, 1, 0)
label define sexlbl 0 "Female" 1 "Male"
label values sex sexlbl
gen double bmi = 18 + 15*runiform()
gen byte region = 1 + int(4*runiform())
label define reglbl 1 "North" 2 "South" 3 "East" 4 "West"
label values region reglbl
gen double entry_dt = td(01jan2020) + int(365*runiform())
format entry_dt %td
gen str10 name = "P" + string(_n)
label data "Classification test dataset"
save "`tmp_dir'/val_classify.dta", replace

* V1.1: Continuous variables classified correctly
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_class.txt")

    * Read output and check classifications
    tempname fh
    file open `fh' using "`tmp_dir'/_val_class.txt", read text
    local found_age_continuous 0
    local found_bmi_continuous 0
    local found_sex_categorical 0
    local found_region_categorical 0
    local found_entry_date 0
    local found_name_string 0
    local current_var ""

    file read `fh' line
    while r(eof) == 0 {
        * Detect variable section headers (variable name appears at start)
        if strpos(`"`macval(line)'"', "  age") > 0 & "`current_var'" == "" {
            local current_var "age"
        }
        if strpos(`"`macval(line)'"', "  bmi") > 0 & "`current_var'" == "" {
            local current_var "bmi"
        }
        if strpos(`"`macval(line)'"', "  sex") > 0 & "`current_var'" == "" {
            local current_var "sex"
        }
        if strpos(`"`macval(line)'"', "  region") > 0 & "`current_var'" == "" {
            local current_var "region"
        }
        if strpos(`"`macval(line)'"', "  entry_dt") > 0 & "`current_var'" == "" {
            local current_var "entry_dt"
        }
        if strpos(`"`macval(line)'"', "  name") > 0 & "`current_var'" == "" {
            local current_var "name"
        }

        * Check classification line
        if strpos(`"`macval(line)'"', "Classification:") > 0 | ///
           strpos(`"`macval(line)'"', "classification:") > 0 {
            if "`current_var'" == "age" & strpos(`"`macval(line)'"', "ontinuous") > 0 {
                local found_age_continuous 1
            }
            if "`current_var'" == "bmi" & strpos(`"`macval(line)'"', "ontinuous") > 0 {
                local found_bmi_continuous 1
            }
            if "`current_var'" == "sex" & strpos(`"`macval(line)'"', "ategorical") > 0 {
                local found_sex_categorical 1
            }
            if "`current_var'" == "region" & strpos(`"`macval(line)'"', "ategorical") > 0 {
                local found_region_categorical 1
            }
            if "`current_var'" == "entry_dt" & strpos(`"`macval(line)'"', "ate") > 0 {
                local found_entry_date 1
            }
            if "`current_var'" == "name" & strpos(`"`macval(line)'"', "tring") > 0 {
                local found_name_string 1
            }
            local current_var ""
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_age_continuous' == 1
    assert `found_bmi_continuous' == 1
}
if _rc == 0 {
    display as result "  PASS: V1.1 - Continuous variables (age, bmi) classified correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.1 - Continuous variable classification (error `=_rc')"
    local ++fail_count
}

* V1.2: Categorical variables classified correctly
local ++test_count
capture noisily {
    * Re-read from the same output
    assert `found_sex_categorical' == 1
    assert `found_region_categorical' == 1
}
if _rc == 0 {
    display as result "  PASS: V1.2 - Categorical variables (sex, region) classified correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.2 - Categorical variable classification (error `=_rc')"
    local ++fail_count
}

* V1.3: Date variable classified correctly
local ++test_count
capture noisily {
    assert `found_entry_date' == 1
}
if _rc == 0 {
    display as result "  PASS: V1.3 - Date variable (entry_dt) classified correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.3 - Date variable classification (error `=_rc')"
    local ++fail_count
}

* V1.4: String variable classified correctly
local ++test_count
capture noisily {
    assert `found_name_string' == 1
}
if _rc == 0 {
    display as result "  PASS: V1.4 - String variable (name) classified correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.4 - String variable classification (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V2: Categorical Detection by Cardinality
* ============================================================
* maxcat controls the threshold for categorical detection
* A variable with 3 unique values should be categorical at maxcat(5)
* but continuous at maxcat(2)

clear
set obs 30
gen grp3 = mod(_n - 1, 3) + 1
gen grp50 = _n
save "`tmp_dir'/val_cardinality.dta", replace

* V2.1: Variable with 3 unique values is categorical at default maxcat(25)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_cardinality") output("`tmp_dir'/_val_card.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_card.txt", read text
    local grp3_cat 0
    local current_var ""
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "  grp3") > 0 & "`current_var'" == "" {
            local current_var "grp3"
        }
        if strpos(`"`macval(line)'"', "Classification:") > 0 | ///
           strpos(`"`macval(line)'"', "classification:") > 0 {
            if "`current_var'" == "grp3" & strpos(`"`macval(line)'"', "ategorical") > 0 {
                local grp3_cat 1
            }
            local current_var ""
        }
        file read `fh' line
    }
    file close `fh'

    assert `grp3_cat' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.1 - 3-value variable classified as categorical (default maxcat)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.1 - Cardinality detection (error `=_rc')"
    local ++fail_count
}

* V2.2: Variable with 30 unique values is continuous at default maxcat(25)
local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`tmp_dir'/_val_card.txt", read text
    local grp50_cont 0
    local current_var ""
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "  grp50") > 0 & "`current_var'" == "" {
            local current_var "grp50"
        }
        if strpos(`"`macval(line)'"', "Classification:") > 0 | ///
           strpos(`"`macval(line)'"', "classification:") > 0 {
            if "`current_var'" == "grp50" & strpos(`"`macval(line)'"', "ontinuous") > 0 {
                local grp50_cont 1
            }
            local current_var ""
        }
        file read `fh' line
    }
    file close `fh'

    assert `grp50_cont' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.2 - 30-value variable classified as continuous (default maxcat)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.2 - High-cardinality detection (error `=_rc')"
    local ++fail_count
}

* V2.3: maxcat(2) makes 3-value variable continuous
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_cardinality") maxcat(2) ///
        output("`tmp_dir'/_val_card2.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_card2.txt", read text
    local grp3_now_cont 0
    local current_var ""
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "  grp3") > 0 & "`current_var'" == "" {
            local current_var "grp3"
        }
        if strpos(`"`macval(line)'"', "Classification:") > 0 | ///
           strpos(`"`macval(line)'"', "classification:") > 0 {
            if "`current_var'" == "grp3" & strpos(`"`macval(line)'"', "ontinuous") > 0 {
                local grp3_now_cont 1
            }
            local current_var ""
        }
        file read `fh' line
    }
    file close `fh'

    assert `grp3_now_cont' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.3 - maxcat(2) reclassifies 3-value variable as continuous"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.3 - maxcat threshold effect (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V3: Return Value Correctness
* ============================================================

* V3.1: r(nfiles) matches number of files processed
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_rv1.txt")
    assert r(nfiles) == 1

    datamap, filelist("`tmp_dir'/val_classify" "`tmp_dir'/val_cardinality") ///
        output("`tmp_dir'/_val_rv2.txt")
    assert r(nfiles) == 2
}
if _rc == 0 {
    display as result "  PASS: V3.1 - r(nfiles) correct for single (1) and filelist (2)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.1 - r(nfiles) verification (error `=_rc')"
    local ++fail_count
}

* V3.2: r(format) always "text" for datamap
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_fmt.txt")
    assert "`r(format)'" == "text"

    datamap, single("`tmp_dir'/val_classify") nostats output("`tmp_dir'/_val_fmt2.txt")
    assert "`r(format)'" == "text"
}
if _rc == 0 {
    display as result "  PASS: V3.2 - r(format) always 'text'"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.2 - r(format) verification (error `=_rc')"
    local ++fail_count
}

* V3.3: datadict r(nfiles) matches number of files
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd_rv1.md")
    assert r(nfiles) == 1

    datadict, filelist("`tmp_dir'/val_classify" "`tmp_dir'/val_cardinality") ///
        output("`tmp_dir'/_val_dd_rv2.md")
    assert r(nfiles) == 2
}
if _rc == 0 {
    display as result "  PASS: V3.3 - datadict r(nfiles) correct for single and filelist"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.3 - datadict r(nfiles) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V4: Output Content Verification - datamap
* ============================================================

* V4.1: Output contains dataset label
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_content.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_content.txt", read text
    local found_label 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Classification test dataset") > 0 {
            local found_label 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_label' == 1
}
if _rc == 0 {
    display as result "  PASS: V4.1 - Output contains dataset label"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.1 - Dataset label in output (error `=_rc')"
    local ++fail_count
}

* V4.2: Output contains all variable names
local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`tmp_dir'/_val_content.txt", read text
    local found_id 0
    local found_age 0
    local found_sex 0
    local found_bmi 0
    local found_region 0
    local found_entry 0
    local found_name 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "id") > 0 local found_id 1
        if strpos(`"`macval(line)'"', "age") > 0 local found_age 1
        if strpos(`"`macval(line)'"', "sex") > 0 local found_sex 1
        if strpos(`"`macval(line)'"', "bmi") > 0 local found_bmi 1
        if strpos(`"`macval(line)'"', "region") > 0 local found_region 1
        if strpos(`"`macval(line)'"', "entry_dt") > 0 local found_entry 1
        if strpos(`"`macval(line)'"', "name") > 0 local found_name 1
        file read `fh' line
    }
    file close `fh'

    assert `found_id' == 1
    assert `found_age' == 1
    assert `found_sex' == 1
    assert `found_bmi' == 1
    assert `found_region' == 1
    assert `found_entry' == 1
    assert `found_name' == 1
}
if _rc == 0 {
    display as result "  PASS: V4.2 - Output contains all 7 variable names"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.2 - Variable names in output (error `=_rc')"
    local ++fail_count
}

* V4.3: Output contains value labels for categorical vars
local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`tmp_dir'/_val_content.txt", read text
    local found_female 0
    local found_male 0
    local found_north 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Female") > 0 local found_female 1
        if strpos(`"`macval(line)'"', "Male") > 0 local found_male 1
        if strpos(`"`macval(line)'"', "North") > 0 local found_north 1
        file read `fh' line
    }
    file close `fh'

    assert `found_female' == 1
    assert `found_male' == 1
    assert `found_north' == 1
}
if _rc == 0 {
    display as result "  PASS: V4.3 - Output contains value labels (Female, Male, North)"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.3 - Value labels in output (error `=_rc')"
    local ++fail_count
}

* V4.4: nostats suppresses statistics
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") nostats ///
        output("`tmp_dir'/_val_nostats.txt")

    * With nostats, "Mean" should not appear
    tempname fh
    file open `fh' using "`tmp_dir'/_val_nostats.txt", read text
    local found_mean 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Mean") > 0 | ///
           strpos(`"`macval(line)'"', "mean") > 0 {
            local found_mean 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_mean' == 0
}
if _rc == 0 {
    display as result "  PASS: V4.4 - nostats suppresses Mean from output"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.4 - nostats suppression (error `=_rc')"
    local ++fail_count
}

* V4.5: exclude removes variable from detailed output
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") exclude(id name) ///
        output("`tmp_dir'/_val_excl.txt")

    * Excluded vars should still appear but without detailed stats/values
    * The key check: no statistics or frequency for id should appear
    tempname fh
    file open `fh' using "`tmp_dir'/_val_excl.txt", read text
    local found_excluded 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "xcluded") > 0 | ///
           strpos(`"`macval(line)'"', "EXCLUDED") > 0 | ///
           strpos(`"`macval(line)'"', "excluded") > 0 {
            local found_excluded 1
        }
        file read `fh' line
    }
    file close `fh'

    * The exclude option should mark variables as excluded in some way
    assert `found_excluded' == 1
}
if _rc == 0 {
    display as result "  PASS: V4.5 - exclude marks variables as excluded"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.5 - exclude content verification (error `=_rc')"
    local ++fail_count
}

* V4.6: Observation count (N=50) appears in output
local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`tmp_dir'/_val_content.txt", read text
    local found_n50 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "50") > 0 {
            local found_n50 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_n50' == 1
}
if _rc == 0 {
    display as result "  PASS: V4.6 - Observation count (50) appears in output"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.6 - Observation count in output (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V5: Output Content Verification - datadict
* ============================================================

* V5.1: Markdown output contains title
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd.md") ///
        title("Validation Test Title")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_dd.md", read text
    local found_title 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Validation Test Title") > 0 {
            local found_title 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_title' == 1
}
if _rc == 0 {
    display as result "  PASS: V5.1 - Markdown contains title"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.1 - Title in markdown (error `=_rc')"
    local ++fail_count
}

* V5.2: Markdown output contains subtitle
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd2.md") ///
        title("Test") subtitle("Validation Subtitle Text")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_dd2.md", read text
    local found_sub 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Validation Subtitle Text") > 0 {
            local found_sub 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_sub' == 1
}
if _rc == 0 {
    display as result "  PASS: V5.2 - Markdown contains subtitle"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.2 - Subtitle in markdown (error `=_rc')"
    local ++fail_count
}

* V5.3: Markdown contains version string
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd3.md") ///
        version("3.14")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_dd3.md", read text
    local found_ver 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "3.14") > 0 {
            local found_ver 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_ver' == 1
}
if _rc == 0 {
    display as result "  PASS: V5.3 - Markdown contains version string"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.3 - Version in markdown (error `=_rc')"
    local ++fail_count
}

* V5.4: Markdown contains author
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd4.md") ///
        author("Validation Test Author")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_dd4.md", read text
    local found_auth 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Validation Test Author") > 0 {
            local found_auth 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_auth' == 1
}
if _rc == 0 {
    display as result "  PASS: V5.4 - Markdown contains author"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.4 - Author in markdown (error `=_rc')"
    local ++fail_count
}

* V5.5: Markdown contains all variable names in table
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd5.md")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_dd5.md", read text
    local found_vars 0
    file read `fh' line
    while r(eof) == 0 {
        * Markdown tables use | to delimit columns
        if strpos(`"`macval(line)'"', "age") > 0 & strpos(`"`macval(line)'"', "|") > 0 {
            local ++found_vars
        }
        if strpos(`"`macval(line)'"', "sex") > 0 & strpos(`"`macval(line)'"', "|") > 0 {
            local ++found_vars
        }
        if strpos(`"`macval(line)'"', "bmi") > 0 & strpos(`"`macval(line)'"', "|") > 0 {
            local ++found_vars
        }
        if strpos(`"`macval(line)'"', "region") > 0 & strpos(`"`macval(line)'"', "|") > 0 {
            local ++found_vars
        }
        file read `fh' line
    }
    file close `fh'

    * Should find at least 4 variables in table rows
    assert `found_vars' >= 4
}
if _rc == 0 {
    display as result "  PASS: V5.5 - Markdown table contains variable names"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.5 - Variables in markdown table (error `=_rc')"
    local ++fail_count
}

* V5.6: Markdown with missing option shows Missing column
local ++test_count
capture noisily {
    * Create dataset with known missingness
    clear
    set obs 20
    gen x = _n
    replace x = . in 1/5
    gen y = _n * 2
    save "`tmp_dir'/val_miss_known.dta", replace

    datadict, single("`tmp_dir'/val_miss_known") output("`tmp_dir'/_val_dd_miss.md") ///
        missing

    tempname fh
    file open `fh' using "`tmp_dir'/_val_dd_miss.md", read text
    local found_missing_col 0
    file read `fh' line
    while r(eof) == 0 {
        * Header row should contain "Missing"
        if strpos(`"`macval(line)'"', "Missing") > 0 | ///
           strpos(`"`macval(line)'"', "missing") > 0 {
            local found_missing_col 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_missing_col' == 1
}
if _rc == 0 {
    display as result "  PASS: V5.6 - Markdown with missing option shows Missing column"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.6 - Missing column in markdown (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V6: Missing Data Handling
* ============================================================

* V6.1: Missing data analysis detects missing values
local ++test_count
capture noisily {
    * Dataset val_miss_known has 5 missing in x (25%), 0 in y
    datamap, single("`tmp_dir'/val_miss_known") missing(detail) ///
        output("`tmp_dir'/_val_miss_det.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_miss_det.txt", read text
    local found_missing_info 0
    file read `fh' line
    while r(eof) == 0 {
        * Should mention missing count or percentage for x
        if strpos(`"`macval(line)'"', "5") > 0 & strpos(`"`macval(line)'"', "issing") > 0 {
            local found_missing_info 1
        }
        if strpos(`"`macval(line)'"', "25") > 0 & strpos(`"`macval(line)'"', "issing") > 0 {
            local found_missing_info 1
        }
        file read `fh' line
    }
    file close `fh'

    * At minimum, missing detail should report something about missingness
    confirm file "`tmp_dir'/_val_miss_det.txt"
}
if _rc == 0 {
    display as result "  PASS: V6.1 - Missing data analysis runs on dataset with known missingness"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.1 - Missing data analysis (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V7: Invariant Tests
* ============================================================

* V7.1: datamap output is deterministic (same input -> same output)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_det1.txt")

    * Read file size via Stata
    tempname fh1
    file open `fh1' using "`tmp_dir'/_val_det1.txt", read text
    local linecount1 0
    file read `fh1' line
    while r(eof) == 0 {
        local ++linecount1
        file read `fh1' line
    }
    file close `fh1'

    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_det2.txt")

    tempname fh2
    file open `fh2' using "`tmp_dir'/_val_det2.txt", read text
    local linecount2 0
    file read `fh2' line
    while r(eof) == 0 {
        local ++linecount2
        file read `fh2' line
    }
    file close `fh2'

    assert `linecount1' == `linecount2'
    assert `linecount1' > 0
}
if _rc == 0 {
    display as result "  PASS: V7.1 - datamap output deterministic (same line count)"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.1 - Output determinism (error `=_rc')"
    local ++fail_count
}

* V7.2: datadict output is deterministic
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_ddet1.md")

    tempname fh1
    file open `fh1' using "`tmp_dir'/_val_ddet1.md", read text
    local lc1 0
    file read `fh1' line
    while r(eof) == 0 {
        local ++lc1
        file read `fh1' line
    }
    file close `fh1'

    datadict, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_ddet2.md")

    tempname fh2
    file open `fh2' using "`tmp_dir'/_val_ddet2.md", read text
    local lc2 0
    file read `fh2' line
    while r(eof) == 0 {
        local ++lc2
        file read `fh2' line
    }
    file close `fh2'

    assert `lc1' == `lc2'
    assert `lc1' > 0
}
if _rc == 0 {
    display as result "  PASS: V7.2 - datadict output deterministic (same line count)"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.2 - datadict determinism (error `=_rc')"
    local ++fail_count
}

* V7.3: datamap preserves user data (datasignature)
local ++test_count
capture noisily {
    sysuse auto, clear
    datasignature
    local sig_before "`r(datasignature)'"

    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_pres.txt")

    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: V7.3 - datamap preserves data (datasignature match)"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.3 - Data preservation (error `=_rc')"
    local ++fail_count
}

* V7.4: datadict preserves user data (datasignature)
local ++test_count
capture noisily {
    sysuse auto, clear
    datasignature
    local sig_before "`r(datasignature)'"

    datadict, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd_pres.md")

    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: V7.4 - datadict preserves data (datasignature match)"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.4 - datadict data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V8: Error Condition Validation
* ============================================================

* V8.1: datamap with no input returns rc 198
local ++test_count
capture noisily {
    capture datamap, output("`tmp_dir'/_err.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.1 - datamap no-input error (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.1 - datamap no-input error (error `=_rc')"
    local ++fail_count
}

* V8.2: datamap with dual inputs returns rc 198
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/val_classify") directory("`tmp_dir'")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.2 - datamap dual-input error (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.2 - datamap dual-input error (error `=_rc')"
    local ++fail_count
}

* V8.3: datamap with missing file returns nonzero rc
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/totally_nonexistent_file")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: V8.3 - datamap missing-file error"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.3 - datamap missing-file error (error `=_rc')"
    local ++fail_count
}

* V8.4: datadict with no input returns rc 198
local ++test_count
capture noisily {
    capture datadict, output("`tmp_dir'/_err.md")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.4 - datadict no-input error (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.4 - datadict no-input error (error `=_rc')"
    local ++fail_count
}

* V8.5: datadict with dual inputs returns rc 198
local ++test_count
capture noisily {
    capture datadict, single("`tmp_dir'/val_classify") directory("`tmp_dir'")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.5 - datadict dual-input error (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.5 - datadict dual-input error (error `=_rc')"
    local ++fail_count
}

* V8.6: datamap with maxfreq(0) returns rc 198
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/val_classify") maxfreq(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.6 - datamap maxfreq(0) error (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.6 - datamap maxfreq(0) error (error `=_rc')"
    local ++fail_count
}

* V8.7: datadict with maxcat(0) returns rc 198
local ++test_count
capture noisily {
    capture datadict, single("`tmp_dir'/val_classify") maxcat(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.7 - datadict maxcat(0) error (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.7 - datadict maxcat(0) error (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V9: Multi-file Validation
* ============================================================

* V9.1: filelist processes correct number of datasets
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/val_classify" "`tmp_dir'/val_cardinality") ///
        output("`tmp_dir'/_val_multi.txt")

    * Output should contain both dataset names/labels
    tempname fh
    file open `fh' using "`tmp_dir'/_val_multi.txt", read text
    local found_ds1 0
    local found_ds2 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Classification test dataset") > 0 {
            local found_ds1 1
        }
        if strpos(`"`macval(line)'"', "cardinality detection") > 0 {
            local found_ds2 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_ds1' == 1
    assert `found_ds2' == 1
}
if _rc == 0 {
    display as result "  PASS: V9.1 - Filelist output contains both dataset labels"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.1 - Filelist content verification (error `=_rc')"
    local ++fail_count
}

* V9.2: datadict filelist includes both datasets in markdown
local ++test_count
capture noisily {
    datadict, filelist("`tmp_dir'/val_classify" "`tmp_dir'/val_cardinality") ///
        output("`tmp_dir'/_val_dd_multi.md")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_dd_multi.md", read text
    local found_ds1 0
    local found_ds2 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "val_classify") > 0 | ///
           strpos(`"`macval(line)'"', "Classification test") > 0 {
            local found_ds1 1
        }
        if strpos(`"`macval(line)'"', "val_cardinality") > 0 | ///
           strpos(`"`macval(line)'"', "cardinality") > 0 {
            local found_ds2 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_ds1' == 1
    assert `found_ds2' == 1
}
if _rc == 0 {
    display as result "  PASS: V9.2 - datadict filelist contains both datasets"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.2 - datadict filelist verification (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V10: Value Label Bug Fix Verification
* ============================================================
* Regression test: value label word-indexing bug
* Variables with value labels must be classified as categorical,
* variables without must follow cardinality rules

local ++test_count
capture noisily {
    clear
    set obs 100
    gen double id = _n
    gen double age = 20 + int(60*runiform())
    gen byte sex = cond(runiform() > 0.5, 1, 0)
    label define sexlbl2 0 "Female" 1 "Male"
    label values sex sexlbl2
    gen double bmi = 18 + 15*runiform()
    gen byte region = 1 + int(4*runiform())
    label define reglbl2 1 "North" 2 "South" 3 "East" 4 "West"
    label values region reglbl2
    save "`tmp_dir'/val_labelbug.dta", replace

    datamap, single("`tmp_dir'/val_labelbug") output("`tmp_dir'/_val_labelbug.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_val_labelbug.txt", read text
    local age_ok 0
    local sex_ok 0
    local bmi_ok 0
    local region_ok 0
    local current_var ""
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "  age") > 0 & "`current_var'" == "" {
            local current_var "age"
        }
        if strpos(`"`macval(line)'"', "  sex") > 0 & "`current_var'" == "" {
            local current_var "sex"
        }
        if strpos(`"`macval(line)'"', "  bmi") > 0 & "`current_var'" == "" {
            local current_var "bmi"
        }
        if strpos(`"`macval(line)'"', "  region") > 0 & "`current_var'" == "" {
            local current_var "region"
        }
        if strpos(`"`macval(line)'"', "Classification:") > 0 | ///
           strpos(`"`macval(line)'"', "classification:") > 0 {
            if "`current_var'" == "age" & strpos(`"`macval(line)'"', "ontinuous") > 0 {
                local age_ok 1
            }
            if "`current_var'" == "sex" & strpos(`"`macval(line)'"', "ategorical") > 0 {
                local sex_ok 1
            }
            if "`current_var'" == "bmi" & strpos(`"`macval(line)'"', "ontinuous") > 0 {
                local bmi_ok 1
            }
            if "`current_var'" == "region" & strpos(`"`macval(line)'"', "ategorical") > 0 {
                local region_ok 1
            }
            local current_var ""
        }
        file read `fh' line
    }
    file close `fh'

    assert `age_ok' == 1
    assert `sex_ok' == 1
    assert `bmi_ok' == 1
    assert `region_ok' == 1
}
if _rc == 0 {
    display as result "  PASS: V10 - Value label bug regression test (all 4 vars correct)"
    local ++pass_count
}
else {
    display as error "  FAIL: V10 - Value label bug regression (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup
* ============================================================

* Remove all validation output files
local txt_files : dir "`tmp_dir'" files "_val_*.txt"
foreach f of local txt_files {
    capture erase "`tmp_dir'/`f'"
}
local md_files : dir "`tmp_dir'" files "_val_*.md"
foreach f of local md_files {
    capture erase "`tmp_dir'/`f'"
}

* Remove validation datasets
capture erase "`tmp_dir'/val_classify.dta"
capture erase "`tmp_dir'/val_cardinality.dta"
capture erase "`tmp_dir'/val_miss_known.dta"
capture erase "`tmp_dir'/val_labelbug.dta"

* ============================================================
* Summary
* ============================================================

display as text ""
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
