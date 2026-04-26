*! datamap Version 1.0.0  2026/04/08
*! Generate privacy-safe LLM-readable dataset documentation
*! Author: Timothy P. Copeland

/*
SYNTAX
------
datamap [, options]

OPTIONS
-------
Input:
  (none)              If no input option given, documents data in memory
  directory(path)     Directory to scan for .dta files (default: current directory)
  filelist(datasets)  Space-separated list of dataset names to process
  single(filename)    Single .dta file to process
  recursive           Scan subdirectories recursively

Output:
  output(filename)    Output file (default: datamap.txt)
  format(type)        text (default: text)
  separate            Create separate output file per dataset
  append              Append to existing output file (note: does not add headers)

Content Control:
  nostats             Suppress summary statistics for continuous variables
  nofreq              Suppress frequency tables for categorical variables
  nolabels            Suppress value label definitions
  maxfreq(#)          Max unique values to show frequency table (default: 25)
  maxcat(#)           Max unique values to treat as categorical (default: 25)

Privacy:
  exclude(varlist)    Variables to document structure only (no values/stats)
  datesafe            For date variables, show range span only (not exact dates)

DESCRIPTION
-----------
datamap generates privacy-safe documentation of Stata dataset structures for
LLM-assisted coding. Exports metadata and aggregate statistics without
observation-level data. All output is aggregate-level; no cross-variable
combinations or individual observations are exported.

The current dataset in memory is preserved and restored after processing.

VARIABLE CLASSIFICATION
-----------------------
categorical: numeric with value labels OR <= maxcat unique values
continuous:  numeric with > maxcat unique values
date:        has Stata date/time format (%t*)
string:      string storage type
excluded:    listed in exclude() option

EXAMPLES
--------
. datamap
. datamap, directory("X:/data") recursive output(datadoc.txt)
. datamap, single(analysis) format(text)
. datamap, filelist(patients hrt dmt) output(combined.txt)
. datamap, exclude(patient_id clinic_id) datesafe

STORED RESULTS
--------------
r(nfiles)        - number of datasets processed
r(nobs)          - number of observations (single-file/memory mode)
r(nvars)         - number of variables (single-file/memory mode)
r(format)        - output format used (text)
r(output)        - output filename (for combined mode)
r(input_source)  - input mode (memory, single, directory, filelist)

NOTES
-----
- Text format for LLM context (readable, structured)
- No observation-level data exported
- Use exclude() for sensitive identifiers
- Use datesafe if exact dates are sensitive
- The current dataset in memory is preserved and restored after processing
- The .dta extension is optional and assumed if not specified
*/

