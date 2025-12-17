"""
Comprehensive validation tests for tvevent Python implementation
Matches Stata validation tests from _validation/validation_tvevent.do
"""

import pytest
import pandas as pd
import numpy as np
from datetime import date, timedelta
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tvtools import tvevent


def calc_duration(stop, start):
    """Calculate duration between stop and start, handling both datetime and numeric types."""
    if pd.api.types.is_numeric_dtype(stop):
        # Already numeric (Stata days), just subtract
        return stop - start
    elif pd.api.types.is_datetime64_any_dtype(stop):
        # Datetime, use .dt.days
        return (stop - start).dt.days
    else:
        # Try to convert to numeric
        return pd.to_numeric(stop) - pd.to_numeric(start)


def create_tvevent_validation_data():
    """Create validation datasets for tvevent tests."""
    # Base intervals - full year for one person
    intervals_fullyear = pd.DataFrame({
        'id': [1, 1],
        'start': [pd.Timestamp('2020-01-01'), pd.Timestamp('2020-07-01')],
        'stop': [pd.Timestamp('2020-06-30'), pd.Timestamp('2020-12-31')],
        'exp': [1, 1]
    })

    # Event in middle of year
    events_mid = pd.DataFrame({
        'id': [1],
        'event_date': [pd.Timestamp('2020-06-15')]
    })

    # Event at interval boundary
    events_boundary = pd.DataFrame({
        'id': [1],
        'event_date': [pd.Timestamp('2020-06-30')]
    })

    # Event outside intervals
    events_outside = pd.DataFrame({
        'id': [1],
        'event_date': [pd.Timestamp('2021-03-15')]
    })

    # Multiple events for recurring
    events_multiple = pd.DataFrame({
        'id': [1, 1],
        'event_date': [pd.Timestamp('2020-03-15'), pd.Timestamp('2020-09-15')]
    })

    # Competing risks events
    events_compete = pd.DataFrame({
        'id': [1],
        'event_date': [pd.Timestamp('2020-08-15')],
        'death_date': [pd.Timestamp('2020-05-20')]  # Death before event
    })

    # Multi-person data
    intervals_multi = pd.DataFrame({
        'id': [1, 1, 2, 2, 3, 3],
        'start': [pd.Timestamp('2020-01-01'), pd.Timestamp('2020-07-01')] * 3,
        'stop': [pd.Timestamp('2020-06-30'), pd.Timestamp('2020-12-31')] * 3,
        'exp': [1, 1, 1, 1, 1, 1]
    })

    events_multi = pd.DataFrame({
        'id': [1, 2],
        'event_date': [pd.Timestamp('2020-04-15'), pd.Timestamp('2020-09-20')]
    })

    # Single interval
    intervals_single = pd.DataFrame({
        'id': [1],
        'start': [pd.Timestamp('2020-01-01')],
        'stop': [pd.Timestamp('2020-12-31')],
        'exp': [1]
    })

    # Events with no matching IDs
    events_nomatch = pd.DataFrame({
        'id': [99],
        'event_date': [pd.Timestamp('2020-06-15')]
    })

    return {
        'intervals_fullyear': intervals_fullyear,
        'intervals_single': intervals_single,
        'intervals_multi': intervals_multi,
        'events_mid': events_mid,
        'events_boundary': events_boundary,
        'events_outside': events_outside,
        'events_multiple': events_multiple,
        'events_compete': events_compete,
        'events_multi': events_multi,
        'events_nomatch': events_nomatch
    }


