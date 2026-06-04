# Developer Guide

## 1. Purpose of this guide

This guide is for engineers who need to understand, run, modify, or extend the repository.

The repo is a small monorepo with a clear split:

- `gen2kgbot/`: backend, scenario execution, preprocessing, data access, API, auth, persistence
- `q2forge/`: frontend, workflow UI, authentication client, dataset export, query editor

This document explains:

- how the codebase is structured
- how the frontend and backend communicate
- how to run each part locally
- where shared state lives
- how to extend the system safely

## 2. High-level architecture

At runtime the system looks like this:

1. The user interacts with the Angular frontend.
2. The frontend authenticates against the FastAPI backend.
3. The backend loads the active KG configuration from MongoDB.
4. For preprocessing or question answering, the backend uses its configuration manager plus scenario logic.
5. Scenarios call local or remote LLM backends and KG SPARQL endpoints.
6. Results stream back to the frontend.
7. The user may refine a query and export curated pairs.

Supporting services:

- MongoDB stores users, chat history, and KG configurations.
- Ollama may be used as the default local model host.
- Remote providers such as OpenAI, DeepSeek, OVH, Google, or HuggingFace may also be used depending on configuration.

## 3. Repository layout

Below is the structure that matters most when making changes:

```text
.
├── docker-compose.yml
├── DOCKER.md
├── docs/
├── gen2kgbot/
│   ├── app/
│   │   ├── api/
│   │   │   ├── database/
│   │   │   ├── models/
│   │   │   ├── requests/
│   │   │   ├── responses/
│   │   │   ├── services/
│   │   │   └── q2forge_api.py
│   │   ├── evaluations/
│   │   ├── preprocessing/
│   │   ├── scenarios/
│   │   └── utils/
│   ├── config/
│   ├── doc/
│   ├── setup_db/
│   ├── environment.yml
│   ├── environment_eval.yml
│   ├── langgraph.json
│   └── Dockerfile
└── q2forge/
    ├── src/app/
    │   ├── components/
    │   ├── dialogs/
    │   ├── models/
    │   ├── services/
    │   └── utils/
    ├── public/
    ├── angular.json
    ├── package.json
    └── Dockerfile
```

## 4. Backend architecture

## 4.1 Main backend entry point

The backend API entry point is:

- `gen2kgbot/app/api/q2forge_api.py`

This file defines:

- FastAPI app creation
- CORS policy
- ReDoc and Swagger paths
- config endpoints
- preprocessing endpoints
- question generation endpoints
- query judging endpoints
- auth endpoints
- user chat endpoints

The backend API paths are all rooted under:

- `/api/q2forge/...`

## 4.2 Backend subpackages

### `app/api/database`

Contains MongoDB access helpers for:

- users
- configurations

These helpers are thin and mostly perform direct read/write operations.

### `app/api/models`

Contains Pydantic models used for:

- token payloads
- user and chat data

### `app/api/requests`

Contains request schemas for:

- config creation
- config activation
- answer generation
- competency question generation
- query refinement

### `app/api/responses`

Contains Pydantic response schemas for:

- KG configurations
- scenario graph schemas

### `app/api/services`

Contains runtime behavior for:

- auth
- answering questions
- graph visualization
- competency question generation
- query refinement
- config helpers

This is where most endpoint logic delegates.

### `app/preprocessing`

Contains preprocessing logic that:

- generates KG descriptions
- computes embeddings

These steps are prerequisites for retrieval-based scenarios.

### `app/scenarios`

Contains `scenario_1` through `scenario_7`.

Each scenario has its own module and prompt definitions. This is the core of the NL-to-SPARQL reasoning pipeline.

### `app/utils`

Contains shared infrastructure such as:

- configuration management
- database initialization
- prompt helpers
- graph state structures
- logging
- SPARQL tooling

## 4.3 Backend data model

The main persisted entities are:

### User

Stored in MongoDB collection `users`.

Important fields:

- `username`
- `hashed_password`
- `disabled`
- `active_config_id`
- `sparql_chats`
- `free_cq_generation_left`
- `free_sparql_query_answers_left`
- `free_sparql_query_judging_left`

### Configuration

Stored in MongoDB collection `configurations`.

Important fields:

- KG identity and endpoint fields
- prefixes and namespace filters
- scenario defaults
- model catalog
- embedding model catalog
- storage path defaults

The user-submitted config is not the whole final config. The backend merges it with defaults from `gen2kgbot/config/params_to_add.yml`.

## 4.4 Backend configuration lifecycle

The configuration lifecycle works like this:

1. A user submits a minimal KG configuration from the frontend.
2. The backend rejects duplicate `kg_short_name` values.
3. Optional example queries are written to `data/<kg_short_name>/example_queries`.
4. Missing defaults are merged from `config/params_to_add.yml`.
5. The completed configuration is inserted into MongoDB.
6. A user activates one configuration, which stores its MongoDB id in `users.active_config_id`.

This means:

- configurations are shared
- active configuration selection is per user

## 4.5 Backend API surface

Major endpoints:

