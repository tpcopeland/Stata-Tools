"""
Merging Commands

Implements:
- merge: Merge two datasets
- append: Append observations from another dataset
- joinby: Form all pairwise combinations
- expand: Duplicate observations
- reshape: Reshape data wide/long
"""

import numpy as np
import pandas as pd
from typing import Optional


class MergingCommands:
    """Merging command implementations."""

    def __init__(self, interpreter):
        """Initialize with interpreter reference."""
        self.interp = interpreter

    @property
    def data(self):
        return self.interp.data

    @property
    def macros(self):
        return self.interp.macros

    def cmd_merge(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
        using: Optional[str] = None,
    ) -> None:
        """
        Merge two datasets.

        Syntax: merge 1:1 varlist using filename [, options]
               merge m:1 varlist using filename [, options]
               merge 1:m varlist using filename [, options]
               merge m:m varlist using filename [, options]
        """
        options = options or {}

        if not args:
            raise ValueError("merge requires match type and varlist")

        # Parse merge type - may be split by parser (e.g., ['m', ':', 1, 'id'] for 'm:1 id')
        merge_type = str(args[0]).lower()
        key_vars = [str(a) for a in args[1:]]

        # Handle split merge type (parser splits m:1 into ['m', ':', 1] or ['m', 1])
        if merge_type in ("m", "1") and len(args) > 1:
            # Check if next token is ':' (colon captured separately)
            if str(args[1]) == ":" and len(args) > 2 and str(args[2]) in ("1", "m"):
                merge_type = f"{merge_type}:{args[2]}"
                key_vars = [str(a) for a in args[3:]]
            # Check if next token is '1' or 'm' directly (no colon)
            elif str(args[1]) in ("1", "m"):
                merge_type = f"{merge_type}:{args[1]}"
                key_vars = [str(a) for a in args[2:]]

        if merge_type not in ("1:1", "m:1", "1:m", "m:m"):
            # Maybe old syntax without merge type
            key_vars = [str(a) for a in args]
            merge_type = "1:1"

        if not using:
            raise ValueError("merge requires using filename")

        filename = using.strip('"').strip("'")
        if not filename.endswith(".dta"):
            filename = f"{filename}.dta"

        # Load using dataset
        try:
            using_df = pd.read_stata(filename, convert_categoricals=False)
        except FileNotFoundError:
            raise ValueError(f"file {filename} not found")

        # Options
        keep_opt = options.get("keep", "match master using")
        # nogen, nogenerate, and nogenerat are all valid abbreviations
        nogenerate = options.get("nogenerate", options.get("nogen", False))
        keepusing = options.get("keepusing")
        generate = options.get("generate", "_merge")

        # Select variables from using
        if keepusing:
            keep_vars = keepusing.split() + key_vars
            using_df = using_df[[v for v in keep_vars if v in using_df.columns]]

        # Determine pandas merge type
        how = "outer"  # Default
        if "match" in keep_opt and "master" not in keep_opt and "using" not in keep_opt:
            how = "inner"
        elif "match" in keep_opt and "master" in keep_opt and "using" not in keep_opt:
            how = "left"
        elif "match" in keep_opt and "using" in keep_opt and "master" not in keep_opt:
            how = "right"

        # Validate key variables
        for var in key_vars:
            if var not in self.data.df.columns:
                raise ValueError(f"variable {var} not found in master")
            if var not in using_df.columns:
                raise ValueError(f"variable {var} not found in using")

        # Perform merge
        master_df = self.data.df.copy()
        result = pd.merge(
            master_df,
            using_df,
            on=key_vars,
            how=how,
            indicator=True if not nogenerate else False,
            suffixes=("", "_merge_using"),
        )

        # Create _merge variable
        if not nogenerate:
            merge_map = {
                "left_only": 1,  # master only
                "right_only": 2,  # using only
                "both": 3,  # matched
            }
            result[generate] = result["_merge"].map(merge_map)
            result = result.drop(columns=["_merge"])

        # Store merge results
        if not nogenerate:
            merge_counts = result[generate].value_counts()
            self.macros.set_return("N_1", int(merge_counts.get(1, 0)))
            self.macros.set_return("N_2", int(merge_counts.get(2, 0)))
            self.macros.set_return("N_3", int(merge_counts.get(3, 0)))
            self.macros.set_return(
                "N_4", 0
            )  # Would be for m:m conflicts
            self.macros.set_return("N_5", 0)

        self.data.df = result

    def cmd_append(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
        using: Optional[str] = None,
    ) -> None:
        """
        Append observations from another dataset.

        Syntax: append using filename [, options]
        """
        options = options or {}

        if not using:
            raise ValueError("append requires using filename")

        filename = using.strip('"').strip("'")
        if not filename.endswith(".dta"):
            filename = f"{filename}.dta"

        # Load using dataset
        try:
            using_df = pd.read_stata(filename, convert_categoricals=False)
        except FileNotFoundError:
            raise ValueError(f"file {filename} not found")

        # Options
        force = options.get("force", False)
        generate = options.get("generate")
        keep = options.get("keep")

        # Select variables
        if keep:
            keep_vars = keep.split()
            using_df = using_df[[v for v in keep_vars if v in using_df.columns]]

        # Add source indicator if requested
        if generate:
            self.data.df[generate] = 0
            using_df[generate] = 1

        # Append
        self.data.df = pd.concat(
            [self.data.df, using_df], ignore_index=True, sort=False
        )

    def cmd_joinby(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
        using: Optional[str] = None,
    ) -> None:
        """
        Form all pairwise combinations within groups.

        Syntax: joinby varlist using filename [, options]
        """
        options = options or {}

        if not using:
            raise ValueError("joinby requires using filename")

        key_vars = [str(a) for a in args] if args else []

        filename = using.strip('"').strip("'")
        if not filename.endswith(".dta"):
            filename = f"{filename}.dta"

        # Load using dataset
        try:
            using_df = pd.read_stata(filename, convert_categoricals=False)
        except FileNotFoundError:
            raise ValueError(f"file {filename} not found")

        # Perform cross join within groups
        if key_vars:
            # Join on key variables
            result = pd.merge(
                self.data.df,
                using_df,
                on=key_vars,
                how="inner",
                suffixes=("", "_using"),
            )
        else:
            # Full cross join
            self.data.df["_cross_key"] = 1
            using_df["_cross_key"] = 1
            result = pd.merge(
                self.data.df,
                using_df,
                on="_cross_key",
                how="inner",
                suffixes=("", "_using"),
            )
            result = result.drop(columns=["_cross_key"])

        self.data.df = result

    def cmd_expand(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Duplicate observations.

        Syntax: expand =exp [if] [in] [, generate(newvar)]
        """
        options = options or {}

        if not args:
            raise ValueError("expand requires expression")

        # Evaluate expansion count
        expr = " ".join(str(a) for a in args)
        if expr.startswith("="):
            expr = expr[1:]

        counts = self.interp.expr_eval.evaluate(expr)

        # Apply if/in conditions
        mask = self.interp.cond_eval.evaluate_combined(if_cond, in_range)

        if isinstance(counts, pd.Series):
            counts = counts.fillna(1).astype(int)
        else:
            counts = pd.Series([int(counts)] * self.data.N)

        # Set count to 1 for non-matching observations
        counts.loc[~mask] = 1

        # Expand
        generate = options.get("generate")

        new_rows = []
        expand_flags = []
        for idx, count in enumerate(counts):
            count = max(1, int(count))
            for i in range(count):
                new_rows.append(self.data.df.iloc[idx])
                expand_flags.append(1 if i > 0 else 0)

        result = pd.DataFrame(new_rows).reset_index(drop=True)

        if generate:
            result[generate] = expand_flags

        self.data.df = result

    def cmd_reshape(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Reshape data between wide and long formats.

        Syntax: reshape long stubnames, i(varlist) j(varname)
               reshape wide stubnames, i(varlist) j(varname)
        """
        options = options or {}

        if not args:
            raise ValueError("reshape requires direction (long/wide)")

        direction = str(args[0]).lower()
        stubs = [str(a) for a in args[1:]]

        i_vars = options.get("i", "").split()
        j_var = options.get("j", "")

        if not i_vars:
            raise ValueError("reshape requires i() option")
        if not j_var:
            raise ValueError("reshape requires j() option")

        if direction == "long":
            self._reshape_long(stubs, i_vars, j_var, options)
        elif direction == "wide":
            self._reshape_wide(stubs, i_vars, j_var, options)
        else:
            raise ValueError(f"unknown reshape direction: {direction}")

    def _reshape_long(
        self, stubs: list, i_vars: list, j_var: str, options: dict
    ) -> None:
        """Reshape wide to long."""
        # Find all columns matching stub patterns
        stub_cols = {}
        for stub in stubs:
            matching = [c for c in self.data.df.columns if c.startswith(stub)]
            if matching:
                stub_cols[stub] = matching

        if not stub_cols:
            raise ValueError("no matching stub variables found")

        # Get j values from column suffixes
        j_values = set()
        for stub, cols in stub_cols.items():
            for col in cols:
                suffix = col[len(stub) :]
                if suffix:
                    j_values.add(suffix)

        j_values = sorted(j_values)

        # Build long format
        result_rows = []
        for idx, row in self.data.df.iterrows():
            for j_val in j_values:
                new_row = {var: row[var] for var in i_vars if var in row}
                new_row[j_var] = j_val

                for stub in stubs:
                    col_name = f"{stub}{j_val}"
                    if col_name in row:
                        new_row[stub] = row[col_name]
                    else:
                        new_row[stub] = np.nan

                result_rows.append(new_row)

        # Add non-stub, non-i columns
        other_cols = [
            c
            for c in self.data.df.columns
            if c not in i_vars
            and not any(c.startswith(s) for s in stubs)
        ]

        for i, row in enumerate(result_rows):
            orig_idx = i // len(j_values)
            for col in other_cols:
                row[col] = self.data.df.iloc[orig_idx][col]

        self.data.df = pd.DataFrame(result_rows)

        # Try to convert j to numeric
        try:
            self.data.df[j_var] = pd.to_numeric(self.data.df[j_var])
        except (ValueError, TypeError):
            pass

    def _reshape_wide(
        self, stubs: list, i_vars: list, j_var: str, options: dict
    ) -> None:
        """Reshape long to wide."""
        if j_var not in self.data.df.columns:
            raise ValueError(f"j variable {j_var} not found")

        # Get unique j values
        j_values = self.data.df[j_var].unique()

        # Group by i variables
        grouped = self.data.df.groupby(i_vars)

        result_rows = []
        for keys, group in grouped:
            if not isinstance(keys, tuple):
                keys = (keys,)
            new_row = dict(zip(i_vars, keys))

            # Add other columns from first row
            other_cols = [
                c for c in self.data.df.columns if c not in i_vars + stubs + [j_var]
            ]
            for col in other_cols:
                new_row[col] = group.iloc[0][col]

            # Create wide columns
            for _, row in group.iterrows():
                j_val = row[j_var]
                for stub in stubs:
                    if stub in row:
                        new_row[f"{stub}{j_val}"] = row[stub]

            result_rows.append(new_row)

        self.data.df = pd.DataFrame(result_rows)

    def cmd_cross(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
        using: Optional[str] = None,
    ) -> None:
        """
        Form every pairwise combination of two datasets.

        Syntax: cross using filename
        """
        if not using:
            raise ValueError("cross requires using filename")

        filename = using.strip('"').strip("'")
        if not filename.endswith(".dta"):
            filename = f"{filename}.dta"

        try:
            using_df = pd.read_stata(filename, convert_categoricals=False)
        except FileNotFoundError:
            raise ValueError(f"file {filename} not found")

        # Cross join
        self.data.df["_cross_key"] = 1
        using_df["_cross_key"] = 1
        result = pd.merge(
            self.data.df, using_df, on="_cross_key", suffixes=("", "_using")
        )
        result = result.drop(columns=["_cross_key"])

        self.data.df = result
