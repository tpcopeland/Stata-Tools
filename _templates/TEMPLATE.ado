*! TEMPLATE Version 1.0.0  YYYY/MM/DD
*! Brief description of what the command does
*! Author: Your Name
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  TEMPLATE varlist [if] [in], required_option(varname) [options]

Required options:
  required_option(varname)  - Description of what this option does

Optional options:
  option1                   - Description (default: value)
  option2(numlist)          - Description
  generate(newvar)          - Name for output variable

See help TEMPLATE for complete documentation
*/

program define TEMPLATE, rclass
    version 18.0
    set varabbrev off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric) [if] [in] , ///
        REQuired_option(varname) ///
        [option1 ///
         option2(numlist) ///
         GENerate(name) ///
         replace]

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    markout `touse' `required_option'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================
    * Validate required_option is numeric
    capture confirm numeric variable `required_option'
    if _rc {
        display as error "required_option() must be a numeric variable"
        exit 109
    }

    * Validate generate variable doesn't exist (unless replace)
    if "`generate'" != "" & "`replace'" == "" {
        capture confirm new variable `generate'
        if _rc {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
    }

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================
    if "`generate'" == "" {
        local generate "TEMPLATE_result"
    }

    * =========================================================================
    * MAIN COMPUTATION
    * =========================================================================
    * Use preserve/restore if modifying data
    * Parse before preserve to catch errors early

    preserve

    quietly {
        keep if `touse'

        * ------------------------------------------------------------------
        * Your main computation logic goes here
        * ------------------------------------------------------------------

        * Example: Create output variable
        gen double `generate' = .

        * Example: Loop over observations
        forvalues i = 1/`=_N' {
            * Process each observation
        }

        * Example: Use tempvar for intermediate calculations
        tempvar temp1 temp2
        gen double `temp1' = .
        gen double `temp2' = .

    }

    restore

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================
    return scalar N = `N'
    return local varlist "`varlist'"
    return local generate "`generate'"

    * =========================================================================
    * DISPLAY OUTPUT
    * =========================================================================
    display as text _n "{hline 60}"
    display as text "TEMPLATE Results"
    display as text "{hline 60}"
    display as text "Observations:     " as result %10.0fc `N'
    display as text "Output variable:  " as result "`generate'"
    display as text "{hline 60}"

end

* =============================================================================
* HELPER SUBROUTINES (if needed)
* =============================================================================

capture program drop _TEMPLATE_helper
program define _TEMPLATE_helper
    * Helper program logic
end
