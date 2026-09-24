######################
# Topic: M&E Indicator Calculations
# Purpose: Aggregate cleaned field data into key quantitative indicators
# Author: One Tech Agency
######################

# install missing packages as necessary
required_pkgs <- c("dplyr", "tidyr", "readr", "lubridate")
new_pkgs <- required_pkgs[!(required_pkgs %in% installed.packages()[, "Package"])]
if (length(new_pkgs)) install.packages(new_pkgs)

# load libraries
library(dplyr)
library(tidyr)
library(readr)
library(lubridate)

# load validated dataset which is saved after validatin
if (!file.exists("data/processed/kobo_validated_tbl.rds")) {
  stop("Input file 'data/processed/kobo_validated_tbl.rds' not found. Run 02_data_validation.R first.")
}

df_validated <- readRDS("data/processed/kobo_validated_tbl.rds")

# 1. Preparation and calculation of indicators ---- 
# filer rows without validation issue for indicator calculations
df_analysis <- df_validated %>%
  filter(has_validation_issue == FALSE)
# message(paste("Processing indicator calculations on", nrow(df_clean_indicators), "valid records."))

# calculating indicators
# indicator 1: rate (e.g., daily job)
jobs_per_day <- df_analysis %>%
  ## convert list to character to prevent missing in exporting to csv
  mutate(across(where(is.list), ~ map_chr(.x, ~ paste(unlist(.x), collapse = ", ")))) %>%
  ## analyze
  group_by(start_dt) %>%
  summarise(
    total_jobs = n(),
    unique_users = n_distinct(form_id),
    .groups = "drop"
  )

# indicator 2: proportion (e.g., building types)
building_types <- df_analysis %>%
  ## convert list to character to prevent missing in exporting to csv
  mutate(across(where(is.list), ~ map_chr(.x, ~ paste(unlist(.x), collapse = ", ")))) %>%
  ## analyze
  group_by(type) %>%
  summarise(
    total_building = n(),
    percent = round((n() / nrow(df_analysis)) * 100, 2),
    .groups = "drop"
  )

# indicator 3: summary matrix for submissions and data quality
data_quality_summary <- tibble(
  metric_name = c(
    "Total submissions received",
    "Total submissions analyzed",
    "Submissions with data issues",
    "Quality submissions (%)"
  ),
  metric_value = c(
    nrow(df_validated),
    nrow(df_analysis),
    nrow(df_validated) - nrow(df_analysis),
    round((nrow(df_analysis) / nrow(df_validated)) * 100, 2)
  )
)

# indicator 4: buidling type by level of damage for analysis with AI
types_and_damage <- df_analysis %>%
  ## convert list to character to prevent missing in exporting to csv
  mutate(across(where(is.list), ~ map_chr(.x, ~ paste(unlist(.x), collapse = ", ")))) %>%
  ## analyze
  group_by(type, lvl_damage) %>%
  summarise(
    total_building = n(),
    percent = round((n() / nrow(df_analysis)) * 100, 2),
    .groups = "drop"
  )

# tables for power BI: create fact and dimension tables in csv format
# fact table: validated and cleaned data set
df_export <- df_analysis %>%
  ## convert list to character to prevent missing in exporting to csv
  mutate(across(where(is.list), ~ map_chr(.x, ~ paste(unlist(.x), collapse = ", "))))

# 2. Saving calculation outputs for further analysis ----
# create directory to save indicators
dir.create("data/processed/indicators", showWarnings = FALSE, recursive = TRUE)

# export indicator datasets
write_csv(jobs_per_day, "data/processed/indicators/jobs_per_day.csv")
write_csv(building_types, "data/processed/indicators/building_types.csv")
write_csv(data_quality_summary, "data/processed/indicators/data_quality_summary.csv")
write_csv(types_and_damage, "data/processed/indicators/types_and_damage.csv")

# export fact and dimension tables for power BI
# create directory for power bi
dir.create("data/processed/powerbi", showWarnings = FALSE, recursive = TRUE)
# fact table
write_csv(df_export, "data/processed/powerbi/dataset.csv")
# dimension table: they are predefined in the Kobocollect form. But form revision may cause addition of new variables, thus extract from dataset to be safe 
## building types
df_export %>% distinct(df_export$type) %>% write_csv("data/processed/powerbi/buildingtypes.csv")
## level of damage
df_export %>% distinct(df_export$lvl_damage) %>% write_csv("data/processed/powerbi/damagelevels.csv")

# save consolidated RDS for Power BI and report generation
indicator_bundle <- list(
  daily_reach = jobs_per_day,
  building_types = building_types,
  summary = data_quality_summary,
  types_damage = types_and_damage
)

# save rds
saveRDS(indicator_bundle, "data/processed/indicators_summary.rds")
