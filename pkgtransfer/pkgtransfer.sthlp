{smcl}
{* *! version 1.2.1  12oct2026}{...}
{vieweralsosee "[R] net install" "help net_install"}{...}
{title:Title}

{p 4 2}
{hi:pkgtransfer} {hline 2} Transfer installed packages between Stata installations


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:pkgtransfer}
[{cmd:,} {it:options}]


{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{cmdab:down:load(}{it:string}{cmd:)}}download mode: {bf:local} or {bf:online}{p_end}
{synopt:{cmdab:lim:ited}({it:pkglist})}restrict to specified packages{p_end}
{synopt:{opt skip(pkglist)}}exclude specified packages{p_end}
{synopt:{cmdab:res:tore}}restore online source URLs in stata.trk{p_end}

{syntab:Advanced}
{synopt:{opt os(string)}}target OS and plugin filter{p_end}
{synopt:{cmdab:do:file(}{it:filename}{cmd:)}}custom name for generated do-file{p_end}
{synopt:{cmdab:zip:file(}{it:filename}{cmd:)}}custom name for generated ZIP file{p_end}
{synopt:{opt replace}}overwrite an existing do-file or ZIP file{p_end}
{synoptline}

{marker description}{...}
{title:Description}

{p 4 4 2}
{cmd:pkgtransfer} facilitates transferring installed packages from one Stata
installation to another. It can generate a do-file with the necessary
{cmd:net install}, {cmd:ssc install}, or {cmd:github install} commands for online installation
on a new machine. Alternatively, it can download all the package files and
create a local installation script and a ZIP archive for offline installation.

{p 4 4 2}
The command works by reading the {cmd:stata.trk} file in your current PLUS directory
to identify installed packages and their sources. It can handle packages
installed from various sources, including SSC, personal websites, and GitHub
(using the {browse "https://github.com/haghish/github":github} command).

