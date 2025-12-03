"""Core algorithms for tvexpose."""

import pandas as pd
import numpy as np

from .types import GracePeriod


def merge_periods(
    df: pd.DataFrame,
    merge_days: int,
    id_col: str
) -> pd.DataFrame:
    """
    Iteratively merge consecutive same-type periods within merge_days.

    Algorithm:
    1. Sort by id, start, stop, exposure
    2. For each person, identify mergeable pairs (same exposure, gap <= merge_days)
    3. Extend earlier period's stop to encompass later period
    4. Mark subsumed periods for deletion
    5. Repeat until no more merges possible

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data with columns: id, exp_start, exp_stop, exp_value
    merge_days : int
        Maximum gap in days to merge
    id_col : str
        ID column name

    Returns
    -------
    pd.DataFrame
        Merged exposure data
    """
    df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value']).copy()

    max_iterations = 10000
    iteration = 0

    while iteration < max_iterations:
        iteration += 1
        n_before = len(df)

        # Calculate gap to next period of same type
        df['_next_start'] = df.groupby([id_col, 'exp_value'])['exp_start'].shift(-1)
        df['_gap'] = (df['_next_start'] - df['exp_stop']).dt.days - 1

        # Identify mergeable pairs
        df['_can_merge'] = (df['_gap'] <= merge_days) & df['_gap'].notna()

        # Extend stop date to encompass next period
        df['_next_stop'] = df.groupby([id_col, 'exp_value'])['exp_stop'].shift(-1)
        df.loc[df['_can_merge'], 'exp_stop'] = df.loc[df['_can_merge'], ['exp_stop', '_next_stop']].max(axis=1)

        # Mark subsumed periods
        df['_prev_can_merge'] = df.groupby([id_col, 'exp_value'])['_can_merge'].shift(1).fillna(False)
        df['_prev_stop'] = df.groupby([id_col, 'exp_value'])['exp_stop'].shift(1)
        df['_subsumed'] = df['_prev_can_merge'] & (df['exp_stop'] <= df['_prev_stop'])

        # Remove subsumed periods
        df = df[~df['_subsumed']].copy()

        # Clean up temp columns
        df = df.drop(columns=[c for c in df.columns if c.startswith('_')])

        # Check if any merges occurred
        if len(df) == n_before:
            break

        df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value'])

    return df


def remove_contained_periods(df: pd.DataFrame, id_col: str) -> pd.DataFrame:
    """
    Remove periods fully contained within another of same exposure type.

    A period B is contained in A if:
    - Same person, same exposure value
    - B.start >= A.start AND B.stop <= A.stop

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    id_col : str
        ID column name

    Returns
    -------
    pd.DataFrame
        Data with contained periods removed
    """
    df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value']).copy()

    max_iterations = 10000
    iteration = 0

    while iteration < max_iterations:
        iteration += 1
        n_before = len(df)

        # Get previous period boundaries for same type
        df['_prev_start'] = df.groupby([id_col, 'exp_value'])['exp_start'].shift(1)
        df['_prev_stop'] = df.groupby([id_col, 'exp_value'])['exp_stop'].shift(1)

        # Mark contained periods
        df['_contained'] = (
            df['_prev_start'].notna() &
            (df['exp_start'] >= df['_prev_start']) &
            (df['exp_stop'] <= df['_prev_stop'])
        )

        # Remove contained
        df = df[~df['_contained']].copy()
        df = df.drop(columns=[c for c in df.columns if c.startswith('_')])

        if len(df) == n_before:
            break

        df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value'])

    return df


