#' Create Time-Varying Exposure Variables for Survival Analysis
#'
#' @description
#' Transforms period-based exposure data into time-varying exposure variables
#' suitable for survival analysis. Handles complex scenarios including overlapping
#' exposures, gaps, multiple exposure types, and various exposure definitions
#' (ever-treated, current/former, cumulative duration, recency).
#'
#' @param master_data Data frame containing cohort with entry/exit dates
#' @param exposure_file String path to exposure file OR data frame with exposure periods
#' @param id String: name of person identifier column
#' @param start String: name of exposure start date column
#' @param exposure String: name of exposure type column
#' @param reference Numeric: value indicating unexposed status
#' @param entry String: name of study entry date column
#' @param exit String: name of study exit date column
#' @param stop String: name of exposure stop date column (required unless pointtime=TRUE)
#' @param pointtime Logical: data are point-in-time (start only, no stop)
#' @param evertreated Logical: create binary ever/never exposed variable
#' @param currentformer Logical: create trichotomous never/current/former variable
#' @param duration Numeric vector: cumulative duration cutpoints
#' @param continuousunit String: unit for cumulative exposure ("days", "weeks", "months", "quarters", "years")
#' @param expandunit String: row expansion granularity (same options as continuousunit)
#' @param bytype Logical: create separate variables per exposure type
#' @param recency Numeric vector: time since last exposure cutpoints (years)
#' @param dose Logical: enable cumulative dose tracking (exposure column contains dose amounts).
#'   When prescriptions overlap, dose is allocated proportionally based on daily rates.
#'   Cannot be combined with bytype.
#' @param dosecuts Numeric vector: cutpoints for dose categorization (requires dose=TRUE).
#'   Creates categories: No dose, <cut1, cut1-<cut2, ..., lastcut+
#'   Example: dosecuts=c(5, 10, 20) creates: No dose, <5, 5-<10, 10-<20, 20+
#' @param grace Numeric or named list: grace period(s) in days
#' @param merge_days Numeric: days to merge same-type consecutive periods (default: 120)
#' @param fillgaps Numeric: assume exposure continues N days beyond last record
#' @param carryforward Numeric: carry forward exposure N days through gaps
#' @param priority Numeric vector: priority order for overlapping exposures (highest first)
#' @param split Logical: split at all exposure boundaries
#' @param layer Logical: later exposures take precedence (default)
#' @param combine String: variable name for combined exposure indicator
#' @param lag Numeric: days before exposure becomes active
#' @param washout Numeric: days exposure persists after stopping
#' @param window Numeric vector c(min, max): acute exposure window filter
#' @param switching Logical: create switching indicator
#' @param switchingdetail Logical: create switching pattern string
#' @param statetime Logical: create cumulative time in current state
#' @param generate String: name for output variable (default: "tv_exposure")
#' @param referencelabel String: label for reference category (default: "Unexposed")
#' @param label String: custom variable label
#' @param saveas String: path to save output
#' @param keepvars Character vector: additional vars to keep from master
#' @param keepdates Logical: keep entry/exit dates in output
#' @param check Logical: display coverage diagnostics
#' @param gaps Logical: show persons with gaps
#' @param overlaps Logical: show overlapping periods
#' @param summarize Logical: display exposure distribution
#' @param validate Logical: create validation dataset
#' @param verbose Logical: show progress messages (default: TRUE)
#'
#' @return List containing:
#' \itemize{
#'   \item data: Time-varying dataset (data.frame)
#'   \item metadata: List with summary statistics and parameters
#'   \item diagnostics: Coverage diagnostics (if validate=TRUE)
#'   \item warnings: Character vector of warnings
#' }
#'
#' @examples
#' \dontrun{
#' # Basic ever-treated
#' result <- tvexpose(
#'   master_data = cohort,
#'   exposure_file = "exposures.csv",
#'   id = "patient_id",
#'   start = "rx_start",
#'   stop = "rx_stop",
#'   exposure = "drug_type",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   evertreated = TRUE
#' )
#'
#' # Current/former with grace period
#' result <- tvexpose(
#'   master_data = cohort,
#'   exposure_file = exposures,
#'   id = "patient_id",
#'   start = "rx_start",
#'   stop = "rx_stop",
#'   exposure = "drug_type",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   currentformer = TRUE,
#'   grace = 30
#' )
#' }
#'
#' @export
tvexpose <- function(
  # Required parameters
  master_data,
  exposure_file,
  id,
  start,
  exposure,
  reference,
  entry,
  exit,

  # Core options
  stop = NULL,
  pointtime = FALSE,

  # Exposure definition options (mutually exclusive)
  evertreated = FALSE,
  currentformer = FALSE,
  duration = NULL,
  continuousunit = NULL,
  expandunit = NULL,
  bytype = FALSE,
  recency = NULL,
  dose = FALSE,
  dosecuts = NULL,

  # Data handling options
  grace = 0,
  merge_days = 120,
  fillgaps = 0,
  carryforward = 0,

  # Competing exposures options (mutually exclusive)
  priority = NULL,
  split = FALSE,
  layer = TRUE,
  combine = NULL,

  # Lag and washout options
  lag = 0,
  washout = 0,
  window = NULL,

  # Pattern tracking options
  switching = FALSE,
  switchingdetail = FALSE,
  statetime = FALSE,

  # Output options
  generate = "tv_exposure",
  referencelabel = "Unexposed",
  label = NULL,
  saveas = NULL,
  keepvars = NULL,
  keepdates = FALSE,

  # Diagnostic options
  check = FALSE,
  gaps = FALSE,
  overlaps = FALSE,
  summarize = FALSE,
  validate = FALSE,

  # Advanced options
  verbose = TRUE
) {

  # Initialize warnings collector
  warnings_list <- character(0)

  # Load required packages
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Package 'data.table' is required. Install with: install.packages('data.table')")
  }
  library(data.table)

  if (verbose) message("tvexpose: Starting time-varying exposure creation")

  # ============================================================================
  # INPUT VALIDATION
  # ============================================================================

  if (verbose) message("  Validating inputs...")

  # Validate required parameters
  required_params <- list(
    master_data = master_data,
    exposure_file = exposure_file,
    id = id,
    start = start,
    exposure = exposure,
    reference = reference,
    entry = entry,
    exit = exit
  )

  for (param_name in names(required_params)) {
    if (is.null(required_params[[param_name]])) {
      stop(sprintf("Required parameter '%s' is missing", param_name))
    }
  }

  # Validate stop or pointtime
  if (is.null(stop) && !pointtime) {
    stop("'stop' is required unless pointtime=TRUE")
  }

  # Check master_data is data frame
  if (!is.data.frame(master_data)) {
    stop("master_data must be a data.frame")
  }

  # Check required columns exist in master_data
  master_cols <- c(id, entry, exit)
  if (!is.null(keepvars)) {
    master_cols <- c(master_cols, keepvars)
  }
  missing <- setdiff(master_cols, names(master_data))
  if (length(missing) > 0) {
    stop(sprintf("Columns not found in master_data: %s",
                 paste(missing, collapse = ", ")))
  }

  # Load and validate exposure data
  if (is.character(exposure_file)) {
    if (!file.exists(exposure_file)) {
      stop(sprintf("Exposure file not found: %s", exposure_file))
    }
    # Determine file type and read
    if (grepl("\\.csv$", exposure_file, ignore.case = TRUE)) {
      exp_data <- read.csv(exposure_file, stringsAsFactors = FALSE)
    } else if (grepl("\\.rds$", exposure_file, ignore.case = TRUE)) {
      exp_data <- readRDS(exposure_file)
    } else if (grepl("\\.dta$", exposure_file, ignore.case = TRUE)) {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required to read .dta files")
      }
      exp_data <- haven::read_dta(exposure_file)
    } else {
      stop("Unsupported file format. Use .csv, .rds, or .dta")
    }
  } else if (is.data.frame(exposure_file)) {
    exp_data <- exposure_file
  } else {
    stop("exposure_file must be a file path or data.frame")
  }

  # Check required columns in exposure data
  exp_cols <- c(id, start, exposure)
  if (!pointtime) {
    exp_cols <- c(exp_cols, stop)
  }
  missing <- setdiff(exp_cols, names(exp_data))
  if (length(missing) > 0) {
    stop(sprintf("Columns not found in exposure data: %s",
                 paste(missing, collapse = ", ")))
  }

  # Validate mutually exclusive exposure types
  exp_types <- c(evertreated, currentformer,
                 !is.null(duration),
                 !is.null(continuousunit) && is.null(duration),
                 !is.null(recency),
                 dose)
  if (sum(exp_types) > 1) {
    stop("Only one exposure type can be specified: evertreated, currentformer, duration, continuousunit, recency, or dose")
  }

  # Validate dosecuts requires dose
  if (!is.null(dosecuts) && !dose) {
    stop("dosecuts requires dose=TRUE. Example: tvexpose(..., dose=TRUE, dosecuts=c(5, 10, 20))")
  }

  # Validate dose cannot be used with bytype
  if (dose && bytype) {
    stop("bytype cannot be used with dose. To analyze doses by drug type, run tvexpose separately for each type.")
  }

  # Validate dosecuts is numeric if provided
  if (!is.null(dosecuts)) {
    if (!is.numeric(dosecuts) || length(dosecuts) == 0) {
      stop("dosecuts must be a numeric vector of cutpoints")
    }
    dosecuts <- sort(dosecuts)  # Ensure sorted
  }

  # Validate mutually exclusive overlap strategies
  overlap_opts <- c(!is.null(priority), split, !is.null(combine), layer)
  if (sum(overlap_opts) > 1) {
    stop("Only one overlap handling option can be specified: priority, split, layer, or combine")
  }

  # Validate numeric parameters
  numeric_params <- list(
    merge_days = merge_days,
    lag = lag,
    washout = washout,
    fillgaps = fillgaps,
    carryforward = carryforward
  )

  for (param_name in names(numeric_params)) {
    val <- numeric_params[[param_name]]
    if (!is.numeric(val) || length(val) != 1) {
      stop(sprintf("%s must be a single numeric value", param_name))
    }
    if (param_name == "merge_days" && val <= 0) {
      stop("merge_days must be positive")
    }
    if (val < 0 && param_name != "merge_days") {
      stop(sprintf("%s cannot be negative", param_name))
    }
  }

  # Validate window format
  if (!is.null(window)) {
    if (length(window) != 2 || !is.numeric(window)) {
      stop("window must be a numeric vector of length 2: c(min, max)")
    }
    if (window[1] >= window[2]) {
      stop("window must be specified with min < max")
    }
  }

  # Validate continuousunit and expandunit
  valid_units <- c("days", "weeks", "months", "quarters", "years")
  if (!is.null(continuousunit)) {
    if (!tolower(continuousunit) %in% valid_units) {
      stop(sprintf("continuousunit must be one of: %s",
                   paste(valid_units, collapse = ", ")))
    }
  }
  if (!is.null(expandunit)) {
    if (!tolower(expandunit) %in% valid_units) {
      stop(sprintf("expandunit must be one of: %s",
                   paste(valid_units, collapse = ", ")))
    }
  }

  # Validate duration/recency are ascending if specified
  if (!is.null(duration)) {
    if (!is.numeric(duration)) {
      stop("duration must be a numeric vector")
    }
    if (is.unsorted(duration)) {
      stop("duration cutpoints must be in ascending order")
    }
  }
  if (!is.null(recency)) {
    if (!is.numeric(recency)) {
      stop("recency must be a numeric vector")
    }
    if (is.unsorted(recency)) {
      stop("recency cutpoints must be in ascending order")
    }
  }

  # Validate bytype usage
  if (bytype) {
    if (!any(c(evertreated, currentformer,
               !is.null(duration), !is.null(continuousunit),
               !is.null(recency)))) {
      stop("bytype cannot be used with default time-varying option")
    }
  }

  # Validate grace format
  grace_bycategory <- FALSE
  grace_list <- NULL
  if (!is.null(grace) && !is.numeric(grace)) {
    if (!is.list(grace)) {
      stop("grace must be numeric or a named list")
    }
    if (is.null(names(grace)) || any(names(grace) == "")) {
      stop("grace list must have names (exposure categories)")
    }
    if (!all(sapply(grace, is.numeric))) {
      stop("grace list values must be numeric (days)")
    }
    grace_bycategory <- TRUE
    grace_list <- grace
    grace <- 0  # Default for categories not in list
  }

  # ============================================================================
  # DATA PREPARATION
  # ============================================================================

  if (verbose) message("  Preparing data...")

  # Convert to data.table
  master_dt <- as.data.table(master_data)
  exp_dt <- as.data.table(exp_data)

  # Strip haven class attributes to prevent rbindlist errors
  for (col in names(master_dt)) {
    if (inherits(master_dt[[col]], "haven_labelled")) {
      master_dt[[col]] <- as.vector(master_dt[[col]])
    }
  }
  for (col in names(exp_dt)) {
    if (inherits(exp_dt[[col]], "haven_labelled")) {
      exp_dt[[col]] <- as.vector(exp_dt[[col]])
    }
  }

  # Ensure date columns are numeric (days)
  for (col in c(entry, exit)) {
    if (inherits(master_dt[[col]], "Date")) {
      master_dt[[col]] <- as.numeric(master_dt[[col]])
    }
    master_dt[[col]] <- as.integer(master_dt[[col]])
  }

  for (col in c(start, if (!pointtime) stop)) {
    if (inherits(exp_dt[[col]], "Date")) {
      exp_dt[[col]] <- as.numeric(exp_dt[[col]])
    }
    exp_dt[[col]] <- as.integer(exp_dt[[col]])
  }

  # Rename columns to standard internal names
  setnames(master_dt,
           old = c(id, entry, exit),
           new = c("id", "study_entry", "study_exit"),
           skip_absent = TRUE)

  setnames(exp_dt,
           old = c(id, start, exposure),
           new = c("id", "exp_start", "exp_value"),
           skip_absent = TRUE)

  if (!pointtime) {
    setnames(exp_dt, old = stop, new = "exp_stop", skip_absent = TRUE)
  } else {
    exp_dt[, exp_stop := exp_start]
  }

  # Keep only specified columns from master
  keep_cols <- c("id", "study_entry", "study_exit")
  if (!is.null(keepvars)) {
    keep_cols <- c(keep_cols, keepvars)
  }
  master_dt <- master_dt[, ..keep_cols]

  # Merge exposure data with master dates
  exp_dt <- merge(exp_dt, master_dt, by = "id", all.x = FALSE, all.y = FALSE)

  if (nrow(exp_dt) == 0) {
    stop("No matching records found between master_data and exposure_file")
  }

  # Truncate exposure periods to study window
  exp_dt[, exp_start := pmax(exp_start, study_entry)]
  exp_dt[, exp_stop := pmin(exp_stop, study_exit)]

  # Remove invalid periods
  exp_dt <- exp_dt[exp_stop >= exp_start]

  # Remove periods entirely outside study window
  exp_dt <- exp_dt[exp_start <= study_exit & exp_stop >= study_entry]

  # Apply lag if specified
  if (lag > 0) {
    exp_dt[, exp_start := exp_start + lag]
    exp_dt <- exp_dt[exp_start <= exp_stop]
  }

  # Apply washout if specified
  if (washout > 0) {
    exp_dt[, exp_stop := pmin(exp_stop + washout, study_exit)]
  }

  # Apply window filter if specified
  if (!is.null(window)) {
    exp_dt[, period_duration := exp_stop - exp_start + 1]
    exp_dt <- exp_dt[period_duration >= window[1] & period_duration <= window[2]]
    exp_dt[, period_duration := NULL]
  }

  # Apply fillgaps if specified
  if (fillgaps > 0) {
    exp_dt[, is_last := (.I == .N), by = id]
    exp_dt[is_last == TRUE, exp_stop := pmin(exp_stop + fillgaps, study_exit)]
    exp_dt[, is_last := NULL]
  }

  # Create helper variables
  exp_dt[, `:=`(
    orig_exp_binary = as.integer(exp_value != reference),
    orig_exp_category = exp_value
  )]

  # Sort by id, start, stop
  setkey(exp_dt, id, exp_start, exp_stop)

  # ============================================================================
  # PERIOD MERGING
  # ============================================================================

  # Skip period merging for dose mode - each prescription must be preserved
  if (!dose) {
    if (verbose) message("  Merging consecutive periods...")
    exp_dt <- merge_periods_impl(exp_dt, merge_days, reference, verbose)
  } else {
    if (verbose) message("  Skipping period merging (dose mode)...")
  }

  # ============================================================================
  # CONTAINED PERIOD REMOVAL
  # ============================================================================

  # Skip contained period removal for dose mode - all prescriptions count
  if (!dose) {
    if (verbose) message("  Removing contained periods...")
    exp_dt <- remove_contained_impl(exp_dt, verbose)
  } else {
    if (verbose) message("  Skipping contained period removal (dose mode)...")
  }

  # ============================================================================
  # OVERLAP RESOLUTION
  # ============================================================================

  # Skip standard overlap resolution for dose mode - uses proportional allocation
  if (!dose) {
    if (verbose) message("  Resolving overlaps...")

    if (!is.null(priority)) {
      exp_dt <- resolve_overlaps_priority_impl(exp_dt, priority)
    } else if (split) {
      exp_dt <- resolve_overlaps_split_impl(exp_dt)
    } else if (!is.null(combine)) {
      exp_dt <- resolve_overlaps_combine_impl(exp_dt, combine)
    } else if (layer) {
      exp_dt <- resolve_overlaps_layer_impl(exp_dt)
    }
  } else {
    if (verbose) message("  Skipping standard overlap resolution (dose mode uses proportional allocation)...")
  }

  # ============================================================================
  # GAP PERIOD CREATION
  # ============================================================================

  if (verbose) message("  Creating gap periods...")

  gap_result <- create_gap_periods_impl(
    exp_dt, reference, grace, grace_bycategory, grace_list, carryforward, verbose
  )
  exp_dt <- gap_result$exp_dt
  gap_periods <- gap_result$gaps

  # Combine exposure periods with gap periods
  if (!is.null(gap_periods) && nrow(gap_periods) > 0) {
    exp_dt <- rbindlist(list(exp_dt, gap_periods), fill = TRUE)
    setkey(exp_dt, id, exp_start, exp_stop)
  }

  # ============================================================================
  # BASELINE AND POST-EXPOSURE PERIODS
  # ============================================================================

  if (verbose) message("  Adding baseline and post-exposure periods...")

  baseline <- create_baseline_periods_impl(master_dt, exp_dt, reference)
  post <- create_postexposure_periods_impl(exp_dt, reference)

  # Combine all periods
  all_periods <- rbindlist(list(exp_dt, baseline, post), fill = TRUE)
  setkey(all_periods, id, exp_start, exp_stop)

  # Remove overlaps introduced by baseline/post periods
  all_periods <- remove_duplicate_coverage(all_periods)

  # ============================================================================
  # EXPOSURE TYPE APPLICATION
  # ============================================================================

  if (verbose) message("  Applying exposure definition...")

  # Determine stub name for bytype variables
  stub_name <- generate
  if (bytype) {
    if (generate == "tv_exposure") {
      # Use default stubs based on exposure type
      if (evertreated) {
        stub_name <- "ever"
      } else if (currentformer) {
        stub_name <- "cf"
      } else if (!is.null(duration)) {
        stub_name <- "duration"
      } else if (!is.null(continuousunit)) {
        stub_name <- "tv_exp"
      } else if (!is.null(recency)) {
        stub_name <- "recency"
      } else {
        stub_name <- "exp"
      }
    }
  }

  # Determine which exposure type to apply
  if (evertreated) {
    result_dt <- apply_evertreated_impl(
      all_periods, reference, bytype, stub_name, keepvars
    )
  } else if (currentformer) {
    result_dt <- apply_currentformer_impl(
      all_periods, reference, bytype, stub_name, keepvars
    )
  } else if (!is.null(continuousunit)) {
    result_dt <- apply_continuous_impl(
      all_periods, reference, bytype, stub_name, keepvars,
      continuousunit, expandunit, duration
    )
  } else if (!is.null(duration)) {
    result_dt <- apply_duration_impl(
      all_periods, reference, bytype, stub_name, keepvars,
      continuousunit, duration
    )
  } else if (!is.null(recency)) {
    result_dt <- apply_recency_impl(
      all_periods, reference, bytype, stub_name, keepvars, recency
    )
  } else if (dose) {
    if (verbose) message("  Applying dose-based exposure...")
    result_dt <- apply_dose_impl(
      all_periods, reference, keepvars, dosecuts, verbose
    )
  } else {
    # Default: time-varying with original exposure values
    result_dt <- all_periods
    setnames(result_dt, "exp_value", generate, skip_absent = TRUE)
  }

  # ============================================================================
  # PATTERN TRACKING
  # ============================================================================

  if (switching) {
    if (verbose) message("  Adding switching indicator...")
    result_dt <- add_switching_indicator_impl(result_dt, generate)
  }

  if (switchingdetail) {
    if (verbose) message("  Adding switching detail...")
    result_dt <- add_switching_detail_impl(result_dt, generate)
  }

  if (statetime) {
    if (verbose) message("  Adding state time...")
    result_dt <- add_statetime_impl(result_dt, generate)
  }

  # ============================================================================
  # FINALIZATION
  # ============================================================================

  if (verbose) message("  Finalizing output...")

  # Rename exp_value to generate name if it exists (for currentformer, evertreated, etc.)
  if ("exp_value" %in% names(result_dt)) {
    setnames(result_dt, "exp_value", generate, skip_absent = TRUE)
  }

  # Remove internal helper columns (exp_value already renamed, so not in this list)
  helper_cols <- c("orig_exp_binary", "orig_exp_category")
  for (col in helper_cols) {
    if (col %in% names(result_dt)) {
      result_dt[, (col) := NULL]
    }
  }

  # Keep/remove entry/exit dates
  if (!keepdates) {
    result_dt[, c("study_entry", "study_exit") := NULL]
  }

  # Rename date columns back to user's names
  setnames(result_dt,
           old = c("exp_start", "exp_stop"),
           new = c("start", "stop"))

  # Convert back to data.frame
  result_df <- as.data.frame(result_dt)

  # ============================================================================
  # METADATA AND DIAGNOSTICS
  # ============================================================================

  metadata <- list(
    N_persons = uniqueN(result_dt$id),
    N_periods = nrow(result_dt),
    total_time = sum(result_dt$stop - result_dt$start + 1, na.rm = TRUE),
    exposure_types = unique(result_dt[[generate]]),
    parameters = list(
      exposure_definition = if (evertreated) "evertreated"
                           else if (currentformer) "currentformer"
                           else if (!is.null(duration)) "duration"
                           else if (!is.null(continuousunit)) "continuous"
                           else if (!is.null(recency)) "recency"
                           else if (dose) "dose"
                           else "timevarying",
      continuousunit = continuousunit,
      expandunit = expandunit,
      dosecuts = dosecuts,
      overlap_strategy = if (!is.null(priority)) "priority"
                        else if (split) "split"
                        else if (!is.null(combine)) "combine"
                        else "layer",
      grace = if (grace_bycategory) grace_list else grace,
      merge_days = merge_days,
      lag = lag,
      washout = washout,
      carryforward = carryforward,
      fillgaps = fillgaps,
      bytype = bytype
    )
  )

  # Calculate exposed/unexposed time
  if (generate %in% names(result_dt)) {
    exposed_mask <- result_dt[[generate]] != reference
    metadata$exposed_time <- sum((result_dt$stop[exposed_mask] -
                                   result_dt$start[exposed_mask] + 1), na.rm = TRUE)
    metadata$unexposed_time <- metadata$total_time - metadata$exposed_time
    metadata$pct_exposed <- 100 * metadata$exposed_time / metadata$total_time
  }

  # Diagnostics
  diagnostics <- NULL
  if (validate) {
    if (verbose) message("  Generating diagnostics...")
    diagnostics <- check_coverage_impl(result_dt, master_dt)
  }

  if (check) {
    coverage <- check_coverage_impl(result_dt, master_dt)
    message("\nCoverage Summary:")
    message(sprintf("  Mean coverage: %.2f%%", mean(coverage$pct_covered)))
    message(sprintf("  Persons with gaps: %d", sum(coverage$coverage_gap > 0)))
  }

  if (gaps) {
    gap_report <- identify_gaps_impl(result_dt)
    if (nrow(gap_report) > 0) {
      message(sprintf("\nFound %d gaps in %d persons",
                     nrow(gap_report), uniqueN(gap_report$id)))
      print(head(gap_report))
    }
  }

  if (overlaps) {
    overlap_report <- identify_overlaps_impl(result_dt, generate)
    if (nrow(overlap_report) > 0) {
      message(sprintf("\nFound %d overlaps in %d persons",
                     nrow(overlap_report), uniqueN(overlap_report$id)))
      print(head(overlap_report))
    }
  }

  if (summarize) {
    summary_report <- summarize_exposure_impl(result_dt, generate)
    message("\nExposure Summary:")
    print(summary_report)
  }

  # ============================================================================
  # SAVE OUTPUT
  # ============================================================================

  if (!is.null(saveas)) {
    if (verbose) message(sprintf("  Saving to %s...", saveas))
    if (grepl("\\.csv$", saveas, ignore.case = TRUE)) {
      write.csv(result_df, saveas, row.names = FALSE)
    } else if (grepl("\\.rds$", saveas, ignore.case = TRUE)) {
      saveRDS(result_df, saveas)
    } else {
      warning("Unknown file extension for saveas. Saving as .csv")
      write.csv(result_df, paste0(saveas, ".csv"), row.names = FALSE)
    }
  }

  # ============================================================================
  # RETURN
  # ============================================================================

  if (verbose) message("tvexpose: Complete!")

  return(list(
    data = result_df,
    metadata = metadata,
    diagnostics = diagnostics,
    warnings = warnings_list
  ))
}

