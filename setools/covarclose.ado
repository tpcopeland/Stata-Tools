*! covarclose Version 1.0.0  2025/12/16
*! Extract covariate values closest to index date from longitudinal data
*! Part of the setools package
*!
*! Description:
*!   Extracts covariate values from longitudinal/panel data (like LISA) at the
*!   observation closest to an index date. Handles missing values by imputing
*!   from neighboring observations if requested.

program define covarclose, rclass
    version 16.0
    set varabbrev off

    syntax using/, IDvar(varname) INDexdate(varname) ///
        DATEvar(string) VARs(string) ///
        [YEARformat IMPute PREfer(string) MISSing(numlist) NOIsily]

    * Validate required variables in master data
    foreach v in `idvar' `indexdate' {
        capture confirm variable `v'
        if _rc {
            display as error "Variable '`v'' not found in master data"
            exit 111
        }
    }

    * Validate index date is numeric
    capture confirm numeric variable `indexdate'
    if _rc {
        display as error "Index date variable '`indexdate'' must be numeric (Stata date format)"
        exit 109
    }

    * Validate prefer option
    if "`prefer'" != "" & !inlist("`prefer'", "before", "after", "closest") {
        display as error "prefer() must be: before, after, or closest"
        exit 198
    }
    if "`prefer'" == "" local prefer "closest"

    * Validate file exists
    capture confirm file "`using'"
    if _rc {
        display as error "File not found: `using'"
        exit 601
    }

    if "`noisily'" != "" {
        display as text _newline "Extracting closest covariate values from `using'..."
    }

    * Preserve master data
    preserve

    * Save master with just ID and index date
    tempfile master_data
    quietly {
        keep `idvar' `indexdate'
        duplicates drop `idvar', force
        save `master_data'
    }

    * Load covariate file
    quietly use "`using'", clear

    * Verify ID variable in covariate file
    capture confirm variable `idvar'
    if _rc {
        display as error "ID variable '`idvar'' not found in covariate file"
        restore
        exit 111
    }

    * Handle date variable (could be year or date)
    if "`yearformat'" != "" {
        * Date variable is a year - convert to approximate date
        capture confirm variable `datevar'
        if _rc {
            display as error "Date variable '`datevar'' not found in covariate file"
            restore
            exit 111
        }
        tempvar covar_date
        quietly gen long `covar_date' = mdy(7, 1, `datevar')  // Mid-year approximation
    }
    else {
        * Date variable should already be a Stata date
        capture confirm variable `datevar'
        if _rc {
            display as error "Date variable '`datevar'' not found in covariate file"
            restore
            exit 111
        }
        capture confirm numeric variable `datevar'
        if _rc {
            display as error "Date variable '`datevar'' must be numeric"
            restore
            exit 109
        }
        local covar_date "`datevar'"
    }

    quietly {
        * Verify all requested variables exist
        foreach var of local vars {
            capture confirm variable `var'
            if _rc {
                display as error "Variable '`var'' not found in covariate file"
                restore
                exit 111
            }
        }

        * Keep only needed variables
        keep `idvar' `covar_date' `vars'

        * Merge with master to get index dates
        merge m:1 `idvar' using `master_data', keep(match) nogen

        * Handle missing values in covariates if impute requested
        if "`impute'" != "" & "`missing'" != "" {
            * Fill missing with values from adjacent observations
            foreach var of local vars {
                * Sort by id and date
                sort `idvar' `covar_date'

                * Get list of missing codes
                local miss_vals "`missing'"

                * Replace missing codes with system missing
                foreach m of local miss_vals {
                    replace `var' = . if `var' == `m'
                }

                * Fill forward then backward within person
                by `idvar': replace `var' = `var'[_n-1] if missing(`var') & _n > 1 & !missing(`var'[_n-1])
                gsort `idvar' -`covar_date'
                by `idvar': replace `var' = `var'[_n-1] if missing(`var') & _n > 1 & !missing(`var'[_n-1])
                sort `idvar' `covar_date'
            }
        }

        * Calculate distance from index date
        tempvar dist_from_index
        gen long `dist_from_index' = `covar_date' - `indexdate'

        * Apply preference for before/after/closest
        if "`prefer'" == "before" {
            * Prefer observations before or at index
            tempvar before_flag
            gen byte `before_flag' = (`dist_from_index' <= 0)
            egen byte has_before = max(`before_flag'), by(`idvar')

            * For those with before observations, keep only before
            drop if has_before == 1 & `before_flag' == 0
            drop has_before `before_flag'

            * Now take closest among remaining
            replace `dist_from_index' = abs(`dist_from_index')
        }
        else if "`prefer'" == "after" {
            * Prefer observations after or at index
            tempvar after_flag
            gen byte `after_flag' = (`dist_from_index' >= 0)
            egen byte has_after = max(`after_flag'), by(`idvar')

            * For those with after observations, keep only after
            drop if has_after == 1 & `after_flag' == 0
            drop has_after `after_flag'

            * Now take closest among remaining
            replace `dist_from_index' = abs(`dist_from_index')
        }
        else {
            * Closest - just use absolute distance
            replace `dist_from_index' = abs(`dist_from_index')
        }

        * Keep observation closest to index for each person
        bysort `idvar' (`dist_from_index'): keep if _n == 1

        * Clean up and keep only needed variables
        keep `idvar' `vars'
    }

    * Merge back to original master
    tempfile covar_closest
    quietly save `covar_closest'
    restore

    quietly merge 1:1 `idvar' using `covar_closest', keep(master match) nogen

    * Report results
    if "`noisily'" != "" {
        display as text _newline "Covariate Extraction Summary"
        display as text "{hline 50}"
        foreach var of local vars {
            quietly count if !missing(`var')
            local n_nonmiss = r(N)
            quietly count
            local n_total = r(N)
            display as text "  `var': " as result `n_nonmiss' as text " / " as result `n_total' as text " non-missing"
        }
        display as text "{hline 50}"
    }

    * Return values
    quietly count
    return scalar n_total = r(N)
    return local vars "`vars'"
    return local prefer "`prefer'"
end
