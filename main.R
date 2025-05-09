# main.R (Plumber API script)

library(plumber)
source("model_logic.R")

#* @apiTitle RSVP Prophet Forecast API (v3)
#* @apiDescription API to get a single RSVP forecast using historical data from a CSV, including EventName and SunsetTime.

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
#* @param registered_count:int The 'RSVP number' or expected initial registrants
#* @param weather_temperature:numeric The expected temperature
#* @param weather_type:string The expected weather type (e.g., "Sunny", "Rain")
#* @param special_event:string Is it a special event? ("Yes" or "No")
#* @param event_name:string The name of the future event
#* @param sunset_time:string The expected sunset time (HH:MM format, e.g., "19:30")
#* @post /predict_event_rsvp
function(req, res, event_date, registered_count, weather_temperature, weather_type, special_event, event_name, sunset_time) {

  # Basic validation for presence of all parameters
  params <- list(event_date=event_date, registered_count=registered_count, weather_temperature=weather_temperature,
                 weather_type=weather_type, special_event=special_event, event_name=event_name, sunset_time=sunset_time)
  
  missing_params <- names(params)[sapply(params, function(p) missing(p) || is.null(p) || p == "")] # Check for missing or empty
  
  # Workaround for Plumber's handling of 'missing()' with default function args
  # Check if parameters were actually passed if they are default R function args (not the case here with explicit listing)
  # A simpler check if all are truly required by endpoint definition:
  if(length(missing_params) > 0){
     # Check if the parameters are part of the formal arguments of the function
     # This part is tricky if Plumber doesn't make them truly 'missing' but NULL or ""
     # A more direct check of actual received parameters might be needed if req$args isn't used
  }

  # A more straightforward check:
  if(any(sapply(c("event_date", "registered_count", "weather_temperature", "weather_type", "special_event", "event_name", "sunset_time"), 
             function(p_name) is.null(req$args[[p_name]]) && is.null(req$body[[p_name]]) ))) {
      # This check depends on how parameters are passed and parsed.
      # For named parameters in the function signature, Plumber populates them.
      # Let's rely on the initial 'missing()' check for required args if Plumber makes them missing.
      # Or explicitly check for NULL/empty for each.
  }
  
  # Simpler validation:
  if (missing(event_date) || nchar(event_date) == 0 ||
      missing(registered_count) || nchar(as.character(registered_count)) == 0 || # check nchar for empty string if it could be passed
      missing(weather_temperature) || nchar(as.character(weather_temperature)) == 0 ||
      missing(weather_type) || nchar(weather_type) == 0 ||
      missing(special_event) || nchar(special_event) == 0 ||
      missing(event_name) || nchar(event_name) == 0 ||
      missing(sunset_time) || nchar(sunset_time) == 0) {
    res$status <- 400
    return(list(error="Missing one or more required parameters."))
  }


  registered_count_num <- as.numeric(registered_count)
  weather_temperature_num <- as.numeric(weather_temperature)

  if (is.na(registered_count_num) || is.na(weather_temperature_num)) {
    res$status <- 400
    return(list(error="Parameters 'registered_count' and 'weather_temperature' must be valid numbers."))
  }
  if (!grepl("^\\d{4}-\\d{2}-\\d{2}$", event_date)) {
    res$status <- 400
    return(list(error="Parameter 'event_date' must be in YYYY-MM-DD format."))
  }
  if (!grepl("^\\d{1,2}:\\d{2}$", sunset_time)) {
    res$status <- 400
    return(list(error="Parameter 'sunset_time' must be in HH:MM format."))
  }

  forecast_result <- tryCatch({
    predict_single_event_rsvp(
      future_event_date_str = event_date,
      future_registered_count = registered_count_num,
      future_weather_temp = weather_temperature_num,
      future_weather_type_str = weather_type,
      future_special_event_str = special_event,
      future_event_name_str = event_name, # Pass new parameter
      future_sunset_time_str = sunset_time  # Pass new parameter
    )
  }, error = function(e) {
    cat("Error in predict_single_event_rsvp: ", e$message, "\n")
    res$status <- 500
    return(list(error = paste("Forecasting error:", e$message)))
  })

  if (inherits(forecast_result, "list") && !is.null(forecast_result$error)) {
      return(forecast_result)
  }
  
  return(forecast_result)
}

#* @plumber
function(pr) {
    pr
}
