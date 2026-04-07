*! consort Version 1.0.0  2026/04/08
*! Generate CONSORT-style exclusion flowcharts for observational research
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
CONSORT Diagram Generator for Stata

Basic syntax:
  consort init, initial(string) [file(string)]
  consort exclude if condition, label(string) [remaining(string)]
  consort save, output(string) [final(string) shading python(string) dpi(integer)]
  consort clear

Subcommands:
  init      - Initialize a new CONSORT diagram with starting population
  exclude   - Apply an exclusion and record it in the diagram
  save      - Generate the diagram image using Python/matplotlib
  clear     - Clear the current diagram state

Requirements:
  - Python 3 with matplotlib installed
  - Stata 16+ recommended (works with earlier versions via shell)

See help consort for complete documentation
*/

program define consort, rclass
    version 16.0
    local orig_varabbrev "`c(varabbrev)'"
    local orig_more "`c(more)'"
    set varabbrev off
    set more off

    capture noisily {
        * Parse subcommand
        gettoken subcmd 0 : 0, parse(" ,")
        local subcmd = lower(trim("`subcmd'"))

        * Dispatch to subcommand
        if "`subcmd'" == "init" {
            _consort_init `0'
        }
        else if "`subcmd'" == "exclude" {
            _consort_exclude `0'
        }
        else if "`subcmd'" == "save" {
            _consort_save `0'
        }
        else if "`subcmd'" == "clear" {
            _consort_clear `0'
        }
        else if "`subcmd'" == "" {
            display as error "subcommand required"
            display as error "syntax: consort {init|exclude|save|clear} [options]"
            exit 198
        }
        else {
            display as error "unknown subcommand: `subcmd'"
            display as error "valid subcommands: init, exclude, save, clear"
            exit 198
        }

        * Pass through return values
        return add
    }
    local rc = _rc
    set varabbrev `orig_varabbrev'
    set more `orig_more'
    if `rc' exit `rc'
end


* =============================================================================
* INIT SUBCOMMAND
* =============================================================================

