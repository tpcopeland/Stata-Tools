"""
tvmerge - Merge multiple time-varying datasets

This module merges multiple time-varying exposure datasets using Cartesian
interval intersections to create all combinations of overlapping exposures.

Main classes:
    TVMerge: Main class for merging datasets
    MergeMetadata: Metadata container

Example:
    >>> from tvtools.tvmerge import TVMerge
    >>> merger = TVMerge(
    ...     datasets=['tv_hrt.csv', 'tv_dmt.csv'],
    ...     id_col='id',
    ...     start_cols=['rx_start', 'dmt_start'],
    ...     stop_cols=['rx_stop', 'dmt_stop'],
    ...     exposure_cols=['tv_exposure', 'tv_exposure'],
    ...     output_names=['hrt', 'dmt']
    ... )
    >>> result = merger.merge()
"""

from .merger import TVMerge
from .types import MergeMetadata, DatasetInput
from .exceptions import (
    TVMergeError,
    IDMismatchError,
    InvalidPeriodError,
    ColumnNotFoundError,
)

__all__ = [
    "TVMerge",
    "MergeMetadata",
    "DatasetInput",
    "TVMergeError",
    "IDMismatchError",
    "InvalidPeriodError",
    "ColumnNotFoundError",
]
