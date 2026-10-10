# Backup manifest

This recovery repo preserves the existing project history and adds the current local UI change and remote inference configuration.

Excluded local or generated artifacts:

- `gen2kgbot/y/`: generated environment/bootstrap output.
- `gen2kgbot/setup_db/data/**/faiss_embeddings/`: generated FAISS indexes and serialized embedding metadata (small historical copies remain in prior commits because history is preserved).
- Python, Node, Angular, and local runtime caches covered by `.gitignore`.
- Local environment files and logs.

The source directory and its original remote were left unchanged. Back up any needed indexes or generated state separately.
