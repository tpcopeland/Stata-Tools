*! _psdash_validate_path Version 1.4.0  2026/07/01
*! Validate a user-supplied file path (extension + shell metacharacters)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper

program define _psdash_validate_path
    version 16.0
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
end
