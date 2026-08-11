/*  demo_pkgtransfer.do - Feature demo for pkgtransfer

    Produces, in pkgtransfer/demo/:
      1. console_scripts.log/.md       - all, limited(), skip(), dofile(), os()
      2. console_local_bundle.log/.md  - download(local), zipfile(), offline installer
      3. console_online_bundle.log/.md - download(online), live download progress
      4. console_restore.log/.md       - offline installation and restore

    Run from the Stata-Tools repository root. The online-bundle section needs
    internet access. All package installations, generated scripts, archives,
    and extracted files live under temporary PLUS/PERSONAL/work directories;
    the demo restores session paths and removes those temporary files on exit.
*/

version 16.0
set varabbrev off
set linesize 120

capture program drop _pkgtransfer_demo_rmtree
program define _pkgtransfer_demo_rmtree, nclass
    version 16.0
    syntax, DIRectory(string)

    local subdirs : dir `"`directory'"' dirs "*", respectcase
    foreach subdir of local subdirs {
        _pkgtransfer_demo_rmtree, directory(`"`directory'/`subdir'"')
    }

    local files : dir `"`directory'"' files "*", respectcase
    foreach filename of local files {
        erase `"`directory'/`filename'"'
    }
    rmdir `"`directory'"'
end

**# Paths and isolated package inventory
local repo_dir "`c(pwd)'"
local pkg_dir "`repo_dir'/pkgtransfer/demo"
local remote_source "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/pkgtransfer"
capture mkdir "`pkg_dir'"

local original_dir "`c(pwd)'"
local original_plus "`c(sysdir_plus)'"
local original_personal "`c(sysdir_personal)'"
local sysdirs_changed 0
local active_log ""

tempfile sandbox_base
local sandbox "`sandbox_base'_dir"
local source_plus "`sandbox'/source_plus"
local source_personal "`sandbox'/source_personal"
local source_work "`sandbox'/source_work"
local destination_plus "`sandbox'/destination_plus"
local destination_personal "`sandbox'/destination_personal"
local destination_work "`sandbox'/destination_work"
local online_extract "`sandbox'/online_extract"
local conversion_plus "`sandbox'/conversion_plus"
local conversion_personal "`sandbox'/conversion_personal"

capture noisily {
    foreach directory in ///
        `"`sandbox'"' ///
        `"`source_plus'"' ///
        `"`source_personal'"' ///
        `"`source_work'"' ///
        `"`destination_plus'"' ///
        `"`destination_personal'"' ///
        `"`destination_work'"' ///
        `"`online_extract'"' ///
        `"`conversion_plus'"' ///
        `"`conversion_personal'"' {
        mkdir `"`directory'"'
    }

    sysdir set PLUS "`source_plus'"
    sysdir set PERSONAL "`source_personal'"
    local sysdirs_changed 1

    capture ado uninstall pkgtransfer
    quietly net install pkgtransfer, from("`repo_dir'/pkgtransfer") replace

    * Build a controlled two-package tracker. pkgtransfer is real and locally
    * installed; demofixture makes filtering behavior visible without touching
    * packages in the user's actual PLUS directory.
    mkdir "`source_plus'/d"
    tempname fixture_fh tracker_fh
    file open `fixture_fh' using ///
        "`source_plus'/d/demofixture.ado", write text replace
    file write `fixture_fh' "program define demofixture" _n
    file write `fixture_fh' "    version 16.0" _n
    file write `fixture_fh' ///
        `"    display as result "pkgtransfer demo fixture""' _n
    file write `fixture_fh' "end" _n
    file close `fixture_fh'

    file open `tracker_fh' using "`source_plus'/stata.trk", ///
        write text replace
    file write `tracker_fh' "S `remote_source'" _n
    file write `tracker_fh' "N pkgtransfer.pkg" _n
    file write `tracker_fh' "d pkgtransfer feature demo" _n
    file write `tracker_fh' "f p/pkgtransfer.ado" _n
    file write `tracker_fh' "f p/pkgtransfer.sthlp" _n
    file write `tracker_fh' "e" _n
    file write `tracker_fh' "S https://example.org/stata" _n
    file write `tracker_fh' "N demofixture.pkg" _n
    file write `tracker_fh' "d filtering fixture" _n
    file write `tracker_fh' "f d/demofixture.ado" _n
    file write `tracker_fh' "e" _n
    file close `tracker_fh'

    cd "`source_work'"

    foreach artifact in ///
        console_output.log console_output.md ///
        console_scripts.log console_scripts.md ///
        console_local_bundle.log console_local_bundle.md ///
        console_online_bundle.log console_online_bundle.md ///
        console_restore.log console_restore.md {
        capture erase "`pkg_dir'/`artifact'"
    }

    **# 1. Online scripts and package filters
    capture log close _all
    local active_log "scripts"
    log using "`pkg_dir'/console_scripts.log", ///
        replace text name(scripts) nomsg

    * # All eligible packages
    noisily pkgtransfer, dofile("_all_packages.do")
    noisily return list
    noisily type "_all_packages.do"

    * # limited() normalizes repeated package names
    noisily pkgtransfer, limited(pkgtransfer pkgtransfer) ///
        os(MacOSX) dofile("_limited_packages.do")
    noisily return list

    * # skip() excludes an exact package name
    noisily pkgtransfer, skip(demofixture) ///
        dofile("_skip_packages.do")
    noisily return list

    log close scripts
    local active_log ""

    assert strpos(fileread("_all_packages.do"), ///
        "net install demofixture") > 0
    assert strpos(fileread("_all_packages.do"), ///
        "net install pkgtransfer") > 0
    assert strpos(fileread("_limited_packages.do"), ///
        "net install pkgtransfer") > 0
    assert strpos(fileread("_limited_packages.do"), ///
        "demofixture") == 0
    assert strpos(fileread("_skip_packages.do"), ///
        "net install pkgtransfer") > 0
    assert strpos(fileread("_skip_packages.do"), ///
        "demofixture") == 0

    **# 2. Local offline bundle
    local active_log "local_bundle"
    log using "`pkg_dir'/console_local_bundle.log", ///
        replace text name(local_bundle) nomsg

    * # Build an offline bundle from installed PLUS files
    noisily pkgtransfer, download(local) limited(pkgtransfer) ///
        os(Windows) dofile("_offline_install.do") ///
        zipfile("_offline_bundle.zip")
    noisily return list

    log close local_bundle
    local active_log ""

    confirm file "_offline_install.do"
    confirm file "_offline_bundle.zip"
    assert strpos(fileread("_offline_install.do"), ///
        `"unzipfile "_offline_bundle.zip", replace"') > 0
    assert strpos(fileread("_offline_install.do"), ///
        "shell rmdir /s /q") > 0

    **# 3. Online offline bundle
    local active_log "online_bundle"
    log using "`pkg_dir'/console_online_bundle.log", ///
        replace text name(online_bundle) nomsg

    * # Download a fresh offline bundle from the recorded source URL
    noisily pkgtransfer, download(online) limited(pkgtransfer) ///
        os(MacOSX) dofile("_online_bundle_install.do") ///
        zipfile("_online_bundle.zip")
    noisily return list

    log close online_bundle
    local active_log ""

    confirm file "_online_bundle_install.do"
    confirm file "_online_bundle.zip"
    cd "`online_extract'"
    quietly unzipfile "`source_work'/_online_bundle.zip", replace
    confirm file "pkgtransfer_files/pkgtransfer.pkg"
    confirm file "pkgtransfer_files/pkgtransfer.ado"
    confirm file "pkgtransfer_files/pkgtransfer.sthlp"
    confirm file "pkgtransfer_files/stata.toc"
    assert strpos(fileread("pkgtransfer_files/pkgtransfer.pkg"), ///
        "v 3") == 1
    assert strpos(fileread("pkgtransfer_files/pkgtransfer.pkg"), ///
        "d pkgtransfer-source `remote_source'") > 0

    **# 4. Install an offline bundle and restore its source URL
    copy "`source_work'/_offline_install.do" ///
        "`destination_work'/_offline_install.do", replace
    copy "`source_work'/_offline_bundle.zip" ///
        "`destination_work'/_offline_bundle.zip", replace
    cd "`destination_work'"
    sysdir set PLUS "`destination_plus'"
    sysdir set PERSONAL "`destination_personal'"
    quietly do "_offline_install.do"
    capture program drop pkgtransfer

    confirm file "`destination_plus'/p/pkgtransfer.ado"
    confirm file "`destination_plus'/p/pkgtransfer.sthlp"
    confirm file "`destination_plus'/stata.trk"
    assert strpos(fileread("`destination_plus'/stata.trk"), ///
        "d pkgtransfer-source `remote_source'") > 0

    local active_log "restore"
    log using "`pkg_dir'/console_restore.log", ///
        replace text name(restore) nomsg

    * # Restore the original online source after offline installation
    noisily pkgtransfer, restore
    noisily return list
    noisily type "`destination_plus'/stata.trk"

    log close restore
    local active_log ""

    confirm file "`destination_plus'/stata.trk.backup"
    assert strpos(fileread("`destination_plus'/stata.trk"), ///
        "S `remote_source'") > 0
    assert strpos(fileread("`destination_plus'/stata.trk"), ///
        "d pkgtransfer-source") == 0
    assert strpos(fileread("`destination_plus'/stata.trk.backup"), ///
        "d pkgtransfer-source `remote_source'") > 0

    **# Convert console logs to markdown
    cd "`source_work'"
    sysdir set PLUS "`conversion_plus'"
    sysdir set PERSONAL "`conversion_personal'"
    capture ado uninstall logdoc
    quietly net install logdoc, from("`repo_dir'/logdoc") replace

    foreach output in ///
        console_scripts ///
        console_local_bundle ///
        console_online_bundle ///
        console_restore {
        logdoc using "`pkg_dir'/`output'.log", ///
            output("`pkg_dir'/`output'.md") ///
            format(md) replace quiet
    }

    **# Verify markdown content
    assert strpos(fileread("`pkg_dir'/console_scripts.md"), ///
        "demofixture") > 0
    assert strpos(fileread("`pkg_dir'/console_scripts.md"), ///
        "limited()") > 0
    assert strpos(fileread("`pkg_dir'/console_scripts.md"), ///
        "skip()") > 0
    assert strpos(fileread("`pkg_dir'/console_local_bundle.md"), ///
        "download(local)") > 0
    assert strpos(fileread("`pkg_dir'/console_local_bundle.md"), ///
        "_offline_bundle.zip") > 0
    assert strpos(fileread("`pkg_dir'/console_online_bundle.md"), ///
        "download(online)") > 0
    assert strpos(fileread("`pkg_dir'/console_online_bundle.md"), ///
        "Progress: 1/1 packages") > 0
    assert strpos(fileread("`pkg_dir'/console_restore.md"), ///
        "Installation pathways restored") > 0
    assert strpos(fileread("`pkg_dir'/console_restore.md"), ///
        "S `remote_source'") > 0

    clear
}
local demo_rc = _rc

**# Restore session state and clean temporary files
if "`active_log'" != "" capture log close `active_log'
capture cd "`original_dir'"
if `sysdirs_changed' {
    capture sysdir set PERSONAL "`original_personal'"
    capture sysdir set PLUS "`original_plus'"
}
capture _pkgtransfer_demo_rmtree, directory("`sandbox'")
capture program drop _pkgtransfer_demo_rmtree

if `demo_rc' exit `demo_rc'
