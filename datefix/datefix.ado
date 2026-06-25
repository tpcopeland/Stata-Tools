*! datefix Version 1.1.0  2026/06/25
*! Convert string date variables to numeric date formatted variables
*! Author: Timothy P Copeland, Karolinska Institutet

program define datefix
    version 16.0
    local _varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax varlist [, newvar(name) drop df(string) order(string) topyear(string) DIAGnose]

    * Validation: topyear must be an integer if specified
    if "`topyear'" != "" {
        capture confirm integer number `topyear'
        if _rc {
            display as error "topyear() must contain an integer"
            exit 198
        }
    }

    * Validation: Check if newvar() is used with multiple variables
    local nvars : word count `varlist'
    if `nvars' > 1 & "`newvar'" != "" {
        display as error "newvar() cannot be used with multiple variables"
        display as error "Use newvar() with a single variable only"
        exit 198
    }

    * Validation: Validate order() option if specified
    if "`order'" != "" {
        local order_upper = upper("`order'")
        if !inlist("`order_upper'", "MDY", "DMY", "YMD") {
            display as error "order(`order') not valid"
            display as error "Valid orders: MDY, DMY, YMD"
            exit 198
        }
    }

    * Validation: Check for observations in dataset
    quietly count
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }

    * Validation: Validate df() option if specified
    if "`df'" != "" {
        if substr("`df'", 1, 3) != "%td" {
            display as error "df(`df') is not a valid Stata daily date format"
            display as error "Daily date formats must start with %td (e.g., %tdCCYY/NN/DD)"
            exit 198
        }
        tempvar testvar
        quietly generate double `testvar' = 22000
        capture format `testvar' `df'
        if _rc {
            display as error "Invalid date format: `df'"
            exit 198
        }
    }

    * Build topyear argument for date() function
    local topyear_arg ""
    if "`topyear'" != "" {
        local topyear_arg ", `topyear'"
    }

    foreach var of varlist `varlist' {

        * Count missing values before processing
        quietly count if missing(`var')
        local miss_before = r(N)

        * Check if newvar name conflicts with existing variable
        if "`newvar'" != "" & "`newvar'" != "`var'" {
            capture confirm variable `newvar'
            if _rc == 0 {
                display as error "variable `newvar' already exists"
                exit 110
            }
        }

        * Check if newvar matches original variable name
        if "`newvar'" == "`var'" {
            display as error "newvar() name same as original variable; remove newvar() option"
            exit 198
        }

        * Note about redundant drop
        if "`drop'" == "drop" & "`newvar'" == "" {
            display as text "Note: 'drop' option is redundant when 'newvar()' is not used."
        }

        capture confirm string variable `var'
        local is_string = (_rc == 0)

        if `is_string' {
            * Check for datetime values
            quietly count if !missing(`var')
            if r(N) > 0 {
                quietly count if strpos(`var', ":") > 0 & !missing(`var')
                if r(N) > 0 {
                    if "`diagnose'" != "" {
                        tempvar badflag
                        quietly gen byte `badflag' = strpos(`var', ":") > 0 & !missing(`var')
                        _datefix_diagnose `var' `badflag'
                    }
                    display as error "variable `var' appears to contain datetime values"
                    display as error "datefix does not support datetime variables"
                    exit 198
                }
            }

            tempvar new_date

            if "`order_upper'" != "" {
                quietly gen double `new_date' = date(`var', "`order_upper'" `topyear_arg')

                quietly count if missing(`new_date') & !missing(`var')
                if r(N) > 0 {
                    local nbad = r(N)
                    if "`diagnose'" != "" {
                        tempvar badflag
                        quietly gen byte `badflag' = missing(`new_date') & !missing(`var')
                        _datefix_diagnose `var' `badflag'
                    }
                    display as error "Specified ordering produced `nbad' missing values from valid strings"
                    display as error "Check ordering, year digits, and for non-date strings"
                    display as error "If year is two-digit format, use topyear() option"
                    exit 198
                }
            }
            else {
                * Auto-detect: try all three orderings, pick the one with most valid parses
                tempvar MDY YMD DMY
                quietly {
                    gen double `MDY' = date(`var', "MDY" `topyear_arg')
                    gen double `YMD' = date(`var', "YMD" `topyear_arg')
                    gen double `DMY' = date(`var', "DMY" `topyear_arg')
                }

                quietly count if !missing(`MDY')
                local mdy_ct = r(N)
                quietly count if !missing(`YMD')
                local ymd_ct = r(N)
                quietly count if !missing(`DMY')
                local dmy_ct = r(N)

                * Select best ordering (MDY wins ties)
                local detected_format "MDY"
                quietly gen double `new_date' = `MDY'

                if `ymd_ct' > `mdy_ct' & `ymd_ct' >= `dmy_ct' {
                    local detected_format "YMD"
                    quietly replace `new_date' = `YMD'
                }
                else if `dmy_ct' > `mdy_ct' & `dmy_ct' > `ymd_ct' {
                    local detected_format "DMY"
                    quietly replace `new_date' = `DMY'
                }

                display as text "Auto-detected date format: `detected_format'"

                quietly count if missing(`new_date') & !missing(`var')
                if r(N) > 0 {
                    local nbad = r(N)
                    if "`diagnose'" != "" {
                        tempvar badflag
                        quietly gen byte `badflag' = missing(`new_date') & !missing(`var')
                        _datefix_diagnose `var' `badflag'
                    }
                    display as error "Optimal ordering produced `nbad' missing values."
                    display as error "Check ordering, number of year digits, and for non-date strings."
                    display as error "If year is in two digit format, use topyear() option."
                    exit 198
                }
            }

            * Place new variable after original
            order `new_date', after(`var')

            * Transfer label
            local lbl : variable label `var'
            label var `new_date' `"`lbl'"'

            if "`newvar'" != "" {
                rename `new_date' `newvar'
                if "`drop'" == "drop" {
                    drop `var'
                }
            }
            else {
                drop `var'
                rename `new_date' `var'
            }
        }
        else {
            * Variable is already numeric — just apply format (or copy if newvar)
            if "`newvar'" != "" {
                quietly generate double `newvar' = `var'
                local lbl : variable label `var'
                label var `newvar' `"`lbl'"'
                order `newvar', after(`var')
                if "`drop'" == "drop" {
                    drop `var'
                }
            }
        }

        * Apply date format
        local target_var = cond("`newvar'" != "", "`newvar'", "`var'")
        local date_fmt  = cond("`df'" != "", "`df'", "%tdCCYY/NN/DD")
        format `date_fmt' `target_var'

        * Count missing values after processing
        quietly count if missing(`target_var')
        local miss_after = r(N)

        * Display summary
        if "`newvar'" == "" {
            display as text "Variable `var' converted to numeric date."
        }
        else if "`drop'" == "drop" {
            display as text "Variable `var' converted to numeric date: `newvar'. Original dropped."
        }
        else {
            display as text "Variable `var' converted to numeric date: `newvar'. Original retained."
        }

        if `miss_before' == `miss_after' {
            display as text "Missing values: `miss_before' before, `miss_after' after"
        }
        else {
            display as error "WARNING: Missing values changed: `miss_before' before, `miss_after' after"
        }
    }

    }
    local rc = _rc
    set varabbrev `_varabbrev'
    if `rc' exit `rc'
