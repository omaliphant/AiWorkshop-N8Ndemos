# Oz' AI Workshop - Setup & Troubleshooting Guide
## N8N RAG Demo - 9 September 2025

## 📋 Table of Contents
- [Prerequisites Check](#prerequisites-check)
- [Windows Installation](#windows-installation)
- [macOS Installation](#macos-installation)
- [Linux Installation](#linux-installation)
- [N8N Template Import](#n8n-template-import)
- [Troubleshooting](#troubleshooting)
- [Verification Steps](#verification-steps)
- [FAQ](#frequently-asked-questions)

## Prerequisites Check

### System Requirements Verification

#### Windows
```powershell
# Check Windows version
[System.Environment]::OSVersion.Version

# Check available RAM
Get-WmiObject Win32_ComputerSystem | Select-Object TotalPhysicalMemory

# Check available disk space
Get-PSDrive C | Select-Object Used,Free

# Check PowerShell version
$PSVersionTable.PSVersion
```

#### macOS/Linux
```bash
# Check system info
uname -a

# Check available RAM
free -h  # Linux
sysctl hw.memsize  # macOS

# Check available disk space
df -h

# Check Docker installation
docker --version
```

## Windows Installation

### Automated Installation (Recommended)

1. **Clone the Workshop Repository**
   ```powershell
   # Clone from GitLab
   git clone [repository-url]
   cd oz-ai-workshop-n8n
   ```

2. **Open PowerShell as Administrator**
   ```powershell
   # Windows Key + X → Windows PowerShell (Admin)
   
   # Set execution policy
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   ```

3. **Run Prerequisites Installation**
   ```powershell
   # Navigate to repository
   cd oz-ai-workshop-n8n
   
   # Run installation script
   .\scripts\install-prerequisites.ps1
   
   # Optional flags:
   # -InstallPath "D:\Workshop"  # Custom install location
   # -SkipOllama                  # Skip Ollama installation
   # -SkipDocker                  # Skip Docker check
   ```

4. **Setup Containers**
   ```powershell
   # Run container setup script
   .\scripts\setup-containers.ps1
   
   # Optional flags:
   # -WorkshopPath "D:\Workshop"  # Custom path
   # -ChromaDBPort "8001"          # Custom ChromaDB port
   # -N8NPort "5679"               # Custom N8N port
   # -RemoveExisting               # Remove existing containers
   ```

### Manual Docker Desktop Installation

If Docker Desktop is not installed:

1. **Download Docker Desktop**
   - Visit: https://www.docker.com/products/docker-desktop/
   - Download Docker Desktop for Windows
   - Run installer as Administrator

2. **Configure Docker Desktop**
   ```powershell
   # After installation, configure settings
   # Open Docker Desktop → Settings
   # - General: Enable "Start Docker Desktop when you log in"
   # - Resources: Allocate at least 4GB RAM
   # - Resources → WSL Integration: Enable integration
   ```

3. **Verify Docker Installation**
   ```powershell
   docker --version
   docker ps
   ```

## macOS Installation

### Step 1: Install Homebrew (if needed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 2: Install Docker Desktop
```bash
# Download and install Docker Desktop for Mac
# https://www.docker.com/products/docker-desktop/

# Or use Homebrew
brew install --cask docker
```

### Step 3: Install Ollama
```bash
# Download from https://ollama.com/download/mac
# Or use curl
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama
ollama serve

# Pull required models
ollama pull llama3.2:3b
ollama pull nomic-embed-text
```

### Step 4: Setup Containers
```bash
# Create directories
mkdir -p ~/Workshop/{chromadb/data,n8n/data,n8n/files,test,scripts}

# Run ChromaDB
docker run -d \
  --name chromadb \
  -p 8000:8000 \
  -v ~/Workshop/chromadb/data:/chroma/chroma \
  -e IS_PERSISTENT=TRUE \
  -e ANONYMIZED_TELEMETRY=FALSE \
  --restart unless-stopped \
  chromadb/chroma:latest

# Run N8N
docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v ~/Workshop/n8n/data:/home/node/.n8n \
  -v ~/Workshop/n8n/files:/files \
  -e N8N_SECURE_COOKIE=false \
  --restart unless-stopped \
  n8nio/n8n:latest
```

## Linux Installation

### Ubuntu/Debian
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
sudo systemctl start ollama
sudo systemctl enable ollama

# Pull models
ollama pull llama3.2:3b
ollama pull nomic-embed-text

# Create workshop directories
mkdir -p ~/Workshop/{chromadb/data,n8n/data,n8n/files,test,scripts}

# Run containers (same as macOS commands above)
```

## N8N Template Import

### Importing Workshop Workflows

1. **Access N8N Interface**
   - Open browser: http://localhost:5678
   - Create account if first time

2. **Import Workflow Templates**
   
   **Method 1: Import from File**
   - Click "Workflows" → "Import from File"
   - Navigate to repository's `/n8n-templates/` folder
   - Import in this order:
     1. `initialize-chromadb.json` - Run once to setup database
     2. `document-indexer.json` - For processing documents
     3. `qa-system.json` - For handling queries

   **Method 2: Copy JSON**
   - Open template file in text editor
   - Copy entire JSON content
   - In N8N: Create New Workflow → Import from URL/JSON
   - Paste and import

3. **Configure Google Drive OAuth**
   - Go to Credentials → New → Google Drive OAuth2
   - Follow OAuth setup wizard
   - Required scopes:
     - `https://www.googleapis.com/auth/drive.readonly`
     - `https://www.googleapis.com/auth/drive.metadata.readonly`
   - Test connection

4. **Initialize ChromaDB**
   - Open "Initialize ChromaDB" workflow
   - Click "Execute Workflow"
   - Should see success message

5. **Configure Document Indexer**
   - Open "Document Indexer" workflow
   - Edit "List Drive Files" node
   - Set your folder ID or search parameters
   - Save workflow

## Troubleshooting

### Common Issues and Solutions

#### 1. Scripts Not Found

**Problem**: PowerShell can't find scripts

**Solution**:
```powershell
# Ensure you're in the repository directory
cd oz-ai-workshop-n8n

# List available scripts
Get-ChildItem .\scripts\

# Run with full path if needed
& "C:\path\to\oz-ai-workshop-n8n\scripts\install-prerequisites.ps1"
```

#### 2. Docker Desktop Not Starting

**Problem**: Docker Desktop won't start or shows "Docker Desktop is starting..."

**Solutions**:
```powershell
# Windows - Enable virtualization
# 1. Restart computer
# 2. Enter BIOS (F2/F10/Del during boot)
# 3. Enable: Intel VT-x/AMD-V, Hyper-V

# Check virtualization status
Get-ComputerInfo -property "HyperV*"

# Enable Hyper-V (Windows)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

# Reset Docker Desktop
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\Docker" -Recurse -Force
# Reinstall Docker Desktop
```

#### 3. Ollama Connection Refused

**Problem**: Cannot connect to Ollama API

**Solutions**:
```bash
# Check if Ollama is running
ps aux | grep ollama  # Linux/macOS
Get-Process ollama    # Windows

# Start Ollama service
ollama serve

# Check API endpoint
curl http://localhost:11434/api/tags

# Windows firewall issue
New-NetFirewallRule -DisplayName "Ollama API" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow
```

#### 4. ChromaDB Container Fails

**Problem**: ChromaDB container exits immediately

**Solutions**:
```bash
# Check logs
docker logs chromadb

# Common fixes:
# 1. Port conflict
netstat -an | findstr :8000  # Windows
lsof -i :8000                 # macOS/Linux

# 2. Permission issues
# Windows: Run as Administrator
# Linux/macOS:
sudo chown -R $(whoami):$(whoami) ~/Workshop/chromadb

# 3. Recreate container
docker stop chromadb
docker rm chromadb
# Run setup script again
.\scripts\setup-containers.ps1
```

#### 5. N8N Webhook Not Accessible

**Problem**: Cannot access N8N webhook endpoint

**Solutions**:
```bash
# Check N8N logs
docker logs n8n

# Verify container is running
docker ps | grep n8n

# Test webhook
curl -X POST http://localhost:5678/webhook/test

# Check firewall
# Windows
New-NetFirewallRule -DisplayName "N8N" -Direction Inbound -Protocol TCP -LocalPort 5678 -Action Allow

# Linux
sudo ufw allow 5678/tcp
```

#### 6. N8N Template Import Fails

**Problem**: Cannot import workflow templates

**Solutions**:
1. Check file path is correct: `/n8n-templates/*.json`
2. Ensure JSON files are not corrupted
3. Try copy-paste method instead of file import
4. Check N8N version compatibility
5. Clear browser cache and retry

#### 7. Google Drive Authentication Issues

**Problem**: Cannot authenticate with Google Drive

**Solutions**:
1. In N8N, go to Credentials → New → Google Drive OAuth2
2. Ensure correct OAuth scopes (see above)
3. Check redirect URI matches N8N URL
4. Clear browser cookies and retry
5. Verify Google Cloud Console settings

#### 8. Slow Model Performance

**Problem**: Llama 3.2 responses are very slow

**Solutions**:
```bash
# Check system resources
docker stats

# Reduce model size
ollama pull llama3.2:1b  # Smaller model

# Adjust Ollama settings
OLLAMA_NUM_PARALLEL=1 ollama serve
OLLAMA_MAX_LOADED_MODELS=1 ollama serve

# Increase Docker resources
# Docker Desktop → Settings → Resources
# Increase CPU and Memory allocation
```

## Verification Steps

### Complete System Check

Run these commands to verify everything is working:

```powershell
# 1. Check Ollama
ollama list
curl http://localhost:11434/api/tags

# 2. Check ChromaDB
curl http://localhost:8000/api/v1/heartbeat

# 3. Check N8N
curl http://localhost:5678

# 4. Check Docker containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 5. Test Ollama embedding
curl http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text",
  "prompt": "test"
}'

# 6. Test ChromaDB collection
curl -X POST http://localhost:8000/api/v1/collections -H "Content-Type: application/json" -d '{
  "name": "test_collection"
}'
```

### Expected Output
```
✓ Ollama: 2 models installed (llama3.2:3b, nomic-embed-text)
✓ ChromaDB: {"nanosecond heartbeat": ...}
✓ N8N: HTML response
✓ Containers: chromadb (Up), n8n (Up)
✓ Embedding: {"embedding": [...]}
✓ Collection: {"name": "test_collection"}
```

## Frequently Asked Questions

### Workshop-Specific Questions

**Q: Where are the workshop materials?**
- Scripts: `/scripts/` directory
- N8N Templates: `/n8n-templates/` directory
  - `document-indexer-local.json` - Indexes local files
  - `qa-system-local.json` - Q&A webhook
  - `initialize-chromadb-local.json` - Setup database
- Test Interface: Created in `c:\dev\workshop\test\`

**Q: Do I need Google Drive access?**
- No! This version works with local or mapped drives
- Just point to your G: drive or any local folder
- No authentication or API keys required

**Q: What if I miss the workshop?**
- All materials are in the GitLab repository
- Follow this guide for self-paced learning
- Join the next Oz' AI Workshop session

**Q: Can I use this after the workshop?**
- Yes! All components are open source
- Keep the repository for reference
- Modify for your own use cases

### Technical Questions

**Q: Can I run this on a laptop?**
- Yes, with at least 8GB RAM (16GB recommended)
- Close other applications during workshop
- Consider using smaller models if needed

**Q: Why use Docker?**
- Consistent environment across all systems
- Easy cleanup after workshop
- Isolated dependencies
- No system pollution

**Q: Can I use different models?**
```bash
# Smaller/faster models
ollama pull gemma:2b
ollama pull phi3:mini

# Larger/better models (need more RAM)
ollama pull llama3.2:7b
ollama pull mixtral:8x7b
```

**Q: How do I completely uninstall?**
```powershell
# Windows
.\scripts\manage-containers.ps1 -Action stop
docker rm chromadb n8n
docker rmi chromadb/chroma n8nio/n8n
Remove-Item -Path "c:\dev\workshop" -Recurse -Force

# Uninstall Ollama via Control Panel
# Uninstall Docker Desktop via Control Panel
```

**Q: Can I change ports?**
- Edit the scripts before running
- Or modify docker run commands:
  - ChromaDB: `-p 8001:8000`
  - N8N: `-p 5679:5678`
- Update webhook URLs in workflows

**Q: How do I backup my work?**
```powershell
# Backup entire workshop
Compress-Archive -Path "c:\dev\workshop" -DestinationPath "Workshop_Backup_$(Get-Date -Format 'yyyyMMdd').zip"

# Export N8N workflows
# In N8N UI: Select workflow → Settings → Download
```

## Support Resources

### During the Workshop
- **Primary**: Ask Oz directly
- **Slack/Teams**: Workshop channel
- **Break time**: One-on-one help

### After the Workshop

1. **Check Logs First**
   ```bash
   docker logs chromadb --tail 50
   docker logs n8n --tail 50
   ollama serve  # Run in terminal to see output
   ```

2. **Community Support**
   - Workshop GitLab Issues
   - N8N Community: https://community.n8n.io
   - Ollama GitHub: https://github.com/ollama/ollama/issues
   - ChromaDB Discord: https://discord.gg/MMeYNTmh3x

### Useful Commands Reference

```powershell
# Container Management (using workshop scripts)
.\scripts\manage-containers.ps1 -Action start
.\scripts\manage-containers.ps1 -Action stop
.\scripts\manage-containers.ps1 -Action restart
.\scripts\manage-containers.ps1 -Action status
.\scripts\manage-containers.ps1 -Action logs

# Direct Docker Commands
docker start chromadb n8n
docker stop chromadb n8n
docker restart chromadb n8n
docker ps -a
docker logs [container] --tail 50

# Ollama Management
ollama list
ollama pull [model]
ollama rm [model]
ollama serve
ollama run llama3.2:3b "test"

# Network Debugging
netstat -an | findstr :[PORT]
curl http://localhost:[PORT]
Test-NetConnection localhost -Port [PORT]

# Cleanup
docker system prune -a
ollama rm llama3.2:3b
Remove-Item "c:\dev\workshop\chromadb\data\*" -Recurse
```

---

## 🎯 Ready for the Workshop?

### Pre-Workshop Checklist
- [ ] Cloned the repository
- [ ] Ran `.\scripts\install-prerequisites.ps1`
- [ ] Ran `.\scripts\setup-containers.ps1`
- [ ] Verified all services are running
- [ ] Opened N8N at http://localhost:5678
- [ ] Have Google account ready for OAuth

---

**See you at Oz' AI Workshop on 9 September 2025!** 🚀

For questions before the workshop, create an issue in the GitLab repository.