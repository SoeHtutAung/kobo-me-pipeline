######################
# Topic: KOBO API integration and automation
# Purpose: Fetching up data from Kobo API
# Author: One Tech Agency
###################### 

# install missing packages and dependencies as necessary
required_pkgs <- c("purrr", "httr2", "jsonlite", "dplyr", "tidyr")
new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[, "Package"])]
if (length(new_pkgs)) install.packages(new_pkgs)

# load libraries
library(httr2)
library(jsonlite)
library(dplyr)
library(purrr)
library(tidyr)

# creating a function to fetch raw data from KoboToolbox API v2 with Pagination
fetch_kobo_submissions <- function(asset_uid, token, base_url) {
  
  # endpoint URL for asset data
  data_url <- paste0(base_url, "/assets/", asset_uid, "/data.json")
  
  all_results <- list()
  next_url <- data_url
  page_count <- 1
  
  message("Starting data extraction from KoboToolbox...")
  
  # pagination Loop
  while (!is.null(next_url)) {
    message(paste("Fetching page", page_count, "..."))
    
    #create request
    req <- request(next_url) %>%
      req_headers(
        Authorization = paste("Token", token),
        Accept = "application/json"
      ) %>%
      req_retry(max_tries = 3, backoff = ~ 2) # auto-retry on network drop/rate limit
    
    #create response
    resp <- req_perform(req)
    
    if (resp_status(resp) != 200) {
      stop(paste("Failed to retrieve data. HTTP status code:", resp_status(resp)))
    }
    
    # extract body
    body <- resp_body_json(resp, simplifyVector = FALSE)
    
    # append current page records
    all_results <- c(all_results, body$results)          
    
    # update pagination cursor     
    next_url <- body$`next`
    page_count <- page_count + 1
  }
  
  message(paste("Extraction complete.", length(all_results), "total records retrieved."))
  return(all_results)
}

# execute data ingestion
raw_payload <- fetch_kobo_submissions(
  asset_uid = kobo_asset,
  token = kobo_token,
  base_url = kobo_base_url
)

# save raw JSON backup with timestamp
timestamp <- format(Sys.time(), "%Y%m%d_%H%M")
raw_json_path <- file.path("data", "raw", paste0("kobo_raw_", timestamp, ".json"))

write_json(raw_payload, raw_json_path, auto_unbox = TRUE, pretty = TRUE)
message(paste("Raw JSON payload saved to:", raw_json_path))

# flatten JSON list to a tidy tibble
df_raw <- fromJSON(toJSON(raw_payload), flatten = TRUE)

# tidy up the data frame
df_clean <- df_raw %>%
  # clean default names of kobo
  rename_with(~ gsub("^_", "meta_", .x)) %>%
  rename_with(~ gsub("/", ".", .x)) %>%
  
  # remove specific columns
  select(-formhub.uuid, -meta__version__, -meta.instanceID, -meta_xform_id_string,
         -meta.rootUuid, -meta_attachments, -meta_status, -meta_geolocation) %>%
  
  # rename specific columns
  rename(
    form_id = meta_id,
    user_id = meta_uuid,
    address = location_add,
    submission_time = meta_submission_time,
    sameas_start_dt = End_date_same_as_start_date
  )

# Save intermediate RDS for Day 3 (Data Validation)
saveRDS(df_clean, "data/raw/kobo_latest_tbl.rds")
