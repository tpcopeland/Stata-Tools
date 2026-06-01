* test_refactor_saving_parser_adversarial.do -- saving() parser edge cases
* Package: qba

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}

_qba_qa_bootstrap, isolated
local orig_plus `"`r(orig_plus)'"'
local orig_personal `"`r(orig_personal)'"'
local plusdir `"`r(plusdir)'"'
local personaldir `"`r(personaldir)'"'

capture noisily {
    tempfile spaced
    local spaced_path "`spaced' with spaces.dta"
    _qba_parse_saving, saving("`spaced_path'", replace)
    assert `"`r(filename)'"' == `"`spaced_path'"'
    assert "`r(replace)'" == "replace"

    _qba_parse_saving, saving("`spaced_path'")
    assert `"`r(filename)'"' == `"`spaced_path'"'
    assert "`r(replace)'" == ""

    capture _qba_parse_saving, saving("`spaced_path'", append)
    assert _rc == 198

    tempfile comma
    local comma_path "`comma',literal.dta"
    capture _qba_parse_saving, saving("`comma_path'")
    assert _rc == 198
}
local rc = _rc

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `rc' exit `rc'
display as result "test_refactor_saving_parser_adversarial passed"
