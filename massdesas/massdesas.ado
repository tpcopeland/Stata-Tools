*! massdesas Version 1.0.0  17November2025

*! Author: Tim Copeland
*! Revised on  17 November 2025

program define massdesas
syntax , directory(string) [ERASE LOWER]

* Validation: Check if directory exists
mata: st_numscalar("r_dir", direxists("`directory'"))
if r_dir == 0 {
	display as error "directory not found: `directory'"
	exit 601
}

* Validation: Check if filelist command is available
capture which filelist
if _rc {
	display as error "filelist command not found; install with: ssc install filelist"
	exit 199
}

****
global source `directory'
cd "$source"
filelist, dir("$source") pat("*.sas7bdat") save("sas_files.dta") replace

* Validation: Check if any SAS files were found
use sas_files, clear
quietly count
if r(N) == 0 {
	display as error "no SAS files found in directory: `directory'"
	erase sas_files.dta
	exit 601
} 
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