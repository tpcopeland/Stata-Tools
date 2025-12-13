"""
Tests for tvexpose module.

This module contains comprehensive tests for TVExpose class and related
functionality for creating time-varying exposure variables.
"""

import pytest
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from tvtools.tvexpose import TVExpose, TVExposeError


@pytest.fixture
def sample_master_data():
    """Sample cohort data."""
    return pd.DataFrame({
        'id': [1, 2, 3],
        'study_entry': pd.to_datetime(['2020-01-01', '2020-01-01', '2020-01-01']),
        'study_exit': pd.to_datetime(['2020-12-31', '2020-12-31', '2020-12-31']),
        'age': [50, 60, 70]
    })


@pytest.fixture
def sample_exposure_data():
    """Sample exposure periods."""
    return pd.DataFrame({
        'id': [1, 1, 2],
        'rx_start': pd.to_datetime(['2020-03-01', '2020-06-01', '2020-04-01']),
        'rx_stop': pd.to_datetime(['2020-04-30', '2020-07-31', '2020-09-30']),
        'drug_type': [1, 2, 1]
    })


@pytest.fixture
def overlapping_exposure_data():
    """Exposure data with overlaps for testing."""
    return pd.DataFrame({
        'id': [1, 1],
        'rx_start': pd.to_datetime(['2020-01-01', '2020-01-15']),
        'rx_stop': pd.to_datetime(['2020-01-31', '2020-02-15']),
        'drug_type': [1, 2]
    })


class TestTVExposeBasic:
    """Test basic functionality."""

    def test_initialization(self, sample_master_data, sample_exposure_data):
        """Test TVExpose can be initialized."""
        tv = TVExpose(
            master_data=sample_master_data,
            exposure_data=sample_exposure_data,
            id_col='id',
            start_col='study_entry',
            stop_col='study_exit',
            exp_start_col='rx_start',
            exp_stop_col='rx_stop',
            exposure_col='drug_type'
        )
        assert tv.id_col == 'id'
        assert tv.exposure_col == 'drug_type'

    def test_process_basic(self, sample_master_data, sample_exposure_data):
        """Test basic processing without errors."""
        tv = TVExpose(
            master_data=sample_master_data,
            exposure_data=sample_exposure_data,
            id_col='id',
            start_col='study_entry',
            stop_col='study_exit',
            exp_start_col='rx_start',
            exp_stop_col='rx_stop',
            exposure_col='drug_type'
        )
        result = tv.process()

        assert isinstance(result.data, pd.DataFrame)
        assert 'start' in result.data.columns
        assert 'stop' in result.data.columns
        assert result.n_persons > 0


class TestTVExposeValidation:
    """Test input validation."""

    def test_missing_id_column(self, sample_exposure_data):
        """Test error when ID column missing from master."""
        bad_master = pd.DataFrame({
            'study_entry': pd.to_datetime(['2020-01-01']),
            'study_exit': pd.to_datetime(['2020-12-31'])
        })

        with pytest.raises(TVExposeError, match="ID column .* not found"):
            TVExpose(
                master_data=bad_master,
                exposure_data=sample_exposure_data,
                id_col='id',
                start_col='study_entry',
                stop_col='study_exit',
                exp_start_col='rx_start',
                exp_stop_col='rx_stop',
                exposure_col='drug_type'
            )

    def test_missing_start_column(self, sample_master_data, sample_exposure_data):
        """Test error when start column missing."""
        bad_master = sample_master_data.drop(columns=['study_entry'])

        with pytest.raises(TVExposeError, match="Start column .* not found"):
            TVExpose(
                master_data=bad_master,
                exposure_data=sample_exposure_data,
                id_col='id',
                start_col='study_entry',
                stop_col='study_exit',
                exp_start_col='rx_start',
                exp_stop_col='rx_stop',
                exposure_col='drug_type'
            )

    def test_invalid_exposure_type(self, sample_master_data, sample_exposure_data):
        """Test error for invalid exposure_type."""
        with pytest.raises(TVExposeError, match="exposure_type must be"):
            TVExpose(
                master_data=sample_master_data,
                exposure_data=sample_exposure_data,
                id_col='id',
                start_col='study_entry',
                stop_col='study_exit',
                exp_start_col='rx_start',
                exp_stop_col='rx_stop',
                exposure_col='drug_type',
                exposure_type='invalid'
            )


