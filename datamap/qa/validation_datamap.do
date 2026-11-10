clear all
set more off
version 16.0

* validation_datamap.do - Correctness validation for datamap package
* Generated: 2026-03-13
* Validates: variable classification, content correctness, return values,
*            output content verification, missing data handling, invariants
*
* 2026-11-10 (datamap 2.0.0): datadict, the text layout and format(json) are
* removed, so this suite was rewritten against the surfaces that remain: the
* Markdown document (read through _qa_md.do, Mata) and the saving() table.
* Every test id V1.1 ... V10 is kept.  What changed:
*   V1, V2, V10   classification is asserted on saving()'s class column (the
*                 text layout's "Classification:" line is gone) and on the
*                 Markdown row (Type column, level list or statistics cell)
*   V3.2          r(format) was removed: it must be UNSET
*   V3.3, V5, V7.2, V7.4, V8.4, V8.5, V8.7, V9.2   the datadict tests are
*                 ported to datamap's Markdown writer (datadict is removed)
*   V4.4          nostats: no mean/SD/percentile cell (the text layout's
*                 "Percentile" lines no longer exist)
*   V5.6          the Missing column is the default (the `missing` option is
*                 removed), asserted with the exact count and share
*   V6.1          the old test only confirmed that a file existed; it now
*                 asserts the exact missing count and share
*   V7.1, V7.2    determinism: the two documents are byte-identical (hash of
*                 the whole text), not just equal in line count
* The earlier assertions "the word id appears somewhere" and "50 appears
* somewhere" matched any substring and are replaced by row-level checks.

* ============================================================
* Setup
* ============================================================
local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local tmp_dir "`qa_dir'/data"
capture mkdir "`tmp_dir'"

* Uninstall any existing version
capture ado uninstall datamap

* Install from local directory
quietly net install datamap, from("`pkg_dir'") force
do "`qa_dir'/_qa_md.do"

* are two files line-for-line identical? r(same); r(n) the line count of the first.
* (Mata: a datamap line may end in a backtick, so no line is held in a macro)
capture program drop _vd_same
program define _vd_same, rclass
    version 16.0
    args f1 f2
    mata: st_numscalar("__vd_s", rows(cat(st_local("f1"))) == rows(cat(st_local("f2"))) & all(cat(st_local("f1")) :== cat(st_local("f2"))))
    mata: st_numscalar("__vd_n", rows(cat(st_local("f1"))))
    return scalar same = scalar(__vd_s)
    return scalar n = scalar(__vd_n)
    scalar drop __vd_s __vd_n
end

* class of one variable in a saving() table, as r(class); "" if absent or not unique
capture program drop _vd_class
program define _vd_class, rclass
    version 16.0
    args meta var
    preserve
    quietly use "`meta'", clear
    quietly count if variable == "`var'"
    local n = r(N)
    local cl ""
    if `n' == 1 {
        quietly levelsof class if variable == "`var'", local(cl) clean
    }
    restore
    return local class "`cl'"
    return scalar n = `n'
end

* ============================================================
* V1: Variable Classification - Known Types
* ============================================================
* Create dataset with exactly known variable types:
*   id       -> continuous (numeric, no labels, many unique values)
*   age      -> continuous (numeric, no labels)
*   sex      -> categorical (labeled 0/1)
*   bmi      -> continuous (numeric, no labels)
*   region   -> categorical (labeled 1-4)
*   entry_dt -> date (%td format)
*   name     -> string
clear
set seed 99999
set obs 50
gen double id = _n
gen double age = 25 + int(50*runiform())
gen byte sex = cond(runiform() > 0.5, 1, 0)
label define sexlbl 0 "Female" 1 "Male"
label values sex sexlbl
gen double bmi = 18 + 15*runiform()
gen byte region = 1 + int(4*runiform())
label define reglbl 1 "North" 2 "South" 3 "East" 4 "West"
label values region reglbl
gen double entry_dt = td(01jan2020) + int(365*runiform())
format entry_dt %td
gen str10 name = "P" + string(_n)
label data "Classification test dataset"
save "`tmp_dir'/val_classify.dta", replace


