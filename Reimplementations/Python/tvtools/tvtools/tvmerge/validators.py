"""Input validation functions."""

from typing import List, Optional
import pandas as pd


def validate_dataset_count(datasets: List) -> None:
    """Validate that at least 2 datasets are provided."""
    if len(datasets) < 2:
        raise ValueError("tvmerge requires at least 2 datasets")


def validate_column_counts(
    n_datasets: int,
    start_cols: List[str],
    stop_cols: List[str],
    exposure_cols: List[str],
) -> None:
    """Validate that column lists match dataset count."""
    if len(start_cols) != n_datasets:
        raise ValueError(
            f"Number of start columns ({len(start_cols)}) must equal "
            f"number of datasets ({n_datasets})"
        )
    if len(stop_cols) != n_datasets:
        raise ValueError(
            f"Number of stop columns ({len(stop_cols)}) must equal "
            f"number of datasets ({n_datasets})"
        )
    if len(exposure_cols) != n_datasets:
        raise ValueError(
            f"Number of exposure columns ({len(exposure_cols)}) must equal "
            f"number of datasets ({n_datasets})"
        )


def validate_naming_options(
    output_names: Optional[List[str]],
    prefix: Optional[str],
    n_datasets: int,
) -> None:
    """Validate naming options."""
    if output_names is not None and prefix is not None:
        raise ValueError("Specify either output_names or prefix, not both")

    if output_names is not None and len(output_names) != n_datasets:
        raise ValueError(
            f"output_names must contain exactly {n_datasets} names "
            "(one per dataset)"
        )


def validate_batch_pct(batch_pct: int) -> None:
    """Validate batch percentage."""
    if not 1 <= batch_pct <= 100:
        raise ValueError("batch_pct must be between 1 and 100")


def validate_required_columns(
    df: pd.DataFrame,
    required_cols: List[str],
    dataset_name: str,
) -> None:
    """Validate that required columns exist in dataset."""
    missing = set(required_cols) - set(df.columns)
    if missing:
        raise ValueError(
            f"Required columns missing from {dataset_name}: {missing}"
        )
