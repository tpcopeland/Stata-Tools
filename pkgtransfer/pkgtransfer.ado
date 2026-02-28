*! pkgtransfer Version 1.0.2  2025/12/05
*! Author: Tim Copeland

/*
    DESCRIPTION:
    'pkgtransfer' facilitates the transfer of installed Stata packages between computers or Stata installations. 
    It offers two primary modes of operation: online and offline.

    - Online Mode: 'pkgtransfer' generates a do-file containing the necessary 'net install', 'ssc install', or 
      'github install' commands to replicate the package installation on a new machine with internet access.

    - Offline Mode: 'pkgtransfer' downloads all package files and creates both a local installation script 
      ('pkgtransfer_local.do') and a ZIP archive ('pkgtransfer_files.zip'). This enables package installation 
      on machines without internet access.

    The command intelligently handles packages from diverse sources, including the SSC archive, personal websites, 
    and GitHub repositories (leveraging the 'github' command by E.F. Haghish).

    SYNTAX:
    pkgtransfer [, DOWNload(string) LIMITED(string) RESTORE]

		os(string):			Specifies operating system of destination for installation; by default will use OS of current Stata instance. Valid options are: "MacOSX", "Unix", or "Windows"

		download(string):	Create a ZIP file of all packages and a do-file for local installation. Specify "local" if you with to capture local copies of packages and files and "online" if you wish to capture online copies of packages and files.

		limited(STRING):	Restricts the operation to only the specified packages. 'string' is a space-separated list of package names.

		restore:			Restores installation pathways to point to online sources after local installation.
*/

program define pkgtransfer, rclass
	version 16.0
	set varabbrev off
	syntax [, DOWNLOAD(string) LIMITED(string) SKIP(string) RESTORE OS(string) DOfile(string) ZIPfile(string)]

