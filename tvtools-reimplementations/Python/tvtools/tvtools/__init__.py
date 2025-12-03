"""
tvtools - Time-Varying Analysis Tools for Python

Python reimplementation of Stata tvtools for time-varying exposure and event
analysis in survival studies.

Modules:
    - tvexpose: Create time-varying exposure variables
    - tvmerge: Merge multiple time-varying datasets
    - tvevent: Integrate events and competing risks

Example:
    >>> from tvtools import TVExpose, TVMerge, TVEvent
    >>> # Create time-varying exposures
    >>> result = TVExpose(...).run()
"""

__version__ = "0.1.0"
__author__ = "Tom Copeland"
__email__ = "tpcopeland@gmail.com"

# Import main classes (will be implemented by other agents)
# from .tvexpose import TVExpose
# from .tvmerge import TVMerge
# from .tvevent import TVEvent

__all__ = [
    "__version__",
    # "TVExpose",
    # "TVMerge",
    # "TVEvent",
]
