.PHONY: help install lint format type security dead complexity deps test check all

help:
	@echo "Available targets:"
	@echo "  install    - uv sync (--all-extras)"
	@echo "  lint       - ruff check"
	@echo "  format     - ruff format"
	@echo "  type       - mypy strict"
	@echo "  security   - bandit"
	@echo "  dead       - vulture (dead code)"
	@echo "  complexity - radon (cyclomatic complexity)"
	@echo "  deps       - deptry (dependency hygiene)"
	@echo "  test       - pytest"
	@echo "  check      - run all quality gates"
	@echo "  hooks      - install pre-commit hooks"

install:
	uv sync --all-extras

lint:
	uv run ruff check src tests

format:
	uv run ruff format src tests

type:
	uv run mypy src

security:
	uv run bandit -c bandit.yaml -r src

dead:
	uv run vulture src .vulture_whitelist.py --min-confidence 80

complexity:
	uv run radon cc src -a -nc
	uv run radon mi src -nc

deps:
	uv run deptry src

test:
	uv run pytest

check:
	bash scripts/check.sh

hooks:
	uv run pre-commit install
	uv run pre-commit run --all-files
