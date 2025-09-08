# Docker Container Management Script for Oz' AI Workshop
# N8N RAG Demo - Container Management Utility
# Usage: .\manage-containers.ps1 -Action [start|stop|restart|status|logs] -Container [all|chromadb|n8n]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "reset", "backup")]
    [string]$Action,
    
    [ValidateSet("all", "chromadb", "n8n")]
    [string]$Container = "all",
    
    [string]$WorkshopPath = "C:\Dev\Workshop",
    
    [int]$LogLines = 50
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success { 
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $args[0] -ForegroundColor Green 
}

function Write-Info { 
    Write-Host "ℹ " -ForegroundColor Cyan -NoNewline
    Write-Host $args[0] -ForegroundColor Cyan 
}

function Write-Alert { 
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $args[0] -ForegroundColor Yellow 
}

function Write-Error { 
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $args[0] -ForegroundColor Red 
}

# ASCII Banner
function Show-Banner {
    Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║           Oz' AI Workshop - Container Manager                ║
║                  N8N RAG Demo - Sept 2025                    ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
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

# Start containers
function Start-Containers {
    param([string[]]$Containers)
    
    foreach ($c in $Containers) {
        Write-Info "Starting $c..."
        
        $status = Get-ContainerStatus -ContainerName $c
        
        if ($status -eq "running") {
            Write-Alert "$c is already running"
        } elseif ($status -eq "not found") {
            Write-Alert "$c container not found. Run setup-containers.ps1 first."
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
                    } elseif ($c -eq "chromadb") {
                        Write-Info "  ChromaDB API at: http://localhost:8000"
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

# Show container status
function Show-Status {
    param([string[]]$Containers)
    
    Write-Info "Container Status Report"
    Write-Host ""
    
    # Header
    $format = "{0,-15} {1,-12} {2,-30} {3,-15}"
    Write-Host ($format -f "CONTAINER", "STATUS", "PORTS", "HEALTH") -ForegroundColor White
    Write-Host ("=" * 72) -ForegroundColor DarkGray
    
    foreach ($c in $Containers) {
        try {
            $status = docker inspect $c --format "{{.State.Status}}" 2>$null
            $ports = docker inspect $c --format "{{range \$p, \$conf := .NetworkSettings.Ports}}{{\$p}} -> {{\$conf}} {{end}}" 2>$null
            $health = docker inspect $c --format "{{.State.Health.Status}}" 2>$null
            
            if ([string]::IsNullOrEmpty($health) -or $health -eq "<no value>") {
                $health = "N/A"
            }
            
            # Clean up ports display
            if ($c -eq "chromadb") {
                $ports = "8000:8000"
            } elseif ($c -eq "n8n") {
                $ports = "5678:5678"
            }
            
            # Color code status
            $statusColor = switch ($status) {
                "running" { "Green" }
                "exited" { "Red" }
                "stopped" { "Red" }
                default { "Yellow" }
            }
            
            Write-Host ($format -f $c, $status, $ports, $health) -ForegroundColor $statusColor
            
        } catch {
            Write-Host ($format -f $c, "not found", "-", "-") -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
    
    # Check services
    Write-Info "Service Endpoints:"
    
    # Check Ollama
    try {
        $ollamaResponse = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -ErrorAction SilentlyContinue
        Write-Debug $ollamaResponse | Out-Null
        Write-Success "Ollama API: http://localhost:11434 (Running)"
    } catch {
        Write-Alert "Ollama API: http://localhost:11434 (Not responding)"
    }
    
    # Check ChromaDB
    if ((Get-ContainerStatus -ContainerName "chromadb") -eq "running") {
        try {
            $chromaResponse = Invoke-RestMethod -Uri "http://localhost:8000/api/v1/heartbeat" -Method Get -ErrorAction SilentlyContinue
            Write-Debug $chromaResponse | Out-Null
            Write-Success "ChromaDB API: http://localhost:8000 (Healthy)"
        } catch {
            Write-Alert "ChromaDB API: http://localhost:8000 (Container running but API not responding)"
        }
    }
    
    # Check N8N
    if ((Get-ContainerStatus -ContainerName "n8n") -eq "running") {
        Write-Success "N8N Interface: http://localhost:5678 (Running)"
    }
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
                    } elseif ($_ -match "success|started|ready") {
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

# Reset containers (remove and recreate)
function Reset-Containers {
    param([string[]]$Containers)
    
    Write-Alert "This will remove and recreate containers. Data in mounted volumes will be preserved."
    $confirm = Read-Host "Are you sure you want to reset containers? (y/n)"
    
    if ($confirm -ne 'y') {
        Write-Info "Reset cancelled"
        return
    }
    
    foreach ($c in $Containers) {
        Write-Info "Resetting $c..."
        
        # Stop container
        $status = Get-ContainerStatus -ContainerName $c
        if ($status -ne "not found") {
            Write-Info "  Stopping $c..."
            docker stop $c 2>$null | Out-Null
            
            Write-Info "  Removing $c..."
            docker rm $c 2>$null | Out-Null
        }
        
        # Recreate container
        Write-Info "  Recreating $c..."
        
        try {
            if ($c -eq "chromadb") {
                $chromaCommand = @"
docker run -d ``
  --name chromadb ``
  -p 8000:8000 ``
  -v "$WorkshopPath\chromadb\data:/chroma/chroma" ``
  -e IS_PERSISTENT=TRUE ``
  -e ANONYMIZED_TELEMETRY=FALSE ``
  --restart unless-stopped ``
  chromadb/chroma:latest
"@
                Invoke-Expression $chromaCommand | Out-Null
                Write-Success "  ChromaDB container recreated"
                
            } elseif ($c -eq "n8n") {
                $n8nCommand = @"
docker run -d ``
  --name n8n ``
  -p 5678:5678 ``
  -v "$WorkshopPath\n8n\data:/home/node/.n8n" ``
  -v "$WorkshopPath\n8n\files:/files" ``
  -e N8N_SECURE_COOKIE=false ``
  -e N8N_HOST=localhost ``
  -e N8N_PORT=5678 ``
  -e N8N_PROTOCOL=http ``
  -e WEBHOOK_URL=http://localhost:5678/ ``
  --restart unless-stopped ``
  n8nio/n8n:latest
"@
                Invoke-Expression $n8nCommand | Out-Null
                Write-Success "  N8N container recreated"
            }
            
        } catch {
            Write-Error "Failed to recreate $c : $_"
        }
    }
    
    Write-Success "Container reset complete"
}

# Backup workshop data
function Backup-WorkshopData {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$WorkshopPath\backups\backup_$timestamp"
    
    Write-Info "Creating backup at: $backupPath"
    
    # Create backup directory
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
        }
        $backupInfo | ConvertTo-Json | Out-File -FilePath "$backupPath\backup_info.json"
        
        # Compress backup
        Write-Info "Compressing backup..."
        $zipPath = "$WorkshopPath\backups\workshop_backup_$timestamp.zip"
        Compress-Archive -Path $backupPath -DestinationPath $zipPath
        
        # Clean up uncompressed backup
        Remove-Item -Path $backupPath -Recurse -Force
        
        Write-Success "Backup created: $zipPath"
        
        # Restart containers
        Write-Info "Restarting containers..."
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
        Write-Info "Starting containers..."
        Start-Containers -Containers $containers
    }
    
    "stop" {
        Write-Info "Stopping containers..."
        Stop-Containers -Containers $containers
    }
    
    "restart" {
        Write-Info "Restarting containers..."
        Restart-Containers -Containers $containers
    }
    
    "status" {
        Show-Status -Containers $containers
    }
    
    "logs" {
        Show-Logs -Containers $containers -Lines $LogLines
    }
    
    "reset" {
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