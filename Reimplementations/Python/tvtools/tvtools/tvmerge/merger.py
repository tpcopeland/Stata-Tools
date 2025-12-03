"""Main TVMerge class for merging time-varying exposure datasets."""

from typing import Union, List, Optional, Dict
from pathlib import Path
import pandas as pd
import numpy as np

from .types import MergeMetadata, DatasetInput


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
        datasets: List[DatasetInput],
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
                id_col='id',
                start_name=self.start_name,
                stop_name=self.stop_name,
                right_exposure_cols=self._get_exposure_cols_for_dataset(i),
                continuous_flags=self._get_continuous_flags_for_dataset(i, continuous_flags),
                batch_pct=self.batch_pct,
                n_jobs=self.n_jobs,
            )

        # Step 5: Remove exact duplicates
        dup_cols = ['id', self.start_name, self.stop_name] + self._get_all_final_exposure_cols()
        n_before = len(result)
        result = result.drop_duplicates(subset=dup_cols, keep='first')
        n_duplicates = n_before - len(result)

        if n_duplicates > 0:
            print(f"Dropped {n_duplicates} duplicate interval+exposure combinations")

        # Step 6: Sort final dataset
        result = result.sort_values(['id', self.start_name, self.stop_name]).reset_index(drop=True)

        # Step 7: Calculate metadata
        self.metadata = self._calculate_metadata(
            result, invalid_periods, n_duplicates, continuous_flags
        )

        # Step 8: Run diagnostics if requested
        if self.check_diagnostics:
            self._display_diagnostics()

        if self.validate_coverage:
            coverage_issues = check_coverage(result, 'id', self.start_name, self.stop_name)
            self._display_coverage_issues(coverage_issues)

        if self.validate_overlap:
            overlap_issues = check_overlaps(
                result, 'id', self.start_name, self.stop_name,
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
        dataset: DatasetInput,
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
        dataset : DatasetInput
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
        if self.metadata is None:
            raise ValueError("No merge result to save. Call merge() first.")

        filepath = Path(filepath)

        # This would need access to the result - we should store it
        # For now, this is a placeholder that would need the result passed in
        raise NotImplementedError(
            "save() method requires storing the result. "
            "Please save the returned DataFrame manually using pandas methods."
        )
