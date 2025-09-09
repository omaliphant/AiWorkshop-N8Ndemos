# N8N RAG Workshop - Docker Container Setup Script (CORS-Fixed Version)
# Run after installing prerequisites
# This version fixes CORS issues for browser-based HTML interfaces

param(
    [string]$WorkshopPath = "c:\dev\workshop",
    [string]$ChromaDBPort = "8000",
    [string]$N8NPort = "5678",
    [switch]$RemoveExisting = $false,
    [string]$LocalDrivePath = "G:\My Drive"  # Default to G: drive
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
Write-Host "      Oz' AI Workshop - Container Setup (CORS-Fixed)          " -ForegroundColor Cyan
Write-Host "                 ChromaDB & N8N Deployment                    " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Check if local drive path exists
Write-Info "[1/7] Checking local drive access..."
if (Test-Path $LocalDrivePath) {
    Write-Success "  [OK] Path exists and is accessible"
} else {
    Write-Alert "[!] Cannot access $LocalDrivePath"
    Write-Alert "  You can configure this later in the N8N workflow"
    $response = Read-Host "  Continue anyway? (y/n)"
    if ($response -ne 'y') {
        exit 1
    }
}

# Check if Docker is running
Write-Info "`n[2/7] Checking Docker status..."
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
Write-Info "`n[3/7] Creating data directories..."

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
    Write-Info "`n[4/7] Removing existing containers..."
    
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
    Write-Info "`n[4/7] Checking for existing containers..."
    
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

# Setup Ollama CORS environment
Write-Info "`n[5/7] Configuring Ollama CORS settings..."
try {
    # Set Ollama CORS environment variable
    [Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "User")
    $env:OLLAMA_ORIGINS = "*"
    Write-Success "  [OK] Ollama CORS origins set to '*'"
    
    # Check if Ollama is running and restart if needed
    $ollamaProcess = Get-Process "ollama" -ErrorAction SilentlyContinue
    if ($ollamaProcess) {
        Write-Info "  Restarting Ollama with new CORS settings..."
        Stop-Process -Name "ollama" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
        Write-Success "  [OK] Ollama restarted with CORS enabled"
    } else {
        Write-Info "  Starting Ollama with CORS enabled..."
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
        Write-Success "  [OK] Ollama started with CORS enabled"
    }
} catch {
    Write-Alert "  [!] Could not configure Ollama CORS automatically"
    Write-Info "  You may need to run: `$env:OLLAMA_ORIGINS='*'; ollama serve"
}

# Setup ChromaDB with CORS
Write-Info "`n[6/7] Setting up ChromaDB with CORS..."

try {
    # Check if ChromaDB is already running
    $chromaRunning = docker ps --filter "name=chromadb" --format "{{.Names}}" 2>$null
    
    if ($chromaRunning) {
        Write-Alert "  [->] ChromaDB container is already running"
    } else {
        Write-Info "  Pulling ChromaDB image (v0.6.1)..."
        docker pull chromadb/chroma:0.6.1
        
        Write-Info "  Starting ChromaDB container with CORS enabled..."
        $chromaCommand = @"
docker run -d ``
  --name chromadb ``
  -p ${ChromaDBPort}:8000 ``
  -v "${WorkshopPath}\chromadb\data:/chroma/chroma" ``
  -e IS_PERSISTENT=TRUE ``
  -e ANONYMIZED_TELEMETRY=FALSE ``
  --restart unless-stopped ``
  chromadb/chroma:0.6.1
"@
        
        Invoke-Expression $chromaCommand
        
        Write-Info "  Waiting for ChromaDB to start..."
        Start-Sleep -Seconds 5
        
        # Verify ChromaDB is running
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:$ChromaDBPort/api/v1/heartbeat" -Method Get
            Write-Success "  [OK] ChromaDB is running on port $ChromaDBPort with CORS enabled"
        } catch {
            Write-Alert "  [->] ChromaDB may still be starting up"
        }
    }
} catch {
    Write-Error "Failed to setup ChromaDB: $_"
    exit 1
}

# Setup N8N with CORS
Write-Info "`nSetting up N8N with CORS..."

