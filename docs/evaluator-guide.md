# Evaluator Guide

## 1. Purpose of this guide

This guide is for a person evaluating the system rather than developing or operating it.

That evaluator might be:

- a thesis supervisor
- a reviewer reproducing experiments
- a QA engineer assessing functional behavior
- a researcher comparing scenarios or model settings

The goal of this guide is to explain:

- what should be evaluated
- what evaluation assets already exist in the repo
- how to interpret the available metrics
- how to run a practical evaluation from both product and research perspectives

## 2. What "evaluation" means in this repo

This repository supports two distinct styles of evaluation.

### 2.1 Product evaluation

This is a user-centric assessment of whether the system is usable and functionally correct.

Typical questions:

- Can a user log in and complete the workflow?
- Can a KG configuration be created and activated?
- Does preprocessing complete successfully?
- Does the system generate plausible competency questions?
- Does it produce runnable SPARQL?
- Does the refinement stage help a human improve the result?

### 2.2 Research evaluation

This is a benchmark-centric assessment of model or scenario quality.

Typical questions:

- How do scenarios compare on a benchmark set?
- Does scenario 7 improve judged query quality over simpler baselines?
- How similar is generated SPARQL to a reference query?
- How often does the system provide any valid query at all?

The repository contains code for both evaluation modes, but they are not wrapped into one single polished command-line suite. Treat them as research utilities and reproduction aids.

## 3. What evaluation assets already exist in the repository

The evaluation materials are mainly under:

- `gen2kgbot/app/evaluations/`

Important files and folders:

### Generic metric functions

- `gen2kgbot/app/evaluations/evaluation_metrics.py`

Provides:

- exact match
- BLEU
- ROUGE
- normalized Levenshtein-based score
- cosine similarity using sentence transformers

### LangSmith-oriented scripts

- `langsmith_evaluation_v1_s1.py`
- `langsmith_evaluation_v1_s2_6.py`
- `langsmith_evaluation_v2_s7.py`

These are oriented toward scenario-level evaluation using LangSmith datasets.

### Langfuse-oriented scripts

- `enpkg/langfuse_dataset_creation.py`
- `enpkg/langfuse_evaluation_enpkg.py`
- `sciqa/all-nodes/dataset_creation.py`
- `sciqa/all-nodes/evaluation.py`
- `sciqa/validation-node/dataset_creation.py`
- `sciqa/validation-node/evaluation.py`

These are oriented toward dataset upload, trace collection, and metric scoring in Langfuse-backed experiments.

### Local dataset assets

- `enpkg/enpkg_q2set.jsonl`
- `sciqa/all-nodes/eval_dataset.json`
- `sciqa/validation-node/validation-node-dataset.json`

These give you concrete examples of the kinds of benchmark inputs expected by the scripts.

## 4. What an evaluator should inspect first

Before running scripts, decide which of the following you actually need.

### Evaluate the product as a system

Use this when your concern is:

- usability
- functional completeness
- workflow coherence
- correctness of the end-to-end user journey

### Evaluate a scenario or model experimentally

Use this when your concern is:

- benchmark reproduction
- metric comparison
- scenario ablation
- model substitution

These two goals should not be mixed casually. A system may be operationally sound while a specific benchmark setup is not yet fully reproducible, and the reverse can also happen.

## 5. Product evaluation checklist

The cleanest product evaluation is a structured end-to-end walkthrough.

### 5.1 Authentication

Check:

- login works
- sign-up works
- protected pages require authentication
- expired sessions eventually require re-authentication

Record:

- success/failure
- clarity of error handling
- whether the user understands what happened

### 5.2 Configuration lifecycle

Check:

- an existing KG configuration can be activated
- a new KG configuration can be created
- invalid URLs are rejected in the UI
- duplicate `kg_short_name` handling is sensible

Also verify that the evaluator understands one critical product rule:

- configurations are shared server-side, but active selection is per user

### 5.3 Preprocessing

Check:

- KG descriptions can be generated
- KG embeddings can be generated
- failures are intelligible when endpoints are unreachable

A useful evaluation question is not merely "did it finish?" but also:

- did the resulting descriptions seem relevant to the KG?

### 5.4 Competency question generation

Check:

- the active config prefills the expected fields
- streamed output appears progressively
- structured JSON extraction works when enabled
- generated questions are domain-relevant
- downloading and local reuse work