def resolve_overlaps_layer(df: pd.DataFrame, id_col: str) -> pd.DataFrame:
    """
    Resolve overlapping exposures using layer strategy.

    Layer strategy:
    - When exposure B starts while A is active:
      1. Truncate A to end just before B starts (pre-overlap segment)
      2. B takes full precedence during overlap
      3. If A extended beyond B, A resumes after B ends (post-overlap segment)

    Visual example:
        Before:  A: |-------------------|  (days 1-20, type 1)
                 B:      |-------|        (days 5-12, type 2)

        After:   A: |----|                (days 1-4, type 1)
                 B:      |-------|        (days 5-12, type 2)
                 A:               |----| (days 13-20, type 1)

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data with potential overlaps
    id_col : str
        ID column name

    Returns
    -------
    pd.DataFrame
        Data with overlaps resolved
    """
    df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value']).copy()

    max_iterations = 10
    iteration = 0

    while iteration < max_iterations:
        iteration += 1

        # Find overlaps with next different-type period
        df['_next_start'] = df.groupby(id_col)['exp_start'].shift(-1)
        df['_next_stop'] = df.groupby(id_col)['exp_stop'].shift(-1)
        df['_next_value'] = df.groupby(id_col)['exp_value'].shift(-1)

        # Overlap: next period starts before current ends, different type
        df['_has_overlap'] = (
            df['_next_start'].notna() &
            (df['_next_start'] <= df['exp_stop']) &
            (df['exp_value'] != df['_next_value'])
        )

        n_overlaps = df['_has_overlap'].sum()
        if n_overlaps == 0:
            df = df.drop(columns=[c for c in df.columns if c.startswith('_')])
            break

        # Process overlaps
        # Non-overlapping periods kept as-is
        non_overlap = df[~df['_has_overlap']].copy()
        overlap = df[df['_has_overlap']].copy()

        # Pre-overlap segments: current start to next_start - 1
        pre_segments = overlap.copy()
        pre_segments['exp_stop'] = pre_segments['_next_start'] - pd.Timedelta(days=1)

        # Post-overlap segments: next_stop + 1 to current stop (if current extends beyond)
        post_segments = overlap[overlap['exp_stop'] > overlap['_next_stop']].copy()
        post_segments['exp_start'] = post_segments['_next_stop'] + pd.Timedelta(days=1)

        # Keep essential columns
        keep_cols = [id_col, 'exp_start', 'exp_stop', 'exp_value']
        extra_cols = [c for c in df.columns if c not in keep_cols and not c.startswith('_')]
        keep_cols.extend(extra_cols)

        pre_segments = pre_segments[keep_cols]
        post_segments = post_segments[keep_cols]
        non_overlap = non_overlap[[c for c in non_overlap.columns if not c.startswith('_')]]

        # Combine and clean
        df = pd.concat([non_overlap, pre_segments, post_segments], ignore_index=True)
        df = df[df['exp_start'] <= df['exp_stop']]  # Remove invalid periods
        df = df.drop_duplicates(subset=[id_col, 'exp_start', 'exp_stop', 'exp_value'])
        df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value'])

    return df


def create_gap_periods(
    df: pd.DataFrame,
    master_dates: pd.DataFrame,
    id_col: str,
    reference: int,
    grace: GracePeriod,
    carryforward: int
) -> pd.DataFrame:
    """
    Fill gaps between exposure periods with reference (unexposed) time.

    Algorithm:
    1. Sort by id, start
    2. Calculate gap to next period
    3. Apply grace period bridging (gaps <= grace are filled by extending previous)
    4. Create reference periods for remaining gaps
    5. Apply carryforward logic if specified

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    master_dates : pd.DataFrame
        Master data with entry/exit dates
    id_col : str
        ID column name
    reference : int
        Reference/unexposed value
    grace : GracePeriod
        Grace period specification
    carryforward : int
        Days to carry forward exposure

    Returns
    -------
    pd.DataFrame
        Data with gap periods added
    """
    df = df.sort_values([id_col, 'exp_start']).copy()

    # Calculate gap to next period
    df['_next_start'] = df.groupby(id_col)['exp_start'].shift(-1)
    df['_gap_days'] = (df['_next_start'] - df['exp_stop']).dt.days - 1

    # Get grace period for each exposure value
    df['_grace_days'] = df['exp_value'].apply(grace.get_grace)

    # Bridge small gaps within same type by extending stop
    same_type_next = df.groupby(id_col)['exp_value'].shift(-1) == df['exp_value']
    bridge_mask = (
        same_type_next &
        df['_gap_days'].notna() &
        (df['_gap_days'] <= df['_grace_days']) &
        (df['_gap_days'] > 0)
    )
    df.loc[bridge_mask, 'exp_stop'] = df.loc[bridge_mask, '_next_start'] - pd.Timedelta(days=1)

    # Recalculate gaps after bridging
    df['_next_start'] = df.groupby(id_col)['exp_start'].shift(-1)
    df['_gap_days'] = (df['_next_start'] - df['exp_stop']).dt.days - 1

    # Identify gaps that need reference periods
    gap_mask = df['_gap_days'].notna() & (df['_gap_days'] > df['_grace_days'])
    gap_rows = df[gap_mask].copy()

    if len(gap_rows) > 0:
        if carryforward > 0:
            # Carryforward: split gap into carryforward + reference
            gap_rows['_carry_stop'] = gap_rows['exp_stop'] + pd.Timedelta(days=carryforward)
            gap_rows['_carry_stop'] = gap_rows[['_carry_stop', '_next_start']].min(axis=1) - pd.Timedelta(days=1)

            # Carryforward periods (same exposure value)
            carry_periods = gap_rows.copy()
            carry_periods['exp_start'] = carry_periods['exp_stop'] + pd.Timedelta(days=1)
            carry_periods['exp_stop'] = carry_periods['_carry_stop']
            carry_periods = carry_periods[carry_periods['exp_start'] <= carry_periods['exp_stop']]

            # Reference periods (remaining gap)
            ref_periods = gap_rows.copy()
            ref_periods['exp_start'] = ref_periods['_carry_stop'] + pd.Timedelta(days=1)
            ref_periods['exp_stop'] = ref_periods['_next_start'] - pd.Timedelta(days=1)
            ref_periods['exp_value'] = reference
            ref_periods = ref_periods[ref_periods['exp_start'] <= ref_periods['exp_stop']]

            gap_periods = pd.concat([carry_periods, ref_periods], ignore_index=True)
        else:
            # No carryforward: entire gap is reference
            gap_periods = gap_rows.copy()
            gap_periods['exp_start'] = gap_periods['exp_stop'] + pd.Timedelta(days=1)
            gap_periods['exp_stop'] = gap_periods['_next_start'] - pd.Timedelta(days=1)
            gap_periods['exp_value'] = reference

        # Keep essential columns
        keep_cols = [id_col, 'exp_start', 'exp_stop', 'exp_value']
        gap_periods = gap_periods[keep_cols]

        # Combine with original data
        df = df.drop(columns=[c for c in df.columns if c.startswith('_')])
        df = pd.concat([df, gap_periods], ignore_index=True)
        df = df.sort_values([id_col, 'exp_start', 'exp_stop'])
    else:
        df = df.drop(columns=[c for c in df.columns if c.startswith('_')])

    return df