# ==============================================================================
# INTERNAL IMPLEMENTATION FUNCTIONS
# ==============================================================================

#' Merge consecutive periods of same exposure type
#' @keywords internal
merge_periods_impl <- function(exp_dt, merge_days, reference, verbose = TRUE) {
  max_iter <- 10000
  iter <- 0
  changes <- 1

  while (changes > 0 && iter < max_iter) {
    if (verbose && iter > 0 && iter %% 100 == 0) {
      message(sprintf("    Merge iteration %d/%d", iter, max_iter))
    }

    exp_dt[, drop_flag := 0L]

    # Calculate gap to next period
    exp_dt[, `:=`(
      gap_to_next = shift(exp_start, type = "lead") - exp_stop,
      next_value = shift(exp_value, type = "lead"),
      next_stop = shift(exp_stop, type = "lead")
    ), by = id]

    # Mark periods that can merge with next
    exp_dt[, can_merge := !is.na(gap_to_next) &
                          gap_to_next <= merge_days &
                          exp_value == next_value]

    # Extend current period to encompass next
    exp_dt[can_merge == TRUE, exp_stop := pmax(exp_stop, next_stop)]

    # Mark next period for deletion
    exp_dt[, should_drop := shift(can_merge, type = "lag", fill = FALSE), by = id]
    exp_dt[, `:=`(
      prev_start = shift(exp_start, type = "lag"),
      prev_stop = shift(exp_stop, type = "lag")
    ), by = id]

    # Only drop if fully contained in previous merged period
    exp_dt[should_drop == TRUE, drop_flag :=
           as.integer(exp_start >= prev_start & exp_stop <= prev_stop)]

    changes <- sum(exp_dt$drop_flag)

    if (changes > 0) {
      exp_dt <- exp_dt[drop_flag == 0]
    }

    exp_dt[, c("gap_to_next", "next_value", "next_stop", "can_merge",
               "should_drop", "prev_start", "prev_stop", "drop_flag") := NULL]

    iter <- iter + 1
  }

  if (iter >= max_iter) {
    warning(sprintf("Merge iteration limit (%d) reached", max_iter))
  }

  # Remove exact duplicates
  exp_dt <- unique(exp_dt, by = c("id", "exp_start", "exp_stop", "exp_value"))

  return(exp_dt)
}

