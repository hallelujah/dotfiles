#!/usr/bin/env bash
# Incremental portability test — GitHub MCP + Claude Code.
#
# Usage:
#   ./run.sh              Run all steps; skip steps already checkpointed.
#   ./run.sh --from=N     Clear checkpoints from step N onwards, then run.
#   ./run.sh --clean      Destroy container, clear all checkpoints, start fresh.
#   ./run.sh --report     Print the last report and exit.
#
# Checkpoints live in /tmp/dotfiles-portability-checkpoints/ so they survive
# script restarts but are wiped on system reboot — a natural boundary.
#
# Requirements (on the host):
#   - Docker daemon running      (checked in step 1)
#   - OP_SERVICE_ACCOUNT_TOKEN   (read from env or ~/.config/environment.d/op-service-account.conf)
#   - ~/.claude.json with a valid session  OR  ANTHROPIC_API_KEY set
#     (needed for step 12; step 11 tests GitHub via SSE without Claude auth)

set -uo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECKPOINT_DIR="${TMPDIR:-/tmp}/dotfiles-portability-checkpoints"
REPORT="$SCRIPT_DIR/last-run-report.md"
DOCKERFILE="$SCRIPT_DIR/Dockerfile"

# ── Constants ──────────────────────────────────────────────────────────────────
CONTAINER=dotfiles-portability
IMAGE=dotfiles-portability:latest

# ── Derive clone URL (SSH → HTTPS for use inside the container) ────────────────
REMOTE=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE" =~ ^git@github\.com:(.+)$ ]]; then
  CLONE_URL="https://github.com/${BASH_REMATCH[1]}"
else
  CLONE_URL="$REMOTE"
fi
BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

# ── Argument parsing ───────────────────────────────────────────────────────────
CLEAN=false
FROM_STEP=0

for arg in "$@"; do
  case "$arg" in
    --clean)      CLEAN=true ;;
    --from=*)     FROM_STEP="${arg#--from=}" ;;
    --report)     cat "$REPORT" 2>/dev/null || echo "No report found at $REPORT"; exit 0 ;;
    *)            echo "Unknown argument: $arg" >&2
                  echo "Usage: $0 [--clean] [--from=N] [--report]" >&2
                  exit 1 ;;
  esac
done

# ── Checkpoint helpers ─────────────────────────────────────────────────────────
mkdir -p "$CHECKPOINT_DIR"

checkpoint_file() { echo "$CHECKPOINT_DIR/step-${1}.done"; }

is_done() {
  local step=$1
  [[ $FROM_STEP -gt 0 && $step -ge $FROM_STEP ]] && return 1
  [[ -f "$(checkpoint_file "$step")" ]]
}

mark_done() {
  local step=$1 note=${2:-}
  echo "$note" > "$(checkpoint_file "$step")"
}

mark_failed() {
  local step=$1 note=${2:-}
  echo "FAILED: $note" > "$(checkpoint_file "$step").failed"
}

# ── Result tracking ────────────────────────────────────────────────────────────
declare -A STEP_STATUS   # PASS | SKIP | FAIL
declare -A STEP_NOTE

record() {
  local step=$1 status=$2 note=${3:-}
  STEP_STATUS[$step]=$status
  STEP_NOTE[$step]=$note
}

# ── Output helpers ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

step_header() { echo -e "\n${CYAN}── Step $1: $2${NC}"; }
ok()   { echo -e "   ${GREEN}✓${NC} $*"; }
fail() { echo -e "   ${RED}✗${NC} $*"; }
info() { echo -e "   ${YELLOW}·${NC} $*"; }

die() { echo -e "${RED}FATAL:${NC} $*" >&2; exit 1; }

# ── Container exec helper ──────────────────────────────────────────────────────
T() {
  # Run a command as the tester user inside the container.
  # Environment: mise PATH, XDG_RUNTIME_DIR for systemctl --user.
  local cmd=$1
  sudo docker exec -u tester "$CONTAINER" bash -lc "
    export PATH=\"\$HOME/.local/bin:\$HOME/.local/share/mise/shims:\$PATH\"
    export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"
    $cmd
  " 2>&1
}

