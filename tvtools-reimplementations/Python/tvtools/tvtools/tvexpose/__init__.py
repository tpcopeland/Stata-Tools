"""
tvexpose - Create time-varying exposure variables

This module creates time-varying exposure variables from period-based
exposure data, with support for multiple exposure types and overlap
resolution strategies.

Main classes:
    TVExpose: Main class for exposure transformation
    TVExposeResult: Result container

Example:
    >>> from tvtools.tvexpose import TVExpose
    >>> exposer = TVExpose(
    ...     exposure_data="prescriptions.csv",
    ...     master_data="cohort.csv",
    ...     id_col="patient_id",
    ...     start_col="rx_start",
    ...     stop_col="rx_stop",
    ...     exposure_col="drug_type",
    ...     reference=0,
    ...     entry_col="study_entry",
    ...     exit_col="study_exit"
    ... )
    >>> result = exposer.run()
"""

from .exposer import TVExpose
from .types import TVExposeResult, ExposureType, OverlapMethod, TimeUnit
from .exceptions import TVExposeError, ValidationError

__all__ = [
    "TVExpose",
    "TVExposeResult",
    "TVExposeError",
    "ValidationError",
    "ExposureType",
    "OverlapMethod",
    "TimeUnit",
]
