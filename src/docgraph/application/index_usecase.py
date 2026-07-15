"""IndexUseCase - orchestrates scanning, parsing, and relation building."""
from dataclasses import dataclass

from docgraph.application.ports import (
    DocumentRepository,
    FileScannerPort,
    MarkdownParserPort,
    RelationRepository,
    SearchRepository,
)
from docgraph.application.stopwords_service import StopwordsService


@dataclass
class IndexResult:
    indexed_files: int
    skipped_files: int
    explicit_links: int
    name_mentions: int
    heading_mentions: int
    elapsed_ms: int


class IndexUseCase:
    def __init__(
        self,
        scanner: FileScannerPort,
        parser: MarkdownParserPort,
        document_repo: DocumentRepository,
        relation_repo: RelationRepository,
        search_repo: SearchRepository,
        stopwords: StopwordsService,
    ) -> None:
        self._scanner = scanner
        self._parser = parser
        self._document_repo = document_repo
        self._relation_repo = relation_repo
        self._search_repo = search_repo
        self._stopwords = stopwords

    def execute(self, root: str) -> IndexResult:
        # TODO: implement
        raise NotImplementedError
