# Start from an official R base image from rocker.
FROM rocker/r-ver:4.3.3

# Set a working directory within the container
WORKDIR /app

# Install system dependencies required for R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    zlib1g-dev \
    libmariadb-dev-compat \
    libpq-dev \
    git \
    vim \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Set the locale to handle potential encoding issues
RUN locale-gen en_US.utf8
ENV LANG en_US.utf8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install necessary R packages. Adjust these based on your project's requirements.
# For your project, it seems you'll definitely need 'prophet'.
RUN R -e "install.packages(c('prophet'), repos='https://cloud.r-project.org/')"

# Copy project files into the working directory
COPY . /app

# If your application has other dependencies (e.g., Python), you can install them here.
# Example for Python and pip:
# RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip && rm -rf /var/lib/apt/lists/*
# RUN pip3 install -r requirements.txt

# Define the command to run your R script or application.
# Assuming you have a main R script named 'main.R'.
CMD ["Rscript", "main.R"]

# If you have a Shiny application, you might expose a port:
# EXPOSE 80
