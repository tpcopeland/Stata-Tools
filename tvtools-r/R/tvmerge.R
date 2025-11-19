#' Merge multiple time-varying exposure datasets
#'
#' @title Merge Multiple Time-Varying Exposure Datasets
#'
#' @description
#' Merges multiple time-varying exposure datasets created by \code{\link{tvexpose}}. The function
#' is designed to work specifically with the output from \code{tvexpose}, combining multiple
#' exposure variables into a single dataset with synchronized time periods.
#'
#' \strong{CRITICAL PREREQUISITE}: \code{tvmerge} requires that each input dataset has already
#' been processed by \code{tvexpose}. You cannot use \code{tvmerge} directly on raw exposure files.
#'
#' The typical workflow is:
#' \enumerate{
#'   \item Load cohort data and run \code{tvexpose} on first exposure dataset, save result
#'   \item Load cohort data and run \code{tvexpose} on second exposure dataset, save result
#'   \item Run \code{tvmerge} on the saved \code{tvexpose} outputs
#' }
#'
#' Unlike standard data frame merging, \code{tvmerge} performs time-interval matching rather
#' than simple key-based matching. It identifies temporal overlaps between the \code{tvexpose}
#' outputs and creates new time intervals representing the intersections of exposure periods.
#' The function creates all possible overlapping combinations between datasets (Cartesian product).
#'
#' \strong{Exposure types}: \code{tvmerge} handles two types of exposures:
#' \itemize{
#'   \item \strong{Categorical exposures} (default): Creates Cartesian product of all exposure
#'         combinations. Each unique combination of exposure values across datasets becomes a
#'         separate period.
#'   \item \strong{Continuous exposures}: Treats exposure as a rate per day and calculates
#'         period-specific exposure. For continuous exposures, two variables are created: one
#'         for the rate and one for the period-specific exposure amount.
#' }
#'
#' @param datasets A list of data frames or file paths to datasets. Each dataset must contain
#'   the specified id, start, stop, and exposure variables. Each should be the output from
#'   \code{\link{tvexpose}}. Provide at least 2 datasets.
#' @param id Character string specifying the person identifier variable name that must exist in
#'   all datasets with identical names. This variable links records across datasets.
#' @param start Character vector specifying the start date variable names for all datasets,
#'   listed in the same order as the datasets. Must have length equal to the number of datasets.
#' @param stop Character vector specifying the stop date variable names for all datasets,
#'   listed in the same order as the datasets. Must have length equal to the number of datasets.
#' @param exposure Character vector specifying the exposure variable names for all datasets,
#'   listed in the same order as the datasets. Must have length equal to the number of datasets.
#' @param continuous Character vector or numeric vector specifying which exposures should be
#'   treated as continuous (rates per day) rather than categorical. You can specify either
#'   variable names or dataset positions (1, 2, 3, etc.). For continuous exposures, two
#'   variables are created: \code{varname} containing the rate per day and
#'   \code{varname_period} containing the exposure amount for that specific time period.
#'   Default: \code{NULL}.
#' @param generate Character vector specifying new names for exposure variables in the output
#'   dataset. Provide exactly one name per dataset, in the same order as the datasets. This
#'   option is mutually exclusive with \code{prefix}. Default: \code{NULL}.
#' @param prefix Character string to add as a prefix to all exposure variable names in the
#'   output. For example, \code{prefix = "exp_"} would create variables named exp_1, exp_2, etc.
#'   This option is mutually exclusive with \code{generate}. Default: \code{NULL}.
#' @param startname Character string specifying the name for the start date variable in the
#'   output dataset. Default: "start".
#' @param stopname Character string specifying the name for the stop date variable in the
#'   output dataset. Default: "stop".
#' @param dateformat Character string specifying the date format to apply to the output start
#'   and stop date variables. Any valid R date format may be used. Default: "\%Y-\%m-\%d".
#' @param saveas Character string specifying filename to save the merged dataset. Include the
#'   file extension (e.g., .csv, .rds, .rda). Use with \code{replace = TRUE} to overwrite an
#'   existing file. Default: \code{NULL}.
#' @param replace Logical. Allows \code{saveas} to overwrite an existing file. Default: \code{FALSE}.
#' @param keep Character vector specifying additional variables to keep from the source datasets.
#'   These variables are included in the output dataset with _ds# suffixes (where # is the
#'   dataset number) to distinguish variables from different sources. For example, if you specify
#'   \code{keep = "dose"}, the output will contain dose_ds1, dose_ds2, and so on. The ID variable,
#'   start and stop date variables, and exposure variables are always kept and do not receive
#'   suffixes. Default: \code{NULL}.
#' @param check Logical. Display coverage diagnostics including the number of persons, average
#'   periods per person, maximum periods per person, and total merged intervals. Default: \code{FALSE}.
#' @param validate_coverage Logical. Checks for gaps in person-time coverage. Gaps larger than
#'   1 day are reported. This is useful for ensuring that your merge has not inadvertently
#'   created discontinuous exposure histories. Any gaps found are listed showing the ID, start
#'   and stop dates, and gap size. Default: \code{FALSE}.
#' @param validate_overlap Logical. Checks for unexpected overlapping periods within the same
#'   person. Overlaps occur when a period starts before the previous period ends. Any overlaps
#'   found are listed showing the ID and the overlapping periods. This can indicate data quality
#'   issues or unintended merge results. Default: \code{FALSE}.
#' @param summarize Logical. Display summary statistics (min, max, mean, percentiles) for the
#'   start and stop date variables in the merged output dataset. Default: \code{FALSE}.
#'
#' @return A data frame containing the merged time-varying exposure data. The output includes:
#'   \itemize{
#'     \item The person identifier variable (specified in \code{id})
#'     \item Start and stop date variables (named according to \code{startname} and \code{stopname})
#'     \item Exposure variables for each dataset (named according to \code{generate} or \code{prefix},
#'           or defaulting to exp1, exp2, etc.)
#'     \item For continuous exposures: both the rate variable and the _period variable
#'     \item Any additional variables specified in \code{keep}, with _ds# suffixes
#'   }
#'
#'   The function also returns the following attributes accessible via \code{attr()}:
#'   \itemize{
#'     \item \code{n_datasets}: Number of datasets merged
#'     \item \code{n_persons}: Number of unique persons
#'     \item \code{mean_periods}: Mean periods per person
#'     \item \code{max_periods}: Maximum periods for any person
#'     \item \code{exposure_vars}: Names of exposure variables in output
#'     \item \code{continuous_vars}: Names of continuous exposure variables (if \code{continuous} used)
#'     \item \code{categorical_vars}: Names of categorical exposure variables
#'     \item \code{startname}: Name of start date variable in output
#'     \item \code{stopname}: Name of stop date variable in output
#'   }
#'
#' @details
#' \strong{Understanding merge strategies}
#'
#' The merge creates all possible combinations of overlapping periods (Cartesian product). For example,
#' if person 1 has two HRT periods that overlap with three DMT periods, the merge will produce six
#' output records representing all combinations.
#'
#' \strong{Time period validity}
#'
#' All input datasets must have valid time periods where start < stop. Records with invalid periods
#' (start >= stop) are automatically excluded with a warning message. Point-in-time observations
#' (where start = stop) are valid; for example, lab measurements or clinic visits that occur on a
#' single day.
#'
#' \strong{Missing values}
#'
#' Missing exposure values are retained by default and appear in the output dataset. Missing date
#' values will cause records to be excluded (they cannot define valid time periods).
#'
#' \strong{Variable naming and suffixes}
#'
#' When using \code{keep}, additional variables from different source datasets receive _ds# suffixes
#' (where # is 1, 2, 3, etc., corresponding to the dataset order). This prevents naming conflicts when
#' the same variable name appears in multiple datasets. The ID variable is not suffixed because it
#' represents the same entity across all datasets. The output start and stop date variables are not
#' suffixed because they represent the merged time intervals, not source-specific values. Exposure
#' variables are renamed according to \code{generate}, \code{prefix}, or default names (exp1, exp2, etc.).
#'
#' \strong{Performance considerations}
#'
#' Cartesian merges with multiple datasets can produce very large output datasets, especially when
#' individuals have many overlapping exposure periods. The command is optimized for efficiency but
#' may take several seconds to minutes for large datasets with complex exposure patterns.
#'
#' @examples
#' \dontrun{
#' # Example 1: Basic two-dataset merge
#' # First, create time-varying datasets from the raw exposure files
#' library(dplyr)
#'
#' cohort <- read.csv("cohort.csv")
#' hrt <- read.csv("hrt.csv")
#' dmt <- read.csv("dmt.csv")
#'
#' # Create time-varying HRT dataset
#' tv_hrt <- tvexpose(
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
#' # Create time-varying DMT dataset
#' tv_dmt <- tvexpose(
#'   master = cohort,
#'   exposure_data = dmt,
#'   id = "id",
#'   start = "dmt_start",
#'   stop = "dmt_stop",
#'   exposure = "dmt",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit"
#' )
#'
#' # Now merge the two time-varying datasets
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dmt),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "tv_exposure")
#' )
#'
#' # Example 2: Merge with custom variable names
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dmt),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "tv_exposure"),
#'   generate = c("hrt", "dmt_type"),
#'   startname = "period_start",
#'   stopname = "period_end"
#' )
#'
#' # Example 3: Keep additional covariates from tvexpose outputs
#' # When running tvexpose, use keepvars to bring covariates in
#' tv_hrt <- tvexpose(
#'   master = cohort,
#'   exposure_data = hrt,
#'   id = "id",
#'   start = "rx_start",
#'   stop = "rx_stop",
#'   exposure = "hrt_type",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   keepvars = c("age", "female")
#' )
#'
#' tv_dmt <- tvexpose(
#'   master = cohort,
#'   exposure_data = dmt,
#'   id = "id",
#'   start = "dmt_start",
#'   stop = "dmt_stop",
#'   exposure = "dmt",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   keepvars = c("mstype", "edss_baseline")
#' )
#'
#' # Merge and keep the covariates from both datasets
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dmt),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "tv_exposure"),
#'   keep = c("age", "female", "mstype", "edss_baseline"),
#'   generate = c("hrt", "dmt_type")
#' )
#' # Output includes age_ds1, female_ds1, mstype_ds2, edss_baseline_ds2
#'
#' # Example 4: Diagnostics and validation
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dmt),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "tv_exposure"),
#'   check = TRUE,
#'   validate_coverage = TRUE,
#'   validate_overlap = TRUE,
#'   summarize = TRUE
#' )
#'
#' # Example 5: Save output to file
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dmt),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "tv_exposure"),
#'   generate = c("hrt", "dmt_type"),
#'   saveas = "merged_exposures.rds",
#'   replace = TRUE
#' )
#'
#' # Example 6: Three-dataset merge
#' tv_hrt2 <- tvexpose(
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
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dmt, tv_hrt2),
#'   id = "id",
#'   start = c("rx_start", "rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "tv_exposure", "tv_exposure"),
#'   generate = c("hrt", "dmt_type", "hrt2")
#' )
#'
#' # Example 7: Merge with different exposure definitions
#' # Create one tvexpose output with evertreated and another with currentformer
#' tv_hrt_ever <- tvexpose(
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
#' tv_dmt_cf <- tvexpose(
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
#'   generate = "dmt_cf"
#' )
#'
#' merged <- tvmerge(
#'   datasets = list(tv_hrt_ever, tv_dmt_cf),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("ever_hrt", "dmt_cf"),
#'   generate = c("hrt_ever", "dmt_status")
#' )
#'
#' # Example 8: Prefix for systematic naming
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dmt),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "tv_exposure"),
#'   prefix = "exp_"
#' )
#' # Creates variables: exp_1 (HRT) and exp_2 (DMT)
#'
#' # Example 9: Integration with cohort data
#' # After merging tvexpose outputs, merge with cohort file to bring in
#' # additional baseline characteristics
#' library(dplyr)
#'
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dmt),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "tv_exposure"),
#'   generate = c("hrt", "dmt_type")
#' )
#'
#' # Join with cohort to add baseline variables
#' final_data <- merged %>%
#'   left_join(
#'     cohort %>% select(id, age, female, mstype, edss_baseline),
#'     by = "id"
#'   )
#'
#' # Example 10: Comprehensive workflow with validation
#' # Complete workflow showing tvexpose, tvmerge, validation, and preparation
#' # for survival analysis
#'
#' # Step 1: Create time-varying HRT dataset
#' tv_hrt <- tvexpose(
#'   master = cohort,
#'   exposure_data = hrt,
#'   id = "id",
#'   start = "rx_start",
#'   stop = "rx_stop",
#'   exposure = "hrt_type",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   keepvars = c("age", "female")
#' )
#'
#' # Step 2: Create time-varying DMT dataset
#' tv_dmt <- tvexpose(
#'   master = cohort,
#'   exposure_data = dmt,
#'   id = "id",
#'   start = "dmt_start",
#'   stop = "dmt_stop",
#'   exposure = "dmt",
#'   reference = 0,
#'   entry = "study_entry",
#'   exit = "study_exit",
#'   keepvars = c("mstype", "edss_baseline")
#' )
#'
#' # Step 3: Merge the two time-varying datasets
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dmt),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "tv_exposure"),
#'   generate = c("hrt", "dmt_type"),
#'   keep = c("age", "female", "mstype", "edss_baseline"),
#'   check = TRUE,
#'   validate_coverage = TRUE,
#'   summarize = TRUE,
#'   saveas = "merged_exposures.rds",
#'   replace = TRUE
#' )
#'
#' # Step 4: Merge additional cohort characteristics
#' final_data <- merged %>%
#'   left_join(cohort, by = "id")
#'
#' # Step 5: Display cross-tabulation and sample rows
#' table(final_data$hrt, final_data$dmt_type, useNA = "always")
#'
#' head(final_data %>% select(id, start, stop, hrt, dmt_type, age_ds1, female_ds1), 20)
#'
#' # Example 11: Continuous exposure merging
#' # Merge continuous exposures (like dosage rates) using the continuous option
#' # Assume tv_hrt has categorical HRT types
#' # and tv_dose has continuous dosage rates per day
#'
#' merged <- tvmerge(
#'   datasets = list(tv_hrt, tv_dose),
#'   id = "id",
#'   start = c("rx_start", "rx_start"),
#'   stop = c("rx_stop", "rx_stop"),
#'   exposure = c("tv_exposure", "dosage_rate"),
#'   continuous = "dosage_rate",
#'   generate = c("hrt_type", "dose")
#' )
#' # Creates: hrt_type (categorical), dose (rate per day), dose_period (total in period)
#'
#' # Example 12: Multiple continuous exposures
#' merged <- tvmerge(
#'   datasets = list(tv_drug1, tv_drug2, tv_drug3),
#'   id = "id",
#'   start = c("start", "start", "start"),
#'   stop = c("stop", "stop", "stop"),
#'   exposure = c("rate1", "rate2", "rate3"),
#'   continuous = c(1, 2, 3),  # All three are continuous
#'   generate = c("d1", "d2", "d3")
#' )
#' # Creates: d1, d1_period, d2, d2_period, d3, d3_period
#' }
#'
#' @seealso \code{\link{tvexpose}} for creating time-varying exposure datasets
#'
#' @export
#' @importFrom dplyr mutate filter select arrange group_by ungroup summarise distinct inner_join rename sym n_distinct
#' @importFrom tidyr any_of

