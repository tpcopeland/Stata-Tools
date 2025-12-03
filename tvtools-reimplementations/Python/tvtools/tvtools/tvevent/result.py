"""Type definitions for TVEvent module."""

from dataclasses import dataclass
from typing import Dict, Optional
import pandas as pd


@dataclass
class TVEventResult:
    """Container for tvevent results and metadata."""

    data: pd.DataFrame
    n_total: int
    n_events: int
    n_splits: int
    event_labels: Dict[int, str]
    output_col: str
    time_col: Optional[str]
    event_type: str

    def __repr__(self) -> str:
        return (
            f"TVEventResult(\n"
            f"  Total observations: {self.n_total:,}\n"
            f"  Events flagged: {self.n_events:,}\n"
            f"  Intervals split: {self.n_splits:,}\n"
            f"  Event type: {self.event_type}\n"
            f"  Output column: {self.output_col}\n"
            f")"
        )
