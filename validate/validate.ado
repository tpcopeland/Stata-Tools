*! validate Version 1.0.0  2025/12/21
*! Data validation rules - define and run validation suites
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
    Define expected ranges, patterns, and cross-variable checks. Run validation
    suites and generate reports. Useful for registry data QC and ensuring
    data integrity before analysis.

SYNTAX:
    validate varlist [if] [in], [options]

    Or with rule specification:
    validate varname, range(numlist) [options]
    validate varname, values(numlist | string) [options]
    validate varname, pattern(string) [options]
    validate var1 var2, cross(condition) [options]

Options:
    range(numlist)      - Expected numeric range (min max)
    values(list)        - Expected values (numeric or string)
    pattern(string)     - Expected regex pattern for strings
    type(string)        - Expected data type: numeric, string, date
    nomiss              - No missing values allowed
    unique              - All values must be unique
    cross(condition)    - Cross-variable validation expression
    assert              - Stop execution on failure
    generate(name)      - Generate indicator for valid observations
    replace             - Allow replacing existing variable
    report              - Display detailed report
    xlsx(string)        - Export validation report to Excel
    sheet(string)       - Excel sheet name (default: "Validation")
    title(string)       - Report title

EXAMPLES:
    * Check age is in valid range
    validate age, range(0 120) nomiss

    * Check sex is valid category
    validate sex, values(0 1)

    * Check ID format with regex
    validate patient_id, pattern("^P[0-9]{6}$")

    * Check date ordering
    validate start_date end_date, cross(start_date <= end_date)

    * Run multiple validations with report
    validate age sex bmi, nomiss report xlsx(validation.xlsx)

STORED RESULTS:
    r(N)            - Number of observations checked
    r(n_valid)      - Number passing validation
    r(n_invalid)    - Number failing validation
    r(pct_valid)    - Percentage valid
    r(rules_pass)   - Number of rules passed
    r(rules_fail)   - Number of rules failed
*/

