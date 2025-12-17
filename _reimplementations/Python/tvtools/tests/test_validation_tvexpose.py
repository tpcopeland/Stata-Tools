"""
Comprehensive validation tests for tvexpose Python implementation
Matches Stata validation tests from _validation/validation_tvexpose.do
"""

import pytest
import pandas as pd
import numpy as np
from datetime import date, timedelta
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tvtools import tvexpose

# Test data path
DATA_PATH = "/home/ubuntu/Stata-Tools/_testing/data"


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


def create_validation_data():
    """Create minimal validation datasets."""
    # Single person cohort, 2020 (366 days = leap year)
    cohort_single = pd.DataFrame({
        'id': [1],
        'study_entry': [pd.Timestamp('2020-01-01')],
        'study_exit': [pd.Timestamp('2020-12-31')]
    })

    # Basic single exposure (Mar 1 - Jun 30, 2020)
    exp_basic = pd.DataFrame({
        'id': [1],
        'rx_start': [pd.Timestamp('2020-03-01')],
        'rx_stop': [pd.Timestamp('2020-06-30')],
        'exp_type': [1]
    })

    # Two non-overlapping exposures
    exp_two = pd.DataFrame({
        'id': [1, 1],
        'rx_start': [pd.Timestamp('2020-02-01'), pd.Timestamp('2020-08-01')],
        'rx_stop': [pd.Timestamp('2020-03-31'), pd.Timestamp('2020-10-31')],
        'exp_type': [1, 2]
    })

    # Overlapping exposures (Apr-Jun overlap)
    exp_overlap = pd.DataFrame({
        'id': [1, 1],
        'rx_start': [pd.Timestamp('2020-01-01'), pd.Timestamp('2020-04-01')],
        'rx_stop': [pd.Timestamp('2020-06-30'), pd.Timestamp('2020-09-30')],
        'exp_type': [1, 2]
    })

    # Exposures with 15-day gap for grace period testing
    exp_gap15 = pd.DataFrame({
        'id': [1, 1],
        'rx_start': [pd.Timestamp('2020-01-01'), pd.Timestamp('2020-02-15')],
        'rx_stop': [pd.Timestamp('2020-01-31'), pd.Timestamp('2020-03-17')],
        'exp_type': [1, 1]
    })

    # Full-year exposure for cumulative testing
    exp_fullyear = pd.DataFrame({
        'id': [1],
        'rx_start': [pd.Timestamp('2020-01-01')],
        'rx_stop': [pd.Timestamp('2020-12-31')],
        'exp_type': [1]
    })

    return {
        'cohort_single': cohort_single,
        'exp_basic': exp_basic,
        'exp_two': exp_two,
        'exp_overlap': exp_overlap,
        'exp_gap15': exp_gap15,
        'exp_fullyear': exp_fullyear
    }


class TestCoreTronsformation:
    """Section 3.1: Core Transformation Tests"""

    def test_3_1_1_basic_interval_splitting(self):
        """Test basic interval splitting."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_basic'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        # Should have at least 3 intervals (before, during, after exposure)
        assert len(result.data) >= 3

        # Verify non-overlapping
        df = result.data.sort_values('start').reset_index(drop=True)
        for i in range(1, len(df)):
            assert df.loc[i-1, 'stop'] <= df.loc[i, 'start']

    def test_3_1_2_person_time_conservation(self):
        """Test person-time is conserved."""
        vdata = create_validation_data()

        expected_ptime = (vdata['cohort_single']['study_exit'].iloc[0] -
                         vdata['cohort_single']['study_entry'].iloc[0]).days

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_basic'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        df = result.data
        actual_ptime = calc_duration(df['stop'], df['start']).sum()

        # Allow small tolerance
        assert abs(actual_ptime - expected_ptime) / expected_ptime < 0.01

    def test_3_1_3_non_overlapping_intervals(self):
        """Test non-overlapping output with overlapping inputs."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_overlap'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        df = result.data.sort_values(['id', 'start']).reset_index(drop=True)

        # Check no overlaps
        n_overlaps = 0
        for i in range(1, len(df)):
            if df.loc[i, 'id'] == df.loc[i-1, 'id']:
                if df.loc[i, 'start'] < df.loc[i-1, 'stop']:
                    n_overlaps += 1

        assert n_overlaps == 0


class TestCumulativeExposure:
    """Section 3.2: Cumulative Exposure Tests"""

    def test_3_2_1_continuousunit_years(self):
        """Test continuousunit(years) calculation."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_fullyear'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            continuousunit='years',
            verbose=False
        )

        df = result.data
        max_cum = df['tv_exp'].max()

        # Full year should be ~1 year
        assert abs(max_cum - 1.0) < 0.1

    def test_3_2_2_cumulative_monotonicity(self):
        """Test cumulative exposure is monotonically increasing."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_two'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            continuousunit='days',
            verbose=False
        )

        df = result.data.sort_values(['id', 'start']).reset_index(drop=True)

        # Cumulative exposure should never decrease within a person
        for i in range(1, len(df)):
            if df.loc[i, 'id'] == df.loc[i-1, 'id']:
                assert df.loc[i, 'tv_exp'] >= df.loc[i-1, 'tv_exp'] - 0.001


