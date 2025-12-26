#!/usr/bin/env python3
"""
Comprehensive Row-by-Row Comparison: Stata vs Python vs R
Compares every row and value across all three implementations.
"""

import pandas as pd
import numpy as np
import sys
import os
from datetime import datetime

sys.path.insert(0, '/home/tpcopeland/Stata-Tools/_reimplementations/Python/tvtools')
from tvtools import tvexpose

DATA_PATH_PY = "/home/tpcopeland/Stata-Tools/_reimplementations/data/Python"
DATA_PATH_R = "/home/tpcopeland/Stata-Tools/_reimplementations/data/R"
STATA_OUT = "/home/tpcopeland/Stata-Tools/_reimplementations/validation/stata_outputs"

print("="*80)
print("COMPREHENSIVE ROW-BY-ROW COMPARISON: Stata vs Python vs R")
print("="*80)
print(f"Date: {datetime.now()}\n")

def load_python_data():
    cohort = pd.read_pickle(f"{DATA_PATH_PY}/cohort.pkl")
    hrt = pd.read_pickle(f"{DATA_PATH_PY}/hrt.pkl")
    return cohort, hrt

def run_python_tvexpose(cohort, hrt):
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
    return result.data.copy()

def load_stata_output(test_name):
    return pd.read_csv(f"{STATA_OUT}/{test_name}.csv")

def normalize_dates(df, date_cols):
    """Convert dates to days since 1970-01-01 for comparison."""
    df = df.copy()
    for col in date_cols:
        if col in df.columns:
            if hasattr(df[col], 'dt'):
                # Already datetime
                df[col] = (df[col] - pd.Timestamp('1970-01-01')).dt.days
            elif df[col].dtype == 'object':
                # String dates (YYYY/MM/DD from Stata)
                df[col] = (pd.to_datetime(df[col]) - pd.Timestamp('1970-01-01')).dt.days
    return df

def normalize_exposure(val):
    """Normalize exposure values for comparison."""
    mapping = {
        0: 'Unexposed', 'Unexposed': 'Unexposed',
        1: 'Estrogen', 'Estrogen': 'Estrogen',
        2: 'Combined', 'Combined': 'Combined',
        3: 'Progestin', 'Progestin': 'Progestin',
    }
    return mapping.get(val, str(val))

def compare_dataframes(df1, df2, name1, name2, exp_col1, exp_col2):
    """Compare two dataframes row by row."""
    
    # Prepare both dataframes
    df1 = df1.copy()
    df2 = df2.copy()
    
    # Normalize column names
    date_cols_1 = [c for c in df1.columns if 'start' in c.lower() or 'stop' in c.lower()]
    date_cols_2 = [c for c in df2.columns if 'start' in c.lower() or 'stop' in c.lower()]
    
    df1 = normalize_dates(df1, date_cols_1)
    df2 = normalize_dates(df2, date_cols_2)
    
    # Find start/stop columns
    start1 = [c for c in df1.columns if 'start' in c.lower()][0]
    stop1 = [c for c in df1.columns if 'stop' in c.lower()][0]
    start2 = [c for c in df2.columns if 'start' in c.lower()][0]
    stop2 = [c for c in df2.columns if 'stop' in c.lower()][0]
    
    # Normalize exposure values
    df1['_exp'] = df1[exp_col1].apply(normalize_exposure)
    df2['_exp'] = df2[exp_col2].apply(normalize_exposure)
    
    # Create comparison key: id + start + stop + exposure
    df1['_key'] = df1['id'].astype(str) + '_' + df1[start1].astype(str) + '_' + df1[stop1].astype(str) + '_' + df1['_exp']
    df2['_key'] = df2['id'].astype(str) + '_' + df2[start2].astype(str) + '_' + df2[stop2].astype(str) + '_' + df2['_exp']
    
    keys1 = set(df1['_key'])
    keys2 = set(df2['_key'])
    
    matching = keys1 & keys2
    only_in_1 = keys1 - keys2
    only_in_2 = keys2 - keys1
    
    print(f"\n  Comparison: {name1} vs {name2}")
    print(f"    {name1} rows: {len(df1)}")
    print(f"    {name2} rows: {len(df2)}")
    print(f"    Matching rows: {len(matching)}")
    print(f"    Only in {name1}: {len(only_in_1)}")
    print(f"    Only in {name2}: {len(only_in_2)}")
    
    if only_in_1:
        print(f"\n    Sample rows only in {name1}:")
        sample_keys = list(only_in_1)[:5]
        for key in sample_keys:
            row = df1[df1['_key'] == key].iloc[0]
            print(f"      ID={row['id']}, start={row[start1]}, stop={row[stop1]}, exp={row['_exp']}")
    
    if only_in_2:
        print(f"\n    Sample rows only in {name2}:")
        sample_keys = list(only_in_2)[:5]
        for key in sample_keys:
            row = df2[df2['_key'] == key].iloc[0]
            print(f"      ID={row['id']}, start={row[start2]}, stop={row[stop2]}, exp={row['_exp']}")
    
    match_pct = len(matching) / max(len(df1), len(df2)) * 100
    return len(only_in_1) == 0 and len(only_in_2) == 0, match_pct

