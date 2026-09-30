*! _datamap_collect_filelist Version 1.8.1  2026/09/30
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
		// Callers pass filelist() -asis-, so a quoted name keeps its spaces.
		// A quoted token that is not itself a file but contains spaces may be
		// the older whole-list form -- filelist("a b") -- which splits into
		// names, as it did when the quotes were stripped.  It splits only
		// when every word looks like a whole name: if the token ends in .dta,
		// every word must end in .dta; if it holds a path separator, every
		// word must -- unless every word is an existing file written with its
		// .dta extension.  "my file.dta" or "dir/my file" is one path with a
		// space and fails as file-not-found rather than documenting my.dta
		// and file.dta.  (A bare "my file" is ambiguous and splits; see help.)
		if strpos(`"`dsname'"', " ") > 0 {
			local _probe `"`dsname'"'
			if !regexm(`"`_probe'"', "\.dta$") local _probe `"`_probe'.dta"'
			capture confirm file `"`_probe'"'
			if _rc {
				local _ends = regexm(`"`dsname'"', "\.dta$")
				local _seps = strpos(`"`dsname'"', "/") | strpos(`"`dsname'"', "\")
				local _split = 1
				local _allfiles = 1
				foreach _w of local dsname {
					if `_ends' & !regexm(`"`_w'"', "\.dta$") local _split = 0
					if `_seps' & !(strpos(`"`_w'"', "/") | strpos(`"`_w'"', "\")) local _split = 0
					if !regexm(`"`_w'"', "\.dta$") local _allfiles = 0
					else {
						capture confirm file `"`_w'"'
						if _rc local _allfiles = 0
					}
				}
				// 1.8.0 read filelist("sub/a.dta b.dta") as two files: a
				// token whose every word is an existing file named with its
				// .dta extension is a list, whatever its separators
				if `_allfiles' local _split = 1
				if `_split' {
					local remaining `"`dsname' `remaining'"'
					continue
				}
			}
		}
		if `"`dsname'"' != "" {
			_datamap_validate_path `"`dsname'"', option("filelist()")
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
