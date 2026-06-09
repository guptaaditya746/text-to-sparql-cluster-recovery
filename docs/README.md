# Documentation

This repository contains two main applications:

- `gen2kgbot/`: the Python backend that generates SPARQL, runs scenarios, exposes the API, and stores shared configuration data.
- `q2forge/`: the Angular frontend that guides users through configuration, question generation, SPARQL generation, and query refinement.

For cluster execution on a GPU node, also see [../README_SLURM.md](../README_SLURM.md).

The documents below are intended to replace scattered onboarding knowledge with role-specific guides.

## Guides in this folder

### 1. User Guide

File: [user-guide.md](./user-guide.md)

Read this if you are an end user who wants to:

- sign in
- create or activate a KG configuration
- preprocess a graph
- generate competency questions
- generate and refine SPARQL queries
- export a dataset

### 2. Developer Guide

File: [developer-guide.md](./developer-guide.md)

Read this if you need to:

- run the stack locally without Docker
- understand the repo structure
- extend the frontend or backend
- add scenarios, models, or endpoints
- understand where data is stored and how requests flow

### 3. Deployment and Operations Guide

File: [deployment-and-operations-guide.md](./deployment-and-operations-guide.md)

Read this if you operate the stack and need to:

- run it with Docker Compose
- configure ports, secrets, and model backends
- manage seeded data, MongoDB, and persistent volumes
- troubleshoot service startup and runtime issues

### 4. Evaluator Guide

File: [evaluator-guide.md](./evaluator-guide.md)

Read this if you are assessing the system and need to:

- evaluate the product manually as a user-facing system
- understand the research evaluation assets already present in the repo
- interpret the available evaluation metrics
- reproduce or adapt LangSmith and Langfuse evaluation scripts

### 5. Pre-Deployment Precheck Test Cases

File: [pre-deployment-precheck-test-cases.md](./pre-deployment-precheck-test-cases.md)

Read this if you need a deployment gate for:

- environment and compose setup
- backend API accessibility
- Ollama reachability and model readiness
- a repeatable host-side precheck before rollout

## Suggested reading order

If you are new to the repo:

1. Read [user-guide.md](./user-guide.md) to understand the product workflow.
2. Read [developer-guide.md](./developer-guide.md) to understand the implementation.
3. Read [deployment-and-operations-guide.md](./deployment-and-operations-guide.md) if you will run the stack.
4. Read [evaluator-guide.md](./evaluator-guide.md) if you need to assess correctness, quality, or reproducibility.
5. Read [pre-deployment-precheck-test-cases.md](./pre-deployment-precheck-test-cases.md) if you need a release gate before deployment.

## Existing project-specific source docs

The repo already contains narrower docs that are still useful as source material:

- Backend overview: [../gen2kgbot/README.md](../gen2kgbot/README.md)
- Backend API notes: [../gen2kgbot/doc/api_description.md](../gen2kgbot/doc/api_description.md)
- Backend development notes: [../gen2kgbot/doc/dev_guidelines.md](../gen2kgbot/doc/dev_guidelines.md)
- Frontend overview: [../q2forge/README.md](../q2forge/README.md)
- Frontend feature notes:
  - [../q2forge/doc/kg-creation.md](../q2forge/doc/kg-creation.md)
  - [../q2forge/doc/competency-question-generation.md](../q2forge/doc/competency-question-generation.md)
  - [../q2forge/doc/sparql-query-generation.md](../q2forge/doc/sparql-query-generation.md)
  - [../q2forge/doc/sparql-query-refinement.md](../q2forge/doc/sparql-query-refinement.md)
- Docker quick start: [../DOCKER.md](../DOCKER.md)

These new docs are intended to give a complete, cross-repo view.
