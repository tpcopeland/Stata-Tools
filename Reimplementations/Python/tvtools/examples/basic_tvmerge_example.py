"""
Basic TVMerge Example
=====================

This example demonstrates basic usage of the TVMerge module to merge
multiple time-varying exposure datasets.

We will:
1. Generate two synthetic time-varying exposure datasets
2. Use TVMerge to create all combinations of overlapping exposures
3. Display results showing combined exposure patterns
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta


def generate_tv_dataset(n_persons=30, exposure_name='exp1', values=[0, 1, 2]):
    """Generate a single time-varying exposure dataset."""
    np.random.seed(42 + hash(exposure_name) % 1000)

    intervals_list = []

    for person_id in range(1, n_persons + 1):
        entry_date = datetime(2020, 1, 1)
        exit_date = entry_date + timedelta(days=730)  # 2 years

        current_date = entry_date

        # Create 3-5 intervals per person
        n_intervals = np.random.randint(3, 6)

        for i in range(n_intervals):
            # Interval duration: 60-180 days
            duration = np.random.randint(60, 181)
            stop_date = current_date + timedelta(days=duration)

            if stop_date > exit_date:
                stop_date = exit_date

            # Random exposure value
            exposure = np.random.choice(values)

            intervals_list.append({
                'id': person_id,
                'start': current_date,
                'stop': stop_date,
                'tv_exposure': exposure,
                'extra_var': np.random.randint(10, 100)  # Additional variable
            })

            current_date = stop_date

            if current_date >= exit_date:
                break

    return pd.DataFrame(intervals_list)


def main():
    """Main example workflow."""

    print("="*60)
    print("Basic TVMerge Example")
    print("="*60)
    print()

    # Step 1: Generate two time-varying datasets
    print("Step 1: Generating synthetic time-varying datasets...")

    # Dataset 1: HRT exposure (0=none, 1=estrogen, 2=combined)
    tv_hrt = generate_tv_dataset(n_persons=30, exposure_name='hrt', values=[0, 1, 2])
    print(f"  Dataset 1 (HRT): {len(tv_hrt):,} intervals")

    # Dataset 2: DMT exposure (0=none, 1=aspirin, 2=statin)
    tv_dmt = generate_tv_dataset(n_persons=30, exposure_name='dmt', values=[0, 1, 2])
    print(f"  Dataset 2 (DMT): {len(tv_dmt):,} intervals")
    print()

    # Display sample data
    print("Sample HRT data:")
    print(tv_hrt.head(10))
    print()

    print("Sample DMT data:")
    print(tv_dmt.head(10))
    print()

    # Step 2: Create TVMerge object
    print("Step 2: Merging time-varying datasets...")

    from tvtools.tvmerge import TVMerge

    merger = TVMerge(
        datasets=[tv_hrt, tv_dmt],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['tv_exposure', 'tv_exposure'],
        output_names=['hrt', 'dmt'],
        start_name='start',
        stop_name='stop',
        keep_cols=['extra_var'],  # Keep additional variables
        batch_pct=50,  # Process 50% of IDs per batch
        strict_ids=True
    )

    # Perform the merge
    merged_df = merger.merge()

    print()

    # Step 3: Examine results
    print("Step 3: Results summary")
    print("-"*60)

    metadata = merger.metadata
    print(f"  Total intervals: {metadata.n_observations:,}")
    print(f"  Persons: {metadata.n_persons:,}")
    print(f"  Average intervals per person: {metadata.mean_periods:.1f}")
    print(f"  Max intervals per person: {metadata.max_periods}")
    print(f"  Exposure variables: {', '.join(metadata.exposure_vars)}")
    print()

    # Display sample merged data
    print("Sample merged data (first 15 rows):")
    display_cols = ['id', 'start', 'stop', 'hrt', 'dmt', 'extra_var_ds1', 'extra_var_ds2']
    print(merged_df[display_cols].head(15))
    print()

    # Show complete trajectory for one person
    print("Complete merged trajectory for person 1:")
    person_1 = merged_df[merged_df['id'] == 1]
    print(person_1[display_cols])
    print()

    # Exposure combination patterns
    print("Exposure combination patterns:")
    combo_counts = merged_df.groupby(['hrt', 'dmt']).size().reset_index(name='n_intervals')
    combo_counts['percentage'] = combo_counts['n_intervals'] / len(merged_df) * 100

    # Add labels
    hrt_labels = {0: 'No HRT', 1: 'Estrogen', 2: 'Combined'}
    dmt_labels = {0: 'No DMT', 1: 'Aspirin', 2: 'Statin'}

    combo_counts['hrt_label'] = combo_counts['hrt'].map(hrt_labels)
    combo_counts['dmt_label'] = combo_counts['dmt'].map(dmt_labels)

    print(combo_counts[['hrt_label', 'dmt_label', 'n_intervals', 'percentage']].to_string(index=False))
    print()

    # Calculate person-time by combination
    merged_df['duration'] = (merged_df['stop'] - merged_df['start']).dt.days + 1

    print("Person-time (days) by exposure combination:")
    time_by_combo = merged_df.groupby(['hrt', 'dmt'])['duration'].sum().reset_index()
    time_by_combo['hrt_label'] = time_by_combo['hrt'].map(hrt_labels)
    time_by_combo['dmt_label'] = time_by_combo['dmt'].map(dmt_labels)
    time_by_combo['percentage'] = time_by_combo['duration'] / time_by_combo['duration'].sum() * 100

    print(time_by_combo[['hrt_label', 'dmt_label', 'duration', 'percentage']].to_string(index=False))
    print()

    print("="*60)
    print("Example completed successfully!")
    print("="*60)

    return merged_df


if __name__ == "__main__":
    result = main()
