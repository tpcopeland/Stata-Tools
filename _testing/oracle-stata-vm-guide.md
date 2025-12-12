# Oracle Cloud VM + Stata Setup Guide

## Important: Which Claude Product?

| Product | MCP Support | How Stata Access Works |
|---------|-------------|------------------------|
| **Claude.ai** (web/mobile) | ❌ No | N/A - use Claude Code CLI instead |
| **Claude Code CLI** (`claude` in terminal) | ✅ Yes | Configure MCP, SSH tunnel to VM |
| **Claude Desktop** | ✅ Yes | Same as CLI |

This guide targets **Claude Code CLI** on your Mac connecting to Stata on Oracle Cloud.

---

## Architecture

```
Your Mac                              Oracle Cloud VM (Free Tier)
────────                              ──────────────────────────
Claude Code CLI                       
    │                                 
    ├── MCP Client ←─ SSE ─────────→  Stata MCP Server (:4000)
    │         (via SSH tunnel)              │
    │                                       ↓
    └── SSH tunnel (:4000) ────────→  pystata → Stata Linux
                                            │
                                      /home/ubuntu/Stata-Tools/
```

---

## Part 1: Oracle Cloud VM Setup

### 1.1 Create Account
1. Go to https://cloud.oracle.com/free
2. Sign up (credit card required, won't charge for free tier)
3. Select home region close to you

### 1.2 Create Compute Instance
Navigate: **Compute → Instances → Create Instance**

| Setting | Value | Notes |
|---------|-------|-------|
| Name | `stata-sandbox` | |
| Image | Ubuntu 22.04 | |
| Shape | VM.Standard.E2.1.Micro | Free tier, 1 OCPU, 1GB RAM |
| SSH Keys | Upload `~/.ssh/id_rsa.pub` | Or generate new |

⚠️ **Stata requires x86.** The ARM shapes (A1.Flex) won't work.

### 1.3 Record Instance Details
After creation, note:
- **Public IP**: `YOUR_VM_IP`
- **Username**: `ubuntu`

---

## Part 2: VM Firewall

### 2.1 Oracle Security List
Only port 22 (SSH) needed. Port 4000 stays internal (tunnel handles it).

Default config should work. If not:
1. **Networking → VCNs → Your VCN → Security Lists**
2. Verify ingress rule exists for TCP/22

### 2.2 VM Firewall
```bash
ssh ubuntu@YOUR_VM_IP
sudo ufw status
# If active, SSH should already be allowed
```

---

## Part 3: Install Stata on VM

### 3.1 Transfer Stata
From your Mac:
```bash
scp ~/Downloads/Stata17Linux64.tar.gz ubuntu@YOUR_VM_IP:~/
```

### 3.2 Install
```bash
ssh ubuntu@YOUR_VM_IP

# Create directory
sudo mkdir -p /usr/local/stata17
sudo chown $USER:$USER /usr/local/stata17

# Extract
cd /usr/local/stata17
tar -xzf ~/Stata17Linux64.tar.gz --strip-components=1
# If that fails, try without --strip-components and move contents

# Make executable
chmod +x stata* stinit

# Initialize license
./stinit
# Enter: serial number, code, authorization
```

### 3.3 Dependencies
```bash
sudo apt-get update
sudo apt-get install -y libpng16-16 libncurses5 libtinfo5 locales

# Locale
sudo locale-gen en_US.UTF-8
echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc
source ~/.bashrc
```

### 3.4 Verify
```bash
/usr/local/stata17/stata-mp -q <<< "display 1+1"
# Should output: 2
```

### 3.5 Symlink (optional)
```bash
sudo ln -s /usr/local/stata17/stata-mp /usr/local/bin/stata
```

---

## Part 4: Install Stata MCP Server

Two options. **Option A is simpler.**

### Option A: PyPI Package (Recommended)

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# Test it works
uvx stata-mcp --help

# Set Stata path if not default
export STATA_PATH=/usr/local/stata17
echo 'export STATA_PATH=/usr/local/stata17' >> ~/.bashrc
```

Run the server:
```bash
# Foreground (for testing)
uvx stata-mcp --transport sse --port 4000 --host 127.0.0.1

# Or with explicit Stata path
STATA_PATH=/usr/local/stata17 uvx stata-mcp --transport sse --port 4000 --host 127.0.0.1
```

### Option B: DeepEcon Extension Server

Clone and run the server from the VS Code extension:
```bash
# Install dependencies
sudo apt-get install -y python3.11 python3.11-venv
mkdir -p ~/stata-mcp && cd ~/stata-mcp
python3.11 -m venv .venv
source .venv/bin/activate
pip install fastapi uvicorn pystata-mcp

# Get server script (if you have it locally)
# scp from your Mac: ~/.vscode/extensions/deepecon.stata-mcp-*/src/stata_mcp_server.py

# Set Python path for pystata
export PYTHONPATH=/usr/local/stata17/utilities:$PYTHONPATH
```

---

## Part 5: Run MCP Server as Service

```bash
# Create systemd service
sudo tee /etc/systemd/system/stata-mcp.service << 'EOF'
[Unit]
Description=Stata MCP Server
After=network.target

[Service]
Type=simple
User=ubuntu
Environment=STATA_PATH=/usr/local/stata17
ExecStart=/home/ubuntu/.local/bin/uvx stata-mcp --transport sse --port 4000 --host 127.0.0.1
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable stata-mcp
sudo systemctl start stata-mcp
sudo systemctl status stata-mcp
```

Check logs:
```bash
sudo journalctl -u stata-mcp -f
```

---

## Part 6: SSH Tunnel from Mac

### 6.1 SSH Config
Add to `~/.ssh/config`:
```
Host stata-vm
    HostName YOUR_VM_IP
    User ubuntu
    LocalForward 4000 127.0.0.1:4000
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### 6.2 Open Tunnel
```bash
# Foreground (see connection status)
ssh stata-vm -N

# Background
ssh stata-vm -N -f
```

### 6.3 Verify
```bash
curl http://localhost:4000/health
# or
curl http://localhost:4000/mcp
```

### 6.4 Persistent Tunnel (Optional)
```bash
brew install autossh
autossh -M 0 -f -N stata-vm
```

---

## Part 7: Configure Claude Code CLI

### 7.1 Install Claude Code
```bash
# If not installed
npm install -g @anthropic-ai/claude-code
# or
brew install claude-code
```

### 7.2 Add Stata MCP Server

**For PyPI stata-mcp (SSE transport):**
```bash
claude mcp add-json "stata" '{"url":"http://localhost:4000/mcp","transport":"sse"}'
```

**For local stdio (if running on same machine):**
```bash
claude mcp add stata -- uvx stata-mcp
```

### 7.3 Verify MCP
```bash
claude mcp list
# Should show "stata" as configured
```

Start Claude Code and check:
```bash
claude
# Then inside Claude Code:
/mcp
# Should show stata as connected
```

---

## Part 8: Clone Your Repository

On the VM:
```bash
mkdir -p ~/workspace && cd ~/workspace
git clone https://github.com/tpcopeland/Stata-Tools.git
```

---

## Part 9: Workflow

### Sync Code Changes

**Option A: Git**
```bash
# Mac: push
cd ~/Documents/GitHub/Stata-Tools && git push

# VM: pull
ssh stata-vm "cd ~/workspace/Stata-Tools && git pull"
```

**Option B: rsync**
```bash
rsync -avz --exclude '.git' \
    ~/Documents/GitHub/Stata-Tools/ \
    stata-vm:~/workspace/Stata-Tools/
```

### Run Stata via Claude Code

With tunnel active:
```bash
claude
```

Then ask Claude to run Stata commands. The MCP server executes them on the VM.

---

## Troubleshooting

### MCP Server Won't Start
```bash
# Check service logs
sudo journalctl -u stata-mcp --no-pager -n 50

# Test Stata directly
/usr/local/stata17/stata-mp -q <<< "di 1+1"

# Test uvx
uvx stata-mcp --help
```

### pystata Import Errors
```bash
# Verify Stata utilities path exists
ls /usr/local/stata17/utilities/pystata

# Test Python import
python3 -c "import sys; sys.path.insert(0, '/usr/local/stata17/utilities'); from pystata import config; print('OK')"
```

### SSH Tunnel Drops
```bash
# Check if tunnel is active
lsof -i :4000

# Use autossh for reliability
autossh -M 0 -f -N stata-vm
```

### Memory Issues (1GB VM)
- Run tests one at a time
- Use smaller datasets
- Consider paid VM if needed

### Claude Code Can't Connect to MCP
```bash
# Verify tunnel
curl http://localhost:4000/health

# Check Claude Code config
claude mcp list
claude mcp get stata

# Re-add if needed
claude mcp remove stata
claude mcp add-json "stata" '{"url":"http://localhost:4000/mcp","transport":"sse"}'
```

---

## Cost Summary

| Item | Cost |
|------|------|
| Oracle Cloud VM.Standard.E2.1.Micro | $0 (always free) |
| Stata License | Already owned |
| Egress | Free tier: 10TB/month |

---

## Quick Reference

| Task | Command |
|------|---------|
| Start tunnel | `ssh stata-vm -N` |
| Check tunnel | `lsof -i :4000` |
| Start Claude Code | `claude` |
| Check MCP servers | `/mcp` (in Claude Code) |
| Sync code | `rsync -avz ~/Stata-Tools/ stata-vm:~/workspace/Stata-Tools/` |
| VM SSH | `ssh stata-vm` |
| Service logs | `sudo journalctl -u stata-mcp -f` |
