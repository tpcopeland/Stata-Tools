* run_all_validations.do
*
* Compatibility entry point. New automation should call run_all.do directly.

version 16.0

local mode = strtrim("`0'")
if "`mode'" == "" {
    do "`c(pwd)'/run_all.do"
}
else {
    do "`c(pwd)'/run_all.do" `mode'
}
