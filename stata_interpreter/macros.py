"""
Stata Macro System

Handles local and global macros, including:
- Local macros (`name')
- Global macros ($name, ${name})
- Scalar evaluation (`=expr')
- Extended macro functions (:word count, :type, etc.)
- Temporary names (tempvar, tempfile, tempname)
"""

import re
from typing import Any, Optional, Callable
import uuid


class MacroManager:
    """Manages Stata macros (local and global)."""

    def __init__(self):
        self.locals: dict[str, str] = {}
        self.globals: dict[str, str] = {}
        self.scalars: dict[str, float] = {}
        self.return_values: dict[str, Any] = {}  # r() values
        self.ereturn_values: dict[str, Any] = {}  # e() values
        self.sreturn_values: dict[str, Any] = {}  # s() values

        # Temporary object counters
        self._tempvar_counter = 0
        self._tempfile_counter = 0
        self._tempname_counter = 0

        # Track temporary names for cleanup
        self.temp_vars: list[str] = []
        self.temp_files: list[str] = []
        self.temp_names: list[str] = []

        # Expression evaluator (set by interpreter)
        self.eval_expr: Optional[Callable] = None

    def set_local(self, name: str, value: Any) -> None:
        """Set a local macro."""
        self.locals[name] = str(value) if value is not None else ""

    def get_local(self, name: str) -> str:
        """Get a local macro value."""
        return self.locals.get(name, "")

    def set_global(self, name: str, value: Any) -> None:
        """Set a global macro."""
        self.globals[name] = str(value) if value is not None else ""

    def get_global(self, name: str) -> str:
        """Get a global macro value."""
        return self.globals.get(name, "")

    def set_scalar(self, name: str, value: float) -> None:
        """Set a scalar value."""
        self.scalars[name] = value

    def get_scalar(self, name: str) -> Optional[float]:
        """Get a scalar value."""
        return self.scalars.get(name)

    def set_return(self, name: str, value: Any) -> None:
        """Set a return value (r(name))."""
        self.return_values[name] = value

    def get_return(self, name: str) -> Any:
        """Get a return value."""
        return self.return_values.get(name)

    def clear_return(self) -> None:
        """Clear all return values."""
        self.return_values.clear()

    def set_ereturn(self, name: str, value: Any) -> None:
        """Set an ereturn value (e(name))."""
        self.ereturn_values[name] = value

    def get_ereturn(self, name: str) -> Any:
        """Get an ereturn value."""
        return self.ereturn_values.get(name)

    def clear_ereturn(self) -> None:
        """Clear all ereturn values."""
        self.ereturn_values.clear()

    def new_tempvar(self) -> str:
        """Generate a new temporary variable name."""
        self._tempvar_counter += 1
        name = f"__tempvar_{self._tempvar_counter}__"
        self.temp_vars.append(name)
        return name

    def new_tempfile(self) -> str:
        """Generate a new temporary file path."""
        self._tempfile_counter += 1
        name = f"/tmp/stata_temp_{uuid.uuid4().hex[:8]}_{self._tempfile_counter}.dta"
        self.temp_files.append(name)
        return name

    def new_tempname(self) -> str:
        """Generate a new temporary name (for matrices, scalars)."""
        self._tempname_counter += 1
        name = f"__tempname_{self._tempname_counter}__"
        self.temp_names.append(name)
        return name

    def expand(self, text: str, max_depth: int = 10) -> str:
        """
        Expand all macros in text.

        Handles:
        - `local' -> local macro value
        - $global or ${global} -> global macro value
        - `=expr' -> evaluated expression
        - Nested macros
        """
        if not text:
            return text

        depth = 0
        while depth < max_depth:
            new_text = self._expand_once(text)
            if new_text == text:
                break
            text = new_text
            depth += 1

        return text

    def _expand_once(self, text: str) -> str:
        """Perform one pass of macro expansion."""
        result = []
        i = 0

        while i < len(text):
            # Check for local macro `name'
            if text[i] == "`":
                end = text.find("'", i + 1)
                if end != -1:
                    macro_content = text[i + 1 : end]

                    # Check for scalar evaluation `=expr'
                    if macro_content.startswith("="):
                        expr = macro_content[1:]
                        if self.eval_expr:
                            try:
                                value = self.eval_expr(expr)
                                result.append(str(value))
                            except Exception:
                                result.append("")
                        else:
                            result.append("")
                    else:
                        # Regular local macro - handle nested references
                        expanded_name = self._expand_once(macro_content)
                        value = self.get_local(expanded_name)
                        result.append(value)
                    i = end + 1
                    continue

            # Check for global macro $name or ${name}
            if text[i] == "$":
                if i + 1 < len(text) and text[i + 1] == "{":
                    # ${name} form
                    end = text.find("}", i + 2)
                    if end != -1:
                        name = text[i + 2 : end]
                        value = self.get_global(name)
                        result.append(value)
                        i = end + 1
                        continue
                else:
                    # $name form
                    match = re.match(r"\$([a-zA-Z_][a-zA-Z0-9_]*)", text[i:])
                    if match:
                        name = match.group(1)
                        value = self.get_global(name)
                        result.append(value)
                        i += len(match.group(0))
                        continue

            result.append(text[i])
            i += 1

        return "".join(result)

    def extended_macro_function(self, function: str, args: str) -> str:
        """
        Handle extended macro functions like :word count.

        Args:
            function: The function name (e.g., 'word count')
            args: The argument string

        Returns:
            Result as string
        """
        function = function.strip().lower()

        # Word count
        if function == "word count":
            words = args.split()
            return str(len(words))

        # Word N of
        match = re.match(r"word\s+(\d+)\s+of", function)
        if match:
            n = int(match.group(1))
            words = args.split()
            if 1 <= n <= len(words):
                return words[n - 1]
            return ""

        # Length
        if function in ("length", "strlen"):
            return str(len(args))

        # Upper/lower
        if function == "upper":
            return args.upper()
        if function == "lower":
            return args.lower()

        # Subinstr
        match = re.match(r'subinstr\s+"([^"]*)"\s+"([^"]*)"\s+"([^"]*)"', args)
        if match:
            original, find, replace = match.groups()
            return original.replace(find, replace)

        # List operations
        if function == "list uniq":
            words = args.split()
            seen = set()
            unique = []
            for w in words:
                if w not in seen:
                    seen.add(w)
                    unique.append(w)
            return " ".join(unique)

        if function == "list sort":
            words = args.split()
            return " ".join(sorted(words))

        # Type (would need data context)
        if function == "type":
            return "float"  # Default, needs data context

        # Variable label (would need data context)
        if function in ("variable label", "var label"):
            return ""  # Needs data context

        # Value label (would need data context)
        if function == "value label":
            return ""  # Needs data context

        # Format (would need data context)
        if function == "format":
            return "%9.0g"  # Default, needs data context

        return ""

    def parse_extended_macro(self, text: str) -> str:
        """
        Parse and evaluate extended macro syntax.

        Handles patterns like:
        - local n: word count `varlist'
        - local first: word 1 of `varlist'
        - local type: type varname
        """
        # Pattern: local name: function args
        match = re.match(r":\s*(.+)", text)
        if match:
            rest = match.group(1)

            # Word count
            if rest.startswith("word count "):
                args = rest[11:]
                return self.extended_macro_function("word count", args)

            # Word N of
            word_match = re.match(r"word\s+(\d+)\s+of\s+(.+)", rest)
            if word_match:
                n, args = word_match.groups()
                words = args.split()
                n = int(n)
                if 1 <= n <= len(words):
                    return words[n - 1]
                return ""

            # Length
            if rest.startswith("length "):
                return str(len(rest[7:]))

        return text

    def clear_locals(self) -> None:
        """Clear all local macros."""
        self.locals.clear()

    def clear_temps(self) -> None:
        """Clear temporary names."""
        self.temp_vars.clear()
        self.temp_files.clear()
        self.temp_names.clear()

    def push_scope(self) -> dict:
        """Save current local scope for nested programs."""
        return dict(self.locals)

    def pop_scope(self, saved: dict) -> None:
        """Restore a saved local scope."""
        self.locals = saved


class ReturnValues:
    """Manages return values from Stata commands."""

    def __init__(self):
        self.scalars: dict[str, float] = {}
        self.locals: dict[str, str] = {}
        self.matrices: dict[str, Any] = {}

    def clear(self) -> None:
        """Clear all return values."""
        self.scalars.clear()
        self.locals.clear()
        self.matrices.clear()

    def set_scalar(self, name: str, value: float) -> None:
        """Set r(name) scalar."""
        self.scalars[name] = value

    def get_scalar(self, name: str) -> Optional[float]:
        """Get r(name) scalar."""
        return self.scalars.get(name)

    def set_local(self, name: str, value: str) -> None:
        """Set r(name) local."""
        self.locals[name] = value

    def get_local(self, name: str) -> str:
        """Get r(name) local."""
        return self.locals.get(name, "")

    def get(self, name: str) -> Any:
        """Get any return value."""
        if name in self.scalars:
            return self.scalars[name]
        if name in self.locals:
            return self.locals[name]
        if name in self.matrices:
            return self.matrices[name]
        return None