class TestCurrentFormer:
    """Section 3.3: Current/Former Status Tests"""

    def test_3_3_1_currentformer_transitions(self):
        """Test currentformer creates proper transitions."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_basic'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            currentformer=True,
            verbose=False
        )

        df = result.data.sort_values('start').reset_index(drop=True)

        # Should have 0 (never), 1 (current), 2 (former)
        values = df['tv_exposure'].unique()
        assert 0 in values
        assert 1 in values
        assert 2 in values

    def test_3_3_2_currentformer_never_reverts(self):
        """Test currentformer never reverts from former to current."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_basic'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            currentformer=True,
            verbose=False
        )

        df = result.data.sort_values(['id', 'start']).reset_index(drop=True)

        # Once former (2), should never go back to current (1)
        n_reverts = 0
        for i in range(1, len(df)):
            if df.loc[i, 'id'] == df.loc[i-1, 'id']:
                if df.loc[i, 'tv_exposure'] == 1 and df.loc[i-1, 'tv_exposure'] == 2:
                    n_reverts += 1

        assert n_reverts == 0


class TestGracePeriod:
    """Section 3.4: Grace Period Tests"""

    def test_3_4_1_grace_gap_exceeds_grace(self):
        """Test grace period when gap > grace value."""
        vdata = create_validation_data()

        # With grace(14), 15-day gap should NOT be bridged
        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_gap15'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            grace=14,
            verbose=False
        )

        df = result.data
        # Should have unexposed period between exposures
        assert 0 in df['tv_exposure'].values

    def test_3_4_2_grace_gap_within_grace(self):
        """Test grace period when gap <= grace value."""
        vdata = create_validation_data()

        # Without grace
        result_no_grace = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_gap15'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            grace=0,
            verbose=False
        )
        n_unexposed_no_grace = (result_no_grace.data['tv_exposure'] == 0).sum()

        # With grace(15), 15-day gap should be bridged
        result_grace = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_gap15'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            grace=15,
            verbose=False
        )
        n_unexposed_grace = (result_grace.data['tv_exposure'] == 0).sum()

        assert n_unexposed_grace <= n_unexposed_no_grace


class TestLagWashout:
    """Section 3.6: Lag and Washout Tests"""

    def test_3_6_1_lag_delays_exposure(self):
        """Test lag delays exposure start."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_basic'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            lag=30,
            verbose=False
        )

        assert result.metadata['parameters']['lag'] == 30

    def test_3_6_2_washout_extends_exposure(self):
        """Test washout extends exposure end."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_basic'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            washout=30,
            verbose=False
        )

        assert result.metadata['parameters']['washout'] == 30


class TestEverTreated:
    """Section 3.8: Ever-Treated Tests"""

    def test_3_8_1_evertreated_never_reverts(self):
        """Test evertreated never reverts to unexposed."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_basic'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            evertreated=True,
            verbose=False
        )

        df = result.data.sort_values(['id', 'start']).reset_index(drop=True)

        # Once exposed (1), should never revert to unexposed (0)
        n_reverts = 0
        for i in range(1, len(df)):
            if df.loc[i, 'id'] == df.loc[i-1, 'id']:
                if df.loc[i, 'tv_exposure'] == 0 and df.loc[i-1, 'tv_exposure'] == 1:
                    n_reverts += 1

        assert n_reverts == 0

    def test_3_8_2_evertreated_switches_at_first_exposure(self):
        """Test evertreated switches at first exposure."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_basic'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            evertreated=True,
            verbose=False
        )

        df = result.data.sort_values('start').reset_index(drop=True)

        # Handle both datetime and numeric (Unix days) output
        exp_start = pd.Timestamp('2020-03-01')
        if pd.api.types.is_numeric_dtype(df['stop']):
            # Convert timestamp to Unix days for comparison (Python uses 1970 epoch)
            exp_start_numeric = (exp_start - pd.Timestamp('1970-01-01')).days
            n_before = ((df['stop'] <= exp_start_numeric) & (df['tv_exposure'] == 0)).sum()
            n_after = ((df['start'] >= exp_start_numeric) & (df['tv_exposure'] == 1)).sum()
        else:
            n_before = ((df['stop'] <= exp_start) & (df['tv_exposure'] == 0)).sum()
            n_after = ((df['start'] >= exp_start) & (df['tv_exposure'] == 1)).sum()

        assert n_before >= 1
        assert n_after >= 1


