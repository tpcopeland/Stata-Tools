#' Time-Varying Exposure Merge
#'
#' Merges multiple time-varying exposure datasets by computing the Cartesian
#' product of overlapping time periods. Creates all possible combinations of
#' exposure values across datasets for each person.
#'
#' @param datasets Character vector of dataset names (with or without .dta
#'   extension) or list of data.frames. Minimum 2 datasets required.
#' @param id Character string specifying the ID variable name (must be the same
#'   across all datasets).
#' @param start Character vector of start date variable names (one per dataset).
#' @param stop Character vector of stop date variable names (one per dataset).
#' @param exposure Character vector of exposure variable names (one per dataset).
#'   Must all be unique.
#' @param continuous Character vector or numeric vector specifying which
#'   exposures are continuous (either positions 1:n or variable names). Continuous
#'   exposures will be interpolated based on overlap duration. Default is NULL
#'   (all categorical).
#' @param generate Character vector of new names for exposure variables in output
#'   (length must equal number of datasets). Mutually exclusive with \code{prefix}.
#' @param prefix Character string prefix to add to all exposure variable names.
#'   Mutually exclusive with \code{generate}.
#' @param startname Character string name for output start variable. Default is "start".
#' @param stopname Character string name for output stop variable. Default is "stop".
#' @param dateformat Character string date format (kept for Stata compatibility,
#'   not used in R).
#' @param saveas Character string filename to save result as Stata dataset.
#' @param keep Character vector of additional variables to keep from source
#'   datasets (will be suffixed with _ds1, _ds2, etc.).
#' @param batch Numeric value between 1-100 specifying percentage of IDs to
#'   process per batch. Default is 20. Lower values use less memory but may be
#'   slower.
#' @param force Logical indicating whether to allow mismatched IDs between
#'   datasets. If FALSE (default), stops with error if IDs don't match. If TRUE,
#'   continues with warning and uses intersection of IDs.
#' @param check Logical indicating whether to display coverage diagnostics.
#'   Default is FALSE.
#' @param validatecoverage Logical indicating whether to check for gaps >1 day
#'   in coverage. Default is FALSE.
#' @param validateoverlap Logical indicating whether to check for unexpected
#'   overlapping periods with identical exposures. Default is FALSE.
#' @param summarize Logical indicating whether to display summary statistics.
#'   Default is FALSE.
#'
#' @return A list with three components:
#'   \describe{
#'     \item{data}{Merged data.frame with ID, start/stop intervals, and all
#'       exposure variables}
#'     \item{diagnostics}{List containing diagnostic information including
#'       n_persons, avg_periods, max_periods, invalid_counts, n_duplicates}
#'     \item{returns}{List of return values mimicking Stata's r() storage,
#'       including N, N_persons, exposure_vars, etc.}
#'   }
#'
#' @details
#' The core algorithm performs a Cartesian product of time intervals by ID,
#' then filters to overlapping periods. For each person, it finds all temporal
#' overlaps between datasets and creates new time intervals representing the
#' intersection of those overlaps, carrying forward the exposure values from
#' each source dataset.
#'
#' For continuous exposures, values are interpolated based on the proportion
#' of the original period that overlaps: \code{new_value = original_value *
#' (overlap_duration / original_duration)}.
#'
#' Start dates are floored and stop dates are ceiled to handle fractional
#' date values. Point-in-time observations (start == stop) are valid.
#'
#' @examples
#' \dontrun{
#' # Basic two-dataset merge
#' result <- tvmerge(
#'   datasets = c("tv_hrt.dta", "tv_dmt.dta"),
#'   id = "id",
#'   start = c("rx_start", "dmt_start"),
#'   stop = c("rx_stop", "dmt_stop"),
#'   exposure = c("tv_exposure", "tv_exposure"),
#'   generate = c("hrt", "dmt_type")
#' )
#'
#' # With continuous exposure
#' result <- tvmerge(
#'   datasets = c("tv_hrt.dta", "tv_dosage.dta"),
#'   id = "id",
#'   start = c("rx_start", "dose_start"),
#'   stop = c("rx_stop", "dose_stop"),
#'   exposure = c("hrt_type", "dosage_rate"),
#'   continuous = c(2),  # Position 2 is continuous
#'   generate = c("hrt", "dose")
#' )
#'
#' # With validation
#' result <- tvmerge(
#'   datasets = c("tv_hrt.dta", "tv_dmt.dta"),
#'   id = "id",
#'   start = c("rx_start", "dmt_start"),
#'   stop = c("rx_stop", "dmt_stop"),
#'   exposure = c("tv_exposure", "tv_exposure"),
#'   generate = c("hrt", "dmt_type"),
#'   check = TRUE,
#'   validatecoverage = TRUE,
#'   validateoverlap = TRUE,
#'   summarize = TRUE
#' )
#' }
#'
#' @export
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
                    dateformat = NULL,
                    saveas = NULL,
                    keep = NULL,
                    batch = 20,
                    force = FALSE,
                    check = FALSE,
                    validatecoverage = FALSE,
                    validateoverlap = FALSE,
                    summarize = FALSE) {

  # Load required packages
  require_packages()

  # ========== INPUT VALIDATION ==========

  # Validate and load datasets
  loaded_datasets <- validate_datasets(datasets)
  numds <- length(loaded_datasets)

  # Validate variables exist
  validate_variables(loaded_datasets, id, start, stop, exposure)

  # Validate naming options
  validate_naming_options(generate, prefix, numds, exposure, startname, stopname)

  # Validate continuous specification
  continuous_info <- validate_continuous(continuous, exposure)

  # Validate batch parameter
  batch <- validate_batch(batch)

  # ========== CORE MERGE ALGORITHM ==========

  merge_result <- merge_all_datasets(
    datasets = loaded_datasets,
    id = id,
    start = start,
    stop = stop,
    exposure = exposure,
    continuous_info = continuous_info,
    generate = generate,
    prefix = prefix,
    startname = startname,
    stopname = stopname,
    keep_vars = keep,
    batch = batch,
    force = force,
    verbose = TRUE
  )

  merged_data <- merge_result$data
  exp_final_names <- merge_result$exp_final_names

  # ========== DIAGNOSTICS ==========

  diagnostics <- compute_diagnostics(merged_data, "id", startname, stopname)

  # Coverage validation
  coverage_validation <- NULL
  if (validatecoverage) {
    coverage_validation <- validate_coverage(merged_data, "id", startname, stopname)
  }

  # Overlap validation
  overlap_validation <- NULL
  if (validateoverlap) {
    overlap_validation <- validate_overlap(merged_data, "id", startname, stopname, exp_final_names)
  }

  # ========== DISPLAY OUTPUTS ==========

  if (check) {
    display_diagnostics(diagnostics, nrow(merged_data))
  }

  if (validatecoverage) {
    display_gap_validation(coverage_validation, startname, stopname)
  }

  if (validateoverlap) {
    display_overlap_validation(overlap_validation)
  }

  if (summarize) {
    display_summary_stats(merged_data, startname, stopname)
  }

  # Display final summary
  display_final_summary(nrow(merged_data), diagnostics$n_persons, exp_final_names)

  # ========== SAVE OUTPUT ==========

  if (!is.null(saveas)) {
    # Add .dta extension if not present
    if (!grepl("\\.dta$", saveas, ignore.case = TRUE)) {
      saveas <- paste0(saveas, ".dta")
    }

    haven::write_dta(merged_data, saveas)
    message(sprintf("\nOutput saved to: %s", saveas))
  }

  # ========== PREPARE RETURN VALUES ==========

  # Determine categorical vs continuous exposure names
  categorical_names <- setdiff(exp_final_names, continuous_info$names)

  return_list <- list(
    # Main result
    data = merged_data,

    # Diagnostics
    diagnostics = list(
      n_persons = diagnostics$n_persons,
      avg_periods = diagnostics$avg_periods,
      max_periods = diagnostics$max_periods,
      invalid_counts = merge_result$invalid_counts,
      n_duplicates = merge_result$n_duplicates,
      coverage_validation = coverage_validation,
      overlap_validation = overlap_validation
    ),

    # Stata-style returns
    returns = list(
      N = nrow(merged_data),
      N_persons = diagnostics$n_persons,
      mean_periods = diagnostics$avg_periods,
      max_periods = diagnostics$max_periods,
      N_datasets = numds,
      exposure_vars = exp_final_names,
      continuous_vars = continuous_info$names,
      categorical_vars = categorical_names,
      n_continuous = length(continuous_info$names),
      n_categorical = length(categorical_names),
      startname = startname,
      stopname = stopname,
      prefix = prefix,
      generated_names = generate,
      output_file = saveas
    )
  )

  return(return_list)
}


# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

#' Validate datasets parameter
#' @keywords internal
validate_datasets <- function(datasets) {
  # Accept either character vector of filenames or list of data.frames
  if (length(datasets) < 2) {
    stop("tvmerge requires at least 2 datasets")
  }

  loaded_datasets <- list()

  for (i in seq_along(datasets)) {
    if (is.character(datasets[[i]])) {
      # It's a filename
      fname <- datasets[[i]]

      # Add .dta extension if missing
      if (!grepl("\\.dta$", fname, ignore.case = TRUE)) {
        fname <- paste0(fname, ".dta")
      }

      # Check file exists
      if (!file.exists(fname)) {
        stop(sprintf("Dataset file not found: %s", fname))
      }

      # Try to load with haven::read_dta
      tryCatch({
        loaded_datasets[[i]] <- haven::read_dta(fname)
      }, error = function(e) {
        stop(sprintf("%s is not a valid Stata dataset or cannot be read: %s",
                     fname, e$message))
      })

    } else if (is.data.frame(datasets[[i]])) {
      # It's already a data.frame
      loaded_datasets[[i]] <- datasets[[i]]
    } else {
      stop(sprintf("Dataset %d is neither a filename nor a data.frame", i))
    }

    # Strip haven class attributes to prevent rbindlist errors
    for (col in names(loaded_datasets[[i]])) {
      if (inherits(loaded_datasets[[i]][[col]], "haven_labelled")) {
        loaded_datasets[[i]][[col]] <- as.vector(loaded_datasets[[i]][[col]])
      }
    }
  }

  return(loaded_datasets)
}