# ============================================================================
# HELPER FUNCTIONS FOR TYPE-SAFE DATE CONVERSIONS
# ============================================================================

#' Convert dates to numeric safely with validation
#'
#' @param date_var Vector of dates (Date, POSIXct, numeric, or character)
#' @param var_name Name of variable for error messages
#' @return Numeric vector of days since 1970-01-01
#' @keywords internal
convert_to_numeric_date <- function(date_var, var_name) {
  # Case 1: Already Date or POSIXct
  if (inherits(date_var, c("Date", "POSIXct", "POSIXlt"))) {
    return(as.numeric(date_var))
  }

  # Case 2: Already numeric
  if (is.numeric(date_var)) {
    # Validate reasonable range (1970-01-01 to 2100-12-31)
    if (any(!is.na(date_var) & (date_var < 0 | date_var > 47847))) {
      warning(sprintf("%s contains dates outside reasonable range (1970-2100)", var_name))
    }
    return(date_var)
  }

  # Case 3: Character - try to parse
  if (is.character(date_var)) {
    parsed <- tryCatch(
      as.Date(date_var),
      error = function(e) {
        stop(sprintf("Cannot convert %s to date. Error: %s\nPlease provide Date objects or YYYY-MM-DD format.",
                     var_name, e$message))
      }
    )
    return(as.numeric(parsed))
  }

  # Case 4: Unsupported type
  stop(sprintf("%s must be Date, POSIXct, numeric, or character (YYYY-MM-DD), got: %s",
               var_name, class(date_var)[1]))
}

