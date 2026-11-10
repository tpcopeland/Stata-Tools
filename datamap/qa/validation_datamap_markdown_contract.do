*! validation_datamap_markdown_contract.do -- canonical metadata and actual Markdown content
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Ported 2026-11-10 (datamap 2.0.0, Phase 2) from
* validation_datadict_fixture_contract.do: datadict is removed, so the same six
* A7 labelled fixtures (friendly, unsorted, label_gaps, single_row,
* miss_all_column, boundary_values) go through `datamap` and keep every
* assertion's intent: the saving() table pins the numeric truth, the Markdown
* must carry the matching rendered summary (an all-missing variable reads
* "All missing", never a zero mean), and the caller's state is restored.
* What changed with the port: r(nvars_total)/r(nobs_total) are r(nvars)/r(nobs);
* `stats` is gone (a continuous() variable always prints its statistics);
* the Missing cell is a count, so an all-missing variable reads
* "<N> (100.0%)" in Missing and "All missing" in Values/Statistics; the row
* is "| <name> | <label> | <storage type> | <missing> | <values> |"; the
* expected mean text is derived from the fixture's truth, not typed.
version 16
clear all
set more off
capture log close _all
log using "validation_datamap_markdown_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
do _qa_fx_a7.do
do _qa_state.do
do _qa_md.do
local bt = char(96)
local tests 0
local pass 0
local fail 0

**# Markdown exact friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datamap, output("`md'") saving("`metadata'", replace) continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars)==10 & r(nobs)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double |")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("| `bt'all_missing`bt' |  | double | `N' (100.0%) | All missing |") exact
    assert r(found) == 1
    local mtxt = strtrim(string(`xm', "%9.2f"))
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double | 0 (0.0%) | N=`N'; mean=`mtxt';")
    assert r(found) == 1
    if `N' == 40 {
        qa_md_contains using "`md'", needle("mean=20.50; SD=11.69;")
        assert r(found) == 1
    }
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: friendly"
}

**# Markdown exact unsorted
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datamap, output("`md'") saving("`metadata'", replace) continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars)==10 & r(nobs)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double |")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("| `bt'all_missing`bt' |  | double | `N' (100.0%) | All missing |") exact
    assert r(found) == 1
    local mtxt = strtrim(string(`xm', "%9.2f"))
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double | 0 (0.0%) | N=`N'; mean=`mtxt';")
    assert r(found) == 1
    if `N' == 40 {
        qa_md_contains using "`md'", needle("mean=20.50; SD=11.69;")
        assert r(found) == 1
    }
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: unsorted"
}

**# Markdown exact label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datamap, output("`md'") saving("`metadata'", replace) continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars)==10 & r(nobs)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double |")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("| `bt'all_missing`bt' |  | double | `N' (100.0%) | All missing |") exact
    assert r(found) == 1
    local mtxt = strtrim(string(`xm', "%9.2f"))
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double | 0 (0.0%) | N=`N'; mean=`mtxt';")
    assert r(found) == 1
    if `N' == 40 {
        qa_md_contains using "`md'", needle("mean=20.50; SD=11.69;")
        assert r(found) == 1
    }
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: label_gaps"
}

**# Markdown exact single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datamap, output("`md'") saving("`metadata'", replace) continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars)==10 & r(nobs)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double |")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("| `bt'all_missing`bt' |  | double | `N' (100.0%) | All missing |") exact
    assert r(found) == 1
    local mtxt = strtrim(string(`xm', "%9.2f"))
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double | 0 (0.0%) | N=`N'; mean=`mtxt';")
    assert r(found) == 1
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: single_row"
}

**# Markdown exact miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datamap, output("`md'") saving("`metadata'", replace) continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars)==10 & r(nobs)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double |")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("| `bt'all_missing`bt' |  | double | `N' (100.0%) | All missing |") exact
    assert r(found) == 1
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double | `N' (100.0%) | All missing |") exact
    assert r(found) == 1
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: miss_all_column"
}

**# Markdown exact boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datamap, output("`md'") saving("`metadata'", replace) continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars)==10 & r(nobs)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double |")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("| `bt'all_missing`bt' |  | double | `N' (100.0%) | All missing |") exact
    assert r(found) == 1
    local mtxt = strtrim(string(`xm', "%9.2f"))
    qa_md_contains using "`md'", needle("| `bt'x`bt' | Exact sequence 1–40 | double | 0 (0.0%) | N=`N'; mean=`mtxt';")
    assert r(found) == 1
    if `N' == 40 {
        qa_md_contains using "`md'", needle("mean=20.50; SD=11.69;")
        assert r(found) == 1
    }
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: boundary_values"
}

display "RESULT: validation_datamap_markdown_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
