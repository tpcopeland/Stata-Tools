*! massdesas Version 1.0  24July2020

*! Author: Tim Copeland 
*! Revised on  24 July 2020 at 22:41:00

program define massdesas
syntax , directory(string) [ERASE LOWER]
 
****
global source `directory'
cd "$source"
filelist, dir("$source") pat("*.sas7bdat") save("sas_files.dta") replace 
use sas_files, replace 
replace dirname = subinstr(dirname, "/\", "/",.) 
replace dirname = subinstr(dirname, "\/", "/",.) 
replace dirname = subinstr(dirname, "\", "/",.) 

levelsof dirname, local(levels) 
erase sas_files.dta 
foreach l of local levels {
cd "`l'"
quietly fs *.sas7bdat 
foreach file in `r(files)'{ 
clear 
if "`lower'"== "" {
import sas using "`file'", clear
}
else{
import sas using "`file'", case(lower) clear
}
save "`=substr("`file'", 1, strpos("`file'", ".sas7bdat") - 1)'.dta", replace 
if "`erase'"== "" {
}
else{
erase "`file'"
}
}
}
cd "$source"
end 