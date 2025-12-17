"""
Tests for newly implemented features:
- dose and dosecuts options in tvexpose
- keep option in tvmerge
- startvar/stopvar options in tvevent
"""

import pytest
import pandas as pd
import numpy as np
from datetime import date, timedelta
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tvtools import tvexpose, tvmerge, tvevent


# =============================================================================
# TEST DATA FIXTURES
# =============================================================================

@pytest.fixture
def dose_cohort_data():
    """Cohort data for dose testing."""
    return pd.DataFrame({
        'id': [1, 2, 3],
        'study_entry': [pd.Timestamp('2020-01-01')] * 3,
        'study_exit': [pd.Timestamp('2020-12-31')] * 3
    })


@pytest.fixture
def dose_exposure_data():
    """Exposure data with dose amounts."""
    return pd.DataFrame({
        'id': [1, 1, 2, 3, 3, 3],
        'rx_start': [
            pd.Timestamp('2020-02-01'),
            pd.Timestamp('2020-05-01'),
            pd.Timestamp('2020-03-01'),
            pd.Timestamp('2020-01-15'),
            pd.Timestamp('2020-04-01'),
            pd.Timestamp('2020-08-01')
        ],
        'rx_stop': [
            pd.Timestamp('2020-03-31'),
            pd.Timestamp('2020-07-31'),
            pd.Timestamp('2020-06-30'),
            pd.Timestamp('2020-02-28'),
            pd.Timestamp('2020-05-31'),
            pd.Timestamp('2020-10-31')
        ],
        'dose_amount': [10, 20, 15, 5, 10, 25]  # Dose amounts
    })


@pytest.fixture
def keep_dataset_1():
    """Dataset 1 with extra variables for keep testing."""
    return pd.DataFrame({
        'id': [1, 1, 2],
        'start_1': [pd.Timestamp('2020-01-01'), pd.Timestamp('2020-06-01'), pd.Timestamp('2020-01-01')],
        'stop_1': [pd.Timestamp('2020-05-31'), pd.Timestamp('2020-12-31'), pd.Timestamp('2020-12-31')],
        'exp1': [1, 2, 1],
        'extra_var_a': ['A1', 'A2', 'A3'],
        'extra_var_b': [100, 200, 300]
    })


@pytest.fixture
def keep_dataset_2():
    """Dataset 2 with extra variables for keep testing."""
    return pd.DataFrame({
        'id': [1, 2, 2],
        'start_2': [pd.Timestamp('2020-03-01'), pd.Timestamp('2020-01-01'), pd.Timestamp('2020-07-01')],
        'stop_2': [pd.Timestamp('2020-09-30'), pd.Timestamp('2020-06-30'), pd.Timestamp('2020-12-31')],
        'exp2': ['X', 'Y', 'Z'],
        'extra_var_a': ['B1', 'B2', 'B3'],  # Same name, different values
        'extra_var_c': [1.1, 2.2, 3.3]
    })


@pytest.fixture
def intervals_custom_names():
    """Intervals data with custom start/stop column names."""
    return pd.DataFrame({
        'person_id': [1, 1, 2, 2],
        'period_begin': [pd.Timestamp('2020-01-01'), pd.Timestamp('2020-07-01'),
                         pd.Timestamp('2020-01-01'), pd.Timestamp('2020-06-01')],
        'period_end': [pd.Timestamp('2020-06-30'), pd.Timestamp('2020-12-31'),
                       pd.Timestamp('2020-05-31'), pd.Timestamp('2020-12-31')],
        'exposure_type': [1, 2, 1, 1]
    })


@pytest.fixture
def events_for_custom_intervals():
    """Events data for testing with custom interval column names."""
    return pd.DataFrame({
        'person_id': [1, 2],
        'event_date': [pd.Timestamp('2020-08-15'), pd.Timestamp('2020-09-01')]
    })


# =============================================================================
# DOSE OPTION TESTS
# =============================================================================

