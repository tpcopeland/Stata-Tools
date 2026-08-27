* _finegray_qa_common.do - shared QA bootstrap for finegray

version 16.0
set more off
set varabbrev off

capture program drop _finegray_qa_bootstrap
program define _finegray_qa_bootstrap, rclass
    version 16.0

    local qa_dir "`c(pwd)'"
    local pkg_dir = regexr("`qa_dir'", "/qa$", "")
    capture confirm file "`pkg_dir'/finegray.pkg"
    if _rc {
        display as error "run_all.do must be run from the finegray/qa directory"
        exit 601
    }

    local orig_plus "`c(sysdir_plus)'"
    local orig_personal "`c(sysdir_personal)'"
    * tempname counters restart at __000000 in every Stata process, so they are
    * not safe directory identifiers: concurrent lanes otherwise uninstall and
    * replace each other's helpers.  tempfile paths include Stata's process id
    * (for example, /tmp/St12345.000001), which makes these directories unique.
    tempfile install_anchor
    local plus_dir "`install_anchor'_plus"
    local personal_dir "`install_anchor'_personal"

    capture mkdir "`plus_dir'"
    capture mkdir "`personal_dir'"
    sysdir set PLUS "`plus_dir'"
    sysdir set PERSONAL "`personal_dir'"
    discard

    capture ado uninstall finegray
    capture noisily net install finegray, from("`pkg_dir'") replace
    local install_rc = _rc
    if `install_rc' {
        sysdir set PLUS "`orig_plus'"
        sysdir set PERSONAL "`orig_personal'"
        discard
        capture shell rm -rf "`plus_dir'" "`personal_dir'"
        exit `install_rc'
    }

    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
    return local orig_plus "`orig_plus'"
    return local orig_personal "`orig_personal'"
    return local plus_dir "`plus_dir'"
    return local personal_dir "`personal_dir'"
end

* -----------------------------------------------------------------------------
* Seeded fixture builders.
*
* The flagship cross-validation fixture (webuse hypoxia) has ZERO cause-event
* times shared with a censored observation, so every oracle built on it is
* structurally blind to the censoring-tie convention: a G(t) implementation and
* a G(t-) implementation agree on it exactly.  That is why a 347/347 green suite
* coexisted with a live tie defect through v1.1.4.  The builders below exist to
* give the suite fixtures that CAN see these defects.
* -----------------------------------------------------------------------------

* Deliberately tied competing-risks data: discrete times 1..8, so censoring
* times routinely collide with cause- and competing-event times.  This is the
* fixture that separates G(t-) (cmprsk, stcrreg) from post-jump G(t).
capture program drop _finegray_qa_tied_data
program define _finegray_qa_tied_data
    version 16.0
    syntax [, N(integer 300) SEED(integer 20260712)]

    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x = rnormal()

    * latent cause / competing / censoring times, all on the same coarse grid
    gen double lp1 = 0.4 * x
    gen double lp2 = -0.2 * x
    gen byte tc1 = 1 + floor(8 * runiform()^exp(-lp1))
    gen byte tc2 = 1 + floor(8 * runiform()^exp(-lp2))
    gen byte tcens = 1 + floor(8 * runiform())
    quietly replace tc1 = 8 if tc1 > 8
    quietly replace tc2 = 8 if tc2 > 8
    quietly replace tcens = 8 if tcens > 8

    gen double t = min(tc1, tc2, tcens)
    gen byte etype = 0
    quietly replace etype = 1 if tc1 <= tc2 & tc1 <= tcens
    quietly replace etype = 2 if tc2 <  tc1 & tc2 <= tcens
    quietly replace etype = 0 if tcens < tc1 & tcens < tc2
    drop lp1 lp2 tc1 tc2 tcens
end

* Delayed-entry data with a block of subjects entering at EXACTLY time 5, with
* cause events at 5.  Stata intervals are (t0, t], so such a subject is not at
* risk for a failure at 5 -- nudging its entry to 5+1e-7 (no event times in
* between) must leave every coefficient bit-identical, as stcrreg's does.
capture program drop _finegray_qa_entry_data
program define _finegray_qa_entry_data
    version 16.0
    syntax [, SEED(integer 4242) EPS(real 0)]

    clear
    set seed `seed'
    quietly set obs 400
    gen long id = _n
    gen double x = rnormal()
    gen double t = 1 + floor(10 * runiform())
    gen byte etype = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))

    * 80 subjects enter at exactly 5 (or 5+eps) and exit strictly after
    gen double t0 = 0
    quietly replace t0 = 5 + `eps' in 1/80
    quietly replace t = 5 + ceil(5 * runiform()) in 1/80
