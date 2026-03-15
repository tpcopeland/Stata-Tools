{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "mlearn" "help mlearn"}{...}
{vieweralsosee "mlearn_train" "help mlearn_train"}{...}
{viewerjumpto "Syntax" "mlearn_setup##syntax"}{...}
{viewerjumpto "Description" "mlearn_setup##description"}{...}
{viewerjumpto "Options" "mlearn_setup##options"}{...}
{viewerjumpto "Remarks" "mlearn_setup##remarks"}{...}
{viewerjumpto "Examples" "mlearn_setup##examples"}{...}
{viewerjumpto "Stored results" "mlearn_setup##results"}{...}
{viewerjumpto "Author" "mlearn_setup##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:mlearn setup} {hline 2}}Check and install Python dependencies{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Check dependency status

{p 8 17 2}
{cmd:mlearn setup}
{cmd:,}
{opt ch:eck}

{pstd}
Install packages

{p 8 17 2}
{cmd:mlearn setup}
{cmd:,}
{opt inst:all(string)}

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt ch:eck}}check which Python packages are installed{p_end}
{synopt:{opt inst:all(string)}}install packages: {cmd:core}, {cmd:xgboost}, {cmd:lightgbm}, {cmd:shap}, {cmd:all}, or a custom package name{p_end}
{synoptline}

{pstd}
One of {opt check} or {opt install()} must be specified.


{marker description}{...}
{title:Description}

{pstd}
{cmd:mlearn setup} checks whether the Python dependencies required by
{cmd:mlearn} are installed and optionally installs missing packages. It
requires Stata 16+ with Python integration configured.

{pstd}
{cmd:mlearn} requires Python with numpy, scikit-learn, and joblib as core
dependencies. Optional packages include xgboost, lightgbm, and shap.


{marker options}{...}
{title:Options}

{phang}
{opt check} reports the Python version and the installation status of all
core and optional dependencies. Core dependencies are numpy, scikit-learn,
and joblib. Optional dependencies are xgboost, lightgbm, and shap.

{phang}
{opt install(string)} installs the specified package group or individual
package name. Recognized group names are:

{p2colset 9 22 24 2}{...}
{p2col:{cmd:core}}numpy, scikit-learn, joblib{p_end}
{p2col:{cmd:xgboost}}xgboost{p_end}
{p2col:{cmd:lightgbm}}lightgbm{p_end}
{p2col:{cmd:shap}}shap{p_end}
{p2col:{cmd:all}}all of the above{p_end}
{p2colreset}{...}

{pmore}
Any other string is treated as a pip package name and passed to the
Python installer directly.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:First-time setup}

{pstd}
Run {cmd:mlearn setup, check} to see the status of all dependencies, then
install missing packages as needed. A typical first-time setup:

{phang2}{cmd:. mlearn setup, check}{p_end}
{phang2}{cmd:. mlearn setup, install(all)}{p_end}

{pstd}
{bf:Python configuration}

{pstd}
Stata's {cmd:python:} directive must be configured before using {cmd:mlearn}.
See {cmd:help python} for details. The Python interpreter used by Stata can
be queried with {cmd:python query}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Check all dependencies}

{phang2}{cmd:. mlearn setup, check}{p_end}

{pstd}
{bf:Example 2: Install core dependencies}

{phang2}{cmd:. mlearn setup, install(core)}{p_end}

{pstd}
{bf:Example 3: Install all dependencies (core + optional)}

{phang2}{cmd:. mlearn setup, install(all)}{p_end}

{pstd}
{bf:Example 4: Install only XGBoost}

{phang2}{cmd:. mlearn setup, install(xgboost)}{p_end}

{pstd}
{bf:Example 5: Install only SHAP}

{phang2}{cmd:. mlearn setup, install(shap)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mlearn setup, check} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(python_version)}}Python version string{p_end}
{synopt:{cmd:r(core_ok)}}{cmd:1} if all core dependencies are installed, {cmd:0} otherwise{p_end}

{pstd}
{cmd:mlearn setup, install()} does not store results.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb mlearn}, {helpb mlearn_train}, {helpb python}

{hline}
