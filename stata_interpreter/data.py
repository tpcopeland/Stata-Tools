"""
Stata Data Management Layer

Wraps pandas DataFrame with Stata-specific semantics:
- Variable labels
- Value labels
- Display formats
- By-group processing with _n and _N
- Missing value handling (. in Stata)
"""

import pandas as pd
import numpy as np
from typing import Optional, Any, Union
from dataclasses import dataclass, field
import copy


@dataclass
class ValueLabel:
    """A Stata value label definition."""

    name: str
    mapping: dict[int, str] = field(default_factory=dict)

    def define(self, value: int, label: str) -> None:
        """Add or update a value-label mapping."""
        self.mapping[value] = label

    def get_label(self, value: int) -> Optional[str]:
        """Get label for a value."""
        return self.mapping.get(value)

    def get_value(self, label: str) -> Optional[int]:
        """Get value for a label."""
        for v, l in self.mapping.items():
            if l == label:
                return v
        return None


@dataclass
class VariableMetadata:
    """Metadata for a single variable."""

    name: str
    label: str = ""
    format: str = "%9.0g"
    value_label: Optional[str] = None  # Name of value label to use
    type: str = "float"  # byte, int, long, float, double, str#


class StataData:
    """
    Stata-like data container built on pandas DataFrame.

    Provides Stata semantics for data manipulation:
    - Missing values represented as NaN
    - Variable and value labels
    - By-group operations with _n and _N
    - Observation indexing (1-based in Stata, 0-based internally)
    """

    # Stata missing value codes
    MISSING = np.nan
    MISSING_VALUES = {".": np.nan, ".a": np.nan, ".b": np.nan, ".z": np.nan}

    def __init__(self, df: Optional[pd.DataFrame] = None):
        """Initialize with optional DataFrame."""
        self._df: pd.DataFrame = df.copy() if df is not None else pd.DataFrame()
        self._var_labels: dict[str, str] = {}
        self._var_formats: dict[str, str] = {}
        self._var_value_labels: dict[str, str] = {}  # var -> value label name
        self._value_labels: dict[str, ValueLabel] = {}
        self._notes: dict[str, list[str]] = {}  # var -> list of notes

        # Current by-group context
        self._by_groups: Optional[pd.core.groupby.DataFrameGroupBy] = None
        self._current_group: Optional[tuple] = None

        # Sort order
        self._sort_vars: list[str] = []

    @property
    def df(self) -> pd.DataFrame:
        """Access the underlying DataFrame."""
        return self._df

    @df.setter
    def df(self, value: pd.DataFrame) -> None:
        """Set the underlying DataFrame."""
        self._df = value

    @property
    def N(self) -> int:
        """Total number of observations (Stata's _N)."""
        return len(self._df)

    @property
    def varlist(self) -> list[str]:
        """List of variable names."""
        return list(self._df.columns)

    def clear(self) -> None:
        """Clear all data and metadata."""
        self._df = pd.DataFrame()
        self._var_labels.clear()
        self._var_formats.clear()
        self._var_value_labels.clear()
        self._value_labels.clear()
        self._notes.clear()
        self._by_groups = None
        self._current_group = None
        self._sort_vars.clear()

    def copy(self) -> "StataData":
        """Create a deep copy of the data."""
        new_data = StataData(self._df.copy())
        new_data._var_labels = copy.deepcopy(self._var_labels)
        new_data._var_formats = copy.deepcopy(self._var_formats)
        new_data._var_value_labels = copy.deepcopy(self._var_value_labels)
        new_data._value_labels = copy.deepcopy(self._value_labels)
        new_data._notes = copy.deepcopy(self._notes)
        new_data._sort_vars = self._sort_vars.copy()
        return new_data

    # =========================================================================
    # Variable Operations
    # =========================================================================

    def has_var(self, name: str) -> bool:
        """Check if variable exists."""
        return name in self._df.columns

    def get_var(self, name: str) -> pd.Series:
        """Get a variable as Series."""
        if name not in self._df.columns:
            raise KeyError(f"variable {name} not found")
        return self._df[name]

    def set_var(self, name: str, values: Any) -> None:
        """Set or create a variable."""
        self._df[name] = values

    def drop_var(self, names: Union[str, list[str]]) -> None:
        """Drop variable(s)."""
        if isinstance(names, str):
            names = [names]
        self._df = self._df.drop(columns=names, errors="ignore")
        # Clean up metadata
        for name in names:
            self._var_labels.pop(name, None)
            self._var_formats.pop(name, None)
            self._var_value_labels.pop(name, None)
            self._notes.pop(name, None)

    def rename_var(self, old_name: str, new_name: str) -> None:
        """Rename a variable."""
        if old_name not in self._df.columns:
            raise KeyError(f"variable {old_name} not found")
        self._df = self._df.rename(columns={old_name: new_name})
        # Move metadata
        if old_name in self._var_labels:
            self._var_labels[new_name] = self._var_labels.pop(old_name)
        if old_name in self._var_formats:
            self._var_formats[new_name] = self._var_formats.pop(old_name)
        if old_name in self._var_value_labels:
            self._var_value_labels[new_name] = self._var_value_labels.pop(old_name)

    def keep_vars(self, names: list[str]) -> None:
        """Keep only specified variables."""
        existing = [n for n in names if n in self._df.columns]
        dropped = set(self._df.columns) - set(existing)
        self._df = self._df[existing]
        for name in dropped:
            self._var_labels.pop(name, None)
            self._var_formats.pop(name, None)
            self._var_value_labels.pop(name, None)
            self._notes.pop(name, None)

    def order_vars(self, names: list[str]) -> None:
        """Reorder variables (put specified vars first)."""
        current = list(self._df.columns)
        # Put specified vars first, then others
        new_order = [n for n in names if n in current]
        new_order += [n for n in current if n not in new_order]
        self._df = self._df[new_order]

    # =========================================================================
    # Observation Operations
    # =========================================================================

    def keep_obs(self, mask: pd.Series) -> None:
        """Keep observations where mask is True."""
        self._df = self._df[mask].reset_index(drop=True)

    def drop_obs(self, mask: pd.Series) -> None:
        """Drop observations where mask is True."""
        self._df = self._df[~mask].reset_index(drop=True)

    def keep_in(self, start: int, end: int) -> None:
        """Keep observations in range (1-based, inclusive)."""
        # Convert to 0-based
        start_idx = max(0, start - 1)
        end_idx = min(len(self._df), end) if end > 0 else len(self._df)
        self._df = self._df.iloc[start_idx:end_idx].reset_index(drop=True)

    def expand(self, n: int) -> None:
        """Expand each observation n times."""
        self._df = self._df.loc[self._df.index.repeat(n)].reset_index(drop=True)

    def set_obs(self, n: int) -> None:
        """Set number of observations (extend with missing or truncate)."""
        current_n = len(self._df)
        if n > current_n:
            # Add rows with missing values
            new_rows = pd.DataFrame(
                index=range(n - current_n), columns=self._df.columns
            )
            self._df = pd.concat([self._df, new_rows], ignore_index=True)
        elif n < current_n:
            self._df = self._df.iloc[:n]

    # =========================================================================
    # Labels
    # =========================================================================

    def set_var_label(self, varname: str, label: str) -> None:
        """Set variable label."""
        self._var_labels[varname] = label

    def get_var_label(self, varname: str) -> str:
        """Get variable label."""
        return self._var_labels.get(varname, "")

    def set_var_format(self, varname: str, fmt: str) -> None:
        """Set variable display format."""
        self._var_formats[varname] = fmt

    def get_var_format(self, varname: str) -> str:
        """Get variable display format."""
        return self._var_formats.get(varname, "%9.0g")

    def define_value_label(self, name: str) -> ValueLabel:
        """Define or get a value label."""
        if name not in self._value_labels:
            self._value_labels[name] = ValueLabel(name)
        return self._value_labels[name]

    def label_values(self, varname: str, label_name: str) -> None:
        """Assign a value label to a variable."""
        self._var_value_labels[varname] = label_name

    def get_value_label(self, varname: str, value: int) -> Optional[str]:
        """Get the label for a value in a variable."""
        label_name = self._var_value_labels.get(varname)
        if label_name and label_name in self._value_labels:
            return self._value_labels[label_name].get_label(value)
        return None

    # =========================================================================
    # Sorting
    # =========================================================================

    def sort(self, vars: list[str], ascending: Union[bool, list[bool]] = True) -> None:
        """Sort data by variables."""
        self._df = self._df.sort_values(by=vars, ascending=ascending).reset_index(
            drop=True
        )
        self._sort_vars = vars

    def gsort(
        self, vars: list[str], ascending: Union[bool, list[bool]] = True
    ) -> None:
        """Sort data (gsort allows descending with -)."""
        self._df = self._df.sort_values(by=vars, ascending=ascending).reset_index(
            drop=True
        )
        self._sort_vars = vars

    def is_sorted_by(self, vars: list[str]) -> bool:
        """Check if data is sorted by variables."""
        return self._sort_vars == vars

    # =========================================================================
    # By-Group Operations
    # =========================================================================

    def setup_by(self, vars: list[str], sort_vars: Optional[list[str]] = None) -> None:
        """Set up by-group processing."""
        if sort_vars:
            self.sort(vars + sort_vars)
        self._by_groups = self._df.groupby(vars, sort=False)

    def get_by_groups(self):
        """Get by-group iterator."""
        if self._by_groups is None:
            return [(None, self._df)]
        return self._by_groups

    def get_n(self, idx: int) -> int:
        """
        Get _n (observation number within group, 1-based).

        In Stata, _n is the observation number within the current by-group.
        """
        return idx + 1

    def get_N(self, group_size: Optional[int] = None) -> int:
        """
        Get _N (total observations in group).

        In Stata, _N is the total number of observations in the current by-group.
        """
        if group_size is not None:
            return group_size
        return len(self._df)

    def compute_by_n(self, by_vars: Optional[list[str]] = None) -> pd.Series:
        """
        Compute _n for all observations.

        Returns a Series with 1-based observation numbers within each group.
        """
        if by_vars:
            return self._df.groupby(by_vars).cumcount() + 1
        return pd.Series(range(1, len(self._df) + 1))

    def compute_by_N(self, by_vars: Optional[list[str]] = None) -> pd.Series:
        """
        Compute _N for all observations.

        Returns a Series with group sizes for each observation.
        """
        if by_vars:
            return self._df.groupby(by_vars)[by_vars[0]].transform("count")
        return pd.Series([len(self._df)] * len(self._df))

    # =========================================================================
    # Type Information
    # =========================================================================

    def get_var_type(self, varname: str) -> str:
        """Get Stata-style type for a variable."""
        if varname not in self._df.columns:
            raise KeyError(f"variable {varname} not found")

        dtype = self._df[varname].dtype

        if dtype == np.float64:
            return "double"
        elif dtype == np.float32:
            return "float"
        elif dtype == np.int64:
            return "long"
        elif dtype == np.int32:
            return "int"
        elif dtype == np.int16:
            return "int"
        elif dtype == np.int8:
            return "byte"
        elif dtype == object:
            # String - get max length
            max_len = self._df[varname].astype(str).str.len().max()
            return f"str{int(max_len) if pd.notna(max_len) else 1}"
        else:
            return "float"

    def is_numeric(self, varname: str) -> bool:
        """Check if variable is numeric."""
        if varname not in self._df.columns:
            return False
        return pd.api.types.is_numeric_dtype(self._df[varname])

    def is_string(self, varname: str) -> bool:
        """Check if variable is string."""
        if varname not in self._df.columns:
            return False
        return self._df[varname].dtype == object

    # =========================================================================
    # Missing Values
    # =========================================================================

    def is_missing(self, varname: str) -> pd.Series:
        """Return boolean Series indicating missing values."""
        return self._df[varname].isna()

    def count_missing(self, varname: str) -> int:
        """Count missing values in a variable."""
        return self._df[varname].isna().sum()

    def replace_missing(self, varname: str, value: Any) -> None:
        """Replace missing values with a value."""
        self._df[varname] = self._df[varname].fillna(value)

    # =========================================================================
    # Summary Statistics
    # =========================================================================

    def count(self, condition: Optional[pd.Series] = None) -> int:
        """Count observations (optionally with condition)."""
        if condition is not None:
            return condition.sum()
        return len(self._df)

    def summarize(self, varname: str) -> dict:
        """Get summary statistics for a variable."""
        series = self._df[varname]
        return {
            "N": series.count(),
            "mean": series.mean(),
            "sd": series.std(),
            "min": series.min(),
            "max": series.max(),
            "sum": series.sum(),
            "p25": series.quantile(0.25) if series.count() > 0 else np.nan,
            "p50": series.quantile(0.50) if series.count() > 0 else np.nan,
            "p75": series.quantile(0.75) if series.count() > 0 else np.nan,
        }

    # =========================================================================
    # I/O Helpers
    # =========================================================================

    def to_dict(self) -> dict:
        """Export data and metadata as dictionary."""
        return {
            "data": self._df.to_dict(orient="list"),
            "var_labels": self._var_labels,
            "var_formats": self._var_formats,
            "var_value_labels": self._var_value_labels,
            "value_labels": {
                name: vl.mapping for name, vl in self._value_labels.items()
            },
        }

    @classmethod
    def from_dict(cls, d: dict) -> "StataData":
        """Create StataData from dictionary."""
        data = cls(pd.DataFrame(d.get("data", {})))
        data._var_labels = d.get("var_labels", {})
        data._var_formats = d.get("var_formats", {})
        data._var_value_labels = d.get("var_value_labels", {})
        for name, mapping in d.get("value_labels", {}).items():
            vl = data.define_value_label(name)
            for v, l in mapping.items():
                vl.define(int(v), l)
        return data

    # =========================================================================
    # Display
    # =========================================================================

    def describe(self) -> str:
        """Return Stata-style describe output."""
        lines = []
        lines.append(f"Contains data")
        lines.append(f"  obs:        {self.N:>10,}")
        lines.append(f"  vars:       {len(self.varlist):>10}")
        lines.append("")
        lines.append(
            f"{'variable':<20} {'type':<10} {'format':<12} {'label'}"
        )
        lines.append("-" * 70)

        for var in self.varlist:
            vtype = self.get_var_type(var)
            vfmt = self.get_var_format(var)
            vlabel = self.get_var_label(var)
            lines.append(f"{var:<20} {vtype:<10} {vfmt:<12} {vlabel}")

        return "\n".join(lines)

    def list_obs(
        self,
        vars: Optional[list[str]] = None,
        obs_range: Optional[tuple[int, int]] = None,
    ) -> str:
        """Return Stata-style list output."""
        df = self._df
        if vars:
            df = df[[v for v in vars if v in df.columns]]
        if obs_range:
            start, end = obs_range
            df = df.iloc[start - 1 : end]

        return df.to_string()

    def __repr__(self) -> str:
        return f"StataData(obs={self.N}, vars={len(self.varlist)})"
