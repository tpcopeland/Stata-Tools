*! datadict Version 1.6.1  2026/07/15
*! Generate clean Markdown data dictionaries matching professional documentation style
*! Author: Timothy P Copeland, Karolinska Institutet

program define datadict, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	local _restore_needed = 0
	local _post_open = 0
	capture noisily {
	syntax [anything(name=varspec id="varlist")] [, ///
	          SIngle(string) DIRectory(string) FILElist(string) ///
	          MANifest(string) RECursive ///
	          OUtput(string) OUTDir(string) SUFfix(string) SEParate ///
	          TItle(string asis) SUBTitle(string asis) VERsion(string) ///
	          AUTHor(string asis) DATE(string) ///
		          NOTEs(string asis) CHANGElog(string asis) ///
		          MISSing STats DETail SAVing(string) ///
		          COLumns(string asis) CONFig(string) DATASIGnature ///
		          MAXCat(integer -999999999) MAXFreq(integer -999999999) ///
		          UNIQCap(integer -999999999) ///
		          MINCell(integer -999999999) ///
		          EXClude(string) CONTinuous(string) CATegorical(string) ///
		          DATEVars(string) DATEFormat(string)]

	// Load reusable project defaults before applying command defaults.
		if `"`config'"' != "" {
			_datadict_ValidatePath `"`config'"', option("config()")
			confirm file `"`config'"'
			_datamap_load_config, config(`"`config'"')
			foreach opt in output outdir suffix title subtitle version author date notes changelog columns {
				local cfgval `"`r(`opt')'"'
				if `"``opt''"' == "" & `"`cfgval'"' != "" {
					local `opt' `"`cfgval'"'
				}
			}
			if `"`date'"' == "" & `"`r(docdate)'"' != "" local date `"`r(docdate)'"'
			foreach opt in exclude continuous categorical datevars dateformat {
				local cfgval `"`r(`opt')'"'
				if `"``opt''"' == "" & `"`cfgval'"' != "" {
					local `opt' `"`cfgval'"'
				}
			}
			foreach opt in maxcat maxfreq mincell {
				if ``opt'' == -999999999 & `"`r(`opt')'"' != "" {
					local `opt' = real(`"`r(`opt')'"')
				}
			}
			if "`missing'" == "" & "`r(missing)'" != "" local missing "missing"
			if "`stats'" == "" & "`r(stats)'" != "" local stats "stats"
			if "`detail'" == "" & "`r(detail)'" != "" local detail "detail"
			if "`datasignature'" == "" & "`r(datasignature)'" != "" local datasignature "datasignature"
		}
		if `maxcat' == -999999999 local maxcat = 25
		if `maxfreq' == -999999999 local maxfreq = 25
		if `mincell' == -999999999 local mincell = 5
		if `uniqcap' == -999999999 local uniqcap = 1000
		if `maxcat' <= 0 | missing(`maxcat') {
			noisily di as error "maxcat() must be positive"
			exit 198
		}
		if `maxfreq' <= 0 | missing(`maxfreq') {
			noisily di as error "maxfreq() must be positive"
			exit 198
		}
		if `mincell' < 0 | missing(`mincell') {
			noisily di as error "mincell() must be non-negative"
			exit 198
		}
		if `uniqcap' < 0 | missing(`uniqcap') {
			noisily di as error "uniqcap() must be non-negative (0 = exact counts, no cap)"
			exit 198
		}

		// Set default date format (ISO 8601: YYYY/MM/DD)
	if `"`dateformat'"' == "" local dateformat "%tdCCYY/NN/DD"
	if strpos(`"`dateformat'"', "%t") != 1 & strpos(`"`dateformat'"', "%d") != 1 {
		noisily di as error "dateformat() must be a Stata date/time display format beginning with %t or %d"
		exit 198
	}

	// Validate input options
	local ninput = ("`single'" != "") + ("`directory'" != "") + ///
		(`"`filelist'"' != "") + ("`manifest'" != "")
	if `ninput' > 1 {
		noisily di as error "specify only one of single(), directory(), filelist(), or manifest()"
		exit 198
	}
	if `"`varspec'"' != "" & `ninput' > 0 & `"`single'"' == "" {
		noisily di as error "varlist is allowed only with data in memory or single()"
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
		if `mincell' < 0 {
			di as error "mincell must be non-negative"
			exit 198
		}

	// Set defaults
	if `"`output'"' == "" local output "data_dictionary.md"
	if `"`title'"' == "" local title "Data Dictionary"
	if `"`date'"' == "" local date "`c(current_date)'"
	if `"`suffix'"' == "" local suffix "_dictionary"

	local columnsopt ""
	if `"`columns'"' != "" local columnsopt `"columns(`columns')"'
	_datadict_NormalizeColumns, `columnsopt' detail("`detail'") ///
		missing("`missing'") stats("`stats'")
	local columns `"`r(columns)'"'
	local showmissing "`r(showmissing)'"
	local showstats "`r(showstats)'"

	if `"`output'"' != "" & "`separate'" == "" {
		_datadict_ValidatePath `"`output'"', option("output()")
	}
	if `"`outdir'"' != "" {
		_datadict_ValidatePath `"`outdir'"', option("outdir()")
	}
	if `"`manifest'"' != "" {
		_datadict_ValidatePath `"`manifest'"', option("manifest()")
		confirm file `"`manifest'"'
	}

	local saving_file ""
	local saving_replace 0
	local result_metadata ""
	if `"`saving'"' != "" {
		_datadict_ParseSaving, saving(`"`saving'"')
		local saving_file `"`r(file)'"'
		local saving_replace = r(replace)
		_datadict_ValidatePath `"`saving_file'"', option("saving()")
		if !`saving_replace' {
			confirm new file `"`saving_file'"'
		}
	}

	// Preserve only when this run loads files into memory over the user's data.
	// Documenting the data already in memory needs no snapshot -- and a
	// -preserve- is a full second copy of the dataset, which on a multi-GB file
	// is the difference between fitting in RAM and paging.  See datamap.ado.
	// Cleanup runs after the capture block on all exits.
	if !`from_memory' {
		preserve
		local _restore_needed = 1
	}

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
	else if `"`manifest'"' != "" {
		_datadict_CollectManifest, manifest(`"`manifest'"') saving(`"`filelist_tmp'"')
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

	_datadict_FileListMacro, filelist(`"`filelist_tmp'"') memory(`from_memory')
	local result_files `"`r(files)'"'

	local result_mode "memory"
	if !`from_memory' {
		if `"`single'"' != "" local result_mode "single"
		else if `"`filelist'"' != "" local result_mode "filelist"
		else if `"`manifest'"' != "" local result_mode "manifest"
		else if `"`recursive'"' != "" local result_mode "directory_recursive"
		else local result_mode "directory"
	}

	if `"`saving_file'"' != "" {
		tempfile metadata_tmp
		tempname metadata_post
			quietly postfile `metadata_post' ///
				str16 source_command str2045 source str2045 output ///
				str80 dataset str2045 dataset_label ///
				str32 variable str20 storage_type str32 display_format ///
				str32 value_label str20 class double N long nvars long missing ///
				double missing_pct long unique str2045 variable_label str2045 notes ///
				str2045 characteristics double mean double sd double p50 ///
				double p25 double p75 double min double max str2045 datasignature ///
				byte unique_capped ///
				using `"`metadata_tmp'"', replace
		local _post_open = 1
		local postopt `"postname(`metadata_post')"'
	}

	// Process files (data already preserved at top of program)
	if "`separate'" != "" {
		_datadict_ProcessSeparate, filelist(`"`filelist_tmp'"') namesfile(`"`names_tmp'"') ///
			title(`"`title'"') subtitle(`"`subtitle'"') version(`"`version'"') ///
				author(`"`author'"') date(`"`date'"') notes(`"`notes'"') ///
				changelog(`"`changelog'"') nfiles(`nfiles') `showmissing' `showstats' ///
				maxcat(`maxcat') maxfreq(`maxfreq') mincell(`mincell') ///
				uniqcap(`uniqcap') ///
				exclude(`"`exclude'"') continuous(`"`continuous'"') ///
				categorical(`"`categorical'"') datevars(`"`datevars'"') ///
				dateformat("`dateformat'") ///
				columns(`columns') varspec(`"`varspec'"') outdir(`"`outdir'"') ///
				suffix(`"`suffix'"') `datasignature' `postopt'
	}
	else {
		_datadict_ProcessCombined, filelist(`"`filelist_tmp'"') namesfile(`"`names_tmp'"') ///
			output(`"`output'"') title(`"`title'"') subtitle(`"`subtitle'"') ///
				version(`"`version'"') author(`"`author'"') date(`"`date'"') ///
				notes(`"`notes'"') changelog(`"`changelog'"') nfiles(`nfiles') ///
				`showmissing' `showstats' maxcat(`maxcat') maxfreq(`maxfreq') ///
				mincell(`mincell') uniqcap(`uniqcap') exclude(`"`exclude'"') ///
				continuous(`"`continuous'"') categorical(`"`categorical'"') ///
				datevars(`"`datevars'"') dateformat("`dateformat'") columns(`columns') ///
				varspec(`"`varspec'"') `datasignature' `postopt'
	}
	local result_output `"`r(output)'"'
	local result_outputs `"`r(outputs)'"'
	local result_nobs_total = r(nobs_total)
	local result_nvars_total = r(nvars_total)
	local result_nfiles = `nfiles'

	if `"`saving_file'"' != "" {
		postclose `metadata_post'
		local _post_open = 0
		// Frame: -use- here would replace the user's data with the metadata
		// table.  The top-level preserve used to undo that; the in-memory path
		// no longer takes one.
		tempname _mfr
		frame create `_mfr'
		frame `_mfr' {
			use `"`metadata_tmp'"', clear
			if `saving_replace' {
				quietly save `"`saving_file'"', replace
			}
			else {
				quietly save `"`saving_file'"'
			}
		}
		frame drop `_mfr'
		local result_metadata `"`saving_file'"'
	}

	// Restore original data (only if this run preserved it)
	if `_restore_needed' {
		restore
		local _restore_needed = 0
	}

	}
	local rc = _rc
	if `_post_open' {
		capture postclose `metadata_post'
		local _postclose_rc = _rc
	}
	if `_restore_needed' {
		capture restore
		local _restore_rc = _rc
	}
	set varabbrev `_varabbrev'
	if `rc' exit `rc'

	// Return results after cleanup so preserve/restore cannot disturb r().
	return scalar nfiles = `result_nfiles'
	return scalar nvars_total = `result_nvars_total'
	return scalar nobs_total = `result_nobs_total'
	return local mode `"`result_mode'"'
	return local files `"`result_files'"'
	return local outputs `"`result_outputs'"'
	return local output `"`result_output'"'
	if `"`result_metadata'"' != "" {
		return local metadata `"`result_metadata'"'
	}

	if "`separate'" != "" {
		di as result "Markdown dictionaries generated for `result_nfiles' dataset(s)"
	}
	else {
		di as result `"Markdown dictionary generated: `result_output'"'
	}
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
// Helper: ValidatePath - reject shell metacharacters in file path options
// =============================================================================
capture program drop _datadict_ValidatePath
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_ValidatePath, nclass
	version 16.0
	syntax anything(name=path id="path"), OPTion(string)

	local path = strtrim(`"`macval(path)'"')
	if substr(`"`path'"', 1, 1) == char(34) & ///
	   substr(`"`path'"', length(`"`path'"'), 1) == char(34) {
		local path = substr(`"`path'"', 2, length(`"`path'"') - 2)
	}
	local path = subinstr(`"`macval(path)'"', char(34), "", .)

	foreach bad in ";" "&" "|" ">" "<" "$" {
		if strpos(`"`macval(path)'"', "`bad'") > 0 {
			noisily di as error "`option' contains unsupported shell metacharacter: `bad'"
			exit 198
		}
	}
end

// =============================================================================
// Helper: ParseSaving - parse saving(filename[, replace])
// =============================================================================
capture program drop _datadict_ParseSaving
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_ParseSaving, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax, SAVing(string)

		local spec = subinstr(`"`macval(saving)'"', char(34), "", .)
		local spec = subinstr(`"`macval(spec)'"', ")", "", .)
		local cpos = strpos(`"`macval(spec)'"', ",")
		if `cpos' > 0 {
			local savefile = strtrim(substr(`"`macval(spec)'"', 1, `cpos' - 1))
			local saveopts = strtrim(substr(`"`macval(spec)'"', `cpos' + 1, .))
		}
		else {
			local savefile = strtrim(`"`macval(spec)'"')
			local saveopts ""
		}
		if `"`savefile'"' == "" {
			noisily di as error "saving() requires a filename"
			exit 198
		}

		local replace 0
		if `"`saveopts'"' != "" {
			local saveopts_l = lower(strtrim(`"`saveopts'"'))
			if strpos(`"`saveopts_l'"', "replace") > 0 {
				local replace 1
			}
			else {
				noisily di as error "saving() supports only the replace suboption"
				exit 198
			}
		}

		return scalar replace = `replace'
		return local file `"`savefile'"'
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: LoadConfig - parse reusable key=value defaults
// =============================================================================
capture program drop _datadict_LoadConfig
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_LoadConfig, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	local _fh_open = 0
	capture noisily {
		syntax, CONFig(string)

		tempname fh
		file open `fh' using `"`config'"', read text
		local _fh_open = 1
		file read `fh' line
		while r(eof) == 0 {
			local raw = strtrim(`"`macval(line)'"')
			if `"`raw'"' != "" & substr(`"`raw'"', 1, 1) != "#" & ///
			   substr(`"`raw'"', 1, 1) != "*" & substr(`"`raw'"', 1, 2) != "//" {
				local eqpos = strpos(`"`raw'"', "=")
				local colonpos = strpos(`"`raw'"', ":")
				local splitpos = `eqpos'
				if `splitpos' == 0 | (`colonpos' > 0 & `colonpos' < `splitpos') {
					local splitpos = `colonpos'
				}
				if `splitpos' > 0 {
					local key = lower(strtrim(substr(`"`raw'"', 1, `splitpos' - 1)))
					local val = strtrim(substr(`"`raw'"', `splitpos' + 1, .))
					local key = subinstr(`"`key'"', " ", "", .)
					if inlist(`"`key'"', "title", "subtitle", "version", "author", "date") {
						return local `key' `"`macval(val)'"'
					}
					else if inlist(`"`key'"', "notes", "changelog", "output", "outdir", "suffix", "columns") {
						return local `key' `"`macval(val)'"'
					}
					else if inlist(`"`key'"', "missing", "stats", "detail", "datasignature") {
						if inlist(lower(`"`val'"'), "1", "yes", "true", "on", "`key'") {
							return local `key' "`key'"
						}
					}
				}
			}
			file read `fh' line
		}
		file close `fh'
		local _fh_open = 0
	}
	local rc = _rc
	if `_fh_open' {
		capture file close `fh'
		local _close_rc = _rc
	}
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: NormalizeColumns - validate and expand table column choices
// =============================================================================
capture program drop _datadict_NormalizeColumns
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_NormalizeColumns, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax, [COLumns(string asis) DETail(string) MISSing(string) STats(string)]

		local columns = subinstr(`"`macval(columns)'"', char(34), "", .)
		local cols ""
		if `"`columns'"' == "" {
			local cols "variable label type"
			if "`detail'" != "" {
				local cols "`cols' storage format vallabel notes chars"
			}
			if "`missing'" != "" {
				local cols "`cols' missing"
			}
			if "`stats'" != "" {
				local cols "`cols' stats"
			}
			else {
				local cols "`cols' values"
			}
		}
		else {
			local cleaned = subinstr(`"`columns'"', ",", " ", .)
			local cleaned = subinstr(`"`cleaned'"', "|", " ", .)
			local cleaned = strtrim(`"`cleaned'"')
			foreach raw in `cleaned' {
				local col = lower(strtrim(`"`raw'"'))
				if inlist(`"`col'"', "name", "var", "variable") local col "variable"
				else if inlist(`"`col'"', "label", "varlabel") local col "label"
				else if inlist(`"`col'"', "type") local col "type"
				else if inlist(`"`col'"', "class", "classification") local col "class"
				else if inlist(`"`col'"', "storage", "storagetype") local col "storage"
				else if inlist(`"`col'"', "format", "displayformat") local col "format"
				else if inlist(`"`col'"', "vallabel", "valuelabel", "value_label") local col "vallabel"
				else if inlist(`"`col'"', "missing", "miss") local col "missing"
				else if inlist(`"`col'"', "values", "notesvalues", "valuesnotes") local col "values"
				else if inlist(`"`col'"', "stats", "statistics") local col "stats"
				else if inlist(`"`col'"', "notes", "varnotes") local col "notes"
				else if inlist(`"`col'"', "chars", "characteristics", "char") local col "chars"
				else {
					noisily di as error "invalid columns() field: `raw'"
					noisily di as error "allowed fields: name label type class storage format vallabel missing values stats notes chars"
					exit 198
				}
				local cols "`cols' `col'"
			}
			local cols = strtrim(`"`cols'"')
		}

		local hasmissing = strpos(" `cols' ", " missing ") > 0
		local hasstats = strpos(" `cols' ", " stats ") > 0
		return local columns "`cols'"
		if `hasmissing' return local showmissing "missing"
		if `hasstats' return local showstats "stats"
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: CollectManifest - read one dataset path per line
// =============================================================================
capture program drop _datadict_CollectManifest
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_CollectManifest, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	local _fh_in_open = 0
	local _fh_out_open = 0
	capture noisily {
		syntax, MANifest(string) SAVing(string)

		tempname fh_in fh_out
		file open `fh_in' using `"`manifest'"', read text
		local _fh_in_open = 1
		quietly file open `fh_out' using `"`saving'"', write text replace
		local _fh_out_open = 1

		local nfiles 0
		file read `fh_in' line
		while r(eof) == 0 {
			local path = strtrim(`"`macval(line)'"')
			if `"`path'"' != "" & substr(`"`path'"', 1, 1) != "#" {
				local path = cond(regexm(`"`path'"', "\.dta$"), `"`path'"', `"`path'.dta"')
				_datadict_ValidatePath `"`path'"', option("manifest() dataset path")
				confirm file `"`path'"'
				file write `fh_out' `"`path'"' _n
				local ++nfiles
			}
			file read `fh_in' line
		}

		file close `fh_in'
		local _fh_in_open = 0
		file close `fh_out'
		local _fh_out_open = 0
		return scalar nfiles = `nfiles'
	}
	local rc = _rc
	if `_fh_in_open' {
		capture file close `fh_in'
		local _close_in_rc = _rc
	}
	if `_fh_out_open' {
		capture file close `fh_out'
		local _close_out_rc = _rc
	}
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: FileListMacro - return semicolon-delimited processed file list
// =============================================================================
capture program drop _datadict_FileListMacro
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_FileListMacro, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	local _fh_open = 0
	capture noisily {
		syntax, FILElist(string) MEMory(integer)

		if `memory' {
			return local files "memory"
			exit
		}

		tempname fh
		file open `fh' using `"`filelist'"', read text
		local _fh_open = 1
		local files ""
		file read `fh' filepath
		while r(eof) == 0 {
			if `"`files'"' == "" local files `"`macval(filepath)'"'
			else local files `"`macval(files)';`macval(filepath)'"'
			file read `fh' filepath
		}
		file close `fh'
		local _fh_open = 0
		return local files `"`macval(files)'"'
	}
	local rc = _rc
	if `_fh_open' {
		capture file close `fh'
		local _close_rc = _rc
	}
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: FileSize - safely get file size in bytes without shelling out
// =============================================================================
capture program drop _datadict_FileSize
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_FileSize, rclass
	version 16.0
	args filepath
	tempname bytes
	capture confirm file `"`filepath'"'
	if _rc {
		return scalar bytes = .
		exit
	}
	capture mata: fh = fopen(st_local("filepath"), "r"); fseek(fh, 0, 1); st_numscalar("`bytes'", ftell(fh)); fclose(fh)
	if _rc return scalar bytes = .
	else return scalar bytes = `bytes'
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

		_datadict_EscapeMarkdown `"`macval(labtext)'"'
		local labtext `"`r(escaped)'"'

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
	args vname vallabname maxlevels totalobs mincell
	if "`mincell'" == "" local mincell = 0

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

		_datadict_EscapeMarkdown `"`macval(labtext)'"'
		local labtext `"`r(escaped)'"'

		if `mincell' > 0 & `levcount' < `mincell' {
			if `"`labtext'"' != "" {
				local valstring `"`valstring'<br>`lev' `labtext' (suppressed <`mincell')"'
			}
			else {
				local valstring `"`valstring'<br>`lev' (suppressed <`mincell')"'
			}
		}
		else if `"`labtext'"' != "" {
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
	args vname maxlevels totalobs mincell
	if "`mincell'" == "" local mincell = 0

	capture quietly levelsof `vname' if !missing(`vname'), local(levels)
	if _rc != 0 | `"`levels'"' == "" {
		return local valstring "All missing"
		exit
	}

	local nlevels: word count `levels'

	// Count non-missing
	quietly count if !missing(`vname')
	local nvalid = r(N)
	capture confirm numeric variable `vname'
	local is_numeric = (_rc == 0)

	if `nlevels' > `maxlevels' {
		return local valstring "Unique=`nlevels'"
		exit
	}

	// Build multi-line output: Unique= first, then one line per value
	local valstring "Unique=`nlevels'"
	foreach lev of local levels {
		// Get count for this level
		local levdisplay `"`macval(lev)'"'
		if `is_numeric' {
			quietly count if `vname' == `lev'
		}
		else {
			local levcmp = subinstr(`"`macval(lev)'"', char(34), "", .)
			quietly count if `vname' == `"`macval(levcmp)'"'
			_datadict_EscapeMarkdown `"`macval(levcmp)'"'
			local levdisplay `"`r(escaped)'"'
		}
		local levcount = r(N)
		if `nvalid' > 0 {
			local levpct = strtrim(string(100 * `levcount' / `nvalid', "%9.1f"))
		}
		else {
			local levpct "0.0"
		}

		if `mincell' > 0 & `levcount' < `mincell' {
			local valstring `"`valstring'<br>`levdisplay' (suppressed <`mincell')"'
		}
		else {
			local valstring `"`valstring'<br>`levdisplay' (`levcount'; `levpct'%)"'
		}
	}

	return local valstring `"`valstring'"'
