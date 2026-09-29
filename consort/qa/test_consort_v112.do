* test_consort_v112.do — review regressions, 2026-09-29
* Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
local pkg_dir "`c(pwd)'/.."
capture ado uninstall consort
quietly net install consort, from("`pkg_dir'") replace
tempfile out_base
local out "`out_base'_consort_review"
capture mkdir "`out'"
do _qa_state.do
do _qa_hostile.do
capture program drop _consort_qa_text
program define _consort_qa_text, rclass
    args source
    mata: st_local("text", st_global(st_local("source")))
    clear
    set obs 10
    gen long id = _n
    consort clear, quiet
    consort init, initial(`"`macval(text)'"')
    mata: st_local("result", st_global("r(initial)"))
    consort exclude if id == 1, label(`"`macval(text)'"') remaining(`"`macval(text)'"')
    mata: st_local("actual", st_global("r(label)"))
    assert `"`macval(actual)'"' == `"`macval(text)'"'
    consort clear, quiet
    return local result `"`macval(result)'"'
end
local test_count 0
local pass_count 0
local fail_count 0

**## single evaluation
local ++test_count
capture noisily {
clear
set obs 100
gen long id = _n
set seed 12345
gen byte expected = runiform() < .5
quietly count if expected
local excluded = r(N)
set seed 12345
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if runiform() < .5, label("Random")
assert r(n_excluded) == `excluded'
assert r(n_remaining) == 100 - `excluded'
assert _N == 100 - `excluded'
assert expected == 0
local expected_n = _N
consort save, output("`out'/figure.png") csv("`out'/resolved.csv") xlsx("`out'/resolved.xlsx")
assert r(N_final) == `expected_n'
local mode "random `expected_n'"
    capture erase "`out'/receipt"
    gettoken kind args : mode
    shell python3 tools/check_review.py "`pkg_dir'" `kind' "`out'" `args' > "`out'/receipt" 2>&1
    tempname fh
    file open `fh' using "`out'/receipt", read text
    file read `fh' line
    file close `fh'
    assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## path identities
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n <= 2, label("Excluded")
shell python3 tools/check_review.py "`pkg_dir'" snapshot "`out'"
capture consort save, output("`out'/figure.png") csv("`out'/figure.png")
local rc = _rc
assert `rc' == 198
assert "${CONSORT_ACTIVE}" == "1"
assert _N == 8
shell python3 tools/check_review.py "`pkg_dir'" unchanged "`out'" > "`out'/receipt" 2>&1
tempname fh
file open `fh' using "`out'/receipt", read text
file read `fh' line
file close `fh'
assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## path identities
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n <= 2, label("Excluded")
shell python3 tools/check_review.py "`pkg_dir'" snapshot "`out'"
capture consort save, output("`out'/back.csv")
local rc = _rc
assert `rc' == 198
assert "${CONSORT_ACTIVE}" == "1"
assert _N == 8
shell python3 tools/check_review.py "`pkg_dir'" unchanged "`out'" > "`out'/receipt" 2>&1
tempname fh
file open `fh' using "`out'/receipt", read text
file read `fh' line
file close `fh'
assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## path identities
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n <= 2, label("Excluded")
shell python3 tools/check_review.py "`pkg_dir'" snapshot "`out'"
capture consort save, output("`out'/figure.png") csv("`out'/resolved.csv") xlsx("`out'/./resolved.csv")
local rc = _rc
assert `rc' == 198
assert "${CONSORT_ACTIVE}" == "1"
assert _N == 8
shell python3 tools/check_review.py "`pkg_dir'" unchanged "`out'" > "`out'/receipt" 2>&1
tempname fh
file open `fh' using "`out'/receipt", read text
file read `fh' line
file close `fh'
assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## path identities
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n <= 2, label("Excluded")
shell python3 tools/check_review.py "`pkg_dir'" snapshot "`out'"
capture consort save, output("`out'/figure.png") csv("`out'/back.csv")
local rc = _rc
assert `rc' == 198
assert "${CONSORT_ACTIVE}" == "1"
assert _N == 8
shell python3 tools/check_review.py "`pkg_dir'" unchanged "`out'" > "`out'/receipt" 2>&1
tempname fh
file open `fh' using "`out'/receipt", read text
file read `fh' line
file close `fh'
assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## path identities
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n <= 2, label("Excluded")
shell python3 tools/check_review.py "`pkg_dir'" snapshot "`out'"
capture consort save, output("`out'/figure.png") xlsx("`out'/back.csv")
local rc = _rc
assert `rc' == 198
assert "${CONSORT_ACTIVE}" == "1"
assert _N == 8
shell python3 tools/check_review.py "`pkg_dir'" unchanged "`out'" > "`out'/receipt" 2>&1
tempname fh
file open `fh' using "`out'/receipt", read text
file read `fh' line
file close `fh'
assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## path identities
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n <= 2, label("Excluded")
shell python3 tools/check_review.py "`pkg_dir'" snapshot "`out'"
capture consort save, output("`out'/./back.csv")
local rc = _rc
assert `rc' == 198
assert "${CONSORT_ACTIVE}" == "1"
assert _N == 8
shell python3 tools/check_review.py "`pkg_dir'" unchanged "`out'" > "`out'/receipt" 2>&1
tempname fh
file open `fh' using "`out'/receipt", read text
file read `fh' line
file close `fh'
assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## Relative and absolute destinations
local ++test_count
capture noisily {
    clear
    set obs 10
    gen long id = _n
    consort clear, quiet
    consort init, initial("Population") file("`out'/back.csv")
    consort exclude if id <= 2, label("Excluded")
    tempname fh
    file open `fh' using "__review_collision.png", write replace text
    file write `fh' "untouched sentinel" _n
    file close `fh'
    capture consort save, output("`c(pwd)'/__review_collision.png") csv("__review_collision.png")
    local rc = _rc
    assert `rc' == 198
    assert "${CONSORT_ACTIVE}" == "1"
    file open `fh' using "__review_collision.png", read text
    file read `fh' text
    file close `fh'
    assert "`text'" == "untouched sentinel"
    assert _N == 8
}
local rc = _rc
capture erase "__review_collision.png"
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
}
else local ++pass_count

