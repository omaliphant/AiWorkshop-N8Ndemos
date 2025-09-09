# Oz' AI Workshop - N8N RAG Demo
## 9 September 2025 - N8N with Ollama & Local File Indexing

## 🎯 Overview

This workshop is part of **Oz' AI Workshop Series** and teaches participants how to build a **Retrieval-Augmented Generation (RAG)** system using N8N workflow automation, local file indexing, and local LLMs via Ollama. Perfect for corporate environments where data security is paramount - everything runs locally on your machine with no external API calls!

### What You'll Build
- 📚 **Document Indexing System**: Automatically indexes documents from your G: drive (or any local/mapped drive)
- 🤖 **Intelligent Q&A Bot**: Answers questions about your company documents using AI
- 🔒 **Fully Local Processing**: No data leaves your machine - uses Ollama with Llama 3.2
- 🔄 **Automated Workflows**: N8N orchestrates the entire pipeline
- 🚫 **No Authentication Required**: Direct file system access - no OAuth, APIs, or tokens needed

### Key Features
- ✅ **100% Local Processing** - No external API calls or cloud services
- ✅ **Local Drive Indexing** - Works with G: drive or any mapped/local folders
- ✅ **No Authentication Required** - No OAuth, tokens, or API keys needed
- ✅ **Vector Search** - ChromaDB for intelligent document retrieval
- ✅ **Production Ready** - Includes error handling, logging, and monitoring
- ✅ **Simple Setup** - No complex authentication or permissions

## 📋 Prerequisites

### System Requirements
- **OS**: Windows 10/11 (64-bit) or macOS or Linux
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: 20GB free space
- **CPU**: Modern multi-core processor (4+ cores recommended)

### Software Requirements
- **Docker Desktop** (will be guided through installation)
- **PowerShell 5.1+** (Windows) or Terminal (macOS/Linux)
- **Access to G: drive** or local folders with documents
- **Administrator privileges** for installation

### Document Requirements
- **Supported Formats**: PDF, DOCX, DOC, TXT, MD files
- **Location**: G: drive (mapped network drive) or any local folder
- **Permissions**: Read access to target folders

## 🚀 Quick Start

### Windows Users

1. **Clone the Repository**
   ```powershell
   # Clone the workshop repository
   git clone [repository-url]
   cd oz-ai-workshop-n8n
   ```

2. **Run Installation Scripts**
   ```powershell
   # Run as Administrator
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   
   # Install prerequisites (Ollama, models)
   .\scripts\install-prerequisites.ps1
   
   # Setup Docker containers (ChromaDB, N8N)
   .\scripts\setup-containers.ps1
   
   # Optional: Specify your drive path
   .\scripts\setup-containers.ps1 -LocalDrivePath "G:\"
   ```

3. **Access the Applications**
   - N8N Interface: http://localhost:5678
   - ChromaDB API: http://localhost:8000
   - Test Interface: `c:\dev\workshop\test\qa-interface-local.html`

### macOS/Linux Users

See [Setup Guide](SETUP_GUIDE.md) for detailed instructions.

## 📁 Repository Structure

```
oz-ai-workshop-n8n/
├── scripts/
│   ├── install-prerequisites.ps1    # Ollama & model installation
│   ├── setup-containers.ps1         # Docker container setup
│   └── manage-containers.ps1        # Container management utility
├── n8n-templates/
│   ├── document-indexer-local.json  # Workflow 1: Local drive indexing
│   ├── qa-system-local.json         # Workflow 2: Q&A processing
│   └── initialize-chromadb-local.json # Workflow 3: DB initialization
├── test/
│   └── qa-interface-local.html      # Web UI for testing
├── README.md                        # This file
└── SETUP_GUIDE.md                   # Detailed setup instructions
```

## 📁 Local Workshop Directory (Created by Scripts)

```
c:\dev\workshop\
├── chromadb/
│   └── data/           # Vector database storage
├── n8n/
│   ├── data/           # N8N configuration
│   └── files/          # N8N file storage
├── test/
│   └── qa-interface-local.html  # Web UI for testing
├── downloads/          # Temporary downloads
└── models/            # Ollama model cache
```

## 🔧 Workshop Components

### 1. **Ollama (Local LLM)**
- **Model**: Llama 3.2 3B - Fast, efficient text generation
- **Embeddings**: Nomic-embed-text - Document vectorization
- **API**: Local REST API at `http://localhost:11434`

