#!/bin/bash

echo "Setting up RAG Workshop Environment..."

# Create necessary directories
echo "Creating directories..."
mkdir -p files
mkdir -p data/supabase
mkdir -p data/n8n
mkdir -p data/ollama

# Set proper permissions
echo "Setting permissions..."
chmod 755 files
chmod -R 755 data

# Start the services
echo "Starting Docker services..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 20

# Pull Ollama model
echo "Pulling Llama 3.2:3b model..."
docker exec ollama ollama pull llama3.2:3b

# Setup Supabase database with vector extension
echo "Setting up Supabase with vector extension..."
docker exec supabase-db psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Create documents table
echo "Creating documents table..."
docker exec supabase-db psql -U postgres -d postgres -c "
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    filename VARCHAR(255) NOT NULL,
    embedding vector(4096),
    chunk_index INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

# Create index for similarity search
docker exec supabase-db psql -U postgres -d postgres -c "
CREATE INDEX IF NOT EXISTS documents_embedding_idx ON documents 
USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);"

# Create similarity search function
docker exec supabase-db psql -U postgres -d postgres -c "
CREATE OR REPLACE FUNCTION similarity_search(
  query_embedding vector(4096),
  match_threshold float DEFAULT 0.8,
  match_count int DEFAULT 5
)
RETURNS TABLE(
  content text,
  filename varchar(255),
  chunk_index integer,
  similarity float
)
LANGUAGE sql
AS \$\$
  SELECT
    d.content,
    d.filename,
    d.chunk_index,
    1 - (d.embedding <=> query_embedding) as similarity
  FROM documents d
  WHERE 1 - (d.embedding <=> query_embedding) > match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
\$\$;"

echo "Setup complete!"
echo ""
echo "Access your services:"
echo "  - N8N: http://localhost:5678"
echo "  - Open WebUI: http://localhost:3001"
echo "  - Supabase API: http://localhost:3000"
echo ""
echo "Next steps:"
echo "  1. Import the N8N workflow template"
echo "  2. Drop files into the './files' directory"
echo "  3. Start chatting with your documents!"
echo ""
echo "To stop the environment: docker-compose down"