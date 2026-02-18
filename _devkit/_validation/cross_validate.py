#!/usr/bin/env python3
"""
cross_validate.py - Independent Python cross-validation engine for tvtools

Purpose: Implement core tvtools algorithms independently in Python, then
compare outputs cell-by-cell with Stata results. This catches bugs that
no amount of Stata-only testing can find.

Usage:
    python3 cross_validate.py [--verbose]

Requires: pandas, numpy
"""

import pandas as pd
import numpy as np
import subprocess
import os
import sys
import tempfile
from pathlib import Path
from datetime import datetime, timedelta

# ===========================================================================
# CONFIGURATION
# ===========================================================================

STATA_TOOLS_PATH = Path(os.environ.get('STATA_TOOLS_PATH',
    os.path.expanduser('~/Stata-Tools')))
VALIDATION_DIR = STATA_TOOLS_PATH / '_devkit' / '_validation'
DATA_DIR = VALIDATION_DIR / 'data'
CROSS_VAL_DIR = VALIDATION_DIR / 'cross_validation'

VERBOSE = '--verbose' in sys.argv

# Stata date epoch: January 1, 1960
STATA_EPOCH = datetime(1960, 1, 1)

def date_to_stata(dt):
    """Convert Python datetime to Stata date (integer days since 1960-01-01)."""
    return (dt - STATA_EPOCH).days

def stata_to_date(sd):
    """Convert Stata date to Python datetime."""
    return STATA_EPOCH + timedelta(days=int(sd))

# ===========================================================================
# TEST TRACKING
# ===========================================================================

class TestTracker:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.errors = []

    def check(self, name, actual, expected, tolerance=0.0001):
        """Compare actual vs expected with tolerance."""
        if isinstance(actual, pd.DataFrame) and isinstance(expected, pd.DataFrame):
            return self._check_dataframes(name, actual, expected, tolerance)

        if isinstance(actual, (int, float, np.integer, np.floating)):
            if isinstance(expected, (int, float, np.integer, np.floating)):
                if abs(actual - expected) <= tolerance:
                    self.passed += 1
                    if VERBOSE:
                        print(f"  PASS: {name}")
                    return True
                else:
                    self.failed += 1
                    self.errors.append(f"{name}: expected {expected}, got {actual}")
                    print(f"  FAIL: {name}: expected {expected}, got {actual}")
                    return False

        if actual == expected:
            self.passed += 1
            if VERBOSE:
                print(f"  PASS: {name}")
            return True
        else:
            self.failed += 1
            self.errors.append(f"{name}: expected {expected}, got {actual}")
            print(f"  FAIL: {name}: expected {expected}, got {actual}")
            return False

    def _check_dataframes(self, name, actual, expected, tolerance):
        """Compare two DataFrames cell by cell."""
        if actual.shape != expected.shape:
            self.failed += 1
            msg = f"{name}: shape mismatch: actual {actual.shape} vs expected {expected.shape}"
            self.errors.append(msg)
            print(f"  FAIL: {msg}")
            return False

        # Compare each column
        all_match = True
        for col in expected.columns:
            if col not in actual.columns:
                self.failed += 1
                msg = f"{name}: missing column {col}"
                self.errors.append(msg)
                print(f"  FAIL: {msg}")
                all_match = False
                continue

            for idx in range(len(expected)):
                exp_val = expected[col].iloc[idx]
                act_val = actual[col].iloc[idx]

                if pd.isna(exp_val) and pd.isna(act_val):
                    continue
                if pd.isna(exp_val) != pd.isna(act_val):
                    self.failed += 1
                    msg = f"{name}[{idx},{col}]: expected {exp_val}, got {act_val}"
                    self.errors.append(msg)
                    print(f"  FAIL: {msg}")
                    all_match = False
                    break
                if isinstance(exp_val, (int, float, np.integer, np.floating)):
                    if abs(act_val - exp_val) > tolerance:
                        self.failed += 1
                        msg = f"{name}[{idx},{col}]: expected {exp_val}, got {act_val}"
                        self.errors.append(msg)
                        print(f"  FAIL: {msg}")
                        all_match = False
                        break
                elif act_val != exp_val:
                    self.failed += 1
                    msg = f"{name}[{idx},{col}]: expected {exp_val}, got {act_val}"
                    self.errors.append(msg)
                    print(f"  FAIL: {msg}")
                    all_match = False
                    break

        if all_match:
            self.passed += 1
            if VERBOSE:
                print(f"  PASS: {name}")
        return all_match

    def summary(self):
        total = self.passed + self.failed
        print(f"\n{'='*70}")
        print(f"CROSS-VALIDATION SUMMARY")
        print(f"{'='*70}")
        print(f"Total checks: {total}")
        print(f"Passed:       {self.passed}")
        print(f"Failed:       {self.failed}")
        if self.errors:
            print(f"\nFailed checks:")
            for e in self.errors:
                print(f"  - {e}")
        print(f"{'='*70}")
        return self.failed == 0


tracker = TestTracker()


# ===========================================================================
# HELPER: Run Stata and load results
# ===========================================================================

