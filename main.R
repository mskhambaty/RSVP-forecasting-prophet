# main.R (Plumber API script)

library(plumber)
# Other libraries like dplyr, prophet, lubridate are loaded by model_logic.R

# Source the forecasting function
source("model_logic.R") # Assumes model_logic.R is in the same directory

#* @apiTitle RSVP Prophet Forecast API (v2)
#* @apiDescription API to get a single RSVP forecast using historical data from a CSV.

#* Log information about each incoming request
#* @filter logger
function(req){
  cat(as.character(Sys.time()), "-",
      req$REQUEST_METHOD, req$PATH_INFO, "-",
      req$HTTP_USER_AGENT, "@", req$REMOTE_ADDR, "\n")
  plumber::forward()
}

#* Generate a forecast for a single future event
#* @param event_date:string The date of the future event (e.g., "2025-12-31")
#* @param registered_count:int The 'RSVP number' or expected initial registrants for the future event
#* @param weather_temperature:numeric The expected temperature for the future event
#* @param weather_type:string The expected weather type (e.g., "Sunny", "Rain", "Cloudy")
#* @param special_event:string Is it a special event? ("Yes" or "No")
#* @post /predict_event_rsvp
function(req, res, event_date, registered_count, weather_temperature, weather_type, special_event) {

  # Basic validation (Plumber handles type conversion for primitive types based on annotations if possible)
  if(missing(event_date) || missing(registered_count) || missing(weather_temperature) || missing(weather_type) || missing(special_event)) {
    res$status <- 400 # Bad Request
    return(list(error="Missing one or more required parameters: event_date, registered_count, weather_temperature, weather_type, special_event"))
  }

  # Convert types explicitly for robustness, especially numeric ones
  registered_count_num <- as.numeric(registered_count)
  weather_temperature_num <- as.numeric(weather_temperature)

  if (is.na(registered_count_num) || is.na(weather_temperature_num)) {
    res$status <- 400 # Bad Request
    return(list(error="Parameters 'registered_count' and 'weather_temperature' must be valid numbers."))
  }
  
  # Validate date format (basic check)
  # A more robust check would use tryCatch(as.Date(...), error = ...)
  if (!grepl("^\\d{4}-\\d{2}-\\d{2}$", event_date)) {
    res$status <- 400 # Bad Request
    return(list(error="Parameter 'event_date' must be in YYYY-MM-DD format."))
  }


  # Call the forecasting function from model_logic.R
  forecast_result <- tryCatch({
    predict_single_event_rsvp(
      future_event_date_str = event_date,
      future_registered_count = registered_count_num,
      future_weather_temp = weather_temperature_num,
      future_weather_type_str = weather_type,
      future_special_event_str = special_event
    )
  }, error = function(e) {
    cat("Error in predict_single_event_rsvp: ", e$message, "\n") # Log server-side
    res$status <- 500 # Internal Server Error
    return(list(error = paste("Forecasting error:", e$message)))
  })

  # Check if tryCatch returned an error (if res$status not set inside error function)
  if (inherits(forecast_result, "list") && !is.null(forecast_result$error)) {
      # Error already formatted by the error handler in tryCatch or is an error object
      return(forecast_result)
  }
  
  # Success: return the forecast result
  return(forecast_result)
}

# Plumber entrypoint definition for Render
#* @plumber
function(pr) {
    pr # Returns the plumber router object. CMD in Dockerfile calls pr_run on it.
}
