*! stratetab | Version 1.0
*! Author: Tim Copeland
*! Revised: October 23, 2025

/*
DESCRIPTION:
	Combines pre-computed strate output files, exports to Excel with outcome 
	labels as headers and category labels indented in first column.

SYNTAX:
	stratetab, using(filelist) xlsx(string) [sheet(string) title(string) ///
	  labels(string) digits(integer 1) eventdigits(integer 0) pydigits(integer 0) ///
	  unitlabel(string) pyscale(real 1)]

	using:      Space-separated list of strate output files (.dta extension added automatically)
	xlsx:       Excel output file (must have .xlsx extension)
	sheet:      Sheet name (default: Results)
	title:      Title text for row 1
	labels:     Outcome labels separated by \ (e.g., "EDSS 4 \ EDSS 6 \ Relapse")
	digits:     Decimal places for rate and CI (default 1)
	eventdigits:Decimal places for events (default 0)
	pydigits:   Decimal places for person-years (default 0)
	unitlabel:  Adds unit label to rate column (e.g., "Rate per 1000 person-years")
	pyscale:    Divides person-years by this value (default 1 = no scaling)  

EXAMPLE:
	stratetab, using(strate_edss4 strate_edss6 strate_relapse) ///
	  xlsx(results.xlsx) ///
	  labels(EDSS Progression \ EDSS 6 \ Relapse) ///
	  title(Unadjusted Event Rates)
*/

program define stratetab
version 17

if "`_byvars'" != "" {
	di as err "stratetab may not be combined with by:"
	exit 190
}

syntax, using(namelist) xlsx(string) [sheet(string) title(string) ///
	labels(string) digits(integer 1) eventdigits(integer 0) pydigits(integer 0) ///
	unitlabel(string) pyscale(real 1)]

if !strmatch("`xlsx'", "*.xlsx") {
	di as err "xlsx must have .xlsx extension"
	exit 198
}

if `digits' < 0 | `digits' > 10 | `eventdigits' < 0 | `eventdigits' > 10 | `pydigits' < 0 | `pydigits' > 10 {
	di as err "digit options must be 0-10"
	exit 198
}

if `pyscale' <= 0 {
	di as err "pyscale must be positive"
	exit 198
}

qui {
* Parse labels
local n_files : word count `using'
if "`labels'" != "" {
	local labels = subinstr("`labels'", " \ ", "\", .)
	local labels = subinstr("`labels'", "\  ", "\", .)
	local labels = subinstr("`labels'", "  \", "\", .)
	tokenize "`labels'", parse("\")
	forvalues i = 1/`n_files' {
		local j = (`i'-1)*2 + 1
		local lab`i' "``j''"
	}
}
else {
	forvalues i = 1/`n_files' {
		local lab`i' "Outcome `i'"
	}
}

* Build output dataset
clear
quietly gen str244 c1 = ""
quietly gen str244 c2 = ""
quietly gen str244 c3 = ""
quietly gen str244 c4 = ""
quietly gen str244 c5 = ""
quietly set obs 1

* Title row (in column A)
quietly replace c1 = "`title'" in 1

}
* Identify categorical variable(s) and set column header
local catvar_list ""
qui {
	forvalues f = 1/`n_files' {
		local file : word `f' of `using'
		preserve
		cap use "`file'.dta", clear
		if _rc {
			di as err "File not found: `file'.dta"
			restore
			exit 601
		}
		
		* Find the categorical variable (first non-strate column)
		unab allvars : *
		local catvar ""
		foreach v of local allvars {
			if "`v'" != "_D" & "`v'" != "_Y" & "`v'" != "_Rate" & "`v'" != "_Lower" & "`v'" != "_Upper" {
				local catvar "`v'"
				continue, break
			}
		}
		local catvar_list "`catvar_list' `catvar'"
		restore
	}
}

qui {
* Determine header label for column 1 using variable label
local catvar_unique : list uniq catvar_list
local n_unique : word count `catvar_unique'
if `n_files' == 1 {
	local firstcat : word 1 of `catvar_unique'
	qui {
		preserve
		local file : word 1 of `using'
		use "`file'.dta", clear
		local varlabel : variable label `firstcat'
		if "`varlabel'" == "" local varlabel "`firstcat'"
		restore
	}
	local col1_header "Outcome by `varlabel'"
}
else if `n_unique' == 1 {
	local firstcat : word 1 of `catvar_unique'
	qui {
		preserve
		local file : word 1 of `using'
		use "`file'.dta", clear
		local varlabel : variable label `firstcat'
		if "`varlabel'" == "" local varlabel "`firstcat'"
		restore
	}
	local col1_header "Outcomes by `varlabel'"
}
else {
	local col1_header "Outcomes by Group"
}

