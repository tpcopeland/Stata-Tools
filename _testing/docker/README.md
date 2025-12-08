# Docker Setup for Sandboxed Stata-MCP Testing

This directory contains Docker configuration for running Claude Code in a sandboxed environment to test Stata-Tools commands using the Stata-MCP server.

## Security Features

- **Sandboxed Environment**: Only Stata-Tools and Stata-MCP directories are accessible
- **Non-root User**: Container runs as non-root `tester` user
- **Resource Limits**: CPU and memory limits prevent runaway processes
- **No Host Access**: Cannot access host filesystem outside mounted directories

## Prerequisites

1. **Docker** and **Docker Compose** installed
2. **Stata-MCP** server directory (your MCP server for Stata)
3. **Stata** installed and licensed (accessible by Stata-MCP)

## Quick Start

### 1. Configure Environment

```bash
# Copy the example env file
cp .env.example .env

# Edit .env and set your Stata-MCP path
# STATA_MCP_PATH=/path/to/your/Stata-MCP
```

### 2. Build the Container

```bash
docker-compose build
```

### 3. Start the Container

```bash
docker-compose up -d
```

### 4. Connect to Container

```bash
docker exec -it stata-mcp-tester bash
```

### 5. Run Tests

Inside the container:
```bash
cd /workspace/Stata-Tools/_testing
# Follow instructions in TESTING_INSTRUCTIONS.md
```

## Directory Structure

When running, the container has access to:

```
/workspace/
├── Stata-Tools/        # This repository (read-write)
├── Stata-MCP/          # Your MCP server (read-write)
└── test-output/        # Test results output (persisted)
```

## Using with Claude Code

### VS Code Setup

1. Install Claude Code extension
2. Configure MCP server settings to point to container
3. Open Stata-Tools in VS Code
4. Claude can now execute Stata commands via MCP

### MCP Configuration Example

Add to your Claude Code settings:

```json
{
  "mcpServers": {
    "stata": {
      "command": "docker",
      "args": [
        "exec", "-i", "stata-mcp-tester",
        "python3", "/workspace/Stata-MCP/server.py"
      ]
    }
  }
}
```

## Safety Notes

1. **No Internet Access (Optional)**: Uncomment `network_mode: none` in docker-compose.yml
2. **Read-Only Mode**: Change `:rw` to `:ro` for read-only mounts if desired
3. **Resource Limits**: Adjust CPU/memory limits in docker-compose.yml

## Troubleshooting

### Container Won't Start
```bash
docker-compose logs stata-mcp-tester
```

### Stata Not Found
Ensure `STATA_PATH` in `.env` points to your Stata executable, or configure it in your Stata-MCP settings.

### Permission Denied
The container runs as user `tester` (UID 1000). Ensure mounted directories are accessible.

## Cleanup

```bash
# Stop container
docker-compose down

# Remove volumes (deletes test output)
docker-compose down -v

# Remove image
docker rmi stata-mcp-tester
```
