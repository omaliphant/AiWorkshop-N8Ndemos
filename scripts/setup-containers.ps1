# N8N RAG Workshop - Docker Container Setup Script (Local Drive Version)
# Run after installing prerequisites
# This version works with local/mapped drives instead of Google Drive

param(
    [string]$WorkshopPath = "C:\dev\workshop",
    [string]$ChromaDBPort = "8000",
    [string]$N8NPort = "5678",
    [switch]$RemoveExisting = $false,
    [string]$LocalDrivePath = "G:\"  # Default to G: drive
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
Write-Host "      Oz' AI Workshop - Container Setup (Local Drive)         " -ForegroundColor Cyan
Write-Host "                 ChromaDB & N8N Deployment                    " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Check if local drive path exists
Write-Info "[1/6] Checking local drive access..."
if (Test-Path $LocalDrivePath) {
    $fileCount = (Get-ChildItem -Path $LocalDrivePath -Recurse -File -Include *.pdf,*.docx,*.txt,*.md -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Success "[OK] Access to $LocalDrivePath confirmed"
    Write-Info "  Found $fileCount potential documents to index"
} else {
    Write-Alert "[!] Cannot access $LocalDrivePath"
    Write-Alert "  You can configure this later in the N8N workflow"
    $response = Read-Host "  Continue anyway? (y/n)"
    if ($response -ne 'y') {
        exit 1
    }
}

# Check if Docker is running
Write-Info "`n[2/6] Checking Docker status..."
try {
    docker ps 2>$null | Out-Null
    Write-Success "[OK] Docker is running"
} catch {
    Write-Error "Docker is not running!"
    Write-Alert "Please start Docker Desktop and try again."
    
    # Try to start Docker Desktop
    $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Write-Info "Attempting to start Docker Desktop..."
        Start-Process $dockerDesktopPath
        Write-Alert "Waiting 30 seconds for Docker to start..."
        Start-Sleep -Seconds 30
        
        # Check again
        try {
            docker ps 2>$null | Out-Null
            Write-Success "[OK] Docker is now running"
        } catch {
            Write-Error "Docker failed to start. Please start it manually and run this script again."
            exit 1
        }
    } else {
        exit 1
    }
}

# Create necessary directories
Write-Info "`n[3/6] Creating data directories..."

$directories = @(
    "$WorkshopPath\chromadb\data",
    "$WorkshopPath\n8n\data",
    "$WorkshopPath\n8n\files",
    "$WorkshopPath\test",
    "$WorkshopPath\logs"
)

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Success "  [OK] Created: $dir"
    } else {
        Write-Alert "  [->] Directory exists: $dir"
    }
}

# Handle existing containers
if ($RemoveExisting) {
    Write-Info "`n[4/6] Removing existing containers..."
    
    $containers = @("chromadb", "n8n")
    foreach ($container in $containers) {
        try {
            $exists = docker ps -a --filter "name=$container" --format "{{.Names}}" 2>$null
            if ($exists) {
                Write-Info "  Stopping $container..."
                docker stop $container 2>$null | Out-Null
                docker rm $container 2>$null | Out-Null
                Write-Success "  [OK] Removed container: $container"
            }
        } catch {
            Write-Alert "  [->] Container $container not found"
        }
    }
} else {
    Write-Info "`n[4/6] Checking for existing containers..."
    
    $existingContainers = @()
    $containers = @("chromadb", "n8n")
    
    foreach ($container in $containers) {
        try {
            $exists = docker ps -a --filter "name=$container" --format "{{.Names}}" 2>$null
            if ($exists) {
                $existingContainers += $container
            }
        } catch {}
    }
    
    if ($existingContainers.Count -gt 0) {
        Write-Alert "  Found existing containers: $($existingContainers -join ', ')"
        Write-Alert "  Run with -RemoveExisting flag to remove them first"
        $response = Read-Host "  Do you want to remove existing containers? (y/n)"
        if ($response -eq 'y') {
            foreach ($container in $existingContainers) {
                Write-Info "  Stopping $container..."
                docker stop $container 2>$null | Out-Null
                docker rm $container 2>$null | Out-Null
                Write-Success "  [OK] Removed container: $container"
            }
        } else {
            Write-Alert "  Keeping existing containers"
        }
    }
}

# Setup ChromaDB
Write-Info "`n[5/6] Setting up ChromaDB..."

