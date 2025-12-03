#!/usr/bin/env python3
"""
Comprehensive Synthetic Test Data Generator for tvtools Reimplementations

Generates large-scale test datasets with edge cases for testing tvtools functions.
All datasets are deterministic (seed 42) for reproducibility.
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta

# Set seed for reproducibility
np.random.seed(42)


def generate_cohort(n_patients=1000):
    """
    Generate large cohort dataset with study entry/exit dates.

    Returns:
        DataFrame with columns: patient_id, study_entry, study_exit, age, sex
    """
    print("Generating cohort dataset...")

    # Patient IDs (1-1000)
    patient_ids = np.arange(1, n_patients + 1)

    # Study entry dates spread across 2015-2016
    entry_start = datetime(2015, 1, 1)
    entry_end = datetime(2016, 12, 31)
    days_range = (entry_end - entry_start).days
    study_entry = [entry_start + timedelta(days=int(np.random.uniform(0, days_range)))
                   for _ in range(n_patients)]

    # Study exit dates 2-6 years after entry
    study_exit = [entry + timedelta(days=int(np.random.uniform(365*2, 365*6)))
                  for entry in study_entry]

    # Age uniformly distributed 30-80
    age = np.random.uniform(30, 80, n_patients).astype(int)

    # Sex (M/F)
    sex = np.random.choice(['M', 'F'], n_patients)

    cohort = pd.DataFrame({
        'patient_id': patient_ids,
        'study_entry': study_entry,
        'study_exit': study_exit,
        'age': age,
        'sex': sex
    })

    return cohort


def generate_exposures(cohort, n_exposures=5000, dataset_num=1):
    """
    Generate exposure dataset with comprehensive edge cases.

    Edge cases included:
    - Overlapping exposure periods
    - Adjacent exposure periods (end = next start)
    - Gaps between exposures
    - Exposures starting before study_entry
    - Exposures ending after study_exit
    - Zero-duration exposures
    - Very long exposures (>2 years)
    - Very short exposures (1-3 days)
    - Multiple exposure types per patient
    - Patients with no exposures (10%)

    Args:
        cohort: DataFrame with patient data
        n_exposures: Target number of exposure records
        dataset_num: Dataset identifier (1 or 2)

    Returns:
        DataFrame with columns: patient_id, exp_start, exp_stop, drug_type
    """
    print(f"Generating exposure dataset {dataset_num} (target: {n_exposures:,} records)...")

    exposures = []

    # Calculate target exposures per patient on average
    n_patients = len(cohort)
    avg_exposures = n_exposures / n_patients

    # Distribute exposures using Poisson distribution (realistic variation)
    exposure_counts = np.random.poisson(avg_exposures, n_patients)

    # Ensure at least 10% of patients have no exposures
    no_exposure_patients = np.random.choice(n_patients, size=int(n_patients * 0.1), replace=False)
    exposure_counts[no_exposure_patients] = 0

    # Adjust to get close to target total
    current_total = exposure_counts.sum()
    if current_total > 0:
        scale_factor = n_exposures / current_total
        exposure_counts = (exposure_counts * scale_factor).astype(int)

    # Generate base exposures
    for idx, row in cohort.iterrows():
        patient_id = row['patient_id']
        study_entry = row['study_entry']
        study_exit = row['study_exit']
        study_duration = (study_exit - study_entry).days

        n_exp = exposure_counts[idx]

        if n_exp == 0:
            continue

        for i in range(n_exp):
            # Determine exposure type (0=reference, 1, 2, 3)
            exposure_type = np.random.randint(0, 4)

            # Generate start date with various scenarios
            scenario = np.random.random()

            if scenario < 0.05:  # 5% - Before study entry
                start_offset = np.random.randint(-180, 0)
                exp_start = study_entry + timedelta(days=start_offset)
            elif scenario < 0.10:  # 5% - At exact study entry
                exp_start = study_entry
            else:  # 85% - During study period
                start_offset = np.random.randint(0, max(1, study_duration - 1))
                exp_start = study_entry + timedelta(days=start_offset)

            # Generate duration with various patterns
            duration_type = np.random.random()

            if duration_type < 0.05:  # 5% - Zero duration
                duration = 0
            elif duration_type < 0.15:  # 10% - Very short (1-3 days)
                duration = np.random.randint(1, 4)
            elif duration_type < 0.25:  # 10% - Short (4-14 days)
                duration = np.random.randint(4, 15)
            elif duration_type < 0.70:  # 45% - Medium (15-180 days)
                duration = np.random.randint(15, 181)
            elif duration_type < 0.85:  # 15% - Long (181-365 days)
                duration = np.random.randint(181, 366)
            else:  # 15% - Very long (>2 years)
                duration = np.random.randint(731, 1096)

            exp_stop = exp_start + timedelta(days=duration)

            # 10% chance to extend beyond study exit
            if np.random.random() < 0.10:
                exp_stop = study_exit + timedelta(days=np.random.randint(1, 180))

            exposures.append({
                'patient_id': patient_id,
                'exp_start': exp_start,
                'exp_stop': exp_stop,
                'drug_type': exposure_type
            })

    # Create initial dataframe
    exp_df = pd.DataFrame(exposures)

    # Add overlapping exposures (15% of patients with multiple exposures)
    patients_with_exp = exp_df['patient_id'].unique()
    overlap_patients = np.random.choice(
        patients_with_exp,
        size=min(len(patients_with_exp), int(len(patients_with_exp) * 0.15)),
        replace=False
    )

    overlap_records = []
    for patient_id in overlap_patients:
        patient_exps = exp_df[exp_df['patient_id'] == patient_id]
        if len(patient_exps) == 0:
            continue

        # Pick a random existing exposure to overlap with
        base_exp = patient_exps.sample(1).iloc[0]

        # Create overlapping exposure
        exp_duration = (base_exp['exp_stop'] - base_exp['exp_start']).days
        if exp_duration <= 0:
            continue

        overlap_start = base_exp['exp_start'] + timedelta(
            days=np.random.randint(1, max(2, exp_duration))
        )
        overlap_duration = np.random.randint(30, 180)
        overlap_stop = overlap_start + timedelta(days=overlap_duration)

        overlap_records.append({
            'patient_id': patient_id,
            'exp_start': overlap_start,
            'exp_stop': overlap_stop,
            'drug_type': np.random.randint(0, 4)
        })

    if overlap_records:
        exp_df = pd.concat([exp_df, pd.DataFrame(overlap_records)], ignore_index=True)

    # Add adjacent exposures (10% of patients with multiple exposures)
    adjacent_patients = np.random.choice(
        patients_with_exp,
        size=min(len(patients_with_exp), int(len(patients_with_exp) * 0.10)),
        replace=False
    )

    adjacent_records = []
    for patient_id in adjacent_patients:
        patient_exps = exp_df[exp_df['patient_id'] == patient_id]
        if len(patient_exps) == 0:
            continue

        base_exp = patient_exps.sample(1).iloc[0]

        # Create adjacent exposure (starts exactly when previous ends)
        adjacent_start = base_exp['exp_stop']
        adjacent_duration = np.random.randint(30, 180)
        adjacent_stop = adjacent_start + timedelta(days=adjacent_duration)

        adjacent_records.append({
            'patient_id': patient_id,
            'exp_start': adjacent_start,
            'exp_stop': adjacent_stop,
            'drug_type': np.random.randint(0, 4)
        })

    if adjacent_records:
        exp_df = pd.concat([exp_df, pd.DataFrame(adjacent_records)], ignore_index=True)

    # Sort by patient_id and exp_start
    exp_df = exp_df.sort_values(['patient_id', 'exp_start']).reset_index(drop=True)

    return exp_df


def generate_events(cohort):
    """
    Generate events dataset with edge cases.

    Edge cases included:
    - Multiple competing events on same date
    - Events at exact interval boundaries (study entry/exit)
    - Events before study entry (invalid)
    - Events after study exit (invalid)
    - String date format (YYYY-MM-DD)

    Event types:
    - mi_date: Primary event (~30% of patients)
    - death_date: Competing risk 1 (~15% of patients)
    - emigration_date: Competing risk 2 (~10% of patients)

    Args:
        cohort: DataFrame with patient data

    Returns:
        DataFrame with columns: patient_id, mi_date, death_date, emigration_date
    """
    print("Generating events dataset...")

    events = []

    for idx, row in cohort.iterrows():
        patient_id = row['patient_id']
        study_entry = row['study_entry']
        study_exit = row['study_exit']
        study_duration = (study_exit - study_entry).days

        event_record = {'patient_id': patient_id}

        # MI event (~30% of patients)
        if np.random.random() < 0.30:
            scenario = np.random.random()
            if scenario < 0.05:  # 5% before study entry (invalid)
                mi_date = study_entry - timedelta(days=np.random.randint(1, 180))
            elif scenario < 0.10:  # 5% after study exit (invalid)
                mi_date = study_exit + timedelta(days=np.random.randint(1, 180))
            elif scenario < 0.15:  # 5% at study entry (boundary)
                mi_date = study_entry
            elif scenario < 0.20:  # 5% at study exit (boundary)
                mi_date = study_exit
            else:  # 80% during study
                mi_date = study_entry + timedelta(days=np.random.randint(1, study_duration))

            event_record['mi_date'] = mi_date.strftime('%Y-%m-%d')

        # Death event (~15% of patients)
        if np.random.random() < 0.15:
            scenario = np.random.random()
            if scenario < 0.05:  # 5% before study entry (invalid)
                death_date = study_entry - timedelta(days=np.random.randint(1, 180))
            elif scenario < 0.10:  # 5% after study exit (invalid)
                death_date = study_exit + timedelta(days=np.random.randint(1, 180))
            elif scenario < 0.15:  # 5% at study entry (boundary)
                death_date = study_entry
            elif scenario < 0.20:  # 5% at study exit (boundary)
                death_date = study_exit
            else:  # 80% during study
                death_date = study_entry + timedelta(days=np.random.randint(1, study_duration))

            event_record['death_date'] = death_date.strftime('%Y-%m-%d')

            # 20% chance of death on same date as MI (if MI exists)
            if 'mi_date' in event_record and np.random.random() < 0.20:
                event_record['death_date'] = event_record['mi_date']

        # Emigration event (~10% of patients)
        if np.random.random() < 0.10:
            scenario = np.random.random()
            if scenario < 0.05:  # 5% before study entry (invalid)
                emigration_date = study_entry - timedelta(days=np.random.randint(1, 180))
            elif scenario < 0.10:  # 5% after study exit (invalid)
                emigration_date = study_exit + timedelta(days=np.random.randint(1, 180))
            elif scenario < 0.15:  # 5% at study entry (boundary)
                emigration_date = study_entry
            elif scenario < 0.20:  # 5% at study exit (boundary)
                emigration_date = study_exit
            else:  # 80% during study
                emigration_date = study_entry + timedelta(days=np.random.randint(1, study_duration))

            event_record['emigration_date'] = emigration_date.strftime('%Y-%m-%d')

            # 10% chance of emigration on same date as other events
            if 'mi_date' in event_record and np.random.random() < 0.10:
                event_record['emigration_date'] = event_record['mi_date']
            elif 'death_date' in event_record and np.random.random() < 0.10:
                event_record['emigration_date'] = event_record['death_date']

        events.append(event_record)

    events_df = pd.DataFrame(events)

    return events_df


def print_summary_stats(df, name):
    """Print comprehensive summary statistics for a dataset."""
    print(f"\n{'='*80}")
    print(f"SUMMARY STATISTICS: {name}")
    print(f"{'='*80}")
    print(f"Total records: {len(df):,}")
    print(f"\nFirst 5 rows:")
    print(df.head())
    print(f"\nData types:")
    print(df.dtypes)
    print(f"\nBasic statistics:")
    print(df.describe(include='all'))

    if name.startswith("Exposure"):
        # Additional exposure-specific stats
        print(f"\n{'-'*80}")
        print("EXPOSURE-SPECIFIC STATISTICS")
        print(f"{'-'*80}")
        print(f"Unique patients with exposures: {df['patient_id'].nunique():,}")
        print(f"Average exposures per patient: {len(df) / df['patient_id'].nunique():.2f}")

        # Duration statistics
        df_temp = df.copy()
        df_temp['duration'] = (pd.to_datetime(df_temp['exp_stop']) -
                               pd.to_datetime(df_temp['exp_start'])).dt.days
        print(f"\nDuration statistics (days):")
        print(f"  Mean: {df_temp['duration'].mean():.2f}")
        print(f"  Median: {df_temp['duration'].median():.2f}")
        print(f"  Min: {df_temp['duration'].min()}")
        print(f"  Max: {df_temp['duration'].max()}")
        print(f"\nDuration categories:")
        print(f"  Zero-duration exposures: {(df_temp['duration'] == 0).sum():,} "
              f"({(df_temp['duration'] == 0).sum() / len(df_temp) * 100:.1f}%)")
        print(f"  Very short (1-3 days): {((df_temp['duration'] >= 1) & (df_temp['duration'] <= 3)).sum():,}")
        print(f"  Short (4-14 days): {((df_temp['duration'] >= 4) & (df_temp['duration'] <= 14)).sum():,}")
        print(f"  Medium (15-180 days): {((df_temp['duration'] >= 15) & (df_temp['duration'] <= 180)).sum():,}")
        print(f"  Long (181-730 days): {((df_temp['duration'] >= 181) & (df_temp['duration'] <= 730)).sum():,}")
        print(f"  Very long (>730 days): {(df_temp['duration'] > 730).sum():,}")

        print(f"\nDrug type distribution:")
        print(df['drug_type'].value_counts().sort_index())

        # Check for overlaps (same patient, overlapping periods)
        overlaps = 0
        adjacent = 0
        for patient_id in df['patient_id'].unique():
            patient_exps = df[df['patient_id'] == patient_id].sort_values('exp_start')
            for i in range(len(patient_exps) - 1):
                exp1 = patient_exps.iloc[i]
                exp2 = patient_exps.iloc[i + 1]
                exp1_stop = pd.to_datetime(exp1['exp_stop'])
                exp2_start = pd.to_datetime(exp2['exp_start'])

                if exp2_start < exp1_stop:
                    overlaps += 1
                elif exp2_start == exp1_stop:
                    adjacent += 1

        print(f"\nTemporal patterns:")
        print(f"  Overlapping exposure pairs: {overlaps:,}")
        print(f"  Adjacent exposure pairs (end = next start): {adjacent:,}")

    elif name.startswith("Events"):
        # Event-specific stats
        print(f"\n{'-'*80}")
        print("EVENT-SPECIFIC STATISTICS")
        print(f"{'-'*80}")

        for col in ['mi_date', 'death_date', 'emigration_date']:
            if col in df.columns:
                n_events = df[col].notna().sum()
                pct_events = n_events / len(df) * 100
                print(f"{col}: {n_events:,} ({pct_events:.1f}%)")

        # Patients with multiple events
        event_cols = [col for col in ['mi_date', 'death_date', 'emigration_date'] if col in df.columns]
        n_events = df[event_cols].notna().sum(axis=1)
        print(f"\nNumber of events per patient:")
        print(f"  0 events: {(n_events == 0).sum():,}")
        print(f"  1 event: {(n_events == 1).sum():,}")
        print(f"  2 events: {(n_events == 2).sum():,}")
        print(f"  3 events: {(n_events == 3).sum():,}")

        # Same-date events
        print(f"\nSame-date event occurrences:")
        if 'mi_date' in df.columns and 'death_date' in df.columns:
            same_date_mi_death = (df['mi_date'] == df['death_date']).sum()
            print(f"  MI and death on same date: {same_date_mi_death:,}")
        if 'mi_date' in df.columns and 'emigration_date' in df.columns:
            same_date_mi_emig = (df['mi_date'] == df['emigration_date']).sum()
            print(f"  MI and emigration on same date: {same_date_mi_emig:,}")
        if 'death_date' in df.columns and 'emigration_date' in df.columns:
            same_date_death_emig = (df['death_date'] == df['emigration_date']).sum()
            print(f"  Death and emigration on same date: {same_date_death_emig:,}")

    elif name == "Cohort":
        # Cohort-specific stats
        print(f"\n{'-'*80}")
        print("COHORT-SPECIFIC STATISTICS")
        print(f"{'-'*80}")
        print(f"\nAge range: {df['age'].min()} - {df['age'].max()}")
        print(f"Age mean: {df['age'].mean():.2f}")
        print(f"\nSex distribution:")
        print(df['sex'].value_counts())

        # Study duration
        df_temp = df.copy()
        df_temp['study_duration'] = (df_temp['study_exit'] - df_temp['study_entry']).dt.days
        print(f"\nStudy duration (days):")
        print(f"  Mean: {df_temp['study_duration'].mean():.2f}")
        print(f"  Median: {df_temp['study_duration'].median():.2f}")
        print(f"  Min: {df_temp['study_duration'].min()}")
        print(f"  Max: {df_temp['study_duration'].max()}")

        print(f"\nStudy entry date range:")
        print(f"  Min: {df['study_entry'].min()}")
        print(f"  Max: {df['study_entry'].max()}")

        print(f"\nStudy exit date range:")
        print(f"  Min: {df['study_exit'].min()}")
        print(f"  Max: {df['study_exit'].max()}")


def main():
    """Main function to generate all datasets."""
    print("="*80)
    print("COMPREHENSIVE TEST DATA GENERATOR FOR TVTOOLS REIMPLEMENTATIONS")
    print("="*80)
    print("Seed: 42 (deterministic)")
    print("="*80)

    output_dir = "/home/user/Stata-Tools/Reimplementations/Testing"

    # Generate cohort
    cohort = generate_cohort(n_patients=1000)
    print_summary_stats(cohort, "Cohort")

    # Save cohort
    cohort_path = f"{output_dir}/stress_cohort.csv"
    cohort.to_csv(cohort_path, index=False)
    print(f"\n✓ Saved to: {cohort_path}")

    # Generate first exposure dataset
    exposures1 = generate_exposures(cohort, n_exposures=5000, dataset_num=1)
    print_summary_stats(exposures1, "Exposure Dataset 1")

    # Save exposures1
    exp1_path = f"{output_dir}/stress_exposures.csv"
    exposures1.to_csv(exp1_path, index=False)
    print(f"\n✓ Saved to: {exp1_path}")

    # Generate second exposure dataset
    exposures2 = generate_exposures(cohort, n_exposures=3000, dataset_num=2)
    print_summary_stats(exposures2, "Exposure Dataset 2")

    # Save exposures2
    exp2_path = f"{output_dir}/stress_exposures2.csv"
    exposures2.to_csv(exp2_path, index=False)
    print(f"\n✓ Saved to: {exp2_path}")

    # Generate events
    events = generate_events(cohort)
    print_summary_stats(events, "Events Dataset")

    # Save events
    events_path = f"{output_dir}/stress_events.csv"
    events.to_csv(events_path, index=False)
    print(f"\n✓ Saved to: {events_path}")

    print("\n" + "="*80)
    print("DATA GENERATION COMPLETE!")
    print("="*80)
    print(f"\nGenerated files:")
    print(f"  1. {cohort_path}")
    print(f"  2. {exp1_path}")
    print(f"  3. {exp2_path}")
    print(f"  4. {events_path}")
    print("\nAll datasets are ready for testing tvtools reimplementations.")
    print("="*80)


if __name__ == "__main__":
    main()
