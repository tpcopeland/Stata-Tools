"""
Stata Interpreter

Main execution engine for Stata code. Handles:
- Command execution
- Control flow (foreach, forvalues, while, if/else)
- Program definitions
- Macro expansion
- By-group processing
"""

import re
import os
import sys
from typing import Optional, Callable, Any
import pandas as pd
import numpy as np

from .parser import StataParser, ParsedCommand, preprocess_stata_code
from .macros import MacroManager
from .data import StataData
from .expressions import ExpressionEvaluator, ConditionEvaluator
from .commands.data_manip import DataManipCommands
from .commands.sorting import SortingCommands
from .commands.io import IOCommands
from .commands.merging import MergingCommands
from .commands.aggregation import AggregationCommands


class StataError(Exception):
    """Stata execution error with return code."""

    def __init__(self, message: str, rc: int = 198):
        super().__init__(message)
        self.rc = rc


class StataProgram:
    """A defined Stata program."""

    def __init__(
        self,
        name: str,
        body: str,
        options: dict = None,
    ):
        self.name = name
        self.body = body
        self.options = options or {}
        self.rclass = "rclass" in self.options
        self.eclass = "eclass" in self.options
        self.sclass = "sclass" in self.options
        self.sortpreserve = "sortpreserve" in self.options
        self.byable = self.options.get("byable")


