"""
Ever-Treated Exposure Example with TVExpose
============================================

This example demonstrates creating ever-treated exposure variables,
where exposure status becomes 1 after first treatment and never reverts.

This is common in:
- New-user designs
- Intention-to-treat analyses
- Time-to-treatment studies
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta


def generate_treatment_data():
    """Generate prescription data for ever-treated analysis."""
    np.random.seed(789)

    # Cohort: 80 persons
    cohort_list = []
    for person_id in range(1, 81):
        entry = datetime(2019, 1, 1) + timedelta(days=np.random.randint(0, 90))
        exit = entry + timedelta(days=np.random.randint(500, 900))

        cohort_list.append({
            'id': person_id,
            'cohort_entry': entry,
            'cohort_exit': exit,
            'age': np.random.randint(40, 75),
            'baseline_score': np.random.randint(10, 50)
        })

    cohort_df = pd.DataFrame(cohort_list)

    # Prescriptions: some people never treated, some treated
    prescriptions_list = []

    for person_id in range(1, 81):
        person = cohort_df[cohort_df['id'] == person_id].iloc[0]

        # 70% get treated at some point
        if np.random.random() < 0.7:
            # Time to first treatment
            days_to_treatment = np.random.randint(30, 400)
            first_rx = person['cohort_entry'] + timedelta(days=days_to_treatment)

            # Make sure first rx is before exit
            if first_rx < person['cohort_exit']:
                current = first_rx

                # 2-4 prescription periods
                n_rx = np.random.randint(2, 5)

                for i in range(n_rx):
                    duration = np.random.randint(60, 180)
                    stop = current + timedelta(days=duration)

                    if stop > person['cohort_exit']:
                        stop = person['cohort_exit']

                    prescriptions_list.append({
                        'id': person_id,
                        'rx_start': current,
                        'rx_stop': stop,
                        'medication': 1  # Binary: treated or not
                    })

                    # Gap before next rx
                    gap = np.random.randint(0, 90)
                    current = stop + timedelta(days=gap)

                    if current >= person['cohort_exit']:
                        break

    prescriptions_df = pd.DataFrame(prescriptions_list)

    return cohort_df, prescriptions_df


def main():
    """Main example workflow."""

    print("="*70)
    print(" Ever-Treated Exposure Example")
    print("="*70)
    print()

    # Generate data
    print("Generating cohort and prescription data...")
    cohort_df, prescriptions_df = generate_treatment_data()

    n_treated = prescriptions_df['id'].nunique()
    n_never_treated = len(cohort_df) - n_treated

    print(f"  Cohort: {len(cohort_df)} persons")
    print(f"  Ever treated: {n_treated} persons")
    print(f"  Never treated: {n_never_treated} persons")
    print(f"  Prescription periods: {len(prescriptions_df):,}")
    print()

    # Show examples
    print("Example: Person who gets treated:")
    treated_person = prescriptions_df[prescriptions_df['id'] == 1]
    if len(treated_person) > 0:
        print(treated_person)
    print()

    print("Example: Person who never gets treated:")
    never_treated_id = cohort_df[~cohort_df['id'].isin(prescriptions_df['id'])]['id'].iloc[0]
    print(f"Person {never_treated_id}: No prescriptions in dataset")
    print(cohort_df[cohort_df['id'] == never_treated_id])
    print()

    # Method 1: Basic time-varying exposure
    print("-"*70)
    print("Method 1: Basic time-varying exposure (standard)")
    print("-"*70)

    from tvtools.tvexpose import TVExpose

    tv_standard = TVExpose(
        exposure_data=prescriptions_df,
        master_data=cohort_df,
        id_col='id',
        start_col='rx_start',
        stop_col='rx_stop',
        exposure_col='medication',
        reference=0,
        entry_col='cohort_entry',
        exit_col='cohort_exit',
        exposure_type='time_varying',  # Standard
        output_col='tv_exposure',
        keep_cols=['age', 'baseline_score']
    )

    result_standard = tv_standard.run()

    print(f"  Created {result_standard.n_periods:,} intervals")
    print()

    # Show person 1 (has prescriptions)
    person_1_standard = result_standard.data[result_standard.data['id'] == 1]
    print("Person 1 trajectory (time-varying):")
    print(person_1_standard[['id', 'exp_start', 'exp_stop', 'tv_exposure']])
    print()
    print("Notice: Exposure switches back to 0 (unexposed) during gaps")
    print()

    # Method 2: Ever-treated exposure
    print("-"*70)
    print("Method 2: Ever-treated exposure")
    print("-"*70)

    tv_ever = TVExpose(
        exposure_data=prescriptions_df,
        master_data=cohort_df,
        id_col='id',
        start_col='rx_start',
        stop_col='rx_stop',
        exposure_col='medication',
        reference=0,
        entry_col='cohort_entry',
        exit_col='cohort_exit',
        exposure_type='ever_treated',  # Ever-treated!
        output_col='ever_treated',
        keep_cols=['age', 'baseline_score']
    )

    result_ever = tv_ever.run()

    print(f"  Created {result_ever.n_periods:,} intervals")
    print()

    # Show person 1 with ever-treated
    person_1_ever = result_ever.data[result_ever.data['id'] == 1]
    print("Person 1 trajectory (ever-treated):")
    print(person_1_ever[['id', 'exp_start', 'exp_stop', 'ever_treated']])
    print()
    print("Notice: Once exposed, status stays at 1 (never reverts to 0)")
    print()

    # Method 3: Ever-treated with grace period
    print("-"*70)
    print("Method 3: Ever-treated with grace period")
    print("-"*70)
    print("Grace period bridges small gaps before first exposure")
    print()

    tv_ever_grace = TVExpose(
        exposure_data=prescriptions_df,
        master_data=cohort_df,
        id_col='id',
        start_col='rx_start',
        stop_col='rx_stop',
        exposure_col='medication',
        reference=0,
        entry_col='cohort_entry',
        exit_col='cohort_exit',
        exposure_type='ever_treated',
        grace=60,  # Bridge gaps <= 60 days
        output_col='ever_treated',
        keep_cols=['age', 'baseline_score']
    )

    result_ever_grace = tv_ever_grace.run()

    print(f"  Created {result_ever_grace.n_periods:,} intervals")
    print()

    # Compare results
    print("-"*70)
    print("Comparison of methods")
    print("-"*70)
    print()

    # Count intervals per person
    print("Average intervals per person:")
    print(f"  Time-varying: {result_standard.n_periods / result_standard.n_persons:.1f}")
    print(f"  Ever-treated: {result_ever.n_periods / result_ever.n_persons:.1f}")
    print(f"  Ever-treated (grace=60): {result_ever_grace.n_periods / result_ever_grace.n_persons:.1f}")
    print()

    print("Exposure distribution (intervals):")
    print()

    print("Time-varying:")
    print(result_standard.data['tv_exposure'].value_counts().sort_index())
    print()

    print("Ever-treated:")
    print(result_ever.data['ever_treated'].value_counts().sort_index())
    print()

    # Time to treatment analysis
    print("-"*70)
    print("Time-to-treatment analysis using ever-treated data")
    print("-"*70)
    print()

    # Find first treated interval per person
    treated_intervals = result_ever.data[result_ever.data['ever_treated'] == 1]
    first_treatment = treated_intervals.groupby('id')['exp_start'].min().reset_index()
    first_treatment.columns = ['id', 'treatment_date']

    # Merge with cohort entry
    first_treatment = first_treatment.merge(
        cohort_df[['id', 'cohort_entry']],
        on='id'
    )

    first_treatment['days_to_treatment'] = (
        first_treatment['treatment_date'] - first_treatment['cohort_entry']
    ).dt.days

    print("Time to treatment statistics:")
    print(first_treatment['days_to_treatment'].describe())
    print()

    print("First 10 persons - time to treatment:")
    print(first_treatment.head(10))
    print()

    # Never treated persons
    never_treated = cohort_df[~cohort_df['id'].isin(first_treatment['id'])]
    print(f"Never treated: {len(never_treated)} persons")
    print()

    # Application: Prepare for Cox model
    print("-"*70)
    print("Application: Preparing for time-to-event analysis")
    print("-"*70)
    print()

    print("The ever-treated dataset is ideal for:")
    print("  1. Cox models with time-varying treatment")
    print("  2. Intention-to-treat analyses")
    print("  3. Time-to-treatment studies")
    print()

    print("Sample data structure for Cox regression:")
    display_cols = ['id', 'exp_start', 'exp_stop', 'ever_treated', 'age', 'baseline_score']
    print(result_ever.data[display_cols].head(15))
    print()

    print("="*70)
    print(" Example completed successfully!")
    print()
    print(" Key difference:")
    print("  - Time-varying: Exposure can turn on/off")
    print("  - Ever-treated: Once exposed, always exposed")
    print("="*70)

    return result_ever


if __name__ == "__main__":
    result = main()
