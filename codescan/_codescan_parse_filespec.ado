*! _codescan_parse_filespec Version 4.0.1  2026/07/18
*! Parse a "filename [, replace]" option spec and enforce overwrite authorization
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    Shared parser for every codescan option that names an output file:
    export(), save(), saving(), and codescan_describe's save().

    Splits the spec into a filename and an optional `replace' suboption,
    validates the path, and — with checkexists — refuses to proceed when the
    target already exists and replace was not given.

    The existence check runs at option-validation time, before any data
    mutation or file handle, so a refusal leaves both the caller's data and the
    existing file untouched.

RETURNS:
    r(filename) - the unquoted filename
    r(replace)  - 1 if the replace suboption was given, 0 otherwise
*/

program define _codescan_parse_filespec, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    * SPEC is deliberately plain `string', not `asis'. The caller's option must
    * be `asis' so the ", replace" suboption survives parsing, which means the
    * value reaching here can itself contain quotes. An `asis' option preserves
    * the compound quotes that wrap the value on this hop, delivering
    *     `""/tmp/x.csv", replace"'
    * — a double wrapper that both defeats the quote strip below (leaving a
    * char(34) that _codescan_validate_path rejects as unsafe) and hides the
    * suboption comma inside an apparent quoted region. Plain `string' consumes
    * exactly the transport layer and hands over the caller's own text.
    syntax , SPEC(string) CONTEXT(string) [CHECKEXISTS]

    local _replace = 0

    * Split the filename from its suboptions at the first comma outside quotes,
    * so a quoted filename may itself contain a comma.
    local _len = length(`"`spec'"')
    local _comma_pos = 0
    local _in_quotes = 0
    forvalues _c = 1/`_len' {
        if substr(`"`spec'"', `_c', 1) == char(34) {
            local _in_quotes = !`_in_quotes'
        }
        else if substr(`"`spec'"', `_c', 1) == char(44) & !`_in_quotes' {
            local _comma_pos = `_c'
            continue, break
        }
    }
    if `_comma_pos' > 0 {
        local _fn  = strtrim(substr(`"`spec'"', 1, `_comma_pos' - 1))
        local _sub = strtrim(substr(`"`spec'"', `_comma_pos' + 1, .))
        if lower(`"`_sub'"') == "replace" {
            local _replace = 1
        }
        else if `"`_sub'"' != "" {
            display as error `"`context': unknown suboption `_sub' (only replace is allowed)"'
            exit 198
        }
    }
    else {
        local _fn = strtrim(`"`spec'"')
    }

    * Strip surrounding quotes: "path" (regular) and `"path"' (compound, which a
    * `string asis' option can deliver).
    if substr(`"`_fn'"', 1, 1) == char(96) {
        local _fn = substr(`"`_fn'"', 3, length(`"`_fn'"') - 4)
    }
    else if substr(`"`_fn'"', 1, 1) == `"""' {
        local _fn = substr(`"`_fn'"', 2, length(`"`_fn'"') - 2)
    }
    if `"`_fn'"' == "" {
        display as error "`context' requires a filename"
        exit 198
    }

    _codescan_validate_path, path(`"`_fn'"') context(`context')

    * Overwrite authorization. Without this, a typo or a repeated run silently
    * destroys an existing dictionary, audit table, or workbook.
    if "`checkexists'" != "" & !`_replace' {
        capture confirm file `"`_fn'"'
        if _rc == 0 {
            display as error `"`context': file already exists: `_fn'"'
            display as error `"  specify `context'(`_fn', replace) to overwrite it"'
            exit 602
        }
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local filename `"`_fn'"'
    return scalar replace = `_replace'
end