program define datamap, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
	syntax [, DIRectory(string) FILElist(string) SINGLE(string) ///
	          RECursive ///
	          Output(string) Format(string) SEParate APPend ///
	          NOSTats NOFReq NOLAbels ///
	          MAXFreq(integer 25) MAXCat(integer 25) ///
	          EXClude(string) DATESafe DATEFormat(string) ///
	          DETect(string) AUTODETect PANELid(string) ///
	          SURVIVALvars(string) QUality QUality2(string) ///
	          SAMples(integer 0) MISSing(string)]

	// Set default date format (ISO 8601: YYYY/MM/DD)
	if `"`dateformat'"' == "" local dateformat "%tdCCYY/NN/DD"
	
	// Preserve current dataset
	preserve

	// Validate mutually exclusive input options (only one allowed)
	local ninput = ("`directory'" != "") + ("`filelist'" != "") + ("`single'" != "")
	if `ninput' > 1 {
		noisily di as error "specify only one of directory(), filelist(), or single()"
		exit 198
	}

	// If no input specified, document data currently in memory
	local input_source ""
	if `ninput' == 0 {
		if c(N) == 0 | c(k) == 0 {
			noisily di as error "no data in memory and no input specified"
			noisily di as error "specify directory(), filelist(), single(), or load data first"
			exit 198
		}
		tempfile memdata
		quietly save "`memdata'"
		local single "`memdata'"
		local input_source "memory"
	}
	else if "`single'" != "" {
		local input_source "single"
	}
	else if "`directory'" != "" {
		local input_source "directory"
	}
	else {
		local input_source "filelist"
	}
	
	// Set defaults for output format
	if "`format'" == "" local format "text"
	if !inlist("`format'", "text") {
		noisily di as error "format() currently only supports 'text'"
		exit 198
	}
	
	// Set default output filename
	if "`output'" == "" {
		local output "datamap.txt"
	}
	
	// Validate numeric parameters
	if `maxfreq' <= 0 {
		di as error "maxfreq must be positive"
		exit 198
	}
	if `maxcat' <= 0 {
		di as error "maxcat must be positive"
		exit 198
	}
	if `samples' < 0 {
		di as error "samples must be non-negative"
		exit 198
	}

	// Parse and validate detect() option
	local detect_panel 0
	local detect_binary 0
	local detect_survival 0
	local detect_survey 0
	local detect_common 0

	if "`autodetect'" != "" {
		local detect_panel 1
		local detect_binary 1
		local detect_survival 1
		local detect_survey 1
		local detect_common 1
	}

	if "`detect'" != "" {
		// Parse comma-separated list
		local detect_opts "`detect'"
		while "`detect_opts'" != "" {
			gettoken opt detect_opts : detect_opts, parse(" ")
			if "`opt'" == "panel" local detect_panel 1
			else if "`opt'" == "binary" local detect_binary 1
			else if "`opt'" == "survival" local detect_survival 1
			else if "`opt'" == "survey" local detect_survey 1
			else if "`opt'" == "common" local detect_common 1
			else if "`opt'" != "" {
				di as error "detect() option '`opt'' not recognized"
				di as error "Valid options: panel, binary, survival, survey, common"
				exit 198
			}
		}
	}

	// Parse quality option
	local quality_level ""
	if "`quality'" != "" {
		local quality_level "basic"
	}
	if "`quality2'" != "" {
		if "`quality2'" == "strict" {
			local quality_level "strict"
		}
		else {
			di as error "quality() must be 'strict' if specified"
			exit 198
		}
	}

	// Parse missing option
	local missing_detail 0
	local missing_pattern 0
	if "`missing'" != "" {
		if "`missing'" == "detail" {
			local missing_detail 1
		}
		else if "`missing'" == "pattern" {
			local missing_detail 1
			local missing_pattern 1
		}
		else {
			di as error "missing() must be 'detail' or 'pattern'"
			exit 198
		}
	}
	
	// Collect files to process based on input method
	tempfile filelist_tmp  // Temporary file to hold file paths
	if "`single'" != "" {
		// Single file mode: process one specified file
		// Add .dta extension if not present (skip for in-memory tempfiles)
		if "`input_source'" != "memory" {
			if !regexm(`"`single'"', "\.dta$") {
				local single `"`single'.dta"'
			}
		}
		confirm file `"`single'"'
		local nfiles 1
	}
	else if "`filelist'" != "" {
		// File list mode: parse space-separated dataset names
		_datamap_CollectFilelist `"`filelist'"' `"`filelist_tmp'"'
		// Count lines in the temp file
		tempname fh
		file open `fh' using `"`filelist_tmp'"', read text
		local nfiles 0
		file read `fh' line
		while r(eof) == 0 {
			local ++nfiles
			file read `fh' line
		}
		file close `fh'
	}
	else {
		// Directory scan mode: find all .dta files in directory
		if "`directory'" == "" local directory "."
		_datamap_CollectFromDir `"`directory'"' "`recursive'" `"`filelist_tmp'"'
		// Count lines in the temp file
		tempname fh
		file open `fh' using `"`filelist_tmp'"', read text
		local nfiles 0
		file read `fh' line
		while r(eof) == 0 {
			local ++nfiles
			file read `fh' line
		}
		file close `fh'
	}
	
	// Error if no files found (except in single file mode)
	if "`single'" == "" {
		if `nfiles' == 0 {
			di as error "no .dta files found"
			exit 601
		}
	}
	
	// Process files and generate output
	if "`separate'" != "" {
		// Generate separate output file per dataset
		_datamap_ProcessSeparate, filelist("`filelist_tmp'") format(`format') ///
			`nostats' `nofreq' `nolabels' ///
			maxfreq(`maxfreq') maxcat(`maxcat') ///
			exclude(`exclude') `datesafe' dateformat(`dateformat') nfiles(`nfiles') ///
			detect_panel(`detect_panel') detect_binary(`detect_binary') ///
			detect_survival(`detect_survival') detect_survey(`detect_survey') ///
			detect_common(`detect_common') panelid(`panelid') ///
			survivalvars(`survivalvars') quality_level(`quality_level') ///
			samples(`samples') missing_detail(`missing_detail') ///
			missing_pattern(`missing_pattern')
	}
	else {
		// Generate single combined output file
		_datamap_ProcessCombined, filelist("`filelist_tmp'") output(`output') format(`format') ///
			`append' `nostats' `nofreq' ///
			`nolabels' maxfreq(`maxfreq') ///
			maxcat(`maxcat') exclude(`exclude') `datesafe' ///
			dateformat(`dateformat') single(`single') nfiles(`nfiles') ///
			detect_panel(`detect_panel') detect_binary(`detect_binary') ///
			detect_survival(`detect_survival') detect_survey(`detect_survey') ///
			detect_common(`detect_common') panelid(`panelid') ///
			survivalvars(`survivalvars') quality_level(`quality_level') ///
			samples(`samples') missing_detail(`missing_detail') ///
			missing_pattern(`missing_pattern')
	}
		
	// Collect metadata for return values (before restore clears tempfiles)
	local nobs_total .
	local nvars_total .
	if "`single'" != "" {
		capture quietly describe using "`single'", short
		if _rc == 0 {
			local nobs_total = r(N)
			local nvars_total = r(k)
		}
	}

	// Restore original dataset
	restore

	// Return results
	return scalar nfiles = `nfiles'
	if `nobs_total' < . {
		return scalar nobs = `nobs_total'
		return scalar nvars = `nvars_total'
	}
	return local format "`format'"
	return local output "`output'"
	return local input_source "`input_source'"

	di as text "Documentation generated successfully"
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: _datamap_CollectFilelist
// Parse space-separated dataset names and write to temp file
// =============================================================================
program define _datamap_CollectFilelist
	version 16.0
	args filelist tmpfile

	tempname fh_out
	quietly file open `fh_out' using "`tmpfile'", write text replace

	// Parse the space-separated list
	local remaining `"`filelist'"'
	while `"`remaining'"' != "" {
		gettoken dsname remaining : remaining
		if `"`dsname'"' != "" {
			// Add .dta extension if not present
			if !regexm(`"`dsname'"', "\.dta$") {
				local dsname `"`dsname'.dta"'
			}
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
// Helper: _datamap_CollectFromDir
// Scan directory for .dta files, optionally recursive
// Write output to text file
// =============================================================================
program define _datamap_CollectFromDir
	version 16.0
	args directory recursive tmpfile

	tempname fh
	quietly file open `fh' using "`tmpfile'", write text replace

	if "`recursive'" == "" {
		// Non-recursive: simple directory scan
		local files : dir "`directory'" files "*.dta"

		foreach f of local files {
			// Prepend directory path if not current directory
			if "`directory'" != "." {
				file write `fh' "`directory'/`f'" _n
			}
			else {
				file write `fh' "`f'" _n
			}
		}
	}
	else {
		// Recursive: scan subdirectories
		_datamap_RecursiveScan "`directory'" `fh'
	}

	file close `fh'
end

// Helper for recursive scanning
program define _datamap_RecursiveScan
	version 16.0
	args directory fh

	// Get files in current directory
	local files : dir "`directory'" files "*.dta"
	foreach f of local files {
		if "`directory'" != "." {
			file write `fh' "`directory'/`f'" _n
		}
		else {
			file write `fh' "`f'" _n
		}
	}

	// Get subdirectories and recurse
	local subdirs : dir "`directory'" dirs "*"
	foreach subdir of local subdirs {
		// Skip hidden directories and common excludes
		if substr("`subdir'", 1, 1) != "." & "`subdir'" != "__pycache__" {
			if "`directory'" != "." {
				_datamap_RecursiveScan "`directory'/`subdir'" `fh'
			}
			else {
				_datamap_RecursiveScan "`subdir'" `fh'
			}
		}
	}
end

// =============================================================================
// Helper: _datamap_ProcessCombined
// Generate single output file containing all datasets
// =============================================================================
program define _datamap_ProcessCombined
	version 16.0
	syntax, filelist(string) output(string) format(string) [append ///
		NOSTats NOFReq NOLAbels maxfreq(integer 25) ///
		maxcat(integer 25) exclude(string) datesafe dateformat(string) ///
		single(string) nfiles(integer 1) ///
		detect_panel(integer 0) detect_binary(integer 0) detect_survival(integer 0) ///
		detect_survey(integer 0) detect_common(integer 0) panelid(string) ///
		survivalvars(string) quality_level(string) samples(integer 0) ///
		missing_detail(integer 0) missing_pattern(integer 0)]

	// Open output file (append or replace mode)
	tempname fh
	if "`append'" != "" {
		file open `fh' using "`output'", write text append
	}
	else {
		file open `fh' using "`output'", write text replace

		// Write header for text format
		local cdate = c(current_date)
		local ctime = c(current_time)
		file write `fh' "Dataset Documentation" _n
		file write `fh' "Generated: `cdate' `ctime'" _n _n
	}

	// Process each file in list

	if "`single'" != "" {
		// Single file mode
		_datamap_ProcessDataset `fh' "`single'" "`format'" "`nostats'" "`nofreq'" ///
			"`nolabels'" `maxfreq' `maxcat' "`exclude'" "`datesafe'" 1 1 ///
			`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
			"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
			`missing_detail' `missing_pattern' "`dateformat'"
	}
	else {
		// Multiple files from list - read from file
		tempname fh_list
		file open `fh_list' using "`filelist'", read text
		local i 0
		file read `fh_list' thisfile
		while r(eof) == 0 {
			local ++i
			_datamap_ProcessDataset `fh' "`thisfile'" "`format'" "`nostats'" "`nofreq'" ///
				"`nolabels'" `maxfreq' `maxcat' "`exclude'" "`datesafe'" `i' `nfiles' ///
				`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
				"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
				`missing_detail' `missing_pattern' "`dateformat'"
			file read `fh_list' thisfile
		}
		file close `fh_list'
	}

	// Always close file handle
	file close `fh'
	noisily di as result `"Output written to: `output'"'
end

// =============================================================================
// Helper: _datamap_ProcessSeparate
// Generate separate output file for each dataset
// =============================================================================
program define _datamap_ProcessSeparate
	version 16.0
	syntax, filelist(string) format(string) [NOSTats NOFReq NOLAbels ///
		maxfreq(integer 25) maxcat(integer 25) exclude(string) datesafe ///
		dateformat(string) nfiles(integer 1) ///
		detect_panel(integer 0) detect_binary(integer 0) detect_survival(integer 0) ///
		detect_survey(integer 0) detect_common(integer 0) panelid(string) ///
		survivalvars(string) quality_level(string) samples(integer 0) ///
		missing_detail(integer 0) missing_pattern(integer 0)]

	// Loop through each file and generate separate output
	tempname fh_list
	file open `fh_list' using "`filelist'", read text
	file read `fh_list' thisfile
	while r(eof) == 0 {

		// Determine output filename from dataset name
		local len = length("`thisfile'")
		if substr("`thisfile'", `len'-3, 4) == ".dta" {
			local basename = substr("`thisfile'", 1, `len'-4)
		}
		else {
			local basename "`thisfile'"
		}
		local outfile "`basename'_map.txt"

		// Open output file for this dataset
		tempname fh
		quietly file open `fh' using "`outfile'", write text replace

		// Process with error handling
		capture noisily {
			// Write header for text format
			local cdate = c(current_date)
			local ctime = c(current_time)
			file write `fh' "Dataset Documentation" _n
			file write `fh' "Generated: `cdate' `ctime'" _n _n

			// Process this dataset
			_datamap_ProcessDataset `fh' "`thisfile'" "`format'" "`nostats'" "`nofreq'" ///
				"`nolabels'" `maxfreq' `maxcat' "`exclude'" "`datesafe'" 1 1 ///
				`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
				"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
				`missing_detail' `missing_pattern' "`dateformat'"
		}
		local rc = _rc

		// Always close file handle
		capture file close `fh'

		// Re-throw error if one occurred
		if `rc' {
			file close `fh_list'
			noisily di as error "Error processing `thisfile' (rc=`rc')"
			exit `rc'
		}
		noisily di as result `"Output written to: `outfile'"'

		file read `fh_list' thisfile
	}
	file close `fh_list'
end

// =============================================================================
// Helper: _datamap_ProcessDataset
// Process single dataset and write documentation to file handle
// Args: fh filepath format nostats nofreq nolabels maxfreq maxcat
//       exclude datesafe idx total detect_panel detect_binary detect_survival
//       detect_survey detect_common panelid survivalvars quality_level samples
//       missing_detail missing_pattern
// =============================================================================
program define _datamap_ProcessDataset
	version 16.0
	args fh filepath format nostats nofreq nolabels maxfreq maxcat exclude datesafe idx total ///
	     detect_panel detect_binary detect_survival detect_survey detect_common ///
	     panelid survivalvars quality_level samples missing_detail missing_pattern dateformat

	// Get dataset metadata from describe
	capture quietly describe using "`filepath'", short
	if _rc != 0 {
		noisily di as error "    ERROR: Could not describe file `filepath' (rc=`=_rc')"
		exit _rc
	}
	local obs = r(N)
	local nvars = r(k)
	local sortorder "`r(sortlist)'"

	// Load dataset to get label and datasignature
	quietly {
		capture use "`filepath'", clear
		if _rc != 0 {
			noisily di as error "    ERROR: Could not load `filepath' (rc=`=_rc')"
			exit _rc
		}
	}
	local label : data label

	// Get datasignature
	local dsig ""
	quietly capture datasignature
	if _rc == 0 {
		local dsig "`r(datasignature)'"
	}

	// Get file system info - extract basename from filepath
	// Normalize slashes first to handle mixed path separators (Windows/Unix)
	local normalized_path = subinstr("`filepath'", "\", "/", .)
	local basename = "`normalized_path'"

	// Extract filename from normalized path
	if strpos("`normalized_path'", "/") > 0 {
		local basename = reverse("`normalized_path'")
		local slashpos = strpos("`basename'", "/")
		if `slashpos' > 0 {
			local basename = reverse(substr("`basename'", 1, `slashpos'-1))
		}
		else {
			local basename = "`normalized_path'"
		}
	}

	// Write dataset header based on format
	if `idx' > 1 file write `fh' _n _n

	// LLM-optimized header with structured sections
	file write `fh' "========================================" _n
	file write `fh' "DATASET: `basename'" _n
	file write `fh' "========================================" _n _n

	file write `fh' "METADATA" _n
	file write `fh' "--------" _n
	file write `fh' "Observations: `obs'" _n
	file write `fh' "Variables: `nvars'" _n
	if `"`label'"' != "" & `"`label'"' != "." {
		file write `fh' `"Label: `label'"' _n
	}
	if "`dsig'" != "" {
		file write `fh' "Data Signature: `dsig'" _n
	}

	// Add sort order if set
	if "`sortorder'" != "" {
		file write `fh' "Sort Order: `sortorder'" _n
	}
	file write `fh' _n

	// Generate natural language summary
	_datamap_GenerateDatasetSummary `fh' "`filepath'" `obs' `nvars' "`label'" ///
		`detect_panel' `detect_survival' "`panelid'" "`dateformat'" "`datesafe'"

	// Run detection features if requested
	if `detect_panel' | "`panelid'" != "" {
		_datamap_DetectPanel `fh' "`filepath'" "`panelid'" "`format'"
	}
	if `detect_survival' | "`survivalvars'" != "" {
		_datamap_DetectSurvival `fh' "`filepath'" "`survivalvars'" "`format'"
	}
	if `detect_survey' {
		_datamap_DetectSurvey `fh' "`filepath'" "`format'"
	}
	if `detect_common' {
		_datamap_DetectCommon `fh' "`filepath'" "`format'"
	}
	if `missing_detail' | `missing_pattern' {
		_datamap_SummarizeMissing `fh' "`filepath'" "`format'" `missing_pattern' `obs'
	}

	// Process all variables in the dataset
	_datamap_ProcessVariables `fh' "`filepath'" "`format'" "`nostats'" "`nofreq'" ///
		"`nolabels'" `maxfreq' `maxcat' "`exclude'" "`datesafe'" `obs' ///
		`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
		"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
		`missing_detail' `missing_pattern' "`dateformat'"
end

// =============================================================================
// Helper: _datamap_ProcessVariables
// Classify and document all variables in a dataset
// =============================================================================
program define _datamap_ProcessVariables
	version 16.0
	args fh filepath format nostats nofreq nolabels maxfreq maxcat exclude datesafe obs ///
	     detect_panel detect_binary detect_survival detect_survey detect_common ///
	     panelid survivalvars quality_level samples missing_detail missing_pattern dateformat

	// Get variable metadata using describe
	tempfile varinfo
	capture use "`filepath'", clear
	if _rc != 0 {
		noisily di as error "      ERROR: Could not load `filepath' (rc=`=_rc')"
		exit _rc
	}
	quietly {
		describe, replace clear

		// Describe output has: name, type, isnumeric, format, vallab, varlab
		// Rename to more intuitive names and add our tracking columns
		rename name varname
		rename type vartype
		rename format varformat
		rename varlab varlabel_orig
		rename vallab valuelabel_orig

		gen varlabel = varlabel_orig
		gen valuelabel = valuelabel_orig
		gen double missing_n = .
		gen double missing_pct = .
		gen classification = ""
		gen double unique_vals = .
		gen is_binary = 0
		gen quality_flag = ""
		gen int orig_position = _n

		save "`varinfo'", replace
	}

	local nvars = _N

	// Parse exclude list for privacy-sensitive variables
	if "`exclude'" != "" {
		local exclude_vars "`exclude'"
	}

	// Write variable summary table header with structured sections
	file write `fh' "========================================" _n
	file write `fh' "VARIABLE SUMMARY" _n
	file write `fh' "========================================" _n _n

	// First pass: classify all variables and compute basic stats
	tempfile classifications

	// PERFORMANCE OPTIMIZATION: Load user dataset ONCE and collect all stats
	// instead of loading it repeatedly for each variable

	// Extract variable metadata from varinfo first
	local vnames ""
	local vtypes ""
	local vfmts ""
	forvalues i = 1/`nvars' {
		local vn = varname[`i']
		local vnames "`vnames' `vn'"
		local vt = vartype[`i']
		local vtypes "`vtypes' `vt'"
		local vf = varformat[`i']
		local vfmts "`vfmts' `vf'"
		local va_`i' = valuelabel[`i']
	}

	// Now load the user dataset ONCE for all statistics calculations
	quietly use "`filepath'", clear

	// Initialize matrices to store results
	tempname miss_n miss_pct uniq_vals is_bin
	matrix `miss_n' = J(`nvars', 1, .)
	matrix `miss_pct' = J(`nvars', 1, .)
	matrix `uniq_vals' = J(`nvars', 1, .)
	matrix `is_bin' = J(`nvars', 1, 0)

	// Store classifications and quality flags in locals (strings)
	forvalues i = 1/`nvars' {
		local class_`i' ""
		local qflag_`i' ""
	}

	// Calculate statistics for all variables in single pass through data
	local i = 0
	foreach vname of local vnames {
		local ++i
		local vtype : word `i' of `vtypes'
		local vfmt : word `i' of `vfmts'
		local valab "`va_`i''"

		// Calculate missing count
		quietly count if missing(`vname')
		local nmiss = r(N)
		matrix `miss_n'[`i', 1] = `nmiss'
		if `obs' > 0 {
			matrix `miss_pct'[`i', 1] = round(100*`nmiss'/`obs', 0.1)
		}

		// Classify variable
		local isexcluded 0
		foreach ev of local exclude_vars {
			if "`vname'" == "`ev'" local isexcluded 1
		}

		if `isexcluded' {
			local class_`i' "excluded"
		}
		else if strpos("`vtype'", "str") == 1 {
			local class_`i' "string"
		}
		else if strpos("`vfmt'", "%t") > 0 | strpos("`vfmt'", "%d") > 0 {
			local class_`i' "date"
		}
		else {
			// For numeric variables: check value label FIRST (more efficient)
			// If labeled, treat as categorical without expensive tabulation
			if "`valab'" != "" {
				local class_`i' "categorical"
				// Still need unique count for reporting, but use faster method
				capture quietly tab `vname'
				if _rc == 0 {
					matrix `uniq_vals'[`i', 1] = r(r)
					if `detect_binary' & r(r) == 2 {
						matrix `is_bin'[`i', 1] = 1
					}
				}
				else {
					// tab failed (>32K unique values) — get count via duplicates
					capture quietly duplicates report `vname'
					if _rc == 0 {
						matrix `uniq_vals'[`i', 1] = r(unique_value)
					}
				}
			}
			else {
				// No value label - need to check cardinality
				capture quietly tab `vname'
				if _rc == 0 {
					local nuniq = r(r)
					matrix `uniq_vals'[`i', 1] = `nuniq'

					if `nuniq' <= `maxcat' {
						local class_`i' "categorical"
					}
					else {
						local class_`i' "continuous"
					}

					// Check if binary (for detect_binary option)
					if `detect_binary' & `nuniq' == 2 {
						matrix `is_bin'[`i', 1] = 1
					}
				}
				else {
					// Tab failed (>32K unique values) — get actual count
					capture quietly duplicates report `vname'
					if _rc == 0 {
						local nuniq = r(unique_value)
						matrix `uniq_vals'[`i', 1] = `nuniq'
					}
					else {
						matrix `uniq_vals'[`i', 1] = .
					}
					local class_`i' "continuous"
				}
			}
		}

		// Quality checks if requested (while we have the data in memory)
		if "`quality_level'" != "" & !`isexcluded' {
			local qflag ""

			// Check for implausible values based on variable name
			if regexm(lower("`vname'"), "^age$|^age_|_age$|_age_") {
				quietly summarize `vname'
				if !missing(r(min)) & r(min) < 0 {
					local qflag "negative age values"
				}
				else if !missing(r(max)) {
					if "`quality_level'" == "strict" & r(max) > 100 {
						local qflag "age >100"
					}
					else if r(max) > 120 {
						local qflag "age >120"
					}
				}
			}
			else if regexm(lower("`vname'"), "^count$|_count$|_count_|^n_|^number$|_number$") {
				quietly summarize `vname'
				if !missing(r(min)) & r(min) < 0 {
					local qflag "negative count"
				}
			}
			else if regexm(lower("`vname'"), "^percent$|_percent$|^pct$|_pct$|_pct_|^proportion$|_proportion$") {
				quietly summarize `vname'
				if !missing(r(min)) & (r(min) < 0 | r(max) > 100) {
					local qflag "percent out of range 0-100"
				}
			}

			local qflag_`i' "`qflag'"
		}
	}

	// Now load varinfo ONCE and update all values from matrices
	quietly {
		use "`varinfo'", clear

		forvalues i = 1/`nvars' {
			replace missing_n = `miss_n'[`i', 1] in `i'
			replace missing_pct = `miss_pct'[`i', 1] in `i'

			if `uniq_vals'[`i', 1] != . {
				replace unique_vals = `uniq_vals'[`i', 1] in `i'
			}

			replace is_binary = `is_bin'[`i', 1] in `i'

			if "`class_`i''" != "" {
				replace classification = "`class_`i''" in `i'
			}

			if "`qflag_`i''" != "" {
				replace quality_flag = "`qflag_`i''" in `i'
			}
		}

		// Save varinfo ONCE at the end
		save "`varinfo'", replace

		save "`classifications'", replace
	}

	// Write compact quick reference table
	assert _N == `nvars'  // Verify expected row count

	file write `fh' "QUICK REFERENCE" _n
	file write `fh' "----------------------------------------" _n
	// Header row
	local hdr_vname = "Variable"
	local hdr_type = "Type"
	local hdr_class = "Class"
	local hdr_miss = "Miss%"
	local hdr_uniq = "Unique"
	file write `fh' "  "
	local padded : di %-24s "`hdr_vname'"
	file write `fh' "`padded'"
	local padded : di %-10s "`hdr_type'"
	file write `fh' "`padded'"
	local padded : di %-14s "`hdr_class'"
	file write `fh' "`padded'"
	local padded : di %6s "`hdr_miss'"
	file write `fh' "`padded'"
	local padded : di %8s "`hdr_uniq'"
	file write `fh' "`padded'" _n

	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local vtype = vartype[`i']
		local vclass = classification[`i']
		if missing(missing_pct[`i']) {
			local pctmiss = 0
		}
		else {
			local pctmiss = missing_pct[`i']
		}
		if missing(unique_vals[`i']) {
			local uniq "."
		}
		else {
			local uniq = string(unique_vals[`i'], "%8.0f")
			local uniq = strtrim("`uniq'")
		}

		// Truncate long variable names
		local vn_disp = substr("`vname'", 1, 23)

		file write `fh' "  "
		local padded : di %-24s "`vn_disp'"
		file write `fh' "`padded'"
		local padded : di %-10s "`vtype'"
		file write `fh' "`padded'"
		local padded : di %-14s "`vclass'"
		file write `fh' "`padded'"
		local padded : di %5.1f `pctmiss'
		file write `fh' "`padded'%"
		local padded : di %8s "`uniq'"
		file write `fh' "`padded'" _n
	}
	file write `fh' "----------------------------------------" _n _n

	// Write detailed variable summary
	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local vtype = vartype[`i']
		local vfmt = varformat[`i']
		local vlab = varlabel[`i']
		local vclass = classification[`i']

		// Handle missing values properly when extracting to locals
		if missing(missing_n[`i']) {
			local nmiss = 0
		}
		else {
			local nmiss = missing_n[`i']
		}
		if missing(missing_pct[`i']) {
			local pctmiss "0.0"
		}
		else {
			local pctmiss : di %5.1f missing_pct[`i']
			local pctmiss = strtrim("`pctmiss'")
		}

		file write `fh' "  `vname'" _n
		file write `fh' "    Type: `vtype'" _n
		file write `fh' "    Format: `vfmt'" _n
		if `"`vlab'"' != "" file write `fh' `"    Label: `vlab'"' _n
		file write `fh' "    Missing: `nmiss' (`pctmiss'%)" _n
		file write `fh' "    Classification: `vclass'" _n _n
	}
	
	// Detailed variable sections
	_datamap_ProcessCategorical `fh' "`filepath'" "`classifications'" "`format'" "`nofreq'" `maxfreq' `obs'
	_datamap_ProcessContinuous `fh' "`filepath'" "`classifications'" "`format'" "`nostats'" `obs'
	_datamap_ProcessDate `fh' "`filepath'" "`classifications'" "`format'" "`datesafe'" "`dateformat'"
	_datamap_ProcessString `fh' "`filepath'" "`classifications'" "`format'"
	_datamap_ProcessExcluded `fh' "`filepath'" "`classifications'" "`format'"

	// Binary variables section (if detect_binary enabled)
	if `detect_binary' {
		_datamap_ProcessBinary `fh' "`filepath'" "`classifications'" "`format'" `obs'
	}

	// Data quality flags (if quality checks enabled)
	if "`quality_level'" != "" {
		_datamap_ProcessQuality `fh' "`filepath'" "`classifications'" "`format'"
	}

	// Sample observations (if requested)
	if `samples' > 0 {
		_datamap_ProcessSamples `fh' "`filepath'" "`classifications'" "`format'" `samples' "`exclude'"
	}

	// Value label definitions
	if "`nolabels'" == "" {
		_datamap_ProcessValueLabels `fh' "`filepath'" "`classifications'" "`format'"
	}
end

program define _datamap_ProcessCategorical
	version 16.0
	args fh filepath classifications format nofreq maxfreq obs

	tempfile catdata
	quietly use "`classifications'", clear
	quietly keep if classification == "categorical"
	if _N == 0 {
		exit
	}

	quietly save `catdata', replace
	local nvars = _N

	file write `fh' "========================================" _n
	file write `fh' "CATEGORICAL VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	assert _N == `nvars'  // Verify expected row count
	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local vtype = vartype[`i']
		local vfmt = varformat[`i']
		local vlab = varlabel[`i']
		local valab = valuelabel[`i']

		// Handle missing values properly
		if missing(missing_n[`i']) {
			local nmiss = 0
		}
		else {
			local nmiss = missing_n[`i']
		}
		if missing(missing_pct[`i']) {
			local pctmiss "0.0"
		}
		else {
			local pctmiss : di %5.1f missing_pct[`i']
			local pctmiss = strtrim("`pctmiss'")
		}
		if missing(unique_vals[`i']) {
			local nuniq = 0
		}
		else {
			local nuniq = unique_vals[`i']
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		local origpos = orig_position[`i']
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`vlab'"' != "" file write `fh' `"Label: `vlab'"' _n
		if "`valab'" != "" file write `fh' "Value Label: `valab'" _n
		file write `fh' "Classification: categorical" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "Unique Values: `nuniq'" _n _n
		
		// Frequency table
		if "`nofreq'" == "" & `nuniq' <= `maxfreq' {
			quietly use "`filepath'", clear
			
			file write `fh' "  Frequencies:" _n
			capture quietly tab `vname', matrow(vals) matcell(freqs)
			if _rc == 0 {
				local nvals = r(r)
				forvalues j = 1/`nvals' {
					local val = vals[`j',1]
					local freq = freqs[`j',1]
					if `obs' > 0 {
						local pct : di %5.1f round(100*`freq'/`obs', 0.1)
						local pct = strtrim("`pct'")
					}
					else {
						local pct "."
					}
					local vlab : label (`vname') `val'
					file write `fh' "    `val' = `vlab': `freq' (`pct'%)" _n
				}
			}
			else {
				file write `fh' "    (frequency table unavailable)" _n
			}
			file write `fh' _n

			quietly use "`catdata'", clear
		}

		// Add analysis guidance
		file write `fh' "ANALYSIS GUIDANCE: "
		file write `fh' "Use as factor/categorical variable. "
		if `nuniq' == 2 {
			file write `fh' "This is a binary variable - suitable for binary outcome models. "
		}
		else if `nuniq' <= 5 {
			file write `fh' "Low cardinality - suitable for stratification or interaction terms. "
		}
		else {
			file write `fh' "Consider reference category selection based on largest group or "
			file write `fh' "clinically meaningful baseline. "
		}
		// High missing percentage warning
		if `pctmiss' >= 20 {
			file write `fh' "`pctmiss'% missing - verify missingness mechanism before analysis. "
		}
		file write `fh' _n _n
	}
end

program define _datamap_ProcessContinuous
	version 16.0
	args fh filepath classifications format nostats obs

	tempfile contdata
	quietly use "`classifications'", clear
	quietly count if classification == "continuous"
	if r(N) == 0 {
		exit
	}
	
	file write `fh' "========================================" _n
	file write `fh' "CONTINUOUS VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	quietly use "`classifications'", clear
	quietly keep if classification == "continuous"
	quietly save `contdata', replace
	local nvars = _N
	
	assert _N == `nvars'  // Verify expected row count
	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local vtype = vartype[`i']
		local vfmt = varformat[`i']
		local vlab = varlabel[`i']

		// Handle missing values properly
		if missing(missing_n[`i']) {
			local nmiss = 0
		}
		else {
			local nmiss = missing_n[`i']
		}
		if missing(missing_pct[`i']) {
			local pctmiss "0.0"
		}
		else {
			local pctmiss : di %5.1f missing_pct[`i']
			local pctmiss = strtrim("`pctmiss'")
		}
		if missing(unique_vals[`i']) {
			local nuniq = 0
		}
		else {
			local nuniq = unique_vals[`i']
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		local origpos = orig_position[`i']
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`vlab'"' != "" file write `fh' `"Label: `vlab'"' _n
		file write `fh' "Classification: continuous" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "Unique Values: `nuniq'" _n _n

		// Summary statistics
		if "`nostats'" == "" {
			quietly use "`filepath'", clear
			quietly summarize `vname', detail
			local n = r(N)
			local skewness = r(skewness)

			// Check if all values are missing
			if `n' > 0 {
				local mean = round(r(mean), 0.01)
				local sd = round(r(sd), 0.01)
				local min = round(r(min), 0.01)
				local p25 = round(r(p25), 0.01)
				local p50 = round(r(p50), 0.01)
				local p75 = round(r(p75), 0.01)
				local max = round(r(max), 0.01)

				file write `fh' "DISTRIBUTION:" _n
				file write `fh' "  Valid N: `n'" _n
				file write `fh' "  Mean: `mean'" _n
				file write `fh' "  SD: `sd'" _n
				file write `fh' "  Median: `p50'" _n
				file write `fh' "  IQR: `p25'-`p75'" _n
				file write `fh' "  Range: `min' to `max'" _n _n

				// Add contextual analysis guidance
				file write `fh' "ANALYSIS GUIDANCE: "
				file write `fh' "Use as continuous variable. "

				// Contextual skewness guidance with direction and magnitude
				if !missing(`skewness') & abs(`skewness') > 2 {
					local sk_rounded = round(`skewness', 0.1)
					if `skewness' > 2 {
						file write `fh' "Right-skewed distribution (skewness=`sk_rounded') - consider log transformation. "
					}
					else {
						file write `fh' "Left-skewed distribution (skewness=`sk_rounded') - consider reflection or power transformation. "
					}
				}

				// Check for outliers (simple IQR method)
				local iqr = `p75' - `p25'
				if `iqr' > 0 {
					local lower = `p25' - 3*`iqr'
					local upper = `p75' + 3*`iqr'
					if `min' < `lower' | `max' > `upper' {
						file write `fh' "Potential outliers detected (values beyond 3*IQR) - verify data quality. "
					}
				}

				// Check for discrete-valued continuous (integers with small range)
				if `min' == round(`min', 1) & `max' == round(`max', 1) & `p50' == round(`p50', 1) {
					local range = `max' - `min'
					if `range' > 0 & `range' <= 20 & `nuniq' <= `range' + 1 {
						file write `fh' "Discrete integer values - consider whether ordinal treatment is more appropriate. "
					}
				}

				// High missing percentage warning
				if `pctmiss' >= 20 {
					file write `fh' "`pctmiss'% missing - verify missingness mechanism before analysis. "
				}

				file write `fh' _n _n
			}
			else {
				// All values missing
				file write `fh' "DISTRIBUTION: (all values missing)" _n _n
			}

			quietly use "`contdata'", clear
		}
	}
end

program define _datamap_ProcessDate
	version 16.0
	args fh filepath classifications format datesafe dateformat

	tempfile datedata
	quietly use "`classifications'", clear
	quietly count if classification == "date"
	if r(N) == 0 {
		exit
	}
	
	file write `fh' "========================================" _n
	file write `fh' "DATE VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	quietly use "`classifications'", clear
	quietly keep if classification == "date"
	quietly save `datedata', replace
	local nvars = _N
	
	assert _N == `nvars'  // Verify expected row count
	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local vtype = vartype[`i']
		local vfmt = varformat[`i']
		local vlab = varlabel[`i']

		// Handle missing values properly
		if missing(missing_n[`i']) {
			local nmiss = 0
		}
		else {
			local nmiss = missing_n[`i']
		}
		if missing(missing_pct[`i']) {
			local pctmiss "0.0"
		}
		else {
			local pctmiss : di %5.1f missing_pct[`i']
			local pctmiss = strtrim("`pctmiss'")
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		local origpos = orig_position[`i']
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`vlab'"' != "" file write `fh' `"Label: `vlab'"' _n
		file write `fh' "Classification: date" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n _n

		// Date range
		quietly use "`filepath'", clear
		quietly summarize `vname'
		local minval = r(min)
		local maxval = r(max)

		// Determine span unit from format
		local span_unit "days"
		if strpos("`vfmt'", "%tc") > 0 | strpos("`vfmt'", "%tC") > 0 {
			local span_unit "milliseconds"
		}
		else if strpos("`vfmt'", "%tw") > 0 {
			local span_unit "weeks"
		}
		else if strpos("`vfmt'", "%tm") > 0 {
			local span_unit "months"
		}
		else if strpos("`vfmt'", "%tq") > 0 {
			local span_unit "quarters"
		}
		else if strpos("`vfmt'", "%th") > 0 {
			local span_unit "half-years"
		}
		else if strpos("`vfmt'", "%ty") > 0 {
			local span_unit "years"
		}

		// Determine display format: use dateformat for daily/datetime,
		// native format for weekly/monthly/quarterly/etc.
		local dispfmt "`vfmt'"
		if strpos("`vfmt'", "%td") > 0 | strpos("`vfmt'", "%d") > 0 {
			local dispfmt "`dateformat'"
		}
		else if strpos("`vfmt'", "%tc") > 0 | strpos("`vfmt'", "%tC") > 0 {
			// Adapt daily dateformat to datetime prefix
			local dispfmt = subinstr("`dateformat'", "%td", "%tc", 1)
		}

		if "`datesafe'" == "" {
			// Show exact date range
			if !missing(`minval') & !missing(`maxval') {
				local mindate = string(`minval', "`dispfmt'")
				local maxdate = string(`maxval', "`dispfmt'")
				local span = `maxval' - `minval'
				file write `fh' "DATE RANGE:" _n
				file write `fh' "  Earliest: `mindate'" _n
				file write `fh' "  Latest: `maxdate'" _n
				file write `fh' "  Span: `span' `span_unit'" _n _n
			}
			else {
				file write `fh' "DATE RANGE: (all values missing)" _n _n
			}
		}
		else {
			// Privacy-safe: show only range span or suppress
			if !missing(`minval') & !missing(`maxval') {
				local span = `maxval' - `minval'
				file write `fh' "DATE RANGE: `span' `span_unit' span (exact dates suppressed for privacy)" _n _n
			}
			else {
				file write `fh' "DATE RANGE: (all values missing)" _n _n
			}
		}

		// Add contextual analysis guidance based on span
		file write `fh' "ANALYSIS GUIDANCE: "
		file write `fh' "Can be used to calculate durations, create time-to-event variables, "
		file write `fh' "or generate time periods. "
		if !missing(`minval') & !missing(`maxval') {
			local span = `maxval' - `minval'
			// Contextual span guidance (using days as base unit)
			if "`span_unit'" == "days" {
				if `span' < 30 {
					file write `fh' "Short time span (`span' days) - limited temporal variation. "
				}
				else if `span' > 7300 {
					local years = round(`span'/365.25, 1)
					file write `fh' "Long follow-up period (~`years' years). "
				}
			}
			else if "`span_unit'" == "months" & `span' > 240 {
				local years = round(`span'/12, 1)
				file write `fh' "Long follow-up period (~`years' years). "
			}
			else if "`span_unit'" == "years" & `span' > 20 {
				file write `fh' "Long follow-up period (`span' years). "
			}
		}
		file write `fh' "Verify date ranges are plausible before analysis."
		file write `fh' _n _n

		quietly use "`datedata'", clear
	}
end

program define _datamap_ProcessString
	version 16.0
	args fh filepath classifications format

	tempfile stringdata
	quietly use "`classifications'", clear
	quietly count if classification == "string"
	if r(N) == 0 {
		exit
	}
	
	file write `fh' "========================================" _n
	file write `fh' "STRING VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	quietly use "`classifications'", clear
	quietly keep if classification == "string"
	quietly save `stringdata', replace
	local nvars = _N
	
	assert _N == `nvars'  // Verify expected row count
	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local vtype = vartype[`i']
		local vlab = varlabel[`i']
		local origpos = orig_position[`i']

		// Handle missing values properly
		if missing(missing_n[`i']) {
			local nmiss = 0
		}
		else {
			local nmiss = missing_n[`i']
		}
		if missing(missing_pct[`i']) {
			local pctmiss "0.0"
		}
		else {
			local pctmiss : di %5.1f missing_pct[`i']
			local pctmiss = strtrim("`pctmiss'")
		}

		local is_strL = ("`vtype'" == "strL")

		quietly {
			use "`filepath'", clear
			tempvar slen
			gen double `slen' = length(`vname')
			summarize `slen'
		}
		local maxlen = r(max)
		if missing(`maxlen') local maxlen = 0

		// Get unique value count — skip tab for strL (content too large)
		if `is_strL' {
			capture quietly duplicates report `vname'
			if _rc == 0 {
				local nuniq = r(unique_value)
			}
			else {
				local nuniq "(strL)"
			}
		}
		else {
			capture quietly tab `vname'
			if _rc == 0 {
				local nuniq = r(r)
			}
			else {
				// tab failed (>32K unique values) — get actual count
				capture quietly duplicates report `vname'
				if _rc == 0 {
					local nuniq = r(unique_value)
				}
				else {
					local nuniq "(too many)"
				}
			}
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		if `is_strL' {
			file write `fh' "Note: strL (long string) — can store up to 2 billion characters" _n
		}
		if `"`vlab'"' != "" file write `fh' `"Label: `vlab'"' _n
		file write `fh' "Classification: string" _n
		file write `fh' "Max Length: `maxlen' characters" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "Unique Values: `nuniq'" _n
		file write `fh' "(exact values suppressed)" _n _n

		// Add analysis guidance
		file write `fh' "ANALYSIS GUIDANCE: "
		if `is_strL' {
			file write `fh' "Long string (strL) variable - may contain free text, notes, or large content. "
			file write `fh' "Consider whether content can be parsed or categorized for analysis."
		}
		else {
			file write `fh' "String variable - may contain free text, codes, or identifiers. "
			if "`nuniq'" != "(too many)" & "`nuniq'" != "(strL)" {
				if `nuniq' <= 25 {
					file write `fh' "Low cardinality suggests categorical data - consider encoding as numeric. "
				}
			}
			file write `fh' "Verify encoding if contains non-ASCII characters."
		}
		file write `fh' _n _n

		quietly use "`stringdata'", clear
	}
end

program define _datamap_ProcessExcluded
	version 16.0
	args fh filepath classifications format

	tempfile excludedata
	quietly use "`classifications'", clear
	quietly count if classification == "excluded"
	if r(N) == 0 {
		exit
	}
	
	file write `fh' "========================================" _n
	file write `fh' "EXCLUDED VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	quietly use "`classifications'", clear
	quietly keep if classification == "excluded"
	quietly save `excludedata', replace
	local nvars = _N
	
	assert _N == `nvars'  // Verify expected row count
	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local vtype = vartype[`i']
		local vfmt = varformat[`i']
		local vlab = varlabel[`i']

		// Handle missing values properly
		if missing(missing_n[`i']) {
			local nmiss = 0
		}
		else {
			local nmiss = missing_n[`i']
		}
		if missing(missing_pct[`i']) {
			local pctmiss "0.0"
		}
		else {
			local pctmiss : di %5.1f missing_pct[`i']
			local pctmiss = strtrim("`pctmiss'")
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		local origpos = orig_position[`i']
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`vlab'"' != "" file write `fh' `"Label: `vlab'"' _n
		file write `fh' "Classification: excluded (privacy)" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "(values excluded from documentation)" _n _n

		// Add analysis guidance
		file write `fh' "PRIVACY NOTE: This variable excluded to protect participant privacy. "
		file write `fh' "Do not attempt to re-identify individuals. Use for linkage only if authorized."
		file write `fh' _n _n
	}
end

program define _datamap_ProcessValueLabels
	version 16.0
	args fh filepath classifications format

	// Get all value labels used
	tempfile labdata
	quietly use "`classifications'", clear
	quietly keep if valuelabel != ""
	if _N == 0 {
		exit
	}
	
	// Get unique value labels
	quietly levelsof valuelabel, local(vallabs)
	quietly save `labdata', replace
	
	if "`vallabs'" == "" exit
	
	file write `fh' "========================================" _n
	file write `fh' "VALUE LABEL DEFINITIONS" _n
	file write `fh' "========================================" _n _n
	
	// Process each value label
	foreach vl of local vallabs {
		// Get variables using this label
		quietly use `labdata', clear
		quietly keep if valuelabel == "`vl'"
		local nvars = _N
		assert _N == `nvars'  // Verify expected row count
		local varlist ""
		forvalues i = 1/`nvars' {
			local vn = varname[`i']
			local varlist "`varlist' `vn'"
		}
		
		local varlist = strtrim("`varlist'")
		
		// Get label mappings by loading dataset
		quietly use "`filepath'", clear

		file write `fh' "`vl' (used by: `varlist')" _n

		// Check if the label is actually defined
		capture quietly label list `vl'
		if _rc == 0 {
			// Label exists - extract values by iterating through them
			local labname "`vl'"

			// Use extended macro to get label range
			local firstvar : word 1 of `varlist'
			quietly levelsof `firstvar', local(levels)
			foreach lev of local levels {
				local labtext : label `labname' `lev'
				file write `fh' "  `lev' = `labtext'" _n
			}
		}
		else {
			// Label referenced but not defined
			file write `fh' "  (label not defined in this dataset)" _n
		}
		file write `fh' _n
	}
end

// =============================================================================
// Helper: _datamap_ProcessBinary
// Document binary variables (exactly 2 unique values)
// =============================================================================
program define _datamap_ProcessBinary
	version 16.0
	args fh filepath classifications format obs

	tempfile bindata
	quietly use "`classifications'", clear
	quietly count if is_binary == 1
	if r(N) == 0 {
		exit
	}

	file write `fh' "Binary Variables (potential outcomes/indicators)" _n _n

	quietly use "`classifications'", clear
	quietly keep if is_binary == 1
	quietly save `bindata', replace
	local nvars = _N

	assert _N == `nvars'
	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local vtype = vartype[`i']
		local vlab = varlabel[`i']

		if missing(missing_n[`i']) {
			local nmiss = 0
		}
		else {
			local nmiss = missing_n[`i']
		}
		if missing(missing_pct[`i']) {
			local pctmiss = 0
		}
		else {
			local pctmiss = missing_pct[`i']
		}

		file write `fh' "`vname'"
		if `"`vlab'"' != "" file write `fh' ": `vlab'"
		file write `fh' _n
		file write `fh' "  Type: `vtype' (binary)" _n
		file write `fh' "  Missing: `nmiss' obs (`pctmiss'%)" _n

		// Show frequency distribution
		quietly use "`filepath'", clear
		quietly tab `vname', matrow(vals) matcell(freqs)
		local nvals = r(r)

		file write `fh' "  Frequency:" _n
		forvalues j = 1/`nvals' {
			local val = vals[`j',1]
			local freq = freqs[`j',1]
			if `obs' > 0 {
				local pct : di %5.1f round(100*`freq'/`obs', 0.1)
				local pct = strtrim("`pct'")
			}
			else {
				local pct "."
			}
			capture local vallabtext : label (`vname') `val'
			if _rc == 0 & "`vallabtext'" != "" {
				file write `fh' "    `val' (`vallabtext'): `freq' (`pct'%)" _n
			}
			else {
				file write `fh' "    `val': `freq' (`pct'%)" _n
			}
		}
		file write `fh' _n

		quietly use "`bindata'", clear
	}
end

// =============================================================================
// Helper: _datamap_ProcessQuality
// Report data quality flags
// =============================================================================
program define _datamap_ProcessQuality
	version 16.0
	args fh filepath classifications format

	quietly use "`classifications'", clear
	quietly count if quality_flag != ""
	if r(N) == 0 {
		exit
	}

	file write `fh' "========================================" _n
	file write `fh' "DATA QUALITY FLAGS" _n
	file write `fh' "========================================" _n _n

	quietly keep if quality_flag != ""
	local nvars = _N

	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local qflag = quality_flag[`i']
		file write `fh' "  `vname': `qflag'" _n
	}
	file write `fh' _n
end

// =============================================================================
// Helper: _datamap_ProcessSamples
// Include sample observations (privacy-limited)
// =============================================================================
program define _datamap_ProcessSamples
	version 16.0
	args fh filepath classifications format nsamples exclude

	quietly use "`filepath'", clear

	file write `fh' "========================================" _n
	file write `fh' "SAMPLE OBSERVATIONS" _n
	file write `fh' "========================================" _n _n
	file write `fh' "First `nsamples' observations (excluded variables masked):" _n _n

	// Get variable list
	quietly describe, varlist
	local allvars `r(varlist)'

	// Print header
	file write `fh' "| "
	foreach vn of local allvars {
		local isexcl 0
		foreach ev of local exclude {
			if "`vn'" == "`ev'" local isexcl 1
		}
		if `isexcl' {
			file write `fh' "`vn'(masked) | "
		}
		else {
			file write `fh' "`vn' | "
		}
	}
	file write `fh' _n

	// Print separator
	file write `fh' "|"
	foreach vn of local allvars {
		file write `fh' "---|"
	}
	file write `fh' _n

	// Print sample rows
	local maxrow = min(`nsamples', _N)
	forvalues row = 1/`maxrow' {
		file write `fh' "| "
		foreach vn of local allvars {
			local isexcl 0
			foreach ev of local exclude {
				if "`vn'" == "`ev'" local isexcl 1
			}

			if `isexcl' {
				file write `fh' "[MASKED] | "
			}
			else {
				local vtype : type `vn'
				if substr("`vtype'", 1, 3) == "str" {
					local val `"`=`vn'[`row']'"'
					if length(`"`val'"') > 20 {
						local val = substr(`"`val'"', 1, 17) + "..."
					}
					file write `fh' `"`val' | "'
				}
				else {
					local val = `vn'[`row']
					if missing(`val') {
						file write `fh' ". | "
					}
					else {
						file write `fh' "`val' | "
					}
				}
			}
		}
		file write `fh' _n
	}
	file write `fh' _n
end

// =============================================================================
// Detection Programs
// =============================================================================

// Detect panel/longitudinal data structure
program define _datamap_DetectPanel
	version 16.0
	args fh filepath panelid format

	quietly use "`filepath'", clear

	// If panelid specified, use it; otherwise try to detect
	if "`panelid'" != "" {
		capture confirm variable `panelid'
		if _rc != 0 {
			file write `fh' "Panel ID variable '`panelid'' not found" _n _n
			exit
		}
		local id_var "`panelid'"
	}
	else {
		// Try to detect ID variable
		quietly describe, varlist
		local allvars `r(varlist)'
		local id_var ""

		foreach vn of local allvars {
			local vn_lower = lower("`vn'")
			if regexm("`vn_lower'", "id$|_id$|^id_|patient|subject|person") {
				local id_var "`vn'"
				continue, break
			}
		}

		if "`id_var'" == "" exit
	}

	// Check for repeated observations
	capture quietly tab `id_var'
	if _rc != 0 {
		// tab failed (too many unique values) — use codebook as fallback
		capture quietly codebook `id_var', compact
		if _rc != 0 exit
		local n_units = r(ndistinct)
	}
	else {
		local n_units = r(r)
	}
	local n_obs = _N

	if `n_units' < `n_obs' {
		local avg_obs = round(`n_obs' / `n_units', 0.1)
		file write `fh' "Panel Structure Detected" _n
		file write `fh' "  ID Variable: `id_var'" _n
		file write `fh' "  Unique Units: `n_units'" _n
		file write `fh' "  Total Observations: `n_obs'" _n
		file write `fh' "  Average Obs per Unit: `avg_obs'" _n _n
	}
end

// Detect survival/time-to-event data
program define _datamap_DetectSurvival
	version 16.0
	args fh filepath survivalvars format

	quietly use "`filepath'", clear

	quietly describe, varlist
	local allvars `r(varlist)'

	local time_vars ""
	local event_vars ""

	// Search for time and event variables
	foreach vn of local allvars {
		local vn_lower = lower("`vn'")

		// Time variables
		if regexm("`vn_lower'", "time|duration|followup|follow_up|survtime|_t$|^t_") {
			local time_vars "`time_vars' `vn'"
		}
		// Event/failure variables
		if regexm("`vn_lower'", "event|failure|death|died|status|censor|_d$|^d_") {
			local event_vars "`event_vars' `vn'"
		}
	}

	// Exit if nothing found
	if "`time_vars'" == "" & "`event_vars'" == "" {
		exit
	}

	// Write output
	file write `fh' "Survival Analysis Variables Detected" _n

	if "`time_vars'" != "" {
		file write `fh' "  Likely time variables:`time_vars'" _n
		// Show range for first time variable
		local first_time : word 1 of `time_vars'
		quietly summarize `first_time'
		local t_min = round(r(min), 0.1)
		local t_max = round(r(max), 0.1)
		file write `fh' "    `first_time' range: `t_min' to `t_max'" _n
	}

	if "`event_vars'" != "" {
		file write `fh' "  Likely event indicators:`event_vars'" _n
		// Show event rate for first event variable
		local first_event : word 1 of `event_vars'
		quietly tab `first_event'
		if r(r) == 2 {
			quietly summarize `first_event'
			local event_rate = round(100 * r(mean), 0.1)
			file write `fh' "    `first_event' rate: `event_rate'%" _n
		}
	}

	file write `fh' _n
end

// Detect survey design elements
program define _datamap_DetectSurvey
	version 16.0
	args fh filepath format

	quietly use "`filepath'", clear

	quietly describe, varlist
	local allvars `r(varlist)'

	local weight_vars ""
	local strata_vars ""
	local cluster_vars ""

	// Search for survey design variables
	foreach vn of local allvars {
		local vn_lower = lower("`vn'")

		// Weight variables
		if regexm("`vn_lower'", "weight|wgt|_wt$|^wt_|pweight|fweight") {
			local weight_vars "`weight_vars' `vn'"
		}
		// Strata variables
		if regexm("`vn_lower'", "strat") {
			local strata_vars "`strata_vars' `vn'"
		}
		// Cluster/PSU variables
		if regexm("`vn_lower'", "cluster|psu") {
			local cluster_vars "`cluster_vars' `vn'"
		}
	}

	// Exit if nothing found
	if "`weight_vars'" == "" & "`strata_vars'" == "" & "`cluster_vars'" == "" {
		exit
	}

	// Write output
	file write `fh' "Survey Design Elements Detected" _n

	// Process weight variables
	foreach wvar of local weight_vars {
		quietly summarize `wvar'
		local w_min = round(r(min), 0.1)
		local w_max = round(r(max), 0.1)
		local w_mean = round(r(mean), 0.1)
		file write `fh' "  Sampling weight: `wvar' (range: `w_min' to `w_max', mean: `w_mean')" _n
	}

	// Process strata variables
	foreach svar of local strata_vars {
		quietly tab `svar'
		local n_strata = r(r)
		file write `fh' "  Stratification: `svar' (`n_strata' strata)" _n
	}

	// Process cluster variables
	foreach cvar of local cluster_vars {
		quietly tab `cvar'
		local n_clusters = r(r)
		file write `fh' "  Clustering: `cvar' (`n_clusters' primary sampling units)" _n
	}

	file write `fh' _n
end

// Detect common variable name patterns
program define _datamap_DetectCommon
	version 16.0
	args fh filepath format

	quietly use "`filepath'", clear

	quietly describe, varlist
	local allvars `r(varlist)'

	local id_vars ""
	local date_vars ""
	local outcome_vars ""
	local exposure_vars ""
	local demo_vars ""

	// Search for common patterns
	foreach vn of local allvars {
		local vn_lower = lower("`vn'")

		// ID variables
		if regexm("`vn_lower'", "id$|_id$|^id_|patient|subject") {
			local id_vars "`id_vars' `vn'"
		}
		// Date variables
		else if regexm("`vn_lower'", "date|_dt$|^dt_|dob|death") {
			local date_vars "`date_vars' `vn'"
		}
		// Outcome variables
		else if regexm("`vn_lower'", "outcome|death|event|died") {
			local outcome_vars "`outcome_vars' `vn'"
		}
		// Exposure variables
		else if regexm("`vn_lower'", "exposure|treatment|drug|rx") {
			local exposure_vars "`exposure_vars' `vn'"
		}
		// Demographics
		else if regexm("`vn_lower'", "^age$|^sex$|gender|race|ethnicity|ethnic") {
			local demo_vars "`demo_vars' `vn'"
		}
	}

	// Exit if nothing found
	if "`id_vars'" == "" & "`date_vars'" == "" & "`outcome_vars'" == "" & "`exposure_vars'" == "" & "`demo_vars'" == "" {
		exit
	}

	// Write output
	file write `fh' "Common Variable Patterns Detected" _n

	if "`id_vars'" != "" {
		file write `fh' "  Likely IDs:`id_vars'" _n
	}
	if "`date_vars'" != "" {
		file write `fh' "  Likely dates:`date_vars'" _n
	}
	if "`outcome_vars'" != "" {
		file write `fh' "  Likely outcomes:`outcome_vars'" _n
	}
	if "`exposure_vars'" != "" {
		file write `fh' "  Likely exposures:`exposure_vars'" _n
	}
	if "`demo_vars'" != "" {
		file write `fh' "  Demographics:`demo_vars'" _n
	}

	file write `fh' _n
end

// Summarize missing data patterns
program define _datamap_SummarizeMissing
	version 16.0
	args fh filepath format pattern_check obs

	quietly use "`filepath'", clear

	quietly describe, varlist
	local allvars `r(varlist)'

	// Count variables by missing percentage
	local vars_gt50 ""
	local n_gt50 = 0
	local vars_gt10 ""
	local n_gt10 = 0

	tempvar complete
	quietly gen `complete' = 1

	foreach vn of local allvars {
		quietly count if missing(`vn')
		local nmiss = r(N)
		if `obs' > 0 {
			local pct = 100 * `nmiss' / `obs'
		}
		else {
			local pct = 0
		}

		if `pct' > 50 {
			local vars_gt50 "`vars_gt50' `vn'"
			local ++n_gt50
		}
		if `pct' > 10 {
			local ++n_gt10
		}

		// Mark rows with any missing
		quietly replace `complete' = 0 if missing(`vn')
	}

	// Count complete cases
	quietly count if `complete' == 1
	local n_complete = r(N)
	if `obs' > 0 {
		local pct_complete = round(100 * `n_complete' / `obs', 0.1)
	}
	else {
		local pct_complete = 0
	}

	// Write output
	file write `fh' "Missing Data Summary" _n
	if `n_gt50' > 0 {
		file write `fh' "  Variables with >50% missing: `n_gt50' (`vars_gt50')" _n
	}
	else {
		file write `fh' "  Variables with >50% missing: 0" _n
	}
	file write `fh' "  Variables with >10% missing: `n_gt10'" _n
	file write `fh' "  Observations with complete data: `n_complete' (`pct_complete'%)" _n
	file write `fh' _n
end

// =============================================================================
// Helper: _datamap_GenerateDatasetSummary
// Generate natural language description of the dataset
// =============================================================================
program define _datamap_GenerateDatasetSummary
	version 16.0
	args fh filepath obs nvars label detect_panel detect_survival panelid dateformat datesafe

	quietly use "`filepath'", clear

	file write `fh' "DESCRIPTION" _n
	file write `fh' "-----------" _n

	// Start building summary
	local summary "This dataset contains "

	// Determine structure type
	local is_panel 0
	local is_cross_sectional 1

	// Check for panel structure
	if `detect_panel' & "`panelid'" != "" {
		capture confirm variable `panelid'
		if _rc == 0 {
			quietly tab `panelid'
			local n_units = r(r)
			local summary "`summary'longitudinal data with `n_units' units observed over time. "
			local is_panel 1
			local is_cross_sectional 0
		}
	}

	if `is_cross_sectional' {
		local summary "`summary'cross-sectional data. "
	}

	// Add observation and variable counts
	local summary "`summary'It includes `obs' observations and `nvars' variables. "

	// Check for date variables to infer time period
	// Only compare dates within the same format family to avoid
	// nonsensical ranges when mixing %td (days) and %tc (milliseconds)
	quietly describe, varlist
	local allvars `r(varlist)'
	local has_dates 0
	local earliest .
	local latest .
	local datefmt ""
	local date_family ""

	foreach vn of local allvars {
		local vfmt: format `vn'
		if strpos("`vfmt'", "%t") > 0 | strpos("`vfmt'", "%d") > 0 {
			// Determine format family
			local fam ""
			if strpos("`vfmt'", "%td") > 0 | strpos("`vfmt'", "%d") > 0 {
				local fam "td"
			}
			else if strpos("`vfmt'", "%tc") > 0 | strpos("`vfmt'", "%tC") > 0 {
				local fam "tc"
			}
			else if strpos("`vfmt'", "%tw") > 0 {
				local fam "tw"
			}
			else if strpos("`vfmt'", "%tm") > 0 {
				local fam "tm"
			}
			else if strpos("`vfmt'", "%tq") > 0 {
				local fam "tq"
			}
			else {
				local fam "other"
			}

			// Prefer %td family; otherwise use first family encountered
			if "`date_family'" == "" {
				local date_family "`fam'"
			}
			if "`fam'" == "td" & "`date_family'" != "td" {
				// Switch to %td family, reset range
				local date_family "td"
				local earliest .
				local latest .
				local datefmt ""
			}

			// Only compare within the chosen family
			if "`fam'" == "`date_family'" {
				quietly summarize `vn'
				if r(N) > 0 {
					if `earliest' == . | r(min) < `earliest' {
						local earliest = r(min)
						local datefmt "`vfmt'"
					}
					if `latest' == . | r(max) > `latest' {
						local latest = r(max)
					}
					local has_dates 1
				}
			}
		}
	}

	if `has_dates' & `earliest' != . & `latest' != . {
		if "`datesafe'" != "" {
			local summary "`summary'The data includes date variables (exact range suppressed for privacy). "
		}
		else {
			local dispfmt "`datefmt'"
			if strpos("`datefmt'", "%td") > 0 | strpos("`datefmt'", "%d") > 0 {
				local dispfmt "`dateformat'"
			}
			else if strpos("`datefmt'", "%tc") > 0 | strpos("`datefmt'", "%tC") > 0 {
				local dispfmt = subinstr("`dateformat'", "%td", "%tc", 1)
			}
			local earliest_str = string(`earliest', "`dispfmt'")
			local latest_str = string(`latest', "`dispfmt'")
			local summary "`summary'The data spans from `earliest_str' to `latest_str'. "
		}
	}

	// Detect variable groups
	local has_ids 0
	local has_demos 0
	local has_outcomes 0
	local has_clinical 0

	foreach vn of local allvars {
		local vn_lower = lower("`vn'")
		if regexm("`vn_lower'", "id$|_id$|patient|subject") local has_ids 1
		if regexm("`vn_lower'", "age|sex|gender|race|ethnic") local has_demos 1
		if regexm("`vn_lower'", "outcome|death|event|died|relapse") local has_outcomes 1
		if regexm("`vn_lower'", "dx_|icd|procedure|treatment|therapy|drug|rx|lab_") local has_clinical 1
	}

	// Add variable type information
	if `has_ids' | `has_demos' | `has_clinical' | `has_outcomes' {
		local summary "`summary'Key variable categories include: "
		local cat_list ""
		if `has_ids' local cat_list "`cat_list'identifiers, "
		if `has_demos' local cat_list "`cat_list'demographics, "
		if `has_clinical' local cat_list "`cat_list'clinical data, "
		if `has_outcomes' local cat_list "`cat_list'outcomes"
		local cat_list = strtrim("`cat_list'")
		if substr("`cat_list'", -1, 1) == "," local cat_list = substr("`cat_list'", 1, length("`cat_list'")-1)
		local summary "`summary'`cat_list'. "
	}

	// Write the summary
	file write `fh' "`summary'" _n _n
end
