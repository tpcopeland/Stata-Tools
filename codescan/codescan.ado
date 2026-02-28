*! codescan Version 1.0.1  2026/02/27
*! Scan wide-format code variables for pattern matches and collapse to patient-level
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())
*! Requires: Stata 16.0+

/*
DESCRIPTION:
    Scans wide-format code variables (dx1-dx30, proc1-proc20, etc.) for
    pattern matches using regex or prefix matching. Generates binary
    indicators for each condition, optionally applies time windows, and
    collapses to patient-level summaries with date statistics.

    Works with any string code system: ICD, KVA, CPT, ATC, OPCS, etc.

SYNTAX:
    codescan varlist [if] [in], DEFine(string asis)
        [ID(varname) DATE(varname) REFDate(varname)
         LOOKBack(integer) LOOKForward(integer) INCLusive
         EARLIESTdate LATESTdate COUNTdate
         LABel(string asis) COLLapse MODe(string) REPlace NOIsily]

EXAMPLES:
    * Row-level indicators
    codescan dx1-dx30, define(dm2 "E11" | obesity "E66")

    * Full collapse with time window
    codescan dx1-dx30, id(lopnr) date(visit_dt) refdate(index_date) ///
        define(dm2 "E11" | htn "I1[0-35]") lookback(1825) collapse

STORED RESULTS:
    r(N)            - Number of observations (post-collapse if collapsed)
    r(n_conditions) - Number of conditions defined
    r(conditions)   - Space-separated condition names
    r(varlist)      - Variables scanned
    r(mode)         - Matching mode (regex or prefix)
    r(lookback)     - Lookback days (if specified)
    r(lookforward)  - Lookforward days (if specified)
    r(refdate)      - Reference date variable (if specified)
    r(summary)      - Matrix of counts and prevalences
*/

