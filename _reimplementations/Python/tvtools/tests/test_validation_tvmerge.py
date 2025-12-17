"""
Comprehensive validation tests for tvmerge Python implementation
Matches Stata validation tests from _validation/validation_tvmerge.do
"""

import pytest
import pandas as pd
import numpy as np
from datetime import date, timedelta
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tvtools import tvmerge


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


def create_tvmerge_validation_data():
    """Create validation datasets for tvmerge tests."""
    # Dataset 1: Single full-year interval
    ds1_fullyear = pd.DataFrame({
        'id': [1],
        'start1': [pd.Timestamp('2020-01-01')],
        'stop1': [pd.Timestamp('2020-12-31')],
        'exp1': [1]
    })

    # Dataset 2: Two intervals covering the year
    ds2_split = pd.DataFrame({
        'id': [1, 1],
        'start2': [pd.Timestamp('2020-01-01'), pd.Timestamp('2020-07-01')],
        'stop2': [pd.Timestamp('2020-06-30'), pd.Timestamp('2020-12-31')],
        'exp2': [1, 2]
    })

    # Dataset 1: Partial year (Jan-Jun)
    ds1_partial = pd.DataFrame({
        'id': [1],
        'start1': [pd.Timestamp('2020-01-01')],
        'stop1': [pd.Timestamp('2020-06-30')],
        'exp1': [1]
    })

    # Dataset 2: Partial year (Mar-Sep)
    ds2_partial = pd.DataFrame({
        'id': [1],
        'start2': [pd.Timestamp('2020-03-01')],
        'stop2': [pd.Timestamp('2020-09-30')],
        'exp2': [2]
    })

    # Non-overlapping datasets
    ds1_nonoverlap = pd.DataFrame({
        'id': [1],
        'start1': [pd.Timestamp('2020-01-01')],
        'stop1': [pd.Timestamp('2020-03-01')],
        'exp1': [1]
    })

    ds2_nonoverlap = pd.DataFrame({
        'id': [1],
        'start2': [pd.Timestamp('2020-07-01')],
        'stop2': [pd.Timestamp('2020-12-31')],
        'exp2': [2]
    })

    # Datasets with different IDs
    ds1_ids123 = pd.DataFrame({
        'id': [1, 2, 3],
        'start1': [pd.Timestamp('2020-01-01')] * 3,
        'stop1': [pd.Timestamp('2020-12-31')] * 3,
        'exp1': [1, 1, 1]
    })

    ds2_ids234 = pd.DataFrame({
        'id': [2, 3, 4],
        'start2': [pd.Timestamp('2020-01-01')] * 3,
        'stop2': [pd.Timestamp('2020-12-31')] * 3,
        'exp2': [2, 2, 2]
    })

    # Three datasets for three-way merge
    ds3way_1 = pd.DataFrame({
        'id': [1],
        's1': [pd.Timestamp('2020-01-01')],
        'e1': [pd.Timestamp('2020-09-30')],
        'x1': [1]
    })

    ds3way_2 = pd.DataFrame({
        'id': [1],
        's2': [pd.Timestamp('2020-04-01')],
        'e2': [pd.Timestamp('2020-12-31')],
        'x2': [2]
    })

    ds3way_3 = pd.DataFrame({
        'id': [1],
        's3': [pd.Timestamp('2020-06-01')],
        'e3': [pd.Timestamp('2020-12-31')],
        'x3': [3]
    })

    return {
        'ds1_fullyear': ds1_fullyear,
        'ds2_split': ds2_split,
        'ds1_partial': ds1_partial,
        'ds2_partial': ds2_partial,
        'ds1_nonoverlap': ds1_nonoverlap,
        'ds2_nonoverlap': ds2_nonoverlap,
        'ds1_ids123': ds1_ids123,
        'ds2_ids234': ds2_ids234,
        'ds3way_1': ds3way_1,
        'ds3way_2': ds3way_2,
        'ds3way_3': ds3way_3
    }


