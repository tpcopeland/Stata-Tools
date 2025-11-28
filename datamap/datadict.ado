*! datadict v2.3.0
*! Generate clean Markdown data dictionaries matching professional documentation style
*! Author: Tim Copeland
*! Date: 2025-11-28

program define datadict, rclass
	version 14.0
	syntax [, Single(string) DIRectory(string) FILElist(string) ///
	          RECursive ///
	          Output(string) SEParate ///
	          Title(string) SUBTitle(string) VERsion(string) ///
	          AUTHor(string) DATE(string) ///
	          NOTEs(string) CHANGElog(string) ///
	          MISSing STats MAXCat(integer 25) MAXFreq(integer 25)]

	// Validate input options
	local ninput = ("`single'" != "") + ("`directory'" != "") + ("`filelist'" != "")
	if `ninput' > 1 {
		di as error "specify only one of single(), directory(), or filelist()"
		exit 198
	}
	if `ninput' == 0 {
		di as error "must specify single(), directory(), or filelist()"
		exit 198
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
		// Add .dta extension if not present
		local single = cond(regexm(`"`single'"', "\.dta$"), `"`single'"', `"`single'.dta"')
		confirm file `"`single'"'
		local nfiles 1
		tempname fh_tmp
		file open `fh_tmp' using `"`filelist_tmp'"', write text replace
		file write `fh_tmp' `"`single'"' _n
		file close `fh_tmp'
	}
	else if `"`filelist'"' != "" {
		// filelist now contains dataset names directly (space-separated)
		// Parse the list and write to temp file
		CollectFromFilelistOption `"`filelist'"' `"`filelist_tmp'"'
		CountFiles `"`filelist_tmp'"'
		local nfiles = r(nfiles)
	}
	else {
		if `"`directory'"' == "" local directory "."
		CollectFromDir `"`directory'"' "`recursive'" `"`filelist_tmp'"'
		CountFiles `"`filelist_tmp'"'
		local nfiles = r(nfiles)
	}

	// Error if no files found
	if `nfiles' == 0 {
		di as error "no .dta files found"
		exit 601
	}

	// Collect dataset names for TOC
	tempfile names_tmp
	CollectDatasetNames `"`filelist_tmp'"' `"`names_tmp'"' `nfiles'

	// Preserve current data
	preserve

	// Process files
	if "`separate'" != "" {
		ProcessSeparate `"`filelist_tmp'"' `"`names_tmp'"' ///
			`"`title'"' `"`subtitle'"' `"`version'"' `"`author'"' `"`date'"' ///
			`"`notes'"' `"`changelog'"' `nfiles' "`missing'" "`stats'" `maxcat' `maxfreq'
	}
	else {
		ProcessCombined `"`filelist_tmp'"' `"`names_tmp'"' `"`output'"' ///
			`"`title'"' `"`subtitle'"' `"`version'"' `"`author'"' `"`date'"' ///
			`"`notes'"' `"`changelog'"' `nfiles' "`missing'" "`stats'" `maxcat' `maxfreq'
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
end

// =============================================================================
// Helper: CollectFromFilelistOption
// Parse space-separated dataset names and write to temp file
// =============================================================================
program define CollectFromFilelistOption
	args filelist tmpfile

	tempname fh_out
	file open `fh_out' using `"`tmpfile'"', write text replace

	// Parse the space-separated list
	local remaining `"`filelist'"'
	while `"`remaining'"' != "" {
		gettoken dsname remaining : remaining
		if `"`dsname'"' != "" {
			// Add .dta extension if not present
			local dsname = cond(regexm(`"`dsname'"', "\.dta$"), `"`dsname'"', `"`dsname'.dta"')
			// Check file exists
			capture confirm file `"`dsname'"'
			if _rc != 0 {
				di as error `"file `dsname' not found"'
				file close `fh_out'
				exit 601
			}
			file write `fh_out' `"`dsname'"' _n
		}
	}
	file close `fh_out'
end

// =============================================================================
// Helper: CollectFromDir
// =============================================================================
program define CollectFromDir
	args directory recursive tmpfile

	tempname fh
	file open `fh' using `"`tmpfile'"', write text replace

	if "`recursive'" == "" {
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
		RecursiveScan `"`directory'"' `fh'
	}

	file close `fh'
end

program define RecursiveScan
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
				RecursiveScan `"`directory'/`subdir'"' `fh'
			}
			else {
				RecursiveScan `"`subdir'"' `fh'
			}
		}
	}
end

// =============================================================================
// Helper: CountFiles
// =============================================================================
program define CountFiles, rclass
	args tmpfile

	tempname fh
	file open `fh' using `"`tmpfile'"', read text
	local nfiles 0
	file read `fh' line
	while r(eof) == 0 {
		local ++nfiles
		file read `fh' line
	}
	file close `fh'

	return scalar nfiles = `nfiles'
end

// =============================================================================
// Helper: CollectDatasetNames - extract display names for TOC
// =============================================================================
program define CollectDatasetNames
	args filelist namesfile nfiles

	tempname fh_in fh_out
	file open `fh_in' using `"`filelist'"', read text
	file open `fh_out' using `"`namesfile'"', write text replace

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
program define MakeAnchor, rclass
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
program define EscapeMarkdown, rclass
	args text

	local escaped `"`macval(text)'"'
	local escaped = subinstr(`"`macval(escaped)'"', "|", "\|", .)
	local escaped = subinstr(`"`macval(escaped)'"', "`", "\`", .)

	return local escaped `"`macval(escaped)'"'
end

// =============================================================================
// Helper: ProcessCombined
// =============================================================================
program define ProcessCombined
	args filelist namesfile output title subtitle version author date notes changelog nfiles showmissing showstats maxcat maxfreq

	di as text `"Creating Markdown dictionary: `output'"'

	tempname fh
	file open `fh' using `"`output'"', write text replace

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
		// Parse basename|label
		local pipepos = strpos(`"`nameline'"', "|")
		if `pipepos' > 0 {
			local dsname = substr(`"`nameline'"', 1, `pipepos'-1)
		}
		else {
			local dsname `"`nameline'"'
		}

		// Create anchor
		MakeAnchor `i' `"`dsname'"'
		local anchor = r(anchor)

		// Format display name (capitalize, replace _ with space)
		local dispname = proper(subinstr(`"`dsname'"', "_", " ", .))

		file write `fh' `"`i'. [`dispname'](#`anchor')"' _n

		file read `fh_names' nameline
	}
	file close `fh_names'

	// Add Notes and Change Log to TOC
	local notesidx = `nfiles' + 1
	local chlogidx = `nfiles' + 2
	file write `fh' `"`notesidx'. [Notes](#notes)"' _n
	file write `fh' `"`chlogidx'. [Change Log](#change-log)"' _n
	file write `fh' _n "---" _n _n

	// Process each dataset
	tempname fh_list fh_names2
	file open `fh_list' using `"`filelist'"', read text
	file open `fh_names2' using `"`namesfile'"', read text

	local i 0
	file read `fh_list' filepath
	file read `fh_names2' nameline
	while r(eof) == 0 {
		local ++i

		// Parse name
		local pipepos = strpos(`"`nameline'"', "|")
		if `pipepos' > 0 {
			local dsname = substr(`"`nameline'"', 1, `pipepos'-1)
			local dslabel = substr(`"`nameline'"', `pipepos'+1, .)
		}
		else {
			local dsname `"`nameline'"'
			local dslabel ""
		}

		di as text "  Processing `i' of `nfiles': `dsname'"

		ProcessOneDataset `fh' `"`macval(filepath)'"' `"`dsname'"' `"`macval(dslabel)'"' `i' "`showmissing'" "`showstats'" `maxcat' `maxfreq'

		file read `fh_list' filepath
		file read `fh_names2' nameline
	}
	file close `fh_list'
	file close `fh_names2'

	// Notes section
	file write `fh' "## Notes" _n _n
	if `"`notes'"' != "" {
		// Read notes from file
		capture confirm file `"`notes'"'
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
			file write `fh' `"- Notes file not found: `notes'"' _n
		}
	}
	else {
		file write `fh' "- All date variables are formatted as %tdCCYY/NN/DD (Stata date format)" _n
		file write `fh' "- Missing values for categorical variables are typically coded as . (numeric missing) or empty string" _n
		file write `fh' "- All datasets contain anonymous identifiers for linking" _n
	}
	file write `fh' _n "---" _n _n

	// Change Log section
	file write `fh' "## Change Log" _n _n
	if `"`changelog'"' != "" {
		capture confirm file `"`changelog'"'
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
			file write `fh' `"Changelog file not found: `changelog'"' _n
		}
	}
	else {
		file write `fh' "*No changes recorded.*" _n
	}
	file write `fh' _n "---" _n _n

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
program define ProcessSeparate
	args filelist namesfile title subtitle version author date notes changelog nfiles showmissing showstats maxcat maxfreq

	tempname fh_list fh_names
	file open `fh_list' using `"`filelist'"', read text
	file open `fh_names' using `"`namesfile'"', read text

	file read `fh_list' filepath
	file read `fh_names' nameline
	while r(eof) == 0 {
		// Parse name
		local pipepos = strpos(`"`nameline'"', "|")
		if `pipepos' > 0 {
			local dsname = substr(`"`nameline'"', 1, `pipepos'-1)
			local dslabel = substr(`"`nameline'"', `pipepos'+1, .)
		}
		else {
			local dsname `"`nameline'"'
			local dslabel ""
		}

		local outfile `"`dsname'_dictionary.md"'
		di as text `"Creating: `outfile'"'

		tempname fh
		file open `fh' using `"`outfile'"', write text replace

		// Header
		file write `fh' `"# `macval(title)': `dsname'"' _n _n
		if `"`subtitle'"' != "" {
			file write `fh' `"`macval(subtitle)'"' _n _n
		}
		if `"`version'"' != "" {
			file write `fh' `"Version `version'"' _n _n
		}
		file write `fh' "---" _n _n

		// Process dataset
		ProcessOneDataset `fh' `"`macval(filepath)'"' `"`dsname'"' `"`macval(dslabel)'"' 1 "`showmissing'" "`showstats'" `maxcat' `maxfreq'

		// Notes
		file write `fh' "## Notes" _n _n
		file write `fh' "- All date variables are formatted as %tdCCYY/NN/DD (Stata date format)" _n
		file write `fh' "- Missing values coded as . (numeric missing) or empty string" _n
		file write `fh' _n "---" _n _n

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
program define ProcessOneDataset
	args fh filepath dsname dslabel idx showmissing showstats maxcat maxfreq

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

	// Load dataset (already preserved by main program)
	quietly use `"`macval(filepath)'"', clear

	// Process each variable
	quietly describe, varlist
	local allvars `r(varlist)'

	foreach vn of local allvars {
		WriteVariableRow `fh' `"`vn'"' `obs' "`showmissing'" "`showstats'" `maxcat' `maxfreq'
	}

	file write `fh' _n "---" _n _n
end

// =============================================================================
// Helper: WriteVariableRow
// =============================================================================
program define WriteVariableRow
	args fh vname obs showmissing showstats maxcat maxfreq

	local vtype: type `vname'
	local vfmt: format `vname'
	local vlab: variable label `vname'
	local vallabname: value label `vname'

	// Escape pipes and backticks in label
	EscapeMarkdown `"`macval(vlab)'"'
	local vlab_safe `"`r(escaped)'"'

	// Determine Type column
	local typestr "Numeric"
	local varclass "continuous"
	if substr("`vtype'", 1, 3) == "str" {
		local typestr "String"
		local varclass "string"
	}
	else if strpos("`vfmt'", "%t") > 0 | strpos("`vfmt'", "%d") > 0 {
		local typestr "Date"
		local varclass "date"
	}
	else {
		// Check if categorical
		if "`vallabname'" != "" {
			local varclass "categorical"
		}
		else {
			// Check unique values
			capture quietly tab `vname'
			if _rc == 0 & r(r) <= `maxcat' {
				local varclass "categorical"
			}
		}
	}

	// Calculate missing if requested
	local missingstr ""
	if "`showmissing'" != "" {
		quietly count if missing(`vname')
		local nmiss = r(N)
		if `obs' > 0 {
			local pctmiss = string(round(100 * `nmiss' / `obs', 0.1), "%9.1f")
			local pctmiss = strtrim("`pctmiss'")
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
			// Show frequencies for categorical
			if "`vallabname'" != "" {
				GetValueLabelString `"`vname'"' `"`vallabname'"' `maxfreq'
				local valsnotes `"`r(valstring)'"'
			}
			else {
				// Numeric without labels - show unique count
				capture quietly tab `vname'
				if _rc == 0 {
					local nuniq = r(r)
					if `nuniq' <= `maxfreq' {
						GetUnlabeledFreqs `"`vname'"' `maxfreq'
						local valsnotes `"`r(valstring)'"'
					}
					else {
						local valsnotes "`nuniq' unique values"
					}
				}
			}
		}
		else if "`varclass'" == "continuous" {
			// Show summary stats for continuous
			quietly summarize `vname', detail
			if r(N) > 0 {
				// Get unique values count
				capture quietly tab `vname'
				if _rc == 0 {
					local nuniq = r(r)
				}
				else {
					local nuniq "many"
				}
				// Format all statistics with consistent precision
				local mean = string(r(mean), "%9.2f")
				local mean = strtrim("`mean'")
				local sd = string(r(sd), "%9.2f")
				local sd = strtrim("`sd'")
				local min = string(r(min), "%9.2f")
				local min = strtrim("`min'")
				local p25 = string(r(p25), "%9.2f")
				local p25 = strtrim("`p25'")
				local p50 = string(r(p50), "%9.2f")
				local p50 = strtrim("`p50'")
				local p75 = string(r(p75), "%9.2f")
				local p75 = strtrim("`p75'")
				local max = string(r(max), "%9.2f")
				local max = strtrim("`max'")
				// Format for markdown cell with line breaks
				local valsnotes "N unique: `nuniq' | Mean: `mean' | SD: `sd' | Min: `min' | P25: `p25' | Median: `p50' | P75: `p75' | Max: `max'"
			}
			else {
				local valsnotes "All missing"
			}
		}
		else if "`varclass'" == "date" {
			// Show date range
			quietly summarize `vname'
			if r(N) > 0 {
				local mindate = string(r(min), "`vfmt'")
				local maxdate = string(r(max), "`vfmt'")
				local valsnotes "Range: `mindate' to `maxdate'"
			}
			else {
				local valsnotes "All missing"
			}
		}
		else if "`varclass'" == "string" {
			// Show unique count for strings
			capture quietly tab `vname'
			if _rc == 0 {
				local valsnotes "`r(r)' unique values"
			}
			else {
				local valsnotes "High cardinality"
			}
		}
	}
	else {
		// Original behavior - just show value labels or basic info
		if "`vallabname'" != "" {
			GetValueLabelString `"`vname'"' `"`vallabname'"' `maxfreq'
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
			// Numeric without value labels - check if identifier or continuous
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
program define GetValueLabelString, rclass
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
// Helper: GetUnlabeledFreqs - get frequencies for unlabeled categorical vars
// =============================================================================
program define GetUnlabeledFreqs, rclass
	args vname maxlevels

	capture quietly levelsof `vname' if !missing(`vname'), local(levels)
	if _rc != 0 | `"`levels'"' == "" {
		return local valstring ""
		exit
	}

	local nlevels: word count `levels'
	if `nlevels' > `maxlevels' {
		return local valstring "`nlevels' unique values"
		exit
	}

	local valstring ""
	local first 1
	foreach lev of local levels {
		if `first' {
			local valstring "`lev'"
			local first 0
		}
		else {
			local valstring `"`valstring', `lev'"'
		}

		if length(`"`valstring'"') > 150 {
			local valstring = substr(`"`valstring'"', 1, 147) + "..."
			continue, break
		}
	}

	return local valstring `"`valstring'"'
end
