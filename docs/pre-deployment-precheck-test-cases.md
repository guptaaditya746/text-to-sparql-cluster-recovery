# Pre-Deployment Precheck Test Cases

## 1. Purpose

This document defines a small, repeatable pre-deployment check set for this repository.

It is focused on the three areas you asked for:

- setup readiness
- backend API access
- Ollama access

The intent is practical: before deploying or handing off the stack, someone should be able to run these checks and decide whether the environment is ready.

This repo now also includes a helper script:

- `scripts/predeploy-precheck.sh`

Use the script for fast validation, and use the test cases below as the formal checklist and expected-result definition.

## 2. Scope

These prechecks do not prove that the whole product is correct.

They only answer the narrow operational question:

- Is the environment set up correctly enough to proceed to deployment or smoke testing?

They are therefore a gate before broader testing, not a replacement for:

- end-to-end product walkthroughs
- benchmark evaluation
- security review

## 3. How to run the prechecks

From the repo root:

```bash
chmod +x scripts/predeploy-precheck.sh
./scripts/predeploy-precheck.sh
```

Optional targeted runs:

```bash
./scripts/predeploy-precheck.sh --setup-only
./scripts/predeploy-precheck.sh --api-only
./scripts/predeploy-precheck.sh --ollama-only
```

Optional authenticated API checks:

```bash
PRECHECK_USERNAME=admin PRECHECK_PASSWORD=admin ./scripts/predeploy-precheck.sh --api-only
```

Optional URL overrides:

```bash
BACKEND_URL=http://localhost:8003 \
FRONTEND_URL=http://localhost:4200 \
OLLAMA_URL=http://localhost:11434 \
./scripts/predeploy-precheck.sh
```

## 4. Preconditions

Before running the full precheck set:

- the repo should contain a valid `.env`
- Docker and Docker Compose should be installed
- the deployment host should be able to reach the intended Ollama host
- if API checks are expected to pass, the stack should already be started in the target environment

Important distinction:

- `setup` and some `Ollama` checks can be run before `docker compose up`
- `API` checks require the backend to be running

## 5. Test cases

## TC-SETUP-001: Environment file exists and can be loaded

### Objective

Verify that the deployment environment has a root `.env` file and that the precheck script can load it.

### Command

```bash
./scripts/predeploy-precheck.sh --setup-only
```

### Expected result

- `.env` exists at the repo root
- the script reports setup checks as loaded or passed

### Failure meaning

If this fails, the deployment is not ready. Compose values, ports, model URLs, or credentials are missing or ambiguous.

## TC-SETUP-002: Compose definition is valid

### Objective

Verify that `docker-compose.yml` is syntactically valid in the current environment.

### Command

```bash
./scripts/predeploy-precheck.sh --setup-only
```

### Expected result

- `docker compose config -q` succeeds

### Failure meaning

If this fails, deployment should stop immediately. The compose file or `.env` expansion is invalid.

## TC-SETUP-003: Required local tooling is available

### Objective

Verify that the host has the minimum local tools required for deployment prechecks.

### Command

```bash
./scripts/predeploy-precheck.sh --setup-only
```

### Expected result

- `docker` is installed
- `docker compose` is available
- `curl` is installed

### Failure meaning

The host is not ready for deployment validation.

## TC-SETUP-004: Required deployment files exist

### Objective

Verify that the repo contains the expected deployment artifacts.

### Command

```bash
./scripts/predeploy-precheck.sh --setup-only
```

### Expected result

- `docker-compose.yml` exists
- `gen2kgbot/Dockerfile` exists
- `q2forge/Dockerfile` exists

### Failure meaning

The checked-out workspace is incomplete or the deployment packaging has been broken.

## TC-API-001: Backend OpenAPI endpoint is reachable

### Objective

Verify that the backend is up and serving the API contract.

### Command

```bash
./scripts/predeploy-precheck.sh --api-only
```

### Expected result

- `GET /api/q2forge/openapi.json` returns success

### Failure meaning

The backend is not reachable, not healthy, or not exposed on the expected URL/port.

## TC-API-002: Backend docs endpoint is reachable

### Objective

Verify that the human-readable API documentation route is also available.

### Command

```bash
./scripts/predeploy-precheck.sh --api-only
```

### Expected result

