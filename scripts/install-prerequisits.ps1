# N8N RAG Workshop - Prerequisites Installation Script for Windows
# Run as Administrator

param(
    [string]$InstallPath = "C:\dev\workshop",
    [switch]$SkipOllama = $false,
    [switch]$SkipDocker = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success { Write-Host $args[0] -ForegroundColor Green }
function Write-Info { Write-Host $args[0] -ForegroundColor Cyan }
function Write-Alert { Write-Host $args[0] -ForegroundColor Yellow }
function Write-Error { Write-Host $args[0] -ForegroundColor Red }

# ASCII Banner
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "           N8N RAG Workshop - Prerequisites Installer          " -ForegroundColor Cyan
Write-Host "                    Windows Environment Setup                  " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator!"
    Write-Alert "Right-click on PowerShell and select 'Run as Administrator'"
    exit 1
}

# Create workshop directory
Write-Info "`n[1/6] Creating workshop directory..."
if (!(Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Success "[OK] Created directory: $InstallPath"
} else {
    Write-Alert "[->] Directory already exists: $InstallPath"
}

# Create subdirectories
$directories = @(
    "$InstallPath\downloads",
    "$InstallPath\models",
    "$InstallPath\data",
    "$InstallPath\scripts"
)

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Success "  [OK] Created: $dir"
    }
}

# Check Docker Desktop installation
Write-Info "`n[2/6] Checking Docker Desktop..."
$dockerInstalled = $false
try {
    $dockerVersion = docker --version 2>$null
    if ($dockerVersion) {
        Write-Success "[OK] Docker is installed: $dockerVersion"
        $dockerInstalled = $true
        
        # Check if Docker is running
        try {
            docker ps 2>$null | Out-Null
            Write-Success "[OK] Docker daemon is running"
        } catch {
            Write-Alert "[->] Docker Desktop is installed but not running"
            Write-Info "  Starting Docker Desktop..."
            
            # Try to find and start Docker Desktop
            $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $dockerDesktopPath) {
                Start-Process $dockerDesktopPath -ErrorAction SilentlyContinue
                Write-Alert "  Please wait for Docker Desktop to fully start (may take 30-60 seconds)"
                
                # Wait for Docker to start
                $attempts = 0
                $maxAttempts = 30
                while ($attempts -lt $maxAttempts) {
                    Start-Sleep -Seconds 2
                    try {
                        docker ps 2>$null | Out-Null
                        Write-Success "  [OK] Docker daemon is now running"
                        break
                    } catch {
                        $attempts++
                        if ($attempts % 5 -eq 0) {
                            Write-Info "  Still waiting for Docker to start... ($attempts/$maxAttempts)"
                        }
                    }
                }
                
                if ($attempts -eq $maxAttempts) {
                    Write-Error "Docker Desktop failed to start. Please start it manually and run this script again."
                    exit 1
                }
            }
        }
    }
} catch {
    if (-not $SkipDocker) {
        Write-Alert "[X] Docker Desktop is not installed"
        Write-Info "  Docker Desktop is required for ChromaDB and N8N"
        Write-Alert "  Please install Docker Desktop manually:"
        Write-Alert "  1. Download from: https://www.docker.com/products/docker-desktop/"
        Write-Alert "  2. Install Docker Desktop"
        Write-Alert "  3. Start Docker Desktop"
        Write-Alert "  4. Run this script again"
        Write-Alert ""
        Write-Alert "  Press any key to open the download page..."
        Read-Host
        Start-Process "https://www.docker.com/products/docker-desktop/"
        exit 1
    } else {
        Write-Alert "[->] Skipping Docker check (SkipDocker flag set)"
    }
}

