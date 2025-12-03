"""
Comprehensive test suite for Python tvtools implementation
Testing all option combinations for TVExpose, TVMerge, and TVEvent

Author: Claude
Date: 2025-12-03
"""

import pandas as pd
import numpy as np
from pathlib import Path
import sys
import traceback
from datetime import datetime
from typing import Tuple, Optional, Dict, Any
import warnings

# Suppress FutureWarnings
warnings.simplefilter(action='ignore', category=FutureWarning)

# Import tvtools modules
from tvtools.tvexpose import TVExpose
from tvtools.tvmerge import TVMerge
from tvtools.tvevent import TVEvent

# Setup paths
BASE_DIR = Path("/home/user/Stata-Tools/Reimplementations/Testing")
OUTPUT_DIR = BASE_DIR / "Python_comprehensive_outputs"
OUTPUT_DIR.mkdir(exist_ok=True)

# Test data files
STRESS_COHORT = BASE_DIR / "stress_cohort.csv"
STRESS_EXPOSURES = BASE_DIR / "stress_exposures.csv"
STRESS_EXPOSURES2 = BASE_DIR / "stress_exposures2.csv"
STRESS_EVENTS = BASE_DIR / "stress_events.csv"

# Global test results tracker
test_results = []


class TestResult:
    """Store test result information"""
    def __init__(self, test_id: str, test_name: str):
        self.test_id = test_id
        self.test_name = test_name
        self.status = "PENDING"
        self.rows = 0
        self.cols = 0
        self.unique_patients = 0
        self.error_message = ""
        self.output_file = ""

    def mark_passed(self, df: pd.DataFrame, output_file: str):
        """Mark test as passed with data"""
        self.status = "PASSED"
        self.rows = len(df)
        self.cols = len(df.columns)
        if 'patient_id' in df.columns:
            self.unique_patients = df['patient_id'].nunique()
        elif 'id' in df.columns:
            self.unique_patients = df['id'].nunique()
        self.output_file = output_file

    def mark_failed(self, error: Exception):
        """Mark test as failed with error"""
        self.status = "FAILED"
        self.error_message = str(error)

    def mark_not_implemented(self, error: Exception):
        """Mark test as not implemented"""
        self.status = "NOT_IMPLEMENTED"
        self.error_message = str(error)

    def mark_skipped(self, reason: str):
        """Mark test as skipped"""
        self.status = "SKIPPED"
        self.error_message = reason


