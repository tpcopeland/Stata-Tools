# Full Sandbox Setup (Stata Inside Docker)

## The Reality

**Partial sandbox** (Claude in Docker, Stata on host):
- Claude Code cannot directly delete your files
- BUT Stata commands still execute on your Mac
- `python: os.system("rm -rf ~")` would still work

**Full sandbox** (everything in Docker):
- Stata runs inside container with only Stata-Tools mounted
- Even malicious Stata/Python commands are contained
- Requires Stata license configuration

## Option A: Accept the Risk (Simpler)

If you trust Claude not to generate malicious Stata commands:
1. Use your normal VS Code + Stata-MCP setup
2. Review commands before execution
3. Most realistic - Claude rarely generates destructive code

## Option B: Full Sandbox (More Secure)

### Prerequisites
- Stata installer (.tar.gz or .pkg)
- Your Stata license file

### Setup

1. **Copy your Stata installer to this directory**:
```bash
cp /path/to/Stata17Linux64.tar.gz ./stata-installer/
```

2. **Create license file** (`stata-installer/stata.lic`):
```
!Serial number
501706305188
!Code
xxxx xxxx xxxx xxxx xxxx
!Authorization
your-authorization-code
```

3. **Build the full sandbox**:
```bash
docker build -f Dockerfile.full-sandbox -t stata-sandbox .
```

4. **Run**:
```bash
docker run -it --rm \
  -v /path/to/Stata-Tools:/workspace/Stata-Tools \
  stata-sandbox
```

### Dockerfile.full-sandbox

Create this file for full sandbox:

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Stata dependencies
RUN apt-get update && apt-get install -y \
    libpng16-16 \
    libncurses5 \
    libgtk2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Stata (you provide the installer)
COPY stata-installer/Stata*.tar.gz /tmp/
RUN cd /tmp && tar -xzf Stata*.tar.gz && \
    cd stata* && ./install -q -d /usr/local/stata17

# Copy license
COPY stata-installer/stata.lic /usr/local/stata17/stata.lic

# Add Stata to path
ENV PATH="/usr/local/stata17:$PATH"

# Install Node.js for Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Install Claude Code and Stata-MCP
RUN npm install -g @anthropic-ai/claude-code

# Create user
RUN useradd -m -s /bin/bash tester
USER tester
WORKDIR /workspace/Stata-Tools

CMD ["bash"]
```

## Option C: Review Mode (Recommended)

Use Stata-MCP's built-in safety features:

1. **Enable command confirmation** in VS Code settings
2. **Review each Stata command** before execution
3. **Reject suspicious commands** like:
   - `shell *`
   - `python: *`
   - `erase` with absolute paths

This is practical security without complex Docker setup.

## My Recommendation

For autonomous testing of YOUR OWN code in Stata-Tools:
1. Commands are from your test files, not generated
2. Risk is low - you wrote the tests
3. Use Option C (review mode) for peace of mind

For letting Claude write NEW Stata code autonomously:
1. Use Option B (full sandbox)
2. Or carefully review all commands before execution
