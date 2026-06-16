*! datadict Version 1.1.1  2026/06/16
*! Generate clean Markdown data dictionaries matching professional documentation style
*! Author: Timothy P Copeland, Karolinska Institutet

program define datadict, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
	syntax [, SIngle(string) DIRectory(string) FILElist(string) ///
	          RECursive ///
	          OUtput(string) SEParate ///
	          TItle(string) SUBTitle(string) VERsion(string) ///
	          AUTHor(string) DATE(string) ///
	          NOTEs(string) CHANGElog(string) ///
	          MISSing STats MAXCat(integer 25) MAXFreq(integer 25) ///
	          DATEFormat(string)]

	// Set default date format (ISO 8601: YYYY/MM/DD)
	if `"`dateformat'"' == "" local dateformat "%tdCCYY/NN/DD"
	if strpos(`"`dateformat'"', "%t") != 1 & strpos(`"`dateformat'"', "%d") != 1 {
		noisily di as error "dateformat() must be a Stata date/time display format beginning with %t or %d"
		exit 198
	}

	// Preserve current dataset
	preserve

	// Validate input options
	local ninput = ("`single'" != "") + ("`directory'" != "") + ("`filelist'" != "")
	if `ninput' > 1 {
		di as error "specify only one of single(), directory(), or filelist()"
		exit 198
	}

	// If no input specified, document data currently in memory
	local from_memory 0
	if `ninput' == 0 {
		if c(N) == 0 | c(k) == 0 {
			noisily di as error "no data in memory and no input specified"
			noisily di as error "specify single(), directory(), filelist(), or load data first"
			exit 198
		}
		tempfile memdata
		quietly save "`memdata'"
		local single "`memdata'"
		local from_memory 1
	}
	
	// Validate numeric parameters
	if `maxcat' <= 0 {
		di as error "maxcat must be positive"
		exit 198
	}
	if `maxfreq' <= 0 {
		di as error "maxfreq must be positive"
		exit 198
	}

	// Set defaults
	if `"`output'"' == "" local output "data_dictionary.md"
	if `"`title'"' == "" local title "Data Dictionary"
	if `"`date'"' == "" local date "`c(current_date)'"

	// Collect files to process
	tempfile filelist_tmp
	if `"`single'"' != "" {
		// Add .dta extension if not present (skip for in-memory tempfiles)
		if !`from_memory' {
			local single = cond(regexm(`"`single'"', "\.dta$"), `"`single'"', `"`single'.dta"')
		}
		confirm file `"`single'"'
		local nfiles 1
		tempname fh_tmp
		quietly file open `fh_tmp' using `"`filelist_tmp'"', write text replace
		file write `fh_tmp' `"`single'"' _n
		file close `fh_tmp'
	}
	else if `"`filelist'"' != "" {
		// filelist now contains dataset names directly (space-separated)
		// Parse the list and write to temp file
		_datamap_collect_filelist `"`filelist'"' `"`filelist_tmp'"'
		_datamap_count_files `"`filelist_tmp'"'
		local nfiles = r(nfiles)
	}
	else {
		if `"`directory'"' == "" local directory "."
		_datamap_collect_from_dir `"`directory'"' "`recursive'" `"`filelist_tmp'"'
		_datamap_count_files `"`filelist_tmp'"'
		local nfiles = r(nfiles)
	}

	// Error if no files found
	if `nfiles' == 0 {
		di as error "no .dta files found"
		exit 601
	}

	// Collect dataset names for TOC
	tempfile names_tmp
	_datadict_CollectDatasetNames `"`filelist_tmp'"' `"`names_tmp'"' `nfiles'

	// Process files (data already preserved at top of program)
	if "`separate'" != "" {
		_datadict_ProcessSeparate `"`filelist_tmp'"' `"`names_tmp'"' ///
			`"`title'"' `"`subtitle'"' `"`version'"' `"`author'"' `"`date'"' ///
			`"`notes'"' `"`changelog'"' `nfiles' "`missing'" "`stats'" `maxcat' `maxfreq' "`dateformat'"
	}
	else {
		_datadict_ProcessCombined `"`filelist_tmp'"' `"`names_tmp'"' `"`output'"' ///
			`"`title'"' `"`subtitle'"' `"`version'"' `"`author'"' `"`date'"' ///
			`"`notes'"' `"`changelog'"' `nfiles' "`missing'" "`stats'" `maxcat' `maxfreq' "`dateformat'"
	}

	// Restore original data
	restore

	// Return results
	return scalar nfiles = `nfiles'
	return local output `"`output'"'

	if "`separate'" != "" {
		di as result "Markdown dictionaries generated for `nfiles' dataset(s)"
	}
	else {
		di as result `"Markdown dictionary generated: `output'"'
	}
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: CollectDatasetNames - extract display names for TOC
// =============================================================================
capture program drop _datadict_CollectDatasetNames
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_CollectDatasetNames, nclass
	version 16.0
	args filelist namesfile nfiles

	tempname fh_in fh_out
	file open `fh_in' using `"`filelist'"', read text
	quietly file open `fh_out' using `"`namesfile'"', write text replace

	file read `fh_in' filepath
	while r(eof) == 0 {
		// Extract basename using Stata's native functions
		local basename = ustrregexra(`"`macval(filepath)'"', ".*[/\\]", "")
		// Remove .dta extension
		local basename = ustrregexra(`"`basename'"', "\.dta$", "")

		// Try to get dataset label
		capture quietly describe using `"`macval(filepath)'"', short
		if _rc == 0 {
			local dslabel `"`r(dtalabel)'"'
		}
		else {
			local dslabel ""
		}

		// Write: basename|label
		file write `fh_out' `"`basename'|`macval(dslabel)'"' _n

		file read `fh_in' filepath
	}
	file close `fh_in'
	file close `fh_out'
end

// =============================================================================
// Helper: MakeAnchor - create markdown anchor from text
// =============================================================================
capture program drop _datadict_MakeAnchor
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_MakeAnchor, rclass
	version 16.0
	args idx name

	// Convert to lowercase and replace spaces/special chars with hyphens
	local anchor = lower(`"`name'"')
	local anchor = ustrregexra(`"`anchor'"', "[ _]", "-")
	local anchor = ustrregexra(`"`anchor'"', "[^a-z0-9-]", "")

	return local anchor "`idx'-`anchor'"
end

// =============================================================================
// Helper: EscapeMarkdown - escape special markdown characters
// =============================================================================
capture program drop _datadict_EscapeMarkdown
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_EscapeMarkdown, rclass
	version 16.0
	args text

	local escaped `"`macval(text)'"'
	// Escape characters that could break markdown table formatting
	local escaped = subinstr(`"`macval(escaped)'"', "|", "\|", .)
	local escaped = subinstr(`"`macval(escaped)'"', "`", "\`", .)
	// Replace newlines/carriage returns with space to prevent table breaks
	local escaped = subinstr(`"`macval(escaped)'"', char(10), " ", .)
	local escaped = subinstr(`"`macval(escaped)'"', char(13), " ", .)
	// Escape HTML angle brackets
	local escaped = subinstr(`"`macval(escaped)'"', "<", "&lt;", .)
	local escaped = subinstr(`"`macval(escaped)'"', ">", "&gt;", .)

	return local escaped `"`macval(escaped)'"'
end

// =============================================================================
// Helper: ParseNameLine - parse basename|label metadata line
// =============================================================================
capture program drop _datadict_ParseNameLine
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_ParseNameLine, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
	args nameline

	local pipepos = strpos(`"`nameline'"', "|")
	if `pipepos' > 0 {
		local dsname = substr(`"`nameline'"', 1, `pipepos'-1)
		local dslabel = substr(`"`nameline'"', `pipepos'+1, .)
	}
	else {
		local dsname `"`nameline'"'
		local dslabel ""
	}

	return local dsname `"`dsname'"'
	return local dslabel `"`macval(dslabel)'"'
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: FormatDisplayName - format dataset name for Markdown display
// =============================================================================
capture program drop _datadict_FormatDisplayName
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_FormatDisplayName, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
	args dsname

	local dispname = proper(subinstr(`"`dsname'"', "_", " ", .))

	return local dispname `"`dispname'"'
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: ProcessCombined
// =============================================================================
capture program drop _datadict_ProcessCombined
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_ProcessCombined, nclass
	version 16.0
	args filelist namesfile output title subtitle version author date notes changelog nfiles showmissing showstats maxcat maxfreq dateformat

	tempname fh
	quietly file open `fh' using `"`output'"', write text replace

	// Write document header
	file write `fh' `"# `macval(title)'"' _n _n

	if `"`subtitle'"' != "" {
		file write `fh' `"`macval(subtitle)'"' _n _n
	}

	if `"`version'"' != "" {
		file write `fh' `"Version `version'"' _n _n
	}

	// Table of Contents
	file write `fh' "## Table of Contents" _n _n

	// Read names file for TOC entries
	tempname fh_names
	file open `fh_names' using `"`namesfile'"', read text
	local i 0
	file read `fh_names' nameline
	while r(eof) == 0 {
		local ++i
		_datadict_ParseNameLine `"`macval(nameline)'"'
		local dsname `"`r(dsname)'"'

		// Create anchor
		_datadict_MakeAnchor `i' `"`dsname'"'
		local anchor = r(anchor)

		// Format display name (capitalize, replace _ with space)
		_datadict_FormatDisplayName `"`dsname'"'
		local dispname `"`r(dispname)'"'

		file write `fh' `"`i'. [`dispname'](#`anchor')"' _n

		file read `fh_names' nameline
	}
	file close `fh_names'

	// Add Notes and Change Log to TOC
	local notesidx = `nfiles' + 1
	local chlogidx = `nfiles' + 2
	file write `fh' `"`notesidx'. [Notes](#notes)"' _n
	file write `fh' `"`chlogidx'. [Change Log](#change-log)"' _n
	file write `fh' _n _n

	// Process each dataset
	tempname fh_list fh_names2
	file open `fh_list' using `"`filelist'"', read text
	file open `fh_names2' using `"`namesfile'"', read text

	local i 0
	file read `fh_list' filepath
	file read `fh_names2' nameline
	while r(eof) == 0 {
		local ++i

		_datadict_ParseNameLine `"`macval(nameline)'"'
		local dsname `"`r(dsname)'"'
		local dslabel `"`r(dslabel)'"'

		_datadict_ProcessOneDataset `fh' `"`macval(filepath)'"' `"`dsname'"' `"`macval(dslabel)'"' `i' "`showmissing'" "`showstats'" `maxcat' `maxfreq' "`dateformat'"

		file read `fh_list' filepath
		file read `fh_names2' nameline
	}
	file close `fh_list'
	file close `fh_names2'

	// Notes section
	file write `fh' "## Notes" _n _n
	if `"`notes'"' != "" {
		capture quietly confirm file `"`notes'"'
		if _rc == 0 {
			tempname fh_notes
			file open `fh_notes' using `"`notes'"', read text
			file read `fh_notes' noteline
			while r(eof) == 0 {
				file write `fh' `"`macval(noteline)'"' _n
				file read `fh_notes' noteline
			}
			file close `fh_notes'
		}
		else {
			file write `fh' `"`macval(notes)'"' _n
		}
	}
	else {
		file write `fh' "- No additional notes provided" _n
	}
	file write `fh' _n _n

	// Change Log section
	file write `fh' "## Change Log" _n _n
	if `"`changelog'"' != "" {
		capture quietly confirm file `"`changelog'"'
		if _rc == 0 {
			tempname fh_clog
			file open `fh_clog' using `"`changelog'"', read text
			file read `fh_clog' clogline
			while r(eof) == 0 {
				file write `fh' `"`macval(clogline)'"' _n
				file read `fh_clog' clogline
			}
			file close `fh_clog'
		}
		else {
			file write `fh' `"`macval(changelog)'"' _n
		}
	}
	else {
		file write `fh' "*No changes recorded.*" _n
	}
	file write `fh' _n _n

	// Footer
	if `"`version'"' != "" {
		file write `fh' `"**Document Version:** `version'"' _n _n
	}
	if `"`author'"' != "" {
		file write `fh' `"**Author:** `macval(author)'"' _n _n
	}
	file write `fh' `"**Last Updated:** `date'"' _n

	file close `fh'
	di as result `"Output written to: `output'"'
end

// =============================================================================
// Helper: ProcessSeparate
// =============================================================================
capture program drop _datadict_ProcessSeparate
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_ProcessSeparate, nclass
	version 16.0
	args filelist namesfile title subtitle version author date notes changelog nfiles showmissing showstats maxcat maxfreq dateformat

	tempname fh_list fh_names
	file open `fh_list' using `"`filelist'"', read text
	file open `fh_names' using `"`namesfile'"', read text

	file read `fh_list' filepath
	file read `fh_names' nameline
	while r(eof) == 0 {
		_datadict_ParseNameLine `"`macval(nameline)'"'
		local dsname `"`r(dsname)'"'
		local dslabel `"`r(dslabel)'"'

		// Derive output path from filepath (preserving directory)
		local len = length(`"`macval(filepath)'"')
		if substr(`"`macval(filepath)'"', `len'-3, 4) == ".dta" {
			local outbase = substr(`"`macval(filepath)'"', 1, `len'-4)
		}
		else {
			local outbase `"`macval(filepath)'"'
		}
		local outfile `"`outbase'_dictionary.md"'

		tempname fh
		quietly file open `fh' using `"`outfile'"', write text replace

		// Header
		file write `fh' `"# `macval(title)': `dsname'"' _n _n
		if `"`subtitle'"' != "" {
			file write `fh' `"`macval(subtitle)'"' _n _n
		}
		if `"`version'"' != "" {
			file write `fh' `"Version `version'"' _n _n
		}
		file write `fh' _n

		// Process dataset
		_datadict_ProcessOneDataset `fh' `"`macval(filepath)'"' `"`dsname'"' `"`macval(dslabel)'"' 1 "`showmissing'" "`showstats'" `maxcat' `maxfreq' "`dateformat'"

		// Notes
		file write `fh' "## Notes" _n _n
		file write `fh' `"- All date variables are displayed using `dateformat' format"' _n
		file write `fh' "- Missing values coded as . (numeric missing) or empty string" _n
		file write `fh' _n _n

		// Footer
		if `"`author'"' != "" {
			file write `fh' `"**Author:** `macval(author)'"' _n _n
		}
		file write `fh' `"**Last Updated:** `date'"' _n

		file close `fh'
		di as result `"Output written to: `outfile'"'

		file read `fh_list' filepath
		file read `fh_names' nameline
	}
	file close `fh_list'
	file close `fh_names'
