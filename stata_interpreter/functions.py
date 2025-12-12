"""
Stata Built-in Functions

Implements common Stata functions for use in expressions:
- Mathematical functions (log, exp, sqrt, abs, etc.)
- String functions (substr, strlen, upper, lower, etc.)
- Date functions (date, mdy, year, month, day, etc.)
- Statistical functions (min, max, sum, etc.)
- Conditional functions (cond, inlist, inrange, missing)
"""

import numpy as np
import pandas as pd
from typing import Any, Union, Optional
import re
from datetime import datetime, date
import math

# Type aliases
Numeric = Union[int, float, np.number, pd.Series]
Value = Union[Numeric, str, pd.Series]

# Module-level state for regex functions
_last_regex_match: Optional[re.Match] = None


class StataFunctions:
    """Collection of Stata built-in functions."""

    # =========================================================================
    # Mathematical Functions
    # =========================================================================

    @staticmethod
    def abs(x: Numeric) -> Numeric:
        """Absolute value."""
        return np.abs(x)

    @staticmethod
    def ceil(x: Numeric) -> Numeric:
        """Ceiling (round up)."""
        return np.ceil(x)

    @staticmethod
    def floor(x: Numeric) -> Numeric:
        """Floor (round down)."""
        return np.floor(x)

    @staticmethod
    def round(x: Numeric, y: Numeric = 1) -> Numeric:
        """Round to nearest multiple of y."""
        return np.round(x / y) * y

    @staticmethod
    def int(x: Numeric) -> Numeric:
        """Integer part (truncate toward zero)."""
        return np.trunc(x)

    @staticmethod
    def exp(x: Numeric) -> Numeric:
        """Exponential function."""
        return np.exp(x)

    @staticmethod
    def ln(x: Numeric) -> Numeric:
        """Natural logarithm."""
        return np.log(x)

    @staticmethod
    def log(x: Numeric) -> Numeric:
        """Natural logarithm (alias for ln)."""
        return np.log(x)

    @staticmethod
    def log10(x: Numeric) -> Numeric:
        """Base-10 logarithm."""
        return np.log10(x)

    @staticmethod
    def sqrt(x: Numeric) -> Numeric:
        """Square root."""
        return np.sqrt(x)

    @staticmethod
    def sign(x: Numeric) -> Numeric:
        """Sign of x (-1, 0, or 1)."""
        return np.sign(x)

    @staticmethod
    def mod(x: Numeric, y: Numeric) -> Numeric:
        """Modulo (remainder)."""
        return np.mod(x, y)

    @staticmethod
    def min(*args) -> Numeric:
        """Minimum of arguments (row-wise for Series)."""
        if len(args) == 1 and isinstance(args[0], (list, tuple)):
            args = args[0]

        # Handle pandas Series
        if any(isinstance(a, pd.Series) for a in args):
            df = pd.DataFrame({f"c{i}": a for i, a in enumerate(args)})
            return df.min(axis=1)

        return np.min(args)

    @staticmethod
    def max(*args) -> Numeric:
        """Maximum of arguments (row-wise for Series)."""
        if len(args) == 1 and isinstance(args[0], (list, tuple)):
            args = args[0]

        if any(isinstance(a, pd.Series) for a in args):
            df = pd.DataFrame({f"c{i}": a for i, a in enumerate(args)})
            return df.max(axis=1)

        return np.max(args)

    @staticmethod
    def sum(*args) -> Numeric:
        """Sum of arguments."""
        return np.sum(args)

    # =========================================================================
    # Trigonometric Functions
    # =========================================================================

    @staticmethod
    def sin(x: Numeric) -> Numeric:
        """Sine."""
        return np.sin(x)

    @staticmethod
    def cos(x: Numeric) -> Numeric:
        """Cosine."""
        return np.cos(x)

    @staticmethod
    def tan(x: Numeric) -> Numeric:
        """Tangent."""
        return np.tan(x)

    @staticmethod
    def asin(x: Numeric) -> Numeric:
        """Arc sine."""
        return np.arcsin(x)

    @staticmethod
    def acos(x: Numeric) -> Numeric:
        """Arc cosine."""
        return np.arccos(x)

    @staticmethod
    def atan(x: Numeric) -> Numeric:
        """Arc tangent."""
        return np.arctan(x)

    @staticmethod
    def atan2(y: Numeric, x: Numeric) -> Numeric:
        """Two-argument arc tangent."""
        return np.arctan2(y, x)

    # =========================================================================
    # String Functions
    # =========================================================================

    @staticmethod
    def strlen(s: Union[str, pd.Series]) -> Union[int, pd.Series]:
        """Length of string."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.len()
        return len(str(s))

    @staticmethod
    def substr(s: Union[str, pd.Series], start: int, length: int) -> Union[str, pd.Series]:
        """Substring (1-based start position)."""
        # Ensure start and length are integers
        start = int(start)
        length = int(length)
        if isinstance(s, pd.Series):
            # Stata uses 1-based indexing, use .str.slice() method
            return s.astype(str).str.slice(start - 1, start - 1 + length)
        s = str(s)
        return s[start - 1 : start - 1 + length]

    @staticmethod
    def subinstr(
        s: Union[str, pd.Series], find: str, replace: str, count: int = 0
    ) -> Union[str, pd.Series]:
        """Replace occurrences of find with replace."""
        if isinstance(s, pd.Series):
            if count == 0:
                return s.astype(str).str.replace(find, replace, regex=False)
            else:
                return s.astype(str).str.replace(find, replace, n=count, regex=False)
        if count == 0:
            return str(s).replace(find, replace)
        return str(s).replace(find, replace, count)

    @staticmethod
    def strupper(s: Union[str, pd.Series]) -> Union[str, pd.Series]:
        """Convert to uppercase."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.upper()
        return str(s).upper()

    @staticmethod
    def strlower(s: Union[str, pd.Series]) -> Union[str, pd.Series]:
        """Convert to lowercase."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.lower()
        return str(s).lower()

    @staticmethod
    def upper(s: Union[str, pd.Series]) -> Union[str, pd.Series]:
        """Convert to uppercase (alias)."""
        return StataFunctions.strupper(s)

    @staticmethod
    def lower(s: Union[str, pd.Series]) -> Union[str, pd.Series]:
        """Convert to lowercase (alias)."""
        return StataFunctions.strlower(s)

    @staticmethod
    def proper(s: Union[str, pd.Series]) -> Union[str, pd.Series]:
        """Convert to proper case (title case)."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.title()
        return str(s).title()

    @staticmethod
    def strtrim(s: Union[str, pd.Series]) -> Union[str, pd.Series]:
        """Trim leading and trailing whitespace."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.strip()
        return str(s).strip()

    @staticmethod
    def ltrim(s: Union[str, pd.Series]) -> Union[str, pd.Series]:
        """Trim leading whitespace."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.lstrip()
        return str(s).lstrip()

    @staticmethod
    def rtrim(s: Union[str, pd.Series]) -> Union[str, pd.Series]:
        """Trim trailing whitespace."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.rstrip()
        return str(s).rstrip()

    @staticmethod
    def trim(s: Union[str, pd.Series]) -> Union[str, pd.Series]:
        """Trim whitespace (alias for strtrim)."""
        return StataFunctions.strtrim(s)

    @staticmethod
    def strpos(haystack: Union[str, pd.Series], needle: str) -> Union[int, pd.Series]:
        """Find position of substring (1-based, 0 if not found)."""
        if isinstance(haystack, pd.Series):
            result = haystack.astype(str).str.find(needle)
            return (result + 1).where(result >= 0, 0)
        pos = str(haystack).find(needle)
        return pos + 1 if pos >= 0 else 0

    @staticmethod
    def strmatch(s: Union[str, pd.Series], pattern: str) -> Union[int, pd.Series]:
        """Check if string matches pattern (with * and ? wildcards)."""
        # Convert Stata wildcards to regex
        regex_pattern = pattern.replace("*", ".*").replace("?", ".")
        regex_pattern = f"^{regex_pattern}$"

        if isinstance(s, pd.Series):
            return s.astype(str).str.match(regex_pattern).astype(int)
        return 1 if re.match(regex_pattern, str(s)) else 0

    @staticmethod
    def regexm(s: Union[str, pd.Series], pattern: str) -> Union[int, pd.Series]:
        """Check if string matches regex pattern and store match for regexs()."""
        global _last_regex_match
        if isinstance(s, pd.Series):
            return s.astype(str).str.contains(pattern, regex=True, na=False).astype(int)
        match = re.search(pattern, str(s))
        _last_regex_match = match
        return 1 if match else 0

    @staticmethod
    def regexr(
        s: Union[str, pd.Series], pattern: str, replacement: str
    ) -> Union[str, pd.Series]:
        """Replace first regex match."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.replace(pattern, replacement, n=1, regex=True)
        return re.sub(pattern, replacement, str(s), count=1)

    @staticmethod
    def regexs(n: int) -> str:
        """Return captured group from most recent regexm()."""
        global _last_regex_match
        if _last_regex_match is None:
            return ""
        try:
            n = int(n)
            return _last_regex_match.group(n) or ""
        except (IndexError, AttributeError):
            return ""

    @staticmethod
    def string(x: Numeric, format: str = None) -> Union[str, pd.Series]:
        """
        Convert number to string, optionally with format.

        Stata syntax: string(x) or string(x, "%fmt")
        Common formats: %02.0f (zero-padded 2 digits), %9.2f, etc.
        """
        if format is not None:
            # Parse Stata format and convert to Python format
            # Handle common formats like "%02.0f", "%9.2f", etc.
            format = str(format).strip('"').strip("'")
            try:
                # Convert Stata format to Python format
                # Stata: %02.0f -> Python: {:02.0f}
                if format.startswith("%"):
                    py_fmt = format[1:]  # Remove leading %
                    # Handle common patterns
                    if isinstance(x, pd.Series):
                        return x.apply(lambda v: f"{v:{py_fmt}}" if pd.notna(v) else "")
                    return f"{x:{py_fmt}}"
            except (ValueError, TypeError):
                pass

        if isinstance(x, pd.Series):
            return x.astype(str)
        return str(x)

    @staticmethod
    def real(s: Union[str, pd.Series]) -> Union[float, pd.Series]:
        """Convert string to number."""
        if isinstance(s, pd.Series):
            return pd.to_numeric(s, errors="coerce")
        try:
            return float(s)
        except (ValueError, TypeError):
            return np.nan

    @staticmethod
    def word(s: Union[str, pd.Series], n: int) -> Union[str, pd.Series]:
        """Extract nth word from string (1-based)."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.split().str[n - 1].fillna("")
        words = str(s).split()
        if 1 <= n <= len(words):
            return words[n - 1]
        return ""

    @staticmethod
    def wordcount(s: Union[str, pd.Series]) -> Union[int, pd.Series]:
        """Count words in string."""
        if isinstance(s, pd.Series):
            return s.astype(str).str.split().str.len()
        return len(str(s).split())

    # =========================================================================
    # Date Functions
    # =========================================================================

    @staticmethod
    def date(
        s: Union[str, pd.Series], format: str
    ) -> Union[int, pd.Series]:
        """
        Convert string to Stata date (days since 1960-01-01).

        Common formats: "DMY", "MDY", "YMD"
        Handles various input formats including:
        - "12 Dec 2025" (day monthname year)
        - "12/12/2025" (with separators)
        - "12122025" (continuous digits)
        """
        stata_epoch = datetime(1960, 1, 1)

        def parse_date(date_str: str, fmt: str) -> int:
            try:
                fmt_upper = fmt.upper()
                date_str = date_str.strip()

                # Try multiple parsing strategies
                # Strategy 1: Handle "DD Mon YYYY" format (like "12 Dec 2025")
                if fmt_upper == "DMY":
                    # Try day month-name year format first
                    for date_fmt in ["%d %b %Y", "%d %B %Y", "%d/%m/%Y", "%d-%m-%Y", "%d%m%Y"]:
                        try:
                            dt = datetime.strptime(date_str, date_fmt)
                            return (dt - stata_epoch).days
                        except ValueError:
                            continue
                elif fmt_upper == "MDY":
                    for date_fmt in ["%m/%d/%Y", "%m-%d-%Y", "%m%d%Y", "%b %d %Y", "%B %d %Y"]:
                        try:
                            dt = datetime.strptime(date_str, date_fmt)
                            return (dt - stata_epoch).days
                        except ValueError:
                            continue
                elif fmt_upper == "YMD":
                    for date_fmt in ["%Y/%m/%d", "%Y-%m-%d", "%Y%m%d", "%Y %b %d", "%Y %B %d"]:
                        try:
                            dt = datetime.strptime(date_str, date_fmt)
                            return (dt - stata_epoch).days
                        except ValueError:
                            continue

                # Fallback: remove common separators and try basic format
                clean_str = date_str.replace("/", "").replace("-", "").replace(" ", "")
                format_map = {
                    "DMY": "%d%m%Y",
                    "MDY": "%m%d%Y",
                    "YMD": "%Y%m%d",
                }
                py_fmt = format_map.get(fmt_upper, "%Y%m%d")
                dt = datetime.strptime(clean_str, py_fmt)
                return (dt - stata_epoch).days

            except (ValueError, AttributeError):
                return np.nan

        if isinstance(s, pd.Series):
            return s.apply(lambda x: parse_date(str(x), format))
        return parse_date(str(s), format)

    @staticmethod
    def mdy(month: int, day: int, year: int) -> int:
        """Create Stata date from month, day, year."""
        stata_epoch = datetime(1960, 1, 1)
        try:
            dt = datetime(int(year), int(month), int(day))
            return (dt - stata_epoch).days
        except (ValueError, TypeError):
            return np.nan

    @staticmethod
    def dmy(day: int, month: int, year: int) -> int:
        """Create Stata date from day, month, year."""
        return StataFunctions.mdy(month, day, year)

    @staticmethod
    def ymd(year: int, month: int, day: int) -> int:
        """Create Stata date from year, month, day."""
        return StataFunctions.mdy(month, day, year)

    @staticmethod
    def year(d: Union[int, pd.Series]) -> Union[int, pd.Series]:
        """Extract year from Stata date."""
        stata_epoch = pd.Timestamp("1960-01-01")
        if isinstance(d, pd.Series):
            return (stata_epoch + pd.to_timedelta(d, unit="D")).dt.year
        try:
            dt = stata_epoch + pd.Timedelta(days=int(d))
            return dt.year
        except (ValueError, TypeError):
            return np.nan

    @staticmethod
    def month(d: Union[int, pd.Series]) -> Union[int, pd.Series]:
        """Extract month from Stata date."""
        stata_epoch = pd.Timestamp("1960-01-01")
        if isinstance(d, pd.Series):
            return (stata_epoch + pd.to_timedelta(d, unit="D")).dt.month
        try:
            dt = stata_epoch + pd.Timedelta(days=int(d))
            return dt.month
        except (ValueError, TypeError):
            return np.nan

    @staticmethod
    def day(d: Union[int, pd.Series]) -> Union[int, pd.Series]:
        """Extract day from Stata date."""
        stata_epoch = pd.Timestamp("1960-01-01")
        if isinstance(d, pd.Series):
            return (stata_epoch + pd.to_timedelta(d, unit="D")).dt.day
        try:
            dt = stata_epoch + pd.Timedelta(days=int(d))
            return dt.day
        except (ValueError, TypeError):
            return np.nan

    @staticmethod
    def dow(d: Union[int, pd.Series]) -> Union[int, pd.Series]:
        """Day of week (0=Sunday, 1=Monday, ..., 6=Saturday)."""
        stata_epoch = pd.Timestamp("1960-01-01")
        if isinstance(d, pd.Series):
            # pandas: Monday=0, Sunday=6
            # Stata: Sunday=0, Saturday=6
            return ((stata_epoch + pd.to_timedelta(d, unit="D")).dt.dayofweek + 1) % 7
        try:
            dt = stata_epoch + pd.Timedelta(days=int(d))
            return (dt.dayofweek + 1) % 7
        except (ValueError, TypeError):
            return np.nan

    @staticmethod
    def doy(d: Union[int, pd.Series]) -> Union[int, pd.Series]:
        """Day of year (1-366)."""
        stata_epoch = pd.Timestamp("1960-01-01")
        if isinstance(d, pd.Series):
            return (stata_epoch + pd.to_timedelta(d, unit="D")).dt.dayofyear
        try:
            dt = stata_epoch + pd.Timedelta(days=int(d))
            return dt.dayofyear
        except (ValueError, TypeError):
            return np.nan

    @staticmethod
    def week(d: Union[int, pd.Series]) -> Union[int, pd.Series]:
        """Week of year (1-52)."""
        stata_epoch = pd.Timestamp("1960-01-01")
        if isinstance(d, pd.Series):
            return (stata_epoch + pd.to_timedelta(d, unit="D")).dt.isocalendar().week
        try:
            dt = stata_epoch + pd.Timedelta(days=int(d))
            return dt.isocalendar()[1]
        except (ValueError, TypeError):
            return np.nan

    @staticmethod
    def quarter(d: Union[int, pd.Series]) -> Union[int, pd.Series]:
        """Quarter of year (1-4)."""
        stata_epoch = pd.Timestamp("1960-01-01")
        if isinstance(d, pd.Series):
            return (stata_epoch + pd.to_timedelta(d, unit="D")).dt.quarter
        try:
            dt = stata_epoch + pd.Timedelta(days=int(d))
            return dt.quarter
        except (ValueError, TypeError):
            return np.nan

    @staticmethod
    def today() -> int:
        """Return today's date as Stata date."""
        stata_epoch = datetime(1960, 1, 1)
        return (datetime.now() - stata_epoch).days

    # =========================================================================
    # Conditional Functions
    # =========================================================================

    @staticmethod
    def cond(
        condition: Union[bool, pd.Series],
        if_true: Value,
        if_false: Value,
        if_missing: Optional[Value] = None,
    ) -> Value:
        """Conditional expression."""
        if isinstance(condition, pd.Series):
            result = np.where(condition, if_true, if_false)
            if if_missing is not None:
                result = np.where(condition.isna(), if_missing, result)
            return pd.Series(result, index=condition.index)

        if pd.isna(condition):
            return if_missing if if_missing is not None else np.nan
        return if_true if condition else if_false

    @staticmethod
    def inlist(x: Value, *values) -> Union[bool, pd.Series]:
        """Check if x is in the list of values."""
        if isinstance(x, pd.Series):
            return x.isin(values)
        return x in values

    @staticmethod
    def inrange(x: Numeric, low: Numeric, high: Numeric) -> Union[bool, pd.Series]:
        """Check if x is in range [low, high]."""
        if isinstance(x, pd.Series):
            return (x >= low) & (x <= high)
        return low <= x <= high

    @staticmethod
    def missing(x: Value) -> Union[bool, pd.Series]:
        """Check if x is missing."""
        if isinstance(x, pd.Series):
            return x.isna()
        return pd.isna(x)

    @staticmethod
    def coalesce(*args) -> Value:
        """Return first non-missing value."""
        if any(isinstance(a, pd.Series) for a in args):
            # Build DataFrame and use first valid
            df = pd.DataFrame({f"c{i}": a for i, a in enumerate(args)})
            return df.bfill(axis=1).iloc[:, 0]

        for arg in args:
            if not pd.isna(arg):
                return arg
        return np.nan

    # =========================================================================
    # Random Number Functions
    # =========================================================================

    @staticmethod
    def runiform(a: float = 0, b: float = 1) -> float:
        """Uniform random number in [a, b)."""
        return np.random.uniform(a, b)

    @staticmethod
    def rnormal(mean: float = 0, sd: float = 1) -> float:
        """Normal random number."""
        return np.random.normal(mean, sd)

    @staticmethod
    def rbinomial(n: int, p: float) -> int:
        """Binomial random number."""
        return np.random.binomial(n, p)

    @staticmethod
    def rpoisson(mu: float) -> int:
        """Poisson random number."""
        return np.random.poisson(mu)

    @staticmethod
    def rexponential(b: float) -> float:
        """Exponential random number with mean b."""
        return np.random.exponential(b)

    # =========================================================================
    # Statistical Distribution Functions
    # =========================================================================

    @staticmethod
    def normal(z: Numeric) -> Numeric:
        """Standard normal CDF."""
        from scipy import stats

        return stats.norm.cdf(z)

    @staticmethod
    def normalden(z: Numeric) -> Numeric:
        """Standard normal PDF."""
        from scipy import stats

        return stats.norm.pdf(z)

    @staticmethod
    def invnormal(p: Numeric) -> Numeric:
        """Inverse standard normal (quantile function)."""
        from scipy import stats

        return stats.norm.ppf(p)

    @staticmethod
    def chi2(df: int, x: Numeric) -> Numeric:
        """Chi-square CDF."""
        from scipy import stats

        return stats.chi2.cdf(x, df)

    @staticmethod
    def invchi2(df: int, p: Numeric) -> Numeric:
        """Inverse chi-square."""
        from scipy import stats

        return stats.chi2.ppf(p, df)

    @staticmethod
    def t(df: int, x: Numeric) -> Numeric:
        """t-distribution CDF."""
        from scipy import stats

        return stats.t.cdf(x, df)

    @staticmethod
    def invt(df: int, p: Numeric) -> Numeric:
        """Inverse t-distribution."""
        from scipy import stats

        return stats.t.ppf(p, df)

    @staticmethod
    def F(df1: int, df2: int, x: Numeric) -> Numeric:
        """F-distribution CDF."""
        from scipy import stats

        return stats.f.cdf(x, df1, df2)

    @staticmethod
    def invF(df1: int, df2: int, p: Numeric) -> Numeric:
        """Inverse F-distribution."""
        from scipy import stats

        return stats.f.ppf(p, df1, df2)


