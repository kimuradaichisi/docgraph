"""Ports (interfaces) for Infrastructure layer."""
from __future__ import annotations

from typing import Protocol

from docgraph.domain.document import Document
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link
from docgraph.domain.relation import Relation


class FileScannerPort(Protocol):
    def scan(self, root: str) -> list[str]: ...


class MarkdownParserPort(Protocol):
    def parse(self, path: str) -> tuple[list[Heading], list[Link], str]: ...


class DocumentRepository(Protocol):
    def upsert(self, document: Document) -> None: ...

    def find_by_path(self, path: str) -> Document | None: ...

    def find_all(self) -> list[Document]: ...


class RelationRepository(Protocol):
    def upsert_many(self, relations: list[Relation]) -> None: ...

    def find_by_source(self, source_id: str) -> list[Relation]: ...


class SearchRepository(Protocol):
    def index_body(self, doc_id: str, body: str) -> None: ...

    def search(self, keyword: str) -> list[tuple[str, float, str]]: ...
