"""
tvevent - Integrate Outcome Events into Time-Varying Datasets

This module provides the tvevent function for integrating outcome events
and competing risks into time-varying datasets created by tvexpose/tvmerge.
"""

import pandas as pd
import numpy as np
from typing import Optional, Union, List, Dict, Any
from dataclasses import dataclass


@dataclass
class TVEventResult:
    """Result object from tvevent function."""
    data: pd.DataFrame
    N: int
    N_events: int
    generate: str
    type: str


def tvevent(
    intervals_data: pd.DataFrame,
    events_data: pd.DataFrame,
    id: str,
    date: str,
    compete: Optional[List[str]] = None,
    generate: str = "_failure",
    type: str = "single",
    keepvars: Optional[List[str]] = None,
    continuous: Optional[List[str]] = None,
    timegen: Optional[str] = None,
    timeunit: str = "days",
    eventlabel: Optional[Dict[str, str]] = None,
    startvar: str = "start",
    stopvar: str = "stop",
    replace: bool = False
) -> TVEventResult:
    """
    Integrate outcome events into time-varying datasets.

    The third and final step in the tvtools workflow. Integrates outcome events
    and competing risks, splits intervals at event dates, and creates event
    status flags.

    Parameters
    ----------
    intervals_data : pd.DataFrame
        Master dataset with time-varying intervals (from tvexpose/tvmerge)
    events_data : pd.DataFrame
        Events dataset with event dates
    id : str
        Name of ID column
    date : str
        Name of primary event date column
    compete : list, optional
        Names of competing risk date columns
    generate : str
        Name for event indicator variable (default: '_failure')
    type : str
        Event type: 'single' (terminal) or 'recurring'
    keepvars : list, optional
        Additional variables to merge from events_data
    continuous : list, optional
        Cumulative variables to adjust proportionally when splitting
    timegen : str, optional
        Name for time duration variable
    timeunit : str
        Time unit: 'days', 'months', or 'years'
    eventlabel : dict, optional
        Custom labels for event types
    startvar : str
        Name of start date column in intervals_data (default: 'start')
    stopvar : str
        Name of stop date column in intervals_data (default: 'stop')
    replace : bool
        Replace existing variables if they exist

    Returns
    -------
    TVEventResult
        Result object containing modified data with event flags
    """
    print("tvevent: Integrating events into time-varying data")

    # =========================================================================
    # VALIDATION
    # =========================================================================
    type = type.lower()
    if type not in ['single', 'recurring']:
        raise ValueError("type must be 'single' or 'recurring'")

    timeunit = timeunit.lower()
    if timeunit not in ['days', 'months', 'years']:
        raise ValueError("timeunit must be 'days', 'months', or 'years'")

    required_cols = [id, startvar, stopvar]
    missing = set(required_cols) - set(intervals_data.columns)
    if missing:
        raise ValueError(f"intervals_data missing required columns: {missing}")

    if id not in events_data.columns:
        raise ValueError(f"ID variable '{id}' not found in events_data")
    if date not in events_data.columns:
        raise ValueError(f"Date variable '{date}' not found in events_data")

    if not replace and generate in intervals_data.columns:
        raise ValueError(f"Variable '{generate}' already exists. Use replace=True")

    # Handle empty events
    if len(events_data) == 0:
        print("  Warning: events_data has no rows - all intervals will be censored")
        result = intervals_data.copy()
        result[generate] = 0
        if timegen:
            result[timegen] = _calculate_time(result, timeunit)
        return TVEventResult(
            data=result,
            N=len(result),
            N_events=0,
            generate=generate,
            type=type
        )

    # =========================================================================
    # PREPARE DATA
    # =========================================================================
    intervals = intervals_data.copy()
    events = events_data.copy()

    # Helper to convert dates to numeric
    import datetime
    epoch = datetime.date(1970, 1, 1)

    def to_numeric_date(series):
        """Convert date/datetime series to numeric days."""
        if pd.api.types.is_datetime64_any_dtype(series):
            return (series - pd.Timestamp('1970-01-01')).dt.days
        elif series.dtype == object:
            def convert_date(x):
                if pd.isna(x):
                    return np.nan
                if isinstance(x, datetime.date):
                    return (x - epoch).days
                return float(x)
            return series.apply(convert_date)
        return series

    # Rename columns to internal names if different
    col_rename_map = {}
    col_restore_map = {}
    if startvar != 'start':
        col_rename_map[startvar] = 'start'
        col_restore_map['start'] = startvar
    if stopvar != 'stop':
        col_rename_map[stopvar] = 'stop'
        col_restore_map['stop'] = stopvar
    if col_rename_map:
        intervals = intervals.rename(columns=col_rename_map)

    # Convert dates to numeric
    for col in ['start', 'stop']:
        intervals[col] = to_numeric_date(intervals[col])
        intervals[col] = pd.to_numeric(intervals[col], errors='coerce')

    events[date] = to_numeric_date(events[date])
    events[date] = pd.to_numeric(events[date], errors='coerce')

    if compete:
        for comp_var in compete:
            if comp_var in events.columns:
                events[comp_var] = to_numeric_date(events[comp_var])
                events[comp_var] = pd.to_numeric(events[comp_var], errors='coerce')

    # =========================================================================
    # RESOLVE COMPETING RISKS
    # =========================================================================
    print("  Resolving competing risks...")

    events['_eff_date'] = events[date].copy()
    events['_eff_type'] = np.where(events[date].notna(), 1, np.nan)

    if compete:
        for i, comp_var in enumerate(compete):
            if comp_var in events.columns:
                is_earlier = (
                    events[comp_var].notna() &
                    ((events[comp_var] < events['_eff_date']) | events['_eff_date'].isna())
                )
                events.loc[is_earlier, '_eff_type'] = i + 2
                events.loc[is_earlier, '_eff_date'] = events.loc[is_earlier, comp_var]

    # Keep only valid event dates
    events = events[events['_eff_date'].notna()]

    if len(events) == 0:
        print("  Warning: No valid event dates after competing risk resolution")
        result = intervals.copy()
        result[generate] = 0
        if timegen:
            result[timegen] = _calculate_time(result, timeunit)
        return TVEventResult(
            data=result,
            N=len(result),
            N_events=0,
            generate=generate,
            type=type
        )

    # Rename for clarity
    events = events.rename(columns={id: '_id', '_eff_date': '_event_date', '_eff_type': '_event_type'})

    # =========================================================================
    # IDENTIFY SPLIT POINTS
    # =========================================================================
    print("  Identifying split points...")

    # Find events that fall strictly within an interval
    intervals['_row_id'] = range(len(intervals))
    merged = intervals.merge(
        events[['_id', '_event_date', '_event_type']],
        left_on=id,
        right_on='_id',
        how='left'
    )

    # Identify internal events (need splitting)
    merged['_is_internal'] = (
        merged['_event_date'].notna() &
        (merged['_event_date'] > merged['start']) &
        (merged['_event_date'] < merged['stop'])
    )

    internal_events = merged[merged['_is_internal']].copy()

    if len(internal_events) > 0:
        print(f"  Splitting intervals for {len(internal_events)} internal events...")

        # Create pre-event intervals
        pre = internal_events.copy()
        pre['stop'] = pre['_event_date']
        pre['_is_event'] = False

        # Create post-event intervals
        post = internal_events.copy()
        post['start'] = post['_event_date']
        post['_is_event'] = True

        # Remove original intervals that were split
        split_rows = internal_events['_row_id'].unique()
        intervals = intervals[~intervals['_row_id'].isin(split_rows)]

        # Add split intervals
        split_intervals = pd.concat([pre, post], ignore_index=True)

        # Adjust continuous variables proportionally
        if continuous:
            for cont_var in continuous:
                if cont_var in split_intervals.columns:
                    orig_duration = internal_events['stop'] - internal_events['start']
                    for df in [pre, post]:
                        new_duration = df['stop'] - df['start']
                        df[cont_var] = df[cont_var] * (new_duration / orig_duration)

        intervals = pd.concat([intervals, split_intervals], ignore_index=True)

    # =========================================================================
    # FLAG EVENTS
    # =========================================================================
    print("  Flagging events...")

    # Clean up any existing event columns before merge
    for col in ['_id', '_event_date', '_event_type', '_is_event', '_is_internal']:
        if col in intervals.columns:
            intervals = intervals.drop(columns=[col])

    # Merge event info
    events_for_merge = events[['_id', '_event_date', '_event_type']].drop_duplicates()
    intervals = intervals.merge(
        events_for_merge,
        left_on=id,
        right_on='_id',
        how='left'
    )

    # Event occurs when interval stop equals event date
    intervals[generate] = np.where(
        (intervals['_event_date'].notna()) & (intervals['stop'] == intervals['_event_date']),
        intervals['_event_type'],
        0
    ).astype(int)

    # Clean up helper columns
    for col in ['_row_id', '_id', '_event_date', '_event_type', '_is_event', '_is_internal']:
        if col in intervals.columns:
            intervals = intervals.drop(columns=[col])

    # =========================================================================
    # HANDLE SINGLE VS RECURRING
    # =========================================================================
    if type == 'single':
        print("  Single event type: Censoring person-time after first event.")

        # For each person, keep only intervals up to and including first event
        intervals = intervals.sort_values([id, 'start', 'stop'])

        # Find first event for each person
        first_events = intervals[intervals[generate] > 0].groupby(id)['stop'].min().reset_index()
        first_events.columns = [id, '_first_event_stop']

        intervals = intervals.merge(first_events, on=id, how='left')

        # Keep intervals before or at first event
        intervals = intervals[
            intervals['_first_event_stop'].isna() |
            (intervals['stop'] <= intervals['_first_event_stop'])
        ]

        intervals = intervals.drop(columns=['_first_event_stop'], errors='ignore')

    # =========================================================================
    # TIME VARIABLE
    # =========================================================================
    if timegen:
        print(f"  Creating time variable in {timeunit}...")
        intervals[timegen] = _calculate_time(intervals, timeunit)

    # Sort final output
    intervals = intervals.sort_values([id, 'start', 'stop'])

    # Restore original column names if they were renamed
    if col_restore_map:
        intervals = intervals.rename(columns=col_restore_map)

    # =========================================================================
    # SUMMARY
    # =========================================================================
    n_events = (intervals[generate] > 0).sum()
    n_obs = len(intervals)

    print(f"\n{'-' * 50}")
    print("Event integration complete")
    print(f"  Observations: {n_obs}")
    print(f"  Events flagged ({generate}): {n_events}")
    print(f"{'-' * 50}")

    return TVEventResult(
        data=intervals,
        N=n_obs,
        N_events=n_events,
        generate=generate,
        type=type
    )


def _calculate_time(df: pd.DataFrame, timeunit: str) -> pd.Series:
    """Calculate time duration in specified units."""
    days = df['stop'] - df['start']

    if timeunit == 'days':
        return days
    elif timeunit == 'months':
        return days / 30.4375
    elif timeunit == 'years':
        return days / 365.25
    else:
        return days
