# User Guide

## 1. Purpose of the system

This repository provides a complete workflow for turning natural-language questions into SPARQL queries over a target knowledge graph (KG).

As an end user, you interact primarily with the `q2forge` web application, while the `gen2kgbot` backend does the heavy work:

- storing shared KG configurations
- generating KG descriptions and embeddings
- generating competency questions
- generating SPARQL queries
- running those queries
- helping you refine and judge query quality

The system is not only a question-answering interface. It is also a dataset-building tool. A typical user session ends with a validated `(question, SPARQL query)` pair that can be exported for later reuse.

## 2. What you can do with the system

The system supports four main user workflows:

1. Configure a new knowledge graph.
2. Preprocess that graph so the backend can retrieve contextual class information and example queries.
3. Generate competency questions and candidate SPARQL queries.
4. Refine, validate, and export question-query pairs.

In practice, this means the system can be used by:

- researchers building benchmark sets
- ontology engineers testing whether a KG is queryable in natural language
- domain experts creating example question/query corpora
- evaluators comparing different prompting or model configurations

## 3. Before you start

You need the following:

- a running frontend and backend
- a valid user account
- a reachable SPARQL endpoint for the KG you want to use
- at least one active KG configuration in your account

If you are using the Docker setup shipped with this repo, the default seeded account is:

- username: `admin`
- password: `admin`

Important operating constraints:

- most feature routes are protected and require authentication
- the active KG configuration is user-specific
- newly created KG configurations are stored on the server and become available to other users
- SPARQL chats are stored in server-side user history
- some local convenience data is stored in your browser local storage

Do not use sensitive credentials, confidential questions, or private business data in chat history or shared configuration fields.

## 4. Main concepts you need to understand

### 4.1 KG configuration

A KG configuration is the server-side description of the knowledge graph the system should target. It includes:

- full KG name
- short KG name
- KG description
- KG SPARQL endpoint URL
- ontology endpoint URL
- prefixes
- named graphs
- excluded class namespaces
- optional example question/query pairs

The backend enriches the configuration with additional defaults such as model catalogs, embedding settings, storage paths, and scenario settings.

### 4.2 Active configuration

Each user can select one active configuration. The active configuration is the default KG context used by the frontend for:

- filling in forms
- retrieving known prefixes
- generating competency questions
- generating and judging SPARQL queries

If no active configuration exists, several screens will still load but the workflow will be incomplete until a configuration is activated.

### 4.3 Preprocessing

Preprocessing is the step that converts raw KG metadata into reusable text and vector resources.

It consists of two actions:

1. Generate KG descriptions.
2. Generate KG embeddings.

Without preprocessing, the richer retrieval-based scenarios will not work correctly.

### 4.4 Scenario

A scenario is a backend strategy for answering a natural-language question. The repository ships with scenarios `1` to `7`, going from simple direct prompting to more advanced query generation and self-judging workflows.

At a high level:

- Scenario 1: ask the model directly without KG querying
- Scenario 2: generate SPARQL directly
- Scenario 3+: use retrieved class context
- Scenario 6+: use example SPARQL queries as additional context
- Scenario 7: includes query judging and retry behavior

### 4.5 Competency question

A competency question is a natural-language question that the KG should be able to answer. The system can generate these automatically to help you build a benchmark or training/evaluation set.

### 4.6 Query refinement

Query refinement is the human-in-the-loop phase. You:

- inspect the generated SPARQL
- run it against the endpoint
- extract labels and descriptions of terms used in the query
- ask the model to judge whether the query matches the question
- edit and retry until satisfied

### 4.7 Dataset export

Validated question/query pairs can be collected in the browser and exported in multiple formats:

- CSV
- JSONL
- XML
- JSON

## 5. The recommended end-to-end workflow

If you are using the system for the first time, follow this sequence.

### Step 1: Sign in

Open the frontend and log in with an existing account, or sign up for a new one.

After login:

- your access token is stored in local storage
- the frontend keeps you authenticated until token expiry
- the backend still enforces authorization on protected endpoints

Current behavior to know:

- the token lifetime is seven days
- there is no password reset flow in the current app
- there is no role separation in the current app

### Step 2: Activate an existing configuration or create a new one

If your target KG already exists in the backend:

1. Open the activation dialog from a workflow screen.
2. Select the desired `kg_short_name`.
3. Activate it.

If your target KG does not exist yet:

1. Go to the KG configuration creation page.
2. Fill in the KG metadata.
3. Add prefixes and optional example queries.
4. Submit the configuration.

Use a short name that is stable and machine-friendly:

- lowercase letters
- digits
- underscores only

Example: `pubchem`, `orkg_ml`, `d2kab`

### Step 3: Generate KG descriptions

After configuration creation, generate the KG descriptions.

This step queries the KG and produces preprocessing text files such as:

- class descriptions
- class-with-instance descriptions
- property descriptions

These files are used later for retrieval and context construction.

### Step 4: Generate KG embeddings

Run the embedding generation step after descriptions are available.

This computes vector representations used by scenarios that retrieve:

- relevant classes
- relevant properties
- relevant example SPARQL queries

### Step 5: Generate competency questions

Open the competency question generator and review the prefilled KG information from the active configuration.

You can typically choose:

- a model configuration
- the number of questions
- whether to force structured JSON output
- optional additional context, such as a paper abstract

After generation:

- inspect the raw streamed model output
- inspect the parsed structured questions
- download the result
- optionally store questions locally so they can be reused in the SPARQL generation screen

### Step 6: Generate and execute SPARQL

Open the SPARQL generation screen and:

1. choose or confirm the scenario/model setup
2. enter or select a question
3. run the workflow

The interface streams intermediate backend events. Depending on the scenario, you may see:

- question validation
- relevant entities detected in the question
- similar classes retrieved
- similar example queries retrieved
- prompts constructed for the model
- generated query attempts
- syntax verification
- query execution results
- answer interpretation

This is useful because it shows why the system arrived at a particular query.

### Step 7: Refine the query

When you have a promising query, send it to the refinement screen.

There you can:

- inspect the SPARQL in the embedded editor
- run it against the endpoint
- extract qualified names from the query
- retrieve labels/comments/descriptions for those terms
- ask the model to judge the alignment between question and query
- revise the query manually and retry

This is the stage where you convert a merely plausible query into one you are willing to keep.

### Step 8: Export the dataset

Once the pair is good enough:

1. add it to the local dataset
2. open the dataset export dialog
3. review the collected pairs
4. remove any bad entries
5. export in the format you need

## 6. Screen-by-screen guide

## 6.1 Home page

The home page is the orientation page. It presents:

- the overall pipeline
- scenario diagrams
- videos and demonstrations
- entry points to the main features

Use it to understand where each step fits into the larger workflow.

## 6.2 Login and sign-up

The authentication screens are basic username/password forms.

What to expect:

- login returns a bearer token
- sign-up also logs you in immediately
- protected routes require a valid token
- once the token expires, you must log in again

Limitations to be aware of:

- no email recovery
- no multi-factor authentication
- no password reset UI

## 6.3 KG configuration creation

This is one of the most important screens because the quality of later results depends strongly on configuration quality.

You will typically provide:

- `kg_full_name`
- `kg_short_name`
- `kg_description`
- `kg_sparql_endpoint_url`
- `ontologies_sparql_endpoint_url`
- `properties_qnames_info`
- prefixes
- ontology named graphs
- excluded class namespaces
- example question/query pairs

Practical advice:

- keep the KG description concrete and domain-specific
- provide clean prefixes for the namespaces users and models should prefer
- provide representative example queries if you plan to use the richer scenarios
- exclude namespaces that produce noisy or irrelevant classes

Important warning:

The UI explicitly warns that newly created configurations are stored on the server for reuse by other users. Treat configuration content as shared.

## 6.4 Competency question generator

This screen helps you bootstrap question creation.

Best use cases:

- creating an initial benchmark set
- generating candidate questions for expert review
- covering a KG broadly before deeper manual curation

Fields to pay attention to:

- endpoint
- KG description
- KG schema
- additional context
- question count
- model
- structured output toggle

