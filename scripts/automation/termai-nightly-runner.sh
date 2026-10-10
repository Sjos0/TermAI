#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export HOME="/home/ubuntu"
export PATH="/home/ubuntu/.local/bin:/usr/local/bin:/usr/bin:/bin"
export TMPDIR="/tmp"
JOB="$1"
case "$JOB" in
  bugs-hunter) PROMPT="/home/ubuntu/projects/TermAI/scripts/automation/prompts/bugs-hunter.md"; MAX_ITER=32 ;;
  code-review) PROMPT="/home/ubuntu/projects/TermAI/scripts/automation/prompts/code-review.md"; MAX_ITER=64 ;;
  *) echo "Uso: termai-nightly-runner.sh bugs-hunter|code-review" >&2; exit 2 ;;
esac
HOME_DIR="/home/ubuntu"
REPO="/home/ubuntu/projects/TermAI"
STATE="/home/ubuntu/.local/state/termai"
STAMP="$(date +%Y%m%dT%H%M%S%z)"
RUN_DIR="$STATE/jobs/$JOB/$STAMP"
mkdir -p "$RUN_DIR" "$STATE/locks"
exec 9>"$STATE/locks/$JOB.lock"
flock -n 9 || { echo "[$(date -Is)] $JOB já está em execução; saída sem duplicar."; exit 0; }
exec 8>"/home/ubuntu/.local/state/termai-nightly.lock"
flock -w 7200 8 || { echo "[$(date -Is)] Timeout esperando lock global; nenhum job executado."; exit 75; }
LOG="$RUN_DIR/run.log"
exec > >(tee -a "$LOG") 2>&1
STARTED="$(date -Is)"
snapshot() {
  local tag="$1"
  {
    echo "timestamp=$(date -Is)"
    echo "repo=$REPO"
    git -C "$REPO" rev-parse HEAD 2>&1 || true
    git -C "$REPO" status --short --branch 2>&1 || true
    git -C "$REPO" diff --stat 2>&1 || true
    git -C "$REPO" diff --cached --stat 2>&1 || true
  } > "$RUN_DIR/$tag-repository.txt"
  timeout 30s gh pr list --repo Sjos0/TermAI --state open --limit 100 \
    --json number,title,headRefOid,url,labels,updatedAt > "$RUN_DIR/$tag-prs.json" 2>&1 || true
  timeout 30s gh issue list --repo Sjos0/TermAI --state open --limit 100 \
    --json number,title,labels,updatedAt > "$RUN_DIR/$tag-issues.json" 2>&1 || true
}
finish() {
  local rc=$?
  trap - EXIT
  snapshot after || true
  {
    echo "# TermAI scheduled run"
    echo "job=$JOB"
    echo "started=$STARTED"
    echo "finished=$(date -Is)"
    echo "exit_code=$rc"
    echo "model_primary=kilo/kilo-auto/free"
    echo "model_fallback=kilo/openrouter/free"
    echo "max_iterations=$MAX_ITER"
    echo "log=$LOG"
    echo "repository_snapshot_before=$RUN_DIR/before-repository.txt"
    echo "repository_snapshot_after=$RUN_DIR/after-repository.txt"
    echo "github_prs_before=$RUN_DIR/before-prs.json"
    echo "github_prs_after=$RUN_DIR/after-prs.json"
    echo "github_issues_before=$RUN_DIR/before-issues.json"
    echo "github_issues_after=$RUN_DIR/after-issues.json"
  } > "$RUN_DIR/summary.md"
  echo "[$(date -Is)] $JOB finalizado com exit_code=$rc; evidências em $RUN_DIR"
  exit "$rc"
}
trap finish EXIT
echo "[$STARTED] Início de $JOB; run_dir=$RUN_DIR"
cd "$REPO"
if [[ ! -f "$PROMPT" ]]; then echo "Prompt ausente: $PROMPT"; exit 2; fi
gh auth status > "$RUN_DIR/github-auth.txt" 2>&1
gh repo view Sjos0/TermAI --json nameWithOwner,url > "$RUN_DIR/github-repo.json"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Worktree não está limpo; interrompendo para não misturar alterações com o job."
  git status --short
  exit 75
fi
git fetch origin main
git checkout main
git pull --ff-only origin main
snapshot before
echo "[$(date -Is)] Executando TermAI run com fallback por modelo (3 tentativas/modelo)."
timeout --signal=TERM --kill-after=30s 3600s env HOME="$HOME_DIR" TMPDIR=/tmp \
  /home/ubuntu/.local/bin/TermAI run --model kilo/kilo-auto/free \
  --prompt-file "$PROMPT" --max-iter "$MAX_ITER"
