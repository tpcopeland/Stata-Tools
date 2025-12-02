# tvmerge: Python Reimplementation Plan

## Overview

**Purpose**: Merge multiple time-varying exposure datasets by creating a Cartesian product of overlapping time periods.

**Core Concept**: Unlike standard merges that match on keys, tvmerge performs interval-based merging. For each person, it finds all temporal overlaps between datasets and creates new time intervals representing the intersections of exposure periods.

**Key Use Case**: Combine multiple exposure datasets (e.g., HRT and DMT) where each dataset has time-varying exposures, creating a single dataset with all exposure combinations during overlapping periods.

---

## High-Level Architecture

### Module Structure

```
tvmerge/
├── __init__.py              # Package initialization, expose main classes
├── merger.py                # Main TVMerge class
├── validators.py            # Input validation functions
├── cartesian.py             # Cartesian merge algorithm
├── diagnostics.py           # Coverage and overlap validation
├── exceptions.py            # Custom exception classes
├── types.py                 # Type definitions and protocols
└── utils.py                 # Utility functions
```

### Dependencies

**Required**:
- `pandas >= 1.5.0` - DataFrame operations
- `numpy >= 1.23.0` - Numerical operations
- `typing` - Type hints (built-in)

**Optional**:
- `joblib >= 1.2.0` - Parallel processing
- `tqdm >= 4.64.0` - Progress bars

---

## Class Design

### Main Class: TVMerge

