######################
# Topic: Master file
# Purpose: Orchestrate setting up, connection validation and indicator calculation workflow
# Author: One Tech Agency
######################

# step 1: Configuration and setting up the workspace
message("\n--- Step 1: Loading configurations ---")
tryCatch({
  source("R/00_config.R")
  message("SUCCESS: Configuration loaded.")
}, error = function(e) {
  stop("FATAL ERROR in 00_config.R: ", e$message)
})

# step 2: Data ingestion from KoboToolbox API
message("\n--- Step 2: Fetching KoboToolbox API ---")
tryCatch({
  source("R/01_fetch_kobo.R")
  message("SUCCESS: Raw data extracted and saved.")
}, error = function(e) {
  stop("FATAL ERROR in 01_fetch_kobo.R: ", e$message)
})

# step 3: Data validation
message("\n--- Step 3: Running data validation ---")
tryCatch({
  source("R/02_data_validation.R")
  message("SUCCESS: Data validation complete. Reports exported.")
}, error = function(e) {
  stop("FATAL ERROR in 02_data_validation.R: ", e$message)
})

# step 4: Sample indicator calculations and preparation datasets for powerBI
message("\n--- Step 4: Calculating indicators ---")
tryCatch({
  source("R/03_indicator_calculations.R")
  message("SUCCESS: Indicator aggregation complete.")
}, error = function(e) {
  stop("FATAL ERROR in 03_indicator_calculations.R: ", e$message)
})

# step 5: LLM Integration for qualitative M&E analysis
message("\n--- Step 5: LLM integration ---")
tryCatch({
  source("R/04_llm_analysis.R")
  message("SUCCESS: LLM aggregation complete.")
}, error = function(e) {
  stop("FATAL ERROR in 04_llm_analysis.R: ", e$message)
})

message("\n==================================================")
message("PIPELINE EXECUTION COMPLETED SUCCESSFULLY")
message("==================================================")