#' Remove periods fully contained within another period
#' @keywords internal
remove_contained_impl <- function(exp_dt, verbose = TRUE) {
  max_iter <- 10000
  iter <- 0
  done <- FALSE

  while (!done && iter < max_iter) {
    if (verbose && iter > 0 && iter %% 100 == 0) {
      message(sprintf("    Containment check iteration %d/%d", iter, max_iter))
    }

    exp_dt[, contained := 0L]
    exp_dt[, `:=`(
      prev_start = shift(exp_start, type = "lag"),
      prev_stop = shift(exp_stop, type = "lag"),
      prev_value = shift(exp_value, type = "lag")
    ), by = id]

    # Mark as contained if fully within previous period of same type
    exp_dt[!is.na(prev_start), contained :=
           as.integer(exp_start >= prev_start &
                      exp_stop <= prev_stop &
                      exp_value == prev_value)]

    n_contained <- sum(exp_dt$contained)

    if (n_contained == 0) {
      done <- TRUE
    } else {
      exp_dt <- exp_dt[contained == 0]
      setkey(exp_dt, id, exp_start, exp_stop)
    }

    exp_dt[, c("contained", "prev_start", "prev_stop", "prev_value") := NULL]

    iter <- iter + 1
  }

  if (iter >= max_iter) {
    warning("Containment check iteration limit reached")
  }

  return(exp_dt)
}

