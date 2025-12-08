# Setting Up Stata for Linux with Docker

This guide explains how to run Stata inside a Docker container on macOS (or Windows). This is useful for:

- Sandboxed execution (filesystem isolation)
- CI/CD pipelines
- Reproducible environments
- Testing Stata packages safely

## Why Linux Stata?

Docker containers run Linux. Even on macOS or Windows, the container itself is a Linux environment. Therefore, you need **Stata for Linux**, not the macOS or Windows version.

Your existing Stata license typically covers all platforms - you just need to download the Linux installer.

## Step 1: Get Stata for Linux

### Option A: Download from Stata Website (Recommended)

1. Log into your Stata account: https://www.stata.com/customer-service/
2. Go to "Download Stata"
3. Select **"Stata for Unix/Linux (64-bit x86-64)"**
4. Download the `.tar.gz` file (e.g., `Stata18Linux64.tar.gz`)

### Option B: Request from Stata Support

If you don't see the Linux option in your downloads:

1. Email support@stata.com
2. Explain you need the Linux version for Docker/containerized testing
3. Provide your serial number
4. They typically add it to your license within 1-2 business days

## Step 2: Set Up Directory Structure

Store Stata Linux in a dedicated location **outside any git repos**:

```bash
# Create directory (adjust version number as needed)
mkdir -p ~/stata18-linux
cd ~/stata18-linux

# Extract the downloaded archive
tar -xzf ~/Downloads/Stata18Linux64.tar.gz

# You should now have files like:
# ~/stata18-linux/
# ├── stata-mp (or stata-se, stata-be)
# ├── ado/
# ├── docs/
# └── ... other files
```

## Step 3: Create License File

Create `stata.lic` in your Stata Linux directory:

```bash
cat > ~/stata18-linux/stata.lic << 'EOF'
Your Name
Your Institution
123456789012
ABCD-EFGH-IJKL-MNOP
xxxx xxxx xxxx xxxx
xxxx xxxx xxxx xxxx
EOF
```

**License file format** (5 lines, in this exact order):
```
Line 1: Your name (as registered with Stata)
Line 2: Your institution
Line 3: Serial number (12 digits)
Line 4: Authorization code (formatted XXXX-XXXX-XXXX-XXXX)
Line 5+: Code block (the alphanumeric codes from your license certificate)
```

**To find your license info:**
- Check the email from Stata when you purchased/renewed
- Or run Stata on macOS: `Help > About Stata` shows serial number
- Or check `~/Library/Application Support/Stata/stata.lic` on macOS

## Step 4: Create Dockerfile

Create a `Dockerfile` for your Stata container:

```dockerfile
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
    && rm -rf /var/lib/apt/lists/*

# Set locale (required for Stata)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Create stata directory
RUN mkdir -p /usr/local/stata18

# Add Stata to PATH
ENV PATH="/usr/local/stata18:$PATH"

# Create workspace
WORKDIR /workspace

# Default command
CMD ["stata-mp"]
```

## Step 5: Create docker-compose.yml

```yaml
version: '3.8'

services:
  stata:
    build: .
    container_name: stata-linux

    volumes:
      # Mount your Stata Linux installation (read-only for safety)
      - ${STATA_PATH:-~/stata18-linux}:/usr/local/stata18:ro

      # Mount your working directory
      - ${WORK_DIR:-.}:/workspace:rw

    stdin_open: true
    tty: true

    working_dir: /workspace
```

## Step 6: Create Environment File

Create `.env` file:

```bash
# Path to your Stata Linux installation
STATA_PATH=/Users/yourusername/stata18-linux

# Path to your working directory (project you're testing)
WORK_DIR=/Users/yourusername/my-stata-project
```

## Step 7: Build and Run

```bash
# Build the container (only needed once)
docker-compose build

# Run Stata interactively
docker-compose run --rm stata

# Run a specific .do file
docker-compose run --rm stata stata-mp -b do myfile.do

# Run with batch mode (exits after completion)
docker-compose run --rm stata stata-mp -b "do analysis.do"
```

## Quick Test

Once running, verify Stata works:

```stata
. display c(version)
18

. display c(os)
Unix

. sysuse auto
(1978 automobile data)

. summarize price
```

## Common Issues & Solutions

### "License not found" or "Cannot find license"

```bash
# Check license file exists
ls -la ~/stata18-linux/stata.lic

# Check file format (should have 5+ lines)
cat ~/stata18-linux/stata.lic

# Check permissions
chmod 644 ~/stata18-linux/stata.lic
```

### "Command not found: stata-mp"

```bash
# Check Stata executable exists
ls -la ~/stata18-linux/stata*

# Check it's executable
chmod +x ~/stata18-linux/stata-mp

# Try stata-se or stata if you don't have MP edition
```

### "error while loading shared libraries"

The Dockerfile may be missing a library. Check which one:

```bash
docker-compose run --rm stata ldd /usr/local/stata18/stata-mp
```

Add the missing library to the Dockerfile's `apt-get install` line.

### Slow performance

```bash
# Increase Docker Desktop resources:
# Docker Desktop > Settings > Resources
# Recommended: 4+ CPUs, 8+ GB RAM

# Or limit in docker-compose.yml:
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
```

## Edition Selection

Change the executable based on your Stata edition:

| Edition | Command | docker-compose.yml |
|---------|---------|-------------------|
| MP | `stata-mp` | `CMD ["stata-mp"]` |
| SE | `stata-se` | `CMD ["stata-se"]` |
| BE | `stata` | `CMD ["stata"]` |

## Security Notes

1. **Mount Stata read-only** (`:ro`) to prevent accidental modification
2. **Mount work directory read-write** (`:rw`) only for directories you need to modify
3. The container is isolated - it can only access mounted volumes
4. `python:` and `shell` commands in Stata only affect the container, not your host

## Using with CI/CD

For GitHub Actions or similar:

```yaml
# .github/workflows/test.yml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: your-stata-image
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: stata-mp -b do tests/run_all.do
```

Note: You'll need to build and push your Stata image to a container registry, and handle licensing appropriately for CI/CD.

## Directory Structure Summary

```
~/stata18-linux/           # Stata installation (outside repos)
├── stata-mp               # Executable
├── stata.lic              # Your license file
├── ado/                   # Stata packages
└── ...

~/my-project/              # Your Stata project
├── Dockerfile
├── docker-compose.yml
├── .env
├── analysis.do
└── ...
```

## Quick Reference

```bash
# Build container
docker-compose build

# Interactive Stata
docker-compose run --rm stata

# Run .do file
docker-compose run --rm stata stata-mp -b do myfile.do

# Different working directory
WORK_DIR=/path/to/project docker-compose run --rm stata

# Shell access (debugging)
docker-compose run --rm stata /bin/bash

# Clean up
docker-compose down -v
```
