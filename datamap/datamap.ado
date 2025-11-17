*! datamap v2.0.0
*! Generate privacy-safe LLM-readable dataset documentation
*! Author: Tim Copeland
*! Date: 2025-11-16

/*
SYNTAX
------
datamap [, options]

OPTIONS
-------
Input:
  directory(path)     Directory to scan for .dta files (default: current directory)
  filelist(filename)  Text file listing .dta files to process (one per line)
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
  nonotes             Suppress dataset and variable notes
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

WARNING: This command loads datasets into memory and does not preserve the
current dataset. Save your work before running or work in a separate session.

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
. datamap, single(analysis.dta) format(text)
. datamap, exclude(patient_id clinic_id) datesafe

STORED RESULTS
--------------
r(nfiles)   - number of datasets processed
r(format)   - output format used (text)
r(output)   - output filename (for combined mode)

NOTES
-----
- Text format for LLM context (readable, structured)
- No observation-level data exported
- Use exclude() for sensitive identifiers
- Use datesafe if exact dates are sensitive
- Program loads datasets into memory; current dataset is not preserved
*/

program define datamap, rclass
	version 14.0
	syntax [, DIRectory(string) FILElist(string) SINGLE(string) ///
	          RECursive ///
	          Output(string) Format(string) SEParate APPend ///
	          NOSTats NOFReq NOLAbels NONOtes ///
	          MAXFreq(integer 25) MAXCat(integer 25) ///
	          EXClude(string) DATESafe ///
	          DETect(string) AUTODETect PANELid(varname) ///
	          SURVIVALvars(string) QUality QUality2(string) ///
	          SAMples(integer 0) MISSing(string)]
	
	// Validate mutually exclusive input options (only one allowed)
	local ninput = ("`directory'" != "") + ("`filelist'" != "") + ("`single'" != "")
	if `ninput' > 1 {
		noisily di as error "specify only one of directory(), filelist(), or single()"
		exit 198
	}
	if `ninput' == 0 {
		noisily di as error "must specify directory(), filelist(), or single()"
		exit 198
	}
	
	// Set defaults for output format
	if "`format'" == "" local format "text"
	if !inlist("`format'", "text", "json", "markdown", "md") {
		noisily di as error "format must be text, json, or markdown"
		exit 198
	}
	// Normalize markdown format
	if "`format'" == "md" local format "markdown"
	
	// Set default output filename
	if "`output'" == "" {
		local output "datamap.txt"
	}
	noisily di as text "Output file: `output'"
	
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
		confirm file "`single'"
		local nfiles 1
	}
	else if "`filelist'" != "" {
		// File list mode: read paths from text file
		confirm file "`filelist'"
		CollectFromList "`filelist'" "`filelist_tmp'"
		// Count lines in the temp file
		tempname fh
		file open `fh' using "`filelist_tmp'", read text
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
		CollectFromDir "`directory'" "`recursive'" "`filelist_tmp'"
		// Count lines in the temp file
		tempname fh
		file open `fh' using "`filelist_tmp'", read text
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
		ProcessSeparate, filelist("`filelist_tmp'") format(`format') ///
			`nostats' `nofreq' `nolabels' ///
			`nonotes' maxfreq(`maxfreq') maxcat(`maxcat') ///
			exclude(`exclude') `datesafe' nfiles(`nfiles') ///
			detect_panel(`detect_panel') detect_binary(`detect_binary') ///
			detect_survival(`detect_survival') detect_survey(`detect_survey') ///
			detect_common(`detect_common') panelid(`panelid') ///
			survivalvars(`survivalvars') quality_level(`quality_level') ///
			samples(`samples') missing_detail(`missing_detail') ///
			missing_pattern(`missing_pattern')
	}
	else {
		// Generate single combined output file
		ProcessCombined, filelist("`filelist_tmp'") output(`output') format(`format') ///
			`append' `nostats' `nofreq' ///
			`nolabels' `nonotes' maxfreq(`maxfreq') ///
			maxcat(`maxcat') exclude(`exclude') `datesafe' ///
			single(`single') nfiles(`nfiles') ///
			detect_panel(`detect_panel') detect_binary(`detect_binary') ///
			detect_survival(`detect_survival') detect_survey(`detect_survey') ///
			detect_common(`detect_common') panelid(`panelid') ///
			survivalvars(`survivalvars') quality_level(`quality_level') ///
			samples(`samples') missing_detail(`missing_detail') ///
			missing_pattern(`missing_pattern')
	}
		
	// Return results
	return scalar nfiles = `nfiles'
	return local format = "`format'"
	return local output = "`output'"
	
	di as text "Documentation generated successfully"
end

// =============================================================================
// Helper: CollectFromList
// Read file paths from text file, one per line, ignoring comments
// Write output to another text file
// =============================================================================
program define CollectFromList
	args filelist tmpfile

	tempname fh_in fh_out
	file open `fh_in' using "`filelist'", read text
	file open `fh_out' using "`tmpfile'", write text replace

	file read `fh_in' line
	while r(eof) == 0 {
		local line = strtrim("`line'")
		// Skip blank lines and comments (lines starting with *)
		if "`line'" != "" & substr("`line'", 1, 1) != "*" {
			file write `fh_out' `"`line'"' _n
		}
		file read `fh_in' line
	}
	file close `fh_in'
	file close `fh_out'
end

// =============================================================================
// Helper: CollectFromDir
// Scan directory for .dta files, optionally recursive
// Write output to text file
// =============================================================================
program define CollectFromDir
	args directory recursive tmpfile

	tempname fh
	file open `fh' using "`tmpfile'", write text replace

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
		RecursiveScan "`directory'" `fh'
	}

	file close `fh'
end

// Helper for recursive scanning
program define RecursiveScan
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
				RecursiveScan "`directory'/`subdir'" `fh'
			}
			else {
				RecursiveScan "`subdir'" `fh'
			}
		}
	}
end

// =============================================================================
// Helper: ProcessCombined
// Generate single output file containing all datasets
// =============================================================================
program define ProcessCombined
	syntax, filelist(string) output(string) format(string) [append ///
		nostats nofreq nolabels nonotes maxfreq(integer 25) ///
		maxcat(integer 25) exclude(string) datesafe single(string) nfiles(integer 1) ///
		detect_panel(integer 0) detect_binary(integer 0) detect_survival(integer 0) ///
		detect_survey(integer 0) detect_common(integer 0) panelid(string) ///
		survivalvars(string) quality_level(string) samples(integer 0) ///
		missing_detail(integer 0) missing_pattern(integer 0)]

	noisily di as text "Opening output file: `output'"

	// Open output file (append or replace mode)
	tempname fh
	if "`append'" != "" {
		noisily di as text "Appending to existing file"
		file open `fh' using "`output'", write text append
	}
	else {
		noisily di as text "Creating new file"
		file open `fh' using "`output'", write text replace

		// Write header for text format
		local cdate = c(current_date)
		local ctime = c(current_time)
		file write `fh' "Dataset Documentation" _n
		file write `fh' "Generated: `cdate' `ctime'" _n _n
	}

	// Process each file in list
	noisily di as text "Processing files..."

	if "`single'" != "" {
		// Single file mode
		noisily di as text "  Processing single file: `single'"
		ProcessDataset `fh' "`single'" "`format'" "`nostats'" "`nofreq'" ///
			"`nolabels'" "`nonotes'" `maxfreq' `maxcat' "`exclude'" "`datesafe'" 1 1 ///
			`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
			"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
			`missing_detail' `missing_pattern'
	}
	else {
		// Multiple files from list - read from file
		tempname fh_list
		file open `fh_list' using "`filelist'", read text
		local i 0
		file read `fh_list' thisfile
		while r(eof) == 0 {
			local ++i
			noisily di as text "  Processing file `i' of `nfiles': `thisfile'"
			ProcessDataset `fh' "`thisfile'" "`format'" "`nostats'" "`nofreq'" ///
				"`nolabels'" "`nonotes'" `maxfreq' `maxcat' "`exclude'" "`datesafe'" `i' `nfiles' ///
				`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
				"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
				`missing_detail' `missing_pattern'
			file read `fh_list' thisfile
		}
		file close `fh_list'
	}

	// Always close file handle
	noisily di as text "Closing file handle"
	file close `fh'
	noisily di as result `"Output written to: `output'"'
end

// =============================================================================
// Helper: ProcessSeparate
// Generate separate output file for each dataset
// =============================================================================
program define ProcessSeparate
	syntax, filelist(string) format(string) [nostats nofreq nolabels nonotes ///
		maxfreq(integer 25) maxcat(integer 25) exclude(string) datesafe nfiles(integer 1) ///
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

		noisily di as text "Creating separate output: `outfile'"

		// Open output file for this dataset
		tempname fh
		file open `fh' using "`outfile'", write text replace

		// Process with error handling
		capture {
			// Write header for text format
			local cdate = c(current_date)
			local ctime = c(current_time)
			file write `fh' "Dataset Documentation" _n
			file write `fh' "Generated: `cdate' `ctime'" _n _n

			// Process this dataset
			ProcessDataset `fh' "`thisfile'" "`format'" "`nostats'" "`nofreq'" ///
				"`nolabels'" "`nonotes'" `maxfreq' `maxcat' "`exclude'" "`datesafe'" 1 1 ///
				`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
				"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
				`missing_detail' `missing_pattern'
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
// Helper: ProcessDataset
// Process single dataset and write documentation to file handle
// Args: fh filepath format nostats nofreq nolabels nonotes maxfreq maxcat
//       exclude datesafe idx total detect_panel detect_binary detect_survival
//       detect_survey detect_common panelid survivalvars quality_level samples
//       missing_detail missing_pattern
// =============================================================================
program define ProcessDataset
	args fh filepath format nostats nofreq nolabels nonotes maxfreq maxcat exclude datesafe idx total ///
	     detect_panel detect_binary detect_survival detect_survey detect_common ///
	     panelid survivalvars quality_level samples missing_detail missing_pattern

	noisily di as text "  Reading metadata for: `filepath'"

	// Get dataset metadata from describe
	capture describe using "`filepath'", short
	if _rc != 0 {
		noisily di as error "    ERROR: Could not describe file `filepath' (rc=`=_rc')"
		exit _rc
	}
	local obs = r(N)
	local nvars = r(k)
	local label = r(label)

	noisily di as text "    Observations: `obs', Variables: `nvars'"

	// Get file system info - use simple approach
	// Extract basename from filepath
	local basename = "`filepath'"

	// Try to extract filename from path
	if strpos("`filepath'", "/") > 0 {
		// Unix-style path - get last component
		local basename = reverse("`filepath'")
		local slashpos = strpos("`basename'", "/")
		if `slashpos' > 0 {
			local basename = reverse(substr("`basename'", 1, `slashpos'-1))
		}
		else {
			local basename = "`filepath'"
		}
	}
	else if strpos("`filepath'", "\") > 0 {
		// Windows-style path - get last component
		local basename = reverse("`filepath'")
		local slashpos = strpos("`basename'", "\")
		if `slashpos' > 0 {
			local basename = reverse(substr("`basename'", 1, `slashpos'-1))
		}
		else {
			local basename = "`filepath'"
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

	// Add datasignature for versioning
	capture datasignature using "`filepath'"
	if _rc == 0 {
		file write `fh' "Data Signature: `r(datasignature)'" _n
	}

	// Add sort order if set
	capture describe using "`filepath'", short
	if r(sortlist) != "" {
		file write `fh' "Sort Order: `r(sortlist)'" _n
	}
	file write `fh' _n

	// Generate natural language summary
	GenerateDatasetSummary `fh' "`filepath'" `obs' `nvars' "`label'" ///
		`detect_panel' `detect_survival' "`panelid'"

	// Run detection features if requested
	if `detect_panel' | "`panelid'" != "" {
		DetectPanel `fh' "`filepath'" "`panelid'" "`format'"
	}
	if `detect_survival' | "`survivalvars'" != "" {
		DetectSurvival `fh' "`filepath'" "`survivalvars'" "`format'"
	}
	if `detect_survey' {
		DetectSurvey `fh' "`filepath'" "`format'"
	}
	if `detect_common' {
		DetectCommon `fh' "`filepath'" "`format'"
	}
	if `missing_detail' | `missing_pattern' {
		SummarizeMissing `fh' "`filepath'" "`format'" `missing_pattern' `obs'
	}

	// Process all variables in the dataset
	noisily di as text "    Processing variables..."
	ProcessVariables `fh' "`filepath'" "`format'" "`nostats'" "`nofreq'" ///
		"`nolabels'" "`nonotes'" `maxfreq' `maxcat' "`exclude'" "`datesafe'" `obs' ///
		`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
		"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
		`missing_detail' `missing_pattern'
end

// =============================================================================
// Helper: ProcessVariables
// Classify and document all variables in a dataset
// =============================================================================
program define ProcessVariables
	args fh filepath format nostats nofreq nolabels nonotes maxfreq maxcat exclude datesafe obs ///
	     detect_panel detect_binary detect_survival detect_survey detect_common ///
	     panelid survivalvars quality_level samples missing_detail missing_pattern
	
	noisily di as text "    Classifying variables..."

	// Get variable metadata using describe
	tempfile varinfo
	capture use "`filepath'", clear
	if _rc != 0 {
		noisily di as error "      ERROR: Could not load `filepath' (rc=`=_rc')"
		exit _rc
	}
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

	save "`varinfo'", replace

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

	// Loop through each variable - extract info from current row first
	forvalues i = 1/`nvars' {
			// Read info from varinfo while we're in that dataset
			local vname = varname[`i']
			local vtype = vartype[`i']
			local vfmt = varformat[`i']
			local valab = valuelabel[`i']

			// Calculate missing count by loading original dataset
			use "`filepath'", clear
			count if missing(`vname')
			local nmiss = r(N)
			if `obs' > 0 {
				local pctmiss = round(100*`nmiss'/`obs', 0.1)
			}
			else {
				local pctmiss = .
			}

			// Go back to varinfo and update
			use "`varinfo'", clear
			replace missing_n = `nmiss' in `i'
			replace missing_pct = `pctmiss' in `i'

			// Classify variable
			local isexcluded 0
			foreach ev of local exclude_vars {
				if "`vname'" == "`ev'" local isexcluded 1
			}

			if `isexcluded' {
				replace classification = "excluded" in `i'
			}
			else if strpos("`vtype'", "str") == 1 {
				replace classification = "string" in `i'
			}
			else if strpos("`vfmt'", "%t") > 0 {
				replace classification = "date" in `i'
			}
			else {
				// Count unique values
				use "`filepath'", clear
				capture tab `vname', matrow(vals)
				if _rc == 0 {
					local nuniq = r(r)
				}
				else {
					// Tab failed (too many values), treat as continuous
					local nuniq = `maxcat' + 1
				}

				use "`varinfo'", clear
				replace unique_vals = `nuniq' in `i'

				if "`valab'" != "" | `nuniq' <= `maxcat' {
					replace classification = "categorical" in `i'
				}
				else {
					replace classification = "continuous" in `i'
				}

				// Check if binary (for detect_binary option)
				if `detect_binary' & `nuniq' == 2 {
					replace is_binary = 1 in `i'
				}
			}

			// Quality checks if requested
			if "`quality_level'" != "" & !`isexcluded' {
				use "`filepath'", clear
				local qflag ""

				// Check for implausible values based on variable name
				if regexm(lower("`vname'"), "age") {
					quietly summarize `vname'
					if !missing(r(min)) & r(min) < 0 {
						local qflag "negative age values"
					}
					else if !missing(r(max)) & r(max) > 120 {
						if "`quality_level'" == "strict" & r(max) > 100 {
							local qflag "age >100"
						}
						else if r(max) > 120 {
							local qflag "age >120"
						}
					}
				}
				else if regexm(lower("`vname'"), "count|number|^n_") {
					quietly summarize `vname'
					if !missing(r(min)) & r(min) < 0 {
						local qflag "negative count"
					}
				}
				else if regexm(lower("`vname'"), "percent|pct|proportion") {
					quietly summarize `vname'
					if !missing(r(min)) & (r(min) < 0 | r(max) > 100) {
						local qflag "percent out of range 0-100"
					}
				}

				use "`varinfo'", clear
				if "`qflag'" != "" {
					replace quality_flag = "`qflag'" in `i'
				}
			}

			// Save varinfo after each iteration to preserve changes
			save "`varinfo'", replace
		}

	save "`classifications'", replace

	// Write summary table
	assert _N == `nvars'  // Verify expected row count
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
			local pctmiss = 0
		}
		else {
			local pctmiss = missing_pct[`i']
		}

		file write `fh' "  `vname'" _n
		file write `fh' "    Type: `vtype'" _n
		file write `fh' "    Format: `vfmt'" _n
		if `"`vlab'"' != "" file write `fh' `"    Label: `vlab'"' _n
		file write `fh' "    Missing: `nmiss' (`pctmiss'%)" _n
		file write `fh' "    Classification: `vclass'" _n _n
	}
	
	// Detailed variable sections
	noisily di as text "    Processing categorical variables..."
	ProcessCategorical `fh' "`filepath'" "`classifications'" "`format'" "`nofreq'" `maxfreq' `obs'
	noisily di as text "    Processing continuous variables..."
	ProcessContinuous `fh' "`filepath'" "`classifications'" "`format'" "`nostats'" `obs'
	noisily di as text "    Processing date variables..."
	ProcessDate `fh' "`filepath'" "`classifications'" "`format'" "`datesafe'"
	noisily di as text "    Processing string variables..."
	ProcessString `fh' "`filepath'" "`classifications'" "`format'"
	noisily di as text "    Processing excluded variables..."
	ProcessExcluded `fh' "`filepath'" "`classifications'" "`format'"

	// Binary variables section (if detect_binary enabled)
	if `detect_binary' {
		noisily di as text "    Processing binary variables..."
		ProcessBinary `fh' "`filepath'" "`classifications'" "`format'" `obs'
	}

	// Data quality flags (if quality checks enabled)
	if "`quality_level'" != "" {
		noisily di as text "    Processing quality flags..."
		ProcessQuality `fh' "`filepath'" "`classifications'" "`format'"
	}

	// Sample observations (if requested)
	if `samples' > 0 {
		noisily di as text "    Including sample observations..."
		ProcessSamples `fh' "`filepath'" "`classifications'" "`format'" `samples' "`exclude'"
	}

	// Value label definitions
	if "`nolabels'" == "" {
		noisily di as text "    Processing value labels..."
		ProcessValueLabels `fh' "`filepath'" "`classifications'" "`format'"
	}
end

program define ProcessCategorical
	args fh filepath classifications format nofreq maxfreq obs
	
	tempfile catdata
	use "`classifications'", clear
	count if classification == "categorical"
	if r(N) == 0 {
		exit
	}
	local ncat = r(N)
	
	file write `fh' "========================================" _n
	file write `fh' "CATEGORICAL VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	use "`classifications'", clear
	keep if classification == "categorical"
	save `catdata', replace
	local nvars = _N
	
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
			local pctmiss = 0
		}
		else {
			local pctmiss = missing_pct[`i']
		}
		if missing(unique_vals[`i']) {
			local nuniq = 0
		}
		else {
			local nuniq = unique_vals[`i']
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `i'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`vlab'"' != "" file write `fh' `"Label: `vlab'"' _n
		if "`valab'" != "" file write `fh' "Value Label: `valab'" _n
		file write `fh' "Classification: categorical" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "Unique Values: `nuniq'" _n _n
		
		// Frequency table
		if "`nofreq'" == "" & `nuniq' <= `maxfreq' {
			use "`filepath'", clear
			
			file write `fh' "  Frequencies:" _n
			capture tab `vname', matrow(vals) matcell(freqs)
			if _rc == 0 {
				local nvals = r(r)
				forvalues j = 1/`nvals' {
					local val = vals[`j',1]
					local freq = freqs[`j',1]
					if `obs' > 0 {
						local pct = round(100*`freq'/`obs', 0.1)
					}
					else {
						local pct = .
					}
					local vlab : label (`vname') `val'
					file write `fh' "    `val' = `vlab': `freq' (`pct'%)" _n
				}
			}
			else {
				file write `fh' "    (frequency table unavailable)" _n
			}
			file write `fh' _n

			use "`catdata'", clear
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
		file write `fh' _n _n
	}
end

program define ProcessContinuous
	args fh filepath classifications format nostats obs
	
	tempfile contdata
	use "`classifications'", clear
	count if classification == "continuous"
	if r(N) == 0 {
		exit
	}
	
	file write `fh' "========================================" _n
	file write `fh' "CONTINUOUS VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	use "`classifications'", clear
	keep if classification == "continuous"
	save `contdata', replace
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
			local pctmiss = 0
		}
		else {
			local pctmiss = missing_pct[`i']
		}
		if missing(unique_vals[`i']) {
			local nuniq = 0
		}
		else {
			local nuniq = unique_vals[`i']
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `i'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`vlab'"' != "" file write `fh' `"Label: `vlab'"' _n
		file write `fh' "Classification: continuous" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "Unique Values: `nuniq'" _n _n

		// Summary statistics
		if "`nostats'" == "" {
			use "`filepath'", clear
			summarize `vname', detail
			local n = r(N)

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

				// Add analysis guidance
				file write `fh' "ANALYSIS GUIDANCE: "
				file write `fh' "Use as continuous variable. "

				// Check for skewness
				local skew = (`mean' - `p50') / `sd'
				if abs(`skew') > 1 {
					file write `fh' "Distribution appears skewed - consider transformation. "
				}

				// Check for outliers (simple IQR method)
				local iqr = `p75' - `p25'
				if `iqr' > 0 {
					local lower = `p25' - 3*`iqr'
					local upper = `p75' + 3*`iqr'
					if `min' < `lower' | `max' > `upper' {
						file write `fh' "Potential outliers detected - verify data quality. "
					}
				}

				file write `fh' "Check normality assumption if using parametric tests."
				file write `fh' _n _n
			}
			else {
				// All values missing
				file write `fh' "DISTRIBUTION: (all values missing)" _n _n
			}

			use "`contdata'", clear
		}
	}
end

program define ProcessDate
	args fh filepath classifications format datesafe
	
	tempfile datedata
	use "`classifications'", clear
	count if classification == "date"
	if r(N) == 0 {
		exit
	}
	
	file write `fh' "========================================" _n
	file write `fh' "DATE VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	use "`classifications'", clear
	keep if classification == "date"
	save `datedata', replace
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
			local pctmiss = 0
		}
		else {
			local pctmiss = missing_pct[`i']
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `i'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`vlab'"' != "" file write `fh' `"Label: `vlab'"' _n
		file write `fh' "Classification: date" _n
		file write `fh' "  Missing: `nmiss' obs (`pctmiss'%)" _n _n

		// Date range
		use "`filepath'", clear
		summarize `vname'
		local minval = r(min)
		local maxval = r(max)

		if "`datesafe'" == "" {
			// Show exact date range
			if !missing(`minval') & !missing(`maxval') {
				local mindate = string(`minval', "`vfmt'")
				local maxdate = string(`maxval', "`vfmt'")
				local span = `maxval' - `minval'
				file write `fh' "DATE RANGE:" _n
				file write `fh' "  Earliest: `mindate'" _n
				file write `fh' "  Latest: `maxdate'" _n
				file write `fh' "  Span: `span' days" _n _n
			}
			else {
				file write `fh' "DATE RANGE: (all values missing)" _n _n
			}
		}
		else {
			// Privacy-safe: show only range span or suppress
			if !missing(`minval') & !missing(`maxval') {
				local span = `maxval' - `minval'
				file write `fh' "DATE RANGE: `span' day span (exact dates suppressed for privacy)" _n _n
			}
			else {
				file write `fh' "DATE RANGE: (all values missing)" _n _n
			}
		}

		// Add analysis guidance
		file write `fh' "ANALYSIS GUIDANCE: "
		file write `fh' "Can be used to calculate durations, create time-to-event variables, "
		file write `fh' "or generate time periods. Verify date ranges are plausible before analysis."
		file write `fh' _n _n

		use "`datedata'", clear
	}
end

program define ProcessString
	args fh filepath classifications format
	
	tempfile stringdata
	use "`classifications'", clear
	count if classification == "string"
	if r(N) == 0 {
		exit
	}
	
	file write `fh' "========================================" _n
	file write `fh' "STRING VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	use "`classifications'", clear
	keep if classification == "string"
	save `stringdata', replace
	local nvars = _N
	
	assert _N == `nvars'  // Verify expected row count
	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local vtype = vartype[`i']
		local vlab = varlabel[`i']

		// Handle missing values properly
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

		use "`filepath'", clear
		gen double _len = length(`vname')
		summarize _len
		local maxlen = r(max)
		if missing(`maxlen') local maxlen = 0
		drop _len
		capture tab `vname'
		if _rc == 0 {
			local nuniq = r(r)
		}
		else {
			local nuniq "(too many)"
		}
		
		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `i'" _n
		file write `fh' "Storage Type: `vtype'" _n
		if `"`vlab'"' != "" file write `fh' `"Label: `vlab'"' _n
		file write `fh' "Classification: string" _n
		file write `fh' "Max Length: `maxlen' characters" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "Unique Values: `nuniq'" _n
		file write `fh' "(exact values suppressed)" _n _n

		// Add analysis guidance
		file write `fh' "ANALYSIS GUIDANCE: "
		file write `fh' "String variable - may contain free text, codes, or identifiers. "
		if "`nuniq'" != "(too many)" {
			if `nuniq' <= 25 {
				file write `fh' "Low cardinality suggests categorical data - consider encoding as numeric. "
			}
		}
		file write `fh' "Verify encoding if contains non-ASCII characters."
		file write `fh' _n _n

		use "`stringdata'", clear
	}
end

program define ProcessExcluded
	args fh filepath classifications format
	
	tempfile excludedata
	use "`classifications'", clear
	count if classification == "excluded"
	if r(N) == 0 {
		exit
	}
	
	file write `fh' "========================================" _n
	file write `fh' "EXCLUDED VARIABLES" _n
	file write `fh' "========================================" _n _n
	
	use "`classifications'", clear
	keep if classification == "excluded"
	save `excludedata', replace
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
			local pctmiss = 0
		}
		else {
			local pctmiss = missing_pct[`i']
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `i'" _n
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

program define ProcessValueLabels
	args fh filepath classifications format
	
	// Get all value labels used
	tempfile labdata
	use "`classifications'", clear
	keep if valuelabel != ""
	if _N == 0 {
		exit
	}
	
	// Get unique value labels
	levelsof valuelabel, local(vallabs)
	save `labdata', replace
	
	if "`vallabs'" == "" exit
	
	file write `fh' "========================================" _n
	file write `fh' "VALUE LABEL DEFINITIONS" _n
	file write `fh' "========================================" _n _n
	
	// Process each value label
	foreach vl of local vallabs {
		// Get variables using this label
		use `labdata', clear
		keep if valuelabel == "`vl'"
		local nvars = _N
		assert _N == `nvars'  // Verify expected row count
		local varlist ""
		forvalues i = 1/`nvars' {
			local vn = varname[`i']
			local varlist "`varlist' `vn'"
		}
		
		local varlist = strtrim("`varlist'")
		
		// Get label mappings by loading dataset
		use "`filepath'", clear

		file write `fh' "`vl' (used by: `varlist')" _n

		// Check if the label is actually defined
		capture label list `vl'
		if _rc == 0 {
			// Label exists - extract values by iterating through them
			local labname "`vl'"

			// Use extended macro to get label range
			levelsof `: word 1 of `varlist'', local(levels)
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
// Helper: ProcessBinary
// Document binary variables (exactly 2 unique values)
// =============================================================================
program define ProcessBinary
	args fh filepath classifications format obs

	tempfile bindata
	use "`classifications'", clear
	count if is_binary == 1
	if r(N) == 0 {
		exit
	}

	file write `fh' "Binary Variables (potential outcomes/indicators)" _n _n

	use "`classifications'", clear
	keep if is_binary == 1
	save `bindata', replace
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
		use "`filepath'", clear
		quietly tab `vname', matrow(vals) matcell(freqs)
		local nvals = r(r)

		file write `fh' "  Frequency:" _n
		forvalues j = 1/`nvals' {
			local val = vals[`j',1]
			local freq = freqs[`j',1]
			if `obs' > 0 {
				local pct = round(100*`freq'/`obs', 0.1)
			}
			else {
				local pct = .
			}
			capture local vlab : label (`vname') `val'
			if _rc == 0 & "`vlab'" != "" {
				file write `fh' "    `val' (`vlab'): `freq' (`pct'%)" _n
			}
			else {
				file write `fh' "    `val': `freq' (`pct'%)" _n
			}
		}
		file write `fh' _n

		use "`bindata'", clear
	}
end

// =============================================================================
// Helper: ProcessQuality
// Report data quality flags
// =============================================================================
program define ProcessQuality
	args fh filepath classifications format

	use "`classifications'", clear
	count if quality_flag != ""
	if r(N) == 0 {
		exit
	}

	file write `fh' "Data Quality Flags" _n _n

	use "`classifications'", clear
	keep if quality_flag != ""
	local nvars = _N

	assert _N == `nvars'
	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local qflag = quality_flag[`i']

		file write `fh' "  `vname': `qflag'" _n
	}
	file write `fh' _n
end

// =============================================================================
// Helper: ProcessSamples
// Include sample observations
// =============================================================================
program define ProcessSamples
	args fh filepath classifications format nsamples exclude

	use "`filepath'", clear

	// Limit to requested number of observations
	if _N > `nsamples' {
		keep in 1/`nsamples'
	}

	local nsamp = _N

	file write `fh' "Sample Observations (first `nsamp' rows)" _n _n

	// Get list of non-excluded variables
	quietly describe
	local allvars ""
	forvalues i = 1/`r(k)' {
		local vn = varname[`i']
		local allvars "`allvars' `vn'"
	}

	// Build excluded variable list
	local exclude_list ""
	if "`exclude'" != "" {
		foreach ev of local exclude {
			local exclude_list "`exclude_list' `ev'"
		}
	}

	// Write header row with variable names
	file write `fh' "  "
	foreach v of local allvars {
		file write `fh' "`v'" _col(+2)
	}
	file write `fh' _n

	// Write each observation
	forvalues obs_i = 1/`nsamp' {
		file write `fh' "  "
		foreach v of local allvars {
			// Check if excluded
			local is_excluded 0
			foreach ev of local exclude_list {
				if "`v'" == "`ev'" {
					local is_excluded 1
				}
			}

			if `is_excluded' {
				file write `fh' "***" _col(+2)
			}
			else {
				local val = `v'[`obs_i']
				file write `fh' "`val'" _col(+2)
			}
		}
		file write `fh' _n
	}
	file write `fh' _n
end

// =============================================================================
// Detection Functions
// =============================================================================

// Detect panel/longitudinal structure
program define DetectPanel
	args fh filepath panelid format

	use "`filepath'", clear

	// Auto-detect panel ID if not specified
	if "`panelid'" == "" {
		// Get list of all variables
		quietly describe, varlist
		local allvars `r(varlist)'

		local potential_ids ""

		// Check each variable
		foreach vname of local allvars {
			// Get variable type
			local vtype : type `vname'
			local vfmt : format `vname'

			// Skip strings and dates
			if strpos("`vtype'", "str") == 0 & strpos("`vfmt'", "%t") == 0 {
				quietly count if !missing(`vname')
				local nonmiss = r(N)
				if `nonmiss' > 0 {
					capture tab `vname'
					if _rc == 0 {
						local nuniq = r(r)
						// Check if unique < 50% of total N
						if `nuniq' < `nonmiss' * 0.5 & `nuniq' > 1 {
							local potential_ids "`potential_ids' `vname'"
						}
					}
				}
			}
		}

		// Use first potential ID found
		if "`potential_ids'" != "" {
			local panelid : word 1 of `potential_ids'
		}
		else {
			// No panel structure detected
			exit
		}
	}

	// Verify panelid exists
	capture confirm variable `panelid'
	if _rc != 0 {
		exit
	}

	// Calculate panel statistics
	quietly count if !missing(`panelid')
	local n_nonmiss = r(N)

	quietly tab `panelid'
	local n_units = r(r)

	tempvar obs_per_unit
	quietly bysort `panelid': gen `obs_per_unit' = _N
	quietly summarize `obs_per_unit'
	local mean_obs = round(r(mean), 0.1)
	local min_obs = r(min)
	local max_obs = r(max)

	// Check balance
	local is_balanced = (`min_obs' == `max_obs')

	// Write output
	file write `fh' "Dataset Structure: Panel/Longitudinal" _n
	file write `fh' "  Panel ID: `panelid'" _n
	file write `fh' "  Unique units: `n_units'" _n
	file write `fh' "  Observations per unit: mean=`mean_obs', min=`min_obs', max=`max_obs', total=`n_nonmiss'" _n
	if `is_balanced' {
		file write `fh' "  Panel balance: Balanced" _n
	}
	else {
		file write `fh' "  Panel balance: Unbalanced" _n
	}
	file write `fh' _n
end

// Detect survival analysis structure
program define DetectSurvival
	args fh filepath survivalvars format

	use "`filepath'", clear

	// Parse survivalvars if provided
	if "`survivalvars'" != "" {
		gettoken timevar failvar : survivalvars
	}
	else {
		// Auto-detect
		quietly describe, varlist
		local allvars `r(varlist)'

		local timevar ""
		local failvar ""

		// Look for time variables (continuous, positive)
		foreach vn of local allvars {
			// Check for time-related names
			if regexm(lower("`vn'"), "time|followup|duration|surv") {
				capture summarize `vn'
				if _rc == 0 & r(min) >= 0 {
					local timevar "`vn'"
				}
			}
		}

		// Look for event/failure variables (binary)
		foreach vn of local allvars {
			if regexm(lower("`vn'"), "event|fail|death|died|outcome") {
				capture tab `vn'
				if _rc == 0 & r(r) == 2 {
					local failvar "`vn'"
				}
			}
		}

		if "`timevar'" == "" | "`failvar'" == "" {
			// Not detected
			exit
		}
	}

	// Verify variables exist
	capture confirm variable `timevar'
	if _rc != 0 exit
	capture confirm variable `failvar'
	if _rc != 0 exit

	// Calculate survival statistics
	quietly summarize `timevar', detail
	local mean_time = round(r(mean), 0.1)
	local sd_time = round(r(sd), 0.1)
	local min_time = round(r(min), 0.1)
	local max_time = round(r(max), 0.1)

	quietly tab `failvar'
	quietly count if `failvar' == 1
	local n_events = r(N)
	quietly count if `failvar' == 0
	local n_censored = r(N)
	quietly count if !missing(`failvar')
	local n_total = r(N)

	local pct_events = round(100 * `n_events' / `n_total', 0.1)
	local pct_censored = round(100 * `n_censored' / `n_total', 0.1)

	// Person-time
	quietly summarize `timevar'
	local person_time = round(r(sum), 0.1)

	// Write output
	file write `fh' "Survival Analysis Structure Detected" _n
	file write `fh' "  Time variable: `timevar'" _n
	file write `fh' "    Mean follow-up: `mean_time' (SD: `sd_time')" _n
	file write `fh' "    Range: `min_time' to `max_time'" _n
	file write `fh' "  Event variable: `failvar'" _n
	file write `fh' "    Events: `n_events' (`pct_events'%)" _n
	file write `fh' "    Censored: `n_censored' (`pct_censored'%)" _n
	file write `fh' "  Person-time: `person_time'" _n
	file write `fh' _n
end

// Detect survey design elements
program define DetectSurvey
	args fh filepath format

	use "`filepath'", clear

	quietly describe, varlist
	local allvars `r(varlist)'

	local weight_vars ""
	local strata_vars ""
	local cluster_vars ""

	// Search for survey design variables
	foreach vn of local allvars {
		local vn_lower = lower("`vn'")

		// Weight variables
		if regexm("`vn_lower'", "weight|wt$|^wt_") {
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
program define DetectCommon
	args fh filepath format

	use "`filepath'", clear

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
program define SummarizeMissing
	args fh filepath format pattern_check obs

	use "`filepath'", clear

	quietly describe, varlist
	local allvars `r(varlist)'

	// Count variables by missing percentage
	local vars_gt50 ""
	local n_gt50 = 0
	local vars_gt10 ""
	local n_gt10 = 0

	tempvar complete
	gen `complete' = 1

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
// Helper: GenerateDatasetSummary
// Generate natural language description of the dataset
// =============================================================================
program define GenerateDatasetSummary
	args fh filepath obs nvars label detect_panel detect_survival panelid

	use "`filepath'", clear

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
	quietly describe, varlist
	local allvars `r(varlist)'
	local has_dates 0
	local earliest .
	local latest .

	foreach vn of local allvars {
		local vfmt: format `vn'
		if strpos("`vfmt'", "%t") > 0 {
			quietly summarize `vn'
			if r(N) > 0 {
				if `earliest' == . | r(min) < `earliest' {
					local earliest = r(min)
				}
				if `latest' == . | r(max) > `latest' {
					local latest = r(max)
				}
				local has_dates 1
			}
		}
	}

	if `has_dates' & `earliest' != . & `latest' != . {
		local earliest_str = string(`earliest', "%tdCY-N-D")
		local latest_str = string(`latest', "%tdCY-N-D")
		local summary "`summary'The data spans from `earliest_str' to `latest_str'. "
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