#' Resolve overlaps using split strategy
#' @keywords internal
resolve_overlaps_split_impl <- function(exp_dt) {
  # Collect all unique boundaries per person
  boundaries_start <- exp_dt[, .(id, boundary = exp_start)]
  boundaries_stop <- exp_dt[, .(id, boundary = exp_stop + 1)]

  all_boundaries <- rbindlist(list(boundaries_start, boundaries_stop))
  all_boundaries <- unique(all_boundaries)
  setkey(all_boundaries, id, boundary)

  exp_dt[, period_id := .I]

  # Cross join boundaries with periods
  split_dt <- merge(exp_dt, all_boundaries, by = "id", allow.cartesian = TRUE)

  # Keep only boundaries within period
  split_dt <- split_dt[boundary > exp_start & boundary < exp_stop]

  if (nrow(split_dt) == 0) {
    exp_dt[, period_id := NULL]
    return(exp_dt)
  }

  # Create split periods
  setkey(split_dt, id, period_id, boundary)
  split_dt[, `:=`(
    new_start = fifelse(.I == 1, exp_start, boundary),
    new_stop = fifelse(.I == .N, exp_stop, boundary - 1)
  ), by = .(id, period_id)]

  split_dt <- split_dt[new_start <= new_stop]

  split_ids <- unique(split_dt$period_id)
  exp_dt <- exp_dt[!period_id %in% split_ids]

  split_dt[, `:=`(exp_start = new_start, exp_stop = new_stop)]
  split_dt[, c("new_start", "new_stop", "boundary", "period_id") := NULL]

  result <- rbindlist(list(exp_dt[, period_id := NULL], split_dt), fill = TRUE)
  result <- unique(result, by = c("id", "exp_start", "exp_stop", "exp_value"))
  setkey(result, id, exp_start, exp_stop)

  return(result)
}

#' Resolve overlaps using priority strategy
#' @keywords internal
resolve_overlaps_priority_impl <- function(exp_dt, priority_order) {
  priority_map <- data.table(
    exp_value = priority_order,
    priority_rank = seq_along(priority_order)
  )

  exp_dt <- merge(exp_dt, priority_map, by = "exp_value", all.x = TRUE)

  max_rank <- max(priority_map$priority_rank)
  exp_dt[is.na(priority_rank), priority_rank := max_rank + 1]

  setorder(exp_dt, id, exp_start, priority_rank)

  exp_dt[, `:=`(
    prev_stop = shift(exp_stop, type = "lag"),
    prev_priority = shift(priority_rank, type = "lag")
  ), by = id]

  exp_dt[!is.na(prev_stop) &
         exp_start <= prev_stop &
         priority_rank > prev_priority,
         exp_start := prev_stop + 1]

  exp_dt <- exp_dt[exp_start <= exp_stop]
  exp_dt[, c("priority_rank", "prev_stop", "prev_priority") := NULL]

  return(exp_dt)
}

