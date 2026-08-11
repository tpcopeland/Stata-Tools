*! pkgtransfer Version 1.0.4  2026/08/11
*! Author: Timothy P Copeland, Karolinska Institutet

/*
    DESCRIPTION:
    'pkgtransfer' facilitates the transfer of installed Stata packages between computers or Stata installations.
    It offers two primary modes of operation: online and offline.

    - Online Mode: 'pkgtransfer' generates a do-file containing the necessary 'net install', 'ssc install', or
      'github install' commands to replicate the package installation on a new machine with internet access.

    - Offline Mode: 'pkgtransfer' downloads all package files and creates both a local installation script
      ('pkgtransfer.do') and a ZIP archive ('pkgtransfer_files.zip'). This enables package installation
      on machines without internet access.

    The command intelligently handles packages from diverse sources, including the SSC archive, personal websites,
    and GitHub repositories (leveraging the 'github' command by E.F. Haghish).

    SYNTAX:
    pkgtransfer [, DOWNload(string) LIMited(string) SKIP(string) REStore
        OS(string) DOfile(string) ZIPfile(string)]

		os(string):			Specifies operating system of destination for installation; by default will use OS of current Stata instance. Valid options are: "MacOSX", "Unix", or "Windows"

		download(string):	Create a ZIP file of all packages and a do-file for local installation. Specify "local" if you with to capture local copies of packages and files and "online" if you wish to capture online copies of packages and files.

		limited(STRING):	Restricts the operation to only the specified packages. 'string' is a space-separated list of package names.

		restore:			Restores installation pathways to point to online sources after local installation.
*/

program define pkgtransfer, rclass
	version 16.0
	local _varabbrev `c(varabbrev)'
	local _did_preserve 0
	local _staging_created 0
	local _installer_open 0
	local _tracker_open 0
	local _returns_ready 0
	local _return_N .
	local _return_pkg_list ""
	tempname _installer_fh
	tempname _tracker_fh
	set varabbrev off

	capture noisily {

	syntax [, DOWNload(string) LIMited(string) SKIP(string) REStore OS(string) DOfile(string) ZIPfile(string)]

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
		if "`trk_duplicates'" != "" {
			noisily display as error ///
				"ERROR: The following packages appear in multiple package repositories:`trk_duplicates'"
			noisily display as error ///
				"Please use -ado update- to remove duplicate packages (oldest removed)."
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

		/* Error if dofile not specified correctly */
			if "`dofile'" != "" {
				if regexm(`"`dofile'"', "[;&|><\$\`]") | ///
					strpos(`"`dofile'"', char(34)) | ///
					strpos(`"`dofile'"', char(39)) {
				noisily display as error "Error: dofile() contains invalid characters"
				exit 198
			}
			if substr("`dofile'", -3, .) != ".do" {
				noisily display as error "Do file name must end with '.do' extension"
				exit 198
			}
		}

		/* Error if zipfile not specified correctly */
			if "`zipfile'" != "" {
				if regexm(`"`zipfile'"', "[;&|><\$\`]") | ///
					strpos(`"`zipfile'"', char(34)) | ///
					strpos(`"`zipfile'"', char(39)) {
				noisily display as error "Error: zipfile() contains invalid characters"
				exit 198
			}
			if substr("`zipfile'", -4, .) != ".zip" {
				noisily display as error "ZIP file name must end with '.zip' extension"
				exit 198
			}
		}

	/* Error if zipfile specified without 'download' option */
		if "`zipfile'" != "" & "`download'" == "" {
			noisily display as error "Only ZIP file name if downloading data"
			exit 198
		}

*END ERROR CHECK
}

/* Default Locals */
quietly {
		/* DO file name */
		if "`dofile'" == "" local dofile "pkgtransfer.do"

		/* ZIP file name */
		if "`zipfile'" == "" local zipfile "pkgtransfer_files.zip"

		/* If OS is not specified, use current OS */
		if "`os'" == "" local os "`c(os)'"
}