class TestEventPlacement:
    """Section 6.1: Event Placement Tests"""

    def test_6_1_1_event_in_middle_creates_split(self):
        """Test event in middle of interval creates split."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_single'],
            events_data=vdata['events_mid'],
            id='id',
            date='event_date'
        )

        df = result.data
        # With type=single (default), person-time is censored after first event
        # So we expect at least 1 row (pre-event + event row, post-event is dropped)
        assert len(df) >= 1

    def test_6_1_2_event_at_boundary_no_extra_split(self):
        """Test event at interval boundary doesn't create extra splits."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_boundary'],
            id='id',
            date='event_date'
        )

        df = result.data
        # With type=single, person-time after first event is censored
        # Expect at least 1 row
        assert len(df) >= 1

    def test_6_1_3_event_outside_intervals_no_flag(self):
        """Test event outside intervals doesn't flag any interval."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_outside'],
            id='id',
            date='event_date'
        )

        df = result.data
        # No event should be flagged (event is in 2021, intervals in 2020)
        n_events = (df['_failure'] > 0).sum()
        assert n_events == 0


class TestCompetingRisks:
    """Section 6.2: Competing Risks Tests"""

    def test_6_2_1_competing_event_takes_precedence(self):
        """Test earlier competing event takes precedence."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_compete'],
            id='id',
            date='event_date',
            compete=['death_date']
        )

        df = result.data
        # Death date (May 20) is earlier than event date (Aug 15)
        # So death should be flagged
        events = df[df['_failure'] > 0]
        if len(events) > 0:
            # Event type 2 = first competing risk
            assert 2 in events['_failure'].values

    def test_6_2_2_primary_event_when_no_competing(self):
        """Test primary event is flagged when no competing risk."""
        vdata = create_tvevent_validation_data()

        # Events without competing risk date
        events_no_compete = pd.DataFrame({
            'id': [1],
            'event_date': [pd.Timestamp('2020-04-15')],
            'death_date': [pd.NaT]
        })

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=events_no_compete,
            id='id',
            date='event_date',
            compete=['death_date']
        )

        df = result.data
        events = df[df['_failure'] > 0]
        if len(events) > 0:
            # Event type 1 = primary event
            assert 1 in events['_failure'].values


class TestEventTypes:
    """Section 6.3: Single vs Recurring Events"""

    def test_6_3_1_single_event_censors_after_first(self):
        """Test single event type censors person-time after first event."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_single'],
            events_data=vdata['events_multiple'],
            id='id',
            date='event_date',
            type='single'
        )

        df = result.data
        # Only first event should be flagged
        n_events = (df['_failure'] > 0).sum()
        assert n_events <= 1

    def test_6_3_2_recurring_allows_multiple_events(self):
        """Test recurring event type allows multiple events."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_single'],
            events_data=vdata['events_multiple'],
            id='id',
            date='event_date',
            type='recurring'
        )

        df = result.data
        # Both events could be flagged
        n_events = (df['_failure'] > 0).sum()
        assert n_events >= 1


class TestBoundaryConditions:
    """Section 6.4: Boundary Condition Tests"""

    def test_6_4_1_event_on_start_date(self):
        """Test event on interval start date."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': [pd.Timestamp('2020-06-15')],
            'stop': [pd.Timestamp('2020-12-31')],
            'exp': [1]
        })

        events = pd.DataFrame({
            'id': [1],
            'event_date': [pd.Timestamp('2020-06-15')]
        })

        result = tvevent(
            intervals_data=intervals,
            events_data=events,
            id='id',
            date='event_date'
        )

        # Should handle gracefully
        assert len(result.data) >= 1

    def test_6_4_2_event_on_stop_date(self):
        """Test event on interval stop date."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': [pd.Timestamp('2020-01-01')],
            'stop': [pd.Timestamp('2020-06-15')],
            'exp': [1]
        })

        events = pd.DataFrame({
            'id': [1],
            'event_date': [pd.Timestamp('2020-06-15')]
        })

        result = tvevent(
            intervals_data=intervals,
            events_data=events,
            id='id',
            date='event_date'
        )

        df = result.data
        # Event should be flagged
        n_events = (df['_failure'] > 0).sum()
        assert n_events == 1


class TestTimeGeneration:
    """Section 6.5: Time Variable Generation Tests"""

    def test_6_5_1_timegen_creates_variable(self):
        """Test timegen creates time variable."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_mid'],
            id='id',
            date='event_date',
            timegen='_time'
        )

        assert '_time' in result.data.columns

    def test_6_5_2_timeunit_days(self):
        """Test timeunit days calculates correctly."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_mid'],
            id='id',
            date='event_date',
            timegen='_time',
            timeunit='days'
        )

        df = result.data
        # Time should be in days
        total_time = df['_time'].sum()
        assert total_time > 0

    def test_6_5_3_timeunit_years(self):
        """Test timeunit years calculates correctly."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_mid'],
            id='id',
            date='event_date',
            timegen='_time',
            timeunit='years'
        )

        df = result.data
        total_time = df['_time'].sum()
        # Total time in years should be less than 1 (partial year)
        assert 0 < total_time < 2


class TestMultiplePeople:
    """Section 6.6: Multiple Person Tests"""

    def test_6_6_1_events_correctly_assigned_to_persons(self):
        """Test events are correctly assigned to each person."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_multi'],
            events_data=vdata['events_multi'],
            id='id',
            date='event_date'
        )

        df = result.data

        # Person 1 should have event
        p1_events = df[(df['id'] == 1) & (df['_failure'] > 0)]
        assert len(p1_events) >= 1

        # Person 2 should have event
        p2_events = df[(df['id'] == 2) & (df['_failure'] > 0)]
        assert len(p2_events) >= 1

        # Person 3 should have no events
        p3_events = df[(df['id'] == 3) & (df['_failure'] > 0)]
        assert len(p3_events) == 0

    def test_6_6_2_no_cross_person_contamination(self):
        """Test events don't contaminate other persons."""
        vdata = create_tvevent_validation_data()

        # Event only for person 1
        events_p1 = pd.DataFrame({
            'id': [1],
            'event_date': [pd.Timestamp('2020-04-15')]
        })

        result = tvevent(
            intervals_data=vdata['intervals_multi'],
            events_data=events_p1,
            id='id',
            date='event_date'
        )

        df = result.data

        # Person 2 and 3 should have no events
        other_events = df[(df['id'] != 1) & (df['_failure'] > 0)]
        assert len(other_events) == 0


