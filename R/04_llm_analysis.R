######################
# Topic: LLM Integration for qualitative M&E analysis
# Purpose: Extract insights & sentiment using gen AI from Gemini
# Author: One Tech Agency
######################

# install missing packages as necessary
required_pkgs <- c("dotenv","dplyr", "httr2", "jsonlite", "purrr", "readr", "stringr")
new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[, "Package"])]
if (length(new_pkgs)) install.packages(new_pkgs)

# load libraries
library(dotenv)
library(dplyr)
library(httr2)
library(jsonlite)
library(purrr)
library(readr)
library(stringr)

# 1. Setup environment and prepare json ---- 
# making sure that API key for Gemini is there
if (!exists("gemini_key") || is.null(gemini_key) || gemini_key == "") {
  load_dot_env(".env")
  gemini_key <- Sys.getenv("GEMINI_API_KEY")
}

# load validated dataset which is saved after validatin
if (!file.exists("data/processed/kobo_validated_tbl.rds")) {
  stop("Input file 'data/processed/kobo_validated_tbl.rds' not found. Run 02_data_validation.R first.")
}
df_validated <- readRDS("data/processed/kobo_validated_tbl.rds")

# filer rows without validation issue for indicator calculations
df_analysis <- df_validated %>%
  filter(has_validation_issue == FALSE)

# prepare a tibble to feed into AI: buidling type by level of damage for analysis with AI
damage_csv <- df_analysis %>%
  ## convert list to character to prevent missing in exporting to csv
  mutate(across(where(is.list), ~ map_chr(.x, ~ paste(unlist(.x), collapse = ", ")))) %>%
  ## analyze
  group_by(type, lvl_damage) %>%
  summarise(
    total_building = n(),
    percent = round((n() / nrow(df_analysis)) * 100, 2),
    .groups = "drop"
  ) %>% 
  # convert to csv for llm input
  format_csv()
  # # convert to JSON
  # toJSON(dataframe = "rows", auto_unbox = TRUE,na = "null")

# 2. Set up ----
# define system prompt
system_prompt <- "You are an experienced Monitoring and Evaluation (M&E) expert working in the public health and humanitarian sector.

You will be provided with a CSV table showing building types, damage levels, number of buildings, and percentages.

Return the result as valid JSON with exactly two fields:
1. 'summary': A concise 1 paragraph narrative highlighting overall pattern of building damage, Compare damage levels across building type, notable findings.
2. 'findings': A JSON array of 3 bullet-point highlights extracted from the data, including numbers and percentages as applicable."

# 5. User prompt containing the data ----
user_prompt <- paste0(
  "Please analyze the following building damage data:\n\n",
  damage_csv
)

# 6. Build Gemini request ----
# create request
req_gemini <- request(
  "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions") %>%
  req_headers(
    Authorization = paste("Bearer", gemini_key),
    `Content-Type` = "application/json") %>%
  req_body_json(
    list(
      model = "gemini-3.5-flash-lite", # 3.7 returns 503 error on SEP 2026 
      messages = list(
        list(role = "system", content = system_prompt),
        list(role = "user", content = user_prompt)),
      max_completion_tokens = 500,
      response_format = list(
        type = "json_object"))) 
  # %>%
  # # set up repetition
  # req_retry(
  #   max_tries = 5,
  #   is_transient = function(resp) {
  #     resp_status(resp) %in% c(429, 500, 502, 503, 504)
  #   }
  # )
# perform request
resp <- req_perform(req_gemini)

# 9. Process and export outputs ----
if (!is.null(resp) && resp_status(resp) == 200) {
  
  cat("HTTP status:", resp_status(resp), "\n")
  
  # extract outputs
  res_body <- resp_body_json(resp)
  llm_text <- res_body$choices[[1]]$message$content
  
  # parse Gemini JSON into an R list
  llm_result <- fromJSON(llm_text)
  cat("\n===== M&E SUMMARY =====\n")
  cat(llm_result$summary, "\n")
  cat("\n===== KEY FINDINGS =====\n")
  print(llm_result$findings)
  
  # save qualitative outputs for Power BI / Reporting
  dir.create("data/processed/qualitative", showWarnings = FALSE, recursive = TRUE)
  
  # save raw LLM object
  saveRDS(llm_result, "data/processed/qualitative/llm_building_damage_summary.rds")
  
  # flatten and save CSV table summary
  summary_df <- tibble(
    generated_at = Sys.time(),
    summary = llm_result$summary %||% "N/A",
    findings = paste(llm_result$findings, collapse = " | ")
  )
  
  write_csv(summary_df, "data/processed/qualitative/llm_building_damage_summary.csv")
  
} else {
  warning("API Request did not complete successfully.")
}