program define validate, rclass
    version 16.0
    set varabbrev off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist [if] [in], ///
        [RANge(numlist min=2 max=2) ///
         VALues(string asis) ///
         PATtern(string) ///
         TYPE(string) ///
         NOMiss ///
         UNIQue ///
         CROSS(string asis) ///
         ASSERT ///
         GENerate(name) ///
         replace ///
         REPort ///
         xlsx(string) ///
         sheet(string) ///
         TItle(string)]

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse, novarlist

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================
    if "`sheet'" == "" local sheet "Validation"
    if "`title'" == "" local title "Data Validation Report"

    * Validate Excel options
    if "`xlsx'" != "" {
        if !strmatch("`xlsx'", "*.xlsx") {
            display as error "Excel filename must have .xlsx extension"
            exit 198
        }
    }

    * =========================================================================
    * INITIALIZE RESULTS
    * =========================================================================
    local nvars : word count `varlist'
    local total_rules = 0
    local rules_passed = 0
    local rules_failed = 0

    tempname results_mat
    matrix `results_mat' = J(20, 5, .)
    matrix colnames `results_mat' = "N" "N_Valid" "N_Invalid" "Pct_Valid" "Pass"
    local rownames ""
    local rule_num = 0

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================
    display as text _n "{hline 75}"
    display as text "`title'"
    display as text "{hline 75}"
    display as text "Variables:     " as result "`varlist'"
    display as text "Observations:  " as result %10.0fc `N'
    display as text "{hline 75}"
    display ""

    * Table header
    display as text "{hline 75}"
    display as text %30s "Validation Rule" " {c |}" ///
        %10s "N" %10s "Valid" %10s "Invalid" %10s "Status"
    display as text "{hline 75}"

    * =========================================================================
    * VALIDATE EACH VARIABLE
    * =========================================================================
    foreach var of local varlist {
        local var_rules = 0
        local var_passed = 0

        * -----------------------------------------------------------------
        * TYPE CHECK
        * -----------------------------------------------------------------
        if "`type'" != "" {
            local rule_num = `rule_num' + 1
            local total_rules = `total_rules' + 1
            local var_rules = `var_rules' + 1

            local rule_name "`var': type=`type'"
            local rownames "`rownames' `rule_name'"

            capture confirm `type' variable `var'
            if _rc == 0 {
                local n_valid = `N'
                local n_invalid = 0
                local passed = 1
                local rules_passed = `rules_passed' + 1
                local var_passed = `var_passed' + 1
            }
            else {
                local n_valid = 0
                local n_invalid = `N'
                local passed = 0
                local rules_failed = `rules_failed' + 1
            }

            matrix `results_mat'[`rule_num', 1] = `N'
            matrix `results_mat'[`rule_num', 2] = `n_valid'
            matrix `results_mat'[`rule_num', 3] = `n_invalid'
            matrix `results_mat'[`rule_num', 4] = 100 * `n_valid' / `N'
            matrix `results_mat'[`rule_num', 5] = `passed'

            local status = cond(`passed', "PASS", "FAIL")
            local status_color = cond(`passed', "as result", "as error")
            display as text %30s abbrev("`rule_name'", 30) " {c |}" ///
                as result %10.0fc `N' %10.0fc `n_valid' %10.0fc `n_invalid' ///
                `status_color' %10s "`status'"
        }

        * -----------------------------------------------------------------
        * MISSING CHECK
        * -----------------------------------------------------------------
        if "`nomiss'" != "" {
            local rule_num = `rule_num' + 1
            local total_rules = `total_rules' + 1
            local var_rules = `var_rules' + 1

            local rule_name "`var': no missing"
            local rownames "`rownames' `rule_name'"

            quietly count if missing(`var') & `touse'
            local n_invalid = r(N)
            local n_valid = `N' - `n_invalid'
            local passed = (`n_invalid' == 0)

            if `passed' {
                local rules_passed = `rules_passed' + 1
                local var_passed = `var_passed' + 1
            }
            else {
                local rules_failed = `rules_failed' + 1
            }

            matrix `results_mat'[`rule_num', 1] = `N'
            matrix `results_mat'[`rule_num', 2] = `n_valid'
            matrix `results_mat'[`rule_num', 3] = `n_invalid'
            matrix `results_mat'[`rule_num', 4] = 100 * `n_valid' / `N'
            matrix `results_mat'[`rule_num', 5] = `passed'

            local status = cond(`passed', "PASS", "FAIL")
            local status_color = cond(`passed', "as result", "as error")
            display as text %30s abbrev("`rule_name'", 30) " {c |}" ///
                as result %10.0fc `N' %10.0fc `n_valid' %10.0fc `n_invalid' ///
                `status_color' %10s "`status'"
        }

        * -----------------------------------------------------------------
        * RANGE CHECK
        * -----------------------------------------------------------------
        if "`range'" != "" {
            local rule_num = `rule_num' + 1
            local total_rules = `total_rules' + 1
            local var_rules = `var_rules' + 1

            local min_val : word 1 of `range'
            local max_val : word 2 of `range'
            local rule_name "`var': [`min_val',`max_val']"
            local rownames "`rownames' `rule_name'"

            quietly count if (`var' < `min_val' | `var' > `max_val') & ///
                !missing(`var') & `touse'
            local n_invalid = r(N)
            quietly count if !missing(`var') & `touse'
            local n_nonmiss = r(N)
            local n_valid = `n_nonmiss' - `n_invalid'
            local passed = (`n_invalid' == 0)

            if `passed' {
                local rules_passed = `rules_passed' + 1
                local var_passed = `var_passed' + 1
            }
            else {
                local rules_failed = `rules_failed' + 1
            }

            matrix `results_mat'[`rule_num', 1] = `n_nonmiss'
            matrix `results_mat'[`rule_num', 2] = `n_valid'
            matrix `results_mat'[`rule_num', 3] = `n_invalid'
            matrix `results_mat'[`rule_num', 4] = 100 * `n_valid' / `n_nonmiss'
            matrix `results_mat'[`rule_num', 5] = `passed'

            local status = cond(`passed', "PASS", "FAIL")
            local status_color = cond(`passed', "as result", "as error")
            display as text %30s abbrev("`rule_name'", 30) " {c |}" ///
                as result %10.0fc `n_nonmiss' %10.0fc `n_valid' %10.0fc `n_invalid' ///
                `status_color' %10s "`status'"
        }

        * -----------------------------------------------------------------
        * VALUES CHECK
        * -----------------------------------------------------------------
        if `"`values'"' != "" {
            local rule_num = `rule_num' + 1
            local total_rules = `total_rules' + 1
            local var_rules = `var_rules' + 1

            local rule_name "`var': in values"
            local rownames "`rownames' `rule_name'"

            * Check if variable is string
            capture confirm string variable `var'
            if _rc == 0 {
                * String variable
                local val_list ""
                foreach v of local values {
                    if "`val_list'" == "" {
                        local val_list `""`v'""'
                    }
                    else {
                        local val_list `"`val_list', "`v'""'
                    }
                }

                quietly count if !inlist(`var', `val_list') & ///
                    !missing(`var') & `touse'
            }
            else {
                * Numeric variable
                quietly count if !inlist(`var', `values') & ///
                    !missing(`var') & `touse'
            }

            local n_invalid = r(N)
            quietly count if !missing(`var') & `touse'
            local n_nonmiss = r(N)
            local n_valid = `n_nonmiss' - `n_invalid'
            local passed = (`n_invalid' == 0)

            if `passed' {
                local rules_passed = `rules_passed' + 1
                local var_passed = `var_passed' + 1
            }
            else {
                local rules_failed = `rules_failed' + 1
            }

            matrix `results_mat'[`rule_num', 1] = `n_nonmiss'
            matrix `results_mat'[`rule_num', 2] = `n_valid'
            matrix `results_mat'[`rule_num', 3] = `n_invalid'
            matrix `results_mat'[`rule_num', 4] = 100 * `n_valid' / `n_nonmiss'
            matrix `results_mat'[`rule_num', 5] = `passed'

            local status = cond(`passed', "PASS", "FAIL")
            local status_color = cond(`passed', "as result", "as error")
            display as text %30s abbrev("`rule_name'", 30) " {c |}" ///
                as result %10.0fc `n_nonmiss' %10.0fc `n_valid' %10.0fc `n_invalid' ///
                `status_color' %10s "`status'"
        }

        * -----------------------------------------------------------------
        * PATTERN CHECK (regex)
        * -----------------------------------------------------------------
        if "`pattern'" != "" {
            local rule_num = `rule_num' + 1
            local total_rules = `total_rules' + 1
            local var_rules = `var_rules' + 1

            local rule_name "`var': pattern"
            local rownames "`rownames' `rule_name'"

            * Must be string variable
            capture confirm string variable `var'
            if _rc != 0 {
                display as error "pattern() requires string variable"
                exit 109
            }

            quietly count if !regexm(`var', "`pattern'") & ///
                !missing(`var') & `touse'
            local n_invalid = r(N)
            quietly count if !missing(`var') & `touse'
            local n_nonmiss = r(N)
            local n_valid = `n_nonmiss' - `n_invalid'
            local passed = (`n_invalid' == 0)

            if `passed' {
                local rules_passed = `rules_passed' + 1
                local var_passed = `var_passed' + 1
            }
            else {
                local rules_failed = `rules_failed' + 1
            }

            matrix `results_mat'[`rule_num', 1] = `n_nonmiss'
            matrix `results_mat'[`rule_num', 2] = `n_valid'
            matrix `results_mat'[`rule_num', 3] = `n_invalid'
            matrix `results_mat'[`rule_num', 4] = 100 * `n_valid' / `n_nonmiss'
            matrix `results_mat'[`rule_num', 5] = `passed'

            local status = cond(`passed', "PASS", "FAIL")
            local status_color = cond(`passed', "as result", "as error")
            display as text %30s abbrev("`rule_name'", 30) " {c |}" ///
                as result %10.0fc `n_nonmiss' %10.0fc `n_valid' %10.0fc `n_invalid' ///
                `status_color' %10s "`status'"
        }

        * -----------------------------------------------------------------
        * UNIQUE CHECK
        * -----------------------------------------------------------------
        if "`unique'" != "" {
            local rule_num = `rule_num' + 1
            local total_rules = `total_rules' + 1
            local var_rules = `var_rules' + 1

            local rule_name "`var': unique"
            local rownames "`rownames' `rule_name'"

            quietly {
                tempvar dup_count
                bysort `var': gen `dup_count' = _N if `touse' & !missing(`var')
                count if `dup_count' > 1 & `touse'
                local n_invalid = r(N)
                count if !missing(`var') & `touse'
                local n_nonmiss = r(N)
                drop `dup_count'
            }

            local n_valid = `n_nonmiss' - `n_invalid'
            local passed = (`n_invalid' == 0)

            if `passed' {
                local rules_passed = `rules_passed' + 1
                local var_passed = `var_passed' + 1
            }
            else {
                local rules_failed = `rules_failed' + 1
            }

            matrix `results_mat'[`rule_num', 1] = `n_nonmiss'
            matrix `results_mat'[`rule_num', 2] = `n_valid'
            matrix `results_mat'[`rule_num', 3] = `n_invalid'
            matrix `results_mat'[`rule_num', 4] = 100 * `n_valid' / `n_nonmiss'
            matrix `results_mat'[`rule_num', 5] = `passed'

            local status = cond(`passed', "PASS", "FAIL")
            local status_color = cond(`passed', "as result", "as error")
            display as text %30s abbrev("`rule_name'", 30) " {c |}" ///
                as result %10.0fc `n_nonmiss' %10.0fc `n_valid' %10.0fc `n_invalid' ///
                `status_color' %10s "`status'"
        }
    }

    * =========================================================================
    * CROSS-VARIABLE CHECK
    * =========================================================================
    if `"`cross'"' != "" {
        local rule_num = `rule_num' + 1
        local total_rules = `total_rules' + 1

        local rule_name "Cross: `cross'"
        local rownames "`rownames' cross_check"

        quietly count if !(`cross') & `touse'
        local n_invalid = r(N)
        local n_valid = `N' - `n_invalid'
        local passed = (`n_invalid' == 0)

        if `passed' {
            local rules_passed = `rules_passed' + 1
        }
        else {
            local rules_failed = `rules_failed' + 1
        }

        matrix `results_mat'[`rule_num', 1] = `N'
        matrix `results_mat'[`rule_num', 2] = `n_valid'
        matrix `results_mat'[`rule_num', 3] = `n_invalid'
        matrix `results_mat'[`rule_num', 4] = 100 * `n_valid' / `N'
        matrix `results_mat'[`rule_num', 5] = `passed'

        local status = cond(`passed', "PASS", "FAIL")
        local status_color = cond(`passed', "as result", "as error")
        display as text %30s abbrev("`rule_name'", 30) " {c |}" ///
            as result %10.0fc `N' %10.0fc `n_valid' %10.0fc `n_invalid' ///
            `status_color' %10s "`status'"
    }

    * =========================================================================
    * SUMMARY
    * =========================================================================
    display as text "{hline 75}"
    display ""
    display as text "Summary:"
    display as text "  Rules evaluated: " as result `total_rules'
    display as text "  Rules passed:    " as result `rules_passed' ///
        as text " (" as result %5.1f 100*`rules_passed'/`total_rules' as text "%)"
    display as text "  Rules failed:    " ///
        cond(`rules_failed' > 0, "as error", "as result") `rules_failed' ///
        as text " (" cond(`rules_failed' > 0, "as error", "as result") ///
        %5.1f 100*`rules_failed'/`total_rules' as text "%)"

    if `rules_failed' > 0 {
        display as error _n "WARNING: `rules_failed' validation rule(s) failed!"
    }
    else {
        display as result _n "All validation rules passed."
    }
    display as text "{hline 75}"

    * =========================================================================
    * GENERATE VALIDATION INDICATOR
    * =========================================================================
    if "`generate'" != "" {
        quietly {
            if "`replace'" != "" capture drop `generate'

            * For simple validations, generate pass/fail indicator
            gen byte `generate' = 1 if `touse'

            * Apply each rule
            if "`nomiss'" != "" {
                foreach var of local varlist {
                    replace `generate' = 0 if missing(`var') & `touse'
                }
            }

            if "`range'" != "" {
                local min_val : word 1 of `range'
                local max_val : word 2 of `range'
                foreach var of local varlist {
                    replace `generate' = 0 if (`var' < `min_val' | `var' > `max_val') & `touse'
                }
            }

            if `"`cross'"' != "" {
                replace `generate' = 0 if !(`cross') & `touse'
            }

            label variable `generate' "Validation passed"
        }

        quietly count if `generate' == 1 & `touse'
        display as text _n "Validation indicator created: " as result "`generate'"
        display as text "  Valid observations: " as result %10.0fc r(N)
    }

    * =========================================================================
    * ASSERT ON FAILURE
    * =========================================================================
    if "`assert'" != "" & `rules_failed' > 0 {
        display as error _n "Assertion failed: `rules_failed' validation rule(s) failed"
        exit 9
    }

    * =========================================================================
    * EXPORT TO EXCEL
    * =========================================================================
    if "`xlsx'" != "" {
        quietly {
            preserve

            * Create export dataset
            clear
            set obs `=`rule_num' + 2'

            gen str60 A = ""
            gen str15 B = ""
            gen str15 C = ""
            gen str15 D = ""
            gen str15 E = ""

            * Title
            replace A = "`title'" in 1

            * Header
            replace A = "Validation Rule" in 2
            replace B = "N Checked" in 2
            replace C = "N Valid" in 2
            replace D = "N Invalid" in 2
            replace E = "Status" in 2

            * Data rows
            tokenize `"`rownames'"'
            forvalues i = 1/`rule_num' {
                local row = `i' + 2
                replace A = "``i''" in `row'
                replace B = string(`results_mat'[`i', 1], "%10.0fc") in `row'
                replace C = string(`results_mat'[`i', 2], "%10.0fc") in `row'
                replace D = string(`results_mat'[`i', 3], "%10.0fc") in `row'
                local pass = `results_mat'[`i', 5]
                replace E = cond(`pass' == 1, "PASS", "FAIL") in `row'
            }

            export excel using "`xlsx'", sheet("`sheet'") sheetreplace

            restore

            display as text _n "Validation report exported to: " as result "`xlsx'"
        }
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================
    * Trim matrix to actual size
    if `rule_num' > 0 {
        matrix `results_mat' = `results_mat'[1..`rule_num', 1..5]
        matrix rownames `results_mat' = `rownames'
    }

    return scalar N = `N'
    return scalar n_rules = `total_rules'
    return scalar rules_passed = `rules_passed'
    return scalar rules_failed = `rules_failed'
    return scalar pct_passed = 100 * `rules_passed' / `total_rules'
    if `rule_num' > 0 {
        return matrix results = `results_mat'
    }
    return local varlist "`varlist'"

end
