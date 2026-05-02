# Fresh-Install Portability Test

> Audience: an autonomous Claude Code agent (model Sonnet) running on the
> user's host machine.
> Goal: verify that a clean machine can stand up the centralized MCP setup
> using only the tracked dotfiles, and produce a report listing any gaps
> (files / env / steps not covered by the repo).
> Last revised: 2026-05-02.

## What "portable" means here

Tracked in `~/dotfiles` and reachable after `rcup`:

- `config/mcphub/servers.json`
- `config/systemd/user/mcp-hub.service`
- `config/mise/conf.d/core.toml` (declares `mcp-hub`, `1password-cli`, `claude`, `gemini-cli`, `node`, …)
- `bin/op-wrapper`
- `claude/mcp.json`, `.gemini.json`, `rcrc`, `zshrc`, etc.

A successful test means: starting from a container that has only the
prereqs listed in **§2**, after running the steps in **§3**, every check
in **§4** passes and a real MCP tool call returns real data.

Anything you had to create, edit, or install **outside the tracked repo**
to make a step pass is a **gap** — record it in the report. The point of
the test is to surface those.

## §1 Operating rules for the agent

- Run steps in order. **Stop and report** as soon as a step fails its
  pass criterion. Do not paper over a failure to keep going.
- One container, one run. Do not retry inside the container after a
  failure — destroy it and start over only if you need to debug.
- Treat every command that requires editing a file outside `~/dotfiles`
  inside the container as a **candidate gap**. Log it (file path,
  reason, what you put in it) even if the step passes.
- Network is allowed. Real API calls (Linear, GitHub) are required for
  §4 step 8.
- Do not push commits, open PRs, or modify the host's running
  `mcp-hub.service`. The host must still work after the test.
- Do not use `--no-verify`, `sudo` on the host, or anything destructive
  on the host. Inside the container, root is fine.

## §2 Prerequisites the test assumes are already satisfied

These are **not** what the test verifies — they are the floor.

| Prereq | How the test gets it |
|---|---|
| Docker daemon on host | Agent confirms `docker info` succeeds before starting. If it does not, **stop and ask the user**. |
| `OP_SERVICE_ACCOUNT_TOKEN` (1Password service account token, scoped to the `Propitech` vault) | Agent reads it from `$OP_SERVICE_ACCOUNT_TOKEN` in the host shell, or from `~/.config/environment.d/op-service-account.conf` on the host. If neither is set, **stop and ask the user** to export it for this session. Never log or commit the value. |
| `git`, `rcm` (rcup), `mise`, `systemd --user` (with linger), `node`, `npm` | Installed inside the container during **§3 Setup**, not assumed on the host. |

If `OP_SERVICE_ACCOUNT_TOKEN` is missing, the test cannot reach §4 step 5
onward — record that as a gap and stop. (The token's absence is a
*known* gap; see §6.)

## §3 Setup — build and start the test container

The container must run `systemd --user` for the `mcp-hub.service` to be
representative. Use a systemd-enabled base image and `--privileged` (or
the equivalent cgroup mounts).

### 3.1 Write a Dockerfile to `/tmp/portability-test/Dockerfile`

```dockerfile
FROM jrei/systemd-ubuntu:24.04
# If jrei/systemd-ubuntu is unavailable, build from ubuntu:24.04 yourself:
#   - ENV container=docker
#   - install systemd + systemd-sysv
#   - mask getty / unwanted units; ENTRYPOINT ["/lib/systemd/systemd"]
# The rest of the test depends on `systemctl --user` working as `tester`.

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git sudo jq build-essential \
      dbus-user-session libnss-systemd \
    && rm -rf /var/lib/apt/lists/*

# Non-root user with linger so `systemctl --user` works without an
# interactive login session.
RUN useradd -m -s /bin/bash tester \
    && echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester \
    && mkdir -p /var/lib/systemd/linger \
    && touch /var/lib/systemd/linger/tester

# rcm
RUN curl -fsSL https://thoughtbot.github.io/rcm/debian/conf/thoughtbot.gpg.key \
      | gpg --dearmor -o /usr/share/keyrings/thoughtbot.gpg \
    && echo 'deb [signed-by=/usr/share/keyrings/thoughtbot.gpg] https://thoughtbot.github.io/rcm/debian ./' \
      > /etc/apt/sources.list.d/rcm.list \
    && apt-get update && apt-get install -y rcm && rm -rf /var/lib/apt/lists/*

# mise (as tester)
USER tester
WORKDIR /home/tester
RUN curl -fsSL https://mise.run | sh
ENV PATH="/home/tester/.local/bin:/home/tester/.local/share/mise/shims:${PATH}"

USER root
```

Build:
```sh
docker build -t dotfiles-portability:latest /tmp/portability-test
```

If the rcm apt repo URL has changed and the build fails on it, that is
**not** a test gap (rcm is a host-prereq). Try installing rcm via
`gem install rcm` or another mechanism; record what you did.

### 3.2 Start the container

