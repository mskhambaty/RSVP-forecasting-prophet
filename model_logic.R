# model_logic.R

# Load necessary libraries (these will be installed via Docker)
library(prophet)
library(dplyr)
library(lubridate) # For the weekdays() function

# Main forecasting function
# It now accepts R data.frame objects directly for historical and future data.
generate_forecast_from_data <- function(historical_df_input, future_regressors_df_input) {
  
  # Convert inputs to data.frames and ensure 'ds' is Date type
  historical_df <- as.data.frame(historical_df_input) %>%
    mutate(ds = as.Date(ds))
  
  future_regressors_df <- as.data.frame(future_regressors_df_input) %>%
    mutate(ds = as.Date(ds))

  # --- Data Preprocessing for historical data ---
  # The API user needs to ensure these columns are in historical_df_input:
  # ds, y, Weather.Temperature, Weather.Type ("Rain" or other), Special.Event ("Yes" or "No")
  if (!all(c("ds", "y", "Weather.Temperature", "Weather.Type", "Special.Event") %in% names(historical_df))) {
    stop("Historical data is missing one or more required columns: ds, y, Weather.Temperature, Weather.Type, Special.Event")
  }
  
  historical_df <- historical_df %>%
    mutate(
      Day.of.Week.2 = as.factor(weekdays(ds)), # Prophet handles factor regressors
      Weather.Type.2 = ifelse(tolower(Weather.Type) == "rain", 1, 0),
      Special.Event.2 = ifelse(tolower(Special.Event) == "yes", 1, 0)
    )

  # --- Model Definition ---
  m <- prophet(daily.seasonality = TRUE, seasonality.mode = "additive")
  
  # Add regressors - names must match columns created above and in future_df
  m <- add_regressor(m, 'Day.of.Week.2')
  m <- add_regressor(m, 'Weather.Temperature') # Must be numeric
  m <- add_regressor(m, 'Weather.Type.2')    # Must be 0 or 1
  m <- add_regressor(m, 'Special.Event.2')  # Must be 0 or 1
  
  # --- Fit the model ---
  m <- fit.prophet(m, historical_df)
  
  # --- Prepare future dataframe with regressors ---
  # The API user needs to ensure these columns are in future_regressors_df_input:
  # ds, Weather.Temperature, Weather.Type, Special.Event
  if (!all(c("ds", "Weather.Temperature", "Weather.Type", "Special.Event") %in% names(future_regressors_df))) {
    stop("Future regressors data is missing one or more required columns: ds, Weather.Temperature, Weather.Type, Special.Event")
  }

  future_df_prepared <- future_regressors_df %>%
    mutate(
      Day.of.Week.2 = as.factor(weekdays(ds)),
      Weather.Temperature = as.numeric(Weather.Temperature), # Ensure numeric
      Weather.Type.2 = ifelse(tolower(Weather.Type) == "rain", 1, 0),
      Special.Event.2 = ifelse(tolower(Special.Event) == "yes", 1, 0)
    )
  
  # Ensure all regressor columns needed for prediction are present in future_df_prepared
  required_model_regressors <- c("Day.of.Week.2", "Weather.Temperature", "Weather.Type.2", "Special.Event.2")
  if (!all(required_model_regressors %in% names(future_df_prepared))) {
      missing_cols <- setdiff(required_model_regressors, names(future_df_prepared))
      stop(paste("Internal error: Not all regressor columns were correctly prepared for the future dataframe. Missing:", paste(missing_cols, collapse=", ")))
  }

  # --- Make predictions ---
  forecast <- predict(m, future_df_prepared)
  
  # --- Select and return output (ds and yhat) ---
  output_df <- forecast %>%
    select(ds, yhat)
  
  return(output_df)
}
