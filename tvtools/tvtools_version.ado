*! tvtools_version Version 1.0.0  2025/12/26
*! Display version information for all tvtools commands
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvtools_version [, quiet]

Options:
  quiet - suppress output, only set return values

Returns:
  r(tvexpose)      - tvexpose version string
  r(tvmerge)       - tvmerge version string
  r(tvevent)       - tvevent version string
  r(package_date)  - package distribution date (YYYYMMDD)
*/

program define tvtools_version, rclass
    version 16.0

    syntax [, Quiet]

    // Get paths to installed commands using findfile
    capture findfile tvexpose.ado
    if _rc {
        display as error "tvexpose.ado not found in adopath"
        exit 601
    }
    local tvexpose_path "`r(fn)'"

    capture findfile tvmerge.ado
    if _rc {
        display as error "tvmerge.ado not found in adopath"
        exit 601
    }
    local tvmerge_path "`r(fn)'"

    capture findfile tvevent.ado
    if _rc {
        display as error "tvevent.ado not found in adopath"
        exit 601
    }
    local tvevent_path "`r(fn)'"

    // Extract version from first line of each file
    tempname fh

    // tvexpose version
    file open `fh' using `"`tvexpose_path'"', read text
    file read `fh' line
    file close `fh'
    local tvexpose_ver = ""
    if regexm(`"`line'"', "Version ([0-9]+\.[0-9]+\.[0-9]+)") {
        local tvexpose_ver = regexs(1)
    }

    // tvmerge version
    file open `fh' using `"`tvmerge_path'"', read text
    file read `fh' line
    file close `fh'
    local tvmerge_ver = ""
    if regexm(`"`line'"', "Version ([0-9]+\.[0-9]+\.[0-9]+)") {
        local tvmerge_ver = regexs(1)
    }

    // tvevent version
    file open `fh' using `"`tvevent_path'"', read text
    file read `fh' line
    file close `fh'
    local tvevent_ver = ""
    if regexm(`"`line'"', "Version ([0-9]+\.[0-9]+\.[0-9]+)") {
        local tvevent_ver = regexs(1)
    }

    // Display output unless quiet
    if "`quiet'" == "" {
        display as text ""
        display as text "{hline 60}"
        display as text "{bf:tvtools Version Information}"
        display as text "{hline 60}"
        display as text ""
        display as text "  {bf:Command}      {bf:Version}"
        display as text "  {hline 24}"
        display as text "  tvexpose      `tvexpose_ver'"
        display as text "  tvmerge       `tvmerge_ver'"
        display as text "  tvevent       `tvevent_ver'"
        display as text ""
        display as text "  Package Distribution-Date: 20251226"
        display as text "{hline 60}"
        display as text ""
        display as text "  {bf:Paths:}"
        display as text "  tvexpose: `tvexpose_path'"
        display as text "  tvmerge:  `tvmerge_path'"
        display as text "  tvevent:  `tvevent_path'"
        display as text ""
        display as text "  {bf:Citation for methods sections:}"
        display as text `"  tvtools (tvexpose `tvexpose_ver', tvmerge `tvmerge_ver', tvevent `tvevent_ver')"'
        display as text ""
    }

    // Return values
    return local tvexpose "`tvexpose_ver'"
    return local tvmerge "`tvmerge_ver'"
    return local tvevent "`tvevent_ver'"
    return local package_date "20251226"
end
