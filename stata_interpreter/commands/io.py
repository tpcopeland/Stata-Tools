"""
I/O Commands

Implements:
- use: Load data
- save: Save data
- import delimited: Import CSV/delimited files
- export delimited: Export to CSV/delimited
- clear: Clear data from memory
- describe: Describe data
- summarize: Summarize variables
- list: List observations
- count: Count observations
- display: Display text/values
- set obs: Set number of observations
"""

import os
import numpy as np
import pandas as pd
from typing import Optional


class IOCommands:
    """I/O command implementations."""

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

    def cmd_use(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
        using: Optional[str] = None,
    ) -> None:
        """
        Load data from file.

        Syntax: use [varlist] [if] [in] using filename [, clear]
               use filename [, clear]
        """
        options = options or {}

        # Determine filename
        if using:
            filename = using
            varlist = [str(a) for a in args] if args else None
        elif args:
            # Reconstruct filename from split args (path/file.dta may be split)
            filename = "".join(str(a) for a in args).strip('"')
            varlist = None
        else:
            raise ValueError("use requires filename")

        # Clean up filename
        filename = filename.strip('"').strip("'")

        # Add .dta extension if not present
        if not filename.endswith((".dta", ".csv", ".xlsx", ".xls")):
            filename = f"{filename}.dta"

        clear = options.get("clear", False)

        # Check if data in memory
        if self.data.N > 0 and not clear:
            raise ValueError("no; data in memory would be lost")

        # Load based on file type
        if filename.endswith(".dta"):
            self._load_dta(filename, varlist, if_cond, in_range)
        elif filename.endswith(".csv"):
            self._load_csv(filename, varlist, if_cond, in_range)
        elif filename.endswith((".xlsx", ".xls")):
            self._load_excel(filename, varlist, if_cond, in_range, options)
        else:
            raise ValueError(f"unsupported file format: {filename}")

    def _load_dta(
        self,
        filename: str,
        varlist: Optional[list],
        if_cond: Optional[str],
        in_range: Optional[tuple],
    ) -> None:
        """Load Stata .dta file."""
        try:
            # Use pandas to read .dta
            df = pd.read_stata(filename, convert_categoricals=False)

            # Select variables
            if varlist:
                existing = [v for v in varlist if v in df.columns]
                df = df[existing]

            self.data.clear()
            self.data.df = df

            # Try to read labels
            try:
                reader = pd.io.stata.StataReader(filename)
                for var in df.columns:
                    label = reader.variable_labels().get(var, "")
                    if label:
                        self.data.set_var_label(var, label)
            except Exception:
                pass

        except FileNotFoundError:
            raise ValueError(f"file {filename} not found")

    def _load_csv(
        self,
        filename: str,
        varlist: Optional[list],
        if_cond: Optional[str],
        in_range: Optional[tuple],
    ) -> None:
        """Load CSV file."""
        try:
            df = pd.read_csv(filename)

            if varlist:
                existing = [v for v in varlist if v in df.columns]
                df = df[existing]

            self.data.clear()
            self.data.df = df

        except FileNotFoundError:
            raise ValueError(f"file {filename} not found")

    def _load_excel(
        self,
        filename: str,
        varlist: Optional[list],
        if_cond: Optional[str],
        in_range: Optional[tuple],
        options: dict,
    ) -> None:
        """Load Excel file."""
        try:
            sheet = options.get("sheet")
            df = pd.read_excel(filename, sheet_name=sheet)

            if varlist:
                existing = [v for v in varlist if v in df.columns]
                df = df[existing]

            self.data.clear()
            self.data.df = df

        except FileNotFoundError:
            raise ValueError(f"file {filename} not found")

    def cmd_save(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
        using: Optional[str] = None,
    ) -> None:
        """
        Save data to file.

        Syntax: save filename [, replace]
        """
        options = options or {}

        if using:
            filename = using
        elif args:
            # Reconstruct filename from split args (path/file.dta may be split)
            filename = "".join(str(a) for a in args).strip('"')
        else:
            raise ValueError("save requires filename")

        filename = filename.strip('"').strip("'")

        # Add .dta extension if not present
        if not filename.endswith((".dta", ".csv", ".xlsx")):
            filename = f"{filename}.dta"

        replace = options.get("replace", False)

        # Check if file exists
        if os.path.exists(filename) and not replace:
            raise ValueError(f"file {filename} already exists")

        # Save based on file type
        if filename.endswith(".dta"):
            self._save_dta(filename)
        elif filename.endswith(".csv"):
            self._save_csv(filename)
        elif filename.endswith(".xlsx"):
            self._save_excel(filename)

    def _save_dta(self, filename: str) -> None:
        """Save as Stata .dta file."""
        # Create variable labels dict
        var_labels = {}
        for var in self.data.varlist:
            label = self.data.get_var_label(var)
            if label:
                var_labels[var] = label

        self.data.df.to_stata(
            filename, write_index=False, variable_labels=var_labels
        )

    def _save_csv(self, filename: str) -> None:
        """Save as CSV file."""
        self.data.df.to_csv(filename, index=False)

    def _save_excel(self, filename: str) -> None:
        """Save as Excel file."""
        self.data.df.to_excel(filename, index=False)

    def cmd_import(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
        using: Optional[str] = None,
    ) -> None:
        """
        Import data.

        Syntax: import delimited [using] filename [, options]
               import excel [using] filename [, options]
        """
        options = options or {}

        if not args:
            raise ValueError("import requires subcommand")

        subcmd = str(args[0]).lower()
        rest = args[1:]

        if using:
            filename = using
        elif rest:
            filename = str(rest[0]).strip('"')
        else:
            raise ValueError("import requires filename")

        clear = options.get("clear", False)
        if self.data.N > 0 and not clear:
            raise ValueError("no; data in memory would be lost")

        if subcmd == "delimited":
            self._import_delimited(filename, options)
        elif subcmd == "excel":
            self._import_excel(filename, options)
        else:
            raise ValueError(f"unknown import type: {subcmd}")

    def _import_delimited(self, filename: str, options: dict) -> None:
        """Import delimited file."""
        delimiter = options.get("delimiter", options.get("delim", ","))
        if delimiter == "tab":
            delimiter = "\t"
        elif delimiter == "comma":
            delimiter = ","

        varnames = options.get("varnames")
        if varnames == "1" or varnames == 1:
            header = 0
        elif varnames == "nonames":
            header = None
        else:
            header = 0

        encoding = options.get("encoding", "utf-8")

        try:
            df = pd.read_csv(
                filename, delimiter=delimiter, header=header, encoding=encoding
            )
            self.data.clear()
            self.data.df = df
        except Exception as e:
            raise ValueError(f"error importing {filename}: {e}")

    def _import_excel(self, filename: str, options: dict) -> None:
        """Import Excel file."""
        sheet = options.get("sheet")
        firstrow = options.get("firstrow", 1)

        try:
            df = pd.read_excel(
                filename, sheet_name=sheet, header=firstrow - 1 if firstrow else 0
            )
            self.data.clear()
            self.data.df = df
        except Exception as e:
            raise ValueError(f"error importing {filename}: {e}")

    def cmd_export(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
        using: Optional[str] = None,
    ) -> None:
        """
        Export data.

        Syntax: export delimited [varlist] using filename [, options]
               export excel [varlist] using filename [, options]
        """
        options = options or {}

        if not args:
            raise ValueError("export requires subcommand")

        subcmd = str(args[0]).lower()

        if using:
            filename = using
        else:
            raise ValueError("export requires using filename")

        replace = options.get("replace", False)
        if os.path.exists(filename) and not replace:
            raise ValueError(f"file {filename} already exists")

        if subcmd == "delimited":
            self._export_delimited(filename, options)
        elif subcmd == "excel":
            self._export_excel(filename, options)
        else:
            raise ValueError(f"unknown export type: {subcmd}")

    def _export_delimited(self, filename: str, options: dict) -> None:
        """Export to delimited file."""
        delimiter = options.get("delimiter", options.get("delim", ","))
        if delimiter == "tab":
            delimiter = "\t"

        quote = options.get("quote", False)

        self.data.df.to_csv(
            filename, sep=delimiter, index=False, quoting=1 if quote else 0
        )

    def _export_excel(self, filename: str, options: dict) -> None:
        """Export to Excel file."""
        sheet = options.get("sheet", "Sheet1")
        firstrow = options.get("firstrow", 1)

        self.data.df.to_excel(
            filename, sheet_name=sheet, startrow=firstrow - 1, index=False
        )

    def cmd_clear(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Clear data from memory.

        Syntax: clear [all]
        """
        clear_all = "all" in [str(a).lower() for a in args] if args else False

        self.data.clear()

        if clear_all:
            self.macros.clear_locals()
            self.macros.clear_return()
            self.macros.clear_temps()

    def cmd_describe(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Describe data.

        Syntax: describe [varlist] [, short simple]
        """
        options = options or {}
        short = options.get("short", False)
        simple = options.get("simple", False)

        # Store results in r()
        self.macros.set_return("N", self.data.N)
        self.macros.set_return("k", len(self.data.varlist))

        output = self.data.describe()
        self.interp.output(output)

    def cmd_summarize(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Summarize variables.

        Syntax: summarize [varlist] [if] [in] [, detail]
        """
        options = options or {}
        detail = options.get("detail", options.get("d", False))

        varlist = [str(a) for a in args] if args else self.data.varlist

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)

        for var in varlist:
            if not self.data.has_var(var):
                continue
            if not self.data.is_numeric(var):
                continue

            values = self.data.get_var(var).loc[mask]
            stats = {
                "N": values.count(),
                "mean": values.mean(),
                "sd": values.std(),
                "min": values.min(),
                "max": values.max(),
                "sum": values.sum(),
            }

            if detail:
                stats["p1"] = values.quantile(0.01)
                stats["p5"] = values.quantile(0.05)
                stats["p10"] = values.quantile(0.10)
                stats["p25"] = values.quantile(0.25)
                stats["p50"] = values.quantile(0.50)
                stats["p75"] = values.quantile(0.75)
                stats["p90"] = values.quantile(0.90)
                stats["p95"] = values.quantile(0.95)
                stats["p99"] = values.quantile(0.99)
                stats["skewness"] = values.skew()
                stats["kurtosis"] = values.kurtosis()

            # Store in r()
            for name, value in stats.items():
                if pd.notna(value):
                    self.macros.set_return(name, float(value))

            # Output
            output = f"\nVariable: {var}\n"
            output += f"  Obs: {stats['N']}\n"
            output += f"  Mean: {stats['mean']:.4f}\n"
            output += f"  Std. Dev.: {stats['sd']:.4f}\n"
            output += f"  Min: {stats['min']:.4f}\n"
            output += f"  Max: {stats['max']:.4f}\n"
            self.interp.output(output)

    def cmd_list(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        List observations.

        Syntax: list [varlist] [if] [in] [, options]
        """
        options = options or {}

        varlist = [str(a) for a in args] if args else self.data.varlist
        existing = [v for v in varlist if self.data.has_var(v)]

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)

        df = self.data.df[existing].loc[mask]

        noobs = options.get("noobs", False)

        output = df.to_string(index=not noobs)
        self.interp.output(output)

    def cmd_count(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Count observations.

        Syntax: count [if] [in]
        """
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)
        count = mask.sum()

        self.macros.set_return("N", int(count))
        self.interp.output(f"  {count}")

    def cmd_display(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Display text or expression result.

        Syntax: display [as {text|result|error}] [exp] [exp] ...
        """
        result_parts = []
        add_newline = True
        skip_next = False
        i = 0

        while i < len(args):
            if skip_next:
                skip_next = False
                i += 1
                continue

            arg_str = str(args[i])
            arg_lower = arg_str.lower()

            # Handle "as text/error/result" formatting (skip these)
            if arg_lower == "as" and i + 1 < len(args):
                next_arg = str(args[i + 1]).lower()
                if next_arg in ("text", "error", "result", "input", "txt", "err", "res"):
                    i += 2
                    continue

            # Handle special display directives
            if arg_lower == "_n":
                # Newline
                result_parts.append("\n")
                i += 1
                continue
            elif arg_lower == "_c":
                # Continue (no newline at end)
                add_newline = False
                i += 1
                continue
            elif arg_lower == "_continue":
                add_newline = False
                i += 1
                continue
            elif arg_lower == "_skip" and i + 1 < len(args):
                # Skip N lines
                try:
                    n = int(args[i + 1])
                    result_parts.append("\n" * n)
                except ValueError:
                    pass
                i += 2
                continue
            elif arg_lower == "_newline" and i + 1 < len(args):
                # Add N newlines
                try:
                    n = int(args[i + 1])
                    result_parts.append("\n" * n)
                except ValueError:
                    result_parts.append("\n")
                i += 2
                continue
            elif arg_lower.startswith("{hline") or arg_lower == "{hline}":
                # Horizontal line
                result_parts.append("-" * 60)
                i += 1
                continue
            elif arg_lower == "_col" and i + 1 < len(args):
                # Column positioning (simplified - just add spaces)
                i += 2
                continue

            # String literal
            if arg_str.startswith('"') and arg_str.endswith('"'):
                result_parts.append(arg_str[1:-1])
            elif arg_str.startswith("'") and arg_str.endswith("'"):
                result_parts.append(arg_str[1:-1])
            # Expression
            else:
                try:
                    value = self.interp.expr_eval.evaluate(arg_str, row_context=False)
                    if isinstance(value, pd.Series):
                        value = value.iloc[0] if len(value) > 0 else ""
                    result_parts.append(str(value))
                except Exception:
                    result_parts.append(arg_str)

            i += 1

        output = " ".join(result_parts)
        # Clean up multiple spaces
        while "  " in output:
            output = output.replace("  ", " ")
        self.interp.output(output)

    def cmd_set(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Set various options.

        Syntax: set option value
        """
        if not args:
            return

        setting = str(args[0]).lower()
        value = args[1] if len(args) > 1 else None

        if setting == "obs":
            if value is not None:
                n = int(value)
                self.data.set_obs(n)
        elif setting == "seed":
            if value is not None:
                np.random.seed(int(value))
        elif setting in ("more", "varabbrev", "trace"):
            # These settings are noted but don't affect Python execution
            pass

    def cmd_compress(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Compress data to save memory.

        Syntax: compress [varlist]
        """
        varlist = [str(a) for a in args] if args else self.data.varlist

        for var in varlist:
            if not self.data.has_var(var):
                continue

            col = self.data.df[var]

            if col.dtype == np.float64:
                # Try to convert to smaller types
                if col.isna().all():
                    continue

                # Check if integer
                if (col.dropna() == col.dropna().astype(int)).all():
                    min_val = col.min()
                    max_val = col.max()

                    if min_val >= -127 and max_val <= 100:
                        self.data.df[var] = col.astype("Int8")
                    elif min_val >= -32767 and max_val <= 32740:
                        self.data.df[var] = col.astype("Int16")
                    elif min_val >= -2147483647 and max_val <= 2147483620:
                        self.data.df[var] = col.astype("Int32")
                else:
                    # Try float32
                    self.data.df[var] = col.astype("float32")

    def cmd_assert(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Assert that expression is true.

        Syntax: assert exp [if] [in]
        """
        if not args:
            raise ValueError("assert requires expression")

        expr = " ".join(str(a) for a in args)

        # Evaluate expression
        result = self.interp.expr_eval.evaluate(expr)

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)

        if isinstance(result, pd.Series):
            # Check that all values are true where mask is true
            failed = (~result) & mask
            if failed.any():
                n_failed = failed.sum()
                raise AssertionError(f"assertion is false for {n_failed} observations")
        else:
            if not result:
                raise AssertionError("assertion is false")

    def cmd_format(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Set display format for variables.

        Syntax: format varlist %fmt
        Note: Display formats are not implemented - this is a stub.
        """
        # Stub - formats don't affect data manipulation
        pass

    def cmd_note(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Add notes to dataset or variables.

        Syntax: note varname: text
        Note: Notes are not implemented - this is a stub.
        """
        # Stub - notes don't affect data manipulation
        pass

    def cmd_cd(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Change directory.

        Syntax: cd "path"
        """
        if args:
            # Reconstruct path from split args
            path = "".join(str(a) for a in args).strip('"').strip("'")
            # Expand macros in path
            path = self.macros.expand(path)
            try:
                os.chdir(path)
            except FileNotFoundError:
                raise ValueError(f"directory {path} not found")
            except PermissionError:
                raise ValueError(f"cannot access directory {path}")
        else:
            # Without args, display current directory
            print(os.getcwd())

    def cmd_pwd(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Print working directory.

        Syntax: pwd
        """
        print(os.getcwd())

    def cmd_net(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Network commands.

        Syntax: net install pkgname, from(path)
                net uninstall pkgname
        Note: Network commands with URLs are not supported - only local paths.
        """
        options = options or {}

        if not args:
            return

        subcmd = str(args[0]).lower()

        if subcmd == "install":
            # Handle net install pkgname, from(path)
            from_path = options.get("from", "")
            if from_path:
                from_path = self.macros.expand(from_path)
                from_path = from_path.strip('"').strip("'")
                # Register the path for ado file search
                self.interp.add_ado_path(from_path)
        elif subcmd == "uninstall":
            # Uninstall is a no-op for now
            pass

    def cmd_confirm(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Confirm existence of items.

        Syntax: confirm file filename
                confirm variable varname
                confirm numeric variable varname
                confirm string variable varname
                confirm new variable varname
        """
        if not args:
            raise ValueError("confirm requires arguments")

        confirm_type = str(args[0]).lower()

        if confirm_type == "file":
            if len(args) < 2:
                raise ValueError("confirm file requires filename")
            # Reconstruct filename from split args
            filename = "".join(str(a) for a in args[1:]).strip('"').strip("'")
            filename = self.macros.expand(filename)
            if not os.path.exists(filename):
                raise ValueError(f'file "{filename}" not found')

        elif confirm_type == "variable":
            if len(args) < 2:
                raise ValueError("confirm variable requires varname")
            varname = str(args[1])
            if varname not in self.data.df.columns:
                raise ValueError(f"variable {varname} not found")

        elif confirm_type == "numeric":
            if len(args) < 3 or str(args[1]).lower() != "variable":
                raise ValueError("confirm numeric variable requires varname")
            varname = str(args[2])
            if varname not in self.data.df.columns:
                raise ValueError(f"variable {varname} not found")
            if not pd.api.types.is_numeric_dtype(self.data.df[varname]):
                raise ValueError(f"variable {varname} is not numeric")

        elif confirm_type == "string":
            if len(args) < 3 or str(args[1]).lower() != "variable":
                raise ValueError("confirm string variable requires varname")
            varname = str(args[2])
            if varname not in self.data.df.columns:
                raise ValueError(f"variable {varname} not found")
            if pd.api.types.is_numeric_dtype(self.data.df[varname]):
                raise ValueError(f"variable {varname} is not string")

        elif confirm_type == "new":
            if len(args) < 3 or str(args[1]).lower() != "variable":
                raise ValueError("confirm new variable requires varname")
            varname = str(args[2])
            if varname in self.data.df.columns:
                raise ValueError(f"variable {varname} already exists")

        else:
            raise ValueError(f"unknown confirm type: {confirm_type}")