end

* Diagnostic listing for diagnose option: tabulates the distinct string values
* that could not be converted, with frequencies and offending observation rows.
* Non-destructive (all working variables are tempvars); callers invoke this just
* before aborting, so it never alters the user's data.
capture program drop _datefix_diagnose
program define _datefix_diagnose
    version 16.0
    args var bad

    quietly count if `bad'
    local nbad = r(N)
    if `nbad' == 0 exit

    tempvar grp obsnum vlen
    quietly generate long `obsnum' = _n
    quietly egen `grp' = group(`var') if `bad'
    quietly summarize `grp', meanonly
    local ndistinct = r(max)

    quietly generate `vlen' = strlen(`var') if `bad'
    quietly summarize `vlen', meanonly
    local w = r(max)
    if `w' < 5  local w = 5
    if `w' > 30 local w = 30

    display as text ""
    display as text "Unconvertible values in {res:`var'} (`nbad' observation(s), `ndistinct' distinct):"
    display as text %-`w's "value" "   " %6s "freq" "   " "obs"
    display as text "{hline `=`w' + 3 + 6 + 3 + 24'}"

    local gmax = `ndistinct'
    if `gmax' > 50 local gmax = 50

    forvalues g = 1/`gmax' {
        quietly levelsof `var' if `grp' == `g', local(thisval) clean
        quietly count if `grp' == `g'
        local f = r(N)
        quietly levelsof `obsnum' if `grp' == `g', local(allrows) clean
        local rowct : word count `allrows'
        local shown ""
        local i = 0
        foreach r of local allrows {
            local ++i
            if `i' > 10 continue, break
            local shown = cond("`shown'" == "", "`r'", "`shown', `r'")
        }
        if `rowct' > 10 local shown "`shown', ... (+`=`rowct' - 10' more)"
        local vshow = substr(`"`thisval'"', 1, `w')
        display as text %-`w's `"`vshow'"' "   " %6.0f `f' "   " "`shown'"
    }

    if `ndistinct' > 50 {
        display as text "... and `=`ndistinct' - 50' more distinct value(s) not shown."
    }
end
