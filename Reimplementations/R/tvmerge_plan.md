# tvmerge R Reimplementation Plan

## Overview

`tvmerge` merges multiple time-varying exposure datasets (created by `tvexpose`) by computing the Cartesian product of overlapping time periods. This creates all possible combinations of exposure values across datasets for each person.

**Core Algorithm**: For each person, find all temporal overlaps between datasets and create new time intervals representing the intersection of those overlaps, carrying forward the exposure values from each source dataset.

## Function Signature

```r
tvmerge <- function(
  datasets,              # Character vector of dataset names or list of data.frames
  id,                    # Character: name of ID variable (same across all datasets)
  start,                 # Character vector: start date variable names (one per dataset)
  stop,                  # Character vector: stop date variable names (one per dataset)
  exposure,              # Character vector: exposure variable names (one per dataset)
  continuous = NULL,     # Character vector or numeric vector: which exposures are continuous
  generate = NULL,       # Character vector: new names for exposure variables (length = n datasets)
  prefix = NULL,         # Character: prefix for all exposure variables (mutually exclusive with generate)
  startname = "start",   # Character: name for output start variable
  stopname = "stop",     # Character: name for output stop variable
  dateformat = NULL,     # Character: date format string (not used in R, kept for compatibility)
  saveas = NULL,         # Character: filename to save result
  keep = NULL,           # Character vector: additional variables to keep from sources
  batch = 20,            # Numeric: percentage of IDs per batch (1-100)
  force = FALSE,         # Logical: allow mismatched IDs between datasets
  check = FALSE,         # Logical: display coverage diagnostics
  validatecoverage = FALSE,  # Logical: check for gaps >1 day
  validateoverlap = FALSE,   # Logical: check for unexpected overlaps
  summarize = FALSE      # Logical: display summary statistics
) {
  # Returns a list with:
  #   $data: merged data.frame
  #   $diagnostics: list of diagnostic information
  #   $returns: list of return values (mimicking Stata's r() storage)
}
```

## Input Validation Requirements

### 1. Dataset Validation

```r
# Validate datasets parameter
validate_datasets <- function(datasets) {
  # Accept either:
  #   - Character vector of .dta filenames (with or without .dta extension)
  #   - List of data.frames
  #   - Mix of both

  # Minimum 2 datasets required
  if (length(datasets) < 2) {
    stop("tvmerge requires at least 2 datasets")
  }

  # Load datasets into a list of data.frames
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
  }

  return(loaded_datasets)
}
```

### 2. Variable Validation

```r
# Validate that all required variables exist in each dataset
validate_variables <- function(datasets, id, start, stop, exposure) {
  numds <- length(datasets)

  # Validate start/stop/exposure counts match dataset count
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

    # Check ID variable
    if (!id %in% names(ds)) {
      stop(sprintf("Variable '%s' not found in %s", id, ds_label))
    }

    # Check start variable
    if (!start[i] %in% names(ds)) {
      stop(sprintf("Variable '%s' not found in %s", start[i], ds_label))
    }

    # Check stop variable
    if (!stop[i] %in% names(ds)) {
      stop(sprintf("Variable '%s' not found in %s", stop[i], ds_label))
    }

    # Check exposure variable
    if (!exposure[i] %in% names(ds)) {
      stop(sprintf("Variable '%s' not found in %s", exposure[i], ds_label))
    }
  }
}
```

### 3. Naming Options Validation

```r
validate_naming_options <- function(generate, prefix, numds, exposure) {
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

  # Validate startname/stopname
  if (!is.null(startname)) {
    if (!grepl("^[a-zA-Z][a-zA-Z0-9._]*$", startname)) {
      stop(sprintf("startname contains invalid R name: %s", startname))
    }
  }

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
```

### 4. Continuous Exposure Validation

```r
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
```

### 5. Batch Parameter Validation

```r
validate_batch <- function(batch) {
  if (!is.numeric(batch) || length(batch) != 1) {
    stop("batch must be a single numeric value")
  }

  if (batch < 1 || batch > 100) {
    stop("batch must be between 1 and 100 (percentage of IDs per batch)")
  }

  return(as.integer(batch))
}
```

## Core Algorithm Implementation

### 1. Prepare First Dataset

