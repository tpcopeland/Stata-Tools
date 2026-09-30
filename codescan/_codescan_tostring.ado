*! _codescan_tostring Version 4.2.5  2026/09/30
*! Exact numeric-to-string conversion for the tostring option
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
DESCRIPTION:
    Writes each value of a numeric code variable into a new string variable
    as the SHORTEST decimal text that reads back as the stored number:
    integers in full (never scientific notation), and a non-integer at the
    fewest significant digits that round-trip at the variable's storage
    precision -- so a float holding 250.01 becomes "250.01", not the
    "250.0099945" that tostring's default %12.0g produces.

    Stata's `tostring, force' was used before. Its %12.0g default is lossy:
    1234567890123 became "1.23457e+12" and float 401.9 became "401.8999939",
    and `force' suppressed the only warning, so a numeric code silently failed
    to match its pattern at rc=0.

    Missing values (. and .a-.z) become "". A value whose text cannot be
    verified to read back exactly is an error, never a guess.
*/

program define _codescan_tostring
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax varname(numeric) , GENerate(name)

    local _v `varlist'
    local _vt : type `_v'
    confirm new variable `generate'
    quietly gen str1 `generate' = ""

    * Integers: every digit, no exponent. %24.0f is exact for any integer a
    * double holds below 1e21; larger magnitudes fall through to %g below.
    quietly replace `generate' = string(`_v', "%24.0f") ///
        if !missing(`_v') & `_v' == round(`_v') & abs(`_v') < 1e21

    * Non-integers: fewest significant digits whose text reads back as the
    * stored value at its own storage precision (float values compare after
    * float()). 17 digits round-trip every double, so the loop always ends.
    forvalues _p = 1/17 {
        * `&' does not short-circuit, so every pass re-evaluates string() on
        * every row; stop as soon as nothing is left to convert (at once for
        * integer codes, the common case).
        quietly count if `generate' == "" & !missing(`_v')
        if r(N) == 0 continue, break
        if "`_vt'" == "float" {
            quietly replace `generate' = string(`_v', "%24.`_p'g") ///
                if `generate' == "" & !missing(`_v') & ///
                float(real(string(`_v', "%24.`_p'g"))) == `_v'
        }
        else {
            quietly replace `generate' = string(`_v', "%24.`_p'g") ///
                if `generate' == "" & !missing(`_v') & ///
                real(string(`_v', "%24.`_p'g")) == `_v'
        }
    }

    * Every nonmissing value must now carry text that reads back exactly.
    if "`_vt'" == "float" {
        quietly count if !missing(`_v') & ///
            (`generate' == "" | float(real(`generate')) != `_v')
    }
    else {
        quietly count if !missing(`_v') & ///
            (`generate' == "" | real(`generate') != `_v')
    }
    if r(N) > 0 {
        display as error "tostring: `r(N)' value(s) of `_v' cannot be written as text exactly"
        display as error "  convert `_v' to a string variable yourself before scanning"
        exit 198
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
