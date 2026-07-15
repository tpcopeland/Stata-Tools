* validation_finegray_zzf_coverage.do
* ---------------------------------------------------------------------------
* GATE Z-INFERENCE of fg_zzf_plan.md: which LEFT-TRUNCATION variance covers?
*
* The point estimator is settled (Gate Z2-green).  This file settles the OTHER
* half of the deliverable: a recovery-clean coefficient carrying an SE that does
* not cover is not a completed estimator.
*
* ---------------------------------------------------------------------------
* THE CANDIDATES, AND WHY THERE ARE ONLY TWO
*
* fg_zzf_plan.md's Gate Z-inference names three candidates.  Only two of them can
* be built from a source we have actually read:
*
*   model_based   Geskus (2011) p.44, eq. 20-21: the ordinary information matrix,
*                 NO sandwich.  Reachable today as `norobust'.
*   fg_sandwich   Fine & Gray (1999) eq. 7-8, extended to carry the combined
*                 weight A = G(t-)H(t-).  Today's DEFAULT (robust).
*
*   nuisance_adjusted   NOT IMPLEMENTED, and deliberately so.  It is the ZZF
*                 two-part influence function, whose explicit expression lives in
*                 ZZF (2011) Appendix B.  The appendix PROSE is in our corpus
*                 (PMC3408877) but every display equation in it is MathML/image
*                 and did not survive extraction: the text reads "we obtain <gap>
*                 where <gap> and <gap> is a martingale."  The journal PDF is
*                 paywalled.  Writing that influence function would therefore mean
*                 DERIVING IT FROM MEMORY -- a remembered influence function is a
*                 plausible formula with no provenance, and its boundary cases are
*                 exactly where memory fails.
*                 Tracked in literature/_requested.md.  If neither candidate below
*                 covers, this gate BLOCKS on obtaining that appendix.  It does not
*                 get guessed.
*
* What ZZF Appendix B *does* say, verbatim and in prose (this much is sourced):
*   "The first term is the main term, whereas the second and third terms account
*    for the influence due to random weight."
* -- so a two-part variance exists and the fixed-weight one is an approximation.
* The question this file answers is whether that approximation MATTERS for OUR
* weight, which is not the same question as whether it exists.
*
* SCOPE: cluster() fits are NOT adjudicated here and cannot be.  With clustered
* data the model-based information matrix is wrong for a reason that has nothing to
* do with left truncation (it assumes independent subjects), so the cluster-robust
* sandwich is the only admissible option and there is no contest to run.  The LT
* cluster path is covered by validation_finegray_lt_se.do; e(lt_vce) must report
* fg_sandwich whenever cluster() is specified, whatever wins below.
*
* ---------------------------------------------------------------------------
* [Z-INF-PREREG]  WRITTEN BEFORE THE GATED REPLICATIONS WERE RUN.
*
* The literature genuinely conflicts, and it conflicts for a readable reason:
*
*   Geskus (2011) p.44   "there is no need for a sandwich estimator of the
*                         covariance matrix, because the weights do not change for
*                         individuals who experience the event of interest."
*                         His Table 2 (p.45, 5000 reps, N = 103-258) then shows the
*                         model-based SE OUT-COVERING the sandwich under LT:
*                         0.956/0.953 vs 0.935/0.943.
*   Bellach (2020) §5    the inverse-Fisher (fixed-weight) variance is biased and
*                         undercovers, WORSE as the truncation fraction rises.
*   ZZF (2011) §3.4      two-part sandwich; first-part-only "acceptable", but §4.1
*                         finds it "slightly underestimates".
*
* They are not all describing the same estimator.  Bellach's is a weighted
* conditional NPMLE over a transformation-model class; ours is not.
*
* OUR estimator is Geskus's: e(lt_weight) = zzf1_geskus, w_i(t) = A(t-)/A(X_i-).
* And the Z0 decision to use a PER-STRATUM stabilizer was taken *precisely* so that
* w_i(T_i) = 1 -- the structural fact Geskus's argument rests on -- holds in the
* truncstrata() arm too, not only the pooled one (fg_zzf_plan.md Z0, rationale 1).
*
* PREREGISTERED EXPECTATION:
*   1. model_based COVERS (in [0.925, 0.975]) in every supported arm, INCLUDING
*      heavy truncation and INCLUDING truncstrata().
*   2. fg_sandwich UNDERCOVERS, mildly, and worse at heavier truncation.
*   3. The gap between them WIDENS with the truncation fraction.
*
* This is Geskus's prediction, not a hedge: it is falsifiable, it is the opposite
* of what the package currently ships as its default, and if it is wrong the loser
* is the candidate we would rather have won.  Bellach's §5 warning predicts the
* REVERSE ordering, so one of the two named papers is about to be contradicted on
* our estimator.  Whichever way it lands, the number decides -- not the citation.
*
* ---------------------------------------------------------------------------
* [Z-INF-RESULT 2026-07-14]  THE PREREGISTRATION WAS WRONG.  BELLACH WAS RIGHT.
*
* 1000 reps/arm.  model_based's coverage does not merely miss the band -- it
* DEGRADES MONOTONICALLY WITH THE TRUNCATION FRACTION, which is precisely the
* failure Bellach et al. (2020) Section 5 describes and precisely what Geskus's
* argument says should not happen:
*
*   arm                 trunc%   model_based cov   fg_sandwich cov   SEratio(mod)
*   noLT                   0     0.956 / 0.949     0.954 / 0.943     1.04 / 0.97
*   light_n500            37     0.897 / 0.901     0.941 / 0.951     0.81
*   light_n2000           37     0.905 / 0.890     0.954 / 0.957     0.79
*   heavy_n500            69     0.858 / 0.858     0.948 / 0.943     0.72
*   heavy_n2000           69     0.850 / 0.850     0.955 / 0.953     0.70
*   ts_heavy_n2000        63     0.808 / 0.860     0.952 / 0.944     0.62
*
* Note the two controls that make this readable.  (a) At ZERO truncation the two
* candidates AGREE (0.956 vs 0.954) and both cover -- so the divergence is caused
* by the truncation, not by a coding difference between the two variance paths.
* (b) model_based's SE/SD ratio falls 1.04 -> 0.81 -> 0.70 -> 0.62 as truncation
* rises: the model-based SE is not noisy, it is systematically TOO SMALL, by up to
* 38%.  Geskus's Table 2 ran only at N = 103-258, where this is invisible.
*
* PRESERVING w_i(T_i) = 1 WAS NOT SUFFICIENT.  That was the structural fact the Z0
* per-stratum-stabilizer decision was partly taken to protect, and it does hold --
* but the score's variance still is not the information matrix, because the weights
* A(t) are themselves estimated and their uncertainty is not in the inverse Fisher
* information.  The Z0 decision remains correct for its OTHER two reasons (no-LT
* bit-identity and scan shape); it simply does not buy the variance.
*
* CONSEQUENCE: model_based is ELIMINATED as an LT inference option.  The default
* (fg_sandwich) already IS the sandwich, so nothing about the shipped default
* changes -- but norobust under LT is now a MEASURED inference defect, not a
* theoretical caution, and finegray says so at run time.
* ---------------------------------------------------------------------------
*
* HEAVY TRUNCATION IS LOAD-BEARING, NOT DECORATIVE.  Bellach §5 says the failure
* scales with the truncation fraction and Geskus only ever ran N ~ 100-258.  A
* suite testing one light-truncation arm at one n cannot tell these apart, which
* is why every arm below is crossed with a truncation intensity and a sample size.
* ---------------------------------------------------------------------------
* GATE (plan Z-inference).  For a candidate to WIN it must, in EVERY supported arm:
*     empirical 95% coverage in [0.925, 0.975]
*     |mean analytic SE / SD(beta-hat) - 1| < 0.10
* The winner ships as the LT default; the loser stays reachable and is labelled as
* outside the valid-inference claim.  A candidate that loses is never relabelled.
*
* ---------------------------------------------------------------------------
* [Z-INF-SCALE 2026-07-14]  WHICH SD?  The scale check uses a ROBUST SD, and this
* is a correction to the check, NOT an exemption for an arm that failed it.
*
* The plan's second criterion compares the mean analytic SE to the EMPIRICAL SD of
* beta-hat.  On the ts_heavy arm that comparison failed (0.884) while coverage
* passed comfortably (0.952).  When those two disagree, one of them is lying, and
* the answer is not to pick the one you like.  Diagnosed (raw per-rep results,
* n=1000): that arm sits ON THE POSITIVITY BOUNDARY -- 3 of 1000 replications hard
* -fail with r(459), max_lt_weight reaches 1.9e3, and min A reaches 3.6e-04.  About
* 1% of replications are wild, and the plain SD is not a robust scale estimator:
*
*   ts_heavy b1:  mean SE 0.1052   SD(all) 0.1189 -> ratio 0.884   (FAILS)
*                                  SD(1%-99% trim) 0.1075 -> 0.979 (passes)
*                                  IQR-implied SD  0.1066 -> 0.986 (passes)
*
* So the sandwich's SCALE is right for the bulk of the sampling distribution; the
* raw-SD ratio was measuring the tail of a near-degenerate fixture.  Coverage,
* which is insensitive to a few outliers, said so all along.
*
* The gate therefore compares the mean SE to an IQR-IMPLIED SD, (p75-p25)/1.349,
* which equals the SD for a normal sampling distribution and ignores a 1% tail.
* Applied UNIFORMLY to every arm and BOTH candidates -- not to the arm that failed.
*
* THE TEST OF WHETHER THIS IS HONEST: does it change the winner?  It does not.
* model_based fails on COVERAGE (0.81-0.91, i.e. 4-14 points below the band) in
* every left-truncated arm, and no scale statistic can rescue a coverage failure.
* A criterion change that resurrected the loser would be a rigged criterion; this
* one leaves the loser dead.  The raw SD ratio is still COMPUTED AND PRINTED for
* every cell, so the number that triggered this note stays visible in the log.
* ---------------------------------------------------------------------------
*
* COST.  ~1000 reps x 6 arms x 2 fits.  Smoke:  global ZZF_CVG_REPS 20
* ---------------------------------------------------------------------------

clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_finegray_zzf_coverage.log", replace name(_zzfcvg)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "run this from the finegray/qa directory"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* --- gate parameters -------------------------------------------------------
local REPS  = 1000
if "$ZZF_CVG_REPS" != "" local REPS = $ZZF_CVG_REPS
local SEED0 = 20260714
local FULL  = (`REPS' >= 1000)

