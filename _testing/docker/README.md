# Stata Linux Docker Setup

Run Stata inside a Docker container for sandboxed testing.

## Why Docker?

- **Sandboxed execution**: Filesystem isolation protects your system
- **Reproducible environments**: Consistent testing across machines
- **Linux Stata required**: Docker runs Linux containers, so you need Stata for Linux

## Prerequisites

1. **Docker Desktop** installed
2. **Stata for Linux** (your license typically covers all platforms)

## Quick Start

### Step 1: Get Stata for Linux

**IMPORTANT**: You need **Stata for Linux**, not macOS Stata. Docker runs Linux containers.

1. Log into https://www.stata.com/customer-service/
2. Go to "Download Stata"
3. Select **"Stata for Unix/Linux (64-bit x86-64)"**
4. Download the `.tar.gz` file (e.g., `Stata18Linux64.tar.gz`)

If you don't see the Linux option, email support@stata.com with your serial number.

### Step 2: Extract Stata Linux

Store Stata Linux **outside any git repos** so it's reusable:

```bash
# Create directory (use your Stata version number)
mkdir -p ~/stata18-linux
cd ~/stata18-linux

# Extract the tar.gz file
tar -xzf ~/Downloads/Stata18Linux64.tar.gz
```

After extraction, you should see files like:
```
~/stata18-linux/
├── stata-mp        # Executable (or stata-se, stata)
├── ado/            # Stata packages
├── auto.dta        # Sample data
└── ...
```

**Verify you have the right files**:
```bash
ls ~/stata18-linux/stata*
# Should show: stata-mp (or stata-se, stata)
# Should NOT show: .app files (that's macOS Stata)
```

### Step 3: Create License File

Create `~/stata18-linux/stata.lic` with your license info (5+ lines):

```
Your Name
Your Institution
123456789012
ABCD-EFGH-IJKL-MNOP
xxxx xxxx xxxx xxxx
xxxx xxxx xxxx xxxx
```

**To find your license info:**
- Check your Stata purchase/renewal email
- On macOS: `Help > About Stata` shows serial/authorization
- License file location: `~/Library/Application Support/Stata/stata.lic`

### Step 4: Configure Docker Environment

```bash
cd /path/to/Stata-Tools/_testing/docker
cp .env.example .env
```

Edit `.env` with your actual paths:

```
STATA_PATH=/Users/yourusername/stata18-linux
STATA_VERSION=18
WORK_DIR=../..
```

### Step 5: Build and Run

```bash
# Build the container (one time, or after changing Dockerfile)
docker-compose build

# Run interactively
docker-compose run --rm stata

# Inside container, run Stata
stata-mp
```

### Step 6: Verify It Works

Inside Stata:

```stata
. display c(version)
18

. display c(os)
Unix

. sysuse auto
. summarize price
```

## Quick Reference

```bash
# Build container
docker-compose build

# Interactive shell
docker-compose run --rm stata

# Run a .do file
docker-compose run --rm stata stata-mp -b do myfile.do

# Different working directory
WORK_DIR=/path/to/project docker-compose run --rm stata

# Clean up
docker-compose down -v
```

## Troubleshooting

### "Stata directory not mounted or empty"

Your `STATA_PATH` in `.env` doesn't point to a valid Stata installation:

```bash
# Check what's in your Stata directory
ls -la ~/stata18-linux/

# You should see stata-mp (or stata-se), ado/, etc.
# If empty: extract the tar.gz file
# If you see .app files: you have macOS Stata, need Linux version
```

### "No Stata executable found"

The directory exists but doesn't have Stata executables:

```bash
# Check for executables
ls ~/stata18-linux/stata*

# If missing, re-extract the tar.gz
cd ~/stata18-linux
tar -xzf ~/Downloads/Stata18Linux64.tar.gz
```

### "License file not found"

```bash
# Check file exists
ls -la ~/stata18-linux/stata.lic

# Check format (should be 5+ lines)
cat ~/stata18-linux/stata.lic

# Fix permissions if needed
chmod 644 ~/stata18-linux/stata.lic
```

### "Command not found: stata-mp"

```bash
# Check executable exists and permissions
ls -la ~/stata18-linux/stata*
chmod +x ~/stata18-linux/stata-mp
```

Use `stata-se` or `stata` if you don't have MP edition.

### "error while loading shared libraries"

Check which library is missing:

```bash
docker-compose run --rm stata ldd /usr/local/stata/stata-mp
```

Add missing library to `apt-get install` in `Dockerfile`, then rebuild.

## Directory Structure

```
~/stata18-linux/              # Stata installation (outside repos)
├── stata-mp                  # Executable
├── stata.lic                 # Your license file
├── ado/                      # Stata packages
└── ...

Stata-Tools/_testing/docker/  # This directory
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── .env                      # Your config (create from .env.example)
├── entrypoint.sh
└── README.md
```

## Edition Selection

| Edition | Executable | Usage |
|---------|------------|-------|
| MP | `stata-mp` | `docker-compose run --rm stata stata-mp` |
| SE | `stata-se` | `docker-compose run --rm stata stata-se` |
| BE | `stata` | `docker-compose run --rm stata stata` |
