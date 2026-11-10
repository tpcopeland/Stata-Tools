*! _dataprobe_safesave Version 2.0.0  2026/11/10
*! dataprobe saving() under safe: the written rows carry the printed masks
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// 2.0.0 (U2).  frame() is a copy of the 27 saving() columns
// (_datamap_post_metadata_rows, plain) about to be written; the profiled
// data are the current frame.  Under safe the copy is masked as the console
// is under maskrare with mask(m), so the file says no more than the log:
//   excluded rows    missing, missing_pct, unique, mean, sd, p25, p50, p75,
//                    min and max are .s (exclude() withholds contents)
//   date rows        (class date, or a %t or %d display format): mean, sd,
//                    p25, p50, p75, min and max are .s (no date is printed)
//   min, max         .s on every row (maskrare never prints an extreme)
//   missing          .s with missing_pct when it, or the rows N less it, is
//                    1 to m-1 (_dataprobe_mshare)
//   unique           .s when N or the nonmissing N less it is 1 to m-1 (the
//                    console's unique rule)
//   mean, sd, p25, p50, p75   .s unless the console would print it
//                    (_dataprobe_qshow: m observations at or below and at or
//                    above it; sd and the mean with m nonmissing)
// N is kept: the header prints it.  Text columns are unchanged.
program define _dataprobe_safesave, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, FRame(name) MASK(integer)
        local m = `mask'
        local src = c(frame)
        frame `frame': local R = _N
        tempname val
        forvalues r = 1/`R' {
            frame `frame' {
                local v = variable[`r']
                local cl = class[`r']
                local fm = display_format[`r']
                local nN = N[`r']
                local nm = missing[`r']
                local nu = unique[`r']
                local uc = unique_capped[`r']
            }
            local ex = ("`cl'" == "excluded")
            local dt = ("`cl'" == "date" | regexm("`fm'", "^%-?(t|d)"))
            local stats "mean sd p25 p50 p75"
            local wipe "min max"
            if `ex' | `dt' local wipe "`wipe' `stats'"
            if `ex' local wipe "`wipe' missing missing_pct unique"
            if !`ex' & !missing(`nm') {
                _dataprobe_mshare `nm' `nN' `m'
                if r(masked) local wipe "`wipe' missing missing_pct"
            }
            if !`ex' & !missing(`nu') & `uc' != 1 & `m' > 0 {
                local _nmz = cond(missing(`nm'), 0, `nm')
                local d1 = `nN' - `nu'
                local d2 = `nN' - `_nmz' - `nu'
                if (`d1' >= 1 & `d1' < `m') | (`d2' >= 1 & `d2' < `m') local wipe "`wipe' unique"
            }
            if !`ex' & !`dt' {
                capture confirm numeric variable `v', exact
                if !_rc {
                    foreach st of local stats {
                        frame `frame': scalar `val' = `st'[`r']
                        if missing(scalar(`val')) continue
                        _dataprobe_qshow `v', value(`val') mask(`m') stat(`st')
                        if !r(shown) local wipe "`wipe' `st'"
                    }
                }
            }
            local wipe : list uniq wipe
            frame `frame' {
                // a statistic that is already missing (text) stays as it is
                foreach c of local wipe {
                    quietly replace `c' = .s in `r' if !missing(`c')
                }
            }
        }
        capture scalar drop `val'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
