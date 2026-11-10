*! datamap Version 2.0.0  2026/11/10
*! Generate privacy-safe LLM-readable dataset documentation
*! Author: Timothy P Copeland, Karolinska Institutet

/*
SYNTAX
------
datamap [varlist] [, options]

Input (one at most; none = the data in memory):
  single(file)        one .dta file (the extension is optional)
  directory(path)     every .dta file in a directory   [recursive]
  filelist(names)     a list of datasets
  manifest(file)      a text file naming one dataset per line
  varlist             only with the data in memory or single()

Output (Markdown is the only file format):
  output(file)        the document (default datamap.md)
  separate            one document per dataset: <dataset><suffix>.md beside
                      it, or in outdir(); suffix() defaults to _map
  append              add the dataset sections to output(); refused with the
                      document options and with separate
  saving(file[, replace csv])   the variable-level metadata table (.dta);
                      csv also writes it as <file>.csv (2.0.0)
  config(file)        project defaults (key = value lines)

Document (written only when given): title() subtitle() version() author()
  docdate() notes() changelog()

Content: columns() compact nostats nofreq nolabels maxfreq(25) maxcat(25)
  uniqcap(1000) mincell(5)
Privacy: exclude(varlist|auto) datesafe dateformat() safe
  exclude(auto): the likely identifiers (r(suggested_exclude)) are withheld;
  names may stand beside auto
  safe: mincell(5) or more, datesafe, exclude(auto), no listed values of
  text above maxcat() or holding a digit, samples() refused (U2)
Classification: continuous() categorical() date()
Structure: detect() autodetect panelid() survivalvars()
Quality: quality quality(strict) missing(detail|pattern) samples()
  placeholders(numlist)  declared placeholder values, listed with the
  placeholder dates under "Candidates (not applied)"; requires quality

Removed in 2.0.0: format() (Markdown only; it stops with a pointer to
saving()), datevars() (stops with a pointer to date()), noguidance, and
datadict's bare missing, stats, detail and datasignature (not in the syntax:
rc 198).  datadict itself is removed; date() is a varlist and the document
date is docdate().

DESIGN
------
Collect once, render once.  Each dataset is loaded once and collected into
three frames (_datamap_collect_dataset, _datamap_post_metadata_rows,
_datamap_collect_levels); the Markdown document (_datamap_md_document) and
saving() read only those frames, so the file and the metadata table cannot
disagree.  Facts that need the data and are not per-variable (detected
structure, missing-value patterns, sample rows) are written as Markdown
fragments into the datasets frame while the dataset is loaded
(_datamap_md_sections).

File-based input preserves and restores the current dataset.  In-memory runs
take no snapshot: successful runs leave the data unchanged, but failures are
not rolled back.

STORED RESULTS
--------------
r(nfiles) r(nobs) r(nvars) r(mincell) r(n_categorical) r(n_continuous)
r(n_date) r(n_string) r(n_excluded) r(n_suggested_exclude)
r(output) (combined) r(outputs) r(files) r(mode) r(input_source)
r(categorical_vars) r(continuous_vars) r(date_vars) r(string_vars)
r(excluded_vars) r(suggested_exclude) r(metadata) (saving())
r(metadata_csv) (saving(, csv))

With two or more datasets in one document (not separate or append), a
Linkage section follows the datasets (F1, _datamap_md_document).
*/

