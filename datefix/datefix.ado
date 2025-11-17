*! Datefix | Version 2.1
*! Original Author: Tim Copeland
*! Updated on: 2 October 2025

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

program define datefix, rclass
    syntax [varlist] [, newvar(string) drop df(string) order(string) topyear(string asis)]

	*Error Message if topyear() contains non-integer value 
	capture confirm integer number `topyear'
	if _rc!=0 & "`topyear'" != ""{
		di in re "topyear() must contain an integer"
		error 198
	}

	if missing("`topyear'"){
		local topyear  ""
	}

	if !missing("`topyear'"){
		local topyear  ", `topyear'"
	}

	foreach var of varlist `varlist' {

		* Count missing values before processing
		quietly count if missing(`var')
		local miss_before = r(N)

		capture confirm string variable `var'
		if _rc == 0 {
			*Datetime error 
			if strpos(`var', ":"){
				di in re "Error: Input variable `var' appears to be a datetime variable."
				di in re "datefix does not support datetime variables."
				di in re "If you believe this message is in error, check for timestamps or colons in `var'."
				exit 198
			}
		}

        * Validate varlist
        if strpos("`varlist'", " ") > 0 & "`newvar'" != "" {
            di in re "Error: 'newvar()' can only be specified when a single variable is used." 
			di in re "For a list of variables, new variables will replace original variables."
            exit 198
        }

		*Newvar error 
        if "`newvar'" == "`var'" {
            di in re "Error: New variable name same as old variable name. newvar() option not necessary. Please remove newvar() option."
            exit 198
        }
        
        *Drop Notes
        if "`drop'"=="drop" & "`newvar'" == "" {
            di "Note: 'drop' option is redundant when 'newvar()' is not used."
        }
        
        if "`drop'"=="drop" & "`newvar'" == "`var'" {
            di "Note: 'newvar()' specifies same name as original variable. Original variable will not be saved."
        }

        *Convert to date variable in specified ordering of Year, Month, and Day
		
		capture confirm string variable `var'
		if _rc == 0 {

			if "`order'"!="" {
				quietly capture gen new = date(`var',"`order'" `topyear') 

				if missing(new) & !missing(`var'){
					di in re "Specified ordering of Year, Month, and Day producing new missingness."
					di in re "Check ordering, number of year digits, and for non-date strings."
					di in re "If year is in two digit format, use topyear() option."
					quietly drop new 
					exit 198
				}
			}
				
			else {
				quietly{				
					*Generate temporary copies of the original variable
					capture gen tmp_orig = `var' 
					gen new = .
					*Generate dates for string in MDY format
					capture gen MDY = date(`var',"MDY" `topyear')
					capture egen MDY_ct = count(MDY) 
					*Generate dates for string in YMD format
					capture gen YMD = date(`var',"YMD" `topyear')
					capture egen YMD_ct = count(YMD)
					*Generate dates for string in DMY format
					capture gen DMY = date(`var',"DMY" `topyear')
					capture egen DMY_ct = count(DMY) 
					*Select highest count for valid conversion
					capture replace new = MDY if YMD_ct <= MDY_ct & DMY_ct <= MDY_ct 
					capture replace new = YMD if MDY_ct < YMD_ct & DMY_ct <= YMD_ct 
					capture replace new = DMY if MDY_ct < DMY_ct & YMD_ct < DMY_ct
					*Drop temporary variable  
					foreach tmp in MDY YMD DMY MDY_ct YMD_ct DMY_ct tmp_orig{
						capture drop `tmp' 
					}       

				}

				if missing(new) & !missing(`var'){
					di in re "Optimal ordering of Year, Month, and Day producing missing values."
					di in re "Check ordering, number of year digits, and for non-date strings."
					di in re "If year is in two digit format, use topyear() option."
					quietly drop new 
					exit 198
				}

				*Retrieve original variable if original variable was a date 
				quietly capture replace new = tmp_orig if new == . 
			}
		}

	quietly{

		*Order new variable after the original variable 
		capture order new, after(`var')
        
		*Save previous label and apply to new variable
		local lbl : variable label `var' 
		capture label var new "`lbl'" 

        *Apply drop option
		if "`drop'"=="drop"{
			drop `var'
        }
            
        *Rename new variable to original variable name or specified newvar
		if "`newvar'"!="" {
			capture rename new `newvar'
		}
		else {
			capture confirm string variable `var'
			if _rc == 0 {
				drop `var'
			}
			capture rename new `var'
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
		
	quietly capture drop new 

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
		di "Date variable `var' converted to date formatted numeric variable."
		di "	Original name retained and original `var' dropped, given `var' was a string; otherwise, date format applied."
	}

	if "`newvar'" != "" & "`drop'"=="" {
    	di "Date variable `var' converted to date formatted numeric variable: `newvar'."
		di "	Original `var' retained."
	}

	if "`newvar'" != "" & "`drop'"=="drop" {
    	di "Date variable `var' converted to date formatted numeric variable: `newvar'."
		di "	Original `var' dropped, given `var' was a string; otherwise, date format applied."
	}

		* Display missing value information
		if `miss_before' == `miss_after' {
			di "Missing values: `miss_before' before, `miss_after' after"
		}
		else {
			di in re "WARNING: Missing values: `miss_before' before, `miss_after' after"
		}

}

end