# Create a dictionary of all available functions for easy lookup
STATA_FUNCTIONS = {
    # Math
    "abs": StataFunctions.abs,
    "ceil": StataFunctions.ceil,
    "floor": StataFunctions.floor,
    "round": StataFunctions.round,
    "int": StataFunctions.int,
    "exp": StataFunctions.exp,
    "ln": StataFunctions.ln,
    "log": StataFunctions.log,
    "log10": StataFunctions.log10,
    "sqrt": StataFunctions.sqrt,
    "sign": StataFunctions.sign,
    "mod": StataFunctions.mod,
    "min": StataFunctions.min,
    "max": StataFunctions.max,
    "sum": StataFunctions.sum,
    # Trig
    "sin": StataFunctions.sin,
    "cos": StataFunctions.cos,
    "tan": StataFunctions.tan,
    "asin": StataFunctions.asin,
    "acos": StataFunctions.acos,
    "atan": StataFunctions.atan,
    "atan2": StataFunctions.atan2,
    # String
    "strlen": StataFunctions.strlen,
    "substr": StataFunctions.substr,
    "subinstr": StataFunctions.subinstr,
    "strupper": StataFunctions.strupper,
    "strlower": StataFunctions.strlower,
    "upper": StataFunctions.upper,
    "lower": StataFunctions.lower,
    "proper": StataFunctions.proper,
    "strtrim": StataFunctions.strtrim,
    "ltrim": StataFunctions.ltrim,
    "rtrim": StataFunctions.rtrim,
    "trim": StataFunctions.trim,
    "strpos": StataFunctions.strpos,
    "strmatch": StataFunctions.strmatch,
    "regexm": StataFunctions.regexm,
    "regexr": StataFunctions.regexr,
    "string": StataFunctions.string,
    "real": StataFunctions.real,
    "word": StataFunctions.word,
    "wordcount": StataFunctions.wordcount,
    # Date
    "date": StataFunctions.date,
    "mdy": StataFunctions.mdy,
    "dmy": StataFunctions.dmy,
    "ymd": StataFunctions.ymd,
    "year": StataFunctions.year,
    "month": StataFunctions.month,
    "day": StataFunctions.day,
    "dow": StataFunctions.dow,
    "doy": StataFunctions.doy,
    "week": StataFunctions.week,
    "quarter": StataFunctions.quarter,
    "today": StataFunctions.today,
    # Conditional
    "cond": StataFunctions.cond,
    "inlist": StataFunctions.inlist,
    "inrange": StataFunctions.inrange,
    "missing": StataFunctions.missing,
    "coalesce": StataFunctions.coalesce,
    # Random
    "runiform": StataFunctions.runiform,
    "rnormal": StataFunctions.rnormal,
    "rbinomial": StataFunctions.rbinomial,
    "rpoisson": StataFunctions.rpoisson,
    "rexponential": StataFunctions.rexponential,
    # Statistical distributions
    "normal": StataFunctions.normal,
    "normalden": StataFunctions.normalden,
    "invnormal": StataFunctions.invnormal,
    "chi2": StataFunctions.chi2,
    "invchi2": StataFunctions.invchi2,
    "ttail": StataFunctions.t,  # alias
    "invttail": StataFunctions.invt,  # alias
    "Ftail": StataFunctions.F,  # alias
}