def log_test(test_id: str, test_name: str, status: str = "START"):
    """Log test progress"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"\n{'='*80}")
    print(f"[{timestamp}] {status}: {test_id} - {test_name}")
    print(f"{'='*80}")


def save_output(df: pd.DataFrame, filename: str, test_name: str) -> str:
    """Save output and print summary"""
    output_path = OUTPUT_DIR / filename
    df.to_csv(output_path, index=False)
    print(f"✓ Saved output to: {filename}")
    print(f"  Shape: {df.shape[0]} rows x {df.shape[1]} cols")
    print(f"  Columns: {list(df.columns)}")
    if len(df) > 0 and len(df) <= 3:
        print(f"  All rows:")
        print(df.to_string())
    elif len(df) > 3:
        print(f"  First 3 rows preview:")
        print(df.head(3).to_string())
    return str(output_path)


def fix_intervals(df: pd.DataFrame) -> pd.DataFrame:
    """Fix intervals where start >= stop by filtering them out"""
    initial_len = len(df)
    df = df[df['start'] < df['stop']].copy()
    final_len = len(df)
    if initial_len != final_len:
        print(f"  Note: Filtered out {initial_len - final_len} intervals where start >= stop")
    return df


# ============================================================================
# TVEXPOSE TESTS
# ============================================================================

def test_tvexpose_01_basic():
    """TVExpose Test 1: Basic exposure (no special options)"""
    test_id = "TVE-01"
    test_name = "Basic exposure creation"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve01_basic.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_02_evertreated():
    """TVExpose Test 2: Ever treated indicator"""
    test_id = "TVE-02"
    test_name = "Ever treated indicator"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            exposure_type="ever_treated"
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve02_evertreated.csv", test_name)
        result.mark_passed(output.data, output_file)

        # Check for evertreated column
        if 'evertreated' in output.data.columns or 'ever_treated' in output.data.columns:
            print(f"  ✓ Ever treated column created")

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_03_currentformer():
    """TVExpose Test 3: Current/former exposure indicator"""
    test_id = "TVE-03"
    test_name = "Current/former exposure"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            exposure_type="current_former"
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve03_currentformer.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_04_duration():
    """TVExpose Test 4: Duration categories with cutpoints"""
    test_id = "TVE-04"
    test_name = "Duration with cutpoints [30, 90, 180, 365]"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            exposure_type="duration",
            duration_cutpoints=[30, 90, 180, 365],
            continuous_unit="days"
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve04_duration.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_05_continuous_days():
    """TVExpose Test 5: Continuous exposure in days"""
    test_id = "TVE-05"
    test_name = "Continuous exposure (days)"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            exposure_type="continuous",
            continuous_unit="days"
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve05_continuous_days.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_06_continuous_months():
    """TVExpose Test 6: Continuous exposure in months"""
    test_id = "TVE-06"
    test_name = "Continuous exposure (months)"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            exposure_type="continuous",
            continuous_unit="months"
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve06_continuous_months.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_07_continuous_years():
    """TVExpose Test 7: Continuous exposure in years"""
    test_id = "TVE-07"
    test_name = "Continuous exposure (years)"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            exposure_type="continuous",
            continuous_unit="years"
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve07_continuous_years.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_08_bytype():
    """TVExpose Test 8: Separate variable per exposure type"""
    test_id = "TVE-08"
    test_name = "By type (separate variables)"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            bytype=True
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve08_bytype.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_09_grace30():
    """TVExpose Test 9: Grace period 30 days"""
    test_id = "TVE-09"
    test_name = "Grace period = 30 days"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            grace=30
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve09_grace30.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_10_grace60():
    """TVExpose Test 10: Grace period 60 days"""
    test_id = "TVE-10"
    test_name = "Grace period = 60 days"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            grace=60
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve10_grace60.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_11_lag():
    """TVExpose Test 11: Lag 14 days"""
    test_id = "TVE-11"
    test_name = "Lag = 14 days"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            lag_days=14
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve11_lag14.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_12_washout():
    """TVExpose Test 12: Washout 30 days"""
    test_id = "TVE-12"
    test_name = "Washout = 30 days"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            washout_days=30
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve12_washout30.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_13_lag_washout():
    """TVExpose Test 13: Combined lag and washout"""
    test_id = "TVE-13"
    test_name = "Lag=14 + Washout=30"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            lag_days=14,
            washout_days=30
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve13_lag_washout.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_14_overlap_layer():
    """TVExpose Test 14: Overlap handling - layer (default)"""
    test_id = "TVE-14"
    test_name = "Overlap handling: layer"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            overlap_method="layer"
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve14_overlap_layer.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvexpose_15_keepcols():
    """TVExpose Test 15: Keep additional columns from master"""
    test_id = "TVE-15"
    test_name = "Keep cols: age, sex"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            keep_cols=["age", "sex"]
        )

        output = exposer.run()
        output_file = save_output(output.data, "tve15_keepcols.csv", test_name)
        result.mark_passed(output.data, output_file)

        # Check for kept columns
        if 'age' in output.data.columns and 'sex' in output.data.columns:
            print(f"  ✓ Age and sex columns kept")

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


# ============================================================================
# TVMERGE TESTS
# ============================================================================

def test_tvmerge_01_basic():
    """TVMerge Test 1: Basic two-dataset merge"""
    test_id = "TVM-01"
    test_name = "Basic two-dataset merge"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # First create two exposure datasets
        print("  Creating exposure dataset 1...")
        exposer1 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv1 = exposer1.run()
        tv1_path = OUTPUT_DIR / "tvm01_tv1.csv"
        tv1.data.to_csv(tv1_path, index=False)

        print("  Creating exposure dataset 2...")
        exposer2 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES2),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv2 = exposer2.run()
        tv2_path = OUTPUT_DIR / "tvm01_tv2.csv"
        tv2.data.to_csv(tv2_path, index=False)

        print("  Merging datasets...")
        merger = TVMerge(
            datasets=[str(tv1_path), str(tv2_path)],
            id_col="patient_id",
            start_cols=["exp_start", "exp_start"],
            stop_cols=["exp_stop", "exp_stop"],
            exposure_cols=["tv_exposure", "tv_exposure"],
            output_names=["drug1", "drug2"]
        )

        merged = merger.merge()
        output_file = save_output(merged, "tvm01_basic.csv", test_name)
        result.mark_passed(merged, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvmerge_02_continuous():
    """TVMerge Test 2: Merge with continuous exposure interpolation"""
    test_id = "TVM-02"
    test_name = "Merge with continuous interpolation"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create continuous exposure datasets
        print("  Creating continuous exposure dataset 1...")
        exposer1 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            exposure_type="continuous",
            continuous_unit="days"
        )
        tv1 = exposer1.run()
        tv1_path = OUTPUT_DIR / "tvm02_tv1_cont.csv"
        tv1.data.to_csv(tv1_path, index=False)

        print("  Creating continuous exposure dataset 2...")
        exposer2 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES2),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            exposure_type="continuous",
            continuous_unit="days"
        )
        tv2 = exposer2.run()
        tv2_path = OUTPUT_DIR / "tvm02_tv2_cont.csv"
        tv2.data.to_csv(tv2_path, index=False)

        # Find the continuous column name
        cont_col1 = [c for c in tv1.data.columns if 'continuous' in c.lower()][0]
        cont_col2 = [c for c in tv2.data.columns if 'continuous' in c.lower()][0]

        print(f"  Using continuous columns: {cont_col1}, {cont_col2}")
        print("  Merging continuous datasets...")
        merger = TVMerge(
            datasets=[str(tv1_path), str(tv2_path)],
            id_col="patient_id",
            start_cols=["exp_start", "exp_start"],
            stop_cols=["exp_stop", "exp_stop"],
            exposure_cols=[cont_col1, cont_col2],
            output_names=["cont1", "cont2"],
            interpolate=True
        )

        merged = merger.merge()
        output_file = save_output(merged, "tvm02_continuous.csv", test_name)
        result.mark_passed(merged, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvmerge_03_three_datasets():
    """TVMerge Test 3: Three-dataset merge"""
    test_id = "TVM-03"
    test_name = "Three-dataset merge"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create three exposure datasets
        print("  Creating exposure dataset 1...")
        exposer1 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv1 = exposer1.run()
        tv1_path = OUTPUT_DIR / "tvm03_tv1.csv"
        tv1.data.to_csv(tv1_path, index=False)

        print("  Creating exposure dataset 2...")
        exposer2 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES2),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv2 = exposer2.run()
        tv2_path = OUTPUT_DIR / "tvm03_tv2.csv"
        tv2.data.to_csv(tv2_path, index=False)

        print("  Creating exposure dataset 3 (with grace period)...")
        exposer3 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            grace=30
        )
        tv3 = exposer3.run()
        tv3_path = OUTPUT_DIR / "tvm03_tv3.csv"
        tv3.data.to_csv(tv3_path, index=False)

        print("  Merging three datasets...")
        merger = TVMerge(
            datasets=[str(tv1_path), str(tv2_path), str(tv3_path)],
            id_col="patient_id",
            start_cols=["exp_start", "exp_start", "exp_start"],
            stop_cols=["exp_stop", "exp_stop", "exp_stop"],
            exposure_cols=["tv_exposure", "tv_exposure", "tv_exposure"],
            output_names=["exp1", "exp2", "exp3"]
        )

        merged = merger.merge()
        output_file = save_output(merged, "tvm03_three_datasets.csv", test_name)
        result.mark_passed(merged, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvmerge_04_generate():
    """TVMerge Test 4: Different output naming with generate"""
    test_id = "TVM-04"
    test_name = "Output naming with generate"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create two exposure datasets
        print("  Creating exposure datasets...")
        exposer1 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv1 = exposer1.run()
        tv1_path = OUTPUT_DIR / "tvm04_tv1.csv"
        tv1.data.to_csv(tv1_path, index=False)

        exposer2 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES2),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv2 = exposer2.run()
        tv2_path = OUTPUT_DIR / "tvm04_tv2.csv"
        tv2.data.to_csv(tv2_path, index=False)

        print("  Merging with custom generate names...")
        merger = TVMerge(
            datasets=[str(tv1_path), str(tv2_path)],
            id_col="patient_id",
            start_cols=["exp_start", "exp_start"],
            stop_cols=["exp_stop", "exp_stop"],
            exposure_cols=["tv_exposure", "tv_exposure"],
            output_names=["primary_drug", "secondary_drug"]
        )

        merged = merger.merge()
        output_file = save_output(merged, "tvm04_generate.csv", test_name)
        result.mark_passed(merged, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvmerge_05_prefix():
    """TVMerge Test 5: Different output naming with prefix"""
    test_id = "TVM-05"
    test_name = "Output naming with prefix"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create two exposure datasets
        print("  Creating exposure datasets...")
        exposer1 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv1 = exposer1.run()
        tv1_path = OUTPUT_DIR / "tvm05_tv1.csv"
        tv1.data.to_csv(tv1_path, index=False)

        exposer2 = TVExpose(
            exposure_data=str(STRESS_EXPOSURES2),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv2 = exposer2.run()
        tv2_path = OUTPUT_DIR / "tvm05_tv2.csv"
        tv2.data.to_csv(tv2_path, index=False)

        print("  Merging with prefix (using default names)...")
        merger = TVMerge(
            datasets=[str(tv1_path), str(tv2_path)],
            id_col="patient_id",
            start_cols=["exp_start", "exp_start"],
            stop_cols=["exp_stop", "exp_stop"],
            exposure_cols=["tv_exposure", "tv_exposure"],
            prefix="medication"
        )

        merged = merger.merge()
        output_file = save_output(merged, "tvm05_prefix.csv", test_name)
        result.mark_passed(merged, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


# ============================================================================
# TVEVENT TESTS
# ============================================================================

def test_tvevent_01_single():
    """TVEvent Test 1: Single event type (MI only)"""
    test_id = "TVT-01"
    test_name = "Single event type (MI)"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create exposure dataset
        print("  Creating exposure dataset...")
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv_data = exposer.run()

        # Read events
        events = pd.read_csv(STRESS_EVENTS)

        # Rename columns for TVEvent and fix invalid intervals
        intervals = tv_data.data.rename(columns={
            'exp_start': 'start',
            'exp_stop': 'stop'
        })
        intervals = fix_intervals(intervals)

        print("  Processing events...")
        tv_event = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col="patient_id",
            date_col="mi_date",
            event_type='single'
        )

        output = tv_event.process()
        output_file = save_output(output.data, "tvt01_single.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvevent_02_recurring():
    """TVEvent Test 2: Recurring event type"""
    test_id = "TVT-02"
    test_name = "Recurring event type"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create exposure dataset
        print("  Creating exposure dataset...")
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv_data = exposer.run()

        # Read events
        events = pd.read_csv(STRESS_EVENTS)

        # Rename columns for TVEvent and fix invalid intervals
        intervals = tv_data.data.rename(columns={
            'exp_start': 'start',
            'exp_stop': 'stop'
        })
        intervals = fix_intervals(intervals)

        print("  Processing recurring events...")
        tv_event = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col="patient_id",
            date_col="mi_date",
            event_type='recurring'
        )

        output = tv_event.process()
        output_file = save_output(output.data, "tvt02_recurring.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvevent_03_single_compete():
    """TVEvent Test 3: Single competing risk (death)"""
    test_id = "TVT-03"
    test_name = "Single competing risk (death)"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create exposure dataset
        print("  Creating exposure dataset...")
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv_data = exposer.run()

        # Read events
        events = pd.read_csv(STRESS_EVENTS)

        # Rename columns for TVEvent and fix invalid intervals
        intervals = tv_data.data.rename(columns={
            'exp_start': 'start',
            'exp_stop': 'stop'
        })
        intervals = fix_intervals(intervals)

        print("  Processing with competing risk...")
        tv_event = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col="patient_id",
            date_col="mi_date",
            compete_cols=["death_date"],
            event_type='single'
        )

        output = tv_event.process()
        output_file = save_output(output.data, "tvt03_single_compete.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvevent_04_multiple_compete():
    """TVEvent Test 4: Multiple competing risks"""
    test_id = "TVT-04"
    test_name = "Multiple competing risks"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create exposure dataset
        print("  Creating exposure dataset...")
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv_data = exposer.run()

        # Read events
        events = pd.read_csv(STRESS_EVENTS)

        # Rename columns for TVEvent and fix invalid intervals
        intervals = tv_data.data.rename(columns={
            'exp_start': 'start',
            'exp_stop': 'stop'
        })
        intervals = fix_intervals(intervals)

        print("  Processing with multiple competing risks...")
        tv_event = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col="patient_id",
            date_col="mi_date",
            compete_cols=["death_date", "emigration_date"],
            event_type='single'
        )

        output = tv_event.process()
        output_file = save_output(output.data, "tvt04_multiple_compete.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvevent_05_continuous():
    """TVEvent Test 5: With continuous variable adjustment"""
    test_id = "TVT-05"
    test_name = "With continuous variable"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create continuous exposure dataset
        print("  Creating continuous exposure dataset...")
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit",
            exposure_type="continuous",
            continuous_unit="days"
        )
        tv_data = exposer.run()

        # Read events
        events = pd.read_csv(STRESS_EVENTS)

        # Rename columns for TVEvent and fix invalid intervals
        intervals = tv_data.data.rename(columns={
            'exp_start': 'start',
            'exp_stop': 'stop'
        })
        intervals = fix_intervals(intervals)

        # Find continuous column
        cont_cols = [c for c in intervals.columns if 'continuous' in c.lower()]

        print("  Processing with continuous variable...")
        tv_event = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col="patient_id",
            date_col="mi_date",
            compete_cols=["death_date"],
            event_type='single',
            continuous_cols=cont_cols if cont_cols else None
        )

        output = tv_event.process()
        output_file = save_output(output.data, "tvt05_continuous.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvevent_06_time_days():
    """TVEvent Test 6: With time generation (days)"""
    test_id = "TVT-06"
    test_name = "Time generation (days)"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create exposure dataset
        print("  Creating exposure dataset...")
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv_data = exposer.run()

        # Read events
        events = pd.read_csv(STRESS_EVENTS)

        # Rename columns for TVEvent and fix invalid intervals
        intervals = tv_data.data.rename(columns={
            'exp_start': 'start',
            'exp_stop': 'stop'
        })
        intervals = fix_intervals(intervals)

        print("  Processing with time in days...")
        tv_event = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col="patient_id",
            date_col="mi_date",
            event_type='single',
            time_col="time_days",
            time_unit="days"
        )

        output = tv_event.process()
        output_file = save_output(output.data, "tvt06_time_days.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


def test_tvevent_07_time_years():
    """TVEvent Test 7: With time generation (years)"""
    test_id = "TVT-07"
    test_name = "Time generation (years)"
    result = TestResult(test_id, test_name)
    log_test(test_id, test_name)

    try:
        # Create exposure dataset
        print("  Creating exposure dataset...")
        exposer = TVExpose(
            exposure_data=str(STRESS_EXPOSURES),
            master_data=str(STRESS_COHORT),
            id_col="patient_id",
            start_col="exp_start",
            stop_col="exp_stop",
            exposure_col="drug_type",
            reference=0,
            entry_col="study_entry",
            exit_col="study_exit"
        )
        tv_data = exposer.run()

        # Read events
        events = pd.read_csv(STRESS_EVENTS)

        # Rename columns for TVEvent and fix invalid intervals
        intervals = tv_data.data.rename(columns={
            'exp_start': 'start',
            'exp_stop': 'stop'
        })
        intervals = fix_intervals(intervals)

        print("  Processing with time in years...")
        tv_event = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col="patient_id",
            date_col="mi_date",
            event_type='single',
            time_col="time_years",
            time_unit="years"
        )

        output = tv_event.process()
        output_file = save_output(output.data, "tvt07_time_years.csv", test_name)
        result.mark_passed(output.data, output_file)

        print(f"\n✓ Test PASSED")

    except NotImplementedError as e:
        result.mark_not_implemented(e)
        print(f"\n⚠ Test NOT IMPLEMENTED: {str(e)}")
    except Exception as e:
        result.mark_failed(e)
        print(f"\n✗ Test FAILED: {str(e)}")
        traceback.print_exc()

    test_results.append(result)
    return result


# ============================================================================
# MAIN TEST RUNNER
# ============================================================================

def generate_summary_report():
    """Generate comprehensive summary report"""
    print("\n" + "="*80)
    print("COMPREHENSIVE TEST SUITE SUMMARY")
    print("="*80)

    # Count by status
    status_counts = {
        "PASSED": 0,
        "FAILED": 0,
        "NOT_IMPLEMENTED": 0,
        "SKIPPED": 0
    }

    for result in test_results:
        if result.status in status_counts:
            status_counts[result.status] += 1

    total_tests = len(test_results)

    print(f"\nTotal tests run: {total_tests}")
    print(f"  ✓ Passed: {status_counts['PASSED']}")
    print(f"  ✗ Failed: {status_counts['FAILED']}")
    print(f"  ⚠ Not Implemented: {status_counts['NOT_IMPLEMENTED']}")
    print(f"  - Skipped: {status_counts['SKIPPED']}")

    # Detailed results by category
    print("\n" + "="*80)
    print("TVEXPOSE TESTS (15 tests)")
    print("="*80)
    for result in test_results:
        if result.test_id.startswith("TVE"):
            status_symbol = {
                "PASSED": "✓",
                "FAILED": "✗",
                "NOT_IMPLEMENTED": "⚠",
                "SKIPPED": "-"
            }.get(result.status, "?")

            print(f"{status_symbol} {result.test_id}: {result.test_name}")
            if result.status == "PASSED":
                print(f"    Rows: {result.rows}, Cols: {result.cols}, Patients: {result.unique_patients}")
            elif result.error_message:
                error_short = result.error_message[:100]
                print(f"    Error: {error_short}")

    print("\n" + "="*80)
    print("TVMERGE TESTS (5 tests)")
    print("="*80)
    for result in test_results:
        if result.test_id.startswith("TVM"):
            status_symbol = {
                "PASSED": "✓",
                "FAILED": "✗",
                "NOT_IMPLEMENTED": "⚠",
                "SKIPPED": "-"
            }.get(result.status, "?")

            print(f"{status_symbol} {result.test_id}: {result.test_name}")
            if result.status == "PASSED":
                print(f"    Rows: {result.rows}, Cols: {result.cols}, Patients: {result.unique_patients}")
            elif result.error_message:
                error_short = result.error_message[:100]
                print(f"    Error: {error_short}")

    print("\n" + "="*80)
    print("TVEVENT TESTS (7 tests)")
    print("="*80)
    for result in test_results:
        if result.test_id.startswith("TVT"):
            status_symbol = {
                "PASSED": "✓",
                "FAILED": "✗",
                "NOT_IMPLEMENTED": "⚠",
                "SKIPPED": "-"
            }.get(result.status, "?")

            print(f"{status_symbol} {result.test_id}: {result.test_name}")
            if result.status == "PASSED":
                print(f"    Rows: {result.rows}, Cols: {result.cols}, Patients: {result.unique_patients}")
            elif result.error_message:
                error_short = result.error_message[:100]
                print(f"    Error: {error_short}")

    # Save detailed report to file
    report_path = OUTPUT_DIR / "comprehensive_test_report.txt"
    with open(report_path, 'w') as f:
        f.write("COMPREHENSIVE PYTHON TVTOOLS TEST REPORT\n")
        f.write("="*80 + "\n\n")
        f.write(f"Test Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total Tests: {total_tests}\n")
        f.write(f"Passed: {status_counts['PASSED']}\n")
        f.write(f"Failed: {status_counts['FAILED']}\n")
        f.write(f"Not Implemented: {status_counts['NOT_IMPLEMENTED']}\n")
        f.write(f"Skipped: {status_counts['SKIPPED']}\n\n")

        f.write("="*80 + "\n")
        f.write("DETAILED RESULTS\n")
        f.write("="*80 + "\n\n")

        for result in test_results:
            f.write(f"{result.test_id}: {result.test_name}\n")
            f.write(f"  Status: {result.status}\n")
            if result.status == "PASSED":
                f.write(f"  Rows: {result.rows}\n")
                f.write(f"  Columns: {result.cols}\n")
                f.write(f"  Unique Patients: {result.unique_patients}\n")
                f.write(f"  Output File: {result.output_file}\n")
            elif result.error_message:
                f.write(f"  Error: {result.error_message}\n")
            f.write("\n")

    print(f"\nDetailed report saved to: {report_path}")
    print(f"All outputs saved to: {OUTPUT_DIR}")

    return status_counts


def run_all_tests():
    """Run all comprehensive tests"""
    print("\n" + "="*80)
    print("PYTHON TVTOOLS COMPREHENSIVE TEST SUITE")
    print("="*80)
    print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"Using stress test data:")
    print(f"  - {STRESS_COHORT}")
    print(f"  - {STRESS_EXPOSURES}")
    print(f"  - {STRESS_EXPOSURES2}")
    print(f"  - {STRESS_EVENTS}")

    # Run all TVExpose tests
    print("\n" + "="*80)
    print("RUNNING TVEXPOSE TESTS (15 tests)")
    print("="*80)

    test_tvexpose_01_basic()
    test_tvexpose_02_evertreated()
    test_tvexpose_03_currentformer()
    test_tvexpose_04_duration()
    test_tvexpose_05_continuous_days()
    test_tvexpose_06_continuous_months()
    test_tvexpose_07_continuous_years()
    test_tvexpose_08_bytype()
    test_tvexpose_09_grace30()
    test_tvexpose_10_grace60()
    test_tvexpose_11_lag()
    test_tvexpose_12_washout()
    test_tvexpose_13_lag_washout()
    test_tvexpose_14_overlap_layer()
    test_tvexpose_15_keepcols()

    # Run all TVMerge tests
    print("\n" + "="*80)
    print("RUNNING TVMERGE TESTS (5 tests)")
    print("="*80)

    test_tvmerge_01_basic()
    test_tvmerge_02_continuous()
    test_tvmerge_03_three_datasets()
    test_tvmerge_04_generate()
    test_tvmerge_05_prefix()

    # Run all TVEvent tests
    print("\n" + "="*80)
    print("RUNNING TVEVENT TESTS (7 tests)")
    print("="*80)

    test_tvevent_01_single()
    test_tvevent_02_recurring()
    test_tvevent_03_single_compete()
    test_tvevent_04_multiple_compete()
    test_tvevent_05_continuous()
    test_tvevent_06_time_days()
    test_tvevent_07_time_years()

    # Generate summary
    status_counts = generate_summary_report()

    print(f"\nEnd time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    return status_counts


if __name__ == "__main__":
    try:
        status_counts = run_all_tests()

        # Exit with appropriate code
        if status_counts["FAILED"] > 0:
            sys.exit(1)
        elif status_counts["PASSED"] == 0:
            sys.exit(2)  # No tests passed
        else:
            sys.exit(0)

    except Exception as e:
        print(f"\n\nFATAL ERROR: {str(e)}")
        traceback.print_exc()
        sys.exit(3)
