*! pkgtransfer Version 1.0.0  2026/10/28
*! Author: Timothy P Copeland, Karolinska Institutet

* Writes an online reinstall script, or an offline bundle (do-file + ZIP),
* from the packages tracked in the PLUS stata.trk. See help pkgtransfer.

program define pkgtransfer, rclass
	version 16.0
	local _varabbrev `c(varabbrev)'
	local _did_preserve 0
	local _staging_created 0
	local _stage_root ""
	local _registry_created 0
    local _output_cwd_changed 0
    local _output_cwd `"`c(pwd)'"'
	tempname _bundle_registry
	local _installer_open 0
	local _tracker_open 0
	local _returns_ready 0
	local _return_N .
	local _return_pkg_list ""
	tempname _installer_fh
	tempname _tracker_fh
	set varabbrev off

	capture noisily {

	syntax [, DOWNload(string) LIMited(string) SKIP(string) REStore OS(string) DOfile(string) ZIPfile(string) replace]
	* download() and os() accept any case; returns use the canonical spelling
	local download = lower(`"`download'"')
	if lower(`"`os'"') == "windows" local os "Windows"
	else if lower(`"`os'"') == "unix" local os "Unix"
	else if lower(`"`os'"') == "macosx" local os "MacOSX"
	local _os_requested = (`"`os'"' != "")
	local _plugin_platform_regex ""

	/* Treat package selectors as sets while preserving input order */
	foreach list_name in limited skip {
		local unique_list ""
		foreach pkg of local `list_name' {
			local already_seen 0
			foreach seen_pkg of local unique_list {
				if "`pkg'" == "`seen_pkg'" local already_seen 1
			}
			if !`already_seen' local unique_list "`unique_list' `pkg'"
		}
		local `list_name' = trim("`unique_list'")
	}

	* PLUS directory path (always includes trailing separator)
	local plusdir "`c(sysdir_plus)'"

/* Check For Errors */
quietly {

	/* Standalone restore only rewrites stata.trk; refuse options it cannot honor */
	local _restore_only = "`restore'" != "" & "`download'" == ""
	if `_restore_only' {
		local _restore_conflicts ""
		foreach opt in limited skip os dofile zipfile replace {
			if `"`macval(`opt')'"' != "" ///
				local _restore_conflicts = "`_restore_conflicts' `opt'" + ///
					cond("`opt'" == "replace", "", "()")
		}
		if "`_restore_conflicts'" != "" {
			noisily display as error ///
				"restore without download() cannot be combined with:`_restore_conflicts'"
			noisily display as error ///
				"Standalone restore rewrites every pkgtransfer source marker in stata.trk."
			exit 198
		}
	}

	/* Error if stata.trk file doesn't exist */
	capture confirm file "`plusdir'stata.trk"
		if _rc {
            noisily display as error "Error: stata.trk file not found in PLUS directory"
            exit 601
        }

		/* Build the tracked package inventory once for validation */
		file open `_tracker_fh' using "`plusdir'stata.trk", read text
		local _tracker_open 1
		file read `_tracker_fh' line
		local trk_pkg_list ""
		while r(eof) == 0 {
			if substr(`"`macval(line)'"', 1, 2) == "N " {
				local this_pkg = subinstr( ///
					substr(`"`macval(line)'"', 3, .), ".pkg", "", .)
				local trk_pkg_list "`trk_pkg_list' `this_pkg'"
			}
			file read `_tracker_fh' line
		}
		file close `_tracker_fh'
		local _tracker_open 0

		/* Duplicate definitions make the source repository ambiguous */
		local trk_unique ""
		local trk_duplicates ""
		foreach pkg of local trk_pkg_list {
			local already_seen 0
			foreach seen_pkg of local trk_unique {
				if "`pkg'" == "`seen_pkg'" local already_seen 1
			}
			if `already_seen' {
				local already_listed 0
				foreach duplicate_pkg of local trk_duplicates {
					if "`pkg'" == "`duplicate_pkg'" local already_listed 1
				}
				if !`already_listed' ///
					local trk_duplicates "`trk_duplicates' `pkg'"
			}
			else {
				local trk_unique "`trk_unique' `pkg'"
			}
		}
		/* Reinstalling a bundle over an existing copy leaves two entries;
		   restore must still run on that tracker, so it only warns. */
		if "`trk_duplicates'" != "" & `_restore_only' {
			noisily display as text ///
				"Note: stata.trk lists more than one copy of:`trk_duplicates'"
			noisily display as text ///
				"Use -ado dir- and -ado uninstall [#]- to remove the older copy."
		}
		else if "`trk_duplicates'" != "" {
			noisily display as error ///
				"ERROR: The following packages appear in multiple package repositories:`trk_duplicates'"
			noisily display as error ///
				"Use -ado dir- and -ado uninstall [#]- to remove the older copy."
			exit 459
		}

		/* Error if specified packages in limited() are not found */
		if "`limited'" != "" {
			foreach pkg of local limited {
				local found 0
				foreach trk_pkg of local trk_unique {
				if "`pkg'" == "`trk_pkg'" local found 1
			}
			if !`found' {
				noisily display as error "Error: package '`pkg'' not found"
				noisily display as error "Package must be installed before transfer"
				exit 111
			}
		}
	}

	/* limited() and skip() may not select and exclude the same package */
	if "`limited'" != "" & "`skip'" != "" {
		local overlap ""
		foreach selected of local limited {
			foreach excluded of local skip {
				if "`selected'" == "`excluded'" {
					local overlap "`overlap' `selected'"
				}
			}
		}
		if "`overlap'" != "" {
			noisily display as error ///
				"limited() and skip() contain the same package(s):`overlap'"
			exit 198
		}
	}

	/* Error if download() not specified correctly */
		if "`download'" != "local" & "`download'" != "online" &  "`download'" != "" {
			noisily display as error "Error: Invalid download() specification. Either do not specify the download() option, specify download(local), or download(online)."
			exit 198
		}

	/* Error if os() not specified correctly */
		if "`os'" != "" & "`os'" != "Windows" & "`os'" != "Unix" & "`os'" != "MacOSX" {
			noisily display as error "Error: Invalid os() specification. Valid options are 'Windows', 'Unix', or 'MacOSX'."
			exit 198
		}
		if `_os_requested' {
			if "`os'" == "Windows" local _plugin_platform_regex "^WIN"
			else if "`os'" == "Unix" ///
				local _plugin_platform_regex "^(LINUX|UNIX)"
			* [R] net: MACARM64/MACINTEL64 (GUI), OSX.ARM64/OSX.X8664 (console)
			else local _plugin_platform_regex "^(MAC|OSX)"
		}

		/* Error if dofile not specified correctly */
			if "`macval(dofile)'" != "" {
				if regexm(`"`macval(dofile)'"', "[;&|><\$\`]") | ///
					strpos(`"`macval(dofile)'"', char(34)) | ///
					strpos(`"`macval(dofile)'"', char(39)) {
				noisily display as error "Error: dofile() contains invalid characters"
				exit 198
			}
			if substr("`macval(dofile)'", -3, .) != ".do" {
				noisily display as error "Do file name must end with '.do' extension"
				exit 198
			}
		}

		/* Error if zipfile not specified correctly */
			if "`macval(zipfile)'" != "" {
				if regexm(`"`macval(zipfile)'"', "[;&|><\$\`]") | ///
					strpos(`"`macval(zipfile)'"', char(34)) | ///
					strpos(`"`macval(zipfile)'"', char(39)) {
				noisily display as error "Error: zipfile() contains invalid characters"
				exit 198
			}
			if substr("`macval(zipfile)'", -4, .) != ".zip" {
				noisily display as error "ZIP file name must end with '.zip' extension"
				exit 198
			}
		}

	/* Error if zipfile specified without 'download' option */
		if "`macval(zipfile)'" != "" & "`download'" == "" {
			noisily display as error "Only ZIP file name if downloading data"
			exit 198
		}

