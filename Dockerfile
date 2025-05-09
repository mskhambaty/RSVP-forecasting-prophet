# Dockerfile

# Start from an official R base image from rocker.
FROM rocker/r-ver:4.3.3 # Or your chosen R version

# Install system dependencies
USER root
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    sudo \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    cargo \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*
USER ${NB_USER:-rstudio}

# Set the working directory
WORKDIR /app

# Copy the R package installation script and run it
COPY install_dependencies.R /app/install_dependencies.R
RUN Rscript /app/install_dependencies.R

# ---- ADD THIS LINE ----
# Copy the historical data CSV into the application directory
COPY historical_rsvp_data.csv /app/historical_rsvp_data.csv
# -----------------------

# Copy your API application files
COPY model_logic.R /app/model_logic.R
COPY main.R /app/main.R

# Expose the port
EXPOSE 8000

# Command to run your Plumber API
CMD ["Rscript", "-e", "api <- plumber::plumb('/app/main.R'); api$run(host='0.0.0.0', port=8000)"]
