"""
Tests for tvmerge module.

This module contains comprehensive tests for TVMerge class and related
functionality for merging multiple time-varying datasets.
"""

import pytest
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from tvtools.tvmerge import TVMerge, TVMergeError, IDMismatchError


class TestBasicMerge:
    """Test basic two-dataset merge functionality."""

    def test_two_dataset_merge(self):
        """Test basic two-dataset merge."""
        # Create test data
        df1 = pd.DataFrame({
            'id': [1, 1, 2, 2],
            'start': [0, 10, 0, 15],
            'stop': [9, 19, 14, 29],
            'exp1': ['A', 'B', 'A', 'B'],
        })

        df2 = pd.DataFrame({
            'id': [1, 1, 2, 2],
            'start': [0, 5, 0, 10],
            'stop': [4, 19, 9, 29],
            'exp2': [1, 2, 1, 2],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp1', 'exp2'],
        )

        result = merger.merge()

        # Assertions
        assert len(result) > 0
        assert set(result.columns) >= {'id', 'start', 'stop', 'exp1', 'exp2'}
        assert result['id'].nunique() == 2

        # Check specific intersection
        person1_a1 = result[(result['id'] == 1) & (result['exp1'] == 'A') & (result['exp2'] == 1)]
        assert len(person1_a1) == 1
        assert person1_a1.iloc[0]['start'] == 0
        assert person1_a1.iloc[0]['stop'] == 4

    def test_three_dataset_merge(self):
        """Test merging three datasets."""
        df1 = pd.DataFrame({
            'id': [1, 1],
            'start': [0, 10],
            'stop': [9, 19],
            'exp1': ['A', 'B'],
        })

        df2 = pd.DataFrame({
            'id': [1, 1],
            'start': [0, 5],
            'stop': [4, 19],
            'exp2': [1, 2],
        })

        df3 = pd.DataFrame({
            'id': [1, 1],
            'start': [0, 7],
            'stop': [6, 19],
            'exp3': ['X', 'Y'],
        })

        merger = TVMerge(
            datasets=[df1, df2, df3],
            id_col='id',
            start_cols=['start', 'start', 'start'],
            stop_cols=['stop', 'stop', 'stop'],
            exposure_cols=['exp1', 'exp2', 'exp3'],
        )

        result = merger.merge()

        assert len(result) > 0
        assert set(result.columns) >= {'id', 'start', 'stop', 'exp1', 'exp2', 'exp3'}


class TestOutputNaming:
    """Test output column naming options."""

    def test_output_naming(self):
        """Test custom output names."""
        df1 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],
            'exp': ['A'],
        })

        df2 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],
            'exp': [1],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
            output_names=['treatment', 'dose'],
        )

        result = merger.merge()

        assert 'treatment' in result.columns
        assert 'dose' in result.columns
        assert 'exp' not in result.columns

    def test_prefix_naming(self):
        """Test prefix naming."""
        df1 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],
            'exp1': ['A'],
        })

        df2 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],
            'exp2': [1],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp1', 'exp2'],
            prefix='var_',
        )

        result = merger.merge()

        assert 'var_exp1' in result.columns
        assert 'var_exp2' in result.columns


class TestContinuousExposure:
    """Test continuous exposure prorating."""

    def test_continuous_exposure(self):
        """Test continuous exposure prorating."""
        df1 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],  # 11 days
            'exp1': ['A'],
        })

        df2 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],  # 11 days
            'dose': [110.0],  # Total dose for period
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp1', 'dose'],
            continuous=['dose'],
        )

        result = merger.merge()

        # Should have dose (original) and dose_period (prorated amount)
        assert 'dose' in result.columns
        assert 'dose_period' in result.columns

        # Full overlap: dose should be original value
        assert result['dose'].iloc[0] == 110.0

    def test_continuous_partial_overlap(self):
        """Test continuous exposure with partial overlap."""
        df1 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],  # 11 days
            'exp1': ['A'],
        })

        df2 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [4],  # 5 days
            'dose': [100.0],  # Total dose for 5 days
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp1', 'dose'],
            continuous=['dose'],
        )

        result = merger.merge()

        # Intersection is 0-4 (5 days)
        assert result['start'].iloc[0] == 0
        assert result['stop'].iloc[0] == 4

        # Proportion should be 5/5 = 1.0, so dose_period = dose * 1.0
        expected_period = 100.0 * 1.0
        assert np.isclose(result['dose_period'].iloc[0], expected_period)

    def test_continuous_multiple_variables(self):
        """Test multiple continuous variables."""
        df1 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],
            'dose1': [100.0],
        })

        df2 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],
            'dose2': [200.0],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['dose1', 'dose2'],
            continuous=['dose1', 'dose2'],
        )

        result = merger.merge()

        assert 'dose1' in result.columns
        assert 'dose1_period' in result.columns
        assert 'dose2' in result.columns
        assert 'dose2_period' in result.columns


