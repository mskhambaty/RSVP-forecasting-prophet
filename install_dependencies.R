# install_dependencies.R

# Set a CRAN mirror for package downloads
options(repos = c(CRAN = "https://cloud.r-project.org/"))

# Install Prophet first, as it's the most complex
# This will also pull in its dependencies like Rcpp, StanHeaders, etc.
# The binary from CRAN is usually preferred if it works for the OS in Docker.
install.packages("prophet")

# Install other R packages needed by your scripts
install.packages(c(
  "plumber",  # For creating the API
  "jsonlite", # For handling JSON (though Plumber uses it internally)
  "dplyr",    # For data manipulation (used in model_logic.R)
  "lubridate" # For date functions like weekdays() (used in model_logic.R)
  # "extraDistr" # Your original script had this. Add back if model_logic.R uses it.
                 # Currently, it does not appear to be used.
  # "tidyverse"  # This is a large meta-package. We've installed dplyr and lubridate separately.
                 # If you need other tidyverse packages (e.g. tidyr, ggplot2 for other tasks), add them.
))

# Optional: You can add a line here to verify installations, e.g.,
# print("All requested packages installed.")
# if (!requireNamespace("prophet", quietly = TRUE)) {
#   stop("Prophet package failed to install or load.")
# }
