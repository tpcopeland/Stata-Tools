{smcl}
{* 25july2020}{...}
{cmd:help check}
{hline}

{title:Title}
{p 10}{bf:check}{p_end}

{title:Syntax}
{p 10}
{cmd:check}
{varlist}
[,
{cmdab:short}
]
{p_end}

{title:Description}

{p}Produces a table with: N, # Missing, % Missing, # Unique Values, Variable Type, Variable Format, Mean, Standard Deviation, Minimum, 25th Percentile, Median, 75th Percentile, Maximum, and Variable Label. May be used with one or multiple variables{p_end}

{title:Options}

{p 4 8 2}{opt short} removes the descriptive statistics{p_end}

{title:Authors}

{pstd}
Revisions by: {break}
Timothy P Copeland {break}
Division of Nephrology {break}
University of California, San Francisco{p_end}

{pstd}
Original concept & code by: {break}
Michael N Mitchell{p_end}

{title:Also see}

{psee}
Online: {stata ssc describe unique: ssc describe unique}, {stata ssc describe nmissing: ssc describe mdesc}
{p_end}