class TestValidation:
    """Test input validation."""

    def test_insufficient_datasets(self):
        """Test error on < 2 datasets."""
        with pytest.raises(TVMergeError, match="at least 2 datasets"):
            TVMerge(
                datasets=[pd.DataFrame()],
                id_col='id',
                start_cols=['start'],
                stop_cols=['stop'],
                exposure_cols=['exp'],
            )

    def test_column_count_mismatch(self):
        """Test error on column count mismatch."""
        with pytest.raises(TVMergeError, match="must equal number of datasets"):
            TVMerge(
                datasets=[pd.DataFrame(), pd.DataFrame()],
                id_col='id',
                start_cols=['start'],  # Only 1, need 2
                stop_cols=['stop', 'stop'],
                exposure_cols=['exp', 'exp'],
            )

    def test_conflicting_naming_options(self):
        """Test error on both output_names and prefix."""
        with pytest.raises(TVMergeError, match="Specify either output_names or prefix"):
            TVMerge(
                datasets=[pd.DataFrame(), pd.DataFrame()],
                id_col='id',
                start_cols=['start', 'start'],
                stop_cols=['stop', 'stop'],
                exposure_cols=['exp', 'exp'],
                output_names=['a', 'b'],
                prefix='var_',
            )

    def test_id_mismatch_strict(self):
        """Test error on ID mismatch with strict_ids=True."""
        df1 = pd.DataFrame({
            'id': [1, 2],
            'start': [0, 0],
            'stop': [10, 10],
            'exp': ['A', 'A'],
        })

        df2 = pd.DataFrame({
            'id': [1, 3],  # ID 3 not in df1, ID 2 not in df2
            'start': [0, 0],
            'stop': [10, 10],
            'exp': [1, 1],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
            strict_ids=True,
        )

        with pytest.raises(IDMismatchError):
            merger.merge()

    def test_id_mismatch_force(self):
        """Test warning on ID mismatch with strict_ids=False."""
        df1 = pd.DataFrame({
            'id': [1, 2],
            'start': [0, 0],
            'stop': [10, 10],
            'exp': ['A', 'A'],
        })

        df2 = pd.DataFrame({
            'id': [1, 3],
            'start': [0, 0],
            'stop': [10, 10],
            'exp': [1, 1],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
            strict_ids=False,  # Allow mismatch
        )

        result = merger.merge()

        # Only ID 1 should remain
        assert result['id'].nunique() == 1
        assert result['id'].iloc[0] == 1

    def test_missing_id_column(self):
        """Test error when ID column missing."""
        df1 = pd.DataFrame({
            'start': [0],
            'stop': [10],
            'exp': ['A'],
        })

        df2 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],
            'exp': [1],
        })

        with pytest.raises(TVMergeError, match="ID column .* not found"):
            TVMerge(
                datasets=[df1, df2],
                id_col='id',
                start_cols=['start', 'start'],
                stop_cols=['stop', 'stop'],
                exposure_cols=['exp', 'exp'],
            )