```python
from typing import Union, List, Optional, Dict, Any, Tuple
from pathlib import Path
import pandas as pd
import numpy as np
from dataclasses import dataclass, field

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
    invalid_periods: Dict[str, int] = field(default_factory=dict)
    n_duplicates_dropped: int = 0

class TVMerge:
    """
    Merge multiple time-varying exposure datasets.

    This class implements a Cartesian merge algorithm that creates all possible
    combinations of overlapping time periods across multiple datasets. Unlike
    standard merges, this operates on time intervals rather than exact key matches.

    The merge algorithm:
    1. Loads and validates each dataset
    2. Iteratively merges datasets by finding interval intersections
    3. For continuous exposures, prorates values based on overlap duration
    4. Validates coverage and overlaps if requested

    Parameters
    ----------
    datasets : List[Union[str, Path, pd.DataFrame]]
        List of datasets to merge. Can be file paths (str/Path) or DataFrames.
        Minimum 2 datasets required.

    id_col : str
        Name of person identifier column present in all datasets.

    start_cols : List[str]
        List of start date column names, one per dataset in order.

    stop_cols : List[str]
        List of stop date column names, one per dataset in order.

    exposure_cols : List[str]
        List of exposure column names, one per dataset in order.

    continuous : Optional[List[Union[str, int]]]
        List of exposure names or positions (1-indexed) that are continuous.
        Continuous exposures are treated as rates per day and prorated.
        Default: None (all exposures treated as categorical).

    output_names : Optional[List[str]]
        New names for exposure columns in output. Must match number of datasets.
        Mutually exclusive with prefix. Default: None.

    prefix : Optional[str]
        Prefix to add to all exposure column names.
        Mutually exclusive with output_names. Default: None.

    start_name : str
        Name for output start date column. Default: "start".

    stop_name : str
        Name for output stop date column. Default: "stop".

    keep_cols : Optional[List[str]]
        Additional columns to keep from source datasets.
        Will be suffixed with _ds{n} where n is dataset number.
        Default: None.

    batch_pct : int
        Percentage of IDs to process per batch (1-100).
        Larger batches are faster but use more memory.
        Default: 20.

    n_jobs : int
        Number of parallel jobs. -1 uses all cores.
        Default: 1 (no parallelization).

    validate_coverage : bool
        Check for gaps in person-time coverage. Default: False.

    validate_overlap : bool
        Check for unexpected overlapping periods. Default: False.

    check_diagnostics : bool
        Display coverage diagnostics. Default: False.

    summarize : bool
        Display summary statistics of start/stop dates. Default: False.

    strict_ids : bool
        If True, error on ID mismatches between datasets.
        If False, warn and continue (drop mismatched IDs).
        Default: True.

    Attributes
    ----------
    metadata : MergeMetadata
        Metadata about the merge operation, populated after merge().

    Examples
    --------
    Basic two-dataset merge:

    >>> merger = TVMerge(
    ...     datasets=['tv_hrt.csv', 'tv_dmt.csv'],
    ...     id_col='id',
    ...     start_cols=['rx_start', 'dmt_start'],
    ...     stop_cols=['rx_stop', 'dmt_stop'],
    ...     exposure_cols=['tv_exposure', 'tv_exposure'],
    ...     output_names=['hrt', 'dmt']
    ... )
    >>> result = merger.merge()
    >>> print(result.head())

    Merge with continuous exposure:

    >>> merger = TVMerge(
    ...     datasets=['tv_hrt.csv', 'tv_dose.csv'],
    ...     id_col='id',
    ...     start_cols=['rx_start', 'dose_start'],
    ...     stop_cols=['rx_stop', 'dose_stop'],
    ...     exposure_cols=['hrt_type', 'dosage'],
    ...     continuous=['dosage'],  # Or continuous=[2]
    ...     output_names=['hrt', 'dose']
    ... )
    >>> result = merger.merge()
    >>> # Result has columns: id, start, stop, hrt, dose, dose_period

    Batch processing for large datasets:

    >>> merger = TVMerge(
    ...     datasets=[df1, df2, df3],
    ...     id_col='person_id',
    ...     start_cols=['start', 'start', 'start'],
    ...     stop_cols=['stop', 'stop', 'stop'],
    ...     exposure_cols=['exp1', 'exp2', 'exp3'],
    ...     batch_pct=50,  # Process 50% of IDs per batch
    ...     n_jobs=-1      # Use all CPU cores
    ... )
    >>> result = merger.merge()
    """

    def __init__(
        self,
        datasets: List[Union[str, Path, pd.DataFrame]],
        id_col: str,
        start_cols: List[str],
        stop_cols: List[str],
        exposure_cols: List[str],
        continuous: Optional[List[Union[str, int]]] = None,
        output_names: Optional[List[str]] = None,
        prefix: Optional[str] = None,
        start_name: str = "start",
        stop_name: str = "stop",
        keep_cols: Optional[List[str]] = None,
        batch_pct: int = 20,
        n_jobs: int = 1,
        validate_coverage: bool = False,
        validate_overlap: bool = False,
        check_diagnostics: bool = False,
        summarize: bool = False,
        strict_ids: bool = True,
    ):
        # Store parameters
        self.datasets = datasets
        self.id_col = id_col
        self.start_cols = start_cols
        self.stop_cols = stop_cols
        self.exposure_cols = exposure_cols
        self.continuous = continuous or []
        self.output_names = output_names
        self.prefix = prefix
        self.start_name = start_name
        self.stop_name = stop_name
        self.keep_cols = keep_cols or []
        self.batch_pct = batch_pct
        self.n_jobs = n_jobs
        self.validate_coverage = validate_coverage
        self.validate_overlap = validate_overlap
        self.check_diagnostics = check_diagnostics
        self.summarize = summarize
        self.strict_ids = strict_ids

        # Initialize metadata
        self.metadata: Optional[MergeMetadata] = None

        # Validate inputs
        self._validate_inputs()

    def _validate_inputs(self) -> None:
        """
        Validate all input parameters.

        Raises
        ------
        ValueError
            If any input validation fails.
        TypeError
            If any input has wrong type.
        """
        # Import here to avoid circular imports
        from .validators import (
            validate_dataset_count,
            validate_column_counts,
            validate_naming_options,
            validate_batch_pct,
            validate_id_column,
        )

        validate_dataset_count(self.datasets)
        validate_column_counts(
            len(self.datasets),
            self.start_cols,
            self.stop_cols,
            self.exposure_cols
        )
        validate_naming_options(
            self.output_names,
            self.prefix,
            len(self.datasets)
        )
        validate_batch_pct(self.batch_pct)
        # validate_id_column will be called per dataset during load

    def merge(self) -> pd.DataFrame:
        """
        Perform the Cartesian merge of all datasets.

        Returns
        -------
        pd.DataFrame
            Merged dataset with the following structure:
            - id column (person identifier)
            - start column (period start date)
            - stop column (period stop date)
            - exposure columns (one per dataset, renamed as specified)
            - For continuous exposures: exp_name (rate) and exp_name_period (amount)
            - keep columns (suffixed with _ds{n})

            The DataFrame also has a .metadata attribute containing MergeMetadata.

        Raises
        ------
        IDMismatchError
            If IDs don't match across datasets and strict_ids=True.
        InvalidPeriodError
            If datasets contain invalid periods (start > stop).
        """
        from .cartesian import cartesian_merge_batch
        from .diagnostics import check_coverage, check_overlaps, summarize_dates

        print(f"Loading and preparing {len(self.datasets)} datasets...")

        # Step 1: Load and prepare all datasets
        prepared_datasets = []
        invalid_periods = {}

        for i, (dataset, start_col, stop_col, exp_col) in enumerate(
            zip(self.datasets, self.start_cols, self.stop_cols, self.exposure_cols),
            start=1
        ):
            df = self._load_and_prepare_dataset(
                dataset, i, start_col, stop_col, exp_col
            )

            # Count and remove invalid periods
            n_invalid = ((df[self.start_name] > df[self.stop_name]) |
                        df[self.start_name].isna() |
                        df[self.stop_name].isna()).sum()

            if n_invalid > 0:
                invalid_periods[f"dataset_{i}"] = n_invalid
                print(f"  Warning: Dropping {n_invalid} invalid periods from dataset {i}")
                df = df[
                    (df[self.start_name] <= df[self.stop_name]) &
                    df[self.start_name].notna() &
                    df[self.stop_name].notna()
                ]

            prepared_datasets.append(df)

        # Step 2: Validate ID matching
        self._validate_id_matching(prepared_datasets)

        # Step 3: Determine continuous exposure positions
        continuous_flags = self._resolve_continuous_flags()

        # Step 4: Perform iterative Cartesian merge
        print(f"Performing Cartesian merge...")
        result = prepared_datasets[0].copy()

        for i in range(1, len(prepared_datasets)):
            print(f"  Merging dataset {i+1}/{len(prepared_datasets)}...")

            result = cartesian_merge_batch(
                left=result,
                right=prepared_datasets[i],
                id_col=self.id_col,
                start_name=self.start_name,
                stop_name=self.stop_name,
                right_exposure_cols=self._get_exposure_cols_for_dataset(i),
                continuous_flags=self._get_continuous_flags_for_dataset(i, continuous_flags),
                batch_pct=self.batch_pct,
                n_jobs=self.n_jobs,
            )

        # Step 5: Remove exact duplicates
        dup_cols = [self.id_col, self.start_name, self.stop_name] + self._get_all_final_exposure_cols()
        n_before = len(result)
        result = result.drop_duplicates(subset=dup_cols, keep='first')
        n_duplicates = n_before - len(result)

        if n_duplicates > 0:
            print(f"Dropped {n_duplicates} duplicate interval+exposure combinations")

        # Step 6: Sort final dataset
        result = result.sort_values([self.id_col, self.start_name, self.stop_name]).reset_index(drop=True)

        # Step 7: Calculate metadata
        self.metadata = self._calculate_metadata(
            result, invalid_periods, n_duplicates, continuous_flags
        )

        # Step 8: Run diagnostics if requested
        if self.check_diagnostics:
            self._display_diagnostics()

        if self.validate_coverage:
            coverage_issues = check_coverage(result, self.id_col, self.start_name, self.stop_name)
            self._display_coverage_issues(coverage_issues)

        if self.validate_overlap:
            overlap_issues = check_overlaps(
                result, self.id_col, self.start_name, self.stop_name,
                self._get_all_final_exposure_cols()
            )
            self._display_overlap_issues(overlap_issues)

        if self.summarize:
            summarize_dates(result, self.start_name, self.stop_name)

        # Step 9: Attach metadata to result
        result.attrs['tvmerge_metadata'] = self.metadata

        print(f"\n{'='*50}")
        print(f"Merged time-varying dataset successfully created")
        print(f"{'='*50}")
        print(f"  Observations: {len(result):,}")
        print(f"  Persons: {self.metadata.n_persons:,}")
        print(f"  Exposure variables: {', '.join(self.metadata.exposure_vars)}")
        print(f"{'='*50}\n")

        return result

    def _load_and_prepare_dataset(
        self,
        dataset: Union[str, Path, pd.DataFrame],
        dataset_num: int,
        start_col: str,
        stop_col: str,
        exp_col: str,
    ) -> pd.DataFrame:
        """
        Load and prepare a single dataset.

        Steps:
        1. Load from file or use DataFrame
        2. Validate required columns exist
        3. Rename columns to standard names
        4. Floor start dates, ceil stop dates
        5. Apply output naming (generate/prefix)
        6. Handle keep() columns with _ds{n} suffix
        7. Keep only required columns

        Parameters
        ----------
        dataset : Union[str, Path, pd.DataFrame]
            Dataset to load.
        dataset_num : int
            Dataset number (1-indexed).
        start_col : str
            Name of start column in this dataset.
        stop_col : str
            Name of stop column in this dataset.
        exp_col : str
            Name of exposure column in this dataset.

        Returns
        -------
        pd.DataFrame
            Prepared dataset with standardized column names.
        """
        # Load dataset
        if isinstance(dataset, pd.DataFrame):
            df = dataset.copy()
            dataset_name = f"dataset_{dataset_num}"
        else:
            df = pd.read_csv(dataset)  # Could extend to support .dta, .xlsx, etc.
            dataset_name = str(Path(dataset).stem)

        # Validate required columns
        from .validators import validate_required_columns
        validate_required_columns(df, [self.id_col, start_col, stop_col, exp_col], dataset_name)

        # Rename ID column if needed
        if self.id_col != 'id':
            df = df.rename(columns={self.id_col: 'id'})

        # Floor start, ceil stop (handle fractional dates)
        df[start_col] = np.floor(df[start_col].astype(float))
        df[stop_col] = np.ceil(df[stop_col].astype(float))

        # Rename date columns to standard names
        if dataset_num == 1:
            # First dataset uses final names directly
            df = df.rename(columns={
                start_col: self.start_name,
                stop_col: self.stop_name,
            })
        else:
            # Subsequent datasets use temporary names (will be merged)
            df = df.rename(columns={
                start_col: f'{self.start_name}_new',
                stop_col: f'{self.stop_name}_new',
            })

        # Determine output name for exposure
        if self.output_names:
            output_exp_name = self.output_names[dataset_num - 1]
        elif self.prefix:
            output_exp_name = f"{self.prefix}{exp_col}"
        else:
            output_exp_name = exp_col

        # Rename exposure column
        df = df.rename(columns={exp_col: output_exp_name})

        # Handle keep() columns
        keep_cols_to_include = []
        for col in self.keep_cols:
            if col in df.columns:
                new_name = f"{col}_ds{dataset_num}"
                df = df.rename(columns={col: new_name})
                keep_cols_to_include.append(new_name)

        # Select only required columns
        if dataset_num == 1:
            cols_to_keep = ['id', self.start_name, self.stop_name, output_exp_name] + keep_cols_to_include
        else:
            cols_to_keep = ['id', f'{self.start_name}_new', f'{self.stop_name}_new', output_exp_name] + keep_cols_to_include

        df = df[cols_to_keep]

        return df

    def _validate_id_matching(self, datasets: List[pd.DataFrame]) -> None:
        """
        Validate that IDs match across all datasets.

        Parameters
        ----------
        datasets : List[pd.DataFrame]
            List of prepared datasets.

        Raises
        ------
        IDMismatchError
            If IDs don't match and strict_ids=True.
        """
        from .exceptions import IDMismatchError

        # Get unique IDs from each dataset
        id_sets = [set(df['id'].unique()) for df in datasets]

        # Check for mismatches
        all_ids = set.union(*id_sets)
        common_ids = set.intersection(*id_sets)

        if len(common_ids) < len(all_ids):
            # Found mismatches
            for i, id_set in enumerate(id_sets, start=1):
                only_in_this = id_set - common_ids
                missing_from_this = common_ids - id_set

                if only_in_this or missing_from_this:
                    msg = f"\nID mismatch detected in dataset {i}:\n"
                    if only_in_this:
                        msg += f"  {len(only_in_this)} IDs only in dataset {i}\n"
                    if missing_from_this:
                        msg += f"  {len(missing_from_this)} IDs missing from dataset {i}\n"

                    if self.strict_ids:
                        raise IDMismatchError(
                            f"{msg}\nUse strict_ids=False to proceed anyway "
                            "(mismatched IDs will be dropped)."
                        )
                    else:
                        print(f"Warning: {msg}")

            if not self.strict_ids:
                print(f"Proceeding with {len(common_ids)} common IDs (dropped {len(all_ids) - len(common_ids)} mismatched IDs)")

    def _resolve_continuous_flags(self) -> Dict[str, bool]:
        """
        Resolve continuous exposure specification to boolean flags.

        The continuous parameter can contain:
        - Exposure variable names (original or output names)
        - 1-indexed positions (1, 2, 3, ...)

        Returns
        -------
        Dict[str, bool]
            Mapping from final exposure name to continuous flag.
        """
        continuous_flags = {}

        # Get final exposure names
        final_names = self._get_all_final_exposure_cols()

        # Initialize all as False
        for name in final_names:
            continuous_flags[name] = False

        # Process continuous specification
        for item in self.continuous:
            if isinstance(item, int):
                # Position (1-indexed)
                if 1 <= item <= len(final_names):
                    continuous_flags[final_names[item - 1]] = True
                else:
                    raise ValueError(f"continuous() position {item} out of range (1-{len(final_names)})")
            else:
                # Name
                if item in final_names:
                    continuous_flags[item] = True
                elif item in self.exposure_cols:
                    # Original name - find corresponding final name
                    idx = self.exposure_cols.index(item)
                    continuous_flags[final_names[idx]] = True
                else:
                    raise ValueError(f"continuous() exposure '{item}' not found in exposure list")

        return continuous_flags

    def _get_all_final_exposure_cols(self) -> List[str]:
        """Get list of all final exposure column names."""
        if self.output_names:
            return self.output_names
        elif self.prefix:
            return [f"{self.prefix}{col}" for col in self.exposure_cols]
        else:
            return self.exposure_cols

    def _get_exposure_cols_for_dataset(self, dataset_idx: int) -> List[str]:
        """Get exposure column names for a specific dataset (0-indexed)."""
        final_names = self._get_all_final_exposure_cols()
        return [final_names[dataset_idx]]

    def _get_continuous_flags_for_dataset(
        self, dataset_idx: int, continuous_flags: Dict[str, bool]
    ) -> Dict[str, bool]:
        """Get continuous flags for a specific dataset (0-indexed)."""
        final_names = self._get_all_final_exposure_cols()
        col_name = final_names[dataset_idx]
        return {col_name: continuous_flags[col_name]}

    def _calculate_metadata(
        self,
        result: pd.DataFrame,
        invalid_periods: Dict[str, int],
        n_duplicates: int,
        continuous_flags: Dict[str, bool],
    ) -> MergeMetadata:
        """Calculate merge metadata."""
        n_persons = result['id'].nunique()
        periods_per_person = result.groupby('id').size()

        final_exp_names = self._get_all_final_exposure_cols()
        continuous_vars = [name for name, is_cont in continuous_flags.items() if is_cont]
        categorical_vars = [name for name, is_cont in continuous_flags.items() if not is_cont]

        # Get dataset names
        dataset_names = []
        for ds in self.datasets:
            if isinstance(ds, pd.DataFrame):
                dataset_names.append("<DataFrame>")
            else:
                dataset_names.append(str(ds))

        return MergeMetadata(
            n_observations=len(result),
            n_persons=n_persons,
            mean_periods=periods_per_person.mean(),
            max_periods=periods_per_person.max(),
            n_datasets=len(self.datasets),
            n_continuous=len(continuous_vars),
            n_categorical=len(categorical_vars),
            exposure_vars=final_exp_names,
            continuous_vars=continuous_vars,
            categorical_vars=categorical_vars,
            start_name=self.start_name,
            stop_name=self.stop_name,
            datasets=dataset_names,
            invalid_periods=invalid_periods,
            n_duplicates_dropped=n_duplicates,
        )

    def _display_diagnostics(self) -> None:
        """Display coverage diagnostics."""
        print(f"\n{'='*50}")
        print("Coverage Diagnostics:")
        print(f"  Number of persons: {self.metadata.n_persons:,}")
        print(f"  Average periods per person: {self.metadata.mean_periods:.2f}")
        print(f"  Max periods per person: {self.metadata.max_periods}")
        print(f"  Total merged intervals: {self.metadata.n_observations:,}")
        print(f"{'='*50}\n")

    def _display_coverage_issues(self, issues: pd.DataFrame) -> None:
        """Display coverage validation results."""
        print(f"\n{'='*50}")
        print("Validating coverage...")
        if len(issues) > 0:
            print(f"Found {len(issues)} gaps in coverage (>1 day gaps)")
            print(issues.to_string(index=False))
        else:
            print("No gaps >1 day found in coverage.")
        print(f"{'='*50}\n")

    def _display_overlap_issues(self, issues: pd.DataFrame) -> None:
        """Display overlap validation results."""
        print(f"\n{'='*50}")
        print("Validating overlaps...")
        if len(issues) > 0:
            print(f"Found {len(issues)} unexpected overlapping periods")
            print(issues.to_string(index=False))
        else:
            print("No unexpected overlaps found.")
        print(f"{'='*50}\n")

    def save(self, filepath: Union[str, Path], **kwargs) -> None:
        """
        Save merged dataset to file.

        Parameters
        ----------
        filepath : Union[str, Path]
            Output file path. Format determined by extension.
            Supported: .csv, .parquet, .dta (requires pyreadstat), .xlsx
        **kwargs
            Additional arguments passed to pandas save function.
        """
        filepath = Path(filepath)

        if filepath.suffix == '.csv':
            self.result.to_csv(filepath, index=False, **kwargs)
        elif filepath.suffix == '.parquet':
            self.result.to_parquet(filepath, index=False, **kwargs)
        elif filepath.suffix == '.dta':
            try:
                self.result.to_stata(filepath, **kwargs)
            except AttributeError:
                raise ImportError("Saving to .dta requires pyreadstat package")
        elif filepath.suffix == '.xlsx':
            self.result.to_excel(filepath, index=False, **kwargs)
        else:
            raise ValueError(f"Unsupported file format: {filepath.suffix}")
```

