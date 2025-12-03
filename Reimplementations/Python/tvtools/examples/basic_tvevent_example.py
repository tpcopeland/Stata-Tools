"""
Basic TVEvent Example
=====================

This example demonstrates basic usage of the TVEvent module to integrate
events and competing risks into time-varying exposure datasets.

We will:
1. Generate synthetic time-varying exposure data
2. Generate synthetic event data with competing risks
3. Use TVEvent to process and flag events
4. Display results
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# For demonstration, we'll create the data structures manually
# In practice, you would have interval data from tvexpose/tvmerge


def generate_synthetic_data():
    """Generate synthetic data for the example."""
    np.random.seed(42)

    # Create time-varying intervals (output from tvexpose)
    # 100 persons, each with 3-5 intervals
    intervals_list = []

    for person_id in range(1, 101):
        entry_date = datetime(2020, 1, 1)
        current_date = entry_date

        # Create 3-5 intervals per person
        n_intervals = np.random.randint(3, 6)

        for i in range(n_intervals):
            # Interval duration: 30-120 days
            duration = np.random.randint(30, 121)
            stop_date = current_date + timedelta(days=duration)

            # Random exposure status
            exposure = np.random.choice([0, 1, 2])

            intervals_list.append({
                'person_id': person_id,
                'start': current_date,
                'stop': stop_date,
                'tv_exposure': exposure
            })

            current_date = stop_date

    intervals_df = pd.DataFrame(intervals_list)

    # Create event data with competing risks
    # Some people have primary events, some have competing events, some censored
    events_list = []

    for person_id in range(1, 101):
        # Get this person's last interval stop date
        person_intervals = intervals_df[intervals_df['person_id'] == person_id]
        max_stop = person_intervals['stop'].max()

        # 40% chance of primary event
        # 20% chance of competing risk (death)
        # 40% censored
        event_type = np.random.choice(['primary', 'compete', 'censored'], p=[0.4, 0.2, 0.4])

        primary_date = None
        death_date = None

        if event_type == 'primary':
            # Event occurs somewhere during follow-up
            min_date = person_intervals['start'].min()
            event_day = np.random.randint(0, (max_stop - min_date).days + 1)
            primary_date = min_date + timedelta(days=event_day)

        elif event_type == 'compete':
            # Competing event
            min_date = person_intervals['start'].min()
            event_day = np.random.randint(0, (max_stop - min_date).days + 1)
            death_date = min_date + timedelta(days=event_day)

        events_list.append({
            'person_id': person_id,
            'event_date': primary_date,
            'death_date': death_date
        })

    events_df = pd.DataFrame(events_list)

    return intervals_df, events_df


def main():
    """Main example workflow."""

    print("="*60)
    print("Basic TVEvent Example")
    print("="*60)
    print()

    # Step 1: Generate synthetic data
    print("Step 1: Generating synthetic data...")
    intervals_df, events_df = generate_synthetic_data()

    print(f"  Created {len(intervals_df):,} time-varying intervals")
    print(f"  Created {len(events_df):,} person records with events")
    print()

    # Display sample data
    print("Sample interval data:")
    print(intervals_df.head(10))
    print()

    print("Sample event data:")
    print(events_df.head(10))
    print()

    # Step 2: Initialize TVEvent
    print("Step 2: Initializing TVEvent...")

    # Import the TVEvent class
    # Note: In actual use, you would do: from tvtools.tvevent import TVEvent
    from tvtools.tvevent import TVEvent

    tv = TVEvent(
        intervals_data=intervals_df,
        events_data=events_df,
        id_col='person_id',
        date_col='event_date',
        compete_cols=['death_date'],
        event_type='single',  # Terminal event
        output_col='_failure',
        time_col='_t',
        time_unit='days'
    )

    print("  TVEvent initialized successfully")
    print()

    # Step 3: Process the data
    print("Step 3: Processing events...")
    result = tv.process()

    print(f"  Processed {result.n_total:,} intervals")
    print(f"  Flagged {result.n_events:,} events")
    print(f"  Split {result.n_splits:,} intervals at event boundaries")
    print()

    # Step 4: Examine results
    print("Step 4: Results summary")
    print("-"*60)

    # Event status distribution
    print("\nEvent status distribution:")
    status_counts = result.data[result.output_col].value_counts().sort_index()
    for status, count in status_counts.items():
        label = result.event_labels.get(status, f"Status {status}")
        pct = count / len(result.data) * 100
        print(f"  {label}: {count:,} ({pct:.1f}%)")

    print()

    # Display sample of processed data
    print("Sample processed data (first 10 rows):")
    display_cols = ['person_id', 'start', 'stop', 'tv_exposure', '_failure', '_t']
    print(result.data[display_cols].head(10))
    print()

    # Show examples of each event type
    print("Examples of each event status:")
    print()

    for status in sorted(result.data[result.output_col].unique()):
        label = result.event_labels.get(status, f"Status {status}")
        print(f"\n{label} (status={status}):")
        sample = result.data[result.data[result.output_col] == status].head(3)
        print(sample[display_cols])

    print()
    print("="*60)
    print("Example completed successfully!")
    print("="*60)

    return result


if __name__ == "__main__":
    result = main()