#' Validate that all required variables exist
#' @keywords internal
validate_variables <- function(datasets, id, start, stop, exposure) {
  numds <- length(datasets)

  # Validate counts
  if (length(start) != numds) {
    stop(sprintf("Number of start variables (%d) must equal number of datasets (%d)",
                 length(start), numds))
  }
  if (length(stop) != numds) {
    stop(sprintf("Number of stop variables (%d) must equal number of datasets (%d)",
                 length(stop), numds))
  }
  if (length(exposure) != numds) {
    stop(sprintf("Number of exposure variables (%d) must equal number of datasets (%d)",
                 length(exposure), numds))
  }

  # Check for duplicate exposure names
  if (any(duplicated(exposure))) {
    dup_name <- exposure[duplicated(exposure)][1]
    stop(sprintf(paste("Duplicate exposure variable name '%s' specified multiple times.",
                      "Each position in exposure must have a unique name.",
                      "Use the generate parameter to rename exposures if datasets have same variable names."),
                 dup_name))
  }

  # Validate each dataset has required variables
  for (i in seq_along(datasets)) {
    ds <- datasets[[i]]
    ds_label <- sprintf("dataset %d", i)

    if (!id %in% names(ds)) {
      stop(sprintf("Variable '%s' not found in %s", id, ds_label))
    }

    if (!start[i] %in% names(ds)) {
      stop(sprintf("Variable '%s' not found in %s", start[i], ds_label))
    }

    if (!stop[i] %in% names(ds)) {
      stop(sprintf("Variable '%s' not found in %s", stop[i], ds_label))
    }

    if (!exposure[i] %in% names(ds)) {
      stop(sprintf("Variable '%s' not found in %s", exposure[i], ds_label))
    }
  }
}


#' Validate naming options
#' @keywords internal
validate_naming_options <- function(generate, prefix, numds, exposure, startname, stopname) {
  # Check for conflicting options
  if (!is.null(generate) && !is.null(prefix)) {
    stop("Specify either 'generate' or 'prefix', not both")
  }

  # Validate generate
  if (!is.null(generate)) {
    if (length(generate) != numds) {
      stop(sprintf("generate must contain exactly %d names (one per dataset)", numds))
    }

    # Check for valid R names
    for (name in generate) {
      if (!grepl("^[a-zA-Z][a-zA-Z0-9._]*$", name)) {
        stop(sprintf("generate contains invalid name: %s", name))
      }
    }
  }

  # Validate prefix
  if (!is.null(prefix)) {
    if (!grepl("^[a-zA-Z][a-zA-Z0-9._]*$", prefix)) {
      stop("prefix contains invalid R name characters")
    }
  }

  # Validate startname
  if (!is.null(startname)) {
    if (!grepl("^[a-zA-Z][a-zA-Z0-9._]*$", startname)) {
      stop(sprintf("startname contains invalid R name: %s", startname))
    }
  }

  # Validate stopname
  if (!is.null(stopname)) {
    if (!grepl("^[a-zA-Z][a-zA-Z0-9._]*$", stopname)) {
      stop(sprintf("stopname contains invalid R name: %s", stopname))
    }
  }

  # Ensure startname and stopname are different
  if (startname == stopname) {
    stop("startname and stopname must be different variable names")
  }
}


