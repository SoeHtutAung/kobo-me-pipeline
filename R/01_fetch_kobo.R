######################
# Topic: KOBO API integration and automation
# Purpose: Fetching up data from Kobo API
# Author: One Tech Agency
###################### 

# install missing packages and dependencies as necessary
required_pkgs <- c("purrr", "httr2", "jsonlite", "dplyr", "tidyr", "stringr")
new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[, "Package"])]
if (length(new_pkgs)) install.packages(new_pkgs)

# load libraries
library(httr2)
library(jsonlite)
library(dplyr)
library(purrr)
library(tidyr)
library(stringr)

# 1. Fetching JSON from Kobo API -----
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

# 2. Tidying up JSON to data frame ----
# flatten JSON list to a tidy tibble
df_raw <- fromJSON(toJSON(raw_payload), flatten = TRUE)

# tidy up the data frame
df_clean <- df_raw %>%
  # clean default names of kobo
  rename_with(~ gsub("^_", "meta_", .x)) %>%
  rename_with(~ gsub("/", ".", .x)) %>%
  
  # remove specific columns
  select(-formhub.uuid, -meta.instanceID, -meta_xform_id_string,
         -meta.rootUuid, -meta_attachments, -meta_status, -meta_geolocation) %>%
  
  # rename specific columns
  rename(
    form_id = meta_id,
    user_id = meta_uuid,
    address = location_add,
    submission_time = meta_submission_time,
    sameas_start_dt = End_date_same_as_start_date) %>%
  
  # there was an error during form development that responses were not properly coded in earlier versions
  # follow script is to manipulate that data
  ## convert activity list-column to character
  mutate(
    activity = map_chr(
      activity,
      ~ paste(unlist(.x), collapse = " ")
    )
  ) %>%
  
  ## recode activity for the two old form versions
  mutate(
    activity = if_else(
      meta__version__ %in% c(
        "v2CCG9MzxrKktdz8bW63PE",
        "vksRw3i9xevqUQz2bGV4WV"
      ),
      activity %>%
        str_replace_all(
          c(
            "option_1" = "corpse_retrieval",
            "option_2" = "debris_removal_major",
            "debris_removal_comprehensive" = "debris_removal_com"
          )
        ),
      activity
    )
  )

# save intermediate RDS before data validation
saveRDS(df_clean, "data/raw/kobo_latest_tbl.rds")