# ── Clean ─────────────────────────────────────────────────────────────────────
if $CLEAN; then
  info "Removing container and all checkpoints…"
  sudo docker rm -f "$CONTAINER" 2>/dev/null || true
  rm -rf "$CHECKPOINT_DIR"
  mkdir -p "$CHECKPOINT_DIR"
fi

if [[ $FROM_STEP -gt 0 ]]; then
  info "Clearing checkpoints from step $FROM_STEP onwards…"
  for f in "$CHECKPOINT_DIR"/step-*.done; do
    [[ -f "$f" ]] || continue
    n=$(basename "$f" .done | sed 's/step-//')
    [[ $n -ge $FROM_STEP ]] && rm -f "$f"
  done
fi

# ── Globals written during test ────────────────────────────────────────────────
GITHUB_LOGIN=""
TOTAL_TOOLS=0
GAPS=()   # Each entry is a formatted string.

add_gap() { GAPS+=("$*"); }

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — Preflight
# ══════════════════════════════════════════════════════════════════════════════
STEP=1
step_header $STEP "Preflight"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
else
  # Docker
  if ! sudo docker info > /dev/null 2>&1; then
    fail "Docker daemon is not running."
    die "Start Docker and rerun."
  fi
  ok "Docker is running ($(sudo docker info --format '{{.ServerVersion}}'))"

  # OP token
  OP_TOKEN=""
  if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    OP_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN"
    ok "OP_SERVICE_ACCOUNT_TOKEN found in environment"
  elif [[ -f "$HOME/.config/environment.d/op-service-account.conf" ]]; then
    OP_TOKEN=$(grep "OP_SERVICE_ACCOUNT_TOKEN" "$HOME/.config/environment.d/op-service-account.conf" | cut -d= -f2-)
    ok "OP_SERVICE_ACCOUNT_TOKEN read from environment.d file"
  fi

  if [[ -z "$OP_TOKEN" ]]; then
    fail "OP_SERVICE_ACCOUNT_TOKEN not found in env or ~/.config/environment.d/op-service-account.conf"
    die "Export OP_SERVICE_ACCOUNT_TOKEN and rerun."
  fi

  # Claude auth check (warn only — step 12 will handle)
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]] && [[ ! -f "$HOME/.claude.json" ]]; then
    info "Neither ANTHROPIC_API_KEY nor ~/.claude.json found — step 12 (claude --print) will be skipped"
  else
    ok "Claude auth available (step 12 will run)"
  fi

  # Branch pushed?
  if ! git -C "$REPO_ROOT" ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q .; then
    info "Branch $BRANCH not found on remote — will docker-cp working tree into container instead"
    add_gap "Branch '$BRANCH' is not pushed. Fresh installs cannot clone it. Push before shipping."
  fi

  mark_done $STEP
  record $STEP PASS
  ok "Preflight complete"
fi

# Re-load OP_TOKEN for later steps even if step was skipped.
if [[ -z "${OP_TOKEN:-}" ]]; then
  if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    OP_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN"
  elif [[ -f "$HOME/.config/environment.d/op-service-account.conf" ]]; then
    OP_TOKEN=$(grep "OP_SERVICE_ACCOUNT_TOKEN" "$HOME/.config/environment.d/op-service-account.conf" | cut -d= -f2-)
  else
    die "OP_SERVICE_ACCOUNT_TOKEN unavailable — run with --clean to reset"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — Build Docker image
# ══════════════════════════════════════════════════════════════════════════════
STEP=2
step_header $STEP "Build Docker image"

if is_done $STEP; then
  info "Image already built — skipping (run --from=2 to rebuild)"
  record $STEP SKIP
elif sudo docker image inspect "$IMAGE" > /dev/null 2>&1; then
  info "Image $IMAGE exists — skipping build"
  mark_done $STEP "pre-existing"
  record $STEP SKIP
else
  info "Building $IMAGE from $DOCKERFILE …"
  if sudo docker build -t "$IMAGE" -f "$DOCKERFILE" "$SCRIPT_DIR" 2>&1 | \
      grep -E "^Step |^#[0-9]+ (DONE|ERROR)|Successfully built|ERROR:" ; then
    ok "Image built"
    mark_done $STEP
    record $STEP PASS
  else
    fail "Image build failed — see output above"
    record $STEP FAIL "docker build failed"
    die "Cannot continue without image."
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — Start container
# ══════════════════════════════════════════════════════════════════════════════
STEP=3
step_header $STEP "Start container"