#' Validate continuous exposure specification
#' @keywords internal
validate_continuous <- function(continuous, exposure) {
  if (is.null(continuous)) {
    return(list(
      positions = integer(0),
      names = character(0)
    ))
  }

  continuous_positions <- integer(0)
  continuous_names <- character(0)

  for (item in continuous) {
    # Check if it's a position (integer)
    if (is.numeric(item) && item == as.integer(item)) {
      pos <- as.integer(item)

      if (pos < 1 || pos > length(exposure)) {
        stop(sprintf("continuous position %d out of range (1-%d)", pos, length(exposure)))
      }

      continuous_positions <- c(continuous_positions, pos)
      continuous_names <- c(continuous_names, exposure[pos])

    } else if (is.character(item)) {
      # It's a name - find position
      pos <- which(exposure == item)

      if (length(pos) == 0) {
        stop(sprintf("continuous exposure '%s' not found in exposure list", item))
      }

      continuous_positions <- c(continuous_positions, pos)
      continuous_names <- c(continuous_names, item)

    } else {
      stop(sprintf("continuous contains invalid item: %s", as.character(item)))
    }
  }

  return(list(
    positions = continuous_positions,
    names = continuous_names
  ))
}


#' Validate batch parameter
#' @keywords internal
validate_batch <- function(batch) {
  if (!is.numeric(batch) || length(batch) != 1) {
    stop("batch must be a single numeric value")
  }

  if (batch < 1 || batch > 100) {
    stop("batch must be between 1 and 100 (percentage of IDs per batch)")
  }

  return(as.integer(batch))
}


# ============================================================================
# CORE ALGORITHM FUNCTIONS
# ============================================================================

#' Prepare first dataset
#' @keywords internal
prepare_first_dataset <- function(ds1, id, start1, stop1, exp1,
                                  startname, stopname, exp_final_name,
                                  keep_vars = NULL) {
  # Rename core variables to standard names
  result <- ds1 %>%
    dplyr::rename(
      id = !!rlang::sym(id),
      !!rlang::sym(startname) := !!rlang::sym(start1),
      !!rlang::sym(stopname) := !!rlang::sym(stop1)
    )

  # Floor start dates, ceil stop dates (only for numeric types, not Date)
  if (!inherits(result[[startname]], "Date")) {
    result <- result %>%
      dplyr::mutate(
        !!rlang::sym(startname) := floor(!!rlang::sym(startname)),
        !!rlang::sym(stopname) := ceiling(!!rlang::sym(stopname))
      )
  }

  # Rename exposure variable
  result <- result %>%
    dplyr::rename(!!rlang::sym(exp_final_name) := !!rlang::sym(exp1))

  # Process keep() variables
  keep_list <- c("id", startname, stopname, exp_final_name)

  if (!is.null(keep_vars)) {
    for (var in keep_vars) {
      if (var %in% names(result)) {
        # Rename with _ds1 suffix
        new_name <- paste0(var, "_ds1")
        result <- result %>%
          dplyr::rename(!!rlang::sym(new_name) := !!rlang::sym(var))
        keep_list <- c(keep_list, new_name)
      }
    }
  }

  # Keep only necessary variables
  result <- result %>%
    dplyr::select(dplyr::all_of(keep_list))

  # Drop invalid periods (start > stop or missing dates)
  invalid_count <- sum(result[[startname]] > result[[stopname]] |
                      is.na(result[[startname]]) |
                      is.na(result[[stopname]]))

  result <- result %>%
    dplyr::filter(!!rlang::sym(startname) <= !!rlang::sym(stopname),
                  !is.na(!!rlang::sym(startname)),
                  !is.na(!!rlang::sym(stopname)))

  # Sort
  result <- result %>%
    dplyr::arrange(id, !!rlang::sym(startname), !!rlang::sym(stopname))

  return(list(
    data = result,
    invalid_count = invalid_count
  ))
}


