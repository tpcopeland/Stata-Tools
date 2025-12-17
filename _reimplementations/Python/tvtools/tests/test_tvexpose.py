"""
Comprehensive tests for tvexpose Python implementation
Based on Stata test suite from _testing/test_tvexpose.do
"""

import pytest
import pandas as pd
import numpy as np
import sys
import os

# Add package to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tvtools import tvexpose

# Test data path
DATA_PATH = "/home/ubuntu/Stata-Tools/_testing/data"


@pytest.fixture
def test_data():
    """Load test data."""
    import pyreadstat
    cohort, _ = pyreadstat.read_dta(f"{DATA_PATH}/cohort.dta")
    hrt, _ = pyreadstat.read_dta(f"{DATA_PATH}/hrt.dta")
    return {'cohort': cohort, 'hrt': hrt}


class TestTVExposeBasic:
    """Basic functionality tests."""

    def test_basic_tvexpose(self, test_data):
        """Test basic time-varying exposure creation."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        assert result is not None
        assert len(result.data) > 0
        assert 'tv_exposure' in result.data.columns
        assert 'start' in result.data.columns
        assert 'stop' in result.data.columns

    def test_custom_generate_name(self, test_data):
        """Test custom generate option."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            generate='my_exposure',
            verbose=False
        )

        assert 'my_exposure' in result.data.columns


class TestTVExposeOptions:
    """Test various options."""

    def test_evertreated(self, test_data):
        """Test ever-treated option."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            evertreated=True,
            verbose=False
        )

        # Ever-treated creates binary 0/1 in tv_exposure column
        assert 'tv_exposure' in result.data.columns
        values = result.data['tv_exposure'].unique()
        assert all(v in [0, 1] for v in values)

    def test_currentformer(self, test_data):
        """Test current/former option."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            currentformer=True,
            verbose=False
        )

        # Current/former creates 0/1/2 in tv_exposure column
        assert 'tv_exposure' in result.data.columns
        values = result.data['tv_exposure'].unique()
        assert all(v in [0, 1, 2] for v in values)

    def test_lag(self, test_data):
        """Test lag option."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            lag=30,
            verbose=False
        )

        assert len(result.data) > 0
        assert result.metadata['parameters']['lag'] == 30

    def test_washout(self, test_data):
        """Test washout option."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            washout=90,
            verbose=False
        )

        assert len(result.data) > 0
        assert result.metadata['parameters']['washout'] == 90

    def test_grace(self, test_data):
        """Test grace period option."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            grace=14,
            verbose=False
        )

        assert len(result.data) > 0

    def test_switching(self, test_data):
        """Test switching indicator option."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            switching=True,
            verbose=False
        )

        assert 'has_switched' in result.data.columns

    def test_keepdates(self, test_data):
        """Test keepdates option."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            keepdates=True,
            verbose=False
        )

        assert 'study_entry' in result.data.columns
        assert 'study_exit' in result.data.columns


class TestTVExposeValidation:
    """Input validation tests."""

    def test_missing_stop_raises(self, test_data):
        """Test that missing stop raises error when not pointtime."""
        with pytest.raises(ValueError, match="stop.*required"):
            tvexpose(
                master_data=test_data['cohort'],
                exposure_file=test_data['hrt'],
                id='id',
                start='rx_start',
                exposure='hrt_type',
                entry='study_entry',
                exit='study_exit',
                reference=0,
                verbose=False
            )

    def test_invalid_column_raises(self, test_data):
        """Test that invalid column names raise error."""
        with pytest.raises(ValueError, match="not found"):
            tvexpose(
                master_data=test_data['cohort'],
                exposure_file=test_data['hrt'],
                id='id',
                start='rx_start',
                stop='rx_stop',
                exposure='invalid_column',
                entry='study_entry',
                exit='study_exit',
                reference=0,
                verbose=False
            )

    def test_mutually_exclusive_options(self, test_data):
        """Test mutually exclusive options raise error."""
        with pytest.raises(ValueError, match="Only one exposure type"):
            tvexpose(
                master_data=test_data['cohort'],
                exposure_file=test_data['hrt'],
                id='id',
                start='rx_start',
                stop='rx_stop',
                exposure='hrt_type',
                entry='study_entry',
                exit='study_exit',
                reference=0,
                evertreated=True,
                currentformer=True,
                verbose=False
            )


class TestTVExposeMetadata:
    """Metadata and return value tests."""

    def test_returns_metadata(self, test_data):
        """Test that metadata is returned."""
        result = tvexpose(
            master_data=test_data['cohort'],
            exposure_file=test_data['hrt'],
            id='id',
            start='rx_start',
            stop='rx_stop',
            exposure='hrt_type',
            entry='study_entry',
            exit='study_exit',
            reference=0,
            verbose=False
        )

        assert result.metadata is not None
        assert 'N_persons' in result.metadata
        assert 'N_periods' in result.metadata
        assert 'parameters' in result.metadata


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