capture program drop _consort_init
program define _consort_init, rclass
    version 16.0

    syntax , INItial(string) [FILE(string)]

    * Check if diagram already active
    if "${CONSORT_ACTIVE}" == "1" {
        display as error "CONSORT diagram already initialized"
        display as error "use {bf:consort clear} first, or {bf:consort save} to complete"
        exit 198
    }

    * Count current observations
    quietly count
    local n = r(N)

    if `n' == 0 {
        display as error "no observations in dataset"
        exit 2000
    }

    * Set up file path
    if "`file'" == "" {
        * Create a temp file that persists across program calls
        local tmpdir "`c(tmpdir)'"
        local ts = clock("`c(current_date)' `c(current_time)'", "DMYhms")
        local file "`tmpdir'/consort_`ts'_`c(pid)'.csv"
        global CONSORT_TEMPFILE "`file'"
    }
    else {
        * Validate file path for shell metacharacters (passed to shell in save)
        local _bad = strpos("`file'", ";") + strpos("`file'", "|") + ///
            strpos("`file'", "&") + strpos("`file'", ">") + ///
            strpos("`file'", "<") + strpos("`file'", char(96)) + ///
            strpos("`file'", "$")
        if `_bad' > 0 {
            display as error "file path contains invalid characters"
            exit 198
        }
        global CONSORT_TEMPFILE ""
    }

    * Escape double quotes for CSV (double them per RFC 4180)
    local safe_initial : subinstr local initial `"""' `""""', all

    * Format count to prevent scientific notation for very large datasets
    local n_str = string(`n', "%20.0f")
    local n_str = trim("`n_str'")

    * Initialize CSV file
    tempname fh
    file open `fh' using "`file'", write replace
    file write `fh' "label,n,remaining" _n
    file write `fh' `""`macval(safe_initial)'",`n_str',"' _n
    file close `fh'

    * Store state in globals
    global CONSORT_FILE "`file'"
    global CONSORT_N `n'
    global CONSORT_ACTIVE "1"
    global CONSORT_STEPS "0"

    * Return values
    return scalar N = `n'
    return local initial "`initial'"
    return local file "`file'"

    * Display
    display as text _n "{hline 60}"
    display as text "CONSORT Diagram Initialized"
    display as text "{hline 60}"
    display as text "Initial population:  " as result "`initial'"
    display as text "Observations:        " as result %10.0fc `n'
    display as text "CSV file:            " as result "`file'"
    display as text "{hline 60}"
    display as text "Use {bf:consort exclude} to add exclusion steps"
end


* =============================================================================
* EXCLUDE SUBCOMMAND
* =============================================================================

capture program drop _consort_exclude
program define _consort_exclude, rclass
    version 16.0

    syntax if , LABel(string) [REMaining(string)]

    * Validate label is non-empty
    if trim("`label'") == "" {
        display as error "label() must be non-empty"
        exit 198
    }

    * Check if diagram is active
    if "${CONSORT_ACTIVE}" != "1" {
        display as error "CONSORT diagram not initialized"
        display as error "use {bf:consort init} first"
        exit 198
    }

    * Count exclusions before applying
    quietly count `if'
    local n_excl = r(N)

    if `n_excl' == 0 {
        display as text "Note: 0 observations match condition, skipping exclusion"
        return scalar n_excluded = 0
        return scalar n_remaining = _N
        return local label "`label'"
        exit 0
    }

    * Compute remaining count before dropping
    local n_remain = _N - `n_excl'

    * Escape double quotes for CSV (double them per RFC 4180)
    local safe_label : subinstr local label `"""' `""""', all
    local safe_remaining : subinstr local remaining `"""' `""""', all

    * Format count to prevent scientific notation for very large datasets
    local n_excl_str = string(`n_excl', "%20.0f")
    local n_excl_str = trim("`n_excl_str'")

    * Write CSV BEFORE dropping data (so data isn't lost if write fails)
    * Note: use _char(34) for quotes around remaining field to avoid
    * compound-quote ambiguity when remaining is empty (the trailing "'
    * gets consumed as Stata's compound-quote close, leaving a stray ")
    tempname fh
    file open `fh' using "${CONSORT_FILE}", write append
    file write `fh' `""`macval(safe_label)'",`n_excl_str',"' _char(34) `"`macval(safe_remaining)'"' _char(34) _n
    file close `fh'

    * Apply exclusion (drop matching observations)
    drop `if'

    * Update state
    local steps = 0${CONSORT_STEPS} + 1
    global CONSORT_STEPS "`steps'"

    * Return values
    return scalar n_excluded = `n_excl'
    return scalar n_remaining = `n_remain'
    return scalar step = `steps'
    return local label "`label'"

    * Display
    local pct : display %5.1f 100 * `n_remain' / 0${CONSORT_N}
    display as text "Step `steps': " as result "Excluded `n_excl'" ///
        as text " - `label'"
    display as text "         Remaining: " as result "`n_remain'" ///
        as text " (`pct'% of initial)"
end


* =============================================================================
* SAVE SUBCOMMAND
* =============================================================================

capture program drop _consort_save
program define _consort_save, rclass
    version 16.0

    syntax , OUTput(string) [FINal(string) SHADing PYTHON(string) DPI(integer 150)]

    * Check if diagram is active
    if "${CONSORT_ACTIVE}" != "1" {
        display as error "CONSORT diagram not initialized"
        display as error "use {bf:consort init} first"
        exit 198
    }

    * Check for at least one exclusion
    if 0${CONSORT_STEPS} == 0 {
        display as error "no exclusion steps recorded"
        display as error "use {bf:consort exclude} to add at least one exclusion"
        exit 198
    }

    * Validate DPI
    if `dpi' <= 0 {
        display as error "dpi() must be a positive integer"
        exit 198
    }

    * Validate output path for shell metacharacters
    local _bad = strpos("`output'", ";") + strpos("`output'", "|") + ///
        strpos("`output'", "&") + strpos("`output'", ">") + ///
        strpos("`output'", "<") + strpos("`output'", char(96)) + ///
        strpos("`output'", "$")
    if `_bad' > 0 {
        display as error "output path contains invalid characters"
        exit 198
    }

    * Check that output directory exists
    local outdir ""
    local slashpos = strrpos("`output'", "/")
    if `slashpos' == 0 {
        local slashpos = strrpos("`output'", "\")
    }
    if `slashpos' > 0 {
        local outdir = substr("`output'", 1, `slashpos' - 1)
        mata : st_local("dir_exists", strofreal(direxists(st_local("outdir"))))
        if `dir_exists' == 0 {
            display as error "output directory does not exist: `outdir'"
            exit 601
        }
    }

    * Determine if final() was explicitly provided
    local final_explicit = ("`final'" != "")
    if !`final_explicit' {
        local final "Final Cohort"
    }

    * Update last row with final label
    _consort_update_final `"`final'"' `final_explicit'

    * Find Python executable
    if "`python'" == "" {
        local python "python"
        * Try python3 first on Unix systems
        if "`c(os)'" != "Windows" {
            local pycheck "`c(tmpdir)'/consort_pycheck_`c(pid)'"
            capture erase "`pycheck'"
            shell which python3 > /dev/null 2>&1 && echo FOUND > "`pycheck'" 2>/dev/null
            capture confirm file "`pycheck'"
            if _rc == 0 {
                local python "python3"
            }
            capture erase "`pycheck'"
        }
    }

    * Find the consort_diagram.py script
    local scriptpath ""
    _consort_find_script
    local scriptpath "${CONSORT_SCRIPT_PATH}"

    if "`scriptpath'" == "" {
        display as error "cannot find consort_diagram.py"
        display as error "ensure the script is installed with the consort package"
        exit 601
    }

    * Verify CSV data file still exists
    capture confirm file "${CONSORT_FILE}"
    if _rc {
        display as error "exclusion data file not found: ${CONSORT_FILE}"
        display as error "the file may have been deleted; re-run the workflow"
        exit 601
    }

    * Build command with options
    local cmd `"`python' "`scriptpath'" "${CONSORT_FILE}" "`output'""'
    if "`shading'" != "" {
        local cmd `"`cmd' --shading"'
    }
    if `dpi' != 150 {
        local cmd `"`cmd' --dpi `dpi'"'
    }

    * Remove any existing output file so stale results don't mask failure
    capture erase "`output'"

    * Execute Python script
    display as text _n "Generating CONSORT diagram..."
    shell `cmd'

    * Check if output was created
    capture confirm file "`output'"
    if _rc {
        display as error "failed to generate diagram"
        display as error "check that Python and matplotlib are installed"
        display as error "command attempted: `cmd'"
        exit 601
    }

    * Get final counts
    quietly count
    local final_n = r(N)
    local initial_n = 0${CONSORT_N}
    local pct : display %5.1f 100 * `final_n' / `initial_n'
    local excluded = `initial_n' - `final_n'
    local steps = 0${CONSORT_STEPS}

    * Return values
    return scalar N_initial = `initial_n'
    return scalar N_final = `final_n'
    return scalar N_excluded = `excluded'
    return scalar steps = `steps'
    return local output "`output'"
    return local final "`final'"

    * Display summary
    display as text _n "{hline 60}"
    display as text "CONSORT Diagram Complete"
    display as text "{hline 60}"
    display as text "Output file:      " as result "`output'"
    display as text "Initial N:        " as result %10.0fc `initial_n'
    display as text "Final N:          " as result %10.0fc `final_n'
    display as text "Total excluded:   " as result %10.0fc `excluded'
    display as text "Retention:        " as result "`pct'%"
    display as text "Exclusion steps:  " as result "`steps'"
    display as text "{hline 60}"

    * Clear state after successful save
    _consort_clear_state
end


* =============================================================================
* CLEAR SUBCOMMAND
* =============================================================================

capture program drop _consort_clear
program define _consort_clear
    version 16.0

    syntax [, QUIET]

    if "${CONSORT_ACTIVE}" != "1" & "`quiet'" == "" {
        display as text "No active CONSORT diagram to clear"
        exit 0
    }

    _consort_clear_state

    if "`quiet'" == "" {
        display as text "CONSORT diagram state cleared"
    }
end


* =============================================================================
* HELPER PROGRAMS
* =============================================================================

capture program drop _consort_clear_state
program define _consort_clear_state
    * Delete temp file if we created one
    if "${CONSORT_TEMPFILE}" != "" {
        capture erase "${CONSORT_TEMPFILE}"
    }
    * Clear all globals
    global CONSORT_FILE ""
    global CONSORT_N ""
    global CONSORT_ACTIVE ""
    global CONSORT_STEPS ""
    global CONSORT_TEMPFILE ""
    global CONSORT_SCRIPT_PATH ""
end


capture program drop _consort_find_script
program define _consort_find_script
    * Find consort_diagram.py in various locations
    * Note: All paths must be expanded (~ replaced with home directory)
    * because shell commands don't expand ~ when called from Stata

    * Helper: get home directory for ~ expansion
    local homedir : environment HOME

    * 1. Check current directory
    capture confirm file "consort_diagram.py"
    if _rc == 0 {
        global CONSORT_SCRIPT_PATH "consort_diagram.py"
        exit 0
    }

    * 2. Search adopath using findfile (most reliable method)
    capture findfile consort_diagram.py
    if _rc == 0 {
        local scriptpath "`r(fn)'"
        * Expand ~ if present (findfile returns unexpanded paths)
        if substr("`scriptpath'", 1, 1) == "~" {
            local rest = substr("`scriptpath'", 2, .)
            local scriptpath "`homedir'`rest'"
        }
        global CONSORT_SCRIPT_PATH "`scriptpath'"
        exit 0
    }

    * 3. Check py subdirectory of PLUS (where net install places .py files)
    local plusdir "`c(sysdir_plus)'"
    if substr("`plusdir'", 1, 1) == "~" {
        local rest = substr("`plusdir'", 2, .)
        local plusdir "`homedir'`rest'"
    }
    local scriptfile "`plusdir'py/consort_diagram.py"
    capture confirm file "`scriptfile'"
    if _rc == 0 {
        global CONSORT_SCRIPT_PATH "`scriptfile'"
        exit 0
    }

    * 4. Check PERSONAL directory
    local persdir "`c(sysdir_personal)'"
    if substr("`persdir'", 1, 1) == "~" {
        local rest = substr("`persdir'", 2, .)
        local persdir "`homedir'`rest'"
    }
    local scriptfile "`persdir'consort_diagram.py"
    capture confirm file "`scriptfile'"
    if _rc == 0 {
        global CONSORT_SCRIPT_PATH "`scriptfile'"
        exit 0
    }

    * Not found
    global CONSORT_SCRIPT_PATH ""
end


capture program drop _consort_update_final
program define _consort_update_final
    args final_label force
    if "`force'" == "" local force 0

    * Read current CSV, update last line with final label
    tempname fh

    * Read all lines
    file open `fh' using "${CONSORT_FILE}", read text
    local linenum = 0

    file read `fh' line
    while r(eof) == 0 {
        local linenum = `linenum' + 1
        * Store each line using compound quotes to preserve special chars
        local line`linenum' `"`macval(line)'"'
        file read `fh' line
    }
    file close `fh'

    * Rewrite with final label on last data line
    file open `fh' using "${CONSORT_FILE}", write replace

    forvalues i = 1/`linenum' {
        if `i' == `linenum' {
            * Last line: update remaining field with final label
            * Use macval() to prevent expansion of special chars like $
            local lastline `"`macval(line`i')'"'

            if `force' {
                * Force overwrite: replace remaining field regardless of content
                * Find last ," which marks the start of the remaining field
                local pos = strrpos(`"`macval(lastline)'"', `","')
                if `pos' > 0 {
                    local prefix = substr(`"`macval(lastline)'"', 1, `pos' - 1)
                    file write `fh' `"`macval(prefix)'"' "," _char(34) "`macval(final_label)'" _char(34) _n
                }
                else {
                    * Fallback: line doesn't match expected format
                    file write `fh' `"`macval(lastline)'"' _n
                }
            }
            else {
                * Default: only fill in if remaining field is empty
                local rev = strreverse(`"`macval(lastline)'"')
                local needs_final = 0
                if substr(`"`macval(rev)'"', 1, 1) == "," {
                    local needs_final = 1
                }
                else if substr(`"`macval(rev)'"', 1, 3) == `""""' + "," {
                    * Ends with ,"" (empty quoted field)
                    local needs_final = 1
                }
                if `needs_final' {
                    * Strip trailing ,"" or , and rewrite with final label
                    if substr(`"`macval(rev)'"', 1, 3) == `""""' + "," {
                        local trimmed = strreverse(substr(`"`macval(rev)'"', 4, .))
                    }
                    else {
                        local trimmed = strreverse(substr(`"`macval(rev)'"', 2, .))
                    }
                    file write `fh' `"`macval(trimmed)'"' "," _char(34) "`macval(final_label)'" _char(34) _n
                }
                else {
                    * Line already has remaining label, keep it
                    file write `fh' `"`macval(lastline)'"' _n
                }
            }
        }
        else {
            file write `fh' `"`macval(line`i')'"' _n
        }
    }
    file close `fh'
end
