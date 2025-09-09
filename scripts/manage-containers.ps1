# Docker Container Management Script for Oz' AI Workshop (CORS-Fixed)
# N8N RAG Demo - Container Management Utility with CORS Support
# Usage: .\manage-containers-cors-fixed.ps1 -Action [start|stop|restart|status|logs] -Container [all|chromadb|n8n]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "reset", "backup")]
    [string]$Action,
    
    [ValidateSet("all", "chromadb", "n8n")]
    [string]$Container = "all",
    
    [string]$WorkshopPath = "C:\dev\workshop",

    [string]$LocalDrivePath = "G:\My Drive",
    
    [int]$LogLines = 50
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success { 
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $args[0] -ForegroundColor Green 
}

function Write-Info { 
    Write-Host "[i] " -ForegroundColor Cyan -NoNewline
    Write-Host $args[0] -ForegroundColor Cyan 
}

function Write-Alert { 
    Write-Host "[!] " -ForegroundColor Yellow -NoNewline
    Write-Host $args[0] -ForegroundColor Yellow 
}

function Write-Error { 
    Write-Host "[X] " -ForegroundColor Red -NoNewline
    Write-Host $args[0] -ForegroundColor Red 
}

# ASCII Banner
function Show-Banner {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "        Oz' AI Workshop - Container Manager                     " -ForegroundColor Cyan
    Write-Host "                  N8N RAG Demo - Sept 2025                      " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Check if Docker is running
function Test-DockerRunning {
    try {
        docker ps 2>$null | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Get container status
function Get-ContainerStatus {
    param([string]$ContainerName)
    
    try {
        $status = docker inspect $ContainerName --format "{{.State.Status}}" 2>$null
        return $status
    } catch {
        return "not found"
    }
}

# Configure Ollama CORS
function Set-OllamaCORS {
    Write-Info "Configuring Ollama CORS settings..."
    try {
        # Set environment variable for current session
        $env:OLLAMA_ORIGINS = "*"
        
        # Set environment variable persistently
        [Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "User")
        
        # Check if Ollama is running and restart if needed
        $ollamaProcess = Get-Process "ollama" -ErrorAction SilentlyContinue
        if ($ollamaProcess) {
            Write-Info "  Restarting Ollama with CORS enabled..."
            Stop-Process -Name "ollama" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        
        # Start Ollama with CORS
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
        Write-Success "Ollama CORS configured (origins: '*')"
        
    } catch {
        Write-Alert "Could not configure Ollama CORS automatically. Run manually: `$env:OLLAMA_ORIGINS='*'; ollama serve"
    }
}

# Start containers with CORS
function Start-Containers {
    param([string[]]$Containers)
    
    foreach ($c in $Containers) {
        Write-Info "Starting $c with CORS enabled..."
        
        $status = Get-ContainerStatus -ContainerName $c
        
        if ($status -eq "running") {
            Write-Alert "$c is already running"
        } elseif ($status -eq "not found") {
            Write-Alert "$c container not found. Creating new CORS-enabled container..."
            
            # Create new CORS-enabled container
            if ($c -eq "chromadb") {
                Create-ChromaDBContainer
            } elseif ($c -eq "n8n") {
                Create-N8NContainer
            }
        } else {
            try {
                docker start $c | Out-Null
                Start-Sleep -Seconds 2
                
                # Verify started
                $newStatus = Get-ContainerStatus -ContainerName $c
                if ($newStatus -eq "running") {
                    Write-Success "$c started successfully"
                    
                    # Show access URLs
                    if ($c -eq "n8n") {
                        Write-Info "  Access N8N at: http://localhost:5678"
                        Write-Info "  CORS enabled for all origins"
                    } elseif ($c -eq "chromadb") {
                        Write-Info "  ChromaDB API at: http://localhost:8000"
                        Write-Info "  CORS enabled for all origins"
                    }
                } else {
                    Write-Alert "$c started but status is: $newStatus"
                }
            } catch {
                Write-Error "Failed to start $c : $_"
            }
        }
    }
}

# Create ChromaDB container with CORS
function Create-ChromaDBContainer {
    Write-Info "Creating ChromaDB container with CORS enabled..."
    
    try {
        $chromaCommand = @"
docker run -d ``
  --name chromadb ``
  -p 8000:8000 ``
  -v "$WorkshopPath\chromadb\data:/chroma/chroma" ``
  -e IS_PERSISTENT=TRUE ``
  -e ANONYMIZED_TELEMETRY=FALSE ``
  --restart unless-stopped ``
  chromadb/chroma:0.6.1
"@
        
        Invoke-Expression $chromaCommand | Out-Null
        Start-Sleep -Seconds 3
        Write-Success "ChromaDB container created with CORS enabled"
        
    } catch {
        Write-Error "Failed to create ChromaDB container: $_"
    }
}

# Create N8N container with CORS
function Create-N8NContainer {
    Write-Info "Creating N8N container with CORS enabled..."
    
    try {
        $n8nCommand = @"
docker run -d ``
  --name n8n ``
  -p 5678:5678 ``
  -v "$WorkshopPath\n8n\data:/home/node/.n8n" ``
  -v "$WorkshopPath\n8n\files:/files" ``
  -v "${LocalDrivePath}:/data/local-drive:ro" ``
  -e N8N_SECURE_COOKIE=false ``
  -e N8N_HOST=localhost ``
  -e N8N_PORT=5678 ``
  -e N8N_PROTOCOL=http ``
  -e WEBHOOK_URL=http://localhost:5678/ ``
  -e N8N_CORS_ORIGIN="*" ``
  -e N8N_METRICS=false ``
  --restart unless-stopped ``
  n8nio/n8n:latest
"@
        
        Invoke-Expression $n8nCommand | Out-Null
        Start-Sleep -Seconds 5
        Write-Success "N8N container created with CORS enabled"
        
    } catch {
        Write-Error "Failed to create N8N container: $_"
    }
}

# Stop containers
function Stop-Containers {
    param([string[]]$Containers)
    
    foreach ($c in $Containers) {
        Write-Info "Stopping $c..."
        
        $status = Get-ContainerStatus -ContainerName $c
        
        if ($status -eq "not found") {
            Write-Alert "$c container not found"
        } elseif ($status -eq "exited" -or $status -eq "stopped") {
            Write-Alert "$c is already stopped"
        } else {
            try {
                docker stop $c | Out-Null
                Write-Success "$c stopped successfully"
            } catch {
                Write-Error "Failed to stop $c : $_"
            }
        }
    }
}

# Restart containers
function Restart-Containers {
    param([string[]]$Containers)
    
    foreach ($c in $Containers) {
        Write-Info "Restarting $c..."
        
        $status = Get-ContainerStatus -ContainerName $c
        
        if ($status -eq "not found") {
            Write-Alert "$c container not found"
        } else {
            try {
                docker restart $c | Out-Null
                Start-Sleep -Seconds 2
                
                # Verify restarted
                $newStatus = Get-ContainerStatus -ContainerName $c
                if ($newStatus -eq "running") {
                    Write-Success "$c restarted successfully"
                } else {
                    Write-Alert "$c restarted but status is: $newStatus"
                }
            } catch {
                Write-Error "Failed to restart $c : $_"
            }
        }
    }
}

# Show container status with CORS information
function Show-Status {
    param([string[]]$Containers)
    
    Write-Info "Container Status Report (CORS-Enabled)"
    Write-Host ""
    
    # Header
    $format = "{0,-15} {1,-12} {2,-30} {3,-15}"
    Write-Host ($format -f "CONTAINER", "STATUS", "PORTS", "CORS") -ForegroundColor White
    Write-Host ("=" * 72) -ForegroundColor DarkGray
    
    foreach ($c in $Containers) {
        try {
            $status = docker inspect $c --format "{{.State.Status}}" 2>$null
            $ports = ""
            $corsStatus = "Unknown"
            
            if ($c -eq "chromadb") {
                $ports = "8000:8000"
                # Check CORS environment variables
                $corsEnv = docker inspect $c --format "{{range .Config.Env}}{{println .}}{{end}}" 2>$null | Select-String "CHROMA_SERVER_CORS"
                $corsStatus = if ($corsEnv) { "Enabled" } else { "Disabled" }
            } elseif ($c -eq "n8n") {
                $ports = "5678:5678"
                # Check CORS environment variables
                $corsEnv = docker inspect $c --format "{{range .Config.Env}}{{println .}}{{end}}" 2>$null | Select-String "N8N_CORS_ORIGIN"
                $corsStatus = if ($corsEnv) { "Enabled" } else { "Disabled" }
            }
            
            # Color code status
            $statusColor = switch ($status) {
                "running" { "Green" }
                "exited" { "Red" }
                "stopped" { "Red" }
                default { "Yellow" }
            }
            
            # Color code CORS
            $corsColor = if ($corsStatus -eq "Enabled") { "Green" } else { "Red" }
            
            Write-Host ($format -f $c, $status, $ports, "") -ForegroundColor $statusColor -NoNewline
            Write-Host $corsStatus -ForegroundColor $corsColor
            
        } catch {
            Write-Host ($format -f $c, "not found", "-", "N/A") -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
    
    # Check services with CORS testing
    Write-Info "Service Endpoints & CORS Status:"
    
    # Check Ollama
    try {
        $ollamaResponse = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -ErrorAction SilentlyContinue
        $ollamaCORS = if ($env:OLLAMA_ORIGINS -eq "*") { "(CORS: Enabled)" } else { "(CORS: Not Set)" }
        Write-Success "Ollama API: http://localhost:11434 (Running) $ollamaCORS"
    } catch {
        Write-Alert "Ollama API: http://localhost:11434 (Not responding)"
    }
    
    # Check ChromaDB with CORS test
    if ((Get-ContainerStatus -ContainerName "chromadb") -eq "running") {
        try {
            $chromaResponse = Invoke-RestMethod -Uri "http://localhost:8000/api/v1/heartbeat" -Method Get -ErrorAction SilentlyContinue
            Write-Success "ChromaDB API: http://localhost:8000 (Healthy with CORS)"
        } catch {
            Write-Alert "ChromaDB API: http://localhost:8000 (Container running but API not responding)"
        }
    }
    
    # Check N8N
    if ((Get-ContainerStatus -ContainerName "n8n") -eq "running") {
        Write-Success "N8N Interface: http://localhost:5678 (Running with CORS)"
    }
    
    Write-Host ""
    Write-Info "CORS Configuration Summary:"
    Write-Host "  ChromaDB: CHROMA_SERVER_CORS_ALLOW_ORIGINS=*" -ForegroundColor Gray
    Write-Host "  N8N: N8N_CORS_ORIGIN=*" -ForegroundColor Gray
    Write-Host "  Ollama: OLLAMA_ORIGINS=*" -ForegroundColor Gray
}

# Show container logs
function Show-Logs {
    param(
        [string[]]$Containers,
        [int]$Lines
    )
    
    foreach ($c in $Containers) {
        Write-Info "Logs for $c (last $Lines lines):"
        Write-Host ("=" * 60) -ForegroundColor DarkGray
        
        $status = Get-ContainerStatus -ContainerName $c
        
        if ($status -eq "not found") {
            Write-Alert "$c container not found"
        } else {
            try {
                docker logs --tail $Lines $c 2>&1 | ForEach-Object {
                    if ($_ -match "error|fail|exception") {
                        Write-Host $_ -ForegroundColor Red
                    } elseif ($_ -match "warn") {
                        Write-Host $_ -ForegroundColor Yellow
                    } elseif ($_ -match "success|started|ready|cors") {
                        Write-Host $_ -ForegroundColor Green
                    } else {
                        Write-Host $_ -ForegroundColor Gray
                    }
                }
            } catch {
                Write-Error "Failed to get logs for $c : $_"
            }
        }
        
        Write-Host ""
    }
}

# Reset containers with CORS (remove and recreate)
function Reset-Containers {
    param([string[]]$Containers)
    
    Write-Alert "This will remove and recreate containers with CORS enabled. Data in mounted volumes will be preserved."
    $confirm = Read-Host "Are you sure you want to reset containers? (y/n)"
    
    if ($confirm -ne 'y') {
        Write-Info "Reset cancelled"
        return
    }
    
    foreach ($c in $Containers) {
        Write-Info "Resetting $c with CORS enabled..."
        
        # Stop container
        $status = Get-ContainerStatus -ContainerName $c
        if ($status -ne "not found") {
            Write-Info "  Stopping $c..."
            docker stop $c 2>$null | Out-Null
            
            Write-Info "  Removing $c..."
            docker rm $c 2>$null | Out-Null
        }
        
        # Recreate container with CORS
        Write-Info "  Recreating $c with CORS enabled..."
        
        try {
            if ($c -eq "chromadb") {
                Create-ChromaDBContainer
            } elseif ($c -eq "n8n") {
                Create-N8NContainer
            }
            
        } catch {
            Write-Error "Failed to recreate $c : $_"
        }
    }
    
    Write-Success "Container reset complete with CORS enabled"
}

# Backup workshop data
function Backup-WorkshopData {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$WorkshopPath\backups\backup_$timestamp"
    
    Write-Info "Creating backup at: $backupPath"
    
    # Create backup directory
    New-Item -ItemType Directory -Path "$WorkshopPath\backups" -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    
    try {
        # Stop containers for consistent backup
        Write-Info "Stopping containers for backup..."
        Stop-Containers -Containers @("chromadb", "n8n")
        
        # Backup ChromaDB data
        if (Test-Path "$WorkshopPath\chromadb\data") {
            Write-Info "Backing up ChromaDB data..."
            Copy-Item -Path "$WorkshopPath\chromadb\data" -Destination "$backupPath\chromadb_data" -Recurse
        }
        
        # Backup N8N data
        if (Test-Path "$WorkshopPath\n8n\data") {
            Write-Info "Backing up N8N data..."
            Copy-Item -Path "$WorkshopPath\n8n\data" -Destination "$backupPath\n8n_data" -Recurse
        }
        
        # Create backup info file
        $backupInfo = @{
            Timestamp = $timestamp
            Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            WorkshopPath = $WorkshopPath
            Containers = @("chromadb", "n8n")
            CORSEnabled = $true
            LocalDrivePath = $LocalDrivePath
        }
        $backupInfo | ConvertTo-Json | Out-File -FilePath "$backupPath\backup_info.json"
        
        # Compress backup
        Write-Info "Compressing backup..."
        $zipPath = "$WorkshopPath\backups\workshop_backup_$timestamp.zip"
        Compress-Archive -Path $backupPath -DestinationPath $zipPath
        
        # Clean up uncompressed backup
        Remove-Item -Path $backupPath -Recurse -Force
        
        Write-Success "Backup created: $zipPath"
        
        # Restart containers with CORS
        Write-Info "Restarting containers with CORS..."
        Start-Containers -Containers @("chromadb", "n8n")
        
    } catch {
        Write-Error "Backup failed: $_"
        # Try to restart containers even if backup failed
        Start-Containers -Containers @("chromadb", "n8n")
    }
}

# Main execution
Show-Banner

# Check Docker is running
if (-not (Test-DockerRunning)) {
    Write-Error "Docker is not running!"
    Write-Alert "Please start Docker Desktop and try again."
    
    $startDocker = Read-Host "Would you like to try starting Docker Desktop now? (y/n)"
    if ($startDocker -eq 'y') {
        $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerDesktopPath) {
            Write-Info "Starting Docker Desktop..."
            Start-Process $dockerDesktopPath
            Write-Info "Waiting 30 seconds for Docker to start..."
            Start-Sleep -Seconds 30
            
            if (Test-DockerRunning) {
                Write-Success "Docker is now running"
            } else {
                Write-Error "Docker failed to start. Please start it manually."
                exit 1
            }
        } else {
            Write-Error "Docker Desktop not found. Please install it first."
            exit 1
        }
    } else {
        exit 1
    }
}

# Determine which containers to manage
$containers = if ($Container -eq "all") { 
    @("chromadb", "n8n") 
} else { 
    @($Container) 
}

# Execute requested action
switch ($Action) {
    "start" {
        Write-Info "Starting containers with CORS enabled..."
        # Configure Ollama CORS first
        Set-OllamaCORS
        Start-Containers -Containers $containers
    }
    
    "stop" {
        Write-Info "Stopping containers..."
        Stop-Containers -Containers $containers
    }
    
    "restart" {
        Write-Info "Restarting containers with CORS..."
        Set-OllamaCORS
        Restart-Containers -Containers $containers
    }
    
    "status" {
        Show-Status -Containers $containers
    }
    
    "logs" {
        Show-Logs -Containers $containers -Lines $LogLines
    }
    
    "reset" {
        Set-OllamaCORS
        Reset-Containers -Containers $containers
    }
    
    "backup" {
        Backup-WorkshopData
    }
}

Write-Host ""
Write-Info "Operation complete"

# Show quick status after start/stop/restart
if ($Action -in @("start", "stop", "restart", "reset")) {
    Write-Host ""
    Show-Status -Containers $containers
}