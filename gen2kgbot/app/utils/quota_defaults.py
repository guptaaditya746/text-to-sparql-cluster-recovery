import os


DEFAULT_INITIAL_FREE_QUOTA = 10000


def _get_int_env(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default

    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"Environment variable {name} must be an integer") from exc


def get_initial_free_cq_generation() -> int:
    return _get_int_env("INITIAL_FREE_CQ_GENERATION", DEFAULT_INITIAL_FREE_QUOTA)


def get_initial_free_sparql_query_answers() -> int:
    return _get_int_env(
        "INITIAL_FREE_SPARQL_QUERY_ANSWERS", DEFAULT_INITIAL_FREE_QUOTA
    )


def get_initial_free_sparql_query_judging() -> int:
    return _get_int_env(
        "INITIAL_FREE_SPARQL_QUERY_JUDGING", DEFAULT_INITIAL_FREE_QUOTA
    )
