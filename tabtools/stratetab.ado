*! stratetab Version 1.0.2  05dec2025
*! Author: Tim Copeland

/*
DESCRIPTION:
	Combines pre-computed strate output files, exports to Excel with outcomes 
	as column groups and exposure variables as rows.

SYNTAX:
	stratetab, using(filelist) xlsx(string) outcomes(integer) [sheet(string) ///
	  title(string) outlabels(string) explabels(string) digits(integer 1) ///
	  eventdigits(integer 0) pydigits(integer 0) unitlabel(string) ///
	  pyscale(real 1) ratescale(real 1000)]

	using:       Space-separated list of strate output files (.dta extension added automatically)
	             Format: out1_exp1 out2_exp1 out3_exp1 out1_exp2 out2_exp2 out3_exp2 ...
	             (all outcomes for exposure 1, then all outcomes for exposure 2, etc.)
	xlsx:        Excel output file (must have .xlsx extension)
	outcomes:    Number of outcomes (required)
	sheet:       Sheet name (default: Results)
	title:       Title text for row 1
	outlabels:   Outcome labels separated by \ (e.g., "Sustained EDSS 4 \ Sustained EDSS 6 \ First Relapse")
	explabels:   Exposure group labels separated by \ (e.g., "Time-Varying HRT \ HRT Duration")
	digits:      Decimal places for rate and CI (default 1)
	eventdigits: Decimal places for events (default 0)
	pydigits:    Decimal places for person-years (default 0)
	unitlabel:   Unit label for rate column (default "1,000")
	pyscale:     Divides person-years by this value (default 1 = no scaling)
	ratescale:   Multiplies rates by this value (default 1000)
*/

program define stratetab
version 17.0
set varabbrev off

if "`_byvars'" != "" {
	di as err "stratetab may not be combined with by:"
	exit 190
}

syntax, using(string asis) xlsx(string) outcomes(integer) ///
	[sheet(string) title(string) outlabels(string) explabels(string) ///
	digits(integer 1) eventdigits(integer 0) pydigits(integer 0) ///
	unitlabel(string) pyscale(real 1) ratescale(real 1000)]

if !strmatch("`xlsx'", "*.xlsx") {
	di as err "xlsx must have .xlsx extension"
	exit 198
}

* Sanitize file path to prevent injection
if regexm("`xlsx'", "[;&|><\$]") {
	di as err "xlsx() contains invalid characters"
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

if `ratescale' <= 0 {
	di as err "ratescale must be positive"
	exit 198
}

if `outcomes' < 1 {
	di as err "outcomes must be at least 1"
	exit 198
}

local n_files : word count `using'
if mod(`n_files', `outcomes') != 0 {
	di as err "Number of files must be divisible by number of outcomes"
	exit 198
}

local n_exposures = `n_files' / `outcomes'

* Sanitize file paths in using()
foreach file of local using {
	if regexm("`file'", "[;&|><\$]") {
		di as err "using() contains invalid characters: `file'"
		exit 198
	}
}