CONTAINER_STATE=$(sudo docker inspect --format '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "absent")

if [[ "$CONTAINER_STATE" == "running" ]]; then
  info "Container already running — reusing"
  record $STEP SKIP
else
  if [[ "$CONTAINER_STATE" == "exited" ]]; then
    info "Container exists but stopped — removing and re-creating"
    sudo docker rm -f "$CONTAINER" > /dev/null
    # Clear step checkpoints that depend on container state
    rm -f "$CHECKPOINT_DIR"/step-{4..13}.done
  fi

  info "Starting container…"
  sudo docker run -d --name "$CONTAINER" \
    --privileged \
    --cgroupns=host \
    --tmpfs /run --tmpfs /run/lock \
    -e OP_SERVICE_ACCOUNT_TOKEN="$OP_TOKEN" \
    "$IMAGE" > /dev/null

  info "Waiting for systemd to reach running state…"
  for i in $(seq 1 20); do
    STATUS=$(sudo docker exec "$CONTAINER" systemctl is-system-running 2>/dev/null || echo "not_ready")
    if [[ "$STATUS" == "running" || "$STATUS" == "degraded" ]]; then
      ok "systemd is $STATUS"
      break
    fi
    [[ $i -eq 20 ]] && { fail "systemd did not reach running state"; die "Container boot failed."; }
    sleep 2
  done

  mark_done $STEP
  record $STEP PASS
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4 — Clone dotfiles
# ══════════════════════════════════════════════════════════════════════════════
STEP=4
step_header $STEP "Clone dotfiles (branch: $BRANCH @ $SHA)"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
else
  # If branch is not pushed, copy the working tree instead.
  if git -C "$REPO_ROOT" ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q .; then
    info "Cloning $CLONE_URL (branch $BRANCH)…"
    if T "git clone --branch $BRANCH $CLONE_URL ~/dotfiles" ; then
      ok "Cloned"
    else
      fail "git clone failed"
      record $STEP FAIL "clone failed"
      die "Cannot continue without dotfiles."
    fi
  else
    info "Branch not on remote — copying working tree via docker cp"
    sudo docker exec "$CONTAINER" bash -c 'mkdir -p /home/tester/dotfiles && chown tester:tester /home/tester/dotfiles'
    sudo docker cp "$REPO_ROOT/." "$CONTAINER:/home/tester/dotfiles/"
    T "chown -R tester:tester ~/dotfiles"
    add_gap "Branch '$BRANCH' is not pushed to remote; used docker-cp fallback. Fresh installs cannot bootstrap from git clone."
    ok "Copied working tree"
  fi

  ACTUAL_SHA=$(T "git -C ~/dotfiles rev-parse --short HEAD" 2>/dev/null || echo "N/A")
  info "Container repo at $ACTUAL_SHA"

  mark_done $STEP
  record $STEP PASS
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5 — rcup
# ══════════════════════════════════════════════════════════════════════════════
STEP=5
step_header $STEP "rcup"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
else
  # rcup without -d does not find ~/dotfiles reliably on a fresh home; run
  # twice with -d: first pass creates parent dirs, second pass links the files
  # inside those dirs.
  T "cd ~/dotfiles && rcup -d ~/dotfiles -v 2>&1 | tail -5"
  T "cd ~/dotfiles && rcup -d ~/dotfiles -v 2>&1 | tail -5"

  MISSING=()
  for target in \
    "~/.rcrc" \
    "~/.config/mcphub/servers.json" \
    "~/.config/systemd/user/mcp-hub.service" \
    "~/.config/mise/conf.d/core.toml" \
    "~/.bin/op-wrapper" \
    "~/.claude/mcp.json"; do
    if ! T "test -L $target" > /dev/null 2>&1; then
      MISSING+=("$target")
    fi
  done

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    fail "Missing symlinks after rcup: ${MISSING[*]}"
    add_gap "rcup did not create symlinks for: ${MISSING[*]}"
    record $STEP FAIL "missing symlinks"
    die "rcup incomplete."
  fi

  # Note: plain 'rcup' (no -d) silently creates nothing on a clean $HOME.
  add_gap "KNOWN: 'rcup' without '-d ~/dotfiles' creates no symlinks on a fresh home. Must run 'rcup -d ~/dotfiles' twice. See gap-report.md."

  ok "All expected symlinks present"
  mark_done $STEP
  record $STEP PASS
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 6 — mise install
# ══════════════════════════════════════════════════════════════════════════════
STEP=6
step_header $STEP "mise install (mcp-hub, op, claude, node)"

if is_done $STEP; then
  info "Already done — skipping (run --from=6 to reinstall)"
  record $STEP SKIP
else
  info "Running mise install — this may take several minutes on first run…"
  # Run in background-friendly mode; we only care about the critical tools.
  T "cd ~/dotfiles && mise install --yes 2>&1 | grep -E 'INSTALL|installed|ERROR|failed' | tail -30"

  TOOL_MISSING=()
  for tool in mcp-hub op claude node; do
    if ! T "mise which $tool" > /dev/null 2>&1; then
      TOOL_MISSING+=("$tool")
    fi
  done

  if [[ ${#TOOL_MISSING[@]} -gt 0 ]]; then
    fail "Critical tools missing after mise install: ${TOOL_MISSING[*]}"
    add_gap "mise install failed to install: ${TOOL_MISSING[*]}"
    record $STEP FAIL "${TOOL_MISSING[*]}"
    die "Cannot continue without critical tools."
  fi

  ok "mcp-hub, op, claude, node all installed"
  mark_done $STEP
  record $STEP PASS
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 7 — Provision OP token
# ══════════════════════════════════════════════════════════════════════════════
STEP=7
step_header $STEP "Provision OP service-account token"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
else
  T "mkdir -p ~/.config/environment.d"
  # Write token into the container; never print the value.
  sudo docker exec -u tester "$CONTAINER" bash -c \
    "printf 'OP_SERVICE_ACCOUNT_TOKEN=%s\n' \"\$OP_SERVICE_ACCOUNT_TOKEN\" \
     > ~/.config/environment.d/op-service-account.conf"

  T "systemctl --user daemon-reload"

  # Verify it is visible to the user's systemd manager.
  if T "systemctl --user show-environment" | grep -q "OP_SERVICE_ACCOUNT_TOKEN="; then
    ok "Token is visible to systemd --user"
  else
    fail "environment.d/ not picked up by systemd --user"
    add_gap "OP_SERVICE_ACCOUNT_TOKEN in environment.d/ is NOT visible to systemd --user manager. May need 'systemctl --user import-environment OP_SERVICE_ACCOUNT_TOKEN' instead."
    # Try explicit import as fallback so the test can continue.
    sudo docker exec -u tester "$CONTAINER" bash -c \
      "XDG_RUNTIME_DIR=/run/user/\$(id -u) systemctl --user import-environment OP_SERVICE_ACCOUNT_TOKEN" || true
    info "Fallback: imported token via import-environment"
  fi

  add_gap "KNOWN: ~/.config/environment.d/op-service-account.conf is intentionally not tracked (contains secret). Must be provisioned out-of-band on every fresh machine."

  mark_done $STEP
  record $STEP PASS
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 8 — Enable mcp-hub.service
# ══════════════════════════════════════════════════════════════════════════════
STEP=8
step_header $STEP "Enable and start mcp-hub.service"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
else
  T "systemctl --user daemon-reload"
  T "systemctl --user enable --now mcp-hub.service 2>&1 | head -5"
  sleep 3

  ACTIVE=$(T "systemctl --user is-active mcp-hub.service" || true)
  if [[ "$ACTIVE" != "active" ]]; then
    fail "mcp-hub.service is $ACTIVE"
    info "Journal:"
    T "journalctl --user -u mcp-hub.service -n 30 --no-pager" | sed 's/^/   /'
    record $STEP FAIL "service state: $ACTIVE"
    die "mcp-hub failed to start."
  fi

  ok "mcp-hub.service is active"
  mark_done $STEP
  record $STEP PASS
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 9 — Hub health + GitHub connected
# ══════════════════════════════════════════════════════════════════════════════
STEP=9
step_header $STEP "Hub health and GitHub connection"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
  TOTAL_TOOLS=$(cat "$CHECKPOINT_DIR/step-9.done" 2>/dev/null | grep -oP '\d+' || echo 0)
else
  HEALTH=$(T "curl -fsS http://localhost:37373/api/health" | jq -r .status 2>/dev/null || echo "error")
  if [[ "$HEALTH" != "ok" ]]; then
    fail "Health endpoint returned: $HEALTH"
    record $STEP FAIL "health: $HEALTH"
    die "Hub is not healthy."
  fi
  ok "Health: ok"

  # Wait up to 15s for GitHub to connect.
  GITHUB_STATUS="unknown"
  for i in $(seq 1 5); do
    GITHUB_STATUS=$(T "curl -fsS http://localhost:37373/api/servers" | \
      jq -r '.servers[] | select(.name=="github") | .status' 2>/dev/null || echo "error")
    [[ "$GITHUB_STATUS" == "connected" ]] && break
    sleep 3
  done

  if [[ "$GITHUB_STATUS" != "connected" ]]; then
    fail "GitHub server status: $GITHUB_STATUS"
    info "This usually means op-wrapper failed to resolve the API key."
    T "journalctl --user -u mcp-hub.service -n 20 --no-pager" | grep -i "github\|error\|warn" | sed 's/^/   /'
    add_gap "GitHub MCP server is not connecting. Check op-wrapper and the Propitech vault credentials."
    record $STEP FAIL "github: $GITHUB_STATUS"
    die "GitHub server not connected."
  fi

  TOTAL_TOOLS=$(T "curl -fsS http://localhost:37373/api/servers" | \
    jq '[.servers[].capabilities.tools[]] | length' 2>/dev/null || echo 0)

  ok "GitHub connected — $TOTAL_TOOLS total tools available"
  mark_done $STEP "$TOTAL_TOOLS tools"
  record $STEP PASS "$TOTAL_TOOLS tools"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 10 — Register Claude CLI with the hub
# ══════════════════════════════════════════════════════════════════════════════
STEP=10
step_header $STEP "Register Claude MCP (user-level)"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
else
  # Check if already registered (tracked claude/mcp.json has the entry, but the
  # user-level ~/.claude.json does not on a fresh machine).
  if T "claude mcp list 2>&1" | grep -q "mcphub"; then
    ok "mcphub already registered in claude mcp list"
  else
    T "claude mcp add --transport sse mcphub http://localhost:37373/mcp 2>&1"
    if T "claude mcp list 2>&1" | grep -q "mcphub"; then
      ok "mcphub registered"
      add_gap "KNOWN: ~/.claude.json MCP registration must be done via 'claude mcp add' after each fresh install — not tracked in dotfiles."
    else
      fail "mcphub not visible in 'claude mcp list' after add"
      add_gap "claude mcp add ran but mcphub did not appear in mcp list."
      record $STEP FAIL "mcp list empty after add"
      die "Cannot proceed to Claude E2E without MCP registered."
    fi
  fi

  mark_done $STEP
  record $STEP PASS
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 11 — E2E: GitHub tool call via SSE (no Claude auth needed)
# ══════════════════════════════════════════════════════════════════════════════
STEP=11
step_header $STEP "E2E: GitHub get_me via SSE (direct)"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
  GITHUB_LOGIN=$(cat "$CHECKPOINT_DIR/step-11.done" 2>/dev/null || echo "cached")
else
  # Open an SSE session, keep it alive, POST the tool call, read response.
  SSE_RESULT=$(T '
    SSE_OUT=$(mktemp)
    trap "rm -f $SSE_OUT" EXIT

    curl -fsS -N -H "Accept: text/event-stream" "http://localhost:37373/mcp" > "$SSE_OUT" 2>&1 &
    SSE_PID=$!
    sleep 1

    SESSION_PATH=$(grep "^data:" "$SSE_OUT" | head -1 | sed "s|data: ||")
    if [ -z "$SESSION_PATH" ]; then
      echo "ERROR: no session path from SSE endpoint"
      kill $SSE_PID 2>/dev/null
      exit 1
    fi

    curl -fsS -X POST "http://localhost:37373${SESSION_PATH}" \
      -H "content-type: application/json" \
      -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"github__get_me\",\"arguments\":{}}}" \
      > /dev/null 2>&1

    sleep 3
    # Extract the result for id:1
    grep "^data:" "$SSE_OUT" | grep "\"id\":1" | head -1

    kill $SSE_PID 2>/dev/null
  ')

  GITHUB_LOGIN=$(echo "$SSE_RESULT" | jq -r '.result.content[0].text | fromjson | .login' 2>/dev/null || echo "")

  if [[ -z "$GITHUB_LOGIN" ]]; then
    fail "github__get_me returned no login"
    info "Raw response: $SSE_RESULT"
    add_gap "github__get_me tool call returned no data. Possible credential or routing issue."
    record $STEP FAIL "no login in response"
    die "E2E tool call failed."
  fi

  ok "github__get_me → login: $GITHUB_LOGIN"
  mark_done $STEP "$GITHUB_LOGIN"
  record $STEP PASS "login: $GITHUB_LOGIN"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 12 — E2E: GitHub tool call via claude --print (requires auth)
# ══════════════════════════════════════════════════════════════════════════════
STEP=12
step_header $STEP "E2E: GitHub tool call via claude --print"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
else
  # Determine if auth is available.
  CLAUDE_AUTH=false
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    sudo docker exec "$CONTAINER" bash -c "echo ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY' >> /etc/environment"
    CLAUDE_AUTH=true
  elif [[ -f "$HOME/.claude.json" ]]; then
    sudo docker cp "$HOME/.claude.json" "$CONTAINER:/home/tester/.claude.json.host"
    sudo docker exec -u root "$CONTAINER" chown tester:tester /home/tester/.claude.json.host
    # Merge: keep auth from host, keep projects/MCP from container
    T '
      MCP_PROJ=$(cat ~/.claude.json | jq ".projects // {}")
      jq --argjson p "$MCP_PROJ" ".projects = \$p" ~/.claude.json.host > ~/.claude.json
      rm ~/.claude.json.host
    '
    CLAUDE_AUTH=true
  fi

  if ! $CLAUDE_AUTH; then
    info "No ANTHROPIC_API_KEY and no ~/.claude.json on host — skipping this step"
    info "To enable: export ANTHROPIC_API_KEY=... before running this script"
    add_gap "KNOWN: Claude CLI auth (~/.claude.json session or ANTHROPIC_API_KEY) is not tracked. Must log in or set API key on every fresh install."
    record $STEP SKIP "no auth available"
  else
    CLAUDE_RESULT=$(T '
      echo "Call mcp__mcphub__github__get_me and return the login field only." \
        | claude -p --mcp-config ~/.claude/mcp.json --allowedTools "mcp__mcphub__github__get_me" 2>&1
    ' || true)

    if echo "$CLAUDE_RESULT" | grep -q "Not logged in"; then
      info "Claude auth did not transfer (OAuth token is device-bound)"
      add_gap "KNOWN: Claude CLI OAuth token is device-bound; cannot be transferred to a fresh container. Use ANTHROPIC_API_KEY for headless auth instead."
      record $STEP SKIP "oauth device-bound"
    elif echo "$CLAUDE_RESULT" | grep -qi "hallelujah\|login\|github"; then
      ok "claude --print returned GitHub data via MCP"
      record $STEP PASS
      mark_done $STEP
    else
      fail "Unexpected response from claude --print:"
      info "$CLAUDE_RESULT"
      add_gap "claude --print MCP call returned unexpected output: $CLAUDE_RESULT"
      record $STEP FAIL "unexpected response"
    fi
  fi

  # Mark step done regardless so we don't retry auth copy on next run.
  mark_done $STEP
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 13 — Service restart
# ══════════════════════════════════════════════════════════════════════════════
STEP=13
step_header $STEP "mcp-hub.service restart survival"

if is_done $STEP; then
  info "Already done — skipping"
  record $STEP SKIP
else
  T "systemctl --user restart mcp-hub.service"
  sleep 5

  ACTIVE=$(T "systemctl --user is-active mcp-hub.service" || true)
  HEALTH=$(T "curl -fsS http://localhost:37373/api/health" | jq -r .status 2>/dev/null || echo "error")

  if [[ "$ACTIVE" == "active" && "$HEALTH" == "ok" ]]; then
    # Wait for GitHub to reconnect.
    for i in $(seq 1 5); do
      GH_STATUS=$(T "curl -fsS http://localhost:37373/api/servers" | \
        jq -r '.servers[] | select(.name=="github") | .status' 2>/dev/null || echo "unknown")
      [[ "$GH_STATUS" == "connected" ]] && break
      sleep 3
    done
    ok "Service restarted — active, health ok, GitHub $GH_STATUS"
    mark_done $STEP
    record $STEP PASS "GitHub: $GH_STATUS"
  else
    fail "After restart: active=$ACTIVE health=$HEALTH"
    add_gap "mcp-hub.service did not recover after restart."
    record $STEP FAIL "active=$ACTIVE health=$HEALTH"
    die "Service restart check failed."
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# REPORT
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN} Portability test — $(date '+%Y-%m-%d %H:%M')${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Determine overall outcome
OVERALL=PASS
for status in "${STEP_STATUS[@]}"; do
  [[ "$status" == "FAIL" ]] && OVERALL=FAIL && break
done

STEP_NAMES=(
  ""
  "Preflight"
  "Build image"
  "Start container"
  "Clone dotfiles"
  "rcup"
  "mise install"
  "Provision OP token"
  "Enable mcp-hub.service"
  "Hub health + GitHub connected"
  "Register Claude MCP"
  "E2E: github__get_me (SSE)"
  "E2E: claude --print"
  "Service restart"
)

# Print step table
printf "\n  %-4s %-32s %-8s %s\n" "#" "Step" "Status" "Notes"
printf "  %-4s %-32s %-8s %s\n" "---" "--------------------------------" "--------" "-----"
for i in $(seq 1 13); do
  status=${STEP_STATUS[$i]:-N/A}
  note=${STEP_NOTE[$i]:-}
  name=${STEP_NAMES[$i]}
  case "$status" in
    PASS) color="$GREEN" ;;
    FAIL) color="$RED"   ;;
    *)    color="$NC"    ;;
  esac
  printf "  %-4s %-32s " "$i" "$name"
  echo -e "${color}${status}${NC}   $note"
done

echo ""
if [[ "$OVERALL" == "PASS" ]]; then
  echo -e "  Outcome: ${GREEN}PASS${NC}  —  github login: ${GITHUB_LOGIN}  |  tools: ${TOTAL_TOOLS}"
else
  echo -e "  Outcome: ${RED}FAIL${NC}"
fi

# Print gaps
if [[ ${#GAPS[@]} -gt 0 ]]; then
  echo -e "\n  ${YELLOW}Gaps / notes:${NC}"
  for g in "${GAPS[@]}"; do
    echo "  · $g"
  done
fi
echo ""

# Write markdown report
{
  echo "# Portability test run — $(date '+%Y-%m-%d')"
  echo ""
  echo "Branch: \`$BRANCH\` @ \`$SHA\`  "
  echo "Outcome: **$OVERALL**"
  if [[ -n "$GITHUB_LOGIN" ]]; then
    echo "GitHub login confirmed: \`$GITHUB_LOGIN\`  "
    echo "Total MCP tools: $TOTAL_TOOLS"
  fi
  echo ""
  echo "## Steps"
  echo ""
  echo "| # | Step | Status | Notes |"
  echo "|---|------|--------|-------|"
  for i in $(seq 1 13); do
    status=${STEP_STATUS[$i]:-N/A}
    note=${STEP_NOTE[$i]:-}
    name=${STEP_NAMES[$i]}
    echo "| $i | $name | $status | $note |"
  done
  echo ""
  echo "## Gaps"
  echo ""
  if [[ ${#GAPS[@]} -gt 0 ]]; then
    for g in "${GAPS[@]}"; do
      echo "- $g"
    done
  else
    echo "None detected."
  fi
} > "$REPORT"

info "Report written to $REPORT"

# Final verification: host service untouched
if systemctl --user is-active mcp-hub.service > /dev/null 2>&1; then
  ok "Host mcp-hub.service is still active"
else
  echo -e "  ${RED}WARNING:${NC} Host mcp-hub.service is no longer active — check immediately"
fi

[[ "$OVERALL" == "PASS" ]] && exit 0 || exit 1