def create_baseline_periods(
    df: pd.DataFrame,
    master_dates: pd.DataFrame,
    id_col: str,
    reference: int
) -> pd.DataFrame:
    """
    Create reference periods before first exposure (baseline unexposed time).

    Also handles never-exposed persons (entire follow-up is reference).

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    master_dates : pd.DataFrame
        Master data with id, study_entry, study_exit
    id_col : str
        ID column name
    reference : int
        Reference value

    Returns
    -------
    pd.DataFrame
        Data with baseline periods added
    """
    # Get first exposure date per person
    first_exp = df.groupby(id_col)['exp_start'].min().reset_index()
    first_exp.columns = [id_col, '_first_exp']

    # Merge with master dates
    baseline = master_dates.merge(first_exp, on=id_col, how='left')

    # Create baseline period: entry to day before first exposure
    baseline['exp_start'] = baseline['study_entry']
    baseline['exp_stop'] = baseline['_first_exp'] - pd.Timedelta(days=1)

    # For never-exposed: entire follow-up is baseline
    baseline.loc[baseline['_first_exp'].isna(), 'exp_stop'] = baseline.loc[
        baseline['_first_exp'].isna(), 'study_exit'
    ]

    baseline['exp_value'] = reference

    # Keep only valid baseline periods
    baseline = baseline[baseline['exp_stop'] >= baseline['exp_start']]
    baseline = baseline[[id_col, 'exp_start', 'exp_stop', 'exp_value']]

    # Combine
    df = pd.concat([df, baseline], ignore_index=True)
    df = df.sort_values([id_col, 'exp_start', 'exp_stop'])

    return df


def create_post_exposure_periods(
    df: pd.DataFrame,
    master_dates: pd.DataFrame,
    id_col: str,
    reference: int
) -> pd.DataFrame:
    """
    Create reference periods after last exposure to study exit.

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    master_dates : pd.DataFrame
        Master data with id, study_entry, study_exit
    id_col : str
        ID column name
    reference : int
        Reference value

    Returns
    -------
    pd.DataFrame
        Data with post-exposure periods added
    """
    # Get last exposure date per person
    last_exp = df.groupby(id_col)['exp_stop'].max().reset_index()
    last_exp.columns = [id_col, '_last_exp']

    # Merge with master dates
    post = master_dates.merge(last_exp, on=id_col, how='left')

    # Create post-exposure period: day after last exposure to exit
    post['exp_start'] = post['_last_exp'] + pd.Timedelta(days=1)
    post['exp_stop'] = post['study_exit']
    post['exp_value'] = reference

    # Keep only valid post periods
    post = post[post['exp_start'] <= post['exp_stop']]
    post = post[[id_col, 'exp_start', 'exp_stop', 'exp_value']]

    # Combine
    if len(post) > 0:
        df = pd.concat([df, post], ignore_index=True)
        df = df.sort_values([id_col, 'exp_start', 'exp_stop'])

    return df