end

// =============================================================================
// Overrides for datadict 1.4.0 feature surface
// =============================================================================

capture program drop _datadict_WriteTableHeader
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_WriteTableHeader, nclass
	version 16.0
	syntax, HANDLE(name) COLumns(string)

	local header "|"
	local divider "|"
	foreach col of local columns {
		if "`col'" == "variable" local label "Variable"
		else if "`col'" == "label" local label "Label"
		else if "`col'" == "type" local label "Type"
		else if "`col'" == "class" local label "Class"
		else if "`col'" == "storage" local label "Storage"
		else if "`col'" == "format" local label "Format"
		else if "`col'" == "vallabel" local label "Value label"
		else if "`col'" == "missing" local label "Missing"
		else if "`col'" == "values" local label "Values/Notes"
		else if "`col'" == "stats" local label "Statistics/Values"
		else if "`col'" == "notes" local label "Notes"
		else if "`col'" == "chars" local label "Characteristics"
		local header "`header' `label' |"
		local divider "`divider'---|"
	}
	file write `handle' "`header'" _n
	file write `handle' "`divider'" _n
end

capture program drop _datadict_WriteTextBlock
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_WriteTextBlock, nclass
	version 16.0
	syntax, HANDLE(name) KIND(string) DATEFormat(string) [TEXT(string asis)]

	local text = subinstr(`"`macval(text)'"', char(34), "", .)
	local text = subinstr(`"`macval(text)'"', char(96), "", .)
	local text = subinstr(`"`macval(text)'"', char(39), "", .)

	if `"`text'"' != "" {
		capture quietly confirm file `"`text'"'
		if _rc == 0 {
			tempname fh_text
			file open `fh_text' using `"`text'"', read text
			file read `fh_text' blockline
			while r(eof) == 0 {
				_datadict_EscapeMarkdown `"`macval(blockline)'"'
				local escaped `"`r(escaped)'"'
				file write `handle' `"`macval(escaped)'"' _n
				file read `fh_text' blockline
			}
			file close `fh_text'
		}
		else {
			_datadict_EscapeMarkdown `"`macval(text)'"'
			local escaped `"`r(escaped)'"'
			file write `handle' `"`macval(escaped)'"' _n
		}
		exit
	}

	if "`kind'" == "notes" {
		file write `handle' `"- All date variables are displayed using `dateformat' format"' _n
		file write `handle' "- Missing values coded as . (numeric missing) or empty string" _n
	}
	else {
		file write `handle' "*No changes recorded.*" _n
	}
