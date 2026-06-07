# text-to-sparql

This repository contains the Q2Forge frontend and the Gen2KGBot backend for text-to-SPARQL workflows.

## Repository layout

- `gen2kgbot/`: FastAPI backend, KG preprocessing, scenario logic
- `q2forge/`: Angular frontend
- `docs/`: developer, deployment, evaluator, and user guides
- `scripts/predeploy-precheck.sh`: local stack smoke test
- `.env.example`: Compose-oriented environment template

## Run locally without Docker

The steps below run the repo directly on your machine. They do not use `docker compose`.

### 1. Prerequisites

Install these first:

- MongoDB
- Conda or Micromamba
- Node.js and npm
- Ollama, or a reachable remote Ollama/vLLM endpoint

You will also need network access to the SPARQL endpoints referenced by the active KG configuration.

### 2. Create a local `.env`

Copy the example file:

```bash
cp .env.example .env
```

Then edit `.env`.

Important:

- `.env.example` is written for Docker Compose.
- For a direct local run, `MONGODB_CONNECTION_STRING` must use `localhost`, not `mongodb`.

Recommended local values:

```env
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=admin
MONGODB_CONNECTION_STRING=mongodb://admin:admin@localhost:27017/?authSource=admin

Q2FORGE_SECRET_KEY=replace-this-with-a-random-secret

OLLAMA_HOST=http://127.0.0.1:11434
OLLAMA_BASE_URL=http://127.0.0.1:11434
OPENAI_BASE_URL=http://127.0.0.1:11434/v1

LLM_MODEL=llama3.2:1b
EMBEDDING_MODEL=nomic-embed-text:latest
OLLAMA_MODEL=llama3.2:1b
OLLAMA_EMBED_MODEL=nomic-embed-text:latest

FRONTEND_PORT=4200
BACKEND_PORT=8003
MONGODB_PORT=27017

LANGCHAIN_API_KEY=
OPENAI_API_KEY=ollama
OVHCLOUD_API_KEY=
HF_TOKEN=
GOOGLE_API_KEY=
DEEPSEEK_API_KEY=
```

If you use a remote Ollama instance through an SSH tunnel, keep these values pointed at the local forwarded port, for example `http://127.0.0.1:11434`.

If you use a remote OpenAI-compatible endpoint for both chat and embeddings, set the bearer token in `OPENAI_API_KEY`. You can also set a shared fallback base URL:

```env
OPENAI_API_KEY=sk-local-vllm
OPENAI_BASE_URL=http://127.0.0.1:18000/v1
```

Use `OPENAI_BASE_URL` only when the chat and embedding endpoints share the same `/v1` base. If they are exposed on different ports, define `base_url` per model in the YAML config instead.

### 3. Export the variables into your current shell

Do not run `bash .env`. That starts a subshell and does not keep the variables in your current terminal.

Use:

```bash
set -a
source .env
set +a
```

Run that in every shell where you want to start the backend or helper scripts.

### 4. Start MongoDB

Make sure MongoDB is running on `localhost:27017`.

Quick check:

```bash
mongosh --eval "db.adminCommand({ ping: 1 })"
```

If that fails, start MongoDB with whatever method your OS uses before continuing.

### 5. Create the backend environment

From `gen2kgbot/`:

```bash
cd gen2kgbot
micromamba create -f environment.yml
micromamba activate gen2kgbot
```

If you use Conda instead:

```bash
cd gen2kgbot
conda env create -f environment.yml
conda activate gen2kgbot
```

### 6. Initialize the database

Still from `gen2kgbot/`:

```bash
python -m setup_db.init_db
```

This seeds the database with the default admin user and starter configuration.

Default credentials after initialization:

- username: `admin`
- password: `admin`

### 7. Start the backend

From `gen2kgbot/`:

```bash
uvicorn app.api.q2forge_api:app --host 127.0.0.1 --port 8003 --reload
```

Useful URLs:

- API docs: `http://localhost:8003/api/q2forge/docs`
- OpenAPI: `http://localhost:8003/api/q2forge/openapi.json`

Note:

- the frontend local constants point to `http://localhost:8003`
- if your browser shows login/network errors while the backend is up, check whether `localhost` vs `127.0.0.1` resolution is the issue in `q2forge/src/app/services/predefined-variables.ts`

### 8. Start the frontend

Open a second terminal, load the same `.env`, then run:

```bash
cd q2forge
npm ci
npm start
```

The Angular dev server will be available at:

- `http://localhost:4200`

