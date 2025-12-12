"""
Sorting Commands

Implements:
- sort: Sort data in ascending order
- gsort: Sort data with descending option
- order: Reorder variables
- aorder: Alphabetically order variables
"""

import numpy as np
import pandas as pd
from typing import Optional, List


class SortingCommands:
    """Sorting command implementations."""

    def __init__(self, interpreter):
        """Initialize with interpreter reference."""
        self.interp = interpreter

    @property
    def data(self):
        return self.interp.data

    def cmd_sort(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Sort data in ascending order.

        Syntax: sort varlist [, stable]
        """
        options = options or {}

        if not args:
            raise ValueError("sort requires variable list")

        vars_to_sort = [str(v) for v in args]

        # Verify all variables exist
        for var in vars_to_sort:
            if not self.data.has_var(var):
                raise ValueError(f"variable {var} not found")

        stable = options.get("stable", False)
        kind = "mergesort" if stable else "quicksort"

        self.data.df.sort_values(
            by=vars_to_sort, ascending=True, kind=kind, inplace=True
        )
        self.data.df.reset_index(drop=True, inplace=True)
        self.data._sort_vars = vars_to_sort

    def cmd_gsort(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Sort data with ascending/descending options.

        Syntax: gsort [+|-]varname [[+|-]varname ...]

        Variables prefixed with - are sorted descending.
        Variables prefixed with + (or no prefix) are sorted ascending.
        """
        options = options or {}

        if not args:
            raise ValueError("gsort requires variable list")

        vars_to_sort = []
        ascending = []

        # Pre-process args to combine '-' or '+' with following variable
        processed_args = []
        i = 0
        while i < len(args):
            arg = str(args[i])
            if arg in ("-", "+") and i + 1 < len(args):
                # Combine with next argument
                processed_args.append(arg + str(args[i + 1]))
                i += 2
            else:
                processed_args.append(arg)
                i += 1

        for arg in processed_args:
            arg = str(arg)
            if arg.startswith("-"):
                var = arg[1:]
                vars_to_sort.append(var)
                ascending.append(False)
            elif arg.startswith("+"):
                var = arg[1:]
                vars_to_sort.append(var)
                ascending.append(True)
            else:
                vars_to_sort.append(arg)
                ascending.append(True)

        # Verify all variables exist
        for var in vars_to_sort:
            if not self.data.has_var(var):
                raise ValueError(f"variable {var} not found")

        mfirst = options.get("mfirst", False)
        na_position = "first" if mfirst else "last"

        self.data.df.sort_values(
            by=vars_to_sort, ascending=ascending, na_position=na_position, inplace=True
        )
        self.data.df.reset_index(drop=True, inplace=True)
        self.data._sort_vars = vars_to_sort

    def cmd_order(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Reorder variables.

        Syntax: order varlist [, first last before(varname) after(varname) alphabetic]
        """
        options = options or {}

        if not args:
            raise ValueError("order requires variable list")

        vars_to_order = self._expand_varlist(args)
        current_order = list(self.data.df.columns)

        # Handle options
        alphabetic = options.get("alphabetic", options.get("alpha", False))
        first = options.get("first", False)
        last = options.get("last", False)
        before = options.get("before")
        after = options.get("after")

        # Verify all variables exist
        for var in vars_to_order:
            if var not in current_order:
                raise ValueError(f"variable {var} not found")

        # Remove vars_to_order from current order
        remaining = [v for v in current_order if v not in vars_to_order]

        if alphabetic:
            vars_to_order = sorted(vars_to_order)

        if last:
            # Put at end
            new_order = remaining + vars_to_order
        elif before:
            # Put before specified variable
            if before not in remaining:
                raise ValueError(f"variable {before} not found")
            idx = remaining.index(before)
            new_order = remaining[:idx] + vars_to_order + remaining[idx:]
        elif after:
            # Put after specified variable
            if after not in remaining:
                raise ValueError(f"variable {after} not found")
            idx = remaining.index(after) + 1
            new_order = remaining[:idx] + vars_to_order + remaining[idx:]
        else:
            # Default: put first (or specified position)
            new_order = vars_to_order + remaining

        self.data.df = self.data.df[new_order]

    def cmd_aorder(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Alphabetically order all variables.

        Syntax: aorder
        """
        current_order = list(self.data.df.columns)
        new_order = sorted(current_order)
        self.data.df = self.data.df[new_order]

    def _expand_varlist(self, args: list) -> list:
        """Expand variable list with wildcards."""
        import re

        result = []
        for arg in args:
            arg = str(arg)
            if "*" in arg or "?" in arg:
                pattern = arg.replace("*", ".*").replace("?", ".")
                pattern = f"^{pattern}$"
                for var in self.data.varlist:
                    if re.match(pattern, var):
                        result.append(var)
            elif "-" in arg and not arg.startswith("-"):
                parts = arg.split("-")
                if len(parts) == 2:
                    start_var = parts[0].strip()
                    end_var = parts[1].strip()
                    in_range = False
                    for var in self.data.varlist:
                        if var == start_var:
                            in_range = True
                        if in_range:
                            result.append(var)
                        if var == end_var:
                            in_range = False
                else:
                    result.append(arg)
            else:
                result.append(arg)
        return result
