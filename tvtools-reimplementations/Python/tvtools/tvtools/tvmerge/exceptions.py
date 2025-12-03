"""Custom exception classes."""


class TVMergeError(Exception):
    """Base exception for tvmerge errors."""
    pass


class IDMismatchError(TVMergeError):
    """Raised when IDs don't match across datasets."""
    pass


class InvalidPeriodError(TVMergeError):
    """Raised when datasets contain invalid periods (start > stop)."""
    pass


class ColumnNotFoundError(TVMergeError):
    """Raised when required column is not found in dataset."""
    pass
