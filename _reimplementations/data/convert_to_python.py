#!/usr/bin/env python3
"""
Convert CSV test data to Python pickle format.
Also parses Stata dates correctly for tvtools testing.
"""

import pandas as pd
import os
from datetime import datetime, timedelta

csv_dir = "/home/tpcopeland/Stata-Tools/_reimplementations/data/csv"
pkl_dir = "/home/tpcopeland/Stata-Tools/_reimplementations/data/Python"

os.makedirs(pkl_dir, exist_ok=True)

# List of files to convert
files = [
    "cohort", "hrt", "dmt", "steroids", "hospitalizations",
    "hospitalizations_wide", "point_events", "overlapping_exposures",
    "edss_long", "edge_single_obs", "edge_single_exp",
    "edge_short_followup", "edge_short_exp", "edge_same_type",
    "edge_boundary_exp"
]

# Date columns by file
date_cols = {
    "cohort": ["study_entry", "study_exit", "edss4_dt", "death_dt", "emigration_dt"],
    "hrt": ["rx_start", "rx_stop"],
    "dmt": ["dmt_start", "dmt_stop"],
    "steroids": ["steroid_start", "steroid_stop"],
    "hospitalizations": ["hosp_date", "hosp_end"],
    "hospitalizations_wide": ["study_entry", "study_exit", "hosp_date1", "hosp_date2",
                              "hosp_date3", "hosp_date4", "hosp_date5"],
    "point_events": ["event_date"],
    "overlapping_exposures": ["exp_start", "exp_stop"],
    "edss_long": ["edss_dt"],
    "edge_single_obs": ["study_entry", "study_exit", "edss4_dt", "death_dt", "emigration_dt"],
    "edge_single_exp": ["rx_start", "rx_stop"],
    "edge_short_followup": ["study_entry", "study_exit"],
    "edge_short_exp": ["rx_start", "rx_stop"],
    "edge_same_type": ["rx_start", "rx_stop"],
    "edge_boundary_exp": ["rx_start", "rx_stop"]
}

def parse_stata_date(date_str):
    """Convert Stata date string (e.g., '03may2013') to datetime."""
    if pd.isna(date_str) or date_str == '' or date_str == '.':
        return pd.NaT
    try:
        return pd.to_datetime(date_str, format='%d%b%Y')
    except:
        return pd.NaT

print("Converting CSV files to Python format...")
print("-" * 60)

for f in files:
    csv_path = os.path.join(csv_dir, f"{f}.csv")
    pkl_path = os.path.join(pkl_dir, f"{f}.pkl")

    if not os.path.exists(csv_path):
        print(f"  [SKIP] {f}.csv not found")
        continue

    # Read CSV
    df = pd.read_csv(csv_path)

    # Convert Stata date strings to actual dates
    if f in date_cols:
        for col in date_cols[f]:
            if col in df.columns:
                # Stata dates are in format like "03may2013"
                df[col] = df[col].apply(parse_stata_date)

    # Save as pickle
    df.to_pickle(pkl_path)
    print(f"  [OK] {f}.pkl ({len(df)} obs, {len(df.columns)} vars)")

print("-" * 60)
print("Conversion complete")