### 2. **ChromaDB (Vector Database)**
- **Version**: 0.6.1 (stable with v1 API)
- **Purpose**: Stores document embeddings for semantic search
- **Access**: REST API at `http://localhost:8000`
- **API Version**: v1 endpoints (`/api/v1/`)
- **Persistence**: Data saved in `chromadb/data/`

### 3. **N8N (Workflow Automation)**
- **Purpose**: Orchestrates the entire RAG pipeline
- **Workflows**: Import from `/n8n-templates/` directory
  - `document-indexer-local.json` - Scans and indexes local/mapped drives
  - `qa-system-local.json` - Handles user queries
  - `initialize-chromadb-local.json` - Database initialization

### 4. **Local File System**
- **G: Drive**: Mapped network drive or local folder
- **File Types**: PDF, DOCX, TXT, MD files
- **Permissions**: Read access to target folders
- **No Authentication**: Direct file system access

## 📚 N8N Workflow Templates

### Importing Workflows

1. Open N8N at http://localhost:5678
2. Go to Workflows → Import from File
3. Import templates in this order:
   - `/n8n-templates/initialize-chromadb-local.json` (run once)
   - `/n8n-templates/document-indexer-local.json`
   - `/n8n-templates/qa-system-local.json`

### Configuring the Indexer

1. Open the "Local Drive Document Indexer" workflow
2. Edit the "Scan Local Files" node
3. Modify the configuration:
   ```javascript
   const config = {
     basePath: 'G:\\',  // Your drive or folder
     subdirectories: [],  // Optional: specific folders like ['Policies', 'Procedures']
     includePatterns: ['*.pdf', '*.docx', '*.txt', '*.md'],
     maxFileSizeMB: 50
   };
   ```
4. Save and activate the workflow

### Workflow 1: Document Indexing
```
Local File System → Read Files → Extract Text → Chunk Text → Generate Embeddings → Store in ChromaDB
```

### Workflow 2: Question Answering
```
User Question → Generate Embedding → Search ChromaDB → Retrieve Documents → Build Context → Generate Answer → Return Response
```

## 🎓 Workshop Agenda - 9 Sept 2025

### Welcome & Introduction (10 min)
- Oz' AI Workshop Series overview
- Today's objectives
- Architecture walkthrough

### Module 1: Environment Setup (20 min)
- Run installation scripts
- Verify all services
- Quick troubleshooting

### Module 2: N8N Fundamentals (30 min)
- N8N interface tour
- Import workflow templates
- Configure local drive paths
- Test file access

### Module 3: Document Processing Pipeline (30 min)
- Understanding the indexing workflow
- File scanning and filtering
- Text extraction and chunking
- Embedding generation with Ollama

### Module 4: RAG Implementation (30 min)
- Query processing workflow
- Vector search mechanics
- Context building and LLM integration

### Break (10 min)

### Module 5: Hands-On Practice (40 min)
- Configure your local drive path
- Index your own documents
- Test various queries
- Optimize retrieval parameters

### Module 6: Advanced Topics (30 min)
- Handling different file types
- Metadata filtering
- Performance optimization
- Production considerations

### Q&A & Wrap-up (20 min)
- Open discussion
- Resources for continued learning
- Next workshop preview

## 🛠️ Container Management

### Using the Management Script
```powershell
# All commands use the script in /scripts/
.\scripts\manage-containers.ps1 -Action [command]

# Available commands:
.\scripts\manage-containers.ps1 -Action start    # Start containers
.\scripts\manage-containers.ps1 -Action stop     # Stop containers
.\scripts\manage-containers.ps1 -Action restart  # Restart containers
.\scripts\manage-containers.ps1 -Action status   # Check status
.\scripts\manage-containers.ps1 -Action logs     # View logs
.\scripts\manage-containers.ps1 -Action backup   # Backup data
```

## 📊 Testing Your System

### 1. **Verify Services**
```powershell
# Check Ollama
ollama list

# Check ChromaDB
curl http://localhost:8000/api/v1/heartbeat

# Check N8N
curl http://localhost:5678

# Check local drive access
Get-ChildItem "G:\" -File -Include *.pdf,*.docx,*.txt -Recurse | Select-Object -First 5
```

### 2. **Test Document Indexing**
1. Open N8N workflow "Local Drive Document Indexer"
2. Click "Execute Workflow" to run manually
3. Check execution log for indexed files
4. Verify documents stored in ChromaDB

