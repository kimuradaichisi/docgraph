"""CLI entry point using Typer."""
from __future__ import annotations

import typer

app = typer.Typer(help="DocGraph - Documentation relationship analysis engine")


@app.command()
def index(
    root: str = typer.Option(".", "--root", help="Project root directory"),
    config: str = typer.Option("docgraph.toml", "--config", help="Config file path"),
) -> None:
    """Build or update the knowledge graph."""
    typer.echo(f"index root={root} config={config}")
    # TODO: wire up IndexUseCase


@app.command()
def related(
    path: str = typer.Argument(..., help="Target file path"),
    min_confidence: float = typer.Option(0.0, "--min-confidence"),
    output_format: str = typer.Option("json", "--format"),
) -> None:
    """Show related documents for a file."""
    typer.echo(f"related path={path}")
    # TODO: wire up QueryUseCase


@app.command()
def search(
    keyword: str = typer.Argument(..., help="Search keyword"),
    output_format: str = typer.Option("json", "--format"),
) -> None:
    """Full-text search across documents."""
    typer.echo(f"search keyword={keyword}")
    # TODO: wire up QueryUseCase


if __name__ == "__main__":
    app()