* V1.1: Continuous variables (age, bmi) classified correctly
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_class.md") saving("`tmp_dir'/_val_class_meta.dta", replace)
    foreach v in age bmi {
        _vd_class "`tmp_dir'/_val_class_meta.dta" `v'
        assert r(n) == 1 & "`r(class)'" == "continuous"
        * and the document shows statistics, not a level list
        qa_md_rows using "`tmp_dir'/_val_class.md", var(`v')
        assert r(n) == 1
        qa_md_contains using "`tmp_dir'/_val_class.md", needle("`=char(96)'`v'`=char(96)' |  | double | 0 (0.0%) | N=50; mean=")
        assert r(n) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: V1.1 - Continuous variables (age, bmi) classified correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.1 - Continuous variables (age, bmi) classified correctly (error `=_rc')"
    local ++fail_count
}

* V1.2: Categorical variables (sex, region) classified correctly
local ++test_count
capture noisily {
    foreach v in sex region {
        _vd_class "`tmp_dir'/_val_class_meta.dta" `v'
        assert r(n) == 1 & "`r(class)'" == "categorical"
    }
    * the labelled levels are listed with the counts the data give
    preserve
    quietly use "`tmp_dir'/val_classify.dta", clear
    quietly count if sex == 0
    local f0 = r(N)
    quietly count if sex == 1
    local f1 = r(N)
    restore
    local p0 = string(100 * `f0' / 50, "%4.1f")
    local p1 = string(100 * `f1' / 50, "%4.1f")
    qa_md_rows using "`tmp_dir'/_val_class.md", var(sex) cell("0 Female: `f0' (`p0'%)<br>1 Male: `f1' (`p1'%)")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V1.2 - Categorical variables (sex, region) classified correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.2 - Categorical variables (sex, region) classified correctly (error `=_rc')"
    local ++fail_count
}

* V1.3: Date variable (entry_dt) classified correctly
local ++test_count
capture noisily {
    _vd_class "`tmp_dir'/_val_class_meta.dta" entry_dt
    assert r(n) == 1 & "`r(class)'" == "date"
    qa_md_rows using "`tmp_dir'/_val_class.md", var(entry_dt)
    assert r(n) == 1
    * 2026-11-10 (2.0.0 Phase 3, U4): the Type column names the date family
    qa_md_contains using "`tmp_dir'/_val_class.md", needle("| double %td daily | 0 (0.0%) | N=50; range 20")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V1.3 - Date variable (entry_dt) classified correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.3 - Date variable (entry_dt) classified correctly (error `=_rc')"
    local ++fail_count
}

* V1.4: String variable (name) classified correctly
local ++test_count
capture noisily {
    _vd_class "`tmp_dir'/_val_class_meta.dta" name
    assert r(n) == 1 & "`r(class)'" == "string"
    qa_md_rows using "`tmp_dir'/_val_class.md", var(name) cell("N=50; 50 distinct; max length 3")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V1.4 - String variable (name) classified correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.4 - String variable (name) classified correctly (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V2: Categorical Detection by Cardinality
* ============================================================
* maxcat controls the threshold for categorical detection
* A variable with 3 unique values should be categorical at maxcat(5)
* but continuous at maxcat(2)
clear
set obs 30
gen grp3 = mod(_n - 1, 3) + 1
gen grp50 = _n
save "`tmp_dir'/val_cardinality.dta", replace


* V2.1: Variable with 3 unique values is categorical at default maxcat(25)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_cardinality") output("`tmp_dir'/_val_card.md") saving("`tmp_dir'/_val_card_meta.dta", replace)
    _vd_class "`tmp_dir'/_val_card_meta.dta" grp3
    assert r(n) == 1 & "`r(class)'" == "categorical"
    qa_md_rows using "`tmp_dir'/_val_card.md", var(grp3) cell("1: 10 (33.3%)<br>2: 10 (33.3%)<br>3: 10 (33.3%)")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V2.1 - Variable with 3 unique values is categorical at default maxcat(25)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.1 - Variable with 3 unique values is categorical at default maxcat(25) (error `=_rc')"
    local ++fail_count
}

* V2.2: Variable with 30 unique values is continuous at default maxcat(25)
local ++test_count
capture noisily {
    _vd_class "`tmp_dir'/_val_card_meta.dta" grp50
    assert r(n) == 1 & "`r(class)'" == "continuous"
    qa_md_rows using "`tmp_dir'/_val_card.md", var(grp50)
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_card.md", needle("`=char(96)'grp50`=char(96)' |  | float | 0 (0.0%) | N=30; mean=15.50;")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V2.2 - Variable with 30 unique values is continuous at default maxcat(25)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.2 - Variable with 30 unique values is continuous at default maxcat(25) (error `=_rc')"
    local ++fail_count
}

* V2.3: maxcat(2) makes 3-value variable continuous
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_cardinality") maxcat(2) ///
        output("`tmp_dir'/_val_card2.md") saving("`tmp_dir'/_val_card2_meta.dta", replace)
    _vd_class "`tmp_dir'/_val_card2_meta.dta" grp3
    assert r(n) == 1 & "`r(class)'" == "continuous"
    qa_md_contains using "`tmp_dir'/_val_card2.md", needle("`=char(96)'grp3`=char(96)' |  | float | 0 (0.0%) | N=30; mean and SD withheld (mincell; two or three values); median=2.00; IQR=1.00-3.00; range=1.00-3.00 |")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V2.3 - maxcat(2) makes 3-value variable continuous"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.3 - maxcat(2) makes 3-value variable continuous (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V3: Return Value Correctness
* ============================================================

* V3.1: r(nfiles) matches number of files processed
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_rv1.md")
    assert r(nfiles) == 1
    datamap, filelist("`tmp_dir'/val_classify" "`tmp_dir'/val_cardinality") ///
        output("`tmp_dir'/_val_rv2.md")
    assert r(nfiles) == 2
}
if _rc == 0 {
    display as result "  PASS: V3.1 - r(nfiles) matches number of files processed"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.1 - r(nfiles) matches number of files processed (error `=_rc')"
    local ++fail_count
}

* V3.2: r(format) is gone (removed with the text layout in 2.0.0); r(mode) says single
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_fmt.md")
    assert "`r(format)'" == ""
    assert "`r(mode)'" == "single"
    datamap, single("`tmp_dir'/val_classify") nostats output("`tmp_dir'/_val_fmt2.md")
    assert "`r(format)'" == ""
    assert "`r(mode)'" == "single"
}
if _rc == 0 {
    display as result "  PASS: V3.2 - r(format) is gone (removed with the text layout in 2.0.0); r(mode) says single"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.2 - r(format) is gone (removed with the text layout in 2.0.0); r(mode) says single (error `=_rc')"
    local ++fail_count
}

* V3.3: (was datadict) r(nfiles) correct for single and filelist, r(mode) filelist
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd_rv1.md")
    assert r(nfiles) == 1
    datamap, filelist("`tmp_dir'/val_classify" "`tmp_dir'/val_cardinality") ///
        output("`tmp_dir'/_val_dd_rv2.md")
    assert r(nfiles) == 2
    assert "`r(mode)'" == "filelist"
}
if _rc == 0 {
    display as result "  PASS: V3.3 - (was datadict) r(nfiles) correct for single and filelist, r(mode) filelist"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.3 - (was datadict) r(nfiles) correct for single and filelist, r(mode) filelist (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V4: Output Content Verification - datamap
* ============================================================

* V4.1: Output contains dataset label
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_content.md")
    qa_md_contains using "`tmp_dir'/_val_content.md", needle("- Label: Classification test dataset") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V4.1 - Output contains dataset label"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.1 - Output contains dataset label (error `=_rc')"
    local ++fail_count
}

* V4.2: Output contains one row per variable, in dataset order
local ++test_count
capture noisily {
    qa_md_rows using "`tmp_dir'/_val_content.md"
    assert r(n) == 7
    foreach v in id age sex bmi region entry_dt name {
        qa_md_rows using "`tmp_dir'/_val_content.md", var(`v')
        assert r(n) == 1
    }
    * order: the row lines appear in dataset order (the first row is id, the last name)
    mata: _vd_L = cat(st_local("tmp_dir") + "/_val_content.md"); _vd_R = select(_vd_L, substr(_vd_L, 1, 3) :== "| " + char(96)); ///
        st_numscalar("__vd_ok", substr(_vd_R[1], 1, 6) == "| " + char(96) + "id" + char(96) & substr(_vd_R[rows(_vd_R)], 1, 8) == "| " + char(96) + "name" + char(96) & rows(_vd_R) == 7)
    assert scalar(__vd_ok) == 1
    scalar drop __vd_ok
    capture mata: mata drop _vd_L _vd_R
}
if _rc == 0 {
    display as result "  PASS: V4.2 - Output contains one row per variable, in dataset order"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.2 - Output contains one row per variable, in dataset order (error `=_rc')"
    local ++fail_count
}

* V4.3: Output contains value labels for categorical vars
local ++test_count
capture noisily {
    qa_md_rows using "`tmp_dir'/_val_content.md", var(sex)
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_content.md", needle("0 Female: ")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_content.md", needle("1 Male: ")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_content.md", needle("1 North: ")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V4.3 - Output contains value labels for categorical vars"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.3 - Output contains value labels for categorical vars (error `=_rc')"
    local ++fail_count
}

* V4.4: nostats suppresses the statistics (mean, SD, percentiles, range)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") nostats ///
        output("`tmp_dir'/_val_nostats.md")
    * the default document carries them (control: the claim is not vacuous)
    qa_md_contains using "`tmp_dir'/_val_content.md", needle("mean=")
    assert !missing(r(n))
    assert r(n) >= 2
    * (a date variable keeps its span "range <start> to <end>", which is structure, so only the
    * statistic forms are tested)
    foreach t in "mean=" "SD=" "median=" "IQR=" "range=" {
        qa_md_contains using "`tmp_dir'/_val_nostats.md", needle("`t'")
        assert r(n) == 0
    }
    * the rows are still there with their N
    qa_md_rows using "`tmp_dir'/_val_nostats.md", var(age) cell("N=50")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V4.4 - nostats suppresses the statistics (mean, SD, percentiles, range)"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.4 - nostats suppresses the statistics (mean, SD, percentiles, range) (error `=_rc')"
    local ++fail_count
}

* V4.5: exclude removes variable detail from the output
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") exclude(id name) ///
        output("`tmp_dir'/_val_excl.md")
    qa_md_rows using "`tmp_dir'/_val_excl.md", var(id) cell("excluded (structure only)")
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_val_excl.md", var(name) cell("excluded (structure only)")
    assert r(n) == 1
    * no statistic, no value of the excluded variables; the others keep theirs
    qa_md_contains using "`tmp_dir'/_val_excl.md", needle("max length")
    assert r(n) == 0
    qa_md_contains using "`tmp_dir'/_val_excl.md", needle("N=50; mean=")
    assert r(n) == 2
    qa_md_contains using "`tmp_dir'/_val_excl.md", needle("2 excluded")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V4.5 - exclude removes variable detail from the output"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.5 - exclude removes variable detail from the output (error `=_rc')"
    local ++fail_count
}

* V4.6: Observation count (N=50) and variable count appear in the dataset block
local ++test_count
capture noisily {
    qa_md_contains using "`tmp_dir'/_val_content.md", needle("- Observations: 50") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_content.md", needle("- Variables: 7") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V4.6 - Observation count (N=50) and variable count appear in the dataset block"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.6 - Observation count (N=50) and variable count appear in the dataset block (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V5: Output Content Verification - (was datadict) document options
* ============================================================

* V5.1: Markdown output contains title
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd.md") ///
        title("Validation Test Title")
    qa_md_contains using "`tmp_dir'/_val_dd.md", needle("# Validation Test Title") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V5.1 - Markdown output contains title"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.1 - Markdown output contains title (error `=_rc')"
    local ++fail_count
}

* V5.2: Markdown output contains subtitle
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd2.md") ///
        title("Test") subtitle("Validation Subtitle Text")
    qa_md_contains using "`tmp_dir'/_val_dd2.md", needle("Validation Subtitle Text") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V5.2 - Markdown output contains subtitle"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.2 - Markdown output contains subtitle (error `=_rc')"
    local ++fail_count
}

* V5.3: Markdown contains version string
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd3.md") ///
        version("3.14")
    qa_md_contains using "`tmp_dir'/_val_dd3.md", needle("**Document Version:** 3.14") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V5.3 - Markdown contains version string"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.3 - Markdown contains version string (error `=_rc')"
    local ++fail_count
}

* V5.4: Markdown contains author
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd4.md") ///
        author("Validation Test Author")
    qa_md_contains using "`tmp_dir'/_val_dd4.md", needle("**Author:** Validation Test Author") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V5.4 - Markdown contains author"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.4 - Markdown contains author (error `=_rc')"
    local ++fail_count
}

* V5.5: Markdown contains all variable names in the table
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd5.md")
    qa_md_rows using "`tmp_dir'/_val_dd5.md"
    assert r(n) == 7
    foreach v in id age sex bmi region entry_dt name {
        qa_md_rows using "`tmp_dir'/_val_dd5.md", var(`v')
        assert r(n) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: V5.5 - Markdown contains all variable names in the table"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.5 - Markdown contains all variable names in the table (error `=_rc')"
    local ++fail_count
}

* V5.6: Markdown shows the Missing column (default) with exact counts
local ++test_count
capture noisily {
    * Create dataset with known missingness
    clear
    set obs 20
    gen x = _n
    replace x = . in 1/5
    gen y = _n * 2
    save "`tmp_dir'/val_miss_known.dta", replace
    datamap, single("`tmp_dir'/val_miss_known") output("`tmp_dir'/_val_dd_miss.md")
    qa_md_contains using "`tmp_dir'/_val_dd_miss.md", needle("| Variable | Label | Type | Missing | Values/Statistics |") exact
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_val_dd_miss.md", var(x) miss("5 (25.0%)")
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_val_dd_miss.md", var(y) miss("0 (0.0%)")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V5.6 - Markdown shows the Missing column (default) with exact counts"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.6 - Markdown shows the Missing column (default) with exact counts (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V6: Missing Data Handling
* ============================================================

* V6.1: Missing data analysis reports the exact missing count and share
local ++test_count
capture noisily {
    * Dataset val_miss_known has 5 missing in x (25%), 0 in y
    datamap, single("`tmp_dir'/val_miss_known") missing(detail) ///
        output("`tmp_dir'/_val_miss_det.md") saving("`tmp_dir'/_val_miss_meta.dta", replace)
    confirm file "`tmp_dir'/_val_miss_det.md"
    * the Missingness section (missing(detail)) names x and counts 5 of 20; y is not listed
    qa_md_contains using "`tmp_dir'/_val_miss_det.md", needle("### Missingness") exact
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_val_miss_det.md", var(x) miss("5 (25.0%)")
    assert r(n) == 1
    * saving(): missing, missing_pct and N are the data's (independent count)
    preserve
    quietly use "`tmp_dir'/val_miss_known.dta", clear
    quietly count if missing(x)
    local truth = r(N)
    restore
    preserve
    quietly use "`tmp_dir'/_val_miss_meta.dta", clear
    assert `truth' == 5
    assert missing == `truth' & N == 20 & abs(missing_pct - 25) < 1e-9 if variable == "x"
    assert missing == 0 if variable == "y"
    restore
    * the section's own wording for the 25% variable
    qa_md_contains using "`tmp_dir'/_val_miss_det.md", needle("- Complete rows: 15 (75.0%)") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_miss_det.md", needle("- Variables more than 10% missing: 1") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_miss_det.md", needle("- Variables more than 50% missing: 0") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V6.1 - Missing data analysis reports the exact missing count and share"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.1 - Missing data analysis reports the exact missing count and share (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V7: Invariant Tests
* ============================================================

* V7.1: datamap output is deterministic (same input -> same output, byte for byte)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_det1.md")
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_det2.md")
    _vd_same "`tmp_dir'/_val_det1.md" "`tmp_dir'/_val_det2.md"
    assert r(same) == 1
    assert !missing(r(n))
    assert r(n) > 0
}
if _rc == 0 {
    display as result "  PASS: V7.1 - datamap output is deterministic (same input -> same output, byte for byte)"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.1 - datamap output is deterministic (same input -> same output, byte for byte) (error `=_rc')"
    local ++fail_count
}

* V7.2: (was datadict) document-option output is deterministic
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_ddet1.md") title("T") docdate("2026-01-01")
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_ddet2.md") title("T") docdate("2026-01-01")
    _vd_same "`tmp_dir'/_val_ddet1.md" "`tmp_dir'/_val_ddet2.md"
    assert r(same) == 1
    assert !missing(r(n))
    assert r(n) > 0
}
if _rc == 0 {
    display as result "  PASS: V7.2 - (was datadict) document-option output is deterministic"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.2 - (was datadict) document-option output is deterministic (error `=_rc')"
    local ++fail_count
}

* V7.3: datamap preserves user data (datasignature)
local ++test_count
capture noisily {
    sysuse auto, clear
    datasignature
    local sig_before "`r(datasignature)'"
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_pres.md")
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: V7.3 - datamap preserves user data (datasignature)"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.3 - datamap preserves user data (datasignature) (error `=_rc')"
    local ++fail_count
}

* V7.4: (was datadict) datamap with document options preserves user data (datasignature)
local ++test_count
capture noisily {
    sysuse auto, clear
    datasignature
    local sig_before "`r(datasignature)'"
    datamap, single("`tmp_dir'/val_classify") output("`tmp_dir'/_val_dd_pres.md") title("T") notes("n")
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: V7.4 - (was datadict) datamap with document options preserves user data (datasignature)"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.4 - (was datadict) datamap with document options preserves user data (datasignature) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V8: Error Condition Validation
* ============================================================

* V8.1: datamap with no input returns rc 198
local ++test_count
capture noisily {
    clear
    capture datamap, output("`tmp_dir'/_err.md")
    assert _rc == 198
    capture confirm file "`tmp_dir'/_err.md"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: V8.1 - datamap with no input returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.1 - datamap with no input returns rc 198 (error `=_rc')"
    local ++fail_count
}

* V8.2: datamap with dual inputs returns rc 198
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/val_classify") directory("`tmp_dir'")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.2 - datamap with dual inputs returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.2 - datamap with dual inputs returns rc 198 (error `=_rc')"
    local ++fail_count
}

* V8.3: datamap with missing file returns rc 601
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/totally_nonexistent_file")
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: V8.3 - datamap with missing file returns rc 601"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.3 - datamap with missing file returns rc 601 (error `=_rc')"
    local ++fail_count
}

* V8.4: (was datadict) datamap with document options and no input returns rc 198
local ++test_count
capture noisily {
    clear
    capture datamap, output("`tmp_dir'/_err2.md") title("T")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.4 - (was datadict) datamap with document options and no input returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.4 - (was datadict) datamap with document options and no input returns rc 198 (error `=_rc')"
    local ++fail_count
}

* V8.5: (was datadict) datamap with dual inputs and a varlist returns rc 198
local ++test_count
capture noisily {
    capture datamap age, single("`tmp_dir'/val_classify") directory("`tmp_dir'")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.5 - (was datadict) datamap with dual inputs and a varlist returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.5 - (was datadict) datamap with dual inputs and a varlist returns rc 198 (error `=_rc')"
    local ++fail_count
}

* V8.6: datamap with maxfreq(0) returns rc 198
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/val_classify") maxfreq(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.6 - datamap with maxfreq(0) returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.6 - datamap with maxfreq(0) returns rc 198 (error `=_rc')"
    local ++fail_count
}

* V8.7: (was datadict) datamap with maxcat(0) returns rc 198
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/val_classify") maxcat(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8.7 - (was datadict) datamap with maxcat(0) returns rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.7 - (was datadict) datamap with maxcat(0) returns rc 198 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V9: Multi-file Validation
* ============================================================

* V9.1: filelist processes correct number of datasets
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/val_classify" "`tmp_dir'/val_cardinality") ///
        output("`tmp_dir'/_val_multi.md")
    * one numbered dataset section per file, in the order given
    qa_md_contains using "`tmp_dir'/_val_multi.md", needle("## 1. val_classify") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_multi.md", needle("## 2. val_cardinality") exact
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_val_multi.md"
    assert r(n) == 9
}
if _rc == 0 {
    display as result "  PASS: V9.1 - filelist processes correct number of datasets"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.1 - filelist processes correct number of datasets (error `=_rc')"
    local ++fail_count
}

* V9.2: (was datadict) filelist with a title lists both datasets in the table of contents
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/val_classify" "`tmp_dir'/val_cardinality") ///
        output("`tmp_dir'/_val_dd_multi.md") title("Two files")
    qa_md_contains using "`tmp_dir'/_val_dd_multi.md", needle("1. [val_classify](#1-val_classify)") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_dd_multi.md", needle("2. [val_cardinality](#2-val_cardinality)") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V9.2 - (was datadict) filelist with a title lists both datasets in the table of contents"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.2 - (was datadict) filelist with a title lists both datasets in the table of contents (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V10: Value Label Bug Fix Verification
* ============================================================

* Regression test: value label word-indexing bug
* Variables with value labels must be classified as categorical,
* variables without must follow cardinality rules

* V10.1: Value-labelled variables are categorical, unlabelled ones follow cardinality
local ++test_count
capture noisily {
    clear
    set seed 99999
    set obs 100
    gen double id = _n
    gen double age = 20 + int(60*runiform())
    gen byte sex = cond(runiform() > 0.5, 1, 0)
    label define sexlbl2 0 "Female" 1 "Male"
    label values sex sexlbl2
    gen double bmi = 18 + 15*runiform()
    gen byte region = 1 + int(4*runiform())
    label define reglbl2 1 "North" 2 "South" 3 "East" 4 "West"
    label values region reglbl2
    save "`tmp_dir'/val_labelbug.dta", replace
    datamap, single("`tmp_dir'/val_labelbug") output("`tmp_dir'/_val_labelbug.md") saving("`tmp_dir'/_val_labelbug_meta.dta", replace)
    foreach pair in age:continuous sex:categorical bmi:continuous region:categorical {
        local v = substr("`pair'", 1, strpos("`pair'", ":") - 1)
        local c = substr("`pair'", strpos("`pair'", ":") + 1, .)
        _vd_class "`tmp_dir'/_val_labelbug_meta.dta" `v'
        assert r(n) == 1 & "`r(class)'" == "`c'"
    }
    * the labels reach the right variable (the word-indexing bug attached them to the wrong one)
    qa_md_contains using "`tmp_dir'/_val_labelbug.md", needle("0 Female: ")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_labelbug.md", needle("4 West: ")
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_val_labelbug.md", var(age)
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_val_labelbug.md", needle("Female")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: V10.1 - Value-labelled variables are categorical, unlabelled ones follow cardinality"
    local ++pass_count
}
else {
    display as error "  FAIL: V10.1 - Value-labelled variables are categorical, unlabelled ones follow cardinality (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup
* ============================================================
* Remove all validation output files
foreach pat in "_val_*.txt" "_val_*.md" "_val_*_meta.dta" {
    local files : dir "`tmp_dir'" files "`pat'"
    foreach f of local files {
        capture erase "`tmp_dir'/`f'"
    }
}

* Remove validation datasets
capture erase "`tmp_dir'/val_classify.dta"
capture erase "`tmp_dir'/val_cardinality.dta"
capture erase "`tmp_dir'/val_miss_known.dta"
capture erase "`tmp_dir'/val_labelbug.dta"

* ============================================================
* Summary
* ============================================================
display as text ""
if `fail_count' > 0 {
    display as error "validation_datamap: `fail_count' of `test_count' FAILED"
}
else {
    display as result "validation_datamap: all `test_count' passed"
}
display "RESULT: validation_datamap tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