*END ERROR CHECK
}

/* Default Locals */
quietly {
		/* DO file name */
		if "`macval(dofile)'" == "" local dofile "pkgtransfer.do"

		/* ZIP file name */
		if "`macval(zipfile)'" == "" local zipfile "pkgtransfer_files.zip"

		/* If OS is not specified, use current OS */
		if "`os'" == "" local os "`c(os)'"

		/* Existing outputs are kept unless replace is specified */
		if "`replace'" == "" & !`_restore_only' {
			local _outputs "dofile"
			if "`download'" != "" local _outputs "dofile zipfile"
			foreach output of local _outputs {
				if fileexists(`"`macval(`output')'"') {
					noisily display as error ///
						`"file `macval(`output')' already exists; specify replace to overwrite it"'
					exit 602
				}
			}
		}
}

/* Resolve output paths before staging can own or delete any files. */
if "`download'" != "" {
    foreach output in dofile zipfile {
        local output_path = subinstr(`"`macval(`output')'"', "\", "/", .)
        if substr(`"`output_path'"', 1, 1) != "/" & ///
            substr(`"`output_path'"', 2, 1) != ":" ///
            local output_path `"`c(pwd)'/`output_path'"'
        local remaining `"`output_path'"'
        local resolved ""
        while `"`remaining'"' != "" {
            gettoken part remaining : remaining, parse("/")
            if inlist(`"`part'"', "/", ".", "") continue
            if `"`part'"' == ".." local resolved = regexr(`"`resolved'"', "/[^/]+$", "")
            else local resolved `"`resolved'/`part'"'
        }
        if "`c(os)'" == "Windows" {
            if substr(`"`resolved'"', 3, 1) == ":" ///
                local resolved = substr(`"`resolved'"', 2, .)
            if substr(`"`output_path'"', 1, 2) == "//" ///
                local resolved `"/`resolved'"'
        }
        * Resolve existing ancestors too, so directory aliases cannot hide staging.
        local probe = regexr(`"`resolved'"', "/[^/]+$", "")
        local suffix = substr(`"`resolved'"', strlen(`"`probe'"') + 2, .)
        while `"`probe'"' != "" {
            capture quietly cd `"`probe'"'
            if _rc == 0 {
                local _output_cwd_changed 1
                local resolved = subinstr(`"`c(pwd)'/`suffix'"', "\", "/", .)
                quietly cd `"`_output_cwd'"'
                local _output_cwd_changed 0
                continue, break
            }
            local suffix = substr(`"`probe'"', strrpos(`"`probe'"', "/") + 1, .) + "/" + `"`suffix'"'
            local probe = regexr(`"`probe'"', "/[^/]+$", "")
            if `"`probe'"' == "/" continue, break
        }
        local _abs_`output' `"`resolved'"'
    }
    * Stage in a unique temporary directory, never in ./pkgtransfer_files: the
    * generated installer unpacks the archive there, so a later bundle run in
    * the same directory would otherwise refuse to start (r(602)).
    tempfile _stage_token
    local _stage_root `"`_stage_token'_pkgtransfer"'
    capture mkdir `"`_stage_root'"'
    if _rc {
        noisily display as error "Could not create the temporary staging directory"
        exit 603
    }
    quietly cd `"`_stage_root'"'
    local _output_cwd_changed 1
    frame create `_bundle_registry' strL path strL owner
    local _registry_created 1
    _pkgtransfer_prepare_destination, root("pkgtransfer_files") ///
        relative("stata.toc") registry(`_bundle_registry') owner("metadata:toc")
}

/* Preserve user data */
preserve
local _did_preserve 1

/* Create the bundle's staging directory inside the temporary directory */
if "`download'" != "" {
	capture mkdir "pkgtransfer_files"
	if _rc {
		noisily display as error ///
			"Could not create the staging directory pkgtransfer_files under `_stage_root'"
		noisily display as error ///
			"Check that the system temporary directory is writable."
		exit 603
	}
	local _staging_created 1
}

/* Execute Program */
quietly{

		/* Capture packages for do file installation or online download */
		if ("`download'" == "" & "`restore'" == "") | "`download'" == "online" {

			/* Generate List of Packages and Sources */
			tempfile pkg_list
			_pkgtransfer_read_lines using "`plusdir'stata.trk"
			keep if substr(v1, 1, 2) == "N " | substr(v1, 1, 1) == "S"
			gen url = v1[_n-1]
			drop if substr(v1, 1, 1) == "S"
			replace url = substr(url, 3, .)
			* Exact recorded source, kept for the restore marker
			gen src_orig = url
			gen package = substr(v1, strpos(v1, "N ") + 2, strpos(v1, ".pkg") - strpos(v1, "N ") - 2)
			sort package
			if "`skip'" != ""{
				local skiplist "`skip'"
				foreach name of local skiplist{
					drop if package == "`name'"
				}
			}
			if _N == 0 {
				noisily display as text "No transferable packages found in stata.trk"
				noisily display as text "Do-file will be empty."
			}
			* Fix haghish packages with alternative source URLs
			replace url = "https://raw.githubusercontent.com/haghish/" + package + "/master" ///
				if strpos(url, "haghish.github.io") | strpos(url, "github.com/haghish") ///
				| strpos(url, "githubusercontent.com/haghish")
			gen row = _n
			replace row = -9999 if strpos(package,"github")
			replace row = -1*row if strpos(url,"githubusercontent.com/haghish")
			sort row
			if _N == 0 {
				local pkg_list_for_do ""
			}
				else if "`limited'" == "" {
					local pkg_list_for_do ""
					* net install records either a URL or an absolute path
					tempvar online_source
					gen byte `online_source' = ///
						regexm(url, "^[A-Za-z][A-Za-z0-9+.-]+://")
					levelsof package if `online_source', ///
						local(pkg_list_for_do) clean
					levelsof package if !`online_source', ///
						local(local_path_pkgs) clean
					if `"`local_path_pkgs'"' != "" {
						noisily display as text ///
							"Note: omitted packages installed from a local path: `local_path_pkgs'"
						noisily display as text ///
							"Name them in limited() to include them."
					}
					gen keep_these = 0
					foreach name of local pkg_list_for_do {
						replace keep_these = 1 if package == "`name'"
					}
					drop if keep_these == 0
				}
			else{
				local pkg_list_for_do "`limited'"
				gen keep_these = 0
				* limited() names were validated against stata.trk above
				foreach name of local pkg_list_for_do {
					replace keep_these = 1 if package == "`name'"
				}
				drop if keep_these == 0
			}
				replace url = url + "/" if strpos(url,"http") & substr(url, -1, 1) != "/"
				replace url = url + "`c(dirsep)'" if !strpos(url,"http") & substr(url, -1, 1) != "`c(dirsep)'"
				local _return_pkg_list "`pkg_list_for_do'"
				local _return_N : word count `pkg_list_for_do'
				local _returns_ready 1
                if "`download'" != "" {
                    foreach reserved of local pkg_list_for_do {
                        _pkgtransfer_prepare_destination, root("pkgtransfer_files") ///
                            relative("`reserved'.pkg") registry(`_bundle_registry') ///
                            owner("metadata:`reserved'")
                    }
                }
			}

        /* Creation of do file to install with internet access [Final Product for Default] */
	        if "`download'" == "" & "`restore'" == "" {
	            gen command = "net install " + package + ///
				", replace from(" + char(34) + url + char(34) + ")"
            replace command = "ssc install " + package + ", replace" if strmatch(url, "*fmwww.bc.edu/repec/bocode*")
			replace command = "github install haghish/" + package + ", stable replace" if strpos(url,"githubusercontent.com/haghish") & package != "github" & !strpos(command,"github install")
            keep command
	            outfile using "`macval(dofile)'", noquote replace wide
			capture confirm file "`macval(dofile)'"
			if _rc exit 603
			noisily display "Preparation of installation do file completed!"
			clear
        }

        /* Copy files from local plus directory */
        if "`download'" == "local" {

			// Get data from stata.trk
			tempfile pkg_list pkg_url plugin_temp
			_pkgtransfer_read_lines using "`plusdir'stata.trk"
			keep if substr(v1,1,2) == "S " | substr(v1,1,2) == "N " | substr(v1,1,2) == "f " | substr(v1,1,2) == "g " | substr(v1,1,2) == "d " | strtrim(v1) == "e"
			gen row2 = _n
			replace row2 = row2 + 2.5 if substr(v1,1,2) == "S "
			sort row2
			replace v1 = subinstr(v1,"\","/",.) if substr(v1,1,2) != "S "
			* Package names come only from N records, never from d text
			gen package = subinstr(substr(v1, 3, .), ".pkg", "", .) ///
				if substr(v1,1,2) == "N "
			replace package = package[_n-1] if package == ""
			if "`skip'" != ""{
				local skiplist "`skip'"
				foreach name of local skiplist{
					drop if package == "`name'"
				}
			}
			sort package row2
			keep v1 package
			quietly count if package != ""
			local _selected_records = r(N)
			if `_selected_records' == 0 {
				local pkg_list_for_do ""
			}
			else if "`limited'" == "" {
				local pkg_list_for_do ""
				levelsof package, local(pkg_list_for_do) clean
			}
			else{
				local pkg_list_for_do "`limited'"
				gen keep_these = 0
				* limited() names were validated against stata.trk above
				foreach name of local pkg_list_for_do {
					replace keep_these = 1 if package == "`name'"
				}
					drop if keep_these == 0
				}
				local _return_pkg_list "`pkg_list_for_do'"
				local _return_N : word count `pkg_list_for_do'
				local _returns_ready 1
                if "`download'" != "" {
                    foreach reserved of local pkg_list_for_do {
                        _pkgtransfer_prepare_destination, root("pkgtransfer_files") ///
                            relative("`reserved'.pkg") registry(`_bundle_registry') ///
                            owner("metadata:`reserved'")
                    }
                }
	            save "`pkg_list'", replace
			keep if substr(v1,1,2) == "N " | substr(v1,1,2) == "S "
			gen url = v1[_n+1]
			replace url = substr(url,3,.)
			keep if substr(v1,1,2) == "N "
			keep package url
			save "`pkg_url'", replace

            use "`pkg_list'", replace
			quietly count if substr(v1,1,2) == "f " | substr(v1,1,2) == "g "
			local num_files = r(N)
			noisily display "Starting file copy (`num_files' files) from local directory..."

			foreach name of local pkg_list_for_do{
				use "`pkg_list'", replace
				keep if package == "`name'"
				replace v1 = substr(v1, 1, 2) + regexr(regexr(substr(v1, 3, .), "^\.\.\/", ""), "^[^\/]+\/", "") if substr(lower(v1), 1, 2) == "f " | substr(lower(v1), 1, 2) == "g "
				* Every tracked file was installed into the system directories, so
				* F keeps runtime data (F x.dta) installed; F x.ado equals f x.ado
				replace v1 = "F " + substr(v1, 3, .) if substr(v1, 1, 2) == "f "
				* Preserve the original source under a private restore marker.
				* A package installed from a bundle already carries the original
				* marker; its S line names the previous machine's staging folder.
				quietly count if substr(v1,1,21) == "d pkgtransfer-source " | ///
					(substr(v1,1,4) == "d S " & regexm(substr(v1,5,.), "^[A-Za-z]+://"))
				if r(N) > 0 drop if substr(v1,1,2) == "S "
				else replace v1 = "d pkgtransfer-source " + substr(v1, 3, .) ///
					if substr(v1,1,2) == "S "
				drop if substr(v1,1,2) == "N "
				tempvar pkg_order
				gen long `pkg_order' = _n + 1
				local _pkg_obs = _N + 1
				set obs `_pkg_obs'
				replace v1 = "v 3" in `_pkg_obs'
				replace `pkg_order' = 1 in `_pkg_obs'
				sort `pkg_order'
				drop `pkg_order'
				_pkgtransfer_write_lines using "pkgtransfer_files/`name'.pkg"
			}

			// Read each source descriptor: a tracked file installed by a g/G
			// record takes the platform route whatever its extension
			tempfile src_desc platform_files
			clear
			gen strL v1 = ""
			gen package = ""
			save "`src_desc'", emptyok replace
			local _desc_read ""
			local _desc_unread ""
			local _desc_unread_rc ""
			* A package installed from a bundle carries a restore marker; its S
			* line names the previous machine's staging folder, not the source
			use "`pkg_list'", clear
			tempvar marker_rec
			gen byte `marker_rec' = substr(v1,1,21) == "d pkgtransfer-source " | ///
				(substr(v1,1,4) == "d S " & regexm(substr(v1,5,.), "^[A-Za-z]+://"))
			local _marker_pkgs ""
			quietly count if `marker_rec'
			if r(N) levelsof package if `marker_rec', local(_marker_pkgs) clean
			foreach name of local pkg_list_for_do {
				use "`pkg_url'", clear
				quietly keep if package == "`name'"
				local desc_url `"`=url[1]'/`name'.pkg"'
				capture _pkgtransfer_read_lines using `"`desc_url'"'
				local desc_rc = _rc
				if `desc_rc' {
					local from_bundle : list name in _marker_pkgs
					* g/G files cannot be identified; refuse rather than ship
					* this machine's build labelled as the requested platform
					if `from_bundle' {
						noisily display as error ///
							`"Could not read the source descriptor of `name': `desc_url'"'
						noisily display as error ///
							"`name' was installed from a pkgtransfer bundle whose folder is no longer readable, so its platform-specific (g/G) files cannot be identified."
						noisily display as error ///
							"Run -pkgtransfer, restore- first (on its own), then rerun download(local) to read the original source."
						exit 601
					}
					local _desc_unread "`_desc_unread' `name'"
					local _desc_unread_rc "`_desc_unread_rc' `desc_rc'"
					continue
				}
				local _desc_read "`_desc_read' `name'"
				replace v1 = subinstr(v1, char(9), " ", .)
				keep if substr(lower(v1),1,2) == "g " | substr(lower(v1),1,2) == "h "
				gen package = "`name'"
				append using "`src_desc'"
				save "`src_desc'", replace
			}
			use "`src_desc'", clear
			keep if substr(lower(v1),1,2) == "g "
			gen file_base = cond(word(v1, 4) != "", word(v1, 4), word(v1, 3))
			replace file_base = regexr(subinstr(file_base, "\", "/", .), "^.*/", "")
			keep package file_base
			if _N > 0 duplicates drop
			gen byte platform_route = 1
			save "`platform_files'", replace

			use "`pkg_list'", replace
			tempvar record_order
			gen long `record_order' = _n
			gen file_base = regexr(strtrim(substr(v1, 3, .)), "^.*/", "") ///
				if substr(v1,1,2) == "f "
			merge m:1 package file_base using "`platform_files'", ///
				keep(1 3) nogen
			replace platform_route = 1 if substr(v1,1,2) == "f " & ///
				regexm(file_base, "\.plugin$")
			replace platform_route = 0 if missing(platform_route)
			sort `record_order'
			drop file_base `record_order'
			save "`pkg_list'", replace

			* Without a descriptor, g/G files cannot be told apart from f files
			local _unread_plain ""
			foreach name of local _desc_unread {
				quietly count if package == "`name'" & platform_route
				if r(N) == 0 local _unread_plain "`_unread_plain' `name'"
			}
			if "`_unread_plain'" != "" {
				noisily display as text ///
					"Note: could not read the source descriptor of:`_unread_plain'"
				noisily display as text ///
					"Their files are bundled as installed on this machine; platform-specific (g) files cannot be identified."
			}

            use "`pkg_list'", replace
			keep if substr(v1,1,2) == "f " & !platform_route
			replace v1 = subinstr(v1,"\","/",.)
			replace v1 = substr(v1,3,.)
			gen source_file = "`plusdir'" + v1
				replace v1 = regexr(regexr(substr(v1, 1, .), "^\.\.\/", ""), "^[^\/]+\/", "")
				if _N > 0 {
					quietly forvalues i = 1/`=_N' {
						local source `"`=source_file[`i']'"'
						local destination `"`=v1[`i']'"'
						_pkgtransfer_prepare_destination, ///
							root("pkgtransfer_files") ///
							relative(`"`destination'"') registry(`_bundle_registry') ///
                            owner(`"`=package[`i']':`source'"')
						capture copy `"`source'"' ///
							`"pkgtransfer_files/`destination'"', replace
					if _rc {
						local source_copy_rc = _rc
						noisily display as error ///
							"Could not copy required package file `source'"
						exit `source_copy_rc'
					}
				}
			}

			// Fix plugins
			tempfile pluginfiles
            use "`pkg_list'", replace
			keep if substr(lower(v1),1,2) == "f " & platform_route
			rename v1 plugin_name
			merge m:1 package using "`pkg_url'", nogen keep(3)
			replace plugin_name = subinstr(plugin_name,"f ","",.)
			replace plugin_name = subinstr(plugin_name,"F ","",.)
			gen pkg_source_url = url + "/" + package + ".pkg"
			replace plugin_name = substr(plugin_name, 3,.) if substr(plugin_name, 1, 1) == substr(url, length(url), 1) & strpos(url,".bc.edu/repec")
			replace plugin_name = regexr(regexr(substr(plugin_name, 1, .), "^\.\.\/", ""), "^[^\/]+\/", "")
			save "`pluginfiles'", replace

			// loop to capture plugin packages
				quietly count
				local _plugin_packages = r(N)
				if `_plugin_packages' > 0 {
				noisily display "Copying OS-specific plugins from online..."
				quietly forvalues i = 1(1)`_plugin_packages'{
				local main_url `"`=url[`i']'"'
				local pkg_source_url `"`=pkg_source_url[`i']'"'
				local package `"`=package[`i']'"'
				local plugin_name `"`=plugin_name[`i']'"'
				// Remove the stale installed-platform copy before replacement
				capture erase "pkgtransfer_files/`plugin_name'"

				// g/h records of the source descriptor read above
				local desc_was_read : list package in _desc_read
				if !`desc_was_read' {
					* A .plugin file's platform builds come only from the descriptor
					local desc_pos : list posof "`package'" in _desc_unread
					local desc_rc : word `desc_pos' of `_desc_unread_rc'
					noisily display as error ///
						`"Could not read the source descriptor of `package': `pkg_source_url'"'
					noisily display as error ///
						"Its plugin `plugin_name' has platform-specific builds that only that descriptor identifies."
					noisily display as error ///
						"Make the source reachable, or exclude it with skip(`package')."
					exit `desc_rc'
				}
				use "`src_desc'" if package == "`package'", clear
				drop package
				* Match the installed file name exactly, not as a substring
				local plugin_base = regexr(`"`plugin_name'"', "^.*/", "")
				tempvar plugin_target
				gen strL `plugin_target' = cond(substr(lower(v1),1,2) == "h ", ///
					word(v1, 2), cond(word(v1, 4) != "", word(v1, 4), word(v1, 3)))
				replace `plugin_target' = ///
					regexr(subinstr(`plugin_target', "\", "/", .), "^.*/", "")
				keep if `plugin_target' == `"`plugin_base'"'
				drop `plugin_target'
				if `_os_requested' {
					drop if substr(lower(v1),1,2) == "g " & ///
						!regexm(upper(word(v1, 2)), ///
						`"`_plugin_platform_regex'"')
				}

				// Normalize descriptor paths and download every matching plugin
				noisily display "Downloading platform files for `package'..."
				quietly count if substr(lower(v1),1,2) == "g "
				if r(N) == 0 {
					local file_kind = cond(regexm(`"`plugin_name'"', "\.plugin$"), ///
						"Plugin", "Platform file")
					local for_os = cond(`_os_requested', " for os(`os')", "")
					noisily display as error ///
						"`file_kind' `plugin_name' has no platform record`for_os'"
					exit 498
				}
				quietly forvalues u = 1/`=_N' {
					if substr(lower(v1[`u']),1,2) == "g " {
						local plugin_directive `"`=substr(v1[`u'], 1, 1)'"'
						local plugin_platform `"`=word(v1[`u'], 2)'"'
						local source_file `"`=word(v1[`u'], 3)'"'
						local target_file `"`=word(v1[`u'], 4)'"'
						local plugin_base_url = ///
							regexr(`"`main_url'"', "/$", "") + "/"
						if substr(`"`source_file'"', 1, 3) == "../" {
							local source_file = substr(`"`source_file'"', 4, .)
							local plugin_base_url = regexr( ///
								`"`plugin_base_url'"', "/[^/]+/$", "/")
						}

						local clean_source = subinstr( ///
							`"`source_file'"', "\", "/", .)
						if `"`target_file'"' == "" ///
							local target_file `"`clean_source'"'
						if substr(`"`target_file'"', 1, 3) == "../" ///
							local target_file = substr(`"`target_file'"', 4, .)
						local clean_target = subinstr( ///
							`"`target_file'"', "\", "/", .)
						_pkgtransfer_prepare_destination, ///
							root("pkgtransfer_files") ///
							relative(`"`clean_source'"') registry(`_bundle_registry') ///
                            owner(`"`package':`plugin_base_url'`source_file'"')
						_pkgtransfer_prepare_destination, ///
							root("pkgtransfer_files") ///
							relative(`"`clean_target'"')

						replace v1 = "`plugin_directive' `plugin_platform' `clean_source'" + ///
							cond(`"`clean_target'"' != `"`clean_source'"', ///
							" `clean_target'", "") in `u'

						local max_retries = 3
						local success = 0
						forvalues attempt = 1/`max_retries' {
							capture copy ///
								`"`plugin_base_url'`source_file'"' ///
								`"pkgtransfer_files/`clean_source'"', replace
							local plugin_copy_rc = _rc
							if `plugin_copy_rc' == 0 {
								local success = 1
								continue, break
							}
							if `attempt' < `max_retries' {
								noisily display as text ///
									"Retry `attempt' of `max_retries' for plugin file..."
								sleep 2000
							}
						}
						if `success' == 0 {
							noisily display as error ///
								"Failed to download plugin file after `max_retries' attempts"
							exit `plugin_copy_rc'
						}

					}
				}

				// Save normalized g/h records to append to the local descriptor
				save "`plugin_temp'", replace

				// get current pkg file
				_pkgtransfer_read_lines using "pkgtransfer_files/`package'.pkg"
				quietly count if strtrim(lower(v1)) == "e"
				local had_end_marker = r(N) > 0
				drop if strtrim(lower(v1)) == "e"
				// drop plugin file name
				drop if substr(lower(v1),1,2) == "f " & ///
					regexr(strtrim(substr(v1, 3, .)), "^.*/", "") == `"`plugin_base'"'
				// append new file names for plugins
				append using "`plugin_temp'"
				if `had_end_marker' {
					local _end_obs = _N + 1
					set obs `_end_obs'
					replace v1 = "e" in `_end_obs'
				}
				// update package file
				_pkgtransfer_write_lines using "pkgtransfer_files/`package'.pkg"
					use "`pluginfiles'", replace
				}
				}


			// Initialize empty package description file
			tempfile pkg_desc
			use "`pkg_list'", replace
			quietly count
			if r(N) > 0 {
				gen row3 = _n
				egen first_dX = min(row3) if substr(v1,1,2) == "d ",by(package)
				egen first_d = min(first_dX),by(package)
				keep if first_d == row3
			}
			save "`pkg_desc'", replace
			clear
		*END LOCAL FILE COPY
		}

		/* Download files from online */
        if "`download'" == "online" {

			// Count total packages
			count
			local total_pkgs = r(N)
			local curr_pkg_num = 1

			noisily display "Starting download of `total_pkgs' packages..."
			tempfile pkg_desc
			save "`pkg_list'", replace

            // Initialize empty package description file
            clear
			gen v1 = ""
			gen package = ""
            save "`pkg_desc'", emptyok replace

			use "`pkg_list'", replace
			quietly count
			local _online_packages = r(N)
			if `_online_packages' > 0 {
			quietly forvalues i = 1/`_online_packages' {
                local curr_url = url[`i']
                local curr_src = src_orig[`i']
                local curr_pkg = package[`i']

				* Network retry logic for package download (3 attempts)
				local max_retries = 3
				local success = 0
				forvalues attempt = 1/`max_retries' {
					capture copy "`curr_url'`curr_pkg'.pkg" "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", replace
					local package_copy_rc = _rc
					if `package_copy_rc' == 0 {
						local success = 1
						continue, break
					}
					if `attempt' < `max_retries' {
						noisily display as text "Retry `attempt' of `max_retries' for `curr_pkg'.pkg..."
						sleep 2000
					}
				}
				if `success' == 0 {
					noisily display as error ///
						"Failed to download required descriptor `curr_pkg'.pkg"
					exit `package_copy_rc'
				}

				// Store description from first line
				clear
				_pkgtransfer_read_lines using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg"
				gen package = "`curr_pkg'"
				keep if substr(v1,1,2) == "d "
				keep if _n == 1
				keep v1 package
				append using "`pkg_desc'"
				save "`pkg_desc'", replace

				// First, create a separate dataset for file copying
				clear
				_pkgtransfer_read_lines using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg"
				* Directive fields may be tab-separated; word() splits on spaces only
				replace v1 = subinstr(v1, char(9), " ", .) if lower(substr(v1, 1, 1)) != "d"

				keep if substr(lower(v1), 1, 2) == "f " | substr(lower(v1), 1, 2) == "g "
				if `_os_requested' {
					drop if substr(lower(v1),1,2) == "g " & ///
						!regexm(upper(word(v1, 2)), ///
						`"`_plugin_platform_regex'"')
				}
					gen filepath = substr(v1, 3, .)

					quietly forvalues j = 1/`=_N' {
						local filepath `"`=filepath[`j']'"'
						// For g lines with platform-specific plugins
						if substr(lower(v1[`j']), 1, 2) == "g " {
						// Parse the platform and filenames
						local full_line = trim(substr("`filepath'", 1, .))
						local platform = word("`full_line'", 1)
						local source_file = word("`full_line'", 2)

						// Handle target file if specified
						if wordcount("`full_line'") >= 3 {
							local target_file = word("`full_line'", 3)
						}
						else {
							local target_file = "`source_file'"
						}

							// Handle relative paths
							if substr("`source_file'", 1, 3) == "../" {
							local source_file = substr("`source_file'", 4, .)
							local base_url = regexr("`curr_url'", "/[^/]+/$", "/")
						}
						else {
							local base_url = "`curr_url'"
						}

							local source_file = subinstr("`source_file'", "\", "/", .)
							local clean_source "`source_file'"
							_pkgtransfer_prepare_destination, ///
								root("pkgtransfer_files") ///
								relative(`"`clean_source'"') registry(`_bundle_registry') ///
                                owner(`"`curr_pkg':`base_url'`source_file'"')

						// Download all platform-specific files with retry logic
						local max_retries = 3
						local success = 0
							forvalues attempt = 1/`max_retries' {
									capture copy "`base_url'`source_file'" ///
										"pkgtransfer_files`c(dirsep)'`clean_source'", replace
								local plugin_source_rc = _rc
								if `plugin_source_rc' == 0 {
								local success = 1
								continue, break
							}
							if `attempt' < `max_retries' {
									sleep 2000
								}
							}
							if `success' == 0 {
								noisily display as error ///
									"Failed to download required plugin file `source_file'"
								exit `plugin_source_rc'
							}

								local clean_target = subinstr("`target_file'", "\", "/", .)
								if substr("`clean_target'", 1, 3) == "../" ///
									local clean_target = substr("`clean_target'", 4, .)
								_pkgtransfer_prepare_destination, ///
									root("pkgtransfer_files") ///
									relative(`"`clean_target'"')

						}

						// For regular f lines
					else {
						if substr("`filepath'", 1, 3) == "../" {
							local filepath = substr("`filepath'", 4, .)
							local base_url = regexr("`curr_url'", "/[^/]+/$", "/")
						}
						else {
							local base_url = "`curr_url'"
						}

							local filepath = subinstr("`filepath'", "\", "/", .)
							local clean_filepath "`filepath'"
							_pkgtransfer_prepare_destination, ///
								root("pkgtransfer_files") ///
								relative(`"`clean_filepath'"') registry(`_bundle_registry') ///
                                owner(`"`curr_pkg':`base_url'`filepath'"')

						// Download with retry logic
						local max_retries = 3
						local success = 0
							forvalues attempt = 1/`max_retries' {
									capture copy "`base_url'`filepath'" ///
										"pkgtransfer_files`c(dirsep)'`clean_filepath'", replace
								local file_copy_rc = _rc
								if `file_copy_rc' == 0 {
								local success = 1
								continue, break
							}
							if `attempt' < `max_retries' {
								sleep 2000
								}
							}
							if `success' == 0 {
								noisily display as error ///
									"Failed to download required package file `filepath'"
								exit `file_copy_rc'
							}
						}
				}

				// Last, read and modify the entire .pkg file
				clear
				_pkgtransfer_read_lines using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg"
				replace v1 = subinstr(v1, char(9), " ", .) if lower(substr(v1, 1, 1)) != "d"
				if `_os_requested' {
					drop if substr(lower(v1),1,2) == "g " & ///
						!regexm(upper(word(v1, 2)), ///
						`"`_plugin_platform_regex'"')
				}

					// Normalize bundled paths while preserving nested directories
					tempvar manifest_f manifest_gd manifest_gp manifest_gs manifest_gt
					gen strL `manifest_f' = subinstr(substr(v1, 3, .), ///
						"\", "/", .) if substr(lower(v1), 1, 2) == "f "
					replace `manifest_f' = regexr(`manifest_f', "^\.\.\/", "") ///
						if substr(lower(v1), 1, 2) == "f "
					* Keep the directive's case: F installs non-ado types into PLUS
					replace v1 = substr(v1, 1, 1) + " " + `manifest_f' ///
						if substr(lower(v1), 1, 2) == "f "
					gen strL `manifest_gp' = word(v1, 2) ///
						if substr(lower(v1), 1, 2) == "g "
					gen str1 `manifest_gd' = substr(v1, 1, 1) ///
						if substr(lower(v1), 1, 2) == "g "
					gen strL `manifest_gs' = subinstr(word(v1, 3), "\", "/", .) ///
						if substr(lower(v1), 1, 2) == "g "
					gen strL `manifest_gt' = subinstr(word(v1, 4), "\", "/", .) ///
						if substr(lower(v1), 1, 2) == "g "
					replace `manifest_gs' = regexr(`manifest_gs', "^\.\.\/", "") ///
						if substr(lower(v1), 1, 2) == "g "
					replace `manifest_gt' = regexr(`manifest_gt', "^\.\.\/", "") ///
						if substr(lower(v1), 1, 2) == "g "
					replace v1 = `manifest_gd' + " " + `manifest_gp' + ///
						" " + `manifest_gs' + ///
						cond(`manifest_gt' != "", " " + `manifest_gt', "") ///
						if substr(lower(v1), 1, 2) == "g "

				// Add a private backup URL marker for restore functionality,
				// unless the source is itself a bundle that already names it
				quietly count if substr(v1,1,21) == "d pkgtransfer-source " | ///
					(substr(v1,1,4) == "d S " & regexm(substr(v1,5,.), "^[A-Za-z]+://"))
				local has_marker = r(N) > 0
				quietly count if strtrim(lower(v1)) == "e"
				local had_end_marker = r(N) > 0
				drop if strtrim(lower(v1)) == "e"
				if !`has_marker' {
					local _obs = _N + 1
					set obs `_obs'
					replace v1 = "d pkgtransfer-source `curr_src'" in `_obs'
				}
				if `had_end_marker' {
					local _end_obs = _N + 1
					set obs `_end_obs'
					replace v1 = "e" in `_end_obs'
				}

				// Save the modified complete .pkg file
				_pkgtransfer_write_lines using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg"

				use "`pkg_list'", clear

				noisily display "Progress: `curr_pkg_num'/`total_pkgs' packages (`=round(`curr_pkg_num'/`total_pkgs'*100)'%)"
				local curr_pkg_num = `curr_pkg_num' + 1

            }

			}
		}

		/* Create stata.toc, pkgtransfer_local.do, and ZIP file [Final Product for local & online download options] */
		if "`download'" == "online" | "`download'" == "local" {

            // Create stata.toc file
            use "`pkg_desc'", clear
			keep if substr(v1,1,2) == "d "
			tempvar toc_description toc_order
			gen strL `toc_description' = strtrim(substr(v1, 3, .))
			replace v1 = "p " + package + ///
				cond(`toc_description' != "", " " + `toc_description', "")
			gen long `toc_order' = _n + 1
			local _toc_obs = _N + 1
			set obs `_toc_obs'
			replace v1 = "v 3" in `_toc_obs'
			replace `toc_order' = 1 in `_toc_obs'
			sort `toc_order'
			drop `toc_description' `toc_order'
            _pkgtransfer_write_lines using "pkgtransfer_files/stata.toc"
            clear

			local date = string(year(date("`c(current_date)'", "DMY")), "%4.0f") + "_" + string(month(date("`c(current_date)'", "DMY")), "%02.0f") + "_" + string(day(date("`c(current_date)'", "DMY")), "%02.0f")

            // Create installation do-file
			file open `_installer_fh' using "`macval(_abs_dofile)'", write replace
			local _installer_open 1
			file write `_installer_fh' "*pkgtransfer local installation script" _n
			file write `_installer_fh' "*Generated: `date' $S_TIME" _n _n
			file write `_installer_fh' ///
				"*Set the directory containing the installer and archive" _n
			file write `_installer_fh' "local _pkgtransfer_original_dir " ///
				`"""' "\`c(pwd)'" `"""' _n
			file write `_installer_fh' "local package_dir " ///
				`"""' "DIRECTORY_GOES_HERE" `"""' _n _n
			file write `_installer_fh' "*Use the current directory unless edited" _n
			file write `_installer_fh' "if " `"""' "\`package_dir'" `"""' " == " `"""' "DIRECTORY_GOES_HERE" `"""' " local package_dir " `"""' "\`c(pwd)'" `"""' _n _n
			file write `_installer_fh' "capture noisily {" _n
			file write `_installer_fh' "    cd " `"""' ///
				"\`package_dir'" `"""' _n
			* The installer runs beside the archive, so it names only the file
			local zip_base = regexr(subinstr(`"`macval(zipfile)'"', "\", "/", .), "^.*/", "")
			file write `_installer_fh' "    unzipfile " `"""' "`macval(zip_base)'" `"""' ", replace" _n
			file write `_installer_fh' "    foreach pkg in `pkg_list_for_do' {" _n
			file write `_installer_fh' "        net install \`pkg', from(" ///
				`"""' "\`package_dir'/pkgtransfer_files" `"""' ") replace" _n
			file write `_installer_fh' "    }" _n
			file write `_installer_fh' "}" _n
			file write `_installer_fh' "local _pkgtransfer_rc = _rc" _n
			file write `_installer_fh' "capture cd " `"""' ///
				"\`_pkgtransfer_original_dir'" `"""' _n
			file write `_installer_fh' ///
				"if \`_pkgtransfer_rc' exit \`_pkgtransfer_rc'" _n _n
			file write `_installer_fh' "*Clean up" _n
			file write `_installer_fh' "* SAFETY NOTE: Automated removal of 'pkgtransfer_files' folder disabled for safety." _n
			file write `_installer_fh' "* The rm -rf/rmdir command is high-risk when run from scripts on different machines." _n
			file write `_installer_fh' "* Please manually remove the 'pkgtransfer_files' folder when finished:" _n
			if "`os'" == "Windows"{
				file write `_installer_fh' `"* shell rmdir /s /q "pkgtransfer_files""' _n
			}
			if "`os'" == "MacOSX" | "`os'" == "Unix" {
				file write `_installer_fh' `"* shell rm -rf "pkgtransfer_files""' _n
			}
				file close `_installer_fh'
				local _installer_open 0
				capture confirm file "`macval(_abs_dofile)'"
				if _rc exit 603

	            // Create ZIP file
	            zipfile "pkgtransfer_files", saving("`macval(_abs_zipfile)'", replace)
				capture confirm file "`macval(_abs_zipfile)'"
				if _rc exit 603

			_pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
			local _staging_created 0
                confirm file "`macval(_abs_dofile)'"
                confirm file "`macval(_abs_zipfile)'"

            // Announce Completion
			noisily display "Preparation of installation do file and package ZIP file completed!"

        }

			/* Restore installation pathways to online sources if requested (standalone) */
			if "`restore'" != "" {
				if !`_returns_ready' local _returns_ready 1
				noisily display "Restoring installation pathways to online sources..."
			_pkgtransfer_read_lines using "`plusdir'stata.trk"
			* Recognize private markers and URL-shaped legacy markers
			tempvar restore_marker
			gen byte `restore_marker' = ///
				substr(v1,1,21) == "d pkgtransfer-source "
			replace `restore_marker' = 1 if ///
				substr(v1,1,4) == "d S " & ///
				regexm(substr(v1,5,.), "^[A-Za-z]+://")
			quietly count if `restore_marker'
			if r(N) == 0 {
				noisily display as text "No pkgtransfer backup URLs found in stata.trk"
				noisily display as text "Restore requires packages installed from a pkgtransfer ZIP archive."
			}
			else {
				* Back up before modifying; never overwrite an earlier backup
				local trk_backup "`plusdir'stata.trk.backup"
				local backup_n 0
				while fileexists("`trk_backup'") {
					local ++backup_n
					local trk_backup "`plusdir'stata.trk.backup`backup_n'"
				}
				copy "`plusdir'stata.trk" "`trk_backup'"
				gen row_id = _n
				gen entry_id = sum(substr(v1,1,2) == "S ")
				* Extract original URLs from private and legacy backup lines
				gen orig_url = substr(v1, 22, .) if ///
					substr(v1,1,21) == "d pkgtransfer-source "
				replace orig_url = substr(v1, 5, .) if ///
					substr(v1,1,4) == "d S " & `restore_marker'
				* Carry the entry's last marker back to its S line. Bundles made
				* before 1.2.0 stacked a later hop's marker ahead of the original,
				* so the last marker is the original source.
				gsort entry_id -row_id
				by entry_id: replace orig_url = orig_url[_n-1] if !missing(orig_url[_n-1])
				sort row_id
				* Replace S lines with original URL where backup exists
				replace v1 = "S " + orig_url if substr(v1,1,2) == "S " & !missing(orig_url)
				drop if `restore_marker'
				drop row_id entry_id orig_url `restore_marker'
				_pkgtransfer_write_lines using "`plusdir'stata.trk"
				noisily display "Installation pathways restored!"
				noisily display as text "Previous stata.trk saved as `trk_backup'"
			}
		}

}

/* Restore user data */
restore
local _did_preserve 0

	} // end capture noisily

		/* Clean up on success or error */
		local rc = _rc
		if `_tracker_open' capture file close `_tracker_fh'
		if `_installer_open' capture file close `_installer_fh'
        * Staging is removed while still inside the staging directory
        if `rc' & `_staging_created' {
            capture noisily _pkgtransfer_cleanup_staging, ///
                directory("pkgtransfer_files")
            if _rc {
                display as error ///
                    "Warning: could not remove invocation-owned staging directory"
            }
        }
        if `_output_cwd_changed' {
            capture quietly cd `"`_output_cwd'"'
            if _rc & !`rc' local rc = _rc
        }
        if `"`_stage_root'"' != "" capture rmdir `"`_stage_root'"'
        if `_registry_created' {
            capture frame drop `_bundle_registry'
            if _rc & !`rc' local rc = _rc
        }
		if `rc' & `_did_preserve' capture restore
		set varabbrev `_varabbrev'

		/* Post the complete analytical surface even when side work failed */
		if `_returns_ready' {
			return clear
			if "`restore'" != "" & "`download'" == "" {
				return local download_mode "restore"
				return local os "`os'"
			}
			else {
				return scalar N_packages = `_return_N'
				return local package_list "`_return_pkg_list'"
				if "`download'" != "" {
					return local download_mode "`download'"
				}
				else {
					return local download_mode "script_only"
				}
				return local os "`os'"
				return local dofile "`macval(dofile)'"
				if "`download'" != "" {
					return local zipfile "`macval(zipfile)'"
				}
			}
		}
		if `rc' exit `rc'

*END PROGRAM
end
*

capture program drop _pkgtransfer_prepare_destination
program define _pkgtransfer_prepare_destination, nclass
	version 16.0
	local _varabbrev `c(varabbrev)'
	set varabbrev off

	capture noisily {
		syntax, ROOT(string) RELative(string) [REGistry(name) OWNer(string)]
		local relative = subinstr(`"`relative'"', "\", "/", .)
		local padded "/`relative'/"
		local unsafe = ///
			`"`relative'"' == "" | ///
			substr(`"`relative'"', 1, 1) == "/" | ///
			substr(`"`relative'"', 1, 1) == "\" | ///
			(strlen(`"`relative'"') >= 2 & ///
				substr(`"`relative'"', 2, 1) == ":") | ///
			strpos(`"`padded'"', "/../") > 0 | ///
			strpos(`"`padded'"', "/./") > 0 | ///
			strpos(`"`relative'"', "//") > 0 | ///
			strpos(`"`relative'"', char(34)) > 0 | ///
			strpos(`"`relative'"', char(39)) > 0
		if `unsafe' {
			noisily display as error ///
				"Unsafe package path in tracking metadata: `relative'"
			exit 198
		}

		* Claims include generated metadata and full package/source identity.
        * Fold paths only for collision refusal, so bundles are portable.
        if "`registry'" != "" {
            local key = lower(`"`relative'"')
            frame `registry': quietly count if path == `"`key'"' & owner != `"`owner'"'
            if r(N) {
                noisily display as error "Conflicting bundle destination: `relative'"
                exit 459
            }
            frame `registry': quietly count if path == `"`key'"'
            if r(N) == 0 {
                frame `registry': quietly count
                local row = r(N) + 1
                frame `registry': quietly set obs `row'
                frame `registry': quietly replace path = `"`key'"' in `row'
                frame `registry': quietly replace owner = `"`owner'"' in `row'
            }
        }

        local parent = regexr(`"`relative'"', "/[^/]+$", "")
		if `"`parent'"' == `"`relative'"' local parent ""
		local path_built ""
		local remaining `"`parent'"'
		while `"`remaining'"' != "" {
			gettoken path_part remaining : remaining, parse("/")
			if `"`path_part'"' == "/" continue
			local path_built `"`path_built'`path_part'/"'
			capture mkdir `"`root'/`path_built'"'
			if _rc {
				capture local dir_probe : dir ///
					`"`root'/`path_built'"' files "*"
				if _rc {
					noisily display as error ///
						"Could not create bundle directory `path_built'"
					exit 693
				}
			}
		}
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end
*

capture program drop _pkgtransfer_cleanup_staging
program define _pkgtransfer_cleanup_staging, nclass
	version 16.0
	local _varabbrev `c(varabbrev)'
	set varabbrev off

	capture noisily {
		syntax, DIRectory(string)
		local subdirs : dir `"`directory'"' dirs "*", respectcase
		foreach d of local subdirs {
			_pkgtransfer_cleanup_staging, ///
				directory(`"`directory'/`d'"')
		}
		local filelist : dir `"`directory'"' files "*", respectcase
		foreach f of local filelist {
			erase `"`directory'/`f'"'
		}
		rmdir `"`directory'"'
	}
	local rc = _rc
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end

* Load a text file into strL v1, one observation per line. Unlike
* import delimited, every line (blank, piped, quoted, long) is kept.
capture program drop _pkgtransfer_read_lines
program define _pkgtransfer_read_lines, nclass
	version 16.0
	local _varabbrev `c(varabbrev)'
	set varabbrev off
	tempname fh
	local _file_open 0

	capture noisily {
		syntax using/
		local source `"`using'"'
		if regexm(`"`source'"', "^[A-Za-z][A-Za-z0-9+.-]+://") {
			tempfile remote_copy
			copy `"`source'"' `"`remote_copy'"'
			local source `"`remote_copy'"'
		}
		clear
		quietly generate strL v1 = ""
		file open `fh' using `"`source'"', read text
		local _file_open 1
		file read `fh' line
		local n 0
		while r(eof) == 0 {
			local ++n
			quietly set obs `n'
			mata: st_sstore(`n', "v1", st_local("line"))
			file read `fh' line
		}
		file close `fh'
		local _file_open 0
		quietly compress v1
	}
	local rc = _rc
	if `_file_open' capture file close `fh'
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end
*

* Write v1 one line per observation, staged so the target is replaced whole.
capture program drop _pkgtransfer_write_lines
program define _pkgtransfer_write_lines, nclass
	version 16.0
	local _varabbrev `c(varabbrev)'
	set varabbrev off
	tempname mfh mlines mi
	tempfile staged

	capture noisily {
		syntax using/
		mata: `mfh' = fopen(st_local("staged"), "w"); `mlines' = st_sdata(., "v1"); for (`mi' = 1; `mi' <= rows(`mlines'); `mi'++) fput(`mfh', `mlines'[`mi']); fclose(`mfh')
		copy `"`staged'"' `"`using'"', replace
	}
	local rc = _rc
	* stata-dev-ignore: capture-rc, capture_rc — cleanup zone; the write's rc is already saved in rc
	if `rc' capture mata: fclose(`mfh')
	capture mata: mata drop `mfh' `mlines' `mi'
	set varabbrev `_varabbrev'
	if `rc' exit `rc'
end
*
