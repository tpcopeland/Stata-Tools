*! test_network_smoke.do  1.0.0  2026/07/13
*! Optional network lane: pinned authoritative CCI source checksum

version 16.0
clear all
set more off
capture log close _all

tempfile source hash_file
local url "https://raw.githubusercontent.com/bjoroeKI/Charlson-comorbidity-index-revisited/0f2b6058fa551deb6d4b68116a21551f13ef99bc/Charlson_STATA"
capture noisily copy "`url'" "`source'", replace
local copy_ok = (_rc == 0)
local hash_ok = 0
if `copy_ok' {
    shell /usr/bin/sha256sum "`source'" > "`hash_file'"
    tempname handle
    file open `handle' using "`hash_file'", read text
    file read `handle' hash_line
    file close `handle'
    local observed : word 1 of `hash_line'
    local hash_ok = ("`observed'" == ///
        "ed865ef10f2d0f29235091ec6ec1e921b2db39b17cf9e37624f2b75f84868acd")
}
local pass = `copy_ok' + `hash_ok'
local fail = 2 - `pass'
display "RESULT: test_network_smoke tests=2 pass=`pass' fail=`fail'"
if `fail' > 0 exit 9