program define codescan, rclass
    version 16.0
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist [if] [in] , DEFine(string asis) ///
        [ID(varname) DATE(varname) REFDate(varname) ///
         LOOKBack(integer -1) LOOKForward(integer -1) INCLusive ///
         EARLIESTdate LATESTdate COUNTdate ///
         LABel(string asis) COLLapse MODe(string) REPlace NOIsily]

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================

    * All varlist variables must be string
    foreach var of local varlist {
        capture confirm string variable `var'
        if _rc {
            display as error "`var' is not a string variable"
            display as error "codescan requires string variables; use tostring first if needed"
            exit 109
        }
    }

    * Mode validation
    if "`mode'" == "" local mode "regex"
    if "`mode'" != "regex" & "`mode'" != "prefix" {
        display as error "mode() must be {bf:regex} or {bf:prefix}"
        exit 198
    }

    * Time window validation
    local has_lookback = (`lookback' != -1)
    local has_lookfwd  = (`lookforward' != -1)

    if `has_lookback' & `lookback' < 0 {
        display as error "lookback() must be a non-negative integer"
        exit 198
    }
    if `has_lookfwd' & `lookforward' < 0 {
        display as error "lookforward() must be a non-negative integer"
        exit 198
    }

    if (`has_lookback' | `has_lookfwd') & ("`date'" == "" | "`refdate'" == "") {
        display as error "lookback() and lookforward() require both date() and refdate()"
        exit 198
    }

    * Validate date/refdate are numeric
    if "`date'" != "" {
        confirm numeric variable `date'
    }
    if "`refdate'" != "" {
        confirm numeric variable `refdate'
    }

    * Collapse validation
    if "`collapse'" != "" & "`id'" == "" {
        display as error "collapse requires id()"
        exit 198
    }

    * Date summary options require date + collapse
    if ("`earliestdate'" != "" | "`latestdate'" != "" | "`countdate'" != "") {
        if "`date'" == "" {
            display as error "earliestdate, latestdate, and countdate require date()"
            exit 198
        }
        if "`collapse'" == "" {
            display as error "earliestdate, latestdate, and countdate require collapse"
            exit 198
        }
    }

    * Inclusive requires lookback or lookforward
    if "`inclusive'" != "" & !`has_lookback' & !`has_lookfwd' {
        display as error "inclusive requires lookback() or lookforward()"
        exit 198
    }

    * =========================================================================
    * PARSE DEFINE()
    * =========================================================================
    * tokenize respects quotes: "I2[0-5]|I6[0-9]" stays as one token
    * Unquoted | becomes a separate token (space-separated)
    * Format: name "pattern" | name "pattern" | ...
    tokenize `"`define'"'

    local n_conditions = 0
    local all_names ""
    local i = 1
    while `"``i''"' != "" {
        * Skip | delimiter tokens
        if `"``i''"' == "|" {
            local ++i
            continue
        }

        * Expect: name pattern
        local ++n_conditions
        local def_name_`n_conditions' `"``i''"'
        local ++i
        if `"``i''"' == "" | `"``i''"' == "|" {
            display as error "define(): condition `def_name_`n_conditions'' has no pattern"
            display as error "  Expected format: define(name {c 34}pattern{c 34} | name2 {c 34}pattern2{c 34})"
            exit 198
        }
        local def_pattern_`n_conditions' `"``i''"'
        local ++i
        local all_names "`all_names' `def_name_`n_conditions''"
    }
    local all_names = trim("`all_names'")

    if `n_conditions' == 0 {
        display as error "define() is empty"
        exit 198
    }

    * Validate define names: valid Stata names, <=26 chars, unique
    forvalues i = 1/`n_conditions' {
        local nm "`def_name_`i''"
        capture confirm name `nm'
        if _rc {
            display as error "define(): `nm' is not a valid Stata name"
            exit 198
        }
        if strlen("`nm'") > 26 {
            display as error "define(): `nm' exceeds 26 characters (need room for _first/_count suffix)"
            exit 198
        }
        * Check uniqueness
        forvalues j = 1/`=`i'-1' {
            if "`nm'" == "`def_name_`j''" {
                display as error "define(): duplicate condition name `nm'"
                exit 198
            }
        }
    }

    * Check output variable names don't already exist (unless replace)
    if "`replace'" == "" {
        forvalues i = 1/`n_conditions' {
            local nm "`def_name_`i''"
            capture confirm new variable `nm'
            if _rc {
                display as error "variable `nm' already exists; use replace option"
                exit 110
            }
            if "`collapse'" != "" {
                if "`earliestdate'" != "" {
                    capture confirm new variable `nm'_first
                    if _rc {
                        display as error "variable `nm'_first already exists; use replace option"
                        exit 110
                    }
                }
                if "`latestdate'" != "" {
                    capture confirm new variable `nm'_last
                    if _rc {
                        display as error "variable `nm'_last already exists; use replace option"
                        exit 110
                    }
                }
                if "`countdate'" != "" {
                    capture confirm new variable `nm'_count
                    if _rc {
                        display as error "variable `nm'_count already exists; use replace option"
                        exit 110
                    }
                }
            }
        }
    }

    * =========================================================================
    * PARSE LABEL()
    * =========================================================================
    local n_labels = 0
    if `"`label'"' != "" {
        * Split on \ delimiter using strpos (tokenize can't handle \ reliably)
        local lab_remaining `"`label'"'
        while `"`lab_remaining'"' != "" {
            local bspos = strpos(`"`lab_remaining'"', "\")
            if `bspos' > 0 {
                local lab_segment = substr(`"`lab_remaining'"', 1, `bspos' - 1)
                local lab_remaining = substr(`"`lab_remaining'"', `bspos' + 1, .)
            }
            else {
                local lab_segment `"`lab_remaining'"'
                local lab_remaining ""
            }
            local lab_segment = strtrim(`"`lab_segment'"')
            if `"`lab_segment'"' == "" continue

            * gettoken: first token = name, remaining = label text
            gettoken lab_nm lab_txt : lab_segment
            * gettoken strips quotes from the extracted token but NOT from
            * the remaining part. Strip outer quotes from label text.
            local lab_txt = strtrim(`"`lab_txt'"')
            if substr(`"`lab_txt'"', 1, 1) == `"""' {
                local lab_txt = substr(`"`lab_txt'"', 2, strlen(`"`lab_txt'"') - 2)
            }

            if "`lab_nm'" == "" | `"`lab_txt'"' == "" {
                display as error "label(): each entry needs a name and label text"
                exit 198
            }

            local ++n_labels
            local lab_name_`n_labels' "`lab_nm'"
            local lab_label_`n_labels' `"`lab_txt'"'
        }

        * Validate label names match define names
        forvalues j = 1/`n_labels' {
            local found = 0
            forvalues k = 1/`n_conditions' {
                if "`lab_name_`j''" == "`def_name_`k''" {
                    local found = 1
                }
            }
            if !`found' {
                display as error `"label(): `lab_name_`j'' does not match any condition in define()"'
                exit 198
            }
        }
    }

    * =========================================================================
    * MARK SAMPLE & TIME WINDOW
    * =========================================================================
    * Note: cannot use marksample — string asis puts quotes in `0' which
    * breaks marksample's parser. Use mark for if/in only.
    * Do NOT markout the varlist: empty strings in code variables are expected.
    tempvar touse
    mark `touse' `if' `in'

    local include_ref = ("`inclusive'" != "" | (`has_lookback' & `has_lookfwd'))

    if `has_lookback' | `has_lookfwd' {
        quietly replace `touse' = 0 if missing(`date') | missing(`refdate')
    }

    if `has_lookback' & `has_lookfwd' {
        * Both: [refdate - lookback, refdate + lookforward] — always inclusive
        quietly replace `touse' = 0 if `date' < `refdate' - `lookback'
        quietly replace `touse' = 0 if `date' > `refdate' + `lookforward'
    }
    else if `has_lookback' {
        * Lookback only
        quietly replace `touse' = 0 if `date' < `refdate' - `lookback'
        if `include_ref' {
            quietly replace `touse' = 0 if `date' > `refdate'
        }
        else {
            quietly replace `touse' = 0 if `date' >= `refdate'
        }
    }
    else if `has_lookfwd' {
        * Lookforward only
        quietly replace `touse' = 0 if `date' > `refdate' + `lookforward'
        if `include_ref' {
            quietly replace `touse' = 0 if `date' < `refdate'
        }
        else {
            quietly replace `touse' = 0 if `date' <= `refdate'
        }
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }
    local N = r(N)

    * =========================================================================
    * CREATE ROW-LEVEL INDICATORS
    * =========================================================================
    quietly {
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            local pattern `"`def_pattern_`i''"'

            if "`replace'" != "" {
                capture drop `name'
                if "`collapse'" != "" {
                    if "`earliestdate'" != "" capture drop `name'_first
                    if "`latestdate'" != ""   capture drop `name'_last
                    if "`countdate'" != ""    capture drop `name'_count
                }
            }
            gen byte `name' = 0

            if "`noisily'" != "" {
                noisily display as text "  Scanning `name': " _continue
            }

            local n_varscanned = 0
            foreach var of local varlist {
                if "`mode'" == "prefix" {
                    * Prefix mode: split pattern on | for multi-prefix
                    _codescan_prefix_scan `name' `var' `touse' `"`pattern'"'
                }
                else {
                    * Regex mode — auto-anchor with ^()
                    replace `name' = 1 if regexm(`var', `"^(`pattern')"') & `touse' & `name' == 0
                }
                local ++n_varscanned
            }

            if "`noisily'" != "" {
                count if `name' == 1
                noisily display as result r(N) as text " matches across `n_varscanned' variables"
            }
        }
    }

    * =========================================================================
    * PREPARE DATE VARIABLES (PRE-COLLAPSE)
    * =========================================================================
    if "`collapse'" != "" & "`date'" != "" {
        local datefmt : format `date'

        quietly {
            forvalues i = 1/`n_conditions' {
                local name "`def_name_`i''"

                if "`earliestdate'" != "" | "`latestdate'" != "" {
                    tempvar date_`i'
                    gen double `date_`i'' = `date' if `name' == 1 & `touse'
                }

                if "`countdate'" != "" {
                    tempvar tag_`i'
                    sort `id' `date'
                    by `id' `date': gen byte `tag_`i'' = (_n == 1) & (`name' == 1) & `touse'
                }
            }
        }
    }

    * =========================================================================
    * COLLAPSE
    * =========================================================================
    if "`collapse'" != "" {
        * Build collapse expression
        local collapse_expr ""
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            local collapse_expr "`collapse_expr' (max) `name'"

            if "`earliestdate'" != "" {
                local collapse_expr "`collapse_expr' (min) `name'_first=`date_`i''"
            }
            if "`latestdate'" != "" {
                local collapse_expr "`collapse_expr' (max) `name'_last=`date_`i''"
            }
            if "`countdate'" != "" {
                local collapse_expr "`collapse_expr' (sum) `name'_count=`tag_`i''"
            }
        }

        collapse `collapse_expr', by(`id')

        * Post-collapse formatting
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            recast byte `name'

            if "`earliestdate'" != "" {
                format `name'_first `datefmt'
            }
            if "`latestdate'" != "" {
                format `name'_last `datefmt'
            }
            if "`countdate'" != "" {
                recast long `name'_count
            }
        }

        quietly count
        local N_collapsed = r(N)
    }

    * =========================================================================
    * APPLY LABELS
    * =========================================================================
    forvalues i = 1/`n_conditions' {
        local name "`def_name_`i''"
        local lbl ""

        forvalues j = 1/`n_labels' {
            if "`lab_name_`j''" == "`name'" {
                local lbl `"`lab_label_`j''"'
            }
        }

        if `"`lbl'"' != "" {
            label variable `name' `"`lbl'"'
            if "`earliestdate'" != "" {
                label variable `name'_first `"Earliest `lbl' Date"'
            }
            if "`latestdate'" != "" {
                label variable `name'_last `"Latest `lbl' Date"'
            }
            if "`countdate'" != "" {
                label variable `name'_count `"`lbl' Date Count"'
            }
        }
    }

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================
    local nvars : word count `varlist'
    if "`collapse'" != "" {
        local N_display = `N_collapsed'
    }
    else {
        local N_display = `N'
    }

    display as text _n "codescan: `n_conditions' condition" ///
        cond(`n_conditions' > 1, "s", "") ", `nvars' variable" ///
        cond(`nvars' > 1, "s", "")

    if `has_lookback' & `has_lookfwd' {
        display as text "Window: `lookback' days before to `lookforward' days after `refdate' (inclusive)"
    }
    else if `has_lookback' {
        local incl_txt = cond(`include_ref', " (inclusive)", "")
        display as text "Window: `lookback' days before `refdate'`incl_txt'"
    }
    else if `has_lookfwd' {
        local incl_txt = cond(`include_ref', " (inclusive)", "")
        display as text "Window: `lookforward' days after `refdate'`incl_txt'"
    }

    display as text ""
    display as text "  Condition" _col(24) %9s "Matches" _col(36) %10s "Prevalence"
    display as text "  {hline 44}"

    tempname summary
    matrix `summary' = J(`n_conditions', 2, .)
    local rnames ""

    forvalues i = 1/`n_conditions' {
        local name "`def_name_`i''"
        quietly count if `name' == 1
        local n_match = r(N)
        local pct = `n_match' / `N_display' * 100
        display as text "  `name'" _col(24) as result %9.0fc `n_match' ///
            _col(36) as result %9.1f `pct' as text "%"

        matrix `summary'[`i', 1] = `n_match'
        matrix `summary'[`i', 2] = `pct'
        local rnames "`rnames' `name'"
    }

    matrix colnames `summary' = count prevalence
    matrix rownames `summary' = `rnames'

    if "`collapse'" != "" {
        display as text _n "  Collapsed to " as result %10.0fc `N_collapsed' ///
            as text " unique `id' values"
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================
    return scalar N = `N_display'
    return scalar n_conditions = `n_conditions'
    return local conditions "`all_names'"
    return local varlist "`varlist'"
    return local mode "`mode'"
    if `has_lookback'              return scalar lookback = `lookback'
    if `has_lookfwd'               return scalar lookforward = `lookforward'
    if `has_lookback' | `has_lookfwd' return local refdate "`refdate'"
    return matrix summary = `summary'

end

* =============================================================================
* SUBROUTINE: Prefix scanning with | splitting
* =============================================================================
capture program drop _codescan_prefix_scan
program define _codescan_prefix_scan
    version 16.0
    set varabbrev off
    set more off
    args indicator var touse pattern

    * Split pattern on | using strpos (patterns have no embedded quotes)
    local remaining `"`pattern'"'
    while `"`remaining'"' != "" {
        local pos = strpos(`"`remaining'"', "|")
        if `pos' > 0 {
            local subpat = substr(`"`remaining'"', 1, `pos' - 1)
            local remaining = substr(`"`remaining'"', `pos' + 1, .)
        }
        else {
            local subpat `"`remaining'"'
            local remaining ""
        }
        local subpat = strtrim("`subpat'")
        if "`subpat'" == "" continue
        local len = strlen("`subpat'")
        quietly replace `indicator' = 1 if substr(`var', 1, `len') == "`subpat'" & `touse' & `indicator' == 0
    }
end