---

## Supporting Modules

### validators.py

```python
"""Input validation functions."""

from typing import List, Optional, Union
from pathlib import Path
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
```

### cartesian.py

```python
"""Cartesian merge algorithm implementation."""

from typing import Dict, List, Optional
import pandas as pd
import numpy as np

def cartesian_merge_batch(
    left: pd.DataFrame,
    right: pd.DataFrame,
    id_col: str,
    start_name: str,
    stop_name: str,
    right_exposure_cols: List[str],
    continuous_flags: Dict[str, bool],
    batch_pct: int = 20,
    n_jobs: int = 1,
) -> pd.DataFrame:
    """
    Perform Cartesian merge of two datasets with batch processing.

    Algorithm:
    1. Split IDs into batches
    2. For each batch:
       a. Cross join on ID (Cartesian product within person)
       b. Calculate interval intersection (max start, min stop)
       c. Keep valid intersections (start <= stop)
       d. For continuous exposures, prorate based on overlap
    3. Concatenate batch results

    Parameters
    ----------
    left : pd.DataFrame
        Left dataset (result of previous merges).
    right : pd.DataFrame
        Right dataset to merge.
    id_col : str
        ID column name (should be 'id' in both).
    start_name : str
        Start column name in left.
    stop_name : str
        Stop column name in left.
    right_exposure_cols : List[str]
        Exposure columns from right dataset.
    continuous_flags : Dict[str, bool]
        Mapping of exposure names to continuous flags.
    batch_pct : int
        Percentage of IDs per batch.
    n_jobs : int
        Number of parallel jobs.

    Returns
    -------
    pd.DataFrame
        Merged dataset with interval intersections.
    """
    # Get unique IDs
    unique_ids = left[id_col].unique()
    n_ids = len(unique_ids)

    # Calculate batch parameters
    batch_size = max(1, int(np.ceil(n_ids * (batch_pct / 100))))
    n_batches = int(np.ceil(n_ids / batch_size))

    print(f"    Processing {n_ids:,} unique IDs in {n_batches} batches "
          f"(batch size: {batch_size} IDs = {batch_pct}%)...")

    # Split IDs into batches
    id_batches = [
        unique_ids[i * batch_size:(i + 1) * batch_size]
        for i in range(n_batches)
    ]

    # Process batches
    if n_jobs == 1:
        # Sequential processing
        results = []
        for i, batch_ids in enumerate(id_batches, start=1):
            print(f"      Batch {i}/{n_batches}...")
            batch_result = _process_batch(
                left, right, batch_ids, id_col,
                start_name, stop_name, right_exposure_cols, continuous_flags
            )
            if len(batch_result) > 0:
                results.append(batch_result)
            else:
                print(f"        (batch {i} produced no valid intersections)")

        if not results:
            # No valid intersections - return empty with correct structure
            return _create_empty_result(left, right, right_exposure_cols, continuous_flags)

        return pd.concat(results, ignore_index=True)
    else:
        # Parallel processing with joblib
        from joblib import Parallel, delayed

        results = Parallel(n_jobs=n_jobs)(
            delayed(_process_batch)(
                left, right, batch_ids, id_col,
                start_name, stop_name, right_exposure_cols, continuous_flags
            )
            for batch_ids in id_batches
        )

        # Filter empty results
        results = [r for r in results if len(r) > 0]

        if not results:
            return _create_empty_result(left, right, right_exposure_cols, continuous_flags)

        return pd.concat(results, ignore_index=True)

def _process_batch(
    left: pd.DataFrame,
    right: pd.DataFrame,
    batch_ids: np.ndarray,
    id_col: str,
    start_name: str,
    stop_name: str,
    right_exposure_cols: List[str],
    continuous_flags: Dict[str, bool],
) -> pd.DataFrame:
    """Process a single batch of IDs."""
    # Filter to batch IDs
    left_batch = left[left[id_col].isin(batch_ids)].copy()
    right_batch = right[right[id_col].isin(batch_ids)].copy()

    # Rename right columns temporarily
    right_batch = right_batch.rename(columns={
        f'{start_name}_new': 'start_right',
        f'{stop_name}_new': 'stop_right',
    })

    # Perform cross join (Cartesian product within each ID)
    merged = left_batch.merge(right_batch, on=id_col, how='inner')

    # Calculate intersection
    merged['new_start'] = merged[[start_name, 'start_right']].max(axis=1)
    merged['new_stop'] = merged[[stop_name, 'stop_right']].min(axis=1)

    # Keep only valid intersections
    merged = merged[
        (merged['new_start'] <= merged['new_stop']) &
        merged['new_start'].notna() &
        merged['new_stop'].notna()
    ].copy()

    if len(merged) == 0:
        return pd.DataFrame()

    # For continuous exposures, prorate values
    for exp_col in right_exposure_cols:
        if continuous_flags.get(exp_col, False):
            # Calculate proportion: (overlap_days) / (original_days)
            overlap_days = merged['new_stop'] - merged['new_start'] + 1
            original_days = merged['stop_right'] - merged['start_right'] + 1

            # Avoid division by zero
            proportion = np.where(
                original_days > 0,
                overlap_days / original_days,
                1.0
            )

            # Ensure proportion doesn't exceed 1 (floating point rounding)
            proportion = np.minimum(proportion, 1.0)

            # Create period column
            merged[f'{exp_col}_period'] = merged[exp_col] * proportion

            # Update exposure to be the rate (already is, but make explicit)
            # merged[exp_col] remains unchanged

    # Replace old intervals with intersections
    merged[start_name] = merged['new_start']
    merged[stop_name] = merged['new_stop']

    # Drop temporary columns
    merged = merged.drop(columns=['new_start', 'new_stop', 'start_right', 'stop_right'])

    return merged

def _create_empty_result(
    left: pd.DataFrame,
    right: pd.DataFrame,
    right_exposure_cols: List[str],
    continuous_flags: Dict[str, bool],
) -> pd.DataFrame:
    """Create empty DataFrame with correct structure."""
    # Get all columns from left
    result_cols = list(left.columns)

    # Add exposure columns from right
    for exp_col in right_exposure_cols:
        result_cols.append(exp_col)
        if continuous_flags.get(exp_col, False):
            result_cols.append(f'{exp_col}_period')

    # Create empty DataFrame with correct dtypes
    return pd.DataFrame(columns=result_cols)
```

