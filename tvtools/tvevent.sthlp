{smcl}
{* *! version 1.0.0  17nov2025}{...}
{vieweralsosee "[ST] stset" "help stset"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{viewerjumpto "Syntax" "tvevent##syntax"}{...}
{viewerjumpto "Description" "tvevent##description"}{...}
{viewerjumpto "Options" "tvevent##options"}{...}
{viewerjumpto "Examples" "tvevent##examples"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:tvevent} {hline 2}}Integrate events and competing risks into time-varying datasets{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:tvevent}
{cmd:using} {it:filename},
{cmd:id(}{varname}{cmd:)}
{cmd:date(}{varname}{cmd:)}
[{it:options}]


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier matching the master dataset{p_end}
{synopt:{opt date(varname)}}variable in using file containing the primary event date{p_end}

{syntab:Competing Risks}
{synopt:{opt com:pete(varlist)}}list of date variables in using file representing competing risks{p_end}
{synopt:{opt eventl:abel(string)}}custom value labels for the generated event variable{p_end}

{syntab:Event definition}
{synopt:{opt type(string)}}event type: {bf:single} (default) or {bf:recurring}{p_end}
{synopt:{opt gen:erate(newvar)}}name for event indicator variable (default: _failure){p_end}
{synopt:{opt con:tinuous(varlist)}}cumulative exposure variables to adjust proportionally when splitting intervals{p_end}

{syntab:Time generation}
{synopt:{opt timeg:en(newvar)}}create a variable representing the duration of each interval{p_end}
{synopt:{opt timeu:nit(string)}}unit for timegen: {bf:days} (default), {bf:months}, or {bf:years}{p_end}

{syntab:Data handling}
{synopt:{opt keep:vars(varlist)}}additional variables to keep from event dataset{p_end}
{synopt:{opt replace}}replace output variables if they already exist{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvevent} is the third step in the {bf:tvtools} workflow. It processes time-varying datasets (created by {helpb tvexpose} and {helpb tvmerge}) to integrate outcomes and competing risks.

{pstd}
It performs the following key tasks:
{break}1. **Resolves Event Dates:** Compares the primary {cmd:date()} and any variables in {cmd:compete()}. The earliest occurring date becomes the effective event date for that person.
{break}2. **Splitting:** If the event occurs in the middle of an existing exposure interval (start < event < stop), the interval is automatically split into two parts: pre-event and post-event.
{break}3. **Continuous Adjustment:** If {cmd:continuous()} is specified, cumulative variables (like total dose) are proportionally reduced for split rows based on the new interval duration.
{break}4. **Flagging:** Creates a status variable (default {cmd:_failure}) coded as:
{p_end}
{phang2}* 0 = Censored (No event){p_end}
{phang2}* 1 = Primary Event (from {cmd:date()}){p_end}
{phang2}* 2+ = Competing Events (corresponding to the order in {cmd:compete()}){p_end}

{pstd}
If {cmd:type(single)} is used (default), all data after the first occurring event is dropped, making the data ready for standard survival analysis ({cmd:stset}, {cmd:stcrreg}).


{marker options}{...}
{title:Options}

{phang}
{opt compete(varlist)} specifies date variables in the using dataset that represent competing risks. If a competing date is earlier than the primary date, the status is set to 2 (for the first variable in the list), 3 (for the second), etc.

{phang}
{opt eventlabel(string)} specifies custom value labels for the outcome variable categories. 
{break}Use standard Stata syntax: {it:value "Label" value "Label"}.
{break}Example: {cmd:eventlabel(0 "Alive" 1 "Heart Failure" 2 "Death")}
{break}If not specified, labels default to "Censored" (0) and the variable labels of the date variables from the using dataset.

{phang}
{opt continuous(varlist)} specifies variables representing cumulative exposure amounts (e.g., total mg of drug, total days exposed) calculated for the *original* interval. When an interval is split, the values of these variables are multiplied by the ratio of (new duration / old duration), preserving the correct rate and total sum.

{phang}
{opt timegen(newvar)} creates a new variable containing the duration of each interval. This is useful for Poisson regression offsets or descriptive statistics.

{phang}
{opt timeunit(string)} specifies the unit for {cmd:timegen()}. Options are {bf:days} (default), {bf:months} (days/30.4375), or {bf:years} (days/365.25).

{phang}
{opt type(string)} specifies the event logic.
{break}{bf:single} (default): Treats the first event as terminal. Drops all follow-up time after the first event.
{break}{bf:recurring}: Allows multiple events per person. Splits intervals as needed but retains all follow-up time.

{phang}
{opt generate(newvar)} names the new outcome variable. Default is {cmd:_failure}.

{phang}
{opt keepvars(varlist)} specifies additional variables to keep from the event dataset (e.g., diagnosis codes). These will be populated only on the rows where the event occurred.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Primary outcome with Competing Risk (Death)}

{pstd}
You are studying heart failure (HF) diagnosis, but death is a competing risk.

{phang2}{cmd:. tvevent using registry, id(pat_id) date(date_hf) compete(date_death) generate(outcome)}{p_end}
{phang2}{cmd:. stset stop, id(pat_id) failure(outcome==1) enter(start)}{p_end}
{phang2}{cmd:. stcrreg ..., compete(outcome==2)}{p_end}

{pstd}
{bf:Example 2: Custom Event Labels}

{pstd}
Explicitly label censored, primary, and competing events.

{phang2}{cmd:. tvevent using events, id(id) date(relapse_date) ///}{p_end}
{phang2}{cmd:.     compete(death_date emig_date) ///}{p_end}
{phang2}{cmd:.     eventlabel(0 "Censored" 1 "Relapse" 2 "Death" 3 "Emigration") ///}{p_end}
{phang2}{cmd:.     generate(status)}{p_end}

{pstd}
{bf:Example 3: Continuous Dose Adjustment}

{pstd}
You have a variable `dose_mg` representing total drug amount in an interval. If death splits the interval, `dose_mg` should be reduced proportionally.

{phang2}{cmd:. tvevent using death_reg, id(id) date(dod) type(single) continuous(dose_mg)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvevent} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}Total number of observations in output{p_end}
{synopt:{cmd:r(N_events)}}Total number of events/failures flagged{p_end}


{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{title:Also see}

{psee}
Online:  {helpb tvexpose}, {helpb tvmerge}
{p_end}
