*! codescan Version 2.0.9  2026/07/09
*! Scan wide-format code variables for pattern matches and collapse to patient-level
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())
*! Requires: Stata 16.0+

/*
DESCRIPTION:
    Scans wide-format code variables (dx1-dx30, proc1-proc20, etc.) for
    pattern matches using regex or prefix matching. Generates binary
    indicators for each condition, optionally applies time windows, and
    collapses to patient-level summaries with date statistics.

    Works with any string code system: ICD, KVA, CPT, ATC, OPCS, etc.

SYNTAX:
    codescan varlist [if] [in], define(string asis) | codefile(string)
        [ID(varname) DATE(varname) REFDate(varname)
         LOOKBack(string) LOOKForward(integer) INCLusive
         EARLIESTdate LATESTdate COUNTdate COUNTRows ALLDates
         LABel(string asis) COLLapse MERge MODe(string) REPlace NOIsily
         DETail NODots TOSTRing PREserve FRAME(name) COOCcurrence
         NOCase GENerate(string)
         UNMatched(name) MATCHed_code(name) LEVel(integer) GRaph EXPort(string)
         SAVE(string) SAVing(string asis) FORmat(string) COUNTMode]

EXAMPLES:
    * Row-level indicators
    codescan dx1-dx30, define(dm2 "E11" | obesity "E66")

    * Exclusion patterns
    codescan dx1-dx30, define(dm2 "E11" ~ "E116" | htn "I1[0-35]")

    * Load definitions from file
    codescan dx1-dx30, codefile(code_rules.csv) id(pid) collapse

    * Non-destructive collapse into a frame
    codescan dx1-dx30, define(dm2 "E11") id(pid) collapse frame(results)

STORED RESULTS:
    r(N)              - Number of observations (post-collapse if collapsed)
    r(n_conditions)   - Number of conditions defined
    r(collapsed)      - 1 if collapse was performed, 0 otherwise
    r(merged)         - 1 if merge was performed, 0 otherwise
    r(conditions)     - Space-separated condition names
    r(newvars)        - Variables present on exit (indicators + retained outputs)
    r(varlist)        - Variables scanned
    r(mode)           - Matching mode (regex or prefix)
    r(define)         - Full define specification string (if used)
    r(codefile)       - Path to code definitions file (if used)
    r(id)             - ID variable (if specified)
    r(date)           - Date variable (if specified)
    r(lookback)       - Lookback days (if specified; space-separated if multi-window)
    r(lookforward)    - Lookforward days (if specified)
    r(refdate)        - Reference date variable (if specified)
    r(n_excluded_missingdate) - Rows dropped from the time window for a missing
                        date()/refdate() (if lookback()/lookforward() specified)
    r(frame)          - Frame name (if frame() specified)
    r(nocase)         - "nocase" if case-insensitive matching was used
    r(generate)       - Output-name prefix (if generate() specified)
    r(mode_count)     - 1 if countmode specified, 0 otherwise
    r(ci_level)       - Confidence level for the prevalence CIs
    r(summary)        - Matrix of counts, prevalences, and Wilson 95% CIs
    r(codelist)       - Matrix: count, prevalence per condition
    r(varcounts)      - Per-variable match counts (if detail specified)
    r(cooccurrence)   - Pairwise co-occurrence matrix (if cooccurrence specified)
    r(sensitivity)    - Multi-window comparison matrix (if multi-window lookback)
*/