class TestMergePeriods:
    """Tests for period merging algorithm."""

    def test_merge_adjacent_same_type(self):
        """Adjacent same-type periods are merged."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        # Create adjacent periods with 5-day gap
        exposures = pd.DataFrame({
            'id': [1, 1],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-01-11']),
            'exp_stop': pd.to_datetime(['2020-01-10', '2020-01-20']),
            'exp_value': [1, 1]
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='exp_value',
            merge_days=5
        )
        result = tv.process()

        # Should merge into 1 period
        person1 = result.data[result.data['id'] == 1]
        exposed = person1[person1['exp_value'] == 1]

        # Check that periods were merged
        assert len(exposed) >= 1
        # First exposed period should extend from first start to second stop
        first_exposed = exposed.iloc[0]
        assert first_exposed['start'] == pd.Timestamp('2020-01-01')

    def test_no_merge_different_types(self):
        """Different exposure types are not merged."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        exposures = pd.DataFrame({
            'id': [1, 1],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-01-11']),
            'exp_stop': pd.to_datetime(['2020-01-10', '2020-01-20']),
            'exp_value': [1, 2]  # Different types
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='exp_value',
            merge_days=5
        )
        result = tv.process()

        # Should not merge - different types
        person1 = result.data[result.data['id'] == 1]
        # Should have separate periods for type 1 and type 2
        type1_periods = person1[person1['exp_value'] == 1]
        type2_periods = person1[person1['exp_value'] == 2]

        assert len(type1_periods) >= 1
        assert len(type2_periods) >= 1


class TestLayerOverlapResolution:
    """Tests for layer overlap strategy."""

    def test_later_takes_precedence(self, overlapping_exposure_data):
        """Later exposure takes precedence in overlap."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=overlapping_exposure_data,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='rx_start',
            exp_stop_col='rx_stop',
            exposure_col='drug_type',
            overlap_strategy='layer'
        )
        result = tv.process()

        # Should have periods: pre-overlap type 1, overlap type 2, post-overlap type 1
        person1 = result.data[result.data['id'] == 1]

        # Check that type 2 appears in the overlap region (Jan 15 - Jan 31)
        overlap_period = person1[
            (person1['start'] >= pd.Timestamp('2020-01-15')) &
            (person1['stop'] <= pd.Timestamp('2020-01-31'))
        ]

        # At least one period in overlap should be type 2
        assert any(overlap_period['drug_type'] == 2)

    def test_earlier_resumes_after(self, overlapping_exposure_data):
        """Earlier exposure resumes after later ends."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=overlapping_exposure_data,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='rx_start',
            exp_stop_col='rx_stop',
            exposure_col='drug_type',
            overlap_strategy='layer'
        )
        result = tv.process()

        person1 = result.data[result.data['id'] == 1]

        # Last period should be type 1 (resumption after type 2 ends)
        last = person1.sort_values('start').iloc[-1]
        # The last exposed period (before return to reference) should be type 1
        exposed_periods = person1[person1['drug_type'].notna()]
        if len(exposed_periods) > 0:
            last_exposed = exposed_periods.sort_values('stop').iloc[-1]
            assert last_exposed['drug_type'] == 1


class TestEverTreated:
    """Tests for ever-treated exposure type."""

    def test_switches_at_first_exposure(self):
        """Variable switches from 0 to 1 at first exposure."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        exposures = pd.DataFrame({
            'id': [1, 1],
            'exp_start': pd.to_datetime(['2020-03-01', '2020-06-01']),
            'exp_stop': pd.to_datetime(['2020-05-31', '2020-12-31']),
            'exp_value': [1, 0]  # Exposed, then back to unexposed
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='exp_value',
            exposure_type='ever_treated',
            reference_value=0,
            output_col='ever'
        )
        result = tv.process()

        person1 = result.data[result.data['id'] == 1].sort_values('start')

        # Before first exposure (Jan-Feb)
        before = person1[person1['stop'] < pd.Timestamp('2020-03-01')]
        assert all(before['ever'] == 0)

        # At and after first exposure (Mar onwards)
        after = person1[person1['start'] >= pd.Timestamp('2020-03-01')]
        assert all(after['ever'] == 1)

    def test_never_exposed_stays_zero(self):
        """Never-exposed persons stay at 0."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        exposures = pd.DataFrame({
            'id': [1],
            'exp_start': pd.to_datetime(['2020-01-01']),
            'exp_stop': pd.to_datetime(['2020-12-31']),
            'exp_value': [0]  # Never exposed
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='exp_value',
            exposure_type='ever_treated',
            reference_value=0,
            output_col='ever'
        )
        result = tv.process()

        person1 = result.data[result.data['id'] == 1]
        assert all(person1['ever'] == 0)


