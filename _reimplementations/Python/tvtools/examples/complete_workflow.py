"""
Complete TVTools Workflow Example
==================================

This example demonstrates a complete workflow using all three modules:
1. TVExpose: Create time-varying exposures from prescription data
2. TVMerge: Merge multiple time-varying datasets
3. TVEvent: Integrate outcomes and competing risks

This represents a typical survival analysis workflow.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta


def generate_complete_dataset():
    """Generate a complete synthetic dataset for the workflow."""
    np.random.seed(123)

    # Create cohort
    cohort_list = []
    for person_id in range(1, 101):
        entry = datetime(2020, 1, 1) + timedelta(days=np.random.randint(0, 90))
        followup = np.random.randint(365, 900)
        exit = entry + timedelta(days=followup)

        cohort_list.append({
            'id': person_id,
            'entry_date': entry,
            'exit_date': exit,
            'age': np.random.randint(50, 85),
            'sex': np.random.choice(['M', 'F']),
            'baseline_risk': np.random.uniform(0.1, 0.5)
        })

    cohort_df = pd.DataFrame(cohort_list)

    # Create HRT prescriptions
    hrt_list = []
    for person_id in range(1, 101):
        person = cohort_df[cohort_df['id'] == person_id].iloc[0]
        current = person['entry_date']
        exit = person['exit_date']

        n_rx = np.random.randint(2, 5)
        for i in range(n_rx):
            duration = np.random.randint(60, 180)
            stop = current + timedelta(days=duration)
            if stop > exit:
                stop = exit

            hrt_type = np.random.choice([1, 2], p=[0.7, 0.3])

            hrt_list.append({
                'id': person_id,
                'rx_start': current,
                'rx_stop': stop,
                'hrt_type': hrt_type
            })

            gap = np.random.randint(0, 90)
            current = stop + timedelta(days=gap)

            if current >= exit:
                break

    hrt_df = pd.DataFrame(hrt_list)

    # Create statin prescriptions
    statin_list = []
    for person_id in range(1, 101):
        person = cohort_df[cohort_df['id'] == person_id].iloc[0]
        current = person['entry_date'] + timedelta(days=np.random.randint(0, 180))
        exit = person['exit_date']

        n_rx = np.random.randint(1, 4)
        for i in range(n_rx):
            duration = np.random.randint(90, 240)
            stop = current + timedelta(days=duration)
            if stop > exit:
                stop = exit

            statin_dose = np.random.choice([10, 20, 40])

            statin_list.append({
                'id': person_id,
                'statin_start': current,
                'statin_stop': stop,
                'dose_mg': statin_dose
            })

            gap = np.random.randint(0, 60)
            current = stop + timedelta(days=gap)

            if current >= exit:
                break

    statin_df = pd.DataFrame(statin_list)

    # Create events
    events_list = []
    for person_id in range(1, 101):
        person = cohort_df[cohort_df['id'] == person_id].iloc[0]
        entry = person['entry_date']
        exit = person['exit_date']

        event_prob = np.random.random()

        mi_date = None
        death_date = None

        if event_prob < 0.25:  # 25% MI
            days_to_event = np.random.randint(0, (exit - entry).days)
            mi_date = entry + timedelta(days=days_to_event)
        elif event_prob < 0.35:  # 10% death
            days_to_event = np.random.randint(0, (exit - entry).days)
            death_date = entry + timedelta(days=days_to_event)
        # else: 65% censored

        events_list.append({
            'id': person_id,
            'mi_date': mi_date,
            'death_date': death_date
        })

    events_df = pd.DataFrame(events_list)

    return cohort_df, hrt_df, statin_df, events_df


def main():
    """Main workflow."""

    print("="*70)
    print(" Complete TVTools Workflow Example")
    print("="*70)
    print()
    print("This example demonstrates:")
    print("  1. TVExpose: Create time-varying exposures")
    print("  2. TVMerge: Merge multiple exposure datasets")
    print("  3. TVEvent: Integrate outcomes and competing risks")
    print()
    print("="*70)
    print()

    # Generate data
    print("Generating synthetic cohort and exposure data...")
    cohort_df, hrt_df, statin_df, events_df = generate_complete_dataset()

    print(f"  Cohort: {len(cohort_df)} persons")
    print(f"  HRT prescriptions: {len(hrt_df)} periods")
    print(f"  Statin prescriptions: {len(statin_df)} periods")
    print(f"  Events: {events_df['mi_date'].notna().sum()} MIs, {events_df['death_date'].notna().sum()} deaths")
    print()

    # STEP 1: Create time-varying HRT exposure
    print("-"*70)
    print("STEP 1: Creating time-varying HRT exposure")
    print("-"*70)

    from tvtools.tvexpose import TVExpose

    tv_hrt = TVExpose(
        exposure_data=hrt_df,
        master_data=cohort_df,
        id_col='id',
        start_col='rx_start',
        stop_col='rx_stop',
        exposure_col='hrt_type',
        reference=0,
        entry_col='entry_date',
        exit_col='exit_date',
        output_col='hrt',
        grace=30,  # Bridge gaps <= 30 days
        keep_cols=['age', 'sex', 'baseline_risk']
    )

    result_hrt = tv_hrt.run()

    print(f"  Created {result_hrt.n_periods:,} HRT intervals")
    print(f"  {result_hrt.pct_exposed:.1f}% of time exposed")
    print()

    # STEP 2: Create time-varying statin exposure
    print("-"*70)
    print("STEP 2: Creating time-varying statin exposure")
    print("-"*70)

    tv_statin = TVExpose(
        exposure_data=statin_df,
        master_data=cohort_df,
        id_col='id',
        start_col='statin_start',
        stop_col='statin_stop',
        exposure_col='dose_mg',
        reference=0,
        entry_col='entry_date',
        exit_col='exit_date',
        output_col='statin_dose',
        grace=30
    )

    result_statin = tv_statin.run()

    print(f"  Created {result_statin.n_periods:,} statin intervals")
    print(f"  {result_statin.pct_exposed:.1f}% of time exposed")
    print()

    # STEP 3: Merge HRT and statin exposures
    print("-"*70)
    print("STEP 3: Merging HRT and statin exposures")
    print("-"*70)

    from tvtools.tvmerge import TVMerge

    merger = TVMerge(
        datasets=[result_hrt.data, result_statin.data],
        id_col='id',
        start_cols=['exp_start', 'exp_start'],
        stop_cols=['exp_stop', 'exp_stop'],
        exposure_cols=['hrt', 'statin_dose'],
        output_names=['hrt', 'statin'],
        start_name='start',
        stop_name='stop',
        keep_cols=['age', 'sex', 'baseline_risk'],
        batch_pct=50
    )

    merged_df = merger.merge()

    print()

    # STEP 4: Integrate events
    print("-"*70)
    print("STEP 4: Integrating MI events and death (competing risk)")
    print("-"*70)

    from tvtools.tvevent import TVEvent

    tv_event = TVEvent(
        intervals_data=merged_df,
        events_data=events_df,
        id_col='id',
        date_col='mi_date',
        compete_cols=['death_date'],
        event_type='single',
        output_col='event',
        time_col='time_years',
        time_unit='years'
    )

    final_result = tv_event.process()

    print(f"  Final dataset: {final_result.n_total:,} intervals")
    print(f"  Events flagged: {final_result.n_events:,}")
    print(f"  Intervals split: {final_result.n_splits:,}")
    print()

    # STEP 5: Analyze results
    print("="*70)
    print(" FINAL RESULTS")
    print("="*70)
    print()

    # Event status distribution
    print("Event status distribution:")
    for status in sorted(final_result.data['event'].unique()):
        label = final_result.event_labels[status]
        count = (final_result.data['event'] == status).sum()
        pct = count / len(final_result.data) * 100
        print(f"  {label}: {count:,} intervals ({pct:.1f}%)")

    print()

    # Exposure combinations
    print("Exposure combinations in final dataset:")
    combo_counts = final_result.data.groupby(['hrt', 'statin']).size().reset_index(name='n_intervals')
    combo_counts['pct'] = combo_counts['n_intervals'] / len(final_result.data) * 100

    hrt_labels = {0: 'No HRT', 1: 'Estrogen', 2: 'Combined'}
    combo_counts['hrt_label'] = combo_counts['hrt'].map(hrt_labels).fillna('Unknown')

    print(combo_counts[['hrt_label', 'statin', 'n_intervals', 'pct']].to_string(index=False))
    print()

    # Sample of final dataset
    print("Sample of final analysis-ready dataset:")
    display_cols = ['id', 'start', 'stop', 'hrt', 'statin', 'event', 'time_years', 'age', 'sex']
    available_cols = [col for col in display_cols if col in final_result.data.columns]
    print(final_result.data[available_cols].head(20))
    print()

    # Person-level summary
    print("Person-level event summary:")
    person_events = final_result.data[final_result.data['event'] > 0].groupby('id')['event'].max()
    event_counts = person_events.value_counts().sort_index()

    for status, count in event_counts.items():
        label = final_result.event_labels[status]
        print(f"  {label}: {count} persons")

    print()

    # Total person-time
    total_time = final_result.data['time_years'].sum()
    print(f"Total person-years of follow-up: {total_time:,.1f}")
    print()

    print("="*70)
    print(" Workflow completed successfully!")
    print(" Dataset is ready for Cox proportional hazards or other survival analysis")
    print("="*70)

    return final_result


if __name__ == "__main__":
    result = main()
