*! _datamap_collect_from_dir Version 1.10.3  2026/10/20
*! Shared datamap/datadict directory scanner
*! Author: Timothy P Copeland, Karolinska Institutet

program define _datamap_collect_from_dir, nclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	tempname fh
	local opened 0
	capture noisily {
	args directory recursive tmpfile
	_datamap_validate_path `"`directory'"', option("directory()")

	quietly file open `fh' using `"`tmpfile'"', write text replace
	local opened 1

	if `"`recursive'"' == "" {
		// *.DTA too: on a case-sensitive file system "*.dta" skipped X.DTA
	local files : dir `"`directory'"' files "*.dta"
	local _filesU : dir `"`directory'"' files "*.DTA"
	local files : list files | _filesU
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

capture program drop _datamap_recursive_scan
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_recursive_scan, nclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
	args directory fh depth
	// a symbolic link back to an ancestor made the walk unbounded
	if "`depth'" == "" local depth 0
	if `depth' > 32 {
		display as error `"recursive: directories nested deeper than 32 levels below the start (a symbolic-link loop?) at `directory'"'
		exit 198
	}

	// *.DTA too: on a case-sensitive file system "*.dta" skipped X.DTA
	local files : dir `"`directory'"' files "*.dta"
	local _filesU : dir `"`directory'"' files "*.DTA"
	local files : list files | _filesU
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
				_datamap_recursive_scan `"`directory'/`subdir'"' `fh' `=`depth' + 1'
			}
			else {
				_datamap_recursive_scan `"`subdir'"' `fh' `=`depth' + 1'
			}
		}
	}
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end
