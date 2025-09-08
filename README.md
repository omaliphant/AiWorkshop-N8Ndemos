# Oz' AI Workshop - N8N RAG Demo
## 9 September 2025 - N8N with Ollama & Google Drive

## 🎯 Overview

This workshop is part of **Oz' AI Workshop Series** and teaches participants how to build a **Retrieval-Augmented Generation (RAG)** system using N8N workflow automation, Google Drive documents, and local LLMs via Ollama. Perfect for corporate environments where data security is paramount - everything runs locally on your machine!

### What You'll Build
- 📚 **Document Indexing System**: Automatically processes and indexes Google Drive documents
- 🤖 **Intelligent Q&A Bot**: Answers questions about your company documents using AI
- 🔒 **Fully Local Processing**: No data leaves your machine - uses Ollama with Llama 3.2
- 🔄 **Automated Workflows**: N8N orchestrates the entire pipeline

### Key Features
- ✅ **100% Local Processing** - No external API calls
- ✅ **Google Drive Integration** - Works with your existing documents
- ✅ **Vector Search** - ChromaDB for intelligent document retrieval
- ✅ **Production Ready** - Includes error handling, logging, and monitoring
- ✅ **Easy Setup** - Automated installation scripts for Windows

## 📋 Prerequisites

### System Requirements
- **OS**: Windows 10/11 (64-bit) or macOS or Linux
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: 20GB free space
- **CPU**: Modern multi-core processor (4+ cores recommended)

### Software Requirements
- **Docker Desktop** (will be guided through installation)
- **PowerShell 5.1+** (Windows) or Terminal (macOS/Linux)
- **Google Account** with Drive access
- **Administrator privileges** for installation

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
   ```

3. **Access the Applications**
   - N8N Interface: http://localhost:5678
   - ChromaDB API: http://localhost:8000
   - Test Interface: `c:\dev\workshop\test\qa-interface.html`

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
│   ├── document-indexer.json        # Workflow 1: GDrive indexing
│   ├── qa-system.json               # Workflow 2: Q&A processing
│   └── initialize-chromadb.json     # Workflow 3: DB initialization
├── test/
│   └── qa-interface.html            # Web UI for testing
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
│   └── qa-interface.html      # Web UI for testing
├── downloads/          # Temporary downloads
└── models/            # Ollama model cache
```

## 🔧 Workshop Components

### 1. **Ollama (Local LLM)**
- **Model**: Llama 3.2 3B - Fast, efficient text generation
- **Embeddings**: Nomic-embed-text - Document vectorization
- **API**: Local REST API at `http://localhost:11434`

### 2. **ChromaDB (Vector Database)**
- **Purpose**: Stores document embeddings for semantic search
- **Access**: REST API at `http://localhost:8000`
- **Persistence**: Data saved in `chromadb/data/`

### 3. **N8N (Workflow Automation)**
- **Purpose**: Orchestrates the entire RAG pipeline
- **Workflows**: Import from `/n8n-templates/` directory
  - `document-indexer.json` - Processes Google Drive files
  - `qa-system.json` - Handles user queries
  - `initialize-chromadb.json` - Database initialization

### 4. **Google Drive Integration**
- **OAuth2**: Secure authentication
- **File Types**: PDF, DOCX, TXT, XLSX
- **Permissions**: Read-only access to specified folders

## 📚 N8N Workflow Templates

### Importing Workflows

1. Open N8N at http://localhost:5678
2. Go to Workflows → Import from File
3. Import templates in this order:
   - `/n8n-templates/initialize-chromadb.json` (run once)
   - `/n8n-templates/document-indexer.json`
   - `/n8n-templates/qa-system.json`

### Workflow 1: Document Indexing
```
Google Drive → Download Files → Extract Text → Chunk Text → Generate Embeddings → Store in ChromaDB
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
- Configure Google Drive OAuth

### Module 3: Document Processing Pipeline (30 min)
- Understanding the indexing workflow
- Text extraction and chunking
- Embedding generation with Ollama

### Module 4: RAG Implementation (30 min)
- Query processing workflow
- Vector search mechanics
- Context building and LLM integration

### Break (10 min)

### Module 5: Hands-On Practice (40 min)
- Index your own documents
- Test various queries
- Optimize retrieval parameters

### Module 6: Advanced Topics (30 min)
- Metadata filtering
- Access control patterns
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
```

### 2. **Test Q&A Interface**
- Open `c:\dev\workshop\test\qa-interface.html` in browser
- Ask: "What is our remote work policy?"
- Verify response includes sources

### 3. **Sample Test Questions**
- "What are the company's core values?"
- "How do I submit an expense report?"
- "What is the vacation policy?"
- "Who should I contact for IT support?"

## 🔐 Security Considerations

### Data Protection
- ✅ All processing happens locally
- ✅ No external API calls
- ✅ Data encrypted at rest (Docker volumes)
- ✅ OAuth2 for Google Drive access

### Best Practices
1. **Access Control**: Implement user authentication for production
2. **Audit Logging**: Track all queries and access
3. **Data Retention**: Set policies for document updates
4. **Network Security**: Use HTTPS in production
5. **Container Security**: Keep images updated

## 📈 Performance Optimization

### Recommended Settings
- **Chunk Size**: 1000 characters with 200 overlap
- **Embedding Batch**: 10 documents at a time
- **Vector Search**: Top 5 results
- **LLM Temperature**: 0.3 for factual responses
- **Cache Strategy**: Store frequently accessed embeddings

## 🎯 Learning Objectives

By the end of this workshop, participants will be able to:
1. ✅ Build a complete RAG system from scratch
2. ✅ Process and index documents automatically
3. ✅ Implement semantic search with vector databases
4. ✅ Create intelligent Q&A systems with local LLMs
5. ✅ Deploy production-ready workflow automation
6. ✅ Ensure data security with local processing

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

---

### 🚀 Oz' AI Workshop Series

This workshop is part of Oz' AI Workshop Series, bringing practical AI implementations to enterprise environments. 

---

**Ready to start?** Follow the [Setup Guide](SETUP_GUIDE.md) or run `.\scripts\install-prerequisites.ps1` to begin! 🚀