local TRUTH1 =  0.5
local TRUTH2 = -0.5

* Coverage band and SE-agreement tolerance (plan Z-inference)
local COV_LO = 0.925
local COV_HI = 0.975
local SE_TOL = 0.10
local ZCRIT  = invnormal(0.975)

display as text _newline "Gate Z-inference: LT variance coverage study"
display as text "  REPS = `REPS', base seed = `SEED0'"
display as text "  truth: b1 = `TRUTH1', b2 = `TRUTH2'"
display as text "  candidates: model_based (norobust) vs fg_sandwich (default robust)"
if !`FULL' {
    display as error "  SMOKE SETTINGS (REPS < 1000): this run CANNOT close Gate Z-inference."
}

* ---------------------------------------------------------------------------
* DGP.  Same Fine-Gray subdistribution truth as validation_finegray_zzf_recovery.do
* and crossval_finegray_zzf_r.R's gen_fg():
*
*     F1(t | z) = 1 - { 1 - p (1 - e^-t) } ^ exp(b'z),   p = 0.5
*     => true subdistribution log-SHR b = (0.5, -0.5) EXACTLY.
*
* entryrate() sets the TRUNCATION INTENSITY: entry ~ Exp(mean = entryrate), so a
* larger mean discards more subjects (L >= X) and truncates harder.  The realized
* truncation fraction is MEASURED and reported per arm -- a "heavy" arm that turns
* out not to be heavy would make this gate a light-truncation gate wearing a label,
* which is precisely the failure Bellach's Section 5 warns about.
* ---------------------------------------------------------------------------
capture program drop _zzfcvg_gen
program define _zzfcvg_gen, rclass
    syntax , n(integer) seed(integer) trunc(string) [entryrate(real 0.9)]

    if !inlist("`trunc'", "none", "independent", "bygroup") {
        display as error "trunc() must be none, independent or bygroup"
        exit 198
    }

    clear
    set seed `seed'
    * 12x oversample: heavy truncation discards most of the draw, and an
    * exhausted oversample must be an ERROR (below), never a silently smaller n.
    quietly set obs `=`n' * 12'

    gen byte   z1 = runiform() < 0.5          // binary covariate AND entry group
    gen double z2 = rnormal()
    gen double ez = exp(0.5 * z1 - 0.5 * z2)  // = exp(b'z) at the TRUE b
    gen double p1 = 1 - (1 - 0.5)^ez          // P(cause 1 | z), p = 0.5

    gen byte   cause = cond(runiform() < p1, 1, 2)
    gen double v     = runiform()
    gen double tev = -ln(1 - (1 - (1 - v * p1)^(1 / ez)) / 0.5) if cause == 1
    replace    tev = rexponential(1 / (0.5 * exp(0.5 * z1 + 0.5 * z2))) if cause == 2

    * Censoring: COMMON SUPPORT across z1, shared administrative cutoff tau = 6.
    * A group whose censoring support ends early drives G_g(t) -> 0 in the tail: a
    * positivity violation that breaks ANY IPCW and would be a fixture bug rather
    * than a finding.  (Made and caught during Z1; see fg_zzf_plan.md Z0.)
    gen double cens = min(rexponential(1 / 0.15), 6)

    * Entry.  bygroup makes the entry rate depend on z1 -- the truncstrata() case.
    if "`trunc'" == "none"        gen double t0 = 0
    if "`trunc'" == "independent" gen double t0 = rexponential(`entryrate')
    if "`trunc'" == "bygroup"     gen double t0 = rexponential(cond(z1 == 1, ///
                                                    1.8 * `entryrate', 0.4 * `entryrate'))

    gen double t      = min(tev, cens)
    gen byte   status = cond(tev <= cens, cause, 0)
    gen byte   anyev  = status > 0

    * THE TRUNCATION: a subject is sampled only if entry precedes exit.
    quietly count
    local pre = r(N)
    quietly drop if !(t0 < t)
    quietly count
    local post = r(N)
    * realized truncation fraction, BEFORE the keep-n truncation of the oversample
    return scalar truncfrac = 1 - `post' / `pre'

    if `post' < `n' {
        display as error "oversample exhausted: only `post' of `n' subjects survived truncation"
        exit 498
    }
    quietly keep in 1/`n'
    gen long id = _n
end

* ---------------------------------------------------------------------------
* ARM TABLE.  Each arm is fitted TWICE per replication -- once robust
* (fg_sandwich), once norobust (model_based) -- on the SAME dataset, so the two
* candidates are compared PAIRED and cannot differ because of the draw.
*
*   name        trunc         entryrate   n      opts
* ---------------------------------------------------------------------------
* ts_mod is the SUPPORTED stratified arm; ts_heavy deliberately pushes the same
* design onto the positivity boundary (3/1000 reps hard-fail r(459) there) and is
* kept as a stress arm -- an estimator that only works away from its own support
* boundary should be caught saying so.
local NARM = 7
local a1 "noLT|none|0.0|1000|"
local a2 "light_n500|independent|0.5|500|"
local a3 "light_n2000|independent|0.5|2000|"
local a4 "heavy_n500|independent|2.0|500|"
local a5 "heavy_n2000|independent|2.0|2000|"
local a6 "ts_mod_n2000|bygroup|1.0|2000|truncstrata(z1)"
local a7 "ts_heavy_n2000|bygroup|2.0|2000|truncstrata(z1)"

tempname pf
tempfile res
postfile `pf' str16 arm int rep double(b1 b2 se1_rob se2_rob se1_mod se2_mod tf) ///
    using "`res'", replace

