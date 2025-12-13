"""
Tests for tvevent module.

This module contains comprehensive tests for TVEvent class and related
functionality for integrating events and competing risks.
"""

import pytest
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from tvtools.tvevent import TVEvent, TVEventError


@pytest.fixture
def sample_intervals():
    """Create sample interval data."""
    return pd.DataFrame({
        'id': [1, 1, 1, 2, 2],
        'start': pd.to_datetime([
            '2020-01-01', '2020-04-01', '2020-07-01',
            '2020-01-01', '2020-06-01'
        ]),
        'stop': pd.to_datetime([
            '2020-03-31', '2020-06-30', '2020-12-31',
            '2020-05-31', '2020-12-31'
        ]),
        'exposure': [0, 1, 1, 0, 0],
        'cumulative_dose': [0.0, 100.0, 200.0, 0.0, 0.0]
    })


@pytest.fixture
def sample_events():
    """Create sample event data."""
    return pd.DataFrame({
        'id': [1, 2],
        'event_date': pd.to_datetime(['2020-05-15', '2020-08-01']),
        'death_date': pd.to_datetime(['2020-11-01', pd.NaT]),
        'diagnosis_code': ['A01', 'B02']
    })


class TestTVEventBasic:
    """Test basic functionality."""

    def test_initialization(self, sample_intervals, sample_events):
        """Test TVEvent can be initialized."""
        tv = TVEvent(
            intervals_data=sample_intervals,
            events_data=sample_events,
            id_col='id',
            date_col='event_date'
        )
        assert tv.id_col == 'id'
        assert tv.event_type == 'single'

    def test_process_basic(self, sample_intervals, sample_events):
        """Test basic processing without errors."""
        tv = TVEvent(
            intervals_data=sample_intervals,
            events_data=sample_events,
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        assert isinstance(result.data, pd.DataFrame)
        assert '_failure' in result.data.columns
        assert result.n_total > 0
        assert result.n_events >= 0

    def test_competing_risk(self, sample_intervals, sample_events):
        """Test competing risk resolution."""
        tv = TVEvent(
            intervals_data=sample_intervals,
            events_data=sample_events,
            id_col='id',
            date_col='event_date',
            compete_cols=['death_date']
        )
        result = tv.process()

        # Check status values
        assert 0 in result.data['_failure'].values  # Censored
        assert 1 in result.data['_failure'].values or \
               2 in result.data['_failure'].values  # Event or compete


class TestTVEventValidation:
    """Test input validation."""

    def test_missing_start_column(self, sample_events):
        """Test error when 'start' column missing."""
        bad_intervals = pd.DataFrame({
            'id': [1, 2],
            'stop': pd.to_datetime(['2020-12-31', '2020-12-31'])
        })

        with pytest.raises(TVEventError, match="must have 'start' column"):
            TVEvent(
                intervals_data=bad_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date'
            )

    def test_missing_stop_column(self, sample_events):
        """Test error when 'stop' column missing."""
        bad_intervals = pd.DataFrame({
            'id': [1, 2],
            'start': pd.to_datetime(['2020-01-01', '2020-01-01'])
        })

        with pytest.raises(TVEventError, match="must have 'stop' column"):
            TVEvent(
                intervals_data=bad_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date'
            )

    def test_invalid_event_type(self, sample_intervals, sample_events):
        """Test error for invalid event_type."""
        with pytest.raises(TVEventError, match="event_type must be"):
            TVEvent(
                intervals_data=sample_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date',
                event_type='invalid'
            )

    def test_invalid_time_unit(self, sample_intervals, sample_events):
        """Test error for invalid time_unit."""
        with pytest.raises(TVEventError, match="time_unit must be"):
            TVEvent(
                intervals_data=sample_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date',
                time_col='duration',
                time_unit='weeks'
            )

    def test_column_exists_no_replace(self, sample_intervals, sample_events):
        """Test error when output column exists without replace."""
        sample_intervals['_failure'] = 0

        with pytest.raises(TVEventError, match="already exists"):
            TVEvent(
                intervals_data=sample_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date',
                replace_existing=False
            )


class TestTVEventSplitting:
    """Test interval splitting logic."""

    def test_split_at_event(self, sample_intervals, sample_events):
        """Test interval is split when event occurs mid-interval."""
        tv = TVEvent(
            intervals_data=sample_intervals,
            events_data=sample_events,
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        # Person 1 has event on 2020-05-15 (mid-interval 2020-04-01 to 2020-06-30)
        # Should create 2 intervals from that split
        person1 = result.data[result.data['id'] == 1]

        # Check that we have an interval ending at event date
        assert any(person1['stop'] == pd.Timestamp('2020-05-15'))
        # And an interval starting at event date
        assert any(person1['start'] == pd.Timestamp('2020-05-15'))

    def test_no_split_at_boundary(self):
        """Test no split when event exactly at boundary."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-12-31'])  # Exactly at stop
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        # Should have 1 interval (no split)
        assert len(result.data) == 1
        assert result.data.iloc[0]['_failure'] == 1  # Event flagged


class TestTVEventContinuous:
    """Test continuous variable adjustment."""

    def test_continuous_adjustment(self):
        """Test continuous variables are adjusted proportionally."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),  # 366 days (leap year)
            'dose': [366.0]  # 1 unit per day
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-07-01'])  # Mid-year
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            continuous_cols=['dose']
        )
        result = tv.process()

        # Should have 2 intervals
        assert len(result.data) == 2

        # First interval: Jan 1 to Jul 1 (182 days)
        # Second interval: Jul 1 to Dec 31 (184 days)
        first = result.data[result.data['stop'] == pd.Timestamp('2020-07-01')]
        second = result.data[result.data['start'] == pd.Timestamp('2020-07-01')]

        # Doses should be proportional to duration
        assert abs(first['dose'].values[0] - 182.0) < 1e-6
        assert abs(second['dose'].values[0] - 184.0) < 1e-6


class TestTVEventTypeLogic:
    """Test single vs recurring event logic."""

    def test_single_event_censors_after_first(self):
        """Test single event type drops followup after first event."""
        intervals = pd.DataFrame({
            'id': [1, 1, 1],
            'start': pd.to_datetime(['2020-01-01', '2020-04-01', '2020-07-01']),
            'stop': pd.to_datetime(['2020-03-31', '2020-06-30', '2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1, 1],
            'event_date': pd.to_datetime(['2020-05-15', '2020-10-01'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            event_type='single'
        )
        result = tv.process()

        # Should only have intervals up to first event (2020-05-15)
        assert result.data['stop'].max() == pd.Timestamp('2020-05-15')

        # Should have exactly 1 event flagged
        assert (result.data['_failure'] > 0).sum() == 1

    def test_recurring_event_keeps_all(self):
        """Test recurring event type keeps all intervals."""
        intervals = pd.DataFrame({
            'id': [1, 1, 1],
            'start': pd.to_datetime(['2020-01-01', '2020-04-01', '2020-07-01']),
            'stop': pd.to_datetime(['2020-03-31', '2020-06-30', '2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1, 1],
            'event_date': pd.to_datetime(['2020-05-15', '2020-10-01'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            event_type='recurring'
        )
        result = tv.process()

        # Should keep intervals beyond first event
        assert result.data['stop'].max() == pd.Timestamp('2020-12-31')

        # Should have 2 events flagged
        assert (result.data['_failure'] > 0).sum() == 2


class TestTVEventTimeGeneration:
    """Test time variable generation."""

    def test_time_days(self):
        """Test time generation in days."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-01-31']),
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-01-31'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            time_col='duration',
            time_unit='days'
        )
        result = tv.process()

        assert 'duration' in result.data.columns
        assert result.data['duration'].iloc[0] == 30.0

    def test_time_months(self):
        """Test time generation in months."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-01-31']),
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-01-31'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            time_col='duration',
            time_unit='months'
        )
        result = tv.process()

        expected_months = 30.0 / 30.4375
        assert abs(result.data['duration'].iloc[0] - expected_months) < 1e-6

    def test_time_years(self):
        """Test time generation in years."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-12-31'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            time_col='duration',
            time_unit='years'
        )
        result = tv.process()

        expected_years = 365.0 / 365.25  # 2020 is leap year
        assert abs(result.data['duration'].iloc[0] - expected_years) < 1e-6


class TestTVEventEdgeCases:
    """Test edge cases."""

    def test_empty_events(self, sample_intervals):
        """Test error with no events."""
        empty_events = pd.DataFrame({
            'id': [],
            'event_date': pd.to_datetime([])
        })

        with pytest.raises(TVEventError, match="No events found"):
            tv = TVEvent(
                intervals_data=sample_intervals,
                events_data=empty_events,
                id_col='id',
                date_col='event_date'
            )
            tv.process()

    def test_events_outside_intervals(self):
        """Test events that don't match any intervals."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [2],  # Different person
            'event_date': pd.to_datetime(['2020-06-15'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date'
        )

        with pytest.warns(UserWarning, match="no matching intervals"):
            result = tv.process()

        # Should have all censored
        assert (result.data['_failure'] == 0).all()

    def test_zero_duration_interval(self):
        """Test handling of zero-duration intervals."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-01-01']),  # Same day
            'dose': [0.0]
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-01-01'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            continuous_cols=['dose']
        )

        result = tv.process()
        assert len(result.data) == 1
        # Dose should remain 0
        assert result.data['dose'].iloc[0] == 0.0

    def test_multiple_events_same_day(self):
        """Test multiple events on same day (duplicates)."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1, 1],
            'event_date': pd.to_datetime(['2020-06-15', '2020-06-15'])  # Same day
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date'
        )

        with pytest.warns(UserWarning, match="duplicate events"):
            result = tv.process()

        # Should have only 1 event flagged (duplicates removed)
        assert (result.data['_failure'] > 0).sum() == 1


class TestTVEventFileIO:
    """Test file loading functionality."""

    def test_load_csv(self, tmp_path, sample_intervals, sample_events):
        """Test loading from CSV files."""
        intervals_path = tmp_path / "intervals.csv"
        events_path = tmp_path / "events.csv"

        sample_intervals.to_csv(intervals_path, index=False)
        sample_events.to_csv(events_path, index=False)

        tv = TVEvent(
            intervals_data=str(intervals_path),
            events_data=str(events_path),
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        assert isinstance(result.data, pd.DataFrame)

    def test_load_pickle(self, tmp_path, sample_intervals, sample_events):
        """Test loading from pickle files."""
        intervals_path = tmp_path / "intervals.pkl"
        events_path = tmp_path / "events.pkl"

        sample_intervals.to_pickle(intervals_path)
        sample_events.to_pickle(events_path)

        tv = TVEvent(
            intervals_data=str(intervals_path),
            events_data=str(events_path),
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        assert isinstance(result.data, pd.DataFrame)

    def test_file_not_found(self, sample_intervals):
        """Test error when file doesn't exist."""
        with pytest.raises(TVEventError, match="File not found"):
            TVEvent(
                intervals_data=sample_intervals,
                events_data='/nonexistent/file.csv',
                id_col='id',
                date_col='event_date'
            )
