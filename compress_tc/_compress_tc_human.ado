*! _compress_tc_human Version 1.1.0  2026/06/19
*! Format a byte count as a human-readable size string (B / KB / MB / GB)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (helper for compress_tc)

program define _compress_tc_human, rclass
    version 16.0
    args bytes

    * Missing or empty -> n/a (defensive; callers normally guard)
    if "`bytes'" == "" {
        return local human "n/a"
        return local unit ""
        exit
    }
    if `bytes' == . {
        return local human "n/a"
        return local unit ""
        exit
    }

    * Unit selection on magnitude; bytes < 1 KB stay in bytes (integer),
    * KB to 1 decimal, MB and GB to 2 decimals. Stop at GB.
    local a = abs(`bytes')
    if `a' < 1024 {
        local num : display %15.0fc `bytes'
        local unit "B"
    }
    else if `a' < 1048576 {
        local val = `bytes' / 1024
        local num : display %15.1fc `val'
        local unit "KB"
    }
    else if `a' < 1073741824 {
        local val = `bytes' / 1048576
        local num : display %18.2fc `val'
        local unit "MB"
    }
    else {
        local val = `bytes' / 1073741824
        local num : display %21.2fc `val'
        local unit "GB"
    }

    local num = trim("`num'")
    return local human "`num' `unit'"
    return local unit "`unit'"
end
