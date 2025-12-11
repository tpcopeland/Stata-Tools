"""
Stata Expression Evaluator

Evaluates Stata expressions including:
- Arithmetic operations (+, -, *, /, ^)
- Logical operations (&, |, !)
- Comparison operations (==, !=, <, >, <=, >=)
- Function calls
- Variable references
- Observation subscripts (var[_n-1])
"""

import re
import operator
import numpy as np
import pandas as pd
from typing import Any, Optional, Callable, Union
from .functions import STATA_FUNCTIONS, StataFunctions


class ExpressionEvaluator:
    """Evaluates Stata expressions."""

    # Operator precedence (higher = binds tighter)
    PRECEDENCE = {
        "|": 1,
        "&": 2,
        "!": 3,
        "~": 3,
        "==": 4,
        "!=": 4,
        "~=": 4,
        "<": 5,
        "<=": 5,
        ">": 5,
        ">=": 5,
        "+": 6,
        "-": 6,
        "*": 7,
        "/": 7,
        "^": 8,
    }

    # Binary operators
    BINARY_OPS = {
        "+": operator.add,
        "-": operator.sub,
        "*": operator.mul,
        "/": operator.truediv,
        "^": operator.pow,
        "==": operator.eq,
        "!=": operator.ne,
        "~=": operator.ne,
        "<": operator.lt,
        "<=": operator.le,
        ">": operator.gt,
        ">=": operator.ge,
        "&": lambda a, b: a & b,
        "|": lambda a, b: a | b,
    }

    def __init__(self, data=None, macros=None):
        """
        Initialize evaluator.

        Args:
            data: StataData instance for variable access
            macros: MacroManager instance for macro expansion
        """
        self.data = data
        self.macros = macros
        self.functions = STATA_FUNCTIONS.copy()

        # Current by-group context (for _n, _N)
        self._current_group_n: Optional[pd.Series] = None
        self._current_group_N: Optional[int] = None

        # Current observation index (for scalar evaluation)
        self._current_obs: Optional[int] = None

    def set_by_context(
        self, n_series: pd.Series, group_size: int, group_mask: pd.Series = None
    ):
        """Set by-group context for _n and _N."""
        self._current_group_n = n_series
        self._current_group_N = group_size
        self._group_mask = group_mask

    def clear_by_context(self):
        """Clear by-group context."""
        self._current_group_n = None
        self._current_group_N = None
        self._group_mask = None

    def evaluate(
        self, expr: str, row_context: bool = True
    ) -> Union[Any, pd.Series]:
        """
        Evaluate a Stata expression.

        Args:
            expr: Expression string
            row_context: If True, evaluate in row context (return Series)
                        If False, evaluate as scalar

        Returns:
            Result (scalar or Series depending on context)
        """
        if not expr or not expr.strip():
            return np.nan

        # Expand macros first
        if self.macros:
            expr = self.macros.expand(expr)

        # Parse and evaluate
        try:
            return self._eval_expr(expr.strip())
        except Exception as e:
            # For debugging
            raise ValueError(f"Error evaluating expression '{expr}': {e}")

    def _eval_expr(self, expr: str) -> Any:
        """Parse and evaluate expression."""
        tokens = self._tokenize(expr)
        if not tokens:
            return np.nan

        result, _ = self._parse_expression(tokens, 0)
        return result

    def _tokenize(self, expr: str) -> list:
        """Tokenize an expression string."""
        tokens = []
        i = 0
        expr = expr.strip()

        while i < len(expr):
            # Skip whitespace
            if expr[i].isspace():
                i += 1
                continue

            # String literals
            if expr[i] == '"':
                j = i + 1
                while j < len(expr) and expr[j] != '"':
                    j += 1
                tokens.append(("STRING", expr[i + 1 : j]))
                i = j + 1
                continue

            # Compound quotes `"..."'
            if expr[i : i + 2] == '`"':
                j = i + 2
                while j < len(expr) - 1 and expr[j : j + 2] != "\"'":
                    j += 1
                tokens.append(("STRING", expr[i + 2 : j]))
                i = j + 2
                continue

            # Numbers
            if expr[i].isdigit() or (
                expr[i] == "." and i + 1 < len(expr) and expr[i + 1].isdigit()
            ):
                j = i
                while j < len(expr) and (expr[j].isdigit() or expr[j] in ".eE+-"):
                    if expr[j] in "eE":
                        j += 1
                        if j < len(expr) and expr[j] in "+-":
                            j += 1
                    else:
                        j += 1
                num_str = expr[i:j]
                try:
                    tokens.append(("NUMBER", float(num_str)))
                except ValueError:
                    tokens.append(("NUMBER", 0))
                i = j
                continue

            # Missing value indicator
            if expr[i] == ".":
                if i + 1 >= len(expr) or not expr[i + 1].isalpha():
                    tokens.append(("MISSING", np.nan))
                    i += 1
                    continue

            # Two-character operators
            two_char = expr[i : i + 2]
            if two_char in ("==", "!=", "~=", "<=", ">="):
                tokens.append(("OP", two_char))
                i += 2
                continue

            # Single-character operators
            if expr[i] in "+-*/^<>=&|!~(),[]":
                tokens.append(("OP", expr[i]))
                i += 1
                continue

            # Names (variables, functions, keywords)
            if expr[i].isalpha() or expr[i] == "_":
                j = i
                while j < len(expr) and (expr[j].isalnum() or expr[j] == "_"):
                    j += 1
                name = expr[i:j]
                tokens.append(("NAME", name))
                i = j
                continue

            # Skip unknown characters
            i += 1

        return tokens

    def _parse_expression(
        self, tokens: list, pos: int, min_prec: int = 0
    ) -> tuple[Any, int]:
        """Parse expression with precedence climbing."""
        # Parse primary (atom)
        left, pos = self._parse_primary(tokens, pos)

        # Parse binary operators
        while pos < len(tokens):
            token = tokens[pos]
            if token[0] != "OP" or token[1] not in self.PRECEDENCE:
                break

            op = token[1]
            prec = self.PRECEDENCE[op]
            if prec < min_prec:
                break

            pos += 1  # consume operator

            # Parse right side with higher precedence
            right, pos = self._parse_expression(tokens, pos, prec + 1)

            # Apply operator
            left = self._apply_binary_op(op, left, right)

        return left, pos

    def _parse_primary(self, tokens: list, pos: int) -> tuple[Any, int]:
        """Parse a primary expression (atom)."""
        if pos >= len(tokens):
            return np.nan, pos

        token = tokens[pos]

        # Number
        if token[0] == "NUMBER":
            return token[1], pos + 1

        # String
        if token[0] == "STRING":
            return token[1], pos + 1

        # Missing value
        if token[0] == "MISSING":
            return np.nan, pos + 1

        # Unary operators
        if token[0] == "OP" and token[1] in ("!", "~", "-"):
            op = token[1]
            value, pos = self._parse_primary(tokens, pos + 1)
            if op in ("!", "~"):
                result = ~value if isinstance(value, pd.Series) else not value
            else:  # -
                result = -value
            return result, pos

        # Parenthesized expression
        if token[0] == "OP" and token[1] == "(":
            value, pos = self._parse_expression(tokens, pos + 1)
            if pos < len(tokens) and tokens[pos] == ("OP", ")"):
                pos += 1
            return value, pos

        # Name (variable, function, or special)
        if token[0] == "NAME":
            name = token[1]

            # Special values
            if name == "_n":
                return self._get_n(), pos + 1
            if name == "_N":
                return self._get_N(), pos + 1
            if name == "_pi":
                return np.pi, pos + 1

            # Check if it's a function call
            if pos + 1 < len(tokens) and tokens[pos + 1] == ("OP", "("):
                return self._parse_function_call(name, tokens, pos + 1)

            # Variable reference
            return self._get_variable(name, tokens, pos + 1)

        return np.nan, pos + 1

    def _parse_function_call(
        self, name: str, tokens: list, pos: int
    ) -> tuple[Any, int]:
        """Parse a function call."""
        pos += 1  # skip (

        # Parse arguments
        args = []
        while pos < len(tokens) and tokens[pos] != ("OP", ")"):
            if tokens[pos] == ("OP", ","):
                pos += 1
                continue
            arg, pos = self._parse_expression(tokens, pos)
            args.append(arg)

        if pos < len(tokens) and tokens[pos] == ("OP", ")"):
            pos += 1

        # Call function
        return self._call_function(name, args), pos

    def _get_variable(
        self, name: str, tokens: list, pos: int
    ) -> tuple[Any, int]:
        """Get variable value, handling subscripts."""
        if self.data is None or not self.data.has_var(name):
            # Not a variable - might be a constant or error
            return np.nan, pos

        # Check for subscript [expr]
        if pos < len(tokens) and tokens[pos] == ("OP", "["):
            pos += 1  # skip [

            # Parse subscript expression
            subscript, pos = self._parse_expression(tokens, pos)

            if pos < len(tokens) and tokens[pos] == ("OP", "]"):
                pos += 1  # skip ]

            return self._subscript_variable(name, subscript), pos

        # Return full variable
        return self.data.get_var(name), pos

    def _subscript_variable(self, name: str, subscript: Any) -> Any:
        """Get variable value with subscript (like var[_n-1])."""
        var = self.data.get_var(name)

        if isinstance(subscript, pd.Series):
            # Vector subscript - each row gets different index
            result = pd.Series(index=var.index, dtype=var.dtype)
            for i, idx in enumerate(subscript):
                if pd.notna(idx):
                    idx = int(idx) - 1  # Convert to 0-based
                    if 0 <= idx < len(var):
                        result.iloc[i] = var.iloc[idx]
                    else:
                        result.iloc[i] = np.nan
                else:
                    result.iloc[i] = np.nan
            return result
        else:
            # Scalar subscript
            idx = int(subscript) - 1  # Convert to 0-based
            if 0 <= idx < len(var):
                return var.iloc[idx]
            return np.nan

    def _get_n(self) -> Union[int, pd.Series]:
        """Get _n (observation number within group)."""
        if self._current_group_n is not None:
            return self._current_group_n
        if self.data is not None:
            return pd.Series(range(1, self.data.N + 1))
        return 1

    def _get_N(self) -> Union[int, pd.Series]:
        """Get _N (total observations in group)."""
        if self._current_group_N is not None:
            return self._current_group_N
        if self.data is not None:
            return self.data.N
        return 1

    def _apply_binary_op(self, op: str, left: Any, right: Any) -> Any:
        """Apply a binary operator."""
        op_func = self.BINARY_OPS.get(op)
        if op_func is None:
            return np.nan

        try:
            # Handle pandas Series with different indexes
            if isinstance(left, pd.Series) and isinstance(right, pd.Series):
                left, right = left.align(right, fill_value=np.nan)

            result = op_func(left, right)

            # Convert boolean results to int for Stata compatibility
            if isinstance(result, (bool, np.bool_)):
                result = int(result)
            elif isinstance(result, pd.Series) and result.dtype == bool:
                result = result.astype(int)

            return result
        except Exception:
            return np.nan

    def _call_function(self, name: str, args: list) -> Any:
        """Call a Stata function."""
        name_lower = name.lower()

        # Check built-in functions
        if name_lower in self.functions:
            try:
                return self.functions[name_lower](*args)
            except Exception as e:
                return np.nan

        # Unknown function
        return np.nan


