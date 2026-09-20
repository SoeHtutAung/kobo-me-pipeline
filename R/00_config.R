######################
# Topic: Demo project
# Purpose: API integrations and report generation
# Author: One Tech Agency
###################### 

# install missing packages and dependencies as necessary
required_pkgs <- c("dotenv", "httr2", "jsonlite", "dplyr")
new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[, "Package"])]
if (length(new_pkgs)) install.packages(new_pkgs)

# load libraries
library(dotenv)
library(httr2)
library(jsonlite)
library(dplyr)

# load environment variables from .env file
if (file.exists(".env")) {
  load_dot_env(".env")
}

# retrieve credentials from environment
kobo_token    <- Sys.getenv("KOBO_API_TOKEN")
kobo_base_url <- Sys.getenv("KOBO_BASE_URL")
kobo_asset    <- Sys.getenv("KOBO_ASSET_UID")

# validation check for missing credentials
if (kobo_token == "" || kobo_base_url == "") {
  stop("CRITICAL ERROR: KoboToolbox API credentials are missing from .env")
}

message("Configuration successfully loaded.")


