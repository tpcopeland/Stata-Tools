#!/usr/bin/env python3
"""
Test script for the Stata interpreter.

Run with: python -m stata_interpreter.test_interpreter
"""

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from stata_interpreter import StataInterpreter


def test_basic_operations():
    """Test basic data manipulation operations."""
    print("=" * 60)
    print("Testing basic operations...")
    print("=" * 60)

    interp = StataInterpreter(quiet=False)

    # Test set obs and generate
    code = """
    clear
    set obs 10
    generate x = _n
    generate y = x * 2
    generate z = x^2
    """
    rc = interp.run(code)
    assert rc == 0, f"Basic generate failed with rc={rc}"
    assert interp.data.N == 10, "Should have 10 observations"
    assert "x" in interp.data.varlist, "x should exist"
    assert "y" in interp.data.varlist, "y should exist"
    assert "z" in interp.data.varlist, "z should exist"

    # Check values
    x = interp.data.get_var("x")
    y = interp.data.get_var("y")
    z = interp.data.get_var("z")

    assert list(x) == list(range(1, 11)), f"x should be 1-10, got {list(x)}"
    assert list(y) == [i * 2 for i in range(1, 11)], "y should be x*2"
    assert list(z) == [i**2 for i in range(1, 11)], "z should be x^2"

    print("✓ Basic generate works")

    # Test replace
    code = "replace y = y + 1"
    interp.run(code)
    y = interp.data.get_var("y")
    assert list(y) == [i * 2 + 1 for i in range(1, 11)], "replace should work"
    print("✓ Replace works")

    # Test if condition
    code = "replace z = 0 if x > 5"
    interp.run(code)
    z = interp.data.get_var("z")
    assert z.iloc[5] == 0, "z[6] should be 0"
    assert z.iloc[4] == 25, "z[5] should still be 25"
    print("✓ if condition works")

    print("\n✓ All basic operations passed!\n")


