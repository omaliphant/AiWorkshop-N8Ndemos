# Oz's AI Workshop - RAG Environment
**September 10th, 2025**

A complete local RAG (Retrieval Augmented Generation) setup using N8N with LangChain nodes, Ollama, and Qdrant. Perfect for learning how AI systems can intelligently search and respond using your own documents.

## What You'll Learn Today

- **RAG Architecture**: How Retrieval Augmented Generation works in practice
- **Vector Databases**: Using Qdrant for semantic document search
- **Local AI Models**: Running Llama 3.2 locally with Ollama
- **Workflow Automation**: Building AI pipelines with N8N and LangChain
- **Document Processing**: From files to searchable knowledge base

## Prerequisites

- Docker Desktop installed and running
- NVIDIA GPU with Docker GPU support (optional but recommended)
- At least 8GB RAM available for containers
- Basic understanding of AI/ML concepts

## Quick Setup

### Windows Users
1. **Open PowerShell as Administrator**
   ```powershell
   # Navigate to workshop directory
   cd path\to\workshop
   
   # Run setup script
   .\setup.ps1
   
   # For CPU-only (no GPU)
   .\setup.ps1 -NoGPU
   ```

### Linux/Mac Users
1. **Run setup script**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

### Manual Setup (if scripts fail)
```bash
# Start all services
docker-compose up -d

# Pull the AI model
docker exec ollama ollama pull llama3.2:3b

# Create vector collection
curl -X PUT "http://localhost:6333/collections/documents" \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 4096, "distance": "Cosine"}}'
```

## Workshop Steps

### Step 1: Import the N8N Workflow
1. Open N8N at http://localhost:5678
2. Go to **Workflows** → **Import from File**
3. Upload the provided workflow JSON file
4. You should see the complete RAG pipeline

### Step 2: Configure Credentials
Set up these credentials in N8N:

**Ollama API Credential:**
- Name: `Ollama account`
- Base URL: `http://ollama:11434`
- No authentication needed

**Qdrant API Credential:**
- Name: `QdrantApi account`  
- Host: `qdrant`
- Port: `6333`
- API Key: (leave empty for local setup)

### Step 3: Set Collection Name
- In both Qdrant Vector Store nodes, set collection to: `local_docs`
- This will be created automatically on first use

### Step 4: Test with Sample Data
1. **Copy test file**: Save the provided `dad-jokes.txt` to the `./files` directory
2. **Activate workflow**: Toggle the workflow to "Active"
3. **Process documents**: Click "Execute workflow" (manual trigger)
4. **Wait for processing**: Watch the workflow execute and index the jokes

### Step 5: Start Chatting
1. Click the **"When chat message received"** node
2. Use the chat interface to ask questions like:
   - "Tell me a joke about animals"
   - "What's funny about bicycles?"
   - "Show me jokes with food"
   - "Find a joke about the ocean"

## Workshop Architecture

```
📁 Files Directory → 🔄 N8N Processing → 🗄️ Qdrant Storage → 💬 Chat Interface
     ↓                    ↓                     ↓              ↓
  Text Files         Extract & Chunk       Vector Storage    AI Responses
   (*.txt)          Create Embeddings     Similarity Search  with Context
```

### Services Overview

| Service | URL | Purpose | Port |
|---------|-----|---------|------|
| **N8N** | http://localhost:5678 | Workflow automation & Chat | 5678 |
| **Qdrant** | http://localhost:6333 | Vector database | 6333 |
| **Ollama** | http://localhost:11434 | Local LLM | 11434 |

## Understanding the RAG Process

### Document Processing Flow:
1. **File Detection**: N8N watches for new files in `/files` directory
2. **Format Validation**: Filters for supported types (PDF, TXT, DOC, etc.)
3. **Content Extraction**: Reads and extracts text from documents
4. **Text Chunking**: Splits content into manageable pieces
5. **Embedding Generation**: Creates vector representations using Llama 3.2
6. **Vector Storage**: Stores embeddings in Qdrant with metadata

### Chat Query Flow:
1. **User Question**: Enter question in N8N chat interface
2. **Query Embedding**: Convert question to vector representation
3. **Similarity Search**: Find relevant document chunks in Qdrant
4. **Context Assembly**: Gather matching content as context
5. **AI Response**: Generate answer using Ollama with retrieved context
6. **Source Attribution**: Show which documents informed the response

## Workshop Exercises

### Exercise 1: Basic RAG
- Process the dad-jokes file
- Ask for jokes by category
- Notice how the AI finds relevant jokes

### Exercise 2: Custom Documents
- Add your own text files to `/files`
- Process them through the workflow
- Ask questions about your content

### Exercise 3: Understanding Embeddings
- Look at the Qdrant collection: http://localhost:6333/collections/local_docs
- See how documents are stored as vectors
- Experiment with different search queries

### Exercise 4: Workflow Customization
- Modify chunk sizes in the processing pipeline
- Adjust similarity thresholds
- Try different embedding models

## Key Learning Points

**Vector Embeddings**: How text becomes searchable mathematical representations  
**Semantic Search**: Finding meaning, not just keywords  
**Context Window**: How much information the AI uses to respond  
**Local AI**: Running powerful models without cloud dependencies  
**RAG vs Fine-tuning**: When to retrieve vs when to train  

## Troubleshooting

### Model Download Issues
```bash
# Check if model exists
docker exec ollama ollama list

# Manual download
docker exec ollama ollama pull llama3.2:3b
```

### Qdrant Connection Issues
```bash
# Check Qdrant status
curl http://localhost:6333/collections

# Restart if needed
docker-compose restart qdrant
```

### N8N Workflow Issues
- Ensure workflow is **activated** (green toggle)
- Check all **credentials are configured**
- Verify **collection name** is `local_docs` in both vector nodes
- Test individual nodes by clicking "Test step"

### Performance Tips
- **GPU Users**: Faster embedding generation and responses
- **CPU Users**: Expect slower processing, but still functional
- **Memory**: Each document chunk uses ~16KB of vector storage
- **Scaling**: Can handle thousands of documents

## Post-Workshop

### What You've Built
- A complete local RAG system
- Document processing pipeline
- Intelligent search capabilities
- Conversational AI interface

### Next Steps
- Add more document types (PDFs, Word docs)
- Experiment with different AI models
- Scale to larger document collections
- Integrate with other applications

### Resources
- N8N Documentation: https://docs.n8n.io
- Qdrant Documentation: https://qdrant.tech/documentation
- Ollama Models: https://ollama.ai/library
- LangChain Integration: https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain/

## Workshop Cleanup

To stop and remove everything:
```bash
# Stop services
docker-compose down

# Remove volumes (optional - deletes all data)
docker-compose down -v
```

---

**Workshop Leader**: Oz  
**Date**: September 10th, 2025  
**Duration**: ~2 hours  
**Difficulty**: Intermediate  

*Questions? Ask during the workshop or reach out afterward!*