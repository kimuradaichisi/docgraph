"""QueryUseCase - handles related and search queries."""
from dataclasses import dataclass

from docgraph.application.ports import (
    DocumentRepository,
    RelationRepository,
    SearchRepository,
)


@dataclass
class RelatedItem:
    path: str
    reason: str
    confidence: float
    evidence_line: int


@dataclass
class SearchItem:
    path: str
    score: float
    snippet: str


class QueryUseCase:
    def __init__(
        self,
        document_repo: DocumentRepository,
        relation_repo: RelationRepository,
        search_repo: SearchRepository,
    ) -> None:
        self._document_repo = document_repo
        self._relation_repo = relation_repo
        self._search_repo = search_repo

    def related(self, path: str, min_confidence: float = 0.0) -> list[RelatedItem]:
        # TODO: implement
        raise NotImplementedError

    def search(self, keyword: str) -> list[SearchItem]:
        # TODO: implement
        raise NotImplementedError