### diagnostics.py

```python
"""Diagnostic and validation functions."""

import pandas as pd
import numpy as np
from typing import List

def check_coverage(
    df: pd.DataFrame,
    id_col: str,
    start_col: str,
    stop_col: str,
    gap_threshold: int = 1,
) -> pd.DataFrame:
    """
    Check for gaps in person-time coverage.

    Parameters
    ----------
    df : pd.DataFrame
        Merged dataset.
    id_col : str
        ID column name.
    start_col : str
        Start date column name.
    stop_col : str
        Stop date column name.
    gap_threshold : int
        Gap size threshold in days. Default: 1.

    Returns
    -------
    pd.DataFrame
        DataFrame of coverage gaps with columns:
        [id_col, start_col, stop_col, 'gap_days']
    """
    # Sort by ID and start
    df = df.sort_values([id_col, start_col, stop_col]).copy()

    # Calculate gap to next period within each person
    df['_next_start'] = df.groupby(id_col)[start_col].shift(-1)
    df['_gap'] = df['_next_start'] - df[stop_col] - 1

    # Find gaps exceeding threshold
    gaps = df[df['_gap'] > gap_threshold].copy()

    if len(gaps) > 0:
        gaps = gaps[[id_col, start_col, stop_col, '_gap']].rename(
            columns={'_gap': 'gap_days'}
        )
        return gaps

    return pd.DataFrame(columns=[id_col, start_col, stop_col, 'gap_days'])

def check_overlaps(
    df: pd.DataFrame,
    id_col: str,
    start_col: str,
    stop_col: str,
    exposure_cols: List[str],
) -> pd.DataFrame:
    """
    Check for unexpected overlapping periods.

    Overlaps are expected when exposure values differ (Cartesian product).
    This function identifies overlaps where exposure values are IDENTICAL
    (likely data errors).

    Parameters
    ----------
    df : pd.DataFrame
        Merged dataset.
    id_col : str
        ID column name.
    start_col : str
        Start date column name.
    stop_col : str
        Stop date column name.
    exposure_cols : List[str]
        List of exposure column names.

    Returns
    -------
    pd.DataFrame
        DataFrame of unexpected overlaps with columns:
        [id_col, start_col, stop_col]
    """
    # Sort by ID and start
    df = df.sort_values([id_col, start_col, stop_col]).copy()

    # Check if period starts before previous period ends
    df['_prev_stop'] = df.groupby(id_col)[stop_col].shift(1)
    df['_overlap'] = df[start_col] < df['_prev_stop']

    # For overlaps, check if exposures are identical
    df['_same_exposures'] = False

    overlapping = df[df['_overlap']].copy()
    if len(overlapping) > 0:
        for exp_col in exposure_cols:
            if exp_col in df.columns:
                prev_exp = df.groupby(id_col)[exp_col].shift(1)
                df['_same_exposures'] |= (df[exp_col] == prev_exp)

    # Keep only overlaps with identical exposures
    unexpected = df[df['_overlap'] & df['_same_exposures']].copy()

    if len(unexpected) > 0:
        return unexpected[[id_col, start_col, stop_col]]

    return pd.DataFrame(columns=[id_col, start_col, stop_col])

def summarize_dates(
    df: pd.DataFrame,
    start_col: str,
    stop_col: str,
) -> None:
    """
    Display summary statistics for start and stop dates.

    Parameters
    ----------
    df : pd.DataFrame
        Merged dataset.
    start_col : str
        Start date column name.
    stop_col : str
        Stop date column name.
    """
    print(f"\n{'='*50}")
    print("Summary Statistics:")
    print(f"\n{start_col}:")
    print(df[start_col].describe())
    print(f"\n{stop_col}:")
    print(df[stop_col].describe())
    print(f"{'='*50}\n")
```

