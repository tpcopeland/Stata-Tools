*! datadict v1.0.0
*! Generate professional Markdown data dictionaries
*! Companion to datamap (LLM-focused)
*! Author: Tim Copeland
*! Date: 2025-11-17

/*
SYNTAX
------
datadict [, options]

OPTIONS
-------
Input (choose one):
  single(filename)    Single .dta file to document
  directory(path)     Document all .dta files in directory
  filelist(filename)  Text file listing .dta files to process
  recursive           Scan subdirectories (with directory())

Output:
  output(filename)    Output markdown file (default: data_dictionary.md)
  separate            Create separate output file per dataset
  append              Append to existing output file

Content Control:
  title(string)       Document title (default: "Data Dictionary")
  version(string)     Version number for documentation
  authors(string)     Author names
  toc                 Include table of contents
  maxfreq(#)          Max unique values for frequency tables (default: 25)
  maxcat(#)           Max unique values to treat as categorical (default: 25)

Privacy:
  exclude(varlist)    Variables to document structure only
  datesafe            Show only date range spans, not exact dates

DESCRIPTION
-----------
datadict generates professional Markdown data dictionaries suitable for
documentation, version control, and conversion to HTML/DOCX via Stata's
dyndoc command.

Output format is clean Markdown with tables, sections, and proper formatting
that renders beautifully in GitHub, VSCode, Pandoc, and after dyndoc conversion.

EXAMPLES
--------
. datadict, single(patients.dta)
. datadict, single(patients.dta) output(dict.md) title("Patient Registry")
. datadict, directory(.) separate toc
. dyndoc data_dictionary.md, replace   // Convert to HTML

STORED RESULTS
--------------
r(nfiles)   - number of datasets documented
r(output)   - output filename
*/

