# SLURM GPU Runbook

This guide explains how to run the `text-to-sparql` stack on a SLURM GPU node, keep MongoDB local to the job, use the remote Webis vLLM endpoints for chat and embeddings, and expose the UI and API back to your laptop for a demo.

The instructions assume:

- repository path on the cluster: `~/thesis/text-to-sparql`
- backend Conda/Micromamba environment name: `gen2kgbot`
- remote chat endpoint: `http://gammaweb07.medien.uni-weimar.de:8000/v1`
- remote embedding endpoint: `http://gammaweb07.medien.uni-weimar.de:8001/v1`
- reverse tunnel relay host: `ssh.webis.de`

## Architecture

During the demo, the system is split across three layers:

1. SLURM GPU node
   Runs:
   - local `mongod`
   - FastAPI backend on `127.0.0.1:8003`
   - Angular frontend on `127.0.0.1:4200`

2. Shared remote model host
   Runs:
   - `qwen-chat` on `gammaweb07.medien.uni-weimar.de:8000`
   - `qwen-embed` on `gammaweb07.medien.uni-weimar.de:8001`

3. Laptop
   Connects through:
   - reverse tunnels from the SLURM node to `ssh.webis.de`
   - local forwards from the laptop to `ssh.webis.de`

## 1. Start a GPU job

Request an interactive job on a GPU node. Adjust partition, memory, time, and GPU count for your cluster.

```bash
srun --pty --partition=gpu --gres=gpu:1 --cpus-per-task=8 --mem=32G --time=08:00:00 zsh -l
```

Confirm the allocation:

```bash
hostname
echo "$SLURM_JOB_ID"
```

## 2. Activate Micromamba cleanly in `zsh`

If `micromamba activate` does not work in a fresh SLURM shell, initialize the shell hook first:

```bash
eval "$(micromamba shell hook --shell zsh)"
micromamba activate gen2kgbot
```

If you use Conda instead:

```bash
source ~/miniconda3/etc/profile.d/conda.sh
conda activate gen2kgbot
```

## 3. Ensure MongoDB server binaries are available

You need the `mongod` server binary, not only `mongosh`.

Check:

```bash
command -v mongod
command -v mongosh
```

If `mongod` is not on `PATH`, either load a cluster module or export the path to your unpacked MongoDB server tarball, for example:

```bash
export PATH="$HOME/tmp/mongodb-linux-x86_64-ubuntu2204-7.0.14/bin:$PATH"
```

Verify again:

```bash
command -v mongod
```

## 4. Start MongoDB inside the SLURM job

Create job-local storage:

```bash
mkdir -p "$TMPDIR/mongodb/db" "$TMPDIR/mongodb/log"
```

Start MongoDB bound only to loopback:

```bash
mongod \
  --dbpath "$TMPDIR/mongodb/db" \
  --bind_ip 127.0.0.1 \
  --port 27017 \
  --logpath "$TMPDIR/mongodb/log/mongod.log" \
  --fork
```

Verify:

```bash
mongosh --host 127.0.0.1 --port 27017 --eval "db.adminCommand({ ping: 1 })"
```

Expected:

```bash
{ ok: 1 }
```

## 5. Prepare `.env` for SLURM-local MongoDB and remote vLLM

From the repo root:

```bash
cd ~/thesis/text-to-sparql
cp .env.example .env
```

Use these values for the SLURM job:

```env
MONGODB_CONNECTION_STRING=mongodb://127.0.0.1:27017/
Q2FORGE_SECRET_KEY=replace-this-with-a-random-secret

OPENAI_API_KEY=sk-local-vllm
OPENAI_BASE_URL=

OLLAMA_HOST=
OLLAMA_BASE_URL=

LLM_MODEL=qwen-chat
EMBEDDING_MODEL=qwen-embed

FRONTEND_PORT=4200
BACKEND_PORT=8003
MONGODB_PORT=27017
```

Important:

- keep MongoDB unauthenticated for the job-local demo unless you explicitly configure Mongo auth
- leave `OPENAI_BASE_URL` empty when chat and embedding models live on different ports
- the actual per-model URLs are defined in the YAML config files such as `gen2kgbot/config/params.yml` and `gen2kgbot/config/params_dblp.yml`

Load the file into the current shell:

```bash
set -a
source .env
set +a
```

Verify:

```bash
echo "$MONGODB_CONNECTION_STRING"
echo "$OPENAI_API_KEY"
```

## 6. Verify remote vLLM endpoints

Before starting the backend, verify both remote services directly from the GPU node:

```bash
curl http://gammaweb07.medien.uni-weimar.de:8000/v1/chat/completions \
  -H 'Authorization: Bearer sk-local-vllm' \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen-chat","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":64}'
```

```bash
curl http://gammaweb07.medien.uni-weimar.de:8001/v1/embeddings \
  -H 'Authorization: Bearer sk-local-vllm' \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen-embed","input":"GraphRAG query to knowledge graph retrieval"}'
```

If both return JSON, the model layer is ready.

## 7. Initialize the database and import file-backed configs

Run:

```bash
cd ~/thesis/text-to-sparql/gen2kgbot
python -m setup_db.init_db
```

This now does all of the following:

- seeds the `users` collection
- seeds the default configuration data
- skips the redundant copy when `data/` already points to `setup_db/data`
- imports file-backed configs such as `config/params_dblp.yml` into MongoDB

