#!/usr/bin/env python3
"""
Test the Stata interpreter with a sample .ado program.
"""

from stata_interpreter import StataInterpreter


def test_simple_ado_program():
    """Test a simple user-defined program."""
    print("=" * 60)
    print("Testing simple .ado program definition...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    # Define a simple program that calculates stats
    code = """
    * Define a simple stats program
    program define mystats, rclass
        version 16.0
        syntax varlist(numeric)

        foreach v of varlist `varlist' {
            quietly summarize `v'
            return scalar mean_`v' = r(mean)
        }
    end

    * Create test data
    clear
    set obs 100
    generate x = _n
    generate y = _n * 2
    generate z = _n^2

    * Run the program
    mystats x y z
    """
    rc = interp.run(code)

    # Check results
    assert "mystats" in interp.programs, "mystats program should be defined"
    assert interp.data.N == 100, "Should have 100 observations"
    print("✓ Simple .ado program definition works")


def test_data_manipulation():
    """Test comprehensive data manipulation."""
    print("=" * 60)
    print("Testing data manipulation...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 20

    * Create base variables
    generate id = _n
    generate group = mod(_n, 4)
    generate value = _n * 10 + runiform()

    * Test replace with if conditions
    replace value = 0 if group == 0

    * Test generate with expressions
    generate log_id = log(id)
    generate sqrt_id = sqrt(id)

    * Test egen functions
    egen total_value = sum(value)
    egen mean_value = mean(value)
    egen max_value = max(value)
    egen min_value = min(value)
    egen group_sum = sum(value), by(group)

    * Test sort
    sort group id

    * Test drop and keep
    drop log_id sqrt_id

    * Count remaining variables
    """
    rc = interp.run(code)

    assert rc == 0, f"Data manipulation failed with rc={rc}"
    assert interp.data.N == 20, "Should have 20 observations"
    assert "total_value" in interp.data.varlist
    assert "mean_value" in interp.data.varlist
    assert "group_sum" in interp.data.varlist
    assert "log_id" not in interp.data.varlist, "log_id should be dropped"
    print("✓ Data manipulation works")


def test_control_flow():
    """Test control flow structures."""
    print("=" * 60)
    print("Testing control flow...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 10
    generate x = _n

    * Test foreach with in
    local sum = 0
    foreach i in 1 2 3 4 5 {
        local sum = `sum' + `i'
    }

    * Test forvalues
    local product = 1
    forvalues j = 1/5 {
        local product = `product' * `j'
    }

    * Test foreach of varlist
    generate y = 0
    generate z = 0
    foreach v of varlist x y z {
        replace `v' = `v' + 1
    }

    * Test if-else block
    local condition = 1
    if `condition' == 1 {
        local result = "yes"
    }
    else {
        local result = "no"
    }
    """
    rc = interp.run(code)

    assert rc == 0, f"Control flow failed with rc={rc}"

    sum_val = float(interp.macros.get_local("sum"))
    assert sum_val == 15, f"foreach sum should be 15, got {sum_val}"

    product_val = float(interp.macros.get_local("product"))
    assert product_val == 120, f"forvalues product should be 120, got {product_val}"

    result_val = interp.macros.get_local("result")
    assert result_val == "yes", f"if-else result should be 'yes', got {result_val}"

    print("✓ Control flow works")


def test_string_operations():
    """Test string variable operations."""
    print("=" * 60)
    print("Testing string operations...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 5

    * Create string variable (Stata syntax approximation)
    generate str20 name = ""
    replace name = "Alice" in 1
    replace name = "Bob" in 2
    replace name = "Charlie" in 3
    replace name = "Diana" in 4
    replace name = "Eve" in 5

    * String functions
    generate name_len = strlen(name)
    generate name_upper = strupper(name)
    generate name_lower = strlower(name)
    generate name_sub = substr(name, 1, 3)
    """
    rc = interp.run(code)

    assert rc == 0, f"String operations failed with rc={rc}"

    # Check string lengths
    name_len = list(interp.data.get_var("name_len"))
    assert name_len == [5, 3, 7, 5, 3], f"String lengths wrong: {name_len}"

    # Check substr
    name_sub = list(interp.data.get_var("name_sub"))
    assert name_sub == ["Ali", "Bob", "Cha", "Dia", "Eve"], f"Substr wrong: {name_sub}"

    print("✓ String operations work")


def test_preserve_restore():
    """Test preserve and restore functionality."""
    print("=" * 60)
    print("Testing preserve/restore...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    clear
    set obs 10
    generate x = _n

    * Preserve original data
    preserve

    * Modify data
    drop if x > 5
    generate y = x * 2

    * Restore original
    restore
    """
    rc = interp.run(code)

    assert rc == 0, f"Preserve/restore failed with rc={rc}"
    assert interp.data.N == 10, "After restore, should have 10 observations"
    assert "y" not in interp.data.varlist, "y should not exist after restore"

    print("✓ Preserve/restore works")


def test_macro_functions():
    """Test extended macro functions."""
    print("=" * 60)
    print("Testing macro functions...")
    print("=" * 60)

    interp = StataInterpreter(quiet=True)

    code = """
    * Test word count
    local mylist "apple banana cherry date elderberry"
    local count: word count `mylist'

    * Test word extraction
    local first: word 1 of `mylist'
    local third: word 3 of `mylist'
    local last: word 5 of `mylist'
    """
    rc = interp.run(code)

    assert rc == 0, f"Macro functions failed with rc={rc}"

    count = interp.macros.get_local("count")
    assert count == "5", f"Word count should be 5, got {count}"

    first = interp.macros.get_local("first")
    assert first == "apple", f"First word should be 'apple', got {first}"

    third = interp.macros.get_local("third")
    assert third == "cherry", f"Third word should be 'cherry', got {third}"

    print("✓ Macro functions work")


def run_all_tests():
    """Run all ado tests."""
    print("\n" + "=" * 60)
    print("STATA ADO INTERPRETER TEST SUITE")
    print("=" * 60 + "\n")

    tests = [
        test_simple_ado_program,
        test_data_manipulation,
        test_control_flow,
        test_string_operations,
        test_preserve_restore,
        test_macro_functions,
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
    import sys
    success = run_all_tests()
    sys.exit(0 if success else 1)
