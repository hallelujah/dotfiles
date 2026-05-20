# semble — code search for AI agents

[Semble](https://minish.ai/packages/semble/introduction/) is a CPU-only,
embedding-based code search tool optimised for agent workflows. It returns
precise code snippets with **$HOME98% fewer tokens than `ripgrep` + file reads**,
and is exposed in this repo as the `semble` MCP server (via the central mcphub)
plus a thin CLI wrapper at `bin/semble-here`.

This document is a condensed reference of the upstream docs (introduction,
installation, usage, MCP server, benchmarks).

## At a glance

| Property        | Value                                                               |
| --------------- | ------------------------------------------------------------------- |
| Runtime         | Python ≥ 3.10, CPU only — no GPU, no API keys, no external svc      |
| Indexing speed  | $HOME250–263 ms per repo                                            |
| Query latency   | $HOME1.5 ms                                                         |
| Quality         | 0.854 NDCG@10 (vs 0.862 for CodeRankEmbed Hybrid; $HOME218× faster) |
| Token reduction | 566 tokens/query vs 45,692 for `rg` + read ($HOME98% saving)        |
| Recall @ 500 t  | 0.685 vs 0.001 for ripgrep                                          |
| Recall @ 4k t   | 0.976 vs 0.088 for ripgrep                                          |
| License         | MIT                                                                 |

## How it works

Dual-retrieval pipeline:

1. **Semantic** — Model2Vec embeddings from `potion-code-16M`.
2. **Lexical** — BM25 over identifiers / API names.

Results merged via Reciprocal Rank Fusion, then re-ranked using code-aware
signals: adaptive weighting, definition prioritisation, identifier stemming,
file-level coherence, and noise filtering.

## Install

Upstream options:

```sh
pip install semble                    # core only
pip install "semble[mcp]"             # core + MCP server
uv add semble                         # via uv
uvx --from "semble[mcp]" semble       # ephemeral, no persistent install
```

In this repo `hooks/post-up` runs the following on every `rcup`, idempotently:

```sh
uv tool install --python 3.13 --upgrade 'semble[mcp]'
```

That puts a persistent `semble` binary at `$HOME/.local/.bin/semble` (managed
by `uv tool`). The mcphub entry then invokes that binary directly, so no
ephemeral `uvx` env is built per launch.

**Why pin Python 3.13?** semble pulls `chonkie` → `tokie`, which builds via
PyO3 ≤ 3.13. uv defaults to the newest interpreter available (3.14 as of
writing) and the wheel build fails. `--python 3.13` forces uv to provision
3.13 if missing.

## CLI

```sh
semble search "<natural-language query>" <path-or-git-url> [--top-k N]
semble find-related <file> <line> <path-or-git-url> [--top-k N]
```

Convenience wrapper in this repo:

```sh
bin/semble-here "<query>" [--top-k N]   # searches the current working tree
```

Examples:

```sh
semble search "where is the auth middleware" .
semble search "model2vec embedding load" https://github.com/MinishLab/model2vec
semble find-related src/auth/middleware.py 42 .
```

## Python API

```python
from semble import SembleIndex

index = SembleIndex.from_path("./my-project")
# or: SembleIndex.from_git("https://github.com/MinishLab/model2vec", ref="main")

results = index.search("save model to disk", top_k=5)
related = index.find_related(results[0], top_k=5)

for r in results:
    print(r.score, r.chunk.file_path, r.chunk.start_line, r.chunk.end_line)
    print(r.chunk.content)

print(index.stats.indexed_files, index.stats.total_chunks, index.stats.languages)
```

### Indexing options

| Option               | Purpose                                        |
| -------------------- | ---------------------------------------------- |
| `extensions`         | `frozenset({".py", ".ts"})` — limit file types |
| `ignore`             | Skip dirs (`"dist"`, `"node_modules"`, …)      |
| `include_text_files` | Index Markdown / YAML / JSON                   |
| `ref`                | Git branch or tag (git repos only)             |

### Search options

| Option             | Purpose                                      |
| ------------------ | -------------------------------------------- |
| `filter_languages` | e.g. `["python"]`                            |
| `filter_paths`     | Restrict to specific files                   |
| `mode`             | `"hybrid"` (default), `"semantic"`, `"bm25"` |
| `top_k`            | Number of results returned                   |

## MCP server

Transport: **stdio** only. Two tools exposed:

| Tool           | Purpose                                                                 |
| -------------- | ----------------------------------------------------------------------- |
| `search`       | Natural-language or code query against a local path or git URL          |
| `find_related` | Given a `file_path` + `line` from a prior result, return similar chunks |

Indexes are cached for the lifetime of the MCP process; remote repos are
cloned and indexed on demand.

### Registration in this repo

Registered centrally in `config/mcphub/servers.json`:

```json
"semble": {
  "command": "semble",
  "args": [],
  "env": {}
}
```

Bare `semble` (no subcommand) starts the MCP server over stdio. The
`{search, find-related, init}` subcommands route to the regular CLI.

`bin/mcp-hub-run` (the launcher) prepends `$HOME/.local/.bin` to PATH so the
service unit finds the binary even when launched headlessly by systemd /
launchd.

Claude Code, Gemini, and any other agent talk to the mcphub SSE bridge
(`http://localhost:37373/mcp`); semble surfaces there as
`mcp__mcphub__semble__search` and `mcp__mcphub__semble__find_related`.

After editing `servers.json`, restart the hub:

```sh
systemctl --user restart mcp-hub                              # Linux
launchctl kickstart -k "gui/$(id -u)/com.user.mcp-hub"        # macOS
```

### Upstream-recommended per-agent registration (reference)

Not used here (we route through mcphub) but useful if you ever want a
direct, hub-less wiring:

```sh
# Claude Code (direct, bypasses mcphub)
claude mcp add semble -s user -- uvx --from "semble[mcp]" semble
```

```json
// Cursor — $HOME/.cursor/mcp.json
{
  "mcpServers": {
    "semble": {
      "command": "uvx",
      "args": ["--from", "semble[mcp]", "semble"]
    }
  }
}
```

```json
// OpenCode — $HOME/.opencode/config.json
{
  "mcp": {
    "semble": {
      "type": "local",
      "command": ["uvx", "--from", "semble[mcp]", "semble"]
    }
  }
}
```

```toml
# Codex — $HOME/.codex/config.toml
[mcp_servers.semble]
command = "uvx"
args = ["--from", "semble[mcp]", "semble"]
```

## When to use semble vs grep

| Use semble                        | Use grep / ripgrep                  |
| --------------------------------- | ----------------------------------- |
| "Where is the auth middleware?"   | `TODO\(hery\)` literal              |
| "What handles webhook retries?"   | An exact error message              |
| "Find code that loads embeddings" | A known function name               |
| Mapping a feature across files    | A specific log line                 |
| Architecture / concept questions  | A specific identifier / import path |

Rule of thumb: **intent / concept → semble; literal string → grep.**

## Benchmarks (one paragraph)

Evaluated over $HOME1,250 queries spanning 63 repos in 19 languages, split into
semantic (711), architecture (343), and symbol-lookup (204). Tokens counted
with `cl100k_base`. Compared against `ripgrep`, `probe` (BM25 + tree-sitter),
ColGREP, `grepai` (nomic embeddings), and `CodeRankEmbed`. Headline result:
near-transformer quality, two-orders-of-magnitude lower latency, and a 98%
token reduction relative to grep+read.

## Repo touchpoints

| File                                 | Role                                                                                                    |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `config/mcphub/servers.json`         | Registers `semble` with the MCP hub                                                                     |
| `hooks/post-up`                      | `uv tool install --upgrade 'semble[mcp]'`, model warm-up, mcp-hub auto-restart on `servers.json` change |
| `bin/semble-here`                    | CLI shorthand for searching the current tree                                                            |
| `claude/commands/semble.md`          | Claude Code slash command `/semble <query>`                                                             |
| `bin/semble-init-project`            | SessionStart hook: `semble init` per project, idempotent                                                |
| `config/nvim/lua/semble.lua`         | Neovim integration logic (`:Semble`, `:SembleRelated`)                                                  |
| `config/nvim/lua/plugins/semble.lua` | Lazy.nvim spec; binds `<leader>ss` and `<leader>sr`                                                     |
| `AGENTS.md` → "Code Search"          | Tells agents to prefer semble over grep+read                                                            |
| `docs/semble.md`                     | This document                                                                                           |

## Per-project sub-agent (`semble init`)

Upstream semble ships a Claude Code sub-agent definition that teaches the
parent agent to delegate code-search to a `semble-search` sub-agent. Drop
it into a project with:

```sh
semble init                                     # writes .claude/agents/semble-search.md
```

`bin/semble-init-project` does this idempotently as a SessionStart hook,
so any project you open in Claude Code automatically gets the sub-agent.
Wire it into your local Claude settings (untracked, machine-local), e.g.
`$HOME/dotfiles-local/claude/settings.json`:

```jsonc
"hooks": {
  "SessionStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "$HOME/.bin/semble-init-project",
          "timeout": 10,
          "statusMessage": "Ensuring semble sub-agent..."
        }
      ]
    }
  ]
}
```

The script is a no-op when:

- `.claude/agents/semble-search.md` already exists, or
- the cwd / `$CLAUDE_PROJECT_DIR` doesn't look like a project root
  (no `.git`, `AGENTS.md`, `pyproject.toml`, `package.json`, `Cargo.toml`,
  `Gemfile`, or `go.mod`), or
- `semble` isn't installed.

`.claude/agents/` is gitignored at the repo root, so the generated file
never lands in your dotfiles history.

## Links

- Introduction: <https://minish.ai/packages/semble/introduction/>
- Installation: <https://minish.ai/packages/semble/installation/>
- Usage: <https://minish.ai/packages/semble/usage/>
- MCP server: <https://minish.ai/packages/semble/mcp-server/>
- Benchmarks: <https://minish.ai/packages/semble/benchmarks/>
- Source: <https://github.com/MinishLab/semble>
