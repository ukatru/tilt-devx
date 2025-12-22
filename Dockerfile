FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    R_VERSION=4.3.2 \
    RSTUDIO_VERSION=2023.12.1+402 \
    S6_VERSION=v2.1.0.2 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    PATH=/usr/lib/rstudio-server/bin:$PATH

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    gdebi-core \
    pandoc \
    pandoc-citeproc \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libcairo2-dev \
    libxt-dev \
    libssh2-1-dev \
    libgit2-dev \
    libpq-dev \
    libsasl2-dev \
    libsqlite3-dev \
    unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    dirmngr \
    && wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc \
    && add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    r-base=${R_VERSION}* \
    r-base-dev=${R_VERSION}* \
    && rm -rf /var/lib/apt/lists/*

# Install RStudio Server
RUN wget https://download2.rstudio.org/server/jammy/amd64/rstudio-server-${RSTUDIO_VERSION}-amd64.deb \
    && gdebi -n rstudio-server-${RSTUDIO_VERSION}-amd64.deb \
    && rm rstudio-server-${RSTUDIO_VERSION}-amd64.deb

# Install s6 supervisor for process management
RUN wget -P /tmp/ https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-amd64.tar.gz \
    && tar xzf /tmp/s6-overlay-amd64.tar.gz -C / --exclude="./bin" \
    && tar xzf /tmp/s6-overlay-amd64.tar.gz -C /usr ./bin \
    && rm /tmp/s6-overlay-amd64.tar.gz

# Create rstudio user
RUN useradd -m -s /bin/bash -N -u 1000 rstudio \
    && echo "rstudio:rstudio" | chpasswd \
    && mkdir -p /home/rstudio/.rstudio/monitored/user-settings \
    && echo 'alwaysSaveHistory="0" \
        \nloadRData="0" \
        \nsaveAction="0"' > /home/rstudio/.rstudio/monitored/user-settings/user-settings \
    && chown -R rstudio:users /home/rstudio

# Configure RStudio Server
RUN echo "www-port=8787" >> /etc/rstudio/rserver.conf \
    && echo "www-address=0.0.0.0" >> /etc/rstudio/rserver.conf \
    && echo "rsession-which-r=/usr/bin/R" >> /etc/rstudio/rserver.conf

# Install commonly used R packages (optional - comment out if not needed)
RUN R -e "install.packages(c('tidyverse', 'devtools', 'rmarkdown', 'shiny'), repos='https://cloud.r-project.org/')"

# Expose RStudio Server port
EXPOSE 8787

# Set up s6 services
COPY --chown=root:root scripts/rstudio-server.sh /etc/services.d/rstudio/run
RUN chmod +x /etc/services.d/rstudio/run

# Use s6 as init system
ENTRYPOINT ["/init"]
