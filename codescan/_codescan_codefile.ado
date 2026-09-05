*! _codescan_codefile Version 4.2.2  2026/09/06
*! Private codefile helpers for codescan
*! Author: Timothy P Copeland, Karolinska Institutet

capture program drop _codescan_parse_codefile
program define _codescan_parse_codefile, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _did_preserve = 0
    capture noisily {

    syntax , CODEFile(string)

    local resolved_codefile `"`codefile'"'
    local ext = lower(substr(`"`resolved_codefile'"', -4, .))
    if "`ext'" != ".csv" & "`ext'" != ".dta" {
        display as error "codefile() must be a .csv or .dta file"
        exit 198
    }
    capture confirm file `"`resolved_codefile'"'
    if _rc {
        display as error `"codefile(): file not found: `resolved_codefile'"'
        exit 601
    }

    preserve
    local _did_preserve = 1
    quietly {
        if "`ext'" == ".csv" {
            import delimited `"`resolved_codefile'"', clear stringcols(_all) varnames(1)
        }
        else {
            use `"`resolved_codefile'"', clear
        }
    }

    * R2: Case-tolerant column name matching.
    *
    * The mapping from physical columns to the four semantic fields must be
    * unique. Stata allows case-distinct variable names, so a .dta codefile can
    * carry both `name' and `Name' (or `PATTERN' and `Pattern'). Preferring an
    * exact lowercase hit and never looking further -- or renaming the first
    * casefold match and leaving the rest -- makes the resolution depend on
    * physical spelling and storage order and silently selects one of two
    * conflicting rule sets at rc=0: a different cohort from the same file.
    * Ambiguity is not resolvable here, so collect every casefold match per
    * field and refuse the schema when there is more than one.
    foreach _cfcol in name pattern label exclusion {
        local _cfmatch ""
        local _cfnmatch = 0
        foreach _v of varlist * {
            if lower("`_v'") == "`_cfcol'" {
                local ++_cfnmatch
                local _cfmatch "`_cfmatch' `_v'"
            }
        }
        if `_cfnmatch' > 1 {
            local _cfmatch = trim("`_cfmatch'")
            display as error "codefile(): column {bf:`_cfcol'} is ambiguous: `_cfnmatch' columns match ignoring case (`_cfmatch')"
            display as error "  rename or drop the duplicates so exactly one column supplies {bf:`_cfcol'}"
            exit 198
        }
        if `_cfnmatch' == 1 {
            local _cfhit = trim("`_cfmatch'")
            if "`_cfhit'" != "`_cfcol'" rename `_cfhit' `_cfcol'
        }
    }

    * Validate required columns. Report absent and wrong-type separately so the
    * message names the actual problem.
    foreach _cfreq in name pattern {
        capture confirm variable `_cfreq'
        if _rc {
            display as error "codefile(): file must contain a string variable {bf:`_cfreq'}"
            exit 198
        }
        capture confirm string variable `_cfreq'
        if _rc {
            local _cftype : type `_cfreq'
            display as error "codefile(): column {bf:`_cfreq'} must be a string variable; found `_cftype'"
            exit 198
        }
    }

    * Optional columns. A bare `capture confirm string variable' conflates two
    * materially different states — column absent, and column present with the
    * wrong storage type — and treating the second as the first silently
    * discards the column: a visible numeric exclusion is ignored and produces
    * an incorrect positive cohort at rc=0. Check existence first, then require
    * string storage. Do not coerce a numeric column, because its display format
    * can change the resulting text.
    local _cf_has_label = 0
    local _cf_has_excl = 0
    foreach _cfopt in label exclusion {
        capture confirm variable `_cfopt'
        if _rc continue
        capture confirm string variable `_cfopt'
        if _rc {
            local _cftype : type `_cfopt'
            display as error "codefile(): column {bf:`_cfopt'} must be a string variable; found `_cftype'"
            display as error "  convert it with {bf:tostring `_cfopt', replace} before use"
            exit 198
        }
        if "`_cfopt'" == "label"     local _cf_has_label = 1
        if "`_cfopt'" == "exclusion" local _cf_has_excl  = 1
    }

    quietly count
    local n_conditions = r(N)
    if `n_conditions' == 0 {
        display as error "codefile(): file is empty"
        exit 198
    }

    * M2: a value carrying a Stata quoting metacharacter cannot survive the
    * macro round-trip this parser and codescan.ado perform on every field. The
    * two-character sequence " followed by ' closes a compound quote, and a
    * backquote opens a macro reference, so the next expansion was corrupted
    * rather than matched: the caller saw "too few quotes" attributed to an
    * unrelated line and the call died at r(199) with no usable message. Run on
    * the data, before any value is pulled into a local, so the check itself
    * cannot be broken by the value it is checking. A lone double quote round-
    * trips correctly and is still accepted.
    local _cf_qcols name pattern
    if `_cf_has_excl'  local _cf_qcols `_cf_qcols' exclusion
    if `_cf_has_label' local _cf_qcols `_cf_qcols' label
    tempvar _cf_qbad _cf_qrow
    quietly gen long `_cf_qrow' = _n
    local _cf_qerr = 0
    foreach _qc of local _cf_qcols {
        capture drop `_cf_qbad'
        quietly gen byte `_cf_qbad' = ///
            strpos(`_qc', char(34) + char(39)) > 0 | strpos(`_qc', char(96)) > 0
        quietly count if `_cf_qbad' == 1
        if r(N) > 0 {
            local _cf_qn = r(N)
            quietly summarize `_cf_qrow' if `_cf_qbad' == 1, meanonly
            local _cf_qfirst = r(min)
            if !`_cf_qerr' {
                display as error "codefile(): unusable quoting character in the file"
            }
            local _cf_qerr = 1
            display as error "  column {bf:`_qc'}: `_cf_qn' row(s), first at row `_cf_qfirst'"
        }
    }
    if `_cf_qerr' {
        display as error "  a backquote, or a double quote immediately followed by an apostrophe, cannot be carried through Stata's macro quoting"
        display as error "  remove it; a double quote on its own is accepted"
        exit 198
    }

    local all_names ""
    local n_labels = 0
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
    }
    local all_names = trim("`all_names'")

    * R3: Codefile schema validation — batch all errors
    local _cf_errors ""
    local _cf_nerr = 0
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
                local _bad_nm "`def_name_`i''"
                local _cf_errors `"`_cf_errors'"row `i': [`_bad_nm'] is not a valid Stata name" "'
            }
        }
        * Case-insensitive: distinct-by-case names are almost always a typo and
        * a hazard in codefile-driven team workflows (F10)
        forvalues j = 1/`=`i'-1' {
            if strlower("`def_name_`i''") == strlower("`def_name_`j''") & "`def_name_`i''" != "" {
                local ++_cf_nerr
                local _dup_nm "`def_name_`i''"
                local _cf_errors `"`_cf_errors'"row `i': duplicate name [`_dup_nm'] (same as row `j', ignoring case)" "'
                continue, break
            }
        }
    }
    if `_cf_nerr' > 0 {
        display as error "codefile(): `_cf_nerr' validation error(s):"
        local _cf_remain `"`_cf_errors'"'
        forvalues _ei = 1/`_cf_nerr' {
            gettoken _emsg _cf_remain : _cf_remain
            display as error "  `_emsg'"
        }
        exit 198
    }

    }
    local rc = _rc
    if `_did_preserve' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar n_conditions = `n_conditions'
    return scalar n_labels = `n_labels'
    return local all_names "`all_names'"
    return local resolved_codefile `"`resolved_codefile'"'
    forvalues i = 1/`n_conditions' {
        return local def_name_`i' "`def_name_`i''"
        return local def_pattern_`i' `"`def_pattern_`i''"'
        return local def_excl_`i' `"`def_excl_`i''"'
    }
    if `n_labels' > 0 {
        forvalues i = 1/`n_labels' {
            return local lab_name_`i' "`lab_name_`i''"
            return local lab_label_`i' `"`lab_label_`i''"'
        }
    }
end