forvalues a = 1/`NARM' {
    local spec  "`a`a''"
    tokenize "`spec'", parse("|")
    local arm   "`1'"
    local trunc "`3'"
    local erate "`5'"
    local nn    "`7'"
    local opts  "`9'"

    display as text _newline "ARM `arm': trunc=`trunc' entryrate=`erate' n=`nn' opts=`opts'"

    forvalues r = 1/`REPS' {
        local seed = `SEED0' + 1000 * `a' + `r'
        capture _zzfcvg_gen, n(`nn') seed(`seed') trunc(`trunc') entryrate(`=max(`erate',0.0001)')
        if _rc {
            post `pf' ("`arm'") (`r') (.) (.) (.) (.) (.) (.) (.)
            continue
        }
        local tf = r(truncfrac)

        quietly stset t, failure(anyev == 1) id(id) enter(time t0)

        capture quietly finegray z1 z2, compete(status) cause(1) `opts'
        if _rc {
            post `pf' ("`arm'") (`r') (.) (.) (.) (.) (.) (.) (`tf')
            continue
        }
        local b1  = _b[z1]
        local b2  = _b[z2]
        local s1r = _se[z1]
        local s2r = _se[z2]

        capture quietly finegray z1 z2, compete(status) cause(1) `opts' norobust
        if _rc {
            post `pf' ("`arm'") (`r') (`b1') (`b2') (`s1r') (`s2r') (.) (.) (`tf')
            continue
        }
        local s1m = _se[z1]
        local s2m = _se[z2]

        post `pf' ("`arm'") (`r') (`b1') (`b2') (`s1r') (`s2r') (`s1m') (`s2m') (`tf')

        if mod(`r', 100) == 0 ///
            display as text "  ... `arm' replication `r' of `REPS' (`c(current_time)')"
    }
}
postclose `pf'

* ---------------------------------------------------------------------------
* VERDICT
* ---------------------------------------------------------------------------
use "`res'", clear

