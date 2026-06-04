import re


def _extract_with_spacy(question: str) -> list[str]:
    try:
        import spacy
    except ModuleNotFoundError:
        return []

    model_names = [
        "en_core_sci_lg",
        "en_core_web_lg",
        "en_core_web_sm",
    ]

    for model_name in model_names:
        try:
            nlp = spacy.load(model_name)
            doc = nlp(question)
            entities = [ent.text.strip() for ent in doc.ents if ent.text.strip()]
            if entities:
                return entities
        except OSError:
            continue

    return []


def _extract_with_fallback(question: str) -> list[str]:
    # Keep quoted spans and parenthesized phrases first since many questions name KG entities that way.
    matches = re.findall(r"'([^']+)'|\"([^\"]+)\"|\(([^)]+)\)", question)
    entities = []
    for group in matches:
        for candidate in group:
            candidate = candidate.strip()
            if candidate:
                entities.append(candidate)

    if entities:
        return entities

    # Last resort: use the full question so later retrieval still has something meaningful to search with.
    cleaned = " ".join(question.split()).strip()
    return [cleaned] if cleaned else []


def extract_relevant_entities_spacy(question: str) -> list[str]:
    """
    Extract relevant entities from the NL question.

    Prefer spaCy when available, but keep the application runnable without heavyweight
    local NLP models by falling back to lightweight string heuristics.
    """

    entities = _extract_with_spacy(question)
    if entities:
        return entities

    return _extract_with_fallback(question)
