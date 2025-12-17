"""
tvtools - Time-Varying Exposure Analysis Tools

This package provides tools for creating time-varying exposure variables
for survival analysis, with functionality similar to the Stata tvtools commands.

Main Functions:
- tvexpose: Create time-varying exposure variables from period-based data
- tvmerge: Merge multiple time-varying exposure datasets
- tvevent: Integrate outcome events and competing risks
"""

from .tvexpose import tvexpose
from .tvmerge import tvmerge
from .tvevent import tvevent

__version__ = "0.2.0"
__author__ = "Timothy P. Copeland"
__all__ = ["tvexpose", "tvmerge", "tvevent"]