#' Validate ID matching between datasets
#' @keywords internal
validate_id_matching <- function(merged_data, ds_k, force = FALSE,
                                 k, ds_k_name) {
  # Get unique IDs from both datasets
  merged_ids <- unique(merged_data$id)
  ds_k_ids <- unique(ds_k$id)

  # Find mismatches
  only_merged <- setdiff(merged_ids, ds_k_ids)
  only_dsk <- setdiff(ds_k_ids, merged_ids)

  n_only_merged <- length(only_merged)
  n_only_dsk <- length(only_dsk)

  # If mismatches exist
  if (n_only_merged > 0 || n_only_dsk > 0) {
    if (!force) {
      # Strict mode - error out
      msg <- sprintf("\nID mismatch detected between datasets!\n")

      if (n_only_merged > 0) {
        msg <- paste0(msg, sprintf(
          "  %d IDs exist in datasets 1-%d but not in dataset %d (%s):\n",
          n_only_merged, k-1, k, ds_k_name
        ))
        msg <- paste0(msg, "  ", paste(head(only_merged, 10), collapse = ", "))
        if (n_only_merged > 10) {
          msg <- paste0(msg, sprintf(", ... (%d more)", n_only_merged - 10))
        }
        msg <- paste0(msg, "\n")
      }

      if (n_only_dsk > 0) {
        msg <- paste0(msg, sprintf(
          "  %d IDs exist in dataset %d (%s) but not in datasets 1-%d:\n",
          n_only_dsk, k, ds_k_name, k-1
        ))
        msg <- paste0(msg, "  ", paste(head(only_dsk, 10), collapse = ", "))
        if (n_only_dsk > 10) {
          msg <- paste0(msg, sprintf(", ... (%d more)", n_only_dsk - 10))
        }
        msg <- paste0(msg, "\n")
      }

      msg <- paste0(msg, "\nAll datasets must contain the same set of IDs.\n")
      msg <- paste0(msg, "IDs that don't match across datasets will be silently dropped during merge.\n")
      msg <- paste0(msg, "Use force = TRUE to proceed anyway (mismatched IDs will be dropped).\n")

      stop(msg)

    } else {
      # Force mode - warn and continue
      warning(sprintf(
        "\nID mismatch detected between datasets (proceeding due to force = TRUE)"
      ))

      if (n_only_merged > 0) {
        warning(sprintf(
          "  %d IDs exist in datasets 1-%d but not in dataset %d (%s)",
          n_only_merged, k-1, k, ds_k_name
        ))
        warning("  These IDs will be dropped from the merged result.")
      }

      if (n_only_dsk > 0) {
        warning(sprintf(
          "  %d IDs exist in dataset %d (%s) but not in datasets 1-%d",
          n_only_dsk, k, ds_k_name, k-1
        ))
        warning("  These IDs will be dropped from the merged result.")
      }

      warning("  Note: Only IDs present in ALL datasets will appear in the output.")
    }
  }

  return(invisible(NULL))
}


#' Cartesian merge with batch processing
#' @keywords internal
cartesian_merge_batch <- function(merged_data, ds_k, startname, stopname,
                                  exp_k_final, is_continuous_k,
                                  batch_pct = 20, k, verbose = TRUE) {
  # Create batch sequence
  unique_ids <- unique(merged_data$id)
  n_unique_ids <- length(unique_ids)

  # Calculate batch parameters
  batch_size <- ceiling(n_unique_ids * (batch_pct / 100))
  n_batches <- ceiling(n_unique_ids / batch_size)

  if (verbose) {
    message(sprintf(
      "Processing %d unique IDs in %d batches (batch size: %d IDs = %d%%)...",
      n_unique_ids, n_batches, batch_size, batch_pct
    ))
  }

  # Assign batch numbers to IDs
  id_batches <- data.frame(
    id = unique_ids,
    batch_num = rep(1:n_batches, each = batch_size, length.out = n_unique_ids)
  )

  # Process each batch
  batch_results <- list()

  for (b in 1:n_batches) {
    if (verbose) {
      message(sprintf("  Batch %d/%d...", b, n_batches))
    }

    # Get IDs for this batch
    batch_ids <- id_batches$id[id_batches$batch_num == b]

    # Filter merged data to this batch
    batch_merged <- merged_data %>%
      dplyr::filter(id %in% batch_ids)

    # Filter ds_k to this batch
    batch_k <- ds_k %>%
      dplyr::filter(id %in% batch_ids)

    # Perform Cartesian product using data.table for efficiency
    batch_merged_dt <- data.table::as.data.table(batch_merged)
    batch_k_dt <- data.table::as.data.table(batch_k)

    # Set keys for efficient join
    data.table::setkeyv(batch_merged_dt, "id")
    data.table::setkeyv(batch_k_dt, "id")

    # Cartesian join on id
    cartesian <- batch_merged_dt[batch_k_dt, allow.cartesian = TRUE]

    # Convert back to tibble
    cartesian <- tibble::as_tibble(cartesian)

    # Calculate interval intersection
    cartesian <- cartesian %>%
      dplyr::mutate(
        new_start = pmax(!!rlang::sym(startname), start_k),
        new_stop = pmin(!!rlang::sym(stopname), stop_k)
      )

    # Keep only valid intersections (where intervals overlap)
    cartesian <- cartesian %>%
      dplyr::filter(new_start <= new_stop,
                    !is.na(new_start),
                    !is.na(new_stop))

    # Replace old intervals with intersections
    cartesian <- cartesian %>%
      dplyr::mutate(
        !!rlang::sym(startname) := new_start,
        !!rlang::sym(stopname) := new_stop
      ) %>%
      dplyr::select(-new_start, -new_stop)

    # Handle continuous exposure interpolation
    if (is_continuous_k) {
      cartesian <- cartesian %>%
        dplyr::mutate(
          # Calculate proportion (convert to numeric if Date to avoid difftime issues)
          .proportion = ifelse(
            stop_k > start_k,
            as.numeric(!!rlang::sym(stopname) - !!rlang::sym(startname) + 1) /
              as.numeric(stop_k - start_k + 1),
            1
          ),
          # Ensure proportion doesn't exceed 1
          .proportion = pmin(.proportion, 1, na.rm = TRUE),
          # Interpolate exposure value
          !!rlang::sym(exp_k_final) := !!rlang::sym(exp_k_final) * .proportion
        ) %>%
        dplyr::select(-.proportion)
    }

    # Drop temporary columns
    cartesian <- cartesian %>%
      dplyr::select(-start_k, -stop_k)

    # Store batch result
    if (nrow(cartesian) > 0) {
      batch_results[[b]] <- cartesian
    } else {
      if (verbose) {
        message("    (batch produced no valid intersections)")
      }
    }
  }

  # Combine all batches
  if (length(batch_results) > 0) {
    result <- dplyr::bind_rows(batch_results)
  } else {
    # No valid intersections - return empty with proper structure
    result <- merged_data %>%
      dplyr::filter(FALSE) %>%
      dplyr::mutate(!!rlang::sym(exp_k_final) := numeric(0))
  }

  return(result)
}