#' Validate dates for infinite and missing values
#'
#' @param date_var Numeric date vector
#' @param var_name Name of variable for error messages
#' @keywords internal
validate_date_values <- function(date_var, var_name) {
  # Check for infinite values
  if (any(is.infinite(date_var))) {
    stop(sprintf("%s contains infinite (Inf or -Inf) values. Please provide finite dates.",
                 var_name))
  }

  # Check for NA values
  if (any(is.na(date_var))) {
    stop(sprintf("%s contains NA values. All dates must be valid.", var_name))
  }

  invisible(TRUE)
}

#' Check for overlapping IDs between datasets
#'
#' @param datasets List of datasets
#' @param id ID variable name
#' @keywords internal
validate_overlapping_ids <- function(datasets, id) {
  # Get unique IDs from each dataset
  all_ids <- lapply(datasets, function(df) unique(df[[id]]))

  # Find common IDs across all datasets
  common_ids <- Reduce(intersect, all_ids)

  if (length(common_ids) == 0) {
    # No overlapping IDs at all
    stop(sprintf(
      paste0("No common IDs found across all %d datasets.\n",
             "Dataset 1 has %d unique IDs, Dataset 2 has %d unique IDs.\n",
             "Please ensure datasets contain the same persons (IDs)."),
      length(datasets),
      length(all_ids[[1]]),
      if (length(all_ids) >= 2) length(all_ids[[2]]) else 0
    ))
  }

  # Warn if many IDs are not common
  for (i in seq_along(all_ids)) {
    pct_overlap <- length(common_ids) / length(all_ids[[i]]) * 100
    if (pct_overlap < 50) {
      warning(sprintf(
        paste0("Only %.1f%% of IDs in dataset %d are present in all datasets.\n",
               "  Dataset %d unique IDs: %d\n",
               "  Common across all: %d"),
        pct_overlap,
        i,
        i,
        length(all_ids[[i]]),
        length(common_ids)
      ))
    }
  }

  invisible(TRUE)
}

