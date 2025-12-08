# Stata-MCP Testing Environment
# This Dockerfile creates a sandboxed environment for Claude Code to test Stata commands
# using the Stata-MCP server

FROM ubuntu:22.04

LABEL maintainer="Timothy P Copeland"
LABEL description="Sandboxed Stata-MCP testing environment for Stata-Tools"

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    vim \
    less \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for running tests
RUN useradd -m -s /bin/bash tester && \
    echo "tester ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create working directories
RUN mkdir -p /workspace/Stata-Tools && \
    mkdir -p /workspace/Stata-MCP && \
    mkdir -p /workspace/test-output && \
    mkdir -p /home/tester/.local/share/claude-code && \
    chown -R tester:tester /workspace && \
    chown -R tester:tester /home/tester

# Set up Python virtual environment for Stata-MCP
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies for MCP
RUN pip install --upgrade pip && \
    pip install \
    httpx \
    pydantic \
    uvicorn \
    fastapi \
    websockets \
    aiofiles

# Install Node.js LTS
RUN npm install -g n && n lts

# Set working directory
WORKDIR /workspace

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch to non-root user
USER tester

# Environment variables
ENV HOME=/home/tester
ENV STATA_TOOLS_DIR=/workspace/Stata-Tools
ENV STATA_MCP_DIR=/workspace/Stata-MCP
ENV TEST_OUTPUT_DIR=/workspace/test-output

# Entry point
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