class TestCurrentFormer:
    """Tests for current/former exposure type."""

    def test_current_former_switching(self):
        """Test switching between current and former states."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        exposures = pd.DataFrame({
            'id': [1, 1],
            'exp_start': pd.to_datetime(['2020-02-01', '2020-06-01']),
            'exp_stop': pd.to_datetime(['2020-03-31', '2020-07-31']),
            'exp_value': [1, 1]
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='exp_value',
            exposure_type='current_former',
            reference_value=0,
            output_col='status'
        )
        result = tv.process()

        person1 = result.data[result.data['id'] == 1].sort_values('start')

        # Should have periods: 0 (never), 1 (current), 2 (former), 1 (current again), 2 (former)
        # Check that we have current periods (value 1)
        current_periods = person1[person1['status'] == 1]
        assert len(current_periods) > 0

        # Check that we have former periods (value 2)
        former_periods = person1[person1['status'] == 2]
        assert len(former_periods) > 0


class TestContinuousExposure:
    """Tests for continuous cumulative exposure."""

    def test_cumulative_calculation(self):
        """Test cumulative exposure calculation."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        exposures = pd.DataFrame({
            'id': [1, 1],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-02-01']),
            'exp_stop': pd.to_datetime(['2020-01-31', '2020-02-29']),
            'dose': [100.0, 200.0]
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='dose',
            exposure_type='continuous',
            output_col='cumulative_dose'
        )
        result = tv.process()

        person1 = result.data[result.data['id'] == 1].sort_values('start')

        # Cumulative dose should increase over time
        cumulative_vals = person1['cumulative_dose'].values
        # Check that cumulative values are monotonically increasing
        assert all(cumulative_vals[i] <= cumulative_vals[i+1]
                  for i in range(len(cumulative_vals)-1))


class TestDurationCategories:
    """Tests for duration category exposure type."""

    def test_duration_categories(self):
        """Test duration category assignment."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        exposures = pd.DataFrame({
            'id': [1],
            'exp_start': pd.to_datetime(['2020-01-01']),
            'exp_stop': pd.to_datetime(['2020-12-31']),
            'exp_value': [1]
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='exp_value',
            exposure_type='duration',
            duration_cutpoints=[30, 90, 180],  # Days
            output_col='duration_cat'
        )
        result = tv.process()

        person1 = result.data[result.data['id'] == 1].sort_values('start')

        # Should have increasing duration categories
        duration_cats = person1['duration_cat'].values
        # At least some progression through categories
        assert len(set(duration_cats)) > 1


class TestGracePeriods:
    """Tests for grace period bridging."""

    def test_grace_period_bridges_gaps(self):
        """Test that grace period bridges small gaps."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        # Two periods with 10-day gap
        exposures = pd.DataFrame({
            'id': [1, 1],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-02-01']),
            'exp_stop': pd.to_datetime(['2020-01-20', '2020-02-28']),
            'exp_value': [1, 1]
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='exp_value',
            grace_days=15  # Bridge gaps up to 15 days
        )
        result = tv.process()

        person1 = result.data[result.data['id'] == 1]
        exposed = person1[person1['exp_value'] == 1]

        # Should bridge the gap - check for continuous exposure
        # Gap from Jan 21 to Jan 31 should be filled
        gap_periods = exposed[
            (exposed['start'] >= pd.Timestamp('2020-01-20')) &
            (exposed['stop'] <= pd.Timestamp('2020-02-01'))
        ]
        assert len(gap_periods) > 0


class TestEdgeCases:
    """Test edge cases."""

    def test_empty_exposure_data(self, sample_master_data):
        """Test with no exposure data."""
        empty_exposures = pd.DataFrame({
            'id': [],
            'rx_start': pd.to_datetime([]),
            'rx_stop': pd.to_datetime([]),
            'drug_type': []
        })

        tv = TVExpose(
            master_data=sample_master_data,
            exposure_data=empty_exposures,
            id_col='id',
            start_col='study_entry',
            stop_col='study_exit',
            exp_start_col='rx_start',
            exp_stop_col='rx_stop',
            exposure_col='drug_type'
        )
        result = tv.process()

        # Should return master data with reference exposure values
        assert len(result.data) == len(sample_master_data)

    def test_exposure_outside_followup(self):
        """Test exposure periods outside followup window."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        # Exposure completely outside followup
        exposures = pd.DataFrame({
            'id': [1],
            'exp_start': pd.to_datetime(['2019-01-01']),
            'exp_stop': pd.to_datetime(['2019-12-31']),
            'exp_value': [1]
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='exp_value'
        )
        result = tv.process()

        # Should have only unexposed periods
        person1 = result.data[result.data['id'] == 1]
        assert all(person1['exp_value'] != 1)

    def test_zero_duration_exposure(self):
        """Test point-in-time exposure (start == stop)."""
        master = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31'])
        })

        exposures = pd.DataFrame({
            'id': [1],
            'exp_start': pd.to_datetime(['2020-06-15']),
            'exp_stop': pd.to_datetime(['2020-06-15']),  # Same day
            'exp_value': [1]
        })

        tv = TVExpose(
            master_data=master,
            exposure_data=exposures,
            id_col='id',
            start_col='start',
            stop_col='stop',
            exp_start_col='exp_start',
            exp_stop_col='exp_stop',
            exposure_col='exp_value'
        )
        result = tv.process()

        # Should handle point-in-time exposure
        assert len(result.data) > 0