# Install Ollama
if (-not $SkipOllama) {
    Write-Info "`n[3/6] Checking Ollama installation..."
    
    # Check if Ollama is already installed
    $ollamaInstalled = $false
    try {
        $ollamaVersion = ollama --version 2>$null
        if ($ollamaVersion) {
            Write-Success "[OK] Ollama is already installed: $ollamaVersion"
            $ollamaInstalled = $true
        }
    } catch {
        Write-Alert "[->] Ollama not found, installing..."
    }
    
    if (-not $ollamaInstalled) {
        # Download Ollama installer
        $ollamaUrl = "https://ollama.com/download/OllamaSetup.exe"
        $ollamaInstaller = "$InstallPath\downloads\OllamaSetup.exe"
        
        Write-Info "  Downloading Ollama installer..."
        try {
            # Use Invoke-WebRequest with progress bar
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $ollamaUrl -OutFile $ollamaInstaller -UseBasicParsing
            $ProgressPreference = 'Continue'
            Write-Success "  [OK] Downloaded Ollama installer"
            
            # Install Ollama silently
            Write-Info "  Installing Ollama (this may take a few minutes)..."
            $installArgs = "/S"  # Silent install
            $process = Start-Process -FilePath $ollamaInstaller -ArgumentList $installArgs -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Success "  [OK] Ollama installed successfully"
                
                # Add Ollama to PATH if needed
                $ollamaPath = "$env:LOCALAPPDATA\Programs\Ollama"
                if (Test-Path $ollamaPath) {
                    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
                    if ($currentPath -notlike "*$ollamaPath*") {
                        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$ollamaPath", "User")
                        $env:Path = "$env:Path;$ollamaPath"
                        Write-Success "  [OK] Added Ollama to PATH"
                    }
                }
                
                # Refresh environment variables
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                
            } else {
                Write-Error "Ollama installation failed with exit code: $($process.ExitCode)"
                exit 1
            }
        } catch {
            Write-Error "Failed to download or install Ollama: $_"
            exit 1
        }
    }
    
    # Start Ollama service
    Write-Info "`n[4/6] Starting Ollama service..."
    try {
        # Check if Ollama is running
        $ollamaRunning = Get-Process "ollama" -ErrorAction SilentlyContinue
        if (-not $ollamaRunning) {
            Write-Info "  Starting Ollama serve..."
            Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
            Start-Sleep -Seconds 3
            Write-Success "  [OK] Ollama service started"
        } else {
            Write-Success "  [OK] Ollama service is already running"
        }
    } catch {
        Write-Alert "  Could not start Ollama service automatically"
        Write-Info "  You may need to run 'ollama serve' manually"
    }
    
    # Pull required models
    Write-Info "`n[5/6] Pulling required Ollama models..."
    
    $models = @(
        @{Name="llama3.2:3b"; Description="Llama 3.2 3B model for text generation"},
        @{Name="nomic-embed-text"; Description="Nomic embedding model for RAG"}
    )
    
    foreach ($model in $models) {
        Write-Info "  Pulling $($model.Name) - $($model.Description)"
        Write-Alert "  This may take several minutes depending on your internet connection..."
        
        try {
            $pullProcess = Start-Process "ollama" -ArgumentList "pull $($model.Name)" -Wait -PassThru -NoNewWindow
            if ($pullProcess.ExitCode -eq 0) {
                Write-Success "  [OK] Successfully pulled $($model.Name)"
            } else {
                Write-Alert "  [X] Failed to pull $($model.Name), will retry..."
                # Retry once
                Start-Sleep -Seconds 2
                $retryProcess = Start-Process "ollama" -ArgumentList "pull $($model.Name)" -Wait -PassThru -NoNewWindow
                if ($retryProcess.ExitCode -eq 0) {
                    Write-Success "  [OK] Successfully pulled $($model.Name) on retry"
                } else {
                    Write-Error "  Failed to pull $($model.Name). Please run 'ollama pull $($model.Name)' manually"
                }
            }
        } catch {
            Write-Error "Error pulling model $($model.Name): $_"
        }
    }
    
    # Verify models
    Write-Info "  Verifying installed models..."
    try {
        $installedModels = ollama list 2>$null
        Write-Success "  [OK] Models available:"
        Write-Host $installedModels -ForegroundColor Gray
    } catch {
        Write-Alert "  Could not verify models"
    }
    
} else {
    Write-Alert "`n[->] Skipping Ollama installation (SkipOllama flag set)"
}

# Final verification
Write-Info "`n[6/6] Verifying installation..."

$verificationResults = @()

# Check Ollama
try {
    $ollamaTest = ollama --version 2>$null
    if ($ollamaTest) {
        $verificationResults += "[OK] Ollama: Installed"
        
        # Test Ollama API
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -ErrorAction SilentlyContinue
            $verificationResults += "[OK] Ollama API: Accessible"
        } catch {
            $verificationResults += "[X] Ollama API: Not accessible (start with 'ollama serve')"
        }
    }
} catch {
    $verificationResults += "[X] Ollama: Not found"
}

# Check Docker
try {
    $dockerTest = docker --version 2>$null
    if ($dockerTest) {
        $verificationResults += "[OK] Docker: Installed"
        
        # Check if Docker daemon is running
        try {
            docker ps 2>$null | Out-Null
            $verificationResults += "[OK] Docker Daemon: Running"
        } catch {
            $verificationResults += "[X] Docker Daemon: Not running"
        }
    }
} catch {
    $verificationResults += "[X] Docker: Not found"
}

# Display results
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "                    Installation Summary                       " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

foreach ($result in $verificationResults) {
    if ($result -like "*[OK]*") {
        Write-Success $result
    } else {
        Write-Alert $result
    }
}

# Save configuration
$config = @{
    InstallPath = $InstallPath
    InstallDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    OllamaInstalled = $ollamaInstalled
    DockerInstalled = $dockerInstalled
}

$configPath = "$InstallPath\workshop-config.json"
$config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8
Write-Success "`n[OK] Configuration saved to: $configPath"

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "            Prerequisites Installation Complete!               " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

Write-Info "`nNext steps:"
Write-Info "1. Run the container setup script: .\scripts\setup-containers.ps1"
Write-Info "2. Import the N8N workflows"
Write-Info "3. Start indexing your local documents"
Write-Info ""
Write-Info "Workshop directory: $InstallPath"
Write-Info ""

Write-Success "[OK] Prerequisites installation completed successfully!"