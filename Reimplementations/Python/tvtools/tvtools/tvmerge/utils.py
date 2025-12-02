"""Utility functions."""

import pandas as pd
from pathlib import Path
from typing import Union


def load_dataset(filepath: Union[str, Path, pd.DataFrame]) -> pd.DataFrame:
    """
    Load dataset from file or return DataFrame.

    Supports: .csv, .dta (Stata), .xlsx, .parquet
    """
    if isinstance(filepath, pd.DataFrame):
        return filepath.copy()

    filepath = Path(filepath)

    if filepath.suffix == '.csv':
        return pd.read_csv(filepath)
    elif filepath.suffix == '.dta':
        return pd.read_stata(filepath)
    elif filepath.suffix == '.xlsx':
        return pd.read_excel(filepath)
    elif filepath.suffix == '.parquet':
        return pd.read_parquet(filepath)
    else:
        raise ValueError(f"Unsupported file format: {filepath.suffix}")


def format_number(n: int) -> str:
    """Format number with thousands separator."""
    return f"{n:,}"
