*! massdesas Version 1.0.0  17November2025

*! Author: Tim Copeland
*! Revised on  17 November 2025

program define massdesas, rclass
version 18.0
syntax , directory(string) [ERASE LOWER]

* Save original working directory
local original_dir `"`c(pwd)'"'

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
local source `directory'
tempfile sasfiles
cd "`source'"
filelist, dir("`source'") pat("*.sas7bdat") save("`sasfiles'") replace

* Validation: Check if any SAS files were found
use "`sasfiles'", clear
quietly count
if r(N) == 0 {
	display as error "no SAS files found in directory: `directory'"
	cd "`original_dir'"
	exit 601
} 
replace dirname = subinstr(dirname, "/\", "/",.) 
replace dirname = subinstr(dirname, "\/", "/",.) 
replace dirname = subinstr(dirname, "\", "/",.) 

levelsof dirname, local(levels)

* Initialize counters
local n_converted 0
local n_failed 0

foreach l of local levels {
cd "`l'"
quietly fs *.sas7bdat 
foreach file in `r(files)'{
clear
capture {
	if "`lower'"== "" {
		import sas using "`file'", clear
	}
	else{
		import sas using "`file'", case(lower) clear
	}
}
if _rc == 0 {
	local dtaname = substr("`file'", 1, strpos("`file'", ".sas7bdat") - 1)
	save "`dtaname'.dta", replace
	if "`erase'" != "" {
		erase "`file'"
	}
	local ++n_converted
}
else {
	display as error "Failed to import: `file' (rc=`_rc')"
	local ++n_failed
}
}
}

* Restore original working directory
cd "`original_dir'"

* Return values
return scalar n_converted = `n_converted'
return scalar n_failed = `n_failed'
return local directory "`source'"

display as result "Conversion complete: `n_converted' file(s) converted, `n_failed' failed"
end 