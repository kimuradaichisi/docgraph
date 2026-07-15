"""Confidence value object tests."""
import pytest

from docgraph.domain.confidence import Confidence


def test_valid_value() -> None:
    c = Confidence(0.5)
    assert c.value == 0.5


def test_lower_bound() -> None:
    assert Confidence(0.0).value == 0.0


def test_upper_bound() -> None:
    assert Confidence(1.0).value == 1.0


def test_out_of_range_raises() -> None:
    with pytest.raises(ValueError):
        Confidence(1.5)
    with pytest.raises(ValueError):
        Confidence(-0.1)