### exceptions.py

```python
"""Custom exception classes."""

class TVMergeError(Exception):
    """Base exception for tvmerge errors."""
    pass

class IDMismatchError(TVMergeError):
    """Raised when IDs don't match across datasets."""
    pass

class InvalidPeriodError(TVMergeError):
    """Raised when datasets contain invalid periods (start > stop)."""
    pass

class ColumnNotFoundError(TVMergeError):
    """Raised when required column is not found in dataset."""
    pass
```

### types.py

```python
"""Type definitions and protocols."""

from typing import Protocol, Union, List
from pathlib import Path
import pandas as pd

# Type alias for dataset input
DatasetInput = Union[str, Path, pd.DataFrame]

class MergeableDataset(Protocol):
    """Protocol for datasets that can be merged."""

    def __getitem__(self, key):
        """Support column access."""
        ...

    @property
    def columns(self) -> List[str]:
        """Return column names."""
        ...
```

### utils.py

```python
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
```

---

## Testing Strategy

### Test Structure

```
tests/
├── __init__.py
├── conftest.py                    # pytest fixtures
├── test_basic_merge.py           # Basic two-dataset merge
├── test_continuous.py            # Continuous exposures
├── test_validation.py            # Input validation
├── test_batch_processing.py      # Batch processing
├── test_edge_cases.py            # Edge cases
├── test_diagnostics.py           # Coverage/overlap validation
└── test_integration.py           # End-to-end workflows
```