class TestCartesianProduct:
    """Section 5.1: Cartesian Product Tests"""

    def test_5_1_1_complete_intersection_coverage(self):
        """Test complete intersection coverage."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_fullyear'], vdata['ds2_split']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2']
        )

        # Should produce 2 intervals (Jan-Jun, Jul-Dec)
        assert len(result.data) == 2

    def test_5_1_2_non_overlapping_periods_excluded(self):
        """Test non-overlapping periods are excluded."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_nonoverlap'], vdata['ds2_nonoverlap']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2']
        )

        # Should produce 0 intervals (no overlap)
        assert len(result.data) == 0


class TestPersonTime:
    """Section 5.2: Person-Time Tests"""

    def test_5_2_1_merged_duration_equals_intersection(self):
        """Test merged duration equals intersection."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_partial'], vdata['ds2_partial']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2']
        )

        df = result.data
        df['dur'] = calc_duration(df['stop'], df['start'])
        total_dur = df['dur'].sum()

        # Overlap is Mar 1 - Jun 30 = 122 days
        expected_dur = (pd.Timestamp('2020-06-30') - pd.Timestamp('2020-03-01')).days
        assert abs(total_dur - expected_dur) < 2

    def test_5_2_2_no_overlapping_intervals_in_output(self):
        """Test no overlapping intervals in output."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_fullyear'], vdata['ds2_split']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2']
        )

        df = result.data.sort_values(['id', 'start']).reset_index(drop=True)

        # Check no overlaps
        n_overlaps = 0
        for i in range(1, len(df)):
            if df.loc[i, 'id'] == df.loc[i-1, 'id']:
                if df.loc[i, 'start'] < df.loc[i-1, 'stop']:
                    n_overlaps += 1

        assert n_overlaps == 0


class TestIDMatching:
    """Section 5.4: ID Matching Tests"""

    def test_5_4_1_id_mismatch_without_force(self):
        """Test ID mismatch without force raises error."""
        vdata = create_tvmerge_validation_data()

        with pytest.raises(Exception):
            tvmerge(
                datasets=[vdata['ds1_ids123'], vdata['ds2_ids234']],
                id='id',
                start=['start1', 'start2'],
                stop=['stop1', 'stop2'],
                exposure=['exp1', 'exp2']
            )

    def test_5_4_2_id_intersection_with_force(self):
        """Test ID intersection with force."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_ids123'], vdata['ds2_ids234']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2'],
            force=True
        )

        df = result.data
        unique_ids = df['id'].unique()

        # Only IDs 2 and 3 should appear (intersection)
        assert len(unique_ids) == 2
        assert 2 in unique_ids
        assert 3 in unique_ids
        assert 1 not in unique_ids
        assert 4 not in unique_ids


class TestThreeWayMerge:
    """Section 5.5: Three-Way Merge Tests"""

    def test_5_5_1_three_dataset_intersection(self):
        """Test three dataset intersection."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds3way_1'], vdata['ds3way_2'], vdata['ds3way_3']],
            id='id',
            start=['s1', 's2', 's3'],
            stop=['e1', 'e2', 'e3'],
            exposure=['x1', 'x2', 'x3']
        )

        df = result.data

        # Three-way intersection: Jun 1 - Sep 30
        assert len(df) >= 1

    def test_5_5_2_three_way_merge_duration_calculation(self):
        """Test three-way merge duration calculation."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds3way_1'], vdata['ds3way_2'], vdata['ds3way_3']],
            id='id',
            start=['s1', 's2', 's3'],
            stop=['e1', 'e2', 'e3'],
            exposure=['x1', 'x2', 'x3']
        )

        df = result.data
        df['dur'] = calc_duration(df['stop'], df['start'])
        total_dur = df['dur'].sum()

        # Three-way intersection: Jun 1 - Sep 30 = 122 days
        expected_dur = (pd.Timestamp('2020-09-30') - pd.Timestamp('2020-06-01')).days
        assert abs(total_dur - expected_dur) < 2


class TestOutputOptions:
    """Section 5.6: Output Options Tests"""

    def test_5_6_1_generate_custom_names(self):
        """Test generate creates custom-named variables."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_fullyear'], vdata['ds2_split']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2'],
            generate=['my_exp1', 'my_exp2']
        )

        assert 'my_exp1' in result.data.columns
        assert 'my_exp2' in result.data.columns

    def test_5_6_2_prefix_adds_prefix(self):
        """Test prefix adds prefix to variable names."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_fullyear'], vdata['ds2_split']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2'],
            prefix='tv_'
        )

        # Check for prefixed variables
        assert any(col.startswith('tv_') for col in result.data.columns)

    def test_5_6_3_startname_stopname(self):
        """Test startname and stopname customize date variable names."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_fullyear'], vdata['ds2_split']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2'],
            startname='period_start',
            stopname='period_stop'
        )

        assert 'period_start' in result.data.columns
        assert 'period_stop' in result.data.columns