* Parse outcome labels
if "`outlabels'" != "" {
	local outlabels = subinstr("`outlabels'", " \ ", "\", .)
	local outlabels = subinstr("`outlabels'", "\  ", "\", .)
	local outlabels = subinstr("`outlabels'", "  \", "\", .)
	tokenize "`outlabels'", parse("\")
	local n_outlabs = 0
	forvalues i = 1/100 {
		local j = (`i'-1)*2 + 1
		if "``j''" == "" continue, break
		local n_outlabs = `n_outlabs' + 1
		local outlab`i' = strtrim("``j''")
	}
	if `n_outlabs' != `outcomes' {
		di as err "Number of outcome labels (`n_outlabs') must match outcomes (`outcomes')"
		exit 198
	}
}
else {
	forvalues i = 1/`outcomes' {
		local outlab`i' "Outcome `i'"
	}
}

* Parse exposure labels
if "`explabels'" != "" {
	local explabels = subinstr("`explabels'", " \ ", "\", .)
	local explabels = subinstr("`explabels'", "\  ", "\", .)
	local explabels = subinstr("`explabels'", "  \", "\", .)
	tokenize "`explabels'", parse("\")
	local n_explabs = 0
	forvalues i = 1/100 {
		local j = (`i'-1)*2 + 1
		if "``j''" == "" continue, break
		local n_explabs = `n_explabs' + 1
		local explab`i' = strtrim("``j''")
	}
	if `n_explabs' != `n_exposures' {
		di as err "Number of exposure labels (`n_explabs') must match number of exposure groups (`n_exposures')"
		exit 198
	}
}
else {
	forvalues i = 1/`n_exposures' {
		local explab`i' "Exposure `i'"
	}
}

qui {

* Set default unit label
if "`unitlabel'" == "" {
	local unitlabel "1,000"
}

* Process each file and store data
* Files are organized: out1_exp1 out2_exp1 out3_exp1 out1_exp2 out2_exp2 out3_exp2 ...
local filenum = 0
forvalues e = 1/`n_exposures' {
	forvalues o = 1/`outcomes' {
		local filenum = `filenum' + 1
		local file : word `filenum' of `using'
		
		preserve
		cap use "`file'.dta", clear
		if _rc {
			noi di as err "File not found: `file'.dta"
			restore
			exit 601
		}
		
		cap confirm var _Rate _Lower _Upper _D _Y
		if _rc {
			noi di as err "`file'.dta missing required columns"
			restore
			exit 111
		}
		
		* Find the categorical variable
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
			* Check if variable has a value label before decoding
			local vallabel : value label `catvar'
			if "`vallabel'" != "" {
				decode `catvar', gen(catvar_str)
			}
			else {
				* No value label - convert to string directly
				gen catvar_str = string(`catvar')
			}
		}
		else {
			gen catvar_str = `catvar'
		}
		
		* Scale and format rate
		gen _Rate_scaled = _Rate * `ratescale'
		gen _Lower_scaled = _Lower * `ratescale'
		gen _Upper_scaled = _Upper * `ratescale'
		
		* Store number of categories for this exposure
		local ncat_e`e' = _N
		
		* Store data
		forvalues i = 1/`=_N' {
			local cat_e`e'_`i' = catvar_str[`i']
			local D_o`o'_e`e'_`i' = _D[`i']
			local Y_o`o'_e`e'_`i' = _Y[`i'] / `pyscale'
			local Rate_o`o'_e`e'_`i' = _Rate_scaled[`i']
			local Lower_o`o'_e`e'_`i' = _Lower_scaled[`i']
			local Upper_o`o'_e`e'_`i' = _Upper_scaled[`i']
		}
		
		restore
	}
}

* Build output dataset
clear
local ncols = 1 + `outcomes' * 3
forvalues c = 1/`ncols' {
	quietly gen str244 c`c' = ""
}
quietly gen str244 title = ""

* Row 1: Title (in title column, will be merged across all)
quietly set obs 1
quietly replace title = "`title'" in 1

* Row 2: Outcome headers (merged across 3 columns each)
local new = _N + 1
quietly set obs `new'
quietly replace c1 = "Exposure" in `new'
local col = 2
forvalues o = 1/`outcomes' {
	quietly replace c`col' = "`outlab`o''" in `new'
	local col = `col' + 3
}

* Row 3: Sub-headers (Events, Person-Years, Rate)
local new = _N + 1
quietly set obs `new'
quietly replace c1 = "Exposure" in `new'
local col = 2
forvalues o = 1/`outcomes' {
	quietly replace c`col' = "Events" in `new'
	local col = `col' + 1
	quietly replace c`col' = "Person-Years (PY)" in `new'
	local col = `col' + 1
	quietly replace c`col' = "Per `unitlabel' PY (95% CI)" in `new'
	local col = `col' + 1
}

* Data rows by exposure group
forvalues e = 1/`n_exposures' {
	* Exposure header row
	local new = _N + 1
	quietly set obs `new'
	quietly replace c1 = "`explab`e''" in `new'
	
	* Category rows (indented)
	forvalues i = 1/`ncat_e`e'' {
		local new = _N + 1
		quietly set obs `new'
		quietly replace c1 = "   `cat_e`e'_`i''" in `new'
		
		local col = 2
		forvalues o = 1/`outcomes' {
			* Events
			if `eventdigits' == 0 {
				local ev_fmt = string(`D_o`o'_e`e'_`i'', "%11.0fc")
			}
			else {
				local ev_fmt = string(`D_o`o'_e`e'_`i'', "%11.`eventdigits'fc")
			}
			quietly replace c`col' = "`ev_fmt'" in `new'
			local col = `col' + 1
			
			* Person-years
			if `pydigits' == 0 {
				local py_fmt = string(round(`Y_o`o'_e`e'_`i'',1), "%11.0fc")
			}
			else {
				local py_fmt = string(`Y_o`o'_e`e'_`i'', "%11.`pydigits'fc")
			}
			quietly replace c`col' = "`py_fmt'" in `new'
			local col = `col' + 1
			
			* Rate (95% CI)
			local rt_fmt = strtrim(string(round(`Rate_o`o'_e`e'_`i'',10^(-`digits')), "%11.`digits'f")) + ///
				" (" + strtrim(string(round(`Lower_o`o'_e`e'_`i'',10^(-`digits')), "%11.`digits'f")) + ///
				"-" + strtrim(string(round(`Upper_o`o'_e`e'_`i'',10^(-`digits')), "%11.`digits'f")) + ")"
			quietly replace c`col' = "`rt_fmt'" in `new'
			local col = `col' + 1
		}
	}
}

* Identify exposure header rows (for borders)
local lastrow = _N
tempvar exp_row
gen `exp_row' = (c2 == "" & c1 != "" & c1 != "Exposure" & _n > 3)
local exp_rows ""
forvalues r = 4/`lastrow' {
	if `exp_row'[`r'] == 1 {
		local exp_rows "`exp_rows' `r'"
	}
}
drop `exp_row'

* Export to Excel
local sht = cond("`sheet'" != "", "`sheet'", "Results")
order title c*
export excel using "`xlsx'", sheet("`sht'") sheetreplace

* Apply formatting with mata
clear
mata: b = xl()
mata: b.load_book("`xlsx'")
mata: b.set_sheet("`sht'")
mata: b.set_row_height(1,1,30)
mata: b.set_column_width(1,1,5)
mata: b.set_column_width(2,2,18)

local col = 3
forvalues o = 1/`outcomes' {
	mata: b.set_column_width(`col',`col',7)
	local col = `col' + 1
	mata: b.set_column_width(`col',`col',17)
	local col = `col' + 1
	mata: b.set_column_width(`col',`col',20)
	local col = `col' + 1
}
mata: b.close_book()

* Apply borders and formatting with putexcel
putexcel set "`xlsx'", sheet("`sht'") modify

* Column letters
local letters "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z AA AB AC AD AE AF AG AH AI AJ AK AL AM AN AO AP AQ AR AS AT AU AV AW AX AY AZ"
local lastcol_num = 1 + `outcomes' * 3
local lastcol : word `=`lastcol_num'+1' of `letters'

* Title row - merge and format
putexcel (A1:`lastcol'1), merge bold txtwrap left top font(Arial,10)

* Header rows
putexcel (B2:`lastcol'2), border(top,thin)
putexcel (B3:`lastcol'3), border(bottom,thin)

* Merge outcome headers
local col = 3
forvalues o = 1/`outcomes' {
	local col1 : word `col' of `letters'
	local col3 : word `=`col'+2' of `letters'
	putexcel (`col1'2:`col3'2), merge bold hcenter top border(bottom,thin)
	local col = `col' + 3
}

* Merge Exposure cell across rows 2-3
putexcel (B2:B3), merge bold hcenter vcenter border(bottom,thin)

* Row 3 formatting
putexcel (C3:`lastcol'3), bold

* Font for all data
putexcel (B2:`lastcol'`lastrow'), font(Arial,10)

* Vertical borders between outcome groups
putexcel (B2:B`lastrow'), border(left,thin)
putexcel (B2:B`lastrow'), border(right,thin)

local col = 3
forvalues o = 1/`outcomes' {
	local col_end : word `=`col'+2' of `letters'
	putexcel (`col_end'2:`col_end'`lastrow'), border(right,thin)
	local col = `col' + 3
}

* Horizontal borders between exposure groups (at bottom of each group)
foreach r of local exp_rows {
	local border_row = `r' - 1
	if `border_row' > 3 {
		putexcel (B`border_row':`lastcol'`border_row'), border(bottom,thin)
	}
}

* Bottom border
putexcel (B`lastrow':`lastcol'`lastrow'), border(bottom,thin)

putexcel clear

}

di as txt "Exported to `xlsx'"

end
