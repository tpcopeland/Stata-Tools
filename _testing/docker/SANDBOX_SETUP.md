# Sandboxed Testing Setup

## The Problem
Stata can execute arbitrary code via:
- `python: import os; os.system("rm -rf ~")`
- `shell rm -rf /`

Even with just Stata-MCP access, your entire filesystem is at risk.

## The Solution
Run Claude Code inside Docker. The container:
1. **Only sees Stata-Tools** - No access to your home directory
2. **Connects to your existing Stata-MCP** on port 4000
3. **Sandboxed Python/shell** - Even malicious commands only affect container

## Quick Start

```bash
cd _testing/docker

# Start your Stata-MCP extension in VS Code first (it runs on port 4000)

# Build the sandbox container
docker-compose -f docker-compose.sandbox.yml build

# Run Claude Code inside the sandbox
docker-compose -f docker-compose.sandbox.yml run --rm claude-sandbox

# Inside the container, start Claude Code:
claude
```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  YOUR MAC (Host)                                            │
│                                                             │
│  ┌──────────────────┐     ┌──────────────────────────────┐ │
│  │ VS Code          │     │ Docker Container             │ │
│  │ + Stata-MCP ext  │◄────┤ (Sandboxed)                  │ │
│  │ (port 4000)      │     │                              │ │
│  │                  │     │ ┌─────────────────────────┐  │ │
│  │ Stata MP runs    │     │ │ Claude Code CLI         │  │ │
│  │ here with full   │     │ │                         │  │ │
│  │ filesystem       │     │ │ Can only see:           │  │ │
│  │ access           │     │ │ /workspace/Stata-Tools  │  │ │
│  └──────────────────┘     │ └─────────────────────────┘  │ │
│         ▲                 │                              │ │
│         │                 │ Even if Stata runs:         │ │
│         │                 │ python: os.system("rm -rf") │ │
│         │                 │ ...it only affects container│ │
│  ┌──────┴───────┐         └──────────────────────────────┘ │
│  │ /Users/      │                    ▲                     │
│  │ tcopeland/   │                    │ Network only        │
│  │ (protected)  │                    │ (port 4000)         │
│  └──────────────┘         ┌──────────┴───────────┐         │
│                           │ Stata-Tools/         │         │
│                           │ (mounted read-write) │         │
│                           └──────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## Important Notes

1. **Stata runs on host** - Your Stata license works normally
2. **Only Stata-Tools is exposed** - Container cannot see ~/Documents, etc.
3. **Test output stays in container** - Use `/workspace/output` for results
4. **Container is ephemeral** - `--rm` flag deletes it after use

## MCP Configuration Inside Container

Create `/home/claude/.config/claude-code/mcp.json`:
```json
{
  "mcpServers": {
    "stata": {
      "transport": "http",
      "url": "http://host.docker.internal:4000"
    }
  }
}
```

## Limitations

- Stata output files go to Stata's working directory (on host)
- If Stata saves to absolute paths, those paths must exist on host
- Solution: Always use relative paths in Stata commands
