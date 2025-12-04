{smcl}
{* *! version 1.0.0  2025/12/03}{...}
{vieweralsosee "consortq" "help consortq"}{...}
{vieweralsosee "[G] graph" "help graph"}{...}
{vieweralsosee "[G] graph export" "help graph_export"}{...}
{viewerjumpto "Syntax" "consort##syntax"}{...}
{viewerjumpto "Description" "consort##description"}{...}
{viewerjumpto "Options" "consort##options"}{...}
{viewerjumpto "Examples" "consort##examples"}{...}
{viewerjumpto "Stored results" "consort##results"}{...}
{viewerjumpto "Authors" "consort##authors"}{...}
{hline}
help for {cmd:consort}{right:version 1.0.0}
{hline}

{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:consort} {hline 2}}CONSORT flow diagram generator for clinical trials{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 15 2}
{cmd:consort}
{cmd:,} {it:required_options} [{it:optional_options}]

{synoptset 32 tabbed}{...}
{synopthdr:Required options}
{synoptline}
{syntab:Enrollment}
{synopt:{opt ass:essed(#)}}total participants assessed for eligibility{p_end}
{synopt:{opt exc:luded(#)}}total participants excluded{p_end}
{synopt:{opt ran:domized(#)}}total participants randomized{p_end}

{syntab:Arm 1}
{synopt:{opt arm1_label(string)}}label for treatment arm 1{p_end}
{synopt:{opt arm1_allocated(#)}}participants allocated to arm 1{p_end}
{synopt:{opt arm1_analyzed(#)}}participants analyzed in arm 1{p_end}

{syntab:Arm 2}
{synopt:{opt arm2_label(string)}}label for treatment arm 2{p_end}
{synopt:{opt arm2_allocated(#)}}participants allocated to arm 2{p_end}
{synopt:{opt arm2_analyzed(#)}}participants analyzed in arm 2{p_end}
{synoptline}

{synoptset 32 tabbed}{...}
{synopthdr:Optional options}
{synoptline}
{syntab:Enrollment details}
{synopt:{opt excr:easons(string)}}exclusion reasons; separate multiple with {cmd:;;}{p_end}

{syntab:Arm 1 allocation details}
{synopt:{opt arm1_received(#)}}received intervention in arm 1{p_end}
{synopt:{opt arm1_notrec(#)}}did not receive intervention{p_end}
{synopt:{opt arm1_notrec_reasons(string)}}reasons for not receiving{p_end}

{syntab:Arm 1 follow-up}
{synopt:{opt arm1_lost(#)}}lost to follow-up in arm 1{p_end}
{synopt:{opt arm1_lost_reasons(string)}}reasons for loss to follow-up{p_end}
{synopt:{opt arm1_discontinued(#)}}discontinued intervention{p_end}
{synopt:{opt arm1_disc_reasons(string)}}reasons for discontinuation{p_end}

{syntab:Arm 1 analysis}
{synopt:{opt arm1_analysis_excluded(#)}}excluded from analysis{p_end}
{synopt:{opt arm1_analysis_exc_reasons(string)}}reasons for analysis exclusion{p_end}

{syntab:Arm 2 allocation details}
{synopt:{opt arm2_received(#)}}received intervention in arm 2{p_end}
{synopt:{opt arm2_notrec(#)}}did not receive intervention{p_end}
{synopt:{opt arm2_notrec_reasons(string)}}reasons for not receiving{p_end}

{syntab:Arm 2 follow-up}
{synopt:{opt arm2_lost(#)}}lost to follow-up in arm 2{p_end}
{synopt:{opt arm2_lost_reasons(string)}}reasons for loss to follow-up{p_end}
{synopt:{opt arm2_discontinued(#)}}discontinued intervention{p_end}
{synopt:{opt arm2_disc_reasons(string)}}reasons for discontinuation{p_end}

{syntab:Arm 2 analysis}
{synopt:{opt arm2_analysis_excluded(#)}}excluded from analysis{p_end}
{synopt:{opt arm2_analysis_exc_reasons(string)}}reasons for analysis exclusion{p_end}

{syntab:Additional arms (optional)}
{synopt:{opt arm3_label(string)}}label for arm 3{p_end}
{synopt:{opt arm3_allocated(#)}}allocated to arm 3{p_end}
{synopt:{opt arm3_analyzed(#)}}analyzed in arm 3{p_end}
{synopt:{it:arm3_*}}other arm 3 options follow arm1/arm2 pattern{p_end}

{synopt:{opt arm4_label(string)}}label for arm 4{p_end}
{synopt:{opt arm4_allocated(#)}}allocated to arm 4{p_end}
{synopt:{opt arm4_analyzed(#)}}analyzed in arm 4{p_end}
{synopt:{it:arm4_*}}other arm 4 options follow arm1/arm2 pattern{p_end}

{syntab:Graph options}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt subti:tle(string)}}graph subtitle{p_end}
{synopt:{opt name(name)}}name graph in memory{p_end}
{synopt:{opt sav:ing(filename)}}export graph to file{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synopt:{opt sch:eme(schemename)}}graph scheme{p_end}
{synopt:{opt nodr:aw}}suppress graph display{p_end}

{syntab:Appearance options}
{synopt:{opt boxc:olor(colorstyle)}}box fill color; default {cmd:white}{p_end}
{synopt:{opt boxb:order(colorstyle)}}box border color; default {cmd:black}{p_end}
{synopt:{opt arrowc:olor(colorstyle)}}arrow color; default {cmd:black}{p_end}
{synopt:{opt texts:ize(textstyle)}}text size; default {cmd:vsmall}{p_end}
{synopt:{opt labels:ize(textstyle)}}stage label size; default {cmd:small}{p_end}
{synopt:{opt width(#)}}graph width in inches; default 7{p_end}
{synopt:{opt height(#)}}graph height in inches; default 10{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:consort} generates CONSORT (Consolidated Standards of Reporting Trials)
flow diagrams for clinical trials. The CONSORT flow diagram is a standardized
visualization showing the flow of participants through each stage of a
randomized trial: enrollment, allocation, follow-up, and analysis.

{pstd}
The command supports 2 to 4 treatment arms and allows detailed specification
of participant counts and reasons at each stage. The output is a publication-quality
graph that can be exported to various formats (PNG, PDF, EPS, SVG, etc.).

{pstd}
Key features include:

{p2colset 5 8 10 2}{...}
{p2col:{c -}}Support for 2, 3, or 4 treatment arms{p_end}
{p2col:{c -}}Automatic layout adjustment based on number of arms{p_end}
{p2col:{c -}}Detailed tracking of exclusions at each stage{p_end}
{p2col:{c -}}Customizable colors, text sizes, and dimensions{p_end}
{p2col:{c -}}Export to common graphics formats{p_end}
{p2colreset}{...}


{marker options}{...}
{title:Options}

{dlgtab:Enrollment}

{phang}
{opt assessed(#)} specifies the total number of participants assessed for
eligibility. This is the starting point of the flow diagram.

{phang}
{opt excluded(#)} specifies the total number of participants excluded from
the trial (did not meet inclusion criteria, declined to participate, etc.).

{phang}
{opt randomized(#)} specifies the total number of participants randomized.
Note: {cmd:assessed()} must be >= {cmd:excluded()} + {cmd:randomized()}.

{phang}
{opt excreasons(string)} specifies reasons for exclusion. Multiple reasons
should be separated by {cmd:;;} (double semicolon). Example:
{cmd:excreasons("Not meeting criteria (n=10);; Declined to participate (n=5)")}

{dlgtab:Arm options}

{phang}
{opt arm#_label(string)} specifies the label for treatment arm # (1-4).
Examples: "Intervention", "Control", "Drug A", "Placebo".

{phang}
{opt arm#_allocated(#)} specifies the number of participants allocated to
arm #.

{phang}
{opt arm#_received(#)} specifies the number who received the allocated
intervention. If not specified, this row is not shown.

{phang}
{opt arm#_notrec(#)} specifies the number who did not receive the allocated
intervention.

{phang}
{opt arm#_lost(#)} specifies the number lost to follow-up in arm #.

{phang}
{opt arm#_discontinued(#)} specifies the number who discontinued the
intervention.

{phang}
{opt arm#_analyzed(#)} specifies the number analyzed in the primary analysis
for arm #.

{phang}
{opt arm#_analysis_excluded(#)} specifies the number excluded from the
primary analysis.

{phang}
For all {cmd:*_reasons()} options, multiple reasons should be separated by
{cmd:;;} (double semicolon).

{dlgtab:Graph options}

{phang}
{opt title(string)} specifies a title for the graph.

{phang}
{opt subtitle(string)} specifies a subtitle for the graph.

{phang}
{opt name(name)} assigns a name to the graph in memory.

{phang}
{opt saving(filename)} exports the graph to a file. The format is determined
by the file extension (.png, .pdf, .eps, .svg, .tif, etc.).

{phang}
{opt replace} allows overwriting an existing file.

{phang}
{opt scheme(schemename)} specifies the graph scheme.

{phang}
{opt nodraw} suppresses display of the graph (useful when only saving).

{dlgtab:Appearance options}

{phang}
{opt boxcolor(colorstyle)} specifies the fill color for boxes. Default is
{cmd:white}.

{phang}
{opt boxborder(colorstyle)} specifies the border color for boxes. Default is
{cmd:black}.

{phang}
{opt arrowcolor(colorstyle)} specifies the color for arrows and connecting
lines. Default is {cmd:black}.

{phang}
{opt textsize(textstyle)} specifies the text size within boxes. Default is
{cmd:vsmall}. Options include: {cmd:tiny}, {cmd:vsmall}, {cmd:small},
{cmd:medsmall}, {cmd:medium}, {cmd:medlarge}, {cmd:large}, {cmd:vlarge},
{cmd:huge}.

{phang}
{opt labelsize(textstyle)} specifies the text size for stage labels
(Enrollment, Allocation, etc.). Default is {cmd:small}.

{phang}
{opt width(#)} specifies the graph width in inches. Default is 7.

{phang}
{opt height(#)} specifies the graph height in inches. Default is 10.


{marker examples}{...}
{title:Examples}

{pstd}{ul:Example 1: Basic two-arm trial}{p_end}

{phang2}{cmd:. consort, assessed(200) excluded(25) randomized(175)}{break}
{cmd:         arm1_label("Treatment") arm1_allocated(88) arm1_analyzed(80)}{break}
{cmd:         arm2_label("Control") arm2_allocated(87) arm2_analyzed(82)}{p_end}

{pstd}{ul:Example 2: With exclusion reasons and follow-up details}{p_end}

{phang2}{cmd:. consort, assessed(500) excluded(100) randomized(400)}{break}
{cmd:         excreasons("Not meeting criteria (n=60);; Declined (n=30);; Other (n=10)")}{break}
{cmd:         arm1_label("Drug A") arm1_allocated(200)}{break}
{cmd:         arm1_lost(15) arm1_lost_reasons("Withdrew consent (n=10);; Lost contact (n=5)")}{break}
{cmd:         arm1_discontinued(8) arm1_disc_reasons("Adverse events (n=5);; Lack of efficacy (n=3)")}{break}
{cmd:         arm1_analyzed(177)}{break}
{cmd:         arm2_label("Placebo") arm2_allocated(200)}{break}
{cmd:         arm2_lost(12) arm2_lost_reasons("Withdrew consent (n=8);; Lost contact (n=4)")}{break}
{cmd:         arm2_discontinued(5) arm2_disc_reasons("Adverse events (n=3);; Other (n=2)")}{break}
{cmd:         arm2_analyzed(183)}{break}
{cmd:         title("CONSORT Flow Diagram")}{break}
{cmd:         saving("consort_diagram.png") replace}{p_end}

{pstd}{ul:Example 3: Three-arm trial}{p_end}

{phang2}{cmd:. consort, assessed(600) excluded(150) randomized(450)}{break}
{cmd:         arm1_label("Low Dose") arm1_allocated(150) arm1_analyzed(140)}{break}
{cmd:         arm1_lost(5) arm1_discontinued(3)}{break}
{cmd:         arm2_label("High Dose") arm2_allocated(150) arm2_analyzed(138)}{break}
{cmd:         arm2_lost(7) arm2_discontinued(5)}{break}
{cmd:         arm3_label("Placebo") arm3_allocated(150) arm3_analyzed(145)}{break}
{cmd:         arm3_lost(3) arm3_discontinued(2)}{break}
{cmd:         title("Three-Arm Dose-Finding Study")}{p_end}

{pstd}{ul:Example 4: Customized appearance}{p_end}

{phang2}{cmd:. consort, assessed(300) excluded(50) randomized(250)}{break}
{cmd:         arm1_label("Intervention") arm1_allocated(125) arm1_analyzed(120)}{break}
{cmd:         arm2_label("Control") arm2_allocated(125) arm2_analyzed(122)}{break}
{cmd:         boxcolor("ltblue") boxborder("navy") arrowcolor("navy")}{break}
{cmd:         textsize("small") width(8) height(12)}{break}
{cmd:         scheme(s1color)}{break}
{cmd:         saving("consort_custom.pdf") replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:consort} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(assessed)}}total assessed for eligibility{p_end}
{synopt:{cmd:r(excluded)}}total excluded{p_end}
{synopt:{cmd:r(randomized)}}total randomized{p_end}
{synopt:{cmd:r(narms)}}number of treatment arms{p_end}
{synopt:{cmd:r(arm1_allocated)}}allocated to arm 1{p_end}
{synopt:{cmd:r(arm1_analyzed)}}analyzed in arm 1{p_end}
{synopt:{cmd:r(arm2_allocated)}}allocated to arm 2{p_end}
{synopt:{cmd:r(arm2_analyzed)}}analyzed in arm 2{p_end}
{synopt:{cmd:r(arm3_allocated)}}allocated to arm 3 (if applicable){p_end}
{synopt:{cmd:r(arm3_analyzed)}}analyzed in arm 3 (if applicable){p_end}
{synopt:{cmd:r(arm4_allocated)}}allocated to arm 4 (if applicable){p_end}
{synopt:{cmd:r(arm4_analyzed)}}analyzed in arm 4 (if applicable){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(arm1_label)}}label for arm 1{p_end}
{synopt:{cmd:r(arm2_label)}}label for arm 2{p_end}
{synopt:{cmd:r(arm3_label)}}label for arm 3 (if applicable){p_end}
{synopt:{cmd:r(arm4_label)}}label for arm 4 (if applicable){p_end}


{marker authors}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se


{marker references}{...}
{title:References}

{phang}
Schulz KF, Altman DG, Moher D (2010). CONSORT 2010 Statement: updated guidelines
for reporting parallel group randomised trials. {it:BMJ} 340:c332.

{phang}
Moher D, Hopewell S, Schulz KF, et al. (2010). CONSORT 2010 Explanation and
Elaboration: updated guidelines for reporting parallel group randomised trials.
{it:BMJ} 340:c869.


{marker seealso}{...}
{title:Also see}

{psee}
Online: {helpb consortq} (for cohort studies), {helpb graph}, {helpb graph export}
{p_end}
