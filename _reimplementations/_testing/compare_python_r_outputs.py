"""
Compare Python and R tvtools outputs

This script compares the outputs from Python and R implementations
of tvtools to verify consistency.

Usage:
    python3 compare_python_r_outputs.py
"""

import pandas as pd
import numpy as np
from pathlib import Path
import sys

# Paths
BASE_DIR = Path("/home/user/Stata-Tools/Reimplementations/Testing")
PYTHON_DIR = BASE_DIR / "Python_test_outputs"
R_DIR = BASE_DIR / "R_test_outputs"
COMPARE_DIR = BASE_DIR / "Comparison_outputs"

# Create comparison directory
COMPARE_DIR.mkdir(exist_ok=True)


def compare_dataframes(py_df, r_df, test_name):
    """
    Compare two dataframes and report differences.

    Returns: (is_match, differences_dict)
    """
    differences = {}

    # Check shape
    if py_df.shape != r_df.shape:
        differences['shape'] = {
            'python': py_df.shape,
            'r': r_df.shape
        }

    # Check columns (allowing for order differences)
    py_cols = set(py_df.columns)
    r_cols = set(r_df.columns)

    if py_cols != r_cols:
        differences['columns'] = {
            'python_only': py_cols - r_cols,
            'r_only': r_cols - py_cols
        }

    # Compare common columns
    common_cols = py_cols & r_cols
    if common_cols:
        # Sort both dataframes by ID and date columns for fair comparison
        sort_cols = []
        for col in ['patient_id', 'id', 'start', 'exp_start']:
            if col in common_cols:
                sort_cols.append(col)
                break

        if sort_cols:
            py_sorted = py_df[list(common_cols)].sort_values(sort_cols).reset_index(drop=True)
            r_sorted = r_df[list(common_cols)].sort_values(sort_cols).reset_index(drop=True)

            # Compare values
            for col in common_cols:
                if col in py_sorted.columns and col in r_sorted.columns:
                    # Handle different types (e.g., dates as strings vs datetime)
                    py_col = py_sorted[col].astype(str)
                    r_col = r_sorted[col].astype(str)

                    if not py_col.equals(r_col):
                        # Find rows with differences
                        diff_mask = py_col != r_col
                        n_diffs = diff_mask.sum()

                        if n_diffs > 0:
                            differences[f'column_{col}'] = {
                                'n_differences': n_diffs,
                                'sample_differences': list(zip(
                                    py_col[diff_mask].head(5).tolist(),
                                    r_col[diff_mask].head(5).tolist()
                                ))
                            }

    is_match = len(differences) == 0
    return is_match, differences


def compare_test(test_name, py_file, r_file):
    """Compare a single test output."""
    print(f"\n{'='*80}")
    print(f"Comparing: {test_name}")
    print(f"{'='*80}")

    py_path = PYTHON_DIR / py_file
    r_path = R_DIR / r_file

    # Check if files exist
    if not py_path.exists():
        print(f"✗ Python file not found: {py_path}")
        return False

    if not r_path.exists():
        print(f"✗ R file not found: {r_path}")
        print(f"  (This is expected if R tests haven't been run yet)")
        return None

    # Load data
    try:
        py_df = pd.read_csv(py_path)
        r_df = pd.read_csv(r_path)
    except Exception as e:
        print(f"✗ Error loading files: {e}")
        return False

    print(f"Python: {py_df.shape[0]} rows, {py_df.shape[1]} columns")
    print(f"R:      {r_df.shape[0]} rows, {r_df.shape[1]} columns")

    # Compare
    is_match, differences = compare_dataframes(py_df, r_df, test_name)

    if is_match:
        print(f"✓ MATCH: Outputs are identical")
        return True
    else:
        print(f"✗ DIFFERENCES FOUND:")
        for key, value in differences.items():
            print(f"  - {key}: {value}")

        # Save comparison report
        report_path = COMPARE_DIR / f"{test_name}_differences.txt"
        with open(report_path, 'w') as f:
            f.write(f"Comparison Report: {test_name}\n")
            f.write("="*80 + "\n\n")
            f.write(f"Python file: {py_path}\n")
            f.write(f"R file: {r_path}\n\n")
            f.write(f"Differences:\n")
            for key, value in differences.items():
                f.write(f"\n{key}:\n{value}\n")

        print(f"\n  Detailed report saved to: {report_path}")
        return False


def main():
    """Run all comparisons."""
    print("="*80)
    print("PYTHON vs R TVTOOLS OUTPUT COMPARISON")
    print("="*80)

    # Define test pairs
    tests = [
        ("Test1_TVExpose_Basic", "test1_tvexpose_basic.csv", "test1_tvexpose_basic.csv"),
        ("Test2_TVExpose_Categorical", "test2_tvexpose_categorical.csv", "test2_tvexpose_categorical.csv"),
        ("Test3_TVExpose_KeepCols", "test3_tvexpose_keepcols.csv", "test3_tvexpose_keepcols.csv"),
        ("Test4_TVMerge_Basic", "test4_tvmerge_basic.csv", "test4_tvmerge_basic.csv"),
        ("Test5_TVEvent_MI", "test5_tvevent_mi.csv", "test5_tvevent_mi.csv"),
        ("Test6_TVEvent_Death", "test6_tvevent_death.csv", "test6_tvevent_death.csv"),
    ]

    results = {}
    for test_name, py_file, r_file in tests:
        result = compare_test(test_name, py_file, r_file)
        results[test_name] = result

    # Summary
    print(f"\n{'='*80}")
    print("SUMMARY")
    print(f"{'='*80}\n")

    matches = sum(1 for r in results.values() if r is True)
    mismatches = sum(1 for r in results.values() if r is False)
    missing = sum(1 for r in results.values() if r is None)

    print(f"Tests compared: {len(results)}")
    print(f"  ✓ Matches:    {matches}")
    print(f"  ✗ Mismatches: {mismatches}")
    print(f"  ? Missing R:  {missing}")

    print("\nDetailed results:")
    for test_name, result in results.items():
        if result is True:
            status = "✓ MATCH"
        elif result is False:
            status = "✗ MISMATCH"
        else:
            status = "? R OUTPUT MISSING"
        print(f"  {status}: {test_name}")

    if missing == len(results):
        print("\n" + "="*80)
        print("NOTE: R test outputs not yet available.")
        print("Run R tests first, then run this comparison script.")
        print("="*80)
        return 2
    elif mismatches > 0:
        print("\n" + "="*80)
        print("ATTENTION: Some outputs don't match!")
        print("Review difference reports in:", COMPARE_DIR)
        print("="*80)
        return 1
    else:
        print("\n" + "="*80)
        print("SUCCESS: All outputs match!")
        print("="*80)
        return 0


if __name__ == "__main__":
    sys.exit(main())