### 3. **Test Q&A Interface**
- Open `c:\dev\workshop\test\qa-interface-local.html` in browser
- The interface shows service status for all components
- Try sample questions:
  - "What is our remote work policy?"
  - "How do I submit an expense report?"
  - "What are the company values?"

### 4. **Sample Test Questions**
- Policy Questions: "What is the vacation policy?"
- Process Questions: "How do I request IT support?"
- Information Queries: "Who is the HR contact?"
- Document Search: "Find information about project deadlines"

## 🔐 Security Considerations

### Data Protection
- ✅ All processing happens locally
- ✅ No external API calls or cloud services
- ✅ Direct file system access only
- ✅ Data never leaves your network
- ✅ Works within existing file permissions

### Best Practices
1. **File Access**: Only grant read access to necessary folders
2. **Network Drives**: Use read-only mounts when possible
3. **Audit Logging**: Track all queries and access
4. **Data Retention**: Set policies for re-indexing
5. **Container Security**: Keep images updated

## 📈 Performance Optimization

### File Scanning
- **Selective Folders**: Index only relevant directories
- **File Size Limits**: Skip very large files (>50MB)
- **File Type Filtering**: Only index supported formats
- **Incremental Updates**: Track modified dates

### Processing Settings
- **Chunk Size**: 1000 characters with 200 overlap
- **Batch Processing**: 10 files at a time
- **Embedding Cache**: Reuse embeddings for unchanged files
- **Vector Search**: Top 5 results
- **LLM Temperature**: 0.3 for factual responses

## 🎯 Learning Objectives

By the end of this workshop, participants will be able to:
1. ✅ Build a complete RAG system using local files
2. ✅ Configure N8N workflows for document processing
3. ✅ Implement semantic search with vector databases
4. ✅ Create intelligent Q&A systems with local LLMs
5. ✅ Deploy production-ready workflow automation
6. ✅ Ensure data security with 100% local processing

## 🆚 Why Local File Indexing?

### Advantages over Cloud APIs
- **No Authentication Complexity**: Skip OAuth, tokens, and API setup
- **Immediate Start**: Begin indexing right away
- **Corporate Compliance**: Data never leaves your network
- **Cost Effective**: No API rate limits or usage fees
- **Full Control**: Complete ownership of your data pipeline
- **Offline Capable**: Works without internet connection

### Perfect for Corporate Environments
- Works with existing network drives
- Respects current file permissions
- No cloud service agreements needed
- IT department approved approach
- Integrates with existing backup systems

## 🙏 Acknowledgments

- **Ollama** - Local LLM runtime
- **N8N** - Workflow automation platform
- **ChromaDB** - Vector database
- **Llama 3.2** - Meta's language model

## 📞 Workshop Support

- **During Workshop**: Ask Oz directly
- **Post-Workshop Issues**: Create an issue in this repository
- **N8N Community**: https://community.n8n.io
- **Ollama Support**: https://github.com/ollama/ollama
- **ChromaDB Docs**: https://docs.trychroma.com

## 📚 Additional Resources

- [N8N Documentation](https://docs.n8n.io)
- [Ollama Model Library](https://ollama.com/library)
- [ChromaDB Documentation](https://docs.trychroma.com)
- [RAG Techniques Guide](https://www.pinecone.io/learn/retrieval-augmented-generation/)

## 🚨 Common Issues & Quick Fixes

### Can't Access G: Drive
```powershell
# Verify drive is mapped
Get-PSDrive G

# Use alternative local folder
.\scripts\setup-containers.ps1 -LocalDrivePath "C:\Documents"
```

### Slow Indexing
- Reduce file size limit in workflow
- Index specific folders only
- Use smaller chunk sizes

### No Results from Q&A
- Check if indexing completed successfully
- Verify ChromaDB has documents
- Try broader search terms

---

### 🚀 Oz' AI Workshop Series

This workshop is part of Oz' AI Workshop Series, bringing practical AI implementations to enterprise environments with a focus on security and local processing.

**Workshop Focus**: Building production-ready RAG systems without cloud dependencies

**Next Workshop**: Advanced N8N Automations with Multi-Agent Systems

---

**Ready to start?** Follow the [Setup Guide](SETUP_GUIDE.md) or run `.\scripts\install-prerequisites.ps1` to begin! 🚀

**No authentication needed - just point to your files and start building!**