### 9. Optional: use a remote Ollama host through SSH

If Ollama runs on another machine, create a local forward before starting the backend.

Generic example:

```bash
ssh -N -L 11434:127.0.0.1:11434 user@remote-host
```

If you already have an SSH alias such as `omen-ollama`, start that alias instead.

After the tunnel is up, keep the `.env` values pointing to:

```env
OLLAMA_HOST=http://127.0.0.1:11434
OLLAMA_BASE_URL=http://127.0.0.1:11434
OPENAI_BASE_URL=http://127.0.0.1:11434/v1
```

### 9.1 Optional: use remote OpenAI-compatible or vLLM endpoints

The backend can also use remote OpenAI-compatible chat and embedding servers, including vLLM-style `/v1` endpoints.

For the Weimar gammaweb vLLM services, chat and embeddings are exposed on different ports:

- chat completions: `http://gammaweb07.medien.uni-weimar.de:8000/v1`
- embeddings: `http://gammaweb07.medien.uni-weimar.de:8001/v1`

First verify both OpenAI-compatible endpoints directly:

```bash
curl http://gammaweb07.medien.uni-weimar.de:8001/v1/embeddings \
  -H 'Authorization: Bearer sk-local-vllm' \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen-embed","input":"GraphRAG query to knowledge graph retrieval"}'
```

```bash
curl http://gammaweb07.medien.uni-weimar.de:8000/v1/chat/completions \
  -H 'Authorization: Bearer sk-local-vllm' \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen-chat","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":64}'
```

Then set the shared bearer token in your shell or `.env`:

```env
OPENAI_API_KEY=sk-local-vllm
```

Because these services use separate ports, define `base_url` per model in your KG config file, for example `gen2kgbot/config/params.yml` or a copied variant:

```yaml
seq2seq_models:
  qwen-chat@remote:
    server_type: openai
    id: qwen-chat
    base_url: http://gammaweb07.medien.uni-weimar.de:8000/v1
    temperature: 0
    max_retries: 3
    top_p: 0.95

text_embedding_models:
  qwen-embed_faiss@remote:
    server_type: openai-embeddings
    id: qwen-embed
    base_url: http://gammaweb07.medien.uni-weimar.de:8001/v1
    vector_db: faiss
```

Then point the scenarios to those model names:

```yaml
scenario_3:
  validate_question: qwen-chat@remote
  generate_query: qwen-chat@remote
  interpret_results: qwen-chat@remote
  text_embedding_model: qwen-embed_faiss@remote
```

If the remote servers are not directly reachable from your machine, tunnel them first:

```bash
ssh -N \
  -L 18000:127.0.0.1:8000 \
  -L 18001:127.0.0.1:8001 \
  gammaweb07
```

Then use the tunneled URLs in the config instead:

```yaml
seq2seq_models:
  qwen-chat@remote:
    server_type: openai
    id: qwen-chat
    base_url: http://127.0.0.1:18000/v1

text_embedding_models:
  qwen-embed_faiss@remote:
    server_type: openai-embeddings
    id: qwen-embed
    base_url: http://127.0.0.1:18001/v1
    vector_db: faiss
```

### 10. Run the local precheck

Once MongoDB, the backend, the frontend, and Ollama are available:

```bash
./scripts/predeploy-precheck.sh
```

Useful subsets:

```bash
./scripts/predeploy-precheck.sh --setup-only
./scripts/predeploy-precheck.sh --api-only
./scripts/predeploy-precheck.sh --ollama-only
```

## Common local pitfalls

### `bash .env`

This does not export variables into your current shell. Use `source .env` with `set -a`.

### `MONGODB_CONNECTION_STRING` still points to `mongodb`

That hostname only works inside Docker Compose. For a direct local run, use `localhost`.

### Login fails with `Http failure response ... 0 Unknown Error`

That usually means the browser could not reach the backend at all. Check:

- backend is listening on port `8003`
- frontend is calling the correct host
- `localhost` vs `127.0.0.1` is not mismatched

### Port `11434` is reachable in the precheck but not in the backend

Make sure the shell that starts the backend has the same exported `.env` values as the shell where you tested the tunnel.

## Additional docs

- [docs/README.md](docs/README.md)
- [docs/developer-guide.md](docs/developer-guide.md)
- [docs/deployment-and-operations-guide.md](docs/deployment-and-operations-guide.md)
- [gen2kgbot/README.md](gen2kgbot/README.md)
- [q2forge/README.md](q2forge/README.md)