```r
prepare_first_dataset <- function(ds1, id, start1, stop1, exp1,
                                  startname, stopname, exp_final_name,
                                  keep_vars = NULL) {
  # Rename core variables to standard names
  result <- ds1 %>%
    rename(
      id = !!sym(id),
      !!sym(startname) := !!sym(start1),
      !!sym(stopname) := !!sym(stop1)
    )

  # Floor start dates, ceil stop dates (handles fractional date values)
  result <- result %>%
    mutate(
      !!sym(startname) := floor(!!sym(startname)),
      !!sym(stopname) := ceiling(!!sym(stopname))
    )

  # Rename exposure variable
  result <- result %>%
    rename(!!sym(exp_final_name) := !!sym(exp1))

  # Process keep() variables
  keep_list <- c("id", startname, stopname, exp_final_name)

  if (!is.null(keep_vars)) {
    for (var in keep_vars) {
      if (var %in% names(result)) {
        # Rename with _ds1 suffix
        new_name <- paste0(var, "_ds1")
        result <- result %>%
          rename(!!sym(new_name) := !!sym(var))
        keep_list <- c(keep_list, new_name)
      }
    }
  }

  # Keep only necessary variables
  result <- result %>%
    select(all_of(keep_list))

  # Drop invalid periods (start > stop)
  # Keep point-in-time observations (start == stop)
  invalid_count <- sum(result[[startname]] > result[[stopname]] |
                      is.na(result[[startname]]) |
                      is.na(result[[stopname]]))

  result <- result %>%
    filter(!!sym(startname) <= !!sym(stopname),
           !is.na(!!sym(startname)),
           !is.na(!!sym(stopname)))

  # Sort
  result <- result %>%
    arrange(id, !!sym(startname), !!sym(stopname))

  return(list(
    data = result,
    invalid_count = invalid_count
  ))
}
```

### 2. ID Matching Validation

```r
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
```

### 3. Cartesian Merge with Batch Processing

This is the core algorithm that performs the Cartesian product of overlapping time intervals.

```r
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
      filter(id %in% batch_ids)

    # Filter ds_k to this batch
    batch_k <- ds_k %>%
      filter(id %in% batch_ids)

    # Perform Cartesian product using data.table for efficiency
    # This is equivalent to Stata's joinby
    batch_merged_dt <- data.table::as.data.table(batch_merged)
    batch_k_dt <- data.table::as.data.table(batch_k)

    # Set keys for efficient join
    data.table::setkeyv(batch_merged_dt, "id")
    data.table::setkeyv(batch_k_dt, "id")

    # Cartesian join on id
    # This creates all combinations within each id
    cartesian <- batch_merged_dt[batch_k_dt, allow.cartesian = TRUE]

    # Convert back to data.frame/tibble
    cartesian <- as_tibble(cartesian)

    # Calculate interval intersection
    cartesian <- cartesian %>%
      mutate(
        new_start = pmax(!!sym(startname), start_k),
        new_stop = pmin(!!sym(stopname), stop_k)
      )

    # Keep only valid intersections (where intervals overlap)
    cartesian <- cartesian %>%
      filter(new_start <= new_stop,
             !is.na(new_start),
             !is.na(new_stop))

    # Replace old intervals with intersections
    cartesian <- cartesian %>%
      mutate(
        !!sym(startname) := new_start,
        !!sym(stopname) := new_stop
      ) %>%
      select(-new_start, -new_stop)

    # Handle continuous exposure interpolation
    if (is_continuous_k) {
      # For continuous exposures: interpolate based on overlap duration
      # Formula: exposure * (overlap_duration / original_duration)

      cartesian <- cartesian %>%
        mutate(
          # Calculate proportion
          .proportion = ifelse(
            stop_k > start_k,
            (!!sym(stopname) - !!sym(startname) + 1) / (stop_k - start_k + 1),
            1
          ),
          # Ensure proportion doesn't exceed 1 (floating point protection)
          .proportion = pmin(.proportion, 1, na.rm = TRUE),
          # Interpolate exposure value
          !!sym(exp_k_final) := !!sym(exp_k_final) * .proportion
        ) %>%
        select(-.proportion)
    }

    # Drop temporary start_k and stop_k columns
    cartesian <- cartesian %>%
      select(-start_k, -stop_k)

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
    result <- bind_rows(batch_results)
  } else {
    # No valid intersections at all - return empty data.frame with proper structure
    result <- merged_data %>%
      filter(FALSE) %>%  # Keep structure but no rows
      mutate(!!sym(exp_k_final) := numeric(0))
  }

  return(result)
}
```

### 4. Main Merge Loop

