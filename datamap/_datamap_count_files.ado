*! _datamap_count_files Version 1.0.0  2026/04/08
*! Count file paths in a datamap/datadict filelist
*! Author: Timothy P. Copeland

program define _datamap_count_files, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	tempname fh
	local opened 0
	capture noisily {
	args tmpfile

	file open `fh' using `"`tmpfile'"', read text
	local opened 1
	local nfiles 0
	file read `fh' line
	while r(eof) == 0 {
		local ++nfiles
		file read `fh' line
	}
	file close `fh'
	local opened 0

	return scalar nfiles = `nfiles'
	}
	local rc = _rc
	if `opened' file close `fh'
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end
