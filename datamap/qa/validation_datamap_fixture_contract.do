*! validation_datamap_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
* 2026-11-10 (datamap 2.0.0): format(json) is removed.  The six "JSON metadata"
* tests of the labelled design are now "Markdown metadata" tests on the same
* fixtures and the same expected facts: the document is read through _qa_md.do
* (observations, variable rows, Missing cells, the x statistics text, the group
* level counts) and saving() carries the exact numbers (N, nvars, missing, mean).
version 16.0
clear all
set more off
capture log close _all
log using "validation_datamap_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
do _qa_fx_a7.do
do _qa_state.do
do _qa_md.do
local tests 0
local pass 0
local fail 0

* 2026-11-10 (2.0.0 Phase 3, F3): the Missing cell of the all-missing
* extended variable lists its codes ("40 (100.0%): . 14, .a 1, ..."); the
* pins read miss("40 (100.0%)") before.  Oracle: -count- per code on the
* fixture in memory (every run here is mincell(0), so every count prints).
capture program drop _fxc_extcell
program define _fxc_extcell, rclass
    quietly count
    local N = r(N)
    quietly count if missing(extended)
    assert r(N) == `N' & `N' > 0
    local cell "`N' (100.0%):"
    local sep ""
    foreach c in . .a .b .c .d .e .f .g .h .i .j .k .l .m .n .o .p .q .r .s .t .u .v .w .x .y .z {
        quietly count if extended == `c'
        if r(N) > 0 {
            local cell "`cell'`sep' `c' `r(N)'"
            local sep ","
        }
    }
    return local cell "`cell'"
end

**# Markdown metadata exact labelled friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    tempfile meta
    quietly datamap, output(`"`output'"') saving(`"`meta'"', replace) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    * Markdown + saving() oracle (was the JSON parse): 40 observations, ten variable rows,
    * all_missing and extended 40 missing, x complete with mean 20.5
    qa_md_contains using `"`output'"', needle("- Observations: 40") exact
    assert r(n)==1
    qa_md_contains using `"`output'"', needle("- Variables: 10") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==10
    qa_md_rows using `"`output'"', var(all_missing) cell("All missing") miss("40 (100.0%)")
    assert r(n)==1
    _fxc_extcell
    qa_md_rows using `"`output'"', var(extended) cell("All missing") miss(`"`r(cell)'"')
    assert r(n)==1
    qa_md_rows using `"`output'"', var(x) miss("0 (0.0%)") ///
        cell("N=40; mean=20.50; SD=11.69; median=20.50; IQR=10.50-30.50; range=1.00-40.00")
    assert r(n)==1
    preserve
    quietly use `"`meta'"', clear
    assert _N==10 & N==40 & nvars==10
    assert missing==40 if inlist(variable,"all_missing","extended")
    assert missing==0 & mean==20.5 if variable=="x"
    restore
    qa_md_levels using `"`output'"', var(group) expect(1:10 2:10 5:10 9:10)
    assert r(ok)==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Markdown metadata exact labelled friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Markdown metadata exact labelled friendly"
}

**# Missingness exact labelled friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==80
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled friendly"
}

**# QC exact labelled friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(dm_qc)
    quietly dataprobe, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled friendly"
}

**# Markdown metadata exact labelled label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    tempfile meta
    quietly datamap, output(`"`output'"') saving(`"`meta'"', replace) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    * Markdown + saving() oracle (was the JSON parse): 40 observations, ten variable rows,
    * all_missing and extended 40 missing, x complete with mean 20.5
    qa_md_contains using `"`output'"', needle("- Observations: 40") exact
    assert r(n)==1
    qa_md_contains using `"`output'"', needle("- Variables: 10") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==10
    qa_md_rows using `"`output'"', var(all_missing) cell("All missing") miss("40 (100.0%)")
    assert r(n)==1
    _fxc_extcell
    qa_md_rows using `"`output'"', var(extended) cell("All missing") miss(`"`r(cell)'"')
    assert r(n)==1
    qa_md_rows using `"`output'"', var(x) miss("0 (0.0%)") ///
        cell("N=40; mean=20.50; SD=11.69; median=20.50; IQR=10.50-30.50; range=1.00-40.00")
    assert r(n)==1
    preserve
    quietly use `"`meta'"', clear
    assert _N==10 & N==40 & nvars==10
    assert missing==40 if inlist(variable,"all_missing","extended")
    assert missing==0 & mean==20.5 if variable=="x"
    restore
    qa_md_levels using `"`output'"', var(group) expect(1:10 2:10 5:10 9:10)
    assert r(ok)==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Markdown metadata exact labelled label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Markdown metadata exact labelled label_gaps"
}

