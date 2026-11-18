#!/bin/bash
# Start an implementer worker in hc, parented to THIS session (never a stale address).
#   tool/spawn_worker.sh <name> <worktree> [sonnet]
# Then: accept the folder-trust prompt (hc keys <t> down enter) if shown, and hc send <t> "<task>".
set -euo pipefail
NAME=${1:?name}; WT=${2:?worktree}; MODEL=${3:-}
: "${HC_TERMINAL_ID:?run from an hc terminal}"
ARGS="--permission-mode auto"; [ -n "$MODEL" ] && ARGS="--model $MODEL $ARGS"
PRE=${WORKER_PRE:-proxy_on; nvm use --lts;}   # required on this machine (else API 403); machine setup before claude, e.g. WORKER_PRE="proxy_on; nvm use --lts;"
hc run --bg --parent "$HC_TERMINAL_ID" --name "$NAME" --cwd "$WT" /bin/zsh -lic "set -e; $PRE exec claude $ARGS"
