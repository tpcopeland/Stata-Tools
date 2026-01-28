{smcl}
{* *! version 1.0.0  DDmonYYYY}{...}
{vieweralsosee "[R] regress" "help regress"}{...}
{vieweralsosee "[D] generate" "help generate"}{...}
{viewerjumpto "Syntax" "TEMPLATE##syntax"}{...}
{viewerjumpto "Description" "TEMPLATE##description"}{...}
{viewerjumpto "Options" "TEMPLATE##options"}{...}
{viewerjumpto "Remarks" "TEMPLATE##remarks"}{...}
{viewerjumpto "Examples" "TEMPLATE##examples"}{...}
{viewerjumpto "Stored results" "TEMPLATE##results"}{...}
{viewerjumpto "Author" "TEMPLATE##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:TEMPLATE} {hline 2}}Brief description of what the command does{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:TEMPLATE}
{varlist}
{ifin}
{cmd:,}
{opt req:uired_option(varname)}
[{it:options}]


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt req:uired_option(varname)}}description of required option{p_end}

{syntab:Optional}
{synopt:{opt option1}}description of option1{p_end}
{synopt:{opt option2(numlist)}}description of option2{p_end}
{synopt:{opt gen:erate(newvar)}}name for output variable{p_end}
{synopt:{opt replace}}allow replacing existing variables{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:TEMPLATE} does something useful with your data. This is a longer description
that explains what the command does, when you would use it, and any important
details about how it works.

{pstd}
The typical workflow involves:

{phang2}1. First step in the workflow

{phang2}2. Second step in the workflow

{phang2}3. Third step in the workflow


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt required_option(varname)} specifies the variable that does something
important. This option is required because...

{dlgtab:Optional}

{phang}
{opt option1} enables a specific feature. When specified, the command will...

{phang}
{opt option2(numlist)} specifies numeric values for something. For example,
{cmd:option2(1 5 10)} would...

{phang}
{opt generate(newvar)} specifies the name for the output variable. Default
is {cmd:TEMPLATE_result}.

{phang}
{opt replace} allows the command to overwrite existing variables.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Important considerations}

{pstd}
Add any important remarks, caveats, or technical details here.

{pstd}
{bf:Performance}

{pstd}
Notes about performance with large datasets, if relevant.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic usage}

{pstd}
Description of what this example demonstrates:

{phang2}{cmd:. sysuse auto, clear}{p_end}

{phang2}{cmd:. TEMPLATE price mpg, required_option(weight)}{p_end}


{pstd}
{bf:Example 2: With optional arguments}

{pstd}
Description of what this example demonstrates:

{phang2}{cmd:. sysuse auto, clear}{p_end}

{phang2}{cmd:. TEMPLATE price mpg, required_option(weight) option1 generate(result)}{p_end}


{pstd}
{bf:Example 3: Advanced usage}

{pstd}
Description of what this example demonstrates:

{phang2}{cmd:. sysuse auto, clear}{p_end}

{phang2}{cmd:. TEMPLATE price mpg if foreign == 0, required_option(weight) option2(1 5 10)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:TEMPLATE} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}variables specified{p_end}
{synopt:{cmd:r(generate)}}name of generated variable{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(results)}}matrix of results (if applicable){p_end}


{marker author}{...}
{title:Author}

{pstd}Your Name{p_end}
{pstd}Department/Institution{p_end}
{pstd}Affiliation{p_end}
{pstd}Email: your@email.com{p_end}
{pstd}Version 1.0.0, YYYY-MM-DD{p_end}


{title:Also see}

{psee}
Manual:  {manlink R regress}, {manlink D generate}

{psee}
Online:  {helpb related_command1}, {helpb related_command2}

{hline}