program define datadict, rclass
	version 14.0
	syntax [, Single(string) DIRectory(string) FILElist(string) ///
	          RECursive ///
	          Output(string) SEParate APPend ///
	          Title(string) VERsion(string) AUTHors(string) ///
	          TOC ///
	          MAXFreq(integer 25) MAXCat(integer 25) ///
	          EXClude(string) DATESafe]

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

	// Set defaults
	if "`output'" == "" local output "data_dictionary.md"
	if "`title'" == "" local title "Data Dictionary"

	// Validate numeric parameters
	if `maxfreq' <= 0 {
		di as error "maxfreq must be positive"
		exit 198
	}
	if `maxcat' <= 0 {
		di as error "maxcat must be positive"
		exit 198
	}

	// Collect files to process
	tempfile filelist_tmp
	if "`single'" != "" {
		confirm file "`single'"
		local nfiles 1
	}
	else if "`filelist'" != "" {
		confirm file "`filelist'"
		CollectFromList "`filelist'" "`filelist_tmp'"
		CountFiles "`filelist_tmp'"
		local nfiles = r(nfiles)
	}
	else {
		if "`directory'" == "" local directory "."
		CollectFromDir "`directory'" "`recursive'" "`filelist_tmp'"
		CountFiles "`filelist_tmp'"
		local nfiles = r(nfiles)
	}

	// Error if no files found
	if "`single'" == "" & `nfiles' == 0 {
		di as error "no .dta files found"
		exit 601
	}

	// Process files
	if "`separate'" != "" {
		// Separate output per dataset
		ProcessSeparateMarkdown, filelist("`filelist_tmp'") ///
			title("`title'") version("`version'") authors("`authors'") ///
			`toc' maxfreq(`maxfreq') maxcat(`maxcat') ///
			exclude("`exclude'") `datesafe' nfiles(`nfiles')
	}
	else {
		// Combined output
		ProcessCombinedMarkdown, filelist("`filelist_tmp'") output("`output'") ///
			single("`single'") `append' ///
			title("`title'") version("`version'") authors("`authors'") ///
			`toc' maxfreq(`maxfreq') maxcat(`maxcat') ///
			exclude("`exclude'") `datesafe' nfiles(`nfiles')
	}

	// Return results
	return scalar nfiles = `nfiles'
	return local output = "`output'"

	di as result "Markdown dictionary generated: `output'"
	di as text "To convert to HTML, run: dyndoc `output', replace"
end

// =============================================================================
// Helper: CollectFromList (borrowed from datamap)
// =============================================================================
program define CollectFromList
	args filelist tmpfile

	tempname fh_in fh_out
	file open `fh_in' using "`filelist'", read text
	file open `fh_out' using "`tmpfile'", write text replace

	file read `fh_in' line
	while r(eof) == 0 {
		local line = strtrim("`line'")
		if "`line'" != "" & substr("`line'", 1, 1) != "*" {
			file write `fh_out' `"`line'"' _n
		}
		file read `fh_in' line
	}
	file close `fh_in'
	file close `fh_out'
end

// =============================================================================
// Helper: CollectFromDir (borrowed from datamap)
// =============================================================================
program define CollectFromDir
	args directory recursive tmpfile

	tempname fh
	file open `fh' using "`tmpfile'", write text replace

	if "`recursive'" == "" {
		local files : dir "`directory'" files "*.dta"
		foreach f of local files {
			if "`directory'" != "." {
				file write `fh' "`directory'/`f'" _n
			}
			else {
				file write `fh' "`f'" _n
			}
		}
	}
	else {
		RecursiveScan "`directory'" `fh'
	}

	file close `fh'
end

program define RecursiveScan
	args directory fh

	local files : dir "`directory'" files "*.dta"
	foreach f of local files {
		if "`directory'" != "." {
			file write `fh' "`directory'/`f'" _n
		}
		else {
			file write `fh' "`f'" _n
		}
	}

	local subdirs : dir "`directory'" dirs "*"
	foreach subdir of local subdirs {
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
// Helper: CountFiles
// =============================================================================
program define CountFiles, rclass
	args tmpfile

	tempname fh
	file open `fh' using "`tmpfile'", read text
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
// Helper: ProcessCombinedMarkdown
// =============================================================================
program define ProcessCombinedMarkdown
	syntax, filelist(string) output(string) [single(string) append ///
		title(string) version(string) authors(string) toc ///
		maxfreq(integer 25) maxcat(integer 25) exclude(string) datesafe nfiles(integer 1)]

	di as text "Creating Markdown dictionary: `output'"

	tempname fh
	if "`append'" != "" {
		file open `fh' using "`output'", write text append
	}
	else {
		file open `fh' using "`output'", write text replace

		// Write document header
		WriteMarkdownDocHeader `fh' "`title'" "`version'" "`authors'"

		// Write table of contents if requested
		if "`toc'" != "" {
			WriteMarkdownTOC `fh' `nfiles'
		}
	}

	// Process each file
	if "`single'" != "" {
		di as text "  Processing: `single'"
		ProcessDatasetMarkdown `fh' "`single'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" 1 `nfiles'
	}
	else {
		tempname fh_list
		file open `fh_list' using "`filelist'", read text
		local i 0
		file read `fh_list' thisfile
		while r(eof) == 0 {
			local ++i
			di as text "  Processing `i' of `nfiles': `thisfile'"
			ProcessDatasetMarkdown `fh' "`thisfile'" `maxfreq' `maxcat' ///
				"`exclude'" "`datesafe'" `i' `nfiles'
			file read `fh_list' thisfile
		}
		file close `fh_list'
	}

	file close `fh'
	di as result `"Output written to: `output'"'
end

// =============================================================================
// Helper: ProcessSeparateMarkdown
// =============================================================================
program define ProcessSeparateMarkdown
	syntax, filelist(string) [title(string) version(string) authors(string) toc ///
		maxfreq(integer 25) maxcat(integer 25) exclude(string) datesafe nfiles(integer 1)]

	tempname fh_list
	file open `fh_list' using "`filelist'", read text
	file read `fh_list' thisfile
	while r(eof) == 0 {
		// Generate output filename
		local len = length("`thisfile'")
		if substr("`thisfile'", `len'-3, 4) == ".dta" {
			local basename = substr("`thisfile'", 1, `len'-4)
		}
		else {
			local basename "`thisfile'"
		}
		local outfile "`basename'_dictionary.md"

		di as text "Creating: `outfile'"

		tempname fh
		file open `fh' using "`outfile'", write text replace

		// Write header
		WriteMarkdownDocHeader `fh' "`title'" "`version'" "`authors'"
		if "`toc'" != "" {
			WriteMarkdownTOC `fh' 1
		}

		// Process dataset
		ProcessDatasetMarkdown `fh' "`thisfile'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" 1 1

		file close `fh'
		di as result `"Output written to: `outfile'"'

		file read `fh_list' thisfile
	}
	file close `fh_list'
end

// =============================================================================
// Helper: WriteMarkdownDocHeader
// =============================================================================
program define WriteMarkdownDocHeader
	args fh title version authors

	file write `fh' "# `title'" _n _n

	if "`version'" != "" {
		file write `fh' "**Version:** `version'  " _n
	}
	file write `fh' "**Date:** `c(current_date)'  " _n
	if "`authors'" != "" {
		file write `fh' "**Authors:** `authors'  " _n
	}
	file write `fh' _n
end

// =============================================================================
// Helper: WriteMarkdownTOC
// =============================================================================
program define WriteMarkdownTOC
	args fh nfiles

	file write `fh' "## Table of Contents" _n _n
	file write `fh' "1. [Dataset Information](#dataset-information)" _n
	file write `fh' "2. [Variable Definitions](#variable-definitions)" _n
	file write `fh' "   - [Identifiers](#identifiers)" _n
	file write `fh' "   - [Demographics](#demographics)" _n
	file write `fh' "   - [Categorical Variables](#categorical-variables)" _n
	file write `fh' "   - [Continuous Variables](#continuous-variables)" _n
	file write `fh' "   - [Date Variables](#date-variables)" _n
	file write `fh' "   - [String Variables](#string-variables)" _n
	file write `fh' "3. [Value Label Definitions](#value-label-definitions)" _n
	file write `fh' "4. [Data Quality Notes](#data-quality-notes)" _n
	file write `fh' _n "---" _n _n
end

// =============================================================================
// Helper: ProcessDatasetMarkdown
// =============================================================================
program define ProcessDatasetMarkdown
	args fh filepath maxfreq maxcat exclude datesafe idx total

	// Get dataset metadata
	capture describe using "`filepath'", short
	if _rc != 0 {
		di as error "ERROR: Could not describe `filepath'"
		exit _rc
	}
	local obs = r(N)
	local nvars = r(k)
	local label = r(label)
	local sortlist = r(sortlist)

	// Handle empty dataset edge case
	if `obs' == 0 {
		di as text "  Warning: Dataset `filepath' has 0 observations - limited documentation generated"
	}

	// Extract basename
	local basename = "`filepath'"
	if strpos("`filepath'", "/") > 0 {
		local basename = reverse("`filepath'")
		local slashpos = strpos("`basename'", "/")
		if `slashpos' > 0 {
			local basename = reverse(substr("`basename'", 1, `slashpos'-1))
		}
	}

	// Dataset header
	if `idx' > 1 file write `fh' _n "---" _n _n
	file write `fh' "## Dataset: `basename'" _n _n

	// Write dataset info table
	file write `fh' "| Property | Value |" _n
	file write `fh' "|----------|-------|" _n
	file write `fh' "| Observations | " (`obs') " |" _n
	file write `fh' "| Variables | " (`nvars') " |" _n
	if `"`label'"' != "" & `"`label'"' != "." {
		file write `fh' "| Label | `label' |" _n
	}
	if "`sortlist'" != "" {
		file write `fh' "| Sort Order | `sortlist' |" _n
	}

	// Add datasignature
	capture datasignature using "`filepath'"
	if _rc == 0 {
		file write `fh' "| Data Signature | `r(datasignature)' |" _n
	}
	file write `fh' _n

	// Load dataset for variable processing
	use "`filepath'", clear

	// Generate variable summary table
	WriteMarkdownVariableSummaryTable `fh' `maxfreq' `maxcat' "`exclude'" `obs'

	// Generate detailed variable sections by group
	WriteMarkdownDetailedVariables `fh' `maxfreq' `maxcat' "`exclude'" "`datesafe'" `obs'

	// Value label definitions
	WriteMarkdownValueLabels `fh'

	// Data quality notes
	WriteMarkdownQualityNotes `fh' `obs'
