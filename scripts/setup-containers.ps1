# N8N RAG Workshop - Docker Container Setup Script
# Run after installing prerequisites

param(
    [string]$WorkshopPath = "C:\Dev\Workshop",
    [string]$ChromaDBPort = "8000",
    [string]$N8NPort = "5678",
    [switch]$RemoveExisting = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success { Write-Host $args[0] -ForegroundColor Green }
function Write-Info { Write-Host $args[0] -ForegroundColor Cyan }
function Write-Alert { Write-Host $args[0] -ForegroundColor Yellow }
function Write-Error { Write-Host $args[0] -ForegroundColor Red }

# ASCII Banner
Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║           N8N RAG Workshop - Container Setup                 ║
║                 ChromaDB & N8N Deployment                    ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Check if Docker is running
Write-Info "[1/5] Checking Docker status..."
try {
    docker ps 2>$null | Out-Null
    Write-Success "✓ Docker is running"
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
            Write-Success "✓ Docker is now running"
        } catch {
            Write-Error "Docker failed to start. Please start it manually and run this script again."
            exit 1
        }
    } else {
        exit 1
    }
}

# Create necessary directories
Write-Info "`n[2/5] Creating data directories..."

$directories = @(
    "$WorkshopPath\chromadb\data",
    "$WorkshopPath\n8n\data",
    "$WorkshopPath\n8n\files",
    "$WorkshopPath\test"
)

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Success "  ✓ Created: $dir"
    } else {
        Write-Alert "  → Directory exists: $dir"
    }
}

# Handle existing containers
if ($RemoveExisting) {
    Write-Info "`n[3/5] Removing existing containers..."
    
    $containers = @("chromadb", "n8n")
    foreach ($container in $containers) {
        try {
            $exists = docker ps -a --filter "name=$container" --format "{{.Names}}" 2>$null
            if ($exists) {
                Write-Info "  Stopping $container..."
                docker stop $container 2>$null | Out-Null
                docker rm $container 2>$null | Out-Null
                Write-Success "  ✓ Removed container: $container"
            }
        } catch {
            Write-Alert "  → Container $container not found"
        }
    }
} else {
    Write-Info "`n[3/5] Checking for existing containers..."
    
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
                Write-Success "  ✓ Removed container: $container"
            }
        } else {
            Write-Alert "  Keeping existing containers"
        }
    }
}

# Setup ChromaDB
Write-Info "`n[4/5] Setting up ChromaDB..."

try {
    # Check if ChromaDB is already running
    $chromaRunning = docker ps --filter "name=chromadb" --format "{{.Names}}" 2>$null
    
    if ($chromaRunning) {
        Write-Alert "  → ChromaDB container is already running"
    } else {
        Write-Info "  Pulling ChromaDB image..."
        docker pull chromadb/chroma:latest
        
        Write-Info "  Starting ChromaDB container..."
        $chromaCommand = @"
docker run -d `
  --name chromadb `
  -p ${ChromaDBPort}:8000 `
  -v "${WorkshopPath}\chromadb\data:/chroma/chroma" `
  -e IS_PERSISTENT=TRUE `
  -e ANONYMIZED_TELEMETRY=FALSE `
  --restart unless-stopped `
  chromadb/chroma:latest
"@
        
        Invoke-Expression $chromaCommand
        
        Write-Info "  Waiting for ChromaDB to start..."
        Start-Sleep -Seconds 5
        
        # Verify ChromaDB is running
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:$ChromaDBPort/api/v1/heartbeat" -Method Get
            Write-Success "  ✓ ChromaDB is running on port $ChromaDBPort"
        } catch {
            Write-Alert "  → ChromaDB may still be starting up"
        }
    }
} catch {
    Write-Error "Failed to setup ChromaDB: $_"
    exit 1
}

# Setup N8N
Write-Info "`n[5/5] Setting up N8N..."

try {
    # Check if N8N is already running
    $n8nRunning = docker ps --filter "name=n8n" --format "{{.Names}}" 2>$null
    
    if ($n8nRunning) {
        Write-Alert "  → N8N container is already running"
    } else {
        Write-Info "  Pulling N8N image..."
        docker pull n8nio/n8n:latest
        
        Write-Info "  Starting N8N container..."
        $n8nCommand = @"
docker run -d `
  --name n8n `
  -p ${N8NPort}:5678 `
  -v "${WorkshopPath}\n8n\data:/home/node/.n8n" `
  -v "${WorkshopPath}\n8n\files:/files" `
  -e N8N_SECURE_COOKIE=false `
  -e N8N_HOST=localhost `
  -e N8N_PORT=5678 `
  -e N8N_PROTOCOL=http `
  -e WEBHOOK_URL=http://localhost:5678/ `
  -e N8N_METRICS=false `
  --restart unless-stopped `
  n8nio/n8n:latest
"@
        
        Invoke-Expression $n8nCommand
        
        Write-Info "  Waiting for N8N to start..."
        Start-Sleep -Seconds 10
        
        # Verify N8N is running
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$N8NPort" -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Success "  ✓ N8N is running on port $N8NPort"
            }
        } catch {
            Write-Alert "  → N8N may still be starting up (this can take up to 30 seconds)"
        }
    }
} catch {
    Write-Error "Failed to setup N8N: $_"
    exit 1
}