#' Resolve overlaps using layer strategy
#' @keywords internal
resolve_overlaps_layer_impl <- function(exp_dt) {
  setkey(exp_dt, id, exp_start, exp_stop)

  exp_dt[, `:=`(
    next_start = shift(exp_start, type = "lead"),
    next_stop = shift(exp_stop, type = "lead"),
    next_value = shift(exp_value, type = "lead")
  ), by = id]

  exp_dt[, has_overlap := !is.na(next_start) & next_start <= exp_stop]

  overlaps <- exp_dt[has_overlap == TRUE & exp_value != next_value]

  if (nrow(overlaps) > 0) {
    pre_overlap <- overlaps[next_start > exp_start,
                            .(id, exp_start,
                              exp_stop = next_start - 1,
                              exp_value,
                              orig_exp_binary,
                              orig_exp_category,
                              study_entry,
                              study_exit)]

    post_overlap <- overlaps[exp_stop > next_stop,
                             .(id,
                               exp_start = next_stop + 1,
                               exp_stop,
                               exp_value,
                               orig_exp_binary,
                               orig_exp_category,
                               study_entry,
                               study_exit)]

    exp_dt <- exp_dt[!(has_overlap == TRUE & exp_value != next_value)]

    exp_dt <- rbindlist(list(exp_dt, pre_overlap, post_overlap), fill = TRUE)
  }

  exp_dt[, c("next_start", "next_stop", "next_value", "has_overlap") := NULL]

  exp_dt <- exp_dt[exp_start <= exp_stop]
  exp_dt <- unique(exp_dt, by = c("id", "exp_start", "exp_stop", "exp_value"))
  setkey(exp_dt, id, exp_start, exp_stop)

  return(exp_dt)
}

#' Resolve overlaps using combine strategy
#' @keywords internal
resolve_overlaps_combine_impl <- function(exp_dt, combine_varname) {
  exp_dt[, `:=`(
    next_start = shift(exp_start, type = "lead"),
    next_value = shift(exp_value, type = "lead")
  ), by = id]

  exp_dt[, has_overlap := !is.na(next_start) &
                          next_start <= exp_stop &
                          exp_value != next_value]

  exp_dt[, exp_combined := exp_value]
  exp_dt[has_overlap == TRUE,
         exp_combined := exp_value * 100 + next_value]

  exp_dt[, `:=`(
    prev_value = shift(exp_value, type = "lag"),
    prev_stop = shift(exp_stop, type = "lag")
  ), by = id]

  exp_dt[!is.na(prev_stop) &
         exp_start <= prev_stop &
         exp_value != prev_value,
         exp_combined := prev_value * 100 + exp_value]

  setnames(exp_dt, "exp_combined", combine_varname)

  exp_dt[, c("next_start", "next_value", "has_overlap",
             "prev_value", "prev_stop") := NULL]

  return(exp_dt)
}

#' Create gap periods filled with reference value
#' @keywords internal
create_gap_periods_impl <- function(exp_dt, reference, grace_default,
                                     grace_bycategory, grace_list,
                                     carryforward, verbose = TRUE) {

  exp_dt[, `:=`(
    next_start = shift(exp_start, type = "lead"),
    next_value = shift(exp_value, type = "lead")
  ), by = id]

  exp_dt[, gap_days := next_start - exp_stop - 1]

  exp_dt[, grace_days := grace_default]

  if (grace_bycategory && !is.null(grace_list)) {
    for (cat in names(grace_list)) {
      cat_num <- as.numeric(cat)
      exp_dt[exp_value == cat_num, grace_days := grace_list[[cat]]]
    }
  }

  # Bridge small gaps within grace period
  exp_dt[!is.na(gap_days) &
         gap_days <= grace_days &
         gap_days >= 0 &
         exp_value == next_value,
         exp_stop := next_start - 1]

  # Recalculate gaps after bridging
  exp_dt[, next_start := shift(exp_start, type = "lead"), by = id]
  exp_dt[, gap_days := next_start - exp_stop - 1]

  # Identify gaps that need filling
  gaps <- exp_dt[!is.na(gap_days) & gap_days > grace_days,
                 .(id,
                   gap_start = exp_stop + 1,
                   gap_stop = next_start - 1,
                   gap_days,
                   prev_value = exp_value,
                   study_entry = study_entry,
                   study_exit = study_exit)]

  if (nrow(gaps) == 0) {
    exp_dt[, c("next_start", "next_value", "gap_days", "grace_days") := NULL]
    return(list(exp_dt = exp_dt, gaps = NULL))
  }

  # Apply carryforward if specified
  if (carryforward > 0) {
    gaps[, `:=`(
      carry_stop = pmin(gap_start + carryforward - 1, gap_stop),
      needs_ref = gap_days > carryforward
    )]

    carry_periods <- gaps[, .(
      id,
      exp_start = gap_start,
      exp_stop = carry_stop,
      exp_value = prev_value,
      study_entry,
      study_exit
    )]

    ref_periods <- gaps[needs_ref == TRUE, .(
      id,
      exp_start = carry_stop + 1,
      exp_stop = gap_stop,
      exp_value = reference,
      study_entry,
      study_exit
    )]

    gap_periods <- rbindlist(list(carry_periods, ref_periods), fill = TRUE)
  } else {
    gap_periods <- gaps[, .(
      id,
      exp_start = gap_start,
      exp_stop = gap_stop,
      exp_value = reference,
      study_entry,
      study_exit
    )]
  }

  # Add helper columns to gap periods
  gap_periods[, `:=`(
    orig_exp_binary = as.integer(exp_value != reference),
    orig_exp_category = exp_value
  )]

  exp_dt[, c("next_start", "next_value", "gap_days", "grace_days") := NULL]

  return(list(exp_dt = exp_dt, gaps = gap_periods))
}

#' Create baseline periods (before first exposure)
#' @keywords internal
create_baseline_periods_impl <- function(master_dt, exp_dt, reference) {
  earliest <- exp_dt[, .(earliest_exp = min(exp_start)), by = id]

  baseline <- merge(master_dt, earliest, by = "id", all.x = TRUE)

  baseline[, `:=`(
    exp_start = study_entry,
    exp_stop = fifelse(is.na(earliest_exp),
                       study_exit,
                       earliest_exp - 1),
    exp_value = reference
  )]

  baseline <- baseline[exp_stop >= exp_start]

  baseline[, `:=`(
    orig_exp_binary = 0L,
    orig_exp_category = reference,
    earliest_exp = NULL
  )]

  return(baseline)
}

#' Create post-exposure periods (after last exposure)
#' @keywords internal
create_postexposure_periods_impl <- function(exp_dt, reference) {
  last_exp <- exp_dt[, .(
    id,
    last_exp_stop = max(exp_stop),
    study_exit = first(study_exit),
    study_entry = first(study_entry)
  ), by = id]

  post <- last_exp[last_exp_stop < study_exit,
                   .(id,
                     exp_start = last_exp_stop + 1,
                     exp_stop = study_exit,
                     exp_value = reference,
                     study_entry,
                     study_exit)]

  post[, `:=`(
    orig_exp_binary = 0L,
    orig_exp_category = reference
  )]

  return(post)
}

#' Remove duplicate coverage from overlapping periods
#' @keywords internal
remove_duplicate_coverage <- function(all_periods) {
  # Sort and remove exact duplicates
  setkey(all_periods, id, exp_start, exp_stop, exp_value)
  all_periods <- unique(all_periods)

  # For each person, ensure no time is covered twice
  # Keep non-reference periods over reference periods
  all_periods[, period_id := .I]
  all_periods[, is_reference := (exp_value == min(exp_value)), by = id]

  # If periods overlap and one is reference, truncate/remove reference period
  all_periods[, `:=`(
    prev_start = shift(exp_start, type = "lag"),
    prev_stop = shift(exp_stop, type = "lag"),
    prev_is_ref = shift(is_reference, type = "lag")
  ), by = id]

  # Mark reference periods that overlap with non-reference
  all_periods[is_reference == TRUE &
              !is.na(prev_stop) &
              exp_start <= prev_stop,
              exp_start := prev_stop + 1]

  # Remove invalid periods
  all_periods <- all_periods[exp_start <= exp_stop]

  all_periods[, c("period_id", "is_reference", "prev_start",
                  "prev_stop", "prev_is_ref") := NULL]

  return(all_periods)
}