class TestDoseOption:
    """Tests for dose and dosecuts options in tvexpose."""

    def test_dose_cumulative_calculation(self, dose_cohort_data, dose_exposure_data):
        """Test that dose calculates cumulative dose correctly."""
        result = tvexpose(
            master_data=dose_cohort_data,
            exposure_file=dose_exposure_data,
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='dose_amount',
            reference=0,
            entry='study_entry',
            exit='study_exit',
            dose=True,
            verbose=False
        )

        df = result.data
        assert 'tv_dose' in df.columns

        # Check person 1: cumulative dose should be 10 then 30 (10+20)
        person1 = df[df['id'] == 1].sort_values('start')
        max_dose = person1['tv_dose'].max()
        assert max_dose == 30  # 10 + 20

        # Check person 3: cumulative dose should be 5, then 15, then 40
        person3 = df[df['id'] == 3].sort_values('start')
        max_dose = person3['tv_dose'].max()
        assert max_dose == 40  # 5 + 10 + 25

    def test_dose_monotonic_increase(self, dose_cohort_data, dose_exposure_data):
        """Test that cumulative dose is monotonically increasing."""
        result = tvexpose(
            master_data=dose_cohort_data,
            exposure_file=dose_exposure_data,
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='dose_amount',
            reference=0,
            entry='study_entry',
            exit='study_exit',
            dose=True,
            verbose=False
        )

        df = result.data.sort_values(['id', 'start'])

        for pid in df['id'].unique():
            person_data = df[df['id'] == pid]
            doses = person_data['tv_dose'].values
            # Each subsequent dose should be >= previous
            for i in range(1, len(doses)):
                assert doses[i] >= doses[i-1], f"Dose decreased for person {pid}"

    def test_dosecuts_categorization(self, dose_cohort_data, dose_exposure_data):
        """Test that dosecuts creates proper categories."""
        result = tvexpose(
            master_data=dose_cohort_data,
            exposure_file=dose_exposure_data,
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='dose_amount',
            reference=0,
            entry='study_entry',
            exit='study_exit',
            dose=True,
            dosecuts=[10, 20, 30],
            verbose=False
        )

        df = result.data
        # With dosecuts, should have tv_exposure instead of tv_dose
        assert 'tv_exposure' in df.columns or 'exp_value' in df.columns

        # Categories should be: 0 (no dose), 1 (<10), 2 (10-<20), 3 (20-<30), 4 (30+)
        exp_col = 'tv_exposure' if 'tv_exposure' in df.columns else 'exp_value'
        unique_cats = sorted(df[exp_col].unique())
        # Should have at least some categories
        assert len(unique_cats) >= 2

    def test_dosecuts_requires_dose(self, dose_cohort_data, dose_exposure_data):
        """Test that dosecuts without dose raises error."""
        with pytest.raises(ValueError, match="dosecuts requires dose=True"):
            tvexpose(
                master_data=dose_cohort_data,
                exposure_file=dose_exposure_data,
                id='id',
                start='rx_start',
                stop='rx_stop',
                exposure='dose_amount',
                reference=0,
                entry='study_entry',
                exit='study_exit',
                dosecuts=[10, 20, 30],  # No dose=True
                verbose=False
            )

    def test_dose_mutually_exclusive_with_other_types(self, dose_cohort_data, dose_exposure_data):
        """Test that dose cannot be combined with other exposure types."""
        with pytest.raises(ValueError, match="Only one exposure type"):
            tvexpose(
                master_data=dose_cohort_data,
                exposure_file=dose_exposure_data,
                id='id',
                start='rx_start',
                stop='rx_stop',
                exposure='dose_amount',
                reference=0,
                entry='study_entry',
                exit='study_exit',
                dose=True,
                evertreated=True,  # Conflicting option
                verbose=False
            )


# =============================================================================
# KEEP OPTION TESTS
# =============================================================================

class TestKeepOption:
    """Tests for keep option in tvmerge."""

    def test_keep_variables_included(self, keep_dataset_1, keep_dataset_2):
        """Test that keep variables are included in output."""
        result = tvmerge(
            datasets=[keep_dataset_1, keep_dataset_2],
            id='id',
            start=['start_1', 'start_2'],
            stop=['stop_1', 'stop_2'],
            exposure=['exp1', 'exp2'],
            keep=['extra_var_b', 'extra_var_c']
        )

        df = result.data
        # extra_var_b from ds1 should be extra_var_b_ds1
        assert 'extra_var_b_ds1' in df.columns
        # extra_var_c from ds2 should be extra_var_c_ds2
        assert 'extra_var_c_ds2' in df.columns

    def test_keep_same_name_different_datasets(self, keep_dataset_1, keep_dataset_2):
        """Test that same variable name in different datasets gets suffixed."""
        result = tvmerge(
            datasets=[keep_dataset_1, keep_dataset_2],
            id='id',
            start=['start_1', 'start_2'],
            stop=['stop_1', 'stop_2'],
            exposure=['exp1', 'exp2'],
            keep=['extra_var_a']
        )

        df = result.data
        # Both datasets have extra_var_a, should be suffixed differently
        assert 'extra_var_a_ds1' in df.columns
        assert 'extra_var_a_ds2' in df.columns

    def test_keep_missing_variable_warning(self, keep_dataset_1, keep_dataset_2, capsys):
        """Test that missing keep variable generates warning."""
        result = tvmerge(
            datasets=[keep_dataset_1, keep_dataset_2],
            id='id',
            start=['start_1', 'start_2'],
            stop=['stop_1', 'stop_2'],
            exposure=['exp1', 'exp2'],
            keep=['nonexistent_var']
        )

        captured = capsys.readouterr()
        assert 'not found in any dataset' in captured.out


# =============================================================================
# STARTVAR/STOPVAR TESTS
# =============================================================================

