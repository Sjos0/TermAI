#!/usr/bin/env python3
"""Apply review-routing labels only after a verified comment for the exact PR HEAD."""
import json
import subprocess
import sys

REPO = "Sjos0/TermAI"
REVIEW_LABEL = "agent:code-review-reviewed"
QUEUE_LABEL = "agent:needs-code-review"
MARKER_BASE = "<!-- ameno-code-review:automated head="

def gh(args):
    return subprocess.run(["gh", *args], text=True, capture_output=True, check=True)

def main():
    if len(sys.argv) != 3 or not sys.argv[1].isdigit():
        print("Uso: termai-gh-review-finish PR HEAD_SHA", file=sys.stderr)
        return 2
    pr, sha = sys.argv[1:]
    info = json.loads(gh(["pr", "view", pr, "--repo", REPO, "--json", "state,headRefOid,labels"]).stdout)
    if info.get("state") != "OPEN" or info.get("headRefOid") != sha:
        print("HEAD mudou ou PR não está aberta; labels preservadas.", file=sys.stderr)
        return 3
    comments = json.loads(gh(["api", f"repos/{REPO}/issues/{pr}/comments", "--paginate"]).stdout)
    marker = f"{MARKER_BASE}{sha} -->"
    if not any(marker in (c.get("body") or "") for c in comments):
        print("Não há comentário confirmado para o HEAD exato; labels preservadas.", file=sys.stderr)
        return 4
    labels = {x.get("name") for x in info.get("labels", [])}
    if REVIEW_LABEL not in labels:
        existing = json.loads(gh(["api", f"repos/{REPO}/labels?per_page=100"]).stdout)
        if not any(x.get("name") == REVIEW_LABEL for x in existing):
            gh(["label", "create", REVIEW_LABEL, "--repo", REPO,
                "--description", "PR revisada pelo Code Review", "--color", "0E8A16"])
    args = ["pr", "edit", pr, "--repo", REPO]
    if QUEUE_LABEL in labels:
        args += ["--remove-label", QUEUE_LABEL]
    if REVIEW_LABEL not in labels:
        args += ["--add-label", REVIEW_LABEL]
    if len(args) > 4:
        gh(args)
    verify = json.loads(gh(["pr", "view", pr, "--repo", REPO, "--json", "headRefOid,labels"]).stdout)
    final_labels = {x.get("name") for x in verify.get("labels", [])}
    if verify.get("headRefOid") != sha or REVIEW_LABEL not in final_labels or QUEUE_LABEL in final_labels:
        print("Falha ao verificar labels finais.", file=sys.stderr)
        return 5
    print(f"OK: pr={pr} head={sha} labels={','.join(sorted(final_labels))}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
