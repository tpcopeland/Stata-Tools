"""
tvevent - Integrate events and competing risks into time-varying datasets

This module integrates outcome events and competing risks into time-varying
datasets created by tvexpose/tvmerge, preparing data for survival analysis.

Main class:
    TVEvent: Main class for event integration
    TVEventResult: Result container

Example:
    >>> from tvtools.tvevent import TVEvent
    >>> tv = TVEvent(
    ...     intervals_data=tvexpose_output,
    ...     events_data='cohort.csv',
    ...     id_col='person_id',
    ...     date_col='event_date',
    ...     compete_cols=['death_date']
    ... )
    >>> result = tv.process()
"""

from .core import TVEvent
from .result import TVEventResult
from .exceptions import (
    TVEventError,
    TVEventValidationError,
    TVEventProcessingError
)

__all__ = [
    "TVEvent",
    "TVEventResult",
    "TVEventError",
    "TVEventValidationError",
    "TVEventProcessingError",
]