```r
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

  # Track invalid periods from each dataset
  invalid_counts <- integer(numds)

  # Track which keep variables were found
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
      rename(
        id = !!sym(id),
        start_k = !!sym(start[k]),
        stop_k = !!sym(stop[k])
      )

    # Floor/ceil dates
    ds_k_prep <- ds_k_prep %>%
      mutate(
        start_k = floor(start_k),
        stop_k = ceiling(stop_k)
      )

    # Rename exposure
    ds_k_prep <- ds_k_prep %>%
      rename(!!sym(exp_final_names[k]) := !!sym(exposure[k]))

    # Build keep list for this dataset
    keep_list_k <- c("id", "start_k", "stop_k", exp_final_names[k])

    if (!is.null(keep_vars)) {
      for (var in keep_vars) {
        if (var %in% names(ds_k_prep)) {
          # Track that we found it
          keep_vars_found <- union(keep_vars_found, var)

          # Rename with suffix
          new_name <- paste0(var, "_ds", k)
          ds_k_prep <- ds_k_prep %>%
            rename(!!sym(new_name) := !!sym(var))
          keep_list_k <- c(keep_list_k, new_name)
        }
      }
    }

    # Keep only needed variables
    ds_k_prep <- ds_k_prep %>%
      select(all_of(keep_list_k))

    # Drop invalid periods
    invalid_counts[k] <- sum(
      ds_k_prep$start_k > ds_k_prep$stop_k |
      is.na(ds_k_prep$start_k) |
      is.na(ds_k_prep$stop_k)
    )

    ds_k_prep <- ds_k_prep %>%
      filter(start_k <= stop_k,
             !is.na(start_k),
             !is.na(stop_k))

    # Sort
    ds_k_prep <- ds_k_prep %>%
      arrange(id, start_k, stop_k)

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
  # Duplicates are rows with same id, start, stop, AND all exposure values
  dup_vars <- c("id", startname, stopname, exp_final_names)
  merged_data <- merged_data %>%
    distinct(across(all_of(dup_vars)), .keep_all = TRUE)

  n_after_dedup <- nrow(merged_data)
  n_dups <- n_before_dedup - n_after_dedup

  # Sort final dataset
  merged_data <- merged_data %>%
    arrange(id, !!sym(startname), !!sym(stopname))

  return(list(
    data = merged_data,
    invalid_counts = invalid_counts,
    n_duplicates = n_dups,
    exp_final_names = exp_final_names
  ))
}
```

## Diagnostic Functions

### 1. Coverage Validation (Gap Detection)

```r
validate_coverage <- function(data, id, startname, stopname) {
  # Check for gaps > 1 day between consecutive periods within each person

  gaps <- data %>%
    group_by(!!sym(id)) %>%
    arrange(!!sym(startname)) %>%
    mutate(
      gap = !!sym(startname) - lag(!!sym(stopname))
    ) %>%
    filter(!is.na(gap), gap > 1) %>%
    ungroup()

  n_gaps <- nrow(gaps)

  return(list(
    n_gaps = n_gaps,
    gap_data = gaps
  ))
}
```

### 2. Overlap Validation

```r
validate_overlap <- function(data, id, startname, stopname, exposure_vars) {
  # Check for overlapping periods with IDENTICAL exposure values
  # (overlaps with different exposures are expected in Cartesian merges)

  overlaps <- data %>%
    group_by(!!sym(id)) %>%
    arrange(!!sym(startname)) %>%
    mutate(
      overlap = !!sym(startname) < lag(!!sym(stopname)),
      same_exposures = TRUE
    ) %>%
    ungroup()

  # For each exposure variable, check if values match with previous row
  for (exp_var in exposure_vars) {
    if (exp_var %in% names(data)) {
      overlaps <- overlaps %>%
        group_by(!!sym(id)) %>%
        arrange(!!sym(startname)) %>%
        mutate(
          same_exposures = same_exposures &
            (is.na(overlap) | !overlap |
             !!sym(exp_var) == lag(!!sym(exp_var)))
        ) %>%
        ungroup()
    }
  }

  # Keep only unexpected overlaps (same exposure values)
  overlaps <- overlaps %>%
    filter(!is.na(overlap), overlap, same_exposures) %>%
    select(-overlap, -same_exposures)

  n_overlaps <- nrow(overlaps)

  return(list(
    n_overlaps = n_overlaps,
    overlap_data = overlaps
  ))
}
```

### 3. Coverage Diagnostics

