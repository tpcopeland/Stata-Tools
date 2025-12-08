# Stata Linux Docker Setup

Run Stata inside a Docker container for sandboxed testing.

## Why Docker?

- **Sandboxed execution**: Filesystem isolation protects your system
- **Reproducible environments**: Consistent testing across machines
- **Required for Apple Silicon Macs**: Stata Linux is x86-64 only; Docker provides emulation

## Prerequisites

1. **Docker Desktop** installed
2. **Stata for Linux** downloaded (your license typically covers all platforms)

## Quick Start

### Step 1: Get Stata for Linux

**IMPORTANT**: You need **Stata for Linux**, not macOS Stata.

1. Log into https://www.stata.com/customer-service/
2. Go to "Download Stata"
3. Select **"Stata for Unix/Linux (64-bit x86-64)"**
4. Download the `.tar.gz` file (e.g., `Stata17Linux64.tar.gz`)

If you don't see the Linux option, email support@stata.com with your serial number.

### Step 2: Extract Stata Linux

Store Stata Linux **outside any git repos**:

```bash
# Create directory (use your Stata version number)
mkdir -p ~/stata17-linux
cd ~/stata17-linux

# Extract the tar.gz file
tar -xzf ~/Downloads/Stata17Linux64.tar.gz
```

After extraction, you should see:
```
~/stata17-linux/
├── stata-mp        # Executable
├── stinit          # License initialization tool
├── ado/            # Stata packages
└── ...
```

**DO NOT run `./stinit` directly on macOS** - it will fail with "exec format error" because it's a Linux binary. License initialization happens inside Docker.

### Step 3: Configure Docker Environment

```bash
cd /path/to/Stata-Tools/_testing/docker
cp .env.example .env
```

Edit `.env` with your paths:

```
STATA_PATH=/Users/yourusername/stata17-linux
STATA_VERSION=17
WORK_DIR=/path/to/your/working/directory
```

### Step 4: Build and Run

```bash
# Build the container (first time or after Dockerfile changes)
docker-compose build

# Run interactively
docker-compose run --rm stata
```

### Step 5: Initialize License (First Time Only)

On first run, you'll see "License not initialized". Run `stinit` inside the container:

```bash
# Inside the container:
cd /usr/local/stata
./stinit
```

Enter your license information when prompted:
- Serial number
- Code (authorization code)
- First/Last name
- Organization

**Find your license info:**
- Check your Stata purchase/renewal email
- On macOS Stata: `Help > About Stata`
- stata.com/customer-service/ (login required)

The license is saved to your mounted Stata directory, so you only need to do this once.

### Step 6: Run Stata

```bash
# Inside the container:
stata-mp
```

Verify it works:
```stata
. display c(version)
17

. display c(os)
Unix

. sysuse auto
. summarize price
```

## Apple Silicon Macs (M1/M2/M3)

This setup automatically handles Apple Silicon via `platform: linux/amd64` in docker-compose.yml. Docker Desktop uses Rosetta 2 for x86-64 emulation.

**Performance note**: Emulated x86-64 runs slower than native. This is fine for testing but not ideal for heavy computation.

## Quick Reference

```bash
# Build container
docker-compose build

# Interactive shell
docker-compose run --rm stata

# Run a .do file
docker-compose run --rm stata stata-mp -b do myfile.do

# Initialize license (first time)
docker-compose run --rm stata bash -c "cd /usr/local/stata && ./stinit"

# Clean up
docker-compose down -v
```

## Troubleshooting

### "exec format error" when running stinit

You're trying to run Linux binaries directly on macOS. Run `stinit` **inside the Docker container**, not on your Mac.

### "Stata directory not mounted or empty"

Your `STATA_PATH` in `.env` doesn't point to valid Stata files:

```bash
# Check what's in your Stata directory
ls -la ~/stata17-linux/

# Should see: stata-mp, stinit, ado/, etc.
# If empty: re-extract the tar.gz file
```

### "License not initialized"

Run `stinit` inside the container:

```bash
docker-compose run --rm stata
# Then inside container:
cd /usr/local/stata
./stinit
```

### "No Stata executable found"

The directory exists but doesn't have Stata executables:

```bash
ls ~/stata17-linux/stata*
# Should show stata-mp (or stata-se, stata)
```

If you see `.app` files, you downloaded macOS Stata instead of Linux.

### Container is slow (Apple Silicon)

This is expected - Docker is emulating x86-64 on ARM. For heavy work, consider:
- Using macOS Stata directly for computation
- Using Docker only for testing/verification

### "error while loading shared libraries"

Check which library is missing:

```bash
docker-compose run --rm stata ldd /usr/local/stata/stata-mp
```

Add missing library to `apt-get install` in `Dockerfile`, then rebuild.

## Directory Structure

```
~/stata17-linux/              # Stata installation (outside repos)
├── stata-mp                  # Executable
├── stinit                    # License initialization
├── stata.lic                 # License file (created by stinit)
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
