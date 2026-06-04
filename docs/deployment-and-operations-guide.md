# Deployment and Operations Guide

## 1. Purpose of this guide

This guide is for the person operating the system.

It focuses on:

- Docker Compose deployment
- service topology
- environment variables
- persistent data
- startup, shutdown, reset, and update procedures
- runtime troubleshooting

This repo already includes a working containerized topology, so the shortest path is to use the shipped `docker-compose.yml`.

## 2. Runtime topology

The compose stack defines four services:

| Service | Role | Notes |
|---|---|---|
| `mongodb` | persistent database | stores users and KG configurations |
| `backend-init` | one-shot initialization job | seeds MongoDB and copies default data into the backend data volume |
| `backend` | FastAPI application | serves `/api/q2forge/...` |
| `frontend` | static Angular app via nginx | serves the UI and proxies API requests through nginx config |

Persistent volumes:

| Volume | Purpose |
|---|---|
| `mongodb-data` | MongoDB database files |
| `backend-data` | copied default KG data, embeddings, and generated runtime data |

## 3. External dependencies

The stack assumes at least one model provider is available.

By default, the repository treats Ollama as a host dependency rather than a containerized compose service. The compose file expects the backend container to reach Ollama through:

- `http://host.docker.internal:11434`

If you keep the default local-model setup, verify the host can answer:

```bash
curl http://localhost:11434/api/chat \
  -d '{"model":"llama3.2:1b","messages":[{"role":"user","content":"hello"}],"stream":false}'

curl http://localhost:11434/api/embeddings \
  -d '{"model":"nomic-embed-text","prompt":"hello"}'
```

You can also point the backend to remote providers by setting the relevant API keys and base URLs.

## 4. Environment variables

The root `.env.example` documents the compose-time variables currently expected by the stack.

Important groups:

### 4.1 MongoDB

- `MONGO_INITDB_ROOT_USERNAME`
- `MONGO_INITDB_ROOT_PASSWORD`
- `MONGODB_CONNECTION_STRING`
- `MONGODB_PORT`

### 4.2 Backend auth and application identity

- `Q2FORGE_SECRET_KEY`

This signs JWT tokens and should be replaced before anything beyond disposable local use.

### 4.3 Local model host wiring

- `OLLAMA_HOST`
- `OLLAMA_BASE_URL`
- `OPENAI_BASE_URL`
- `LLM_MODEL`
- `EMBEDDING_MODEL`
- `OLLAMA_MODEL`
- `OLLAMA_EMBED_MODEL`

These variables support the default local-model path. Depending on your backend configuration, not every variable is used directly in every request path, but they are relevant defaults.

### 4.4 Exposed ports

- `FRONTEND_PORT`
- `BACKEND_PORT`

Default public URLs in the compose setup are:

- frontend: `http://localhost:4200`
- backend API docs: `http://localhost:8003/api/q2forge/docs`
- proxied API docs through frontend host: `http://localhost:4200/api/q2forge/docs`

### 4.5 Remote provider credentials

- `LANGCHAIN_API_KEY`
- `OPENAI_API_KEY`
- `OVHCLOUD_API_KEY`
- `HF_TOKEN`
- `GOOGLE_API_KEY`
- `DEEPSEEK_API_KEY`

Set only what your selected models require.

## 5. First-time deployment

## 5.1 Prepare the environment file

From the repo root:

```bash
cp .env.example .env
```

Then edit `.env` and replace at least:

- `Q2FORGE_SECRET_KEY`
- any API keys you plan to use
- port overrides if the defaults conflict locally

For anything other than local experimentation, also review:

- MongoDB credentials
- exposed ports
- model endpoints

## 5.2 Pull the default Ollama models

If you follow the local-Ollama path:

```bash
ollama pull llama3.2:1b
ollama pull nomic-embed-text
```

If you plan to use a different local model inventory, update configuration defaults and environment variables accordingly.

## 5.3 Start the stack

From the repo root:

```bash
docker compose up --build
```

What happens in order:

1. MongoDB starts.
2. `backend-init` waits for MongoDB to become healthy.
3. `backend-init` runs `python -m setup_db.init_db`.
4. That initialization job creates the seed collections if needed and copies `gen2kgbot/setup_db/data` into the runtime data volume.
5. The backend starts after the init job completes successfully.
6. The frontend starts after the backend health check passes.

## 5.4 Validate the deployment

Check these URLs:

- `http://localhost:4200`
- `http://localhost:4200/api/q2forge/docs`
- `http://localhost:8003/api/q2forge/docs`

Default seeded credentials:

- username: `admin`
- password: `admin`

If the frontend loads but API routes fail, the frontend service may be healthy while the backend is not actually serving requests correctly. Check backend logs directly.

## 6. Seeded data and initialization behavior

The initialization step does two important things:

### 6.1 Seeds MongoDB

It creates at least:

- a default `admin` user
- a default `d2kab` configuration

### 6.2 Copies default runtime data

It copies:

- `gen2kgbot/setup_db/data/...`

into the runtime `data` directory backed by the `backend-data` volume.

This is important because retrieval-based scenarios depend on those assets already existing for the seeded KG.

## 7. Day-2 operations

## 7.1 Start in detached mode

```bash
docker compose up -d
```

## 7.2 Stop services but keep data

```bash
docker compose down
```

## 7.3 Stop services and remove volumes

```bash
docker compose down -v
```

Use `-v` only when you intentionally want to remove:

- MongoDB contents
- copied backend data and generated embeddings

This is the fastest way to reset the environment, but it is destructive.

## 7.4 Restart after code changes

```bash
docker compose up --build -d
```

If only one service changed, you can target it, but for this stack a full rebuild is often simpler.

## 8. Backups and recovery

At minimum, preserve:

- `mongodb-data`
- `backend-data`

If you lose `mongodb-data`, you lose:

- users
- chat history
- active configuration assignments
- newly created shared configurations

If you lose `backend-data`, you lose:

- copied seed assets
- generated descriptions
- generated embeddings
- example query files written during config creation

A practical backup policy is:

1. snapshot MongoDB data regularly
2. snapshot backend data when significant preprocessing has been done
3. keep the repo itself under version control separately from runtime data

## 9. Security considerations

This stack is suitable for local, lab, or controlled deployment. It is not hardened by default.

Immediate issues to address before broader exposure:

- default `admin/admin` credentials
- default JWT signing secret
- wildcard CORS policy in the backend
- no role-based access control
- ordinary users can create shared configurations
- chat history and configs are not designed for sensitive data

Minimum hardening checklist:

1. replace `Q2FORGE_SECRET_KEY`
2. replace the default admin password or recreate the user set
3. avoid exposing the stack directly to the public internet
4. put it behind a controlled reverse proxy if needed
5. restrict network reachability of MongoDB
6. review whether remote provider API keys are mounted only where needed

## 10. Ports, routing, and URL behavior

Current compose defaults:

- MongoDB host port: `27017`
- backend host port: `8003`
- frontend host port: `4200`

The frontend container serves static assets through nginx. The backend serves FastAPI on container port `8000`, mapped to host port `8003` by default.

The frontend docker build uses the Docker-specific endpoint constant file, where the API base is relative:

- `/api/q2forge`

This is why accessing the frontend on `4200` is typically sufficient for a normal browser session.

## 11. Health checks and readiness

Built-in health logic:

- MongoDB: `db.adminCommand('ping').ok`
- backend: HTTP fetch of `/api/q2forge/openapi.json`
- frontend: starts only after backend health passes

This gives acceptable startup sequencing for local deployment, but it does not replace application-level smoke testing.

## 12. Logs and observability

Useful commands:

```bash
docker compose logs -f
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f mongodb
docker compose logs -f backend-init
```

Backend logs may also be written inside the container according to `gen2kgbot/config/logging.yml`.

When debugging:

- inspect `backend-init` first if the backend never starts
- inspect `backend` if auth or workflow calls fail
- inspect `frontend` if the UI is blank or routes do not load

## 13. Common operational problems

### 13.1 Backend init fails

Likely causes:

- MongoDB is not reachable
- the connection string is wrong
- the data volume permissions are problematic

What to check:

- `docker compose logs backend-init`
- resolved `MONGODB_CONNECTION_STRING`
- whether the `backend-data` volume is writable

### 13.2 Backend starts, but generation requests fail

Likely causes:

- Ollama is not reachable from the container
- remote provider key is missing
- selected models do not match the available provider inventory
- KG endpoint is unavailable

What to check:

- backend logs
- `OLLAMA_HOST` and `OPENAI_BASE_URL`
- outbound connectivity to the configured SPARQL endpoint
- whether the active KG has already been preprocessed

### 13.3 Frontend loads, but login or API calls fail

Likely causes:

- backend not healthy
- JWT secret mismatch after partial restart
- reverse-proxy path mismatch

What to check:

- direct backend docs on `8003`
- browser dev tools network requests
- backend logs for `401`, `403`, or `500`

### 13.4 Users see `403 Forbidden`

Likely causes:

- the relevant quota reached zero

What to check:

- current user document in MongoDB
- whether you need to top up quota values manually for local usage

### 13.5 Results are poor after deployment appears healthy

Likely causes:

- the KG config is weak or incomplete
- preprocessing was skipped
- default models are too small for the target KG

What to do:

- confirm the active configuration
- rerun KG descriptions and embeddings
- adjust model assignments

## 14. Recommended operator runbook

For a clean local or lab deployment:

1. copy `.env.example` to `.env`
2. replace secrets and credentials
3. ensure Ollama or remote providers are reachable
4. `docker compose up --build -d`
5. verify frontend and API docs
6. log in as admin
7. verify the seeded `d2kab` configuration works
8. create a non-default user if needed
9. test one full preprocessing and query workflow
10. snapshot volumes once the environment is in a good state

That is the baseline operating posture for this repo.