class ConditionEvaluator:
    """Evaluates Stata if/in conditions to create boolean masks."""

    def __init__(self, data, macros=None):
        self.data = data
        self.macros = macros
        self.expr_eval = ExpressionEvaluator(data, macros)

    def evaluate_if(self, condition: str) -> pd.Series:
        """
        Evaluate an if condition and return boolean mask.

        Args:
            condition: Stata if condition (e.g., "foreign == 1")

        Returns:
            Boolean Series indicating which observations match
        """
        if not condition:
            return pd.Series([True] * self.data.N)

        # Evaluate expression
        result = self.expr_eval.evaluate(condition)

        # Convert to boolean
        if isinstance(result, pd.Series):
            return result.astype(bool)
        elif isinstance(result, (bool, np.bool_)):
            return pd.Series([result] * self.data.N)
        elif pd.isna(result):
            return pd.Series([False] * self.data.N)
        else:
            return pd.Series([bool(result)] * self.data.N)

    def evaluate_in(self, in_range: tuple) -> pd.Series:
        """
        Evaluate an in range condition.

        Args:
            in_range: Tuple of (start, end) observation numbers (1-based)

        Returns:
            Boolean Series indicating which observations are in range
        """
        if in_range is None:
            return pd.Series([True] * self.data.N)

        start, end = in_range
        if start is None:
            start = 1
        if end is None or end == -1:
            end = self.data.N

        # Create mask (convert to 0-based)
        obs_nums = np.arange(1, self.data.N + 1)
        return pd.Series((obs_nums >= start) & (obs_nums <= end))

    def evaluate_combined(
        self, if_condition: Optional[str], in_range: Optional[tuple]
    ) -> pd.Series:
        """Evaluate combined if and in conditions."""
        if_mask = self.evaluate_if(if_condition)
        in_mask = self.evaluate_in(in_range)
        return if_mask & in_mask
