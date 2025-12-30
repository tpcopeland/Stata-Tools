{smcl}
{* *! version 1.0.3  13dec2025}{...}
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

{pstd}
{cmd:check} provides a comprehensive summary of one or more variables, displaying both data quality
metrics and descriptive statistics in a single table. This command is particularly useful for
initial data exploration and validation, as it combines information typically obtained from
multiple commands ({cmd:codebook}, {cmd:summarize}, {cmd:tabulate}, etc.) into one convenient output.
{p_end}

{pstd}
The output table includes the following information for each variable:
{p_end}

{phang2}• N: Total number of observations{p_end}
{phang2}• # Missing: Count of missing values{p_end}
{phang2}• % Missing: Percentage of observations that are missing{p_end}
{phang2}• # Unique Values: Number of distinct values{p_end}
{phang2}• Variable Type: Storage type (byte, int, long, float, double, string){p_end}
{phang2}• Variable Format: Display format{p_end}
{phang2}• Mean: Arithmetic mean (for numeric variables){p_end}
{phang2}• Standard Deviation: SD (for numeric variables){p_end}
{phang2}• Minimum: Smallest value{p_end}
{phang2}• 25th Percentile: First quartile{p_end}
{phang2}• Median: 50th percentile{p_end}
{phang2}• 75th Percentile: Third quartile{p_end}
{phang2}• Maximum: Largest value{p_end}
{phang2}• Variable Label: Descriptive label if defined{p_end}

{pstd}
{bf:Note on missing values:} When all observations for a variable are missing,
statistics (mean, SD, min, max, percentiles) will display as missing (".").
The N will show 0, and % Missing will show 100. This is expected behavior
and indicates the variable has no valid data.
{p_end}

{title:Options}

{phang}
{opt short} removes the descriptive statistics (mean, SD, min, percentiles, max) from the output,
displaying only data quality metrics (N, missing, unique values, type, format, and label).
This option is useful when you only need to check data completeness and structure without
examining the distribution of values.
{p_end}

{marker examples}{...}
{title:Examples}

{pstd}Check a single variable{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. check mpg}{p_end}

{pstd}Check multiple variables{p_end}
{phang2}{cmd:. check mpg weight price}{p_end}

{pstd}Check all variables in dataset{p_end}
{phang2}{cmd:. check _all}{p_end}

{pstd}Check variables with short output (no descriptive statistics){p_end}
{phang2}{cmd:. check mpg weight price, short}{p_end}

{pstd}Check variables matching a pattern{p_end}
{phang2}{cmd:. check rep*}{p_end}

{pstd}Check after data import to validate data quality{p_end}
{phang2}{cmd:. import delimited "rawdata.csv", clear}{p_end}
{phang2}{cmd:. check _all}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:check} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(nvars)}}number of variables checked{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}list of variables checked{p_end}
{synopt:{cmd:r(mode)}}"short" or "full" depending on option{p_end}
{p2colreset}{...}

{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}
Revisions of original concept & code by Michael N Mitchell{p_end}

{title:Also see}

{psee}
Online: {stata ssc describe unique: ssc describe unique}, {stata ssc describe nmissing: ssc describe mdesc}
{p_end}