#' Apply ever-treated exposure definition
#' @keywords internal
apply_evertreated_impl <- function(exp_dt, reference, bytype,
                                    stub_name, keepvars) {
  exp_dt[, first_exp_any := min(exp_start[orig_exp_binary == 1]), by = id]

  if (bytype) {
    exp_types <- unique(exp_dt[exp_value != reference, exp_value])

    for (exp_type_val in exp_types) {
      suffix <- gsub("-", "neg", as.character(exp_type_val))
      suffix <- gsub("\\.", "p", suffix)
      varname <- paste0(stub_name, suffix)

      exp_dt[, temp_first := min(exp_start[orig_exp_category == exp_type_val]),
             by = id]

      exp_dt[, (varname) := fifelse(
        is.na(temp_first) | exp_start < temp_first,
        0,
        1
      )]

      exp_dt[, temp_first := NULL]
    }

    ever_vars <- paste0(stub_name,
                        gsub("-", "neg", gsub("\\.", "p", as.character(exp_types))))

    exp_dt[, period_group := .GRP,
           by = c("id", "exp_value", ever_vars)]

    keep_cols <- c("id", "exp_value", ever_vars)
    if (!is.null(keepvars)) {
      keep_cols <- c(keep_cols, keepvars)
    }
    keep_cols <- intersect(keep_cols, names(exp_dt))

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop),
      study_entry = first(study_entry),
      study_exit = first(study_exit)
    ), by = c("period_group", keep_cols)]

    result[, period_group := NULL]

  } else {
    exp_dt[, exp_value_new := fifelse(
      is.na(first_exp_any) | exp_start < first_exp_any,
      0,
      1
    )]

    exp_dt[, exp_value := exp_value_new]
    exp_dt[, exp_value_new := NULL]

    exp_dt[, period_group := rleid(id, exp_value)]

    keep_cols <- c("id", "exp_value")
    if (!is.null(keepvars)) {
      keep_cols <- c(keep_cols, keepvars)
    }
    keep_cols <- intersect(keep_cols, names(exp_dt))

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop),
      study_entry = first(study_entry),
      study_exit = first(study_exit)
    ), by = c("period_group", keep_cols)]

    result[, period_group := NULL]
  }

  # Remove first_exp_any if it exists
  if ("first_exp_any" %in% names(result)) {
    result[, first_exp_any := NULL]
  }
  setkey(result, id, exp_start)

  return(result)
}

#' Apply current/former exposure definition
#' @keywords internal
apply_currentformer_impl <- function(exp_dt, reference, bytype,
                                      stub_name, keepvars) {

  if (bytype) {
    exp_types <- unique(exp_dt[exp_value != reference, exp_value])

    for (exp_type_val in exp_types) {
      suffix <- gsub("-", "neg", as.character(exp_type_val))
      suffix <- gsub("\\.", "p", suffix)
      varname <- paste0(stub_name, suffix)

      exp_dt[, `:=`(
        first_exp = min(exp_start[orig_exp_category == exp_type_val]),
        last_exp = max(exp_stop[orig_exp_category == exp_type_val])
      ), by = id]

      exp_dt[, (varname) := fcase(
        is.na(first_exp), 0L,
        orig_exp_category == exp_type_val, 1L,
        exp_start >= first_exp, 2L,
        default = 0L
      )]

      exp_dt[, c("first_exp", "last_exp") := NULL]
    }

    cf_vars <- paste0(stub_name,
                      gsub("-", "neg", gsub("\\.", "p", as.character(exp_types))))

    exp_dt[, period_group := .GRP,
           by = c("id", "exp_value", cf_vars)]

    keep_cols <- c("id", "exp_value", cf_vars)
    if (!is.null(keepvars)) {
      keep_cols <- c(keep_cols, keepvars)
    }
    keep_cols <- intersect(keep_cols, names(exp_dt))

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop),
      study_entry = first(study_entry),
      study_exit = first(study_exit)
    ), by = c("period_group", keep_cols)]

    result[, period_group := NULL]

  } else {
    exp_dt[, `:=`(
      first_exp_any = min(exp_start[orig_exp_binary == 1]),
      currently_exposed = orig_exp_binary
    ), by = id]

    exp_dt[, exp_value_new := fcase(
      is.na(first_exp_any), 0L,
      currently_exposed == 1, 1L,
      exp_start >= first_exp_any, 2L,
      default = 0L
    )]

    exp_dt[, exp_value := exp_value_new]
    exp_dt[, c("exp_value_new", "first_exp_any", "currently_exposed") := NULL]

    exp_dt[, period_group := rleid(id, exp_value)]

    keep_cols <- c("id", "exp_value")
    if (!is.null(keepvars)) {
      keep_cols <- c(keep_cols, keepvars)
    }
    keep_cols <- intersect(keep_cols, names(exp_dt))

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop),
      study_entry = first(study_entry),
      study_exit = first(study_exit)
    ), by = c("period_group", keep_cols)]

    result[, period_group := NULL]
  }

  setkey(result, id, exp_start)
  return(result)
}

#' Apply continuous cumulative exposure definition
#' @keywords internal
apply_continuous_impl <- function(exp_dt, reference, bytype, stub_name,
                                   keepvars, continuousunit, expandunit,
                                   duration) {
  # Unit conversion factors
  unit_divisor <- switch(
    tolower(continuousunit),
    "days" = 1,
    "weeks" = 7,
    "months" = 365.25 / 12,
    "quarters" = 365.25 / 4,
    "years" = 365.25,
    1  # default
  )

  # Determine expansion unit
  expand_unit <- if (!is.null(expandunit)) {
    tolower(expandunit)
  } else if (!is.null(continuousunit)) {
    tolower(continuousunit)
  } else {
    "days"
  }

  # Apply row expansion if not "days"
  if (expand_unit != "days") {
    exp_dt <- expand_by_unit_impl(exp_dt, expand_unit, reference)
  }

  # Calculate period days
  exp_dt[, period_days := exp_stop - exp_start + 1]
  exp_dt[exp_value == reference, period_days := 0]

  # Calculate cumulative exposure
  exp_dt[, cumul_days_end := cumsum(period_days), by = id]

  if (bytype) {
    exp_types <- unique(exp_dt[exp_value != reference, exp_value])

    for (exp_type_val in exp_types) {
      suffix <- gsub("-", "neg", as.character(exp_type_val))
      suffix <- gsub("\\.", "p", suffix)
      varname <- paste0(stub_name, suffix)

      exp_dt[, temp_days := fifelse(orig_exp_category == exp_type_val,
                                     period_days,
                                     0)]

      exp_dt[, temp_cumul := cumsum(temp_days), by = id]
      exp_dt[, (varname) := temp_cumul / unit_divisor]
      exp_dt[, c("temp_days", "temp_cumul") := NULL]
    }

    tvexp_vars <- paste0(stub_name,
                         gsub("-", "neg", gsub("\\.", "p", as.character(exp_types))))

    exp_dt[, period_group := .GRP, by = c("id", tvexp_vars)]

    keep_cols <- c("id", "exp_value", tvexp_vars)
    if (!is.null(keepvars)) {
      keep_cols <- c(keep_cols, keepvars)
    }
    keep_cols <- intersect(keep_cols, names(exp_dt))

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop),
      study_entry = first(study_entry),
      study_exit = first(study_exit)
    ), by = c("period_group", keep_cols)]

    result[, period_group := NULL]

  } else {
    exp_dt[, tv_exp := cumul_days_end / unit_divisor]

    exp_dt[, period_group := rleid(id, tv_exp)]

    keep_cols <- c("id", "exp_value", "tv_exp")
    if (!is.null(keepvars)) {
      keep_cols <- c(keep_cols, keepvars)
    }
    keep_cols <- intersect(keep_cols, names(exp_dt))

    result <- exp_dt[, .(
      exp_start = min(exp_start),
      exp_stop = max(exp_stop),
      study_entry = first(study_entry),
      study_exit = first(study_exit)
    ), by = c("period_group", keep_cols)]

    result[, period_group := NULL]
  }

  setkey(result, id, exp_start)
  return(result)
}

#' Expand rows by time unit
#' @keywords internal
expand_by_unit_impl <- function(exp_dt, unit, reference) {
  exp_dt[, needs_expansion := (exp_value != reference)]

  exposed <- exp_dt[needs_expansion == TRUE]
  unexposed <- exp_dt[needs_expansion == FALSE]

  if (nrow(exposed) > 0) {
    unit_days <- switch(
      unit,
      "weeks" = 7,
      "months" = 30.4375,
      "quarters" = 91.3125,
      "years" = 365.25,
      1
    )

    exposed[, n_units := ceiling((exp_stop - exp_start + 1) / unit_days)]
    exposed[, period_id := .I]
    expanded <- exposed[rep(1:.N, n_units)]
    expanded[, unit_seq := seq_len(.N), by = period_id]

    expanded[, `:=`(
      unit_start = floor(exp_start + (unit_seq - 1) * unit_days),
      unit_stop = floor(exp_start + unit_seq * unit_days) - 1
    )]

    expanded[, is_last := (unit_seq == max(unit_seq)), by = period_id]
    expanded[is_last == TRUE, unit_stop := exp_stop]

    expanded[, `:=`(exp_start = unit_start, exp_stop = unit_stop)]
    expanded[, c("unit_start", "unit_stop", "n_units", "unit_seq",
                 "is_last", "period_id") := NULL]

    result <- rbindlist(list(expanded, unexposed), fill = TRUE)
  } else {
    result <- unexposed
  }

  result[, needs_expansion := NULL]
  setkey(result, id, exp_start)

  return(result)
}

