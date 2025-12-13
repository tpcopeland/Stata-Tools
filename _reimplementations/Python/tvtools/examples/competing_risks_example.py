"""
Competing Risks Example with TVEvent
=====================================

This example demonstrates handling multiple competing risks with TVEvent.

We will model a cohort with three possible outcomes:
1. Primary outcome: Disease progression
2. Competing risk 1: Death
3. Competing risk 2: Loss to follow-up

The earliest event wins, and TVEvent flags which type occurred.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta


def generate_competing_risks_data():
    """Generate data with multiple competing events."""
    np.random.seed(999)

    # Create time-varying exposure intervals
    intervals_list = []
    for person_id in range(1, 201):
        entry = datetime(2018, 1, 1)
        current = entry

        # Each person has 2-4 intervals
        n_intervals = np.random.randint(2, 5)

        for i in range(n_intervals):
            duration = np.random.randint(90, 180)
            stop = current + timedelta(days=duration)

            # Treatment status
            treatment = np.random.choice([0, 1, 2])

            intervals_list.append({
                'patient_id': person_id,
                'start': current,
                'stop': stop,
                'treatment': treatment
            })

            current = stop

    intervals_df = pd.DataFrame(intervals_list)

    # Create events with multiple competing risks
    events_list = []

    for person_id in range(1, 201):
        person_intervals = intervals_df[intervals_df['patient_id'] == person_id]
        entry = person_intervals['start'].min()
        max_stop = person_intervals['stop'].max()

        # Simulate event occurrence based on probabilities
        rand = np.random.random()

        progression_date = None
        death_date = None
        ltfu_date = None

        if rand < 0.30:  # 30% progression
            days = np.random.randint(0, (max_stop - entry).days)
            progression_date = entry + timedelta(days=days)

        elif rand < 0.45:  # 15% death
            days = np.random.randint(0, (max_stop - entry).days)
            death_date = entry + timedelta(days=days)

        elif rand < 0.55:  # 10% loss to follow-up
            days = np.random.randint(0, (max_stop - entry).days)
            ltfu_date = entry + timedelta(days=days)

        # else: 45% censored

        events_list.append({
            'patient_id': person_id,
            'progression_date': progression_date,
            'death_date': death_date,
            'ltfu_date': ltfu_date,
            'baseline_severity': np.random.choice(['Low', 'Medium', 'High'])
        })

    events_df = pd.DataFrame(events_list)

    return intervals_df, events_df


def main():
    """Main example workflow."""

    print("="*70)
    print(" Competing Risks Example with TVEvent")
    print("="*70)
    print()

    # Generate data
    print("Generating data with multiple competing events...")
    intervals_df, events_df = generate_competing_risks_data()

    print(f"  Intervals: {len(intervals_df):,}")
    print(f"  Persons: {len(events_df):,}")
    print()

    # Count events by type
    print("Event counts in source data:")
    print(f"  Progression events: {events_df['progression_date'].notna().sum()}")
    print(f"  Death events: {events_df['death_date'].notna().sum()}")
    print(f"  Loss to follow-up: {events_df['ltfu_date'].notna().sum()}")
    print(f"  Censored: {(events_df[['progression_date', 'death_date', 'ltfu_date']].isna().all(axis=1)).sum()}")
    print()

    # Sample data
    print("Sample event data:")
    print(events_df.head(10))
    print()

    # Initialize TVEvent with competing risks
    print("Processing with TVEvent...")

    from tvtools.tvevent import TVEvent

    tv = TVEvent(
        intervals_data=intervals_df,
        events_data=events_df,
        id_col='patient_id',
        date_col='progression_date',  # Primary outcome
        compete_cols=['death_date', 'ltfu_date'],  # Competing risks
        event_type='single',
        output_col='outcome',
        time_col='followup_years',
        time_unit='years',
        keep_cols=['baseline_severity']
    )

    result = tv.process()

    print(f"  Processed {result.n_total:,} intervals")
    print(f"  Split {result.n_splits:,} intervals at event boundaries")
    print()

    # Analyze results
    print("="*70)
    print(" RESULTS")
    print("="*70)
    print()

    # Event labels
    print("Event type definitions:")
    for status, label in result.event_labels.items():
        print(f"  {status}: {label}")

    print()

    # Interval-level distribution
    print("Event status distribution (by interval):")
    status_counts = result.data['outcome'].value_counts().sort_index()

    for status in sorted(result.data['outcome'].unique()):
        label = result.event_labels[status]
        count = status_counts[status]
        pct = count / len(result.data) * 100
        print(f"  {label}: {count:,} intervals ({pct:.1f}%)")

    print()

    # Person-level distribution
    print("Event status distribution (by person):")
    person_status = result.data[result.data['outcome'] > 0].groupby('patient_id')['outcome'].first()
    person_counts = person_status.value_counts().sort_index()

    total_events = person_status.count()
    censored = len(events_df) - total_events

    print(f"  Censored: {censored} persons")

    for status in sorted(person_counts.index):
        label = result.event_labels[status]
        count = person_counts[status]
        pct = count / len(events_df) * 100
        print(f"  {label}: {count} persons ({pct:.1f}%)")

    print()

    # Cumulative incidence by competing event
    print("Cumulative person-years by outcome:")
    time_by_outcome = result.data.groupby('outcome')['followup_years'].sum()

    for status in sorted(time_by_outcome.index):
        label = result.event_labels[status]
        years = time_by_outcome[status]
        pct = years / time_by_outcome.sum() * 100
        print(f"  {label}: {years:,.1f} years ({pct:.1f}%)")

    print()

    # Sample results
    print("Sample of processed data:")
    display_cols = ['patient_id', 'start', 'stop', 'treatment', 'outcome',
                   'followup_years', 'baseline_severity']
    available_cols = [col for col in display_cols if col in result.data.columns]
    print(result.data[available_cols].head(20))
    print()

    # Show examples of each outcome type
    print("Examples of each outcome type:")
    for status in sorted(result.data['outcome'].unique()):
        label = result.event_labels[status]
        print(f"\n{label} (status={status}):")
        sample = result.data[result.data['outcome'] == status].head(3)
        print(sample[available_cols])

    print()

    # Treatment exposure by outcome
    print("Treatment exposure at time of event/censoring:")
    final_intervals = result.data.groupby('patient_id').last()
    outcome_treatment = pd.crosstab(
        final_intervals['outcome'].map(result.event_labels),
        final_intervals['treatment'],
        margins=True
    )
    print(outcome_treatment)
    print()

    print("="*70)
    print(" Example completed successfully!")
    print(" Data is ready for competing risks analysis (Fine-Gray model, etc.)")
    print("="*70)

    return result


if __name__ == "__main__":
    result = main()