* Header row (column headers in B, C, D, E)
local new = _N + 1
quietly set obs `new'
quietly replace c2 = "`col1_header'" in `new'
quietly replace c3 = "Events" in `new'
* Person-years header based on pyscale
if `pyscale' != 1 {
	local pyscale_int = string(`pyscale', "%12.0g")
	quietly replace c4 = "Person-years" + char(10) + "(`pyscale_int's)" in `new'
}
else {
	quietly replace c4 = "Person-years" in `new'
}

* Rate header based on unitlabel
if "`unitlabel'" != "" {
	quietly replace c5 = "Rate per `unitlabel'" + char(10) + "person-years (95% CI)" in `new'
}
else {
	quietly replace c5 = "Rate (95% CI)" in `new'
}

}

qui {
	forvalues f = 1/`n_files' {
		local file : word `f' of `using'
		
		* Load file
		preserve
		use "`file'.dta", clear
		
		cap confirm var _Rate _Lower _Upper _D _Y
		if _rc {
			di as err "`file'.dta missing required columns"
			restore
			exit 111
		}
		
		* Get categorical variable
		unab allvars : *
		local catvar ""
		foreach v of local allvars {
			if "`v'" != "_D" & "`v'" != "_Y" & "`v'" != "_Rate" & "`v'" != "_Lower" & "`v'" != "_Upper" {
				local catvar "`v'"
				continue, break
			}
		}
		
		* Convert categorical to string if needed
		cap confirm string var `catvar'
		if _rc {
			decode `catvar', gen(catvar_str)
		}
		else {
			gen catvar_str = `catvar'
		}
		
		* Format data
		if `eventdigits' == 0 {
			gen ev = string(_D, "%11.0fc")
		}
		else {
			gen ev = string(_D, "%11.`eventdigits'fc")
		}
		
		if `pydigits' == 0 {
			gen py = string(round(_Y/`pyscale',1), "%11.0fc")
		}
		else {
			gen py = string(_Y/`pyscale', "%11.`pydigits'fc")
		}
		
		gen rt = strtrim(string(round(_Rate,10^(-`digits')), "%11.`digits'f")) + " (" + ///
		         strtrim(string(round(_Lower,10^(-`digits')), "%11.`digits'f")) + "-" + ///
		         strtrim(string(round(_Upper,10^(-`digits')), "%11.`digits'f")) + ")"
		
		local nobs = _N
		
		restore
		
		* Outcome header row
		local new = _N + 1
		quietly set obs `new'
		quietly replace c2 = "`lab`f''" in `new'
		
		* Data rows with indented levels
		preserve
		use "`file'.dta", clear
		
		* Get categorical variable
		unab allvars : *
		local catvar ""
		foreach v of local allvars {
			if "`v'" != "_D" & "`v'" != "_Y" & "`v'" != "_Rate" & "`v'" != "_Lower" & "`v'" != "_Upper" {
				local catvar "`v'"
				continue, break
			}
		}
		
		* Convert categorical to string if needed
		cap confirm string var `catvar'
		if _rc {
			decode `catvar', gen(catvar_str)
		}
		else {
			gen catvar_str = `catvar'
		}
		
		* Format data
		if `eventdigits' == 0 {
			gen ev = string(_D, "%11.0fc")
		}
		else {
			gen ev = string(_D, "%11.`eventdigits'fc")
		}
		
		if `pydigits' == 0 {
			gen py = string(round(_Y/`pyscale',1), "%11.0fc")
		}
		else {
			gen py = string(_Y/`pyscale', "%11.`pydigits'fc")
		}
		
		gen rt = strtrim(string(round(_Rate,10^(-`digits')), "%11.`digits'f")) + " (" + ///
		         strtrim(string(round(_Lower,10^(-`digits')), "%11.`digits'f")) + "-" + ///
		         strtrim(string(round(_Upper,10^(-`digits')), "%11.`digits'f")) + ")"
		
		forvalues i = 1/`=_N' {
			local v1 = "    " + catvar_str[`i']
			local v2 = ev[`i']
			local v3 = py[`i']
			local v4 = rt[`i']
			restore
			
			local new = _N + 1
			quietly set obs `new'
			quietly replace c2 = "`v1'" in `new'
			quietly replace c3 = "`v2'" in `new'
			quietly replace c4 = "`v3'" in `new'
			quietly replace c5 = "`v4'" in `new'
			
			preserve
			use "`file'.dta", clear
			
			* Get categorical variable
			unab allvars : *
			local catvar ""
			foreach v of local allvars {
				if "`v'" != "_D" & "`v'" != "_Y" & "`v'" != "_Rate" & "`v'" != "_Lower" & "`v'" != "_Upper" {
					local catvar "`v'"
					continue, break
				}
			}
			
			* Convert categorical to string if needed
			cap confirm string var `catvar'
			if _rc {
				decode `catvar', gen(catvar_str)
			}
			else {
				gen catvar_str = `catvar'
			}
			
			* Format data
			if `eventdigits' == 0 {
				gen ev = string(_D, "%11.0fc")
			}
			else {
				gen ev = string(_D, "%11.`eventdigits'fc")
			}
			
			if `pydigits' == 0 {
				gen py = string(round(_Y/`pyscale',1), "%11.0fc")
			}
			else {
				gen py = string(_Y/`pyscale', "%11.`pydigits'fc")
			}
			
			gen rt = strtrim(string(round(_Rate,10^(-`digits')), "%11.`digits'f")) + " (" + ///
			         strtrim(string(round(_Lower,10^(-`digits')), "%11.`digits'f")) + "-" + ///
			         strtrim(string(round(_Upper,10^(-`digits')), "%11.`digits'f")) + ")"
		}
		restore
	}
}

qui {
* Identify outcome label rows and export
local lastrow = _N
gen outcome_row = (c3 == "" & c2 != "" & _n > 2)
local outcome_rows ""
forvalues r = 3/`lastrow' {
	if outcome_row[`r'] == 1 {
		local outcome_rows "`outcome_rows' `r'"
	}
}

local sht = cond("`sheet'" != "", "`sheet'", "Results")
export excel c1-c5 using "`xlsx'", sheet("`sht'") sheetreplace

* Calculate column widths based on content
forvalues i = 1(1)5 {
	gen c`i'_length = length(c`i')
}

if `pyscale' != 1 {
	local pyscale_int = string(`pyscale', "%12.0g")
	quietly replace c4_length = c4_length - length(" (`pyscale_int's)") if _n == 2
}
if "`unitlabel'" != "" {
	quietly replace c5_length = c5_length - length(" per `unitlabel' person-years") if _n == 2
}

forvalues i = 1(1)5 {
	qui sum c`i'_length
	local max_c`i' = r(max)
}

local col_a_width = `max_c1' + 2
if `col_a_width' < 10 local col_a_width = 10
if `col_a_width' > 50 local col_a_width = 50

local col_b_width = ceil(`max_c2' * 1.2)
if `col_b_width' < 12 local col_b_width = 12

local col_c_width = ceil(`max_c3' * 1.15)
if `col_c_width' < 10 local col_c_width = 10

* Column D width based on pyscale
if `pyscale' != 1 {
	local col_d_width = ceil(`max_c4' * 1.1)
	if `col_d_width' < 13 local col_d_width = 13
}
else {
	local col_d_width = ceil(`max_c4' * 1.15)
	if `col_d_width' < 13 local col_d_width = 13
}

* Column E width based on unitlabel
if "`unitlabel'" != "" {
	local col_e_width = ceil(`max_c5' * 1.2)
	if `col_e_width' < 15 local col_e_width = 15
}
else {
	local col_e_width = ceil(`max_c5' * 1.1)
	if `col_e_width' < 20 local col_e_width = 20
}
drop c*_length outcome_row
}

qui {
* Apply mata formatting
clear
mata: b = xl()
mata: b.load_book("`xlsx'")
mata: b.set_sheet("`sht'")
mata: b.set_row_height(1,1,30)
mata: b.set_row_height(2,2,30)
*mata: b.set_column_width(1,1,`col_a_width')
mata: b.set_column_width(2,2,`col_b_width')
mata: b.set_column_width(3,3,`col_c_width')
mata: b.set_column_width(4,4,`col_d_width')
mata: b.set_column_width(5,5,`col_e_width')
mata: b.close_book()

* Apply borders and formatting
putexcel set "`xlsx'", sheet("`sht'") modify

putexcel (A1:E1), merge txtwrap left top bold font(Arial,10) 
putexcel (B2:E2), txtwrap bold hcenter vcenter font(Arial,10) border(top,thin)
putexcel (B2:E2), border(bottom,thin)
putexcel (B2:E`lastrow'), font(Arial,10)
putexcel (B2:B`lastrow'), left
putexcel (C2:E`lastrow'), hcenter

* Add top borders before outcome label rows to separate sections
foreach r of local outcome_rows {
	putexcel (B`r':E`r'), border(top,thin) bold left
}

* Outer borders
putexcel (B2:B`lastrow'), border(left,thin)
putexcel (B2:B`lastrow'), border(right,thin)
putexcel (E2:E`lastrow'), border(right,thin)
putexcel (B`lastrow':E`lastrow'), border(bottom,thin)

putexcel clear
}

di as txt "Exported to `xlsx'"

end
