"""
Stata Interpreter for Python

A Python-based interpreter for Stata .ado files focused on data management
and manipulation. Uses pandas as the data backend.

This is designed for testing Stata .ado files without needing actual Stata access.
It supports a subset of Stata commands focused on data management.

Usage:
    from stata_interpreter import StataInterpreter

    interp = StataInterpreter()
    interp.run_file("myprogram.ado")
    interp.run("generate x = y * 2")
"""

from .interpreter import StataInterpreter
from .data import StataData
from .parser import StataParser
from .macros import MacroManager

__version__ = "0.1.0"
__all__ = ["StataInterpreter", "StataData", "StataParser", "MacroManager"]
