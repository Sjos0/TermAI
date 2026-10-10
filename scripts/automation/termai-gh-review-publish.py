#!/usr/bin/env python3
"""Safely publish/update the idempotent TermAI Code Review comment."""
import json
import pathlib
import subprocess
import sys
import tempfile

REPO = "Sjos0/TermAI"
MARKER_BASE = "<!-- ameno-code-review:automated"

def gh(args, *, capture=True):
    return subprocess.run(["gh", *args], text=True, capture_output=capture, check=True)

def main():
    if len(sys.argv) != 4:
        print("Uso: termai-gh-review-publish PR HEAD_SHA BODY_FILE", file=sys.stderr)
        return 2
    pr, expected_sha, body_path = sys.argv[1:]
    if not pr.isdigit() or not expected_sha or len(expected_sha) < 7:
        print("PR ou HEAD_SHA inválido.", file=sys.stderr)
        return 2
    p = pathlib.Path(body_path)
    if not p.is_file():
        print("Arquivo do comentário não encontrado.", file=sys.stderr)
        return 2
    info = json.loads(gh(["pr", "view", pr, "--repo", REPO, "--json", "state,headRefOid"]).stdout)
    if info.get("state") != "OPEN" or info.get("headRefOid") != expected_sha:
        print("HEAD mudou ou PR não está aberta; comentário não publicado.", file=sys.stderr)
        return 3
    body = p.read_text(encoding="utf-8").strip()
    body = "\n".join(line for line in body.splitlines()
                     if not line.strip().startswith(MARKER_BASE)).strip()
    body = f"<!-- ameno-code-review:automated head={expected_sha} -->\n\n{body}\n"
    p.write_text(body, encoding="utf-8")
    comments = json.loads(gh(["api", f"repos/{REPO}/issues/{pr}/comments", "--paginate"]).stdout)
    matching = [c for c in comments if MARKER_BASE in (c.get("body") or "")]
    matching.sort(key=lambda c: c.get("created_at", ""), reverse=True)
    if matching:
        comment_id = str(matching[0]["id"])
        result = json.loads(gh(["api", f"repos/{REPO}/issues/comments/{comment_id}",
                                "-X", "PATCH", "-f", f"body={body}"]).stdout)
        action = "updated"
    else:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False, suffix=".md") as f:
            f.write(body)
            tmp = f.name
        try:
            gh(["pr", "comment", pr, "--repo", REPO, "--body-file", tmp], capture=True)
        finally:
            pathlib.Path(tmp).unlink(missing_ok=True)
        comments = json.loads(gh(["api", f"repos/{REPO}/issues/{pr}/comments", "--paginate"]).stdout)
        matching = [c for c in comments if f"<!-- ameno-code-review:automated head={expected_sha} -->" in (c.get("body") or "")]
        if not matching:
            print("GitHub não confirmou o comentário publicado.", file=sys.stderr)
            return 4
        result = max(matching, key=lambda c: c.get("created_at", ""))
        comment_id = str(result["id"])
        action = "created"
    if f"<!-- ameno-code-review:automated head={expected_sha} -->" not in (result.get("body") or ""):
        print("O comentário retornado não contém o marcador esperado.", file=sys.stderr)
        return 4
    latest = json.loads(gh(["pr", "view", pr, "--repo", REPO, "--json", "headRefOid"]).stdout)
    if latest.get("headRefOid") != expected_sha:
        print(f"Comentário {action} (id={comment_id}), mas o HEAD mudou; labels não serão alteradas.", file=sys.stderr)
        return 3
    print(f"OK: comment_{action}=true pr={pr} comment_id={comment_id} head={expected_sha}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
