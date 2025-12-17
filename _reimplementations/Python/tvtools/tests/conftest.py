"""
Pytest configuration and shared fixtures for tvtools tests.

This module contains pytest fixtures used across all test modules.
"""

import pytest
import pandas as pd
import numpy as np
from datetime import datetime, timedelta


@pytest.fixture
def sample_cohort_data():
    """
    Sample cohort/master data for testing.

    Returns a DataFrame with:
    - id: person identifier
    - study_entry: study entry date
    - study_exit: study exit date
    - age: person age
    - sex: person sex
    """
    return pd.DataFrame({
        'id': [1, 2, 3, 4, 5],
        'study_entry': pd.to_datetime([
            '2020-01-01', '2020-01-01', '2020-01-01',
            '2020-01-01', '2020-01-01'
        ]),
        'study_exit': pd.to_datetime([
            '2020-12-31', '2020-12-31', '2020-12-31',
            '2020-12-31', '2020-12-31'
        ]),
        'age': [50, 60, 45, 55, 65],
        'sex': ['F', 'M', 'F', 'M', 'F']
    })


@pytest.fixture
def sample_exposure_data():
    """
    Sample exposure data for testing.

    Returns a DataFrame with:
    - id: person identifier
    - rx_start: prescription start date
    - rx_stop: prescription stop date
    - drug_type: drug type (1, 2, 3, etc.)
    """
    return pd.DataFrame({
        'id': [1, 1, 2, 2, 3],
        'rx_start': pd.to_datetime([
            '2020-03-01', '2020-06-01', '2020-04-01',
            '2020-08-01', '2020-02-01'
        ]),
        'rx_stop': pd.to_datetime([
            '2020-04-30', '2020-07-31', '2020-06-30',
            '2020-09-30', '2020-11-30'
        ]),
        'drug_type': [1, 2, 1, 1, 2]
    })


@pytest.fixture
def sample_events_data():
    """
    Sample events data for testing.

    Returns a DataFrame with:
    - id: person identifier
    - event_date: primary event date
    - death_date: competing risk (death) date
    - diagnosis_code: diagnosis code
    """
    return pd.DataFrame({
        'id': [1, 2, 3],
        'event_date': pd.to_datetime(['2020-05-15', '2020-07-01', pd.NaT]),
        'death_date': pd.to_datetime(['2020-11-01', pd.NaT, '2020-10-15']),
        'diagnosis_code': ['A01', 'B02', 'C03']
    })


@pytest.fixture
def sample_intervals_data():
    """
    Sample time-varying intervals data (output from tvexpose/tvmerge).

    Returns a DataFrame with:
    - id: person identifier
    - start: interval start date
    - stop: interval stop date
    - exposure: exposure value
    - cumulative_dose: continuous variable
    """
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
        'cumulative_dose': [0.0, 100.0, 300.0, 0.0, 0.0]
    })


@pytest.fixture
def overlapping_exposure_data():
    """
    Exposure data with overlapping periods for testing overlap resolution.

    Returns a DataFrame with:
    - id: person identifier
    - rx_start: prescription start date
    - rx_stop: prescription stop date
    - drug_type: drug type
    """
    return pd.DataFrame({
        'id': [1, 1, 2, 2],
        'rx_start': pd.to_datetime([
            '2020-01-01', '2020-01-15', '2020-03-01', '2020-03-10'
        ]),
        'rx_stop': pd.to_datetime([
            '2020-01-31', '2020-02-15', '2020-04-30', '2020-05-15'
        ]),
        'drug_type': [1, 2, 1, 1]
    })


@pytest.fixture
def continuous_exposure_data():
    """
    Exposure data with continuous variables (e.g., dose) for testing.

    Returns a DataFrame with:
    - id: person identifier
    - exp_start: exposure start date
    - exp_stop: exposure stop date
    - dose: continuous dose variable
    - intensity: continuous intensity variable
    """
    return pd.DataFrame({
        'id': [1, 1, 2],
        'exp_start': pd.to_datetime(['2020-01-01', '2020-03-01', '2020-02-01']),
        'exp_stop': pd.to_datetime(['2020-02-29', '2020-04-30', '2020-05-31']),
        'dose': [100.0, 150.0, 200.0],
        'intensity': [1.0, 1.5, 2.0]
    })


