*! logdoc Version 1.1.0  2026/03/15
*! Convert Stata SMCL/log files to HTML or Markdown documents
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Syntax:
  logdoc using filename, output(string) [format(string) theme(string)
      title(string) date(string) run preformatted nofold nodots
      python(string) replace]

Description:
  Converts Stata .smcl, .log, or .do files into self-contained HTML
  or Markdown documents with styled output, formatted tables, and
  embedded graphs.

See help logdoc for complete documentation
*/

program define logdoc, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * Parse syntax
    syntax using/ , Output(string) [Format(string) THeme(string) ///
        TItle(string) DATe(string) RUN PREformatted NOFold NODots ///
        PYthon(string) REPlace]

    * Defaults
    if "`format'" == "" local format "html"
    if "`theme'" == "" local theme "light"

    * Validate format
    if !inlist("`format'", "html", "md", "both") {
        display as error "format() must be html, md, or both"
        set varabbrev `_vaset'
        exit 198
    }

    * Validate theme
    if !inlist("`theme'", "light", "dark") {
        display as error "theme() must be light or dark"
        set varabbrev `_vaset'
        exit 198
    }

    * Check input file
    local input_file "`using'"

    * Handle .do files with run option
    if "`run'" != "" {
        * Verify input is a .do file
        local ext = lower(substr("`input_file'", -3, .))
        if "`ext'" != ".do" {
            display as error "run option requires a .do file as input"
            set varabbrev `_vaset'
            exit 198
        }
        capture confirm file "`input_file'"
        if _rc {
            display as error `"file "`input_file'" not found"'
            set varabbrev `_vaset'
            exit 601
        }

        * Execute the .do file in batch mode
        display as text "Running: `input_file'"
        shell stata-mp -b do "`input_file'"

        * Find the resulting .smcl log
        local dobase = substr("`input_file'", 1, length("`input_file'") - 3)
        local smcl_file "`dobase'.smcl"

        capture confirm file "`smcl_file'"
        if _rc {
            * Try .log as fallback
            local log_file "`dobase'.log"
            capture confirm file "`log_file'"
            if _rc {
                display as error "no log file produced from running `input_file'"
                display as error "expected: `smcl_file' or `log_file'"
                set varabbrev `_vaset'
                exit 601
            }
            local input_file "`log_file'"
        }
        else {
            local input_file "`smcl_file'"
        }
        display as text "Log captured: `input_file'"
    }
    else {
        * Check input exists
        capture confirm file "`input_file'"
        if _rc {
            display as error `"file "`input_file'" not found"'
            set varabbrev `_vaset'
            exit 601
        }
    }

    * Check replace / output exists
    if "`replace'" == "" {
        capture confirm file "`output'"
        if !_rc {
            display as error `"file "`output'" already exists; use replace option"'
            set varabbrev `_vaset'
            exit 602
        }
    }

    * Find Python executable
    if "`python'" == "" {
        local python "python3"
        if "`c(os)'" == "Windows" {
            local python "python"
        }
    }

    * Find logdoc_render.py
    local scriptpath ""
    _logdoc_find_script, result(scriptpath)
    if "`scriptpath'" == "" {
        display as error "logdoc_render.py not found"
        display as error "ensure logdoc is properly installed"
        set varabbrev `_vaset'
        exit 601
    }

    * Find CSS files (expand ~ like _logdoc_find_script does)
    local light_css ""
    local dark_css ""

    capture findfile logdoc_light.css
    if _rc == 0 {
        local light_css "`r(fn)'"
        if substr("`light_css'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`light_css'", 2, .)
            local light_css "`homedir'`rest'"
        }
    }

    capture findfile logdoc_dark.css
    if _rc == 0 {
        local dark_css "`r(fn)'"
        if substr("`dark_css'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`dark_css'", 2, .)
            local dark_css "`homedir'`rest'"
        }
    }

    * Build command
    local cmd `"`python' "`scriptpath'" "`input_file'" "`output'""'
    local cmd `"`cmd' --format `format'"'
    local cmd `"`cmd' --theme `theme'"'

    if "`title'" != "" {
        local cmd `"`cmd' --title '`title''"'
    }

    if "`preformatted'" != "" {
        local cmd `"`cmd' --preformatted"'
    }

    if "`nofold'" != "" {
        local cmd `"`cmd' --nofold"'
    }

    if "`nodots'" != "" {
        local cmd `"`cmd' --nodots"'
    }

    if "`date'" != "" {
        local cmd `"`cmd' --date '`date''"'
    }

    if "`light_css'" != "" {
        local cmd `"`cmd' --light-css "`light_css'""'
    }

    if "`dark_css'" != "" {
        local cmd `"`cmd' --dark-css "`dark_css'""'
    }

    * Execute
    display as text "Generating document..."
    shell `cmd'

    * Verify output
    capture confirm file "`output'"
    if _rc {
        display as error "failed to generate output document"
        display as error "ensure Python 3 is installed and accessible"
        display as error "command attempted: `cmd'"
        set varabbrev `_vaset'
        exit 601
    }

    display as result "Output: `output'"

    * Verify secondary output for format(both)
    if "`format'" == "both" {
        local dotpos = strrpos("`output'", ".")
        if `dotpos' > 0 {
            local outbase = substr("`output'", 1, `dotpos' - 1)
        }
        else {
            local outbase "`output'"
        }
        local primary_ext = substr("`output'", `dotpos', .)
        if "`primary_ext'" == ".md" {
            local secondary "`outbase'.html"
        }
        else {
            local secondary "`outbase'.md"
        }
        capture confirm file "`secondary'"
        if _rc {
            display as error "primary output created but secondary file failed"
            display as error "expected: `secondary'"
            set varabbrev `_vaset'
            exit 601
        }
        display as result "Output: `secondary'"
    }

    * Return values
    return local output "`output'"
    return local input "`input_file'"
    return local format "`format'"
    return local theme "`theme'"

    set varabbrev `_vaset'
end


* ---------------------------------------------------------------------------
* Helper: find logdoc_render.py
* ---------------------------------------------------------------------------

capture program drop _logdoc_find_script
program define _logdoc_find_script
    syntax , result(name)

    * 1. Try findfile (searches adopath)
    capture findfile logdoc_render.py
    if _rc == 0 {
        local path "`r(fn)'"
        * Expand ~ if present
        if substr("`path'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`path'", 2, .)
            local path "`homedir'`rest'"
        }
        c_local `result' "`path'"
        exit 0
    }

    * 2. Try current directory
    capture confirm file "logdoc_render.py"
    if !_rc {
        c_local `result' "logdoc_render.py"
        exit 0
    }

    * 3. Try PERSONAL directory
    capture findfile logdoc_render.py, path(PERSONAL)
    if _rc == 0 {
        local path "`r(fn)'"
        if substr("`path'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`path'", 2, .)
            local path "`homedir'`rest'"
        }
        c_local `result' "`path'"
        exit 0
    }

    * Not found
    c_local `result' ""
end
