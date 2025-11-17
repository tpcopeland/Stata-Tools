*! regtab | Version 1.2
*! Originals Author: Tim Copeland
*! Updated on: 25 September 2025

/* 
DESCRIPTION: 
	Formats the collected regression tables; exports point estimate, 95% CI, and p-value to excel; and applies excel formatting (column widths, merges cells, sets column widths). Title appears in cell A1. Top left cell of table is B2.

SYNTAX: 
	regtab, xlsx(string) sheet(string) [models(string) sep(string asis) coef(string) title(string) noint nore]

	xlsx:	Required option. Excel file name. Requires .xlsx suffix
	sheet:	Required option. Excel sheet name.
	models:	Label models, separating model names using backslash (e.g., Model 1 \ Model 2...) 
	coef:	Labels the point estimate (e.g., OR, Coef., HR)
	title:	Gives spreasheet a table name in cell A1
	noint:	Drops intercept row
	nore:	Drops random effects rows
	sep:    character separating 95% CI, default is ", "
	   
*/
capture program drop regtab
program define regtab
version 17

syntax, xlsx(string) sheet(string) [sep(string asis) models(string) coef(string) title(string) noint nore]

quietly{
    /* Check if regression results exist 
    capture quietly collect query row
    if _rc {
        display as error "No regression results found. Run regression commands first."
        exit 301
    }
    /* Check if file name has .xlsx extension */
    if !strmatch("`xlsx'", "*.xlsx") {
        display as error "Excel filename must have .xlsx extension"
        exit 198
    }
    
    /* Check if temporary file exists and warn */
    capture confirm file "temp.xlsx"
    if !_rc {
        display as text "Warning: temp.xlsx exists and will be overwritten"
    }
    
    return local xlsx "`xlsx'"
    return local sheet "`sheet'"

    */
	
	    if `"`sep'"' == "" local sep ", "      // Default separator for IQR

collect label levels result _r_b "`coef'", modify
collect style cell result[_r_b], warn nformat(%4.2fc) halign(center) valign(center)
collect style cell result[_r_ci], warn nformat(%4.2fc) sformat("(%s)") cidelimiter("`sep'") halign(center) valign(center)
collect style cell result[_r_p], warn nformat(%5.4f) halign(center) valign(center)
collect style column, dups(center)
collect style row stack, nodelimiter nospacer indent length(.) wrapon(word) noabbreviate wrap(.) truncate(tail)
collect layout (colname) (cmdset#result[_r_b _r_ci _r_p]) ()
collect export temp.xlsx, sheet(temp,replace) modify open

import excel temp.xlsx, sheet(temp) clear
if !missing(`noint') {
	drop if inlist(strlower(strtrim(A)), "intercept", "_cons", "constant", "Intercept")
}
else {

}
if !missing(`nore'){
drop if strpos(A,"var(")
}
else {

}
ds
local varlist `r(varlist)'
local varlist = "_"+"`r(varlist)'"
local allvars: subinstr local varlist "_A B " "B ", all
display "`allvars'"
local n 1 
foreach var of local allvars{
rename `var' c`n'
replace c`n' = "" if _n == 1 
local n `=`n'+1'
}
local n2 `=`n'-3'
local n `=`n'-1'

if "`models'" != "" {
    * Split models string by backslashes
	local models : subinstr local models " \ " "\", all
	local models : subinstr local models "\  " "\", all
	local models : subinstr local models "  \" "\", all
    tokenize "`models'", parse("\")
    local model_idx = 1
    local col_idx = 1
    
    * Loop through tokenized results
    while "``model_idx''" != "" {
        if "``model_idx''" != "\" {
            * Apply label to appropriate column
            replace c`col_idx' = "``model_idx''" if _n == 1
            local col_idx = `col_idx' + 3
        }
        local model_idx = `model_idx' + 1
    }
}
local last = `n' - 2
forvalues i = 1(3)`last'{
destring c`i', gen(c`i'z) force 
replace c`i'z = round(c`i'z, 0.01) 
tostring c`i'z, replace force format(%9.2f)
replace c`i' = "Reference" if inlist(c`i', "0", "1") & c`=`i'+1' == ""
replace c`i' = c`i'z if c`i'z != "." & c`i' != "Reference" & _n >= 3
drop c`i'z
capture confirm variable c`=`i'+1'
if _rc == 0 replace c`=`i'+1' = "" if _n == 1
capture confirm variable c`=`i'+2'
if _rc == 0 replace c`=`i'+2' = "" if _n == 1
}
forvalues i = 3(3)`n'{
destring c`i', gen(c`i'z) force 
replace c`i'z = round(c`i'z, 0.001) 
replace c`i'z = round(c`i'z, 0.01) if c`i'z > 0.05
tostring c`i'z, replace force 
replace c`i'z = "0" + c`i'z if substr(c`i'z, 1, 1) == "." & c`i'z != "."
replace c`i'z = "<0.001" if c`i'z == "0"
replace c`i' = c`i'z if c`i' != "" & _n >= 3
replace c`i' = c`i' + "0" if length(c`i') == 3
drop c`i'z
}
*
gen id = _n 
count 
local count `=`r(N)'+1'
set obs `count'
replace id = 0 if id == . 
sort id 
drop id 
gen title = "" 
order title 
replace title = "`title'" if _n == 1 
export excel using "`xlsx'", sheet("`sheet'") sheetreplace