class TestErrorHandling:
    """Section 5.12: Error Handling Tests"""

    def test_5_12_1_mismatched_start_stop_counts(self):
        """Test mismatched start/stop counts raise error."""
        vdata = create_tvmerge_validation_data()

        with pytest.raises(ValueError):
            tvmerge(
                datasets=[vdata['ds1_fullyear'], vdata['ds2_split']],
                id='id',
                start=['start1'],  # Only 1 start
                stop=['stop1', 'stop2'],  # 2 stops
                exposure=['exp1', 'exp2']
            )

    def test_5_12_2_mismatched_exposure_count(self):
        """Test mismatched exposure count raises error."""
        vdata = create_tvmerge_validation_data()

        with pytest.raises(ValueError):
            tvmerge(
                datasets=[vdata['ds1_fullyear'], vdata['ds2_split']],
                id='id',
                start=['start1', 'start2'],
                stop=['stop1', 'stop2'],
                exposure=['exp1']  # Only 1 exposure
            )


class TestEdgeCases:
    """Section 5.16: Edge Cases"""

    def test_5_16_1_same_day_start_stop(self):
        """Test same-day start and stop intervals."""
        ds1_sameday = pd.DataFrame({
            'id': [1],
            'start1': [pd.Timestamp('2020-06-15')],
            'stop1': [pd.Timestamp('2020-06-16')],
            'exp1': [1]
        })

        ds2_sameday = pd.DataFrame({
            'id': [1],
            'start2': [pd.Timestamp('2020-06-15')],
            'stop2': [pd.Timestamp('2020-06-16')],
            'exp2': [2]
        })

        result = tvmerge(
            datasets=[ds1_sameday, ds2_sameday],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2']
        )

        assert len(result.data) >= 1


class TestUniversalInvariants:
    """Section 5.26: Universal Invariants"""

    def test_5_26_1_output_duration_lte_min_input(self):
        """Test output duration <= minimum input duration."""
        vdata = create_tvmerge_validation_data()

        input1_dur = (vdata['ds1_partial']['stop1'].iloc[0] -
                      vdata['ds1_partial']['start1'].iloc[0]).days
        input2_dur = (vdata['ds2_partial']['stop2'].iloc[0] -
                      vdata['ds2_partial']['start2'].iloc[0]).days
        min_input_dur = min(input1_dur, input2_dur)

        result = tvmerge(
            datasets=[vdata['ds1_partial'], vdata['ds2_partial']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2']
        )

        df = result.data
        df['dur'] = calc_duration(df['stop'], df['start'])
        output_dur = df['dur'].sum()

        assert output_dur <= min_input_dur

    def test_5_26_2_no_output_overlaps_within_person(self):
        """Test no output overlaps within person."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_fullyear'], vdata['ds2_split']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2']
        )

        df = result.data.sort_values(['id', 'start']).reset_index(drop=True)

        n_overlaps = 0
        for i in range(1, len(df)):
            if df.loc[i, 'id'] == df.loc[i-1, 'id']:
                if df.loc[i, 'start'] < df.loc[i-1, 'stop']:
                    n_overlaps += 1

        assert n_overlaps == 0

    def test_5_26_3_output_sorted_by_id_start(self):
        """Test output is sorted by id and start."""
        vdata = create_tvmerge_validation_data()

        result = tvmerge(
            datasets=[vdata['ds1_fullyear'], vdata['ds2_split']],
            id='id',
            start=['start1', 'start2'],
            stop=['stop1', 'stop2'],
            exposure=['exp1', 'exp2']
        )

        df = result.data
        df_sorted = df.sort_values(['id', 'start']).reset_index(drop=True)

        assert df['id'].tolist() == df_sorted['id'].tolist()
        assert df['start'].tolist() == df_sorted['start'].tolist()


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