#' Main merge loop for all datasets
#' @keywords internal
merge_all_datasets <- function(datasets, id, start, stop, exposure,
                               continuous_info, generate, prefix,
                               startname, stopname, keep_vars,
                               batch, force, verbose = TRUE) {
  numds <- length(datasets)

  # Determine final exposure names
  exp_final_names <- character(numds)
  for (i in 1:numds) {
    if (!is.null(generate)) {
      exp_final_names[i] <- generate[i]
    } else if (!is.null(prefix)) {
      exp_final_names[i] <- paste0(prefix, exposure[i])
    } else {
      exp_final_names[i] <- exposure[i]
    }
  }

  # Track which exposures are continuous
  is_continuous <- rep(FALSE, numds)
  is_continuous[continuous_info$positions] <- TRUE

  # Track invalid periods
  invalid_counts <- integer(numds)

  # Track keep variables
  keep_vars_found <- character(0)

  # ======= PROCESS FIRST DATASET =======
  ds1_result <- prepare_first_dataset(
    ds1 = datasets[[1]],
    id = id,
    start1 = start[1],
    stop1 = stop[1],
    exp1 = exposure[1],
    startname = startname,
    stopname = stopname,
    exp_final_name = exp_final_names[1],
    keep_vars = keep_vars
  )

  merged_data <- ds1_result$data
  invalid_counts[1] <- ds1_result$invalid_count

  # Track keep vars from dataset 1
  if (!is.null(keep_vars)) {
    for (var in keep_vars) {
      var_ds1 <- paste0(var, "_ds1")
      if (var_ds1 %in% names(merged_data)) {
        keep_vars_found <- union(keep_vars_found, var)
      }
    }
  }

  # ======= PROCESS ADDITIONAL DATASETS =======
  for (k in 2:numds) {
    if (verbose) {
      message(sprintf("\nMerging dataset %d of %d...", k, numds))
    }

    ds_k <- datasets[[k]]

    # Rename variables in dataset k
    ds_k_prep <- ds_k %>%
      dplyr::rename(
        id = !!rlang::sym(id),
        start_k = !!rlang::sym(start[k]),
        stop_k = !!rlang::sym(stop[k])
      )

    # Floor/ceil dates (only for numeric types, not Date)
    if (!inherits(ds_k_prep[["start_k"]], "Date")) {
      ds_k_prep <- ds_k_prep %>%
        dplyr::mutate(
          start_k = floor(start_k),
          stop_k = ceiling(stop_k)
        )
    }

    # Rename exposure
    ds_k_prep <- ds_k_prep %>%
      dplyr::rename(!!rlang::sym(exp_final_names[k]) := !!rlang::sym(exposure[k]))

    # Build keep list
    keep_list_k <- c("id", "start_k", "stop_k", exp_final_names[k])

    if (!is.null(keep_vars)) {
      for (var in keep_vars) {
        if (var %in% names(ds_k_prep)) {
          keep_vars_found <- union(keep_vars_found, var)

          new_name <- paste0(var, "_ds", k)
          ds_k_prep <- ds_k_prep %>%
            dplyr::rename(!!rlang::sym(new_name) := !!rlang::sym(var))
          keep_list_k <- c(keep_list_k, new_name)
        }
      }
    }

    # Keep only needed variables
    ds_k_prep <- ds_k_prep %>%
      dplyr::select(dplyr::all_of(keep_list_k))

    # Drop invalid periods
    invalid_counts[k] <- sum(
      ds_k_prep$start_k > ds_k_prep$stop_k |
      is.na(ds_k_prep$start_k) |
      is.na(ds_k_prep$stop_k)
    )

    ds_k_prep <- ds_k_prep %>%
      dplyr::filter(start_k <= stop_k,
                    !is.na(start_k),
                    !is.na(stop_k))

    # Sort
    ds_k_prep <- ds_k_prep %>%
      dplyr::arrange(id, start_k, stop_k)

    # VALIDATE ID MATCHING
    validate_id_matching(
      merged_data = merged_data,
      ds_k = ds_k_prep,
      force = force,
      k = k,
      ds_k_name = sprintf("dataset %d", k)
    )

    # PERFORM CARTESIAN MERGE
    merged_data <- cartesian_merge_batch(
      merged_data = merged_data,
      ds_k = ds_k_prep,
      startname = startname,
      stopname = stopname,
      exp_k_final = exp_final_names[k],
      is_continuous_k = is_continuous[k],
      batch_pct = batch,
      k = k,
      verbose = verbose
    )
  }

  # ======= VALIDATE KEEP VARIABLES =======
  if (!is.null(keep_vars)) {
    for (var in keep_vars) {
      if (!var %in% keep_vars_found) {
        stop(sprintf(
          "Variable '%s' specified in keep was not found in any dataset",
          var
        ))
      }
    }
  }

  # ======= FINAL CLEANUP =======

  # Count before deduplication
  n_before_dedup <- nrow(merged_data)

  # Drop exact duplicates
  dup_vars <- c("id", startname, stopname, exp_final_names)
  merged_data <- merged_data %>%
    dplyr::distinct(dplyr::across(dplyr::all_of(dup_vars)), .keep_all = TRUE)

  n_after_dedup <- nrow(merged_data)
  n_dups <- n_before_dedup - n_after_dedup

  # Sort final dataset
  merged_data <- merged_data %>%
    dplyr::arrange(id, !!rlang::sym(startname), !!rlang::sym(stopname))

  return(list(
    data = merged_data,
    invalid_counts = invalid_counts,
    n_duplicates = n_dups,
    exp_final_names = exp_final_names
  ))
}


