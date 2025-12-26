#' Integrate Outcome Events into Time-Varying Datasets
#'
#' @description
#' \code{tvevent} is the third and final step in the tvtools workflow. It integrates
#' outcome events and competing risks into time-varying datasets created by
#' tvexpose/tvmerge. The function resolves competing risks, splits intervals when
#' events occur mid-interval, adjusts continuous variables proportionally, and
#' creates event status flags.
#'
#' @param intervals_data Data frame containing the master dataset with time-varying
#'   intervals. Must have columns: id, start, stop (typically output from tvexpose/tvmerge).
#' @param events_data Data frame containing the events dataset with event dates.
#'   Must have columns: id, date (primary event), and optionally competing risk dates.
#' @param id String name of the ID column (must exist in both datasets).
#' @param date String name of the primary event date column in events_data.
#' @param compete Character vector of competing risk date column names in events_data.
#'   Default is NULL (no competing risks).
#' @param generate String name for the event indicator variable to create in output.
#'   Values: 0=censored, 1=primary event, 2+=competing events. Default is "_failure".
#' @param type String specifying event type: "single" (terminal, default) or "recurring".
#'   For single events, person-time is censored after first event.
#' @param keepvars Character vector of additional variables from events_data to merge
#'   into intervals where events occur. Default NULL keeps all non-id/date variables.
#' @param continuous Character vector of cumulative variables to adjust proportionally
#'   when intervals split (e.g., total dose, cumulative exposure days).
#' @param timegen String name for time duration variable to create. NULL (default)
#'   means don't create this variable.
#' @param timeunit String specifying time unit for timegen: "days" (default),
#'   "months" (days/30.4375), or "years" (days/365.25).
#' @param eventlabel Named character vector for custom event labels.
#'   E.g., c("0"="Censored", "1"="Myocardial Infarction", "2"="Death").
#'   Default uses variable labels from date/compete columns.
#' @param startvar String name of the start date column in intervals_data.
#'   Default is "start" (standard output from tvexpose/tvmerge).
#' @param stopvar String name of the stop date column in intervals_data.
#'   Default is "stop" (standard output from tvexpose/tvmerge).
#' @param replace Logical; if TRUE, replace generate/timegen variables if they exist.
#'   Default is FALSE (error if variables exist).
#'
#' @return A list of class "tvevent" containing:
#'   \item{data}{Modified intervals_data with event flags and adjusted variables}
#'   \item{N}{Total number of observations (intervals) in result}
#'   \item{N_events}{Number of intervals flagged with events (generate > 0)}
#'   \item{generate}{Name of the event indicator variable}
#'   \item{type}{Event type used ("single" or "recurring")}
#'
#' @details
#' The tvevent algorithm performs these steps:
#' \enumerate{
#'   \item Resolves competing risks: for each person, the earliest event date wins
#'   \item Identifies split points: events occurring strictly within intervals (start < event < stop)
#'   \item Splits intervals: creates two intervals at each split point (one ending at event, one starting at event)
#'   \item Adjusts continuous variables: proportional to new duration / original duration
#'   \item Merges event flags: matches events where interval stop equals event date
#'   \item Applies labels: creates factor with event type labels
#'   \item Type-specific logic: for "single" events, drops all follow-up after first event
#'   \item Generates time variable: calculates interval duration in requested units
#' }
#'
#' For single events (type="single"), the first event is terminal - all person-time
#' after the first event is dropped. For recurring events (type="recurring"), all
#' intervals are retained allowing multiple events per person.
#'
#' Continuous variables (specified in continuous parameter) represent cumulative
#' quantities over an interval (e.g., total medication dose). When intervals split,
#' these are adjusted proportionally: new_value = old_value * (new_duration / old_duration).
#' This preserves both the rate (dose/day) and the total sum across all intervals.
#'
#' @examples
#' \dontrun{
#' # Basic usage with single event
#' result <- tvevent(
#'   intervals_data = tv_exposure,
#'   events_data = outcomes,
#'   id = "person_id",
#'   date = "mi_date",
#'   generate = "mi_status",
#'   type = "single"
#' )
#'
#' # With competing risks
#' result <- tvevent(
#'   intervals_data = tv_exposure,
#'   events_data = outcomes,
#'   id = "person_id",
#'   date = "mi_date",
#'   compete = c("death_date", "emigration_date"),
#'   generate = "outcome",
#'   timegen = "followup_years",
#'   timeunit = "years"
#' )
#'
#' # Recurring events with dose adjustment
#' result <- tvevent(
#'   intervals_data = tv_exposure,
#'   events_data = hospitalizations,
#'   id = "person_id",
#'   date = "hosp_date",
#'   type = "recurring",
#'   continuous = c("cumulative_dose", "total_exposure_days"),
#'   timegen = "interval_days",
#'   timeunit = "days"
#' )
#'
#' # Use result for survival analysis
#' library(survival)
#' survdata <- result$data
#' cox_model <- coxph(Surv(followup_years, outcome == 1) ~ exposure + age, data = survdata)
#' }
#'
#' @export
tvevent <- function(
  intervals_data,
  events_data,
  id,
  date,
  compete = NULL,
  generate = "_failure",
  type = "single",
  keepvars = NULL,
  continuous = NULL,
  timegen = NULL,
  timeunit = "days",
  eventlabel = NULL,
  startvar = "start",
  stopvar = "stop",
  replace = FALSE
) {

  # Load required packages
  if (!requireNamespace("dplyr", quietly = TRUE)) {
    stop("Package 'dplyr' is required but not installed")
  }
  library(dplyr)

  # ============================================================================
  # PHASE 1: Parameter Validation
  # ============================================================================

  # Check type parameter
  type <- tolower(type)
  if (!type %in% c("single", "recurring")) {
    stop(sprintf(
      "type must be either 'single' or 'recurring', got: '%s'\n  single: first event is terminal (default)\n  recurring: allows multiple events",
      type
    ))
  }

  # Check timeunit parameter
  timeunit <- tolower(timeunit)
  if (!timeunit %in% c("days", "months", "years")) {
    stop(sprintf(
      "timeunit must be 'days', 'months', or 'years', got: '%s'",
      timeunit
    ))
  }

  # Validate data frames
  if (!is.data.frame(intervals_data)) {
    stop("intervals_data must be a data frame")
  }
  if (!is.data.frame(events_data)) {
    stop("events_data must be a data frame")
  }

  # Check for zero-length inputs
  if (nrow(intervals_data) == 0) {
    stop("intervals_data has no rows")
  }
  if (nrow(events_data) == 0) {
    warning("events_data has no rows - all intervals will be censored")
    intervals_data[[generate]] <- 0L
    attr(intervals_data[[generate]], "label") <- "Event Status"

    if (!is.null(timegen)) {
      days_diff <- as.numeric(intervals_data[[stopvar]] - intervals_data[[startvar]])
      if (timeunit == "days") {
        intervals_data[[timegen]] <- days_diff
      } else if (timeunit == "months") {
        intervals_data[[timegen]] <- days_diff / 30.4375
      } else if (timeunit == "years") {
        intervals_data[[timegen]] <- days_diff / 365.25
      }
    }

    result <- list(
      data = intervals_data,
      N = nrow(intervals_data),
      N_events = 0,
      generate = generate,
      type = type
    )
    class(result) <- c("tvevent", "list")
    return(result)
  }

  # ============================================================================
  # PHASE 2: Master Dataset Validation (intervals_data)
  # ============================================================================

  # Required columns from tvexpose/tvmerge
  required_cols <- c(id, startvar, stopvar)
  missing_cols <- setdiff(required_cols, names(intervals_data))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "intervals_data missing required columns: %s\n  (tvevent requires output from tvexpose/tvmerge with start/stop columns, or specify startvar/stopvar)",
      paste(missing_cols, collapse=", ")
    ))
  }

  # Validate continuous variables
  if (!is.null(continuous)) {
    missing_cont <- setdiff(continuous, names(intervals_data))
    if (length(missing_cont) > 0) {
      stop(sprintf(
        "Continuous variables not found in intervals_data: %s",
        paste(missing_cont, collapse=", ")
      ))
    }

    # Check that continuous vars are numeric
    non_numeric <- continuous[!sapply(intervals_data[continuous], is.numeric)]
    if (length(non_numeric) > 0) {
      stop(sprintf(
        "Continuous variables must be numeric: %s",
        paste(non_numeric, collapse=", ")
      ))
    }
  }

  # Check replace option
  if (!replace) {
    if (generate %in% names(intervals_data)) {
      stop(sprintf(
        "Variable '%s' already exists in intervals_data. Use replace=TRUE to overwrite.",
        generate
      ))
    }
    if (!is.null(timegen) && timegen %in% names(intervals_data)) {
      stop(sprintf(
        "Variable '%s' already exists in intervals_data. Use replace=TRUE to overwrite.",
        timegen
      ))
    }
  } else {
    # Drop existing variables if replace=TRUE
    intervals_data[[generate]] <- NULL
    if (!is.null(timegen)) {
      intervals_data[[timegen]] <- NULL
    }
  }

  # Validate interval structure (allow single-day intervals where start == stop)
  if (any(intervals_data[[startvar]] > intervals_data[[stopvar]], na.rm = TRUE)) {
    stop("intervals_data contains invalid intervals where start > stop")
  }

  # ============================================================================
  # PHASE 3: Using Dataset Validation (events_data)
  # ============================================================================

  # Check ID column exists
  if (!id %in% names(events_data)) {
    stop(sprintf("ID variable '%s' not found in events_data", id))
  }

  # Check date column exists
  if (!date %in% names(events_data)) {
    stop(sprintf("Date variable '%s' not found in events_data", date))
  }

  # Date must be numeric/Date
  if (!is.numeric(events_data[[date]]) && !inherits(events_data[[date]], "Date")) {
    stop(sprintf("Date variable '%s' must be numeric or Date type", date))
  }

  # Check competing risk variables
  if (!is.null(compete)) {
    missing_compete <- setdiff(compete, names(events_data))
    if (length(missing_compete) > 0) {
      stop(sprintf(
        "Competing event variables not found in events_data: %s",
        paste(missing_compete, collapse=", ")
      ))
    }

    # Check competing vars are numeric/Date
    for (comp_var in compete) {
      if (!is.numeric(events_data[[comp_var]]) && !inherits(events_data[[comp_var]], "Date")) {
        stop(sprintf("Competing variable '%s' must be numeric or Date type", comp_var))
      }
    }
  }

  # Handle keepvars - default to all vars except id, date, compete
  if (is.null(keepvars)) {
    keepvars <- setdiff(
      names(events_data),
      c(id, date, compete)
    )
  } else {
    # Validate specified keepvars exist
    missing_keep <- setdiff(keepvars, names(events_data))
    if (length(missing_keep) > 0) {
      stop(sprintf(
        "keepvars not found in events_data: %s",
        paste(missing_keep, collapse=", ")
      ))
    }
  }

  # ============================================================================
  # STEP 1: Prepare Events Dataset - Resolve Competing Risks
  # ============================================================================

  # Strip haven class attributes to prevent issues
  for (col in names(intervals_data)) {
    if (inherits(intervals_data[[col]], "haven_labelled")) {
      intervals_data[[col]] <- as.vector(intervals_data[[col]])
    }
  }
  for (col in names(events_data)) {
    if (inherits(events_data[[col]], "haven_labelled")) {
      events_data[[col]] <- as.vector(events_data[[col]])
    }
  }

  # Create working copy of events data
  events_work <- events_data %>%
    dplyr::select(dplyr::all_of(c(id, date, compete, keepvars)))

  # Floor all dates to day precision (Stata behavior)
  events_work[[date]] <- floor(as.numeric(events_work[[date]]))

  # Initialize effective date and type
  events_work$eff_date <- events_work[[date]]
  events_work$eff_type <- ifelse(is.na(events_work[[date]]), NA_integer_, 1L)

  # Capture variable labels for eventlabel defaults
  date_label <- attr(events_data[[date]], "label")
  if (is.null(date_label) || date_label == "") {
    date_label <- sprintf("Event: %s", date)
  }

  compete_labels <- list()
  if (!is.null(compete)) {
    for (i in seq_along(compete)) {
      comp_var <- compete[i]

      # Floor competing dates
      events_work[[comp_var]] <- floor(as.numeric(events_work[[comp_var]]))

      # Capture label
      comp_label <- attr(events_data[[comp_var]], "label")
      if (is.null(comp_label) || comp_label == "") {
        comp_label <- sprintf("Competing: %s", comp_var)
      }
      compete_labels[[i]] <- comp_label

      # Update effective date/type if this competing date is earlier
      is_earlier <- !is.na(events_work[[comp_var]]) &
                    (events_work[[comp_var]] < events_work$eff_date |
                     is.na(events_work$eff_date))

      events_work$eff_type <- ifelse(is_earlier, i + 1L, events_work$eff_type)
      events_work$eff_date <- ifelse(is_earlier, events_work[[comp_var]], events_work$eff_date)
    }
  }

  # Keep only observations with valid event dates
  events_work <- events_work %>%
    dplyr::filter(!is.na(eff_date))

  # If events_data is now empty, warn and return all censored
  if (nrow(events_work) == 0) {
    warning("No valid event dates found after competing risk resolution")
    intervals_data[[generate]] <- factor(0, levels = 0, labels = "Censored")
    attr(intervals_data[[generate]], "label") <- "Event Status"

    if (!is.null(timegen)) {
      days_diff <- as.numeric(intervals_data[[stopvar]] - intervals_data[[startvar]])
      if (timeunit == "days") {
        intervals_data[[timegen]] <- days_diff
      } else if (timeunit == "months") {
        intervals_data[[timegen]] <- days_diff / 30.4375
      } else if (timeunit == "years") {
        intervals_data[[timegen]] <- days_diff / 365.25
      }
    }

    result <- list(
      data = intervals_data,
      N = nrow(intervals_data),
      N_events = 0,
      generate = generate,
      type = type
    )
    class(result) <- c("tvevent", "list")
    return(result)
  }

  # Drop original date columns, rename effective date
  events_work <- events_work %>%
    dplyr::select(-dplyr::all_of(c(date, compete))) %>%
    dplyr::rename(!!date := eff_date,
                  event_type = eff_type)

  # Remove duplicate events for same person-date
  events_work <- events_work %>%
    dplyr::distinct(dplyr::across(dplyr::all_of(c(id, date))), .keep_all = TRUE)

  # ============================================================================
  # STEP 2: Identify Split Points
  # ============================================================================

  # Create minimal interval structure for join
  intervals_minimal <- intervals_data %>%
    dplyr::select(dplyr::all_of(c(id, startvar, stopvar))) %>%
    dplyr::distinct()

  # Join intervals with events (Stata: joinby)
  split_candidates <- intervals_minimal %>%
    dplyr::inner_join(
      events_work %>% dplyr::select(dplyr::all_of(c(id, date))),
      by = id,
      relationship = "many-to-many"
    )

  # Keep only events occurring STRICTLY within intervals
  splits_needed <- split_candidates %>%
    dplyr::filter(get(date) > get(startvar) & get(date) < get(stopvar)) %>%
    dplyr::select(dplyr::all_of(c(id, date))) %>%
    dplyr::distinct()

  n_splits <- nrow(splits_needed)
  message(sprintf("Splitting intervals for %d internal events...", n_splits))

  # ============================================================================
  # STEP 3: Execute Splits and Adjust Continuous Variables
  # ============================================================================

  # Store original duration for continuous adjustment
  intervals_data$orig_dur <- as.numeric(intervals_data[[stopvar]] - intervals_data[[startvar]])

  if (n_splits > 0) {
    # First identify which unique intervals need splitting (at any date)
    # This prevents keeping duplicate rows when an interval has multiple event dates
    intervals_to_split <- intervals_data %>%
      dplyr::inner_join(splits_needed, by = id, relationship = "many-to-many") %>%
      dplyr::filter(get(date) > get(startvar) & get(date) < get(stopvar)) %>%
      dplyr::select(dplyr::all_of(c(id, startvar, stopvar))) %>%
      dplyr::distinct()

    # Mark intervals that need splitting
    intervals_data <- intervals_data %>%
      dplyr::left_join(
        intervals_to_split %>% dplyr::mutate(will_split = TRUE),
        by = c(id, startvar, stopvar)
      ) %>%
      dplyr::mutate(will_split = ifelse(is.na(will_split), FALSE, will_split))

    # Separate non-split and split intervals
    non_split_intervals <- intervals_data %>%
      dplyr::filter(!will_split) %>%
      dplyr::select(-will_split)

    # For intervals that need splitting, join with their split points
    split_rows <- intervals_data %>%
      dplyr::filter(will_split) %>%
      dplyr::select(-will_split) %>%
      dplyr::inner_join(splits_needed, by = id, relationship = "many-to-many") %>%
      dplyr::filter(get(date) > get(startvar) & get(date) < get(stopvar))

    if (nrow(split_rows) > 0) {
      # Check if start/stop columns are Date type BEFORE mutate
      start_is_date <- inherits(split_rows[[startvar]], "Date")

      # Convert the date column to match start/stop type
      if (start_is_date) {
        split_rows[[date]] <- as.Date(split_rows[[date]], origin = "1970-01-01")
      } else {
        split_rows[[date]] <- as.numeric(split_rows[[date]])
      }

      # First copy: end at event date
      split_rows_pre <- split_rows %>%
        dplyr::mutate(
          !!rlang::sym(stopvar) := get(date)
        )

      # Second copy: start at event date
      split_rows_post <- split_rows %>%
        dplyr::mutate(
          !!rlang::sym(startvar) := get(date)
        )

      # Combine: non-split intervals + both halves of split intervals
      intervals_data <- dplyr::bind_rows(
        non_split_intervals,
        split_rows_pre %>% dplyr::select(-dplyr::all_of(date)),
        split_rows_post %>% dplyr::select(-dplyr::all_of(date))
      ) %>%
        dplyr::arrange(dplyr::across(dplyr::all_of(c(id, startvar, stopvar))))

      # Remove duplicates
      intervals_data <- intervals_data %>%
        dplyr::distinct(dplyr::across(dplyr::all_of(c(id, startvar, stopvar))), .keep_all = TRUE)
    } else {
      # No splits actually needed, use non-split intervals
      intervals_data <- non_split_intervals
    }
  }

  # Adjust continuous variables proportionally
  if (!is.null(continuous)) {
    intervals_data <- intervals_data %>%
      dplyr::mutate(
        new_dur = as.numeric(stop - start),
        ratio = ifelse(orig_dur == 0 | new_dur == 0, 1, new_dur / orig_dur)
      )

    # Multiply each continuous variable by ratio
    for (cont_var in continuous) {
      intervals_data[[cont_var]] <- intervals_data[[cont_var]] * intervals_data$ratio
    }

    intervals_data <- intervals_data %>%
      dplyr::select(-new_dur, -ratio)
  }

  # Drop original duration tracking variable
  intervals_data <- intervals_data %>%
    dplyr::select(-orig_dur)

  # ============================================================================
  # STEP 4: Merge Event Flags
  # ============================================================================

  # Create match variable (stop date)
  intervals_data$match_date <- as.numeric(intervals_data[[stopvar]])

  # Prepare events for merging
  events_for_merge <- events_work %>%
    dplyr::mutate(match_date = get(date)) %>%
    dplyr::select(-dplyr::all_of(date))

  # Left join on id + match_date
  intervals_data <- intervals_data %>%
    dplyr::left_join(
      events_for_merge %>% dplyr::select(dplyr::all_of(c(id, "match_date", "event_type", keepvars))),
      by = c(id, "match_date"),
      relationship = "many-to-one",
      suffix = c("", "_event")
    )

  # Create failure indicator
  intervals_data[[generate]] <- ifelse(
    is.na(intervals_data$event_type),
    0L,
    as.integer(intervals_data$event_type)
  )

  # Clean up temporary variables
  intervals_data <- intervals_data %>%
    dplyr::select(-match_date, -event_type)

  # ============================================================================
  # STEP 5: Apply Type-Specific Logic (Single vs Recurring)
  # Note: Must be done BEFORE factor conversion since we need numeric values
  # ============================================================================

  if (type == "single") {
    # Find first event per person
    intervals_data <- intervals_data %>%
      dplyr::arrange(dplyr::across(dplyr::all_of(c(id, stopvar)))) %>%
      dplyr::group_by(dplyr::across(dplyr::all_of(id))) %>%
      dplyr::mutate(
        event_rank = cumsum(get(generate) > 0)
      ) %>%
      dplyr::ungroup()

    # Find time of first failure
    intervals_data <- intervals_data %>%
      dplyr::mutate(
        censor_time = ifelse(get(generate) > 0 & event_rank == 1,
                             as.numeric(get(stopvar)), NA_real_)
      ) %>%
      dplyr::group_by(dplyr::across(dplyr::all_of(id))) %>%
      dplyr::mutate(
        first_fail = min(censor_time, na.rm = TRUE)
      ) %>%
      dplyr::ungroup()

    # Drop intervals starting at or after first failure
    intervals_data <- intervals_data %>%
      dplyr::filter(is.na(first_fail) | is.infinite(first_fail) | as.numeric(get(startvar)) < first_fail)

    # Reset failure flag for any subsequent events (after first)
    intervals_data <- intervals_data %>%
      dplyr::mutate(
        !!rlang::sym(generate) := ifelse(event_rank > 1, 0L, get(generate))
      )

    # Clean up temporary variables
    intervals_data <- intervals_data %>%
      dplyr::select(-event_rank, -censor_time, -first_fail)

    message("Single event type: Censored person-time after first event.")

  } else {
    # type == "recurring"
    message("Recurring event type: Retained all person-time.")
  }

  # ============================================================================
  # STEP 6: Apply Event Labels
  # ============================================================================

  # Build default labels
  labels <- c("0" = "Censored", "1" = date_label)

  # Add competing risk labels
  if (!is.null(compete)) {
    for (i in seq_along(compete_labels)) {
      labels[as.character(i + 1)] <- compete_labels[[i]]
    }
  }

  # Override with user-specified eventlabel
  if (!is.null(eventlabel)) {
    if (is.null(names(eventlabel))) {
      stop("eventlabel must be a named vector (e.g., c('0'='Censored', '1'='Event'))")
    }

    # Merge user labels
    for (val in names(eventlabel)) {
      labels[val] <- eventlabel[val]
    }
  }

  # Convert to factor with labels
  present_vals <- sort(unique(intervals_data[[generate]]))
  present_labels <- labels[as.character(present_vals)]

  # Create factor
  intervals_data[[generate]] <- factor(
    intervals_data[[generate]],
    levels = present_vals,
    labels = present_labels
  )

  # Add variable label attribute
  attr(intervals_data[[generate]], "label") <- "Event Status"

  # ============================================================================
  # STEP 7: Generate Time Duration Variable (Optional)
  # ============================================================================

  if (!is.null(timegen)) {
    # Calculate duration in days
    days_diff <- as.numeric(intervals_data[[stopvar]] - intervals_data[[startvar]])

    # Convert to requested unit
    if (timeunit == "days") {
      intervals_data[[timegen]] <- days_diff
      attr(intervals_data[[timegen]], "label") <- "Time (days)"

    } else if (timeunit == "months") {
      # Stata: days / 30.4375 (average days per month)
      intervals_data[[timegen]] <- days_diff / 30.4375
      attr(intervals_data[[timegen]], "label") <- "Time (months)"

    } else if (timeunit == "years") {
      # Stata: days / 365.25 (accounting for leap years)
      intervals_data[[timegen]] <- days_diff / 365.25
      attr(intervals_data[[timegen]], "label") <- "Time (years)"
    }
  }

  # ============================================================================
  # STEP 8: Final Formatting and Output
  # ============================================================================

  # Ensure Date class for start/stop
  if (!inherits(intervals_data[[startvar]], "Date")) {
    intervals_data[[startvar]] <- as.Date(intervals_data[[startvar]], origin = "1970-01-01")
  }
  if (!inherits(intervals_data[[stopvar]], "Date")) {
    intervals_data[[stopvar]] <- as.Date(intervals_data[[stopvar]], origin = "1970-01-01")
  }

  # Sort by id, start, stop
  intervals_data <- intervals_data %>%
    dplyr::arrange(dplyr::across(dplyr::all_of(c(id, startvar, stopvar))))

  # Calculate summary statistics
  n_total <- nrow(intervals_data)
  n_failures <- sum(as.integer(intervals_data[[generate]]) > 0)

  # Display summary
  cat("\n")
  cat(strrep("-", 50), "\n")
  cat("Event integration complete\n")
  cat(sprintf("  Observations: %d\n", n_total))
  cat(sprintf("  Events flagged (%s): %d\n", generate, n_failures))
  cat(sprintf("  Variable %s labels:\n", generate))

  # Display label frequencies
  label_table <- table(intervals_data[[generate]])
  for (i in seq_along(label_table)) {
    cat(sprintf("    %s = %s (n=%d)\n",
                names(label_table)[i],
                names(label_table)[i],
                label_table[i]))
  }
  cat(strrep("-", 50), "\n")

  # Return result with attributes
  result <- list(
    data = intervals_data,
    N = n_total,
    N_events = n_failures,
    generate = generate,
    type = type
  )

  class(result) <- c("tvevent", "list")
  return(result)
}


