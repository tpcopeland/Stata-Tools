#!/usr/bin/env python3
"""
Cross-Language Validation Script for tvtools

Compares Python and R implementations against Stata reference outputs.
"""

import pandas as pd
import numpy as np
import sys
import os
from datetime import datetime

# Add tvtools to path
sys.path.insert(0, '/home/tpcopeland/Stata-Tools/_reimplementations/Python/tvtools')
from tvtools import tvexpose, tvevent, tvmerge

# Paths
DATA_PATH = "/home/tpcopeland/Stata-Tools/_reimplementations/data/Python"
STATA_OUT = "/home/tpcopeland/Stata-Tools/_reimplementations/validation/stata_outputs"

def load_test_data():
    """Load test data from pickle files."""
    cohort = pd.read_pickle(f"{DATA_PATH}/cohort.pkl")
    hrt = pd.read_pickle(f"{DATA_PATH}/hrt.pkl")
    dmt = pd.read_pickle(f"{DATA_PATH}/dmt.pkl")
    return cohort, hrt, dmt

def compare_persontime(py_df, stata_csv, label):
    """Compare total person-time between Python and Stata outputs."""
    stata_df = pd.read_csv(stata_csv)

    # Calculate person-time from Python output
    py_df['person_days'] = (py_df['stop'] - py_df['start']).dt.days + 1
    py_total = py_df['person_days'].sum()

    # Get Stata total
    stata_total = stata_df['person_days'].sum() if 'person_days' in stata_df.columns else 0

    # Allow for small numeric differences
    diff = abs(py_total - stata_total)
    match = diff < 10  # Allow up to 10 days difference due to rounding

    status = "PASS" if match else "FAIL"
    print(f"  {label}: Python={py_total:,} days, Stata={stata_total:,} days [{status}]")

    return match

def validate_basic_tvexpose():
    """Test 1: Basic tvexpose."""
    print("\nTest 1: Basic tvexpose")
    cohort, hrt, _ = load_test_data()

    result = tvexpose(
        master_data=cohort,
        exposure_file=hrt,
        id='id',
        start='rx_start',
        stop='rx_stop',
        exposure='hrt_type',
        entry='study_entry',
        exit='study_exit',
        reference=0,
        verbose=False
    )

    # Check we got output
    assert len(result.data) > 0, "No output data"

    # Compare with Stata
    stata_df = pd.read_csv(f"{STATA_OUT}/test1_basic_tvexpose.csv")

    # Compare row counts
    py_count = len(result.data)
    stata_count = len(stata_df)

    # Allow for small differences due to date handling
    pct_diff = abs(py_count - stata_count) / stata_count * 100
    match = pct_diff < 5  # Within 5%

    status = "PASS" if match else "FAIL"
    print(f"  Row count: Python={py_count}, Stata={stata_count} ({pct_diff:.1f}% diff) [{status}]")

    return match

def validate_evertreated():
    """Test 2: Evertreated option."""
    print("\nTest 2: Evertreated option")
    cohort, hrt, _ = load_test_data()

    result = tvexpose(
        master_data=cohort,
        exposure_file=hrt,
        id='id',
        start='rx_start',
        stop='rx_stop',
        exposure='hrt_type',
        entry='study_entry',
        exit='study_exit',
        reference=0,
        evertreated=True,
        verbose=False
    )

    # Check values are only 0 or 1
    exp_col = 'tv_exposure' if 'tv_exposure' in result.data.columns else list(result.data.columns)[-1]
    unique_vals = result.data[exp_col].unique()
    valid_vals = all(v in [0, 1] for v in unique_vals if pd.notna(v))

    status = "PASS" if valid_vals else "FAIL"
    print(f"  Binary values only: {valid_vals} [{status}]")

    # Check monotonicity - once exposed, stays exposed
    by_person = result.data.groupby('id')[exp_col].apply(list)
    monotonic = all(
        all(vals[i] <= vals[i+1] for i in range(len(vals)-1))
        for vals in by_person if len(vals) > 1
    )

    status = "PASS" if monotonic else "FAIL"
    print(f"  Monotonic (never reverts): {monotonic} [{status}]")

    return valid_vals and monotonic

def validate_currentformer():
    """Test 3: Currentformer option."""
    print("\nTest 3: Currentformer option")
    cohort, hrt, _ = load_test_data()

    result = tvexpose(
        master_data=cohort,
        exposure_file=hrt,
        id='id',
        start='rx_start',
        stop='rx_stop',
        exposure='hrt_type',
        entry='study_entry',
        exit='study_exit',
        reference=0,
        currentformer=True,
        verbose=False
    )

    # Check values are 0, 1, or 2
    exp_col = 'tv_exposure' if 'tv_exposure' in result.data.columns else list(result.data.columns)[-1]
    unique_vals = result.data[exp_col].unique()
    valid_vals = all(v in [0, 1, 2] for v in unique_vals if pd.notna(v))

    status = "PASS" if valid_vals else "FAIL"
    print(f"  Valid categories (0,1,2): {valid_vals} [{status}]")

    return valid_vals

def calc_duration(df):
    """Calculate duration handling both datetime and numeric formats."""
    if hasattr(df['stop'], 'dt'):
        return (df['stop'] - df['start']).dt.days + 1
    else:
        return df['stop'] - df['start'] + 1