# ============================================================================
# DIAGNOSTIC FUNCTIONS
# ============================================================================

#' Validate coverage (gap detection)
#' @keywords internal
validate_coverage <- function(data, id, startname, stopname) {
  gaps <- data %>%
    dplyr::group_by(!!rlang::sym(id)) %>%
    dplyr::arrange(!!rlang::sym(startname)) %>%
    dplyr::mutate(
      gap = !!rlang::sym(startname) - dplyr::lag(!!rlang::sym(stopname))
    ) %>%
    dplyr::filter(!is.na(gap), gap > 1) %>%
    dplyr::ungroup()

  n_gaps <- nrow(gaps)

  return(list(
    n_gaps = n_gaps,
    gap_data = gaps
  ))
}


#' Validate overlap detection
#' @keywords internal
validate_overlap <- function(data, id, startname, stopname, exposure_vars) {
  overlaps <- data %>%
    dplyr::group_by(!!rlang::sym(id)) %>%
    dplyr::arrange(!!rlang::sym(startname)) %>%
    dplyr::mutate(
      overlap = !!rlang::sym(startname) < dplyr::lag(!!rlang::sym(stopname)),
      same_exposures = TRUE
    ) %>%
    dplyr::ungroup()

  # Check if exposure values match with previous row
  for (exp_var in exposure_vars) {
    if (exp_var %in% names(data)) {
      overlaps <- overlaps %>%
        dplyr::group_by(!!rlang::sym(id)) %>%
        dplyr::arrange(!!rlang::sym(startname)) %>%
        dplyr::mutate(
          same_exposures = same_exposures &
            (is.na(overlap) | !overlap |
             !!rlang::sym(exp_var) == dplyr::lag(!!rlang::sym(exp_var)))
        ) %>%
        dplyr::ungroup()
    }
  }

  # Keep only unexpected overlaps
  overlaps <- overlaps %>%
    dplyr::filter(!is.na(overlap), overlap, same_exposures) %>%
    dplyr::select(-overlap, -same_exposures)

  n_overlaps <- nrow(overlaps)

  return(list(
    n_overlaps = n_overlaps,
    overlap_data = overlaps
  ))
}


