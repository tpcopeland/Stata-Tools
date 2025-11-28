*! compress_tc: Maximally compress string variables via strL conversion + compress
*! Version: 1.0.0
*! Date: 2025-11-28
*! Fork Author: Tim Copeland 
*! Forked from strcompress
*! Original Author: Luke Stein (lcdstein@babson.edu)
*!
*! Syntax:
*!   compress_tc [varlist] [, NOCompress NOStrl NOReport Quietly Detail]
*!
*! Description:
*!   Two-stage string compression: (1) convert str# to strL, (2) run compress.
*!   strL stores strings in a compressed heap, beneficial for long/repeated values.
*!   Subsequent compress reverts short unique strings to str# if more efficient.
*!
*! Options:
*!   nocompress  Skip compress step (strL conversion only)
*!   nostrl      Skip strL conversion (standard compress only)
*!   noreport    Suppress compress's per-variable output; show summary only
*!   quietly     Suppress all output
*!   detail      Show per-variable type information before conversion
*!
*! Returns:
*!   r(bytes_saved)    Bytes saved (string data only)
*!   r(pct_saved)      Percentage reduction
*!   r(bytes_initial)  Initial string data size
*!   r(bytes_final)    Final string data size
*!   r(varlist)        Variables processed
*!
*! Note: Memory calculations reflect total string data in dataset, not just
*!       specified varlist. This is a limitation of Stata's memory reporting.

program define compress_tc, rclass
    version 13.0
    
    syntax [varlist] [, NOCompress NOStrl NOStrL NOReport Quietly Detail]
    
    // Handle alternate spelling nostrl/nostrL
    if "`nostrl'" != "" | "`nostrL'" != "" {
        local nostrl "nostrl"
    }
    
    // Error if both nocompress and nostrl specified
    if "`nocompress'" != "" & "`nostrl'" != "" {
        display as error "options nocompress and nostrl are mutually exclusive"
        display as error "specifying both would result in no action"
        exit 198
    }
    
    // Check for empty dataset
    if _N == 0 {
        if "`quietly'" == "" {
            display as text "  No observations in dataset"
        }
        return scalar bytes_saved = 0
        return scalar pct_saved = 0
        return scalar bytes_initial = 0
        return scalar bytes_final = 0
        return local varlist ""
        exit
    }
    
    // Record initial memory (total string data)
    quietly memory
    local oldmem = `r(data_data_u)' + `r(data_strl_u)'
    
    // Handle zero initial memory
    if `oldmem' == 0 {
        if "`quietly'" == "" {
            display as text "  No string data to compress"
        }
        return scalar bytes_saved = 0
        return scalar pct_saved = 0
        return scalar bytes_initial = 0
        return scalar bytes_final = 0
        return local varlist ""
        exit
    }
    
    local midmem = `oldmem'
    local converted_vars ""
    
    // Stage 1: Convert str# to strL
    if "`nostrl'" == "" {
        quietly ds `varlist', has(type str#)
        local strvars `r(varlist)'
        
        if "`strvars'" != "" {
            local converted_vars "`strvars'"
            
            if "`quietly'" == "" {
                display as text "  Converting str# to strL:"
                if "`detail'" != "" {
                    foreach v of local strvars {
                        local vtype : type `v'
                        display as text "    `v'" _col(30) as result "`vtype'"
                    }
                }
                else {
                    // Wrap long variable lists
                    local linelen 0
                    display as text "   " _continue
                    foreach v of local strvars {
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
            }
            
            capture noisily quietly recast strL `strvars'
            if _rc {
                display as error "  recast to strL failed"
                exit _rc
            }
            
            quietly memory
            local midmem = `r(data_data_u)' + `r(data_strl_u)'
            
            if "`quietly'" == "" {
                local diff = `oldmem' - `midmem'
                if `midmem' <= `oldmem' {
                    local pct = 100 * (1 - `midmem' / `oldmem')
                    display as text "    strL: " ///
                        as result %12.0fc `diff' as text " bytes saved " ///
                        as result "(" %5.1f `pct' "%)"
                }
                else {
                    local pct = 100 * (`midmem' / `oldmem' - 1)
                    local diff = `midmem' - `oldmem'
                    display as text "    strL: " ///
                        as result %12.0fc `diff' as text " bytes added " ///
                        as result "(+" %5.1f `pct' "%)" ///
                        as text " (compress will optimize)"
                }
            }
        }
        else if "`quietly'" == "" {
            display as text "  No fixed-length string variables to convert"
        }
    }
    
    // Stage 2: Run compress
    if "`nocompress'" == "" {
        if "`quietly'" != "" | "`noreport'" != "" {
            quietly compress `varlist'
        }
        else {
            compress `varlist'
        }
    }
    
    // Final memory and report
    quietly memory
    local newmem = `r(data_data_u)' + `r(data_strl_u)'
    
    local bytes_saved = `oldmem' - `newmem'
    if `oldmem' > 0 {
        local pct_saved = 100 * (1 - `newmem' / `oldmem')
    }
    else {
        local pct_saved = 0
    }
    
    if "`quietly'" == "" {
        display ""
        display as text "  {hline 45}"
        display as text "  Overall: " ///
            as result %12.0fc `bytes_saved' as text " bytes saved " ///
            as result "(" %5.1f `pct_saved' "%)"
        display as text "  Initial: " as result %12.0fc `oldmem' as text " bytes"
        display as text "  Final:   " as result %12.0fc `newmem' as text " bytes"
    }
    
    // Return results
    return scalar bytes_saved = `bytes_saved'
    return scalar pct_saved = `pct_saved'
    return scalar bytes_initial = `oldmem'
    return scalar bytes_final = `newmem'
    return local varlist "`varlist'"

end