@pytest.fixture
def multi_event_data():
    """
    Sample data with multiple events per person (for recurring events).

    Returns a DataFrame with:
    - id: person identifier
    - event_date: event occurrence date
    - event_type: type of event
    """
    return pd.DataFrame({
        'id': [1, 1, 1, 2, 2, 3],
        'event_date': pd.to_datetime([
            '2020-02-15', '2020-05-20', '2020-08-10',
            '2020-03-01', '2020-07-15', '2020-10-01'
        ]),
        'event_type': ['A', 'B', 'A', 'A', 'A', 'C']
    })


@pytest.fixture
def competing_risk_data():
    """
    Sample data with competing risks for testing.

    Returns a DataFrame with:
    - id: person identifier
    - event_date: primary event date
    - death_date: death date (competing risk)
    - emigration_date: emigration date (competing risk)
    """
    return pd.DataFrame({
        'id': [1, 2, 3, 4, 5],
        'event_date': pd.to_datetime(['2020-06-15', pd.NaT, '2020-09-01', pd.NaT, pd.NaT]),
        'death_date': pd.to_datetime([pd.NaT, '2020-08-20', pd.NaT, pd.NaT, '2020-11-15']),
        'emigration_date': pd.to_datetime([pd.NaT, pd.NaT, pd.NaT, '2020-10-01', pd.NaT])
    })


@pytest.fixture
def large_cohort_data():
    """
    Large cohort dataset for performance testing.

    Returns a DataFrame with 1000 individuals and 5-year followup.
    """
    n = 1000
    np.random.seed(42)

    return pd.DataFrame({
        'id': range(1, n + 1),
        'study_entry': pd.to_datetime(['2015-01-01'] * n),
        'study_exit': pd.to_datetime(['2019-12-31'] * n),
        'age': np.random.randint(18, 90, n),
        'sex': np.random.choice(['M', 'F'], n),
        'region': np.random.choice(['North', 'South', 'East', 'West'], n)
    })


@pytest.fixture
def large_exposure_data():
    """
    Large exposure dataset for performance testing.

    Returns a DataFrame with multiple exposures per person.
    """
    n_persons = 1000
    n_exposures_per_person = 5
    np.random.seed(42)

    ids = np.repeat(range(1, n_persons + 1), n_exposures_per_person)

    # Generate random start dates in 2015-2019
    base_date = pd.to_datetime('2015-01-01')
    start_offsets = np.random.randint(0, 365 * 5, len(ids))
    rx_start = base_date + pd.to_timedelta(start_offsets, unit='D')

    # Generate stop dates 30-180 days after start
    duration = np.random.randint(30, 180, len(ids))
    rx_stop = rx_start + pd.to_timedelta(duration, unit='D')

    return pd.DataFrame({
        'id': ids,
        'rx_start': rx_start,
        'rx_stop': rx_stop,
        'drug_type': np.random.choice([1, 2, 3], len(ids)),
        'dose': np.random.uniform(50, 200, len(ids))
    })


@pytest.fixture
def numeric_interval_data():
    """
    Sample interval data with numeric (integer) time periods instead of dates.

    Returns a DataFrame with:
    - id: person identifier
    - start: interval start (days from baseline)
    - stop: interval stop (days from baseline)
    - exposure: exposure value
    """
    return pd.DataFrame({
        'id': [1, 1, 1, 2, 2, 2],
        'start': [0, 30, 90, 0, 60, 120],
        'stop': [29, 89, 179, 59, 119, 179],
        'exposure': [0, 1, 0, 1, 0, 1]
    })


@pytest.fixture
def merge_dataset_1():
    """
    First dataset for TVMerge testing.

    Returns a DataFrame with categorical exposure variable.
    """
    return pd.DataFrame({
        'id': [1, 1, 1, 2, 2],
        'start': [0, 10, 20, 0, 15],
        'stop': [9, 19, 29, 14, 29],
        'treatment': ['A', 'B', 'A', 'A', 'B']
    })


@pytest.fixture
def merge_dataset_2():
    """
    Second dataset for TVMerge testing.

    Returns a DataFrame with numeric exposure variable.
    """
    return pd.DataFrame({
        'id': [1, 1, 2, 2, 2],
        'start': [0, 8, 0, 10, 20],
        'stop': [7, 19, 9, 19, 29],
        'dose': [100, 200, 100, 150, 200]
    })


@pytest.fixture
def merge_dataset_3():
    """
    Third dataset for TVMerge testing (for 3-way merges).

    Returns a DataFrame with binary exposure variable.
    """
    return pd.DataFrame({
        'id': [1, 1, 2, 2],
        'start': [0, 12, 0, 16],
        'stop': [11, 29, 15, 29],
        'comorbidity': [0, 1, 0, 1]
    })