class TestEdgeCases:
    """Test edge cases."""

    def test_empty_intersection(self):
        """Test datasets with no overlapping periods."""
        df1 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],
            'exp': ['A'],
        })

        df2 = pd.DataFrame({
            'id': [1],
            'start': [20],  # No overlap
            'stop': [30],
            'exp': [1],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
        )

        result = merger.merge()

        # Should return empty DataFrame with correct structure
        assert len(result) == 0
        assert 'id' in result.columns
        assert 'start' in result.columns
        assert 'stop' in result.columns

    def test_single_day_periods(self):
        """Test point-in-time observations (start == stop)."""
        df1 = pd.DataFrame({
            'id': [1],
            'start': [5],
            'stop': [5],  # Single day
            'exp': ['A'],
        })

        df2 = pd.DataFrame({
            'id': [1],
            'start': [5],
            'stop': [5],  # Single day
            'exp': [1],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
        )

        result = merger.merge()

        assert len(result) == 1
        assert result['start'].iloc[0] == 5
        assert result['stop'].iloc[0] == 5

    def test_invalid_periods_dropped(self):
        """Test that invalid periods (start > stop) are dropped."""
        df1 = pd.DataFrame({
            'id': [1, 2],
            'start': [0, 10],  # Second period invalid
            'stop': [10, 5],   # 10 > 5
            'exp': ['A', 'B'],
        })

        df2 = pd.DataFrame({
            'id': [1, 2],
            'start': [0, 0],
            'stop': [10, 10],
            'exp': [1, 2],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
        )

        result = merger.merge()

        # Only ID 1 should have results (ID 2 had invalid period)
        assert result['id'].nunique() == 1
        assert 1 in result['id'].values
        assert 2 not in result['id'].values

    def test_no_common_ids(self):
        """Test when datasets have no IDs in common."""
        df1 = pd.DataFrame({
            'id': [1, 2],
            'start': [0, 0],
            'stop': [10, 10],
            'exp': ['A', 'A'],
        })

        df2 = pd.DataFrame({
            'id': [3, 4],  # Completely different IDs
            'start': [0, 0],
            'stop': [10, 10],
            'exp': [1, 1],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
            strict_ids=False,
        )

        result = merger.merge()

        # Should return empty result
        assert len(result) == 0

    def test_empty_dataset(self):
        """Test with one empty dataset."""
        df1 = pd.DataFrame({
            'id': [1],
            'start': [0],
            'stop': [10],
            'exp': ['A'],
        })

        df2 = pd.DataFrame({
            'id': [],
            'start': [],
            'stop': [],
            'exp': [],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
            strict_ids=False,
        )

        result = merger.merge()

        # Should return empty since no IDs in common
        assert len(result) == 0


class TestDateTimeSupport:
    """Test datetime handling."""

    def test_datetime_periods(self):
        """Test merge with datetime periods."""
        df1 = pd.DataFrame({
            'id': [1, 1],
            'start': pd.to_datetime(['2020-01-01', '2020-06-01']),
            'stop': pd.to_datetime(['2020-05-31', '2020-12-31']),
            'exp1': ['A', 'B'],
        })

        df2 = pd.DataFrame({
            'id': [1, 1],
            'start': pd.to_datetime(['2020-01-01', '2020-04-01']),
            'stop': pd.to_datetime(['2020-03-31', '2020-12-31']),
            'exp2': [1, 2],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp1', 'exp2'],
        )

        result = merger.merge()

        # Check that datetime types are preserved
        assert pd.api.types.is_datetime64_any_dtype(result['start'])
        assert pd.api.types.is_datetime64_any_dtype(result['stop'])

        # Check intersections
        assert len(result) > 0


class TestBatchProcessing:
    """Test batch processing functionality."""

    def test_process_in_batches(self):
        """Test processing large datasets in batches."""
        # Create larger datasets
        n_rows = 1000
        df1 = pd.DataFrame({
            'id': np.repeat(range(100), 10),
            'start': np.tile(range(10), 100) * 10,
            'stop': np.tile(range(10), 100) * 10 + 9,
            'exp1': np.random.choice(['A', 'B', 'C'], n_rows),
        })

        df2 = pd.DataFrame({
            'id': np.repeat(range(100), 10),
            'start': np.tile(range(10), 100) * 10,
            'stop': np.tile(range(10), 100) * 10 + 9,
            'exp2': np.random.choice([1, 2, 3], n_rows),
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp1', 'exp2'],
            batch_size=20,  # Process 20 IDs at a time
        )

        result = merger.merge()

        # Should process all IDs
        assert result['id'].nunique() == 100


class TestDiagnostics:
    """Test diagnostic output."""

    def test_coverage_report(self):
        """Test coverage reporting."""
        df1 = pd.DataFrame({
            'id': [1, 2],
            'start': [0, 0],
            'stop': [10, 10],
            'exp1': ['A', 'A'],
        })

        df2 = pd.DataFrame({
            'id': [1],  # Missing ID 2
            'start': [0],
            'stop': [5],  # Partial coverage
            'exp2': [1],
        })

        merger = TVMerge(
            datasets=[df1, df2],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp1', 'exp2'],
            strict_ids=False,
            report_coverage=True,
        )

        result = merger.merge()

        # Should produce result for ID 1 only
        assert result['id'].nunique() == 1