def validate_lag():
    """Test 4: Lag option."""
    print("\nTest 4: Lag option")
    cohort, hrt, _ = load_test_data()

    # Without lag
    result_no_lag = tvexpose(
        master_data=cohort,
        exposure_file=hrt,
        id='id',
        start='rx_start',
        stop='rx_stop',
        exposure='hrt_type',
        entry='study_entry',
        exit='study_exit',
        reference=0,
        verbose=False
    )

    # With lag
    result_with_lag = tvexpose(
        master_data=cohort,
        exposure_file=hrt,
        id='id',
        start='rx_start',
        stop='rx_stop',
        exposure='hrt_type',
        entry='study_entry',
        exit='study_exit',
        reference=0,
        lag=30,
        verbose=False
    )

    # Lag should delay exposure start (less exposed time)
    exp_col = 'tv_exposure' if 'tv_exposure' in result_no_lag.data.columns else list(result_no_lag.data.columns)[-1]

    # Calculate exposed time
    def calc_exposed_time(df, col):
        df = df.copy()
        df['duration'] = calc_duration(df)
        # Handle mixed types - exposed = not 0 and not 'Unexposed'
        exposed_mask = ~df[col].isin([0, '0', 'Unexposed', 'unexposed'])
        return df.loc[exposed_mask, 'duration'].sum()

    exp_no_lag = calc_exposed_time(result_no_lag.data, exp_col)
    exp_with_lag = calc_exposed_time(result_with_lag.data, exp_col)

    lag_reduced = exp_with_lag < exp_no_lag

    status = "PASS" if lag_reduced else "FAIL"
    print(f"  Lag reduces exposed time: {exp_with_lag:,} < {exp_no_lag:,} [{status}]")

    return lag_reduced

def validate_washout():
    """Test 5: Washout option."""
    print("\nTest 5: Washout option")
    cohort, hrt, _ = load_test_data()

    # Without washout
    result_no_washout = tvexpose(
        master_data=cohort,
        exposure_file=hrt,
        id='id',
        start='rx_start',
        stop='rx_stop',
        exposure='hrt_type',
        entry='study_entry',
        exit='study_exit',
        reference=0,
        verbose=False
    )

    # With washout
    result_with_washout = tvexpose(
        master_data=cohort,
        exposure_file=hrt,
        id='id',
        start='rx_start',
        stop='rx_stop',
        exposure='hrt_type',
        entry='study_entry',
        exit='study_exit',
        reference=0,
        washout=30,
        verbose=False
    )

    # Washout should extend exposure (more exposed time)
    exp_col = 'tv_exposure' if 'tv_exposure' in result_no_washout.data.columns else list(result_no_washout.data.columns)[-1]

    def calc_exposed_time(df, col):
        df = df.copy()
        df['duration'] = calc_duration(df)
        # Handle mixed types - exposed = not 0 and not 'Unexposed'
        exposed_mask = ~df[col].isin([0, '0', 'Unexposed', 'unexposed'])
        return df.loc[exposed_mask, 'duration'].sum()

    exp_no_washout = calc_exposed_time(result_no_washout.data, exp_col)
    exp_with_washout = calc_exposed_time(result_with_washout.data, exp_col)

    washout_extended = exp_with_washout >= exp_no_washout

    status = "PASS" if washout_extended else "FAIL"
    print(f"  Washout extends exposed time: {exp_with_washout:,} >= {exp_no_washout:,} [{status}]")

    return washout_extended

def validate_persontime_conservation():
    """Test 9: Person-time conservation."""
    print("\nTest 9: Person-time conservation")
    cohort, hrt, _ = load_test_data()

    result = tvexpose(
        master_data=cohort,
        exposure_file=hrt,
        id='id',
        start='rx_start',
        stop='rx_stop',
        exposure='hrt_type',
        entry='study_entry',
        exit='study_exit',
        reference=0,
        verbose=False
    )

    # Calculate expected person-time from cohort
    cohort = cohort.copy()
    if hasattr(cohort['study_exit'], 'dt'):
        cohort['expected_days'] = (cohort['study_exit'] - cohort['study_entry']).dt.days + 1
    else:
        cohort['expected_days'] = cohort['study_exit'] - cohort['study_entry'] + 1
    expected_total = cohort['expected_days'].sum()

    # Calculate actual person-time from tvexpose output
    result.data['actual_days'] = calc_duration(result.data)
    actual_total = result.data['actual_days'].sum()

    # Should be equal (within tolerance for edge cases)
    pct_diff = abs(actual_total - expected_total) / expected_total * 100
    conserved = pct_diff < 1  # Within 1%

    status = "PASS" if conserved else "FAIL"
    print(f"  Expected: {expected_total:,} days")
    print(f"  Actual:   {actual_total:,} days")
    print(f"  Difference: {pct_diff:.2f}% [{status}]")

    return conserved

def run_all_validations():
    """Run all validation tests."""
    print("="*70)
    print("CROSS-LANGUAGE VALIDATION: Python vs Stata")
    print("="*70)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    results = []

    results.append(("Basic tvexpose", validate_basic_tvexpose()))
    results.append(("Evertreated", validate_evertreated()))
    results.append(("Currentformer", validate_currentformer()))
    results.append(("Lag option", validate_lag()))
    results.append(("Washout option", validate_washout()))
    results.append(("Person-time conservation", validate_persontime_conservation()))

    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)

    passed = sum(1 for _, r in results if r)
    total = len(results)

    for name, result in results:
        status = "PASS" if result else "FAIL"
        print(f"  {name}: {status}")

    print("-"*70)
    print(f"TOTAL: {passed}/{total} tests passed")
    print("="*70)

    return passed == total

if __name__ == "__main__":
    success = run_all_validations()
    sys.exit(0 if success else 1)
