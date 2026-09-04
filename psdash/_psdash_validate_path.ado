*! _psdash_validate_path Version 1.7.0  2026/09/03
*! Validate a user-supplied file path (extension + shell metacharacters)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass
*! Internal helper

program define _psdash_validate_path, nclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , PATH(string) [OPTion(string) EXTension(string)]

    if "`option'" == "" local option "file"

    * Reject shell metacharacters and quote characters that could be
    * exploited when a path reaches a file handle or post-export shell open.
    if regexm(`"`path'"', "[;&|><\$\`]") | strpos(`"`path'"', `"""') {
        display as error "`option'() path contains invalid characters"
        exit 198
    }

    * Enforce extension when requested (e.g. .xlsx)
    if "`extension'" != "" {
        if !strmatch(lower(`"`path'"'), "*." + lower("`extension'")) {
            display as error "`option'() filename must have .`extension' extension"
            exit 198
        }
    }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' == 0 return clear
    if `rc' exit `rc'
end
