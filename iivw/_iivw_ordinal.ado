*! _iivw_ordinal Version 1.0.0  2026/10/15
*! English ordinal for a percentile: 1st, 2nd, 3rd, 4th, 11th, 21st, 99th
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass
*! A non-integer percentile (2.5) takes "th".

program define _iivw_ordinal
    version 16.0
    args value name
    local ord "th"
    if `value' == floor(`value') {
        local m100 = mod(`value', 100)
        local m10 = mod(`value', 10)
        if `m100' < 11 | `m100' > 13 {
            if `m10' == 1 local ord "st"
            else if `m10' == 2 local ord "nd"
            else if `m10' == 3 local ord "rd"
        }
    }
    c_local `name' "`value'`ord'"
end