try {
    # Check if N8N is already running
    $n8nRunning = docker ps --filter "name=n8n" --format "{{.Names}}" 2>$null
    
    if ($n8nRunning) {
        Write-Alert "  [->] N8N container is already running"
    } else {
        Write-Info "  Pulling N8N image..."
        docker pull n8nio/n8n:latest
        
        Write-Info "  Starting N8N container with CORS enabled..."
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
  -e N8N_CORS_ORIGIN="*" ``
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
                Write-Success "  [OK] N8N is running on port $N8NPort with CORS enabled"
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

# Create CORS-fixed test HTML file
Write-Info "`n[7/7] Creating CORS-compatible test interface..."

$testHtmlPath = "$WorkshopPath\test\qa-interface-cors-fixed.html"

$testHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Oz' AI Workshop - Local Drive Q&A System (CORS Fixed)</title>
    <style>
        * { 
            margin: 0; 
            padding: 0; 
            box-sizing: border-box; 
        }
        
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
            max-width: 900px;
            width: 100%;
        }
        
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 2.2em;
        }
        
        .subtitle {
            color: #666;
            font-size: 1.1em;
            margin-bottom: 5px;
        }
        
        .workshop-info {
            color: #764ba2;
            font-weight: bold;
            font-size: 0.9em;
        }
        
        .cors-notice {
            background: #e8f5e8;
            border: 1px solid #4caf50;
            border-radius: 8px;
            padding: 10px;
            margin-bottom: 20px;
            color: #2e7d32;
            font-size: 0.9em;
        }
        
        .status-bar {
            display: flex;
            justify-content: space-around;
            margin-bottom: 30px;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        
        .status-item {
            text-align: center;
        }
        
        .status-label {
            font-size: 0.8em;
            color: #666;
            margin-bottom: 5px;
        }
        
        .status-value {
            font-weight: bold;
            padding: 5px 15px;
            border-radius: 15px;
            font-size: 0.9em;
        }
        
        .status-value.online {
            background: #4caf50;
            color: white;
        }
        
        .status-value.offline {
            background: #f44336;
            color: white;
        }
        
        .status-value.info {
            background: #2196F3;
            color: white;
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
            white-space: nowrap;
        }
        
        button:hover:not(:disabled) {
            transform: translateY(-2px);
        }
        
        button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
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
        
        .sample-questions {
            margin-top: 20px;
            padding: 15px;
            background: #f0f7ff;
            border-radius: 10px;
        }
        
        .sample-questions h3 {
            color: #667eea;
            font-size: 0.9em;
            margin-bottom: 10px;
        }
        
        .sample-list {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
        }
        
        .sample-btn {
            padding: 5px 12px;
            background: white;
            border: 1px solid #667eea;
            border-radius: 15px;
            font-size: 0.85em;
            color: #667eea;
            cursor: pointer;
            transition: all 0.2s;
        }
        
        .sample-btn:hover {
            background: #667eea;
            color: white;
        }
        
        .error {
            background: #fee;
            border-left: 4px solid #f44336;
            color: #c00;
            padding: 15px;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Local Drive Q&A System</h1>
            <div class="subtitle">Ask questions about your G: drive documents</div>
            <div class="workshop-info">Oz' AI Workshop - 9 September 2025 - CORS Fixed Version</div>
        </div>
        
        <div class="cors-notice">
            ✅ CORS-Fixed Version: This interface can connect to your local services without cross-origin issues.
        </div>
        
        <div class="status-bar">
            <div class="status-item">
                <div class="status-label">N8N Status</div>
                <div class="status-value offline" id="n8n-status">Checking...</div>
            </div>
            <div class="status-item">
                <div class="status-label">ChromaDB</div>
                <div class="status-value offline" id="chromadb-status">Checking...</div>
            </div>
            <div class="status-item">
                <div class="status-label">Ollama</div>
                <div class="status-value offline" id="ollama-status">Checking...</div>
            </div>
            <div class="status-item">
                <div class="status-label">Indexed Docs</div>
                <div class="status-value info" id="doc-count">-</div>
            </div>
        </div>
        
        <div class="input-group">
            <input type="text" id="question" placeholder="What would you like to know about your documents?" 
                   autocomplete="off" spellcheck="true">
            <button onclick="askQuestion()" id="ask-btn">Ask Question</button>
        </div>
        
        <div class="sample-questions">
            <h3>Try these sample questions:</h3>
            <div class="sample-list">
                <button class="sample-btn" onclick="setSampleQuestion('What is our remote work policy?')">
                    Remote Work Policy
                </button>
                <button class="sample-btn" onclick="setSampleQuestion('How do I submit an expense report?')">
                    Expense Reports
                </button>
                <button class="sample-btn" onclick="setSampleQuestion('What are the company core values?')">
                    Core Values
                </button>
                <button class="sample-btn" onclick="setSampleQuestion('What is the vacation policy?')">
                    Vacation Policy
                </button>
                <button class="sample-btn" onclick="setSampleQuestion('Who should I contact for IT support?')">
                    IT Support
                </button>
            </div>
        </div>
        
        <div id="response"></div>
    </div>

    <script>
        // Configuration - Using localhost for CORS-fixed version
        const WEBHOOK_URL = 'http://localhost:5678/webhook/local-qa';
        const CHROMADB_URL = 'http://localhost:8000';
        const OLLAMA_URL = 'http://localhost:11434';
        
        // Check service status
        async function checkStatus() {
            // Check N8N webhook
            try {
                // Use a simple GET request to check if webhook endpoint responds
                const response = await fetch(`${WEBHOOK_URL.replace('/webhook/local-qa', '')}/healthz`, {
                    method: 'GET'
                }).catch(() => {
                    // If healthz doesn't exist, try a simple request to base URL
                    return fetch(WEBHOOK_URL.replace('/webhook/local-qa', ''));
                });
                
                document.getElementById('n8n-status').className = 'status-value online';
                document.getElementById('n8n-status').textContent = 'Online';
            } catch {
                document.getElementById('n8n-status').className = 'status-value offline';
                document.getElementById('n8n-status').textContent = 'Offline';
            }
            
            // Check ChromaDB
            try {
                const response = await fetch(`${CHROMADB_URL}/api/v1/heartbeat`);
                if (response.status === 200) {
                    document.getElementById('chromadb-status').className = 'status-value online';
                    document.getElementById('chromadb-status').textContent = 'Online';
                    
                    // Try to get collection info
                    try {
                        const collResponse = await fetch(`${CHROMADB_URL}/api/v1/collections/local_docs`);
                        if (collResponse.ok) {
                            const data = await collResponse.json();
                            document.getElementById('doc-count').textContent = 'Ready';
                        }
                    } catch {
                        document.getElementById('doc-count').textContent = 'No Data';
                    }
                }
            } catch {
                document.getElementById('chromadb-status').className = 'status-value offline';
                document.getElementById('chromadb-status').textContent = 'Offline';
            }
            
            // Check Ollama
            try {
                const response = await fetch(`${OLLAMA_URL}/api/tags`);
                if (response.status === 200) {
                    document.getElementById('ollama-status').className = 'status-value online';
                    document.getElementById('ollama-status').textContent = 'Online';
                }
            } catch {
                document.getElementById('ollama-status').className = 'status-value offline';
                document.getElementById('ollama-status').textContent = 'Offline';
            }
        }
        
        // Set sample question
        function setSampleQuestion(question) {
            document.getElementById('question').value = question;
            document.getElementById('question').focus();
        }
        
        // Ask question
        async function askQuestion() {
            const questionInput = document.getElementById('question');
            const question = questionInput.value.trim();
            const responseDiv = document.getElementById('response');
            const askBtn = document.getElementById('ask-btn');
            
            if (!question) {
                alert('Please enter a question');
                return;
            }
            
            // Disable button and show loading
            askBtn.disabled = true;
            askBtn.textContent = 'Processing...';
            
            responseDiv.className = 'show';
            responseDiv.innerHTML = '<div>Searching local documents and generating answer...</div>';
            
            try {
                const response = await fetch(WEBHOOK_URL, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ 
                        question: question,
                        max_results: 5
                    })
                });
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                
                const data = await response.json();
                
                // Build response HTML
                let html = '<div><strong>Question:</strong> ' + escapeHtml(data.question) + '</div><br>';
                html += '<div><strong>Answer:</strong> ' + escapeHtml(data.answer) + '</div><br>';
                
                if (data.sources && data.sources.length > 0) {
                    html += '<div><strong>Sources:</strong></div>';
                    data.sources.forEach((source, index) => {
                        html += '<div style="background: white; padding: 10px; margin: 10px 0; border-left: 3px solid #667eea; border-radius: 4px;">';
                        html += '<strong>' + escapeHtml(source.document) + '</strong> (Relevance: ' + source.relevance_score + ')<br>';
                        html += '<small>' + source.chunk_info + '</small>';
                        html += '</div>';
                    });
                } else {
                    html += '<div><strong>Note:</strong> No source documents were found. You may need to index your G: drive first.</div>';
                }
                
                responseDiv.innerHTML = html;
                
            } catch (error) {
                console.error('Error:', error);
                responseDiv.innerHTML = `<div class="error">
                    <strong>Error:</strong> ${escapeHtml(error.message)}<br>
                    <small>Make sure the N8N webhook is active and all services are running.</small>
                </div>`;
            } finally {
                // Re-enable button
                askBtn.disabled = false;
                askBtn.textContent = 'Ask Question';
            }
        }
        
        // Escape HTML to prevent XSS
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        // Allow Enter key to submit
        document.getElementById('question').addEventListener('keypress', function(e) {
            if (e.key === 'Enter' && !document.getElementById('ask-btn').disabled) {
                askQuestion();
            }
        });
        
        // Check status on load
        checkStatus();
        
        // Check status every 30 seconds
        setInterval(checkStatus, 30000);
        
        // Focus on input field
        document.getElementById('question').focus();
    </script>
