"""
tvtools - Time-Varying Exposure Analysis Tools for Python

A Python implementation of the Stata tvtools commands for managing
time-varying exposures in longitudinal and survival analysis.
"""

from setuptools import setup, find_packages

setup(
    name="tvtools",
    version="0.2.0",
    author="Timothy P. Copeland",
    author_email="timothy.copeland@ki.se",
    description="Time-varying exposure and event analysis tools",
    long_description=open("README.md").read() if __import__("os").path.exists("README.md") else "",
    long_description_content_type="text/markdown",
    url="https://github.com/tpcopeland/Stata-Tools",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Scientific/Engineering :: Medical Science Apps.",
    ],
    python_requires=">=3.8",
    install_requires=[
        "pandas>=1.3.0",
        "numpy>=1.20.0",
    ],
    extras_require={
        "dev": [
            "pytest>=6.0.0",
            "pytest-cov>=2.0.0",
        ],
        "stata": [
            "pyreadstat>=1.1.0",
        ],
    },
)