**# Missingness exact labelled label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==80
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled label_gaps"
}

**# QC exact labelled label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    qa_state_snapshot, tag(dm_qc)
    quietly dataprobe, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled label_gaps"
}

**# Markdown metadata exact labelled miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    tempfile meta
    quietly datamap, output(`"`output'"') saving(`"`meta'"', replace) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    * Markdown + saving() oracle (was the JSON parse): 40 observations, ten variable rows,
    * all_missing and extended 40 missing, x all missing
    qa_md_contains using `"`output'"', needle("- Observations: 40") exact
    assert r(n)==1
    qa_md_contains using `"`output'"', needle("- Variables: 10") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==10
    qa_md_rows using `"`output'"', var(all_missing) cell("All missing") miss("40 (100.0%)")
    assert r(n)==1
    _fxc_extcell
    qa_md_rows using `"`output'"', var(extended) cell("All missing") miss(`"`r(cell)'"')
    assert r(n)==1
    qa_md_rows using `"`output'"', var(x) cell("All missing") miss("40 (100.0%)")
    assert r(n)==1
    preserve
    quietly use `"`meta'"', clear
    assert _N==10 & N==40 & nvars==10
    assert missing==40 if inlist(variable,"all_missing","extended")
    assert missing==40 & mean==. if variable=="x"
    restore
    qa_md_levels using `"`output'"', var(group) expect(1:10 2:10 5:10 9:10)
    assert r(ok)==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Markdown metadata exact labelled miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Markdown metadata exact labelled miss_all_column"
}

**# Missingness exact labelled miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==120
    assert r(max_miss)==3 & r(mean_miss)==3
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled miss_all_column"
}

**# QC exact labelled miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    qa_state_snapshot, tag(dm_qc)
    quietly dataprobe, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled miss_all_column"
}

**# Markdown metadata exact labelled single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    tempfile meta
    quietly datamap, output(`"`output'"') saving(`"`meta'"', replace) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==1 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    * Markdown + saving() oracle (was the JSON parse): 1 observations, ten variable rows,
    * all_missing and extended 1 missing, x complete with mean 1
    qa_md_contains using `"`output'"', needle("- Observations: 1") exact
    assert r(n)==1
    qa_md_contains using `"`output'"', needle("- Variables: 10") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==10
    qa_md_rows using `"`output'"', var(all_missing) cell("All missing") miss("1 (100.0%)")
    assert r(n)==1
    _fxc_extcell
    qa_md_rows using `"`output'"', var(extended) cell("All missing") miss(`"`r(cell)'"')
    assert r(n)==1
    qa_md_rows using `"`output'"', var(x) miss("0 (0.0%)") ///
        cell("N=1; mean=1.00; SD=.; median=1.00; IQR=1.00-1.00; range=1.00-1.00")
    assert r(n)==1
    preserve
    quietly use `"`meta'"', clear
    assert _N==10 & N==1 & nvars==10
    assert missing==1 if inlist(variable,"all_missing","extended")
    assert missing==0 & mean==1 if variable=="x"
    restore
    qa_md_levels using `"`output'"', var(group) expect(1:1)
    assert r(ok)==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Markdown metadata exact labelled single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Markdown metadata exact labelled single_row"
}

**# Missingness exact labelled single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==1 & r(N_complete)==0 & r(N_incomplete)==1
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==2
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled single_row"
}

**# QC exact labelled single_row
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    qa_state_snapshot, tag(dm_qc)
    capture noisily dataprobe, gatesonly expectn(1) isid(id) binary(y) allowed(group 1 2 5 9)
    assert _rc==9
    assert r(N)==1 & r(n_failed)==1 & r(n_errors)==1
    assert r(n_checks)==4 & r(n_passed)==3
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled single_row"
}