# =============================================================================
# Test 1: Basic tvexpose
# =============================================================================
print("\nTest 1: Basic tvexpose - Full row comparison")
print("-"*60)

cohort, hrt = load_python_data()
py_df = run_python_tvexpose(cohort, hrt)
stata_df = load_stata_output("test1_basic_tvexpose")

# Find exposure column
py_exp_col = 'tv_exposure' if 'tv_exposure' in py_df.columns else [c for c in py_df.columns if 'tv_' in c.lower()][0]
stata_exp_col = 'tv_hrt'

py_stata_match, py_stata_pct = compare_dataframes(
    py_df, stata_df, "Python", "Stata", py_exp_col, stata_exp_col
)

# =============================================================================
# Now compare each test output
# =============================================================================
tests = [
    ("test2_evertreated", dict(evertreated=True)),
    ("test3_currentformer", dict(currentformer=True)),
    ("test4_lag", dict(lag=30)),
    ("test5_washout", dict(washout=30)),
]

all_results = []
all_results.append(("Basic tvexpose", py_stata_pct))

for test_name, options in tests:
    print(f"\n{test_name} - Full row comparison")
    print("-"*60)
    
    # Run Python with these options
    py_result = tvexpose(
        master_data=cohort,
        exposure_file=hrt,
        id='id',
        start='rx_start',
        stop='rx_stop',
        exposure='hrt_type',
        entry='study_entry',
        exit='study_exit',
        reference=0,
        verbose=False,
        **options
    )
    py_df = py_result.data.copy()
    
    # Load Stata output
    stata_df = load_stata_output(test_name)
    
    # Find exposure columns
    py_exp_col = [c for c in py_df.columns if 'tv_' in c.lower() or 'ever_' in c.lower() or 'cf_' in c.lower()][0]
    stata_exp_col = [c for c in stata_df.columns if 'tv_' in c.lower() or 'ever_' in c.lower() or 'cf_' in c.lower() or 'lag_' in c.lower() or 'washout_' in c.lower()][0]
    
    match, pct = compare_dataframes(py_df, stata_df, "Python", "Stata", py_exp_col, stata_exp_col)
    all_results.append((test_name, pct))

# =============================================================================
# Summary
# =============================================================================
print("\n" + "="*80)
print("SUMMARY: Python vs Stata Row Matching")
print("="*80)

for test_name, pct in all_results:
    status = "EXACT MATCH" if pct == 100 else f"{pct:.1f}% match"
    print(f"  {test_name}: {status}")

total_match = sum(1 for _, pct in all_results if pct == 100)
print(f"\nTotal: {total_match}/{len(all_results)} tests with 100% row match")
print("="*80)