end

// =============================================================================
// Helper: WriteMarkdownVariableSummaryTable
// =============================================================================
program define WriteMarkdownVariableSummaryTable
	args fh maxfreq maxcat exclude obs

	file write `fh' "### Variable Summary" _n _n
	file write `fh' "| Variable | Label | Type | Format | Missing | Classification |" _n
	file write `fh' "|----------|-------|------|--------|---------|----------------|" _n

	quietly describe, varlist
	local allvars `r(varlist)'

	foreach vn of local allvars {
		local vtype: type `vn'
		local vfmt: format `vn'
		local vlab: variable label `vn'

		// Count missing
		quietly count if missing(`vn')
		local nmiss = r(N)
		if `obs' > 0 {
			local pctmiss = string(100*`nmiss'/`obs', "%4.1f")
		}
		else {
			local pctmiss = "0.0"
		}

		// Classify
		ClassifyVariable "`vn'" "`vtype'" "`vfmt'" `maxcat' "`exclude'"
		local class = r(class)

		// Write row (escape pipes in labels)
		local vlab_safe = subinstr("`vlab'", "|", "\|", .)
		file write `fh' "| \``vn'\` | `vlab_safe' | `vtype' | `vfmt' | "
		file write `fh' "`nmiss' (`pctmiss'%) | `class' |" _n
	}
	file write `fh' _n
