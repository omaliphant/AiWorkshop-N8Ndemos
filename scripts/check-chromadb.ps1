# ChromaDB Collection Management Script
# Checks if the 'local_docs' collection exists and creates it if needed

$chromaHost = "http://localhost:8000"
$collectionName = "local_docs"

Write-Host "ChromaDB Collection Check Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Function to check ChromaDB health
function Test-ChromaDB {
    try {
        $response = Invoke-RestMethod -Uri "$chromaHost/api/v1/heartbeat" -Method GET -ErrorAction Stop
        Write-Host "[OK] ChromaDB is running" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERROR] ChromaDB is not accessible at $chromaHost" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        return $false
    }
}

# Function to list all collections
function Get-Collections {
    try {
        $response = Invoke-RestMethod -Uri "$chromaHost/api/v1/collections" -Method GET -ErrorAction Stop
        return $response
    }
    catch {
        Write-Host "[ERROR] Failed to get collections" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        return $null
    }
}

# Function to get specific collection
function Get-Collection {
    param($name)
    try {
        $response = Invoke-RestMethod -Uri "$chromaHost/api/v1/collections/$name" -Method GET -ErrorAction Stop
        return $response
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 'NotFound') {
            return $null
        }
        Write-Host "[ERROR] Error checking collection: $_" -ForegroundColor Red
        return $null
    }
}

# Function to create collection
function New-Collection {
    param($name)
    try {
        $body = @{
            name = $name
            metadata = @{
                description = "Local document storage"
                created_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$chromaHost/api/v1/collections" `
            -Method POST `
            -Body $body `
            -ContentType "application/json" `
            -ErrorAction Stop
            
        return $response
    }
    catch {
        Write-Host "[ERROR] Failed to create collection" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        return $null
    }
}

# Function to delete collection (if needed)
function Remove-Collection {
    param($name)
    try {
        $response = Invoke-RestMethod -Uri "$chromaHost/api/v1/collections/$name" `
            -Method DELETE `
            -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to delete collection" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        return $false
    }
}

# Main execution
Write-Host "1. Checking ChromaDB connection..." -ForegroundColor White
if (-not (Test-ChromaDB)) {
    Write-Host ""
    Write-Host "Please ensure ChromaDB is running:" -ForegroundColor Yellow
    Write-Host "  docker run -p 8000:8000 chromadb/chroma" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "2. Listing all collections..." -ForegroundColor White
$collections = Get-Collections
if ($collections) {
    if ($collections.Count -eq 0) {
        Write-Host "  No collections found" -ForegroundColor Yellow
    }
    else {
        Write-Host "  Found $($collections.Count) collection(s):" -ForegroundColor Green
        foreach ($col in $collections) {
            Write-Host "    - $($col.name)" -ForegroundColor Gray
            if ($col.name -eq $collectionName) {
                Write-Host "      [OK] Target collection found!" -ForegroundColor Green
            }
        }
    }
}

Write-Host ""
Write-Host "3. Checking for '$collectionName' collection..." -ForegroundColor White
$collection = Get-Collection -name $collectionName
if ($collection) {
    Write-Host "  [OK] Collection '$collectionName' exists" -ForegroundColor Green
    Write-Host "    ID: $($collection.id)" -ForegroundColor Gray
    Write-Host "    Name: $($collection.name)" -ForegroundColor Gray
    if ($collection.metadata) {
        Write-Host "    Metadata: $($collection.metadata | ConvertTo-Json -Compress)" -ForegroundColor Gray
    }
}
else {
    Write-Host "  [INFO] Collection '$collectionName' does not exist" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4. Creating collection '$collectionName'..." -ForegroundColor White
    
    $newCollection = New-Collection -name $collectionName
    if ($newCollection) {
        Write-Host "  [OK] Collection created successfully!" -ForegroundColor Green
        Write-Host "    ID: $($newCollection.id)" -ForegroundColor Gray
        Write-Host "    Name: $($newCollection.name)" -ForegroundColor Gray
    }
    else {
        Write-Host "  [ERROR] Failed to create collection" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "5. Testing collection with a sample add operation..." -ForegroundColor White
try {
    # Create a 768-dimensional zero vector
    $zeroVector = @()
    for ($i = 0; $i -lt 768; $i++) {
        $zeroVector += 0
    }
    
    # First get the collection to use its ID
    $testCollection = Get-Collection -name $collectionName
    if ($testCollection) {
        $collectionId = $testCollection.id
        
        $testData = @{
            ids = @("test_doc_1")
            documents = @("This is a test document")
            metadatas = @(@{source = "test"})
            embeddings = @($zeroVector)
        } | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri "$chromaHost/api/v1/collections/$collectionId/add" `
            -Method POST `
            -Body $testData `
            -ContentType "application/json" `
            -ErrorAction Stop
        
        Write-Host "  [OK] Successfully added test document to collection" -ForegroundColor Green
        
        # Clean up test document
        $deleteData = @{
            ids = @("test_doc_1")
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri "$chromaHost/api/v1/collections/$collectionId/delete" `
            -Method POST `
            -Body $deleteData `
            -ContentType "application/json" `
            -ErrorAction SilentlyContinue | Out-Null
            
        Write-Host "  [OK] Test document cleaned up" -ForegroundColor Gray
    } else {
        Write-Host "  [SKIP] Could not get collection ID for testing" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  [ERROR] Failed to add to collection" -ForegroundColor Red
    Write-Host "    Error: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "ChromaDB collection check complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor White
Write-Host "  ChromaDB URL: $chromaHost" -ForegroundColor Gray
Write-Host "  Collection: '$collectionName'" -ForegroundColor Gray
Write-Host "  Status: Ready for indexing" -ForegroundColor Green