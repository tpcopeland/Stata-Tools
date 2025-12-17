{smcl}
{* *{* *! version 1.0.0  2025/12/02}{...}
{title:Title}

{p 4 2}
{hi:pkgtransfer} {hline 2} Transfer installed packages between Stata installations


{title:Syntax}

{p 8 17 2}
{cmd:pkgtransfer}
[{cmd:,} {it:options}]


{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{cmdab:down:load}}Create a ZIP file of all packages and a do-file for local installation.{p_end}
{synopt:{cmdab:limited}({it:pkglist})}Restricts the operation to only the specified packages. {it:pkglist} is a space-separated list of package names.{p_end}

{synoptline}
{p 4 4 2}

{title:Description}

{p 4 4 2}
{cmd:pkgtransfer} facilitates transferring installed packages from one Stata installation to another. It can generate a do-file with the necessary {cmd:net install}, {cmd:ssc install}, or {cmd:github install} commands for online installation on a new machine. Alternatively, it can download all the package files and create a local installation script and a ZIP archive for offline installation.

{p 4 4 2}
The command works by reading the {cmd:stata.trk} file in your current PLUS directory to identify installed packages and their sources. It can handle packages installed from various sources, including SSC, personal websites, and GitHub (using the {browse "https://github.com/haghish/github":github} command).

{p 4 4 2}
{cmd:NOTE}: It is strongly suggested that when using the {opt download} option, first {cmd:pkgtransfer} is run to save all the original package installation commands for online installation (i.e., {cmd: pkgtransfer}) and the resulting {cmd:pkgtransfer.do} is moved to a separate folder. 

{title:Options}

{dlgtab:Main}

{phang}
{opt download} specifies that you want to create a ZIP file containing all the package files and a do-file ({cmd:pkgtransfer_local.do}) for installing the packages locally. This is useful for machines without internet access or for creating backups of your installed packages. When {opt download} is not specified, {cmd:pkgtransfer} generates a do-file ({cmd:pkgtransfer.do}) with online installation commands.

{phang}
{opt limited}({it:pkglist}) restricts the operation to a specific set of packages.  {it:pkglist} should be a space-separated list of package names, exactly as they appear in the {cmd:stata.trk} file. For example, {cmd:limited(estout outreg2)}. When {opt limited()} is not specified, {cmd:pkgtransfer} processes all packages listed in the {cmd:stata.trk} file.

{title:Examples}

{p 4 4 2}
{cmd:. pkgtransfer}
{break}
Generates a do-file ({cmd:pkgtransfer.do}) for online installation of all packages listed in your {cmd:stata.trk} file.

{p 4 4 2}
{cmd:. pkgtransfer, download}
{break}
Downloads all packages and creates a local installation script ({cmd:pkgtransfer_local.do}) and a ZIP archive ({cmd:pkgtransfer_files.zip}).

{p 4 4 2}
{cmd:. pkgtransfer, limited(estout outreg2)}
{break}
Generates a do-file for online installation of only the "estout" and "outreg2" packages.

{p 4 4 2}
{cmd:. pkgtransfer, download limited(estout outreg2)}
{break}
Downloads only the "estout" and "outreg2" packages and creates a local installation script and ZIP archive.

{p 4 4 2}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:pkgtransfer} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_packages)}}number of packages processed{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(package_list)}}list of packages processed{p_end}
{synopt:{cmd:r(download_mode)}}download mode ("local", "online", or "script_only"){p_end}
{synopt:{cmd:r(os)}}target operating system{p_end}
{synopt:{cmd:r(dofile)}}path to generated do-file{p_end}
{synopt:{cmd:r(zipfile)}}path to ZIP file (if download mode is "local"){p_end}
{p2colreset}{...}

{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.0 - 2025-12-02{p_end}