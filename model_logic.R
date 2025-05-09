# model_logic.R

library(prophet)
library(dplyr)
library(lubridate) # For weekdays()

# Function to train model and predict for a single future event
predict_single_event_rsvp <- function(future_event_date_str,
                                      future_registered_count,
                                      future_weather_temp,
                                      future_weather_type_str,
                                      future_special_event_str) {

  # --- 1. Load and preprocess historical data ---
  historical_data <- tryCatch({
    read.csv("historical_rsvp_data.csv", stringsAsFactors = FALSE)
  }, error = function(e) {
    stop("Error reading historical_rsvp_data.csv: ", e$message, ". Make sure the file exists in the application directory.")
  })

  # Validate required columns in historical data
  required_hist_cols <- c("ds", "y", "RegisteredCount", "WeatherTemperature", "WeatherType", "SpecialEvent")
  if (!all(required_hist_cols %in% names(historical_data))) {
    missing_cols <- setdiff(required_hist_cols, names(historical_data))
    stop(paste("Historical data CSV is missing columns:", paste(missing_cols, collapse=", ")))
  }

  historical_data <- historical_data %>%
    mutate(
      ds = as.Date(ds), # Ensure ds is Date type
      y = as.numeric(y),
      RegisteredCount = as.numeric(RegisteredCount),
      WeatherTemperature = as.numeric(WeatherTemperature),
      # Derived regressors
      DayOfWeek = as.factor(weekdays(ds)), # Prophet handles factor regressors
      WeatherTypeNumeric = ifelse(tolower(WeatherType) == "rain", 1, 0), # Example: 1 for Rain, 0 for other
      SpecialEventNumeric = ifelse(tolower(SpecialEvent) == "yes", 1, 0)   # 1 for Yes, 0 for No
    )

  # --- 2. Define and Train Prophet Model ---
  # Using daily.seasonality=TRUE as per your original script.
  # Additive seasonality is generally a good start.
  m <- prophet(daily.seasonality = TRUE, seasonality.mode = "additive")

  # Add all regressors (must match names in historical_data and future_df)
  m <- add_regressor(m, 'RegisteredCount')
  m <- add_regressor(m, 'WeatherTemperature')
  m <- add_regressor(m, 'DayOfWeek')          # Factor, Prophet will handle dummy coding
  m <- add_regressor(m, 'WeatherTypeNumeric')
  m <- add_regressor(m, 'SpecialEventNumeric')

  # Fit the model
  # Prophet requires 'ds' and 'y' columns in the fitting dataframe.
  # Other columns with matching names to add_regressor calls will be used as regressors.
  m <- fit.prophet(m, historical_data)

  # --- 3. Prepare future dataframe for the single event ---
  future_event_date <- as.Date(future_event_date_str)

  future_df <- data.frame(
    ds = future_event_date,
    RegisteredCount = as.numeric(future_registered_count),
    WeatherTemperature = as.numeric(future_weather_temp)
    # Derived regressors for the future date
    # DayOfWeek = as.factor(weekdays(future_event_date)),
    # WeatherTypeNumeric = ifelse(tolower(future_weather_type_str) == "rain", 1, 0),
    # SpecialEventNumeric = ifelse(tolower(future_special_event_str) == "yes", 1, 0)
  )
  
  # It's critical that regressor columns in future_df have the *exact same names and types*
  # (especially factor levels for DayOfWeek) as those used during training.
  # Prophet's predict function expects these.

  # To ensure consistency, especially with factors like DayOfWeek,
  # let's generate them in the same way and then select:
  future_df_processed <- future_df %>%
    mutate(
      DayOfWeek = factor(weekdays(ds), levels = levels(historical_data$DayOfWeek)), # Use levels from historical data
      WeatherTypeNumeric = ifelse(tolower(future_weather_type_str) == "rain", 1, 0),
      SpecialEventNumeric = ifelse(tolower(future_special_event_str) == "yes", 1, 0)
    )
    
  # Ensure all regressor columns are present in the future_df_processed
  # These are the names used in add_regressor
  required_model_regressors <- c('RegisteredCount', 'WeatherTemperature', 'DayOfWeek', 'WeatherTypeNumeric', 'SpecialEventNumeric')
  if (!all(required_model_regressors %in% names(future_df_processed))) {
      missing_regressors <- setdiff(required_model_regressors, names(future_df_processed))
      stop(paste("Internal error preparing future data. Missing regressors:", paste(missing_regressors, collapse=", ")))
  }


  # --- 4. Make Prediction ---
  forecast <- predict(m, future_df_processed)

  # --- 5. Return the forecast (yhat) ---
  # The forecast dataframe will have many columns (yhat, yhat_lower, yhat_upper, trend, etc.)
  # We only need yhat for the single future date.
  predicted_rsvp_count <- forecast$yhat[1] # Get yhat for the first (and only) row

  return(list(predicted_rsvp_count = predicted_rsvp_count))
}
