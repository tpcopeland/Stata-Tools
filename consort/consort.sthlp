{smcl}
{* *! version 1.0.1  15dec2025}{...}
{vieweralsosee "[D] drop" "help drop"}{...}
{vieweralsosee "[D] count" "help count"}{...}
{viewerjumpto "Syntax" "consort##syntax"}{...}
{viewerjumpto "Description" "consort##description"}{...}
{viewerjumpto "Subcommands" "consort##subcommands"}{...}
{viewerjumpto "Options" "consort##options"}{...}
{viewerjumpto "Remarks" "consort##remarks"}{...}
{viewerjumpto "Examples" "consort##examples"}{...}
{viewerjumpto "Stored results" "consort##results"}{...}
{viewerjumpto "Requirements" "consort##requirements"}{...}
{viewerjumpto "Author" "consort##author"}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{cmd:consort} {hline 2}}Generate CONSORT-style exclusion flowcharts{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}Initialize a CONSORT diagram

{p 8 16 2}
{cmd:consort init}{cmd:,}
{opt ini:tial(string)}
[{opt file(filename)}]


{pstd}Add an exclusion step

{p 8 16 2}
{cmd:consort exclude}
{it:if}{cmd:,}
{opt lab:el(string)}
[{opt rem:aining(string)}]


{pstd}Generate and save the diagram

{p 8 16 2}
{cmd:consort save}{cmd:,}
{opt out:put(filename)}
[{it:save_options}]


{pstd}Clear diagram state

{p 8 16 2}
{cmd:consort clear}
[{cmd:,} {opt quiet}]


{synoptset 24 tabbed}{...}
{synopthdr:init options}
{synoptline}
{p2coldent:* {opt ini:tial(string)}}label for initial population box{p_end}
{synopt:{opt file(filename)}}path to store CSV data; default is temp file{p_end}
{synoptline}

{synoptset 24 tabbed}{...}
{synopthdr:exclude options}
{synoptline}
{p2coldent:* {opt lab:el(string)}}label for exclusion box{p_end}
{synopt:{opt rem:aining(string)}}custom label for remaining population box{p_end}
{synoptline}

