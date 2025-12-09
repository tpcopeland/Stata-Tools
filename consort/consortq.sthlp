{smcl}
{* *! version 1.0.1  2025/12/09}{...}
{vieweralsosee "consort" "help consort"}{...}
{vieweralsosee "[G] graph" "help graph"}{...}
{viewerjumpto "Syntax" "consortq##syntax"}{...}
{viewerjumpto "Description" "consortq##description"}{...}
{viewerjumpto "Options" "consortq##options"}{...}
{viewerjumpto "Examples" "consortq##examples"}{...}
{viewerjumpto "Stored results" "consortq##results"}{...}
{viewerjumpto "Authors" "consortq##authors"}{...}
{hline}
help for {cmd:consortq}{right:version 1.0.1}
{hline}

{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:consortq} {hline 2}}Cohort flow diagram for observational/retrospective studies{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 15 2}
{cmd:consortq}
{cmd:,} {opt n1(#)} [{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr:Required}
{synoptline}
{synopt:{opt n1(#)}}starting population size{p_end}
{synoptline}

{synoptset 28 tabbed}{...}
{synopthdr:Box and exclusion options}
{synoptline}
{syntab:Box 1 (starting)}
{synopt:{opt label1(string)}}label for first box; default "Initial population"{p_end}

{syntab:Exclusion 1 and Box 2}
{synopt:{opt exc1(#)}}number excluded at step 1{p_end}
{synopt:{opt exc1_reasons(string)}}exclusion reasons; separate with {cmd:;;}{p_end}
{synopt:{opt n2(#)}}n after exclusion 1; auto-calculated if omitted{p_end}
{synopt:{opt label2(string)}}label for box 2{p_end}

{syntab:Exclusion 2 and Box 3}
{synopt:{opt exc2(#)}}number excluded at step 2{p_end}
{synopt:{opt exc2_reasons(string)}}exclusion reasons{p_end}
{synopt:{opt n3(#)}}n after exclusion 2{p_end}
{synopt:{opt label3(string)}}label for box 3{p_end}

{syntab:Additional steps (3-9)}
{synopt:{it:exc#, n#, label#}}pattern continues for steps 3-9{p_end}
{synoptline}

{synoptset 28 tabbed}{...}
{synopthdr:Graph options}
{synoptline}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt subti:tle(string)}}graph subtitle{p_end}
{synopt:{opt name(name)}}name graph in memory{p_end}
{synopt:{opt sav:ing(filename)}}export graph to file{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synopt:{opt sch:eme(schemename)}}graph scheme{p_end}
{synopt:{opt nodr:aw}}suppress graph display{p_end}
{synoptline}

{synoptset 28 tabbed}{...}
{synopthdr:Appearance options}
{synoptline}
{synopt:{opt boxc:olor(color)}}main box fill color; default {cmd:white}{p_end}
{synopt:{opt boxb:order(color)}}box border color; default {cmd:black}{p_end}
{synopt:{opt excc:olor(color)}}exclusion box fill color; default {cmd:gs14}{p_end}
{synopt:{opt arrowc:olor(color)}}arrow color; default {cmd:black}{p_end}
{synopt:{opt texts:ize(size)}}main box text size; default {cmd:small}{p_end}
{synopt:{opt exctexts:ize(size)}}exclusion text size; default {cmd:vsmall}{p_end}
{synopt:{opt width(#)}}graph width in inches; default 6{p_end}
{synopt:{opt height(#)}}graph height in inches; default 9{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:consortq} generates CONSORT-style cohort flow diagrams for observational
and retrospective studies. Unlike randomized trials, these studies have a
single path with sequential exclusions rather than randomization to multiple
treatment arms.

{pstd}
The diagram shows:

{p2colset 5 8 10 2}{...}
{p2col:{c -}}A starting population box at the top{p_end}
{p2col:{c -}}Sequential exclusion boxes branching to the right{p_end}
{p2col:{c -}}Remaining population boxes as you move down{p_end}
{p2col:{c -}}Final cohort at the bottom{p_end}
{p2colreset}{...}

{pstd}
Key features:

{p2colset 5 8 10 2}{...}
{p2col:{c -}}Supports up to 10 boxes (9 exclusion steps){p_end}
{p2col:{c -}}Auto-calculates remaining n if exclusion count provided{p_end}
{p2col:{c -}}Multiple exclusion reasons per step{p_end}
{p2col:{c -}}Customizable colors and text sizes{p_end}
{p2col:{c -}}Export to common graphics formats{p_end}
{p2colreset}{...}


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt n1(#)} specifies the starting population size. This is required.

{dlgtab:Box and exclusion options}

{phang}
{opt label#(string)} specifies the label for box #. Default labels are
"Initial population" for box 1, "After exclusion #" for intermediate boxes,
and "Final cohort" for the last box.

{phang}
{opt exc#(#)} specifies the number excluded at step #. This triggers
the display of an exclusion box to the right of the main flow.

{phang}
{opt exc#_reasons(string)} specifies reasons for exclusion at step #.
Multiple reasons should be separated by {cmd:;;} (double semicolon).

{phang}
{opt n#(#)} specifies the population size after exclusion step #-1.
If omitted but {opt exc#-1()} is specified, n# is auto-calculated as
the previous n minus the exclusion count.

{dlgtab:Graph options}

{phang}
{opt title(string)} specifies a title for the graph.

{phang}
{opt subtitle(string)} specifies a subtitle for the graph.

{phang}
{opt name(name)} assigns a name to the graph in memory.

{phang}
{opt saving(filename)} exports the graph to a file. The format is determined
by the file extension (.png, .pdf, .eps, .svg, etc.).

{phang}
{opt replace} allows overwriting an existing file.

{phang}
{opt scheme(schemename)} specifies the graph scheme.

{phang}
{opt nodraw} suppresses display of the graph.

{dlgtab:Appearance options}

{phang}
{opt boxcolor(color)} specifies the fill color for main boxes. Default is
{cmd:white}.

{phang}
{opt boxborder(color)} specifies the border color for all boxes. Default is
{cmd:black}.

{phang}
{opt exccolor(color)} specifies the fill color for exclusion boxes. Default is
{cmd:gs14} (light gray).

{phang}
{opt arrowcolor(color)} specifies the color for arrows and connecting lines.
Default is {cmd:black}.

{phang}
{opt textsize(size)} specifies the text size for main boxes. Default is
{cmd:small}.

{phang}
{opt exctextsize(size)} specifies the text size for exclusion boxes. Default is
{cmd:vsmall}.

{phang}
{opt width(#)} specifies the graph width in inches. Default is 6.

{phang}
{opt height(#)} specifies the graph height in inches. Default is 9.


{marker examples}{...}
{title:Examples}

{pstd}{ul:Example 1: Simple two-step flow}{p_end}

{phang2}{cmd:. consortq, n1(10000) exc1(2000) n2(8000)}{p_end}

{pstd}{ul:Example 2: With labels and reasons}{p_end}

{phang2}{cmd:. consortq, n1(50000) label1("Registry population")}{break}
{cmd:         exc1(15000) exc1_reasons("Missing diagnosis date (n=8000);; Age < 18 (n=7000)")}{break}
{cmd:         n2(35000) label2("Adults with diagnosis")}{break}
{cmd:         exc2(5000) exc2_reasons("No follow-up data")}{break}
{cmd:         n3(30000) label3("Study cohort")}{p_end}

{pstd}{ul:Example 3: Multiple exclusion steps}{p_end}

{phang2}{cmd:. consortq, n1(100000) label1("Initial database extract")}{break}
{cmd:         exc1(20000) exc1_reasons("Duplicate records")}{break}
{cmd:         label2("Unique patients")}{break}
{cmd:         exc2(15000) exc2_reasons("Missing exposure data (n=10000);; Missing outcome (n=5000)")}{break}
{cmd:         label3("Complete cases")}{break}
{cmd:         exc3(8000) exc3_reasons("Prevalent cases at baseline")}{break}
{cmd:         label4("Incident cases")}{break}
{cmd:         exc4(2000) exc4_reasons("< 1 year follow-up")}{break}
{cmd:         label5("Final analysis cohort")}{break}
{cmd:         title("Cohort Selection") saving("cohort_flow.png") replace}{p_end}

{pstd}{ul:Example 4: Auto-calculate remaining n}{p_end}

{phang2}{cmd:. consortq, n1(5000)}{break}
{cmd:         exc1(500)}{break}
{cmd:         exc2(200)}{break}
{cmd:         exc3(100)}{break}
{cmd:         label4("Final cohort")}{p_end}

{pstd}This automatically calculates n2=4500, n3=4300, n4=4200.

{pstd}{ul:Example 5: Custom appearance}{p_end}

{phang2}{cmd:. consortq, n1(25000) label1("Source population")}{break}
{cmd:         exc1(5000) n2(20000) label2("Eligible population")}{break}
{cmd:         exc2(2000) n3(18000) label3("Included in study")}{break}
{cmd:         boxcolor("ltblue") exccolor("orange*0.3") arrowcolor("navy")}{break}
{cmd:         textsize("medsmall") width(7) height(10)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:consortq} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(nboxes)}}number of boxes in diagram{p_end}
{synopt:{cmd:r(n1)}}population in box 1{p_end}
{synopt:{cmd:r(n2)}}population in box 2 (if applicable){p_end}
{synopt:{cmd:r(n#)}}population in box # (up to 10){p_end}
{synopt:{cmd:r(exc1)}}excluded at step 1 (if applicable){p_end}
{synopt:{cmd:r(exc#)}}excluded at step # (up to 9){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(label1)}}label for box 1{p_end}
{synopt:{cmd:r(label#)}}label for box # (up to 10){p_end}


{marker authors}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se


{marker seealso}{...}
{title:Also see}

{psee}
Online: {helpb consort} (for randomized trials), {helpb graph}, {helpb graph export}
{p_end}