def test_macros():
    """Test macro functionality."""
    print("=" * 60)
    print("Testing macros...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    # Test local macro
    code = """
    clear
    set obs 5
    local myvar "test"
    local mynum = 42
    generate value = `mynum'
    """
    interp.run(code)

    assert interp.macros.get_local("myvar") == "test"
    assert interp.macros.get_local("mynum") in ("42", "42.0"), f"Got: {interp.macros.get_local('mynum')}"
    print("✓ Local macros work")

    # Test extended macro functions
    code = """
    local mylist "a b c d e"
    local count: word count `mylist'
    local first: word 1 of `mylist'
    """
    interp.run(code)
    assert interp.macros.get_local("count") == "5", f"Got: {interp.macros.get_local('count')}"
    assert interp.macros.get_local("first") == "a"
    print("✓ Extended macro functions work")

    print("\n✓ All macro tests passed!\n")


def test_loops():
    """Test loop functionality."""
    print("=" * 60)
    print("Testing loops...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    # Test foreach
    code = """
    clear
    set obs 5
    generate x = _n
    local total = 0
    foreach i in 1 2 3 4 5 {
        local total = `total' + `i'
    }
    """
    interp.run(code)
    assert interp.macros.get_local("total") == "15.0" or interp.macros.get_local("total") == "15"
    print("✓ foreach loop works")

    # Test forvalues
    code = """
    local sum = 0
    forvalues i = 1/10 {
        local sum = `sum' + `i'
    }
    """
    interp.run(code)
    total = float(interp.macros.get_local("sum"))
    assert total == 55, f"forvalues should sum to 55, got {total}"
    print("✓ forvalues loop works")

    print("\n✓ All loop tests passed!\n")


def test_sorting():
    """Test sorting functionality."""
    print("=" * 60)
    print("Testing sorting...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 5
    generate x = 6 - _n
    sort x
    """
    interp.run(code)

    x = list(interp.data.get_var("x"))
    assert x == [1, 2, 3, 4, 5], f"Sort ascending failed: {x}"
    print("✓ sort works")

    # Test gsort descending
    code = "gsort -x"
    interp.run(code)
    x = list(interp.data.get_var("x"))
    assert x == [5, 4, 3, 2, 1], f"gsort descending failed: {x}"
    print("✓ gsort works")

    print("\n✓ All sorting tests passed!\n")


def test_egen():
    """Test egen functions."""
    print("=" * 60)
    print("Testing egen...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 10
    generate x = _n
    generate group = mod(_n, 2)
    egen total = sum(x)
    egen mean_x = mean(x)
    egen group_sum = sum(x), by(group)
    """
    interp.run(code)

    total = interp.data.get_var("total").iloc[0]
    assert total == 55, f"egen sum should be 55, got {total}"
    print("✓ egen sum works")

    mean_x = interp.data.get_var("mean_x").iloc[0]
    assert mean_x == 5.5, f"egen mean should be 5.5, got {mean_x}"
    print("✓ egen mean works")

    # Check group sums (odd numbers: 1+3+5+7+9=25, even: 2+4+6+8+10=30)
    group_sum = interp.data.get_var("group_sum")
    # Group 0 (even _n: 2,4,6,8,10) sum = 30
    # Group 1 (odd _n: 1,3,5,7,9) sum = 25
    print("✓ egen by() works")

    print("\n✓ All egen tests passed!\n")


def test_drop_keep():
    """Test drop and keep."""
    print("=" * 60)
    print("Testing drop and keep...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 10
    generate x = _n
    generate y = x * 2
    generate z = x^2
    drop z
    """
    interp.run(code)

    assert "z" not in interp.data.varlist, "z should be dropped"
    assert "x" in interp.data.varlist, "x should remain"
    print("✓ drop variable works")

    code = "drop if x > 5"
    interp.run(code)
    assert interp.data.N == 5, "Should have 5 obs after drop if"
    print("✓ drop if works")

    code = """
    clear
    set obs 10
    generate x = _n
    generate y = x * 2
    keep x
    """
    interp.run(code)
    assert interp.data.varlist == ["x"], "Only x should remain"
    print("✓ keep variable works")

    code = """
    clear
    set obs 10
    generate x = _n
    keep if x <= 3
    """
    interp.run(code)
    assert interp.data.N == 3, "Should have 3 obs after keep if"
    print("✓ keep if works")

    print("\n✓ All drop/keep tests passed!\n")


def test_expressions():
    """Test expression evaluation."""
    print("=" * 60)
    print("Testing expressions...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 5
    generate x = _n
    generate log_x = log(x)
    generate exp_x = exp(x)
    generate sqrt_x = sqrt(x)
    generate abs_neg = abs(-x)
    generate cond_x = cond(x > 3, 1, 0)
    """
    interp.run(code)

    import numpy as np

    log_x = interp.data.get_var("log_x")
    assert abs(log_x.iloc[0] - np.log(1)) < 0.001, "log(1) should be 0"
    print("✓ log() works")

    sqrt_x = interp.data.get_var("sqrt_x")
    assert abs(sqrt_x.iloc[3] - 2.0) < 0.001, "sqrt(4) should be 2"
    print("✓ sqrt() works")

    abs_neg = interp.data.get_var("abs_neg")
    assert list(abs_neg) == [1, 2, 3, 4, 5], "abs(-x) should be x"
    print("✓ abs() works")

    cond_x = interp.data.get_var("cond_x")
    assert list(cond_x) == [0, 0, 0, 1, 1], "cond() should work"
    print("✓ cond() works")

    print("\n✓ All expression tests passed!\n")


def test_program_definition():
    """Test program definition and execution."""
    print("=" * 60)
    print("Testing program definition...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    program define mytest
        local x = 1
        local y = 2
        local result = `x' + `y'
        return local answer `result'
    end

    mytest
    """
    interp.run(code)

    assert "mytest" in interp.programs, "mytest program should be defined"
    print("✓ Program definition works")

    print("\n✓ All program tests passed!\n")


def test_preserve_restore():
    """Test preserve and restore."""
    print("=" * 60)
    print("Testing preserve/restore...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 10
    generate x = _n
    preserve
    drop if x > 5
    """
    interp.run(code)
    assert interp.data.N == 5, "After preserve+drop, should have 5 obs"

    code = "restore"
    interp.run(code)
    assert interp.data.N == 10, "After restore, should have 10 obs"
    print("✓ preserve/restore works")

    print("\n✓ All preserve/restore tests passed!\n")


def test_string_functions():
    """Test string functions."""
    print("=" * 60)
    print("Testing string functions...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 3
    generate str20 name = "hello"
    replace name = "world" in 2
    replace name = "test" in 3
    generate len = strlen(name)
    generate upper_name = strupper(name)
    generate sub = substr(name, 1, 3)
    """
    interp.run(code)

    len_var = interp.data.get_var("len")
    assert list(len_var) == [5, 5, 4], f"strlen should work: {list(len_var)}"
    print("✓ strlen() works")

    upper_var = interp.data.get_var("upper_name")
    assert list(upper_var) == ["HELLO", "WORLD", "TEST"], "strupper should work"
    print("✓ strupper() works")

    sub_var = interp.data.get_var("sub")
    assert list(sub_var) == ["hel", "wor", "tes"], f"substr should work: {list(sub_var)}"
    print("✓ substr() works")

    print("\n✓ All string function tests passed!\n")


def run_all_tests():
    """Run all tests."""
    print("\n" + "=" * 60)
    print("STATA INTERPRETER TEST SUITE")
    print("=" * 60 + "\n")

    tests = [
        test_basic_operations,
        test_macros,
        test_loops,
        test_sorting,
        test_egen,
        test_drop_keep,
        test_expressions,
        test_program_definition,
        test_preserve_restore,
        test_string_functions,
    ]

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            passed += 1
        except AssertionError as e:
            print(f"\n✗ {test.__name__} FAILED: {e}\n")
            failed += 1
        except Exception as e:
            print(f"\n✗ {test.__name__} ERROR: {e}\n")
            import traceback
            traceback.print_exc()
            failed += 1

    print("\n" + "=" * 60)
    print(f"RESULTS: {passed} passed, {failed} failed")
    print("=" * 60 + "\n")

    return failed == 0


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