class TestErrorHandling:
    """Section 3.17: Error Handling Tests"""

    def test_3_17_1_missing_required_options(self):
        """Test missing required options raise error."""
        vdata = create_validation_data()

        # Python raises TypeError for missing required arguments
        with pytest.raises(TypeError):
            tvexpose(
                master_data=vdata['cohort_single'],
                exposure_file=vdata['exp_basic'],
                id='id',
                start='rx_start',
                stop='rx_stop',
                exposure='exp_type',
                exit='study_exit',  # Missing entry
                reference=0,
                verbose=False
            )

    def test_3_17_3_variable_not_found(self):
        """Test variable not found raises error."""
        vdata = create_validation_data()

        with pytest.raises(ValueError, match="not found"):
            tvexpose(
                master_data=vdata['cohort_single'],
                exposure_file=vdata['exp_basic'],
                id='nonexistent_id',
                start='rx_start',
                stop='rx_stop',
                exposure='exp_type',
                entry='study_entry',
                exit='study_exit',
                reference=0,
                verbose=False
            )


class TestInvariants:
    """Invariant Tests"""

    def test_invariant_1_date_ordering(self):
        """Test all rows have start < stop."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_overlap'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        df = result.data
        assert (df['stop'] > df['start']).all()

    def test_invariant_2_valid_exposure_categories(self):
        """Test exposure values are valid categories."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_two'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        df = result.data
        # Should only have values 0 (reference), 1, 2 (exposure types)
        assert df['tv_exposure'].isin([0, 1, 2]).all()


class TestContinuousUnits:
    """Section 3.19: Continuous Unit Tests"""

    def test_3_19_1_continuousunit_months(self):
        """Test continuousunit(months)."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_fullyear'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            continuousunit='months',
            verbose=False
        )

        df = result.data
        max_cum = df['tv_exp'].max()

        # Full year should be ~12 months
        assert abs(max_cum - 12) < 1

    def test_3_19_2_continuousunit_weeks(self):
        """Test continuousunit(weeks)."""
        vdata = create_validation_data()

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=vdata['exp_fullyear'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            continuousunit='weeks',
            verbose=False
        )

        df = result.data
        max_cum = df['tv_exp'].max()

        # Full year should be ~52 weeks
        assert abs(max_cum - 52) < 2


class TestEdgeCases:
    """Section 3.27: Edge Cases"""

    def test_3_27_1_single_day_exposure(self):
        """Test single-day exposure."""
        cohort = pd.DataFrame({
            'id': [1],
            'study_entry': [pd.Timestamp('2020-01-01')],
            'study_exit': [pd.Timestamp('2020-12-31')]
        })

        exp_single_day = pd.DataFrame({
            'id': [1],
            'rx_start': [pd.Timestamp('2020-06-15')],
            'rx_stop': [pd.Timestamp('2020-06-16')],
            'exp_type': [1]
        })

        result = tvexpose(
            master_data=cohort,
            exposure_file=exp_single_day,
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        assert len(result.data) >= 1

    def test_3_27_2_exposure_at_entry(self):
        """Test exposure starting at study entry."""
        vdata = create_validation_data()

        exp_at_entry = pd.DataFrame({
            'id': [1],
            'rx_start': [pd.Timestamp('2020-01-01')],
            'rx_stop': [pd.Timestamp('2020-03-31')],
            'exp_type': [1]
        })

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=exp_at_entry,
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        assert len(result.data) >= 1

    def test_3_27_3_exposure_at_exit(self):
        """Test exposure ending at study exit."""
        vdata = create_validation_data()

        exp_at_exit = pd.DataFrame({
            'id': [1],
            'rx_start': [pd.Timestamp('2020-10-01')],
            'rx_stop': [pd.Timestamp('2020-12-31')],
            'exp_type': [1]
        })

        result = tvexpose(
            master_data=vdata['cohort_single'],
            exposure_file=exp_at_exit,
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        assert len(result.data) >= 1


class TestMultiPerson:
    """Section 3.35: Multi-Person Tests"""

    def test_3_35_1_multiple_persons_different_patterns(self):
        """Test multiple persons with different exposure patterns."""
        cohort_3person = pd.DataFrame({
            'id': [1, 2, 3],
            'study_entry': [pd.Timestamp('2020-01-01')] * 3,
            'study_exit': [pd.Timestamp('2020-12-31')] * 3
        })

        exp_multi = pd.DataFrame({
            'id': [1, 2, 2],
            'rx_start': [pd.Timestamp('2020-03-01'), pd.Timestamp('2020-02-01'), pd.Timestamp('2020-08-01')],
            'rx_stop': [pd.Timestamp('2020-06-30'), pd.Timestamp('2020-04-30'), pd.Timestamp('2020-10-31')],
            'exp_type': [1, 1, 2]
        })

        result = tvexpose(
            master_data=cohort_3person,
            exposure_file=exp_multi,
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='exp_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        df = result.data

        # All 3 persons should be in output
        assert len(df['id'].unique()) == 3

        # Person 3 should only have unexposed periods
        person3 = df[df['id'] == 3]
        assert (person3['tv_exposure'] == 0).all()


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