#' Print Method for tvevent Objects
#'
#' @param x An object of class "tvevent"
#' @param ... Additional arguments (unused)
#'
#' @export
print.tvevent <- function(x, ...) {
  cat("\ntvevent Result\n")
  cat(strrep("=", 50), "\n")
  cat(sprintf("Total observations: %d\n", x$N))
  cat(sprintf("Events flagged: %d\n", x$N_events))
  cat(sprintf("Event variable: %s\n", x$generate))
  cat(sprintf("Event type: %s\n", x$type))
  cat(strrep("=", 50), "\n")
  cat("\nFirst few rows of data:\n")
  print(head(x$data, 10))
  cat("\nUse $data to access the full dataset\n")
  invisible(x)
}


#' Summary Method for tvevent Objects
#'
#' @param object An object of class "tvevent"
#' @param ... Additional arguments (unused)
#'
#' @export
summary.tvevent <- function(object, ...) {
  cat("\ntvevent Summary\n")
  cat(strrep("=", 50), "\n")
  cat(sprintf("Total observations: %d\n", object$N))
  cat(sprintf("Events flagged: %d (%.1f%%)\n",
              object$N_events,
              100 * object$N_events / object$N))
  cat(sprintf("Event variable: %s\n", object$generate))
  cat(sprintf("Event type: %s\n", object$type))
  cat("\nEvent distribution:\n")
  print(table(object$data[[object$generate]]))
  cat(strrep("=", 50), "\n")
  invisible(object)
}
