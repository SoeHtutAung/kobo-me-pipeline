######################
# Topic: LLM Integration for qualitative M&E analysis
# Purpose: Extract insights & sentiment using gen AI fron open AI
# Author: One Tech Agency
######################

# install missing packages as necessary
required_pkgs <- c("dplyr", "httr2", "jsonlite", "purrr", "readr", "stringr")
new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[, "Package"])]
if (length(new_pkgs)) install.packages(new_pkgs)

# load libraries
library(dplyr)
library(httr2)
library(jsonlite)
library(purrr)
library(readr)
library(stringr)

# making sure that API key for Chatgpt is there
if (openai_key == "") {
  warning("OPENAI_API_KEY missing from environment. Skipping live LLM calls and generating mock response structure.")
}

# load validated dataset which is saved after validatin
if (!file.exists("data/processed/kobo_validated_tbl.rds")) {
  stop("Input file 'data/processed/kobo_validated_tbl.rds' not found. Run 02_data_validation.R first.")
}

df_validated <- readRDS("data/processed/kobo_validated_tbl.rds")

# 1. Preparation and calculation of indicators ---- 
# filer rows without validation issue for indicator calculations
df_analysis <- df_validated %>%
  filter(has_validation_issue == FALSE)

df_validated <- readRDS("data/processed/kobo_validated_tbl.rds")


# --- 2. Define LLM API Request Function ---

#' Call OpenAI Chat Completions API for qualitative M&E field notes
#' @param text_input Character string containing field response/notes
#' @param api_key API key string
#' @return A list containing summary and sentiment output
analyze_field_note_llm <- function(text_input, api_key) {
  
  if (is.na(text_input) || trimws(text_input) == "") {
    return(list(summary = "No content provided", sentiment = "Neutral"))
  }
  
  # Fallback mock mode if no API key is set
  if (api_key == "") {
    return(list(
      summary = paste("Mock Summary:", str_trunc(text_input, 30)),
      sentiment = "Neutral"
    ))
  }
  
  system_prompt <- "You are an expert M&E Data Analyst. Analyze the field note provided. Return a valid JSON object with exactly two keys: 'summary' (a concise 1-sentence summary) and 'sentiment' (one of: 'Positive', 'Neutral', 'Negative', 'Critical Concern'). Do not include Markdown formatting or backticks in your response."
  
  req <- request("https://api.openai.com/v1/chat/completions") %>%
    req_headers(
      "Authorization" = paste("Bearer", api_key),
      "Content-Type" = "application/json"
    ) %>%
    req_body_json(list(
      model = "gpt-4o-mini", # Cost-effective & fast model for batch text processing
      temperature = 0.2,     # Low temperature for deterministic outputs
      response_format = list(type = "json_object"),
      messages = list(
        list(role = "system", content = system_prompt),
        list(role = "user", content = paste("Field Note:", text_input))
      )
    )) %>%
    req_retry(max_tries = 3, backoff = ~ 2)
  
  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    return(NULL)
  })
  
  if (is.null(resp) || resp_status(resp) != 200) {
    return(list(summary = "API Error", sentiment = "Error"))
  }
  
  res_body <- resp_body_json(resp)
  parsed_content <- fromJSON(res_body$choices[[1]]$message$content)
  
  return(parsed_content)
}


# --- 3. Run Analysis on Qualitative Text Columns ---

# Assuming 'address' or a dedicated 'notes' / 'comments' column contains text
# Subsetting first 10 rows for API cost optimization during testing
df_qual_sample <- df_validated %>%
  filter(has_validation_issue == FALSE) %>%
  slice_head(n = 10) 

message("Starting LLM analysis on qualitative records...")

# Apply LLM function across qualitative responses
llm_results <- map(
  df_qual_sample$address, 
  ~ analyze_field_note_llm(.x, api_key = openai_key)
)

# Bind structured LLM insights back to data frame
df_llm_processed <- df_qual_sample %>%
  mutate(
    llm_summary   = map_chr(llm_results, ~ .x$summary %||% "N/A"),
    llm_sentiment = map_chr(llm_results, ~ .x$sentiment %||% "N/A")
  )

# --- 4. Export Qualitative LLM Outputs ---
dir.create("data/processed/qualitative", showWarnings = FALSE, recursive = TRUE)

saveRDS(df_llm_processed, "data/processed/qualitative/kobo_llm_analyzed.rds")
write_csv(df_llm_processed, "data/processed/qualitative/llm_qualitative_summary.csv")

message("LLM analysis complete. Outputs saved to data/processed/qualitative/")