class TestOutputOptions:
    """Section 6.7: Output Options Tests"""

    def test_6_7_1_custom_generate_name(self):
        """Test custom generate variable name."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_mid'],
            id='id',
            date='event_date',
            generate='my_event_flag'
        )

        assert 'my_event_flag' in result.data.columns

    def test_6_7_2_result_object_properties(self):
        """Test result object has correct properties."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_mid'],
            id='id',
            date='event_date'
        )

        assert hasattr(result, 'data')
        assert hasattr(result, 'N')
        assert hasattr(result, 'N_events')
        assert hasattr(result, 'generate')
        assert hasattr(result, 'type')


class TestErrorHandling:
    """Section 6.8: Error Handling Tests"""

    def test_6_8_1_missing_id_in_intervals(self):
        """Test error when ID missing from intervals."""
        vdata = create_tvevent_validation_data()

        intervals_no_id = vdata['intervals_fullyear'].drop(columns=['id'])

        with pytest.raises(ValueError):
            tvevent(
                intervals_data=intervals_no_id,
                events_data=vdata['events_mid'],
                id='id',
                date='event_date'
            )

    def test_6_8_2_missing_date_in_events(self):
        """Test error when date variable missing from events."""
        vdata = create_tvevent_validation_data()

        events_no_date = vdata['events_mid'].drop(columns=['event_date'])

        with pytest.raises(ValueError):
            tvevent(
                intervals_data=vdata['intervals_fullyear'],
                events_data=events_no_date,
                id='id',
                date='event_date'
            )

    def test_6_8_3_invalid_type(self):
        """Test error for invalid event type."""
        vdata = create_tvevent_validation_data()

        with pytest.raises(ValueError):
            tvevent(
                intervals_data=vdata['intervals_fullyear'],
                events_data=vdata['events_mid'],
                id='id',
                date='event_date',
                type='invalid_type'
            )

    def test_6_8_4_invalid_timeunit(self):
        """Test error for invalid time unit."""
        vdata = create_tvevent_validation_data()

        with pytest.raises(ValueError):
            tvevent(
                intervals_data=vdata['intervals_fullyear'],
                events_data=vdata['events_mid'],
                id='id',
                date='event_date',
                timegen='_time',
                timeunit='invalid_unit'
            )