local num_rows = _N
local num_cols = c(k)

forvalues i = 1(1)`n'{
gen c`i'_length = length(c`i')
}
egen label_length = rowmax(c*_length)
sum label_length, d 
local max_header_length = `=`r(max)' - 0.5'
drop label_length
forvalues i = 1(1)`n'{
replace c`i'_length = . if _n == 2 
egen c`i'_max = max(c`i'_length)
}
forvalues i = 1(1)`=`n'-1'{
replace c1_max = c`=`i'+1'_max if c`=`i'+1'_max > c1_max
}
sum c1_max, d 
local max_length = (`r(max)' * 3 / 8) + 2
    
    /* Ensure reasonable min/max bounds */
    if `max_length' < 8 local max_length = 8
    if `max_length' > 60 local max_length = 60

gen A_length = length(A)
egen factor_length = max(A_length)
sum factor_length, d 
local factor_length = `=ceil(`=`r(max)'*0.95')'

drop A_length factor_length c*_max c*_length

forvalues i = 1(3)`last'{
gen ref`i' = _n if c`i' == "Reference" 
order ref`i', after(c`i')
levelsof ref`i', local(ref`i'_levels)
}
local ref_rows ""
forvalues i = 1(3)`last'{
local ref_rows "`ref_rows' `ref`i'_levels'"
}
local ref_rows: list uniq ref_rows
clear 
mata: b = xl()
mata: b.load_book("`xlsx'")
mata: b.set_sheet("`sheet'")
mata: b.set_row_height(1,1,30)
mata: b.set_column_width(2,2,`factor_length')
forvalues i = 3(3)`=`num_cols'-2'{
mata: b.set_column_width(`i',`i',`=`max_length'*.55')
}
forvalues i = 4(3)`=`num_cols'-1'{
mata: b.set_column_width(`i',`i',`=`max_length'*1.3')
}
forvalues i = 5(3)`num_cols'{
mata: b.set_column_width(`i',`i',`=`max_length'*.875')
}
if `=`max_header_length'*.9' > `=(`max_length'*.55)+(`max_length'*1.3)+(`max_length'*.875)' {
local headerheight = ceil(`=`max_header_length'*.9'/`=(`max_length'*.55)+(`max_length'*1.3)+(`max_length'*.875)')
mata: b.set_row_height(2,2,`=`headerheight'*15')
}
else {

}
mata: b.close_book()

putexcel set "`xlsx'", sheet("`sheet'") modify
local letterleft B
local lettertwo C

