# RAG Workshop Environment Setup Script for Windows
# Requires Docker Desktop with WSL2 backend

param(
    [switch]$SkipModelPull,
    [switch]$NoGPU
)

Write-Host "Setting up RAG Workshop Environment..." -ForegroundColor Green

# Check if Docker is running
Write-Host "Checking Docker installation..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "Docker found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Docker not found or not running. Please install Docker Desktop and ensure it's running." -ForegroundColor Red
    Write-Host "Download from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

# Check if Docker Compose is available
try {
    $composeVersion = docker-compose --version
    Write-Host "Docker Compose found: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Docker Compose not found. Please ensure Docker Desktop is properly installed." -ForegroundColor Red
    exit 1
}

# Create necessary directories
Write-Host "Creating directories..." -ForegroundColor Yellow
$directories = @("files", "data\qdrant", "data\n8n", "data\ollama")

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created directory: $dir" -ForegroundColor Gray
    } else {
        Write-Host "Directory already exists: $dir" -ForegroundColor Gray
    }
}

# Modify docker-compose.yml if NoGPU flag is set
if ($NoGPU) {
    Write-Host "Removing GPU configuration for CPU-only setup..." -ForegroundColor Yellow
    
    $composeContent = Get-Content "docker-compose.yml" -Raw
    
    # Remove the deploy section from ollama service
    $modifiedContent = $composeContent -replace '(?s)    deploy:\s*\n      resources:\s*\n        reservations:\s*\n          devices:\s*\n            - driver: nvidia\s*\n              count: all\s*\n              capabilities: \[gpu\]', ''
    
    # Write to a temporary file
    $modifiedContent | Set-Content "docker-compose-cpu.yml"
    $composeFile = "docker-compose-cpu.yml"
    Write-Host "Created CPU-only compose file: $composeFile" -ForegroundColor Green
} else {
    $composeFile = "docker-compose.yml"
}

# Start the services
Write-Host "Starting Docker services..." -ForegroundColor Yellow
try {
    docker-compose -f $composeFile up -d
    if ($LASTEXITCODE -ne 0) {
        throw "Docker compose failed"
    }
    Write-Host "Services started successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to start services. Check Docker Desktop is running and try again." -ForegroundColor Red
    exit 1
}

# Wait for services to be ready
Write-Host "Waiting for services to start (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check service health
Write-Host "Checking service health..." -ForegroundColor Yellow
$services = @(
    @{Name="ollama"; Port=11434},
    @{Name="n8n"; Port=5678},
    @{Name="qdrant"; Port=6333}
)

foreach ($service in $services) {
    try {
        $response = Invoke-WebRequest -Uri "http://$($service.Name):$($service.Port)" -TimeoutSec 5 -ErrorAction Stop
        Write-Host "$($service.Name) is responding on port $($service.Port)" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: $($service.Name) not responding on port $($service.Port)" -ForegroundColor Yellow
    }
}

# Pull Ollama model
if (-not $SkipModelPull) {
    Write-Host "Pulling Llama 3.2:3b model (this may take several minutes)..." -ForegroundColor Yellow
    try {
        docker exec ollama ollama pull llama3.2:3b
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Model pulled successfully" -ForegroundColor Green
        } else {
            Write-Host "WARNING: Model pull failed. You can retry manually with:" -ForegroundColor Yellow
            Write-Host "docker exec ollama ollama pull llama3.2:3b" -ForegroundColor Gray
        }
    } catch {
        Write-Host "WARNING: Could not pull model automatically. Try manually later." -ForegroundColor Yellow
    }
} else {
    Write-Host "Skipping model pull (use -SkipModelPull to skip)" -ForegroundColor Gray
}

# Setup Qdrant collection
Write-Host "Setting up Qdrant vector collection..." -ForegroundColor Yellow
$qdrantCollection = @{
    vectors = @{
        size = 4096
        distance = "Cosine"
    }
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "http://localhost:6333/collections/documents" -Method PUT -Body $qdrantCollection -ContentType "application/json"
    Write-Host "Qdrant collection created" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Could not create Qdrant collection. Will retry on first document upload." -ForegroundColor Yellow
}

# Clean up temporary CPU compose file
if ($NoGPU -and (Test-Path "docker-compose-cpu.yml")) {
    Remove-Item "docker-compose-cpu.yml"
}

Write-Host "`nSetup complete!" -ForegroundColor Green
Write-Host "`nAccess your services:" -ForegroundColor White
Write-Host "  - N8N: http://localhost:5678" -ForegroundColor Cyan
Write-Host "  - Open WebUI: http://localhost:3001" -ForegroundColor Cyan
Write-Host "  - Qdrant API: http://localhost:6333" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor White
Write-Host "  1. Import the N8N workflow template" -ForegroundColor Gray
Write-Host "  2. Drop files into the './files' directory" -ForegroundColor Gray
Write-Host "  3. Start chatting with your documents!" -ForegroundColor Gray
Write-Host "`nTo stop the environment: docker-compose down" -ForegroundColor Yellow

# Open services in browser (optional)
$openBrowser = Read-Host "`nWould you like to open the services in your browser? (y/N)"
if ($openBrowser -eq 'y' -or $openBrowser -eq 'Y') {
    Start-Process "http://localhost:5678"  # N8N
}