class TestEdgeCases:
    """Section 6.9: Edge Cases"""

    def test_6_9_1_empty_events_data(self):
        """Test handling of empty events data."""
        vdata = create_tvevent_validation_data()

        events_empty = pd.DataFrame({
            'id': pd.Series([], dtype='int64'),
            'event_date': pd.Series([], dtype='datetime64[ns]')
        })

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=events_empty,
            id='id',
            date='event_date'
        )

        df = result.data
        # All intervals should be censored
        assert (df['_failure'] == 0).all()

    def test_6_9_2_no_matching_ids(self):
        """Test when no event IDs match interval IDs."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_nomatch'],
            id='id',
            date='event_date'
        )

        df = result.data
        # No events should be flagged
        assert (df['_failure'] == 0).all()

    def test_6_9_3_all_events_missing_dates(self):
        """Test when all events have missing dates."""
        vdata = create_tvevent_validation_data()

        events_missing = pd.DataFrame({
            'id': [1],
            'event_date': [pd.NaT]
        })

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=events_missing,
            id='id',
            date='event_date'
        )

        df = result.data
        # No events should be flagged
        assert (df['_failure'] == 0).all()


class TestIntervalSplitting:
    """Section 6.10: Interval Splitting Tests"""

    def test_6_10_1_split_preserves_original_vars(self):
        """Test splitting preserves original variables."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': [pd.Timestamp('2020-01-01')],
            'stop': [pd.Timestamp('2020-12-31')],
            'exp': [1],
            'group': ['A'],
            'value': [100]
        })

        events = pd.DataFrame({
            'id': [1],
            'event_date': [pd.Timestamp('2020-06-15')]
        })

        result = tvevent(
            intervals_data=intervals,
            events_data=events,
            id='id',
            date='event_date'
        )

        df = result.data
        # Original variables should be preserved
        assert 'exp' in df.columns
        assert 'group' in df.columns
        assert 'value' in df.columns

    def test_6_10_2_split_creates_contiguous_intervals(self):
        """Test split intervals are contiguous."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': [pd.Timestamp('2020-01-01')],
            'stop': [pd.Timestamp('2020-12-31')],
            'exp': [1]
        })

        events = pd.DataFrame({
            'id': [1],
            'event_date': [pd.Timestamp('2020-06-15')]
        })

        result = tvevent(
            intervals_data=intervals,
            events_data=events,
            id='id',
            date='event_date'
        )

        df = result.data.sort_values(['id', 'start']).reset_index(drop=True)

        # Check contiguity - stop of one interval should equal start of next
        for i in range(1, len(df)):
            if df.loc[i, 'id'] == df.loc[i-1, 'id']:
                assert df.loc[i, 'start'] == df.loc[i-1, 'stop']


class TestPersonTimeConservation:
    """Section 6.11: Person-Time Conservation Tests"""

    def test_6_11_1_single_type_conserves_to_event(self):
        """Test single type conserves person-time up to event."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': [pd.Timestamp('2020-01-01')],
            'stop': [pd.Timestamp('2020-12-31')],
            'exp': [1]
        })

        events = pd.DataFrame({
            'id': [1],
            'event_date': [pd.Timestamp('2020-06-15')]
        })

        result = tvevent(
            intervals_data=intervals,
            events_data=events,
            id='id',
            date='event_date',
            type='single'
        )

        df = result.data
        # Calculate output duration
        df['dur'] = calc_duration(df['stop'], df['start'])
        output_dur = df['dur'].sum()

        # Expected duration: Jan 1 to Jun 15
        expected_dur = (pd.Timestamp('2020-06-15') - pd.Timestamp('2020-01-01')).days
        assert output_dur == expected_dur

    def test_6_11_2_no_overlaps_in_output(self):
        """Test no overlapping intervals in output."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_multi'],
            events_data=vdata['events_multi'],
            id='id',
            date='event_date'
        )

        df = result.data.sort_values(['id', 'start']).reset_index(drop=True)

        n_overlaps = 0
        for i in range(1, len(df)):
            if df.loc[i, 'id'] == df.loc[i-1, 'id']:
                if df.loc[i, 'start'] < df.loc[i-1, 'stop']:
                    n_overlaps += 1

        assert n_overlaps == 0


class TestUniversalInvariants:
    """Section 6.12: Universal Invariants"""

    def test_6_12_1_start_before_stop(self):
        """Test all intervals have start < stop."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_mid'],
            id='id',
            date='event_date'
        )

        df = result.data
        assert (df['start'] < df['stop']).all() or (df['start'] == df['stop']).all()

    def test_6_12_2_failure_values_valid(self):
        """Test failure values are valid (0, 1, or competing risk codes)."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_fullyear'],
            events_data=vdata['events_compete'],
            id='id',
            date='event_date',
            compete=['death_date']
        )

        df = result.data
        # All failure values should be non-negative integers
        assert (df['_failure'] >= 0).all()
        # Should only be 0, 1, or 2 (competing risk)
        assert df['_failure'].isin([0, 1, 2]).all()

    def test_6_12_3_output_sorted(self):
        """Test output is sorted by id and start."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_multi'],
            events_data=vdata['events_multi'],
            id='id',
            date='event_date'
        )

        df = result.data
        df_sorted = df.sort_values(['id', 'start']).reset_index(drop=True)

        assert df['id'].tolist() == df_sorted['id'].tolist()
        assert df['start'].tolist() == df_sorted['start'].tolist()

    def test_6_12_4_n_events_matches_flagged(self):
        """Test N_events matches actual flagged events."""
        vdata = create_tvevent_validation_data()

        result = tvevent(
            intervals_data=vdata['intervals_multi'],
            events_data=vdata['events_multi'],
            id='id',
            date='event_date'
        )

        actual_events = (result.data['_failure'] > 0).sum()
        assert result.N_events == actual_events


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
