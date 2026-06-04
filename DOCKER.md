# Docker Deployment

This workspace is structured as a monorepo for deployment:

- `gen2kgbot/`: FastAPI backend
- `q2forge/`: Angular frontend
- `docker-compose.yml`: MongoDB, backend initialization, backend API, and frontend

Ollama is treated as a host dependency by default. Before starting compose, make sure these work on the host:

```sh
curl http://localhost:11434/api/chat -d '{"model":"llama3.2:1b","messages":[{"role":"user","content":"hello"}],"stream":false}'
curl http://localhost:11434/api/embeddings -d '{"model":"nomic-embed-text","prompt":"hello"}'
```

## Start

```sh
cp .env.example .env
docker compose up --build
```

Then open:

- Frontend: <http://localhost:4200>
- API docs: <http://localhost:4200/api/q2forge/docs>
- Direct backend: <http://localhost:8003/api/q2forge/docs>

The seeded default account is `admin` / `admin`.

## Ollama Models

Pull the default local models once:

```sh
ollama pull llama3.2:1b
ollama pull nomic-embed-text
```

You can also set API keys in `.env` and use backend configurations that target remote providers.

## Reset Data

To remove MongoDB data and copied embeddings:

```sh
docker compose down -v
```
