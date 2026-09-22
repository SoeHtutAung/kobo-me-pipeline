######################
# Topic: M&E Data Validation & Quality Checks
# Purpose: Validate df_clean schema and domain logic rules
# Author: One Tech Agency
######################

# install missing packages as necessary
required_pkgs <- c("pointblank", "dplyr", "lubridate", "readr","stringr")
new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[, "Package"])]
if (length(new_pkgs)) install.packages(new_pkgs)

# load libraries
library(pointblank)
library(dplyr)
library(lubridate)
library(readr)
library(stringr)

# load intermediate dataset which is saved after fetching
if (!file.exists("data/raw/kobo_latest_tbl.rds")) {
  stop("Input file 'data/raw/kobo_latest_tbl.rds' not found. Run 01_fetch_kobo.R first.")
}

df_clean <- readRDS("data/raw/kobo_latest_tbl.rds")

# set up boundary in the past in UTC (e.g., start date before 0:00 10 SEP 2026 in MMT +6:30 UTC)
past_boundary <- ymd_hms("2026-09-10 0:00:00", tz = "Asia/Yangon") %>% with_tz("UTC") 

# define validation agent with pointblank package
agent <- create_agent(
  tbl = df_clean %>% select(user_id, form_id, start_dt, address) %>%
  ## convert list to character for selected columns to prevent error in printing agent report
  mutate(across(where(is.list), ~ map_chr(.x, ~ paste(unlist(.x), collapse = ", ")))) %>%
  ## convert empty text, whitespace, or "NA" strings to true NA for pointblank to detect missing values
  mutate(across(where(is.character), ~ case_when(
    .x == "" ~ NA_character_,
    .x == "NA" ~ NA_character_,
    str_trim(.x) == "" ~ NA_character_,
    TRUE ~ .x
  ))),
  tbl_name = "kobo_cleaned_submissions",
  label = "Simple data validation report for Kobocollect"
  ) %>%
  
  # integrity check, missing values (e.g., id and submission time)
  col_vals_not_null(columns = vars(user_id, form_id, start_dt, address)) %>%
  
  # overlap
  rows_distinct(columns = vars(user_id)) %>%
  
  # sanity check (past_boundary has been set up previously) (e.g., start date must be earlier than 10 SEP)
  col_vals_lt(
    columns = vars(start_dt),
    value = past_boundary,# 
    na_pass = FALSE
  ) %>%
  
  # interrogate data
  interrogate()

# save HTML report for documentation 
## create path for validation report
html_report_path <- file.path("data", "processed", sprintf("validation_report_%s.html", format(Sys.Date(), "%Y%m%d")))
## export report
export_report(agent, filename = html_report_path)
# message(paste("HTML Validation report saved to:", html_report_path))

# row-level screening and filtering forms with validation issue
df_flagged_rows <- df_clean %>%
    # unlist the df
    mutate(across( 
      c(user_id, form_id, address, submission_time, username, start_dt),
      ~ purrr::map_chr(.x, ~ if (length(.x) == 0 || is.null(.x)) "NULL"
                       else paste(unlist(.x), collapse = " | ")))
      ) %>%
  # create validation flags (TRUE = issue found)
    mutate(
      flag_duplication    = duplicated(user_id) | duplicated(user_id, fromLast = TRUE),
      flag_missing_value  = is.na(address) | trimws(address) == "" | address == 'NULL', #NULL is important for kobo
      flag_invalid_date   = !is.na(start_dt) & 
      # convert submission time column to POSIXct from list
      ymd(start_dt, tz = "UTC", quiet = TRUE) > past_boundary,
    
    # Consolidated row status
    has_validation_issue = flag_duplication | flag_missing_value | flag_invalid_date
  ) %>%
  
    # filter rows with data issue
    filter(has_validation_issue == TRUE) %>%
    
    # select columns to include in the csv file
    select (user_id, form_id, address, submission_time, username, start_dt, has_validation_issue)

# export CSV log of flagged records for field enumerator follow-up
write_csv(df_flagged_rows, sprintf("data/processed/flagged_data_%s.csv", format(Sys.Date(), "%Y%m%d")))
