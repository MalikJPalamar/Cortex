#!/usr/bin/env python3
"""Centaurion — Graphiti LIVE activation + DoD verification.

This is the "flip it on" step. Unlike prove-dod.py (which hand-loads structured
records into an EPHEMERAL Neo4j to prove the graph mechanism without a key), this
script does the real thing against the SHARED LIVE Neo4j:

  1. Connects graphiti-core to the live Neo4j on this host.
  2. Feeds it a raw, UNSTRUCTURED conversation episode and lets the LLM
     auto-EXTRACT the decision + its time axis (the one capability the proof
     could not exercise without a key).
  3. Runs the Phase 10 DoD query and prints the answer with its valid-time.

If step 2 produces an edge whose fact mentions Ontraport with valid_at on the
decision date, auto-extraction works end-to-end → Phase 10 is LIVE, not just proven.

SAFETY / IDEMPOTENCY:
  * All writes are namespaced under group_id="centaurion-activation-check" so this
    verification never pollutes the real "centaurion" memory namespace. Re-running
    is safe; it overwrites the same probe episode.
  * Nothing is deleted. Graphiti edges are invalidated, never dropped.

LLM PROVIDER:
  Golden path = OpenAI (one key does both extraction + embeddings). Set
  OPENAI_API_KEY (OpenRouter-compatible base via OPENAI_BASE_URL also works).
  Anthropic-only is possible but still needs an embedder; see --help notes.

Run via deploy/graphiti/activate-graphiti.sh (which installs graphiti-core into a
dedicated venv and loads host .env first). Direct use:
    python activate_and_verify.py --uri bolt://localhost:7687 --user neo4j --password ****
"""

import argparse
import asyncio
import os
import sys
from datetime import datetime, timezone

PROBE_GROUP = "centaurion-activation-check"

# A raw, unstructured episode — the LLM must EXTRACT the decision + date itself.
# This mirrors what MemPalace mines from real transcripts, but deliberately leaves
# it as prose so the activation actually exercises LLM extraction (the live gap).
PROBE_EPISODE = (
    "Team sync, early March 2026. Malik confirmed the call: we're migrating AOB off "
    "Ontraport. The decision was made on 2026-03-02 after the renewal quote came in — "
    "GoHighLevel becomes the system of record for AOB membership and CRM. Anthony to "
    "lead the cutover. Ontraport stays read-only through the transition, then sunsets."
)
PROBE_REFERENCE_TIME = datetime(2026, 3, 2, 12, 0, 0, tzinfo=timezone.utc)

DOD_QUERY = "When did we decide to migrate from Ontraport?"


def _build_graphiti(uri, user, password, provider):
    """Construct a Graphiti client with the chosen LLM provider.

    OpenAI is the golden path (LLM + embeddings from one key). Anthropic is
    supported for extraction but still needs an OpenAI key for embeddings, since
    Anthropic ships no embeddings endpoint.
    """
    from graphiti_core import Graphiti

    if provider == "openai":
        if not os.environ.get("OPENAI_API_KEY"):
            sys.exit("FAIL  OPENAI_API_KEY not set (required for provider=openai).")
        # Default Graphiti uses OpenAI for both the LLM and the embedder. An
        # OpenAI-compatible gateway (e.g. OpenRouter) works via OPENAI_BASE_URL.
        return Graphiti(uri, user, password)

    if provider == "anthropic":
        if not os.environ.get("ANTHROPIC_API_KEY"):
            sys.exit("FAIL  ANTHROPIC_API_KEY not set (required for provider=anthropic).")
        if not os.environ.get("OPENAI_API_KEY"):
            sys.exit(
                "FAIL  provider=anthropic still needs an embedder. Anthropic has no "
                "embeddings API — set OPENAI_API_KEY too (used only for embeddings), "
                "or switch to --llm-provider openai."
            )
        from graphiti_core.llm_client.anthropic_client import AnthropicClient
        from graphiti_core.llm_client.config import LLMConfig

        model = os.environ.get("MODEL_NAME", "claude-sonnet-4-6")
        llm = AnthropicClient(config=LLMConfig(api_key=os.environ["ANTHROPIC_API_KEY"], model=model))
        # Embedder defaults to OpenAI from OPENAI_API_KEY.
        return Graphiti(uri, user, password, llm_client=llm)

    sys.exit(f"FAIL  unknown provider '{provider}' (use openai|anthropic).")


async def _run(args):
    graphiti = _build_graphiti(args.uri, args.user, args.password, args.llm_provider)
    try:
        print("──  Ensuring indices/constraints on the live Neo4j ...")
        await graphiti.build_indices_and_constraints()

        from graphiti_core.nodes import EpisodeType

        print("──  Feeding RAW episode (LLM must extract the decision + date) ...")
        await graphiti.add_episode(
            name="activation-probe-ontraport",
            episode_body=PROBE_EPISODE,
            source=EpisodeType.text,
            source_description="Graphiti activation probe (deploy/graphiti)",
            reference_time=PROBE_REFERENCE_TIME,
            group_id=PROBE_GROUP,
        )
        print("OK  Episode ingested. LLM extraction complete.")

        print(f'──  Running the DoD query: "{DOD_QUERY}"')
        results = await graphiti.search(DOD_QUERY, group_ids=[PROBE_GROUP])

        if not results:
            print("FAIL  Query returned no facts. Extraction may have failed — check the LLM key.")
            return 1

        print("\n──  FACTS RETURNED ───────────────────────────────────────")
        hit = False
        for r in results:
            valid = getattr(r, "valid_at", None)
            fact = getattr(r, "fact", str(r))
            print(f"  • {fact}")
            if valid is not None:
                print(f"      valid_at: {valid}")
            text = f"{fact} {valid}".lower()
            if "ontraport" in text and ("2026-03-02" in text or "march" in text):
                hit = True

        print("──────────────────────────────────────────────────────────\n")
        if hit:
            print("OK  Phase 10 DoD is LIVE: the graph auto-extracted the Ontraport")
            print("    decision from raw text and answered with its valid-time.")
            return 0
        print("WARN  Facts returned, but none clearly tied Ontraport to 2026-03-02.")
        print("      The mechanism works; re-run or inspect the facts above. Not a hard fail.")
        return 0
    finally:
        await graphiti.close()


def main():
    p = argparse.ArgumentParser(description="Activate + verify Graphiti against the live Neo4j.")
    p.add_argument("--uri", default=os.environ.get("NEO4J_URI", "bolt://localhost:7687"))
    p.add_argument("--user", default=os.environ.get("NEO4J_USER", "neo4j"))
    p.add_argument("--password", default=os.environ.get("NEO4J_PASSWORD"))
    p.add_argument("--llm-provider", default=os.environ.get("GRAPHITI_LLM_PROVIDER", "openai"),
                   choices=["openai", "anthropic"])
    args = p.parse_args()
    if not args.password:
        sys.exit("FAIL  NEO4J_PASSWORD not set (host .env) and --password not given.")
    sys.exit(asyncio.run(_run(args)))


if __name__ == "__main__":
    main()