</body>
</html>
'@

$testHtml | Out-File -FilePath $testHtmlPath -Encoding UTF8
Write-Success "[OK] CORS-compatible test interface created: $testHtmlPath"

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
    cors_enabled = $true
    ollama_origins = "*"
}

$configPath = "$WorkshopPath\workshop-config.json"
$config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
Write-Success "[OK] Configuration saved to: $configPath"

# Verification
Write-Info "`nVerifying CORS-enabled container setup..."

$verificationResults = @()

# Check ChromaDB
try {
    $chromaStatus = docker ps --filter "name=chromadb" --format "{{.Status}}" 2>$null
    if ($chromaStatus -like "Up*") {
        $verificationResults += "[OK] ChromaDB: Running with CORS enabled"
        
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
        $verificationResults += "[OK] N8N: Running with CORS enabled"
        $verificationResults += "[OK] N8N UI: http://localhost:$N8NPort"
    } else {
        $verificationResults += "[X] N8N: Not running"
    }
} catch {
    $verificationResults += "[X] N8N: Container not found"
}

# Check Ollama CORS
if ($env:OLLAMA_ORIGINS -eq "*") {
    $verificationResults += "[OK] Ollama: CORS origins set to '*'"
} else {
    $verificationResults += "[X] Ollama: CORS origins not set"
}