### Key Test Cases

#### test_basic_merge.py

```python
import pytest
import pandas as pd
import numpy as np
from tvmerge import TVMerge

def test_two_dataset_merge():
    """Test basic two-dataset merge."""
    # Create test data
    df1 = pd.DataFrame({
        'id': [1, 1, 2, 2],
        'start': [0, 10, 0, 15],
        'stop': [9, 19, 14, 29],
        'exp1': ['A', 'B', 'A', 'B'],
    })

    df2 = pd.DataFrame({
        'id': [1, 1, 2, 2],
        'start': [0, 5, 0, 10],
        'stop': [4, 19, 9, 29],
        'exp2': [1, 2, 1, 2],
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp1', 'exp2'],
    )

    result = merger.merge()

    # Assertions
    assert len(result) == 8  # 4 combinations per person * 2 persons
    assert set(result.columns) == {'id', 'start', 'stop', 'exp1', 'exp2'}
    assert result['id'].nunique() == 2

    # Check specific intersection
    person1_a1 = result[(result['id'] == 1) & (result['exp1'] == 'A') & (result['exp2'] == 1)]
    assert len(person1_a1) == 1
    assert person1_a1.iloc[0]['start'] == 0
    assert person1_a1.iloc[0]['stop'] == 4

def test_output_naming():
    """Test custom output names."""
    df1 = pd.DataFrame({
        'id': [1],
        'start': [0],
        'stop': [10],
        'exp': ['A'],
    })

    df2 = pd.DataFrame({
        'id': [1],
        'start': [0],
        'stop': [10],
        'exp': [1],
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp', 'exp'],
        output_names=['treatment', 'dose'],
    )

    result = merger.merge()

    assert 'treatment' in result.columns
    assert 'dose' in result.columns
    assert 'exp' not in result.columns

def test_prefix_naming():
    """Test prefix naming."""
    df1 = pd.DataFrame({
        'id': [1],
        'start': [0],
        'stop': [10],
        'exp1': ['A'],
    })

    df2 = pd.DataFrame({
        'id': [1],
        'start': [0],
        'stop': [10],
        'exp2': [1],
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp1', 'exp2'],
        prefix='var_',
    )

    result = merger.merge()

    assert 'var_exp1' in result.columns
    assert 'var_exp2' in result.columns
```

#### test_continuous.py

```python
def test_continuous_exposure():
    """Test continuous exposure prorating."""
    df1 = pd.DataFrame({
        'id': [1],
        'start': [0],
        'stop': [10],  # 11 days
        'exp1': ['A'],
    })

    df2 = pd.DataFrame({
        'id': [1],
        'start': [0],
        'stop': [10],  # 11 days
        'dose': [100.0],  # 100 per day
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp1', 'dose'],
        continuous=['dose'],
    )

    result = merger.merge()

    # Should have dose (rate) and dose_period (amount)
    assert 'dose' in result.columns
    assert 'dose_period' in result.columns

    # Full overlap: dose_period should equal dose * days
    assert result['dose'].iloc[0] == 100.0
    assert result['dose_period'].iloc[0] == 100.0 * 1.0  # proportion = 1

def test_continuous_partial_overlap():
    """Test continuous exposure with partial overlap."""
    df1 = pd.DataFrame({
        'id': [1],
        'start': [0],
        'stop': [10],  # 11 days
        'exp1': ['A'],
    })

    df2 = pd.DataFrame({
        'id': [1],
        'start': [0],
        'stop': [4],  # 5 days
        'dose': [100.0],  # 100 per day
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp1', 'dose'],
        continuous=['dose'],
    )

    result = merger.merge()

    # Intersection is 0-4 (5 days)
    assert result['start'].iloc[0] == 0
    assert result['stop'].iloc[0] == 4

    # Proportion should be 5/5 = 1.0
    expected_period = 100.0 * 1.0
    assert np.isclose(result['dose_period'].iloc[0], expected_period)
```

#### test_validation.py

```python
def test_insufficient_datasets():
    """Test error on < 2 datasets."""
    with pytest.raises(ValueError, match="at least 2 datasets"):
        TVMerge(
            datasets=[pd.DataFrame()],
            id_col='id',
            start_cols=['start'],
            stop_cols=['stop'],
            exposure_cols=['exp'],
        )

def test_column_count_mismatch():
    """Test error on column count mismatch."""
    with pytest.raises(ValueError, match="must equal number of datasets"):
        TVMerge(
            datasets=[pd.DataFrame(), pd.DataFrame()],
            id_col='id',
            start_cols=['start'],  # Only 1, need 2
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
        )

def test_conflicting_naming_options():
    """Test error on both output_names and prefix."""
    with pytest.raises(ValueError, match="Specify either output_names or prefix"):
        TVMerge(
            datasets=[pd.DataFrame(), pd.DataFrame()],
            id_col='id',
            start_cols=['start', 'start'],
            stop_cols=['stop', 'stop'],
            exposure_cols=['exp', 'exp'],
            output_names=['a', 'b'],
            prefix='var_',
        )

def test_id_mismatch_strict():
    """Test error on ID mismatch with strict_ids=True."""
    from tvmerge.exceptions import IDMismatchError

    df1 = pd.DataFrame({
        'id': [1, 2],
        'start': [0, 0],
        'stop': [10, 10],
        'exp': ['A', 'A'],
    })

    df2 = pd.DataFrame({
        'id': [1, 3],  # ID 3 not in df1, ID 2 not in df2
        'start': [0, 0],
        'stop': [10, 10],
        'exp': [1, 1],
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp', 'exp'],
        strict_ids=True,
    )

    with pytest.raises(IDMismatchError):
        merger.merge()

def test_id_mismatch_force():
    """Test warning on ID mismatch with strict_ids=False."""
    df1 = pd.DataFrame({
        'id': [1, 2],
        'start': [0, 0],
        'stop': [10, 10],
        'exp': ['A', 'A'],
    })

    df2 = pd.DataFrame({
        'id': [1, 3],
        'start': [0, 0],
        'stop': [10, 10],
        'exp': [1, 1],
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp', 'exp'],
        strict_ids=False,  # Allow mismatch
    )

    result = merger.merge()

    # Only ID 1 should remain
    assert result['id'].nunique() == 1
    assert result['id'].iloc[0] == 1
```

