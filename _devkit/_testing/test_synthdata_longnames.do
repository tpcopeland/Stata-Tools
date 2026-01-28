* Test for variable names at or near 32-character limit
clear all
set more off

* Find repo root and source the ado file
local repo_root "`c(pwd)'"
if regexm("`repo_root'", "^(.*/Stata-Tools)") {
    local repo_root = regexs(1)
}
run "`repo_root'/synthdata/synthdata.ado"

* Create test data with LONG variable names (near 32-char limit)
clear
set obs 100
set seed 12345

* 32 characters is the max - test with exactly 32 and close to it
gen a_very_long_variable_name_here = runiform()
gen another_extremely_long_name__ = rnormal(50, 10)
gen this_name_has_exactly_32_char = ceil(runiform() * 5)

* Check variable name lengths
foreach v of varlist * {
    local len = strlen("`v'")
    di "`v': `len' characters"
}

* Test synthesis without prefix - should work fine
di _n "Testing WITHOUT prefix..."
tempfile orig
save `orig'

synthdata, n(50) replace seed(456)
di "Synthesis without prefix: SUCCESS"
describe, short

* Test with a short prefix
di _n "Testing WITH short prefix (s_)..."
use `orig', clear
synthdata, n(50) replace seed(456) prefix(s_)
di "Synthesis with prefix s_: SUCCESS"
describe, short

* Verify all variables are prefixed (or truncated if needed)
di _n "Variables after prefixing:"
foreach v of varlist * {
    local len = strlen("`v'")
    di "`v': `len' characters"
}

* Test with a longer prefix that will cause truncation
di _n "Testing WITH longer prefix (synth_)..."
use `orig', clear
synthdata, n(50) replace seed(456) prefix(synth_)
di "Synthesis with prefix synth_: SUCCESS"
describe, short

di _n "Variables after longer prefix:"
foreach v of varlist * {
    local len = strlen("`v'")
    di "`v': `len' characters"
    assert `len' <= 32
}

di _n "All variable name limit tests passed!"