end

// =============================================================================
// Helper: ClassifyVariable (returns classification string)
// =============================================================================
program define ClassifyVariable, rclass
	args vname vtype vfmt maxcat exclude

	// Check if excluded
	if "`exclude'" != "" {
		foreach ev of local exclude {
			if "`vname'" == "`ev'" {
				return local class "excluded"
				exit
			}
		}
	}

	// Classify
	if strpos("`vtype'", "str") == 1 {
		return local class "string"
	}
	else if strpos("`vfmt'", "%t") > 0 {
		return local class "date"
	}
	else {
		// Check for value label or cardinality
		local valab: value label `vname'
		quietly tab `vname'
		if _rc == 0 {
			local nuniq = r(r)
			if "`valab'" != "" | `nuniq' <= `maxcat' {
				return local class "categorical"
			}
			else {
				return local class "continuous"
			}
		}
		else {
			return local class "continuous"
		}
	}
end

// =============================================================================
// Helper: WriteMarkdownDetailedVariables
// =============================================================================
program define WriteMarkdownDetailedVariables
	args fh maxfreq maxcat exclude datesafe obs

	// Group variables by type
	quietly describe, varlist
	local allvars `r(varlist)'

	local id_vars ""
	local demo_vars ""
	local cat_vars ""
	local cont_vars ""
	local date_vars ""
	local string_vars ""
	local excl_vars ""

	foreach vn of local allvars {
		local vtype: type `vn'
		local vfmt: format `vn'
		ClassifyVariable "`vn'" "`vtype'" "`vfmt'" `maxcat' "`exclude'"
		local class = r(class)

		// Check if ID/key variable
		local vn_lower = lower("`vn'")
		if regexm("`vn_lower'", "^id$|_id$|patient|subject") {
			local id_vars "`id_vars' `vn'"
		}
		// Check if demographic
		else if regexm("`vn_lower'", "age|sex|gender|race|ethnic") {
			local demo_vars "`demo_vars' `vn'"
		}
		// Otherwise group by classification
		else {
			if "`class'" == "categorical" local cat_vars "`cat_vars' `vn'"
			else if "`class'" == "continuous" local cont_vars "`cont_vars' `vn'"
			else if "`class'" == "date" local date_vars "`date_vars' `vn'"
			else if "`class'" == "string" local string_vars "`string_vars' `vn'"
			else if "`class'" == "excluded" local excl_vars "`excl_vars' `vn'"
		}
	}

	// Write sections
	file write `fh' "### Variable Definitions" _n _n

	if "`id_vars'" != "" {
		WriteMarkdownVariableGroup `fh' "Identifiers" "`id_vars'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" `obs'
	}
	if "`demo_vars'" != "" {
		WriteMarkdownVariableGroup `fh' "Demographics" "`demo_vars'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" `obs'
	}
	if "`cat_vars'" != "" {
		WriteMarkdownVariableGroup `fh' "Categorical Variables" "`cat_vars'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" `obs'
	}
	if "`cont_vars'" != "" {
		WriteMarkdownVariableGroup `fh' "Continuous Variables" "`cont_vars'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" `obs'
	}
	if "`date_vars'" != "" {
		WriteMarkdownVariableGroup `fh' "Date Variables" "`date_vars'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" `obs'
	}
	if "`string_vars'" != "" {
		WriteMarkdownVariableGroup `fh' "String Variables" "`string_vars'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" `obs'
	}
	if "`excl_vars'" != "" {
		WriteMarkdownVariableGroup `fh' "Excluded Variables" "`excl_vars'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" `obs'
	}