{p 4 4 2}
The output is a list of package {it:sources}, not a snapshot of package
{it:versions}; see {help pkgtransfer##remarks:Remarks}.

{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opt download(string)} specifies the download mode for creating offline installation
packages: {bf:local} or {bf:online}, in any case. {opt download(online)} downloads all package files from the internet and
creates a ZIP archive and local installation do-file. {opt download(local)} copies
package files from your local PLUS directory instead of downloading
them. {opt download(local)} reads each package's source descriptor to find files
installed by platform-specific {cmd:g} or {cmd:G} records (plugins, or any other
file type); those files are downloaded for every platform even with
{opt download(local)}, because the local PLUS directory only contains the current
platform's version. If a package's source descriptor cannot be read, its files are
bundled as installed on this machine and a note names the package. Two cases
fail instead (r(601)), with a message naming the package: a package with a
{cmd:.plugin} file, and a package installed from a {cmd:pkgtransfer} bundle whose
{cmd:pkgtransfer_files} folder is no longer readable, because its platform-specific
files cannot be identified without the descriptor. For the second case, run
{cmd:pkgtransfer, restore} on its own first so that the original source is
read. By default, every OS variant is bundled; explicitly specifying
{opt os()} limits platform files and descriptor records to that OS. A
{cmd:g}-installed file with no record for the requested OS is an error
(r(498)), as is a {cmd:.plugin} file with no platform record at all. Bundled
descriptors keep {cmd:F} records, so data or other non-ado files that the source
forced into the system directories are installed there on the
destination; {opt download(local)} writes every tracked file as an {cmd:F} record,
because a tracked file was installed into the system directories. When neither {opt download()}
nor {opt restore} is specified, {cmd:pkgtransfer} generates a do-file
({cmd:pkgtransfer.do}) with online installation commands only (no ZIP archive). Bundle
creation refuses to reuse an existing {cmd:pkgtransfer_files} directory, so move or
remove that directory before rerunning a download mode. Missing required package
files abort bundle creation instead of producing an incomplete archive. Generated
package descriptors and {cmd:stata.toc} use Stata's version-3
distribution format. Plugin source and target paths are normalized into the
bundle, while the original {cmd:g}/{cmd:G} installation semantics are preserved.

{phang}
{opt limited(pkglist)} restricts the operation to a specific set of
packages. {it:pkglist} should be a space-separated list of package names, exactly
as they appear in the {cmd:stata.trk} file. For example,
{cmd:limited(estout outreg2)}. When {opt limited()} is not specified,
{opt download(local)} processes every package listed in {cmd:stata.trk}, while
the default mode and {opt download(online)} process the packages whose recorded
source is a URL ({it:scheme}{cmd:://}..., such as {cmd:https://}). Packages
installed from a local absolute path are omitted from those two modes, and a
note names them; name them in {opt limited()} to include them. Repeated package
names are normalized to one selection while preserving the order supplied.

{phang}
{opt skip(pkglist)} excludes the specified packages from the transfer. {it:pkglist}
should be a space-separated list of package names to skip. For example,
{cmd:skip(estout outreg2)} would transfer all packages except estout
and outreg2. The same package may not appear in both {opt limited()} and
{opt skip()}. If {opt skip()} excludes every tracked package,
{cmd:pkgtransfer} creates the requested empty script or bundle rather than
failing. Repeated names are normalized to one exclusion.

{phang}
{opt restore} restores installation pathways in {cmd:stata.trk} to point to original
online sources after a local installation. Can be used as a standalone option
({cmd:pkgtransfer, restore}) or combined with {opt download()}. Combined with
{opt download()}, {cmd:pkgtransfer} first writes the bundle and then restores
{it:this} machine's {cmd:stata.trk}; it is the same as running the two commands in
sequence. Because the bundle is written first, the combination does not help a
machine set up from a bundle whose {cmd:pkgtransfer_files} folder has been
removed; there, run {cmd:pkgtransfer, restore} alone first, then {opt download()}. Standalone
{opt restore} cannot be combined with
{opt limited()}, {opt skip()}, {opt os()}, {opt dofile()}, {opt zipfile()}, or {opt replace}. With or
without {opt download()}, {opt restore} rewrites every backup marker in
{cmd:stata.trk}; {opt limited()} and {opt skip()} do not narrow it. This
works only for packages installed from {cmd:pkgtransfer}-generated ZIP
archives, which embed the original source URL as backup metadata. A bundle made
on a machine that was itself set up from a bundle carries the original source
forward in {cmd:stata.trk}, so {opt restore} returns the first machine's source
after any number of transfers. Until {opt restore} is run, {opt download(local)} on
such a machine reads package descriptors from the bundle folder that
{cmd:stata.trk} records. Before
modifying {cmd:stata.trk}, {cmd:pkgtransfer} copies it to
{cmd:stata.trk.backup}, or to {cmd:stata.trk.backup1}, {cmd:stata.trk.backup2},
... when earlier backups exist; an existing backup is never overwritten. All
other tracker lines are kept unchanged. If no backup URLs are found, a warning
is displayed and nothing is written. If the installer upgraded an existing
copy, {cmd:stata.trk} lists that package twice; {opt restore} still runs and
names the duplicates, which {cmd:ado dir} and {cmd:ado uninstall [}{it:#}{cmd:]}
can remove.

{dlgtab:Advanced}

{phang}
{opt os(string)} specifies the target operating system for the installation script
cleanup commands and limits an offline bundle to platform-file variants for that OS. Valid
options are {bf:Windows}, {bf:Unix}, or {bf:MacOSX}, in any case. Plugin platforms are
matched by family: {cmd:WIN}* for Windows, {cmd:LINUX}* or {cmd:UNIX}* for Unix,
and {cmd:MAC}* or {cmd:OSX.}* for MacOSX, which includes the console platforms
{cmd:OSX.ARM64} and {cmd:OSX.X8664}. When omitted, the installer uses the
current OS and an offline bundle includes every OS plugin variant.

{phang}
{opt dofile(filename)} specifies a custom name for the generated do-file. The
filename must end with {bf:.do} and may not contain shell metacharacters or quote
characters. Default is {cmd:pkgtransfer.do}.

{phang}
{opt zipfile(filename)} specifies a custom name for the generated ZIP file. The
filename must end with {bf:.zip}. Default is {cmd:pkgtransfer_files.zip}. Only valid with
{opt download()}. The generated installer refers to the archive by its file
name only (without the directory), so keep the do-file and ZIP file in the same
directory and run the installer from there. Shell metacharacters and quote
characters are not allowed.

{phang}
{opt replace} permits {cmd:pkgtransfer} to overwrite an existing do-file or ZIP
file. Without it, an existing output is an error (r(602)) and nothing is written.

{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:pkgtransfer} records where packages came from, not which versions were
installed:

{phang2}o{space 2}The default script and {opt download(online)} install whatever the
recorded source offers {it:now}. If a package has been updated since it was
installed here, the destination gets the newer version.{p_end}

{phang2}o{space 2}{opt download(local)} is the only mode that preserves the installed
{cmd:.ado}, help, and other files. Files installed by {cmd:g}/{cmd:G} records,
such as plugins, are still downloaded from the current source, so they may come
from a newer release than the bundled {cmd:.ado} files.{p_end}

{phang2}o{space 2}Packages from E. F. Haghish's GitHub pages are mapped to
{cmd:https://raw.githubusercontent.com/haghish/}{it:pkg}{cmd:/master} and written as
{cmd:github install haghish/}{it:pkg}{cmd:, stable}, which installs the latest
release. A repository whose default branch is not {cmd:master} fails in
{opt download(online)}.{p_end}

{phang2}o{space 2}Only packages recorded in the current PLUS {cmd:stata.trk} are
considered.{p_end}

{marker examples}{...}
{title:Examples}

{p 4 4 2}
{cmd:. pkgtransfer}
{break}
Generates a do-file ({cmd:pkgtransfer.do}) for online installation of all packages listed in your {cmd:stata.trk} file.

{p 4 4 2}
{cmd:. pkgtransfer, download(online)}
{break}
Downloads all packages from the internet and creates a local installation
script ({cmd:pkgtransfer.do}) and a ZIP archive ({cmd:pkgtransfer_files.zip}).

{p 4 4 2}
{cmd:. pkgtransfer, download(local)}
{break}
Copies all packages from your local PLUS directory and creates a local installation
script and ZIP archive containing all OS plugin variants.

{p 4 4 2}
{cmd:. pkgtransfer, download(local) os(Unix)}
{break}
Creates a Unix-targeted bundle containing Linux/Unix plugin variants only.

{p 4 4 2}
{cmd:. pkgtransfer, limited(estout outreg2)}
{break}
Generates a do-file for online installation of only the "estout" and "outreg2" packages.

{p 4 4 2}
{cmd:. pkgtransfer, download(online) limited(estout outreg2)}
{break}
Downloads only the "estout" and "outreg2" packages and creates a local installation script and ZIP archive.

{p 4 4 2}
{cmd:. pkgtransfer, skip(gtools)}
{break}
Generates a do-file for all packages except "gtools".

{p 4 4 2}
{cmd:. pkgtransfer, download(online) dofile(my_install.do) zipfile(my_packages.zip)}
{break}
Downloads packages with custom output file names.

{p 4 4 2}
{cmd:. pkgtransfer, dofile(my_install.do) replace}
{break}
Rewrites an existing {cmd:my_install.do}.

{p 4 4 2}
{cmd:. pkgtransfer, restore}
{break}
Restores online source URLs in {cmd:stata.trk} for packages previously installed via pkgtransfer ZIP archive.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:pkgtransfer} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_packages)}}number of packages processed{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(package_list)}}list of packages processed{p_end}
{synopt:{cmd:r(download_mode)}}local, online, script_only, or restore{p_end}
{synopt:{cmd:r(os)}}target operating system ({cmd:Windows}, {cmd:Unix}, or {cmd:MacOSX}){p_end}
{synopt:{cmd:r(dofile)}}do-file name or path as specified{p_end}
{synopt:{cmd:r(zipfile)}}ZIP file name or path as specified (download modes){p_end}
{p2colreset}{...}

{pstd}
Standalone {opt restore} returns only {cmd:r(download_mode)} = {cmd:restore}
and {cmd:r(os)}. It does not set the package-count, package-list, do-file,
or ZIP-file results because it generates no installer or archive.

{pstd}
When {opt skip()} excludes every tracked package, {cmd:r(N_packages)} is 0 and
{cmd:r(package_list)} is empty. The requested do-file and, for a download
mode, ZIP archive are still created.

{pstd}
Local and online bundles preserve nested paths recorded by package
descriptors. Absolute paths, remaining parent traversal, and other unsafe
relative paths in tracking metadata abort bundle creation before a file is
written outside the invocation-owned staging directory.

{pstd}
Once package selection succeeds, the full standard return surface remains
available after a captured output-write or archive failure. The command still
exits with the original nonzero return code.

{pstd}
Generated offline installers use local macros, restore the caller's working
directory, and propagate installation failures without overwriting a caller's
global {cmd:package_dir} macro. They install with {cmd:net install ..., replace},
so an older copy on the destination is upgraded.

{pstd}
Bundle creation refuses conflicting payload paths and paths reserved for package
descriptors or stata.toc. Installer and archive outputs must be outside
pkgtransfer_files, which is removed after bundling. GitHub-origin entries need
github on the destination; when github itself is selected, its generated command
uses net install to bootstrap it.
{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.2.1, 2026-10-12{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}

{pstd}Check GitHub for the most up-to-date release; it may be newer than the version installed here.{p_end}

{hline}
