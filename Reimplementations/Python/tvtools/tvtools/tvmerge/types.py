"""Type definitions and protocols."""

from typing import Protocol, Union, List
from pathlib import Path
from dataclasses import dataclass, field
import pandas as pd


# Type alias for dataset input
DatasetInput = Union[str, Path, pd.DataFrame]


@dataclass
class MergeMetadata:
    """Stores metadata about the merge operation."""
    n_observations: int
    n_persons: int
    mean_periods: float
    max_periods: int
    n_datasets: int
    n_continuous: int
    n_categorical: int
    exposure_vars: List[str]
    continuous_vars: List[str]
    categorical_vars: List[str]
    start_name: str
    stop_name: str
    datasets: List[str]
    invalid_periods: dict = field(default_factory=dict)
    n_duplicates_dropped: int = 0


class MergeableDataset(Protocol):
    """Protocol for datasets that can be merged."""

    def __getitem__(self, key):
        """Support column access."""
        ...

    @property
    def columns(self) -> List[str]:
        """Return column names."""
        ...