Evaluate quality on:

- relevance
- diversity
- specificity
- consistency with KG scope

### 5.5 SPARQL generation and execution

Check:

- scenario selection is understandable
- streamed intermediate states help explain the result
- the system provides a query often enough to be useful
- endpoint results correspond to the generated query

Quality questions to ask:

- Did the model answer by direct text instead of query generation when it should not?
- Did the query use the right entities and predicates?
- Did the result set support the final interpretation?

### 5.6 Query refinement

Check:

- the editor loads and runs queries
- prefixes can be added
- QName extraction works
- label/description lookup helps explain the query
- LLM judging provides actionable feedback

This stage is central for evaluator judgment because it shows whether the product helps a human recover from imperfect generation.

### 5.7 Dataset export

Check:

- refined pairs can be added to the local dataset
- export formats are correct
- dataset cleanup/removal works

### 5.8 Persistence behavior

Check:

- SPARQL chat history persists across reloads for the user
- locally stored question/dataset state behaves as expected
- clearing the browser affects local but not server-side state

## 6. Suggested scoring dimensions for product evaluation

If you need a structured evaluation sheet, score each dimension from `1` to `5`:

| Dimension | What to evaluate |
|---|---|
| Setup clarity | How easy it is to get a usable session started |
| Configuration clarity | Whether KG setup is understandable and sufficiently explicit |
| Workflow continuity | Whether one stage leads naturally into the next |
| Transparency | Whether intermediate outputs explain the system behavior |
| Query usefulness | Whether generated SPARQL is often a useful starting point |
| Refinement support | Whether the human can improve results effectively |
| Export readiness | Whether results can be turned into a reusable dataset |
| Failure handling | Whether errors are visible, actionable, and specific |

Keep product scoring separate from benchmark metrics.

## 7. Research evaluation workflow

If your task is experimental rather than product-centered, use this sequence.

### Step 1: Prepare the evaluation environment

The repo ships a separate environment file:

- `gen2kgbot/environment_eval.yml`

Create it with Micromamba or Conda:

```bash
micromamba create -f environment_eval.yml
micromamba activate gen2kgbot-eval
```

### Step 2: Ensure runtime dependencies exist

You may need:

- SPARQL endpoint reachability
- model provider credentials
- LangSmith credentials
- Langfuse credentials
- local or remote embedding model availability

Because these scripts are research utilities, they assume the surrounding environment is already configured correctly.

### Step 3: Decide whether you are using LangSmith or Langfuse

Use LangSmith if you want:

- example-driven scenario evaluation
- evaluator callbacks that score outputs
- experiment tables through LangSmith tooling

Use Langfuse if you want:

- dataset management
- trace-level logging
- score attachment to runs

### Step 4: Check the dataset format

The repo includes local files showing the expected benchmark shapes.

Examples:

- `sciqa/all-nodes/eval_dataset.json` stores objects with `question`, `query`, and `query_result`
- `enpkg/enpkg_q2set.jsonl` stores JSONL-style entries with prompt history and target query outputs

Before reusing a script, confirm that:

- the dataset name referenced in the script exists remotely
- the expected output schema matches the script logic

### Step 5: Verify the script assumptions

This matters more than it sounds. The evaluation scripts are not a uniform framework; they are experiment-specific files. Before execution, verify:

- dataset names
- scenario numbers
- model names
- config file names
- expected output keys
- environment credentials

Do not assume that every script is plug-and-play across every KG or scenario.

## 8. How to interpret the shipped metrics

The repo includes several metric functions. Each tells you something different.

### 8.1 Exact match

Definition:

- `1.0` if generated text equals reference text exactly
- `0.0` otherwise

Strength:

- simple
- reproducible

Weakness:

- too strict for SPARQL because semantically equivalent queries can differ syntactically

Use it only as a harsh surface-form signal.

### 8.2 BLEU

Definition:

- n-gram overlap between generated and reference text

Strength:

- easy to compare across outputs

Weakness:

- sensitive to formatting and token ordering
- a poor proxy for SPARQL semantic equivalence on its own

### 8.3 ROUGE

Definition:

- overlap-oriented summary metric, here used on query strings

Strength:

- useful as another surface similarity signal

Weakness:

- still not a semantic correctness test

### 8.4 Levenshtein-based score

Definition:

- normalized edit distance between generated and reference text