#' Apply duration categories exposure definition
#' @keywords internal
apply_duration_impl <- function(exp_dt, reference, bytype, stub_name,
                                 keepvars, continuousunit, duration_cuts) {
  # First apply continuous logic
  exp_dt <- apply_continuous_impl(exp_dt, reference, bytype = FALSE, stub_name,
                                   keepvars, continuousunit, NULL, NULL)

  # Create duration categories
  exp_dt[, exp_duration := reference]

  for (i in seq_along(duration_cuts)) {
    if (i == 1) {
      exp_dt[tv_exp > 0 & tv_exp < duration_cuts[i],
             exp_duration := i]
    } else {
      exp_dt[tv_exp >= duration_cuts[i-1] & tv_exp < duration_cuts[i],
             exp_duration := i]
    }
  }

  exp_dt[tv_exp >= duration_cuts[length(duration_cuts)],
         exp_duration := length(duration_cuts) + 1]

  exp_dt[, exp_value := exp_duration]
  exp_dt[, c("tv_exp", "exp_duration") := NULL]

  # Collapse
  exp_dt[, period_group := rleid(id, exp_value)]

  keep_cols <- c("id", "exp_value")
  if (!is.null(keepvars)) {
    keep_cols <- c(keep_cols, keepvars)
  }
  keep_cols <- intersect(keep_cols, names(exp_dt))

  result <- exp_dt[, .(
    exp_start = min(exp_start),
    exp_stop = max(exp_stop),
    study_entry = first(study_entry),
    study_exit = first(study_exit)
  ), by = c("period_group", keep_cols)]

  result[, period_group := NULL]
  setkey(result, id, exp_start)

  return(result)
}

#' Apply recency exposure definition
#' @keywords internal
apply_recency_impl <- function(exp_dt, reference, bytype, stub_name,
                                keepvars, recency_cuts) {
  exp_dt[, last_exp_end := max(exp_stop[orig_exp_binary == 1]), by = id]

  # Calculate time since last exposure (in years)
  exp_dt[, years_since := (exp_start - last_exp_end) / 365.25]

  # Categorize
  exp_dt[, recency_cat := fcase(
    is.na(last_exp_end), as.integer(reference),
    orig_exp_binary == 1, 1L,
    default = NA_integer_
  )]

  # Apply cutpoints for former exposure
  for (i in seq_along(recency_cuts)) {
    if (i == 1) {
      exp_dt[!is.na(years_since) &
             years_since > 0 &
             years_since < recency_cuts[i],
             recency_cat := i + 1]
    } else {
      exp_dt[years_since >= recency_cuts[i-1] &
             years_since < recency_cuts[i],
             recency_cat := i + 1]
    }
  }

  exp_dt[years_since >= recency_cuts[length(recency_cuts)],
         recency_cat := length(recency_cuts) + 2]

  exp_dt[, exp_value := recency_cat]
  exp_dt[, c("last_exp_end", "years_since", "recency_cat") := NULL]

  # Collapse
  exp_dt[, period_group := rleid(id, exp_value)]

  keep_cols <- c("id", "exp_value")
  if (!is.null(keepvars)) {
    keep_cols <- c(keep_cols, keepvars)
  }
  keep_cols <- intersect(keep_cols, names(exp_dt))

  result <- exp_dt[, .(
    exp_start = min(exp_start),
    exp_stop = max(exp_stop),
    study_entry = first(study_entry),
    study_exit = first(study_exit)
  ), by = c("period_group", keep_cols)]

  result[, period_group := NULL]
  setkey(result, id, exp_start)

  return(result)
}

#' Add switching indicator
#' @keywords internal
add_switching_indicator_impl <- function(exp_dt, generate) {
  exp_value_col <- if ("exp_value" %in% names(exp_dt)) "exp_value" else generate

  exp_dt[, n_unique_exp := uniqueN(get(exp_value_col)), by = id]
  exp_dt[, has_switched := as.integer(n_unique_exp > 1)]
  exp_dt[, n_unique_exp := NULL]

  return(exp_dt)
}

#' Add switching detail pattern string
#' @keywords internal
add_switching_detail_impl <- function(exp_dt, generate) {
  exp_value_col <- if ("exp_value" %in% names(exp_dt)) "exp_value" else generate

  exp_dt[, prev_value := shift(get(exp_value_col), type = "lag"), by = id]
  exp_dt[, is_switch := (!is.na(prev_value) & get(exp_value_col) != prev_value)]

  switching_patterns <- exp_dt[, {
    vals <- unique(get(exp_value_col))
    pattern <- paste(vals, collapse = "->")
    .(switching_pattern = pattern)
  }, by = id]

  exp_dt <- merge(exp_dt, switching_patterns, by = "id", all.x = TRUE)
  exp_dt[, c("prev_value", "is_switch") := NULL]

  return(exp_dt)
}

#' Add cumulative time in current state
#' @keywords internal
add_statetime_impl <- function(exp_dt, generate) {
  exp_value_col <- if ("exp_value" %in% names(exp_dt)) "exp_value" else generate

  exp_dt[, `:=`(
    period_days = stop - start + 1,
    prev_value = shift(get(exp_value_col), type = "lag")
  ), by = id]

  exp_dt[, state_reset := (is.na(prev_value) | get(exp_value_col) != prev_value)]
  exp_dt[, state_group := cumsum(state_reset), by = id]

  exp_dt[, statetime := cumsum(period_days), by = .(id, state_group)]

  exp_dt[, c("period_days", "prev_value", "state_reset", "state_group") := NULL]

  return(exp_dt)
}

#' Check coverage diagnostics
#' @keywords internal
check_coverage_impl <- function(result_dt, master_dt) {
  coverage <- result_dt[, .(
    n_periods = .N,
    first_period_start = min(start),
    last_period_stop = max(stop),
    total_period_days = sum(stop - start + 1)
  ), by = id]

  master_summary <- master_dt[, .(
    id,
    study_entry,
    study_exit,
    expected_days = study_exit - study_entry + 1
  )]

  coverage <- merge(coverage, master_summary, by = "id", all = TRUE)

  coverage[, `:=`(
    coverage_gap = expected_days - total_period_days,
    pct_covered = 100 * total_period_days / expected_days
  )]

  return(as.data.frame(coverage))
}

#' Identify gaps in coverage
#' @keywords internal
identify_gaps_impl <- function(result_dt) {
  result_dt[, `:=`(
    next_start = shift(start, type = "lead"),
    period_end = stop
  ), by = id]

  gaps <- result_dt[!is.na(next_start) & next_start > period_end + 1,
                    .(id,
                      gap_start = period_end + 1,
                      gap_end = next_start - 1,
                      gap_days = next_start - period_end - 1)]

  result_dt[, c("next_start", "period_end") := NULL]

  return(as.data.frame(gaps))
}

#' Identify overlapping periods
#' @keywords internal
identify_overlaps_impl <- function(result_dt, generate) {
  result_dt[, `:=`(
    next_start = shift(start, type = "lead"),
    next_value = shift(get(generate), type = "lead")
  ), by = id]

  overlaps <- result_dt[!is.na(next_start) &
                        next_start <= stop,
                        .(id,
                          period1_start = start,
                          period1_stop = stop,
                          period1_value = get(generate),
                          period2_start = next_start,
                          period2_value = next_value,
                          overlap_days = stop - next_start + 1)]

  result_dt[, c("next_start", "next_value") := NULL]

  return(as.data.frame(overlaps))
}

