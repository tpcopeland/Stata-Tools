*! consort Version 1.0.1  2025/12/15
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
    set varabbrev off

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
end


* =============================================================================
* INIT SUBCOMMAND
* =============================================================================

capture program drop _consort_init
program define _consort_init, rclass
    version 16.0
    set varabbrev off

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
        * Use c(tmpdir) and a unique name based on process ID and timestamp
        local tmpdir "`c(tmpdir)'"
        local pid "`c(pi)'"  // Use pi as a pseudo-unique number
        local ts = clock("`c(current_date)' `c(current_time)'", "DMYhms")
        local file "`tmpdir'/consort_`ts'.csv"
        global CONSORT_TEMPFILE "`file'"
    }
    else {
        global CONSORT_TEMPFILE ""
    }

    * Initialize CSV file
    tempname fh
    file open `fh' using "`file'", write replace
    file write `fh' "label,n,remaining" _n
    file write `fh' `""`initial'",`n',"' _n
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
    set varabbrev off

    syntax if , LABel(string) [REMaining(string)]

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
        exit 0
    }

    * Apply exclusion (drop matching observations)
    drop `if'

    * Count remaining
    quietly count
    local n_remain = r(N)

    * Append to CSV file
    tempname fh
    file open `fh' using "${CONSORT_FILE}", write append
    file write `fh' `""`label'",`n_excl',`remaining'"' _n
    file close `fh'

    * Update state
    global CONSORT_STEPS = ${CONSORT_STEPS} + 1

    * Return values
    return scalar n_excluded = `n_excl'
    return scalar n_remaining = `n_remain'
    return scalar step = ${CONSORT_STEPS}
    return local label "`label'"

    * Display
    local pct : display %5.1f 100 * `n_remain' / ${CONSORT_N}
    display as text "Step ${CONSORT_STEPS}: " as result "Excluded `n_excl'" ///
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
    set varabbrev off

    syntax , OUTput(string) [FINal(string) SHADing PYTHON(string) DPI(integer 150)]

    * Check if diagram is active
    if "${CONSORT_ACTIVE}" != "1" {
        display as error "CONSORT diagram not initialized"
        display as error "use {bf:consort init} first"
        exit 198
    }

    * Check for at least one exclusion
    if ${CONSORT_STEPS} == 0 {
        display as error "no exclusion steps recorded"
        display as error "use {bf:consort exclude} to add at least one exclusion"
        exit 198
    }

    * Set final cohort label
    if "`final'" == "" {
        local final "Final Cohort"
    }

    * Update last row with final label if needed
    _consort_update_final "`final'"

    * Find Python executable
    if "`python'" == "" {
        local python "python"
        * Try python3 first on Unix systems
        if "`c(os)'" != "Windows" {
            capture shell which python3 > /dev/null 2>&1
            if _rc == 0 {
                local python "python3"
            }
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

    * Build command with options
    local cmd `"`python' "`scriptpath'" "${CONSORT_FILE}" "`output'""'
    if "`shading'" != "" {
        local cmd `"`cmd' --shading"'
    }
    if `dpi' != 150 {
        local cmd `"`cmd' --dpi `dpi'"'
    }

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
    local initial_n = ${CONSORT_N}
    local pct : display %5.1f 100 * `final_n' / `initial_n'
    local excluded = `initial_n' - `final_n'

    * Return values
    return scalar N_initial = `initial_n'
    return scalar N_final = `final_n'
    return scalar N_excluded = `excluded'
    return scalar steps = ${CONSORT_STEPS}
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
    display as text "Exclusion steps:  " as result ${CONSORT_STEPS}
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
    set varabbrev off

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

    * 3. Check py subdirectory of PLUS directory (where Stata installs .py files)
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
    args final_label

    * Read current CSV, update last line with final label
    tempname fh

    * Read all lines into a temporary dataset approach instead
    * This avoids macro expansion issues with special characters like $

    * First, read file line by line and count
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
            * Last line - append final label if not already present
            * Use macval() to prevent expansion of special chars like $
            local lastline `"`macval(line`i')'"'
            * Check if line already has a remaining label (ends with something after last comma)
            local pos = strpos(strreverse(`"`macval(lastline)'"'), ",")
            if `pos' == 1 {
                * Line ends with comma, no remaining label yet
                file write `fh' `"`macval(lastline)'`final_label'"' _n
            }
            else {
                * Line already has remaining label, keep it
                file write `fh' `"`macval(lastline)'"' _n
            }
        }
        else {
            file write `fh' `"`macval(line`i')'"' _n
        }
    }
    file close `fh'
end