#' Compute coverage diagnostics
#' @keywords internal
compute_diagnostics <- function(data, id, startname, stopname) {
  n_persons <- data %>%
    dplyr::summarize(n_distinct(!!rlang::sym(id))) %>%
    dplyr::pull()

  periods_per_person <- data %>%
    dplyr::group_by(!!rlang::sym(id)) %>%
    dplyr::summarize(n_periods = dplyr::n()) %>%
    dplyr::ungroup()

  avg_periods <- mean(periods_per_person$n_periods)
  max_periods <- max(periods_per_person$n_periods)

  return(list(
    n_persons = n_persons,
    avg_periods = avg_periods,
    max_periods = max_periods
  ))
}


# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

#' Display coverage diagnostics
#' @keywords internal
display_diagnostics <- function(diagnostics, n_obs) {
  cat("\n")
  cat(strrep("-", 50), "\n")
  cat("Coverage Diagnostics:\n")
  cat(sprintf("    Number of persons: %d\n", diagnostics$n_persons))
  cat(sprintf("    Average periods per person: %.2f\n", diagnostics$avg_periods))
  cat(sprintf("    Max periods per person: %d\n", diagnostics$max_periods))
  cat(sprintf("    Total merged intervals: %d\n", n_obs))
  cat(strrep("-", 50), "\n")
}


#' Display gap validation
#' @keywords internal
display_gap_validation <- function(coverage_validation, startname, stopname) {
  cat("\n")
  cat(strrep("-", 50), "\n")
  cat("Validating coverage...\n")

  if (coverage_validation$n_gaps > 0) {
    cat(sprintf(
      "Found %d gaps in coverage (>1 day gaps)\n",
      coverage_validation$n_gaps
    ))

    # Display first 20 gaps
    print(head(coverage_validation$gap_data, 20))
  } else {
    cat("No gaps >1 day found in coverage.\n")
  }

  cat(strrep("-", 50), "\n")
}


#' Display overlap validation
#' @keywords internal
display_overlap_validation <- function(overlap_validation) {
  cat("\n")
  cat(strrep("-", 50), "\n")
  cat("Validating overlaps...\n")

  if (overlap_validation$n_overlaps > 0) {
    cat(sprintf(
      "Found %d unexpected overlapping periods (same interval, same exposures)\n",
      overlap_validation$n_overlaps
    ))

    # Display first 20 overlaps
    print(head(overlap_validation$overlap_data, 20))
  } else {
    cat("No unexpected overlaps found.\n")
  }

  cat(strrep("-", 50), "\n")
}


#' Display summary statistics
#' @keywords internal
display_summary_stats <- function(data, startname, stopname) {
  cat("\n")
  cat(strrep("-", 50), "\n")
  cat("Summary Statistics:\n")

  cat("\nStart dates:\n")
  print(summary(data[[startname]]))

  cat("\nStop dates:\n")
  print(summary(data[[stopname]]))

  cat(strrep("-", 50), "\n")
}


#' Display final summary
#' @keywords internal
display_final_summary <- function(n_obs, n_persons, exposure_vars) {
  cat("\n")
  cat("Merged time-varying dataset successfully created\n")
  cat(strrep("-", 50), "\n")
  cat(sprintf("    Observations: %s\n", format(n_obs, big.mark = ",")))
  cat(sprintf("    Persons: %s\n", format(n_persons, big.mark = ",")))
  cat(sprintf("    Exposure variables: %s\n", paste(exposure_vars, collapse = ", ")))
  cat(strrep("-", 50), "\n")
}


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

#' Check and load required packages
#' @keywords internal
require_packages <- function() {
  required <- c("dplyr", "tibble", "data.table", "haven", "rlang")

  for (pkg in required) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(sprintf("Package '%s' is required but not installed. Install with: install.packages('%s')",
                   pkg, pkg))
    }
  }

  # Load packages
  suppressPackageStartupMessages({
    library(dplyr)
    library(tibble)
    library(data.table)
    library(haven)
    library(rlang)
  })
}
