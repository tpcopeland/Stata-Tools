*! codescan Version 1.0.2  2026/04/17
*! Scan wide-format code variables for pattern matches and collapse to patient-level
*! Author: Timothy P Copeland
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
         NOCase GENerate(string) SCORE(string) HIERarchy(string)
         UNMatched(name) MATCHed_code(name) LEVel(integer) GRaph EXPort(string)
         SAVE(string) SAVing(string asis) FORmat(string) COUNTMode]

EXAMPLES:
    * Row-level indicators
    codescan dx1-dx30, define(dm2 "E11" | obesity "E66")

    * Exclusion patterns
    codescan dx1-dx30, define(dm2 "E11" ~ "E116" | htn "I1[0-35]")

    * Load definitions from file
    codescan dx1-dx30, codefile(charlson_codes.csv) id(pid) collapse

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
    r(lookback)       - Lookback days (if specified; space-separated if multi-window)
    r(lookforward)    - Lookforward days (if specified)
    r(refdate)        - Reference date variable (if specified)
    r(frame)          - Frame name (if frame() specified)
    r(score)          - Score type (if score() specified)
    r(mode_count)     - 1 if countmode specified, 0 otherwise
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
        NOCase GENerate(string) SCORE(string) HIERarchy(string) ///
        UNMatched(name) MATCHed_code(name) LEVel(integer 0) ///
        GRaph EXPort(string) SAVE(string) SAVing(string asis) ///
        FORmat(string) COUNTMode]

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

    * All varlist variables must be string (skip if tostring will handle them)
    if "`tostring'" == "" {
        foreach var of local varlist {
            capture confirm string variable `var'
            if _rc {
                display as error "`var' is not a string variable"
                display as error "codescan requires string variables; use tostring or the tostring option"
                exit 109
            }
        }
    }

    * Mode validation
    if "`mode'" == "" local mode "regex"
    if "`mode'" != "regex" & "`mode'" != "prefix" {
        display as error "mode() must be {bf:regex} or {bf:prefix}"
        exit 198
    }

    * Parse lookback — accepts integers or standard numlists (e.g. 30(30)90)
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

    * Score validation
    if "`score'" != "" {
        local _score_type = lower("`score'")
        if !inlist("`_score_type'", "charlson", "elixhauser", "custom") {
            display as error "score() must be {bf:charlson}, {bf:elixhauser}, or {bf:custom}"
            exit 198
        }
        if "`_score_type'" == "custom" & "`codefile'" == "" {
            display as error "score(custom) requires codefile() with a weight column"
            exit 198
        }
    }

    * Level validation
    if `level' != 0 {
        if `level' < 1 | `level' > 10 {
            display as error "level() must be between 1 and 10"
            exit 198
        }
    }

    * Export validation
    if `"`export'"' != "" {
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
        * Split filename from suboptions at first comma
        local _comma_pos = strpos(`"`saving'"', ",")
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

    * hierarchy() validation — lightweight syntax check (name validation deferred until conditions parsed)
    if `"`hierarchy'"' != "" {
        if "`collapse'" == "" & "`merge'" == "" {
            display as error "hierarchy() requires collapse or merge"
            exit 198
        }
        * Check each pair has a > separator
        local _hcheck_str `"`hierarchy'"'
        while `"`_hcheck_str'"' != "" {
            gettoken _hchk_pair _hcheck_str : _hcheck_str, parse("\")
            local _hchk_pair = strtrim(`"`_hchk_pair'"')
            if `"`_hchk_pair'"' == "\" | `"`_hchk_pair'"' == "" continue
            if !strpos(`"`_hchk_pair'"', ">") {
                display as error "hierarchy(): each pair must use {bf:>} syntax: superior_name {bf:>} inferior_name"
                exit 198
            }
        }
    }
    local _n_hier_pairs = 0

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

    if "`codefile'" != "" {
        local ext = lower(substr("`codefile'", -4, .))
        if "`ext'" != ".csv" & "`ext'" != ".dta" {
            display as error "codefile() must be a .csv or .dta file"
            exit 198
        }
        capture confirm file `"`codefile'"'
        if _rc {
            local _cf_base = lower(regexr(`"`codefile'"', ".*[\\/]", ""))
            if inlist("`_cf_base'", "charlson_icd10_example.csv", "elixhauser_icd10_example.csv") {
                tempfile _builtin_codefile
                _codescan_write_builtin_codefile, name("`_cf_base'") target("`_builtin_codefile'")
                local codefile "`_builtin_codefile'"
                local ext ".dta"
            }
            else {
                display as error `"codefile(): file not found: `codefile'"'
                exit 601
            }
        }

        preserve
        quietly {
            if "`ext'" == ".csv" {
                import delimited `"`codefile'"', clear stringcols(_all) varnames(1)
            }
            else {
                use `"`codefile'"', clear
            }
        }

        * R2: Case-tolerant column name matching
        foreach _cfcol in name pattern label exclusion weight {
            capture confirm variable `_cfcol'
            if _rc {
                * Try case-insensitive match
                foreach _v of varlist * {
                    if lower("`_v'") == "`_cfcol'" & "`_v'" != "`_cfcol'" {
                        rename `_v' `_cfcol'
                        continue, break
                    }
                }
            }
        }

        * Validate required columns
        capture confirm string variable name
        if _rc {
            restore
            display as error "codefile(): file must contain a string variable {bf:name}"
            exit 198
        }
        capture confirm string variable pattern
        if _rc {
            restore
            display as error "codefile(): file must contain a string variable {bf:pattern}"
            exit 198
        }

        * Optional columns
        capture confirm string variable label
        local _cf_has_label = (_rc == 0)
        capture confirm string variable exclusion
        local _cf_has_excl = (_rc == 0)
        capture confirm variable weight
        local _cf_has_weight = (_rc == 0)

        quietly count
        local n_conditions = r(N)
        if `n_conditions' == 0 {
            restore
            display as error "codefile(): file is empty"
            exit 198
        }

        forvalues i = 1/`n_conditions' {
            local def_name_`i' = name[`i']
            local def_pattern_`i' = pattern[`i']
            local def_excl_`i' ""
            local all_names "`all_names' `def_name_`i''"

            if `_cf_has_label' {
                local _lbl = label[`i']
                if `"`_lbl'"' != "" {
                    local ++n_labels
                    local lab_name_`n_labels' "`def_name_`i''"
                    local lab_label_`n_labels' `"`_lbl'"'
                }
            }
            if `_cf_has_excl' {
                local _excl = exclusion[`i']
                if `"`_excl'"' != "" {
                    local def_excl_`i' `"`_excl'"'
                }
            }
            if `_cf_has_weight' {
                local def_weight_`i' = weight[`i']
            }
            else {
                local def_weight_`i' = 0
            }
        }
        local all_names = trim("`all_names'")

        * R3: Codefile schema validation — batch all errors
        local _cf_errors ""
        local _cf_nerr = 0
        if "`_score_type'" == "custom" & !`_cf_has_weight' {
            local ++_cf_nerr
            local _cf_errors `"`_cf_errors'"score(custom) requires a weight column in codefile()" "'
        }
        forvalues i = 1/`n_conditions' {
            if "`def_name_`i''" == "" {
                local ++_cf_nerr
                local _cf_errors `"`_cf_errors'"row `i': empty name" "'
            }
            if `"`def_pattern_`i''"' == "" {
                local ++_cf_nerr
                local _cf_errors `"`_cf_errors'"row `i': empty pattern" "'
            }
            if "`def_name_`i''" != "" {
                capture confirm name `def_name_`i''
                if _rc {
                    local ++_cf_nerr
                    local _cf_errors `"`_cf_errors'"row `i': '`def_name_`i''' is not a valid Stata name" "'
                }
            }
            if "`_score_type'" == "custom" & `_cf_has_weight' {
                local _wval = weight[`i']
                local _wnum = real("`_wval'")
                if "`_wval'" == "" | "`_wnum'" == "." {
                    local ++_cf_nerr
                    local _cf_errors `"`_cf_errors'"row `i': weight is missing or non-numeric ('`_wval'')" "'
                }
            }
            forvalues j = 1/`=`i'-1' {
                if "`def_name_`i''" == "`def_name_`j''" & "`def_name_`i''" != "" {
                    local ++_cf_nerr
                    local _cf_errors `"`_cf_errors'"row `i': duplicate name '`def_name_`i''' (same as row `j')" "'
                    continue, break
                }
            }
        }
        if `_cf_nerr' > 0 {
            restore
            display as error "codefile(): `_cf_nerr' validation error(s):"
            local _cf_remain `"`_cf_errors'"'
            forvalues _ei = 1/`_cf_nerr' {
                gettoken _emsg _cf_remain : _cf_remain
                display as error "  `_emsg'"
            }
            exit 198
        }

        restore
    }

    * =========================================================================
    * PARSE DEFINE()
    * =========================================================================
    else {
        * tokenize respects quotes: "I2[0-5]|I6[0-9]" stays as one token
        * Unquoted | becomes a separate token (space-separated)
        * Format: name "pattern" [~ "excl" ...] | name "pattern" | ...
        tokenize `"`define'"'

        local i = 1
        while `"``i''"' != "" {
            * Skip | delimiter tokens
            if `"``i''"' == "|" {
                local ++i
                continue
            }

            * Expect: name pattern [~ excl ...]
            local ++n_conditions
            local def_name_`n_conditions' `"``i''"'
            local ++i
            if `"``i''"' == "" | `"``i''"' == "|" {
                display as error "define(): condition `def_name_`n_conditions'' has no pattern"
                display as error "  Expected format: define(name {c 34}pattern{c 34} | name2 {c 34}pattern2{c 34})"
                exit 198
            }
            local def_pattern_`n_conditions' `"``i''"'
            local ++i

            * Parse optional exclusion patterns (~ "pattern" ~ "pattern" ...)
            local def_excl_`n_conditions' ""
            while `"``i''"' == "~" {
                local ++i
                if `"``i''"' == "" | `"``i''"' == "|" | `"``i''"' == "~" {
                    display as error "define(): ~ must be followed by an exclusion pattern"
                    exit 198
                }
                if `"`def_excl_`n_conditions''"' == "" {
                    local def_excl_`n_conditions' `"``i''"'
                }
                else {
                    local def_excl_`n_conditions' `"`def_excl_`n_conditions''|``i''"'
                }
                local ++i
            }

            local def_weight_`n_conditions' = 0
            local all_names "`all_names' `def_name_`n_conditions''"
        }
        local all_names = trim("`all_names'")

        if `n_conditions' == 0 {
            display as error "define() is empty"
            exit 198
        }
    }

    * =========================================================================
    * APPLY GENERATE PREFIX (F3)
    * =========================================================================
    if "`generate'" != "" {
        * Validate prefix + longest name + _count suffix <= 32
        local _max_nm_len = 0
        forvalues _gi = 1/`n_conditions' {
            if strlen("`def_name_`_gi''") > `_max_nm_len' {
                local _max_nm_len = strlen("`def_name_`_gi''")
            }
        }
        if strlen("`generate'") + `_max_nm_len' + 6 > 32 {
            display as error "generate(): prefix + longest condition name + suffix exceeds 32 characters"
            exit 198
        }
        * Apply prefix to all condition names
        local all_names ""
        forvalues i = 1/`n_conditions' {
            local def_name_`i' "`generate'`def_name_`i''"
            local all_names "`all_names' `def_name_`i''"
        }
        local all_names = trim("`all_names'")
        * Also update label names
        forvalues j = 1/`n_labels' {
            local lab_name_`j' "`generate'`lab_name_`j''"
        }
    }

    * =========================================================================
    * REGEX PRE-VALIDATION (R1) — structural check
    * =========================================================================
    * Stata's regexm() is lenient and never errors on invalid patterns.
    * We check for the most common structural issues: unmatched brackets.
    if "`mode'" == "regex" {
        forvalues i = 1/`n_conditions' {
            mata: _codescan_validate_regex(`"`def_pattern_`i''"', "`def_name_`i''", "pattern")
            if `"`def_excl_`i''"' != "" {
                mata: _codescan_validate_regex(`"`def_excl_`i''"', "`def_name_`i''", "exclusion")
            }
        }
    }

    * =========================================================================
    * LEVEL() — truncate patterns to N characters (C4)
    * =========================================================================
    if `level' > 0 & "`mode'" == "prefix" {
        forvalues i = 1/`n_conditions' {
            * Truncate each pipe-separated prefix to level() characters
            local _lv_remaining `"`def_pattern_`i''"'
            local _lv_result ""
            while `"`_lv_remaining'"' != "" {
                local _lv_pos = strpos(`"`_lv_remaining'"', "|")
                if `_lv_pos' > 0 {
                    local _lv_tok = substr(`"`_lv_remaining'"', 1, `_lv_pos' - 1)
                    local _lv_remaining = substr(`"`_lv_remaining'"', `_lv_pos' + 1, .)
                }
                else {
                    local _lv_tok `"`_lv_remaining'"'
                    local _lv_remaining ""
                }
                local _lv_tok = strtrim(`"`_lv_tok'"')
                if `"`_lv_tok'"' != "" {
                    local _lv_tok = substr(`"`_lv_tok'"', 1, `level')
                    if `"`_lv_result'"' == "" {
                        local _lv_result `"`_lv_tok'"'
                    }
                    else {
                        local _lv_result `"`_lv_result'|`_lv_tok'"'
                    }
                }
            }
            local def_pattern_`i' `"`_lv_result'"'
        }
    }

    * =========================================================================
    * SCORE() — Charlson default weights (F2)
    * =========================================================================
    if "`score'" != "" {
        local _score_type = lower("`score'")
        if "`_score_type'" == "charlson" {
            * Quan et al. 2011 updated Charlson weights (ICD-10 codes from Quan et al. 2005)
            * Map condition names to standard Charlson weights
            forvalues i = 1/`n_conditions' {
                local _snm = lower("`def_name_`i''")
                * Strip any generate() prefix for matching
                if "`generate'" != "" {
                    local _snm = substr("`_snm'", strlen("`generate'") + 1, .)
                }
                local def_weight_`i' = 0
                if inlist("`_snm'", "mi", "chf", "pvd", "dementia", "copd") {
                    local def_weight_`i' = 1
                }
                if inlist("`_snm'", "cvd", "stroke", "cerebrovascular") {
                    local def_weight_`i' = 1
                }
                if inlist("`_snm'", "rheumatic", "rheumatoid", "connective") {
                    local def_weight_`i' = 1
                }
                if inlist("`_snm'", "peptic", "ulcer", "pud") {
                    local def_weight_`i' = 1
                }
                if inlist("`_snm'", "liver_mild", "mild_liver") {
                    local def_weight_`i' = 1
                }
                if inlist("`_snm'", "dm", "dm1", "dm2", "dm_uncomp", "diabetes") {
                    local def_weight_`i' = 1
                }
                if inlist("`_snm'", "dm_comp", "dm_complicated", "diabetes_comp") {
                    local def_weight_`i' = 2
                }
                if inlist("`_snm'", "hemiplegia", "paraplegia", "paralysis") {
                    local def_weight_`i' = 2
                }
                if inlist("`_snm'", "renal", "ckd", "kidney") {
                    local def_weight_`i' = 2
                }
                if inlist("`_snm'", "cancer", "malignancy", "tumor") {
                    local def_weight_`i' = 2
                }
                if inlist("`_snm'", "liver_severe", "severe_liver") {
                    local def_weight_`i' = 3
                }
                if inlist("`_snm'", "metastatic", "mets") {
                    local def_weight_`i' = 6
                }
                if inlist("`_snm'", "hiv", "aids") {
                    local def_weight_`i' = 6
                }
            }
            * Warn for unrecognized condition names
            forvalues i = 1/`n_conditions' {
                if `def_weight_`i'' == 0 {
                    local _warn_nm = lower("`def_name_`i''")
                    if "`generate'" != "" {
                        local _warn_nm = substr("`_warn_nm'", strlen("`generate'") + 1, .)
                    }
                    noisily display as text ///
                        "(note: `_warn_nm' is not a recognized Charlson condition name; weight = 0)"
                }
            }
        }
        else if "`_score_type'" == "elixhauser" {
            * Van Walraven et al. 2009 Elixhauser weights
            * ICD-10 condition names mapped to van Walraven weights
            * _elix_matched_`i' = 1 when name was recognized (even if weight = 0)
            forvalues i = 1/`n_conditions' {
                local _snm = lower("`def_name_`i''")
                if "`generate'" != "" {
                    local _snm = substr("`_snm'", strlen("`generate'") + 1, .)
                }
                local def_weight_`i' = 0
                local _elix_matched_`i' = 0
                if inlist("`_snm'", "chf", "heart_failure") {
                    local def_weight_`i' = 7
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "arrhythmia", "cardiac_arrhythmia") {
                    local def_weight_`i' = 5
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "valvular", "valvular_disease") {
                    local def_weight_`i' = -1
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "pulmonary_circ", "pulmonary_circulation") {
                    local def_weight_`i' = 4
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "pvd", "peripheral_vascular") {
                    local def_weight_`i' = 2
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "htn_uncomp", "hypertension_uncomp") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "htn_comp", "hypertension_comp") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "paralysis") {
                    local def_weight_`i' = 7
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "neuro_other", "other_neurological") {
                    local def_weight_`i' = 6
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "copd", "chronic_pulmonary") {
                    local def_weight_`i' = 3
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "dm_uncomp", "diabetes_uncomp") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "dm_comp", "diabetes_comp") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "hypothyroid", "hypothyroidism") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "renal", "renal_failure") {
                    local def_weight_`i' = 5
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "liver", "liver_disease") {
                    local def_weight_`i' = 11
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "pud", "peptic_ulcer") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "hiv", "aids") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "lymphoma") {
                    local def_weight_`i' = 9
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "metastatic", "metastatic_cancer") {
                    local def_weight_`i' = 12
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "solid_tumor", "solid_tumour") {
                    local def_weight_`i' = 4
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "rheumatoid", "rheumatoid_arthritis", "collagen") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "coagulopathy") {
                    local def_weight_`i' = 3
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "obesity") {
                    local def_weight_`i' = -4
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "weight_loss") {
                    local def_weight_`i' = 6
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "fluid_electrolyte", "fluid_electrolytes") {
                    local def_weight_`i' = 5
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "blood_loss_anemia", "blood_loss") {
                    local def_weight_`i' = -2
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "deficiency_anemia", "anemia") {
                    local def_weight_`i' = -2
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "alcohol", "alcohol_abuse") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "drug", "drug_abuse") {
                    local def_weight_`i' = -7
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "psychoses", "psychosis") {
                    local def_weight_`i' = 0
                    local _elix_matched_`i' = 1
                }
                if inlist("`_snm'", "depression") {
                    local def_weight_`i' = -3
                    local _elix_matched_`i' = 1
                }
            }
            * Warn for unrecognized Elixhauser condition names (matched flag = 0)
            forvalues i = 1/`n_conditions' {
                if !`_elix_matched_`i'' {
                    local _warn_nm = lower("`def_name_`i''")
                    if "`generate'" != "" {
                        local _warn_nm = substr("`_warn_nm'", strlen("`generate'") + 1, .)
                    }
                    noisily display as text ///
                        "(note: `_warn_nm' is not a recognized Elixhauser condition name; weight = 0)"
                }
            }
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
    }

    local _scorename "_score"
    if "`generate'" != "" {
        local _scorename "`generate'_score"
    }

    * Validate every created output up front so replace cannot clobber scan
    * inputs before the row scanner runs.
    local _n_outputs = 0
    forvalues i = 1/`n_conditions' {
        local ++_n_outputs
        local _output_`_n_outputs' "`def_name_`i''"
        if "`collapse'" != "" | "`merge'" != "" {
            if "`earliestdate'" != "" {
                local ++_n_outputs
                local _output_`_n_outputs' "`def_name_`i''_first"
            }
            if "`latestdate'" != "" {
                local ++_n_outputs
                local _output_`_n_outputs' "`def_name_`i''_last"
            }
            if "`countdate'" != "" {
                local ++_n_outputs
                local _output_`_n_outputs' "`def_name_`i''_count"
            }
            if "`countrows'" != "" {
                local ++_n_outputs
                local _output_`_n_outputs' "`def_name_`i''_nrows"
            }
        }
    }
    if "`score'" != "" {
        local ++_n_outputs
        local _output_`_n_outputs' "`_scorename'"
    }
    if "`unmatched'" != "" {
        local ++_n_outputs
        local _output_`_n_outputs' "`unmatched'"
    }
    if "`matched_code'" != "" {
        local ++_n_outputs
        local _output_`_n_outputs' "`matched_code'"
    }

    forvalues i = 1/`_n_outputs' {
        local _out_nm "`_output_`i''"
        foreach v of local varlist {
            if "`_out_nm'" == "`v'" {
                display as error "output name `_out_nm' conflicts with a varlist variable"
                exit 198
            }
        }
        if "`_out_nm'" == "`id'" | "`_out_nm'" == "`date'" | "`_out_nm'" == "`refdate'" {
            display as error "output name `_out_nm' conflicts with id(), date(), or refdate() variable"
            exit 198
        }
        forvalues j = 1/`=`i'-1' {
            if "`_out_nm'" == "`_output_`j''" {
                display as error "output name `_out_nm' is specified more than once; choose distinct names"
                exit 198
            }
        }
        if "`replace'" == "" {
            capture confirm new variable `_out_nm'
            if _rc {
                display as error "variable `_out_nm' already exists; use replace option"
                exit 110
            }
        }
    }

    * =========================================================================
    * PARSE HIERARCHY() — full validation now that condition names are known
    * =========================================================================
    if `"`hierarchy'"' != "" {
        local _hier_str `"`hierarchy'"'
        while `"`_hier_str'"' != "" {
            gettoken _hpair _hier_str : _hier_str, parse("\")
            local _hpair = strtrim(`"`_hpair'"')
            if `"`_hpair'"' == "\" | `"`_hpair'"' == "" continue
            local _n_hier_pairs = `_n_hier_pairs' + 1

            * Split on >
            gettoken _hsup _hinf : _hpair, parse(">")
            local _hsup = strtrim(`"`_hsup'"')
            local _hinf = strtrim(subinstr(`"`_hinf'"', ">", "", 1))

            * Resolve hierarchy names by membership: exact match first, then
            * generated-prefix fallback for bare names.
            local _hsup_full "`_hsup'"
            local _hinf_full "`_hinf'"
            local _hfound_sup = 0
            local _hfound_inf = 0
            forvalues i = 1/`n_conditions' {
                if "`def_name_`i''" == "`_hsup_full'" local _hfound_sup = 1
                if "`def_name_`i''" == "`_hinf_full'" local _hfound_inf = 1
            }
            if "`generate'" != "" {
                if !`_hfound_sup' {
                    local _hsup_pref "`generate'`_hsup'"
                    forvalues i = 1/`n_conditions' {
                        if "`def_name_`i''" == "`_hsup_pref'" {
                            local _hfound_sup = 1
                            local _hsup_full "`_hsup_pref'"
                        }
                    }
                }
                if !`_hfound_inf' {
                    local _hinf_pref "`generate'`_hinf'"
                    forvalues i = 1/`n_conditions' {
                        if "`def_name_`i''" == "`_hinf_pref'" {
                            local _hfound_inf = 1
                            local _hinf_full "`_hinf_pref'"
                        }
                    }
                }
            }
            if !`_hfound_sup' {
                display as error "hierarchy(): `_hsup' is not a defined condition name"
                exit 198
            }
            if !`_hfound_inf' {
                display as error "hierarchy(): `_hinf' is not a defined condition name"
                exit 198
            }

            local _hier_sup_`_n_hier_pairs' "`_hsup_full'"
            local _hier_inf_`_n_hier_pairs' "`_hinf_full'"
        }
    }

    * =========================================================================
    * PARSE LABEL()
    * =========================================================================
    * Note: codefile labels already populated above; label() can override them
    if `"`label'"' != "" {
        local lab_remaining `"`label'"'
        while `"`lab_remaining'"' != "" {
            local bspos = strpos(`"`lab_remaining'"', "\")
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

        * Validate label names match condition names
        forvalues j = 1/`n_labels' {
            local found = 0
            forvalues k = 1/`n_conditions' {
                if "`lab_name_`j''" == "`def_name_`k''" {
                    local found = 1
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
    * TOSTRING (auto-convert numeric variables)
    * =========================================================================
    if "`tostring'" != "" {
        foreach var of local varlist {
            capture confirm string variable `var'
            if _rc {
                noisily display as text "(note: converting `var' from numeric to string)"
                quietly tostring `var', replace force
            }
        }
    }

    * =========================================================================
    * MARK SAMPLE & TIME WINDOW
    * =========================================================================
    * Note: cannot use marksample — string asis puts quotes in `0' which
    * breaks marksample's parser. Use mark for if/in only.
    * Do NOT markout the varlist: empty strings in code variables are expected.
    tempvar touse
    mark `touse' `if' `in'

    * Exclude missing id values from collapse/merge to prevent phantom grouping
    if "`collapse'" != "" | "`merge'" != "" {
        quietly replace `touse' = 0 if missing(`id')
    }

    local include_ref = ("`inclusive'" != "" | (`has_lookback' & `has_lookfwd'))

    if `has_lookback' | `has_lookfwd' {
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
    local scan_varlist "`varlist'"

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
        mata: _codescan_mata_scan()

        * Noisily display and zero-match warnings (from Mata-computed counts)
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            count if `name' > 0 & `touse'
            local _n_matched = r(N)

            if "`noisily'" != "" {
                noisily display as text "  `name': " as result `_n_matched' ///
                    as text " matches across `nvars_scan' variables"
            }

            if `_n_matched' == 0 {
                noisily display as text "(note: condition `name' matched 0 observations)"
            }
        }

        * R1: Warn on overlapping conditions
        if "`cooccurrence'" == "" & `n_conditions' > 1 {
            forvalues _oi = 1/`n_conditions' {
                forvalues _oj = `=`_oi'+1'/`n_conditions' {
                    local _on1 "`def_name_`_oi''"
                    local _on2 "`def_name_`_oj''"
                    quietly count if `_on1' > 0 & `_on2' > 0 & `touse'
                    local _overlap = r(N)
                    if `_overlap' > 0 {
                        quietly count if `_on1' > 0 & `touse'
                        local _cnt1 = r(N)
                        quietly count if `_on2' > 0 & `touse'
                        local _cnt2 = r(N)
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
    * MULTI-WINDOW SENSITIVITY ANALYSIS (W4)
    * =========================================================================
    * Must run BEFORE collapse since secondary scans need row-level data.
    if `n_lookback_windows' > 1 {
        tempname sensitivity
        matrix `sensitivity' = J(`n_conditions', `n_lookback_windows', .)
        local _sens_cnames ""

        * First window: count from primary scan
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            quietly count if `name' > 0 & `touse'
            local _prim_n_`i' = r(N)
        }

        * Run additional windows
        forvalues _wi = 2/`n_lookback_windows' {
            local _lb_wi = `_lookback_`_wi''
            local _sens_cnames "`_sens_cnames' `_lb_wi'd"

            tempfile _sens_save
            quietly save `_sens_save'
            quietly {
                tempvar _stouse
                mark `_stouse' `if' `in'
                if "`id'" != "" replace `_stouse' = 0 if missing(`id')
                replace `_stouse' = 0 if missing(`date') | missing(`refdate')

                if `has_lookfwd' {
                    replace `_stouse' = 0 if `date' < `refdate' - `_lb_wi'
                    replace `_stouse' = 0 if `date' > `refdate' + `lookforward'
                }
                else {
                    replace `_stouse' = 0 if `date' < `refdate' - `_lb_wi'
                    if `include_ref' {
                        replace `_stouse' = 0 if `date' > `refdate'
                    }
                    else {
                        replace `_stouse' = 0 if `date' >= `refdate'
                    }
                }

                * Create temp indicators
                forvalues i = 1/`n_conditions' {
                    tempvar _sind_`i'
                    gen byte `_sind_`i'' = 0
                }

                * Run Mata scan with temp touse
                local _mata_touse "`_stouse'"
                forvalues i = 1/`n_conditions' {
                    local _mata_name_`i' "`_sind_`i''"
                }
                local _mata_detail ""
                local _mata_countmode ""
                mata: _codescan_mata_scan()

                * Collapse to get patient-level counts
                count if `_stouse'
                local _sens_N_`_wi' = r(N)
                if `_sens_N_`_wi'' > 0 {
                    if "`collapse'" != "" | "`merge'" != "" {
                        local _sens_cexpr ""
                        forvalues i = 1/`n_conditions' {
                            local _sens_cexpr "`_sens_cexpr' (max) `_sind_`i''"
                        }
                        collapse `_sens_cexpr' if `_stouse', by(`id')
                        count
                        local _sens_N_`_wi' = r(N)
                    }
                    forvalues i = 1/`n_conditions' {
                        count if `_sind_`i'' > 0
                        local _sens_ct_`_wi'_`i' = r(N)
                    }
                }
                else {
                    forvalues i = 1/`n_conditions' {
                        local _sens_ct_`_wi'_`i' = 0
                    }
                }
            }
            quietly use `_sens_save', clear

            * Restore original Mata locals for the main scan
            local _mata_touse "`touse'"
            forvalues i = 1/`n_conditions' {
                local _mata_name_`i' "`def_name_`i''"
            }
            local _mata_detail "`detail'"
            local _mata_countmode "`countmode'"
        }

        * Store sensitivity matrix (deferred until after display section
        * computes N_display for prevalence calculation)
        local _has_sensitivity = 1
    }
    else {
        local _has_sensitivity = 0
    }

    * =========================================================================
    * PREPARE DATE VARIABLES (PRE-COLLAPSE/MERGE)
    * =========================================================================
    if ("`collapse'" != "" | "`merge'" != "") & "`date'" != "" {
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
                    bysort `id' `date': egen byte `hasmatch_`i'' = max(`name' * `touse')
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
        * Compute patient-level indicators via tempframe + merge back
        tempname _merge_frame
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
                    quietly bysort `id' `date': egen byte `mhasmatch_`i'' = max(`name' * `touse')
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

        quietly count if `touse'
        local N_merged = r(N)
        quietly {
            tempvar _uniq_id
            bysort `id': gen byte `_uniq_id' = (`touse' & sum(`touse') == 1)
            count if `_uniq_id' == 1
        }
        local N_unique_ids = r(N)
    }

    * =========================================================================
    * HIERARCHY — condition supersession
    * =========================================================================
    * Must run BEFORE score so zeroed-out conditions don't inflate the index.
    * Requires collapse or merge (patient-level data).
    if `_n_hier_pairs' > 0 {
        quietly {
            forvalues _hp = 1/`_n_hier_pairs' {
                local _h_sup "`_hier_sup_`_hp''"
                local _h_inf "`_hier_inf_`_hp''"
                if "`countmode'" != "" {
                    replace `_h_inf' = 0 if `_h_sup' > 0 & !missing(`_h_sup')
                }
                else {
                    replace `_h_inf' = 0 if `_h_sup' == 1
                }
            }
        }
        if "`noisily'" != "" {
            noisily display as text "  (hierarchy: `_n_hier_pairs' rule(s) applied)"
        }
    }

    * =========================================================================
    * SCORE — weighted comorbidity index (F2)
    * =========================================================================
    if "`score'" != "" {
        local _scorename "_score"
        if "`generate'" != "" {
            local _scorename "`generate'_score"
        }
        if "`replace'" != "" {
            capture drop `_scorename'
        }
        quietly gen double `_scorename' = 0
        forvalues i = 1/`n_conditions' {
            local name "`def_name_`i''"
            local wt = `def_weight_`i''
            if `wt' != 0 {
                if inlist("`_score_type'", "charlson", "elixhauser") {
                    * Charlson/Elixhauser: binary presence regardless of countmode
                    * sign() preserves missing propagation for unmatched merge rows
                    quietly replace `_scorename' = `_scorename' + `wt' * sign(`name')
                }
                else {
                    quietly replace `_scorename' = `_scorename' + `wt' * `name'
                }
            }
        }
        label variable `_scorename' "`_score_type' score"
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

    display as text _n "codescan: `n_conditions' condition" ///
        cond(`n_conditions' > 1, "s", "") ", `nvars' variable" ///
        cond(`nvars' > 1, "s", "") ", N = " as result %10.0fc `N_display'

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
            * merge+countmode: compute from patient-level (one row per patient)
            quietly {
                tempvar _cmtag
                bysort `id': gen byte `_cmtag' = (_n == 1)
                count if `_cmtag' == 1 & `name' > 0
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

    if "`collapse'" != "" {
        display as text _n "  Collapsed to " as result %10.0fc `N_collapsed' ///
            as text " unique `id' values"
    }
    if "`merge'" != "" {
        display as text _n "  Merged patient-level indicators for " ///
            as result %10.0fc `N_unique_ids' as text " unique `id' values"
    }

    * Score display
    if "`score'" != "" {
        if "`merge'" != "" {
            * Patient-level score stats (one row per patient)
            tempvar _sc_tag
            quietly bysort `id': gen byte `_sc_tag' = (_n == 1)
            quietly summarize `_scorename' if `_sc_tag' == 1
            local _sc_mean = r(mean)
            local _sc_min = r(min)
            local _sc_max = r(max)
            quietly _pctile `_scorename' if `_sc_tag' == 1, p(50)
            local _sc_med = r(r1)
            quietly drop `_sc_tag'
        }
        else {
            quietly summarize `_scorename'
            local _sc_mean = r(mean)
            local _sc_min = r(min)
            local _sc_max = r(max)
            quietly _pctile `_scorename', p(50)
            local _sc_med = r(r1)
        }
        display as text _n "  `_score_type' score: mean = " as result %5.2f `_sc_mean' ///
            as text ", median = " as result %5.1f `_sc_med' ///
            as text ", range = [" as result %3.0f `_sc_min' ///
            as text ", " as result %3.0f `_sc_max' as text "]"
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
    * GRAPH — prevalence bar chart (O1)
    * =========================================================================
    if "`graph'" != "" {
        tempfile _graph_save
        quietly save `_graph_save'
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
            blabel(bar, format(%4.1f)) ///
            scheme(plotplainblind)
        quietly use `_graph_save', clear
    }

    * =========================================================================
    * RETURN RESULTS (posted before export/saving so r() survives side-effect failures)
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
    if "`score'" != "" {
        local newvars "`newvars' `_scorename'"
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
    if "`codefile'" != ""              return local codefile "`codefile'"
    if "`id'" != ""                    return local id "`id'"
    if `has_lookback' & `n_lookback_windows' == 1 {
        return scalar lookback = `_lookback_primary'
    }
    else if `has_lookback' {
        return local lookback "`lookback'"
    }
    if `has_lookfwd'                   return scalar lookforward = `lookforward'
    if `has_lookback' | `has_lookfwd'  return local refdate "`refdate'"
    if "`frame'" != ""                 return local frame "`frame'"
    if "`score'" != ""                 return local score "`_score_type'"
    return scalar ci_level = c(level)
    * , copy — keep local tempname matrices alive for the export block below.
    return matrix summary = `summary', copy
    return matrix codelist = `codelist', copy
    if "`detail'" != ""                return matrix varcounts = `varcounts', copy
    if "`cooccurrence'" != ""          return matrix cooccurrence = `cooc', copy
    if `_has_sensitivity'              return matrix sensitivity = `sensitivity', copy

    * =========================================================================
    * EXPORT — save results to file (O2)
    * =========================================================================
    if `"`export'"' != "" {
        local _exp_ext = lower(substr(`"`export'"', -4, .))
        tempfile _export_save
        quietly save `_export_save'
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
            if "`_exp_ext'" == ".csv" {
                export delimited using `"`export'"', replace
            }
            else {
                export excel using `"`export'"', firstrow(variables) replace
                * Add co-occurrence as second sheet if available
                if "`cooccurrence'" != "" {
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
                    export excel using `"`export'"', firstrow(variables) ///
                        sheet("cooccurrence") sheetmodify
                }
            }
        }
        quietly use `_export_save', clear
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
                capture frame drop `frame'
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
        * Clean up: restore any active user preserve, drop partial indicator variables.
        capture restore
        if "`_n_outputs'" != "" {
            forvalues i = 1/`_n_outputs' {
                local _drop_nm "`_output_`i''"
                local _drop_protected = 0
                foreach v of local varlist {
                    if "`_drop_nm'" == "`v'" local _drop_protected = 1
                }
                if "`_drop_nm'" == "`id'" | "`_drop_nm'" == "`date'" | "`_drop_nm'" == "`refdate'" {
                    local _drop_protected = 1
                }
                if !`_drop_protected' capture drop `_drop_nm'
            }
        }
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _codescan_write_builtin_codefile, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , NAME(string) TARGET(string)

    tempname _cfh
    postfile `_cfh' str32 name str2045 pattern str2045 exclusion str80 label double weight ///
        using `"`target'"', replace

    if lower("`name'") == "charlson_icd10_example.csv" {
        post `_cfh' ("mi") ("I21|I22|I252") ("") ("Myocardial Infarction") (1)
        post `_cfh' ("chf") ("I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290") ("") ("Congestive Heart Failure") (1)
        post `_cfh' ("pvd") ("I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959") ("") ("Peripheral Vascular Disease") (1)
        post `_cfh' ("cvd") ("G45|G46|H340|I60|I61|I62|I63|I64|I65|I66|I67|I68|I69") ("") ("Cerebrovascular Disease") (1)
        post `_cfh' ("dementia") ("F00|F01|F02|F03|F051|G30|G311") ("") ("Dementia") (1)
        post `_cfh' ("copd") ("I278|I279|J40|J41|J42|J43|J44|J45|J46|J47|J60|J61|J62|J63|J64|J65|J66|J67|J684|J701|J703") ("") ("Chronic Pulmonary Disease") (1)
        post `_cfh' ("rheumatic") ("M05|M06|M315|M32|M33|M34|M351|M353|M360") ("") ("Rheumatic Disease") (1)
        post `_cfh' ("peptic") ("K25|K26|K27|K28") ("") ("Peptic Ulcer Disease") (1)
        post `_cfh' ("liver_mild") ("B18|K700|K701|K702|K703|K709|K713|K714|K715|K717|K73|K74|K760|K762|K763|K764|K768|K769|Z944") ("") ("Mild Liver Disease") (1)
        post `_cfh' ("dm_uncomp") ("E100|E101|E106|E108|E109|E110|E111|E116|E118|E119|E120|E121|E126|E128|E129|E130|E131|E136|E138|E139|E140|E141|E146|E148|E149") ("") ("Diabetes without Complications") (1)
        post `_cfh' ("dm_comp") ("E102|E103|E104|E105|E107|E112|E113|E114|E115|E117|E122|E123|E124|E125|E127|E132|E133|E134|E135|E137|E142|E143|E144|E145|E147") ("") ("Diabetes with Complications") (2)
        post `_cfh' ("hemiplegia") ("G041|G114|G801|G802|G81|G82|G830|G831|G832|G833|G834|G839") ("") ("Hemiplegia or Paraplegia") (2)
        post `_cfh' ("renal") ("I12|I13|N03|N05|N18|N19|N250|Z490|Z491|Z492|Z940|Z992") ("") ("Renal Disease") (2)
        post `_cfh' ("cancer") ("C00|C01|C02|C03|C04|C05|C06|C07|C08|C09|C10|C11|C12|C13|C14|C15|C16|C17|C18|C19|C20|C21|C22|C23|C24|C25|C26|C30|C31|C32|C33|C34|C37|C38|C39|C40|C41|C43|C45|C46|C47|C48|C49|C50|C51|C52|C53|C54|C55|C56|C57|C58|C60|C61|C62|C63|C64|C65|C66|C67|C68|C69|C70|C71|C72|C73|C74|C75|C76|C81|C82|C83|C84|C85|C88|C90|C91|C92|C93|C94|C95|C96") ("C77|C78|C79|C80") ("Any Malignancy, Including Leukemia and Lymphoma") (2)
        post `_cfh' ("liver_severe") ("I85|I864|I982|K704|K711|K721|K729|K765|K766|K767") ("") ("Moderate or Severe Liver Disease") (3)
        post `_cfh' ("metastatic") ("C77|C78|C79|C80") ("") ("Metastatic Solid Tumor") (6)
        post `_cfh' ("hiv") ("B20|B21|B22|B24") ("") ("AIDS/HIV") (6)
    }
    else if lower("`name'") == "elixhauser_icd10_example.csv" {
        post `_cfh' ("chf") ("I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290") ("") ("Congestive Heart Failure") (7)
        post `_cfh' ("arrhythmia") ("I441|I442|I443|I456|I459|I47|I48|I49|R000|R001|R008|T821|Z450|Z950") ("") ("Cardiac Arrhythmias") (5)
        post `_cfh' ("valvular") ("A520|I05|I06|I07|I08|I091|I098|I34|I35|I36|I37|I38|I39|Q230|Q231|Q232|Q233|Z952|Z953|Z954") ("") ("Valvular Disease") (-1)
        post `_cfh' ("pulmonary_circ") ("I26|I27|I280|I288|I289") ("") ("Pulmonary Circulation Disorders") (4)
        post `_cfh' ("pvd") ("I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959") ("") ("Peripheral Vascular Disorders") (2)
        post `_cfh' ("htn_uncomp") ("I10") ("") ("Hypertension Uncomplicated") (0)
        post `_cfh' ("htn_comp") ("I11|I12|I13|I15") ("") ("Hypertension Complicated") (0)
        post `_cfh' ("paralysis") ("G041|G114|G801|G802|G803|G81|G82|G830|G831|G832|G833|G834|G839") ("") ("Paralysis") (7)
        post `_cfh' ("neuro_other") ("G10|G11|G12|G13|G20|G21|G22|G254|G255|G312|G318|G319|G32|G35|G36|G37|G40|G41|G931|G934") ("") ("Other Neurological Disorders") (6)
        post `_cfh' ("copd") ("I278|I279|J40|J41|J42|J43|J44|J45|J46|J47|J60|J61|J62|J63|J64|J65|J66|J67|J684|J701|J703") ("") ("Chronic Pulmonary Disease") (3)
        post `_cfh' ("dm_uncomp") ("E100|E101|E106|E108|E109|E110|E111|E116|E118|E119|E120|E121|E126|E128|E129|E130|E131|E136|E138|E139|E140|E141|E146|E148|E149") ("") ("Diabetes Uncomplicated") (0)
        post `_cfh' ("dm_comp") ("E102|E103|E104|E105|E107|E112|E113|E114|E115|E117|E122|E123|E124|E125|E127|E132|E133|E134|E135|E137|E142|E143|E144|E145|E147") ("") ("Diabetes Complicated") (0)
        post `_cfh' ("hypothyroid") ("E00|E01|E02|E03|E890") ("") ("Hypothyroidism") (0)
        post `_cfh' ("renal") ("I12|I13|N00|N01|N02|N03|N04|N05|N07|N11|N14|N17|N18|N19|Q61") ("") ("Renal Failure") (5)
        post `_cfh' ("liver") ("B18|I85|I864|I982|K70|K711|K713|K714|K715|K717|K72|K73|K74|K760|K762|K763|K764|K765|K766|K767|K768|K769|Z944") ("") ("Liver Disease") (11)
        post `_cfh' ("pud") ("K257|K259|K267|K269|K277|K279|K287|K289") ("") ("Peptic Ulcer Disease Excluding Bleeding") (0)
        post `_cfh' ("hiv") ("B20|B21|B22|B24") ("") ("AIDS/HIV") (0)
        post `_cfh' ("lymphoma") ("C81|C82|C83|C84|C85|C88|C96|C900|C902") ("") ("Lymphoma") (9)
        post `_cfh' ("metastatic") ("C77|C78|C79|C80") ("") ("Metastatic Cancer") (12)
        post `_cfh' ("solid_tumor") ("C00|C01|C02|C03|C04|C05|C06|C07|C08|C09|C10|C11|C12|C13|C14|C15|C16|C17|C18|C19|C20|C21|C22|C23|C24|C25|C26|C30|C31|C32|C33|C34|C37|C38|C39|C40|C41|C43|C45|C46|C47|C48|C49|C50|C51|C52|C53|C54|C55|C56|C57|C58|C60|C61|C62|C63|C64|C65|C66|C67|C68|C69|C70|C71|C72|C73|C74|C75|C76|C97") ("C77|C78|C79|C80") ("Solid Tumor Without Metastasis") (4)
        post `_cfh' ("rheumatoid") ("M05|M06|M315|M32|M33|M34|M351|M353|M360") ("") ("Rheumatoid Arthritis/Collagen Vascular Diseases") (0)
        post `_cfh' ("coagulopathy") ("D65|D66|D67|D68|D691|D693|D694|D695|D696") ("") ("Coagulopathy") (3)
        post `_cfh' ("obesity") ("E66") ("") ("Obesity") (-4)
        post `_cfh' ("weight_loss") ("E40|E41|E42|E43|E44|E45|E46|R634|R64") ("") ("Weight Loss") (6)
        post `_cfh' ("fluid_electrolyte") ("E222|E86|E87") ("") ("Fluid and Electrolyte Disorders") (5)
        post `_cfh' ("blood_loss_anemia") ("D500") ("") ("Blood Loss Anemia") (-2)
        post `_cfh' ("deficiency_anemia") ("D508|D509|D51|D52|D53") ("") ("Deficiency Anemia") (-2)
        post `_cfh' ("alcohol") ("F10|E52|G621|I426|K292|K700|K703|K709|T51|Z502|Z714|Z721") ("") ("Alcohol Abuse") (0)
        post `_cfh' ("drug") ("F11|F12|F13|F14|F15|F16|F18|F19|Z715|Z722") ("") ("Drug Abuse") (-7)
        post `_cfh' ("psychoses") ("F20|F22|F23|F24|F25|F28|F29|F302|F312|F315") ("") ("Psychoses") (0)
        post `_cfh' ("depression") ("F204|F313|F314|F315|F32|F33|F341|F412|F432") ("") ("Depression") (-3)
    }
    else {
        postclose `_cfh'
        display as error "built-in codefile `name' is not supported"
        exit 601
    }

    postclose `_cfh'
    return local path `"`target'"'
    }
    local rc = _rc
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
    string scalar    mode, touse_name, vcname, val, mcname
    string rowvector scanvars, cond_names
    string colvector patterns, excl_patterns, anchored_pats, anchored_excl
    string colvector col
    string colvector mcode
    real matrix      indicators, varcounts
    real colvector   touse

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

    // F1: nocase — uppercase patterns for case-insensitive matching
    if (use_nocase) {
        for (i = 1; i <= ncond; i++) {
            patterns[i] = strupper(patterns[i])
            if (excl_patterns[i] != "") {
                excl_patterns[i] = strupper(excl_patterns[i])
            }
        }
    }

    // Pre-build anchored regex patterns (avoid repeated string concat)
    if (!is_prefix) {
        anchored_pats = J(ncond, 1, "")
        anchored_excl = J(ncond, 1, "")
        for (i = 1; i <= ncond; i++) {
            anchored_pats[i] = "^(" + patterns[i] + ")"
            if (excl_patterns[i] != "") {
                anchored_excl[i] = "^(" + excl_patterns[i] + ")"
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

    // ── SINGLE PASS: inclusion with inline exclusion per code value ──
    // Each code value is independently evaluated: it must match the
    // inclusion pattern AND NOT match the exclusion pattern.  This
    // ensures a valid code in one variable is not zeroed by an excluded
    // code in another variable on the same row.
    for (j = 1; j <= nvars; j++) {
        st_sview(col, ., scanvars[j])

        for (i = 1; i <= N; i++) {
            if (!touse[i]) continue
            if (col[i] == "") continue

            // Inline value transforms: strip dots, then uppercase
            val = col[i]
            if (strip_dots) val = subinstr(val, ".", "", .)
            if (use_nocase) val = strupper(val)

            for (k = 1; k <= ncond; k++) {
                if (!is_count && indicators[i, k]) continue

                // ── Inclusion check ──
                matched = 0
                if (is_prefix) {
                    npfx = cols(*pfx_list[k])
                    for (len = 1; len <= npfx; len++) {
                        if (substr(val, 1, (*pfx_lens[k])[len]) == (*pfx_list[k])[len]) {
                            matched = 1
                            break
                        }
                    }
                }
                else {
                    if (regexm(val, anchored_pats[k])) matched = 1
                }

                if (!matched) continue

                // ── Inline exclusion check ──
                if (has_excl & excl_patterns[k] != "") {
                    excluded = 0
                    if (is_prefix) {
                        enpfx = cols(*excl_pfx_list[k])
                        for (len = 1; len <= enpfx; len++) {
                            if (substr(val, 1, (*excl_pfx_lens[k])[len]) == (*excl_pfx_list[k])[len]) {
                                excluded = 1
                                break
                            }
                        }
                    }
                    else {
                        if (regexm(val, anchored_excl[k])) excluded = 1
                    }
                    if (excluded) continue
                }

                // ── Code passed inclusion and exclusion — record match ──
                if (is_count) {
                    indicators[i, k] = indicators[i, k] + 1
                }
                else {
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

// R1: Validate regex pattern structure (check balanced brackets/parens)
void _codescan_validate_regex(string scalar pat, string scalar cname, string scalar ptype)
{
    real scalar i, n, depth_paren, depth_bracket, escaped
    string scalar ch

    n = strlen(pat)
    depth_paren = 0
    depth_bracket = 0
    escaped = 0

    for (i = 1; i <= n; i++) {
        ch = substr(pat, i, 1)
        if (escaped) {
            escaped = 0
            continue
        }
        if (ch == "\") {
            escaped = 1
            continue
        }
        if (depth_bracket == 0) {
            if (ch == "(") depth_paren = depth_paren + 1
            else if (ch == ")") {
                depth_paren = depth_paren - 1
                if (depth_paren < 0) {
                    errprintf("{err}" + ptype + " for %s: unmatched ')' in pattern: %s\n", cname, pat)
                    exit(198)
                }
            }
            else if (ch == "[") depth_bracket = depth_bracket + 1
        }
        else {
            if (ch == "]") depth_bracket = depth_bracket - 1
        }
    }
    if (depth_paren != 0) {
        errprintf("{err}" + ptype + " for %s: unmatched '(' in pattern: %s\n", cname, pat)
        exit(198)
    }
    // Note: Stata's regex engine tolerates unclosed brackets, so we only
    // warn on unmatched brackets rather than erroring.
    // Unmatched brackets are still technically valid in Stata's regexm().
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
end