local n1 = mod(`num_cols' - 1, 26)
local letterright = upper(char(65 + `n1'))
if `num_cols' > 26 {
  local n2 = floor((`num_cols' - 1) / 26)
  if `n2' > 0 {
local firstletter = upper(char(64 + `n2'))
local letterright = "`firstletter'" + "`letterright'"
  }
}
local n1 2 
local n2 `num_rows'
local tl1 `letterleft'`n1'
local tl2 `letterleft'`=1+`n1''
local tl3 `letterleft'`=2+`n1''
local tr1 `letterright'`n1'
local tr2 `letterright'`=1+`n1''
local tr3 `letterright'`=2+`n1''
local bl `letterleft'`n2'
local br `letterright'`n2'
foreach row of local ref_rows {
local col_num = 3
while `col_num' <= `n' {
local col_letter = ""
local temp_col_num = `col_num'
while `temp_col_num' > 0 {
local remainder = mod(`temp_col_num' - 1, 26)
local col_letter = char(`remainder' + 65) + "`col_letter'"
local temp_col_num = floor((`temp_col_num' - 1) / 26)
}

local col_letter_next1 = ""
local temp_col_num = `col_num' + 1
while `temp_col_num' > 0 {
local remainder = mod(`temp_col_num' - 1, 26)
local col_letter_next1 = char(`remainder' + 65) + "`col_letter_next1'"
local temp_col_num = floor((`temp_col_num' - 1) / 26)
}

local col_letter_next2 = ""
local temp_col_num = `col_num' + 2
while `temp_col_num' > 0 {
local remainder = mod(`temp_col_num' - 1, 26)
local col_letter_next2 = char(`remainder' + 65) + "`col_letter_next2'"
local temp_col_num = floor((`temp_col_num' - 1) / 26)
}

putexcel (`col_letter'`row':`col_letter_next2'`row'), merge hcenter vcenter
local col_num = `col_num' + 3
}
}
*Merge Headers over models
local col_num = 3
while `col_num' <= `n' {
local col_letter = ""
local temp_col_num = `col_num'
while `temp_col_num' > 0 {
local remainder = mod(`temp_col_num' - 1, 26)
local col_letter = char(`remainder' + 65) + "`col_letter'"
local temp_col_num = floor((`temp_col_num' - 1) / 26)
}

local col_letter_next1 = ""
local temp_col_num = `col_num' + 1
while `temp_col_num' > 0 {
local remainder = mod(`temp_col_num' - 1, 26)
local col_letter_next1 = char(`remainder' + 65) + "`col_letter_next1'"
local temp_col_num = floor((`temp_col_num' - 1) / 26)
}

local col_letter_next2 = ""
local temp_col_num = `col_num' + 2
while `temp_col_num' > 0 {
local remainder = mod(`temp_col_num' - 1, 26)
local col_letter_next2 = char(`remainder' + 65) + "`col_letter_next2'"
local temp_col_num = floor((`temp_col_num' - 1) / 26)
}

putexcel (`col_letter'`n1':`col_letter_next2'`n1'), merge hcenter vcenter bold txtwrap // merge headers 
putexcel (`col_letter_next2'`n1':`col_letter_next2'`n2'), border(right, thin) // right border 
local col_num = `col_num' + 3
}
putexcel (A1:`letterright'1), merge txtwrap left top bold // merge title cells 
putexcel (`letterleft'3:`letterright'3), bold // bold column labels 
putexcel (`tl1':`tr1'), border(top, thin) // top 
putexcel (`lettertwo'`n1':`tr2'), border(top, thin) // above column labels
putexcel (`tl2':`tr2'), border(bottom, thin) // header bottom 
putexcel (`tr1':`br'), border(right, thin) // right 
putexcel (`tl1':`bl'), border(left, thin) // left 
putexcel (`tl1':`bl'), border(right, thin) // middle (right of variables)
putexcel (`bl':`br'), border(bottom, thin) // bottom 
putexcel (`letterright'`n1':`letterright'`n2'), border(right, thin) // right of model "x" 
putexcel (A1:`br'), font(Arial, 10)
putexcel clear 
collect clear 
erase temp.xlsx
}

end
*