```sh
docker run -d --name dotfiles-portability \
  --privileged \
  --tmpfs /run --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -e OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" \
  dotfiles-portability:latest
```

Wait until `docker exec dotfiles-portability systemctl is-system-running`
returns `running` or `degraded` (degraded is acceptable; the host's
network-online targets are not relevant here).

### 3.3 Open a working shell as `tester`

Every command in §4 runs as:
```sh
docker exec -u tester -it dotfiles-portability bash -lc '<cmd>'
```
or via a heredoc when multi-line. `-u tester` is required so
`systemctl --user` targets the tester's manager.

## §4 Test steps

For each step: run the command, check the pass criterion, log the
result, and if it fails, **stop**.

### Step 1 — Clone the dotfiles repo

```sh
git clone https://github.com/<USER>/dotfiles.git ~/dotfiles
cd ~/dotfiles && git checkout <BRANCH>
```

The agent must use the branch the user currently has checked out on the
host (run `git -C ~/dotfiles rev-parse --abbrev-ref HEAD` on the host
first; pass that as `<BRANCH>`). If the branch is not pushed, agent
should `docker cp` the working tree in instead and **record this as a
gap** ("a fresh machine cannot reach this branch via git remote").

**Pass:** repo present at `/home/tester/dotfiles`, working tree clean.

### Step 2 — Run rcup

```sh
cd ~/dotfiles && rcup -v
```

**Pass:** exits 0. The following symlinks all resolve to files inside
`~/dotfiles`:

- `~/.rcrc`
- `~/.config/mcphub/servers.json`
- `~/.config/systemd/user/mcp-hub.service`
- `~/.config/mise/conf.d/core.toml`
- `~/.bin/op-wrapper`
- `~/.claude/mcp.json`
- `~/.gemini.json`

