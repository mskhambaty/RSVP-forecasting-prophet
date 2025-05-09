# Dockerfile

# Start from an official R base image from rocker.
# rocker/r-ver provides specific R versions. Using a recent one is good.
# As of early 2024, Prophet generally works well with R 4.2.x or 4.3.x.
FROM rocker/r-ver:4.3.3

# Install system dependencies that Prophet or its components (like Stan) might need.
# This includes a C++ compiler (g++), make, and libraries for curl, ssl, xml.
# 'cargo' is for Rust, sometimes a dependency of R packages.
# Running as root for these system installations.
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
USER ${NB_USER:-rstudio} # Switch back to default rocker user (often rstudio or similar)

# Set the working directory in the container
WORKDIR /app

# Copy the R package installation script and run it
COPY install_dependencies.R /app/install_dependencies.R
RUN Rscript /app/install_dependencies.R

# Copy your API application files into the container
COPY model_logic.R /app/model_logic.R
COPY main.R /app/main.R

# Expose the port Plumber will run on (default is 8000)
EXPOSE 8000

# The command to run your Plumber API when the container starts.
# This tells R to load Plumber, point it to your main.R file,
# and run the API on host 0.0.0.0 (to be accessible from outside the container)
# and port 8000 (which Render will map).
CMD ["Rscript", "-e", "api <- plumber::plumb('/app/main.R'); api$run(host='0.0.0.0', port=8000)"]
