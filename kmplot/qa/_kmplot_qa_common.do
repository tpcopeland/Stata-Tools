version 16.0

capture program drop _kmplot_qa_bootstrap
program define _kmplot_qa_bootstrap
    version 16.0

    local qa_dir "`c(pwd)'"
    local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
    if "`pkg_dir'" == "`qa_dir'" {
        local pkg_dir "`qa_dir'/.."
    }

    local plus_dir "`c(tmpdir)'/kmplot_qa_plus"
    local personal_dir "`c(tmpdir)'/kmplot_qa_personal"
    capture mkdir "`plus_dir'"
    capture mkdir "`personal_dir'"
    sysdir set PLUS "`plus_dir'"
    sysdir set PERSONAL "`personal_dir'"

    capture ado uninstall kmplot
    quietly net install kmplot, from("`pkg_dir'") replace
    discard
    which kmplot
    which _kmplot_risktable
end

capture program drop _kmplot_assert_file_contains
program define _kmplot_assert_file_contains
    version 16.0
    syntax using/, PATTERN(string)

    tempname fh
    local found 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`pattern'"') > 0 {
            local found 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
end

capture program drop _kmplot_assert_file_not_contains
program define _kmplot_assert_file_not_contains
    version 16.0
    syntax using/, PATTERN(string)

    tempname fh
    local found 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`pattern'"') > 0 {
            local found 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found' == 0
end