end

capture program drop _datadict_DeriveSeparateOutput
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_DeriveSeparateOutput, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax, FILEPATH(string asis) DSName(string asis) SUFfix(string) [OUTDir(string)]

		local filepath = subinstr(`"`macval(filepath)'"', char(34), "", .)
		local filepath = subinstr(`"`macval(filepath)'"', char(96), "", .)
		local filepath = subinstr(`"`macval(filepath)'"', char(39), "", .)
		local outdir = subinstr(`"`macval(outdir)'"', char(34), "", .)
		local outdir = subinstr(`"`macval(outdir)'"', char(96), "", .)
		local outdir = subinstr(`"`macval(outdir)'"', char(39), "", .)
		local suffix = subinstr(`"`macval(suffix)'"', char(34), "", .)
		local suffix = subinstr(`"`macval(suffix)'"', char(96), "", .)
		local suffix = subinstr(`"`macval(suffix)'"', char(39), "", .)

		local basename = ustrregexra(`"`macval(filepath)'"', ".*[/\\]", "")
		local basename = ustrregexra(`"`basename'"', "\.dta$", "")
		if `"`outdir'"' != "" {
			local outroot = subinstr(`"`outdir'"', "\", "/", .)
			if substr(`"`outroot'"', length(`"`outroot'"'), 1) == "/" {
				local outroot = substr(`"`outroot'"', 1, length(`"`outroot'"') - 1)
			}
			local outfile `"`outroot'/`basename'`suffix'.md"'
		}
		else {
			local len = length(`"`macval(filepath)'"')
			if substr(`"`macval(filepath)'"', `len' - 3, 4) == ".dta" {
				local outbase = substr(`"`macval(filepath)'"', 1, `len' - 4)
			}
			else {
				local outbase `"`macval(filepath)'"'
			}
			local outfile `"`outbase'`suffix'.md"'
		}
		return local output `"`outfile'"'
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

