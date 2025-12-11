"""
Data Manipulation Commands

Implements:
- generate/gen: Create new variable
- replace: Replace values in existing variable
- drop: Drop variables or observations
- keep: Keep variables or observations
- rename: Rename variable
- clonevar: Clone variable with labels
- encode/decode: Convert between string and numeric
- destring/tostring: Convert variable types
- label: Variable and value labels
- recode: Recode values
- egen: Extended generate functions
"""

import re
import numpy as np
import pandas as pd
from typing import Optional


class DataManipCommands:
    """Data manipulation command implementations."""

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
    def expr_eval(self):
        return self.interp.expr_eval

    @property
    def cond_eval(self):
        return self.interp.cond_eval

    def cmd_generate(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Generate a new variable.

        Syntax: generate [type] newvar = exp [if] [in]
        """
        options = options or {}

        # Parse arguments: [type] newvar = expression
        # Join args back to string for parsing
        arg_str = " ".join(str(a) for a in args)

        # Check for type specification
        var_type = None
        type_match = re.match(
            r"^(byte|int|long|float|double|str\d*)\s+", arg_str, re.IGNORECASE
        )
        if type_match:
            var_type = type_match.group(1).lower()
            arg_str = arg_str[type_match.end() :]

        # Parse newvar = expression
        if "=" not in arg_str:
            raise ValueError("generate requires newvar = expression")

        parts = arg_str.split("=", 1)
        new_var = parts[0].strip()
        expression = parts[1].strip()

        # Check if variable already exists
        if self.data.has_var(new_var):
            raise ValueError(f"variable {new_var} already defined")

        # Evaluate expression
        result = self.expr_eval.evaluate(expression)

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)

        # Create variable
        if isinstance(result, pd.Series):
            # Result is already a Series
            new_values = pd.Series(index=range(self.data.N), dtype=float)
            new_values.loc[mask] = result.loc[mask]
        else:
            # Scalar result
            new_values = pd.Series([np.nan] * self.data.N)
            new_values.loc[mask] = result

        # Convert type if specified
        if var_type:
            new_values = self._convert_type(new_values, var_type)

        self.data.set_var(new_var, new_values)

    def cmd_replace(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Replace values in existing variable.

        Syntax: replace oldvar = exp [if] [in]
        """
        options = options or {}

        # Join args back to string for parsing
        arg_str = " ".join(str(a) for a in args)

        # Parse var = expression
        if "=" not in arg_str:
            raise ValueError("replace requires var = expression")

        parts = arg_str.split("=", 1)
        var_name = parts[0].strip()
        expression = parts[1].strip()

        # Check variable exists
        if not self.data.has_var(var_name):
            raise ValueError(f"variable {var_name} not found")

        # Evaluate expression
        result = self.expr_eval.evaluate(expression)

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)

        # Get existing variable
        current = self.data.get_var(var_name).copy()

        # Replace values where mask is True
        if isinstance(result, pd.Series):
            current.loc[mask] = result.loc[mask]
        else:
            current.loc[mask] = result

        self.data.set_var(var_name, current)

    def cmd_drop(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Drop variables or observations.

        Syntax: drop varlist
               drop if condition
               drop in range
        """
        options = options or {}

        # Check if dropping observations or variables
        if if_cond or in_range:
            # Drop observations
            mask = self.cond_eval.evaluate_combined(if_cond, in_range)
            self.data.drop_obs(mask)
        elif args:
            # Drop variables
            vars_to_drop = self._expand_varlist(args)
            self.data.drop_var(vars_to_drop)
        else:
            raise ValueError("drop requires varlist or if/in condition")

    def cmd_keep(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Keep variables or observations.

        Syntax: keep varlist
               keep if condition
               keep in range
        """
        options = options or {}

        # Check if keeping observations or variables
        if if_cond or in_range:
            # Keep observations
            mask = self.cond_eval.evaluate_combined(if_cond, in_range)
            self.data.keep_obs(mask)
        elif args:
            # Keep variables
            vars_to_keep = self._expand_varlist(args)
            self.data.keep_vars(vars_to_keep)
        else:
            raise ValueError("keep requires varlist or if/in condition")

    def cmd_rename(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Rename variable(s).

        Syntax: rename oldvar newvar
               rename (varlist) (newnames)
        """
        options = options or {}

        # Simple rename
        if len(args) == 2:
            old_name = str(args[0])
            new_name = str(args[1])
            self.data.rename_var(old_name, new_name)
        else:
            raise ValueError("rename requires exactly 2 arguments")

    def cmd_clonevar(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Clone variable including labels.

        Syntax: clonevar newvar = oldvar
        """
        options = options or {}

        arg_str = " ".join(str(a) for a in args)

        if "=" not in arg_str:
            raise ValueError("clonevar requires newvar = oldvar")

        parts = arg_str.split("=", 1)
        new_var = parts[0].strip()
        old_var = parts[1].strip()

        if not self.data.has_var(old_var):
            raise ValueError(f"variable {old_var} not found")

        if self.data.has_var(new_var):
            raise ValueError(f"variable {new_var} already defined")

        # Copy values
        self.data.set_var(new_var, self.data.get_var(old_var).copy())

        # Copy metadata
        label = self.data.get_var_label(old_var)
        if label:
            self.data.set_var_label(new_var, label)

        fmt = self.data.get_var_format(old_var)
        self.data.set_var_format(new_var, fmt)

    def cmd_encode(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Encode string variable as numeric with value labels.

        Syntax: encode varname, generate(newvar) [label(name)]
        """
        options = options or {}

        if not args:
            raise ValueError("encode requires variable name")

        var_name = str(args[0])
        if not self.data.has_var(var_name):
            raise ValueError(f"variable {var_name} not found")

        new_var = options.get("generate", options.get("gen"))
        if not new_var:
            raise ValueError("encode requires generate() option")

        label_name = options.get("label", new_var)

        # Get unique values
        values = self.data.get_var(var_name)
        unique_vals = values.dropna().unique()

        # Create mapping
        vl = self.data.define_value_label(label_name)
        value_map = {}
        for i, val in enumerate(sorted(unique_vals), 1):
            vl.define(i, str(val))
            value_map[val] = i

        # Create encoded variable
        encoded = values.map(value_map)
        self.data.set_var(new_var, encoded)
        self.data.label_values(new_var, label_name)

    def cmd_decode(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Decode numeric variable to string using value labels.

        Syntax: decode varname, generate(newvar)
        """
        options = options or {}

        if not args:
            raise ValueError("decode requires variable name")

        var_name = str(args[0])
        if not self.data.has_var(var_name):
            raise ValueError(f"variable {var_name} not found")

        new_var = options.get("generate", options.get("gen"))
        if not new_var:
            raise ValueError("decode requires generate() option")

        # Get value label name
        label_name = self.data._var_value_labels.get(var_name)
        if not label_name or label_name not in self.data._value_labels:
            raise ValueError(f"variable {var_name} has no value labels")

        vl = self.data._value_labels[label_name]
        values = self.data.get_var(var_name)

        # Decode
        decoded = values.apply(lambda x: vl.get_label(int(x)) if pd.notna(x) else np.nan)
        self.data.set_var(new_var, decoded)

    def cmd_destring(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Convert string to numeric.

        Syntax: destring varlist, {generate(newvarlist) | replace} [options]
        """
        options = options or {}
        vars_to_convert = self._expand_varlist(args)

        generate = options.get("generate", options.get("gen"))
        replace = options.get("replace", False)
        force = options.get("force", False)
        ignore = options.get("ignore", "")

        if not generate and not replace:
            raise ValueError("destring requires generate() or replace option")

        for i, var in enumerate(vars_to_convert):
            values = self.data.get_var(var).astype(str)

            # Remove ignored characters
            if ignore:
                for char in ignore:
                    values = values.str.replace(char, "", regex=False)

            # Convert to numeric
            numeric = pd.to_numeric(values, errors="coerce")

            if generate:
                # Get target variable name
                if isinstance(generate, str):
                    gen_vars = generate.split()
                    new_var = gen_vars[i] if i < len(gen_vars) else f"{var}_num"
                else:
                    new_var = f"{var}_num"
                self.data.set_var(new_var, numeric)
            else:
                self.data.set_var(var, numeric)

    def cmd_tostring(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Convert numeric to string.

        Syntax: tostring varlist, {generate(newvarlist) | replace} [options]
        """
        options = options or {}
        vars_to_convert = self._expand_varlist(args)

        generate = options.get("generate", options.get("gen"))
        replace = options.get("replace", False)
        force = options.get("force", False)
        format_opt = options.get("format")

        if not generate and not replace:
            raise ValueError("tostring requires generate() or replace option")

        for i, var in enumerate(vars_to_convert):
            values = self.data.get_var(var)

            # Convert to string
            if format_opt:
                # Apply format
                string_vals = values.apply(
                    lambda x: format(x, format_opt) if pd.notna(x) else ""
                )
            else:
                string_vals = values.astype(str).replace("nan", "")

            if generate:
                if isinstance(generate, str):
                    gen_vars = generate.split()
                    new_var = gen_vars[i] if i < len(gen_vars) else f"{var}_str"
                else:
                    new_var = f"{var}_str"
                self.data.set_var(new_var, string_vals)
            else:
                self.data.set_var(var, string_vals)

    def cmd_label(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Label commands.

        Syntax: label variable varname "label"
               label values varname labelname
               label define labelname value "label" [value "label" ...]
               label data "label"
               label list [labelname]
        """
        options = options or {}

        if not args:
            raise ValueError("label requires subcommand")

        subcmd = str(args[0]).lower()
        rest = args[1:]

        if subcmd in ("var", "variable"):
            # label variable varname "label"
            if len(rest) < 2:
                raise ValueError('label variable requires varname "label"')
            var_name = str(rest[0])
            label = " ".join(str(r) for r in rest[1:]).strip('"')
            self.data.set_var_label(var_name, label)

        elif subcmd == "values":
            # label values varname labelname
            if len(rest) < 2:
                raise ValueError("label values requires varname labelname")
            var_name = str(rest[0])
            label_name = str(rest[1])
            self.data.label_values(var_name, label_name)

        elif subcmd == "define":
            # label define labelname value "label" ...
            if len(rest) < 3:
                raise ValueError('label define requires labelname value "label"')
            label_name = str(rest[0])
            vl = self.data.define_value_label(label_name)

            # Parse value label pairs
            i = 1
            while i < len(rest) - 1:
                try:
                    value = int(rest[i])
                    label = str(rest[i + 1]).strip('"')
                    vl.define(value, label)
                    i += 2
                except (ValueError, IndexError):
                    break

        elif subcmd == "data":
            # label data "label" - data label (not implemented)
            pass

        elif subcmd == "list":
            # label list - display labels (not implemented)
            pass

    def cmd_recode(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
    ) -> None:
        """
        Recode variable values.

        Syntax: recode varname (rule1) (rule2) ... [, generate(newvar)]
        """
        options = options or {}

        if not args:
            raise ValueError("recode requires variable name")

        # Parse variable and rules
        var_name = str(args[0])
        rules_str = " ".join(str(a) for a in args[1:])

        if not self.data.has_var(var_name):
            raise ValueError(f"variable {var_name} not found")

        generate = options.get("generate", options.get("gen"))

        # Parse rules
        rules = re.findall(r"\(([^)]+)\)", rules_str)

        values = self.data.get_var(var_name).copy()

        for rule in rules:
            # Parse rule: oldval = newval or min/max = newval
            if "=" in rule:
                parts = rule.split("=")
                old_part = parts[0].strip()
                new_val = float(parts[1].strip())

                # Handle ranges
                if "/" in old_part:
                    range_parts = old_part.split("/")
                    low = float(range_parts[0]) if range_parts[0] != "min" else -np.inf
                    high = float(range_parts[1]) if range_parts[1] != "max" else np.inf
                    mask = (values >= low) & (values <= high)
                else:
                    # Single value
                    old_val = float(old_part)
                    mask = values == old_val

                values.loc[mask] = new_val

        if generate:
            self.data.set_var(generate, values)
        else:
            self.data.set_var(var_name, values)

    def cmd_egen(
        self,
        args: list,
        if_cond: Optional[str] = None,
        in_range: Optional[tuple] = None,
        options: dict = None,
        by_vars: list = None,
    ) -> None:
        """
        Extended generate functions.

        Syntax: egen [type] newvar = fcn(arguments) [if] [in] [, options]
        """
        options = options or {}

        arg_str = " ".join(str(a) for a in args)

        # Check for type specification
        var_type = None
        type_match = re.match(
            r"^(byte|int|long|float|double)\s+", arg_str, re.IGNORECASE
        )
        if type_match:
            var_type = type_match.group(1).lower()
            arg_str = arg_str[type_match.end() :]

        # Parse newvar = function(args)
        if "=" not in arg_str:
            raise ValueError("egen requires newvar = fcn(arguments)")

        parts = arg_str.split("=", 1)
        new_var = parts[0].strip()
        func_str = parts[1].strip()

        # Parse function call
        func_match = re.match(r"(\w+)\s*\(([^)]*)\)", func_str)
        if not func_match:
            raise ValueError(f"invalid egen function: {func_str}")

        func_name = func_match.group(1).lower()
        func_args = func_match.group(2).strip()

        # Apply if/in conditions
        mask = self.cond_eval.evaluate_combined(if_cond, in_range)

        # Execute egen function
        result = self._egen_function(func_name, func_args, mask, by_vars, options)

        if var_type:
            result = self._convert_type(result, var_type)

        self.data.set_var(new_var, result)

    def _egen_function(
        self, func: str, args: str, mask: pd.Series, by_vars: list, options: dict
    ) -> pd.Series:
        """Execute an egen function."""
        # Parse variable list from args
        var_list = [v.strip() for v in args.split() if v.strip()]

        if func == "mean":
            return self._egen_stat(var_list[0], mask, by_vars, "mean")
        elif func == "sum" or func == "total":
            return self._egen_stat(var_list[0], mask, by_vars, "sum")
        elif func == "count":
            return self._egen_stat(var_list[0], mask, by_vars, "count")
        elif func == "min":
            return self._egen_stat(var_list[0], mask, by_vars, "min")
        elif func == "max":
            return self._egen_stat(var_list[0], mask, by_vars, "max")
        elif func == "sd":
            return self._egen_stat(var_list[0], mask, by_vars, "std")
        elif func in ("rowtotal", "rowsum"):
            return self._egen_rowtotal(var_list, mask)
        elif func in ("rowmean", "rowavg"):
            return self._egen_rowmean(var_list, mask)
        elif func in ("rowmin", "rowmax"):
            return self._egen_rowminmax(var_list, mask, func)
        elif func == "rownonmiss":
            return self._egen_rownonmiss(var_list, mask)
        elif func == "concat":
            return self._egen_concat(var_list, mask, options)
        elif func == "group":
            return self._egen_group(var_list, mask, by_vars)
        elif func == "rank":
            return self._egen_rank(var_list[0], mask, by_vars, options)
        elif func == "seq":
            return self._egen_seq(mask, by_vars, options)
        elif func == "tag":
            return self._egen_tag(var_list, mask, by_vars)
        else:
            raise ValueError(f"egen function {func} not implemented")

    def _egen_stat(
        self, var: str, mask: pd.Series, by_vars: list, stat: str
    ) -> pd.Series:
        """Compute statistic, optionally by group."""
        values = self.data.get_var(var).copy()
        values.loc[~mask] = np.nan

        if by_vars:
            grouped = self.data.df.groupby(by_vars)[var]
            if stat == "mean":
                return grouped.transform("mean")
            elif stat == "sum":
                return grouped.transform("sum")
            elif stat == "count":
                return grouped.transform("count")
            elif stat == "min":
                return grouped.transform("min")
            elif stat == "max":
                return grouped.transform("max")
            elif stat == "std":
                return grouped.transform("std")
        else:
            if stat == "mean":
                return pd.Series([values.mean()] * self.data.N)
            elif stat == "sum":
                return pd.Series([values.sum()] * self.data.N)
            elif stat == "count":
                return pd.Series([values.count()] * self.data.N)
            elif stat == "min":
                return pd.Series([values.min()] * self.data.N)
            elif stat == "max":
                return pd.Series([values.max()] * self.data.N)
            elif stat == "std":
                return pd.Series([values.std()] * self.data.N)

        return pd.Series([np.nan] * self.data.N)

    def _egen_rowtotal(self, vars: list, mask: pd.Series) -> pd.Series:
        """Row-wise total."""
        existing = [v for v in vars if self.data.has_var(v)]
        df = self.data.df[existing]
        result = df.sum(axis=1)
        result.loc[~mask] = np.nan
        return result

    def _egen_rowmean(self, vars: list, mask: pd.Series) -> pd.Series:
        """Row-wise mean."""
        existing = [v for v in vars if self.data.has_var(v)]
        df = self.data.df[existing]
        result = df.mean(axis=1)
        result.loc[~mask] = np.nan
        return result

    def _egen_rowminmax(self, vars: list, mask: pd.Series, func: str) -> pd.Series:
        """Row-wise min or max."""
        existing = [v for v in vars if self.data.has_var(v)]
        df = self.data.df[existing]
        if func == "rowmin":
            result = df.min(axis=1)
        else:
            result = df.max(axis=1)
        result.loc[~mask] = np.nan
        return result

    def _egen_rownonmiss(self, vars: list, mask: pd.Series) -> pd.Series:
        """Count non-missing values per row."""
        existing = [v for v in vars if self.data.has_var(v)]
        df = self.data.df[existing]
        result = df.notna().sum(axis=1)
        result.loc[~mask] = np.nan
        return result

    def _egen_concat(
        self, vars: list, mask: pd.Series, options: dict
    ) -> pd.Series:
        """Concatenate string variables."""
        punct = options.get("punct", "")
        existing = [v for v in vars if self.data.has_var(v)]

        df = self.data.df[existing].astype(str)
        result = df.apply(lambda row: punct.join(row), axis=1)
        result.loc[~mask] = np.nan
        return result

    def _egen_group(
        self, vars: list, mask: pd.Series, by_vars: list
    ) -> pd.Series:
        """Create group identifier."""
        existing = [v for v in vars if self.data.has_var(v)]

        # Create unique groups
        group_cols = by_vars + existing if by_vars else existing
        existing_cols = [c for c in group_cols if self.data.has_var(c)]

        if existing_cols:
            codes, _ = pd.factorize(
                self.data.df[existing_cols].apply(tuple, axis=1)
            )
            result = pd.Series(codes + 1)
        else:
            result = pd.Series([1] * self.data.N)

        result.loc[~mask] = np.nan
        return result

    def _egen_rank(
        self, var: str, mask: pd.Series, by_vars: list, options: dict
    ) -> pd.Series:
        """Compute ranks."""
        values = self.data.get_var(var).copy()

        if by_vars:
            result = self.data.df.groupby(by_vars)[var].rank()
        else:
            result = values.rank()

        result.loc[~mask] = np.nan
        return result

    def _egen_seq(
        self, mask: pd.Series, by_vars: list, options: dict
    ) -> pd.Series:
        """Generate sequential numbers."""
        if by_vars:
            result = self.data.df.groupby(by_vars).cumcount() + 1
        else:
            result = pd.Series(range(1, self.data.N + 1))

        result = result.astype(float)
        result.loc[~mask] = np.nan
        return result

    def _egen_tag(
        self, vars: list, mask: pd.Series, by_vars: list
    ) -> pd.Series:
        """Tag first occurrence in group."""
        existing = [v for v in vars if self.data.has_var(v)]
        group_cols = by_vars + existing if by_vars else existing
        existing_cols = [c for c in group_cols if self.data.has_var(c)]

        if existing_cols:
            result = (~self.data.df.duplicated(subset=existing_cols)).astype(int)
        else:
            result = pd.Series([1] + [0] * (self.data.N - 1))

        result.loc[~mask] = 0
        return result

    def _expand_varlist(self, args: list) -> list:
        """Expand variable list with wildcards."""
        result = []
        for arg in args:
            arg = str(arg)
            if "*" in arg or "?" in arg:
                # Wildcard pattern
                pattern = arg.replace("*", ".*").replace("?", ".")
                pattern = f"^{pattern}$"
                for var in self.data.varlist:
                    if re.match(pattern, var):
                        result.append(var)
            elif "-" in arg and not arg.startswith("-"):
                # Variable range
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

    def _convert_type(self, values: pd.Series, var_type: str) -> pd.Series:
        """Convert values to specified Stata type."""
        if var_type == "byte":
            return values.astype("Int8")
        elif var_type == "int":
            return values.astype("Int16")
        elif var_type == "long":
            return values.astype("Int32")
        elif var_type == "float":
            return values.astype("float32")
        elif var_type == "double":
            return values.astype("float64")
        elif var_type.startswith("str"):
            return values.astype(str)
        return values