#### test_edge_cases.py

```python
def test_empty_intersection():
    """Test datasets with no overlapping periods."""
    df1 = pd.DataFrame({
        'id': [1],
        'start': [0],
        'stop': [10],
        'exp': ['A'],
    })

    df2 = pd.DataFrame({
        'id': [1],
        'start': [20],  # No overlap
        'stop': [30],
        'exp': [1],
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp', 'exp'],
    )

    result = merger.merge()

    # Should return empty DataFrame with correct structure
    assert len(result) == 0
    assert set(result.columns) == {'id', 'start', 'stop', 'exp', 'exp'}

def test_single_day_periods():
    """Test point-in-time observations (start == stop)."""
    df1 = pd.DataFrame({
        'id': [1],
        'start': [5],
        'stop': [5],  # Single day
        'exp': ['A'],
    })

    df2 = pd.DataFrame({
        'id': [1],
        'start': [5],
        'stop': [5],  # Single day
        'exp': [1],
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp', 'exp'],
    )

    result = merger.merge()

    assert len(result) == 1
    assert result['start'].iloc[0] == 5
    assert result['stop'].iloc[0] == 5

def test_invalid_periods_dropped():
    """Test that invalid periods (start > stop) are dropped."""
    df1 = pd.DataFrame({
        'id': [1, 2],
        'start': [0, 10],  # Second period invalid
        'stop': [10, 5],   # 10 > 5
        'exp': ['A', 'B'],
    })

    df2 = pd.DataFrame({
        'id': [1, 2],
        'start': [0, 0],
        'stop': [10, 10],
        'exp': [1, 2],
    })

    merger = TVMerge(
        datasets=[df1, df2],
        id_col='id',
        start_cols=['start', 'start'],
        stop_cols=['stop', 'stop'],
        exposure_cols=['exp', 'exp'],
    )

    result = merger.merge()

    # Only ID 1 should have results (ID 2 had invalid period)
    assert result['id'].nunique() == 1
    assert 1 in result['id'].values
    assert 2 not in result['id'].values
```

---

## Memory Optimization Strategies

### 1. Batch Processing

**Problem**: Cartesian joins can create very large intermediate datasets.

**Solution**: Process IDs in batches, concatenate results.

```python
# Instead of:
result = left.merge(right, on='id', how='inner')  # Huge memory spike

# Do:
batches = split_ids(unique_ids, batch_pct)
results = [process_batch(left, right, batch) for batch in batches]
result = pd.concat(results)  # More gradual memory usage
```

### 2. Column Selection

**Problem**: Keeping unnecessary columns wastes memory.

**Solution**: Drop columns as early as possible.

```python
# After each merge, keep only needed columns
result = result[required_columns]
```

### 3. Data Types

**Problem**: Default dtypes use more memory than needed.

**Solution**: Downcast numeric types.

```python
# After merge, optimize dtypes
for col in result.select_dtypes(include=['float64']).columns:
    result[col] = pd.to_numeric(result[col], downcast='float')

for col in result.select_dtypes(include=['int64']).columns:
    result[col] = pd.to_numeric(result[col], downcast='integer')
```

### 4. Categorical Encoding

**Problem**: String exposures use lots of memory.

**Solution**: Convert to categorical dtype.

```python
for col in exposure_cols:
    if result[col].dtype == 'object':
        result[col] = result[col].astype('category')
```

### 5. Chunked I/O

**Problem**: Loading large datasets into memory all at once.

**Solution**: Use chunked reading for very large files.

```python
def load_large_dataset(filepath, chunksize=100000):
    """Load dataset in chunks."""
    chunks = pd.read_csv(filepath, chunksize=chunksize)
    return pd.concat(chunks, ignore_index=True)
```

---

## Performance Benchmarks

### Expected Performance

| Dataset Size | IDs | Periods/ID | Datasets | batch_pct=20 | batch_pct=50 | n_jobs=-1 |
|--------------|-----|------------|----------|--------------|--------------|-----------|
| Small        | 100 | 10         | 2        | < 1s         | < 1s         | < 1s      |
| Medium       | 1K  | 50         | 2        | 5s           | 3s           | 2s        |
| Large        | 10K | 100        | 2        | 2min         | 1min         | 30s       |
| Very Large   | 100K| 100        | 3        | 30min        | 15min        | 5min      |

### Optimization Tips

1. **Use larger batches** if you have sufficient RAM (batch_pct=50-100)
2. **Use parallel processing** for datasets with >1000 IDs (n_jobs=-1)
3. **Pre-filter datasets** to only include needed IDs before merging
4. **Use categorical dtype** for exposure variables with few unique values
5. **Consider dask** for datasets >1M IDs (out-of-core processing)

---

## Example Usage

### Basic Example

```python
from tvmerge import TVMerge

# Load datasets (already processed by tvexpose)
merger = TVMerge(
    datasets=['tv_hrt.csv', 'tv_dmt.csv'],
    id_col='id',
    start_cols=['rx_start', 'dmt_start'],
    stop_cols=['rx_stop', 'dmt_stop'],
    exposure_cols=['tv_exposure', 'tv_exposure'],
    output_names=['hrt', 'dmt']
)

result = merger.merge()
print(result.head())
```

### Advanced Example with All Options

```python
from tvmerge import TVMerge

merger = TVMerge(
    datasets=['tv_hrt.csv', 'tv_dmt.csv', 'tv_dose.csv'],
    id_col='person_id',
    start_cols=['start', 'start', 'start'],
    stop_cols=['stop', 'stop', 'stop'],
    exposure_cols=['hrt_type', 'dmt_type', 'dosage'],
    continuous=['dosage'],  # Dosage is continuous
    output_names=['hrt', 'dmt', 'dose'],
    start_name='period_start',
    stop_name='period_end',
    keep_cols=['age', 'sex'],  # Will create age_ds1, sex_ds1, etc.
    batch_pct=50,  # 50% of IDs per batch
    n_jobs=-1,  # Use all CPU cores
    validate_coverage=True,  # Check for gaps
    validate_overlap=True,  # Check for unexpected overlaps
    check_diagnostics=True,  # Display diagnostics
    strict_ids=False,  # Allow ID mismatches (with warning)
)

result = merger.merge()

# Access metadata
print(f"Merged {merger.metadata.n_persons} persons")
print(f"Created {merger.metadata.n_observations} time periods")
print(f"Continuous exposures: {merger.metadata.continuous_vars}")
print(f"Categorical exposures: {merger.metadata.categorical_vars}")

# Save result
merger.save('merged_exposures.csv')
```

