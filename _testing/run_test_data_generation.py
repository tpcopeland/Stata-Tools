#!/usr/bin/env python3
"""
Run generate_test_data through the Python Stata interpreter.
"""

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from stata_interpreter import StataInterpreter


def main():
    print("=" * 70)
    print("RUNNING generate_test_data.ado THROUGH PYTHON STATA INTERPRETER")
    print("=" * 70)

    # Get paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_dir = os.path.join(script_dir, "data")
    ado_file = os.path.join(script_dir, "generate_test_data.ado")

    print(f"Script directory: {script_dir}")
    print(f"Data directory: {data_dir}")
    print(f"ADO file: {ado_file}")

    # Create data directory if it doesn't exist
    os.makedirs(data_dir, exist_ok=True)

    # Initialize interpreter
    interp = StataInterpreter(quiet=False)

    # First, load the .ado file to define the program
    print("\n" + "=" * 70)
    print("Step 1: Loading generate_test_data.ado")
    print("=" * 70)

    with open(ado_file, 'r') as f:
        ado_code = f.read()

    rc = interp.run(ado_code)
    if rc != 0:
        print(f"Error loading .ado file: rc={rc}")
        return rc

    print(f"Loaded program. Available programs: {list(interp.programs.keys())}")

    # Now run the generate_test_data command
    print("\n" + "=" * 70)
    print("Step 2: Running generate_test_data command")
    print("=" * 70)

    # Run the command with the data directory
    code = f'''
    generate_test_data, savedir("{data_dir}") seed(12345) nobs(100) miss replace
    '''

    rc = interp.run(code)
    print(f"\nReturn code: {rc}")

    # Check what files were created
    print("\n" + "=" * 70)
    print("Step 3: Checking created files")
    print("=" * 70)

    expected_files = [
        "cohort.dta", "hrt.dta", "dmt.dta", "hospitalizations.dta",
        "migrations_wide.dta", "edss_long.dta",
        "cohort_miss.dta", "hrt_miss.dta", "dmt_miss.dta"
    ]

    for f in expected_files:
        fpath = os.path.join(data_dir, f)
        if os.path.exists(fpath):
            size = os.path.getsize(fpath)
            print(f"  [OK] {f} ({size} bytes)")
        else:
            print(f"  [MISSING] {f}")

    return rc


if __name__ == "__main__":
    sys.exit(main())
