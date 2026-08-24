*! Static source contract for literal user-path examples in massdesas.sthlp.
*! The paths are placeholders and must never be executed as fixtures.
* qa-hygiene: no-package-code
*! Date: 2026-08-23

clear all
set varabbrev off
version 14.0

local qa_dir = regexr("`c(pwd)'", "/+$", "")
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local help_file "`pkg_dir'/massdesas.sthlp"
local test_count = 0
local pass_count = 0
local fail_count = 0

capture confirm file "`help_file'"
if _rc {
    display as error "missing help file: `help_file'"
    display "RESULT: test_massdesas_documentation_exact tests=1 pass=0 fail=1 skip=0"
    exit 601
}

local saw_directory = 0
local saw_backup = 0
local saw_dataset = 0
tempname help_handle
file open `help_handle' using "`help_file'", read text
file read `help_handle' line
while r(eof) == 0 {
    if strpos(`"`line'"', "C:/Data/SAS_Files") > 0 {
        local saw_directory = 1
    }
    if strpos(`"`line'"', "C:/Data/SAS_Files_Backup") > 0 {
        local saw_backup = 1
    }
    if strpos(`"`line'"', "C:/Data/SAS_Files_Backup/dataset1.dta") > 0 {
        local saw_dataset = 1
    }
    file read `help_handle' line
}
file close `help_handle'

foreach contract in directory backup dataset {
    local ++test_count
    if `saw_`contract'' == 1 local ++pass_count
    else local ++fail_count
}

display "RESULT: test_massdesas_documentation_exact tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