end

// =============================================================================
// Helper: WriteMarkdownVariableGroup
// Write detailed documentation for a group of variables
// =============================================================================
program define WriteMarkdownVariableGroup
	args fh section_title varlist maxfreq maxcat exclude datesafe obs

	file write `fh' "####  `section_title'" _n _n

	// Write each variable in the group
	foreach vn of local varlist {
		WriteMarkdownVariableDetail `fh' "`vn'" `maxfreq' `maxcat' ///
			"`exclude'" "`datesafe'" `obs'
	}
end

// =============================================================================
// Helper: WriteMarkdownVariableDetail
// Write detailed documentation for one variable
// =============================================================================
program define WriteMarkdownVariableDetail
	args fh vname maxfreq maxcat exclude datesafe obs

	// Get variable metadata
	local vtype: type `vname'
	local vfmt: format `vname'
	local vlab: variable label `vname'
	local valab: value label `vname'

	// Escape special markdown characters in label
	local vlab_safe = subinstr("`vlab'", "|", "\|", .)

	// Count missing
	quietly count if missing(`vname')
	local nmiss = r(N)
	if `obs' > 0 {
		local pctmiss = string(100*`nmiss'/`obs', "%4.1f")
	}
	else {
		local pctmiss = "0.0"
	}

	// Classify variable
	ClassifyVariable "`vname'" "`vtype'" "`vfmt'" `maxcat' "`exclude'"
	local class = r(class)

	// Write variable header
	file write `fh' "##### `vname'" _n
	if "`vlab'" != "" {
		file write `fh' "**Description:** `vlab_safe'  " _n
	}
	file write `fh' "**Type:** `vtype'  " _n
	file write `fh' "**Format:** `vfmt'  " _n
	if "`valab'" != "" {
		file write `fh' "**Value Label:** \``valab'\`  " _n
	}
	file write `fh' "**Missing:** `nmiss' observations (`pctmiss'%)  " _n _n

	// Type-specific details
	if "`class'" == "categorical" {
		WriteMarkdownCategoricalDetail `fh' "`vname'" `maxfreq' `obs'
	}
	else if "`class'" == "continuous" {
		WriteMarkdownContinuousDetail `fh' "`vname'" `obs'
	}
	else if "`class'" == "date" {
		WriteMarkdownDateDetail `fh' "`vname'" "`vfmt'" "`datesafe'"
	}
	else if "`class'" == "string" {
		WriteMarkdownStringDetail `fh' "`vname'"
	}
	else if "`class'" == "excluded" {
		file write `fh' "**Note:** Variable excluded for privacy protection.  " _n _n
	}

	file write `fh' "---" _n _n
end

// =============================================================================
// Helper: WriteMarkdownCategoricalDetail
// =============================================================================
program define WriteMarkdownCategoricalDetail
	args fh vname maxfreq obs

	quietly tab `vname'
	local nuniq = r(r)

	if `nuniq' <= `maxfreq' {
		file write `fh' "**Frequency Distribution:**" _n _n
		file write `fh' "| Value | Label | Frequency | Percent |" _n
		file write `fh' "|-------|-------|-----------|---------|" _n

		quietly tab `vname', matrow(vals) matcell(freqs)
		local nvals = r(r)

		forvalues i = 1/`nvals' {
			local val = vals[`i',1]
			local freq = freqs[`i',1]
			if `obs' > 0 {
				local pct = string(100*`freq'/`obs', "%4.1f")
			}
			else {
				local pct = "0.0"
			}

			capture local labtext: label (`vname') `val'
			if _rc == 0 {
				local labtext_safe = subinstr("`labtext'", "|", "\|", .)
				file write `fh' "| `val' | `labtext_safe' | `freq' | `pct'% |" _n
			}
			else {
				file write `fh' "| `val' | | `freq' | `pct'% |" _n
			}
		}
		file write `fh' _n
	}
	else {
		file write `fh' "**Note:** Variable has `nuniq' unique values (frequency table suppressed).  " _n _n
	}
end

// =============================================================================
// Helper: WriteMarkdownContinuousDetail
// =============================================================================
program define WriteMarkdownContinuousDetail
	args fh vname obs

	quietly summarize `vname', detail
	local n = r(N)

	if `n' > 0 {
		local mean = string(r(mean), "%9.2f")
		local sd = string(r(sd), "%9.2f")
		local min = string(r(min), "%9.2f")
		local p25 = string(r(p25), "%9.2f")
		local p50 = string(r(p50), "%9.2f")
		local p75 = string(r(p75), "%9.2f")
		local max = string(r(max), "%9.2f")

		file write `fh' "**Summary Statistics:**" _n _n
		file write `fh' "| Statistic | Value |" _n
		file write `fh' "|-----------|-------|" _n
		file write `fh' "| Valid N | `n' |" _n
		file write `fh' "| Mean | `mean' |" _n
		file write `fh' "| SD | `sd' |" _n
		file write `fh' "| Median | `p50' |" _n
		file write `fh' "| IQR | `p25' - `p75' |" _n
		file write `fh' "| Range | `min' - `max' |" _n
		file write `fh' _n
	}
	else {
		file write `fh' "**Summary Statistics:** All values missing.  " _n _n
	}
end

// =============================================================================
// Helper: WriteMarkdownDateDetail
// =============================================================================
program define WriteMarkdownDateDetail
	args fh vname vfmt datesafe

	quietly summarize `vname'
	local n = r(N)

	if `n' > 0 {
		local minval = r(min)
		local maxval = r(max)
		local span = `maxval' - `minval'

		file write `fh' "**Date Range:**" _n _n
		file write `fh' "| Property | Value |" _n
		file write `fh' "|----------|-------|" _n

		if "`datesafe'" == "" {
			local mindate = string(`minval', "`vfmt'")
			local maxdate = string(`maxval', "`vfmt'")
			file write `fh' "| Earliest | `mindate' |" _n
			file write `fh' "| Latest | `maxdate' |" _n
		}
		file write `fh' "| Span | `span' days |" _n
		file write `fh' _n
	}
	else {
		file write `fh' "**Date Range:** All values missing.  " _n _n
	}
end

// =============================================================================
// Helper: WriteMarkdownStringDetail
// =============================================================================
program define WriteMarkdownStringDetail
	args fh vname

	// Get max length
	gen double _len = length(`vname')
	quietly summarize _len
	local maxlen = r(max)
	if missing(`maxlen') local maxlen = 0
	drop _len

	// Count unique
	capture quietly tab `vname'
	if _rc == 0 {
		local nuniq = r(r)
	}
	else {
		local nuniq "(too many to count)"
	}

	file write `fh' "**String Properties:**" _n _n
	file write `fh' "| Property | Value |" _n
	file write `fh' "|----------|-------|" _n
	file write `fh' "| Max Length | `maxlen' characters |" _n
	file write `fh' "| Unique Values | `nuniq' |" _n
	file write `fh' _n

	file write `fh' "**Note:** String values not displayed in documentation.  " _n _n
end

// =============================================================================
// Helper: WriteMarkdownValueLabels
// Document all value labels used in dataset
// =============================================================================
program define WriteMarkdownValueLabels
	args fh

	file write `fh' "### Value Label Definitions" _n _n

	// Get all variables with value labels
	quietly describe, varlist
	local allvars `r(varlist)'

	local all_labels ""
	foreach vn of local allvars {
		local valab: value label `vn'
		if "`valab'" != "" {
			local all_labels "`all_labels' `valab'"
		}
	}

	// Remove duplicates
	local all_labels: list uniq all_labels

	if "`all_labels'" == "" {
		file write `fh' "No value labels defined in this dataset.  " _n _n
		exit
	}

	// Document each label
	foreach vl of local all_labels {
		WriteMarkdownOneValueLabel `fh' "`vl'" "`allvars'"
	}
end

// =============================================================================
// Helper: WriteMarkdownOneValueLabel
// =============================================================================
program define WriteMarkdownOneValueLabel
	args fh labname allvars

	// Find variables using this label
	local uservars ""
	foreach vn of local allvars {
		local valab: value label `vn'
		if "`valab'" == "`labname'" {
			local uservars "`uservars' \``vn'\`"
		}
	}

	file write `fh' "#### \``labname'\`" _n
	file write `fh' "Used by: `uservars'  " _n _n

	// Check if label exists
	capture label list `labname'
	if _rc != 0 {
		file write `fh' "*(Label not defined)*  " _n _n
		exit
	}

	// Get label mappings by extracting from first variable using it
	local first_var: word 1 of `allvars'
	foreach vn of local allvars {
		local valab: value label `vn'
		if "`valab'" == "`labname'" {
			local first_var "`vn'"
			break
		}
	}

	// Write table
	file write `fh' "| Value | Label |" _n
	file write `fh' "|-------|-------|" _n

	quietly levelsof `first_var', local(levels)
	foreach lev of local levels {
		capture local labtext: label `labname' `lev'
		if _rc == 0 {
			local labtext_safe = subinstr("`labtext'", "|", "\|", .)
			file write `fh' "| `lev' | `labtext_safe' |" _n
		}
	}
	file write `fh' _n
end

// =============================================================================
// Helper: WriteMarkdownQualityNotes
// Basic data quality summary
// =============================================================================
program define WriteMarkdownQualityNotes
	args fh obs

	file write `fh' "### Data Quality Notes" _n _n

	// Missing data summary
	file write `fh' "#### Missing Data Summary" _n _n

	quietly describe, varlist
	local allvars `r(varlist)'

	local vars_gt50 ""
	local vars_gt10 ""
	local n_complete = `obs'

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
			local vars_gt50 "`vars_gt50' \``vn'\`"
		}
		if `pct' > 10 {
			local vars_gt10 "`vars_gt10' \``vn'\`"
		}

		// Count complete cases
		quietly count if !missing(`vn')
		if r(N) < `n_complete' {
			local n_complete = r(N)
		}
	}

	if `obs' > 0 {
		local pct_complete = string(100*`n_complete'/`obs', "%4.1f")
	}
	else {
		local pct_complete = "0.0"
	}

	file write `fh' "- Complete cases: `n_complete'/`obs' (`pct_complete'%)  " _n
	if "`vars_gt50'" != "" {
		file write `fh' "- Variables with >50% missing: `vars_gt50'  " _n
	}
	else {
		file write `fh' "- Variables with >50% missing: None  " _n
	}
	if "`vars_gt10'" != "" {
		file write `fh' "- Variables with >10% missing: `vars_gt10'  " _n
	}
	else {
		file write `fh' "- Variables with >10% missing: None  " _n
	}
	file write `fh' _n
end