```r
compute_diagnostics <- function(data, id, startname, stopname) {
  # Number of persons
  n_persons <- data %>%
    summarize(n_distinct(!!sym(id))) %>%
    pull()

  # Periods per person
  periods_per_person <- data %>%
    group_by(!!sym(id)) %>%
    summarize(n_periods = n()) %>%
    ungroup()

  avg_periods <- mean(periods_per_person$n_periods)
  max_periods <- max(periods_per_person$n_periods)

  return(list(
    n_persons = n_persons,
    avg_periods = avg_periods,
    max_periods = max_periods
  ))
}
```

## Display Functions

### 1. Display Coverage Diagnostics

```r
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
```

### 2. Display Gap Validation

```r
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
```

### 3. Display Overlap Validation

```r
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
```

### 4. Display Summary Statistics

```r
display_summary_stats <- function(data, startname, stopname) {
  cat("\n")
  cat(strrep("-", 50), "\n")
  cat("Summary Statistics:\n")

  # Summary of start and stop dates
  cat("\nStart dates:\n")
  print(summary(data[[startname]]))

  cat("\nStop dates:\n")
  print(summary(data[[stopname]]))

  cat(strrep("-", 50), "\n")
}
```

### 5. Display Final Summary

```r
display_final_summary <- function(n_obs, n_persons, exposure_vars) {
  cat("\n")
  cat("Merged time-varying dataset successfully created\n")
  cat(strrep("-", 50), "\n")
  cat(sprintf("    Observations: %s\n", format(n_obs, big.mark = ",")))
  cat(sprintf("    Persons: %s\n", format(n_persons, big.mark = ",")))
  cat(sprintf("    Exposure variables: %s\n", paste(exposure_vars, collapse = ", ")))
  cat(strrep("-", 50), "\n")
}
```

## Return Value Structure

The function should return a list with three components:

```r
return(list(
  # Main result: merged data.frame
  data = merged_data,

  # Diagnostics information
  diagnostics = list(
    n_persons = n_persons,
    avg_periods = avg_periods,
    max_periods = max_periods,
    invalid_counts = invalid_counts,
    n_duplicates = n_dups,
    coverage_validation = coverage_validation,  # If validatecoverage = TRUE
    overlap_validation = overlap_validation     # If validateoverlap = TRUE
  ),

  # Stata-style return values (for compatibility)
  returns = list(
    N = nrow(merged_data),
    N_persons = n_persons,
    mean_periods = avg_periods,
    max_periods = max_periods,
    N_datasets = numds,
    datasets = datasets_names,
    exposure_vars = exp_final_names,
    continuous_vars = continuous_names,  # If continuous specified
    categorical_vars = categorical_names,
    n_continuous = length(continuous_names),
    n_categorical = length(categorical_names),
    startname = startname,
    stopname = stopname,
    prefix = prefix,             # If used
    generated_names = generate,  # If used
    output_file = saveas         # If used
  )
))
```

## Error Handling Strategy

### Critical Error Cases (stop execution)

1. **Dataset validation failures**
   - Fewer than 2 datasets
   - File not found
   - File not a valid Stata dataset
   - Cannot read file

2. **Variable validation failures**
   - ID variable missing from any dataset
   - Start/stop/exposure variable missing from its dataset
   - Wrong number of start/stop/exposure variables
   - Duplicate exposure names

3. **Naming conflicts**
   - Both generate and prefix specified
   - Invalid variable names in generate/prefix
   - startname == stopname

4. **Continuous exposure specification errors**
   - Position out of range
   - Variable name not in exposure list

5. **ID matching failures (when force = FALSE)**
   - IDs don't match across datasets
   - Display which IDs are mismatched
   - Suggest using force = TRUE

6. **Keep variable errors**
   - Variable specified in keep() not found in any dataset

### Warning Cases (continue with warning)

1. **Invalid periods** (start > stop)
   - Display count per dataset
   - Drop and continue

2. **Duplicates found**
   - Display count
   - Drop and continue

3. **ID mismatches (when force = TRUE)**
   - Display warning with counts
   - Continue with intersection of IDs

4. **Empty batch results**
   - Display message that batch produced no intersections
   - Continue

## Testing Strategy

### Unit Tests

1. **Input validation tests**
   ```r
   test_that("rejects fewer than 2 datasets", {
     expect_error(tvmerge(list(df1), ...))
   })

   test_that("rejects missing ID variable", {
     expect_error(tvmerge(list(df1, df2), id = "nonexistent", ...))
   })

   test_that("rejects duplicate exposure names", {
     expect_error(tvmerge(..., exposure = c("exp1", "exp1")))
   })
   ```

