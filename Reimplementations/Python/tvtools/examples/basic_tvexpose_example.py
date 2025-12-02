"""
Basic TVExpose Example
======================

This example demonstrates basic usage of the TVExpose module to create
time-varying exposure variables from prescription data.

We will:
1. Generate synthetic prescription and cohort data
2. Use TVExpose to create time-varying exposure intervals
3. Display results showing how exposures change over time
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta


def generate_synthetic_data():
    """Generate synthetic prescription and cohort data."""
    np.random.seed(42)

    # Create cohort data (master file)
    # 50 persons followed from 2020-2022
    cohort_list = []

    for person_id in range(1, 51):
        entry_date = datetime(2020, 1, 1) + timedelta(days=np.random.randint(0, 180))
        # Follow-up: 1-2 years
        followup_days = np.random.randint(365, 730)
        exit_date = entry_date + timedelta(days=followup_days)

        cohort_list.append({
            'patient_id': person_id,
            'study_entry': entry_date,
            'study_exit': exit_date,
            'age': np.random.randint(40, 80),
            'sex': np.random.choice(['M', 'F'])
        })

    cohort_df = pd.DataFrame(cohort_list)

    # Create prescription data (exposure file)
    # Each person has 2-6 prescription periods
    prescriptions_list = []

    for person_id in range(1, 51):
        person_cohort = cohort_df[cohort_df['patient_id'] == person_id].iloc[0]
        entry = person_cohort['study_entry']
        exit = person_cohort['study_exit']

        # Number of prescriptions
        n_rx = np.random.randint(2, 7)

        current_date = entry + timedelta(days=np.random.randint(0, 90))

        for i in range(n_rx):
            # Prescription duration: 30-180 days
            duration = np.random.randint(30, 181)
            rx_stop = current_date + timedelta(days=duration)

            # Make sure we don't go past study exit
            if rx_stop > exit:
                rx_stop = exit

            # Drug type: 0=none, 1=drug A, 2=drug B
            drug = np.random.choice([1, 2], p=[0.6, 0.4])

            prescriptions_list.append({
                'patient_id': person_id,
                'rx_start': current_date,
                'rx_stop': rx_stop,
                'drug_type': drug
            })

            # Gap before next prescription: 0-60 days
            gap = np.random.randint(0, 61)
            current_date = rx_stop + timedelta(days=gap)

            # Stop if we've reached study exit
            if current_date >= exit:
                break

    prescriptions_df = pd.DataFrame(prescriptions_list)

    return cohort_df, prescriptions_df


def main():
    """Main example workflow."""

    print("="*60)
    print("Basic TVExpose Example")
    print("="*60)
    print()

    # Step 1: Generate synthetic data
    print("Step 1: Generating synthetic data...")
    cohort_df, prescriptions_df = generate_synthetic_data()

    print(f"  Cohort: {len(cohort_df):,} persons")
    print(f"  Prescriptions: {len(prescriptions_df):,} prescription periods")
    print()

    # Display sample data
    print("Sample cohort data:")
    print(cohort_df.head())
    print()

    print("Sample prescription data:")
    print(prescriptions_df.head(10))
    print()

    # Step 2: Create TVExpose object
    print("Step 2: Creating time-varying exposure intervals...")

    from tvtools.tvexpose import TVExpose

    # Basic time-varying exposure
    tv = TVExpose(
        exposure_data=prescriptions_df,
        master_data=cohort_df,
        id_col='patient_id',
        start_col='rx_start',
        stop_col='rx_stop',
        exposure_col='drug_type',
        reference=0,  # 0 = unexposed
        entry_col='study_entry',
        exit_col='study_exit',
        output_col='tv_exposure',
        keep_cols=['age', 'sex'],
        keep_dates=False
    )

    # Run the transformation
    result = tv.run()

    print(f"  Created {result.n_periods:,} time-varying intervals")
    print(f"  Covering {result.n_persons:,} persons")
    print()

    # Step 3: Examine results
    print("Step 3: Results summary")
    print("-"*60)
    print(f"  Total person-time: {result.total_time:,.0f} days")
    print(f"  Exposed time: {result.exposed_time:,.0f} days ({result.pct_exposed:.1f}%)")
    print(f"  Unexposed time: {result.unexposed_time:,.0f} days ({100-result.pct_exposed:.1f}%)")
    print()

    # Exposure distribution
    print("Exposure value distribution:")
    exp_counts = result.data['tv_exposure'].value_counts().sort_index()
    for exp_val, count in exp_counts.items():
        pct = count / len(result.data) * 100
        label = "Unexposed" if exp_val == 0 else f"Drug {exp_val}"
        print(f"  {label}: {count:,} intervals ({pct:.1f}%)")

    print()

    # Display sample results
    print("Sample time-varying intervals (first 15 rows):")
    display_cols = ['patient_id', 'exp_start', 'exp_stop', 'tv_exposure', 'age', 'sex']
    print(result.data[display_cols].head(15))
    print()

    # Show one person's complete trajectory
    print("Complete exposure trajectory for person 1:")
    person_1 = result.data[result.data['patient_id'] == 1]
    print(person_1[display_cols])
    print()

    # Calculate duration for each interval
    result.data['duration_days'] = (
        result.data['exp_stop'] - result.data['exp_start']
    ).dt.days + 1

    print("Summary statistics by exposure:")
    print(result.data.groupby('tv_exposure')['duration_days'].describe())
    print()

    print("="*60)
    print("Example completed successfully!")
    print("="*60)

    return result


if __name__ == "__main__":
    result = main()
