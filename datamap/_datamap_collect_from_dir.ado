*! _datamap_collect_from_dir Version 1.0.0  2026/04/08
*! Shared datamap/datadict directory scanner
*! Author: Timothy P. Copeland

program define _datamap_collect_from_dir, nclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	tempname fh
	local opened 0
	capture noisily {
	args directory recursive tmpfile

	quietly file open `fh' using `"`tmpfile'"', write text replace
	local opened 1

	if `"`recursive'"' == "" {
		local files : dir `"`directory'"' files "*.dta"
		foreach f of local files {
			if `"`directory'"' != "." {
				file write `fh' `"`directory'/`f'"' _n
			}
			else {
				file write `fh' `"`f'"' _n
			}
		}
	}
	else {
		_datamap_recursive_scan `"`directory'"' `fh'
	}

	file close `fh'
	local opened 0
	}
	local rc = _rc
	if `opened' file close `fh'
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

program define _datamap_recursive_scan, nclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
	args directory fh

	local files : dir `"`directory'"' files "*.dta"
	foreach f of local files {
		if `"`directory'"' != "." {
			file write `fh' `"`directory'/`f'"' _n
		}
		else {
			file write `fh' `"`f'"' _n
		}
	}

	local subdirs : dir `"`directory'"' dirs "*"
	foreach subdir of local subdirs {
		if substr(`"`subdir'"', 1, 1) != "." & `"`subdir'"' != "__pycache__" {
			if `"`directory'"' != "." {
				_datamap_recursive_scan `"`directory'/`subdir'"' `fh'
			}
			else {
				_datamap_recursive_scan `"`subdir'"' `fh'
			}
		}
	}
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end
