# Stata Linux Docker Environment
# Run Stata inside Docker for sandboxed testing

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Stata dependencies
RUN apt-get update && apt-get install -y \
    libpng16-16 \
    libncurses5 \
    libncurses6 \
    libtinfo5 \
    libtinfo6 \
    libgtk-3-0 \
    libxt6 \
    libxmu6 \
    libxss1 \
    libxft2 \
    locales \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set locale (required for Stata)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Create directories
RUN mkdir -p /usr/local/stata17 /workspace

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Add Stata to PATH
ENV PATH="/usr/local/stata17:$PATH"

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
