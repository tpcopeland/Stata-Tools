{smcl}
{vieweralsosee "tvbuild" "help tvbuild"}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{viewerjumpto "Syntax" "tvspec##syntax"}{...}
{viewerjumpto "Description" "tvspec##description"}{...}
{viewerjumpto "Options" "tvspec##options"}{...}
{viewerjumpto "Remarks" "tvspec##remarks"}{...}
{viewerjumpto "Examples" "tvspec##examples"}{...}
{viewerjumpto "Stored results" "tvspec##results"}{...}
{viewerjumpto "Author" "tvspec##author"}{...}

{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:tvspec} {hline 2}}Build a {cmd:tvbuild} specification frame one source at a time{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}Create an empty specification frame

{p 8 16 2}
{cmd:tvspec create} {it:framename} [{cmd:,} {opt rep:lace}]

{pstd}Append one source

{p 8 16 2}
{cmd:tvspec add} {it:framename}{cmd:,}
{opt nam:e(name)}
{c -(}{opt fr:ame(name)} | {opt us:ing(filename)}{c )-}
{opt start(name)}
{opt stop(name)}
{opt expos:ure(namelist)}
{opt gen:erate(namelist)}
[{opt ref:erence(#)}
{opt kind(string)}
{opt referencel:abel(string)}
{opt lab:el(string)}
{opt desc:ription(string)}
{opt rate(namelist)}
{opt tot:al(namelist)}
{opt cum:ulative(namelist)}]

{pstd}Display the frame

{p 8 16 2}
{cmd:tvspec list} {it:framename}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvspec} writes the multi-source specification frame that {cmd:tvbuild}'s
{opt specframe()} option consumes. Each {cmd:tvspec add} call appends one
source: where its records come from, which columns hold the interval bounds,
and which input variables map to which generated output variables.

{pstd}
{cmd:tvspec} is a convenience over the specification format, not a second
definition of it. It writes the same typed columns, in the same order, with the
same schema characteristic, so a frame it builds and a frame built by hand with
{helpb generate} are indistinguishable to {cmd:tvbuild}. Building the frame by
hand remains fully supported and nothing about the specification schema changed
when {cmd:tvspec} was added.

{pstd}
{cmd:tvspec} does not validate the plan. Every cross-row rule -- source-name
uniqueness, output-name collisions across sources, quantity lists being subsets
of {opt exposure()}, and the {cmd:episodes}/{cmd:intervals} asymmetries --
belongs to {cmd:tvbuild}, which applies it to the frame however the frame was
built. {cmd:tvspec} checks only the row in front of it: that its options are
consistent with each other, and that every value can be stored in its column
exactly. A value too long for its column is an error, never a truncation.

{pstd}
Row order is semantic. It fixes generated-variable order, merge order, the
order sources appear in {cmd:tvbuild}'s plan display, and the order of stages
in the provenance manifest. {cmd:tvspec add} appends and never reorders.


{marker options}{...}
{title:Options}

{dlgtab:create}

{phang}
{opt rep:lace} permits overwriting an existing frame. Without it, an existing
{it:framename} is an error. {cmd:tvspec create} will not replace the frame it
is currently running in.

{dlgtab:add}

{phang}
{opt nam:e(name)} is the logical name of the source. It is required, must be a
legal Stata name of at most 32 characters, and must be unique within the
frame. It appears in {cmd:tvbuild}'s plan display, in the provenance manifest,
and in {cmd:r(source_names)}.

{phang}
{opt fr:ame(name)} names a frame holding the source records, and
{opt us:ing(filename)} names a {cmd:.dta} file holding them. Exactly one of
the two is required.

{phang}
{opt start(name)} and {opt stop(name)} are the columns in the source that hold
each record's interval bounds. Each is a single column name.

{phang}
{opt expos:ure(namelist)} names the input variable(s) to read from the source
and {opt gen:erate(namelist)} names the output variable(s) to create from
them. The two are mapped position by position and must name the same number
of variables. An {cmd:episodes} source declares exactly one of each.

{phang}
{opt ref:erence(#)} is the whole-number category that fills time not covered by
any episode. It is required for an {cmd:episodes} source and not allowed for an
{cmd:intervals} source, which is already constructed.

{phang}
{opt kind(string)} is {cmd:episodes} (the default) for raw records that must be
tiled against each person's follow-up window, or {cmd:intervals} for a source
that is already an interval table.

{phang}
{opt referencel:abel(string)} labels the reference category and
{opt lab:el(string)} labels the generated variable. Both describe an
{cmd:episodes} source only.

{phang}
{opt desc:ription(string)} is free text recorded with the source and carried
into the provenance manifest.

{phang}
{opt rate(namelist)}, {opt tot:al(namelist)}, and {opt cum:ulative(namelist)}
declare which of the {opt exposure()} variables are quantities and how each is
apportioned across split intervals. They apply to an {cmd:intervals} source; each
must name variables that appear in {opt exposure()}, and the three lists must
not overlap.


{marker remarks}{...}
{title:Remarks}

{pstd}
The specification frame is data, never command text. {cmd:tvspec} writes typed
cells with the value already resolved, and refuses a value containing a
backtick, a dollar sign, or a double quote -- those characters would be
expanded as macro references when {cmd:tvbuild} later reads the cell back,
which turns a data cell into macro indirection and usually reads as empty
rather than as an error.

{pstd}
To pass a path held in a local macro, let the macro expand as usual, so that
{cmd:tvspec add myspec, using("`episodes'") ...} stores the resolved path.


{marker examples}{...}
{title:Examples}

{pstd}Two sources, described in three lines{p_end}
{phang2}{cmd:. tvspec create study_spec, replace}{p_end}
{phang2}{cmd:. tvspec add study_spec, name(antidep) using("antidep.dta") start(rx_start) stop(rx_stop) exposure(drug) reference(0) generate(tv_drug) referencelabel("Unexposed") label("Antidepressant class")}{p_end}
{phang2}{cmd:. tvspec add study_spec, name(benzo) using("benzo.dta") start(rx_start) stop(rx_stop) exposure(benzo_use) reference(0) generate(tv_benzo) referencelabel("No benzo") label("Benzodiazepine use")}{p_end}

{pstd}Review it before building{p_end}
{phang2}{cmd:. tvspec list study_spec}{p_end}

{pstd}Build with it{p_end}
{phang2}{cmd:. tvbuild, specframe(study_spec) id(id) entry(study_entry) exit(study_exit) frameout(analysis)}{p_end}

{pstd}A source that is already an interval table, carrying a rate quantity{p_end}
{phang2}{cmd:. tvspec add study_spec, name(labs) frame(lab_intervals) start(start) stop(stop) exposure(egfr) generate(tv_egfr) kind(intervals) rate(egfr)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvspec create} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_sources)}}0{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(specframe)}}name of the frame created{p_end}

{pstd}
{cmd:tvspec add} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_sources)}}rows in the frame after the append{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(source_name)}}logical name appended{p_end}
{synopt:{cmd:r(specframe)}}name of the frame written to{p_end}

{pstd}
{cmd:tvspec list} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_sources)}}rows in the frame{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(source_names)}}source names in row order{p_end}
{synopt:{cmd:r(specframe)}}name of the frame listed{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
{space 2}Help: {help tvbuild}, {help tvexpose}, {help tvmerge}, {help tvtools}
{p_end}

{hline}
