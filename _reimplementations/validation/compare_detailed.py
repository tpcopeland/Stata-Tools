#!/usr/bin/env python3
"""Detailed field-by-field comparison of Stata vs Python tvexpose outputs."""

import pandas as pd
import numpy as np
import sys
sys.path.insert(0, '/home/tpcopeland/Stata-Tools/_reimplementations/Python/tvtools')
from tvtools import tvexpose

DATA_PATH = "/home/tpcopeland/Stata-Tools/_reimplementations/data/Python"
STATA_OUT = "/home/tpcopeland/Stata-Tools/_reimplementations/validation/stata_outputs"

def load_data():
    cohort = pd.read_pickle(f"{DATA_PATH}/cohort.pkl")
    hrt = pd.read_pickle(f"{DATA_PATH}/hrt.pkl")
    return cohort, hrt

def main():
    print("Loading data...")
    cohort, hrt = load_data()

    # Run Python tvexpose
    print("Running Python tvexpose...")
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
    py_df = result.data.copy()

    # Load Stata output
    print("Loading Stata output...")
    stata_df = pd.read_csv(f"{STATA_OUT}/test1_basic_tvexpose.csv")

    # Normalize column names
    py_df = py_df.rename(columns={'start': 'rx_start', 'stop': 'rx_stop', 'tv_exposure': 'tv_hrt'})

    # Convert Python dates to comparable format (days since 1970-01-01)
    if hasattr(py_df['rx_start'], 'dt'):
        # Already datetime - convert to days from 1970
        py_df['rx_start'] = (py_df['rx_start'] - pd.Timestamp('1970-01-01')).dt.days
        py_df['rx_stop'] = (py_df['rx_stop'] - pd.Timestamp('1970-01-01')).dt.days

    # Convert Stata dates (YYYY/MM/DD strings) to days from 1970
    stata_df['rx_start'] = (pd.to_datetime(stata_df['rx_start']) - pd.Timestamp('1970-01-01')).dt.days
    stata_df['rx_stop'] = (pd.to_datetime(stata_df['rx_stop']) - pd.Timestamp('1970-01-01')).dt.days

    # Normalize exposure values (Python uses 0, Stata uses "Unexposed")
    py_df['tv_hrt'] = py_df['tv_hrt'].replace({0: 'Unexposed', 1: 'Estrogen', 2: 'Progestin', 3: 'Combined'})
    if py_df['tv_hrt'].dtype == 'object':
        pass  # Already strings
    else:
        py_df['tv_hrt'] = py_df['tv_hrt'].map({0: 'Unexposed', 1: 'Estrogen', 2: 'Progestin', 3: 'Combined'})

    # Keep relevant columns
    py_df = py_df[['id', 'rx_start', 'rx_stop', 'tv_hrt']].copy()
    stata_df = stata_df[['id', 'rx_start', 'rx_stop', 'tv_hrt']].copy()

    # Sort both
    py_df = py_df.sort_values(['id', 'rx_start', 'rx_stop']).reset_index(drop=True)
    stata_df = stata_df.sort_values(['id', 'rx_start', 'rx_stop']).reset_index(drop=True)

    print(f"\nRow counts: Python={len(py_df)}, Stata={len(stata_df)}")

    # Calculate person-time (dates are now numeric days)
    def calc_pt(df):
        df = df.copy()
        df['pt'] = df['rx_stop'] - df['rx_start'] + 1
        return df['pt'].sum()

    py_pt = calc_pt(py_df)
    stata_pt = calc_pt(stata_df)
    print(f"Person-time: Python={py_pt:,}, Stata={stata_pt:,}, Diff={stata_pt - py_pt:,}")

    # Check per-person row counts
    py_counts = py_df.groupby('id').size()
    stata_counts = stata_df.groupby('id').size()

    diff_counts = (py_counts - stata_counts).dropna()
    diff_ids = diff_counts[diff_counts != 0].index.tolist()

    print(f"\nIDs with different row counts: {len(diff_ids)}")
    if diff_ids:
        print("IDs with differences:")
        for i, id_val in enumerate(diff_ids):
            print(f"  ID {id_val}: Python={py_counts.get(id_val, 0)}, Stata={stata_counts.get(id_val, 0)}")

        # Show detailed comparison for first 2 IDs
        print("\n--- Detailed comparison for IDs with row count differences ---")
        for id_val in diff_ids[:2]:
            print(f"\nID {id_val}:")
            print("  Python:")
            py_rows = py_df[py_df['id'] == id_val].sort_values('rx_start')
            for _, row in py_rows.iterrows():
                print(f"    {row['rx_start']} - {row['rx_stop']}: {row['tv_hrt']} (days: {row['rx_stop'] - row['rx_start'] + 1})")

            print("  Stata:")
            stata_rows = stata_df[stata_df['id'] == id_val].sort_values('rx_start')
            for _, row in stata_rows.iterrows():
                print(f"    {row['rx_start']} - {row['rx_stop']}: {row['tv_hrt']} (days: {row['rx_stop'] - row['rx_start'] + 1})")

    # For IDs with same row count, check if values match
    same_count_ids = set(py_counts.index) & set(stata_counts.index) - set(diff_ids)
    mismatched_ids = []

    for id_val in same_count_ids:
        py_rows = py_df[py_df['id'] == id_val].reset_index(drop=True)
        stata_rows = stata_df[stata_df['id'] == id_val].reset_index(drop=True)

        if len(py_rows) != len(stata_rows):
            continue

        # Check if all fields match
        matches = True
        for col in ['rx_start', 'rx_stop', 'tv_hrt']:
            if not (py_rows[col] == stata_rows[col]).all():
                matches = False
                break

        if not matches:
            mismatched_ids.append(id_val)

    print(f"\nIDs with same row count but different values: {len(mismatched_ids)}")
    if mismatched_ids:
        print("First 5 mismatched IDs:")
        for id_val in mismatched_ids[:5]:
            print(f"\n  ID {id_val}:")
            print("  Python:")
            print(py_df[py_df['id'] == id_val].to_string(index=False))
            print("  Stata:")
            print(stata_df[stata_df['id'] == id_val].to_string(index=False))

if __name__ == "__main__":
    main()