### Using DataFrames Instead of Files

```python
import pandas as pd
from tvmerge import TVMerge

# Create or load DataFrames
df_hrt = pd.read_csv('tv_hrt.csv')
df_dmt = pd.read_csv('tv_dmt.csv')

merger = TVMerge(
    datasets=[df_hrt, df_dmt],  # Pass DataFrames directly
    id_col='id',
    start_cols=['rx_start', 'dmt_start'],
    stop_cols=['rx_stop', 'dmt_stop'],
    exposure_cols=['tv_exposure', 'tv_exposure'],
    output_names=['hrt', 'dmt']
)

result = merger.merge()
```

### Continuous Exposure Example

```python
from tvmerge import TVMerge

# Merge categorical HRT with continuous dosage
merger = TVMerge(
    datasets=['tv_hrt.csv', 'tv_dose.csv'],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['hrt_type', 'dosage_rate'],
    continuous=['dosage_rate'],  # Or continuous=[2]
    output_names=['hrt', 'dose']
)

result = merger.merge()

# Result has columns:
# - id
# - start, stop
# - hrt (categorical)
# - dose (rate per day)
# - dose_period (total dose in period)

print(result.head())
#    id  start  stop  hrt   dose  dose_period
# 0   1      0    10    A  100.0       1100.0
# 1   1     11    20    B  150.0       1500.0
```

---

## Installation and Setup

### Package Structure

```
tvmerge/
├── pyproject.toml
├── README.md
├── LICENSE
├── tvmerge/
│   ├── __init__.py
│   ├── merger.py
│   ├── validators.py
│   ├── cartesian.py
│   ├── diagnostics.py
│   ├── exceptions.py
│   ├── types.py
│   └── utils.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_basic_merge.py
│   ├── test_continuous.py
│   ├── test_validation.py
│   ├── test_batch_processing.py
│   ├── test_edge_cases.py
│   ├── test_diagnostics.py
│   └── test_integration.py
└── examples/
    ├── basic_merge.py
    ├── continuous_exposure.py
    └── advanced_workflow.py
```

### pyproject.toml

```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "tvmerge"
version = "1.0.0"
description = "Merge multiple time-varying exposure datasets"
readme = "README.md"
license = {text = "MIT"}
authors = [
    {name = "Your Name", email = "your@email.com"}
]
requires-python = ">=3.8"
dependencies = [
    "pandas>=1.5.0",
    "numpy>=1.23.0",
]

[project.optional-dependencies]
parallel = [
    "joblib>=1.2.0",
]
dev = [
    "pytest>=7.2.0",
    "pytest-cov>=4.0.0",
    "black>=22.0.0",
    "mypy>=0.990",
    "ruff>=0.0.200",
]

[project.urls]
Homepage = "https://github.com/yourusername/tvmerge"
Repository = "https://github.com/yourusername/tvmerge"
```

### Installation

```bash
# From PyPI (when published)
pip install tvmerge

# With parallel processing support
pip install tvmerge[parallel]

# For development
git clone https://github.com/yourusername/tvmerge
cd tvmerge
pip install -e ".[dev]"
```

---

## Implementation Checklist

### Phase 1: Core Functionality
- [ ] Create package structure
- [ ] Implement TVMerge class skeleton
- [ ] Implement input validation (validators.py)
- [ ] Implement basic Cartesian merge (cartesian.py)
- [ ] Write basic tests
- [ ] Test with simple two-dataset merge

### Phase 2: Advanced Features
- [ ] Implement continuous exposure handling
- [ ] Implement batch processing
- [ ] Add parallel processing support
- [ ] Implement diagnostics (diagnostics.py)
- [ ] Write comprehensive tests

### Phase 3: Optimization
- [ ] Optimize memory usage
- [ ] Add progress bars (optional tqdm)
- [ ] Benchmark performance
- [ ] Add type hints throughout
- [ ] Run mypy type checking

### Phase 4: Documentation
- [ ] Write comprehensive docstrings
- [ ] Create usage examples
- [ ] Write README.md
- [ ] Add inline comments
- [ ] Generate API documentation

### Phase 5: Testing & QA
- [ ] Write edge case tests
- [ ] Write integration tests
- [ ] Test with real-world data
- [ ] Verify against Stata implementation
- [ ] Achieve >90% test coverage

### Phase 6: Polish
- [ ] Format with black
- [ ] Lint with ruff
- [ ] Fix all mypy errors
- [ ] Add CLI interface (optional)
- [ ] Prepare for PyPI release

---

## Key Differences from Stata Implementation

1. **Type Safety**: Python implementation uses type hints for better IDE support and error catching.

2. **Object-Oriented**: Uses class-based design vs. Stata's procedural approach.

3. **Memory Management**: Python's garbage collection vs. Stata's explicit preserve/restore.

4. **Parallelization**: joblib for parallel processing vs. Stata's single-threaded approach.

5. **Error Handling**: Custom exception classes vs. Stata's numeric error codes.

6. **Metadata**: Stored as object attribute vs. Stata's r() returns.

7. **File Formats**: Supports multiple formats (CSV, Parquet, Excel) vs. Stata's .dta only.

8. **Flexible Input**: Accepts DataFrames or file paths vs. Stata's file-only approach.

---

## Future Enhancements

1. **Dask Support**: For datasets too large for memory
2. **GPU Acceleration**: Using cuDF for very large datasets
3. **SQL Backend**: Option to perform merge in database
4. **Incremental Merge**: Merge new data into existing results
5. **Visualization**: Plot exposure timelines
6. **Export to Survival Formats**: Direct export for Cox models
7. **Smart Caching**: Cache intermediate results for repeated merges
8. **CLI Interface**: Command-line tool for non-Python users

---

## Success Criteria

The implementation is complete when:

1. ✅ All basic merge scenarios work correctly
2. ✅ Continuous exposures are properly prorated
3. ✅ Batch processing improves performance by >10x
4. ✅ Results match Stata tvmerge output exactly
5. ✅ All tests pass with >90% coverage
6. ✅ Type hints pass mypy strict mode
7. ✅ Documentation is comprehensive
8. ✅ Performance meets benchmarks
9. ✅ Memory usage is optimized
10. ✅ Ready for PyPI release

---

*This plan provides a complete roadmap for implementing tvmerge in Python with all features, optimizations, and testing strategies needed for a production-ready package.*