If any expected symlink is missing or points elsewhere, that is the
primary kind of gap this test is looking for — record the file, where
it ended up (or didn't), and continue if possible.

### Step 3 — Install tools via mise

```sh
cd ~/dotfiles && mise install
```

**Pass:** exits 0. After install:
- `mise which mcp-hub` → resolves
- `mise which op` → resolves
- `mise which claude` → resolves
- `mise which gemini` → resolves
- `mise which node` → resolves

Gap signal: any tool listed in `config/mise/conf.d/core.toml` that fails
to install. Record the tool and the error. Do not retry by editing the
toml — the toml is the source of truth.

### Step 4 — Provision the OP service-account token

Create `~/.config/environment.d/op-service-account.conf` with:
```
OP_SERVICE_ACCOUNT_TOKEN=<value-passed-via-docker-env>
```
Then `systemctl --user daemon-reload`.

This step is **a known gap** (the file is intentionally not tracked
because it contains a secret). Record it as such — but the test plan
itself must execute the step so later checks can run. The gap report
should note: "This file is required, intentionally not tracked. Need
to confirm the README / setup docs explain this for new machines."

Verify the token is visible to the user's systemd manager:
```sh
systemctl --user show-environment | grep OP_SERVICE_ACCOUNT_TOKEN
```
If the variable is not present, `environment.d/` integration is broken
in this image — record exactly what you had to do instead (e.g.,
`systemctl --user import-environment OP_SERVICE_ACCOUNT_TOKEN` or
adding `Environment=` to a drop-in). That is a real gap.

### Step 5 — Enable and start mcp-hub.service

```sh
systemctl --user daemon-reload
systemctl --user enable --now mcp-hub.service
sleep 2
systemctl --user is-active mcp-hub.service
```

**Pass:** `is-active` prints `active`. No errors in
`journalctl --user -u mcp-hub.service -n 100`.

Gap signal: any path in the unit that does not resolve (binary path,
config path) — capture the journal excerpt and the resolved path.

### Step 6 — Hub health and tool aggregation

```sh
curl -fsS http://localhost:37373/api/health | jq -r .status
curl -fsS -X POST http://localhost:37373/mcp \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  | jq '.result.tools | length'
```

**Pass:** health is `ok`; tools count is `> 0` and includes at least one
tool each from figma, github, and linear (grep names). If a server is
listed in `servers.json` but produces zero tools, inspect the journal
— most likely cause is `op-wrapper` failing to resolve a secret for
that server. Record the failure mode.

### Step 7 — Claude and Gemini CLIs see the hub

```sh
claude mcp list
gemini mcp list
```

Note: these CLIs read user-level config (`~/.claude.json`,
`~/.gemini/settings.json`), which is **not tracked**. The tracked files
are `claude/mcp.json` and `.gemini.json`, which are project-scoped /
`--mcp-config`-scoped pointers. Expect the user-level `mcp list` to
show *nothing* on a fresh machine.

The agent must run, in this order:
```sh
claude mcp add --transport sse mcphub http://localhost:37373/mcp
gemini mcp add --transport sse mcphub http://localhost:37373/mcp
```
…and **record this as a gap**: a fresh install does not have the
mcphub registration in `~/.claude.json` or `~/.gemini/settings.json`,
even though the project-scoped tracked configs have it. (Decide
whether the canonical fix is to commit those user-level configs, add
a post-`rcup` hook, or document the manual step.)

**Pass:** after registration, both `mcp list` commands show `mcphub`
pointing at `http://localhost:37373/mcp`.

### Step 8 — Real MCP tool call (E2E)

Choose a read-only tool that proves credentials and routing both work:

```sh
claude --print --mcp-config ~/.claude/mcp.json \
  --allowedTools 'mcp__mcphub__github__get_me' \
  'Call the mcp__mcphub__github__get_me tool and return only the GitHub login it reports.'
```

Then a Linear read:
```sh
claude --print --mcp-config ~/.claude/mcp.json \
  --allowedTools 'mcp__mcphub__linear__list_teams' \
  'Call mcp__mcphub__linear__list_teams and return the JSON.'
```

**Pass:** both calls return real data (a real GitHub login, a non-empty
team list). Errors that mention authentication mean a secret did not
resolve — that is a hub/secret problem, not a portability gap, but
still record it.

If `claude --print` is missing or behaves differently from the host
version, record the `claude --version` you got from `mise install`
versus the host's.

### Step 9 — Survives a service restart

```sh
systemctl --user restart mcp-hub.service
sleep 3
systemctl --user is-active mcp-hub.service
curl -fsS http://localhost:37373/api/health | jq -r .status
```

**Pass:** `active` and `ok`.

(Container reboot is not part of this test — Docker container restart
re-runs the entrypoint and is environment-specific. The systemd unit
restart above is sufficient evidence that linger + the unit's
`[Install]` section are correct.)

## §5 Report format

Write the report to `/tmp/portability-report.md` inside the container,
then `docker cp` it back to the host at
`~/dotfiles/docs/testing/last-run-report.md` (this file is gitignored
or manually excluded — do not commit it). Also print the report to
stdout for the user.

Structure:

```markdown
# Portability test run — <ISO date>

Branch: <branch> @ <short-sha>
Image: <docker image tag>
Outcome: PASS | PARTIAL | FAIL

## Steps

| # | Step | Status | Notes |
|---|------|--------|-------|
| 1 | Clone dotfiles | PASS | |
| 2 | rcup | PASS | |
| ... | | | |

## Gaps

For every gap, one entry. Sort by severity (blocker → nit).

### Gap N — <short title>

- **What was missing:** <file / env var / step>
- **What I had to do:** <exact action taken>
- **Why it matters:** <does it block install, degrade UX, leak secrets, etc.>
- **Suggested fix:** <track file in repo / add bootstrap script /
  document manual step / out-of-scope>
- **Severity:** blocker | high | medium | low

## Known-acknowledged (not new gaps)

List of known gaps from §6 that were observed but already understood.
Don't re-investigate these unless something changed.

## Raw artifacts

- `journalctl --user -u mcp-hub.service` (last 200 lines)
- `mise ls` output
- `rcup -v` output
- Anything else that informs the gaps above
```

## §6 Known-acknowledged gaps (do not flag as new)

The following are already known and intentional. Record that you
observed them, but do not present them as discoveries.

1. `~/.config/environment.d/op-service-account.conf` is not tracked
   (contains a secret). A new machine must provision it out-of-band.
2. `~/.claude.json` and `~/.gemini/settings.json` are user-level CLI
   configs that are not tracked. They must be created with
   `claude mcp add` / `gemini mcp add` after install. (Open question
   whether to track them or auto-populate via a hook — out of scope
   for this test.)
3. `mise` itself is not tracked (it bootstraps the rest).
4. `rcm` itself is not tracked (it bootstraps the symlinks).
5. The Docker image used for the test is not tracked. The `Dockerfile`
   in §3 is allowed to live outside the repo — its purpose is to
   simulate a fresh machine, not to be deployed.
6. WSL-specific concerns (`/etc/wsl.conf`, `op.exe` interop) are not
   exercised by this test. `op-wrapper`'s WSL branch is unreachable in
   a Linux container; that is intentional. A separate WSL test would
   be needed to cover those paths.

## §7 Cleanup

```sh
docker rm -f dotfiles-portability
docker image rm dotfiles-portability:latest   # optional
rm -rf /tmp/portability-test
```

Confirm the host's `mcp-hub.service` is still active:
```sh
systemctl --user is-active mcp-hub.service   # on the host
```
If the host service was somehow disturbed, that is a **bug in the
test plan** — flag it to the user immediately.

## §8 If something is unclear

Stop and ask the user. Do not silently choose an interpretation that
makes a step pass — that defeats the test. Examples of things worth
asking:

- The current branch is not pushed. Should I `docker cp` the working
  tree, or wait for you to push?
- `OP_SERVICE_ACCOUNT_TOKEN` is not set in this shell. Where do you
  want me to source it from?
- A step's expected file path differs from what I find in the repo
  (e.g., `bin/op-wrapper` symlinks to `~/bin/op-wrapper` instead of
  `~/.bin/op-wrapper`). Which is current?
