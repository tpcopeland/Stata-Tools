"""
Comprehensive tests for tvmerge Python implementation
"""

import pytest
import pandas as pd
import numpy as np
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tvtools import tvexpose, tvmerge

DATA_PATH = "/home/tpcopeland/Stata-Tools/_reimplementations/data/Python"


@pytest.fixture
def test_data():
    """Load test data from pickle files."""
    cohort = pd.read_pickle(f"{DATA_PATH}/cohort.pkl")
    hrt = pd.read_pickle(f"{DATA_PATH}/hrt.pkl")
    dmt = pd.read_pickle(f"{DATA_PATH}/dmt.pkl")
    return {'cohort': cohort, 'hrt': hrt, 'dmt': dmt}


@pytest.fixture
def exposure_data(test_data):
    """Create exposure datasets for merge testing."""
    result1 = tvexpose(
        master_data=test_data['cohort'],
        exposure_file=test_data['hrt'],
        id='id', start='rx_start', stop='rx_stop', exposure='hrt_type',
        entry='study_entry', exit='study_exit', reference=0,
        generate='hrt_exp', verbose=False
    )

    result2 = tvexpose(
        master_data=test_data['cohort'],
        exposure_file=test_data['dmt'],
        id='id', start='dmt_start', stop='dmt_stop', exposure='dmt',
        entry='study_entry', exit='study_exit', reference=0,
        generate='dmt_exp', verbose=False
    )

    return {'ds1': result1.data, 'ds2': result2.data}


class TestTVMergeBasic:
    """Basic functionality tests."""

    def test_basic_merge(self, exposure_data):
        """Test basic two-dataset merge."""
        result = tvmerge(
            datasets=[exposure_data['ds1'], exposure_data['ds2']],
            id='id',
            start=['start', 'start'],
            stop=['stop', 'stop'],
            exposure=['hrt_exp', 'dmt_exp']
        )

        assert result is not None
        assert len(result.data) > 0
        assert 'hrt_exp' in result.data.columns
        assert 'dmt_exp' in result.data.columns
        assert 'start' in result.data.columns
        assert 'stop' in result.data.columns

    def test_generate_option(self, exposure_data):
        """Test generate option for renaming."""
        result = tvmerge(
            datasets=[exposure_data['ds1'], exposure_data['ds2']],
            id='id',
            start=['start', 'start'],
            stop=['stop', 'stop'],
            exposure=['hrt_exp', 'dmt_exp'],
            generate=['hormone', 'drug']
        )

        assert 'hormone' in result.data.columns
        assert 'drug' in result.data.columns

    def test_prefix_option(self, exposure_data):
        """Test prefix option."""
        result = tvmerge(
            datasets=[exposure_data['ds1'], exposure_data['ds2']],
            id='id',
            start=['start', 'start'],
            stop=['stop', 'stop'],
            exposure=['hrt_exp', 'dmt_exp'],
            prefix='tv_'
        )

        assert 'tv_hrt_exp' in result.data.columns
        assert 'tv_dmt_exp' in result.data.columns

    def test_startname_stopname(self, exposure_data):
        """Test custom start/stop names."""
        result = tvmerge(
            datasets=[exposure_data['ds1'], exposure_data['ds2']],
            id='id',
            start=['start', 'start'],
            stop=['stop', 'stop'],
            exposure=['hrt_exp', 'dmt_exp'],
            startname='begin',
            stopname='end'
        )

        assert 'begin' in result.data.columns
        assert 'end' in result.data.columns


class TestTVMergeAdvanced:
    """Advanced option tests."""

    def test_continuous_interpolation(self):
        """Test continuous exposure interpolation."""
        ds1 = pd.DataFrame({
            'id': [1, 1],
            'start': [1, 11],
            'stop': [10, 20],
            'exp1': ['A', 'B']
        })

        ds2 = pd.DataFrame({
            'id': [1],
            'start': [1],
            'stop': [20],
            'dosage': [100]
        })

        result = tvmerge(
            datasets=[ds1, ds2],
            id='id',
            start=['start', 'start'],
            stop=['stop', 'stop'],
            exposure=['exp1', 'dosage'],
            continuous=[1],  # Position 1 (dosage) is continuous
            generate=['category', 'dose']
        )

        # Each interval should have ~50 (100 * 10/20)
        assert abs(result.data['dose'].iloc[0] - 50) < 1
        assert abs(result.data['dose'].iloc[1] - 50) < 1

    def test_force_option(self):
        """Test force option with ID mismatch."""
        ds1 = pd.DataFrame({
            'id': [1, 2],
            'start': [1, 1],
            'stop': [10, 10],
            'exp1': ['A', 'B']
        })

        ds2 = pd.DataFrame({
            'id': [2, 3],
            'start': [1, 1],
            'stop': [10, 10],
            'exp2': ['X', 'Y']
        })

        result = tvmerge(
            datasets=[ds1, ds2],
            id='id',
            start=['start', 'start'],
            stop=['stop', 'stop'],
            exposure=['exp1', 'exp2'],
            force=True
        )

        # Only ID 2 should be in result
        assert list(result.data['id'].unique()) == [2]


class TestTVMergeValidation:
    """Validation tests."""

    def test_minimum_datasets(self):
        """Test minimum 2 datasets required."""
        ds1 = pd.DataFrame({
            'id': [1],
            'start': [1],
            'stop': [10],
            'exp': ['A']
        })

        with pytest.raises(ValueError, match="at least 2"):
            tvmerge(
                datasets=[ds1],
                id='id',
                start=['start'],
                stop=['stop'],
                exposure=['exp']
            )


class TestTVMergeReturns:
    """Return value tests."""

    def test_returns_structure(self, exposure_data):
        """Test proper return structure."""
        result = tvmerge(
            datasets=[exposure_data['ds1'], exposure_data['ds2']],
            id='id',
            start=['start', 'start'],
            stop=['stop', 'stop'],
            exposure=['hrt_exp', 'dmt_exp']
        )

        assert hasattr(result, 'data')
        assert hasattr(result, 'diagnostics')
        assert hasattr(result, 'returns')
        assert 'N' in result.returns
        assert 'N_persons' in result.returns
        assert 'N_datasets' in result.returns


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