program define codescan, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist [if] [in] , [DEFine(string asis) CODEFile(string) ///
        ID(varname) DATE(varname) REFDate(varname) ///
        LOOKBack(string) LOOKForward(integer -1) INCLusive ///
        EARLIESTdate LATESTdate COUNTdate COUNTRows ALLDates ///
        LABel(string asis) COLLapse MERge MODe(string) REPlace NOIsily ///
        DETail NODots TOSTRing PREserve FRAME(name) COOCcurrence ///
        NOCase GENerate(string) ///
        UNMatched(name) MATCHed_code(name) LEVel(integer 0) ///
        GRaph EXPort(string) SAVE(string) SAVing(string asis) ///
        FORmat(string) COUNTMode]

    * =========================================================================
    * LOAD OUTPUT-PLANNING HELPERS
    * =========================================================================
    capture program list _codescan_plan_outputs
    local _need_outputs_helper = _rc
    capture program list _codescan_cleanup_outputs
    if _rc local _need_outputs_helper = 1
    if `_need_outputs_helper' {
        capture findfile _codescan_outputs.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_codescan_outputs.ado not found; reinstall codescan"
            exit 111
        }
    }

    * =========================================================================
    * ALLDATES SHORTHAND
    * =========================================================================
    if "`alldates'" != "" {
        local earliestdate "earliestdate"
        local latestdate "latestdate"
        local countdate "countdate"
    }

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================

    * Require exactly one of define()/codefile()
    if `"`define'"' == "" & "`codefile'" == "" {
        display as error "define() or codefile() is required"
        exit 198
    }
    if `"`define'"' != "" & "`codefile'" != "" {
        display as error "define() and codefile() cannot both be specified"
        exit 198
    }

    * Guard every user-supplied file path before any file operation.
    if `"`codefile'"' != "" {
        _codescan_validate_path, path(`"`codefile'"') context(codefile())
    }

    * Reject a variable that appears more than once in varlist (directly or via
    * overlapping ranges like dx1-dx5 dx3-dx8). A repeated scan column is read
    * once per occurrence, so under countmode/countrows/detail its codes are
    * counted multiple times — a silent inflation with rc=0. Binary indicators
    * are idempotent, but the count paths are not, so reject the ambiguity.
    local _dupvars : list dups varlist
    if `"`_dupvars'"' != "" {
        display as error "varlist contains repeated variable(s): `_dupvars'"
        display as error "remove duplicate or overlapping scan variables"
        exit 198
    }

    * All varlist variables must be string (numeric is allowed only when
    * tostring will convert it).  strL is rejected unconditionally: the Mata
    * scanner reads columns with st_sview(), which cannot form views onto strL
    * variables (r(3300) with a raw Mata traceback).
    foreach var of local varlist {
        capture confirm string variable `var'
        if _rc {
            if "`tostring'" == "" {
                display as error "`var' is not a string variable"
                display as error "codescan requires string variables; use tostring or the tostring option"
                exit 109
            }
        }
        else if "`: type `var''" == "strL" {
            display as error "`var' is a strL variable and cannot be scanned"
            display as error "convert it to a fixed-width string first, e.g. {bf:compress `var'} or {bf:recast str244 `var'}"
            exit 109
        }
    }

    * Mode validation
    if "`mode'" == "" local mode "regex"
    if "`mode'" != "regex" & "`mode'" != "prefix" {
        display as error "mode() must be {bf:regex} or {bf:prefix}"
        exit 198
    }

    * Parse lookback — accepts integers or standard numlists (e.g. 30(30)90)
    local _n_excl_missdate = 0
    local has_lookback = (`"`lookback'"' != "")
    local n_lookback_windows = 0
    local _lookback_primary = -1
    if `has_lookback' {
        * Expand numlist (supports 30(30)90, 90/365, etc.)
        capture numlist "`lookback'", integer min(1)
        if _rc {
            display as error "lookback(): invalid numlist"
            exit 198
        }
        local lookback "`r(numlist)'"
        local n_lookback_windows : word count `lookback'
        forvalues _lbi = 1/`n_lookback_windows' {
            local _lb_val : word `_lbi' of `lookback'
            if `_lb_val' < 0 {
                display as error "lookback() must contain non-negative integers"
                exit 198
            }
            local _lookback_`_lbi' = `_lb_val'
        }
        local _lookback_primary = `_lookback_1'
        if `n_lookback_windows' > 1 {
            * Multi-window mode requires collapse
            if "`collapse'" == "" & "`merge'" == "" {
                display as error "multi-window lookback() requires collapse or merge"
                exit 198
            }
        }
    }

    * Time window validation
    local has_lookfwd  = (`lookforward' != -1)

    if `has_lookfwd' & `lookforward' < 0 {
        display as error "lookforward() must be a non-negative integer"
        exit 198
    }

    if (`has_lookback' | `has_lookfwd') & ("`date'" == "" | "`refdate'" == "") {
        display as error "lookback()/lookforward() require both date() and refdate()"
        exit 198
    }

    * Merge validation
    if "`merge'" != "" & "`id'" == "" {
        display as error "merge requires id()"
        exit 198
    }
    if "`merge'" != "" & "`collapse'" != "" {
        display as error "merge and collapse cannot both be specified"
        exit 198
    }

    * Level validation
    if `level' != 0 {
        if `level' < 1 | `level' > 10 {
            display as error "level() must be between 1 and 10"
            exit 198
        }
        if "`mode'" == "regex" {
            display as text "(note: level() applies only in mode(prefix); ignored in regex mode)"
        }
    }

    * Export validation
    if `"`export'"' != "" {
        _codescan_validate_path, path(`"`export'"') context(export())
        local _exp_ext = lower(substr(`"`export'"', -4, .))
        local _exp_ext5 = lower(substr(`"`export'"', -5, .))
        if "`_exp_ext'" != ".csv" & "`_exp_ext'" != ".xlsx" & "`_exp_ext5'" != ".xlsx" {
            display as error "export() must be a .csv or .xlsx file"
            exit 198
        }
    }

    * Format validation
    if "`format'" != "" {
        capture local _fmt_test : display `format' 12.345
        if _rc {
            display as error "format(): `format' is not a valid numeric display format"
            exit 198
        }
    }
    local _prev_fmt = cond("`format'" != "", "`format'", "%9.1f")
    local _ci_fmt   = cond("`format'" != "", "`format'", "%5.1f")

    * saving() validation (distinct from save() which saves the define to CSV)
    local _saving_replace = 0
    if `"`saving'"' != "" {
        if "`collapse'" == "" & "`merge'" == "" {
            display as error "saving() requires collapse or merge"
            exit 198
        }
        * Split filename from suboptions at the first comma outside quotes, so
        * a quoted filename may itself contain a comma.
        local _saving_len = length(`"`saving'"')
        local _comma_pos = 0
        local _saving_in_quotes = 0
        forvalues _c = 1/`_saving_len' {
            if substr(`"`saving'"', `_c', 1) == char(34) {
                local _saving_in_quotes = !`_saving_in_quotes'
            }
            else if substr(`"`saving'"', `_c', 1) == char(44) & !`_saving_in_quotes' {
                local _comma_pos = `_c'
                continue, break
            }
        }
        if `_comma_pos' > 0 {
            local _saving_fn  = strtrim(substr(`"`saving'"', 1, `_comma_pos' - 1))
            local _saving_sub = strtrim(substr(`"`saving'"', `_comma_pos' + 1, .))
            if lower(`"`_saving_sub'"') == "replace" {
                local _saving_replace = 1
            }
            else if `"`_saving_sub'"' != "" {
                display as error `"saving(): unknown suboption `_saving_sub' (only replace is allowed)"'
                exit 198
            }
        }
        else {
            local _saving_fn = strtrim(`"`saving'"')
        }
        * Strip surrounding quotes from filename
        * handles: "path" (regular) and `"path"' (compound, from string asis option)
        if substr(`"`_saving_fn'"', 1, 1) == char(96) {
            * compound-quote wrapped: `"path"' — strip 2 chars at start, 2 at end
            local _saving_fn = substr(`"`_saving_fn'"', 3, length(`"`_saving_fn'"') - 4)
        }
        else if substr(`"`_saving_fn'"', 1, 1) == `"""' {
            * regular double-quote wrapped: "path"
            local _saving_fn = substr(`"`_saving_fn'"', 2, length(`"`_saving_fn'"') - 2)
        }
        if `"`_saving_fn'"' == "" {
            display as error "saving() requires a filename"
            exit 198
        }
        _codescan_validate_path, path(`"`_saving_fn'"') context(saving())
    }

    * Validate date/refdate are numeric
    if "`date'" != "" {
        confirm numeric variable `date'
    }
    if "`refdate'" != "" {
        confirm numeric variable `refdate'
    }

    * Collapse validation
    if "`collapse'" != "" & "`id'" == "" {
        display as error "collapse requires id()"
        exit 198
    }

    * Date summary options require date + collapse/merge
    if ("`earliestdate'" != "" | "`latestdate'" != "" | "`countdate'" != "") {
        if "`date'" == "" {
            display as error "earliestdate, latestdate, and countdate require date()"
            exit 198
        }
        if "`collapse'" == "" & "`merge'" == "" {
            display as error "earliestdate, latestdate, and countdate require collapse or merge"
            exit 198
        }
    }

    * countrows requires collapse or merge
    if "`countrows'" != "" {
        if "`collapse'" == "" & "`merge'" == "" {
            display as error "countrows requires collapse or merge"
            exit 198
        }
    }

    * Inclusive requires lookback or lookforward
    if "`inclusive'" != "" & !`has_lookback' & !`has_lookfwd' {
        display as error "inclusive requires lookback() or lookforward()"
        exit 198
    }

    * preserve/frame require collapse or merge
    if "`preserve'" != "" & "`collapse'" == "" & "`merge'" == "" {
        display as error "preserve requires collapse or merge"
        exit 198
    }
    if "`frame'" != "" & "`collapse'" == "" & "`merge'" == "" {
        display as error "frame() requires collapse or merge"
        exit 198
    }
    * frame() implies preserve
    if "`frame'" != "" {
        local preserve "preserve"
    }
    * Validate frame name
    if "`frame'" != "" {
        capture confirm name `frame'
        if _rc {
            display as error "frame(): `frame' is not a valid frame name"
            exit 198
        }
        * Check if frame already exists
        capture confirm frame `frame'
        if !_rc & "`replace'" == "" {
            display as error "frame `frame' already exists; use replace option"
            exit 110
        }
    }

    * Warn on lookback(0)/lookforward(0) without inclusive (empty window)
    if `has_lookback' & `_lookback_primary' == 0 & "`inclusive'" == "" & !`has_lookfwd' {
        display as text "(note: lookback(0) without inclusive excludes refdate, yielding an empty window)"
    }
    if `has_lookfwd' & `lookforward' == 0 & "`inclusive'" == "" & !`has_lookback' {
        display as text "(note: lookforward(0) without inclusive excludes refdate, yielding an empty window)"
    }

    * =========================================================================
    * PARSE CODEFILE()
    * =========================================================================
    local n_conditions = 0
    local all_names ""
    local n_labels = 0
    local _defsrc = cond("`codefile'" != "", "codefile()", "define()")

    capture program list _codescan_parse_define
    local _need_definitions_helper = _rc
    capture program list _codescan_apply_generate
    if _rc local _need_definitions_helper = 1
    capture program list _codescan_validate_def_regex
    if _rc local _need_definitions_helper = 1
    capture program list _codescan_apply_level
    if _rc local _need_definitions_helper = 1
    capture program list _codescan_validate_def_prefix
    if _rc local _need_definitions_helper = 1
    if `_need_definitions_helper' {
        capture findfile _codescan_definitions.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_codescan_definitions.ado not found; reinstall codescan"
            exit 111
        }
    }

    if "`codefile'" != "" {
        local _orig_codefile "`codefile'"
        capture program list _codescan_parse_codefile
        local _need_codefile_helper = _rc
        if `_need_codefile_helper' {
            capture findfile _codescan_codefile.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
            else {
                display as error "_codescan_codefile.ado not found; reinstall codescan"
                exit 111
            }
        }

        _codescan_parse_codefile, codefile(`"`codefile'"')
        local n_conditions = r(n_conditions)
        local all_names "`r(all_names)'"
        local n_labels = r(n_labels)
        local codefile `"`r(resolved_codefile)'"'
        forvalues i = 1/`n_conditions' {
            local def_name_`i' "`r(def_name_`i')'"
            local def_pattern_`i' `"`r(def_pattern_`i')'"'
            local def_excl_`i' `"`r(def_excl_`i')'"'
        }
        if `n_labels' > 0 {
            forvalues i = 1/`n_labels' {
                local lab_name_`i' "`r(lab_name_`i')'"
                local lab_label_`i' `"`r(lab_label_`i')'"'
            }
        }
    }

    * =========================================================================
    * PARSE DEFINE()
    * =========================================================================
    else {
        local _define_arg = subinstr(`"`macval(define)'"', `"""', char(1), .)
        local _define_arg = subinstr(`"`macval(_define_arg)'"', "(", char(4), .)
        local _define_arg = subinstr(`"`macval(_define_arg)'"', ")", char(2), .)
        local _define_arg = subinstr(`"`macval(_define_arg)'"', ",", char(3), .)
        _codescan_parse_define, define(`macval(_define_arg)')
        local n_conditions = r(n_conditions)
        local all_names "`r(all_names)'"
        forvalues i = 1/`n_conditions' {
            local def_name_`i' "`r(def_name_`i')'"
            local def_pattern_`i' `"`r(def_pattern_`i')'"'
            local def_excl_`i' `"`r(def_excl_`i')'"'
        }
    }

    * =========================================================================
    * APPLY GENERATE PREFIX (F3)
    * =========================================================================
    if "`generate'" != "" {
        local all_names ""
        forvalues i = 1/`n_conditions' {
            _codescan_apply_generate, prefix(`macval(generate)') ///
                name(`macval(def_name_`i')') suffixlen(6)
            local def_name_`i' "`r(name)'"
            local all_names "`all_names' `def_name_`i''"
        }
        local all_names = trim("`all_names'")
        * Also update label names
        forvalues j = 1/`n_labels' {
            _codescan_apply_generate, prefix(`macval(generate)') ///
                name(`macval(lab_name_`j')') suffixlen(6)
            local lab_name_`j' "`r(name)'"
        }
    }

    * =========================================================================
    * REGEX PRE-VALIDATION (R1) — structural check + compile-probe
    * =========================================================================
    * Stata's regexm() is lenient and silently returns 0 on invalid patterns —
    * a false-zero cohort with no error. _codescan_validate_def_regex first runs
    * a structural delimiter check (clear "unmatched ')'" / "unclosed '['"
    * messages) and then a ustrregexm() compile-probe that rejects every other
    * malformed pattern (bad quantifiers, groups, alternations). See
    * _codescan_definitions.ado.
    if "`mode'" == "regex" {
        forvalues i = 1/`n_conditions' {
            local _pat_arg `"`macval(def_pattern_`i')'"'
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', `"""', char(1), .)
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', "(", char(4), .)
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', ")", char(2), .)
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', ",", char(3), .)
            local _excl_arg `"`macval(def_excl_`i')'"'
            local _excl_arg = subinstr(`"`macval(_excl_arg)'"', `"""', char(1), .)
            local _excl_arg = subinstr(`"`macval(_excl_arg)'"', "(", char(4), .)
            local _excl_arg = subinstr(`"`macval(_excl_arg)'"', ")", char(2), .)
            local _excl_arg = subinstr(`"`macval(_excl_arg)'"', ",", char(3), .)
            _codescan_validate_def_regex, ///
                name(`macval(def_name_`i')') ///
                pattern(`macval(_pat_arg)') ///
                exclusion(`macval(_excl_arg)')
        }
    }
    else {
        forvalues i = 1/`n_conditions' {
            local _pat_arg `"`macval(def_pattern_`i')'"'
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', `"""', char(1), .)
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', "(", char(4), .)
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', ")", char(2), .)
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', ",", char(3), .)
            local _excl_arg `"`macval(def_excl_`i')'"'
            local _excl_arg = subinstr(`"`macval(_excl_arg)'"', `"""', char(1), .)
            local _excl_arg = subinstr(`"`macval(_excl_arg)'"', "(", char(4), .)
            local _excl_arg = subinstr(`"`macval(_excl_arg)'"', ")", char(2), .)
            local _excl_arg = subinstr(`"`macval(_excl_arg)'"', ",", char(3), .)
            _codescan_validate_def_prefix, ///
                name(`macval(def_name_`i')') ///
                pattern(`macval(_pat_arg)') ///
                exclusion(`macval(_excl_arg)')
        }
    }

    * =========================================================================
    * LEVEL() — truncate patterns to N characters (C4)
    * =========================================================================
    if `level' > 0 & "`mode'" == "prefix" {
        forvalues i = 1/`n_conditions' {
            local _pat_arg `"`macval(def_pattern_`i')'"'
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', `"""', char(1), .)
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', "(", char(4), .)
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', ")", char(2), .)
            local _pat_arg = subinstr(`"`macval(_pat_arg)'"', ",", char(3), .)
            _codescan_apply_level, pattern(`macval(_pat_arg)') level(`level')
            local def_pattern_`i' `"`r(pattern)'"'
        }
    }

    * =========================================================================
    * VALIDATE CONDITION NAMES
    * =========================================================================
    * Valid Stata names, <=26 chars (or <=26 after prefix), unique, no collisions
    forvalues i = 1/`n_conditions' {
        local nm "`def_name_`i''"
        capture confirm name `nm'
        if _rc {
            display as error "`_defsrc': `nm' is not a valid Stata name"
            exit 198
        }
        if strlen("`nm'") > 26 {
            display as error "`_defsrc': `nm' exceeds 26 characters (need room for _first/_count/_nrows suffix)"
            exit 198
        }
        * Check uniqueness
        forvalues j = 1/`=`i'-1' {
            if "`nm'" == "`def_name_`j''" {
                display as error "`_defsrc': duplicate condition name `nm'"
                exit 198
            }
        }
        * Check name does not collide with input variables
        foreach v of local varlist {
            if "`nm'" == "`v'" {
                display as error "`_defsrc': condition name `nm' conflicts with a varlist variable"
                exit 198
            }
        }
        if "`nm'" == "`id'" | "`nm'" == "`date'" | "`nm'" == "`refdate'" {
            display as error "`_defsrc': condition name `nm' conflicts with id, date, or refdate variable"
            exit 198
        }
        if `"`export'"' != "" {
            if inlist("`nm'", "condition", "matches", "prevalence", "pattern", "exclusion", "ci_low", "ci_high") {
                display as error "`_defsrc': condition name `nm' conflicts with a reserved export column name"
                exit 198
            }
        }
    }

    * Validate every created output up front so replace cannot clobber scan
    * inputs before the row scanner runs.
    _codescan_plan_outputs, conditions("`all_names'") scanvars("`varlist'") ///
        protected("`id' `date' `refdate'") ///
        unmatched("`unmatched'") ///
        matched_code("`matched_code'") `collapse' `merge' `earliestdate' ///
        `latestdate' `countdate' `countrows' `replace'
    local _n_outputs = r(n_outputs)
    local _outputs "`r(outputs)'"
    forvalues i = 1/`_n_outputs' {
        local _output_`i' "`r(output_`i')'"
    }
    local _outputs_created = 0

    * =========================================================================
    * PARSE LABEL()
    * =========================================================================
    * Note: codefile labels already populated above; label() can override them
    if `"`label'"' != "" {
        local lab_remaining `"`label'"'
        while `"`lab_remaining'"' != "" {
            * Find the first backslash that is OUTSIDE a quoted string so the
            * "\" entry separator can still be used, while a backslash inside
            * quoted label text (e.g. a Windows path "C:\dir") does not split
            * the entry mid-quote. Toggle in_quotes on each double-quote.
            local _lr_len = length(`"`lab_remaining'"')
            local bspos = 0
            local _inq  = 0
            forvalues _c = 1/`_lr_len' {
                local _ch = substr(`"`lab_remaining'"', `_c', 1)
                if `"`_ch'"' == `"""' {
                    local _inq = !`_inq'
                }
                else if `"`_ch'"' == "\" & !`_inq' {
                    local bspos = `_c'
                    continue, break
                }
            }
            if `bspos' > 0 {
                local lab_segment = substr(`"`lab_remaining'"', 1, `bspos' - 1)
                local lab_remaining = substr(`"`lab_remaining'"', `bspos' + 1, .)
            }
            else {
                local lab_segment `"`lab_remaining'"'
                local lab_remaining ""
            }
            local lab_segment = strtrim(`"`lab_segment'"')
            if `"`lab_segment'"' == "" continue

            * gettoken: first token = name, remaining = label text
            gettoken lab_nm lab_txt : lab_segment
            * gettoken strips quotes from the extracted token but NOT from
            * the remaining part. Strip outer quotes from label text.
            local lab_txt = strtrim(`"`lab_txt'"')
            if substr(`"`lab_txt'"', 1, 1) == `"""' {
                local lab_txt = substr(`"`lab_txt'"', 2, strlen(`"`lab_txt'"') - 2)
            }

            if "`lab_nm'" == "" | `"`lab_txt'"' == "" {
                display as error "label(): each entry needs a name and label text"
                exit 198
            }

            local ++n_labels
            local lab_name_`n_labels' "`lab_nm'"
            local lab_label_`n_labels' `"`lab_txt'"'
        }

        * Validate label names match condition names (with generate-prefix fallback)
        forvalues j = 1/`n_labels' {
            local found = 0
            forvalues k = 1/`n_conditions' {
                if "`lab_name_`j''" == "`def_name_`k''" {
                    local found = 1
                }
            }
            if !`found' & "`generate'" != "" {
                local _lab_pref "`generate'`lab_name_`j''"
                forvalues k = 1/`n_conditions' {
                    if "`_lab_pref'" == "`def_name_`k''" {
                        local found = 1
                        local lab_name_`j' "`_lab_pref'"
                    }
                }
            }
            if !`found' {
                display as error `"label(): `lab_name_`j'' does not match any condition in `_defsrc'"'
                exit 198
            }
        }
    }

    * =========================================================================
    * SAVE DEFINE TO CSV (W3)
    * =========================================================================
    if `"`save'"' != "" {
        _codescan_validate_path, path(`"`save'"') context(save())
        local _save_ext = lower(substr(`"`save'"', -4, .))
        if "`_save_ext'" != ".csv" {
            display as error "save() requires a .csv file extension"
            exit 198
        }
        if "`codefile'" != "" {
            display as error "save() cannot be combined with codefile(); codefile already provides a file"
            exit 198
        }
        preserve
        quietly {
            clear
            set obs `n_conditions'
            gen str32 name = ""
            gen str244 pattern = ""
            gen str244 exclusion = ""
            gen str80 label = ""
            forvalues i = 1/`n_conditions' {
                local _sv_nm "`def_name_`i''"
                * Strip generate() prefix if present
                if "`generate'" != "" {
                    local _sv_nm = substr("`_sv_nm'", strlen("`generate'") + 1, .)
                }
                replace name = "`_sv_nm'" in `i'
                replace pattern = `"`def_pattern_`i''"' in `i'
                replace exclusion = `"`def_excl_`i''"' in `i'
                forvalues j = 1/`n_labels' {
                    if "`lab_name_`j''" == "`def_name_`i''" {
                        replace label = `"`lab_label_`j''"' in `i'
                    }
                }
            }
            export delimited using `"`save'"', replace
        }
        restore
        display as text `"(define() saved to `save')"'
    }

    * =========================================================================
    * USER PRESERVE (for non-destructive collapse)
    * =========================================================================
    if "`preserve'" != "" {
        preserve
    }

    * =========================================================================
    * MARK SAMPLE & TIME WINDOW
    * =========================================================================
    * Note: cannot use marksample — string asis puts quotes in `0' which
    * breaks marksample's parser. Use mark for if/in only.
    * Do NOT markout the varlist: empty strings in code variables are expected.
    * Mark BEFORE tostring so an if-expression that references a scan variable
    * is evaluated against the data as the user sees it at call time (numeric),
    * not after tostring has recast it to string.
    tempvar touse
    mark `touse' `if' `in'

    * =========================================================================
    * TOSTRING (auto-convert numeric variables)
    * =========================================================================
    local scan_varlist ""
    local _scan_index = 0
    foreach var of local varlist {
        local ++_scan_index
        capture confirm string variable `var'
        if _rc {
            noisily display as text "(note: converting `var' from numeric to string)"
            tempvar _scan_string_`_scan_index'
            quietly tostring `var', generate(`_scan_string_`_scan_index'') force
            local scan_varlist "`scan_varlist' `_scan_string_`_scan_index''"
        }
        else {
            local scan_varlist "`scan_varlist' `var'"
        }
    }
    local scan_varlist = trim("`scan_varlist'")

    * Exclude missing id values from collapse/merge to prevent phantom grouping
    if "`collapse'" != "" | "`merge'" != "" {
        quietly replace `touse' = 0 if missing(`id')
    }

    local include_ref = ("`inclusive'" != "" | (`has_lookback' & `has_lookfwd'))

    if `has_lookback' | `has_lookfwd' {
        * Rows with a missing date()/refdate() cannot be placed in the time
        * window and are dropped from every condition. In row-level mode this
        * silently zeroes a genuinely-matching code, so report the count (and
        * expose it via r(n_excluded_missingdate)) rather than failing quietly.
        quietly count if `touse' & (missing(`date') | missing(`refdate'))
        local _n_excl_missdate = r(N)
        if `_n_excl_missdate' > 0 {
            display as text "(note: `_n_excl_missdate' row(s) excluded from the time window for missing date()/refdate())"
        }
        quietly replace `touse' = 0 if missing(`date') | missing(`refdate')
    }

    if `has_lookback' & `has_lookfwd' {
        * Both: [refdate - lookback, refdate + lookforward] — always inclusive
        quietly replace `touse' = 0 if `date' < `refdate' - `_lookback_primary'
        quietly replace `touse' = 0 if `date' > `refdate' + `lookforward'
    }
    else if `has_lookback' {
        * Lookback only
        quietly replace `touse' = 0 if `date' < `refdate' - `_lookback_primary'
        if `include_ref' {
            quietly replace `touse' = 0 if `date' > `refdate'
        }
        else {
            quietly replace `touse' = 0 if `date' >= `refdate'
        }
    }
    else if `has_lookfwd' {
        * Lookforward only
        quietly replace `touse' = 0 if `date' > `refdate' + `lookforward'
        if `include_ref' {
            quietly replace `touse' = 0 if `date' < `refdate'
        }
        else {
            quietly replace `touse' = 0 if `date' <= `refdate'
        }
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }
    local N = r(N)

    * =========================================================================
    * NODOTS — handled inline in Mata scanner (no temp variables needed)
    * =========================================================================
    local nvars_scan : word count `varlist'

    * =========================================================================
    * DETAIL SETUP — per-variable match tracking
    * =========================================================================
    if "`detail'" != "" {
        tempname varcounts
        matrix `varcounts' = J(`n_conditions', `nvars_scan', 0)
    }

    * =========================================================================
    * CREATE ROW-LEVEL INDICATORS (Mata-accelerated)
    * =========================================================================
    local _outputs_created = 1
    quietly {
        * Drop/create indicator variables
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            if "`replace'" != "" {
                capture drop `name'
                if "`collapse'" != "" | "`merge'" != "" {
                    if "`earliestdate'" != "" capture drop `name'_first
                    if "`latestdate'" != ""   capture drop `name'_last
                    if "`countdate'" != ""    capture drop `name'_count
                    if "`countrows'" != ""   capture drop `name'_nrows
                }
            }
            if "`countmode'" != "" {
                gen long `name' = 0
            }
            else {
                gen byte `name' = 0
            }
        }

        * Pass condition info to Mata via locals
        local _mata_ncond "`n_conditions'"
        local _mata_mode "`mode'"
        local _mata_scanvars "`scan_varlist'"
        local _mata_touse "`touse'"
        local _mata_detail "`detail'"
        local _mata_nocase "`nocase'"
        local _mata_nodots "`nodots'"
        local _mata_countmode "`countmode'"
        forvalues i = 1/`n_conditions' {
            local _mata_name_`i' "`def_name_`i''"
            local _mata_pat_`i' `"`def_pattern_`i''"'
            local _mata_excl_`i' `"`def_excl_`i''"'
        }

        * P1: Create matched_code before Mata call so Mata can populate it
        if "`matched_code'" != "" {
            if "`replace'" != "" capture drop `matched_code'
            gen str244 `matched_code' = ""
            local _mata_matched_code "`matched_code'"
        }

        * Call Mata scanner
        if "`detail'" != "" {
            local _mata_vcname "`varcounts'"
        }
        tempname _match_counts
        local _mata_mc_name "`_match_counts'"
        mata: _codescan_mata_scan()

        * Noisily display and zero-match warnings (from Mata-accumulated counts)
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            local _n_matched = el(`_match_counts', 1, `i')

            if "`noisily'" != "" {
                noisily display as text "  `name': " as result `_n_matched' ///
                    as text " matches across `nvars_scan' variables"
            }

            if `_n_matched' == 0 {
                noisily display as text "(note: condition `name' matched 0 observations)"
            }
        }

        * R1: Warn on overlapping conditions (single Mata pass via cross product)
        if "`cooccurrence'" == "" & `n_conditions' > 1 {
            tempname _overlap_cooc
            local _mata_cooc_matname "`_overlap_cooc'"
            local _mata_cooc_names "`all_names'"
            local _mata_cooc_touse "`touse'"
            local _mata_cooc_countmode "`countmode'"
            mata: _codescan_mata_cooccurrence()
            forvalues _oi = 1/`n_conditions' {
                forvalues _oj = `=`_oi'+1'/`n_conditions' {
                    local _on1 "`def_name_`_oi''"
                    local _on2 "`def_name_`_oj''"
                    local _overlap = el(`_overlap_cooc', `_oi', `_oj')
                    if `_overlap' > 0 {
                        local _cnt1 = el(`_overlap_cooc', `_oi', `_oi')
                        local _cnt2 = el(`_overlap_cooc', `_oj', `_oj')
                        local _smaller = min(`_cnt1', `_cnt2')
                        if `_smaller' > 0 & `_overlap' / `_smaller' > 0.5 {
                            local _opct = round(`_overlap' / `_smaller' * 100, 1)
                            noisily display as text ///
                                "(note: `_on1' and `_on2' overlap in " ///
                                as result `_overlap' as text " obs, " ///
                                as result "`_opct'" as text "% of smaller group)"
                        }
                    }
                }
            }
        }

        * C1: Unmatched code report — flag rows with no condition matches.
        * Strict 0/1 at row level: filtered rows (if/in, missing id for
        * collapse/merge) get 0, not missing, matching the sthlp contract.
        if "`unmatched'" != "" {
            if "`replace'" != "" capture drop `unmatched'
            gen byte `unmatched' = 0
            replace `unmatched' = 1 if `touse'
            forvalues i = 1/`n_conditions' {
                replace `unmatched' = 0 if `def_name_`i'' > 0 & `touse'
            }
            label variable `unmatched' "No condition matched"
        }

        * F6: matched_code — label (P1: capture moved to Mata scanner)
        if "`matched_code'" != "" {
            label variable `matched_code' "First matched code"
        }
    }

    * =========================================================================
    * MULTI-WINDOW SENSITIVITY ANALYSIS (W4, Mata-optimized)
    * =========================================================================
    * Scans secondary-window observations in ONE supplementary Mata pass
    * instead of N-1 save/scan/restore cycles. Per-window counts are
    * computed in Mata (patient-level for collapse/merge, row-level otherwise).
    if `n_lookback_windows' > 1 {
        tempname sensitivity
        matrix `sensitivity' = J(`n_conditions', `n_lookback_windows', .)
        * Column names are rebuilt during the display section below (using the
        * final window order); this initialization is intentionally provisional.
        local _sens_cnames ""

        * First window: use match counts already accumulated by primary scan
        forvalues i = 1/`n_conditions' {
            local _prim_n_`i' = el(`_match_counts', 1, `i')
        }

        * Pre-compute ALL secondary window touse masks
        quietly {
            forvalues _wi = 2/`n_lookback_windows' {
                local _lb_wi = `_lookback_`_wi''
                local _sens_cnames "`_sens_cnames' `_lb_wi'd"
                tempvar _stouse_`_wi'
                mark `_stouse_`_wi'' `if' `in'
                if "`id'" != "" replace `_stouse_`_wi'' = 0 if missing(`id')
                replace `_stouse_`_wi'' = 0 if missing(`date') | missing(`refdate')
                if `has_lookfwd' {
                    replace `_stouse_`_wi'' = 0 if `date' < `refdate' - `_lb_wi'
                    replace `_stouse_`_wi'' = 0 if `date' > `refdate' + `lookforward'
                }
                else {
                    replace `_stouse_`_wi'' = 0 if `date' < `refdate' - `_lb_wi'
                    if `include_ref' {
                        replace `_stouse_`_wi'' = 0 if `date' > `refdate'
                    }
                    else {
                        replace `_stouse_`_wi'' = 0 if `date' >= `refdate'
                    }
                }
            }

            * Union touse: observations in ANY secondary window but NOT primary
            tempvar _utouse
            gen byte `_utouse' = 0
            forvalues _wi = 2/`n_lookback_windows' {
                replace `_utouse' = 1 if `_stouse_`_wi'' & !`touse'
            }
            count if `_utouse'
            local _n_supp = r(N)
        }

        * Supplementary scan: match codes in secondary-only observations
        if `_n_supp' > 0 {
            quietly {
                forvalues i = 1/`n_conditions' {
                    tempvar _uind_`i'
                    gen byte `_uind_`i'' = 0
                }
            }
            local _mata_touse "`_utouse'"
            local _mata_mc_name ""
            forvalues i = 1/`n_conditions' {
                local _mata_name_`i' "`_uind_`i''"
            }
            local _mata_detail ""
            local _mata_countmode ""
            * matched_code is a primary-scan output; the supplementary scan
            * must not populate it for secondary-window-only rows (those lie
            * outside the primary analysis window).
            local _mata_matched_code ""
            quietly mata: _codescan_mata_scan()
        }

        * Count per-window matches via Mata
        local _sens_ind_names "`all_names'"
        local _sens_supp_names ""
        if `_n_supp' > 0 {
            forvalues i = 1/`n_conditions' {
                local _sens_supp_names "`_sens_supp_names' `_uind_`i''"
            }
            local _sens_supp_names = trim("`_sens_supp_names'")
        }
        local _sens_ncond "`n_conditions'"
        local _sens_nwindows "`n_lookback_windows'"
        local _sens_primary_touse "`touse'"
        forvalues _wi = 2/`n_lookback_windows' {
            local _sens_touse_`_wi' "`_stouse_`_wi''"
        }
        local _sens_do_collapse = ("`collapse'" != "" | "`merge'" != "")
        local _sens_id "`id'"
        tempname _sens_counts _sens_ns
        local _sens_counts_name "`_sens_counts'"
        local _sens_ns_name "`_sens_ns'"
        mata: _codescan_mata_sensitivity_count()

        * Extract per-window results from Mata
        forvalues _wi = 2/`n_lookback_windows' {
            local _sens_N_`_wi' = el(`_sens_ns', 1, `_wi')
            forvalues i = 1/`n_conditions' {
                local _sens_ct_`_wi'_`i' = el(`_sens_counts', `i', `_wi')
            }
        }

        * Clean up supplementary variables
        if `_n_supp' > 0 {
            forvalues i = 1/`n_conditions' {
                quietly drop `_uind_`i''
            }
        }
        quietly drop `_utouse'
        forvalues _wi = 2/`n_lookback_windows' {
            quietly drop `_stouse_`_wi''
        }

        * Restore Mata locals for potential later use
        local _mata_touse "`touse'"
        forvalues i = 1/`n_conditions' {
            local _mata_name_`i' "`def_name_`i''"
        }
        local _mata_detail "`detail'"
        local _mata_countmode "`countmode'"
        local _mata_matched_code "`matched_code'"

        local _has_sensitivity = 1
    }
    else {
        local _has_sensitivity = 0
    }

    * Preserve the caller's row ordering across merge's internal bysort/collapse.
    if "`merge'" != "" {
        tempvar _merge_input_order
        quietly gen long `_merge_input_order' = _n
    }

    * =========================================================================
    * PREPARE DATE VARIABLES (PRE-COLLAPSE/MERGE)
    * =========================================================================
    * Only collapse consumes these tempvars; the merge path builds its own
    * m*-prefixed date summaries below (collapse and merge are mutually
    * exclusive), so preparing them under merge is wasted work and an
    * unnecessary reorder of the data.
    if "`collapse'" != "" & "`date'" != "" {
        local datefmt : format `date'

        quietly {
            forvalues i = 1/`n_conditions' {
                local name "`def_name_`i''"

                if "`earliestdate'" != "" | "`latestdate'" != "" {
                    tempvar date_`i'
                    gen double `date_`i'' = `date' if `name' > 0 & `touse'
                }

                if "`countdate'" != "" {
                    tempvar hasmatch_`i' tag_`i'
                    bysort `id' `date': egen byte `hasmatch_`i'' = max((`name' > 0) * `touse')
                    by `id' `date': gen byte `tag_`i'' = `hasmatch_`i'' & `touse' & sum(`touse') == 1 & !missing(`date')
                }
            }
        }
    }

    * =========================================================================
    * PREPARE ROW-COUNT VARIABLES (PRE-COLLAPSE/MERGE)
    * =========================================================================
    if ("`collapse'" != "" | "`merge'" != "") & "`countrows'" != "" {
        quietly {
            forvalues i = 1/`n_conditions' {
                local name "`def_name_`i''"
                tempvar rowmatch_`i'
                if "`countmode'" != "" {
                    gen long `rowmatch_`i'' = `name' if `touse'
                }
                else {
                    gen byte `rowmatch_`i'' = (`name' > 0 & `touse')
                }
            }
        }
    }

    * =========================================================================
    * COLLAPSE
    * =========================================================================
    if "`collapse'" != "" {
        * Build collapse expression
        local collapse_expr ""
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            if "`countmode'" != "" {
                local collapse_expr "`collapse_expr' (sum) `name'"
            }
            else {
                local collapse_expr "`collapse_expr' (max) `name'"
            }

            if "`earliestdate'" != "" {
                local collapse_expr "`collapse_expr' (min) `name'_first=`date_`i''"
            }
            if "`latestdate'" != "" {
                local collapse_expr "`collapse_expr' (max) `name'_last=`date_`i''"
            }
            if "`countdate'" != "" {
                local collapse_expr "`collapse_expr' (sum) `name'_count=`tag_`i''"
            }
            if "`countrows'" != "" {
                local collapse_expr "`collapse_expr' (sum) `name'_nrows=`rowmatch_`i''"
            }
        }

        collapse `collapse_expr' if `touse', by(`id')

        * Post-collapse formatting
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            if "`countmode'" == "" {
                recast byte `name'
            }

            if "`earliestdate'" != "" {
                format `name'_first `datefmt'
            }
            if "`latestdate'" != "" {
                format `name'_last `datefmt'
            }
            if "`countdate'" != "" {
                recast long `name'_count
            }
            if "`countrows'" != "" {
                recast long `name'_nrows
            }
        }

        quietly count
        local N_collapsed = r(N)
    }

    * =========================================================================
    * MERGE — non-destructive patient-level indicators (U1)
    * =========================================================================
    if "`merge'" != "" {
        * Compute patient-level indicators via tempfile + merge back
        local merge_expr ""
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            if "`countmode'" != "" {
                local merge_expr "`merge_expr' (sum) `name'"
            }
            else {
                local merge_expr "`merge_expr' (max) `name'"
            }
        }

        * Also handle date summaries for merge
        if "`date'" != "" {
            local datefmt : format `date'
            forvalues i = 1/`n_conditions' {
                local name "`def_name_`i''"
                if "`earliestdate'" != "" {
                    tempvar mdate_`i'
                    quietly gen double `mdate_`i'' = `date' if `name' > 0 & `touse'
                    local merge_expr "`merge_expr' (min) `name'_first=`mdate_`i''"
                }
                if "`latestdate'" != "" {
                    if "`earliestdate'" == "" {
                        tempvar mdate_`i'
                        quietly gen double `mdate_`i'' = `date' if `name' > 0 & `touse'
                    }
                    local merge_expr "`merge_expr' (max) `name'_last=`mdate_`i''"
                }
                if "`countdate'" != "" {
                    tempvar mhasmatch_`i' mtag_`i'
                    quietly bysort `id' `date': egen byte `mhasmatch_`i'' = max((`name' > 0) * `touse')
                    quietly by `id' `date': gen byte `mtag_`i'' = `mhasmatch_`i'' & `touse' & sum(`touse') == 1 & !missing(`date')
                    local merge_expr "`merge_expr' (sum) `name'_count=`mtag_`i''"
                }
            }
        }

        * Row-count summaries for merge
        if "`countrows'" != "" {
            forvalues i = 1/`n_conditions' {
                local name "`def_name_`i''"
                local merge_expr "`merge_expr' (sum) `name'_nrows=`rowmatch_`i''"
            }
        }

        * Collapse to patient level via tempfile, then merge back
        tempfile _merge_save
        quietly save `_merge_save'
        quietly collapse `merge_expr' if `touse', by(`id')
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            if "`countmode'" == "" {
                recast byte `name'
            }
            if "`date'" != "" {
                if "`earliestdate'" != "" format `name'_first `datefmt'
                if "`latestdate'" != ""   format `name'_last `datefmt'
                if "`countdate'" != ""    recast long `name'_count
            }
            if "`countrows'" != "" recast long `name'_nrows
        }
        tempfile _merge_tf
        quietly save `_merge_tf'
        quietly use `_merge_save', clear

        * Drop the row-level indicators we created, merge patient-level ones
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            quietly drop `name'
            if "`replace'" != "" {
                if "`earliestdate'" != "" capture drop `name'_first
                if "`latestdate'" != ""   capture drop `name'_last
                if "`countdate'" != ""    capture drop `name'_count
                if "`countrows'" != ""   capture drop `name'_nrows
            }
        }
        quietly merge m:1 `id' using `_merge_tf', nogenerate keep(master match)

        quietly {
            tempvar _uniq_id
            bysort `id': gen byte `_uniq_id' = (`touse' & sum(`touse') == 1)
            count if `_uniq_id' == 1
        }
        local N_unique_ids = r(N)
    }

    * =========================================================================
    * CO-OCCURRENCE MATRIX (P1: Mata-accelerated)
    * =========================================================================
    if "`cooccurrence'" != "" {
        tempname cooc
        local _mata_cooc_matname "`cooc'"
        local _mata_cooc_names "`all_names'"
        local _mata_cooc_countmode "`countmode'"
        if "`collapse'" != "" {
            local _mata_cooc_touse ""
        }
        else if "`merge'" != "" {
            * Patient-level co-occurrence: restrict to one row per patient
            tempvar _cooc_tag
            quietly bysort `id': gen byte `_cooc_tag' = (`touse' & sum(`touse') == 1)
            local _mata_cooc_touse "`_cooc_tag'"
        }
        else {
            local _mata_cooc_touse "`touse'"
        }
        mata: _codescan_mata_cooccurrence()
        matrix rownames `cooc' = `all_names'
        matrix colnames `cooc' = `all_names'
    }

    * =========================================================================
    * APPLY LABELS
    * =========================================================================
    forvalues i = 1/`n_conditions' {
        local name "`def_name_`i''"
        local lbl ""

        forvalues j = 1/`n_labels' {
            if "`lab_name_`j''" == "`name'" {
                local lbl `"`lab_label_`j''"'
            }
        }

        if `"`lbl'"' != "" {
            label variable `name' `"`lbl'"'
            if "`earliestdate'" != "" {
                label variable `name'_first `"Earliest `lbl' Date"'
            }
            if "`latestdate'" != "" {
                label variable `name'_last `"Latest `lbl' Date"'
            }
            if "`countdate'" != "" {
                label variable `name'_count `"`lbl' Date Count"'
            }
            if "`countrows'" != "" {
                label variable `name'_nrows `"`lbl' Row Count"'
            }
        }
        else {
            label variable `name' `"`name'"'
            if "`earliestdate'" != "" {
                label variable `name'_first `"`name': earliest date"'
            }
            if "`latestdate'" != "" {
                label variable `name'_last `"`name': latest date"'
            }
            if "`countdate'" != "" {
                label variable `name'_count `"`name': unique dates"'
            }
            if "`countrows'" != "" {
                label variable `name'_nrows `"`name': row count"'
            }
        }
    }

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================
    local nvars : word count `varlist'
    if "`collapse'" != "" {
        local N_display = `N_collapsed'
    }
    else if "`merge'" != "" {
        local N_display = `N_unique_ids'
    }
    else {
        local N_display = `N'
    }

    * Name the analysis unit so "Prevalence" is never read as person-level in
    * row-level mode: row-level prevalence is the share of observations
    * (encounters) with a match, not the share of persons.
    if "`collapse'" != "" | "`merge'" != "" {
        local _unit_lbl "`id' values"
    }
    else {
        local _unit_lbl "observations"
    }

    display as text _n "codescan: `n_conditions' condition" ///
        cond(`n_conditions' > 1, "s", "") ", `nvars' variable" ///
        cond(`nvars' > 1, "s", "") ", N = " as result %10.0fc `N_display' ///
        as text " `_unit_lbl'"

    if `has_lookback' & `has_lookfwd' {
        display as text "Window: `_lookback_primary' days before to `lookforward' days after `refdate' (inclusive)"
    }
    else if `has_lookback' {
        local incl_txt = cond(`include_ref', " (inclusive)", "")
        display as text "Window: `_lookback_primary' days before `refdate'`incl_txt'"
    }
    else if `has_lookfwd' {
        local incl_txt = cond(`include_ref', " (inclusive)", "")
        display as text "Window: `lookforward' days after `refdate'`incl_txt'"
    }

    display as text ""
    if "`countmode'" != "" {
        display as text "  Condition" _col(24) %9s "Total" _col(36) %9s "Obs>0" ///
            _col(48) %10s "Prevalence" _col(62) %16s "[`=c(level)'% CI]"
        display as text "  {hline 76}"
    }
    else {
        display as text "  Condition" _col(24) %9s "Matches" ///
            _col(36) %10s "Prevalence" _col(50) %16s "[`=c(level)'% CI]"
        display as text "  {hline 64}"
    }

    tempname summary
    matrix `summary' = J(`n_conditions', 4, .)
    local rnames ""

    forvalues i = 1/`n_conditions' {
        local name "`def_name_`i''"
        if "`countmode'" != "" & "`merge'" != "" {
            * merge+countmode: compute from patient-level (one row per patient).
            * Patients with no in-window rows come back from the merge with a
            * MISSING count; missing > 0 is true in Stata, so screen it out or
            * they are counted as matches (inflating Obs>0 past 100%).
            quietly {
                tempvar _cmtag
                bysort `id': gen byte `_cmtag' = (_n == 1)
                count if `_cmtag' == 1 & `name' > 0 & !missing(`name')
                local n_match = r(N)
                summarize `name' if `_cmtag' == 1, meanonly
                local n_total_match = r(sum)
                drop `_cmtag'
            }
        }
        else if "`countmode'" != "" {
            quietly count if `name' > 0
            local n_match = r(N)
            quietly summarize `name', meanonly
            local n_total_match = r(sum)
        }
        else if "`merge'" != "" {
            * For merge: count unique IDs with condition = 1
            quietly {
                tempvar _cnt_tag
                bysort `id': gen byte `_cnt_tag' = (_n == 1) if `name' == 1
                count if `_cnt_tag' == 1
                local n_match = r(N)
                drop `_cnt_tag'
            }
        }
        else {
            quietly count if `name' == 1
            local n_match = r(N)
        }
        local pct = `n_match' / `N_display' * 100

        * O5: Wilson score confidence interval
        local _p_hat = `n_match' / `N_display'
        local _z = invnormal(1 - (1 - c(level)/100)/2)
        local _z2n = `_z'^2 / `N_display'
        local _denom = 1 + `_z2n'
        local _center = (`_p_hat' + `_z2n' / 2) / `_denom'
        local _margin = `_z' * sqrt((`_p_hat' * (1 - `_p_hat') + `_z2n' / 4) / `N_display') / `_denom'
        local ci_low = max(0, (`_center' - `_margin') * 100)
        local ci_high = min(100, (`_center' + `_margin') * 100)

        if "`countmode'" != "" {
            display as text "  `name'" _col(24) as result %9.0fc `n_total_match' ///
                _col(36) as result %9.0fc `n_match' ///
                _col(48) as result `_prev_fmt' `pct' as text "%" ///
                _col(62) as text "[" as result `_ci_fmt' `ci_low' ///
                as text ", " as result `_ci_fmt' `ci_high' as text "]"
        }
        else {
            display as text "  `name'" _col(24) as result %9.0fc `n_match' ///
                _col(36) as result `_prev_fmt' `pct' as text "%" ///
                _col(50) as text "[" as result `_ci_fmt' `ci_low' ///
                as text ", " as result `_ci_fmt' `ci_high' as text "]"
        }

        if "`countmode'" != "" {
            matrix `summary'[`i', 1] = `n_total_match'
        }
        else {
            matrix `summary'[`i', 1] = `n_match'
        }
        matrix `summary'[`i', 2] = `pct'
        matrix `summary'[`i', 3] = `ci_low'
        matrix `summary'[`i', 4] = `ci_high'
        local rnames "`rnames' `name'"
    }

    matrix colnames `summary' = count prevalence ci_low ci_high
    matrix rownames `summary' = `rnames'
    if "`merge'" != "" {
        quietly sort `_merge_input_order'
    }

    if "`collapse'" != "" {
        display as text _n "  Collapsed to " as result %10.0fc `N_collapsed' ///
            as text " unique `id' values"
    }
    if "`merge'" != "" {
        display as text _n "  Merged patient-level indicators for " ///
            as result %10.0fc `N_unique_ids' as text " unique `id' values"
    }

    * Multi-window sensitivity display (W4)
    if `_has_sensitivity' {
        * Now build the sensitivity matrix using N_display
        local _sens_cnames "`_lookback_1'd"
        forvalues i = 1/`n_conditions' {
            if "`collapse'" != "" | "`merge'" != "" {
                * For collapsed data: primary window count from summary
                matrix `sensitivity'[`i', 1] = `summary'[`i', 2]
            }
            else {
                * Unreachable in practice: multi-window lookback() requires
                * collapse or merge (validated above). Kept as a defensive
                * row-level fallback should that constraint ever be relaxed.
                matrix `sensitivity'[`i', 1] = `_prim_n_`i'' / `N_display' * 100
            }
        }
        forvalues _wi = 2/`n_lookback_windows' {
            local _lb_wi = `_lookback_`_wi''
            if `_wi' > 1 local _sens_cnames "`_sens_cnames' `_lb_wi'd"
            forvalues i = 1/`n_conditions' {
                if `_sens_N_`_wi'' > 0 {
                    matrix `sensitivity'[`i', `_wi'] = `_sens_ct_`_wi'_`i'' / `_sens_N_`_wi'' * 100
                }
                else {
                    matrix `sensitivity'[`i', `_wi'] = .
                }
            }
        }
        matrix rownames `sensitivity' = `all_names'
        matrix colnames `sensitivity' = `_sens_cnames'

        display as text _n "  Multi-window sensitivity (prevalence %):"
        display as text _col(20) _continue
        forvalues _wi = 1/`n_lookback_windows' {
            local _lb_wi = `_lookback_`_wi''
            display as text %9s "`_lb_wi'd" _continue
        }
        display ""
        forvalues i = 1/`n_conditions' {
            display as text "  `def_name_`i''" _col(20) _continue
            forvalues _wi = 1/`n_lookback_windows' {
                display as result %9.1f el(`sensitivity', `i', `_wi') _continue
            }
            display ""
        }
    }

    * Detail display: per-variable match contribution
    if "`detail'" != "" {
        display as text _n "  Per-variable match contribution:"
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            display as text "  `name': " _continue
            local first = 1
            local j = 0
            foreach var of local varlist {
                local ++j
                local vc = el(`varcounts', `i', `j')
                if `vc' > 0 {
                    if !`first' display as text ", " _continue
                    display as result `vc' as text " in `var'" _continue
                    local first = 0
                }
            }
            if `first' {
                display as text "no matches" _continue
            }
            display ""
        }

        matrix rownames `varcounts' = `all_names'
        local vnames ""
        foreach var of local varlist {
            local vnames "`vnames' `var'"
        }
        local vnames = trim("`vnames'")
        matrix colnames `varcounts' = `vnames'
    }

    * Co-occurrence display
    if "`cooccurrence'" != "" {
        display as text _n "  Co-occurrence:"
        display as text _col(24) _continue
        forvalues j = 1/`n_conditions' {
            display as text %9s "`def_name_`j''" _continue
        }
        display ""
        forvalues i = 1/`n_conditions' {
            display as text "  `def_name_`i''" _col(24) _continue
            forvalues j = 1/`n_conditions' {
                display as result %9.0fc el(`cooc', `i', `j') _continue
            }
            display ""
        }
    }

    * =========================================================================
    * RETURN RESULTS (posted before graph/export/saving so r() survives side-effect failures)
    * =========================================================================

    * Build list of created variables
    local newvars "`all_names'"
    if "`collapse'" != "" | "`merge'" != "" {
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            if "`earliestdate'" != "" local newvars "`newvars' `name'_first"
            if "`latestdate'" != ""   local newvars "`newvars' `name'_last"
            if "`countdate'" != ""    local newvars "`newvars' `name'_count"
            if "`countrows'" != ""   local newvars "`newvars' `name'_nrows"
        }
    }
    if "`unmatched'" != "" & "`collapse'" == "" {
        local newvars "`newvars' `unmatched'"
    }
    if "`matched_code'" != "" & "`collapse'" == "" {
        local newvars "`newvars' `matched_code'"
    }

    * I2: Build codelist matrix
    tempname codelist
    matrix `codelist' = J(`n_conditions', 2, .)
    local cl_rnames ""
    forvalues i = 1/`n_conditions' {
        matrix `codelist'[`i', 1] = `summary'[`i', 1]
        matrix `codelist'[`i', 2] = `summary'[`i', 2]
        local cl_rnames "`cl_rnames' `def_name_`i''"
    }
    matrix rownames `codelist' = `cl_rnames'
    matrix colnames `codelist' = count prevalence

    return scalar N = `N_display'
    return scalar n_conditions = `n_conditions'
    return scalar collapsed = ("`collapse'" != "")
    return scalar merged = ("`merge'" != "")
    return scalar mode_count = ("`countmode'" != "")
    return local conditions "`all_names'"
    return local newvars "`newvars'"
    return local varlist "`varlist'"
    return local mode "`mode'"
    if "`nocase'" != ""                return local nocase "nocase"
    if "`generate'" != ""              return local generate "`generate'"
    if `"`define'"' != ""              return local define `"`define'"'
    if "`_orig_codefile'" != ""         return local codefile "`_orig_codefile'"
    if "`id'" != ""                    return local id "`id'"
    if "`date'" != ""                  return local date "`date'"
    if `has_lookback' & `n_lookback_windows' == 1 {
        return scalar lookback = `_lookback_primary'
    }
    else if `has_lookback' {
        return local lookback "`lookback'"
    }
    if `has_lookfwd'                   return scalar lookforward = `lookforward'
    if `has_lookback' | `has_lookfwd'  return local refdate "`refdate'"
    if `has_lookback' | `has_lookfwd'  return scalar n_excluded_missingdate = `_n_excl_missdate'
    if "`frame'" != ""                 return local frame "`frame'"
    return scalar ci_level = c(level)
    * , copy — keep local tempname matrices alive for the export block below.
    return matrix summary = `summary', copy
    return matrix codelist = `codelist', copy
    if "`detail'" != ""                return matrix varcounts = `varcounts', copy
    if "`cooccurrence'" != ""          return matrix cooccurrence = `cooc', copy
    if `_has_sensitivity'              return matrix sensitivity = `sensitivity', copy

    * =========================================================================
    * GRAPH — prevalence bar chart (O1)
    * =========================================================================
    if "`graph'" != "" {
        tempfile _graph_save
        quietly save `_graph_save'
        capture noisily {
            quietly {
                clear
                set obs `n_conditions'
                gen str32 condition = ""
                gen double prevalence = .
                forvalues i = 1/`n_conditions' {
                    replace condition = "`def_name_`i''" in `i'
                    replace prevalence = `summary'[`i', 2] in `i'
                }
                gsort -prevalence
                gen int order = _n
                tempname _glab
                forvalues _gi = 1/`=_N' {
                    local _gcond = condition[`_gi']
                    label define `_glab' `_gi' "`_gcond'", add
                }
                label values order `_glab'
            }
            graph hbar prevalence, over(order) ///
                ytitle("Prevalence (%)") ///
                title("Condition Prevalence") ///
                blabel(bar, format(%4.1f))
        }
        local _graph_rc = _rc
        capture quietly use `_graph_save', clear
        local _graph_restore_rc = _rc
        if `_graph_restore_rc' & `_graph_rc' == 0 exit `_graph_restore_rc'
        if `_graph_rc' exit `_graph_rc'
    }

    * =========================================================================
    * EXPORT — save results to file (O2)
    * =========================================================================
    if `"`export'"' != "" {
        local _exp_ext = lower(substr(`"`export'"', -4, .))
        tempfile _export_save
        quietly save `_export_save'
        capture noisily {
            quietly {
            clear
            set obs `n_conditions'
            gen str32 condition = ""
            gen long matches = .
            gen double prevalence = .
            gen double ci_low = .
            gen double ci_high = .
            gen str80 pattern = ""
            gen str80 exclusion = ""
            forvalues i = 1/`n_conditions' {
                replace condition = "`def_name_`i''" in `i'
                replace matches = `summary'[`i', 1] in `i'
                replace prevalence = `summary'[`i', 2] in `i'
                replace ci_low  = `summary'[`i', 3] in `i'
                replace ci_high = `summary'[`i', 4] in `i'
                replace pattern = `"`def_pattern_`i''"' in `i'
                replace exclusion = `"`def_excl_`i''"' in `i'
            }
            format prevalence ci_low ci_high `_prev_fmt'
            }
            if "`_exp_ext'" == ".csv" {
                quietly export delimited using `"`export'"', replace
            }
            else {
                quietly export excel using `"`export'"', firstrow(variables) replace
                * Add co-occurrence as second sheet if available
                if "`cooccurrence'" != "" {
                    quietly {
                        clear
                        local _ncond = `n_conditions'
                        set obs `_ncond'
                        gen str32 condition = ""
                        forvalues i = 1/`_ncond' {
                            replace condition = "`def_name_`i''" in `i'
                        }
                        forvalues j = 1/`_ncond' {
                            gen double `def_name_`j'' = .
                            forvalues i = 1/`_ncond' {
                                replace `def_name_`j'' = el(`cooc', `i', `j') in `i'
                            }
                        }
                    }
                    quietly export excel using `"`export'"', firstrow(variables) ///
                        sheet("cooccurrence") sheetmodify
                }
            }
        }
        local _export_rc = _rc
        capture quietly use `_export_save', clear
        local _export_restore_rc = _rc
        if `_export_restore_rc' & `_export_rc' == 0 exit `_export_restore_rc'
        if `_export_rc' exit `_export_rc'
        display as text _n `"  Results exported to `export'"'
    }

    * =========================================================================
    * SAVING() — save result dataset to file (before restore)
    * =========================================================================
    if `"`saving'"' != "" {
        if `_saving_replace' {
            quietly save `"`_saving_fn'"', replace
        }
        else {
            quietly save `"`_saving_fn'"'
        }
        display as text `"  (dataset saved to `_saving_fn')"'
    }

    * =========================================================================
    * FRAME OUTPUT + RESTORE
    * =========================================================================
    if "`preserve'" != "" {
        if "`frame'" != "" {
            if "`replace'" != "" {
                capture confirm frame `frame'
                if !_rc frame drop `frame'
            }
            frame put *, into(`frame')
        }
        restore
        * After restore, indicators no longer exist in memory
        return local newvars ""
    }

    } // end capture noisily
    local rc = _rc
    if `rc' {
        * Clean up: restore any active user preserve, drop only variables this run started creating.
        capture restore
        if "`_outputs'" != "" & "`_outputs_created'" == "1" {
            capture noisily _codescan_cleanup_outputs, outputs("`_outputs'") ///
                scanvars("`varlist'") protected("`id' `date' `refdate'")
        }
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* =============================================================================
* SUBROUTINE: Prefix scanning with | splitting
* =============================================================================
* MATA: Row-loop scanning engine with st_sview() + st_view()
* =============================================================================
* Iterates over observations once per scan variable, testing all conditions
* per observation.  Uses st_sview() for zero-copy string reads and st_view()
* for direct indicator write-back.  The row-loop avoids intermediate vector
* allocations from colon operators and benefits from early-exit short-circuits
* (skip empty strings, skip already-matched conditions).  Detail tracking
* (per-variable match counts) is accumulated in the same pass at zero cost.
* =============================================================================

mata:
void _codescan_mata_scan()
{
    real scalar      ncond, nvars, N, i, j, k, len, npfx, enpfx
    real scalar      is_prefix, has_detail, has_excl, use_nocase, is_count, has_mcode
    real scalar      matched, excluded, strip_dots
    string scalar    mode, touse_name, vcname, val, mcname, mc_name
    string rowvector scanvars, cond_names
    string colvector patterns, excl_patterns, anchored_pats, anchored_excl
    string colvector col
    string colvector mcode
    real matrix      indicators, varcounts
    real colvector   touse
    real rowvector   match_counts
    string rowvector pk, epk
    real rowvector   lk, elk
    transmorphic     A
    string colvector keys
    string scalar    dval
    real matrix      D
    real colvector   anymatch
    real scalar      didx, ndistinct, di

    // Read parameters from Stata locals
    ncond      = strtoreal(st_local("_mata_ncond"))
    mode       = st_local("_mata_mode")
    touse_name = st_local("_mata_touse")
    scanvars   = tokens(st_local("_mata_scanvars"))
    nvars      = cols(scanvars)
    N          = st_nobs()
    is_prefix  = (mode == "prefix")
    has_detail = (st_local("_mata_detail") != "")
    vcname     = st_local("_mata_vcname")
    use_nocase = (st_local("_mata_nocase") != "")
    strip_dots = (st_local("_mata_nodots") != "")
    is_count   = (st_local("_mata_countmode") != "")
    mcname     = st_local("_mata_matched_code")
    has_mcode  = (mcname != "")

    // Load condition definitions
    cond_names    = J(1, ncond, "")
    patterns      = J(ncond, 1, "")
    excl_patterns = J(ncond, 1, "")
    for (i = 1; i <= ncond; i++) {
        cond_names[i]    = st_local("_mata_name_" + strofreal(i))
        patterns[i]      = st_local("_mata_pat_" + strofreal(i))
        excl_patterns[i] = st_local("_mata_excl_" + strofreal(i))
    }

    // F1: prefix nocase uses unicode-aware case folding. Regex nocase is
    // implemented with ICU's inline (?i) flag below so escapes such as \d are
    // never corrupted by uppercasing the pattern to \D.
    if (use_nocase & is_prefix) {
        for (i = 1; i <= ncond; i++) {
            patterns[i] = ustrupper(patterns[i])
            if (excl_patterns[i] != "") {
                excl_patterns[i] = ustrupper(excl_patterns[i])
            }
        }
    }

    // Pre-build anchored regex patterns (avoid repeated string concat)
    if (!is_prefix) {
        anchored_pats = J(ncond, 1, "")
        anchored_excl = J(ncond, 1, "")
        for (i = 1; i <= ncond; i++) {
            anchored_pats[i] = (use_nocase ? "(?i)^(" : "^(") + patterns[i] + ")"
            if (excl_patterns[i] != "") {
                anchored_excl[i] = (use_nocase ? "(?i)^(" : "^(") + excl_patterns[i] + ")"
            }
        }
    }

    // Set up views: touse (read), indicators (read/write)
    touse = st_data(., touse_name)
    st_view(indicators, ., cond_names)

    // P1: Set up matched_code view for Mata-accelerated capture
    if (has_mcode) {
        st_sview(mcode, ., mcname)
    }

    // Check if any condition has exclusion patterns
    has_excl = 0
    for (i = 1; i <= ncond; i++) {
        if (excl_patterns[i] != "") {
            has_excl = 1
            break
        }
    }

    // Pre-parse prefix patterns (pipe-separated) into pointer arrays
    pointer(string rowvector) rowvector pfx_list, excl_pfx_list
    pointer(real rowvector) rowvector pfx_lens, excl_pfx_lens

    if (is_prefix) {
        pfx_list = J(1, ncond, NULL)
        pfx_lens = J(1, ncond, NULL)
        excl_pfx_list = J(1, ncond, NULL)
        excl_pfx_lens = J(1, ncond, NULL)
        for (i = 1; i <= ncond; i++) {
            pfx_list[i] = &_codescan_split_prefixes(patterns[i])
            pfx_lens[i] = &strlen(*pfx_list[i])
            if (excl_patterns[i] != "") {
                excl_pfx_list[i] = &_codescan_split_prefixes(excl_patterns[i])
                excl_pfx_lens[i] = &strlen(*excl_pfx_list[i])
            }
        }
    }

    // Initialize detail tracking
    if (has_detail) {
        varcounts = J(ncond, nvars, 0)
    }

    match_counts = J(1, ncond, 0)
    mc_name = st_local("_mata_mc_name")

    // ── DISTINCT-VALUE MEMOIZATION ──
    // A code's classification (matched AND NOT excluded, per condition) depends
    // ONLY on the string value, never on the row.  Registry data has millions of
    // cells but only a few thousand distinct codes, so we classify each distinct
    // (transformed) value once and reuse the result, turning the hot loop into a
    // hash lookup.  Results are byte-identical to a per-cell scan; only the cost
    // changes (O(distinct x ncond) pattern tests instead of O(N x nvars x ncond)).

    // Pass 1 — collect the distinct transformed values that will be scanned.
    A = asarray_create("string", 1)
    asarray_notfound(A, 0)
    for (j = 1; j <= nvars; j++) {
        st_sview(col, ., scanvars[j])
        for (i = 1; i <= N; i++) {
            if (!touse[i]) continue
            // Skip empty cells and bare "." placeholders (missing-value
            // convention in registry data).  This mirrors codescan_describe
            // so the exploration and scan tools agree on what is scannable.
            if (col[i] == "" | col[i] == ".") continue
            val = col[i]
            if (strip_dots) val = subinstr(val, ".", "", .)
            if (val == "") continue
            if (use_nocase & is_prefix) val = ustrupper(val)
            if (asarray(A, val) == 0) asarray(A, val, 1)
        }
    }

    // Pass 2 — classify each distinct value once into D[didx, k]; assign each
    // key its final index didx (1..ndistinct) in the asarray for O(1) lookup.
    keys      = asarray_keys(A)
    ndistinct = rows(keys)
    D         = J(ndistinct, ncond, 0)
    anymatch  = J(ndistinct, 1, 0)
    for (di = 1; di <= ndistinct; di++) {
        dval = keys[di]
        asarray(A, dval, di)
        for (k = 1; k <= ncond; k++) {
            // ── Inclusion check ──
            matched = 0
            if (is_prefix) {
                pk = *pfx_list[k]
                lk = *pfx_lens[k]
                npfx = cols(pk)
                for (len = 1; len <= npfx; len++) {
                    if (substr(dval, 1, lk[len]) == pk[len]) {
                        matched = 1
                        break
                    }
                }
            }
            else {
                // ustrregexm(): unicode-aware ICU engine. Returns 1/0 for valid
                // patterns (-1 only on an invalid pattern, which the validator
                // rejects up front); compare ==1 so any stray -1 is a non-match.
                if (ustrregexm(dval, anchored_pats[k]) == 1) matched = 1
            }
            if (!matched) continue

            // ── Exclusion check ──
            if (has_excl & excl_patterns[k] != "") {
                excluded = 0
                if (is_prefix) {
                    epk = *excl_pfx_list[k]
                    elk = *excl_pfx_lens[k]
                    enpfx = cols(epk)
                    for (len = 1; len <= enpfx; len++) {
                        if (substr(dval, 1, elk[len]) == epk[len]) {
                            excluded = 1
                            break
                        }
                    }
                }
                else {
                    // ==1 guard: a stray -1 must not exclude every value.
                    if (ustrregexm(dval, anchored_excl[k]) == 1) excluded = 1
                }
                if (excluded) continue
            }

            D[di, k] = 1
            anymatch[di] = 1
        }
    }

    // Pass 3 — apply.  Same j (variable) / i (row) / k (condition) nesting and
    // early-out as the original per-cell scan, so all ordering-dependent outputs
    // (matched_code first-hit, match_counts, varcounts) are preserved exactly.
    // The only change: the inline pattern test is now a D[didx, k] lookup.
    for (j = 1; j <= nvars; j++) {
        st_sview(col, ., scanvars[j])

        for (i = 1; i <= N; i++) {
            if (!touse[i]) continue
            // Guard MUST match Pass 1 exactly (same skip set), or a value
            // scanned here but absent from asarray A would return didx==0.
            if (col[i] == "" | col[i] == ".") continue

            val = col[i]
            if (strip_dots) val = subinstr(val, ".", "", .)
            if (val == "") continue
            if (use_nocase & is_prefix) val = ustrupper(val)
            didx = asarray(A, val)
            // Values that match no condition (common: codes in untargeted
            // chapters) skip the condition loop entirely.
            if (anymatch[didx] == 0) continue

            for (k = 1; k <= ncond; k++) {
                if (!is_count && indicators[i, k]) continue
                if (!D[didx, k]) continue

                // ── Code passed inclusion and exclusion — record match ──
                if (is_count) {
                    if (indicators[i, k] == 0) match_counts[k] = match_counts[k] + 1
                    indicators[i, k] = indicators[i, k] + 1
                }
                else {
                    match_counts[k] = match_counts[k] + 1
                    indicators[i, k] = 1
                }
                if (has_mcode) {
                    if (mcode[i] == "") mcode[i] = col[i]
                }
                if (has_detail) varcounts[k, j] = varcounts[k, j] + 1
            }
        }
    }

    // Write detail matrix back to Stata
    if (has_detail) {
        st_matrix(vcname, varcounts)
    }
    if (mc_name != "") {
        st_matrix(mc_name, match_counts)
    }
}

// Helper: split pipe-separated prefix string into row vector of trimmed tokens
string rowvector _codescan_split_prefixes(string scalar s)
{
    string rowvector result
    string scalar    remaining, token
    real scalar      pos

    result = J(1, 0, "")
    remaining = s
    while (remaining != "") {
        pos = strpos(remaining, "|")
        if (pos > 0) {
            token = strtrim(substr(remaining, 1, pos - 1))
            remaining = substr(remaining, pos + 1, .)
        }
        else {
            token = strtrim(remaining)
            remaining = ""
        }
        if (token != "") {
            result = result, token
        }
    }
    return(result)
}

// P1: Compute co-occurrence matrix in a single Mata pass
void _codescan_mata_cooccurrence()
{
    string rowvector names
    string scalar    touse_name, coocname
    real scalar      ncond, N, i, j, is_count
    real matrix      ind, cooc, mask
    real colvector   touse

    names      = tokens(st_local("_mata_cooc_names"))
    ncond      = cols(names)
    touse_name = st_local("_mata_cooc_touse")
    coocname   = st_local("_mata_cooc_matname")
    is_count   = (st_local("_mata_cooc_countmode") != "")

    st_view(ind, ., names)
    N = rows(ind)

    // Binarize counts for co-occurrence (countmode stores counts, not 0/1)
    if (is_count) {
        mask = (ind :> 0)
    }
    else {
        mask = ind
    }

    if (touse_name != "") {
        touse = st_data(., touse_name)
        mask = mask :* touse
    }

    // cross(mask, mask) gives ncond × ncond co-occurrence counts
    cooc = cross(mask, mask)
    st_matrix(coocname, cooc)
}

// Multi-window sensitivity: count per-window matches in a single pass.
// For collapse/merge, counts at patient level (unique IDs per window).
// For row-level, counts observations per window.
// Reads primary indicators + supplementary indicators (from union scan).
void _codescan_mata_sensitivity_count()
{
    real scalar ncond, nwindows, N, i, j, k, w
    real scalar do_collapse, has_supp, id_is_str, new_patient
    string rowvector ind_names, supp_names
    string scalar id_name, counts_name, ns_name, primary_touse_name
    real matrix indicators, supp_ind, touse_w, counts
    real colvector primary_touse, sort_idx, num_ids
    real rowvector N_per_window, in_window
    real matrix matched
    string colvector str_ids

    ncond = strtoreal(st_local("_sens_ncond"))
    nwindows = strtoreal(st_local("_sens_nwindows"))
    N = st_nobs()
    do_collapse = strtoreal(st_local("_sens_do_collapse"))
    id_name = st_local("_sens_id")
    counts_name = st_local("_sens_counts_name")
    ns_name = st_local("_sens_ns_name")
    primary_touse_name = st_local("_sens_primary_touse")

    ind_names = tokens(st_local("_sens_ind_names"))
    st_view(indicators, ., ind_names)

    supp_names = tokens(st_local("_sens_supp_names"))
    has_supp = (cols(supp_names) > 0)
    if (has_supp) {
        if (supp_names[1] == "") has_supp = 0
    }
    if (has_supp) {
        st_view(supp_ind, ., supp_names)
    }

    primary_touse = st_data(., primary_touse_name)

    // Build touse matrix: column 1 = primary, columns 2..nwindows = secondary
    touse_w = J(N, nwindows, 0)
    touse_w[., 1] = primary_touse
    for (w = 2; w <= nwindows; w++) {
        touse_w[., w] = st_data(., st_local("_sens_touse_" + strofreal(w)))
    }

    counts = J(ncond, nwindows, 0)
    N_per_window = J(1, nwindows, 0)

    if (do_collapse && id_name != "") {
        // Patient-level counting: sort by ID, scan for unique patients
        id_is_str = st_isstrvar(id_name)

        if (id_is_str) {
            str_ids = st_sdata(., id_name)
            sort_idx = order(str_ids, 1)
        }
        else {
            num_ids = st_data(., id_name)
            sort_idx = order(num_ids, 1)
        }
        in_window = J(1, nwindows, 0)
        matched = J(nwindows, ncond, 0)

        for (j = 1; j <= N; j++) {
            i = sort_idx[j]

            // Detect new patient
            if (j == 1) {
                new_patient = 1
            }
            else if (id_is_str) {
                new_patient = (str_ids[i] != str_ids[sort_idx[j - 1]])
            }
            else {
                new_patient = (num_ids[i] != num_ids[sort_idx[j - 1]])
            }

            if (new_patient && j > 1) {
                for (w = 1; w <= nwindows; w++) {
                    if (in_window[w]) {
                        N_per_window[w] = N_per_window[w] + 1
                        for (k = 1; k <= ncond; k++) {
                            if (matched[w, k]) counts[k, w] = counts[k, w] + 1
                        }
                    }
                }
                in_window = J(1, nwindows, 0)
                matched = J(nwindows, ncond, 0)
            }

            for (w = 1; w <= nwindows; w++) {
                if (touse_w[i, w]) {
                    in_window[w] = 1
                    for (k = 1; k <= ncond; k++) {
                        if (!matched[w, k]) {
                            if (indicators[i, k] > 0) {
                                matched[w, k] = 1
                            }
                            else if (has_supp) {
                                if (supp_ind[i, k] > 0) matched[w, k] = 1
                            }
                        }
                    }
                }
            }
        }
        // Commit last patient
        if (N > 0) {
            for (w = 1; w <= nwindows; w++) {
                if (in_window[w]) {
                    N_per_window[w] = N_per_window[w] + 1
                    for (k = 1; k <= ncond; k++) {
                        if (matched[w, k]) counts[k, w] = counts[k, w] + 1
                    }
                }
            }
        }
    }
    else {
        // Row-level counting
        for (i = 1; i <= N; i++) {
            for (w = 1; w <= nwindows; w++) {
                if (touse_w[i, w]) {
                    N_per_window[w] = N_per_window[w] + 1
                    for (k = 1; k <= ncond; k++) {
                        if (indicators[i, k] > 0) {
                            counts[k, w] = counts[k, w] + 1
                        }
                        else if (has_supp) {
                            if (supp_ind[i, k] > 0) counts[k, w] = counts[k, w] + 1
                        }
                    }
                }
            }
        }
    }

    st_matrix(counts_name, counts)
    st_matrix(ns_name, N_per_window)
}
end