{synoptset 24 tabbed}{...}
{synopthdr:save options}
{synoptline}
{p2coldent:* {opt out:put(filename)}}output image path (.png recommended){p_end}
{synopt:{opt fin:al(string)}}label for final cohort box; default "Final Cohort"{p_end}
{synopt:{opt shading}}enable box shading (blue for flow, red for exclusions){p_end}
{synopt:{opt python(path)}}path to Python executable{p_end}
{synopt:{opt dpi(#)}}image resolution; default 150{p_end}
{synoptline}
{p 4 6 2}* indicates required option.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:consort} generates CONSORT-style (Consolidated Standards of Reporting Trials)
exclusion flowcharts for observational research. These diagrams visualize the
sequential exclusion of observations from a dataset, showing how many observations
were removed at each step and why.

{pstd}
The workflow involves three steps:

{phang2}1. {bf:Initialize} the diagram with your starting population using {cmd:consort init}

{phang2}2. {bf:Apply exclusions} using {cmd:consort exclude} with {it:if} conditions.
Each call drops matching observations and records the exclusion.

{phang2}3. {bf:Generate} the diagram image using {cmd:consort save}

{pstd}
The diagram generation uses Python with matplotlib. The exclusion data is stored
in a CSV file that can be edited manually if needed.


{marker subcommands}{...}
{title:Subcommands}

{dlgtab:init}

{pstd}
{cmd:consort init} initializes a new CONSORT diagram. It records the current
number of observations as the initial population and creates a CSV file to
track exclusions.

{pstd}
Only one diagram can be active at a time. Use {cmd:consort clear} or
{cmd:consort save} before starting a new diagram.

{dlgtab:exclude}

{pstd}
{cmd:consort exclude} applies an exclusion criterion to the dataset. Observations
matching the {it:if} condition are dropped and the exclusion is recorded in the
CSV file.

{pstd}
The command requires an {it:if} condition specifying which observations to exclude.
If zero observations match, a note is displayed and no action is taken.

{dlgtab:save}

{pstd}
{cmd:consort save} generates the flowchart image using Python and matplotlib.
The diagram shows the initial population at the top, with exclusion boxes
branching to the right and remaining population boxes continuing downward.

{pstd}
After successful generation, the diagram state is automatically cleared.

{dlgtab:clear}

{pstd}
{cmd:consort clear} removes the current diagram state without generating output.
Use this to abandon an incomplete diagram and start fresh.


{marker options}{...}
{title:Options}

{dlgtab:init options}

{phang}
{opt initial(string)} specifies the label for the initial population box at the
top of the diagram. This typically describes your source population and time period.
For example: "All patients in database 2015-2023".

{phang}
{opt file(filename)} specifies the path where the exclusion data CSV will be stored.
If not specified, a temporary file is used. Specifying a file allows you to
inspect or edit the CSV data before generating the diagram.

{dlgtab:exclude options}

{phang}
{opt label(string)} specifies the label for the exclusion box. This should
briefly describe the exclusion criterion. For example: "Missing baseline labs"
or "Age < 18 years".

{phang}
{opt remaining(string)} specifies a custom label for the remaining population
box after this exclusion. If not specified, intermediate boxes show only the
count. Use this to mark important milestones like "Eligible patients" or
"Met inclusion criteria".

{dlgtab:save options}

{phang}
{opt output(filename)} specifies the output image path. PNG format is recommended.
Other formats supported by matplotlib (PDF, SVG, etc.) may also work.

{phang}
{opt final(string)} specifies the label for the final cohort box at the bottom
of the diagram. Default is "Final Cohort". Use this to describe your analytic
sample, such as "Final Analytic Cohort" or "Study Population".

{phang}
{opt shading} enables color shading for boxes. Main flow boxes are shaded light
blue and exclusion boxes are shaded light red. Without this option, all boxes
have white backgrounds.

{phang}
{opt python(path)} specifies the path to the Python executable. Default is
"python" (or "python3" on Unix systems). Use this if Python is not in your
system PATH or you need a specific Python installation.

{phang}
{opt dpi(#)} specifies the image resolution in dots per inch. Default is 150.
Higher values produce larger, higher-quality images suitable for publication.
Use 300 for print-quality output.

{dlgtab:clear options}

{phang}
{opt quiet} suppresses the confirmation message.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Important considerations}

{pstd}
Each {cmd:consort exclude} command {bf:permanently drops} observations from the
dataset. If you need to preserve the original data, use {cmd:preserve} before
starting the CONSORT workflow or work on a copy of your data.

{pstd}
The order of exclusions matters both for the diagram layout and for the counts.
Exclusions are applied sequentially, so later exclusions only operate on
observations that passed earlier criteria.

{pstd}
{bf:CSV file format}

{pstd}
The exclusion data is stored in a simple CSV format:

        label,n,remaining
        Initial Population,10000,
        Missing lab values,234,
        Age < 18 years,89,Eligible patients
        Lost to follow-up,156,Final Cohort

{pstd}
The first row after the header is the initial population (n = total count).
Subsequent rows are exclusions (n = number excluded). The "remaining" column
specifies custom labels for boxes after exclusions.

{pstd}
{bf:Python dependency}

{pstd}
This command requires Python 3 with matplotlib installed. To check if you have
the requirements:

{phang2}{cmd:. shell python --version}{p_end}
{phang2}{cmd:. shell python -c "import matplotlib; print(matplotlib.__version__)"}{p_end}

{pstd}
If matplotlib is not installed, you can install it with:

{phang2}{cmd:. shell pip install matplotlib}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic workflow}

{pstd}
Generate a CONSORT diagram for a cohort study:

{phang2}{cmd:. use patient_data, clear}{p_end}
{phang2}{cmd:. consort init, initial("All patients in database 2015-2023")}{p_end}
{phang2}{cmd:. consort exclude if missing(baseline_lab), label("Missing baseline labs")}{p_end}
{phang2}{cmd:. consort exclude if age < 18, label("Age < 18 years")}{p_end}
{phang2}{cmd:. consort exclude if prior_cancer == 1, label("Prior cancer diagnosis")}{p_end}
{phang2}{cmd:. consort exclude if followup_days < 30, label("Lost to follow-up < 30 days")}{p_end}
{phang2}{cmd:. consort save, output("consort_diagram.png") final("Final Analytic Cohort")}{p_end}


{pstd}
{bf:Example 2: With custom milestone labels}

{pstd}
Mark intermediate milestones in the exclusion process:

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. consort init, initial("All cars in dataset")}{p_end}
{phang2}{cmd:. consort exclude if rep78 == ., label("Missing repair record") remaining("Cars with repair data")}{p_end}
{phang2}{cmd:. consort exclude if foreign == 1, label("Foreign manufacture")}{p_end}
{phang2}{cmd:. consort save, output("auto_consort.png") final("Domestic cars for analysis") shading}{p_end}


{pstd}
{bf:Example 3: High-resolution output for publication}

{phang2}{cmd:. consort save, output("figure1.png") final("Study Population") dpi(300)}{p_end}


{pstd}
{bf:Example 4: Using a specific Python installation}

{phang2}{cmd:. consort save, output("diagram.png") python("/usr/local/bin/python3")}{p_end}


{pstd}
{bf:Example 5: Preserving original data}

{phang2}{cmd:. use mydata, clear}{p_end}
{phang2}{cmd:. preserve}{p_end}
{phang2}{cmd:. consort init, initial("Source population")}{p_end}
{phang2}{cmd:. consort exclude if condition1, label("Criterion 1")}{p_end}
{phang2}{cmd:. consort exclude if condition2, label("Criterion 2")}{p_end}
{phang2}{cmd:. consort save, output("diagram.png")}{p_end}
{phang2}{cmd:. restore}{p_end}
{phang2}{cmd:. * Original data restored}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:consort init} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}initial number of observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(initial)}}initial population label{p_end}
{synopt:{cmd:r(file)}}path to CSV file{p_end}

{pstd}
{cmd:consort exclude} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_excluded)}}number of observations excluded{p_end}
{synopt:{cmd:r(n_remaining)}}number of observations remaining{p_end}
{synopt:{cmd:r(step)}}exclusion step number{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(label)}}exclusion label{p_end}

{pstd}
{cmd:consort save} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_initial)}}initial number of observations{p_end}
{synopt:{cmd:r(N_final)}}final number of observations{p_end}
{synopt:{cmd:r(N_excluded)}}total number excluded{p_end}
{synopt:{cmd:r(steps)}}number of exclusion steps{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(output)}}output file path{p_end}
{synopt:{cmd:r(final)}}final cohort label{p_end}


{marker requirements}{...}
{title:Requirements}

{pstd}
{bf:Stata version}: 16.0 or higher recommended

{pstd}
{bf:Python requirements}:

{p 8 12 2}- Python 3.6 or higher{p_end}
{p 8 12 2}- matplotlib library{p_end}

{pstd}
To install matplotlib:

{phang2}{cmd:. shell pip install matplotlib}{p_end}

{pstd}
On some systems you may need to use {cmd:pip3} instead of {cmd:pip}.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}


{title:Also see}

{psee}
Online: {helpb drop}, {helpb count}, {helpb if}

{hline}
