"""
Setup script for tvtools package.

This file exists for backward compatibility with tools that don't support
pyproject.toml. Modern installations should use:

    pip install .

or for development:

    pip install -e .
"""

from setuptools import setup

# Read version from pyproject.toml
try:
    import tomllib
except ImportError:
    # Python < 3.11
    try:
        import tomli as tomllib
    except ImportError:
        # Fallback: parse manually
        import re

        with open("pyproject.toml", "r") as f:
            content = f.read()
            version_match = re.search(r'version\s*=\s*"([^"]+)"', content)
            __version__ = version_match.group(1) if version_match else "0.1.0"
else:
    with open("pyproject.toml", "rb") as f:
        pyproject = tomllib.load(f)
        __version__ = pyproject["project"]["version"]

setup(
    name="tvtools",
    version=__version__,
    description="Python reimplementation of Stata tvtools: time-varying exposure and event analysis",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    author="Tom Copeland",
    author_email="tpcopeland@gmail.com",
    url="https://github.com/tpcopeland/Stata-Tools",
    packages=["tvtools", "tvtools.tvevent", "tvtools.tvexpose", "tvtools.tvmerge", "tvtools.utils"],
    python_requires=">=3.8",
    install_requires=[
        "pandas>=1.5.0",
        "numpy>=1.23.0",
    ],
    extras_require={
        "parallel": ["joblib>=1.2.0"],
        "dev": [
            "pytest>=7.2.0",
            "pytest-cov>=4.0.0",
            "black>=22.0.0",
            "mypy>=0.990",
            "ruff>=0.0.200",
        ],
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Scientific/Engineering",
    ],
    license="MIT",
)