2. **Cartesian merge tests**
   ```r
   test_that("creates all combinations of overlapping periods", {
     # Person 1: 2 HRT periods, 3 DMT periods with overlap
     # Should produce 2 * 3 = 6 output periods
   })

   test_that("handles non-overlapping periods correctly", {
     # Person 1: HRT period 1-10, DMT period 20-30
     # Should produce 0 output periods for person 1
   })
   ```

3. **Continuous exposure tests**
   ```r
   test_that("interpolates continuous exposures correctly", {
     # Exposure rate = 10 per day, period 1-10 (10 days)
     # Overlap period 3-7 (5 days)
     # Expected value: 10 * (5/10) = 5
   })
   ```

4. **Date handling tests**
   ```r
   test_that("floors start dates and ceils stop dates", {
     # Input: start = 1.5, stop = 10.3
     # Expected: start = 1, stop = 11
   })
   ```

### Integration Tests

1. **Two-dataset merge**
   - Basic overlap
   - Partial overlap
   - No overlap
   - Complete overlap

2. **Three-dataset merge**
   - All three overlap
   - Only two overlap
   - No overlaps

3. **Batch processing**
   - Verify identical results with batch(10), batch(50), batch(100)
   - Test with different numbers of IDs

4. **Real-world scenarios**
   - HRT + DMT merge (categorical)
   - Drug dosages (continuous)
   - Mixed categorical + continuous

### Edge Case Tests

1. **Empty datasets**
   - One dataset has no observations
   - All datasets empty after validation

2. **Single observation**
   - One person, one period in each dataset

3. **Point-in-time observations**
   - start == stop (should be valid)

4. **Large datasets**
   - 10,000+ IDs
   - 100+ periods per person

5. **Missing values**
   - Missing exposure values (should be retained)
   - Missing dates (should be dropped with warning)

6. **ID matching edge cases**
   - Complete mismatch
   - Partial mismatch with force = TRUE
   - String vs numeric IDs

## Example Usage

### Basic Two-Dataset Merge

```r
library(tvtools)  # Hypothetical R package
library(haven)
library(dplyr)

# Assume tv_hrt.dta and tv_dmt.dta already created by tvexpose equivalent

result <- tvmerge(
  datasets = c("tv_hrt.dta", "tv_dmt.dta"),
  id = "id",
  start = c("rx_start", "dmt_start"),
  stop = c("rx_stop", "dmt_stop"),
  exposure = c("tv_exposure", "tv_exposure"),
  generate = c("hrt", "dmt_type")
)

# Access merged data
merged_data <- result$data

# View diagnostics
print(result$returns)
```

### With Continuous Exposures

```r
result <- tvmerge(
  datasets = c("tv_hrt.dta", "tv_dosage.dta"),
  id = "id",
  start = c("rx_start", "dose_start"),
  stop = c("rx_stop", "dose_stop"),
  exposure = c("hrt_type", "dosage_rate"),
  continuous = c(2),  # Position 2 (dosage_rate) is continuous
  generate = c("hrt", "dose")
)

# Result will have columns: id, start, stop, hrt, dose
# dose contains interpolated values based on overlap duration
```

### With Validation

```r
result <- tvmerge(
  datasets = c("tv_hrt.dta", "tv_dmt.dta"),
  id = "id",
  start = c("rx_start", "dmt_start"),
  stop = c("rx_stop", "dmt_stop"),
  exposure = c("tv_exposure", "tv_exposure"),
  generate = c("hrt", "dmt_type"),
  check = TRUE,
  validatecoverage = TRUE,
  validateoverlap = TRUE,
  summarize = TRUE
)

# Diagnostics printed to console
# Also available in result$diagnostics
```

### Save Output

```r
result <- tvmerge(
  datasets = c("tv_hrt.dta", "tv_dmt.dta"),
  id = "id",
  start = c("rx_start", "dmt_start"),
  stop = c("rx_stop", "dmt_stop"),
  exposure = c("tv_exposure", "tv_exposure"),
  generate = c("hrt", "dmt_type"),
  saveas = "merged_exposures.dta"
)

# Output saved as Stata dataset using haven::write_dta()
```

## Performance Considerations

### Memory Efficiency

1. **Batch processing**
   - Default 20% batch size balances memory and I/O
   - Larger batches (50-100%) for systems with more RAM
   - Smaller batches (10-20%) for memory-constrained systems

2. **data.table usage**
   - Use data.table for Cartesian joins (much faster than base R)
   - Convert to tibble for return (user-friendly)

3. **Avoid copying**
   - Use references where possible
   - Only duplicate when necessary

