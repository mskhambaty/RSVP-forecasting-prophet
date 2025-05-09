# main.R (This is your Plumber API script)

library(plumber)
library(jsonlite) # For explicit JSON handling if needed, though Plumber does a lot
library(dplyr)    # Used in model_logic.R
library(prophet)  # Used in model_logic.R

# Source the forecasting function from model_logic.R
source("model_logic.R") # Make sure this file is in the same directory

#* @apiTitle RSVP Prophet Forecast API
#* @apiDescription This API takes historical data and future regressor data to generate a forecast using Prophet.

#* Log information about each incoming request (optional, but good for debugging)
#* @filter logger
function(req){
  cat(as.character(Sys.time()), "-", 
      req$REQUEST_METHOD, req$PATH_INFO, "-", 
      req$HTTP_USER_AGENT, "@", req$REMOTE_ADDR, "\n")
  plumber::forward() # Continue processing the request
}

#* Generate a forecast
#* Call this endpoint with a POST request.
#* The request body should be JSON and include two main keys:
#* "historical_data": An object (which will become a data frame) with columns:
#* ds (date string), y (numeric), Weather.Temperature (numeric),
#* Weather.Type (string, e.g., "Rain", "Sunny"),
#* Special.Event (string, e.g., "Yes", "No").
#* "future_regressors": An object (data frame) for future dates with columns:
#* ds (date string), Weather.Temperature (numeric),
#* Weather.Type (string), Special.Event (string).
#* @post /predict
#* @parser json  # Tells Plumber to automatically parse the incoming JSON body
function(req, res) { # 'res' allows you to set response status if needed
  
  body <- req$body # req$body will now contain the parsed JSON as R lists/data.frames
  
  # Basic validation of the input structure
  if (is.null(body$historical_data) || is.null(body$future_regressors)) {
    res$status <- 400 # Bad Request
    return(list(error = "Request body must be JSON and include 'historical_data' and 'future_regressors' objects."))
  }
  
  # Call the forecasting function
  forecast_results <- tryCatch({
    generate_forecast_from_data(
      historical_df_input = body$historical_data,
      future_regressors_df_input = body$future_regressors
    )
  }, error = function(e) {
    # Log the actual error message for debugging on the server
    cat("Error in generate_forecast_from_data: ", e$message, "\n") 
    # Return an error response
    res$status <- 500 # Internal Server Error
    return(list(error = paste("Forecasting error:", e$message)))
  })
  
  # If tryCatch returned an error object (e.g. if res$status was not set inside error function)
  if (inherits(forecast_results, "list") && !is.null(forecast_results$error)) {
    # Error already formatted, just return it
    return(forecast_results)
  }
  
  # Success: return the forecast results
  return(forecast_results)
}

# This section is for defining how Plumber runs.
# Render will use the CMD in the Dockerfile to start this.
# However, having a @plumber tag makes it runnable directly with plumber::pr("main.R") %>% pr_run()
#* @plumber
function(pr) {
    pr # This just returns the plumber router object. The CMD in Dockerfile will call pr_run on it.
}
