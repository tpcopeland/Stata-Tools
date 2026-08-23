* Public error contracts for spaghetti incompatible options.
version 16.0
clear all
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall spaghetti
quietly net install spaghetti, from("`pkg_dir'") replace
local tests = 0
local pass = 0
local fail = 0
foreach options in "by(group) colorby(color)" "colorby(color) highlight(id==1)" {
    local ++tests
    capture noisily {
        clear
        set obs 4
        generate byte id = ceil(_n / 2)
        generate byte time = mod(_n - 1, 2)
        generate byte outcome = _n
        generate byte group = id
        generate byte color = time + 1
        capture noisily spaghetti outcome, id(id) time(time) `options'
        local call_rc = _rc
        assert `call_rc' == 198
        assert _N == 4
    }
    if _rc == 0 local ++pass
    else local ++fail
}
display "RESULT: test_spaghetti_errors tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
