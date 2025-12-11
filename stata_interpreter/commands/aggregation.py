"""
Aggregation Commands

Implements:
- collapse: Collapse data to summary statistics
- contract: Contract data to frequencies
- duplicates: Report, tag, or drop duplicate observations
- isid: Check that variable(s) uniquely identify observations
- distinct: Report distinct values
- levelsof: Get levels of a variable
- tabulate: Tabulate frequencies
"""

import numpy as np
import pandas as pd
from typing import Optional


class AggregationCommands:
    """Aggregation command implementations."""

    def __init__(self, interpreter):
        """Initialize with interpreter reference."""
        self.interp = interpreter

    @property
    def data(self):
        return self.interp.data

    @property
    def macros(self):
        return self.interp.macros

    @property
    def cond_eval(self):
        return self.interp.cond_eval

    def cmd_collapse(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Collapse data to summary statistics.

        Syntax: collapse (stat) varlist [(stat) varlist ...] [if] [in], by(varlist)
        """
        options = options or {}

        if not args:
            raise ValueError("collapse requires statistic and variables")

        # Parse (stat) varlist groups
        stat_specs = self._parse_collapse_specs(args)

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)
        df = self.data.df.loc[mask].copy()

        by_vars = options.get("by", "").split() if options.get("by") else []

        # Build aggregation dict
        agg_dict = {}
        rename_dict = {}

        for stat, vars_list in stat_specs:
            stat_lower = stat.lower()
            for var_spec in vars_list:
                # Handle newvar=var syntax
                if "=" in var_spec:
                    new_var, old_var = var_spec.split("=")
                else:
                    new_var = var_spec
                    old_var = var_spec

                if old_var not in df.columns:
                    continue

                # Map Stata stat to pandas
                pandas_stat = self._map_stat(stat_lower)

                if old_var in agg_dict:
                    # Multiple stats for same variable
                    if isinstance(agg_dict[old_var], list):
                        agg_dict[old_var].append(pandas_stat)
                    else:
                        agg_dict[old_var] = [agg_dict[old_var], pandas_stat]
                else:
                    agg_dict[old_var] = pandas_stat

                rename_dict[(old_var, pandas_stat)] = new_var

        # Perform collapse
        if by_vars:
            result = df.groupby(by_vars).agg(agg_dict).reset_index()
        else:
            result = df.agg(agg_dict).to_frame().T

        # Flatten multi-level columns if needed
        if isinstance(result.columns, pd.MultiIndex):
            result.columns = [
                rename_dict.get((col[0], col[1]), f"{col[0]}_{col[1]}")
                for col in result.columns
            ]
        else:
            # Simple rename
            new_cols = []
            for col in result.columns:
                if col in by_vars:
                    new_cols.append(col)
                else:
                    # Find the new name
                    found = False
                    for (old_var, _), new_var in rename_dict.items():
                        if old_var == col:
                            new_cols.append(new_var)
                            found = True
                            break
                    if not found:
                        new_cols.append(col)
            result.columns = new_cols

        self.data.df = result

    def _parse_collapse_specs(self, args: list) -> list:
        """Parse collapse specification into (stat, vars) tuples."""
        specs = []
        current_stat = "mean"  # Default
        current_vars = []

        i = 0
        while i < len(args):
            arg = str(args[i])

            # Check for (stat) pattern
            if arg.startswith("(") and arg.endswith(")"):
                # Save previous spec
                if current_vars:
                    specs.append((current_stat, current_vars))
                current_stat = arg[1:-1]
                current_vars = []
            elif arg.startswith("("):
                # Stat without closing paren
                current_stat = arg[1:]
            elif arg.endswith(")"):
                # Closing paren
                var = arg[:-1]
                if var:
                    current_vars.append(var)
            else:
                current_vars.append(arg)

            i += 1

        # Save last spec
        if current_vars:
            specs.append((current_stat, current_vars))

        return specs

    def _map_stat(self, stat: str) -> str:
        """Map Stata statistic name to pandas aggregation function."""
        stat_map = {
            "mean": "mean",
            "sum": "sum",
            "count": "count",
            "max": "max",
            "min": "min",
            "sd": "std",
            "median": "median",
            "first": "first",
            "last": "last",
            "firstnm": "first",
            "lastnm": "last",
            "p1": lambda x: x.quantile(0.01),
            "p5": lambda x: x.quantile(0.05),
            "p10": lambda x: x.quantile(0.10),
            "p25": lambda x: x.quantile(0.25),
            "p50": lambda x: x.quantile(0.50),
            "p75": lambda x: x.quantile(0.75),
            "p90": lambda x: x.quantile(0.90),
            "p95": lambda x: x.quantile(0.95),
            "p99": lambda x: x.quantile(0.99),
            "iqr": lambda x: x.quantile(0.75) - x.quantile(0.25),
            "rawsum": "sum",
        }
        return stat_map.get(stat, "mean")

    def cmd_contract(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Contract data to frequencies.

        Syntax: contract varlist [if] [in] [, options]
        """
        options = options or {}

        varlist = [str(a) for a in args]

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)
        df = self.data.df.loc[mask].copy()

        freq_var = options.get("freq", "_freq")
        percent_var = options.get("percent")
        cfreq_var = options.get("cfreq")
        cpercent_var = options.get("cpercent")

        # Get existing variables
        existing_vars = [v for v in varlist if v in df.columns]

        # Count frequencies
        result = df.groupby(existing_vars).size().reset_index(name=freq_var)

        # Add percent
        total = result[freq_var].sum()
        if percent_var:
            result[percent_var] = result[freq_var] / total * 100

        # Add cumulative
        if cfreq_var:
            result[cfreq_var] = result[freq_var].cumsum()
        if cpercent_var:
            result[cpercent_var] = result[freq_var].cumsum() / total * 100

        self.data.df = result

    def cmd_duplicates(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Report, tag, or drop duplicates.

        Syntax: duplicates report [varlist] [if] [in]
               duplicates tag [varlist] [if] [in], generate(newvar)
               duplicates drop [varlist] [if] [in]
        """
        options = options or {}

        if not args:
            raise ValueError("duplicates requires subcommand")

        subcmd = str(args[0]).lower()
        varlist = [str(a) for a in args[1:]]

        if not varlist:
            varlist = list(self.data.df.columns)

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)

        existing_vars = [v for v in varlist if v in self.data.df.columns]

        if subcmd == "report":
            # Report duplicates
            dup_counts = self.data.df.loc[mask].groupby(existing_vars).size()
            n_unique = len(dup_counts)
            n_surplus = len(self.data.df.loc[mask]) - n_unique

            self.interp.output(f"Duplicates in terms of {' '.join(existing_vars)}")
            self.interp.output(f"Observations: {len(self.data.df.loc[mask])}")
            self.interp.output(f"Unique values: {n_unique}")
            self.interp.output(f"Surplus: {n_surplus}")

        elif subcmd == "tag":
            # Tag duplicates
            generate = options.get("generate")
            if not generate:
                raise ValueError("duplicates tag requires generate() option")

            # Count duplicates for each observation
            dup_counts = self.data.df.loc[mask].groupby(
                existing_vars
            ).transform("size")
            self.data.df[generate] = 0
            self.data.df.loc[mask, generate] = dup_counts - 1

        elif subcmd == "drop":
            # Drop duplicates
            force = options.get("force", False)

            # Keep first occurrence
            keep_mask = ~self.data.df.duplicated(subset=existing_vars, keep="first")
            keep_mask = keep_mask | ~mask  # Don't drop rows outside if/in

            self.data.df = self.data.df.loc[keep_mask].reset_index(drop=True)

        elif subcmd == "list":
            # List duplicates
            dup_mask = self.data.df.duplicated(subset=existing_vars, keep=False)
            combined_mask = dup_mask & mask

            self.interp.output(self.data.df.loc[combined_mask].to_string())

    def cmd_isid(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Check for unique identifiers.

        Syntax: isid varlist [if] [in] [, sort missok]
        """
        options = options or {}

        varlist = [str(a) for a in args]

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)
        df = self.data.df.loc[mask]

        existing_vars = [v for v in varlist if v in df.columns]

        missok = options.get("missok", False)

        # Check for missing values
        if not missok:
            for var in existing_vars:
                if df[var].isna().any():
                    raise ValueError(f"variable {var} has missing values")

        # Check for duplicates
        if df.duplicated(subset=existing_vars).any():
            raise ValueError(
                f"variables {' '.join(existing_vars)} do not uniquely identify observations"
            )

    def cmd_distinct(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Report distinct values.

        Syntax: distinct [varlist] [if] [in]
        """
        options = options or {}

        varlist = [str(a) for a in args] if args else list(self.data.df.columns)

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)
        df = self.data.df.loc[mask]

        existing_vars = [v for v in varlist if v in df.columns]

        n_distinct = len(df[existing_vars].drop_duplicates())
        n_total = len(df)

        self.macros.set_return("ndistinct", n_distinct)
        self.macros.set_return("N", n_total)

        self.interp.output(f"Distinct observations: {n_distinct}")
        self.interp.output(f"Total observations: {n_total}")

    def cmd_levelsof(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Get levels of a variable.

        Syntax: levelsof varname [if] [in] [, options]
        """
        options = options or {}

        if not args:
            raise ValueError("levelsof requires variable name")

        varname = str(args[0])

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)
        values = self.data.df.loc[mask, varname]

        clean = options.get("clean", False)
        local_name = options.get("local", "levels")
        separate = options.get("separate", " ")
        missing = options.get("missing", False)

        # Get unique values
        if missing:
            unique_vals = values.unique()
        else:
            unique_vals = values.dropna().unique()

        unique_vals = sorted(unique_vals, key=lambda x: (pd.isna(x), x))

        # Format as string
        if self.data.is_string(varname):
            if clean:
                levels_str = separate.join(str(v) for v in unique_vals if pd.notna(v))
            else:
                levels_str = separate.join(
                    f'"{v}"' for v in unique_vals if pd.notna(v)
                )
        else:
            levels_str = separate.join(str(int(v)) for v in unique_vals if pd.notna(v))

        # Store in local
        self.macros.set_local(local_name, levels_str)

        # Store in r()
        self.macros.set_return("levels", levels_str)
        self.macros.set_return("r", len(unique_vals))

    def cmd_tabulate(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Tabulate frequencies.

        Syntax: tabulate varname [if] [in] [, options]
               tabulate varname1 varname2 [if] [in] [, options]
        """
        options = options or {}

        if not args:
            raise ValueError("tabulate requires variable name")

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)

        if len(args) == 1:
            # One-way tabulation
            self._tabulate_oneway(str(args[0]), mask, options)
        else:
            # Two-way tabulation
            self._tabulate_twoway(str(args[0]), str(args[1]), mask, options)

    def _tabulate_oneway(
        self, varname: str, mask: pd.Series, options: dict
    ) -> None:
        """One-way tabulation."""
        if varname not in self.data.df.columns:
            raise ValueError(f"variable {varname} not found")

        values = self.data.df.loc[mask, varname]

        missing = options.get("missing", False)
        sort_opt = options.get("sort", False)

        # Count frequencies
        if missing:
            counts = values.value_counts(dropna=False)
        else:
            counts = values.value_counts(dropna=True)

        if sort_opt:
            counts = counts.sort_values(ascending=False)
        else:
            counts = counts.sort_index()

        total = counts.sum()

        # Store results
        self.macros.set_return("N", int(total))
        self.macros.set_return("r", len(counts))

        # Display
        output_lines = [f"\n{varname} |      Freq.     Percent        Cum."]
        output_lines.append("-" * 50)

        cum = 0
        for val, count in counts.items():
            cum += count
            pct = count / total * 100
            cum_pct = cum / total * 100
            val_str = str(val) if pd.notna(val) else "."
            output_lines.append(f"{val_str:>10} | {count:>10} {pct:>10.2f} {cum_pct:>10.2f}")

        output_lines.append("-" * 50)
        output_lines.append(f"{'Total':>10} | {total:>10} {100.00:>10.2f}")

        self.interp.output("\n".join(output_lines))

    def _tabulate_twoway(
        self, var1: str, var2: str, mask: pd.Series, options: dict
    ) -> None:
        """Two-way tabulation."""
        if var1 not in self.data.df.columns:
            raise ValueError(f"variable {var1} not found")
        if var2 not in self.data.df.columns:
            raise ValueError(f"variable {var2} not found")

        df = self.data.df.loc[mask]

        # Create cross-tabulation
        crosstab = pd.crosstab(df[var1], df[var2], margins=True)

        # Store results
        self.macros.set_return("N", int(crosstab.loc["All", "All"]))
        self.macros.set_return("r", len(crosstab) - 1)
        self.macros.set_return("c", len(crosstab.columns) - 1)

        self.interp.output(f"\n{var1} by {var2}")
        self.interp.output(crosstab.to_string())

    def cmd_table(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        General table command.

        Syntax: table rowvar [colvar [supercolvar]] [if] [in] [, options]
        """
        options = options or {}

        if not args:
            raise ValueError("table requires variable name")

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)
        df = self.data.df.loc[mask]

        row_var = str(args[0])
        col_var = str(args[1]) if len(args) > 1 else None

        contents = options.get("contents", options.get("c", "freq"))

        if col_var:
            # Two-way table
            if contents == "freq":
                result = pd.crosstab(df[row_var], df[col_var])
            else:
                # Parse contents for stat var
                parts = contents.split()
                if len(parts) >= 2:
                    stat = parts[0]
                    stat_var = parts[1]
                    result = pd.pivot_table(
                        df, values=stat_var, index=row_var, columns=col_var, aggfunc=stat
                    )
                else:
                    result = pd.crosstab(df[row_var], df[col_var])
        else:
            # One-way table
            if contents == "freq":
                result = df[row_var].value_counts().to_frame()
            else:
                parts = contents.split()
                if len(parts) >= 2:
                    stat = parts[0]
                    stat_var = parts[1]
                    result = df.groupby(row_var)[stat_var].agg(stat).to_frame()
                else:
                    result = df[row_var].value_counts().to_frame()

        self.interp.output(result.to_string())
