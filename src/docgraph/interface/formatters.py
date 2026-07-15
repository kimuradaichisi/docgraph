"""Output formatters (JSON / text)."""
import json


def to_json(data: object) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2, default=str)


def to_text(data: object) -> str:
    # TODO: implement human-readable formatting
    return str(data)