### Computational Efficiency

1. **Vectorized operations**
   - Use dplyr/data.table vectorized functions
   - Avoid row-wise operations where possible

2. **Pre-computation**
   - Pre-compute continuous exposure flags
   - Calculate batch assignments once

3. **Early filtering**
   - Drop invalid periods before merge
   - Filter to batch IDs before Cartesian product

### Expected Performance

| Dataset Size | IDs | Periods/ID | Batch % | Expected Time |
|-------------|-----|-----------|---------|---------------|
| Small | 100 | 10 | 20 | < 1 second |
| Medium | 1,000 | 20 | 20 | 5-10 seconds |
| Large | 10,000 | 30 | 20 | 1-2 minutes |
| Very Large | 50,000 | 50 | 10 | 5-15 minutes |

## Dependencies

### Required R Packages

```r
# Data manipulation
library(dplyr)      # Data manipulation
library(tibble)     # Modern data frames
library(tidyr)      # Data tidying
library(data.table) # Fast Cartesian joins

# Stata I/O
library(haven)      # Read/write Stata datasets

# Utilities
library(rlang)      # Tidy evaluation
```

### Optional Packages

```r
# For testing
library(testthat)   # Unit tests

# For progress bars (if implementing)
library(progress)   # Progress reporting
```

## Implementation Notes for Sonnet

### Critical Algorithm Details

1. **Cartesian Product Logic**
   - The core operation is `joinby` in Stata, equivalent to a Cartesian join in SQL/data.table
   - Within each ID, create ALL combinations of periods from dataset A and dataset B
   - Then filter to keep only overlapping combinations

2. **Interval Intersection Formula**
   ```
   new_start = max(start_A, start_B)
   new_stop = min(stop_A, stop_B)

   Keep if: new_start <= new_stop  (i.e., intervals overlap)
   ```

3. **Continuous Exposure Interpolation**
   ```
   overlap_duration = new_stop - new_start + 1
   original_duration = stop_B - start_B + 1
   proportion = overlap_duration / original_duration
   interpolated_value = original_value * proportion
   ```

   Important: Proportion must be capped at 1.0 to handle floating-point rounding

4. **Batch Processing Strategy**
   - Split unique IDs into batches (NOT observations)
   - Process each batch completely before moving to next
   - Combine results at end
   - This minimizes memory usage while maintaining correctness

5. **Date Handling**
   - Floor start dates (rounds down)
   - Ceiling stop dates (rounds up)
   - This ensures no partial days are lost due to fractional date values

### Common Pitfalls to Avoid

1. **Don't merge on time intervals directly**
   - The merge is NOT a range join
   - It's a Cartesian product by ID, then filter by overlap

2. **Don't forget to validate ID matching**
   - Stata's joinby silently drops non-matching IDs
   - We need to explicitly warn/error when IDs don't match

3. **Don't confuse exposure positions with dataset positions**
   - In the future, datasets might have multiple exposures
   - Track positions carefully

4. **Handle empty results gracefully**
   - A batch might produce zero valid intersections
   - An entire merge might produce zero rows if datasets don't overlap
   - Preserve structure even with 0 rows

5. **Point-in-time observations are valid**
   - start == stop is valid (e.g., lab measurement on single day)
   - Only drop when start > stop

### Testing Priority

High priority tests (implement first):
1. Basic 2-dataset merge with perfect overlap
2. Basic 2-dataset merge with partial overlap
3. Basic 2-dataset merge with no overlap
4. Continuous exposure interpolation
5. ID mismatch validation (force = FALSE and force = TRUE)

Medium priority:
1. 3-dataset merge
2. Batch processing consistency
3. Keep variables with suffixes
4. Custom naming (generate, prefix)

Lower priority (nice to have):
1. Coverage validation
2. Overlap validation
3. Summary statistics
4. Large dataset performance

## Summary

This implementation plan provides a complete specification for reimplementing tvmerge in R. The core algorithm is:

1. Load and validate all datasets
2. Prepare first dataset (rename, floor/ceil dates, filter invalid)
3. For each additional dataset:
   - Prepare dataset (rename, floor/ceil dates, filter invalid)
   - Validate ID matching
   - Perform batch-wise Cartesian merge
   - Calculate interval intersections
   - Filter to valid overlaps
   - Interpolate continuous exposures
4. Remove duplicates
5. Sort and return

The key insight is that this is NOT a traditional merge—it's a Cartesian product of time intervals within each ID, filtered to overlapping periods. The batch processing is essential for performance with large datasets.
