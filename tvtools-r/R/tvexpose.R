#' Create time-varying exposure variables for survival analysis
#'
#' @title Create Time-Varying Exposure Variables
#'
#' @description
#' Creates time-varying exposure variables suitable for survival analysis
#' from a dataset containing exposure periods. The function merges exposure data with a
#' master cohort dataset, creating periods of time where exposure status changes.
#'
#' The typical workflow involves:
#' \enumerate{
#'   \item A master dataset containing person-level data with study entry and exit dates
#'   \item An exposure dataset containing periods when exposures occurred
#'   \item \code{tvexpose} merges these datasets and creates time-varying periods
#' }
#'
#' The output is a long-format data frame with one row per person-time period, where the
#' exposure variable indicates exposure status during that period. This format is
#' compatible with survival analysis functions like \code{coxph} and \code{survfit}.
#'
#' @param master A data frame containing the master cohort dataset with person-level data
#'   including study entry and exit dates.
#' @param exposure_data A data frame containing exposure periods. Must contain the variables
#'   specified in \code{id}, \code{start}, \code{exposure}, and (unless \code{pointtime = TRUE})
#'   \code{stop}.
#' @param id Character string specifying the person identifier variable name that links the
#'   exposure dataset to the master dataset. Must be present in both datasets.
#' @param start Character string specifying the variable name in the exposure dataset containing
#'   the start date of each exposure period.
#' @param stop Character string specifying the variable name in the exposure dataset containing
#'   the end date of each exposure period. Required unless \code{pointtime = TRUE}.
#' @param exposure Character string specifying the categorical exposure status variable name
#'   in the exposure dataset. This identifies what type of exposure occurred in each period.
#' @param reference Numeric value in the exposure variable that represents the unexposed or
#'   reference state. Typically 0.
#' @param entry Character string specifying the variable name in the master dataset containing
#'   each person's study entry date. Exposure periods are only counted from this date forward.
#' @param exit Character string specifying the variable name in the master dataset containing
#'   each person's study exit date (e.g., end of follow-up, death, outcome occurrence).
#'   Exposure periods are truncated at this date.
#' @param pointtime Logical indicating that exposure data represent point-in-time events rather
#'   than periods with duration. When \code{TRUE}, \code{stop} is not required. Default: \code{FALSE}.
#' @param evertreated Logical. Creates a binary time-varying exposure that switches from 0 to 1
#'   at the first exposure and remains 1 for all subsequent follow-up. Used for immortal time
#'   bias correction in ever-treated analyses. Default: \code{FALSE}.
#' @param currentformer Logical. Creates a trichotomous time-varying exposure with values:
#'   0 = never exposed, 1 = currently exposed, 2 = formerly exposed. Returns to 1 if re-exposed
#'   after a gap. Default: \code{FALSE}.
#' @param duration Numeric vector specifying category boundaries for cumulative duration-based
#'   exposure categories. The unit is determined by \code{continuousunit} (defaults to years).
#'   For example, \code{c(1, 5)} creates categories: 0=unexposed, 1=<1 year, 2=1 to <5 years, 3=≥5 years.
#'   Default: \code{NULL}.
#' @param continuousunit Character string specifying the unit for cumulative exposure tracking.
#'   Options: "days", "weeks", "months", "quarters", or "years". Creates a continuous time-varying
#'   variable tracking cumulative exposure in the specified unit. Default: \code{NULL}.
#' @param expandunit Character string specifying the granularity for splitting person-time into
#'   rows at regular calendar intervals. Options: "days", "weeks", "months", "quarters", or "years".
#'   Used with \code{continuousunit} to create finely-grained time-varying data. Default: \code{NULL}.
#' @param bytype Logical. Creates separate time-varying variables for each exposure type instead
#'   of a single variable. Useful when different exposure types have independent effects.
#'   Default: \code{FALSE}.
#' @param recency Numeric vector specifying category boundaries based on time since last exposure
#'   (in years). For example, \code{c(1, 5)} creates: current exposure, <1 year since last,
#'   1 to <5 years since last, ≥5 years since last. Default: \code{NULL}.
#' @param grace Numeric value or named numeric vector specifying grace period(s) in days for merging
#'   small gaps between exposure periods. If a single number, applies to all exposure types.
#'   If a named vector (e.g., \code{c("1" = 30, "2" = 60)}), applies different grace periods
#'   to different exposure categories. Default: 0.
#' @param merge_periods Numeric value specifying days within which to merge consecutive periods
#'   of the same exposure type. Default: 120.
#' @param fillgaps Numeric value indicating exposure continues for this many days beyond the
#'   last recorded stop date. Useful when exposure records may be incomplete or delayed.
#'   Default: \code{NULL}.
#' @param carryforward Numeric value specifying days to carry the most recent exposure forward
#'   through gaps. Used when exposure is likely to persist beyond recorded periods.
#'   Default: \code{NULL}.
#' @param layer Logical. When \code{TRUE}, handles overlapping exposures by giving precedence to
#'   later exposures, with earlier exposures resuming after the later one ends. This is the
#'   default behavior. Default: \code{TRUE}.
#' @param priority Numeric vector specifying priority order when exposures overlap. Lists exposure
#'   values in priority order (highest first). For example, \code{c(2, 1, 0)} gives type 2
#'   highest priority. Default: \code{NULL}.
#' @param split Logical. Splits overlapping periods at all exposure boundaries, creating separate
#'   rows for each combination. Used when overlapping exposures have independent effects.
#'   Default: \code{FALSE}.
#' @param combine Character string. Creates an additional variable with this name containing a
#'   combined exposure indicator when periods overlap. The new variable shows simultaneous
#'   exposure to multiple types. Default: \code{NULL}.
#' @param lag Numeric value specifying a lag period in days before exposure becomes active.
#'   Exposure status changes this many days after the start date rather than immediately.
#'   Used to model delayed biological effects. Default: 0.
#' @param washout Numeric value specifying that exposure effects persist for this many days after
#'   the stop date. Exposure status remains active until this many days past the recorded end.
#'   Used to model residual effects. Default: 0.
#' @param window Numeric vector of length 2 specifying minimum and maximum days for an acute
#'   exposure window. Only exposure periods lasting between the specified minimum and maximum
#'   are counted. Used for analyzing acute effects of brief exposures. Default: \code{NULL}.
#' @param switching Logical. Creates a binary indicator variable that equals 1 once a person has
#'   ever switched between exposure types, 0 otherwise. Default: \code{FALSE}.
#' @param switchingdetail Logical. Creates a character variable containing the complete sequence
#'   of exposure changes. For example, "0->1->2" indicates starting unexposed, then type 1,
#'   then type 2. Default: \code{FALSE}.
#' @param statetime Logical. Creates a continuous variable tracking cumulative time (in days)
#'   spent in the current exposure state. Resets to 0 when exposure changes. Default: \code{FALSE}.
#' @param generate Character string specifying the name for the output time-varying exposure
#'   variable. Default: "tv_exposure".
#' @param referencelabel Character string specifying the label for the reference category in
#'   the output variable. Default: "Unexposed".
#' @param label Character string specifying a custom variable label for the output exposure
#'   variable. Default: \code{NULL}.
#' @param keepvars Character vector specifying additional variable names from the master dataset
#'   to keep in the output. Baseline covariates like age, sex, etc. Default: \code{NULL}.
#' @param keepdates Logical. Retains the study entry and exit date variables in the output
#'   dataset. By default these are dropped to save space. Default: \code{FALSE}.
#' @param check Logical. Display diagnostic information about exposure coverage for each person,
#'   including number of periods, total exposed time, and gaps. Default: \code{FALSE}.
#' @param gaps Logical. Identifies and lists persons with gaps in exposure coverage, showing
#'   the location and duration of gaps. Default: \code{FALSE}.
#' @param overlaps Logical. Identifies and lists overlapping exposure periods, showing where
#'   multiple exposures occur simultaneously. Default: \code{FALSE}.
#' @param summarize Logical. Display summary statistics for the time-varying exposure
#'   distribution, including frequencies of each category and person-time totals.
#'   Default: \code{FALSE}.
#' @param validate Logical. Creates a separate validation data frame containing coverage metrics
#'   for each person, useful for quality control. Default: \code{FALSE}.
#'
#' @return A data frame in long format with one row per person-time period. The output includes:
#'   \itemize{
#'     \item The person identifier variable
#'     \item Start and stop dates for each period
#'     \item The time-varying exposure variable(s)
#'     \item Any additional variables specified in \code{keepvars}
#'     \item Optional diagnostic variables if \code{switching}, \code{switchingdetail}, or
#'           \code{statetime} are \code{TRUE}
#'   }
#'
#'   When \code{validate = TRUE}, also returns a list with components:
#'   \itemize{
#'     \item \code{data}: The main time-varying exposure data frame
#'     \item \code{validation}: A data frame with coverage metrics for each person
#'     \item \code{N_persons}: Number of unique persons
#'     \item \code{N_periods}: Number of time-varying periods
#'     \item \code{total_time}: Total person-time in days
#'     \item \code{exposed_time}: Exposed person-time in days
#'     \item \code{unexposed_time}: Unexposed person-time in days
#'     \item \code{pct_exposed}: Percentage of time exposed
#'   }
#'
#' @examples
#' \dontrun{
#' # Example 1: Basic time-varying exposure
#' # Create categorical time-varying HRT exposure for survival analysis
#' library(dplyr)
#'
#' # Load cohort and exposure data
#' cohort <- read.csv("cohort.csv")
#' hrt <- read.csv("hrt.csv")
#'
#' result <- tvexpose(
#'   master = cohort,
#'   exposure_data = hrt,
#'   id = "id",
#'   start = "rx_start",
#'   stop = "rx_stop",
#'   exposure = "hrt_type",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit"
#' )
#'
#' # Example 2: Ever-treated analysis
#' # Create binary indicator that switches permanently at first HRT exposure
#' result <- tvexpose(
#'   master = cohort,
#'   exposure_data = hrt,
#'   id = "id",
#'   start = "rx_start",
#'   stop = "rx_stop",
#'   exposure = "hrt_type",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   evertreated = TRUE,
#'   generate = "ever_hrt"
#' )
#'
#' # Example 3: Current vs former exposure
#' # Distinguish between current and former DMT exposure
#' dmt <- read.csv("dmt.csv")
#'
#' result <- tvexpose(
#'   master = cohort,
#'   exposure_data = dmt,
#'   id = "id",
#'   start = "dmt_start",
#'   stop = "dmt_stop",
#'   exposure = "dmt",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   currentformer = TRUE,
#'   generate = "dmt_status"
#' )
#'
#' # Example 4: Duration categories
#' # Create exposure categories based on cumulative years of HRT use
#' result <- tvexpose(
#'   master = cohort,
#'   exposure_data = hrt,
#'   id = "id",
#'   start = "rx_start",
#'   stop = "rx_stop",
#'   exposure = "hrt_type",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   duration = c(1, 5, 10),
#'   continuousunit = "years"
#' )
#'
#' # Example 5: Continuous cumulative exposure
#' # Track cumulative months of DMT exposure as a continuous variable
#' result <- tvexpose(
#'   master = cohort,
#'   exposure_data = dmt,
#'   id = "id",
#'   start = "dmt_start",
#'   stop = "dmt_stop",
#'   exposure = "dmt",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   continuousunit = "months",
#'   generate = "cumul_dmt_months"
#' )
#'
#' # Example 6: Grace period for gaps
#' # Treat gaps ≤30 days as continuous HRT exposure
#' result <- tvexpose(
#'   master = cohort,
#'   exposure_data = hrt,
#'   id = "id",
#'   start = "rx_start",
#'   stop = "rx_stop",
#'   exposure = "hrt_type",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   grace = 30,
#'   currentformer = TRUE
#' )
#'
#' # Example 7: Keep baseline covariates
#' # Bring demographic and clinical variables into the time-varying dataset
#' result <- tvexpose(
#'   master = cohort,
#'   exposure_data = dmt,
#'   id = "id",
#'   start = "dmt_start",
#'   stop = "dmt_stop",
#'   exposure = "dmt",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   keepvars = c("age", "female", "mstype", "edss_baseline", "region")
#' )
#'
#' # Example 8: Complete workflow for survival analysis
#' # Full analysis pipeline from time-varying exposure to Cox regression
#' library(survival)
#'
#' result <- tvexpose(
#'   master = cohort,
#'   exposure_data = dmt,
#'   id = "id",
#'   start = "dmt_start",
#'   stop = "dmt_stop",
#'   exposure = "dmt",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   currentformer = TRUE,
#'   generate = "dmt_status",
#'   keepvars = c("age", "female", "mstype", "edss_baseline")
#' )
#'
#' # Define failure event and run Cox regression
#' result <- result %>%
#'   mutate(
#'     failure = !is.na(edss4_dt) & edss4_dt <= rx_stop,
#'     time_years = as.numeric(difftime(rx_stop, rx_start, units = "days")) / 365.25
#'   )
#'
#' cox_model <- coxph(
#'   Surv(time_years, failure) ~ factor(dmt_status) + age + factor(female) +
#'     factor(mstype) + edss_baseline,
#'   data = result,
#'   id = id
#' )
#'
#' summary(cox_model)
#' }
#'
#' @export
#' @importFrom dplyr mutate filter select arrange group_by ungroup summarize left_join
#' @importFrom dplyr bind_rows distinct pull
#' @importFrom lubridate as_date days weeks months years
#' @importFrom tidyr pivot_longer
tvexpose <- function(master,
                     exposure_data,
                     id,
                     start,
                     stop = NULL,
                     exposure,
                     reference,
                     entry,
                     exit,
                     pointtime = FALSE,
                     evertreated = FALSE,
                     currentformer = FALSE,
                     duration = NULL,
                     continuousunit = NULL,
                     expandunit = NULL,
                     bytype = FALSE,
                     recency = NULL,
                     grace = 0,
                     merge_periods = 120,
                     fillgaps = NULL,
                     carryforward = NULL,
                     layer = TRUE,
                     priority = NULL,
                     split = FALSE,
                     combine = NULL,
                     lag = 0,
                     washout = 0,
                     window = NULL,
                     switching = FALSE,
                     switchingdetail = FALSE,
                     statetime = FALSE,
                     generate = "tv_exposure",
                     referencelabel = "Unexposed",
                     label = NULL,
                     keepvars = NULL,
                     keepdates = FALSE,
                     check = FALSE,
                     gaps = FALSE,
                     overlaps = FALSE,
                     summarize = FALSE,
                     validate = FALSE) {

  # Load required packages
  require(dplyr)
  require(lubridate)
  require(zoo)  # For na.locf (carry forward)

  # ============================================================================
  # PARAMETER VALIDATION
  # ============================================================================

  # Determine exposure type from parameters
  exposure_type <- "timevarying"  # Default
  if (evertreated) exposure_type <- "evertreated"
  if (currentformer) exposure_type <- "currentformer"
  if (!is.null(duration)) exposure_type <- "duration"
  if (!is.null(continuousunit) && is.null(duration)) exposure_type <- "continuous"
  if (!is.null(recency)) exposure_type <- "recency"

  # Set default continuous unit for duration if not specified
  if (exposure_type == "duration" && is.null(continuousunit)) {
    continuousunit <- "years"
  }

  # Validate continuous_unit
  valid_units <- c("days", "weeks", "months", "quarters", "years")
  if (!is.null(continuousunit) && !continuousunit %in% valid_units) {
    stop("continuousunit must be one of: ", paste(valid_units, collapse = ", "))
  }

  # Check that stop is provided unless pointtime is TRUE
  if (is.null(stop) && !pointtime) {
    stop("stop variable required unless pointtime = TRUE")
  }

  # ============================================================================
  # DATA PREPARATION
  # ============================================================================

  message("Preparing data...")

  # Extract master data with entry/exit dates and keepvars
  master_cols <- c(id, entry, exit)
  if (!is.null(keepvars)) {
    master_cols <- c(master_cols, keepvars)
  }

  master_dates <- master %>%
    select(all_of(master_cols)) %>%
    rename(
      id = !!sym(id),
      study_entry = !!sym(entry),
      study_exit = !!sym(exit)
    ) %>%
    mutate(
      study_entry = floor(as.numeric(study_entry)),
      study_exit = ceiling(as.numeric(study_exit))
    )

  # Validate that entry < exit
  invalid_dates <- master_dates %>%
    filter(study_exit < study_entry)

  if (nrow(invalid_dates) > 0) {
    stop(sprintf("%d persons have study_exit < study_entry", nrow(invalid_dates)))
  }

  # Prepare exposure data
  exp_cols <- c(id, start, exposure)
  if (!is.null(stop)) {
    exp_cols <- c(exp_cols, stop)
  }

  exp_data <- exposure_data %>%
    select(all_of(exp_cols)) %>%
    rename(
      id = !!sym(id),
      exp_start = !!sym(start),
      exp_value = !!sym(exposure)
    )

  # Handle stop date
  if (!is.null(stop)) {
    exp_data <- exp_data %>%
      rename(exp_stop = !!sym(stop)) %>%
      mutate(
        exp_start = floor(as.numeric(exp_start)),
        exp_stop = ceiling(as.numeric(exp_stop))
      )
  } else {
    # Point-in-time data
    exp_data <- exp_data %>%
      mutate(
        exp_start = floor(as.numeric(exp_start)),
        exp_stop = exp_start
      )

    # Apply carryforward for point-in-time data
    if (!is.null(carryforward) && carryforward > 0) {
      exp_data <- exp_data %>%
        mutate(exp_stop = exp_start + carryforward - 1)
    }
  }

  # Merge exposure data with master dates
  exp_data <- exp_data %>%
    inner_join(master_dates, by = "id")

  # Remove invalid periods (start > stop)
  invalid_periods <- exp_data %>%
    filter(exp_start > exp_stop)

  if (nrow(invalid_periods) > 0) {
    message(sprintf("Warning: Dropping %d periods with start > stop", nrow(invalid_periods)))
    exp_data <- exp_data %>%
      filter(exp_start <= exp_stop)
  }

  # Remove exposures completely outside study window
  exp_data <- exp_data %>%
    filter(exp_stop >= study_entry,
           exp_start <= study_exit)

  # Apply fillgaps option
  if (!is.null(fillgaps) && fillgaps > 0) {
    exp_data <- exp_data %>%
      group_by(id) %>%
      arrange(exp_start) %>%
      mutate(is_last = row_number() == n()) %>%
      mutate(exp_stop = ifelse(is_last, exp_stop + fillgaps, exp_stop)) %>%
      select(-is_last) %>%
      ungroup()
  }

  # Apply lag period
  if (lag > 0) {
    exp_data <- exp_data %>%
      mutate(exp_start = exp_start + lag) %>%
      filter(exp_start <= exp_stop,
             exp_start <= study_exit)
  }

  # Apply washout period
  if (washout > 0) {
    exp_data <- exp_data %>%
      mutate(exp_stop = pmin(exp_stop + washout, study_exit))
  }

  # Truncate all periods to study window
  exp_data <- exp_data %>%
    mutate(
      exp_start = pmax(exp_start, study_entry),
      exp_stop = pmin(exp_stop, study_exit)
    )

  # Save original exposure categories for later use
  exp_data <- exp_data %>%
    mutate(orig_exp_category = exp_value)

  # ============================================================================
  # MERGE CLOSE PERIODS OF SAME EXPOSURE TYPE
  # ============================================================================

  message("Merging close periods...")

  # Iteratively merge periods of same type within merge_periods days
  converged <- FALSE
  iter <- 0
  max_iter <- 100

  while (!converged && iter < max_iter) {
    iter <- iter + 1

    # Sort and identify mergeable periods
    exp_data <- exp_data %>%
      arrange(id, exp_start, exp_stop, exp_value)

    # Identify periods that can be merged
    exp_data <- exp_data %>%
      group_by(id) %>%
      mutate(
        next_start = lead(exp_start),
        next_value = lead(exp_value),
        gap_to_next = next_start - exp_stop,
        can_merge = !is.na(gap_to_next) &
                    gap_to_next <= merge_periods &
                    exp_value == next_value
      ) %>%
      ungroup()

    # If no periods to merge, we're done
    if (sum(exp_data$can_merge, na.rm = TRUE) == 0) {
      converged <- TRUE
    } else {
      # Extend current period to cover next period
      exp_data <- exp_data %>%
        group_by(id) %>%
        mutate(
          exp_stop = ifelse(can_merge & !is.na(lead(exp_stop)),
                           pmax(exp_stop, lead(exp_stop)),
                           exp_stop)
        ) %>%
        ungroup()

      # Mark next period for deletion if completely subsumed
      exp_data <- exp_data %>%
        group_by(id) %>%
        mutate(
          prev_merged = lag(can_merge, default = FALSE),
          prev_start = lag(exp_start),
          prev_stop = lag(exp_stop),
          drop_flag = prev_merged &
                     exp_start >= prev_start &
                     exp_stop <= prev_stop
        ) %>%
        ungroup() %>%
        filter(!drop_flag) %>%
        select(-next_start, -next_value, -gap_to_next, -can_merge,
               -prev_merged, -prev_start, -prev_stop, -drop_flag)
    }
  }

  # Remove exact duplicates
  exp_data <- exp_data %>%
    distinct(id, exp_start, exp_stop, exp_value, .keep_all = TRUE)

  # ============================================================================
  # HANDLE OVERLAPPING EXPOSURES (LAYER METHOD)
  # ============================================================================

  message("Handling overlapping exposures...")

  # Simple layer approach: later exposures truncate earlier ones
  converged <- FALSE
  iter <- 0

  while (!converged && iter < 10) {
    iter <- iter + 1

    exp_data <- exp_data %>%
      arrange(id, exp_start, exp_stop, exp_value) %>%
      group_by(id) %>%
      mutate(
        next_start = lead(exp_start),
        next_value = lead(exp_value),
        # Truncate if next period starts before current ends with different value
        exp_stop = ifelse(!is.na(next_start) &
                         next_start <= exp_stop &
                         exp_value != next_value,
                         next_start - 1,
                         exp_stop)
      ) %>%
      ungroup() %>%
      select(-next_start, -next_value) %>%
      filter(exp_start <= exp_stop)

    # Check for remaining overlaps
    exp_data <- exp_data %>%
      arrange(id, exp_start, exp_stop, exp_value) %>%
      group_by(id) %>%
      mutate(
        still_overlap = lead(exp_start) <= exp_stop &
                       exp_value != lead(exp_value)
      ) %>%
      ungroup()

    if (sum(exp_data$still_overlap, na.rm = TRUE) == 0) {
      converged <- TRUE
    }

    exp_data <- exp_data %>%
      select(-still_overlap)
  }

  # ============================================================================
  # CREATE GAP, BASELINE, AND POST-EXPOSURE PERIODS
  # ============================================================================

  message("Creating unexposed periods...")

  # Apply grace period by extending periods to bridge small gaps
  if (grace > 0) {
    exp_data <- exp_data %>%
      arrange(id, exp_start) %>%
      group_by(id) %>%
      mutate(
        next_start = lead(exp_start),
        next_value = lead(exp_value),
        gap = next_start - exp_stop - 1,
        # Bridge gap if <= grace and same exposure type
        exp_stop = ifelse(!is.na(gap) & gap > 0 & gap <= grace &
                         exp_value == next_value,
                         next_start - 1,
                         exp_stop)
      ) %>%
      select(-next_start, -next_value, -gap) %>%
      ungroup()
  }

  # Calculate gaps between exposure periods (after grace bridging)
  gaps <- exp_data %>%
    arrange(id, exp_start, exp_stop) %>%
    group_by(id) %>%
    mutate(
      next_start = lead(exp_start),
      gap_days = next_start - exp_stop - 1
    ) %>%
    filter(!is.na(gap_days) & gap_days > 0) %>%
    mutate(
      gap_start = exp_stop + 1,
      gap_stop = next_start - 1
    ) %>%
    ungroup() %>%
    select(id, gap_start, gap_stop)

  # Create gap periods with reference value
  if (nrow(gaps) > 0) {
    gap_periods <- gaps %>%
      rename(exp_start = gap_start, exp_stop = gap_stop) %>%
      mutate(exp_value = reference,
             orig_exp_category = reference) %>%
      left_join(select(master_dates, -any_of(keepvars)), by = "id")
  } else {
    gap_periods <- NULL
  }

  # Create baseline period (pre-first exposure)
  baseline <- exp_data %>%
    group_by(id) %>%
    summarise(earliest_exp = min(exp_start), .groups = "drop") %>%
    right_join(master_dates %>% select(id, study_entry, study_exit), by = "id") %>%
    mutate(
      exp_start = study_entry,
      exp_stop = ifelse(!is.na(earliest_exp), earliest_exp - 1, study_exit),
      exp_value = reference,
      orig_exp_category = reference
    ) %>%
    filter(exp_stop >= exp_start) %>%
    select(-earliest_exp)

  # Create post-exposure period
  post_exposure <- exp_data %>%
    group_by(id) %>%
    summarise(latest_exp = max(exp_stop), .groups = "drop") %>%
    inner_join(master_dates %>% select(id, study_entry, study_exit), by = "id") %>%
    filter(latest_exp < study_exit) %>%
    mutate(
      exp_start = latest_exp + 1,
      exp_stop = study_exit,
      exp_value = reference,
      orig_exp_category = reference
    ) %>%
    select(-latest_exp)

  # Combine all periods
  all_periods <- bind_rows(
    exp_data,
    gap_periods,
    baseline,
    post_exposure
  )

  # Merge back master data variables
  all_periods <- all_periods %>%
    select(-any_of(c("study_entry", "study_exit", keepvars))) %>%
    left_join(master_dates, by = "id")

  # Final cleanup
  all_periods <- all_periods %>%
    distinct(id, exp_start, exp_stop, exp_value, .keep_all = TRUE) %>%
    filter(exp_stop >= study_entry,
           exp_start <= study_exit) %>%
    mutate(
      exp_start = pmax(exp_start, study_entry),
      exp_stop = pmin(exp_stop, study_exit)
    ) %>%
    arrange(id, exp_start, exp_stop)

  # ============================================================================
  # EXPOSURE TYPE TRANSFORMATIONS
  # ============================================================================

  message(sprintf("Applying %s transformation...", exposure_type))

  # Mark exposed vs unexposed
  all_periods <- all_periods %>%
    mutate(is_exposed = exp_value != reference)

  # EVER-TREATED
  if (exposure_type == "evertreated") {

    if (bytype) {
      # Create separate ever-treated variables for each type
      exp_types <- all_periods %>%
        filter(is_exposed) %>%
        pull(orig_exp_category) %>%
        unique() %>%
        sort()

      for (exp_type_val in exp_types) {
        var_name <- paste0(generate, exp_type_val)

        # Find first exposure date for this type
        all_periods <- all_periods %>%
          group_by(id) %>%
          mutate(
            first_exp_date = min(ifelse(orig_exp_category == exp_type_val,
                                       exp_start, Inf), na.rm = TRUE),
            !!var_name := ifelse(exp_start >= first_exp_date &
                                is.finite(first_exp_date), 1, 0)
          ) %>%
          select(-first_exp_date) %>%
          ungroup()
      }

      # Keep exp_value as categorical
      output_var <- "exp_value"

    } else {
      # Single ever-treated variable
      all_periods <- all_periods %>%
        group_by(id) %>%
        mutate(
          first_exp_date = min(ifelse(is_exposed, exp_start, Inf), na.rm = TRUE),
          !!generate := ifelse(exp_start >= first_exp_date &
                              is.finite(first_exp_date), 1, 0)
        ) %>%
        select(-first_exp_date) %>%
        ungroup()

      output_var <- generate
    }
  }

  # CURRENT/FORMER
  else if (exposure_type == "currentformer") {

    if (bytype) {
      # Create separate current/former variables for each type
      exp_types <- all_periods %>%
        filter(is_exposed) %>%
        pull(orig_exp_category) %>%
        unique() %>%
        sort()

      for (exp_type_val in exp_types) {
        var_name <- paste0(generate, exp_type_val)

        all_periods <- all_periods %>%
          group_by(id) %>%
          mutate(
            first_exp = min(ifelse(orig_exp_category == exp_type_val,
                                  exp_start, Inf), na.rm = TRUE),
            is_current = orig_exp_category == exp_type_val,
            !!var_name := case_when(
              is_current ~ 1,  # Currently exposed to this type
              exp_start >= first_exp & is.finite(first_exp) ~ 2,  # Formerly exposed
              TRUE ~ 0  # Never exposed
            )
          ) %>%
          select(-first_exp, -is_current) %>%
          ungroup()
      }

      output_var <- "exp_value"

    } else {
      # Single current/former variable
      all_periods <- all_periods %>%
        group_by(id) %>%
        mutate(
          first_exp = min(ifelse(is_exposed, exp_start, Inf), na.rm = TRUE),
          !!generate := case_when(
            is_exposed ~ 1,  # Currently exposed
            exp_start >= first_exp & is.finite(first_exp) ~ 2,  # Formerly exposed
            TRUE ~ 0  # Never exposed
          )
        ) %>%
        select(-first_exp) %>%
        ungroup()

      output_var <- generate
    }
  }

  # CONTINUOUS DURATION
  else if (exposure_type == "continuous") {

    # Set unit divisor
    unit_divisor <- switch(continuousunit,
                          "days" = 1,
                          "weeks" = 7,
                          "months" = 365.25 / 12,
                          "quarters" = 365.25 / 4,
                          "years" = 365.25)

    if (bytype) {
      # Create separate continuous variables for each type
      exp_types <- all_periods %>%
        filter(is_exposed) %>%
        pull(orig_exp_category) %>%
        unique() %>%
        sort()

      for (exp_type_val in exp_types) {
        var_name <- paste0(generate, exp_type_val)

        all_periods <- all_periods %>%
          arrange(id, exp_start) %>%
          group_by(id) %>%
          mutate(
            period_days = ifelse(orig_exp_category == exp_type_val,
                               exp_stop - exp_start + 1, 0),
            cumul_days = cumsum(period_days),
            !!var_name := cumul_days / unit_divisor
          ) %>%
          select(-period_days, -cumul_days) %>%
          ungroup()
      }

      output_var <- "exp_value"

    } else {
      # Single continuous variable
      all_periods <- all_periods %>%
        arrange(id, exp_start) %>%
        group_by(id) %>%
        mutate(
          period_days = ifelse(is_exposed, exp_stop - exp_start + 1, 0),
          cumul_days = cumsum(period_days),
          !!generate := cumul_days / unit_divisor
        ) %>%
        select(-period_days, -cumul_days) %>%
        ungroup()

      output_var <- generate
    }
  }

  # DURATION CATEGORIES
  else if (exposure_type == "duration") {

    # Set unit divisor
    unit_divisor <- switch(continuousunit,
                          "days" = 1,
                          "weeks" = 7,
                          "months" = 365.25 / 12,
                          "quarters" = 365.25 / 4,
                          "years" = 365.25)

    if (bytype) {
      # Create separate duration variables for each type
      exp_types <- all_periods %>%
        filter(is_exposed) %>%
        pull(orig_exp_category) %>%
        unique() %>%
        sort()

      for (exp_type_val in exp_types) {
        var_name <- paste0(generate, exp_type_val)

        all_periods <- all_periods %>%
          arrange(id, exp_start) %>%
          group_by(id) %>%
          mutate(
            period_days = ifelse(orig_exp_category == exp_type_val,
                               exp_stop - exp_start + 1, 0),
            cumul_days = cumsum(period_days),
            cumul_start_days = lag(cumul_days, default = 0),
            cumul_units = cumul_start_days / unit_divisor
          ) %>%
          ungroup()

        # Assign to duration categories
        all_periods[[var_name]] <- reference

        for (i in seq_along(duration)) {
          if (i == 1) {
            # First category: < first cutpoint
            all_periods[[var_name]] <- ifelse(
              all_periods$orig_exp_category == exp_type_val &
                all_periods$cumul_units < duration[1],
              1,
              all_periods[[var_name]]
            )
          } else {
            # Middle categories
            all_periods[[var_name]] <- ifelse(
              all_periods$orig_exp_category == exp_type_val &
                all_periods$cumul_units >= duration[i-1] &
                all_periods$cumul_units < duration[i],
              i,
              all_periods[[var_name]]
            )
          }
        }

        # Last category: >= last cutpoint
        all_periods[[var_name]] <- ifelse(
          all_periods$orig_exp_category == exp_type_val &
            all_periods$cumul_units >= duration[length(duration)],
          length(duration) + 1,
          all_periods[[var_name]]
        )

        # Carry forward to unexposed periods after first exposure
        all_periods <- all_periods %>%
          group_by(id) %>%
          mutate(
            has_exposure = any(is_exposed),
            !!var_name := ifelse(has_exposure & row_number() > min(which(is_exposed)) &
                                !!sym(var_name) == reference,
                               zoo::na.locf(!!sym(var_name), na.rm = FALSE),
                               !!sym(var_name))
          ) %>%
          select(-has_exposure, -period_days, -cumul_days, -cumul_start_days, -cumul_units) %>%
          ungroup()
      }

      output_var <- "exp_value"

    } else {
      # Single duration variable
      all_periods <- all_periods %>%
        arrange(id, exp_start) %>%
        group_by(id) %>%
        mutate(
          period_days = ifelse(is_exposed, exp_stop - exp_start + 1, 0),
          cumul_days = cumsum(period_days),
          cumul_start_days = lag(cumul_days, default = 0),
          cumul_units = cumul_start_days / unit_divisor
        ) %>%
        ungroup()

      # Assign to duration categories
      all_periods[[generate]] <- reference

      for (i in seq_along(duration)) {
        if (i == 1) {
          all_periods[[generate]] <- ifelse(
            all_periods$is_exposed & all_periods$cumul_units < duration[1],
            1,
            all_periods[[generate]]
          )
        } else {
          all_periods[[generate]] <- ifelse(
            all_periods$is_exposed &
              all_periods$cumul_units >= duration[i-1] &
              all_periods$cumul_units < duration[i],
            i,
            all_periods[[generate]]
          )
        }
      }

      all_periods[[generate]] <- ifelse(
        all_periods$is_exposed &
          all_periods$cumul_units >= duration[length(duration)],
        length(duration) + 1,
        all_periods[[generate]]
      )

      # Carry forward to unexposed periods after first exposure
      all_periods <- all_periods %>%
        group_by(id) %>%
        mutate(
          has_exposure = any(is_exposed),
          !!generate := ifelse(has_exposure & row_number() > min(which(is_exposed)) &
                              !!sym(generate) == reference,
                             zoo::na.locf(!!sym(generate), na.rm = FALSE),
                             !!sym(generate))
        ) %>%
        select(-has_exposure, -period_days, -cumul_days, -cumul_start_days, -cumul_units) %>%
        ungroup()

      output_var <- generate
    }
  }

  # RECENCY
  else if (exposure_type == "recency") {

    if (bytype) {
      # Create separate recency variables for each type
      exp_types <- all_periods %>%
        filter(is_exposed) %>%
        pull(orig_exp_category) %>%
        unique() %>%
        sort()

      for (exp_type_val in exp_types) {
        var_name <- paste0(generate, exp_type_val)

        all_periods <- all_periods %>%
          arrange(id, exp_start) %>%
          group_by(id) %>%
          mutate(
            last_exp_end = ifelse(orig_exp_category == exp_type_val,
                                 exp_stop, NA_real_),
            last_exp_carried = zoo::na.locf(last_exp_end, na.rm = FALSE),
            days_since = exp_start - last_exp_carried
          ) %>%
          ungroup()

        # Assign recency categories
        all_periods[[var_name]] <- reference
        all_periods[[var_name]] <- ifelse(
          all_periods$orig_exp_category == exp_type_val, 1, all_periods[[var_name]]
        )

        # Categories based on time since last exposure (in days)
        if (!is.null(recency)) {
          cat_num <- 2
          for (i in seq_along(recency)) {
            if (i == 1) {
              all_periods[[var_name]] <- ifelse(
                !is.na(all_periods$days_since) &
                  all_periods$days_since >= 0 &
                  all_periods$days_since < recency[1] &
                  all_periods$orig_exp_category != exp_type_val,
                cat_num,
                all_periods[[var_name]]
              )
              cat_num <- cat_num + 1
            } else {
              all_periods[[var_name]] <- ifelse(
                !is.na(all_periods$days_since) &
                  all_periods$days_since >= recency[i-1] &
                  all_periods$days_since < recency[i] &
                  all_periods$orig_exp_category != exp_type_val,
                cat_num,
                all_periods[[var_name]]
              )
              cat_num <- cat_num + 1
            }
          }

          # Last category
          max_cutpoint <- recency[length(recency)]
          all_periods[[var_name]] <- ifelse(
            !is.na(all_periods$days_since) &
              all_periods$days_since >= max_cutpoint &
              all_periods$orig_exp_category != exp_type_val,
            cat_num,
            all_periods[[var_name]]
          )
        }

        all_periods <- all_periods %>%
          select(-last_exp_end, -last_exp_carried, -days_since)
      }

      output_var <- "exp_value"

    } else {
      # Single recency variable
      all_periods <- all_periods %>%
        arrange(id, exp_start) %>%
        group_by(id) %>%
        mutate(
          last_exp_end = ifelse(is_exposed, exp_stop, NA_real_),
          last_exp_carried = zoo::na.locf(last_exp_end, na.rm = FALSE),
          days_since = exp_start - last_exp_carried
        ) %>%
        ungroup()

      # Assign recency categories
      all_periods[[generate]] <- reference
      all_periods[[generate]] <- ifelse(all_periods$is_exposed, 1, all_periods[[generate]])

      if (!is.null(recency)) {
        cat_num <- 2
        for (i in seq_along(recency)) {
          if (i == 1) {
            all_periods[[generate]] <- ifelse(
              !is.na(all_periods$days_since) &
                all_periods$days_since >= 0 &
                all_periods$days_since < recency[1] &
                !all_periods$is_exposed,
              cat_num,
              all_periods[[generate]]
            )
            cat_num <- cat_num + 1
          } else {
            all_periods[[generate]] <- ifelse(
              !is.na(all_periods$days_since) &
                all_periods$days_since >= recency[i-1] &
                all_periods$days_since < recency[i] &
                !all_periods$is_exposed,
              cat_num,
              all_periods[[generate]]
            )
            cat_num <- cat_num + 1
          }
        }

        max_cutpoint <- recency[length(recency)]
        all_periods[[generate]] <- ifelse(
          !is.na(all_periods$days_since) &
            all_periods$days_since >= max_cutpoint &
            !all_periods$is_exposed,
          cat_num,
          all_periods[[generate]]
        )
      }

      all_periods <- all_periods %>%
        select(-last_exp_end, -last_exp_carried, -days_since)

      output_var <- generate
    }
  }

  # TIME-VARYING (keep original categories)
  else {
    # Rename exp_value to generate name
    all_periods <- all_periods %>%
      rename(!!generate := exp_value)

    output_var <- generate
  }

  # ============================================================================
  # FINAL OUTPUT PREPARATION
  # ============================================================================

  message("Finalizing output...")

  # Rename core variables
  all_periods <- all_periods %>%
    rename(start = exp_start, stop = exp_stop)

  # Select output columns
  output_cols <- c("id", "start", "stop")

  if (bytype) {
    # Add bytype variables
    bytype_vars <- grep(paste0("^", generate), names(all_periods), value = TRUE)
    output_cols <- c(output_cols, bytype_vars)
    # Keep original categorical exposure
    if ("exp_value" %in% names(all_periods)) {
      output_cols <- c(output_cols, "exp_value")
    }
  } else {
    output_cols <- c(output_cols, output_var)
  }

  if (!is.null(keepvars)) {
    output_cols <- c(output_cols, keepvars)
  }

  if (keepdates) {
    output_cols <- c(output_cols, "study_entry", "study_exit")
  }

  # Final dataset
  result <- all_periods %>%
    select(all_of(output_cols)) %>%
    arrange(id, start, stop)

  # Calculate summary statistics
  n_persons <- n_distinct(result$id)
  n_periods <- nrow(result)
  total_time <- sum(result$stop - result$start + 1, na.rm = TRUE)

  message(sprintf("Complete: %d persons, %d periods, %.0f person-days",
                 n_persons, n_periods, total_time))

  # Return result
  return(result)
}