**## quoted labels
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial(`"All "eligible" patients"') file("`out'/back.csv")
assert `"`r(initial)'"' == `"All "eligible" patients"'
consort exclude if _n <= 2, label(`"Not "eligible""') remaining(`"Adults,"eligible""')
assert `"`r(label)'"' == `"Not "eligible""'
assert _N == 8
consort save, output("`out'/figure.png") final(`"Final "eligible" patients"') csv("`out'/resolved.csv") xlsx("`out'/resolved.xlsx")
assert `"`r(final)'"' == `"Final "eligible" patients"'
local mode "quotes"
    capture erase "`out'/receipt"
    gettoken kind args : mode
    shell python3 tools/check_review.py "`pkg_dir'" `kind' "`out'" `args' > "`out'/receipt" 2>&1
    tempname fh
    file open `fh' using "`out'/receipt", read text
    file read `fh' line
    file close `fh'
    assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## CSV records
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n <= 2, label("Excluded")
shell python3 tools/check_review.py "`pkg_dir'" fixture "`out'"
consort save, output("`out'/figure.png") final(`"Analysis "quoted""') csv("`out'/resolved.csv") xlsx("`out'/resolved.xlsx")
local mode "multiline"
    capture erase "`out'/receipt"
    gettoken kind args : mode
    shell python3 tools/check_review.py "`pkg_dir'" `kind' "`out'" `args' > "`out'/receipt" 2>&1
    tempname fh
    file open `fh' using "`out'/receipt", read text
    file read `fh' line
    file close `fh'
    assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## executable spaces
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n <= 2, label("Excluded")
capture mkdir "`out'/python space"
shell ln -sf "$(command -v python3)" "`out'/python space/python3"
consort save, output("`out'/figure.png") python("`out'/python space/python3") csv("`out'/resolved.csv") xlsx("`out'/resolved.xlsx")
local mode "labels Final Cohort"
    capture erase "`out'/receipt"
    gettoken kind args : mode
    shell python3 tools/check_review.py "`pkg_dir'" `kind' "`out'" `args' > "`out'/receipt" 2>&1
    tempname fh
    file open `fh' using "`out'/receipt", read text
    file read `fh' line
    file close `fh'
    assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## renderer error
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n <= 2, label("Excluded")
set varabbrev on
set more on
capture noisily consort save, output("`out'/figure.png") python("/bin/false")
local rc = _rc
assert `rc' == 601
assert "${CONSORT_ACTIVE}" == "1"
assert c(varabbrev) == "on"
assert c(more) == "on"
set more off
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## label parity
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n == 1, label("First") remaining("  Milestone  ")
consort exclude if _n == 1, label("Second") remaining("")
consort save, output("`out'/figure.png") csv("`out'/resolved.csv") xlsx("`out'/resolved.xlsx")
local mode "labels Final Cohort"
    capture erase "`out'/receipt"
    gettoken kind args : mode
    shell python3 tools/check_review.py "`pkg_dir'" `kind' "`out'" `args' > "`out'/receipt" 2>&1
    tempname fh
    file open `fh' using "`out'/receipt", read text
    file read `fh' line
    file close `fh'
    assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## label parity
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n == 1, label("First") remaining("  Milestone  ")
consort exclude if _n == 1, label("Second") remaining("   ")
consort save, output("`out'/figure.png") csv("`out'/resolved.csv") xlsx("`out'/resolved.xlsx")
local mode "labels Final Cohort"
    capture erase "`out'/receipt"
    gettoken kind args : mode
    shell python3 tools/check_review.py "`pkg_dir'" `kind' "`out'" `args' > "`out'/receipt" 2>&1
    tempname fh
    file open `fh' using "`out'/receipt", read text
    file read `fh' line
    file close `fh'
    assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count

**## label parity
local ++test_count
capture noisily {
clear
set obs 10
consort clear, quiet
consort init, initial("Population") file("`out'/back.csv")
consort exclude if _n == 1, label("First") remaining("  Milestone  ")
consort exclude if _n == 1, label("Second") remaining("  Eligible  ")
consort save, output("`out'/figure.png") csv("`out'/resolved.csv") xlsx("`out'/resolved.xlsx")
local mode "labels Eligible"
    capture erase "`out'/receipt"
    gettoken kind args : mode
    shell python3 tools/check_review.py "`pkg_dir'" `kind' "`out'" `args' > "`out'/receipt" 2>&1
    tempname fh
    file open `fh' using "`out'/receipt", read text
    file read `fh' line
    file close `fh'
    assert strpos(`"`line'"', "ARTIFACT_CONTENT_PASS") == 1
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
    capture noisily type "`out'/receipt"
}
else local ++pass_count
**## caller state
local ++test_count
capture noisily {
sysuse auto, clear
regress price mpg
matrix caller_matrix = (1,2)
scalar caller_scalar = 42
consort clear, quiet
qa_state_snapshot, tag(init)
consort init, initial("Population") file("`out'/back.csv")
qa_state_compare, tag(init) allow(r global)
qa_state_snapshot, tag(exclude)
consort exclude if foreign == 1, label("Foreign")
* Exclude documents changing observations and CONSORT workflow globals.
qa_state_compare, tag(exclude) allow(r global data e)
qa_state_snapshot, tag(save)
consort save, output("`out'/state.png")
qa_state_compare, tag(save) allow(r global)
qa_state_snapshot, tag(clear)
consort clear, quiet
qa_state_compare, tag(clear) allow(r global)
qa_state_snapshot, tag(error)
capture consort save, output("`out'/state.png")
local err = _rc
assert `err' == 198
qa_state_compare, tag(error) allow(r)
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
}
else local ++pass_count

**## hostile literals
local ++test_count
capture noisily {
qa_hostile_strings, check(_consort_qa_text) result(r(result))
}
local rc = _rc
if `rc' {
    local ++fail_count
    display as error "FAIL `test_count' rc=`rc'"
}
else local ++pass_count

consort clear, quiet
display "RESULT: test_consort_v112 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' exit 1
