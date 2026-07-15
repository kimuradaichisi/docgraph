"""Relation entity and Reason enum."""
from dataclasses import dataclass
from enum import StrEnum

from docgraph.domain.confidence import Confidence


class Reason(StrEnum):
    """Edge origin category."""

    EXPLICIT_LINK = "explicit_link"
    NAME_MENTION = "name_mention"
    HEADING_MENTION = "heading_mention"


@dataclass(frozen=True)
class Relation:
    """Directed relation between two documents."""

    source_id: str
    target_id: str
    reason: Reason
    confidence: Confidence
    evidence_line: int