try {
    # Check if ChromaDB is already running
    $chromaRunning = docker ps --filter "name=chromadb" --format "{{.Names}}" 2>$null
    
    if ($chromaRunning) {
        Write-Alert "  [->] ChromaDB container is already running"
    } else {
        Write-Info "  Pulling ChromaDB image..."
        docker pull chromadb/chroma:latest
        
        Write-Info "  Starting ChromaDB container..."
        $chromaCommand = @"
docker run -d ``
  --name chromadb ``
  -p ${ChromaDBPort}:8000 ``
  -v "${WorkshopPath}\chromadb\data:/chroma/chroma" ``
  -e IS_PERSISTENT=TRUE ``
  -e ANONYMIZED_TELEMETRY=FALSE ``
  --restart unless-stopped ``
  chromadb/chroma:latest
"@
        
        Invoke-Expression $chromaCommand
        
        Write-Info "  Waiting for ChromaDB to start..."
        Start-Sleep -Seconds 5
        
        # Verify ChromaDB is running
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:$ChromaDBPort/api/v1/heartbeat" -Method Get
            Write-Success "  [OK] ChromaDB is running on port $ChromaDBPort"
        } catch {
            Write-Alert "  [->] ChromaDB may still be starting up"
        }
    }
} catch {
    Write-Error "Failed to setup ChromaDB: $_"
    exit 1
}

# Setup N8N
Write-Info "`n[6/6] Setting up N8N..."

try {
    # Check if N8N is already running
    $n8nRunning = docker ps --filter "name=n8n" --format "{{.Names}}" 2>$null
    
    if ($n8nRunning) {
        Write-Alert "  [->] N8N container is already running"
    } else {
        Write-Info "  Pulling N8N image..."
        docker pull n8nio/n8n:latest
        
        Write-Info "  Starting N8N container..."
        # Note: We're mounting the local drive for file access
        $n8nCommand = @"
docker run -d ``
  --name n8n ``
  -p ${N8NPort}:5678 ``
  -v "${WorkshopPath}\n8n\data:/home/node/.n8n" ``
  -v "${WorkshopPath}\n8n\files:/files" ``
  -v "${LocalDrivePath}:/data/local-drive:ro" ``
  -e N8N_SECURE_COOKIE=false ``
  -e N8N_HOST=localhost ``
  -e N8N_PORT=5678 ``
  -e N8N_PROTOCOL=http ``
  -e WEBHOOK_URL=http://localhost:5678/ ``
  -e N8N_METRICS=false ``
  --restart unless-stopped ``
  n8nio/n8n:latest
"@
        
        Invoke-Expression $n8nCommand
        
        Write-Info "  Waiting for N8N to start..."
        Start-Sleep -Seconds 10
        
        # Verify N8N is running
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$N8NPort" -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Success "  [OK] N8N is running on port $N8NPort"
                Write-Info "  [OK] Local drive mounted at /data/local-drive in container"
            }
        } catch {
            Write-Alert "  [->] N8N may still be starting up (this can take up to 30 seconds)"
        }
    }
} catch {
    Write-Error "Failed to setup N8N: $_"
    exit 1
}

# Create test HTML file (copy from repository if exists)
Write-Info "`nCreating test interface..."

$sourceHtml = "$PSScriptRoot\..\test\qa-interface-local.html"
$testHtmlPath = "$WorkshopPath\test\qa-interface-local.html"

if (Test-Path $sourceHtml) {
    Copy-Item -Path $sourceHtml -Destination $testHtmlPath -Force
    Write-Success "[OK] Copied test interface from repository"
} else {
    # Create a basic test interface if template doesn't exist
    $testHtml = @'
<!DOCTYPE html>
<html>
<head>
    <title>Local Drive Q&A Test Interface</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            max-width: 800px; 
            margin: 50px auto; 
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            border-radius: 8px;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 { 
            color: #333; 
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 20px;
        }
        input[type="text"] {
            width: 70%;
            padding: 12px;
            font-size: 16px;
            border: 2px solid #ddd;
            border-radius: 4px;
        }
        input[type="text"]:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            padding: 12px 24px;
            font-size: 16px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            margin-left: 10px;
        }
        button:hover {
            background: #5a67d8;
        }
        #response {
            margin-top: 20px;
            padding: 20px;
            background-color: #f9f9f9;
            border-radius: 4px;
            border: 1px solid #e0e0e0;
            display: none;
        }
        #response.show {
            display: block;
        }
        .source-item {
            background: white;
            padding: 10px;
            margin: 10px 0;
            border-left: 3px solid #667eea;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Local Drive Q&A System</h1>
        <div class="subtitle">Oz AI Workshop - 9 September 2025</div>
        <p>Ask questions about documents in your local/mapped drives</p>
        <div>
            <input type="text" id="question" placeholder="Ask a question about your documents...">
            <button onclick="askQuestion()">Ask</button>
        </div>
        <div id="response"></div>
    </div>

    <script>
        async function askQuestion() {
            const question = document.getElementById('question').value;
            const responseDiv = document.getElementById('response');
            
            if (!question) {
                alert('Please enter a question');
                return;
            }
            
            responseDiv.className = 'show';
            responseDiv.innerHTML = 'Processing your question...';
            
            try {
                const response = await fetch('http://localhost:5678/webhook/local-qa', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ question: question })
                });
                
                const data = await response.json();
                
                let html = '<strong>Question:</strong> ' + data.question + '<br><br>';
                html += '<strong>Answer:</strong> ' + data.answer + '<br><br>';
                
                if (data.sources && data.sources.length > 0) {
                    html += '<strong>Sources:</strong>';
                    data.sources.forEach(source => {
                        html += '<div class="source-item">';
                        html += source.document + ' (Relevance: ' + source.relevance_score + ')';
                        html += '</div>';
                    });
                }
                
                responseDiv.innerHTML = html;
            } catch (error) {
                responseDiv.innerHTML = '<strong>Error:</strong> ' + error.message;
            }
        }
        
        document.getElementById('question').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                askQuestion();
            }
        });
    </script>
