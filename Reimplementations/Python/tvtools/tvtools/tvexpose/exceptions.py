"""Custom exceptions for tvexpose module."""


class TVExposeError(Exception):
    """Base exception for tvexpose errors."""
    pass


class ValidationError(TVExposeError):
    """Exception raised for input validation errors."""
    pass
