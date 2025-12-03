"""Input validation functions for tvexpose."""

import pandas as pd
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .exposer import TVExpose

from .exceptions import ValidationError
from .types import ExposureType


def validate_inputs(exposer: 'TVExpose', exposure_df: pd.DataFrame, master_df: pd.DataFrame) -> None:
    """
    Validate all inputs for TVExpose.

    Parameters
    ----------
    exposer : TVExpose
        The TVExpose instance to validate
    exposure_df : pd.DataFrame
        Exposure data
    master_df : pd.DataFrame
        Master/cohort data

    Raises
    ------
    ValidationError
        If any validation check fails
    """
    # Validate column existence
    _validate_columns_exist(exposer, exposure_df, master_df)

    # Validate data types
    _validate_data_types(exposer, exposure_df, master_df)

    # Validate option combinations
    _validate_option_combinations(exposer)

    # Validate value ranges
    _validate_value_ranges(exposer)

    # Validate required options for exposure types
    _validate_exposure_type_requirements(exposer)


def _validate_columns_exist(exposer: 'TVExpose', exposure_df: pd.DataFrame, master_df: pd.DataFrame) -> None:
    """Validate that required columns exist in datasets."""
    # Check master_df columns
    master_required = [exposer.id_col, exposer.entry_col, exposer.exit_col]
    missing = [col for col in master_required if col not in master_df.columns]
    if missing:
        raise ValidationError(f"Master data missing required columns: {missing}")

    # Check exposure_df columns
    exposure_required = [exposer.id_col, exposer.start_col, exposer.exposure_col]
    if not exposer.pointtime and exposer.stop_col:
        exposure_required.append(exposer.stop_col)
    elif not exposer.pointtime and not exposer.stop_col:
        raise ValidationError("stop_col is required unless pointtime=True")

    missing = [col for col in exposure_required if col not in exposure_df.columns]
    if missing:
        raise ValidationError(f"Exposure data missing required columns: {missing}")

    # Check keep_cols exist in master
    if exposer.keep_cols:
        missing = [col for col in exposer.keep_cols if col not in master_df.columns]
        if missing:
            raise ValidationError(f"keep_cols not found in master data: {missing}")


def _validate_data_types(exposer: 'TVExpose', exposure_df: pd.DataFrame, master_df: pd.DataFrame) -> None:
    """Validate that columns have appropriate data types."""
    # Check date columns in master
    for col in [exposer.entry_col, exposer.exit_col]:
        if not pd.api.types.is_datetime64_any_dtype(master_df[col]):
            raise ValidationError(f"Master column '{col}' must be datetime type")

    # Check date columns in exposure
    if not pd.api.types.is_datetime64_any_dtype(exposure_df[exposer.start_col]):
        raise ValidationError(f"Exposure column '{exposer.start_col}' must be datetime type")

    if not exposer.pointtime and exposer.stop_col:
        if not pd.api.types.is_datetime64_any_dtype(exposure_df[exposer.stop_col]):
            raise ValidationError(f"Exposure column '{exposer.stop_col}' must be datetime type")

    # Check exposure_col is numeric or categorical (string)
    # Allow both numeric and string categorical exposures
    if not (pd.api.types.is_numeric_dtype(exposure_df[exposer.exposure_col]) or
            pd.api.types.is_string_dtype(exposure_df[exposer.exposure_col]) or
            pd.api.types.is_object_dtype(exposure_df[exposer.exposure_col])):
        raise ValidationError(f"Exposure column '{exposer.exposure_col}' must be numeric or categorical (string)")


def _validate_option_combinations(exposer: 'TVExpose') -> None:
    """Validate that mutually exclusive options are not used together."""
    # Priority order only valid with priority method
    if exposer.priority_order and exposer.overlap_method.value != "priority":
        raise ValidationError("priority_order requires overlap_method='priority'")

    # Combine col only valid with combine method
    if exposer.combine_col and exposer.overlap_method.value != "combine":
        raise ValidationError("combine_col requires overlap_method='combine'")

    # Window requires lag and/or washout
    if exposer.window and exposer.lag_days == 0 and exposer.washout_days == 0:
        raise ValidationError("window requires lag_days > 0 or washout_days > 0")


def _validate_value_ranges(exposer: 'TVExpose') -> None:
    """Validate that numeric values are in valid ranges."""
    if exposer.grace.default < 0:
        raise ValidationError("grace must be >= 0")

    if exposer.merge_days < 0:
        raise ValidationError("merge_days must be >= 0")

    if exposer.fillgaps < 0:
        raise ValidationError("fillgaps must be >= 0")

    if exposer.carryforward < 0:
        raise ValidationError("carryforward must be >= 0")

    if exposer.lag_days < 0:
        raise ValidationError("lag_days must be >= 0")

    if exposer.washout_days < 0:
        raise ValidationError("washout_days must be >= 0")

    if exposer.window:
        if len(exposer.window) != 2:
            raise ValidationError("window must be a tuple of (min_days, max_days)")
        if exposer.window[0] < 0 or exposer.window[1] < 0:
            raise ValidationError("window days must be >= 0")
        if exposer.window[0] > exposer.window[1]:
            raise ValidationError("window min_days must be <= max_days")


def _validate_exposure_type_requirements(exposer: 'TVExpose') -> None:
    """Validate that required options are provided for each exposure type."""
    if exposer.exposure_type == ExposureType.DURATION:
        if not exposer.duration_cutpoints:
            raise ValidationError("duration_cutpoints required for exposure_type='duration'")
        if not exposer.continuous_unit:
            raise ValidationError("continuous_unit required for exposure_type='duration'")
        if len(exposer.duration_cutpoints) < 1:
            raise ValidationError("duration_cutpoints must have at least one value")
        if exposer.duration_cutpoints != sorted(exposer.duration_cutpoints):
            raise ValidationError("duration_cutpoints must be in ascending order")

    if exposer.exposure_type == ExposureType.CONTINUOUS:
        if not exposer.continuous_unit:
            raise ValidationError("continuous_unit required for exposure_type='continuous'")

    if exposer.exposure_type == ExposureType.RECENCY:
        if not exposer.recency_cutpoints:
            raise ValidationError("recency_cutpoints required for exposure_type='recency'")
        if len(exposer.recency_cutpoints) < 1:
            raise ValidationError("recency_cutpoints must have at least one value")
        if exposer.recency_cutpoints != sorted(exposer.recency_cutpoints):
            raise ValidationError("recency_cutpoints must be in ascending order")