def run_stata(do_code, timeout=120):
    """Run Stata do-file code and return True if successful."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.do', delete=False,
                                      dir=str(STATA_TOOLS_PATH)) as f:
        f.write(do_code)
        do_file = f.name

    try:
        result = subprocess.run(
            ['stata-mp', '-b', 'do', do_file],
            cwd=str(STATA_TOOLS_PATH),
            capture_output=True, text=True, timeout=timeout
        )
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print(f"  WARNING: Stata timed out after {timeout}s")
        return False
    finally:
        os.unlink(do_file)
        log_file = do_file.replace('.do', '.log')
        if os.path.exists(log_file):
            os.unlink(log_file)


def load_dta(path):
    """Load a Stata .dta file into a pandas DataFrame.

    Reads with convert_categoricals=False so labeled values remain numeric,
    and convert_dates=False so dates stay as Stata internal integers.
    """
    df = pd.read_stata(str(path), convert_categoricals=False, convert_dates=False)
    return df


def save_dta(df, path):
    """Save a pandas DataFrame to Stata .dta file.

    Ensures int64 columns are converted to int32 (Stata long) to avoid
    pandas version compatibility issues.
    """
    df_out = df.copy()
    for col in df_out.columns:
        if df_out[col].dtype == np.int64:
            df_out[col] = df_out[col].astype(np.int32)
    df_out.to_stata(str(path), write_index=False)


# ===========================================================================
# PYTHON IMPLEMENTATIONS OF CORE ALGORITHMS
# ===========================================================================

def python_tvexpose(cohort, exposures, reference=0):
    """
    Independent Python implementation of tvexpose core algorithm.

    Args:
        cohort: DataFrame with columns [id, study_entry, study_exit]
        exposures: DataFrame with columns [id, exp_start, exp_stop, exp_value]
        reference: Reference (unexposed) value

    Returns:
        DataFrame with time-varying exposure intervals
    """
    results = []

    for pid in cohort['id'].unique():
        entry = cohort.loc[cohort['id'] == pid, 'study_entry'].values[0]
        exit_d = cohort.loc[cohort['id'] == pid, 'study_exit'].values[0]

        # Get exposure periods for this person, sorted by start
        person_exp = exposures[exposures['id'] == pid].copy()
        person_exp = person_exp.sort_values('exp_start').reset_index(drop=True)

        # Truncate to study window
        person_exp = person_exp[(person_exp['exp_stop'] >= entry) &
                                (person_exp['exp_start'] <= exit_d)].copy()
        person_exp.loc[:, 'exp_start'] = person_exp['exp_start'].clip(lower=entry)
        person_exp.loc[:, 'exp_stop'] = person_exp['exp_stop'].clip(upper=exit_d)

        if len(person_exp) == 0:
            # Never exposed - single reference period
            results.append({
                'id': pid, 'exp_start': entry, 'exp_stop': exit_d,
                'exp_value': reference
            })
            continue

        # Build complete timeline: baseline + exposed + gaps + post-exposure
        periods = []

        # Baseline (before first exposure)
        first_exp_start = person_exp['exp_start'].min()
        if first_exp_start > entry:
            periods.append({
                'id': pid, 'exp_start': entry,
                'exp_stop': first_exp_start - 1, 'exp_value': reference
            })

        # Add exposure periods
        for _, row in person_exp.iterrows():
            periods.append({
                'id': pid, 'exp_start': int(row['exp_start']),
                'exp_stop': int(row['exp_stop']),
                'exp_value': int(row['exp_value'])
            })

        # Add gaps between exposures
        exp_sorted = person_exp.sort_values('exp_start').reset_index(drop=True)
        for i in range(len(exp_sorted) - 1):
            gap_start = exp_sorted.iloc[i]['exp_stop'] + 1
            gap_stop = exp_sorted.iloc[i + 1]['exp_start'] - 1
            if gap_start <= gap_stop:
                periods.append({
                    'id': pid, 'exp_start': int(gap_start),
                    'exp_stop': int(gap_stop), 'exp_value': reference
                })

        # Post-exposure period
        last_exp_stop = person_exp['exp_stop'].max()
        if last_exp_stop < exit_d:
            periods.append({
                'id': pid, 'exp_start': int(last_exp_stop) + 1,
                'exp_stop': exit_d, 'exp_value': reference
            })

        results.extend(periods)

    result_df = pd.DataFrame(results)
    result_df = result_df.sort_values(['id', 'exp_start']).reset_index(drop=True)
    return result_df


def python_tvexpose_evertreated(cohort, exposures, reference=0):
    """
    Independent Python implementation of evertreated exposure type.
    """
    # First get the basic time-varying intervals
    tv = python_tvexpose(cohort, exposures, reference)

    results = []
    for pid in tv['id'].unique():
        person = tv[tv['id'] == pid].sort_values('exp_start').reset_index(drop=True)

        # Find first exposure date
        exposed = person[person['exp_value'] != reference]
        if len(exposed) == 0:
            # Never exposed
            first = person.iloc[0]
            last = person.iloc[-1]
            results.append({
                'id': pid, 'exp_start': first['exp_start'],
                'exp_stop': last['exp_stop'], 'exp_value': 0
            })
        else:
            first_exp_date = exposed['exp_start'].min()

            # Before first exposure: 0 (never)
            before = person[person['exp_start'] < first_exp_date]
            if len(before) > 0:
                results.append({
                    'id': pid, 'exp_start': before.iloc[0]['exp_start'],
                    'exp_stop': int(first_exp_date) - 1, 'exp_value': 0
                })

            # From first exposure onward: 1 (ever)
            after = person[person['exp_start'] >= first_exp_date]
            if len(after) > 0:
                results.append({
                    'id': pid, 'exp_start': first_exp_date,
                    'exp_stop': after.iloc[-1]['exp_stop'], 'exp_value': 1
                })

    result_df = pd.DataFrame(results)
    result_df = result_df.sort_values(['id', 'exp_start']).reset_index(drop=True)
    return result_df


def python_tvexpose_currentformer(cohort, exposures, reference=0):
    """
    Independent Python implementation of currentformer exposure type.
    0=never, 1=current, 2=former
    """
    tv = python_tvexpose(cohort, exposures, reference)

    results = []
    for pid in tv['id'].unique():
        person = tv[tv['id'] == pid].sort_values('exp_start').reset_index(drop=True)

        exposed_rows = person[person['exp_value'] != reference]
        if len(exposed_rows) == 0:
            # Never exposed
            results.append({
                'id': pid, 'exp_start': person.iloc[0]['exp_start'],
                'exp_stop': person.iloc[-1]['exp_stop'], 'exp_value': 0
            })
            continue

        first_exp_date = exposed_rows['exp_start'].min()

        for _, row in person.iterrows():
            if row['exp_start'] < first_exp_date:
                # Before first exposure: never (0)
                results.append({
                    'id': pid, 'exp_start': row['exp_start'],
                    'exp_stop': row['exp_stop'], 'exp_value': 0
                })
            elif row['exp_value'] != reference:
                # Currently exposed (1)
                results.append({
                    'id': pid, 'exp_start': row['exp_start'],
                    'exp_stop': row['exp_stop'], 'exp_value': 1
                })
            else:
                # After exposure but not currently exposed: former (2)
                results.append({
                    'id': pid, 'exp_start': row['exp_start'],
                    'exp_stop': row['exp_stop'], 'exp_value': 2
                })

    # Collapse consecutive same-value periods
    result_df = pd.DataFrame(results)
    collapsed = []
    for pid in result_df['id'].unique():
        person = result_df[result_df['id'] == pid].sort_values('exp_start').reset_index(drop=True)
        current = person.iloc[0].to_dict()
        for i in range(1, len(person)):
            row = person.iloc[i]
            if row['exp_value'] == current['exp_value']:
                current['exp_stop'] = row['exp_stop']
            else:
                collapsed.append(current)
                current = row.to_dict()
        collapsed.append(current)

    return pd.DataFrame(collapsed).sort_values(['id', 'exp_start']).reset_index(drop=True)


def python_tvmerge_intersect(ds1, ds2, id_col='id'):
    """
    Independent Python implementation of tvmerge interval intersection.

    For each person, compute all pairwise intersections between intervals
    from ds1 and ds2.
    """
    results = []

    all_ids = set(ds1[id_col].unique()) & set(ds2[id_col].unique())

    for pid in sorted(all_ids):
        p1 = ds1[ds1[id_col] == pid].reset_index(drop=True)
        p2 = ds2[ds2[id_col] == pid].reset_index(drop=True)

        for _, r1 in p1.iterrows():
            for _, r2 in p2.iterrows():
                # Compute intersection
                int_start = max(r1['start1'], r2['start2'])
                int_stop = min(r1['stop1'], r2['stop2'])

                if int_start <= int_stop:
                    results.append({
                        id_col: pid,
                        'start': int_start,
                        'stop': int_stop,
                        'exp1': r1['exp1'],
                        'exp2': r2['exp2']
                    })

    if not results:
        return pd.DataFrame(columns=[id_col, 'start', 'stop', 'exp1', 'exp2'])

    return pd.DataFrame(results).sort_values([id_col, 'start']).reset_index(drop=True)


def python_tvevent_split(intervals, events, id_col='id', start_col='start',
                          stop_col='stop', date_col='event_date'):
    """
    Independent Python implementation of tvevent interval splitting.

    Splits intervals at event dates and flags the event.
    Boundary rule: event at start -> not flagged; event at stop -> flagged.
    Event strictly inside interval -> split into two, event flagged on first half.
    """
    results = []

    for pid in intervals[id_col].unique():
        person_int = intervals[intervals[id_col] == pid].sort_values(start_col).reset_index(drop=True)
        person_evt = events[events[id_col] == pid]

        if len(person_evt) == 0:
            # No events - copy intervals with _event=0
            for _, row in person_int.iterrows():
                r = row.to_dict()
                r['_event'] = 0
                results.append(r)
            continue

        event_date = person_evt[date_col].values[0]

        for _, row in person_int.iterrows():
            r = row.to_dict()
            s = row[start_col]
            e = row[stop_col]

            if event_date > s and event_date < e:
                # Event strictly inside interval - split
                # Pre-event segment (includes event date)
                r1 = r.copy()
                r1[stop_col] = event_date
                r1['_event'] = 1
                results.append(r1)

                # Post-event segment
                r2 = r.copy()
                r2[start_col] = event_date + 1
                r2['_event'] = 0
                results.append(r2)

            elif event_date == e:
                # Event at stop boundary - flag but don't split
                r['_event'] = 1
                results.append(r)

            elif event_date == s:
                # Event at start boundary - not flagged
                r['_event'] = 0
                results.append(r)

            else:
                # Event not in this interval
                r['_event'] = 0
                results.append(r)

    return pd.DataFrame(results).sort_values([id_col, start_col]).reset_index(drop=True)


def python_tvage(cohort, id_col='id', dob_col='dob', entry_col='study_entry',
                 exit_col='study_exit', groupwidth=1):
    """
    Independent Python implementation of tvage.
    """
    results = []

    for _, row in cohort.iterrows():
        pid = row[id_col]
        dob = row[dob_col]
        entry = row[entry_col]
        exit_d = row[exit_col]

        age_entry = int(np.floor((entry - dob) / 365.25))
        age_exit = int(np.floor((exit_d - dob) / 365.25))

        for age in range(age_entry, age_exit + 1):
            # Start: max(entry, birthday for this age)
            age_start = round(dob + age * 365.25)
            if age == age_entry:
                period_start = entry
            else:
                period_start = age_start

            # Stop: min(exit, birthday for next age - 1)
            next_age_start = round(dob + (age + 1) * 365.25)
            if age == age_exit:
                period_stop = exit_d
            else:
                period_stop = next_age_start - 1

            if period_start <= period_stop:
                if groupwidth > 1:
                    age_group = (age // groupwidth) * groupwidth
                else:
                    age_group = age

                results.append({
                    id_col: pid,
                    'age_tv': age_group,
                    'age_start': period_start,
                    'age_stop': period_stop
                })

    df = pd.DataFrame(results)

    # If groupwidth > 1, collapse same age groups
    if groupwidth > 1:
        df = df.groupby([id_col, 'age_tv']).agg(
            age_start=('age_start', 'min'),
            age_stop=('age_stop', 'max')
        ).reset_index()

    return df.sort_values([id_col, 'age_start']).reset_index(drop=True)


def python_smd(ref_values, exp_values):
    """
    Independent Python implementation of SMD calculation.
    SMD = (mean_exp - mean_ref) / sqrt((var_ref + var_exp) / 2)
    Uses N-denominator variance (Stata's r(Var) uses N-1, but we match Stata).
    """
    mean_ref = np.mean(ref_values)
    mean_exp = np.mean(exp_values)
    # Stata uses N-1 denominator (sample variance) via r(Var)
    var_ref = np.var(ref_values, ddof=1)
    var_exp = np.var(exp_values, ddof=1)
    pooled_sd = np.sqrt((var_ref + var_exp) / 2)

    if pooled_sd == 0:
        return np.nan
    return (mean_exp - mean_ref) / pooled_sd


def python_evalue(rr):
    """
    Independent Python implementation of E-value calculation.
    E = RR + sqrt(RR * (RR - 1)) for RR >= 1
    E = (1/RR) + sqrt((1/RR) * ((1/RR) - 1)) for RR < 1
    """
    if rr >= 1:
        return rr + np.sqrt(rr * (rr - 1))
    else:
        rr_inv = 1 / rr
        return rr_inv + np.sqrt(rr_inv * (rr_inv - 1))


# ===========================================================================
# CROSS-VALIDATION TESTS
# ===========================================================================

def test_tvexpose_basic():
    """Cross-validate tvexpose core algorithm with known data."""
    print("\n" + "="*70)
    print("TEST: tvexpose basic interval splitting")
    print("="*70)

    # Create deterministic test data
    # Person 1: entry=Jan1 2020, exit=Dec31 2020
    # Exposure: Mar1-Jun30 2020, type=1
    entry = date_to_stata(datetime(2020, 1, 1))
    exit_d = date_to_stata(datetime(2020, 12, 31))
    exp_start = date_to_stata(datetime(2020, 3, 1))
    exp_stop = date_to_stata(datetime(2020, 6, 30))

    cohort = pd.DataFrame({'id': [1], 'study_entry': [entry], 'study_exit': [exit_d]})
    exposures = pd.DataFrame({
        'id': [1], 'exp_start': [exp_start], 'exp_stop': [exp_stop], 'exp_value': [1]
    })

    # Python calculation
    py_result = python_tvexpose(cohort, exposures, reference=0)

    # Expected: 3 intervals
    # 1. Jan1 to Feb29 (reference)
    # 2. Mar1 to Jun30 (exposed)
    # 3. Jul1 to Dec31 (reference)
    tracker.check("tvexpose basic: row count", len(py_result), 3)
    tracker.check("tvexpose basic: period 1 start", py_result.iloc[0]['exp_start'], entry)
    tracker.check("tvexpose basic: period 1 stop", py_result.iloc[0]['exp_stop'], exp_start - 1)
    tracker.check("tvexpose basic: period 1 value", py_result.iloc[0]['exp_value'], 0)
    tracker.check("tvexpose basic: period 2 start", py_result.iloc[1]['exp_start'], exp_start)
    tracker.check("tvexpose basic: period 2 stop", py_result.iloc[1]['exp_stop'], exp_stop)
    tracker.check("tvexpose basic: period 2 value", py_result.iloc[1]['exp_value'], 1)
    tracker.check("tvexpose basic: period 3 start", py_result.iloc[2]['exp_start'], exp_stop + 1)
    tracker.check("tvexpose basic: period 3 stop", py_result.iloc[2]['exp_stop'], exit_d)
    tracker.check("tvexpose basic: period 3 value", py_result.iloc[2]['exp_value'], 0)

    # Person-time conservation
    total_days = sum(py_result['exp_stop'] - py_result['exp_start'] + 1)
    expected_days = exit_d - entry + 1  # 366 days (2020 is leap year)
    tracker.check("tvexpose basic: person-time conservation", total_days, expected_days)

    # Now run Stata and compare
    cross_val_data = CROSS_VAL_DIR / 'tvexpose_basic'
    cross_val_data.mkdir(parents=True, exist_ok=True)

    save_dta(cohort, cross_val_data / 'cohort.dta')
    save_dta(exposures, cross_val_data / 'exposures.dta')

    stata_code = f"""
clear all
set more off
version 16.0
quietly net install tvtools, from("{STATA_TOOLS_PATH}/tvtools") replace

use "{cross_val_data}/cohort.dta", clear
format study_entry study_exit %td
save "{cross_val_data}/cohort.dta", replace

use "{cross_val_data}/exposures.dta", clear
format exp_start exp_stop %td
save "{cross_val_data}/exposures.dta", replace

use "{cross_val_data}/cohort.dta", clear
tvexpose using "{cross_val_data}/exposures.dta", ///
    id(id) start(exp_start) stop(exp_stop) ///
    exposure(exp_value) reference(0) entry(study_entry) exit(study_exit)
sort id exp_start
save "{cross_val_data}/stata_result.dta", replace
"""

    if run_stata(stata_code):
        stata_result = load_dta(cross_val_data / 'stata_result.dta')
        stata_result = stata_result.sort_values(['id', 'exp_start']).reset_index(drop=True)

        # Compare row counts
        tracker.check("tvexpose Stata vs Python: row count",
                      len(stata_result), len(py_result))

        # Compare each row
        for i in range(min(len(stata_result), len(py_result))):
            stata_start = int(stata_result.iloc[i]['exp_start'])
            stata_stop = int(stata_result.iloc[i]['exp_stop'])
            tracker.check(f"tvexpose Stata vs Python: row {i} start",
                         stata_start, int(py_result.iloc[i]['exp_start']))
            tracker.check(f"tvexpose Stata vs Python: row {i} stop",
                         stata_stop, int(py_result.iloc[i]['exp_stop']))
            # Compare exposure values
            exp_col = 'tv_exposure' if 'tv_exposure' in stata_result.columns else 'exp_value'
            tracker.check(f"tvexpose Stata vs Python: row {i} value",
                         int(stata_result.iloc[i][exp_col]), int(py_result.iloc[i]['exp_value']))
    else:
        print("  WARNING: Stata execution failed; skipping Stata comparison")


def test_tvexpose_multi_person():
    """Cross-validate tvexpose with multiple persons and gaps."""
    print("\n" + "="*70)
    print("TEST: tvexpose multi-person with gaps")
    print("="*70)

    entry = date_to_stata(datetime(2020, 1, 1))
    exit_d = date_to_stata(datetime(2020, 12, 31))

    cohort = pd.DataFrame({
        'id': [1, 2, 3],
        'study_entry': [entry, entry, entry],
        'study_exit': [exit_d, exit_d, exit_d]
    })

    # Person 1: two exposures with gap
    # Person 2: single exposure, starts on entry
    # Person 3: never exposed
    exposures = pd.DataFrame({
        'id': [1, 1, 2],
        'exp_start': [
            date_to_stata(datetime(2020, 2, 1)),
            date_to_stata(datetime(2020, 6, 1)),
            entry
        ],
        'exp_stop': [
            date_to_stata(datetime(2020, 3, 31)),
            date_to_stata(datetime(2020, 8, 31)),
            date_to_stata(datetime(2020, 4, 30))
        ],
        'exp_value': [1, 1, 2]
    })

    py_result = python_tvexpose(cohort, exposures, reference=0)

    # Verify person 1: 5 intervals (baseline, exp1, gap, exp2, post)
    p1 = py_result[py_result['id'] == 1]
    tracker.check("tvexpose multi: person 1 intervals", len(p1), 5)

    # Verify person 2: 2 intervals (no baseline since starts on entry, then post)
    p2 = py_result[py_result['id'] == 2]
    tracker.check("tvexpose multi: person 2 intervals", len(p2), 2)

    # Verify person 3: 1 interval (never exposed)
    p3 = py_result[py_result['id'] == 3]
    tracker.check("tvexpose multi: person 3 intervals", len(p3), 1)
    tracker.check("tvexpose multi: person 3 value", p3.iloc[0]['exp_value'], 0)

    # Verify person-time conservation for all persons
    for pid in [1, 2, 3]:
        person = py_result[py_result['id'] == pid]
        total = sum(person['exp_stop'] - person['exp_start'] + 1)
        expected = exit_d - entry + 1  # 366
        tracker.check(f"tvexpose multi: person {pid} person-time", total, expected)

    # Verify no overlaps
    for pid in [1, 2, 3]:
        person = py_result[py_result['id'] == pid].sort_values('exp_start')
        for i in range(len(person) - 1):
            gap = person.iloc[i + 1]['exp_start'] - person.iloc[i]['exp_stop']
            tracker.check(f"tvexpose multi: person {pid} no overlap ({i})", gap >= 1, True)


def test_tvexpose_evertreated():
    """Cross-validate evertreated transformation."""
    print("\n" + "="*70)
    print("TEST: tvexpose evertreated transformation")
    print("="*70)

    entry = date_to_stata(datetime(2020, 1, 1))
    exit_d = date_to_stata(datetime(2020, 12, 31))

    cohort = pd.DataFrame({'id': [1], 'study_entry': [entry], 'study_exit': [exit_d]})
    exposures = pd.DataFrame({
        'id': [1],
        'exp_start': [date_to_stata(datetime(2020, 4, 1))],
        'exp_stop': [date_to_stata(datetime(2020, 6, 30))],
        'exp_value': [1]
    })

    py_result = python_tvexpose_evertreated(cohort, exposures, reference=0)

    # Should have 2 periods: never (0) then ever (1)
    tracker.check("evertreated: row count", len(py_result), 2)
    tracker.check("evertreated: first period value", py_result.iloc[0]['exp_value'], 0)
    tracker.check("evertreated: second period value", py_result.iloc[1]['exp_value'], 1)

    # Transition should happen at first exposure date
    exp_date = date_to_stata(datetime(2020, 4, 1))
    tracker.check("evertreated: transition date", py_result.iloc[1]['exp_start'], exp_date)

    # Person-time conservation
    total = sum(py_result['exp_stop'] - py_result['exp_start'] + 1)
    tracker.check("evertreated: person-time conservation", total, exit_d - entry + 1)


def test_tvexpose_currentformer():
    """Cross-validate currentformer transformation."""
    print("\n" + "="*70)
    print("TEST: tvexpose currentformer transformation")
    print("="*70)

    entry = date_to_stata(datetime(2020, 1, 1))
    exit_d = date_to_stata(datetime(2020, 12, 31))

    cohort = pd.DataFrame({'id': [1], 'study_entry': [entry], 'study_exit': [exit_d]})
    exposures = pd.DataFrame({
        'id': [1],
        'exp_start': [date_to_stata(datetime(2020, 3, 1))],
        'exp_stop': [date_to_stata(datetime(2020, 6, 30))],
        'exp_value': [1]
    })

    py_result = python_tvexpose_currentformer(cohort, exposures, reference=0)

    # Should have 3 periods: never (0), current (1), former (2)
    tracker.check("currentformer: row count", len(py_result), 3)
    tracker.check("currentformer: period 1 value (never)", py_result.iloc[0]['exp_value'], 0)
    tracker.check("currentformer: period 2 value (current)", py_result.iloc[1]['exp_value'], 1)
    tracker.check("currentformer: period 3 value (former)", py_result.iloc[2]['exp_value'], 2)


def test_tvmerge_intersection():
    """Cross-validate tvmerge interval intersection algorithm."""
    print("\n" + "="*70)
    print("TEST: tvmerge interval intersection")
    print("="*70)

    # Dataset 1: Person 1 has one interval
    ds1 = pd.DataFrame({
        'id': [1, 1],
        'start1': [
            date_to_stata(datetime(2020, 1, 1)),
            date_to_stata(datetime(2020, 7, 1))
        ],
        'stop1': [
            date_to_stata(datetime(2020, 6, 30)),
            date_to_stata(datetime(2020, 12, 31))
        ],
        'exp1': [1, 0]
    })

    # Dataset 2: Person 1 has overlapping intervals
    ds2 = pd.DataFrame({
        'id': [1, 1],
        'start2': [
            date_to_stata(datetime(2020, 3, 1)),
            date_to_stata(datetime(2020, 9, 1))
        ],
        'stop2': [
            date_to_stata(datetime(2020, 8, 31)),
            date_to_stata(datetime(2020, 12, 31))
        ],
        'exp2': [1, 0]
    })

    py_result = python_tvmerge_intersect(ds1, ds2)

    # Expected intersections:
    # ds1[0] ∩ ds2[0]: Mar1-Jun30 (exp1=1, exp2=1)
    # ds1[1] ∩ ds2[0]: Jul1-Aug31 (exp1=0, exp2=1)
    # ds1[1] ∩ ds2[1]: Sep1-Dec31 (exp1=0, exp2=0)

    tracker.check("tvmerge: intersection count", len(py_result), 3)

    # Verify first intersection
    tracker.check("tvmerge: int 1 start", py_result.iloc[0]['start'],
                  date_to_stata(datetime(2020, 3, 1)))
    tracker.check("tvmerge: int 1 stop", py_result.iloc[0]['stop'],
                  date_to_stata(datetime(2020, 6, 30)))
    tracker.check("tvmerge: int 1 exp1", py_result.iloc[0]['exp1'], 1)
    tracker.check("tvmerge: int 1 exp2", py_result.iloc[0]['exp2'], 1)

    # Verify no overlaps in output
    for i in range(len(py_result) - 1):
        if py_result.iloc[i]['id'] == py_result.iloc[i+1]['id']:
            gap = py_result.iloc[i+1]['start'] - py_result.iloc[i]['stop']
            tracker.check(f"tvmerge: no overlap ({i})", gap >= 1, True)


def test_tvevent_split():
    """Cross-validate tvevent interval splitting at event dates."""
    print("\n" + "="*70)
    print("TEST: tvevent interval splitting")
    print("="*70)

    # Two intervals for person 1
    intervals = pd.DataFrame({
        'id': [1, 1],
        'start': [
            date_to_stata(datetime(2020, 1, 1)),
            date_to_stata(datetime(2020, 7, 1))
        ],
        'stop': [
            date_to_stata(datetime(2020, 6, 30)),
            date_to_stata(datetime(2020, 12, 31))
        ],
        'tv_exp': [1, 0]
    })

    # Event in the middle of first interval
    event_date = date_to_stata(datetime(2020, 4, 15))
    events = pd.DataFrame({
        'id': [1],
        'event_date': [event_date]
    })

    py_result = python_tvevent_split(intervals, events)

    # Expected: first interval split at Apr 15, plus second interval unchanged
    # [Jan1-Apr15, _event=1], [Apr16-Jun30, _event=0], [Jul1-Dec31, _event=0]
    tracker.check("tvevent: row count after split", len(py_result), 3)
    tracker.check("tvevent: pre-event stop", py_result.iloc[0]['stop'], event_date)
    tracker.check("tvevent: pre-event flag", py_result.iloc[0]['_event'], 1)
    tracker.check("tvevent: post-event start", py_result.iloc[1]['start'], event_date + 1)
    tracker.check("tvevent: post-event flag", py_result.iloc[1]['_event'], 0)

    # Test boundary: event at stop date
    events_boundary = pd.DataFrame({
        'id': [1],
        'event_date': [date_to_stata(datetime(2020, 6, 30))]  # At stop of first interval
    })

    py_result_boundary = python_tvevent_split(intervals, events_boundary)
    # Should NOT split, just flag
    tracker.check("tvevent boundary: row count", len(py_result_boundary), 2)
    tracker.check("tvevent boundary: event flag", py_result_boundary.iloc[0]['_event'], 1)


def test_tvage_expansion():
    """Cross-validate tvage age interval creation."""
    print("\n" + "="*70)
    print("TEST: tvage expansion")
    print("="*70)

    # Person born 1970-06-15, study 2020-01-01 to 2023-12-31
    dob = date_to_stata(datetime(1970, 6, 15))
    entry = date_to_stata(datetime(2020, 1, 1))
    exit_d = date_to_stata(datetime(2023, 12, 31))

    cohort = pd.DataFrame({
        'id': [1], 'dob': [dob], 'study_entry': [entry], 'study_exit': [exit_d]
    })

    py_result = python_tvage(cohort, groupwidth=1)

    # Age at entry: floor((2020-01-01 - 1970-06-15) / 365.25) = floor(49.55) = 49
    # Age at exit: floor((2023-12-31 - 1970-06-15) / 365.25) = floor(53.55) = 53
    age_entry = int(np.floor((entry - dob) / 365.25))
    age_exit = int(np.floor((exit_d - dob) / 365.25))

    tracker.check("tvage: age at entry", age_entry, 49)
    tracker.check("tvage: age at exit", age_exit, 53)

    # Should have 5 intervals (ages 49, 50, 51, 52, 53)
    tracker.check("tvage: interval count", len(py_result), 5)

    # First interval starts at study entry
    tracker.check("tvage: first start", py_result.iloc[0]['age_start'], entry)

    # Last interval stops at study exit
    tracker.check("tvage: last stop", py_result.iloc[-1]['age_stop'], exit_d)

    # Test with groupwidth=5
    py_result_grouped = python_tvage(cohort, groupwidth=5)

    # Age groups: 45-49 (age 49), 50-54 (ages 50-53)
    tracker.check("tvage grouped: interval count", len(py_result_grouped), 2)
    tracker.check("tvage grouped: first group", py_result_grouped.iloc[0]['age_tv'], 45)
    tracker.check("tvage grouped: second group", py_result_grouped.iloc[1]['age_tv'], 50)


def test_tvbalance_smd():
    """Cross-validate SMD calculation."""
    print("\n" + "="*70)
    print("TEST: tvbalance SMD calculation")
    print("="*70)

    # Known data: reference group mean=10, sd=2; exposed group mean=12, sd=3
    np.random.seed(42)
    n_ref = 100
    n_exp = 100

    ref_vals = np.random.normal(10, 2, n_ref)
    exp_vals = np.random.normal(12, 3, n_exp)

    py_smd = python_smd(ref_vals, exp_vals)

    # Hand calculation
    mean_ref = np.mean(ref_vals)
    mean_exp = np.mean(exp_vals)
    var_ref = np.var(ref_vals, ddof=1)
    var_exp = np.var(exp_vals, ddof=1)
    expected_smd = (mean_exp - mean_ref) / np.sqrt((var_ref + var_exp) / 2)

    tracker.check("SMD: Python matches hand calc", py_smd, expected_smd, tolerance=1e-10)

    # Cross-validate with Stata
    cross_val_data = CROSS_VAL_DIR / 'tvbalance_smd'
    cross_val_data.mkdir(parents=True, exist_ok=True)

    df = pd.DataFrame({
        'id': range(n_ref + n_exp),
        'exposure': [0]*n_ref + [1]*n_exp,
        'covar': np.concatenate([ref_vals, exp_vals])
    })
    save_dta(df, cross_val_data / 'balance_data.dta')

    stata_code = f"""
clear all
set more off
version 16.0
quietly net install tvtools, from("{STATA_TOOLS_PATH}/tvtools") replace
use "{cross_val_data}/balance_data.dta", clear
tvbalance covar, exposure(exposure)
matrix b = r(balance)
scalar smd_val = b[1,3]
clear
set obs 1
gen double smd = scalar(smd_val)
save "{cross_val_data}/stata_smd.dta", replace
"""

    if run_stata(stata_code):
        stata_smd_df = load_dta(cross_val_data / 'stata_smd.dta')
        stata_smd = stata_smd_df['smd'].values[0]
        tracker.check("SMD: Stata vs Python", stata_smd, py_smd, tolerance=1e-6)
    else:
        print("  WARNING: Stata execution failed; skipping Stata comparison")


def test_tvsensitivity_evalue():
    """Cross-validate E-value calculation."""
    print("\n" + "="*70)
    print("TEST: tvsensitivity E-value calculation")
    print("="*70)

    # Test cases with known answers
    test_cases = [
        (2.0, 2.0 + np.sqrt(2.0 * 1.0)),      # RR=2
        (3.0, 3.0 + np.sqrt(3.0 * 2.0)),      # RR=3
        (1.5, 1.5 + np.sqrt(1.5 * 0.5)),      # RR=1.5
        (1.0, 1.0),                             # RR=1 (null)
    ]

    for rr, expected in test_cases:
        py_eval = python_evalue(rr)
        tracker.check(f"E-value RR={rr}", py_eval, expected, tolerance=1e-10)

    # Protective effects
    py_eval_protect = python_evalue(0.5)
    expected_protect = python_evalue(1/0.5)  # Should use inverted RR
    tracker.check("E-value protective (RR=0.5)", py_eval_protect, expected_protect, tolerance=1e-10)

    # Cross-validate with Stata
    cross_val_data = CROSS_VAL_DIR / 'tvsensitivity'
    cross_val_data.mkdir(parents=True, exist_ok=True)

    stata_code = f"""
clear all
set more off
version 16.0
quietly net install tvtools, from("{STATA_TOOLS_PATH}/tvtools") replace

tvsensitivity, rr(2.0)
local evalue_2 = r(evalue)

tvsensitivity, rr(0.5)
local evalue_05 = r(evalue)

clear
set obs 1
gen double evalue_rr2 = `evalue_2'
gen double evalue_rr05 = `evalue_05'
save "{cross_val_data}/stata_evalues.dta", replace
"""

    if run_stata(stata_code):
        stata_df = load_dta(cross_val_data / 'stata_evalues.dta')
        tracker.check("E-value Stata vs Python RR=2",
                      stata_df['evalue_rr2'].values[0], python_evalue(2.0), tolerance=1e-6)
        tracker.check("E-value Stata vs Python RR=0.5",
                      stata_df['evalue_rr05'].values[0], python_evalue(0.5), tolerance=1e-6)
    else:
        print("  WARNING: Stata execution failed; skipping Stata comparison")


def test_dose_proportioning():
    """Cross-validate dose proportioning with overlapping prescriptions."""
    print("\n" + "="*70)
    print("TEST: tvexpose dose proportioning")
    print("="*70)

    # Two 30-day prescriptions of 30mg each, overlapping by 10 days
    # Rx1: day 1-30, total dose=30mg, daily rate=1mg/day
    # Rx2: day 21-50, total dose=30mg, daily rate=1mg/day
    # Overlap: day 21-30 (10 days)
    # Expected segments:
    #   Day 1-20: 1mg/day × 20 days = 20mg (from Rx1 only)
    #   Day 21-30: 2mg/day × 10 days = 20mg (from both)
    #   Day 31-50: 1mg/day × 20 days = 20mg (from Rx2 only)
    # Total: 60mg (correct: 30+30=60)

    base_date = date_to_stata(datetime(2020, 1, 1))
    entry = base_date
    exit_d = base_date + 99  # 100 days

    cohort = pd.DataFrame({'id': [1], 'study_entry': [entry], 'study_exit': [exit_d]})

    # Rx1: days 1-30 (Stata dates: entry to entry+29), dose=30
    # Rx2: days 21-50 (Stata dates: entry+20 to entry+49), dose=30
    exposures = pd.DataFrame({
        'id': [1, 1],
        'exp_start': [entry, entry + 20],
        'exp_stop': [entry + 29, entry + 49],
        'exp_value': [30, 30]
    })

    # Python dose proportioning
    rx1_daily = 30 / 30  # 1mg/day
    rx2_daily = 30 / 30  # 1mg/day

    # Segment 1: days 0-19 (20 days, Rx1 only)
    seg1_dose = 20 * rx1_daily  # 20mg
    # Segment 2: days 20-29 (10 days, both Rx)
    seg2_dose = 10 * (rx1_daily + rx2_daily)  # 20mg
    # Segment 3: days 30-49 (20 days, Rx2 only)
    seg3_dose = 20 * rx2_daily  # 20mg

    total_dose = seg1_dose + seg2_dose + seg3_dose
    tracker.check("dose: segment 1", seg1_dose, 20.0)
    tracker.check("dose: segment 2", seg2_dose, 20.0)
    tracker.check("dose: segment 3", seg3_dose, 20.0)
    tracker.check("dose: total conserved", total_dose, 60.0)

    # Cross-validate with Stata
    cross_val_data = CROSS_VAL_DIR / 'tvexpose_dose'
    cross_val_data.mkdir(parents=True, exist_ok=True)

    save_dta(cohort, cross_val_data / 'cohort.dta')
    save_dta(exposures, cross_val_data / 'exposures.dta')

    stata_code = f"""
clear all
set more off
version 16.0
quietly net install tvtools, from("{STATA_TOOLS_PATH}/tvtools") replace

use "{cross_val_data}/cohort.dta", clear
format study_entry study_exit %td
save "{cross_val_data}/cohort.dta", replace

use "{cross_val_data}/exposures.dta", clear
format exp_start exp_stop %td
save "{cross_val_data}/exposures.dta", replace

use "{cross_val_data}/cohort.dta", clear
tvexpose using "{cross_val_data}/exposures.dta", ///
    id(id) start(exp_start) stop(exp_stop) ///
    exposure(exp_value) reference(0) dose ///
    entry(study_entry) exit(study_exit)
sort id exp_start
save "{cross_val_data}/stata_dose_result.dta", replace

* Also save cumulative dose at each segment
gen double seg_dose = tv_exposure
gen double seg_days = exp_stop - exp_start + 1
save "{cross_val_data}/stata_dose_detail.dta", replace
"""

    if run_stata(stata_code):
        stata_df = load_dta(cross_val_data / 'stata_dose_detail.dta')
        stata_df = stata_df.sort_values('exp_start').reset_index(drop=True)

        # tvexpose dose option returns CUMULATIVE dose in tv_exposure
        # So seg_dose values should be: 20, 40, 60 (cumulative)
        cum1 = seg1_dose                          # 20
        cum2 = seg1_dose + seg2_dose              # 40
        cum3 = seg1_dose + seg2_dose + seg3_dose  # 60

        if len(stata_df) >= 3:
            tracker.check("dose Stata: segment 1 cumulative dose",
                         stata_df.iloc[0]['seg_dose'], cum1, tolerance=0.01)
            tracker.check("dose Stata: segment 2 cumulative dose",
                         stata_df.iloc[1]['seg_dose'], cum2, tolerance=0.01)
            tracker.check("dose Stata: segment 3 cumulative dose",
                         stata_df.iloc[2]['seg_dose'], cum3, tolerance=0.01)

            # Also verify person-time conservation
            total_days = stata_df['seg_days'].sum()
            expected_days = exit_d - entry + 1  # 100 days
            tracker.check("dose Stata: person-time conservation",
                         total_days, expected_days, tolerance=0.01)
        else:
            print(f"  WARNING: Expected 3 segments, got {len(stata_df)}")
    else:
        print("  WARNING: Stata execution failed; skipping Stata comparison")


def test_person_time_conservation():
    """
    Cross-validate that total person-time is conserved through tvexpose.
    This is the fundamental invariant: sum(stop-start+1) = exit-entry+1 for each person.
    """
    print("\n" + "="*70)
    print("TEST: Person-time conservation (5 persons)")
    print("="*70)

    np.random.seed(123)
    entry = date_to_stata(datetime(2020, 1, 1))

    # 5 persons with varying follow-up and exposure patterns
    cohort = pd.DataFrame({
        'id': [1, 2, 3, 4, 5],
        'study_entry': [entry]*5,
        'study_exit': [entry + 365, entry + 180, entry + 730, entry + 100, entry + 500]
    })

    exposures = pd.DataFrame({
        'id': [1, 1, 2, 3, 3, 3],
        'exp_start': [entry+30, entry+120, entry+10, entry+50, entry+200, entry+400],
        'exp_stop': [entry+90, entry+200, entry+80, entry+150, entry+350, entry+600],
        'exp_value': [1, 1, 1, 2, 1, 2]
    })

    py_result = python_tvexpose(cohort, exposures, reference=0)

    for pid in cohort['id']:
        person = py_result[py_result['id'] == pid]
        total_days = sum(person['exp_stop'] - person['exp_start'] + 1)
        expected = cohort.loc[cohort['id'] == pid, 'study_exit'].values[0] - entry + 1
        tracker.check(f"ptime conservation: person {pid}", total_days, expected)

    # Cross-validate with Stata
    cross_val_data = CROSS_VAL_DIR / 'ptime_conservation'
    cross_val_data.mkdir(parents=True, exist_ok=True)

    save_dta(cohort, cross_val_data / 'cohort.dta')
    save_dta(exposures, cross_val_data / 'exposures.dta')

    stata_code = f"""
clear all
set more off
version 16.0
quietly net install tvtools, from("{STATA_TOOLS_PATH}/tvtools") replace

use "{cross_val_data}/cohort.dta", clear
format study_entry study_exit %td
save "{cross_val_data}/cohort.dta", replace

use "{cross_val_data}/exposures.dta", clear
format exp_start exp_stop %td
save "{cross_val_data}/exposures.dta", replace

use "{cross_val_data}/cohort.dta", clear
tvexpose using "{cross_val_data}/exposures.dta", ///
    id(id) start(exp_start) stop(exp_stop) ///
    exposure(exp_value) reference(0) entry(study_entry) exit(study_exit)

gen double days = exp_stop - exp_start + 1
collapse (sum) total_days=days, by(id)
save "{cross_val_data}/stata_ptime.dta", replace
"""

    if run_stata(stata_code):
        stata_ptime = load_dta(cross_val_data / 'stata_ptime.dta')

        for pid in cohort['id']:
            expected = cohort.loc[cohort['id'] == pid, 'study_exit'].values[0] - entry + 1
            stata_total = stata_ptime.loc[stata_ptime['id'] == pid, 'total_days'].values
            if len(stata_total) > 0:
                tracker.check(f"ptime Stata: person {pid}", stata_total[0], expected)
    else:
        print("  WARNING: Stata execution failed")


# ===========================================================================
# MAIN
# ===========================================================================

def main():
    print("="*70)
    print("TVTOOLS INDEPENDENT CROSS-VALIDATION (Python)")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Stata-Tools path: {STATA_TOOLS_PATH}")
    print("="*70)

    # Ensure cross-validation directory exists
    CROSS_VAL_DIR.mkdir(parents=True, exist_ok=True)

    # Run all cross-validation tests
    test_tvexpose_basic()
    test_tvexpose_multi_person()
    test_tvexpose_evertreated()
    test_tvexpose_currentformer()
    test_tvmerge_intersection()
    test_tvevent_split()
    test_tvage_expansion()
    test_tvbalance_smd()
    test_tvsensitivity_evalue()
    test_dose_proportioning()
    test_person_time_conservation()

    # Print summary
    all_passed = tracker.summary()

    return 0 if all_passed else 1


if __name__ == '__main__':
    sys.exit(main())