class StataInterpreter:
    """
    Main Stata interpreter.

    Executes Stata code including:
    - Data manipulation commands
    - Control flow structures
    - Program definitions and calls
    - Macro expansion
    """

    def __init__(self, quiet: bool = False):
        """
        Initialize the interpreter.

        Args:
            quiet: If True, suppress output
        """
        self.quiet = quiet
        self._output_buffer: list[str] = []

        # Initialize components
        self.data = StataData()
        self.macros = MacroManager()
        self.parser = StataParser()

        # Expression evaluators
        self.expr_eval = ExpressionEvaluator(self.data, self.macros)
        self.cond_eval = ConditionEvaluator(self.data, self.macros)

        # Connect macro evaluator
        self.macros.eval_expr = self.expr_eval.evaluate

        # User-defined programs
        self.programs: dict[str, StataProgram] = {}

        # Command handlers
        self.data_manip = DataManipCommands(self)
        self.sorting = SortingCommands(self)
        self.io = IOCommands(self)
        self.merging = MergingCommands(self)
        self.aggregation = AggregationCommands(self)

        # Execution state
        self._return_code = 0
        self._capture_mode = False
        self._quietly_mode = False
        self._preserve_stack: list[StataData] = []
        self._current_by_vars: list[str] = []
        self._current_by_sort_vars: list[str] = []

        # Build command dispatch table
        self._commands = self._build_command_table()

    def _build_command_table(self) -> dict[str, Callable]:
        """Build dispatch table mapping command names to handlers."""
        return {
            # Data manipulation
            "generate": self.data_manip.cmd_generate,
            "gen": self.data_manip.cmd_generate,
            "g": self.data_manip.cmd_generate,
            "replace": self.data_manip.cmd_replace,
            "drop": self.data_manip.cmd_drop,
            "keep": self.data_manip.cmd_keep,
            "rename": self.data_manip.cmd_rename,
            "clonevar": self.data_manip.cmd_clonevar,
            "encode": self.data_manip.cmd_encode,
            "decode": self.data_manip.cmd_decode,
            "destring": self.data_manip.cmd_destring,
            "tostring": self.data_manip.cmd_tostring,
            "label": self.data_manip.cmd_label,
            "recode": self.data_manip.cmd_recode,
            "egen": self.data_manip.cmd_egen,
            # Sorting
            "sort": self.sorting.cmd_sort,
            "gsort": self.sorting.cmd_gsort,
            "order": self.sorting.cmd_order,
            "aorder": self.sorting.cmd_aorder,
            # I/O
            "use": self.io.cmd_use,
            "save": self.io.cmd_save,
            "import": self.io.cmd_import,
            "export": self.io.cmd_export,
            "clear": self.io.cmd_clear,
            "describe": self.io.cmd_describe,
            "desc": self.io.cmd_describe,
            "summarize": self.io.cmd_summarize,
            "sum": self.io.cmd_summarize,
            "su": self.io.cmd_summarize,
            "list": self.io.cmd_list,
            "l": self.io.cmd_list,
            "count": self.io.cmd_count,
            "display": self.io.cmd_display,
            "di": self.io.cmd_display,
            "set": self.io.cmd_set,
            "compress": self.io.cmd_compress,
            "assert": self.io.cmd_assert,
            "format": self.io.cmd_format,
            "note": self.io.cmd_note,
            "cd": self.io.cmd_cd,
            "pwd": self.io.cmd_pwd,
            "net": self.io.cmd_net,
            "confirm": self.io.cmd_confirm,
            # Merging
            "merge": self.merging.cmd_merge,
            "append": self.merging.cmd_append,
            "joinby": self.merging.cmd_joinby,
            "expand": self.merging.cmd_expand,
            "reshape": self.merging.cmd_reshape,
            "cross": self.merging.cmd_cross,
            # Aggregation
            "collapse": self.aggregation.cmd_collapse,
            "contract": self.aggregation.cmd_contract,
            "duplicates": self.aggregation.cmd_duplicates,
            "isid": self.aggregation.cmd_isid,
            "distinct": self.aggregation.cmd_distinct,
            "levelsof": self.aggregation.cmd_levelsof,
            "tabulate": self.aggregation.cmd_tabulate,
            "tab": self.aggregation.cmd_tabulate,
            "table": self.aggregation.cmd_table,
        }

    def output(self, text: str) -> None:
        """Output text (respecting quiet mode)."""
        if not self._quietly_mode and not self.quiet:
            self._output_buffer.append(text)
            print(text)

    def get_output(self) -> list[str]:
        """Get accumulated output."""
        return self._output_buffer

    def clear_output(self) -> None:
        """Clear output buffer."""
        self._output_buffer.clear()

    @property
    def rc(self) -> int:
        """Get last return code."""
        return self._return_code

    def run(self, code: str) -> int:
        """
        Execute Stata code.

        Args:
            code: Stata code to execute

        Returns:
            Return code (0 for success)
        """
        self._return_code = 0

        try:
            # Preprocess code
            code = preprocess_stata_code(code)

            # Parse and execute
            commands = self.parser.parse_text(code)
            self._execute_commands(commands)

        except StataError as e:
            self._return_code = e.rc
            if not self._capture_mode:
                self.output(f"error: {e}")

        except Exception as e:
            self._return_code = 198
            if not self._capture_mode:
                self.output(f"error: {e}")

        return self._return_code

    def run_file(self, filepath: str) -> int:
        """
        Execute a Stata file (.do or .ado).

        Args:
            filepath: Path to file

        Returns:
            Return code
        """
        try:
            with open(filepath, "r", encoding="utf-8", errors="replace") as f:
                code = f.read()
            return self.run(code)
        except FileNotFoundError:
            self._return_code = 601
            self.output(f"file {filepath} not found")
            return self._return_code

    def _execute_commands(self, commands: list[ParsedCommand]) -> None:
        """Execute a list of parsed commands."""
        i = 0
        while i < len(commands):
            cmd = commands[i]
            i = self._execute_command(cmd, commands, i)

    def _execute_command(
        self, cmd: ParsedCommand, all_commands: list[ParsedCommand], idx: int
    ) -> int:
        """
        Execute a single command.

        Returns the index of the next command to execute.
        """
        command = cmd.command.lower() if cmd.command else ""

        # Handle capture prefix
        was_capture = self._capture_mode
        was_quiet = self._quietly_mode
        is_capture_cmd = cmd.prefix == "capture"

        if is_capture_cmd:
            self._capture_mode = True
        if cmd.prefix == "quietly":
            self._quietly_mode = True

        try:
            # Special commands
            if command == "local":
                self._cmd_local(cmd)
            elif command == "global":
                self._cmd_global(cmd)
            elif command == "scalar":
                self._cmd_scalar(cmd)
            elif command in ("tempvar", "tempfile", "tempname"):
                self._cmd_temp(cmd, command)
            elif command == "return":
                self._cmd_return(cmd)
            elif command == "ereturn":
                self._cmd_ereturn(cmd)
            elif command == "foreach":
                return self._cmd_foreach(cmd, all_commands, idx)
            elif command == "forvalues":
                return self._cmd_forvalues(cmd, all_commands, idx)
            elif command == "while":
                return self._cmd_while(cmd, all_commands, idx)
            elif command == "if":
                return self._cmd_if_block(cmd, all_commands, idx)
            elif command == "program":
                return self._cmd_program(cmd, all_commands, idx)
            elif command == "preserve":
                self._cmd_preserve()
            elif command == "restore":
                self._cmd_restore(cmd)
            elif command in ("version",):
                pass  # Ignore
            elif command in ("mata", "mata:"):
                self._cmd_mata(cmd)
            elif command in ("quietly", "qui", "capture", "cap", "noisily"):
                pass  # Prefix only
            elif command in ("end", "}", "{"):
                pass  # Block delimiter
            elif command == "syntax":
                self._cmd_syntax(cmd)
            elif command == "marksample":
                self._cmd_marksample(cmd)
            elif command == "markout":
                self._cmd_markout(cmd)
            elif command == "exit":
                self._cmd_exit(cmd)
            elif command == "error":
                self._cmd_error(cmd)
            elif command == "confirm":
                self._cmd_confirm(cmd)
            elif command == "gettoken":
                self._cmd_gettoken(cmd)
            elif command == "tokenize":
                self._cmd_tokenize(cmd)
            elif command in self._commands:
                # Standard command
                self._execute_standard_command(cmd)
            elif command in self.programs:
                # User-defined program
                self._execute_program(command, cmd)
            elif command:
                # Try to find and execute ado file
                if not self._try_execute_ado(command, cmd):
                    if not self._capture_mode:
                        self.output(f"unrecognized command: {command}")

        except StataError as e:
            if is_capture_cmd or was_capture:
                # In capture mode, store rc and continue
                self._return_code = e.rc
                self.macros.set_scalar("_rc", e.rc)
            else:
                raise
        except Exception as e:
            if is_capture_cmd or was_capture:
                self._return_code = 198
                self.macros.set_scalar("_rc", 198)
            else:
                raise StataError(str(e))

        else:
            # Command succeeded
            if is_capture_cmd:
                self.macros.set_scalar("_rc", 0)
            self._return_code = 0

        finally:
            self._capture_mode = was_capture
            self._quietly_mode = was_quiet

        return idx + 1

    def _execute_standard_command(self, cmd: ParsedCommand) -> None:
        """Execute a standard command with by-group handling."""
        command = cmd.command.lower()
        handler = self._commands.get(command)

        if handler is None:
            raise StataError(f"unrecognized command: {command}")

        # Commands that accept 'using' argument
        using_commands = {
            "use", "save", "merge", "append", "joinby", "cross",
            "import", "export"
        }

        # Expand macros in arguments
        expanded_args = self._expand_args(cmd.arguments)

        # Expand macros in if condition
        expanded_if = None
        if cmd.if_condition:
            expanded_if = self.macros.expand(cmd.if_condition)

        # Expand macros in using clause
        expanded_using = None
        if cmd.using:
            expanded_using = self.macros.expand(cmd.using)

        # Handle by/bysort prefix
        if cmd.prefix in ("by", "bysort"):
            self._execute_with_by(cmd, handler)
        else:
            # Only pass 'using' to commands that support it
            if command in using_commands:
                handler(
                    expanded_args,
                    if_cond=expanded_if,
                    in_range=cmd.in_range,
                    options=cmd.options,
                    using=expanded_using,
                )
            else:
                handler(
                    expanded_args,
                    if_cond=expanded_if,
                    in_range=cmd.in_range,
                    options=cmd.options,
                )

    def _expand_args(self, args: list) -> list:
        """Expand macros in command arguments."""
        expanded = []
        for arg in args:
            if isinstance(arg, str):
                expanded.append(self.macros.expand(arg))
            else:
                expanded.append(arg)
        return expanded

    def _execute_with_by(
        self, cmd: ParsedCommand, handler: Callable
    ) -> None:
        """Execute command with by-group processing."""
        by_vars = cmd.prefix_vars
        sort_vars = cmd.prefix_sort_vars

        # Sort if bysort
        if cmd.prefix == "bysort" or sort_vars:
            all_sort = by_vars + sort_vars
            self.data.sort(all_sort)

        # Set up by-group context
        self._current_by_vars = by_vars
        self._current_by_sort_vars = sort_vars

        # Expand macros in arguments
        expanded_args = self._expand_args(cmd.arguments)
        expanded_if = self.macros.expand(cmd.if_condition) if cmd.if_condition else None

        # Special handling for generate - use vectorized by-group _n and _N
        if cmd.command.lower() in ('generate', 'gen', 'g'):
            self._generate_with_by(expanded_args, expanded_if, cmd, by_vars, sort_vars)
            self._current_by_vars = []
            self._current_by_sort_vars = []
            return

        # Execute for each group
        grouped = self.data.df.groupby(by_vars, sort=False)

        for group_key, group_df in grouped:
            # Create mask for this group
            if len(by_vars) == 1:
                mask = self.data.df[by_vars[0]] == group_key
            else:
                mask = pd.Series([True] * self.data.N)
                for i, var in enumerate(by_vars):
                    mask &= self.data.df[var] == group_key[i]

            # Set by-group context for expression evaluator
            group_n = mask.cumsum()
            group_n.loc[~mask] = np.nan
            group_size = mask.sum()

            self.expr_eval.set_by_context(group_n, group_size, mask)

            # Execute command
            try:
                # For egen with by, pass by_vars
                if cmd.command.lower() == "egen":
                    handler(
                        expanded_args,
                        if_cond=expanded_if,
                        in_range=cmd.in_range,
                        options=cmd.options,
                        by_vars=by_vars,
                    )
                else:
                    handler(
                        expanded_args,
                        if_cond=expanded_if,
                        in_range=cmd.in_range,
                        options=cmd.options,
                    )
            finally:
                self.expr_eval.clear_by_context()

        self._current_by_vars = []
        self._current_by_sort_vars = []

    def _generate_with_by(
        self,
        args: list,
        if_cond: str,
        cmd: ParsedCommand,
        by_vars: list,
        sort_vars: list
    ) -> None:
        """Handle generate command with by-group context using vectorized operations."""
        import re

        # Parse arguments: [type] newvar = expression
        arg_str = " ".join(str(a) for a in args)

        # Check for type specification
        var_type = None
        type_match = re.match(r'^(byte|int|long|float|double|str\d*)\s+', arg_str, re.IGNORECASE)
        if type_match:
            var_type = type_match.group(1).lower()
            arg_str = arg_str[type_match.end():]

        # Parse newvar = expression
        if '=' not in arg_str:
            raise ValueError("generate requires newvar = expression")

        parts = arg_str.split('=', 1)
        new_var = parts[0].strip()
        expression = parts[1].strip()

        # Check if variable already exists
        if self.data.has_var(new_var):
            raise ValueError(f"variable {new_var} already defined")

        # Calculate by-group _n (within-group observation number) for all observations
        # This creates a cumulative count within each group
        grouped = self.data.df.groupby(by_vars, sort=False)
        by_group_n = grouped.cumcount() + 1  # 1-indexed like Stata

        # Calculate by-group _N (group size) for all observations
        by_group_N = grouped[by_vars[0]].transform('count')

        # Create a mask for all observations (all True since we want all rows)
        full_mask = pd.Series([True] * self.data.N)

        # Set by-group context for expression evaluator
        self.expr_eval.set_by_context(
            pd.Series(by_group_n.values, dtype=float),
            None,  # _N varies by group, handled via by_group_N
            full_mask
        )

        # Temporarily set _current_group_N to the by_group_N series for vectorized evaluation
        self.expr_eval._by_group_N_series = by_group_N

        try:
            # Evaluate expression
            result = self.expr_eval.evaluate(expression)

            # Apply if condition if any
            if if_cond:
                mask = self.cond_eval.evaluate_if(if_cond)
            else:
                mask = full_mask

            # Create new variable
            if isinstance(result, pd.Series):
                new_values = pd.Series(index=range(self.data.N), dtype=float)
                new_values.loc[:] = np.nan
                new_values.loc[mask] = result.loc[mask]
            else:
                new_values = pd.Series([np.nan] * self.data.N)
                new_values.loc[mask] = result

            # Convert type if specified
            if var_type:
                new_values = self.data_manip._convert_type(new_values, var_type)

            self.data.set_var(new_var, new_values)

        finally:
            self.expr_eval.clear_by_context()
            # Clean up temporary attribute
            if hasattr(self.expr_eval, '_by_group_N_series'):
                delattr(self.expr_eval, '_by_group_N_series')

    def _cmd_local(self, cmd: ParsedCommand) -> None:
        """Handle local macro assignment."""
        if not cmd.arguments:
            return

        # Parse: local name [= expression] or local name "value" or local name: extended
        arg_str = " ".join(str(a) for a in cmd.arguments)

        # Extended macro function: local name: function args
        # Check using raw_line since parser strips colons
        raw = cmd.raw_line
        if ":" in raw and "=" not in raw:
            # Find the colon position in raw line
            colon_idx = raw.find(":")
            # Extract name and extended function
            before_colon = raw[:colon_idx].strip()
            # Name is after 'local '
            if before_colon.lower().startswith("local "):
                name = before_colon[6:].strip()
            else:
                name = before_colon
            extended = raw[colon_idx + 1 :].strip()

            # Expand macros in extended part
            extended = self.macros.expand(extended)
            value = self.macros.parse_extended_macro(":" + extended)
            self.macros.set_local(name, value)
            return

        # Assignment: local name = expr or local name expr
        if "=" in arg_str:
            parts = arg_str.split("=", 1)
            name = parts[0].strip()
            expr = parts[1].strip()

            # Evaluate expression
            expr = self.macros.expand(expr)
            try:
                value = self.expr_eval.evaluate(expr, row_context=False)
                if isinstance(value, pd.Series):
                    value = value.iloc[0] if len(value) > 0 else ""
                self.macros.set_local(name, value)
            except Exception:
                self.macros.set_local(name, expr)
        else:
            # local name value or local name "value"
            parts = arg_str.split(None, 1)
            name = parts[0]
            value = parts[1].strip('"') if len(parts) > 1 else ""
            value = self.macros.expand(value)
            self.macros.set_local(name, value)

    def _cmd_global(self, cmd: ParsedCommand) -> None:
        """Handle global macro assignment."""
        if not cmd.arguments:
            return

        arg_str = " ".join(str(a) for a in cmd.arguments)

        if "=" in arg_str:
            parts = arg_str.split("=", 1)
            name = parts[0].strip()
            expr = parts[1].strip()
            expr = self.macros.expand(expr)
            try:
                value = self.expr_eval.evaluate(expr, row_context=False)
                if isinstance(value, pd.Series):
                    value = value.iloc[0] if len(value) > 0 else ""
                self.macros.set_global(name, value)
            except Exception:
                self.macros.set_global(name, expr)
        else:
            parts = arg_str.split(None, 1)
            name = parts[0]
            value = parts[1].strip('"') if len(parts) > 1 else ""
            value = self.macros.expand(value)
            self.macros.set_global(name, value)

    def _cmd_scalar(self, cmd: ParsedCommand) -> None:
        """Handle scalar command."""
        if not cmd.arguments:
            return

        arg_str = " ".join(str(a) for a in cmd.arguments)

        if arg_str.startswith("define "):
            arg_str = arg_str[7:]

        if "=" in arg_str:
            parts = arg_str.split("=", 1)
            name = parts[0].strip()
            expr = parts[1].strip()
            expr = self.macros.expand(expr)
            value = self.expr_eval.evaluate(expr, row_context=False)
            if isinstance(value, pd.Series):
                value = value.iloc[0] if len(value) > 0 else np.nan
            self.macros.set_scalar(name, float(value))

    def _cmd_temp(self, cmd: ParsedCommand, temp_type: str) -> None:
        """Handle tempvar/tempfile/tempname."""
        for name in cmd.arguments:
            name = str(name)
            if temp_type == "tempvar":
                temp_name = self.macros.new_tempvar()
            elif temp_type == "tempfile":
                temp_name = self.macros.new_tempfile()
            else:
                temp_name = self.macros.new_tempname()
            self.macros.set_local(name, temp_name)

    def _cmd_return(self, cmd: ParsedCommand) -> None:
        """Handle return command."""
        if not cmd.arguments:
            return

        subcmd = str(cmd.arguments[0]).lower()

        if subcmd == "clear":
            self.macros.clear_return()
        elif subcmd in ("scalar", "local", "matrix"):
            if len(cmd.arguments) > 1:
                arg_str = " ".join(str(a) for a in cmd.arguments[1:])
                if "=" in arg_str:
                    parts = arg_str.split("=", 1)
                    name = parts[0].strip()
                    expr = parts[1].strip()
                    expr = self.macros.expand(expr)

                    if subcmd == "scalar":
                        value = self.expr_eval.evaluate(expr, row_context=False)
                        if isinstance(value, pd.Series):
                            value = value.iloc[0] if len(value) > 0 else np.nan
                        self.macros.set_return(name, float(value))
                    else:
                        self.macros.set_return(name, expr)

    def _cmd_ereturn(self, cmd: ParsedCommand) -> None:
        """Handle ereturn command."""
        if not cmd.arguments:
            return

        subcmd = str(cmd.arguments[0]).lower()

        if subcmd == "clear":
            self.macros.clear_ereturn()
        elif subcmd in ("scalar", "local", "matrix", "post"):
            if len(cmd.arguments) > 1:
                arg_str = " ".join(str(a) for a in cmd.arguments[1:])
                if "=" in arg_str:
                    parts = arg_str.split("=", 1)
                    name = parts[0].strip()
                    expr = parts[1].strip()
                    expr = self.macros.expand(expr)

                    if subcmd == "scalar":
                        value = self.expr_eval.evaluate(expr, row_context=False)
                        if isinstance(value, pd.Series):
                            value = value.iloc[0] if len(value) > 0 else np.nan
                        self.macros.set_ereturn(name, float(value))
                    else:
                        self.macros.set_ereturn(name, expr)

    def _cmd_mata(self, cmd: ParsedCommand) -> None:
        """Handle simple mata commands.

        Supports limited Mata functionality for common patterns:
        - st_local("name", value) - set local macro
        - direxists(path) - check if directory exists
        """
        import re

        # Get the mata expression from raw_line
        raw = cmd.raw_line
        # Handle "mata :" or "mata:" prefix
        if raw.lower().startswith("mata"):
            expr = raw[4:].strip()
            if expr.startswith(":"):
                expr = expr[1:].strip()
        else:
            expr = " ".join(str(a) for a in cmd.arguments)

        # Expand macros in the expression
        expr = self.macros.expand(expr)

        # Remove extra spaces around parentheses and commas
        expr = re.sub(r'\s*\(\s*', '(', expr)
        expr = re.sub(r'\s*\)\s*', ')', expr)
        expr = re.sub(r'\s*,\s*', ',', expr)

        # Pattern: st_local("name", strofreal(direxists(st_local("varname"))))
        # This is used to check if a directory exists

        # Match st_local("name", value) - handle both "quotes" and unquoted
        match = re.match(r'st_local\((["\']?)(\w+)\1,(.+)\)', expr)
        if match:
            local_name = match.group(2)
            value_expr = match.group(3).strip()

            # Handle direxists with st_local pattern
            # Pattern: strofreal(direxists(st_local("mydir")))
            inner_local_match = re.search(r'direxists\(st_local\((["\']?)(\w+)\1\)\)', value_expr)
            if inner_local_match:
                inner_name = inner_local_match.group(2)
                inner_value = self.macros.get_local(inner_name)
                exists = "1" if os.path.isdir(inner_value) else "0"
                self.macros.set_local(local_name, exists)
                return

            # Handle direxists with literal path
            dir_match = re.search(r'direxists\((["\']?)([^"\']+)\1\)', value_expr)
            if dir_match:
                dir_path = dir_match.group(2)
                exists = "1" if os.path.isdir(dir_path) else "0"
                self.macros.set_local(local_name, exists)
                return

            # Try to evaluate as simple string
            if value_expr.startswith('"') and value_expr.endswith('"'):
                self.macros.set_local(local_name, value_expr[1:-1])
                return

            # Default: try to evaluate as numeric
            try:
                result = self.expr_eval.evaluate(value_expr, row_context=False)
                self.macros.set_local(local_name, str(result))
            except Exception:
                pass  # Silently ignore unsupported mata expressions

    def _cmd_foreach(
        self, cmd: ParsedCommand, all_commands: list[ParsedCommand], idx: int
    ) -> int:
        """Handle foreach loop."""
        # Parse: foreach lname in list or foreach lname of local macname
        # Use raw_line since arguments parsing stops at "in" keyword
        raw = cmd.raw_line
        # Remove "foreach" from the beginning
        if raw.lower().startswith("foreach "):
            arg_str = raw[8:].strip()
        else:
            arg_str = " ".join(str(a) for a in cmd.arguments)
        # Remove trailing brace if present
        if arg_str.endswith("{"):
            arg_str = arg_str[:-1].strip()
        arg_str = self.macros.expand(arg_str)

        # Find loop body (between { and })
        body_start = idx + 1
        body_end = self._find_block_end(all_commands, body_start)
        body_commands = all_commands[body_start:body_end]

        # Parse foreach syntax
        if " in " in arg_str:
            parts = arg_str.split(" in ", 1)
            loop_var = parts[0].strip()
            list_items = parts[1].split()
        elif " of local " in arg_str:
            parts = arg_str.split(" of local ", 1)
            loop_var = parts[0].strip()
            macro_name = parts[1].strip()
            list_content = self.macros.get_local(macro_name)
            list_items = list_content.split()
        elif " of varlist " in arg_str:
            parts = arg_str.split(" of varlist ", 1)
            loop_var = parts[0].strip()
            varlist = parts[1].strip()
            list_items = self._expand_varlist(varlist.split())
        elif " of newlist " in arg_str:
            parts = arg_str.split(" of newlist ", 1)
            loop_var = parts[0].strip()
            list_items = parts[1].split()
        elif " of numlist " in arg_str:
            parts = arg_str.split(" of numlist ", 1)
            loop_var = parts[0].strip()
            numlist = parts[1].strip()
            list_items = self._expand_numlist(numlist)
        else:
            # Try simple form
            parts = arg_str.split(None, 1)
            loop_var = parts[0]
            list_items = parts[1].split() if len(parts) > 1 else []

        # Execute loop
        for item in list_items:
            self.macros.set_local(loop_var, str(item))
            self._execute_commands(body_commands)

        return body_end + 1

    def _cmd_forvalues(
        self, cmd: ParsedCommand, all_commands: list[ParsedCommand], idx: int
    ) -> int:
        """Handle forvalues loop."""
        # Parse: forvalues lname = range
        # Use raw_line to ensure we get the full range specification
        raw = cmd.raw_line
        if raw.lower().startswith("forvalues "):
            arg_str = raw[10:].strip()
        else:
            arg_str = " ".join(str(a) for a in cmd.arguments)
        # Remove trailing brace if present
        if arg_str.endswith("{"):
            arg_str = arg_str[:-1].strip()
        arg_str = self.macros.expand(arg_str)

        # Find loop body
        body_start = idx + 1
        body_end = self._find_block_end(all_commands, body_start)
        body_commands = all_commands[body_start:body_end]

        # Parse range: start/end or start(step)end
        if "=" in arg_str:
            parts = arg_str.split("=", 1)
            loop_var = parts[0].strip()
            range_str = parts[1].strip()
        else:
            parts = arg_str.split(None, 1)
            loop_var = parts[0]
            range_str = parts[1] if len(parts) > 1 else ""

        # Parse range
        values = self._parse_forvalues_range(range_str)

        # Execute loop
        for val in values:
            self.macros.set_local(loop_var, str(val))
            self._execute_commands(body_commands)

        return body_end + 1

    def _cmd_while(
        self, cmd: ParsedCommand, all_commands: list[ParsedCommand], idx: int
    ) -> int:
        """Handle while loop."""
        # Use raw_line to get the full condition with operators
        raw = cmd.raw_line
        if raw.lower().startswith("while "):
            arg_str = raw[6:].strip()
        else:
            arg_str = " ".join(str(a) for a in cmd.arguments)
        # Remove trailing brace if present
        if arg_str.endswith("{"):
            arg_str = arg_str[:-1].strip()

        # Find loop body
        body_start = idx + 1
        body_end = self._find_block_end(all_commands, body_start)
        body_commands = all_commands[body_start:body_end]

        # Execute while condition is true
        max_iterations = 100000  # Safety limit
        iterations = 0

        while iterations < max_iterations:
            # Evaluate condition
            condition = self.macros.expand(arg_str)
            result = self.expr_eval.evaluate(condition, row_context=False)

            if isinstance(result, pd.Series):
                result = result.iloc[0] if len(result) > 0 else False

            if not result:
                break

            self._execute_commands(body_commands)
            iterations += 1

        return body_end + 1

    def _cmd_if_block(
        self, cmd: ParsedCommand, all_commands: list[ParsedCommand], idx: int
    ) -> int:
        """Handle if/else block (not if qualifier)."""
        # Use raw_line to get the full condition with operators
        raw = cmd.raw_line
        if raw.lower().startswith("if "):
            arg_str = raw[3:].strip()
        else:
            arg_str = " ".join(str(a) for a in cmd.arguments)
        # Remove trailing brace if present
        if arg_str.endswith("{"):
            arg_str = arg_str[:-1].strip()
        arg_str = self.macros.expand(arg_str)

        # Find if body
        body_start = idx + 1
        body_end = self._find_block_end(all_commands, body_start)
        if_body = all_commands[body_start:body_end]

        # Check for else
        else_body = []
        next_idx = body_end + 1

        if next_idx < len(all_commands):
            next_cmd = all_commands[next_idx]
            if next_cmd.command and next_cmd.command.lower() == "else":
                else_start = next_idx + 1
                else_end = self._find_block_end(all_commands, else_start)
                else_body = all_commands[else_start:else_end]
                next_idx = else_end + 1

        # Evaluate condition
        result = self.expr_eval.evaluate(arg_str, row_context=False)
        if isinstance(result, pd.Series):
            result = result.iloc[0] if len(result) > 0 else False

        if result:
            self._execute_commands(if_body)
        elif else_body:
            self._execute_commands(else_body)

        return next_idx

    def _cmd_program(
        self, cmd: ParsedCommand, all_commands: list[ParsedCommand], idx: int
    ) -> int:
        """Handle program definition."""
        if not cmd.arguments:
            return idx + 1

        subcmd = str(cmd.arguments[0]).lower()

        if subcmd == "drop":
            # Drop program
            if len(cmd.arguments) > 1:
                prog_name = str(cmd.arguments[1])
                self.programs.pop(prog_name, None)
            return idx + 1

        if subcmd == "define":
            prog_name = str(cmd.arguments[1]) if len(cmd.arguments) > 1 else ""
        else:
            prog_name = subcmd

        # Find program body (until "end")
        body_start = idx + 1
        body_end = body_start
        while body_end < len(all_commands):
            if all_commands[body_end].command and all_commands[body_end].command.lower() == "end":
                break
            body_end += 1

        # Collect body text
        body_lines = []
        for i in range(body_start, body_end):
            body_lines.append(all_commands[i].raw_line)

        # Create program
        self.programs[prog_name] = StataProgram(
            name=prog_name,
            body="\n".join(body_lines),
            options=cmd.options,
        )

        return body_end + 1

    def _execute_program(self, name: str, cmd: ParsedCommand) -> None:
        """Execute a user-defined program."""
        program = self.programs.get(name)
        if not program:
            raise StataError(f"program {name} not found", 199)

        # Save local scope
        saved_locals = self.macros.push_scope()

        try:
            # Set up arguments
            # Build full argument string including options
            arg_parts = [str(a) for a in cmd.arguments]

            # Add if condition if present
            if cmd.if_condition:
                arg_parts.append("if")
                arg_parts.append(cmd.if_condition)

            # Add in range if present
            if cmd.in_range:
                arg_parts.append("in")
                arg_parts.append(cmd.in_range)

            # Add options after comma
            if cmd.options:
                opt_parts = []
                for opt_name, opt_value in cmd.options.items():
                    if opt_value is True:
                        # Flag option (no value)
                        opt_parts.append(opt_name)
                    else:
                        # Option with value
                        opt_parts.append(f"{opt_name}({opt_value})")
                if opt_parts:
                    arg_parts.append(",")
                    arg_parts.extend(opt_parts)

            arg_str = " ".join(arg_parts)
            self.macros.set_local("0", arg_str)

            # Set positional arguments
            for i, arg in enumerate(cmd.arguments, 1):
                self.macros.set_local(str(i), str(arg))

            # Clear return values if rclass
            if program.rclass:
                self.macros.clear_return()

            # Execute program body
            self.run(program.body)

        finally:
            # Restore local scope
            self.macros.pop_scope(saved_locals)

    def _cmd_preserve(self) -> None:
        """Preserve current data."""
        self._preserve_stack.append(self.data.copy())

    def _cmd_restore(self, cmd: ParsedCommand) -> None:
        """Restore preserved data."""
        if not self._preserve_stack:
            raise StataError("preserve/restore mismatch")

        not_opt = "not" in [str(a).lower() for a in cmd.arguments]

        if not_opt:
            # Discard preserved copy but keep current data
            self._preserve_stack.pop()
        else:
            # Restore preserved data
            self.data = self._preserve_stack.pop()
            # Update evaluators
            self.expr_eval.data = self.data
            self.cond_eval.data = self.data

    def _cmd_syntax(self, cmd: ParsedCommand) -> None:
        """Parse syntax specification."""
        import re

        # Use raw_line to get the actual syntax specification
        # The parser puts options into cmd.options but we need the raw spec
        raw_line = cmd.raw_line
        # Remove "syntax" from the beginning
        if raw_line.lower().startswith("syntax"):
            arg_str = raw_line[6:].strip()
        else:
            arg_str = " ".join(str(a) for a in cmd.arguments)
        arg_str = self.macros.expand(arg_str)

        # Get the arguments passed to the program
        program_args = self.macros.get_local("0")

        # Very basic syntax parsing - just set varlist
        if "varlist" in arg_str.lower():
            # Extract variables from program args
            parts = program_args.split(",")[0].split()
            vars = [p for p in parts if not p.startswith("-")]
            self.macros.set_local("varlist", " ".join(vars))

        # Handle if/in
        if " if " in program_args:
            if_idx = program_args.find(" if ")
            if_part = program_args[if_idx + 4 :]
            # Find end of if condition
            end_idx = len(if_part)
            for marker in [",", " in "]:
                if marker in if_part:
                    end_idx = min(end_idx, if_part.find(marker))
            self.macros.set_local("if", if_part[:end_idx].strip())

        # Parse options from syntax specification
        # Options appear after comma in syntax: syntax [varlist] , options
        if "," in arg_str:
            options_spec = arg_str.split(",", 1)[1].strip()

            # Remove brackets for optional parts (simplified - treat all as optional for now)
            options_spec_clean = options_spec.replace("[", " ").replace("]", " ")

            # Find option specifications like: OPTNAME(type default) or OPTNAME
            # Pattern: word(type) or word(type default) or just word
            opt_pattern = re.compile(r'(\w+)(?:\((\w+)(?:\s+(\S+))?\))?', re.IGNORECASE)

            # Parse actual arguments passed to the program
            # Split on comma to get options part
            if "," in program_args:
                actual_options = program_args.split(",", 1)[1].strip()
            else:
                # Options-only syntax (syntax starts with comma)
                actual_options = program_args.strip()

            # Build a dict of option specs with their defaults
            option_specs = {}
            for match in opt_pattern.finditer(options_spec_clean):
                opt_name = match.group(1).lower()
                opt_type = match.group(2)  # string, integer, real, etc.
                opt_default = match.group(3)  # default value if any
                option_specs[opt_name] = {
                    'type': opt_type,
                    'default': opt_default
                }

            # Set defaults first
            for opt_name, spec in option_specs.items():
                if spec['default'] is not None:
                    self.macros.set_local(opt_name, spec['default'])

            # Parse actual option values from program args
            # Handle optname(value) pattern
            opt_value_pattern = re.compile(r'(\w+)\s*\(\s*([^)]+)\s*\)', re.IGNORECASE)
            for match in opt_value_pattern.finditer(actual_options):
                opt_name = match.group(1).lower()
                opt_value = match.group(2).strip()
                # Remove surrounding quotes if present
                if (opt_value.startswith('"') and opt_value.endswith('"')) or \
                   (opt_value.startswith("'") and opt_value.endswith("'")):
                    opt_value = opt_value[1:-1]
                self.macros.set_local(opt_name, opt_value)

            # Handle flag options (options without values)
            # Remove matched option(value) patterns to find remaining flags
            remaining = opt_value_pattern.sub('', actual_options)
            for word in remaining.split():
                word_lower = word.lower()
                if word_lower in option_specs or word_lower in [s.lower() for s in option_specs]:
                    # It's a flag option - set to non-empty value
                    self.macros.set_local(word_lower, word_lower)

    def _cmd_marksample(self, cmd: ParsedCommand) -> None:
        """Create sample marker variable."""
        if not cmd.arguments:
            return

        touse_name = str(cmd.arguments[0])

        # Create touse variable (1 for all observations by default)
        self.data.set_var(touse_name, pd.Series([1] * self.data.N))

        # Apply if condition if any
        if_cond = self.macros.get_local("if")
        if if_cond:
            mask = self.cond_eval.evaluate_if(if_cond)
            touse = self.data.get_var(touse_name)
            touse.loc[~mask] = 0
            self.data.set_var(touse_name, touse)

        # Apply varlist missing
        varlist = self.macros.get_local("varlist")
        if varlist and "novarlist" not in [str(a).lower() for a in cmd.arguments]:
            for var in varlist.split():
                if self.data.has_var(var) and self.data.is_numeric(var):
                    missing_mask = self.data.is_missing(var)
                    touse = self.data.get_var(touse_name)
                    touse.loc[missing_mask] = 0
                    self.data.set_var(touse_name, touse)

    def _cmd_markout(self, cmd: ParsedCommand) -> None:
        """Mark out observations with missing values."""
        if len(cmd.arguments) < 2:
            return

        touse_name = str(cmd.arguments[0])
        varlist = [str(a) for a in cmd.arguments[1:]]

        for var in varlist:
            if self.data.has_var(var):
                missing_mask = self.data.is_missing(var)
                touse = self.data.get_var(touse_name)
                touse.loc[missing_mask] = 0
                self.data.set_var(touse_name, touse)

    def _cmd_exit(self, cmd: ParsedCommand) -> None:
        """Handle exit command."""
        if cmd.arguments:
            rc = int(cmd.arguments[0])
            if rc != 0:
                raise StataError("", rc)

    def _cmd_error(self, cmd: ParsedCommand) -> None:
        """Handle error command."""
        if cmd.arguments:
            rc = int(cmd.arguments[0])
            raise StataError("", rc)

    def _cmd_confirm(self, cmd: ParsedCommand) -> None:
        """Confirm existence of something."""
        if len(cmd.arguments) < 2:
            return

        what = str(cmd.arguments[0]).lower()
        name = str(cmd.arguments[1])

        if what == "variable":
            name = self.macros.expand(name)
            if not self.data.has_var(name):
                raise StataError(f"variable {name} not found", 111)
        elif what in ("numeric", "string"):
            name = self.macros.expand(name)
            if not self.data.has_var(name):
                raise StataError(f"variable {name} not found", 111)
            is_num = self.data.is_numeric(name)
            if what == "numeric" and not is_num:
                raise StataError(f"{name} is not numeric", 109)
            if what == "string" and is_num:
                raise StataError(f"{name} is not string", 109)
        elif what == "file":
            # Reconstruct filename from args and expand macros
            filename = "".join(str(a) for a in cmd.arguments[1:]).strip('"').strip("'")
            filename = self.macros.expand(filename)
            if not os.path.exists(filename):
                raise StataError(f'file "{filename}" not found', 601)

    def _cmd_gettoken(self, cmd: ParsedCommand) -> None:
        """Parse gettoken command."""
        arg_str = " ".join(str(a) for a in cmd.arguments)
        arg_str = self.macros.expand(arg_str)

        # Parse: gettoken token rest : source
        if ":" not in arg_str:
            return

        left, right = arg_str.split(":", 1)
        parts = left.split()
        if len(parts) < 2:
            return

        token_name = parts[0]
        rest_name = parts[1]
        source_name = right.strip()

        # Get source value
        source = self.macros.get_local(source_name)
        words = source.split(None, 1)

        if words:
            self.macros.set_local(token_name, words[0])
            self.macros.set_local(rest_name, words[1] if len(words) > 1 else "")
        else:
            self.macros.set_local(token_name, "")
            self.macros.set_local(rest_name, "")

    def _cmd_tokenize(self, cmd: ParsedCommand) -> None:
        """Tokenize a string into positional locals."""
        arg_str = " ".join(str(a) for a in cmd.arguments)
        arg_str = self.macros.expand(arg_str)

        words = arg_str.strip('"').split()
        for i, word in enumerate(words, 1):
            self.macros.set_local(str(i), word)

    def _find_block_end(
        self, commands: list[ParsedCommand], start: int
    ) -> int:
        """Find the end of a block (matching })."""
        depth = 1
        i = start

        while i < len(commands) and depth > 0:
            cmd = commands[i]
            raw = cmd.raw_line.strip()
            cmd_name = cmd.command.lower() if cmd.command else ""

            if cmd_name == "}" or raw == "}":
                depth -= 1
            elif cmd_name == "end":
                depth -= 1
            elif raw.endswith("{"):
                depth += 1

            if depth > 0:
                i += 1

        return i

    def _parse_forvalues_range(self, range_str: str) -> list:
        """Parse forvalues range specification."""
        range_str = range_str.strip()

        # Format: start/end or start(step)end
        if "(" in range_str:
            # start(step)end
            match = re.match(r"(-?\d+)\((-?\d+)\)(-?\d+)", range_str)
            if match:
                start = int(match.group(1))
                step = int(match.group(2))
                end = int(match.group(3))
                if step > 0:
                    return list(range(start, end + 1, step))
                else:
                    return list(range(start, end - 1, step))
        else:
            # start/end
            parts = range_str.split("/")
            if len(parts) == 2:
                start = int(parts[0])
                end = int(parts[1])
                return list(range(start, end + 1))

        return []

    def _expand_numlist(self, numlist: str) -> list:
        """Expand Stata numlist specification."""
        result = []
        numlist = self.macros.expand(numlist)

        for part in numlist.split():
            if "/" in part:
                # Range: start/end
                s, e = part.split("/")
                result.extend(str(i) for i in range(int(s), int(e) + 1))
            elif "(" in part:
                # Step: start(step)end
                match = re.match(r"(-?\d+)\((-?\d+)\)(-?\d+)", part)
                if match:
                    start = int(match.group(1))
                    step = int(match.group(2))
                    end = int(match.group(3))
                    result.extend(str(i) for i in range(start, end + 1, step))
            else:
                result.append(part)

        return result

    def _expand_varlist(self, varlist: list) -> list:
        """Expand variable list with wildcards."""
        result = []
        for pattern in varlist:
            if "*" in pattern or "?" in pattern:
                regex = pattern.replace("*", ".*").replace("?", ".")
                regex = f"^{regex}$"
                for var in self.data.varlist:
                    if re.match(regex, var):
                        result.append(var)
            else:
                result.append(pattern)
        return result

    def _try_execute_ado(self, command: str, cmd: ParsedCommand) -> bool:
        """Try to find and execute an ado file for the command."""
        # Look in common locations
        search_paths = [
            os.getcwd(),
            os.path.dirname(os.path.abspath(__file__)),
        ]

        for path in search_paths:
            ado_file = os.path.join(path, f"{command}.ado")
            if os.path.exists(ado_file):
                # Load and execute ado file
                self.run_file(ado_file)

                # Now try to execute the program
                if command in self.programs:
                    self._execute_program(command, cmd)
                    return True

        return False