# Create test HTML file
Write-Info "`nCreating test interface..."

$testHtml = @'
<!DOCTYPE html>
<html>
<head>
    <title>GDrive Q&A Test Interface</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 40px;
            max-width: 800px;
            width: 100%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 2em;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 0.9em;
        }
        .input-group {
            display: flex;
            gap: 10px;
            margin-bottom: 30px;
        }
        input[type="text"] {
            flex: 1;
            padding: 15px;
            font-size: 16px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            transition: border-color 0.3s;
        }
        input[type="text"]:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            padding: 15px 30px;
            font-size: 16px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        button:active {
            transform: translateY(0);
        }
        #response {
            margin-top: 30px;
            padding: 20px;
            background-color: #f8f9fa;
            border-radius: 10px;
            min-height: 100px;
            display: none;
        }
        #response.show {
            display: block;
        }
        .answer-section {
            margin-bottom: 20px;
        }
        .answer-label {
            font-weight: bold;
            color: #667eea;
            margin-bottom: 10px;
        }
        .answer-text {
            color: #333;
            line-height: 1.6;
        }
        .source {
            margin-top: 10px;
            padding: 15px;
            background: white;
            border-left: 4px solid #667eea;
            border-radius: 5px;
        }
        .source-title {
            font-weight: bold;
            color: #333;
            margin-bottom: 5px;
        }
        .source-link {
            color: #667eea;
            text-decoration: none;
        }
        .source-link:hover {
            text-decoration: underline;
        }
        .loading {
            text-align: center;
            color: #666;
        }
        .loading::after {
            content: '';
            animation: dots 1.5s steps(4, end) infinite;
        }
        @keyframes dots {
            0%, 20% { content: ''; }
            40% { content: '.'; }
            60% { content: '..'; }
            80%, 100% { content: '...'; }
        }
        .error {
            background: #fee;
            border-left: 4px solid #f44336;
            color: #c00;
            padding: 15px;
            border-radius: 5px;
        }
        .status {
            position: absolute;
            top: 20px;
            right: 20px;
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: bold;
        }
        .status.online {
            background: #4caf50;
            color: white;
        }
        .status.offline {
            background: #f44336;
            color: white;
        }
    </style>
</head>
<body>
    <div class="status offline" id="status">Checking...</div>
    <div class="container">
        <h1>🤖 Google Drive Q&A System</h1>
        <div class="subtitle">Ask questions about your company documents</div>
        
        <div class="input-group">
            <input type="text" id="question" placeholder="What would you like to know about your documents?">
            <button onclick="askQuestion()">Ask Question</button>
        </div>
        
        <div id="response"></div>
    </div>

    <script>
        // Check webhook status
        async function checkStatus() {
            try {
                const response = await fetch('http://localhost:5678/webhook/gdrive-qa', {
                    method: 'OPTIONS'
                });
                document.getElementById('status').className = 'status online';
                document.getElementById('status').textContent = '● Online';
            } catch {
                document.getElementById('status').className = 'status offline';
                document.getElementById('status').textContent = '● Offline';
            }
        }
        
        checkStatus();
        setInterval(checkStatus, 30000); // Check every 30 seconds
        
        async function askQuestion() {
            const question = document.getElementById('question').value;
            const responseDiv = document.getElementById('response');
            
            if (!question.trim()) {
                alert('Please enter a question');
                return;
            }
            
            responseDiv.className = 'show';
            responseDiv.innerHTML = '<div class="loading">Processing your question</div>';
            
            try {
                const response = await fetch('http://localhost:5678/webhook/gdrive-qa', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ question: question })
                });
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                
                const data = await response.json();
                
                let html = '<div class="answer-section">';
                html += '<div class="answer-label">Question:</div>';
                html += `<div class="answer-text">${data.question}</div>`;
                html += '</div>';
                
                html += '<div class="answer-section">';
                html += '<div class="answer-label">Answer:</div>';
                html += `<div class="answer-text">${data.answer}</div>`;
                html += '</div>';
                
                if (data.sources && data.sources.length > 0) {
                    html += '<div class="answer-section">';
                    html += '<div class="answer-label">Sources:</div>';
                    data.sources.forEach((source, index) => {
                        html += `<div class="source">
                            <div class="source-title">📄 ${source.document}</div>
                            <div>Relevance: ${source.relevance_score}</div>
                            <a href="${source.link}" target="_blank" class="source-link">View Document →</a>
                        </div>`;
                    });
                    html += '</div>';
                }
                
                responseDiv.innerHTML = html;
            } catch (error) {
                responseDiv.innerHTML = `<div class="error">
                    <strong>Error:</strong> ${error.message}<br>
                    <small>Make sure the N8N webhook is active and properly configured.</small>
                </div>`;
            }
        }
        
        // Allow Enter key to submit
        document.getElementById('question').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                askQuestion();
            }
        });
    </script>
