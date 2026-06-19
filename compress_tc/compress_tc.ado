*! compress_tc Version 1.1.0  2026/06/19
*! Maximally compress string variables via strL conversion + compress
*! Author: Timothy P Copeland, Karolinska Institutet
*! Fork Author: Tim Copeland (Forked from strcompress)
*! Original Author: Luke Stein (lcdstein@babson.edu)
*!
*! Syntax:
*!   compress_tc [varlist] [, NOCompress NOStrl NOReport Quietly Detail ///
*!                            VARSavings LOWmem DRYrun MINlength(#)]
*!
*! Description:
*!   Two-stage string compression: (1) convert str# to strL, (2) run compress.
*!   strL stores strings in a compressed heap, beneficial for long/repeated values.
*!   Subsequent compress reverts short unique strings to str# if more efficient.
*!
*! Options:
*!   nocompress   Skip compress step (strL conversion only)
*!   nostrl       Skip strL conversion (standard compress only)
*!   noreport     Suppress compress's per-variable output; show summary only
*!   quietly      Suppress all output
*!   detail       Show per-variable type information before conversion
*!   varsavings   Report per-variable memory savings (before/after/saved)
*!   lowmem       Convert+compress one variable at a time to cap peak memory
*!   dryrun       Report projected savings without modifying the data
*!   minlength(#) Only convert str# variables at least # bytes wide to strL
*!
*! Returns:
*!   r(bytes_saved)    Bytes saved
*!   r(pct_saved)      Percentage reduction
*!   r(bytes_initial)  Initial data size
*!   r(bytes_final)    Final data size
*!   r(bytes_strl)     Bytes held in the strL heap after compression
*!   r(k_converted)    Number of variables recast to strL
*!   r(k_reverted)     Number of those that compress moved back to a fixed type
*!   r(vars_strl)      Variables stored as strL after compression
*!   r(varlist)        Variables actually processed (string variables)
*!
*! Note: Memory calculations reflect total data in dataset, not just
*!       specified varlist. This is a limitation of Stata's memory reporting.

program define compress_tc, rclass
    version 16.0
    local _user_varabbrev `c(varabbrev)'
    set varabbrev off
    local _preserved 0

    capture noisily {

    syntax [varlist] [, NOCompress NOStrl NOReport Quietly Detail VARSavings ///
                        LOWmem DRYrun MINlength(integer 0)]

    // Error if both nocompress and nostrl specified
    if "`nocompress'" != "" & "`nostrl'" != "" {
        display as error "options nocompress and nostrl are mutually exclusive"
        display as error "specifying both would result in no action"
        exit 198
    }

    if `minlength' < 0 {
        display as error "minlength() must be a non-negative integer"
        exit 198
    }

    // Check for empty dataset
    if _N == 0 {
        if "`quietly'" == "" {
            display as text "  No observations in dataset"
        }
        return scalar bytes_saved   = 0
        return scalar pct_saved     = 0
        return scalar bytes_initial = 0
        return scalar bytes_final   = 0
        return scalar bytes_strl    = 0
        return scalar k_converted   = 0
        return scalar k_reverted    = 0
        return local  vars_strl     ""
        return local  varlist       ""
        // Early clean exit bypasses the post-block cleanup zone, so restore
        // state here (preserve has not run yet, but guard it for safety)
        if `_preserved' capture restore
        set varabbrev `_user_varabbrev'
        exit
    }

    // Record initial memory (total data)
    quietly memory
    local oldmem = `r(data_data_u)' + `r(data_strl_u)'

    // Handle zero initial memory
    if `oldmem' == 0 {
        if "`quietly'" == "" {
            display as text "  No data to compress"
        }
        return scalar bytes_saved   = 0
        return scalar pct_saved     = 0
        return scalar bytes_initial = 0
        return scalar bytes_final   = 0
        return scalar bytes_strl    = 0
        return scalar k_converted   = 0
        return scalar k_reverted    = 0
        return local  vars_strl     ""
        return local  varlist       ""
        // Early clean exit bypasses the post-block cleanup zone, so restore
        // state here (preserve has not run yet, but guard it for safety)
        if `_preserved' capture restore
        set varabbrev `_user_varabbrev'
        exit
    }

    // dryrun: protect the data so storage types are restored on exit
    if "`dryrun'" != "" {
        preserve
        local _preserved 1
    }

    // String variables in scope (str# and strL)
    quietly ds `varlist', has(type string)
    local allstr `r(varlist)'

    // Variables we report on / process
    if "`nostrl'" != "" {
        local processed_vars "`allstr'"
    }
    else {
        quietly ds `varlist', has(type str#)
        local processed_vars "`r(varlist)'"
    }
    local nps : word count `processed_vars'

    // Classify str# candidates by minlength (stage-1 eligibility)
    local eligible ""
    local skipped_short ""
    if "`nostrl'" == "" {
        forvalues i = 1/`nps' {
            local v : word `i' of `processed_vars'
            local t : type `v'
            local w = real(substr("`t'", 4, .))
            if `w' >= `minlength' {
                local _elig_`i' 1
                local eligible `eligible' `v'
            }
            else {
                local _elig_`i' 0
                local skipped_short `skipped_short' `v'
            }
        }
    }

    // Capture per-variable before-state for the varsavings report
    if "`varsavings'" != "" & "`quietly'" == "" {
        forvalues i = 1/`nps' {
            local v : word `i' of `processed_vars'
            local _bt_`i' : type `v'
            _compress_tc_bytes `v'
            local _bb_`i' = r(bytes)
        }
    }

    // -------------------------------------------------------------------------
    // Stage 1: Convert str# to strL
    // -------------------------------------------------------------------------
    if "`nostrl'" == "" & "`eligible'" != "" {

        if "`quietly'" == "" {
            display as text "  Converting str# to strL:"
            if "`detail'" != "" {
                foreach v of local eligible {
                    local vtype : type `v'
                    display as text "    `v'" _col(30) as result "`vtype'"
                }
            }
            else {
                // Wrap long variable lists
                local linelen 0
                display as text "   " _continue
                foreach v of local eligible {
                    local vlen = length("`v'") + 1
                    if `linelen' + `vlen' > 70 & `linelen' > 0 {
                        display ""
                        display as text "   " _continue
                        local linelen 0
                    }
                    display as text " `v'" _continue
                    local linelen = `linelen' + `vlen'
                }
                display ""
            }
            if "`skipped_short'" != "" {
                display as text "    (skipped below minlength(`minlength'): `skipped_short')"
            }
        }

        if "`lowmem'" != "" {
            // Incremental: recast + compress one variable at a time so only
            // a single variable's strL heap is live at once (caps peak memory)
            forvalues i = 1/`nps' {
                if `_elig_`i'' == 0 continue
                local v : word `i' of `processed_vars'
                if "`varsavings'" != "" & "`quietly'" == "" {
                    quietly memory
                    local _mb = `r(data_data_u)' + `r(data_strl_u)'
                }
                capture noisily recast strL `v'
                if _rc {
                    display as error "  recast to strL failed for `v'"
                    exit _rc
                }
                if "`nocompress'" == "" {
                    quietly compress `v'
                }
                if "`varsavings'" != "" & "`quietly'" == "" {
                    quietly memory
                    local _ma = `r(data_data_u)' + `r(data_strl_u)'
                    local _delta_`i' = `_mb' - `_ma'
                }
            }
            if "`quietly'" == "" {
                display as text "    converted `: word count `eligible'' variable(s) incrementally (low-memory mode)"
            }
        }
        else {
            // Batch: recast all eligible variables at once
            capture noisily recast strL `eligible'
            if _rc {
                display as error "  recast to strL failed"
                exit _rc
            }

            quietly memory
            local midmem = `r(data_data_u)' + `r(data_strl_u)'

            if "`quietly'" == "" {
                if `midmem' <= `oldmem' {
                    local diff = `oldmem' - `midmem'
                    local pct  = 100 * (1 - `midmem' / `oldmem')
                    _compress_tc_human `diff'
                    display as text "    strL: " as result "`r(human)'" ///
                        as text " saved (" as result %5.1f `pct' as text "%)"
                }
                else {
                    local diff = `midmem' - `oldmem'
                    local pct  = 100 * (`midmem' / `oldmem' - 1)
                    _compress_tc_human `diff'
                    display as text "    strL: " as result "`r(human)'" ///
                        as text " added (+" as result %5.1f `pct' as text "%)" ///
                        as text " (compress will optimize)"
                }
            }
        }
    }
    else if "`nostrl'" == "" & "`quietly'" == "" {
        if "`skipped_short'" != "" {
            display as text "  All fixed-length strings below minlength(`minlength'); none converted"
        }
        else {
            display as text "  No fixed-length string variables to convert"
        }
    }

    // -------------------------------------------------------------------------
    // Stage 2: Run compress
    // -------------------------------------------------------------------------
    if "`nocompress'" == "" {
        if "`quietly'" != "" | "`noreport'" != "" {
            quietly compress `varlist'
        }
        else {
            compress `varlist'
        }
    }

    // Capture per-variable after-state for the varsavings report
    if "`varsavings'" != "" & "`quietly'" == "" {
        forvalues i = 1/`nps' {
            local v : word `i' of `processed_vars'
            local _at_`i' : type `v'
            _compress_tc_bytes `v'
            local _ab_`i' = r(bytes)
        }
    }

    // -------------------------------------------------------------------------
    // strL accounting (for richer returns)
    // -------------------------------------------------------------------------
    local vars_strl ""
    foreach v of local allstr {
        local ft : type `v'
        if "`ft'" == "strL" local vars_strl `vars_strl' `v'
    }
    local k_converted : word count `eligible'
    local k_reverted 0
    foreach v of local eligible {
        local ft : type `v'
        if "`ft'" != "strL" local ++k_reverted
    }

    // -------------------------------------------------------------------------
    // Per-variable savings report
    // -------------------------------------------------------------------------
    if "`varsavings'" != "" & "`quietly'" == "" & "`processed_vars'" != "" {
        display ""
        display as text "  Per-variable summary"
        display as text "  Variable" _col(24) "Type" _col(44) "Before" ///
            _col(57) "After" _col(70) "Saved"
        display as text "  {hline 76}"
        forvalues i = 1/`nps' {
            local v : word `i' of `processed_vars'
            local bb = `_bb_`i''
            local ab = `_ab_`i''
            local sv .
            capture local sv = `_delta_`i''
            if _rc local sv .
            if `sv' == . & `bb' != . & `ab' != . local sv = `bb' - `ab'

            local bbh "-"
            if `bb' != . {
                _compress_tc_human `bb'
                local bbh "`r(human)'"
            }
            local abh "-"
            if `ab' != . {
                _compress_tc_human `ab'
                local abh "`r(human)'"
            }
            local svh "-"
            if `sv' != . {
                _compress_tc_human `sv'
                local svh "`r(human)'"
            }

            local vshow = abbrev("`v'", 20)
            display as text "  `vshow'" ///
                _col(24) as result "`_bt_`i'' -> `_at_`i''" ///
                _col(44) "`bbh'" _col(57) "`abh'" _col(70) "`svh'"
        }
        display as text "  Note: strL bytes live in a shared heap and are shown as a dash;"
        display as text "        use lowmem for measured per-variable strL savings."
    }

    // -------------------------------------------------------------------------
    // Final memory and overall report
    // -------------------------------------------------------------------------
    quietly memory
    local newmem = `r(data_data_u)' + `r(data_strl_u)'
    local bytes_strl_final = `r(data_strl_u)'

    local bytes_saved = `oldmem' - `newmem'
    if `oldmem' > 0 {
        local pct_saved = 100 * (1 - `newmem' / `oldmem')
    }
    else {
        local pct_saved = 0
    }

    if "`quietly'" == "" {
        _compress_tc_human `bytes_saved'
        local h_saved "`r(human)'"
        _compress_tc_human `oldmem'
        local h_init "`r(human)'"
        _compress_tc_human `newmem'
        local h_final "`r(human)'"
        display ""
        if "`dryrun'" != "" {
            display as text "  Overall (dry run -- data not modified):"
        }
        else {
            display as text "  Overall:"
        }
        display as text "    Saved:   " as result "`h_saved'" ///
            as text "  (" as result %5.1f `pct_saved' as text "%)"
        display as text "    Initial: " as result "`h_init'"
        display as text "    Final:   " as result "`h_final'"
    }

    // -------------------------------------------------------------------------
    // Return results
    // -------------------------------------------------------------------------
    return scalar bytes_saved   = `bytes_saved'
    return scalar pct_saved     = `pct_saved'
    return scalar bytes_initial = `oldmem'
    return scalar bytes_final   = `newmem'
    return scalar bytes_strl    = `bytes_strl_final'
    return scalar k_converted   = `k_converted'
    return scalar k_reverted    = `k_reverted'
    local vars_strl = strtrim("`vars_strl'")
    return local  vars_strl     "`vars_strl'"
    return local  varlist       "`processed_vars'"

    }
    local rc = _rc
    if `_preserved' capture restore
    set varabbrev `_user_varabbrev'
    if `rc' exit `rc'
end