Check the available configuration short names:

```bash
mongosh "$MONGODB_CONNECTION_STRING" --eval 'db.getSiblingDB("q2forge").configurations.find({}, {kg_short_name:1,_id:0}).toArray()'
```

## 8. Backend configuration to use

For the current setup, the key remote model definitions already exist in:

- [gen2kgbot/config/params.yml](/home/prims/Projects/thesis/git_clones/text-to-sparql/gen2kgbot/config/params.yml)
- [gen2kgbot/config/params_dblp.yml](/home/prims/Projects/thesis/git_clones/text-to-sparql/gen2kgbot/config/params_dblp.yml)

The relevant model ids are:

- `qwen-chat@remote`
- `qwen-embed_faiss@remote`

## 9. Start the backend

From `gen2kgbot/`:

```bash
cd ~/thesis/text-to-sparql
set -a
source .env
set +a

cd gen2kgbot
uvicorn app.api.q2forge_api:app --host 127.0.0.1 --port 8003 --log-level debug
```

Verify from another shell on the same node:

```bash
curl http://127.0.0.1:8003/api/q2forge/openapi.json
curl -X POST http://127.0.0.1:8003/api/q2forge/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data 'username=admin&password=admin'
```

## 10. Start the frontend

In another shell on the same node:

```bash
cd ~/thesis/text-to-sparql
set -a
source .env
set +a

cd q2forge
npm ci
npm start
```

The frontend runs on:

- `http://127.0.0.1:4200`

The frontend source currently targets:

- `http://localhost:8003`

That is fine for the demo as long as the browser also reaches the tunneled backend on local port `8003`.

## 11. Publish the job ports through Webis SSH

On the SLURM node, keep this reverse tunnel running:

```bash
ssh -i ~/.ssh/id_ed25519_webis_tunnel -N -o ExitOnForwardFailure=yes \
  -R 14200:127.0.0.1:4200 \
  -R 18003:127.0.0.1:8003 \
  xepi3167@ssh.webis.de
```

This exposes:

- `ssh.webis.de:14200` -> SLURM node `127.0.0.1:4200`
- `ssh.webis.de:18003` -> SLURM node `127.0.0.1:8003`

## 12. Forward those ports to the laptop

On the laptop:

```bash
ssh -N \
  -L 4200:127.0.0.1:14200 \
  -L 8003:127.0.0.1:18003 \
  xepi3167@ssh.webis.de
```

After that:

- laptop browser `http://127.0.0.1:4200` -> frontend on the SLURM node
- laptop browser/API `http://127.0.0.1:8003` -> backend on the SLURM node

## 13. Demo-ready validation checklist

Run through this before presenting the system:

1. MongoDB responds locally on the SLURM node.
2. Remote `qwen-chat` and `qwen-embed` endpoints return valid JSON.
3. `uvicorn` is running and `openapi.json` is reachable.
4. `admin/admin` login works through `/api/q2forge/token`.
5. Frontend loads through the laptop tunnel.
6. Available configurations include the one you want to show, for example `dblp`.
7. The active configuration is correct.
8. Any required preprocessing artifacts already exist for the chosen KG.

## 14. Suggested demo flow

If you need to present the system to someone, this sequence is usually the cleanest:

1. Open the frontend on the laptop.
2. Log in as `admin`.
3. Show available configurations and activate `dblp` if needed.
4. Open the API docs briefly to show the backend contract.
5. Generate or show KG descriptions.
6. Generate or show embeddings readiness.
7. Ask a DBLP-style question such as:
   - papers by a specific author
   - authors who published in a venue in a given year
   - publications with a DOI or ORCID-linked author
8. Show the generated SPARQL.
9. Run refinement/judging if needed.

## 15. Common issues

### `mongod: command not found`

You installed `mongosh` only. You need the MongoDB server binary package that contains `mongod`.

### `MONGODB_CONNECTION_STRING` points to `mongodb`

That hostname is only valid in Docker Compose. On SLURM with local MongoDB, use:

```env
MONGODB_CONNECTION_STRING=mongodb://127.0.0.1:27017/
```

### Frontend shows `Http failure response ... 0 Unknown Error`

That means the browser is not reaching the backend. Recheck:

- reverse tunnel on the SLURM node
- local forward on the laptop
- backend actually listening on `127.0.0.1:8003`

### Signup returns `500 Internal Server Error`

Likely `bcrypt` mismatch in the local Python environment. Check:

```bash
python - <<'PY'
from app.api.services.auth import get_password_hash
print(get_password_hash("testpass1"))
PY
```

If needed:

```bash
pip install 'bcrypt<5'
```

### Uvicorn exits or hangs before binding

Use the exact startup command from this guide. If it still hangs, test the import path:

```bash
cd ~/thesis/text-to-sparql/gen2kgbot
python -X faulthandler -c "import app.api.q2forge_api; print('import ok')"
```

## 16. Shutdown

Stop the frontend and backend with `Ctrl+C` in their respective terminals.

Stop MongoDB:

```bash
mongosh --host 127.0.0.1 --port 27017 --eval "db.adminCommand({ shutdown: 1 })"
```

Or:

```bash
pkill -f "mongod.*27017"
```

Close the reverse and forward SSH tunnel sessions when the demo is over.
