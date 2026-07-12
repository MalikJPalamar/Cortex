#!/usr/bin/env python3
"""Centaurion — Graphiti dual-backend selector (the shared contract).

One env var — ``GRAPHITI_BACKEND`` (``neo4j`` | ``falkordb``) — picks the graph
store behind Graphiti. This is NOT a fork: graphiti-core ships a pluggable
``GraphDriver`` layer and supports both stores first-class, so swapping is a
driver swap, nothing more.

Why two stores: Neo4j is a JVM (~0.5–1 GB resident); FalkorDB is a Redis module
(~tens of MB). On a RAM-constrained host the lighter store may win outright. The
benchmark (``deploy/graphiti/bench/``) runs the SAME episodes through both and
lets the numbers decide — LLM extraction is identical across backends, so the
store is the only variable.

Driver signatures (verified against the installed graphiti-core):
    Neo4jDriver(uri, user, password, database='neo4j')
    FalkorDriver(host='localhost', port=6379, username=None, password=None,
                 falkor_db=None, database='default_db')
    Graphiti(uri, user, password, ..., graph_driver=None, llm_client=None, embedder=None)

Design note: ``graphiti_core`` is imported INSIDE ``build_graphiti`` so this
module imports — and ``resolve_backend`` / ``connection_from_env`` stay
unit-testable — without the heavy dependency present.
"""
from __future__ import annotations

import os

SUPPORTED_BACKENDS = ("neo4j", "falkordb")
DEFAULT_BACKEND = "neo4j"


def resolve_backend(name: str | None = None) -> str:
    """Resolve the backend from an explicit arg or ``GRAPHITI_BACKEND``.

    Falls back to :data:`DEFAULT_BACKEND`. Raises :class:`ValueError` on an
    unknown backend so a typo fails loudly instead of silently picking the
    wrong store.
    """
    backend = (name or os.environ.get("GRAPHITI_BACKEND") or DEFAULT_BACKEND).strip().lower()
    if backend not in SUPPORTED_BACKENDS:
        raise ValueError(
            f"unknown GRAPHITI_BACKEND {backend!r}; choose one of {SUPPORTED_BACKENDS}"
        )
    return backend


def connection_from_env(backend: str) -> dict:
    """Read connection settings for ``backend`` from the environment.

    neo4j:    NEO4J_URI (bolt://localhost:7687), NEO4J_USER (neo4j), NEO4J_PASSWORD
    falkordb: FALKORDB_HOST (localhost), FALKORDB_PORT (6379),
              FALKORDB_USERNAME (none), FALKORDB_PASSWORD (none),
              FALKORDB_DATABASE (default_db)
    """
    backend = resolve_backend(backend)
    if backend == "neo4j":
        return {
            "uri": os.environ.get("NEO4J_URI", "bolt://localhost:7687"),
            "user": os.environ.get("NEO4J_USER", "neo4j"),
            "password": os.environ.get("NEO4J_PASSWORD"),
        }
    # falkordb
    return {
        "host": os.environ.get("FALKORDB_HOST", "localhost"),
        "port": int(os.environ.get("FALKORDB_PORT", "6379")),
        "username": os.environ.get("FALKORDB_USERNAME") or None,
        "password": os.environ.get("FALKORDB_PASSWORD") or None,
        "database": os.environ.get("FALKORDB_DATABASE", "default_db"),
    }


def build_graphiti(backend: str, conn: dict, *, llm_client=None, embedder=None):
    """Construct a Graphiti client bound to ``backend``.

    ``conn`` is a dict as returned by :func:`connection_from_env`. graphiti-core
    is imported lazily here so importing this module never requires it.
    """
    backend = resolve_backend(backend)
    from graphiti_core import Graphiti

    if backend == "neo4j":
        if not conn.get("password"):
            raise ValueError("neo4j backend requires NEO4J_PASSWORD (conn['password'])")
        return Graphiti(
            conn["uri"], conn["user"], conn["password"],
            llm_client=llm_client, embedder=embedder,
        )

    # falkordb
    from graphiti_core.driver.falkordb_driver import FalkorDriver

    driver = FalkorDriver(
        host=conn.get("host", "localhost"),
        port=int(conn.get("port", 6379)),
        username=conn.get("username"),
        password=conn.get("password"),
        database=conn.get("database", "default_db"),
    )
    return Graphiti(graph_driver=driver, llm_client=llm_client, embedder=embedder)


__all__ = [
    "SUPPORTED_BACKENDS",
    "DEFAULT_BACKEND",
    "resolve_backend",
    "connection_from_env",
    "build_graphiti",
]
