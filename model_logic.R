# model_logic.R

library(prophet)
library(dplyr)
library(lubridate) # For weekdays() and time parsing

# Helper function to convert HH:MM string to numeric hours
time_to_numeric_hours <- function(time_str) {
  if (is.na(time_str) || !grepl("^\\d{1,2}:\\d{2}$", time_str)) {
    return(NA) # Or a default value, or raise error
  }
  parts <- as.numeric(strsplit(time_str, ":")[[1]])
  return(parts[1] + parts[2] / 60)
}

# Function to train model and predict for a single future event
predict_single_event_rsvp <- function(future_event_date_str,
                                      future_registered_count,
                                      future_weather_temp,
                                      future_weather_type_str,
                                      future_special_event_str,
                                      future_event_name_str, # New parameter
                                      future_sunset_time_str) { # New parameter

  # --- 1. Load and preprocess historical data ---
  historical_data <- tryCatch({
    read.csv("historical_rsvp_data.csv", stringsAsFactors = FALSE)
  }, error = function(e) {
    stop("Error reading historical_rsvp_data.csv: ", e$message, ". Make sure the file exists.")
  })

  # Validate required columns
  required_hist_cols <- c("ds", "y", "RegisteredCount", "WeatherTemperature", "WeatherType", 
                          "SpecialEvent", "EventName", "SunsetTime")
  if (!all(required_hist_cols %in% names(historical_data))) {
    missing_cols <- setdiff(required_hist_cols, names(historical_data))
    stop(paste("Historical data CSV is missing columns:", paste(missing_cols, collapse=", ")))
  }

  historical_data <- historical_data %>%
    mutate(
      ds = as.Date(ds),
      y = as.numeric(y),
      RegisteredCount = as.numeric(RegisteredCount),
      WeatherTemperature = as.numeric(WeatherTemperature),
      EventName = as.factor(EventName), # Convert EventName to factor
      SunsetHour = sapply(SunsetTime, time_to_numeric_hours), # Convert SunsetTime to numeric hour
      DayOfWeek = as.factor(weekdays(ds)),
      WeatherTypeNumeric = ifelse(tolower(WeatherType) == "rain", 1, 0),
      SpecialEventNumeric = ifelse(tolower(SpecialEvent) == "yes", 1, 0)
    ) %>%
    filter(!is.na(SunsetHour)) # Remove rows where SunsetHour conversion failed, or handle differently

  if (nrow(historical_data) == 0) {
    stop("No valid historical data remaining after processing SunsetTime.")
  }
  
  # --- 2. Define and Train Prophet Model ---
  m <- prophet(daily.seasonality = TRUE, seasonality.mode = "additive")

  # Add all regressors
  m <- add_regressor(m, 'RegisteredCount')
  m <- add_regressor(m, 'WeatherTemperature')
  m <- add_regressor(m, 'DayOfWeek')
  m <- add_regressor(m, 'WeatherTypeNumeric')
  m <- add_regressor(m, 'SpecialEventNumeric')
  m <- add_regressor(m, 'EventName') # Add EventName as regressor (Prophet handles factors)
  m <- add_regressor(m, 'SunsetHour') # Add SunsetHour as numeric regressor

  m <- fit.prophet(m, historical_data)

  # --- 3. Prepare future dataframe for the single event ---
  future_event_date <- as.Date(future_event_date_str)
  future_sunset_hour_numeric <- time_to_numeric_hours(future_sunset_time_str)
  
  if (is.na(future_sunset_hour_numeric)) {
    stop("Invalid SunsetTime format for future event. Please use HH:MM.")
  }

  future_df_processed <- data.frame(
      ds = future_event_date,
      RegisteredCount = as.numeric(future_registered_count),
      WeatherTemperature = as.numeric(future_weather_temp)
    ) %>%
    mutate(
      EventName = factor(future_event_name_str, levels = levels(historical_data$EventName)), # Ensure factor levels match
      SunsetHour = future_sunset_hour_numeric,
      DayOfWeek = factor(weekdays(ds), levels = levels(historical_data$DayOfWeek)),
      WeatherTypeNumeric = ifelse(tolower(future_weather_type_str) == "rain", 1, 0),
      SpecialEventNumeric = ifelse(tolower(future_special_event_str) == "yes", 1, 0)
    )
    
  # Check for NA in EventName factor if future_event_name_str was not in historical levels
  # Prophet will handle new factor levels by not assigning a coefficient, which is usually fine.
  if (is.na(future_df_processed$EventName)) {
      warning(paste("Future EventName '", future_event_name_str, "' was not found in historical data. It will not have a specific learned effect.", sep=""))
      # To avoid issues with predict if NAs in factors are problematic (depends on Prophet version/settings):
      # One option: convert EventName back to character for the new level, or ensure all levels are covered.
      # For simplicity, Prophet usually handles new factor levels gracefully by effectively giving them a zero coefficient for that specific dummy variable.
      # Re-creating the factor with the new level if it's not present:
      all_event_names <- unique(c(levels(historical_data$EventName), future_event_name_str))
      future_df_processed$EventName <- factor(future_event_name_str, levels = all_event_names)
      
      # Re-level DayOfWeek similarly if necessary, though weekdays are fixed.
      all_day_names <- levels(historical_data$DayOfWeek) # Should be fixed set of 7 days
      future_df_processed$DayOfWeek <- factor(weekdays(ds), levels = all_day_names)

  }


  # --- 4. Make Prediction ---
  forecast <- predict(m, future_df_processed)

  # --- 5. Return the forecast (yhat) ---
  predicted_rsvp_count <- forecast$yhat[1]

  return(list(predicted_rsvp_count = round(predicted_rsvp_count, 0))) # Round to whole number
}