/* Check For Errors */
quietly {

	/* Error if stata.trk file doesn't exist */
	capture confirm file "`c(sysdir_plus)'`c(dirsep)'stata.trk"
		if _rc {
            noisily display as error "Error: stata.trk file not found in PLUS directory"
            exit 601
        }

	/* Error if specified packages in limited() are not found */
	if "`limited'" != "" {
		foreach pkg of local limited {
			* Check if package exists in stata.trk
			capture ado describe `pkg'
			if _rc {
				noisily display as error "Error: package '`pkg'' not found"
				noisily display as error "Package must be installed before transfer"
				exit 111
			}
		}
	}
    
	/* Error if download() not specifid correctly */
		if "`download'" != "local" & "`download'" != "online" &  "`download'" != "" {
			noisily di in red "Error: Invalid download() specification. Either do not specify the download() option, specify download(local), or download(online)."
			exit 198
		}

	/* Error if os() not specified correctly */
		if "`os'" != "" & "`os'" != "Windows" & "`os'" != "Unix" & "`os'" != "MacOSX" {
			noisily di in red "Error: Invalid os() specification. Valid options are 'Windows', 'Unix', or 'MacOSX'."
			exit 198
		}

	/* Error if `dofile' not specified correctly */
		if "`dofile'" != "" {
			if regexm("`dofile'", "[;&|><\$\`]") {
				noisily di in red "Error: dofile() contains invalid characters"
				exit 198
			}
			if substr("`dofile'", -3, .) != ".do" {
				noisily di in red "Do file name must end with '.do' extension"
				exit 198
			}
		}

	/* Error if `zipfile' not specified correctly */
		if "`zipfile'" != "" {
			if regexm("`zipfile'", "[;&|><\$\`]") {
				noisily di in red "Error: zipfile() contains invalid characters"
				exit 198
			}
			if substr("`zipfile'", -4, .) != ".zip" {
				noisily di in red "ZIP file name must end with '.zip' extension"
				exit 198
			}
		}

	/* Error if `zipfile' specified without 'download' option */
		if "`zipfile'" != "" & "`download'" == "" {
			noisily di in red "Only ZIP file name if downloading data"
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

/* Execute Program */
quietly{

		/* Capture packages for do file installation or online download */
		if "`download'" == "" | "`download'" == "online" {
	
			/* Generate List of Packages and Sources */
			tempfile pkg_list
			import delimited using "`c(sysdir_plus)'`c(dirsep)'stata.trk", delim("$$$$$$$$$") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
			keep if substr(v1, 1, 2) == "N " | substr(v1, 1, 1) == "S"
			gen url = v1[_n-1]
			drop if substr(v1, 1, 1) == "S"
			replace url = subinstr(url,"S ","",.)
			gen package = substr(v1, strpos(v1, "N ") + 2, strpos(v1, ".pkg") - strpos(v1, "N ") - 2)
			sort package 
			if "`skip'" != ""{
				local skiplist "`skip'"
				foreach name of local skiplist{
					drop if package == "N " + "`name'" + ".pkg"
				}
			}
			duplicates tag package, gen(tag)
			sum tag, d 
			if `r(max)' > 0{
				drop if tag == 0 
				duplicates drop package, force 
				local dupe_list ""
				levelsof package, local(dupes)
				foreach pkg in `dupes' {
					local dupe_list "`dupe_list' `pkg'"
				}
				display as error "ERROR: The following packages appear in multiple package repositories: `dupe_list'"
				display as error "Please use -ado update- to remove duplicate packages (oldest removed)."
				display as error "Alternatively, to chose which duplicate to remove: "
				display as error "	1) Run -ado dir- to identify the # of the duplicate package."
				display as error "	2) Run -net uninstall [#]-, replacing # as appropriate."
				exit 459
			}
			drop tag 
			foreach name in rcall markdoc datadoc machinelearning diagram weaver neat statax md2smcl colorcode{
				replace url = "https://raw.githubusercontent.com/haghish/" + package + "/master" if package == "`name'"
			}
			gen row = _n 
			replace row = -9999 if strpos(package,"github")
			replace row = -1*row if strpos(url,"githubusercontent.com/haghish")
			sort row  
			if "`limited'" == "" {
				local pkg_list_for_do ""
				levelsof package if (strpos(url,"http") | strpos(url,".edu") | strpos(url,"org") | strpos(url,"com")) , local(pkg_list_for_do) clean
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
			replace url = url + "/" if strpos(url,"http")
			replace url = url + "`c(dirsep)'" if !strpos(url,"http")
		}

        /* Creation of do file to install with internet access [Final Product for Default] */
        if "`download'" == "" {
            gen command = "net install " + package + ", replace from(" + url + ")"
            replace command = "ssc install " + package + ", replace" if strmatch(url, "*fmwww.bc.edu/repec/bocode*")
			replace command = "github install haghish/" + package + ", stable replace" if strpos(url,"githubusercontent.com/haghish") & !strpos(command,"github install")
            keep command
            outfile using "`dofile'", noquote replace wide
			noisily display "Preparation of installation do file completed!" 
			clear 
        }

        /* Copy files from local plus directory */
        if "`download'" == "local" {

			// Get data from stata.trk
			tempfile pkg_list pkg_url plugin_temp 
			import delimited using "`c(sysdir_plus)'`c(dirsep)'stata.trk", delim("$$$$$$$$$") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
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
			if "`limited'" == "" {
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
            save "`pkg_list'", replace
			keep if substr(v1,1,2) == "N " | substr(v1,1,2) == "S "
			gen url = v1[_n+1]
			replace url = substr(url,3,.)
			keep if substr(v1,1,2) == "N "
			keep package url 
			save "`pkg_url'", replace
 
            use "`pkg_list'", replace
			local num_pkgs = _N
            capture mkdir "pkgtransfer_files"
			noisily display "Starting copying of `num_pkgs' files (not packages) from local directory..."
			
			foreach name of local pkg_list_for_do{
				use "`pkg_list'", replace 
				keep if package == "`name'"
				replace v1 = substr(v1, 1, 2) + regexr(regexr(substr(v1, 3, .), "^\.\.\/", ""), "^[^\/]+\/", "") if substr(lower(v1), 1, 2) == "f " | substr(lower(v1), 1, 2) == "g "
				drop if substr(v1,1,2) == "N "
				outfile v1 using "pkgtransfer_files/`name'.pkg", noquote replace
			}

            use "`pkg_list'", replace
			keep if substr(v1,1,2) == "f " 
			replace v1 = subinstr(v1,"\","/",.)
			replace v1 = substr(v1,3,.)
			gen source_file = "`c(sysdir_plus)'" + v1 
			replace v1 = regexr(regexr(substr(v1, 1, .), "^\.\.\/", ""), "^[^\/]+\/", "")
            tempfile pkg_files
            quietly forvalues i = 1/`=_N' {
                local source = source_file[`i']
                local destination = v1[`i']
                copy "`source'" "pkgtransfer_files/`destination'", replace
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
			replace pkg_source_url = url if !strpos(url,".bc.edu/repec")
			replace plugin_name = substr(plugin_name, 3,.) if substr(plugin_name, 1, 1) == substr(url, length(url), 1) & strpos(url,".bc.edu/repec")
			gen source_file = url + "/" + plugin_name
			replace plugin_name = regexr(regexr(substr(plugin_name, 1, .), "^\.\.\/", ""), "^[^\/]+\/", "")
			save "`pluginfiles'", replace 
			
			// loop to capture plugin packages  
			quietly forvalues i = 1(1)`=_N'{
				local main_url = url[`i']
				local pkg_source_url = pkg_source_url[`i']
				local package = package[`i']
				local plugin_name = plugin_name[`i']

				// import pkg from offline 
				import delimited using "`pkg_source_url'", delim("$$$$$$$$$") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
				keep if (strpos(v1,"g ") | strpos(v1,"h ")) & strpos(v1,"`plugin_name'")

				// save file to append to current pkg file 
				save "`plugin_temp'", replace 

				// keep only rows for plugin so we can grab them 
				keep if (strpos(v1,"g ")) & strpos(v1,"`plugin_name'")
				gen v2 = word(v1, 3)
				drop v1
				gen package = "`package'"
				merge m:1 package using "`pluginfiles'", nogen keep(3)
				gen file_source = url + "/" + v2 if !strpos(v2,"/")
				replace file_source = substr(url, 1, strlen(url)-1) + substr(v2,1,strpos(v2,"/")-1) + "/" + substr(v2, strpos(v2,"/")+1, .) if strpos(v2,"/")
				replace v2 = regexr(regexr(substr(v2, 1, .), "^\.\.\/", ""), "^[^\/]+\/", "")

				// Download plugins with retry logic
				noisily display "Downloading plugins for `package'..."
				quietly forvalues u = 1(1)`=_N'{
					local max_retries = 3
					local success = 0
					forvalues attempt = 1/`max_retries' {
						capture copy "`=file_source[`u']'" "pkgtransfer_files`c(dirsep)'`=v2[`u']'", replace
						if _rc == 0 {
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
					}
				}

				// get current pkg file 
				import delimited using "pkgtransfer_files/`package'", delim("$$$$$$$$$") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
				// drop plugin file name 
				drop if substr(lower(v1),1,2) == "f " & strpos(v1,"`plugin_name'")
				// erase current plugin file 
				capture erase "pkgtransfer_files/`plugin_name'"
				// append new file names for plugins 
				append using "`plugin_temp'"
				// update package file 
				outfile v1 using "pkgtransfer_files/`package'", noquote replace
				use "`pluginfiles'", replace 
			}


            // Initialize empty package description file
			tempfile pkg_desc
			use "`pkg_list'", replace 
			gen row3 = _n 
			egen first_dX = min(row3) if substr(v1,1,2) == "d ",by(package)
			egen first_d = min(first_dX),by(package)
			keep if first_d == row3 
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
            capture mkdir "pkgtransfer_files"
            
            save "`pkg_list'", replace

            // Initialize empty package description file
            clear
			gen v1 = ""
			gen package = ""
            save "`pkg_desc'", emptyok replace
            
            use "`pkg_list'", replace
            tempfile pkg_files
            quietly forvalues i = 1/`=_N' {
                local curr_url = url[`i']
                local curr_pkg = package[`i']

				* Network retry logic for package download (3 attempts)
				local max_retries = 3
				local success = 0
				forvalues attempt = 1/`max_retries' {
					capture copy "`curr_url'`curr_pkg'.pkg" "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", replace
					if _rc == 0 {
						local success = 1
						continue, break
					}
					if `attempt' < `max_retries' {
						noisily display as text "Retry `attempt' of `max_retries' for `curr_pkg'.pkg..."
						sleep 2000
					}
				}
				if `success' == 0 {
					noisily display as error "Failed to download `curr_pkg'.pkg after `max_retries' attempts"
				}
				
				// Store description from first line
				clear
				import delimited using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", delim("$$$$$$$$$") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
				gen package = "`curr_pkg'"
				keep if substr(v1,1,2) == "d "
				keep if _n == 1
				keep v1 package
				append using "`pkg_desc'"
				save "`pkg_desc'", replace

				// First, create a separate dataset for file copying
				clear
				tempfile modified_pkg
				import delimited using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", delim("$$$$$$$$$") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear

				keep if substr(lower(v1), 1, 2) == "f " | substr(lower(v1), 1, 2) == "g "
				gen filepath = substr(v1, 3, .)
				
				quietly forvalues j = 1/`=_N' {
					local filepath = filepath[`j']
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
						
						// Create all necessary directories in the path
						if strpos("`source_file'", "/") {
							local dirs = subinstr("`source_file'", regexr("`source_file'", "^(.+/)[^/]+$", ""), "", .)
							local path = ""
							foreach part in `=subinstr(regexr("`source_file'", "^(.+/)[^/]+$", "\1"), "/", " ", .)' {
								local path = "`path'`part'/"
								capture mkdir "pkgtransfer_files`c(dirsep)'`path'"
							}
						}
						
						// Handle relative paths
						if substr("`source_file'", 1, 3) == "../" {
							local source_file = substr("`source_file'", 4, .)
							local base_url = regexr("`curr_url'", "/[^/]+/$", "/")
						}
						else {
							local base_url = "`curr_url'"
						}
						
						// Clean the filepath of any directory components
						local clean_source = regexr(regexr("`source_file'", "^\.\.\/", ""), "^[^\/]+\/", "")

						// Download all platform-specific files with retry logic
						local max_retries = 3
						local success = 0
						forvalues attempt = 1/`max_retries' {
							capture copy "`base_url'`source_file'" "pkgtransfer_files`c(dirsep)'`clean_source'"
							if _rc == 0 {
								local success = 1
								continue, break
							}
							if `attempt' < `max_retries' {
								sleep 2000
							}
						}
						
						// Also save a copy with the target filename
						// This ensures all platform variants are downloaded and the target file exists
						local clean_target = regexr(regexr("`target_file'", "^\.\.\/", ""), "^[^\/]+\/", "")
						capture copy "pkgtransfer_files`c(dirsep)'`clean_source'" "pkgtransfer_files`c(dirsep)'`clean_target'", replace

					}
					
					// For h lines, we don't need to download anything as these are just references
					// to files that should already be downloaded via the g lines
					else if substr(lower(v1[`j']), 1, 2) == "h " {
						continue
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

						local clean_filepath = regexr(regexr("`filepath'", "^\.\.\/", ""), "^[^\/]+\/", "")

						// Download with retry logic
						local max_retries = 3
						local success = 0
						forvalues attempt = 1/`max_retries' {
							capture copy "`base_url'`filepath'" "pkgtransfer_files`c(dirsep)'`clean_filepath'"
							if _rc == 0 {
								local success = 1
								continue, break
							}
							if `attempt' < `max_retries' {
								sleep 2000
							}
						}
					}
				}

				// Last, read and modify the entire .pkg file
				clear
				tempfile modified_pkg
				import delimited using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", delim("$$$$$$$$$") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
				
				// Modify only the F and G lines while preserving all other content
				replace v1 = substr(v1, 1, 2) + regexr(regexr(substr(v1, 3, .), "^\.\.\/", ""), "^[^\/]+\/", "") if substr(lower(v1), 1, 2) == "f " | substr(lower(v1), 1, 2) == "g "
				
				// Save the modified complete .pkg file
				outfile v1 using "pkgtransfer_files`c(dirsep)'`curr_pkg'.pkg", noquote replace

				use "`pkg_list'", clear					
					
				noisily display "Progress: `curr_pkg_num'/`total_pkgs' packages (`=round(`curr_pkg_num'/`total_pkgs'*100)'%)" 
				if `curr_pkg_num' < `total_pkgs' noisily display _continue
				local curr_pkg_num = `curr_pkg_num' + 1
				
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
			
			local date "`=string(year(date("`c(current_date)'", "DMY")), "%4.0f")'" "_" "`=string(month(date("`c(current_date)'", "DMY")), "%02.0f")'" "_" "`=string(day(date("`c(current_date)'", "DMY")), "%02.0f")'"

            // Create installation do-file
            capture file close inst
            file open inst using "`dofile'", write replace
            file write inst "*pkgtransfer local installation script" _n
            file write inst "*Generated: `date' $S_TIME" _n _n
            file write inst "*Set working directory to the folder containing package files; place in global below" _n
            file write inst "global package_dir " `"""' "DIRECTORY_GOES_HERE" `"""' _n _n
            file write inst "*Use current directory if global is not set" _n
			file write inst "if " `"""' "\$package_dir" `"""' " == " `"""' "DIRECTORY_GOES_HERE" `"""' " global package_dir " `"""' "\`c(pwd)'" `"""' _n _n
            file write inst "*Set directory" _n
            file write inst `"cd "\$package_dir""' _n _n
            file write inst "*Unzip and install from local files" _n
            file write inst "unzipfile pkgtransfer_files.zip, replace" _n _n
            file write inst "*Install packages (Note: add 'replace' or 'force' options to the -net install- command if updating packages)" _n
            file write inst "foreach pkg in `pkg_list_for_do' {" _n
			file write inst `"capture noisily net install \`pkg', from("\$package_dir/pkgtransfer_files")"' _n
            file write inst "}" _n _n
			file write inst "*Clean up" _n
			file write inst "* SAFETY NOTE: Automated removal of 'pkgtransfer_files' folder disabled for safety." _n
			file write inst "* The rm -rf/rmdir command is high-risk when run from scripts on different machines." _n
			file write inst "* Please manually remove the 'pkgtransfer_files' folder when finished:" _n
			if "`os'" == "Windows"{
				file write inst `"* shell rmdir /s /q "pkgtransfer_files""' _n
			}
			if "`os'" == "MacOSX" | "`os'" == "Unix" {
				file write inst `"* shell rm -rf "pkgtransfer_files""' _n
			}
            file close inst

            // Create ZIP file
            zipfile "pkgtransfer_files", saving("`zipfile'", replace)

            // Delete Directory using Stata's file commands (safer than shell)
            // Note: Stata's rmdir only deletes empty directories, but we use
            // a local recursive approach with Stata file commands
            local filelist : dir "pkgtransfer_files" files "*", respectcase
            foreach f of local filelist {
                capture erase "pkgtransfer_files/`f'"
            }
            capture rmdir "pkgtransfer_files"
            
            /* Restore installation pathways to online sources if requested */
            if "`restore'" != "" {
                noisily display "Restoring installation pathways to online sources..."
                * Backup stata.trk before modifying
                copy "`c(sysdir_plus)'`c(dirsep)'stata.trk" "`c(sysdir_plus)'`c(dirsep)'stata.trk.backup", replace
                import delimited using "`c(sysdir_plus)'`c(dirsep)'stata.trk", delim("$$$$$$$$$") stringcols(1) bindquote(strict) maxquotedrows(unlimited) clear
                replace v1 = v1[_n+5] if substr(v1,1,2) == "S " &  substr(v1[_n+5],1,2) == "d S "
                replace v1 = subinstr(v1,"d S ","S ",.) if substr(v1[_n+1],1,2) == "N "
                drop if substr(v1,1,4) == "d S "
                outfile v1 using "`c(sysdir_plus)'`c(dirsep)'stata.trk", noquote replace
                noisily display "Installation pathways restored!"
            }

            // Announce Completion
			noisily display "Preparation of installation do file and package ZIP file completed!"

        }

}

/* Return values */
if "`pkg_list_for_do'" != "" {
	local n_pkgs : word count `pkg_list_for_do'
	return scalar N_packages = `n_pkgs'
	return local package_list "`pkg_list_for_do'"
}
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

*END PROGRAM
end
*