@pytest.fixture
def datetime_intervals():
    """
    Interval data with datetime periods for testing datetime handling.

    Returns a DataFrame with datetime start/stop columns.
    """
    return pd.DataFrame({
        'id': [1, 1, 2],
        'start': pd.to_datetime(['2020-01-01', '2020-06-01', '2020-03-01']),
        'stop': pd.to_datetime(['2020-05-31', '2020-12-31', '2020-09-30']),
        'exposure': ['A', 'B', 'A']
    })


@pytest.fixture
def point_in_time_events():
    """
    Point-in-time event data (start == stop) for testing.

    Returns a DataFrame with single-day observations.
    """
    return pd.DataFrame({
        'id': [1, 2, 3],
        'event_date': pd.to_datetime(['2020-03-15', '2020-06-20', '2020-09-10']),
        'lab_value': [125.5, 98.3, 110.7]
    })


@pytest.fixture
def missing_data_sample():
    """
    Sample data with missing values for testing data cleaning.

    Returns a DataFrame with various types of missing data.
    """
    return pd.DataFrame({
        'id': [1, 2, 3, 4, 5],
        'start': pd.to_datetime(['2020-01-01', '2020-01-01', pd.NaT, '2020-01-01', '2020-01-01']),
        'stop': pd.to_datetime(['2020-12-31', pd.NaT, '2020-12-31', '2020-12-31', '2020-12-31']),
        'exposure': [1, 2, np.nan, 1, 2],
        'dose': [100.0, np.nan, 150.0, 200.0, np.nan]
    })


# Additional helper fixtures for specific test scenarios

@pytest.fixture
def empty_dataframe():
    """Empty DataFrame for testing edge cases."""
    return pd.DataFrame()


@pytest.fixture
def single_person_data():
    """Single person cohort data for simple test cases."""
    return pd.DataFrame({
        'id': [1],
        'study_entry': pd.to_datetime(['2020-01-01']),
        'study_exit': pd.to_datetime(['2020-12-31']),
        'age': [50],
        'sex': ['F']
    })


@pytest.fixture
def single_exposure_data():
    """Single exposure record for simple test cases."""
    return pd.DataFrame({
        'id': [1],
        'rx_start': pd.to_datetime(['2020-03-01']),
        'rx_stop': pd.to_datetime(['2020-06-30']),
        'drug_type': [1]
    })


@pytest.fixture
def adjacent_periods_data():
    """
    Exposure data with adjacent (non-overlapping) periods for merge testing.

    Returns a DataFrame with periods that touch but don't overlap.
    """
    return pd.DataFrame({
        'id': [1, 1, 1],
        'exp_start': pd.to_datetime(['2020-01-01', '2020-02-01', '2020-03-01']),
        'exp_stop': pd.to_datetime(['2020-01-31', '2020-02-28', '2020-03-31']),
        'drug_type': [1, 1, 1]  # Same type - may be merged with grace period
    })


@pytest.fixture
def gap_periods_data():
    """
    Exposure data with gaps between periods for grace period testing.

    Returns a DataFrame with various gap sizes.
    """
    return pd.DataFrame({
        'id': [1, 1, 1],
        'exp_start': pd.to_datetime(['2020-01-01', '2020-02-01', '2020-04-01']),
        'exp_stop': pd.to_datetime(['2020-01-15', '2020-02-20', '2020-04-30']),
        'drug_type': [1, 1, 1]  # Same type - gaps vary
    })


# Parametrized fixture for testing multiple scenarios

@pytest.fixture(params=['categorical', 'numeric', 'binary'])
def exposure_type_data(request):
    """
    Parametrized fixture that provides different exposure data types.

    Yields exposure data with categorical, numeric, or binary values.
    """
    if request.param == 'categorical':
        return pd.DataFrame({
            'id': [1, 1, 2],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-06-01', '2020-03-01']),
            'exp_stop': pd.to_datetime(['2020-05-31', '2020-12-31', '2020-09-30']),
            'exposure': ['A', 'B', 'A']
        })
    elif request.param == 'numeric':
        return pd.DataFrame({
            'id': [1, 1, 2],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-06-01', '2020-03-01']),
            'exp_stop': pd.to_datetime(['2020-05-31', '2020-12-31', '2020-09-30']),
            'exposure': [100.0, 200.0, 150.0]
        })
    else:  # binary
        return pd.DataFrame({
            'id': [1, 1, 2],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-06-01', '2020-03-01']),
            'exp_stop': pd.to_datetime(['2020-05-31', '2020-12-31', '2020-09-30']),
            'exposure': [0, 1, 1]
        })