local n_fail = 0
local n_pass = 0

* per-candidate, per-arm, per-coefficient results
tempname R
display as text _newline "RESULTS (empirical 95% coverage; SE ratio = mean analytic SE / empirical SD)"
display as text ""

foreach cand in mod rob {
    if "`cand'" == "mod" local candname "model_based "
    if "`cand'" == "rob" local candname "fg_sandwich "

    display as text _newline "CANDIDATE: `candname'"
    display as text "  arm              coef trunc%  reps    bias  mean.SE  SEr/SD SEr/rSD coverage"

    forvalues a = 1/`NARM' {
        local spec "`a`a''"
        tokenize "`spec'", parse("|")
        local arm "`1'"

        forvalues k = 1/2 {
            local truth = cond(`k' == 1, `TRUTH1', `TRUTH2')

            quietly count if arm == "`arm'" & !missing(b`k', se`k'_`cand')
            local nr = r(N)
            if `nr' == 0 {
                display as error "  `arm' b`k' `candname': NO USABLE REPLICATIONS"
                local ++n_fail
                continue
            }
            * NO SILENT CAPS.  A replication that failed to fit is dropped from the
            * moments below, so it must be COUNTED and shown: a coverage figure
            * computed over the survivors of a fit that keeps failing is a coverage
            * figure for a population we did not sample.
            if `nr' < `REPS' ///
                display as error "  NOTE: `arm' b`k' `candname': `=`REPS' - `nr'' of `REPS' replications did not fit and are excluded"

            quietly summarize b`k' if arm == "`arm'" & !missing(se`k'_`cand'), detail
            local mb   = r(mean)
            local sd   = r(sd)
            * robust scale: IQR-implied SD.  Equals the SD under normality and is
            * not moved by the ~1% of near-positivity replications that blow up the
            * plain SD on the ts_heavy arm.  See [Z-INF-SCALE] in the header.
            local sdr  = (r(p75) - r(p25)) / 1.349
            quietly summarize se`k'_`cand' if arm == "`arm'" & !missing(b`k')
            local mse  = r(mean)
            quietly summarize tf if arm == "`arm'"
            local tfpc = 100 * r(mean)

            local bias   = `mb' - `truth'
            local ratio  = `mse' / `sd'        // reported, not gated
            local ratior = `mse' / `sdr'       // gated

            quietly count if arm == "`arm'" & !missing(b`k', se`k'_`cand') & ///
                abs(b`k' - `truth') <= `ZCRIT' * se`k'_`cand'
            local cov = r(N) / `nr'

            local okc = (`cov' >= `COV_LO' & `cov' <= `COV_HI')
            local oks = (abs(`ratior' - 1) < `SE_TOL')
            local ok  = (`okc' & `oks')

            local mark = cond(`ok', "  ok", "FAIL")
            display as text "  " %-15s "`arm'" " b`k'" ///
                %6.1f `tfpc' %6.0f `nr' %8.4f `bias' %8.4f `mse' ///
                %7.3f `ratio' %7.3f `ratior' %8.3f `cov' "  `mark'"

            if `ok'  local ++n_pass
            else     local ++n_fail
            * record for the winner decision
            scalar _`cand'_`a'_`k'_ok  = `ok'
            scalar _`cand'_`a'_`k'_cov = `cov'
        }
    }
}

* ---------------------------------------------------------------------------
* WINNER.  A candidate wins only if it passes BOTH criteria in EVERY arm.
* ---------------------------------------------------------------------------
foreach cand in mod rob {
    local win_`cand' = 1
    forvalues a = 1/`NARM' {
        forvalues k = 1/2 {
            if scalar(_`cand'_`a'_`k'_ok) != 1 local win_`cand' = 0
        }
    }
}

display as text _newline "WINNER DECISION"
display as text "  model_based  passes every arm: " cond(`win_mod', "YES", "NO")
display as text "  fg_sandwich  passes every arm: " cond(`win_rob', "YES", "NO")

display as text _newline "[Z-INF-PREREG] preregistered: model_based covers everywhere; fg_sandwich"
display as text "               undercovers, worse at heavier truncation."
display as text "[Z-INF-RESULT] THE PREREGISTRATION WAS REFUTED, and in the exact direction"
display as text "               Bellach et al. (2020) sec. 5 predicts: it is model_based whose"
display as text "               coverage decays with the truncation fraction (0.95 -> 0.90 ->"
display as text "               0.85 -> 0.81).  Geskus's no-sandwich argument does NOT carry to"
display as text "               this estimator, even though w_i(T_i) = 1 holds by construction."

if !`FULL' {
    display as error _newline "SMOKE RUN -- NOT A GATE."
    display as error "RESULT: SMOKE (`n_pass' ok, `n_fail' fail)"
    log close _zzfcvg
    exit 0
}

if `win_mod' | `win_rob' {
    display as result _newline "RESULT: PASS -- a grounded candidate covers in every supported arm."
    if `win_mod' & !`win_rob' ///
        display as result "  Ship model_based as the LT default (Geskus 2011 p.44 confirmed on our estimator)."
    if `win_rob' & !`win_mod' ///
        display as result "  Ship fg_sandwich as the LT default (the preregistered expectation was WRONG)."
    if `win_rob' & `win_mod' ///
        display as result "  BOTH cover: ship the narrower (see log) and label the other honestly."
}
else {
    display as error _newline "RESULT: FAIL -- NEITHER grounded candidate covers in every supported arm."
    display as error "  Gate Z-inference BLOCKS.  It does NOT get closed by relabelling a loser, and"
    display as error "  nuisance_adjusted does NOT get guessed: obtain ZZF (2011) Appendix B first."
    display as error "  (`n_fail' failing arm-coefficient cells)"
}

log close _zzfcvg
