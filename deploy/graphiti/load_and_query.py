#!/usr/bin/env python3
"""Phase 10 DoD prover — load temporal decision records into Neo4j and answer
the canonical question: "When did we decide to migrate from Ontraport?".

This is the LLM-FREE proof of the temporal-knowledge-graph mechanism. Graphiti
itself needs an LLM key to auto-EXTRACT decision records from raw conversation
text; here we hand-load already-structured records (the exact shape the
MemPalace miner emits) so we can prove the graph + bi-temporal query end-to-end
against a REAL Neo4j, with no key required.

Each record becomes a ``(:Decision)`` node carrying BI-TEMPORAL properties:

  * decided_at  — VALID time: when the decision was actually made (domain time)
  * recorded_at — TRANSACTION time: when we ingested it into the graph (system time)

The DoD query then asks the graph when the Ontraport migration was decided and
prints the answer in plain English.

Usage:
    load_and_query.py --uri bolt://localhost:7688 --user neo4j --password testpassword123

Requires the ``neo4j`` Python driver (installed in a throwaway venv by the
calling script — NOT added to repo requirements).
"""

from __future__ import annotations

import argparse
import datetime as _dt
import sys

from neo4j import GraphDatabase

# Structured decision records — the SAME shape mine_conversations.py emits
# ({"timestamp","type","text", ...}). Synthetic / public content only; NO real
# private conversation text. The Ontraport->GoHighLevel migration is the record
# the DoD question targets; the others are decoys proving the query discriminates.
DECISION_RECORDS = [
    {
        "timestamp": "2026-03-02T14:11:00Z",
        "type": "decision",
        "subject": "crm-migration",
        "text": "We decided to migrate from Ontraport to GoHighLevel.",
    },
    {
        "timestamp": "2026-01-15T09:30:00Z",
        "type": "decision",
        "subject": "knowledge-graph",
        "text": "We chose Neo4j + Graphiti for the temporal knowledge graph.",
    },
    {
        "timestamp": "2026-02-20T17:45:00Z",
        "type": "decision",
        "subject": "directory-stack",
        "text": "We picked Next.js with an embedded Hono backend for The Directory.",
    },
    {
        "timestamp": "2026-04-08T11:05:00Z",
        "type": "decision",
        "subject": "hosting",
        "text": "We opted for Neon Postgres over a self-hosted database.",
    },
]


def load_records(session, records, recorded_at: str) -> int:
    """Idempotently MERGE decision records as bi-temporal nodes. Returns count."""
    # MERGE on text so re-runs don't duplicate. decided_at = VALID time (when the
    # decision was made), recorded_at = TRANSACTION time (when ingested).
    query = """
    MERGE (d:Decision {text: $text})
    SET d.decided_at  = datetime($decided_at),
        d.recorded_at = datetime($recorded_at),
        d.subject     = $subject,
        d.type        = $type
    RETURN d.text AS text
    """
    n = 0
    for rec in records:
        session.run(
            query,
            text=rec["text"],
            decided_at=rec["timestamp"],
            recorded_at=recorded_at,
            subject=rec.get("subject", "unknown"),
            type=rec.get("type", "decision"),
        )
        n += 1
    return n


def answer_dod(session) -> list[dict]:
    """The DoD Cypher query: when was the Ontraport-migration decision made?"""
    query = """
    MATCH (d:Decision)
    WHERE d.text CONTAINS 'Ontraport'
    RETURN d.decided_at AS decided_at, d.text AS text, d.recorded_at AS recorded_at
    ORDER BY d.decided_at
    """
    return [dict(r) for r in session.run(query)]


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Phase 10 DoD prover (LLM-free).")
    p.add_argument("--uri", default="bolt://localhost:7688")
    p.add_argument("--user", default="neo4j")
    p.add_argument("--password", default="testpassword123")
    args = p.parse_args(argv)

    recorded_at = _dt.datetime.now(_dt.timezone.utc).isoformat()

    print(f"-> Connecting to Neo4j at {args.uri} ...")
    driver = GraphDatabase.driver(args.uri, auth=(args.user, args.password))
    try:
        driver.verify_connectivity()
        print("OK Connected.")
        with driver.session() as session:
            # Clean slate so the proof is deterministic on re-run.
            session.run("MATCH (d:Decision) DETACH DELETE d")

            n = load_records(session, DECISION_RECORDS, recorded_at)
            print(f"OK Loaded {n} temporal decision node(s) "
                  f"(valid-time=decided_at, transaction-time=recorded_at).")

            total = session.run("MATCH (d:Decision) RETURN count(d) AS c").single()["c"]
            print(f"OK Graph now holds {total} (:Decision) node(s).")

            print("\n-- DoD QUERY -----------------------------------------------")
            print("  MATCH (d:Decision) WHERE d.text CONTAINS 'Ontraport'")
            print("  RETURN d.decided_at, d.text\n")

            rows = answer_dod(session)
            if not rows:
                print("FAIL No Ontraport decision found -- DoD NOT proven.")
                return 1

            for row in rows:
                decided = row["decided_at"]
                # neo4j DateTime -> ISO date string for a phone-readable answer.
                date_str = decided.iso_format()[:10] if hasattr(decided, "iso_format") else str(decided)[:10]
                print(f"  ANSWER: Decided to migrate from Ontraport on {date_str}.")
                print(f"          (full record: \"{row['text']}\")")
                print(f"          valid-time:       {decided}")
                print(f"          transaction-time: {row['recorded_at']}")

            print("\nOK Phase 10 DoD PROVEN against a real Neo4j temporal graph.")
            return 0
    finally:
        driver.close()


if __name__ == "__main__":
    raise SystemExit(main())
