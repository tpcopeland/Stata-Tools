"""Type definitions for tvexpose module."""

from dataclasses import dataclass, field
from typing import Optional, Dict, List
from enum import Enum
import pandas as pd


class ExposureType(Enum):
    """Exposure definition type."""
    TIME_VARYING = "time_varying"      # Default categorical
    EVER_TREATED = "ever_treated"       # Binary 0/1 permanent switch
    CURRENT_FORMER = "current_former"   # Trichotomous 0/1/2
    DURATION = "duration"               # Cumulative duration categories
    CONTINUOUS = "continuous"           # Continuous cumulative
    RECENCY = "recency"                 # Time since last exposure


class OverlapMethod(Enum):
    """Method for handling overlapping exposures."""
    LAYER = "layer"         # Later takes precedence, earlier resumes (default)
    PRIORITY = "priority"   # Static priority order
    SPLIT = "split"         # Create all boundary combinations
    COMBINE = "combine"     # Encode overlaps as combined values


class TimeUnit(Enum):
    """Time units for continuous exposure."""
    DAYS = "days"
    WEEKS = "weeks"
    MONTHS = "months"
    QUARTERS = "quarters"
    YEARS = "years"

    @property
    def days_per_unit(self) -> float:
        """Days per unit for conversion."""
        mapping = {
            "days": 1.0,
            "weeks": 7.0,
            "months": 30.4375,
            "quarters": 91.3125,
            "years": 365.25
        }
        return mapping[self.value]


@dataclass
class GracePeriod:
    """Grace period specification."""
    default: int = 0
    by_category: Optional[Dict[int, int]] = None

    def get_grace(self, exposure_value: int) -> int:
        """Get grace period for an exposure value."""
        if self.by_category and exposure_value in self.by_category:
            return self.by_category[exposure_value]
        return self.default


@dataclass
class TVExposeResult:
    """Result container for tvexpose."""
    data: pd.DataFrame
    n_persons: int
    n_periods: int
    total_time: float
    exposed_time: float
    unexposed_time: float
    pct_exposed: float
    exposure_type: ExposureType
    overlap_ids: Optional[List] = None
    warnings: List[str] = field(default_factory=list)