program define datamap, rclass
	version 16.0
    local _legacy_globals : all globals
    foreach g in S_1 S_FN S_FNDATE {
        local _had_`g' : list g in _legacy_globals
        mata: st_local("_old_" + st_local("g"), st_global(st_local("g")))
        // in Mata: a saved value ending in an unmatched ` (S_FNDATE keeps
        // only 17 characters) opened a compound quote here, r(132)
        mata: st_local("_had_" + st_local("g"), strofreal(st_local("_had_" + st_local("g")) == "1" | st_local("_old_" + st_local("g")) != ""))
    }

	local _varabbrev = c(varabbrev)
	set varabbrev off
	local _restore_needed = 0
	// the collector frames (datasets, variables, levels): tempnames, so
	// Stata drops them when datamap ends; the cleanup zone drops them too
	local _fds_open = 0
	local _fvar_open = 0
	local _flev_open = 0
	tempname _dm_fds _dm_fvar _dm_flev
	// the input list's read handles (separate's destinations, the collection)
	local _fhl_open = 0
	local _fhc_open = 0
	tempname _fhl _fhc
	local _cmdline : copy local 0
	capture noisily {
		syntax [anything(name=varspec id="varlist")] [, ///
			DIRectory(string) FILElist(string asis) SINGLE(string) ///
			MANifest(string) RECursive ///
			Output(string) OUTDir(string) SUFfix(string) SEParate APPend ///
			SAVing(string) CONFig(string) ///
			TItle(string) SUBTitle(string) VERsion(string) AUTHor(string) ///
			DOCDate(string) NOTEs(string) CHANGElog(string) ///
			COLumns(string asis) COMpact NOSTats NOFReq NOLAbels ///
			MAXFreq(integer -999999999) MAXCat(integer -999999999) ///
			MINCell(integer -999999999) UNIQCap(integer -999999999) ///
			EXClude(string) CONTinuous(string) CATegorical(string) date(string) ///
			DATESafe DATEFormat(string) ///
			DETect(string) AUTODETect PANELid(string) SURVIVALvars(string) ///
			QUality QUality2(string) SAMples(integer -999999999) MISSing(string) ///
			PLACEholders(numlist) SAFE Format(string) DATEVars(string)]

		// format() and datevars() with empty parentheses parse as not given;
		// _datamap_emptyopts finds them in the command line
		local _fmt_empty = 0
		local _dv_empty = 0
		mata: st_local("_emptyo", _datamap_emptyopts(st_local("_cmdline")))
		foreach _eo of local _emptyo {
			if strpos("format", "`_eo'") == 1 local _fmt_empty = 1
			if strlen("`_eo'") >= 5 & strpos("datevars", "`_eo'") == 1 local _dv_empty = 1
		}

		// 2.0.0: Markdown is the only file format
		if `"`format'"' != "" | `_fmt_empty' {
			noisily di as error "format() was removed in 2.0.0: datamap writes Markdown; use saving() for a machine-readable table"
			exit 198
		}
		// Removed options (2.0.0, 2026-11-10).  format() and datevars() are
		// parsed only to stop with a pointer: datevars() was datadict's name
		// for date().  date() is datamap's varlist; a datadict document date
		// in it matches no variable and stops rc 198 with a docdate()
		// pointer (_datamap_classify, precheck).  noguidance, bare missing,
		// stats, detail and datasignature are not in the syntax and stop
		// there (rc 198): no replacement option exists (guidance prose is
		// gone; missing and statistics are default columns; columns() names
		// datadict's detail columns; the data signature is always printed).
		if `"`datevars'"' != "" | `_dv_empty' {
			noisily di as error "datevars() was removed in 2.0.0: use date() to classify variables as dates"
			exit 198
		}

		// The document options travel encoded ($, `, line breaks), so no
		// macro or quote syntax in their text is read on the way to the
		// writer; _datamap_md_document decodes them (datadict's transport)
		foreach opt in title subtitle version author docdate notes changelog {
			mata: st_local("`opt'", _datamap_transport_encode(st_local("`opt'")))
		}

		// typed on the command line, before config() can set them (safe)
		local _samp_cmd = (`samples' != -999999999)
		if `"`config'"' != "" {
			_datamap_validate_path `"`macval(config)'"', option("config()")
			confirm file `"`config'"'
			_datamap_load_config, config(`"`config'"')
			// read through Mata: a config value is data, and `r(...)' would
			// expand a $name or `name' inside it
			mata: st_local("_cfgfmt", st_global("r(format)"))
			if `"`_cfgfmt'"' != "" {
				noisily di as error "config(): the format key was removed in 2.0.0: datamap writes Markdown; use saving() for a machine-readable table"
				exit 198
			}
			// datadict's missing = yes|no column switch (2026-11-10: it
			// stopped with missing()'s detail|pattern message, which named
			// no config key); missing = detail|pattern is datamap's
			mata: st_local("_cfgmis", strlower(strtrim(st_global("r(missing)"))))
			if `"`missing'"' == "" & inlist(`"`_cfgmis'"', "1", "yes", "true", "on", "missing", "0", "no", "false", "off") {
				noisily di as error `"config(): missing = `_cfgmis' was datadict's Missing-column switch, removed in 2.0.0: the Missing column is always printed (columns() leaves it out); missing = detail or missing = pattern adds the missingness section"'
				exit 198
			}
			foreach opt in output outdir suffix exclude continuous categorical ///
				detect panelid survivalvars missing dateformat columns {
				mata: st_local("cfgval", st_global("r(`opt')"))
				if `"``opt''"' == "" & `"`cfgval'"' != "" {
					local `opt' `"`cfgval'"'
				}
			}
			foreach opt in title subtitle version author notes changelog docdate {
				mata: st_local("cfgval", st_global("r(`opt')"))
				mata: st_local("_cfgset", strofreal(st_local("`opt'") == "" & st_local("cfgval") != ""))
				if `_cfgset' mata: st_local("`opt'", _datamap_transport_encode(st_local("cfgval")))
			}
			if `"`date'"' == "" & `"`r(datevars)'"' != "" local date `"`r(datevars)'"'
			foreach opt in maxfreq maxcat mincell samples uniqcap {
				if ``opt'' == -999999999 & `"`r(`opt')'"' != "" local `opt' = real(`"`r(`opt')'"')
			}
			foreach opt in nostats nofreq nolabels datesafe compact autodetect {
				if "``opt''" == "" & "`r(`opt')'" != "" local `opt' "`opt'"
			}
		}
		// safe (2.0.0, U2): the agent-safe preset -- mincell(5) or more,
		// datesafe, exclude(auto), and no listed values of text above
		// maxcat() distinct values or holding a digit; samples() prints rows
		// and is refused.  dataqa set agent turns it on for the session.  It
		// covers the document and saving(); r() is not masked.
		if "`safe'" == "" & `"$DATAMAP_DQ"' != "" {
			_datamap_dqdefaults
			if r(safe) local safe "safe"
		}
		local _safe = ("`safe'" != "")
		if `_safe' {
			local datesafe "datesafe"
			if !`: list posof "auto" in exclude' local exclude `"`exclude' auto"'
		}
		// exclude(auto) (2.0.0 U5): the token auto withholds every variable
		// r(suggested_exclude) would name (_datamap_classify, autoexclude);
		// other tokens may stand beside it.  The token stays in the list, so
		// a variable named auto is withheld too; the precheck does not see
		// it, as it is not a name to match.
		local _autoex = 0
		local _exuser ""
		foreach _etok of local exclude {
			if `"`_etok'"' == "auto" local _autoex = 1
			else local _exuser `"`_exuser' `_etok'"'
		}
		local _exuser = strtrim(`"`_exuser'"')
		if `maxfreq' == -999999999 local maxfreq = 25
		if `maxcat' == -999999999 local maxcat = 25
		if `mincell' == -999999999 local mincell = 5
		if `samples' == -999999999 local samples = 0
		if `uniqcap' == -999999999 local uniqcap = 1000
		// a config() value is read with real(): 2.5 passed on as
		// mincell(2.5) failed later with a bare syntax error
		foreach opt in maxfreq maxcat mincell samples uniqcap {
			if !missing(``opt'') & ``opt'' != floor(``opt'') {
				noisily di as error "`opt'() must be an integer"
				exit 198
			}
		}
		if `maxfreq' <= 0 | missing(`maxfreq') {
			noisily di as error "maxfreq must be positive"
			exit 198
		}
		if `maxcat' <= 0 | missing(`maxcat') {
			noisily di as error "maxcat must be positive"
			exit 198
		}
		if `mincell' < 0 | missing(`mincell') {
			noisily di as error "mincell must be non-negative"
			exit 198
		}
		if `samples' < 0 | missing(`samples') {
			noisily di as error "samples must be non-negative"
			exit 198
		}
		if `uniqcap' < 0 | missing(`uniqcap') {
			noisily di as error "uniqcap must be non-negative (0 = exact counts, no cap)"
			exit 198
		}
		if `_safe' {
			if `samples' > 0 & `_samp_cmd' {
				noisily di as error "samples() prints rows of data; it cannot be combined with safe"
				exit 198
			}
			if `samples' > 0 noisily di as text "note: safe ignores the config() samples key (sample rows are row-level data)"
			local samples = 0
			if `mincell' < 5 {
				noisily di as text "note: safe raises mincell(`mincell') to 5"
				local mincell = 5
			}
		}

		// Set default date format (ISO 8601: YYYY/MM/DD)
		if `"`dateformat'"' == "" local dateformat "%tdCCYY/NN/DD"
		if strpos(`"`dateformat'"', "%t") != 1 & strpos(`"`dateformat'"', "%d") != 1 {
			noisily di as error "dateformat() must be a Stata date/time display format beginning with %t or %d"
			exit 198
		}

		// the document options: a title block, contents and footer are
		// written only when one of them is given
		mata: st_local("_docmode", strofreal(st_local("title") + st_local("subtitle") + ///
			st_local("version") + st_local("author") + st_local("docdate") + ///
			st_local("notes") + st_local("changelog") != ""))

		// Validate mutually exclusive input options (only one allowed)
		// filelist() is -asis-: plain -string- stripped the quotes around a
		// name containing spaces, so filelist("my dir/a") read as two names.
		local ninput = ("`directory'" != "") + (`"`filelist'"' != "") + ///
			("`single'" != "") + (`"`manifest'"' != "")
		if `ninput' > 1 {
			noisily di as error "specify only one of directory(), filelist(), manifest(), or single()"
			exit 198
		}
		// recursive scans directory(); with any other input it did nothing
		if "`recursive'" != "" & "`directory'" == "" {
			noisily di as error "recursive requires directory()"
			exit 198
		}
		if `"`single'"' != "" _datamap_validate_path `"`single'"', option("single()")
		if `"`directory'"' != "" _datamap_validate_path `"`directory'"', option("directory()")
		if `"`manifest'"' != "" {
			_datamap_validate_path `"`manifest'"', option("manifest()")
			confirm file `"`manifest'"'
		}
		if `"`varspec'"' != "" & `ninput' > 0 & `"`single'"' == "" {
			noisily di as error "varlist is allowed only with data in memory or single()"
			exit 198
		}

		// separate writes a new file per dataset; append adds dataset
		// sections to one existing file, so it has no document parts
		if "`append'" != "" & "`separate'" != "" {
			noisily di as error "append cannot be combined with separate"
			exit 198
		}
		if "`append'" != "" & `_docmode' {
			noisily di as error "append adds dataset sections only; it cannot be combined with title(), subtitle(), version(), author(), docdate(), notes(), or changelog()"
			exit 198
		}

		// the table's columns (compact: the preset)
		_datamap_md_columns, columns(`macval(columns)') `compact'
		local columns "`r(columns)'"
		local _needlev = (strpos(" `columns' ", " values ") > 0 & "`nofreq'" == "")

		// output names
		if "`separate'" == "" {
			if `"`output'"' == "" local output "datamap.md"
			_datamap_validate_path `"`output'"', option("output()")
		}
		else {
			if `"`suffix'"' == "" local suffix "_map"
			if `"`outdir'"' != "" _datamap_validate_path `"`outdir'"', option("outdir()")
		}

		local saving_file ""
		local saving_replace 0
		local result_metadata ""
		if `"`saving'"' != "" {
			local saving_spec = subinstr(`"`macval(saving)'"', char(34), "", .)
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
			// csv (2.0.0 I2): a comma-separated copy beside the .dta.  The
			// suboptions are replace and csv; anything else stops here
			// (2026-11-10: an unknown suboption was ignored)
			local saving_csv = 0
			local _svtoks = subinstr(lower(`"`macval(saving_rest)'"'), ",", " ", .)
			foreach _svt of local _svtoks {
				if "`_svt'" == "csv" local saving_csv = 1
				else if "`_svt'" != "replace" {
					noisily di as error `"saving(): unknown suboption `_svt'; the suboptions are replace and csv"'
					exit 198
				}
			}
			_datamap_validate_path `"`macval(saving_file)'"', option("saving()")
			// -save- adds .dta to a name with no suffix; the existence check
			// must test that name, or a second run wrote its report and
			// then failed r(602) at the save
			mata: st_local("_sext", pathsuffix(st_local("saving_file")))
			if `"`_sext'"' == "" local saving_file `"`saving_file'.dta"'
			if !`saving_replace' confirm new file `"`saving_file'"'
			if `saving_csv' {
				if lower(`"`_sext'"') == ".dta" | `"`_sext'"' == "" {
					local saving_csvfile = substr(`"`saving_file'"', 1, strlen(`"`saving_file'"') - 4) + ".csv"
				}
				else local saving_csvfile `"`saving_file'.csv"'
				_datamap_validate_path `"`macval(saving_csvfile)'"', option("saving(, csv)")
				if !`saving_replace' confirm new file `"`saving_csvfile'"'
			}
		}

		// Parse and validate detect() option
		local detect_panel 0
		local detect_binary 0
		local detect_survival 0
		local detect_survey 0
		local detect_common 0
		// autodetect: every detector except the binary line, which prints
		// only when detect(binary) asks for it (2026-11-10: the 1.x binary
		// section is gone, O2; the line under autodetect was its remnant)
		if "`autodetect'" != "" {
			local detect_panel 1
			local detect_survival 1
			local detect_survey 1
			local detect_common 1
		}
		if "`detect'" != "" {
			local detect_opts "`detect'"
			while "`detect_opts'" != "" {
				gettoken opt detect_opts : detect_opts, parse(" ")
				if "`opt'" == "panel" local detect_panel 1
				else if "`opt'" == "binary" local detect_binary 1
				else if "`opt'" == "survival" local detect_survival 1
				else if "`opt'" == "survey" local detect_survey 1
				else if "`opt'" == "common" local detect_common 1
				else if "`opt'" != "" {
					noisily di as error "detect() option '`opt'' not recognized"
					noisily di as error "Valid options: panel, binary, survival, survey, common"
					exit 198
				}
			}
		}

		// Parse quality option
		local quality_level ""
		if "`quality'" != "" local quality_level "basic"
		if "`quality2'" != "" {
			if "`quality2'" == "strict" local quality_level "strict"
			else {
				noisily di as error "quality() must be 'strict' if specified"
				exit 198
			}
		}

		// placeholders() (2.0.0 F5): the declared values are candidates in the
		// quality section, which only quality prints
		if "`placeholders'" != "" & "`quality_level'" == "" {
			noisily di as error "placeholders() requires quality: the candidates are listed in the quality section"
			exit 198
		}

		// Parse missing option
		local missing_detail 0
		local missing_pattern 0
		if "`missing'" != "" {
			if "`missing'" == "detail" local missing_detail 1
			else if "`missing'" == "pattern" {
				local missing_detail 1
				local missing_pattern 1
			}
			else {
				noisily di as error "missing() must be 'detail' or 'pattern'"
				exit 198
			}
		}

		// Preserve the current dataset ONLY when this run loads files into
		// memory (single/directory/filelist/manifest): -use- replaces the
		// user's data and only -restore- puts it back.  Documenting the data
		// already in memory does not need it: nothing on that path replaces
		// the dataset, and a -preserve- is a full second copy of it.
		if `ninput' > 0 {
			preserve
			local _restore_needed = 1
		}

		// If no input specified, document data currently in memory
		local input_source ""
		if `ninput' == 0 {
			// A dataset with variables but no observations is documentable
			// (structure only), as single() already allowed.
			if c(k) == 0 {
				noisily di as error "no data in memory and no input specified"
				noisily di as error "specify directory(), filelist(), manifest(), single(), or load data first"
				exit 198
			}
			tempfile memdata
			_datamap_memshell `"`memdata'"'
			local single "`memdata'"
			local input_source "memory"
		}
		else if "`single'" != "" local input_source "single"
		else if "`directory'" != "" local input_source "directory"
		else if `"`manifest'"' != "" local input_source "manifest"
		else local input_source "filelist"
		local result_mode "`input_source'"
		if "`input_source'" == "directory" & "`recursive'" != "" local result_mode "directory_recursive"

		// Collect files to process based on input method
		tempfile filelist_tmp
		if "`single'" != "" {
			if "`input_source'" != "memory" {
				if !regexm(lower(`"`single'"'), "\.dta$") local single `"`single'.dta"'
			}
			confirm file `"`single'"'
			local nfiles 1
			tempname fh_tmp
			quietly file open `fh_tmp' using `"`filelist_tmp'"', write text replace
			file write `fh_tmp' `"`single'"' _n
			file close `fh_tmp'
		}
		else if `"`filelist'"' != "" {
			_datamap_collect_filelist `"`filelist'"' `"`filelist_tmp'"'
			_datamap_count_files `"`filelist_tmp'"'
			local nfiles = r(nfiles)
		}
		else if `"`manifest'"' != "" {
			_datamap_md_manifest, manifest(`"`manifest'"') saving(`"`filelist_tmp'"')
			local nfiles = r(nfiles)
		}
		else {
			if "`directory'" == "" local directory "."
			_datamap_collect_from_dir `"`directory'"' "`recursive'" `"`filelist_tmp'"'
			_datamap_count_files `"`filelist_tmp'"'
			local nfiles = r(nfiles)
		}
		if `nfiles' == 0 {
			noisily di as error "no .dta files found"
			exit 601
		}

		// r(files): the datasets read, ";"-separated
		if "`input_source'" == "memory" local result_files "memory"
		else mata: st_local("result_files", invtokens(cat(st_local("filelist_tmp"))', ";"))

		local memoryopt ""
		if "`input_source'" == "memory" local memoryopt "memory"

		// exclude() against every file before any output is written: an
		// unresolvable range errors here, and a token matching no variable
		// in any file gets a note (see _datamap_classify, precheck).
		// continuous(), categorical(), and date() tokens are checked there
		// too: one that names no variable in any file is an error.
		if `"`_exuser'`continuous'`categorical'`date'"' != "" {
			_datamap_classify using `"`filelist_tmp'"', precheck ///
				exclude(`"`_exuser'"') continuous(`"`continuous'"') ///
				categorical(`"`categorical'"') date(`"`date'"') `memoryopt'
		}

		// Every destination before any dataset is read: separate refuses two
		// datasets writing one file; an unwritable path fails here
		// (_datamap_stage check), not after the collection
		local result_outputs ""
		if "`separate'" != "" {
			file open `_fhl' using `"`filelist_tmp'"', read text
			local _fhl_open = 1
			local _i = 0
			file read `_fhl' _fp
			while r(eof) == 0 {
				local ++_i
				_datamap_md_outname, filepath(`"`_fp'"') suffix(`"`suffix'"') ///
					outdir(`"`outdir'"') `memoryopt'
				local _out`_i' `"`r(output)'"'
				_datamap_validate_path `"`_out`_i''"', option("separate output path")
				forvalues _j = 1/`=`_i' - 1' {
					if `"`_out`_i''"' == `"`_out`_j''"' {
						noisily di as error `"separate outputs collide: `_out`_i''"'
						exit 198
					}
				}
				file read `_fhl' _fp
			}
			file close `_fhl'
			local _fhl_open = 0
			forvalues _i = 1/`nfiles' {
				_datamap_stage check `"`_out`_i''"'
			}
		}
		else _datamap_stage check `"`output'"'

		// F1 (2.0.0): the variable names two or more input datasets share,
		// read from each file's header before the collection; their
		// uniqueness per dataset is counted exactly when each is loaded
		// (_datamap_collect_link), and the linkage block lists them
		local _linkvars ""
		if `nfiles' >= 2 {
			file open `_fhl' using `"`filelist_tmp'"', read text
			local _fhl_open = 1
			// every file's names in one list (a name occurs once per file);
			// Mata keeps the names that occur twice or more (2026-11-10:
			// macro list operators cost 0.3 s on 15 files of 2,000 names)
			local _lkall ""
			file read `_fhl' _fp
			while r(eof) == 0 {
				capture quietly describe using `"`_fp'"', varlist
				if _rc == 0 local _lkall `"`_lkall' `r(varlist)'"'
				file read `_fhl' _fp
			}
			file close `_fhl'
			local _fhl_open = 0
			mata: st_local("_linkvars", _datamap_shared(st_local("_lkall")))
		}
		local _linkopt ""
		if `nfiles' >= 2 local _linkopt "multi"
		local _phopt ""
		if "`placeholders'" != "" local _phopt "placeholders(`placeholders')"

		// The collector frames
		_datamap_collect_dataset, create frame(`_dm_fds')
		local _fds_open = 1
		_datamap_post_metadata_rows, create frame(`_dm_fvar')
		local _fvar_open = 1
		_datamap_collect_levels, create frame(`_dm_flev')
		local _flev_open = 1

		// Collect: each dataset loaded once (_datamap_CollectDataset).
		// Without saving(), the variables rows hold the summaries the
		// document prints (reportonly; see _datamap_CollectDataset).
		local _rponly ""
		if `"`saving_file'"' == "" local _rponly "reportonly"
		local n_categorical = 0
		local n_continuous = 0
		local n_date = 0
		local n_string = 0
		local n_excluded = 0
		local n_suggested_exclude = 0
		foreach _L in categorical_vars continuous_vars date_vars string_vars excluded_vars suggested_exclude {
			local `_L' ""
		}
		file open `_fhc' using `"`filelist_tmp'"', read text
		local _fhc_open = 1
		local _i = 0
		file read `_fhc' _fp
		while r(eof) == 0 {
			local ++_i
			local _mdout `"`output'"'
			if "`separate'" != "" local _mdout `"`_out`_i''"'
			_datamap_CollectDataset, filepath(`"`_fp'"') ///
				dsframe(`_dm_fds') varframe(`_dm_fvar') levframe(`_dm_flev') ///
				maxfreq(`maxfreq') maxcat(`maxcat') mincell(`mincell') ///
				uniqcap(`uniqcap') dateformat(`"`dateformat'"') needlevels(`_needlev') ///
				mdout(`"`_mdout'"') varspec(`"`varspec'"') `memoryopt' ///
				exclude(`"`exclude'"') continuous(`"`continuous'"') ///
				categorical(`"`categorical'"') fdate(`"`date'"') ///
				`nostats' `datesafe' `_rponly' quality_level(`quality_level') ///
				detect_panel(`detect_panel') detect_binary(`detect_binary') ///
				detect_survival(`detect_survival') detect_survey(`detect_survey') ///
				detect_common(`detect_common') panelid(`panelid') ///
				survivalvars(`survivalvars') samples(`samples') ///
				missing_detail(`missing_detail') missing_pattern(`missing_pattern') ///
				autoex(`_autoex') linkvars(`_linkvars') `_linkopt' `_phopt' `safe'
			foreach _s in n_categorical n_continuous n_date n_string n_excluded n_suggested_exclude {
				local `_s' = ``_s'' + r(`_s')
			}
			foreach _L in categorical_vars continuous_vars date_vars string_vars excluded_vars suggested_exclude {
				local `_L' "``_L'' `r(`_L')'"
			}
			file read `_fhc' _fp
		}
		file close `_fhc'
		local _fhc_open = 0

		// Render: the document reads the frames only
		if `_docmode' {
			mata: st_local("_dd", st_local("docdate"))
			if `"`_dd'"' == "" mata: st_local("docdate", _datamap_transport_encode(c("current_date")))
		}
		local _docopt ""
		if `_docmode' local _docopt "docmode"
		foreach _o in nofreq nostats nolabels datesafe safe {
			if "``_o''" != "" local _docopt "`_docopt' `_o'"
		}
		if "`quality_level'" != "" local _docopt "`_docopt' quality"
		// the linkage block: two or more datasets in one document (not
		// separate, one file per dataset; not append, dataset sections only)
		local _lkdoc ""
		if `nfiles' >= 2 & "`append'" == "" local _lkdoc "linkage"
		if "`separate'" == "" {
			tempfile _stage
			if "`append'" != "" {
				capture confirm file `"`output'"'
				if _rc == 0 quietly copy `"`output'"' `"`_stage'"', replace
			}
			local _toc ""
			if "`append'" == "" & (`_docmode' | `nfiles' >= 2) local _toc "toc"
			_datamap_md_document using `"`_stage'"', dsframe(`_dm_fds') ///
				varframe(`_dm_fvar') levframe(`_dm_flev') dslist(1/`nfiles') ///
				columns(`columns') mincell(`mincell') maxfreq(`maxfreq') ///
				dateformat(`"`dateformat'"') `append' `_toc' `_docopt' `_lkdoc' ///
				title(`"`macval(title)'"') subtitle(`"`macval(subtitle)'"') ///
				version(`"`macval(version)'"') author(`"`macval(author)'"') ///
				docdate(`"`macval(docdate)'"') notes(`"`macval(notes)'"') ///
				changelog(`"`macval(changelog)'"')
			_datamap_stage commit `"`_stage'"' `"`output'"'
			noisily di as result `"Output written to: `output'"'
			local result_outputs `"`output'"'
		}
		else {
			forvalues _i = 1/`nfiles' {
				tempfile _stage`_i'
				_datamap_md_document using `"`_stage`_i''"', dsframe(`_dm_fds') ///
					varframe(`_dm_fvar') levframe(`_dm_flev') dslist(`_i') ///
					columns(`columns') mincell(`mincell') maxfreq(`maxfreq') ///
					dateformat(`"`dateformat'"') separate `_docopt' ///
					title(`"`macval(title)'"') subtitle(`"`macval(subtitle)'"') ///
					version(`"`macval(version)'"') author(`"`macval(author)'"') ///
					docdate(`"`macval(docdate)'"') notes(`"`macval(notes)'"') ///
					changelog(`"`macval(changelog)'"')
			}
			// every file is staged before the first is copied over its
			// destination: a failure leaves the previous outputs in place
			forvalues _i = 1/`nfiles' {
				_datamap_stage commit `"`_stage`_i''"' `"`_out`_i''"'
				noisily di as result `"Output written to: `_out`_i''"'
				if `_i' == 1 local result_outputs `"`_out`_i''"'
				else local result_outputs `"`result_outputs';`_out`_i''"'
			}
		}

		// saving(): the variables frame, as collected (written from a
		// frame of its own: the user's data in memory is never replaced)
		if `"`saving_file'"' != "" {
			local _svrep ""
			if `saving_replace' local _svrep "replace"
			_datamap_post_metadata_rows, frame(`_dm_fvar') ///
				savefile(`"`saving_file'"') `_svrep' `safe'
			local result_metadata `"`saving_file'"'
			// csv: the same table, comma-separated, every string quoted
			// (a cell may hold a comma, a quote or a line break), numbers at
			// full precision (import delimited reads it back)
			if `saving_csv' {
				_datamap_post_metadata_rows, frame(`_dm_fvar') ///
					savefile(`"`saving_csvfile'"') csv `_svrep' `safe'
				local result_metadata_csv `"`saving_csvfile'"'
			}
		}

		// observations and variables of a single dataset (single, memory)
		local nobs_total .
		local nvars_total .
		if "`single'" != "" {
			frame `_dm_fds': local nobs_total = N[1]
			frame `_dm_fds': local nvars_total = nvars[1]
		}

		// Restore original dataset (only if this run preserved one)
		if `_restore_needed' {
			restore
			local _restore_needed = 0
		}

		// Return results
		return scalar nfiles = `nfiles'
		if `nobs_total' < . {
			return scalar nobs = `nobs_total'
			return scalar nvars = `nvars_total'
		}
		// separate writes one file per dataset, never `output'
		if "`separate'" == "" return local output `"`output'"'
		return local outputs `"`macval(result_outputs)'"'
		return local files `"`macval(result_files)'"'
		return local mode "`result_mode'"
		return local input_source "`input_source'"
		return scalar mincell = `mincell'
		return scalar safe = `_safe'
		return scalar n_categorical = `n_categorical'
		return scalar n_continuous = `n_continuous'
		return scalar n_date = `n_date'
		return scalar n_string = `n_string'
		return scalar n_excluded = `n_excluded'
		return scalar n_suggested_exclude = `n_suggested_exclude'
		// Accumulated per dataset with a leading separator; return clean
		// lists so a string comparison does not trip on stray spaces.
		foreach _L in categorical_vars continuous_vars date_vars string_vars excluded_vars suggested_exclude {
			local `_L' : list retokenize `_L'
		}
		return local categorical_vars "`categorical_vars'"
		return local continuous_vars "`continuous_vars'"
		return local date_vars "`date_vars'"
		return local string_vars "`string_vars'"
		return local excluded_vars "`excluded_vars'"
		return local suggested_exclude "`suggested_exclude'"
		if `"`result_metadata'"' != "" {
			return local metadata `"`result_metadata'"'
		}
		if `"`result_metadata_csv'"' != "" {
			return local metadata_csv `"`result_metadata_csv'"'
		}

		di as text "Documentation generated successfully"
	}
	local rc = _rc
	if `_fhl_open' capture file close `_fhl'
	if `_fhc_open' capture file close `_fhc'
	if `_fds_open' capture frame drop `_dm_fds'
	if `_fvar_open' capture frame drop `_dm_fvar'
	if `_flev_open' capture frame drop `_dm_flev'
	if `_restore_needed' {
		capture restore
		local _restore_rc = _rc
		if !`rc' & `_restore_rc' local rc = `_restore_rc'
	}
    foreach g in S_1 S_FN S_FNDATE {
        // Mata, not -global-: a one-line -if- expands its command a second
        // time, so a saved value holding $name or `name' came back rewritten
        if `_had_`g'' mata: st_global(st_local("g"), st_local("_old_" + st_local("g")))
        else macro drop `g'
    }
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

// =============================================================================
// Helper: _datamap_CollectDataset
// Collect one dataset into the three frames (and its data-dependent Markdown
// fragments into the datasets frame); writes no output file
// =============================================================================
capture program drop _datamap_CollectDataset
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datamap_CollectDataset, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax, FILEpath(string) DSFrame(name) VARFrame(name) LEVFrame(name) ///
			MAXFreq(integer) MAXCat(integer) MINCell(integer) UNIQCap(integer) ///
			DATEFormat(string) NEEDLEVels(integer) ///
			[MEMory MDOUT(string) VARSPEC(string) ///
			EXClude(string) CONTinuous(string) CATegorical(string) FDATE(string) ///
			NOSTats DATESafe REPORTonly quality_level(string) ///
			detect_panel(integer 0) detect_binary(integer 0) ///
			detect_survival(integer 0) detect_survey(integer 0) ///
			detect_common(integer 0) PANELid(string) SURVIVALvars(string) ///
			SAMples(integer 0) missing_detail(integer 0) missing_pattern(integer 0) ///
			AUTOEX(integer 0) LINKVars(string) MULTi PLACEholders(numlist) SAFE]

		// memory mode: `filepath' is a zero-observation shell of the loaded
		// data (_datamap_memshell); the data are already in memory
		if "`memory'" == "" {
			capture quietly describe using `"`filepath'"', short
			if _rc {
				local _drc = _rc
				noisily di as error `"    ERROR: Could not describe file `filepath' (rc=`_drc')"'
				exit `_drc'
			}
			capture quietly use `"`filepath'"', clear
			if _rc {
				local _drc = _rc
				noisily di as error `"    ERROR: Could not load `filepath' (rc=`_drc')"'
				exit `_drc'
			}
		}

		// the documented variables: a varlist (memory or single()), each
		// once, in the order given; else every variable
		local docvars ""
		if `"`varspec'"' != "" {
			capture unab _sel : `varspec'
			if _rc {
				local _vrc = _rc
				local _where `"`filepath'"'
				if "`memory'" != "" local _where "the data in memory"
				noisily di as error `"varlist not found in `_where': `varspec'"'
				exit `_vrc'
			}
			local docvars : list uniq _sel
		}

		// saving()'s source and dataset columns
		local _mdsrc `"`filepath'"'
		local _mdsname "memory"
		if "`memory'" != "" local _mdsrc "memory"
		else {
			local _mnorm = subinstr(`"`filepath'"', "\", "/", .)
			local _mdsname `"`_mnorm'"'
			if strpos(`"`_mnorm'"', "/") > 0 {
				local _mdsname = reverse(`"`_mnorm'"')
				local _mslash = strpos(`"`_mdsname'"', "/")
				local _mdsname = reverse(substr(`"`_mdsname'"', 1, `_mslash' - 1))
			}
			if lower(substr(`"`_mdsname'"', -4, 4)) == ".dta" {
				local _mdsname = substr(`"`_mdsname'"', 1, length(`"`_mdsname'"') - 4)
			}
		}

		// the dataset row, from the data as loaded and before the classifier
		// touches them (c(changed) is read here)
		_datamap_collect_dataset, frame(`dsframe') sourcecommand("datamap") ///
			source(`"`_mdsrc'"') dsname(`"`_mdsname'"') output(`"`mdout'"') ///
			signature(soft)
		local dsx = r(ds_index)
		frame `dsframe': mata: _datamap_ds_read(`dsx', "_ds")
		local obs = `_dsN'
		local nvars = `_dsk'
		local dsig "`_dssig'"

		// The classification.  Unique counts above `uniqcap' are censored
		// and render as ">cap" (see _datamap_nuniq.ado); the cap must clear
		// maxcat (classification) and maxfreq (level lists), or a censored
		// count could flip a class or hide a level list.  uniqcap(0): exact.
		if `uniqcap' == 0 local nuniq_cap = 0
		else local nuniq_cap = max(`uniqcap', `maxcat', `maxfreq')
		// textsave(): the classification as text too, read back without a
		// frame (_datamap_post_metadata_rows, classtext())
		tempfile classifications classtext
		local _srcn `"`filepath'"'
		if "`memory'" != "" local _srcn "memory"
		local _aex ""
		if `autoex' local _aex "autoexclude"
		_datamap_classify using `"`filepath'"', saving("`classifications'") loaded ///
			srcname(`"`_srcn'"') maxcat(`maxcat') obs(`obs') exclude(`"`exclude'"') ///
			continuous(`"`continuous'"') categorical(`"`categorical'"') ///
			date(`"`fdate'"') cap(`nuniq_cap') quality_level("`quality_level'") ///
			docvars(`"`docvars'"') textsave("`classtext'") `_aex'
		local _autox "`r(auto_excluded)'"
		foreach _s in n_categorical n_continuous n_date n_string n_excluded n_suggested_exclude {
			local `_s' = r(`_s')
		}
		foreach _L in categorical_vars continuous_vars date_vars string_vars excluded_vars suggested_exclude {
			local `_L' "`r(`_L')'"
		}
		if "`docvars'" == "" local docvars "`r(all_vars)'"
		if `n_suggested_exclude' > 0 {
			noisily display as text "warning: likely identifier variable(s) not in exclude():`suggested_exclude'"
		}
		// every excluded variable of the dataset, also outside a varlist: a
		// variable named in panelid() or survivalvars() is checked against it
		local exall "`excluded_vars'"
		if `"`varspec'"' != "" {
			foreach _etok of local exclude {
				capture unab _ex : `_etok'
				if _rc == 0 local exall : list exall | _ex
			}
			// exclude(auto): its variables outside the varlist too
			local exall : list exall | _autox
		}

		// the variables rows.  With saving(): every summary saving() writes.
		// Without it (reportonly): every summary the document prints -- all
		// of them for a continuous variable, min and max for a date-class
		// one -- and no sort for summaries nothing reads.  The document's
		// cells are the same either way.
		frame `varframe': local _vf = _N + 1
		_datamap_post_metadata_rows, frame(`varframe') dsindex(`dsx') ///
			classtext(`"`classtext'"') sourcecommand("datamap") ///
			source(`"`_mdsrc'"') output(`"`mdout'"') dsname(`"`_mdsname'"') ///
			nvars(`nvars') datasignature(`"`dsig'"') `datesafe' `nostats' ///
			mincell(`mincell') `reportonly'
		frame `varframe': local _vl = _N
		if `_vl' < `_vf' {
			local _vf = 0
			local _vl = 0
		}

		// the levels rows: every categorical variable whose levels the
		// table lists (a values column, not nofreq), except a
		// date-formatted one under datesafe, whose levels are exact dates.
		// Excluded variables are never categorical here.  Then the profile
		// rows (missing codes, non-numeric string values) of any variable.
		local _lf = 0
		local _ll = 0
		frame `levframe': local _lf0 = _N + 1
		if `needlevels' {
			local _lvv ""
			foreach _v of local categorical_vars {
				_datamap_sumpolicy, class(categorical) vfmt("`: format `_v''") `datesafe'
				if r(datehide) continue
				// safe: text forced categorical lists no value holding a
				// digit (the datesafe rule of the string profile)
				if "`safe'" != "" {
					capture confirm string variable `_v'
					if !_rc {
						quietly count if ustrregexm(`_v', "\p{Nd}")
						if r(N) continue
					}
				}
				local _lvv "`_lvv' `_v'"
			}
			if "`_lvv'" != "" {
				_datamap_collect_levels `_lvv', frame(`levframe') dsindex(`dsx') ///
					maxlevels(`maxfreq') mincell(`mincell')
			}
		}
		// the row margins, the per-code missing counts (F3) and the string
		// profile (F4), after the levels whose mask the Missing total joins;
		// every variable, whatever the columns (2026-11-10)
		local _lfa = 0
		frame `levframe': if _N >= `_lf0' local _lfa = `_lf0'
		_datamap_collect_levels, profile frame(`levframe') dsindex(`dsx') ///
			varframe(`varframe') vfirst(`_vf') vlast(`_vl') lfirst(`_lfa') ///
			mincell(`mincell') maxcat(`maxcat') `datesafe' `safe'
		frame `levframe': local _ll0 = _N
		if `_ll0' >= `_lf0' {
			local _lf = `_lf0'
			local _ll = `_ll0'
		}

		// the key flag (I2; counted exactly for the names the datasets share
		// and the likely identifiers) and, with two or more datasets, the
		// value-label definitions the linkage block compares (F1)
		if `_vf' > 0 {
			local _lkx : list linkvars | suggested_exclude
			local _lklab ""
			if "`multi'" != "" local _lklab "labels dsframe(`dsframe') dsindex(`dsx')"
			_datamap_collect_link, varframe(`varframe') vfirst(`_vf') vlast(`_vl') ///
				exact(`_lkx') excluded(`exall') `_lklab'
		}
		else if "`multi'" != "" {
			_datamap_collect_link, varframe(`varframe') vfirst(0) vlast(0) ///
				excluded(`exall') labels dsframe(`dsframe') dsindex(`dsx')
		}
		// placeholder candidates (F5), under quality only
		local _phopt ""
		if "`placeholders'" != "" local _phopt "placeholders(`placeholders')"
		if "`quality_level'" != "" & `_vf' > 0 {
			_datamap_collect_cands, varframe(`varframe') vfirst(`_vf') vlast(`_vl') ///
				levframe(`levframe') lfirst(`_lf') mincell(`mincell') ///
				dateformat(`"`dateformat'"') `_phopt' `datesafe'
		}

		// the fragments that need the data
		if `detect_panel' | `detect_binary' | `detect_survival' | `detect_survey' | ///
			`detect_common' | "`panelid'" != "" | `"`survivalvars'"' != "" | ///
			`missing_detail' | `missing_pattern' | `samples' > 0 {
			_datamap_md_sections, dsframe(`dsframe') dsindex(`dsx') ///
				varframe(`varframe') vfirst(`_vf') vlast(`_vl') ///
				docvars(`docvars') excluded(`exall') datevars(`date_vars') ///
				catvars(`categorical_vars') detect_panel(`detect_panel') ///
				detect_binary(`detect_binary') detect_survival(`detect_survival') ///
				detect_survey(`detect_survey') detect_common(`detect_common') ///
				panelid(`panelid') survivalvars(`survivalvars') ///
				missing_detail(`missing_detail') missing_pattern(`missing_pattern') ///
				samples(`samples') mincell(`mincell') `datesafe' ///
				dateformat(`"`dateformat'"')
		}

		local _ndoc : word count `docvars'
		_datamap_collect_dataset, update frame(`dsframe') dsindex(`dsx') ///
			nvarsdoc(`_ndoc') vfirst(`_vf') vlast(`_vl') lfirst(`_lf') ///
			llast(`_ll') suggested(`suggested_exclude') excluded(`exall')

		foreach _s in n_categorical n_continuous n_date n_string n_excluded n_suggested_exclude {
			return scalar `_s' = ``_s''
		}
		foreach _L in categorical_vars continuous_vars date_vars string_vars excluded_vars suggested_exclude {
			return local `_L' "``_L''"
		}
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

// The document options travel encoded: $, `, line breaks and the prefix
// itself, so no macro or quote syntax in their text is read on the way to the
// writer (_datamap_md_document and _datamap_md_textblock decode them).
capture mata: mata drop _datamap_transport_encode()
capture mata: mata drop _datamap_emptyopts()
capture mata: mata drop _datamap_shared()
mata:
// The names that occur twice or more in the space-separated list s (sorted)
string scalar _datamap_shared(string scalar s)
{
	string colvector t
	real colvector st, len
	real scalar n
	t = sort(tokens(s)', 1)
	n = rows(t)
	if (n < 2) return("")
	st = selectindex(1 \ (t[|2 \ n|] :!= t[|1 \ n - 1|]))
	len = (rows(st) == 1 ? n : (st[|2 \ rows(st)|] \ n + 1) - st)
	st = select(st, len :>= 2)
	if (rows(st) == 0) return("")
	return(invtokens(t[st]'))
}
string scalar _datamap_transport_encode(string scalar text)
{
	string scalar prefix
	prefix = "__DATAMAP_68F73A__"
	text = subinstr(text, prefix, prefix + "P")
	text = subinstr(text, char(36), prefix + "D")
	text = subinstr(text, char(96), prefix + "T")
	text = subinstr(text, char(10), prefix + "N")
	text = subinstr(text, char(13), prefix + "R")
	return(text)
}

// The option names in command line s (after its first top-level comma)
// given with empty parentheses, space-separated.  -syntax- leaves a string
// option given as format() as empty as one not given, so the removed
// options are told apart here (2026-11-10: format() and datevars() with
// empty parentheses ran at rc 0).  Text inside "..." or `"..."' and inside
// another option's parentheses is skipped.
string scalar _datamap_emptyopts(string scalar s)
{
	real scalar i, n, cq, dq, pd, opts, st
	string scalar c, c2, nm, out, ns
	n = strlen(s)
	cq = dq = pd = opts = 0
	nm = out = ns = ""
	st = 0
	for (i = 1; i <= n; i++) {
		c = substr(s, i, 1)
		c2 = substr(s, i, 2)
		if (cq > 0) {
			if (c2 == char(96) + char(34)) {
				cq++
				i++
			}
			else if (c2 == char(34) + char(39)) {
				cq--
				i++
			}
			continue
		}
		if (dq) {
			if (c == char(34)) dq = 0
			continue
		}
		if (c2 == char(96) + char(34)) {
			cq = 1
			i++
			nm = ""
			continue
		}
		if (c == char(34)) {
			dq = 1
			nm = ""
			continue
		}
		if (c == "(") {
			pd++
			if (pd == 1) {
				st = i
				ns = (opts ? nm : "")
			}
			nm = ""
			continue
		}
		if (c == ")") {
			if (pd == 1 & ns != "") {
				if (strtrim(substr(s, st + 1, i - st - 1)) == "") out = out + " " + ns
			}
			if (pd > 0) pd--
			nm = ""
			continue
		}
		if (pd > 0) continue
		if (c == ",") {
			opts = 1
			nm = ""
			continue
		}
		if (strpos("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_", c)) nm = nm + c
		else nm = ""
	}
	return(strtrim(out))
}
end

// Row r of the collector's datasets frame (_datamap_collect_dataset; run with
// that frame current) into the caller's locals <stub>N <stub>k <stub>sort
// <stub>sig <stub>label.  Here, not in the collector's file: Mata in an
// autoloaded .ado is private to its file.
capture mata: mata drop _datamap_ds_read()
mata:
void _datamap_ds_read(real scalar r, string scalar stub)
{
	st_local(stub + "N", strofreal(_st_data(r, st_varindex("N")), "%20.0g"))
	st_local(stub + "k", strofreal(_st_data(r, st_varindex("nvars")), "%20.0g"))
	st_local(stub + "sort", _st_sdata(r, st_varindex("sortlist")))
	st_local(stub + "sig", _st_sdata(r, st_varindex("datasignature")))
	st_local(stub + "label", _st_sdata(r, st_varindex("label")))
}
end
