"""Custom exceptions for TVEvent module."""


class TVEventError(Exception):
    """Base exception for TVEvent errors."""
    pass


class TVEventValidationError(TVEventError):
    """Raised when input validation fails."""
    pass


class TVEventProcessingError(TVEventError):
    """Raised when processing encounters an error."""
    pass
