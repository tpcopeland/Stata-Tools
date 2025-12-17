#' @keywords internal
"_PACKAGE"

#' tvtools: Time-Varying Exposure and Event Analysis Tools
#'
#' @description
#' The tvtools package provides comprehensive tools for managing time-varying
#' exposures in longitudinal and survival analysis. It implements three main
#' functions that work together in a typical survival analysis workflow:
#'
#' \itemize{
#'   \item \code{\link{tvexpose}}: Create time-varying exposure variables from
#'     period-based exposure data
#'   \item \code{\link{tvmerge}}: Merge multiple time-varying datasets using
#'     Cartesian product of overlapping time periods
#'   \item \code{\link{tvevent}}: Integrate outcome events and competing risks
#'     into time-varying datasets
#' }
#'
#' @section Typical Workflow:
#' \preformatted{
#' Raw exposure data
#'         ↓
#'     tvexpose()  ←──────────── Create time-varying exposure variables
#'         ↓
#'    [tvmerge()]  ←──────────── Merge multiple exposures (optional)
#'         ↓
#'     tvevent()   ←──────────── Integrate events and competing risks
#'         ↓
#'   Surv() + coxph() ←────────── Survival analysis
#' }
#'
#' @section Key Features:
#' \itemize{
#'   \item Comprehensive exposure definitions (basic, ever-treated,
#'     current/former, duration, continuous, recency)
#'   \item Advanced data handling (grace periods, gap filling, overlap
#'     resolution, lag/washout)
#'   \item Flexible merging with temporal alignment
#'   \item Competing risks support
#'   \item Validation and diagnostic tools
#'   \item Performance optimized for large datasets
#' }
#'
#' @section Original Implementation:
#' This R package is a reimplementation of the Stata tvtools package by
#' Timothy P. Copeland. The original Stata commands maintain API compatibility
#' where possible while leveraging R's data manipulation capabilities.
#'
#' @author
#' Timothy P. Copeland \email{timothy.copeland@@ki.se}
#'
#' Department of Clinical Neuroscience
#'
#' Karolinska Institutet, Stockholm, Sweden
#'
#' @seealso
#' \itemize{
#'   \item Original Stata package: \url{https://github.com/tpcopeland/Stata-Tools/tree/main/tvtools}
#'   \item GitHub repository: \url{https://github.com/tpcopeland/Stata-Tools}
#' }
#'
#' @docType package
#' @name tvtools-package
NULL