Good practice:

- start with a small batch such as `5`
- inspect quality before scaling
- keep structured output enabled if you intend to reuse the results automatically

## 6.5 SPARQL query generator/executor

This screen is the most important one for everyday usage.

It gives you:

- a question input
- scenario/model configuration
- streamed system reasoning
- generated SPARQL attempts
- query execution results
- answer interpretation
- persistent server-side chat history

This screen is appropriate when you want to:

- test whether a question is answerable
- compare scenarios
- inspect why a query failed
- retain a trace of generation attempts

The backend decrements a per-user quota when this workflow runs. If you see `403 Forbidden`, the likely reason is that your free SPARQL answer quota is exhausted.

## 6.6 SPARQL query refinement

This screen is appropriate when you care about correctness more than speed.

Use it to:

- inspect syntax carefully
- add missing prefixes
- understand entities and predicates used in the query
- get model feedback on semantic alignment
- build a cleaner gold dataset

The embedded SPARQL editor is useful, but do not treat it as a semantic guarantee. Always inspect the actual endpoint result.

## 6.7 API documentation page

The frontend includes a route that opens the backend API documentation.

Use it when:

- you want to understand the raw API
- you are integrating another client
- you want to inspect request and response schemas

## 7. Data persistence and privacy behavior

Different parts of the workflow are stored in different places.

### Stored on the server

- user accounts
- user active configuration selection
- SPARQL chat history
- shared KG configurations
- quotas

### Stored in the browser

- access token
- token expiry
- generated competency questions kept for reuse
- local dataset entries for export
- some editor state from the embedded SPARQL tooling

This means a browser cleanup can remove your locally stored dataset, even though your account and server-side chats remain intact.

## 8. Quotas and limits

The backend maintains free-use counters per user for at least three actions:

- competency question generation
- SPARQL answer generation
- SPARQL query judging

The default seeded values are generous for local experimentation, but the backend still enforces them. If a request fails with `403`, check whether the relevant quota has reached zero.

## 9. Common failure cases and what they usually mean

### "No active configuration found"

Meaning:

- you have not activated a KG configuration yet

What to do:

- activate an existing configuration
- or create a new one, then activate it

### Configuration created, but generation quality is poor

Meaning:

- the KG description is too vague
- prefixes are incomplete
- preprocessing was not run
- example queries are missing for higher scenarios

What to do:

- enrich the configuration
- regenerate descriptions and embeddings
- add representative example queries

### Preprocessing fails

Meaning:

- the KG endpoint is unreachable
- the ontology endpoint is wrong
- the KG returns unexpected schema information

What to do:

- verify endpoint URLs directly
- test the SPARQL endpoint outside the app
- reduce noise in the configuration

### SPARQL generation fails or produces empty answers

Meaning:

- the question may be out of scope
- the scenario may be too weak
- the generated query may be invalid or too restrictive
- the endpoint may not contain the expected data

What to do:

- try another scenario
- refine the question
- inspect the streamed intermediate steps
- move to the query refinement screen

### Query judging returns a low score

Meaning:

- the query shape does not reflect the actual question intent
- labels/comments in the query context expose mismatched entities

What to do:

- inspect extracted QNames
- edit the query manually
- rerun the judgement after each meaningful change

## 10. Practical operating advice

- Start with one known-good KG before adding many.
- Keep KG descriptions factual, not promotional.
- Use scenario 7 when you want the strongest built-in checking.
- Use example queries for domains where naming is ambiguous.
- Treat automatic outputs as drafts until a human has reviewed them.
- Export often if you are building a dataset in the browser.

## 11. What this system is good at, and what it is not

The system is good at:

- guiding an expert through natural-language-to-SPARQL construction
- exposing intermediate reasoning steps
- helping create evaluation datasets
- reusing KG-specific configuration and retrieval assets

The system is not, in its current form:

- a zero-maintenance production QA chatbot
- a privacy-preserving confidential assistant
- a guaranteed semantic verifier of SPARQL correctness
- a replacement for human curation when building gold datasets

That is the right expectation to keep while using it.