end

// =============================================================================
// Helper: ProcessOneDataset
// =============================================================================
capture program drop _datadict_ProcessOneDataset
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_ProcessOneDataset, nclass
	version 16.0
	args fh filepath dsname dslabel idx showmissing showstats maxcat maxfreq dateformat

	// Get metadata
	capture quietly describe using `"`macval(filepath)'"', short
	if _rc != 0 {
		di as error `"ERROR: Could not describe `filepath'"'
		exit _rc
	}
	local obs = r(N)
	local nvars = r(k)
	if `"`dslabel'"' == "" | `"`dslabel'"' == "." {
		local dslabel "Dataset containing `nvars' variables and `obs' observations."
	}

	// Format display name
	local dispname = proper(subinstr(`"`dsname'"', "_", " ", .))

	// Section header
	file write `fh' `"## `idx'. `dispname'"' _n _n
	file write `fh' `"**Filename:** \``dsname'.dta\`  "' _n
	file write `fh' `"**Description:** `macval(dslabel)'"' _n _n

	// Variables subsection
	file write `fh' "### Variables" _n _n

	// Determine table header based on options
	if "`showmissing'" != "" & "`showstats'" != "" {
		file write `fh' "| Variable | Label | Type | Missing | Statistics/Values |" _n
		file write `fh' "|----------|-------|------|---------|-------------------|" _n
	}
	else if "`showmissing'" != "" {
		file write `fh' "| Variable | Label | Type | Missing | Values/Notes |" _n
		file write `fh' "|----------|-------|------|---------|--------------|" _n
	}
	else if "`showstats'" != "" {
		file write `fh' "| Variable | Label | Type | Statistics/Values |" _n
		file write `fh' "|----------|-------|------|-------------------|" _n
	}
	else {
		file write `fh' "| Variable | Label | Type | Values/Notes |" _n
		file write `fh' "|----------|-------|------|--------------|" _n
	}

	// Shared classification engine leaves the source dataset loaded for row stats.
	tempfile classifications
	_datamap_classify using `"`macval(filepath)'"', saving("`classifications'") ///
		maxcat(`maxcat') obs(`obs')
	local allvars "`r(all_vars)'"
	local categorical_vars "`r(categorical_vars)'"
	local continuous_vars "`r(continuous_vars)'"
	local date_vars "`r(date_vars)'"
	local string_vars "`r(string_vars)'"

	foreach vn of local allvars {
		local varclass "continuous"
		foreach cv of local categorical_vars {
			if "`vn'" == "`cv'" local varclass "categorical"
		}
		foreach cv of local continuous_vars {
			if "`vn'" == "`cv'" local varclass "continuous"
		}
		foreach cv of local date_vars {
			if "`vn'" == "`cv'" local varclass "date"
		}
		foreach cv of local string_vars {
			if "`vn'" == "`cv'" local varclass "string"
		}
		_datadict_WriteVariableRow `fh' `"`vn'"' `obs' "`showmissing'" "`showstats'" `maxcat' `maxfreq' "`dateformat'" "`varclass'"
	}

	file write `fh' _n _n
end

// =============================================================================
// Helper: WriteVariableRow
// =============================================================================
capture program drop _datadict_DateDisplayFormat
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_DateDisplayFormat, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax, VFMT(string) DATEFormat(string)

		local datefmt "`vfmt'"
		if strpos("`vfmt'", "%td") > 0 | strpos("`vfmt'", "%d") > 0 {
			local datefmt "`dateformat'"
		}
		else if strpos("`vfmt'", "%tc") > 0 | strpos("`vfmt'", "%tC") > 0 {
			local datefmt = subinstr("`dateformat'", "%td", "%tc", 1)
		}

		return local display_format `"`datefmt'"'
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

capture program drop _datadict_WriteVariableRow
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_WriteVariableRow, nclass
	version 16.0
	args fh vname obs showmissing showstats maxcat maxfreq dateformat varclass

	local vtype: type `vname'
	local vfmt: format `vname'
	local vlab: variable label `vname'
	local vallabname: value label `vname'

	// Escape pipes and backticks in label
	_datadict_EscapeMarkdown `"`macval(vlab)'"'
	local vlab_safe `"`r(escaped)'"'

	// Determine Type column
	local typestr "Numeric"
	if substr("`vtype'", 1, 3) == "str" {
		local typestr "String"
	}
	else if strpos("`vfmt'", "%t") > 0 | strpos("`vfmt'", "%d") > 0 {
		local typestr "Date"
	}

	// Calculate missing if requested
	local missingstr ""
	if "`showmissing'" != "" {
		quietly count if missing(`vname')
		local nmiss = r(N)
		if `obs' > 0 {
			local pctmiss = strtrim(string(100 * `nmiss' / `obs', "%9.1f"))
		}
		else {
			local pctmiss "0.0"
		}
		local missingstr "`nmiss' (`pctmiss'%)"
	}

	// Determine Values/Notes or Statistics column
	local valsnotes ""

	if "`showstats'" != "" {
		// Show appropriate statistics based on variable classification
		if "`varclass'" == "categorical" {
			// Show frequencies for categorical with percentages
			if "`vallabname'" != "" {
				_datadict_GetCategoricalStats `"`vname'"' `"`vallabname'"' `maxfreq' `obs'
				local valsnotes `"`r(valstring)'"'
			}
			else {
				// Numeric without labels - show unique count with frequencies
				capture quietly tab `vname'
				if _rc == 0 {
					local nuniq = r(r)
					if `nuniq' <= `maxfreq' {
						_datadict_GetUnlabeledStats `"`vname'"' `maxfreq' `obs'
						local valsnotes `"`r(valstring)'"'
					}
					else {
						local valsnotes "Unique=`nuniq'"
					}
				}
			}
		}
		else if "`varclass'" == "continuous" {
			// Show comprehensive summary stats for continuous
			quietly summarize `vname', detail
			if r(N) > 0 {
				local nvalid = r(N)
				// Capture all summarize results before calling FormatStatNumber
				// (FormatStatNumber is rclass and overwrites r() results)
				local raw_mean = r(mean)
				local raw_sd = r(sd)
				local raw_p50 = r(p50)
				local raw_p25 = r(p25)
				local raw_p75 = r(p75)
				local raw_min = r(min)
				local raw_max = r(max)
				// Format numbers intelligently based on magnitude
				_datadict_FormatStatNumber `raw_mean'
				local mean `r(formatted)'
				_datadict_FormatStatNumber `raw_sd'
				local sd `r(formatted)'
				_datadict_FormatStatNumber `raw_p50'
				local median `r(formatted)'
				_datadict_FormatStatNumber `raw_p25'
				local p25 `r(formatted)'
				_datadict_FormatStatNumber `raw_p75'
				local p75 `r(formatted)'
				_datadict_FormatStatNumber `raw_min'
				local vmin `r(formatted)'
				_datadict_FormatStatNumber `raw_max'
				local vmax `r(formatted)'
				local valsnotes "N=`nvalid'<br>Median=`median'; IQR=`p25'-`p75'<br>Mean=`mean' (SD=`sd')<br>Range=`vmin'-`vmax'"
			}
			else {
				local valsnotes "All missing"
			}
		}
		else if "`varclass'" == "date" {
			// Show date range with count
			quietly summarize `vname'
			if r(N) > 0 {
				local nvalid = r(N)
				local raw_min = r(min)
				local raw_max = r(max)
				_datadict_DateDisplayFormat, vfmt("`vfmt'") dateformat("`dateformat'")
				local datefmt "`r(display_format)'"
				local mindate = string(`raw_min', "`datefmt'")
				local maxdate = string(`raw_max', "`datefmt'")
				local valsnotes "N=`nvalid'<br>Range: `mindate' to `maxdate'"
			}
			else {
				local valsnotes "All missing"
			}
		}
		else if "`varclass'" == "string" {
			quietly count if !missing(`vname')
			local nvalid = r(N)
			capture quietly tab `vname'
			if _rc == 0 {
				local nuniq = r(r)
			}
			else {
				capture quietly duplicates report `vname'
				if _rc == 0 {
					local nuniq = r(unique_value)
				}
				else {
					local nuniq "?"
				}
			}
			local valsnotes "N=`nvalid'; `nuniq' unique values"
		}
	}
	else {
		// Original behavior - just show value labels or basic info
		if "`vallabname'" != "" {
			_datadict_GetValueLabelString `"`vname'"' `"`vallabname'"' `maxfreq'
			local valsnotes `"`r(valstring)'"'
		}
		else if "`typestr'" == "Date" {
			if strpos("`vfmt'", "%tc") > 0 {
				local valsnotes "Datetime"
			}
			else {
				local valsnotes "Date"
			}
		}
		else if substr("`vtype'", 1, 3) == "str" {
			local valsnotes ""
		}
		else {
			// Numeric without value labels
			local vname_lower = lower(`"`vname'"')
			if inlist(`"`vname_lower'"', "id", "lopnr") | ///
			   strpos(`"`vname_lower'"', "_id") > 0 | ///
			   strpos(`"`vname_lower'"', "personid") > 0 | ///
			   strpos(`"`vname_lower'"', "identifier") > 0 {
				local valsnotes "Unique identifier"
			}
			else if inlist(`"`vname_lower'"', "year", "yr") {
				local valsnotes "Year of observation"
			}
			else if "`varclass'" == "categorical" {
				// Classified as categorical by maxcat threshold
				_datadict_GetUnlabeledStats `"`vname'"' `maxfreq' `obs'
				local valsnotes `"`r(valstring)'"'
			}
		}
	}

	// Write the row based on options
	if "`showmissing'" != "" & "`showstats'" != "" {
		file write `fh' `"| \``vname'\` | `macval(vlab_safe)' | `typestr' | `missingstr' | `macval(valsnotes)' |"' _n
	}
	else if "`showmissing'" != "" {
		file write `fh' `"| \``vname'\` | `macval(vlab_safe)' | `typestr' | `missingstr' | `macval(valsnotes)' |"' _n
	}
	else if "`showstats'" != "" {
		file write `fh' `"| \``vname'\` | `macval(vlab_safe)' | `typestr' | `macval(valsnotes)' |"' _n
	}
	else {
		file write `fh' `"| \``vname'\` | `macval(vlab_safe)' | `typestr' | `macval(valsnotes)' |"' _n
	}
end

// =============================================================================
// Helper: GetValueLabelString - format value labels for display
// =============================================================================
capture program drop _datadict_GetValueLabelString
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_GetValueLabelString, rclass
	version 16.0
	args vname vallabname maxlevels

	// Get unique non-missing values
	capture quietly levelsof `vname' if !missing(`vname'), local(levels)
	if _rc != 0 | `"`levels'"' == "" {
		return local valstring ""
		exit
	}

	local nlevels: word count `levels'

	// If too many levels, just note the count
	if `nlevels' > `maxlevels' {
		return local valstring "`nlevels' categories"
		exit
	}

	// Build string of value=label pairs
	local valstring ""
	local first 1
	foreach lev of local levels {
		capture local labtext: label `vallabname' `lev'
		if _rc != 0 {
			local labtext ""
		}

		// Escape special characters
		local labtext = subinstr(`"`macval(labtext)'"', "|", "\|", .)
		local labtext = subinstr(`"`macval(labtext)'"', ",", ";", .)

		if `first' {
			if `"`labtext'"' != "" {
				local valstring "`lev'=`labtext'"
			}
			else {
				local valstring "`lev'"
			}
			local first 0
		}
		else {
			if `"`labtext'"' != "" {
				local valstring `"`valstring', `lev'=`labtext'"'
			}
			else {
				local valstring `"`valstring', `lev'"'
			}
		}

		// Truncate if getting too long
		if length(`"`valstring'"') > 200 {
			local valstring = substr(`"`valstring'"', 1, 197) + "..."
			continue, break
		}
	}

	return local valstring `"`valstring'"'
end

// =============================================================================
// Helper: FormatStatNumber - format numbers intelligently based on magnitude
// =============================================================================
capture program drop _datadict_FormatStatNumber
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_FormatStatNumber, rclass
	version 16.0
	args num

	// Handle missing
	if missing(`num') {
		return local formatted "."
		exit
	}

	local absnum = abs(`num')

	// Very large or very small numbers: use scientific notation
	if `absnum' >= 1000000 | (`absnum' < 0.001 & `absnum' > 0) {
		local formatted = string(`num', "%9.2e")
	}
	// Large numbers (>=100): no decimals
	else if `absnum' >= 100 {
		local formatted = string(`num', "%12.0fc")
	}
	// Medium numbers (>=1): 2 decimals
	else if `absnum' >= 1 {
		local formatted = string(`num', "%9.2f")
	}
	// Small numbers (<1): 3 decimals
	else if `absnum' >= 0.001 {
		local formatted = string(`num', "%9.3f")
	}
	// Zero
	else {
		local formatted = "0"
	}

	// Trim whitespace
	local formatted = strtrim("`formatted'")

	return local formatted "`formatted'"
end

// =============================================================================
// Helper: GetCategoricalStats - get frequencies with percentages for labeled categoricals
// =============================================================================
capture program drop _datadict_GetCategoricalStats
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_GetCategoricalStats, rclass
	version 16.0
	args vname vallabname maxlevels totalobs

	// Get unique non-missing values
	capture quietly levelsof `vname' if !missing(`vname'), local(levels)
	if _rc != 0 | `"`levels'"' == "" {
		return local valstring "All missing"
		exit
	}

	local nlevels: word count `levels'

	// If too many levels, just note the count
	if `nlevels' > `maxlevels' {
		return local valstring "Unique=`nlevels'"
		exit
	}

	// Count non-missing
	quietly count if !missing(`vname')
	local nvalid = r(N)

	// Build multi-line output: Unique= first, then one line per category
	local valstring "Unique=`nlevels'"
	foreach lev of local levels {
		capture local labtext: label `vallabname' `lev'
		if _rc != 0 {
			local labtext ""
		}

		// Get count for this level
		quietly count if `vname' == `lev'
		local levcount = r(N)
		if `nvalid' > 0 {
			local levpct = strtrim(string(100 * `levcount' / `nvalid', "%9.1f"))
		}
		else {
			local levpct "0.0"
		}

		// Escape pipe characters for markdown tables
		local labtext = subinstr(`"`macval(labtext)'"', "|", "\|", .)

		if `"`labtext'"' != "" {
			local valstring `"`valstring'<br>`lev' `labtext' (`levcount'; `levpct'%)"'
		}
		else {
			local valstring `"`valstring'<br>`lev' (`levcount'; `levpct'%)"'
		}
	}

	return local valstring `"`valstring'"'
end

// =============================================================================
// Helper: GetUnlabeledStats - get frequencies with percentages for unlabeled categoricals
// =============================================================================
capture program drop _datadict_GetUnlabeledStats
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_GetUnlabeledStats, rclass
	version 16.0
	args vname maxlevels totalobs

	capture quietly levelsof `vname' if !missing(`vname'), local(levels)
	if _rc != 0 | `"`levels'"' == "" {
		return local valstring "All missing"
		exit
	}

	local nlevels: word count `levels'

	// Count non-missing
	quietly count if !missing(`vname')
	local nvalid = r(N)

	if `nlevels' > `maxlevels' {
		return local valstring "Unique=`nlevels'"
		exit
	}

	// Build multi-line output: Unique= first, then one line per value
	local valstring "Unique=`nlevels'"
	foreach lev of local levels {
		// Get count for this level
		quietly count if `vname' == `lev'
		local levcount = r(N)
		if `nvalid' > 0 {
			local levpct = strtrim(string(100 * `levcount' / `nvalid', "%9.1f"))
		}
		else {
			local levpct "0.0"
		}

		local valstring `"`valstring'<br>`lev' (`levcount'; `levpct'%)"'
	}

	return local valstring `"`valstring'"'
end