#' Estimate memory usage for Cartesian merge
#'
#' @param merged_data First dataset
#' @param dfk_clean Second dataset
#' @param id_var ID variable name
#' @keywords internal
estimate_cartesian_size <- function(merged_data, dfk_clean, id_var) {
  # Count periods per person in each dataset
  periods_ds1 <- merged_data %>%
    group_by(!!sym(id_var)) %>%
    summarise(n1 = n(), .groups = "drop")

  periods_ds2 <- dfk_clean %>%
    group_by(!!sym(id_var)) %>%
    summarise(n2 = n(), .groups = "drop")

  # Join to get product per person
  combined <- periods_ds1 %>%
    inner_join(periods_ds2, by = id_var) %>%
    mutate(product = n1 * n2)

  # Calculate statistics
  total_output_rows <- sum(combined$product)
  max_per_person <- max(combined$product)
  mean_per_person <- mean(combined$product)

  # Estimate memory (rough: 1 KB per row)
  estimated_mb <- total_output_rows / 1024

  return(list(
    total_rows = total_output_rows,
    max_rows_per_person = max_per_person,
    mean_rows_per_person = mean_per_person,
    estimated_mb = estimated_mb,
    input_rows_ds1 = nrow(merged_data),
    input_rows_ds2 = nrow(dfk_clean)
  ))
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

tvmerge <- function(datasets,
                    id,
                    start,
                    stop,
                    exposure,
                    continuous = NULL,
                    generate = NULL,
                    prefix = NULL,
                    startname = "start",
                    stopname = "stop",
                    dateformat = "%Y-%m-%d",
                    saveas = NULL,
                    replace = FALSE,
                    keep = NULL,
                    check = FALSE,
                    validate_coverage = FALSE,
                    validate_overlap = FALSE,
                    summarize = FALSE) {

  # =============================================================================
  # INPUT VALIDATION
  # =============================================================================

  # Validate datasets argument
  if (!is.list(datasets)) {
    stop("datasets must be a list of data frames or file paths")
  }

  numds <- length(datasets)
  if (numds < 2) {
    stop("tvmerge requires at least 2 datasets")
  }

  # Check for conflicting naming options
  if (!is.null(prefix) && !is.null(generate)) {
    stop("Specify either prefix or generate, not both")
  }

  # Validate generate names count
  if (!is.null(generate)) {
    if (length(generate) != numds) {
      stop(sprintf("generate must contain exactly %d names (one per dataset)", numds))
    }
  }

  # Validate startname and stopname are different
  if (startname == stopname) {
    stop("startname and stopname must be different variable names")
  }

  # Validate variable name vectors have correct length
  if (length(start) != numds || length(stop) != numds || length(exposure) != numds) {
    stop("Number of start, stop, and exposure variables must equal number of datasets")
  }

  # Load datasets if file paths provided
  for (i in seq_along(datasets)) {
    if (is.character(datasets[[i]])) {
      # Assume it's a file path
      if (!file.exists(datasets[[i]])) {
        stop(sprintf("Dataset file not found: %s", datasets[[i]]))
      }
      # Try to load based on extension
      if (grepl("\\.csv$", datasets[[i]], ignore.case = TRUE)) {
        datasets[[i]] <- read.csv(datasets[[i]], stringsAsFactors = FALSE)
      } else if (grepl("\\.rds$", datasets[[i]], ignore.case = TRUE)) {
        datasets[[i]] <- readRDS(datasets[[i]])
      } else {
        stop(sprintf("Unsupported file format for dataset %d. Use .csv or .rds", i))
      }
    }
    if (!is.data.frame(datasets[[i]])) {
      stop(sprintf("Dataset %d must be a data frame", i))
    }
  }

  # =============================================================================
  # PARSE CONTINUOUS EXPOSURE SPECIFICATION
  # =============================================================================

  continuous_positions <- c()
  continuous_names <- c()

  if (!is.null(continuous)) {
    for (item in continuous) {
      # Check if item is numeric (position)
      if (is.numeric(item)) {
        if (item < 1 || item > numds) {
          stop(sprintf("continuous position %d out of range (1-%d)", item, numds))
        }
        continuous_positions <- c(continuous_positions, item)
        continuous_names <- c(continuous_names, exposure[item])
      } else {
        # Treat as exposure name
        pos <- which(exposure == item)
        if (length(pos) == 0) {
          stop(sprintf("continuous exposure '%s' not found in exposure list", item))
        }
        continuous_positions <- c(continuous_positions, pos)
        continuous_names <- c(continuous_names, item)
      }
    }
  }

  # Identify categorical exposures
  categorical_positions <- setdiff(1:numds, continuous_positions)
  categorical_names <- exposure[categorical_positions]

  # =============================================================================
  # VALIDATE OVERLAPPING IDS
  # =============================================================================

  # Ensure datasets have common IDs
  validate_overlapping_ids(datasets, id)

  # =============================================================================
  # DETERMINE FINAL EXPOSURE NAMES
  # =============================================================================

  final_exposure_names <- character(numds)
  for (j in 1:numds) {
    if (!is.null(generate)) {
      final_exposure_names[j] <- generate[j]
    } else if (!is.null(prefix)) {
      final_exposure_names[j] <- paste0(prefix, exposure[j])
    } else {
      final_exposure_names[j] <- exposure[j]
    }
  }

  # Track which final names are continuous
  continuous_final_names <- final_exposure_names[continuous_positions]
  categorical_final_names <- final_exposure_names[categorical_positions]

  # =============================================================================
  # TRACK STATISTICS
  # =============================================================================

  invalid_counts <- integer(numds)

  # =============================================================================
  # PROCESS FIRST DATASET
  # =============================================================================

  cat("Processing dataset 1...\n")

  df1 <- datasets[[1]]

  # Verify required variables exist
  if (!id %in% names(df1)) {
    stop(sprintf("Variable '%s' not found in dataset 1", id))
  }
  if (!start[1] %in% names(df1)) {
    stop(sprintf("Variable '%s' not found in dataset 1", start[1]))
  }
  if (!stop[1] %in% names(df1)) {
    stop(sprintf("Variable '%s' not found in dataset 1", stop[1]))
  }
  if (!exposure[1] %in% names(df1)) {
    stop(sprintf("Variable '%s' not found in dataset 1", exposure[1]))
  }

  # Select and rename variables
  merged_data <- df1 %>%
    select(
      id_var = !!sym(id),
      start_var = !!sym(start[1]),
      stop_var = !!sym(stop[1]),
      exp_var = !!sym(exposure[1]),
      if (!is.null(keep)) {
        any_of(keep)
      }
    ) %>%
    # Floor start dates and ceil stop dates to handle fractional values
    mutate(
      start_var = floor(convert_to_numeric_date(start_var, paste0("dataset 1: ", start[1]))),
      stop_var = ceiling(convert_to_numeric_date(stop_var, paste0("dataset 1: ", stop[1])))
    )

  # Validate converted dates
  validate_date_values(merged_data$start_var, paste0("dataset 1: ", start[1]))
  validate_date_values(merged_data$stop_var, paste0("dataset 1: ", stop[1]))

  # Rename exposure variable to final name
  names(merged_data)[names(merged_data) == "exp_var"] <- final_exposure_names[1]

  # Rename keep variables with _ds1 suffix
  if (!is.null(keep)) {
    for (var in keep) {
      if (var %in% names(merged_data)) {
        names(merged_data)[names(merged_data) == var] <- paste0(var, "_ds1")
      }
    }
  }

  # Drop invalid periods where start > stop
  invalid_counts[1] <- sum(merged_data$start_var > merged_data$stop_var |
                             is.na(merged_data$start_var) |
                             is.na(merged_data$stop_var))

  merged_data <- merged_data %>%
    filter(start_var <= stop_var,
           !is.na(start_var),
           !is.na(stop_var))

  # Validate dataset is not empty after filtering
  if (nrow(merged_data) == 0) {
    stop("No valid time periods remain after filtering invalid dates in dataset 1")
  }

  # Sort
  merged_data <- merged_data %>%
    arrange(id_var, start_var, stop_var)

  # =============================================================================
  # PROCESS ADDITIONAL DATASETS AND MERGE
  # =============================================================================

  for (k in 2:numds) {
    cat(sprintf("Processing dataset %d and merging...\n", k))

    dfk <- datasets[[k]]

    # Verify required variables exist
    if (!id %in% names(dfk)) {
      stop(sprintf("Variable '%s' not found in dataset %d", id, k))
    }
    if (!start[k] %in% names(dfk)) {
      stop(sprintf("Variable '%s' not found in dataset %d", start[k], k))
    }
    if (!stop[k] %in% names(dfk)) {
      stop(sprintf("Variable '%s' not found in dataset %d", stop[k], k))
    }
    if (!exposure[k] %in% names(dfk)) {
      stop(sprintf("Variable '%s' not found in dataset %d", exposure[k], k))
    }

    # Select and rename variables
    dfk_clean <- dfk %>%
      select(
        id_var = !!sym(id),
        start_k = !!sym(start[k]),
        stop_k = !!sym(stop[k]),
        exp_k = !!sym(exposure[k]),
        if (!is.null(keep)) {
          any_of(keep)
        }
      ) %>%
      # Floor start dates and ceil stop dates
      mutate(
        start_k = floor(convert_to_numeric_date(start_k, paste0("dataset ", k, ": ", start[k]))),
        stop_k = ceiling(convert_to_numeric_date(stop_k, paste0("dataset ", k, ": ", stop[k])))
      )

    # Validate converted dates
    validate_date_values(dfk_clean$start_k, paste0("dataset ", k, ": ", start[k]))
    validate_date_values(dfk_clean$stop_k, paste0("dataset ", k, ": ", stop[k]))

    # Rename keep variables with _ds# suffix
    if (!is.null(keep)) {
      for (var in keep) {
        if (var %in% names(dfk_clean)) {
          names(dfk_clean)[names(dfk_clean) == var] <- paste0(var, "_ds", k)
        }
      }
    }

    # Validate continuous exposure is numeric
    is_continuous_k <- k %in% continuous_positions
    if (is_continuous_k && !is.numeric(dfk_clean$exp_k)) {
      stop(sprintf("Continuous exposure '%s' in dataset %d must be numeric", exposure[k], k))
    }

    # Drop invalid periods where start > stop
    invalid_counts[k] <- sum(dfk_clean$start_k > dfk_clean$stop_k |
                              is.na(dfk_clean$start_k) |
                              is.na(dfk_clean$stop_k))

    dfk_clean <- dfk_clean %>%
      filter(start_k <= stop_k,
             !is.na(start_k),
             !is.na(stop_k))

    # Validate dataset is not empty after filtering
    if (nrow(dfk_clean) == 0) {
      stop(sprintf("No valid time periods remain after filtering invalid dates in dataset %d", k))
    }

    # Sort
    dfk_clean <- dfk_clean %>%
      arrange(id_var, start_k, stop_k)

    # -------------------------------------------------------------------------
    # PERFORM CARTESIAN MERGE OF TIME INTERVALS
    # -------------------------------------------------------------------------

    # Check if exposure k is continuous
    is_continuous_k <- k %in% continuous_positions

    # -------------------------------------------------------------------------
    # ESTIMATE CARTESIAN PRODUCT SIZE AND WARN IF LARGE
    # -------------------------------------------------------------------------

    size_est <- estimate_cartesian_size(merged_data, dfk_clean, "id_var")

    # Warn if output will be very large
    if (size_est$total_rows > 1e6) {
      warning(sprintf(
        paste0("Large Cartesian merge detected for dataset %d:\n",
               "  Input: %s rows (merged data) × %s rows (dataset %d)\n",
               "  Estimated output: %s rows (%.1f MB)\n",
               "  Max rows per person: %s\n",
               "  This may take several minutes and use significant memory."),
        k,
        format(size_est$input_rows_ds1, big.mark = ","),
        format(size_est$input_rows_ds2, big.mark = ","),
        k,
        format(size_est$total_rows, big.mark = ","),
        size_est$estimated_mb,
        format(size_est$max_rows_per_person, big.mark = ",")
      ))
    }

    # If extremely large, stop with error
    if (size_est$total_rows > 1e8) {
      stop(sprintf(
        paste0("Cartesian merge would create %s rows (>100 million) for dataset %d.\n",
               "This would likely exhaust memory.\n",
               "Consider:\n",
               "  1. Reducing the number of periods in your tvexpose outputs\n",
               "  2. Merging datasets with fewer overlapping time periods\n",
               "  3. Processing in smaller batches by ID"),
        format(size_est$total_rows, big.mark = ","),
        k
      ))
    }

    # Create cartesian product by joining on id only
    cartesian <- merged_data %>%
      inner_join(dfk_clean, by = "id_var", relationship = "many-to-many")

    # Calculate interval intersection
    cartesian <- cartesian %>%
      mutate(
        new_start = pmax(start_var, start_k),
        new_stop = pmin(stop_var, stop_k)
      ) %>%
      # Keep only valid intersections
      filter(new_start <= new_stop, !is.na(new_start), !is.na(new_stop))

    # For continuous exposures, calculate period-specific exposure
    if (is_continuous_k) {
      # Calculate period length (days in the intersection)
      period_length <- cartesian$new_stop - cartesian$new_start + 1

      cartesian <- cartesian %>%
        mutate(
          # Create period-specific exposure variable (rate * days)
          !!sym(paste0(final_exposure_names[k], "_period")) := exp_k * period_length
          # Keep exp_k as-is (it's the rate per day)
        )
    }

    # Replace old interval with intersection
    cartesian <- cartesian %>%
      mutate(
        start_var = new_start,
        stop_var = new_stop
      ) %>%
      select(-new_start, -new_stop, -start_k, -stop_k)

    # Rename exposure variable to final name
    names(cartesian)[names(cartesian) == "exp_k"] <- final_exposure_names[k]

    # Update merged_data for next iteration
    merged_data <- cartesian

    # Sort
    merged_data <- merged_data %>%
      arrange(id_var, start_var, stop_var)
  }

  # =============================================================================
  # CLEAN UP FINAL DATASET
  # =============================================================================

  cat("Finalizing merged dataset...\n")

  # Rename id_var, start_var, stop_var to final names
  merged_data <- merged_data %>%
    rename(
      !!sym(id) := id_var,
      !!sym(startname) := start_var,
      !!sym(stopname) := stop_var
    )

  # Apply date format if specified and convert back to Date objects
  merged_data <- merged_data %>%
    mutate(
      !!sym(startname) := as.Date(!!sym(startname), origin = "1970-01-01"),
      !!sym(stopname) := as.Date(!!sym(stopname), origin = "1970-01-01")
    )

  # Drop exact duplicates
  n_before_dedup <- nrow(merged_data)
  merged_data <- merged_data %>%
    distinct()
  n_after_dedup <- nrow(merged_data)
  n_dups <- n_before_dedup - n_after_dedup

  # Sort final dataset
  merged_data <- merged_data %>%
    arrange(!!sym(id), !!sym(startname), !!sym(stopname))

  # =============================================================================
  # CALCULATE DIAGNOSTICS
  # =============================================================================

  n_obs <- nrow(merged_data)
  n_persons <- n_distinct(merged_data[[id]])

  # Calculate average and max periods per person
  periods_per_person <- merged_data %>%
    group_by(!!sym(id)) %>%
    summarise(n_periods = n(), .groups = "drop")

  avg_periods <- mean(periods_per_person$n_periods)
  max_periods <- max(periods_per_person$n_periods)

  # =============================================================================
  # VALIDATE COVERAGE (CHECK FOR GAPS)
  # =============================================================================

  if (validate_coverage) {
    cat("\n")
    cat(strrep("-", 50), "\n")
    cat("Validating coverage...\n")

    gaps <- merged_data %>%
      arrange(!!sym(id), !!sym(startname)) %>%
      group_by(!!sym(id)) %>%
      mutate(
        gap = !!sym(startname) - lag(!!sym(stopname)),
        gap_start = lag(!!sym(stopname)),
        gap_end = !!sym(startname)
      ) %>%
      ungroup() %>%
      filter(!is.na(gap), gap > 1)

    if (nrow(gaps) > 0) {
      cat(sprintf("Found %d gaps in coverage (>1 day gaps)\n", nrow(gaps)))
      print(gaps %>% select(!!sym(id), gap_start, gap_end, gap))
    } else {
      cat("No gaps >1 day found in coverage.\n")
    }
    cat(strrep("-", 50), "\n")
  }

  # =============================================================================
  # VALIDATE OVERLAPS
  # =============================================================================

  if (validate_overlap) {
    cat("\n")
    cat(strrep("-", 50), "\n")
    cat("Validating overlaps...\n")

    overlaps <- merged_data %>%
      arrange(!!sym(id), !!sym(startname)) %>%
      group_by(!!sym(id)) %>%
      mutate(
        overlap = !!sym(startname) < lag(!!sym(stopname)),
        prev_stop = lag(!!sym(stopname))
      ) %>%
      ungroup() %>%
      filter(!is.na(overlap), overlap == TRUE)

    # Check if exposure values are identical (unexpected overlap)
    if (nrow(overlaps) > 0) {
      overlaps <- overlaps %>%
        mutate(same_exposures = TRUE)

      # Check each exposure variable
      for (exp_name in final_exposure_names) {
        if (exp_name %in% names(overlaps)) {
          overlaps <- overlaps %>%
            group_by(!!sym(id)) %>%
            mutate(
              same_exposures = same_exposures &
                (!!sym(exp_name) == lag(!!sym(exp_name)))
            ) %>%
            ungroup()
        }
      }

      # Only flag overlaps with identical exposure values
      unexpected_overlaps <- overlaps %>%
        filter(same_exposures == TRUE)

      if (nrow(unexpected_overlaps) > 0) {
        cat(sprintf("Found %d unexpected overlapping periods (same interval, same exposures)\n",
                    nrow(unexpected_overlaps)))
        print(unexpected_overlaps %>%
                select(!!sym(id), !!sym(startname), !!sym(stopname), prev_stop))
      } else {
        cat("No unexpected overlaps found.\n")
      }
    } else {
      cat("No overlaps found.\n")
    }
    cat(strrep("-", 50), "\n")
  }

  # =============================================================================
  # DISPLAY SUMMARY STATISTICS
  # =============================================================================

  if (summarize) {
    cat("\n")
    cat(strrep("-", 50), "\n")
    cat("Summary Statistics:\n")
    print(summary(merged_data[[startname]]))
    print(summary(merged_data[[stopname]]))
    cat(strrep("-", 50), "\n")
  }

  # =============================================================================
  # DISPLAY COMPLETION SUMMARY
  # =============================================================================

  # Display invalid period warnings
  for (k in 1:numds) {
    if (invalid_counts[k] > 0) {
      cat(sprintf("Found %d rows in dataset %d where start > stop (skipped)\n",
                  invalid_counts[k], k))
    }
  }

  # Display duplicates info
  if (n_dups > 0) {
    cat(sprintf("Dropped %d duplicate interval+exposure combinations\n", n_dups))
  }

  # Display coverage diagnostics if requested
  if (check) {
    cat("\n")
    cat(strrep("-", 50), "\n")
    cat("Coverage Diagnostics:\n")
    cat(sprintf("    Number of persons: %d\n", n_persons))
    cat(sprintf("    Average periods per person: %.2f\n", avg_periods))
    cat(sprintf("    Max periods per person: %d\n", max_periods))
    cat(sprintf("    Total merged intervals: %d\n", n_obs))
    cat(strrep("-", 50), "\n")
  }

  cat("\n")
  cat("Merged time-varying dataset successfully created\n")
  cat(strrep("-", 50), "\n")
  cat(sprintf("    Observations: %d\n", n_obs))
  cat(sprintf("    Persons: %d\n", n_persons))
  cat(sprintf("    Exposure variables: %s\n", paste(final_exposure_names, collapse = ", ")))
  cat(strrep("-", 50), "\n")

  # =============================================================================
  # SAVE DATASET IF REQUESTED
  # =============================================================================

  if (!is.null(saveas)) {
    if (file.exists(saveas) && !replace) {
      stop(sprintf("File '%s' already exists. Use replace = TRUE to overwrite.", saveas))
    }
    if (grepl("\\.csv$", saveas, ignore.case = TRUE)) {
      write.csv(merged_data, saveas, row.names = FALSE)
    } else if (grepl("\\.rds$", saveas, ignore.case = TRUE)) {
      saveRDS(merged_data, saveas)
    } else if (grepl("\\.rda$|\\.RData$", saveas, ignore.case = TRUE)) {
      save(merged_data, file = saveas)
    } else {
      stop("saveas must have extension .csv, .rds, .rda, or .RData")
    }
    cat(sprintf("\nDataset saved to: %s\n", saveas))
  }

  # =============================================================================
  # RETURN RESULTS
  # =============================================================================

  # Store metadata as attributes
  attr(merged_data, "n_datasets") <- numds
  attr(merged_data, "n_persons") <- n_persons
  attr(merged_data, "mean_periods") <- avg_periods
  attr(merged_data, "max_periods") <- max_periods
  attr(merged_data, "exposure_vars") <- final_exposure_names
  attr(merged_data, "continuous_vars") <- continuous_final_names
  attr(merged_data, "categorical_vars") <- categorical_final_names
  attr(merged_data, "startname") <- startname
  attr(merged_data, "stopname") <- stopname

  return(merged_data)
}
