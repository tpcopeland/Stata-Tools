*! _compress_tc_bytes Version 1.1.0  2026/06/19
*! Return a variable's fixed in-memory storage size (storage width x _N).
*! Returns missing for strL, whose bytes live in the shared heap and cannot
*! be attributed to a single variable from Stata's dataset-wide -memory-.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (helper for compress_tc)

program define _compress_tc_bytes, rclass
    version 16.0
    args vname

    local t : type `vname'
    local w .
    if substr("`t'", 1, 3) == "str" {
        if "`t'" == "strL"  local w .
        else                local w = real(substr("`t'", 4, .))
    }
    else if "`t'" == "byte"   local w 1
    else if "`t'" == "int"    local w 2
    else if "`t'" == "long"   local w 4
    else if "`t'" == "float"  local w 4
    else if "`t'" == "double" local w 8

    if `w' == .  return scalar bytes = .
    else         return scalar bytes = `w' * _N
end
