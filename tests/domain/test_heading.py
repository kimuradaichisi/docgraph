"""Heading value object tests."""
import pytest

from docgraph.domain.heading import Heading


def test_valid_level() -> None:
    h = Heading(level=1, text="Intro", line=1)
    assert h.level == 1


def test_invalid_level_raises() -> None:
    with pytest.raises(ValueError):
        Heading(level=0, text="X", line=1)
    with pytest.raises(ValueError):
        Heading(level=7, text="X", line=1)