/* Preserve user data */
preserve
local _did_preserve 1

/* Refuse to reuse an output directory the command does not own */
if "`download'" != "" {
	capture mkdir "pkgtransfer_files"
	if _rc {
		noisily display as error ///
			"Output directory pkgtransfer_files already exists or cannot be created"
		noisily display as error ///
			"Move or remove that directory before creating a transfer bundle."
		exit 602
	}
	local _staging_created 1
}

/* Execute Program */
quietly{

		/* Capture packages for do file installation or online download */
		if ("`download'" == "" & "`restore'" == "") | "`download'" == "online" {

			/* Generate List of Packages and Sources */
			tempfile pkg_list
			import delimited using "`plusdir'stata.trk", delim("||||||||") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
			keep if substr(v1, 1, 2) == "N " | substr(v1, 1, 1) == "S"
			gen url = v1[_n-1]
			drop if substr(v1, 1, 1) == "S"
			replace url = subinstr(url,"S ","",.)
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
					levelsof package if (strpos(url,"http://") | strpos(url,"https://") | strpos(url,".edu/") | strpos(url,".org/") | strpos(url,".com/")) , local(pkg_list_for_do) clean
					gen keep_these = 0
					foreach name of local pkg_list_for_do {
						replace keep_these = 1 if package == "`name'"
					}
					drop if keep_these == 0
				}
			else{
				local pkg_list_for_do "`limited'"
				gen keep_these = 0
				foreach name of local pkg_list_for_do{
					quietly count if package == "`name'"
					if r(N) == 0 {
						noisily display "Note: Package `name' not currently installed"
					}
					else {
						replace keep_these = 1 if package == "`name'"
					}
				}
				drop if keep_these == 0
			}
				replace url = url + "/" if strpos(url,"http") & substr(url, -1, 1) != "/"
				replace url = url + "`c(dirsep)'" if !strpos(url,"http") & substr(url, -1, 1) != "`c(dirsep)'"
				local _return_pkg_list "`pkg_list_for_do'"
				local _return_N : word count `pkg_list_for_do'
				local _returns_ready 1
			}

        /* Creation of do file to install with internet access [Final Product for Default] */
	        if "`download'" == "" & "`restore'" == "" {
	            gen command = "net install " + package + ///
				", replace from(" + char(34) + url + char(34) + ")"
            replace command = "ssc install " + package + ", replace" if strmatch(url, "*fmwww.bc.edu/repec/bocode*")
			replace command = "github install haghish/" + package + ", stable replace" if strpos(url,"githubusercontent.com/haghish") & !strpos(command,"github install")
            keep command
	            outfile using "`dofile'", noquote replace wide
			capture confirm file "`dofile'"
			if _rc exit 603
			noisily display "Preparation of installation do file completed!"
			clear
        }

        /* Copy files from local plus directory */
        if "`download'" == "local" {

			// Get data from stata.trk
			tempfile pkg_list pkg_url plugin_temp
			import delimited using "`plusdir'stata.trk", delim("||||||||") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
			keep if substr(v1,1,2) == "S " | substr(v1,1,2) == "N " | substr(v1,1,2) == "f " | substr(v1,1,2) == "g " | substr(v1[_n-3],1,2) == "N " | substr(v1,1,2) == "d "
			gen row2 = _n
			replace row2 = row2 + 2.5 if substr(v1,1,2) == "S "
			sort row2
			replace v1 = subinstr(v1,"\","/",.) if substr(v1,1,2) != "S "
			split v1, p("N ")
			replace v12 = "" if !strpos(v12,".pkg")
			gen package = subinstr(v12,".pkg","",.)
			replace package = package[_n-1] if package == ""
			if "`skip'" != ""{
				local skiplist "`skip'"
				foreach name of local skiplist{
					drop if package == "`name'"
				}
			}
			sort package row2
			gen row = _n
			replace row = -9999 if strpos(package,"github")
			replace row = -9998 if strpos(package,"markdoc")
			replace row = -9997 if strpos(package,"weaver")
			replace row = -9996 if strpos(package,"statax")
			replace row = -9995 if strpos(package,"datadoc")
			replace row = -9994 if strpos(package,"md2smcl")
			replace row = -9993 if strpos(package,"colorcode")
			replace row = -9992 if strpos(package,"neat")
			replace row = -9991 if strpos(package,"machinelearning")
			replace row = -9990 if strpos(package,"diagram")
			replace row = -9989 if strpos(package,"rcall")
			sort row row2
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
				foreach name of local pkg_list_for_do{
					quietly count if package == "`name'"
					if r(N) == 0 {
						noisily display "Note: Package `name' not currently installed"
					}
					else {
						replace keep_these = 1 if package == "`name'"
					}
				}
					drop if keep_these == 0
				}
				local _return_pkg_list "`pkg_list_for_do'"
				local _return_N : word count `pkg_list_for_do'
				local _returns_ready 1
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
				* Convert S line to "d S <url>" backup for restore functionality
				replace v1 = "d " + v1 if substr(v1,1,2) == "S "
				drop if substr(v1,1,2) == "N "
				outfile v1 using "pkgtransfer_files/`name'.pkg", noquote replace
			}

            use "`pkg_list'", replace
			keep if substr(v1,1,2) == "f "
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
							relative(`"`destination'"')
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
			noisily display "Copying OS-specific plugins from online..."
            use "`pkg_list'", replace
			keep if substr(lower(v1),1,2) == "f " & strpos(v1,".plugin") & !strpos(v1,"gtools")
			rename v1 plugin_name
			merge m:1 package using "`pkg_url'", nogen keep(3)
			replace plugin_name = subinstr(plugin_name,"f ","",.)
			replace plugin_name = subinstr(plugin_name,"F ","",.)
			gen pkg_source_url = url + "/" + package if strpos(url,".bc.edu/repec")
			replace pkg_source_url = url + "/" + package + ".pkg" ///
				if !strpos(url,".bc.edu/repec")
			replace plugin_name = substr(plugin_name, 3,.) if substr(plugin_name, 1, 1) == substr(url, length(url), 1) & strpos(url,".bc.edu/repec")
			gen source_file = url + "/" + plugin_name
			replace plugin_name = regexr(regexr(substr(plugin_name, 1, .), "^\.\.\/", ""), "^[^\/]+\/", "")
			save "`pluginfiles'", replace

			// loop to capture plugin packages
				quietly count
				local _plugin_packages = r(N)
				if `_plugin_packages' > 0 {
				quietly forvalues i = 1(1)`_plugin_packages'{
				local main_url = url[`i']
				local pkg_source_url = pkg_source_url[`i']
				local package = package[`i']
				local plugin_name = plugin_name[`i']

				// import pkg from offline
				import delimited using "`pkg_source_url'", delim("||||||||") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
				keep if (substr(v1,1,2) == "g " | substr(v1,1,2) == "h ") & strpos(v1,"`plugin_name'")
				replace v1 = subinstr(v1, char(9), " ", .)

				// save file to append to current pkg file
				save "`plugin_temp'", replace

				// keep only rows for plugin so we can grab them
				keep if substr(v1,1,2) == "g " & strpos(v1,"`plugin_name'")
				gen v2 = word(v1, 3)
				drop v1
				gen package = "`package'"
				merge m:1 package using "`pluginfiles'", nogen keep(3)
				gen file_source = url + "/" + v2 if !strpos(v2,"/")
				replace file_source = url + "/" + v2 if strpos(v2,"/")
				replace v2 = regexr(substr(v2, 1, .), "^\.\.\/", "")

					// Download plugins with retry logic
					noisily display "Downloading plugins for `package'..."
					quietly forvalues u = 1(1)`=_N'{
						local plugin_destination `"`=v2[`u']'"'
						_pkgtransfer_prepare_destination, ///
							root("pkgtransfer_files") ///
							relative(`"`plugin_destination'"')
					local max_retries = 3
					local success = 0
					forvalues attempt = 1/`max_retries' {
						capture copy "`=file_source[`u']'" "pkgtransfer_files`c(dirsep)'`=v2[`u']'", replace
						local plugin_copy_rc = _rc
						if `plugin_copy_rc' == 0 {
							local success = 1
							continue, break
						}
						if `attempt' < `max_retries' {
							noisily display as text "Retry `attempt' of `max_retries' for plugin file..."
							sleep 2000
						}
					}
					if `success' == 0 {
						noisily display as error "Failed to download plugin file after `max_retries' attempts"
						exit `plugin_copy_rc'
					}
				}

				// get current pkg file
				import delimited using "pkgtransfer_files/`package'.pkg", delim("||||||||") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
				// drop plugin file name
				drop if substr(lower(v1),1,2) == "f " & strpos(v1,"`plugin_name'")
				// erase current plugin file
				capture erase "pkgtransfer_files/`plugin_name'"
				// append new file names for plugins
				append using "`plugin_temp'"
				// update package file
				outfile v1 using "pkgtransfer_files/`package'.pkg", noquote replace
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
				import delimited using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", delim("||||||||") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
				gen package = "`curr_pkg'"
				keep if substr(v1,1,2) == "d "
				keep if _n == 1
				keep v1 package
				append using "`pkg_desc'"
				save "`pkg_desc'", replace

				// First, create a separate dataset for file copying
				clear
				import delimited using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", delim("||||||||") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear

				keep if substr(lower(v1), 1, 2) == "f " | substr(lower(v1), 1, 2) == "g "
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
								relative(`"`clean_source'"')

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

						// Also save a copy with the target filename
						// This ensures all platform variants are downloaded and the target file exists
								local clean_target = subinstr("`target_file'", "\", "/", .)
								if substr("`clean_target'", 1, 3) == "../" ///
									local clean_target = substr("`clean_target'", 4, .)
								_pkgtransfer_prepare_destination, ///
									root("pkgtransfer_files") ///
									relative(`"`clean_target'"')
								if "`clean_target'" != "`clean_source'" {
									capture copy ///
										"pkgtransfer_files`c(dirsep)'`clean_source'" ///
										"pkgtransfer_files`c(dirsep)'`clean_target'", replace
									if _rc {
										local target_copy_rc = _rc
										noisily display as error ///
											"Could not create plugin target `clean_target'"
										exit `target_copy_rc'
									}
								}

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
								relative(`"`clean_filepath'"')

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
				import delimited using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", delim("||||||||") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear

					// Normalize bundled paths while preserving nested directories
					tempvar manifest_f manifest_gp manifest_gs manifest_gt
					gen strL `manifest_f' = subinstr(substr(v1, 3, .), ///
						"\", "/", .) if substr(lower(v1), 1, 2) == "f "
					replace `manifest_f' = regexr(`manifest_f', "^\.\.\/", "") ///
						if substr(lower(v1), 1, 2) == "f "
					replace v1 = "f " + `manifest_f' ///
						if substr(lower(v1), 1, 2) == "f "
					gen strL `manifest_gp' = word(v1, 2) ///
						if substr(lower(v1), 1, 2) == "g "
					gen strL `manifest_gs' = subinstr(word(v1, 3), "\", "/", .) ///
						if substr(lower(v1), 1, 2) == "g "
					gen strL `manifest_gt' = subinstr(word(v1, 4), "\", "/", .) ///
						if substr(lower(v1), 1, 2) == "g "
					replace `manifest_gs' = regexr(`manifest_gs', "^\.\.\/", "") ///
						if substr(lower(v1), 1, 2) == "g "
					replace `manifest_gt' = regexr(`manifest_gt', "^\.\.\/", "") ///
						if substr(lower(v1), 1, 2) == "g "
					replace v1 = "g " + `manifest_gp' + " " + `manifest_gs' + ///
						cond(`manifest_gt' != "", " " + `manifest_gt', "") ///
						if substr(lower(v1), 1, 2) == "g "

				// Add backup URL for restore functionality
				local _obs = _N + 1
				set obs `_obs'
				replace v1 = "d S `curr_url'" in `_obs'

				// Save the modified complete .pkg file
				outfile v1 using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", noquote replace

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
            replace v1 = subinstr(v1, "d ", "p ", 1)
            outfile v1 using "pkgtransfer_files/stata.toc", noquote replace
            clear

			local date = string(year(date("`c(current_date)'", "DMY")), "%4.0f") + "_" + string(month(date("`c(current_date)'", "DMY")), "%02.0f") + "_" + string(day(date("`c(current_date)'", "DMY")), "%02.0f")

            // Create installation do-file
			file open `_installer_fh' using "`dofile'", write replace
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
			file write `_installer_fh' "    unzipfile " `"""' "`zipfile'" `"""' ", replace" _n
			file write `_installer_fh' "    foreach pkg in `pkg_list_for_do' {" _n
			file write `_installer_fh' "        net install \`pkg', from(" ///
				`"""' "\`package_dir'/pkgtransfer_files" `"""' ")" _n
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
				capture confirm file "`dofile'"
				if _rc exit 603

	            // Create ZIP file
	            zipfile "pkgtransfer_files", saving("`zipfile'", replace)
				capture confirm file "`zipfile'"
				if _rc exit 603

			_pkgtransfer_cleanup_staging, directory("pkgtransfer_files")
			local _staging_created 0

            // Announce Completion
			noisily display "Preparation of installation do file and package ZIP file completed!"

        }

			/* Restore installation pathways to online sources if requested (standalone) */
			if "`restore'" != "" {
				if !`_returns_ready' local _returns_ready 1
				noisily display "Restoring installation pathways to online sources..."
			* Backup stata.trk before modifying
			copy "`plusdir'stata.trk" "`plusdir'stata.trk.backup", replace
			import delimited using "`plusdir'stata.trk", delim("||||||||") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
			* Check if any backup URLs exist
			quietly count if substr(v1,1,4) == "d S "
			if r(N) == 0 {
				noisily display as text "No pkgtransfer backup URLs found in stata.trk"
				noisily display as text "Restore requires packages installed from a pkgtransfer ZIP archive."
			}
			else {
				gen row_id = _n
				gen entry_id = sum(substr(v1,1,2) == "S ")
				* Extract original URL from "d S " backup lines
				gen orig_url = substr(v1, 5, .) if substr(v1,1,4) == "d S "
				* Fill orig_url backward within each entry to reach the S line
				gsort entry_id -row_id
				by entry_id: replace orig_url = orig_url[_n-1] if missing(orig_url) & !missing(orig_url[_n-1])
				sort row_id
				* Replace S lines with original URL where backup exists
				replace v1 = "S " + orig_url if substr(v1,1,2) == "S " & !missing(orig_url)
				drop if substr(v1,1,4) == "d S "
				drop row_id entry_id orig_url
				outfile v1 using "`plusdir'stata.trk", noquote replace
				noisily display "Installation pathways restored!"
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
	if `rc' & `_staging_created' {
		capture noisily _pkgtransfer_cleanup_staging, ///
			directory("pkgtransfer_files")
		if _rc {
			display as error ///
				"Warning: could not remove invocation-owned staging directory"
		}
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
				return local dofile "`dofile'"
				if "`download'" != "" {
					return local zipfile "`zipfile'"
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
		syntax, ROOT(string) RELative(string)
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
program define _pkgtransfer_cleanup_staging
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
