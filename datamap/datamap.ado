*! datamap Version 1.5.2  2026/07/09
*! Generate privacy-safe LLM-readable dataset documentation
*! Author: Timothy P Copeland, Karolinska Institutet

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
  format(type)        text (default) or json
  separate            Create separate output file per dataset
  append              Append to existing output file (note: does not add headers)

Content Control:
  nostats             Suppress summary statistics for continuous variables
  nofreq              Suppress frequency tables for categorical variables
  nolabels            Suppress value label definitions
  maxfreq(#)          Max unique values to show frequency table (default: 25)
  maxcat(#)           Max unique values to treat as categorical (default: 25)
  mincell(#)          Suppress frequency cells smaller than # (default: 5; 0 disables)
  noguidance          Suppress ANALYSIS GUIDANCE prose
  compact             Token-compact map (quick reference only; implies noguidance)

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
r(nfiles)               - number of datasets processed
r(nobs)                 - number of observations (single-file/memory mode)
r(nvars)                - number of variables (single-file/memory mode)
r(mincell)              - small-cell threshold used
r(n_categorical)        - number of categorical variables documented
r(n_continuous)         - number of continuous variables documented
r(n_date)               - number of date variables documented
r(n_string)             - number of string variables documented
r(n_excluded)           - number of variables excluded by exclude()
r(n_suggested_exclude)  - number of likely identifiers not excluded
r(format)               - output format used (text or json)
r(output)               - output filename (for combined mode)
r(input_source)         - input mode (memory, single, directory, filelist)
r(categorical_vars)     - categorical variable names
r(continuous_vars)      - continuous variable names
r(date_vars)            - date variable names
r(string_vars)          - string variable names
r(excluded_vars)        - excluded variable names
r(suggested_exclude)    - likely identifiers not listed in exclude()

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
		local _restore_needed = 0
		local _metadata_post_open = 0
		capture noisily {
			local _raw0 `"`0'"'
			syntax [, DIRectory(string) FILElist(string) SINGLE(string) ///
			          RECursive ///
			          Output(string) Format(string) SEParate APPend SAVing(string) ///
			          CONFig(string) ///
			          NOSTats NOFReq NOLAbels ///
			          MAXFreq(integer -1) MAXCat(integer -1) ///
			          MINCell(integer -1) NOGuidance COMpact ///
			          EXClude(string) CONTinuous(string) CATegorical(string) date(string) ///
			          DATESafe DATEFormat(string) ///
			          DETect(string) AUTODETect PANELid(string) ///
			          SURVIVALvars(string) QUality QUality2(string) ///
		          SAMples(integer -1) MISSing(string)]
			// Detect whether the user actually typed each numeric option (at any
			// legal abbreviation), so an explicit negative errors instead of
			// being silently reset to the default.  regexm covers every prefix
			// from the minimum abbreviation through the full name; a bare
			// strpos on one or two forms missed the intermediate abbreviations
			// (e.g. maxfr(), mince()).
			local _raw_lower = lower(`"`macval(_raw0)'"')
			local _user_maxfreq = regexm(`"`_raw_lower'"', "maxf(r(e(q)?)?)?\(")
			local _user_maxcat  = regexm(`"`_raw_lower'"', "maxc(a(t)?)?\(")
			local _user_mincell = regexm(`"`_raw_lower'"', "minc(e(l(l)?)?)?\(")
			local _user_samples = regexm(`"`_raw_lower'"', "sam(p(l(e(s)?)?)?)?\(")

			if `"`config'"' != "" {
				_datamap_validate_path "`config'", option("config()")
				confirm file `"`config'"'
				_datamap_load_config, config(`"`config'"')
				foreach opt in output format exclude continuous categorical detect panelid survivalvars missing dateformat {
					local cfgval `"`r(`opt')'"'
					if `"``opt''"' == "" & `"`cfgval'"' != "" {
						local `opt' `"`cfgval'"'
					}
				}
				if `"`date'"' == "" & `"`r(datevars)'"' != "" local date `"`r(datevars)'"'
				foreach opt in maxfreq maxcat mincell samples {
					if ``opt'' < 0 & `"`r(`opt')'"' != "" local `opt' = real(`"`r(`opt')'"')
				}
				foreach opt in nostats nofreq nolabels datesafe compact noguidance autodetect {
					if "``opt''" == "" & "`r(`opt')'" != "" local `opt' "`opt'"
				}
			}
			if `_user_maxfreq' & `maxfreq' <= 0 {
				noisily di as error "maxfreq must be positive"
				exit 198
			}
			if `_user_maxcat' & `maxcat' <= 0 {
				noisily di as error "maxcat must be positive"
				exit 198
			}
			if `_user_mincell' & `mincell' < 0 {
				noisily di as error "mincell must be non-negative"
				exit 198
			}
			if `_user_samples' & `samples' < 0 {
				noisily di as error "samples must be non-negative"
				exit 198
			}
			if `maxfreq' < 0 local maxfreq = 25
			if `maxcat' < 0 local maxcat = 25
			if `mincell' < 0 local mincell = 5
			if `samples' < 0 local samples = 0

			// Set default date format (ISO 8601: YYYY/MM/DD)
			if `"`dateformat'"' == "" local dateformat "%tdCCYY/NN/DD"
		if strpos(`"`dateformat'"', "%t") != 1 & strpos(`"`dateformat'"', "%d") != 1 {
			noisily di as error "dateformat() must be a Stata date/time display format beginning with %t or %d"
			exit 198
		}

		// Preserve current dataset
		preserve
		local _restore_needed = 1

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
		if !inlist("`format'", "text", "json") {
			noisily di as error "format() must be 'text' or 'json'"
			exit 198
		}
		if "`append'" != "" & "`format'" == "json" {
			noisily di as error "append is not supported with format(json)"
			exit 198
		}

		// Set default output filename
		if "`output'" == "" {
			if "`format'" == "json" local output "datamap.json"
			else local output "datamap.txt"
		}

		local saving_file ""
		local saving_replace 0
		local result_metadata ""
		if `"`saving'"' != "" {
			local saving_spec = subinstr(`"`macval(saving)'"', char(34), "", .)
			local saving_spec = subinstr(`"`macval(saving_spec)'"', ")", "", .)
			local saving_cpos = strpos(`"`macval(saving_spec)'"', ",")
			if `saving_cpos' > 0 {
				local saving_file = strtrim(substr(`"`macval(saving_spec)'"', 1, `saving_cpos' - 1))
				local saving_rest = strtrim(substr(`"`macval(saving_spec)'"', `saving_cpos' + 1, .))
			}
			else {
				local saving_file = strtrim(`"`macval(saving_spec)'"')
				local saving_rest ""
			}
			if `"`saving_file'"' == "" {
				noisily di as error "saving() requires a filename"
				exit 198
			}
			local saving_replace = regexm(lower(`"`macval(saving_rest)'"'), "replace")
			_datamap_validate_path "`saving_file'", option("saving()")
			if !`saving_replace' confirm new file `"`saving_file'"'
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
		if `mincell' < 0 {
			di as error "mincell must be non-negative"
			exit 198
		}
		if `samples' < 0 {
			di as error "samples must be non-negative"
			exit 198
		}
		if "`compact'" != "" local noguidance "noguidance"

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
		_datamap_collect_filelist `"`filelist'"' `"`filelist_tmp'"'
		_datamap_count_files `"`filelist_tmp'"'
		local nfiles = r(nfiles)
	}
	else {
		// Directory scan mode: find all .dta files in directory
		if "`directory'" == "" local directory "."
		_datamap_collect_from_dir `"`directory'"' "`recursive'" `"`filelist_tmp'"'
		_datamap_count_files `"`filelist_tmp'"'
		local nfiles = r(nfiles)
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
					mincell(`mincell') `noguidance' `compact' ///
					exclude(`"`exclude'"') continuous(`"`continuous'"') ///
					categorical(`"`categorical'"') date(`"`date'"') ///
					`datesafe' dateformat(`dateformat') nfiles(`nfiles') ///
					detect_panel(`detect_panel') detect_binary(`detect_binary') ///
					detect_survival(`detect_survival') detect_survey(`detect_survey') ///
				detect_common(`detect_common') panelid(`panelid') ///
			survivalvars(`survivalvars') quality_level(`quality_level') ///
			samples(`samples') missing_detail(`missing_detail') ///
			missing_pattern(`missing_pattern')
	}
	else {
		// Generate single combined output file
		_datamap_ProcessCombined, filelist("`filelist_tmp'") output(`"`output'"') format(`format') ///
					`append' `nostats' `nofreq' ///
					`nolabels' maxfreq(`maxfreq') ///
					maxcat(`maxcat') mincell(`mincell') `noguidance' `compact' ///
					exclude(`"`exclude'"') continuous(`"`continuous'"') ///
					categorical(`"`categorical'"') date(`"`date'"') `datesafe' ///
					dateformat(`dateformat') single(`single') nfiles(`nfiles') ///
					detect_panel(`detect_panel') detect_binary(`detect_binary') ///
				detect_survival(`detect_survival') detect_survey(`detect_survey') ///
			detect_common(`detect_common') panelid(`panelid') ///
			survivalvars(`survivalvars') quality_level(`quality_level') ///
				samples(`samples') missing_detail(`missing_detail') ///
				missing_pattern(`missing_pattern')
		}

		local n_categorical = r(n_categorical)
		local n_continuous = r(n_continuous)
		local n_date = r(n_date)
		local n_string = r(n_string)
		local n_excluded = r(n_excluded)
		local n_suggested_exclude = r(n_suggested_exclude)
		local categorical_vars "`r(categorical_vars)'"
		local continuous_vars "`r(continuous_vars)'"
		local date_vars "`r(date_vars)'"
			local string_vars "`r(string_vars)'"
			local excluded_vars "`r(excluded_vars)'"
			local suggested_exclude "`r(suggested_exclude)'"

			if `"`saving_file'"' != "" {
				tempfile metadata_tmp
				tempname metadata_post
				quietly postfile `metadata_post' ///
					str16 source_command str2045 source str2045 output ///
					str80 dataset str2045 dataset_label str32 variable ///
					str20 storage_type str32 display_format str32 value_label ///
					str20 class double N long nvars long missing ///
					double missing_pct long unique str2045 variable_label ///
					str2045 notes str2045 characteristics double mean double sd ///
					double p50 double p25 double p75 double min double max ///
					str2045 datasignature using `"`metadata_tmp'"', replace
				local _metadata_post_open = 1
				if `"`single'"' != "" {
					local _mfile `"`single'"'
					quietly use `"`_mfile'"', clear
					local _mlabel : data label
					quietly describe, short
					local _mnvars = r(k)
					local _mdsig ""
					quietly capture datasignature
					if _rc == 0 local _mdsig `"`r(datasignature)'"'
					local _mnorm = subinstr(`"`_mfile'"', "\", "/", .)
					local _mdsname `"`_mnorm'"'
					if strpos(`"`_mnorm'"', "/") > 0 {
						local _mdsname = reverse(`"`_mnorm'"')
						local _mslash = strpos(`"`_mdsname'"', "/")
						local _mdsname = reverse(substr(`"`_mdsname'"', 1, `_mslash' - 1))
					}
					if substr(`"`_mdsname'"', -4, 4) == ".dta" {
						local _mdsname = substr(`"`_mdsname'"', 1, length(`"`_mdsname'"') - 4)
					}
					tempfile _mclass
					quietly _datamap_classify using "memory", loaded saving(`"`_mclass'"') ///
						maxcat(`maxcat') obs(`=_N') exclude(`"`exclude'"') ///
						continuous(`"`continuous'"') categorical(`"`categorical'"') ///
						date(`"`date'"') detect_binary(`detect_binary') ///
						quality_level(`"`quality_level'"')
					_datamap_post_metadata_rows, postname(`metadata_post') ///
						classifications(`"`_mclass'"') sourcecommand("datamap") ///
						source(`"`_mfile'"') output(`"`output'"') dsname(`"`_mdsname'"') ///
						dslabel(`"`_mlabel'"') nvars(`_mnvars') ///
						datasignature(`"`_mdsig'"')
				}
				else {
					tempname _mfl
					file open `_mfl' using `"`filelist_tmp'"', read text
					file read `_mfl' _mfile
					while r(eof) == 0 {
						if trim(`"`macval(_mfile)'"') != "" {
							quietly use `"`_mfile'"', clear
							local _mlabel : data label
							quietly describe, short
							local _mnvars = r(k)
							local _mdsig ""
							quietly capture datasignature
							if _rc == 0 local _mdsig `"`r(datasignature)'"'
							local _mnorm = subinstr(`"`_mfile'"', "\", "/", .)
							local _mdsname `"`_mnorm'"'
							if strpos(`"`_mnorm'"', "/") > 0 {
								local _mdsname = reverse(`"`_mnorm'"')
								local _mslash = strpos(`"`_mdsname'"', "/")
								local _mdsname = reverse(substr(`"`_mdsname'"', 1, `_mslash' - 1))
							}
							if substr(`"`_mdsname'"', -4, 4) == ".dta" {
								local _mdsname = substr(`"`_mdsname'"', 1, length(`"`_mdsname'"') - 4)
							}
							tempfile _mclass
							quietly _datamap_classify using "memory", loaded saving(`"`_mclass'"') ///
								maxcat(`maxcat') obs(`=_N') exclude(`"`exclude'"') ///
								continuous(`"`continuous'"') categorical(`"`categorical'"') ///
								date(`"`date'"') detect_binary(`detect_binary') ///
								quality_level(`"`quality_level'"')
							_datamap_post_metadata_rows, postname(`metadata_post') ///
								classifications(`"`_mclass'"') sourcecommand("datamap") ///
								source(`"`_mfile'"') output(`"`output'"') dsname(`"`_mdsname'"') ///
								dslabel(`"`_mlabel'"') nvars(`_mnvars') ///
								datasignature(`"`_mdsig'"')
						}
						file read `_mfl' _mfile
					}
					file close `_mfl'
				}
				postclose `metadata_post'
				local _metadata_post_open = 0
				quietly use `"`metadata_tmp'"', clear
				if `saving_replace' quietly save `"`saving_file'"', replace
				else quietly save `"`saving_file'"'
				local result_metadata `"`saving_file'"'
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
		local _restore_needed = 0

		// Return results
		return scalar nfiles = `nfiles'
	if `nobs_total' < . {
		return scalar nobs = `nobs_total'
		return scalar nvars = `nvars_total'
	}
		return local format "`format'"
		return local output "`output'"
		return local input_source "`input_source'"
		return scalar mincell = `mincell'
		return scalar n_categorical = `n_categorical'
		return scalar n_continuous = `n_continuous'
		return scalar n_date = `n_date'
		return scalar n_string = `n_string'
		return scalar n_excluded = `n_excluded'
		return scalar n_suggested_exclude = `n_suggested_exclude'
		return local categorical_vars "`categorical_vars'"
		return local continuous_vars "`continuous_vars'"
		return local date_vars "`date_vars'"
			return local string_vars "`string_vars'"
			return local excluded_vars "`excluded_vars'"
			return local suggested_exclude "`suggested_exclude'"
			if `"`result_metadata'"' != "" {
				return local metadata `"`result_metadata'"'
			}

		di as text "Documentation generated successfully"
		}
		local rc = _rc
		if `_metadata_post_open' {
			capture postclose `metadata_post'
			local _postclose_rc = _rc
			if !`rc' & `_postclose_rc' local rc = `_postclose_rc'
		}
		if `_restore_needed' {
			capture restore
			local _restore_rc = _rc
			if !`rc' & `_restore_rc' local rc = `_restore_rc'
		}
		set varabbrev `_varabbrev'
		if `rc' exit `rc'
	end

// Parse the package version from the datamap.ado header so JSON output never
// carries a hardcoded literal that drifts from the *! header on a version bump.
capture program drop _datamap_pkgversion
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_pkgversion, rclass
	version 16.0
	local ver "unknown"
	capture findfile datamap.ado
	if _rc == 0 {
		tempname fh
		file open `fh' using `"`r(fn)'"', read text
		file read `fh' line
		while r(eof) == 0 {
			if regexm(`"`macval(line)'"', "^\*! datamap Version ([0-9.]+)") {
				local ver = regexs(1)
				continue, break
			}
			file read `fh' line
		}
		file close `fh'
	}
	return local version "`ver'"
end

// =============================================================================
// Helper: _datamap_ProcessCombined
// Generate single output file containing all datasets
// =============================================================================
capture program drop _datamap_ProcessCombined
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessCombined, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	local _fh_open = 0
	local _fhlist_open = 0
	capture noisily {
		syntax, FILElist(string) Output(string) Format(string) [APPend ///
			NOSTats NOFReq NOLAbels MAXFreq(integer 25) ///
			MAXCat(integer 25) MINCell(integer 5) NOGuidance COMpact ///
			EXClude(string) CONTinuous(string) CATegorical(string) date(string) ///
			DATESafe DATEFormat(string) ///
			single(string) nfiles(integer 1) ///
		detect_panel(integer 0) detect_binary(integer 0) detect_survival(integer 0) ///
		detect_survey(integer 0) detect_common(integer 0) PANELid(string) ///
		SURVIVALvars(string) quality_level(string) SAMples(integer 0) ///
		missing_detail(integer 0) missing_pattern(integer 0)]

	_datamap_pkgversion
	local _pkgver "`r(version)'"

	// Open output file (append or replace mode)
	tempname fh
	if "`append'" != "" {
		quietly file open `fh' using "`output'", write text append
	}
		else {
			quietly file open `fh' using "`output'", write text replace

			local cdate = c(current_date)
			local ctime = c(current_time)
			if "`format'" == "json" {
				file write `fh' "{" _n
				file write `fh' `"  "datamap_version": "`_pkgver'","' _n
				file write `fh' `"  "generated": "`cdate' `ctime'","' _n
				file write `fh' `"  "format": "json","' _n
				file write `fh' `"  "datasets": ["' _n
			}
			else {
				// Write header for text format
				file write `fh' "Dataset Documentation" _n
				file write `fh' "Generated: `cdate' `ctime'" _n _n
			}
		}
		local _fh_open = 1

		// Process each file in list
		local n_categorical = 0
		local n_continuous = 0
		local n_date = 0
		local n_string = 0
		local n_excluded = 0
		local n_suggested_exclude = 0
		local categorical_vars ""
		local continuous_vars ""
		local date_vars ""
		local string_vars ""
		local excluded_vars ""
		local suggested_exclude ""

		if "`single'" != "" {
				// Single file mode
				_datamap_ProcessDataset `fh' "`single'" "`format'" "`nostats'" "`nofreq'" ///
					"`nolabels'" `maxfreq' `maxcat' `mincell' "`noguidance'" "`compact'" ///
					"`exclude'" "`continuous'" "`categorical'" "`date'" "`datesafe'" 1 1 ///
					`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
				"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
				`missing_detail' `missing_pattern' "`dateformat'"
			local n_categorical = `n_categorical' + r(n_categorical)
			local n_continuous = `n_continuous' + r(n_continuous)
			local n_date = `n_date' + r(n_date)
			local n_string = `n_string' + r(n_string)
			local n_excluded = `n_excluded' + r(n_excluded)
			local n_suggested_exclude = `n_suggested_exclude' + r(n_suggested_exclude)
			local categorical_vars "`categorical_vars' `r(categorical_vars)'"
			local continuous_vars "`continuous_vars' `r(continuous_vars)'"
			local date_vars "`date_vars' `r(date_vars)'"
			local string_vars "`string_vars' `r(string_vars)'"
			local excluded_vars "`excluded_vars' `r(excluded_vars)'"
			local suggested_exclude "`suggested_exclude' `r(suggested_exclude)'"
		}
		else {
		// Multiple files from list - read from file
		tempname fh_list
		file open `fh_list' using "`filelist'", read text
		local _fhlist_open = 1
		local i 0
		file read `fh_list' thisfile
		while r(eof) == 0 {
				local ++i
					_datamap_ProcessDataset `fh' "`thisfile'" "`format'" "`nostats'" "`nofreq'" ///
						"`nolabels'" `maxfreq' `maxcat' `mincell' "`noguidance'" "`compact'" ///
						"`exclude'" "`continuous'" "`categorical'" "`date'" "`datesafe'" `i' `nfiles' ///
						`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
					"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
					`missing_detail' `missing_pattern' "`dateformat'"
				local n_categorical = `n_categorical' + r(n_categorical)
				local n_continuous = `n_continuous' + r(n_continuous)
				local n_date = `n_date' + r(n_date)
				local n_string = `n_string' + r(n_string)
				local n_excluded = `n_excluded' + r(n_excluded)
				local n_suggested_exclude = `n_suggested_exclude' + r(n_suggested_exclude)
				local categorical_vars "`categorical_vars' `r(categorical_vars)'"
				local continuous_vars "`continuous_vars' `r(continuous_vars)'"
				local date_vars "`date_vars' `r(date_vars)'"
				local string_vars "`string_vars' `r(string_vars)'"
				local excluded_vars "`excluded_vars' `r(excluded_vars)'"
				local suggested_exclude "`suggested_exclude' `r(suggested_exclude)'"
				file read `fh_list' thisfile
			}
			file close `fh_list'
			local _fhlist_open = 0
		}

		if "`format'" == "json" {
			file write `fh' _n `"  ]"' _n
			file write `fh' "}" _n
		}

		// Always close file handle
		file close `fh'
		local _fh_open = 0
		noisily di as result `"Output written to: `output'"'

		return scalar n_categorical = `n_categorical'
		return scalar n_continuous = `n_continuous'
		return scalar n_date = `n_date'
		return scalar n_string = `n_string'
		return scalar n_excluded = `n_excluded'
		return scalar n_suggested_exclude = `n_suggested_exclude'
		return local categorical_vars "`categorical_vars'"
		return local continuous_vars "`continuous_vars'"
		return local date_vars "`date_vars'"
		return local string_vars "`string_vars'"
		return local excluded_vars "`excluded_vars'"
		return local suggested_exclude "`suggested_exclude'"
	}
	local rc = _rc
	if `_fhlist_open' capture file close `fh_list'
	if `_fh_open' capture file close `fh'
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: _datamap_ProcessSeparate
// Generate separate output file for each dataset
// =============================================================================
capture program drop _datamap_ProcessSeparate
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessSeparate, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	local _fhlist_open = 0
	capture noisily {
		syntax, FILElist(string) Format(string) [NOSTats NOFReq NOLAbels ///
			MAXFreq(integer 25) MAXCat(integer 25) MINCell(integer 5) ///
			NOGuidance COMpact EXClude(string) CONTinuous(string) ///
			CATegorical(string) date(string) DATESafe ///
			DATEFormat(string) nfiles(integer 1) ///
		detect_panel(integer 0) detect_binary(integer 0) detect_survival(integer 0) ///
		detect_survey(integer 0) detect_common(integer 0) PANELid(string) ///
		SURVIVALvars(string) quality_level(string) SAMples(integer 0) ///
		missing_detail(integer 0) missing_pattern(integer 0)]

	_datamap_pkgversion
	local _pkgver "`r(version)'"

	// Loop through each file and generate separate output
	tempname fh_list
	file open `fh_list' using "`filelist'", read text
	local _fhlist_open = 1
	local n_categorical = 0
	local n_continuous = 0
	local n_date = 0
	local n_string = 0
	local n_excluded = 0
	local n_suggested_exclude = 0
	local categorical_vars ""
	local continuous_vars ""
	local date_vars ""
	local string_vars ""
	local excluded_vars ""
	local suggested_exclude ""
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
		if "`format'" == "json" local outfile "`basename'_map.json"
		else local outfile "`basename'_map.txt"

		// Open output file for this dataset
		tempname fh
		quietly file open `fh' using "`outfile'", write text replace

		// Process with error handling
		capture noisily {
			local cdate = c(current_date)
			local ctime = c(current_time)
			if "`format'" == "json" {
				file write `fh' "{" _n
				file write `fh' `"  "datamap_version": "`_pkgver'","' _n
				file write `fh' `"  "generated": "`cdate' `ctime'","' _n
				file write `fh' `"  "format": "json","' _n
				file write `fh' `"  "datasets": ["' _n
			}
			else {
				// Write header for text format
				file write `fh' "Dataset Documentation" _n
				file write `fh' "Generated: `cdate' `ctime'" _n _n
			}

			// Process this dataset
				_datamap_ProcessDataset `fh' "`thisfile'" "`format'" "`nostats'" "`nofreq'" ///
					"`nolabels'" `maxfreq' `maxcat' `mincell' "`noguidance'" "`compact'" ///
					"`exclude'" "`continuous'" "`categorical'" "`date'" "`datesafe'" 1 1 ///
					`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
				"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
				`missing_detail' `missing_pattern' "`dateformat'"
			local n_categorical = `n_categorical' + r(n_categorical)
			local n_continuous = `n_continuous' + r(n_continuous)
			local n_date = `n_date' + r(n_date)
			local n_string = `n_string' + r(n_string)
			local n_excluded = `n_excluded' + r(n_excluded)
			local n_suggested_exclude = `n_suggested_exclude' + r(n_suggested_exclude)
			local categorical_vars "`categorical_vars' `r(categorical_vars)'"
			local continuous_vars "`continuous_vars' `r(continuous_vars)'"
			local date_vars "`date_vars' `r(date_vars)'"
			local string_vars "`string_vars' `r(string_vars)'"
			local excluded_vars "`excluded_vars' `r(excluded_vars)'"
			local suggested_exclude "`suggested_exclude' `r(suggested_exclude)'"
			if "`format'" == "json" {
				file write `fh' _n `"  ]"' _n
				file write `fh' "}" _n
			}
		}
		local rc = _rc

			// Always close file handle
			capture file close `fh'
			local close_rc = _rc

			// Re-throw error if one occurred (outer cleanup closes fh_list)
			if `rc' {
				noisily di as error "Error processing `thisfile' (rc=`rc')"
				exit `rc'
			}
			if `close_rc' {
				noisily di as error "Error closing `outfile' (rc=`close_rc')"
				exit `close_rc'
			}
		noisily di as result `"Output written to: `outfile'"'

		file read `fh_list' thisfile
	}
	file close `fh_list'
	local _fhlist_open = 0

	return scalar n_categorical = `n_categorical'
	return scalar n_continuous = `n_continuous'
	return scalar n_date = `n_date'
	return scalar n_string = `n_string'
	return scalar n_excluded = `n_excluded'
	return scalar n_suggested_exclude = `n_suggested_exclude'
	return local categorical_vars "`categorical_vars'"
	return local continuous_vars "`continuous_vars'"
	return local date_vars "`date_vars'"
	return local string_vars "`string_vars'"
	return local excluded_vars "`excluded_vars'"
	return local suggested_exclude "`suggested_exclude'"
	}
	local rc = _rc
	if `_fhlist_open' capture file close `fh_list'
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: _datamap_ProcessDataset
// Process single dataset and write documentation to file handle
// Args: fh filepath format nostats nofreq nolabels maxfreq maxcat
//       exclude datesafe idx total detect_panel detect_binary detect_survival
//       detect_survey detect_common panelid survivalvars quality_level samples
//       missing_detail missing_pattern
	// =============================================================================
capture program drop _datamap_ProcessDataset
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessDataset, rclass
		version 16.0
			args fh filepath format nostats nofreq nolabels maxfreq maxcat mincell noguidance compact ///
			     exclude continuous categorical force_date datesafe idx total detect_panel detect_binary detect_survival detect_survey detect_common ///
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

	// Write dataset header for text output.
	if "`format'" != "json" {
		if `idx' > 1 file write `fh' _n _n

		// LLM-optimized header with structured sections
		_datamap_write_rule_header `fh' "DATASET: `basename'"

		file write `fh' "METADATA" _n
		file write `fh' "--------" _n
		file write `fh' "Observations: `obs'" _n
		file write `fh' "Variables: `nvars'" _n
		if `"`macval(label)'"' != "" & `"`macval(label)'"' != "." {
			file write `fh' `"Label: `macval(label)'"' _n
		}
		if "`dsig'" != "" {
			file write `fh' "Data Signature: `dsig'" _n
		}

		// Add sort order if set
		if "`sortorder'" != "" {
			file write `fh' "Sort Order: `sortorder'" _n
		}
		file write `fh' _n
	}

	// Shared classification pass for all output formats and stored results.
	tempfile classifications
			_datamap_classify using "`filepath'", saving("`classifications'") loaded ///
				maxcat(`maxcat') obs(`obs') exclude("`exclude'") ///
				continuous("`continuous'") categorical("`categorical'") ///
				date("`force_date'") ///
			detect_binary(`detect_binary') quality_level("`quality_level'")
	local n_categorical = r(n_categorical)
	local n_continuous = r(n_continuous)
	local n_date = r(n_date)
	local n_string = r(n_string)
	local n_excluded = r(n_excluded)
	local n_suggested_exclude = r(n_suggested_exclude)
	local categorical_vars "`r(categorical_vars)'"
	local continuous_vars "`r(continuous_vars)'"
	local date_vars "`r(date_vars)'"
	local string_vars "`r(string_vars)'"
	local excluded_vars "`r(excluded_vars)'"
	local suggested_exclude "`r(suggested_exclude)'"

	if `n_suggested_exclude' > 0 {
		noisily display as text "warning: likely identifier variable(s) not in exclude():`suggested_exclude'"
	}

	if "`format'" == "json" {
		_datamap_ProcessDatasetJson `fh' "`filepath'" "`classifications'" ///
			"`basename'" `obs' `nvars' `"`macval(label)'"' "`dsig'" "`sortorder'" ///
			`idx' `total' "`nostats'" "`nofreq'" "`nolabels'" `maxfreq' ///
			`mincell' "`datesafe'" "`dateformat'" ///
			`detect_panel' `detect_binary' `detect_survival' `detect_survey' ///
			`detect_common' "`panelid'" "`survivalvars'" "`quality_level'" ///
			`samples' `missing_detail' `missing_pattern'
		return scalar n_categorical = `n_categorical'
		return scalar n_continuous = `n_continuous'
		return scalar n_date = `n_date'
		return scalar n_string = `n_string'
		return scalar n_excluded = `n_excluded'
		return scalar n_suggested_exclude = `n_suggested_exclude'
		return local categorical_vars "`categorical_vars'"
		return local continuous_vars "`continuous_vars'"
		return local date_vars "`date_vars'"
		return local string_vars "`string_vars'"
		return local excluded_vars "`excluded_vars'"
		return local suggested_exclude "`suggested_exclude'"
		exit
	}

	// One-glance privacy posture for text output.
	file write `fh' "DISCLOSURE RISK SUMMARY" _n
	file write `fh' "-----------------------" _n
	file write `fh' "Excluded variables: `n_excluded'" _n
	file write `fh' "Small-cell threshold: `mincell'"
	if `mincell' == 0 file write `fh' " (disabled)"
	file write `fh' _n
	if "`datesafe'" != "" file write `fh' "Date-safe mode: on" _n
	else file write `fh' "Date-safe mode: off" _n
	if `n_suggested_exclude' > 0 {
		file write `fh' "Likely identifiers not excluded:`suggested_exclude'" _n
	}
	else {
		file write `fh' "Likely identifiers not excluded: 0" _n
	}
	file write `fh' _n

	// Generate natural language summary
	_datamap_GenerateDatasetSummary `fh' "`filepath'" `obs' `nvars' `"`macval(label)'"' ///
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
	_datamap_ProcessVariables `fh' "`filepath'" "`classifications'" "`format'" "`nostats'" "`nofreq'" ///
		"`nolabels'" `maxfreq' `maxcat' `mincell' "`noguidance'" "`compact'" ///
		"`exclude'" "`datesafe'" `obs' ///
		`detect_panel' `detect_binary' `detect_survival' `detect_survey' `detect_common' ///
		"`panelid'" "`survivalvars'" "`quality_level'" `samples' ///
		`missing_detail' `missing_pattern' "`dateformat'"

	return scalar n_categorical = `n_categorical'
	return scalar n_continuous = `n_continuous'
	return scalar n_date = `n_date'
	return scalar n_string = `n_string'
	return scalar n_excluded = `n_excluded'
	return scalar n_suggested_exclude = `n_suggested_exclude'
	return local categorical_vars "`categorical_vars'"
	return local continuous_vars "`continuous_vars'"
	return local date_vars "`date_vars'"
	return local string_vars "`string_vars'"
	return local excluded_vars "`excluded_vars'"
	return local suggested_exclude "`suggested_exclude'"
end

// =============================================================================
// Helper: _datamap_ProcessVariables
// Classify and document all variables in a dataset
// =============================================================================
capture program drop _datamap_ProcessVariables
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessVariables, nclass
	version 16.0
	args fh filepath classifications format nostats nofreq nolabels maxfreq maxcat mincell noguidance compact ///
	     exclude datesafe obs ///
	     detect_panel detect_binary detect_survival detect_survey detect_common ///
	     panelid survivalvars quality_level samples missing_detail missing_pattern dateformat

	// Write variable summary table header with structured sections
	_datamap_write_rule_header `fh' "VARIABLE SUMMARY"

	preserve
	quietly use "`classifications'", clear
	local nvars = _N

	// Write compact quick reference table
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
		if `"`macval(vlab)'"' != "" {
			file write `fh' `"    Label: `macval(vlab)'"' _n
		}
		file write `fh' "    Missing: `nmiss' (`pctmiss'%)" _n
			file write `fh' "    Classification: `vclass'" _n _n
		}
	restore

	if "`compact'" != "" {
		exit
	}

	// Detailed variable sections
	_datamap_ProcessCategorical `fh' "`classifications'" "`format'" "`nofreq'" `maxfreq' `obs' `mincell' "`noguidance'"
	_datamap_ProcessContinuous `fh' "`classifications'" "`format'" "`nostats'" `obs' "`noguidance'"
	_datamap_ProcessDate `fh' "`classifications'" "`format'" "`datesafe'" "`dateformat'" "`noguidance'"
	_datamap_ProcessString `fh' "`classifications'" "`format'" "`noguidance'"
	_datamap_ProcessExcluded `fh' "`classifications'" "`format'" "`noguidance'"

	// Binary variables section (if detect_binary enabled)
	if `detect_binary' {
		_datamap_ProcessBinary `fh' "`classifications'" "`format'" `obs' `mincell'
	}

	// Data quality flags (if quality checks enabled)
	if "`quality_level'" != "" {
		_datamap_ProcessQuality `fh' "`classifications'" "`format'"
	}

	// Sample observations (if requested)
	if `samples' > 0 {
		_datamap_ProcessSamples `fh' "`classifications'" "`format'" `samples' "`exclude'" "`datesafe'" "`dateformat'"
	}

	// Value label definitions
	if "`nolabels'" == "" {
		_datamap_ProcessValueLabels `fh' "`classifications'" "`format'"
	}
end

capture program drop _datamap_write_rule_header
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_write_rule_header, nclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		args fh title

		file write `fh' "========================================" _n
		file write `fh' "`title'" _n
		file write `fh' "========================================" _n _n
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

capture program drop _datamap_DateFamily
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_DateFamily, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax, VFMT(string)

		local is_date = (strpos("`vfmt'", "%t") > 0 | strpos("`vfmt'", "%d") > 0)
		local family ""
		if `is_date' {
			if strpos("`vfmt'", "%td") > 0 | strpos("`vfmt'", "%d") > 0 {
				local family "td"
			}
			else if strpos("`vfmt'", "%tc") > 0 | strpos("`vfmt'", "%tC") > 0 {
				local family "tc"
			}
			else if strpos("`vfmt'", "%tw") > 0 {
				local family "tw"
			}
			else if strpos("`vfmt'", "%tm") > 0 {
				local family "tm"
			}
			else if strpos("`vfmt'", "%tq") > 0 {
				local family "tq"
			}
			else if strpos("`vfmt'", "%th") > 0 {
				local family "th"
			}
			else if strpos("`vfmt'", "%ty") > 0 {
				local family "ty"
			}
			else {
				local family "other"
			}
		}

		return scalar is_date = `is_date'
		return local family "`family'"
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

capture program drop _datamap_DateDisplayFormat
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_DateDisplayFormat, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax, VFMT(string) DATEFormat(string)

		local dispfmt "`vfmt'"
		if strpos("`vfmt'", "%td") > 0 | strpos("`vfmt'", "%d") > 0 {
			local dispfmt "`dateformat'"
		}
		else if strpos("`vfmt'", "%tc") > 0 | strpos("`vfmt'", "%tC") > 0 {
			local dispfmt = subinstr("`dateformat'", "%td", "%tc", 1)
		}

		return local display_format `"`dispfmt'"'
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

capture program drop _datamap_DateSpanUnit
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_DateSpanUnit, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax, VFMT(string)

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

		return local span_unit "`span_unit'"
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

capture program drop _datamap_json_escape
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_json_escape, rclass
	version 16.0
	args text

	local escaped `"`macval(text)'"'
	local escaped = subinstr(`"`macval(escaped)'"', char(92), char(92) + char(92), .)
	local escaped = subinstr(`"`macval(escaped)'"', char(34), char(92) + char(34), .)
	local escaped = subinstr(`"`macval(escaped)'"', char(10), char(92) + "n", .)
	local escaped = subinstr(`"`macval(escaped)'"', char(13), char(92) + "r", .)
	return local escaped `"`macval(escaped)'"'
end

capture program drop _datamap_json_number
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_json_number, rclass
	version 16.0
	args num

	if missing(`num') {
		return local number "null"
		exit
	}

	local number = strtrim(string(`num', "%21.12g"))
	if substr("`number'", 1, 1) == "." {
		local number "0`number'"
	}
	else if substr("`number'", 1, 2) == "-." {
		local number = "-0" + substr("`number'", 2, .)
	}
	return local number "`number'"
end

// JSON string escaper that runs entirely in Mata.  A macro-based escape
// (subinstr on the command line, or an -args- helper) re-expands any $macro
// or backtick the string contains, silently corrupting labels; Mata's
// st_local/subinstr copy bytes verbatim with no macro expansion.  Reads the
// caller's local `src', escapes it, and writes the caller's local `dst'.
capture mata: mata drop _datamap_jsonesc()
mata:
void _datamap_jsonesc(string scalar src, string scalar dst)
{
	string scalar s
	s = st_local(src)
	s = subinstr(s, char(92), char(92) + char(92))
	s = subinstr(s, char(34), char(92) + char(34))
	s = subinstr(s, char(10), char(92) + "n")
	s = subinstr(s, char(13), char(92) + "r")
	st_local(dst, s)
}
end

capture program drop _datamap_ProcessDatasetJson
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessDatasetJson, nclass
	version 16.0
	args fh filepath classifications basename obs nvars label dsig sortorder idx total ///
	     nostats nofreq nolabels maxfreq mincell datesafe dateformat ///
	     detect_panel detect_binary detect_survival detect_survey detect_common ///
	     panelid survivalvars quality_level samples missing_detail missing_pattern

	// The data label arrives through the -args- pipeline, which re-expands
	// $macro/backtick on the command line.  Re-read it from the source
	// dataset (still in memory; -preserve- below has not run yet) so the
	// JSON label matches the true data label.
	local label : data label

	if `idx' > 1 file write `fh' "," _n

	mata: _datamap_jsonesc("basename", "basename_json")
	mata: _datamap_jsonesc("label", "label_json")
	_datamap_json_escape `"`dsig'"'
	local dsig_json `"`r(escaped)'"'
	_datamap_json_escape `"`sortorder'"'
	local sortorder_json `"`r(escaped)'"'

	preserve
	quietly use "`classifications'", clear
	local nvars_class = _N
	local n_categorical = 0
	local n_continuous = 0
	local n_date = 0
	local n_string = 0
	local n_excluded = 0
	local n_suggested_exclude = 0
	local suggested_exclude ""
	forvalues i = 1/`nvars_class' {
		local vname_`i' = varname[`i']
		local vtype_`i' = vartype[`i']
		local vfmt_`i' = varformat[`i']
		local vlab_`i' = varlabel[`i']
		local valab_`i' = valuelabel[`i']
		local class_`i' = classification[`i']
		local nmiss_`i' = cond(missing(missing_n[`i']), 0, missing_n[`i'])
		local pctmiss_`i' = cond(missing(missing_pct[`i']), 0, missing_pct[`i'])
		local nuniq_`i' = cond(missing(unique_vals[`i']), ., unique_vals[`i'])
		local maxlen_`i' = cond(missing(max_length[`i']), ., max_length[`i'])

		if "`class_`i''" == "categorical" local ++n_categorical
		else if "`class_`i''" == "continuous" local ++n_continuous
		else if "`class_`i''" == "date" local ++n_date
		else if "`class_`i''" == "string" local ++n_string
		else if "`class_`i''" == "excluded" local ++n_excluded

		if regexm(lower("`vname_`i''"), "id$|_id$|^id_|patient|subject|person|lopnr|identifier") & "`class_`i''" != "excluded" {
			local ++n_suggested_exclude
			local suggested_exclude "`suggested_exclude' `vname_`i''"
		}
	}
	local suggested_exclude = strtrim("`suggested_exclude'")
	restore

	_datamap_json_escape `"`suggested_exclude'"'
	local suggested_json `"`r(escaped)'"'

	file write `fh' "    {" _n
	file write `fh' `"      "name": "`macval(basename_json)'","' _n
	file write `fh' `"      "observations": `obs',"' _n
	file write `fh' `"      "variables": `nvars',"' _n
	file write `fh' `"      "label": "`macval(label_json)'","' _n
	file write `fh' `"      "data_signature": "`dsig_json'","' _n
	file write `fh' `"      "sort_order": "`sortorder_json'","' _n
	file write `fh' `"      "privacy": {"' _n
	file write `fh' `"        "mincell": `mincell',"' _n
	file write `fh' `"        "datesafe": "'
	if "`datesafe'" != "" file write `fh' "true," _n
	else file write `fh' "false," _n
	file write `fh' `"        "excluded_variables": `n_excluded',"' _n
	file write `fh' `"        "likely_identifiers_not_excluded": `n_suggested_exclude',"' _n
	file write `fh' `"        "suggested_exclude": "`suggested_json'""' _n
	file write `fh' "      }," _n
	file write `fh' `"      "class_counts": {"' _n
	file write `fh' `"        "categorical": `n_categorical',"' _n
	file write `fh' `"        "continuous": `n_continuous',"' _n
	file write `fh' `"        "date": `n_date',"' _n
	file write `fh' `"        "string": `n_string',"' _n
	file write `fh' `"        "excluded": `n_excluded'"' _n
	file write `fh' "      }," _n
	file write `fh' `"      "variable_metadata": ["' _n

	forvalues i = 1/`nvars_class' {
		if `i' > 1 file write `fh' "," _n

		local vname "`vname_`i''"
		local vtype "`vtype_`i''"
		local vfmt "`vfmt_`i''"
		local vlab `"`macval(vlab_`i')'"'
		local valab "`valab_`i''"
		local vclass "`class_`i''"
		local nmiss = `nmiss_`i''
		local pctmiss = `pctmiss_`i''
		local nuniq = `nuniq_`i''
		local maxlen = `maxlen_`i''
		_datamap_json_number `pctmiss'
		local pctmiss_json "`r(number)'"

		_datamap_json_escape `"`vname'"'
		local vname_json `"`r(escaped)'"'
		_datamap_json_escape `"`vtype'"'
		local vtype_json `"`r(escaped)'"'
		_datamap_json_escape `"`vfmt'"'
		local vfmt_json `"`r(escaped)'"'
		mata: _datamap_jsonesc("vlab", "vlab_json")
		_datamap_json_escape `"`valab'"'
		local valab_json `"`r(escaped)'"'
		_datamap_json_escape `"`vclass'"'
		local vclass_json `"`r(escaped)'"'

		file write `fh' "        {" _n
		file write `fh' `"          "name": "`vname_json'","' _n
		file write `fh' `"          "type": "`vtype_json'","' _n
		file write `fh' `"          "format": "`vfmt_json'","' _n
		file write `fh' `"          "label": "`macval(vlab_json)'","' _n
		file write `fh' `"          "value_label": "`valab_json'","' _n
		file write `fh' `"          "classification": "`vclass_json'","' _n
		file write `fh' `"          "missing_n": `nmiss',"' _n
		file write `fh' `"          "missing_pct": `pctmiss_json',"' _n
		file write `fh' `"          "unique_values": "'
		if `nuniq' < . file write `fh' "`nuniq'," _n
		else file write `fh' "null," _n
		file write `fh' `"          "max_length": "'
		if `maxlen' < . file write `fh' "`maxlen'," _n
		else file write `fh' "null," _n

		file write `fh' `"          "summary": {"' _n
		if "`vclass'" == "continuous" & "`nostats'" == "" {
			quietly summarize `vname', detail
			if r(N) > 0 {
				local s_n = r(N)
				local s_mean = r(mean)
				local s_sd = r(sd)
				local s_p25 = r(p25)
				local s_p50 = r(p50)
				local s_p75 = r(p75)
				local s_min = r(min)
				local s_max = r(max)
				_datamap_json_number `s_n'
				local j_n "`r(number)'"
				_datamap_json_number `s_mean'
				local j_mean "`r(number)'"
				_datamap_json_number `s_sd'
				local j_sd "`r(number)'"
				_datamap_json_number `s_p25'
				local j_p25 "`r(number)'"
				_datamap_json_number `s_p50'
				local j_p50 "`r(number)'"
				_datamap_json_number `s_p75'
				local j_p75 "`r(number)'"
				_datamap_json_number `s_min'
				local j_min "`r(number)'"
				_datamap_json_number `s_max'
				local j_max "`r(number)'"
				file write `fh' `"            "n": `j_n',"' _n
				file write `fh' `"            "mean": `j_mean',"' _n
				file write `fh' `"            "sd": `j_sd',"' _n
				file write `fh' `"            "p25": `j_p25',"' _n
				file write `fh' `"            "median": `j_p50',"' _n
				file write `fh' `"            "p75": `j_p75',"' _n
				file write `fh' `"            "min": `j_min',"' _n
				file write `fh' `"            "max": `j_max'"' _n
			}
		}
		else if "`vclass'" == "date" {
			quietly summarize `vname'
			if r(N) > 0 {
				local date_n = r(N)
				local raw_min = r(min)
				local raw_max = r(max)
				_datamap_DateSpanUnit, vfmt("`vfmt'")
				local span_unit "`r(span_unit)'"
				local span = `raw_max' - `raw_min'
				_datamap_json_number `date_n'
				local date_n_json "`r(number)'"
				_datamap_json_number `span'
				local span_json "`r(number)'"
				_datamap_json_escape "`span_unit'"
				local span_unit_json "`r(escaped)'"
				file write `fh' `"            "n": `date_n_json',"' _n
				file write `fh' `"            "span": `span_json',"' _n
				file write `fh' `"            "span_unit": "`span_unit_json'""'
				if "`datesafe'" == "" {
					_datamap_DateDisplayFormat, vfmt("`vfmt'") dateformat("`dateformat'")
					local dispfmt "`r(display_format)'"
					local mindate = string(`raw_min', "`dispfmt'")
					local maxdate = string(`raw_max', "`dispfmt'")
					_datamap_json_escape "`mindate'"
					local mindate_json "`r(escaped)'"
					_datamap_json_escape "`maxdate'"
					local maxdate_json "`r(escaped)'"
					file write `fh' "," _n
					file write `fh' `"            "min": "`mindate_json'","' _n
					file write `fh' `"            "max": "`maxdate_json'""' _n
				}
				else {
					file write `fh' _n
				}
			}
		}
		file write `fh' "          }," _n

		file write `fh' `"          "frequencies": ["' _n
		local wrote_freq = 0
		if "`vclass'" == "categorical" & "`nofreq'" == "" & `nuniq' < . & `nuniq' <= `maxfreq' {
			capture quietly tab `vname', matrow(vals) matcell(freqs)
			if _rc == 0 {
				local nvals = r(r)
				forvalues j = 1/`nvals' {
					local val = vals[`j',1]
					local freq = freqs[`j',1]
					if `j' > 1 file write `fh' "," _n
					capture local vallabtext : label (`vname') `val'
					if _rc != 0 local vallabtext ""
					_datamap_json_escape "`val'"
					local val_json "`r(escaped)'"
					mata: _datamap_jsonesc("vallabtext", "vallab_json")
					file write `fh' "            {" _n
					file write `fh' `"              "value": "`val_json'","' _n
					file write `fh' `"              "label": "`macval(vallab_json)'","' _n
					if `mincell' > 0 & `freq' < `mincell' {
						file write `fh' `"              "count": null,"' _n
						file write `fh' `"              "pct": null,"' _n
						file write `fh' `"              "suppressed": true,"' _n
						file write `fh' `"              "threshold": `mincell'"' _n
					}
					else {
						local pct = 0
						if `obs' > 0 local pct = round(100 * `freq' / `obs', 0.1)
						_datamap_json_number `pct'
						local pct_json "`r(number)'"
						file write `fh' `"              "count": `freq',"' _n
						file write `fh' `"              "pct": `pct_json',"' _n
						file write `fh' `"              "suppressed": false,"' _n
						file write `fh' `"              "threshold": `mincell'"' _n
					}
					file write `fh' "            }"
					local wrote_freq = 1
				}
				if `wrote_freq' file write `fh' _n
			}
		}
		file write `fh' "          ]" _n
		file write `fh' "        }"
	}

	file write `fh' _n `"      ]"' _n
	file write `fh' "    }"
end

capture program drop _datamap_ProcessCategorical
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessCategorical, nclass
	version 16.0
	args fh classifications format nofreq maxfreq obs mincell noguidance

	preserve
	quietly use "`classifications'", clear
	quietly keep if classification == "categorical"
	local nvars = _N
	if _N == 0 {
		restore
		exit
	}
	forvalues i = 1/`nvars' {
		local vname_`i' = varname[`i']
		local vtype_`i' = vartype[`i']
		local vfmt_`i' = varformat[`i']
		local vlab_`i' = varlabel[`i']
		local valab_`i' = valuelabel[`i']
		local origpos_`i' = orig_position[`i']
		local nmiss_`i' = cond(missing(missing_n[`i']), 0, missing_n[`i'])
		local pctmiss_`i' = cond(missing(missing_pct[`i']), 0, missing_pct[`i'])
		local nuniq_`i' = cond(missing(unique_vals[`i']), 0, unique_vals[`i'])
	}
	restore

	_datamap_write_rule_header `fh' "CATEGORICAL VARIABLES"

	forvalues i = 1/`nvars' {
		local vname "`vname_`i''"
		local vtype "`vtype_`i''"
		local vfmt "`vfmt_`i''"
		local vlab `"`macval(vlab_`i')'"'
		local valab "`valab_`i''"
		local origpos = `origpos_`i''
		local nmiss = `nmiss_`i''
		local pctmiss : di %5.1f `pctmiss_`i''
		local pctmiss = strtrim("`pctmiss'")
		local nuniq = `nuniq_`i''

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`macval(vlab)'"' != "" {
			file write `fh' `"Label: `macval(vlab)'"' _n
		}
		if "`valab'" != "" file write `fh' "Value Label: `valab'" _n
		file write `fh' "Classification: categorical" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "Unique Values: `nuniq'" _n _n

		// Frequency table
		if "`nofreq'" == "" & `nuniq' <= `maxfreq' {
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
					local vltext : label (`vname') `val'
					if `mincell' > 0 & `freq' < `mincell' {
						file write `fh' `"    `val' = `macval(vltext)': suppressed (<`mincell')"' _n
					}
					else {
						file write `fh' `"    `val' = `macval(vltext)': `freq' (`pct'%)"' _n
					}
				}
			}
			else {
				file write `fh' "    (frequency table unavailable)" _n
			}
			file write `fh' _n
		}

		// Add analysis guidance
		if "`noguidance'" == "" {
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
			if `pctmiss_`i'' >= 20 {
				file write `fh' "`pctmiss'% missing - verify missingness mechanism before analysis. "
			}
			file write `fh' _n _n
		}
	}
end

capture program drop _datamap_ProcessContinuous
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessContinuous, nclass
	version 16.0
	args fh classifications format nostats obs noguidance

	preserve
	quietly use "`classifications'", clear
	quietly keep if classification == "continuous"
	local nvars = _N
	if `nvars' == 0 {
		restore
		exit
	}
	forvalues i = 1/`nvars' {
		local vname_`i' = varname[`i']
		local vtype_`i' = vartype[`i']
		local vfmt_`i' = varformat[`i']
		local vlab_`i' = varlabel[`i']
		local origpos_`i' = orig_position[`i']
		local nmiss_`i' = cond(missing(missing_n[`i']), 0, missing_n[`i'])
		local pctmiss_`i' = cond(missing(missing_pct[`i']), 0, missing_pct[`i'])
		local nuniq_`i' = cond(missing(unique_vals[`i']), 0, unique_vals[`i'])
	}
	restore

	_datamap_write_rule_header `fh' "CONTINUOUS VARIABLES"

	forvalues i = 1/`nvars' {
		local vname "`vname_`i''"
		local vtype "`vtype_`i''"
		local vfmt "`vfmt_`i''"
		local vlab `"`macval(vlab_`i')'"'
		local origpos = `origpos_`i''
		local nmiss = `nmiss_`i''
		local pctmiss : di %5.1f `pctmiss_`i''
		local pctmiss = strtrim("`pctmiss'")
		local nuniq = `nuniq_`i''

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`macval(vlab)'"' != "" {
			file write `fh' `"Label: `macval(vlab)'"' _n
		}
		file write `fh' "Classification: continuous" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "Unique Values: `nuniq'" _n _n

		// Summary statistics
		if "`nostats'" == "" {
			quietly summarize `vname', detail
			local n = r(N)
			local skewness = r(skewness)

			// Check if all values are missing
			if `n' > 0 {
				local mean = strtrim(string(round(r(mean), 0.01), "%14.0g"))
				local sd = strtrim(string(round(r(sd), 0.01), "%14.0g"))
				local min = strtrim(string(round(r(min), 0.01), "%14.0g"))
				local p25 = strtrim(string(round(r(p25), 0.01), "%14.0g"))
				local p50 = strtrim(string(round(r(p50), 0.01), "%14.0g"))
				local p75 = strtrim(string(round(r(p75), 0.01), "%14.0g"))
				local max = strtrim(string(round(r(max), 0.01), "%14.0g"))

				file write `fh' "DISTRIBUTION:" _n
				file write `fh' "  Valid N: `n'" _n
				file write `fh' "  Mean: `mean'" _n
				file write `fh' "  SD: `sd'" _n
				file write `fh' "  Median: `p50'" _n
				file write `fh' "  IQR: `p25'-`p75'" _n
				file write `fh' "  Range: `min' to `max'" _n _n

				if "`noguidance'" == "" {
					// Add contextual analysis guidance
					file write `fh' "ANALYSIS GUIDANCE: "
					file write `fh' "Use as continuous variable. "

					// Contextual skewness guidance with direction and magnitude
					if !missing(`skewness') & abs(`skewness') > 2 {
						local sk_rounded = strtrim(string(round(`skewness', 0.1), "%14.0g"))
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
					if `pctmiss_`i'' >= 20 {
						file write `fh' "`pctmiss'% missing - verify missingness mechanism before analysis. "
					}
					file write `fh' _n _n
				}
			}
			else {
				// All values missing
				file write `fh' "DISTRIBUTION: (all values missing)" _n _n
			}
		}
	}
end

capture program drop _datamap_ProcessDate
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessDate, nclass
	version 16.0
	args fh classifications format datesafe dateformat noguidance

	preserve
	quietly use "`classifications'", clear
	quietly keep if classification == "date"
	local nvars = _N
	if `nvars' == 0 {
		restore
		exit
	}
	forvalues i = 1/`nvars' {
		local vname_`i' = varname[`i']
		local vtype_`i' = vartype[`i']
		local vfmt_`i' = varformat[`i']
		local vlab_`i' = varlabel[`i']
		local origpos_`i' = orig_position[`i']
		local nmiss_`i' = cond(missing(missing_n[`i']), 0, missing_n[`i'])
		local pctmiss_`i' = cond(missing(missing_pct[`i']), 0, missing_pct[`i'])
	}
	restore

	_datamap_write_rule_header `fh' "DATE VARIABLES"

	forvalues i = 1/`nvars' {
		local vname "`vname_`i''"
		local vtype "`vtype_`i''"
		local vfmt "`vfmt_`i''"
		local vlab `"`macval(vlab_`i')'"'
		local origpos = `origpos_`i''
		local nmiss = `nmiss_`i''
		local pctmiss : di %5.1f `pctmiss_`i''
		local pctmiss = strtrim("`pctmiss'")

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`macval(vlab)'"' != "" {
			file write `fh' `"Label: `macval(vlab)'"' _n
		}
		file write `fh' "Classification: date" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n _n

		// Date range
		quietly summarize `vname'
		local minval = r(min)
		local maxval = r(max)

		_datamap_DateSpanUnit, vfmt("`vfmt'")
		local span_unit "`r(span_unit)'"
		_datamap_DateDisplayFormat, vfmt("`vfmt'") dateformat("`dateformat'")
		local dispfmt "`r(display_format)'"

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
		if "`noguidance'" == "" {
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
		}
	}