- `GET /api/q2forge/docs` returns success

### Failure meaning

The API app may be partially misrouted even if the process is up.

## TC-API-003: Token issuance works with a known test account

### Objective

Verify that authentication works and the token endpoint can issue a bearer token.

### Command

```bash
PRECHECK_USERNAME=admin PRECHECK_PASSWORD=admin ./scripts/predeploy-precheck.sh --api-only
```

### Expected result

- `POST /api/q2forge/token` returns a valid access token

### Failure meaning

Possible causes:

- auth service is broken
- user does not exist
- password is wrong
- JWT secret/config is inconsistent

## TC-API-004: Protected user endpoint works with bearer token

### Objective

Verify that a valid token can access a protected endpoint.

### Command

```bash
PRECHECK_USERNAME=admin PRECHECK_PASSWORD=admin ./scripts/predeploy-precheck.sh --api-only
```

### Expected result

- `GET /api/q2forge/me` succeeds when called with the token from `TC-API-003`

### Failure meaning

Possible causes:

- token generation succeeded but auth middleware or bearer handling is broken
- token is malformed
- user is disabled

## TC-OLLAMA-001: Ollama service is reachable

### Objective

Verify that the configured Ollama host responds.

### Command

```bash
./scripts/predeploy-precheck.sh --ollama-only
```

### Expected result

- `GET /api/tags` on the configured Ollama URL succeeds

### Failure meaning

Possible causes:

- Ollama is down
- host/port is wrong
- the deployment host cannot route to Ollama

## TC-OLLAMA-002: Required chat model is present

### Objective

Verify that the configured chat model is available in Ollama before the backend needs it.

### Command

```bash
./scripts/predeploy-precheck.sh --ollama-only
```

### Expected result

- the Ollama tag list contains the model referenced by `OLLAMA_MODEL` or `LLM_MODEL`

### Failure meaning

The stack may start, but generation will fail at runtime when the backend tries to use a missing model.

## TC-OLLAMA-003: Required embedding model is present

### Objective

Verify that the configured embedding model is available in Ollama.

### Command

```bash
./scripts/predeploy-precheck.sh --ollama-only
```

### Expected result

- the Ollama tag list contains the model referenced by `OLLAMA_EMBED_MODEL` or `EMBEDDING_MODEL`

### Failure meaning

Preprocessing and retrieval-based scenarios are likely to fail.

## TC-OLLAMA-004: Chat generation call succeeds

### Objective

Verify that Ollama can actually execute a minimal chat request, not just list models.

### Command

```bash
./scripts/predeploy-precheck.sh --ollama-only
```

### Expected result

- `POST /api/chat` succeeds with `stream=false`

### Failure meaning

The model may be listed but unusable, or the Ollama API may be unhealthy.

## TC-OLLAMA-005: Embedding generation call succeeds

### Objective

Verify that Ollama can serve embeddings for the configured embedding model.

### Command

```bash
./scripts/predeploy-precheck.sh --ollama-only
```

### Expected result

- `POST /api/embeddings` succeeds

### Failure meaning

The backend may later fail during KG embedding generation or retrieval workflows.

## 6. Pass/fail policy

Suggested deployment gate:

### Hard fail

Do not deploy if any of these fail:

- `TC-SETUP-001`
- `TC-SETUP-002`
- `TC-SETUP-003`
- `TC-API-001`
- `TC-OLLAMA-001`
- `TC-OLLAMA-004`
- `TC-OLLAMA-005`

### Conditional fail

Investigate before deployment if these fail:

- `TC-API-002`
- `TC-API-003`
- `TC-API-004`
- `TC-OLLAMA-002`
- `TC-OLLAMA-003`

In a strict environment, these should also be considered blocking.

## 7. Recommended execution order before deployment

1. Run setup-only checks.
2. Run Ollama-only checks.
3. Start the stack in the target environment.
4. Run API-only checks.
5. If credentials are available, rerun API-only checks with `PRECHECK_USERNAME` and `PRECHECK_PASSWORD`.

That sequence catches most environment and routing errors early.

## 8. Evidence to capture

For release evidence or handoff notes, record:

- date and environment name
- exact command used
- script output
- overridden URLs, if any
- whether auth checks used seeded or dedicated test credentials

That is enough to make the precheck reproducible.
