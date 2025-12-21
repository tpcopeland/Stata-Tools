*! datefix Version 1.0.1  2025/12/03
*! Original Author: Tim Copeland
*! 

/*
    DESCRIPTION:
    Given a variable name(s), optionally an input format, and an output format,
    'datefix' fixes the date string variable into a Stata date variable
    and saves it with the same name using the specified output format.

    SYNTAX:
    datefix [varlist] [, newvar(string) drop df(string) order(string) twodigit topyear(integer)]
            varlist:    a space-separated list of variables to be processed
            newvar:     renames new variable with specified name
            drop:       specifies to drop the original variable
                        only applies if newvar option is used, otherwise is redundant; however, will not trigger error.
            df:         specifies the output date format for the final Stata date variable.
                        Valid formats can be found in Stata's help on the 'format' command.
                        If empty, the CCYY/NN/DD will be applied.
            order:      specifies the order of date elements in the original variable.
                        Valid date element orders include "MDY", "YMD", and "DMY."
                        If an invalid option is given, an error message will occur.
            topyear:   specifies the latest year possible if a two digit year is used

*/

program define datefix
    version 16.0
    set varabbrev off
    syntax [varlist] [, newvar(string) drop df(string) order(string) topyear(string asis)]

	* Validation: Check if varlist is empty
	if "`varlist'" == "" {
		display as error "varlist required"
		exit 100
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
		* Check if it's a valid Stata daily date format
		* Daily date formats start with %td
		if substr("`df'", 1, 3) != "%td" {
			display as error "df(`df') is not a valid Stata daily date format"
			display as error "Daily date formats must start with %td (e.g., %tdCCYY/NN/DD)"
			display as error "For datetime formats, consider using different tools"
			exit 198
		}
		* Test the format validity
		tempvar testvar
		quietly generate double `testvar' = 22000
		capture format `testvar' `df'
		if _rc {
			display as error "Invalid date format: `df'"
			exit 198
		}
		drop `testvar'
	}

	*Error Message if topyear() contains non-integer value
	capture confirm integer number `topyear'
	if _rc!=0 & "`topyear'" != ""{
		display as error "topyear() must contain an integer"
		error 198
	}

	if "`topyear'" != "" {
		local topyear  ", `topyear'"
	}

	foreach var of varlist `varlist' {

		* Declare temporary variables
		tempvar new_date tmp_orig MDY YMD DMY MDY_ct YMD_ct DMY_ct

		* Count missing values before processing
		quietly count if missing(`var')
		local miss_before = r(N)

		capture confirm string variable `var'
		if _rc == 0 {
			*Datetime error - check any non-missing value for datetime indicators
			quietly count if !missing(`var')
			if r(N) > 0 {
				quietly count if strpos(`var', ":") > 0 & !missing(`var')
				if r(N) > 0 {
					display as error "Error: Variable `var' appears to contain datetime values"
					display as error "datefix does not support datetime variables"
					exit 198
				}
			}
		}

		*Newvar error
        if "`newvar'" == "`var'" {
            display as error "Error: New variable name same as old variable name. newvar() option not necessary. Please remove newvar() option."
            exit 198
        }

        *Drop Notes
        if "`drop'"=="drop" & "`newvar'" == "" {
            display as text "Note: 'drop' option is redundant when 'newvar()' is not used."
        }

        if "`drop'"=="drop" & "`newvar'" == "`var'" {
            display as text "Note: 'newvar()' specifies same name as original variable. Original variable will not be saved."
        }

        *Convert to date variable in specified ordering of Year, Month, and Day

		capture confirm string variable `var'
		if _rc == 0 {

			if "`order'"!="" {
				quietly capture gen `new_date' = date(`var',"`order'" `topyear')

				* Check if conversion created NEW missing values
				qui count if missing(`new_date') & !missing(`var')
				if r(N) > 0 {
					display as error "Specified ordering produced `r(N)' missing values from valid strings"
					display as error "Check ordering, year digits, and for non-date strings"
					display as error "If year is two-digit format, use topyear() option"
					qui drop `new_date'
					exit 198
				}
			}

			else {
				quietly{
					*Generate temporary copies of the original variable
					capture gen `tmp_orig' = `var'
					gen `new_date' = .
					*Generate dates for string in MDY format
					capture gen `MDY' = date(`var',"MDY" `topyear')
					capture egen `MDY_ct' = count(`MDY')
					*Generate dates for string in YMD format
					capture gen `YMD' = date(`var',"YMD" `topyear')
					capture egen `YMD_ct' = count(`YMD')
					*Generate dates for string in DMY format
					capture gen `DMY' = date(`var',"DMY" `topyear')
					capture egen `DMY_ct' = count(`DMY')
					*Select highest count for valid conversion
					capture replace `new_date' = `MDY' if `YMD_ct' <= `MDY_ct' & `DMY_ct' <= `MDY_ct'
					capture replace `new_date' = `YMD' if `MDY_ct' < `YMD_ct' & `DMY_ct' <= `YMD_ct'
					capture replace `new_date' = `DMY' if `MDY_ct' < `DMY_ct' & `YMD_ct' < `DMY_ct'

					* Determine which format was detected for display
					local detected_format "UNKNOWN"
					if `YMD_ct' <= `MDY_ct' & `DMY_ct' <= `MDY_ct' {
						local detected_format "MDY"
					}
					else if `MDY_ct' < `YMD_ct' & `DMY_ct' <= `YMD_ct' {
						local detected_format "YMD"
					}
					else if `MDY_ct' < `DMY_ct' & `YMD_ct' < `DMY_ct' {
						local detected_format "DMY"
					}

				}

				* Display auto-detected format
				display as text "Auto-detected date format: `detected_format'"

				qui count if missing(`new_date') & !missing(`var')
				if r(N) > 0 {
					display as error "Optimal ordering of Year, Month, and Day produced `r(N)' missing values."
					display as error "Check ordering, number of year digits, and for non-date strings."
					display as error "If year is in two digit format, use topyear() option."
					exit 198
				}
			}
		}
		else {
			* Variable is already numeric - apply date format
			* If newvar is specified, create a copy; otherwise just format the original
			if "`newvar'" != "" {
				quietly generate double `new_date' = `var'
				local lbl : variable label `var'
				quietly label var `new_date' "`lbl'"
			}
			* If newvar is not specified, new_date doesn't need to exist
			* The format will be applied directly to the original variable
		}

	quietly{

		*Order new variable after the original variable
		capture order `new_date', after(`var')

		*Save previous label and apply to new variable
		local lbl : variable label `var'
		capture label var `new_date' "`lbl'"

        *Apply drop option (only applies when newvar is specified)
		if "`drop'"=="drop" & "`newvar'"!=""{
			drop `var'
        }

        *Rename new variable to original variable name or specified newvar
		if "`newvar'"!="" {
			capture rename `new_date' `newvar'
		}
		else {
			capture confirm string variable `var'
			if _rc == 0 {
				drop `var'
			}
			capture rename `new_date' `var'
		}

		*Set date format if same variable name
		if "`df'"=="" &  "`newvar'"=="" {
			format %tdCCYY/NN/DD `var'
		}
		else if "`df'"!="" & "`newvar'"=="" {
			format `df' `var'
		}

		*Set date format if new variable name
		if "`df'"=="" & "`newvar'"!="" {
			format %tdCCYY/NN/DD `newvar'
		}

		else if "`df'"!="" & "`newvar'"!="" {
			format `df' `newvar'
		}

*END QUIETLY
	}

		* Count missing values after processing
		if "`newvar'" == "" {
			quietly count if missing(`var')
			local miss_after = r(N)
		}
		else {
			quietly count if missing(`newvar')
			local miss_after = r(N)
		}

		*Display ending Syntax
	if "`newvar'" == "" {
		display as text "Date variable `var' converted to date formatted numeric variable."
		display as text "	Original name retained and original `var' dropped, given `var' was a string; otherwise, date format applied."
	}

	if "`newvar'" != "" & "`drop'"=="" {
    	display as text "Date variable `var' converted to date formatted numeric variable: `newvar'."
		display as text "	Original `var' retained."
	}

	if "`newvar'" != "" & "`drop'"=="drop" {
    	display as text "Date variable `var' converted to date formatted numeric variable: `newvar'."
		display as text "	Original `var' dropped, given `var' was a string; otherwise, date format applied."
	}

		* Display missing value information
		if `miss_before' == `miss_after' {
			display as text "Missing values: `miss_before' before, `miss_after' after"
		}
		else {
			display as error "WARNING: Missing values: `miss_before' before, `miss_after' after"
		}

}

end
