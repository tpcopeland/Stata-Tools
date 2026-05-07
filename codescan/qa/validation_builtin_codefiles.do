* validation_builtin_codefiles.do - Known-answer validation for bundled codefile basenames

clear all
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

**# Tests

**## Charlson basename must match shipped CSV for divergent edge codes
local ++test_count
capture noisily {
    capture confirm file "charlson_icd10_example.csv"
    assert _rc == 601

    clear
    input long pid str10 dx1
    1 "C97"
    2 "I139"
    3 "I851"
    4 "B20"
    end

    codescan dx1, codefile(charlson_icd10_example.csv) id(pid) collapse ///
        score(charlson)
    tempfile basename
    keep pid cancer renal liver_severe hiv _score
    rename (cancer renal liver_severe hiv _score) ///
        (b_cancer b_renal b_liver_severe b_hiv b_score)
    quietly save `basename'

    clear
    input long pid str10 dx1
    1 "C97"
    2 "I139"
    3 "I851"
    4 "B20"
    end

    codescan dx1, codefile("`pkg_dir'/charlson_icd10_example.csv") ///
        id(pid) collapse score(charlson)
    merge 1:1 pid using `basename', nogenerate

    assert cancer == b_cancer
    assert renal == b_renal
    assert liver_severe == b_liver_severe
    assert hiv == b_hiv
    assert _score == b_score

    assert cancer == 1 if pid == 1
    assert _score == 2 if pid == 1
    assert renal == 0 if pid == 2
    assert _score == 0 if pid == 2
    assert liver_severe == 0 if pid == 3
    assert _score == 0 if pid == 3
    assert hiv == 1 if pid == 4
    assert _score == 6 if pid == 4
}
if _rc == 0 {
    display as result "  PASS: Charlson basename uses shipped CSV definitions"
    local ++pass_count
}
else {
    display as error "  FAIL: Charlson basename parity (error `=_rc')"
    local ++fail_count
}

**## Elixhauser basename must match shipped CSV for divergent edge codes
local ++test_count
capture noisily {
    capture confirm file "elixhauser_icd10_example.csv"
    assert _rc == 601

    clear
    input long pid str10 dx1
    1 "K25"
    2 "N00"
    3 "C97"
    4 "F39"
    5 "R64"
    6 "F412"
    end

    codescan dx1, codefile(elixhauser_icd10_example.csv) id(pid) collapse ///
        score(elixhauser)
    tempfile basename
    keep pid pud renal solid_tumor depression weight_loss _score
    rename (pud renal solid_tumor depression weight_loss _score) ///
        (b_pud b_renal b_solid_tumor b_depression b_weight_loss b_score)
    quietly save `basename'

    clear
    input long pid str10 dx1
    1 "K25"
    2 "N00"
    3 "C97"
    4 "F39"
    5 "R64"
    6 "F412"
    end

    codescan dx1, codefile("`pkg_dir'/elixhauser_icd10_example.csv") ///
        id(pid) collapse score(elixhauser)
    merge 1:1 pid using `basename', nogenerate

    assert pud == b_pud
    assert renal == b_renal
    assert solid_tumor == b_solid_tumor
    assert depression == b_depression
    assert weight_loss == b_weight_loss
    assert _score == b_score

    assert pud == 1 if pid == 1
    assert _score == 0 if pid == 1
    assert renal == 0 if pid == 2
    assert _score == 0 if pid == 2
    assert solid_tumor == 0 if pid == 3
    assert _score == 0 if pid == 3
    assert depression == 1 if pid == 4
    assert _score == -3 if pid == 4
    assert weight_loss == 0 if pid == 5
    assert _score == 0 if pid == 5
    assert depression == 0 if pid == 6
    assert _score == 0 if pid == 6
}
if _rc == 0 {
    display as result "  PASS: Elixhauser basename uses shipped CSV definitions"
    local ++pass_count
}
else {
    display as error "  FAIL: Elixhauser basename parity (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "RESULT: validation_builtin_codefiles tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
display as result "ALL TESTS PASSED"