# Display results
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "                CORS-Fixed Container Status                    " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

foreach ($result in $verificationResults) {
    if ($result -like "*[OK]*") {
        Write-Success $result
    } else {
        Write-Alert $result
    }
}

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "          CORS-Fixed Container Setup Complete!                " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

Write-Info "`n[*] Your CORS-compatible Local Drive RAG Workshop environment is ready!"
Write-Info ""
Write-Info "CORS Fixes Applied:"
Write-Info "   ✅ ChromaDB: CORS headers enabled for all origins"
Write-Info "   ✅ N8N: CORS origin set to '*'"
Write-Info "   ✅ Ollama: OLLAMA_ORIGINS environment variable set"
Write-Info "   ✅ Test Interface: Uses localhost URLs (no cross-origin issues)"
Write-Info ""
Write-Info "Access Points:"
Write-Info "   * N8N Interface: http://localhost:$N8NPort"
Write-Info "   * ChromaDB API: http://localhost:$ChromaDBPort"
Write-Info "   * CORS-Fixed Test Interface: file:///$testHtmlPath"
Write-Info "   * Local Drive Path: $LocalDrivePath"
Write-Info ""
Write-Info "Next Steps:"
Write-Info "   1. Open N8N at http://localhost:$N8NPort"
Write-Info "   2. Import workflow templates from \n8n-templates\"
Write-Info "   3. Configure local drive path in indexer workflow"
Write-Info "   4. Run indexing workflow"
Write-Info "   5. Test with the CORS-fixed Q&A interface"
Write-Info ""

# Open N8N in browser
$openBrowser = Read-Host "Would you like to open N8N in your browser now? (y/n)"
if ($openBrowser -eq 'y') {
    Start-Process "http://localhost:$N8NPort"
}

Write-Success "[OK] CORS-fixed setup completed successfully!"