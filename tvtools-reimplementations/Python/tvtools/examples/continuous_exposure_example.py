"""
Continuous Exposure Example with TVMerge
=========================================

This example demonstrates handling continuous (dose/rate) exposures with TVMerge.

When merging datasets with continuous exposures:
- Values represent rates per day (e.g., mg/day)
- When intervals overlap, values are prorated based on overlap duration
- Output includes both rate and total amount for the period
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta


def generate_continuous_exposure_data():
    """Generate time-varying datasets with continuous exposures."""
    np.random.seed(456)

    # Dataset 1: Categorical exposure (treatment type)
    treatment_list = []
    for person_id in range(1, 51):
        entry = datetime(2020, 1, 1)
        current = entry

        n_periods = np.random.randint(3, 6)

        for i in range(n_periods):
            duration = np.random.randint(60, 150)
            stop = current + timedelta(days=duration)

            treatment = np.random.choice([0, 1, 2])  # 0=none, 1=A, 2=B

            treatment_list.append({
                'id': person_id,
                'start': current,
                'stop': stop,
                'treatment_type': treatment
            })

            current = stop

    treatment_df = pd.DataFrame(treatment_list)

    # Dataset 2: Continuous exposure (daily dose in mg)
    dose_list = []
    for person_id in range(1, 51):
        entry = datetime(2020, 1, 1)
        current = entry

        n_periods = np.random.randint(2, 5)

        for i in range(n_periods):
            duration = np.random.randint(80, 200)
            stop = current + timedelta(days=duration)

            # Daily dose: 0-100 mg/day
            dose = np.random.choice([0, 10, 20, 40, 80])

            dose_list.append({
                'id': person_id,
                'start': current,
                'stop': stop,
                'daily_dose_mg': dose
            })

            current = stop

    dose_df = pd.DataFrame(dose_list)

    # Dataset 3: Another continuous exposure (cumulative exposure in mg)
    # This will be converted to rate per day
    cumulative_list = []
    for person_id in range(1, 51):
        entry = datetime(2020, 1, 1)
        current = entry

        n_periods = np.random.randint(2, 4)

        for i in range(n_periods):
            duration = np.random.randint(90, 180)
            stop = current + timedelta(days=duration)

            # Total cumulative dose for this period
            total_mg = np.random.randint(0, 5000)

            cumulative_list.append({
                'id': person_id,
                'start': current,
                'stop': stop,
                'total_exposure_mg': total_mg
            })

            current = stop

    cumulative_df = pd.DataFrame(cumulative_list)

    # Convert cumulative to rate (mg per day)
    cumulative_df['duration_days'] = (cumulative_df['stop'] - cumulative_df['start']).dt.days
    cumulative_df['rate_per_day'] = cumulative_df['total_exposure_mg'] / cumulative_df['duration_days']
    cumulative_df = cumulative_df.drop(columns=['total_exposure_mg', 'duration_days'])

    return treatment_df, dose_df, cumulative_df


def main():
    """Main example workflow."""

    print("="*70)
    print(" Continuous Exposure Example with TVMerge")
    print("="*70)
    print()

    # Generate data
    print("Generating datasets...")
    treatment_df, dose_df, cumulative_df = generate_continuous_exposure_data()

    print(f"  Treatment (categorical): {len(treatment_df):,} intervals")
    print(f"  Dose (continuous): {len(dose_df):,} intervals")
    print(f"  Cumulative rate (continuous): {len(cumulative_df):,} intervals")
    print()

    # Show sample data
    print("Sample treatment data (categorical):")
    print(treatment_df.head())
    print()

    print("Sample dose data (continuous mg/day):")
    print(dose_df.head())
    print()

    print("Sample cumulative rate data (continuous mg/day):")
    print(cumulative_df.head())
    print()

    # Merge without continuous handling (INCORRECT for dose data)
    print("-"*70)
    print("Example 1: Merge WITHOUT continuous handling (incorrect)")
    print("-"*70)

    from tvtools.tvmerge import TVMerge

    merger_wrong = TVMerge(
        datasets=[treatment_df, dose_df],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['treatment_type', 'daily_dose_mg'],
        output_names=['treatment', 'dose'],
        # NOT specifying continuous - this is WRONG for dose data!
    )

    merged_wrong = merger_wrong.merge()

    print("\nSample output (INCORRECT - dose not prorated):")
    sample_person = merged_wrong[merged_wrong['id'] == 1].head(5)
    sample_person['duration'] = (sample_person['stop'] - sample_person['start']).dt.days
    print(sample_person[['id', 'start', 'stop', 'duration', 'treatment', 'dose']])
    print("\nProblem: Dose values are not adjusted for partial overlap!")
    print()

    # Merge WITH continuous handling (CORRECT)
    print("-"*70)
    print("Example 2: Merge WITH continuous handling (correct)")
    print("-"*70)

    merger_correct = TVMerge(
        datasets=[treatment_df, dose_df],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['treatment_type', 'daily_dose_mg'],
        output_names=['treatment', 'dose'],
        continuous=['dose'],  # Specify dose as continuous
    )

    merged_correct = merger_correct.merge()

    print("\nSample output (CORRECT - dose prorated):")
    sample_person = merged_correct[merged_correct['id'] == 1].head(5)
    sample_person['duration'] = (sample_person['stop'] - sample_person['start']).dt.days
    display_cols = ['id', 'start', 'stop', 'duration', 'treatment', 'dose', 'dose_period']
    available = [c for c in display_cols if c in sample_person.columns]
    print(sample_person[available])
    print()
    print("Notice:")
    print("  - 'dose' column: mg/day rate (unchanged)")
    print("  - 'dose_period' column: total mg for this specific interval")
    print()

    # Merge three datasets with multiple continuous
    print("-"*70)
    print("Example 3: Merge three datasets with multiple continuous exposures")
    print("-"*70)

    merger_three = TVMerge(
        datasets=[treatment_df, dose_df, cumulative_df],
        id_col='id',
        start_cols=['start', 'start', 'start'],
        stop_cols=['stop', 'stop', 'stop'],
        exposure_cols=['treatment_type', 'daily_dose_mg', 'rate_per_day'],
        output_names=['treatment', 'dose', 'cumulative_rate'],
        continuous=['dose', 'cumulative_rate'],  # Both are continuous
    )

    merged_three = merger_three.merge()

    print("\nMetadata:")
    print(f"  Total intervals: {merger_three.metadata.n_observations:,}")
    print(f"  Continuous variables: {', '.join(merger_three.metadata.continuous_vars)}")
    print(f"  Categorical variables: {', '.join(merger_three.metadata.categorical_vars)}")
    print()

    print("Sample output with multiple continuous exposures:")
    sample = merged_three[merged_three['id'] == 1].head(8)
    sample['duration'] = (sample['stop'] - sample['start']).dt.days
    display_cols = ['id', 'start', 'stop', 'duration', 'treatment',
                   'dose', 'dose_period', 'cumulative_rate', 'cumulative_rate_period']
    available = [c for c in display_cols if c in sample.columns]
    print(sample[available])
    print()

    # Calculate summary statistics
    print("-"*70)
    print("Summary statistics for continuous exposures")
    print("-"*70)
    print()

    # Calculate total exposure per person
    if 'dose_period' in merged_three.columns:
        person_totals = merged_three.groupby('id').agg({
            'dose_period': 'sum',
            'cumulative_rate_period': 'sum'
        }).rename(columns={
            'dose_period': 'total_dose_mg',
            'cumulative_rate_period': 'total_cumulative_mg'
        })

        print("Per-person total exposures:")
        print(person_totals.describe())
        print()

        print("First 10 persons:")
        print(person_totals.head(10))
        print()

    # Dose distribution by treatment type
    print("Average daily dose by treatment type:")
    dose_by_treatment = merged_three.groupby('treatment')['dose'].agg(['mean', 'std', 'count'])
    print(dose_by_treatment)
    print()

    # Person-time by exposure combination
    merged_three['person_days'] = (merged_three['stop'] - merged_three['start']).dt.days
    print("Person-days by treatment and dose category:")

    # Categorize dose
    merged_three['dose_cat'] = pd.cut(
        merged_three['dose'],
        bins=[-1, 0, 20, 40, 100],
        labels=['None', 'Low (1-20)', 'Med (21-40)', 'High (41+)']
    )

    pt_summary = merged_three.groupby(['treatment', 'dose_cat'])['person_days'].sum().reset_index()
    pt_summary['person_years'] = pt_summary['person_days'] / 365.25
    print(pt_summary)
    print()

    print("="*70)
    print(" Example completed successfully!")
    print()
    print(" Key takeaways:")
    print("  1. Always specify continuous=[] for dose/rate variables")
    print("  2. Continuous values are prorated for overlapping intervals")
    print("  3. Output includes both rate (var) and amount (var_period)")
    print("  4. Use var_period to calculate cumulative exposure per person")
    print("="*70)

    return merged_three


if __name__ == "__main__":
    result = main()