</body>
</html>
'@
    $testHtml | Out-File -FilePath $testHtmlPath -Encoding UTF8
    Write-Success "[OK] Created basic test interface"
}

Write-Success "[OK] Test interface available at: $testHtmlPath"

# Create configuration file
Write-Info "Creating configuration file..."

$config = @{
    workshop = "Oz' AI Workshop - 9 Sept 2025"
    setup_date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    workshop_path = $WorkshopPath
    local_drive = $LocalDrivePath
    chromadb_port = $ChromaDBPort
    n8n_port = $N8NPort
    webhook_url = "http://localhost:$N8NPort/webhook/local-qa"
    test_interface = $testHtmlPath
}

$configPath = "$WorkshopPath\workshop-config.json"
$config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
Write-Success "[OK] Configuration saved to: $configPath"

# Verification
Write-Info "`nVerifying container setup..."

$verificationResults = @()

# Check ChromaDB
try {
    $chromaStatus = docker ps --filter "name=chromadb" --format "{{.Status}}" 2>$null
    if ($chromaStatus -like "Up*") {
        $verificationResults += "[OK] ChromaDB: Running"
        
        # Test API
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:$ChromaDBPort/api/v1/heartbeat" -Method Get -ErrorAction SilentlyContinue
            $verificationResults += "[OK] ChromaDB API: Accessible at http://localhost:$ChromaDBPort"
        } catch {
            $verificationResults += "[X] ChromaDB API: Not responding"
        }
    } else {
        $verificationResults += "[X] ChromaDB: Not running"
    }
} catch {
    $verificationResults += "[X] ChromaDB: Container not found"
}

# Check N8N
try {
    $n8nStatus = docker ps --filter "name=n8n" --format "{{.Status}}" 2>$null
    if ($n8nStatus -like "Up*") {
        $verificationResults += "[OK] N8N: Running"
        $verificationResults += "[OK] N8N UI: http://localhost:$N8NPort"
    } else {
        $verificationResults += "[X] N8N: Not running"
    }
} catch {
    $verificationResults += "[X] N8N: Container not found"
}

# Display results
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "                     Container Status                         " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

foreach ($result in $verificationResults) {
    if ($result -like "*[OK]*") {
        Write-Success $result
    } else {
        Write-Alert $result
    }
}

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "              Container Setup Complete!                       " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

Write-Info "`n[*] Your Local Drive RAG Workshop environment is ready!"
Write-Info ""
Write-Info "Access Points:"
Write-Info "   * N8N Interface: http://localhost:$N8NPort"
Write-Info "   * ChromaDB API: http://localhost:$ChromaDBPort"
Write-Info "   * Test Interface: file:///$testHtmlPath"
Write-Info "   * Local Drive Path: $LocalDrivePath"
Write-Info ""
Write-Info "Data Directories:"
Write-Info "   * ChromaDB Data: $WorkshopPath\chromadb\data"
Write-Info "   * N8N Data: $WorkshopPath\n8n\data"
Write-Info "   * N8N Files: $WorkshopPath\n8n\files"
Write-Info ""
Write-Info "Management Commands:"
Write-Info "   * Start containers: .\scripts\manage-containers.ps1 -Action start"
Write-Info "   * Stop containers: .\scripts\manage-containers.ps1 -Action stop"
Write-Info "   * View status: .\scripts\manage-containers.ps1 -Action status"
Write-Info "   * View logs: .\scripts\manage-containers.ps1 -Action logs"
Write-Info ""
Write-Info "Next Steps:"
Write-Info "   1. Open N8N at http://localhost:$N8NPort"
Write-Info "   2. Import workflow templates from \n8n-templates\"
Write-Info "      - initialize-chromadb-local.json (run once)"
Write-Info "      - document-indexer-local.json"
Write-Info "      - qa-system-local.json"
Write-Info "   3. Configure local drive path in indexer workflow"
Write-Info "   4. Run indexing workflow"
Write-Info "   5. Test with the Q&A interface"
Write-Info ""
Write-Info "Workshop Notes:"
Write-Info "   * No Google authentication needed!"
Write-Info "   * Works with any local or mapped drive"
Write-Info "   * Configure path in N8N workflow: '$LocalDrivePath'"
Write-Info "   * All processing stays local"
Write-Info ""

# Open N8N in browser
$openBrowser = Read-Host "Would you like to open N8N in your browser now? (y/n)"
if ($openBrowser -eq 'y') {
    Start-Process "http://localhost:$N8NPort"
}

Write-Success "[OK] Setup completed successfully!"