# Portability test run — 2026-05-02

Branch: `centralized-mcphub` @ `2be741c`  
Outcome: **PARTIAL** — GitHub + Figma MCP work end-to-end; blockers are all known or expected.  
GitHub login confirmed: `hallelujah`  
Total MCP tools available: 48 (figma: 7, github: 41, linear: 0 — OAuth required)

---

## Steps

| # | Step | Status | Notes |
|---|------|--------|-------|
| pre | Docker install | PASS | Docker CE 29.4.2 via dnf on Fedora 43 WSL |
| pre | `jrei/systemd-ubuntu:24.04` image | FAIL → fallback | Not available for amd64; used `ubuntu:24.04` + systemd manually |
| pre | rcm apt repo (thoughtbot) | FAIL → fallback | 404; installed rcm from Ubuntu universe |
| pre | systemd in container | FAIL → fixed | Required `--cgroupns=host` (not `--privileged` alone) on WSL2 cgroup v2 |
| 1 | Clone dotfiles | PASS | Branch pushed; HTTPS clone |
| 2 | rcup | PARTIAL | Needs `-d ~/dotfiles` and must run **twice** (first run creates parent dirs) |
| 3 | mise install | PARTIAL | mcp-hub, op, claude, node — OK; ruby/lua/postgres failed (build deps) |
| 4 | Provision OP token | PASS | environment.d/ picked up by systemd --user |
| 5 | Enable mcp-hub.service | PASS | Active immediately; binary path resolved from mise shims |
| 6 | Hub health + tools | PASS | Health `ok`; GitHub 41 tools, Figma 7 tools |
| 7 | Claude mcp list | PASS | Connected after `claude mcp add` |
| 8 | E2E GitHub SSE | PASS | `github__get_me` → `hallelujah` |
| 9 | E2E via claude --print | BLOCKED | OAuth token is device-bound; didn't transfer to container |
| 10 | Service restart | PASS | Active + health ok; GitHub reconnected |

---

## Gaps

### Gap 1 — `rcup` bootstrap (blocker)

- **What was missing:** `rcup` (no flags) on a fresh `$HOME` creates no symlinks and exits 0. Without `~/.rcrc` already in place, rcup silently skips everything.
- **Fix:** Run `rcup -d ~/dotfiles` **twice** on first setup. First pass creates parent dirs; second pass links files inside them. Update `AGENTS.md` and add to bootstrap docs.
- **Severity:** blocker

### Gap 2 — Linear OAuth tokens not tracked

- **What was missing:** `mcp-remote` OAuth cache (Linear authentication tokens).
- **Why:** Linear uses browser OAuth; `mcp-remote` stores tokens locally (likely `~/.config/mcp-remote/` or similar). Not tracked.
- **Fix:** Document as a one-time manual step. Identify and potentially track the token cache path if it contains no secrets.
- **Severity:** high (Linear tools unavailable until browser OAuth completed)

### Gap 3 — Claude CLI auth not tracked

- **What was missing:** `~/.claude.json` session token (or `ANTHROPIC_API_KEY`).
- **Why:** OAuth token is device-bound; cannot be copied to another machine.
- **Fix:** Document `claude auth login` as a required post-install step. Support `ANTHROPIC_API_KEY` env var for headless/CI use.
- **Severity:** high (Claude CLI non-functional without login)

### Gap 4 — ruby/lua/postgres fail on minimal Ubuntu (low, non-blocking)

- **What was missing:** Build dependencies (openssl-dev, zlib-dev, etc.) for compiling ruby/postgres; vfox plugin issues for lua.
- **Why:** `config.nixos.toml` disables these on NixOS but that file is not applied on Ubuntu.
- **Fix:** Add `config.ubuntu.toml` with appropriate `disable_tools`, or document required apt packages.
- **Severity:** low (not in MCP critical path)

---

## Known-acknowledged (§6 of test plan)

All confirmed as expected:

1. `~/.config/environment.d/op-service-account.conf` — provisioned manually, works via `environment.d/`.
2. `~/.claude.json` auth — see Gap 3.
3. `~/.gemini/settings.json` — tracked file already contains `mcpServers.mcphub`. **Better than expected:** Gemini MCP is portable without any post-install step.
4. `mise` itself not tracked — bootstrapped in container.
5. `rcm` apt repo down — Ubuntu universe fallback worked.
6. WSL-specific paths — not tested in Ubuntu container (intentional).

---

## Test-plan defects (fixed in `run.sh`)

1. **Missing `--cgroupns=host`** in `docker run`. Required for WSL2 + cgroups v2.
2. **Wrong `tools/list` command**: JSON-RPC POST to `/mcp` returns 404. Hub uses SSE transport; use `/api/servers` REST endpoint or a proper SSE session.
3. **Wrong path**: test plan referenced `~/.gemini.json`; actual path is `~/.gemini/settings.json`.