</body>
</html>
'@

$testHtmlPath = "$WorkshopPath\test\qa-interface.html"
$testHtml | Out-File -FilePath $testHtmlPath -Encoding UTF8
Write-Success "✓ Created test interface: $testHtmlPath"

# Create docker management script
Write-Info "Creating Docker management script..."

$dockerScript = @'
# Docker Container Management Script
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop", "restart", "status", "logs")]
    [string]$Action,
    
    [ValidateSet("all", "chromadb", "n8n")]
    [string]$Container = "all"
)

function Write-Info { Write-Host $args[0] -ForegroundColor Cyan }
function Write-Success { Write-Host $args[0] -ForegroundColor Green }

$containers = if ($Container -eq "all") { @("chromadb", "n8n") } else { @($Container) }

switch ($Action) {
    "start" {
        foreach ($c in $containers) {
            Write-Info "Starting $c..."
            docker start $c
        }
    }
    "stop" {
        foreach ($c in $containers) {
            Write-Info "Stopping $c..."
            docker stop $c
        }
    }
    "restart" {
        foreach ($c in $containers) {
            Write-Info "Restarting $c..."
            docker restart $c
        }
    }
    "status" {
        Write-Info "Container Status:"
        docker ps -a --filter "name=chromadb" --filter "name=n8n" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    }
    "logs" {
        foreach ($c in $containers) {
            Write-Info "Logs for $c (last 20 lines):"
            docker logs --tail 20 $c
        }
    }
}
'@

$dockerScriptPath = "$WorkshopPath\scripts\manage-containers.ps1"
$dockerScript | Out-File -FilePath $dockerScriptPath -Encoding UTF8
Write-Success "✓ Created management script: $dockerScriptPath"

# Verification
Write-Info "`nVerifying container setup..."

$verificationResults = @()

# Check ChromaDB
try {
    $chromaStatus = docker ps --filter "name=chromadb" --format "{{.Status}}" 2>$null
    if ($chromaStatus -like "Up*") {
        $verificationResults += "✓ ChromaDB: Running"
        
        # Test API
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:$ChromaDBPort/api/v1/heartbeat" -Method Get -ErrorAction SilentlyContinue
            $verificationResults += "✓ ChromaDB API: Accessible at http://localhost:$ChromaDBPort"
        } catch {
            $verificationResults += "✗ ChromaDB API: Not responding"
        }
    } else {
        $verificationResults += "✗ ChromaDB: Not running"
    }
} catch {
    $verificationResults += "✗ ChromaDB: Container not found"
}

# Check N8N
try {
    $n8nStatus = docker ps --filter "name=n8n" --format "{{.Status}}" 2>$null
    if ($n8nStatus -like "Up*") {
        $verificationResults += "✓ N8N: Running"
        $verificationResults += "✓ N8N UI: http://localhost:$N8NPort"
    } else {
        $verificationResults += "✗ N8N: Not running"
    }
} catch {
    $verificationResults += "✗ N8N: Container not found"
}

# Display results
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                     Container Status                         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

foreach ($result in $verificationResults) {
    if ($result -like "*✓*") {
        Write-Success $result
    } else {
        Write-Alert $result
    }
}

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Container Setup Complete!                       ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Info @"

🎉 Your N8N RAG Workshop environment is ready!

📍 Access Points:
   • N8N Interface: http://localhost:$N8NPort
   • ChromaDB API: http://localhost:$ChromaDBPort
   • Test Interface: file:///$testHtmlPath

📁 Data Directories:
   • ChromaDB Data: $WorkshopPath\chromadb\data
   • N8N Data: $WorkshopPath\n8n\data
   • N8N Files: $WorkshopPath\n8n\files

🛠️ Management Commands:
   • Start containers: .\scripts\manage-containers.ps1 -Action start
   • Stop containers: .\scripts\manage-containers.ps1 -Action stop
   • View status: .\scripts\manage-containers.ps1 -Action status
   • View logs: .\scripts\manage-containers.ps1 -Action logs

📝 Next Steps:
   1. Open N8N at http://localhost:$N8NPort
   2. Import the workflow templates
   3. Configure Google Drive OAuth
   4. Run the initialization workflow
   5. Test with the Q&A interface

💡 Workshop Tips:
   • Keep Docker Desktop running during the workshop
   • Use 'ollama serve' if Ollama stops responding
   • Check container logs if issues occur
   • The test interface will show connection status

"@

# Open N8N in browser
$openBrowser = Read-Host "Would you like to open N8N in your browser now? (y/n)"
if ($openBrowser -eq 'y') {
    Start-Process "http://localhost:$N8NPort"
}

Write-Success "✓ Setup completed successfully!"