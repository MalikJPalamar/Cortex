# Wiki Migration Kit — PT-7 (Phase 9)

Split the `docs/*-wiki` subdirectories of the Centaurion monorepo into **separate
GitHub repositories**, satisfying the Phase 9 DoD:

> "Wiki repos as separate GitHub repos (not just `docs/` subdirectories)."

This is a **kit the operator runs** — it is not run automatically. The
irreversible, outward step (creating repos under `MalikJPalamar`) is guarded
behind an explicit `--execute` flag. The default is a dry run.

---

## What it does

For each `docs/<name>-wiki/` directory, `migrate-wikis.sh`:

1. Stages the wiki content into a clean temp area (`.staging/<name>-wiki/`).
2. Generates a `README.md` for the new repo, derived from the wiki's actual
   page list (overwriting any copied-in README so links point back to the
   monorepo source).
3. Runs `git init` in the staging dir and makes an initial commit using a
   local-only identity (never touches your global git config).
4. Runs `gh repo create MalikJPalamar/<name>-wiki --private --source=. --push`
   — **only in `--execute` mode**.

Currently detected wikis:

| Wiki dir | Target repo | Pages |
|----------|-------------|-------|
| `docs/aob-wiki` | `MalikJPalamar/aob-wiki` | 5 |
| `docs/builderbee-wiki` | `MalikJPalamar/builderbee-wiki` | 5 |
| `docs/centaurion-wiki` | `MalikJPalamar/centaurion-wiki` | 17 |

The script discovers `docs/*-wiki` dynamically, so new wikis are picked up
automatically.

---

## Dry run vs. `--execute`

| Mode | Command | Effect |
|------|---------|--------|
| **Dry run (default)** | `bash deploy/wiki-migration/migrate-wikis.sh` | Stages everything, generates READMEs, and prints the exact `gh repo create` command per wiki. **Creates nothing. Pushes nothing.** |
| **Execute** | `bash deploy/wiki-migration/migrate-wikis.sh --execute` | Actually creates + pushes the repos. |

Always run the dry run first and read the planned commands.

### Options

```
--execute        Actually create + push (default = dry run).
--public         Create repos as --public (default = --private).
--org <name>     GitHub owner/org (default = MalikJPalamar).
--help           Show usage.
```

Idempotence: the staging area is rebuilt cleanly every run, and in `--execute`
mode a repo that already exists is skipped (no clobber), so re-running is safe.

---

## Operator command (the real thing)

```bash
# 1. Review the plan (safe, creates nothing):
bash deploy/wiki-migration/migrate-wikis.sh

# 2. When satisfied, create the private repos for real:
bash deploy/wiki-migration/migrate-wikis.sh --execute
```

Requires an authenticated `gh` session (`gh auth status`). The script checks this
before doing anything in `--execute` mode.

---

## Decision points

1. **Private vs. public.** Recommended: start **`--private`**. The centaurion-wiki
   contains internal architecture; the aob/builderbee wikis contain venture ops
   detail. You can flip a repo to public later with
   `gh repo edit MalikJPalamar/<name>-wiki --visibility public`. Going public is
   harder to undo than starting private.

2. **Keep `docs/` copies, or replace with submodules?** See the next section.
   Recommended: **leave `docs/` as-is initially** and treat the new repos as
   canonical only once you've confirmed the push looks right. Convert to
   submodules later as a deliberate, separate change.

---

## Post-migration options

After the repos exist, you have two ways to relate the monorepo to them:

### Option A — Leave `docs/` as-is, new repos are canonical (recommended first)

Do nothing to the monorepo. The `docs/*-wiki` directories remain as a working
copy; the new standalone repos become the source of truth you publish/share.
Lowest risk, fully reversible, zero submodule complexity. You can sync changes
back manually or automate later.

### Option B — Replace `docs/*-wiki` with git submodules

Point the monorepo at the new repos instead of holding copies. Run **after**
`--execute` has created and populated the repos:

```bash
# From the Centaurion repo root, for each wiki:
git rm -r docs/aob-wiki docs/builderbee-wiki docs/centaurion-wiki
git commit -m "chore: remove inlined wiki dirs ahead of submodule conversion"

git submodule add git@github.com:MalikJPalamar/aob-wiki.git        docs/aob-wiki
git submodule add git@github.com:MalikJPalamar/builderbee-wiki.git docs/builderbee-wiki
git submodule add git@github.com:MalikJPalamar/centaurion-wiki.git docs/centaurion-wiki

git commit -m "chore: track wiki repos as submodules under docs/"
```

(Use HTTPS URLs — `https://github.com/MalikJPalamar/<name>-wiki.git` — if you
don't use SSH.) Note the tradeoff: submodules pin a specific commit and require
`git submodule update --init --recursive` on clone, which adds friction for
phone-based ops. Only adopt if you want the monorepo to track the repos exactly.

A lighter-weight Option B variant: delete the `docs/*-wiki` dirs and replace each
with a short `docs/<name>-wiki.md` stub linking to the new repo — no submodule
machinery, just a pointer.

---

## Rollback

Nothing in the dry run needs rollback (it creates nothing).

If you ran `--execute` and want to undo it, just delete the new repos:

```bash
gh repo delete MalikJPalamar/aob-wiki --yes
gh repo delete MalikJPalamar/builderbee-wiki --yes
gh repo delete MalikJPalamar/centaurion-wiki --yes
```

(`gh repo delete` requires the `delete_repo` token scope; add it with
`gh auth refresh -s delete_repo` if prompted.) The monorepo `docs/` copies are
untouched by the migration, so deleting the new repos fully reverts the state.

---

## Files in this kit

| File | Purpose |
|------|---------|
| `migrate-wikis.sh` | The idempotent, dry-run-by-default migration script. |
| `README.md` | This runbook. |
| `readme-templates/` | Per-wiki README templates (reference; the script also generates these at run time). |
| `.gitignore` | Ignores the `.staging/` temp working area. |