**# Markdown metadata exact labelled boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    tempfile meta
    quietly datamap, output(`"`output'"') saving(`"`meta'"', replace) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    * Markdown + saving() oracle (was the JSON parse): 40 observations, ten variable rows,
    * all_missing and extended 40 missing, x complete with mean 20.5
    qa_md_contains using `"`output'"', needle("- Observations: 40") exact
    assert r(n)==1
    qa_md_contains using `"`output'"', needle("- Variables: 10") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==10
    qa_md_rows using `"`output'"', var(all_missing) cell("All missing") miss("40 (100.0%)")
    assert r(n)==1
    _fxc_extcell
    qa_md_rows using `"`output'"', var(extended) cell("All missing") miss(`"`r(cell)'"')
    assert r(n)==1
    qa_md_rows using `"`output'"', var(x) miss("0 (0.0%)") ///
        cell("N=40; mean=20.50; SD=11.69; median=20.50; IQR=10.50-30.50; range=1.00-40.00")
    assert r(n)==1
    preserve
    quietly use `"`meta'"', clear
    assert _N==10 & N==40 & nvars==10
    assert missing==40 if inlist(variable,"all_missing","extended")
    assert missing==0 & mean==20.5 if variable=="x"
    restore
    qa_md_levels using `"`output'"', var(group) expect(1:10 2:10 5:10 9:10)
    assert r(ok)==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Markdown metadata exact labelled boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Markdown metadata exact labelled boundary_values"
}

**# Missingness exact labelled boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==80
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled boundary_values"
}

**# QC exact labelled boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    qa_state_snapshot, tag(dm_qc)
    quietly dataprobe, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled boundary_values"
}

**# Markdown metadata exact labelled unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempfile output
    qa_state_snapshot, tag(dm_json)
    tempfile meta
    quietly datamap, output(`"`output'"') saving(`"`meta'"', replace) continuous(x) mincell(0)
    assert r(nfiles)==1 & r(nobs)==40 & r(nvars)==10
    qa_state_compare, tag(dm_json)
    * Markdown + saving() oracle (was the JSON parse): 40 observations, ten variable rows,
    * all_missing and extended 40 missing, x complete with mean 20.5
    qa_md_contains using `"`output'"', needle("- Observations: 40") exact
    assert r(n)==1
    qa_md_contains using `"`output'"', needle("- Variables: 10") exact
    assert r(n)==1
    qa_md_rows using `"`output'"'
    assert r(n)==10
    qa_md_rows using `"`output'"', var(all_missing) cell("All missing") miss("40 (100.0%)")
    assert r(n)==1
    _fxc_extcell
    qa_md_rows using `"`output'"', var(extended) cell("All missing") miss(`"`r(cell)'"')
    assert r(n)==1
    qa_md_rows using `"`output'"', var(x) miss("0 (0.0%)") ///
        cell("N=40; mean=20.50; SD=11.69; median=20.50; IQR=10.50-30.50; range=1.00-40.00")
    assert r(n)==1
    preserve
    quietly use `"`meta'"', clear
    assert _N==10 & N==40 & nvars==10
    assert missing==40 if inlist(variable,"all_missing","extended")
    assert missing==0 & mean==20.5 if variable=="x"
    restore
    qa_md_levels using `"`output'"', var(group) expect(1:10 2:10 5:10 9:10)
    assert r(ok)==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Markdown metadata exact labelled unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Markdown metadata exact labelled unsorted"
}

**# Missingness exact labelled unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    global S_2 "CALLER_KEEP"
    qa_state_snapshot, tag(dm_miss)
    quietly datamvp x extended all_missing, nodrop
    assert r(N)==40 & r(N_complete)==0 & r(N_incomplete)==40
    assert r(N_vars)==3 & r(N_patterns)==1
    assert r(N_mv_total)==80
    assert r(max_miss)==2 & r(mean_miss)==2
    qa_state_compare, tag(dm_miss)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Missingness exact labelled unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Missingness exact labelled unsorted"
}

**# QC exact labelled unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    qa_state_snapshot, tag(dm_qc)
    quietly dataprobe, gatesonly expectn(40) isid(id) binary(y) allowed(group 1 2 5 9)
    assert r(N)==40 & r(n_failed)==0 & r(n_errors)==0
    assert r(n_checks)==4 & r(n_passed)==4
    qa_state_compare, tag(dm_qc)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: QC exact labelled unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: QC exact labelled unsorted"
}

display "RESULT: validation_datamap_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
