"""Exposure type transformation functions for tvexpose."""

import pandas as pd
import numpy as np
from typing import List

from .types import TimeUnit


def apply_ever_treated(
    df: pd.DataFrame,
    id_col: str,
    reference: int,
    output_col: str
) -> pd.DataFrame:
    """
    Create binary ever-treated variable (0 before first exposure, 1 after).

    The variable switches permanently from 0 to 1 at first non-reference exposure.

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data with columns: id_col, exp_start, exp_value
    id_col : str
        ID column name
    reference : int
        Reference/unexposed value
    output_col : str
        Name for output column

    Returns
    -------
    pd.DataFrame
        Data with ever-treated column added
    """
    df = df.sort_values([id_col, 'exp_start']).copy()

    # Find first non-reference exposure per person
    non_ref = df[df['exp_value'] != reference].copy()
    first_exp = non_ref.groupby(id_col)['exp_start'].min().reset_index()
    first_exp.columns = [id_col, '_first_exp_date']

    df = df.merge(first_exp, on=id_col, how='left')

    # Before first exposure: 0, After (including): 1
    df[output_col] = np.where(
        df['_first_exp_date'].isna() | (df['exp_start'] < df['_first_exp_date']),
        0, 1
    )

    df = df.drop(columns=['_first_exp_date'])
    return df


def apply_current_former(
    df: pd.DataFrame,
    id_col: str,
    reference: int,
    output_col: str
) -> pd.DataFrame:
    """
    Create trichotomous current/former variable.

    Values:
    - 0: Never exposed (no prior exposure)
    - 1: Currently exposed (non-reference value)
    - 2: Formerly exposed (reference value, but had prior exposure)

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    id_col : str
        ID column name
    reference : int
        Reference value
    output_col : str
        Name for output column

    Returns
    -------
    pd.DataFrame
        Data with current/former column added
    """
    df = df.sort_values([id_col, 'exp_start']).copy()

    # Track if person has ever been exposed
    df['_is_exposed'] = (df['exp_value'] != reference).astype(int)
    df['_ever_exposed'] = df.groupby(id_col)['_is_exposed'].cumsum() > 0

    # Shift to get "ever exposed before this period"
    df['_was_exposed'] = df.groupby(id_col)['_ever_exposed'].shift(1).fillna(False)

    # Create trichotomous variable
    conditions = [
        df['exp_value'] != reference,           # Currently exposed
        df['_was_exposed'] | df['_ever_exposed'], # Formerly exposed
    ]
    choices = [1, 2]
    df[output_col] = np.select(conditions, choices, default=0)

    # Clean up
    df = df.drop(columns=[c for c in df.columns if c.startswith('_')])
    return df


def apply_continuous_exposure(
    df: pd.DataFrame,
    id_col: str,
    reference: int,
    output_col: str,
    time_unit: TimeUnit
) -> pd.DataFrame:
    """
    Calculate cumulative exposure in specified time units.

    Creates a continuous variable tracking total time exposed.

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    id_col : str
        ID column name
    reference : int
        Reference value
    output_col : str
        Name for output column
    time_unit : TimeUnit
        Unit for time calculation

    Returns
    -------
    pd.DataFrame
        Data with continuous exposure column added
    """
    df = df.sort_values([id_col, 'exp_start']).copy()

    # Calculate period duration in days
    df['_duration_days'] = (df['exp_stop'] - df['exp_start']).dt.days + 1

    # Only count non-reference periods
    df['_exposed_days'] = np.where(
        df['exp_value'] != reference,
        df['_duration_days'],
        0
    )

    # Cumulative sum within person
    df['_cumul_days'] = df.groupby(id_col)['_exposed_days'].cumsum()

    # Convert to requested unit
    df[output_col] = df['_cumul_days'] / time_unit.days_per_unit

    # Clean up
    df = df.drop(columns=[c for c in df.columns if c.startswith('_')])
    return df


def apply_duration_categories(
    df: pd.DataFrame,
    id_col: str,
    reference: int,
    output_col: str,
    cutpoints: List[float],
    time_unit: TimeUnit
) -> pd.DataFrame:
    """
    Create categorical variable based on cumulative exposure duration.

    Example with cutpoints=[1, 5]:
    - 0: Unexposed
    - 1: <1 unit
    - 2: 1 to <5 units
    - 3: >=5 units

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    id_col : str
        ID column name
    reference : int
        Reference value
    output_col : str
        Name for output column
    cutpoints : List[float]
        Cutpoints for categories
    time_unit : TimeUnit
        Unit for time calculation

    Returns
    -------
    pd.DataFrame
        Data with duration category column added
    """
    # First calculate continuous
    df = apply_continuous_exposure(df, id_col, reference, '_cumul_exp', time_unit)

    # Create categories
    bins = [-np.inf, 0] + cutpoints + [np.inf]
    labels = list(range(len(bins) - 1))

    df[output_col] = pd.cut(
        df['_cumul_exp'],
        bins=bins,
        labels=labels,
        include_lowest=True
    ).astype(int)

    # Unexposed (reference) periods get category 0
    df.loc[df['exp_value'] == reference, output_col] = 0

    df = df.drop(columns=['_cumul_exp'])
    return df