- `GET /api/q2forge/config/available`
- `GET /api/q2forge/config/active`
- `GET /api/q2forge/scenarios_graph_schema`
- `POST /api/q2forge/config/create`
- `POST /api/q2forge/config/activate`
- `POST /api/q2forge/config/kg_descriptions`
- `POST /api/q2forge/config/kg_embeddings`
- `POST /api/q2forge/generate_questions`
- `POST /api/q2forge/answer_question`
- `POST /api/q2forge/judge_query`
- `POST /api/q2forge/token`
- `GET /api/q2forge/me`
- `POST /api/q2forge/sign-up`
- `POST /api/q2forge/user/sparql_chats`
- `DELETE /api/q2forge/user/sparql_chats`

Behavioral notes:

- generation and judging endpoints stream JSON events
- auth uses bearer tokens
- quotas are enforced server-side
- active config loading is implicit in many requests

## 4.6 Auth model

Auth is implemented with JWT bearer tokens.

Important details:

- tokens are issued by `POST /api/q2forge/token`
- sign-up also returns a token
- token lifetime is `10080` minutes, which is seven days
- password hashing uses bcrypt through Passlib
- protected endpoints depend on `get_current_active_user`

Current limitations:

- no refresh token flow
- no password reset
- no roles
- no admin UI

## 4.7 Scenario execution model

Scenario execution is exposed through `app/api/services/answer_question.py`.

The answer flow:

1. Load the selected scenario module.
2. Construct the LangGraph graph.
3. Stream graph events.
4. Filter and serialize only relevant graph/chat events.
5. Return them line-by-line as JSON to the frontend.

This explains why the frontend can show intermediate workflow states like:

- selected classes
- retrieved example queries
- prompt construction
- query verification attempts
- final result interpretation

## 4.8 Logging

Backend logging is centralized in:

- `gen2kgbot/config/logging.yml`

The existing backend dev notes recommend using the local logger utility instead of `print`.

For new scripts, follow the existing pattern:

```python
from app.utils.logger_manager import setup_logger

logger = setup_logger(__package__, __file__)
```

## 5. Frontend architecture

## 5.1 Main frontend routing

The route configuration is in:

- `q2forge/src/app/app.routes.ts`

Main routes:

- `/`
- `/login`
- `/sign-up`
- `/kg-configuration-creation`
- `/competency-question-generator`
- `/sparql-query-generator`
- `/sparql-query-refinement`
- `/api/docs`

Most workflow routes are protected by `authGuard`.

## 5.2 Frontend component model

Major components:

- `HomeComponent`
- `LoginComponent`
- `SignUpComponent`
- `KGConfigurationCreationComponent`
- `CompetencyQuestionGeneratorComponent`
- `SPARQLQueryGeneratorExecutorComponent`
- `SPARQLQueryRefinementComponent`

Supporting dialogs:

- config activation
- dataset export
- available question selection
- question-answerer configuration
- generic notifications

## 5.3 Frontend services

Key services and their responsibilities:

### `AuthService`

- login
- sign-up
- local token storage
- logout timing
- auth state broadcasting

### `ConfigManagerService`

- fetch active config
- fetch available configs
- fetch scenario schemas
- create config
- activate config
- trigger KG description generation
- trigger KG embedding generation

### `AnswerQuestionService`

- call the streamed answer endpoint

### `GenerateQuestionService`

- call the streamed competency question endpoint

### `LLMJudgeService`

- call the query judging endpoint

### `UserService`

- fetch current user data
- persist SPARQL chat history
- delete chat history items

### `LocalStorageManagerService`

- persist generated competency questions locally for reuse

## 5.4 Frontend API binding strategy

The frontend uses environment-like file replacement instead of Angular runtime env injection.

Important files:

- `predefined-variables.ts`
- `predefined-variables.prod.ts`
- `predefined-variables.docker.ts`

Build-time behavior:

- production build replaces the default variables file with the production one
- docker build replaces it with the docker one

This matters when you add new endpoints. You must keep the endpoint constant list aligned across these files.

## 5.5 Frontend storage model

The frontend stores several items in browser local storage:

- `access_token`
- `expires_in`
- `questions`
- `dataset`
- editor-related state from YASGUI

Server-side storage is still used for:

- SPARQL chat history
- user profile data
- active configuration

## 5.6 Frontend build and serve behavior

Useful commands from `q2forge/package.json`:

- `npm start`: Angular dev server with proxy config
- `npm run build`: standard build
- `npm run watch`: development build watch
- `npm run test`: Angular test runner
- `npm run dc`: production-style base-href build for deployment

Important practical note:

- `npm start` is the correct local dev entry point for the shipped package scripts

## 6. Local development setup without Docker

## 6.1 Prerequisites

For the frontend:

- Node.js compatible with the repo's current Angular toolchain
- npm

For the backend:

- Conda or Micromamba
- Python 3.12
- MongoDB
- network access to your target SPARQL endpoints
- either local Ollama or remote model provider credentials

## 6.2 Backend setup

From `gen2kgbot/`:

```bash
micromamba create -f environment.yml
micromamba activate gen2kgbot
```

If you use Conda instead:

```bash
conda env create -f environment.yml
conda activate gen2kgbot
```