end

* Globally full-rank design (so _rmcoll passes) in which x2 is nonzero ONLY for
* subjects censored before the first cause event.  x2 therefore enters no
* cause-event risk set, the likelihood is flat in that direction, and the
* information matrix is rank deficient -- the direction is unidentified.
capture program drop _finegray_qa_unident_data
program define _finegray_qa_unident_data
    version 16.0
    syntax [, SEED(integer 777)]

    clear
    set seed `seed'
    quietly set obs 400
    gen long id = _n
    gen double x = rnormal()
    gen double u = runiform()

    * cause and competing events only from t >= 3 ...
    gen double t = 3 + floor(6 * runiform())
    gen byte etype = cond(u < .45, 1, 2)
    * ... while the first 60 subjects are censored at t = 1 or 2
    quietly replace t = 1 + floor(2 * runiform()) in 1/60
    quietly replace etype = 0 in 1/60

    gen double x2 = 0
    quietly replace x2 = rnormal() in 1/60
    drop u
end

* -----------------------------------------------------------------------------
* Fence probes: assert on (rc, TOKENS), never on a whole sentence.
*
* WHY.  Every scope fence in this package is a hard refusal whose message names
* the reason and the alternative.  Tests that pinned those sentences coupled
* correctness to wording: one rewording of one refusal turned a lattice of
* fence tests red at once, and the pressure that creates is to soften the
* message rather than to keep the fence honest.
*
* The stable contract is therefore declared to be two things and only two:
*
*   1. the RETURN CODE.  198 is a syntax/option fence (the combination is
*      refused before any data is touched); 459 is a data fence (something that
*      should be true of the data is not); 301 is a post-estimation fence (the
*      fit in e() cannot support this request).
*   2. the OPTION NAMES the refusal is about, spelled as the user types them --
*      `nuisance', `bstrata()', `tvc()', `truncstrata()'.  No rewording of a
*      refusal removes the names of the options it is refusing, and a rewording
*      that DID remove them would be a real regression in the message.
*
* Everything else in the sentence -- the citation, the suggested alternative,
* the help link -- is prose, and exactly ONE test in the suite pins it:
* the wording canary in test_finegray_errors.do.  A rewording therefore breaks
* one test, in one place, on purpose.
*
* _finegray_qa_fence runs a command, captures its output, and returns
*   r(rc)       the return code
*   r(ntok)     how many of the supplied tokens appeared in the message
*   r(ok)       1 iff rc matched AND every token appeared
*   r(log)      the captured output file, for the canary to read
* -----------------------------------------------------------------------------
capture program drop _finegray_qa_fence
program define _finegray_qa_fence, rclass
    version 16.0
    * The command travels in an OPTION, not as the leading argument: every
    * refusal worth probing is an option combination, so the command line is
    * full of commas and any gettoken split on "," would cut it in half.
    syntax , CMD(string) [RC(integer 198) TOKens(string) NOCHECKrc]

    tempfile cap
    capture log close _fgfence
    quietly log using "`cap'", replace text name(_fgfence)
    capture noisily `cmd'
    local got_rc = _rc
    capture log close _fgfence

    local ntok = 0
    local nwant : word count `tokens'
    tempname fh
    local blob ""
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        local blob `"`blob' `line'"'
        file read `fh' line
    }
    file close `fh'
    foreach tk of local tokens {
        if strpos(`"`blob'"', `"`tk'"') > 0 local ++ntok
    }

    local ok = 1
    if "`nocheckrc'" == "" & `got_rc' != `rc' local ok = 0
    if `ntok' != `nwant' local ok = 0

    return scalar rc = `got_rc'
    return scalar ntok = `ntok'
    return scalar nwant = `nwant'
    return scalar ok = `ok'
    return local log "`cap'"
end

* Assert a fence: right return code, every token present.  Fails the enclosing
* capture block (rc 9) on any mismatch, so the caller needs no if/else.
capture program drop _finegray_qa_assert_fence
program define _finegray_qa_assert_fence
    version 16.0
    syntax , CMD(string) [RC(integer 198) TOKens(string)]
    _finegray_qa_fence, cmd(`"`cmd'"') rc(`rc') tokens(`tokens')
    if r(ok) != 1 {
        display as error `"fence probe failed: `cmd'"'
        display as error "  expected rc `rc', got r(rc) = " r(rc)
        display as error "  tokens matched " r(ntok) " of " r(nwant) ": `tokens'"
    }
    assert r(ok) == 1
end
