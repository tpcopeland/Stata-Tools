#' Cohort Dataset for tvtools Examples
#'
#' A synthetic cohort of 1,000 multiple sclerosis (MS) patients with study entry
#' and exit dates, along with baseline demographic and clinical characteristics.
#' This dataset serves as the master cohort for use with \code{\link{tvexpose}}
#' and \code{\link{tvmerge}} to create time-varying exposure variables.
#'
#' @format A data frame with 1,000 rows and 8 columns:
#' \describe{
#'   \item{id}{Person identifier (1-1000). Unique identifier for each study participant.}
#'   \item{study_entry}{Date of entry into the cohort. Class Date. Specifies when each
#'     person's follow-up begins.}
#'   \item{study_exit}{Date of exit from the cohort. Class Date. Specifies when each
#'     person's follow-up ends (e.g., end of study, loss to follow-up, or occurrence
#'     of outcome event).}
#'   \item{age}{Age at baseline in years. Integer. Ranges from 25 to 85 years.}
#'   \item{female}{Indicator of female sex. Binary (0 = male, 1 = female).}
#'   \item{mstype}{Type of multiple sclerosis. Integer (1 = RRMS, 2 = SPMS, 3 = PPMS).
#'     RRMS = Relapsing-remitting MS, SPMS = Secondary progressive MS,
#'     PPMS = Primary progressive MS.}
#'   \item{edss_baseline}{Baseline Expanded Disability Status Scale (EDSS) score.
#'     Numeric, ranges from 0 to 8.5. EDSS measures disability severity in MS
#'     (0 = normal neurologic exam, 10 = death due to MS).}
#'   \item{region}{Geographic region. Character. One of "North", "Central",
#'     "South", "East", or "West".}
#' }
#'
#' @details
#' This dataset is synthetic and generated for demonstration purposes. The follow-up
#' period spans from 2010-01-02 to 2020-12-31. Each participant has at least one year
#' of follow-up.
#'
#' The cohort is designed to work with the \code{\link{hrt_exposure}} and
#' \code{\link{dmt_exposure}} datasets, which contain exposure information that can
#' be merged with this cohort using \code{\link{tvexpose}}.
#'
#' @source Synthetically generated for package examples.
#'
#' @examples
#' data(cohort)
#' head(cohort)
#' summary(cohort)
#' table(cohort$female)
#' table(cohort$mstype)
"cohort"


#' HRT Exposure Dataset for tvtools Examples
#'
#' A synthetic dataset containing hormone replacement therapy (HRT) exposure periods
#' for the \code{\link{cohort}} dataset. Each row represents a continuous period of
#' HRT use for a study participant. Exposure periods can overlap and users can choose
#' how to handle overlaps using options in \code{\link{tvexpose}}.
#'
#' @format A data frame with 791 rows and 5 columns:
#' \describe{
#'   \item{id}{Person identifier linking to the cohort. Integer (1-1000).}
#'   \item{rx_start}{Start date of HRT exposure period. Class Date. The date when
#'     HRT use began.}
#'   \item{rx_stop}{Stop date of HRT exposure period. Class Date. The date when
#'     HRT use ended.}
#'   \item{hrt_type}{Type of hormone replacement therapy. Integer (1, 2, or 3).
#'     1 = Estrogen only, 2 = Estrogen + Progestin, 3 = Other formulations.}
#'   \item{dose}{Dose of HRT in mg/day. Numeric. Ranges from 0.3 to 1.5 mg/day.}
#' }
#'
#' @details
#' Approximately 39% of cohort members have at least one HRT exposure period. Among
#' those exposed, the number of periods ranges from 1 to 3 per person. Period duration
#' ranges from 30 to 730 days.
#'
#' This dataset is used with \code{\link{tvexpose}} to create time-varying HRT
#' exposure variables. The typical workflow is:
#' \enumerate{
#'   \item Load the cohort dataset
#'   \item Use \code{\link{tvexpose}} with the hrt_exposure dataset as the "using" file
#'   \item Optionally merge with other exposures using \code{\link{tvmerge}}
#' }
#'
#' @source Synthetically generated for package examples.
#'
#' @examples
#' data(hrt_exposure)
#' head(hrt_exposure)
#' table(hrt_exposure$hrt_type)
#' summary(hrt_exposure$dose)
#' # Count exposed persons
#' length(unique(hrt_exposure$id))
"hrt_exposure"


#' DMT Exposure Dataset for tvtools Examples
#'
#' A synthetic dataset containing disease-modifying therapy (DMT) exposure periods
#' for the \code{\link{cohort}} dataset. Each row represents a continuous period of
#' use of a specific DMT for a study participant. Participants may switch between
#' different DMT types, resulting in multiple periods per person.
#'
#' @format A data frame with 1,905 rows and 4 columns:
#' \describe{
#'   \item{id}{Person identifier linking to the cohort. Integer (1-1000).}
#'   \item{dmt_start}{Start date of DMT exposure period. Class Date. The date when
#'     DMT use began.}
#'   \item{dmt_stop}{Stop date of DMT exposure period. Class Date. The date when
#'     DMT use ended.}
#'   \item{dmt}{Type of disease-modifying therapy. Integer (1-6). Codes represent
#'     different DMT classes:
#'     1 = Interferon beta,
#'     2 = Glatiramer acetate,
#'     3 = Natalizumab,
#'     4 = Fingolimod,
#'     5 = Dimethyl fumarate,
#'     6 = Ocrelizumab.}
#' }
#'
#' @details
#' Approximately 76% of cohort members have at least one DMT exposure period, reflecting
#' the high prevalence of DMT use in MS populations. Among those exposed, the number of
#' periods (treatment episodes) ranges from 1 to 4 per person, with periods ranging from
#' 30 to 1,095 days in duration. Multiple periods per person reflect treatment switching,
#' which is common in MS management.
#'
#' This dataset is used with \code{\link{tvexpose}} to create time-varying DMT
#' exposure variables. It can also be merged with other exposures (e.g., HRT) using
#' \code{\link{tvmerge}} to analyze combined or competing exposures.
#'
#' The typical analysis workflow is:
#' \enumerate{
#'   \item Load the cohort dataset
#'   \item Use \code{\link{tvexpose}} with dmt_exposure to create time-varying DMT
#'   \item (Optional) Merge with other exposures using \code{\link{tvmerge}}
#'   \item Use \code{stset} and standard survival analysis commands
#' }
#'
#' @source Synthetically generated for package examples.
#'
#' @examples
#' data(dmt_exposure)
#' head(dmt_exposure)
#' table(dmt_exposure$dmt)
#' # Count exposed persons
#' length(unique(dmt_exposure$id))
#' # Distribution of number of periods per person
#' table(table(dmt_exposure$id))
"dmt_exposure"