Strength:

- easy to understand as "how much rewriting would be needed"

Weakness:

- penalizes harmless formatting and alias changes

### 8.5 Cosine similarity

Definition:

- embedding similarity between output and expected output

Strength:

- less brittle than exact string matching

Weakness:

- depends on the chosen sentence transformer
- may score structurally wrong but lexically similar queries too generously

## 9. Metric interpretation for SPARQL specifically

SPARQL is not ordinary prose. That changes how you should read metric scores.

A generated query can be:

- syntactically different but semantically equivalent
- semantically narrower or broader than the reference
- syntactically valid but operationally useless
- semantically right but formatted differently enough to score poorly

Because of that, a sound evaluator should combine:

1. automatic similarity metrics
2. execution behavior
3. human semantic inspection

If you rely only on BLEU or ROUGE, your evaluation will be too shallow.

## 10. What the existing evaluation scripts appear to measure

### LangSmith scenario 1 script

Focus:

- whether the model provided an answer instead of refusing

This is coarse and is closer to availability than correctness.

### LangSmith scenario 2-6 script

Focus:

- whether the system produced a query

Again, useful but incomplete. A provided query is not necessarily a good query.

### LangSmith scenario 7 script

Focus:

- last judging score from the system's own query-judgement chain

This is more aligned with practical system behavior, but it still depends on the model-based judge.

### Langfuse ENPKG and SCIQA scripts

Focus:

- query generation against reference datasets
- scoring with cosine, Levenshtein, BLEU, and ROUGE

These are more benchmark-like, but still require human interpretation.

## 11. Practical evaluator procedure for this repo

If you need a rigorous but realistic evaluation, use the following sequence.

### Phase A: System readiness

1. Verify the stack starts.
2. Verify authentication.
3. Verify one active seeded KG works.
4. Verify preprocessing can run.

### Phase B: Product walkthrough

1. Create or activate a KG configuration.
2. Generate 5 competency questions.
3. Select 2 questions of different difficulty.
4. Run SPARQL generation on both.
5. Refine the weaker result manually.
6. Export the resulting dataset.

Record:

- user effort
- number of retries
- clarity of feedback
- whether the system helped recover from bad generations

### Phase C: Research evaluation

1. Choose a dataset family such as `sciqa` or `enpkg`.
2. Verify the dataset format and remote dataset registration.
3. Run the chosen script after reviewing its assumptions.
4. Record metric outputs plus execution success.
5. Manually inspect a sample of high-scoring and low-scoring outputs.

### Phase D: Final judgment

Summarize separately:

- product usability
- workflow completeness
- scenario quality
- benchmark reproducibility

Those are related but not interchangeable judgments.

## 12. Common evaluation pitfalls

### Mistaking any generated query for a correct query

The system may produce a syntactically plausible query that does not answer the user question correctly.

### Over-trusting model-based judging

Scenario 7's internal judging is useful, but it is still another LLM step. It should not be treated as infallible ground truth.

### Over-penalizing formatting differences

Two SPARQL queries can behave identically while scoring poorly on string-based metrics.

### Ignoring endpoint behavior

A query that "looks right" but returns empty or irrelevant results is not a successful answer.

### Mixing product and benchmark conclusions

A repo can be a valuable research workbench even if some research scripts need adaptation. Keep those conclusions separate.

## 13. Reproducibility notes

The evaluation assets in this repo are real and useful, but they are not a hermetic evaluation harness.

Expect to verify and possibly adapt:

- credentials
- dataset names
- config file names
- chosen model identifiers
- SPARQL endpoint availability
- result parsing assumptions

That is normal for a research-oriented repository.

## 14. Evidence an evaluator should capture

For a complete evaluation report, collect:

- frontend screenshots of each workflow stage
- backend/API errors encountered
- exact scenario and model settings used
- dataset names and sizes
- metric outputs
- representative good and bad generated queries
- notes on semantic correctness after human review

This gives you enough evidence to distinguish:

- implementation failures
- data/configuration problems
- model-quality problems

## 15. Bottom line

The right way to evaluate this repo is to treat it as both:

- a user-facing workflow application
- a research platform for NL-to-SPARQL experimentation

If you evaluate only the UI, you miss the research value.
If you evaluate only the benchmark scripts, you miss whether the product actually helps a human reach a correct query.

Use both perspectives and keep the conclusions separate.