Set the key environment variables you need, for example:

```bash
export MONGODB_CONNECTION_STRING='mongodb://admin:admin@localhost:27017/?authSource=admin'
export Q2FORGE_SECRET_KEY='replace-this'
export OLLAMA_HOST='http://localhost:11434'
export OLLAMA_BASE_URL='http://localhost:11434'
export OPENAI_BASE_URL='http://localhost:11434/v1'
```

Initialize the database:

```bash
python -m setup_db.init_db
```

Start the API:

```bash
python -m app.api.q2forge_api
```

Or equivalently:

```bash
uvicorn app.api.q2forge_api:app --host 0.0.0.0 --port 8000
```

## 6.3 Frontend setup

From `q2forge/`:

```bash
npm ci
npm start
```

The frontend will typically be available at:

- `http://localhost:4200`

The default local frontend constants expect the backend at:

- `http://localhost:8003`

If you run the backend on `8000`, either:

- change the frontend constant file for local work
- or run a port-forward / reverse proxy
- or start the backend on the expected port

## 6.4 Local dev smoke test

Once both pieces are running:

1. Open the frontend.
2. Log in or sign up.
3. Open the API docs.
4. Fetch available configurations.
5. Activate one configuration.
6. Generate KG descriptions.
7. Generate KG embeddings.
8. Generate a small batch of competency questions.
9. Run one SPARQL generation request.
10. Open the refinement screen and judge one query.

If that sequence works, the full stack is basically wired correctly.

## 7. Extending the backend

## 7.1 Add a new API endpoint

When adding a backend endpoint:

1. Define or reuse request/response models.
2. Put business logic in `app/api/services` where possible.
3. Keep persistence logic in `app/api/database`.
4. Add the route in `q2forge_api.py`.
5. Update the frontend endpoint constants.
6. Add or update the consuming frontend service/component.

## 7.2 Add a new scenario

To add a scenario:

1. Create a new scenario package under `app/scenarios/scenario_<n>/`.
2. Follow the existing pattern with module, prompt, and graph construction.
3. Make sure the scenario can be resolved by the config manager utilities.
4. Add or update scenario defaults in configuration data.
5. Expose the scenario in the frontend configuration dialog if users need to select it.

Also update:

- `gen2kgbot/langgraph.json` if you want it visible to LangGraph tooling
- any evaluation scripts that iterate specific scenario ranges

## 7.3 Add a new model provider or model entry

The fastest path is often to extend:

- `gen2kgbot/config/params_to_add.yml`

This file centralizes:

- model catalogs
- embedding model catalogs
- default scenario-to-model mapping

If the provider requires new runtime behavior, update the backend configuration/model loading utilities as needed.

## 7.4 Add a new preprocessing asset

If a scenario needs additional retrieved context:

1. decide whether the asset belongs to descriptions, embeddings, or examples
2. add the generation logic under `app/preprocessing`
3. update configuration defaults or output paths
4. make the scenario load and use the new asset

## 8. Extending the frontend

## 8.1 Add a new page

1. Create a standalone component under `src/app/components`.
2. Add the route in `app.routes.ts`.
3. Add an auth guard if it is protected.
4. Create or update a service for backend calls.

## 8.2 Add a new backend integration

1. Add endpoint constants to all predefined-variable files.
2. Update or add a frontend service.
3. Handle auth automatically through the existing interceptors if applicable.
4. Decide whether the data should live only in component state, local storage, or server storage.

## 8.3 Keep streaming UX consistent

Several core workflows consume streamed backend responses. When adding another streamed endpoint:

- parse incrementally
- handle `403` before starting to read the body
- separate model-stream events from final workflow state
- expose enough intermediate detail for debugging

The existing generator and judge components are the patterns to follow.

## 9. Data locations that matter during development

### MongoDB

- database name: `q2forge`
- collections: `users`, `configurations`

### Backend filesystem

- `gen2kgbot/data/`: runtime data, embeddings, example queries
- `gen2kgbot/setup_db/data/`: seeded data copied during initialization
- `gen2kgbot/logs/`: backend logs
- `gen2kgbot/tmp/`: temporary runtime files

### Frontend browser storage

- auth token
- token expiry
- generated questions
- local dataset export state

## 10. Testing and verification reality

There is currently no strong automated, repo-wide test harness checked into the repository for the combined stack.

What this means in practice:

- rely on focused manual smoke testing after changes
- run `npm run build` in `q2forge` after UI changes
- verify backend imports and API startup after Python changes
- test at least one end-to-end user workflow for any cross-cutting change

For research logic, evaluation scripts under `gen2kgbot/app/evaluations/` are relevant but they are not a substitute for application-level regression testing.

## 11. Current technical constraints you should keep in mind

- Shared KG configurations are writable by ordinary users through the app.
- Quotas are stored directly on user documents.
- Frontend local configuration is compile-time, not runtime-injected.
- Auth is simple and suitable for controlled environments, not hardened public deployment.
- Research evaluation scripts exist, but they are not packaged as a single polished benchmark command.

These are the assumptions you should preserve or consciously change when extending the codebase.
