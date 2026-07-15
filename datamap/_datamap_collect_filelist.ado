*! _datamap_collect_filelist Version 1.6.1  2026/07/15
*! Shared datamap/datadict filelist parser
*! Author: Timothy P Copeland, Karolinska Institutet

program define _datamap_collect_filelist, nclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	tempname fh_out
	local opened 0
	capture noisily {
	args filelist tmpfile

	quietly file open `fh_out' using `"`tmpfile'"', write text replace
	local opened 1

	local remaining `"`filelist'"'
	while `"`remaining'"' != "" {
		gettoken dsname remaining : remaining
		if `"`dsname'"' != "" {
			if !regexm(`"`dsname'"', "\.dta$") {
				local dsname `"`dsname'.dta"'
			}
			capture quietly confirm file `"`dsname'"'
			if _rc != 0 {
				di as error `"file `dsname' not found"'
				file close `fh_out'
				local opened 0
				exit 601
			}
			file write `fh_out' `"`dsname'"' _n
		}
	}
	file close `fh_out'
	local opened 0
	}
	local rc = _rc
	if `opened' file close `fh_out'
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end