end

capture program drop _datamap_ProcessString
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessString, nclass
	version 16.0
	args fh classifications format noguidance

	preserve
	quietly use "`classifications'", clear
	quietly keep if classification == "string"
	local nvars = _N
	if `nvars' == 0 {
		restore
		exit
	}
	forvalues i = 1/`nvars' {
		local vname_`i' = varname[`i']
		local vtype_`i' = vartype[`i']
		local vlab_`i' = varlabel[`i']
		local origpos_`i' = orig_position[`i']
		local nmiss_`i' = cond(missing(missing_n[`i']), 0, missing_n[`i'])
		local pctmiss_`i' = cond(missing(missing_pct[`i']), 0, missing_pct[`i'])
		local maxlen_`i' = cond(missing(max_length[`i']), 0, max_length[`i'])
		local nuniq_`i' = cond(missing(unique_vals[`i']), ., unique_vals[`i'])
	}
	restore

	_datamap_write_rule_header `fh' "STRING VARIABLES"

	forvalues i = 1/`nvars' {
		local vname "`vname_`i''"
		local vtype "`vtype_`i''"
		local vlab `"`macval(vlab_`i')'"'
		local origpos = `origpos_`i''
		local nmiss = `nmiss_`i''
		local pctmiss : di %5.1f `pctmiss_`i''
		local pctmiss = strtrim("`pctmiss'")
		local maxlen = `maxlen_`i''
		local is_strL = ("`vtype'" == "strL")
		if `nuniq_`i'' < . {
			local nuniq = string(`nuniq_`i'', "%12.0f")
			local nuniq = strtrim("`nuniq'")
		}
		else if `is_strL' {
			local nuniq "(strL)"
		}
		else {
			local nuniq "(too many)"
		}

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		if `is_strL' {
			file write `fh' "Note: strL (long string) — can store up to 2 billion characters" _n
		}
		if `"`macval(vlab)'"' != "" {
			file write `fh' `"Label: `macval(vlab)'"' _n
		}
		file write `fh' "Classification: string" _n
		file write `fh' "Max Length: `maxlen' characters" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "Unique Values: `nuniq'" _n
		file write `fh' "(exact values suppressed)" _n _n

		// Add analysis guidance
		if "`noguidance'" == "" {
			file write `fh' "ANALYSIS GUIDANCE: "
			if `is_strL' {
				file write `fh' "Long string (strL) variable - may contain free text, notes, or large content. "
				file write `fh' "Consider whether content can be parsed or categorized for analysis."
			}
			else {
				file write `fh' "String variable - may contain free text, codes, or identifiers. "
				if "`nuniq'" != "(too many)" & "`nuniq'" != "(strL)" {
					if `nuniq_`i'' <= 25 {
						file write `fh' "Low cardinality suggests categorical data - consider encoding as numeric. "
					}
				}
				file write `fh' "Verify encoding if contains non-ASCII characters."
			}
			file write `fh' _n _n
		}
	}
end

capture program drop _datamap_ProcessExcluded
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessExcluded, nclass
	version 16.0
	args fh classifications format noguidance

	preserve
	quietly use "`classifications'", clear
	quietly keep if classification == "excluded"
	local nvars = _N
	if `nvars' == 0 {
		restore
		exit
	}
	forvalues i = 1/`nvars' {
		local vname_`i' = varname[`i']
		local vtype_`i' = vartype[`i']
		local vfmt_`i' = varformat[`i']
		local vlab_`i' = varlabel[`i']
		local origpos_`i' = orig_position[`i']
		local nmiss_`i' = cond(missing(missing_n[`i']), 0, missing_n[`i'])
		local pctmiss_`i' = cond(missing(missing_pct[`i']), 0, missing_pct[`i'])
	}
	restore

	_datamap_write_rule_header `fh' "EXCLUDED VARIABLES"

	forvalues i = 1/`nvars' {
		local vname "`vname_`i''"
		local vtype "`vtype_`i''"
		local vfmt "`vfmt_`i''"
		local vlab `"`macval(vlab_`i')'"'
		local origpos = `origpos_`i''
		local nmiss = `nmiss_`i''
		local pctmiss : di %5.1f `pctmiss_`i''
		local pctmiss = strtrim("`pctmiss'")

		file write `fh' "VARIABLE: `vname'" _n
		file write `fh' "--------------------" _n
		file write `fh' "Position: `origpos'" _n
		file write `fh' "Storage Type: `vtype'" _n
		file write `fh' "Display Format: `vfmt'" _n
		if `"`macval(vlab)'"' != "" {
			file write `fh' `"Label: `macval(vlab)'"' _n
		}
		file write `fh' "Classification: excluded (privacy)" _n
		file write `fh' "Missing: `nmiss' obs (`pctmiss'%)" _n
		file write `fh' "(values excluded from documentation)" _n _n

		// Add analysis guidance
		if "`noguidance'" == "" {
			file write `fh' "PRIVACY NOTE: This variable excluded to protect participant privacy. "
			file write `fh' "Do not attempt to re-identify individuals. Use for linkage only if authorized."
			file write `fh' _n _n
		}
	}
end

capture program drop _datamap_ProcessValueLabels
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessValueLabels, nclass
	version 16.0
	args fh classifications format

	// Get all value labels used
	preserve
	quietly use "`classifications'", clear
	quietly keep if valuelabel != ""
	if _N == 0 {
		restore
		exit
	}

	// Get unique value labels
	quietly levelsof valuelabel, local(vallabs)

	if "`vallabs'" == "" {
		restore
		exit
	}

	// Index-keyed by position in `vallabs': `vars_<labelname>' locals
	// overflow the 31-character macro-name limit for long label names.
	local li = 0
	foreach vl of local vallabs {
		local ++li
		local vars`li' ""
		forvalues i = 1/`=_N' {
			if valuelabel[`i'] == "`vl'" {
				local vn = varname[`i']
				local vars`li' "`vars`li'' `vn'"
			}
		}
		local vars`li' = strtrim("`vars`li''")
	}
	restore

	_datamap_write_rule_header `fh' "VALUE LABEL DEFINITIONS"

	// Process each value label
	local li = 0
	foreach vl of local vallabs {
		local ++li
		local varlist "`vars`li''"

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
				file write `fh' `"  `lev' = `macval(labtext)'"' _n
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
capture program drop _datamap_ProcessBinary
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessBinary, nclass
	version 16.0
	args fh classifications format obs mincell

	preserve
	quietly use "`classifications'", clear
	quietly keep if is_binary == 1
	local nvars = _N
	if `nvars' == 0 {
		restore
		exit
	}
	forvalues i = 1/`nvars' {
		local vname_`i' = varname[`i']
		local vtype_`i' = vartype[`i']
		local vlab_`i' = varlabel[`i']
		local nmiss_`i' = cond(missing(missing_n[`i']), 0, missing_n[`i'])
		local pctmiss_`i' = cond(missing(missing_pct[`i']), 0, missing_pct[`i'])
	}
	restore

	file write `fh' "Binary Variables (potential outcomes/indicators)" _n _n

	forvalues i = 1/`nvars' {
		local vname "`vname_`i''"
		local vtype "`vtype_`i''"
		local vlab `"`macval(vlab_`i')'"'
		local nmiss = `nmiss_`i''
		local pctmiss = `pctmiss_`i''

		file write `fh' "`vname'"
		if `"`macval(vlab)'"' != "" {
			file write `fh' `": `macval(vlab)'"'
		}
		file write `fh' _n
		file write `fh' "  Type: `vtype' (binary)" _n
		file write `fh' "  Missing: `nmiss' obs (`pctmiss'%)" _n

		// Show frequency distribution
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
			local vallabtext ""
			capture local vallabtext : label (`vname') `val'
			if `mincell' > 0 & `freq' < `mincell' {
				if _rc == 0 & `"`macval(vallabtext)'"' != "" {
					file write `fh' `"    `val' (`macval(vallabtext)'): suppressed (<`mincell')"' _n
				}
				else {
					file write `fh' "    `val': suppressed (<`mincell')" _n
				}
			}
			else if _rc == 0 & `"`macval(vallabtext)'"' != "" {
				file write `fh' `"    `val' (`macval(vallabtext)'): `freq' (`pct'%)"' _n
			}
			else {
				file write `fh' "    `val': `freq' (`pct'%)" _n
			}
		}
		file write `fh' _n
	}
end

// =============================================================================
// Helper: _datamap_ProcessQuality
// Report data quality flags
// =============================================================================
capture program drop _datamap_ProcessQuality
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessQuality, nclass
	version 16.0
	args fh classifications format

	preserve
	quietly use "`classifications'", clear
	quietly count if quality_flag != ""
	if r(N) == 0 {
		restore
		exit
	}

	_datamap_write_rule_header `fh' "DATA QUALITY FLAGS"

	quietly keep if quality_flag != ""
	local nvars = _N

	forvalues i = 1/`nvars' {
		local vname = varname[`i']
		local qflag = quality_flag[`i']
		file write `fh' "  `vname': `qflag'" _n
	}
	file write `fh' _n
	restore
end

// =============================================================================
// Helper: _datamap_ProcessSamples
// Include sample observations (privacy-limited)
// =============================================================================
capture program drop _datamap_ProcessSamples
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_ProcessSamples, nclass
	version 16.0
	args fh classifications format nsamples exclude datesafe dateformat

	// Index-keyed by position in `classvars': `class_<varname>' locals
	// overflow the 31-character macro-name limit for long variable names.
	preserve
	quietly use "`classifications'", clear
	local classvars ""
	forvalues i = 1/`=_N' {
		local vn = varname[`i']
		local classvars "`classvars' `vn'"
		local class`i' = classification[`i']
	}
	restore

	_datamap_write_rule_header `fh' "SAMPLE OBSERVATIONS"
	if "`datesafe'" != "" {
		file write `fh' "First `nsamples' observations (excluded variables masked; date variables suppressed):" _n _n
	}
	else {
		file write `fh' "First `nsamples' observations (excluded variables masked):" _n _n
	}

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

				local cx : list posof "`vn'" in classvars
				local vnclass ""
				if `cx' > 0 local vnclass "`class`cx''"
				if `isexcl' {
					file write `fh' "[MASKED] | "
				}
				else if "`datesafe'" != "" & "`vnclass'" == "date" {
					file write `fh' "[DATE SUPPRESSED] | "
				}
				else {
					local vtype : type `vn'
					if substr("`vtype'", 1, 3) == "str" {
					local val = `vn'[`row']
					if length(`"`macval(val)'"') > 20 {
						local val = substr(`"`macval(val)'"', 1, 17) + "..."
					}
					file write `fh' `"`macval(val)' | "'
				}
					else {
						local val = `vn'[`row']
						if missing(`val') {
							file write `fh' ". | "
						}
						else if "`vnclass'" == "date" {
							local vfmt : format `vn'
							_datamap_DateDisplayFormat, vfmt("`vfmt'") dateformat("`dateformat'")
							local dispfmt "`r(display_format)'"
							local val = string(`vn'[`row'], "`dispfmt'")
							file write `fh' "`val' | "
						}
						else {
							file write `fh' "`=strtrim(string(`val', "%14.0g"))' | "
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

// Count distinct non-missing values of a variable.  Unlike -tabulate-, which
// errors r(134) above ~12,000 distinct values, this works at any cardinality.
capture program drop _datamap_ndistinct
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
// Thin wrapper over _datamap_nuniq, which counts distinct values without the
// full-dataset sort that -egen tag()- required.  Missing (and "" for strings)
// stay uncounted, as they were under the `if !missing(v)' restriction.
program define _datamap_ndistinct, rclass
	version 16.0
	args v
	_datamap_nuniq `v'
	return scalar n = r(n)
end

// Detect panel/longitudinal data structure
capture program drop _datamap_DetectPanel
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_DetectPanel, nclass
	version 16.0
	args fh filepath panelid format

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

	// Check for repeated observations.  -tabulate- errors r(134) above
	// ~12k units, and -codebook, compact- stores no r(ndistinct), so both
	// prior approaches failed for high-cardinality IDs.
	_datamap_ndistinct `id_var'
	local n_units = r(n)
	if `n_units' == 0 exit
	local n_obs = _N

	if `n_units' < `n_obs' {
		local avg_obs = strtrim(string(round(`n_obs' / `n_units', 0.1), "%14.0g"))
		file write `fh' "Panel Structure Detected" _n
		file write `fh' "  ID Variable: `id_var'" _n
		file write `fh' "  Unique Units: `n_units'" _n
		file write `fh' "  Total Observations: `n_obs'" _n
		file write `fh' "  Average Obs per Unit: `avg_obs'" _n _n
	}
end

// Detect survival/time-to-event data
capture program drop _datamap_DetectSurvival
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_DetectSurvival, nclass
	version 16.0
	args fh filepath survivalvars format

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
		// Show range for first time variable (numeric only)
		local first_time : word 1 of `time_vars'
		capture confirm numeric variable `first_time'
		if _rc == 0 {
			quietly summarize `first_time'
			local t_min = strtrim(string(round(r(min), 0.1), "%14.0g"))
			local t_max = strtrim(string(round(r(max), 0.1), "%14.0g"))
			file write `fh' "    `first_time' range: `t_min' to `t_max'" _n
		}
	}

	if "`event_vars'" != "" {
		file write `fh' "  Likely event indicators:`event_vars'" _n
		// Show event rate for first event variable (numeric binary only;
		// unguarded tab errors r(134) on high-cardinality name matches)
		local first_event : word 1 of `event_vars'
		capture confirm numeric variable `first_event'
		if _rc == 0 {
			_datamap_ndistinct `first_event'
			if r(n) == 2 {
				quietly summarize `first_event'
				local event_rate = strtrim(string(round(100 * r(mean), 0.1), "%14.0g"))
				file write `fh' "    `first_event' rate: `event_rate'%" _n
			}
		}
	}

	file write `fh' _n
end

// Detect survey design elements
capture program drop _datamap_DetectSurvey
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_DetectSurvey, nclass
	version 16.0
	args fh filepath format

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

	// Process weight variables (numeric only)
	foreach wvar of local weight_vars {
		capture confirm numeric variable `wvar'
		if _rc continue
		quietly summarize `wvar'
		local w_min = strtrim(string(round(r(min), 0.1), "%14.0g"))
		local w_max = strtrim(string(round(r(max), 0.1), "%14.0g"))
		local w_mean = strtrim(string(round(r(mean), 0.1), "%14.0g"))
		file write `fh' "  Sampling weight: `wvar' (range: `w_min' to `w_max', mean: `w_mean')" _n
	}

	// Process strata variables (-tabulate- errors r(134) above ~12k levels)
	foreach svar of local strata_vars {
		_datamap_ndistinct `svar'
		local n_strata = r(n)
		file write `fh' "  Stratification: `svar' (`n_strata' strata)" _n
	}

	// Process cluster variables
	foreach cvar of local cluster_vars {
		_datamap_ndistinct `cvar'
		local n_clusters = r(n)
		file write `fh' "  Clustering: `cvar' (`n_clusters' primary sampling units)" _n
	}

	file write `fh' _n
end

// Detect common variable name patterns
capture program drop _datamap_DetectCommon
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_DetectCommon, nclass
	version 16.0
	args fh filepath format

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
capture program drop _datamap_SummarizeMissing
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_SummarizeMissing, nclass
	version 16.0
	args fh filepath format pattern_check obs

	quietly describe, varlist
	local allvars `r(varlist)'

	// Count variables by missing percentage
	local vars_gt50 ""
	local n_gt50 = 0
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
		local pct_complete = strtrim(string(round(100 * `n_complete' / `obs', 0.1), "%14.0g"))
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
capture program drop _datamap_GenerateDatasetSummary
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_GenerateDatasetSummary, nclass
	version 16.0
	args fh filepath obs nvars label detect_panel detect_survival panelid dateformat datesafe

	file write `fh' "DESCRIPTION" _n
	file write `fh' "-----------" _n

	// Start building summary
	local summary "This dataset contains "

	// Determine structure type
	local is_cross_sectional 1

	// Check for panel structure
	if `detect_panel' & "`panelid'" != "" {
		capture confirm variable `panelid'
		if _rc == 0 {
			// -tabulate- errors r(134) above ~12k units
			_datamap_ndistinct `panelid'
			local n_units = r(n)
			local summary "`summary'longitudinal data with `n_units' units observed over time. "
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
		_datamap_DateFamily, vfmt("`vfmt'")
		if r(is_date) {
			local fam "`r(family)'"
			if !inlist("`fam'", "td", "tc", "tw", "tm", "tq") {
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
			_datamap_DateDisplayFormat, vfmt("`datefmt'") dateformat("`dateformat'")
			local dispfmt "`r(display_format)'"
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
