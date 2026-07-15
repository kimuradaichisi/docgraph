"""MarkdownParser - wraps markdown-it-py."""
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link


class MarkdownParser:
    def parse(self, path: str) -> tuple[list[Heading], list[Link], str]:
        # TODO: implement with markdown-it-py
        raise NotImplementedError