class TestStartvarStopvar:
    """Tests for startvar and stopvar options in tvevent."""

    def test_custom_column_names(self, intervals_custom_names, events_for_custom_intervals):
        """Test that custom start/stop column names work correctly."""
        result = tvevent(
            intervals_data=intervals_custom_names,
            events_data=events_for_custom_intervals,
            id='person_id',
            date='event_date',
            startvar='period_begin',
            stopvar='period_end'
        )

        df = result.data
        # Output should use original column names
        assert 'period_begin' in df.columns
        assert 'period_end' in df.columns
        # Default names should not be present
        assert 'start' not in df.columns
        assert 'stop' not in df.columns

    def test_custom_names_event_integration(self, intervals_custom_names, events_for_custom_intervals):
        """Test that events are properly integrated with custom column names."""
        result = tvevent(
            intervals_data=intervals_custom_names,
            events_data=events_for_custom_intervals,
            id='person_id',
            date='event_date',
            startvar='period_begin',
            stopvar='period_end',
            generate='_event_flag'
        )

        df = result.data
        # Person 1 has event on 2020-08-15, which is in the second period (Jul-Dec)
        person1_events = df[(df['person_id'] == 1) & (df['_event_flag'] > 0)]
        assert len(person1_events) >= 1

        # Person 2 has event on 2020-09-01, which is in the second period (Jun-Dec)
        person2_events = df[(df['person_id'] == 2) & (df['_event_flag'] > 0)]
        assert len(person2_events) >= 1

    def test_default_names_still_work(self):
        """Test that default start/stop column names still work."""
        intervals = pd.DataFrame({
            'id': [1, 1],
            'start': [pd.Timestamp('2020-01-01'), pd.Timestamp('2020-07-01')],
            'stop': [pd.Timestamp('2020-06-30'), pd.Timestamp('2020-12-31')],
            'exposure': [1, 2]
        })

        events = pd.DataFrame({
            'id': [1],
            'event_date': [pd.Timestamp('2020-08-15')]
        })

        result = tvevent(
            intervals_data=intervals,
            events_data=events,
            id='id',
            date='event_date'
            # No startvar/stopvar specified, should use defaults
        )

        df = result.data
        assert 'start' in df.columns
        assert 'stop' in df.columns


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

class TestIntegration:
    """Integration tests combining multiple new features."""

    def test_full_workflow_with_dose(self):
        """Test complete workflow using dose option."""
        # Create cohort
        cohort = pd.DataFrame({
            'id': [1, 2],
            'study_entry': [pd.Timestamp('2020-01-01')] * 2,
            'study_exit': [pd.Timestamp('2020-12-31')] * 2
        })

        # Create dose exposure
        exposures = pd.DataFrame({
            'id': [1, 1, 2],
            'rx_start': [pd.Timestamp('2020-02-01'), pd.Timestamp('2020-06-01'), pd.Timestamp('2020-03-01')],
            'rx_stop': [pd.Timestamp('2020-04-30'), pd.Timestamp('2020-08-31'), pd.Timestamp('2020-09-30')],
            'dose': [10, 20, 15]
        })

        # Run tvexpose with dose
        tv_result = tvexpose(
            master_data=cohort,
            exposure_file=exposures,
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='dose',
            reference=0,
            entry='study_entry',
            exit='study_exit',
            dose=True,
            verbose=False
        )

        assert tv_result.data is not None
        assert 'tv_dose' in tv_result.data.columns
        assert tv_result.metadata['parameters']['exposure_definition'] == 'dose'

    def test_dose_with_categorization_workflow(self):
        """Test workflow with dose categorization."""
        cohort = pd.DataFrame({
            'id': [1],
            'study_entry': [pd.Timestamp('2020-01-01')],
            'study_exit': [pd.Timestamp('2020-12-31')]
        })

        exposures = pd.DataFrame({
            'id': [1, 1, 1],
            'rx_start': [pd.Timestamp('2020-02-01'), pd.Timestamp('2020-05-01'), pd.Timestamp('2020-08-01')],
            'rx_stop': [pd.Timestamp('2020-03-31'), pd.Timestamp('2020-06-30'), pd.Timestamp('2020-10-31')],
            'dose': [5, 10, 15]  # Cumulative: 5, 15, 30
        })

        result = tvexpose(
            master_data=cohort,
            exposure_file=exposures,
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='dose',
            reference=0,
            entry='study_entry',
            exit='study_exit',
            dose=True,
            dosecuts=[10, 25],  # Categories: 0 (ref), 1 (<10), 2 (10-<25), 3 (25+)
            verbose=False
        )

        assert result.data is not None
        # Should create categorical variable
        exp_col = 'tv_exposure' if 'tv_exposure' in result.data.columns else 'exp_value'
        unique_vals = result.data[exp_col].unique()
        # Should have some categorization
        assert len(unique_vals) >= 2


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
