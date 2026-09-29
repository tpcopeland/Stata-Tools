*! consort Version 1.1.2  2026/09/29
*! Generate CONSORT-style exclusion flowcharts for observational research
*! Author: Timothy P Copeland, Karolinska Institutet
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

    capture noisily {
        * Parse subcommand
        gettoken subcmd 0 : 0, parse(" ,")
        local subcmd = lower(trim("`subcmd'"))

        * Dispatch to subcommand
        if "`subcmd'" == "init" {
            capture noisily _consort_init `macval(0)'
            local sub_rc = _rc
            return add
            if `sub_rc' exit `sub_rc'
        }
        else if "`subcmd'" == "exclude" {
            capture noisily _consort_exclude `macval(0)'
            local sub_rc = _rc
            return add
            if `sub_rc' exit `sub_rc'
        }
        else if "`subcmd'" == "save" {
            capture noisily _consort_save `macval(0)'
            local sub_rc = _rc
            return add
            if `sub_rc' exit `sub_rc'
        }
        else if "`subcmd'" == "clear" {
            capture noisily _consort_clear `macval(0)'
            local sub_rc = _rc
            return add
            if `sub_rc' exit `sub_rc'
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
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname fh
    local fh_open = 0
    capture noisily {

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
            _consort_validate_path, path(`"`file'"') kind("file")
            global CONSORT_TEMPFILE ""
        }

        * Escape double quotes for CSV (double them per RFC 4180)
        local safe_initial : subinstr local initial `"""' `""""', all

        * Format count to prevent scientific notation for very large datasets
        local n_str = string(`n', "%20.0f")
        local n_str = trim("`n_str'")

        * Initialize CSV file
        file open `fh' using "`file'", write replace
        local fh_open = 1
        file write `fh' "label,n,remaining" _n
        file write `fh' `""`macval(safe_initial)'",`n_str',"' _n
        file close `fh'
        local fh_open = 0

        * Store state in globals
        global CONSORT_FILE "`file'"
        global CONSORT_N `n'
        global CONSORT_ACTIVE "1"
        global CONSORT_STEPS "0"

        * Return values
        return scalar N = `n'
        return local initial `"`macval(initial)'"'
        return local file "`file'"

        * Display
        display as text _n "{hline 60}"
        display as text "CONSORT Diagram Initialized"
        display as text "{hline 60}"
        display as text "Initial population:  " as result `"`macval(initial)'"'
        display as text "Observations:        " as result %10.0fc `n'
        display as text "CSV file:            " as result "`file'"
        display as text "{hline 60}"
        display as text "Use {bf:consort exclude} to add exclusion steps"
    }
    local rc = _rc
    if `fh_open' capture file close `fh'
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end


* =============================================================================
* EXCLUDE SUBCOMMAND
* =============================================================================

capture program drop _consort_exclude
program define _consort_exclude, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    local empty_data = (c(k) == 0)
    local kept_n = _N
    set varabbrev off
    tempname fh
    local fh_open = 0
    capture noisily {

        syntax if , LABel(string) [REMaining(string)]

        * Validate label is non-empty
        if trim(`"`macval(label)'"') == "" {
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
        tempvar selected
        marksample selected, novarlist
        quietly count if `selected'
        local n_excl = r(N)

        if `n_excl' == 0 {
            display as text "Note: 0 observations match condition, skipping exclusion"
            return scalar n_excluded = 0
            return scalar n_remaining = _N
            return local label `"`macval(label)'"'
            capture drop `selected'
            if `empty_data' quietly set obs `kept_n'
            set varabbrev `orig_varabbrev'
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
        file open `fh' using "${CONSORT_FILE}", write append
        local fh_open = 1
        file write `fh' `""`macval(safe_label)'",`n_excl_str',"' _char(34) `"`macval(safe_remaining)'"' _char(34) _n
        file close `fh'
        local fh_open = 0

        * Apply exclusion (drop matching observations)
        drop if `selected'
        local kept_n = _N

        * Update state
        local steps = 0${CONSORT_STEPS} + 1
        global CONSORT_STEPS "`steps'"

        * Return values
        return scalar n_excluded = `n_excl'
        return scalar n_remaining = `n_remain'
        return scalar step = `steps'
        return local label `"`macval(label)'"'

        * Display
        local pct : display %5.1f 100 * `n_remain' / 0${CONSORT_N}
        display as text "Step `steps': " as result "Excluded `n_excl'" ///
            as text `" - `macval(label)'"'
        display as text "         Remaining: " as result "`n_remain'" ///
            as text " (`pct'% of initial)"
    }
    local rc = _rc
    capture drop `selected'
    if `empty_data' quietly set obs `kept_n'
    if `fh_open' capture file close `fh'
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end


* =============================================================================
* SAVE SUBCOMMAND
* =============================================================================

capture program drop _consort_save
program define _consort_save, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname fh
    local fh_open = 0
    capture noisily {

        syntax , OUTput(string) [FINal(string) SHADing PYTHON(string) DPI(integer 150) ///
            CSV(string) XLSX(string)]

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

        _consort_validate_path, path(`"`output'"') kind("output")

        * Validate companion data-export paths up front (fail before generating
        * the figure if a directory is missing or a path is malformed)
        if "`csv'" != "" {
            _consort_validate_path, path(`"`csv'"') kind("csv")
        }
        if "`xlsx'" != "" {
            _consort_validate_path, path(`"`xlsx'"') kind("xlsx")
        }

        * Determine if final() was explicitly provided
        local final_explicit = (`"`macval(final)'"' != "")
        if !`final_explicit' {
            local final "Final Cohort"
        }


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

        * Labels travel as data in a file, never as shell syntax.
        tempfile finalfile statusfile
        file open `fh' using "`finalfile'", write replace text
        local fh_open = 1
        file write `fh' `"`macval(final)'"'
        file close `fh'
        local fh_open = 0
        _consort_validate_path, path(`"`python'"') kind("python")
        local cmd `""`python'" "`scriptpath'" "${CONSORT_FILE}" "`output'" --status "`statusfile'" --final-file "`finalfile'""'
        if `final_explicit' local cmd `"`macval(cmd)' --force-final"'
        if "`csv'" != "" local cmd `"`macval(cmd)' --csv-path "`csv'""'
        if "`xlsx'" != "" local cmd `"`macval(cmd)' --xlsx-path "`xlsx'""'
        if "`shading'" != "" local cmd `"`macval(cmd)' --shading"'
        local cmd `"`macval(cmd)' --dpi `dpi'"'
        shell `macval(cmd)'
        local render_rc = 601
        capture confirm file "`statusfile'"
        if !_rc {
            file open `fh' using "`statusfile'", read text
        local fh_open = 1
            file read `fh' result
            file close `fh'
        local fh_open = 0
            if "`result'" == "198" local render_rc = 198
            if "`result'" == "0" local render_rc = 0
        }
        if `render_rc' {
            display as error "failed to generate diagram; check paths, Python and matplotlib"
            display as error `"command attempted: `macval(cmd)'"'
            exit `render_rc'
        }
        confirm file "`output'"

        * Get final counts
        quietly count
        local final_n = r(N)
        local initial_n = 0${CONSORT_N}
        local pct : display %5.1f 100 * `final_n' / `initial_n'
        local excluded = `initial_n' - `final_n'
        local steps = 0${CONSORT_STEPS}

        * Optional companion data export (resolved table for LLMs / downstream use)
        * Built from the SAME CSV the figure is rendered from, so the table always
        * matches the diagram. Done before returns/state-clear: on failure we exit
        * without clearing state so the workflow can be re-run.
        if "`csv'" != "" | "`xlsx'" != "" {
            _consort_export_data, csv(`"`csv'"') xlsx(`"`xlsx'"')
        }

        * Return values
        return scalar N_initial = `initial_n'
        return scalar N_final = `final_n'
        return scalar N_excluded = `excluded'
        return scalar steps = `steps'
        return local output "`output'"
        return local final `"`macval(final)'"'
        if "`csv'" != "" {
            return local csv "`csv'"
        }
        if "`xlsx'" != "" {
            return local xlsx "`xlsx'"
        }

        * Display summary
        display as text _n "{hline 60}"
        display as text "CONSORT Diagram Complete"
        display as text "{hline 60}"
        display as text "Output file:      " as result "`output'"
        if "`csv'" != "" {
            display as text "Data (CSV):       " as result "`csv'"
        }
        if "`xlsx'" != "" {
            display as text "Data (XLSX):      " as result "`xlsx'"
        }
        display as text "Initial N:        " as result %10.0fc `initial_n'
        display as text "Final N:          " as result %10.0fc `final_n'
        display as text "Total excluded:   " as result %10.0fc `excluded'
        display as text "Retention:        " as result "`pct'%"
        display as text "Exclusion steps:  " as result "`steps'"
        display as text "{hline 60}"

        * Clear state after successful save
        _consort_clear_state
    }
    local rc = _rc
    if `fh_open' capture file close `fh'
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end


* =============================================================================
* CLEAR SUBCOMMAND
* =============================================================================

capture program drop _consort_clear
program define _consort_clear
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax [, QUIET]

        if "${CONSORT_ACTIVE}" != "1" & "`quiet'" == "" {
            display as text "No active CONSORT diagram to clear"
            set varabbrev `orig_varabbrev'
            exit 0
        }

        _consort_clear_state

        if "`quiet'" == "" {
            display as text "CONSORT diagram state cleared"
        }
    }
    local rc = _rc
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end


* =============================================================================
* HELPER PROGRAMS
* =============================================================================

capture program drop _consort_clear_state
program define _consort_clear_state
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
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
    }
    local rc = _rc
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _consort_find_script
program define _consort_find_script
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        * Find consort_diagram.py in various locations
        * Note: All paths must be expanded (~ replaced with home directory)
        * because shell commands don't expand ~ when called from Stata

        * Helper: get home directory for ~ expansion
        local homedir : environment HOME

        * 1. Check current directory
        capture confirm file "consort_diagram.py"
        if _rc == 0 {
            global CONSORT_SCRIPT_PATH "consort_diagram.py"
            set varabbrev `orig_varabbrev'
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
            set varabbrev `orig_varabbrev'
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
            set varabbrev `orig_varabbrev'
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
            set varabbrev `orig_varabbrev'
            exit 0
        }

        * Not found
        global CONSORT_SCRIPT_PATH ""
    }
    local rc = _rc
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _consort_validate_path
program define _consort_validate_path
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        * Validate a user-supplied export path: reject shell/quote metacharacters
        * and confirm the target directory exists. kind() is used only in messages.
        syntax , Path(string) Kind(string)

        local _bad = strpos(`"`path'"', ";") + strpos(`"`path'"', "|") + ///
            strpos(`"`path'"', "&") + strpos(`"`path'"', ">") + ///
            strpos(`"`path'"', "<") + strpos(`"`path'"', char(96)) + ///
            strpos(`"`path'"', "$") + strpos(`"`path'"', char(34))
        if `_bad' > 0 {
            display as error "`kind'() path contains invalid characters"
            exit 198
        }

        local slashpos = strrpos(`"`path'"', "/")
        if `slashpos' == 0 {
            local slashpos = strrpos(`"`path'"', "\")
        }
        if `slashpos' > 0 {
            local dir = substr(`"`path'"', 1, `slashpos' - 1)
            mata : st_local("dir_exists", strofreal(direxists(st_local("dir"))))
            if `dir_exists' == 0 {
                display as error "`kind'() directory does not exist: `dir'"
                exit 601
            }
        }
    }
    local rc = _rc
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _consort_export_data
program define _consort_export_data
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        * Build a resolved, one-row-per-node table from the active CONSORT CSV and
        * write it to csv() and/or xlsx(). The table mirrors the rendered diagram:
        * the initial population, each exclusion with its running remaining count,
        * and the percentage of the initial population retained. Reading the same
        * backing CSV the figure is rendered from guarantees the table matches the
        * diagram even when the CSV was edited by hand via init's file() option.
        syntax , [CSV(string) XLSX(string)]

        tempname tblframe
        capture noisily {
            frame create `tblframe'
            frame `tblframe' {
                * Parse the backing CSV using RFC-4180 quoting. Force the label and
                * remaining columns to string so numeric-looking labels are not
                * coerced to numbers.
                import delimited using "${CONSORT_FILE}", varnames(1) ///
                    bindquote(strict) stripquote(default) encoding("utf-8") stringcols(1 3) clear

                * Defensive: ensure expected columns are present and typed
                capture confirm variable remaining
                if _rc {
                    gen str1 remaining = ""
                }
                capture confirm numeric variable n
                if _rc {
                    destring n, replace force
                }

                * Initial population count is the first data row
                local init_n = n[1]

                gen long step = _n - 1
                gen double n_excluded = n if step >= 1
                gen double _cum_excluded = sum(cond(step >= 1, n, 0))
                gen double n_remaining = `init_n' - _cum_excluded
                * Store percent as a clean 2-decimal string: a double cannot
                * represent values like 93.24 exactly, and export delimited writes
                * full precision, which would litter the file with float artifacts.
                gen str10 pct_of_initial = ///
                    string(100 * n_remaining / `init_n', "%9.2f")

                * In the backing CSV: label = exclusion reason and remaining =
                * cohort/node label after the step. On the initial row the label is
                * the initial population label and there is no exclusion.
                rename label exclusion_label
                rename remaining cohort_label
                replace cohort_label = exclusion_label if step == 0
                replace exclusion_label = "" if step == 0

                drop n _cum_excluded
                order step cohort_label n_remaining exclusion_label n_excluded ///
                    pct_of_initial

                format n_remaining n_excluded %15.0fc

                label variable step "Step (0 = initial population)"
                label variable cohort_label "Cohort label after this step"
                label variable n_remaining "N remaining in cohort"
                label variable exclusion_label "Exclusion applied at this step"
                label variable n_excluded "N excluded at this step"
                label variable pct_of_initial "Percent of initial population remaining"

                if "`csv'" != "" {
                    export delimited using "`csv'", replace
                }
                if "`xlsx'" != "" {
                    export excel using "`xlsx'", firstrow(variables) replace
                }
            }
        }
        local _exp_rc = _rc
        capture frame drop `tblframe'
        if `_exp_rc' {
            display as error "failed to write companion data export (csv/xlsx)"
            exit `_exp_rc'
        }
    }
    local rc = _rc
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end
