"""
Comprehensive tests for tvevent Python implementation
"""

import pytest
import pandas as pd
import numpy as np
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tvtools import tvexpose, tvevent

DATA_PATH = "/home/ubuntu/Stata-Tools/_testing/data"


@pytest.fixture
def test_data():
    """Load test data."""
    import pyreadstat
    cohort, _ = pyreadstat.read_dta(f"{DATA_PATH}/cohort.dta")
    hrt, _ = pyreadstat.read_dta(f"{DATA_PATH}/hrt.dta")
    return {'cohort': cohort, 'hrt': hrt}


@pytest.fixture
def intervals_data(test_data):
    """Create interval data for tvevent testing."""
    result = tvexpose(
        master_data=test_data['cohort'],
        exposure_file=test_data['hrt'],
        id='id', start='rx_start', stop='rx_stop', exposure='hrt_type',
        entry='study_entry', exit='study_exit', reference=0,
        generate='hrt_exp', verbose=False
    )
    return result.data


@pytest.fixture
def events_data(test_data):
    """Create events data for testing."""
    events = test_data['cohort'][['id', 'edss4_dt', 'death_dt', 'emigration_dt']].copy()
    events = events.rename(columns={'edss4_dt': 'event_date'})
    return events


class TestTVEventBasic:
    """Basic functionality tests."""

    def test_basic_single_event(self, intervals_data, events_data):
        """Test basic single event creation."""
        result = tvevent(
            intervals_data=intervals_data,
            events_data=events_data,
            id='id',
            date='event_date',
            generate='outcome',
            type='single'
        )

        assert result is not None
        assert len(result.data) > 0
        assert 'outcome' in result.data.columns
        assert result.N_events >= 0

    def test_competing_risks(self, intervals_data, events_data):
        """Test competing risks handling."""
        result = tvevent(
            intervals_data=intervals_data,
            events_data=events_data,
            id='id',
            date='event_date',
            compete=['death_dt', 'emigration_dt'],
            generate='outcome',
            type='single'
        )

        # Should have multiple event types
        outcome_vals = result.data['outcome'].unique()
        assert len(outcome_vals) > 1


class TestTVEventTimeGeneration:
    """Time variable generation tests."""

    def test_timegen_days(self, intervals_data, events_data):
        """Test time generation in days."""
        result = tvevent(
            intervals_data=intervals_data,
            events_data=events_data,
            id='id',
            date='event_date',
            generate='outcome',
            timegen='followup',
            timeunit='days',
            type='single'
        )

        assert 'followup' in result.data.columns
        assert all(result.data['followup'] >= 0)

    def test_timegen_months(self, intervals_data, events_data):
        """Test time generation in months."""
        result = tvevent(
            intervals_data=intervals_data,
            events_data=events_data,
            id='id',
            date='event_date',
            generate='outcome',
            timegen='followup',
            timeunit='months',
            type='single'
        )

        assert 'followup' in result.data.columns

    def test_timegen_years(self, intervals_data, events_data):
        """Test time generation in years."""
        result = tvevent(
            intervals_data=intervals_data,
            events_data=events_data,
            id='id',
            date='event_date',
            generate='outcome',
            timegen='followup',
            timeunit='years',
            type='single'
        )

        assert 'followup' in result.data.columns


class TestTVEventTypes:
    """Event type handling tests."""

    def test_single_event_type(self, intervals_data, events_data):
        """Test single event type censors after first event."""
        result = tvevent(
            intervals_data=intervals_data,
            events_data=events_data,
            id='id',
            date='event_date',
            generate='outcome',
            type='single'
        )

        # For each person, max 1 event
        events_per_person = result.data[result.data['outcome'] > 0].groupby('id').size()
        assert all(events_per_person <= 1)

    def test_recurring_events(self):
        """Test recurring events type."""
        intervals = pd.DataFrame({
            'id': [1, 1, 1, 2, 2],
            'start': [1, 11, 21, 1, 11],
            'stop': [10, 20, 30, 10, 20],
            'exposure': [1, 1, 0, 1, 0]
        })

        events = pd.DataFrame({
            'id': [1, 1, 2],
            'event_date': [5.0, 15.0, 8.0]
        })

        result = tvevent(
            intervals_data=intervals,
            events_data=events,
            id='id',
            date='event_date',
            generate='outcome',
            type='recurring'
        )

        assert len(result.data) > 0


class TestTVEventValidation:
    """Validation tests."""

    def test_invalid_type_raises(self, intervals_data, events_data):
        """Test that invalid type raises error."""
        with pytest.raises(ValueError, match="single.*recurring"):
            tvevent(
                intervals_data=intervals_data,
                events_data=events_data,
                id='id',
                date='event_date',
                generate='outcome',
                type='invalid'
            )

    def test_invalid_timeunit_raises(self, intervals_data, events_data):
        """Test that invalid timeunit raises error."""
        with pytest.raises(ValueError, match="days.*months.*years"):
            tvevent(
                intervals_data=intervals_data,
                events_data=events_data,
                id='id',
                date='event_date',
                generate='outcome',
                timegen='time',
                timeunit='invalid',
                type='single'
            )

    def test_missing_columns_raises(self, intervals_data, events_data):
        """Test that missing columns raise error."""
        with pytest.raises(ValueError, match="not found"):
            tvevent(
                intervals_data=intervals_data,
                events_data=events_data,
                id='id',
                date='invalid_column',
                generate='outcome',
                type='single'
            )


class TestTVEventReturns:
    """Return value tests."""

    def test_returns_structure(self, intervals_data, events_data):
        """Test proper return structure."""
        result = tvevent(
            intervals_data=intervals_data,
            events_data=events_data,
            id='id',
            date='event_date',
            generate='outcome',
            type='single'
        )

        assert hasattr(result, 'data')
        assert hasattr(result, 'N')
        assert hasattr(result, 'N_events')
        assert hasattr(result, 'generate')
        assert hasattr(result, 'type')


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