capture program drop _datadict_WriteVariableRow
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
	program define _datadict_WriteVariableRow, nclass
		version 16.0
		syntax, HANDLE(name) VNAME(name) OBS(integer) COLumns(string) ///
			MAXCat(integer) MAXFreq(integer) MINCell(integer) DATEFormat(string) VARCLASS(string) ///
			UNIQCap(integer) ///
			SOURCE(string asis) OUtput(string asis) DSName(string asis) ///
			DSLABEL(string asis) NVARS(integer) [POSTNAME(name) DATASIGnature(string asis)]

	local source = subinstr(`"`macval(source)'"', char(34), "", .)
	local source = subinstr(`"`macval(source)'"', char(96), "", .)
	local source = subinstr(`"`macval(source)'"', char(39), "", .)
	local output = subinstr(`"`macval(output)'"', char(34), "", .)
	local output = subinstr(`"`macval(output)'"', char(96), "", .)
	local output = subinstr(`"`macval(output)'"', char(39), "", .)
	local dsname = subinstr(`"`macval(dsname)'"', char(34), "", .)
	local dsname = subinstr(`"`macval(dsname)'"', char(96), "", .)
	local dsname = subinstr(`"`macval(dsname)'"', char(39), "", .)
	local dslabel = subinstr(`"`macval(dslabel)'"', char(34), "", .)
	local dslabel = subinstr(`"`macval(dslabel)'"', char(96), "", .)
	local dslabel = subinstr(`"`macval(dslabel)'"', char(39), "", .)

	local vtype: type `vname'
	local vfmt: format `vname'
	local vlab: variable label `vname'
	local vallabname: value label `vname'

	_datadict_EscapeMarkdown `"`macval(vlab)'"'
	local vlab_safe `"`r(escaped)'"'
	_datadict_EscapeMarkdown `"`vtype'"'
	local vtype_safe `"`r(escaped)'"'
	_datadict_EscapeMarkdown `"`vfmt'"'
	local vfmt_safe `"`r(escaped)'"'
	_datadict_EscapeMarkdown `"`vallabname'"'
	local vallab_safe `"`r(escaped)'"'

	_datadict_GetVariableNotes `vname'
	local notesstr `"`r(notes)'"'
	_datadict_GetVariableChars `vname'
	local charsstr `"`r(chars)'"'

	local typestr "Numeric"
	if substr("`vtype'", 1, 3) == "str" {
		local typestr "String"
	}
	else if strpos("`vfmt'", "%t") > 0 | strpos("`vfmt'", "%d") > 0 {
		local typestr "Date"
	}

	quietly count if missing(`vname')
	local nmiss = r(N)
	if `obs' > 0 local pctmiss = strtrim(string(100 * `nmiss' / `obs', "%9.1f"))
	else local pctmiss "0.0"
	local missingstr "`nmiss' (`pctmiss'%)"

	// -egen tag()- sorts the WHOLE dataset once per variable, which made
	// datadict 6.5x slower than datamap on the same file (measured: 347s vs 54s
	// on a 3M x 60 dataset).  _datamap_nuniq walks the column in bounded chunks
	// and stops early once the count exceeds the cap.  See _datamap_nuniq.ado.
	local nuniq = .
	local ncapped = 0
	capture _datamap_nuniq `vname', cap(`uniqcap')
	if _rc == 0 {
		local nuniq = r(n)
		local ncapped = r(capped)
	}

	local valuesstr ""
	if "`vallabname'" != "" {
		_datadict_GetValueLabelString `"`vname'"' `"`vallabname'"' `maxfreq'
		local valuesstr `"`r(valstring)'"'
	}
	else if "`typestr'" == "Date" {
		if strpos("`vfmt'", "%tc") > 0 local valuesstr "Datetime"
		else local valuesstr "Date"
	}
	else if substr("`vtype'", 1, 3) == "str" {
		local valuesstr ""
	}
	else {
		local vname_lower = lower(`"`vname'"')
		if inlist(`"`vname_lower'"', "id", "lopnr") | ///
		   strpos(`"`vname_lower'"', "_id") > 0 | ///
		   strpos(`"`vname_lower'"', "personid") > 0 | ///
		   strpos(`"`vname_lower'"', "identifier") > 0 {
			local valuesstr "Unique identifier"
		}
		else if inlist(`"`vname_lower'"', "year", "yr") {
			local valuesstr "Year of observation"
		}
			else if "`varclass'" == "categorical" {
				_datadict_GetUnlabeledStats `"`vname'"' `maxfreq' `obs' `mincell'
				local valuesstr `"`r(valstring)'"'
			}
	}

	local statsstr ""
	local mean = .
	local sd = .
	local p50 = .
	local p25 = .
	local p75 = .
	local vmin_raw = .
	local vmax_raw = .
	capture confirm numeric variable `vname'
	local is_numeric = (_rc == 0)
	if `is_numeric' {
		quietly summarize `vname', detail
		if r(N) > 0 {
			local mean = r(mean)
			local sd = r(sd)
			local p50 = r(p50)
			local p25 = r(p25)
			local p75 = r(p75)
			local vmin_raw = r(min)
			local vmax_raw = r(max)
		}
	}

		if "`varclass'" == "categorical" {
			if "`vallabname'" != "" {
				_datadict_GetCategoricalStats `"`vname'"' `"`vallabname'"' `maxfreq' `obs' `mincell'
				local statsstr `"`r(valstring)'"'
			}
			else {
				if !missing(`nuniq') & `nuniq' <= `maxfreq' {
					_datadict_GetUnlabeledStats `"`vname'"' `maxfreq' `obs' `mincell'
					local statsstr `"`r(valstring)'"'
				}
			else {
				_datamap_fmt_uniq `nuniq' `ncapped'
				local statsstr "Unique=`r(s)'"
			}
		}
	}
	else if "`varclass'" == "continuous" {
		if `is_numeric' & !missing(`mean') {
			_datadict_FormatStatNumber `mean'
			local mean_s `r(formatted)'
			_datadict_FormatStatNumber `sd'
			local sd_s `r(formatted)'
			_datadict_FormatStatNumber `p50'
			local median_s `r(formatted)'
			_datadict_FormatStatNumber `p25'
			local p25_s `r(formatted)'
			_datadict_FormatStatNumber `p75'
			local p75_s `r(formatted)'
			_datadict_FormatStatNumber `vmin_raw'
			local min_s `r(formatted)'
			_datadict_FormatStatNumber `vmax_raw'
			local max_s `r(formatted)'
			quietly count if !missing(`vname')
			local nvalid = r(N)
			local statsstr "N=`nvalid'<br>Median=`median_s'; IQR=`p25_s'-`p75_s'<br>Mean=`mean_s' (SD=`sd_s')<br>Range=`min_s'-`max_s'"
		}
		else {
			local statsstr "All missing"
		}
	}
	else if "`varclass'" == "date" {
		if `is_numeric' & !missing(`vmin_raw') {
			quietly count if !missing(`vname')
			local nvalid = r(N)
			_datadict_DateDisplayFormat, vfmt("`vfmt'") dateformat("`dateformat'")
			local datefmt "`r(display_format)'"
			local mindate = string(`vmin_raw', "`datefmt'")
			local maxdate = string(`vmax_raw', "`datefmt'")
			_datadict_EscapeMarkdown `"`mindate'"'
			local mindate `"`r(escaped)'"'
			_datadict_EscapeMarkdown `"`maxdate'"'
			local maxdate `"`r(escaped)'"'
			local statsstr "N=`nvalid'<br>Range: `mindate' to `maxdate'"
		}
		else {
			local statsstr "All missing"
		}
	}
	else if "`varclass'" == "string" {
		quietly count if !missing(`vname')
		local nvalid = r(N)
		_datamap_fmt_uniq `nuniq' `ncapped'
		local statsstr "N=`nvalid'; `r(s)' unique values"
	}

	local row "|"
	foreach col of local columns {
		local cell ""
		if "`col'" == "variable" local cell "\``vname'\`"
		else if "`col'" == "label" local cell `"`macval(vlab_safe)'"'
		else if "`col'" == "type" local cell "`typestr'"
		else if "`col'" == "class" local cell "`varclass'"
		else if "`col'" == "storage" local cell `"`macval(vtype_safe)'"'
		else if "`col'" == "format" local cell `"`macval(vfmt_safe)'"'
		else if "`col'" == "vallabel" local cell `"`macval(vallab_safe)'"'
		else if "`col'" == "missing" local cell "`missingstr'"
		else if "`col'" == "values" local cell `"`macval(valuesstr)'"'
		else if "`col'" == "stats" local cell `"`macval(statsstr)'"'
		else if "`col'" == "notes" local cell `"`macval(notesstr)'"'
		else if "`col'" == "chars" local cell `"`macval(charsstr)'"'
		local row `"`macval(row)' `macval(cell)' |"'
	}
	file write `handle' `"`macval(row)'"' _n

	if "`postname'" != "" {
		local post_source = substr(`"`macval(source)'"', 1, 2045)
		local post_output = substr(`"`macval(output)'"', 1, 2045)
		foreach field in post_source post_output {
			local `field' = subinstr(`"`macval(`field')'"', char(96), "", .)
			local `field' = subinstr(`"`macval(`field')'"', char(34), "", .)
			local `field' = subinstr(`"`macval(`field')'"', char(39), "", .)
		}
		local post_dslabel = substr(`"`macval(dslabel)'"', 1, 2045)
		local post_vlab = substr(`"`macval(vlab)'"', 1, 2045)
		local post_notes = substr(`"`macval(notesstr)'"', 1, 2045)
		local post_chars = substr(`"`macval(charsstr)'"', 1, 2045)
			local post_dsig = substr(`"`macval(datasignature)'"', 1, 2045)
			post `postname' (`"datadict"') (`"`macval(post_source)'"') (`"`macval(post_output)'"') ///
				(`"`dsname'"') (`"`macval(post_dslabel)'"') (`"`vname'"') ///
				(`"`vtype'"') (`"`vfmt'"') (`"`vallabname'"') (`"`varclass'"') ///
				(`obs') (`nvars') (`nmiss') (`pctmiss') (`nuniq') (`"`macval(post_vlab)'"') ///
				(`"`macval(post_notes)'"') (`"`macval(post_chars)'"') ///
				(`mean') (`sd') (`p50') (`p25') (`p75') (`vmin_raw') (`vmax_raw') ///
				(`"`macval(post_dsig)'"') (`ncapped')
		}
	end

capture program drop _datadict_GetVariableNotes
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_GetVariableNotes, rclass
	version 16.0
	args vname

	local notes ""
	local note0: char `vname'[note0]
	if "`note0'" == "" local note0 0
	forvalues i = 1/`note0' {
		local notei: char `vname'[note`i']
		if `"`notei'"' != "" {
			_datadict_EscapeMarkdown `"`macval(notei)'"'
			local escaped `"`r(escaped)'"'
			if `"`notes'"' == "" local notes `"`macval(escaped)'"'
			else local notes `"`macval(notes)'<br>`macval(escaped)'"'
		}
	}
	return local notes `"`macval(notes)'"'
end

capture program drop _datadict_GetVariableChars
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_GetVariableChars, rclass
	version 16.0
	args vname

	local chars ""
	local allchars: char `vname'[]
	foreach cname of local allchars {
		if !regexm("`cname'", "^note[0-9]+$") {
			local cval: char `vname'[`cname']
			_datadict_EscapeMarkdown `"`macval(cval)'"'
			local escaped `"`r(escaped)'"'
			if `"`chars'"' == "" local chars `"`cname'=`macval(escaped)'"'
			else local chars `"`macval(chars)'<br>`cname'=`macval(escaped)'"'
		}
	}
	return local chars `"`macval(chars)'"'
end

capture program drop _datadict_ProcessCombined
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_ProcessCombined, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	local _fh_open = 0
	local _fh_names_open = 0
	local _fh_list_open = 0
	local _fh_names2_open = 0
	capture noisily {
			syntax, FILElist(string) NAMESFILE(string) OUtput(string) ///
				TItle(string asis) DATE(string) NFILES(integer) ///
				MAXCat(integer) MAXFreq(integer) MINCell(integer) ///
				UNIQCap(integer) ///
				DATEFormat(string) ///
				COLumns(string) [SUBTitle(string asis) VERsion(string) ///
				AUTHor(string asis) NOTEs(string asis) CHANGElog(string asis) ///
				MISSing STats VARSPEC(string asis) POSTNAME(name) DATASIGnature ///
				EXClude(string) CONTinuous(string) CATegorical(string) DATEVars(string)]

		foreach opt in title subtitle version author date notes changelog {
			local `opt' = subinstr(`"`macval(`opt')'"', char(34), "", .)
			local `opt' = subinstr(`"`macval(`opt')'"', char(96), "", .)
			local `opt' = subinstr(`"`macval(`opt')'"', char(39), "", .)
		}

		tempname fh
		quietly file open `fh' using `"`output'"', write text replace
		local _fh_open = 1

		file write `fh' `"# `macval(title)'"' _n _n
		if `"`subtitle'"' != "" file write `fh' `"`macval(subtitle)'"' _n _n
		if `"`version'"' != "" file write `fh' `"Version `version'"' _n _n

		file write `fh' "## Table of Contents" _n _n
		tempname fh_names
		file open `fh_names' using `"`namesfile'"', read text
		local _fh_names_open = 1
		local i 0
		file read `fh_names' nameline
		while r(eof) == 0 {
			local ++i
			_datadict_ParseNameLine `"`macval(nameline)'"'
			local dsname `"`r(dsname)'"'
			_datadict_MakeAnchor `i' `"`dsname'"'
			local anchor = r(anchor)
			_datadict_FormatDisplayName `"`dsname'"'
			local dispname `"`r(dispname)'"'
			file write `fh' `"`i'. [`dispname'](#`anchor')"' _n
			file read `fh_names' nameline
		}
		file close `fh_names'
		local _fh_names_open = 0

		local notesidx = `nfiles' + 1
		local chlogidx = `nfiles' + 2
		file write `fh' `"`notesidx'. [Notes](#notes)"' _n
		file write `fh' `"`chlogidx'. [Change Log](#change-log)"' _n
		file write `fh' _n _n

		tempname fh_list fh_names2
		file open `fh_list' using `"`filelist'"', read text
		local _fh_list_open = 1
		file open `fh_names2' using `"`namesfile'"', read text
		local _fh_names2_open = 1

		local nobs_total 0
		local nvars_total 0
		local postopt ""
		if "`postname'" != "" local postopt "postname(`postname')"
		local i 0
		file read `fh_list' filepath
		file read `fh_names2' nameline
		while r(eof) == 0 {
			local ++i
			_datadict_ParseNameLine `"`macval(nameline)'"'
			local dsname `"`r(dsname)'"'
			local dslabel `"`r(dslabel)'"'

					_datadict_ProcessOneDataset, handle(`fh') filepath(`"`macval(filepath)'"') ///
						dsname(`"`dsname'"') dslabel(`"`macval(dslabel)'"') idx(`i') ///
						maxcat(`maxcat') maxfreq(`maxfreq') mincell(`mincell') ///
						uniqcap(`uniqcap') ///
						exclude(`"`exclude'"') continuous(`"`continuous'"') ///
						categorical(`"`categorical'"') datevars(`"`datevars'"') ///
						dateformat("`dateformat'") ///
						columns(`columns') varspec(`"`varspec'"') output(`"`output'"') ///
						`datasignature' `postopt'
			local nobs_total = `nobs_total' + r(nobs)
			local nvars_total = `nvars_total' + r(nvars)

			file read `fh_list' filepath
			file read `fh_names2' nameline
		}
		file close `fh_list'
		local _fh_list_open = 0
		file close `fh_names2'
		local _fh_names2_open = 0

		file write `fh' "## Notes" _n _n
		_datadict_WriteTextBlock, handle(`fh') kind("notes") ///
			dateformat("`dateformat'") text(`"`notes'"')
		file write `fh' _n _n

		file write `fh' "## Change Log" _n _n
		_datadict_WriteTextBlock, handle(`fh') kind("changelog") ///
			dateformat("`dateformat'") text(`"`changelog'"')
		file write `fh' _n _n

		if `"`version'"' != "" file write `fh' `"**Document Version:** `version'"' _n _n
		if `"`author'"' != "" file write `fh' `"**Author:** `macval(author)'"' _n _n
		file write `fh' `"**Last Updated:** `date'"' _n

		file close `fh'
		local _fh_open = 0
		di as result `"Output written to: `output'"'

		return scalar nobs_total = `nobs_total'
		return scalar nvars_total = `nvars_total'
		return local output `"`output'"'
		return local outputs `"`output'"'
	}
	local rc = _rc
	if `_fh_names_open' {
		capture file close `fh_names'
		local _close_names_rc = _rc
	}
	if `_fh_list_open' {
		capture file close `fh_list'
		local _close_list_rc = _rc
	}
	if `_fh_names2_open' {
		capture file close `fh_names2'
		local _close_names2_rc = _rc
	}
	if `_fh_open' {
		capture file close `fh'
		local _close_rc = _rc
	}
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

capture program drop _datadict_ProcessSeparate
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_ProcessSeparate, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	local _fh_list_open = 0
	local _fh_names_open = 0
	local _fh_open = 0
	capture noisily {
			syntax, FILElist(string) NAMESFILE(string) TItle(string asis) ///
				DATE(string) NFILES(integer) MAXCat(integer) MAXFreq(integer) ///
				UNIQCap(integer) ///
				MINCell(integer) DATEFormat(string) COLumns(string) SUFfix(string) ///
				[SUBTitle(string asis) VERsion(string) AUTHor(string asis) ///
				NOTEs(string asis) CHANGElog(string asis) MISSing STats ///
				VARSPEC(string asis) OUTDir(string) POSTNAME(name) DATASIGnature ///
				EXClude(string) CONTinuous(string) CATegorical(string) DATEVars(string)]

		foreach opt in title subtitle version author date notes changelog {
			local `opt' = subinstr(`"`macval(`opt')'"', char(34), "", .)
			local `opt' = subinstr(`"`macval(`opt')'"', char(96), "", .)
			local `opt' = subinstr(`"`macval(`opt')'"', char(39), "", .)
		}

		tempname fh_list fh_names
		file open `fh_list' using `"`filelist'"', read text
		local _fh_list_open = 1
		file open `fh_names' using `"`namesfile'"', read text
		local _fh_names_open = 1

		local outputs ""
		local nobs_total 0
		local nvars_total 0
		local postopt ""
		if "`postname'" != "" local postopt "postname(`postname')"
		file read `fh_list' filepath
		file read `fh_names' nameline
		while r(eof) == 0 {
			_datadict_ParseNameLine `"`macval(nameline)'"'
			local dsname `"`r(dsname)'"'
			local dslabel `"`r(dslabel)'"'

			_datadict_DeriveSeparateOutput, filepath(`"`macval(filepath)'"') ///
				dsname(`"`dsname'"') suffix(`"`suffix'"') outdir(`"`outdir'"')
			local outfile `"`r(output)'"'
			_datadict_ValidatePath `"`outfile'"', option("separate output path")

			tempname fh
			quietly file open `fh' using `"`outfile'"', write text replace
			local _fh_open = 1

			file write `fh' `"# `macval(title)': `dsname'"' _n _n
			if `"`subtitle'"' != "" file write `fh' `"`macval(subtitle)'"' _n _n
			if `"`version'"' != "" file write `fh' `"Version `version'"' _n _n
			file write `fh' _n

				_datadict_ProcessOneDataset, handle(`fh') filepath(`"`macval(filepath)'"') ///
					dsname(`"`dsname'"') dslabel(`"`macval(dslabel)'"') idx(1) ///
					maxcat(`maxcat') maxfreq(`maxfreq') mincell(`mincell') ///
					uniqcap(`uniqcap') ///
					exclude(`"`exclude'"') continuous(`"`continuous'"') ///
					categorical(`"`categorical'"') datevars(`"`datevars'"') ///
					dateformat("`dateformat'") ///
					columns(`columns') varspec(`"`varspec'"') output(`"`outfile'"') ///
					`datasignature' `postopt'
			local nobs_total = `nobs_total' + r(nobs)
			local nvars_total = `nvars_total' + r(nvars)

			file write `fh' "## Notes" _n _n
			_datadict_WriteTextBlock, handle(`fh') kind("notes") ///
				dateformat("`dateformat'") text(`"`notes'"')
			file write `fh' _n _n

			file write `fh' "## Change Log" _n _n
			_datadict_WriteTextBlock, handle(`fh') kind("changelog") ///
				dateformat("`dateformat'") text(`"`changelog'"')
			file write `fh' _n _n

			if `"`version'"' != "" file write `fh' `"**Document Version:** `version'"' _n _n
			if `"`author'"' != "" file write `fh' `"**Author:** `macval(author)'"' _n _n
			file write `fh' `"**Last Updated:** `date'"' _n

			file close `fh'
			local _fh_open = 0
			di as result `"Output written to: `outfile'"'

			if `"`outputs'"' == "" local outputs `"`outfile'"'
			else local outputs `"`macval(outputs)';`outfile'"'

			file read `fh_list' filepath
			file read `fh_names' nameline
		}
		file close `fh_list'
		local _fh_list_open = 0
		file close `fh_names'
		local _fh_names_open = 0

		return scalar nobs_total = `nobs_total'
		return scalar nvars_total = `nvars_total'
		return local output `"`macval(outputs)'"'
		return local outputs `"`macval(outputs)'"'
	}
	local rc = _rc
	if `_fh_open' {
		capture file close `fh'
		local _close_rc = _rc
	}
	if `_fh_list_open' {
		capture file close `fh_list'
		local _close_list_rc = _rc
	}
	if `_fh_names_open' {
		capture file close `fh_names'
		local _close_names_rc = _rc
	}
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

capture program drop _datadict_ProcessOneDataset
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datadict_ProcessOneDataset, rclass
	version 16.0
	local _varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
			syntax, HANDLE(name) FILEPATH(string asis) DSName(string asis) ///
				IDX(integer) MAXCat(integer) MAXFreq(integer) MINCell(integer) ///
				UNIQCap(integer) ///
				DATEFormat(string) ///
				COLumns(string) [DSLABEL(string asis) VARSPEC(string asis) ///
				OUtput(string asis) POSTNAME(name) DATASIGnature ///
				EXClude(string) CONTinuous(string) CATegorical(string) DATEVars(string)]

		local filepath = subinstr(`"`macval(filepath)'"', char(34), "", .)
		local filepath = subinstr(`"`macval(filepath)'"', char(96), "", .)
		local filepath = subinstr(`"`macval(filepath)'"', char(39), "", .)
		local output = subinstr(`"`macval(output)'"', char(34), "", .)
		local output = subinstr(`"`macval(output)'"', char(96), "", .)
		local output = subinstr(`"`macval(output)'"', char(39), "", .)
		local varspec = subinstr(`"`macval(varspec)'"', char(34), "", .)
		local varspec = subinstr(`"`macval(varspec)'"', char(96), "", .)
		local varspec = subinstr(`"`macval(varspec)'"', char(39), "", .)
		local dsname = subinstr(`"`macval(dsname)'"', char(34), "", .)
		local dsname = subinstr(`"`macval(dsname)'"', char(96), "", .)
		local dsname = subinstr(`"`macval(dsname)'"', char(39), "", .)
		local dslabel = subinstr(`"`macval(dslabel)'"', char(34), "", .)
		local dslabel = subinstr(`"`macval(dslabel)'"', char(96), "", .)
		local dslabel = subinstr(`"`macval(dslabel)'"', char(39), "", .)

		capture quietly describe using `"`macval(filepath)'"', short
		if _rc != 0 {
			local _drc = _rc
			noisily di as error `"ERROR: Could not describe dataset `filepath'"'
			exit `_drc'
		}
		local obs = r(N)
		local nvars_file = r(k)
		if `"`dslabel'"' == "" | `"`dslabel'"' == "." {
			local dslabel "Dataset containing `nvars_file' variables and `obs' observations."
		}

			tempfile classifications
			// cap must clear maxcat, or a censored count could misclassify.
			// uniqcap(0) = exact counts.  Otherwise the cap must clear maxcat and
			// maxfreq, or a censored count could misclassify or hide a table.
			if `uniqcap' == 0 local nuniq_cap = 0
			else local nuniq_cap = max(`uniqcap', `maxcat', `maxfreq')
			_datamap_classify using `"`macval(filepath)'"', saving("`classifications'") ///
				maxcat(`maxcat') obs(`obs') exclude(`"`exclude'"') ///
				continuous(`"`continuous'"') categorical(`"`categorical'"') ///
				date(`"`datevars'"') cap(`nuniq_cap')
			local allvars "`r(all_vars)'"
			local categorical_vars "`r(categorical_vars)'"
			local continuous_vars "`r(continuous_vars)'"
			local date_vars "`r(date_vars)'"
			local string_vars "`r(string_vars)'"
			local excluded_vars "`r(excluded_vars)'"

		if `"`varspec'"' != "" {
			capture unab selected_vars : `varspec'
			if _rc {
				local _vrc = _rc
				noisily di as error `"varlist not found in `filepath': `varspec'"'
				exit `_vrc'
				}
				local allvars "`selected_vars'"
			}
			local docvars ""
			foreach vn of local allvars {
				if !`: list vn in excluded_vars' local docvars "`docvars' `vn'"
			}
			local allvars "`docvars'"
			local nvars_doc: word count `allvars'
			if `nvars_doc' == 0 {
			noisily di as error `"no variables selected in `filepath'"'
			exit 102
		}

		local dsignature ""
		if "`datasignature'" != "" {
			quietly datasignature
			local dsignature `"`r(datasignature)'"'
		}

		_datadict_FileSize `"`macval(filepath)'"'
		local filesize = r(bytes)
		if missing(`filesize') local filesizestr "unavailable"
		else local filesizestr = strtrim(string(`filesize', "%15.0fc")) + " bytes"

		local dispname = proper(subinstr(`"`dsname'"', "_", " ", .))
		_datadict_EscapeMarkdown `"`macval(dslabel)'"'
		local dslabel_safe `"`r(escaped)'"'
		_datadict_EscapeMarkdown `"`macval(filepath)'"'
		local filepath_safe `"`r(escaped)'"'

		file write `handle' `"## `idx'. `dispname'"' _n _n
		file write `handle' `"**Filename:** \``dsname'.dta\`  "' _n
		file write `handle' `"**Source path:** \``macval(filepath_safe)'\`  "' _n
		file write `handle' `"**Description:** `macval(dslabel_safe)'  "' _n
		file write `handle' `"**Observations:** `obs'  "' _n
		file write `handle' `"**Variables in file:** `nvars_file'  "' _n
		file write `handle' `"**Variables documented:** `nvars_doc'  "' _n
		file write `handle' `"**File size:** `filesizestr'  "' _n
		if "`datasignature'" != "" {
			file write `handle' `"**Data signature:** \``dsignature'\`  "' _n
		}
		file write `handle' _n

			file write `handle' "### Variables" _n _n
			_datadict_WriteTableHeader, handle(`handle') columns(`columns')
			local postopt ""
			if "`postname'" != "" local postopt "postname(`postname')"

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
				_datadict_WriteVariableRow, handle(`handle') vname(`vn') obs(`obs') ///
					columns(`columns') maxcat(`maxcat') maxfreq(`maxfreq') ///
						uniqcap(`nuniq_cap') ///
						mincell(`mincell') dateformat("`dateformat'") varclass("`varclass'") ///
						source(`"`macval(filepath)'"') output(`"`output'"') ///
						dsname(`"`dsname'"') dslabel(`"`macval(dslabel)'"') ///
						nvars(`nvars_file') datasignature(`"`dsignature'"') `postopt'
		}

		file write `handle' _n _n
		return scalar nobs = `obs'
		return scalar nvars = `nvars_doc'
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end