def c(name: str) -> Any:
    """
    Return Stata system constant.

    Common constants:
    - c(pwd) - current working directory
    - c(current_date) - current date
    - c(N) - number of observations (requires data context)
    - c(k) - number of variables (requires data context)
    - c(os) - operating system
    - c(pi) - value of pi
    """
    import os
    import sys
    from datetime import datetime

    name_lower = name.lower() if isinstance(name, str) else str(name).lower()

    constants = {
        "pwd": os.getcwd(),
        "current_date": datetime.now().strftime("%d %b %Y"),
        "current_time": datetime.now().strftime("%H:%M:%S"),
        "os": sys.platform,
        "pi": np.pi,
        "e": np.e,
        "maxbyte": 100,
        "maxint": 32740,
        "maxlong": 2147483620,
        "maxfloat": 1.7014117e38,
        "maxdouble": 8.9884656743e307,
        "mindouble": -8.9884656743e307,
        "epsfloat": 1.1920929e-7,
        "epsdouble": 2.2204460493e-16,
        "stata_version": 18.0,
        "version": 18.0,
        "rc": 0,  # Default return code
        "linesize": 79,
        "pagesize": 23,
    }

    return constants.get(name_lower, "")


# Add c() to STATA_FUNCTIONS
STATA_FUNCTIONS["c"] = c
