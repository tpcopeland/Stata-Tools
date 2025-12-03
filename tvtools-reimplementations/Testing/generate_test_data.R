# Generate Synthetic Test Data for tvtools Testing
# This script creates comprehensive test data for tvexpose, tvmerge, and tvevent

set.seed(12345)

# 1. Master Cohort Data (100 persons)
# Required for tvexpose: id, entry, exit
cohort <- data.frame(
  patient_id = 1:100,
  study_entry = as.Date("2015-01-01") + sample(0:365, 100, replace = TRUE),
  study_exit = as.Date("2015-01-01") + sample(1096:2190, 100, replace = TRUE),  # 3-6 years follow-up
  age = sample(40:75, 100, replace = TRUE),
  sex = sample(c("M", "F"), 100, replace = TRUE),
  stringsAsFactors = FALSE
)

# 2. Medication Exposure Data (for tvexpose testing)
# Multiple prescriptions per person, some overlapping
exposure_list <- list()
counter <- 1

for (id in 1:100) {
  entry <- cohort$study_entry[id]
  exit <- cohort$study_exit[id]

  # Random number of prescriptions (0-5)
  n_prescriptions <- sample(0:5, 1, prob = c(0.1, 0.15, 0.25, 0.25, 0.15, 0.1))

  if (n_prescriptions > 0) {
    for (j in 1:n_prescriptions) {
      rx_start <- entry + sample(0:as.numeric(exit - entry - 90), 1)
      rx_duration <- sample(30:365, 1)  # 1-12 months
      rx_stop <- min(rx_start + rx_duration, exit)

      exposure_list[[counter]] <- data.frame(
        patient_id = id,
        rx_start = rx_start,
        rx_stop = rx_stop,
        drug_type = sample(1:3, 1),  # 3 different drug types
        stringsAsFactors = FALSE
      )
      counter <- counter + 1
    }
  }
}

exposures <- do.call(rbind, exposure_list)

# 3. Second Exposure Dataset (for tvmerge testing)
# Different exposure with different timing
exposure2_list <- list()
counter <- 1

for (id in 1:100) {
  entry <- cohort$study_entry[id]
  exit <- cohort$study_exit[id]

  # Random number of treatment periods (0-4)
  n_periods <- sample(0:4, 1, prob = c(0.15, 0.25, 0.3, 0.2, 0.1))

  if (n_periods > 0) {
    for (j in 1:n_periods) {
      treat_start <- entry + sample(0:as.numeric(exit - entry - 60), 1)
      treat_duration <- sample(60:180, 1)  # 2-6 months
      treat_stop <- min(treat_start + treat_duration, exit)

      exposure2_list[[counter]] <- data.frame(
        patient_id = id,
        treatment_start = treat_start,
        treatment_stop = treat_stop,
        treatment_type = sample(c("A", "B", "C"), 1),
        dosage = sample(c(10, 20, 30, 40), 1),  # Continuous variable
        stringsAsFactors = FALSE
      )
      counter <- counter + 1
    }
  }
}

exposures2 <- do.call(rbind, exposure2_list)

# 4. Events Data (for tvevent testing)
# Primary events and competing risks
events_list <- list()

for (id in 1:100) {
  entry <- cohort$study_entry[id]
  exit <- cohort$study_exit[id]

  # 30% chance of primary event (MI)
  mi_date <- NA
  if (runif(1) < 0.30) {
    mi_date <- entry + sample(30:as.numeric(exit - entry), 1)
  }

  # 20% chance of death (competing risk)
  death_date <- NA
  if (runif(1) < 0.20) {
    death_date <- entry + sample(60:as.numeric(exit - entry), 1)
  }

  # 10% chance of emigration (competing risk)
  emigration_date <- NA
  if (runif(1) < 0.10) {
    emigration_date <- entry + sample(90:as.numeric(exit - entry), 1)
  }

  events_list[[id]] <- data.frame(
    patient_id = id,
    mi_date = mi_date,
    death_date = death_date,
    emigration_date = emigration_date,
    stringsAsFactors = FALSE
  )
}

events <- do.call(rbind, events_list)

# Convert dates back to character for CSV compatibility
cohort$study_entry <- as.character(cohort$study_entry)
cohort$study_exit <- as.character(cohort$study_exit)
exposures$rx_start <- as.character(exposures$rx_start)
exposures$rx_stop <- as.character(exposures$rx_stop)
exposures2$treatment_start <- as.character(exposures2$treatment_start)
exposures2$treatment_stop <- as.character(exposures2$treatment_stop)
events$mi_date <- as.character(events$mi_date)
events$death_date <- as.character(events$death_date)
events$emigration_date <- as.character(events$emigration_date)

# Save to CSV files
write.csv(cohort, "cohort.csv", row.names = FALSE, na = "")
write.csv(exposures, "exposures.csv", row.names = FALSE, na = "")
write.csv(exposures2, "exposures2.csv", row.names = FALSE, na = "")
write.csv(events, "events.csv", row.names = FALSE, na = "")

# Print summary
cat("\n=== Synthetic Test Data Generated ===\n\n")
cat("1. cohort.csv:\n")
cat("   - 100 persons\n")
cat("   - Columns: patient_id, study_entry, study_exit, age, sex\n\n")

cat("2. exposures.csv:\n")
cat("   - ", nrow(exposures), " exposure records\n", sep = "")
cat("   - Columns: patient_id, rx_start, rx_stop, drug_type\n")
cat("   - Drug types: 1, 2, 3\n\n")

cat("3. exposures2.csv:\n")
cat("   - ", nrow(exposures2), " treatment records\n", sep = "")
cat("   - Columns: patient_id, treatment_start, treatment_stop, treatment_type, dosage\n")
cat("   - Treatment types: A, B, C\n")
cat("   - Dosage (continuous): 10, 20, 30, 40\n\n")

cat("4. events.csv:\n")
cat("   - 100 persons\n")
cat("   - Columns: patient_id, mi_date, death_date, emigration_date\n")
cat("   - MI events: ", sum(!is.na(events$mi_date)), "\n", sep = "")
cat("   - Deaths: ", sum(!is.na(events$death_date)), "\n", sep = "")
cat("   - Emigrations: ", sum(!is.na(events$emigration_date)), "\n\n", sep = "")

cat("Files saved to current directory.\n")
