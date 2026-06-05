import argparse
import os

from pymongo import MongoClient


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Update Q2Forge quotas for an existing user."
    )
    parser.add_argument("username", help="Username to update")
    parser.add_argument("--cq", type=int, help="New CQ generation quota")
    parser.add_argument(
        "--sparql-answers", type=int, help="New SPARQL query answer quota"
    )
    parser.add_argument(
        "--sparql-judging", type=int, help="New SPARQL query judging quota"
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    updates = {}

    if args.cq is not None:
        updates["free_cq_generation_left"] = args.cq
    if args.sparql_answers is not None:
        updates["free_sparql_query_answers_left"] = args.sparql_answers
    if args.sparql_judging is not None:
        updates["free_sparql_query_judging_left"] = args.sparql_judging

    if not updates:
        raise SystemExit("No quota values provided.")

    connection_string = os.getenv("MONGODB_CONNECTION_STRING")
    if not connection_string:
        raise SystemExit("MONGODB_CONNECTION_STRING is not set.")

    client = MongoClient(connection_string)
    try:
        result = client["q2forge"]["users"].update_one(
            {"username": args.username}, {"$set": updates}
        )
        if result.matched_count == 0:
            raise SystemExit(f"User not found: {args.username}")

        user = client["q2forge"]["users"].find_one({"username": args.username})
        print(
            {
                "username": user["username"],
                "free_cq_generation_left": user["free_cq_generation_left"],
                "free_sparql_query_answers_left": user[
                    "free_sparql_query_answers_left"
                ],
                "free_sparql_query_judging_left": user[
                    "free_sparql_query_judging_left"
                ],
            }
        )
    finally:
        client.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
