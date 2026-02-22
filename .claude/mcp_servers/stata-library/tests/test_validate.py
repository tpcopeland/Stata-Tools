"""Tests for validate.py — static analysis patterns for Stata .ado code."""

import sys
from pathlib import Path

# Add tools directory to path
TOOLS_DIR = Path(__file__).parent.parent / "tools"
sys.path.insert(0, str(TOOLS_DIR))

from validate import validate_ado_code, detect_patterns, get_pattern_info, list_patterns


def test_empty_code():
    """Empty code should return no issues."""
    result = validate_ado_code("")
    assert result["summary"]["total"] == 0
    assert result["clean"] is True


def test_missing_version():
    """Program without version statement."""
    code = """program define mytest, rclass
    set varabbrev off
    syntax varlist
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "missing_version" in ids


def test_has_version():
    """Program with version statement should not flag."""
    code = """program define mytest, rclass
    version 16.0
    set varabbrev off
    syntax varlist
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "missing_version" not in ids


def test_missing_varabbrev():
    """Program without set varabbrev off."""
    code = """program define mytest, rclass
    version 16.0
    syntax varlist
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "missing_varabbrev" in ids


def test_missing_marksample():
    """Syntax has [if] [in] but no marksample."""
    code = """program define mytest, rclass
    version 16.0
    set varabbrev off
    syntax varlist [if] [in]
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "missing_marksample" in ids


def test_has_marksample():
    """Program with marksample should not flag."""
    code = """program define mytest, rclass
    version 16.0
    set varabbrev off
    syntax varlist [if] [in]
    marksample touse
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "missing_marksample" not in ids


def test_long_macro_name():
    """Macro name exceeding 31 characters."""
    code = """program define mytest, rclass
    version 16.0
    local this_is_a_very_long_macro_name_that_will_be_truncated = 1
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "long_macro_name" in ids


def test_short_macro_name():
    """Normal length macro name should not flag."""
    code = """program define mytest
    version 16.0
    local short_name = 1
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "long_macro_name" not in ids


def test_float_precision():
    """gen without double keyword."""
    code = """program define mytest
    version 16.0
    gen result = x + y
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "float_precision" in ids


def test_gen_double_ok():
    """gen double should not flag."""
    code = """program define mytest
    version 16.0
    gen double result = x + y
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "float_precision" not in ids


def test_gen_byte_ok():
    """gen byte should not flag float_precision."""
    code = """program define mytest
    version 16.0
    gen byte flag = 1
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "float_precision" not in ids


def test_bysort_function():
    """Function in bysort sort specification."""
    code = """bysort id (abs(diff)): keep if _n == 1"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "bysort_abs" in ids


def test_string_multiply():
    """String multiplication pattern."""
    code = '''display "=" * 60'''
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "string_multiply" in ids


def test_cls_batch():
    """cls command in batch mode."""
    code = """cls"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "cls_batch" in ids


def test_nogen_merge():
    """nogenerate merge then referencing _merge."""
    code = """merge 1:1 id using data, nogenerate
keep if _merge == 3"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "nogen_merge" in ids


def test_global_in_program():
    """Global macro inside program define."""
    code = """program define mytest
    version 16.0
    global myvar "hello"
end"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "global_in_program" in ids


def test_hardcoded_path():
    """Hardcoded file path."""
    code = '''use "/home/user/data/mydata.dta"'''
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "hardcoded_path" in ids


def test_capture_no_rc():
    """capture without _rc check."""
    code = """capture confirm file "data.dta"
display "moving on" """
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "capture_no_rc" in ids


def test_capture_with_rc():
    """capture followed by _rc check should not flag."""
    code = """capture confirm file "data.dta"
if _rc != 0 {
    display as error "not found"
}"""
    issues = detect_patterns(code)
    ids = [i["pattern"] for i in issues]
    assert "capture_no_rc" not in ids


def test_validate_ado_code_structure():
    """Test validate_ado_code returns proper structure."""
    code = """program define mytest
    syntax varlist [if] [in]
end"""
    result = validate_ado_code(code)
    assert "issues" in result
    assert "summary" in result
    assert "clean" in result
    assert isinstance(result["issues"], list)
    assert isinstance(result["summary"]["errors"], int)
    assert isinstance(result["summary"]["warnings"], int)


def test_get_pattern_info():
    """Test getting info about a specific pattern."""
    info = get_pattern_info("missing_version")
    assert info is not None
    assert info["id"] == "missing_version"
    assert "description" in info


def test_get_pattern_info_not_found():
    """Test getting info about a nonexistent pattern."""
    info = get_pattern_info("nonexistent_pattern")
    assert info is None


def test_list_patterns():
    """Test listing all patterns."""
    patterns = list_patterns()
    assert len(patterns) > 0
    for p in patterns:
        assert "id" in p
        assert "severity" in p


def test_list_patterns_filtered():
    """Test listing patterns by category."""
    patterns = list_patterns(category="structure")
    assert len(patterns) > 0
    for p in patterns:
        assert p["category"] == "structure"


def test_clean_program():
    """A well-written program should have no errors."""
    code = """program define mytest, rclass
    version 16.0
    set varabbrev off

    syntax varlist [if] [in] [, by(varlist)]

    marksample touse
    quietly count if `touse'
    if r(N) == 0 error 2000
    local n = r(N)

    return scalar N = `n'
end"""
    result = validate_ado_code(code)
    assert result["clean"] is True
    assert result["summary"]["errors"] == 0


if __name__ == "__main__":
    test_empty_code()
    test_missing_version()
    test_has_version()
    test_missing_varabbrev()
    test_missing_marksample()
    test_has_marksample()
    test_long_macro_name()
    test_short_macro_name()
    test_float_precision()
    test_gen_double_ok()
    test_gen_byte_ok()
    test_bysort_function()
    test_string_multiply()
    test_cls_batch()
    test_nogen_merge()
    test_global_in_program()
    test_hardcoded_path()
    test_capture_no_rc()
    test_capture_with_rc()
    test_validate_ado_code_structure()
    test_get_pattern_info()
    test_get_pattern_info_not_found()
    test_list_patterns()
    test_list_patterns_filtered()
    test_clean_program()
    print("All validate tests passed!")
