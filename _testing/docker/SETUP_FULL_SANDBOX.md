# Full Sandbox Setup Guide

This guide sets up complete filesystem isolation where Stata runs inside Docker.

## Prerequisites

1. **Docker Desktop** for Mac
2. **Stata for Linux** (you need the Linux version, not macOS)
3. **Your Stata license** (works across platforms)

## Step 1: Get Stata for Linux

You have two options:

### Option A: Download from Stata (Recommended)

1. Log into your Stata account: https://www.stata.com/customer-service/
2. Download "Stata 17 for Unix/Linux (64-bit)"
3. You'll get a `.tar.gz` file

### Option B: Request from Stata Support

Email stata@stata.com and explain you need the Linux version for Docker testing.
They can usually add it to your license.

## Step 2: Set Up Stata Linux (External to Repo)

Store Stata Linux **outside your repos** so it's reusable across projects:

```bash
# Create a dedicated directory for Stata Linux (outside any repo)
mkdir -p ~/stata17-linux

# Extract Stata Linux there
tar -xzf ~/Downloads/Stata17Linux64.tar.gz -C ~/stata17-linux/

# Your license file - create from your existing license info
cat > ~/stata17-linux/stata.lic << 'EOF'
Timothy Copeland
UCSF
501706305188
your-authorization-code
your-code-block
EOF
```

The `stata.lic` file format is:
```
Name
Institution
Serial Number
Authorization Code
Code Block (the alphanumeric code from your license)
```

## Step 3: Configure Environment

```bash
cd /path/to/Stata-Tools/_testing/docker

# Copy example env file
cp .env.full.example .env.full

# Edit with your paths
nano .env.full
```

Set these values:
```bash
# Path to the repo you're testing (can change for different projects)
STATA_TOOLS_PATH=../..

# Path to your Stata Linux installation (reusable across all projects)
STATA_LINUX_PATH=/Users/tcopeland/stata17-linux

# Path to Stata-MCP extension
STATA_MCP_PATH=/Users/tcopeland/.vscode/extensions/deepecon.stata-mcp-0.3.6/src

# Stata edition
STATA_EDITION=mp
```

## Step 4: Build the Container

```bash
docker-compose -f docker-compose.full.yml --env-file .env.full build
```

## Step 5: Test Stata Works

```bash
# Start container
docker-compose -f docker-compose.full.yml --env-file .env.full run --rm stata-full-sandbox

# Inside container, test Stata
stata-mp -b "display 1+1"
cat stata.log
```

## Step 6: Run Tests

Inside the container:
```bash
cd /workspace/Stata-Tools/_testing

# Generate test data
stata-mp -b do generate_test_data.do

# Run all tests
stata-mp -b do run_all_tests.do
```

## Step 7: Connect Claude Code

### Option A: Use Claude Code inside container

```bash
# Install Claude Code CLI in container
npm install -g @anthropic-ai/claude-code

# Start Claude
claude
```

### Option B: Connect from host to container's MCP

The container exposes port 4000 with SSE transport. Configure Claude Code on your Mac:

**Method 1: CLI (Recommended)**
```bash
claude mcp add --transport sse stata-mcp http://localhost:4000/mcp --scope user
```

**Method 2: Manual config** (in `~/.claude/mcp.json`):
```json
{
  "mcpServers": {
    "stata-mcp": {
      "transport": "sse",
      "url": "http://localhost:4000/mcp"
    }
  }
}
```

### Stata-MCP VS Code Settings (Optional)

Configure these in VS Code settings for better AI interaction:

| Setting | Description | Recommended |
|---------|-------------|-------------|
| `stata-vscode.resultDisplayMode` | "compact" filters verbose output | compact |
| `stata-vscode.maxOutputTokens` | Limit tokens (0=unlimited) | 10000 |
| `stata-vscode.runFileTimeout` | Execution timeout (seconds) | 600 |
| `stata-vscode.stataEdition` | MP, SE, or BE | mp |
| `stata-vscode.autoStartServer` | Start MCP on extension load | true |

See: https://github.com/hanlulong/stata-mcp

## Directory Structure Inside Container

```
/workspace/
├── Stata-Tools/          # Your repo (read-write)
└── output/               # Test output (persisted)

/usr/local/stata17/       # Stata installation (read-only)
├── stata-mp              # Stata executable
├── stata.lic             # Your license
└── ado/                  # Stata packages

/opt/stata-mcp/           # MCP server (read-only)
```

## Security Verification

Test that the sandbox works:

```stata
* This should FAIL or only affect container
python: import os; os.system("ls /")  // Only sees container filesystem
shell ls ~                             // Only sees container home dir

* This should work normally
sysuse auto
summarize price
```

## Testing Other Repositories

Once set up, you can easily test any Stata project:

```bash
# Option 1: Create a separate .env file for each project
cp .env.full .env.full.myproject
# Edit STATA_TOOLS_PATH to point to /path/to/my-other-project

# Run with that config
docker-compose -f docker-compose.full.yml --env-file .env.full.myproject run --rm stata-full-sandbox

# Option 2: Override just the repo path
STATA_TOOLS_PATH=/path/to/other-repo docker-compose -f docker-compose.full.yml --env-file .env.full run --rm stata-full-sandbox
```

The Stata Linux installation (`~/stata17-linux`) is shared across all projects.

## Troubleshooting

### "License not found"
- Check `~/stata17-linux/stata.lic` exists and is correctly formatted
- Run `stata-mp` without `-b` to see interactive license prompt

### "Command not found: stata-mp"
- Check Stata files are in `~/stata17-linux/` directory
- Verify executable: `chmod +x ~/stata17-linux/stata-mp`

### "Library not found"
- The Dockerfile installs common dependencies
- If you see missing lib errors, add them to the Dockerfile

### Slow performance
- Increase Docker Desktop resources (CPU/RAM)
- Use `batch(50)` in tvmerge for faster processing

## Quick Reference

```bash
# Build (only needed once, or after Dockerfile changes)
docker-compose -f docker-compose.full.yml --env-file .env.full build

# Start interactive shell
docker-compose -f docker-compose.full.yml --env-file .env.full run --rm stata-full-sandbox

# Run a specific test
docker-compose -f docker-compose.full.yml --env-file .env.full run --rm stata-full-sandbox \
  stata-mp -b "do _testing/test_tvexpose.do"

# Test a different repo
STATA_TOOLS_PATH=/path/to/other-repo docker-compose -f docker-compose.full.yml --env-file .env.full run --rm stata-full-sandbox

# Stop and clean up
docker-compose -f docker-compose.full.yml down -v
```