#' Apply dose-based cumulative exposure definition
#' @description
#' Calculates cumulative dose over time, handling overlapping prescriptions
#' with proportional dose allocation. When prescriptions overlap, the dose
#' contribution for each day is calculated as the sum of the daily rates
#' of all active prescriptions.
#'
#' @param exp_dt data.table with exposure periods
#' @param reference Reference value (always 0 for dose)
#' @param keepvars Additional variables to keep
#' @param dosecuts Optional numeric vector of cutpoints for categorization
#' @param verbose Logical: print progress messages
#' @return data.table with cumulative dose
#' @keywords internal
apply_dose_impl <- function(exp_dt, reference, keepvars, dosecuts, verbose) {

  # Step 1: Calculate daily dose rate for each period
  exp_dt[, period_length := exp_stop - exp_start + 1]
  exp_dt[, daily_rate := exp_value / period_length]

  # Check for overlapping dose periods
  setkey(exp_dt, id, exp_start, exp_stop)
  exp_dt[, has_overlap := FALSE]
  exp_dt[, has_overlap := {
    if (.N > 1) {
      any(exp_start[-1] <= exp_stop[-.N])
    } else {
      FALSE
    }
  }, by = id]

  n_persons_with_overlap <- uniqueN(exp_dt[has_overlap == TRUE, id])

  if (n_persons_with_overlap > 0) {
    if (verbose) message(sprintf("  Processing %d persons with overlapping dose periods...",
                                 n_persons_with_overlap))

    # Separate persons with and without overlaps
    no_overlap_ids <- unique(exp_dt[has_overlap == FALSE, id])
    overlap_ids <- unique(exp_dt[has_overlap == TRUE, id])

    no_overlap_dt <- exp_dt[id %in% no_overlap_ids]
    overlap_dt <- exp_dt[id %in% overlap_ids]

    # Process overlapping persons: create segment-based dose calculation
    # Step 2: Collect all boundary points (starts and stops+1)
    boundaries_start <- overlap_dt[, .(boundary = exp_start), by = id]
    boundaries_stop <- overlap_dt[, .(boundary = exp_stop + 1), by = id]
    all_boundaries <- rbind(boundaries_start, boundaries_stop)
    all_boundaries <- unique(all_boundaries)
    setkey(all_boundaries, id, boundary)

    # Create segments from consecutive boundaries
    all_boundaries[, seg_start := boundary, by = id]
    all_boundaries[, seg_stop := shift(boundary, type = "lead") - 1, by = id]
    segments <- all_boundaries[!is.na(seg_stop) & seg_stop >= seg_start]
    segments[, boundary := NULL]

    # Step 3: For each segment, find overlapping original periods and sum daily rates
    # Cross-join segments with periods for same person
    segments[, seg_id := .I]
    setkey(segments, id)

    period_info <- overlap_dt[, .(id, orig_start = exp_start, orig_stop = exp_stop,
                                  daily_rate, study_entry, study_exit)]
    if (!is.null(keepvars)) {
      kv_cols <- intersect(keepvars, names(overlap_dt))
      if (length(kv_cols) > 0) {
        period_info <- overlap_dt[, c("id", "orig_start", "orig_stop", "daily_rate",
                                      "study_entry", "study_exit", kv_cols), with = FALSE]
      }
    }

    # Join segments with period info
    seg_period <- merge(segments, period_info, by = "id", allow.cartesian = TRUE)

    # Keep only where segment overlaps with original period
    seg_period <- seg_period[seg_start >= orig_start & seg_stop <= orig_stop]

    # Calculate segment dose: (segment_days) * sum(active daily_rates)
    seg_period[, seg_days := seg_stop - seg_start + 1]
    seg_dose <- seg_period[, .(
      dose_contribution = sum(daily_rate) * first(seg_days),
      study_entry = first(study_entry),
      study_exit = first(study_exit)
    ), by = .(id, seg_id, seg_start, seg_stop)]

    # Handle keepvars - take first value per segment
    if (!is.null(keepvars)) {
      kv_cols <- intersect(keepvars, names(seg_period))
      if (length(kv_cols) > 0) {
        kv_dt <- seg_period[, c("id", "seg_id", kv_cols), with = FALSE]
        kv_dt <- unique(kv_dt, by = c("id", "seg_id"))
        seg_dose <- merge(seg_dose, kv_dt, by = c("id", "seg_id"), all.x = TRUE)
      }
    }

    # Rename columns to match non-overlap format
    setnames(seg_dose, c("seg_start", "seg_stop", "dose_contribution"),
             c("exp_start", "exp_stop", "exp_value"))
    seg_dose[, seg_id := NULL]

    # For non-overlapping persons, just use original exp_value
    if (nrow(no_overlap_dt) > 0) {
      no_overlap_result <- no_overlap_dt[, .(id, exp_start, exp_stop, exp_value,
                                             study_entry, study_exit)]
      if (!is.null(keepvars)) {
        kv_cols <- intersect(keepvars, names(no_overlap_dt))
        if (length(kv_cols) > 0) {
          no_overlap_result <- no_overlap_dt[, c("id", "exp_start", "exp_stop", "exp_value",
                                                 "study_entry", "study_exit", kv_cols), with = FALSE]
        }
      }

      # Combine results
      result_dt <- rbind(no_overlap_result, seg_dose, fill = TRUE)
    } else {
      result_dt <- seg_dose
    }

  } else {
    if (verbose) message("  No overlapping dose periods found.")
    # No overlaps - just use original data
    result_dt <- exp_dt[, .(id, exp_start, exp_stop, exp_value, study_entry, study_exit)]
    if (!is.null(keepvars)) {
      kv_cols <- intersect(keepvars, names(exp_dt))
      if (length(kv_cols) > 0) {
        result_dt <- exp_dt[, c("id", "exp_start", "exp_stop", "exp_value",
                                "study_entry", "study_exit", kv_cols), with = FALSE]
      }
    }
  }

  # Step 4: Calculate cumulative dose as running sum
  setkey(result_dt, id, exp_start)
  result_dt[, cumul_dose := cumsum(exp_value), by = id]

  # Step 5: Apply categorization if dosecuts provided
  if (!is.null(dosecuts)) {
    if (verbose) message("  Categorizing cumulative dose...")
    n_cuts <- length(dosecuts)

    # Category 0: 0 cumulative dose (reference)
    # Category 1: >0 but < first cutpoint
    # Category 2..n: between cutpoints
    # Category n+1: >= last cutpoint
    result_dt[, dose_cat := 0L]
    result_dt[cumul_dose > 0 & cumul_dose < dosecuts[1], dose_cat := 1L]

    for (i in 2:n_cuts) {
      result_dt[cumul_dose >= dosecuts[i-1] & cumul_dose < dosecuts[i], dose_cat := as.integer(i)]
    }

    result_dt[cumul_dose >= dosecuts[n_cuts], dose_cat := as.integer(n_cuts + 1L)]

    # Create labels
    dose_labels <- c("No dose", paste0("<", dosecuts[1]))
    if (n_cuts > 1) {
      for (i in 2:n_cuts) {
        dose_labels <- c(dose_labels, paste0(dosecuts[i-1], "-<", dosecuts[i]))
      }
    }
    dose_labels <- c(dose_labels, paste0(dosecuts[n_cuts], "+"))

    result_dt[, exp_value := factor(dose_cat, levels = 0:(n_cuts+1), labels = dose_labels)]
    result_dt[, c("dose_cat", "cumul_dose") := NULL]

  } else {
    # Output is continuous cumulative dose
    result_dt[, exp_value := cumul_dose]
    result_dt[, cumul_dose := NULL]
  }

  # Collapse consecutive periods with same exp_value
  result_dt[, period_group := rleid(id, exp_value)]

  keep_cols <- c("id", "exp_value")
  if (!is.null(keepvars)) {
    keep_cols <- c(keep_cols, intersect(keepvars, names(result_dt)))
  }
  keep_cols <- intersect(keep_cols, names(result_dt))

  collapsed_dt <- result_dt[, .(
    exp_start = min(exp_start),
    exp_stop = max(exp_stop),
    study_entry = first(study_entry),
    study_exit = first(study_exit)
  ), by = c("period_group", keep_cols)]

  collapsed_dt[, period_group := NULL]

  setkey(collapsed_dt, id, exp_start)
  return(collapsed_dt)
}

#' Summarize exposure distribution
#' @keywords internal
summarize_exposure_impl <- function(result_dt, generate) {
  summary <- result_dt[, .(
    n_periods = .N,
    n_persons = uniqueN(id),
    total_days = sum(stop - start + 1),
    mean_period_days = mean(stop - start + 1),
    median_period_days = median(stop - start + 1)
  ), by = get(generate)]

  summary[, pct_person_time := 100 * total_days / sum(total_days)]

  setorder(summary, get)

  return(as.data.frame(summary))
}
