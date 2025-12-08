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

1. Log into https://www.stata.com/customer-service/
2. Go to "Download Stata"
3. Select **"Stata for Unix/Linux (64-bit x86-64)"**
4. Download the `.tar.gz` file

If you don't see the Linux option, email support@stata.com with your serial number.

### Step 2: Extract Stata Linux

Store Stata Linux **outside any git repos** so it's reusable:

```bash
mkdir -p ~/stata18-linux
cd ~/stata18-linux
tar -xzf ~/Downloads/Stata18Linux64.tar.gz
```

### Step 3: Create License File

Create `~/stata18-linux/stata.lic` with this format (5+ lines):

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
- On macOS: `Help > About Stata` or `~/Library/Application Support/Stata/stata.lic`

### Step 4: Configure Docker Environment

```bash
cd /path/to/Stata-Tools/_testing/docker
cp .env.example .env
```

Edit `.env` with your actual paths:

```
STATA_PATH=/Users/yourusername/stata18-linux
WORK_DIR=../..
```

### Step 5: Build and Run

```bash
# Build the container (one time)
docker-compose build

# Run Stata interactively
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

### "License not found"

```bash
ls -la ~/stata18-linux/stata.lic    # Check file exists
cat ~/stata18-linux/stata.lic       # Check format (5+ lines)
chmod 644 ~/stata18-linux/stata.lic # Fix permissions
```

### "Command not found: stata-mp"

```bash
ls -la ~/stata18-linux/stata*       # Check executable exists
chmod +x ~/stata18-linux/stata-mp   # Make executable
```

Use `stata-se` or `stata` if you don't have MP edition.

### "error while loading shared libraries"

Check which library is missing:

```bash
docker-compose run --rm stata ldd /usr/local/stata18/stata-mp
```

Add missing library to `apt-get install` in `Dockerfile`.

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
